import '../../src/engine.dart';
import 'tiles.dart';

class TianjinResult {
  final int fan;
  final int mult;
  final bool noHun; // 没混儿 ×2
  final bool hunDiao; // 混儿吊 ×2
  final bool zhuoWuKui; // 捉五魁 ×4
  final bool isLong; // 龙 ×4
  final bool benHunLong; // 本混儿龙 ×8
  final bool isBig;
  final List<(String, int)> items;
  const TianjinResult({
    required this.fan,
    required this.mult,
    required this.noHun,
    required this.hunDiao,
    required this.zhuoWuKui,
    required this.isLong,
    required this.benHunLong,
    required this.isBig,
    required this.items,
  });

  String get label => [for (final (n, _) in items) n].join(' ');
  List<List<Object>> toJson() => [for (final (n, f) in items) [n, f]];
}

/// Checks whether a 13-tile hand + [melds] is in 混儿吊听口 (4 melds complete + 1 hunTile waiting on all 34 tiles).
bool canHunDiaoWait(List<int> hand13, List<Meld> melds, List<int> hunTiles) =>
    canWildcardPairWaitAfterDiscard(hand13, melds, hunTiles);

/// Evaluates a Tianjin Mahjong hand (136 tiles, self-draw only, [hunTile] / [hunTiles] are universal wildcards).
TianjinResult? tianjinEvaluate(
  List<int> concealed,
  List<Meld> melds, {
  required int hunTile,
  List<int>? hunTiles,
  int? winTile,
  bool selfDrawn = true,
  bool gangKai = false,
}) {
  // Tianjin Mahjong strictly requires self-draw (只许自摸，不可点炮)
  if (!selfDrawn) return null;

  final total = countTotal(concealed);
  final needSets = 4 - melds.length;
  if (needSets < 0 || total != needSets * 3 + 2) return null;

  final wildIds = (hunTiles != null && hunTiles.isNotEmpty) ? hunTiles : <int>[hunTile];
  final c = List<int>.of(concealed);
  var wild = 0;
  for (final w in wildIds) {
    if (w >= 0 && w < c.length) {
      wild += c[w];
      c[w] = 0;
    }
  }

  final pureStd = isStandardWin(concealed);
  final pureQidui = melds.isEmpty && isSevenPairs(concealed);
  final stdWin = pureStd || canAnyPairStandardWild(c, wild);
  final qidui = pureQidui || (melds.isEmpty && canSevenPairsWild(c, wild));

  if (!stdWin && !qidui) return null;

  // 1. 没混儿 (No Wildcards in hand): ×2
  final noHun = wild == 0 && (pureStd || pureQidui);

  // 2. 混儿吊 (Wildcard Pair Wait — 4 melds complete + 1 hunTile waiting on any tile as pair): ×2
  final hunDiao = wild >= 1 && isWildcardPairWait14(concealed, melds, wildIds);

  // 3. 捉五魁 (Catching 5m in a 4m-5m-6m wait): ×4
  var zhuoWuKui = false;
  if (needSets >= 1 &&
      (winTile == null || winTile == kWuKui || wildIds.contains(winTile)) &&
      (concealed[kWuKui] > 0 || (winTile != null && wildIds.contains(winTile)))) {
    // Check if {4m(3), 5m(4), 6m(5)} can be extracted as a sequence
    final u3 = c[3] > 0 ? 1 : 0;
    final u4 = c[4] > 0 ? 1 : 0;
    final u5 = c[5] > 0 ? 1 : 0;
    final naturalUsed = u3 + u4 + u5;
    final needW = 3 - naturalUsed;
    if (naturalUsed >= 2 && needW <= wild) {
      c[3] -= u3;
      c[4] -= u4;
      c[5] -= u5;
      if (canAnyPairStandardWild(c, wild - needW)) {
        zhuoWuKui = true;
      }
      c[3] += u3;
      c[4] += u4;
      c[5] += u5;
    }
  }

  // 4. 龙 (Same-suit 1..9 straight in hand): ×4, or 本混儿龙 (in hunTile's suit): ×8
  var isLong = false;
  var benHunLong = false;
  if (needSets >= 3) {
    for (var s = 0; s < 3; s++) {
      var present = 0;
      for (var r = 0; r < 9; r++) {
        if (c[s * 9 + r] > 0) present++;
      }
      final needW = 9 - present;
      if (present >= 6 && needW <= wild) {
        for (var r = 0; r < 9; r++) {
          if (c[s * 9 + r] > 0) c[s * 9 + r]--;
        }
        final ok = canAnyPairStandardWild(c, wild - needW);
        for (var r = 0; r < 9; r++) {
          if (concealed[s * 9 + r] > 0 && !wildIds.contains(s * 9 + r)) {
            // restored below
          }
        }
        // Restore c accurately
        for (var r = 0; r < 9; r++) {
          final idx = s * 9 + r;
          c[idx] = wildIds.contains(idx) ? 0 : concealed[idx];
        }
        if (ok) {
          isLong = true;
          if (wildIds.any((w) => w >= 0 && w < kNumKinds && w ~/ 9 == s)) {
            benHunLong = true;
          }
        }
      }
    }
  }

  final items = <(String, int)>[];
  var mult = 1;
  if (benHunLong) {
    items.add(('本混儿龙', 8));
    mult *= 8;
  } else if (isLong) {
    items.add(('龙', 4));
    mult *= 4;
  }
  if (zhuoWuKui) {
    items.add(('捉五魁', 4));
    mult *= 4;
  }
  if (hunDiao) {
    items.add(('混儿吊', 2));
    mult *= 2;
  }
  if (noHun) {
    items.add(('没混儿', 2));
    mult *= 2;
  }
  if (qidui && !hunDiao) {
    items.add(('七对', 4));
    mult *= 2;
  }
  if (gangKai) {
    items.add(('杠上开花', 2));
    mult *= 2;
  }
  if (items.isEmpty) {
    items.add(('自摸屁胡', 1));
  }

  final isBig = benHunLong || isLong || zhuoWuKui || hunDiao || noHun || qidui || gangKai;
  final fan = items.fold<int>(0, (a, b) => a + b.$2);
  return TianjinResult(
    fan: fan,
    mult: mult,
    noHun: noHun,
    hunDiao: hunDiao,
    zhuoWuKui: zhuoWuKui,
    isLong: isLong,
    benHunLong: benHunLong,
    isBig: isBig,
    items: items,
  );
}

List<int> tianjinWaits(
  List<int> concealed,
  List<Meld> melds, {
  required int hunTile,
  List<int>? hunTiles,
}) {
  final wildIds = (hunTiles != null && hunTiles.isNotEmpty) ? hunTiles : <int>[hunTile];
  if (canHunDiaoWait(concealed, melds, wildIds)) {
    return List<int>.generate(kKinds, (i) => i);
  }
  final out = <int>[];
  for (var t = 0; t < kKinds && t < concealed.length; t++) {
    concealed[t]++;
    final r = tianjinEvaluate(
      concealed,
      melds,
      hunTile: hunTile,
      hunTiles: wildIds,
      winTile: t,
      selfDrawn: true,
    );
    concealed[t]--;
    if (r != null) out.add(t);
  }
  return out;
}

class _TjClaim {
  final int tile;
  final int from;
  final Map<int, Set<String>> opts;
  final Map<int, List<int>> chis;
  final Map<int, Map<String, dynamic>> resp = {};
  _TjClaim(this.tile, this.from, this.opts, {this.chis = const {}});
  List<int> get pending => [for (final s in opts.keys) if (!resp.containsKey(s)) s]..sort();
}

class _TjDiscard {
  final int tile;
  bool taken = false;
  final bool tsumogiri;
  _TjDiscard(this.tile, {this.tsumogiri = false});
}

/// 天津麻将 (tianjinmj)
class TianjinGame extends GameEngine {
  TianjinGame(super.setup);

  late final int totalRounds = setup.opt<int>('rounds', 4);
  late final bool doubleHun = setup.opt<bool>('doubleHun', false);

  late List<int> scores = List.filled(players, 0);
  int handNo = 0;
  int dealer = 0;
  bool over = false;
  List<Map<String, dynamic>> history = [];

  // Tianjin-specific state: 翻混儿 (hunIndicator -> hunTile, optional fuHunTile)
  int hunIndicatorId = 0;
  int hunTileId = 1;
  int fuHunTileId = -1;
  String get hunIndicator => tileCode(hunIndicatorId);
  String get hunTile => tileCode(hunTileId);
  List<int> get hunTileIds => [
        hunTileId,
        if (doubleHun && fuHunTileId >= 0 && fuHunTileId != hunTileId) fuHunTileId,
      ];
  List<String> get hunTiles => [for (final id in hunTileIds) tileCode(id)];

  void setHunIndicator(int indicatorId) {
    hunIndicatorId = indicatorId;
    hunTileId = nextCyclicTile(indicatorId);
    fuHunTileId = doubleHun ? nextCyclicTile(hunTileId) : -1;
  }

  // Hand state
  String phase = 'act'; // act, claim, settle, over, pause
  String pausedPhase = '';
  List<List<int>> hands = [];
  List<List<Meld>> melds = [];
  List<List<_TjDiscard>> discards = [];
  List<int> drawn = [];
  List<int> wall = [];
  int turn = 0;
  bool canZimo = false;
  bool afterKong = false;
  int lastDiscardSeat = -1;
  String lastAction = '';
  Map<String, dynamic>? lastEvent;
  int eventSeq = 0;
  _TjClaim? claim;
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
    discards = List.generate(players, (_) => <_TjDiscard>[]);
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

    // 翻混儿: flip hunIndicator -> next cyclic tile is hunTile
    setHunIndicator(wall.removeLast());

    turn = dealer;
    phase = 'act';
    canZimo = true;
    host.log('第 $handNo/$totalRounds 局开始，${name(dealer)} 坐庄，翻出 ${tileName(hunIndicatorId)}，正混儿：${tileName(hunTileId)}');
    lastAction = '混儿牌：${tileName(hunTileId)} · 只许自摸';
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

  TianjinResult? selfEval(int s) => tianjinEvaluate(
        hands[s],
        melds[s],
        hunTile: hunTileId,
        hunTiles: hunTileIds,
        winTile: drawn[s] >= 0 ? drawn[s] : null,
        selfDrawn: true,
        gangKai: afterKong,
      );

  bool get canSelfHu => phase == 'act' && canZimo && selfEval(turn) != null;

  List<(int, bool)> selfKongs() {
    if (phase != 'act' || wall.isEmpty) return const [];
    final s = turn;
    final out = <(int, bool)>[];
    for (var t = 0; t < kKinds; t++) {
      if (hunTileIds.contains(t)) continue;
      if (hands[s][t] == 4) out.add((t, false));
      if (hands[s][t] >= 1 && melds[s].any((m) => m.isPeng && m.tile == t)) out.add((t, true));
    }
    return out;
  }

  List<int> chiOptions(int s, int t) {
    if (t >= kNumKinds || hunTileIds.contains(t)) return const [];
    final h = hands[s];
    final r = rankOf(t);
    final out = <int>[];
    for (var lo = t - 2; lo <= t; lo++) {
      final lr = r - (t - lo);
      if (lr < 1 || lr > 7) continue;
      var ok = true;
      for (var k = lo; k < lo + 3; k++) {
        if (hunTileIds.contains(k)) ok = false;
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
    if (type == 'ron') throw GameError('天津麻将只许自摸，不能点炮胡牌');
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
      if (r == null) throw GameError('现在不能自摸胡牌');
      final t = drawn[s] >= 0 && hands[s][drawn[s]] > 0 ? drawn[s] : _anyTile(s);
      _settleWin(s, t, r);
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
      if (!hunTileIds.contains(t) && hands[s][t] > 0) return t;
    }
    return hunTileId;
  }

  void _discard(int s, int t) {
    hands[s][t]--;
    final giri = drawn[s] == t;
    drawn[s] = -1;
    discards[s].add(_TjDiscard(t, tsumogiri: giri));
    canZimo = false;
    afterKong = false;
    lastDiscardSeat = s;
    lastAction = '${name(s)} 打出 ${tileName(t)}';
    _event('discard', s, t);

    if (hunTileIds.contains(t)) {
      _coverPause(() => _draw((s + 1) % players));
      return;
    }

    // Tianjin Mahjong: opponents can Peng, Gang, or Chi, but NEVER Ron!
    final opts = <int, Set<String>>{};
    final chis = <int, List<int>>{};
    for (var o = 0; o < players; o++) {
      if (o == s) continue;
      final set = <String>{};
      if (wall.isNotEmpty) {
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
      claim = _TjClaim(t, s, opts, chis: chis);
      phase = 'claim';
    }
  }

  int _prio(String type) => switch (type) { 'gang' || 'peng' => 20, 'chi' => 10, _ => 0 };

  int _maxPrio(_TjClaim c, int s) {
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
    var best = 0;
    for (final e in c.resp.values) {
      final p = _prio(e['type'] as String);
      if (p > best) best = p;
    }
    if (pend.any((p) => _maxPrio(c, p) > best)) return;
    _resolveClaim();
  }

  void _resolveClaim() {
    final c = claim!;
    claim = null;
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
      hands[s][t]--;
      final m = melds[s].firstWhere((m) => m.isPeng && m.tile == t);
      m.kind = 'bgang';
      lastAction = '${name(s)} 补杠 ${tileName(t)}';
      host.log(lastAction);
      _event('gang', s, t);
      _draw(s, kong: true);
      return;
    }
    hands[s][t] -= 4;
    melds[s].add(Meld('agang', t));
    lastAction = '${name(s)} 暗杠 ${tileName(t)}';
    host.log(lastAction);
    _event('gang', s);
    _draw(s, kong: true);
  }

  void _pay(int from, int to, int amt) {
    scores[from] -= amt;
    scores[to] += amt;
    handDelta[from] -= amt;
    handDelta[to] += amt;
  }

  void _settleWin(int w, int tile, TianjinResult res) {
    if (hands[w][tile] > 0) hands[w][tile]--;
    drawn[w] = -1;
    final pay = <String, int>{};
    var totalWon = 0;
    for (var p = 0; p < players; p++) {
      if (p == w) continue;
      var amt = res.fan * res.mult * 2;
      if (w == dealer || p == dealer) amt *= 2;
      _pay(p, w, amt);
      pay['$p'] = amt;
      totalWon += amt;
    }
    events.add({
      'kind': 'hu',
      'seat': w,
      'from': -1,
      'tile': tileCode(tile),
      'zimo': true,
      'rob': false,
      'big': res.isBig,
      'noHun': res.noHun,
      'hunDiao': res.hunDiao,
      'zhuoWuKui': res.zhuoWuKui,
      'isLong': res.isLong,
      'benHunLong': res.benHunLong,
      'fan': res.fan,
      'mult': res.mult,
      'total': totalWon,
      'items': res.toJson(),
      'pay': pay,
      'hand': codesOfCounts(hands[w]),
    });
    host.log('${name(w)} 自摸 ${tileName(tile)}！${res.label}（×${res.mult}）');
    _event('zimo', w, tile);
    lastAction = '${name(w)} 自摸 ${res.label}';
    nextDealer = w;
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
      'hunIndicator': hunIndicator,
      'hunTile': hunTile,
      'hunTiles': hunTiles,
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
      'rule': 'tianjinmj',
      'phase': phase == 'pause' ? 'claim' : phase,
      'hand': handNo,
      'hands': totalRounds,
      'rounds': totalRounds,
      'dealer': dealer,
      'turn': turn,
      'wall': wall.length,
      'hunIndicator': hunIndicator,
      'hunTile': hunTile,
      'hunTiles': hunTiles,
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
      v['claimRob'] = false;
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
        final ev = canZimo ? selfEval(seat) : null;
        my['canHu'] = ev != null;
        my['canTsumo'] = ev != null;
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
          for (final t in tianjinWaits(hands[seat], melds[seat], hunTile: hunTileId, hunTiles: hunTileIds))
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
        if (opts.contains('gang')) return {'type': 'gang'};
        if (opts.contains('peng') && hands[seat][c.tile] == 2) return {'type': 'peng'};
        if (opts.contains('chi') && (botLevel == 0 || rng.nextDouble() < 0.5)) {
          final list = c.chis[seat]!;
          return {'type': 'chi', 'tile': tileCode(list.first)};
        }
        return {'type': 'pass'};
      case 'act':
        if (seat != turn) return null;
        if (canSelfHu) return {'type': 'tsumo'};
        final ks = selfKongs();
        if (ks.isNotEmpty) {
          return {'type': 'gang', 'tile': tileCode(ks.first.$1)};
        }
        final disc = legalDiscards(seat);
        if (botLevel >= 1) {
          for (final t in disc) {
            if (hunTileIds.contains(t)) continue;
            hands[seat][t]--;
            final hd = canHunDiaoWait(hands[seat], melds[seat], hunTileIds);
            hands[seat][t]++;
            if (hd) return {'type': 'discard', 'tile': tileCode(t)};
          }
        }
        if (botLevel == 0) {
          final nonHun = disc.where((t) => !hunTileIds.contains(t)).toList();
          final pool = nonHun.isNotEmpty ? nonHun : disc;
          return {'type': 'discard', 'tile': tileCode(pool[rng.nextInt(pool.length)])};
        }
        var bestT = disc.first;
        var bestScore = 1 << 20;
        for (final t in disc) {
          var v = tileValue(hands[seat], t);
          if (hunTileIds.contains(t)) v += 1000;
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
