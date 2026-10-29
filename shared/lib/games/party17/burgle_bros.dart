import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';

class BurgleBrosRoomInfo {
  final int id;
  final String name;
  final String emoji;
  final String desc;
  const BurgleBrosRoomInfo(this.id, this.name, this.emoji, this.desc);
}

const List<BurgleBrosRoomInfo> kBurgleBrosRooms = [
  BurgleBrosRoomInfo(0, '大厅', '🚪', '潜入起点，安全区域'),
  BurgleBrosRoomInfo(1, '金库保险箱', '🔐', '加骰并掷出同行同列密码即可破译金库（+25分）'),
  BurgleBrosRoomInfo(2, '逃生直升机', '🪜', '破译金库后在此撤离（+15分）'),
  BurgleBrosRoomInfo(3, '红外警报', '🚨', '未骇入时进入会触发警报，吸引保安并提速'),
  BurgleBrosRoomInfo(4, '监控室', '📷', '未骇入时进入会触发警报，吸引保安并提速'),
  BurgleBrosRoomInfo(5, '电脑室', '💻', '消耗1AP骇入（+1骇客标记，自动屏蔽警报）'),
  BurgleBrosRoomInfo(6, '暗室', '🤫', '隐蔽死角，在此停留更安全'),
  BurgleBrosRoomInfo(7, '实验室', '🧪', '首次探索获得科研支援（+5分并恢复1潜行）'),
];

class BurgleBrosGame extends GameEngine {
  BurgleBrosGame(super.setup);

  late int maxRounds;
  int round = 1;
  int turn = 0;
  int apLeft = 4;
  String phase = 'act'; // 'act' | 'over'

  /// 4x4 grid of room types (0..7).
  late List<List<int>> rooms;

  /// 4x4 grid of safe combination digits (1..6).
  late List<List<int>> roomNums;

  /// 4x4 grid of revealed status.
  late List<List<bool>> revealed;

  /// 4x4 grid of visited status for Lab bonus.
  late List<List<bool>> labVisited;

  /// Vertical walls: vWalls[r][c] is wall between (r, c) and (r, c+1), size 4x3.
  late List<List<bool>> vWalls;

  /// Horizontal walls: hWalls[r][c] is wall between (r, c) and (r+1, c), size 3x4.
  late List<List<bool>> hWalls;

  /// Player positions [r, c].
  late List<List<int>> playerPos;

  /// Stealth tokens per player (starts at 3).
  late List<int> stealth;

  /// Scores per player.
  late List<int> scores;

  /// Escaped status per player.
  late List<bool> escaped;

  /// Caught/eliminated status.
  late List<bool> eliminated;

  /// Guard position and target [r, c], plus speed (2..4).
  List<int> guardPos = [0, 3];
  List<int> guardTarget = [3, 0];
  int guardSpeed = 2;
  List<List<int>> lastGuardPath = [];

  /// Shared hack tokens from Computer room (💻).
  int hackTokens = 0;

  /// Safe cracking state.
  int safeDice = 1;
  bool safeCracked = false;
  int lootCarrier = -1;
  Set<int> crackedDigits = <int>{};
  List<int> lastRoll = <int>[];
  int crackAttempts = 0;

  bool heistWon = false;
  String lastEvent = '神偷小队潜入银行大厅，准备搜寻金库与逃生梯！';

  @override
  bool get isOver => phase == 'over';

  @override
  bool get canResign => true;

  @override
  List<int>? get placings {
    if (!isOver) return null;
    final adjusted = <num>[
      for (var s = 0; s < players; s++)
        eliminated[s] ? -1000 + scores[s] : scores[s] + (escaped[s] ? 20 : 0) + stealth[s] * 3,
    ];
    return rankByScore(adjusted);
  }

  @override
  List<int> get waitingFor {
    if (isOver) return const [];
    if (!_isSeatActive(turn)) return const [];
    return [turn];
  }

  bool _isSeatActive(int s) => s >= 0 && s < players && !escaped[s] && !eliminated[s];

  @override
  void start() {
    final mode = setup.opt<String>('mode', 'standard');
    maxRounds = mode == 'fast' ? 8 : 11;
    round = 1;
    turn = 0;
    apLeft = 4;
    phase = 'act';

    stealth = List<int>.filled(players, 3);
    scores = List<int>.filled(players, 0);
    escaped = List<bool>.filled(players, false);
    eliminated = List<bool>.filled(players, false);
    playerPos = [for (var i = 0; i < players; i++) [3, 0]];

    _initBankFloor();
    host.log('【神偷小队】潜行行动开始！全员位于 (3,0) 🚪大厅，携带 3 枚潜行标记。');
  }

  void _initBankFloor() {
    // Deck of 16 rooms: (3,0) is Foyer (0), (0,3) is Escape (2), one middle/far room is Safe (1)
    final pool = <int>[
      3, 3, // Laser
      4, 4, // Camera
      5, 5, // Hack
      6, 6, 6, // Deadbolt
      7, 7, 7, 7, // Lab
    ]..shuffle(rng);

    // Pick Safe position among coordinates at distance >= 2 from (3,0) excluding (0,3)
    final safeCandidates = <List<int>>[
      [0, 1],
      [0, 2],
      [1, 1],
      [1, 2],
      [1, 3],
      [2, 2],
      [2, 3],
    ];
    final safeCell = safeCandidates[rng.nextInt(safeCandidates.length)];

    rooms = List.generate(4, (_) => List<int>.filled(4, 0));
    var idx = 0;
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        if (r == 3 && c == 0) {
          rooms[r][c] = 0; // Foyer
        } else if (r == 0 && c == 3) {
          rooms[r][c] = 2; // Escape
        } else if (r == safeCell[0] && c == safeCell[1]) {
          rooms[r][c] = 1; // Safe
        } else {
          rooms[r][c] = pool[idx++];
        }
      }
    }

    roomNums = List.generate(
      4,
      (r) => List.generate(4, (c) => ((r * 2 + c + rng.nextInt(6)) % 6) + 1),
    );
    revealed = List.generate(4, (_) => List<bool>.filled(4, false));
    labVisited = List.generate(4, (_) => List<bool>.filled(4, false));
    revealed[3][0] = true;
    revealed[0][3] = true;

    // Generate walls while keeping the 4x4 grid connected
    vWalls = List.generate(4, (_) => List<bool>.filled(3, false));
    hWalls = List.generate(3, (_) => List<bool>.filled(4, false));
    _generateConnectedWalls();

    guardPos = [0, 3];
    guardTarget = [0, 0];
    guardSpeed = 2;
    lastGuardPath = [
      [0, 3],
    ];
    hackTokens = 0;
    safeDice = 1;
    safeCracked = false;
    lootCarrier = -1;
    crackedDigits = <int>{};
    lastRoll = <int>[];
    crackAttempts = 0;
  }

  void _generateConnectedWalls() {
    final candidates = <(bool, int, int)>[];
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 3; c++) {
        candidates.add((true, r, c));
      }
    }
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 4; c++) {
        candidates.add((false, r, c));
      }
    }
    candidates.shuffle(rng);
    var placed = 0;
    for (final (isV, r, c) in candidates) {
      if (placed >= 5) break;
      if (isV) {
        vWalls[r][c] = true;
        if (!_isGridFullyConnected()) {
          vWalls[r][c] = false;
        } else {
          placed++;
        }
      } else {
        hWalls[r][c] = true;
        if (!_isGridFullyConnected()) {
          hWalls[r][c] = false;
        } else {
          placed++;
        }
      }
    }
  }

  bool _isGridFullyConnected() {
    final visited = List.generate(4, (_) => List<bool>.filled(4, false));
    final q = Queue<(int, int)>()..add((0, 0));
    visited[0][0] = true;
    var count = 1;
    while (q.isNotEmpty) {
      final (r, c) = q.removeFirst();
      for (final (nr, nc) in neighborsOf(r, c)) {
        if (!visited[nr][nc]) {
          visited[nr][nc] = true;
          count++;
          q.add((nr, nc));
        }
      }
    }
    return count == 16;
  }

  bool isConnected(int r1, int c1, int r2, int c2) {
    if (r1 < 0 || r1 >= 4 || c1 < 0 || c1 >= 4) return false;
    if (r2 < 0 || r2 >= 4 || c2 < 0 || c2 >= 4) return false;
    if ((r1 - r2).abs() + (c1 - c2).abs() != 1) return false;
    if (r1 == r2) {
      final minC = min(c1, c2);
      return !vWalls[r1][minC];
    } else {
      final minR = min(r1, r2);
      return !hWalls[minR][c1];
    }
  }

  List<(int, int)> neighborsOf(int r, int c) {
    const dirs = [
      (-1, 0),
      (1, 0),
      (0, -1),
      (0, 1),
    ];
    final out = <(int, int)>[];
    for (final (dr, dc) in dirs) {
      final nr = r + dr;
      final nc = c + dc;
      if (isConnected(r, c, nr, nc)) {
        out.add((nr, nc));
      }
    }
    return out;
  }

  (int, int) findSafePos() {
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        if (rooms[r][c] == 1) return (r, c);
      }
    }
    return (1, 2);
  }

  (int, int) findEscapePos() {
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        if (rooms[r][c] == 2) return (r, c);
      }
    }
    return (0, 3);
  }

  List<int> get safeDigits {
    final (sr, sc) = findSafePos();
    final set = <int>{};
    for (var i = 0; i < 4; i++) {
      if (i != sc) set.add(roomNums[sr][i]);
      if (i != sr) set.add(roomNums[i][sc]);
    }
    if (set.isEmpty) set.add(roomNums[sr][sc]);
    final list = set.toList()..sort();
    return list;
  }

  List<List<int>> shortestPath(int sr, int sc, int tr, int tc) {
    if (sr == tr && sc == tc) return [];
    final q = Queue<List<List<int>>>();
    final seen = List.generate(4, (_) => List<bool>.filled(4, false));
    seen[sr][sc] = true;
    q.add([
      [sr, sc],
    ]);
    while (q.isNotEmpty) {
      final path = q.removeFirst();
      final cur = path.last;
      for (final (nr, nc) in neighborsOf(cur[0], cur[1])) {
        if (seen[nr][nc]) continue;
        final nextPath = [
          ...path,
          [nr, nc],
        ];
        if (nr == tr && nc == tc) {
          return nextPath.sublist(1);
        }
        seen[nr][nc] = true;
        q.add(nextPath);
      }
    }
    return [];
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('对局已结束');
    if (seat != turn) throw GameError('当前还未轮到你行动');

    final type = asStr(action['type']);
    final pr = playerPos[seat][0];
    final pc = playerPos[seat][1];

    if (type == 'peek') {
      if (apLeft < 1) throw GameError('行动点（AP）不足');
      final r = asInt(action['r']);
      final c = asInt(action['c']);
      if (!isConnected(pr, pc, r, c)) {
        throw GameError('只能侦察相邻且无墙壁阻挡的房间');
      }
      if (revealed[r][c]) {
        throw GameError('该房间已被翻开');
      }
      apLeft -= 1;
      revealed[r][c] = true;
      scores[seat] += 2;
      final info = kBurgleBrosRooms[rooms[r][c]];
      lastEvent = '${name(seat)} 侦察了 ($r,$c)：发现 ${info.emoji}${info.name}（密码 #${roomNums[r][c]}）！';
      host.log(lastEvent);
      return;
    }

    if (type == 'move') {
      if (apLeft < 1) throw GameError('行动点（AP）不足');
      final r = asInt(action['r']);
      final c = asInt(action['c']);
      if (!isConnected(pr, pc, r, c)) {
        throw GameError('只能移动到相邻且无墙壁阻挡的房间');
      }
      apLeft -= 1;
      playerPos[seat] = [r, c];
      final newlyRevealed = !revealed[r][c];
      if (newlyRevealed) {
        revealed[r][c] = true;
        scores[seat] += 2;
      }
      final rType = rooms[r][c];
      final info = kBurgleBrosRooms[rType];
      final notes = <String>['${name(seat)} 移动至 ($r,$c) ${info.emoji}${info.name}'];

      // Alarm check (Laser 3 / Camera 4)
      if (rType == 3 || rType == 4) {
        if (hackTokens > 0) {
          hackTokens -= 1;
          scores[seat] += 3;
          notes.add('💻消耗1枚骇客标记成功屏蔽警报（+3分）');
        } else {
          guardTarget = [r, c];
          guardSpeed = min(4, guardSpeed + 1);
          notes.add('🚨触发警报！保安目标锁定 ($r,$c)，移速升至 $guardSpeed');
        }
      } else if (rType == 7 && !labVisited[r][c]) {
        labVisited[r][c] = true;
        scores[seat] += 5;
        if (stealth[seat] < 3) stealth[seat] += 1;
        notes.add('🧪首次探索实验室获得 +5 分与潜行补给');
      }

      // Stepping into Guard's tile
      if (guardPos[0] == r && guardPos[1] == c) {
        _spotPlayer(seat, notes);
      }

      // Escape check on Helipad (room 2) once safeCracked
      if (rType == 2 && safeCracked && !escaped[seat]) {
        escaped[seat] = true;
        scores[seat] += 15;
        if (lootCarrier == seat) scores[seat] += 10;
        notes.add('🚁成功登上直升机携带战利品撤离（+15分）！');
      }

      lastEvent = '${notes.join('；')}。';
      host.log(lastEvent);
      _checkGameEnd();
      if (!isOver && ! _isSeatActive(seat)) {
        _advanceTurnAfterGuard(runGuard: false);
      }
      return;
    }

    if (type == 'hack') {
      if (apLeft < 1) throw GameError('行动点（AP）不足');
      if (rooms[pr][pc] != 5) throw GameError('只能在 💻电脑室 执行骇入');
      if (hackTokens >= 3) throw GameError('骇客标记已达上限（3枚）');
      apLeft -= 1;
      hackTokens += 1;
      scores[seat] += 3;
      lastEvent = '${name(seat)} 在电脑室植入骇客程序（当前骇客标记：$hackTokens，+3分）！';
      host.log(lastEvent);
      return;
    }

    if (type == 'add_die') {
      if (apLeft < 1) throw GameError('行动点（AP）不足');
      if (rooms[pr][pc] != 1) throw GameError('只能在 🔐金库保险箱 旁安装破译骰');
      if (safeCracked) throw GameError('金库保险箱已经破译');
      if (safeDice >= 6) throw GameError('破译骰数量已达上限（6颗）');
      final cost = apLeft >= 2 ? 2 : 1;
      apLeft -= cost;
      safeDice += 1;
      scores[seat] += 3;
      lastEvent = '${name(seat)} 在金库加装破译骰（当前共 $safeDice 颗骰子，+3分）！';
      host.log(lastEvent);
      return;
    }

    if (type == 'crack') {
      if (apLeft < 1) throw GameError('行动点（AP）不足');
      if (rooms[pr][pc] != 1) throw GameError('只能在 🔐金库保险箱 旁尝试破译');
      if (safeCracked) throw GameError('金库保险箱已经破译');
      apLeft -= 1;
      crackAttempts += 1;
      lastRoll = [for (var i = 0; i < safeDice; i++) rng.nextInt(6) + 1];
      final needed = safeDigits;
      final newlyCracked = <int>[];
      for (final d in lastRoll) {
        if (needed.contains(d) && !crackedDigits.contains(d)) {
          crackedDigits.add(d);
          newlyCracked.add(d);
        }
      }
      // Guarantee progress on high roll or repeated attempts so games never stall
      if (newlyCracked.isEmpty && (lastRoll.contains(6) || crackAttempts >= 2)) {
        final rem = needed.where((d) => !crackedDigits.contains(d)).toList();
        if (rem.isNotEmpty) {
          crackedDigits.add(rem.first);
          newlyCracked.add(rem.first);
        }
      }
      scores[seat] += newlyCracked.length * 4;
      if (needed.every(crackedDigits.contains)) {
        safeCracked = true;
        lootCarrier = seat;
        scores[seat] += 25;
        lastEvent =
            '${name(seat)} 掷出 $lastRoll，完全破译金库密码 $needed！夺得金库大奖（+25分），快前往 🪜逃生梯 撤离！';
      } else {
        lastEvent =
            '${name(seat)} 掷出 $lastRoll，已破译密码 ${crackedDigits.toList()..sort()} / $needed。';
      }
      host.log(lastEvent);
      return;
    }

    if (type == 'end_turn') {
      _advanceTurnAfterGuard(runGuard: true);
      return;
    }

    throw GameError('未知操作类型：$type');
  }

  void _spotPlayer(int s, List<String> notes) {
    if (escaped[s] || eliminated[s]) return;
    stealth[s] = max(0, stealth[s] - 1);
    notes.add('👮保安发现 ${name(s)}（潜行剩余 ${stealth[s]}）');
  }

  void _advanceTurnAfterGuard({required bool runGuard}) {
    final notes = <String>[];
    if (runGuard) {
      lastGuardPath = [
        [guardPos[0], guardPos[1]],
      ];
      for (var step = 0; step < guardSpeed; step++) {
        if (guardPos[0] == guardTarget[0] && guardPos[1] == guardTarget[1]) {
          _pickNextGuardTarget();
        }
        final path = shortestPath(guardPos[0], guardPos[1], guardTarget[0], guardTarget[1]);
        if (path.isEmpty) break;
        guardPos = [path.first[0], path.first[1]];
        lastGuardPath.add([guardPos[0], guardPos[1]]);
        for (var s = 0; s < players; s++) {
          if (_isSeatActive(s) &&
              playerPos[s][0] == guardPos[0] &&
              playerPos[s][1] == guardPos[1]) {
            _spotPlayer(s, notes);
          }
        }
        if (guardPos[0] == guardTarget[0] && guardPos[1] == guardTarget[1]) {
          _pickNextGuardTarget();
        }
      }
      if (notes.isEmpty) {
        lastEvent = '👮保安巡逻移动至 (${guardPos[0]},${guardPos[1]})，目标 (${guardTarget[0]},${guardTarget[1]})。';
      } else {
        lastEvent = '👮保安巡逻至 (${guardPos[0]},${guardPos[1]})：${notes.join('，')}！';
      }
      host.log(lastEvent);
    }

    _checkGameEnd();
    if (isOver) return;

    // Advance to next active player
    for (var i = 1; i <= players; i++) {
      final next = (turn + i) % players;
      if (next <= turn) {
        round += 1;
      }
      if (_isSeatActive(next)) {
        turn = next;
        apLeft = 4;
        break;
      }
    }
    _checkGameEnd();
  }

  void _pickNextGuardTarget() {
    final corners = <List<int>>[
      [0, 0],
      [0, 3],
      [3, 0],
      [3, 3],
      [1, 1],
      [2, 2],
    ].where((c) => c[0] != guardPos[0] || c[1] != guardPos[1]).toList();
    guardTarget = List<int>.of(corners[rng.nextInt(corners.length)]);
  }

  void _checkGameEnd() {
    if (phase == 'over') return;
    // Check if all active players escaped
    final anyActive = [for (var s = 0; s < players; s++) _isSeatActive(s)].any((x) => x);
    final anyZeroStealth = [for (var s = 0; s < players; s++) stealth[s] <= 0 && !escaped[s]].any((x) => x);

    if (!anyActive || anyZeroStealth || round > maxRounds) {
      phase = 'over';
      heistWon = safeCracked && escaped.any((e) => e);
      host.log('【神偷小队】行动结束！${heistWon ? "小队成功劫掠金库并撤离！" : "警报封锁，行动终止！"}');
    }
  }

  @override
  void resign(int seat) {
    if (isOver || seat < 0 || seat >= players) return;
    eliminated[seat] = true;
    scores[seat] = -100;
    host.log('${name(seat)} 选择认输退出潜行。');
    _checkGameEnd();
    if (!isOver && turn == seat) {
      _advanceTurnAfterGuard(runGuard: false);
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || seat != turn) return null;
    if (apLeft <= 0) return {'type': 'end_turn'};

    final pr = playerPos[seat][0];
    final pc = playerPos[seat][1];
    final curRoom = rooms[pr][pc];

    // 1. If on Safe and not cracked yet: add die or crack
    if (curRoom == 1 && !safeCracked) {
      if (safeDice < 3 && apLeft >= 2) {
        return {'type': 'add_die'};
      }
      return {'type': 'crack'};
    }

    // 2. If on Computer room and hackTokens < 2: hack
    if (curRoom == 5 && hackTokens < 2) {
      return {'type': 'hack'};
    }

    // 3. Peek any adjacent unrevealed room if safe is not revealed yet
    final (sr, sc) = findSafePos();
    final adj = neighborsOf(pr, pc);
    for (final (nr, nc) in adj) {
      if (!revealed[nr][nc]) {
        return {'type': 'peek', 'r': nr, 'c': nc};
      }
    }

    // 4. Move toward goal: if safeCracked -> Escape (2), else -> Safe (1)
    final (tr, tc) = safeCracked ? findEscapePos() : (sr, sc);
    final path = shortestPath(pr, pc, tr, tc);
    if (path.isNotEmpty) {
      final next = path.first;
      // Avoid stepping directly onto Guard if only 1 stealth left and can end turn
      if (next[0] == guardPos[0] && next[1] == guardPos[1] && stealth[seat] <= 1) {
        return {'type': 'end_turn'};
      }
      return {'type': 'move', 'r': next[0], 'c': next[1]};
    }

    return {'type': 'end_turn'};
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'round': round,
      'maxRounds': maxRounds,
      'turn': turn,
      'apLeft': apLeft,
      'phase': phase,
      'rooms': [
        for (var r = 0; r < 4; r++)
          [
            for (var c = 0; c < 4; c++) revealed[r][c] || isOver ? rooms[r][c] : -1,
          ],
      ],
      'roomNums': [
        for (var r = 0; r < 4; r++)
          [
            for (var c = 0; c < 4; c++) revealed[r][c] || isOver ? roomNums[r][c] : 0,
          ],
      ],
      'revealed': [
        for (var r = 0; r < 4; r++) List<bool>.of(revealed[r]),
      ],
      'vWalls': [
        for (var r = 0; r < 4; r++) List<bool>.of(vWalls[r]),
      ],
      'hWalls': [
        for (var r = 0; r < 3; r++) List<bool>.of(hWalls[r]),
      ],
      'playerPos': [
        for (var s = 0; s < players; s++) List<int>.of(playerPos[s]),
      ],
      'stealth': List<int>.of(stealth),
      'scores': List<int>.of(scores),
      'escaped': List<bool>.of(escaped),
      'guardPos': List<int>.of(guardPos),
      'guardTarget': List<int>.of(guardTarget),
      'guardSpeed': guardSpeed,
      'lastGuardPath': [for (final p in lastGuardPath) List<int>.of(p)],
      'hackTokens': hackTokens,
      'safeDice': safeDice,
      'safeCracked': safeCracked,
      'lootCarrier': lootCarrier,
      'safeDigits': safeDigits,
      'crackedDigits': crackedDigits.toList()..sort(),
      'lastRoll': List<int>.of(lastRoll),
      'heistWon': heistWon,
      'lastEvent': lastEvent,
      'canAct': seat == turn && !isOver,
    };
  }
}
