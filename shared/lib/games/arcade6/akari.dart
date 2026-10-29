import 'dart:math';

import '../../src/engine.dart';
import 'a6_util.dart';

class AkariPuzzle {
  final int size;
  /// `-2`: white corridor, `-1`: unnumbered black wall, `0..4`: numbered black wall.
  final List<int> grid;
  /// White cell indices (`0..size*size-1`) containing light bulbs in the generated solution.
  final Set<int> solutionBulbs;

  const AkariPuzzle({
    required this.size,
    required this.grid,
    required this.solutionBulbs,
  });
}

class AkariSolver {
  static const List<int> dr = [-1, 0, 1, 0];
  static const List<int> dc = [0, 1, 0, -1];

  static bool isWall(int cellType) => cellType >= -1;

  /// Computes `(lit, conflictingBulbs)` for a `size × size` [puzzleGrid] and player [board].
  static (List<bool>, Set<int>) analyzeIllumination(
    List<int> puzzleGrid,
    List<int> board,
    int size,
  ) {
    final n = size * size;
    final lit = List<bool>.filled(n, false);
    final conflicts = <int>{};

    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final idx = r * size + c;
        if (puzzleGrid[idx] != -2 || board[idx] != 1) continue;
        lit[idx] = true;
        for (var d = 0; d < 4; d++) {
          var nr = r + dr[d];
          var nc = c + dc[d];
          while (nr >= 0 && nr < size && nc >= 0 && nc < size) {
            final nIdx = nr * size + nc;
            if (puzzleGrid[nIdx] != -2) break; // blocked by wall
            lit[nIdx] = true;
            if (board[nIdx] == 1) {
              conflicts.add(idx);
              conflicts.add(nIdx);
            }
            nr += dr[d];
            nc += dc[d];
          }
        }
      }
    }
    return (lit, conflicts);
  }

  /// Counts orthogonally adjacent light bulbs (`board[nIdx] == 1`) around `(r, c)`.
  static int adjacentBulbCount(List<int> puzzleGrid, List<int> board, int size, int r, int c) {
    var count = 0;
    for (var d = 0; d < 4; d++) {
      final nr = r + dr[d];
      final nc = c + dc[d];
      if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
      final nIdx = nr * size + nc;
      if (puzzleGrid[nIdx] == -2 && board[nIdx] == 1) {
        count++;
      }
    }
    return count;
  }

  /// Returns true if:
  /// 1. Every white cell (`-2`) is illuminated by at least one Light Bulb,
  /// 2. No two Light Bulbs illuminate each other along a clear row/column segment, and
  /// 3. Every numbered black wall `k` (`0..4`) has exactly `k` adjacent Light Bulbs.
  static bool isSolved(List<int> puzzleGrid, List<int> board, int size) {
    final n = size * size;
    if (puzzleGrid.length != n || board.length != n) return false;

    for (var i = 0; i < n; i++) {
      if (puzzleGrid[i] != -2 && board[i] == 1) return false;
    }

    final (lit, conflicts) = analyzeIllumination(puzzleGrid, board, size);
    if (conflicts.isNotEmpty) return false;

    for (var i = 0; i < n; i++) {
      final cell = puzzleGrid[i];
      if (cell == -2) {
        if (!lit[i]) return false;
      } else if (cell >= 0 && cell <= 4) {
        final r = i ~/ size, c = i % size;
        if (adjacentBulbCount(puzzleGrid, board, size, r, c) != cell) {
          return false;
        }
      }
    }
    return true;
  }

  /// Generates a 100% guaranteed-solvable Akari puzzle for [size] (`6` or `8`).
  static AkariPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    final grid = List<int>.filled(n, -2);

    // Place 180-degree rotationally symmetric black walls (-1) on ~22% of cells
    final pairCount = size <= 6 ? (3 + rng.nextInt(2)) : (6 + rng.nextInt(3));
    final halfLimit = n ~/ 2;
    final candidates = [for (var i = 0; i < halfLimit; i++) i]..shuffle(rng);
    for (var k = 0; k < min(pairCount, candidates.length); k++) {
      final idx = candidates[k];
      final sym = n - 1 - idx;
      grid[idx] = -1;
      grid[sym] = -1;
    }

    // Place non-conflicting bulbs on unilluminated white cells until 100% of white cells are lit.
    // Because line-of-sight is symmetric, any currently unlit white cell cannot see any existing bulb!
    final board = List<int>.filled(n, 0);
    final bulbs = <int>{};
    while (true) {
      final (lit, _) = analyzeIllumination(grid, board, size);
      final unlitWhite = <int>[
        for (var i = 0; i < n; i++)
          if (grid[i] == -2 && !lit[i]) i,
      ];
      if (unlitWhite.isEmpty) break;

      // Prefer unlit cells near walls to produce rich wall clue numbers
      final nearWall = <int>[
        for (final idx in unlitWhite)
          if (_hasAdjacentWall(grid, size, idx ~/ size, idx % size)) idx,
      ];
      final pool = (nearWall.isNotEmpty && rng.nextDouble() < 0.75) ? nearWall : unlitWhite;
      final pick = pool[rng.nextInt(pool.length)];
      board[pick] = 1;
      bulbs.add(pick);
    }

    // Assign exact clue numbers (0..4) to ~75% of black walls, leaving ~25% as unnumbered (-1)
    var numberedWalls = 0;
    for (var i = 0; i < n; i++) {
      if (grid[i] == -1) {
        final r = i ~/ size, c = i % size;
        final adjBulbs = adjacentBulbCount(grid, board, size, r, c);
        if (adjBulbs > 0 || numberedWalls < 2 || rng.nextDouble() < 0.72) {
          grid[i] = adjBulbs;
          numberedWalls++;
        }
      }
    }

    return AkariPuzzle(
      size: size,
      grid: grid,
      solutionBulbs: bulbs,
    );
  }

  static bool _hasAdjacentWall(List<int> grid, int size, int r, int c) {
    for (var d = 0; d < 4; d++) {
      final nr = r + dr[d], nc = c + dc[d];
      if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
        if (grid[nr * size + nc] >= -1) return true;
      }
    }
    return false;
  }
}

/// 美术馆照明竞速 (Akari / Light Up Race, 1-6 人).
class AkariGame extends GameEngine {
  AkariGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late AkariPuzzle currentPuzzle;
  late List<AkariPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<List<int>> get boards => [for (final p in ps) p.board];
  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a6Placings(ranking, players) : null;

  @override
  bool get canResign => !over;

  @override
  int get botDelayMs => switch (botLevel) { 0 => 760, 2 => 250, _ => 450 };

  @override
  void resign(int seat) {
    if (over) throw GameError('对局已结束');
    if (seat < 0 || seat >= players) throw GameError('观众不能认输');
    final p = ps[seat];
    if (p.resignNo > 0) throw GameError('你已认输');
    p.resignNo = ++_resigns;
    p.status = 'resigned';
    host.log('${name(seat)} 认输');
    final still = [for (var s = 0; s < players; s++) if (ps[s].resignNo == 0) s];
    if (still.isEmpty || (players > 1 && still.length <= 1)) {
      _finish(still.isEmpty ? '所有人都已认输' : '其他人都已认输');
    } else {
      _checkRoundComplete();
    }
  }

  @override
  void start() {
    final rawSize = setup.opt<int>('size', 6);
    size = rawSize == 8 ? 8 : 6;
    totalRounds = setup.opt<int>('rounds', 3) == 1 ? 1 : 3;

    currentPuzzle = AkariSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) AkariPlayer(size * size)];

    host.log('美术馆照明竞速开始（$size×$size 展厅，共 $totalRounds 题）！放置灯泡照亮所有白格且互不直射、满足黑墙数字即可过关！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = AkariSolver.generatePuzzle(size, rng);
    }
    for (var s = 0; s < players; s++) {
      ps[s].resetForRound(size * size);
    }
  }

  void _clock() {
    if (over) return;
    roundSec++;
    if (roundSec >= roundMaxSec) {
      _endRound('本题时间到');
    }
    if (!over) host.schedule(1000, _clock);
  }

  bool _activeInRound(int s) => ps[s].resignNo == 0 && ps[s].status == 'play';

  @override
  List<int> get waitingFor {
    if (over) return const [];
    return a6Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
  }

  int _resolveWhiteCellIndex(Map<String, dynamic> a) {
    int idx;
    if (a.containsKey('r') && a.containsKey('c')) {
      final r = asInt(a['r']);
      final c = asInt(a['c']);
      if (r < 0 || r >= size || c < 0 || c >= size) {
        throw GameError('行列坐标超出棋盘范围');
      }
      idx = r * size + c;
    } else {
      idx = asInt(a['i']);
      if (idx < 0 || idx >= size * size) {
        throw GameError('格子索引超出棋盘范围');
      }
    }
    if (currentPuzzle.grid[idx] != -2) {
      throw GameError('黑色墙壁格上不能放置灯泡或标记');
    }
    return idx;
  }

  @override
  void handle(int seat, Map<String, dynamic> a) {
    if (over) throw GameError('对局已结束');
    if (seat < 0 || seat >= players) throw GameError('观众不能操作');
    final type = asStr(a['type']);
    if (type == 'idle' || type == 'next') return;
    final p = ps[seat];
    if (p.resignNo > 0) throw GameError('你已认输');
    if (p.status != 'play') throw GameError('你已完成本题');

    switch (type) {
      case 'set':
        final idx = _resolveWhiteCellIndex(a);
        final val = asInt(a['val']);
        if (val < 0 || val > 2) {
          throw GameError('单元格状态值必须为 0、1 或 2');
        }
        p.board[idx] = val;
        moves++;
        if (AkariSolver.isSolved(currentPuzzle.grid, p.board, size)) {
          _markSolved(seat);
        }

      case 'toggle':
        final idx = _resolveWhiteCellIndex(a);
        final cur = p.board[idx];
        if (a.containsKey('mode')) {
          final mode = asInt(a['mode'], 1) == 2 ? 2 : 1;
          p.board[idx] = cur == mode ? 0 : mode;
        } else {
          p.board[idx] = (cur + 1) % 3;
        }
        moves++;
        if (AkariSolver.isSolved(currentPuzzle.grid, p.board, size)) {
          _markSolved(seat);
        }

      case 'clear':
      case 'reset':
        p.board.fillRange(0, p.board.length, 0);
        moves++;

      case 'pass':
      case 'give_up':
      case 'skip':
        p.status = 'pass';
        p.lastRoundPts = 0;
        moves++;
        host.log('${name(seat)} 放弃了第 $round 题');
        _checkRoundComplete();

      default:
        throw GameError('未知操作');
    }
  }

  void _markSolved(int seat) {
    final p = ps[seat];
    roundSolvers++;
    final pts = switch (roundSolvers) {
      1 => 10,
      2 => 8,
      3 => 6,
      _ => 4,
    };
    p.status = 'solved';
    p.solveRank = roundSolvers;
    p.lastRoundPts = pts;
    p.score += pts;
    p.solvedCount++;
    p.totalSolveSec += roundSec;
    host.log('${name(seat)} 第 $roundSolvers 个点亮整座美术馆，+$pts 分！');
    _checkRoundComplete();
  }

  void _checkRoundComplete() {
    if (over) return;
    if ([for (var s = 0; s < players; s++) if (_activeInRound(s)) s].isEmpty) {
      _endRound('全员完成第 $round 题');
    }
  }

  void _endRound(String reason) {
    lastRoundSummary = {
      'round': round,
      'reason': reason,
      'ps': [
        for (var s = 0; s < players; s++)
          {
            's': s,
            'status': ps[s].status,
            'pts': ps[s].lastRoundPts,
            'rank': ps[s].solveRank,
          },
      ],
    };

    if (round >= totalRounds) {
      _finish('全部 $totalRounds 题已完成');
    } else {
      _startRound(round + 1);
    }
  }

  void _finish(String why) {
    if (over) return;
    over = true;
    ranking = a6Ranking(players, (a, b) {
      final pa = ps[a], pb = ps[b];
      if (pa.resignNo != pb.resignNo) {
        return pa.resignNo == 0 ? -1 : (pb.resignNo == 0 ? 1 : pb.resignNo - pa.resignNo);
      }
      if (pa.score != pb.score) return pb.score - pa.score;
      if (pa.solvedCount != pb.solvedCount) return pb.solvedCount - pa.solvedCount;
      return pa.totalSolveSec - pb.totalSolveSec;
    }, (s) => {
          'score': ps[s].score,
          'solved': ps[s].solvedCount,
          'sec': ps[s].totalSolveSec,
        });
    host.log('游戏结束（$why）！冠军：${a6Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || !_activeInRound(seat)) return null;
    final p = ps[seat];
    final solBulbs = currentPuzzle.solutionBulbs;

    // Easy bot occasionally gives up at the start of a round
    final anyMarked = p.board.any((v) => v != 0);
    if (botLevel <= 0 && !anyMarked && rng.nextInt(8) == 0) {
      return {'type': 'pass'};
    }

    // First remove any misplaced bulb (board[i] == 1 where i is not in solBulbs)
    for (var i = 0; i < p.board.length; i++) {
      if (p.board[i] == 1 && !solBulbs.contains(i)) {
        return {'type': 'set', 'r': i ~/ size, 'c': i % size, 'val': 2};
      }
    }

    // Place a missing solution bulb
    final missing = <int>[
      for (final idx in solBulbs)
        if (p.board[idx] != 1) idx,
    ];
    if (missing.isNotEmpty) {
      final pick = missing[rng.nextInt(missing.length)];
      return {'type': 'set', 'r': pick ~/ size, 'c': pick % size, 'val': 1};
    }

    return {'type': 'pass'};
  }

  // ---------------------------------------------------------------- view

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players ? ps[seat] : (ps.isNotEmpty ? ps[0] : null);
    final grid = currentPuzzle.grid;
    final myBoard = me?.board ?? List<int>.filled(size * size, 0);
    final (lit, conflicts) = AkariSolver.analyzeIllumination(grid, myBoard, size);

    final totalWhite = grid.where((c) => c == -2).length;
    final litWhite = [
      for (var i = 0; i < grid.length; i++)
        if (grid[i] == -2 && lit[i]) i,
    ].length;

    final wallOk = <bool>[];
    for (var i = 0; i < grid.length; i++) {
      final cell = grid[i];
      if (cell >= 0 && cell <= 4) {
        wallOk.add(AkariSolver.adjacentBulbCount(grid, myBoard, size, i ~/ size, i % size) == cell);
      } else {
        wallOk.add(true);
      }
    }

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'grid': grid,
      'board': myBoard,
      'lit': lit,
      'conflicts': conflicts.toList()..sort(),
      'wallOk': wallOk,
      'litWhite': litWhite,
      'totalWhite': totalWhite,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final (pLit, _) = AkariSolver.analyzeIllumination(grid, ps[s].board, size);
            final pLitWhite = [
              for (var i = 0; i < grid.length; i++)
                if (grid[i] == -2 && pLit[i]) i,
            ].length;
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'litWhite': pLitWhite,
              'totalWhite': max(1, totalWhite),
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class AkariPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  AkariPlayer(int cellCount) : board = List<int>.filled(cellCount, 0);

  void resetForRound(int cellCount) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.filled(cellCount, 0);
  }
}
