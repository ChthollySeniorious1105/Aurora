import '../../src/engine.dart';

const List<String> scopaSuits = ['D', 'H', 'S', 'C'];
const List<String> scopaRanks = [
  'A',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  'J',
  'Q',
  'K',
];

const Map<String, int> scopaCardValues = {
  'A': 1,
  '2': 2,
  '3': 3,
  '4': 4,
  '5': 5,
  '6': 6,
  '7': 7,
  'J': 8,
  'Q': 9,
  'K': 10,
};

const Map<String, int> scopaPrimieraValues = {
  '7': 21,
  '6': 18,
  'A': 16,
  '5': 15,
  '4': 14,
  '3': 13,
  '2': 12,
  'J': 10,
  'Q': 10,
  'K': 10,
};

int scopaValue(String card) => scopaCardValues[card[0]] ?? 0;
int scopaPrimieraVal(String card) => scopaPrimieraValues[card[0]] ?? 0;
String scopaRank(String card) => card[0];
String scopaSuit(String card) => card[1];

List<String> buildScopaDeck() => [
      for (final s in scopaSuits)
        for (final r in scopaRanks) '$r$s',
    ];

int calcPrimiera(List<String> capturedCards) {
  var total = 0;
  for (final s in scopaSuits) {
    var best = 0;
    for (final c in capturedCards) {
      if (scopaSuit(c) == s) {
        final v = scopaPrimieraVal(c);
        if (v > best) best = v;
      }
    }
    total += best;
  }
  return total;
}

/// Returns all legal capture subsets of [tableCards] for playing [card].
/// If any single card on the table matches [card]'s value, ONLY single-card
/// captures are legal. Otherwise, all subsets of size >= 2 summing to [card]'s
/// value are returned. Returns an empty list if no capture is possible.
List<List<String>> legalScopaCaptures(String card, List<String> tableCards) {
  final target = scopaValue(card);
  final singles = <List<String>>[
    for (final t in tableCards)
      if (scopaValue(t) == target) [t],
  ];
  if (singles.isNotEmpty) return singles;

  final results = <List<String>>[];
  final n = tableCards.length;
  void dfs(int idx, int currentSum, List<String> chosen) {
    if (currentSum == target && chosen.length >= 2) {
      results.add(List<String>.of(chosen));
      return;
    }
    if (idx >= n || currentSum >= target) return;
    for (var i = idx; i < n; i++) {
      final c = tableCards[i];
      final v = scopaValue(c);
      if (currentSum + v <= target) {
        chosen.add(c);
        dfs(i + 1, currentSum + v, chosen);
        chosen.removeLast();
      }
    }
  }

  dfs(0, 0, []);
  return results;
}

class ScopaGame extends GameEngine {
  late final int targetScore;

  List<int> scores = [];
  int handNumber = 0;
  int dealer = 0;
  int turn = 0;

  List<String> deck = [];
  List<String> table = [];
  List<List<String>> hands = [];
  List<List<String>> captured = [];
  List<int> scopas = [];
  int? lastCapturer;

  Map<String, dynamic>? lastMove;
  Map<String, dynamic>? lastHandSummary;
  Map<String, dynamic>? result;
  bool over = false;
  int? resignedSeat;

  ScopaGame(super.setup) {
    targetScore = setup.opt<int>('targetScore', 11);
    scores = List<int>.filled(players, 0);
    hands = List.generate(players, (_) => <String>[]);
    captured = List.generate(players, (_) => <String>[]);
    scopas = List<int>.filled(players, 0);
  }

  @override
  void start() {
    dealer = 0;
    _startNewHand();
  }

  void _startNewHand() {
    handNumber++;
    List<String> d;
    while (true) {
      d = shuffled(buildScopaDeck(), rng);
      final initialTable = d.sublist(0, 4);
      final kings = initialTable.where((c) => scopaRank(c) == 'K').length;
      if (kings < 3) break;
    }
    table = d.sublist(0, 4);
    deck = d.sublist(4);
    hands = List.generate(players, (_) => <String>[]);
    captured = List.generate(players, (_) => <String>[]);
    scopas = List<int>.filled(players, 0);
    lastCapturer = null;
    lastMove = null;
    turn = (dealer + 1) % players;
    _dealRoundOfCards();
  }

  void _dealRoundOfCards() {
    for (var i = 0; i < players; i++) {
      final s = (dealer + 1 + i) % players;
      final count = deck.length >= 3 ? 3 : deck.length;
      if (count > 0) {
        hands[s].addAll(deck.sublist(0, count));
        deck.removeRange(0, count);
        hands[s].sort((a, b) => scopaValue(a).compareTo(scopaValue(b)));
      }
    }
  }

  static bool _sameCardSet(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sa = List<String>.of(a)..sort();
    final sb = List<String>.of(b)..sort();
    for (var i = 0; i < sa.length; i++) {
      if (sa[i] != sb[i]) return false;
    }
    return true;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你出牌');

    final type = asStr(action['type']);
    if (type != 'play') throw GameError('未知操作: $type');

    final card = asStr(action['card']);
    if (!hands[seat].contains(card)) {
      throw GameError('手牌中没有该张牌');
    }

    final rawCap = action['capture'];
    final cap = rawCap is List
        ? [for (final x in rawCap) asStr(x)]
        : <String>[];

    final validCaptures = legalScopaCaptures(card, table);
    var scoredScopa = false;

    if (validCaptures.isNotEmpty) {
      final match = validCaptures.any((v) => _sameCardSet(v, cap));
      if (!match) {
        if (validCaptures.first.length == 1) {
          throw GameError('桌面有同点数单牌，必须优先吃单张同点数牌');
        }
        throw GameError('必须吃掉桌面上点数之和等于 ${scopaValue(card)} 的合法牌组');
      }
      hands[seat].remove(card);
      for (final c in cap) {
        table.remove(c);
      }
      captured[seat].add(card);
      captured[seat].addAll(cap);
      lastCapturer = seat;

      final isVeryLastCard =
          deck.isEmpty && hands.every((h) => h.isEmpty);
      if (table.isEmpty && !isVeryLastCard) {
        scopas[seat]++;
        scoredScopa = true;
        host.log('${name(seat)} 用 $card 清台（Scopa! +1分）');
      }
    } else {
      if (cap.isNotEmpty) {
        throw GameError('该牌无法吃掉所选的桌面牌');
      }
      hands[seat].remove(card);
      table.add(card);
    }

    lastMove = {
      'seat': seat,
      'card': card,
      'captured': cap,
      'scopa': scoredScopa,
    };

    if (hands.every((h) => h.isEmpty)) {
      if (deck.isNotEmpty) {
        _dealRoundOfCards();
        turn = (seat + 1) % players;
      } else {
        finishHand();
      }
    } else {
      turn = (seat + 1) % players;
    }
  }

  void finishHand() {
    if (table.isNotEmpty && lastCapturer != null) {
      captured[lastCapturer!].addAll(table);
      table.clear();
    }

    final cardCounts = [for (var s = 0; s < players; s++) captured[s].length];
    final coinCounts = [
      for (var s = 0; s < players; s++)
        captured[s].where((c) => scopaSuit(c) == 'D').length,
    ];
    final settebelloWinner = [
      for (var s = 0; s < players; s++)
        if (captured[s].contains('7D')) s,
    ];
    final primieraScores = [
      for (var s = 0; s < players; s++) calcPrimiera(captured[s]),
    ];

    int? uniqueMaxWinner(List<int> vals) {
      var maxVal = 0;
      for (final v in vals) {
        if (v > maxVal) maxVal = v;
      }
      if (maxVal <= 0) return null;
      final winners = [
        for (var i = 0; i < vals.length; i++)
          if (vals[i] == maxVal) i,
      ];
      return winners.length == 1 ? winners.first : null;
    }

    final mostCardsWinner = uniqueMaxWinner(cardCounts);
    final mostCoinsWinner = uniqueMaxWinner(coinCounts);
    final sevenCoinsWinner =
        settebelloWinner.isNotEmpty ? settebelloWinner.first : null;
    final primieraWinner = uniqueMaxWinner(primieraScores);

    final gained = List<int>.filled(players, 0);
    if (mostCardsWinner != null) gained[mostCardsWinner] += 1;
    if (mostCoinsWinner != null) gained[mostCoinsWinner] += 1;
    if (sevenCoinsWinner != null) gained[sevenCoinsWinner] += 1;
    if (primieraWinner != null) gained[primieraWinner] += 1;
    for (var s = 0; s < players; s++) {
      gained[s] += scopas[s];
      scores[s] += gained[s];
    }

    lastHandSummary = {
      'hand': handNumber,
      'cardCounts': cardCounts,
      'coinCounts': coinCounts,
      'primieraScores': primieraScores,
      'scopas': List<int>.of(scopas),
      'mostCardsWinner': mostCardsWinner,
      'mostCoinsWinner': mostCoinsWinner,
      'settebelloWinner': sevenCoinsWinner,
      'primieraWinner': primieraWinner,
      'gained': gained,
      'scores': List<int>.of(scores),
    };

    host.log('第$handNumber局结算：各家得分 +$gained，总分 $scores');

    if (scores.any((x) => x >= targetScore)) {
      over = true;
      var best = scores[0];
      for (final sc in scores) {
        if (sc > best) best = sc;
      }
      final winners = [
        for (var s = 0; s < players; s++)
          if (scores[s] == best) s,
      ];
      result = {
        'winners': winners,
        'scores': List<int>.of(scores),
        'lastHand': lastHandSummary,
      };
      return;
    }

    dealer = (dealer + 1) % players;
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
      return rankWinners(
        players,
        [for (var i = 0; i < players; i++) if (i != resignedSeat) i],
      );
    }
    return rankByScore(scores);
  }

  @override
  bool get canResign => !over;

  @override
  void resign(int seat) {
    if (over) throw GameError('游戏已结束');
    resignedSeat = seat;
    over = true;
    final winners = [for (var i = 0; i < players; i++) if (i != seat) i];
    result = {
      'winners': winners,
      'resigned': seat,
      'scores': List<int>.of(scores),
    };
    host.log('${name(seat)} 认输');
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    final h = hands[seat];
    if (h.isEmpty) return null;

    if (botLevel == 0) {
      final c = h[rng.nextInt(h.length)];
      final caps = legalScopaCaptures(c, table);
      return {
        'type': 'play',
        'card': c,
        'capture': caps.isEmpty ? <String>[] : caps[rng.nextInt(caps.length)],
      };
    }

    // Score each possible move (card, capture)
    String? bestCard;
    List<String> bestCap = const [];
    var bestScore = -999999;

    for (final c in h) {
      final caps = legalScopaCaptures(c, table);
      if (caps.isEmpty) {
        // Trailing a card: avoid trailing 7s or Coins, and avoid leaving table sum <= 10
        var s = 0;
        if (c == '7D') s -= 50;
        if (scopaRank(c) == '7') s -= 20;
        if (scopaSuit(c) == 'D') s -= 10;
        final newSum =
            table.fold<int>(0, (a, b) => a + scopaValue(b)) + scopaValue(c);
        if (newSum <= 10) s -= 25;
        if (s > bestScore) {
          bestScore = s;
          bestCard = c;
          bestCap = const [];
        }
      } else {
        for (final cap in caps) {
          final all = [c, ...cap];
          var s = 100 + all.length * 10;
          if (cap.length == table.length) s += 200; // Scopa!
          if (all.contains('7D')) s += 150;
          for (final x in all) {
            if (scopaSuit(x) == 'D') s += 25;
            if (scopaRank(x) == '7') s += 30;
            if (scopaRank(x) == '6') s += 15;
          }
          if (s > bestScore) {
            bestScore = s;
            bestCard = c;
            bestCap = cap;
          }
        }
      }
    }

    return {
      'type': 'play',
      'card': bestCard ?? h.first,
      'capture': bestCap,
    };
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myHand =
        (seat >= 0 && seat < players) ? List<String>.of(hands[seat]) : <String>[];
    final capturesMap = <String, List<List<String>>>{};
    if (seat >= 0 && seat < players) {
      for (final c in myHand) {
        capturesMap[c] = legalScopaCaptures(c, table);
      }
    }
    return {
      'targetScore': targetScore,
      'scores': List<int>.of(scores),
      'handNumber': handNumber,
      'dealer': dealer,
      'turn': turn,
      'deckCount': deck.length,
      'table': List<String>.of(table),
      'hand': myHand,
      'handCounts': [for (final h in hands) h.length],
      'capturedCounts': [for (final c in captured) c.length],
      'coinCounts': [
        for (final c in captured) c.where((x) => scopaSuit(x) == 'D').length,
      ],
      'hasSettebello': [for (final c in captured) c.contains('7D')],
      'scopas': List<int>.of(scopas),
      'lastCapturer': lastCapturer,
      'legalCaptures': capturesMap,
      'lastMove': lastMove,
      'lastHandSummary': lastHandSummary,
      'result': result,
      'over': over,
    };
  }
}
