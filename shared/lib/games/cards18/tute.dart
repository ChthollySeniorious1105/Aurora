import '../../src/engine.dart';

/// Spanish suits in Tute:
/// - `'O'`: Oros (金币 ♦)
/// - `'C'`: Copas (圣杯 ♥)
/// - `'E'`: Espadas (宝剑 ♠)
/// - `'B'`: Bastos (权杖 ♣)
const List<String> tuteSuits = ['O', 'C', 'E', 'B'];

/// Rank order in Tute from lowest (`2`) to highest (`A`):
/// `2 < 4 < 5 < 6 < 7 < J (Sota) < Q (Caballo) < K (Rey) < 3 < A`.
const List<String> tuteRanks = ['2', '4', '5', '6', '7', 'J', 'Q', 'K', '3', 'A'];

const Map<String, String> tuteSuitNames = {
  'O': '♦ 金币 (Oros)',
  'C': '♥ 圣杯 (Copas)',
  'E': '♠ 宝剑 (Espadas)',
  'B': '♣ 权杖 (Bastos)',
};

const Map<String, String> tuteRankNames = {
  'A': 'A (As · 11分)',
  '3': '3 (Tres · 10分)',
  'K': 'K (Rey · 4分)',
  'Q': 'Q (Caballo · 3分)',
  'J': 'J (Sota · 2分)',
  '7': '7',
  '6': '6',
  '5': '5',
  '4': '4',
  '2': '2',
};

String tuteCardRank(String card) =>
    card.length >= 2 ? card.substring(0, card.length - 1) : '';

String tuteCardSuit(String card) =>
    card.length >= 2 ? card[card.length - 1] : '';

/// Builds the 40-card Spanish Tute deck (`2, 4, 5, 6, 7, J, Q, K, 3, A` in `O, C, E, B`).
List<String> buildTuteDeck() => [
      for (final s in tuteSuits)
        for (final r in tuteRanks) '$r$s',
    ];

/// Card point values in Tute (`A=11, 3=10, K=4, Q=3, J=2, 7..2=0`; total `120` card points).
int tuteCardPoints(String card) => switch (tuteCardRank(card)) {
      'A' => 11,
      '3' => 10,
      'K' => 4,
      'Q' => 3,
      'J' => 2,
      _ => 0,
    };

/// Rank order (`0..9`) where `A(9) > 3(8) > K(7) > Q(6) > J(5) > 7(4) > 6(3) > 5(2) > 4(1) > 2(0)`.
int tuteRankOrder(String cardOrRank) {
  final r = cardOrRank.length >= 2 ? tuteCardRank(cardOrRank) : cardOrRank;
  return tuteRanks.indexOf(r);
}

/// Side index for [seat]:
/// - In 4-player partnership mode: `seat % 2` (`0` for `0&2`, `1` for `1&3`).
/// - In 2-player or 3-player mode: `seat`.
int tuteSideOf(int seat, int players) => players == 4 ? (seat % 2) : seat;

/// Trick-taking strength of [card] given [trumpSuit] and [leadSuit].
int tuteCardStrength(String card, String trumpSuit, String leadSuit) {
  final s = tuteCardSuit(card);
  final rOrder = tuteRankOrder(card);
  if (s == trumpSuit) return 100 + rOrder;
  if (s == leadSuit) return 10 + rOrder;
  return rOrder;
}

/// Evaluates the winning seat of a completed [trick] under [trumpSuit].
int tuteTrickWinner(List<Map<String, dynamic>> trick, String trumpSuit) {
  if (trick.isEmpty) return 0;
  final leadCard = asStr(trick.first['card']);
  final leadSuit = tuteCardSuit(leadCard);
  var bestSeat = asInt(trick.first['seat'], 0);
  var bestStr = tuteCardStrength(leadCard, trumpSuit, leadSuit);
  for (var i = 1; i < trick.length; i++) {
    final c = asStr(trick[i]['card']);
    final str = tuteCardStrength(c, trumpSuit, leadSuit);
    if (str > bestStr) {
      bestStr = str;
      bestSeat = asInt(trick[i]['seat'], 0);
    }
  }
  return bestSeat;
}

/// Computes legal cards from [hand] given current [trick] and [trumpSuit].
/// Under strict Spanish following rules (Montar & Fallar, active once stock is empty or throughout 4p):
/// 1. Must follow the led suit and beat the highest card of the led suit (Montar) if able;
/// 2. If holding the led suit but unable to beat it, play any card of the led suit;
/// 3. If void in the led suit, must play a Trump card (Fallar), beating any earlier trump in the trick if able;
/// 4. Only if void in both the led suit and Trump may any card be played.
List<String> tuteLegalCards(
  List<String> hand,
  List<Map<String, dynamic>> trick,
  String trumpSuit, {
  bool strict = true,
}) {
  if (trick.isEmpty || !strict) return List<String>.of(hand);

  final leadSuit = tuteCardSuit(asStr(trick.first['card']));
  final sameSuit = hand.where((c) => tuteCardSuit(c) == leadSuit).toList();

  if (sameSuit.isNotEmpty) {
    var highestLedRank = -1;
    for (final e in trick) {
      final c = asStr(e['card']);
      if (tuteCardSuit(c) == leadSuit) {
        final ro = tuteRankOrder(c);
        if (ro > highestLedRank) highestLedRank = ro;
      }
    }
    // Montar: beat the highest card of the led suit if able
    final higher =
        sameSuit.where((c) => tuteRankOrder(c) > highestLedRank).toList();
    return higher.isNotEmpty ? higher : sameSuit;
  }

  // Void in led suit -> Fallar (must play trump if holding any)
  final trumps = hand.where((c) => tuteCardSuit(c) == trumpSuit).toList();
  if (trumps.isNotEmpty) {
    var highestTrumpRank = -1;
    for (final e in trick) {
      final c = asStr(e['card']);
      if (tuteCardSuit(c) == trumpSuit) {
        final ro = tuteRankOrder(c);
        if (ro > highestTrumpRank) highestTrumpRank = ro;
      }
    }
    if (highestTrumpRank >= 0) {
      final higherTrumps =
          trumps.where((c) => tuteRankOrder(c) > highestTrumpRank).toList();
      if (higherTrumps.isNotEmpty) return higherTrumps;
    }
    return trumps;
  }

  return List<String>.of(hand);
}

/// Returns suits for which [hand] holds both `'K$suit'` and `'Q$suit'` and which are not yet in [declaredSuits].
List<String> tuteAvailableCantes(
  List<String> hand,
  Set<String> declaredSuits,
) {
  final out = <String>[];
  for (final s in tuteSuits) {
    if (!declaredSuits.contains(s) &&
        hand.contains('K$s') &&
        hand.contains('Q$s')) {
      out.add(s);
    }
  }
  return out;
}

/// Points for declaring Cante (`K+Q`) in [suit] given [trumpSuit]:
/// `40` pts for Trump Suit (`Las Cuarenta`), `20` pts for non-trump suit (`Veinte`).
int tuteCantePoints(String suit, String trumpSuit) =>
    suit == trumpSuit ? 40 : 20;

/// Checks if [hand] holds all 4 Kings (`'K'`) or all 4 Queens (`'Q'`) for a `'tute'` instant win.
/// Returns `'kings'`, `'queens'`, or `null`.
String? tuteCheckTuteInHand(List<String> hand) {
  if (tuteSuits.every((s) => hand.contains('K$s'))) return 'kings';
  if (tuteSuits.every((s) => hand.contains('Q$s'))) return 'queens';
  return null;
}

class TuteGame extends GameEngine {
  late int totalRounds;
  int round = 1;
  int dealer = 0;
  int leader = 1;
  int turn = 1;
  String phase = 'play';

  String trumpCard = '2O';
  String trumpSuit = 'O';
  List<String> stock = [];

  late List<List<String>> hands;
  late List<int> scores; // Cumulative match points per seat
  late List<int> sideScores; // Cumulative match points per side
  late List<int> handCardPoints; // Card points (out of 120 + 10 last trick) per side
  late List<int> handCantePoints; // Cante points (+20/+40) per side
  late List<int> sideTricksWon; // Tricks won in current hand per side
  late List<Set<String>> sideDeclaredCantes; // Suits declared per side
  List<Map<String, dynamic>> canteLog = [];

  List<Map<String, dynamic>> trick = [];
  Map<String, dynamic>? lastTrick;
  Map<String, dynamic>? lastHandSummary;
  int trickNumber = 1;

  bool _over = false;
  List<int>? _placings;

  TuteGame(super.setup) {
    totalRounds = setup.opt<int>('rounds', 2);
    final nSides = numSides;
    hands = List.generate(players, (_) => <String>[]);
    scores = List.filled(players, 0);
    sideScores = List.filled(nSides, 0);
    handCardPoints = List.filled(nSides, 0);
    handCantePoints = List.filled(nSides, 0);
    sideTricksWon = List.filled(nSides, 0);
    sideDeclaredCantes = List.generate(nSides, (_) => <String>{});
  }

  int get numSides => players == 4 ? 2 : players;
  int sideOf(int seat) => tuteSideOf(seat, players);

  /// Whether strict Spanish following rules (Montar & Fallar) are currently enforced.
  /// Enforced once the stock is empty (and throughout 4p where stock is empty from the deal).
  bool get isStrictFollowing => stock.isEmpty;

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
    _startRound();
  }

  void _startRound() {
    final deck = shuffled(buildTuteDeck(), rng);
    if (players == 4) {
      // 4 players (2v2): deal all 10 cards each; dealer's last card determines trump
      for (var s = 0; s < 4; s++) {
        hands[s] = deck.sublist(s * 10, (s + 1) * 10);
      }
      trumpCard = hands[dealer].last;
      trumpSuit = tuteCardSuit(trumpCard);
      stock = [];
    } else if (players == 3) {
      // 3 players: set aside a 0-point '2' card as trump indicator so 39 cards (all 120 pts) are played
      final twoIdx = deck.lastIndexWhere((c) => tuteCardRank(c) == '2');
      trumpCard = deck.removeAt(twoIdx >= 0 ? twoIdx : deck.length - 1);
      trumpSuit = tuteCardSuit(trumpCard);
      for (var s = 0; s < 3; s++) {
        hands[s] = deck.sublist(s * 8, (s + 1) * 8);
      }
      stock = deck.sublist(24); // 15 cards -> 5 draw rounds of 3 cards
    } else {
      // 2 players: deal 8 cards each; remaining 24 cards form stock with trumpCard at bottom
      for (var s = 0; s < 2; s++) {
        hands[s] = deck.sublist(s * 8, (s + 1) * 8);
      }
      stock = deck.sublist(16);
      trumpCard = stock.last;
      trumpSuit = tuteCardSuit(trumpCard);
    }

    for (var s = 0; s < players; s++) {
      _sortHand(hands[s]);
    }

    handCardPoints = List.filled(numSides, 0);
    handCantePoints = List.filled(numSides, 0);
    sideTricksWon = List.filled(numSides, 0);
    sideDeclaredCantes = List.generate(numSides, (_) => <String>{});
    canteLog = [];
    trick = [];
    trickNumber = 1;
    phase = 'play';
    leader = (dealer + 1) % players;
    turn = leader;

    host.log('第 $round/$totalRounds 局开始：主牌花色 ${tuteSuitNames[trumpSuit] ?? trumpSuit}（指示牌 $trumpCard）');
  }

  void _sortHand(List<String> hand) {
    hand.sort((a, b) {
      final ta = tuteCardSuit(a) == trumpSuit;
      final tb = tuteCardSuit(b) == trumpSuit;
      if (ta != tb) return ta ? -1 : 1;
      final sa = tuteSuits.indexOf(tuteCardSuit(a));
      final sb = tuteSuits.indexOf(tuteCardSuit(b));
      if (sa != sb) return sa.compareTo(sb);
      return tuteRankOrder(b).compareTo(tuteRankOrder(a));
    });
  }

  List<String> legalCards(int seat) => tuteLegalCards(
        hands[seat],
        trick,
        trumpSuit,
        strict: isStrictFollowing,
      );

  List<String> availableCantes(int seat) {
    if (_over || phase != 'play' || seat != turn || trick.isNotEmpty) {
      return const [];
    }
    if (sideTricksWon[sideOf(seat)] <= 0) return const [];
    return tuteAvailableCantes(hands[seat], sideDeclaredCantes[sideOf(seat)]);
  }

  String? availableTute(int seat) {
    if (_over || phase != 'play' || seat != turn || trick.isNotEmpty) {
      return null;
    }
    if (sideTricksWon[sideOf(seat)] <= 0) return null;
    return tuteCheckTuteInHand(hands[seat]);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);

    if (type == 'cante') {
      if (trick.isNotEmpty) {
        throw GameError('只能在领出新一墩前宣告 Cante (王后组合)');
      }
      final side = sideOf(seat);
      final avail = tuteAvailableCantes(hands[seat], sideDeclaredCantes[side]);
      if (avail.isEmpty) {
        throw GameError('手中没有可宣告的同花色 K+Q (Cante)');
      }
      var suit = asStr(action['suit']);
      if (suit.isEmpty) {
        suit = avail.contains(trumpSuit) ? trumpSuit : avail.first;
      }
      if (!avail.contains(suit)) {
        throw GameError('该花色无法宣告 Cante');
      }
      final pts = tuteCantePoints(suit, trumpSuit);
      sideDeclaredCantes[side].add(suit);
      handCantePoints[side] += pts;
      canteLog.add({
        'seat': seat,
        'side': side,
        'suit': suit,
        'points': pts,
      });
      host.log('${name(seat)} 宣告 ${suit == trumpSuit ? "Las Cuarenta (主花色K+Q)" : "Veinte (${tuteSuitNames[suit]} K+Q)"}，获得 +$pts 分！');
      return;
    }

    if (type == 'tute') {
      if (trick.isNotEmpty) {
        throw GameError('只能在领出新一墩前宣告 Tute');
      }
      final kind = tuteCheckTuteInHand(hands[seat]);
      if (kind == null) {
        throw GameError('需要集齐 4 张 K 或 4 张 Q 才能宣告 Tute');
      }
      final side = sideOf(seat);
      host.log('${name(seat)} 集齐四张${kind == "kings" ? "国王 (4K)" : "骑士 (4Q)"}，宣告「Tute!」直接赢得本局！');
      _finishRound(tuteWinSide: side, tuteSeat: seat, tuteKind: kind);
      return;
    }

    if (type == 'play') {
      final card = asStr(action['card']);
      if (!hands[seat].contains(card)) {
        throw GameError('手牌中没有该张牌');
      }
      final legal = legalCards(seat);
      if (!legal.contains(card)) {
        throw GameError('违反西班牙跟牌规则（Montar 必压大 / Fallar 无花必毙）');
      }

      hands[seat].remove(card);
      trick.add({
        'seat': seat,
        'card': card,
      });

      if (trick.length < players) {
        turn = (turn + 1) % players;
        return;
      }

      _resolveTrick();
      return;
    }

    throw GameError('未知操作：$type');
  }

  void _resolveTrick() {
    final winner = tuteTrickWinner(trick, trumpSuit);
    final winSide = sideOf(winner);
    var pts = 0;
    for (final e in trick) {
      pts += tuteCardPoints(asStr(e['card']));
    }

    handCardPoints[winSide] += pts;
    sideTricksWon[winSide] += 1;

    // Draw from stock if non-empty (starting from trick winner)
    if (stock.length >= players) {
      for (var i = 0; i < players; i++) {
        final s = (winner + i) % players;
        hands[s].add(stock.removeAt(0));
        _sortHand(hands[s]);
      }
    } else {
      stock.clear();
    }

    final isLastTrick = hands.every((h) => h.isEmpty);
    if (isLastTrick) {
      // Diez de últimas (+10 pts for winning the last trick)
      handCardPoints[winSide] += 10;
    }

    lastTrick = {
      'trickNumber': trickNumber,
      'winner': winner,
      'winSide': winSide,
      'points': pts + (isLastTrick ? 10 : 0),
      'deUltimas': isLastTrick,
      'cards': [for (final e in trick) Map<String, dynamic>.of(e)],
    };

    trick = [];
    leader = winner;
    turn = winner;
    trickNumber += 1;

    if (isLastTrick) {
      _finishRound(lastTrickWinner: winner);
    }
  }

  void _finishRound({
    int? lastTrickWinner,
    int? tuteWinSide,
    int? tuteSeat,
    String? tuteKind,
  }) {
    final roundTotals = List<int>.filled(numSides, 0);
    if (tuteWinSide != null) {
      roundTotals[tuteWinSide] = 260;
    } else {
      for (var side = 0; side < numSides; side++) {
        roundTotals[side] = handCardPoints[side] + handCantePoints[side];
      }
    }

    for (var side = 0; side < numSides; side++) {
      sideScores[side] += roundTotals[side];
    }
    for (var s = 0; s < players; s++) {
      scores[s] = sideScores[sideOf(s)];
    }

    lastHandSummary = {
      'round': round,
      'trumpSuit': trumpSuit,
      'trumpCard': trumpCard,
      'handCardPoints': List<int>.of(handCardPoints),
      'handCantePoints': List<int>.of(handCantePoints),
      'roundTotals': roundTotals,
      'lastTrickWinner': lastTrickWinner,
      'tuteWinSide': tuteWinSide,
      'tuteSeat': tuteSeat,
      'tuteKind': tuteKind,
    };

    if (round >= totalRounds) {
      _over = true;
      _placings = rankByScore(scores);
      host.log('比赛结束！');
    } else {
      round += 1;
      dealer = (dealer + 1) % players;
      _startRound();
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    // Declare Tute immediately if available
    if (availableTute(seat) != null) {
      return {'type': 'tute'};
    }

    // Declare Cante if available
    final cantes = availableCantes(seat);
    if (cantes.isNotEmpty) {
      final chosen = cantes.contains(trumpSuit) ? trumpSuit : cantes.first;
      return {'type': 'cante', 'suit': chosen};
    }

    final legal = legalCards(seat);
    if (legal.isEmpty) return null;

    if (botLevel == 0) {
      return {'type': 'play', 'card': legal[rng.nextInt(legal.length)]};
    }

    if (trick.isEmpty) {
      // Lead low non-trump while stock is non-empty, or strong card in endgame
      if (stock.isNotEmpty) {
        final nonTrumps =
            legal.where((c) => tuteCardSuit(c) != trumpSuit).toList();
        final pool = nonTrumps.isNotEmpty ? nonTrumps : legal;
        pool.sort((a, b) => tuteRankOrder(a).compareTo(tuteRankOrder(b)));
        return {'type': 'play', 'card': pool.first};
      }
      final sorted = List<String>.of(legal)
        ..sort((a, b) => tuteRankOrder(b).compareTo(tuteRankOrder(a)));
      return {'type': 'play', 'card': sorted.first};
    }

    final leadSuit = tuteCardSuit(asStr(trick.first['card']));
    var curBestStr = -1;
    for (final e in trick) {
      final str = tuteCardStrength(asStr(e['card']), trumpSuit, leadSuit);
      if (str > curBestStr) curBestStr = str;
    }

    final winners = legal
        .where((c) => tuteCardStrength(c, trumpSuit, leadSuit) > curBestStr)
        .toList();
    if (winners.isNotEmpty) {
      winners.sort((a, b) => tuteCardStrength(a, trumpSuit, leadSuit)
          .compareTo(tuteCardStrength(b, trumpSuit, leadSuit)));
      return {'type': 'play', 'card': winners.first};
    }

    // Cannot win trick: discard lowest point card
    final sortedAsc = List<String>.of(legal)
      ..sort((a, b) {
        final pa = tuteCardPoints(a);
        final pb = tuteCardPoints(b);
        if (pa != pb) return pa.compareTo(pb);
        return tuteRankOrder(a).compareTo(tuteRankOrder(b));
      });
    return {'type': 'play', 'card': sortedAsc.first};
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myLegal = (seat >= 0 && seat < players && seat == turn && phase == 'play')
        ? legalCards(seat)
        : <String>[];
    final myCantes = (seat >= 0 && seat < players)
        ? availableCantes(seat)
        : const <String>[];
    final myTute = (seat >= 0 && seat < players) ? availableTute(seat) : null;

    return {
      'round': round,
      'totalRounds': totalRounds,
      'phase': phase,
      'dealer': dealer,
      'leader': leader,
      'turn': turn,
      'trumpCard': trumpCard,
      'trumpSuit': trumpSuit,
      'trumpSuitName': tuteSuitNames[trumpSuit] ?? trumpSuit,
      'stockCount': stock.length,
      'strictFollowing': isStrictFollowing,
      'trickNumber': trickNumber,
      'scores': List<int>.of(scores),
      'sideScores': List<int>.of(sideScores),
      'handCardPoints': List<int>.of(handCardPoints),
      'handCantePoints': List<int>.of(handCantePoints),
      'sideTricksWon': List<int>.of(sideTricksWon),
      'canteLog': [for (final e in canteLog) Map<String, dynamic>.of(e)],
      'handCounts': [for (final h in hands) h.length],
      'hand': (seat >= 0 && seat < players) ? List<String>.of(hands[seat]) : <String>[],
      'legal': myLegal,
      'availableCantes': myCantes,
      'availableTute': myTute,
      'trick': [for (final e in trick) Map<String, dynamic>.of(e)],
      'lastTrick': lastTrick,
      'lastHandSummary': lastHandSummary,
      'over': _over,
      'placings': _placings,
    };
  }
}
