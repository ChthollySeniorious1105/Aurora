import '../../src/engine.dart';

/// 库巴推球棋（Kuba / Traboulet）—— 7×7 后方留空直线推球、劫争禁手与中立红球夺取抽象策略名作。
///
/// 核心规则：
/// - 棋盘为 `7×7` 正交网格（`board[r][c]`：`0` = 空格，`1` = 白球（座位 0），`2` = 黑球（座位 1），`3` = 中立红球）。
/// - 初始布置：
///   - 白球（`1`）：左上 `(0..1, 0..1)` 与右下 `(5..6, 5..6)` 两个 `2×2` 角落，共 `8` 枚；
///   - 黑球（`2`）：右上 `(0..1, 5..6)` 与左下 `(5..6, 0..1)` 两个 `2×2` 角落，共 `8` 枚；
///   - 中立红球（`3`）：中心曼哈顿距离 `|r - 3| + |c - 3| <= 2` 的十字菱形区域，共 `13` 枚。
/// - 后方留空推球法则（`{'type': 'push', 'r': r, 'c': c, 'dir': 0..3}`）：
///   - 方向编码：`0: 上 (-1, 0)`，`1: 右 (0, 1)`，`2: 下 (1, 0)`，`3: 左 (0, -1)`。
///   - 条件 1（后方留空 Open-Behind）：选中己方颜色弹球 `(r, c)`（`board[r][c] == seat + 1`），其推动反方向紧邻的一格 `(r - dr, c - dc)` 必须位于棋盘外或为空格（`0`）！
///   - 条件 2（禁止自推出界 No Self-Ejection）：从 `(r, c)` 沿 `(dr, dc)` 方向连续紧挨的一整排弹球整体向前平移 `1` 格，绝不能将己方颜色的弹球（`seat + 1`）推出棋盘边界！
///   - 条件 3（劫争禁手 Ko Rule）：推动后的棋盘整体状态不能与对手上一步行动之前的棋盘状态（`prevBoard`）完全相同！
/// - 夺球与连击奖励回合：
///   - 若将中立红球（`3`）或敌方弹球（`2 - seat`）推出 `7×7` 棋盘边界，则将其捕获（`redCaptured[seat]++` 或 `enemyCaptured[seat]++`），且只要对局尚未结束，捕获弹球的一方立即获得一次**额外奖励回合（Bonus Turn）**继续行动！
/// - 胜负条件：
///   - 率先捕获 **`7` 枚中立红球**（快速模式为 `5` 枚）或 **全部 `8` 枚敌方弹球**（或令对手无合法推球步数）的玩家立即获胜！
class KubaGame extends GameEngine {
  KubaGame(super.setup);

  static const int kSize = 7;

  /// 0: 上 (-1,0), 1: 右 (0,1), 2: 下 (1,0), 3: 左 (0,-1)
  static const List<(int, int)> kDirs = [
    (-1, 0),
    (0, 1),
    (1, 0),
    (0, -1),
  ];

  static const List<String> kDirNames = ['上', '右', '下', '左'];

  late String mode;
  late int targetRed;
  late List<List<int>> board;
  List<List<int>>? prevBoard;

  List<int> redCaptured = [0, 0];
  List<int> enemyCaptured = [0, 0];

  int turn = 0;
  bool bonusTurn = false;
  bool over = false;
  int? winner;
  String? winReason;
  List<int>? _placings;
  int moveCount = 0;
  Map<String, dynamic>? lastMove;

  static bool inBounds(int r, int c) => r >= 0 && r < kSize && c >= 0 && c < kSize;

  static List<List<int>> cloneBoard(List<List<int>> src) => [
        for (final row in src) List<int>.of(row),
      ];

  static bool boardsEqual(List<List<int>> a, List<List<int>> b) {
    for (var r = 0; r < kSize; r++) {
      for (var c = 0; c < kSize; c++) {
        if (a[r][c] != b[r][c]) return false;
      }
    }
    return true;
  }

  @override
  void start() {
    mode = setup.opt<String>('mode', 'standard');
    targetRed = mode == 'quick' ? 5 : 7;

    board = List.generate(kSize, (_) => List.filled(kSize, 0));
    for (var r = 0; r < kSize; r++) {
      for (var c = 0; c < kSize; c++) {
        if ((r <= 1 && c <= 1) || (r >= 5 && c >= 5)) {
          board[r][c] = 1; // White (Seat 0)
        } else if ((r <= 1 && c >= 5) || (r >= 5 && c <= 1)) {
          board[r][c] = 2; // Black (Seat 1)
        } else if ((r - 3).abs() + (c - 3).abs() <= 2) {
          board[r][c] = 3; // Neutral Red (13 marbles)
        }
      }
    }

    prevBoard = null;
    redCaptured = [0, 0];
    enemyCaptured = [0, 0];
    turn = 0;
    bonusTurn = false;
    over = false;
    winner = null;
    winReason = null;
    _placings = null;
    moveCount = 0;
    lastMove = null;
  }

  /// Returns `(nextBoard, ejectedMarble, lineLength)` if pushing `(r, c)` in `dir` is legal for `seat`,
  /// or `null` if illegal.
  (List<List<int>>, int, int)? simulatePush(int seat, int r, int c, int dir) {
    if (!inBounds(r, c) || dir < 0 || dir >= 4) return null;
    final myColor = seat + 1;
    if (board[r][c] != myColor) return null;

    final (dr, dc) = kDirs[dir];
    final br = r - dr;
    final bc = c - dc;
    // Condition 1 (Open Behind): cell behind must be off-board or empty
    if (inBounds(br, bc) && board[br][bc] != 0) return null;

    // Walk contiguous line of marbles starting at (r, c)
    var er = r;
    var ec = c;
    var len = 0;
    while (inBounds(er, ec) && board[er][ec] != 0) {
      er += dr;
      ec += dc;
      len++;
    }

    var ejected = 0;
    if (!inBounds(er, ec)) {
      final tailR = er - dr;
      final tailC = ec - dc;
      ejected = board[tailR][tailC];
      // Condition 2 (No Self-Ejection): cannot push own marble off the board
      if (ejected == myColor) return null;
    }

    final next = cloneBoard(board);
    // Shift line from tail back to (r, c)
    for (var k = len; k >= 1; k--) {
      final nr = r + dr * k;
      final nc = c + dc * k;
      final pr = r + dr * (k - 1);
      final pc = c + dc * (k - 1);
      if (inBounds(nr, nc)) {
        next[nr][nc] = board[pr][pc];
      }
    }
    next[r][c] = 0;

    // Condition 3 (Ko Rule): resulting board must not equal prevBoard
    if (prevBoard != null && boardsEqual(next, prevBoard!)) {
      return null;
    }

    return (next, ejected, len);
  }

  bool canPush(int seat, int r, int c, int dir) =>
      simulatePush(seat, r, c, dir) != null;

  List<Map<String, int>> legalMoves(int seat) {
    final res = <Map<String, int>>[];
    final myColor = seat + 1;
    for (var r = 0; r < kSize; r++) {
      for (var c = 0; c < kSize; c++) {
        if (board[r][c] != myColor) continue;
        for (var dir = 0; dir < 4; dir++) {
          final sim = simulatePush(seat, r, c, dir);
          if (sim != null) {
            res.add({
              'r': r,
              'c': c,
              'dir': dir,
              'ejected': sim.$2,
              'len': sim.$3,
            });
          }
        }
      }
    }
    return res;
  }

  int marbleCount(int color) {
    var cnt = 0;
    for (var r = 0; r < kSize; r++) {
      for (var c = 0; c < kSize; c++) {
        if (board[r][c] == color) cnt++;
      }
    }
    return cnt;
  }

  void _endGame(int winSeat, String reason) {
    over = true;
    winner = winSeat;
    if (winSeat == 0) {
      _placings = [1, 2];
    } else if (winSeat == 1) {
      _placings = [2, 1];
    } else {
      _placings = [1, 1];
    }
    winReason = reason;
    host.log(reason);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('当前不是你的回合');

    final type = asStr(action['type']);
    if (type != 'push') throw GameError('未知操作类型：$type');

    final r = asInt(action['r'], -1);
    final c = asInt(action['c'], -1);
    final dir = asInt(action['dir'], -1);

    if (!inBounds(r, c)) throw GameError('所选格子坐标越界');
    if (dir < 0 || dir >= 4) throw GameError('推动方向无效');
    final myColor = seat + 1;
    if (board[r][c] != myColor) throw GameError('只能选择己方颜色的弹球进行推动');

    final (dr, dc) = kDirs[dir];
    final br = r - dr;
    final bc = c - dc;
    if (inBounds(br, bc) && board[br][bc] != 0) {
      throw GameError('推动失败：所选弹球后方紧邻格 ($br, $bc) 必须为空格或棋盘外');
    }

    var er = r;
    var ec = c;
    while (inBounds(er, ec) && board[er][ec] != 0) {
      er += dr;
      ec += dc;
    }
    if (!inBounds(er, ec) && board[er - dr][ec - dc] == myColor) {
      throw GameError('推动失败：不能将己方颜色的弹球推出棋盘边界');
    }

    final sim = simulatePush(seat, r, c, dir);
    if (sim == null) {
      throw GameError('违反劫争禁手（Ko Rule）：不能立即还原对手上一步之前的棋盘状态');
    }

    final (nextBoard, ejected, lineLen) = sim;
    final beforeBoard = cloneBoard(board);
    board = nextBoard;
    moveCount++;

    final enemyColor = 2 - seat;
    var capturedRed = false;
    var capturedEnemy = false;
    if (ejected == 3) {
      redCaptured[seat]++;
      capturedRed = true;
    } else if (ejected == enemyColor) {
      enemyCaptured[seat]++;
      capturedEnemy = true;
    }

    lastMove = {
      'type': 'push',
      'seat': seat,
      'r': r,
      'c': c,
      'dir': dir,
      'len': lineLen,
      'ejected': ejected,
    };

    if (capturedRed) {
      host.log('${name(seat)} 从 ($r, $c) 向${kDirNames[dir]}推动 $lineLen 球，击落捕获 1 枚中立红球（已获 ${redCaptured[seat]}/$targetRed 红球）！');
    } else if (capturedEnemy) {
      host.log('${name(seat)} 从 ($r, $c) 向${kDirNames[dir]}推动 $lineLen 球，将 1 枚敌方弹球推出界外（已歼敌 ${enemyCaptured[seat]}/8 球）！');
    } else {
      host.log('${name(seat)} 从 ($r, $c) 向${kDirNames[dir]}推动 $lineLen 枚弹球');
    }

    // Check immediate win conditions
    if (redCaptured[seat] >= targetRed) {
      _endGame(
        seat,
        '${name(seat)} 率先夺取 ${redCaptured[seat]} 枚中立红球（目标 $targetRed 枚），获得胜利！',
      );
      return;
    }
    if (enemyCaptured[seat] >= 8 || marbleCount(enemyColor) == 0) {
      _endGame(
        seat,
        '${name(seat)} 将对手全部 8 枚弹球悉数推出界外，获得完胜！',
      );
      return;
    }

    final opp = 1 - seat;
    if (capturedRed || capturedEnemy) {
      // Bonus turn on capture! Marble count decreased, so Ko cannot occur.
      prevBoard = null;
      if (legalMoves(seat).isNotEmpty) {
        bonusTurn = true;
        return;
      }
      // If active player somehow has no legal moves on bonus turn, pass turn to opponent
      bonusTurn = false;
      turn = opp;
      if (legalMoves(opp).isEmpty) {
        _endGame(seat, '${name(opp)} 已无合法推球步数，${name(seat)} 获胜！');
      }
      return;
    }

    // Normal non-capturing move: store beforeBoard as prevBoard for Ko check
    prevBoard = beforeBoard;
    bonusTurn = false;
    turn = opp;

    if (legalMoves(opp).isEmpty) {
      _endGame(seat, '${name(opp)} 被完全封锁无路可推，${name(seat)} 获胜！');
      return;
    }

    // Safety cap against endless shuffling in automated simulations
    if (moveCount >= 180) {
      final s0 = redCaptured[0] * 10 + enemyCaptured[0] * 3;
      final s1 = redCaptured[1] * 10 + enemyCaptured[1] * 3;
      if (s0 > s1) {
        _endGame(
          0,
          '达到步数上限，${name(0)}（红球${redCaptured[0]}/歼敌${enemyCaptured[0]}）领先 ${name(1)}（红球${redCaptured[1]}/歼敌${enemyCaptured[1]}）获胜！',
        );
      } else if (s1 > s0) {
        _endGame(
          1,
          '达到步数上限，${name(1)}（红球${redCaptured[1]}/歼敌${enemyCaptured[1]}）领先 ${name(0)}（红球${redCaptured[0]}/歼敌${enemyCaptured[0]}）获胜！',
        );
      } else {
        _endGame(-1, '达到步数上限，双方捕获数相同，握手言和！');
      }
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    final moves = legalMoves(seat);
    if (moves.isEmpty) return null;

    if (botLevel <= 0) {
      // Even easy bots take immediate captures if available to keep games lively
      final caps = moves.where((m) => m['ejected']! > 0).toList();
      final pool = caps.isNotEmpty ? caps : moves;
      final pick = pool[rng.nextInt(pool.length)];
      return {
        'type': 'push',
        'r': pick['r'],
        'c': pick['c'],
        'dir': pick['dir'],
      };
    }

    final myColor = seat + 1;
    final oppColor = 2 - seat;
    var bestScore = -1e9;
    var bestMoves = <Map<String, int>>[];

    for (final m in moves) {
      final r = m['r']!;
      final c = m['c']!;
      final dir = m['dir']!;
      final ejected = m['ejected']!;
      final sim = simulatePush(seat, r, c, dir)!;
      final nextB = sim.$1;

      var val = 0.0;
      if (ejected == 3) {
        val += 150.0;
        if (redCaptured[seat] + 1 >= targetRed) val += 10000.0;
      } else if (ejected == oppColor) {
        val += 95.0;
        if (enemyCaptured[seat] + 1 >= 8) val += 10000.0;
      }

      // Evaluate board position on nextB:
      // 1. Prefer pushing lines that contain Red (3) or Enemy (oppColor) marbles closer to the edge
      // 2. Keep our marbles slightly more central so they aren't easily ejected
      final (dr, dc) = kDirs[dir];
      for (var k = 1; k <= m['len']!; k++) {
        final nr = r + dr * k;
        final nc = c + dc * k;
        if (inBounds(nr, nc)) {
          final color = nextB[nr][nc];
          if (color == 3) {
            final edgeDist = _distToEdgeInDir(nr, nc, dir);
            val += (6 - edgeDist) * 8.0;
          } else if (color == oppColor) {
            final edgeDist = _distToEdgeInDir(nr, nc, dir);
            val += (6 - edgeDist) * 5.0;
          }
        }
      }

      for (var rr = 0; rr < kSize; rr++) {
        for (var cc = 0; cc < kSize; cc++) {
          final cell = nextB[rr][cc];
          if (cell == myColor) {
            final centerDist = (rr - 3).abs() + (cc - 3).abs();
            val += (6 - centerDist) * 1.2;
          } else if (cell == oppColor) {
            final centerDist = (rr - 3).abs() + (cc - 3).abs();
            val -= (6 - centerDist) * 1.0;
          }
        }
      }

      val += rng.nextDouble() * 0.5;
      if (val > bestScore) {
        bestScore = val;
        bestMoves = [m];
      }
    }

    final chosen = bestMoves[rng.nextInt(bestMoves.length)];
    return {
      'type': 'push',
      'r': chosen['r'],
      'c': chosen['c'],
      'dir': chosen['dir'],
    };
  }

  static int _distToEdgeInDir(int r, int c, int dir) {
    switch (dir) {
      case 0:
        return r;
      case 1:
        return (kSize - 1) - c;
      case 2:
        return (kSize - 1) - r;
      case 3:
        return c;
      default:
        return 3;
    }
  }

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (over) throw GameError('对局已结束');
    _endGame(1 - seat, '${name(seat)} 认输，${name(1 - seat)} 获胜！');
  }

  @override
  bool get canDraw => true;

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
      'targetRed': targetRed,
      'board': [
        for (final row in board) List<int>.of(row),
      ],
      'prevBoard': prevBoard == null
          ? null
          : [
              for (final row in prevBoard!) List<int>.of(row),
            ],
      'redCaptured': List<int>.of(redCaptured),
      'enemyCaptured': List<int>.of(enemyCaptured),
      'redRemaining': marbleCount(3),
      'marblesRemaining': [marbleCount(1), marbleCount(2)],
      'turn': turn,
      'bonusTurn': bonusTurn,
      'over': over,
      'winner': winner,
      'winReason': winReason,
      'moveCount': moveCount,
      'lastMove': lastMove,
      'legalMoves': over ? const [] : legalMoves(turn),
    };
  }
}
