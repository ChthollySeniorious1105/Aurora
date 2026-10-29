import 'dart:math';

import '../../src/engine.dart';

/// 3 primary hex axes: E-W (1,0), NW-SE (0,1), NE-SW (1,-1).
const List<(int, int)> yavalathAxes = [
  (1, 0),
  (0, 1),
  (1, -1),
];

int yavalathHexDist(int q, int r) {
  return max(q.abs(), max(r.abs(), (q + r).abs()));
}

List<(int, int)> yavalathBoardCellsForRadius(int radius) {
  return [
    for (var q = -radius; q <= radius; q++)
      for (var r = -radius; r <= radius; r++)
        if (yavalathHexDist(q, r) <= radius) (q, r),
  ];
}

/// 亚瓦拉特棋 (Yavalath) — Cameron Browne's "Make 4-in-a-Row WITHOUT Making 3-in-a-Row" hex game.
class YavalathGame extends GameEngine {
  YavalathGame(super.setup);

  late String mode;
  late int radius;
  late List<(int, int)> boardCells;

  /// Key: (q, r), Value: -1 (empty), 0 (White / seat 0), 1 (Black / seat 1).
  final Map<(int, int), int> _board = {};

  int turn = 0;
  int moveCount = 0;
  bool _over = false;
  int? winner; // 0, 1, or -1 for draw
  String? winReason;
  bool endedBySuicide = false;
  List<(int, int)> highlightLine = [];
  Map<String, dynamic>? lastMove;

  @override
  bool get isOver => _over;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  bool get canResign => true;

  @override
  bool get canDraw => true;

  @override
  List<int>? get placings {
    if (!_over) return null;
    if (winner == null || winner == -1) return const [1, 1];
    return rankWinners(2, [winner!]);
  }

  bool isValidHex(int q, int r) => yavalathHexDist(q, r) <= radius;

  int stoneAt(int q, int r) => _board[(q, r)] ?? -1;

  void setStoneAt(int q, int r, int color) {
    if (isValidHex(q, r)) {
      _board[(q, r)] = color;
    }
  }

  @override
  void start() {
    mode = setup.opt<String>('mode', 'standard');
    radius = mode == 'quick' ? 3 : 4;
    boardCells = yavalathBoardCellsForRadius(radius);
    _board.clear();
    for (final cell in boardCells) {
      _board[cell] = -1;
    }
    turn = 0;
    moveCount = 0;
    _over = false;
    winner = null;
    winReason = null;
    endedBySuicide = false;
    highlightLine = [];
    lastMove = null;
  }

  @override
  void resign(int seat) {
    if (_over) throw GameError('对局已结束');
    _over = true;
    winner = 1 - seat;
    winReason = '${name(seat)} 认输，${name(winner!)} 获胜！';
    host.log(winReason!);
  }

  @override
  void agreeDraw() {
    if (_over) throw GameError('对局已结束');
    _over = true;
    winner = -1;
    winReason = '双方同意和棋';
    host.log(winReason!);
  }

  /// Inspect contiguous same-color lines passing through (q, r) if [color] is placed at (q, r).
  /// Returns:
  ///  - outcome: 1 if any axis >= 4 (immediate win), -1 if no axis >= 4 and any axis == 3 (immediate loss), 0 otherwise.
  ///  - line: the longest >=4 line (if winning) or the ==3 line (if losing).
  (int outcome, List<(int, int)> line) inspectPlacement(int q, int r, int color) {
    List<(int, int)>? winLine;
    List<(int, int)>? loseLine;

    for (final (dq, dr) in yavalathAxes) {
      final neg = <(int, int)>[];
      for (var step = 1; step <= radius * 2; step++) {
        final nq = q - dq * step;
        final nr = r - dr * step;
        if (!isValidHex(nq, nr) || stoneAt(nq, nr) != color) break;
        neg.add((nq, nr));
      }
      final pos = <(int, int)>[];
      for (var step = 1; step <= radius * 2; step++) {
        final nq = q + dq * step;
        final nr = r + dr * step;
        if (!isValidHex(nq, nr) || stoneAt(nq, nr) != color) break;
        pos.add((nq, nr));
      }
      final line = <(int, int)>[
        ...neg.reversed,
        (q, r),
        ...pos,
      ];
      if (line.length >= 4) {
        if (winLine == null || line.length > winLine.length) {
          winLine = line;
        }
      } else if (line.length == 3) {
        loseLine ??= line;
      }
    }

    if (winLine != null) return (1, winLine);
    if (loseLine != null) return (-1, loseLine);
    return (0, const []);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你落子');

    final type = asStr(action['type']);
    if (type != 'place') throw GameError('未知操作类型：$type');

    final q = asInt(action['q'], 999);
    final r = asInt(action['r'], 999);
    if (!isValidHex(q, r)) {
      throw GameError('落子坐标超出棋盘范围');
    }
    if (stoneAt(q, r) != -1) {
      throw GameError('该六角格已有棋子');
    }

    final (outcome, line) = inspectPlacement(q, r, seat);
    _board[(q, r)] = seat;
    moveCount++;
    lastMove = {
      'type': 'place',
      'seat': seat,
      'q': q,
      'r': r,
      'outcome': outcome,
    };

    if (outcome == 1) {
      _over = true;
      winner = seat;
      endedBySuicide = false;
      highlightLine = line;
      winReason = '${name(seat)} 连成四子，直接获胜！';
      host.log(winReason!);
      return;
    }

    if (outcome == -1) {
      _over = true;
      winner = 1 - seat;
      endedBySuicide = true;
      highlightLine = line;
      winReason = '${name(seat)} 形成三连自杀判负，${name(winner!)} 获胜！';
      host.log(winReason!);
      return;
    }

    if (moveCount >= boardCells.length || !_board.values.any((v) => v == -1)) {
      _over = true;
      winner = -1;
      winReason = '棋盘已满且无人达成四连，双方平局！';
      host.log(winReason!);
      return;
    }

    turn = 1 - seat;
  }

  /// Counts split-4 threats (windows of 4 where [color] has 3 stones and 1 empty gap)
  /// if [color] is placed at (q, r).
  int _countSplitThreatsAfter(int q, int r, int color) {
    var threats = 0;
    for (final (dq, dr) in yavalathAxes) {
      // Check all 4-cell windows along this axis containing (q, r)
      for (var startOffset = -3; startOffset <= 0; startOffset++) {
        var ownCount = 0;
        var emptyCount = 0;
        var validWindow = true;
        for (var i = 0; i < 4; i++) {
          final wq = q + dq * (startOffset + i);
          final wr = r + dr * (startOffset + i);
          if (!isValidHex(wq, wr)) {
            validWindow = false;
            break;
          }
          final v = (wq == q && wr == r) ? color : stoneAt(wq, wr);
          if (v == color) {
            ownCount++;
          } else if (v == -1) {
            emptyCount++;
          } else {
            validWindow = false;
            break;
          }
        }
        if (validWindow) {
          if (ownCount == 3 && emptyCount == 1) {
            threats += 3;
          } else if (ownCount == 2 && emptyCount == 2) {
            threats += 1;
          }
        }
      }
    }
    return threats;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    final emptyCells = <(int, int)>[];
    for (final cell in boardCells) {
      if (stoneAt(cell.$1, cell.$2) == -1) {
        emptyCells.add(cell);
      }
    }
    if (emptyCells.isEmpty) return null;

    final winningMoves = <(int, int)>[];
    final safeMoves = <(int, int)>[];
    final suicideMoves = <(int, int)>[];

    for (final (q, r) in emptyCells) {
      final (outcome, _) = inspectPlacement(q, r, seat);
      if (outcome == 1) {
        winningMoves.add((q, r));
      } else if (outcome == 0) {
        safeMoves.add((q, r));
      } else {
        suicideMoves.add((q, r));
      }
    }

    // 1. Immediate win
    if (winningMoves.isNotEmpty) {
      final pick = winningMoves[rng.nextInt(winningMoves.length)];
      return {'type': 'place', 'q': pick.$1, 'r': pick.$2};
    }

    // If forced to play a suicide move because every empty cell is a 3-in-a-row:
    if (safeMoves.isEmpty) {
      final pick = suicideMoves[rng.nextInt(suicideMoves.length)];
      return {'type': 'place', 'q': pick.$1, 'r': pick.$2};
    }

    if (botLevel == 0 && rng.nextDouble() < 0.4) {
      final pick = safeMoves[rng.nextInt(safeMoves.length)];
      return {'type': 'place', 'q': pick.$1, 'r': pick.$2};
    }

    // 2. Block opponent's immediate 4-in-a-row win if safe to do so
    final opp = 1 - seat;
    for (final (q, r) in safeMoves) {
      final (oppOutcome, _) = inspectPlacement(q, r, opp);
      if (oppOutcome == 1) {
        return {'type': 'place', 'q': q, 'r': r};
      }
    }

    // 3. Score safe moves by split-4 threats created + blocking opponent split threats + centrality
    (int, int)? bestCell;
    var bestScore = double.negativeInfinity;
    for (final (q, r) in safeMoves) {
      final myThreats = _countSplitThreatsAfter(q, r, seat);
      final oppThreats = _countSplitThreatsAfter(q, r, opp);
      final centerBonus = (radius - yavalathHexDist(q, r)) * 0.8;
      final score = myThreats * 6.0 + oppThreats * 4.5 + centerBonus + rng.nextDouble() * 0.9;
      if (score > bestScore) {
        bestScore = score;
        bestCell = (q, r);
      }
    }

    final chosen = bestCell ?? safeMoves.first;
    return {'type': 'place', 'q': chosen.$1, 'r': chosen.$2};
  }

  @override
  Map<String, dynamic> view(int seat) {
    final cellViews = <Map<String, dynamic>>[];
    for (final (q, r) in boardCells) {
      final c = stoneAt(q, r);
      var suicideHint = false;
      var winHint = false;
      if (!_over && c == -1) {
        final (out, _) = inspectPlacement(q, r, turn);
        if (out == 1) winHint = true;
        if (out == -1) suicideHint = true;
      }
      cellViews.add({
        'q': q,
        'r': r,
        'color': c,
        'winHint': winHint,
        'suicideHint': suicideHint,
      });
    }

    return {
      'mode': mode,
      'radius': radius,
      'turn': turn,
      'moveCount': moveCount,
      'totalCells': boardCells.length,
      'over': _over,
      'winner': winner,
      'winReason': winReason,
      'endedBySuicide': endedBySuicide,
      'highlightLine': [
        for (final (q, r) in highlightLine) [q, r],
      ],
      'cells': cellViews,
      'lastMove': lastMove,
    };
  }
}
