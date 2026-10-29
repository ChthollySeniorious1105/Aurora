import '../../src/engine.dart';

const List<String> _suits = ['S', 'H', 'D', 'C'];
const List<String> _ranks = [
  'A',
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
];

List<String> buildGolfDeck() => [
      for (final s in _suits)
        for (final r in _ranks) '$r$s',
      'BJ',
      'RJ',
    ];

String golfCardRank(String card) {
  if (card == 'BJ' || card == 'RJ') return card;
  if (card.length >= 2) return card.substring(0, card.length - 1);
  return '';
}

int golfCardValue(String card) {
  if (card == 'BJ' || card == 'RJ') return -5;
  final r = golfCardRank(card);
  return switch (r) {
    'K' => 0,
    'A' => 1,
    '2' => -2,
    '3' => 3,
    '4' => 4,
    '5' => 5,
    '6' => 6,
    '7' => 7,
    '8' => 8,
    '9' => 9,
    'T' => 10,
    'J' => 10,
    'Q' => 10,
    _ => 0,
  };
}

/// Checks whether vertical column [col] (0..2, indices col, col+3, col+6)
/// has 3 cards of the same rank and cancels to 0 points.
bool isGolfColumnCancelled(List<String> grid, int col, [List<bool>? rev]) {
  final i0 = col, i1 = col + 3, i2 = col + 6;
  if (grid.length < 9) return false;
  if (rev != null && (!rev[i0] || !rev[i1] || !rev[i2])) return false;
  final c0 = grid[i0], c1 = grid[i1], c2 = grid[i2];
  if (c0 == '??' || c1 == '??' || c2 == '??') return false;
  final r0 = golfCardRank(c0);
  final r1 = golfCardRank(c1);
  final r2 = golfCardRank(c2);
  if (r0.isEmpty || r0 != r1 || r1 != r2) return false;
  return golfCardValue(c0) >= 0;
}

/// Computes the score of a 3x3 [grid] (with Column Cancellation for 3 matching
/// ranks in a vertical column (c, c+3, c+6)).
/// If [rev] is provided, only revealed slots are counted.
int scoreGolfGrid(List<String> grid, [List<bool>? rev]) {
  var total = 0;
  for (var col = 0; col < 3; col++) {
    final indices = [col, col + 3, col + 6];
    if (isGolfColumnCancelled(grid, col, rev)) {
      continue; // 0 points for this column!
    }
    for (final idx in indices) {
      if (rev != null && !rev[idx]) continue;
      final c = grid[idx];
      if (c == '??' || c.isEmpty) continue;
      total += golfCardValue(c);
    }
  }
  return total;
}

class GolfCardsGame extends GameEngine {
  late int totalHoles;
  int hole = 1;
  int turn = 0;
  int startPlayer = 0;
  String phase = 'draw'; // 'draw' | 'act'

  late List<List<String>> grid;
  late List<List<bool>> revealed;
  List<String> stock = [];
  List<String> discard = [];
  String? drawnCard;

  int firstOutSeat = -1;
  int finalTurnsLeft = -1;

  late List<int> scores;
  late List<List<int>> holeHistory;
  Map<String, dynamic>? lastHoleSummary;

  bool _over = false;
  List<int>? _placings;

  GolfCardsGame(super.setup) {
    totalHoles = setup.opt<int>('holes', 3);
    grid = List.generate(players, (_) => List.filled(9, ''));
    revealed = List.generate(players, (_) => List.filled(9, false));
    scores = List.filled(players, 0);
    holeHistory = [];
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
    _startHole();
  }

  void _startHole() {
    final deck = shuffled(buildGolfDeck(), rng);
    var ptr = 0;
    for (var s = 0; s < players; s++) {
      grid[s] = deck.sublist(ptr, ptr + 9);
      ptr += 9;
      revealed[s] = List.filled(9, false);
      final initFlip = shuffled([0, 1, 2, 3, 4, 5, 6, 7, 8], rng);
      revealed[s][initFlip[0]] = true;
      revealed[s][initFlip[1]] = true;
    }
    discard = [deck[ptr++]];
    stock = deck.sublist(ptr);
    drawnCard = null;
    firstOutSeat = -1;
    finalTurnsLeft = -1;
    turn = startPlayer;
    phase = 'draw';
    host.log('第 $hole/$totalHoles 洞开始，由 ${name(turn)} 先手行动');
  }

  void _ensureStock() {
    if (stock.isNotEmpty) return;
    if (discard.length > 1) {
      final top = discard.removeLast();
      stock = shuffled(discard, rng);
      discard = [top];
    } else {
      // Fallback if all cards somehow exhausted
      stock = shuffled(buildGolfDeck(), rng);
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    if (phase == 'draw') {
      if (type == 'take_discard') {
        final slot = asInt(action['slot'], -1);
        if (slot < 0 || slot >= 9) throw GameError('请选择有效的九宫格位置(0..8)');
        if (discard.isEmpty) throw GameError('弃牌堆为空');
        final taken = discard.removeLast();
        final old = grid[seat][slot];
        grid[seat][slot] = taken;
        revealed[seat][slot] = true;
        discard.add(old);
        _endTurn(seat);
        return;
      }
      if (type == 'draw_stock') {
        _ensureStock();
        drawnCard = stock.removeLast();
        phase = 'act';
        return;
      }
      throw GameError('请从摸牌堆摸牌或拿取弃牌堆顶牌');
    }

    if (phase == 'act') {
      final card = drawnCard;
      if (card == null) throw GameError('尚未摸牌');
      final slot = asInt(action['slot'], -1);
      if (slot < 0 || slot >= 9) throw GameError('请选择有效的九宫格位置(0..8)');

      if (type == 'swap') {
        final old = grid[seat][slot];
        grid[seat][slot] = card;
        revealed[seat][slot] = true;
        discard.add(old);
        drawnCard = null;
        _endTurn(seat);
        return;
      }
      if (type == 'discard_flip') {
        if (revealed[seat][slot]) {
          throw GameError('必须选择一张尚未翻开的暗牌进行翻面');
        }
        discard.add(card);
        revealed[seat][slot] = true;
        drawnCard = null;
        _endTurn(seat);
        return;
      }
      throw GameError('请选择替换九宫格卡牌(swap)或弃牌翻开暗牌(discard_flip)');
    }

    throw GameError('未知阶段');
  }

  void _endTurn(int seat) {
    final allRevealed = revealed[seat].every((r) => r);
    if (firstOutSeat == -1 && allRevealed) {
      firstOutSeat = seat;
      finalTurnsLeft = players - 1;
      host.log('${name(seat)} 翻开了全部 9 张牌！其余玩家各进行最后 1 回合');
    } else if (firstOutSeat != -1) {
      finalTurnsLeft -= 1;
    }

    if (firstOutSeat != -1 && finalTurnsLeft <= 0) {
      _finishHole();
      return;
    }

    turn = (turn + 1) % players;
    phase = 'draw';
    if (turn == firstOutSeat) {
      _finishHole();
    }
  }

  void _finishHole() {
    for (var s = 0; s < players; s++) {
      for (var i = 0; i < 9; i++) {
        revealed[s][i] = true;
      }
    }
    final holeScores = [
      for (var s = 0; s < players; s++) scoreGolfGrid(grid[s]),
    ];
    for (var s = 0; s < players; s++) {
      scores[s] += holeScores[s];
    }
    holeHistory.add(holeScores);
    lastHoleSummary = {
      'hole': hole,
      'holeScores': holeScores,
      'firstOutSeat': firstOutSeat,
      'grids': [for (var s = 0; s < players; s++) List<String>.of(grid[s])],
    };

    host.log('第 $hole 洞结算：${[
      for (var s = 0; s < players; s++) '${name(s)} ${holeScores[s]}杆(总${scores[s]})'
    ].join('，')}');

    if (hole >= totalHoles) {
      _over = true;
      _placings = rankByScore(scores, lowWins: true);
      host.log('全部 $totalHoles 洞结束！');
    } else {
      hole += 1;
      startPlayer = (startPlayer + 1) % players;
      _startHole();
    }
  }

  int? _findColumnMatchSlot(int seat, String card) {
    final r = golfCardRank(card);
    if (golfCardValue(card) <= 0) return null;
    final g = grid[seat];
    final rev = revealed[seat];
    for (var col = 0; col < 3; col++) {
      final idxs = [col, col + 3, col + 6];
      final matching = idxs.where((i) => rev[i] && golfCardRank(g[i]) == r).toList();
      final nonMatching = idxs.where((i) => !rev[i] || golfCardRank(g[i]) != r).toList();
      if (matching.length == 2 && nonMatching.length == 1) {
        return nonMatching.first;
      }
    }
    return null;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    final g = grid[seat];
    final rev = revealed[seat];
    final hiddenSlots = [for (var i = 0; i < 9; i++) if (!rev[i]) i];

    if (phase == 'draw') {
      if (discard.isNotEmpty) {
        final top = discard.last;
        final topVal = golfCardValue(top);
        if (botLevel > 0) {
          final matchSlot = _findColumnMatchSlot(seat, top);
          if (matchSlot != null) {
            return {'type': 'take_discard', 'slot': matchSlot};
          }
        }
        if (topVal <= 2) {
          // Find worst revealed card that isn't part of a pair in its column
          var worstSlot = -1;
          var worstVal = topVal + 3;
          for (var i = 0; i < 9; i++) {
            if (!rev[i]) continue;
            final v = golfCardValue(g[i]);
            if (v > worstVal) {
              worstVal = v;
              worstSlot = i;
            }
          }
          if (worstSlot != -1) {
            return {'type': 'take_discard', 'slot': worstSlot};
          }
          if (hiddenSlots.isNotEmpty) {
            return {'type': 'take_discard', 'slot': hiddenSlots.first};
          }
        }
      }
      return {'type': 'draw_stock'};
    }

    if (phase == 'act') {
      final card = drawnCard!;
      final val = golfCardValue(card);
      if (botLevel > 0) {
        final matchSlot = _findColumnMatchSlot(seat, card);
        if (matchSlot != null) {
          return {'type': 'swap', 'slot': matchSlot};
        }
      }
      if (val <= 4) {
        var worstSlot = -1;
        var worstVal = val + 2;
        for (var i = 0; i < 9; i++) {
          if (!rev[i]) continue;
          final v = golfCardValue(g[i]);
          if (v > worstVal) {
            worstVal = v;
            worstSlot = i;
          }
        }
        if (worstSlot != -1) {
          return {'type': 'swap', 'slot': worstSlot};
        }
        if (hiddenSlots.isNotEmpty) {
          return {'type': 'swap', 'slot': hiddenSlots.first};
        }
      }
      if (hiddenSlots.isNotEmpty) {
        return {'type': 'discard_flip', 'slot': hiddenSlots.first};
      }
      // All slots already revealed: swap with worst revealed if strictly better, else swap 0
      var worstSlot = 0;
      var worstVal = -99;
      for (var i = 0; i < 9; i++) {
        final v = golfCardValue(g[i]);
        if (v > worstVal) {
          worstVal = v;
          worstSlot = i;
        }
      }
      return {'type': 'swap', 'slot': worstSlot};
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final visibleGrids = <List<String>>[
      for (var s = 0; s < players; s++)
        [
          for (var i = 0; i < 9; i++)
            revealed[s][i] ? grid[s][i] : '??',
        ],
    ];
    final visibleScores = [
      for (var s = 0; s < players; s++) scoreGolfGrid(grid[s], revealed[s]),
    ];
    final cancelledCols = [
      for (var s = 0; s < players; s++)
        [
          for (var col = 0; col < 3; col++)
            isGolfColumnCancelled(grid[s], col, revealed[s]),
        ],
    ];
    return {
      'hole': hole,
      'totalHoles': totalHoles,
      'turn': turn,
      'phase': phase,
      'grid': visibleGrids,
      'revealed': [for (final r in revealed) List<bool>.of(r)],
      'visibleScores': visibleScores,
      'cancelledCols': cancelledCols,
      'scores': List<int>.of(scores),
      'holeHistory': [for (final h in holeHistory) List<int>.of(h)],
      'stockCount': stock.length,
      'discardTop': discard.isNotEmpty ? discard.last : null,
      'discardCount': discard.length,
      'drawnCard': (seat == turn && drawnCard != null) ? drawnCard : (drawnCard != null ? '??' : null),
      'firstOutSeat': firstOutSeat,
      'finalTurnsLeft': finalTurnsLeft,
      'lastHoleSummary': lastHoleSummary,
      'over': _over,
      'placings': _placings,
    };
  }
}
