import '../../src/engine.dart';
import 'tiles.dart';

/// Checks whether a flipped Horse tile [tile] matches [wind] (0=East, 1=South, 2=West, 3=North)
/// in Chaoshan Mahjong (潮汕麻将奖马/买马):
/// - East (0, 东): 1, 5, 9 of m/p/s, or 1z (东), 5z (白)
/// - South (1, 南): 2, 6 of m/p/s, or 2z (南), 6z (发)
/// - West (2, 西): 3, 7 of m/p/s, or 3z (西), 7z (中)
/// - North (3, 北): 4, 8 of m/p/s, or 4z (北)
bool isChaoshanHorseMatch(Object? tile, int wind) {
  final t = tileFromCode(tile);
  if (t < 0 || t >= kKinds) return false;
  final w = ((wind % 4) + 4) % 4;
  if (t < kNumKinds) {
    final r = rankOf(t); // 1..9
    return switch (w) {
      0 => r == 1 || r == 5 || r == 9,
      1 => r == 2 || r == 6,
      2 => r == 3 || r == 7,
      _ => r == 4 || r == 8,
    };
  }
  return switch (w) {
    0 => t == kEast || t == kHaku, // 1z, 5z
    1 => t == kSouth || t == kHatsu, // 2z, 6z
    2 => t == kWest || t == kChun, // 3z, 7z
    _ => t == kNorth, // 4z
  };
}

int countChaoshanHorses(Iterable<Object?> horseTiles, int wind) {
  var matched = 0;
  for (final ht in horseTiles) {
    if (isChaoshanHorseMatch(ht, wind)) matched++;
  }
  return matched;
}

class ChaoshanResult {
  final int baseFan;
  final int fan;
  final int mult;
  final int matchedHorses;
  final int horseBonus;
  final List<String> horseTiles;
  final List<String> matchedHorseTiles;
  final bool isQiDui;
  final bool isPengPeng;
  final bool isQingYiSe;
  final bool isHunYiSe;
  final bool isBig;
  final List<(String, int)> items;

  const ChaoshanResult({
    required this.baseFan,
    required this.fan,
    required this.mult,
    required this.matchedHorses,
    required this.horseBonus,
    required this.horseTiles,
    required this.matchedHorseTiles,
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

/// Evaluates a Chaoshan Mahjong (潮汕麻将) hand (136 tiles):
/// - Standard 4 sets + 1 pair or Seven Pairs (`七对`).
/// - Each matched Horse tile (`horseTiles`) for [seatWind] adds `+1 × baseFan`!
ChaoshanResult? chaoshanEvaluate(
  List<int> concealed,
  List<Meld> melds, {
  Iterable<Object?> horseTiles = const [],
  int seatWind = 0,
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
  if (qingyise) {
    items.add(('清一色', 4));
  } else if (hunyise) {
    items.add(('混一色', 2));
  }
  if (qidui) {
    items.add(('七对', 2));
  } else if (pengpeng) {
    items.add(('碰碰胡', 2));
  }
  if (gangKai) {
    items.add(('杠上开花', 1));
  }
  if (qiangGang) {
    items.add(('抢杠胡', 1));
  }
  if (items.isEmpty) {
    items.add(('鸡胡', 1));
  }

  final baseFan = items.fold<int>(0, (a, b) => a + b.$2);

  final hCodes = <String>[];
  final matchedCodes = <String>[];
  for (final ht in horseTiles) {
    final id = tileFromCode(ht);
    if (id < 0) continue;
    final code = tileCode(id);
    hCodes.add(code);
    if (isChaoshanHorseMatch(id, seatWind)) {
      matchedCodes.add(code);
    }
  }

  final matchedHorses = matchedCodes.length;
  final horseBonus = matchedHorses * baseFan;
  if (matchedHorses > 0) {
    items.add(('中马×$matchedHorses', horseBonus));
  }
  final fan = baseFan + horseBonus;
  final mult = 1 + matchedHorses;
  final isBig = qingyise || hunyise || qidui || pengpeng || gangKai || qiangGang || matchedHorses > 0;

  return ChaoshanResult(
    baseFan: baseFan,
    fan: fan,
    mult: mult,
    matchedHorses: matchedHorses,
    horseBonus: horseBonus,
    horseTiles: hCodes,
    matchedHorseTiles: matchedCodes,
    isQiDui: qidui,
    isPengPeng: pengpeng,
    isQingYiSe: qingyise,
    isHunYiSe: hunyise,
    isBig: isBig,
    items: items,
  );
}

List<int> chaoshanWaits(List<int> concealed, List<Meld> melds) {
  final out = <int>[];
  for (var t = 0; t < kKinds && t < concealed.length; t++) {
    concealed[t]++;
    final r = chaoshanEvaluate(concealed, melds, selfDrawn: true);
    concealed[t]--;
    if (r != null) out.add(t);
  }
  return out;
}

class _CsClaim {
  final int tile;
  final int from;
  final bool rob;
  final Map<int, Set<String>> opts;
  final Map<int, ChaoshanResult> hu;
  final Map<int, Map<String, dynamic>> resp = {};
  _CsClaim(this.tile, this.from, this.rob, this.opts, {this.hu = const {}});
  List<int> get pending => [for (final s in opts.keys) if (!resp.containsKey(s)) s]..sort();
}

class _CsDiscard {
  final int tile;
  bool taken = false;
  final bool tsumogiri;
  _CsDiscard(this.tile, {this.tsumogiri = false});
}

/// 潮汕麻将 (chaoshanmj)
class ChaoshanGame extends GameEngine {
  ChaoshanGame(super.setup);

  late final int totalRounds = setup.opt<int>('rounds', 4);
  late final bool allowRon = setup.opt<bool>('allowRon', true);
  late final int horseCount = setup.opt<int>('horseCount', 4);

  late List<int> scores = List.filled(players, 0);
  int handNo = 0;
  int dealer = 0;
  bool over = false;
  List<Map<String, dynamic>> history = [];

  // Chaoshan-specific state: 奖马/买马 (horseTiles flipped upon win)
  List<int> horseTileIds = [];
  bool _presetHorses = false;
  List<String> get horseTiles => [for (final t in horseTileIds) tileCode(t)];

  void setHorseTiles(Iterable<Object> tiles) {
    horseTileIds = [
      for (final e in tiles)
        if (tileFromCode(e) >= 0) tileFromCode(e)
    ];
    _presetHorses = horseTileIds.isNotEmpty;
  }

  // Hand state
  String phase = 'act'; // act, claim, settle, over, pause
  String pausedPhase = '';
  List<List<int>> hands = [];
  List<List<Meld>> melds = [];
  List<List<_CsDiscard>> discards = [];
  List<int> drawn = [];
  List<int> wall = [];
  int turn = 0;
  bool canZimo = false;
  bool afterKong = false;
  int lastDiscardSeat = -1;
  String lastAction = '';
  Map<String, dynamic>? lastEvent;
  int eventSeq = 0;
  _CsClaim? claim;
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
    discards = List.generate(players, (_) => <_CsDiscard>[]);
    drawn = List.filled(players, -1);
    handDelta = List.filled(players, 0);
    horseTileIds = [];
    _presetHorses = false;
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
    final ronModeText = allowRon ? '可捉铳包自摸' : '仅限自摸';
    host.log('第 $handNo/$totalRounds 局开始，${name(dealer)} 坐庄（只能碰杠不能吃 · $ronModeText · 奖马${horseCount}匹）');
    lastAction = '${ronModeText} · 奖${horseCount}马 · ${name(dealer)} 出牌';
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

  ChaoshanResult? selfEval(int s) => chaoshanEvaluate(
        hands[s],
        melds[s],
        seatWind: seatWind(s),
        selfDrawn: true,
        gangKai: afterKong,
      );

  ChaoshanResult? ronEval(int o, int t, {bool rob = false}) {
    if (!allowRon) return null;
    final c = List<int>.of(hands[o]);
    c[t]++;
    return chaoshanEvaluate(
      c,
      melds[o],
      seatWind: seatWind(o),
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
    if (type == 'chi') {
      throw GameError('潮汕麻将只能碰杠，不能吃牌');
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
      if (hands[s][t] > 0) return t;
    }
    return 0;
  }

  void _discard(int s, int t) {
    hands[s][t]--;
    final giri = drawn[s] == t;
    drawn[s] = -1;
    discards[s].add(_CsDiscard(t, tsumogiri: giri));
    canZimo = false;
    afterKong = false;
    lastDiscardSeat = s;
    lastAction = '${name(s)} 打出 ${tileName(t)}';
    _event('discard', s, t);

    // 潮汕麻将：只能碰杠不能吃 (NO chi options)
    final opts = <int, Set<String>>{};
    final hu = <int, ChaoshanResult>{};
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
      claim = _CsClaim(t, s, false, opts, hu: hu);
      phase = 'claim';
    }
  }

  int _prio(String type) => switch (type) {
        'ron' || 'hu' => 30,
        'gang' || 'mgang' || 'peng' => 20,
        _ => 0,
      };

  int _maxPrio(_CsClaim c, int s) {
    var best = 0;
    for (final o in c.opts[s]!) {
      final p = _prio(o);
      if (p > best) best = p;
    }
    return best;
  }

  void _handleClaim(int s, String rawType, Map<String, dynamic> a) {
    if (!allowRon && (rawType == 'ron' || rawType == 'hu')) {
      throw GameError('当前为仅自摸模式，不能点炮胡牌');
    }
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
      // 潮汕麻将杠分即时结算：明杠 (+1 × 3)
      for (var o = 0; o < players; o++) {
        if (o == s) continue;
        _pay(o, s, 1);
        events.add({'kind': 'gang', 'subKind': 'mgang', 'from': o, 'to': s, 'amount': 1, 'why': '明杠'});
      }
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
      final hu = <int, ChaoshanResult>{};
      for (var o = 0; o < players; o++) {
        if (o == s) continue;
        final r = ronEval(o, t, rob: true);
        if (r != null) {
          opts[o] = {'ron'};
          hu[o] = r;
        }
      }
      if (opts.isNotEmpty) {
        claim = _CsClaim(t, s, true, opts, hu: hu);
        phase = 'claim';
        lastAction = '${name(s)} 补杠 ${tileName(t)}';
        _event('bugang', s, t);
        return;
      }
      _finishBuGang(s, t);
      return;
    }
    // 暗杠 (+2 × 3)
    hands[s][t] -= 4;
    melds[s].add(Meld('agang', t));
    for (var o = 0; o < players; o++) {
      if (o == s) continue;
      _pay(o, s, 2);
      events.add({'kind': 'gang', 'subKind': 'agang', 'from': o, 'to': s, 'amount': 2, 'why': '暗杠'});
    }
    lastAction = '${name(s)} 暗杠 ${tileName(t)}';
    host.log(lastAction);
    _event('gang', s, t);
    _draw(s, kong: true);
  }

  void _finishBuGang(int s, int t) {
    // 补杠 (+1 × 3)
    hands[s][t]--;
    final m = melds[s].firstWhere((m) => m.isPeng && m.tile == t);
    m.kind = 'bgang';
    for (var o = 0; o < players; o++) {
      if (o == s) continue;
      _pay(o, s, 1);
      events.add({'kind': 'gang', 'subKind': 'bgang', 'from': o, 'to': s, 'amount': 1, 'why': '补杠'});
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

  void _flipHorses() {
    if (_presetHorses && horseTileIds.isNotEmpty) return;
    horseTileIds = [];
    for (var i = 0; i < horseCount; i++) {
      if (wall.isNotEmpty) {
        horseTileIds.add(wall.removeLast());
      } else {
        horseTileIds.add(rng.nextInt(kKinds));
      }
    }
  }

  void _settleWin(Map<int, (int, ChaoshanResult)> wins, int from, {bool rob = false}) {
    final zimo = from < 0;
    _flipHorses();

    for (final e in wins.entries) {
      final w = e.key;
      final (tile, rawRes) = e.value;
      final evalHand = List<int>.of(hands[w]);
      if (!zimo) evalHand[tile]++;
      final res = chaoshanEvaluate(
            evalHand,
            melds[w],
            horseTiles: horseTileIds,
            seatWind: seatWind(w),
            selfDrawn: zimo,
            gangKai: zimo && afterKong,
            qiangGang: rob,
          ) ??
          rawRes;

      if (zimo && hands[w][tile] > 0) hands[w][tile]--;
      drawn[w] = -1;

      final share = res.fan; // baseFan * (1 + matchedHorses)
      final pay = <String, int>{};
      var totalWon = 0;
      if (zimo) {
        for (var o = 0; o < players; o++) {
          if (o == w) continue;
          _pay(o, w, share);
          pay['$o'] = share;
          totalWon += share;
        }
      } else {
        // 捉铳包自摸：点炮者包赔全三家 (×3 shares, including matched Horse bonuses!)
        final amt = share * (players - 1);
        _pay(from, w, amt);
        pay['$from'] = amt;
        totalWon = amt;
      }

      final itemsJson = res.toJson();
      if (!zimo) {
        itemsJson.add(['捉铳包自摸×3', totalWon]);
      }

      events.add({
        'kind': 'hu',
        'seat': w,
        'from': from,
        'tile': tileCode(tile),
        'zimo': zimo,
        'baoZimo': !zimo,
        'rob': rob,
        'big': res.isBig,
        'baseFan': res.baseFan,
        'fan': res.fan,
        'mult': res.mult,
        'horseTiles': horseTiles,
        'matchedHorses': res.matchedHorses,
        'matchedHorseTiles': res.matchedHorseTiles,
        'horseBonus': res.horseBonus,
        'total': totalWon,
        'items': itemsJson,
        'pay': pay,
        'hand': codesOfCounts(hands[w]),
      });
      final horseDesc = horseTiles.isEmpty
          ? ''
          : '（翻马：${[for (final ht in horseTileIds) tileName(ht)].join(' ')}，中 ${res.matchedHorses} 马）';
      host.log(zimo
          ? '${name(w)} 自摸 ${tileName(tile)}！${res.label}$horseDesc'
          : '${name(w)} 捉铳胡 ${name(from)} 的 ${tileName(tile)}（${name(from)} 包自摸×3）！${res.label}$horseDesc');
      _event(zimo ? 'zimo' : 'hu', w, tile);
    }
    lastAction = zimo ? '${name(wins.keys.first)} 自摸' : '${wins.keys.map(name).join('、')} 捉铳胡（${name(from)}包三家）';
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
      'allowRon': allowRon,
      'horseCount': horseCount,
      'horseTiles': horseTiles,
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
      'rule': 'chaoshanmj',
      'phase': phase == 'pause' ? 'claim' : phase,
      'hand': handNo,
      'hands': totalRounds,
      'rounds': totalRounds,
      'dealer': dealer,
      'turn': turn,
      'wall': wall.length,
      'allowRon': allowRon,
      'horseCount': horseCount,
      'horseTiles': horseTiles,
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
      }
      final n = countTotal(hands[seat]);
      if (n % 3 == 1 && (phase == 'act' || phase == 'claim' || phase == 'pause')) {
        my['waits'] = [for (final t in chaoshanWaits(hands[seat], melds[seat])) tileCode(t)];
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
        if (botLevel == 0 && rng.nextDouble() < 0.3) {
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
        if (o.contains('peng') && (hands[seat][c.tile] >= 3 || rng.nextDouble() < 0.6)) {
          return {'type': 'peng'};
        }
        return {'type': 'pass'};
      case 'settle':
        return ready.contains(seat) ? null : {'type': 'next'};
    }
    return null;
  }
}
