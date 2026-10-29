import '../../src/engine.dart';

/// Base rank order in Brazilian Truco (`4 < 5 < 6 < 7 < Q < J < K < A < 2 < 3`).
const List<String> trucoRanks = ['4', '5', '6', '7', 'Q', 'J', 'K', 'A', '2', '3'];

/// Suits in Truco (`D ♦ < S ♠ < H ♥ < C ♣` for Manilhas).
const List<String> trucoSuits = ['D', 'S', 'H', 'C'];

/// Escalating stake ladder: `1 -> 3 (Truco!) -> 6 (Seis!) -> 9 (Nove!) -> 12 (Doze!)`.
const List<int> trucoStakeLadder = [1, 3, 6, 9, 12];

const Map<int, String> trucoStakeNames = {
  1: '普通 (1分)',
  3: 'Truco! (3分)',
  6: 'Seis! (6分)',
  9: 'Nove! (9分)',
  12: 'Doze! (12分)',
};

const Map<String, String> trucoManilhaNames = {
  'C': '♣ Zap (最高王牌)',
  'H': '♥ Copas (次高王牌)',
  'S': '♠ Espadilha (第三王牌)',
  'D': '♦ Pica-fumo (第四王牌)',
};

String trucoCardRank(String card) =>
    card.length >= 2 ? card.substring(0, card.length - 1) : '';

String trucoCardSuit(String card) =>
    card.length >= 2 ? card[card.length - 1] : '';

/// Builds the 40-card Truco deck (`4, 5, 6, 7, Q, J, K, A, 2, 3` in `D, S, H, C`).
List<String> buildTrucoDeck() => [
      for (final s in trucoSuits)
        for (final r in trucoRanks) '$r$s',
    ];

/// Returns the Manilha rank (`王牌阶`), which is the rank immediately cyclic-above [viraCard]
/// in `[4, 5, 6, 7, Q, J, K, A, 2, 3]`.
String trucoManilhaRank(String viraCard) {
  final r = trucoCardRank(viraCard);
  final idx = trucoRanks.indexOf(r);
  if (idx < 0) return '4';
  return trucoRanks[(idx + 1) % trucoRanks.length];
}

/// Whether [card] is one of the 4 dynamic Manilhas given [viraCard].
bool isTrucoManilha(String card, String viraCard) =>
    trucoCardRank(card) == trucoManilhaRank(viraCard);

/// Suit hierarchy for the 4 Manilhas: `C ♣ (Zap, 4) > H ♥ (Copas, 3) > S ♠ (Espadilha, 2) > D ♦ (Pica-fumo, 1)`.
int trucoManilhaSuitOrder(String suit) => switch (suit) {
      'C' => 4, // Zap
      'H' => 3, // Copas
      'S' => 2, // Espadilha
      'D' => 1, // Pica-fumo
      _ => 0,
    };

/// Strength of [card] given [viraCard]:
/// - Manilhas: `C(104) > H(103) > S(102) > D(101)`
/// - Non-Manilhas: `3(9) > 2(8) > A(7) > K(6) > J(5) > Q(4) > 7(3) > 6(2) > 5(1) > 4(0)` (suits are equal!).
int trucoCardStrength(String card, String viraCard) {
  final r = trucoCardRank(card);
  final s = trucoCardSuit(card);
  if (r == trucoManilhaRank(viraCard)) {
    return 100 + trucoManilhaSuitOrder(s);
  }
  return trucoRanks.indexOf(r);
}

/// Side index for [seat]:
/// - In 4-player partnership mode: `seat % 2` (`0` for `0&2`, `1` for `1&3`).
/// - In 2-player or 3-player mode: `seat` (`0..players-1`).
int trucoSideOf(int seat, int players) => players == 4 ? (seat % 2) : seat;

/// Next stake in the Truco ladder (`1 -> 3 -> 6 -> 9 -> 12`).
int nextTrucoStake(int currentStake) {
  final idx = trucoStakeLadder.indexOf(currentStake);
  if (idx < 0) return 3;
  if (idx + 1 < trucoStakeLadder.length) return trucoStakeLadder[idx + 1];
  return 12;
}

/// Evaluates a completed [trick] and returns `(winningSide, winningSeat)`.
/// If two or more DIFFERENT sides tie for the highest card strength, the trick is tied (`Empate`),
/// returning `(-1, -1)`.
(int, int) trucoEvaluateTrick(
  List<Map<String, dynamic>> trick,
  String viraCard, {
  int players = 2,
}) {
  if (trick.isEmpty) return (-1, -1);
  var maxStr = -1;
  for (final e in trick) {
    final str = trucoCardStrength(asStr(e['card']), viraCard);
    if (str > maxStr) maxStr = str;
  }
  final topEntries = trick
      .where((e) => trucoCardStrength(asStr(e['card']), viraCard) == maxStr)
      .toList();
  final topSides = {
    for (final e in topEntries) trucoSideOf(asInt(e['seat'], 0), players),
  };
  if (topSides.length != 1) {
    return (-1, -1); // Empate (tie between opposing sides)
  }
  final winSide = topSides.first;
  final winSeat = asInt(topEntries.first['seat'], 0);
  return (winSide, winSeat);
}

/// Returns the winning side of [trick] (`0, 1, ...`), or `-1` if tied (`Empate`).
int trucoTrickWinner(
  List<Map<String, dynamic>> trick,
  String viraCard, {
  int players = 2,
}) =>
    trucoEvaluateTrick(trick, viraCard, players: players).$1;

/// Determines if the best-of-3 hand is decided given [trickWinners] (each element is a side index or `-1` for tie):
/// - First side to win 2 tricks wins immediately.
/// - If Trick 1 is tied (`-1`), whoever wins Trick 2 wins immediately!
/// - If Trick 1 is won by side `W` and Trick 2 or Trick 3 is tied (`-1`), side `W` wins!
/// - If Tricks 1 and 2 are both tied (`-1, -1`), whoever wins Trick 3 wins!
/// Returns the winning side (`>= 0`), or `-1` if undecided (or all 3 tricks tied).
int trucoHandWinner(List<int> trickWinners) {
  if (trickWinners.isEmpty) return -1;

  // Check if any side has won 2 tricks
  final counts = <int, int>{};
  for (final w in trickWinners) {
    if (w >= 0) {
      counts[w] = (counts[w] ?? 0) + 1;
      if (counts[w]! >= 2) return w;
    }
  }

  if (trickWinners.length >= 2) {
    final t1 = trickWinners[0];
    final t2 = trickWinners[1];
    // Trick 1 tied, Trick 2 won -> Trick 2 winner wins immediately
    if (t1 == -1 && t2 >= 0) return t2;
    // Trick 1 won, Trick 2 tied -> Trick 1 winner wins immediately
    if (t1 >= 0 && t2 == -1) return t1;
  }

  if (trickWinners.length >= 3) {
    final t1 = trickWinners[0];
    final t2 = trickWinners[1];
    final t3 = trickWinners[2];
    if (t1 == -1 && t2 == -1 && t3 >= 0) return t3;
    if (t3 == -1 && t1 >= 0) return t1;
    if (t1 >= 0) return t1; // In 3p if 3 different players win 1 trick each, Trick 1 winner wins
  }

  return -1;
}

class TrucoGame extends GameEngine {
  late int targetScore;
  int handNumber = 1;
  int dealer = 0;
  int leader = 1;
  int turn = 1;
  String phase = 'play'; // 'play' | 'respond_truco'

  String viraCard = '4D';
  String manilhaRank = '5';

  int handStake = 1;
  int proposedStake = 1;
  int lastTrucoCallerSide = -1;
  int trucoCallerSeat = -1;
  int trucoResponderSeat = -1;

  late List<List<String>> hands;
  late List<int> scores; // Individual seat scores
  late List<int> sideScores; // Side scores (length 2 in 2p/4p, length 3 in 3p)
  late List<int> sideTricksWon; // Tricks won in current hand per side
  List<int> trickWinners = []; // History of winning sides in current hand (-1 = Empate)
  List<Map<String, dynamic>> trick = [];
  Map<String, dynamic>? lastTrick;
  Map<String, dynamic>? lastHandSummary;
  int trickNumber = 1;

  bool _over = false;
  List<int>? _placings;

  TrucoGame(super.setup) {
    targetScore = setup.opt<int>('targetScore', 12);
    final numSides = players == 4 ? 2 : players;
    hands = List.generate(players, (_) => <String>[]);
    scores = List.filled(players, 0);
    sideScores = List.filled(numSides, 0);
    sideTricksWon = List.filled(numSides, 0);
  }

  int get numSides => players == 4 ? 2 : players;
  int sideOf(int seat) => trucoSideOf(seat, players);

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _placings;

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (phase == 'respond_truco') return [trucoResponderSeat];
    return [turn];
  }

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (_over || seat < 0 || seat >= players) throw GameError('无法认输');
    _over = true;
    final losingSide = sideOf(seat);
    final winners = [
      for (var i = 0; i < players; i++)
        if (sideOf(i) != losingSide) i,
    ];
    _placings = rankWinners(players, winners);
    host.log('${name(seat)} 认输');
  }

  @override
  void start() {
    _startHand();
  }

  void _startHand() {
    final deck = shuffled(buildTrucoDeck(), rng);
    for (var s = 0; s < players; s++) {
      hands[s] = deck.sublist(s * 3, (s + 1) * 3);
    }
    viraCard = deck[players * 3];
    manilhaRank = trucoManilhaRank(viraCard);
    for (var s = 0; s < players; s++) {
      _sortHand(hands[s]);
    }

    handStake = 1;
    proposedStake = 1;
    lastTrucoCallerSide = -1;
    trucoCallerSeat = -1;
    trucoResponderSeat = -1;
    sideTricksWon = List.filled(numSides, 0);
    trickWinners = [];
    trick = [];
    trickNumber = 1;
    phase = 'play';
    leader = (dealer + 1) % players;
    turn = leader;
    host.log('第 $handNumber 手开始：翻开指示牌 Vira=$viraCard，本手王牌阶 Manilha=$manilhaRank (♣>♥>♠>♦)');
  }

  void _sortHand(List<String> hand) {
    hand.sort((a, b) =>
        trucoCardStrength(b, viraCard).compareTo(trucoCardStrength(a, viraCard)));
  }

  /// Whether [seat] can call `{'type': 'truco'}` right now.
  bool canCallTruco(int seat) {
    if (_over || phase != 'play' || seat != turn) return false;
    if (handStake >= 12) return false;
    if (lastTrucoCallerSide == sideOf(seat)) return false;
    return true;
  }

  int _findOpponentResponder(int callerSeat) {
    final callerSide = sideOf(callerSeat);
    for (var offset = 1; offset < players; offset++) {
      final candidate = (callerSeat + offset) % players;
      if (sideOf(candidate) != callerSide) return candidate;
    }
    return (callerSeat + 1) % players;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'respond_truco') {
      if (seat != trucoResponderSeat && sideOf(seat) == lastTrucoCallerSide) {
        throw GameError('等待对方回应 Truco 挑战');
      }
      if (seat != trucoResponderSeat) {
        throw GameError('还没轮到你回应 Truco 挑战');
      }

      if (type == 'accept') {
        handStake = proposedStake;
        phase = 'play';
        host.log('${name(seat)} 接受挑战！当前手牌分值升至 $handStake 分');
        return;
      }

      if (type == 'raise') {
        if (proposedStake >= 12) {
          throw GameError('已达最高分值 12 分 (Doze!)，无法继续加注');
        }
        handStake = proposedStake;
        proposedStake = nextTrucoStake(handStake);
        final prevCaller = trucoCallerSeat;
        lastTrucoCallerSide = sideOf(seat);
        trucoCallerSeat = seat;
        trucoResponderSeat = prevCaller >= 0 ? prevCaller : _findOpponentResponder(seat);
        host.log('${name(seat)} 反加注 ${trucoStakeNames[proposedStake] ?? "$proposedStake分"}！等待 ${name(trucoResponderSeat)} 回应');
        return;
      }

      if (type == 'fold') {
        final winSide = lastTrucoCallerSide >= 0
            ? lastTrucoCallerSide
            : sideOf(trucoCallerSeat);
        host.log('${name(seat)} 选择弃牌 (Correr)！进攻方直接赢得 $handStake 分');
        _awardHand(winSide, foldedBy: seat);
        return;
      }

      throw GameError('请回应挑战：accept (接受) / raise (加注) / fold (弃牌)');
    }

    if (phase == 'play') {
      if (seat != turn) throw GameError('还没轮到你行动');

      if (type == 'truco') {
        if (!canCallTruco(seat)) {
          throw GameError('当前无法发起 Truco 加注');
        }
        proposedStake = nextTrucoStake(handStake);
        lastTrucoCallerSide = sideOf(seat);
        trucoCallerSeat = seat;
        trucoResponderSeat = _findOpponentResponder(seat);
        phase = 'respond_truco';
        host.log('${name(seat)} 喊出 ${trucoStakeNames[proposedStake] ?? "Truco!"}（提议将本手分值升至 $proposedStake 分）！');
        return;
      }

      if (type == 'play') {
        final card = asStr(action['card']);
        if (!hands[seat].contains(card)) {
          throw GameError('手牌中没有该张牌');
        }
        hands[seat].remove(card);
        trick.add({
          'seat': seat,
          'card': card,
          'strength': trucoCardStrength(card, viraCard),
          'isManilha': isTrucoManilha(card, viraCard),
        });

        if (trick.length < players) {
          turn = (turn + 1) % players;
          return;
        }

        _resolveTrick();
        return;
      }

      throw GameError('请出牌或喊 Truco!');
    }

    throw GameError('未知阶段');
  }

  void _resolveTrick() {
    final (winSide, winSeat) = trucoEvaluateTrick(trick, viraCard, players: players);
    trickWinners.add(winSide);
    if (winSide >= 0) {
      sideTricksWon[winSide] += 1;
    }

    lastTrick = {
      'trickNumber': trickNumber,
      'winSide': winSide,
      'winner': winSeat,
      'isTie': winSide == -1,
      'cards': [for (final e in trick) Map<String, dynamic>.of(e)],
    };

    final nextLeader = winSeat >= 0 ? winSeat : leader;
    trick = [];

    final handWinSide = trucoHandWinner(trickWinners);
    if (handWinSide >= 0 || trickWinners.length >= 3) {
      _awardHand(handWinSide);
      return;
    }

    trickNumber += 1;
    leader = nextLeader;
    turn = nextLeader;
  }

  void _awardHand(int winSide, {int? foldedBy}) {
    final awarded = List<int>.filled(numSides, 0);
    if (winSide >= 0 && winSide < numSides) {
      awarded[winSide] = handStake;
      sideScores[winSide] += handStake;
    }
    for (var s = 0; s < players; s++) {
      scores[s] = sideScores[sideOf(s)];
    }

    lastHandSummary = {
      'handNumber': handNumber,
      'viraCard': viraCard,
      'manilhaRank': manilhaRank,
      'winSide': winSide,
      'handStake': handStake,
      'trickWinners': List<int>.of(trickWinners),
      'foldedBy': foldedBy,
      'awarded': awarded,
    };

    if (sideScores.any((sc) => sc >= targetScore)) {
      _over = true;
      _placings = rankByScore(scores);
      host.log('比赛结束！');
    } else {
      handNumber += 1;
      dealer = (dealer + 1) % players;
      _startHand();
    }
  }

  int _handStrengthSum(int seat) =>
      hands[seat].fold<int>(0, (acc, c) => acc + trucoCardStrength(c, viraCard));

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over) return null;

    if (phase == 'respond_truco') {
      if (seat != trucoResponderSeat) return null;
      final hasManilha = hands[seat].any((c) => isTrucoManilha(c, viraCard));
      final maxStr = hands[seat].isEmpty
          ? 0
          : hands[seat]
              .map((c) => trucoCardStrength(c, viraCard))
              .reduce((a, b) => a > b ? a : b);
      final mySide = sideOf(seat);
      final wonTrick = trickWinners.contains(mySide);

      if (hasManilha && wonTrick && proposedStake < 12 && botLevel >= 2) {
        return {'type': 'raise'};
      }
      if (hasManilha || maxStr >= 7 || wonTrick) {
        return {'type': 'accept'};
      }
      return {'type': 'fold'};
    }

    if (phase == 'play') {
      if (seat != turn) return null;
      final hand = hands[seat];
      if (hand.isEmpty) return null;

      // Consider calling Truco if holding a strong hand
      final hasManilha = hand.any((c) => isTrucoManilha(c, viraCard));
      if (canCallTruco(seat) &&
          handStake == 1 &&
          hasManilha &&
          _handStrengthSum(seat) >= 112 &&
          botLevel >= 1) {
        return {'type': 'truco'};
      }

      if (botLevel == 0) {
        return {'type': 'play', 'card': hand[rng.nextInt(hand.length)]};
      }

      final sortedAsc = List<String>.of(hand)
        ..sort((a, b) =>
            trucoCardStrength(a, viraCard).compareTo(trucoCardStrength(b, viraCard)));

      if (trick.isEmpty) {
        // Lead strongest card in Trick 1 or medium/strong card
        return {'type': 'play', 'card': sortedAsc.last};
      }

      final (curWinSide, _) = trucoEvaluateTrick(trick, viraCard, players: players);
      if (curWinSide == sideOf(seat)) {
        // Partner is already winning the trick: play lowest card
        return {'type': 'play', 'card': sortedAsc.first};
      }

      var curMax = -1;
      for (final e in trick) {
        final str = trucoCardStrength(asStr(e['card']), viraCard);
        if (str > curMax) curMax = str;
      }

      // Find cheapest card that strictly beats curMax
      final winners = sortedAsc
          .where((c) => trucoCardStrength(c, viraCard) > curMax)
          .toList();
      if (winners.isNotEmpty) {
        return {'type': 'play', 'card': winners.first};
      }

      // Otherwise check if we can tie on Trick 2/3 when our side won Trick 1
      if (trickWinners.isNotEmpty && trickWinners.first == sideOf(seat)) {
        final tiers = sortedAsc
            .where((c) => trucoCardStrength(c, viraCard) == curMax)
            .toList();
        if (tiers.isNotEmpty) {
          return {'type': 'play', 'card': tiers.first};
        }
      }

      return {'type': 'play', 'card': sortedAsc.first};
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final canTruco = (seat >= 0 && seat < players) && canCallTruco(seat);
    return {
      'handNumber': handNumber,
      'targetScore': targetScore,
      'phase': phase,
      'dealer': dealer,
      'leader': leader,
      'turn': turn,
      'viraCard': viraCard,
      'manilhaRank': manilhaRank,
      'handStake': handStake,
      'proposedStake': proposedStake,
      'lastTrucoCallerSide': lastTrucoCallerSide,
      'trucoCallerSeat': trucoCallerSeat,
      'trucoResponderSeat': trucoResponderSeat,
      'canCallTruco': canTruco,
      'trickNumber': trickNumber,
      'scores': List<int>.of(scores),
      'sideScores': List<int>.of(sideScores),
      'sideTricksWon': List<int>.of(sideTricksWon),
      'trickWinners': List<int>.of(trickWinners),
      'handCounts': [for (final h in hands) h.length],
      'hand': (seat >= 0 && seat < players) ? List<String>.of(hands[seat]) : <String>[],
      'trick': [for (final e in trick) Map<String, dynamic>.of(e)],
      'lastTrick': lastTrick,
      'lastHandSummary': lastHandSummary,
      'over': _over,
      'placings': _placings,
    };
  }
}
