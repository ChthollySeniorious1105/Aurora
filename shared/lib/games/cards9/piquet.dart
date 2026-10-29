import '../../src/engine.dart';

const String piquetRules = '''
# 皮克牌 (Piquet) 规则说明

## 基本配置
- **人数**：2 人古典技巧扑克对战（支持 100分标准局 / 60分快速局）。
- **牌库构成**：使用 32 张扑克牌，包含 ♠、♥、♦、♣ 四种花色的 `7, 8, 9, 10(T), J, Q, K, A`（牌阶从大到小为 `A > K > Q > J > 10 > 9 > 8 > 7`，全局**无主花色 No-Trump**）。
- **发牌与角色**：每局由非庄家担任 **先手（Elder）**，庄家担任 **后手（Younger）**。双方各发 12 张手牌，剩余 8 张作为底牌堆（Talon）。

## 第一阶段：换牌 (`exchange`)
1. **先手换牌**：先手（Elder）必须从手牌中弃置 **1~5 张牌**，并从底牌堆（Talon）摸取等量新牌。
2. **后手换牌**：后手（Younger）可从手牌中弃置 **0~剩余底牌数（3~7张）** 的牌，并从底牌堆摸取等量新牌。

## 第二阶段：比牌宣告与 12 墩无主吃墩 (`play`)
### 1. 比牌宣告（首引第一张牌时自动结算）
- **白牌奖 (Carte Blanche, +10分)**：若一方 12 张手牌中没有任何人头牌（无 J、Q、K），立即获得 **+10 分**。
- **三项比牌（每项仅胜出方得分，平局均不得分）**：
  1. **长套 (Point)**：比较双方单花色最多的张数（若张数相同则比较该花色牌点总和：`A=11, K/Q/J/10=10, 9=9, 8=8, 7=7`）。胜者得等同于其最长花色张数的分数。
  2. **同花顺 (Sequence)**：比较双方最长的同花顺（至少 3 张连续同花色；长度相同比最大牌阶）。胜者得其所有同花顺分数（3张=3分，4张=4分，5张=15分，6张=16分，7张=17分，8张=18分）。
  3. **同点组 (Set)**：仅限 `10, J, Q, K, A` 的四条（Quatorze，**14分**）或三条（Trio，**3分**）。任何四条大于三条，同类型比牌阶。胜者得其所有有效同点组分数。
- **暗倍 (Repique, +60分)**：若一方仅靠宣告阶段得分便达到 **30 分或以上** 且对手为 0 分，立即额外奖励 **+60 分**！

### 2. 12 墩无主吃墩
- **跟牌规则**：必须跟出首引花色（无主花色，首引花色点数最大者赢墩）。
- **墩中即时计分**：
  - **首引出牌**：每墩首引出牌者立即得 **+1 分**。
  - **夺取先手**：若后出牌者赢下对手首引的一墩，赢墩者得 **+1 分**（若首引者自己保住该墩则不重复加分）。
  - **末墩奖**：赢得第 12 墩（最后一墩）者额外得 **+1 分**。
  - **明倍 (Pique, +30分)**：若本局未触发暗倍，且一方在吃墩过程中率先达到 **30 分** 而对手仍为 **0 分**，立即额外奖励 **+30 分**！
- **终局墩数奖**：
  - **过半奖 (Majority, +10分)**：赢得 **7~11 墩** 的一方获得 **+10 分**（6:6 平分则均无分）。
  - **全胜奖 (Capot, +40分)**：包揽全部 **12 墩** 的一方获得 **+40 分**（替代过半奖）！
''';

const List<String> kPiquetSuits = ['S', 'H', 'D', 'C'];
const List<String> kPiquetRanks = ['7', '8', '9', 'T', 'J', 'Q', 'K', 'A'];

String piquetRank(String card) => card.substring(0, card.length - 1);
String piquetSuit(String card) => card.substring(card.length - 1);
int piquetRankIndex(String card) => kPiquetRanks.indexOf(piquetRank(card));

int piquetPipValue(String card) {
  switch (piquetRank(card)) {
    case 'A':
      return 11;
    case 'K':
    case 'Q':
    case 'J':
    case 'T':
      return 10;
    case '9':
      return 9;
    case '8':
      return 8;
    case '7':
      return 7;
    default:
      return 0;
  }
}

List<String> buildPiquetDeck() => [
      for (final s in kPiquetSuits)
        for (final r in kPiquetRanks) '$r$s',
    ];

bool hasPiquetCarteBlanche(List<String> hand) =>
    hand.isNotEmpty &&
    !hand.any((c) {
      final r = piquetRank(c);
      return r == 'J' || r == 'Q' || r == 'K';
    });

class PiquetPointEval {
  final int length;
  final int pips;
  final String suit;
  const PiquetPointEval(this.length, this.pips, this.suit);
}

PiquetPointEval evalPiquetPoint(List<String> hand) {
  var bestLen = 0;
  var bestPips = 0;
  var bestSuit = 'S';
  for (final s in kPiquetSuits) {
    final cards = hand.where((c) => piquetSuit(c) == s).toList();
    final len = cards.length;
    final pips = cards.fold<int>(0, (sum, c) => sum + piquetPipValue(c));
    if (len > bestLen || (len == bestLen && pips > bestPips)) {
      bestLen = len;
      bestPips = pips;
      bestSuit = s;
    }
  }
  return PiquetPointEval(bestLen, bestPips, bestSuit);
}

class PiquetSequenceEval {
  final int bestLength;
  final int bestTopRank;
  final int totalPoints;
  const PiquetSequenceEval(this.bestLength, this.bestTopRank, this.totalPoints);

  int get strength => bestLength == 0 ? 0 : bestLength * 100 + bestTopRank;
}

PiquetSequenceEval evalPiquetSequences(List<String> hand) {
  var bestLen = 0;
  var bestTop = -1;
  var totalPts = 0;

  for (final s in kPiquetSuits) {
    final ranks = hand
        .where((c) => piquetSuit(c) == s)
        .map(piquetRankIndex)
        .toSet()
        .toList()
      ..sort();
    if (ranks.length < 3) continue;

    var runStart = 0;
    for (var i = 1; i <= ranks.length; i++) {
      if (i == ranks.length || ranks[i] != ranks[i - 1] + 1) {
        final runLen = i - runStart;
        if (runLen >= 3) {
          final topRank = ranks[i - 1];
          final pts = runLen >= 5 ? runLen + 10 : runLen;
          totalPts += pts;
          if (runLen > bestLen || (runLen == bestLen && topRank > bestTop)) {
            bestLen = runLen;
            bestTop = topRank;
          }
        }
        runStart = i;
      }
    }
  }

  return PiquetSequenceEval(bestLen, bestTop, totalPts);
}

class PiquetSetEval {
  final int bestSize; // 4 or 3 (or 0)
  final int bestRankIndex; // 3..7 for T..A
  final int totalPoints;
  const PiquetSetEval(this.bestSize, this.bestRankIndex, this.totalPoints);

  int get strength => bestSize == 0 ? 0 : bestSize * 100 + bestRankIndex;
}

PiquetSetEval evalPiquetSets(List<String> hand) {
  var bestSize = 0;
  var bestRank = -1;
  var totalPts = 0;

  // Only ranks T(3), J(4), Q(5), K(6), A(7) count!
  for (var rIdx = 3; rIdx < kPiquetRanks.length; rIdx++) {
    final r = kPiquetRanks[rIdx];
    final cnt = hand.where((c) => piquetRank(c) == r).length;
    if (cnt >= 3) {
      final pts = cnt == 4 ? 14 : 3;
      totalPts += pts;
      if (cnt > bestSize || (cnt == bestSize && rIdx > bestRank)) {
        bestSize = cnt;
        bestRank = rIdx;
      }
    }
  }

  return PiquetSetEval(bestSize, bestRank, totalPts);
}

typedef Piquet = PiquetGame;

class PiquetGame extends GameEngine {
  late int targetScore;

  int handNumber = 1;
  int dealer = 1; // Younger = dealer, Elder = 1 - dealer
  int turn = 0;
  int leader = 0;
  String phase = 'exchange'; // 'exchange', 'play', 'over'

  List<List<String>> hands = [[], []];
  List<String> talon = [];
  List<bool> exchanged = [false, false];
  List<int> exchangedCounts = [0, 0];

  bool declarationsScored = false;
  bool repiqueAwarded = false;
  bool piqueAwarded = false;
  Map<String, dynamic>? declarationsSummary;

  int tricksPlayed = 0;
  List<int> tricksWon = [0, 0];
  List<int> handPoints = [0, 0];
  List<int> scores = [0, 0];

  List<Map<String, dynamic>> currentTrick = [];
  Map<String, dynamic>? lastTrick;
  Map<String, dynamic>? lastHandSummary;
  Map<String, dynamic>? result;

  bool _over = false;
  int? _resignedSeat;

  PiquetGame(super.setup) {
    targetScore = setup.opt<int>('target', 100);
  }

  int get elder => 1 - dealer;
  int get younger => dealer;

  @override
  void start() {
    scores = [0, 0];
    handNumber = 1;
    dealer = 1;
    _over = false;
    _resignedSeat = null;
    result = null;
    lastHandSummary = null;
    _startNewHand();
  }

  void _startNewHand() {
    final deck = shuffled(buildPiquetDeck(), rng);
    hands = [
      deck.sublist(0, 12)..sort(_compareCards),
      deck.sublist(12, 24)..sort(_compareCards),
    ];
    talon = deck.sublist(24, 32);
    exchanged = [false, false];
    exchangedCounts = [0, 0];

    declarationsScored = false;
    repiqueAwarded = false;
    piqueAwarded = false;
    declarationsSummary = null;

    tricksPlayed = 0;
    tricksWon = [0, 0];
    handPoints = [0, 0];
    currentTrick = [];
    lastTrick = null;

    phase = 'exchange';
    leader = elder;
    turn = elder;
  }

  int _compareCards(String a, String b) {
    final sa = kPiquetSuits.indexOf(piquetSuit(a));
    final sb = kPiquetSuits.indexOf(piquetSuit(b));
    if (sa != sb) return sa.compareTo(sb);
    return piquetRankIndex(a).compareTo(piquetRankIndex(b));
  }

  /// Automatically compares and scores Elder vs Younger's 3 declarations,
  /// Carte Blanche (+10), and Repique (+60).
  void scoreDeclarations() {
    if (declarationsScored) return;
    declarationsScored = true;

    final cb = [hasPiquetCarteBlanche(hands[0]), hasPiquetCarteBlanche(hands[1])];
    for (var s = 0; s < 2; s++) {
      if (cb[s]) {
        handPoints[s] += 10;
      }
    }

    // 1. Point (longest suit, broken by pip sum)
    final p0 = evalPiquetPoint(hands[0]);
    final p1 = evalPiquetPoint(hands[1]);
    int? pointWinner;
    var pointPts = 0;
    if (p0.length > p1.length || (p0.length == p1.length && p0.pips > p1.pips)) {
      pointWinner = 0;
      pointPts = p0.length;
    } else if (p1.length > p0.length || (p1.length == p0.length && p1.pips > p0.pips)) {
      pointWinner = 1;
      pointPts = p1.length;
    }
    if (pointWinner != null) {
      handPoints[pointWinner] += pointPts;
      _checkRepique(pointWinner);
    }

    // 2. Sequence (longest straight flush >= 3)
    final seq0 = evalPiquetSequences(hands[0]);
    final seq1 = evalPiquetSequences(hands[1]);
    int? seqWinner;
    var seqPts = 0;
    if (seq0.strength > seq1.strength) {
      seqWinner = 0;
      seqPts = seq0.totalPoints;
    } else if (seq1.strength > seq0.strength) {
      seqWinner = 1;
      seqPts = seq1.totalPoints;
    }
    if (seqWinner != null && seqPts > 0) {
      handPoints[seqWinner] += seqPts;
      _checkRepique(seqWinner);
    }

    // 3. Set (highest 3/4 of a kind T..A)
    final set0 = evalPiquetSets(hands[0]);
    final set1 = evalPiquetSets(hands[1]);
    int? setWinner;
    var setPts = 0;
    if (set0.strength > set1.strength) {
      setWinner = 0;
      setPts = set0.totalPoints;
    } else if (set1.strength > set0.strength) {
      setWinner = 1;
      setPts = set1.totalPoints;
    }
    if (setWinner != null && setPts > 0) {
      handPoints[setWinner] += setPts;
      _checkRepique(setWinner);
    }

    declarationsSummary = {
      'carteBlanche': cb,
      'pointWinner': pointWinner,
      'pointPts': pointPts,
      'seqWinner': seqWinner,
      'seqPts': seqPts,
      'setWinner': setWinner,
      'setPts': setPts,
      'repique': repiqueAwarded,
      'declPoints': List<int>.of(handPoints),
    };
  }

  void _checkRepique(int seat) {
    if (!repiqueAwarded && handPoints[seat] >= 30 && handPoints[1 - seat] == 0) {
      repiqueAwarded = true;
      handPoints[seat] += 60;
      host.log('${name(seat)} 宣告得分突破30分，触发「暗倍 (Repique)」+60分！');
    }
  }

  void _checkPique(int seat) {
    if (!repiqueAwarded &&
        !piqueAwarded &&
        handPoints[seat] >= 30 &&
        handPoints[1 - seat] == 0) {
      piqueAwarded = true;
      handPoints[seat] += 30;
      host.log('${name(seat)} 率先达到30分而对手为0分，触发「明倍 (Pique)」+30分！');
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);

    if (phase == 'exchange') {
      if (type != 'exchange') throw GameError('请先选择要换掉的手牌');
      final rawCards = action['cards'];
      final discards = rawCards is List
          ? [for (final c in rawCards) asStr(c)]
          : const <String>[];

      if (discards.toSet().length != discards.length) {
        throw GameError('不能重复选择同一张牌');
      }
      for (final c in discards) {
        if (!hands[seat].contains(c)) {
          throw GameError('手牌中没有 $c');
        }
      }

      if (seat == elder) {
        final maxTake = talon.length < 5 ? talon.length : 5;
        if (discards.isEmpty || discards.length > maxTake) {
          throw GameError('先手（Elder）必须换掉 1~$maxTake 张牌');
        }
      } else {
        if (discards.length > talon.length) {
          throw GameError('后手（Younger）最多只能换掉剩余的 ${talon.length} 张底牌');
        }
      }

      for (final c in discards) {
        hands[seat].remove(c);
      }
      final drawn = talon.sublist(0, discards.length);
      talon.removeRange(0, discards.length);
      hands[seat].addAll(drawn);
      hands[seat].sort(_compareCards);

      exchanged[seat] = true;
      exchangedCounts[seat] = discards.length;
      host.log('${name(seat)} 换了 ${discards.length} 张牌');

      if (seat == elder) {
        turn = younger;
      } else {
        phase = 'play';
        leader = elder;
        turn = elder;
      }
      return;
    }

    if (phase == 'play') {
      if (type != 'play') throw GameError('请打出一张手牌');
      final card = asStr(action['card']);
      if (!hands[seat].contains(card)) throw GameError('手中没有这张牌');

      if (!declarationsScored) {
        scoreDeclarations();
      }

      if (currentTrick.isEmpty) {
        // Leading a trick
        leader = seat;
        hands[seat].remove(card);
        currentTrick.add({'seat': seat, 'card': card});
        handPoints[seat] += 1; // +1 pt for leading any trick
        _checkPique(seat);
        turn = 1 - seat;
        return;
      }

      // Following in a trick
      final ledCard = asStr(currentTrick.first['card']);
      final ledSuit = piquetSuit(ledCard);
      final hasLedSuit = hands[seat].any((c) => piquetSuit(c) == ledSuit);
      if (hasLedSuit && piquetSuit(card) != ledSuit) {
        throw GameError('必须跟出首引花色 ($ledSuit)');
      }

      hands[seat].remove(card);
      currentTrick.add({'seat': seat, 'card': card});

      final followerWins =
          piquetSuit(card) == ledSuit && piquetRankIndex(card) > piquetRankIndex(ledCard);
      final winner = followerWins ? seat : leader;

      if (winner != leader) {
        handPoints[winner] += 1; // +1 pt for winning opponent's lead
      }

      tricksWon[winner] += 1;
      tricksPlayed += 1;

      final isLastTrick = tricksPlayed >= 12 || (hands[0].isEmpty && hands[1].isEmpty);
      if (isLastTrick) {
        handPoints[winner] += 1; // +1 pt for winning the last trick
      }

      _checkPique(winner);

      lastTrick = {
        'leader': leader,
        'winner': winner,
        'cards': List<Map<String, dynamic>>.of(currentTrick),
      };
      currentTrick = [];
      leader = winner;
      turn = winner;

      if (isLastTrick) {
        _finishHand();
      }
      return;
    }

    throw GameError('未知操作');
  }

  void _finishHand() {
    int? capotSeat;
    int? majoritySeat;
    final totalTricks = tricksWon[0] + tricksWon[1];
    for (var s = 0; s < 2; s++) {
      if (tricksWon[s] == 12 || (totalTricks > 0 && tricksWon[1 - s] == 0 && tricksWon[s] == totalTricks)) {
        handPoints[s] += 40;
        capotSeat = s;
      } else if (tricksWon[s] >= 7) {
        handPoints[s] += 10;
        majoritySeat = s;
      }
    }

    scores[0] += handPoints[0];
    scores[1] += handPoints[1];

    lastHandSummary = {
      'hand': handNumber,
      'declarations': declarationsSummary,
      'pique': piqueAwarded,
      'repique': repiqueAwarded,
      'tricksWon': List<int>.of(tricksWon),
      'capotSeat': capotSeat,
      'majoritySeat': majoritySeat,
      'handPoints': List<int>.of(handPoints),
      'scores': List<int>.of(scores),
    };

    host.log('第 $handNumber 局结算：本局得分 $handPoints，总分 $scores');

    if ((scores[0] >= targetScore || scores[1] >= targetScore) && scores[0] != scores[1]) {
      _over = true;
      phase = 'over';
      final winner = scores[0] > scores[1] ? 0 : 1;
      result = {
        'winners': [winner],
        'scores': List<int>.of(scores),
        'lastHand': lastHandSummary,
      };
      return;
    }

    if (handNumber >= 12 && scores[0] == scores[1]) {
      _over = true;
      phase = 'over';
      result = {
        'winners': [0, 1],
        'scores': List<int>.of(scores),
        'lastHand': lastHandSummary,
      };
      return;
    }

    dealer = 1 - dealer;
    handNumber++;
    _startNewHand();
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'handNumber': handNumber,
      'targetScore': targetScore,
      'dealer': dealer,
      'elder': elder,
      'younger': younger,
      'turn': turn,
      'leader': leader,
      'phase': phase,
      'talonCount': talon.length,
      'exchanged': List<bool>.of(exchanged),
      'exchangedCounts': List<int>.of(exchangedCounts),
      'myHand': seat >= 0 && seat < players ? List<String>.of(hands[seat]) : const <String>[],
      'handCounts': [hands[0].length, hands[1].length],
      'declarationsScored': declarationsScored,
      'declarationsSummary': declarationsSummary,
      'repiqueAwarded': repiqueAwarded,
      'piqueAwarded': piqueAwarded,
      'tricksPlayed': tricksPlayed,
      'tricksWon': List<int>.of(tricksWon),
      'handPoints': List<int>.of(handPoints),
      'scores': List<int>.of(scores),
      'currentTrick': [
        for (final e in currentTrick) Map<String, dynamic>.of(e),
      ],
      'lastTrick': lastTrick,
      'lastHandSummary': lastHandSummary,
      'result': result,
    };
  }

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  bool get isOver => _over;

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (_over) return;
    _resignedSeat = seat;
    _over = true;
    phase = 'over';
    final winner = 1 - seat;
    result = {
      'winners': [winner],
      'scores': List<int>.of(scores),
      'resigned': seat,
    };
  }

  @override
  List<int>? get placings {
    if (!_over) return null;
    if (_resignedSeat != null) {
      return rankWinners(players, [1 - _resignedSeat!]);
    }
    return rankByScore(scores);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    if (phase == 'exchange') {
      final hand = List<String>.of(hands[seat]);
      // Sort low cards first to discard low non-trump/short-suit cards
      final bestPointSuit = evalPiquetPoint(hand).suit;
      hand.sort((a, b) {
        final keepA = (piquetSuit(a) == bestPointSuit ? 4 : 0) + piquetRankIndex(a);
        final keepB = (piquetSuit(b) == bestPointSuit ? 4 : 0) + piquetRankIndex(b);
        return keepA.compareTo(keepB);
      });
      final maxTake = seat == elder
          ? (talon.length < 5 ? talon.length : 5)
          : talon.length;
      final count = seat == elder
          ? maxTake.clamp(1, 5)
          : (maxTake > 3 ? 3 : maxTake);
      return {
        'type': 'exchange',
        'cards': hand.take(count).toList(),
      };
    }

    // phase == 'play'
    final hand = hands[seat];
    if (currentTrick.isEmpty) {
      // Lead highest rank card
      final sorted = List<String>.of(hand)
        ..sort((a, b) => piquetRankIndex(b).compareTo(piquetRankIndex(a)));
      return {'type': 'play', 'card': sorted.first};
    }

    final ledCard = asStr(currentTrick.first['card']);
    final ledSuit = piquetSuit(ledCard);
    final ledRank = piquetRankIndex(ledCard);
    final sameSuit = hand.where((c) => piquetSuit(c) == ledSuit).toList();
    if (sameSuit.isNotEmpty) {
      final winners = sameSuit.where((c) => piquetRankIndex(c) > ledRank).toList();
      if (winners.isNotEmpty) {
        winners.sort((a, b) => piquetRankIndex(b).compareTo(piquetRankIndex(a)));
        return {'type': 'play', 'card': winners.first};
      }
      sameSuit.sort((a, b) => piquetRankIndex(a).compareTo(piquetRankIndex(b)));
      return {'type': 'play', 'card': sameSuit.first};
    }

    final sorted = List<String>.of(hand)
      ..sort((a, b) => piquetRankIndex(a).compareTo(piquetRankIndex(b)));
    return {'type': 'play', 'card': sorted.first};
  }
}
