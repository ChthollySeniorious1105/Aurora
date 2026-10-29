import '../../src/engine.dart';
import 'tiles.dart';

class YunnanResult {
  final int fan;
  final int mult;
  final bool isShiFeng; // 十风胡 ×4
  final bool isWuMeiHua; // 五梅花 ×5 (杠上花胡 5p 或 1s)
  final bool isGangShangHua; // 杠上花 ×3
  final bool isQiDui; // 七对 ×2
  final bool isPengPeng; // 碰碰胡 ×2
  final bool isQingYiSe; // 清一色 ×4
  final bool isHunYiSe; // 混一色 ×2
  final bool noWild; // 无鸡硬胡
  final bool isBig;
  final List<(String, int)> items;

  const YunnanResult({
    required this.fan,
    required this.mult,
    required this.isShiFeng,
    required this.isWuMeiHua,
    required this.isGangShangHua,
    required this.isQiDui,
    required this.isPengPeng,
    required this.isQingYiSe,
    required this.isHunYiSe,
    required this.noWild,
    required this.isBig,
    required this.items,
  });

  String get label => [for (final (n, _) in items) n].join(' ');
  List<List<Object>> toJson() => [for (final (n, f) in items) [n, f]];
}

/// Evaluates a Yunnan Shifeng Mahjong (云南十风麻将) hand (136 tiles):
/// - `'1s'` ([kYaoJi]) acts as a universal wildcard in hand (幺鸡任用).
/// - 十风胡 (`shifeng: true`): immediate `×4` full-table win when `consecutiveHonors[seat] >= targetHonors`.
/// - 五梅花 / 杠上花: winning on a Gang replacement draw (`gangKai: true`) scores
///   **杠上花 (`×3`)**, or **五梅花 (`×5`)** if the winning tile is `'5p'` ([kWuTong]) or `'1s'` ([kYaoJi])!
YunnanResult? yunnanEvaluate(
  List<int> concealed,
  List<Meld> melds, {
  Object? winTile,
  int laiziTile = kYaoJi,
  bool shifeng = false,
  bool selfDrawn = false,
  bool gangKai = false,
  bool qiangGang = false,
}) {
  if (shifeng) {
    return const YunnanResult(
      fan: 8,
      mult: 4,
      isShiFeng: true,
      isWuMeiHua: false,
      isGangShangHua: false,
      isQiDui: false,
      isPengPeng: false,
      isQingYiSe: false,
      isHunYiSe: false,
      noWild: true,
      isBig: true,
      items: [('十风胡', 8)],
    );
  }

  final total = countTotal(concealed);
  final needSets = 4 - melds.length;
  if (needSets < 0 || total != needSets * 3 + 2) return null;

  final wild = (laiziTile >= 0 && laiziTile < concealed.length) ? concealed[laiziTile] : 0;
  final pureStd = isStandardWin(concealed);
  final pureQidui = melds.isEmpty && isSevenPairs(concealed);
  final noWild = (pureStd || pureQidui) && wild == 0;

  final c = List<int>.of(concealed);
  if (laiziTile >= 0 && laiziTile < c.length) {
    c[laiziTile] = 0;
  }

  final stdWin = pureStd || canAnyPairStandardWild(c, wild);
  final qidui = pureQidui || (melds.isEmpty && canSevenPairsWild(c, wild));
  if (!stdWin && !qidui) return null;

  final pengpeng = stdWin && melds.every((m) => !m.isChi) && (isAllPungs(concealed) || canPengPengWild(c, wild));

  final suits = <int>{};
  var hasHonor = false;
  for (var t = 0; t < c.length; t++) {
    if (c[t] <= 0) continue;
    if (t < kNumKinds) {
      suits.add(t ~/ 9);
    } else {
      hasHonor = true;
    }
  }
  for (final m in melds) {
    for (final t in m.tiles) {
      if (t == laiziTile) continue;
      if (t < kNumKinds) {
        suits.add(t ~/ 9);
      } else {
        hasHonor = true;
      }
    }
  }

  final qingyise = !hasHonor && suits.length <= 1;
  final hunyise = hasHonor && suits.length == 1;

  final wTile = winTile == null ? -1 : (winTile is int ? winTile : tileFromCode(winTile));
  final isMeiHuaTile = wTile == kWuTong || wTile == kYaoJi;
  final wumeihua = gangKai && isMeiHuaTile;
  final gangshanghua = gangKai && !wumeihua;

  final items = <(String, int)>[];
  var mult = 1;

  if (wumeihua) {
    items.add(('五梅花', 5));
    mult *= 5;
  } else if (gangshanghua) {
    items.add(('杠上花', 3));
    mult *= 3;
  }
  if (qingyise) {
    items.add(('清一色', 8));
    mult *= 4;
  } else if (hunyise) {
    items.add(('混一色', 4));
    mult *= 2;
  }
  if (qidui) {
    items.add(('七对', 4));
    mult *= 2;
  } else if (pengpeng) {
    items.add(('碰碰胡', 4));
    mult *= 2;
  }
  if (qiangGang) {
    items.add(('抢杠胡', 2));
    mult *= 2;
  }
  if (noWild) {
    items.add(('无鸡硬胡', 2));
  }
  if (items.isEmpty) {
    items.add(('平胡', 1));
  }
  if (selfDrawn) {
    items.add(('自摸', 1));
  }

  final isBig = wumeihua || gangshanghua || qingyise || hunyise || qidui || pengpeng || qiangGang || noWild;
  final fan = items.fold<int>(0, (a, b) => a + b.$2);
  return YunnanResult(
    fan: fan,
    mult: mult,
    isShiFeng: false,
    isWuMeiHua: wumeihua,
    isGangShangHua: gangshanghua,
    isQiDui: qidui,
    isPengPeng: pengpeng,
    isQingYiSe: qingyise,
    isHunYiSe: hunyise,
    noWild: noWild,
    isBig: isBig,
    items: items,
  );
}

List<int> yunnanWaits(
  List<int> concealed,
  List<Meld> melds, {
  int laiziTile = kYaoJi,
}) {
  final out = <int>[];
  for (var t = 0; t < kKinds && t < concealed.length; t++) {
    concealed[t]++;
    final r = yunnanEvaluate(
      concealed,
      melds,
      winTile: t,
      laiziTile: laiziTile,
      selfDrawn: true,
    );
    concealed[t]--;
    if (r != null) out.add(t);
  }
  return out;
}

class _YnClaim {
  final int tile;
  final int from;
  final bool rob;
  final Map<int, Set<String>> opts;
  final Map<int, YunnanResult> hu;
  final Map<int, Map<String, dynamic>> resp = {};
  _YnClaim(this.tile, this.from, this.rob, this.opts, {this.hu = const {}});
  List<int> get pending => [for (final s in opts.keys) if (!resp.containsKey(s)) s]..sort();
}

class _YnDiscard {
  final int tile;
  bool taken = false;
  final bool tsumogiri;
  _YnDiscard(this.tile, {this.tsumogiri = false});
}

/// 云南十风麻将 (yunnanmj)
class YunnanGame extends GameEngine {
  YunnanGame(super.setup);

  late final int totalRounds = setup.opt<int>('rounds', 4);
  late final int targetHonors = setup.opt<int>('targetHonors', 10);

  late List<int> scores = List.filled(players, 0);
  int handNo = 0;
  int dealer = 0;
  bool over = false;
  List<Map<String, dynamic>> history = [];

  // Yunnan-specific state: 幺鸡任用 ('1s' = kYaoJi) + 十风连续字牌计数 (consecutiveHonors[seat])
  int laiziTileId = kYaoJi;
  String get laiziTile => tileCode(laiziTileId);
  late List<int> consecutiveHonors = List.filled(players, 0);

  // Hand state
  String phase = 'act'; // act, claim, settle, over, pause
  String pausedPhase = '';
  List<List<int>> hands = [];
  List<List<Meld>> melds = [];
  List<List<_YnDiscard>> discards = [];
  List<int> drawn = [];
  List<int> wall = [];
  int turn = 0;
  bool canZimo = false;
  bool afterKong = false;
  int lastDiscardSeat = -1;
  String lastAction = '';
  Map<String, dynamic>? lastEvent;
  int eventSeq = 0;
  _YnClaim? claim;
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
    discards = List.generate(players, (_) => <_YnDiscard>[]);
    consecutiveHonors = List.filled(players, 0);
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

    turn = dealer;
    phase = 'act';
    canZimo = true;
    host.log('第 $handNo/$totalRounds 局开始，${name(dealer)} 坐庄（幺鸡任用百搭 · 连续 $targetHonors 张字牌十风胡 · 五梅花×5）');
    lastAction = '幺鸡任用 · 十风($targetHonors张) · 五梅花';
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

  int _firstHonorInHand(int s) {
    for (var t = kEast; t < kKinds; t++) {
      if (hands[s][t] > 0) return t;
    }
    return -1;
  }

  bool canShifeng(int s) {
    if (consecutiveHonors[s] >= targetHonors) return true;
    if (phase == 'act' && turn == s && consecutiveHonors[s] == targetHonors - 1 && _firstHonorInHand(s) >= 0) {
      return true;
    }
    return false;
  }

  int _winTileForSelf(int s) {
    if (drawn[s] >= 0 && hands[s][drawn[s]] > 0) return drawn[s];
    if (afterKong) {
      if (hands[s][kWuTong] > 0) return kWuTong;
      if (hands[s][kYaoJi] > 0) return kYaoJi;
    }
    for (var t = kKinds - 1; t >= 0; t--) {
      if (t != laiziTileId && hands[s][t] > 0) return t;
    }
    return laiziTileId;
  }

  YunnanResult? selfEval(int s) => yunnanEvaluate(
        hands[s],
        melds[s],
        winTile: _winTileForSelf(s),
        laiziTile: laiziTileId,
        selfDrawn: true,
        gangKai: afterKong,
      );

  YunnanResult? ronEval(int o, int t, {bool rob = false}) {
    if (t == laiziTileId) return null;
    final c = List<int>.of(hands[o]);
    c[t]++;
    return yunnanEvaluate(
      c,
      melds[o],
      winTile: t,
      laiziTile: laiziTileId,
      selfDrawn: false,
      qiangGang: rob,
    );
  }

  bool get canSelfHu => phase == 'act' && canZimo && selfEval(turn) != null;

  List<(int, bool)> selfKongs() {
    if (phase != 'act' || wall.isEmpty) return const [];
    final s = turn;
    final out = <(int, bool)>[];
    for (var t = 0; t < kKinds; t++) {
      if (t == laiziTileId) continue;
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

    // Allow declaring 'shifeng' immediately whenever consecutiveHonors[seat] >= targetHonors
    if (type == 'shifeng' && consecutiveHonors[seat] >= targetHonors && (phase == 'act' || phase == 'claim' || phase == 'pause')) {
      final res = yunnanEvaluate(hands[seat], melds[seat], shifeng: true, selfDrawn: true)!;
      final lastT = discards[seat].isNotEmpty ? discards[seat].last.tile : kEast;
      _settleWin({seat: (lastT, res)}, -1);
      return;
    }

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
    if (type == 'shifeng') {
      if (consecutiveHonors[s] == targetHonors - 1) {
        final argT = tileFromCode(a['tile']);
        final hTile = (argT >= 0 && isHonor(argT) && hands[s][argT] > 0) ? argT : _firstHonorInHand(s);
        if (hTile >= 0) {
          hands[s][hTile]--;
          final giri = drawn[s] == hTile;
          drawn[s] = -1;
          discards[s].add(_YnDiscard(hTile, tsumogiri: giri));
          consecutiveHonors[s]++;
          final res = yunnanEvaluate(hands[s], melds[s], shifeng: true, selfDrawn: true)!;
          _settleWin({s: (hTile, res)}, -1);
          return;
        }
      }
      if (consecutiveHonors[s] >= targetHonors) {
        final res = yunnanEvaluate(hands[s], melds[s], shifeng: true, selfDrawn: true)!;
        final lastT = discards[s].isNotEmpty ? discards[s].last.tile : kEast;
        _settleWin({s: (lastT, res)}, -1);
        return;
      }
      throw GameError('连续打出字牌尚未达到 $targetHonors 张，不能胡十风');
    }
    if (type == 'tsumo' || type == 'hu') {
      final r = canZimo ? selfEval(s) : null;
      if (r == null) throw GameError('现在不能自摸胡牌');
      final t = _winTileForSelf(s);
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

  void _discard(int s, int t) {
    hands[s][t]--;
    final giri = drawn[s] == t;
    drawn[s] = -1;
    discards[s].add(_YnDiscard(t, tsumogiri: giri));
    if (isHonor(t)) {
      consecutiveHonors[s]++;
    } else {
      consecutiveHonors[s] = 0;
    }
    canZimo = false;
    afterKong = false;
    lastDiscardSeat = s;
    lastAction = isHonor(t)
        ? '${name(s)} 打出 ${tileName(t)}（十风连打 ${consecutiveHonors[s]}/$targetHonors）'
        : '${name(s)} 打出 ${tileName(t)}';
    _event('discard', s, t);

    if (t == laiziTileId) {
      _coverPause(() => _draw((s + 1) % players));
      return;
    }

    final opts = <int, Set<String>>{};
    final hu = <int, YunnanResult>{};
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
      claim = _YnClaim(t, s, false, opts, hu: hu);
      phase = 'claim';
    }
  }

  int _prio(String type) => switch (type) { 'ron' || 'hu' => 30, 'gang' || 'peng' => 20, _ => 0 };

  int _maxPrio(_YnClaim c, int s) {
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
    if (!isHonor(c.tile)) {
      consecutiveHonors[s] = 0; // Making a suited meld resets consecutiveHonors
    }
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
    if (!isHonor(t)) {
      consecutiveHonors[s] = 0;
    }
    if (bu) {
      final opts = <int, Set<String>>{};
      final hu = <int, YunnanResult>{};
      for (var o = 0; o < players; o++) {
        if (o == s) continue;
        final r = ronEval(o, t, rob: true);
        if (r != null) {
          opts[o] = {'ron'};
          hu[o] = r;
        }
      }
      if (opts.isNotEmpty) {
        claim = _YnClaim(t, s, true, opts, hu: hu);
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

  void _settleWin(Map<int, (int, YunnanResult)> wins, int from, {bool rob = false}) {
    final zimo = from < 0;
    for (final e in wins.entries) {
      final w = e.key;
      final (tile, res) = e.value;
      if (zimo && !res.isShiFeng && hands[w][tile] > 0) hands[w][tile]--;
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
        'shifeng': res.isShiFeng,
        'wumeihua': res.isWuMeiHua,
        'gangshanghua': res.isGangShangHua,
        'consecutiveHonors': consecutiveHonors[w],
        'fan': res.fan,
        'mult': res.mult,
        'total': totalWon,
        'items': res.toJson(),
        'pay': pay,
        'hand': codesOfCounts(hands[w]),
      });
      host.log(res.isShiFeng
          ? '${name(w)} 达成【十风胡】（连续打出 ${consecutiveHonors[w]} 张字牌，全场×4）！'
          : (zimo
              ? '${name(w)} 自摸 ${tileName(tile)}！${res.label}（×${res.mult}）'
              : '${name(w)} 胡 ${name(from)} 的 ${tileName(tile)}！${res.label}（×${res.mult}）'));
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
      'laiziTile': laiziTile,
      'targetHonors': targetHonors,
      'consecutiveHonors': List.of(consecutiveHonors),
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
        'consecutiveHonors': consecutiveHonors[s],
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
      'rule': 'yunnanmj',
      'phase': phase == 'pause' ? 'claim' : phase,
      'hand': handNo,
      'hands': totalRounds,
      'rounds': totalRounds,
      'dealer': dealer,
      'turn': turn,
      'wall': wall.length,
      'laiziTile': laiziTile,
      'targetHonors': targetHonors,
      'consecutiveHonors': List.of(consecutiveHonors),
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
        'consecutiveHonors': consecutiveHonors[seat],
      };
      if (phase == 'act' && turn == seat) {
        final ev = canZimo ? selfEval(seat) : null;
        my['canHu'] = ev != null;
        my['canTsumo'] = ev != null;
        my['canShifeng'] = canShifeng(seat);
        my['kongs'] = [for (final (t, _) in selfKongs()) tileCode(t)];
        my['discardable'] = [for (final t in legalDiscards(seat)) tileCode(t)];
      }
      if (phase == 'claim' && claim!.opts.containsKey(seat) && !claim!.resp.containsKey(seat)) {
        my['claim'] = claim!.opts[seat]!.toList();
      }
      final n = countTotal(hands[seat]);
      if (n % 3 == 1 && (phase == 'act' || phase == 'claim' || phase == 'pause')) {
        my['waits'] = [
          for (final t in yunnanWaits(hands[seat], melds[seat], laiziTile: laiziTileId)) tileCode(t)
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
        if (canShifeng(seat)) return {'type': 'shifeng'};
        if (canSelfHu) return {'type': 'tsumo'};
        final ks = selfKongs();
        if (ks.isNotEmpty) return {'type': 'gang', 'tile': tileCode(ks.first.$1)};
        // If chasing 十风 (already >= 3 consecutive honors and holding an honor tile), discard honor tile
        final hTile = _firstHonorInHand(seat);
        if (consecutiveHonors[seat] >= 2 && hTile >= 0) {
          return {'type': 'discard', 'tile': tileCode(hTile)};
        }
        final legals = legalDiscards(seat);
        final nonWild = [for (final t in legals) if (t != laiziTileId) t];
        final pool = nonWild.isNotEmpty ? nonWild : legals;
        if (botLevel == 0 && rng.nextDouble() < 0.35) {
          return {'type': 'discard', 'tile': tileCode(pool[rng.nextInt(pool.length)])};
        }
        var best = pool.first, bestScore = 1 << 20;
        for (final t in pool) {
          final sc = tileValue(hands[seat], t);
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
        if (o.contains('gang') && consecutiveHonors[seat] < 3) return {'type': 'gang'};
        if (o.contains('peng') && consecutiveHonors[seat] < 3 && (hands[seat][c.tile] >= 3 || rng.nextDouble() < 0.5)) {
          return {'type': 'peng'};
        }
        return {'type': 'pass'};
      case 'settle':
        return ready.contains(seat) ? null : {'type': 'next'};
    }
    return null;
  }
}
