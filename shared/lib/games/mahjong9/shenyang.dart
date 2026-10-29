import '../../src/engine.dart';
import 'tiles.dart';

class ShenyangResult {
  final int fan;
  final int mult;
  final bool isOpened; // 开门（有吃/碰/明杠/旋风杠，或七对）
  final bool hasAllThreeSuits; // 三门齐（万、筒、条齐全）
  final bool hasHeng; // 有横牌（有刻子/杠/旋风杠，或中发白作掌/将）
  final bool hasYaoJiu; // 有幺九（含1/9或字牌）
  final bool isQiDui; // 七对 ×2
  final bool isPiaoHu; // 飘胡（对对胡）×2
  final bool noHui; // 无会硬胡
  final int xfgangCount; // 旋风杠数量
  final bool isBig;
  final List<(String, int)> items;

  const ShenyangResult({
    required this.fan,
    required this.mult,
    required this.isOpened,
    required this.hasAllThreeSuits,
    required this.hasHeng,
    required this.hasYaoJiu,
    required this.isQiDui,
    required this.isPiaoHu,
    required this.noHui,
    required this.xfgangCount,
    required this.isBig,
    required this.items,
  });

  String get label => [for (final (n, _) in items) n].join(' ');
  List<List<Object>> toJson() => [for (final (n, f) in items) [n, f]];
}

bool _canSetsShenyang(
  List<int> c,
  int i,
  int wild, {
  required int suitMask,
  required bool heng,
  required bool yaojiu,
}) {
  final n = c.length;
  while (i < n && c[i] == 0) {
    i++;
  }
  if (i >= n) {
    // Remaining wildcards (if any) must be a multiple of 3 and can form triplets of 1m/1p/1s
    if (wild % 3 != 0) return false;
    final freeTrips = wild ~/ 3;
    var sm = suitMask;
    var h = heng || freeTrips > 0;
    var yj = yaojiu || freeTrips > 0;
    var rem = freeTrips;
    for (var s = 0; s < 3 && rem > 0; s++) {
      if ((sm & (1 << s)) == 0) {
        sm |= (1 << s);
        rem--;
      }
    }
    return sm == 0x7 && h && yj;
  }

  final sBit = i < kNumKinds ? (1 << (i ~/ 9)) : 0;
  final iYj = isYaojiu(i);

  // 1. Triplet at i (counts as 横牌!)
  final useTrip = c[i] >= 3 ? 3 : c[i];
  final needTrip = 3 - useTrip;
  if (needTrip <= wild) {
    c[i] -= useTrip;
    final ok = _canSetsShenyang(
      c,
      i,
      wild - needTrip,
      suitMask: suitMask | sBit,
      heng: true,
      yaojiu: yaojiu || iYj,
    );
    c[i] += useTrip;
    if (ok) return true;
  }

  // 2. Sequences involving i (only for number tiles 0..26)
  if (i < kNumKinds) {
    final r = i % 9;
    if (r <= 6) {
      final u1 = c[i + 1] > 0 ? 1 : 0;
      final u2 = c[i + 2] > 0 ? 1 : 0;
      final needW = (1 - u1) + (1 - u2);
      if (needW <= wild) {
        final seqYj = r == 0 || r == 6; // 1-2-3 or 7-8-9
        c[i]--;
        c[i + 1] -= u1;
        c[i + 2] -= u2;
        final ok = _canSetsShenyang(
          c,
          i,
          wild - needW,
          suitMask: suitMask | sBit,
          heng: heng,
          yaojiu: yaojiu || seqYj,
        );
        c[i]++;
        c[i + 1] += u1;
        c[i + 2] += u2;
        if (ok) return true;
      }
    }
    if (r >= 1 && r <= 7 && wild >= 1) {
      final u1 = c[i + 1] > 0 ? 1 : 0;
      final needW = 1 + (1 - u1);
      if (needW <= wild) {
        final seqYj = r == 1 || r == 7; // (1)-2-3 or 7-8-(9)
        c[i]--;
        c[i + 1] -= u1;
        final ok = _canSetsShenyang(
          c,
          i,
          wild - needW,
          suitMask: suitMask | sBit,
          heng: heng,
          yaojiu: yaojiu || seqYj,
        );
        c[i]++;
        c[i + 1] += u1;
        if (ok) return true;
      }
    }
    if (r >= 2 && wild >= 2) {
      // (i-2, i-1, i) or (i-1, i, i+1) with 2 wildcards
      final seqYj = r == 2 || r == 8 || r == 7;
      c[i]--;
      final ok = _canSetsShenyang(
        c,
        i,
        wild - 2,
        suitMask: suitMask | sBit,
        heng: heng,
        yaojiu: yaojiu || seqYj,
      );
      c[i]++;
      if (ok) return true;
    }
  }
  return false;
}

bool _canStandardShenyang(
  List<int> c,
  int wild, {
  required int baseSuitMask,
  required bool baseHeng,
  required bool baseYaoJiu,
}) {
  final n = c.length;
  for (var p = 0; p < n; p++) {
    final use = c[p] >= 2 ? 2 : c[p];
    final need = 2 - use;
    if (need <= wild) {
      final pSuitBit = p < kNumKinds ? (1 << (p ~/ 9)) : 0;
      final pHeng = isDragon(p); // 中发白 (5z, 6z, 7z) 作掌/将 算有横牌！
      final pYj = isYaojiu(p);
      c[p] -= use;
      final ok = _canSetsShenyang(
        c,
        0,
        wild - need,
        suitMask: baseSuitMask | pSuitBit,
        heng: baseHeng || pHeng,
        yaojiu: baseYaoJiu || pYj,
      );
      c[p] += use;
      if (ok) return true;
    }
  }
  return false;
}

bool _canSevenPairsShenyang(List<int> c, int wild) {
  var odd = 0;
  var suitMask = 0;
  var yaojiu = false;
  for (var t = 0; t < c.length; t++) {
    if (c[t] <= 0) continue;
    if (c[t].isOdd) odd++;
    if (t < kNumKinds) suitMask |= (1 << (t ~/ 9));
    if (isYaojiu(t)) yaojiu = true;
  }
  if (odd > wild || (wild - odd).isOdd) return false;
  final freePairs = (wild - odd) ~/ 2;
  if (freePairs > 0) yaojiu = true; // Free wildcard pair can be 1m/1p/1s
  var missingSuits = 0;
  for (var s = 0; s < 3; s++) {
    if ((suitMask & (1 << s)) == 0) missingSuits++;
  }
  return missingSuits <= freePairs && yaojiu;
}

/// Evaluates a Shenyang Mahjong (沈阳麻将) hand (136 tiles):
/// - Optional [huiTile] (when [useHui] is true, flipped from `huiIndicator` -> next cyclic tile)
///   is a universal wildcard in hand.
/// - Enforces the **Four Pillars of Shenyang Mahjong (沈阳胡牌四大硬条件)**:
///   1. **开门 (`isOpened`)**: At least 1 exposed meld (`chi`, `peng`, `mgang`, `bgang`, or `xfgang`), OR Seven Pairs (`七对`)!
///   2. **三门齐 (`hasAllThreeSuits`)**: Hand + melds contain at least one tile of each of the 3 number suits (`m`, `p`, `s`)!
///   3. **有横牌 (`hasHeng`)**: Contains at least 1 Triplet/Quad (`peng`, `mgang`, `agang`, `xfgang`, or concealed triplet) OR a pair of Dragons (`5z, 6z, 7z` 中发白作掌/将)!
///   4. **有幺九 (`hasYaoJiu`)**: Contains at least 1 terminal (`1` or `9`) or Honor tile (`1z..7z`)!
ShenyangResult? shenyangEvaluate(
  List<int> concealed,
  List<Meld> melds, {
  Object? huiTile = -1,
  bool useHui = true,
  bool selfDrawn = false,
  bool gangKai = false,
  bool qiangGang = false,
}) {
  final total = countTotal(concealed);
  final needSets = 4 - melds.length;
  if (needSets < 0 || total != needSets * 3 + 2) return null;

  final huiId = useHui ? tileFromCode(huiTile) : -1;
  final wild = (huiId >= 0 && huiId < concealed.length) ? concealed[huiId] : 0;

  var baseSuitMask = 0;
  var baseHeng = false;
  var baseYaoJiu = false;
  var xfgangCount = 0;
  for (final m in melds) {
    if (!m.isChi) baseHeng = true;
    if (m.isXfgang) xfgangCount++;
    for (final t in m.tiles) {
      if (t < kNumKinds) baseSuitMask |= (1 << (t ~/ 9));
      if (isYaojiu(t)) baseYaoJiu = true;
    }
  }
  for (var t = 0; t < concealed.length; t++) {
    if (t == huiId || concealed[t] <= 0) continue;
    if (t < kNumKinds) baseSuitMask |= (1 << (t ~/ 9));
    if (isYaojiu(t)) baseYaoJiu = true;
  }

  final hasExposedMeld = melds.any((m) => m.isExposed);

  // Check pure (no-wildcard) win first
  final pureAllCounts = List<int>.of(concealed);
  var pureSuitMask = baseSuitMask;
  var pureYaoJiu = baseYaoJiu;
  if (huiId >= 0 && huiId < pureAllCounts.length && pureAllCounts[huiId] > 0) {
    if (huiId < kNumKinds) pureSuitMask |= (1 << (huiId ~/ 9));
    if (isYaojiu(huiId)) pureYaoJiu = true;
  }
  final pureStd = hasExposedMeld &&
      _canStandardShenyang(
        pureAllCounts,
        0,
        baseSuitMask: pureSuitMask,
        baseHeng: baseHeng,
        baseYaoJiu: pureYaoJiu,
      );
  final pureQidui = melds.isEmpty && _canSevenPairsShenyang(pureAllCounts, 0);
  final noHui = (pureStd || pureQidui) && wild == 0;

  final c = List<int>.of(concealed);
  if (huiId >= 0 && huiId < c.length) {
    c[huiId] = 0;
  }

  final stdWin = pureStd ||
      (hasExposedMeld &&
          wild > 0 &&
          _canStandardShenyang(
            c,
            wild,
            baseSuitMask: baseSuitMask,
            baseHeng: baseHeng,
            baseYaoJiu: baseYaoJiu,
          ));
  final qidui = pureQidui || (melds.isEmpty && wild > 0 && _canSevenPairsShenyang(c, wild));

  if (!stdWin && !qidui) return null;

  final piaohu = stdWin &&
      melds.every((m) => !m.isChi) &&
      (isAllPungs(concealed) || (wild > 0 && canPengPengWild(c, wild)));

  final items = <(String, int)>[];
  var mult = 1;

  if (qidui) {
    items.add(('七对', 4));
    mult *= 2;
  } else if (piaohu) {
    items.add(('飘胡', 4));
    mult *= 2;
  }
  if (xfgangCount > 0) {
    items.add(('旋风杠×$xfgangCount', xfgangCount * 2));
  }
  if (gangKai) {
    items.add(('杠上开花', 2));
    mult *= 2;
  }
  if (qiangGang) {
    items.add(('抢杠胡', 2));
    mult *= 2;
  }
  if (noHui) {
    items.add(('无会硬胡', 2));
  }
  if (items.isEmpty) {
    items.add(('平胡', 1));
  }
  if (selfDrawn) {
    items.add(('自摸', 1));
  }

  final isBig = qidui || piaohu || xfgangCount > 0 || gangKai || qiangGang || noHui;
  final fan = items.fold<int>(0, (a, b) => a + b.$2);

  return ShenyangResult(
    fan: fan,
    mult: mult,
    isOpened: true,
    hasAllThreeSuits: true,
    hasHeng: true,
    hasYaoJiu: true,
    isQiDui: qidui,
    isPiaoHu: piaohu,
    noHui: noHui,
    xfgangCount: xfgangCount,
    isBig: isBig,
    items: items,
  );
}

List<int> shenyangWaits(
  List<int> concealed,
  List<Meld> melds, {
  Object? huiTile = -1,
  bool useHui = true,
}) {
  final out = <int>[];
  for (var t = 0; t < kKinds && t < concealed.length; t++) {
    concealed[t]++;
    final r = shenyangEvaluate(concealed, melds, huiTile: huiTile, useHui: useHui, selfDrawn: true);
    concealed[t]--;
    if (r != null) out.add(t);
  }
  return out;
}

class _SyClaim {
  final int tile;
  final int from;
  final bool rob;
  final Map<int, Set<String>> opts;
  final Map<int, List<int>> chis;
  final Map<int, ShenyangResult> hu;
  final Map<int, Map<String, dynamic>> resp = {};
  _SyClaim(this.tile, this.from, this.rob, this.opts, {this.chis = const {}, this.hu = const {}});
  List<int> get pending => [for (final s in opts.keys) if (!resp.containsKey(s)) s]..sort();
}

class _SyDiscard {
  final int tile;
  bool taken = false;
  final bool tsumogiri;
  _SyDiscard(this.tile, {this.tsumogiri = false});
}

/// 沈阳麻将 (shenyangmj)
class ShenyangGame extends GameEngine {
  ShenyangGame(super.setup);

  late final int totalRounds = setup.opt<int>('rounds', 4);
  late final bool useHui = setup.opt<bool>('useHui', true);

  late List<int> scores = List.filled(players, 0);
  int handNo = 0;
  int dealer = 0;
  bool over = false;
  List<Map<String, dynamic>> history = [];

  // Shenyang-specific state: 翻会牌 (huiIndicator -> huiTile) & 旋风杠 ('xfgang')
  int huiIndicatorId = -1;
  int huiTileId = -1;
  String? get huiIndicator => useHui && huiIndicatorId >= 0 ? tileCode(huiIndicatorId) : null;
  String? get huiTile => useHui && huiTileId >= 0 ? tileCode(huiTileId) : null;

  void setHuiIndicator(Object indicator) {
    final id = tileFromCode(indicator);
    if (id >= 0) {
      huiIndicatorId = id;
      huiTileId = nextCyclicTile(id);
    }
  }

  void setHuiTile(Object tile) {
    final id = tileFromCode(tile);
    if (id >= 0) {
      huiTileId = id;
    }
  }

  // Hand state
  String phase = 'act'; // act, claim, settle, over, pause
  String pausedPhase = '';
  List<List<int>> hands = [];
  List<List<Meld>> melds = [];
  List<List<_SyDiscard>> discards = [];
  List<int> drawn = [];
  List<int> wall = [];
  int turn = 0;
  bool canZimo = false;
  bool afterKong = false;
  int lastDiscardSeat = -1;
  String lastAction = '';
  Map<String, dynamic>? lastEvent;
  int eventSeq = 0;
  _SyClaim? claim;
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

  bool isOpened(int s) => melds[s].any((m) => m.isExposed);

  @override
  void start() {
    dealer = 0;
    _startHand();
  }

  void _startHand() {
    handNo++;
    wall = <int>[for (var t = 0; t < kKinds; t++) for (var k = 0; k < 4; k++) t]..shuffle(rng);
    hands = List.generate(players, (_) => List.filled(kKinds, 0));
    melds = List.generate(players, (_) => <Meld>[]);
    discards = List.generate(players, (_) => <_SyDiscard>[]);
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

    if (useHui) {
      final ind = wall.removeLast();
      setHuiIndicator(ind);
    } else {
      huiIndicatorId = -1;
      huiTileId = -1;
    }

    turn = dealer;
    phase = 'act';
    canZimo = true;
    final huiText = useHui ? '翻出 ${tileName(huiIndicatorId)}，会牌：${tileName(huiTileId)}' : '纯硬胡无会牌';
    host.log('第 $handNo/$totalRounds 局开始，${name(dealer)} 坐庄（$huiText · 四大条件开门/三门齐/有横牌/有幺九）');
    lastAction = useHui ? '会牌：${tileName(huiTileId)} · ${name(dealer)} 出牌' : '纯硬胡 · ${name(dealer)} 出牌';
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

  ShenyangResult? selfEval(int s) => shenyangEvaluate(
        hands[s],
        melds[s],
        huiTile: useHui ? huiTileId : -1,
        useHui: useHui,
        selfDrawn: true,
        gangKai: afterKong,
      );

  ShenyangResult? ronEval(int o, int t, {bool rob = false}) {
    if (useHui && t == huiTileId) return null;
    final c = List<int>.of(hands[o]);
    c[t]++;
    return shenyangEvaluate(
      c,
      melds[o],
      huiTile: useHui ? huiTileId : -1,
      useHui: useHui,
      selfDrawn: false,
      qiangGang: rob,
    );
  }

  bool get canSelfHu => phase == 'act' && canZimo && selfEval(turn) != null;

  /// Available 旋风杠 kinds ('wind' for 1z+2z+3z+4z, 'dragon' for 5z+6z+7z) for [s].
  List<String> selfXfgangs([int? s]) {
    final seat = s ?? turn;
    if (phase != 'act' || seat != turn || wall.isEmpty) return const [];
    final h = hands[seat];
    final out = <String>[];
    if (h[kEast] >= 1 && h[kSouth] >= 1 && h[kWest] >= 1 && h[kNorth] >= 1) {
      out.add('wind');
    }
    if (h[kHaku] >= 1 && h[kHatsu] >= 1 && h[kChun] >= 1) {
      out.add('dragon');
    }
    return out;
  }

  List<(int, bool)> selfKongs() {
    if (phase != 'act' || wall.isEmpty) return const [];
    final s = turn;
    final out = <(int, bool)>[];
    for (var t = 0; t < kKinds; t++) {
      if (useHui && t == huiTileId) continue;
      if (hands[s][t] == 4) out.add((t, false));
      if (hands[s][t] >= 1 && melds[s].any((m) => m.isPeng && m.tile == t)) out.add((t, true));
    }
    return out;
  }

  List<int> chiOptions(int s, int t) {
    if (t >= kNumKinds || (useHui && t == huiTileId)) return const [];
    final h = hands[s];
    final r = rankOf(t);
    final out = <int>[];
    for (var lo = t - 2; lo <= t; lo++) {
      final lr = r - (t - lo);
      if (lr < 1 || lr > 7) continue;
      var ok = true;
      for (var k = lo; k < lo + 3; k++) {
        if (k != t && ((useHui && k == huiTileId) || h[k] == 0)) ok = false;
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
  int get botDelayMs => phase == 'claim' ? 480 : 700;

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
    if (type == 'tsumo' || type == 'hu') {
      final r = canZimo ? selfEval(s) : null;
      if (r == null) throw GameError('未满足沈阳麻将四大胡牌条件（开门、三门齐、有横牌、有幺九），不能胡牌');
      final t = drawn[s] >= 0 && hands[s][drawn[s]] > 0 ? drawn[s] : _anyTile(s);
      _settleWin({s: (t, r)}, -1);
      return;
    }
    if (type == 'xfgang') {
      final avail = selfXfgangs(s);
      if (avail.isEmpty) throw GameError('手中没有齐备的风杠（东南西北）或喜杠（白发中）');
      final rawKind = asStr(a['kind']);
      final kind = avail.contains(rawKind) ? rawKind : avail.first;
      _declareXfgang(s, kind);
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
      _discard(s, t);
      return;
    }
    throw GameError('请出牌');
  }

  void _declareXfgang(int s, String kind) {
    final xTiles = kind == 'wind' ? const [kEast, kSouth, kWest, kNorth] : const [kHaku, kHatsu, kChun];
    for (final t in xTiles) {
      hands[s][t]--;
    }
    melds[s].add(Meld('xfgang', xTiles.first, customTiles: xTiles, subKind: kind));
    final why = kind == 'wind' ? '风杠(东南西北)' : '喜杠(白发中)';
    for (var o = 0; o < players; o++) {
      if (o == s) continue;
      _pay(o, s, 2);
      events.add({
        'kind': 'xfgang',
        'subKind': kind,
        'from': o,
        'to': s,
        'amount': 2,
        'why': why,
      });
    }
    lastAction = '${name(s)} 亮出旋风杠：$why';
    host.log(lastAction);
    _event('gang', s, xTiles.first);

    // Draw 1 replacement tile while maintaining standard hand size (needSets * 3 + 2)
    final needSets = 4 - melds[s].length;
    final targetOnTurn = needSets * 3 + 2;
    final curTotal = countTotal(hands[s]);
    if (curTotal < targetOnTurn) {
      _draw(s, kong: true);
    } else {
      if (wall.isEmpty) {
        _drawnGame();
        return;
      }
      final rep = wall.removeLast();
      if (selfEval(s) == null && drawn[s] >= 0 && hands[s][drawn[s]] > 0) {
        hands[s][drawn[s]]--;
        hands[s][rep]++;
        drawn[s] = rep;
      } else {
        drawn[s] = _anyTile(s);
      }
      turn = s;
      phase = 'act';
      canZimo = true;
      afterKong = true;
    }
  }

  int _anyTile(int s) {
    for (var t = kKinds - 1; t >= 0; t--) {
      if ((!useHui || t != huiTileId) && hands[s][t] > 0) return t;
    }
    return useHui && huiTileId >= 0 ? huiTileId : 0;
  }

  void _discard(int s, int t) {
    hands[s][t]--;
    final giri = drawn[s] == t;
    drawn[s] = -1;
    discards[s].add(_SyDiscard(t, tsumogiri: giri));
    canZimo = false;
    afterKong = false;
    lastDiscardSeat = s;
    lastAction = '${name(s)} 打出 ${tileName(t)}';
    _event('discard', s, t);

    if (useHui && t == huiTileId) {
      _coverPause(() => _draw((s + 1) % players));
      return;
    }

    final opts = <int, Set<String>>{};
    final chis = <int, List<int>>{};
    final hu = <int, ShenyangResult>{};
    for (var o = 0; o < players; o++) {
      if (o == s) continue;
      final set = <String>{};
      final r = ronEval(o, t);
      if (r != null) {
        set.add('ron');
        hu[o] = r;
      }
      if (wall.isNotEmpty) {
        if (hands[o][t] >= 2) set.add('peng');
        if (hands[o][t] >= 3) set.add('gang');
        if (o == (s + 1) % players) {
          final cs = chiOptions(o, t);
          if (cs.isNotEmpty) {
            set.add('chi');
            chis[o] = cs;
          }
        }
      }
      if (set.isNotEmpty) opts[o] = set;
    }
    if (opts.isEmpty) {
      _coverPause(() => _draw((s + 1) % players));
    } else {
      claim = _SyClaim(t, s, false, opts, chis: chis, hu: hu);
      phase = 'claim';
    }
  }

  int _prio(String type) => switch (type) {
        'ron' || 'hu' => 30,
        'gang' || 'peng' => 20,
        'chi' => 10,
        _ => 0,
      };

  int _maxPrio(_SyClaim c, int s) {
    var best = 0;
    for (final o in c.opts[s]!) {
      final p = _prio(o);
      if (p > best) best = p;
    }
    return best;
  }

  void _handleClaim(int s, String rawType, Map<String, dynamic> a) {
    final c = claim!;
    final o = c.opts[s];
    if (o == null) throw GameError('你没有可执行的操作');
    if (c.resp.containsKey(s)) throw GameError('你已经选择了');
    final type = rawType == 'hu' ? 'ron' : rawType;
    if (type != 'pass' && !o.contains(type)) throw GameError('不能执行该操作');
    var chiTile = -1;
    if (type == 'chi') {
      final list = c.chis[s] ?? const [];
      final arg = tileFromCode(a['tile']);
      chiTile = list.contains(arg) ? arg : list.first;
    }
    c.resp[s] = {'type': type, if (chiTile >= 0) 'tile': chiTile};
    final pend = c.pending;
    final huDeclared = c.resp.values.any((e) => e['type'] == 'ron');
    if (huDeclared) {
      if (pend.any((p) => c.opts[p]!.contains('ron'))) return;
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
        if (c.resp[(c.from + i) % players]?['type'] == 'ron') (c.from + i) % players
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
      _pay(c.from, s, 2);
      events.add({'kind': 'gang', 'from': c.from, 'to': s, 'amount': 2, 'why': '点杠'});
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
    } else if (type == 'chi') {
      final lo = r['tile'] as int;
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
      final hu = <int, ShenyangResult>{};
      for (var o = 0; o < players; o++) {
        if (o == s) continue;
        final r = ronEval(o, t, rob: true);
        if (r != null) {
          opts[o] = {'ron'};
          hu[o] = r;
        }
      }
      if (opts.isNotEmpty) {
        claim = _SyClaim(t, s, true, opts, hu: hu);
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
    for (var o = 0; o < players; o++) {
      if (o == s) continue;
      _pay(o, s, 2);
      events.add({'kind': 'gang', 'from': o, 'to': s, 'amount': 2, 'why': '暗杠'});
    }
    lastAction = '${name(s)} 暗杠 ${tileName(t)}';
    host.log(lastAction);
    _event('gang', s, t);
    _draw(s, kong: true);
  }

  void _finishBuGang(int s, int t) {
    hands[s][t]--;
    final m = melds[s].firstWhere((m) => m.isPeng && m.tile == t);
    m.kind = 'bgang';
    for (var o = 0; o < players; o++) {
      if (o == s) continue;
      _pay(o, s, 1);
      events.add({'kind': 'gang', 'from': o, 'to': s, 'amount': 1, 'why': '补杠'});
    }
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

  void _settleWin(Map<int, (int, ShenyangResult)> wins, int from, {bool rob = false}) {
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
        final amt = res.fan * res.mult * (zimo ? 2 : 1);
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
        'isOpened': res.isOpened,
        'hasAllThreeSuits': res.hasAllThreeSuits,
        'hasHeng': res.hasHeng,
        'hasYaoJiu': res.hasYaoJiu,
        'noHui': res.noHui,
        'xfgangCount': res.xfgangCount,
        'fan': res.fan,
        'mult': res.mult,
        'total': totalWon,
        'items': res.toJson(),
        'pay': pay,
        'hand': codesOfCounts(hands[w]),
      });
      host.log(zimo
          ? '${name(w)} 自摸 ${tileName(tile)}！${res.label}'
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
      'useHui': useHui,
      'huiIndicator': huiIndicator,
      'huiTile': huiTile,
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
        'opened': isOpened(s),
        'discards': [
          for (final d in discards[s])
            {'t': tileCode(d.tile), 'taken': d.taken, 'tg': d.tsumogiri, 'riichi': false}
        ],
        'wind': seatWind(s),
        'score': scores[s],
        'delta': handDelta[s],
      });
    }
    final v = <String, dynamic>{
      'rule': 'shenyangmj',
      'phase': phase == 'pause' ? 'claim' : phase,
      'hand': handNo,
      'hands': totalRounds,
      'rounds': totalRounds,
      'dealer': dealer,
      'turn': turn,
      'wall': wall.length,
      'useHui': useHui,
      'huiIndicator': huiIndicator,
      'huiTile': huiTile,
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
        'opened': isOpened(seat),
      };
      if (phase == 'act' && turn == seat) {
        final ev = canZimo ? selfEval(seat) : null;
        final xfs = selfXfgangs(seat);
        my['canHu'] = ev != null;
        my['canTsumo'] = ev != null;
        my['xfgangs'] = xfs;
        my['canXfgang'] = xfs.isNotEmpty;
        my['kongs'] = [for (final (t, _) in selfKongs()) tileCode(t)];
        my['discardable'] = [for (final t in legalDiscards(seat)) tileCode(t)];
      }
      if (phase == 'claim' && claim!.opts.containsKey(seat) && !claim!.resp.containsKey(seat)) {
        my['claim'] = claim!.opts[seat]!.toList();
        if (claim!.chis.containsKey(seat)) {
          my['chis'] = [
            for (final lo in claim!.chis[seat]!) [tileCode(lo), tileCode(lo + 1), tileCode(lo + 2)]
          ];
        }
      }
      final n = countTotal(hands[seat]);
      if (n % 3 == 1 && (phase == 'act' || phase == 'claim' || phase == 'pause')) {
        my['waits'] = [
          for (final t in shenyangWaits(hands[seat], melds[seat], huiTile: useHui ? huiTileId : -1, useHui: useHui))
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
      case 'act':
        if (seat != turn) return null;
        if (canSelfHu) return {'type': 'tsumo'};
        final xfs = selfXfgangs(seat);
        if (xfs.isNotEmpty) return {'type': 'xfgang', 'kind': xfs.first};
        final ks = selfKongs();
        if (ks.isNotEmpty) return {'type': 'gang', 'tile': tileCode(ks.first.$1)};
        final legals = legalDiscards(seat);
        final nonHui = [for (final t in legals) if (!useHui || t != huiTileId) t];
        final pool = nonHui.isNotEmpty ? nonHui : legals;
        if (botLevel == 0 && rng.nextDouble() < 0.3) {
          return {'type': 'discard', 'tile': tileCode(pool[rng.nextInt(pool.length)])};
        }
        var best = pool.first, bestScore = 1 << 20;
        for (final t in pool) {
          final sc = tileValue(hands[seat], t, preferHonors: true, keepTerminals: true);
          if (sc < bestScore) {
            bestScore = sc;
            best = t;
          }
        }
        return {'type': 'discard', 'tile': tileCode(best)};
      case 'claim':
        final c = claim!;
        final o = c.opts[seat];
        if (o == null || c.resp.containsKey(seat)) return null;
        if (o.contains('ron')) return {'type': 'ron'};
        if (o.contains('gang')) return {'type': 'gang'};
        if (o.contains('peng') && (!isOpened(seat) || rng.nextDouble() < 0.7)) {
          return {'type': 'peng'};
        }
        if (o.contains('chi') && (!isOpened(seat) || rng.nextDouble() < 0.5)) {
          final lo = c.chis[seat]!.first;
          return {'type': 'chi', 'tile': tileCode(lo)};
        }
        return {'type': 'pass'};
      case 'settle':
        return ready.contains(seat) ? null : {'type': 'next'};
    }
    return null;
  }
}
