import '../../src/engine.dart';

/// Italian suits in Tressette:
/// - `'D'`: Denari (金币 ♦)
/// - `'C'`: Coppe (圣杯 ♥)
/// - `'S'`: Spade (宝剑 ♠)
/// - `'B'`: Bastoni (权杖 ♣)
const List<String> tressetteSuits = ['D', 'C', 'S', 'B'];

/// Rank order in Tressette from lowest (`4`) to highest (`3`):
/// `4 < 5 < 6 < 7 < J (Fante) < Q (Cavallo) < K (Re) < A (Asso) < 2 (Due) < 3 (Tre)`.
const List<String> tressetteRanks = ['4', '5', '6', '7', 'J', 'Q', 'K', 'A', '2', '3'];

const Map<String, String> tressetteSuitNames = {
  'D': '♦ 金币 (Denari)',
  'C': '♥ 圣杯 (Coppe)',
  'S': '♠ 宝剑 (Spade)',
  'B': '♣ 权杖 (Bastoni)',
};

String tressetteCardRank(String card) =>
    card.length >= 2 ? card.substring(0, card.length - 1) : card;

String tressetteCardSuit(String card) =>
    card.length >= 2 ? card[card.length - 1] : '';

/// Builds the 40-card Italian Tressette deck (`4, 5, 6, 7, J, Q, K, A, 2, 3` in `D, C, S, B`).
List<String> buildTressetteDeck() => [
      for (final s in tressetteSuits)
        for (final r in tressetteRanks) '$r$s',
    ];

/// Rank order (`0..9`) where `3(9) > 2(8) > A(7) > K(6) > Q(5) > J(4) > 7(3) > 6(2) > 5(1) > 4(0)`.
int tressetteRankOrder(String cardOrRank) {
  final r = cardOrRank.length >= 2 ? tressetteCardRank(cardOrRank) : cardOrRank;
  return tressetteRanks.indexOf(r);
}

/// Point value of [card] measured in **thirds of a point (`1/3 pt`)**:
/// - `'A'` (Asso): **`3` thirds (`1` full point)**
/// - `'3', '2', 'K', 'Q', 'J'` (Figure / Scartini): **`1` third (`1/3` point)**
/// - `'7', '6', '5', '4'` (Scarti): **`0` thirds**
int tressetteCardThirds(String cardOrRank) {
  final r = cardOrRank.length >= 2 ? tressetteCardRank(cardOrRank) : cardOrRank;
  return switch (r) {
    'A' => 3,
    '3' || '2' || 'K' || 'Q' || 'J' => 1,
    _ => 0,
  };
}

/// Converts [thirds] into full points (`3 thirds = 1 full point`, fractional thirds dropped at hand end).
int tressetteThirdsToFullPoints(int thirds) => thirds ~/ 3;

/// Formats [thirds] as a readable string (e.g. `10` thirds -> `'3⅓ 分 (10/3)'`).
String tressetteFormatThirds(int thirds) {
  final full = thirds ~/ 3;
  final rem = thirds % 3;
  if (rem == 0) return '$full分';
  if (rem == 1) return '$full⅓分';
  return '$full⅔分';
}

/// Side index for [seat]:
/// - In 4-player partnership mode: `seat % 2` (`0` for `0&2`, `1` for `1&3`).
/// - In 2-player or 3-player mode: `seat`.
int tressetteSideOf(int seat, int players) => players == 4 ? (seat % 2) : seat;

/// Evaluates the winning seat of a completed [trick] in Tressette.
/// Tressette has **NO Trump Suit**: the highest rank (`3 > 2 > A > K > Q > J > 7 > 6 > 5 > 4`)
/// of the **LED SUIT** always wins!
int tressetteTrickWinner(List<Map<String, dynamic>> trick) {
  if (trick.isEmpty) return 0;
  final leadCard = asStr(trick.first['card']);
  final leadSuit = tressetteCardSuit(leadCard);
  var bestSeat = asInt(trick.first['seat'], 0);
  var bestOrder = tressetteRankOrder(leadCard);

  for (var i = 1; i < trick.length; i++) {
    final c = asStr(trick[i]['card']);
    if (tressetteCardSuit(c) == leadSuit) {
      final order = tressetteRankOrder(c);
      if (order > bestOrder) {
        bestOrder = order;
        bestSeat = asInt(trick[i]['seat'], 0);
      }
    }
  }
  return bestSeat;
}

/// Legal cards from [hand] given current [trick] in Tressette:
/// Players **MUST follow the led suit (`leadSuit`)** if able (even in 2-player mode while stock is non-empty);
/// they are NOT required to beat the led card. If void in `leadSuit`, any card may be played.
List<String> tressetteLegalCards(
  List<String> hand,
  List<Map<String, dynamic>> trick,
) {
  if (trick.isEmpty) return List<String>.of(hand);
  final leadSuit = tressetteCardSuit(asStr(trick.first['card']));
  final sameSuit = hand.where((c) => tressetteCardSuit(c) == leadSuit).toList();
  return sameSuit.isNotEmpty ? sameSuit : List<String>.of(hand);
}

/// Computes available **Accuse (Melds)** in [hand] not yet in [declaredIds]:
/// 1. **`Napoli` (`3 + 2 + A` of the same suit `s`)**: `+3` full points (`+9` thirds), id `'napoli_$s'`
/// 2. **`Bongioco` (`three or four 3s, 2s, or Aces`)**:
///    - 4 of a kind in rank `r` (`'3', '2', 'A'`): `+4` full points (`+12` thirds), id `'bongioco_${r}_4'`
///    - 3 of a kind in rank `r` (`'3', '2', 'A'`): `+3` full points (`+9` thirds), id `'bongioco_${r}_3'`
List<Map<String, dynamic>> tressetteAvailableAccuse(
  List<String> hand, [
  Set<String> declaredIds = const <String>{},
]) {
  final out = <Map<String, dynamic>>[];

  // 1. Check Napoli (3 + 2 + A of the same suit)
  for (final s in tressetteSuits) {
    final id = 'napoli_$s';
    if (!declaredIds.contains(id) &&
        hand.contains('3$s') &&
        hand.contains('2$s') &&
        hand.contains('A$s')) {
      out.add({
        'id': id,
        'type': 'napoli',
        'suit': s,
        'cards': ['3$s', '2$s', 'A$s'],
        'points': 3,
        'thirds': 9,
        'label': 'Napoli (${tressetteSuitNames[s]} 3+2+A · +3分)',
      });
    }
  }

  // 2. Check Bongioco (Three or Four 3s, 2s, or Aces)
  for (final r in ['3', '2', 'A']) {
    final matching = hand.where((c) => tressetteCardRank(c) == r).toList();
    if (matching.length == 4) {
      final id4 = 'bongioco_${r}_4';
      final id3 = 'bongioco_${r}_3';
      if (!declaredIds.contains(id4) && !declaredIds.contains(id3)) {
        out.add({
          'id': id4,
          'type': 'bongioco',
          'rank': r,
          'count': 4,
          'cards': matching,
          'points': 4,
          'thirds': 12,
          'label': 'Bongioco (四张$r · +4分)',
        });
      }
    } else if (matching.length == 3) {
      final id3 = 'bongioco_${r}_3';
      if (!declaredIds.contains(id3)) {
        out.add({
          'id': id3,
          'type': 'bongioco',
          'rank': r,
          'count': 3,
          'cards': matching,
          'points': 3,
          'thirds': 9,
          'label': 'Bongioco (三张$r · +3分)',
        });
      }
    }
  }

  return out;
}

class TressetteGame extends GameEngine {
  late int totalRounds;
  int round = 1;
  int dealer = 0;
  int leader = 1;
  int turn = 1;
  String phase = 'play';

  List<String> stock = [];
  late List<List<String>> hands;

  late List<int> scores; // Cumulative full points per seat
  late List<int> sideScores; // Cumulative full points per side
  late List<int> handCardThirds; // Card + Ultima thirds (out of 35 thirds -> 11 full points) per side
  late List<int> handMeldPoints; // Accuse (Napoli / Bongioco) full points per side
  late List<int> sideTricksWon;
  late List<Set<String>> seatDeclaredAccuse;
  List<Map<String, dynamic>> accuseLog = [];

  List<Map<String, dynamic>> trick = [];
  Map<String, dynamic>? lastTrick;
  Map<String, dynamic>? lastHandSummary;
  int trickNumber = 1;

  bool _over = false;
  List<int>? _placings;

  TressetteGame(super.setup) {
    totalRounds = setup.opt<int>('rounds', 2);
    final nSides = numSides;
    hands = List.generate(players, (_) => <String>[]);
    scores = List.filled(players, 0);
    sideScores = List.filled(nSides, 0);
    handCardThirds = List.filled(nSides, 0);
    handMeldPoints = List.filled(nSides, 0);
    sideTricksWon = List.filled(nSides, 0);
    seatDeclaredAccuse = List.generate(players, (_) => <String>{});
  }

  int get numSides => players == 4 ? 2 : players;
  int sideOf(int seat) => tressetteSideOf(seat, players);

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

  void _sortHand(List<String> hand) {
    hand.sort((a, b) {
      final sa = tressetteSuits.indexOf(tressetteCardSuit(a));
      final sb = tressetteSuits.indexOf(tressetteCardSuit(b));
      if (sa != sb) return sa.compareTo(sb);
      return tressetteRankOrder(b).compareTo(tressetteRankOrder(a));
    });
  }

  void _startRound() {
    final deck = shuffled(buildTressetteDeck(), rng);
    if (players == 4) {
      for (var s = 0; s < 4; s++) {
        hands[s] = deck.sublist(s * 10, (s + 1) * 10);
      }
      stock = [];
    } else if (players == 3) {
      // Remove 0-point '4B' so 39 cards are used: 10 cards each + 9 cards in stock
      deck.remove('4B');
      for (var s = 0; s < 3; s++) {
        hands[s] = deck.sublist(s * 10, (s + 1) * 10);
      }
      stock = deck.sublist(30);
    } else {
      // 2 players: 10 cards each + 20 cards in stock
      for (var s = 0; s < 2; s++) {
        hands[s] = deck.sublist(s * 10, (s + 1) * 10);
      }
      stock = deck.sublist(20);
    }

    for (var s = 0; s < players; s++) {
      _sortHand(hands[s]);
    }

    handCardThirds = List.filled(numSides, 0);
    handMeldPoints = List.filled(numSides, 0);
    sideTricksWon = List.filled(numSides, 0);
    seatDeclaredAccuse = List.generate(players, (_) => <String>{});
    accuseLog = [];
    trick = [];
    trickNumber = 1;
    phase = 'play';
    leader = (dealer + 1) % players;
    turn = leader;

    host.log('第 $round/$totalRounds 局开始：无主牌（3 > 2 > A > K > Q > J > 7 > 6 > 5 > 4）');
  }

  List<String> legalCards(int seat) => tressetteLegalCards(hands[seat], trick);

  /// In Tressette, Accuse (`Napoli` / `Bongioco`) can be declared on Trick 1 (`trickNumber == 1`)
  /// when it is [seat]'s turn before playing their card.
  List<Map<String, dynamic>> availableAccuse(int seat) {
    if (_over || phase != 'play' || seat != turn || trickNumber != 1) {
      return const [];
    }
    return tressetteAvailableAccuse(hands[seat], seatDeclaredAccuse[seat]);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);

    if (type == 'accusa' || type == 'meld') {
      if (trickNumber != 1) {
        throw GameError('只能在第一墩 (Trick 1) 出牌前宣告 Accusa (Napoli / Bongioco)');
      }
      final avail = tressetteAvailableAccuse(hands[seat], seatDeclaredAccuse[seat]);
      if (avail.isEmpty) {
        throw GameError('手中没有可宣告的 Napoli (同花色3+2+A) 或 Bongioco (三/四张 3/2/A)');
      }
      final reqId = asStr(action['id'], asStr(action['meld']));
      Map<String, dynamic>? chosen;
      if (reqId.isEmpty) {
        chosen = avail.first;
      } else {
        for (final m in avail) {
          if (m['id'] == reqId || m['type'] == reqId) {
            chosen = m;
            break;
          }
        }
      }
      if (chosen == null) {
        throw GameError('无法宣告指定的组合：$reqId');
      }

      final id = asStr(chosen['id']);
      final pts = asInt(chosen['points'], 3);
      final side = sideOf(seat);
      seatDeclaredAccuse[seat].add(id);
      handMeldPoints[side] += pts;
      accuseLog.add({
        'seat': seat,
        'side': side,
        'id': id,
        'label': chosen['label'],
        'cards': chosen['cards'],
        'points': pts,
      });
      host.log('${name(seat)} 宣告 ${chosen['label']}！');
      return;
    }

    if (type == 'play') {
      final card = asStr(action['card']);
      if (!hands[seat].contains(card)) {
        throw GameError('手牌中没有 $card');
      }
      final legal = legalCards(seat);
      if (!legal.contains(card)) {
        throw GameError('必须跟出领出花色 (${tressetteSuitNames[tressetteCardSuit(asStr(trick.first['card']))]})');
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
    final winner = tressetteTrickWinner(trick);
    final winSide = sideOf(winner);
    var thirds = 0;
    for (final e in trick) {
      thirds += tressetteCardThirds(asStr(e['card']));
    }

    handCardThirds[winSide] += thirds;
    sideTricksWon[winSide] += 1;

    // Draw from stock if non-empty (starting from trick winner)
    final drawnCards = <Map<String, dynamic>>[];
    if (stock.length >= players) {
      for (var i = 0; i < players; i++) {
        final s = (winner + i) % players;
        final drawn = stock.removeAt(0);
        hands[s].add(drawn);
        _sortHand(hands[s]);
        drawnCards.add({'seat': s, 'card': drawn});
      }
    } else {
      stock.clear();
    }

    final isLastTrick = hands.every((h) => h.isEmpty);
    if (isLastTrick) {
      // Ultima / Rete: +3 thirds (+1 full point) for winning the last trick!
      handCardThirds[winSide] += 3;
    }

    lastTrick = {
      'trickNumber': trickNumber,
      'winner': winner,
      'winSide': winSide,
      'thirds': thirds + (isLastTrick ? 3 : 0),
      'ultima': isLastTrick,
      'cards': [for (final e in trick) Map<String, dynamic>.of(e)],
      'drawn': drawnCards,
    };

    trick = [];
    leader = winner;
    turn = winner;
    trickNumber += 1;

    if (isLastTrick) {
      _finishRound(lastTrickWinner: winner);
    }
  }

  void _finishRound({required int lastTrickWinner}) {
    final cardFullPoints = [
      for (var side = 0; side < numSides; side++)
        tressetteThirdsToFullPoints(handCardThirds[side]),
    ];
    final roundTotals = [
      for (var side = 0; side < numSides; side++)
        cardFullPoints[side] + handMeldPoints[side],
    ];

    for (var side = 0; side < numSides; side++) {
      sideScores[side] += roundTotals[side];
    }
    for (var s = 0; s < players; s++) {
      scores[s] = sideScores[sideOf(s)];
    }

    lastHandSummary = {
      'round': round,
      'handCardThirds': List<int>.of(handCardThirds),
      'cardFullPoints': cardFullPoints,
      'handMeldPoints': List<int>.of(handMeldPoints),
      'roundTotals': roundTotals,
      'lastTrickWinner': lastTrickWinner,
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

    // Declare any available Napoli / Bongioco on Trick 1
    final melds = availableAccuse(seat);
    if (melds.isNotEmpty) {
      return {'type': 'accusa', 'id': melds.first['id']};
    }

    final legal = legalCards(seat);
    if (legal.isEmpty) return null;

    if (botLevel == 0) {
      return {'type': 'play', 'card': legal[rng.nextInt(legal.length)]};
    }

    if (trick.isEmpty) {
      // Lead a strong 3 or 2 to pull Aces, or lead from longest suit
      final topHonors = legal.where((c) {
        final r = tressetteCardRank(c);
        return r == '3' || r == '2';
      }).toList();
      if (topHonors.isNotEmpty) {
        topHonors.sort((a, b) => tressetteRankOrder(b).compareTo(tressetteRankOrder(a)));
        return {'type': 'play', 'card': topHonors.first};
      }
      final sorted = List<String>.of(legal)
        ..sort((a, b) => tressetteRankOrder(a).compareTo(tressetteRankOrder(b)));
      return {'type': 'play', 'card': sorted.first};
    }

    final leadSuit = tressetteCardSuit(asStr(trick.first['card']));
    var curBestOrder = -1;
    var curBestSeat = -1;
    for (final e in trick) {
      final c = asStr(e['card']);
      if (tressetteCardSuit(c) == leadSuit) {
        final o = tressetteRankOrder(c);
        if (o > curBestOrder) {
          curBestOrder = o;
          curBestSeat = asInt(e['seat'], 0);
        }
      }
    }

    final sameSuit = legal.where((c) => tressetteCardSuit(c) == leadSuit).toList();
    if (sameSuit.isNotEmpty) {
      // If partner is already winning in 4p, play a high-point Ace or low card
      if (players == 4 && sideOf(curBestSeat) == sideOf(seat) && trick.length == 3) {
        final aces = sameSuit.where((c) => tressetteCardRank(c) == 'A').toList();
        if (aces.isNotEmpty) return {'type': 'play', 'card': aces.first};
      }
      final winners = sameSuit
          .where((c) => tressetteRankOrder(c) > curBestOrder)
          .toList();
      if (winners.isNotEmpty) {
        winners.sort((a, b) => tressetteRankOrder(a).compareTo(tressetteRankOrder(b)));
        return {'type': 'play', 'card': winners.first};
      }
      // Cannot beat led suit: play lowest value card
      sameSuit.sort((a, b) {
        final ta = tressetteCardThirds(a);
        final tb = tressetteCardThirds(b);
        if (ta != tb) return ta.compareTo(tb);
        return tressetteRankOrder(a).compareTo(tressetteRankOrder(b));
      });
      return {'type': 'play', 'card': sameSuit.first};
    }

    // Void in led suit: cannot win trick (no trump!), so slough a 0-point scarto
    final sortedAsc = List<String>.of(legal)
      ..sort((a, b) {
        final ta = tressetteCardThirds(a);
        final tb = tressetteCardThirds(b);
        if (ta != tb) return ta.compareTo(tb);
        return tressetteRankOrder(a).compareTo(tressetteRankOrder(b));
      });
    return {'type': 'play', 'card': sortedAsc.first};
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myLegal = (seat >= 0 && seat < players && seat == turn && phase == 'play')
        ? legalCards(seat)
        : <String>[];
    final myAccuse = (seat >= 0 && seat < players)
        ? availableAccuse(seat)
        : const <Map<String, dynamic>>[];

    return {
      'round': round,
      'totalRounds': totalRounds,
      'phase': phase,
      'dealer': dealer,
      'leader': leader,
      'turn': turn,
      'stockCount': stock.length,
      'trickNumber': trickNumber,
      'scores': List<int>.of(scores),
      'sideScores': List<int>.of(sideScores),
      'handCardThirds': List<int>.of(handCardThirds),
      'handCardFullPoints': [
        for (final t in handCardThirds) tressetteThirdsToFullPoints(t),
      ],
      'handMeldPoints': List<int>.of(handMeldPoints),
      'sideTricksWon': List<int>.of(sideTricksWon),
      'accuseLog': [for (final e in accuseLog) Map<String, dynamic>.of(e)],
      'handCounts': [for (final h in hands) h.length],
      'hand': (seat >= 0 && seat < players) ? List<String>.of(hands[seat]) : <String>[],
      'legal': myLegal,
      'availableAccuse': myAccuse,
      'trick': [for (final e in trick) Map<String, dynamic>.of(e)],
      'lastTrick': lastTrick,
      'lastHandSummary': lastHandSummary,
      'over': _over,
      'placings': _placings,
    };
  }
}
