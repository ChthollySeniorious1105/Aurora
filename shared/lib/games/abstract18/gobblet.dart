import '../../src/engine.dart';

/// 套杯棋（Gobblet）—— Thierry Denoual 创作的 4×4 四阶套杯吞噬、揭盖显影与四连博弈名作。
///
/// 核心规则：
/// - 棋盘为 `4×4` 网格（`r in 0..3, c in 0..3`），每个格子维护一个套杯堆栈 `List<(int owner, int size)>`，只有**最顶层（最后一个元素）**的套杯可见且生效！
/// - 每位玩家拥有 **12 枚套杯**（尺寸 `1..4`，4 号最大），初始在场外整齐码放为 **3 摞外部套杯栈** `[1, 2, 3, 4]`（顶部为 4 号大杯）。
/// - **两种合法行动**：
///   1. **盘面移杯（`'move'`）**：拿起棋盘上任意一枚**顶层属于己方**的套杯 `(fromR, fromC)`，将其移至另一个空格或顶层套杯尺寸严格更小的格子 `(toR, toC)`（`top.size < piece.size`，可吞套敌方或己方更小的杯子）。*注意：掀起己方套杯可能会直接暴露压在底下的敌方套杯！*
///   2. **场外入场（`'place'`）**：从己方 3 摞场外套杯栈中选择非空的一摞 `stackIdx (0..2)`，取出其栈顶套杯放入棋盘上的**任意空格 `(toR, toC)`**；
///      **场外吞套特例**：场外套杯通常只能放入空格，唯有当对手在某条线上（横/竖/斜）已经形成 **3 枚可见敌方套杯** 时，才允许直接从场外拿大杯吞套该条三连线上的敌方较小套杯！
/// - **胜负判定**：
///   - 行动完成后，若某方在横、竖或对角线上形成 **4 枚同色可见顶层套杯连线**，即获胜！
///   - **揭盖自杀警告**：若你掀起棋盘上的己方套杯时，底层露出的敌方套杯恰好为对手补齐了 4 连线，而你的这一步落点又未能重新盖住该 4 连线中的另一格，则对手立即获胜！
class GobbletGame extends GameEngine {
  GobbletGame(super.setup);

  static const int kSize = 4;

  static const List<List<(int, int)>> kLines4 = [
    // Rows
    [(0, 0), (0, 1), (0, 2), (0, 3)],
    [(1, 0), (1, 1), (1, 2), (1, 3)],
    [(2, 0), (2, 1), (2, 2), (2, 3)],
    [(3, 0), (3, 1), (3, 2), (3, 3)],
    // Columns
    [(0, 0), (1, 0), (2, 0), (3, 0)],
    [(0, 1), (1, 1), (2, 1), (3, 1)],
    [(0, 2), (1, 2), (2, 2), (3, 2)],
    [(0, 3), (1, 3), (2, 3), (3, 3)],
    // Diagonals
    [(0, 0), (1, 1), (2, 2), (3, 3)],
    [(0, 3), (1, 2), (2, 1), (3, 0)],
  ];

  late String mode;

  /// `board[r][c]` holds the stack of gobblets from bottom to top `(owner, size)`.
  late List<List<List<(int, int)>>> board;

  /// `externalStacks[seat][stackIdx]` holds sizes `[1, 2, 3, 4]` from bottom to top.
  late List<List<List<int>>> externalStacks;

  int turn = 0;
  bool over = false;
  int? winner;
  String? winReason;
  List<(int, int)> winningCells = [];
  List<int>? _placings;
  int moveCount = 0;
  Map<String, dynamic>? lastMove;

  static bool inBounds(int r, int c) => r >= 0 && r < kSize && c >= 0 && c < kSize;

  (int, int)? topAt(int r, int c) =>
      board[r][c].isEmpty ? null : board[r][c].last;

  @override
  void start() {
    mode = setup.opt<String>('mode', 'standard');
    board = List.generate(
      kSize,
      (_) => List.generate(kSize, (_) => <(int, int)>[]),
    );
    externalStacks = [
      [
        [1, 2, 3, 4],
        [1, 2, 3, 4],
        [1, 2, 3, 4],
      ],
      [
        [1, 2, 3, 4],
        [1, 2, 3, 4],
        [1, 2, 3, 4],
      ],
    ];
    turn = 0;
    over = false;
    winner = null;
    winReason = null;
    winningCells = [];
    _placings = null;
    moveCount = 0;
    lastMove = null;
  }

  void clearBoard() {
    for (var r = 0; r < kSize; r++) {
      for (var c = 0; c < kSize; c++) {
        board[r][c].clear();
      }
    }
  }

  /// Checks if cell `(r, c)` has a visible top piece of `oppSeat` that belongs to at least one
  /// line of 4 containing 3 or more visible top pieces of `oppSeat`.
  bool isInOpponentLineOfThree(int oppSeat, int r, int c, [List<List<List<(int, int)>>>? b]) {
    final grid = b ?? board;
    final cellStack = grid[r][c];
    if (cellStack.isEmpty || cellStack.last.$1 != oppSeat) return false;

    for (final line in kLines4) {
      if (!line.contains((r, c))) continue;
      var oppCount = 0;
      for (final (lr, lc) in line) {
        final st = grid[lr][lc];
        if (st.isNotEmpty && st.last.$1 == oppSeat) {
          oppCount++;
        }
      }
      if (oppCount >= 3) return true;
    }
    return false;
  }

  /// Returns the 4 cells of a winning line for `seat` on `grid`, or `null` if none.
  static List<(int, int)>? findWinningLine(int seat, List<List<List<(int, int)>>> grid) {
    for (final line in kLines4) {
      var ok = true;
      for (final (r, c) in line) {
        final st = grid[r][c];
        if (st.isEmpty || st.last.$1 != seat) {
          ok = false;
          break;
        }
      }
      if (ok) return line;
    }
    return null;
  }

  bool canPlaceFromStack(int seat, int stackIdx, int toR, int toC) {
    if (stackIdx < 0 || stackIdx >= 3) return false;
    if (externalStacks[seat][stackIdx].isEmpty) return false;
    if (!inBounds(toR, toC)) return false;

    final size = externalStacks[seat][stackIdx].last;
    final top = topAt(toR, toC);
    if (top == null) return true;

    // External gobblet can only gobble an opponent's strictly smaller piece
    // that is part of a line of 3 opponent pieces!
    final opp = 1 - seat;
    if (top.$1 != opp || top.$2 >= size) return false;
    return isInOpponentLineOfThree(opp, toR, toC);
  }

  bool canMoveOnBoard(int seat, int fromR, int fromC, int toR, int toC) {
    if (!inBounds(fromR, fromC) || !inBounds(toR, toC)) return false;
    if (fromR == toR && fromC == toC) return false;
    final srcTop = topAt(fromR, fromC);
    if (srcTop == null || srcTop.$1 != seat) return false;
    final dstTop = topAt(toR, toC);
    if (dstTop != null && dstTop.$2 >= srcTop.$2) return false;
    return true;
  }

  List<Map<String, dynamic>> legalMoves(int seat) {
    final res = <Map<String, dynamic>>[];

    // 1. Place from external stacks (deduplicate identical top sizes across stacks Only in AI if needed; list all valid stackIdx for UI)
    for (var sIdx = 0; sIdx < 3; sIdx++) {
      if (externalStacks[seat][sIdx].isEmpty) continue;
      final size = externalStacks[seat][sIdx].last;
      for (var r = 0; r < kSize; r++) {
        for (var c = 0; c < kSize; c++) {
          if (canPlaceFromStack(seat, sIdx, r, c)) {
            res.add({
              'type': 'place',
              'stackIdx': sIdx,
              'toR': r,
              'toC': c,
              'size': size,
            });
          }
        }
      }
    }

    // 2. Move exposed top piece on board
    for (var fr = 0; fr < kSize; fr++) {
      for (var fc = 0; fc < kSize; fc++) {
        final srcTop = topAt(fr, fc);
        if (srcTop == null || srcTop.$1 != seat) continue;
        for (var tr = 0; tr < kSize; tr++) {
          for (var tc = 0; tc < kSize; tc++) {
            if (canMoveOnBoard(seat, fr, fc, tr, tc)) {
              res.add({
                'type': 'move',
                'fromR': fr,
                'fromC': fc,
                'toR': tr,
                'toC': tc,
                'size': srcTop.$2,
              });
            }
          }
        }
      }
    }

    return res;
  }

  static List<List<List<(int, int)>>> _cloneBoard(List<List<List<(int, int)>>> src) => [
        for (var r = 0; r < kSize; r++)
          [
            for (var c = 0; c < kSize; c++) List<(int, int)>.of(src[r][c]),
          ],
      ];

  void _endGame(int winSeat, String reason, [List<(int, int)> cells = const []]) {
    over = true;
    winner = winSeat;
    winningCells = cells;
    _placings = winSeat == 0
        ? [1, 2]
        : (winSeat == 1 ? [2, 1] : [1, 1]);
    winReason = reason;
    host.log(reason);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('当前不是你的回合');

    final type = asStr(action['type']);
    final opp = 1 - seat;

    if (type == 'place') {
      final stackIdx = asInt(action['stackIdx'] ?? action['stack'], -1);
      final toR = asInt(action['toR'] ?? action['r'], -1);
      final toC = asInt(action['toC'] ?? action['c'], -1);

      if (stackIdx < 0 || stackIdx >= 3) throw GameError('外部套杯栈编号无效');
      if (externalStacks[seat][stackIdx].isEmpty) throw GameError('所选外部套杯栈已空');
      if (!inBounds(toR, toC)) throw GameError('目标棋盘格 ($toR, $toC) 越界');

      final size = externalStacks[seat][stackIdx].last;
      final dstTop = topAt(toR, toC);
      if (dstTop != null) {
        if (dstTop.$1 == seat) {
          throw GameError('场外套杯不能直接套在己方棋盘套杯上（必须放入空格）');
        }
        if (dstTop.$2 >= size) {
          throw GameError('只能用尺寸更大的套杯吞套尺寸更小的套杯');
        }
        if (!isInOpponentLineOfThree(opp, toR, toC)) {
          throw GameError('场外套杯只能放入空格，除非目标格上的敌方套杯已处于敌方三连线中！');
        }
      }

      externalStacks[seat][stackIdx].removeLast();
      board[toR][toC].add((seat, size));
      moveCount++;

      lastMove = {
        'type': 'place',
        'seat': seat,
        'stackIdx': stackIdx,
        'toR': toR,
        'toC': toC,
        'size': size,
        'gobbled': dstTop != null,
      };
      host.log(
        '${name(seat)} 从场外第 ${stackIdx + 1} 栈取出 $size 号套杯放入 ($toR, $toC)'
        '${dstTop != null ? '（吞套 ${dstTop.$2} 号杯）' : ''}',
      );
    } else if (type == 'move') {
      final fromR = asInt(action['fromR'], -1);
      final fromC = asInt(action['fromC'], -1);
      final toR = asInt(action['toR'], -1);
      final toC = asInt(action['toC'], -1);

      if (!inBounds(fromR, fromC) || !inBounds(toR, toC)) {
        throw GameError('棋盘坐标越界');
      }
      if (fromR == toR && fromC == toC) {
        throw GameError('目标格不能与起始格相同');
      }
      final srcTop = topAt(fromR, fromC);
      if (srcTop == null || srcTop.$1 != seat) {
        throw GameError('起始格 ($fromR, $fromC) 顶层没有你的套杯');
      }
      final dstTop = topAt(toR, toC);
      if (dstTop != null && dstTop.$2 >= srcTop.$2) {
        throw GameError('目标格 ($toR, $toC) 的套杯尺寸不小于你的 ${srcTop.$2} 号套杯，无法吞套');
      }

      board[fromR][fromC].removeLast();
      final uncovered = topAt(fromR, fromC);
      board[toR][toC].add(srcTop);
      moveCount++;

      lastMove = {
        'type': 'move',
        'seat': seat,
        'fromR': fromR,
        'fromC': fromC,
        'toR': toR,
        'toC': toC,
        'size': srcTop.$2,
        'gobbled': dstTop != null,
        'uncoveredOwner': uncovered?.$1,
      };
      host.log(
        '${name(seat)} 将 ${srcTop.$2} 号套杯从 ($fromR, $fromC) 移至 ($toR, $toC)'
        '${dstTop != null ? '（吞套 ${dstTop.$2} 号杯）' : ''}',
      );
    } else {
      throw GameError('未知操作类型：$type');
    }

    // Check victory! If lifting uncovered an opponent's 4-in-a-row and the move didn't cover it,
    // opponent wins first!
    final oppWin = findWinningLine(opp, board);
    if (oppWin != null) {
      _endGame(opp, '${name(seat)} 掀起套杯暴露出 ${name(opp)} 的四子连线且未能封堵，${name(opp)} 获胜！', oppWin);
      return;
    }

    final myWin = findWinningLine(seat, board);
    if (myWin != null) {
      _endGame(seat, '${name(seat)} 率先达成四枚顶层套杯连线，获得胜利！', myWin);
      return;
    }

    turn = opp;
    if (legalMoves(opp).isEmpty) {
      _endGame(seat, '${name(opp)} 无合法行动，${name(seat)} 获胜！');
      return;
    }

    final maxMoves = mode == 'quick' ? 80 : 120;
    if (moveCount >= maxMoves) {
      var top0 = 0;
      var top1 = 0;
      for (var r = 0; r < kSize; r++) {
        for (var c = 0; c < kSize; c++) {
          final t = topAt(r, c);
          if (t != null) {
            if (t.$1 == 0) {
              top0 += t.$2;
            } else {
              top1 += t.$2;
            }
          }
        }
      }
      if (top0 > top1) {
        _endGame(0, '达到回合上限，${name(0)} 盘面顶层套杯总阶数更高获胜！');
      } else if (top1 > top0) {
        _endGame(1, '达到回合上限，${name(1)} 盘面顶层套杯总阶数更高获胜！');
      } else {
        _endGame(-1, '达到回合上限，双方势均力敌握手言和！');
      }
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    final moves = legalMoves(seat);
    if (moves.isEmpty) return null;

    final opp = 1 - seat;
    final safeMoves = <Map<String, dynamic>>[];

    for (final m in moves) {
      final sim = _cloneBoard(board);
      if (m['type'] == 'place') {
        final tr = m['toR'] as int;
        final tc = m['toC'] as int;
        final sz = m['size'] as int;
        sim[tr][tc].add((seat, sz));
      } else {
        final fr = m['fromR'] as int;
        final fc = m['fromC'] as int;
        final tr = m['toR'] as int;
        final tc = m['toC'] as int;
        final p = sim[fr][fc].removeLast();
        sim[tr][tc].add(p);
      }
      // Do not play a move that uncovers an opponent 4-in-a-row
      if (findWinningLine(opp, sim) != null) continue;
      // Immediate win!
      if (findWinningLine(seat, sim) != null) return m;
      safeMoves.add(m);
    }

    final pool = safeMoves.isNotEmpty ? safeMoves : moves;
    if (botLevel <= 0) {
      return pool[rng.nextInt(pool.length)];
    }

    var bestScore = -1e9;
    var bestMoves = <Map<String, dynamic>>[];

    for (final m in pool) {
      final sim = _cloneBoard(board);
      if (m['type'] == 'place') {
        sim[m['toR'] as int][m['toC'] as int].add((seat, m['size'] as int));
      } else {
        final p = sim[m['fromR'] as int][m['fromC'] as int].removeLast();
        sim[m['toR'] as int][m['toC'] as int].add(p);
      }

      var val = _evaluateBoard(seat, sim) - _evaluateBoard(opp, sim) * 1.15;
      if (m['type'] == 'place') val += (m['size'] as int) * 2.5;
      val += rng.nextDouble() * 0.5;

      if (val > bestScore) {
        bestScore = val;
        bestMoves = [m];
      }
    }

    return bestMoves[rng.nextInt(bestMoves.length)];
  }

  static double _evaluateBoard(int seat, List<List<List<(int, int)>>> grid) {
    var score = 0.0;
    for (final line in kLines4) {
      var myCnt = 0;
      var oppCnt = 0;
      var mySizeSum = 0;
      for (final (r, c) in line) {
        final st = grid[r][c];
        if (st.isNotEmpty) {
          if (st.last.$1 == seat) {
            myCnt++;
            mySizeSum += st.last.$2;
          } else {
            oppCnt++;
          }
        }
      }
      if (myCnt == 4) {
        score += 10000.0;
      } else if (myCnt == 3 && oppCnt == 0) {
        score += 120.0 + mySizeSum * 4.0;
      } else if (myCnt == 3 && oppCnt == 1) {
        score += 45.0;
      } else if (myCnt == 2 && oppCnt == 0) {
        score += 18.0 + mySizeSum * 1.5;
      }
    }
    return score;
  }

  @override
  bool get canResign => !isOver;

  @override
  void resign(int seat) {
    if (over) throw GameError('对局已结束');
    _endGame(1 - seat, '${name(seat)} 认输，${name(1 - seat)} 获胜！');
  }

  @override
  bool get canDraw => !isOver;

  @override
  void agreeDraw() {
    if (over) throw GameError('对局已结束');
    _endGame(-1, '双方同意和棋！');
  }

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => _placings;

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'mode': mode,
      'board': [
        for (var r = 0; r < kSize; r++)
          [
            for (var c = 0; c < kSize; c++)
              [
                for (final (owner, size) in board[r][c])
                  {'owner': owner, 'size': size},
              ],
          ],
      ],
      'externalStacks': [
        for (var s = 0; s < 2; s++)
          [
            for (var idx = 0; idx < 3; idx++) List<int>.of(externalStacks[s][idx]),
          ],
      ],
      'turn': turn,
      'over': over,
      'winner': winner,
      'winReason': winReason,
      'winningCells': [
        for (final (r, c) in winningCells) [r, c],
      ],
      'moveCount': moveCount,
      'lastMove': lastMove,
      'legalMoves': over ? const [] : legalMoves(turn),
    };
  }
}
