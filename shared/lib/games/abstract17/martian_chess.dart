import '../../src/engine.dart';

/// 火星象棋（Martian Chess）—— Andrew Looney 起源奖（Origins Award）最佳抽象棋得主。
///
/// 核心规则：
/// - 棋盘为 `8×4` 网格（`rows 0..7, cols 0..3`），在第 3 行与第 4 行之间横亘着**火星运河（The Canal）**。
/// - **运河领地控制铁律（Zone-Determines-Ownership）**：
///   - 棋子本身不分颜色！棋子当前所处的半区直接决定它的控制权归属：
///   - **座位 0（南区统帅）**：控制所有位于南区 **`rows 4..7`** 的棋子！
///   - **座位 1（北区统帅）**：控制所有位于北区 **`rows 0..3`** 的棋子！
///   - 一旦你将一枚棋子跨过运河移入对方半区（无论是否吃子），该棋子落地后即刻移交控制权归对手所有！
/// - **三种金字塔棋子（分值 = 体型大小）**：
///   - **`1`（小兵 Pawn，1 分）**：沿对角线斜向移动 `1` 格（`|dr| == 1 && |dc| == 1`）。
///   - **`2`（中卫 Drone，2 分）**：沿上下左右正交方向移动 `1` 或 `2` 格（不可越子）。
///   - **`3`（女王 Queen，3 分）**：沿正交或斜向 8 个方向移动任意格数（不可越子）。
/// - **吃子、合成晋升与跨河反悔禁手**：
///   - **跨河吃子**：只能吃掉位于**对方半区**的棋子（获得等同于被吃棋子等级的分数 `1/2/3 分`）；绝不能吃掉自己半区内的棋子！
///   - **战地合成（Field Promotion）**：若你当前半区内**没有任何女王（`3`）**，你可以将自己半区内的 `1`（小兵）移到 `2`（中卫）上，或将 `2`（中卫）移到 `1`（小兵）上，合体晋升为一枚 **`3`（女王）**！
///   - **跨河反悔禁手（Canal Ko Rule）**：若对手上一步刚刚把一枚棋子跨过运河移入你的半区且**未吃子**，你在紧接着的这一回合不能将该棋子原路退回其出发格！
/// - **终局与胜负**：
///   - 当任意一方半区（`rows 0..3` 或 `rows 4..7`）内没有任何棋子（或快速模式率先达到目标分数）时对局立即结束，累计得分 `score[seat]` 更高者获胜！
class MartianChessGame extends GameEngine {
  MartianChessGame(super.setup);

  static const int kRows = 8;
  static const int kCols = 4;

  static const Map<int, String> kPieceNames = {
    1: '小兵',
    2: '中卫',
    3: '女王',
  };

  late String mode;
  late int targetScore;

  /// `board[r][c]`: `0` = empty, `1` = Pawn (1 pt), `2` = Drone (2 pts), `3` = Queen (3 pts).
  late List<List<int>> board;

  List<int> score = [0, 0];

  /// `[seat][0..2]` counts of captured `[Pawns, Drones, Queens]` by `seat`.
  List<List<int>> capturedCounts = [
    [0, 0, 0],
    [0, 0, 0],
  ];

  /// If the last move was a non-capturing cross-canal move `(fromR, fromC) -> (toR, toC)`,
  /// the next player is forbidden from immediately playing `(toR, toC) -> (fromR, fromC)`.
  (int, int, int, int)? forbiddenReverse;

  int turn = 0;
  bool over = false;
  int? winner;
  String? winReason;
  List<int>? _placings;
  int moveCount = 0;
  Map<String, dynamic>? lastMove;

  static bool inBounds(int r, int c) =>
      r >= 0 && r < kRows && c >= 0 && c < kCols;

  /// Seat 0 owns South Zone (`rows 4..7`), Seat 1 owns North Zone (`rows 0..3`).
  static int zoneOwner(int r) => r >= 4 ? 0 : 1;

  @override
  void start() {
    mode = setup.opt<String>('mode', 'standard');
    targetScore = mode == 'quick' ? 12 : 999;

    // Official 2-player Martian Chess initial setup:
    // North Zone (rows 0..3, Seat 1): top-left 3x3 corner pyramid
    // South Zone (rows 4..7, Seat 0): bottom-right 3x3 corner pyramid
    board = [
      [3, 3, 2, 0], // Row 0 (North)
      [3, 2, 1, 0], // Row 1 (North)
      [2, 1, 1, 0], // Row 2 (North)
      [0, 0, 0, 0], // Row 3 (North, canal bank)
      [0, 0, 0, 0], // Row 4 (South, canal bank)
      [0, 1, 1, 2], // Row 5 (South)
      [0, 1, 2, 3], // Row 6 (South)
      [0, 2, 3, 3], // Row 7 (South)
    ];

    score = [0, 0];
    capturedCounts = [
      [0, 0, 0],
      [0, 0, 0],
    ];
    forbiddenReverse = null;
    turn = 0;
    over = false;
    winner = null;
    winReason = null;
    _placings = null;
    moveCount = 0;
    lastMove = null;
  }

  int zonePieceCount(int seat) {
    final rStart = seat == 0 ? 4 : 0;
    final rEnd = seat == 0 ? 7 : 3;
    var count = 0;
    for (var r = rStart; r <= rEnd; r++) {
      for (var c = 0; c < kCols; c++) {
        if (board[r][c] > 0) count++;
      }
    }
    return count;
  }

  int zoneQueenCount(int seat) {
    final rStart = seat == 0 ? 4 : 0;
    final rEnd = seat == 0 ? 7 : 3;
    var count = 0;
    for (var r = rStart; r <= rEnd; r++) {
      for (var c = 0; c < kCols; c++) {
        if (board[r][c] == 3) count++;
      }
    }
    return count;
  }

  /// Checks if `piece` at `(fromR, fromC)` can geometrically reach `(toR, toC)` with unobstructed path.
  bool isPathValid(int piece, int fromR, int fromC, int toR, int toC) {
    if (!inBounds(fromR, fromC) || !inBounds(toR, toC)) return false;
    final dr = toR - fromR;
    final dc = toC - fromC;
    if (dr == 0 && dc == 0) return false;

    if (piece == 1) {
      // Pawn: 1 step diagonally
      return dr.abs() == 1 && dc.abs() == 1;
    } else if (piece == 2) {
      // Drone: 1 or 2 unobstructed steps orthogonally
      if (dr != 0 && dc != 0) return false;
      final dist = dr.abs() + dc.abs();
      if (dist < 1 || dist > 2) return false;
      if (dist == 2) {
        final midR = fromR + dr ~/ 2;
        final midC = fromC + dc ~/ 2;
        if (board[midR][midC] != 0) return false;
      }
      return true;
    } else if (piece == 3) {
      // Queen: any number of unobstructed steps orthogonally or diagonally
      if (dr != 0 && dc != 0 && dr.abs() != dc.abs()) return false;
      final steps = dr.abs() > dc.abs() ? dr.abs() : dc.abs();
      final stepR = dr.sign;
      final stepC = dc.sign;
      for (var s = 1; s < steps; s++) {
        if (board[fromR + stepR * s][fromC + stepC * s] != 0) return false;
      }
      return true;
    }
    return false;
  }

  /// Validates a move for `seat`. Returns `null` if legal, or a Chinese reason string if illegal.
  String? validateMove(int seat, int fromR, int fromC, int toR, int toC) {
    if (!inBounds(fromR, fromC) || !inBounds(toR, toC)) {
      return '棋盘坐标越界';
    }
    if (zoneOwner(fromR) != seat) {
      return '只能移动位于己方运河半区（${seat == 0 ? '南区 4..7 行' : '北区 0..3 行'}）内的棋子';
    }
    final piece = board[fromR][fromC];
    if (piece <= 0) {
      return '起始格没有棋子';
    }
    if (!isPathValid(piece, fromR, fromC, toR, toC)) {
      return '${kPieceNames[piece]}无法按该路径移动或途中存在阻挡';
    }

    final target = board[toR][toC];
    if (target == 0 && forbiddenReverse == (fromR, fromC, toR, toC)) {
      return '违反跨河反悔禁手：不能立即将对手刚跨过运河的棋子原路退回';
    }
    final targetZone = zoneOwner(toR);
    if (target > 0 && targetZone == seat) {
      // Landing on a piece in own zone: only legal if Field Promotion (Pawn + Drone -> Queen when 0 Queens in zone)
      final isPawnDronePair = (piece == 1 && target == 2) || (piece == 2 && target == 1);
      if (!isPawnDronePair) {
        return '不能吃掉己方半区内的棋子';
      }
      if (zoneQueenCount(seat) > 0) {
        return '己方半区内已有女王（3），不能合并小兵与中卫晋升';
      }
    }

    return null;
  }

  bool canMove(int seat, int fromR, int fromC, int toR, int toC) =>
      validateMove(seat, fromR, fromC, toR, toC) == null;

  List<Map<String, int>> legalMoves(int seat) {
    final res = <Map<String, int>>[];
    final rStart = seat == 0 ? 4 : 0;
    final rEnd = seat == 0 ? 7 : 3;
    for (var fr = rStart; fr <= rEnd; fr++) {
      for (var fc = 0; fc < kCols; fc++) {
        final p = board[fr][fc];
        if (p <= 0) continue;
        for (var tr = 0; tr < kRows; tr++) {
          for (var tc = 0; tc < kCols; tc++) {
            if (validateMove(seat, fr, fc, tr, tc) == null) {
              final target = board[tr][tc];
              final tZone = zoneOwner(tr);
              final isPromote = target > 0 && tZone == seat;
              final captured = (target > 0 && tZone != seat) ? target : 0;
              res.add({
                'fromR': fr,
                'fromC': fc,
                'toR': tr,
                'toC': tc,
                'piece': p,
                'captured': captured,
                'promote': isPromote ? 1 : 0,
              });
            }
          }
        }
      }
    }
    return res;
  }

  void _finishByScore(String prefix) {
    over = true;
    final s0 = score[0];
    final s1 = score[1];
    final summary = '${name(0)} $s0分 vs ${name(1)} $s1分';
    if (s0 > s1) {
      winner = 0;
      _placings = [1, 2];
      winReason = '$prefix，$summary，${name(0)} 获胜！';
    } else if (s1 > s0) {
      winner = 1;
      _placings = [2, 1];
      winReason = '$prefix，$summary，${name(1)} 获胜！';
    } else {
      winner = -1;
      _placings = [1, 1];
      winReason = '$prefix，$summary，双方平局！';
    }
    host.log(winReason!);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('当前不是你的回合');

    final type = asStr(action['type']);
    if (type != 'move') throw GameError('未知操作类型：$type');

    final fromR = asInt(action['fromR'], -1);
    final fromC = asInt(action['fromC'], -1);
    final toR = asInt(action['toR'], -1);
    final toC = asInt(action['toC'], -1);

    final err = validateMove(seat, fromR, fromC, toR, toC);
    if (err != null) throw GameError(err);

    final piece = board[fromR][fromC];
    final target = board[toR][toC];
    final fromZone = zoneOwner(fromR);
    final toZone = zoneOwner(toR);
    final crossedCanal = fromZone != toZone;

    var captured = 0;
    var promoted = false;

    if (target > 0 && toZone == seat) {
      // Field promotion: Pawn (1) + Drone (2) -> Queen (3)
      board[fromR][fromC] = 0;
      board[toR][toC] = 3;
      promoted = true;
      forbiddenReverse = null;
    } else {
      if (target > 0 && toZone != seat) {
        captured = target;
        score[seat] += captured;
        capturedCounts[seat][captured - 1]++;
      }
      board[fromR][fromC] = 0;
      board[toR][toC] = piece;

      if (crossedCanal && captured == 0) {
        forbiddenReverse = (toR, toC, fromR, fromC);
      } else {
        forbiddenReverse = null;
      }
    }

    moveCount++;
    lastMove = {
      'type': 'move',
      'seat': seat,
      'fromR': fromR,
      'fromC': fromC,
      'toR': toR,
      'toC': toC,
      'piece': piece,
      'captured': captured,
      'promoted': promoted,
      'crossedCanal': crossedCanal,
    };

    if (promoted) {
      host.log('${name(seat)} 在 ($toR, $toC) 将小兵与中卫合体晋升为女王（3）！');
    } else if (captured > 0) {
      host.log(
        '${name(seat)} 驱使${kPieceNames[piece]}从 ($fromR, $fromC) 跨过运河奇袭 ($toR, $toC)，吃掉${kPieceNames[captured]}（+$captured分，总分 ${score[seat]}）！',
      );
    } else if (crossedCanal) {
      host.log('${name(seat)} 将${kPieceNames[piece]}从 ($fromR, $fromC) 跨河移入对方半区 ($toR, $toC)');
    } else {
      host.log('${name(seat)} 在半区内将${kPieceNames[piece]}从 ($fromR, $fromC) 移至 ($toR, $toC)');
    }

    if (score[seat] >= targetScore) {
      _finishByScore('${name(seat)} 率先达到目标分（${score[seat]}分）');
      return;
    }

    final southCount = zonePieceCount(0);
    final northCount = zonePieceCount(1);
    if (southCount == 0 || northCount == 0) {
      final emptyZoneName = southCount == 0 ? '南区（4..7行）' : '北区（0..3行）';
      _finishByScore('$emptyZoneName已无任何棋子');
      return;
    }

    final opp = 1 - seat;
    turn = opp;

    if (legalMoves(opp).isEmpty) {
      _finishByScore('${name(opp)} 无合法移动步数');
      return;
    }

    if (moveCount >= 150) {
      _finishByScore('达到回合上限');
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    final moves = legalMoves(seat);
    if (moves.isEmpty) return null;

    if (botLevel <= 0) {
      final caps = moves.where((m) => m['captured']! > 0 || m['promote'] == 1).toList();
      final pool = caps.isNotEmpty ? caps : moves;
      final pick = pool[rng.nextInt(pool.length)];
      return {
        'type': 'move',
        'fromR': pick['fromR'],
        'fromC': pick['fromC'],
        'toR': pick['toR'],
        'toC': pick['toC'],
      };
    }

    final opp = 1 - seat;
    final myCount = zonePieceCount(seat);
    var bestVal = -1e9;
    var bestMoves = <Map<String, int>>[];

    for (final m in moves) {
      final fr = m['fromR']!;
      final tr = m['toR']!;
      final piece = m['piece']!;
      final captured = m['captured']!;
      final promote = m['promote'] == 1;
      final crossed = zoneOwner(tr) != seat;

      var val = 0.0;
      if (captured > 0) {
        // Capturing always advances game progress and scores points;
        // evaluate trade value (captured value vs piece handed over to opponent)
        val += captured * 42.0 - piece * 11.0;
        if (score[seat] + captured >= targetScore) val += 10000.0;
        // If our last piece in zone captures and wins by score, huge bonus!
        if (myCount == 1) {
          final myNewScore = score[seat] + captured;
          if (myNewScore > score[opp]) {
            val += 10000.0;
          } else if (myNewScore < score[opp]) {
            val -= 500.0;
          }
        }
      } else if (promote) {
        val += 48.0;
      } else if (crossed) {
        // Non-capturing cross-canal move gifts a piece to the opponent!
        // Only do this if forced or emptying zone while ahead on score
        if (myCount == 1 && score[seat] > score[opp]) {
          val += 8000.0;
        } else {
          val -= piece * 26.0;
        }
      } else {
        // Move within own zone: prefer advancing closer to the canal (rows 3 & 4)
        final oldDistToCanal = seat == 0 ? (fr - 4) : (3 - fr);
        final newDistToCanal = seat == 0 ? (tr - 4) : (3 - tr);
        val += (oldDistToCanal - newDistToCanal) * 6.0;
        if (tr == 3 || tr == 4) val += 5.0;
      }

      val += rng.nextDouble() * 0.5;
      if (val > bestVal) {
        bestVal = val;
        bestMoves = [m];
      }
    }

    final chosen = bestMoves[rng.nextInt(bestMoves.length)];
    return {
      'type': 'move',
      'fromR': chosen['fromR'],
      'fromC': chosen['fromC'],
      'toR': chosen['toR'],
      'toC': chosen['toC'],
    };
  }

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (over) throw GameError('对局已结束');
    over = true;
    winner = 1 - seat;
    _placings = winner == 0 ? [1, 2] : [2, 1];
    winReason = '${name(seat)} 认输，${name(winner!)} 获胜！';
    host.log(winReason!);
  }

  @override
  bool get canDraw => true;

  @override
  void agreeDraw() {
    if (over) throw GameError('对局已结束');
    over = true;
    winner = -1;
    _placings = [1, 1];
    winReason = '双方同意和棋！';
    host.log(winReason!);
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
      'targetScore': targetScore,
      'board': [
        for (final row in board) List<int>.of(row),
      ],
      'score': List<int>.of(score),
      'capturedCounts': [
        List<int>.of(capturedCounts[0]),
        List<int>.of(capturedCounts[1]),
      ],
      'zoneCounts': [zonePieceCount(0), zonePieceCount(1)],
      'zoneQueens': [zoneQueenCount(0), zoneQueenCount(1)],
      'forbiddenReverse': forbiddenReverse == null
          ? null
          : [
              forbiddenReverse!.$1,
              forbiddenReverse!.$2,
              forbiddenReverse!.$3,
              forbiddenReverse!.$4,
            ],
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
