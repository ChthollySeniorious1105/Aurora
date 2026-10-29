import '../../src/engine.dart';
import 'tiles.dart';

/// Next tile in cyclic suit/wind/dragon order from [indicator] (0..33).
/// In Wuhan Mahjong, '7z' (红中, id 33) is a fixed gang tile and cannot be
/// the Laizi (wildcard); if '7z' would be Laizi, use '5z' (白板, id 31).
int wuhanNextLaizi(int indicator) {
  if (indicator >= 0 && indicator < 27) {
    final s = indicator ~/ 9;
    final r = indicator % 9;
    return s * 9 + (r + 1) % 9;
  }
  if (indicator >= 27 && indicator <= 30) {
    return 27 + (indicator - 27 + 1) % 4;
  }
  if (indicator == kHaku) return kHatsu; // 5z -> 6z
  if (indicator == kHatsu) return kHaku; // 6z -> would be 7z, use 5z 白板
  if (indicator == kChun) return kHaku; // 7z -> 5z 白板
  return 0;
}

String wuhanLaiziFromCode(String indicatorCode) =>
    tileCode(wuhanNextLaizi(tileFromCode(indicatorCode)));

class WuhanResult {
  final int fan;
  final bool isBig;
  final List<(String, int)> items;
  const WuhanResult(this.fan, this.isBig, this.items);

  String get label => [for (final (n, _) in items) n].join(' ');
  List<List<Object>> toJson() => [for (final (n, f) in items) [n, f]];
}

bool _canSetsWild(List<int> c, int i, int wild) {
  while (i < kKinds && c[i] == 0) {
    i++;
  }
  if (i >= kKinds) return true;
  // 1. Triplet at i
  final useTrip = c[i] >= 3 ? 3 : c[i];
  final needTrip = 3 - useTrip;
  if (needTrip <= wild) {
    c[i] -= useTrip;
    final ok = _canSetsWild(c, i, wild - needTrip);
    c[i] += useTrip;
    if (ok) return true;
  }
  // 2. Sequences involving i (only for number tiles 0..26)
  if (i < 27) {
    final r = i % 9;
    // (i, i+1, i+2)
    if (r <= 6) {
      final u1 = c[i + 1] > 0 ? 1 : 0;
      final u2 = c[i + 2] > 0 ? 1 : 0;
      final needW = (1 - u1) + (1 - u2);
      if (needW <= wild) {
        c[i]--;
        c[i + 1] -= u1;
        c[i + 2] -= u2;
        final ok = _canSetsWild(c, i, wild - needW);
        c[i]++;
        c[i + 1] += u1;
        c[i + 2] += u2;
        if (ok) return true;
      }
    }
    // (i-1, i, i+1) with wildcard at i-1
    if (r >= 1 && r <= 7 && wild >= 1) {
      final u1 = c[i + 1] > 0 ? 1 : 0;
      final needW = 1 + (1 - u1);
      if (needW <= wild) {
        c[i]--;
        c[i + 1] -= u1;
        final ok = _canSetsWild(c, i, wild - needW);
        c[i]++;
        c[i + 1] += u1;
        if (ok) return true;
      }
    }
    // (i-2, i-1, i) with wildcards at i-2, i-1
    if (r >= 2 && wild >= 2) {
      c[i]--;
      final ok = _canSetsWild(c, i, wild - 2);
      c[i]++;
      if (ok) return true;
    }
  }
  return false;
}

bool _canAnyPairStandardWild(List<int> c, int wild) {
  for (var p = 0; p < kKinds; p++) {
    final use = c[p] >= 2 ? 2 : c[p];
    final need = 2 - use;
    if (need <= wild) {
      c[p] -= use;
      final ok = _canSetsWild(c, 0, wild - need);
      c[p] += use;
      if (ok) return true;
    }
  }
  return false;
}

bool _can258PairStandardWild(List<int> c, int wild) {
  for (var p = 0; p < 27; p++) {
    if (!is258(p)) continue;
    final use = c[p] >= 2 ? 2 : c[p];
    final need = 2 - use;
    if (need <= wild) {
      c[p] -= use;
      final ok = _canSetsWild(c, 0, wild - need);
      c[p] += use;
      if (ok) return true;
    }
  }
  return false;
}

bool _canPengPengWild(List<int> c, int wild) {
  for (var p = 0; p < kKinds; p++) {
    final use = c[p] >= 2 ? 2 : c[p];
    var remWild = wild - (2 - use);
    if (remWild < 0) continue;
    c[p] -= use;
    var ok = true;
    for (var t = 0; t < kKinds; t++) {
      final rem = c[t] % 3;
      if (rem != 0) {
        remWild -= (3 - rem);
        if (remWild < 0) {
          ok = false;
          break;
        }
      }
    }
    c[p] += use;
    if (ok) return true;
  }
  return false;
}

bool _canSevenPairsWild(List<int> c, int wild) {
  var odd = 0;
  for (var t = 0; t < kKinds; t++) {
    if (c[t].isOdd) odd++;
  }
  return odd <= wild && (wild - odd).isEven;
}

/// Evaluates a Wuhan Mahjong hand.
/// [concealed] has `3 * (4 - melds.length) + 2` tiles.
WuhanResult? wuhanEvaluate(
  List<int> concealed,
  List<Meld> melds, {
  required int laiziTile,
  bool kaikou = true,
  bool requireKaikou = true,
  bool selfDrawn = false,
  bool gangKai = false,
  bool qiangGang = false,
  bool haidi = false,
}) {
  if (requireKaikou && !kaikou) return null;
  final total = countTotal(concealed);
  final needSets = 4 - melds.length;
  if (needSets < 0 || total != needSets * 3 + 2) return null;

  final c = List<int>.of(concealed);
  var wild = 0;
  if (laiziTile >= 0 && laiziTile < kKinds) {
    wild = c[laiziTile];
    c[laiziTile] = 0;
  }

  // Gather all non-wildcard tiles across concealed + melds
  final allReal = List<int>.of(c);
  for (final m in melds) {
    for (final t in m.tiles) {
      if (t != laiziTile) allReal[t]++;
    }
  }
  var realTotal = 0;
  final suits = <int>{};
  var hasHonor = false;
  var all258 = true;
  var allHonor = true;
  for (var t = 0; t < kKinds; t++) {
    if (allReal[t] == 0) continue;
    realTotal += allReal[t];
    if (t < 27) {
      suits.add(t ~/ 9);
      allHonor = false;
      if (!is258(t)) all258 = false;
    } else {
      hasHonor = true;
      all258 = false;
    }
  }
  if (melds.any((m) => m.isChi)) {
    all258 = false;
    allHonor = false;
  }

  final anyStandard = _canAnyPairStandardWild(c, wild);
  final pengpeng = melds.every((m) => !m.isChi) && _canPengPengWild(c, wild);
  final qingyise = !hasHonor && suits.length <= 1 && (anyStandard || (melds.isEmpty && _canSevenPairsWild(c, wild)));
  final jiangyise = all258 && (realTotal > 0 || wild > 0);
  final fengyise = allHonor && (realTotal > 0 || wild > 0);
  final quanqiuren = melds.length == 4 && melds.every((m) => m.isExposed) && _canPengPengWild(c, wild);
  final qidui = melds.isEmpty && !requireKaikou && _canSevenPairsWild(c, wild);

  final bigItems = <(String, int)>[];
  if (qingyise) bigItems.add(('清一色', 4));
  if (pengpeng) bigItems.add(('碰碰胡', 4));
  if (jiangyise) bigItems.add(('将一色', 4));
  if (fengyise) bigItems.add(('风一色', 4));
  if (quanqiuren) bigItems.add(('全求人', 4));
  if (qidui && bigItems.isEmpty) bigItems.add(('七对', 4));

  if (bigItems.isNotEmpty) {
    if (gangKai) bigItems.add(('杠上开花', 4));
    if (qiangGang) bigItems.add(('抢杠胡', 4));
    if (haidi) bigItems.add(('海底捞月', 4));
    final fan = bigItems.fold<int>(0, (a, b) => a + b.$2);
    return WuhanResult(fan, true, bigItems);
  }

  // Normal hand (屁胡 / 平胡) requires 2-5-8 pair (unless situational big hand)
  final std258 = _can258PairStandardWild(c, wild);
  if (!std258) return null;

  final sitItems = <(String, int)>[];
  if (gangKai) sitItems.add(('杠上开花', 4));
  if (qiangGang) sitItems.add(('抢杠胡', 4));
  if (haidi) sitItems.add(('海底捞月', 4));
  if (sitItems.isNotEmpty) {
    final fan = sitItems.fold<int>(0, (a, b) => a + b.$2);
    return WuhanResult(fan, true, sitItems);
  }

  final items = <(String, int)>[('平胡', 1)];
  if (wild == 0) items.add(('硬胡', 1));
  final fan = items.fold<int>(0, (a, b) => a + b.$2);
  return WuhanResult(fan, false, items);
}

List<int> wuhanWaits(
  List<int> concealed,
  List<Meld> melds, {
  required int laiziTile,
  required bool kaikou,
  required bool requireKaikou,
}) {
  if (requireKaikou && !kaikou) return const [];
  final out = <int>[];
  for (var t = 0; t < kKinds; t++) {
    concealed[t]++;
    final r = wuhanEvaluate(
      concealed,
      melds,
      laiziTile: laiziTile,
      kaikou: kaikou,
      requireKaikou: requireKaikou,
    );
    concealed[t]--;
    if (r != null) out.add(t);
  }
  return out;
}

class _WhClaim {
  final int tile;
  final int from;
  final bool rob;
  final Map<int, Set<String>> opts;
  final Map<int, List<int>> chis;
  final Map<int, WuhanResult> hu;
  final Map<int, Map<String, dynamic>> resp = {};
  _WhClaim(this.tile, this.from, this.rob, this.opts, {this.chis = const {}, this.hu = const {}});
  List<int> get pending => [for (final s in opts.keys) if (!resp.containsKey(s)) s]..sort();
}

class _WhDiscard {
  final int tile;
  bool taken = false;
  final bool tsumogiri;
  _WhDiscard(this.tile, {this.tsumogiri = false});
}

/// 武汉麻将 · 红中赖子杠
class WuhanGame extends GameEngine {
  WuhanGame(super.setup);

  late final int totalRounds = setup.opt<int>('rounds', 4);
  late final bool requireKaikou = setup.opt<bool>('requireKaikou', true);

  late List<int> scores = List.filled(players, 0);
  int handNo = 0;
  int dealer = 0;
  bool over = false;
  List<Map<String, dynamic>> history = [];

  // Wuhan-specific state
  int laiziIndicatorId = 0;
  int laiziId = 1;
  String get laiziIndicator => tileCode(laiziIndicatorId);
  String get laiziTile => tileCode(laiziId);
  List<int> gangMultipliers = [1, 1, 1, 1];
  List<bool> kaikou = [false, false, false, false];
  List<List<String>> specialGangs = [];

  // Hand state
  String phase = 'act'; // act, claim, settle, over, pause
  String pausedPhase = '';
  List<List<int>> hands = [];
  List<List<Meld>> melds = [];
  List<List<_WhDiscard>> discards = [];
  List<int> drawn = [];
  List<int> wall = [];
  int turn = 0;
  bool canZimo = false;
  bool afterKong = false;
  int lastDiscardSeat = -1;
  String lastAction = '';
  Map<String, dynamic>? lastEvent;
  int eventSeq = 0;
  _WhClaim? claim;
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

  bool isSpecialGangTile(int t) => t == kChun || t == kHatsu || t == laiziId;

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
    discards = List.generate(players, (_) => <_WhDiscard>[]);
    specialGangs = List.generate(players, (_) => <String>[]);
    gangMultipliers = List.filled(players, 1);
    kaikou = List.filled(players, false);
    drawn = List.filled(players, -1);
    handDelta = List.filled(players, 0);
    events = [];
    settle = null;
    claim = null;
    afterKong = false;
    lastDiscardSeat = -1;
    nextDealer = -1;

    // Deal 13 tiles each + 1 extra to dealer
    for (var i = 0; i < 13; i++) {
      for (var s = 0; s < players; s++) {
        hands[s][wall.removeLast()]++;
      }
    }
    final extra = wall.removeLast();
    hands[dealer][extra]++;
    drawn[dealer] = extra;

    // Flip 1 indicator tile to determine Laizi
    laiziIndicatorId = wall.removeLast();
    laiziId = wuhanNextLaizi(laiziIndicatorId);

    turn = dealer;
    phase = 'act';
    canZimo = true;
    host.log('第 $handNo/$totalRounds 局开始，${name(dealer)} 坐庄，翻出 ${tileName(laiziIndicatorId)}，赖子为 ${tileName(laiziId)}');
    lastAction = '赖子：${tileName(laiziId)} · ${name(dealer)} 出牌';
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

  WuhanResult? selfEval(int s) => wuhanEvaluate(
        hands[s],
        melds[s],
        laiziTile: laiziId,
        kaikou: kaikou[s],
        requireKaikou: requireKaikou,
        selfDrawn: true,
        gangKai: afterKong,
        haidi: wall.isEmpty,
      );

  WuhanResult? ronEval(int o, int t, {bool rob = false}) {
    final c = List<int>.of(hands[o]);
    c[t]++;
    return wuhanEvaluate(
      c,
      melds[o],
      laiziTile: laiziId,
      kaikou: kaikou[o],
      requireKaikou: requireKaikou,
      qiangGang: rob,
      haidi: wall.isEmpty && !rob,
    );
  }

  bool get canSelfHu => phase == 'act' && canZimo && selfEval(turn) != null;

  /// Special gang tiles ('7z', '6z', laiziTile) currently in turn player's hand.
  List<int> specialGangOptions(int s) {
    if (phase != 'act' || turn != s || wall.isEmpty) return const [];
    final out = <int>[];
    for (final t in <int>{kChun, kHatsu, laiziId}) {
      if (hands[s][t] > 0) out.add(t);
    }
    return out;
  }

  /// Normal 4-of-a-kind kongs available to turn player: (tile, isBuGang).
  List<(int, bool)> selfKongs() {
    if (phase != 'act' || wall.isEmpty) return const [];
    final s = turn;
    final out = <(int, bool)>[];
    for (var t = 0; t < kKinds; t++) {
      if (t == kChun || t == kHatsu || t == laiziId) continue;
      if (hands[s][t] == 4) out.add((t, false));
      if (hands[s][t] >= 1 && melds[s].any((m) => m.isPeng && m.tile == t)) out.add((t, true));
    }
    return out;
  }

  List<int> chiOptions(int s, int t) {
    if (t >= 27 || t == laiziId) return const [];
    final h = hands[s];
    final r = rankOf(t);
    final out = <int>[];
    for (var lo = t - 2; lo <= t; lo++) {
      final lr = r - (t - lo);
      if (lr < 1 || lr > 7) continue;
      var ok = true;
      for (var k = lo; k < lo + 3; k++) {
        if (k == laiziId) ok = false;
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
    if (type == 'hu') {
      final r = canZimo ? selfEval(s) : null;
      if (r == null) {
        if (requireKaikou && !kaikou[s]) throw GameError('必须先开口（吃/碰/明杠）才能胡牌');
        throw GameError('现在不能胡牌（小胡需要二五八将）');
      }
      final t = drawn[s] >= 0 && hands[s][drawn[s]] > 0 ? drawn[s] : _anyTile(s);
      _settleWin({s: (t, r)}, -1);
      return;
    }
    if (type == 'laizi_gang') {
      if (wall.isEmpty) throw GameError('牌山已空，不能杠牌');
      final t = tileFromCode(a['tile']);
      if (t < 0 || !isSpecialGangTile(t) || hands[s][t] <= 0) {
        throw GameError('只能对红中、发财或赖子声明赖子杠');
      }
      hands[s][t]--;
      specialGangs[s].add(tileCode(t));
      gangMultipliers[s] *= 2;
      final kindLabel = t == laiziId ? '赖子杠' : '${tileName(t)}杠';
      lastAction = '${name(s)} $kindLabel（×${gangMultipliers[s]}）';
      host.log('${name(s)} $kindLabel，番数翻倍 ×${gangMultipliers[s]}');
      _event('gang', s, t);
      _draw(s, kong: true);
      return;
    }
    if (type == 'gang') {
      final t = tileFromCode(a['tile']);
      if (isSpecialGangTile(t) && hands[s][t] > 0 && wall.isNotEmpty) {
        // Also allow 'gang' on special gang tile as convenience alias
        _handleAct(s, 'laizi_gang', a);
        return;
      }
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

  int _anyTile(int s) {
    for (var t = kKinds - 1; t >= 0; t--) {
      if (hands[s][t] > 0) return t;
    }
    return 0;
  }

  void _discard(int s, int t) {
    hands[s][t]--;
    final giri = drawn[s] == t;
    drawn[s] = -1;
    discards[s].add(_WhDiscard(t, tsumogiri: giri));
    canZimo = false;
    afterKong = false;
    lastDiscardSeat = s;
    lastAction = '${name(s)} 打出 ${tileName(t)}';
    _event('discard', s, t);

    final opts = <int, Set<String>>{};
    final chis = <int, List<int>>{};
    final hu = <int, WuhanResult>{};
    for (var o = 0; o < players; o++) {
      if (o == s) continue;
      final set = <String>{};
      // Red Dragon / Green Dragon / Laizi discards cannot be called for melds,
      // wait: can non-special tiles be called for hu/peng/gang/chi?
      final r = ronEval(o, t);
      if (r != null) {
        set.add('hu');
        hu[o] = r;
      }
      if (wall.isNotEmpty && !isSpecialGangTile(t)) {
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
      claim = _WhClaim(t, s, false, opts, chis: chis, hu: hu);
      phase = 'claim';
    }
  }

  int _prio(String type) => switch (type) { 'hu' => 30, 'gang' || 'peng' => 20, 'chi' => 10, _ => 0 };

  int _maxPrio(_WhClaim c, int s) {
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
    kaikou[s] = true; // Chi, Peng, MingGang all count as Kaikou (开口)!
    if (type == 'gang') {
      hands[s][c.tile] -= 3;
      melds[s].add(Meld('mgang', c.tile, claimed: c.tile, from: c.from));
      gangMultipliers[s] *= 2;
      lastAction = '${name(s)} 明杠 ${tileName(c.tile)}（开口 ×${gangMultipliers[s]}）';
      host.log(lastAction);
      _event('gang', s, c.tile);
      _draw(s, kong: true);
      return;
    }
    if (type == 'peng') {
      hands[s][c.tile] -= 2;
      melds[s].add(Meld('peng', c.tile, claimed: c.tile, from: c.from));
      lastAction = '${name(s)} 碰 ${tileName(c.tile)}（开口）';
      _event('peng', s, c.tile);
    } else {
      final lo = r['lo'] as int;
      for (var k = lo; k < lo + 3; k++) {
        if (k != c.tile) hands[s][k]--;
      }
      melds[s].add(Meld('chi', lo, claimed: c.tile, from: c.from));
      lastAction = '${name(s)} 吃 ${tileName(c.tile)}（开口）';
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
      final hu = <int, WuhanResult>{};
      for (var o = 0; o < players; o++) {
        if (o == s) continue;
        final r = ronEval(o, t, rob: true);
        if (r != null) {
          opts[o] = {'hu'};
          hu[o] = r;
        }
      }
      if (opts.isNotEmpty) {
        claim = _WhClaim(t, s, true, opts, hu: hu);
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
    gangMultipliers[s] *= 2;
    lastAction = '${name(s)} 暗杠（×${gangMultipliers[s]}）';
    host.log(lastAction);
    _event('gang', s);
    _draw(s, kong: true);
  }

  void _finishBuGang(int s, int t) {
    hands[s][t]--;
    final m = melds[s].firstWhere((m) => m.isPeng && m.tile == t);
    m.kind = 'bgang';
    kaikou[s] = true;
    gangMultipliers[s] *= 2;
    lastAction = '${name(s)} 补杠 ${tileName(t)}（×${gangMultipliers[s]}）';
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

  void _settleWin(Map<int, (int, WuhanResult)> wins, int from, {bool rob = false}) {
    final zimo = from < 0;
    for (final e in wins.entries) {
      final w = e.key;
      final (tile, res) = e.value;
      if (zimo) hands[w][tile]--;
      drawn[w] = -1;
      final payers = zimo ? [for (var o = 0; o < players; o++) if (o != w) o] : [from];
      final pay = <String, int>{};
      for (final p in payers) {
        var base = res.fan * (zimo ? 2 : 1);
        if (w == dealer || p == dealer) base *= 2;
        final mult = gangMultipliers[w] * gangMultipliers[p];
        final amt = base * mult;
        _pay(p, w, amt);
        pay['$p'] = amt;
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
        'mult': gangMultipliers[w],
        'items': res.toJson(),
        'pay': pay,
        'hand': codesOfCounts(hands[w]),
      });
      host.log(zimo
          ? '${name(w)} 自摸 ${tileName(tile)}！${res.label}（×${gangMultipliers[w]}）'
          : '${name(w)} 胡 ${name(from)} 的 ${tileName(tile)}！${res.label}（×${gangMultipliers[w]}）');
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
      'win': events.any((e) => e['kind'] == 'hu'),
      'delta': List.of(handDelta),
      'dealer': dealer,
      'laiziIndicator': laiziIndicator,
      'laiziTile': laiziTile,
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
        'specialGangs': specialGangs[s],
        'kaikou': kaikou[s],
        'gangMultiplier': gangMultipliers[s],
        'discards': [
          for (final d in discards[s]) {'t': tileCode(d.tile), 'taken': d.taken, 'tg': d.tsumogiri}
        ],
        'wind': seatWind(s),
        'score': scores[s],
        'delta': handDelta[s],
      });
    }
    final v = <String, dynamic>{
      'rule': 'wuhanmj',
      'phase': phase == 'pause' ? 'claim' : phase,
      'hand': handNo,
      'hands': totalRounds,
      'rounds': totalRounds,
      'dealer': dealer,
      'turn': turn,
      'wall': wall.length,
      'laiziIndicator': laiziIndicator,
      'laiziTile': laiziTile,
      'requireKaikou': requireKaikou,
      'kaikou': List.of(kaikou),
      'gangMultipliers': List.of(gangMultipliers),
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
        my['canHu'] = canSelfHu;
        my['laiziGangs'] = [for (final t in specialGangOptions(seat)) tileCode(t)];
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
          for (final t in wuhanWaits(
            hands[seat],
            melds[seat],
            laiziTile: laiziId,
            kaikou: kaikou[seat],
            requireKaikou: requireKaikou,
          ))
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
          if (!kaikou[seat] || hands[seat][c.tile] == 2) return {'type': 'peng'};
        }
        if (opts.contains('chi')) {
          if (!kaikou[seat] || botLevel == 0 || rng.nextDouble() < 0.6) {
            final list = c.chis[seat]!;
            return {'type': 'chi', 'tile': tileCode(list.first)};
          }
        }
        return {'type': 'pass'};
      case 'act':
        if (seat != turn) return null;
        if (canSelfHu) return {'type': 'hu'};
        // Always declare laizi_gang on Red Dragon ('7z') or Green Dragon ('6z'),
        // or if holding > 2 Laizi tiles
        final sp = specialGangOptions(seat);
        for (final t in sp) {
          if (t == kChun || t == kHatsu || hands[seat][t] >= 3) {
            return {'type': 'laizi_gang', 'tile': tileCode(t)};
          }
        }
        final ks = selfKongs();
        if (ks.isNotEmpty) {
          return {'type': 'gang', 'tile': tileCode(ks.first.$1)};
        }
        final disc = legalDiscards(seat);
        if (botLevel == 0) {
          final nonLaizi = disc.where((t) => t != laiziId).toList();
          final pool = nonLaizi.isNotEmpty ? nonLaizi : disc;
          return {'type': 'discard', 'tile': tileCode(pool[rng.nextInt(pool.length)])};
        }
        var bestT = disc.first;
        var bestScore = 1 << 20;
        for (final t in disc) {
          var v = tileValue(hands[seat], t);
          if (t == laiziId) v += 1000;
          if (is258(t) && hands[seat][t] == 2) v += 6;
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
