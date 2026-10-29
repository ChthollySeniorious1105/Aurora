import '../../src/engine.dart';
import 'tiles.dart';

/// Next tile in cyclic rank order (1->2->...->9->1 of same suit) for Guizhou Mahjong chicken indicator.
int guizhouNextChicken(int indicator) {
  if (indicator >= 0 && indicator < kNumKinds) {
    final s = indicator ~/ 9;
    final r = indicator % 9;
    return s * 9 + (r + 1) % 9;
  }
  return kYaoji;
}

String guizhouChickenFromCode(String indicatorCode) =>
    tileCode(guizhouNextChicken(tileFromCode(indicatorCode)));

class GuizhouResult {
  final int points;
  final bool isBig;
  final List<(String, int)> items;
  const GuizhouResult(this.points, this.isBig, this.items);

  String get label => [for (final (n, _) in items) n].join(' ');
  List<List<Object>> toJson() => [for (final (n, p) in items) [n, p]];
}

/// Evaluates a Guizhou Zhuoji Mahjong hand (108 number tiles 0..26).
/// Pass Rule (通行证规则): a player can win by discard ([selfDrawn] == false) ONLY if
/// they have at least 1 Bean ([beans] > 0) OR have a Big Hand (大对子, 七对, 清一色, 单钓, 抢杠胡).
/// Self-draw ([selfDrawn] == true) always wins!
GuizhouResult? guizhouEvaluate(
  List<int> concealed,
  List<Meld> melds, {
  int beans = 0,
  bool selfDrawn = false,
  bool gangKai = false,
  bool qiangGang = false,
}) {
  final total = countTotal(concealed);
  final needSets = 4 - melds.length;
  if (needSets < 0 || total != needSets * 3 + 2) return null;

  final qidui = melds.isEmpty && isSevenPairs(concealed);
  final daduizi = melds.every((m) => !m.isChi) && isAllPungs(concealed);
  final std = qidui || daduizi || isStandardWin(concealed);
  if (!std) return null;

  final suits = <int>{};
  for (var t = 0; t < concealed.length && t < kNumKinds; t++) {
    if (concealed[t] > 0) suits.add(t ~/ 9);
  }
  for (final m in melds) {
    for (final t in m.tiles) {
      if (t < kNumKinds) suits.add(t ~/ 9);
    }
  }
  final qingyise = suits.length == 1;
  final dandiao = melds.length == 4 && total == 2;

  final bigItems = <(String, int)>[];
  if (qingyise) bigItems.add(('清一色', 10));
  if (qidui) {
    final longQidui = concealed.any((x) => x == 4);
    bigItems.add(longQidui ? ('龙七对', 20) : ('七对', 10));
  }
  if (daduizi && !qidui) bigItems.add(('大对子', 5));
  if (dandiao) bigItems.add(('单钓', 5));
  if (gangKai) bigItems.add(('杠上开花', 5));
  if (qiangGang) bigItems.add(('抢杠胡', 5));

  final isBig = bigItems.isNotEmpty;
  if (!selfDrawn && !isBig && beans <= 0) {
    // 通行证规则: cannot Ron a small hand without a Gang Bean
    return null;
  }

  final items = <(String, int)>[...bigItems];
  if (items.isEmpty) {
    items.add(('平胡', 1));
  }
  if (selfDrawn) {
    items.add(('自摸', 1));
  }
  final pts = items.fold<int>(0, (a, b) => a + b.$2);
  return GuizhouResult(pts, isBig, items);
}

List<int> guizhouWaits(
  List<int> concealed,
  List<Meld> melds, {
  int beans = 0,
  bool selfDrawn = true,
}) {
  final out = <int>[];
  for (var t = 0; t < kNumKinds && t < concealed.length; t++) {
    concealed[t]++;
    final r = guizhouEvaluate(concealed, melds, beans: beans, selfDrawn: selfDrawn);
    concealed[t]--;
    if (r != null) out.add(t);
  }
  return out;
}

bool guizhouIsTing(List<int> concealed, List<Meld> melds) =>
    guizhouWaits(concealed, melds, beans: 1, selfDrawn: true).isNotEmpty;

class _GzClaim {
  final int tile;
  final int from;
  final bool rob;
  final bool firstYaoji;
  final Map<int, Set<String>> opts;
  final Map<int, GuizhouResult> hu;
  final Map<int, Map<String, dynamic>> resp = {};
  _GzClaim(
    this.tile,
    this.from,
    this.rob,
    this.opts, {
    this.firstYaoji = false,
    this.hu = const {},
  });
  List<int> get pending => [for (final s in opts.keys) if (!resp.containsKey(s)) s]..sort();
}

class _GzDiscard {
  final int tile;
  bool taken = false;
  final bool tsumogiri;
  bool chongfeng;
  _GzDiscard(this.tile, {this.tsumogiri = false, this.chongfeng = false});
}

/// 贵阳捉鸡麻将 (guizhoumj)
class GuizhouGame extends GameEngine {
  GuizhouGame(super.setup);

  late final int totalRounds = setup.opt<int>('rounds', 4);
  late final bool goldenChickenOn = setup.opt<bool>('goldenChicken', true);

  late List<int> scores = List.filled(players, 0);
  int handNo = 0;
  int dealer = 0;
  bool over = false;
  List<Map<String, dynamic>> history = [];

  // Guizhou-specific state
  List<int> beans = [0, 0, 0, 0];
  bool firstYaojiSeen = false;
  int chongfengSeat = -1;
  int zerenFrom = -1;
  int zerenTo = -1;
  int chickenIndicatorId = -1;
  int luckyChickenId = -1;
  List<int> chickenPoints = [0, 0, 0, 0];

  String? get chickenIndicator => chickenIndicatorId >= 0 ? tileCode(chickenIndicatorId) : null;
  String? get luckyChicken => luckyChickenId >= 0 ? tileCode(luckyChickenId) : null;
  bool get isGoldenChicken => goldenChickenOn && luckyChickenId == kYaoji;

  // Hand state
  String phase = 'act'; // act, claim, settle, over, pause
  String pausedPhase = '';
  List<List<int>> hands = [];
  List<List<Meld>> melds = [];
  List<List<_GzDiscard>> discards = [];
  List<int> drawn = [];
  List<int> wall = [];
  int turn = 0;
  bool canZimo = false;
  bool afterKong = false;
  int lastDiscardSeat = -1;
  String lastAction = '';
  Map<String, dynamic>? lastEvent;
  int eventSeq = 0;
  _GzClaim? claim;
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
    wall = <int>[for (var t = 0; t < kNumKinds; t++) for (var k = 0; k < 4; k++) t]..shuffle(rng);
    hands = List.generate(players, (_) => List.filled(kNumKinds, 0));
    melds = List.generate(players, (_) => <Meld>[]);
    discards = List.generate(players, (_) => <_GzDiscard>[]);
    beans = List.filled(players, 0);
    firstYaojiSeen = false;
    chongfengSeat = -1;
    zerenFrom = -1;
    zerenTo = -1;
    chickenIndicatorId = -1;
    luckyChickenId = -1;
    chickenPoints = List.filled(players, 0);
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
    host.log('第 $handNo/$totalRounds 局开始，${name(dealer)} 坐庄（贵阳捉鸡）');
    lastAction = '第 $handNo 局 · ${name(dealer)} 出牌';
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

  GuizhouResult? selfEval(int s) => guizhouEvaluate(
        hands[s],
        melds[s],
        beans: beans[s],
        selfDrawn: true,
        gangKai: afterKong,
      );

  GuizhouResult? ronEval(int o, int t, {bool rob = false}) {
    if (t < 0 || t >= kNumKinds) return null;
    final c = List<int>.of(hands[o]);
    c[t]++;
    return guizhouEvaluate(
      c,
      melds[o],
      beans: beans[o],
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
    for (var t = 0; t < kNumKinds; t++) {
      if (hands[s][t] == 4) out.add((t, false));
      if (hands[s][t] >= 1 && melds[s].any((m) => m.isPeng && m.tile == t)) out.add((t, true));
    }
    return out;
  }

  List<int> legalDiscards(int s) => [for (var t = 0; t < kNumKinds; t++) if (hands[s][t] > 0) t];

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
      if (r == null) throw GameError('现在不能胡牌');
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
      if (t < 0 || t >= kNumKinds || hands[s][t] <= 0) throw GameError('你没有这张牌');
      _discard(s, t);
      return;
    }
    throw GameError('请出牌');
  }

  int _anyTile(int s) {
    for (var t = kNumKinds - 1; t >= 0; t--) {
      if (hands[s][t] > 0) return t;
    }
    return 0;
  }

  void _discard(int s, int t) {
    hands[s][t]--;
    final giri = drawn[s] == t;
    drawn[s] = -1;
    final isFirstYaoji = t == kYaoji && !firstYaojiSeen;
    if (isFirstYaoji) {
      firstYaojiSeen = true;
      chongfengSeat = s;
    }
    discards[s].add(_GzDiscard(t, tsumogiri: giri, chongfeng: isFirstYaoji));
    canZimo = false;
    afterKong = false;
    lastDiscardSeat = s;
    lastAction = isFirstYaoji ? '${name(s)} 打出冲锋鸡（幺鸡）！' : '${name(s)} 打出 ${tileName(t)}';
    if (isFirstYaoji) host.log('${name(s)} 打出全场首张幺鸡（冲锋鸡）！');
    _event('discard', s, t);

    final opts = <int, Set<String>>{};
    final hu = <int, GuizhouResult>{};
    for (var o = 0; o < players; o++) {
      if (o == s) continue;
      final set = <String>{};
      final r = ronEval(o, t);
      if (r != null) {
        set.add('hu');
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
      claim = _GzClaim(t, s, false, opts, firstYaoji: isFirstYaoji, hu: hu);
      phase = 'claim';
    }
  }

  int _prio(String type) => switch (type) { 'hu' => 30, 'gang' || 'peng' => 20, _ => 0 };

  int _maxPrio(_GzClaim c, int s) {
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
    c.resp[s] = {'type': type};
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
    final lastD = discards[c.from].last;
    lastD.taken = true;

    // 责任鸡: if the very first '1s' is claimed for Pung/Gang, discarder pays +2 to claimer!
    if (c.firstYaoji && (type == 'peng' || type == 'gang')) {
      chongfengSeat = -1;
      lastD.chongfeng = false;
      zerenFrom = c.from;
      zerenTo = s;
      _pay(c.from, s, 2);
      events.add({
        'kind': 'zerenji',
        'why': '责任鸡',
        'from': c.from,
        'to': s,
        'amount': 2,
      });
      host.log('${name(s)} 碰/杠了 ${name(c.from)} 的首张幺鸡，触发【责任鸡】（${name(c.from)} 赔 2 分）！');
    }

    if (type == 'gang') {
      hands[s][c.tile] -= 3;
      melds[s].add(Meld('mgang', c.tile, claimed: c.tile, from: c.from));
      // 点豆: +1 pt from discarder
      beans[s]++;
      _pay(c.from, s, 1);
      events.add({
        'kind': 'bean',
        'why': '点豆',
        'from': c.from,
        'to': s,
        'amount': 1,
      });
      lastAction = '${name(s)} 点豆（明杠 ${tileName(c.tile)}，+1豆）';
      host.log(lastAction);
      _event('gang', s, c.tile);
      _draw(s, kong: true);
      return;
    }

    // Peng
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
      final hu = <int, GuizhouResult>{};
      for (var o = 0; o < players; o++) {
        if (o == s) continue;
        final r = ronEval(o, t, rob: true);
        if (r != null) {
          opts[o] = {'hu'};
          hu[o] = r;
        }
      }
      if (opts.isNotEmpty) {
        claim = _GzClaim(t, s, true, opts, hu: hu);
        phase = 'claim';
        lastAction = '${name(s)} 转弯豆（补杠 ${tileName(t)}）';
        _event('bugang', s, t);
        return;
      }
      _finishBuGang(s, t);
      return;
    }
    hands[s][t] -= 4;
    melds[s].add(Meld('agang', t));
    // 闷豆: +2 pts from all 3 opponents
    beans[s]++;
    for (var o = 0; o < players; o++) {
      if (o == s) continue;
      _pay(o, s, 2);
      events.add({
        'kind': 'bean',
        'why': '闷豆',
        'from': o,
        'to': s,
        'amount': 2,
      });
    }
    lastAction = '${name(s)} 闷豆（暗杠 ${tileName(t)}，+1豆）';
    host.log(lastAction);
    _event('gang', s);
    _draw(s, kong: true);
  }

  void _finishBuGang(int s, int t) {
    hands[s][t]--;
    final m = melds[s].firstWhere((m) => m.isPeng && m.tile == t);
    m.kind = 'bgang';
    // 转弯豆: +1 pt from all 3 opponents
    beans[s]++;
    for (var o = 0; o < players; o++) {
      if (o == s) continue;
      _pay(o, s, 1);
      events.add({
        'kind': 'bean',
        'why': '转弯豆',
        'from': o,
        'to': s,
        'amount': 1,
      });
    }
    lastAction = '${name(s)} 转弯豆（补杠 ${tileName(t)}，+1豆）';
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

  /// Counts total chicken points held by [s] across hand (+ [extraTile]), melds, and non-taken discards.
  int _countSeatChickens(int s, {int extraTile = -1}) {
    var yaojiCnt = hands[s][kYaoji] + (extraTile == kYaoji ? 1 : 0);
    var luckyCnt = (luckyChickenId >= 0 && luckyChickenId != kYaoji)
        ? hands[s][luckyChickenId] + (extraTile == luckyChickenId ? 1 : 0)
        : 0;
    for (final m in melds[s]) {
      for (final t in m.tiles) {
        if (t == kYaoji) yaojiCnt++;
        if (luckyChickenId >= 0 && luckyChickenId != kYaoji && t == luckyChickenId) luckyCnt++;
      }
    }
    for (final d in discards[s]) {
      if (d.taken) continue;
      if (d.tile == kYaoji) yaojiCnt++;
      if (luckyChickenId >= 0 && luckyChickenId != kYaoji && d.tile == luckyChickenId) luckyCnt++;
    }
    final yaojiVal = isGoldenChicken ? 2 : 1;
    var pts = yaojiCnt * yaojiVal + luckyCnt;
    if (chongfengSeat == s) {
      pts += isGoldenChicken ? 4 : 2;
    }
    return pts;
  }

  void _settleWin(Map<int, (int, GuizhouResult)> wins, int from, {bool rob = false}) {
    final zimo = from < 0;
    // Flip 1 tile from the wall as chickenIndicator -> luckyChicken
    chickenIndicatorId = wall.isNotEmpty ? wall.removeLast() : tileFromCode('9s');
    luckyChickenId = guizhouNextChicken(chickenIndicatorId);

    // Compute chicken points for all Winning or Ting players
    for (var s = 0; s < players; s++) {
      final won = wins.containsKey(s);
      final ting = won || guizhouIsTing(hands[s], melds[s]);
      if (ting) {
        final winExtra = (!zimo && won) ? wins[s]!.$1 : -1;
        chickenPoints[s] = _countSeatChickens(s, extraTile: winExtra);
      } else if (chongfengSeat == s) {
        // Ensure chongfengSeat gets their +2冲锋鸡 bonus when a hand is won
        chickenPoints[s] = isGoldenChicken ? 4 : 2;
      }
    }

    // Pay Chongfeng Chicken bonus if chongfengSeat is not one of the winners (winners collect it in their win loop)
    if (chongfengSeat >= 0 && !wins.containsKey(chongfengSeat)) {
      final cfBonus = isGoldenChicken ? 4 : 2;
      for (var o = 0; o < players; o++) {
        if (o == chongfengSeat) continue;
        _pay(o, chongfengSeat, cfBonus);
      }
      events.add({
        'kind': 'chongfengji',
        'why': isGoldenChicken ? '金冲锋鸡' : '冲锋鸡',
        'from': (chongfengSeat + 1) % players,
        'to': chongfengSeat,
        'amount': cfBonus * (players - 1),
      });
    }

    for (final e in wins.entries) {
      final w = e.key;
      final (tile, res) = e.value;
      if (zimo) hands[w][tile]--;
      drawn[w] = -1;
      final cPts = chickenPoints[w];
      final items = List<(String, int)>.of(res.items);
      if (cPts > 0) {
        items.add((isGoldenChicken ? '金鸡加成' : '捉鸡加成', cPts));
      }
      final payers = zimo ? [for (var o = 0; o < players; o++) if (o != w) o] : [from];
      final pay = <String, int>{};
      var totalWon = 0;
      for (final p in payers) {
        final amt = res.points + cPts;
        _pay(p, w, amt);
        pay['$p'] = amt;
        totalWon += amt;
      }
      // On Ron, if winner also has冲锋鸡 or chicken bonus, collect chicken bonus from other 2 opponents too
      if (!zimo && cPts > 0) {
        for (var o = 0; o < players; o++) {
          if (o == w || o == from) continue;
          _pay(o, w, cPts);
          pay['$o'] = cPts;
          totalWon += cPts;
        }
      }
      events.add({
        'kind': 'hu',
        'seat': w,
        'from': from,
        'tile': tileCode(tile),
        'zimo': zimo,
        'rob': rob,
        'big': res.isBig,
        'fan': res.points + cPts,
        'total': totalWon,
        'items': [for (final (n, p) in items) [n, p]],
        'pay': pay,
        'hand': codesOfCounts(hands[w]),
      });
      host.log(zimo
          ? '${name(w)} 自摸 ${tileName(tile)}！${res.label}，翻出 ${tileName(chickenIndicatorId)} → 鸡牌 ${tileName(luckyChickenId)}${isGoldenChicken ? '（金鸡）' : ''}'
          : '${name(w)} 胡 ${name(from)} 的 ${tileName(tile)}！${res.label}，翻出 ${tileName(chickenIndicatorId)} → 鸡牌 ${tileName(luckyChickenId)}${isGoldenChicken ? '（金鸡）' : ''}');
      _event(zimo ? 'zimo' : 'hu', w, tile);
    }
    lastAction = zimo ? '${name(wins.keys.first)} 自摸' : '${wins.keys.map(name).join('、')} 胡牌';
    nextDealer = wins.length == 1 ? wins.keys.first : from;
    _endHand();
  }

  void _drawnGame() {
    // At wall exhaustion, check Ting (查叫) and settle Chongfeng Chicken if Ting
    final ting = [for (var s = 0; s < players; s++) guizhouIsTing(hands[s], melds[s])];
    if (chongfengSeat >= 0 && ting[chongfengSeat]) {
      for (var o = 0; o < players; o++) {
        if (o == chongfengSeat) continue;
        _pay(o, chongfengSeat, 2);
      }
    }
    for (var s = 0; s < players; s++) {
      if (!ting[s]) continue;
      for (var o = 0; o < players; o++) {
        if (ting[o]) continue;
        _pay(o, s, 2);
        events.add({'kind': 'chajiao', 'why': '查叫', 'from': o, 'to': s, 'amount': 2});
      }
    }
    host.log('牌山摸完，流局查叫');
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
      'chickenIndicator': chickenIndicator,
      'luckyChicken': luckyChicken,
      'goldenChicken': isGoldenChicken,
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
        'beans': beans[s],
        'chongfeng': chongfengSeat == s,
        'chickenPts': chickenPoints[s],
        'discards': [
          for (final d in discards[s])
            {'t': tileCode(d.tile), 'taken': d.taken, 'tg': d.tsumogiri, 'cf': d.chongfeng}
        ],
        'wind': seatWind(s),
        'score': scores[s],
        'delta': handDelta[s],
      });
    }
    final v = <String, dynamic>{
      'rule': 'guizhoumj',
      'phase': phase == 'pause' ? 'claim' : phase,
      'hand': handNo,
      'hands': totalRounds,
      'rounds': totalRounds,
      'dealer': dealer,
      'turn': turn,
      'wall': wall.length,
      'beans': List.of(beans),
      'chongfengSeat': chongfengSeat,
      'zerenFrom': zerenFrom,
      'zerenTo': zerenTo,
      'chickenIndicator': chickenIndicator,
      'luckyChicken': luckyChicken,
      'goldenChicken': isGoldenChicken,
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
        my['kongs'] = [for (final (t, _) in selfKongs()) tileCode(t)];
        my['discardable'] = [for (final t in legalDiscards(seat)) tileCode(t)];
      }
      if (phase == 'claim' && claim!.opts.containsKey(seat) && !claim!.resp.containsKey(seat)) {
        my['claim'] = claim!.opts[seat]!.toList();
      }
      final n = countTotal(hands[seat]);
      if (n % 3 == 1 && (phase == 'act' || phase == 'claim' || phase == 'pause')) {
        my['waits'] = [
          for (final t in guizhouWaits(hands[seat], melds[seat], beans: beans[seat], selfDrawn: true)) tileCode(t)
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
        return {'type': 'pass'};
      case 'act':
        if (seat != turn) return null;
        if (canSelfHu) return {'type': 'hu'};
        final ks = selfKongs();
        if (ks.isNotEmpty) {
          return {'type': 'gang', 'tile': tileCode(ks.first.$1)};
        }
        final disc = legalDiscards(seat);
        if (botLevel == 0) {
          return {'type': 'discard', 'tile': tileCode(disc[rng.nextInt(disc.length)])};
        }
        // If first '1s' hasn't been discarded yet and we hold a single '1s', discard it for 冲锋鸡!
        if (!firstYaojiSeen && hands[seat][kYaoji] == 1) {
          return {'type': 'discard', 'tile': '1s'};
        }
        var bestT = disc.first;
        var bestScore = 1 << 20;
        for (final t in disc) {
          var v = tileValue(hands[seat], t);
          if (t == kYaoji && hands[seat][t] >= 2) v += 5;
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
