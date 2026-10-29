import '../../src/engine.dart';

/// 东北红十（抓红十）：4~6 人，一副牌去掉部分小牌以均分。
/// 持有 ♥10 (TH) 与 ♦10 (TD) 的玩家为红十方（若同在一人手中则 1 打众），其余为黑十（平民）方。
/// 阶段：'declare'（亮十/暗打）-> 'play'（出牌爬阶）-> 'roundEnd' / 'over'。

bool hsIsRedTen(String c) => c == 'TH' || c == 'TD';

/// 点数排序：3..9 -> 3..9, 黑10(TS/TC) -> 10, J->11, Q->12, K->13, A->14, 2->15, BJ->16, RJ->17, 红十(TD/TH)->18
int hsRank(String c) {
  if (c == 'TH' || c == 'TD') return 18;
  if (c == 'RJ') return 17;
  if (c == 'BJ') return 16;
  if (c.isEmpty) return 0;
  final r = c[0];
  const order = '3456789TJQKA2';
  final idx = order.indexOf(r);
  return idx >= 0 ? idx + 3 : 0;
}

int _suitOrder(String c) {
  if (c == 'TH') return 5;
  if (c == 'TD') return 4;
  if (c == 'RJ') return 5;
  if (c == 'BJ') return 4;
  if (c.length < 2) return 0;
  return switch (c[c.length - 1]) {
    'S' => 3,
    'H' => 2,
    'C' => 1,
    'D' => 0,
    _ => 0,
  };
}

void hsSort(List<String> cards) {
  cards.sort((a, b) {
    final ra = hsRank(a), rb = hsRank(b);
    if (ra != rb) return rb - ra; // 从大到小排列便于查看
    return _suitOrder(b) - _suitOrder(a);
  });
}

String hsRankName(int r) => switch (r) {
      18 => '红十',
      17 => '大王',
      16 => '小王',
      15 => '2',
      14 => 'A',
      13 => 'K',
      12 => 'Q',
      11 => 'J',
      10 => '10',
      _ => '$r',
    };

class HsCombo {
  /// 'single' | 'pair' | 'triple' | 'straight' | 'bomb' | 'joker_bomb' | 'red_ten_bomb'
  final String type;
  final int rank;
  final int length;
  final String label;

  const HsCombo(this.type, this.rank, this.length, this.label);

  int get bombTier => switch (type) {
        'red_ten_bomb' => 3,
        'joker_bomb' => 2,
        'bomb' => 1,
        _ => 0,
      };

  bool get isBomb => bombTier > 0;

  bool beats(HsCombo other) {
    if (isBomb && !other.isBomb) return true;
    if (!isBomb && other.isBomb) return false;
    if (isBomb && other.isBomb) {
      if (bombTier != other.bombTier) return bombTier > other.bombTier;
      if (length != other.length) return length > other.length;
      return rank > other.rank;
    }
    if (type != other.type || length != other.length) return false;
    return rank > other.rank;
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'rank': rank,
        'length': length,
        'label': label,
        'bomb': isBomb,
      };

  static HsCombo? fromJson(Object? m) {
    if (m is! Map) return null;
    return HsCombo(
      asStr(m['type']),
      asInt(m['rank']),
      asInt(m['length']),
      asStr(m['label']),
    );
  }
}

/// 识别红十牌型：单张、对子、三张、顺子（5张及以上，3..A）、四张炸弹、双王炸、双红十王炸。
HsCombo? hsClassify(List<String> cards) {
  final n = cards.length;
  if (n == 0) return null;
  if (n == 1) {
    final r = hsRank(cards[0]);
    if (r <= 0) return null;
    return HsCombo('single', r, 1, '单${hsRankName(r)}');
  }
  if (n == 2) {
    final s = cards.toSet();
    if (s.contains('TH') && s.contains('TD')) {
      return const HsCombo('red_ten_bomb', 20, 2, '双红十王炸');
    }
    if (s.contains('BJ') && s.contains('RJ')) {
      return const HsCombo('joker_bomb', 19, 2, '双王炸');
    }
    final r0 = hsRank(cards[0]), r1 = hsRank(cards[1]);
    if (r0 == r1 && r0 >= 3 && r0 <= 15) {
      return HsCombo('pair', r0, 2, '对${hsRankName(r0)}');
    }
    return null;
  }
  if (n == 3) {
    final r0 = hsRank(cards[0]);
    if (r0 >= 3 && r0 <= 15 && cards.every((c) => hsRank(c) == r0)) {
      return HsCombo('triple', r0, 3, '三个${hsRankName(r0)}');
    }
    return null;
  }
  if (n == 4) {
    final r0 = hsRank(cards[0]);
    if (r0 >= 3 && r0 <= 15 && cards.every((c) => hsRank(c) == r0)) {
      return HsCombo('bomb', r0, 4, '四${hsRankName(r0)}炸弹');
    }
    return null;
  }
  if (n >= 5) {
    // 顺子：只允许 3..A (rank 3..14)，不含 2、大小王、红十
    final ranks = [for (final c in cards) hsRank(c)]..sort();
    if (ranks.any((r) => r < 3 || r > 14)) return null;
    for (var i = 1; i < ranks.length; i++) {
      if (ranks[i] != ranks[i - 1] + 1) return null;
    }
    return HsCombo('straight', ranks.last, n, '${hsRankName(ranks.first)}-${hsRankName(ranks.last)}顺子');
  }
  return null;
}

/// 生成手牌中的所有合法候选出牌（按从小到大排序）
List<List<String>> hsCandidates(List<String> hand, [HsCombo? target]) {
  final byRank = <int, List<String>>{};
  for (final c in hand) {
    final r = hsRank(c);
    (byRank[r] ??= []).add(c);
  }
  final ranks = byRank.keys.toList()..sort();
  final all = <List<String>>[];

  // 单张
  for (final r in ranks) {
    for (final c in byRank[r]!) {
      all.add([c]);
      break; // 同点数取一张代表即可，红十若两张不同花色取一张即可
    }
  }
  // 对子
  for (final r in ranks) {
    if (r >= 3 && r <= 15 && byRank[r]!.length >= 2) {
      all.add(byRank[r]!.sublist(0, 2));
    }
  }
  // 三张
  for (final r in ranks) {
    if (r >= 3 && r <= 15 && byRank[r]!.length >= 3) {
      all.add(byRank[r]!.sublist(0, 3));
    }
  }
  // 顺子 (5..12 张)
  final seqRanks = ranks.where((r) => r >= 3 && r <= 14).toList();
  for (var len = 5; len <= seqRanks.length; len++) {
    for (var i = 0; i + len <= seqRanks.length; i++) {
      if (seqRanks[i + len - 1] - seqRanks[i] == len - 1) {
        all.add([for (var k = 0; k < len; k++) byRank[seqRanks[i + k]]!.first]);
      }
    }
  }
  // 四张炸弹
  for (final r in ranks) {
    if (r >= 3 && r <= 15 && byRank[r]!.length == 4) {
      all.add(List.of(byRank[r]!));
    }
  }
  // 双王炸
  if (hand.contains('BJ') && hand.contains('RJ')) {
    all.add(['BJ', 'RJ']);
  }
  // 双红十王炸
  if (hand.contains('TH') && hand.contains('TD')) {
    all.add(['TH', 'TD']);
  }

  if (target == null) return all;
  return [
    for (final c in all)
      if (hsClassify(c)?.beats(target) ?? false) c,
  ];
}

List<String> hsDeckForPlayers(int players) {
  const suits = ['D', 'C', 'H', 'S'];
  const ranks = ['3', '4', '5', '6', '7', '8', '9', 'T', 'J', 'Q', 'K', 'A', '2'];
  final deck = <String>[
    for (final r in ranks)
      for (final s in suits) '$r$s',
    'BJ',
    'RJ',
  ];
  if (players == 4) {
    // 54 - 2 = 52 张（每人 13 张），去掉 3D、3C
    deck.remove('3D');
    deck.remove('3C');
  } else if (players == 5) {
    // 54 - 4 = 50 张（每人 10 张），去掉四张 3
    deck.removeWhere((c) => c.startsWith('3'));
  }
  // 6 人使用全部 54 张（每人 9 张）
  return deck;
}

class Hongshi extends GameEngine {
  Hongshi(super.setup);

  late int rounds;
  int round = 0;
  late List<int> scores;
  String phase = 'declare'; // 'declare' | 'play' | 'roundEnd' | 'over'

  late List<List<String>> hands;
  late List<bool> declared;
  late List<bool> liang; // 是否选择亮十
  late List<bool> revealed; // 红十身份是否已公开（亮十或打出红十后公开）
  late List<int> redSeats; // 持有红十的座位列表（1人独持双红十，或2人各持一张）

  late List<Map<String, dynamic>?> acts;
  List<String> tableCards = [];
  Map<String, dynamic>? tableInfo;
  int tableSeat = -1;
  List<int> queue = [];
  int turn = 0;
  int starter = 0;
  List<int> finish = [];
  Map<String, dynamic>? result;
  late List<bool> ready;
  final List<String> log = [];

  void _log(String s) {
    log.add(s);
    if (log.length > 15) log.removeAt(0);
    host.log(s);
  }

  bool isRedTeam(int s) => redSeats.contains(s);
  bool active(int s) => hands[s].isNotEmpty;
  int get activeCount => hands.where((h) => h.isNotEmpty).length;
  bool get leading => tableSeat < 0;

  int get stakesMultiplier {
    var m = 1;
    for (final s in redSeats) {
      if (liang[s]) m *= 2;
    }
    return m;
  }

  @override
  bool get isOver => phase == 'over';

  @override
  List<int>? get placings => isOver ? rankByScore(scores) : null;

  @override
  List<int> get waitingFor {
    switch (phase) {
      case 'declare':
        return [for (final s in redSeats) if (!declared[s]) s];
      case 'play':
        return [turn];
      case 'roundEnd':
        return [for (var s = 0; s < players; s++) if (!ready[s]) s];
      default:
        return const [];
    }
  }

  @override
  void start() {
    rounds = setup.opt<int>('rounds', 4);
    scores = List.filled(players, 0);
    starter = rng.nextInt(players);
    _log('红十开始：$players 人局，共 $rounds 局');
    _deal();
  }

  void _deal() {
    round++;
    final deck = shuffled(hsDeckForPlayers(players), rng);
    final per = deck.length ~/ players;
    hands = [
      for (var s = 0; s < players; s++) deck.sublist(s * per, (s + 1) * per)..sort(),
    ];
    for (final h in hands) {
      hsSort(h);
    }
    _initTeamsAndDeclare();
  }

  /// 根据当前手牌重新识别红十队伍（便于测试直接修改 hands 后调用或自动判断）
  void syncRedSeats() {
    redSeats = [
      for (var s = 0; s < players; s++)
        if (hands[s].any(hsIsRedTen)) s,
    ];
  }

  void _initTeamsAndDeclare() {
    syncRedSeats();
    declared = List.filled(players, true);
    for (final s in redSeats) {
      declared[s] = false;
    }
    liang = List.filled(players, false);
    revealed = List.filled(players, false);
    finish = [];
    result = null;
    ready = List.filled(players, false);
    resetTrick();
    // 默认持 ♥3 或 starter 先出
    final h3 = [for (var s = 0; s < players; s++) if (hands[s].contains('3H')) s];
    turn = h3.isNotEmpty ? h3.first : starter;
    phase = redSeats.isEmpty ? 'play' : 'declare';
    _log('第 $round 局发牌完成，请持有红十的玩家选择【亮十】或【暗打】');
  }

  void resetTrick() {
    acts = List.filled(players, null);
    tableCards = [];
    tableInfo = null;
    tableSeat = -1;
    queue = [];
  }

  int nextActive(int s) {
    for (var i = 1; i <= players; i++) {
      final t = (s + i) % players;
      if (active(t)) return t;
    }
    return s;
  }

  List<int> responders(int seat) => [
        for (var i = 1; i < players; i++)
          if (active((seat + i) % players)) (seat + i) % players,
      ];

  void _startPlay() {
    phase = 'play';
    resetTrick();
    // 若有人亮十，第一个亮十的人先出；否则维持 turn
    final liangList = [for (final s in redSeats) if (liang[s]) s];
    if (liangList.isNotEmpty) {
      turn = liangList.first;
    }
    final modeStr = liangList.isNotEmpty ? '明打（倍数 ×$stakesMultiplier）' : '暗打';
    _log('进入出牌阶段（$modeStr），由 ${name(turn)} 首出');
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (seat < 0 || seat >= players) throw GameError('无效座位');
    final type = asStr(action['type']);

    if (phase == 'roundEnd') {
      if (type != 'continue') throw GameError('请点击继续下一局');
      ready[seat] = true;
      if (ready.every((x) => x)) _deal();
      return;
    }

    if (phase == 'declare') {
      syncRedSeats();
      if (!redSeats.contains(seat)) throw GameError('只有持有红十的玩家可以亮十或暗打');
      if (declared[seat]) throw GameError('你已经做出选择了');
      bool isLiang;
      if (type == 'liang') {
        isLiang = true;
      } else if (type == 'an') {
        isLiang = false;
      } else if (type == 'declare') {
        final choice = asStr(action['choice']);
        isLiang = choice == 'liang' || asBool(action['liang']);
      } else {
        throw GameError('请选择亮十(liang)或暗打(an)');
      }
      declared[seat] = true;
      liang[seat] = isLiang;
      if (isLiang) {
        revealed[seat] = true;
        final reds = hands[seat].where(hsIsRedTen).join('/');
        _log('${name(seat)} 选择【亮十】（亮出 $reds），本局倍数翻倍！');
      } else {
        _log('一位红十玩家选择了【暗打】');
      }
      if (redSeats.every((s) => declared[s])) {
        _startPlay();
      }
      return;
    }

    if (phase == 'play') {
      _handlePlay(seat, action);
      return;
    }

    throw GameError('当前阶段无法执行此操作');
  }

  void _handlePlay(int seat, Map<String, dynamic> a) {
    if (seat != turn) throw GameError('还没轮到你出牌');
    final type = asStr(a['type']);
    if (type == 'pass') {
      if (leading) throw GameError('你是首家，必须出牌');
      acts[seat] = {'pass': true};
      if (queue.isNotEmpty && queue.first == seat) queue.removeAt(0);
      _advanceTrick();
      return;
    }
    if (type != 'play') throw GameError('未知出牌操作');
    final raw = a['cards'];
    if (raw is! List || raw.isEmpty) throw GameError('请选择要出的牌');
    final cards = [for (final x in raw) '$x'];
    final handCopy = List<String>.of(hands[seat]);
    for (final c in cards) {
      if (!handCopy.remove(c)) throw GameError('手牌中没有 $c');
    }
    final combo = hsClassify(cards);
    if (combo == null) throw GameError('不合法的牌型');
    if (!leading && tableInfo != null) {
      final target = HsCombo.fromJson(tableInfo)!;
      if (!combo.beats(target)) {
        throw GameError('打出的牌必须管上桌面的 ${target.label}');
      }
    }

    for (final c in cards) {
      hands[seat].remove(c);
    }
    hsSort(cards);
    tableCards = cards;
    tableInfo = combo.toJson();
    tableSeat = seat;
    acts[seat] = {'cards': cards, 'label': combo.label};

    if (cards.any(hsIsRedTen) && !revealed[seat]) {
      revealed[seat] = true;
      _log('${name(seat)} 打出红十，亮明红十方身份！');
    }
    if (combo.isBomb) {
      _log('${name(seat)} 打出 ${combo.label}！');
    }

    if (hands[seat].isEmpty) {
      finish.add(seat);
      _log('${name(seat)} 出完手牌（第 ${finish.length} 名）');
      if (_checkRoundDone()) {
        _endRound();
        return;
      }
    }
    queue = responders(seat);
    _advanceTrick();
  }

  void _advanceTrick() {
    queue.removeWhere((s) => !active(s) || s == tableSeat);
    if (queue.isEmpty) {
      final w = tableSeat;
      final lead = active(w) ? w : nextActive(w);
      resetTrick();
      turn = lead;
    } else {
      turn = queue.first;
    }
  }

  bool _checkRoundDone() {
    if (activeCount <= 1) return true;
    final nonRed = [for (var s = 0; s < players; s++) if (!redSeats.contains(s)) s];
    if (redSeats.isNotEmpty && redSeats.every((s) => !active(s))) return true;
    if (nonRed.isNotEmpty && nonRed.every((s) => !active(s))) return true;
    return false;
  }

  void _endRound() {
    final rest = [for (var s = 0; s < players; s++) if (active(s)) s]
      ..sort((a, b) => hands[a].length != hands[b].length ? hands[a].length - hands[b].length : a - b);
    final order = [...finish, ...rest];
    final nonRed = [for (var s = 0; s < players; s++) if (!redSeats.contains(s)) s];

    final redFinishedAll = redSeats.isNotEmpty && redSeats.every((s) => !active(s));
    final nonRedFinishedAll = nonRed.isNotEmpty && nonRed.every((s) => !active(s));

    // 先全部出完的一方获胜；若平局或特殊情况按头游归属判定
    bool redWin;
    if (redFinishedAll && !nonRedFinishedAll) {
      redWin = true;
    } else if (nonRedFinishedAll && !redFinishedAll) {
      redWin = false;
    } else {
      redWin = redSeats.contains(order.first);
    }

    var mult = stakesMultiplier;
    final notes = <String>[];
    if (stakesMultiplier > 1) notes.add('亮十×$stakesMultiplier');
    final solo = redSeats.length == 1;
    if (solo) {
      notes.add('双红十独打');
    }
    // 完胜（双破/闷红十）加倍
    if (redWin && order.take(redSeats.length).every(redSeats.contains)) {
      mult *= 2;
      notes.add(solo ? '独打头游×2' : '红十方包揽前二×2');
    } else if (!redWin && finish.every((s) => !redSeats.contains(s))) {
      mult *= 2;
      notes.add('闷红十×2');
    }

    final delta = List.filled(players, 0);
    final sign = redWin ? 1 : -1;
    final nRed = redSeats.length;
    final nBlack = players - nRed;
    if (nRed > 0 && nBlack > 0) {
      // 使双方总得分平衡：红十每人 ± nBlack * mult，黑十每人 ∓ nRed * mult
      for (var s = 0; s < players; s++) {
        if (redSeats.contains(s)) {
          delta[s] = sign * nBlack * mult;
        } else {
          delta[s] = -sign * nRed * mult;
        }
      }
    }
    for (var s = 0; s < players; s++) {
      scores[s] += delta[s];
      revealed[s] = true;
    }

    result = {
      'order': order,
      'delta': delta,
      'redWin': redWin,
      'redSeats': redSeats,
      'mult': mult,
      'notes': notes,
      'hands': [for (final h in hands) List.of(h)],
    };
    starter = order.first;
    _log('第 $round 局结束：${redWin ? '红十方' : '黑十方'}获胜 ${notes.join(' ')}');
    phase = round >= rounds ? 'over' : 'roundEnd';
    ready = List.filled(players, false);
  }

  /// 判断 seat 是否已知 other 是队友（用于电脑 AI，不透视未公开身份）
  bool _knownFriend(int seat, int other) {
    if (seat == other) return true;
    // 若一人独持双红十且是我自己，则所有人都是敌人
    if (hands[seat].where(hsIsRedTen).length == 2) return false;
    final allRevealed = redSeats.every((s) => revealed[s]);
    if (allRevealed) {
      return isRedTeam(seat) == isRedTeam(other);
    }
    if (isRedTeam(seat)) {
      return revealed[other] && isRedTeam(other);
    } else {
      // 我是黑十方：若红十两人均已暴露，则其他非红十都是队友
      return false;
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (phase == 'roundEnd') {
      return ready[seat] ? null : {'type': 'continue'};
    }
    if (phase == 'declare') {
      if (!redSeats.contains(seat) || declared[seat]) return null;
      final h = hands[seat];
      final strong = h.where((c) => hsRank(c) >= 15).length;
      final wantLiang = botLevel >= 1 && (strong >= 4 || h.where(hsIsRedTen).length == 2);
      return {'type': wantLiang ? 'liang' : 'an'};
    }
    if (phase != 'play' || seat != turn) return null;

    final hand = hands[seat];
    if (leading) {
      final cands = hsCandidates(hand);
      if (cands.isEmpty) return {'type': 'play', 'cards': [hand.last]};
      // 如果能一手出完，直接出完
      final whole = cands.where((c) => c.length == hand.length).toList();
      if (whole.isNotEmpty) return {'type': 'play', 'cards': whole.first};
      if (botLevel == 0) {
        return {'type': 'play', 'cards': cands[rng.nextInt(cands.length)]};
      }
      // 优先出非炸弹的小牌组合（顺子、三张、对子、单张）
      final nonBombs = cands.where((c) => !(hsClassify(c)?.isBomb ?? false)).toList();
      final pool = nonBombs.isNotEmpty ? nonBombs : cands;
      pool.sort((a, b) {
        final ca = hsClassify(a)!, cb = hsClassify(b)!;
        if (ca.rank != cb.rank) return ca.rank - cb.rank;
        return cb.length - ca.length;
      });
      return {'type': 'play', 'cards': pool.first};
    }

    if (tableSeat >= 0 && _knownFriend(seat, tableSeat) && hands[tableSeat].length <= 3) {
      return {'type': 'pass'};
    }
    final target = HsCombo.fromJson(tableInfo);
    if (target == null) return {'type': 'pass'};
    final cands = hsCandidates(hand, target);
    if (cands.isEmpty) return {'type': 'pass'};

    final whole = cands.where((c) => c.length == hand.length).toList();
    if (whole.isNotEmpty) return {'type': 'play', 'cards': whole.first};

    if (botLevel == 0) {
      return rng.nextBool() ? {'type': 'play', 'cards': cands.first} : {'type': 'pass'};
    }

    final nonBombs = cands.where((c) => !(hsClassify(c)?.isBomb ?? false)).toList();
    if (nonBombs.isNotEmpty) {
      if (_knownFriend(seat, tableSeat) && hsClassify(nonBombs.first)!.rank >= 16) {
        return {'type': 'pass'};
      }
      return {'type': 'play', 'cards': nonBombs.first};
    }
    // 只剩炸弹可管时：对手快出完或自己手牌很少时才炸
    if (!_knownFriend(seat, tableSeat) && (hands[tableSeat].length <= 4 || hand.length <= 5)) {
      return {'type': 'play', 'cards': cands.first};
    }
    return {'type': 'pass'};
  }

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players;
    final visibleReds = <int>[
      for (final s in redSeats)
        if (revealed[s] || phase == 'roundEnd' || phase == 'over' || (me && s == seat)) s,
    ];
    return {
      'phase': phase,
      'round': round,
      'rounds': rounds,
      'scores': scores,
      'turn': phase == 'play' ? turn : -1,
      'lead': leading,
      'hand': me ? hands[seat] : <String>[],
      'counts': [for (final h in hands) h.length],
      'hasRedTen': me && redSeats.contains(seat),
      'declared': declared,
      'liang': liang,
      'revealed': revealed,
      'visibleReds': visibleReds,
      'stakes': stakesMultiplier,
      'acts': acts,
      'table': tableInfo,
      'tableCards': tableCards,
      'tableSeat': tableSeat,
      'finish': finish,
      'log': log,
      'result': phase == 'roundEnd' || phase == 'over' ? result : null,
      'ready': phase == 'roundEnd' ? ready : null,
    };
  }
}

const String hongshiRules = '''
# 红十（东北抓红十）
4~6 人经典东北扑克游戏，使用一副牌（4 人去掉两张黑 3 共 52 张；5 人去掉四张 3 共 50 张；6 人使用全部 54 张），所有牌均分给每位玩家。
# 阵营与亮十
- 摸到红桃 10（♥10）和方片 10（♦10）的玩家自动结为【红十方】；若两张红十在同一人手中，则该玩家 1 打其余所有人（独打）。
- 其余没有红十的玩家为【黑十方】（平民方）。
- 发牌后进入【亮十阶段】：持有红十的玩家可选择“亮十”（公开红十身份，本局基础倍率 ×2；若两人均亮十则 ×4）或“暗打”（隐藏身份，在出牌过程中打出红十时才会暴露）。
# 牌型与大小
- 点数从大到小：红十（♥10 / ♦10）> 大王 > 小王 > 2 > A > K > Q > J > 黑 10（♠10 / ♣10）> 9 > 8 > 7 > 6 > 5 > 4 > 3。
- 合法牌型：
- 单张：任意 1 张牌，红十是最大的单张。
- 对子：2 张相同点数的普通牌（3~2）。
- 三张：3 张相同点数的普通牌（3~2）。
- 顺子：5 张及以上点数连续的单张（范围 3~A，不含 2、王、红十）。
- 四张炸弹：4 张相同点数的牌，可管任意非炸弹牌型。
- 双王炸：大王 + 小王，大于四张炸弹。
- 双红十王炸：♥10 + ♦10 同出，全场最大，可管一切牌型！
# 胜负与计分
- 任意一方的所有成员率先将手牌全部出完，该方即获得本局胜利。
- 若红十方包揽前两名（或独打夺得头游），或黑十方在红十方无人出完前全部走完（闷红十），额外 ×2 倍。
- 打满设定局数后，按总积分排名决出胜负。
''';
