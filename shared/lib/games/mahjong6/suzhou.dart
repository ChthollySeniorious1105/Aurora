import '../../src/engine.dart';
import 'tiles.dart';

class SuzhouResult {
  final int fan;
  final int mult;
  final int huaCount;
  final bool isMenqing; // 门清
  final bool isDiMaZi; // 滴麻子（平胡）
  final bool isDaDiaoChe; // 大吊车（4副露单钓将）
  final bool isDuiDuiHu; // 对对胡
  final bool isHunYiSe; // 混一色
  final bool isQingYiSe; // 清一色
  final bool isQiDui; // 七对
  final bool isBig;
  final List<(String, int)> items;

  const SuzhouResult({
    required this.fan,
    required this.mult,
    required this.huaCount,
    required this.isMenqing,
    required this.isDiMaZi,
    required this.isDaDiaoChe,
    required this.isDuiDuiHu,
    required this.isHunYiSe,
    required this.isQingYiSe,
    required this.isQiDui,
    required this.isBig,
    required this.items,
  });

  String get label => [for (final (n, _) in items) n].join(' ');
  List<List<Object>> toJson() => [for (final (n, f) in items) [n, f]];
}

/// Evaluates a Suzhou Mahjong (苏州麻将) hand:
/// - 136 tiles, [baidaTile] is the universal wildcard in hand.
/// - Plain hands (滴麻子) require [huaCount] >= 2 OR closed hand (门清, no exposed melds) to win.
/// - Big hands (大吊车, 对对胡, 混一色, 清一色, 七对) can win regardless of flower count and score bonus flower multipliers.
SuzhouResult? suzhouEvaluate(
  List<int> concealed,
  List<Meld> melds, {
  required int baidaTile,
  int huaCount = 0,
  bool selfDrawn = false,
  bool gangKai = false,
  bool qiangGang = false,
}) {
  final total = countTotal(concealed);
  final needSets = 4 - melds.length;
  if (needSets < 0 || total != needSets * 3 + 2) return null;

  final pureStd = isStandardWin(concealed);
  final pureQidui = melds.isEmpty && isSevenPairs(concealed);

  final c = List<int>.of(concealed);
  final wild = (baidaTile >= 0 && baidaTile < c.length) ? c[baidaTile] : 0;
  if (baidaTile >= 0 && baidaTile < c.length) {
    c[baidaTile] = 0;
  }

  final stdWin = pureStd || canAnyPairStandardWild(c, wild);
  final qidui = pureQidui || (melds.isEmpty && canSevenPairsWild(c, wild));
  if (!stdWin && !qidui) return null;

  final menqing = melds.every((m) => m.concealed);
  final dadiaoche = melds.length == 4 && total == 2;
  final duiduihu = stdWin && melds.every((m) => !m.isChi) && (isAllPungs(concealed) || canPengPengWild(c, wild));

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
      if (t == baidaTile) continue;
      if (t < kNumKinds) {
        suits.add(t ~/ 9);
      } else {
        hasHonor = true;
      }
    }
  }
  final qingyise = !hasHonor && suits.length <= 1;
  final hunyise = hasHonor && suits.length == 1;

  final isBig = dadiaoche || duiduihu || hunyise || qingyise || qidui || gangKai || qiangGang;

  // 滴麻子门槛: Plain hands require huaCount >= 2 or closed hand (门清) to win
  if (!isBig && !menqing && huaCount < 2) return null;

  final items = <(String, int)>[];
  var mult = 1;
  if (qingyise) {
    items.add(('清一色', 8));
    mult *= 4;
  } else if (hunyise) {
    items.add(('混一色', 4));
    mult *= 2;
  }
  if (dadiaoche) {
    items.add(('大吊车', 4));
    mult *= 2;
  }
  if (qidui) {
    items.add(('七对', 4));
    mult *= 2;
  } else if (duiduihu) {
    items.add(('对对胡', 4));
    mult *= 2;
  }
  if (gangKai) {
    items.add(('杠上开花', 2));
    mult *= 2;
  }
  if (qiangGang) {
    items.add(('抢杠胡', 2));
    mult *= 2;
  }

  final isDiMaZi = !isBig;
  if (isDiMaZi) {
    items.add(('滴麻子', 1));
  }
  if (menqing && !qidui) {
    items.add(('门清', 1));
  }
  if (huaCount > 0) {
    items.add(('硬花×$huaCount', huaCount));
  }
  if (selfDrawn) {
    items.add(('自摸', 1));
  }

  final fan = items.fold<int>(0, (a, b) => a + b.$2);
  return SuzhouResult(
    fan: fan,
    mult: mult,
    huaCount: huaCount,
    isMenqing: menqing,
    isDiMaZi: isDiMaZi,
    isDaDiaoChe: dadiaoche,
    isDuiDuiHu: duiduihu,
    isHunYiSe: hunyise,
    isQingYiSe: qingyise,
    isQiDui: qidui,
    isBig: isBig,
    items: items,
  );
}

List<int> suzhouWaits(
  List<int> concealed,
  List<Meld> melds, {
  required int baidaTile,
  int huaCount = 0,
}) {
  final out = <int>[];
  for (var t = 0; t < kKinds && t < concealed.length; t++) {
    concealed[t]++;
    final r = suzhouEvaluate(
      concealed,
      melds,
      baidaTile: baidaTile,
      huaCount: huaCount,
      selfDrawn: true,
    );
    concealed[t]--;
    if (r != null) out.add(t);
  }
  return out;
}

class _SzClaim {
  final int tile;
  final int from;
  final bool rob;
  final Map<int, Set<String>> opts;
  final Map<int, SuzhouResult> hu;
  final Map<int, Map<String, dynamic>> resp = {};
  _SzClaim(this.tile, this.from, this.rob, this.opts, {this.hu = const {}});
  List<int> get pending => [for (final s in opts.keys) if (!resp.containsKey(s)) s]..sort();
}

class _SzDiscard {
  final int tile;
  bool taken = false;
  final bool tsumogiri;
  _SzDiscard(this.tile, {this.tsumogiri = false});
}

/// 苏州麻将 (suzhoumj)
class SuzhouGame extends GameEngine {
  SuzhouGame(super.setup);

  late final int totalRounds = setup.opt<int>('rounds', 4);
  late final bool allowRon = setup.opt<bool>('allowRon', true);

  late List<int> scores = List.filled(players, 0);
  int handNo = 0;
  int dealer = 0;
  bool over = false;
  List<Map<String, dynamic>> history = [];

  // Suzhou-specific state: 翻百搭 (baidaIndicator -> baidaTile) & 拔花 (5z, 6z, 7z -> flowers[seat], huaCount[seat])
  int baidaIndicatorId = 0;
  int baidaTileId = 1;
  String get baidaIndicator => tileCode(baidaIndicatorId);
  String get baidaTile => tileCode(baidaTileId);

  late List<List<String>> flowers = List.generate(players, (_) => <String>[]);
  late List<int> huaCount = List.filled(players, 0);

  void setBaidaIndicator(int indicatorId) {
    baidaIndicatorId = indicatorId;
    baidaTileId = nextCyclicTile(indicatorId);
  }

  // Hand state
  String phase = 'act'; // act, claim, settle, over, pause
  String pausedPhase = '';
  List<List<int>> hands = [];
  List<List<Meld>> melds = [];
  List<List<_SzDiscard>> discards = [];
  List<int> drawn = [];
  List<int> wall = [];
  int turn = 0;
  bool canZimo = false;
  bool afterKong = false;
  int lastDiscardSeat = -1;
  String lastAction = '';
  Map<String, dynamic>? lastEvent;
  int eventSeq = 0;
  _SzClaim? claim;
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
    discards = List.generate(players, (_) => <_SzDiscard>[]);
    flowers = List.generate(players, (_) => <String>[]);
    huaCount = List.filled(players, 0);
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

    // Flip baidaIndicator from wall (prefer non-dragon indicator so 5z/6z/7z remain flower tiles)
    var indIdx = wall.lastIndexWhere((t) => !isDragon(t));
    if (indIdx < 0) indIdx = wall.length - 1;
    final indTile = wall.removeAt(indIdx);
    setBaidaIndicator(indTile);

    turn = dealer;
    phase = 'act';
    canZimo = true;
    host.log('第 $handNo/$totalRounds 局开始，${name(dealer)} 坐庄，翻出 ${tileName(baidaIndicatorId)}，百搭：${tileName(baidaTileId)}');
    lastAction = '百搭：${tileName(baidaTileId)} · 中发白可拔花';
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

  SuzhouResult? selfEval(int s) => suzhouEvaluate(
        hands[s],
        melds[s],
        baidaTile: baidaTileId,
        huaCount: huaCount[s],
        selfDrawn: true,
        gangKai: afterKong,
      );

  SuzhouResult? ronEval(int o, int t, {bool rob = false}) {
    if (!allowRon || t == baidaTileId || isDragon(t)) return null;
    final c = List<int>.of(hands[o]);
    c[t]++;
    return suzhouEvaluate(
      c,
      melds[o],
      baidaTile: baidaTileId,
      huaCount: huaCount[o],
      selfDrawn: false,
      qiangGang: rob,
    );
  }

  bool get canSelfHu => phase == 'act' && canZimo && selfEval(turn) != null;

  /// Dragon tiles ('5z', '6z', '7z') in [s]'s hand that can be declared as 拔花 (`bahua`).
  List<int> bahuaOptions(int s) {
    if (phase != 'act' || s != turn || wall.isEmpty) return const [];
    return [
      for (final t in const [kHaku, kHatsu, kChun])
        if (hands[s][t] > 0) t,
    ];
  }

  List<(int, bool)> selfKongs() {
    if (phase != 'act' || wall.isEmpty) return const [];
    final s = turn;
    final out = <(int, bool)>[];
    for (var t = 0; t < kKinds; t++) {
      if (t == baidaTileId || isDragon(t)) continue;
      if (hands[s][t] == 4) out.add((t, false));
      if (hands[s][t] >= 1 && melds[s].any((m) => m.isPeng && m.tile == t)) out.add((t, true));
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
    if (type == 'bahua') {
      final rawTile = a['tile'];
      final avail = bahuaOptions(s);
      if (avail.isEmpty) throw GameError('手里没有可拔花的箭牌（白/发/中）或牌山已空');
      final t = rawTile != null ? tileFromCode(rawTile) : avail.first;
      if (!isDragon(t) || hands[s][t] <= 0) {
        throw GameError('只能对白板（5z）、发财（6z）、红中（7z）执行拔花');
      }
      hands[s][t]--;
      if (drawn[s] == t && hands[s][t] == 0) drawn[s] = -1;
      flowers[s].add(tileCode(t));
      huaCount[s]++;
      lastAction = '${name(s)} 拔花 ${tileName(t)}（硬花 ${huaCount[s]}）';
      host.log(lastAction);
      _event('buhua', s, t);
      _draw(s, kong: true);
      return;
    }
    if (type == 'tsumo' || type == 'hu') {
      final r = canZimo ? selfEval(s) : null;
      if (r == null) throw GameError('未满足胡牌条件（平胡需门清或至少2花）');
      final t = drawn[s] >= 0 && hands[s][drawn[s]] > 0 ? drawn[s] : _anyTile(s);
      _settleWin({s: (t, r)}, -1);
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

  int _anyTile(int s) {
    for (var t = kKinds - 1; t >= 0; t--) {
      if (t != baidaTileId && hands[s][t] > 0) return t;
    }
    return baidaTileId;
  }

  void _discard(int s, int t) {
    hands[s][t]--;
    final giri = drawn[s] == t;
    drawn[s] = -1;
    discards[s].add(_SzDiscard(t, tsumogiri: giri));
    canZimo = false;
    afterKong = false;
    lastDiscardSeat = s;
    lastAction = '${name(s)} 打出 ${tileName(t)}';
    _event('discard', s, t);

    // Discarded baidaTile or dragon flower tiles cannot be claimed
    if (t == baidaTileId || isDragon(t)) {
      _coverPause(() => _draw((s + 1) % players));
      return;
    }

    final opts = <int, Set<String>>{};
    final hu = <int, SuzhouResult>{};
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
      }
      if (set.isNotEmpty) opts[o] = set;
    }
    if (opts.isEmpty) {
      _coverPause(() => _draw((s + 1) % players));
    } else {
      claim = _SzClaim(t, s, false, opts, hu: hu);
      phase = 'claim';
    }
  }

  int _prio(String type) => switch (type) { 'ron' || 'hu' => 30, 'gang' || 'peng' => 20, _ => 0 };

  int _maxPrio(_SzClaim c, int s) {
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
    c.resp[s] = {'type': type};
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
      huaCount[s] += 1;
      lastAction = '${name(s)} 明杠 ${tileName(c.tile)}（硬花+1）';
      host.log(lastAction);
      _event('gang', s, c.tile);
      _draw(s, kong: true);
      return;
    }
    hands[s][c.tile] -= 2;
    melds[s].add(Meld('peng', c.tile, claimed: c.tile, from: c.from));
    lastAction = '${name(s)} 碰 ${tileName(c.tile)}';
    _event('peng', s, c.tile);
    turn = s;
    phase = 'act';
    canZimo = false;
    afterKong = false;
    drawn[s] = -1;
  }

  void _selfKong(int s, int t, bool bu) {
    if (bu) {
      final opts = <int, Set<String>>{};
      final hu = <int, SuzhouResult>{};
      for (var o = 0; o < players; o++) {
        if (o == s) continue;
        final r = ronEval(o, t, rob: true);
        if (r != null) {
          opts[o] = {'ron'};
          hu[o] = r;
        }
      }
      if (opts.isNotEmpty) {
        claim = _SzClaim(t, s, true, opts, hu: hu);
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
    huaCount[s] += 2;
    lastAction = '${name(s)} 暗杠 ${tileName(t)}（硬花+2）';
    host.log(lastAction);
    _event('gang', s);
    _draw(s, kong: true);
  }

  void _finishBuGang(int s, int t) {
    hands[s][t]--;
    final m = melds[s].firstWhere((m) => m.isPeng && m.tile == t);
    m.kind = 'bgang';
    huaCount[s] += 1;
    lastAction = '${name(s)} 补杠 ${tileName(t)}（硬花+1）';
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

  void _settleWin(Map<int, (int, SuzhouResult)> wins, int from, {bool rob = false}) {
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
        var amt = res.fan * res.mult * (zimo ? 2 : 1);
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
        'menqing': res.isMenqing,
        'dadiaoche': res.isDaDiaoChe,
        'duiduihu': res.isDuiDuiHu,
        'hunyise': res.isHunYiSe,
        'qingyise': res.isQingYiSe,
        'qidui': res.isQiDui,
        'huaCount': res.huaCount,
        'flowers': List.of(flowers[w]),
        'fan': res.fan,
        'mult': res.mult,
        'total': totalWon,
        'items': res.toJson(),
        'pay': pay,
        'hand': codesOfCounts(hands[w]),
      });
      host.log(zimo
          ? '${name(w)} 自摸 ${tileName(tile)}！${res.label}（×${res.mult}）'
          : '${name(w)} 胡 ${name(from)} 的 ${tileName(tile)}！${res.label}（×${res.mult}）');
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
      'baidaIndicator': baidaIndicator,
      'baidaTile': baidaTile,
      'huaCount': List.of(huaCount),
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
        'flowers': List.of(flowers[s]),
        'huaCount': huaCount[s],
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
      'rule': 'suzhoumj',
      'phase': phase == 'pause' ? 'claim' : phase,
      'hand': handNo,
      'hands': totalRounds,
      'rounds': totalRounds,
      'dealer': dealer,
      'turn': turn,
      'wall': wall.length,
      'baidaIndicator': baidaIndicator,
      'baidaTile': baidaTile,
      'flowers': [for (final f in flowers) List.of(f)],
      'huaCount': List.of(huaCount),
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
        'huaCount': huaCount[seat],
        'flowers': List.of(flowers[seat]),
      };
      if (phase == 'act' && turn == seat) {
        final ev = canZimo ? selfEval(seat) : null;
        my['canHu'] = ev != null;
        my['canTsumo'] = ev != null;
        my['bahuaTiles'] = [for (final t in bahuaOptions(seat)) tileCode(t)];
        my['kongs'] = [for (final (t, _) in selfKongs()) tileCode(t)];
        my['discardable'] = [for (final t in legalDiscards(seat)) tileCode(t)];
      }
      if (phase == 'claim' && claim!.opts.containsKey(seat) && !claim!.resp.containsKey(seat)) {
        my['claim'] = claim!.opts[seat]!.toList();
      }
      final n = countTotal(hands[seat]);
      if (n % 3 == 1 && (phase == 'act' || phase == 'claim' || phase == 'pause')) {
        my['waits'] = [
          for (final t in suzhouWaits(hands[seat], melds[seat], baidaTile: baidaTileId, huaCount: huaCount[seat]))
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
        if (opts.contains('ron')) return {'type': 'ron'};
        if (opts.contains('gang')) return {'type': 'gang'};
        // Only Peng if we already have >= 2 hard flowers or are building towards 對對胡 / 混一色 / 清一色
        if (opts.contains('peng') && huaCount[seat] >= 2 && hands[seat][c.tile] == 2) {
          return {'type': 'peng'};
        }
        return {'type': 'pass'};
      case 'act':
        if (seat != turn) return null;
        final bh = bahuaOptions(seat);
        if (bh.isNotEmpty) {
          return {'type': 'bahua', 'tile': tileCode(bh.first)};
        }
        if (canSelfHu) return {'type': 'tsumo'};
        final ks = selfKongs();
        if (ks.isNotEmpty) {
          return {'type': 'gang', 'tile': tileCode(ks.first.$1)};
        }
        final ds = legalDiscards(seat);
        final nonWild = ds.where((t) => t != baidaTileId).toList();
        final pool = nonWild.isNotEmpty ? nonWild : ds;
        var best = pool.first;
        var bestVal = 999999;
        for (final t in pool) {
          final v = tileValue(hands[seat], t);
          if (v < bestVal) {
            bestVal = v;
            best = t;
          }
        }
        return {'type': 'discard', 'tile': tileCode(best)};
      default:
        return null;
    }
  }
}
