import '../../src/engine.dart';
import 'tiles.dart';

class _XlSet {
  final int tile;
  final bool seq;
  const _XlSet(this.tile, this.seq);
}

void _xlDecomp(List<int> c, int i, List<_XlSet> cur, List<List<_XlSet>> out) {
  while (i < kNumKinds && c[i] == 0) {
    i++;
  }
  if (i >= kNumKinds) {
    out.add(List.of(cur));
    return;
  }
  if (c[i] >= 3) {
    c[i] -= 3;
    cur.add(_XlSet(i, false));
    _xlDecomp(c, i, cur, out);
    cur.removeLast();
    c[i] += 3;
  }
  if (i % 9 <= 6 && c[i + 1] > 0 && c[i + 2] > 0) {
    c[i]--;
    c[i + 1]--;
    c[i + 2]--;
    cur.add(_XlSet(i, true));
    _xlDecomp(c, i, cur, out);
    cur.removeLast();
    c[i]++;
    c[i + 1]++;
    c[i + 2]++;
  }
}

bool _xlCanSets(List<int> c, int i) {
  while (i < kNumKinds && c[i] == 0) {
    i++;
  }
  if (i >= kNumKinds) return true;
  if (c[i] >= 3) {
    c[i] -= 3;
    final ok = _xlCanSets(c, i);
    c[i] += 3;
    if (ok) return true;
  }
  if (i % 9 <= 6 && c[i + 1] > 0 && c[i + 2] > 0) {
    c[i]--;
    c[i + 1]--;
    c[i + 2]--;
    final ok = _xlCanSets(c, i);
    c[i]++;
    c[i + 1]++;
    c[i + 2]++;
    if (ok) return true;
  }
  return false;
}

bool xueliuIsWin(List<int> c, int meldCount, {int que = -1}) {
  var total = 0;
  for (var t = 0; t < kNumKinds; t++) {
    if (c[t] > 0 && suitOf(t) == que) return false;
    total += c[t];
  }
  if (total % 3 != 2) return false;
  if (meldCount == 0 && total == 14 && c.take(kNumKinds).every((x) => x.isEven)) return true;
  final w = List<int>.of(c);
  for (var t = 0; t < kNumKinds; t++) {
    if (w[t] >= 2) {
      w[t] -= 2;
      final ok = _xlCanSets(w, 0);
      w[t] += 2;
      if (ok) return true;
    }
  }
  return false;
}

class XueliuFanResult {
  final int fan;
  final List<(String, int)> items;
  const XueliuFanResult(this.fan, this.items);

  List<List<Object>> toJson() => [for (final (n, f) in items) [n, f]];
}

XueliuFanResult? xueliuEvaluate(List<int> concealed, List<Meld> melds, {int que = -1}) {
  if (!xueliuIsWin(concealed, melds.length, que: que)) return null;
  final all = List<int>.of(concealed);
  for (final m in melds) {
    all[m.tile] += m.size;
  }
  final suits = <int>{for (var t = 0; t < kNumKinds; t++) if (all[t] > 0) suitOf(t)};
  final qing = suits.length == 1;
  final gen = all.take(kNumKinds).where((x) => x == 4).length;

  XueliuFanResult? best;
  void consider(XueliuFanResult r) {
    if (best == null || r.fan > best!.fan) best = r;
  }

  final total = concealed.take(kNumKinds).fold<int>(0, (a, b) => a + b);
  if (melds.isEmpty && total == 14 && concealed.take(kNumKinds).every((x) => x.isEven)) {
    final items = <(String, int)>[];
    var extraGen = gen;
    if (qing && gen > 0) {
      items.add(('清龙七对', 5));
      extraGen--;
    } else if (qing) {
      items.add(('清七对', 4));
    } else if (gen > 0) {
      items.add(('龙七对', 3));
      extraGen--;
    } else {
      items.add(('七对', 2));
    }
    if (extraGen > 0) items.add(('根', extraGen));
    consider(XueliuFanResult(items.fold(0, (a, e) => a + e.$2), items));
  }

  final w = List<int>.of(concealed);
  for (var p = 0; p < kNumKinds; p++) {
    if (w[p] < 2) continue;
    w[p] -= 2;
    final outs = <List<_XlSet>>[];
    _xlDecomp(w, 0, [], outs);
    w[p] += 2;
    for (final sets in outs) {
      final allTrip = sets.every((s) => !s.seq);
      bool term(int t) => rankOf(t) == 1 || rankOf(t) == 9;
      final yaojiu = term(p) &&
          melds.every((m) => term(m.tile)) &&
          sets.every((s) => s.seq ? (rankOf(s.tile) == 1 || rankOf(s.tile) == 7) : term(s.tile));
      final jiang = allTrip && is258(p) && melds.every((m) => is258(m.tile)) && sets.every((s) => is258(s.tile));
      final items = <(String, int)>[];
      if (jiang) {
        items.add(('将对', 3));
        if (qing) items.add(('清一色', 2));
      } else if (allTrip && qing) {
        items.add(('清对', 3));
      } else if (allTrip) {
        items.add(('对对胡', 1));
      } else if (qing) {
        items.add(('清一色', 2));
      }
      if (yaojiu) items.add(('带幺九', 2));
      if (items.isEmpty) items.add(('平胡', 0));
      if (gen > 0) items.add(('根', gen));
      consider(XueliuFanResult(items.fold(0, (a, e) => a + e.$2), items));
    }
  }
  return best;
}

List<int> xueliuWaits(List<int> concealed, List<Meld> melds, {int que = -1}) {
  final out = <int>[];
  for (var t = 0; t < kNumKinds; t++) {
    if (suitOf(t) == que) continue;
    concealed[t]++;
    if (xueliuIsWin(concealed, melds.length, que: que)) out.add(t);
    concealed[t]--;
  }
  return out;
}

class _XlClaim {
  final int tile;
  final int from;
  final bool qiang;
  final Map<int, Set<String>> opts;
  final Map<int, String> resp = {};
  _XlClaim(this.tile, this.from, this.qiang, this.opts);
  List<int> get pending => [for (final s in opts.keys) if (!resp.containsKey(s)) s]..sort();
}

class _XlDiscard {
  final int tile;
  bool taken = false;
  bool afterKong;
  final bool tsumogiri;
  _XlDiscard(this.tile, this.afterKong, {this.tsumogiri = false});
}

/// 血流成河麻将
class XueliuGame extends GameEngine {
  XueliuGame(super.setup);

  late final int totalHands = setup.opt<int>('hands', 4);
  late final bool swapOn = setup.opt<bool>('swap', true);
  late final int cap = setup.opt<int>('cap', 5);

  late List<int> scores = List.filled(players, 0);
  int handNo = 0;
  int dealer = 0;
  bool over = false;
  List<Map<String, dynamic>> history = [];

  // Hand state: 'swap', 'dingque', 'play', 'claim', 'settle', 'over', 'pause'
  String phase = 'swap';
  String pausedPhase = '';
  List<List<int>> hands = [];
  List<List<Meld>> melds = [];
  List<List<_XlDiscard>> discards = [];
  List<int> que = []; // 0=m, 1=p, 2=s
  List<String> queSuit = []; // 'm', 'p', 's'
  List<bool> locked = []; // locked after first win; stays in game!
  List<int> winCounts = [];
  List<List<String>> winTiles = [];
  List<int> drawn = [];
  List<int> wall = [];
  int turn = 0;
  bool canZimo = false;
  bool afterKong = false;
  bool anyCall = false;
  List<bool> firstTurn = [];
  _XlClaim? claim;
  int? pendingBuGang;
  int lastDiscardSeat = -1;

  // Swap / Dingque
  List<List<int>?> swapPick = [];
  List<List<int>> swapGot = [];
  int swapDir = 1; // 1 下家, 2 对家, 3 上家
  List<int?> quePick = [];

  // Settlement bookkeeping
  List<int> handDelta = [];
  List<Map<String, dynamic>> events = [];
  List<(int owner, int payer, int amount)> kongMoney = [];
  Map<String, dynamic>? settle;
  Set<int> ready = {};
  int nextDealer = -1;
  int totalWinEvents = 0;
  String lastAction = '';
  Map<String, dynamic>? lastEvent;
  int eventSeq = 0;

  void _event(String t, int seat, [int tile = -1]) {
    lastEvent = {'t': t, 'seat': seat, if (tile >= 0) 'tile': tileCode(tile)};
    eventSeq++;
  }

  int get _capPts => 1 << cap;

  @override
  void start() {
    dealer = rng.nextInt(players);
    _startHand();
  }

  void _startHand() {
    handNo++;
    wall = <int>[for (var t = 0; t < kNumKinds; t++) for (var k = 0; k < 4; k++) t]..shuffle(rng);
    hands = List.generate(players, (_) => List.filled(kNumKinds, 0));
    melds = List.generate(players, (_) => <Meld>[]);
    discards = List.generate(players, (_) => <_XlDiscard>[]);
    que = List.filled(players, -1);
    queSuit = List.filled(players, '');
    locked = List.filled(players, false);
    winCounts = List.filled(players, 0);
    winTiles = List.generate(players, (_) => <String>[]);
    drawn = List.filled(players, -1);
    firstTurn = List.filled(players, true);
    handDelta = List.filled(players, 0);
    events = [];
    kongMoney = [];
    settle = null;
    claim = null;
    pendingBuGang = null;
    anyCall = false;
    afterKong = false;
    nextDealer = -1;
    totalWinEvents = 0;
    lastDiscardSeat = -1;

    for (var i = 0; i < 13; i++) {
      for (var s = 0; s < players; s++) {
        hands[s][wall.removeLast()]++;
      }
    }
    final extra = wall.removeLast();
    hands[dealer][extra]++;
    drawn[dealer] = extra;
    turn = dealer;
    swapPick = List.filled(players, null);
    swapGot = List.generate(players, (_) => <int>[]);
    quePick = List.filled(players, null);
    host.log('第 $handNo/$totalHands 局开始，${name(dealer)} 坐庄');
    if (swapOn) {
      phase = 'swap';
      swapDir = const [1, 2, 3][rng.nextInt(3)];
      lastAction = '换三张：请选择三张同花色的牌';
    } else {
      _enterDingque();
    }
  }

  void _enterDingque() {
    phase = 'dingque';
    lastAction = '请选择定缺花色';
  }

  static const _dirNames = {1: '换给下家', 2: '换给对家', 3: '换给上家'};

  void _doSwap() {
    for (var s = 0; s < players; s++) {
      for (final t in swapPick[s]!) {
        hands[s][t]--;
      }
    }
    for (var s = 0; s < players; s++) {
      final to = (s + swapDir) % players;
      for (final t in swapPick[s]!) {
        hands[to][t]++;
      }
      swapGot[to] = List.of(swapPick[s]!);
    }
    if (drawn[dealer] >= 0 && hands[dealer][drawn[dealer]] == 0) drawn[dealer] = -1;
    host.log('换三张：${_dirNames[swapDir]}');
    _enterDingque();
  }

  void _startPlay() {
    for (var s = 0; s < players; s++) {
      que[s] = quePick[s]!;
      queSuit[s] = suitLetters[que[s]];
    }
    host.log('定缺：${[for (var s = 0; s < players; s++) '${name(s)}缺${suitNames[que[s]]}'].join('，')}');
    phase = 'play';
    turn = dealer;
    canZimo = true;
    afterKong = false;
    lastAction = '${name(dealer)} 庄家出牌';
  }

  bool hasQueTile(int s) {
    final q = que[s];
    if (q < 0) return false;
    for (var r = 0; r < 9; r++) {
      if (hands[s][q * 9 + r] > 0) return true;
    }
    return false;
  }

  bool _draw(int s, {bool kong = false}) {
    if (wall.isEmpty) {
      _endHand();
      return false;
    }
    final t = wall.removeLast();
    hands[s][t]++;
    drawn[s] = t;
    turn = s;
    phase = 'play';
    canZimo = true;
    afterKong = kong;
    return true;
  }

  bool canHuWith(int s, int t) {
    if (suitOf(t) == que[s]) return false;
    hands[s][t]++;
    final ok = xueliuIsWin(hands[s], melds[s].length, que: que[s]);
    hands[s][t]--;
    return ok;
  }

  bool get canSelfHu =>
      phase == 'play' && canZimo && xueliuIsWin(hands[turn], melds[turn].length, que: que[turn]);

  /// Whether a locked player can declare an暗杠 on [t] without changing their waits.
  bool _lockedAnGangOk(int s, int t) {
    if (hands[s][t] < 4 || suitOf(t) == que[s]) return false;
    final d = drawn[s];
    if (d < 0 || hands[s][d] <= 0) return false;
    // Waits before drawing d
    hands[s][d]--;
    final beforeWaits = xueliuWaits(hands[s], melds[s], que: que[s]);
    hands[s][d]++;
    if (beforeWaits.isEmpty) return false;
    // Waits after removing 4 of t and adding agang
    hands[s][t] -= 4;
    final afterMelds = [...melds[s], Meld('agang', t)];
    final afterWaits = xueliuWaits(hands[s], afterMelds, que: que[s]);
    hands[s][t] += 4;
    if (afterWaits.length != beforeWaits.length) return false;
    for (var i = 0; i < beforeWaits.length; i++) {
      if (beforeWaits[i] != afterWaits[i]) return false;
    }
    return true;
  }

  /// Tiles the turn player may kong now: (tile, isBuGang).
  List<(int, bool)> selfKongs() {
    if (phase != 'play' || wall.isEmpty) return const [];
    final s = turn;
    final out = <(int, bool)>[];
    for (var t = 0; t < kNumKinds; t++) {
      if (suitOf(t) == que[s]) continue;
      if (locked[s]) {
        // Locked player can upgrade an existing peng if t == drawn[s],
        // or declare agang if it does not change waits.
        if (t == drawn[s] && hands[s][t] >= 1 && melds[s].any((m) => m.isPeng && m.tile == t)) {
          out.add((t, true));
        } else if (hands[s][t] == 4 && _lockedAnGangOk(s, t)) {
          out.add((t, false));
        }
      } else {
        if (hands[s][t] == 4) out.add((t, false));
        if (hands[s][t] >= 1 && melds[s].any((m) => m.isPeng && m.tile == t)) out.add((t, true));
      }
    }
    return out;
  }

  List<int> legalDiscards([int? seat]) {
    final s = seat ?? turn;
    if (locked[s] && drawn[s] >= 0 && hands[s][drawn[s]] > 0) {
      return [drawn[s]];
    }
    final q = hasQueTile(s);
    return [
      for (var t = 0; t < kNumKinds; t++)
        if (hands[s][t] > 0 && (!q || suitOf(t) == que[s])) t
    ];
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
      case 'swap':
        return [for (var s = 0; s < players; s++) if (swapPick[s] == null) s];
      case 'dingque':
        return [for (var s = 0; s < players; s++) if (quePick[s] == null) s];
      case 'play':
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
      case 'swap':
        if (type != 'swap') throw GameError('请先换三张');
        if (swapPick[seat] != null) throw GameError('你已经选好了');
        final ts = [for (final c in (a['tiles'] is List ? a['tiles'] as List : const [])) tileFromCode(c)];
        if (ts.length != 3 || ts.any((t) => t < 0 || t >= kNumKinds)) throw GameError('请选择三张牌');
        if (ts.map(suitOf).toSet().length != 1) throw GameError('三张牌必须是同一花色');
        final c = countsOf(ts, kNumKinds);
        for (var t = 0; t < kNumKinds; t++) {
          if (c[t] > hands[seat][t]) throw GameError('你没有这些牌');
        }
        swapPick[seat] = ts;
        if (swapPick.every((p) => p != null)) _doSwap();
        return;
      case 'dingque':
        if (type != 'dingque' && type != 'que') throw GameError('请先定缺');
        if (quePick[seat] != null) throw GameError('你已经定缺了');
        final su = suitFromCodeOrIndex(a['suit']);
        if (su < 0 || su > 2) throw GameError('无效花色（请选择 m/p/s）');
        quePick[seat] = su;
        if (quePick.every((p) => p != null)) _startPlay();
        return;
      case 'play':
        if (seat != turn) throw GameError('还没轮到你');
        _handlePlay(seat, type, a);
        return;
      case 'claim':
        _handleClaim(seat, type);
        return;
      case 'settle':
        if (type != 'next') throw GameError('请等待下一局');
        ready.add(seat);
        if (ready.length >= players) _nextHand();
        return;
    }
    throw GameError('现在不能操作');
  }

  void _handlePlay(int s, String type, Map<String, dynamic> a) {
    if (type == 'hu') {
      if (!canSelfHu) {
        if (hasQueTile(s)) throw GameError('手牌还有缺门（${suitNames[que[s]]}），不能胡牌');
        throw GameError('现在不能胡');
      }
      final t = drawn[s] >= 0 && hands[s][drawn[s]] > 0 ? drawn[s] : _anyTile(s);
      _win(s, -1, t);
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
      if (t < 0 || t >= kNumKinds || hands[s][t] == 0) throw GameError('你没有这张牌');
      if (locked[s] && drawn[s] >= 0 && t != drawn[s]) {
        throw GameError('已胡牌锁定，只能打出刚摸到的牌');
      }
      if (!locked[s] && hasQueTile(s) && suitOf(t) != que[s]) {
        throw GameError('必须先打完缺门（${suitNames[que[s]]}）');
      }
      _discard(s, t);
      return;
    }
    throw GameError('请出牌');
  }

  int _anyTile(int s) {
    for (var t = kNumKinds - 1; t >= 0; t--) {
      if (hands[s][t] > 0) return t;
    }
    return 0;
  }

  void _discard(int s, int t) {
    hands[s][t]--;
    final giri = drawn[s] == t;
    drawn[s] = -1;
    discards[s].add(_XlDiscard(t, afterKong, tsumogiri: giri));
    firstTurn[s] = false;
    canZimo = false;
    afterKong = false;
    lastDiscardSeat = s;
    lastAction = '${name(s)} 打出 ${tileName(t)}';
    _event('discard', s, t);

    final opts = <int, Set<String>>{};
    for (var o = 0; o < players; o++) {
      if (o == s) continue;
      final set = <String>{};
      if (canHuWith(o, t)) set.add('hu');
      if (!locked[o] && wall.isNotEmpty && suitOf(t) != que[o]) {
        if (hands[o][t] >= 2) set.add('peng');
        if (hands[o][t] >= 3) set.add('gang');
      }
      if (set.isNotEmpty) opts[o] = set;
    }
    if (opts.isEmpty) {
      _coverPause(() => _afterNoClaim(s));
    } else {
      claim = _XlClaim(t, s, false, opts);
      phase = 'claim';
    }
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

  void _afterNoClaim(int from) {
    claim = null;
    if (wall.isEmpty) {
      _endHand();
      return;
    }
    _draw((from + 1) % players);
  }

  void _handleClaim(int s, String type) {
    final c = claim!;
    final o = c.opts[s];
    if (o == null) throw GameError('你没有可执行的操作');
    if (c.resp.containsKey(s)) throw GameError('你已经选择了');
    if (type != 'pass' && !o.contains(type)) throw GameError('不能执行该操作');
    c.resp[s] = type;
    final pend = c.pending;
    final huDeclared = c.resp.values.contains('hu');
    if (pend.isNotEmpty) {
      final pendCanHu = pend.any((p) => c.opts[p]!.contains('hu'));
      if (pendCanHu) return;
      if (!huDeclared) return;
    }
    _resolveClaim();
  }

  void _resolveClaim() {
    final c = claim!;
    claim = null;
    final hus = [
      for (var i = 1; i < players; i++)
        if (c.resp[(c.from + i) % players] == 'hu') (c.from + i) % players
    ];
    if (hus.isNotEmpty) {
      if (c.qiang) {
        hands[c.from][c.tile]--;
        pendingBuGang = null;
      } else {
        discards[c.from].last.taken = true;
      }
      final multi = hus.length > 1;
      if (multi) host.log('一炮多响！');
      for (final h in hus) {
        _win(h, c.from, c.tile, qiang: c.qiang, multi: multi, continueFlow: false);
      }
      if (wall.isEmpty) {
        _endHand();
        return;
      }
      _draw((hus.last + 1) % players);
      return;
    }
    if (c.qiang) {
      _finishBuGang(c.from, c.tile);
      return;
    }
    for (final e in c.resp.entries) {
      if (e.value == 'gang' || e.value == 'peng') {
        final s = e.key;
        discards[c.from].last.taken = true;
        anyCall = true;
        if (e.value == 'gang') {
          hands[s][c.tile] -= 3;
          melds[s].add(Meld('mgang', c.tile, claimed: c.tile, from: c.from));
          _payKong(s, [(c.from, 2)]);
          host.log('${name(s)} 明杠 ${tileName(c.tile)}（刮风下雨）');
          lastAction = '${name(s)} 明杠 ${tileName(c.tile)}';
          _event('gang', s, c.tile);
          _draw(s, kong: true);
        } else {
          hands[s][c.tile] -= 2;
          melds[s].add(Meld('peng', c.tile, claimed: c.tile, from: c.from));
          turn = s;
          phase = 'play';
          canZimo = false;
          afterKong = false;
          drawn[s] = -1;
          lastAction = '${name(s)} 碰 ${tileName(c.tile)}';
          _event('peng', s, c.tile);
        }
        return;
      }
    }
    _afterNoClaim(c.from);
  }

  void _selfKong(int s, int t, bool bu) {
    anyCall = true;
    if (bu) {
      _event('bugang', s, t);
      final opts = <int, Set<String>>{};
      for (var o = 0; o < players; o++) {
        if (o != s && canHuWith(o, t)) opts[o] = {'hu'};
      }
      if (opts.isNotEmpty) {
        pendingBuGang = t;
        claim = _XlClaim(t, s, true, opts);
        phase = 'claim';
        lastAction = '${name(s)} 补杠 ${tileName(t)}';
        return;
      }
      _finishBuGang(s, t);
      return;
    }
    _event('angang', s);
    hands[s][t] -= 4;
    melds[s].add(Meld('agang', t));
    _payKong(s, [for (var o = 0; o < players; o++) if (o != s) (o, 2)]);
    host.log('${name(s)} 暗杠（下雨）');
    lastAction = '${name(s)} 暗杠';
    _draw(s, kong: true);
  }

  void _finishBuGang(int s, int t) {
    pendingBuGang = null;
    hands[s][t]--;
    melds[s].firstWhere((m) => m.isPeng && m.tile == t).kind = 'bgang';
    _payKong(s, [for (var o = 0; o < players; o++) if (o != s) (o, 1)]);
    host.log('${name(s)} 补杠 ${tileName(t)}（刮风）');
    lastAction = '${name(s)} 补杠 ${tileName(t)}';
    _draw(s, kong: true);
  }

  void _payKong(int owner, List<(int, int)> payers) {
    var total = 0;
    for (final (p, amt) in payers) {
      handDelta[p] -= amt;
      scores[p] -= amt;
      kongMoney.add((owner, p, amt));
      total += amt;
    }
    handDelta[owner] += total;
    scores[owner] += total;
    events.add({
      'kind': 'gang',
      'seat': owner,
      'text': '${name(owner)} 杠牌 +$total',
      'pay': {for (final (p, amt) in payers) '$p': amt},
    });
  }

  void _win(int s, int from, int tile, {bool qiang = false, bool multi = false, bool continueFlow = true}) {
    final zimo = from < 0;
    final c = List<int>.of(hands[s]);
    if (!zimo) c[tile]++;
    final pat = xueliuEvaluate(c, melds[s], que: que[s]);
    if (pat == null) throw GameError('不能胡');
    final items = <(String, int)>[...pat.items];
    if (zimo && firstTurn[s] && !anyCall && s == dealer) items.insert(0, ('天胡', cap));
    if (zimo && firstTurn[s] && !anyCall && s != dealer && discards[s].isEmpty) items.insert(0, ('地胡', cap));
    if (zimo && afterKong) items.add(('杠上开花', 1));
    if (!zimo && !qiang && discards[from].isNotEmpty && discards[from].last.afterKong) items.add(('杠上炮', 1));
    if (qiang) items.add(('抢杠胡', 1));
    if (zimo && wall.isEmpty) items.add(('海底捞月', 1));
    if (zimo) items.add(('自摸加番', 1));
    final fan = items.fold<int>(0, (a, e) => a + e.$2);
    final capped = fan > cap ? cap : fan;
    final pts = 1 << capped;

    // In Xueliu Chenghe, all 3 other players stay in the game and pay on zimo!
    final payers = zimo ? [for (var o = 0; o < players; o++) if (o != s) o] : [from];
    for (final p in payers) {
      handDelta[p] -= pts;
      scores[p] -= pts;
    }
    handDelta[s] += pts * payers.length;
    scores[s] += pts * payers.length;

    totalWinEvents++;
    winCounts[s]++;
    locked[s] = true;
    winTiles[s].add(tileCode(tile));
    if (zimo) {
      // Remove the drawn winning tile so hands[s] stays at 3n+1 tenpai tiles!
      hands[s][tile]--;
    }
    drawn[s] = -1;
    if (nextDealer < 0) nextDealer = (multi && !zimo) ? from : s;
    final fanNames = [for (final (n, f) in items) f > 0 && n != '平胡' ? '$n$f番' : n].join(' ');
    events.add({
      'kind': 'hu',
      'seat': s,
      'from': from,
      'tile': tileCode(tile),
      'zimo': zimo,
      'order': totalWinEvents,
      'winCount': winCounts[s],
      'fan': fan,
      'capped': fan > cap,
      'items': [for (final (n, f) in items) [n, f]],
      'points': pts,
      'total': pts * payers.length,
      'pay': {for (final p in payers) '$p': pts},
    });
    host.log(zimo
        ? '${name(s)} 自摸 ${tileName(tile)}（第${winCounts[s]}胡）！$fanNames，每家 $pts 分'
        : '${name(s)} 胡 ${name(from)} 的 ${tileName(tile)}（第${winCounts[s]}胡）！$fanNames，$pts 分');
    lastAction = zimo ? '${name(s)} 自摸（第${winCounts[s]}胡）' : '${name(s)} 胡牌（第${winCounts[s]}胡）';
    _event(zimo ? 'zimo' : 'hu', s, tile);

    if (!continueFlow) return;
    if (wall.isEmpty) {
      _endHand();
      return;
    }
    _draw((s + 1) % players);
  }

  /// Perform 查花猪 / 查大叫 / 退税 at wall exhaustion.
  List<Map<String, dynamic>> settleExhaustiveChecks() {
    final chajiao = <Map<String, dynamic>>[];
    final hz = <int>{for (var s = 0; s < players; s++) if (hasQueTile(s)) s};
    final tenFan = <int, int>{};
    for (var s = 0; s < players; s++) {
      if (hz.contains(s)) continue;
      final f = _tenpaiFan(s);
      if (f >= 0) tenFan[s] = f;
    }
    void pay(int from, int to, int amt, String why) {
      handDelta[from] -= amt;
      scores[from] -= amt;
      handDelta[to] += amt;
      scores[to] += amt;
      chajiao.add({'from': from, 'to': to, 'amount': amt, 'why': why});
    }

    // 1. 查花猪: players still holding forbidden queSuit pay _capPts to non-huazhu players
    for (final h in hz) {
      for (var o = 0; o < players; o++) {
        if (!hz.contains(o)) pay(h, o, _capPts, '查花猪');
      }
    }
    // 2. 查大叫: non-tenpai (and non-huazhu) players pay max wait fan to tenpai players
    for (var s = 0; s < players; s++) {
      if (hz.contains(s) || tenFan.containsKey(s)) continue;
      for (final e in tenFan.entries) {
        final f = e.value > cap ? cap : e.value;
        pay(s, e.key, 1 << f, '查大叫');
      }
    }
    // 3. 退税: non-tenpai players refund kong money
    for (var s = 0; s < players; s++) {
      if (tenFan.containsKey(s)) continue;
      for (final (owner, payer, amt) in kongMoney) {
        if (owner == s) pay(s, payer, amt, '退税');
      }
    }
    return chajiao;
  }

  void _endHand() {
    if (phase == 'settle' || phase == 'over') return;
    claim = null;
    final chajiao = settleExhaustiveChecks();
    host.log('牌墙摸完，血流成河本局结束（共 $totalWinEvents 次胡牌）');
    settle = {
      'hand': handNo,
      'exhausted': true,
      'events': events,
      'chajiao': chajiao,
      'delta': List.of(handDelta),
      'tenpai': [for (var s = 0; s < players; s++) !hasQueTile(s) && _tenpaiFan(s) >= 0],
      'huazhu': [for (var s = 0; s < players; s++) hasQueTile(s)],
      'winCounts': List.of(winCounts),
    };
    history.add({'hand': handNo, 'delta': List.of(handDelta)});
    ready = {};
    if (handNo >= totalHands) {
      phase = 'over';
      over = true;
      final order = List.generate(players, (i) => i)..sort((a, b) => scores[b].compareTo(scores[a]));
      host.log('全部 $totalHands 局结束！${[
        for (var i = 0; i < order.length; i++) '第${i + 1} ${name(order[i])} ${scores[order[i]]}'
      ].join('，')}');
    } else {
      phase = 'settle';
    }
  }

  int _tenpaiFan(int s) {
    final c = hands[s];
    final w = xueliuWaits(c, melds[s], que: que[s]);
    var best = -1;
    for (final t in w) {
      c[t]++;
      final r = xueliuEvaluate(c, melds[s], que: que[s]);
      c[t]--;
      if (r != null && r.fan > best) best = r.fan;
    }
    return best;
  }

  void _nextHand() {
    if (nextDealer >= 0) dealer = nextDealer;
    _startHand();
  }

  int _fewestSuit(List<int> c) {
    final counts = [0, 0, 0];
    for (var s = 0; s < 3; s++) {
      for (var r = 0; r < 9; r++) {
        counts[s] += c[s * 9 + r];
      }
    }
    var bestS = 0;
    for (var s = 1; s < 3; s++) {
      if (counts[s] < counts[bestS]) bestS = s;
    }
    return bestS;
  }

  List<int> _botSwap(int s) {
    final c = hands[s];
    final suitTiles = List.generate(3, (_) => <int>[]);
    for (var su = 0; su < 3; su++) {
      for (var r = 0; r < 9; r++) {
        final t = su * 9 + r;
        for (var k = 0; k < c[t]; k++) {
          suitTiles[su].add(t);
        }
      }
    }
    final validSuits = [for (var su = 0; su < 3; su++) if (suitTiles[su].length >= 3) su];
    validSuits.sort((a, b) => suitTiles[a].length.compareTo(suitTiles[b].length));
    final chosenSuit = validSuits.first;
    final list = suitTiles[chosenSuit]..sort((a, b) => tileValue(c, a).compareTo(tileValue(c, b)));
    return list.take(3).toList();
  }

  @override
  Map<String, dynamic> view(int seat) {
    final reveal = phase == 'settle' || phase == 'over';
    final seats = <Map<String, dynamic>>[];
    for (var s = 0; s < players; s++) {
      final showHand = s == seat || reveal;
      final n = countTotal(hands[s]);
      final hasDrawn = phase == 'play' && turn == s && drawn[s] >= 0 && hands[s][drawn[s]] > 0;
      seats.add({
        'count': n,
        'drawn': hasDrawn,
        'hand': showHand ? codesOfCounts(hands[s]) : null,
        'melds': [
          for (final m in melds[s])
            m.toJson(hide: m.concealed && !showHand)
        ],
        'discards': [
          for (final d in discards[s]) {'t': tileCode(d.tile), 'taken': d.taken, 'tg': d.tsumogiri}
        ],
        'que': phase == 'dingque' || phase == 'swap' ? -1 : que[s],
        'queSuit': phase == 'dingque' || phase == 'swap' ? '' : queSuit[s],
        'queDone': quePick.length > s && quePick[s] != null,
        'swapDone': swapPick.length > s && swapPick[s] != null,
        'locked': locked[s],
        'won': winCounts[s],
        'winCount': winCounts[s],
        'winTiles': winTiles[s],
        'winTile': winTiles[s].isNotEmpty ? winTiles[s].last : null,
        'score': scores[s],
        'delta': handDelta[s],
      });
    }
    final v = <String, dynamic>{
      'rule': 'xueliu',
      'phase': phase == 'pause' ? 'claim' : phase,
      'hand': handNo,
      'hands': totalHands,
      'dealer': dealer,
      'turn': turn,
      'wall': wall.length,
      'cap': cap,
      'swapOn': swapOn,
      'swapDir': phase == 'swap' ? 0 : swapDir,
      'queSuit': [for (var s = 0; s < players; s++) phase == 'dingque' || phase == 'swap' ? '' : queSuit[s]],
      'locked': List.of(locked),
      'winCounts': List.of(winCounts),
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
      v['claimQiang'] = claim!.qiang;
    } else if (phase == 'pause' && lastDiscardSeat >= 0 && discards[lastDiscardSeat].isNotEmpty) {
      v['claimTile'] = tileCode(discards[lastDiscardSeat].last.tile);
      v['claimFrom'] = lastDiscardSeat;
      v['claimQiang'] = false;
    }
    if (over) {
      final order = List.generate(players, (i) => i)..sort((a, b) => scores[b].compareTo(scores[a]));
      v['ranking'] = order;
    }
    if (seat >= 0 && seat < players) {
      final my = <String, dynamic>{
        'drawn': phase == 'play' && turn == seat && drawn[seat] >= 0 && hands[seat][drawn[seat]] > 0
            ? tileCode(drawn[seat])
            : null,
        'swapGot': [for (final t in swapGot[seat]) tileCode(t)],
        'swapPick': swapPick[seat] == null ? null : [for (final t in swapPick[seat]!) tileCode(t)],
        'quePick': quePick[seat],
      };
      if (phase == 'dingque' && quePick[seat] == null) my['queHint'] = _fewestSuit(hands[seat]);
      if (phase == 'swap' && swapPick[seat] == null) my['swapHint'] = [for (final t in _botSwap(seat)) tileCode(t)];
      if (phase == 'play' && turn == seat) {
        my['canHu'] = canSelfHu;
        my['kongs'] = [for (final (t, _) in selfKongs()) tileCode(t)];
        my['discardable'] = [for (final t in legalDiscards(seat)) tileCode(t)];
      }
      if (phase == 'claim' && claim!.opts.containsKey(seat) && !claim!.resp.containsKey(seat)) {
        my['claim'] = claim!.opts[seat]!.toList();
      }
      if (que[seat] >= 0 && phase != 'dingque' && phase != 'swap' && !hasQueTile(seat)) {
        final n = countTotal(hands[seat]);
        if (n % 3 == 1) {
          my['waits'] = [for (final t in xueliuWaits(hands[seat], melds[seat], que: que[seat])) tileCode(t)];
        }
      }
      v['me'] = my;
    }
    return v;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    switch (phase) {
      case 'swap':
        if (swapPick[seat] != null) return null;
        return {
          'type': 'swap',
          'tiles': [for (final t in _botSwap(seat)) tileCode(t)],
        };
      case 'dingque':
        if (quePick[seat] != null) return null;
        final su = _fewestSuit(hands[seat]);
        return {'type': 'dingque', 'suit': suitLetters[su]};
      case 'settle':
        return {'type': 'next'};
      case 'claim':
        final c = claim!;
        final opts = c.opts[seat];
        if (opts == null || c.resp.containsKey(seat)) return null;
        if (opts.contains('hu')) return {'type': 'hu'};
        if (opts.contains('gang')) return {'type': 'gang'};
        if (opts.contains('peng') && !hasQueTile(seat) && hands[seat][c.tile] == 2) {
          return {'type': 'peng'};
        }
        return {'type': 'pass'};
      case 'play':
        if (seat != turn) return null;
        if (canSelfHu) return {'type': 'hu'};
        final ks = selfKongs();
        if (ks.isNotEmpty) {
          return {'type': 'gang', 'tile': tileCode(ks.first.$1)};
        }
        final disc = legalDiscards(seat);
        var bestT = disc.first;
        var bestScore = 1 << 20;
        for (final t in disc) {
          final v = suitOf(t) == que[seat] ? -100 : tileValue(hands[seat], t);
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
