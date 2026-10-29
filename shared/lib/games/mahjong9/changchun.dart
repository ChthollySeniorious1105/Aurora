import '../../src/engine.dart';
import 'tiles.dart';

class ChangchunResult {
  final int baseFan;
  final int fan;
  final int mult;
  final bool hasBao; // 摸宝 或 抱宝 (+2 番)
  final bool isMoBao; // 摸宝 (+2 番)
  final bool isBaoBao; // 抱宝 (+2 番)
  final int eggCount; // 下蛋副露数
  final bool isQiDui; // 七对 ×2
  final bool isPiaoHu; // 飘胡（对对胡）×2
  final bool isQingYiSe; // 清一色 ×4
  final bool isHunYiSe; // 混一色 ×2
  final bool isBig;
  final List<(String, int)> items;

  const ChangchunResult({
    required this.baseFan,
    required this.fan,
    required this.mult,
    required this.hasBao,
    required this.isMoBao,
    required this.isBaoBao,
    required this.eggCount,
    required this.isQiDui,
    required this.isPiaoHu,
    required this.isQingYiSe,
    required this.isHunYiSe,
    required this.isBig,
    required this.items,
  });

  String get label => [for (final (n, _) in items) n].join(' ');
  List<List<Object>> toJson() => [for (final (n, f) in items) [n, f]];
}

/// Validates whether [tileIds] (length 3 or 4) forms a valid Changchun Mahjong Egg (`下蛋`):
/// - `'dragon'` (喜蛋): `{5z, 6z, 7z}`
/// - `'wind'` (风蛋): 3 or 4 distinct winds from `{1z, 2z, 3z, 4z}`
/// - `'yao'` (幺蛋): `{1m, 1p, 1s}`
/// - `'jiu'` (九蛋): `{9m, 9p, 9s}`
/// When [feidan] is true (**小鸡飞蛋**), `1s` (`kYaoJi = 18`) may substitute for a missing tile in any Egg!
/// Returns the egg subKind (`'dragon'`, `'wind'`, `'yao'`, `'jiu'`), or `null` if invalid.
String? classifyXiadan(List<int> tileIds, {bool feidan = true}) {
  if (tileIds.length < 3 || tileIds.length > 4) return null;

  bool checkGroup(Set<int> group, {int minLen = 3, int maxLen = 3}) {
    if (tileIds.length < minLen || tileIds.length > maxLen) return false;
    final seen = <int>{};
    var naturalFromGroup = 0;
    for (final t in tileIds) {
      if (group.contains(t) && !seen.contains(t)) {
        seen.add(t);
        naturalFromGroup++;
      } else if (feidan && t == kYaoJi) {
        // 1s (幺鸡) acts as a wildcard substitute for a missing tile in the Egg
      } else {
        return false;
      }
    }
    return naturalFromGroup >= 1;
  }

  if (checkGroup(const {kHaku, kHatsu, kChun})) return 'dragon';
  if (checkGroup(const {kEast, kSouth, kWest, kNorth}, minLen: 3, maxLen: 4)) return 'wind';
  if (checkGroup(const {0, 9, 18})) return 'yao';
  if (checkGroup(const {8, 17, 26})) return 'jiu';
  return null;
}

/// Evaluates a Changchun Mahjong (长春麻将) hand (136 tiles):
/// - Standard 4 sets + 1 pair or seven pairs (`七对`).
/// - **宝牌 (`baoTile`)**: If the winning tile is `baoTile` (**摸宝**) or the hand/melds
///   contain `baoTile` (**抱宝**), awards `+2` bonus fan!
ChangchunResult? changchunEvaluate(
  List<int> concealed,
  List<Meld> melds, {
  Object? baoTile = -1,
  Object? winTile = -1,
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

  final piaohu = stdWin && melds.every((m) => !m.isChi) && isAllPungs(concealed);
  final eggCount = melds.where((m) => m.isXiadan).length;

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
    items.add(('七对', 4));
    mult *= 2;
  } else if (piaohu) {
    items.add(('飘胡', 4));
    mult *= 2;
  }
  if (eggCount > 0) {
    items.add(('下蛋×$eggCount', eggCount * 2));
  }
  if (gangKai) {
    items.add(('杠上开花', 2));
    mult *= 2;
  }
  if (qiangGang) {
    items.add(('抢杠胡', 2));
    mult *= 2;
  }

  final isBig = qingyise || hunyise || qidui || piaohu || eggCount > 0 || gangKai || qiangGang;
  if (!isBig) {
    items.add(('平胡', 1));
  }
  if (selfDrawn) {
    items.add(('自摸', 1));
  }

  final baseFan = items.fold<int>(0, (a, b) => a + b.$2);

  // 宝牌判定：摸宝 (winTile == baoTile) 或 抱宝 (手牌/副露含 baoTile) -> +2 番！
  final baoId = tileFromCode(baoTile);
  final winId = tileFromCode(winTile);
  final isMoBao = baoId >= 0 && winId == baoId;
  final inHandOrMelds = baoId >= 0 &&
      ((baoId < concealed.length && concealed[baoId] > 0) || melds.any((m) => m.tiles.contains(baoId)));
  final isBaoBao = inHandOrMelds && !isMoBao;
  final hasBao = isMoBao || isBaoBao;

  if (isMoBao) {
    items.add(('摸宝', 2));
  } else if (isBaoBao) {
    items.add(('抱宝', 2));
  }

  final totalFan = baseFan + (hasBao ? 2 : 0);

  return ChangchunResult(
    baseFan: baseFan,
    fan: totalFan,
    mult: mult,
    hasBao: hasBao,
    isMoBao: isMoBao,
    isBaoBao: isBaoBao,
    eggCount: eggCount,
    isQiDui: qidui,
    isPiaoHu: piaohu,
    isQingYiSe: qingyise,
    isHunYiSe: hunyise,
    isBig: isBig || hasBao,
    items: items,
  );
}

List<int> changchunWaits(
  List<int> concealed,
  List<Meld> melds, {
  Object? baoTile = -1,
}) {
  final out = <int>[];
  for (var t = 0; t < kKinds && t < concealed.length; t++) {
    concealed[t]++;
    final r = changchunEvaluate(concealed, melds, baoTile: baoTile, winTile: t, selfDrawn: true);
    concealed[t]--;
    if (r != null) out.add(t);
  }
  return out;
}

class _CcClaim {
  final int tile;
  final int from;
  final bool rob;
  final Map<int, Set<String>> opts;
  final Map<int, List<int>> chis;
  final Map<int, ChangchunResult> hu;
  final Map<int, Map<String, dynamic>> resp = {};
  _CcClaim(this.tile, this.from, this.rob, this.opts, {this.chis = const {}, this.hu = const {}});
  List<int> get pending => [for (final s in opts.keys) if (!resp.containsKey(s)) s]..sort();
}

class _CcDiscard {
  final int tile;
  bool taken = false;
  final bool tsumogiri;
  _CcDiscard(this.tile, {this.tsumogiri = false});
}

/// 长春麻将 (changchunmj)
class ChangchunGame extends GameEngine {
  ChangchunGame(super.setup);

  late final int totalRounds = setup.opt<int>('rounds', 4);
  late final bool feidan = setup.opt<bool>('feidan', true);

  late List<int> scores = List.filled(players, 0);
  int handNo = 0;
  int dealer = 0;
  bool over = false;
  List<Map<String, dynamic>> history = [];

  // Changchun-specific state: 宝牌 (baoIndicator -> baoTile) & 下蛋/补蛋 ('xiadan' / 'jiadan')
  int baoIndicatorId = 0;
  int baoTileId = 1;
  String get baoIndicator => tileCode(baoIndicatorId);
  String get baoTile => tileCode(baoTileId);

  void setBaoIndicator(Object indicator) {
    final id = tileFromCode(indicator);
    if (id >= 0) {
      baoIndicatorId = id;
      baoTileId = nextCyclicTile(id);
    }
  }

  void setBaoTile(Object tile) {
    final id = tileFromCode(tile);
    if (id >= 0) {
      baoTileId = id;
    }
  }

  // Hand state
  String phase = 'act'; // act, claim, settle, over, pause
  String pausedPhase = '';
  List<List<int>> hands = [];
  List<List<Meld>> melds = [];
  List<List<_CcDiscard>> discards = [];
  List<int> drawn = [];
  List<int> wall = [];
  int turn = 0;
  bool canZimo = false;
  bool afterKong = false;
  int lastDiscardSeat = -1;
  String lastAction = '';
  Map<String, dynamic>? lastEvent;
  int eventSeq = 0;
  _CcClaim? claim;
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
    discards = List.generate(players, (_) => <_CcDiscard>[]);
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
    setBaoIndicator(ind);

    turn = dealer;
    phase = 'act';
    canZimo = true;
    host.log('第 $handNo/$totalRounds 局开始，${name(dealer)} 坐庄，翻出 ${tileName(baoIndicatorId)}，本局宝牌：${tileName(baoTileId)}（下蛋立即收分 · 摸宝/抱宝+2番）');
    lastAction = '宝牌：${tileName(baoTileId)} · ${name(dealer)} 出牌';
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

  ChangchunResult? selfEval(int s) {
    final wTile = drawn[s] >= 0 && hands[s][drawn[s]] > 0 ? drawn[s] : -1;
    return changchunEvaluate(
      hands[s],
      melds[s],
      baoTile: baoTileId,
      winTile: wTile,
      selfDrawn: true,
      gangKai: afterKong,
    );
  }

  ChangchunResult? ronEval(int o, int t, {bool rob = false}) {
    final c = List<int>.of(hands[o]);
    c[t]++;
    return changchunEvaluate(
      c,
      melds[o],
      baoTile: baoTileId,
      winTile: t,
      selfDrawn: false,
      qiangGang: rob,
    );
  }

  bool get canSelfHu => phase == 'act' && canZimo && selfEval(turn) != null;

  /// Returns candidate 3-tile Egg (`下蛋`) combinations available in [s]'s hand.
  List<List<String>> selfXiadans([int? s]) {
    final seat = s ?? turn;
    if (phase != 'act' || seat != turn || wall.isEmpty || melds[seat].length >= 4) return const [];
    final h = hands[seat];
    final out = <List<String>>[];

    void tryGroup(List<int> group, {bool isYao = false}) {
      final held = [for (final t in group) if (h[t] > 0) t];
      if (held.length >= 3) {
        out.add([for (final t in held.take(3)) tileCode(t)]);
        return;
      }
      if (!feidan) return;
      if (isYao) {
        // In 幺蛋 (1m, 1p, 1s), 1s is already in group; allow 2 natural + extra 1s
        final nonJi = [for (final t in [0, 9]) if (h[t] > 0) t];
        final jiCount = h[kYaoJi];
        if (nonJi.length == 1 && jiCount >= 2) {
          out.add([tileCode(nonJi.first), '1s', '1s']);
        }
      } else {
        // Use 1s (幺鸡) to substitute for 1 missing tile in a 2-of-3 group
        if (held.length == 2 && h[kYaoJi] >= 1) {
          out.add([tileCode(held[0]), tileCode(held[1]), '1s']);
        }
      }
    }

    tryGroup(const [kHaku, kHatsu, kChun]); // 喜蛋
    tryGroup(const [kEast, kSouth, kWest, kNorth]); // 风蛋
    tryGroup(const [0, 9, 18], isYao: true); // 幺蛋
    tryGroup(const [8, 17, 26]); // 九蛋
    return out;
  }

  /// Returns tile codes in [s]'s hand that can be added to an existing `xiadan` meld (`补蛋`).
  List<String> selfJiadans([int? s]) {
    final seat = s ?? turn;
    if (phase != 'act' || seat != turn || wall.isEmpty) return const [];
    final h = hands[seat];
    final eggMelds = melds[seat].where((m) => m.isXiadan).toList();
    if (eggMelds.isEmpty) return const [];
    final out = <String>{};
    for (final m in eggMelds) {
      final group = switch (m.subKind) {
        'dragon' => const [kHaku, kHatsu, kChun],
        'wind' => const [kEast, kSouth, kWest, kNorth],
        'yao' => const [0, 9, 18],
        'jiu' => const [8, 17, 26],
        _ => const <int>[],
      };
      for (final t in group) {
        if (h[t] > 0) out.add(tileCode(t));
      }
      if (feidan && h[kYaoJi] > 0) {
        out.add('1s');
      }
    }
    return out.toList();
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
      if (r == null) throw GameError('现在不能自摸胡牌');
      final t = drawn[s] >= 0 && hands[s][drawn[s]] > 0 ? drawn[s] : _anyTile(s);
      _settleWin({s: (t, r)}, -1);
      return;
    }
    if (type == 'xiadan') {
      final rawTiles = a['tiles'];
      List<int> tileIds;
      if (rawTiles is List && rawTiles.isNotEmpty) {
        tileIds = [for (final e in rawTiles) tileFromCode(e)];
      } else {
        final cands = selfXiadans(s);
        if (cands.isEmpty) throw GameError('手中没有可亮出的下蛋组合');
        tileIds = [for (final c in cands.first) tileFromCode(c)];
      }
      _declareXiadan(s, tileIds);
      return;
    }
    if (type == 'jiadan') {
      final avail = selfJiadans(s);
      if (avail.isEmpty) throw GameError('没有可补蛋的牌');
      final argCode = tileCode(tileFromCode(a['tile']));
      final code = avail.contains(argCode) ? argCode : avail.first;
      _declareJiadan(s, tileFromCode(code));
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

  void _declareXiadan(int s, List<int> tileIds) {
    if (melds[s].length >= 4) throw GameError('副露已满 4 组，不能再下蛋');
    final subKind = classifyXiadan(tileIds, feidan: feidan);
    if (subKind == null) {
      throw GameError('无效的下蛋组合（需喜蛋5z/6z/7z、风蛋1z..4z、幺蛋1m/1p/1s或九蛋9m/9p/9s）');
    }
    final needed = countsOf(tileIds);
    for (var t = 0; t < kKinds; t++) {
      if (needed[t] > hands[s][t]) {
        throw GameError('手中没有足够的牌亮出该组下蛋');
      }
    }
    for (final t in tileIds) {
      hands[s][t]--;
    }
    melds[s].add(Meld('xiadan', tileIds.first, customTiles: List.of(tileIds), subKind: subKind));
    final eggLabel = switch (subKind) {
      'dragon' => '喜蛋',
      'wind' => '风蛋',
      'yao' => '幺蛋',
      'jiu' => '九蛋',
      _ => '下蛋',
    };
    for (var o = 0; o < players; o++) {
      if (o == s) continue;
      _pay(o, s, 2);
      events.add({
        'kind': 'xiadan',
        'subKind': subKind,
        'tiles': [for (final t in tileIds) tileCode(t)],
        'from': o,
        'to': s,
        'amount': 2,
        'why': eggLabel,
      });
    }
    lastAction = '${name(s)} 下蛋：$eggLabel（${[for (final t in tileIds) tileName(t)].join('')}）';
    host.log(lastAction);
    _event('gang', s, tileIds.first);

    // Draw 1 replacement tile while maintaining standard hand size (needSets * 3 + 2)
    final needSets = 4 - melds[s].length;
    final targetOnTurn = needSets * 3 + 2;
    final curTotal = countTotal(hands[s]);
    if (curTotal < targetOnTurn) {
      _draw(s, kong: true);
    } else {
      if (wall.isEmpty) {
        _drawnGame();
        return;
      }
      final rep = wall.removeLast();
      if (selfEval(s) == null && drawn[s] >= 0 && hands[s][drawn[s]] > 0) {
        hands[s][drawn[s]]--;
        hands[s][rep]++;
        drawn[s] = rep;
      } else {
        drawn[s] = _anyTile(s);
      }
      turn = s;
      phase = 'act';
      canZimo = true;
      afterKong = true;
    }
  }

  void _declareJiadan(int s, int t) {
    if (t < 0 || t >= kKinds || hands[s][t] <= 0) throw GameError('手中没有这张牌');
    Meld? targetMeld;
    for (final m in melds[s]) {
      if (!m.isXiadan) continue;
      final group = switch (m.subKind) {
        'dragon' => const {kHaku, kHatsu, kChun},
        'wind' => const {kEast, kSouth, kWest, kNorth},
        'yao' => const {0, 9, 18},
        'jiu' => const {8, 17, 26},
        _ => const <int>{},
      };
      if (group.contains(t) || (feidan && t == kYaoJi)) {
        targetMeld = m;
        break;
      }
    }
    if (targetMeld == null) throw GameError('没有匹配的蛋可补');
    hands[s][t]--;
    targetMeld.customTiles?.add(t);
    for (var o = 0; o < players; o++) {
      if (o == s) continue;
      _pay(o, s, 2);
      events.add({
        'kind': 'jiadan',
        'subKind': targetMeld.subKind,
        'tile': tileCode(t),
        'from': o,
        'to': s,
        'amount': 2,
        'why': '补蛋',
      });
    }
    lastAction = '${name(s)} 补蛋 ${tileName(t)}';
    host.log(lastAction);
    _event('gang', s, t);
    _draw(s, kong: true);
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
    discards[s].add(_CcDiscard(t, tsumogiri: giri));
    canZimo = false;
    afterKong = false;
    lastDiscardSeat = s;
    lastAction = '${name(s)} 打出 ${tileName(t)}';
    _event('discard', s, t);

    final opts = <int, Set<String>>{};
    final chis = <int, List<int>>{};
    final hu = <int, ChangchunResult>{};
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
      claim = _CcClaim(t, s, false, opts, chis: chis, hu: hu);
      phase = 'claim';
    }
  }

  int _prio(String type) => switch (type) {
        'ron' || 'hu' => 30,
        'gang' || 'peng' => 20,
        'chi' => 10,
        _ => 0,
      };

  int _maxPrio(_CcClaim c, int s) {
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
      final hu = <int, ChangchunResult>{};
      for (var o = 0; o < players; o++) {
        if (o == s) continue;
        final r = ronEval(o, t, rob: true);
        if (r != null) {
          opts[o] = {'ron'};
          hu[o] = r;
        }
      }
      if (opts.isNotEmpty) {
        claim = _CcClaim(t, s, true, opts, hu: hu);
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

  void _settleWin(Map<int, (int, ChangchunResult)> wins, int from, {bool rob = false}) {
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
        final amt = res.fan * res.mult * (zimo ? 2 : 1);
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
        'hasBao': res.hasBao,
        'isMoBao': res.isMoBao,
        'isBaoBao': res.isBaoBao,
        'baoTile': baoTile,
        'eggCount': res.eggCount,
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
      'baoIndicator': baoIndicator,
      'baoTile': baoTile,
      'feidan': feidan,
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
        'eggs': melds[s].where((m) => m.isXiadan).length,
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
      'rule': 'changchunmj',
      'phase': phase == 'pause' ? 'claim' : phase,
      'hand': handNo,
      'hands': totalRounds,
      'rounds': totalRounds,
      'dealer': dealer,
      'turn': turn,
      'wall': wall.length,
      'baoIndicator': baoIndicator,
      'baoTile': baoTile,
      'feidan': feidan,
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
        final xds = selfXiadans(seat);
        final jds = selfJiadans(seat);
        my['canHu'] = ev != null;
        my['canTsumo'] = ev != null;
        my['xiadans'] = xds;
        my['canXiadan'] = xds.isNotEmpty;
        my['jiadans'] = jds;
        my['canJiadan'] = jds.isNotEmpty;
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
          for (final t in changchunWaits(hands[seat], melds[seat], baoTile: baoTileId)) tileCode(t)
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
        final jds = selfJiadans(seat);
        if (jds.isNotEmpty && rng.nextDouble() < 0.7) {
          return {'type': 'jiadan', 'tile': jds.first};
        }
        final xds = selfXiadans(seat);
        if (xds.isNotEmpty && rng.nextDouble() < 0.65) {
          return {'type': 'xiadan', 'tiles': xds.first};
        }
        final ks = selfKongs();
        if (ks.isNotEmpty) return {'type': 'gang', 'tile': tileCode(ks.first.$1)};
        final legals = legalDiscards(seat);
        final nonBao = [for (final t in legals) if (t != baoTileId) t];
        final pool = nonBao.isNotEmpty ? nonBao : legals;
        if (botLevel == 0 && rng.nextDouble() < 0.3) {
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
