import '../../src/engine.dart';
import 'tiles.dart';

class HefeiResult {
  final int fan;
  final int mult;
  final List<int> suitCounts; // [mCount, pCount, sCount]
  final int mainSuit;
  final int mainSuitCount;
  final bool isQueYiMen; // 缺一门 (<= 2 suits)
  final bool isBaZhi; // 够八支 (>= 8 tiles in main suit)
  final bool isShiTong; // 十同 (>= 10 tiles in one suit)
  final bool isShuangBaZhi; // 双八支 (8 tiles in one suit + 8 in another suit with quads)
  final bool isQingYiSe; // 清一色 (all tiles in one suit, >= 14 tiles)
  final bool isQiDui; // 七对
  final bool isPengPeng; // 对对胡
  final bool isBig;
  final List<(String, int)> items;

  const HefeiResult({
    required this.fan,
    required this.mult,
    required this.suitCounts,
    required this.mainSuit,
    required this.mainSuitCount,
    required this.isQueYiMen,
    required this.isBaZhi,
    required this.isShiTong,
    required this.isShuangBaZhi,
    required this.isQingYiSe,
    required this.isQiDui,
    required this.isPengPeng,
    required this.isBig,
    required this.items,
  });

  String get label => [for (final (n, _) in items) n].join(' ');
  List<List<Object>> toJson() => [for (final (n, f) in items) [n, f]];
}

/// Evaluates a Hefei Mahjong (合肥麻将) hand:
/// - 84 tiles only (2..8 of m/p/s; no terminals 1/9 and no honors 1z..7z).
/// - Strict winning prerequisites:
///   1. 缺一门: complete hand (concealed + melds) has at most 2 suits.
///   2. 够八支: at least one suit has >= 8 tiles.
HefeiResult? hefeiEvaluate(
  List<int> concealed,
  List<Meld> melds, {
  bool selfDrawn = false,
  bool gangKai = false,
  bool qiangGang = false,
}) {
  final total = countTotal(concealed);
  final needSets = 4 - melds.length;
  if (needSets < 0 || total != needSets * 3 + 2) return null;

  // Reject any non-Hefei tile (terminals 1/9 or honors 1z..7z) or any chi meld
  final suitCounts = <int>[0, 0, 0];
  for (var t = 0; t < concealed.length; t++) {
    final cnt = concealed[t];
    if (cnt <= 0) continue;
    if (!isHefeiTile(t)) return null;
    suitCounts[suitOf(t)] += cnt;
  }
  for (final m in melds) {
    if (m.isChi) return null;
    for (final t in m.tiles) {
      if (!isHefeiTile(t)) return null;
      suitCounts[suitOf(t)]++;
    }
  }

  final activeSuits = <int>[for (var s = 0; s < 3; s++) if (suitCounts[s] > 0) s];
  // 1. 缺一门: at most 2 suits out of {m, p, s}
  if (activeSuits.isEmpty || activeSuits.length > 2) return null;

  // 2. 够八支: at least one suit has >= 8 tiles
  var mainSuit = 0;
  var maxSuitCount = suitCounts[0];
  for (var s = 1; s < 3; s++) {
    if (suitCounts[s] > maxSuitCount) {
      maxSuitCount = suitCounts[s];
      mainSuit = s;
    }
  }
  if (maxSuitCount < 8) return null;

  final stdWin = isStandardWin(concealed);
  final qidui = melds.isEmpty && isSevenPairs(concealed);
  if (!stdWin && !qidui) return null;

  final pengpeng = melds.every((m) => !m.isChi) && isAllPungs(concealed);
  final qingyise = activeSuits.length == 1;
  final shitong = maxSuitCount >= 10;
  final suitsWith8 = suitCounts.where((c) => c >= 8).length;
  final shuangbazhi = suitsWith8 >= 2;

  final items = <(String, int)>[];
  var mult = 1;

  if (qingyise) {
    items.add(('清一色', 8));
    mult *= 4;
  } else if (shuangbazhi) {
    items.add(('双八支', 6));
    mult *= 2;
  } else if (shitong) {
    items.add(('十同', 4));
    mult *= 2;
  } else {
    items.add(('够八支', 2));
  }

  if (qidui) {
    items.add(('七对', 4));
    mult *= 2;
  } else if (pengpeng && stdWin) {
    items.add(('对对胡', 2));
  }
  if (gangKai) {
    items.add(('杠上开花', 2));
    mult *= 2;
  }
  if (qiangGang) {
    items.add(('抢杠胡', 2));
  }
  if (selfDrawn) {
    items.add(('自摸', 1));
  }

  final isBig = qingyise || shuangbazhi || shitong || qidui || (pengpeng && stdWin) || gangKai || qiangGang;
  final fan = items.fold<int>(0, (a, b) => a + b.$2);
  return HefeiResult(
    fan: fan,
    mult: mult,
    suitCounts: suitCounts,
    mainSuit: mainSuit,
    mainSuitCount: maxSuitCount,
    isQueYiMen: true,
    isBaZhi: true,
    isShiTong: shitong,
    isShuangBaZhi: shuangbazhi,
    isQingYiSe: qingyise,
    isQiDui: qidui,
    isPengPeng: pengpeng && stdWin,
    isBig: isBig,
    items: items,
  );
}

List<int> hefeiWaits(List<int> concealed, List<Meld> melds) {
  final out = <int>[];
  for (final t in kHefeiTileKinds) {
    concealed[t]++;
    final r = hefeiEvaluate(concealed, melds, selfDrawn: true);
    concealed[t]--;
    if (r != null) out.add(t);
  }
  return out;
}

class _HfClaim {
  final int tile;
  final int from;
  final bool rob;
  final Map<int, Set<String>> opts;
  final Map<int, HefeiResult> hu;
  final Map<int, Map<String, dynamic>> resp = {};
  _HfClaim(this.tile, this.from, this.rob, this.opts, {this.hu = const {}});
  List<int> get pending => [for (final s in opts.keys) if (!resp.containsKey(s)) s]..sort();
}

class _HfDiscard {
  final int tile;
  bool taken = false;
  final bool tsumogiri;
  _HfDiscard(this.tile, {this.tsumogiri = false});
}

/// 合肥麻将 (hefeimj)
class HefeiGame extends GameEngine {
  HefeiGame(super.setup);

  late final int totalRounds = setup.opt<int>('rounds', 4);

  late List<int> scores = List.filled(players, 0);
  int handNo = 0;
  int dealer = 0;
  bool over = false;
  List<Map<String, dynamic>> history = [];

  // Hand state
  String phase = 'act'; // act, claim, settle, over, pause
  String pausedPhase = '';
  List<List<int>> hands = [];
  List<List<Meld>> melds = [];
  List<List<_HfDiscard>> discards = [];
  List<int> drawn = [];
  List<int> wall = [];
  int turn = 0;
  bool canZimo = false;
  bool afterKong = false;
  int lastDiscardSeat = -1;
  String lastAction = '';
  Map<String, dynamic>? lastEvent;
  int eventSeq = 0;
  _HfClaim? claim;
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

  List<int> seatSuitCounts(int s) {
    final counts = <int>[0, 0, 0];
    for (final t in kHefeiTileKinds) {
      counts[suitOf(t)] += hands[s][t];
    }
    for (final m in melds[s]) {
      for (final t in m.tiles) {
        if (t >= 0 && t < kNumKinds) counts[suitOf(t)]++;
      }
    }
    return counts;
  }

  @override
  void start() {
    dealer = rng.nextInt(players);
    _startHand();
  }

  void _startHand() {
    handNo++;
    // 84 tiles: 2m..8m, 2p..8p, 2s..8s (21 kinds × 4 = 84)
    wall = <int>[for (final t in kHefeiTileKinds) for (var k = 0; k < 4; k++) t]..shuffle(rng);
    hands = List.generate(players, (_) => List.filled(kKinds, 0));
    melds = List.generate(players, (_) => <Meld>[]);
    discards = List.generate(players, (_) => <_HfDiscard>[]);
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
    host.log('第 $handNo/$totalRounds 局开始，${name(dealer)} 坐庄（84张断幺牌池 · 缺一门够八支）');
    lastAction = '84张断幺 · 缺一门够八支 · ${name(dealer)} 出牌';
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

  HefeiResult? selfEval(int s) => hefeiEvaluate(
        hands[s],
        melds[s],
        selfDrawn: true,
        gangKai: afterKong,
      );

  HefeiResult? ronEval(int o, int t, {bool rob = false}) {
    final c = List<int>.of(hands[o]);
    c[t]++;
    return hefeiEvaluate(
      c,
      melds[o],
      selfDrawn: false,
      qiangGang: rob,
    );
  }

  bool get canSelfHu => phase == 'act' && canZimo && selfEval(turn) != null;

  List<(int, bool)> selfKongs() {
    if (phase != 'act' || wall.isEmpty) return const [];
    final s = turn;
    final out = <(int, bool)>[];
    for (final t in kHefeiTileKinds) {
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
    if (type == 'chi') throw GameError('合肥麻将不能吃牌');
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
      if (r == null) throw GameError('未满足缺一门或够八支条件，不能胡牌');
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
      if (hands[s][t] > 0) return t;
    }
    return kHefeiTileKinds.first;
  }

  void _discard(int s, int t) {
    hands[s][t]--;
    final giri = drawn[s] == t;
    drawn[s] = -1;
    discards[s].add(_HfDiscard(t, tsumogiri: giri));
    canZimo = false;
    afterKong = false;
    lastDiscardSeat = s;
    lastAction = '${name(s)} 打出 ${tileName(t)}';
    _event('discard', s, t);

    // Hefei Mahjong: Peng, Gang, Ron allowed; NO Chi!
    final opts = <int, Set<String>>{};
    final hu = <int, HefeiResult>{};
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
      claim = _HfClaim(t, s, false, opts, hu: hu);
      phase = 'claim';
    }
  }

  int _prio(String type) => switch (type) { 'ron' || 'hu' => 30, 'gang' || 'peng' => 20, _ => 0 };

  int _maxPrio(_HfClaim c, int s) {
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
      _pay(c.from, s, 2);
      events.add({'kind': 'gang', 'from': c.from, 'to': s, 'amount': 2, 'why': '明杠'});
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
      final hu = <int, HefeiResult>{};
      for (var o = 0; o < players; o++) {
        if (o == s) continue;
        final r = ronEval(o, t, rob: true);
        if (r != null) {
          opts[o] = {'ron'};
          hu[o] = r;
        }
      }
      if (opts.isNotEmpty) {
        claim = _HfClaim(t, s, true, opts, hu: hu);
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
    _event('gang', s);
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

  void _settleWin(Map<int, (int, HefeiResult)> wins, int from, {bool rob = false}) {
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
        'shitong': res.isShiTong,
        'shuangbazhi': res.isShuangBaZhi,
        'qingyise': res.isQingYiSe,
        'qidui': res.isQiDui,
        'suitCounts': res.suitCounts,
        'mainSuit': suitNames[res.mainSuit],
        'mainSuitCount': res.mainSuitCount,
        'fan': res.fan,
        'mult': res.mult,
        'total': totalWon,
        'items': res.toJson(),
        'pay': pay,
        'hand': codesOfCounts(hands[w]),
      });
      host.log(zimo
          ? '${name(w)} 自摸 ${tileName(tile)}！${res.label}（${suitNames[res.mainSuit]}${res.mainSuitCount}支）'
          : '${name(w)} 胡 ${name(from)} 的 ${tileName(tile)}！${res.label}（${suitNames[res.mainSuit]}${res.mainSuitCount}支）');
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
      final sc = seatSuitCounts(s);
      seats.add({
        'count': n,
        'drawn': hasDrawn,
        'hand': s == seat || reveal ? codesOfCounts(hands[s]) : null,
        'melds': [for (final m in melds[s]) m.toJson(hide: m.concealed && s != seat && !reveal)],
        'suitCounts': s == seat || reveal ? sc : null,
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
      'rule': 'hefeimj',
      'phase': phase == 'pause' ? 'claim' : phase,
      'hand': handNo,
      'hands': totalRounds,
      'rounds': totalRounds,
      'dealer': dealer,
      'turn': turn,
      'wall': wall.length,
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
      final sc = seatSuitCounts(seat);
      final activeSuits = [for (var i = 0; i < 3; i++) if (sc[i] > 0) i];
      final maxCnt = [sc[0], sc[1], sc[2]].reduce((a, b) => a > b ? a : b);
      final my = <String, dynamic>{
        'drawn': phase == 'act' && turn == seat && drawn[seat] >= 0 && hands[seat][drawn[seat]] > 0
            ? tileCode(drawn[seat])
            : null,
        'suitCounts': sc,
        'queYiMenOk': activeSuits.length <= 2,
        'baZhiOk': maxCnt >= 8,
      };
      if (phase == 'act' && turn == seat) {
        final ev = canZimo ? selfEval(seat) : null;
        my['canHu'] = ev != null;
        my['canTsumo'] = ev != null;
        my['kongs'] = [for (final (t, _) in selfKongs()) tileCode(t)];
        my['discardable'] = [for (final t in legalDiscards(seat)) tileCode(t)];
      }
      if (phase == 'claim' && claim!.opts.containsKey(seat) && !claim!.resp.containsKey(seat)) {
        my['claim'] = claim!.opts[seat]!.toList();
      }
      final n = countTotal(hands[seat]);
      if (n % 3 == 1 && (phase == 'act' || phase == 'claim' || phase == 'pause')) {
        my['waits'] = [for (final t in hefeiWaits(hands[seat], melds[seat])) tileCode(t)];
      }
      v['me'] = my;
    }
    return v;
  }

  /// Determines which suit [seat] should drop to satisfy 缺一门 and which suit is the main suit (>= 8 tiles).
  (int dropSuit, int mainSuit) _suitPlan(int seat) {
    final sc = seatSuitCounts(seat);
    final lockedSuits = <int>{
      for (final m in melds[seat])
        for (final t in m.tiles) suitOf(t),
    };
    var dropSuit = 0;
    var minScore = 999999;
    for (var s = 0; s < 3; s++) {
      final penalty = lockedSuits.contains(s) ? 1000 : 0;
      final score = sc[s] + penalty;
      if (score < minScore) {
        minScore = score;
        dropSuit = s;
      }
    }
    var mainSuit = (dropSuit + 1) % 3;
    var bestMain = -1;
    for (var s = 0; s < 3; s++) {
      if (s == dropSuit) continue;
      if (sc[s] > bestMain) {
        bestMain = sc[s];
        mainSuit = s;
      }
    }
    return (dropSuit, mainSuit);
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
        final (dropSuit, mainSuit) = _suitPlan(seat);
        final tileSuit = suitOf(c.tile);
        if (tileSuit != dropSuit) {
          if (opts.contains('gang')) return {'type': 'gang'};
          if (opts.contains('peng') && (tileSuit == mainSuit || hands[seat][c.tile] == 2)) {
            return {'type': 'peng'};
          }
        }
        return {'type': 'pass'};
      case 'act':
        if (seat != turn) return null;
        if (canSelfHu) return {'type': 'tsumo'};
        final (dropSuit, mainSuit) = _suitPlan(seat);
        final ks = selfKongs().where((e) => suitOf(e.$1) != dropSuit).toList();
        if (ks.isNotEmpty) {
          return {'type': 'gang', 'tile': tileCode(ks.first.$1)};
        }
        final ds = legalDiscards(seat);
        // Priority 1: discard any tile in dropSuit to satisfy 缺一门
        final dropTiles = ds.where((t) => suitOf(t) == dropSuit).toList();
        final pool = dropTiles.isNotEmpty ? dropTiles : ds;
        final sc = seatSuitCounts(seat);
        var best = pool.first;
        var bestVal = 999999;
        for (final t in pool) {
          var v = tileValue(hands[seat], t);
          // Protect mainSuit tiles until we have at least 8 (够八支)
          if (suitOf(t) == mainSuit && sc[mainSuit] <= 8) {
            v += 12;
          } else if (suitOf(t) == mainSuit) {
            v += 4;
          }
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
