import '../../src/engine.dart';

const List<int> geishaCharms = [2, 2, 2, 3, 3, 4, 5];

const List<String> geishaNames = [
  '红扇艺伎',
  '画卷艺伎',
  '纸伞艺伎',
  '茶道艺伎',
  '折笛艺伎',
  '三味线艺伎',
  '花冠艺伎',
];

const List<String> geishaItems = [
  '折扇',
  '画卷',
  '纸伞',
  '茶碗',
  '横笛',
  '三味线',
  '花冠',
];

const List<String> hanamikojiActionNames = [
  '密约 (1张暗置)',
  '取舍 (2张弃置)',
  '赠予 (3选1)',
  '竞争 (2对选1)',
];

List<int> buildHanamikojiDeck() => [
      for (var g = 0; g < geishaCharms.length; g++)
        for (var k = 0; k < geishaCharms[g]; k++) g,
    ];

class HanamikojiGame extends GameEngine {
  int round = 1;
  int maxRounds = 4;
  int startPlayer = 0;
  int turn = 0;
  int offerFrom = -1;
  String phase = 'action'; // 'action' | 'pick_gift' | 'pick_pair'

  /// Geisha favor markers: -1 = neutral, 0 = seat 0, 1 = seat 1.
  List<int> favor = List.filled(7, -1);

  /// Played item counts per seat for each Geisha 0..6 in the current round.
  late List<List<int>> played;

  /// Remaining action tokens per seat: [secret, discard, gift, compete].
  late List<List<bool>> actionsLeft;

  /// Player hands (list of Geisha indices 0..6).
  late List<List<int>> hands;

  /// Reserved secret card per seat (revealed at round end).
  List<int?> secretCard = [null, null];

  /// Secretly discarded cards per seat (2 cards each).
  List<List<int>> discardedCards = [[], []];

  /// Current Gift offer (3 Geisha card IDs) when phase == 'pick_gift'.
  List<int> giftOffer = [];

  /// Current Competition offer (2 pairs of Geisha card IDs) when phase == 'pick_pair'.
  List<List<int>> competePairs = [];

  List<int> deck = [];
  int? removedCard;

  Map<String, dynamic>? lastRoundSummary;
  Map<String, dynamic>? lastActionInfo;

  bool _over = false;
  List<int>? _placings;
  int? winner;
  String? winReason;

  HanamikojiGame(super.setup) {
    maxRounds = setup.opt<int>('maxRounds', 4);
    played = [List.filled(7, 0), List.filled(7, 0)];
    actionsLeft = [
      [true, true, true, true],
      [true, true, true, true],
    ];
    hands = [<int>[], <int>[]];
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
    winner = 1 - seat;
    winReason = '${name(seat)} 认输';
    _placings = rankWinners(players, [1 - seat]);
    host.log('${name(seat)} 认输，${name(1 - seat)} 获胜');
  }

  int geishaCountFor(int seat) =>
      favor.where((f) => f == seat).length;

  int charmPointsFor(int seat) {
    var sum = 0;
    for (var g = 0; g < 7; g++) {
      if (favor[g] == seat) sum += geishaCharms[g];
    }
    return sum;
  }

  @override
  void start() {
    _startRound();
  }

  void _startRound() {
    deck = shuffled(buildHanamikojiDeck(), rng);
    removedCard = deck.removeLast(); // 1 card removed unseen (20 left)
    hands = [
      deck.sublist(0, 6)..sort(),
      deck.sublist(6, 12)..sort(),
    ];
    deck = deck.sublist(12); // 8 cards left for 8 turns
    played = [List.filled(7, 0), List.filled(7, 0)];
    actionsLeft = [
      [true, true, true, true],
      [true, true, true, true],
    ];
    secretCard = [null, null];
    discardedCards = [<int>[], <int>[]];
    giftOffer = [];
    competePairs = [];
    offerFrom = -1;
    turn = startPlayer;
    phase = 'action';
    // Active player draws 1 card at the start of their turn (now 7 cards in hand)
    if (deck.isNotEmpty) {
      hands[turn].add(deck.removeLast());
      hands[turn].sort();
    }
    host.log('第 $round 回合开始，移除 1 张暗牌，${name(turn)} 先手抽牌行动');
  }

  List<int> _extractByIndices(int seat, List<int> indices, int expectedCount) {
    if (indices.length != expectedCount) {
      throw GameError('需要选择 $expectedCount 张手牌');
    }
    final unique = indices.toSet();
    if (unique.length != expectedCount) {
      throw GameError('不能重复选择同一张手牌');
    }
    final hand = hands[seat];
    for (final idx in indices) {
      if (idx < 0 || idx >= hand.length) {
        throw GameError('手牌索引越界：$idx');
      }
    }
    final chosen = [for (final idx in indices) hand[idx]];
    final sortedDesc = List<int>.of(indices)..sort((a, b) => b.compareTo(a));
    for (final idx in sortedDesc) {
      hand.removeAt(idx);
    }
    return chosen;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);

    if (phase == 'action') {
      if (type == 'secret') {
        if (!actionsLeft[seat][0]) throw GameError('本回合已使用过「密约」行动');
        var idx = asInt(action['cardIdx'], -1);
        if (idx < 0 && action['index'] != null) {
          idx = asInt(action['index'], -1);
        }
        if (idx < 0 && action['card'] != null) {
          idx = hands[seat].indexOf(asInt(action['card'], -1));
        }
        final picked = _extractByIndices(seat, [idx], 1);
        secretCard[seat] = picked.first;
        actionsLeft[seat][0] = false;
        lastActionInfo = {'seat': seat, 'type': 'secret'};
        host.log('${name(seat)} 执行了「密约」，暗置保留 1 张礼物牌');
        _advanceAfterTurn(seat);
        return;
      }

      if (type == 'discard') {
        if (!actionsLeft[seat][1]) throw GameError('本回合已使用过「取舍」行动');
        final indices = asIntList(action['cards']);
        final picked = _extractByIndices(seat, indices, 2);
        discardedCards[seat] = picked;
        actionsLeft[seat][1] = false;
        lastActionInfo = {'seat': seat, 'type': 'discard'};
        host.log('${name(seat)} 执行了「取舍」，暗置弃除 2 张礼物牌');
        _advanceAfterTurn(seat);
        return;
      }

      if (type == 'gift') {
        if (!actionsLeft[seat][2]) throw GameError('本回合已使用过「赠予」行动');
        final indices = asIntList(action['cards']);
        final picked = _extractByIndices(seat, indices, 3);
        giftOffer = picked;
        actionsLeft[seat][2] = false;
        offerFrom = seat;
        phase = 'pick_gift';
        turn = 1 - seat;
        lastActionInfo = {
          'seat': seat,
          'type': 'gift',
          'cards': List<int>.of(picked),
        };
        host.log('${name(seat)} 执行了「赠予」，亮出 3 张牌请 ${name(turn)} 挑选 1 张');
        return;
      }

      if (type == 'compete') {
        if (!actionsLeft[seat][3]) throw GameError('本回合已使用过「竞争」行动');
        final pairA = asIntList(action['pairA']);
        final pairB = asIntList(action['pairB']);
        if (pairA.length != 2 || pairB.length != 2) {
          throw GameError('「竞争」必须将 4 张手牌分为两对（每对 2 张）');
        }
        final allFour = [...pairA, ...pairB];
        final extracted = _extractByIndices(seat, allFour, 4);
        competePairs = [
          [extracted[0], extracted[1]],
          [extracted[2], extracted[3]],
        ];
        actionsLeft[seat][3] = false;
        offerFrom = seat;
        phase = 'pick_pair';
        turn = 1 - seat;
        lastActionInfo = {
          'seat': seat,
          'type': 'compete',
          'pairA': List<int>.of(competePairs[0]),
          'pairB': List<int>.of(competePairs[1]),
        };
        host.log('${name(seat)} 执行了「竞争」，将 4 张牌分为两对请 ${name(turn)} 挑选 1 对');
        return;
      }

      throw GameError('未知的行动类型：$type');
    }

    if (phase == 'pick_gift') {
      if (type != 'pick_gift') throw GameError('请从「赠予」的 3 张牌中选择 1 张');
      final idx = asInt(action['index'], -1);
      if (idx < 0 || idx >= giftOffer.length) {
        throw GameError('无效的选择索引：$idx');
      }
      final chosenCard = giftOffer[idx];
      played[seat][chosenCard] += 1;
      final remaining = <int>[];
      for (var i = 0; i < giftOffer.length; i++) {
        if (i != idx) {
          played[offerFrom][giftOffer[i]] += 1;
          remaining.add(giftOffer[i]);
        }
      }
      lastActionInfo = {
        'seat': seat,
        'type': 'pick_gift',
        'picked': chosenCard,
        'remaining': remaining,
        'offerFrom': offerFrom,
      };
      host.log('${name(seat)} 从赠予中挑选了「${geishaItems[chosenCard]}」，其余 2 张归 ${name(offerFrom)}');
      final completedSeat = offerFrom;
      giftOffer = [];
      offerFrom = -1;
      _advanceAfterTurn(completedSeat);
      return;
    }

    if (phase == 'pick_pair') {
      if (type != 'pick_pair') throw GameError('请从「竞争」的两对牌中选择 1 对');
      final p = action['pair'] != null ? asInt(action['pair'], -1) : asInt(action['index'], -1);
      if (p != 0 && p != 1) {
        throw GameError('无效的对子选择：$p');
      }
      final chosenPair = competePairs[p];
      final otherPair = competePairs[1 - p];
      for (final c in chosenPair) {
        played[seat][c] += 1;
      }
      for (final c in otherPair) {
        played[offerFrom][c] += 1;
      }
      lastActionInfo = {
        'seat': seat,
        'type': 'pick_pair',
        'pickedPair': List<int>.of(chosenPair),
        'otherPair': List<int>.of(otherPair),
        'offerFrom': offerFrom,
      };
      host.log('${name(seat)} 选择了第 ${p + 1} 对牌，另一对归 ${name(offerFrom)}');
      final completedSeat = offerFrom;
      competePairs = [];
      offerFrom = -1;
      _advanceAfterTurn(completedSeat);
      return;
    }

    throw GameError('未知阶段');
  }

  void _advanceAfterTurn(int completedSeat) {
    final p0Done = actionsLeft[0].every((x) => !x);
    final p1Done = actionsLeft[1].every((x) => !x);
    if (p0Done && p1Done) {
      resolveRound();
      return;
    }
    final nextSeat = 1 - completedSeat;
    turn = actionsLeft[nextSeat].any((x) => x) ? nextSeat : completedSeat;
    phase = 'action';
    if (deck.isNotEmpty) {
      hands[turn].add(deck.removeLast());
      hands[turn].sort();
    }
  }

  /// Resolves end of round: reveals secret cards, updates Geisha favor,
  /// and checks victory conditions (>= 11 Charm or >= 4 Geishas).
  void resolveRound() {
    final revealedSecrets = [secretCard[0], secretCard[1]];
    for (var s = 0; s < 2; s++) {
      final sc = secretCard[s];
      if (sc != null && sc >= 0 && sc < 7) {
        played[s][sc] += 1;
      }
    }

    for (var g = 0; g < 7; g++) {
      if (played[0][g] > played[1][g]) {
        favor[g] = 0;
      } else if (played[1][g] > played[0][g]) {
        favor[g] = 1;
      }
      // Ties leave favor[g] unchanged!
    }

    final c0 = charmPointsFor(0);
    final c1 = charmPointsFor(1);
    final g0 = geishaCountFor(0);
    final g1 = geishaCountFor(1);

    lastRoundSummary = {
      'round': round,
      'revealedSecrets': revealedSecrets,
      'played': [List<int>.of(played[0]), List<int>.of(played[1])],
      'favor': List<int>.of(favor),
      'charmPoints': [c0, c1],
      'geishaCounts': [g0, g1],
    };

    host.log('第 $round 回合结算：${name(0)} 控制 $g0 位艺伎($c0 魅力)，${name(1)} 控制 $g1 位艺伎($c1 魅力)');

    // Check immediate victory conditions:
    // 1. >= 11 Charm points (at most one player can have >= 11 out of 21)
    // 2. >= 4 Geishas (at most one player can have >= 4 out of 7)
    int? roundWinner;
    String? reason;
    if (c0 >= 11) {
      roundWinner = 0;
      reason = '获得 $c0 点魅力值（≥11）';
    } else if (c1 >= 11) {
      roundWinner = 1;
      reason = '获得 $c1 点魅力值（≥11）';
    } else if (g0 >= 4) {
      roundWinner = 0;
      reason = '赢得 $g0 位艺伎青睐（≥4）';
    } else if (g1 >= 4) {
      roundWinner = 1;
      reason = '赢得 $g1 位艺伎青睐（≥4）';
    } else if (round >= maxRounds) {
      if (c0 != c1) {
        roundWinner = c0 > c1 ? 0 : 1;
        reason = '满回合魅力值领先（$c0 vs $c1）';
      } else if (g0 != g1) {
        roundWinner = g0 > g1 ? 0 : 1;
        reason = '满回合艺伎数领先（$g0 vs $g1）';
      } else {
        roundWinner = 0;
        reason = '满回合平局裁定';
      }
    }

    if (roundWinner != null) {
      _over = true;
      winner = roundWinner;
      winReason = reason;
      _placings = rankWinners(players, [roundWinner]);
      host.log('${name(roundWinner)} 获胜（$reason）！');
      return;
    }

    round += 1;
    startPlayer = 1 - startPlayer;
    _startRound();
  }

  int _cardEval(int seat, int g) {
    final myPlayed = played[seat][g];
    final oppPlayed = played[1 - seat][g];
    final charm = geishaCharms[g];
    final diff = myPlayed - oppPlayed;
    if (diff == 0) return charm * 3 + (favor[g] == seat ? 2 : 4);
    if (diff == -1) return charm * 3;
    if (diff == 1) return charm * 2;
    return charm;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    if (phase == 'pick_gift') {
      var bestIdx = 0;
      var bestScore = -1;
      for (var i = 0; i < giftOffer.length; i++) {
        final s = _cardEval(seat, giftOffer[i]);
        if (s > bestScore) {
          bestScore = s;
          bestIdx = i;
        }
      }
      return {'type': 'pick_gift', 'index': bestIdx};
    }

    if (phase == 'pick_pair') {
      final s0 = _cardEval(seat, competePairs[0][0]) + _cardEval(seat, competePairs[0][1]);
      final s1 = _cardEval(seat, competePairs[1][0]) + _cardEval(seat, competePairs[1][1]);
      return {'type': 'pick_pair', 'pair': s1 > s0 ? 1 : 0};
    }

    if (phase == 'action') {
      final hand = hands[seat];
      final acts = actionsLeft[seat];
      // Rank hand indices by card evaluation descending
      final idxByValue = [for (var i = 0; i < hand.length; i++) i]
        ..sort((a, b) => _cardEval(seat, hand[b]).compareTo(_cardEval(seat, hand[a])));

      if (acts[0] && hand.isNotEmpty && (botLevel > 0 || !acts[1])) {
        // Reserve highest value card in Secret
        return {'type': 'secret', 'cardIdx': idxByValue.first};
      }
      if (acts[2] && hand.length >= 3) {
        return {
          'type': 'gift',
          'cards': [idxByValue[0], idxByValue[1], idxByValue[2]],
        };
      }
      if (acts[3] && hand.length >= 4) {
        // Split top 4 into balanced pairs: (0, 3) and (1, 2)
        return {
          'type': 'compete',
          'pairA': [idxByValue[0], idxByValue[3]],
          'pairB': [idxByValue[1], idxByValue[2]],
        };
      }
      if (acts[1] && hand.length >= 2) {
        // Discard 2 lowest value cards
        final n = idxByValue.length;
        return {
          'type': 'discard',
          'cards': [idxByValue[n - 1], idxByValue[n - 2]],
        };
      }
      if (acts[0] && hand.isNotEmpty) {
        return {'type': 'secret', 'cardIdx': idxByValue.first};
      }
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'round': round,
      'maxRounds': maxRounds,
      'turn': turn,
      'phase': phase,
      'offerFrom': offerFrom,
      'favor': List<int>.of(favor),
      'geishaCharms': geishaCharms,
      'geishaNames': geishaNames,
      'geishaItems': geishaItems,
      'played': [List<int>.of(played[0]), List<int>.of(played[1])],
      'actionsLeft': [List<bool>.of(actionsLeft[0]), List<bool>.of(actionsLeft[1])],
      'handCounts': [hands[0].length, hands[1].length],
      'hand': (seat >= 0 && seat < 2) ? List<int>.of(hands[seat]) : <int>[],
      'hasSecret': [secretCard[0] != null, secretCard[1] != null],
      'mySecret': (seat >= 0 && seat < 2) ? secretCard[seat] : null,
      'hasDiscarded': [discardedCards[0].isNotEmpty, discardedCards[1].isNotEmpty],
      'myDiscarded': (seat >= 0 && seat < 2) ? List<int>.of(discardedCards[seat]) : <int>[],
      'giftOffer': List<int>.of(giftOffer),
      'competePairs': [for (final p in competePairs) List<int>.of(p)],
      'deckCount': deck.length,
      'charmPoints': [charmPointsFor(0), charmPointsFor(1)],
      'geishaCounts': [geishaCountFor(0), geishaCountFor(1)],
      'lastActionInfo': lastActionInfo,
      'lastRoundSummary': lastRoundSummary,
      'over': _over,
      'winner': winner,
      'winReason': winReason,
      'placings': _placings,
    };
  }
}
