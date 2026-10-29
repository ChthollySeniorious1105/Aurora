import '../../src/engine.dart';

const List<String> fiveHundredSuits = ['S', 'C', 'D', 'H'];
const List<String> fiveHundredStrains = ['S', 'C', 'D', 'H', 'NT'];

const Map<String, String> fiveHundredStrainNames = {
  'S': '♠ 黑桃 (Spades)',
  'C': '♣ 梅花 (Clubs)',
  'D': '♦ 方块 (Diamonds)',
  'H': '♥ 红心 (Hearts)',
  'NT': 'NT 无将 (No Trumps)',
  'MISERE': 'Misère 零墩无将 (250分)',
};

String fiveHundredCardRank(String card) {
  if (card == 'JK') return 'JK';
  return card.length >= 2 ? card.substring(0, card.length - 1) : '';
}

String fiveHundredCardSuit(String card) {
  if (card == 'JK') return 'JK';
  return card.length >= 2 ? card[card.length - 1] : '';
}

/// Same-color companion suit for Left Bower (`S <-> C`, `D <-> H`).
String fiveHundredSameColorSuit(String suit) => switch (suit) {
      'S' => 'C',
      'C' => 'S',
      'D' => 'H',
      'H' => 'D',
      _ => '',
    };

/// Builds the Five Hundred deck:
/// - `3` players (`33` cards): `'JK'` + `7..A` in `S, C, D, H` (`1 + 32 = 33` cards)
/// - `4` players (`43` cards): `'JK'` + `'4D'`, `'4H'` + `5..A` in `S, C, D, H` (`1 + 2 + 40 = 43` cards).
List<String> buildFiveHundredDeck([int players = 4]) {
  if (players == 3) {
    const ranks3 = ['7', '8', '9', 'T', 'J', 'Q', 'K', 'A'];
    return [
      'JK',
      for (final s in fiveHundredSuits)
        for (final r in ranks3) '$r$s',
    ];
  }
  const ranks4 = ['5', '6', '7', '8', '9', 'T', 'J', 'Q', 'K', 'A'];
  return [
    'JK',
    '4D',
    '4H',
    for (final s in fiveHundredSuits)
      for (final r in ranks4) '$r$s',
  ];
}

/// Avondale Scoring Table value for a bid of `(tricks, strain)` or `'MISERE'` (`250` pts):
/// - `6S=40, 6C=60, 6D=80, 6H=100, 6NT=120`
/// - `7S=140, 7C=160, 7D=180, 7H=200, 7NT=220`
/// - `8S=240, Misère=250, 8C=260, 8D=280, 8H=300, 8NT=320`
/// - (`9S=340..10NT=520` also supported).
int fiveHundredBidValue(int tricks, String strain) {
  final st = strain.toUpperCase();
  if (st == 'MISERE') return 250;
  final base = switch (st) {
    'S' => 40,
    'C' => 60,
    'D' => 80,
    'H' => 100,
    'NT' => 120,
    _ => -1,
  };
  if (base < 0 || tricks < 6 || tricks > 10) return -1;
  return base + (tricks - 6) * 100;
}

/// Base non-bower rank order (`4(1) < 5(2) < ... < K(10) < A(11)`).
int fiveHundredBaseRankOrder(String rank) => switch (rank) {
      'A' => 11,
      'K' => 10,
      'Q' => 9,
      'J' => 8,
      'T' => 7,
      '9' => 6,
      '8' => 5,
      '7' => 4,
      '6' => 3,
      '5' => 2,
      '4' => 1,
      _ => 0,
    };

/// Effective suit of [card] under [strain]:
/// - In Suit Contracts (`'S' | 'C' | 'D' | 'H'`):
///   - `'JK'` (The Joker), Right Bower (`'J$strain'`), and Left Bower (`'J${sameColorSuit(strain)}'`)
///     ALL count as belonging to the Trump Suit ([strain])!
/// - In `'NT'` or `'MISERE'`:
///   - `'JK'` has effective suit `'JK'`, and all other cards keep their printed suit.
String fiveHundredEffectiveSuit(String card, String strain) {
  final st = strain.toUpperCase();
  final isSuitTrump = fiveHundredSuits.contains(st);
  if (card == 'JK') {
    return isSuitTrump ? st : 'JK';
  }
  final r = fiveHundredCardRank(card);
  final s = fiveHundredCardSuit(card);
  if (isSuitTrump && r == 'J') {
    if (s == st || s == fiveHundredSameColorSuit(st)) {
      return st;
    }
  }
  return s;
}

/// Trick-taking strength of [card] given [strain] and [leadSuit]:
/// - `'JK'` (The Joker 🃏): `200` (highest card in the deck in both Suit and No-Trump contracts!)
/// - In Suit Contracts (`'S' | 'C' | 'D' | 'H'`):
///   - Right Bower (`'J$strain'`): `190`
///   - Left Bower (`'J${sameColorSuit(strain)}'`): `180`
///   - Other Trump Suit cards (`A > K > Q > T > 9 > 8 > 7 > 6 > 5 > 4`): `100 + rankOrder`
/// - Cards matching [leadSuit]: `10 + rankOrder`
/// - Off-suit cards: `0`.
int fiveHundredCardStrength(String card, String strain, String leadSuit) {
  if (card == 'JK') return 200;
  final st = strain.toUpperCase();
  final isSuitTrump = fiveHundredSuits.contains(st);
  final r = fiveHundredCardRank(card);
  final s = fiveHundredCardSuit(card);

  if (isSuitTrump) {
    if (r == 'J' && s == st) return 190; // Right Bower
    if (r == 'J' && s == fiveHundredSameColorSuit(st)) return 180; // Left Bower
    final eff = fiveHundredEffectiveSuit(card, st);
    if (eff == st) {
      return 100 + fiveHundredBaseRankOrder(r);
    }
    if (eff == leadSuit) {
      return 10 + fiveHundredBaseRankOrder(r);
    }
    return 0;
  }

  // No-Trump ('NT' or 'MISERE')
  if (s == leadSuit) {
    return 10 + fiveHundredBaseRankOrder(r);
  }
  return 0;
}

/// Determines the winning seat of [trick] given [strain].
int fiveHundredTrickWinner(List<Map<String, dynamic>> trick, String strain) {
  if (trick.isEmpty) return 0;
  final firstCard = asStr(trick.first['card']);
  final leadSuit = fiveHundredEffectiveSuit(firstCard, strain);
  var bestSeat = asInt(trick.first['seat'], 0);
  var bestStr = fiveHundredCardStrength(firstCard, strain, leadSuit);
  for (var i = 1; i < trick.length; i++) {
    final c = asStr(trick[i]['card']);
    final str = fiveHundredCardStrength(c, strain, leadSuit);
    if (str > bestStr) {
      bestStr = str;
      bestSeat = asInt(trick[i]['seat'], 0);
    }
  }
  return bestSeat;
}

class FiveHundredGame extends GameEngine {
  late int totalRounds;
  int round = 1;
  int dealer = 0;
  int forehand = 1;
  int leader = 1;
  int turn = 1;
  String phase = 'bid'; // 'bid' | 'kitty' | 'play'

  int declarer = -1;
  int contractTricks = 6;
  String contractStrain = 'S'; // 'S' | 'C' | 'D' | 'H' | 'NT' | 'MISERE'
  int contractValue = 0;
  List<Map<String, dynamic>> bidHistory = [];
  List<bool> passedInAuction = [];

  List<String> kitty = [];
  List<String> discardedKitty = [];
  late List<List<String>> hands;
  late List<int> tricksWon;
  late List<int> scores;
  late List<int> teamScores; // [team0 (0&2), team1 (1&3)] in 4p
  List<Map<String, dynamic>> trick = [];
  Map<String, dynamic>? lastTrick;
  Map<String, dynamic>? lastHandSummary;
  int trickNumber = 1;

  bool _over = false;
  List<int>? _placings;

  FiveHundredGame(super.setup) {
    totalRounds = setup.opt<int>('rounds', 3);
    hands = List.generate(players, (_) => <String>[]);
    tricksWon = List.filled(players, 0);
    scores = List.filled(players, 0);
    teamScores = [0, 0];
    passedInAuction = List.filled(players, false);
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
    final winners = players == 4
        ? [for (var i = 0; i < players; i++) if (i % 2 != seat % 2) i]
        : [for (var i = 0; i < players; i++) if (i != seat) i];
    _placings = rankWinners(players, winners);
    host.log('${name(seat)} 认输');
  }

  @override
  void start() {
    _startRound();
  }

  void _startRound() {
    final deck = shuffled(buildFiveHundredDeck(players), rng);
    for (var s = 0; s < players; s++) {
      hands[s] = deck.sublist(s * 10, (s + 1) * 10);
    }
    kitty = deck.sublist(players * 10, players * 10 + 3);
    discardedKitty = [];

    forehand = (dealer + 1) % players;
    leader = forehand;
    turn = forehand;
    phase = 'bid';
    declarer = -1;
    contractTricks = 6;
    contractStrain = 'S';
    contractValue = 0;
    bidHistory = [];
    passedInAuction = List.filled(players, false);
    tricksWon = List.filled(players, 0);
    trick = [];
    trickNumber = 1;

    for (var s = 0; s < players; s++) {
      _sortHand(hands[s], 'NT');
    }
    host.log('第 $round/$totalRounds 局开始：底牌 (Kitty) 3 张已备好，由 ${name(forehand)} 先叫牌');
  }

  void _sortHand(List<String> hand, String strain) {
    hand.sort((a, b) {
      final sa = fiveHundredEffectiveSuit(a, strain);
      final sb = fiveHundredEffectiveSuit(b, strain);
      final ta = sa == strain || a == 'JK';
      final tb = sb == strain || b == 'JK';
      if (ta != tb) return ta ? -1 : 1;
      if (ta && tb) {
        return fiveHundredCardStrength(b, strain, strain)
            .compareTo(fiveHundredCardStrength(a, strain, strain));
      }
      final ia = fiveHundredSuits.indexOf(sa);
      final ib = fiveHundredSuits.indexOf(sb);
      if (ia != ib) return ia.compareTo(ib);
      return fiveHundredBaseRankOrder(fiveHundredCardRank(b))
          .compareTo(fiveHundredBaseRankOrder(fiveHundredCardRank(a)));
    });
  }

  void _advanceBidder() {
    final activeSeats = [
      for (var s = 0; s < players; s++)
        if (!passedInAuction[s]) s,
    ];
    if (declarer >= 0 && activeSeats.length <= 1) {
      _enterKittyPhase();
      return;
    }
    if (activeSeats.isEmpty) {
      // Everyone passed without bidding -> default Forehand 6S (40 pts)
      declarer = forehand;
      contractTricks = 6;
      contractStrain = 'S';
      contractValue = 40;
      host.log('全员不叫，由先手 ${name(forehand)} 默认执行 6♠ (40分) 定约');
      _enterKittyPhase();
      return;
    }

    for (var offset = 1; offset <= players; offset++) {
      final next = (turn + offset) % players;
      if (!passedInAuction[next]) {
        turn = next;
        return;
      }
    }
  }

  void _enterKittyPhase() {
    phase = 'kitty';
    turn = declarer;
    hands[declarer].addAll(kitty);
    _sortHand(hands[declarer], contractStrain);
    final label = contractStrain == 'MISERE'
        ? 'Misère 零墩定约 (250分)'
        : '$contractTricks${fiveHundredStrainNames[contractStrain]?.split(" ").first ?? contractStrain} ($contractValue分)';
    host.log('${name(declarer)} 赢得定约 [$label]，收起 3 张底牌 (Kitty)，请弃置 3 张手牌');
  }

  /// Legal cards for [seat] in `'play'` phase:
  /// - Leading (`trick.isEmpty`): any card in hand.
  /// - Following (`trick.isNotEmpty`): must follow `leadSuit` (`fiveHundredEffectiveSuit(leadCard, contractStrain)`)
  ///   if holding any card of `leadSuit` (unless `'JK'` was led in `'NT'`/`'MISERE'`, which has `'JK'` suit).
  List<String> legalCards(int seat) {
    final hand = hands[seat];
    if (trick.isEmpty) return List<String>.of(hand);

    final leadCard = asStr(trick.first['card']);
    final leadSuit = fiveHundredEffectiveSuit(leadCard, contractStrain);
    if (leadSuit == 'JK') return List<String>.of(hand);

    final matching = hand
        .where((c) => fiveHundredEffectiveSuit(c, contractStrain) == leadSuit)
        .toList();
    if (matching.isNotEmpty) return matching;
    return List<String>.of(hand);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);

    if (phase == 'bid') {
      if (type == 'pass') {
        passedInAuction[seat] = true;
        bidHistory.add({'seat': seat, 'type': 'pass', 'label': 'Pass'});
        host.log('${name(seat)} 选择不叫 (Pass)');
        _advanceBidder();
        return;
      }

      if (type == 'misere' ||
          (type == 'bid' &&
              (asStr(action['bid']).toUpperCase() == 'MISERE' ||
                  asStr(action['strain']).toUpperCase() == 'MISERE'))) {
        const val = 250;
        if (val <= contractValue) {
          throw GameError('叫牌分值 (250分) 必须高于当前最高叫牌 ($contractValue分)');
        }
        declarer = seat;
        contractTricks = 0;
        contractStrain = 'MISERE';
        contractValue = val;
        bidHistory.add({
          'seat': seat,
          'type': 'misere',
          'tricks': 0,
          'strain': 'MISERE',
          'value': val,
          'label': 'Misère (250分)',
        });
        host.log('${name(seat)} 叫出 Misère 零墩无将 (250分)！');
        _advanceBidder();
        return;
      }

      if (type == 'bid') {
        int tricks = asInt(action['tricks'], 0);
        String strain = asStr(action['strain']).toUpperCase();
        final shorthand = asStr(action['bid']).toUpperCase();
        if (shorthand.isNotEmpty && shorthand != 'MISERE' && shorthand.length >= 2) {
          tricks = int.tryParse(shorthand[0]) ?? tricks;
          strain = shorthand.substring(1);
        }
        final val = fiveHundredBidValue(tricks, strain);
        if (val <= 0) {
          throw GameError('无效叫牌（支持 6~8 墩 S/C/D/H/NT 或 Misère）');
        }
        if (val <= contractValue) {
          throw GameError('新叫牌 ($val分) 必须高于当前最高叫牌 ($contractValue分)');
        }
        declarer = seat;
        contractTricks = tricks;
        contractStrain = strain;
        contractValue = val;
        bidHistory.add({
          'seat': seat,
          'type': 'bid',
          'tricks': tricks,
          'strain': strain,
          'value': val,
          'label': '$tricks$strain ($val分)',
        });
        host.log('${name(seat)} 叫牌 $tricks$strain ($val分)');
        _advanceBidder();
        return;
      }

      throw GameError('请叫牌 (bid / misere) 或选择不叫 (pass)');
    }

    if (phase == 'kitty') {
      if (type != 'discard') throw GameError('请弃置 3 张底牌');
      final rawCards = action['cards'];
      final toDiscard = rawCards is List
          ? [for (final e in rawCards) '$e']
          : <String>[];
      if (toDiscard.length != 3 || toDiscard.toSet().length != 3) {
        throw GameError('必须选择 3 张不同的手牌进行弃置');
      }
      for (final c in toDiscard) {
        if (!hands[seat].contains(c)) {
          throw GameError('手牌中没有 $c');
        }
      }
      for (final c in toDiscard) {
        hands[seat].remove(c);
      }
      discardedKitty = toDiscard;
      for (var s = 0; s < players; s++) {
        _sortHand(hands[s], contractStrain);
      }
      phase = 'play';
      leader = declarer;
      turn = declarer;
      host.log('${name(seat)} 完成换底，开始 10 墩出牌（由庄家 ${name(declarer)} 首攻）！');
      return;
    }

    if (phase == 'play') {
      if (type != 'play') throw GameError('请出牌');
      final card = asStr(action['card']);
      if (!hands[seat].contains(card)) {
        throw GameError('手牌中没有该张牌');
      }
      final legal = legalCards(seat);
      if (!legal.contains(card)) {
        throw GameError('必须跟出领出花色（注意：正副 J 和大王在有将定约中均属于主牌花色！）');
      }

      hands[seat].remove(card);
      trick.add({
        'seat': seat,
        'card': card,
        'effectiveSuit': fiveHundredEffectiveSuit(card, contractStrain),
      });

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
    final winner = fiveHundredTrickWinner(trick, contractStrain);
    tricksWon[winner] += 1;

    lastTrick = {
      'trickNumber': trickNumber,
      'winner': winner,
      'cards': [for (final e in trick) Map<String, dynamic>.of(e)],
    };

    trick = [];
    leader = winner;
    turn = winner;
    trickNumber += 1;

    if (trickNumber > 10 || hands.any((h) => h.isEmpty)) {
      resolveRound();
    }
  }

  void resolveRound() {
    final scoreDeltas = List<int>.filled(players, 0);
    bool contractMade;
    int declarerTricks;

    if (players == 4) {
      final declTeam = declarer % 2;
      final defTeam = 1 - declTeam;
      final partner = (declarer + 2) % 4;
      declarerTricks = tricksWon[declarer] + tricksWon[partner];
      final defenderTricks = 10 - declarerTricks;

      if (contractStrain == 'MISERE') {
        contractMade = tricksWon[declarer] == 0;
      } else {
        contractMade = declarerTricks >= contractTricks;
      }

      final declDelta = contractMade ? contractValue : -contractValue;
      final defDelta = defenderTricks * 10;
      teamScores[declTeam] += declDelta;
      teamScores[defTeam] += defDelta;
      for (var s = 0; s < 4; s++) {
        scoreDeltas[s] = (s % 2 == declTeam) ? declDelta : defDelta;
        scores[s] = teamScores[s % 2];
      }
    } else {
      // 3-player individual mode
      declarerTricks = tricksWon[declarer];
      if (contractStrain == 'MISERE') {
        contractMade = declarerTricks == 0;
      } else {
        contractMade = declarerTricks >= contractTricks;
      }
      final declDelta = contractMade ? contractValue : -contractValue;
      scoreDeltas[declarer] = declDelta;
      scores[declarer] += declDelta;
      for (var s = 0; s < players; s++) {
        if (s != declarer) {
          final defDelta = tricksWon[s] * 10;
          scoreDeltas[s] = defDelta;
          scores[s] += defDelta;
        }
      }
    }

    lastHandSummary = {
      'round': round,
      'declarer': declarer,
      'contractTricks': contractTricks,
      'contractStrain': contractStrain,
      'contractValue': contractValue,
      'contractMade': contractMade,
      'declarerTricks': declarerTricks,
      'tricksWon': List<int>.of(tricksWon),
      'scoreDeltas': scoreDeltas,
    };

    host.log('第 $round 局结算：庄家 ${name(declarer)} '
        '${contractMade ? "完成定约 +$contractValue 分" : "宕牌 -$contractValue 分"}');

    final reached500 = scores.any((sc) => sc >= 500 || sc <= -500);
    if (round >= totalRounds || reached500) {
      _over = true;
      _placings = rankByScore(scores);
      host.log('比赛结束！');
    } else {
      round += 1;
      dealer = (dealer + 1) % players;
      _startRound();
    }
  }

  int _evalSuitStrength(List<String> hand, String suit) {
    var pts = 0;
    for (final c in hand) {
      if (c == 'JK') {
        pts += 12;
      } else if (c == 'J$suit') {
        pts += 10;
      } else if (c == 'J${fiveHundredSameColorSuit(suit)}') {
        pts += 8;
      } else if (fiveHundredCardSuit(c) == suit) {
        final r = fiveHundredCardRank(c);
        pts += (r == 'A' || r == 'K' || r == 'Q') ? 5 : 3;
      } else if (fiveHundredCardRank(c) == 'A') {
        pts += 3;
      }
    }
    return pts;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    final hand = hands[seat];

    if (phase == 'bid') {
      var bestSuit = 'S';
      var bestScore = -1;
      for (final s in fiveHundredSuits) {
        final sc = _evalSuitStrength(hand, s);
        if (sc > bestScore) {
          bestScore = sc;
          bestSuit = s;
        }
      }

      if (bestScore >= 24) {
        final maxTricks = bestScore >= 36 ? 7 : 6;
        for (var t = 6; t <= maxTricks; t++) {
          final v = fiveHundredBidValue(t, bestSuit);
          if (v > contractValue) {
            return {'type': 'bid', 'tricks': t, 'strain': bestSuit};
          }
        }
      }
      return {'type': 'pass'};
    }

    if (phase == 'kitty') {
      // Discard 3 weakest cards
      final sortedAsc = List<String>.of(hand)
        ..sort((a, b) => fiveHundredCardStrength(a, contractStrain, contractStrain)
            .compareTo(fiveHundredCardStrength(b, contractStrain, contractStrain)));
      if (contractStrain == 'MISERE') {
        // In Misère, discard the 3 HIGHEST cards!
        return {'type': 'discard', 'cards': sortedAsc.reversed.take(3).toList()};
      }
      return {'type': 'discard', 'cards': sortedAsc.take(3).toList()};
    }

    if (phase == 'play') {
      final legal = legalCards(seat);
      if (legal.isEmpty) return null;
      if (botLevel == 0) {
        return {'type': 'play', 'card': legal[rng.nextInt(legal.length)]};
      }

      final leadSuit = trick.isEmpty
          ? contractStrain
          : fiveHundredEffectiveSuit(asStr(trick.first['card']), contractStrain);
      final sortedAsc = List<String>.of(legal)
        ..sort((a, b) => fiveHundredCardStrength(a, contractStrain, leadSuit)
            .compareTo(fiveHundredCardStrength(b, contractStrain, leadSuit)));

      if (contractStrain == 'MISERE' && seat == declarer) {
        return {'type': 'play', 'card': sortedAsc.first};
      }

      if (trick.isEmpty) {
        return {'type': 'play', 'card': sortedAsc.last};
      }

      final curWinner = fiveHundredTrickWinner(trick, contractStrain);
      if (players == 4 && (curWinner % 2) == (seat % 2)) {
        return {'type': 'play', 'card': sortedAsc.first};
      }

      final curBestStr = fiveHundredCardStrength(
        asStr(trick.firstWhere((e) => e['seat'] == curWinner)['card']),
        contractStrain,
        leadSuit,
      );
      final winners = sortedAsc
          .where((c) => fiveHundredCardStrength(c, contractStrain, leadSuit) > curBestStr)
          .toList();
      if (winners.isNotEmpty) {
        return {'type': 'play', 'card': winners.first};
      }
      return {'type': 'play', 'card': sortedAsc.first};
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
      'declarer': declarer,
      'contractTricks': contractTricks,
      'contractStrain': contractStrain,
      'contractStrainName': fiveHundredStrainNames[contractStrain] ?? contractStrain,
      'contractValue': contractValue,
      'bidHistory': [for (final b in bidHistory) Map<String, dynamic>.of(b)],
      'kittyCount': phase == 'bid' ? kitty.length : 0,
      'trickNumber': trickNumber,
      'tricksWon': List<int>.of(tricksWon),
      'scores': List<int>.of(scores),
      'teamScores': List<int>.of(teamScores),
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
