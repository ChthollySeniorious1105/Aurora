import '../../src/engine.dart';
import 'tiles.dart';

class HenanResult {
  final int fan;
  final int mult;
  final bool isSiHun; // 四混儿直接胡牌 ×2
  final bool isQiDui; // 七对 ×2
  final bool isQingYiSe; // 清一色 ×4
  final bool isHunYiSe; // 混一色 ×2
  final bool isPengPeng; // 碰碰胡 ×2
  final bool noWild; // 无混儿硬胡
  final bool isBig;
  final List<(String, int)> items;

  const HenanResult({
    required this.fan,
    required this.mult,
    required this.isSiHun,
    required this.isQiDui,
    required this.isQingYiSe,
    required this.isHunYiSe,
    required this.isPengPeng,
    required this.noWild,
    required this.isBig,
    required this.items,
  });

  String get label => [for (final (n, _) in items) n].join(' ');
  List<List<Object>> toJson() => [for (final (n, f) in items) [n, f]];
}

/// Evaluates a Henan Mahjong (河南麻将) hand (136 tiles):
/// - [hunTile] (flipped from `hunIndicator` -> next cyclic tile) is a universal wildcard in hand.
/// - Holding all 4 [hunTile]s on self-draw is an immediate win (**四混儿**, `{'type': 'sihun'}`).
/// - Supports standard 4 sets + 1 pair and seven pairs (`七对`), plus `清一色`, `混一色`, `碰碰胡`, `杠上开花`, `抢杠胡`.
HenanResult? henanEvaluate(
  List<int> concealed,
  List<Meld> melds, {
  Object? hunTile = -1,
  bool sihun = false,
  bool selfDrawn = false,
  bool gangKai = false,
  bool qiangGang = false,
}) {
  final total = countTotal(concealed);
  final needSets = 4 - melds.length;
  if (needSets < 0 || total != needSets * 3 + 2) return null;

  final hunId = tileFromCode(hunTile);
  final wild = (hunId >= 0 && hunId < concealed.length) ? concealed[hunId] : 0;
  final isSiHun = sihun || (selfDrawn && wild >= 4);

  final pureStd = isStandardWin(concealed);
  final pureQidui = melds.isEmpty && isSevenPairs(concealed);
  final noWild = (pureStd || pureQidui) && wild == 0;

  final c = List<int>.of(concealed);
  if (hunId >= 0 && hunId < c.length) {
    c[hunId] = 0;
  }

  final stdWin = pureStd || (wild > 0 && canAnyPairStandardWild(c, wild));
  final qidui = pureQidui || (melds.isEmpty && wild > 0 && canSevenPairsWild(c, wild));
  final pengpeng = stdWin && melds.every((m) => !m.isChi) && (isAllPungs(concealed) || (wild > 0 && canPengPengWild(c, wild)));

  if (!isSiHun && !stdWin && !qidui) return null;

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
      if (t == hunId) continue;
      if (t < kNumKinds) {
        suits.add(t ~/ 9);
      } else {
        hasHonor = true;
      }
    }
  }
  final qingyise = (stdWin || qidui) && !hasHonor && suits.length <= 1;
  final hunyise = (stdWin || qidui) && hasHonor && suits.length == 1;

  final items = <(String, int)>[];
  var mult = 1;
  if (isSiHun) {
    items.add(('四混儿', 6));
    mult *= 2;
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
  if (gangKai) {
    items.add(('杠上开花', 2));
    mult *= 2;
  }
  if (qiangGang) {
    items.add(('抢杠胡', 2));
    mult *= 2;
  }
  if (noWild && !isSiHun) {
    items.add(('无混硬胡', 2));
  }
  if (items.isEmpty) {
    items.add(('平胡', 1));
  }
  if (selfDrawn && !isSiHun) {
    items.add(('自摸', 1));
  }

  final isBig = isSiHun || qingyise || hunyise || qidui || pengpeng || gangKai || qiangGang || noWild;
  final fan = items.fold<int>(0, (a, b) => a + b.$2);
  return HenanResult(
    fan: fan,
    mult: mult,
    isSiHun: isSiHun,
    isQiDui: qidui,
    isQingYiSe: qingyise,
    isHunYiSe: hunyise,
    isPengPeng: pengpeng,
    noWild: noWild,
    isBig: isBig,
    items: items,
  );
}

List<int> henanWaits(
  List<int> concealed,
  List<Meld> melds, {
  Object? hunTile = -1,
}) {
  final out = <int>[];
  for (var t = 0; t < kKinds && t < concealed.length; t++) {
    concealed[t]++;
    final r = henanEvaluate(concealed, melds, hunTile: hunTile, selfDrawn: true);
    concealed[t]--;
    if (r != null) out.add(t);
  }
  return out;
}

class _HnClaim {
  final int tile;
  final int from;
  final bool rob;
  final Map<int, Set<String>> opts;
  final Map<int, HenanResult> hu;
  final Map<int, Map<String, dynamic>> resp = {};
  _HnClaim(this.tile, this.from, this.rob, this.opts, {this.hu = const {}});
  List<int> get pending => [for (final s in opts.keys) if (!resp.containsKey(s)) s]..sort();
}

class _HnDiscard {
  final int tile;
  bool taken = false;
  final bool tsumogiri;
  _HnDiscard(this.tile, {this.tsumogiri = false});
}

/// 河南麻将 (henanmj)
class HenanGame extends GameEngine {
  HenanGame(super.setup);

  late final int totalRounds = setup.opt<int>('rounds', 4);
  late final bool allowRon = setup.opt<bool>('allowRon', true);

  late List<int> scores = List.filled(players, 0);
  int handNo = 0;
  int dealer = 0;
  bool over = false;
  List<Map<String, dynamic>> history = [];

  // Henan-specific state: Step 1 选跑分 (paofen in 0..3) & 翻混儿 (hunIndicator -> hunTile)
  late List<int> paofen = List.filled(players, 0);
  Set<int> paofenDone = {};
  int hunIndicatorId = 0;
  int hunTileId = 1;
  String get hunIndicator => tileCode(hunIndicatorId);
  String get hunTile => tileCode(hunTileId);

  void setHunIndicator(Object indicator) {
    final id = tileFromCode(indicator);
    if (id >= 0) {
      hunIndicatorId = id;
      hunTileId = nextCyclicTile(id);
    }
  }

  void setHunTile(Object tile) {
    final id = tileFromCode(tile);
    if (id >= 0) {
      hunTileId = id;
    }
  }

  // Hand state
  String phase = 'paofen'; // paofen, act, claim, settle, over, pause
  String pausedPhase = '';
  List<List<int>> hands = [];
  List<List<Meld>> melds = [];
  List<List<_HnDiscard>> discards = [];
  List<int> drawn = [];
  List<int> wall = [];
  int turn = 0;
  bool canZimo = false;
  bool afterKong = false;
  int lastDiscardSeat = -1;
  String lastAction = '';
  Map<String, dynamic>? lastEvent;
  int eventSeq = 0;
  _HnClaim? claim;
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
    dealer = 0;
    _startHand();
  }

  void _startHand() {
    handNo++;
    wall = <int>[for (var t = 0; t < kKinds; t++) for (var k = 0; k < 4; k++) t]..shuffle(rng);
    hands = List.generate(players, (_) => List.filled(kKinds, 0));
    melds = List.generate(players, (_) => <Meld>[]);
    discards = List.generate(players, (_) => <_HnDiscard>[]);
    paofen = List.filled(players, 0);
    paofenDone = {};
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

    final ind = wall.removeLast();
    setHunIndicator(ind);

    turn = dealer;
    phase = 'paofen';
    canZimo = true;
    host.log('第 $handNo/$totalRounds 局开始，${name(dealer)} 坐庄，翻出 ${tileName(hunIndicatorId)}，本局混儿牌：${tileName(hunTileId)}，请选跑分（0~3 分）');
    lastAction = '混儿：${tileName(hunTileId)} · 请选跑分（0~3分）';
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

  HenanResult? selfEval(int s, {bool sihun = false}) => henanEvaluate(
        hands[s],
        melds[s],
        hunTile: hunTileId,
        sihun: sihun,
        selfDrawn: true,
        gangKai: afterKong,
      );

  HenanResult? ronEval(int o, int t, {bool rob = false}) {
    if (!allowRon || t == hunTileId) return null;
    final c = List<int>.of(hands[o]);
    c[t]++;
    return henanEvaluate(
      c,
      melds[o],
      hunTile: hunTileId,
      selfDrawn: false,
      qiangGang: rob,
    );
  }

  bool get canSelfHu => phase == 'act' && canZimo && selfEval(turn) != null;
  bool get canSiHun => phase == 'act' && canZimo && hands[turn][hunTileId] >= 4;
  bool canSihun(int s) => phase == 'act' && turn == s && canZimo && hands[s][hunTileId] >= 4;

  List<(int, bool)> selfKongs() {
    if (phase != 'act' || wall.isEmpty) return const [];
    final s = turn;
    final out = <(int, bool)>[];
    for (var t = 0; t < kKinds; t++) {
      if (t == hunTileId) continue;
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
  int get botDelayMs => phase == 'claim' || phase == 'paofen' ? 450 : 700;

  @override
  List<int> get waitingFor {
    switch (phase) {
      case 'paofen':
        return [for (var s = 0; s < players; s++) if (!paofenDone.contains(s)) s];
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
      case 'paofen':
        if (type != 'paofen') throw GameError('请先选择本局跑分（0~3 分）');
        if (paofenDone.contains(seat)) throw GameError('你已经选过跑分了');
        final s = asInt(a['score'] ?? a['count'] ?? a['paofen'], -1);
        if (s < 0 || s > 3) throw GameError('跑分必须在 0~3 分之间');
        paofen[seat] = s;
        paofenDone.add(seat);
        host.log('${name(seat)} 选跑分 $s 分');
        if (paofenDone.length >= players) {
          phase = 'act';
          turn = dealer;
          canZimo = true;
          lastAction = '混儿：${tileName(hunTileId)} · ${name(dealer)} 出牌';
        }
        return;
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
    if (type == 'sihun') {
      if (!canZimo || hands[s][hunTileId] < 4) {
        throw GameError('需要手握 4 张混儿牌才能发动【四混儿】胡牌');
      }
      final r = selfEval(s, sihun: true)!;
      _settleWin({s: (hunTileId, r)}, -1);
      return;
    }
    if (type == 'tsumo' || type == 'hu') {
      final r = canZimo ? selfEval(s) : null;
      if (r == null) throw GameError('现在不能自摸胡牌');
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
      if (t != hunTileId && hands[s][t] > 0) return t;
    }
    return hunTileId;
  }

  void _discard(int s, int t) {
    hands[s][t]--;
    final giri = drawn[s] == t;
    drawn[s] = -1;
    discards[s].add(_HnDiscard(t, tsumogiri: giri));
    canZimo = false;
    afterKong = false;
    lastDiscardSeat = s;
    lastAction = '${name(s)} 打出 ${tileName(t)}';
    _event('discard', s, t);

    if (t == hunTileId) {
      _coverPause(() => _draw((s + 1) % players));
      return;
    }

    final opts = <int, Set<String>>{};
    final hu = <int, HenanResult>{};
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
      claim = _HnClaim(t, s, false, opts, hu: hu);
      phase = 'claim';
    }
  }

  int _prio(String type) => switch (type) { 'ron' || 'hu' => 30, 'gang' || 'peng' => 20, _ => 0 };

  int _maxPrio(_HnClaim c, int s) {
    var best = 0;
    for (final o in c.opts[s]!) {
      final p = _prio(o);
      if (p > best) best = p;
    }
    return best;
  }

  void _handleClaim(int s, String rawType, Map<String, dynamic> a) {
    if (!allowRon && (rawType == 'ron' || rawType == 'hu')) {
      throw GameError('当前为只许自摸模式，不能点炮');
    }
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
      final pfBonus = paofen[s] + paofen[c.from];
      final amt = 2 + pfBonus;
      _pay(c.from, s, amt);
      events.add({
        'kind': 'gang',
        'from': c.from,
        'to': s,
        'base': 2,
        'paofenBonus': pfBonus,
        'amount': amt,
        'why': '点杠',
      });
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
    if (bu) {
      final opts = <int, Set<String>>{};
      final hu = <int, HenanResult>{};
      for (var o = 0; o < players; o++) {
        if (o == s) continue;
        final r = ronEval(o, t, rob: true);
        if (r != null) {
          opts[o] = {'ron'};
          hu[o] = r;
        }
      }
      if (opts.isNotEmpty) {
        claim = _HnClaim(t, s, true, opts, hu: hu);
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
      final pfBonus = paofen[s] + paofen[o];
      final amt = 2 + pfBonus;
      _pay(o, s, amt);
      events.add({
        'kind': 'gang',
        'from': o,
        'to': s,
        'base': 2,
        'paofenBonus': pfBonus,
        'amount': amt,
        'why': '暗杠',
      });
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
      final pfBonus = paofen[s] + paofen[o];
      final amt = 1 + pfBonus;
      _pay(o, s, amt);
      events.add({
        'kind': 'gang',
        'from': o,
        'to': s,
        'base': 1,
        'paofenBonus': pfBonus,
        'amount': amt,
        'why': '补杠',
      });
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

  void _settleWin(Map<int, (int, HenanResult)> wins, int from, {bool rob = false}) {
    final zimo = from < 0;
    for (final e in wins.entries) {
      final w = e.key;
      final (tile, res) = e.value;
      if (zimo && hands[w][tile] > 0) hands[w][tile]--;
      drawn[w] = -1;
      final payers = zimo ? [for (var o = 0; o < players; o++) if (o != w) o] : [from];
      final pay = <String, int>{};
      final paofenPay = <String, int>{};
      var totalWon = 0;
      for (final p in payers) {
        final baseAmt = res.fan * res.mult * (zimo ? 2 : 1);
        final pfBonus = paofen[w] + paofen[p];
        final amt = baseAmt + pfBonus;
        _pay(p, w, amt);
        pay['$p'] = amt;
        paofenPay['$p'] = pfBonus;
        totalWon += amt;
      }
      final itemsJson = res.toJson();
      if (paofen[w] > 0) {
        itemsJson.add(['赢家跑${paofen[w]}分', paofen[w]]);
      }
      events.add({
        'kind': 'hu',
        'seat': w,
        'from': from,
        'tile': tileCode(tile),
        'zimo': zimo,
        'rob': rob,
        'big': res.isBig,
        'sihun': res.isSiHun,
        'fan': res.fan,
        'mult': res.mult,
        'paofen': List.of(paofen),
        'paofenPay': paofenPay,
        'total': totalWon,
        'items': itemsJson,
        'pay': pay,
        'hand': codesOfCounts(hands[w]),
      });
      host.log(zimo
          ? '${name(w)} 自摸 ${tileName(tile)}！${res.label}（跑分+${paofen[w]}）'
          : '${name(w)} 胡 ${name(from)} 的 ${tileName(tile)}！${res.label}（跑分+${paofen[w] + paofen[from]}）');
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
      'hunIndicator': hunIndicator,
      'hunTile': hunTile,
      'paofen': List.of(paofen),
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
      final hasDrawn = (phase == 'act' || phase == 'paofen') && turn == s && drawn[s] >= 0 && hands[s][drawn[s]] > 0;
      seats.add({
        'count': n,
        'drawn': hasDrawn,
        'hand': s == seat || reveal ? codesOfCounts(hands[s]) : null,
        'melds': [for (final m in melds[s]) m.toJson(hide: m.concealed && s != seat && !reveal)],
        'paofen': paofen[s],
        'paofenDone': paofenDone.contains(s),
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
      'rule': 'henanmj',
      'phase': phase == 'pause' ? 'claim' : phase,
      'hand': handNo,
      'hands': totalRounds,
      'rounds': totalRounds,
      'dealer': dealer,
      'turn': turn,
      'wall': wall.length,
      'hunIndicator': hunIndicator,
      'hunTile': hunTile,
      'allowRon': allowRon,
      'paofen': List.of(paofen),
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
        'drawn': (phase == 'act' || phase == 'paofen') && turn == seat && drawn[seat] >= 0 && hands[seat][drawn[seat]] > 0
            ? tileCode(drawn[seat])
            : null,
        'paofen': paofen[seat],
        'canPaofen': phase == 'paofen' && !paofenDone.contains(seat),
      };
      if (phase == 'act' && turn == seat) {
        final ev = canZimo ? selfEval(seat) : null;
        my['canHu'] = ev != null;
        my['canTsumo'] = ev != null;
        my['canSiHun'] = canSiHun;
        my['kongs'] = [for (final (t, _) in selfKongs()) tileCode(t)];
        my['discardable'] = [for (final t in legalDiscards(seat)) tileCode(t)];
      }
      if (phase == 'claim' && claim!.opts.containsKey(seat) && !claim!.resp.containsKey(seat)) {
        my['claim'] = claim!.opts[seat]!.toList();
      }
      final n = countTotal(hands[seat]);
      if (n % 3 == 1 && (phase == 'act' || phase == 'claim' || phase == 'pause')) {
        my['waits'] = [
          for (final t in henanWaits(hands[seat], melds[seat], hunTile: hunTileId)) tileCode(t)
        ];
      }
      v['me'] = my;
    }
    return v;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    switch (phase) {
      case 'paofen':
        if (paofenDone.contains(seat)) return null;
        final huns = hands[seat][hunTileId];
        var pairs = 0;
        for (var t = 0; t < kKinds; t++) {
          if (t != hunTileId && hands[seat][t] >= 2) pairs++;
        }
        final sc = botLevel == 0 ? rng.nextInt(4) : (huns + (pairs >= 3 ? 1 : 0)).clamp(0, 3);
        return {'type': 'paofen', 'score': sc};
      case 'act':
        if (seat != turn) return null;
        if (canSiHun) return {'type': 'sihun'};
        if (canSelfHu) return {'type': 'tsumo'};
        final ks = selfKongs();
        if (ks.isNotEmpty) return {'type': 'gang', 'tile': tileCode(ks.first.$1)};
        final legals = legalDiscards(seat);
        final nonHun = [for (final t in legals) if (t != hunTileId) t];
        final pool = nonHun.isNotEmpty ? nonHun : legals;
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
        if (o.contains('gang')) return {'type': 'gang'};
        if (o.contains('peng') && (hands[seat][c.tile] >= 3 || rng.nextDouble() < 0.55)) {
          return {'type': 'peng'};
        }
        return {'type': 'pass'};
      case 'settle':
        return ready.contains(seat) ? null : {'type': 'next'};
    }
    return null;
  }
}
