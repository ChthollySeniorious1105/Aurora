import 'dart:math';

import '../../src/engine.dart';

const List<String> foxSuitCodes = ['B', 'K', 'M'];

const Map<int, String> foxSuitNames = {
  0: '🔔 铃铛 (Bells)',
  1: '🗝️ 钥匙 (Keys)',
  2: '🌙 月亮 (Moons)',
};

const Map<int, String> foxOddPowerNames = {
  1: '天鹅 (Swan)：出1输墩则下墩先手',
  3: '狐狸 (Fox)：可与法令牌交换改主',
  5: '樵夫 (Woodcutter)：抽1张并弃1张至牌堆底',
  7: '宝藏 (Treasure)：赢墩者每张7得+1奖励分',
  9: '女巫 (Witch)：本墩仅一张9时视为王牌花色',
  11: '君王 (Monarch)：领出时对手须跟同花色1或最大牌',
};

/// Suit index 0 (Bells 'B'), 1 (Keys 'K'), 2 (Moons 'M').
int foxCardSuit(String card) {
  if (card.isEmpty) return -1;
  return switch (card[card.length - 1]) {
    'B' || '0' => 0,
    'K' || '1' => 1,
    'M' || '2' => 2,
    _ => -1,
  };
}

/// Rank 1..11 of [card].
int foxCardRank(String card) {
  if (card.length < 2) return 0;
  return int.tryParse(card.substring(0, card.length - 1)) ?? 0;
}

String makeFoxCard(int rank, int suit) => '$rank${foxSuitCodes[suit]}';

/// Builds the 33-card deck (1..11 in 3 suits: B, K, M).
List<String> buildFoxDeck() => [
      for (var s = 0; s < 3; s++)
        for (var r = 1; r <= 11; r++) makeFoxCard(r, s),
    ];

/// The "Humble vs. Greedy" scoring table for 13 tricks.
int foxTrickScore(int tricks) {
  if (tricks <= 3) return 6; // Humble (谦逊 0..3)
  if (tricks == 4) return 1;
  if (tricks == 5) return 2;
  if (tricks == 6) return 3;
  if (tricks <= 9) return 6; // Victorious (凯旋 7..9)
  return 0; // Greedy (贪婪爆分 10..13)
}

String foxScoreTitle(int tricks) {
  if (tricks <= 3) return '谦逊 (Humble)';
  if (tricks <= 6) return '败北 (Defeated)';
  if (tricks <= 9) return '凯旋 (Victorious)';
  return '贪婪爆分 (Greedy)';
}

/// Determines the winning seat of a 2-card [trick] given [trumpSuit] (0, 1, or 2).
/// Handles the Witch ('9') rule: if exactly ONE '9' is in the trick, its effective suit is [trumpSuit].
int foxTrickWinner(List<Map<String, dynamic>> trick, int trumpSuit) {
  if (trick.isEmpty) return 0;
  if (trick.length == 1) return asInt(trick.first['seat'], 0);

  final s0 = asInt(trick[0]['seat'], 0);
  final s1 = asInt(trick[1]['seat'], 1);
  final c0 = asStr(trick[0]['card']);
  final c1 = asStr(trick[1]['card']);
  final r0 = foxCardRank(c0);
  final r1 = foxCardRank(c1);

  final exactlyOneNine = (r0 == 9) != (r1 == 9);
  final eff0 = (exactlyOneNine && r0 == 9) ? trumpSuit : foxCardSuit(c0);
  final eff1 = (exactlyOneNine && r1 == 9) ? trumpSuit : foxCardSuit(c1);

  if (eff0 == trumpSuit && eff1 != trumpSuit) return s0;
  if (eff1 == trumpSuit && eff0 != trumpSuit) return s1;
  if (eff0 == eff1) return r1 > r0 ? s1 : s0;
  return s0;
}

class FoxInTheForestGame extends GameEngine {
  late int totalRounds;
  int round = 1;
  int dealer = 0;
  int leader = 0;
  int turn = 0;
  String phase = 'play'; // 'play' | 'fox_swap' | 'woodcutter_discard'
  String decreeCard = '1B';
  List<String> stock = [];

  late List<List<String>> hands;
  late List<int> scores;
  late List<int> tricksWon;
  late List<int> bonusPoints;
  List<Map<String, dynamic>> trick = [];
  Map<String, dynamic>? lastTrick;
  Map<String, dynamic>? lastRoundSummary;
  int trickNumber = 1;

  bool _over = false;
  List<int>? _placings;

  FoxInTheForestGame(super.setup) {
    totalRounds = setup.opt<int>('rounds', 2);
    hands = List.generate(players, (_) => <String>[]);
    scores = List.filled(players, 0);
    tricksWon = List.filled(players, 0);
    bonusPoints = List.filled(players, 0);
  }

  int get trumpSuit => foxCardSuit(decreeCard);

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
    final deck = shuffled(buildFoxDeck(), rng);
    hands[0] = deck.sublist(0, 13);
    hands[1] = deck.sublist(13, 26);
    decreeCard = deck[26];
    stock = deck.sublist(27); // 6 cards in stock
    for (var s = 0; s < players; s++) {
      _sortHand(hands[s]);
      tricksWon[s] = 0;
      bonusPoints[s] = 0;
    }
    phase = 'play';
    leader = (dealer + 1) % players;
    turn = leader;
    trick = [];
    trickNumber = 1;
    host.log('第 $round/$totalRounds 局开始，法令牌为 $decreeCard（王牌花色：${foxSuitNames[trumpSuit]}）');
  }

  void _sortHand(List<String> hand) {
    final ts = trumpSuit;
    hand.sort((a, b) {
      final sa = foxCardSuit(a);
      final sb = foxCardSuit(b);
      final ta = sa == ts;
      final tb = sb == ts;
      if (ta != tb) return ta ? -1 : 1;
      if (sa != sb) return sa.compareTo(sb);
      return foxCardRank(b).compareTo(foxCardRank(a));
    });
  }

  List<String> legalCards(int seat) {
    final hand = hands[seat];
    if (phase != 'play') return List<String>.of(hand);
    if (trick.isEmpty) return List<String>.of(hand);

    final leadCard = asStr(trick.first['card']);
    final leadSuit = foxCardSuit(leadCard);
    final leadRank = foxCardRank(leadCard);
    final sameSuit = hand.where((c) => foxCardSuit(c) == leadSuit).toList();
    if (sameSuit.isEmpty) return List<String>.of(hand);

    // Monarch ('11') power: follower must play '1' of that suit OR highest card of that suit
    if (leadRank == 11) {
      final maxRank = sameSuit.map(foxCardRank).reduce(max);
      return sameSuit.where((c) {
        final r = foxCardRank(c);
        return r == 1 || r == maxRank;
      }).toList();
    }

    return sameSuit;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);

    if (phase == 'fox_swap') {
      if (type == 'pass' || type == 'skip') {
        host.log('${name(seat)} 放弃发动狐狸(3)交换法令牌');
        _afterCardEffect(seat);
        return;
      }
      if (type != 'fox_swap' && type != 'swap') {
        throw GameError('请选择与法令牌交换的手牌，或选择不交换(pass)');
      }
      final card = asStr(action['card']);
      if (card.isEmpty) {
        _afterCardEffect(seat);
        return;
      }
      if (!hands[seat].contains(card)) {
        throw GameError('手牌中没有该张牌');
      }
      final oldDecree = decreeCard;
      hands[seat].remove(card);
      hands[seat].add(oldDecree);
      decreeCard = card;
      for (var s = 0; s < players; s++) {
        _sortHand(hands[s]);
      }
      host.log('${name(seat)} 发动狐狸(3)：将法令牌换为 $decreeCard（新王牌花色：${foxSuitNames[trumpSuit]}）');
      _afterCardEffect(seat);
      return;
    }

    if (phase == 'woodcutter_discard') {
      if (type != 'woodcutter_discard' && type != 'discard') {
        throw GameError('樵夫(5)效果：请选择 1 张手牌弃置到牌库底');
      }
      final card = asStr(action['card']);
      if (!hands[seat].contains(card)) {
        throw GameError('手牌中没有该张牌');
      }
      hands[seat].remove(card);
      stock.add(card);
      _sortHand(hands[seat]);
      host.log('${name(seat)} 完成樵夫(5)换牌，将 1 张牌置入牌库底');
      _afterCardEffect(seat);
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
        final leadCard = trick.isNotEmpty ? asStr(trick.first['card']) : '';
        if (foxCardRank(leadCard) == 11) {
          throw GameError('对手领出君王(11)，必须跟出同花色的 1 或最大牌');
        }
        throw GameError('必须跟出领出花色');
      }

      hands[seat].remove(card);
      trick.add({'seat': seat, 'card': card});
      final rank = foxCardRank(card);

      // Odd card immediate powers: 3 (Fox) and 5 (Woodcutter)
      if (rank == 3 && hands[seat].isNotEmpty) {
        phase = 'fox_swap';
        turn = seat;
        return;
      }

      if (rank == 5 && stock.isNotEmpty) {
        final drawn = stock.removeAt(0);
        hands[seat].add(drawn);
        _sortHand(hands[seat]);
        phase = 'woodcutter_discard';
        turn = seat;
        return;
      }

      _afterCardEffect(seat);
      return;
    }

    throw GameError('未知阶段');
  }

  void _afterCardEffect(int seatJustPlayed) {
    phase = 'play';
    if (trick.length < players) {
      turn = 1 - seatJustPlayed;
      return;
    }
    _resolveTrick();
  }

  void _resolveTrick() {
    final winner = foxTrickWinner(trick, trumpSuit);
    final loser = 1 - winner;
    tricksWon[winner] += 1;

    // 7 (Treasure): +1 bonus point per '7' in the trick
    var sevens = 0;
    for (final e in trick) {
      if (foxCardRank(asStr(e['card'])) == 7) {
        sevens += 1;
      }
    }
    if (sevens > 0) {
      bonusPoints[winner] += sevens;
    }

    // 1 (Swan): if loser played a '1', loser leads the next trick!
    final loserEntry = trick.firstWhere((e) => asInt(e['seat']) == loser);
    final loserCard = asStr(loserEntry['card']);
    final swanTriggered = foxCardRank(loserCard) == 1;
    final nextLeader = swanTriggered ? loser : winner;

    lastTrick = {
      'winner': winner,
      'nextLeader': nextLeader,
      'swanTriggered': swanTriggered,
      'treasureBonus': sevens,
      'cards': [for (final e in trick) Map<String, dynamic>.of(e)],
    };

    trick = [];
    leader = nextLeader;
    turn = nextLeader;
    trickNumber += 1;

    if (hands.every((h) => h.isEmpty)) {
      resolveRound();
    }
  }

  void resolveRound() {
    final trickPts = [
      for (var s = 0; s < players; s++) foxTrickScore(tricksWon[s]),
    ];
    final roundTotal = [
      for (var s = 0; s < players; s++) trickPts[s] + bonusPoints[s],
    ];
    for (var s = 0; s < players; s++) {
      scores[s] += roundTotal[s];
    }

    lastRoundSummary = {
      'round': round,
      'tricksWon': List<int>.of(tricksWon),
      'trickPoints': trickPts,
      'bonusPoints': List<int>.of(bonusPoints),
      'roundTotal': roundTotal,
      'titles': [for (var s = 0; s < players; s++) foxScoreTitle(tricksWon[s])],
    };

    host.log('第 $round 局结算：'
        '${name(0)} ${tricksWon[0]}墩(${foxScoreTitle(tricksWon[0])} +${trickPts[0]}分, 宝藏+${bonusPoints[0]}分) vs '
        '${name(1)} ${tricksWon[1]}墩(${foxScoreTitle(tricksWon[1])} +${trickPts[1]}分, 宝藏+${bonusPoints[1]}分)');

    if (round >= totalRounds || scores.any((sc) => sc >= 21)) {
      _over = true;
      _placings = rankByScore(scores);
      host.log('比赛结束！');
    } else {
      round += 1;
      dealer = 1 - dealer;
      _startRound();
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    final hand = hands[seat];

    if (phase == 'fox_swap') {
      if (hand.isNotEmpty && rng.nextBool()) {
        return {'type': 'fox_swap', 'card': hand.last};
      }
      return {'type': 'pass'};
    }

    if (phase == 'woodcutter_discard') {
      if (hand.isEmpty) return null;
      // Discard a low non-trump non-7 card if possible
      final sorted = List<String>.of(hand)
        ..sort((a, b) {
          final pa = foxCardRank(a) == 7 ? 100 : foxCardRank(a);
          final pb = foxCardRank(b) == 7 ? 100 : foxCardRank(b);
          return pa.compareTo(pb);
        });
      return {'type': 'woodcutter_discard', 'card': sorted.first};
    }

    if (phase == 'play') {
      final legal = legalCards(seat);
      if (legal.isEmpty) return null;
      if (botLevel == 0) {
        return {'type': 'play', 'card': legal[rng.nextInt(legal.length)]};
      }
      // Avoid going Greedy (>= 10 tricks)! If already at 8 or 9 tricks, try to lose tricks
      if (tricksWon[seat] >= 8) {
        final low = List<String>.of(legal)
          ..sort((a, b) => foxCardRank(a).compareTo(foxCardRank(b)));
        return {'type': 'play', 'card': low.first};
      }
      return {'type': 'play', 'card': legal.first};
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myLegal = (seat >= 0 && seat < players && seat == turn)
        ? legalCards(seat)
        : <String>[];
    return {
      'round': round,
      'totalRounds': totalRounds,
      'phase': phase,
      'dealer': dealer,
      'leader': leader,
      'turn': turn,
      'decreeCard': decreeCard,
      'trumpSuit': trumpSuit,
      'trumpSuitName': foxSuitNames[trumpSuit] ?? '',
      'stockCount': stock.length,
      'trickNumber': trickNumber,
      'scores': List<int>.of(scores),
      'tricksWon': List<int>.of(tricksWon),
      'bonusPoints': List<int>.of(bonusPoints),
      'handCounts': [for (final h in hands) h.length],
      'hand': (seat >= 0 && seat < players) ? List<String>.of(hands[seat]) : <String>[],
      'legal': myLegal,
      'trick': [for (final e in trick) Map<String, dynamic>.of(e)],
      'lastTrick': lastTrick,
      'lastRoundSummary': lastRoundSummary,
      'over': _over,
      'placings': _placings,
    };
  }
}
