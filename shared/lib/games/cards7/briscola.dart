import '../../src/engine.dart';

const String briscolaRules = '''
# 布里斯科拉 (Briscola) 规则说明

## 基本配置
- **人数与模式**：支持 2~4 人游玩。
  - **2人 / 3人模式**：各自为战的个人积分赛（3人模式移除一张草花2 `2C`，使用 39 张牌以确保每人抓牌数均等）。
  - **4人模式**：2v2 搭档对抗赛，座位 0 与 2 为蓝队，座位 1 与 3 为红队，队友捕获的分数合并计算。
- **牌库构成**：使用传统意大利 40 张牌对应的扑克牌面，花色为 ♠、♥、♦、♣，每种花色包含 10 张牌：`A, 3, K, Q, J, 7, 6, 5, 4, 2`（无 8、9、10）。

## 牌阶大小与分值 (120分总分)
布里斯科拉最独特之处在于**数字 3 的地位仅次于 A**，高于 K、Q、J！
各牌从大到小的等级与分值如下：
- **A (王牌 Ace)**：最大，值 **11 分**
- **3 (三点 Three)**：第二大，值 **10 分**
- **K (国王 King)**：第三大，值 **4 分**
- **Q (王后 Queen/Cavallo)**：第四大，值 **3 分**
- **J (侍从 Jack/Fante)**：第五大，值 **2 分**
- **7 > 6 > 5 > 4 > 2**：无分牌（**0 分**），仅按数字大小决定赢墩
- 全副牌共计 `(11 + 10 + 4 + 3 + 2) × 4 = 120` 分。

## 发牌与王牌 (Briscola)
- 开局每位玩家发 **3 张手牌**。
- 将剩余牌堆（Stock）的**最底部一张牌正面朝上亮出**，压在牌堆下方，这张牌被称为 **Briscola（本局王牌）**，其花色即为本局的主花色（Trump Suit）。
- 牌堆底部的这张亮明王牌会在牌堆摸空时的最后一次补牌中被最后一位补牌者摸入手中。

## 出牌、赢墩与补牌
1. **自由出牌（无须跟花色！）**：与绝大多数吃墩游戏不同，布里斯科拉**完全不强制跟出首引花色**！轮到你时，你可以打出手中任意一张牌（既可以随时用小王牌毙掉对方的大分牌，也可以在无法赢墩时垫掉 0 分杂牌）。
2. **赢墩判定**：
   - 若本墩有人打出了**主花色（Briscola）**牌，则打出**最大主花色牌**的玩家赢得该墩。
   - 若本墩无人打出主花色牌，则打出**最大首引花色（Led Suit）牌**的玩家赢得该墩（副花色杂牌无论多大都不能赢墩）。
3. **收分与补牌**：
   - 赢墩玩家将本墩所有牌收入自己的得分堆（计入个人及队伍总分）。
   - 若摸牌堆尚有余牌，从**本墩赢家开始**按顺时针顺序，每人从摸牌堆顶摸 1 张牌，使手牌恢复至 3 张（牌堆摸完后则直接继续打完手中剩余的牌）。
   - 本墩赢家获得下一墩的首引出牌权。

## 胜负判定
- 单局所有牌打完后，获得最高分（两人/两队模式下超过 60 分；若平分则赢得最后一墩者胜）的一方赢得该局胜利。
- 支持 **一局决胜** 或 **三局两胜** 赛制。
''';

const List<String> kBriscolaSuits = ['S', 'H', 'D', 'C'];

/// Ordered from lowest to highest strength!
const List<String> kBriscolaRanksLowToHigh = ['2', '4', '5', '6', '7', 'J', 'Q', 'K', '3', 'A'];

String briscolaSuitOf(String card) => card.substring(card.length - 1);
String briscolaRankOf(String card) => card.substring(0, card.length - 1);

int briscolaCardPoints(String card) {
  switch (briscolaRankOf(card)) {
    case 'A':
      return 11;
    case '3':
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

int briscolaRankStrength(String card) => kBriscolaRanksLowToHigh.indexOf(briscolaRankOf(card));

int briscolaCardPower(String card, {required String ledSuit, required String trumpSuit}) {
  final suit = briscolaSuitOf(card);
  final strength = briscolaRankStrength(card);
  if (suit == trumpSuit) return 100 + strength;
  if (suit == ledSuit) return 20 + strength;
  return 0;
}

List<String> buildBriscolaDeck(int players) {
  final deck = <String>[
    for (final s in kBriscolaSuits)
      for (final r in kBriscolaRanksLowToHigh) '$r$s',
  ];
  if (players == 3) {
    deck.remove('2C');
  }
  return deck;
}

class Briscola extends GameEngine {
  late int maxHands;
  late int handsNeeded;

  int handNumber = 1;
  int startSeat = 0;
  int turn = 0;
  String phase = 'play'; // 'play', 'over'

  List<List<String>> hands = [];
  List<String> stock = [];
  String trumpCard = '2S';
  String trumpSuit = 'S';

  int trickNum = 1;
  int totalTricksInHand = 10;
  List<Map<String, dynamic>> currentTrick = [];
  Map<String, dynamic>? lastTrick;
  Map<String, dynamic>? lastHandResult;

  List<int> handPoints = [];
  List<int> tricksWon = [];
  List<List<String>> capturedCards = [];

  List<int> handWins = [];
  List<int> cumulativePoints = [];

  bool _over = false;

  Briscola(super.setup) {
    maxHands = setup.opt<int>('hands', 1);
    handsNeeded = (maxHands + 1) ~/ 2;
    handWins = List.filled(players, 0);
    cumulativePoints = List.filled(players, 0);
  }

  bool get isPartnership => players == 4;

  @override
  bool get isOver => _over;

  @override
  bool get canResign => !_over;

  @override
  void resign(int seat) {
    if (_over) throw GameError('游戏已结束');
    _over = true;
    phase = 'over';
    if (isPartnership) {
      final winTeam = 1 - (seat % 2);
      for (var s = 0; s < 4; s++) {
        if (s % 2 == winTeam) handWins[s] = handsNeeded + 1;
      }
    } else {
      for (var s = 0; s < players; s++) {
        if (s != seat) handWins[s] += handsNeeded + 1;
      }
    }
    host.log('${name(seat)} 认输！');
  }

  @override
  List<int>? get placings {
    if (!_over) return null;
    if (isPartnership) {
      final t0 = handWins[0] * 10000 + (cumulativePoints[0] + cumulativePoints[2]);
      final t1 = handWins[1] * 10000 + (cumulativePoints[1] + cumulativePoints[3]);
      return rankByScore([t0, t1, t0, t1]);
    }
    return rankByScore([
      for (var s = 0; s < players; s++) handWins[s] * 10000 + cumulativePoints[s],
    ]);
  }

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  void start() {
    startSeat = 0;
    dealHand();
  }

  void dealHand() {
    final deck = shuffled(buildBriscolaDeck(players), rng);
    totalTricksInHand = deck.length ~/ players;
    hands = [
      for (var s = 0; s < players; s++) deck.sublist(s * 3, (s + 1) * 3),
    ];
    stock = deck.sublist(players * 3);
    // Bottom card of stock is the face-up Briscola (drawn last!)
    trumpCard = stock.last;
    trumpSuit = briscolaSuitOf(trumpCard);

    trickNum = 1;
    currentTrick = [];
    handPoints = List.filled(players, 0);
    tricksWon = List.filled(players, 0);
    capturedCards = [for (var s = 0; s < players; s++) <String>[]];
    turn = startSeat;
    phase = 'play';
    _sortHands();
  }

  void _sortHands() {
    for (var s = 0; s < players; s++) {
      hands[s].sort((a, b) {
        final sa = briscolaSuitOf(a);
        final sb = briscolaSuitOf(b);
        if (sa != sb) {
          if (sa == trumpSuit) return -1;
          if (sb == trumpSuit) return 1;
          return kBriscolaSuits.indexOf(sa).compareTo(kBriscolaSuits.indexOf(sb));
        }
        return briscolaRankStrength(b).compareTo(briscolaRankStrength(a));
      });
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你出牌');

    final type = asStr(action['type']);
    if (type != 'play') throw GameError('请选择一张手牌打出');
    final card = asStr(action['card']);
    if (!hands[seat].contains(card)) {
      throw GameError('你手里没有这张牌：$card');
    }

    hands[seat].remove(card);
    currentTrick.add({'seat': seat, 'card': card});

    if (currentTrick.length < players) {
      turn = (seat + 1) % players;
      return;
    }

    // Evaluate trick
    final ledCard = currentTrick.first['card'] as String;
    final ledSuit = briscolaSuitOf(ledCard);
    var winner = currentTrick.first['seat'] as int;
    var winningCard = ledCard;
    var bestPower = briscolaCardPower(ledCard, ledSuit: ledSuit, trumpSuit: trumpSuit);
    var trickPts = briscolaCardPoints(ledCard);

    for (var i = 1; i < currentTrick.length; i++) {
      final s = currentTrick[i]['seat'] as int;
      final c = currentTrick[i]['card'] as String;
      trickPts += briscolaCardPoints(c);
      final p = briscolaCardPower(c, ledSuit: ledSuit, trumpSuit: trumpSuit);
      if (p > bestPower) {
        bestPower = p;
        winner = s;
        winningCard = c;
      }
    }

    tricksWon[winner]++;
    handPoints[winner] += trickPts;
    for (final item in currentTrick) {
      capturedCards[winner].add(item['card'] as String);
    }

    lastTrick = {
      'trick': trickNum,
      'leader': currentTrick.first['seat'],
      'winner': winner,
      'winningCard': winningCard,
      'points': trickPts,
      'cards': [
        for (final item in currentTrick) {'seat': item['seat'], 'card': item['card']},
      ],
    };
    currentTrick = [];

    // Draw 1 card per player starting from trick winner if stock is not empty
    if (stock.isNotEmpty) {
      for (var i = 0; i < players; i++) {
        if (stock.isEmpty) break;
        final drawSeat = (winner + i) % players;
        hands[drawSeat].add(stock.removeAt(0));
      }
      _sortHands();
    }

    // Check if hand is over
    if (hands.every((h) => h.isEmpty)) {
      _finishHand(winner);
    } else {
      trickNum++;
      turn = winner;
    }
  }

  void _finishHand(int lastTrickWinner) {
    for (var s = 0; s < players; s++) {
      cumulativePoints[s] += handPoints[s];
    }

    List<int> winners;
    List<int> effectiveHandScores;
    if (isPartnership) {
      final t0 = handPoints[0] + handPoints[2];
      final t1 = handPoints[1] + handPoints[3];
      effectiveHandScores = [t0, t1, t0, t1];
      if (t0 > t1 || (t0 == t1 && lastTrickWinner % 2 == 0)) {
        winners = [0, 2];
      } else {
        winners = [1, 3];
      }
    } else {
      effectiveHandScores = List.of(handPoints);
      var maxPts = -1;
      for (final p in handPoints) {
        if (p > maxPts) maxPts = p;
      }
      final tied = [
        for (var s = 0; s < players; s++)
          if (handPoints[s] == maxPts) s,
      ];
      if (tied.length == 1) {
        winners = tied;
      } else if (tied.contains(lastTrickWinner)) {
        winners = [lastTrickWinner];
      } else {
        winners = [tied.first];
      }
    }

    for (final w in winners) {
      handWins[w]++;
    }

    lastHandResult = {
      'hand': handNumber,
      'handPoints': List<int>.of(handPoints),
      'effectiveScores': effectiveHandScores,
      'winners': winners,
    };

    host.log('第 $handNumber 局结束，本局得分：$effectiveHandScores，胜者：${winners.map(name).join(" & ")}');

    final someoneReachedTarget = handWins.any((w) => w >= handsNeeded);
    if (someoneReachedTarget || handNumber >= maxHands) {
      _over = true;
      phase = 'over';
      host.log('布里斯科拉全场比赛结束！');
    } else {
      handNumber++;
      startSeat = (startSeat + 1) % players;
      dealHand();
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    final h = hands[seat];
    if (h.length == 1 || botLevel == 0) {
      return {'type': 'play', 'card': h[rng.nextInt(h.length)]};
    }

    // Strategic Briscola bot
    if (currentTrick.isEmpty) {
      // Leading: prefer playing a 0-point non-trump card to avoid giving away points
      final nonTrumpZero = h.where((c) => briscolaSuitOf(c) != trumpSuit && briscolaCardPoints(c) == 0).toList();
      if (nonTrumpZero.isNotEmpty) {
        return {'type': 'play', 'card': nonTrumpZero.last}; // lowest strength
      }
      final nonTrump = h.where((c) => briscolaSuitOf(c) != trumpSuit).toList();
      if (nonTrump.isNotEmpty) {
        return {'type': 'play', 'card': nonTrump.last};
      }
      return {'type': 'play', 'card': h.last};
    }

    // Following in a trick
    final ledCard = currentTrick.first['card'] as String;
    final ledSuit = briscolaSuitOf(ledCard);
    var bestPower = briscolaCardPower(ledCard, ledSuit: ledSuit, trumpSuit: trumpSuit);
    var bestSeat = currentTrick.first['seat'] as int;
    var potPts = briscolaCardPoints(ledCard);
    for (var i = 1; i < currentTrick.length; i++) {
      final s = currentTrick[i]['seat'] as int;
      final c = currentTrick[i]['card'] as String;
      potPts += briscolaCardPoints(c);
      final p = briscolaCardPower(c, ledSuit: ledSuit, trumpSuit: trumpSuit);
      if (p > bestPower) {
        bestPower = p;
        bestSeat = s;
      }
    }

    final partnerWinning = isPartnership && (bestSeat % 2 == seat % 2);
    if (partnerWinning && currentTrick.length == players - 1) {
      // Partner is about to win trick: fatten with highest-point non-trump card if available!
      final fat = h.where((c) => briscolaSuitOf(c) != trumpSuit && briscolaCardPoints(c) >= 10).toList();
      if (fat.isNotEmpty) {
        return {'type': 'play', 'card': fat.first};
      }
    }

    // Can we win the trick?
    final winningPlays = h.where((c) => briscolaCardPower(c, ledSuit: ledSuit, trumpSuit: trumpSuit) > bestPower).toList();
    if (winningPlays.isNotEmpty && !partnerWinning) {
      // Same-suit non-trump overtake is great!
      final nonTrumpWin = winningPlays.where((c) => briscolaSuitOf(c) != trumpSuit).toList();
      if (nonTrumpWin.isNotEmpty) {
        return {'type': 'play', 'card': nonTrumpWin.first};
      }
      // Using trump: do it if pot has >= 4 points!
      if (potPts >= 4) {
        return {'type': 'play', 'card': winningPlays.last}; // smallest winning trump
      }
    }

    // Otherwise dump lowest-point non-trump card (or lowest-point card overall)
    final dumpOrder = List.of(h)
      ..sort((a, b) {
        final pa = briscolaCardPoints(a) + (briscolaSuitOf(a) == trumpSuit ? 15 : 0);
        final pb = briscolaCardPoints(b) + (briscolaSuitOf(b) == trumpSuit ? 15 : 0);
        if (pa != pb) return pa.compareTo(pb);
        return briscolaRankStrength(a).compareTo(briscolaRankStrength(b));
      });
    return {'type': 'play', 'card': dumpOrder.first};
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myHand = (seat >= 0 && seat < players) ? List<String>.of(hands[seat]) : const <String>[];
    final teamPoints = isPartnership
        ? [handPoints[0] + handPoints[2], handPoints[1] + handPoints[3]]
        : null;

    return {
      'phase': phase,
      'handNumber': handNumber,
      'maxHands': maxHands,
      'handsNeeded': handsNeeded,
      'turn': turn,
      'trumpCard': trumpCard,
      'trumpSuit': trumpSuit,
      'trumpInStock': stock.isNotEmpty,
      'stockCount': stock.length,
      'trickNum': trickNum,
      'totalTricksInHand': totalTricksInHand,
      'currentTrick': [
        for (final item in currentTrick)
          {
            'seat': item['seat'],
            'card': item['card'],
            'points': briscolaCardPoints(item['card'] as String),
          },
      ],
      'lastTrick': lastTrick,
      'lastHandResult': lastHandResult,
      'handPoints': List<int>.of(handPoints),
      'teamPoints': teamPoints,
      'tricksWon': List<int>.of(tricksWon),
      'handWins': List<int>.of(handWins),
      'cumulativePoints': List<int>.of(cumulativePoints),
      'handCounts': [for (var s = 0; s < players; s++) hands[s].length],
      'hand': myHand,
      'isPartnership': isPartnership,
      'over': _over,
    };
  }
}
