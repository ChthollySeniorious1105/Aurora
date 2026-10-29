import '../../src/engine.dart';
import 'tiles.dart';

/// Validates whether [tiles] (length 3) forms a valid Qingdao Mahjong 扭牌 (`niupai`):
/// - `'dragon'` (亮箭): `{5z, 6z, 7z}` (中发白)
/// - `'wind'` (亮风): any 3 distinct winds from `{1z, 2z, 3z, 4z}` (e.g. `1z+2z+3z`)
/// Returns `'dragon'` or `'wind'`, or `null` if invalid.
String? classifyNiupai(Iterable<Object?> tiles) {
  final ids = <int>[];
  for (final e in tiles) {
    final id = tileFromCode(e);
    if (id < 0) return null;
    ids.add(id);
  }
  if (ids.length != 3) return null;
  final set = ids.toSet();
  if (set.length != 3) return null;
  if (set.containsAll(const [kHaku, kHatsu, kChun])) return 'dragon';
  if (set.every(isWind)) return 'wind';
  return null;
}

class QingdaoResult {
  final int baseFan;
  final int fan;
  final int mult;
  final int niupaiCount; // 扭牌副露数 (+1 番/组)
  final bool has258Pair; // 是否满足 258 作将
  final bool bypass258; // 七对 / 清一色 / 对对胡 免 258 将限制
  final bool isQiDui; // 七对
  final bool isDuiDui; // 对对胡
  final bool isQingYiSe; // 清一色
  final bool isHunYiSe; // 混一色
  final bool isBig;
  final List<(String, int)> items;

  const QingdaoResult({
    required this.baseFan,
    required this.fan,
    required this.mult,
    required this.niupaiCount,
    required this.has258Pair,
    required this.bypass258,
    required this.isQiDui,
    required this.isDuiDui,
    required this.isQingYiSe,
    required this.isHunYiSe,
    required this.isBig,
    required this.items,
  });

  bool get isPengPeng => isDuiDui;
  String get label => [for (final (n, _) in items) n].join(' ');
  List<List<Object>> toJson() => [for (final (n, f) in items) [n, f]];
}

/// Evaluates a Qingdao Mahjong (青岛麻将) hand (136 tiles):
/// - [hunTile] (flipped from `hunIndicator` -> next cyclic tile) is the universal wildcard (**混儿**).
/// - **258将 ([strict258])**: When [strict258] is true, standard 4-meld + 1-pair hands require the pair
///   to be a `2, 5, or 8` of `m, p, or s` (or formed with [hunTile] wildcard).
///   Seven Pairs (`七对`), Pure One Suit (`清一色`), and All Triplets (`对对胡`) bypass the 258-pair requirement!
/// - **扭牌 (`niupai`)**: Each exposed `niupai` meld (`5z+6z+7z` or 3 distinct winds `1z..4z`) adds `+1` fan!
QingdaoResult? qingdaoEvaluate(
  List<int> concealed,
  List<Meld> melds, {
  Object? hunTile = -1,
  bool strict258 = true,
  bool selfDrawn = false,
  bool gangKai = false,
  bool qiangGang = false,
}) {
  final total = countTotal(concealed);
  final needSets = 4 - melds.length;
  if (needSets < 0 || total != needSets * 3 + 2) return null;

  final hunId = tileFromCode(hunTile);
  final wild = (hunId >= 0 && hunId < concealed.length) ? concealed[hunId] : 0;

  final c = List<int>.of(concealed);
  if (hunId >= 0 && hunId < c.length) {
    c[hunId] = 0;
  }

  final pureStd258 = isStandardWin258(concealed);
  final pureStdAny = isStandardWin(concealed);
  final pureQidui = melds.isEmpty && isSevenPairs(concealed);

  final std258 = pureStd258 || (wild > 0 && can258PairStandardWild(c, wild));
  final stdAny = pureStdAny || std258 || (wild > 0 && canAnyPairStandardWild(c, wild));
  final qidui = pureQidui || (melds.isEmpty && wild > 0 && canSevenPairsWild(c, wild));

  if (!stdAny && !qidui) return null;

  final duidui = stdAny &&
      melds.every((m) => !m.isChi && !m.isNiupai) &&
      (isAllPungs(concealed) || (wild > 0 && canPengPengWild(c, wild)));

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

  final qingyise = !hasHonor && suits.length <= 1;
  final hunyise = hasHonor && suits.length == 1;

  // 七对、清一色、对对胡免 258 将限制；普通手在 strict258 开启时必须 258 作将！
  final bypass258 = !strict258 || qidui || qingyise || duidui;
  if (!qidui && !bypass258 && !std258) {
    return null;
  }

  final niupaiCount = melds.where((m) => m.isNiupai).length;
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
  if (gangKai) {
    items.add(('杠上开花', 1));
  }
  if (qiangGang) {
    items.add(('抢杠胡', 1));
  }
  if (items.isEmpty) {
    items.add((strict258 && std258 ? '平胡(258将)' : '平胡', 1));
  }
  if (selfDrawn) {
    items.add(('自摸', 1));
  }

  final baseFan = items.fold<int>(0, (a, b) => a + b.$2);
  if (niupaiCount > 0) {
    items.add(('扭牌×$niupaiCount', niupaiCount));
  }
  final fan = baseFan + niupaiCount;
  final isBig = qingyise || hunyise || qidui || duidui || gangKai || qiangGang || niupaiCount > 0;

  return QingdaoResult(
    baseFan: baseFan,
    fan: fan,
    mult: mult,
    niupaiCount: niupaiCount,
    has258Pair: std258,
    bypass258: bypass258,
    isQiDui: qidui,
    isDuiDui: duidui,
    isQingYiSe: qingyise,
    isHunYiSe: hunyise,
    isBig: isBig,
    items: items,
  );
}

List<int> qingdaoWaits(
  List<int> concealed,
  List<Meld> melds, {
  Object? hunTile = -1,
  bool strict258 = true,
}) {
  final out = <int>[];
  for (var t = 0; t < kKinds && t < concealed.length; t++) {
    concealed[t]++;
    final r = qingdaoEvaluate(concealed, melds, hunTile: hunTile, strict258: strict258, selfDrawn: true);
    concealed[t]--;
    if (r != null) out.add(t);
  }
  return out;
}

class _QdClaim {
  final int tile;
  final int from;
  final bool rob;
  final Map<int, Set<String>> opts;
  final Map<int, List<int>> chis;
  final Map<int, QingdaoResult> hu;
  final Map<int, Map<String, dynamic>> resp = {};
  _QdClaim(this.tile, this.from, this.rob, this.opts, {this.chis = const {}, this.hu = const {}});
  List<int> get pending => [for (final s in opts.keys) if (!resp.containsKey(s)) s]..sort();
}

class _QdDiscard {
  final int tile;
  bool taken = false;
  final bool tsumogiri;
  _QdDiscard(this.tile, {this.tsumogiri = false});
}

/// 青岛麻将 (qingdaomj)
class QingdaoGame extends GameEngine {
  QingdaoGame(super.setup);

  late final int totalRounds = setup.opt<int>('rounds', 4);
  late final bool strict258 = setup.opt<bool>('strict258', true);

  late List<int> scores = List.filled(players, 0);
  int handNo = 0;
  int dealer = 0;
  bool over = false;
  List<Map<String, dynamic>> history = [];

  // Qingdao-specific state:
  // 1. 翻混儿 (hunIndicator -> hunTile universal wildcard)
  // 2. 258将 (strict258)
  // 3. 扭牌 ('niupai' — 亮风 1z..4z / 亮箭 5z+6z+7z)
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
  String phase = 'act'; // act, claim, settle, over, pause
  String pausedPhase = '';
  List<List<int>> hands = [];
  List<List<Meld>> melds = [];
  List<List<_QdDiscard>> discards = [];
  List<int> drawn = [];
  List<int> wall = [];
  int turn = 0;
  bool canZimo = false;
  bool afterKong = false;
  int lastDiscardSeat = -1;
  String lastAction = '';
  Map<String, dynamic>? lastEvent;
  int eventSeq = 0;
  _QdClaim? claim;
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
    discards = List.generate(players, (_) => <_QdDiscard>[]);
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
    phase = 'act';
    canZimo = true;
    final ruleTag = strict258 ? '严格258将' : '任意将';
    host.log('第 $handNo/$totalRounds 局开始，${name(dealer)} 坐庄，翻出 ${tileName(hunIndicatorId)}，本局混儿：${tileName(hunTileId)}（$ruleTag · 扭牌亮风亮箭）');
    lastAction = '混儿：${tileName(hunTileId)} · ${name(dealer)} 出牌';
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

  QingdaoResult? selfEval(int s) => qingdaoEvaluate(
        hands[s],
        melds[s],
        hunTile: hunTileId,
        strict258: strict258,
        selfDrawn: true,
        gangKai: afterKong,
      );

  QingdaoResult? ronEval(int o, int t, {bool rob = false}) {
    final c = List<int>.of(hands[o]);
    c[t]++;
    return qingdaoEvaluate(
      c,
      melds[o],
      hunTile: hunTileId,
      strict258: strict258,
      selfDrawn: false,
      qiangGang: rob,
    );
  }

  bool get canSelfHu => phase == 'act' && canZimo && selfEval(turn) != null;

  /// Returns candidate 3-tile 扭牌 (`niupai`) combinations in [s]'s hand:
  /// - `['5z', '6z', '7z']` (亮箭：中发白)
  /// - Any 3 distinct winds from `1z..4z` (亮风：东南西北任三张)
  List<List<String>> selfNiupais([int? s]) {
    final seat = s ?? turn;
    if (phase != 'act' || seat != turn || melds[seat].length >= 4) return const [];
    final h = hands[seat];
    final out = <List<String>>[];
    if (h[kHaku] > 0 && h[kHatsu] > 0 && h[kChun] > 0) {
      out.add(const ['5z', '6z', '7z']);
    }
    final winds = [for (final t in const [kEast, kSouth, kWest, kNorth]) if (h[t] > 0) t];
    if (winds.length >= 3) {
      out.add([for (final t in winds.take(3)) tileCode(t)]);
    }
    return out;
  }

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
      if (r == null) throw GameError('现在不能自摸胡牌（普通胡牌需满足258作将）');
      final t = drawn[s] >= 0 && hands[s][drawn[s]] > 0 ? drawn[s] : _anyTile(s);
      _settleWin({s: (t, r)}, -1);
      return;
    }
    if (type == 'niupai') {
      final rawTiles = a['tiles'];
      List<int> tileIds;
      if (rawTiles is List && rawTiles.isNotEmpty) {
        tileIds = [for (final e in rawTiles) tileFromCode(e)];
      } else {
        final cands = selfNiupais(s);
        if (cands.isEmpty) throw GameError('手中没有可亮出的扭牌组合（需中发白5z/6z/7z或任意3张不同风牌1z..4z）');
        tileIds = [for (final c in cands.first) tileFromCode(c)];
      }
      _declareNiupai(s, tileIds);
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

  void _declareNiupai(int s, List<int> tileIds) {
    if (melds[s].length >= 4) throw GameError('副露已满 4 组，不能再扭牌');
    final subKind = classifyNiupai(tileIds);
    if (subKind == null) {
      throw GameError('无效的扭牌组合（需亮箭5z+6z+7z或亮风1z..4z任意3张不同风牌）');
    }
    final needed = countsOf(tileIds);
    for (var t = 0; t < kKinds; t++) {
      if (needed[t] > hands[s][t]) {
        throw GameError('手中没有足够的牌亮出该组扭牌');
      }
    }
    for (final t in tileIds) {
      hands[s][t]--;
    }
    melds[s].add(Meld('niupai', tileIds.first, customTiles: List.of(tileIds), subKind: subKind));
    final niuLabel = subKind == 'dragon' ? '亮箭（中发白）' : '亮风';
    for (var o = 0; o < players; o++) {
      if (o == s) continue;
      _pay(o, s, 2);
      events.add({
        'kind': 'niupai',
        'subKind': subKind,
        'tiles': [for (final t in tileIds) tileCode(t)],
        'from': o,
        'to': s,
        'amount': 2,
        'why': niuLabel,
      });
    }
    lastAction = '${name(s)} 扭牌：$niuLabel（${[for (final t in tileIds) tileName(t)].join('')}）';
    host.log(lastAction);
    _event('gang', s, tileIds.first);

    final needSets = 4 - melds[s].length;
    final targetOnTurn = needSets * 3 + 2;
    final curTotal = countTotal(hands[s]);
    if (curTotal < targetOnTurn && wall.isNotEmpty) {
      _draw(s, kong: true);
    } else {
      drawn[s] = _anyTile(s);
      turn = s;
      phase = 'act';
      canZimo = true;
    }
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
    discards[s].add(_QdDiscard(t, tsumogiri: giri));
    canZimo = false;
    afterKong = false;
    lastDiscardSeat = s;
    lastAction = '${name(s)} 打出 ${tileName(t)}';
    _event('discard', s, t);

    final opts = <int, Set<String>>{};
    final chis = <int, List<int>>{};
    final hu = <int, QingdaoResult>{};
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
      claim = _QdClaim(t, s, false, opts, chis: chis, hu: hu);
      phase = 'claim';
    }
  }

  int _prio(String type) => switch (type) {
        'ron' || 'hu' => 30,
        'gang' || 'mgang' || 'peng' => 20,
        'chi' => 10,
        _ => 0,
      };

  int _maxPrio(_QdClaim c, int s) {
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
      final hu = <int, QingdaoResult>{};
      for (var o = 0; o < players; o++) {
        if (o == s) continue;
        final r = ronEval(o, t, rob: true);
        if (r != null) {
          opts[o] = {'ron'};
          hu[o] = r;
        }
      }
      if (opts.isNotEmpty) {
        claim = _QdClaim(t, s, true, opts, hu: hu);
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

  void _settleWin(Map<int, (int, QingdaoResult)> wins, int from, {bool rob = false}) {
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
        final amt = res.fan * (zimo ? 2 : 1);
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
        'niupaiCount': res.niupaiCount,
        'has258Pair': res.has258Pair,
        'bypass258': res.bypass258,
        'hunTile': hunTile,
        'baseFan': res.baseFan,
        'fan': res.fan,
        'mult': res.mult,
        'total': totalWon,
        'items': res.toJson(),
        'pay': pay,
        'hand': codesOfCounts(hands[w]),
      });
      host.log(zimo
          ? '${name(w)} 自摸 ${tileName(tile)}！${res.label}'
          : '${name(w)} 胡 ${name(from)} 的 ${tileName(tile)}！${res.label}');
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
      'strict258': strict258,
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
        'niupais': melds[s].where((m) => m.isNiupai).length,
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
      'rule': 'qingdaomj',
      'phase': phase == 'pause' ? 'claim' : phase,
      'hand': handNo,
      'hands': totalRounds,
      'rounds': totalRounds,
      'dealer': dealer,
      'turn': turn,
      'wall': wall.length,
      'hunIndicator': hunIndicator,
      'hunTile': hunTile,
      'strict258': strict258,
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
        final nps = selfNiupais(seat);
        my['canHu'] = ev != null;
        my['canTsumo'] = ev != null;
        my['niupais'] = nps;
        my['canNiupai'] = nps.isNotEmpty;
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
          for (final t in qingdaoWaits(hands[seat], melds[seat], hunTile: hunTileId, strict258: strict258)) tileCode(t)
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
        final nps = selfNiupais(seat);
        if (nps.isNotEmpty && rng.nextDouble() < 0.7) {
          return {'type': 'niupai', 'tiles': nps.first};
        }
        final ks = selfKongs().where((e) => e.$1 != hunTileId).toList();
        if (ks.isNotEmpty) return {'type': 'gang', 'tile': tileCode(ks.first.$1)};
        final legals = legalDiscards(seat);
        final nonHun = [for (final t in legals) if (t != hunTileId) t];
        final pool = nonHun.isNotEmpty ? nonHun : legals;
        if (botLevel == 0 && rng.nextDouble() < 0.3) {
          return {'type': 'discard', 'tile': tileCode(pool[rng.nextInt(pool.length)])};
        }
        var best = pool.first, bestScore = 1 << 20;
        for (final t in pool) {
          final sc = tileValue(hands[seat], t, prefer258: strict258);
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
        if (c.tile != hunTileId) {
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
