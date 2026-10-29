import '../../src/engine.dart';
import 'tiles.dart';

class FujianResult {
  final int fan;
  final int swimMult; // 1 = normal, 2 = 单游, 4 = 双游, 8 = 三游
  final bool isBig;
  final List<(String, int)> items;
  const FujianResult(this.fan, this.swimMult, this.isBig, this.items);

  String get label => [for (final (n, _) in items) n].join(' ');
  List<List<Object>> toJson() => [for (final (n, f) in items) [n, f]];
}

/// Checks whether a 13-tile (after discard) concealed hand + [melds] has at least 1
/// [goldTile] and the remaining tiles form `4 - melds.length` complete sets (using any
/// extra [goldTile]s as wildcards), so the lone [goldTile] waits on ALL 34 tiles!
bool canSwimAfterDiscard(List<int> handAfterDiscard, List<Meld> melds, int goldTile) {
  final needSets = 4 - melds.length;
  if (needSets < 0 || countTotal(handAfterDiscard) != needSets * 3 + 1) return false;
  if (goldTile < 0 || goldTile >= handAfterDiscard.length || handAfterDiscard[goldTile] < 1) {
    return false;
  }
  final c = List<int>.of(handAfterDiscard);
  c[goldTile]--; // 1 Gold tile acts as the universal pair wait
  final wild = c[goldTile];
  c[goldTile] = 0;
  return canSetsWild(c, 0, wild);
}

/// Evaluates a Fujian Youjin Mahjong hand (136 tiles, [goldTile] is universal wildcard).
FujianResult? fujianEvaluate(
  List<int> concealed,
  List<Meld> melds, {
  required int goldTile,
  int swimState = 0,
  bool selfDrawn = false,
  bool sanJinDao = false,
  bool gangKai = false,
  bool qiangGang = false,
}) {
  final total = countTotal(concealed);
  final needSets = 4 - melds.length;

  final goldCount = (goldTile >= 0 && goldTile < concealed.length) ? concealed[goldTile] : 0;

  // 1. 三金倒: holding 3 Gold tiles in hand allows an immediate self-draw win regardless of remaining tiles!
  final hasSanJinDao = selfDrawn && (sanJinDao || goldCount >= 3);

  // 2. 游金 / 双游 / 三游: if swimState >= 1 and self-drawn, ANY drawn tile wins!
  final hasSwimWin = selfDrawn && swimState >= 1;

  if (!hasSanJinDao && !hasSwimWin && (needSets < 0 || total != needSets * 3 + 2)) return null;

  final c = List<int>.of(concealed);
  if (goldTile >= 0 && goldTile < c.length) {
    c[goldTile] = 0;
  }
  final stdWin = canAnyPairStandardWild(c, goldCount);
  final qidui = melds.isEmpty && canSevenPairsWild(c, goldCount);
  final pengpeng = melds.every((m) => !m.isChi) && canPengPengWild(c, goldCount);

  if (!stdWin && !qidui && !hasSanJinDao && !hasSwimWin) return null;

  final suits = <int>{};
  var hasHonor = false;
  for (var t = 0; t < c.length; t++) {
    if (c[t] == 0) continue;
    if (t < kNumKinds) {
      suits.add(t ~/ 9);
    } else {
      hasHonor = true;
    }
  }
  for (final m in melds) {
    for (final t in m.tiles) {
      if (t == goldTile) continue;
      if (t < kNumKinds) {
        suits.add(t ~/ 9);
      } else {
        hasHonor = true;
      }
    }
  }
  final qingyise = !hasHonor && suits.length <= 1 && (stdWin || qidui);

  final items = <(String, int)>[];
  var swimMult = 1;
  if (hasSwimWin) {
    if (swimState >= 3) {
      items.add(('三游', 16));
      swimMult = 8;
    } else if (swimState == 2) {
      items.add(('双游', 8));
      swimMult = 4;
    } else {
      items.add(('单游', 4));
      swimMult = 2;
    }
  }
  if (hasSanJinDao) {
    items.add(('三金倒', 8));
    if (swimMult < 4) swimMult = 4;
  }
  if (qingyise) items.add(('清一色', 4));
  if (pengpeng && (stdWin || hasSwimWin)) items.add(('碰碰胡', 2));
  if (qidui && !pengpeng) items.add(('七对', 4));
  if (gangKai) items.add(('杠上开花', 2));
  if (qiangGang) items.add(('抢杠胡', 2));
  if (goldCount == 0 && items.isEmpty) items.add(('无金平胡', 2));
  if (items.isEmpty) items.add(('平胡', 1));
  if (selfDrawn && !hasSwimWin && !hasSanJinDao) items.add(('自摸', 1));

  final isBig = hasSwimWin || hasSanJinDao || qingyise || pengpeng || qidui || gangKai || qiangGang;
  final fan = items.fold<int>(0, (a, b) => a + b.$2);
  return FujianResult(fan, swimMult, isBig, items);
}

List<int> fujianWaits(
  List<int> concealed,
  List<Meld> melds, {
  required int goldTile,
  int swimState = 0,
}) {
  if (swimState >= 1 || canSwimAfterDiscard(concealed, melds, goldTile)) {
    return List<int>.generate(kKinds, (i) => i);
  }
  final out = <int>[];
  for (var t = 0; t < kKinds && t < concealed.length; t++) {
    concealed[t]++;
    final r = fujianEvaluate(concealed, melds, goldTile: goldTile, swimState: swimState, selfDrawn: true);
    concealed[t]--;
    if (r != null) out.add(t);
  }
  return out;
}

class _FjClaim {
  final int tile;
  final int from;
  final bool rob;
  final Map<int, Set<String>> opts;
  final Map<int, List<int>> chis;
  final Map<int, FujianResult> hu;
  final Map<int, Map<String, dynamic>> resp = {};
  _FjClaim(this.tile, this.from, this.rob, this.opts, {this.chis = const {}, this.hu = const {}});
  List<int> get pending => [for (final s in opts.keys) if (!resp.containsKey(s)) s]..sort();
}

class _FjDiscard {
  final int tile;
  bool taken = false;
  final bool tsumogiri;
  final bool swimDeclare;
  _FjDiscard(this.tile, {this.tsumogiri = false, this.swimDeclare = false});
}

/// 福建游金麻将 (fujianmj)
class FujianGame extends GameEngine {
  FujianGame(super.setup);

  late final int totalRounds = setup.opt<int>('rounds', 4);

  late List<int> scores = List.filled(players, 0);
  int handNo = 0;
  int dealer = 0;
  bool over = false;
  List<Map<String, dynamic>> history = [];

  // Fujian-specific state
  int goldTileId = 0;
  String get goldTile => tileCode(goldTileId);
  List<int> swimState = [0, 0, 0, 0]; // 0=无, 1=单游(×2), 2=双游(×4), 3=三游(×8)

  // Hand state
  String phase = 'act'; // act, claim, settle, over, pause
  String pausedPhase = '';
  List<List<int>> hands = [];
  List<List<Meld>> melds = [];
  List<List<_FjDiscard>> discards = [];
  List<int> drawn = [];
  List<int> wall = [];
  int turn = 0;
  bool canZimo = false;
  bool afterKong = false;
  int lastDiscardSeat = -1;
  String lastAction = '';
  Map<String, dynamic>? lastEvent;
  int eventSeq = 0;
  _FjClaim? claim;
  List<int> handDelta = [];
  List<Map<String, dynamic>> events = [];
  Map<String, dynamic>? settle;
  Set<int> ready = {};
  int nextDealer = -1;

  void _event(String t, int seat, [int tile = -1]) {
    lastEvent = {'t': t, 'seat': seat, if (tile >= 0) 'tile': tileCode(tile)};
    eventSeq++;
  }

  int seatWind(int s) => (s - dealer + players) % players;

  static String swimLabel(int st) => switch (st) {
        1 => '单游',
        2 => '双游',
        3 => '三游',
        _ => '游金',
      };

  @override
  void start() {
    dealer = rng.nextInt(players);
    _startHand();
  }

  void _startHand() {
    handNo++;
    wall = <int>[for (var t = 0; t < kKinds; t++) for (var k = 0; k < 4; k++) t]..shuffle(rng);
    hands = List.generate(players, (_) => List.filled(kKinds, 0));
    melds = List.generate(players, (_) => <Meld>[]);
    discards = List.generate(players, (_) => <_FjDiscard>[]);
    swimState = List.filled(players, 0);
    drawn = List.filled(players, -1);
    handDelta = List.filled(players, 0);
    events = [];
    settle = null;
    claim = null;
    afterKong = false;
    lastDiscardSeat = -1;
    nextDealer = -1;

    for (var i = 0; i < 13; i++) {
      for (var s = 0; s < players; s++) {
        hands[s][wall.removeLast()]++;
      }
    }
    final extra = wall.removeLast();
    hands[dealer][extra]++;
    drawn[dealer] = extra;

    // 开金: flip 1 tile from the wall as goldTile (universal wildcard in hand)
    goldTileId = wall.removeLast();

    turn = dealer;
    phase = 'act';
    canZimo = true;
    host.log('第 $handNo/$totalRounds 局开始，${name(dealer)} 坐庄，开金：${tileName(goldTileId)}');
    lastAction = '金牌：${tileName(goldTileId)} · ${name(dealer)} 出牌';
  }

  bool _draw(int s, {bool kong = false}) {
    turn = s;
    if (wall.isEmpty) {
      _drawnGame();
      return false;
    }
    final t = wall.removeLast();
    hands[s][t]++;
    drawn[s] = t;
    phase = 'act';
    canZimo = true;
    afterKong = kong;
    return true;
  }

  void _coverPause(void Function() next) {
    final ms = claimCoverDelayMs(rng);
    if (ms == 0) {
      next();
      return;
    }
    pausedPhase = phase;
    phase = 'pause';
    host.schedule(ms, () {
      if (phase != 'pause') return;
      phase = pausedPhase;
      next();
    });
  }

  bool canSanJinDao(int s) =>
      phase == 'act' && turn == s && canZimo && goldTileId >= 0 && hands[s][goldTileId] >= 3;

  /// Tiles [s] can discard to declare or advance 游金 ('swim').
  List<int> swimTiles(int s) {
    if (phase != 'act' || turn != s || swimState[s] >= 3) return const [];
    final nonGold = <int>[];
    final gold = <int>[];
    for (var t = 0; t < kKinds; t++) {
      if (hands[s][t] <= 0) continue;
      hands[s][t]--;
      final ok = canSwimAfterDiscard(hands[s], melds[s], goldTileId);
      hands[s][t]++;
      if (ok) {
        if (t == goldTileId) {
          gold.add(t);
        } else {
          nonGold.add(t);
        }
      }
    }
    return [...nonGold, ...gold];
  }

  FujianResult? selfEval(int s, {bool sanJinDao = false}) => fujianEvaluate(
        hands[s],
        melds[s],
        goldTile: goldTileId,
        swimState: swimState[s],
        selfDrawn: true,
        sanJinDao: sanJinDao,
        gangKai: afterKong,
      );

  FujianResult? ronEval(int o, int t, {bool rob = false}) {
    if (t == goldTileId) return null;
    // In Fujian Mahjong, when any player is in 双游/三游 (or the player themselves is swimming),
    // winning is by self-draw rather than Ron.
    if (swimState[o] >= 1 || swimState.any((st) => st >= 2)) return null;
    final c = List<int>.of(hands[o]);
    c[t]++;
    return fujianEvaluate(
      c,
      melds[o],
      goldTile: goldTileId,
      swimState: swimState[o],
      selfDrawn: false,
      qiangGang: rob,
    );
  }

  bool get canSelfHu => phase == 'act' && canZimo && selfEval(turn) != null;

  /// Normal 4-of-a-kind kongs available to turn player: (tile, isBuGang).
  List<(int, bool)> selfKongs() {
    if (phase != 'act' || wall.isEmpty) return const [];
    final s = turn;
    final out = <(int, bool)>[];
    for (var t = 0; t < kKinds; t++) {
      if (t == goldTileId) continue;
      if (hands[s][t] == 4) out.add((t, false));
      if (hands[s][t] >= 1 && melds[s].any((m) => m.isPeng && m.tile == t)) out.add((t, true));
    }
    return out;
  }

  List<int> chiOptions(int s, int t) {
    if (t >= kNumKinds || t == goldTileId || swimState[s] > 0) return const [];
    final h = hands[s];
    final r = rankOf(t);
    final out = <int>[];
    for (var lo = t - 2; lo <= t; lo++) {
      final lr = r - (t - lo);
      if (lr < 1 || lr > 7) continue;
      var ok = true;
      for (var k = lo; k < lo + 3; k++) {
        if (k == goldTileId) ok = false;
        if (k != t && h[k] == 0) ok = false;
      }
      if (ok) out.add(lo);
    }
    return out;
  }

  List<int> legalDiscards(int s) => [for (var t = 0; t < kKinds; t++) if (hands[s][t] > 0) t];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? rankByScore(scores) : null;

  @override
  int get botDelayMs => phase == 'claim' ? 500 : 700;

  @override
  List<int> get waitingFor {
    switch (phase) {
      case 'act':
        return [turn];
      case 'claim':
        return claim!.pending;
      case 'settle':
        return [for (var s = 0; s < players; s++) if (!ready.contains(s)) s];
      default:
        return const [];
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> a) {
    if (over) throw GameError('对局已结束');
    if (seat < 0 || seat >= players) throw GameError('你不在座位上');
    final type = asStr(a['type']);
    switch (phase) {
      case 'act':
        if (seat != turn) throw GameError('还没轮到你');
        _handleAct(seat, type, a);
        return;
      case 'claim':
        _handleClaim(seat, type, a);
        return;
      case 'settle':
        if (type != 'next') throw GameError('请等待下一局');
        ready.add(seat);
        if (ready.length >= players) _nextHand();
        return;
    }
    throw GameError('现在不能操作');
  }

  void _handleAct(int s, String type, Map<String, dynamic> a) {
    if (type == 'sanjindao') {
      if (!canSanJinDao(s)) throw GameError('手牌未满三张金牌，不能三金倒');
      final r = selfEval(s, sanJinDao: true)!;
      final t = drawn[s] >= 0 && hands[s][drawn[s]] > 0 ? drawn[s] : goldTileId;
      _settleWin({s: (t, r)}, -1);
      return;
    }
    if (type == 'hu') {
      final r = canZimo ? selfEval(s) : null;
      if (r == null) throw GameError('现在不能胡牌');
      final t = drawn[s] >= 0 && hands[s][drawn[s]] > 0 ? drawn[s] : _anyTile(s);
      _settleWin({s: (t, r)}, -1);
      return;
    }
    if (type == 'swim') {
      final sts = swimTiles(s);
      if (sts.isEmpty) throw GameError('当前手牌不能声明游金');
      var t = tileFromCode(a['tile']);
      if (t < 0 || !sts.contains(t)) {
        if (a['tile'] == null) {
          t = sts.first;
        } else {
          throw GameError('打出该张牌后无法形成单金游金听口');
        }
      }
      swimState[s] = (swimState[s] + 1).clamp(1, 3);
      final label = swimLabel(swimState[s]);
      host.log('${name(s)} 宣布【$label】（×${1 << swimState[s]}），金牌单钓听全牌！');
      _discard(s, t, swimDeclare: true);
      return;
    }
    if (type == 'gang') {
      final t = tileFromCode(a['tile']);
      final k = selfKongs().where((e) => e.$1 == t).toList();
      if (k.isEmpty) throw GameError('不能杠这张牌');
      _selfKong(s, t, k.first.$2);
      return;
    }
    if (type == 'discard') {
      final t = tileFromCode(a['tile']);
      if (t < 0 || t >= kKinds || hands[s][t] <= 0) throw GameError('你没有这张牌');
      // If discarding without 'swim' breaks the swim wait, reset swimState
      hands[s][t]--;
      final keepSwim = swimState[s] > 0 && canSwimAfterDiscard(hands[s], melds[s], goldTileId);
      hands[s][t]++;
      if (!keepSwim) swimState[s] = 0;
      _discard(s, t);
      return;
    }
    throw GameError('请出牌');
  }

  int _anyTile(int s) {
    for (var t = kKinds - 1; t >= 0; t--) {
      if (t != goldTileId && hands[s][t] > 0) return t;
    }
    return goldTileId;
  }

  void _discard(int s, int t, {bool swimDeclare = false}) {
    hands[s][t]--;
    final giri = drawn[s] == t;
    drawn[s] = -1;
    discards[s].add(_FjDiscard(t, tsumogiri: giri, swimDeclare: swimDeclare));
    canZimo = false;
    afterKong = false;
    lastDiscardSeat = s;
    lastAction = swimDeclare
        ? '${name(s)} ${swimLabel(swimState[s])}（×${1 << swimState[s]}）打出 ${tileName(t)}'
        : '${name(s)} 打出 ${tileName(t)}';
    _event(swimDeclare ? 'riichi' : 'discard', s, t);

    // When a player declares 游金/双游/三游 (or discards goldTile), skip opponent meld claims
    if (swimDeclare || t == goldTileId) {
      _coverPause(() => _draw((s + 1) % players));
      return;
    }

    final opts = <int, Set<String>>{};
    final chis = <int, List<int>>{};
    final hu = <int, FujianResult>{};
    for (var o = 0; o < players; o++) {
      if (o == s) continue;
      final set = <String>{};
      final r = ronEval(o, t);
      if (r != null) {
        set.add('hu');
        hu[o] = r;
      }
      if (wall.isNotEmpty && swimState[o] == 0) {
        if (hands[o][t] >= 2) set.add('peng');
        if (hands[o][t] >= 3) set.add('gang');
        if (o == (s + 1) % players) {
          final c = chiOptions(o, t);
          if (c.isNotEmpty) {
            set.add('chi');
            chis[o] = c;
          }
        }
      }
      if (set.isNotEmpty) opts[o] = set;
    }
    if (opts.isEmpty) {
      _coverPause(() => _draw((s + 1) % players));
    } else {
      claim = _FjClaim(t, s, false, opts, chis: chis, hu: hu);
      phase = 'claim';
    }
  }

  int _prio(String type) => switch (type) { 'hu' => 30, 'gang' || 'peng' => 20, 'chi' => 10, _ => 0 };

  int _maxPrio(_FjClaim c, int s) {
    var best = 0;
    for (final o in c.opts[s]!) {
      final p = _prio(o);
      if (p > best) best = p;
    }
    return best;
  }

  void _handleClaim(int s, String type, Map<String, dynamic> a) {
    final c = claim!;
    final o = c.opts[s];
    if (o == null) throw GameError('你没有可执行的操作');
    if (c.resp.containsKey(s)) throw GameError('你已经选择了');
    if (type != 'pass' && !o.contains(type)) throw GameError('不能执行该操作');
    final r = <String, dynamic>{'type': type};
    if (type == 'chi') {
      final lo = tileFromCode(a['tile']);
      final list = c.chis[s] ?? const [];
      r['lo'] = list.contains(lo) ? lo : list.first;
    }
    c.resp[s] = r;
    final pend = c.pending;
    final huDeclared = c.resp.values.any((e) => e['type'] == 'hu');
    if (huDeclared) {
      if (pend.any((p) => c.opts[p]!.contains('hu'))) return;
    } else {
      var best = 0;
      for (final e in c.resp.values) {
        final p = _prio(e['type'] as String);
        if (p > best) best = p;
      }
      if (pend.any((p) => _maxPrio(c, p) > best)) return;
    }
    _resolveClaim();
  }

  void _resolveClaim() {
    final c = claim!;
    claim = null;
    final hus = [
      for (var i = 1; i < players; i++)
        if (c.resp[(c.from + i) % players]?['type'] == 'hu') (c.from + i) % players
    ];
    if (hus.isNotEmpty) {
      if (c.rob) {
        hands[c.from][c.tile]--;
      } else {
        discards[c.from].last.taken = true;
      }
      final wins = {for (final h in hus) h: (c.tile, c.hu[h]!)};
      _settleWin(wins, c.from, rob: c.rob);
      return;
    }
    if (c.rob) {
      _finishBuGang(c.from, c.tile);
      return;
    }
    var bestSeat = -1, best = 0;
    for (final e in c.resp.entries) {
      final p = _prio(e.value['type'] as String);
      if (p > best) {
        best = p;
        bestSeat = e.key;
      }
    }
    if (bestSeat < 0) {
      _draw((c.from + 1) % players);
      return;
    }
    final r = c.resp[bestSeat]!;
    final type = r['type'] as String;
    final s = bestSeat;
    discards[c.from].last.taken = true;
    if (type == 'gang') {
      hands[s][c.tile] -= 3;
      melds[s].add(Meld('mgang', c.tile, claimed: c.tile, from: c.from));
      lastAction = '${name(s)} 明杠 ${tileName(c.tile)}';
      host.log(lastAction);
      _event('gang', s, c.tile);
      _draw(s, kong: true);
      return;
    }
    if (type == 'peng') {
      hands[s][c.tile] -= 2;
      melds[s].add(Meld('peng', c.tile, claimed: c.tile, from: c.from));
      lastAction = '${name(s)} 碰 ${tileName(c.tile)}';
      _event('peng', s, c.tile);
    } else {
      final lo = r['lo'] as int;
      for (var k = lo; k < lo + 3; k++) {
        if (k != c.tile) hands[s][k]--;
      }
      melds[s].add(Meld('chi', lo, claimed: c.tile, from: c.from));
      lastAction = '${name(s)} 吃 ${tileName(c.tile)}';
      _event('chi', s, c.tile);
    }
    turn = s;
    phase = 'act';
    canZimo = false;
    afterKong = false;
    drawn[s] = -1;
  }

  void _selfKong(int s, int t, bool bu) {
    if (bu) {
      final opts = <int, Set<String>>{};
      final hu = <int, FujianResult>{};
      for (var o = 0; o < players; o++) {
        if (o == s) continue;
        final r = ronEval(o, t, rob: true);
        if (r != null) {
          opts[o] = {'hu'};
          hu[o] = r;
        }
      }
      if (opts.isNotEmpty) {
        claim = _FjClaim(t, s, true, opts, hu: hu);
        phase = 'claim';
        lastAction = '${name(s)} 补杠 ${tileName(t)}';
        _event('bugang', s, t);
        return;
      }
      _finishBuGang(s, t);
      return;
    }
    hands[s][t] -= 4;
    melds[s].add(Meld('agang', t));
    lastAction = '${name(s)} 暗杠 ${tileName(t)}';
    host.log(lastAction);
    _event('gang', s);
    _draw(s, kong: true);
  }

  void _finishBuGang(int s, int t) {
    hands[s][t]--;
    final m = melds[s].firstWhere((m) => m.isPeng && m.tile == t);
    m.kind = 'bgang';
    lastAction = '${name(s)} 补杠 ${tileName(t)}';
    host.log(lastAction);
    _event('gang', s, t);
    _draw(s, kong: true);
  }

  void _pay(int from, int to, int amt) {
    scores[from] -= amt;
    scores[to] += amt;
    handDelta[from] -= amt;
    handDelta[to] += amt;
  }

  void _settleWin(Map<int, (int, FujianResult)> wins, int from, {bool rob = false}) {
    final zimo = from < 0;
    for (final e in wins.entries) {
      final w = e.key;
      final (tile, res) = e.value;
      if (zimo && hands[w][tile] > 0) hands[w][tile]--;
      drawn[w] = -1;
      final payers = zimo ? [for (var o = 0; o < players; o++) if (o != w) o] : [from];
      final pay = <String, int>{};
      var totalWon = 0;
      for (final p in payers) {
        var amt = res.fan * res.swimMult * (zimo ? 2 : 1);
        if (w == dealer || p == dealer) amt *= 2;
        _pay(p, w, amt);
        pay['$p'] = amt;
        totalWon += amt;
      }
      events.add({
        'kind': 'hu',
        'seat': w,
        'from': from,
        'tile': tileCode(tile),
        'zimo': zimo,
        'rob': rob,
        'big': res.isBig,
        'fan': res.fan,
        'mult': res.swimMult,
        'total': totalWon,
        'items': res.toJson(),
        'pay': pay,
        'hand': codesOfCounts(hands[w]),
      });
      host.log(zimo
          ? '${name(w)} 自摸 ${tileName(tile)}！${res.label}（×${res.swimMult}）'
          : '${name(w)} 胡 ${name(from)} 的 ${tileName(tile)}！${res.label}');
      _event(zimo ? 'zimo' : 'hu', w, tile);
    }
    lastAction = zimo ? '${name(wins.keys.first)} 自摸' : '${wins.keys.map(name).join('、')} 胡牌';
    nextDealer = wins.length == 1 ? wins.keys.first : from;
    _endHand();
  }

  void _drawnGame() {
    host.log('牌山摸完，流局');
    lastAction = '流局';
    nextDealer = dealer;
    _endHand();
  }

  void _endHand() {
    claim = null;
    settle = {
      'hand': handNo,
      'events': events,
      'chajiao': [for (final e in events) if (e['kind'] != 'hu') e],
      'win': events.any((e) => e['kind'] == 'hu'),
      'delta': List.of(handDelta),
      'dealer': dealer,
      'goldTile': goldTile,
    };
    history.add({'hand': handNo, 'delta': List.of(handDelta)});
    ready = {};
    if (handNo >= totalRounds) {
      phase = 'over';
      over = true;
      final order = ranking();
      host.log('全部 $totalRounds 局结束！${[
        for (var i = 0; i < order.length; i++) '第${i + 1} ${name(order[i])} ${scores[order[i]]}'
      ].join('，')}');
    } else {
      phase = 'settle';
    }
  }

  List<int> ranking() => List.generate(players, (i) => i)..sort((a, b) => scores[b].compareTo(scores[a]));

  void _nextHand() {
    if (nextDealer >= 0) dealer = nextDealer;
    _startHand();
  }

  @override
  Map<String, dynamic> view(int seat) {
    final reveal = phase == 'settle' || phase == 'over';
    final seats = <Map<String, dynamic>>[];
    for (var s = 0; s < players; s++) {
      final n = countTotal(hands[s]);
      final hasDrawn = phase == 'act' && turn == s && drawn[s] >= 0 && hands[s][drawn[s]] > 0;
      seats.add({
        'count': n,
        'drawn': hasDrawn,
        'hand': s == seat || reveal ? codesOfCounts(hands[s]) : null,
        'melds': [for (final m in melds[s]) m.toJson(hide: m.concealed && s != seat && !reveal)],
        'swimState': swimState[s],
        'discards': [
          for (final d in discards[s])
            {'t': tileCode(d.tile), 'taken': d.taken, 'tg': d.tsumogiri, 'riichi': d.swimDeclare}
        ],
        'wind': seatWind(s),
        'score': scores[s],
        'delta': handDelta[s],
      });
    }
    final v = <String, dynamic>{
      'rule': 'fujianmj',
      'phase': phase == 'pause' ? 'claim' : phase,
      'hand': handNo,
      'hands': totalRounds,
      'rounds': totalRounds,
      'dealer': dealer,
      'turn': turn,
      'wall': wall.length,
      'goldTile': goldTile,
      'swimState': List.of(swimState),
      'seats': seats,
      'last': lastAction,
      'lastDiscard': lastDiscardSeat,
      'event': lastEvent == null ? null : {...lastEvent!, 'seq': eventSeq},
      'waiting': phase == 'claim' ? [for (final s in waitingFor) if (s == seat) s] : waitingFor,
      'over': over,
      'settle': settle,
      'history': history,
    };
    if (claim != null) {
      v['claimTile'] = tileCode(claim!.tile);
      v['claimFrom'] = claim!.from;
      v['claimRob'] = claim!.rob;
    } else if (phase == 'pause' && lastDiscardSeat >= 0 && discards[lastDiscardSeat].isNotEmpty) {
      v['claimTile'] = tileCode(discards[lastDiscardSeat].last.tile);
      v['claimFrom'] = lastDiscardSeat;
      v['claimRob'] = false;
    }
    if (over) v['ranking'] = ranking();
    if (seat >= 0 && seat < players) {
      final my = <String, dynamic>{
        'drawn': phase == 'act' && turn == seat && drawn[seat] >= 0 && hands[seat][drawn[seat]] > 0
            ? tileCode(drawn[seat])
            : null,
      };
      if (phase == 'act' && turn == seat) {
        final sts = swimTiles(seat);
        my['canHu'] = canSelfHu;
        my['canSanJinDao'] = canSanJinDao(seat);
        my['canSwim'] = sts.isNotEmpty;
        my['swimTiles'] = [for (final t in sts) tileCode(t)];
        my['nextSwimLabel'] = swimLabel((swimState[seat] + 1).clamp(1, 3));
        my['kongs'] = [for (final (t, _) in selfKongs()) tileCode(t)];
        my['discardable'] = [for (final t in legalDiscards(seat)) tileCode(t)];
      }
      if (phase == 'claim' && claim!.opts.containsKey(seat) && !claim!.resp.containsKey(seat)) {
        final c = claim!;
        my['claim'] = c.opts[seat]!.toList();
        my['chis'] = [
          for (final lo in c.chis[seat] ?? const <int>[]) [for (var k = lo; k < lo + 3; k++) tileCode(k)]
        ];
      }
      final n = countTotal(hands[seat]);
      if (n % 3 == 1 && (phase == 'act' || phase == 'claim' || phase == 'pause')) {
        my['waits'] = [
          for (final t in fujianWaits(hands[seat], melds[seat], goldTile: goldTileId, swimState: swimState[seat]))
            tileCode(t)
        ];
      }
      v['me'] = my;
    }
    return v;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    switch (phase) {
      case 'settle':
        return {'type': 'next'};
      case 'claim':
        final c = claim!;
        final opts = c.opts[seat];
        if (opts == null || c.resp.containsKey(seat)) return null;
        if (opts.contains('hu')) return {'type': 'hu'};
        if (opts.contains('gang')) return {'type': 'gang'};
        if (opts.contains('peng')) {
          if (hands[seat][c.tile] == 2) return {'type': 'peng'};
        }
        if (opts.contains('chi')) {
          if (botLevel == 0 || rng.nextDouble() < 0.5) {
            final list = c.chis[seat]!;
            return {'type': 'chi', 'tile': tileCode(list.first)};
          }
        }
        return {'type': 'pass'};
      case 'act':
        if (seat != turn) return null;
        if (canSanJinDao(seat)) return {'type': 'sanjindao'};
        // If we can advance to 双游 or 三游 (e.g. holding extra gold), prefer swimming!
        final sts = swimTiles(seat);
        if (sts.isNotEmpty && (swimState[seat] == 0 || hands[seat][goldTileId] >= 2) && wall.length > 4) {
          return {'type': 'swim', 'tile': tileCode(sts.first)};
        }
        if (canSelfHu) return {'type': 'hu'};
        if (sts.isNotEmpty) {
          return {'type': 'swim', 'tile': tileCode(sts.first)};
        }
        final ks = selfKongs();
        if (ks.isNotEmpty) {
          return {'type': 'gang', 'tile': tileCode(ks.first.$1)};
        }
        final disc = legalDiscards(seat);
        if (botLevel == 0) {
          final nonGold = disc.where((t) => t != goldTileId).toList();
          final pool = nonGold.isNotEmpty ? nonGold : disc;
          return {'type': 'discard', 'tile': tileCode(pool[rng.nextInt(pool.length)])};
        }
        var bestT = disc.first;
        var bestScore = 1 << 20;
        for (final t in disc) {
          var v = tileValue(hands[seat], t);
          if (t == goldTileId) v += 1000;
          if (v < bestScore) {
            bestScore = v;
            bestT = t;
          }
        }
        return {'type': 'discard', 'tile': tileCode(bestT)};
    }
    return null;
  }
}
