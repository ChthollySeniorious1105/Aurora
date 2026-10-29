import '../../src/engine.dart';
import 'tiles.dart';

class HarbinResult {
  final int fan;
  final bool isBig;
  final List<(String, int)> items;
  const HarbinResult(this.fan, this.isBig, this.items);

  String get label => [for (final (n, _) in items) n].join(' ');
  List<List<Object>> toJson() => [for (final (n, f) in items) [n, f]];
}

/// Evaluates a Harbin Mahjong hand (112 tiles: 1m..9m, 1p..9p, 1s..9s + 7z 红中).
HarbinResult? harbinEvaluate(
  List<int> concealed,
  List<Meld> melds, {
  bool kaimen = true,
  bool ting = false,
  bool selfDrawn = false,
  bool mobao = false,
  bool hongzhongFly = false,
  bool guaDaFeng = false,
  bool gangKai = false,
  bool qiangGang = false,
}) {
  final total = countTotal(concealed);
  final needSets = 4 - melds.length;

  // Special Ting self-draw wins: 摸宝, 红中满天飞, 刮大风
  final specialWin = ting && selfDrawn && (mobao || hongzhongFly || guaDaFeng);
  if (!specialWin && (needSets < 0 || total != needSets * 3 + 2)) return null;

  final qidui = melds.isEmpty && isSevenPairs(concealed);
  final piao = melds.every((m) => !m.isChi) && isAllPungs(concealed);
  final std = qidui || piao || isStandardWin(concealed);
  if (!std && !specialWin) return null;

  final items = <(String, int)>[];
  if (mobao) items.add(('摸宝', 4));
  if (hongzhongFly) items.add(('红中满天飞', 4));
  if (guaDaFeng) items.add(('刮大风', 4));
  if (piao) items.add(('飘胡', 4));
  if (qidui) items.add(('七对', 4));
  if (gangKai) items.add(('杠上开花', 2));
  if (qiangGang) items.add(('抢杠胡', 2));
  if (ting) items.add(('报听', 1));
  if (kaimen) items.add(('开门', 1));
  if (selfDrawn) items.add(('自摸', 1));
  if (items.isEmpty) items.add(('平胡', 1));

  final isBig = mobao || hongzhongFly || guaDaFeng || piao || qidui || gangKai || qiangGang;
  final fan = items.fold<int>(0, (a, b) => a + b.$2);
  return HarbinResult(fan, isBig, items);
}

List<int> harbinWaits(List<int> concealed, List<Meld> melds) {
  final out = <int>[];
  for (var t = 0; t < kKinds && t < concealed.length; t++) {
    if (t >= kNumKinds && t != kChun) continue;
    concealed[t]++;
    final r = harbinEvaluate(concealed, melds);
    concealed[t]--;
    if (r != null) out.add(t);
  }
  return out;
}

class _HbClaim {
  final int tile;
  final int from;
  final bool rob;
  final Map<int, Set<String>> opts;
  final Map<int, List<int>> chis;
  final Map<int, HarbinResult> hu;
  final Map<int, Map<String, dynamic>> resp = {};
  _HbClaim(this.tile, this.from, this.rob, this.opts, {this.chis = const {}, this.hu = const {}});
  List<int> get pending => [for (final s in opts.keys) if (!resp.containsKey(s)) s]..sort();
}

class _HbDiscard {
  final int tile;
  bool taken = false;
  final bool tsumogiri;
  final bool tingDeclare;
  _HbDiscard(this.tile, {this.tsumogiri = false, this.tingDeclare = false});
}

/// 哈尔滨麻将 (harbinmj)
class HarbinGame extends GameEngine {
  HarbinGame(super.setup);

  late final int totalRounds = setup.opt<int>('rounds', 4);
  late final bool hongzhongFlyOn = setup.opt<bool>('hongzhongFly', true);

  late List<int> scores = List.filled(players, 0);
  int handNo = 0;
  int dealer = 0;
  bool over = false;
  List<Map<String, dynamic>> history = [];

  // Harbin-specific state
  int baoTileId = 0;
  String get baoTile => tileCode(baoTileId);
  List<bool> kaimen = [false, false, false, false];
  List<bool> ting = [false, false, false, false];
  List<bool> guaDaFeng = [false, false, false, false];
  List<int> guaDaFengCount = [0, 0, 0, 0];

  // Hand state
  String phase = 'act'; // act, claim, settle, over, pause
  String pausedPhase = '';
  List<List<int>> hands = [];
  List<List<Meld>> melds = [];
  List<List<_HbDiscard>> discards = [];
  List<int> drawn = [];
  List<int> wall = [];
  int turn = 0;
  bool canZimo = false;
  bool afterKong = false;
  int lastDiscardSeat = -1;
  String lastAction = '';
  Map<String, dynamic>? lastEvent;
  int eventSeq = 0;
  _HbClaim? claim;
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
    // 112 tiles: 1m..9m, 1p..9p, 1s..9s (27*4 = 108) + four '7z' 红中 (4)
    wall = <int>[
      for (var t = 0; t < kNumKinds; t++)
        for (var k = 0; k < 4; k++) t,
      for (var k = 0; k < 4; k++) kChun,
    ]..shuffle(rng);
    hands = List.generate(players, (_) => List.filled(kKinds, 0));
    melds = List.generate(players, (_) => <Meld>[]);
    discards = List.generate(players, (_) => <_HbDiscard>[]);
    kaimen = List.filled(players, false);
    ting = List.filled(players, false);
    guaDaFeng = List.filled(players, false);
    guaDaFengCount = List.filled(players, 0);
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

    // Set secret Bao tile from dead wall (only visible in view(seat) to Ting players!)
    baoTileId = wall.removeLast();

    turn = dealer;
    phase = 'act';
    canZimo = true;
    host.log('第 $handNo/$totalRounds 局开始，${name(dealer)} 坐庄，宝牌已从牌墙抽出（上听后可见）');
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

    // If a Ting player self-draws a tile matching one of their own triplets/pungs, trigger 刮大风!
    if (ting[s] && (hands[s][t] == 4 || melds[s].any((m) => (m.isPeng || m.isKong) && m.tile == t))) {
      _triggerGuaDaFeng(s, t);
    }
    return true;
  }

  void _triggerGuaDaFeng(int s, int t) {
    guaDaFeng[s] = true;
    guaDaFengCount[s]++;
    for (var o = 0; o < players; o++) {
      if (o == s) continue;
      _pay(o, s, 2);
    }
    events.add({
      'kind': 'guadafeng',
      'why': '刮大风',
      'from': (s + 1) % players,
      'to': s,
      'tile': tileCode(t),
      'amount': 2 * (players - 1),
    });
    host.log('${name(s)} 听牌后摸到刻子牌 ${tileName(t)}，触发【刮大风】（全场各付 2 分）！');
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

  bool isMoBaoDraw(int s) {
    if (!ting[s] || !canZimo) return false;
    final d = drawn[s];
    if (d >= 0) return d == baoTileId;
    return hands[s][baoTileId] > 0;
  }

  bool isHongzhongFlyDraw(int s) {
    if (!ting[s] || !canZimo || !hongzhongFlyOn) return false;
    final d = drawn[s];
    if (d >= 0) return d == kChun;
    return hands[s][kChun] > 0;
  }

  bool isGuaDaFengDraw(int s) {
    if (!ting[s] || !canZimo) return false;
    if (guaDaFeng[s]) return true;
    final d = drawn[s];
    if (d >= 0) {
      if (hands[s][d] == 4) return true;
      if (melds[s].any((m) => (m.isPeng || m.isKong) && m.tile == d) && hands[s][d] >= 1) return true;
    }
    for (var t = 0; t < kKinds; t++) {
      if (hands[s][t] == 4) return true;
      if (hands[s][t] >= 1 && melds[s].any((m) => m.isPeng && m.tile == t)) return true;
    }
    return false;
  }

  bool canMoBao(int s) =>
      phase == 'act' && turn == s && canZimo && ting[s] && (isMoBaoDraw(s) || isHongzhongFlyDraw(s) || isGuaDaFengDraw(s));

  HarbinResult? selfEval(int s) => harbinEvaluate(
        hands[s],
        melds[s],
        kaimen: kaimen[s],
        ting: ting[s],
        selfDrawn: true,
        mobao: isMoBaoDraw(s),
        hongzhongFly: isHongzhongFlyDraw(s),
        guaDaFeng: isGuaDaFengDraw(s),
        gangKai: afterKong,
      );

  HarbinResult? ronEval(int o, int t, {bool rob = false}) {
    final c = List<int>.of(hands[o]);
    c[t]++;
    return harbinEvaluate(
      c,
      melds[o],
      kaimen: kaimen[o],
      ting: ting[o],
      selfDrawn: false,
      qiangGang: rob,
    );
  }

  bool get canSelfHu => phase == 'act' && canZimo && selfEval(turn) != null;

  /// Tiles [s] can discard to declare Ting ('ting').
  List<int> tingTiles(int s) {
    if (phase != 'act' || turn != s || ting[s]) return const [];
    final out = <int>[];
    for (var t = 0; t < kKinds; t++) {
      if (hands[s][t] <= 0) continue;
      hands[s][t]--;
      final w = harbinWaits(hands[s], melds[s]);
      hands[s][t]++;
      if (w.isNotEmpty) out.add(t);
    }
    return out;
  }

  /// Normal 4-of-a-kind kongs available to turn player: (tile, isBuGang).
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
    if (t >= kNumKinds || ting[s]) return const [];
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
    if (ting[s] && drawn[s] >= 0 && hands[s][drawn[s]] > 0) {
      return [drawn[s]];
    }
    return [for (var t = 0; t < kKinds; t++) if (hands[s][t] > 0) t];
  }

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
    if (type == 'hu' || type == 'mobao' || type == 'guadafeng') {
      if (type == 'guadafeng' && isGuaDaFengDraw(s) && !guaDaFeng[s]) {
        final gTile = drawn[s] >= 0 ? drawn[s] : _anyTile(s);
        _triggerGuaDaFeng(s, gTile);
      }
      final r = canZimo ? selfEval(s) : null;
      if (r == null) throw GameError('现在不能胡牌');
      final t = drawn[s] >= 0 && hands[s][drawn[s]] > 0 ? drawn[s] : _anyTile(s);
      _settleWin({s: (t, r)}, -1);
      return;
    }
    if (type == 'ting') {
      if (ting[s]) throw GameError('已经报听了');
      final tts = tingTiles(s);
      if (tts.isEmpty) throw GameError('当前手牌还不能报听');
      var t = tileFromCode(a['tile']);
      if (t < 0 || !tts.contains(t)) {
        if (a['tile'] == null) {
          t = tts.first;
        } else {
          throw GameError('打出该张牌后无法听牌');
        }
      }
      ting[s] = true;
      kaimen[s] = true;
      host.log('${name(s)} 宣布【上听】，可见宝牌！');
      _discard(s, t, tingDeclare: true);
      return;
    }
    if (type == 'gang') {
      final t = tileFromCode(a['tile']);
      final k = selfKongs().where((e) => e.$1 == t).toList();
      if (k.isEmpty) throw GameError('不能杠这张牌');
      if (ting[s] && !guaDaFeng[s]) {
        _triggerGuaDaFeng(s, t);
      }
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
    if (ting[s] && hands[s][baoTileId] > 0) return baoTileId;
    if (ting[s] && hands[s][kChun] > 0) return kChun;
    for (var t = kKinds - 1; t >= 0; t--) {
      if (hands[s][t] > 0) return t;
    }
    return 0;
  }

  void _discard(int s, int t, {bool tingDeclare = false}) {
    hands[s][t]--;
    final giri = drawn[s] == t;
    drawn[s] = -1;
    discards[s].add(_HbDiscard(t, tsumogiri: giri, tingDeclare: tingDeclare));
    canZimo = false;
    afterKong = false;
    lastDiscardSeat = s;
    lastAction = tingDeclare ? '${name(s)} 报听打出 ${tileName(t)}' : '${name(s)} 打出 ${tileName(t)}';
    _event(tingDeclare ? 'riichi' : 'discard', s, t);

    final opts = <int, Set<String>>{};
    final chis = <int, List<int>>{};
    final hu = <int, HarbinResult>{};
    for (var o = 0; o < players; o++) {
      if (o == s) continue;
      final set = <String>{};
      final r = ronEval(o, t);
      if (r != null) {
        set.add('hu');
        hu[o] = r;
      }
      if (wall.isNotEmpty && !ting[o]) {
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
      claim = _HbClaim(t, s, false, opts, chis: chis, hu: hu);
      phase = 'claim';
    }
  }

  int _prio(String type) => switch (type) { 'hu' => 30, 'gang' || 'peng' => 20, 'chi' => 10, _ => 0 };

  int _maxPrio(_HbClaim c, int s) {
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
    kaimen[s] = true; // Chi, Peng, Gang open the hand!
    if (type == 'gang') {
      hands[s][c.tile] -= 3;
      melds[s].add(Meld('mgang', c.tile, claimed: c.tile, from: c.from));
      lastAction = '${name(s)} 明杠 ${tileName(c.tile)}（开门）';
      host.log(lastAction);
      _event('gang', s, c.tile);
      _draw(s, kong: true);
      return;
    }
    if (type == 'peng') {
      hands[s][c.tile] -= 2;
      melds[s].add(Meld('peng', c.tile, claimed: c.tile, from: c.from));
      lastAction = '${name(s)} 碰 ${tileName(c.tile)}（开门）';
      _event('peng', s, c.tile);
    } else {
      final lo = r['lo'] as int;
      for (var k = lo; k < lo + 3; k++) {
        if (k != c.tile) hands[s][k]--;
      }
      melds[s].add(Meld('chi', lo, claimed: c.tile, from: c.from));
      lastAction = '${name(s)} 吃 ${tileName(c.tile)}（开门）';
      _event('chi', s, c.tile);
    }
    turn = s;
    phase = 'act';
    canZimo = false;
    afterKong = false;
    drawn[s] = -1;
  }

  void _selfKong(int s, int t, bool bu) {
    kaimen[s] = true;
    if (bu) {
      final opts = <int, Set<String>>{};
      final hu = <int, HarbinResult>{};
      for (var o = 0; o < players; o++) {
        if (o == s) continue;
        final r = ronEval(o, t, rob: true);
        if (r != null) {
          opts[o] = {'hu'};
          hu[o] = r;
        }
      }
      if (opts.isNotEmpty) {
        claim = _HbClaim(t, s, true, opts, hu: hu);
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
    kaimen[s] = true;
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

  void _settleWin(Map<int, (int, HarbinResult)> wins, int from, {bool rob = false}) {
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
        var amt = res.fan * (zimo ? 2 : 1);
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
        'fan': res.fan,
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
      'baoTile': baoTile,
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
    final canSeeBao = reveal || (seat >= 0 && seat < players && ting[seat]);
    final seats = <Map<String, dynamic>>[];
    for (var s = 0; s < players; s++) {
      final n = countTotal(hands[s]);
      final hasDrawn = phase == 'act' && turn == s && drawn[s] >= 0 && hands[s][drawn[s]] > 0;
      seats.add({
        'count': n,
        'drawn': hasDrawn,
        'hand': s == seat || reveal ? codesOfCounts(hands[s]) : null,
        'melds': [for (final m in melds[s]) m.toJson(hide: m.concealed && s != seat && !reveal)],
        'kaimen': kaimen[s],
        'ting': ting[s],
        'guaDaFeng': guaDaFeng[s],
        'discards': [
          for (final d in discards[s])
            {'t': tileCode(d.tile), 'taken': d.taken, 'tg': d.tsumogiri, 'riichi': d.tingDeclare}
        ],
        'wind': seatWind(s),
        'score': scores[s],
        'delta': handDelta[s],
      });
    }
    final v = <String, dynamic>{
      'rule': 'harbinmj',
      'phase': phase == 'pause' ? 'claim' : phase,
      'hand': handNo,
      'hands': totalRounds,
      'rounds': totalRounds,
      'dealer': dealer,
      'turn': turn,
      'wall': wall.length,
      'baoTile': canSeeBao ? baoTile : null,
      'kaimen': List.of(kaimen),
      'ting': List.of(ting),
      'guaDaFeng': List.of(guaDaFeng),
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
        final tts = tingTiles(seat);
        my['canHu'] = canSelfHu;
        my['canMoBao'] = canMoBao(seat);
        my['canTing'] = tts.isNotEmpty;
        my['tingTiles'] = [for (final t in tts) tileCode(t)];
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
        my['waits'] = [for (final t in harbinWaits(hands[seat], melds[seat])) tileCode(t)];
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
          if (!kaimen[seat] || hands[seat][c.tile] == 2) return {'type': 'peng'};
        }
        if (opts.contains('chi')) {
          if (!kaimen[seat] || botLevel == 0 || rng.nextDouble() < 0.6) {
            final list = c.chis[seat]!;
            return {'type': 'chi', 'tile': tileCode(list.first)};
          }
        }
        return {'type': 'pass'};
      case 'act':
        if (seat != turn) return null;
        if (canMoBao(seat)) return {'type': 'mobao'};
        if (canSelfHu) return {'type': 'hu'};
        final tts = tingTiles(seat);
        if (tts.isNotEmpty) {
          return {'type': 'ting', 'tile': tileCode(tts.first)};
        }
        final ks = selfKongs();
        if (ks.isNotEmpty) {
          return {'type': 'gang', 'tile': tileCode(ks.first.$1)};
        }
        final disc = legalDiscards(seat);
        if (botLevel == 0) {
          return {'type': 'discard', 'tile': tileCode(disc[rng.nextInt(disc.length)])};
        }
        var bestT = disc.first;
        var bestScore = 1 << 20;
        for (final t in disc) {
          var v = tileValue(hands[seat], t);
          if (t == kChun) v += 8;
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
