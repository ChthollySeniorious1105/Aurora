import '../../src/engine.dart';

/// 虎羊棋（Bagh-Chal）—— 尼泊尔国粹非对称 5×5 米字格围猎博弈名作（4 猛虎 vs 20 山羊）。
///
/// 核心规则：
/// - 棋盘为 `5×5` 经典 Alquerque 米字交叉点网格（25 个交叉点 `(r, c)`，`r, c in 0..4`）：
///   - 所有交叉点均具有上下左右正交连线；
///   - 偶数奇偶性交叉点 `(r + c) % 2 == 0` 额外具有 4 条斜向连线（8 向连通点）。
/// - **非对称双方阵营**：
///   - **座位 0（🐅 猛虎方 Tigers）**：初始拥有 **4 只猛虎**，分别盘踞在四角 `(0,0), (0,4), (4,0), (4,4)`。
///   - **座位 1（🐐 山羊方 Goats）**：初始拥有 **20 只山羊储备**（盘面初始无山羊），由山羊方先手行动！
/// - **回合行动规则**：
///   - **山羊方（座位 1）**：
///     - **阶段 1（布羊阶段，`goatsInReserve > 0`）**：每次从储备中取 1 只山羊放入棋盘上任意空交叉点 `(r, c)`（`{'type': 'place', 'r': r, 'c': c}`）。
///     - **阶段 2（走羊阶段，`goatsInReserve == 0`）**：当 20 只山羊全部放完后，每次选择盘面 1 只山羊沿格线移动 1 步至相邻空交叉点（山羊不可跳越或吃子）。
///   - **猛虎方（座位 0）**：
///     - **常规走步**：选择 1 只猛虎沿格线移动 1 步至相邻空交叉点；或
///     - **跳吃山羊（Capture Jump）**：沿一条笔直格线跳过相邻的 1 只山羊落入紧随其后的空交叉点 `(r + 2*dr, c + 2*dc)`，将该山羊捕获吃掉！
/// - **胜负条件**：
///   - **猛虎获胜**：猛虎方累计吃掉 **5 只山羊**（快速模式为 **3 只**）（或令山羊方无路可走）立即获胜！
///   - **山羊获胜**：轮到猛虎方行动时，若场上 **4 只猛虎被围困至没有任何合法移动或跳吃步数**，山羊方立即获胜！
class BaghChalGame extends GameEngine {
  BaghChalGame(super.setup);

  static const int kSize = 5;
  static const int kEmpty = 0;
  static const int kTiger = 1;
  static const int kGoat = 2;

  static const List<(int, int)> kOrthoDirs = [
    (-1, 0),
    (1, 0),
    (0, -1),
    (0, 1),
  ];

  static const List<(int, int)> kDiagDirs = [
    (-1, -1),
    (-1, 1),
    (1, -1),
    (1, 1),
  ];

  late String mode;
  late int targetCaptures;

  /// `board[r][c]`: `0` = empty, `1` = Tiger (Seat 0), `2` = Goat (Seat 1).
  late List<List<int>> board;

  int goatsInReserve = 20;
  int goatsCaptured = 0;

  /// Seat 1 (Goats) moves first in Bagh-Chal, placing the first goat onto the board.
  int turn = 1;
  bool over = false;
  int? winner;
  String? winReason;
  List<int>? _placings;
  int moveCount = 0;
  Map<String, dynamic>? lastMove;

  static bool inBounds(int r, int c) => r >= 0 && r < kSize && c >= 0 && c < kSize;

  /// Returns the connected grid directions `(dr, dc)` from `(r, c)`.
  /// Orthogonal edges exist everywhere; diagonal edges exist iff `(r + c) % 2 == 0`.
  static List<(int, int)> connectedDirs(int r, int c) =>
      (r + c).isEven ? [...kOrthoDirs, ...kDiagDirs] : kOrthoDirs;

  static bool hasEdge(int r1, int c1, int r2, int c2) {
    if (!inBounds(r1, c1) || !inBounds(r2, c2)) return false;
    final dr = (r2 - r1).abs();
    final dc = (c2 - c1).abs();
    if (dr + dc == 1) return true;
    if (dr == 1 && dc == 1 && (r1 + c1).isEven) return true;
    return false;
  }

  @override
  void start() {
    mode = setup.opt<String>('mode', 'standard');
    targetCaptures = mode == 'quick' ? 3 : 5;

    board = List.generate(kSize, (_) => List.filled(kSize, kEmpty));
    board[0][0] = kTiger;
    board[0][4] = kTiger;
    board[4][0] = kTiger;
    board[4][4] = kTiger;

    goatsInReserve = 20;
    goatsCaptured = 0;
    turn = 1; // Goats (Seat 1) place first
    over = false;
    winner = null;
    winReason = null;
    _placings = null;
    moveCount = 0;
    lastMove = null;
  }

  void clearBoard() {
    for (var r = 0; r < kSize; r++) {
      for (var c = 0; c < kSize; c++) {
        board[r][c] = kEmpty;
      }
    }
  }

  int goatsOnBoard([List<List<int>>? b]) {
    final grid = b ?? board;
    var cnt = 0;
    for (var r = 0; r < kSize; r++) {
      for (var c = 0; c < kSize; c++) {
        if (grid[r][c] == kGoat) cnt++;
      }
    }
    return cnt;
  }

  List<Map<String, dynamic>> legalMoves(int seat, [List<List<int>>? b, int? reserveOverride]) {
    final grid = b ?? board;
    final res = <Map<String, dynamic>>[];

    if (seat == 1) {
      // Goats (Seat 1)
      final rem = reserveOverride ?? goatsInReserve;
      if (rem > 0) {
        for (var r = 0; r < kSize; r++) {
          for (var c = 0; c < kSize; c++) {
            if (grid[r][c] == kEmpty) {
              res.add({'type': 'place', 'r': r, 'c': c});
            }
          }
        }
      } else {
        for (var r = 0; r < kSize; r++) {
          for (var c = 0; c < kSize; c++) {
            if (grid[r][c] != kGoat) continue;
            for (final (dr, dc) in connectedDirs(r, c)) {
              final nr = r + dr;
              final nc = c + dc;
              if (inBounds(nr, nc) && grid[nr][nc] == kEmpty) {
                res.add({
                  'type': 'move',
                  'fromR': r,
                  'fromC': c,
                  'toR': nr,
                  'toC': nc,
                  'capture': false,
                });
              }
            }
          }
        }
      }
      return res;
    }

    // Tigers (Seat 0)
    for (var r = 0; r < kSize; r++) {
      for (var c = 0; c < kSize; c++) {
        if (grid[r][c] != kTiger) continue;
        for (final (dr, dc) in connectedDirs(r, c)) {
          final r1 = r + dr;
          final c1 = c + dc;
          if (!inBounds(r1, c1)) continue;
          if (grid[r1][c1] == kEmpty) {
            res.add({
              'type': 'move',
              'fromR': r,
              'fromC': c,
              'toR': r1,
              'toC': c1,
              'capture': false,
            });
          } else if (grid[r1][c1] == kGoat) {
            final r2 = r + 2 * dr;
            final c2 = c + 2 * dc;
            if (inBounds(r2, c2) && grid[r2][c2] == kEmpty) {
              res.add({
                'type': 'move',
                'fromR': r,
                'fromC': c,
                'toR': r2,
                'toC': c2,
                'capture': true,
                'capR': r1,
                'capC': c1,
              });
            }
          }
        }
      }
    }
    return res;
  }

  void _endGame(int winSeat, String reason) {
    over = true;
    winner = winSeat;
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

    if (seat == 1) {
      // Goats (Seat 1)
      if (goatsInReserve > 0) {
        if (type != 'place') throw GameError('山羊储备尚未用完，请先在空交叉点放置山羊');
        final r = asInt(action['r'], -1);
        final c = asInt(action['c'], -1);
        if (!inBounds(r, c)) throw GameError('交叉点坐标 ($r, $c) 越界');
        if (board[r][c] != kEmpty) throw GameError('目标交叉点 ($r, $c) 已有棋子');

        board[r][c] = kGoat;
        goatsInReserve--;
        moveCount++;
        lastMove = {
          'type': 'place',
          'seat': 1,
          'r': r,
          'c': c,
        };
        host.log('${name(1)} 在 ($r, $c) 放置山羊🐐（剩余储备 $goatsInReserve 只）');
      } else {
        if (type != 'move') throw GameError('20 只山羊已全部入场，请选择盘面山羊移动');
        final fromR = asInt(action['fromR'], -1);
        final fromC = asInt(action['fromC'], -1);
        final toR = asInt(action['toR'], -1);
        final toC = asInt(action['toC'], -1);

        if (!inBounds(fromR, fromC) || !inBounds(toR, toC)) {
          throw GameError('棋盘坐标越界');
        }
        if (board[fromR][fromC] != kGoat) {
          throw GameError('起始点 ($fromR, $fromC) 没有山羊');
        }
        if (board[toR][toC] != kEmpty) {
          throw GameError('目标点 ($toR, $toC) 不是空交叉点');
        }
        if (!hasEdge(fromR, fromC, toR, toC)) {
          throw GameError('山羊只能沿相连的米字格线移动 1 步');
        }

        board[fromR][fromC] = kEmpty;
        board[toR][toC] = kGoat;
        moveCount++;
        lastMove = {
          'type': 'move',
          'seat': 1,
          'fromR': fromR,
          'fromC': fromC,
          'toR': toR,
          'toC': toC,
          'capture': false,
        };
        host.log('${name(1)} 将山羊🐐从 ($fromR, $fromC) 移至 ($toR, $toC)');
      }

      turn = 0;
      if (legalMoves(0).isEmpty) {
        _endGame(1, '${name(1)} 成功将全部 4 只猛虎围困至无路可走，山羊方获胜！');
        return;
      }
    } else {
      // Tigers (Seat 0)
      if (type != 'move') throw GameError('猛虎方请选择猛虎移动或跳吃山羊');
      final fromR = asInt(action['fromR'], -1);
      final fromC = asInt(action['fromC'], -1);
      final toR = asInt(action['toR'], -1);
      final toC = asInt(action['toC'], -1);

      if (!inBounds(fromR, fromC) || !inBounds(toR, toC)) {
        throw GameError('棋盘坐标越界');
      }
      if (board[fromR][fromC] != kTiger) {
        throw GameError('起始点 ($fromR, $fromC) 没有猛虎');
      }
      if (board[toR][toC] != kEmpty) {
        throw GameError('目标点 ($toR, $toC) 不是空交叉点');
      }

      final dr = toR - fromR;
      final dc = toC - fromC;

      if (hasEdge(fromR, fromC, toR, toC)) {
        // 1-step Tiger move
        board[fromR][fromC] = kEmpty;
        board[toR][toC] = kTiger;
        moveCount++;
        lastMove = {
          'type': 'move',
          'seat': 0,
          'fromR': fromR,
          'fromC': fromC,
          'toR': toR,
          'toC': toC,
          'capture': false,
        };
        host.log('${name(0)} 将猛虎🐅从 ($fromR, $fromC) 移至 ($toR, $toC)');
      } else if (dr.abs() <= 2 &&
          dc.abs() <= 2 &&
          dr.abs() % 2 == 0 &&
          dc.abs() % 2 == 0 &&
          (dr != 0 || dc != 0)) {
        final stepR = dr ~/ 2;
        final stepC = dc ~/ 2;
        final midR = fromR + stepR;
        final midC = fromC + stepC;
        if (!hasEdge(fromR, fromC, midR, midC) || !hasEdge(midR, midC, toR, toC)) {
          throw GameError('猛虎只能沿相连的直线格线进行跳吃');
        }
        if (board[midR][midC] != kGoat) {
          throw GameError('跳吃失败：中间交叉点 ($midR, $midC) 必须有 1 只山羊');
        }

        board[fromR][fromC] = kEmpty;
        board[midR][midC] = kEmpty;
        board[toR][toC] = kTiger;
        goatsCaptured++;
        moveCount++;

        lastMove = {
          'type': 'move',
          'seat': 0,
          'fromR': fromR,
          'fromC': fromC,
          'toR': toR,
          'toC': toC,
          'capture': true,
          'capR': midR,
          'capC': midC,
        };
        host.log(
          '${name(0)} 猛虎🐅从 ($fromR, $fromC) 跃过 ($midR, $midC) 扑杀山羊（已吃 $goatsCaptured/$targetCaptures 只）！',
        );

        if (goatsCaptured >= targetCaptures) {
          _endGame(
            0,
            '${name(0)} 累计扑杀 $goatsCaptured 只山羊（目标 $targetCaptures 只），猛虎方获胜！',
          );
          return;
        }
      } else {
        throw GameError('无效的猛虎移动路径');
      }

      turn = 1;
      if (legalMoves(1).isEmpty) {
        _endGame(0, '${name(1)} 已无合法走步，猛虎方获胜！');
        return;
      }
    }

    if (moveCount >= 140) {
      final tigerMoves = legalMoves(0).length;
      if (goatsCaptured * 3 + tigerMoves >= targetCaptures * 3 + 4) {
        _endGame(0, '达到回合上限，猛虎方（已吃 $goatsCaptured 羊）占据主动获胜！');
      } else {
        _endGame(1, '达到回合上限，山羊方成功坚守阵线围困猛虎获胜！');
      }
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    final moves = legalMoves(seat);
    if (moves.isEmpty) return null;

    if (seat == 0) {
      // Tiger bot: prioritize captures and mobility
      final captures = moves.where((m) => m['capture'] == true).toList();
      if (captures.isNotEmpty) {
        return captures[rng.nextInt(captures.length)];
      }
      if (botLevel <= 0) {
        return moves[rng.nextInt(moves.length)];
      }

      var bestVal = -1e9;
      var bestMoves = <Map<String, dynamic>>[];
      for (final m in moves) {
        final fr = m['fromR'] as int;
        final fc = m['fromC'] as int;
        final tr = m['toR'] as int;
        final tc = m['toC'] as int;
        final sim = [for (final row in board) List<int>.of(row)];
        sim[fr][fc] = kEmpty;
        sim[tr][tc] = kTiger;

        final nextTigerMoves = legalMoves(0, sim);
        final nextCaps = nextTigerMoves.where((x) => x['capture'] == true).length;
        final val = nextCaps * 45.0 +
            nextTigerMoves.length * 3.0 +
            ((tr + tc).isEven ? 4.0 : 0.0) +
            rng.nextDouble() * 0.5;
        if (val > bestVal) {
          bestVal = val;
          bestMoves = [m];
        }
      }
      return bestMoves[rng.nextInt(bestMoves.length)];
    } else {
      // Goat bot: avoid giving Tigers capture jumps, and reduce Tiger mobility
      if (botLevel <= 0) {
        return moves[rng.nextInt(moves.length)];
      }

      var bestVal = -1e9;
      var bestMoves = <Map<String, dynamic>>[];
      for (final m in moves) {
        final sim = [for (final row in board) List<int>.of(row)];
        if (m['type'] == 'place') {
          sim[m['r'] as int][m['c'] as int] = kGoat;
        } else {
          sim[m['fromR'] as int][m['fromC'] as int] = kEmpty;
          sim[m['toR'] as int][m['toC'] as int] = kGoat;
        }

        final tigerMoves = legalMoves(0, sim);
        if (tigerMoves.isEmpty) {
          return m; // Immediate win by trapping all 4 Tigers!
        }
        final tigerCaps = tigerMoves.where((x) => x['capture'] == true).length;
        final val = -tigerCaps * 120.0 - tigerMoves.length * 6.0 + rng.nextDouble() * 0.5;
        if (val > bestVal) {
          bestVal = val;
          bestMoves = [m];
        }
      }
      return bestMoves[rng.nextInt(bestMoves.length)];
    }
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
    final tigerMovesCount = legalMoves(0).length;
    return {
      'mode': mode,
      'targetCaptures': targetCaptures,
      'board': [
        for (final row in board) List<int>.of(row),
      ],
      'goatsInReserve': goatsInReserve,
      'goatsOnBoard': goatsOnBoard(),
      'goatsCaptured': goatsCaptured,
      'tigerMobility': tigerMovesCount,
      'turn': turn,
      'over': over,
      'winner': winner,
      'winReason': winReason,
      'moveCount': moveCount,
      'lastMove': lastMove,
      'legalMoves': over ? const [] : legalMoves(turn),
    };
  }
}
