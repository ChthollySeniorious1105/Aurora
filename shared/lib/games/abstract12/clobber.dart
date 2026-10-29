import '../../src/engine.dart';

const List<(int, int)> kClobberOrthoDirs = [
  (-1, 0),
  (1, 0),
  (0, -1),
  (0, 1),
];

class ClobberMove {
  final int fromR;
  final int fromC;
  final int toR;
  final int toC;

  const ClobberMove(this.fromR, this.fromC, this.toR, this.toC);

  Map<String, dynamic> toAction() => {
        'type': 'move',
        'fromR': fromR,
        'fromC': fromC,
        'toR': toR,
        'toC': toC,
      };
}

class ClobberGame extends GameEngine {
  late int rows;
  late int cols;

  /// 2D grid [rows][cols]: 0 = empty, 1 = Black (seat 0), 2 = White (seat 1).
  late List<List<int>> board;

  int turn = 0;
  int moveCount = 0;
  bool over = false;
  int? winner;
  List<int>? finalPlacings;
  String? resultText;
  Map<String, dynamic>? lastMove;

  ClobberGame(super.setup);

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
    final sizeOpt = setup.opt<String>('size', 'quick');
    if (sizeOpt == 'standard') {
      rows = 6;
      cols = 6;
    } else {
      rows = 5;
      cols = 6;
    }

    board = List.generate(
      rows,
      (r) => List.generate(cols, (c) => ((r + c) % 2 == 0) ? 1 : 2),
    );
    turn = 0;
    moveCount = 0;
    over = false;
    winner = null;
    finalPlacings = null;
    resultText = null;
    lastMove = null;
  }

  bool inBounds(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;

  bool canMove(int seat, int r1, int c1, int r2, int c2) {
    if (!inBounds(r1, c1) || !inBounds(r2, c2)) return false;
    final dist = (r1 - r2).abs() + (c1 - c2).abs();
    if (dist != 1) return false;
    final myStone = seat + 1;
    final oppStone = 2 - seat;
    return board[r1][c1] == myStone && board[r2][c2] == oppStone;
  }

  List<ClobberMove> legalMovesFor(int seat) {
    final myStone = seat + 1;
    final oppStone = 2 - seat;
    final moves = <ClobberMove>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (board[r][c] != myStone) continue;
        for (final (dr, dc) in kClobberOrthoDirs) {
          final nr = r + dr;
          final nc = c + dc;
          if (inBounds(nr, nc) && board[nr][nc] == oppStone) {
            moves.add(ClobberMove(r, c, nr, nc));
          }
        }
      }
    }
    return moves;
  }

  int countStones(int seat) {
    final target = seat + 1;
    var count = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (board[r][c] == target) count++;
      }
    }
    return count;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行棋');

    final type = asStr(action['type']);
    if (type != 'move') throw GameError('未知操作类型：$type');

    final r1 = asInt(action['fromR']);
    final c1 = asInt(action['fromC']);
    final r2 = asInt(action['toR']);
    final c2 = asInt(action['toC']);

    if (!canMove(seat, r1, c1, r2, c2)) {
      throw GameError('非法移动：必须将己方棋子正交移动 1 格并压吃相邻的敌方棋子');
    }

    board[r2][c2] = seat + 1;
    board[r1][c1] = 0;
    moveCount++;

    lastMove = {
      'seat': seat,
      'fromR': r1,
      'fromC': c1,
      'toR': r2,
      'toC': c2,
    };

    host.log('${name(seat)} 压吃 (${r1 + 1},${c1 + 1}) → (${r2 + 1},${c2 + 1})');

    final nextSeat = 1 - seat;
    if (legalMovesFor(nextSeat).isEmpty) {
      over = true;
      winner = seat;
      finalPlacings = rankWinners(2, [seat]);
      resultText = '${name(nextSeat)} 已无相邻敌子可吃，${name(seat)} 获胜！';
      host.log('游戏结束：$resultText');
      return;
    }

    turn = nextSeat;
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
    final moves = over ? const <ClobberMove>[] : legalMovesFor(turn);
    return {
      'rows': rows,
      'cols': cols,
      'board': [
        for (final row in board) List<int>.of(row),
      ],
      'stoneCounts': [countStones(0), countStones(1)],
      'turn': turn,
      'moveCount': moveCount,
      'legalMoves': [
        for (final m in moves)
          {
            'fromR': m.fromR,
            'fromC': m.fromC,
            'toR': m.toR,
            'toC': m.toC,
          },
      ],
      'lastMove': lastMove,
      'over': over,
      'winner': winner,
      'result': resultText,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    final moves = legalMovesFor(seat);
    if (moves.isEmpty) return null;

    if (botLevel == 0) {
      return moves[rng.nextInt(moves.length)].toAction();
    }

    final myStone = seat + 1;
    final oppStone = 2 - seat;
    ClobberMove best = moves.first;
    var bestScore = -1000000;

    for (final m in moves) {
      // Simulate move
      board[m.fromR][m.fromC] = 0;
      board[m.toR][m.toC] = myStone;

      final oppMoves = legalMovesFor(1 - seat);
      int sc;
      if (oppMoves.isEmpty) {
        // Immediate win!
        board[m.fromR][m.fromC] = myStone;
        board[m.toR][m.toC] = oppStone;
        return m.toAction();
      } else {
        // Prefer moves where our landing stone still has adjacent enemy stones (stays active)
        // while reducing isolated traps.
        var adjEnemyAtDest = 0;
        for (final (dr, dc) in kClobberOrthoDirs) {
          final nr = m.toR + dr;
          final nc = m.toC + dc;
          if (inBounds(nr, nc) && board[nr][nc] == oppStone) {
            adjEnemyAtDest++;
          }
        }
        sc = -oppMoves.length * 10 + adjEnemyAtDest * 15 + rng.nextInt(7);

        if (botLevel >= 2 && oppMoves.length <= 12) {
          // 1-ply lookahead: avoid moves that allow opponent to immediately win
          var oppCanWinImmediately = false;
          for (final om in oppMoves) {
            board[om.fromR][om.fromC] = 0;
            board[om.toR][om.toC] = oppStone;
            if (legalMovesFor(seat).isEmpty) {
              oppCanWinImmediately = true;
            }
            board[om.fromR][om.fromC] = oppStone;
            board[om.toR][om.toC] = myStone;
            if (oppCanWinImmediately) break;
          }
          if (oppCanWinImmediately) sc -= 5000;
        }
      }

      // Undo move
      board[m.fromR][m.fromC] = myStone;
      board[m.toR][m.toC] = oppStone;

      if (sc > bestScore) {
        bestScore = sc;
        best = m;
      }
    }

    return best.toAction();
  }
}
