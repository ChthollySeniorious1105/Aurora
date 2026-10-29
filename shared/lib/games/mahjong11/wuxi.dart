import '../../src/engine.dart';
import 'tiles.dart';

class WuxiResult {
  final int baseFan;
  final int fan;
  final int mult;
  final bool isYingHu; // 无百搭硬胡 (+1 番)
  final bool isMenQing; // 门清双倍 (+1 番, ×2)
  final bool isQiDui;
  final bool isPengPeng;
  final bool isQingYiSe;
  final bool isHunYiSe;
  final bool isBig;
  final List<(String, int)> items;

  const WuxiResult({
    required this.baseFan,
    required this.fan,
    required this.mult,
    required this.isYingHu,
    required this.isMenQing,
    required this.isQiDui,
    required this.isPengPeng,
    required this.isQingYiSe,
    required this.isHunYiSe,
    required this.isBig,
    required this.items,
  });

  String get label => [for (final (n, _) in items) n].join(' ');
  List<List<Object>> toJson() => [for (final (n, f) in items) [n, f]];
}

/// Evaluates a Wuxi Mahjong (无锡麻将) hand (136 tiles):
/// - [baidaTile] (flipped from `baidaIndicator` -> next cyclic tile) is the universal wildcard (**百搭**).
/// - **无百搭硬胡 ([isYingHu])**: `+1` 番 when winning with 0 wildcards or naturally without wildcard substitution.
/// - **门清双倍 ([isMenQing])**: `+1` 番 & `×2` multiplier when winning with 0 exposed melds.
WuxiResult? wuxiEvaluate(
  List<int> concealed,
  List<Meld> melds, {
  Object? baidaTile = -1,
  bool selfDrawn = false,
  bool gangKai = false,
  bool qiangGang = false,
}) {
  final total = countTotal(concealed);
  final needSets = 4 - melds.length;
  if (needSets < 0 || total != needSets * 3 + 2) return null;

  final bdId = tileFromCode(baidaTile);
  final wild = (bdId >= 0 && bdId < concealed.length) ? concealed[bdId] : 0;

  // 1. Check 无百搭硬胡 (Hard Hand): 0 baidaTile OR wins naturally without wildcard substitution
  final pureStd = isStandardWin(concealed);
  final pureQidui = melds.isEmpty && isSevenPairs(concealed);
  final isYingHu = pureStd || pureQidui;

  // 2. Check Soft Hand with baidaTile wildcard
  final c = List<int>.of(concealed);
  if (bdId >= 0 && bdId < c.length) {
    c[bdId] = 0;
  }
  final stdWin = pureStd || (wild > 0 && canAnyPairStandardWild(c, wild));
  final qidui = pureQidui || (melds.isEmpty && wild > 0 && canSevenPairsWild(c, wild));
  if (!stdWin && !qidui) return null;

  final pengpeng = stdWin &&
      melds.every((m) => !m.isChi) &&
      (isAllPungs(concealed) || (wild > 0 && canPengPengWild(c, wild)));
  final menqing = melds.every((m) => m.concealed);

  final suits = <int>{};
  var hasHonor = false;
  final suitCheck = isYingHu ? concealed : c;
  for (var t = 0; t < suitCheck.length; t++) {
    if (suitCheck[t] <= 0) continue;
    if (t < kNumKinds) {
      suits.add(t ~/ 9);
    } else {
      hasHonor = true;
    }
  }
  for (final m in melds) {
    for (final t in m.tiles) {
      if (!isYingHu && t == bdId) continue;
      if (t < kNumKinds) {
        suits.add(t ~/ 9);
      } else {
        hasHonor = true;
      }
    }
  }

  final qingyise = !hasHonor && suits.length <= 1;
  final hunyise = hasHonor && suits.length == 1;

  final items = <(String, int)>[('底番', 1)];
  var mult = 1;

  if (qingyise) {
    items.add(('清一色', 4));
    mult *= 2;
  } else if (hunyise) {
    items.add(('混一色', 2));
    mult *= 2;
  }
  if (qidui) {
    items.add(('七对', 2));
    mult *= 2;
  } else if (pengpeng) {
    items.add(('对对胡', 2));
    mult *= 2;
  }
  if (isYingHu) {
    items.add(('无百搭硬胡', 1));
  }
  if (menqing) {
    items.add(('门清双倍', 1));
    mult *= 2;
  }
  if (gangKai) {
    items.add(('杠上开花', 1));
  }
  if (qiangGang) {
    items.add(('抢杠胡', 1));
  }

  final fan = items.fold<int>(0, (a, b) => a + b.$2);
  final isBig = qingyise || hunyise || qidui || pengpeng || isYingHu || menqing || gangKai || qiangGang;

  return WuxiResult(
    baseFan: fan,
    fan: fan,
    mult: mult,
    isYingHu: isYingHu,
    isMenQing: menqing,
    isQiDui: qidui,
    isPengPeng: pengpeng,
    isQingYiSe: qingyise,
    isHunYiSe: hunyise,
    isBig: isBig,
    items: items,
  );
}

List<int> wuxiWaits(
  List<int> concealed,
  List<Meld> melds, {
  Object? baidaTile = -1,
}) {
  final out = <int>[];
  for (var t = 0; t < kKinds && t < concealed.length; t++) {
    concealed[t]++;
    final r = wuxiEvaluate(concealed, melds, baidaTile: baidaTile, selfDrawn: true);
    concealed[t]--;
    if (r != null) out.add(t);
  }
  return out;
}

class _WxClaim {
  final int tile;
  final int from;
  final bool rob;
  final Map<int, Set<String>> opts;
  final Map<int, List<int>> chis;
  final Map<int, WuxiResult> hu;
  final Map<int, Map<String, dynamic>> resp = {};
  _WxClaim(this.tile, this.from, this.rob, this.opts, {this.chis = const {}, this.hu = const {}});
  List<int> get pending => [for (final s in opts.keys) if (!resp.containsKey(s)) s]..sort();
}

class _WxDiscard {
  final int tile;
  bool taken = false;
  final bool tsumogiri;
  _WxDiscard(this.tile, {this.tsumogiri = false});
}

/// 无锡麻将 (wuximj)
class WuxiGame extends GameEngine {
  WuxiGame(super.setup);

  late final int totalRounds = setup.opt<int>('rounds', 4);
  late final bool fangchongDufu = setup.opt<bool>('fangchongDufu', true);

  late List<int> scores = List.filled(players, 0);
  int handNo = 0;
  int dealer = 0;
  bool over = false;
  List<Map<String, dynamic>> history = [];

  // Wuxi-specific state:
  // 1. 翻百搭 (baidaIndicator -> baidaTile universal wildcard)
  // 2. 放冲独付 (on ron, discarder pays all 3 shares ×3 alone while other 2 players pay 0)
  int baidaIndicatorId = 0;
  int baidaTileId = 1;
  String get baidaIndicator => tileCode(baidaIndicatorId);
  String get baidaTile => tileCode(baidaTileId);

  void setBaidaIndicator(Object indicator) {
    final id = tileFromCode(indicator);
    if (id >= 0) {
      baidaIndicatorId = id;
      baidaTileId = nextCyclicTile(id);
    }
  }

  void setBaidaTile(Object tile) {
    final id = tileFromCode(tile);
    if (id >= 0) {
      baidaTileId = id;
    }
  }

  // Hand state
  String phase = 'act'; // act, claim, settle, over, pause
  String pausedPhase = '';
  List<List<int>> hands = [];
  List<List<Meld>> melds = [];
  List<List<_WxDiscard>> discards = [];
  List<int> drawn = [];
  List<int> wall = [];
  int turn = 0;
  bool canZimo = false;
  bool afterKong = false;
  int lastDiscardSeat = -1;
  String lastAction = '';
  Map<String, dynamic>? lastEvent;
  int eventSeq = 0;
  _WxClaim? claim;
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
    discards = List.generate(players, (_) => <_WxDiscard>[]);
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
    setBaidaIndicator(ind);

    turn = dealer;
    phase = 'act';
    canZimo = true;
    host.log('第 $handNo/$totalRounds 局开始，${name(dealer)} 坐庄，翻出 ${tileName(baidaIndicatorId)}，本局百搭：${tileName(baidaTileId)}（无百搭硬胡 · 门清双倍 · 放冲独付×3）');
    lastAction = '百搭：${tileName(baidaTileId)} · ${name(dealer)} 出牌';
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

  WuxiResult? selfEval(int s) => wuxiEvaluate(
        hands[s],
        melds[s],
        baidaTile: baidaTileId,
        selfDrawn: true,
        gangKai: afterKong,
      );

  WuxiResult? ronEval(int o, int t, {bool rob = false}) {
    final c = List<int>.of(hands[o]);
    c[t]++;
    return wuxiEvaluate(
      c,
      melds[o],
      baidaTile: baidaTileId,
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
      if (r == null) throw GameError('现在不能自摸胡牌');
      final t = drawn[s] >= 0 && hands[s][drawn[s]] > 0 ? drawn[s] : _anyTile(s);
      _settleWin({s: (t, r)}, -1);
      return;
    }
    if (type == 'gang' || type == 'agang' || type == 'bgang') {
      final t = tileFromCode(a['tile']);
      final allK = selfKongs();
      final filtered = allK.where((e) {
        if (type == 'agang' && e.$2) return false;
        if (type == 'bgang' && !e.$2) return false;
        return t < 0 || e.$1 == t;
      }).toList();
      if (filtered.isEmpty) throw GameError('不能杠这张牌');
      _selfKong(s, filtered.first.$1, filtered.first.$2);
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
    discards[s].add(_WxDiscard(t, tsumogiri: giri));
    canZimo = false;
    afterKong = false;
    lastDiscardSeat = s;
    lastAction = '${name(s)} 打出 ${tileName(t)}';
    _event('discard', s, t);

    final opts = <int, Set<String>>{};
    final chis = <int, List<int>>{};
    final hu = <int, WuxiResult>{};
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
      claim = _WxClaim(t, s, false, opts, chis: chis, hu: hu);
      phase = 'claim';
    }
  }

  int _prio(String type) => switch (type) {
        'ron' || 'hu' => 30,
        'gang' || 'mgang' || 'peng' => 20,
        'chi' => 10,
        _ => 0,
      };

  int _maxPrio(_WxClaim c, int s) {
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
    final type = switch (rawType) {
      'hu' => 'ron',
      'mgang' => 'gang',
      'pon' => 'peng',
      'skip' => 'pass',
      _ => rawType,
    };
    if (type != 'pass' && !o.contains(type)) throw GameError('不能执行该操作');
    var chiTile = -1;
    if (type == 'chi') {
      final list = c.chis[s] ?? const [];
      var arg = tileFromCode(a['tile']);
      if (arg < 0 && a['tiles'] is List && (a['tiles'] as List).isNotEmpty) {
        final ts = [for (final e in a['tiles'] as List) tileFromCode(e), c.tile].where((x) => x >= 0).toList()..sort();
        if (ts.isNotEmpty) arg = ts.first;
      }
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
      final hu = <int, WuxiResult>{};
      for (var o = 0; o < players; o++) {
        if (o == s) continue;
        final r = ronEval(o, t, rob: true);
        if (r != null) {
          opts[o] = {'ron'};
          hu[o] = r;
        }
      }
      if (opts.isNotEmpty) {
        claim = _WxClaim(t, s, true, opts, hu: hu);
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

  void _settleWin(Map<int, (int, WuxiResult)> wins, int from, {bool rob = false}) {
    final zimo = from < 0;
    for (final e in wins.entries) {
      final w = e.key;
      final (tile, res) = e.value;
      if (zimo && hands[w][tile] > 0) hands[w][tile]--;
      drawn[w] = -1;

      final share = res.fan;
      final pay = <String, int>{};
      var totalWon = 0;

      if (zimo) {
        // 自摸：三家各自付 1× 份额
        for (var o = 0; o < players; o++) {
          if (o == w) continue;
          _pay(o, w, share);
          pay['$o'] = share;
          totalWon += share;
        }
      } else if (fangchongDufu) {
        // 放冲独付：点炮者一人包赔全部 3 家份额 (×3)，其余两家付 0！
        final amt = share * (players - 1);
        _pay(from, w, amt);
        pay['$from'] = amt;
        totalWon = amt;
      } else {
        _pay(from, w, share);
        pay['$from'] = share;
        totalWon = share;
      }

      final itemsJson = res.toJson();
      if (!zimo && fangchongDufu) {
        itemsJson.add(['${name(from)}放冲独付×3', totalWon]);
      }

      events.add({
        'kind': 'hu',
        'seat': w,
        'from': from,
        'tile': tileCode(tile),
        'zimo': zimo,
        'rob': rob,
        'big': res.isBig,
        'isYingHu': res.isYingHu,
        'isMenQing': res.isMenQing,
        'fangchongDufu': !zimo && fangchongDufu,
        'baoZimo': !zimo && fangchongDufu,
        'baidaTile': baidaTile,
        'baseFan': res.baseFan,
        'fan': res.fan,
        'mult': !zimo && fangchongDufu ? 3 : res.mult,
        'total': totalWon,
        'items': itemsJson,
        'pay': pay,
        'hand': codesOfCounts(hands[w]),
      });
      final dufuDesc = !zimo && fangchongDufu ? '（${name(from)} 放冲独付包三家×3）' : '';
      host.log(zimo
          ? '${name(w)} 自摸 ${tileName(tile)}！${res.label}'
          : '${name(w)} 胡 ${name(from)} 的 ${tileName(tile)}！${res.label}$dufuDesc');
      _event(zimo ? 'zimo' : 'hu', w, tile);
    }
    lastAction = zimo ? '${name(wins.keys.first)} 自摸' : '${wins.keys.map(name).join('、')} 捉铳胡（${name(from)}独付×3）';
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
      'fangchongDufu': fangchongDufu,
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
      'rule': 'wuximj',
      'phase': phase == 'pause' ? 'claim' : phase,
      'hand': handNo,
      'hands': totalRounds,
      'rounds': totalRounds,
      'dealer': dealer,
      'turn': turn,
      'wall': wall.length,
      'baidaIndicator': baidaIndicator,
      'baidaTile': baidaTile,
      'fangchongDufu': fangchongDufu,
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
            for (final lo in claim!.chis[seat]!) [tileCode(lo), tileCode(lo + 1), tileCode(lo + 2)]
          ];
        }
      }
      final n = countTotal(hands[seat]);
      if (n % 3 == 1 && (phase == 'act' || phase == 'claim' || phase == 'pause')) {
        my['waits'] = [
          for (final t in wuxiWaits(hands[seat], melds[seat], baidaTile: baidaTileId)) tileCode(t)
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
        final ks = selfKongs().where((e) => e.$1 != baidaTileId).toList();
        if (ks.isNotEmpty) return {'type': 'gang', 'tile': tileCode(ks.first.$1)};
        final legals = legalDiscards(seat);
        final nonBd = [for (final t in legals) if (t != baidaTileId) t];
        final pool = nonBd.isNotEmpty ? nonBd : legals;
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
        if (c.tile != baidaTileId) {
          if (o.contains('gang')) return {'type': 'gang'};
          if (o.contains('peng') && (hands[seat][c.tile] >= 3 || rng.nextDouble() < 0.55)) {
            return {'type': 'peng'};
          }
          if (o.contains('chi') && rng.nextDouble() < 0.4) {
            final lo = c.chis[seat]!.first;
            return {'type': 'chi', 'tile': tileCode(lo)};
          }
        }
        return {'type': 'pass'};
      case 'settle':
        return ready.contains(seat) ? null : {'type': 'next'};
    }
    return null;
  }
}
