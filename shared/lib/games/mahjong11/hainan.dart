import '../../src/engine.dart';
import 'tiles.dart';

class HainanResult {
  final int baseFan;
  final int fan;
  final int mult;
  final bool hasFan; // 是否满足海南有番条件
  final int lingPaiCount; // 令牌数（中/发/白刻杠 或 圈风/门风刻杠）
  final bool isMenQing; // 门清（0明副露）
  final bool isPingHuQuanShun; // 平胡全顺（4顺子 + 非字牌将）
  final bool isDuiDui; // 对对胡
  final bool isHunYiSe; // 混一色
  final bool isQingYiSe; // 清一色
  final bool isQiDui; // 七对
  final bool isGangKai; // 杠上开花
  final bool isBig;
  final List<(String, int)> items;

  const HainanResult({
    required this.baseFan,
    required this.fan,
    required this.mult,
    required this.hasFan,
    required this.lingPaiCount,
    required this.isMenQing,
    required this.isPingHuQuanShun,
    required this.isDuiDui,
    required this.isHunYiSe,
    required this.isQingYiSe,
    required this.isQiDui,
    required this.isGangKai,
    required this.isBig,
    required this.items,
  });

  bool get hasLingPai => lingPaiCount > 0;
  bool get isPengPeng => isDuiDui;
  String get label => [for (final (n, _) in items) n].join(' ');
  List<List<Object>> toJson() => [for (final (n, f) in items) [n, f]];
}

/// Evaluates a Hainan Mahjong (海南麻将) hand (136 tiles):
/// - When [requireFan] is true (**有番起胡**), a complete hand may win ONLY IF it has at least 1 valid Hainan Fan:
///   1. **令牌**: Dragon triplet/quad (`5z..7z`) or Seat/Round Wind triplet/quad (`1z..4z`),
///   2. **门清**: 0 exposed melds (`melds.every((m) => m.concealed)`),
///   3. **平胡全顺**: 4 sequences + non-Honor pair (`isPingHuQuanShun(concealed, melds)`),
///   4. **对对胡**, **混一色**, **清一色**, **七对**, or **杠上开花** ([gangKai]).
HainanResult? hainanEvaluate(
  List<int> concealed,
  List<Meld> melds, {
  int seatWind = 0, // 0=东(1z), 1=南(2z), 2=西(3z), 3=北(4z)
  int roundWind = 0, // 0=东(1z), 1=南(2z), 2=西(3z), 3=北(4z)
  bool requireFan = true,
  bool selfDrawn = false,
  bool gangKai = false,
  bool qiangGang = false,
}) {
  final total = countTotal(concealed);
  final needSets = 4 - melds.length;
  if (needSets < 0 || total != needSets * 3 + 2) return null;

  final stdWin = isStandardWin(concealed);
  final qidui = melds.isEmpty && isSevenPairs(concealed);
  if (!stdWin && !qidui) return null;

  final menqing = melds.every((m) => m.concealed);
  final pingHuQuanShun = stdWin && isPingHuQuanShun(concealed, melds);
  final duidui = stdWin && melds.every((m) => !m.isChi) && isAllPungs(concealed);

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

  final qingyise = !hasHonor && suits.length <= 1;
  final hunyise = hasHonor && suits.length == 1;

  // Check 令牌: Dragon triplet/quad (5z..7z) or Seat/Round Wind triplet/quad (1z..4z)
  final seatWindTile = kEast + (seatWind % 4);
  final roundWindTile = kEast + (roundWind % 4);
  var lingPaiCount = 0;
  final lingItems = <(String, int)>[];
  final countedHonors = <int>{};

  void addHonorTriplet(int t) {
    if (isDragon(t)) {
      lingPaiCount++;
      lingItems.add(('令牌(${tileName(t)}刻)', 1));
    } else if (t == seatWindTile && t == roundWindTile) {
      lingPaiCount += 2;
      lingItems.add(('双令牌(${tileName(t)}风刻)', 2));
    } else if (t == seatWindTile) {
      lingPaiCount++;
      lingItems.add(('门风令牌(${tileName(t)}刻)', 1));
    } else if (t == roundWindTile) {
      lingPaiCount++;
      lingItems.add(('圈风令牌(${tileName(t)}刻)', 1));
    }
  }

  for (final m in melds) {
    if (m.isChi) continue;
    if (isHonor(m.tile) && countedHonors.add(m.tile)) {
      addHonorTriplet(m.tile);
    }
  }
  if (stdWin) {
    for (var t = kEast; t < kKinds && t < concealed.length; t++) {
      if (concealed[t] >= 3 && countedHonors.add(t)) {
        addHonorTriplet(t);
      }
    }
  }

  final hasFan = lingPaiCount > 0 ||
      menqing ||
      pingHuQuanShun ||
      duidui ||
      hunyise ||
      qingyise ||
      qidui ||
      gangKai ||
      qiangGang;

  if (requireFan && !hasFan) return null;

  final items = <(String, int)>[];
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
  } else if (duidui) {
    items.add(('对对胡', 2));
    mult *= 2;
  }
  if (pingHuQuanShun) {
    items.add(('平胡全顺', 1));
  }
  if (menqing) {
    items.add(('门清', 1));
  }
  items.addAll(lingItems);
  if (gangKai) {
    items.add(('杠上开花', 2));
  }
  if (qiangGang) {
    items.add(('抢杠胡', 1));
  }
  if (items.isEmpty) {
    items.add(('无番平胡', 1));
  }
  if (selfDrawn) {
    items.add(('自摸', 1));
  }

  final fan = items.fold<int>(0, (a, b) => a + b.$2);
  final isBig = qingyise || hunyise || qidui || duidui || gangKai || lingPaiCount >= 2;

  return HainanResult(
    baseFan: fan,
    fan: fan,
    mult: mult,
    hasFan: hasFan,
    lingPaiCount: lingPaiCount,
    isMenQing: menqing,
    isPingHuQuanShun: pingHuQuanShun,
    isDuiDui: duidui,
    isHunYiSe: hunyise,
    isQingYiSe: qingyise,
    isQiDui: qidui,
    isGangKai: gangKai,
    isBig: isBig,
    items: items,
  );
}

List<int> hainanWaits(
  List<int> concealed,
  List<Meld> melds, {
  int seatWind = 0,
  int roundWind = 0,
  bool requireFan = true,
}) {
  final out = <int>[];
  for (var t = 0; t < kKinds && t < concealed.length; t++) {
    concealed[t]++;
    final r = hainanEvaluate(
      concealed,
      melds,
      seatWind: seatWind,
      roundWind: roundWind,
      requireFan: requireFan,
      selfDrawn: true,
    );
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
  final Map<int, List<int>> chis;
  final Map<int, HainanResult> hu;
  final Map<int, Map<String, dynamic>> resp = {};
  _HnClaim(this.tile, this.from, this.rob, this.opts, {this.chis = const {}, this.hu = const {}});
  List<int> get pending => [for (final s in opts.keys) if (!resp.containsKey(s)) s]..sort();
}

class _HnDiscard {
  final int tile;
  bool taken = false;
  final bool tsumogiri;
  _HnDiscard(this.tile, {this.tsumogiri = false});
}

/// 海南麻将 (hainanmj)
class HainanGame extends GameEngine {
  HainanGame(super.setup);

  late final int totalRounds = setup.opt<int>('rounds', 4);
  late final bool requireFan = setup.opt<bool>('requireFan', true);

  late List<int> scores = List.filled(players, 0);
  int handNo = 0;
  int dealer = 0;
  int roundWind = 0; // 0=东, 1=南, 2=西, 3=北
  bool over = false;
  List<Map<String, dynamic>> history = [];

  // Hainan-specific state:
  // 1. 上噶 / 噶码阶段 (gama[seat] in 0..3, adds +(gama[winner] + gama[loser]) to win settlements)
  // 2. 有番起胡 (requireFan)
  // 3. 首圈跟庄 (genzhuang: first 4 discards identical with 0 melds claimed -> dealer pays +2 to each non-dealer)
  late List<int> gama = List.filled(players, 0);
  Set<int> gamaDone = {};
  List<String> discardHistory = [];
  bool genzhuang = false;
  bool _anyMeldClaimed = false;

  // Hand state
  String phase = 'gama'; // gama, act, claim, settle, over, pause
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
    roundWind = 0;
    _startHand();
  }

  void _startHand() {
    handNo++;
    wall = <int>[for (var t = 0; t < kKinds; t++) for (var k = 0; k < 4; k++) t]..shuffle(rng);
    hands = List.generate(players, (_) => List.filled(kKinds, 0));
    melds = List.generate(players, (_) => <Meld>[]);
    discards = List.generate(players, (_) => <_HnDiscard>[]);
    gama = List.filled(players, 0);
    gamaDone = {};
    discardHistory = [];
    genzhuang = false;
    _anyMeldClaimed = false;
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
    phase = 'gama';
    canZimo = true;
    final fanTag = requireFan ? '有番起胡' : '可无番平胡';
    host.log('第 $handNo/$totalRounds 局开始，${name(dealer)} 坐庄（$fanTag · 首圈跟庄 · 请选择上噶 0~3）');
    lastAction = '请选择上噶（0~3噶）';
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

  HainanResult? selfEval(int s) => hainanEvaluate(
        hands[s],
        melds[s],
        seatWind: seatWind(s),
        roundWind: roundWind,
        requireFan: requireFan,
        selfDrawn: true,
        gangKai: afterKong,
      );

  HainanResult? ronEval(int o, int t, {bool rob = false}) {
    final c = List<int>.of(hands[o]);
    c[t]++;
    return hainanEvaluate(
      c,
      melds[o],
      seatWind: seatWind(o),
      roundWind: roundWind,
      requireFan: requireFan,
      selfDrawn: false,
      qiangGang: rob,
    );
  }

  bool get canSelfHu => (phase == 'act' || phase == 'gama') && canZimo && selfEval(turn) != null;

  List<(int, bool)> selfKongs() {
    if ((phase != 'act' && phase != 'gama') || wall.isEmpty) return const [];
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
  int get botDelayMs => phase == 'claim' || phase == 'gama' ? 450 : 700;

  @override
  List<int> get waitingFor {
    switch (phase) {
      case 'gama':
        return [for (var s = 0; s < players; s++) if (!gamaDone.contains(s)) s];
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
      case 'gama':
        if (type == 'gama') {
          if (gamaDone.contains(seat)) throw GameError('你已经选过上噶了');
          final s = asInt(a['score'] ?? a['gama'] ?? a['count'], -1);
          if (s < 0 || s > 3) throw GameError('上噶必须在 0~3 之间');
          gama[seat] = s;
          gamaDone.add(seat);
          host.log('${name(seat)} 选择${s == 0 ? "不噶(0)" : "上$s噶"}');
          if (gamaDone.length >= players) {
            phase = 'act';
            turn = dealer;
            canZimo = true;
            lastAction = '${name(dealer)} 出牌';
          }
          return;
        }
        // Allow direct play actions in unit tests if gama was skipped
        if (seat == turn &&
            (type == 'discard' ||
                type == 'tsumo' ||
                type == 'hu' ||
                type == 'gang' ||
                type == 'agang' ||
                type == 'bgang')) {
          for (var i = 0; i < players; i++) {
            gamaDone.add(i);
          }
          phase = 'act';
          _handleAct(seat, type, a);
          return;
        }
        throw GameError('请先选择本局上噶（0~3 噶）');
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
      if (r == null) throw GameError('现在不能自摸胡牌（有番起胡需满足至少1番）');
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
      if (hands[s][t] > 0) return t;
    }
    return 0;
  }

  void _discard(int s, int t) {
    hands[s][t]--;
    final giri = drawn[s] == t;
    drawn[s] = -1;
    discards[s].add(_HnDiscard(t, tsumogiri: giri));
    discardHistory.add(tileCode(t));
    canZimo = false;
    afterKong = false;
    lastDiscardSeat = s;
    lastAction = '${name(s)} 打出 ${tileName(t)}';
    _event('discard', s, t);

    // Check 首圈跟庄 (genzhuang):
    // In the very first 4 discards of the hand (discardHistory.length == 4, with 0 melds claimed),
    // if all 3 non-dealers discard the EXACT SAME tile as the dealer's first discard,
    // dealer immediately pays +2 points to each of the 3 non-dealers!
    if (!genzhuang &&
        !_anyMeldClaimed &&
        discardHistory.length == 4 &&
        melds.every((ms) => ms.isEmpty)) {
      final firstCode = discardHistory.first;
      if (discardHistory.every((c) => c == firstCode)) {
        genzhuang = true;
        for (var o = 0; o < players; o++) {
          if (o == dealer) continue;
          _pay(dealer, o, 2);
          events.add({
            'kind': 'genzhuang',
            'from': dealer,
            'to': o,
            'amount': 2,
            'tile': firstCode,
            'why': '首圈跟庄',
          });
        }
        lastAction = '首圈跟庄成功（${tileName(t)}）！庄家 ${name(dealer)} 向三家各赔 2 分';
        host.log('首圈跟庄成功！四家连打 ${tileName(t)}，庄家 ${name(dealer)} 向三家各赔 2 分！');
      }
    }

    final opts = <int, Set<String>>{};
    final chis = <int, List<int>>{};
    final hu = <int, HainanResult>{};
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
      claim = _HnClaim(t, s, false, opts, chis: chis, hu: hu);
      phase = 'claim';
    }
  }

  int _prio(String type) => switch (type) {
        'ron' || 'hu' => 30,
        'gang' || 'mgang' || 'peng' => 20,
        'chi' => 10,
        _ => 0,
      };

  int _maxPrio(_HnClaim c, int s) {
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
    _anyMeldClaimed = true;
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
    _anyMeldClaimed = true;
    if (bu) {
      final opts = <int, Set<String>>{};
      final hu = <int, HainanResult>{};
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

  void _settleWin(Map<int, (int, HainanResult)> wins, int from, {bool rob = false}) {
    final zimo = from < 0;
    for (final e in wins.entries) {
      final w = e.key;
      final (tile, res) = e.value;
      if (zimo && hands[w][tile] > 0) hands[w][tile]--;
      drawn[w] = -1;

      final payers = zimo ? [for (var o = 0; o < players; o++) if (o != w) o] : [from];
      final pay = <String, int>{};
      final gamaPay = <String, int>{};
      var totalWon = 0;
      for (final p in payers) {
        final baseAmt = res.fan;
        final gamaBonus = gama[w] + gama[p];
        final amt = baseAmt + gamaBonus;
        _pay(p, w, amt);
        pay['$p'] = amt;
        gamaPay['$p'] = gamaBonus;
        totalWon += amt;
      }

      final itemsJson = res.toJson();
      if (gama[w] > 0) {
        itemsJson.add(['赢家上${gama[w]}噶', gama[w]]);
      }

      events.add({
        'kind': 'hu',
        'seat': w,
        'from': from,
        'tile': tileCode(tile),
        'zimo': zimo,
        'rob': rob,
        'big': res.isBig,
        'hasFan': res.hasFan,
        'lingPaiCount': res.lingPaiCount,
        'isMenQing': res.isMenQing,
        'isPingHuQuanShun': res.isPingHuQuanShun,
        'gama': List.of(gama),
        'gamaPay': gamaPay,
        'baseFan': res.baseFan,
        'fan': res.fan,
        'mult': res.mult,
        'total': totalWon,
        'items': itemsJson,
        'pay': pay,
        'hand': codesOfCounts(hands[w]),
      });
      host.log(zimo
          ? '${name(w)} 自摸 ${tileName(tile)}！${res.label}（上噶+${gama[w]}）'
          : '${name(w)} 胡 ${name(from)} 的 ${tileName(tile)}！${res.label}（上噶+${gama[w] + gama[from]}）');
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
      'requireFan': requireFan,
      'gama': List.of(gama),
      'genzhuang': genzhuang,
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
      final hasDrawn = (phase == 'act' || phase == 'gama') && turn == s && drawn[s] >= 0 && hands[s][drawn[s]] > 0;
      seats.add({
        'count': n,
        'drawn': hasDrawn,
        'hand': s == seat || reveal ? codesOfCounts(hands[s]) : null,
        'melds': [for (final m in melds[s]) m.toJson(hide: m.concealed && s != seat && !reveal)],
        'gama': gamaDone.contains(s) ? gama[s] : null,
        'gamaDone': gamaDone.contains(s),
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
      'rule': 'hainanmj',
      'phase': phase == 'pause' ? 'claim' : phase,
      'hand': handNo,
      'hands': totalRounds,
      'rounds': totalRounds,
      'dealer': dealer,
      'roundWind': roundWind,
      'turn': turn,
      'wall': wall.length,
      'requireFan': requireFan,
      'gama': List.of(gama),
      'genzhuang': genzhuang,
      'discardHistory': List.of(discardHistory),
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
        'drawn': (phase == 'act' || phase == 'gama') && turn == seat && drawn[seat] >= 0 && hands[seat][drawn[seat]] > 0
            ? tileCode(drawn[seat])
            : null,
        'canGama': phase == 'gama' && !gamaDone.contains(seat),
        'gama': gama[seat],
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
          for (final t in hainanWaits(
            hands[seat],
            melds[seat],
            seatWind: seatWind(seat),
            roundWind: roundWind,
            requireFan: requireFan,
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
      case 'gama':
        if (gamaDone.contains(seat)) return null;
        var pairsOrTrips = 0;
        for (var t = 0; t < kKinds; t++) {
          if (hands[seat][t] >= 2) pairsOrTrips++;
        }
        final gScore = pairsOrTrips >= 4 ? 3 : (pairsOrTrips >= 3 ? 2 : (pairsOrTrips >= 2 ? 1 : 0));
        return {'type': 'gama', 'score': gScore};
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
          final isLing = isDragon(t) || t == kEast + seatWind(seat) || t == kEast + roundWind;
          final sc = tileValue(hands[seat], t, preferHonors: isLing);
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
        final isLing = isDragon(c.tile) || c.tile == kEast + seatWind(seat) || c.tile == kEast + roundWind;
        if (o.contains('peng') && (isLing || hands[seat][c.tile] >= 3 || rng.nextDouble() < 0.45)) {
          return {'type': 'peng'};
        }
        if (o.contains('chi') && rng.nextDouble() < 0.35) {
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
