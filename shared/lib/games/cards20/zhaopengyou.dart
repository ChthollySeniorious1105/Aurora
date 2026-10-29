import '../../src/engine.dart';

const List<String> zpySuits = ['S', 'H', 'D', 'C'];
const Map<String, String> zpySuitNames = {
  'S': '♠黑桃',
  'H': '♥红桃',
  'D': '♦方块',
  'C': '♣梅花',
};
const List<String> zpyRanks = [
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  'T',
  'J',
  'Q',
  'K',
  'A',
];
const List<int> zpyValidBids = [60, 70, 80, 90, 100];

/// Builds standard 54-card deck (52 suited cards + `'BJ'` + `'RJ'`).
List<String> buildZhaopengyouDeck() => [
      for (final s in zpySuits)
        for (final r in zpyRanks) '$r$s',
      'BJ',
      'RJ',
    ];

String zpyCardRank(String card) =>
    (card == 'BJ' || card == 'RJ') ? card : card.substring(0, 1);

String zpyCardSuit(String card) =>
    (card == 'BJ' || card == 'RJ') ? 'J' : card.substring(1, 2);

/// Returns point value of [card]: `5` = 5 pts, `T` = 10 pts, `K` = 10 pts, else `0`.
int zpyCardPoints(String card) {
  if (card == 'BJ' || card == 'RJ') return 0;
  final r = zpyCardRank(card);
  if (r == '5') return 5;
  if (r == 'T' || r == 'K') return 10;
  return 0;
}

/// Effective suit category for trick following: `'T'` (Trump) if Joker or `suit == trumpSuit`, else `suit`.
String zpyEffectiveSuit(String card, String trumpSuit) {
  if (card == 'BJ' || card == 'RJ') return 'T';
  final s = zpyCardSuit(card);
  return s == trumpSuit ? 'T' : s;
}

bool zpyIsTrump(String card, String trumpSuit) =>
    zpyEffectiveSuit(card, trumpSuit) == 'T';

/// Base rank strength within a suit: `2(2) .. A(14)`.
int zpyBaseRankStrength(String card) {
  if (card == 'RJ') return 100;
  if (card == 'BJ') return 90;
  final idx = zpyRanks.indexOf(zpyCardRank(card));
  return idx < 0 ? 0 : idx + 2;
}

/// Strength of [card] in a trick with [ledCategory] (`'T'` or `'S'/'H'/'D'/'C'`) and [trumpSuit].
int zpyTrickCardStrength(
  String card, {
  required String ledCategory,
  required String trumpSuit,
}) {
  if (card == 'RJ') return 200;
  if (card == 'BJ') return 190;
  final cat = zpyEffectiveSuit(card, trumpSuit);
  final base = zpyBaseRankStrength(card);
  if (cat == 'T') {
    return 100 + base;
  }
  if (cat == ledCategory) {
    return base;
  }
  return 0; // off-suit non-trump cannot win trick
}

/// Candidate friend cards that the declarer can call (typically Aces or Kings).
const List<String> kZpyCandidateFriends = [
  'AS',
  'AH',
  'AD',
  'AC',
  'KS',
  'KH',
  'KD',
  'KC',
  'QS',
  'QH',
  'QD',
  'QC',
];

class ZhaopengyouGame extends GameEngine {
  late int totalRounds;
  int round = 1;
  int startPlayer = 0;
  int turn = 0;

  /// Current phase:
  /// - `'bid'`: Players bid `60, 70, 80, 90, 100` or `pass`
  /// - `'setup_declarers'`: Declarer buries 6 kitty cards (`bury`), picks `trumpSuit` and `friendCard`
  /// - `'play'`: 12 tricks of trick-taking & point capturing
  String phase = 'bid';

  List<String> deck = [];
  List<String> kitty = []; // Initial 6-card kitty before declarer takes it
  List<String> buriedKitty = []; // 6 cards buried by declarer
  late List<List<String>> hands;
  late List<int> scores;

  // Bidding state
  int currentBid = 0;
  int highestBidder = -1;
  Set<int> passedSeats = {};
  Map<int, String> bidHistory = {};

  // Declarer & secret friend state
  int declarer = 0;
  int contract = 60;
  String trumpSuit = 'S';
  String friendCard = 'AS';
  int friendSeat = 0; // Secret until friendCard is played!
  bool friendRevealed = false;

  // Trick-taking state
  int trickNumber = 1;
  int leader = 0;
  List<Map<String, dynamic>> currentTrick = [];
  List<Map<String, dynamic>> lastTrick = [];
  late List<int> capturedPoints;
  late List<int> tricksWon;

  List<String> actionLog = [];
  Map<String, dynamic>? lastRoundSummary;

  bool _over = false;
  List<int>? _placings;

  ZhaopengyouGame(super.setup) {
    totalRounds = setup.opt<int>('rounds', 2);
    hands = List.generate(players, (_) => <String>[]);
    scores = List.filled(players, 0);
    capturedPoints = List.filled(players, 0);
    tricksWon = List.filled(players, 0);
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
    final winners = [
      for (var i = 0; i < players; i++)
        if (i != seat) i,
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
      final ca = zpyEffectiveSuit(a, trumpSuit);
      final cb = zpyEffectiveSuit(b, trumpSuit);
      if (ca != cb) {
        if (ca == 'T') return -1;
        if (cb == 'T') return 1;
        return zpySuits.indexOf(ca).compareTo(zpySuits.indexOf(cb));
      }
      return zpyBaseRankStrength(b).compareTo(zpyBaseRankStrength(a));
    });
  }

  void _startRound() {
    deck = shuffled(buildZhaopengyouDeck(), rng);
    trumpSuit = 'S';
    for (var s = 0; s < players; s++) {
      hands[s] = [for (var i = 0; i < 12; i++) deck.removeLast()];
      _sortHand(hands[s]);
      capturedPoints[s] = 0;
      tricksWon[s] = 0;
    }
    kitty = [for (var i = 0; i < 6; i++) deck.removeLast()];
    buriedKitty = [];

    currentBid = 0;
    highestBidder = -1;
    passedSeats = {};
    bidHistory = {};

    declarer = startPlayer;
    contract = 60;
    friendCard = 'AS';
    friendSeat = startPlayer;
    friendRevealed = false;

    trickNumber = 1;
    leader = startPlayer;
    currentTrick = [];
    lastTrick = [];
    actionLog = [];
    phase = 'bid';
    turn = startPlayer;

    host.log('第 $round/$totalRounds 局开始：每人 12 张牌，底牌 6 张，开始叫分（60~100分）！');
  }

  void _enterSetupDeclarers(int winningSeat, int winningBid) {
    declarer = winningSeat;
    contract = winningBid;
    hands[declarer].addAll(kitty);
    _sortHand(hands[declarer]);
    phase = 'setup_declarers';
    turn = declarer;
    actionLog.add(
      '👑 ${name(declarer)} 以 $contract 分成为庄家，拿起 6 张底牌（现手持 ${hands[declarer].length} 张）',
    );
    host.log('${name(declarer)} 以 $contract 分坐庄，请埋底 6 张、定主花色并叫一张朋友牌');
  }

  int _locateFriendSeat(String fCard) {
    for (var s = 0; s < players; s++) {
      if (hands[s].contains(fCard)) return s;
    }
    return declarer; // In buriedKitty or held by declarer -> 1v3 solo!
  }

  List<String> legalCards(int seat) {
    final hand = hands[seat];
    if (hand.isEmpty) return const [];
    if (currentTrick.isEmpty) return List<String>.of(hand);
    final ledCard = asStr(currentTrick.first['card']);
    final ledCat = zpyEffectiveSuit(ledCard, trumpSuit);
    final sameCat = hand
        .where((c) => zpyEffectiveSuit(c, trumpSuit) == ledCat)
        .toList();
    return sameCat.isNotEmpty ? sameCat : List<String>.of(hand);
  }

  bool isDeclarerTeam(int seat) => seat == declarer || seat == friendSeat;

  int get declarerTeamPoints {
    var sum = 0;
    for (var s = 0; s < players; s++) {
      if (isDeclarerTeam(s)) sum += capturedPoints[s];
    }
    return sum;
  }

  int get defenderTeamPoints {
    var sum = 0;
    for (var s = 0; s < players; s++) {
      if (!isDeclarerTeam(s)) sum += capturedPoints[s];
    }
    return sum;
  }

  int get defenderTarget => 105 - contract;

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);

    if (phase == 'bid') {
      if (type == 'bid') {
        final bidVal = asInt(action['score'], asInt(action['bid'], 0));
        if (!zpyValidBids.contains(bidVal) || bidVal <= currentBid) {
          throw GameError('叫分必须为 60/70/80/90/100 且高于当前最高分 ($currentBid)');
        }
        currentBid = bidVal;
        highestBidder = seat;
        bidHistory[seat] = '$bidVal分';
        actionLog.add('${name(seat)} 叫分：$bidVal 分');

        if (bidVal == 100 || passedSeats.length >= players - 1) {
          _enterSetupDeclarers(highestBidder, currentBid);
          return;
        }
        _advanceBiddingTurn();
        return;
      }

      if (type == 'pass') {
        passedSeats.add(seat);
        bidHistory[seat] = '不叫';
        actionLog.add('${name(seat)} 选择不叫');

        if (highestBidder >= 0 && passedSeats.length >= players - 1) {
          _enterSetupDeclarers(highestBidder, currentBid);
          return;
        }
        if (passedSeats.length >= players) {
          // All 4 passed -> startPlayer forced at 60
          _enterSetupDeclarers(startPlayer, 60);
          return;
        }
        _advanceBiddingTurn();
        return;
      }

      throw GameError('叫分阶段请叫分 (bid) 或不叫 (pass)');
    }

    if (phase == 'setup_declarers') {
      if (type != 'bury' &&
          type != 'setup_declarers' &&
          type != 'declare' &&
          type != 'call_friend') {
        throw GameError('请完成庄家埋底与定主找朋友 (bury / setup_declarers)');
      }

      if (action['cards'] is List && buriedKitty.isEmpty) {
        final toBury = (action['cards'] as List).map((e) => '$e').toList();
        if (toBury.length != 6) {
          throw GameError('必须选择恰好 6 张牌埋入底牌');
        }
        final copy = List<String>.of(hands[seat]);
        for (final c in toBury) {
          if (!copy.remove(c)) {
            throw GameError('手牌中没有卡牌 $c');
          }
        }
        hands[seat] = copy;
        buriedKitty = toBury;
      }

      final suitArg = asStr(action['trumpSuit']);
      if (suitArg.isNotEmpty) {
        if (!zpySuits.contains(suitArg)) {
          throw GameError('无效的主花色：$suitArg（需为 S/H/D/C）');
        }
        trumpSuit = suitArg;
      }

      final friendArg = asStr(action['friendCard']);
      if (friendArg.isNotEmpty) {
        if (friendArg == 'BJ' || friendArg == 'RJ' || friendArg.length != 2) {
          throw GameError('朋友牌必须为标准花色点牌（如 AS, AH, AD, AC, KS）');
        }
        friendCard = friendArg;
      }

      // If cards were buried and either trumpSuit/friendCard were provided (or defaults used when type != 'bury_only')
      if (buriedKitty.length == 6 &&
          (suitArg.isNotEmpty ||
              friendArg.isNotEmpty ||
              type == 'setup_declarers')) {
        for (var s = 0; s < players; s++) {
          _sortHand(hands[s]);
        }
        friendSeat = _locateFriendSeat(friendCard);
        friendRevealed = false;
        phase = 'play';
        trickNumber = 1;
        leader = declarer;
        turn = declarer;
        actionLog.add(
          '🎯 庄家 ${name(declarer)} 埋好 6 张底牌，定主【${zpySuitNames[trumpSuit]}】，呼叫朋友牌【$friendCard】！',
        );
        host.log(
          '庄家 ${name(declarer)} 定主【${zpySuitNames[trumpSuit]}】，找朋友牌【$friendCard】！第一墩由庄家领出',
        );
        return;
      }

      return;
    }

    if (phase == 'play') {
      if (type != 'play') throw GameError('当前请出牌 (play)');
      final card = asStr(action['card']);
      final legal = legalCards(seat);
      if (!legal.contains(card)) {
        throw GameError('必须跟随领出花色/主牌类别出牌');
      }

      hands[seat].remove(card);
      currentTrick.add({'seat': seat, 'card': card});

      // Check if friendCard was just played -> publicly reveal partner identity!
      if (card == friendCard && !friendRevealed) {
        friendRevealed = true;
        friendSeat = seat;
        if (seat == declarer) {
          actionLog.add(
            '🔥 庄家 ${name(declarer)} 自己打出了朋友牌【$friendCard】——本局为庄家 1打3 独打！',
          );
          host.log('🔥 朋友牌【$friendCard】由庄家自己打出！庄家 1v3 独打！');
        } else {
          actionLog.add(
            '🤝 ${name(seat)} 打出了朋友牌【$friendCard】，公开亮明庄家伙伴身份！',
          );
          host.log('🤝 ${name(seat)} 打出【$friendCard】，亮明身份为庄家 ${name(declarer)} 的暗伙伴！');
        }
      }

      if (currentTrick.length < players) {
        turn = (turn + 1) % players;
        return;
      }

      _resolveTrick();
      return;
    }

    throw GameError('未知阶段：$phase');
  }

  void _advanceBiddingTurn() {
    for (var off = 1; off <= players; off++) {
      final next = (turn + off) % players;
      if (!passedSeats.contains(next)) {
        turn = next;
        return;
      }
    }
  }

  void _resolveTrick() {
    final ledCard = asStr(currentTrick.first['card']);
    final ledCat = zpyEffectiveSuit(ledCard, trumpSuit);

    var winner = asInt(currentTrick.first['seat']);
    var bestStrength = -1;
    var trickPts = 0;

    for (final entry in currentTrick) {
      final s = asInt(entry['seat']);
      final c = asStr(entry['card']);
      trickPts += zpyCardPoints(c);
      final str = zpyTrickCardStrength(
        c,
        ledCategory: ledCat,
        trumpSuit: trumpSuit,
      );
      if (str > bestStrength) {
        bestStrength = str;
        winner = s;
      }
    }

    tricksWon[winner] += 1;
    capturedPoints[winner] += trickPts;
    lastTrick = List<Map<String, dynamic>>.of(currentTrick);
    currentTrick = [];

    actionLog.add(
      '第 $trickNumber 墩：${name(winner)} 赢墩${trickPts > 0 ? " (+$trickPts分)" : ""}',
    );

    if (trickNumber >= 12 || hands.every((h) => h.isEmpty)) {
      // Last trick winner captures buriedKitty points × 2 (抠底)!
      final kittyBasePts = buriedKitty.fold<int>(
        0,
        (sum, c) => sum + zpyCardPoints(c),
      );
      final kittyBonus = kittyBasePts * 2;
      if (kittyBonus > 0) {
        capturedPoints[winner] += kittyBonus;
        actionLog.add(
          '💎 末墩抠底！${name(winner)} 赢得第 12 墩，底牌 $kittyBasePts 分翻倍获得 +$kittyBonus 分！',
        );
      }
      _finishRound(lastTrickWinner: winner, kittyBonus: kittyBonus);
      return;
    }

    trickNumber += 1;
    leader = winner;
    turn = winner;
  }

  void _finishRound({
    required int lastTrickWinner,
    required int kittyBonus,
  }) {
    friendRevealed = true;
    final declPts = declarerTeamPoints;
    final defPts = defenderTeamPoints;
    // Defenders win if their captured points >= 105 - contract (or declarerTeamPoints < contract)
    final defendersWin = defPts >= defenderTarget || declPts < contract;
    final declWins = !defendersWin;

    final solo = friendSeat == declarer;
    final delta = List<int>.filled(players, 0);
    final stake = (contract - 50) ~/ 10; // 1..5 points per round stake

    for (var s = 0; s < players; s++) {
      if (isDeclarerTeam(s)) {
        if (solo) {
          delta[s] = declWins ? stake * 3 : -stake * 3;
        } else {
          delta[s] = declWins ? stake * 2 : -stake * 2;
        }
      } else {
        delta[s] = defendersWin ? stake * 2 : -stake * 2;
      }
      scores[s] += delta[s];
    }

    lastRoundSummary = {
      'round': round,
      'declarer': declarer,
      'friendSeat': friendSeat,
      'friendCard': friendCard,
      'trumpSuit': trumpSuit,
      'contract': contract,
      'defenderTarget': defenderTarget,
      'declarerTeamPoints': declPts,
      'defenderTeamPoints': defPts,
      'kittyBonus': kittyBonus,
      'lastTrickWinner': lastTrickWinner,
      'declarerWon': declWins,
      'delta': delta,
      'scores': List<int>.of(scores),
    };

    host.log(
      '第 $round 局结算：庄家方 $declPts 分 vs 闲家方 $defPts 分（闲家目标 $defenderTarget 分）→ '
      '${declWins ? "庄家方获胜！" : "闲家方破庄获胜！"}',
    );

    if (round >= totalRounds) {
      _over = true;
      _placings = rankByScore(scores);
      host.log('找朋友比赛结束！');
    } else {
      round += 1;
      startPlayer = (startPlayer + 1) % players;
      _startRound();
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    if (phase == 'bid') {
      // Evaluate hand strength (jokers + aces + 2s)
      final hand = hands[seat];
      var highStrength = 0;
      for (final c in hand) {
        if (c == 'RJ') highStrength += 25;
        if (c == 'BJ') highStrength += 18;
        final r = zpyCardRank(c);
        if (r == 'A') highStrength += 10;
        if (r == 'K') highStrength += 6;
      }
      final maxWilling = (50 + (highStrength ~/ 15) * 10).clamp(60, 90);
      final nextBid = currentBid == 0 ? 60 : currentBid + 10;
      if (nextBid <= maxWilling && zpyValidBids.contains(nextBid)) {
        return {'type': 'bid', 'score': nextBid};
      }
      return {'type': 'pass'};
    }

    if (phase == 'setup_declarers') {
      // Choose most frequent suit in hand as trumpSuit
      final suitCounts = {for (final s in zpySuits) s: 0};
      for (final c in hands[seat]) {
        final s = zpyCardSuit(c);
        if (suitCounts.containsKey(s)) {
          suitCounts[s] = suitCounts[s]! + 1;
        }
      }
      final bestTrump = zpySuits.reduce(
        (a, b) => suitCounts[a]! >= suitCounts[b]! ? a : b,
      );

      // Pick a friend card (prefer an Ace not in declarer's hand!)
      var chosenFriend = 'AS';
      for (final cand in kZpyCandidateFriends) {
        if (!hands[seat].contains(cand)) {
          chosenFriend = cand;
          break;
        }
      }

      // Bury 6 lowest non-trump cards
      final sorted = List<String>.of(hands[seat])
        ..sort((a, b) {
          final ta = zpyIsTrump(a, bestTrump) ? 1 : 0;
          final tb = zpyIsTrump(b, bestTrump) ? 1 : 0;
          if (ta != tb) return ta.compareTo(tb);
          return zpyBaseRankStrength(a).compareTo(zpyBaseRankStrength(b));
        });
      final buryCards = sorted.take(6).toList();
      return {
        'type': 'bury',
        'cards': buryCards,
        'trumpSuit': bestTrump,
        'friendCard': chosenFriend,
      };
    }

    if (phase == 'play') {
      final legal = legalCards(seat);
      if (legal.isEmpty) return null;
      if (botLevel == 0 || legal.length == 1) {
        return {'type': 'play', 'card': legal.first};
      }

      // If leading, play high non-point card or high trump
      if (currentTrick.isEmpty) {
        final sorted = List<String>.of(legal)
          ..sort(
            (a, b) => zpyBaseRankStrength(b).compareTo(zpyBaseRankStrength(a)),
          );
        return {'type': 'play', 'card': sorted.first};
      }

      // Following: try to win if trick contains points, else slough low non-point card
      final ledCard = asStr(currentTrick.first['card']);
      final ledCat = zpyEffectiveSuit(ledCard, trumpSuit);
      var curBest = -1;
      var trickPts = 0;
      for (final e in currentTrick) {
        final c = asStr(e['card']);
        trickPts += zpyCardPoints(c);
        final str = zpyTrickCardStrength(
          c,
          ledCategory: ledCat,
          trumpSuit: trumpSuit,
        );
        if (str > curBest) curBest = str;
      }

      final winners = legal
          .where(
            (c) =>
                zpyTrickCardStrength(
                  c,
                  ledCategory: ledCat,
                  trumpSuit: trumpSuit,
                ) >
                curBest,
          )
          .toList();

      if (winners.isNotEmpty && trickPts >= 10) {
        winners.sort(
          (a, b) => zpyTrickCardStrength(
            a,
            ledCategory: ledCat,
            trumpSuit: trumpSuit,
          ).compareTo(
            zpyTrickCardStrength(
              b,
              ledCategory: ledCat,
              trumpSuit: trumpSuit,
            ),
          ),
        );
        return {'type': 'play', 'card': winners.first};
      }

      final dump = List<String>.of(legal)
        ..sort((a, b) {
          final pa = zpyCardPoints(a);
          final pb = zpyCardPoints(b);
          if (pa != pb) return pa.compareTo(pb);
          return zpyBaseRankStrength(a).compareTo(zpyBaseRankStrength(b));
        });
      return {'type': 'play', 'card': dump.first};
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final hasSeat = seat >= 0 && seat < players;
    final myHand = hasSeat ? List<String>.of(hands[seat]) : <String>[];
    final myLegal = (hasSeat && seat == turn && phase == 'play')
        ? legalCards(seat)
        : const <String>[];

    return {
      'round': round,
      'totalRounds': totalRounds,
      'phase': phase,
      'turn': turn,
      'scores': List<int>.of(scores),
      'handCounts': [for (final h in hands) h.length],
      'hand': myHand,
      'legalCards': myLegal,
      'currentBid': currentBid,
      'highestBidder': highestBidder,
      'bidHistory': {for (final e in bidHistory.entries) '${e.key}': e.value},
      'declarer': declarer,
      'contract': contract,
      'defenderTarget': defenderTarget,
      'trumpSuit': trumpSuit,
      'friendCard': friendCard,
      'friendRevealed': friendRevealed,
      'revealedFriendSeat': friendRevealed ? friendSeat : null,
      'amSecretFriend': hasSeat && seat == friendSeat,
      'trickNumber': trickNumber,
      'leader': leader,
      'currentTrick': [
        for (final e in currentTrick) Map<String, dynamic>.of(e),
      ],
      'lastTrick': [
        for (final e in lastTrick) Map<String, dynamic>.of(e),
      ],
      'capturedPoints': List<int>.of(capturedPoints),
      'tricksWon': List<int>.of(tricksWon),
      'buriedKittyCount': buriedKitty.length,
      'actionLog': List<String>.of(actionLog.reversed.take(6)),
      'lastRoundSummary': lastRoundSummary,
      'over': _over,
      'placings': _placings,
    };
  }
}
