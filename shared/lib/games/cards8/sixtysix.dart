import '../../src/engine.dart';

const List<String> sixtySixSuits = ['S', 'H', 'D', 'C'];
const List<String> sixtySixRanks = ['A', 'T', 'K', 'Q', 'J'];

const Map<String, int> sixtySixCardValues = {
  'A': 11,
  'T': 10,
  'K': 4,
  'Q': 3,
  'J': 2,
};

const Map<String, int> sixtySixRankPowers = {
  'A': 5,
  'T': 4,
  'K': 3,
  'Q': 2,
  'J': 1,
};

int sixtySixVal(String card) => sixtySixCardValues[card[0]] ?? 0;
int sixtySixPower(String card) => sixtySixRankPowers[card[0]] ?? 0;
String sixtySixRank(String card) => card[0];
String sixtySixSuit(String card) => card[1];

List<String> buildSixtySixDeck() => [
      for (final s in sixtySixSuits)
        for (final r in sixtySixRanks) '$r$s',
    ];

class SixtySixGame extends GameEngine {
  late final int targetPoints;

  List<int> gameScores = [0, 0];
  int handNumber = 0;
  int dealer = 0;
  int leader = 0;
  int turn = 0;

  List<List<String>> hands = [[], []];
  List<String> stock = [];
  String trumpCard = 'AS';
  String trumpSuit = 'S';

  bool closed = false;
  int? closer;
  int opponentPtsAtClose = 0;
  int opponentTricksAtClose = 0;

  String? leadCard;
  int? lastMarriageBonus;

  List<int> cardPoints = [0, 0];
  List<int> marriagePoints = [0, 0];
  List<List<String>> marriages = [[], []];
  List<int> tricksWon = [0, 0];

  Map<String, dynamic>? lastTrick;
  Map<String, dynamic>? lastHandResult;
  Map<String, dynamic>? result;
  bool over = false;
  int? resignedSeat;

  SixtySixGame(super.setup) {
    targetPoints = setup.opt<int>('target', 7);
  }

  int effectivePoints(int s) =>
      tricksWon[s] > 0 ? cardPoints[s] + marriagePoints[s] : 0;

  @override
  void start() {
    dealer = 0;
    _startNewHand();
  }

  void _startNewHand() {
    handNumber++;
    final deck = shuffled(buildSixtySixDeck(), rng);
    hands = [
      deck.sublist(0, 5),
      deck.sublist(5, 10),
    ];
    stock = deck.sublist(10);
    trumpCard = stock.last;
    trumpSuit = sixtySixSuit(trumpCard);
    closed = false;
    closer = null;
    opponentPtsAtClose = 0;
    opponentTricksAtClose = 0;
    leadCard = null;
    lastMarriageBonus = null;
    cardPoints = [0, 0];
    marriagePoints = [0, 0];
    marriages = [[], []];
    tricksWon = [0, 0];
    lastTrick = null;
    leader = 1 - dealer;
    turn = leader;
    _sortHands();
  }

  void _sortHands() {
    for (final h in hands) {
      h.sort((a, b) {
        final sa = sixtySixSuit(a) == trumpSuit
            ? -1
            : sixtySixSuits.indexOf(sixtySixSuit(a));
        final sb = sixtySixSuit(b) == trumpSuit
            ? -1
            : sixtySixSuits.indexOf(sixtySixSuit(b));
        if (sa != sb) return sa.compareTo(sb);
        return sixtySixPower(b).compareTo(sixtySixPower(a));
      });
    }
  }

  bool canSwapTrump(int seat) =>
      !over &&
      seat == turn &&
      leadCard == null &&
      !closed &&
      stock.length >= 2 &&
      hands[seat].contains('J$trumpSuit');

  bool canCloseStock(int seat) =>
      !over &&
      seat == turn &&
      leadCard == null &&
      !closed &&
      stock.length >= 2;

  List<String> legalPlays(int seat) {
    if (over || seat != turn) return const [];
    final h = hands[seat];
    if (leadCard == null) return List<String>.of(h);
    final strict = closed || stock.isEmpty;
    if (!strict) return List<String>.of(h);

    final lSuit = sixtySixSuit(leadCard!);
    final lPow = sixtySixPower(leadCard!);
    final higherSame = h
        .where((c) => sixtySixSuit(c) == lSuit && sixtySixPower(c) > lPow)
        .toList();
    if (higherSame.isNotEmpty) return higherSame;

    final anySame = h.where((c) => sixtySixSuit(c) == lSuit).toList();
    if (anySame.isNotEmpty) return anySame;

    final trumps = h.where((c) => sixtySixSuit(c) == trumpSuit).toList();
    if (trumps.isNotEmpty) return trumps;

    return List<String>.of(h);
  }

  bool canDeclareMarriageWith(int seat, String card) {
    if (leadCard != null) return false;
    final r = sixtySixRank(card);
    final s = sixtySixSuit(card);
    if (r == 'K') return hands[seat].contains('Q$s');
    if (r == 'Q') return hands[seat].contains('K$s');
    return false;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);
    if (type == 'swap_trump') {
      if (!canSwapTrump(seat)) {
        throw GameError('当前不能用王牌J交换底牌');
      }
      final jack = 'J$trumpSuit';
      final idx = hands[seat].indexOf(jack);
      final oldTrump = trumpCard;
      hands[seat][idx] = oldTrump;
      trumpCard = jack;
      stock[stock.length - 1] = jack;
      _sortHands();
      host.log('${name(seat)} 用 $jack 换取了王牌底牌 $oldTrump');
      return;
    }

    if (type == 'close') {
      if (!canCloseStock(seat)) {
        throw GameError('当前不能关闭牌库');
      }
      closed = true;
      closer = seat;
      opponentPtsAtClose = effectivePoints(1 - seat);
      opponentTricksAtClose = tricksWon[1 - seat];
      host.log('${name(seat)} 关闭了牌库！进入严格跟牌阶段');
      return;
    }

    if (type == 'play') {
      final card = asStr(action['card']);
      if (!hands[seat].contains(card)) {
        throw GameError('手牌中没有该张牌');
      }
      if (leadCard == null) {
        // Trick leader plays
        final isMarriage = canDeclareMarriageWith(seat, card);
        hands[seat].remove(card);
        if (isMarriage) {
          final s = sixtySixSuit(card);
          final bonus = s == trumpSuit ? 40 : 20;
          marriagePoints[seat] += bonus;
          marriages[seat].add(s);
          lastMarriageBonus = bonus;
          host.log(
              '${name(seat)} 打出 $card 并宣告${s == trumpSuit ? "王牌" : ""}婚姻 (+$bonus分)');
          if (effectivePoints(seat) >= 66) {
            _finishHandReached66(seat, '宣告婚姻达到 ${effectivePoints(seat)} 分');
            return;
          }
        } else {
          lastMarriageBonus = null;
        }
        leadCard = card;
        leader = seat;
        turn = 1 - seat;
        return;
      } else {
        // Follower plays
        final legals = legalPlays(seat);
        if (!legals.contains(card)) {
          throw GameError('牌库关闭或耗尽时，必须优先大过同花色、跟同花色或出王牌');
        }
        hands[seat].remove(card);
        final lead = leadCard!;
        final int winner;
        if (sixtySixSuit(card) == sixtySixSuit(lead)) {
          winner = sixtySixPower(card) > sixtySixPower(lead) ? seat : leader;
        } else if (sixtySixSuit(card) == trumpSuit) {
          winner = seat;
        } else {
          winner = leader;
        }

        final pts = sixtySixVal(lead) + sixtySixVal(card);
        tricksWon[winner]++;
        cardPoints[winner] += pts;
        lastTrick = {
          'leader': leader,
          'leadCard': lead,
          'follower': seat,
          'followCard': card,
          'winner': winner,
          'points': pts,
        };
        leadCard = null;
        lastMarriageBonus = null;

        if (effectivePoints(winner) >= 66) {
          _finishHandReached66(winner, '赢得本墩后达到 ${effectivePoints(winner)} 分');
          return;
        }

        if (!closed && stock.isNotEmpty) {
          hands[winner].add(stock.removeAt(0));
          if (stock.isNotEmpty) {
            hands[1 - winner].add(stock.removeAt(0));
          }
          _sortHands();
        }

        if (hands[0].isEmpty && hands[1].isEmpty) {
          if (closed && closer != null) {
            final opp = 1 - closer!;
            final gPts = opponentTricksAtClose == 0 ? 3 : 2;
            _awardHandPoints(opp, gPts, '${name(closer!)} 关闭牌库但未能达到66分');
          } else {
            _awardHandPoints(winner, 1, '${name(winner)} 赢得最后一墩');
          }
          return;
        }

        leader = winner;
        turn = winner;
        return;
      }
    }

    throw GameError('未知操作类型: $type');
  }

  void _finishHandReached66(int winner, String reason) {
    final opp = 1 - winner;
    int gPts;
    if (closed && closer == winner) {
      gPts = opponentTricksAtClose == 0
          ? 3
          : (opponentPtsAtClose < 33 ? 2 : 1);
    } else if (closed && closer == opp) {
      gPts = tricksWon[opp] == 0 ? 3 : 2;
    } else {
      gPts = tricksWon[opp] == 0
          ? 3
          : (effectivePoints(opp) < 33 ? 2 : 1);
    }
    _awardHandPoints(winner, gPts, reason);
  }

  void _awardHandPoints(int winner, int gPts, String reason) {
    gameScores[winner] += gPts;
    lastHandResult = {
      'hand': handNumber,
      'winner': winner,
      'gamePoints': gPts,
      'handPoints': [effectivePoints(0), effectivePoints(1)],
      'cardPoints': [cardPoints[0], cardPoints[1]],
      'marriagePoints': [marriagePoints[0], marriagePoints[1]],
      'tricks': [tricksWon[0], tricksWon[1]],
      'reason': reason,
    };
    host.log(
        '第$handNumber局结束：${name(winner)} 获胜（$reason），获得 $gPts 局分（比分 ${gameScores[0]}:${gameScores[1]}）');

    if (gameScores[winner] >= targetPoints) {
      over = true;
      result = {
        'winner': winner,
        'gameScores': List<int>.of(gameScores),
        'lastHand': lastHandResult,
      };
      return;
    }

    dealer = 1 - dealer;
    _startNewHand();
  }

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings {
    if (!over) return null;
    if (resignedSeat != null) {
      return rankWinners(players, [1 - resignedSeat!]);
    }
    return rankByScore(gameScores);
  }

  @override
  bool get canResign => !over;

  @override
  void resign(int seat) {
    if (over) throw GameError('游戏已结束');
    resignedSeat = seat;
    over = true;
    final winner = 1 - seat;
    result = {
      'winner': winner,
      'resigned': seat,
      'gameScores': List<int>.of(gameScores),
    };
    host.log('${name(seat)} 认输，${name(winner)} 获胜');
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    if (leadCard == null) {
      if (canSwapTrump(seat) && botLevel > 0) {
        return {'type': 'swap_trump'};
      }
      final h = hands[seat];
      if (botLevel == 0) {
        return {'type': 'play', 'card': h[rng.nextInt(h.length)]};
      }
      // Prefer declaring a marriage if possible
      for (final c in h) {
        if (canDeclareMarriageWith(seat, c)) {
          return {'type': 'play', 'card': c};
        }
      }
      // Consider closing stock if hand is very strong and close to 66
      if (canCloseStock(seat) && botLevel >= 2) {
        final highTrumps = h
            .where((c) => sixtySixSuit(c) == trumpSuit && sixtySixVal(c) >= 10)
            .length;
        final aces = h.where((c) => sixtySixRank(c) == 'A').length;
        if (effectivePoints(seat) >= 45 && (highTrumps + aces >= 2)) {
          return {'type': 'close'};
        }
      }
      // While stock is open, lead a low non-trump card; when closed/empty, lead high
      final strict = closed || stock.isEmpty;
      final sorted = List<String>.of(h);
      if (!strict) {
        sorted.sort((a, b) {
          final ta = sixtySixSuit(a) == trumpSuit ? 1 : 0;
          final tb = sixtySixSuit(b) == trumpSuit ? 1 : 0;
          if (ta != tb) return ta.compareTo(tb);
          return sixtySixVal(a).compareTo(sixtySixVal(b));
        });
      } else {
        sorted.sort((a, b) => sixtySixVal(b).compareTo(sixtySixVal(a)));
      }
      return {'type': 'play', 'card': sorted.first};
    } else {
      final legals = legalPlays(seat);
      if (botLevel == 0) {
        return {'type': 'play', 'card': legals[rng.nextInt(legals.length)]};
      }
      final lead = leadCard!;
      bool winsTrick(String c) {
        if (sixtySixSuit(c) == sixtySixSuit(lead)) {
          return sixtySixPower(c) > sixtySixPower(lead);
        }
        return sixtySixSuit(c) == trumpSuit;
      }

      final winning = legals.where(winsTrick).toList();
      if (winning.isNotEmpty) {
        // Check if any winning card reaches 66 immediately
        for (final c in winning) {
          final newPts = cardPoints[seat] +
              marriagePoints[seat] +
              sixtySixVal(lead) +
              sixtySixVal(c);
          if (newPts >= 66) {
            return {'type': 'play', 'card': c};
          }
        }
        // Win high-value lead card with cheapest winner
        if (sixtySixVal(lead) >= 10 || closed || stock.isEmpty) {
          winning.sort((a, b) {
            final ta = sixtySixSuit(a) == trumpSuit ? 1 : 0;
            final tb = sixtySixSuit(b) == trumpSuit ? 1 : 0;
            if (ta != tb) return ta.compareTo(tb);
            return sixtySixVal(a).compareTo(sixtySixVal(b));
          });
          return {'type': 'play', 'card': winning.first};
        }
      }
      // Otherwise discard lowest value card
      final sorted = List<String>.of(legals)
        ..sort((a, b) {
          final ta = sixtySixSuit(a) == trumpSuit ? 1 : 0;
          final tb = sixtySixSuit(b) == trumpSuit ? 1 : 0;
          if (ta != tb) return ta.compareTo(tb);
          return sixtySixVal(a).compareTo(sixtySixVal(b));
        });
      return {'type': 'play', 'card': sorted.first};
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myHand =
        (seat >= 0 && seat < players) ? List<String>.of(hands[seat]) : <String>[];
    final legals = (seat >= 0 && seat < players) ? legalPlays(seat) : <String>[];
    final marriageCards = (seat >= 0 && seat < players)
        ? [
            for (final c in hands[seat])
              if (canDeclareMarriageWith(seat, c)) c,
          ]
        : <String>[];
    return {
      'targetPoints': targetPoints,
      'gameScores': List<int>.of(gameScores),
      'handNumber': handNumber,
      'dealer': dealer,
      'leader': leader,
      'turn': turn,
      'hand': myHand,
      'handCounts': [hands[0].length, hands[1].length],
      'stockCount': stock.length,
      'trumpCard': stock.isNotEmpty ? trumpCard : null,
      'trumpSuit': trumpSuit,
      'closed': closed,
      'closer': closer,
      'strict': closed || stock.isEmpty,
      'leadCard': leadCard,
      'lastMarriageBonus': lastMarriageBonus,
      'cardPoints': List<int>.of(cardPoints),
      'marriagePoints': List<int>.of(marriagePoints),
      'effectivePoints': [effectivePoints(0), effectivePoints(1)],
      'marriages': [List<String>.of(marriages[0]), List<String>.of(marriages[1])],
      'tricksWon': List<int>.of(tricksWon),
      'canSwapTrump': seat >= 0 && seat < players && canSwapTrump(seat),
      'canClose': seat >= 0 && seat < players && canCloseStock(seat),
      'legalPlays': legals,
      'marriageCards': marriageCards,
      'lastTrick': lastTrick,
      'lastHandResult': lastHandResult,
      'result': result,
      'over': over,
    };
  }
}
