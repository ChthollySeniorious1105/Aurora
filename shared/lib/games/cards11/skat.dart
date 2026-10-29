import '../../src/engine.dart';

const String skatRules = '''
# 德国斯卡特 Skat 规则

## 概述
德国斯卡特（Skat）是德国最负盛名的 3 人 32 张吃墩与独庄叫牌纸牌游戏，被誉为“德国国粹扑克”。3 名玩家通过竞叫争夺**独庄（Declarer）**身份，以 1 敌 2 对抗两名防守方（Defenders）。

## 牌组与分值
- 使用 32 张牌：方片（`D`）、红桃（`H`）、黑桃（`S`）、梅花（`C`）四种花色，每种花色含 `7, 8, 9, 10(T), J, Q, K, A`。
- **单牌分值（整副牌共 120 分）**：
  - `A` = 11 分，`10(T)` = 10 分，`K` = 4 分，`Q` = 3 分，`J` = 2 分，`9 / 8 / 7` = 0 分。
- **四大王牌 J（Buben）**：
  - 在花色定约（`D / H / S / C`）与大满贯定约（`G` Grand）中，**所有 4 张 J 均脱离原花色，固定属于主牌（Trump）且为最高 4 张主牌**，大小顺序恒为：
    `JC（梅花J） > JS（黑桃J） > JH（红桃J） > JD（方片J）`！
  - 在花色定约中，主花色其余 7 张牌排在 `JD` 之后：`A > T > K > Q > 9 > 8 > 7`。
  - 在大满贯定约（`G`）中，**仅有 4 张 J 是主牌**，其余 28 张牌按原花色 `A > T > K > Q > 9 > 8 > 7` 排列。
  - 在空门定约（`N` Null）中，无任何主牌，J 回归原花色，牌序回归自然顺序 `A > K > Q > J > T > 9 > 8 > 7`。

## 阶段流程
1. **发牌与席位**：每人发 10 张手牌，桌面中央留 **2 张暗置底牌（Skat）**。发牌人左手边为**先手（Forehand）**，始终首引第 1 墩。
2. **叫牌阶段（`bid`）**：
   - 玩家依次叫分（`18, 20, 22, 23, 24, 27, 30, 33, 35, 36...`）或选择不叫（`pass`）。最高叫分者成为本局**独庄（Declarer）**。
3. **底牌与定约阶段（`skat` & `contract`）**：
   - **提底（`take_skat`）**：独庄拿起 2 张底牌（手牌变 12 张），并选择 2 张牌埋入自己的得分堆（底牌分值计入独庄吃墩总分）。
   - **明手不看底（`hand`）**：独庄不查看底牌直接宣定约（奖励 `+1` 级倍数，空门定约升为 35 分；2 张底牌分值同样在局末计入独庄总分）。
   - **选择定约（`contract`）**：
     - 方片 `D`（基础分 9）、红桃 `H`（基础分 10）、黑桃 `S`（基础分 11）、梅花 `C`（基础分 12）
     - 大满贯 `G` Grand（基础分 24）
     - 空门 `N` Null（固定 23 分，Hand 明手 35 分 —— **独庄必须 10 墩全败即 0 墩才算获胜！**）
4. **吃墩阶段（`play`）**：
   - 共进行 10 墩。先手首引第 1 墩，跟牌必须跟随首引牌的**有效花色**（注意：花色/大满贯定约下 4 张 J 的有效花色为主牌 `TRUMP`）。
   - **胜负与计分**：
     - 花色/大满贯定约：独庄赢得 **至少 61 分**（含埋底 2 张牌）即获胜！达到 `>= 90` 分获 **Schneider（施耐德 +1 倍）**，赢下全部 10 墩获 **Schwarz（全清 +1 倍）**。
     - 独庄获胜得 `+定约游戏分`，失败则扣除 `-2 × 定约游戏分`。
''';

const List<String> kSkatSuits = ['D', 'H', 'S', 'C'];
const List<String> kSkatRanks = ['7', '8', '9', 'T', 'J', 'Q', 'K', 'A'];
const List<String> kSkatJacks = ['JC', 'JS', 'JH', 'JD'];

const List<int> kSkatBidValues = [
  18, 20, 22, 23, 24, 27, 30, 33, 35, 36, 40, 44, 45, 46, 48, 50, 54, 55, 59, 60,
];

const Map<String, int> kSkatContractBase = {
  'D': 9,
  'H': 10,
  'S': 11,
  'C': 12,
  'G': 24,
  'N': 23,
};

const Map<String, String> kSkatContractNames = {
  'D': '♦方片 (基础9)',
  'H': '♥红桃 (基础10)',
  'S': '♠黑桃 (基础11)',
  'C': '♣梅花 (基础12)',
  'G': '👑大满贯 Grand (基础24)',
  'N': '🕳️空门 Null (0墩胜)',
};

String skatRank(String card) => card.substring(0, card.length - 1);
String skatPrintedSuit(String card) => card[card.length - 1];

int skatCardPoints(String card) {
  switch (skatRank(card)) {
    case 'A':
      return 11;
    case 'T':
      return 10;
    case 'K':
      return 4;
    case 'Q':
      return 3;
    case 'J':
      return 2;
    default:
      return 0;
  }
}

bool skatIsTrump(String card, String contract) {
  if (contract == 'N' || contract.isEmpty) return false;
  if (skatRank(card) == 'J') return true;
  if (contract == 'G') return false;
  return skatPrintedSuit(card) == contract;
}

/// Returns the effective suit of [card] under [contract]:
/// `'TRUMP'` for any trump card (including all 4 Jacks in Suit/Grand),
/// otherwise its printed suit `'D'`, `'H'`, `'S'`, `'C'`.
String skatEffectiveSuit(String card, String contract) {
  if (skatIsTrump(card, contract)) return 'TRUMP';
  return skatPrintedSuit(card);
}

int _nonJackSuitOrder(String rank) {
  switch (rank) {
    case '7':
      return 1;
    case '8':
      return 2;
    case '9':
      return 3;
    case 'Q':
      return 4;
    case 'K':
      return 5;
    case 'T':
      return 6;
    case 'A':
      return 7;
    default:
      return 0;
  }
}

int _nullSuitOrder(String rank) {
  switch (rank) {
    case '7':
      return 1;
    case '8':
      return 2;
    case '9':
      return 3;
    case 'T':
      return 4;
    case 'J':
      return 5;
    case 'Q':
      return 6;
    case 'K':
      return 7;
    case 'A':
      return 8;
    default:
      return 0;
  }
}

/// Higher strength beats lower strength within a trick where [ledEffectiveSuit] was led.
int skatTrickStrength(String card, String contract, String ledEffectiveSuit) {
  if (contract == 'N') {
    if (skatPrintedSuit(card) != ledEffectiveSuit) return -1;
    return _nullSuitOrder(skatRank(card));
  }
  final eff = skatEffectiveSuit(card, contract);
  if (eff == 'TRUMP') {
    final r = skatRank(card);
    if (r == 'J') {
      // JC (104) > JS (103) > JH (102) > JD (101)
      switch (skatPrintedSuit(card)) {
        case 'C':
          return 104;
        case 'S':
          return 103;
        case 'H':
          return 102;
        case 'D':
          return 101;
      }
    }
    return 50 + _nonJackSuitOrder(r);
  }
  if (eff == ledEffectiveSuit) {
    return _nonJackSuitOrder(skatRank(card));
  }
  return -1;
}

/// Counts Spitzen (Matadors: "with" or "without" consecutive top Jacks JC, JS, JH, JD).
int skatCountMatadors(Iterable<String> declarerCards) {
  final set = declarerCards.toSet();
  final hasJC = set.contains('JC');
  var count = 0;
  for (final j in kSkatJacks) {
    if (set.contains(j) == hasJC) {
      count++;
    } else {
      break;
    }
  }
  return count < 1 ? 1 : count;
}

List<String> buildSkatDeck() => [
      for (final s in kSkatSuits)
        for (final r in kSkatRanks) '$r$s',
    ];

class SkatGame extends GameEngine {
  late int maxRounds;
  int round = 1;
  int dealer = 0;

  String phase = 'bid'; // 'bid' | 'skat' | 'contract' | 'play'
  int turn = 0;
  int leader = 0;

  late List<List<String>> hands;
  late List<String> skat;
  late List<String> buriedSkat;
  late List<String> declarerInitial12;

  int currentBid = 0;
  int highBidder = -1;
  int declarer = -1;
  int bidValue = 18;
  late List<bool> passed;

  bool pickedSkat = false;
  bool handGame = false;
  String contract = '';
  int matadors = 1;

  int tricksPlayed = 0;
  late List<int> tricksWon;
  late List<int> trickPoints;
  late List<int> scores;

  List<Map<String, dynamic>> currentTrick = [];
  Map<String, dynamic>? lastTrick;
  Map<String, dynamic>? lastHandSummary;

  bool _over = false;

  SkatGame(super.setup) {
    maxRounds = setup.opt<int>('rounds', 3);
    scores = List.filled(players, 0);
  }

  int get forehand => (dealer + 1) % 3;
  int get middlehand => (dealer + 2) % 3;
  int get rearhand => dealer;

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _over ? rankByScore(scores) : null;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  void start() {
    _startRound();
  }

  void _startRound() {
    final deck = shuffled(buildSkatDeck(), rng);
    hands = [
      deck.sublist(0, 10),
      deck.sublist(10, 20),
      deck.sublist(20, 30),
    ];
    for (var s = 0; s < 3; s++) {
      _sortHand(hands[s], 'G');
    }
    skat = deck.sublist(30, 32);
    buriedSkat = [];
    declarerInitial12 = [];

    phase = 'bid';
    currentBid = 0;
    highBidder = -1;
    declarer = -1;
    bidValue = 18;
    passed = [false, false, false];
    pickedSkat = false;
    handGame = false;
    contract = '';
    matadors = 1;

    tricksPlayed = 0;
    tricksWon = [0, 0, 0];
    trickPoints = [0, 0, 0];
    currentTrick = [];
    lastTrick = null;

    turn = forehand;
    leader = forehand;
    host.log('第 $round/$maxRounds 局开始，先手为 ${name(forehand)}');
  }

  void _sortHand(List<String> hand, String c) {
    const suitOrder = {'C': 4, 'S': 3, 'H': 2, 'D': 1};
    hand.sort((a, b) {
      final ta = skatIsTrump(a, c);
      final tb = skatIsTrump(b, c);
      if (ta != tb) return ta ? -1 : 1;
      if (ta && tb) {
        return skatTrickStrength(b, c, 'TRUMP')
            .compareTo(skatTrickStrength(a, c, 'TRUMP'));
      }
      final sa = suitOrder[skatPrintedSuit(a)] ?? 0;
      final sb = suitOrder[skatPrintedSuit(b)] ?? 0;
      if (sa != sb) return sb.compareTo(sa);
      if (c == 'N') {
        return _nullSuitOrder(skatRank(b)).compareTo(_nullSuitOrder(skatRank(a)));
      }
      return _nonJackSuitOrder(skatRank(b))
          .compareTo(_nonJackSuitOrder(skatRank(a)));
    });
  }

  List<String> legalCards(int seat) {
    if (seat < 0 || seat >= 3) return const [];
    final h = hands[seat];
    if (phase != 'play' || currentTrick.isEmpty) return List<String>.of(h);
    final ledCard = '${currentTrick.first['card']}';
    final ledEff = skatEffectiveSuit(ledCard, contract);
    final matching =
        h.where((c) => skatEffectiveSuit(c, contract) == ledEff).toList();
    return matching.isNotEmpty ? matching : List<String>.of(h);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('当前不是你的回合');
    final type = asStr(action['type']);

    if (phase == 'bid') {
      _handleBid(seat, type, action);
      return;
    }
    if (phase == 'skat') {
      _handleSkat(seat, type, action);
      return;
    }
    if (phase == 'contract') {
      _handleContract(seat, type, action);
      return;
    }
    if (phase == 'play') {
      _handlePlay(seat, type, action);
      return;
    }
    throw GameError('未知阶段');
  }

  void _handleBid(int seat, String type, Map<String, dynamic> action) {
    if (type == 'bid') {
      final val = asInt(action['value']);
      if (val < 18 || val <= currentBid) {
        throw GameError('叫分必须大于当前最高叫分（至少 18 分）');
      }
      currentBid = val;
      highBidder = seat;
      host.log('${name(seat)} 叫分 $val');
      _advanceBidTurn();
      return;
    }
    if (type == 'pass') {
      passed[seat] = true;
      host.log('${name(seat)} 选择不叫 (Pass)');
      _advanceBidTurn();
      return;
    }
    throw GameError('叫牌阶段请使用 bid 或 pass');
  }

  void _advanceBidTurn() {
    final activeSeats = [
      for (var s = 0; s < 3; s++)
        if (!passed[s]) s,
    ];
    if (activeSeats.isEmpty) {
      _finalizeDeclarer(highBidder >= 0 ? highBidder : forehand);
      return;
    }
    if (activeSeats.length == 1 && highBidder == activeSeats.first) {
      _finalizeDeclarer(activeSeats.first);
      return;
    }
    for (var i = 1; i <= 3; i++) {
      final next = (turn + i) % 3;
      if (!passed[next]) {
        turn = next;
        return;
      }
    }
    _finalizeDeclarer(highBidder >= 0 ? highBidder : forehand);
  }

  void _finalizeDeclarer(int winner) {
    declarer = winner;
    bidValue = currentBid > 0 ? currentBid : 18;
    if (currentBid == 0) currentBid = 18;
    declarerInitial12 = [...hands[declarer], ...skat];
    matadors = skatCountMatadors(declarerInitial12);
    phase = 'skat';
    turn = declarer;
    host.log('${name(declarer)} 以 $bidValue 分成为独庄 (Declarer)');
  }

  void _handleSkat(int seat, String type, Map<String, dynamic> action) {
    if (type == 'hand') {
      if (pickedSkat) {
        throw GameError('已拿起底牌，不能再宣布 Hand 明手');
      }
      handGame = true;
      buriedSkat = List<String>.of(skat);
      skat.clear();
      for (final c in buriedSkat) {
        trickPoints[declarer] += skatCardPoints(c);
      }
      phase = 'contract';
      host.log('${name(seat)} 宣布 Hand（不看底牌明手）！');
      return;
    }

    if (type == 'pick_skat' ||
        (type == 'take_skat' &&
            action['discards'] == null &&
            action['cards'] == null)) {
      if (pickedSkat) throw GameError('已经拿起底牌，请选择 2 张手牌埋底');
      pickedSkat = true;
      handGame = false;
      hands[declarer].addAll(skat);
      skat.clear();
      _sortHand(hands[declarer], 'G');
      host.log('${name(seat)} 拿起了 2 张 Skat 底牌');
      return;
    }

    if (type == 'take_skat' || type == 'discard_skat') {
      final raw = action['discards'] ?? action['cards'];
      if (raw is! List || raw.length != 2) {
        throw GameError('必须选择 2 张牌埋入底牌堆');
      }
      final d0 = '${raw[0]}';
      final d1 = '${raw[1]}';
      if (d0 == d1) throw GameError('必须选择 2 张不同的牌埋底');

      if (!pickedSkat) {
        pickedSkat = true;
        handGame = false;
        hands[declarer].addAll(skat);
        skat.clear();
      }
      if (!hands[declarer].contains(d0) || !hands[declarer].contains(d1)) {
        throw GameError('埋底的牌必须在你的手牌或底牌中');
      }
      hands[declarer].remove(d0);
      hands[declarer].remove(d1);
      buriedSkat = [d0, d1];
      trickPoints[declarer] += skatCardPoints(d0) + skatCardPoints(d1);
      phase = 'contract';
      host.log('${name(seat)} 拿起 Skat 底牌并埋下 2 张牌');
      return;
    }

    throw GameError('底牌阶段请使用 take_skat 或 hand');
  }

  void _handleContract(int seat, String type, Map<String, dynamic> action) {
    if (type != 'contract') throw GameError('请选择定约类型');
    final c = asStr(action['contract']);
    if (!kSkatContractBase.containsKey(c)) {
      throw GameError('无效定约，可选 D / H / S / C / G / N');
    }
    contract = c;
    if (declarerInitial12.isEmpty) {
      declarerInitial12 = [...hands[declarer], ...buriedSkat, ...skat];
    }
    matadors = c == 'N' ? 1 : skatCountMatadors(declarerInitial12);
    for (var s = 0; s < 3; s++) {
      _sortHand(hands[s], contract);
    }
    phase = 'play';
    leader = forehand;
    turn = forehand;
    host.log(
      '${name(seat)} 选定定约：${kSkatContractNames[contract] ?? contract}'
      '${handGame ? ' (Hand 明手)' : ''}',
    );
  }

  void _handlePlay(int seat, String type, Map<String, dynamic> action) {
    if (type != 'play') throw GameError('出牌阶段请使用 play');
    final card = asStr(action['card']);
    if (!hands[seat].contains(card)) {
      throw GameError('你手里没有这张牌：$card');
    }
    final legal = legalCards(seat);
    if (!legal.contains(card)) {
      throw GameError('必须跟随首引有效花色出牌');
    }

    hands[seat].remove(card);
    currentTrick.add({'seat': seat, 'card': card});

    if (currentTrick.length < 3) {
      turn = (turn + 1) % 3;
      return;
    }

    // Resolve trick
    final ledCard = '${currentTrick.first['card']}';
    final ledEff = skatEffectiveSuit(ledCard, contract);
    var bestSeat = (currentTrick.first['seat'] as num).toInt();
    var bestCard = ledCard;
    var bestStrength = skatTrickStrength(ledCard, contract, ledEff);
    var pts = skatCardPoints(ledCard);

    for (var i = 1; i < currentTrick.length; i++) {
      final entry = currentTrick[i];
      final s = (entry['seat'] as num).toInt();
      final c = '${entry['card']}';
      pts += skatCardPoints(c);
      final st = skatTrickStrength(c, contract, ledEff);
      if (st > bestStrength) {
        bestStrength = st;
        bestSeat = s;
        bestCard = c;
      }
    }

    tricksPlayed++;
    tricksWon[bestSeat]++;
    trickPoints[bestSeat] += pts;
    lastTrick = {
      'winner': bestSeat,
      'winningCard': bestCard,
      'points': pts,
      'cards': List<Map<String, dynamic>>.of(currentTrick),
    };
    currentTrick = [];
    leader = bestSeat;
    turn = bestSeat;

    if (tricksPlayed >= 10 || hands.every((h) => h.isEmpty)) {
      _finishHand();
    }
  }

  void _finishHand() {
    // Ensure any unburied skat points go to declarer if skipped in tests
    if (skat.isNotEmpty && declarer >= 0) {
      for (final c in skat) {
        trickPoints[declarer] += skatCardPoints(c);
      }
      buriedSkat.addAll(skat);
      skat.clear();
    }

    final declPts = trickPoints[declarer];
    final defPts = 120 - declPts;
    final declTricks = tricksWon[declarer];

    bool declarerWon;
    var schneider = false;
    var schwarz = false;
    int gameValue;

    if (contract == 'N') {
      declarerWon = declTricks == 0;
      gameValue = handGame ? 35 : 23;
    } else {
      declarerWon = declPts >= 61;
      schneider = declPts >= 90 || declPts <= 30;
      schwarz = declTricks == 10 || declTricks == 0;
      final base = kSkatContractBase[contract] ?? 9;
      final mult = 1 +
          matadors +
          (handGame ? 1 : 0) +
          (schneider ? 1 : 0) +
          (schwarz ? 1 : 0);
      gameValue = base * mult;
    }

    final delta = declarerWon ? gameValue : -2 * gameValue;
    scores[declarer] += delta;

    lastHandSummary = {
      'round': round,
      'declarer': declarer,
      'contract': contract,
      'handGame': handGame,
      'declarerPoints': declPts,
      'defenderPoints': defPts,
      'declarerTricks': declTricks,
      'schneider': schneider,
      'schwarz': schwarz,
      'gameValue': gameValue,
      'delta': delta,
      'declarerWon': declarerWon,
    };

    host.log(
      '第 $round 局结算：独庄 ${name(declarer)} 拿 $declPts 分 ($declTricks 墩)，'
      '${declarerWon ? '获胜 +$gameValue' : '失利 $delta'} 分！',
    );

    if (round >= maxRounds) {
      _over = true;
      return;
    }
    round++;
    dealer = (dealer + 1) % 3;
    _startRound();
  }

  @override
  Map<String, dynamic> view(int seat) {
    final canSeeSkat = seat == declarer && phase == 'skat';
    return {
      'round': round,
      'maxRounds': maxRounds,
      'dealer': dealer,
      'forehand': forehand,
      'phase': phase,
      'turn': turn,
      'leader': leader,
      'declarer': declarer,
      'currentBid': currentBid,
      'highBidder': highBidder,
      'bidValue': bidValue,
      'passed': List<bool>.of(passed),
      'pickedSkat': pickedSkat,
      'handGame': handGame,
      'contract': contract,
      'matadors': matadors,
      'tricksPlayed': tricksPlayed,
      'tricksWon': List<int>.of(tricksWon),
      'trickPoints': [
        for (var s = 0; s < 3; s++)
          phase == 'play' && s == declarer && seat != declarer
              ? trickPoints[s] -
                  buriedSkat.fold<int>(0, (a, c) => a + skatCardPoints(c))
              : trickPoints[s],
      ],
      'scores': List<int>.of(scores),
      'handCounts': [for (final h in hands) h.length],
      'myHand': seat >= 0 && seat < 3 ? List<String>.of(hands[seat]) : const <String>[],
      'legalCards': seat == turn && phase == 'play' ? legalCards(seat) : const <String>[],
      'skatCount': skat.length,
      'skat': canSeeSkat ? List<String>.of(skat) : const <String>[],
      'buriedSkat': seat == declarer ? List<String>.of(buriedSkat) : const <String>[],
      'currentTrick': [
        for (final e in currentTrick) Map<String, dynamic>.of(e),
      ],
      'lastTrick': lastTrick,
      'lastHandSummary': lastHandSummary,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    if (phase == 'bid') {
      final h = hands[seat];
      final jacks = h.where((c) => skatRank(c) == 'J').length;
      final highCards =
          h.where((c) => skatRank(c) == 'A' || skatRank(c) == 'T').length;
      final maxWilling = 18 + jacks * 6 + highCards * 2;
      final nextBid = kSkatBidValues.firstWhere(
        (v) => v > currentBid,
        orElse: () => 999,
      );
      if (nextBid <= maxWilling && nextBid <= 36) {
        return {'type': 'bid', 'value': nextBid};
      }
      return {'type': 'pass'};
    }

    if (phase == 'skat') {
      if (!pickedSkat) {
        return {'type': 'pick_skat'};
      }
      // Choose 2 non-Jack low-point or off-suit cards to bury
      final sorted = List<String>.of(hands[seat])
        ..sort((a, b) {
          final ja = skatRank(a) == 'J' ? 1 : 0;
          final jb = skatRank(b) == 'J' ? 1 : 0;
          if (ja != jb) return ja.compareTo(jb);
          return skatCardPoints(a).compareTo(skatCardPoints(b));
        });
      return {
        'type': 'take_skat',
        'discards': [sorted[0], sorted[1]],
      };
    }

    if (phase == 'contract') {
      final h = hands[seat];
      // Pick the suit with the most non-Jack cards
      var bestSuit = 'C';
      var bestCount = -1;
      for (final s in kSkatSuits) {
        final cnt =
            h.where((c) => skatRank(c) != 'J' && skatPrintedSuit(c) == s).length;
        if (cnt > bestCount) {
          bestCount = cnt;
          bestSuit = s;
        }
      }
      final jacks = h.where((c) => skatRank(c) == 'J').length;
      if (jacks >= 3 && bestCount <= 2) {
        return {'type': 'contract', 'contract': 'G'};
      }
      return {'type': 'contract', 'contract': bestSuit};
    }

    if (phase == 'play') {
      final legal = legalCards(seat);
      if (botLevel == 0) {
        return {'type': 'play', 'card': legal[rng.nextInt(legal.length)]};
      }
      legal.sort((a, b) => skatCardPoints(b).compareTo(skatCardPoints(a)));
      return {'type': 'play', 'card': legal.first};
    }

    return null;
  }
}
