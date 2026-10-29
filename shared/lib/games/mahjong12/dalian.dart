import '../../src/engine.dart';
import 'tiles.dart';

class DalianResult {
  final int baseFan;
  final int fan;
  final int mult;
  final bool isOpened; // 开门 (有吃/碰/明杠/补杠，或七对)
  final bool hasAllThreeSuits; // 三门齐 (万、筒、条齐全)
  final bool hasHeng; // 有横 (有刻子/杠，或东南西北白发中作将)
  final bool hasYaoJiu; // 有幺九 (含 1/9 或字牌)
  final bool isBaoting; // 报听 (+1 番)
  final bool isChongBao; // 摸宝 / 冲宝胡 (+2 番, ×2)
  final bool isQiDui; // 七对 (+2 番)
  final bool isPengPeng; // 飘胡 / 对对胡 (+2 番)
  final bool isBig;
  final List<(String, int)> items;

  const DalianResult({
    required this.baseFan,
    required this.fan,
    required this.mult,
    required this.isOpened,
    required this.hasAllThreeSuits,
    required this.hasHeng,
    required this.hasYaoJiu,
    required this.isBaoting,
    required this.isChongBao,
    required this.isQiDui,
    required this.isPengPeng,
    required this.isBig,
    required this.items,
  });

  bool get isMoBao => isChongBao;
  bool get isPiaoHu => isPengPeng;
  String get label => [for (final (n, _) in items) n].join(' ');
  List<List<Object>> toJson() => [for (final (n, f) in items) [n, f]];
}

bool _canSetsDalian(List<int> c, int i, {required bool heng}) {
  while (i < c.length && c[i] == 0) {
    i++;
  }
  if (i >= c.length) return heng;
  // 1. Concealed triplet at i (counts as 有横!)
  if (c[i] >= 3) {
    c[i] -= 3;
    final ok = _canSetsDalian(c, i, heng: true);
    c[i] += 3;
    if (ok) return true;
  }
  // 2. Sequence at i..i+2
  if (i < kNumKinds && i % 9 <= 6 && c[i + 1] > 0 && c[i + 2] > 0) {
    c[i]--;
    c[i + 1]--;
    c[i + 2]--;
    final ok = _canSetsDalian(c, i, heng: heng);
    c[i]++;
    c[i + 1]++;
    c[i + 2]++;
    if (ok) return true;
  }
  return false;
}

bool _canStandardDalian(List<int> concealed, {required bool baseHeng}) {
  if (countTotal(concealed) % 3 != 2) return false;
  final w = List<int>.of(concealed);
  for (var p = 0; p < w.length; p++) {
    if (w[p] >= 2) {
      // Dragon or Wind pair (1z..7z) counts as 有横!
      final pairHeng = isHonor(p);
      w[p] -= 2;
      final ok = _canSetsDalian(w, 0, heng: baseHeng || pairHeng);
      w[p] += 2;
      if (ok) return true;
    }
  }
  return false;
}

/// Evaluates a Dalian Qionghu Mahjong (大连穷胡麻将) hand (136 tiles):
/// - **大连四门硬条件 (`开门 + 三门齐 + 有横 + 有幺九`, or `七对`)**:
///   1. **开门 (`isOpened`)**: At least 1 exposed meld (`chi`, `peng`, `mgang`, `bgang`), OR `七对`!
///   2. **三门齐 (`hasAllThreeSuits`)**: Contains all 3 number suits (`m`, `p`, `s`)!
///   3. **有横 (`hasHeng`)**: Contains at least 1 triplet/quad (`peng`, `mgang`, `bgang`, `agang`, or concealed triplet)
///      OR a Dragon/Wind pair (`1z..7z`)!
///   4. **有幺九 (`hasYaoJiu`)**: Contains at least 1 terminal (`1`, `9`) or honor (`1z..7z`)!
/// - **报听亮明宝 (`baoting` & `baoTile`)**:
///   - When a ready (`baoting == true`) player draws [baoTile] (or triggers [chongbao]),
///     it is an immediate win (**摸宝 / 冲宝胡**, `+2` bonus fan) even if [baoTile] wasn't their normal wait!
DalianResult? dalianEvaluate(
  List<int> concealed,
  List<Meld> melds, {
  Object? baoTile = -1,
  Object? winTile = -1,
  bool baoting = false,
  bool chongbao = false,
  bool selfDrawn = false,
  bool strictConditions = true,
  bool gangKai = false,
  bool qiangGang = false,
}) {
  final total = countTotal(concealed);
  final needSets = 4 - melds.length;
  if (needSets < 0 || total != needSets * 3 + 2) return null;

  final baoId = tileFromCode(baoTile);
  final winId = tileFromCode(winTile);
  final isChongBao = chongbao ||
      (baoting &&
          selfDrawn &&
          baoId >= 0 &&
          (winId == baoId || (winId < 0 && baoId < concealed.length && concealed[baoId] > 0)));

  var suitMask = 0;
  var baseHeng = false;
  var hasYaoJiu = false;
  for (final m in melds) {
    if (!m.isChi) baseHeng = true;
    for (final t in m.tiles) {
      if (t < kNumKinds) suitMask |= (1 << (t ~/ 9));
      if (isYaojiu(t)) hasYaoJiu = true;
    }
  }
  for (var t = 0; t < concealed.length; t++) {
    if (concealed[t] <= 0) continue;
    if (t < kNumKinds) suitMask |= (1 << (t ~/ 9));
    if (isYaojiu(t)) hasYaoJiu = true;
  }

  final hasExposedMeld = melds.any((m) => m.isExposed);
  final hasAllThreeSuits = suitMask == 0x7;
  final qidui = melds.isEmpty && isSevenPairs(concealed);

  final stdWin = strictConditions
      ? (hasExposedMeld &&
          hasAllThreeSuits &&
          hasYaoJiu &&
          _canStandardDalian(concealed, baseHeng: baseHeng))
      : isStandardWin(concealed);

  if (!isChongBao && !stdWin && !qidui) return null;

  final pengpeng = (stdWin || isChongBao) &&
      melds.every((m) => !m.isChi) &&
      isAllPungs(concealed);

  final items = <(String, int)>[('底番', 1)];
  var mult = 1;

  if (isChongBao) {
    items.add(('冲宝胡', 2));
    mult *= 2;
  }
  if (baoting) {
    items.add(('报听', 1));
    mult *= 2;
  }
  if (qidui) {
    items.add(('七对', 2));
    mult *= 2;
  } else if (pengpeng) {
    items.add(('对对胡', 2));
    mult *= 2;
  }
  if (gangKai) {
    items.add(('杠上开花', 1));
  }
  if (qiangGang) {
    items.add(('抢杠胡', 1));
  }
  if (selfDrawn) {
    items.add(('自摸', 1));
  }

  final baseFan = items.fold<int>(0, (a, b) => a + b.$2);
  final fan = baseFan;
  final isBig = isChongBao || baoting || qidui || pengpeng || gangKai || qiangGang;

  return DalianResult(
    baseFan: baseFan,
    fan: fan,
    mult: mult,
    isOpened: hasExposedMeld || qidui || isChongBao,
    hasAllThreeSuits: hasAllThreeSuits || qidui || isChongBao,
    hasHeng: stdWin || baseHeng || qidui || isChongBao,
    hasYaoJiu: hasYaoJiu || qidui || isChongBao,
    isBaoting: baoting,
    isChongBao: isChongBao,
    isQiDui: qidui,
    isPengPeng: pengpeng,
    isBig: isBig,
    items: items,
  );
}

List<int> dalianWaits(
  List<int> concealed,
  List<Meld> melds, {
  bool strictConditions = true,
}) {
  final out = <int>[];
  for (var t = 0; t < kKinds && t < concealed.length; t++) {
    concealed[t]++;
    final r = dalianEvaluate(
      concealed,
      melds,
      selfDrawn: true,
      strictConditions: strictConditions,
    );
    concealed[t]--;
    if (r != null) out.add(t);
  }
  return out;
}

class _DlClaim {
  final int tile;
  final int from;
  final bool rob;
  final Map<int, Set<String>> opts;
  final Map<int, List<int>> chis;
  final Map<int, DalianResult> hu;
  final Map<int, Map<String, dynamic>> resp = {};
  _DlClaim(this.tile, this.from, this.rob, this.opts, {this.chis = const {}, this.hu = const {}});
  List<int> get pending => [for (final s in opts.keys) if (!resp.containsKey(s)) s]..sort();
}

class _DlDiscard {
  final int tile;
  bool taken = false;
  final bool tsumogiri;
  final bool baotingDeclare;
  _DlDiscard(this.tile, {this.tsumogiri = false, this.baotingDeclare = false});
}

/// 大连穷胡麻将 (dalianmj)
class DalianGame extends GameEngine {
  DalianGame(super.setup);

  late final int totalRounds = setup.opt<int>('rounds', 4);
  late final bool allowRon = setup.opt<bool>('allowRon', true);

  late List<int> scores = List.filled(players, 0);
  int handNo = 0;
  int dealer = 0;
  bool over = false;
  List<Map<String, dynamic>> history = [];

  // Dalian-specific state:
  // 1. 大连四门硬条件 (开门 + 三门齐 + 有横 + 有幺九, or 七对)
  // 2. 报听亮明宝 ('baoting' reveals baoTile; ready player drawing baoTile triggers 'chongbao')
  int baoIndicatorId = 0;
  int baoTileId = 1;
  bool baoRevealed = false;
  String get baoIndicator => tileCode(baoIndicatorId);
  String get baoTile => tileCode(baoTileId);

  late List<bool> baoting = List.filled(players, false);

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
  List<List<_DlDiscard>> discards = [];
  List<int> drawn = [];
  List<int> wall = [];
  int turn = 0;
  bool canZimo = false;
  bool afterKong = false;
  int lastDiscardSeat = -1;
  String lastAction = '';
  Map<String, dynamic>? lastEvent;
  int eventSeq = 0;
  _DlClaim? claim;
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
    discards = List.generate(players, (_) => <_DlDiscard>[]);
    baoting = List.filled(players, false);
    baoRevealed = false;
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
    host.log('第 $handNo/$totalRounds 局开始，${name(dealer)} 坐庄（四门硬条件：开门·三门齐·有横·有幺九 · 报听亮明宝冲宝胡）');
    lastAction = '${name(dealer)} 出牌';
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

  bool isSeatChongBao(int s) =>
      phase == 'act' &&
      turn == s &&
      canZimo &&
      baoting[s] &&
      ((drawn[s] == baoTileId && hands[s][baoTileId] > 0) ||
          (drawn[s] < 0 && hands[s][baoTileId] > 0));

  bool get canChongBao => isSeatChongBao(turn);

  int _winTileForSelf(int s) {
    if (isSeatChongBao(s)) return baoTileId;
    if (drawn[s] >= 0 && hands[s][drawn[s]] > 0) return drawn[s];
    return _anyTile(s);
  }

  DalianResult? selfEval(int s) {
    final cb = isSeatChongBao(s);
    return dalianEvaluate(
      hands[s],
      melds[s],
      baoTile: baoTileId,
      winTile: _winTileForSelf(s),
      baoting: baoting[s],
      chongbao: cb,
      selfDrawn: true,
      gangKai: afterKong,
    );
  }

  DalianResult? ronEval(int o, int t, {bool rob = false}) {
    if (!allowRon) return null;
    final c = List<int>.of(hands[o]);
    c[t]++;
    return dalianEvaluate(
      c,
      melds[o],
      baoTile: baoTileId,
      winTile: t,
      baoting: baoting[o],
      chongbao: false,
      selfDrawn: false,
      qiangGang: rob,
    );
  }

  bool get canSelfHu => phase == 'act' && canZimo && (canChongBao || selfEval(turn) != null);

  /// Candidate tiles `d` in [s]'s hand that can be discarded to declare `baoting` (报听).
  List<int> baotingTiles([int? s, bool strictConditions = true]) {
    final seat = s ?? turn;
    if (baoting[seat]) return const [];
    final out = <int>[];
    for (var d = 0; d < kKinds; d++) {
      if (hands[seat][d] <= 0) continue;
      hands[seat][d]--;
      final ws = dalianWaits(hands[seat], melds[seat], strictConditions: strictConditions);
      hands[seat][d]++;
      if (ws.isNotEmpty) out.add(d);
    }
    return out;
  }

  bool canBaoting([int? s]) {
    final seat = s ?? turn;
    return phase == 'act' && turn == seat && !baoting[seat] && baotingTiles(seat).isNotEmpty;
  }

  List<(int, bool)> selfKongs() {
    if (phase != 'act' || wall.isEmpty) return const [];
    final s = turn;
    if (baoting[s]) return const [];
    final out = <(int, bool)>[];
    for (var t = 0; t < kKinds; t++) {
      if (hands[s][t] == 4) out.add((t, false));
      if (hands[s][t] >= 1 && melds[s].any((m) => m.isPeng && m.tile == t)) out.add((t, true));
    }
    return out;
  }

  List<int> chiOptions(int s, int t) {
    if (baoting[s] || t >= kNumKinds) return const [];
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

  List<int> legalDiscards(int s) {
    if (baoting[s] && drawn[s] >= 0 && hands[s][drawn[s]] > 0) {
      return [drawn[s]];
    }
    return [for (var t = 0; t < kKinds; t++) if (hands[s][t] > 0) t];
  }

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
    if (type == 'chongbao' || type == 'mobao') {
      if (!baoting[s] || !canZimo || hands[s][baoTileId] <= 0) {
        throw GameError('现在不能冲宝胡牌');
      }
      final r = dalianEvaluate(
        hands[s],
        melds[s],
        baoTile: baoTileId,
        winTile: baoTileId,
        baoting: true,
        chongbao: true,
        selfDrawn: true,
        gangKai: afterKong,
      )!;
      _settleWin({s: (baoTileId, r)}, -1);
      return;
    }
    if (type == 'tsumo' || type == 'hu') {
      final r = canZimo ? selfEval(s) : null;
      if (r == null) throw GameError('现在不能自摸胡牌');
      final t = _winTileForSelf(s);
      _settleWin({s: (t, r)}, -1);
      return;
    }
    if (type == 'baoting' || type == 'ting' || type == 'riichi') {
      if (baoting[s]) throw GameError('已经报听了');
      var bts = baotingTiles(s, true);
      if (bts.isEmpty) {
        bts = baotingTiles(s, false);
      }
      if (bts.isEmpty) throw GameError('当前手牌打出后无法听牌，不能报听');
      var d = tileFromCode(a['tile']);
      if (d < 0) {
        if (a['tile'] == null) {
          d = bts.first;
        } else {
          throw GameError('无效的报听舍牌');
        }
      }
      if (!bts.contains(d)) throw GameError('打出该张牌后无法听牌，不能报听');
      baoting[s] = true;
      final firstReveal = !baoRevealed;
      baoRevealed = true;
      host.log(firstReveal
          ? '${name(s)} 宣布【报听】，亮出本局明宝：【${tileName(baoTileId)}】！'
          : '${name(s)} 宣布【报听】（明宝：${tileName(baoTileId)}）！');
      _discard(s, d, baotingDeclare: true);
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
      final legals = legalDiscards(s);
      if (!legals.contains(t)) throw GameError('报听后只能打出刚摸到的牌');
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

  void _discard(int s, int t, {bool baotingDeclare = false}) {
    hands[s][t]--;
    final giri = drawn[s] == t;
    drawn[s] = -1;
    discards[s].add(_DlDiscard(t, tsumogiri: giri, baotingDeclare: baotingDeclare));
    canZimo = false;
    afterKong = false;
    lastDiscardSeat = s;
    lastAction = baotingDeclare
        ? '${name(s)} 报听打出 ${tileName(t)}（明宝：${tileName(baoTileId)}）'
        : '${name(s)} 打出 ${tileName(t)}';
    _event(baotingDeclare ? 'riichi' : 'discard', s, t);

    final opts = <int, Set<String>>{};
    final chis = <int, List<int>>{};
    final hu = <int, DalianResult>{};
    for (var o = 0; o < players; o++) {
      if (o == s) continue;
      final set = <String>{};
      final r = ronEval(o, t);
      if (r != null) {
        set.add('ron');
        hu[o] = r;
      }
      if (wall.isNotEmpty && !baoting[o]) {
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
      claim = _DlClaim(t, s, false, opts, chis: chis, hu: hu);
      phase = 'claim';
    }
  }

  int _prio(String type) => switch (type) {
        'ron' || 'hu' => 30,
        'gang' || 'mgang' || 'peng' => 20,
        'chi' => 10,
        _ => 0,
      };

  int _maxPrio(_DlClaim c, int s) {
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
      final hu = <int, DalianResult>{};
      for (var o = 0; o < players; o++) {
        if (o == s) continue;
        final r = ronEval(o, t, rob: true);
        if (r != null) {
          opts[o] = {'ron'};
          hu[o] = r;
        }
      }
      if (opts.isNotEmpty) {
        claim = _DlClaim(t, s, true, opts, hu: hu);
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

  void _settleWin(Map<int, (int, DalianResult)> wins, int from, {bool rob = false}) {
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
        'baoting': res.isBaoting,
        'chongbao': res.isChongBao,
        'isChongBao': res.isChongBao,
        'baoTile': baoTile,
        'baseFan': res.baseFan,
        'fan': res.fan,
        'mult': res.mult,
        'total': totalWon,
        'items': res.toJson(),
        'pay': pay,
        'hand': codesOfCounts(hands[w]),
      });
      host.log(res.isChongBao
          ? '${name(w)} 摸宝冲宝胡 ${tileName(tile)}！${res.label}'
          : zimo
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
      'baoRevealed': baoRevealed,
      'baoting': List.of(baoting),
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
        'baoting': baoting[s],
        'discards': [
          for (final d in discards[s])
            {'t': tileCode(d.tile), 'taken': d.taken, 'tg': d.tsumogiri, 'riichi': d.baotingDeclare}
        ],
        'wind': seatWind(s),
        'score': scores[s],
        'delta': handDelta[s],
      });
    }
    final v = <String, dynamic>{
      'rule': 'dalianmj',
      'phase': phase == 'pause' ? 'claim' : phase,
      'hand': handNo,
      'hands': totalRounds,
      'rounds': totalRounds,
      'dealer': dealer,
      'turn': turn,
      'wall': wall.length,
      'baoRevealed': baoRevealed,
      'baoIndicator': baoRevealed || reveal ? baoIndicator : null,
      'baoTile': baoRevealed || reveal ? baoTile : null,
      'allowRon': allowRon,
      'baoting': List.of(baoting),
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
        'baoting': baoting[seat],
      };
      if (phase == 'act' && turn == seat) {
        final cb = isSeatChongBao(seat);
        final ev = canZimo ? selfEval(seat) : null;
        final bts = baotingTiles(seat);
        my['canChongBao'] = cb;
        my['canHu'] = cb || ev != null;
        my['canTsumo'] = cb || ev != null;
        my['canBaoting'] = !baoting[seat] && bts.isNotEmpty;
        my['baotingTiles'] = [for (final t in bts) tileCode(t)];
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
          for (final t in dalianWaits(hands[seat], melds[seat])) tileCode(t)
        ];
      }
      v['me'] = my;
    }
    return v;
  }

  int _tileValueDalian(int seat, int t) {
    final c = hands[seat];
    var v = tileValue(c, t, preferHonors: true);
    // Protect last tile of a suit to satisfy 三门齐
    if (t < kNumKinds) {
      final s = t ~/ 9;
      var suitCount = 0;
      for (var i = s * 9; i < s * 9 + 9; i++) {
        suitCount += c[i];
      }
      for (final m in melds[seat]) {
        for (final mt in m.tiles) {
          if (mt < kNumKinds && mt ~/ 9 == s) suitCount++;
        }
      }
      if (suitCount <= 1) v += 15;
    }
    // Protect last yaojiu tile to satisfy 有幺九
    if (isYaojiu(t)) {
      var yjCount = 0;
      for (var i = 0; i < kKinds; i++) {
        if (isYaojiu(i)) yjCount += c[i];
      }
      for (final m in melds[seat]) {
        for (final mt in m.tiles) {
          if (isYaojiu(mt)) yjCount++;
        }
      }
      if (yjCount <= 1) v += 15;
    }
    return v;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    switch (phase) {
      case 'act':
        if (seat != turn) return null;
        if (canChongBao) return {'type': 'chongbao'};
        if (canSelfHu) return {'type': 'tsumo'};
        if (!baoting[seat]) {
          final bts = baotingTiles(seat);
          if (bts.isNotEmpty) {
            return {'type': 'baoting', 'tile': tileCode(bts.first)};
          }
        }
        final ks = selfKongs();
        if (ks.isNotEmpty) return {'type': 'gang', 'tile': tileCode(ks.first.$1)};
        final legals = legalDiscards(seat);
        if (botLevel == 0 && rng.nextDouble() < 0.3) {
          return {'type': 'discard', 'tile': tileCode(legals[rng.nextInt(legals.length)])};
        }
        var best = legals.first, bestScore = 1 << 20;
        for (final t in legals) {
          final sc = _tileValueDalian(seat, t);
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
        if (!baoting[seat]) {
          final opened = melds[seat].any((m) => m.isExposed);
          final hasHengMeld = melds[seat].any((m) => !m.isChi);
          if (o.contains('gang')) return {'type': 'gang'};
          if (o.contains('peng') && (!opened || !hasHengMeld || rng.nextDouble() < 0.7)) {
            return {'type': 'peng'};
          }
          if (o.contains('chi') && (!opened || rng.nextDouble() < 0.45)) {
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
