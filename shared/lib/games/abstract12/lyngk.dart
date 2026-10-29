import 'dart:math';

import '../../src/engine.dart';

/// Color constants for LYNGK:
/// 0: 蓝 Blue, 1: 红 Red, 2: 绿 Green, 3: 黑 Black, 4: 金黄 Gold, 5: 白百搭 White Wildcard
const List<String> kLyngkColorNames = ['蓝', '红', '绿', '黑', '金黄', '白百搭'];

const List<(int, int)> kLyngkHexDirs = [
  (1, 0),
  (-1, 0),
  (0, 1),
  (0, -1),
  (1, -1),
  (-1, 1),
];

/// Generate the axial coordinates (q, r) for the LYNGK board.
/// [large] = false -> 37 cells (radius 3 hexagon)
/// [large] = true  -> 43 cells (radius 3 hexagon + 6 radius-4 axial tips)
List<(int, int)> buildLyngkCoords({bool large = false}) {
  final coords = <(int, int)>[];
  if (large) {
    coords.add((0, -4));
    coords.add((4, -4));
  }
  for (var r = -3; r <= 3; r++) {
    if (large && r == 0) coords.add((-4, 0));
    final qMin = max(-3, -3 - r);
    final qMax = min(3, 3 - r);
    for (var q = qMin; q <= qMax; q++) {
      coords.add((q, r));
    }
    if (large && r == 0) coords.add((4, 0));
  }
  if (large) {
    coords.add((-4, 4));
    coords.add((0, 4));
  }
  return coords;
}

class LyngkMove {
  final int from;
  final int to;
  const LyngkMove(this.from, this.to);
}

class LyngkGame extends GameEngine {
  late bool largeBoard;
  late List<(int, int)> coords;
  late Map<(int, int), int> coordToIndex;

  /// Each cell holds a stack of piece colors from bottom to top.
  late List<List<int>> stacks;

  /// Owner of each active color 0..4 (-1 = Neutral, 0 = Seat 0, 1 = Seat 1).
  List<int> ownerOfColor = List.filled(5, -1);

  /// Colors claimed by each player (max 2 per player).
  List<List<int>> claimedColors = [[], []];

  /// Completed 5-stacks scored by each player.
  List<int> scoreStacks = [0, 0];

  int turn = 0;
  bool claimedThisTurn = false;
  bool over = false;
  int? winner; // 0, 1, or null for draw
  List<int>? finalPlacings;
  String? resultText;
  Map<String, dynamic>? lastMove;

  LyngkGame(super.setup);

  @override
  bool get canResign => true;

  @override
  bool get canDraw => true;

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => finalPlacings;

  @override
  void start() {
    final mode = setup.opt<String>('size', 'standard');
    largeBoard = mode == 'large';
    coords = buildLyngkCoords(large: largeBoard);
    coordToIndex = {
      for (var i = 0; i < coords.length; i++) coords[i]: i,
    };

    // Build initial piece bag:
    // 37-cell board: 5 active colors × 7 each (35) + 2 White Wildcards (5) = 37
    // 43-cell board: 5 active colors × 8 each + 1 extra (41) + 2 White Wildcards (5) = 43
    final bag = <int>[];
    final perColor = largeBoard ? 8 : 7;
    for (var c = 0; c < 5; c++) {
      for (var k = 0; k < perColor; k++) {
        bag.add(c);
      }
    }
    if (largeBoard) {
      bag.add(0);
    }
    bag.add(5);
    bag.add(5);
    bag.shuffle(rng);

    stacks = [
      for (var i = 0; i < coords.length; i++) <int>[bag[i]],
    ];
    ownerOfColor = List.filled(5, -1);
    claimedColors = [<int>[], <int>[]];
    scoreStacks = [0, 0];
    turn = 0;
    claimedThisTurn = false;
    over = false;
    winner = null;
    finalPlacings = null;
    resultText = null;
    lastMove = null;
  }

  /// Owner of the top piece of [stack]: -1 if neutral or wildcard (5), else 0 or 1.
  int stackOwner(List<int> stack) {
    if (stack.isEmpty) return -1;
    final top = stack.last;
    if (top >= 0 && top < 5) return ownerOfColor[top];
    return -1;
  }

  /// Check if combining [fromStack] onto [toStack] has <= 5 pieces and no duplicate active colors (0..4).
  bool validStackCombination(List<int> fromStack, List<int> toStack) {
    if (fromStack.isEmpty || toStack.isEmpty) return false;
    if (fromStack.length + toStack.length > 5) return false;
    var mask = 0;
    for (final c in toStack) {
      if (c >= 0 && c < 5) {
        if ((mask & (1 << c)) != 0) return false;
        mask |= (1 << c);
      }
    }
    for (final c in fromStack) {
      if (c >= 0 && c < 5) {
        if ((mask & (1 << c)) != 0) return false;
        mask |= (1 << c);
      }
    }
    return true;
  }

  /// Check if [to] is the first occupied cell along one of the 6 hex directions from [from].
  bool isStraightLineJump(int from, int to) {
    if (from < 0 || from >= coords.length || to < 0 || to >= coords.length || from == to) {
      return false;
    }
    final (q1, r1) = coords[from];
    final (q2, r2) = coords[to];
    final dq = q2 - q1;
    final dr = r2 - r1;

    int stepQ = 0;
    int stepR = 0;
    int steps = 0;
    if (dq == 0 && dr != 0) {
      steps = dr.abs();
      stepR = dr.sign;
    } else if (dr == 0 && dq != 0) {
      steps = dq.abs();
      stepQ = dq.sign;
    } else if (dq + dr == 0 && dq != 0) {
      steps = dq.abs();
      stepQ = dq.sign;
      stepR = dr.sign;
    } else {
      return false;
    }

    for (var k = 1; k < steps; k++) {
      final midIdx = coordToIndex[(q1 + k * stepQ, r1 + k * stepR)];
      if (midIdx == null || stacks[midIdx].isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  /// Check whether [seat] can legally move the stack at [from] onto [to].
  bool canMove(int seat, int from, int to) {
    if (from < 0 || from >= stacks.length || to < 0 || to >= stacks.length || from == to) {
      return false;
    }
    final fromStack = stacks[from];
    final toStack = stacks[to];
    if (fromStack.isEmpty || toStack.isEmpty) return false;

    final fOwner = stackOwner(fromStack);
    final tOwner = stackOwner(toStack);

    // Cannot move a stack topped by an opponent's claimed color.
    if (fOwner == 1 - seat) return false;

    // Neutral stack restrictions:
    // 1. May only land on a stack of equal or smaller height (fromStack.length >= toStack.length).
    // 2. Only a Claimed-Color stack may land on a stack topped by an opponent's Claimed Color.
    if (fOwner == -1) {
      if (fromStack.length < toStack.length) return false;
      if (tOwner == 1 - seat) return false;
    }

    if (!validStackCombination(fromStack, toStack)) return false;
    if (!isStraightLineJump(from, to)) return false;

    return true;
  }

  /// Enumerate all legal stack moves for [seat] given current claimed colors.
  List<LyngkMove> legalMovesFor(int seat) {
    final moves = <LyngkMove>[];
    for (var from = 0; from < stacks.length; from++) {
      final fromStack = stacks[from];
      if (fromStack.isEmpty) continue;
      final fOwner = stackOwner(fromStack);
      if (fOwner == 1 - seat) continue;

      final (q1, r1) = coords[from];
      for (final (dq, dr) in kLyngkHexDirs) {
        var q = q1 + dq;
        var r = r1 + dr;
        while (true) {
          final idx = coordToIndex[(q, r)];
          if (idx == null) break;
          if (stacks[idx].isNotEmpty) {
            if (canMove(seat, from, idx)) {
              moves.add(LyngkMove(from, idx));
            }
            break; // Cannot jump over an occupied cell
          }
          q += dq;
          r += dr;
        }
      }
    }
    return moves;
  }

  /// Colors that [seat] can currently claim.
  List<int> claimableColorsFor(int seat) {
    if (claimedThisTurn || claimedColors[seat].length >= 2) return const [];
    return [
      for (var c = 0; c < 5; c++)
        if (ownerOfColor[c] == -1) c,
    ];
  }

  /// Whether [seat] has at least one legal move now, or after claiming an available color.
  bool canPlayerAct(int seat) {
    if (legalMovesFor(seat).isNotEmpty) return true;
    if (claimedColors[seat].length < 2) {
      for (var c = 0; c < 5; c++) {
        if (ownerOfColor[c] == -1) {
          ownerOfColor[c] = seat;
          final hasMoves = legalMovesFor(seat).isNotEmpty;
          ownerOfColor[c] = -1;
          if (hasMoves) return true;
        }
      }
    }
    return false;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);
    if (type == 'claim') {
      if (claimedThisTurn) throw GameError('本回合已经声明过一种颜色');
      if (claimedColors[seat].length >= 2) throw GameError('每人最多只能声明 2 种颜色');
      final color = asInt(action['color']);
      if (color < 0 || color >= 5) throw GameError('无效的颜色编号');
      if (ownerOfColor[color] != -1) throw GameError('该颜色已被声明，无法重复占领');

      ownerOfColor[color] = seat;
      claimedColors[seat].add(color);
      claimedThisTurn = true;

      // If any 5-stack topped by this newly claimed color is already on the board, score it immediately.
      for (var i = 0; i < stacks.length; i++) {
        if (stacks[i].length == 5 && stacks[i].last == color) {
          stacks[i].clear();
          scoreStacks[seat]++;
        }
      }

      host.log('${name(seat)} 声明占领了【${kLyngkColorNames[color]}色】');
      lastMove = {'type': 'claim', 'seat': seat, 'color': color};

      // If player has no legal move after claiming, advance turn or finish game.
      if (legalMovesFor(seat).isEmpty) {
        _advanceAfterTurn(seat);
      }
      return;
    }

    if (type == 'move') {
      final from = asInt(action['from']);
      final to = asInt(action['to']);
      if (!canMove(seat, from, to)) {
        throw GameError('非法移动：必须沿直线跨越空位落到有效叠堆上，且满足高度与异色规则');
      }

      final fromStack = List<int>.of(stacks[from]);
      stacks[to].addAll(fromStack);
      stacks[from].clear();

      var scoredFive = false;
      final topColor = stacks[to].last;
      if (stacks[to].length == 5 && topColor >= 0 && topColor < 5 && ownerOfColor[topColor] == seat) {
        stacks[to].clear();
        scoreStacks[seat]++;
        scoredFive = true;
      }

      lastMove = {
        'type': 'move',
        'seat': seat,
        'from': from,
        'to': to,
        'scored': scoredFive,
      };

      if (scoredFive) {
        host.log('${name(seat)} 完成了 5 层【${kLyngkColorNames[topColor]}色】叠塔并收获 1 分！');
      } else {
        host.log('${name(seat)} 移动叠堆 ($from → $to)');
      }

      _advanceAfterTurn(seat);
      return;
    }

    throw GameError('未知操作类型：$type');
  }

  void _advanceAfterTurn(int justMovedSeat) {
    claimedThisTurn = false;
    final nextSeat = 1 - justMovedSeat;
    if (canPlayerAct(nextSeat)) {
      turn = nextSeat;
      return;
    }
    if (canPlayerAct(justMovedSeat)) {
      host.log('${name(nextSeat)} 无合法行动，由 ${name(justMovedSeat)} 继续行动');
      turn = justMovedSeat;
      return;
    }
    _finishByScore();
  }

  /// Count stacks of exact height [h] currently on the board topped by a color claimed by [seat].
  int countOwnedStacksOfHeight(int seat, int h) {
    var count = 0;
    for (final s in stacks) {
      if (s.length == h && stackOwner(s) == seat) {
        count++;
      }
    }
    return count;
  }

  void _finishByScore() {
    // Score any remaining height-5 stacks topped by a claimed color
    for (var i = 0; i < stacks.length; i++) {
      if (stacks[i].length == 5) {
        final owner = stackOwner(stacks[i]);
        if (owner == 0 || owner == 1) {
          scoreStacks[owner]++;
          stacks[i].clear();
        }
      }
    }

    over = true;
    int? win;
    if (scoreStacks[0] != scoreStacks[1]) {
      win = scoreStacks[0] > scoreStacks[1] ? 0 : 1;
    } else {
      for (var h = 4; h >= 1; h--) {
        final c0 = countOwnedStacksOfHeight(0, h);
        final c1 = countOwnedStacksOfHeight(1, h);
        if (c0 != c1) {
          win = c0 > c1 ? 0 : 1;
          break;
        }
      }
    }

    winner = win;
    if (win != null) {
      finalPlacings = rankWinners(2, [win]);
      resultText = '${name(win)} 获胜！（5层塔 ${scoreStacks[0]} : ${scoreStacks[1]}）';
    } else {
      finalPlacings = [1, 1];
      resultText = '双方平局！（5层塔 ${scoreStacks[0]} : ${scoreStacks[1]}）';
    }
    host.log('游戏结束：$resultText');
  }

  @override
  void resign(int seat) {
    if (over) return;
    over = true;
    winner = 1 - seat;
    finalPlacings = rankWinners(2, [winner!]);
    resultText = '${name(seat)} 认输，${name(winner!)} 获胜！';
    host.log(resultText!);
  }

  @override
  void agreeDraw() {
    if (over) return;
    over = true;
    winner = null;
    finalPlacings = [1, 1];
    resultText = '双方协议和棋';
    host.log(resultText!);
  }

  @override
  Map<String, dynamic> view(int seat) {
    final moves = over ? const <LyngkMove>[] : legalMovesFor(turn);
    final moveMap = <String, List<int>>{};
    for (final m in moves) {
      (moveMap['${m.from}'] ??= <int>[]).add(m.to);
    }

    return {
      'largeBoard': largeBoard,
      'coords': [
        for (final (q, r) in coords) [q, r],
      ],
      'stacks': [
        for (final s in stacks) List<int>.of(s),
      ],
      'ownerOfColor': List<int>.of(ownerOfColor),
      'claimedColors': [
        List<int>.of(claimedColors[0]),
        List<int>.of(claimedColors[1]),
      ],
      'scoreStacks': List<int>.of(scoreStacks),
      'stackBreakdown': [
        for (var p = 0; p < 2; p++)
          [for (var h = 1; h <= 4; h++) countOwnedStacksOfHeight(p, h)],
      ],
      'turn': turn,
      'claimedThisTurn': claimedThisTurn,
      'claimableColors': over ? const <int>[] : claimableColorsFor(turn),
      'legalMoves': moveMap,
      'lastMove': lastMove,
      'over': over,
      'winner': winner,
      'result': resultText,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    // Consider claiming a color if we haven't claimed 2 yet and haven't claimed this turn.
    final claimable = claimableColorsFor(seat);
    final currentMoves = legalMovesFor(seat);

    if (claimable.isNotEmpty) {
      // Claim if we have no moves without claiming, or if a color is on top of a tall stack (>= 3)
      // or we have >= 1 stack of height >= 2 of that color.
      int? bestColor;
      var bestColorScore = -1;
      for (final c in claimable) {
        var score = 0;
        for (var i = 0; i < stacks.length; i++) {
          final s = stacks[i];
          if (s.isNotEmpty && s.last == c) {
            score += s.length * s.length;
            if (s.length >= 4) score += 50;
          }
        }
        // Check if claiming this color unlocks a 5-stack creation move immediately
        ownerOfColor[c] = seat;
        final ms = legalMovesFor(seat);
        for (final m in ms) {
          if (stacks[m.from].length + stacks[m.to].length == 5 && stacks[m.from].last == c) {
            score += 200;
          }
        }
        ownerOfColor[c] = -1;

        if (score > bestColorScore) {
          bestColorScore = score;
          bestColor = c;
        }
      }

      if (bestColor != null && (currentMoves.isEmpty || bestColorScore >= 18)) {
        return {'type': 'claim', 'color': bestColor};
      }
    }

    if (currentMoves.isEmpty) return null;

    if (botLevel == 0) {
      final pick = currentMoves[rng.nextInt(currentMoves.length)];
      return {'type': 'move', 'from': pick.from, 'to': pick.to};
    }

    // Score each legal move: prefer building taller stacks topped by our claimed colors,
    // especially completing a height-5 stack!
    LyngkMove bestMove = currentMoves.first;
    var bestScore = -1000000;
    for (final m in currentMoves) {
      final fStack = stacks[m.from];
      final tStack = stacks[m.to];
      final newHeight = fStack.length + tStack.length;
      final fOwner = stackOwner(fStack);
      final tOwner = stackOwner(tStack);

      var sc = newHeight * 15 + rng.nextInt(5);
      if (fOwner == seat) {
        sc += newHeight * 25;
        if (newHeight == 5) sc += 1000;
        if (tOwner == 1 - seat) sc += 40 * tStack.length; // Capture opponent-topped stack!
      } else {
        // Neutral top
        if (tOwner == seat) {
          sc -= 30 * tStack.length; // Avoid burying our own claimed color under neutral
        }
        if (newHeight == 5) {
          sc -= 50; // Neutral 5-stack doesn't score unless claimed later
        }
      }
      if (sc > bestScore) {
        bestScore = sc;
        bestMove = m;
      }
    }
    return {'type': 'move', 'from': bestMove.from, 'to': bestMove.to};
  }
}
