import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/src/simulate.dart' show rebuildEngine;
import 'package:crypto/crypto.dart' as hash;

import 'ai_service.dart';
import 'chat_reactions.dart';
import 'replay_store.dart';
import 'stats.dart';
import 'party.dart';

export 'ai_service.dart';
export 'env.dart';
export 'replay_store.dart';
export 'stats.dart';

const emptyRoomTtl = Duration(minutes: 3);
const idleTimeout = Duration(seconds: 60);
const reconnectGrace = Duration(minutes: 10);

/// A login with an online player's name + IP is refused as a duplicate unless
/// that player has been silent this long (clients ping every 10 s, so the old
/// socket is a dead connection the server hasn't noticed yet).
const duplicateLoginStale = Duration(seconds: 25);

/// Security limits.
const handshakeTimeout = Duration(seconds: 10);
const maxConnectionsPerIp = 16;
const maxPendingPerIp = 4;
const maxActionBytes = 64 * 1024;
const maxPasswordFailures = 5; // per ip+room, then locked for [passwordLockout]
const passwordLockout = Duration(minutes: 2);
const maxClients = 2000; // identities kept (online + reconnect grace)
const maxRooms = 500;
const maxRoomsPerClient = 3;

/// Default HTTP port: serves the browser client (static files) and the `/ws`
/// WebSocket game connection on the same port.
const kDefaultWebPort = kDefaultPort;

void logLine(String s) {
  final t = DateTime.now().toIso8601String().substring(11, 19);
  stdout.writeln('[$t] $s');
}

/// One player connection: a browser WebSocket (`/ws` on the HTTP port)
/// carrying length-prefixed, encrypted frames.
abstract class Wire {
  void add(List<int> bytes);
  void destroy();
}

class _WebSocketWire implements Wire {
  final WebSocket ws;
  _WebSocketWire(this.ws);
  @override
  void add(List<int> bytes) {
    if (ws.readyState == WebSocket.open) ws.add(bytes); // List<int> = binary message
  }

  @override
  void destroy() {
    ws.close(WebSocketStatus.policyViolation).catchError((_) {});
  }
}

class Client {
  final int id;
  final String token;
  Wire? socket;

  /// Encrypted channel for the current socket (null until handshake is done).
  SecureChannel? channel;
  String name = '玩家';
  int avatar = 1;

  /// Stable player id derived from the client's uid (''= anonymous).
  String pid = '';
  Room? room;
  DateTime lastSeen = DateTime.now();
  DateTime? disconnectedAt;
  final FrameDecoder decoder = FrameDecoder();
  String address = '';
  String get ip => address.contains(':') ? address.substring(0, address.lastIndexOf(':')) : address;

  // token buckets: chat messages, voice bytes, total json messages
  double _chatTokens = 5, _voiceTokens = 32000, _msgTokens = 60;
  DateTime _refill = DateTime.now();

  void _tick() {
    final now = DateTime.now();
    final dt = now.difference(_refill).inMicroseconds / 1e6;
    _refill = now;
    _chatTokens = min(5, _chatTokens + dt * 1.0); // 1 msg/s, burst 5
    _voiceTokens = min(32000, _voiceTokens + dt * 24000); // 24 KB/s cap; 16 kHz mu-law needs 16 KB/s
    _msgTokens = min(60, _msgTokens + dt * 30); // 30 msgs/s, burst 60
  }

  bool allowChat() {
    _tick();
    if (_chatTokens < 1) return false;
    _chatTokens -= 1;
    return true;
  }

  bool allowVoice(int bytes) {
    _tick();
    if (_voiceTokens < bytes) return false;
    _voiceTokens -= bytes;
    return true;
  }

  bool allowMsg() {
    _tick();
    if (_msgTokens < 1) return false;
    _msgTokens -= 1;
    return true;
  }

  Client(this.id, this.token);

  bool get online => socket != null;

  void send(Map<String, dynamic> msg) => sendRaw(encodeJson(msg));

  /// Send an already-encoded plaintext frame (from [encodeJson]/[encodeFrame]);
  /// it is sealed per-connection before hitting the wire.
  void sendRaw(Uint8List frame) {
    final s = socket;
    final ch = channel;
    if (s == null || ch == null) return;
    try {
      final kind = frame[4];
      s.add(encodeFrame(kind, ch.seal(kind, Uint8List.sublistView(frame, 5))));
    } catch (_) {}
  }

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'avatar': avatar, 'online': online};
}

class Seat {
  Client? client;
  bool bot = false;
  String botName = '';
  bool ready = false;

  /// 托管: the seated human asked the bot to play for them.
  bool auto = false;

  /// Player left mid-game; a bot keeps playing for them until the game ends.
  bool takenOver = false;

  /// Who left a [takenOver] seat, so they can take it back when they return.
  String ownerName = '', ownerIp = '', ownerPid = '';
  bool get empty => client == null && !bot;

  bool ownedBy(Client c) =>
      takenOver &&
      ownerIp.isNotEmpty &&
      ownerIp == c.ip &&
      (ownerName == c.name || (ownerPid.isNotEmpty && ownerPid == c.pid));
}

class Room implements GameHost {
  final AuroraServer server;
  final String id;
  String name;
  String password;

  /// Private rooms are hidden from the lobby list; they can only be joined by
  /// typing the room code (5 chars A-Z0-9, random).
  bool private;
  int hostId;
  String gameId;
  Map<String, dynamic> options;
  List<Seat> seats = [];
  final Set<Client> members = {};
  final ChatReactions reactions = ChatReactions();
  GameEngine? engine;

  /// game seat -> room seat index for the running engine.
  List<int> gameSeats = [];
  DateTime? emptySince;
  final Map<int, Timer> _botTimers = {};

  /// Per-turn time limit for online humans in seconds (0 = unlimited). When it
  /// runs out the bot makes that one move for them.
  int turnTimeout = 0;
  final Map<int, DateTime> _waitSince = {};
  final Map<int, Timer> _humanTimers = {};
  final List<Timer> _timers = [];
  int _epoch = 0; // bumps on every game start / abort to invalidate timers
  bool destroyed = false;

  /// 电脑难度 0 简单 / 1 普通 / 2 困难.
  int botLevel = 1;

  /// 本房间连续对局积分榜 (key -> row), cleared when the game type changes.
  final Map<String, Map<String, dynamic>> tally = {};

  PartyNight? party;

  /// Pending undo/draw request.
  _Request? request;
  int _nextRequestId = 1;

  /// client id -> kicked until.
  final Map<int, DateTime> kicked = {};

  /// 悔棋: seed of the running game (undo games only) and its action log.
  int? _seed;
  final List<(int, Map<String, dynamic>)> _actionLog = [];

  /// Participants of the running game (by game seat), captured at start.
  List<_Participant> _players = [];
  ReplayRecorder? _recorder;
  String _replayId = '';
  final Map<int, DateTime> _botNullSince = {};

  Room(this.server, this.id, this.name, this.password, this.hostId, this.gameId,
      this.options, {this.private = false}) {
    _resizeSeats();
  }

  GameDef get def => server.findDef(gameId)!;
  bool get playing => engine != null && !engine!.isOver;
  (int, int) get range => def.playerRange(options);

  void _resizeSeats() {
    final max = range.$2;
    while (seats.length < max) {
      seats.add(Seat());
    }
    if (seats.length > max) {
      // push occupants from removed seats into free lower seats when possible
      final extra = seats.sublist(max);
      seats = seats.sublist(0, max);
      for (final s in extra) {
        if (s.empty) continue;
        final free = seats.indexWhere((x) => x.empty);
        if (free >= 0) {
          seats[free] = s;
        }
      }
    }
  }

  int seatOf(Client c) => seats.indexWhere((s) => s.client == c);

  int gameSeatOf(Client c) {
    final rs = seatOf(c);
    if (rs < 0 || engine == null) return -1;
    return gameSeats.indexOf(rs);
  }

  Map<String, dynamic> summary() => {
        'id': id,
        'name': name,
        'game': gameId,
        'gameName': def.name,
        'players': seats.where((s) => !s.empty).length,
        'seats': seats.length,
        'members': members.where((m) => m.online).length,
        'playing': playing,
        'locked': password.isNotEmpty,
        'private': private,
      };

  Map<String, dynamic> snapshot() => {
        'id': id,
        'name': name,
        'host': hostId,
        'game': gameId,
        'options': options,
        'locked': password.isNotEmpty,
        'private': private,
        'canStart': !playing && _startable(),
        'range': [range.$1, range.$2],
        'playing': playing,
        'hasGame': engine != null,
        'turnTimeout': turnTimeout,
        'botLevel': botLevel,
        'tally': [for (final r in tally.values) r],
        'party': party?.toJson(),
        'caps': caps,
        'request': request?.toJson(),
        'seats': [
          for (final s in seats)
            {
              'client': s.client?.toJson(),
              'bot': s.bot,
              'botName': s.botName,
              'ready': s.ready,
              'takenOver': s.takenOver,
              'auto': s.auto,
            }
        ],
        'members': [for (final m in members) m.toJson()],
      };

  void broadcast(Map<String, dynamic> msg) {
    final bytes = encodeJson(msg);
    for (final m in members) {
      m.sendRaw(bytes);
    }
  }

  void pushRoom() {
    broadcast({'t': Msg.room, 'room': snapshot()});
    server.pushRoomList();
  }

  Map<String, dynamic> get caps {
    final e = engine;
    if (e == null || e.isOver) return const {'resign': false, 'draw': false, 'undo': false};
    bool safe(bool Function() f) {
      try {
        return f();
      } catch (_) {
        return false;
      }
    }

    return {'resign': safe(() => e.canResign), 'draw': safe(() => e.canDraw), 'undo': def.undo && _seed != null};
  }

  /// Push views to members; returns the views computed per game seat so the
  /// replay recorder can reuse them.
  Map<int, Map<String, dynamic>> pushGame([Client? only]) {
    final e = engine;
    final views = <int, Map<String, dynamic>>{};
    if (e == null) return views;
    final avatars = [
      for (var i = 0; i < gameSeats.length; i++)
        seats[gameSeats[i]].client?.avatar ?? (i < _players.length ? _players[i].avatar : 0)
    ];
    for (final m in only == null ? members : [only]) {
      final gs = gameSeatOf(m);
      Map<String, dynamic> v;
      try {
        v = views[gs] ??= e.view(gs);
      } catch (err, st) {
        logLine('view error in $gameId: $err\n$st');
        continue;
      }
      if (!m.online) continue;
      m.send({
        't': Msg.game,
        'game': gameId,
        'seat': gs,
        'names': e.setup.names,
        'bots': e.setup.bots,
        'avatars': avatars,
        'view': v,
        'over': e.isOver,
        'deadlines': _deadlines(gs),
      });
    }
    return views;
  }

  DateTime _lastRecord = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _recordTimer;

  /// Record every seat's view. Real-time games tick fast, so frames closer
  /// than 200 ms are coalesced into one trailing snapshot.
  void _record(GameEngine e, Map<int, Map<String, dynamic>> views) {
    final r = _recorder;
    if (r == null || r.full) return;
    final now = DateTime.now();
    if (!e.isOver && now.difference(_lastRecord).inMilliseconds < r.minGapMs) {
      final epoch = _epoch;
      _recordTimer ??= Timer(Duration(milliseconds: r.minGapMs), () {
        _recordTimer = null;
        if (destroyed || epoch != _epoch || engine != e || _recorder != r) return;
        _record(e, const {});
      });
      return;
    }
    _recordTimer?.cancel();
    _recordTimer = null;
    _lastRecord = now;
    try {
      for (var s = -1; s < e.players; s++) {
        r.add(s, views[s] ?? e.view(s), force: true);
      }
    } catch (err) {
      logLine('replay record error in $gameId: $err');
    }
  }

  /// Only the receiving seat's own clock: other seats' clocks would reveal who
  /// the engine is waiting on (e.g. who can claim a discard).
  Map<String, int> _deadlines(int seat) {
    if (turnTimeout <= 0 || seat < 0) return const {};
    final since = _waitSince[seat];
    if (since == null) return const {};
    return {'$seat': max(0, turnTimeout * 1000 - DateTime.now().difference(since).inMilliseconds)};
  }

  void setTurnTimeout(Client c, int sec) {
    requireHost(c);
    const allowed = [0, 15, 30, 60, 90, 120, 300];
    if (!allowed.contains(sec)) throw GameError('无效的思考时间');
    turnTimeout = sec;
    systemChat(sec == 0 ? '思考时间：不限' : '思考时间：$sec 秒（超时由电脑代打一步）');
    pushRoom();
  }

  void systemChat(String text) {
    broadcast({
      't': Msg.chatMsg,
      'from': 0,
      'name': '系统',
      'avatar': 0,
      'text': text,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'system': true,
    });
  }

  // ---- GameHost ----
  @override
  void log(String text) {
    systemChat(text);
    try {
      _recorder?.log(text);
    } catch (_) {}
  }

  @override
  void Function() schedule(int ms, void Function() fn) {
    final epoch = _epoch;
    late Timer t;
    t = Timer(Duration(milliseconds: ms), () {
      _timers.remove(t);
      if (destroyed || epoch != _epoch || engine == null) return;
      try {
        fn();
      } catch (e, st) {
        logLine('scheduled error in $gameId: $e\n$st');
      }
      afterChange();
    });
    _timers.add(t);
    return () {
      t.cancel();
      _timers.remove(t);
    };
  }

  // ---- lifecycle ----
  void join(Client c) {
    members.add(c);
    c.room = this;
    emptySince = null;
    systemChat('${c.name} 进入了房间');
    _reclaimSeat(c);
    pushRoom();
    pushGame(c);
  }

  /// A player whose seat was handed to the bot (left / timed out mid-game)
  /// came back: give the seat back instead of making them watch.
  void _reclaimSeat(Client c) {
    final e = engine;
    if (e == null || e.isOver || seatOf(c) >= 0) return;
    final rs = seats.indexWhere((s) => s.ownedBy(c));
    if (rs < 0) return;
    final gs = gameSeats.indexOf(rs);
    if (gs < 0) return;
    seats[rs] = Seat()..client = c;
    e.setup.bots[gs] = false;
    _botTimers.remove(gs)?.cancel();
    systemChat('${c.name} 回到了座位，托管已解除');
    _updateClocks(e);
  }

  void leave(Client c, {bool silent = false}) {
    _dropFromRequest(c);
    final rs = seatOf(c);
    if (rs >= 0) _vacate(rs, c);
    members.remove(c);
    if (c.room == this) c.room = null;
    if (!silent) systemChat('${c.name} 离开了房间');
    if (hostId == c.id) _pickNewHost();
    _checkEmpty();
    pushRoom();
    afterChange();
  }

  void _vacate(int rs, Client c) {
    final seat = seats[rs];
    if (playing && gameSeats.contains(rs)) {
      // keep the game going: a bot takes over this seat
      seat.client = null;
      seat.bot = true;
      seat.takenOver = true;
      seat.auto = false;
      seat.botName = '${c.name}(托管)';
      seat.ownerName = c.name;
      seat.ownerIp = c.ip;
      seat.ownerPid = c.pid;
      engine!.setup.bots[gameSeats.indexOf(rs)] = true;
    } else {
      seats[rs] = Seat();
    }
  }

  void _pickNewHost() {
    final next = members.where((m) => m.online).firstOrNull ?? members.firstOrNull;
    if (next != null) {
      hostId = next.id;
      systemChat('${next.name} 成为了房主');
    }
  }

  void _checkEmpty() {
    if (members.any((m) => m.online)) {
      emptySince = null;
    } else {
      emptySince ??= DateTime.now();
    }
  }

  /// A member who must answer the pending request left / went offline.
  void _dropFromRequest(Client c) {
    final r = request;
    if (r == null) return;
    if (r.fromId == c.id) {
      _cancelRequest();
      return;
    }
    if (r.need.remove(c.id) && r.need.isNotEmpty && r.yes.containsAll(r.need)) {
      _cancelRequest();
      try {
        _execute(r.kind, r.fromGs, r.fromName);
      } catch (_) {}
    } else if (r.need.isEmpty) {
      _cancelRequest();
    }
  }

  void onMemberOffline(Client c) {
    _dropFromRequest(c);
    // No chat notice: flaky connections would flood the room chat. The member list shows online state.
    if (hostId == c.id) {
      final other = members.where((m) => m.online).firstOrNull;
      if (other != null) {
        hostId = other.id;
        systemChat('${other.name} 成为了房主');
      }
    }
    _checkEmpty();
    pushRoom();
    afterChange();
  }

  void onMemberOnline(Client c) {
    emptySince = null;
    final e = engine;
    // the bot stopped covering for this seat; restart the turn clock
    if (e != null && !e.isOver) _updateClocks(e);
    pushRoom();
    pushGame(c);
  }

  void destroy() {
    destroyed = true;
    _cancelTimers();
    _cancelRequest();
    for (final m in members) {
      m.room = null;
      m.send({'t': Msg.room, 'room': null});
    }
    members.clear();
  }

  void _cancelTimers() {
    _epoch++;
    _recordTimer?.cancel();
    _recordTimer = null;
    for (final t in _botTimers.values) {
      t.cancel();
    }
    _botTimers.clear();
    for (final t in _humanTimers.values) {
      t.cancel();
    }
    _humanTimers.clear();
    _waitSince.clear();
    for (final t in List.of(_timers)) {
      t.cancel();
    }
    _timers.clear();
  }

  // ---- host / seat management ----
  bool isHost(Client c) => c.id == hostId;

  void requireHost(Client c) {
    if (!isHost(c)) throw GameError('只有房主可以这样做');
  }

  int get _occupied => seats.where((s) => !s.empty).length;
  bool _startable() {
    final (lo, hi) = range;
    return _occupied >= lo && _occupied <= hi;
  }

  void setPrivate(Client c, bool v) {
    requireHost(c);
    private = v;
    systemChat(v ? '房间已设为私密（仅凭房间号 $id 进入）' : '房间已设为公开');
    pushRoom();
  }

  void requireNotPlaying() {
    if (playing) throw GameError('对局进行中');
  }

  void setGame(Client c, String game, Map<String, dynamic>? opts, {bool partyTransition = false}) {
    if (party != null && !partyTransition) throw GameError('请使用派对之夜的下一局，或先结束派对');
    requireHost(c);
    requireNotPlaying();
    final d = server.findDef(game);
    if (d == null) throw GameError('未知游戏');
    if (game != gameId) tally.clear();
    gameId = game;
    options = d.normalizeOptions(opts);
    _clearFinished();
    _resizeSeats();
    for (final s in seats) {
      s.ready = false;
    }
    pushRoom();
  }

  void configureParty(Client c, Object? raw) {
    requireHost(c); requireNotPlaying();
    if (raw is! List || raw.length > 8) throw GameError('派对队列最多 8 款游戏');
    if (raw.isEmpty) { party = null; pushRoom(); return; }
    final ids = raw.map((x) => asStr(x)).toList();
    if (ids.length < 2 || ids.toSet().length != ids.length) throw GameError('请选择 2~8 款不同游戏');
    final count = seats.where((s) => !s.empty).length;
    for (final id in ids) {
      final d = server.findDef(id);
      if (d == null) throw GameError('未知游戏');
      final r = d.defaultOptionsRange();
      if (count < r.$1 || count > r.$2) throw GameError('${d.name} 需要 ${r.$1}~${r.$2} 人，请先调整座位');
    }
    party = PartyNight(ids);
    setGame(c, ids.first, null, partyTransition: true);
    systemChat('派对之夜已开始：共 ${ids.length} 款游戏，每局第一名得 100 分，其他名次按人数折算。');
  }

  void voteParty(Client c, String game) {
    if (seatOf(c) < 0) throw GameError('入座玩家才可以投票');
    final p = party;
    if (p == null) throw GameError('当前没有派对');
    p.vote(c.id, game); pushRoom();
  }

  void nextParty(Client c) {
    requireHost(c); requireNotPlaying();
    final p = party;
    if (p == null || !p.roundComplete || p.finished) throw GameError('当前没有可继续的派对对局');
    final count = seats.where((s) => !s.empty).length;
    final next = p.nextChoice(members.where((m) => m.online && seatOf(m) >= 0).map((m) => m.id).toSet(), (id) {
      final r = server.findDef(id)!.defaultOptionsRange(); return count >= r.$1 && count <= r.$2;
    });
    if (next == null) throw GameError('剩余游戏与当前人数不符，请调整座位后再试');
    p.advance(next); setGame(c, next, null, partyTransition: true);
    systemChat('派对第 ${p.index + 1}/${p.queue.length} 局：${def.name}，请准备。');
  }

  void _clearFinished() {
    if (engine != null && engine!.isOver) {
      engine = null;
      gameSeats = [];
      for (var i = 0; i < seats.length; i++) {
        if (seats[i].takenOver) seats[i] = Seat();
      }
    }
  }

  void sit(Client c, int seat) {
    requireNotPlaying();
    _clearFinished();
    if (seat < 0 || seat >= seats.length) throw GameError('无效座位');
    if (!seats[seat].empty) throw GameError('座位已被占用');
    final cur = seatOf(c);
    if (cur >= 0) seats[cur] = Seat();
    seats[seat].client = c;
    seats[seat].ready = false;
    pushRoom();
  }

  void stand(Client c) {
    requireNotPlaying();
    final cur = seatOf(c);
    if (cur >= 0) seats[cur] = Seat();
    pushRoom();
  }

  void setReady(Client c, bool ready) {
    final cur = seatOf(c);
    if (cur < 0) throw GameError('请先入座');
    seats[cur].ready = ready;
    pushRoom();
  }

  void addBot(Client c, int seat) {
    requireHost(c);
    requireNotPlaying();
    _clearFinished();
    if (!def.botSupport) throw GameError('该游戏不支持电脑玩家');
    if (seat < 0) seat = seats.indexWhere((s) => s.empty);
    if (seat < 0 || seat >= seats.length || !seats[seat].empty) {
      throw GameError('没有空座位');
    }
    var n = 1;
    while (seats.any((s) => s.bot && s.botName == '电脑$n')) {
      n++;
    }
    seats[seat]
      ..bot = true
      ..botName = '电脑$n'
      ..ready = true;
    pushRoom();
  }

  void removeSeat(Client c, int seat) {
    requireHost(c);
    requireNotPlaying();
    if (seat < 0 || seat >= seats.length) throw GameError('无效座位');
    final s = seats[seat];
    if (s.client == c) throw GameError('不能移除自己');
    if (s.client != null) {
      s.client!.send({'t': Msg.toast, 'msg': '你被房主移出了座位'});
    }
    seats[seat] = Seat();
    pushRoom();
  }

  void startGame(Client c) {
    requireHost(c);
    if (party?.roundComplete == true) throw GameError('请先选择派对下一局，或结束派对');
    requireNotPlaying();
    _clearFinished();
    final occupied = [for (var i = 0; i < seats.length; i++) if (!seats[i].empty) i];
    final (lo, hi) = range;
    if (occupied.length < lo || occupied.length > hi) {
      throw GameError(lo == hi ? '需要 $lo 名玩家' : '需要 $lo~$hi 名玩家（当前 ${occupied.length}）');
    }
    for (final i in occupied) {
      final s = seats[i];
      if (s.client != null && !s.ready && s.client != c) {
        throw GameError('${s.client!.name} 还没有准备');
      }
    }
    _cancelTimers();
    _cancelRequest();
    gameSeats = occupied;
    for (final s in seats) {
      s.auto = false;
    }
    final names = [for (final i in occupied) seats[i].client?.name ?? seats[i].botName];
    final bots = [for (final i in occupied) seats[i].bot];
    final hostRoomSeat = seatOf(c);
    // 悔棋 games replay from a recorded seed; others keep an unguessable rng
    // (a 32-bit seed could be brute-forced to reveal hidden cards).
    final d = def;
    _seed = d.undo ? Random.secure().nextInt(1 << 32) : null;
    final setup = GameSetup(
      players: occupied.length,
      options: Map.of(options),
      names: names,
      bots: bots,
      hostSeat: occupied.indexOf(hostRoomSeat),
      rng: _seed != null ? Random(_seed) : Random.secure(),
      resources: server.resources.snapshot(),
      botLevel: botLevel,
      ai: server.ai,
      botRng: Random.secure(),
    );
    final e = d.create(setup);
    e.host = this;
    engine = e;
    _wasOver = false;
    _actionLog.clear();
    _botNullSince.clear();
    _players = [
      for (final i in occupied)
        _Participant(seats[i].client?.pid ?? '', seats[i].client?.name ?? seats[i].botName,
            seats[i].client?.avatar ?? 0, seats[i].bot)
    ];
    _recorder = ReplayRecorder(occupied.length);
    _replayId = server.replays.newId();
    systemChat('游戏开始：${d.name}');
    try {
      e.start();
    } catch (err, st) {
      logLine('start error in $gameId: $err\n$st');
      engine = null;
      gameSeats = [];
      _recorder = null;
      throw GameError(err is GameError ? err.message : '游戏启动失败');
    }
    logLine('room $id started ${d.name} with ${names.join(",")}');
    pushRoom();
    afterChange();
  }

  void abortGame(Client c) {
    requireHost(c);
    final e = engine;
    if (e == null) return;
    if (!e.isOver) {
      // save what was played (the game is over now, so it's safe to publish)
      final r = _recorder;
      if (r != null && r.tracks.last.length >= 5) _finishReplay(e, null);
    }
    _recorder = null;
    _cancelTimers();
    _cancelRequest();
    engine = null;
    gameSeats = [];
    for (var i = 0; i < seats.length; i++) {
      if (seats[i].takenOver) seats[i] = Seat();
      seats[i].ready = seats[i].bot;
      seats[i].auto = false;
    }
    systemChat('房主结束了对局');
    broadcast({'t': Msg.game, 'game': null});
    pushRoom();
  }

  /// Apply an action (human or bot) and keep the 悔棋 log.
  void _apply(GameEngine e, int gs, Map<String, dynamic> action) {
    if (_seed == null) {
      e.handle(gs, action);
      return;
    }
    final copy = jsonDecode(jsonEncode(action)) as Map<String, dynamic>;
    e.handle(gs, jsonDecode(jsonEncode(copy)) as Map<String, dynamic>);
    _actionLog.add((gs, copy));
  }

  void gameAction(Client c, Map<String, dynamic> a) {
    final e = engine;
    if (e == null) throw GameError('没有进行中的对局');
    final gs = gameSeatOf(c);
    if (gs < 0) throw GameError('你是观众');
    _apply(e, gs, a);
    _clearClock(gs);
    afterChange();
  }

  // ---- v3: options, emotes, 托管, 认输, requests, kick ----

  void setRoomOpts(Client c, Map<String, dynamic> m) {
    requireHost(c);
    requireNotPlaying();
    if (m.containsKey('botLevel')) {
      final l = asInt(m['botLevel'], -1);
      if (l < 0 || l > 2) throw GameError('无效的电脑难度');
      if (l != botLevel) {
        botLevel = l;
        systemChat('电脑难度：${kBotLevels[l]}');
      }
    }
    pushRoom();
  }

  void emote(Client c, int e) {
    if (e < 0 || e >= kEmotes.length) throw GameError('无效表情');
    if (!c.allowChat()) throw GameError('发得太快了，请稍后再试');
    broadcast({
      't': Msg.emoteMsg,
      'from': c.id,
      'name': c.name,
      'avatar': c.avatar,
      'seat': gameSeatOf(c),
      'e': e,
    });
  }

  void autoPlay(Client c, bool on) {
    final e = engine;
    final rs = seatOf(c);
    final gs = gameSeatOf(c);
    if (e == null || e.isOver || gs < 0) throw GameError('你不在对局中');
    if (seats[rs].auto == on) return;
    seats[rs].auto = on;
    if (!on) _botTimers.remove(gs)?.cancel();
    if (on) _clearClock(gs);
    systemChat(on ? '${c.name} 开启了托管' : '${c.name} 取消了托管');
    pushRoom();
    afterChange();
  }

  void resign(Client c) {
    final e = engine;
    final gs = gameSeatOf(c);
    if (e == null || e.isOver || gs < 0) throw GameError('你不在对局中');
    if (caps['resign'] != true) throw GameError('该游戏不支持认输');
    e.resign(gs);
    systemChat('${c.name} 认输');
    _clearClock(gs);
    afterChange();
    pushRoom();
  }

  static const requestTimeout = Duration(seconds: 30);

  void makeRequest(Client c, String kind) {
    final e = engine;
    final gs = gameSeatOf(c);
    if (e == null || e.isOver || gs < 0) throw GameError('你不在对局中');
    if (kind != 'undo' && kind != 'draw') throw GameError('无效请求');
    if (caps[kind] != true) throw GameError(kind == 'undo' ? '该游戏不支持悔棋' : '该游戏不支持求和');
    if (request != null) throw GameError('已有进行中的请求');
    if (kind == 'undo' && !_actionLog.any((x) => x.$1 == gs)) throw GameError('没有可以悔的棋');
    final need = <int>{
      for (var i = 0; i < gameSeats.length; i++)
        if (seats[gameSeats[i]].client case final m? when m != c && m.online) m.id
    };
    final label = kind == 'undo' ? '悔棋' : '和棋';
    if (need.isEmpty) {
      _execute(kind, gs, c.name);
      return;
    }
    final r = _Request(_nextRequestId++, kind, c.id, c.name, gs, need);
    request = r;
    r.timer = Timer(requestTimeout, () {
      if (request != r || destroyed) return;
      request = null;
      broadcast({'t': Msg.toast, 'msg': '$label请求已超时'});
      pushRoom();
    });
    systemChat('${c.name} 请求$label');
    pushRoom();
  }

  void respond(Client c, int reqId, bool yes) {
    final r = request;
    if (r == null || r.id != reqId) throw GameError('请求已失效');
    if (!r.need.contains(c.id)) throw GameError('不需要你回应');
    final label = r.kind == 'undo' ? '悔棋' : '和棋';
    if (!yes) {
      _cancelRequest();
      broadcast({'t': Msg.toast, 'msg': '${c.name} 拒绝了$label请求'});
      systemChat('${c.name} 拒绝了$label');
      pushRoom();
      return;
    }
    r.yes.add(c.id);
    if (r.yes.containsAll(r.need)) {
      _cancelRequest();
      _execute(r.kind, r.fromGs, r.fromName);
    } else {
      pushRoom();
    }
  }

  void _cancelRequest() {
    request?.timer?.cancel();
    request = null;
  }

  void _execute(String kind, int gs, String who) {
    final e = engine;
    if (e == null || e.isOver) return;
    if (kind == 'draw') {
      e.agreeDraw();
      systemChat('双方同意和棋');
      afterChange();
      pushRoom();
      return;
    }
    final k = _actionLog.lastIndexWhere((x) => x.$1 == gs);
    if (k < 0) throw GameError('没有可以悔的棋');
    final kept = _actionLog.sublist(0, k);
    GameEngine ne;
    try {
      ne = rebuildEngine(def, e.setup.copyWith(rng: Random(_seed), bots: List.of(e.setup.bots)), kept);
    } catch (err, st) {
      logLine('undo rebuild error in $gameId: $err\n$st');
      throw GameError('悔棋失败');
    }
    _cancelTimers();
    ne.host = this;
    engine = ne;
    _actionLog
      ..clear()
      ..addAll(kept);
    _wasOver = false;
    _botNullSince.clear();
    systemChat('$who 悔棋');
    pushRoom();
    afterChange();
  }

  static const kickBan = Duration(minutes: 5);
  final Map<String, DateTime> kickedPids = {};

  bool isKicked(Client c) {
    final now = DateTime.now();
    kicked.removeWhere((_, t) => now.isAfter(t));
    kickedPids.removeWhere((_, t) => now.isAfter(t));
    return kicked.containsKey(c.id) || (c.pid.isNotEmpty && kickedPids.containsKey(c.pid));
  }

  void kick(Client c, int targetId) {
    requireHost(c);
    if (targetId == c.id) throw GameError('不能踢出自己');
    final t = members.where((m) => m.id == targetId).firstOrNull;
    if (t == null) throw GameError('该玩家不在房间中');
    final until = DateTime.now().add(kickBan);
    kicked[t.id] = until;
    if (t.pid.isNotEmpty) kickedPids[t.pid] = until;
    systemChat('${t.name} 被房主移出了房间');
    leave(t, silent: true);
    t.send({'t': Msg.room, 'room': null});
    t.send({'t': Msg.toast, 'msg': '你被房主移出了房间（5 分钟内不能再进入）'});
    server.sendLobby(t);
  }

  void _clearClock(int gs) {
    _waitSince.remove(gs);
    _humanTimers.remove(gs)?.cancel();
  }

  bool _wasOver = false;

  bool _botControlled(Seat s) => s.bot || s.auto || (s.client != null && !s.client!.online);

  /// Broadcast views and schedule bot moves.
  void afterChange() {
    final e = engine;
    if (e == null || destroyed) return;
    _updateClocks(e);
    final views = pushGame();
    _record(e, views);
    if (e.isOver) {
      if (!_wasOver) {
        _wasOver = true;
        _cancelRequest();
        try {
          _onGameOver(e);
        } catch (err, st) {
          logLine('game over bookkeeping error in $gameId: $err\n$st');
        }
        for (final s in seats) {
          s.ready = s.bot && !s.takenOver;
          s.auto = false;
        }
        pushRoom();
      }
      return;
    }
    _wasOver = false;
    for (final gs in e.waitingFor.toSet()) {
      if (gs < 0 || gs >= gameSeats.length) continue;
      final seat = seats[gameSeats[gs]];
      if (!_botControlled(seat) || _botTimers.containsKey(gs)) continue;
      final offline = !seat.bot && !seat.auto;
      _scheduleBot(e, gs, offline ? max(e.botDelayMs, 5000) : e.botDelayMs);
    }
  }

  /// Bot returned null while still expected to act (e.g. AI reply pending):
  /// ask again after [botRetryMs]; after [botRetryFastFor] slow down to
  /// [botRetrySlowMs] so a bot that never answers can't spin.
  static int botRetryMs = 700;
  static const botRetrySlowMs = 5000;
  static const botRetryFastFor = Duration(seconds: 60);

  void _scheduleBot(GameEngine e, int gs, int ms) {
    final epoch = _epoch;
    _botTimers[gs] = Timer(Duration(milliseconds: ms), () {
      _botTimers.remove(gs);
      if (destroyed || epoch != _epoch || engine != e || e.isOver) return;
      if (!e.waitingFor.contains(gs)) {
        _botNullSince.remove(gs);
        afterChange();
        return;
      }
      if (gs >= gameSeats.length || !_botControlled(seats[gameSeats[gs]])) return;
      Map<String, dynamic>? act;
      try {
        act = e.runBot(gs);
      } catch (err) {
        logLine('bot error in $gameId seat $gs: $err');
      }
      if (act == null) {
        final since = _botNullSince[gs] ??= DateTime.now();
        final slow = DateTime.now().difference(since) > botRetryFastFor;
        _scheduleBot(e, gs, slow ? botRetrySlowMs : botRetryMs);
        return;
      }
      _botNullSince.remove(gs);
      try {
        _apply(e, gs, act);
      } catch (err) {
        logLine('bot error in $gameId seat $gs: $err');
      }
      afterChange();
    });
  }

  void _updateClocks(GameEngine e) {
    final waiting = e.isOver ? const <int>{} : e.waitingFor.toSet();
    for (final gs in _waitSince.keys.toList()) {
      if (!waiting.contains(gs)) _clearClock(gs);
    }
    if (turnTimeout <= 0) return;
    for (final gs in waiting) {
      if (gs < 0 || gs >= gameSeats.length || _waitSince.containsKey(gs)) continue;
      final seat = seats[gameSeats[gs]];
      if (seat.bot || seat.auto || seat.client == null || !seat.client!.online) continue;
      _waitSince[gs] = DateTime.now();
      final epoch = _epoch;
      _humanTimers[gs] = Timer(Duration(seconds: turnTimeout), () {
        _humanTimers.remove(gs);
        _waitSince.remove(gs);
        if (destroyed || epoch != _epoch || engine != e || e.isOver) return;
        if (!e.waitingFor.contains(gs)) return;
        try {
          final act = e.runBot(gs);
          if (act != null) {
            _apply(e, gs, act);
            // tell only that player: a public notice would reveal who the
            // engine was waiting on (e.g. who could claim a discard)
            seats[gameSeats[gs]].client?.send({'t': Msg.toast, 'msg': '思考超时，电脑代打了一步'});
          }
        } catch (err) {
          logLine('timeout bot error in $gameId seat $gs: $err');
        }
        afterChange();
      });
    }
  }

  // ---- results: stats, tally, replay ----

  List<int>? _placings(GameEngine e) {
    try {
      final p = e.placings;
      if (p == null || p.length != e.players || p.any((x) => x < 1)) return null;
      return List.of(p);
    } catch (_) {
      return null;
    }
  }

  void _onGameOver(GameEngine e) {
    final pl = _placings(e);
    if (pl != null && _players.length == pl.length) {
      server.stats.record(gameId, [
        for (var i = 0; i < pl.length; i++)
          StatEntry(_players[i].pid, _players[i].name, _players[i].avatar, _players[i].bot, pl[i])
      ]);
      for (var i = 0; i < pl.length; i++) {
        final p = _players[i];
        final key = p.pid.isNotEmpty ? 'p:${p.pid}' : 'n:${p.bot ? "bot" : "h"}:${p.name}';
        final row = tally.putIfAbsent(
            key, () => {'pid': p.pid, 'name': p.name, 'avatar': p.avatar, 'games': 0, 'wins': 0, 'points': 0});
        row['name'] = p.name;
        row['avatar'] = p.avatar;
        row['games'] = (row['games'] as int) + 1;
        if (pl[i] == 1) row['wins'] = (row['wins'] as int) + 1;
        row['points'] = (row['points'] as int) + (pl[i] == 1 ? 3 : max(0, pl.length - pl[i]));
      }
    }
    party?.record([for (final p in _players) {'key': p.pid.isNotEmpty ? p.pid : '${p.bot}:${p.name}', 'name': p.name, 'avatar': p.avatar}], pl);
    _finishReplay(e, pl);
  }

  void _finishReplay(GameEngine e, List<int>? ranking) {
    final r = _recorder;
    _recorder = null;
    if (r == null) return;
    try {
      final d = def;
      final doc = r.finish((dur) => ReplayMeta(
            id: _replayId,
            game: gameId,
            gameName: d.name,
            startedAt: r.startedAt,
            durationMs: dur,
            names: List.of(e.setup.names),
            avatars: [for (final p in _players) p.avatar],
            bots: [for (final p in _players) p.bot],
            options: Map.of(e.setup.options),
            uids: [for (final p in _players) p.bot ? '' : p.pid],
            ranking: ranking,
            room: id,
          ));
      server.replays.save(doc).catchError((Object err) {
        logLine('保存回放失败：$err');
      });
    } catch (err) {
      logLine('保存回放失败：$err');
    }
  }
}

class _Participant {
  final String pid;
  final String name;
  final int avatar;
  final bool bot;
  const _Participant(this.pid, this.name, this.avatar, this.bot);
}

class _Request {
  final int id;
  final String kind;
  final int fromId;
  final String fromName;
  final int fromGs;
  final Set<int> need;
  final Set<int> yes = {};
  Timer? timer;
  _Request(this.id, this.kind, this.fromId, this.fromName, this.fromGs, this.need);
  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'fromId': fromId,
        'fromName': fromName,
        'yes': yes.toList(),
        'need': need.toList(),
      };
}

/// Admin-editable text resources in `<exe dir>/words/`:
///   drawguess.txt   你画我猜 custom words, one per line: `词语` or `词语|类别`
///   undercover.txt  谁是卧底 custom pairs, one per line: `平民词|卧底词`
/// Lines starting with # are comments. Files are re-read when modified, so the
/// admin can edit them while the server runs (takes effect for new games).
class ServerResources {
  final Directory dir;
  final Map<String, (DateTime, List<String>)> _cache = {};
  ServerResources(this.dir);

  static const files = {
    'drawguess.words': 'drawguess.txt',
    'undercover.pairs': 'undercover.txt',
    'turtlesoup.stories': 'turtlesoup.txt',
    'decrypto.words': 'decrypto.txt',
    'justone.words': 'justone.txt',
    'wavelength.pairs': 'wavelength.txt',
  };

  List<String> lines(String key) {
    final name = files[key];
    if (name == null) return const [];
    final f = File('${dir.path}${Platform.pathSeparator}$name');
    if (!f.existsSync()) return const [];
    final mod = f.lastModifiedSync();
    final c = _cache[key];
    if (c != null && c.$1 == mod) return c.$2;
    List<String> out;
    try {
      out = [
        for (final l in f.readAsLinesSync())
          if (l.trim().isNotEmpty && !l.trimLeft().startsWith('#')) l.trim()
      ];
    } catch (e) {
      logLine('读取 ${f.path} 失败（请保存为 UTF-8）：$e');
      out = const [];
    }
    _cache[key] = (mod, out);
    logLine('已加载自定义词库 $name：${out.length} 条');
    return out;
  }

  Map<String, Object> snapshot() => {for (final k in files.keys) k: lines(k)};

  /// Force-clears the file mtime cache and reloads all custom word files.
  Map<String, int> reload() {
    _cache.clear();
    return {for (final e in files.entries) e.value: lines(e.key).length};
  }

  /// Raw UTF-8 text of each known custom word file for the web admin editor.
  Map<String, String> readRawFiles() {
    final out = <String, String>{};
    for (final name in files.values) {
      final f = File('${dir.path}${Platform.pathSeparator}$name');
      try {
        out[name] = f.existsSync() ? f.readAsStringSync() : '';
      } catch (_) {
        out[name] = '';
      }
    }
    return out;
  }

  /// Overwrites one known custom word file and reloads the cache.
  bool writeRawFile(String name, String content) {
    if (!files.values.contains(name) || content.length > 512 * 1024) return false;
    try {
      dir.createSync(recursive: true);
      final f = File('${dir.path}${Platform.pathSeparator}$name');
      f.writeAsStringSync(content);
      _cache.clear();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Create the folder with commented templates on first run.
  void ensureTemplates() {
    try {
      dir.createSync(recursive: true);
      final dg = File('${dir.path}${Platform.pathSeparator}drawguess.txt');
      if (!dg.existsSync()) {
        dg.writeAsStringSync('# 你画我猜 自定义词库（UTF-8）。每行一个词，可用 | 附加类别，例如：\n'
            '# 奶茶|食物\n# 打太极|动作\n# 以 # 开头的行是注释。保存后对新开的对局立即生效。\n');
      }
      final uc = File('${dir.path}${Platform.pathSeparator}undercover.txt');
      if (!uc.existsSync()) {
        uc.writeAsStringSync('# 谁是卧底 自定义词对（UTF-8）。每行：平民词|卧底词，例如：\n# 奶茶|咖啡\n');
      }
      final ts = File('${dir.path}${Platform.pathSeparator}turtlesoup.txt');
      if (!ts.existsSync()) {
        ts.writeAsStringSync('# 海龟汤 自定义题目（UTF-8）。每行：标题|汤面|汤底\n');
      }
      final dc = File('${dir.path}${Platform.pathSeparator}decrypto.txt');
      if (!dc.existsSync()) {
        dc.writeAsStringSync('# 截码战 自定义关键词（UTF-8）。每行一个词\n');
      }
      final jo = File('${dir.path}${Platform.pathSeparator}justone.txt');
      if (!jo.existsSync()) {
        jo.writeAsStringSync('# Just One 合作猜词 自定义词库（UTF-8）。每行一个词，例如：\n# 长城\n# 奶茶\n');
      }
      final wl = File('${dir.path}${Platform.pathSeparator}wavelength.txt');
      if (!wl.existsSync()) {
        wl.writeAsStringSync('# 频率猜心 自定义概念对（UTF-8）。每行：左概念|右概念，例如：\n# 冷|热\n# 小众|大众\n');
      }
    } catch (_) {}
  }
}

class AuroraServer {
  /// HTTP port (static web client + `/ws`); 0 = ephemeral (tests).
  final int port;
  final String serverName;
  HttpServer? _http;
  final Map<String, Client> _byToken = {};
  final Map<String, Room> rooms = {};
  int _nextId = 1;
  int _nextChatId = 1;
  final ChatReactions lobbyReactions = ChatReactions();
  final Random _rng = Random.secure();
  Timer? _sweeper;
  bool _roomListDirty = false;

  final Duration emptyTtl;
  final Duration sweepInterval;

  final ServerResources resources;
  final ServerIdentity identity;
  final Map<String, int> _connsPerIp = {};
  final Map<String, int> _pendingPerIp = {};

  /// LLM service passed to engines (null = none configured).
  final AiService? ai;

  /// Salt for pid = sha256(uid + salt).
  final String salt;
  final StatsStore stats;
  final ReplayStore replays;

  /// Public entry URL for invitations (behind NAT / reverse proxy); '' = the
  /// page's own origin.
  final String publicWebUrl;

  /// Auto-detected LAN URL (`http://<lan-ip>:<port>`) so a host opening
  /// `http://localhost:<port>` still gets phone-scannable QR codes.
  String lanWebUrl = '';

  /// Optional secret token unlocking the browser-based server admin panel.
  final String adminToken;

  /// Server start timestamp for `/health` and `/api/status`.
  final DateTime startedAt = DateTime.now();

  /// Extra game definitions (tests); looked up after the global registry.
  final List<GameDef> extraGames;

  /// IPs banned by the console `ban` command until restart.
  final Set<String> bannedIps = {};

  /// Built web client (`flutter build web` output) served over [port].
  final Directory? webDir;

  /// Take the client IP from X-Forwarded-For (only behind a trusted reverse proxy).
  final bool trustProxy;

  AuroraServer(this.port,
      {this.serverName = 'Aurora 服务器',
      this.emptyTtl = emptyRoomTtl,
      this.sweepInterval = const Duration(seconds: 5),
      Directory? resourceDir,
      ServerIdentity? identity,
      this.ai,
      String? salt,
      Directory? dataDir,
      Directory? replayDir,
      int replayKeep = 2000,
      this.extraGames = const [],
      this.webDir,
      this.trustProxy = false,
      this.publicWebUrl = '',
      this.adminToken = ''})
      : resources = ServerResources(resourceDir ?? Directory('words')),
        identity = identity ?? ServerIdentity.fromSeed(ServerIdentity.newSeed()),
        salt = salt ?? _randomHex(16),
        stats = StatsStore(dataDir),
        replays = ReplayStore(replayDir, keep: replayKeep);

  static String _randomHex(int bytes) {
    final r = Random.secure();
    return List.generate(bytes, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Iterable<GameDef> get allGames => [...gameRegistry, ...extraGames];

  GameDef? findDef(String id) {
    final g = findGame(id);
    if (g != null) return g;
    for (final x in extraGames) {
      if (x.id == id) return x;
    }
    return null;
  }

  /// Stable player id: first 16 hex of sha256(uid + salt); '' without uid.
  String pidFor(String uid) {
    if (uid.isEmpty || uid.length > 256) return '';
    return hash.sha256.convert(utf8.encode(uid + salt)).toString().substring(0, 16);
  }

  Iterable<Client> get onlineClients => _byToken.values.where((c) => c.online);

  /// Send to everyone in [c]'s chat channel: its room, or the lobby.
  void _chatBroadcast(Client c, Map<String, dynamic> msg) {
    final room = c.room;
    if (room != null) {
      room.broadcast(msg);
      return;
    }
    final bytes = encodeJson(msg);
    for (final o in onlineClients) {
      if (o.room == null) o.sendRaw(bytes);
    }
  }

  /// Binds the HTTP port (web client + `/ws`). Throws [SocketException] when
  /// the port can't be bound — it is the server's only listener.
  Future<void> start() async {
    final h = await HttpServer.bind(InternetAddress.anyIPv4, port);
    // No on-the-fly gzip: it would deflate the 19 MB main.dart.js on this
    // isolate (which also runs every live game) on every request. Static files
    // are served from a precompressed cache instead, see [_serveStatic].
    h.autoCompress = false;
    h.idleTimeout = const Duration(seconds: 30);
    _http = h;
    unawaited(_warmStaticCache());
    h.listen((req) => _onHttp(req).catchError((_) {
          try {
            req.response.statusCode = HttpStatus.internalServerError;
            req.response.close();
          } catch (_) {}
        }));
    _sweeper = Timer.periodic(sweepInterval, (_) => _sweep());
    try {
      final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      String? best;
      for (final iface in ifaces) {
        for (final a in iface.addresses) {
          if (a.isLoopback) continue;
          final ip = a.address;
          if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
            best ??= ip;
            if (ip.startsWith('192.168.')) {
              best = ip;
              break;
            }
          }
        }
      }
      if (best != null) lanWebUrl = 'http://$best:${h.port}';
    } catch (_) {}
    logLine('Aurora 网页服务器已启动，监听 HTTP ${h.port}'
        '${hasWebClient ? '' : '（未找到网页客户端文件 web 目录，浏览器只能看到提示页）'}');
  }

  /// Actual bound HTTP port (tests bind 0); [port] before [start].
  int get boundPort => _http?.port ?? port;

  /// True when [webDir] holds a built web client.
  bool get hasWebClient {
    final d = webDir;
    return d != null && File('${d.path}${Platform.pathSeparator}index.html').existsSync();
  }

  String _httpIp(HttpRequest req) {
    if (trustProxy) {
      final f = req.headers.value('x-forwarded-for');
      if (f != null && f.trim().isNotEmpty) return f.split(',').first.trim();
      final r = req.headers.value('x-real-ip');
      if (r != null && r.trim().isNotEmpty) return r.trim();
    }
    return req.connectionInfo?.remoteAddress.address ?? '';
  }

  Future<void> _onHttp(HttpRequest req) async {
    final res = req.response;
    final path = req.uri.path;
    if (path == '/health' || path == '/api/status') {
      res.headers
        ..set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8')
        ..set(HttpHeaders.cacheControlHeader, 'no-store');
      final up = DateTime.now().difference(startedAt).inSeconds;
      final a = ai;
      final body = path == '/health'
          ? {'status': 'ok', 'uptimeSec': up}
          : {
              'status': 'ok',
              'server': serverName,
              'online': onlineClients.length,
              'rooms': rooms.length,
              'playingRooms': rooms.values.where((r) => r.playing).length,
              'games': allGames.length,
              'ai': a != null && a.available,
              'uptimeSec': up,
            };
      res.write(jsonEncode(body));
      await res.close();
      return;
    }
    if (path == '/ws') {
      final ip = _httpIp(req);
      if (!WebSocketTransformer.isUpgradeRequest(req) || bannedIps.contains(ip)) {
        res.statusCode = HttpStatus.badRequest;
        await res.close();
        return;
      }
      final ws = await WebSocketTransformer.upgrade(req,
          compression: CompressionOptions.compressionOff, // payloads are encrypted: incompressible
          maxPayloadLength: kMaxFrame + 64);
      ws.pingInterval = const Duration(seconds: 20);
      _accept(_WebSocketWire(ws), ws.where((m) => m is List<int>).cast<List<int>>(), ip,
          req.connectionInfo?.remotePort ?? 0);
      return;
    }
    await _serveStatic(req);
  }

  static const _mime = {
    'html': 'text/html; charset=utf-8',
    'js': 'text/javascript; charset=utf-8',
    'mjs': 'text/javascript; charset=utf-8',
    'json': 'application/json; charset=utf-8',
    'css': 'text/css; charset=utf-8',
    'wasm': 'application/wasm',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'svg': 'image/svg+xml',
    'ico': 'image/x-icon',
    'otf': 'font/otf',
    'ttf': 'font/ttf',
    'woff2': 'font/woff2',
    'txt': 'text/plain; charset=utf-8',
    'md': 'text/plain; charset=utf-8',
  };

  static const _noCache = {'index.html', 'flutter_bootstrap.js', 'flutter_service_worker.js', 'version.json', 'manifest.json'};

  /// Extensions that are always revalidated (`no-cache` + ETag → cheap 304).
  /// File names are not content-hashed, and the deferred `main.dart.js_N.part.js`
  /// chunks / canvaskit glue must always match the `main.dart.js` that loaded
  /// them, so code must never be served stale from a max-age cache. `bin` is
  /// Flutter's AssetManifest.bin, which has to match the deployed assets.
  static const _revalidateExt = {'html', 'js', 'mjs', 'wasm', 'json', 'bin'};

  /// Long-lived cache for everything else (images, fonts, other assets).
  static const _assetCacheControl = 'public, max-age=604800';

  /// Extensions worth gzipping (text, wasm, uncompressed fonts).
  static const _compressibleExt = {'js', 'mjs', 'json', 'html', 'css', 'svg', 'txt', 'md', 'wasm', 'otf', 'ttf'};

  /// Extensionless text files from the Flutter build (assets/NOTICES, ~1.3 MB).
  static const _compressibleNames = {'NOTICES'};

  /// Below this size gzip saves (almost) nothing; serve as is.
  static const _minGzipBytes = 1024;

  /// Above this size files are streamed raw instead of being held in memory.
  static const _maxGzipBytes = 64 << 20;

  /// Precompressed gzip copies of static files, built off the main isolate.
  final _gzipCache = _GzipCache();
  bool _staticStopped = false;

  /// Cache-Control policy for a served file.
  static String _cacheControlFor(String name, String ext) =>
      _noCache.contains(name) || _revalidateExt.contains(ext) ? 'no-cache' : _assetCacheControl;

  /// Weak validator: the gzip and identity variants share it (they are
  /// semantically equivalent), which is exactly what weak ETags allow.
  static String _etagFor(FileStat st) =>
      'W/"${st.size.toRadixString(16)}-${st.modified.millisecondsSinceEpoch.toRadixString(16)}"';

  /// True when the request's validators say the client copy is current.
  /// If-None-Match takes precedence over If-Modified-Since (RFC 9110 §13.2.2).
  static bool _notModified(HttpRequest req, String etag, DateTime mtime) {
    final inm = req.headers[HttpHeaders.ifNoneMatchHeader];
    if (inm != null) {
      String opaque(String t) => t.startsWith('W/') ? t.substring(2) : t; // weak comparison
      final want = opaque(etag);
      return inm.expand((v) => v.split(',')).map((t) => t.trim()).any((t) => t == '*' || opaque(t) == want);
    }
    final ims = req.headers.value(HttpHeaders.ifModifiedSinceHeader);
    if (ims == null) return false;
    try {
      // HTTP dates have 1 s resolution
      return mtime.millisecondsSinceEpoch ~/ 1000 <= HttpDate.parse(ims).millisecondsSinceEpoch ~/ 1000;
    } catch (_) {
      return false;
    }
  }

  /// Whether Accept-Encoding allows gzip (honors `q=0` and `*`).
  static bool _acceptsGzip(HttpRequest req) {
    final values = req.headers[HttpHeaders.acceptEncodingHeader];
    if (values == null) return false;
    double? gz, star;
    for (final part in values.expand((v) => v.split(','))) {
      final bits = part.split(';');
      final coding = bits.first.trim().toLowerCase();
      var q = 1.0;
      for (final p in bits.skip(1)) {
        final kv = p.trim().toLowerCase();
        if (kv.startsWith('q=')) q = double.tryParse(kv.substring(2).trim()) ?? 0;
      }
      if (coding == 'gzip' || coding == 'x-gzip') {
        gz = max(gz ?? 0, q);
      } else if (coding == '*') {
        star = q;
      }
    }
    return (gz ?? star ?? 0) > 0;
  }

  /// Precompresses the big entry files in the background right after start,
  /// so even the first visitor gets gzip without waiting.
  Future<void> _warmStaticCache() async {
    final root = webDir;
    if (root == null || !hasWebClient) return;
    const warm = [
      'main.dart.js',
      'canvaskit/canvaskit.wasm',
      'canvaskit/chromium/canvaskit.wasm',
      'canvaskit/canvaskit.js',
      'canvaskit/chromium/canvaskit.js',
    ];
    for (final rel in warm) {
      if (_staticStopped) return;
      final f = File([root.path, ...rel.split('/')].join(Platform.pathSeparator));
      try {
        final st = await f.stat();
        if (st.type != FileSystemEntityType.file || st.size < _minGzipBytes || st.size > _maxGzipBytes) continue;
        await _gzipCache.get(f.path, st); // sequential: one compression isolate at a time
      } catch (_) {}
    }
  }

  Future<void> _serveStatic(HttpRequest req) async {
    final res = req.response;
    res.headers
      ..set('X-Content-Type-Options', 'nosniff')
      ..set('Referrer-Policy', 'no-referrer');
    if (req.method != 'GET' && req.method != 'HEAD') {
      res.statusCode = HttpStatus.methodNotAllowed;
      await res.close();
      return;
    }
    final sep = Platform.pathSeparator;
    final root = webDir;
    if (root == null || !hasWebClient) {
      res.headers.contentType = ContentType.html;
      res.write('<!doctype html><meta charset="utf-8"><title>Aurora</title>'
          '<p style="font:16px sans-serif;margin:40px">Aurora 服务器正在运行，但没有部署网页客户端。<br>'
          '请把网页客户端（webclient 目录下 flutter build web 生成的 build/web）放到服务器 exe 同目录的 <code>web</code> 文件夹，'
          '或用 <code>--web-dir</code> 指定其位置。</p>');
      await res.close();
      return;
    }
    // plain path segments only: no "..", separators, drive letters or NULs
    final segs = req.uri.pathSegments.where((p) => p.isNotEmpty).toList();
    if (segs.any((p) => p == '..' || p == '.' || p.contains(RegExp(r'[\\/:\x00]')))) {
      res.statusCode = HttpStatus.notFound;
      await res.close();
      return;
    }
    var f = File([root.path, ...segs].join(sep));
    if (segs.isEmpty || FileSystemEntity.isDirectorySync(f.path)) f = File('${f.path}${sep}index.html');
    if (!f.existsSync()) {
      if (segs.isNotEmpty && segs.last.contains('.')) {
        res.statusCode = HttpStatus.notFound;
        await res.close();
        return;
      }
      f = File('${root.path}${sep}index.html'); // unknown route: let the app handle it
    }
    final name = f.path.substring(f.path.lastIndexOf(sep) + 1);
    final ext = name.contains('.') ? name.substring(name.lastIndexOf('.') + 1).toLowerCase() : '';
    final st = await f.stat();
    if (st.type != FileSystemEntityType.file) {
      res.statusCode = HttpStatus.notFound;
      await res.close();
      return;
    }
    final etag = _etagFor(st);
    final compressible = _compressibleExt.contains(ext) || _compressibleNames.contains(name);
    res.headers
      ..set(HttpHeaders.contentTypeHeader, _mime[ext] ?? 'application/octet-stream')
      ..set(HttpHeaders.cacheControlHeader, _cacheControlFor(name, ext))
      ..set(HttpHeaders.etagHeader, etag)
      ..set(HttpHeaders.lastModifiedHeader, HttpDate.format(st.modified));
    if (compressible) res.headers.set(HttpHeaders.varyHeader, 'Accept-Encoding');
    if (_notModified(req, etag, st.modified)) {
      res.statusCode = HttpStatus.notModified;
      await res.close();
      return;
    }
    final head = req.method == 'HEAD';
    Uint8List? gz;
    if (compressible && st.size >= _minGzipBytes && st.size <= _maxGzipBytes && _acceptsGzip(req)) {
      if (head) {
        gz = _gzipCache.ready(f.path, st); // HEAD mirrors GET once cached, never waits
        if (gz == null) unawaited(_gzipCache.get(f.path, st));
      } else {
        // First request for this version waits for the background isolate
        // (~0.3 s for main.dart.js); the main isolate keeps serving meanwhile.
        gz = await _gzipCache.get(f.path, st).timeout(const Duration(seconds: 15), onTimeout: () => null);
      }
      if (gz != null && gz.length >= st.size) gz = null; // not worth it
    }
    // uncompressed byte count, used by the loading page's progress bar
    res.headers.set('X-Raw-Length', '${st.size}');
    if (gz != null) {
      res.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
      res.contentLength = gz.length;
      if (!head) res.add(gz);
    } else {
      res.contentLength = st.size;
      if (!head) await res.addStream(f.openRead(0, st.size));
    }
    await res.close();
  }

  Future<void> stop() async {
    _staticStopped = true;
    _sweeper?.cancel();
    await stats.flush();
    for (final r in rooms.values) {
      r.destroy();
    }
    for (final c in _byToken.values) {
      c.socket?.destroy();
    }
    await _http?.close(force: true);
  }

  void _sweep() {
    final now = DateTime.now();
    _pwFails.removeWhere((_, v) => now.difference(v.$2) >= passwordLockout);
    for (final c in _byToken.values.toList()) {
      if (c.online && now.difference(c.lastSeen) > idleTimeout) {
        logLine('${c.name} 超时断开');
        c.socket?.destroy();
        _onClosed(c, c.socket);
      }
      if (!c.online &&
          c.disconnectedAt != null &&
          now.difference(c.disconnectedAt!) > reconnectGrace) {
        _byToken.remove(c.token);
        c.room?.leave(c, silent: true);
      }
    }
    for (final r in rooms.values.toList()) {
      if (r.emptySince != null && now.difference(r.emptySince!) > emptyTtl) {
        logLine('房间 ${r.id}「${r.name}」无人超过3分钟，已销毁');
        for (final m in r.members.toList()) {
          _byToken.remove(m.token);
        }
        r.destroy();
        rooms.remove(r.id);
        _roomListDirty = true;
      }
    }
    if (_roomListDirty) pushRoomList();
  }

  /// Send the lobby room list to one client.
  void sendLobby(Client c) => c.send(_roomList());

  /// Console: system announcement to every online player.
  void announce(String text) {
    final chat = encodeJson({
      't': Msg.chatMsg,
      'from': 0,
      'name': '系统',
      'avatar': 0,
      'text': '【公告】$text',
      'ts': DateTime.now().millisecondsSinceEpoch,
      'system': true,
    });
    final toast = encodeJson({'t': Msg.toast, 'msg': '【公告】$text'});
    for (final c in onlineClients) {
      c.sendRaw(toast);
      c.sendRaw(chat);
    }
  }

  Client? clientById(int id) => _byToken.values.where((c) => c.id == id).firstOrNull;

  /// Console: disconnect a player (and optionally ban their IP until restart).
  bool kickClient(int id, {bool ban = false}) {
    final c = clientById(id);
    if (c == null) return false;
    if (ban && c.ip.isNotEmpty) bannedIps.add(c.ip);
    c.send({'t': Msg.error, 'msg': ban ? '你已被服务器封禁' : '你已被服务器管理员断开', 'fatal': true});
    final s = c.socket;
    _byToken.remove(c.token);
    c.room?.leave(c, silent: true);
    s?.destroy();
    _onClosed(c, s);
    return true;
  }

  /// Console / Web Admin: force-close a room and return its members to lobby.
  bool closeRoom(String id) {
    final r = rooms.remove(id.trim().toUpperCase());
    if (r == null) return false;
    final members = r.members.toList();
    r.destroy();
    for (final m in members) {
      m.room = null;
      m.send({'t': Msg.room, 'room': null});
      m.send({'t': Msg.toast, 'msg': '房间已被管理员关闭'});
      m.send(_roomList());
    }
    pushRoomList();
    return true;
  }

  void _handleAdmin(Client c, Map<String, dynamic> m) {
    if (adminToken.isEmpty) throw GameError('服务器未启用管理员密钥');
    final tok = asStr(m['token']).trim();
    if (tok.isEmpty || !_constEq(adminToken, tok)) {
      throw GameError('管理员密钥错误');
    }
    final cmd = asStr(m['cmd']);
    switch (cmd) {
      case 'state':
        break;
      case 'announce':
        final text = sanitizeText(asStr(m['text'])).trim();
        if (text.isEmpty) throw GameError('公告内容不能为空');
        announce(text);
        c.send({'t': Msg.toast, 'msg': '已发送全服公告'});
      case 'kick':
        final id = asInt(m['id'], 0);
        final ban = m['ban'] == true;
        if (!kickClient(id, ban: ban)) throw GameError('未找到玩家 #$id');
        c.send({'t': Msg.toast, 'msg': ban ? '已踢出并封禁 #$id' : '已踢出 #$id'});
      case 'unban':
        final ip = asStr(m['ip']).trim();
        bannedIps.remove(ip);
        c.send({'t': Msg.toast, 'msg': '已解封 $ip'});
      case 'close_room':
        final rid = asStr(m['room']).trim().toUpperCase();
        if (!closeRoom(rid)) throw GameError('房间 $rid 不存在');
        c.send({'t': Msg.toast, 'msg': '已关闭房间 $rid'});
      case 'reload_words':
        final counts = resources.reload();
        c.send({'t': Msg.toast, 'msg': '已热重载词库（共 ${counts.values.fold<int>(0, (a, b) => a + b)} 条）'});
      case 'save_words':
        final file = asStr(m['file']).trim();
        final content = asStr(m['content']);
        if (!resources.writeRawFile(file, content)) {
          throw GameError('保存词库 $file 失败');
        }
        c.send({'t': Msg.toast, 'msg': '已保存并热重载 $file'});
      case 'test_ai':
        final a = ai;
        if (a == null || !a.available) {
          throw GameError('AI 未启用或不可用（请在 .env 中配置 AI_PROVIDER 和 API Key）');
        }
        c.send({'t': Msg.toast, 'msg': '正在测试 AI 连接 (${a.label})…'});
        a.complete(const AiRequest(system: '只回复 OK', prompt: 'ping', maxTokens: 16)).then((reply) {
          if (!c.online) return;
          if (reply != null && reply.trim().isNotEmpty) {
            c.send({'t': Msg.toast, 'msg': 'AI 连接测试成功：${AiText.firstLine(reply, maxLen: 24)}'});
          } else {
            final err = a is HttpAiService && a.lastError.isNotEmpty ? a.lastError : '无响应';
            c.send({'t': Msg.error, 'msg': 'AI 连接测试失败：$err'});
          }
          _sendAdminState(c);
        });
        return;
      default:
        throw GameError('未知管理指令 $cmd');
    }
    _sendAdminState(c);
  }

  void _sendAdminState(Client c) {
    final a = ai;
    c.send({
      't': 'admin_state',
      'uptimeSec': DateTime.now().difference(startedAt).inSeconds,
      'aiStatus': a is HttpAiService ? a.status() : (a != null && a.available ? a.label : 'AI 未启用'),
      'bannedIps': bannedIps.toList(),
      'users': [
        for (final u in onlineClients)
          {
            'id': u.id,
            'name': u.name,
            'avatar': u.avatar,
            'ip': u.ip,
            'room': u.room?.id ?? '',
          }
      ],
      'rooms': [
        for (final r in rooms.values)
          {
            ...r.summary(),
            'private': r.private,
          }
      ],
      'words': resources.readRawFiles(),
    });
  }

  void pushRoomList() {
    _roomListDirty = false;
    final bytes = encodeJson(_roomList());
    for (final c in onlineClients) {
      if (c.room == null) c.sendRaw(bytes);
    }
  }

  Map<String, dynamic> _roomList() => {
        't': Msg.rooms,
        'rooms': [for (final r in rooms.values) if (!r.private) r.summary()],
        'online': onlineClients.length,
      };

  /// Runs the encrypted protocol on a new connection ([data] = raw frame bytes).
  void _accept(Wire s, Stream<List<int>> data, String ip, int remotePort) {
    final addr = '$ip:$remotePort';
    if (bannedIps.contains(ip)) {
      s.destroy();
      return;
    }
    if ((_connsPerIp[ip] ?? 0) >= maxConnectionsPerIp || (_pendingPerIp[ip] ?? 0) >= maxPendingPerIp) {
      s.destroy();
      return;
    }
    _connsPerIp[ip] = (_connsPerIp[ip] ?? 0) + 1;
    _pendingPerIp[ip] = (_pendingPerIp[ip] ?? 0) + 1;
    var pending = true;
    void donePending() {
      if (!pending) return;
      pending = false;
      final n = (_pendingPerIp[ip] ?? 1) - 1;
      if (n <= 0) {
        _pendingPerIp.remove(ip);
      } else {
        _pendingPerIp[ip] = n;
      }
    }

    var gone = false;
    void onGone() {
      if (gone) return;
      gone = true;
      donePending();
      final n = (_connsPerIp[ip] ?? 1) - 1;
      if (n <= 0) {
        _connsPerIp.remove(ip);
      } else {
        _connsPerIp[ip] = n;
      }
    }

    Client? client;
    SecureChannel? channel;
    final decoder = FrameDecoder();
    // unauthenticated sockets must finish key exchange + hello quickly
    final hsTimer = Timer(handshakeTimeout, () {
      if (client == null) s.destroy();
    });

    void kill() {
      hsTimer.cancel();
      s.destroy();
    }

    void sendSealed(Map<String, dynamic> msg) {
      final frame = encodeJson(msg);
      s.add(encodeFrame(kFrameJson, channel!.seal(kFrameJson, Uint8List.sublistView(frame, 5))));
    }

    data.listen(
      (bytes) {
        List<Frame> frames;
        try {
          frames = decoder.add(bytes);
        } catch (_) {
          kill();
          return;
        }
        for (final f in frames) {
          // 1) key exchange (the only plaintext frames)
          if (channel == null) {
            if (f.kind != kFrameJson || f.payload.length > 1024) return kill();
            try {
              final hello = f.json;
              if (hello['t'] == Msg.hello) {
                // protocol v1 client
                s.add(encodeJson({'t': Msg.error, 'msg': '客户端版本过旧，请刷新网页（Ctrl+F5）', 'fatal': true}));
                return kill();
              }
              final (reply, ch) = ServerHandshake(identity).respond(hello);
              channel = ch;
              s.add(encodeJson(reply));
            } catch (_) {
              return kill();
            }
            continue;
          }
          // 2) everything else is authenticated + encrypted
          Uint8List plain;
          try {
            plain = channel!.open(f.kind, f.payload);
          } catch (_) {
            logLine('$addr 发送了无法解密或被篡改的数据，已断开');
            return kill();
          }
          final pf = Frame(f.kind, plain);
          if (client == null) {
            if (pf.kind != kFrameJson) continue;
            try {
              client = _hello(s, channel!, pf.json, addr);
              hsTimer.cancel();
              donePending();
            } catch (e) {
              sendSealed({'t': Msg.error, 'msg': e is String ? e : '登录失败', 'fatal': true});
              return kill();
            }
            continue;
          }
          final c = client!;
          if (c.socket != s) return; // superseded by a reconnect
          c.lastSeen = DateTime.now();
          if (pf.kind == kFrameVoice) {
            _relayVoice(c, pf.payload);
          } else if (pf.kind == kFrameJson) {
            Map<String, dynamic> msg;
            try {
              msg = pf.json;
            } catch (_) {
              continue;
            }
            _dispatch(c, msg, pf.payload.length);
          }
        }
      },
      onDone: () {
        onGone();
        _onClosed(client, s);
      },
      onError: (_) {
        onGone();
        _onClosed(client, s);
      },
      cancelOnError: true,
    );
  }

  Client _hello(Wire s, SecureChannel ch, Map<String, dynamic> m, String addr) {
    if (m['t'] != Msg.hello) throw '协议错误';
    if (asInt(m['ver'], 0) != kProtocolVersion) {
      throw '网页版本与服务器不匹配，请刷新网页（Ctrl+F5）';
    }
    final name = asStr(m['name']).trim();
    final err = validateName(name);
    if (err != null) throw err;
    var token = asStr(m['token']);
    if (token.length > 128) token = '';
    var c = token.isNotEmpty ? _byToken[token] : null;
    final ip = addr.contains(':') ? addr.substring(0, addr.lastIndexOf(':')) : addr;
    if (c == null) {
      // no (valid) token, e.g. page reloaded or browser restarted: same name
      // from the same IP is the same person, so they get their seat back
      final same = _sameName(name, ip);
      if (same != null && same.online && DateTime.now().difference(same.lastSeen) < duplicateLoginStale) {
        throw '名称「$name」已在线（同一网络下有人正在使用），请修改名称后再连接';
      }
      c = same;
    }
    final reconnect = c != null;
    if (c != null && c.online) {
      // same identity connecting again: kick the old socket
      c.socket?.destroy();
    }
    if (c == null) {
      if (_byToken.length >= maxClients) {
        // drop the oldest offline identity; refuse if everyone is online
        final victim = _byToken.values.where((x) => !x.online).fold<Client?>(
            null, (a, b) => a == null || b.disconnectedAt!.isBefore(a.disconnectedAt!) ? b : a);
        if (victim == null) throw '服务器人数已满';
        _byToken.remove(victim.token);
        victim.room?.leave(victim, silent: true);
      }
      token = List.generate(32, (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      c = Client(_nextId++, token);
      _byToken[token] = c;
    }
    c
      ..socket = s
      ..channel = ch
      ..name = name
      ..avatar = asInt(m['avatar'], 1).clamp(1, kAvatarCount)
      ..lastSeen = DateTime.now()
      ..disconnectedAt = null
      ..address = addr
      ..pid = pidFor(asStr(m['uid']).trim());
    logLine('${c.name} (#${c.id}) 已连接 $addr${reconnect ? "（重连）" : ""}');
    c.send(_welcome(c));
    final room = c.room;
    if (room != null && rooms.containsKey(room.id)) {
      room.onMemberOnline(c);
    } else {
      c.room = null;
      c.send(_roomList());
    }
    return c;
  }

  /// The identity using [name] from [ip], if any.
  Client? _sameName(String name, String ip, {Client? except}) {
    if (ip.isEmpty) return null;
    return _byToken.values.where((x) => x != except && x.name == name && x.ip == ip).firstOrNull;
  }

  Map<String, dynamic> _welcome(Client c) {
    final a = ai;
    final aiOn = a != null && a.available;
    return {
      't': Msg.welcome,
      'id': c.id,
      'token': c.token,
      'name': c.name,
      'avatar': c.avatar,
      'server': serverName,
      'games': [for (final g in allGames) g.toJson()],
      'ai': aiOn,
      'aiLabel': aiOn ? a.label : '',
      'pid': c.pid,
      'publicWebUrl': publicWebUrl,
      'lanWebUrl': lanWebUrl,
      'hasAdmin': adminToken.isNotEmpty,
    };
  }

  void _onClosed(Client? c, Wire? s) {
    if (c == null || c.socket != s || s == null) return;
    c.socket = null;
    c.channel = null;
    c.disconnectedAt = DateTime.now();
    logLine('${c.name} (#${c.id}) 断开连接');
    c.room?.onMemberOffline(c);
    pushRoomList();
  }

  void _relayVoice(Client c, Uint8List audio) {
    final room = c.room;
    if (room == null || audio.length > 16000 || !c.allowVoice(audio.length)) return;
    final out = Uint8List(4 + audio.length);
    ByteData.sublistView(out).setUint32(0, c.id);
    out.setRange(4, out.length, audio);
    final frame = encodeFrame(kFrameVoice, out);
    Set<int>? allowed;
    final e = room.engine;
    if (e != null && !e.isOver) {
      try {
        allowed = e.voiceListeners(room.gameSeatOf(c));
      } catch (_) {
        allowed = null;
      }
    }
    for (final m in room.members) {
      if (m == c) continue;
      if (allowed != null) {
        final gs = room.gameSeatOf(m);
        // spectators hear everyone; players only if the game allows it
        if (gs >= 0 && !allowed.contains(gs)) continue;
      }
      m.sendRaw(frame);
    }
  }

  final Map<String, (int, DateTime)> _pwFails = {};

  static bool _constEq(String a, String b) {
    final x = utf8.encode(a), y = utf8.encode(b);
    var d = x.length ^ y.length;
    for (var i = 0; i < max(x.length, y.length); i++) {
      d |= (i < x.length ? x[i] : 0) ^ (i < y.length ? y[i] : 0);
    }
    return d == 0;
  }

  static const _idChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  /// Random 5-char room code (A-Z, 0-9), always mixing letters and digits.
  String _newRoomId() {
    for (;;) {
      final id = String.fromCharCodes(List.generate(5, (_) => _idChars.codeUnitAt(_rng.nextInt(_idChars.length))));
      final hasL = id.contains(RegExp('[A-Z]')), hasD = id.contains(RegExp('[0-9]'));
      if (hasL && hasD && !rooms.containsKey(id)) return id;
    }
  }

  void _dispatch(Client c, Map<String, dynamic> m, [int rawLen = 0]) {
    final t = m['t'];
    if (t != Msg.ping && !c.allowMsg()) return; // flood: silently drop
    try {
      switch (t) {
        case Msg.ping:
          c.send({'t': Msg.pong, 'ts': m['ts']});
        case Msg.setProfile:
          final name = asStr(m['name']).trim();
          final err = validateName(name);
          if (err != null) throw GameError(err);
          final other = _sameName(name, c.ip, except: c);
          if (other != null && other.online) throw GameError('名称「$name」已在线（同一网络下有人正在使用），请换一个');
          c.name = name;
          c.avatar = asInt(m['avatar'], c.avatar).clamp(1, kAvatarCount);
          c.send(_welcome(c));
          c.room?.pushRoom();
        case Msg.listRooms:
          c.send(_roomList());
        case Msg.createRoom:
          if (rooms.length >= maxRooms) throw GameError('服务器房间数已满');
          if (rooms.values.where((r) => r.hostId == c.id && r.members.any((m) => m.online)).length >= maxRoomsPerClient) {
            throw GameError('你创建的房间太多了');
          }
          if (c.room != null) c.room!.leave(c);
          final game = findDef(asStr(m['game'])) ?? gameRegistry.first;
          var name = asStr(m['name']).trim();
          if (name.isEmpty) name = '${c.name}的房间';
          if (nameWidth(name) > 32) throw GameError('房间名过长');
          if (hasIllegalChars(name)) throw GameError('房间名包含非法字符');
          if (asStr(m['password']).length > 32) throw GameError('密码过长');
          final room = Room(this, _newRoomId(), name, asStr(m['password']),
              c.id, game.id, game.normalizeOptions(_optMap(m['options'])),
              private: m['private'] == true);
          rooms[room.id] = room;
          logLine('${c.name} 创建了房间 ${room.id}「$name」(${game.name})');
          room.join(c);
          room.seats[0].client = c;
          room.pushRoom();
        case Msg.joinRoom:
          final code = asStr(m['room']).trim().toUpperCase();
          if (code.length > 16) throw GameError('房间号无效');
          final room = rooms[code];
          if (room == null) throw GameError('房间不存在');
          if (room.isKicked(c) && c.room != room) throw GameError('你被房主移出了该房间，请稍后再试');
          if (room.password.isNotEmpty && c.room != room) {
            final key = '${c.ip}|${room.id}';
            final f = _pwFails[key];
            final now = DateTime.now();
            if (f != null && f.$1 >= maxPasswordFailures && now.difference(f.$2) < passwordLockout) {
              throw GameError('密码错误次数过多，请稍后再试');
            }
            if (!_constEq(room.password, asStr(m['password']))) {
              final n = (f == null || now.difference(f.$2) >= passwordLockout) ? 1 : f.$1 + 1;
              _pwFails[key] = (n, now);
              throw GameError('房间密码错误');
            }
            _pwFails.remove(key);
          }
          if (c.room == room) {
            room.pushRoom();
            room.pushGame(c);
            return;
          }
          c.room?.leave(c);
          room.join(c);
          // auto-sit if a seat is free and no game running, unless the player
          // chose to watch
          if (!room.playing && m['spectate'] != true) {
            final free = room.seats.indexWhere((s) => s.empty);
            if (free >= 0) room.sit(c, free);
          }
        case Msg.leaveRoom:
          c.room?.leave(c);
          c.send({'t': Msg.room, 'room': null});
          c.send(_roomList());
        case Msg.chat:
          var text = sanitizeText(asStr(m['text'])).trim();
          if (text.isEmpty) return;
          if (!c.allowChat()) throw GameError('发言太快了，请稍后再试');
          if (text.length > 500) text = text.substring(0, 500);
          final id = _nextChatId++;
          final msg = {
            't': Msg.chatMsg,
            'id': id,
            'from': c.id,
            'name': c.name,
            'avatar': c.avatar,
            'text': text,
            'ts': DateTime.now().millisecondsSinceEpoch,
            'system': false,
          };
          final room = c.room;
          (room?.reactions ?? lobbyReactions).track(id);
          _chatBroadcast(c, msg);
        case Msg.react:
          final id = asInt(m['id']), e = asInt(m['e']);
          if (!c.allowChat()) throw GameError('操作太快了，请稍后再试');
          final on = (c.room?.reactions ?? lobbyReactions).toggle(id, e, c.id);
          _chatBroadcast(c, {'t': Msg.reactMsg, 'id': id, 'e': e, 'from': c.id, 'name': c.name, 'on': on});
        case Msg.listReplays:
          c.send({'t': Msg.replays, 'replays': replays.list(pid: m['mine'] == true ? c.pid : null)});
        case Msg.getReplay:
          final rid = asStr(m['id']);
          replays.chunks(rid).then((ch) {
            if (ch == null) {
              c.send({'t': Msg.error, 'msg': '回放不存在或已被删除'});
              return;
            }
            for (var i = 0; i < ch.length; i++) {
              c.send({'t': Msg.replayChunk, 'id': rid, 'i': i, 'n': ch.length, 'data': ch[i]});
            }
          });
        case Msg.myStats:
          c.send({'t': Msg.stats, 'stats': stats.statsFor(c.pid)});
        case Msg.leaderboard:
          final g = asStr(m['game']);
          c.send({'t': Msg.board, 'game': g, 'rows': stats.leaderboard(g)});
        case 'admin':
          _handleAdmin(c, m);
        default:
          final room = c.room;
          if (room == null) throw GameError('你不在房间中');
          switch (t) {
            case Msg.sit:
              room.sit(c, asInt(m['seat']));
            case Msg.stand:
              room.stand(c);
            case Msg.ready:
              room.setReady(c, asBool(m['ready']));
            case Msg.setPrivate:
              room.setPrivate(c, asBool(m['private']));
            case Msg.setTimeout:
              room.setTurnTimeout(c, asInt(m['sec'], 0));
            case Msg.partyConfig:
              room.configureParty(c, m['queue']);
            case Msg.partyVote:
              room.voteParty(c, asStr(m['game']));
            case Msg.partyNext:
              room.nextParty(c);
            case Msg.setGame:
              room.setGame(c, asStr(m['game']), _optMap(m['options']));
            case Msg.addBot:
              room.addBot(c, asInt(m['seat']));
            case Msg.removeSeat:
              room.removeSeat(c, asInt(m['seat']));
            case Msg.start:
              room.startGame(c);
            case Msg.abort:
              room.abortGame(c);
            case Msg.setRoomOpts:
              room.setRoomOpts(c, m);
            case Msg.emote:
              room.emote(c, asInt(m['e']));
            case Msg.autoPlay:
              room.autoPlay(c, asBool(m['on']));
            case Msg.resign:
              room.resign(c);
            case Msg.request:
              room.makeRequest(c, asStr(m['kind']));
            case Msg.respond:
              room.respond(c, asInt(m['id']), asBool(m['yes']));
            case Msg.kick:
              room.kick(c, asInt(m['id']));
            case Msg.action:
              final a = m['a'];
              if (a is! Map<String, dynamic>) throw GameError('无效操作');
              if (rawLen > maxActionBytes) throw GameError('操作数据过大');
              room.gameAction(c, a);
            default:
              throw GameError('未知消息 $t');
          }
      }
    } on GameError catch (e) {
      c.send({'t': Msg.error, 'msg': e.message});
    } catch (e, st) {
      logLine('error handling $t from ${c.name}: $e\n$st');
      c.send({'t': Msg.error, 'msg': '服务器内部错误，操作未生效'});
    }
  }

  static Map<String, dynamic>? _optMap(Object? o) => o is Map<String, dynamic> ? o : null;

  List<String> describeRooms() => [
        for (final r in rooms.values)
          '${r.id}「${r.name}」${r.def.name} 成员${r.members.where((m) => m.online).length} ${r.playing ? "对局中" : "等待中"}'
      ];
}

/// One cached gzip copy, valid for a specific (mtime, size) of the source.
class _GzEntry {
  _GzEntry(this.mtimeMs, this.size);
  final int mtimeMs;
  final int size;
  late final Future<Uint8List?> future;
  Uint8List? data;

  bool matches(FileStat st) => st.modified.millisecondsSinceEpoch == mtimeMs && st.size == size;
}

/// Precompressed gzip copies of static files keyed by path and invalidated by
/// (mtime, size). Deflating runs in [Isolate.run] so the main isolate — which
/// also runs every live game — never compresses megabytes itself; concurrent
/// requests for the same file share one pending Future. Completed entries are
/// kept LRU-ordered and evicted beyond [_GzipCache.maxBytes].
class _GzipCache {
  /// Memory budget for completed gzip copies (a full build is ~20 MB).
  static const maxBytes = 192 << 20;

  final Map<String, _GzEntry> _entries = {}; // insertion order = LRU order
  int _bytes = 0;

  /// The gzip bytes if they are already built for this version, else null.
  Uint8List? ready(String path, FileStat st) {
    final e = _entries[path];
    if (e == null || !e.matches(st) || e.data == null) return null;
    _touch(path, e);
    return e.data;
  }

  /// Gzip bytes for [path] at version [st]; null when the file changed while
  /// being read or compression failed (callers then serve it raw).
  Future<Uint8List?> get(String path, FileStat st) {
    final old = _entries[path];
    if (old != null) {
      if (old.matches(st)) {
        _touch(path, old);
        return old.future;
      }
      _drop(path);
    }
    final e = _GzEntry(st.modified.millisecondsSinceEpoch, st.size);
    _entries[path] = e;
    e.future = _compress(path, st.size).then<Uint8List?>((gz) {
      if (!identical(_entries[path], e)) return gz; // superseded or evicted meanwhile
      if (gz == null) {
        _entries.remove(path);
        return null;
      }
      e.data = gz;
      _bytes += gz.length;
      _evict();
      return gz;
    }, onError: (Object _) {
      if (identical(_entries[path], e)) _entries.remove(path);
      return null;
    });
    return e.future;
  }

  static Future<Uint8List?> _compress(String path, int size) => Isolate.run(() {
        final raw = File(path).readAsBytesSync();
        if (raw.length != size) return null; // file is being replaced; retry on a later request
        final out = gzip.encode(raw);
        return out is Uint8List ? out : Uint8List.fromList(out);
      });

  void _touch(String path, _GzEntry e) {
    _entries.remove(path);
    _entries[path] = e;
  }

  void _drop(String path) {
    final e = _entries.remove(path);
    final d = e?.data;
    if (d != null) _bytes -= d.length;
  }

  void _evict() {
    while (_bytes > maxBytes) {
      String? victim;
      for (final MapEntry(:key, :value) in _entries.entries) {
        if (value.data != null) {
          victim = key;
          break;
        }
      }
      if (victim == null) return;
      _drop(victim);
    }
  }
}
