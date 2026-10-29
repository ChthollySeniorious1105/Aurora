import '../../src/engine.dart';

const List<String> beziqueSuits = ['S', 'H', 'D', 'C'];

/// Rank order in Bezique from lowest (`7`) to highest (`A`):
/// `7 < 8 < 9 < J < Q < K < T < A`.
const List<String> beziqueRanks = ['7', '8', '9', 'J', 'Q', 'K', 'T', 'A'];

const Map<String, String> beziqueSuitNames = {
  'S': '♠ 黑桃',
  'H': '♥ 红心',
  'D': '♦ 方块',
  'C': '♣ 梅花',
};

const Map<String, String> beziqueMeldTitles = {
  'dix': 'Dix (主花色7 · 换底牌)',
  'common_marriage': '普通王室联姻 (副花色K+Q)',
  'royal_marriage': '皇家联姻 (主花色K+Q)',
  'bezique': '贝济克 Bezique (♠Q+♦J)',
  'double_bezique': '双倍贝济克 Double Bezique (2×♠Q+2×♦J)',
  'four_jacks': '四卫兵 (4张J)',
  'four_queens': '四王后 (4张Q)',
  'four_kings': '四国王 (4张K)',
  'four_aces': '四王牌 (4张A)',
  'trump_sequence': '主花色大顺 (主花色A-T-K-Q-J)',
};

/// Strips the `_0` / `_1` copy suffix from a Bezique card code (e.g. `'QS_0'` -> `'QS'`).
String beziqueBaseCard(String card) {
  final idx = card.indexOf('_');
  return idx >= 0 ? card.substring(0, idx) : card;
}

String beziqueCardRank(String card) {
  final base = beziqueBaseCard(card);
  return base.length >= 2 ? base.substring(0, base.length - 1) : '';
}

String beziqueCardSuit(String card) {
  final base = beziqueBaseCard(card);
  return base.length >= 2 ? base[base.length - 1] : '';
}

/// Builds the 64-card Bezique deck (`2` copies each of `7, 8, 9, J, Q, K, T, A` in `S, H, D, C`).
List<String> buildBeziqueDeck() => [
      for (final copy in const [0, 1])
        for (final s in beziqueSuits)
          for (final r in beziqueRanks) '$r${s}_$copy',
    ];

/// Rank order (`0..7`): `A(7) > T(6) > K(5) > Q(4) > J(3) > 9(2) > 8(1) > 7(0)`.
int beziqueRankOrder(String cardOrRank) {
  final r = cardOrRank.length >= 2 ? beziqueCardRank(cardOrRank) : cardOrRank;
  return beziqueRanks.indexOf(r);
}

/// Brisque value of a card won in a trick (`A` and `T` are worth `10` pts each; others `0`).
int beziqueBrisquePoints(String card) {
  final r = beziqueCardRank(card);
  return (r == 'A' || r == 'T') ? 10 : 0;
}

/// Trick-taking strength of [card] given [trumpSuit] and [leadSuit].
int beziqueCardStrength(String card, String trumpSuit, String leadSuit) {
  final s = beziqueCardSuit(card);
  final rOrder = beziqueRankOrder(card);
  if (s == trumpSuit) return 100 + rOrder;
  if (s == leadSuit) return 10 + rOrder;
  return rOrder;
}

/// Evaluates the winning seat of a 2-player [trick] under [trumpSuit].
/// Uses strict `>` so if two identical cards are played, the leader wins!
int beziqueTrickWinner(List<Map<String, dynamic>> trick, String trumpSuit) {
  if (trick.isEmpty) return 0;
  final leadCard = asStr(trick.first['card']);
  final leadSuit = beziqueCardSuit(leadCard);
  var bestSeat = asInt(trick.first['seat'], 0);
  var bestStr = beziqueCardStrength(leadCard, trumpSuit, leadSuit);
  for (var i = 1; i < trick.length; i++) {
    final c = asStr(trick[i]['card']);
    final str = beziqueCardStrength(c, trumpSuit, leadSuit);
    if (str > bestStr) {
      bestStr = str;
      bestSeat = asInt(trick[i]['seat'], 0);
    }
  }
  return bestSeat;
}

/// Computes legal cards from [hand] given [trick] and [trumpSuit]:
/// - Stage 1 (`stockEmpty == false`): any card in [hand] may be played!
/// - Stage 2 (`stockEmpty == true`, final 8 tricks):
///   1. Must follow the led suit and beat the led card if able;
///   2. Otherwise, if holding the led suit, play any card of the led suit;
///   3. If void in the led suit, must play a trump card if holding any;
///   4. Otherwise, play any card.
List<String> beziqueLegalCards(
  List<String> hand,
  List<Map<String, dynamic>> trick,
  String trumpSuit, {
  required bool stockEmpty,
}) {
  if (trick.isEmpty || !stockEmpty) return List<String>.of(hand);

  final leadCard = asStr(trick.first['card']);
  final leadSuit = beziqueCardSuit(leadCard);
  final leadRankOrder = beziqueRankOrder(leadCard);

  final sameSuit = hand.where((c) => beziqueCardSuit(c) == leadSuit).toList();
  if (sameSuit.isNotEmpty) {
    final higher =
        sameSuit.where((c) => beziqueRankOrder(c) > leadRankOrder).toList();
    return higher.isNotEmpty ? higher : sameSuit;
  }

  final trumps = hand.where((c) => beziqueCardSuit(c) == trumpSuit).toList();
  if (trumps.isNotEmpty) return trumps;

  return List<String>.of(hand);
}

/// Point value for a Bezique meld category.
int beziqueMeldPoints(String meldType) => switch (meldType) {
      'dix' => 10,
      'common_marriage' => 20,
      'royal_marriage' => 40,
      'bezique' => 40,
      'double_bezique' => 500,
      'four_jacks' => 40,
      'four_queens' => 60,
      'four_kings' => 80,
      'four_aces' => 100,
      'trump_sequence' => 250,
      _ => 0,
    };

/// Returns all valid, undeclared melds currently present in [hand] under [trumpSuit].
/// Each returned map has:
/// - `'id'`: unique declaration key (e.g. `'bezique'`, `'double_bezique'`, `'common_marriage_H'`, `'dix_7S_0'`)
/// - `'type'`: canonical meld type (`'dix'`, `'common_marriage'`, `'royal_marriage'`, `'bezique'`, `'double_bezique'`, `'four_jacks'`, `'four_queens'`, `'four_kings'`, `'four_aces'`, `'trump_sequence'`)
/// - `'points'`: point value
/// - `'title'`: display label
/// - `'suit'`: relevant suit (if applicable)
/// - `'card'`: specific card for `'dix'` swap (if applicable)
List<Map<String, dynamic>> beziqueAvailableMelds(
  List<String> hand,
  String trumpSuit,
  Set<String> declaredIds,
) {
  final out = <Map<String, dynamic>>[];
  final baseSet = {for (final c in hand) beziqueBaseCard(c)};

  // 1. Double Bezique (2x QS + 2x JD = 500 pts)
  final qsCount = hand.where((c) => beziqueBaseCard(c) == 'QS').length;
  final jdCount = hand.where((c) => beziqueBaseCard(c) == 'JD').length;
  if (qsCount >= 2 && jdCount >= 2 && !declaredIds.contains('double_bezique')) {
    out.add({
      'id': 'double_bezique',
      'type': 'double_bezique',
      'points': 500,
      'title': '双倍贝济克 (2×♠Q+2×♦J · +500分)',
    });
  }

  // 2. Trump Sequence (A-T-K-Q-J of trumpSuit = 250 pts)
  final hasTrumpSeq = const ['A', 'T', 'K', 'Q', 'J']
      .every((r) => baseSet.contains('$r$trumpSuit'));
  if (hasTrumpSeq && !declaredIds.contains('trump_sequence')) {
    out.add({
      'id': 'trump_sequence',
      'type': 'trump_sequence',
      'suit': trumpSuit,
      'points': 250,
      'title': '主花色同花大顺 (${beziqueSuitNames[trumpSuit]} A-T-K-Q-J · +250分)',
    });
  }

  // 3. Four Aces (100), Four Kings (80), Four Queens (60), Four Jacks (40)
  for (final (rank, mType, pts, label) in const [
    ('A', 'four_aces', 100, '四王牌 (4张A · +100分)'),
    ('K', 'four_kings', 80, '四国王 (4张K · +80分)'),
    ('Q', 'four_queens', 60, '四王后 (4张Q · +60分)'),
    ('J', 'four_jacks', 40, '四卫兵 (4张J · +40分)'),
  ]) {
    final cnt = hand.where((c) => beziqueCardRank(c) == rank).length;
    if (cnt >= 4 && !declaredIds.contains(mType)) {
      out.add({
        'id': mType,
        'type': mType,
        'points': pts,
        'title': label,
      });
    }
  }

  // 4. Bezique (QS + JD = 40 pts)
  if (qsCount >= 1 && jdCount >= 1 && !declaredIds.contains('bezique')) {
    out.add({
      'id': 'bezique',
      'type': 'bezique',
      'points': 40,
      'title': '贝济克 Bezique (♠Q+♦J · +40分)',
    });
  }

  // 5. Royal Marriage (K + Q of trumpSuit = 40 pts) & Common Marriage (K + Q of non-trump = 20 pts)
  for (final s in beziqueSuits) {
    final hasMarriage = baseSet.contains('K$s') && baseSet.contains('Q$s');
    if (!hasMarriage) continue;
    if (s == trumpSuit) {
      if (!declaredIds.contains('royal_marriage')) {
        out.add({
          'id': 'royal_marriage',
          'type': 'royal_marriage',
          'suit': s,
          'points': 40,
          'title': '皇家联姻 (${beziqueSuitNames[s]} K+Q · +40分)',
        });
      }
    } else {
      final id = 'common_marriage_$s';
      if (!declaredIds.contains(id)) {
        out.add({
          'id': id,
          'type': 'common_marriage',
          'suit': s,
          'points': 20,
          'title': '普通联姻 (${beziqueSuitNames[s]} K+Q · +20分)',
        });
      }
    }
  }

  // 6. Dix (7 of trumpSuit = 10 pts)
  for (final c in hand) {
    if (beziqueBaseCard(c) == '7$trumpSuit') {
      final id = 'dix_$c';
      if (!declaredIds.contains(id) && !declaredIds.contains('dix')) {
        out.add({
          'id': id,
          'type': 'dix',
          'suit': trumpSuit,
          'card': c,
          'points': 10,
          'title': '主牌七 Dix (${beziqueSuitNames[trumpSuit]}7 · +10分)',
        });
        break;
      }
    }
  }

  out.sort((a, b) => asInt(b['points']).compareTo(asInt(a['points'])));
  return out;
}

class BeziqueGame extends GameEngine {
  late int totalRounds;
  int round = 1;
  int dealer = 0;
  int leader = 1;
  int turn = 1;
  String phase = 'play'; // 'play' | 'meld'

  String trumpCard = '7S_0';
  String trumpSuit = 'S';
  List<String> stock = [];

  late List<List<String>> hands;
  late List<int> scores;
  late List<int> handMeldPoints;
  late List<int> handBrisquePoints;
  late List<int> brisquesCount;
  late List<int> tricksWon;
  late List<Set<String>> declaredMelds;
  List<Map<String, dynamic>> meldLog = [];

  List<Map<String, dynamic>> trick = [];
  Map<String, dynamic>? lastTrick;
  Map<String, dynamic>? lastHandSummary;
  int trickNumber = 1;

  bool _over = false;
  List<int>? _placings;

  BeziqueGame(super.setup) {
    totalRounds = setup.opt<int>('rounds', 1);
    hands = List.generate(players, (_) => <String>[]);
    scores = List.filled(players, 0);
    handMeldPoints = List.filled(players, 0);
    handBrisquePoints = List.filled(players, 0);
    brisquesCount = List.filled(players, 0);
    tricksWon = List.filled(players, 0);
    declaredMelds = List.generate(players, (_) => <String>{});
  }

  int get stage => stock.isNotEmpty ? 1 : 2;

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
    final deck = shuffled(buildBeziqueDeck(), rng);
    hands[0] = deck.sublist(0, 8);
    hands[1] = deck.sublist(8, 16);
    stock = deck.sublist(16); // 48 cards; stock.last is the face-up trumpCard
    trumpCard = stock.last;
    trumpSuit = beziqueCardSuit(trumpCard);

    for (var s = 0; s < players; s++) {
      _sortHand(hands[s]);
      handMeldPoints[s] = 0;
      handBrisquePoints[s] = 0;
      brisquesCount[s] = 0;
      tricksWon[s] = 0;
      declaredMelds[s] = <String>{};
    }
    meldLog = [];
    trick = [];
    trickNumber = 1;
    phase = 'play';
    leader = (dealer + 1) % players;
    turn = leader;

    host.log('第 $round/$totalRounds 局开始：翻开王牌指示牌 ${beziqueBaseCard(trumpCard)}（主花色 ${beziqueSuitNames[trumpSuit]}）');
  }

  void _sortHand(List<String> hand) {
    hand.sort((a, b) {
      final ta = beziqueCardSuit(a) == trumpSuit;
      final tb = beziqueCardSuit(b) == trumpSuit;
      if (ta != tb) return ta ? -1 : 1;
      final sa = beziqueSuits.indexOf(beziqueCardSuit(a));
      final sb = beziqueSuits.indexOf(beziqueCardSuit(b));
      if (sa != sb) return sa.compareTo(sb);
      final ra = beziqueRankOrder(a);
      final rb = beziqueRankOrder(b);
      if (ra != rb) return rb.compareTo(ra);
      return a.compareTo(b);
    });
  }

  List<String> legalCards(int seat) => beziqueLegalCards(
        hands[seat],
        trick,
        trumpSuit,
        stockEmpty: stock.isEmpty,
      );

  List<Map<String, dynamic>> availableMeldsFor(int seat) {
    if (_over || stock.isEmpty) return const [];
    return beziqueAvailableMelds(hands[seat], trumpSuit, declaredMelds[seat]);
  }

  void _drawFromStockAfterTrick(int winner) {
    if (stock.length >= 2) {
      final loser = 1 - winner;
      hands[winner].add(stock.removeAt(0));
      hands[loser].add(stock.removeAt(0));
      _sortHand(hands[winner]);
      _sortHand(hands[loser]);
      if (stock.isEmpty) {
        host.log('牌库已摸空！进入第 2 阶段（最后 8 墩）：停止组合宣告，必须有花跟花且能大必大、无花必出主牌！');
      }
    } else {
      stock.clear();
    }
  }

  void _applyMeld(int seat, Map<String, dynamic> meldEntry) {
    final id = asStr(meldEntry['id']);
    final mType = asStr(meldEntry['type']);
    final pts = asInt(meldEntry['points'], 0);
    final title = asStr(meldEntry['title'], mType);

    declaredMelds[seat].add(id);
    if (mType == 'dix') {
      declaredMelds[seat].add('dix');
      final dixCard = asStr(meldEntry['card']);
      // Swap 7 of trumps with face-up trumpCard at bottom of stock if trumpCard is not already a 7
      if (dixCard.isNotEmpty &&
          hands[seat].contains(dixCard) &&
          stock.isNotEmpty &&
          beziqueCardRank(trumpCard) != '7') {
        final oldTrump = trumpCard;
        final idx = hands[seat].indexOf(dixCard);
        hands[seat][idx] = oldTrump;
        stock[stock.length - 1] = dixCard;
        trumpCard = dixCard;
        _sortHand(hands[seat]);
      }
    }

    handMeldPoints[seat] += pts;
    scores[seat] += pts;
    meldLog.add({
      'seat': seat,
      'id': id,
      'type': mType,
      'points': pts,
      'title': title,
    });
    host.log('${name(seat)} 宣告组合「$title」，获得 +$pts 分！');
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);

    if (type == 'meld') {
      if (stock.isEmpty) {
        throw GameError('牌库已空（第 2 阶段），不能再宣告组合');
      }
      if (trick.isNotEmpty) {
        throw GameError('墩进行中不能宣告组合');
      }
      final avail = availableMeldsFor(seat);
      if (avail.isEmpty) {
        throw GameError('手中没有可宣告的组合');
      }
      final requested = asStr(action['meld']);
      Map<String, dynamic>? chosen;
      if (requested.isEmpty) {
        chosen = avail.first;
      } else {
        for (final m in avail) {
          if (m['id'] == requested || m['type'] == requested) {
            chosen = m;
            break;
          }
        }
      }
      if (chosen == null) {
        throw GameError('无效或已宣告过的组合：$requested');
      }

      _applyMeld(seat, chosen);
      if (phase == 'meld') {
        _drawFromStockAfterTrick(seat);
        phase = 'play';
      }
      return;
    }

    if (phase == 'meld' && (type == 'skip_meld' || type == 'pass')) {
      _drawFromStockAfterTrick(seat);
      phase = 'play';
      return;
    }

    if (type == 'play') {
      if (phase == 'meld') {
        // Allow playing directly from 'meld' phase by auto-completing the draw first
        // if the card is already in hand, or require resolving meld first
        _drawFromStockAfterTrick(seat);
        phase = 'play';
      }

      final card = asStr(action['card']);
      if (!hands[seat].contains(card)) {
        throw GameError('手牌中没有该张牌');
      }
      final legal = legalCards(seat);
      if (!legal.contains(card)) {
        throw GameError('第 2 阶段必须跟出领出花色且能大必大（若无领出花色则必须出主牌）');
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
    final winner = beziqueTrickWinner(trick, trumpSuit);
    var brisquesInTrick = 0;
    var brisquePts = 0;
    for (final e in trick) {
      final bp = beziqueBrisquePoints(asStr(e['card']));
      if (bp > 0) {
        brisquesInTrick += 1;
        brisquePts += bp;
      }
    }

    tricksWon[winner] += 1;
    if (brisquePts > 0) {
      brisquesCount[winner] += brisquesInTrick;
      handBrisquePoints[winner] += brisquePts;
      scores[winner] += brisquePts;
    }

    final isFinalTrick = stock.isEmpty && hands.every((h) => h.isEmpty);
    if (isFinalTrick) {
      handBrisquePoints[winner] += 10;
      scores[winner] += 10;
    }

    lastTrick = {
      'trickNumber': trickNumber,
      'winner': winner,
      'brisques': brisquesInTrick,
      'points': brisquePts + (isFinalTrick ? 10 : 0),
      'finalTrickBonus': isFinalTrick,
      'cards': [for (final e in trick) Map<String, dynamic>.of(e)],
    };

    trick = [];
    leader = winner;
    turn = winner;
    trickNumber += 1;

    if (isFinalTrick) {
      _finishRound(lastTrickWinner: winner);
      return;
    }

    if (stock.isNotEmpty) {
      // Check if winner can declare a meld before drawing from stock
      final avail = availableMeldsFor(winner);
      if (avail.isNotEmpty) {
        phase = 'meld';
        return;
      }
      _drawFromStockAfterTrick(winner);
    }
    phase = 'play';
  }

  void _finishRound({required int lastTrickWinner}) {
    lastHandSummary = {
      'round': round,
      'trumpSuit': trumpSuit,
      'trumpCard': trumpCard,
      'handMeldPoints': List<int>.of(handMeldPoints),
      'handBrisquePoints': List<int>.of(handBrisquePoints),
      'brisquesCount': List<int>.of(brisquesCount),
      'tricksWon': List<int>.of(tricksWon),
      'lastTrickWinner': lastTrickWinner,
      'scores': List<int>.of(scores),
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

  /// Cards the bot wants to protect in Stage 1 for high-value melds (`QS`, `JD`, `K/Q/A`).
  bool _isMeldKeyCard(String card) {
    final base = beziqueBaseCard(card);
    if (base == 'QS' || base == 'JD') return true;
    final r = beziqueCardRank(card);
    if (r == 'A' || r == 'K' || r == 'Q') return true;
    if (beziqueCardSuit(card) == trumpSuit && (r == 'T' || r == 'J' || r == '7')) {
      return true;
    }
    return false;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    if (phase == 'meld') {
      final avail = availableMeldsFor(seat);
      if (avail.isNotEmpty) {
        return {'type': 'meld', 'meld': avail.first['id']};
      }
      return {'type': 'skip_meld'};
    }

    final legal = legalCards(seat);
    if (legal.isEmpty) return null;

    if (botLevel == 0) {
      return {'type': 'play', 'card': legal[rng.nextInt(legal.length)]};
    }

    if (stock.isNotEmpty) {
      // Stage 1: protect meld cards when possible; win trick if Brisque (A or T) was led
      if (trick.isNotEmpty) {
        final leadCard = asStr(trick.first['card']);
        final leadIsBrisque = beziqueBrisquePoints(leadCard) > 0;
        if (leadIsBrisque) {
          final leadSuit = beziqueCardSuit(leadCard);
          final leadStr = beziqueCardStrength(leadCard, trumpSuit, leadSuit);
          final winners = legal
              .where((c) => beziqueCardStrength(c, trumpSuit, leadSuit) > leadStr)
              .toList();
          if (winners.isNotEmpty) {
            winners.sort((a, b) => beziqueCardStrength(a, trumpSuit, leadSuit)
                .compareTo(beziqueCardStrength(b, trumpSuit, leadSuit)));
            return {'type': 'play', 'card': winners.first};
          }
        }
      }
      // Otherwise throw lowest non-meld, non-brisque card
      final expendable = legal
          .where((c) => !_isMeldKeyCard(c) && beziqueBrisquePoints(c) == 0)
          .toList();
      if (expendable.isNotEmpty) {
        expendable.sort((a, b) => beziqueRankOrder(a).compareTo(beziqueRankOrder(b)));
        return {'type': 'play', 'card': expendable.first};
      }
      final sorted = List<String>.of(legal)
        ..sort((a, b) => beziqueRankOrder(a).compareTo(beziqueRankOrder(b)));
      return {'type': 'play', 'card': sorted.first};
    }

    // Stage 2: strict trick play — lead high or win trick if able
    final sortedDesc = List<String>.of(legal)
      ..sort((a, b) => beziqueRankOrder(b).compareTo(beziqueRankOrder(a)));
    return {'type': 'play', 'card': sortedDesc.first};
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myLegal = (seat >= 0 && seat < players && seat == turn && phase == 'play')
        ? legalCards(seat)
        : <String>[];
    final myMelds = (seat >= 0 && seat < players && seat == turn)
        ? availableMeldsFor(seat)
        : const <Map<String, dynamic>>[];

    return {
      'round': round,
      'totalRounds': totalRounds,
      'stage': stage,
      'phase': phase,
      'dealer': dealer,
      'leader': leader,
      'turn': turn,
      'trumpCard': trumpCard,
      'trumpSuit': trumpSuit,
      'trumpSuitName': beziqueSuitNames[trumpSuit] ?? trumpSuit,
      'stockCount': stock.length,
      'trickNumber': trickNumber,
      'scores': List<int>.of(scores),
      'handMeldPoints': List<int>.of(handMeldPoints),
      'handBrisquePoints': List<int>.of(handBrisquePoints),
      'brisquesCount': List<int>.of(brisquesCount),
      'tricksWon': List<int>.of(tricksWon),
      'meldLog': [for (final e in meldLog) Map<String, dynamic>.of(e)],
      'handCounts': [for (final h in hands) h.length],
      'hand': (seat >= 0 && seat < players) ? List<String>.of(hands[seat]) : <String>[],
      'legal': myLegal,
      'availableMelds': myMelds,
      'trick': [for (final e in trick) Map<String, dynamic>.of(e)],
      'lastTrick': lastTrick,
      'lastHandSummary': lastHandSummary,
      'over': _over,
      'placings': _placings,
    };
  }
}
