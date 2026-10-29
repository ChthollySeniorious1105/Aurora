import '../../src/engine.dart';

class SurakartaLoopStep {
  final int toR;
  final int toC;
  final int ndr;
  final int ndc;
  final String loopId;

  const SurakartaLoopStep(this.toR, this.toC, this.ndr, this.ndc, this.loopId);
}

class SurakartaCapturePath {
  final int fromR;
  final int fromC;
  final int toR;
  final int toC;
  final List<String> loops;
  final List<(int, int)> waypoints;

  const SurakartaCapturePath({
    required this.fromR,
    required this.fromC,
    required this.toR,
    required this.toC,
    required this.loops,
    required this.waypoints,
  });

  Map<String, dynamic> toJson() => {
        'fromR': fromR,
        'fromC': fromC,
        'toR': toR,
        'toC': toC,
        'loops': loops,
        'waypoints': [
          for (final (r, c) in waypoints) [r, c],
        ],
      };
}

/// 苏拉卡尔塔环轨棋 (Surakarta) — Classic Indonesian Corner-Loop Orbit Capture game.
class SurakartaGame extends GameEngine {
  SurakartaGame(super.setup);

  static const List<(int, int)> orthoDirs = [
    (-1, 0),
    (1, 0),
    (0, -1),
    (0, 1),
  ];

  static const List<(int, int)> kingDirs = [
    (-1, -1),
    (-1, 0),
    (-1, 1),
    (0, -1),
    (0, 1),
    (1, -1),
    (1, 0),
    (1, 1),
  ];

  late String mode;
  late int maxQuietMoves;
  late int maxTotalTurns;

  /// 6x6 board: 0 = empty, 1 = Black (seat 0), 2 = White (seat 1).
  late List<List<int>> board;
  List<int> captured = [0, 0];

  int turn = 0;
  int turnCount = 0;
  int quietMoves = 0;
  bool _over = false;
  int? winner; // 0, 1, or -1 for draw
  String? winReason;
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

  static int pieceOfSeat(int seat) => seat == 0 ? 1 : 2;

  static bool inBounds(int r, int c) => r >= 0 && r < 6 && c >= 0 && c < 6;

  int remainingCount(int seat) {
    final target = pieceOfSeat(seat);
    var count = 0;
    for (var r = 0; r < 6; r++) {
      for (var c = 0; c < 6; c++) {
        if (board[r][c] == target) count++;
      }
    }
    return count;
  }

  @override
  void start() {
    mode = setup.opt<String>('mode', 'standard');
    maxQuietMoves = mode == 'quick' ? 32 : 50;
    maxTotalTurns = mode == 'quick' ? 100 : 160;
    board = List.generate(6, (r) {
      if (r <= 1) return List<int>.filled(6, 2); // Player 1 (White) on rows 0, 1
      if (r >= 4) return List<int>.filled(6, 1); // Player 0 (Black) on rows 4, 5
      return List<int>.filled(6, 0);
    });
    captured = [0, 0];
    turn = 0;
    turnCount = 0;
    quietMoves = 0;
    _over = false;
    winner = null;
    winReason = null;
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

  /// Corner loop transition when stepping out of the 6x6 grid from (r, c) in direction (dr, dc).
  static SurakartaLoopStep? cornerLoopTransition(int r, int c, int dr, int dc) {
    // Exiting top edge
    if (r == 0 && dr == -1 && dc == 0) {
      switch (c) {
        case 0:
          return const SurakartaLoopStep(0, 0, 0, 1, 'TL-outer');
        case 1:
          return const SurakartaLoopStep(1, 0, 0, 1, 'TL-inner');
        case 4:
          return const SurakartaLoopStep(1, 5, 0, -1, 'TR-inner');
        case 5:
          return const SurakartaLoopStep(0, 5, 0, -1, 'TR-outer');
      }
      return null;
    }
    // Exiting bottom edge
    if (r == 5 && dr == 1 && dc == 0) {
      switch (c) {
        case 0:
          return const SurakartaLoopStep(5, 0, 0, 1, 'BL-outer');
        case 1:
          return const SurakartaLoopStep(4, 0, 0, 1, 'BL-inner');
        case 4:
          return const SurakartaLoopStep(4, 5, 0, -1, 'BR-inner');
        case 5:
          return const SurakartaLoopStep(5, 5, 0, -1, 'BR-outer');
      }
      return null;
    }
    // Exiting left edge
    if (c == 0 && dr == 0 && dc == -1) {
      switch (r) {
        case 0:
          return const SurakartaLoopStep(0, 0, 1, 0, 'TL-outer');
        case 1:
          return const SurakartaLoopStep(0, 1, 1, 0, 'TL-inner');
        case 4:
          return const SurakartaLoopStep(5, 1, -1, 0, 'BL-inner');
        case 5:
          return const SurakartaLoopStep(5, 0, -1, 0, 'BL-outer');
      }
      return null;
    }
    // Exiting right edge
    if (c == 5 && dr == 0 && dc == 1) {
      switch (r) {
        case 0:
          return const SurakartaLoopStep(0, 5, 1, 0, 'TR-outer');
        case 1:
          return const SurakartaLoopStep(0, 4, 1, 0, 'TR-inner');
        case 4:
          return const SurakartaLoopStep(5, 4, -1, 0, 'BR-inner');
        case 5:
          return const SurakartaLoopStep(5, 5, -1, 0, 'BR-outer');
      }
      return null;
    }
    return null;
  }

  /// Trace all legal loop-capture rays from (fromR, fromC) for [seat].
  List<SurakartaCapturePath> traceCaptureRays(int fromR, int fromC, int seat) {
    if (!inBounds(fromR, fromC)) return const [];
    final myPiece = pieceOfSeat(seat);
    final enemyPiece = pieceOfSeat(1 - seat);
    if (board[fromR][fromC] != myPiece) return const [];

    final results = <SurakartaCapturePath>[];
    final seenTargets = <(int, int)>{};

    for (final (initDr, initDc) in orthoDirs) {
      var r = fromR;
      var c = fromC;
      var dr = initDr;
      var dc = initDc;
      final loops = <String>[];
      final waypoints = <(int, int)>[(fromR, fromC)];
      final visitedStates = <(int, int, int, int)>{(fromR, fromC, dr, dc)};

      for (var step = 0; step < 64; step++) {
        final nr = r + dr;
        final nc = c + dc;
        if (inBounds(nr, nc)) {
          r = nr;
          c = nc;
        } else {
          final loop = cornerLoopTransition(r, c, dr, dc);
          if (loop == null) break; // Hit dead-end edge (row/col 2 or 3)
          loops.add(loop.loopId);
          r = loop.toR;
          c = loop.toC;
          dr = loop.ndr;
          dc = loop.ndc;
        }

        waypoints.add((r, c));

        // The starting square itself is vacated by the moving pebble
        final occupant = (r == fromR && c == fromC) ? 0 : board[r][c];
        if (occupant == myPiece) {
          // Blocked by own pebble
          break;
        }
        if (occupant == enemyPiece) {
          // Encountered first enemy pebble along this ray
          if (loops.isNotEmpty && seenTargets.add((r, c))) {
            results.add(SurakartaCapturePath(
              fromR: fromR,
              fromC: fromC,
              toR: r,
              toC: c,
              loops: List.unmodifiable(loops),
              waypoints: List.unmodifiable(waypoints),
            ));
          }
          break;
        }

        final state = (r, c, dr, dc);
        if (!visitedStates.add(state)) {
          // Full orbit completed without hitting any pebble
          break;
        }
      }
    }
    return results;
  }

  SurakartaCapturePath? findCapturePath(int seat, int fromR, int fromC, int toR, int toC) {
    for (final path in traceCaptureRays(fromR, fromC, seat)) {
      if (path.toR == toR && path.toC == toC) return path;
    }
    return null;
  }

  bool canStep(int seat, int fromR, int fromC, int toR, int toC) {
    if (!inBounds(fromR, fromC) || !inBounds(toR, toC)) return false;
    if (board[fromR][fromC] != pieceOfSeat(seat)) return false;
    if (board[toR][toC] != 0) return false;
    final dr = (fromR - toR).abs();
    final dc = (fromC - toC).abs();
    return (dr <= 1 && dc <= 1) && (dr + dc > 0);
  }

  bool canCapture(int seat, int fromR, int fromC, int toR, int toC) {
    return findCapturePath(seat, fromR, fromC, toR, toC) != null;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);
    final fromR = asInt(action['fromR'], -1);
    final fromC = asInt(action['fromC'], -1);
    final toR = asInt(action['toR'], -1);
    final toC = asInt(action['toC'], -1);

    if (!inBounds(fromR, fromC) || !inBounds(toR, toC)) {
      throw GameError('坐标超出棋盘范围');
    }
    final myPiece = pieceOfSeat(seat);
    if (board[fromR][fromC] != myPiece) {
      throw GameError('起点没有你的棋子');
    }

    if (type == 'step') {
      if (board[toR][toC] != 0) {
        throw GameError('普通移动只能迈入空交叉点，吃子必须经过角环轨道');
      }
      final dr = (fromR - toR).abs();
      final dc = (fromC - toC).abs();
      if (dr > 1 || dc > 1 || (dr == 0 && dc == 0)) {
        throw GameError('普通移动只能向周围 8 个相邻方向移动 1 步');
      }
      board[fromR][fromC] = 0;
      board[toR][toC] = myPiece;
      quietMoves++;
      lastMove = {
        'type': 'step',
        'seat': seat,
        'fromR': fromR,
        'fromC': fromC,
        'toR': toR,
        'toC': toC,
        'loops': const <String>[],
        'waypoints': [
          [fromR, fromC],
          [toR, toC],
        ],
      };
    } else if (type == 'capture') {
      final path = findCapturePath(seat, fromR, fromC, toR, toC);
      if (path == null) {
        throw GameError('非法环轨吃子：必须沿无遮挡直线滑入至少一个角环轨道并吃掉遇到的第一枚敌子');
      }
      board[fromR][fromC] = 0;
      board[toR][toC] = myPiece;
      captured[seat]++;
      quietMoves = 0;
      lastMove = {
        'type': 'capture',
        'seat': seat,
        'fromR': fromR,
        'fromC': fromC,
        'toR': toR,
        'toC': toC,
        'loops': path.loops,
        'waypoints': [
          for (final (r, c) in path.waypoints) [r, c],
        ],
      };
    } else {
      throw GameError('未知操作类型：$type');
    }

    turnCount++;

    final oppSeat = 1 - seat;
    final oppRem = remainingCount(oppSeat);
    if (oppRem == 0) {
      _over = true;
      winner = seat;
      winReason = '${name(seat)} 吃光了对方全部棋子，大获全胜！';
      host.log(winReason!);
      return;
    }

    if (mode == 'quick' && captured[seat] >= 6) {
      _over = true;
      winner = seat;
      winReason = '${name(seat)} 在快速模式中率先俘获 ${captured[seat]} 枚敌子获胜！';
      host.log(winReason!);
      return;
    }

    if (quietMoves >= maxQuietMoves ||
        turnCount >= maxTotalTurns ||
        !_hasAnyLegalMove(oppSeat)) {
      _adjudicateByRemaining();
      return;
    }

    turn = oppSeat;
  }

  bool _hasAnyLegalMove(int seat) {
    final myPiece = pieceOfSeat(seat);
    for (var r = 0; r < 6; r++) {
      for (var c = 0; c < 6; c++) {
        if (board[r][c] != myPiece) continue;
        for (final (dr, dc) in kingDirs) {
          final nr = r + dr;
          final nc = c + dc;
          if (inBounds(nr, nc) && board[nr][nc] == 0) return true;
        }
        if (traceCaptureRays(r, c, seat).isNotEmpty) return true;
      }
    }
    return false;
  }

  void _adjudicateByRemaining() {
    _over = true;
    final rem0 = remainingCount(0);
    final rem1 = remainingCount(1);
    if (rem0 != rem1) {
      winner = rem0 > rem1 ? 0 : 1;
      winReason = '对局结束：${name(winner!)} 剩余更多棋子（$rem0 : $rem1）获胜！';
    } else {
      winner = -1;
      winReason = '对局结束：双方剩余棋子数相同（$rem0 : $rem1），平局！';
    }
    host.log(winReason!);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    final myPiece = pieceOfSeat(seat);

    final captures = <SurakartaCapturePath>[];
    final steps = <Map<String, dynamic>>[];

    for (var r = 0; r < 6; r++) {
      for (var c = 0; c < 6; c++) {
        if (board[r][c] != myPiece) continue;
        captures.addAll(traceCaptureRays(r, c, seat));
        for (final (dr, dc) in kingDirs) {
          final nr = r + dr;
          final nc = c + dc;
          if (inBounds(nr, nc) && board[nr][nc] == 0) {
            steps.add({
              'type': 'step',
              'fromR': r,
              'fromC': c,
              'toR': nr,
              'toC': nc,
            });
          }
        }
      }
    }

    if (captures.isEmpty && steps.isEmpty) return null;

    // Easy bot occasionally takes a random step instead of capturing
    if (botLevel == 0 && rng.nextDouble() < 0.35 && steps.isNotEmpty) {
      return steps[rng.nextInt(steps.length)];
    }

    // Prioritize loop captures!
    if (captures.isNotEmpty) {
      // Score each capture by safety after landing
      SurakartaCapturePath? bestCap;
      var bestScore = double.negativeInfinity;
      for (final cap in captures) {
        final savedFrom = board[cap.fromR][cap.fromC];
        final savedTo = board[cap.toR][cap.toC];
        board[cap.fromR][cap.fromC] = 0;
        board[cap.toR][cap.toC] = myPiece;

        // Check if opponent can immediately recapture at (cap.toR, cap.toC)
        var canBeRecaptured = false;
        if (botLevel >= 1) {
          final oppPiece = pieceOfSeat(1 - seat);
          outer:
          for (var r = 0; r < 6; r++) {
            for (var c = 0; c < 6; c++) {
              if (board[r][c] == oppPiece) {
                for (final oppCap in traceCaptureRays(r, c, 1 - seat)) {
                  if (oppCap.toR == cap.toR && oppCap.toC == cap.toC) {
                    canBeRecaptured = true;
                    break outer;
                  }
                }
              }
            }
          }
        }

        board[cap.fromR][cap.fromC] = savedFrom;
        board[cap.toR][cap.toC] = savedTo;

        final score = (canBeRecaptured ? 50.0 : 120.0) +
            cap.loops.length * 4.0 +
            rng.nextDouble();
        if (score > bestScore) {
          bestScore = score;
          bestCap = cap;
        }
      }
      final chosen = bestCap ?? captures.first;
      return {
        'type': 'capture',
        'fromR': chosen.fromR,
        'fromC': chosen.fromC,
        'toR': chosen.toR,
        'toC': chosen.toC,
      };
    }

    // Otherwise evaluate steps: prefer steps that create capture threats on the next turn
    // or move onto orbit lines (rows/cols 0, 1, 4, 5) while avoiding opening self up to capture.
    Map<String, dynamic>? bestStep;
    var bestStepScore = double.negativeInfinity;
    for (final st in steps) {
      final fr = st['fromR'] as int;
      final fc = st['fromC'] as int;
      final tr = st['toR'] as int;
      final tc = st['toC'] as int;

      board[fr][fc] = 0;
      board[tr][tc] = myPiece;

      final nextCaptures = traceCaptureRays(tr, tc, seat).length;
      final onOrbitRow = (tr == 0 || tr == 1 || tr == 4 || tr == 5) ? 1.0 : 0.0;
      final onOrbitCol = (tc == 0 || tc == 1 || tc == 4 || tc == 5) ? 1.0 : 0.0;
      final advanceBonus = seat == 0 ? (fr - tr) * 0.6 : (tr - fr) * 0.6;

      board[fr][fc] = myPiece;
      board[tr][tc] = 0;

      final score = nextCaptures * 15.0 +
          (onOrbitRow + onOrbitCol) * 1.5 +
          advanceBonus +
          rng.nextDouble() * 1.2;
      if (score > bestStepScore) {
        bestStepScore = score;
        bestStep = st;
      }
    }

    return bestStep ?? steps.first;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final legalCaptures = <Map<String, dynamic>>[];
    if (!_over) {
      final myPiece = pieceOfSeat(turn);
      for (var r = 0; r < 6; r++) {
        for (var c = 0; c < 6; c++) {
          if (board[r][c] == myPiece) {
            for (final cap in traceCaptureRays(r, c, turn)) {
              legalCaptures.add(cap.toJson());
            }
          }
        }
      }
    }

    return {
      'mode': mode,
      'turn': turn,
      'turnCount': turnCount,
      'quietMoves': quietMoves,
      'maxQuietMoves': maxQuietMoves,
      'over': _over,
      'winner': winner,
      'winReason': winReason,
      'board': [
        for (final row in board) List<int>.of(row),
      ],
      'captured': List<int>.of(captured),
      'remaining': [remainingCount(0), remainingCount(1)],
      'legalCaptures': legalCaptures,
      'lastMove': lastMove,
    };
  }
}
