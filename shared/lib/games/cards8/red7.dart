import '../../src/engine.dart';

/// Color indices: 6=Red, 5=Orange, 4=Yellow, 3=Green, 2=Blue, 1=Indigo, 0=Violet
const List<String> red7ColorCodes = ['V', 'I', 'B', 'G', 'Y', 'O', 'R'];

const List<String> red7ColorNames = [
  '紫 (Violet)',
  '靛 (Indigo)',
  '蓝 (Blue)',
  '绿 (Green)',
  '黄 (Yellow)',
  '橙 (Orange)',
  '红 (Red)',
];

const List<String> red7RuleDescriptions = [
  '小于4最多 (1/2/3)',
  '最长连续顺子',
  '不同颜色最多',
  '偶数牌最多 (2/4/6)',
  '同颜色牌最多',
  '同数字牌最多',
  '最高单牌',
];

int red7Color(String card) {
  if (card.isEmpty) return -1;
  final idx = red7ColorCodes.indexOf(card[0]);
  if (idx >= 0) return idx;
  final idx2 = card.length > 1 ? red7ColorCodes.indexOf(card[1]) : -1;
  return idx2;
}

int red7Number(String card) {
  if (card.length < 2) return 0;
  return int.tryParse(card[1]) ?? int.tryParse(card[0]) ?? 0;
}

int red7Power(String card) => red7Number(card) * 10 + red7Color(card);

List<String> buildRed7Deck() => [
      for (var c = 6; c >= 0; c--)
        for (var n = 1; n <= 7; n++) '${red7ColorCodes[c]}$n',
    ];

class Red7Eval {
  final List<String> subset;
  final int count;
  final int topPower;
  const Red7Eval(this.subset, this.count, this.topPower);

  bool beats(Red7Eval other) =>
      count > 0 &&
      (count > other.count ||
          (count == other.count && topPower > other.topPower));

  int get sumNumbers =>
      subset.fold<int>(0, (acc, c) => acc + red7Number(c));
}

Red7Eval _fromSubset(List<String> sub) {
  if (sub.isEmpty) return const Red7Eval([], 0, 0);
  var top = 0;
  for (final c in sub) {
    final p = red7Power(c);
    if (p > top) top = p;
  }
  return Red7Eval(sub, sub.length, top);
}

Red7Eval evaluateRed7Palette(List<String> palette, int canvasColor) {
  if (palette.isEmpty) return const Red7Eval([], 0, 0);

  switch (canvasColor) {
    case 6: // Red: highest single card
      String best = palette.first;
      for (final c in palette) {
        if (red7Power(c) > red7Power(best)) best = c;
      }
      return _fromSubset([best]);

    case 5: // Orange: most of one number
      var best = const Red7Eval([], 0, 0);
      for (var n = 1; n <= 7; n++) {
        final sub = palette.where((c) => red7Number(c) == n).toList();
        final ev = _fromSubset(sub);
        if (ev.beats(best)) best = ev;
      }
      return best;

    case 4: // Yellow: most of one color
      var best = const Red7Eval([], 0, 0);
      for (var col = 0; col <= 6; col++) {
        final sub = palette.where((c) => red7Color(c) == col).toList();
        final ev = _fromSubset(sub);
        if (ev.beats(best)) best = ev;
      }
      return best;

    case 3: // Green: most even cards
      final evens = palette.where((c) => red7Number(c).isEven).toList();
      return _fromSubset(evens);

    case 2: // Blue: most cards all of different colors
      final bestByColor = <int, String>{};
      for (final c in palette) {
        final col = red7Color(c);
        final prev = bestByColor[col];
        if (prev == null || red7Power(c) > red7Power(prev)) {
          bestByColor[col] = c;
        }
      }
      return _fromSubset(bestByColor.values.toList());

    case 1: // Indigo: longest run of consecutive numbers
      final bestByNum = <int, String>{};
      for (final c in palette) {
        final n = red7Number(c);
        final prev = bestByNum[n];
        if (prev == null || red7Power(c) > red7Power(prev)) {
          bestByNum[n] = c;
        }
      }
      var best = const Red7Eval([], 0, 0);
      for (var start = 1; start <= 7; start++) {
        if (!bestByNum.containsKey(start)) continue;
        final run = <String>[];
        for (var end = start; end <= 7 && bestByNum.containsKey(end); end++) {
          run.add(bestByNum[end]!);
          final ev = _fromSubset(List<String>.of(run));
          if (ev.beats(best)) best = ev;
        }
      }
      return best;

    case 0: // Violet: most cards below 4 (1, 2, 3)
      final low = palette.where((c) => red7Number(c) < 4).toList();
      return _fromSubset(low);

    default:
      return const Red7Eval([], 0, 0);
  }
}

class Red7Game extends GameEngine {
  late final int maxRounds;

  int round = 0;
  List<int> scores = [];
  int turn = 0;

  int canvasColor = 6;
  String? canvasCard;
  List<List<String>> hands = [];
  List<List<String>> palettes = [];
  List<bool> folded = [];

  Map<String, dynamic>? lastMove;
  Map<String, dynamic>? lastRoundResult;
  Map<String, dynamic>? result;
  bool over = false;
  int? resignedSeat;

  Red7Game(super.setup) {
    maxRounds = setup.opt<int>('rounds', 3);
    scores = List<int>.filled(players, 0);
    hands = List.generate(players, (_) => <String>[]);
    palettes = List.generate(players, (_) => <String>[]);
    folded = List<bool>.filled(players, false);
  }

  @override
  void start() {
    round = 0;
    _startNewRound();
  }

  void _startNewRound() {
    round++;
    final deck = shuffled(buildRed7Deck(), rng);
    var idx = 0;
    hands = List.generate(players, (_) {
      final h = deck.sublist(idx, idx + 7);
      idx += 7;
      h.sort((a, b) => red7Power(b).compareTo(red7Power(a)));
      return h;
    });
    palettes = List.generate(players, (_) => [deck[idx++]]);
    folded = List<bool>.filled(players, false);
    canvasColor = 6;
    canvasCard = null;
    lastMove = null;

    final leader = currentLeader();
    turn = leader >= 0 ? (leader + 1) % players : 0;
  }

  int currentLeader({
    List<List<String>>? testPalettes,
    int? testCanvasColor,
  }) {
    final pals = testPalettes ?? palettes;
    final rule = testCanvasColor ?? canvasColor;
    var bestSeat = -1;
    var bestEval = const Red7Eval([], 0, 0);
    for (var s = 0; s < players; s++) {
      if (folded[s]) continue;
      final ev = evaluateRed7Palette(pals[s], rule);
      if (ev.beats(bestEval)) {
        bestEval = ev;
        bestSeat = s;
      }
    }
    return bestSeat;
  }

  bool isWinningMove(int seat, {String? paletteCard, String? canvasCardMove}) {
    if (folded[seat]) return false;
    if (paletteCard == null && canvasCardMove == null) return false;
    if (paletteCard != null && !hands[seat].contains(paletteCard)) return false;
    if (canvasCardMove != null && !hands[seat].contains(canvasCardMove)) {
      return false;
    }
    if (paletteCard != null &&
        canvasCardMove != null &&
        paletteCard == canvasCardMove) {
      return false;
    }

    final testPals = [
      for (var s = 0; s < players; s++)
        s == seat && paletteCard != null
            ? [...palettes[s], paletteCard]
            : palettes[s],
    ];
    final testRule =
        canvasCardMove != null ? red7Color(canvasCardMove) : canvasColor;
    return currentLeader(testPalettes: testPals, testCanvasColor: testRule) ==
        seat;
  }

  List<Map<String, dynamic>> legalWinningPlays(int seat) {
    if (over || seat != turn || folded[seat]) return const [];
    final h = hands[seat];
    final moves = <Map<String, dynamic>>[];

    // 1. Play 1 card to Palette
    for (final p in h) {
      if (isWinningMove(seat, paletteCard: p)) {
        moves.add({'type': 'play', 'palette': p});
      }
    }
    // 2. Play 1 card to Canvas
    for (final c in h) {
      if (isWinningMove(seat, canvasCardMove: c)) {
        moves.add({'type': 'play', 'canvas': c});
      }
    }
    // 3. Play 1 card to Palette AND 1 card to Canvas
    for (final p in h) {
      for (final c in h) {
        if (p == c) continue;
        if (isWinningMove(seat, paletteCard: p, canvasCardMove: c)) {
          moves.add({'type': 'play', 'palette': p, 'canvas': c});
        }
      }
    }
    return moves;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    if (type == 'fold') {
      folded[seat] = true;
      lastMove = {'seat': seat, 'type': 'fold'};
      host.log('${name(seat)} 选择弃牌退出本局');
      _advanceAfterTurn(seat);
      return;
    }

    if (type == 'play') {
      final rawP = action['palette'];
      final rawC = action['canvas'];
      final pCard = (rawP is String && rawP.isNotEmpty) ? rawP : null;
      final cCard = (rawC is String && rawC.isNotEmpty) ? rawC : null;

      if (pCard == null && cCard == null) {
        throw GameError('请至少选择一张手牌打入调色盘或画布');
      }
      if (pCard != null && !hands[seat].contains(pCard)) {
        throw GameError('手牌中没有 $pCard');
      }
      if (cCard != null && !hands[seat].contains(cCard)) {
        throw GameError('手牌中没有 $cCard');
      }
      if (pCard != null && cCard != null && pCard == cCard) {
        throw GameError('不能将同一张牌同时打入调色盘和画布');
      }
      if (!isWinningMove(seat, paletteCard: pCard, canvasCardMove: cCard)) {
        throw GameError('行动结束时必须在当前画布规则下领先全场，否则请弃牌');
      }

      if (pCard != null) {
        hands[seat].remove(pCard);
        palettes[seat].add(pCard);
      }
      if (cCard != null) {
        hands[seat].remove(cCard);
        canvasCard = cCard;
        canvasColor = red7Color(cCard);
      }

      lastMove = {
        'seat': seat,
        'type': 'play',
        'palette': pCard,
        'canvas': cCard,
        'canvasColor': canvasColor,
      };
      _advanceAfterTurn(seat);
      return;
    }

    throw GameError('未知操作: $type');
  }

  void _advanceAfterTurn(int currentSeat) {
    final activeSeats = [
      for (var s = 0; s < players; s++)
        if (!folded[s]) s,
    ];
    if (activeSeats.length <= 1) {
      final winner = activeSeats.isNotEmpty ? activeSeats.first : currentSeat;
      _finishRound(winner);
      return;
    }
    var next = (currentSeat + 1) % players;
    while (folded[next]) {
      next = (next + 1) % players;
    }
    turn = next;
  }

  void _finishRound(int winner) {
    final ev = evaluateRed7Palette(palettes[winner], canvasColor);
    var pts = ev.sumNumbers;
    if (pts <= 0 && palettes[winner].isNotEmpty) {
      pts = red7Number(palettes[winner].first);
    }
    scores[winner] += pts;
    lastRoundResult = {
      'round': round,
      'winner': winner,
      'points': pts,
      'canvasColor': canvasColor,
      'winningSubset': ev.subset,
      'scores': List<int>.of(scores),
    };
    host.log(
        '第$round局结束：${name(winner)} 获胜（${red7ColorNames[canvasColor]}规则），赢得 $pts 分！');

    if (round >= maxRounds) {
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
        'lastRound': lastRoundResult,
      };
      return;
    }

    _startNewRound();
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
    final moves = legalWinningPlays(seat);
    if (moves.isEmpty) {
      return {'type': 'fold'};
    }
    if (botLevel == 0) {
      return moves[rng.nextInt(moves.length)];
    }
    // Prefer single-card plays (saving hand size) over 2-card plays!
    final singleMoves = moves
        .where((m) => m['palette'] == null || m['canvas'] == null)
        .toList();
    if (singleMoves.isNotEmpty) {
      // Among single moves, prefer playing to palette to grow subset size
      final palOnly =
          singleMoves.where((m) => m['palette'] != null).toList();
      if (palOnly.isNotEmpty) {
        return palOnly.first;
      }
      return singleMoves.first;
    }
    return moves.first;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myHand =
        (seat >= 0 && seat < players) ? List<String>.of(hands[seat]) : <String>[];
    final evals = [
      for (var s = 0; s < players; s++)
        evaluateRed7Palette(palettes[s], canvasColor).subset,
    ];
    final winMoves =
        (seat >= 0 && seat < players && seat == turn)
            ? legalWinningPlays(seat)
            : const <Map<String, dynamic>>[];

    return {
      'round': round,
      'maxRounds': maxRounds,
      'scores': List<int>.of(scores),
      'turn': turn,
      'leader': currentLeader(),
      'canvasColor': canvasColor,
      'canvasCard': canvasCard,
      'ruleName': red7ColorNames[canvasColor],
      'ruleDesc': red7RuleDescriptions[canvasColor],
      'hand': myHand,
      'handCounts': [for (final h in hands) h.length],
      'palettes': [for (final p in palettes) List<String>.of(p)],
      'bestSubsets': evals,
      'folded': List<bool>.of(folded),
      'canWin': winMoves.isNotEmpty,
      'legalMoves': winMoves,
      'lastMove': lastMove,
      'lastRoundResult': lastRoundResult,
      'result': result,
      'over': over,
    };
  }
}
