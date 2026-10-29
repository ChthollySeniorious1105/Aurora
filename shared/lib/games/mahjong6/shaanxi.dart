import '../../src/engine.dart';
import 'tiles.dart';

class ShaanxiResult {
  final int fan;
  final int mult;
  final bool isSiHongZhong; // 四红中直接胡牌
  final bool isQiDui;
  final bool isQingYiSe;
  final bool isPengPeng;
  final bool noWild; // 硬胡（无红中代牌）
  final bool isBig;
  final List<(String, int)> items;

  const ShaanxiResult({
    required this.fan,
    required this.mult,
    required this.isSiHongZhong,
    required this.isQiDui,
    required this.isQingYiSe,
    required this.isPengPeng,
    required this.noWild,
    required this.isBig,
    required this.items,
  });

  String get label => [for (final (n, _) in items) n].join(' ');
  List<List<Object>> toJson() => [for (final (n, f) in items) [n, f]];
}

/// Evaluates a Shaanxi Mahjong hand (112 tiles, '7z' = [kChun] is universal wildcard).
/// Holding all 4 '7z' tiles on self-draw is an immediate win (四红中).
ShaanxiResult? shaanxiEvaluate(
  List<int> concealed,
  List<Meld> melds, {
  int laiziTile = kChun,
  bool selfDrawn = false,
  bool gangKai = false,
  bool qiangGang = false,
}) {
  final total = countTotal(concealed);
  final needSets = 4 - melds.length;
  if (needSets < 0 || total != needSets * 3 + 2) return null;

  final wild = (laiziTile >= 0 && laiziTile < concealed.length) ? concealed[laiziTile] : 0;
  final isSiHongZhong = selfDrawn && wild >= 4;

  final pureStd = isStandardWin(concealed);
  final pureQidui = melds.isEmpty && isSevenPairs(concealed);
  final noWild = (pureStd || pureQidui) && wild == 0;

  final c = List<int>.of(concealed);
  if (laiziTile >= 0 && laiziTile < c.length) {
    c[laiziTile] = 0;
  }

  final stdWin = pureStd || canAnyPairStandardWild(c, wild);
  final qidui = pureQidui || (melds.isEmpty && canSevenPairsWild(c, wild));
  final pengpeng = melds.every((m) => !m.isChi) && (isAllPungs(concealed) || canPengPengWild(c, wild));

  if (!isSiHongZhong && !stdWin && !qidui) return null;

  final suits = <int>{};
  var hasOtherHonor = false;
  for (var t = 0; t < c.length; t++) {
    if (c[t] == 0) continue;
    if (t < kNumKinds) {
      suits.add(t ~/ 9);
    } else if (t != laiziTile) {
      hasOtherHonor = true;
    }
  }
  for (final m in melds) {
    for (final t in m.tiles) {
      if (t == laiziTile) continue;
      if (t < kNumKinds) {
        suits.add(t ~/ 9);
      } else {
        hasOtherHonor = true;
      }
    }
  }
  final qingyise = !hasOtherHonor && suits.length <= 1 && (stdWin || qidui);

  final items = <(String, int)>[];
  var mult = 1;
  if (isSiHongZhong) {
    items.add(('四红中', 6));
    mult *= 2;
  }
  if (qingyise) {
    items.add(('清一色', 4));
    mult *= 2;
  }
  if (qidui) {
    items.add(('七对', 4));
    mult *= 2;
  } else if (pengpeng && stdWin) {
    items.add(('碰碰胡', 2));
  }
  if (gangKai) {
    items.add(('杠上开花', 2));
    mult *= 2;
  }
  if (qiangGang) {
    items.add(('抢杠胡', 2));
  }
  if (noWild) {
    items.add(('硬胡', 2));
  }
  if (items.isEmpty) {
    items.add(('平胡', 1));
  }
  if (selfDrawn && !isSiHongZhong) {
    items.add(('自摸', 1));
  }

  final isBig = isSiHongZhong || qingyise || qidui || pengpeng || gangKai || qiangGang || noWild;
  final fan = items.fold<int>(0, (a, b) => a + b.$2);
  return ShaanxiResult(
    fan: fan,
    mult: mult,
    isSiHongZhong: isSiHongZhong,
    isQiDui: qidui,
    isQingYiSe: qingyise,
    isPengPeng: pengpeng && stdWin,
    noWild: noWild,
    isBig: isBig,
    items: items,
  );
}

List<int> shaanxiWaits(
  List<int> concealed,
  List<Meld> melds, {
  int laiziTile = kChun,
}) {
  final out = <int>[];
  for (final t in kShaanxiTileKinds) {
    concealed[t]++;
    final r = shaanxiEvaluate(concealed, melds, laiziTile: laiziTile, selfDrawn: true);
    concealed[t]--;
    if (r != null) out.add(t);
  }
  return out;
}

class _SxClaim {
  final int tile;
  final int from;
  final bool rob;
  final Map<int, Set<String>> opts;
  final Map<int, ShaanxiResult> hu;
  final Map<int, Map<String, dynamic>> resp = {};
  _SxClaim(this.tile, this.from, this.rob, this.opts, {this.hu = const {}});
  List<int> get pending => [for (final s in opts.keys) if (!resp.containsKey(s)) s]..sort();
}

class _SxDiscard {
  final int tile;
  bool taken = false;
  final bool tsumogiri;
  _SxDiscard(this.tile, {this.tsumogiri = false});
}

/// 陕西麻将 (shaanximj)
class ShaanxiGame extends GameEngine {
  ShaanxiGame(super.setup);

  late final int totalRounds = setup.opt<int>('rounds', 4);
  late final bool allowRon = setup.opt<bool>('allowRon', true);

  late List<int> scores = List.filled(players, 0);
  int handNo = 0;
  int dealer = 0;
  bool over = false;
  List<Map<String, dynamic>> history = [];

  // Shaanxi-specific state: 红中 ('7z') is fixed wildcard, plus Step 1 下炮子 (paozi in 0..4)
  int laiziTileId = kChun;
  String get laiziTile => tileCode(laiziTileId);
  late List<int> paozi = List.filled(players, 0);
  Set<int> paoziDone = {};

  // Hand state
  String phase = 'paozi'; // paozi, act, claim, settle, over, pause
  String pausedPhase = '';
  List<List<int>> hands = [];
  List<List<Meld>> melds = [];
  List<List<_SxDiscard>> discards = [];
  List<int> drawn = [];
  List<int> wall = [];
  int turn = 0;
  bool canZimo = false;
  bool afterKong = false;
  int lastDiscardSeat = -1;
  String lastAction = '';
  Map<String, dynamic>? lastEvent;
  int eventSeq = 0;
  _SxClaim? claim;
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
    wall = <int>[for (final t in kShaanxiTileKinds) for (var k = 0; k < 4; k++) t]..shuffle(rng);
    hands = List.generate(players, (_) => List.filled(kKinds, 0));
    melds = List.generate(players, (_) => <Meld>[]);
    discards = List.generate(players, (_) => <_SxDiscard>[]);
    paozi = List.filled(players, 0);
    paoziDone = {};
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
    phase = 'paozi';
    canZimo = true;
    host.log('第 $handNo/$totalRounds 局开始，${name(dealer)} 坐庄，请各位玩家下炮子（0~4 子）');
    lastAction = '下炮子阶段（0~4 子）';
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

  ShaanxiResult? selfEval(int s) => shaanxiEvaluate(
        hands[s],
        melds[s],
        laiziTile: laiziTileId,
        selfDrawn: true,
        gangKai: afterKong,
      );

  ShaanxiResult? ronEval(int o, int t, {bool rob = false}) {
    if (!allowRon || t == laiziTileId) return null;
    final c = List<int>.of(hands[o]);
    c[t]++;
    return shaanxiEvaluate(
      c,
      melds[o],
      laiziTile: laiziTileId,
      selfDrawn: false,
      qiangGang: rob,
    );
  }

  bool get canSelfHu => phase == 'act' && canZimo && selfEval(turn) != null;
  bool get canSiHongZhong => phase == 'act' && canZimo && hands[turn][laiziTileId] >= 4;

  List<(int, bool)> selfKongs() {
    if (phase != 'act' || wall.isEmpty) return const [];
    final s = turn;
    final out = <(int, bool)>[];
    for (final t in kShaanxiTileKinds) {
      if (t == laiziTileId) continue;
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
  int get botDelayMs => phase == 'claim' || phase == 'paozi' ? 450 : 700;

  @override
  List<int> get waitingFor {
    switch (phase) {
      case 'paozi':
        return [for (var s = 0; s < players; s++) if (!paoziDone.contains(s)) s];
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
      case 'paozi':
        if (type != 'paozi') throw GameError('请先选择下炮子数（0~4）');
        if (paoziDone.contains(seat)) throw GameError('你已经下过炮子了');
        final c = asInt(a['count'], -1);
        if (c < 0 || c > 4) throw GameError('炮子数必须在 0~4 之间');
        paozi[seat] = c;
        paoziDone.add(seat);
        host.log('${name(seat)} 下 $c 炮');
        if (paoziDone.length >= players) {
          phase = 'act';
          turn = dealer;
          canZimo = true;
          lastAction = '红中赖子 · ${name(dealer)} 出牌';
        }
        return;
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
    if (type == 'sihongzhong') {
      if (!canZimo || hands[s][laiziTileId] < 4) {
        throw GameError('需要手握 4 张红中才能发动【四红中】胡牌');
      }
      final r = selfEval(s)!;
      _settleWin({s: (laiziTileId, r)}, -1);
      return;
    }
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
      if (t != laiziTileId && hands[s][t] > 0) return t;
    }
    return laiziTileId;
  }

  void _discard(int s, int t) {
    hands[s][t]--;
    final giri = drawn[s] == t;
    drawn[s] = -1;
    discards[s].add(_SxDiscard(t, tsumogiri: giri));
    canZimo = false;
    afterKong = false;
    lastDiscardSeat = s;
    lastAction = '${name(s)} 打出 ${tileName(t)}';
    _event('discard', s, t);

    if (t == laiziTileId) {
      _coverPause(() => _draw((s + 1) % players));
      return;
    }

    final opts = <int, Set<String>>{};
    final hu = <int, ShaanxiResult>{};
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
      claim = _SxClaim(t, s, false, opts, hu: hu);
      phase = 'claim';
    }
  }

  int _prio(String type) => switch (type) { 'ron' || 'hu' => 30, 'gang' || 'peng' => 20, _ => 0 };

  int _maxPrio(_SxClaim c, int s) {
    var best = 0;
    for (final o in c.opts[s]!) {
      final p = _prio(o);
      if (p > best) best = p;
    }
    return best;
  }

  void _handleClaim(int s, String rawType, Map<String, dynamic> a) {
    if (!allowRon && (rawType == 'ron' || rawType == 'hu')) {
      throw GameError('当前为只炸不胡（只许自摸）模式，不能点炮');
    }
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
      events.add({'kind': 'gang', 'from': c.from, 'to': s, 'amount': 2, 'why': '点杠'});
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
      final hu = <int, ShaanxiResult>{};
      for (var o = 0; o < players; o++) {
        if (o == s) continue;
        final r = ronEval(o, t, rob: true);
        if (r != null) {
          opts[o] = {'ron'};
          hu[o] = r;
        }
      }
      if (opts.isNotEmpty) {
        claim = _SxClaim(t, s, true, opts, hu: hu);
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

  void _settleWin(Map<int, (int, ShaanxiResult)> wins, int from, {bool rob = false}) {
    final zimo = from < 0;
    for (final e in wins.entries) {
      final w = e.key;
      final (tile, res) = e.value;
      if (zimo && hands[w][tile] > 0) hands[w][tile]--;
      drawn[w] = -1;
      final payers = zimo ? [for (var o = 0; o < players; o++) if (o != w) o] : [from];
      final pay = <String, int>{};
      final paoziPay = <String, int>{};
      var totalWon = 0;
      for (final p in payers) {
        final baseAmt = res.fan * res.mult * (zimo ? 2 : 1);
        final pzBonus = paozi[w] + paozi[p];
        final amt = baseAmt + pzBonus;
        _pay(p, w, amt);
        pay['$p'] = amt;
        paoziPay['$p'] = pzBonus;
        totalWon += amt;
      }
      final itemsJson = res.toJson();
      if (paozi[w] > 0) {
        itemsJson.add(['赢家${paozi[w]}炮', paozi[w]]);
      }
      events.add({
        'kind': 'hu',
        'seat': w,
        'from': from,
        'tile': tileCode(tile),
        'zimo': zimo,
        'rob': rob,
        'big': res.isBig,
        'sihongzhong': res.isSiHongZhong,
        'fan': res.fan,
        'mult': res.mult,
        'paozi': List.of(paozi),
        'paoziPay': paoziPay,
        'total': totalWon,
        'items': itemsJson,
        'pay': pay,
        'hand': codesOfCounts(hands[w]),
      });
      host.log(zimo
          ? '${name(w)} 自摸 ${tileName(tile)}！${res.label}（炮子+${paozi[w]}）'
          : '${name(w)} 胡 ${name(from)} 的 ${tileName(tile)}！${res.label}（炮子+${paozi[w] + paozi[from]}）');
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
      'laiziTile': laiziTile,
      'paozi': List.of(paozi),
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
      final hasDrawn = (phase == 'act' || phase == 'paozi') && turn == s && drawn[s] >= 0 && hands[s][drawn[s]] > 0;
      seats.add({
        'count': n,
        'drawn': hasDrawn,
        'hand': s == seat || reveal ? codesOfCounts(hands[s]) : null,
        'melds': [for (final m in melds[s]) m.toJson(hide: m.concealed && s != seat && !reveal)],
        'paozi': paozi[s],
        'paoziDone': paoziDone.contains(s),
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
      'rule': 'shaanximj',
      'phase': phase == 'pause' ? 'claim' : phase,
      'hand': handNo,
      'hands': totalRounds,
      'rounds': totalRounds,
      'dealer': dealer,
      'turn': turn,
      'wall': wall.length,
      'laiziTile': laiziTile,
      'allowRon': allowRon,
      'paozi': List.of(paozi),
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
        'drawn': (phase == 'act' || phase == 'paozi') && turn == seat && drawn[seat] >= 0 && hands[seat][drawn[seat]] > 0
            ? tileCode(drawn[seat])
            : null,
        'paozi': paozi[seat],
        'canPaozi': phase == 'paozi' && !paoziDone.contains(seat),
      };
      if (phase == 'act' && turn == seat) {
        final ev = canZimo ? selfEval(seat) : null;
        my['canHu'] = ev != null;
        my['canTsumo'] = ev != null;
        my['canSiHongZhong'] = canSiHongZhong;
        my['kongs'] = [for (final (t, _) in selfKongs()) tileCode(t)];
        my['discardable'] = [for (final t in legalDiscards(seat)) tileCode(t)];
      }
      if (phase == 'claim' && claim!.opts.containsKey(seat) && !claim!.resp.containsKey(seat)) {
        my['claim'] = claim!.opts[seat]!.toList();
      }
      final n = countTotal(hands[seat]);
      if (n % 3 == 1 && (phase == 'act' || phase == 'claim' || phase == 'pause')) {
        my['waits'] = [
          for (final t in shaanxiWaits(hands[seat], melds[seat], laiziTile: laiziTileId)) tileCode(t)
        ];
      }
      v['me'] = my;
    }
    return v;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    switch (phase) {
      case 'paozi':
        if (paoziDone.contains(seat)) return null;
        final hz = hands[seat][laiziTileId];
        var pairs = 0;
        for (var t = 0; t < kNumKinds; t++) {
          if (hands[seat][t] >= 2) pairs++;
        }
        final count = (hz + (pairs >= 3 ? 1 : 0)).clamp(0, 4);
        return {'type': 'paozi', 'count': count};
      case 'settle':
        return {'type': 'next'};
      case 'claim':
        final c = claim!;
        final opts = c.opts[seat];
        if (opts == null || c.resp.containsKey(seat)) return null;
        if (opts.contains('ron')) return {'type': 'ron'};
        if (opts.contains('gang')) return {'type': 'gang'};
        if (opts.contains('peng') && hands[seat][c.tile] == 2) return {'type': 'peng'};
        return {'type': 'pass'};
      case 'act':
        if (seat != turn) return null;
        if (canSiHongZhong) return {'type': 'sihongzhong'};
        if (canSelfHu) return {'type': 'tsumo'};
        final ks = selfKongs();
        if (ks.isNotEmpty) {
          return {'type': 'gang', 'tile': tileCode(ks.first.$1)};
        }
        final ds = legalDiscards(seat);
        final nonWild = ds.where((t) => t != laiziTileId).toList();
        final pool = nonWild.isNotEmpty ? nonWild : ds;
        if (botLevel == 0 && pool.length > 1 && rng.nextDouble() < 0.35) {
          return {'type': 'discard', 'tile': tileCode(pool[rng.nextInt(pool.length)])};
        }
        var best = pool.first;
        var bestVal = 999999;
        for (final t in pool) {
          final v = tileValue(hands[seat], t);
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
