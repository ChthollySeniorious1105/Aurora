import '../../src/engine.dart';
import 'tiles.dart';

class GuangxiResult {
  final int baseFan;
  final int fan;
  final int mult;
  final int matchedHorses;
  final List<String> horseTiles;
  final List<String> matchedHorseTiles;
  final bool isQiDui; // 七对 ×2
  final bool isPengPeng; // 碰碰胡 ×2
  final bool isHunYiSe; // 混一色 ×2
  final bool isQingYiSe; // 清一色 ×4
  final bool isBig;
  final List<(String, int)> items;

  const GuangxiResult({
    required this.baseFan,
    required this.fan,
    required this.mult,
    required this.matchedHorses,
    required this.horseTiles,
    required this.matchedHorseTiles,
    required this.isQiDui,
    required this.isPengPeng,
    required this.isHunYiSe,
    required this.isQingYiSe,
    required this.isBig,
    required this.items,
  });

  String get label => [for (final (n, _) in items) n].join(' ');
  List<List<Object>> toJson() => [for (final (n, f) in items) [n, f]];
}

/// Evaluates a Guangxi Maima Mahjong (广西买马麻将) hand (136 tiles):
/// - Standard 4 sets + 1 pair or seven pairs (`七对`).
/// - Horse tiles (`horseTiles`) matching `winnerWind` (`0=East: 1,5,9,1z,5z`;
///   `1=South: 2,6,2z,6z`; `2=West: 3,7,3z,7z`; `3=North: 4,8,4z`) count as
///   **中马 (`matchedHorses`)**, adding `+1 × baseFan` per matched horse (`fan = baseFan * (1 + matchedHorses)`).
GuangxiResult? guangxiEvaluate(
  List<int> concealed,
  List<Meld> melds, {
  Iterable<Object?> horseTiles = const [],
  int winnerWind = 0,
  bool selfDrawn = false,
  bool gangKai = false,
  bool qiangGang = false,
}) {
  final total = countTotal(concealed);
  final needSets = 4 - melds.length;
  if (needSets < 0 || total != needSets * 3 + 2) return null;

  final qidui = melds.isEmpty && isSevenPairs(concealed);
  final stdWin = isStandardWin(concealed);
  if (!stdWin && !qidui) return null;

  final pengpeng = stdWin && melds.every((m) => !m.isChi) && isAllPungs(concealed);

  final suits = <int>{};
  var hasHonor = false;
  for (var t = 0; t < concealed.length; t++) {
    if (concealed[t] <= 0) continue;
    if (t < kNumKinds) {
      suits.add(t ~/ 9);
    } else {
      hasHonor = true;
    }
  }
  for (final m in melds) {
    for (final t in m.tiles) {
      if (t < kNumKinds) {
        suits.add(t ~/ 9);
      } else {
        hasHonor = true;
      }
    }
  }

  final qingyise = !hasHonor && suits.length == 1;
  final hunyise = hasHonor && suits.length == 1;

  final items = <(String, int)>[];
  var mult = 1;

  if (qingyise) {
    items.add(('清一色', 4));
    mult *= 4;
  } else if (hunyise) {
    items.add(('混一色', 2));
    mult *= 2;
  }
  if (qidui) {
    items.add(('七对', 2));
    mult *= 2;
  } else if (pengpeng) {
    items.add(('碰碰胡', 2));
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

  final isBig = qingyise || hunyise || qidui || pengpeng || gangKai || qiangGang;
  if (!isBig) {
    items.add(('平胡', 1));
  }
  if (selfDrawn) {
    items.add(('自摸', 1));
  }

  final baseFan = items.fold<int>(0, (a, b) => a + b.$2);
  final hCodes = <String>[];
  final mCodes = <String>[];
  for (final ht in horseTiles) {
    final id = tileFromCode(ht);
    if (id < 0) continue;
    final cd = tileCode(id);
    hCodes.add(cd);
    if (isHorseMatch(id, winnerWind)) {
      mCodes.add(cd);
    }
  }
  final matched = mCodes.length;
  final horseBonus = matched * baseFan;
  if (matched > 0) {
    items.add(('中马×$matched', horseBonus));
  }
  final totalFan = baseFan + horseBonus;

  return GuangxiResult(
    baseFan: baseFan,
    fan: totalFan,
    mult: mult,
    matchedHorses: matched,
    horseTiles: hCodes,
    matchedHorseTiles: mCodes,
    isQiDui: qidui,
    isPengPeng: pengpeng,
    isHunYiSe: hunyise,
    isQingYiSe: qingyise,
    isBig: isBig,
    items: items,
  );
}

List<int> guangxiWaits(List<int> concealed, List<Meld> melds) {
  final out = <int>[];
  for (var t = 0; t < kKinds && t < concealed.length; t++) {
    concealed[t]++;
    final r = guangxiEvaluate(concealed, melds, selfDrawn: true);
    concealed[t]--;
    if (r != null) out.add(t);
  }
  return out;
}

class _GxClaim {
  final int tile;
  final int from;
  final bool rob;
  final Map<int, Set<String>> opts;
  final Map<int, List<int>> chis;
  final Map<int, GuangxiResult> hu;
  final Map<int, Map<String, dynamic>> resp = {};
  _GxClaim(this.tile, this.from, this.rob, this.opts, {this.chis = const {}, this.hu = const {}});
  List<int> get pending => [for (final s in opts.keys) if (!resp.containsKey(s)) s]..sort();
}

class _GxDiscard {
  final int tile;
  bool taken = false;
  final bool tsumogiri;
  _GxDiscard(this.tile, {this.tsumogiri = false});
}

/// 广西买马麻将 (guangximj)
class GuangxiGame extends GameEngine {
  GuangxiGame(super.setup);

  late final int totalRounds = setup.opt<int>('rounds', 4);
  late final int horseCount = setup.opt<int>('horseCount', 4);

  late List<int> scores = List.filled(players, 0);
  int handNo = 0;
  int dealer = 0;
  bool over = false;
  List<Map<String, dynamic>> history = [];

  /// 三口承包追踪：`feedCount[seat][from]` 记录 `seat` 吃/碰/明杠 `from` 的副露次数。
  /// 当 `feedCount[seat][from] >= 3` 时，`seat` 与 `from` 进入双向【三口承包（封胡）】关系：
  /// 任意一方自摸胡牌，另一方承包全部 3 家的输分（×3）！
  late List<List<int>> feedCount = List.generate(players, (_) => List.filled(players, 0));

  /// 本局胡牌翻出的买马牌与中马数
  List<String> horseTiles = [];
  int matchedHorses = 0;

  // Hand state
  String phase = 'act'; // act, claim, settle, over, pause
  String pausedPhase = '';
  List<List<int>> hands = [];
  List<List<Meld>> melds = [];
  List<List<_GxDiscard>> discards = [];
  List<int> drawn = [];
  List<int> wall = [];
  int turn = 0;
  bool canZimo = false;
  bool afterKong = false;
  int lastDiscardSeat = -1;
  String lastAction = '';
  Map<String, dynamic>? lastEvent;
  int eventSeq = 0;
  _GxClaim? claim;
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

  /// Number of exposed melds [seat] has claimed from [from].
  int feedsFrom(int seat, int from) {
    if (seat < 0 || seat >= players || from < 0 || from >= players || seat == from) return 0;
    final byMelds = melds[seat].where((m) => m.isExposed && m.from == from).length;
    return feedCount[seat][from] >= byMelds ? feedCount[seat][from] : byMelds;
  }

  /// True if [a] and [b] are in a bidirectional 三口承包 (Three-Call Liability) relationship.
  bool isChengbaoPair(int a, int b) => a != b && (feedsFrom(a, b) >= 3 || feedsFrom(b, a) >= 3);

  /// All seats that have a 三口承包 relationship with [seat].
  List<int> chengbaoPartners(int seat) => [
        for (var o = 0; o < players; o++)
          if (isChengbaoPair(seat, o)) o
      ];

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
    discards = List.generate(players, (_) => <_GxDiscard>[]);
    feedCount = List.generate(players, (_) => List.filled(players, 0));
    horseTiles = [];
    matchedHorses = 0;
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
    host.log('第 $handNo/$totalRounds 局开始，${name(dealer)} 坐庄（三口承包 · 买 $horseCount 匹马）');
    lastAction = '买${horseCount}马 · 三口承包 · ${name(dealer)} 出牌';
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

  GuangxiResult? selfEval(int s, {Iterable<Object?> horses = const []}) => guangxiEvaluate(
        hands[s],
        melds[s],
        horseTiles: horses,
        winnerWind: seatWind(s),
        selfDrawn: true,
        gangKai: afterKong,
      );

  GuangxiResult? ronEval(int o, int t, {bool rob = false, Iterable<Object?> horses = const []}) {
    final c = List<int>.of(hands[o]);
    c[t]++;
    return guangxiEvaluate(
      c,
      melds[o],
      horseTiles: horses,
      winnerWind: seatWind(o),
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
      if (hands[s][t] == 4) out.add((t, false));
      if (hands[s][t] >= 1 && melds[s].any((m) => m.isPeng && m.tile == t)) out.add((t, true));
    }
    return out;
  }

  List<int> chiOptions(int s, int t) {
    if (t >= kNumKinds) return const [];
    final h = hands[s];
    final r = rankOf(t);
    final out = <int>[];
    for (var lo = t - 2; lo <= t; lo++) {
      final lr = r - (t - lo);
      if (lr < 1 || lr > 7) continue;
      var ok = true;
      for (var k = lo; k < lo + 3; k++) {
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
      if (hands[s][t] > 0) return t;
    }
    return 0;
  }

  void _discard(int s, int t) {
    hands[s][t]--;
    final giri = drawn[s] == t;
    drawn[s] = -1;
    discards[s].add(_GxDiscard(t, tsumogiri: giri));
    canZimo = false;
    afterKong = false;
    lastDiscardSeat = s;
    lastAction = '${name(s)} 打出 ${tileName(t)}';
    _event('discard', s, t);

    final opts = <int, Set<String>>{};
    final chis = <int, List<int>>{};
    final hu = <int, GuangxiResult>{};
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
      claim = _GxClaim(t, s, false, opts, chis: chis, hu: hu);
      phase = 'claim';
    }
  }

  int _prio(String type) => switch (type) {
        'ron' || 'hu' => 30,
        'gang' || 'peng' => 20,
        'chi' => 10,
        _ => 0,
      };

  int _maxPrio(_GxClaim c, int s) {
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

  void _recordFeed(int seat, int from) {
    if (seat >= 0 && seat < players && from >= 0 && from < players && seat != from) {
      feedCount[seat][from]++;
      if (feedCount[seat][from] == 3) {
        host.log('【三口承包】${name(seat)} 已吃/碰/杠 ${name(from)} 满 3 口，双方进入自摸全包关系！');
      }
    }
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
    _recordFeed(s, c.from);
    if (type == 'gang') {
      hands[s][c.tile] -= 3;
      melds[s].add(Meld('mgang', c.tile, claimed: c.tile, from: c.from));
      _pay(c.from, s, 2);
      events.add({'kind': 'gang', 'from': c.from, 'to': s, 'amount': 2, 'why': '点杠'});
      lastAction = '${name(s)} 明杠 ${tileName(c.tile)}（喂牌 ${feedCount[s][c.from]}/3）';
      host.log(lastAction);
      _event('gang', s, c.tile);
      _draw(s, kong: true);
      return;
    }
    if (type == 'peng') {
      hands[s][c.tile] -= 2;
      melds[s].add(Meld('peng', c.tile, claimed: c.tile, from: c.from));
      lastAction = '${name(s)} 碰 ${tileName(c.tile)}（喂牌 ${feedCount[s][c.from]}/3）';
      _event('peng', s, c.tile);
    } else if (type == 'chi') {
      final lo = r['tile'] as int;
      for (var k = lo; k < lo + 3; k++) {
        if (k != c.tile) hands[s][k]--;
      }
      melds[s].add(Meld('chi', lo, claimed: c.tile, from: c.from));
      lastAction = '${name(s)} 吃 ${tileName(c.tile)}（喂牌 ${feedCount[s][c.from]}/3）';
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
      final hu = <int, GuangxiResult>{};
      for (var o = 0; o < players; o++) {
        if (o == s) continue;
        final r = ronEval(o, t, rob: true);
        if (r != null) {
          opts[o] = {'ron'};
          hu[o] = r;
        }
      }
      if (opts.isNotEmpty) {
        claim = _GxClaim(t, s, true, opts, hu: hu);
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

  void _flipHorseTiles() {
    if (horseTiles.isNotEmpty) return; // Respect pre-set horseTiles in tests
    final flipped = <String>[];
    for (var i = 0; i < horseCount; i++) {
      if (wall.isNotEmpty) {
        flipped.add(tileCode(wall.removeLast()));
      } else {
        flipped.add(tileCode(rng.nextInt(kKinds)));
      }
    }
    horseTiles = flipped;
  }

  void _settleWin(Map<int, (int, GuangxiResult)> wins, int from, {bool rob = false}) {
    final zimo = from < 0;
    _flipHorseTiles();

    for (final e in wins.entries) {
      final w = e.key;
      final (tile, rawRes) = e.value;
      final wWind = seatWind(w);
      final evalHand = List<int>.of(hands[w]);
      if (!zimo) evalHand[tile]++;
      final res = guangxiEvaluate(
            evalHand,
            melds[w],
            horseTiles: horseTiles,
            winnerWind: wWind,
            selfDrawn: zimo,
            gangKai: afterKong && zimo,
            qiangGang: rob,
          ) ??
          rawRes;

      matchedHorses = res.matchedHorses;
      if (zimo && hands[w][tile] > 0) hands[w][tile]--;
      drawn[w] = -1;

      final singleShare = res.fan * (zimo ? 2 : 1);
      final liable = chengbaoPartners(w);
      final isChengbao = zimo && liable.isNotEmpty;
      final pay = <String, int>{};
      var totalWon = 0;

      if (isChengbao) {
        for (final p in liable) {
          final amt = singleShare * 3;
          _pay(p, w, amt);
          pay['$p'] = amt;
          totalWon += amt;
        }
      } else {
        final payers = zimo ? [for (var o = 0; o < players; o++) if (o != w) o] : [from];
        for (final p in payers) {
          _pay(p, w, singleShare);
          pay['$p'] = singleShare;
          totalWon += singleShare;
        }
      }

      final itemsJson = res.toJson();
      if (isChengbao) {
        itemsJson.add(['三口承包(×3)', singleShare * 2]);
      }

      events.add({
        'kind': 'hu',
        'seat': w,
        'from': from,
        'tile': tileCode(tile),
        'zimo': zimo,
        'rob': rob,
        'big': res.isBig,
        'baseFan': res.baseFan,
        'fan': res.fan,
        'mult': res.mult,
        'horseTiles': List.of(horseTiles),
        'matchedHorses': res.matchedHorses,
        'matchedHorseTiles': res.matchedHorseTiles,
        'chengbao': isChengbao,
        'chengbaoPayers': liable,
        'chengbaoPayer': liable.isNotEmpty ? liable.first : null,
        'total': totalWon,
        'items': itemsJson,
        'pay': pay,
        'hand': codesOfCounts(hands[w]),
      });
      final cbText = isChengbao ? '【三口承包：${liable.map(name).join("、")}全包×3】' : '';
      host.log(zimo
          ? '${name(w)} 自摸 ${tileName(tile)}！${res.label}（中马 ${res.matchedHorses}/${horseTiles.length}）$cbText'
          : '${name(w)} 胡 ${name(from)} 的 ${tileName(tile)}！${res.label}（中马 ${res.matchedHorses}/${horseTiles.length}）');
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
      'horseCount': horseCount,
      'horseTiles': List.of(horseTiles),
      'matchedHorses': matchedHorses,
      'feedCount': [for (var s = 0; s < players; s++) [for (var f = 0; f < players; f++) feedsFrom(s, f)]],
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
        'feeds': [for (var f = 0; f < players; f++) feedsFrom(s, f)],
        'chengbao': chengbaoPartners(s),
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
      'rule': 'guangximj',
      'phase': phase == 'pause' ? 'claim' : phase,
      'hand': handNo,
      'hands': totalRounds,
      'rounds': totalRounds,
      'dealer': dealer,
      'turn': turn,
      'wall': wall.length,
      'horseCount': horseCount,
      'horseTiles': List.of(horseTiles),
      'matchedHorses': matchedHorses,
      'feedCount': [for (var s = 0; s < players; s++) [for (var f = 0; f < players; f++) feedsFrom(s, f)]],
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
        'chengbao': chengbaoPartners(seat),
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
        if (claim!.chis.containsKey(seat)) {
          my['chis'] = [
            for (final lo in claim!.chis[seat]!) [for (var k = lo; k < lo + 3; k++) tileCode(k)]
          ];
        }
      }
      final n = countTotal(hands[seat]);
      if (n % 3 == 1 && (phase == 'act' || phase == 'claim' || phase == 'pause')) {
        my['waits'] = [for (final t in guangxiWaits(hands[seat], melds[seat])) tileCode(t)];
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
        final ks = selfKongs();
        if (ks.isNotEmpty) return {'type': 'gang', 'tile': tileCode(ks.first.$1)};
        final legals = legalDiscards(seat);
        if (botLevel == 0 && rng.nextDouble() < 0.35) {
          return {'type': 'discard', 'tile': tileCode(legals[rng.nextInt(legals.length)])};
        }
        var best = legals.first, bestScore = 1 << 20;
        for (final t in legals) {
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
        if (o.contains('chi') && rng.nextDouble() < 0.4) {
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
