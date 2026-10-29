import '../../src/engine.dart';
import 'tiles.dart';

class NanchangResult {
  final int fan;
  final int mult; // 七星十三烂 ×4, 十三烂 ×2, 德国 ×2, etc.
  final bool isDeguo;
  final bool isShisanlan;
  final bool isQixing;
  final bool isBig;
  final List<(String, int)> items;
  const NanchangResult(
    this.fan,
    this.mult,
    this.isDeguo,
    this.isShisanlan,
    this.isQixing,
    this.isBig,
    this.items,
  );

  String get label => [for (final (n, _) in items) n].join(' ');
  List<List<Object>> toJson() => [for (final (n, f) in items) [n, f]];
}

class NanchangJingSummary {
  final List<int> zhengCounts;
  final List<int> fuCounts;
  final List<int> basePoints;
  final int bawangSeat;
  final List<bool> chongguan;
  final List<int> effectivePoints;
  final List<int> deltas;
  const NanchangJingSummary({
    required this.zhengCounts,
    required this.fuCounts,
    required this.basePoints,
    required this.bawangSeat,
    required this.chongguan,
    required this.effectivePoints,
    required this.deltas,
  });

  Map<String, dynamic> toJson() => {
        'zhengCounts': zhengCounts,
        'fuCounts': fuCounts,
        'basePoints': basePoints,
        'bawangSeat': bawangSeat,
        'chongguan': chongguan,
        'effectivePoints': effectivePoints,
        'deltas': deltas,
      };
}

/// Computes Nanchang Mahjong Jing settlement (正精=2分, 副精=1分, 霸王精×2, 冲关(>=5精分)×2).
NanchangJingSummary nanchangJingSettle(List<int> zjCounts, List<int> fjCounts) {
  final n = zjCounts.length;
  final base = [for (var s = 0; s < n; s++) zjCounts[s] * 2 + fjCounts[s]];
  final holders = [for (var s = 0; s < n; s++) if (base[s] > 0) s];
  final bawangSeat = holders.length == 1 ? holders.first : -1;
  final chongguan = [for (var s = 0; s < n; s++) base[s] >= 5];
  final effective = [
    for (var s = 0; s < n; s++)
      base[s] * (bawangSeat == s ? 2 : 1) * (chongguan[s] ? 2 : 1),
  ];
  final deltas = List<int>.filled(n, 0);
  for (var s = 0; s < n; s++) {
    final pts = effective[s];
    if (pts <= 0) continue;
    for (var o = 0; o < n; o++) {
      if (o == s) continue;
      deltas[o] -= pts;
      deltas[s] += pts;
    }
  }
  return NanchangJingSummary(
    zhengCounts: List.of(zjCounts),
    fuCounts: List.of(fjCounts),
    basePoints: base,
    bawangSeat: bawangSeat,
    chongguan: chongguan,
    effectivePoints: effective,
    deltas: deltas,
  );
}

int _maxShisanlanSuitSlots(List<int> c, int suit) {
  final base = suit * 9;
  var prevFixed = -10;
  for (var r = 0; r < 9; r++) {
    final cnt = c[base + r];
    if (cnt > 1) return -1;
    if (cnt == 1) {
      if (r - prevFixed < 3) return -1;
      prevFixed = r;
    }
  }
  var count = 0;
  var last = -10;
  for (var r = 0; r < 9; r++) {
    if (c[base + r] == 1) {
      count++;
      last = r;
    } else if (r - last >= 3) {
      var conflictNext = false;
      for (var nr = r + 1; nr < 9 && nr < r + 3; nr++) {
        if (c[base + nr] == 1) {
          conflictNext = true;
          break;
        }
      }
      if (!conflictNext) {
        count++;
        last = r;
      }
    }
  }
  return count;
}

/// Checks pure 十三烂 (14 all-distinct tiles, suit rank gap >= 3, no wildcard substitution).
bool isPureShisanlan(List<int> c) {
  if (countTotal(c) != 14) return false;
  for (var t = 0; t < kKinds; t++) {
    if (c[t] > 1) return false;
  }
  for (var s = 0; s < 3; s++) {
    if (_maxShisanlanSuitSlots(c, s) < 0) return false;
  }
  return true;
}

/// Checks 十三烂 allowing [zhengJing] to act as a universal wildcard.
bool canShisanlanWild(List<int> c, int zhengJing) {
  if (countTotal(c) != 14) return false;
  if (isPureShisanlan(c)) return true;
  if (zhengJing < 0 || zhengJing >= c.length || c[zhengJing] <= 0) return false;
  final w = List<int>.of(c);
  w[zhengJing] = 0;
  for (var t = 0; t < kKinds; t++) {
    if (w[t] > 1) return false;
  }
  var maxSlots = 7; // 7 distinct honor tiles 1z..7z
  for (var s = 0; s < 3; s++) {
    final slots = _maxShisanlanSuitSlots(w, s);
    if (slots < 0) return false;
    maxSlots += slots;
  }
  return maxSlots >= 14;
}

/// Evaluates a Nanchang Mahjong hand (136 tiles, [zhengJing] is universal wildcard).
NanchangResult? nanchangEvaluate(
  List<int> concealed,
  List<Meld> melds, {
  required int zhengJing,
  bool selfDrawn = false,
  bool gangKai = false,
  bool qiangGang = false,
}) {
  final total = countTotal(concealed);
  final needSets = 4 - melds.length;
  if (needSets < 0 || total != needSets * 3 + 2) return null;

  // Pure checks (德国: winning without using zhengJing as a wildcard substitute)
  final pureSsl = melds.isEmpty && isPureShisanlan(concealed);
  final pureQidui = melds.isEmpty && isSevenPairs(concealed);
  final pureStd = isStandardWin(concealed);
  final isDeguo = pureSsl || pureQidui || pureStd;

  final c = List<int>.of(concealed);
  final wild = (zhengJing >= 0 && zhengJing < c.length) ? c[zhengJing] : 0;
  if (zhengJing >= 0 && zhengJing < c.length) {
    c[zhengJing] = 0;
  }

  final ssl = pureSsl || (melds.isEmpty && canShisanlanWild(concealed, zhengJing));
  final qidui = pureQidui || (melds.isEmpty && canSevenPairsWild(c, wild));
  final stdWin = pureStd || canAnyPairStandardWild(c, wild);
  final pengpeng = melds.every((m) => !m.isChi) && (isAllPungs(concealed) || canPengPengWild(c, wild));

  if (!ssl && !qidui && !stdWin) return null;

  // 七星十三烂: Shisanlan containing all 7 distinct honor tiles 1z..7z (27..33)
  var allSevenHonors = true;
  for (var h = 27; h < 34; h++) {
    if (concealed[h] < 1) {
      allSevenHonors = false;
      break;
    }
  }
  final qixing = ssl && allSevenHonors;

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
      if (t == zhengJing) continue;
      if (t < kNumKinds) {
        suits.add(t ~/ 9);
      } else {
        hasHonor = true;
      }
    }
  }
  final qingyise = !ssl && !hasHonor && suits.length <= 1;

  final items = <(String, int)>[];
  var mult = 1;
  if (qixing) {
    items.add(('七星十三烂', 8));
    mult *= 4;
  } else if (ssl) {
    items.add(('十三烂', 4));
    mult *= 2;
  }
  if (isDeguo) {
    items.add(('德国', 2));
    mult *= 2;
  }
  if (qingyise) items.add(('清一色', 4));
  if (pengpeng && stdWin && !ssl) items.add(('碰碰胡', 2));
  if (qidui && !pengpeng && !ssl) items.add(('七对', 4));
  if (gangKai) {
    items.add(('杠上开花', 2));
    mult *= 2;
  }
  if (qiangGang) items.add(('抢杠胡', 2));
  if (items.isEmpty) items.add(('平胡', 1));
  if (selfDrawn) items.add(('自摸', 1));

  final isBig = qixing || ssl || isDeguo || qingyise || pengpeng || qidui || gangKai || qiangGang;
  final fan = items.fold<int>(0, (a, b) => a + b.$2);
  return NanchangResult(fan, mult, isDeguo, ssl, qixing, isBig, items);
}

List<int> nanchangWaits(
  List<int> concealed,
  List<Meld> melds, {
  required int zhengJing,
}) {
  final out = <int>[];
  for (var t = 0; t < kKinds && t < concealed.length; t++) {
    concealed[t]++;
    final r = nanchangEvaluate(concealed, melds, zhengJing: zhengJing, selfDrawn: true);
    concealed[t]--;
    if (r != null) out.add(t);
  }
  return out;
}

class _NcClaim {
  final int tile;
  final int from;
  final bool rob;
  final Map<int, Set<String>> opts;
  final Map<int, List<int>> chis;
  final Map<int, NanchangResult> hu;
  final Map<int, Map<String, dynamic>> resp = {};
  _NcClaim(this.tile, this.from, this.rob, this.opts, {this.chis = const {}, this.hu = const {}});
  List<int> get pending => [for (final s in opts.keys) if (!resp.containsKey(s)) s]..sort();
}

class _NcDiscard {
  final int tile;
  bool taken = false;
  final bool tsumogiri;
  _NcDiscard(this.tile, {this.tsumogiri = false});
}

/// 南昌麻将 (nanchangmj)
class NanchangGame extends GameEngine {
  NanchangGame(super.setup);

  late final int totalRounds = setup.opt<int>('rounds', 4);

  late List<int> scores = List.filled(players, 0);
  int handNo = 0;
  int dealer = 0;
  bool over = false;
  List<Map<String, dynamic>> history = [];

  // Nanchang-specific state: 上下翻精 (正精 = jingIndicator, 副精 = nextCyclicTile(zhengJing))
  int jingIndicatorId = 0;
  int zhengJingId = 0;
  int fuJingId = 1;
  String get jingIndicator => tileCode(jingIndicatorId);
  String get zhengJing => tileCode(zhengJingId);
  String get fuJing => tileCode(fuJingId);

  void setJingIndicator(int id) {
    jingIndicatorId = id;
    zhengJingId = id;
    fuJingId = nextCyclicTile(id);
  }

  // Hand state
  String phase = 'act'; // act, claim, settle, over, pause
  String pausedPhase = '';
  List<List<int>> hands = [];
  List<List<Meld>> melds = [];
  List<List<_NcDiscard>> discards = [];
  List<int> drawn = [];
  List<int> wall = [];
  int turn = 0;
  bool canZimo = false;
  bool afterKong = false;
  int lastDiscardSeat = -1;
  String lastAction = '';
  Map<String, dynamic>? lastEvent;
  int eventSeq = 0;
  _NcClaim? claim;
  List<int> handDelta = [];
  List<Map<String, dynamic>> events = [];
  Map<String, dynamic>? settle;
  NanchangJingSummary? lastJingSummary;
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
    discards = List.generate(players, (_) => <_NcDiscard>[]);
    drawn = List.filled(players, -1);
    handDelta = List.filled(players, 0);
    events = [];
    settle = null;
    lastJingSummary = null;
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

    // 翻精: flip 1 indicator from the wall -> 正精 (2 pts, wildcard) & 副精 (1 pt, next cyclic tile)
    setJingIndicator(wall.removeLast());

    turn = dealer;
    phase = 'act';
    canZimo = true;
    host.log('第 $handNo/$totalRounds 局开始，${name(dealer)} 坐庄，正精：${tileName(zhengJingId)}，副精：${tileName(fuJingId)}');
    lastAction = '正精：${tileName(zhengJingId)} / 副精：${tileName(fuJingId)}';
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

  NanchangResult? selfEval(int s) => nanchangEvaluate(
        hands[s],
        melds[s],
        zhengJing: zhengJingId,
        selfDrawn: true,
        gangKai: afterKong,
      );

  NanchangResult? ronEval(int o, int t, {bool rob = false}) {
    if (t == zhengJingId) return null;
    final c = List<int>.of(hands[o]);
    c[t]++;
    return nanchangEvaluate(
      c,
      melds[o],
      zhengJing: zhengJingId,
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
      if (t == zhengJingId) continue;
      if (hands[s][t] == 4) out.add((t, false));
      if (hands[s][t] >= 1 && melds[s].any((m) => m.isPeng && m.tile == t)) out.add((t, true));
    }
    return out;
  }

  List<int> chiOptions(int s, int t) {
    if (t >= kNumKinds || t == zhengJingId) return const [];
    final h = hands[s];
    final r = rankOf(t);
    final out = <int>[];
    for (var lo = t - 2; lo <= t; lo++) {
      final lr = r - (t - lo);
      if (lr < 1 || lr > 7) continue;
      var ok = true;
      for (var k = lo; k < lo + 3; k++) {
        if (k == zhengJingId) ok = false;
        if (k != t && h[k] == 0) ok = false;
      }
      if (ok) out.add(lo);
    }
    return out;
  }

  List<int> legalDiscards(int s) => [for (var t = 0; t < kKinds; t++) if (hands[s][t] > 0) t];

  int _countSeatTile(int s, int tileId) {
    if (tileId < 0 || tileId >= kKinds) return 0;
    var n = hands[s][tileId];
    for (final m in melds[s]) {
      for (final t in m.tiles) {
        if (t == tileId) n++;
      }
    }
    for (final d in discards[s]) {
      if (!d.taken && d.tile == tileId) n++;
    }
    return n;
  }

  int seatJingPoints(int s) => _countSeatTile(s, zhengJingId) * 2 + _countSeatTile(s, fuJingId);

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
      if (t < 0 || t >= kKinds || hands[s][t] <= 0) throw GameError('你没有这张牌');
      _discard(s, t);
      return;
    }
    throw GameError('请出牌');
  }

  int _anyTile(int s) {
    for (var t = kKinds - 1; t >= 0; t--) {
      if (t != zhengJingId && hands[s][t] > 0) return t;
    }
    return zhengJingId;
  }

  void _discard(int s, int t) {
    hands[s][t]--;
    final giri = drawn[s] == t;
    drawn[s] = -1;
    discards[s].add(_NcDiscard(t, tsumogiri: giri));
    canZimo = false;
    afterKong = false;
    lastDiscardSeat = s;
    lastAction = '${name(s)} 打出 ${tileName(t)}';
    _event('discard', s, t);

    if (t == zhengJingId) {
      _coverPause(() => _draw((s + 1) % players));
      return;
    }

    final opts = <int, Set<String>>{};
    final chis = <int, List<int>>{};
    final hu = <int, NanchangResult>{};
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
      claim = _NcClaim(t, s, false, opts, chis: chis, hu: hu);
      phase = 'claim';
    }
  }

  int _prio(String type) =>
      switch (type) { 'hu' || 'ron' => 30, 'gang' || 'peng' => 20, 'chi' => 10, _ => 0 };

  int _maxPrio(_NcClaim c, int s) {
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
    final type = rawType == 'ron' ? 'hu' : rawType;
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
      final opts = <int, Set<String>>{};
      final hu = <int, NanchangResult>{};
      for (var o = 0; o < players; o++) {
        if (o == s) continue;
        final r = ronEval(o, t, rob: true);
        if (r != null) {
          opts[o] = {'hu'};
          hu[o] = r;
        }
      }
      if (opts.isNotEmpty) {
        claim = _NcClaim(t, s, true, opts, hu: hu);
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
    lastAction = '${name(s)} 暗杠 ${tileName(t)}';
    host.log(lastAction);
    _event('gang', s);
    _draw(s, kong: true);
  }

  void _finishBuGang(int s, int t) {
    hands[s][t]--;
    final m = melds[s].firstWhere((m) => m.isPeng && m.tile == t);
    m.kind = 'bgang';
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

  void _settleJing() {
    final zjCounts = [for (var s = 0; s < players; s++) _countSeatTile(s, zhengJingId)];
    final fjCounts = [for (var s = 0; s < players; s++) _countSeatTile(s, fuJingId)];
    final summary = nanchangJingSettle(zjCounts, fjCounts);
    lastJingSummary = summary;
    for (var s = 0; s < players; s++) {
      final pts = summary.effectivePoints[s];
      if (pts <= 0) continue;
      final tags = <String>[
        '精分(${summary.basePoints[s]})',
        if (summary.bawangSeat == s) '霸王精×2',
        if (summary.chongguan[s]) '冲关×2',
      ];
      final why = tags.join('·');
      for (var o = 0; o < players; o++) {
        if (o == s) continue;
        _pay(o, s, pts);
        events.add({'kind': 'jing', 'from': o, 'to': s, 'amount': pts, 'why': why});
      }
    }
  }

  void _settleWin(Map<int, (int, NanchangResult)> wins, int from, {bool rob = false}) {
    // Settle Jing points before removing winning tile from self-drawn hand
    _settleJing();
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
        'deguo': res.isDeguo,
        'shisanlan': res.isShisanlan,
        'qixing': res.isQixing,
        'fan': res.fan,
        'mult': res.mult,
        'total': totalWon,
        'items': res.toJson(),
        'pay': pay,
        'hand': codesOfCounts(hands[w]),
      });
      host.log(zimo
          ? '${name(w)} 自摸 ${tileName(tile)}！${res.label}（×${res.mult}）'
          : '${name(w)} 胡 ${name(from)} 的 ${tileName(tile)}！${res.label}');
      _event(zimo ? 'zimo' : 'hu', w, tile);
    }
    lastAction = zimo ? '${name(wins.keys.first)} 自摸' : '${wins.keys.map(name).join('、')} 胡牌';
    nextDealer = wins.length == 1 ? wins.keys.first : from;
    _endHand();
  }

  void _drawnGame() {
    _settleJing();
    host.log('牌山摸完，流局（结算精分）');
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
      'jingIndicator': jingIndicator,
      'zhengJing': zhengJing,
      'fuJing': fuJing,
      'jingSummary': lastJingSummary?.toJson(),
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
        'jingPoints': s == seat || reveal ? seatJingPoints(s) : null,
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
      'rule': 'nanchangmj',
      'phase': phase == 'pause' ? 'claim' : phase,
      'hand': handNo,
      'hands': totalRounds,
      'rounds': totalRounds,
      'dealer': dealer,
      'turn': turn,
      'wall': wall.length,
      'jingIndicator': jingIndicator,
      'zhengJing': zhengJing,
      'fuJing': fuJing,
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
        my['canTsumo'] = canSelfHu;
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
          for (final t in nanchangWaits(hands[seat], melds[seat], zhengJing: zhengJingId)) tileCode(t)
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
        if (opts.contains('peng') && hands[seat][c.tile] == 2) return {'type': 'peng'};
        if (opts.contains('chi') && (botLevel == 0 || rng.nextDouble() < 0.5)) {
          final list = c.chis[seat]!;
          return {'type': 'chi', 'tile': tileCode(list.first)};
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
          final nonJing = disc.where((t) => t != zhengJingId).toList();
          final pool = nonJing.isNotEmpty ? nonJing : disc;
          return {'type': 'discard', 'tile': tileCode(pool[rng.nextInt(pool.length)])};
        }
        var bestT = disc.first;
        var bestScore = 1 << 20;
        for (final t in disc) {
          var v = tileValue(hands[seat], t);
          if (t == zhengJingId) v += 1000;
          if (t == fuJingId) v += 20;
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
