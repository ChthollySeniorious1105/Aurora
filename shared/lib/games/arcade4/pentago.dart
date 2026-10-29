import '../../src/engine.dart';

/// All 32 possible 5-in-a-row lines on the 6x6 Pentago board.
final List<List<int>> pentagoLines = _buildLines();

List<List<int>> _buildLines() {
  final out = <List<int>>[];
  // Horizontal (6 rows x 2 start cols)
  for (var r = 0; r < 6; r++) {
    for (var c0 = 0; c0 <= 1; c0++) {
      out.add([for (var k = 0; k < 5; k++) r * 6 + (c0 + k)]);
    }
  }
  // Vertical (6 cols x 2 start rows)
  for (var c = 0; c < 6; c++) {
    for (var r0 = 0; r0 <= 1; r0++) {
      out.add([for (var k = 0; k < 5; k++) (r0 + k) * 6 + c]);
    }
  }
  // Down-right diagonals
  for (var r0 = 0; r0 <= 1; r0++) {
    for (var c0 = 0; c0 <= 1; c0++) {
      out.add([for (var k = 0; k < 5; k++) (r0 + k) * 6 + (c0 + k)]);
    }
  }
  // Down-left diagonals
  for (var r0 = 0; r0 <= 1; r0++) {
    for (var c0 = 4; c0 <= 5; c0++) {
      out.add([for (var k = 0; k < 5; k++) (r0 + k) * 6 + (c0 - k)]);
    }
  }
  return out;
}

/// Rotate quadrant `q` (0..3) of a 36-cell Pentago board by 90 degrees `'cw'` or `'ccw'`.
/// Returns a new 36-element board list.
List<int> rotateQuadrant(List<int> board, int q, String dir) {
  final next = List<int>.of(board);
  final r0 = (q ~/ 2) * 3;
  final c0 = (q % 2) * 3;
  final cw = dir == 'cw';
  for (var lr = 0; lr < 3; lr++) {
    for (var lc = 0; lc < 3; lc++) {
      final nlr = cw ? lc : (2 - lc);
      final nlc = cw ? (2 - lr) : lr;
      next[(r0 + nlr) * 6 + (c0 + nlc)] = board[(r0 + lr) * 6 + (c0 + lc)];
    }
  }
  return next;
}

/// Returns the first 5-in-a-row line for `color` (0 or 1), or null if none.
List<int>? findWinLine(List<int> board, int color) {
  for (final line in pentagoLines) {
    var ok = true;
    for (var i = 0; i < 5; i++) {
      if (board[line[i]] != color) {
        ok = false;
        break;
      }
    }
    if (ok) return line;
  }
  return null;
}

/// 旋转五子棋 (Pentago) — 2-player abstract strategy board game.
class Pentago extends GameEngine {
  /// 36 cells: -1 = empty, 0 = Black (first mover), 1 = White (second mover).
  List<int> board = List.filled(36, -1);

  /// Which game seat plays Black (0); the other seat plays White (1).
  int blackSeat = 0;

  /// Whose turn it is by color: 0 = Black, 1 = White.
  int turnColor = 0;

  /// Turn sub-step: `'place'` or `'rotate'`.
  String step = 'place';

  int lastPlaced = -1;
  int lastQuadrant = -1;
  String lastDir = '';
  int moveCount = 0;

  bool _over = false;
  int winner = -1; // seat index, or -1 for draw
  String resultText = '';
  List<int> winLine = const [];
  List<int>? _placings;

  Pentago(super.setup);

  int seatOfColor(int c) => c == 0 ? blackSeat : (1 - blackSeat);
  int colorOfSeat(int s) => s == blackSeat ? 0 : 1;
  int get turnSeat => seatOfColor(turnColor);

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _placings;

  @override
  bool get canResign => true;

  @override
  bool get canDraw => true;

  @override
  List<int> get waitingFor => _over ? const [] : [turnSeat];

  @override
  void start() {
    board = List.filled(36, -1);
    final firstOpt = setup.opt<String>('first', 'seat0');
    blackSeat = firstOpt == 'random' ? rng.nextInt(2) : 0;
    turnColor = 0;
    step = 'place';
    lastPlaced = -1;
    lastQuadrant = -1;
    lastDir = '';
    moveCount = 0;
    _over = false;
    winner = -1;
    resultText = '';
    winLine = const [];
    _placings = null;
    host.log('旋转五子棋开始！${name(blackSeat)} 执黑先行，每回合落一子并旋转任意一个 3×3 象限 90°。');
  }

  @override
  void resign(int seat) {
    if (_over || seat < 0 || seat >= 2) throw GameError('当前无法认输');
    _over = true;
    winner = 1 - seat;
    _placings = rankWinners(2, [winner]);
    resultText = '${name(seat)} 认输，${name(winner)} 获胜！';
    host.log(resultText);
  }

  @override
  void agreeDraw() {
    if (_over) throw GameError('游戏已结束');
    _over = true;
    winner = -1;
    _placings = [1, 1];
    resultText = '双方协议和棋！';
    host.log(resultText);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turnSeat) throw GameError('还没轮到你行动');

    final type = asStr(action['type'], 'move');

    if (type == 'unplace') {
      if (step != 'rotate' || lastPlaced < 0) {
        throw GameError('当前没有可撤回的落子');
      }
      board[lastPlaced] = -1;
      lastPlaced = -1;
      step = 'place';
      return;
    }

    if (type == 'place') {
      if (step != 'place') throw GameError('请先旋转一个 3×3 象限');
      final cell = asInt(action['cell'], -1);
      _applyPlacement(seat, cell);
      return;
    }

    if (type == 'rotate') {
      if (step != 'rotate') throw GameError('请先在棋盘空位落子');
      final q = asInt(action['quadrant'], -1);
      final dir = asStr(action['dir']);
      _applyRotation(seat, q, dir);
      return;
    }

    if (type == 'move') {
      if (step != 'place') throw GameError('当前处于旋转阶段，请选择旋转方向');
      final cell = asInt(action['cell'], -1);
      final q = asInt(action['quadrant'], -1);
      final dir = asStr(action['dir']);
      if (cell < 0 || cell >= 36 || board[cell] != -1) {
        throw GameError('落子位置无效或已有棋子');
      }
      if (q < 0 || q >= 4 || (dir != 'cw' && dir != 'ccw')) {
        throw GameError('旋转象限或方向无效');
      }
      _applyPlacement(seat, cell);
      if (!_over) {
        _applyRotation(seat, q, dir);
      }
      return;
    }

    throw GameError('未知操作类型');
  }

  void _applyPlacement(int seat, int cell) {
    if (cell < 0 || cell >= 36) throw GameError('落子位置超出范围');
    if (board[cell] != -1) throw GameError('该位置已有棋子');

    board[cell] = turnColor;
    lastPlaced = cell;

    // Check if placing the marble already forms 5-in-a-row before rotation
    final preLine = findWinLine(board, turnColor);
    if (preLine != null) {
      moveCount++;
      _over = true;
      winner = seat;
      winLine = preLine;
      _placings = rankWinners(2, [seat]);
      resultText = '${name(seat)} 连成五子获胜！';
      host.log(resultText);
      return;
    }

    step = 'rotate';
  }

  void _applyRotation(int seat, int q, String dir) {
    if (q < 0 || q >= 4) throw GameError('请选择要旋转的象限 (0..3)');
    if (dir != 'cw' && dir != 'ccw') throw GameError('旋转方向必须是 cw 或 ccw');

    board = rotateQuadrant(board, q, dir);
    lastQuadrant = q;
    lastDir = dir;
    moveCount++;

    final win0 = findWinLine(board, 0);
    final win1 = findWinLine(board, 1);

    if (win0 != null && win1 != null) {
      // Simultaneous 5-in-a-row for both players -> Draw!
      _over = true;
      winner = -1;
      winLine = win0;
      _placings = [1, 1];
      resultText = '旋转后双方同时连成五子，本局平局！';
      host.log(resultText);
      return;
    }

    if (win0 != null || win1 != null) {
      final winColor = win0 != null ? 0 : 1;
      final winSeat = seatOfColor(winColor);
      _over = true;
      winner = winSeat;
      winLine = (win0 ?? win1)!;
      _placings = rankWinners(2, [winSeat]);
      resultText = '${name(winSeat)} 连成五子获胜！';
      host.log(resultText);
      return;
    }

    // Check if all 36 cells are full
    if (!board.contains(-1)) {
      _over = true;
      winner = -1;
      _placings = [1, 1];
      resultText = '棋盘已满且无人五连，本局平局！';
      host.log(resultText);
      return;
    }

    turnColor = 1 - turnColor;
    step = 'place';
  }

  /// Check whether `color` has an immediate 1-turn win from `b` (either by placing
  /// directly or by placing + rotating one quadrant).
  /// Because rotation is a bijection on the 36 cells, placing then rotating `R`
  /// is equivalent to rotating `R` then placing on an empty cell!
  static bool hasImmediateWinThreat(List<int> b, int color) {
    if (_hasFourAndOneEmpty(b, color)) return true;
    for (var q = 0; q < 4; q++) {
      for (final dir in const ['cw', 'ccw']) {
        final rb = rotateQuadrant(b, q, dir);
        if (_hasFourAndOneEmpty(rb, color)) return true;
      }
    }
    return false;
  }

  static bool _hasFourAndOneEmpty(List<int> b, int color) {
    for (final line in pentagoLines) {
      var countC = 0;
      var countEmpty = 0;
      for (var i = 0; i < 5; i++) {
        final v = b[line[i]];
        if (v == color) {
          countC++;
        } else if (v == -1) {
          countEmpty++;
        } else {
          countC = -1;
          break;
        }
      }
      if (countC == 4 && countEmpty == 1) return true;
    }
    return false;
  }

  /// Heuristic evaluation of board `b` from the perspective of `myColor`.
  static double evaluateBoard(List<int> b, int myColor) {
    final oppColor = 1 - myColor;
    var score = 0.0;

    // Quadrant centers (7, 10, 25, 28) are rotationally invariant in their own quadrant
    const centers = [7, 10, 25, 28];
    for (final idx in centers) {
      if (b[idx] == myColor) score += 16.0;
      if (b[idx] == oppColor) score -= 16.0;
    }

    for (final line in pentagoLines) {
      var myCnt = 0;
      var oppCnt = 0;
      for (var i = 0; i < 5; i++) {
        final v = b[line[i]];
        if (v == myColor) {
          myCnt++;
        } else if (v == oppColor) {
          oppCnt++;
        }
      }
      if (oppCnt == 0 && myCnt > 0) {
        score += switch (myCnt) {
          1 => 3.0,
          2 => 20.0,
          3 => 120.0,
          4 => 750.0,
          _ => 10000.0,
        };
      } else if (myCnt == 0 && oppCnt > 0) {
        score -= switch (oppCnt) {
          1 => 3.0,
          2 => 24.0,
          3 => 150.0,
          4 => 900.0,
          _ => 10000.0,
        };
      }
    }
    return score;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turnSeat) return null;
    final myColor = turnColor;
    final oppColor = 1 - myColor;

    // If a human placed a piece and disconnected during 'rotate' step
    if (step == 'rotate') {
      final (q, dir) = _bestRotationOnly(board, myColor, oppColor);
      return {'type': 'rotate', 'quadrant': q, 'dir': dir};
    }

    final emptyCells = [for (var i = 0; i < 36; i++) if (board[i] == -1) i];
    if (emptyCells.isEmpty) return null;

    // 1. Check immediate win by placement alone (before rotation)
    for (final c in emptyCells) {
      board[c] = myColor;
      final win = findWinLine(board, myColor) != null;
      board[c] = -1;
      if (win) {
        return {'type': 'move', 'cell': c, 'quadrant': 0, 'dir': 'cw'};
      }
    }

    // 2. Check immediate win by placement + rotation
    for (final c in emptyCells) {
      board[c] = myColor;
      for (var q = 0; q < 4; q++) {
        for (final dir in const ['cw', 'ccw']) {
          final rb = rotateQuadrant(board, q, dir);
          final myWin = findWinLine(rb, myColor) != null;
          final oppWin = findWinLine(rb, oppColor) != null;
          if (myWin && !oppWin) {
            board[c] = -1;
            return {'type': 'move', 'cell': c, 'quadrant': q, 'dir': dir};
          }
        }
      }
      board[c] = -1;
    }

    // Easy bot: occasional random legal move (that doesn't immediately lose)
    if (botLevel == 0 && rng.nextDouble() < 0.45) {
      final c = emptyCells[rng.nextInt(emptyCells.length)];
      final q = rng.nextInt(4);
      final dir = rng.nextBool() ? 'cw' : 'ccw';
      return {'type': 'move', 'cell': c, 'quadrant': q, 'dir': dir};
    }

    // 3. Tactical search: score all (cell, q, dir) moves, blocking opponent threats
    var bestScore = -1e12;
    var bestCell = emptyCells.first;
    var bestQ = 0;
    var bestDir = 'cw';

    for (final c in emptyCells) {
      final placed = List<int>.of(board)..[c] = myColor;
      for (var q = 0; q < 4; q++) {
        for (final dir in const ['cw', 'ccw']) {
          final rb = rotateQuadrant(placed, q, dir);
          if (findWinLine(rb, oppColor) != null) {
            // Never rotate opponent into an immediate 5-in-a-row unless forced
            continue;
          }
          var s = evaluateBoard(rb, myColor);
          if (botLevel >= 1 && hasImmediateWinThreat(rb, oppColor)) {
            s -= 50000.0;
          }
          if (botLevel >= 2 && hasImmediateWinThreat(rb, myColor)) {
            s += 600.0;
          }
          s += rng.nextDouble() * 2.5;
          if (s > bestScore) {
            bestScore = s;
            bestCell = c;
            bestQ = q;
            bestDir = dir;
          }
        }
      }
    }

    return {'type': 'move', 'cell': bestCell, 'quadrant': bestQ, 'dir': bestDir};
  }

  (int, String) _bestRotationOnly(List<int> b, int myColor, int oppColor) {
    var bestScore = -1e12;
    var bestQ = 0;
    var bestDir = 'cw';
    for (var q = 0; q < 4; q++) {
      for (final dir in const ['cw', 'ccw']) {
        final rb = rotateQuadrant(b, q, dir);
        final myWin = findWinLine(rb, myColor) != null;
        final oppWin = findWinLine(rb, oppColor) != null;
        if (myWin && !oppWin) return (q, dir);
        if (oppWin) continue;
        final s = evaluateBoard(rb, myColor) - (hasImmediateWinThreat(rb, oppColor) ? 50000.0 : 0.0);
        if (s > bestScore) {
          bestScore = s;
          bestQ = q;
          bestDir = dir;
        }
      }
    }
    return (bestQ, bestDir);
  }

  @override
  Map<String, dynamic> view(int seat) => {
        'board': List<int>.of(board),
        'blackSeat': blackSeat,
        'whiteSeat': 1 - blackSeat,
        'turnColor': turnColor,
        'turnSeat': turnSeat,
        'step': step,
        'lastPlaced': lastPlaced,
        'lastQuadrant': lastQuadrant,
        'lastDir': lastDir,
        'moveCount': moveCount,
        'over': _over,
        'winner': winner,
        'result': _over ? resultText : null,
        'winLine': winLine,
        if (_placings != null) 'placings': _placings,
      };
}
