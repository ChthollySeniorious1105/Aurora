import '../../src/engine.dart';

const List<String> wizardSuits = ['S', 'H', 'D', 'C'];
const List<String> wizardRanks = [
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

const Map<String, String> wizardSuitNames = {
  'S': '♠ 黑桃',
  'H': '♥ 红心',
  'D': '♦ 方块',
  'C': '♣ 梅花',
};

bool isWizardCard(String card) => card.startsWith('W');

bool isJesterCard(String card) =>
    card == 'J' ||
    card == 'J1' ||
    card == 'J2' ||
    card == 'J3' ||
    card == 'J4';

bool isStandardWizardCard(String card) =>
    !isWizardCard(card) && !isJesterCard(card) && card.length >= 2;

String wizardCardSuit(String card) =>
    isStandardWizardCard(card) ? card[card.length - 1] : '';

String wizardCardRank(String card) =>
    isStandardWizardCard(card) ? card.substring(0, card.length - 1) : '';

int wizardRankOrder(String rank) => switch (rank) {
      'A' => 14,
      'K' => 13,
      'Q' => 12,
      'J' => 11,
      'T' => 10,
      '9' => 9,
      '8' => 8,
      '7' => 7,
      '6' => 6,
      '5' => 5,
      '4' => 4,
      '3' => 3,
      '2' => 2,
      _ => 0,
    };

/// Builds the 60-card Wizard deck (52 standard cards + 4 Wizards W1..W4 + 4 Jesters J1..J4).
List<String> buildWizardDeck() => [
      for (final s in wizardSuits)
        for (final r in wizardRanks) '$r$s',
      'W1',
      'W2',
      'W3',
      'W4',
      'J1',
      'J2',
      'J3',
      'J4',
    ];

/// Determines the led suit of [trick].
/// - If a Wizard is led before any standard card, returns null (any card may be played).
/// - Jesters are skipped until the first non-Jester card is seen.
/// - Returns the suit ('S','H','D','C') of the first standard card played, or null.
String? wizardTrickLeadSuit(List<Map<String, dynamic>> trick) {
  for (final e in trick) {
    final c = asStr(e['card']);
    if (isJesterCard(c)) continue;
    if (isWizardCard(c)) return null;
    final s = wizardCardSuit(c);
    if (s.isNotEmpty) return s;
  }
  return null;
}

/// Determines the winning seat of [trick] given [trumpSuit].
/// 1. First Wizard played always wins.
/// 2. If all cards are Jesters, the first Jester played wins.
/// 3. Highest trump suit card wins; otherwise highest card of the led suit wins.
int wizardTrickWinner(List<Map<String, dynamic>> trick, String? trumpSuit) {
  if (trick.isEmpty) return 0;

  // 1. First Wizard played always wins
  for (final e in trick) {
    if (isWizardCard(asStr(e['card']))) {
      return asInt(e['seat'], 0);
    }
  }

  // 2. If all cards played are Jesters, the first Jester wins
  if (trick.every((e) => isJesterCard(asStr(e['card'])))) {
    return asInt(trick.first['seat'], 0);
  }

  // 3. Standard cards comparison (Jesters have strength 0)
  final leadSuit = wizardTrickLeadSuit(trick);
  var bestSeat = asInt(trick.first['seat'], 0);
  var bestStr = -1;
  for (final e in trick) {
    final c = asStr(e['card']);
    var str = 0;
    if (isStandardWizardCard(c)) {
      final s = wizardCardSuit(c);
      final r = wizardRankOrder(wizardCardRank(c));
      if (trumpSuit != null && trumpSuit.isNotEmpty && s == trumpSuit) {
        str = 100 + r;
      } else if (leadSuit != null && s == leadSuit) {
        str = 10 + r;
      }
    }
    if (str > bestStr) {
      bestStr = str;
      bestSeat = asInt(e['seat'], 0);
    }
  }
  return bestSeat;
}

/// Exact bid: +20 + 10 * bid; Missed bid by d = |bid - won|: -10 * d.
int wizardRoundScore(int bid, int won) {
  if (bid == won) return 20 + 10 * bid;
  return -10 * (bid - won).abs();
}

class WizardGame extends GameEngine {
  late int totalRounds;
  int round = 1;
  int roundCards = 1;
  int dealer = 0;
  int leader = 0;
  int turn = 0;
  String phase = 'bid'; // 'choose_trump' | 'bid' | 'play'
  String? trumpCard;
  String? trumpSuit; // 'S' | 'H' | 'D' | 'C' | null (No Trump)

  late List<List<String>> hands;
  late List<int> scores;
  late List<int?> bids;
  late List<int> tricksWon;
  List<Map<String, dynamic>> trick = [];
  Map<String, dynamic>? lastTrick;
  Map<String, dynamic>? lastRoundSummary;
  int trickNumber = 1;

  bool _over = false;
  List<int>? _placings;

  WizardGame(super.setup) {
    totalRounds = setup.opt<int>('rounds', 6);
    hands = List.generate(players, (_) => <String>[]);
    scores = List.filled(players, 0);
    bids = List.filled(players, null);
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
    final winners = [for (var i = 0; i < players; i++) if (i != seat) i];
    _placings = rankWinners(players, winners);
    host.log('${name(seat)} 认输');
  }

  @override
  void start() {
    _startRound();
  }

  int _cardsForRound(int r) {
    if (totalRounds == 4) return r + 1; // 2..5 cards
    return r; // 1..6 cards
  }

  void _startRound() {
    roundCards = _cardsForRound(round);
    final deck = shuffled(buildWizardDeck(), rng);
    var idx = 0;
    for (var s = 0; s < players; s++) {
      hands[s] = deck.sublist(idx, idx + roundCards);
      idx += roundCards;
      _sortHand(hands[s]);
      bids[s] = null;
      tricksWon[s] = 0;
    }

    trumpCard = idx < deck.length ? deck[idx] : null;
    trick = [];
    trickNumber = 1;
    leader = (dealer + 1) % players;

    if (trumpCard == null || isJesterCard(trumpCard!)) {
      trumpSuit = null;
      phase = 'bid';
      turn = leader;
      host.log('第 $round/$totalRounds 轮 ($roundCards张)：翻出 ${trumpCard ?? "无"}，本轮无主牌！');
    } else if (isWizardCard(trumpCard!)) {
      trumpSuit = null;
      phase = 'choose_trump';
      turn = dealer;
      host.log('第 $round/$totalRounds 轮 ($roundCards张)：翻出巫师 $trumpCard，由发牌人 ${name(dealer)} 指定主牌花色');
    } else {
      trumpSuit = wizardCardSuit(trumpCard!);
      phase = 'bid';
      turn = leader;
      for (var s = 0; s < players; s++) {
        _sortHand(hands[s]);
      }
      host.log('第 $round/$totalRounds 轮 ($roundCards张)：翻出 $trumpCard，主牌花色为 ${wizardSuitNames[trumpSuit] ?? trumpSuit}');
    }
  }

  void _sortHand(List<String> hand) {
    hand.sort((a, b) {
      if (isWizardCard(a) != isWizardCard(b)) return isWizardCard(a) ? -1 : 1;
      if (isJesterCard(a) != isJesterCard(b)) return isJesterCard(a) ? 1 : -1;
      if (isWizardCard(a) || isJesterCard(a)) return a.compareTo(b);
      final sa = wizardCardSuit(a);
      final sb = wizardCardSuit(b);
      final ta = sa == trumpSuit;
      final tb = sb == trumpSuit;
      if (ta != tb) return ta ? -1 : 1;
      final ia = wizardSuits.indexOf(sa);
      final ib = wizardSuits.indexOf(sb);
      if (ia != ib) return ia.compareTo(ib);
      return wizardRankOrder(wizardCardRank(b))
          .compareTo(wizardRankOrder(wizardCardRank(a)));
    });
  }

  List<String> legalCards(int seat) {
    final hand = hands[seat];
    if (trick.isEmpty) return List<String>.of(hand);
    final leadSuit = wizardTrickLeadSuit(trick);
    if (leadSuit == null) return List<String>.of(hand);

    final hasLeadSuit = hand.any((c) => isStandardWizardCard(c) && wizardCardSuit(c) == leadSuit);
    if (!hasLeadSuit) return List<String>.of(hand);

    // Must play led suit OR any Wizard OR any Jester
    return hand
        .where((c) =>
            isWizardCard(c) ||
            isJesterCard(c) ||
            wizardCardSuit(c) == leadSuit)
        .toList();
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    if (phase == 'choose_trump') {
      final suit = asStr(action['suit'], asStr(action['trump'])).toUpperCase();
      if (!wizardSuits.contains(suit)) {
        throw GameError('请选择有效的主牌花色 (S / H / D / C)');
      }
      trumpSuit = suit;
      phase = 'bid';
      turn = (dealer + 1) % players;
      for (var s = 0; s < players; s++) {
        _sortHand(hands[s]);
      }
      host.log('${name(seat)} 指定主牌花色为 ${wizardSuitNames[suit]}');
      return;
    }

    if (phase == 'bid') {
      if (type != 'bid') throw GameError('请先预测赢墩数');
      final b = asInt(action['bid'], -1);
      if (b < 0 || b > roundCards) {
        throw GameError('预测墩数必须在 0 ~ $roundCards 之间');
      }
      bids[seat] = b;
      host.log('${name(seat)} 预测赢得 $b 墩');

      if (bids.every((x) => x != null)) {
        phase = 'play';
        leader = (dealer + 1) % players;
        turn = leader;
      } else {
        turn = (turn + 1) % players;
      }
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
        throw GameError('必须跟出领出花色（或打出巫师/小丑）');
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
    final winner = wizardTrickWinner(trick, trumpSuit);
    tricksWon[winner] += 1;

    lastTrick = {
      'winner': winner,
      'cards': [for (final e in trick) Map<String, dynamic>.of(e)],
    };

    trick = [];
    leader = winner;
    turn = winner;
    trickNumber += 1;

    if (hands.every((h) => h.isEmpty)) {
      _finishRound();
    }
  }

  void _finishRound() {
    final roundDelta = List<int>.filled(players, 0);
    for (var s = 0; s < players; s++) {
      final b = bids[s] ?? 0;
      final w = tricksWon[s];
      roundDelta[s] = wizardRoundScore(b, w);
      scores[s] += roundDelta[s];
    }

    lastRoundSummary = {
      'round': round,
      'roundCards': roundCards,
      'bids': [for (final b in bids) b ?? 0],
      'tricksWon': List<int>.of(tricksWon),
      'roundDelta': roundDelta,
    };

    host.log('第 $round 轮结算：${[
      for (var s = 0; s < players; s++)
        '${name(s)} (${tricksWon[s]}/${bids[s]}墩 ${roundDelta[s] >= 0 ? "+" : ""}${roundDelta[s]}分)'
    ].join("，")}');

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
    final hand = hands[seat];

    if (phase == 'choose_trump') {
      var bestSuit = 'S';
      var bestCount = -1;
      for (final s in wizardSuits) {
        final cnt = hand.where((c) => wizardCardSuit(c) == s).length;
        if (cnt > bestCount) {
          bestCount = cnt;
          bestSuit = s;
        }
      }
      return {'type': 'choose_trump', 'suit': bestSuit};
    }

    if (phase == 'bid') {
      var est = 0;
      for (final c in hand) {
        if (isWizardCard(c)) {
          est += 1;
        } else if (isStandardWizardCard(c)) {
          final r = wizardRankOrder(wizardCardRank(c));
          final isTrump = trumpSuit != null && wizardCardSuit(c) == trumpSuit;
          if (isTrump && r >= 10) {
            est += 1;
          } else if (r >= 13) {
            est += 1;
          }
        }
      }
      return {'type': 'bid', 'bid': est.clamp(0, roundCards)};
    }

    if (phase == 'play') {
      final legal = legalCards(seat);
      if (legal.isEmpty) return null;
      if (botLevel == 0) {
        return {'type': 'play', 'card': legal[rng.nextInt(legal.length)]};
      }
      final target = bids[seat] ?? 0;
      final needMore = tricksWon[seat] < target;
      if (needMore) {
        final wiz = legal.where(isWizardCard).toList();
        if (wiz.isNotEmpty) return {'type': 'play', 'card': wiz.first};
        return {'type': 'play', 'card': legal.first};
      } else {
        // Avoid winning more tricks: play Jester or lowest card
        final jesters = legal.where(isJesterCard).toList();
        if (jesters.isNotEmpty) return {'type': 'play', 'card': jesters.first};
        return {'type': 'play', 'card': legal.last};
      }
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
      'roundCards': roundCards,
      'phase': phase,
      'dealer': dealer,
      'leader': leader,
      'turn': turn,
      'trumpCard': trumpCard,
      'trumpSuit': trumpSuit,
      'trumpSuitName': trumpSuit != null ? wizardSuitNames[trumpSuit!] : '无主牌',
      'trickNumber': trickNumber,
      'scores': List<int>.of(scores),
      'bids': List<int?>.of(bids),
      'tricksWon': List<int>.of(tricksWon),
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
