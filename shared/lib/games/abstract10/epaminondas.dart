import '../../src/engine.dart';

const String epaminondasRules = '''
# 斜阵冲击棋 Epaminondas 规则说明

## 游戏概述
斜阵冲击棋（Epaminondas）是由著名博弈设计师 Robert Abbott 于 1975 年发明的经典战术抽象棋类，以古希腊底比斯名将伊巴密浓达（Epaminondas）独创的**斜线方阵战术（Phalanx）**命名。
两名玩家分别执**白棋（座位 0，先手，底排两行向上推进）**与**黑棋（座位 1，后手，顶排两行向下推进）**，通过构筑横、竖、斜方阵进行机动推进、压制冲锋与底线突破！

## 初始布局
- **快速棋盘（8×10）**：8 行 10 列，双方各 20 枚棋子，铺满各自底线的最后两整行。
- **标准棋盘（10×12）**：10 行 12 列，双方各 24 枚棋子，铺满各自底线的最后两整行。
- 白方（座位 0）初始位于最下方两行（`r = H-2, H-1`），目标底线为顶行 `r = 0`；黑方（座位 1）初始位于最上方两行（`r = 0, 1`），目标底线为底行 `r = H-1`。

## 移动与方阵冲锋吃子
每回合玩家必须执行 1 次移动（单子移动或方阵移动）：
- **单子移动（长度 `L = 1`）**：
  - 任选 1 枚己方棋子，向横、竖、斜 **8 个方向之一**移动 **1 步**到相邻的空位。
  - **单枚棋子不能吃子！**
- **方阵移动（Phalanx，长度 `L >= 2`）**：
  - 选择一条直线上（横、竖、斜均可）**连续紧邻的 `L` 枚己方棋子**组成方阵。
  - 整个方阵只能沿着**其自身排列所在的直线方向 `(dr, dc)`** 整体向前推进 `s` 步（`1 <= s <= L`，即最多移动不超过方阵自身长度的步数）。
  - 方阵前端经过的中间格必须全部为空（不能越过任何己方或敌方棋子）。
- **方阵冲锋吃子（Phalanx Capture）**：
  - 如果方阵最前端的棋子在第 `s` 步恰好落在一枚敌方棋子上，则触发方阵冲锋！
  - 从该敌方棋子开始，沿着方阵冲锋的同一方向 `(dr, dc)` 统计紧邻的**连续敌方棋子数量 `E`**。
  - **以长击短原则**：只有当你的**方阵长度严格大于敌方连续棋子数（`L > E`）**时，该冲锋才合法！
  - 冲锋成功后，该方向上这 **`E` 枚连续敌方棋子全部被击溃并从棋盘移除**，己方 `L` 枚方阵棋子停留在推进 `s` 步后的位置上。

## 获胜条件
1. **底线占优胜（Back-Rank Victory）**：
   - 在**任意玩家的回合开始时**，如果该玩家位于**对手底线**（白方在 `r = 0`，黑方在 `r = H-1`）上的己方棋子数量，**严格多于**对手位于自己底线上的棋子数量，则该玩家**立即获胜**！
   - 这意味着当一方率先有棋子冲入敌方底线后，对手拥有**一个回合的反击机会**（吃掉该底线棋子，或同样冲入对方底线追平/反超数量）。
2. **全歼/困毙胜**：若一方将对手所有棋子全部吃光，或令对手无任何合法移动，立即获胜。

## 房间选项
- **棋盘规模（size）**：支持 `8×10 快速`（`'quick'`）与 `10×12 标准`（`'standard'`）。
''';

class EpaminondasMove {
  final int tailR;
  final int tailC;
  final int dr;
  final int dc;
  final int len;
  final int steps;
  final int capturedCount;

  const EpaminondasMove({
    required this.tailR,
    required this.tailC,
    required this.dr,
    required this.dc,
    required this.len,
    required this.steps,
    required this.capturedCount,
  });

  int get headR => tailR + (len - 1) * dr;
  int get headC => tailC + (len - 1) * dc;
  int get targetR => headR + steps * dr;
  int get targetC => headC + steps * dc;

  Map<String, dynamic> toAction() => {
        'type': 'move',
        'r': tailR,
        'c': tailC,
        'dr': dr,
        'dc': dc,
        'len': len,
        'steps': steps,
        'from': [tailR, tailC],
        'to': [targetR, targetC],
      };
}

class EpaminondasGame extends GameEngine {
  late final String sizeMode;
  late final int rows;
  late final int cols;

  /// 0 = empty, 1 = White (Player 0, bottom -> top), 2 = Black (Player 1, top -> bottom)
  late List<List<int>> board;
  final List<int> captured = [0, 0];

  int turn = 0;
  int moveCount = 0;
  bool over = false;
  int? winner;
  String? winReason;
  Map<String, dynamic>? lastMove;

  EpaminondasGame(super.setup) {
    sizeMode = setup.opt<String>('size', 'quick');
    if (sizeMode == 'standard') {
      rows = 10;
      cols = 12;
    } else {
      rows = 8;
      cols = 10;
    }
  }

  static const List<(int, int)> dirs8 = [
    (-1, -1),
    (-1, 0),
    (-1, 1),
    (0, -1),
    (0, 1),
    (1, -1),
    (1, 0),
    (1, 1),
  ];

  @override
  void start() {
    board = List.generate(rows, (r) {
      if (r <= 1) return List<int>.filled(cols, 2);
      if (r >= rows - 2) return List<int>.filled(cols, 1);
      return List<int>.filled(cols, 0);
    });
    captured[0] = 0;
    captured[1] = 0;
    turn = 0;
    moveCount = 0;
    over = false;
    winner = null;
    winReason = null;
    lastMove = null;
    host.log('斜阵冲击棋 Epaminondas 开始：${rows}×$cols 棋盘，构筑方阵冲锋并突破敌方底线！');
  }

  bool inBounds(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  bool get canResign => !over;

  @override
  void resign(int seat) {
    if (over) throw GameError('游戏已结束');
    if (seat < 0 || seat >= 2) throw GameError('无效座位');
    over = true;
    winner = 1 - seat;
    winReason = 'resign';
    host.log('${name(seat)} 认输，${name(winner!)} 获胜！');
  }

  @override
  bool get canDraw => !over;

  @override
  void agreeDraw() {
    if (over) throw GameError('游戏已结束');
    over = true;
    winner = -1;
    winReason = 'draw';
    host.log('双方同意和棋！');
  }

  @override
  List<int>? get placings {
    if (!over) return null;
    if (winner == 0) return const [1, 2];
    if (winner == 1) return const [2, 1];
    return const [1, 1];
  }

  /// Number of [seat]'s stones currently on the opponent's back rank
  /// (row 0 for seat 0, row rows-1 for seat 1).
  int backRankCount(int seat) {
    final targetRow = seat == 0 ? 0 : rows - 1;
    final me = seat + 1;
    var count = 0;
    for (var c = 0; c < cols; c++) {
      if (board[targetRow][c] == me) count++;
    }
    return count;
  }

  int stoneCount(int seat) {
    final me = seat + 1;
    var count = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (board[r][c] == me) count++;
      }
    }
    return count;
  }

  (int, int)? _parseCell(Object? raw) {
    if (raw is List && raw.length >= 2) {
      return (asInt(raw[0], -1), asInt(raw[1], -1));
    }
    if (raw is int || raw is num) {
      final idx = asInt(raw, -1);
      if (idx >= 0 && idx < rows * cols) {
        return (idx ~/ cols, idx % cols);
      }
    }
    return null;
  }

  /// Validates and parses an action into an [EpaminondasMove], or throws [GameError].
  EpaminondasMove validateAction(int seat, Map<String, dynamic> action) {
    final type = asStr(action['type']);
    if (type != 'move') throw GameError('无效操作类型');

    final me = seat + 1;
    final opp = 2 - seat;
    final len = asInt(action['len'], 1);
    if (len < 1) throw GameError('方阵长度必须至少为 1');

    int tailR = -1;
    int tailC = -1;
    int dr = 0;
    int dc = 0;
    int steps = 1;

    if (action.containsKey('dr') && action.containsKey('dc')) {
      final r = asInt(action['r'], -1);
      final c = asInt(action['c'], -1);
      dr = asInt(action['dr'], 0);
      dc = asInt(action['dc'], 0);
      steps = asInt(action['steps'], 1);

      if (!inBounds(r, c)) throw GameError('起始坐标超出棋盘范围');
      if (dr.abs() > 1 || dc.abs() > 1 || (dr == 0 && dc == 0)) {
        throw GameError('无效的移动方向');
      }
      if (board[r][c] != me) throw GameError('起始格没有己方棋子');

      if (len == 1) {
        tailR = r;
        tailC = c;
      } else {
        // Check if (r, c) is the tail stone (stones at r + i*dr, c + i*dc for i=0..len-1)
        var forwardAllMe = true;
        for (var i = 0; i < len; i++) {
          final nr = r + i * dr;
          final nc = c + i * dc;
          if (!inBounds(nr, nc) || board[nr][nc] != me) {
            forwardAllMe = false;
            break;
          }
        }
        var backwardAllMe = true;
        for (var i = 0; i < len; i++) {
          final nr = r - i * dr;
          final nc = c - i * dc;
          if (!inBounds(nr, nc) || board[nr][nc] != me) {
            backwardAllMe = false;
            break;
          }
        }

        if (forwardAllMe && backwardAllMe) {
          // Both directions have len friendly stones; pick the one whose front cell is not me
          final frontIfTailR = r + len * dr;
          final frontIfTailC = c + len * dc;
          if (inBounds(frontIfTailR, frontIfTailC) &&
              board[frontIfTailR][frontIfTailC] != me) {
            tailR = r;
            tailC = c;
          } else {
            tailR = r - (len - 1) * dr;
            tailC = c - (len - 1) * dc;
          }
        } else if (forwardAllMe) {
          tailR = r;
          tailC = c;
        } else if (backwardAllMe) {
          tailR = r - (len - 1) * dr;
          tailC = c - (len - 1) * dc;
        } else {
          throw GameError('无法沿该方向构成长度为 $len 的己方连续方阵');
        }
      }
    } else {
      final fromCell = _parseCell(action['from']) ??
          (action.containsKey('fromR')
              ? (asInt(action['fromR'], -1), asInt(action['fromC'], -1))
              : null);
      final toCell = _parseCell(action['to']) ??
          (action.containsKey('toR')
              ? (asInt(action['toR'], -1), asInt(action['toC'], -1))
              : null);
      if (fromCell == null || toCell == null) {
        throw GameError('缺少移动起止坐标');
      }
      final (fromR, fromC) = fromCell;
      final (toR, toC) = toCell;
      if (!inBounds(fromR, fromC) || !inBounds(toR, toC)) {
        throw GameError('移动坐标超出棋盘范围');
      }
      if (board[fromR][fromC] != me) {
        throw GameError('起始格没有己方棋子');
      }
      final diffR = toR - fromR;
      final diffC = toC - fromC;
      if (diffR == 0 && diffC == 0) {
        throw GameError('目标格不能与起始格相同');
      }
      if (diffR != 0 && diffC != 0 && diffR.abs() != diffC.abs()) {
        throw GameError('必须沿横、竖或对角线直线移动');
      }
      dr = diffR.sign;
      dc = diffC.sign;
      final dist = diffR.abs() > diffC.abs() ? diffR.abs() : diffC.abs();

      if (len == 1) {
        tailR = fromR;
        tailC = fromC;
        steps = asInt(action['steps'], dist);
      } else {
        var forwardAllMe = true;
        for (var i = 0; i < len; i++) {
          final nr = fromR + i * dr;
          final nc = fromC + i * dc;
          if (!inBounds(nr, nc) || board[nr][nc] != me) {
            forwardAllMe = false;
            break;
          }
        }
        var backwardAllMe = true;
        for (var i = 0; i < len; i++) {
          final nr = fromR - i * dr;
          final nc = fromC - i * dc;
          if (!inBounds(nr, nc) || board[nr][nc] != me) {
            backwardAllMe = false;
            break;
          }
        }

        final frontIfTailR = fromR + len * dr;
        final frontIfTailC = fromC + len * dc;
        final isTail = forwardAllMe &&
            (!backwardAllMe ||
                (inBounds(frontIfTailR, frontIfTailC) &&
                    board[frontIfTailR][frontIfTailC] != me));

        if (isTail) {
          tailR = fromR;
          tailC = fromC;
          if (action.containsKey('steps')) {
            steps = asInt(action['steps'], 1);
          } else if (dist >= len) {
            // toCell is where the head stone lands: head + steps * d = tail + (len - 1 + steps) * d
            steps = dist - (len - 1);
          } else {
            steps = dist;
          }
        } else if (backwardAllMe) {
          tailR = fromR - (len - 1) * dr;
          tailC = fromC - (len - 1) * dc;
          steps = asInt(action['steps'], dist);
        } else {
          throw GameError('无法沿该方向构成长度为 $len 的己方连续方阵');
        }
      }
    }

    if (steps < 1) throw GameError('移动步数必须至少为 1');
    if (len == 1 && steps > 1) {
      throw GameError('单枚棋子每次只能移动 1 步');
    }
    if (steps > len) {
      throw GameError('方阵移动步数（$steps）不能超过方阵长度（$len）');
    }

    for (var i = 0; i < len; i++) {
      final sr = tailR + i * dr;
      final sc = tailC + i * dc;
      if (!inBounds(sr, sc) || board[sr][sc] != me) {
        throw GameError('方阵棋子不连续或非己方棋子');
      }
    }

    final headR = tailR + (len - 1) * dr;
    final headC = tailC + (len - 1) * dc;

    // Intermediate steps 1 .. steps - 1 must be empty
    for (var k = 1; k < steps; k++) {
      final ir = headR + k * dr;
      final ic = headC + k * dc;
      if (!inBounds(ir, ic)) throw GameError('移动超出棋盘边界');
      if (board[ir][ic] != 0) {
        throw GameError('方阵推进路径中间格必须为空');
      }
    }

    final targetR = headR + steps * dr;
    final targetC = headC + steps * dc;
    if (!inBounds(targetR, targetC)) {
      throw GameError('目标位置超出棋盘范围');
    }

    final targetCell = board[targetR][targetC];
    if (targetCell == me) {
      throw GameError('不能移动到己方棋子占据的格子');
    }

    var enemyCount = 0;
    if (targetCell == opp) {
      if (len == 1) {
        throw GameError('单枚棋子不能吃子，只有长度 ≥ 2 的方阵才能冲锋吃子');
      }
      while (inBounds(targetR + enemyCount * dr, targetC + enemyCount * dc) &&
          board[targetR + enemyCount * dr][targetC + enemyCount * dc] == opp) {
        enemyCount++;
      }
      if (len <= enemyCount) {
        throw GameError('方阵长度（$len）必须严格大于敌方连续棋子数（$enemyCount）才能冲锋吃子');
      }
    }

    return EpaminondasMove(
      tailR: tailR,
      tailC: tailC,
      dr: dr,
      dc: dc,
      len: len,
      steps: steps,
      capturedCount: enemyCount,
    );
  }

  List<EpaminondasMove> generateLegalMoves(int seat) {
    final moves = <EpaminondasMove>[];
    final me = seat + 1;
    final opp = 2 - seat;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (board[r][c] != me) continue;

        for (final (dr, dc) in dirs8) {
          // Single-piece 1-step move
          final nr = r + dr;
          final nc = c + dc;
          if (inBounds(nr, nc) && board[nr][nc] == 0) {
            moves.add(
              EpaminondasMove(
                tailR: r,
                tailC: c,
                dr: dr,
                dc: dc,
                len: 1,
                steps: 1,
                capturedCount: 0,
              ),
            );
          }

          // Phalanx moves of length L >= 2 with (r, c) as tail
          var maxL = 1;
          while (
              inBounds(r + maxL * dr, c + maxL * dc) &&
              board[r + maxL * dr][c + maxL * dc] == me) {
            maxL++;
          }
          if (maxL < 2) continue;

          for (var len = 2; len <= maxL; len++) {
            final headR = r + (len - 1) * dr;
            final headC = c + (len - 1) * dc;
            // The square immediately in front of head cannot be me
            final frontR = headR + dr;
            final frontC = headC + dc;
            if (!inBounds(frontR, frontC) || board[frontR][frontC] == me) {
              continue;
            }

            for (var s = 1; s <= len; s++) {
              final tr = headR + s * dr;
              final tc = headC + s * dc;
              if (!inBounds(tr, tc)) break;
              final cell = board[tr][tc];
              if (cell == me) break;
              if (cell == 0) {
                moves.add(
                  EpaminondasMove(
                    tailR: r,
                    tailC: c,
                    dr: dr,
                    dc: dc,
                    len: len,
                    steps: s,
                    capturedCount: 0,
                  ),
                );
              } else if (cell == opp) {
                var enemyCount = 0;
                while (inBounds(tr + enemyCount * dr, tc + enemyCount * dc) &&
                    board[tr + enemyCount * dr][tc + enemyCount * dc] == opp) {
                  enemyCount++;
                }
                if (len > enemyCount) {
                  moves.add(
                    EpaminondasMove(
                      tailR: r,
                      tailC: c,
                      dr: dr,
                      dc: dc,
                      len: len,
                      steps: s,
                      capturedCount: enemyCount,
                    ),
                  );
                }
                // Cannot jump over enemy stones to go further steps
                break;
              }
            }
          }
        }
      }
    }
    return moves;
  }

  bool hasAnyLegalMove(int seat) => generateLegalMoves(seat).isNotEmpty;

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final move = validateAction(seat, action);
    final me = seat + 1;

    // Clear old phalanx stones
    for (var i = 0; i < move.len; i++) {
      board[move.tailR + i * move.dr][move.tailC + i * move.dc] = 0;
    }

    // Clear captured enemy stones if any
    final capturedCells = <List<int>>[];
    for (var j = 0; j < move.capturedCount; j++) {
      final cr = move.targetR + j * move.dr;
      final cc = move.targetC + j * move.dc;
      board[cr][cc] = 0;
      capturedCells.add([cr, cc]);
    }
    if (move.capturedCount > 0) {
      captured[seat] += move.capturedCount;
    }

    // Place shifted phalanx stones
    final newCells = <List<int>>[];
    for (var i = 0; i < move.len; i++) {
      final nr = move.tailR + (i + move.steps) * move.dr;
      final nc = move.tailC + (i + move.steps) * move.dc;
      board[nr][nc] = me;
      newCells.add([nr, nc]);
    }

    moveCount++;
    lastMove = {
      'seat': seat,
      'tailR': move.tailR,
      'tailC': move.tailC,
      'headR': move.headR,
      'headC': move.headC,
      'targetR': move.targetR,
      'targetC': move.targetC,
      'dr': move.dr,
      'dc': move.dc,
      'len': move.len,
      'steps': move.steps,
      'captured': capturedCells,
      'newCells': newCells,
    };

    if (move.capturedCount > 0) {
      host.log(
        '${name(seat)} 以 ${move.len} 子方阵冲锋，击溃 ${move.capturedCount} 枚敌子！',
      );
    }

    final nextSeat = 1 - seat;
    turn = nextSeat;

    // 1. At the start of nextSeat's turn, check if nextSeat has strictly more
    // stones on the opponent's back rank than the opponent has on theirs!
    final nextBack = backRankCount(nextSeat);
    final prevBack = backRankCount(seat);
    if (nextBack > prevBack) {
      over = true;
      winner = nextSeat;
      winReason = 'back_rank';
      host.log(
        '${name(nextSeat)} 回合开始时在敌方底线拥有 $nextBack 枚棋子（对手为 $prevBack 枚），达成底线突破获胜！',
      );
      return;
    }

    // 2. Check if nextSeat has no stones or no legal moves left
    if (stoneCount(nextSeat) == 0 || !hasAnyLegalMove(nextSeat)) {
      over = true;
      winner = seat;
      winReason = 'elimination';
      host.log('${name(nextSeat)} 已无合法移动，${name(seat)} 获胜！');
      return;
    }

    // 3. Safety move cap to prevent endless shuffling
    if (moveCount >= 220) {
      over = true;
      winReason = 'limit';
      final b0 = backRankCount(0);
      final b1 = backRankCount(1);
      if (b0 != b1) {
        winner = b0 > b1 ? 0 : 1;
      } else {
        final s0 = stoneCount(0);
        final s1 = stoneCount(1);
        if (s0 != s1) {
          winner = s0 > s1 ? 0 : 1;
        } else {
          winner = -1;
        }
      }
      if (winner == -1) {
        host.log('达到回合上限，双方势均力敌，和棋！');
      } else {
        host.log('达到回合上限，${name(winner!)} 凭借场上优势获胜！');
      }
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    String? resultText;
    if (over) {
      if (winner == -1 || winner == null) {
        resultText = '双方和棋！';
      } else if (winReason == 'back_rank') {
        resultText = '${name(winner!)} 底线突破占优获胜！';
      } else if (winReason == 'elimination') {
        resultText = '${name(winner!)} 歼灭/困毙对手获胜！';
      } else if (winReason == 'resign') {
        resultText = '${name(winner!)} 获胜（对手认输）！';
      } else {
        resultText = '${name(winner!)} 获胜！';
      }
    }

    return {
      'size': sizeMode,
      'rows': rows,
      'cols': cols,
      'board': [
        for (final row in board) List<int>.of(row),
      ],
      'captured': List<int>.of(captured),
      'stoneCounts': [stoneCount(0), stoneCount(1)],
      'backRankCounts': [backRankCount(0), backRankCount(1)],
      'turn': turn,
      'moveCount': moveCount,
      'over': over,
      'winner': winner,
      'winReason': winReason,
      'lastMove': lastMove,
      'result': resultText,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    final moves = generateLegalMoves(seat);
    if (moves.isEmpty) return null;

    final opp = 1 - seat;
    final forwardDir = seat == 0 ? -1 : 1;
    final oppBackRow = seat == 0 ? 0 : rows - 1;
    final myBackRow = seat == 0 ? rows - 1 : 0;

    final curMyBack = backRankCount(seat);
    final curOppBack = backRankCount(opp);

    EpaminondasMove bestMove = moves.first;
    double bestScore = double.negativeInfinity;

    for (final m in moves) {
      // Calculate resulting back-rank counts after move m
      var newMyBack = curMyBack;
      var newOppBack = curOppBack;

      // Did any of our old stones leave oppBackRow?
      for (var i = 0; i < m.len; i++) {
        if (m.tailR + i * m.dr == oppBackRow) newMyBack--;
      }
      // Did any of our new stones land on oppBackRow?
      for (var i = 0; i < m.len; i++) {
        if (m.tailR + (i + m.steps) * m.dr == oppBackRow) newMyBack++;
      }
      // Did we capture any opponent stones on myBackRow?
      for (var j = 0; j < m.capturedCount; j++) {
        if (m.targetR + j * m.dr == myBackRow) newOppBack--;
      }

      var score = 0.0;

      // CRITICAL: If at the end of our move newOppBack > newMyBack,
      // then at the start of opponent's turn opponent wins immediately!
      if (newOppBack > newMyBack) {
        score -= 500000.0;
      } else if (curOppBack > curMyBack) {
        // Saving ourselves from immediate loss!
        score += 500000.0;
      }

      // Strongly reward establishing a back-rank lead
      if (newMyBack > newOppBack) {
        score += (newMyBack - newOppBack) * 28000.0;
      }

      // Reward capturing opponent stones
      if (m.capturedCount > 0) {
        score += m.capturedCount * 2400.0 + m.len * 180.0;
      }

      // Reward forward progress toward opponent's back rank
      final forwardProgress = m.dr * forwardDir;
      if (forwardProgress > 0) {
        final distToGoal = (oppBackRow - m.targetR).abs();
        score += m.len * m.steps * 150.0 + (rows - distToGoal) * 95.0;
      } else if (forwardProgress == 0) {
        score += m.len * 25.0;
      } else {
        // Penalize retreating unless capturing
        if (m.capturedCount == 0) {
          score -= 180.0 * m.steps;
        }
      }

      // Prefer central columns slightly
      final centerC = (cols - 1) / 2.0;
      score += (cols - (m.targetC - centerC).abs()) * 8.0;

      final jitter =
          botLevel == 0 ? rng.nextDouble() * 600.0 : rng.nextDouble() * 15.0;
      if (score + jitter > bestScore) {
        bestScore = score + jitter;
        bestMove = m;
      }
    }

    return bestMove.toAction();
  }
}
