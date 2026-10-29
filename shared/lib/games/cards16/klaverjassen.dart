import '../../src/engine.dart';

const List<String> klaverjassenSuits = ['S', 'H', 'D', 'C'];
const List<String> klaverjassenRanks = ['7', '8', '9', 'T', 'J', 'Q', 'K', 'A'];

const Map<String, String> klaverjassenSuitNames = {
  'S': '♠ 黑桃 (Schoppen)',
  'H': '♥ 红心 (Harten)',
  'D': '♦ 方块 (Ruiten)',
  'C': '♣ 梅花 (Klaveren)',
};

String klaverjassenCardRank(String card) =>
    card.length >= 2 ? card.substring(0, card.length - 1) : '';

String klaverjassenCardSuit(String card) =>
    card.length >= 2 ? card[card.length - 1] : '';

/// Builds the 32-card Klaverjassen deck (`7, 8, 9, T, J, Q, K, A` in `S, H, D, C`).
List<String> buildKlaverjassenDeck() => [
      for (final s in klaverjassenSuits)
        for (final r in klaverjassenRanks) '$r$s',
    ];

/// Card point values in Klaverjassen (`62` in trump suit + `3 × 30` in non-trump suits = `152` card points,
/// plus `+10` for winning the 8th trick = `162` base points).
int klaverjassenCardPoints(String card, String trumpSuit) {
  final r = klaverjassenCardRank(card);
  final s = klaverjassenCardSuit(card);
  if (s == trumpSuit) {
    return switch (r) {
      'J' => 20, // Jas
      '9' => 14, // Nel
      'A' => 11,
      'T' => 10,
      'K' => 4,
      'Q' => 3,
      _ => 0,
    };
  }
  return switch (r) {
    'A' => 11,
    'T' => 10,
    'K' => 4,
    'Q' => 3,
    'J' => 2,
    _ => 0,
  };
}

/// Rank order within the Trump suit: `J(8) > 9(7) > A(6) > T(5) > K(4) > Q(3) > 8(2) > 7(1)`.
int klaverjassenTrumpOrder(String rank) => switch (rank) {
      'J' => 8, // Jas
      '9' => 7, // Nel
      'A' => 6,
      'T' => 5,
      'K' => 4,
      'Q' => 3,
      '8' => 2,
      '7' => 1,
      _ => 0,
    };

/// Rank order within a Non-Trump suit: `A(8) > T(7) > K(6) > Q(5) > J(4) > 9(3) > 8(2) > 7(1)`.
int klaverjassenNonTrumpOrder(String rank) => switch (rank) {
      'A' => 8,
      'T' => 7,
      'K' => 6,
      'Q' => 5,
      'J' => 4,
      '9' => 3,
      '8' => 2,
      '7' => 1,
      _ => 0,
    };

/// Natural sequence order for Roem melds (`7 < 8 < 9 < T < J < Q < K < A`).
int klaverjassenSequenceIndex(String rank) => switch (rank) {
      '7' => 0,
      '8' => 1,
      '9' => 2,
      'T' => 3,
      'J' => 4,
      'Q' => 5,
      'K' => 6,
      'A' => 7,
      _ => -10,
    };

/// Trick-taking strength of [card] given [trumpSuit] and [leadSuit].
int klaverjassenCardStrength(String card, String trumpSuit, String leadSuit) {
  final r = klaverjassenCardRank(card);
  final s = klaverjassenCardSuit(card);
  if (s == trumpSuit) {
    return 100 + klaverjassenTrumpOrder(r);
  }
  if (s == leadSuit) {
    return 10 + klaverjassenNonTrumpOrder(r);
  }
  return 0;
}

/// Determines the winning seat of [trick] given [trumpSuit].
int klaverjassenTrickWinner(
  List<Map<String, dynamic>> trick,
  String trumpSuit,
) {
  if (trick.isEmpty) return 0;
  final firstCard = asStr(trick.first['card']);
  final leadSuit = klaverjassenCardSuit(firstCard);
  var bestSeat = asInt(trick.first['seat'], 0);
  var bestStr = klaverjassenCardStrength(firstCard, trumpSuit, leadSuit);
  for (var i = 1; i < trick.length; i++) {
    final c = asStr(trick[i]['card']);
    final str = klaverjassenCardStrength(c, trumpSuit, leadSuit);
    if (str > bestStr) {
      bestStr = str;
      bestSeat = asInt(trick[i]['seat'], 0);
    }
  }
  return bestSeat;
}

/// Calculates total Roem (trick meld bonus points) present in a 4-card trick [cards]:
/// - 4-card same-suit sequence (`7-8-9-T`, ..., `J-Q-K-A`): `+50`
/// - 3-card same-suit sequence: `+20`
/// - Stuk (`K` + `Q` of [trumpSuit] in the same trick): `+20`
/// - Four of a Kind (4 cards of the same rank): `+100`
int klaverjassenTrickRoem(List<String> cards, String trumpSuit) {
  if (cards.length < 3) return 0;
  var roem = 0;

  // 1. Check Four of a Kind (4 cards of identical rank)
  if (cards.length == 4) {
    final r0 = klaverjassenCardRank(cards[0]);
    if (r0.isNotEmpty && cards.every((c) => klaverjassenCardRank(c) == r0)) {
      roem += 100;
    }
  }

  // 2. Check 4-card or 3-card same-suit sequence in natural order (7,8,9,T,J,Q,K,A)
  for (final s in klaverjassenSuits) {
    final suitSeq = cards
        .where((c) => klaverjassenCardSuit(c) == s)
        .map((c) => klaverjassenSequenceIndex(klaverjassenCardRank(c)))
        .toSet()
        .toList()
      ..sort();
    if (suitSeq.length == 4 && suitSeq[3] - suitSeq[0] == 3) {
      roem += 50;
    } else if (suitSeq.length >= 3) {
      var has3 = false;
      for (var i = 0; i <= suitSeq.length - 3; i++) {
        if (suitSeq[i + 2] - suitSeq[i] == 2) {
          has3 = true;
          break;
        }
      }
      if (has3) roem += 20;
    }
  }

  // 3. Check Stuk (King + Queen of Trumps in the trick)
  if (cards.contains('K$trumpSuit') && cards.contains('Q$trumpSuit')) {
    roem += 20;
  }

  return roem;
}

class KlaverjassenGame extends GameEngine {
  late int totalRounds;
  int round = 1;
  int dealer = 0;
  int forehand = 1;
  int leader = 1;
  int turn = 1;
  String phase = 'trump'; // 'trump' | 'play'
  String proposedSuit = 'C';
  String trumpSuit = 'C';
  int declarer = 1;
  int passCount = 0;

  late List<List<String>> hands;
  late List<int> scores; // Individual seat scores (team 0 = seats 0&2, team 1 = seats 1&3)
  late List<int> teamScores; // [team0, team1]
  late List<int> teamBasePoints; // Card points + last trick +10 for current round
  late List<int> teamRoem; // Roem points for current round
  late List<int> teamTricks; // Tricks won in current round
  List<Map<String, dynamic>> trick = [];
  Map<String, dynamic>? lastTrick;
  Map<String, dynamic>? lastHandSummary;
  int trickNumber = 1;

  bool _over = false;
  List<int>? _placings;

  KlaverjassenGame(super.setup) {
    totalRounds = setup.opt<int>('rounds', 4);
    hands = List.generate(players, (_) => <String>[]);
    scores = List.filled(players, 0);
    teamScores = [0, 0];
    teamBasePoints = [0, 0];
    teamRoem = [0, 0];
    teamTricks = [0, 0];
  }

  int get declarerTeam => declarer % 2;

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
    final losingTeam = seat % 2;
    final winners = [
      for (var i = 0; i < players; i++)
        if (i % 2 != losingTeam) i,
    ];
    _placings = rankWinners(players, winners);
    host.log('${name(seat)} 认输');
  }

  @override
  void start() {
    _startRound();
  }

  void _startRound() {
    final deck = shuffled(buildKlaverjassenDeck(), rng);
    for (var s = 0; s < players; s++) {
      hands[s] = deck.sublist(s * 8, (s + 1) * 8);
    }
    proposedSuit = klaverjassenSuits[rng.nextInt(klaverjassenSuits.length)];
    trumpSuit = proposedSuit;
    for (var s = 0; s < players; s++) {
      _sortHand(hands[s]);
    }
    teamBasePoints = [0, 0];
    teamRoem = [0, 0];
    teamTricks = [0, 0];
    forehand = (dealer + 1) % players;
    declarer = forehand;
    leader = forehand;
    turn = forehand;
    passCount = 0;
    phase = 'trump';
    trick = [];
    trickNumber = 1;
    host.log('第 $round/$totalRounds 局开始，候选主牌花色：${klaverjassenSuitNames[proposedSuit]}，由 ${name(forehand)} 先选主');
  }

  void _sortHand(List<String> hand) {
    hand.sort((a, b) {
      final sa = klaverjassenCardSuit(a);
      final sb = klaverjassenCardSuit(b);
      final ta = sa == trumpSuit;
      final tb = sb == trumpSuit;
      if (ta != tb) return ta ? -1 : 1;
      if (ta && tb) {
        return klaverjassenTrumpOrder(klaverjassenCardRank(b))
            .compareTo(klaverjassenTrumpOrder(klaverjassenCardRank(a)));
      }
      final ia = klaverjassenSuits.indexOf(sa);
      final ib = klaverjassenSuits.indexOf(sb);
      if (ia != ib) return ia.compareTo(ib);
      return klaverjassenNonTrumpOrder(klaverjassenCardRank(b))
          .compareTo(klaverjassenNonTrumpOrder(klaverjassenCardRank(a)));
    });
  }

  /// Highest trump order (`1..8`) currently present in [trick], or `-1` if no trump is in [trick].
  int _highestTrumpOrderInTrick() {
    var best = -1;
    for (final e in trick) {
      final c = asStr(e['card']);
      if (klaverjassenCardSuit(c) == trumpSuit) {
        final ord = klaverjassenTrumpOrder(klaverjassenCardRank(c));
        if (ord > best) best = ord;
      }
    }
    return best;
  }

  /// Rotterdam Klaverjassen Mandatory Trump / Overtrump legal card filter:
  /// 1. If leading (`trick.isEmpty`): any card in hand.
  /// 2. If Trump was led (`leadSuit == trumpSuit`):
  ///    - Must play a higher Trump if holding one; else any Trump; else any card.
  /// 3. If Non-Trump was led (`leadSuit != trumpSuit`):
  ///    - If holding `leadSuit`: must follow `leadSuit`.
  ///    - If void in `leadSuit`: MUST play a Trump card if holding one, and if a Trump is already
  ///      in the trick, MUST overtrump with a higher Trump if holding one!
  List<String> legalCards(int seat) {
    final hand = hands[seat];
    if (trick.isEmpty) return List<String>.of(hand);

    final leadCard = asStr(trick.first['card']);
    final leadSuit = klaverjassenCardSuit(leadCard);
    final highestTrump = _highestTrumpOrderInTrick();
    final myTrumps = hand.where((c) => klaverjassenCardSuit(c) == trumpSuit).toList();
    final myHigherTrumps = myTrumps
        .where((c) => klaverjassenTrumpOrder(klaverjassenCardRank(c)) > highestTrump)
        .toList();

    if (leadSuit == trumpSuit) {
      if (myHigherTrumps.isNotEmpty) return myHigherTrumps;
      if (myTrumps.isNotEmpty) return myTrumps;
      return List<String>.of(hand);
    }

    // Non-trump suit led
    final myLeadSuit = hand.where((c) => klaverjassenCardSuit(c) == leadSuit).toList();
    if (myLeadSuit.isNotEmpty) return myLeadSuit;

    // Void in led suit -> mandatory trump & mandatory overtrump!
    if (myHigherTrumps.isNotEmpty) return myHigherTrumps;
    if (myTrumps.isNotEmpty) return myTrumps;
    return List<String>.of(hand);
  }

  void _beginPlay(int decl, String suit) {
    declarer = decl;
    trumpSuit = suit;
    phase = 'play';
    leader = forehand;
    turn = forehand;
    for (var s = 0; s < players; s++) {
      _sortHand(hands[s]);
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    if (phase == 'trump') {
      if (type == 'pass') {
        passCount += 1;
        if (passCount >= players) {
          _beginPlay(forehand, proposedSuit);
          host.log('四家均不叫，由先手 ${name(forehand)} 担任庄家，主牌花色：${klaverjassenSuitNames[proposedSuit]}');
          return;
        }
        turn = (turn + 1) % players;
        host.log('${name(seat)} 选择不叫 (Pass)');
        return;
      }

      if (type == 'accept' || type == 'play_trump') {
        _beginPlay(seat, proposedSuit);
        host.log('${name(seat)} 认领候选主牌 ${klaverjassenSuitNames[proposedSuit]}（搭档：${name((seat + 2) % 4)}）');
        return;
      }

      if (type == 'choose_trump' || klaverjassenSuits.contains(type.toUpperCase())) {
        final suit = (type == 'choose_trump'
                ? asStr(action['suit'], proposedSuit)
                : type)
            .toUpperCase();
        if (!klaverjassenSuits.contains(suit)) {
          throw GameError('请选择有效的主牌花色 (S / H / D / C)');
        }
        _beginPlay(seat, suit);
        host.log('${name(seat)} 宣告主牌花色为 ${klaverjassenSuitNames[suit]}（搭档：${name((seat + 2) % 4)}）');
        return;
      }

      throw GameError('请选择主牌花色或 Pass');
    }

    if (phase == 'play') {
      if (type != 'play') throw GameError('请出牌');
      final card = asStr(action['card']);
      if (!hands[seat].contains(card)) {
        throw GameError('手牌中没有该张牌');
      }
      final legal = legalCards(seat);
      if (!legal.contains(card)) {
        throw GameError('违反跟花或强制毙牌/超毙规则（无领出花色时必须用主牌毙牌并尽量超毙）');
      }

      hands[seat].remove(card);
      trick.add({'seat': seat, 'card': card});

      if (trick.length < players) {
        turn = (turn + 1) % players;
        return;
      }

      _resolveTrick();
      return;
    }

    throw GameError('未知阶段');
  }

  void _resolveTrick() {
    final winner = klaverjassenTrickWinner(trick, trumpSuit);
    final winTeam = winner % 2;
    final isLastTrick = trickNumber == 8 || hands.every((h) => h.isEmpty);

    var cardPts = 0;
    final cardsInTrick = <String>[];
    for (final entry in trick) {
      final c = asStr(entry['card']);
      cardsInTrick.add(c);
      cardPts += klaverjassenCardPoints(c, trumpSuit);
    }
    final lastTrickBonus = isLastTrick ? 10 : 0;
    final basePts = cardPts + lastTrickBonus;
    final roem = klaverjassenTrickRoem(cardsInTrick, trumpSuit);

    teamBasePoints[winTeam] += basePts;
    teamRoem[winTeam] += roem;
    teamTricks[winTeam] += 1;

    lastTrick = {
      'winner': winner,
      'winTeam': winTeam,
      'points': basePts,
      'roem': roem,
      'lastTrickBonus': lastTrickBonus,
      'cards': [for (final e in trick) Map<String, dynamic>.of(e)],
    };

    trick = [];
    leader = winner;
    turn = winner;
    trickNumber += 1;

    if (hands.every((h) => h.isEmpty)) {
      resolveRound();
    }
  }

  void resolveRound() {
    final declTeam = declarerTeam;
    final defTeam = 1 - declTeam;
    final totalRoem = teamRoem[0] + teamRoem[1];
    final totalStake = 162 + totalRoem;

    final declRaw = teamBasePoints[declTeam] + teamRoem[declTeam];
    final defRaw = teamBasePoints[defTeam] + teamRoem[defTeam];

    final pitDeclarer = teamTricks[declTeam] == 8;
    final pitDefender = teamTricks[defTeam] == 8;

    // Declarer team must score strictly more than half of (162 + totalRoem)
    final isNat = declRaw <= (totalStake ~/ 2);

    final awarded = [0, 0];
    if (isNat) {
      awarded[declTeam] = 0;
      awarded[defTeam] = totalStake + (pitDefender ? 100 : 0);
    } else if (pitDeclarer) {
      awarded[declTeam] = totalStake + 100;
      awarded[defTeam] = 0;
    } else {
      awarded[declTeam] = declRaw;
      awarded[defTeam] = defRaw;
    }

    teamScores[0] += awarded[0];
    teamScores[1] += awarded[1];
    for (var s = 0; s < players; s++) {
      scores[s] = teamScores[s % 2];
    }

    lastHandSummary = {
      'round': round,
      'trumpSuit': trumpSuit,
      'declarer': declarer,
      'declarerTeam': declTeam,
      'teamBasePoints': List<int>.of(teamBasePoints),
      'teamRoem': List<int>.of(teamRoem),
      'teamTricks': List<int>.of(teamTricks),
      'totalRoem': totalRoem,
      'isNat': isNat,
      'pit': pitDeclarer || pitDefender,
      'awarded': awarded,
    };

    final tag = isNat
        ? ' [Nat 宕牌！防守队全取 $totalStake 分]'
        : (pitDeclarer ? ' [Pit 全胜 8 墩 +100 分!]' : '');
    host.log('第 $round 局结算：0&2队 +${awarded[0]} 分 vs 1&3队 +${awarded[1]} 分$tag');

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

  int _evaluateSuitScore(List<String> hand, String suit) {
    var pts = 0;
    for (final c in hand) {
      if (klaverjassenCardSuit(c) == suit) {
        final r = klaverjassenCardRank(c);
        if (r == 'J') {
          pts += 20;
        } else if (r == '9') {
          pts += 14;
        } else if (r == 'A') {
          pts += 8;
        } else {
          pts += 4;
        }
      }
    }
    return pts;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    final hand = hands[seat];

    if (phase == 'trump') {
      // Find best suit in hand
      var bestSuit = proposedSuit;
      var bestVal = -1;
      for (final s in klaverjassenSuits) {
        final v = _evaluateSuitScore(hand, s);
        if (v > bestVal) {
          bestVal = v;
          bestSuit = s;
        }
      }
      if (bestVal >= 34) {
        return {'type': 'choose_trump', 'suit': bestSuit};
      }
      return {'type': 'pass'};
    }

    if (phase == 'play') {
      final legal = legalCards(seat);
      if (legal.isEmpty) return null;
      if (botLevel == 0) {
        return {'type': 'play', 'card': legal[rng.nextInt(legal.length)]};
      }

      if (trick.isEmpty) {
        // Lead Jas ('J' of trump) or an Ace if available
        final jas = 'J$trumpSuit';
        if (legal.contains(jas)) return {'type': 'play', 'card': jas};
        final aces = legal.where((c) => klaverjassenCardRank(c) == 'A').toList();
        if (aces.isNotEmpty) return {'type': 'play', 'card': aces.first};
        return {'type': 'play', 'card': legal.first};
      }

      final leadSuit = klaverjassenCardSuit(asStr(trick.first['card']));
      final curWinner = klaverjassenTrickWinner(trick, trumpSuit);
      final partnerWinning = (curWinner % 2) == (seat % 2);
      if (partnerWinning) {
        // Partner is currently winning: fatten the trick with high-point non-trump if safe, or lowest
        final sorted = List<String>.of(legal)
          ..sort((a, b) => klaverjassenCardPoints(b, trumpSuit)
              .compareTo(klaverjassenCardPoints(a, trumpSuit)));
        return {'type': 'play', 'card': sorted.first};
      }

      final curBestStr = klaverjassenCardStrength(
        asStr(trick.firstWhere((e) => e['seat'] == curWinner)['card']),
        trumpSuit,
        leadSuit,
      );
      final winning = legal
          .where((c) => klaverjassenCardStrength(c, trumpSuit, leadSuit) > curBestStr)
          .toList();
      if (winning.isNotEmpty) {
        winning.sort((a, b) => klaverjassenCardStrength(a, trumpSuit, leadSuit)
            .compareTo(klaverjassenCardStrength(b, trumpSuit, leadSuit)));
        return {'type': 'play', 'card': winning.first};
      }
      final low = List<String>.of(legal)
        ..sort((a, b) => klaverjassenCardPoints(a, trumpSuit)
            .compareTo(klaverjassenCardPoints(b, trumpSuit)));
      return {'type': 'play', 'card': low.first};
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myLegal = (seat >= 0 && seat < players && seat == turn && phase == 'play')
        ? legalCards(seat)
        : <String>[];
    return {
      'round': round,
      'totalRounds': totalRounds,
      'phase': phase,
      'dealer': dealer,
      'forehand': forehand,
      'leader': leader,
      'turn': turn,
      'proposedSuit': proposedSuit,
      'proposedSuitName': klaverjassenSuitNames[proposedSuit] ?? proposedSuit,
      'trumpSuit': trumpSuit,
      'trumpSuitName': klaverjassenSuitNames[trumpSuit] ?? trumpSuit,
      'declarer': declarer,
      'declarerTeam': declarerTeam,
      'trickNumber': trickNumber,
      'scores': List<int>.of(scores),
      'teamScores': List<int>.of(teamScores),
      'teamBasePoints': List<int>.of(teamBasePoints),
      'teamRoem': List<int>.of(teamRoem),
      'teamTricks': List<int>.of(teamTricks),
      'handCounts': [for (final h in hands) h.length],
      'hand': (seat >= 0 && seat < players) ? List<String>.of(hands[seat]) : <String>[],
      'legal': myLegal,
      'trick': [for (final e in trick) Map<String, dynamic>.of(e)],
      'lastTrick': lastTrick,
      'lastHandSummary': lastHandSummary,
      'over': _over,
      'placings': _placings,
    };
  }
}
