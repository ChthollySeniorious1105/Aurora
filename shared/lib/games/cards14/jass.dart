import '../../src/engine.dart';

const List<String> jassSuits = ['S', 'H', 'D', 'C'];
const List<String> jassRanks = ['6', '7', '8', '9', 'T', 'J', 'Q', 'K', 'A'];
const List<String> jassContracts = ['S', 'H', 'D', 'C', 'O', 'U'];

const Map<String, String> jassContractNames = {
  'S': '♠ 黑桃主牌',
  'H': '♥ 红心主牌',
  'D': '♦ 方块主牌',
  'C': '♣ 梅花主牌',
  'O': 'Obenabe 无主大牌胜',
  'U': 'Undenufe 无主小牌胜',
};

String jassCardRank(String card) =>
    card.length >= 2 ? card.substring(0, card.length - 1) : '';

String jassCardSuit(String card) =>
    card.length >= 2 ? card[card.length - 1] : '';

List<String> buildJassDeck() => [
      for (final s in jassSuits)
        for (final r in jassRanks) '$r$s',
    ];

/// Points of a single card under [contract] ('S','H','D','C','O','U').
/// Across all 36 cards, total card points = 152 (plus +5 for final trick = 157).
int jassCardPoints(String card, String contract) {
  final r = jassCardRank(card);
  final s = jassCardSuit(card);
  if (contract == 'O') {
    return switch (r) {
      'A' => 11,
      'K' => 4,
      'Q' => 3,
      'J' => 2,
      'T' => 10,
      '8' => 8,
      _ => 0,
    };
  }
  if (contract == 'U') {
    return switch (r) {
      '6' => 11,
      '8' => 8,
      'T' => 10,
      'J' => 2,
      'Q' => 3,
      'K' => 4,
      'A' => 0,
      _ => 0,
    };
  }
  // Trump suit contract ('S', 'H', 'D', 'C')
  if (s == contract) {
    return switch (r) {
      'J' => 20, // Puure
      '9' => 14, // Näll
      'A' => 11,
      'K' => 4,
      'Q' => 3,
      'T' => 10,
      _ => 0,
    };
  }
  return switch (r) {
    'A' => 11,
    'K' => 4,
    'Q' => 3,
    'J' => 2,
    'T' => 10,
    _ => 0,
  };
}

/// Rank order within a single suit for comparison.
/// Higher int means stronger card.
int jassRankOrder(String rank, {required bool isTrump, required String contract}) {
  if (contract == 'U') {
    // Undenufe: 6 > 7 > 8 > 9 > T > J > Q > K > A
    return switch (rank) {
      '6' => 9,
      '7' => 8,
      '8' => 7,
      '9' => 6,
      'T' => 5,
      'J' => 4,
      'Q' => 3,
      'K' => 2,
      'A' => 1,
      _ => 0,
    };
  }
  if (isTrump && jassSuits.contains(contract)) {
    // Trump: J > 9 > A > K > Q > T > 8 > 7 > 6
    return switch (rank) {
      'J' => 9,
      '9' => 8,
      'A' => 7,
      'K' => 6,
      'Q' => 5,
      'T' => 4,
      '8' => 3,
      '7' => 2,
      '6' => 1,
      _ => 0,
    };
  }
  // Non-trump or Obenabe: A > K > Q > J > T > 9 > 8 > 7 > 6
  return switch (rank) {
    'A' => 9,
    'K' => 8,
    'Q' => 7,
    'J' => 6,
    'T' => 5,
    '9' => 4,
    '8' => 3,
    '7' => 2,
    '6' => 1,
    _ => 0,
  };
}

/// Overall trick-taking strength of [card] given [contract] and [leadSuit].
int jassCardStrength(String card, String contract, String leadSuit) {
  final r = jassCardRank(card);
  final s = jassCardSuit(card);
  final isTrumpContract = jassSuits.contains(contract);
  if (isTrumpContract && s == contract) {
    return 100 + jassRankOrder(r, isTrump: true, contract: contract);
  }
  if (s == leadSuit) {
    return 10 + jassRankOrder(r, isTrump: false, contract: contract);
  }
  return 0;
}

/// Returns the winning seat of a completed or partial [trick].
int jassTrickWinner(List<Map<String, dynamic>> trick, String contract) {
  if (trick.isEmpty) return 0;
  final leadSuit = jassCardSuit(asStr(trick.first['card']));
  var bestSeat = asInt(trick.first['seat'], 0);
  var bestStrength = jassCardStrength(asStr(trick.first['card']), contract, leadSuit);
  for (var i = 1; i < trick.length; i++) {
    final c = asStr(trick[i]['card']);
    final str = jassCardStrength(c, contract, leadSuit);
    if (str > bestStrength) {
      bestStrength = str;
      bestSeat = asInt(trick[i]['seat'], 0);
    }
  }
  return bestSeat;
}

class JassGame extends GameEngine {
  late int totalRounds;
  int round = 1;
  int forehand = 0;
  int leader = 0;
  int turn = 0;
  String phase = 'choose_contract'; // 'choose_contract' | 'play'
  String? contract; // 'S' | 'H' | 'D' | 'C' | 'O' | 'U'
  bool schiebenUsed = false;

  late List<List<String>> hands;
  late List<int> scores;
  late List<int> handPoints;
  late List<int> tricksWon;
  List<Map<String, dynamic>> trick = [];
  Map<String, dynamic>? lastTrick;
  Map<String, dynamic>? lastHandSummary;
  int trickNumber = 1;

  bool _over = false;
  List<int>? _placings;

  JassGame(super.setup) {
    totalRounds = setup.opt<int>('rounds', 2);
    hands = List.generate(players, (_) => <String>[]);
    scores = List.filled(players, 0);
    handPoints = List.filled(players, 0);
    tricksWon = List.filled(players, 0);
  }

  bool get isTeamMode => players == 4;

  int partnerOf(int seat) =>
      isTeamMode ? (seat + 2) % 4 : (seat + 1) % players;

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
    if (isTeamMode) {
      final losingTeam = seat % 2;
      _placings = [
        for (var i = 0; i < players; i++) (i % 2 == losingTeam) ? 2 : 1,
      ];
    } else {
      final winners = [for (var i = 0; i < players; i++) if (i != seat) i];
      _placings = rankWinners(players, winners);
    }
    host.log('${name(seat)} 认输');
  }

  @override
  void start() {
    _startRound();
  }

  void _startRound() {
    final deck = shuffled(buildJassDeck(), rng);
    for (var s = 0; s < players; s++) {
      hands[s] = deck.sublist(s * 9, (s + 1) * 9);
      _sortHand(hands[s]);
      handPoints[s] = 0;
      tricksWon[s] = 0;
    }
    contract = null;
    schiebenUsed = false;
    phase = 'choose_contract';
    leader = forehand;
    turn = forehand;
    trick = [];
    trickNumber = 1;
    host.log('第 $round/$totalRounds 局开始，由 ${name(forehand)} 选择定约或传牌权(Schieben)');
  }

  void _sortHand(List<String> hand) {
    final c = contract ?? 'O';
    hand.sort((a, b) {
      final sa = jassSuits.indexOf(jassCardSuit(a));
      final sb = jassSuits.indexOf(jassCardSuit(b));
      if (sa != sb) return sa.compareTo(sb);
      final ra = jassRankOrder(jassCardRank(a), isTrump: jassCardSuit(a) == c, contract: c);
      final rb = jassRankOrder(jassCardRank(b), isTrump: jassCardSuit(b) == c, contract: c);
      return rb.compareTo(ra);
    });
  }

  List<String> legalCards(int seat) {
    final hand = hands[seat];
    if (trick.isEmpty) return List<String>.of(hand);
    final leadSuit = jassCardSuit(asStr(trick.first['card']));
    final c = contract ?? 'O';
    final isTrumpContract = jassSuits.contains(c);
    final sameSuit = hand.where((card) => jassCardSuit(card) == leadSuit).toList();
    if (sameSuit.isEmpty) return List<String>.of(hand);

    if (isTrumpContract) {
      if (leadSuit == c) {
        // In Swiss Jass, if only holding the Trump Jack (Puure), player may hold it back.
        if (sameSuit.length == 1 && sameSuit.first == 'J$c') {
          return List<String>.of(hand);
        }
        return sameSuit;
      } else {
        // May follow leadSuit OR play a trump card
        return hand
            .where((card) => jassCardSuit(card) == leadSuit || jassCardSuit(card) == c)
            .toList();
      }
    }
    return sameSuit;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    if (phase == 'choose_contract') {
      final chosen = type == 'schieben' ? 'schieben' : asStr(action['contract']);
      if (type == 'schieben' || chosen == 'schieben') {
        if (schiebenUsed) throw GameError('已经传过牌权，必须直接选择定约模式');
        schiebenUsed = true;
        turn = partnerOf(forehand);
        host.log('${name(seat)} 选择 Schieben（传牌权给 ${name(turn)}）');
        return;
      }
      if (type != 'choose_contract' && type != 'contract' && type != 'select_contract') {
        throw GameError('当前阶段请选择定约或传牌权');
      }
      if (!jassContracts.contains(chosen)) {
        throw GameError('无效的定约模式：$chosen');
      }
      contract = chosen;
      phase = 'play';
      leader = forehand;
      turn = forehand;
      for (var s = 0; s < players; s++) {
        _sortHand(hands[s]);
      }
      host.log('${name(seat)} 选定定约：${jassContractNames[chosen]}');
      return;
    }

    if (phase == 'play') {
      if (type != 'play') throw GameError('请出牌');
      var card = asStr(action['card']);
      if (card.isEmpty && action['index'] != null) {
        final idx = asInt(action['index'], -1);
        if (idx >= 0 && idx < hands[seat].length) {
          card = hands[seat][idx];
        }
      }
      if (!hands[seat].contains(card)) {
        throw GameError('手牌中没有该张牌');
      }
      final legal = legalCards(seat);
      if (!legal.contains(card)) {
        throw GameError('必须跟出领出花色或主牌');
      }

      hands[seat].remove(card);
      trick.add({'seat': seat, 'card': card});

      if (trick.length < players) {
        turn = (turn + 1) % players;
        return;
      }

      // Trick complete
      _resolveTrick();
      return;
    }

    throw GameError('未知阶段');
  }

  void _resolveTrick() {
    final c = contract ?? 'O';
    final winner = jassTrickWinner(trick, c);
    var pts = 0;
    for (final entry in trick) {
      pts += jassCardPoints(asStr(entry['card']), c);
    }
    final isFinalTrick = hands.every((h) => h.isEmpty);
    if (isFinalTrick) {
      pts += 5; // Final trick bonus (+5)
    }

    handPoints[winner] += pts;
    tricksWon[winner] += 1;

    lastTrick = {
      'winner': winner,
      'points': pts,
      'isFinal': isFinalTrick,
      'cards': [for (final e in trick) Map<String, dynamic>.of(e)],
    };

    trick = [];
    leader = winner;
    turn = winner;
    trickNumber += 1;

    if (isFinalTrick) {
      _finishRound();
    }
  }

  void _finishRound() {
    var matchTeamOrSeat = -1;
    final roundAwarded = List<int>.filled(players, 0);

    if (isTeamMode) {
      final team0Pts = handPoints[0] + handPoints[2];
      final team1Pts = handPoints[1] + handPoints[3];
      final team0Tricks = tricksWon[0] + tricksWon[2];
      final team1Tricks = tricksWon[1] + tricksWon[3];
      var t0 = team0Pts;
      var t1 = team1Pts;
      if (team0Tricks == 9) {
        t0 += 100;
        matchTeamOrSeat = 0;
      } else if (team1Tricks == 9) {
        t1 += 100;
        matchTeamOrSeat = 1;
      }
      roundAwarded[0] = t0;
      roundAwarded[2] = t0;
      roundAwarded[1] = t1;
      roundAwarded[3] = t1;
    } else {
      for (var s = 0; s < players; s++) {
        var p = handPoints[s];
        if (tricksWon[s] == 9) {
          p += 100;
          matchTeamOrSeat = s;
        }
        roundAwarded[s] = p;
      }
    }

    for (var s = 0; s < players; s++) {
      scores[s] += roundAwarded[s];
    }

    lastHandSummary = {
      'round': round,
      'contract': contract,
      'handPoints': List<int>.of(handPoints),
      'tricksWon': List<int>.of(tricksWon),
      'roundAwarded': roundAwarded,
      'matchBonus': matchTeamOrSeat,
    };

    host.log('第 $round 局结算：${[
      for (var s = 0; s < players; s++) '${name(s)} +${roundAwarded[s]}分'
    ].join('，')}');

    if (round >= totalRounds) {
      _over = true;
      _placings = rankByScore(scores);
      host.log('比赛结束！');
    } else {
      round += 1;
      forehand = (forehand + 1) % players;
      _startRound();
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    final hand = hands[seat];
    if (phase == 'choose_contract') {
      if (botLevel == 0) {
        final pick = jassContracts[rng.nextInt(jassContracts.length)];
        return {'type': 'choose_contract', 'contract': pick};
      }
      // Evaluate best contract for hand
      var bestContract = 'O';
      var bestEval = -1;
      for (final c in jassContracts) {
        var score = 0;
        for (final card in hand) {
          final r = jassCardRank(card);
          final s = jassCardSuit(card);
          if (jassSuits.contains(c) && s == c) {
            if (r == 'J') {
              score += 32;
            } else if (r == '9') {
              score += 24;
            } else if (r == 'A') {
              score += 16;
            } else {
              score += 8;
            }
          } else if (c == 'O') {
            if (r == 'A') {
              score += 18;
            } else if (r == 'K') {
              score += 10;
            } else if (r == 'Q' || r == 'T') {
              score += 6;
            }
          } else if (c == 'U') {
            if (r == '6') {
              score += 18;
            } else if (r == '7') {
              score += 10;
            } else if (r == '8') {
              score += 8;
            }
          } else if (r == 'A') {
            score += 8;
          }
        }
        if (score > bestEval) {
          bestEval = score;
          bestContract = c;
        }
      }
      if (!schiebenUsed && bestEval < 48) {
        return {'type': 'schieben'};
      }
      return {'type': 'choose_contract', 'contract': bestContract};
    }

    if (phase == 'play') {
      final legal = legalCards(seat);
      if (legal.isEmpty) return null;
      if (botLevel == 0) {
        return {'type': 'play', 'card': legal[rng.nextInt(legal.length)]};
      }
      final c = contract ?? 'O';
      if (trick.isEmpty) {
        // Lead strongest card
        legal.sort((a, b) => jassCardStrength(b, c, jassCardSuit(b))
            .compareTo(jassCardStrength(a, c, jassCardSuit(a))));
        return {'type': 'play', 'card': legal.first};
      }
      final leadSuit = jassCardSuit(asStr(trick.first['card']));
      final curWinner = jassTrickWinner(trick, c);
      final curBestStr = jassCardStrength(
        asStr(trick.firstWhere((e) => e['seat'] == curWinner)['card']),
        c,
        leadSuit,
      );
      final partnerWinning = isTeamMode && (curWinner % 2 == seat % 2);
      if (partnerWinning) {
        // Fattening (Schmieren): play high-point non-trump card if possible
        legal.sort((a, b) => jassCardPoints(b, c).compareTo(jassCardPoints(a, c)));
        return {'type': 'play', 'card': legal.first};
      }
      final winningPlays =
          legal.where((card) => jassCardStrength(card, c, leadSuit) > curBestStr).toList();
      if (winningPlays.isNotEmpty) {
        winningPlays.sort((a, b) =>
            jassCardStrength(a, c, leadSuit).compareTo(jassCardStrength(b, c, leadSuit)));
        return {'type': 'play', 'card': winningPlays.first};
      }
      // Sluff lowest point card
      legal.sort((a, b) {
        final pa = jassCardPoints(a, c);
        final pb = jassCardPoints(b, c);
        if (pa != pb) return pa.compareTo(pb);
        return jassCardStrength(a, c, leadSuit).compareTo(jassCardStrength(b, c, leadSuit));
      });
      return {'type': 'play', 'card': legal.first};
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
      'forehand': forehand,
      'leader': leader,
      'turn': turn,
      'contract': contract,
      'contractName': contract != null ? jassContractNames[contract!] : null,
      'schiebenUsed': schiebenUsed,
      'trickNumber': trickNumber,
      'isTeamMode': isTeamMode,
      'scores': List<int>.of(scores),
      'handPoints': List<int>.of(handPoints),
      'tricksWon': List<int>.of(tricksWon),
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
