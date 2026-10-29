import 'dart:math';

import '../../src/engine.dart';

const List<String> schottenColorCodes = ['R', 'B', 'G', 'Y', 'P', 'O'];

const Map<int, String> schottenColorNames = {
  0: '🟥 红氏族 (Red)',
  1: '🟦 蓝氏族 (Blue)',
  2: '🟩 绿氏族 (Green)',
  3: '🟨 黄氏族 (Yellow)',
  4: '🟪 紫氏族 (Purple)',
  5: '🟧 橙氏族 (Orange)',
};

const Map<int, String> schottenFormationNames = {
  5: '同花顺 (Color Run)',
  4: '三条 (Three of a Kind)',
  3: '同花 (Color)',
  2: '顺子 (Run)',
  1: '散牌总和 (Sum)',
};

/// Returns clan color `0..5` of [card] (`R/0->0, B/1->1, G/2->2, Y/3->3, P/4->4, O/5->5`).
int schottenCardColor(String card) {
  if (card.isEmpty) return 0;
  final u = card.toUpperCase();
  if (u.startsWith('C') && u.contains('_')) {
    return int.tryParse(u.substring(1, u.indexOf('_'))) ?? 0;
  }
  if (u.contains('_')) {
    return switch (u.substring(0, u.indexOf('_'))) {
      'R' || '0' => 0,
      'B' || '1' => 1,
      'G' || '2' => 2,
      'Y' || '3' => 3,
      'P' || '4' => 4,
      'O' || '5' => 5,
      _ => 0,
    };
  }
  return switch (u[0]) {
    'R' || '0' => 0,
    'B' || '1' => 1,
    'G' || '2' => 2,
    'Y' || '3' => 3,
    'P' || '4' => 4,
    'O' || '5' => 5,
    _ => 0,
  };
}

/// Returns clan rank `1..9` of [card].
int schottenCardRank(String card) {
  if (card.length < 2) return 1;
  if (card.contains('_')) {
    return int.tryParse(card.substring(card.indexOf('_') + 1)) ?? 1;
  }
  return int.tryParse(card.substring(1)) ?? 1;
}

String makeSchottenCard(int color, int rank) =>
    '${schottenColorCodes[color.clamp(0, 5)]}${rank.clamp(1, 9)}';

/// Builds the 54-card Schotten Totten Clan deck (`Ranks 1..9` across `6` Colors `0..5`).
List<String> buildSchottenDeck() => [
      for (var c = 0; c < 6; c++)
        for (var r = 1; r <= 9; r++) makeSchottenCard(c, r),
    ];

/// Evaluates a 3-card Schotten Totten formation and returns `(formationType, rankSum)`:
/// - `5`: 同花顺 (`Color Run`: same color + consecutive ranks)
/// - `4`: 三条 (`Three of a Kind`: three identical ranks)
/// - `3`: 同花 (`Color`: same color)
/// - `2`: 顺子 (`Run`: consecutive ranks)
/// - `1`: 散牌总和 (`Sum`: any other 3-card combination).
(int, int) schottenEvaluateFormation(List<String> cards) {
  if (cards.length < 3) {
    final partialSum = cards.fold<int>(0, (acc, c) => acc + schottenCardRank(c));
    return (0, partialSum);
  }
  final ranks = [
    schottenCardRank(cards[0]),
    schottenCardRank(cards[1]),
    schottenCardRank(cards[2]),
  ]..sort();
  final c0 = schottenCardColor(cards[0]);
  final c1 = schottenCardColor(cards[1]);
  final c2 = schottenCardColor(cards[2]);

  final sum = ranks[0] + ranks[1] + ranks[2];
  final isColor = (c0 == c1) && (c1 == c2);
  final isRun = (ranks[1] == ranks[0] + 1) && (ranks[2] == ranks[1] + 1);
  final isThree = (ranks[0] == ranks[1]) && (ranks[1] == ranks[2]);

  if (isColor && isRun) return (5, sum);
  if (isThree) return (4, sum);
  if (isColor) return (3, sum);
  if (isRun) return (2, sum);
  return (1, sum);
}

/// Numeric formation score `type * 100 + sum` (`103..524`), strictly ordering `(type, sum)`.
int schottenFormationScore(List<String> cards) {
  final (type, sum) = schottenEvaluateFormation(cards);
  return type * 100 + sum;
}

/// Compares two completed 3-card formations on a boundary stone, breaking ties by [firstToThree] (`0` or `1`).
/// Returns `0` if Seat 0 wins, `1` if Seat 1 wins.
int schottenCompareFormations(
  List<String> seat0Cards,
  List<String> seat1Cards, {
  int firstToThree = 0,
}) {
  final sc0 = schottenFormationScore(seat0Cards);
  final sc1 = schottenFormationScore(seat1Cards);
  if (sc0 != sc1) return sc0 > sc1 ? 0 : 1;
  return firstToThree == 1 ? 1 : 0;
}

int _maxScoreForEmptyOpponent(List<String> unplayedPool) {
  if (unplayedPool.length < 3) return 0;
  final hasCard = List.generate(6, (_) => List<bool>.filled(10, false));
  final rankCount = List<int>.filled(10, 0);
  final allRanks = <int>[];

  for (final c in unplayedPool) {
    final col = schottenCardColor(c);
    final r = schottenCardRank(c);
    if (col >= 0 && col < 6 && r >= 1 && r <= 9 && !hasCard[col][r]) {
      hasCard[col][r] = true;
      rankCount[r] += 1;
      allRanks.add(r);
    }
  }

  // 5: Color Run
  for (var r = 7; r >= 1; r--) {
    for (var col = 0; col < 6; col++) {
      if (hasCard[col][r] && hasCard[col][r + 1] && hasCard[col][r + 2]) {
        return 500 + (3 * r + 3);
      }
    }
  }

  // 4: Three of a Kind
  for (var r = 9; r >= 1; r--) {
    if (rankCount[r] >= 3) {
      return 400 + 3 * r;
    }
  }

  // 3: Color
  var bestColor = 0;
  for (var col = 0; col < 6; col++) {
    final colRanks = <int>[];
    for (var r = 9; r >= 1; r--) {
      if (hasCard[col][r]) colRanks.add(r);
    }
    if (colRanks.length >= 3) {
      bestColor = max(bestColor, 300 + colRanks[0] + colRanks[1] + colRanks[2]);
    }
  }
  if (bestColor > 0) return bestColor;

  // 2: Run
  for (var r = 7; r >= 1; r--) {
    if (rankCount[r] >= 1 && rankCount[r + 1] >= 1 && rankCount[r + 2] >= 1) {
      return 200 + (3 * r + 3);
    }
  }

  // 1: Sum
  allRanks.sort((a, b) => b.compareTo(a));
  if (allRanks.length >= 3) {
    return 100 + allRanks[0] + allRanks[1] + allRanks[2];
  }
  return 0;
}

/// Proof-of-Impossibility Claim check:
/// Returns `true` iff Player [seat] has `3` cards on unclaimed Stone [stone] AND even the best possible
/// 3-card formation the opponent (`1 - seat`) could assemble on Stone [stone] using their existing cards on
/// Stone [stone] + only cards that have NOT yet been played anywhere on the board cannot beat Player [seat]!
bool schottenCanClaimStone({
  required List<List<List<String>>> stones,
  required List<int> stoneOwner,
  required List<int> firstToThree,
  required int seat,
  required int stone,
}) {
  if (stone < 0 || stone >= 9) return false;
  if (stoneOwner[stone] != -1) return false;
  final myCards = stones[stone][seat];
  if (myCards.length != 3) return false;

  final opp = 1 - seat;
  final oppCards = stones[stone][opp];
  final myScore = schottenFormationScore(myCards);

  if (oppCards.length == 3) {
    final ft = firstToThree[stone] == -1 ? seat : firstToThree[stone];
    return schottenCompareFormations(
          stones[stone][0],
          stones[stone][1],
          firstToThree: ft,
        ) ==
        seat;
  }

  // Opponent has < 3 cards on this stone, so [seat] reached 3 cards first and wins any tie!
  // Opponent must strictly exceed [myScore] using cards not yet played anywhere on the board.
  final playedCanonical = <String>{
    for (final st in stones)
      for (final side in st)
        for (final c in side)
          makeSchottenCard(schottenCardColor(c), schottenCardRank(c)),
  };
  final unplayed = buildSchottenDeck()
      .where((c) => !playedCanonical.contains(c))
      .toList();

  final need = 3 - oppCards.length;
  if (unplayed.length < need) return true;

  if (need == 1) {
    for (final c1 in unplayed) {
      if (schottenFormationScore([oppCards[0], oppCards[1], c1]) > myScore) {
        return false;
      }
    }
    return true;
  }

  if (need == 2) {
    for (var i = 0; i < unplayed.length; i++) {
      for (var j = i + 1; j < unplayed.length; j++) {
        if (schottenFormationScore([oppCards[0], unplayed[i], unplayed[j]]) > myScore) {
          return false;
        }
      }
    }
    return true;
  }

  // need == 3 (opponent has 0 cards on this stone)
  return _maxScoreForEmptyOpponent(unplayed) <= myScore;
}

/// Checks if either player has won the round (`0` for Seat 0, `1` for Seat 1, `-1` if neither yet):
/// - First player to claim **3 adjacent Boundary Stones** (`i, i+1, i+2`), OR
/// - First player to claim **5 total Boundary Stones**!
int schottenCheckWinner(List<int> stoneOwner) {
  for (var p = 0; p < 2; p++) {
    final total = stoneOwner.where((o) => o == p).length;
    if (total >= 5) return p;
    for (var i = 0; i <= 6; i++) {
      if (stoneOwner[i] == p && stoneOwner[i + 1] == p && stoneOwner[i + 2] == p) {
        return p;
      }
    }
  }
  return -1;
}

class SchottenTottenGame extends GameEngine {
  late int totalRounds;
  int round = 1;
  int turn = 0;
  String phase = 'play';

  List<String> deck = [];
  late List<List<String>> hands;
  late List<List<List<String>>> stones; // stones[0..8][0..1] = up to 3 cards per side
  late List<int> stoneOwner; // -1 unclaimed, 0 seat 0, 1 seat 1
  late List<int> firstToThree; // -1 neither, 0 seat 0, 1 seat 1
  late List<int> scores; // Match wins across rounds
  Map<String, dynamic>? lastMove;
  Map<String, dynamic>? lastRoundSummary;

  bool _over = false;
  List<int>? _placings;

  SchottenTottenGame(super.setup) {
    totalRounds = setup.opt<int>('rounds', 1);
    hands = List.generate(2, (_) => <String>[]);
    stones = List.generate(9, (_) => [<String>[], <String>[]]);
    stoneOwner = List.filled(9, -1);
    firstToThree = List.filled(9, -1);
    scores = [0, 0];
  }

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _placings;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (_over || seat < 0 || seat >= players) throw GameError('无法认输');
    _over = true;
    final winners = [for (var i = 0; i < players; i++) if (i != seat) i];
    _placings = rankWinners(players, winners);
    host.log('${name(seat)} 认输');
  }

  @override
  void start() {
    _startRound();
  }

  void _startRound() {
    final fullDeck = shuffled(buildSchottenDeck(), rng);
    hands[0] = fullDeck.sublist(0, 6);
    hands[1] = fullDeck.sublist(6, 12);
    deck = fullDeck.sublist(12); // 42 cards remaining
    for (var s = 0; s < 2; s++) {
      _sortHand(hands[s]);
    }
    stones = List.generate(9, (_) => [<String>[], <String>[]]);
    stoneOwner = List.filled(9, -1);
    firstToThree = List.filled(9, -1);
    turn = (round - 1) % 2;
    phase = 'play';
    lastMove = null;
    host.log('第 $round/$totalRounds 局开始：9 座苏格兰边境界石就位，每人发 6 张氏族牌！');
  }

  void _sortHand(List<String> hand) {
    hand.sort((a, b) {
      final ra = schottenCardRank(b).compareTo(schottenCardRank(a));
      if (ra != 0) return ra;
      return schottenCardColor(a).compareTo(schottenCardColor(b));
    });
  }

  /// Whether [seat] can claim Stone [stone] right now using Proof-of-Impossibility.
  bool canClaimStone(int seat, int stone) => schottenCanClaimStone(
        stones: stones,
        stoneOwner: stoneOwner,
        firstToThree: firstToThree,
        seat: seat,
        stone: stone,
      );

  /// List of unclaimed stone indices `0..8` that [seat] can currently claim.
  List<int> claimableStones(int seat) => [
        for (var st = 0; st < 9; st++)
          if (canClaimStone(seat, st)) st,
      ];

  /// List of stone indices `0..8` where [seat] can legally place a card (`stoneOwner[s] == -1 && stones[s][seat].length < 3`).
  List<int> playableStones(int seat) => [
        for (var st = 0; st < 9; st++)
          if (stoneOwner[st] == -1 && stones[st][seat].length < 3) st,
      ];

  bool _hasAnyMove(int seat) =>
      hands[seat].isNotEmpty && playableStones(seat).isNotEmpty;

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (type == 'claim') {
      final st = asInt(action['stone'], -1);
      if (st < 0 || st >= 9) throw GameError('无效界石编号 (0~8)');
      if (stoneOwner[st] == seat) {
        // Already claimed by this seat (idempotent)
        return;
      }
      if (stoneOwner[st] != -1) {
        throw GameError('该界石已被占领');
      }
      if (!canClaimStone(seat, st)) {
        throw GameError('当前无法证明对方不可能在界石 #${st + 1} 击败你的牌型');
      }
      stoneOwner[st] = seat;
      final (fType, fSum) = schottenEvaluateFormation(stones[st][seat]);
      host.log('${name(seat)} 成功夺取界石 #${st + 1}（${schottenFormationNames[fType]} · 点数和 $fSum）！');
      _checkWinOrEnd();
      return;
    }

    if (seat != turn) throw GameError('还没轮到你行动');
    if (type != 'play') throw GameError('请打出 1 张氏族牌到界石或宣告夺石 (claim)');

    final st = asInt(action['stone'], -1);
    if (st < 0 || st >= 9) throw GameError('请选择界石 (0~8)');
    if (stoneOwner[st] != -1) throw GameError('界石 #${st + 1} 已被夺取');
    if (stones[st][seat].length >= 3) {
      throw GameError('你在界石 #${st + 1} 一侧已满 3 张牌');
    }

    final card = asStr(action['card']);
    if (!hands[seat].contains(card)) {
      throw GameError('手牌中没有该张牌');
    }

    hands[seat].remove(card);
    final canonicalCard = makeSchottenCard(schottenCardColor(card), schottenCardRank(card));
    stones[st][seat].add(canonicalCard);
    if (stones[st][seat].length == 3 && firstToThree[st] == -1) {
      firstToThree[st] = seat;
    }

    String? drawnCard;
    if (deck.isNotEmpty) {
      drawnCard = deck.removeAt(0);
      hands[seat].add(drawnCard);
      _sortHand(hands[seat]);
    }

    lastMove = {
      'seat': seat,
      'stone': st,
      'card': canonicalCard,
      'drawn': drawnCard != null,
    };

    // Automatically check if any stone is now proven for [seat] or completed by both sides
    for (var sIdx = 0; sIdx < 9; sIdx++) {
      if (stoneOwner[sIdx] == -1) {
        if (canClaimStone(seat, sIdx)) {
          stoneOwner[sIdx] = seat;
          final (fType, fSum) = schottenEvaluateFormation(stones[sIdx][seat]);
          host.log('${name(seat)} 夺取界石 #${sIdx + 1}（${schottenFormationNames[fType]} · 总和 $fSum）！');
        } else if (stones[sIdx][0].length == 3 && stones[sIdx][1].length == 3) {
          final w = schottenCompareFormations(
            stones[sIdx][0],
            stones[sIdx][1],
            firstToThree: firstToThree[sIdx] < 0 ? seat : firstToThree[sIdx],
          );
          stoneOwner[sIdx] = w;
        }
      }
    }

    if (_checkWinOrEnd()) return;

    final nextSeat = 1 - seat;
    if (_hasAnyMove(nextSeat)) {
      turn = nextSeat;
    } else if (_hasAnyMove(seat)) {
      turn = seat;
    } else {
      _forceResolveRemainingStones();
    }
  }

  bool _checkWinOrEnd() {
    final w = schottenCheckWinner(stoneOwner);
    if (w >= 0) {
      _finishRound(w);
      return true;
    }
    if (stoneOwner.every((o) => o != -1)) {
      final c0 = stoneOwner.where((o) => o == 0).length;
      final c1 = stoneOwner.where((o) => o == 1).length;
      _finishRound(c0 >= c1 ? 0 : 1);
      return true;
    }
    return false;
  }

  void _forceResolveRemainingStones() {
    for (var st = 0; st < 9; st++) {
      if (stoneOwner[st] == -1) {
        final s0 = schottenFormationScore(stones[st][0]);
        final s1 = schottenFormationScore(stones[st][1]);
        if (s0 != s1) {
          stoneOwner[st] = s0 > s1 ? 0 : 1;
        } else {
          stoneOwner[st] = firstToThree[st] == 1 ? 1 : 0;
        }
      }
    }
    _checkWinOrEnd();
  }

  void _finishRound(int winner) {
    scores[winner] += 1;
    final stones0 = stoneOwner.where((o) => o == 0).length;
    final stones1 = stoneOwner.where((o) => o == 1).length;

    lastRoundSummary = {
      'round': round,
      'winner': winner,
      'stoneOwner': List<int>.of(stoneOwner),
      'stonesWon': [stones0, stones1],
    };

    host.log('第 $round 局结束：${name(winner)} 获胜（占领界石：$stones0 vs $stones1）！');

    if (round >= totalRounds) {
      _over = true;
      _placings = rankByScore(scores);
      host.log('比赛结束！');
    } else {
      round += 1;
      _startRound();
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    // First claim any claimable stone
    final claimable = claimableStones(seat);
    if (claimable.isNotEmpty) {
      return {'type': 'claim', 'stone': claimable.first};
    }

    final hand = hands[seat];
    final validStones = playableStones(seat);
    if (hand.isEmpty || validStones.isEmpty) return null;

    if (botLevel == 0) {
      return {
        'type': 'play',
        'stone': validStones[rng.nextInt(validStones.length)],
        'card': hand[rng.nextInt(hand.length)],
      };
    }

    // Heuristic: prefer completing a 3-card formation or matching color/rank on an existing stone
    var bestScore = -1000;
    var bestStone = validStones.first;
    var bestCard = hand.first;

    for (final st in validStones) {
      final existing = stones[st][seat];
      final oppExisting = stones[st][1 - seat];
      // Prioritize adjacent stones to already owned stones
      var adjacencyBonus = 0;
      if (st > 0 && stoneOwner[st - 1] == seat) adjacencyBonus += 15;
      if (st < 8 && stoneOwner[st + 1] == seat) adjacencyBonus += 15;

      for (final c in hand) {
        final col = schottenCardColor(c);
        final r = schottenCardRank(c);
        var val = r * 2 + adjacencyBonus;

        if (existing.isEmpty) {
          if (st >= 2 && st <= 6) val += 5; // Center stones are good for 3-adjacent
        } else if (existing.length == 1) {
          final e0Col = schottenCardColor(existing[0]);
          final e0Rank = schottenCardRank(existing[0]);
          if (col == e0Col && (r - e0Rank).abs() <= 2) {
            val += 45; // Color run potential!
          } else if (r == e0Rank) {
            val += 35; // Three of a kind potential!
          } else if (col == e0Col) {
            val += 20; // Color potential
          } else if ((r - e0Rank).abs() <= 2) {
            val += 15; // Run potential
          }
        } else if (existing.length == 2) {
          final sim = [existing[0], existing[1], c];
          final formScore = schottenFormationScore(sim);
          val += formScore ~/ 3;
          if (oppExisting.length == 3 && formScore > schottenFormationScore(oppExisting)) {
            val += 120; // Directly wins the stone!
          }
        }

        if (val > bestScore) {
          bestScore = val;
          bestStone = st;
          bestCard = c;
        }
      }
    }

    return {'type': 'play', 'stone': bestStone, 'card': bestCard};
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myClaimable = (seat >= 0 && seat < 2) ? claimableStones(seat) : <int>[];
    final myPlayable = (seat >= 0 && seat < 2 && seat == turn)
        ? playableStones(seat)
        : <int>[];
    return {
      'round': round,
      'totalRounds': totalRounds,
      'phase': phase,
      'turn': turn,
      'deckCount': deck.length,
      'scores': List<int>.of(scores),
      'stoneOwner': List<int>.of(stoneOwner),
      'firstToThree': List<int>.of(firstToThree),
      'stones': [
        for (var st = 0; st < 9; st++)
          [
            List<String>.of(stones[st][0]),
            List<String>.of(stones[st][1]),
          ],
      ],
      'handCounts': [hands[0].length, hands[1].length],
      'hand': (seat >= 0 && seat < 2) ? List<String>.of(hands[seat]) : <String>[],
      'claimableStones': myClaimable,
      'playableStones': myPlayable,
      'lastMove': lastMove,
      'lastRoundSummary': lastRoundSummary,
      'over': _over,
      'placings': _placings,
    };
  }
}
