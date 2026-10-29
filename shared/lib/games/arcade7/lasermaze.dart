import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';
import 'a7_util.dart';

class LaserMazePuzzle {
  final int size;
  /// Cell codes (`0..size*size-1`):
  /// - `0`: empty modifiable floor (player can place/rotate `/` (`1`) or `\` (`2`) mirror)
  /// - `1`: Laser Emitter
  /// - `2`: Target Receiver
  /// - `3`: Crystal Checkpoint
  /// - `4`: Fixed Wall / Obstacle
  /// - `5`: Fixed `/` Mirror
  /// - `6`: Fixed `\` Mirror
  /// - `7`: Fixed `/` Beam Splitter (straight + `/` reflection)
  /// - `8`: Fixed `\` Beam Splitter (straight + `\` reflection)
  final List<int> grid;
  final int emitterR;
  final int emitterC;
  /// `0`: Up, `1`: Right, `2`: Down, `3`: Left.
  final int emitterDir;
  final int targetR;
  final int targetC;
  /// Direction the Target Receiver's open port faces (`0..3`).
  /// A beam travelling in `beamDir` enters from side `(beamDir + 2) % 4`.
  final int targetOpenDir;
  /// Cell indices of all Crystal Checkpoints (`grid[idx] == 3`).
  final List<int> crystalIndices;
  /// Solution player mirror board (`0`, `1` = `/`, `2` = `\`) on modifiable cells (`grid[idx] == 0`).
  final List<int> solutionBoard;

  const LaserMazePuzzle({
    required this.size,
    required this.grid,
    required this.emitterR,
    required this.emitterC,
    required this.emitterDir,
    required this.targetR,
    required this.targetC,
    required this.targetOpenDir,
    required this.crystalIndices,
    required this.solutionBoard,
  });
}

class LaserSegment {
  final int r1;
  final int c1;
  final int r2;
  final int c2;
  final int dir;

  const LaserSegment({
    required this.r1,
    required this.c1,
    required this.r2,
    required this.c2,
    required this.dir,
  });

  Map<String, dynamic> toJson() => {
        'r1': r1,
        'c1': c1,
        'r2': r2,
        'c2': c2,
        'dir': dir,
      };
}

class LaserRaycastResult {
  final List<LaserSegment> segments;
  final Set<int> litCells;
  final Set<int> litCrystals;
  final bool targetHit;
  final int totalCrystals;

  const LaserRaycastResult({
    required this.segments,
    required this.litCells,
    required this.litCrystals,
    required this.targetHit,
    required this.totalCrystals,
  });

  bool get isSolved => targetHit && litCrystals.length == totalCrystals;
}

class LaserMazeSolver {
  static const List<int> dr = [-1, 0, 1, 0];
  static const List<int> dc = [0, 1, 0, -1];

  /// Reflects [dir] (`0..3`) off a mirror of type `1` (`/`) or `2` (`\`).
  static int reflectDir(int dir, int mirrorType) {
    if (mirrorType == 1) return dir ^ 1; // 0<->1, 2<->3
    if (mirrorType == 2) return 3 - dir; // 0<->3, 1<->2
    return dir;
  }

  /// Performs a full optical raycast on [puzzle] with player mirrors [board].
  static LaserRaycastResult raycast(LaserMazePuzzle puzzle, List<int> board) {
    final size = puzzle.size;
    final grid = puzzle.grid;
    final segments = <LaserSegment>[];
    final litCells = <int>{puzzle.emitterR * size + puzzle.emitterC};
    final litCrystals = <int>{};
    var targetHit = false;

    // Queue of outgoing rays: (r, c, dir)
    final q = Queue<(int, int, int)>();
    final visitedRays = <int>{};

    void enqueueRay(int r, int c, int dir) {
      final stateKey = (r * size + c) * 4 + dir;
      if (visitedRays.add(stateKey)) {
        q.add((r, c, dir));
      }
    }

    enqueueRay(puzzle.emitterR, puzzle.emitterC, puzzle.emitterDir);

    while (q.isNotEmpty) {
      final (r, c, dir) = q.removeFirst();
      final nr = r + dr[dir];
      final nc = c + dc[dir];
      if (nr < 0 || nr >= size || nc < 0 || nc >= size) {
        continue; // exits board boundary
      }

      final nIdx = nr * size + nc;
      final cell = grid[nIdx];

      if (cell == 4 || cell == 1) {
        // Blocked by wall or emitter housing
        continue;
      }

      if (cell == 2) {
        // Target Receiver: only activates if entered from targetOpenDir
        final enterSide = (dir + 2) % 4;
        if (enterSide == puzzle.targetOpenDir) {
          segments.add(LaserSegment(r1: r, c1: c, r2: nr, c2: nc, dir: dir));
          litCells.add(nIdx);
          targetHit = true;
        }
        continue;
      }

      // Beam reaches center of (nr, nc)
      segments.add(LaserSegment(r1: r, c1: c, r2: nr, c2: nc, dir: dir));
      litCells.add(nIdx);

      switch (cell) {
        case 3: // Crystal Checkpoint: beam passes straight through
          litCrystals.add(nIdx);
          enqueueRay(nr, nc, dir);
        case 5: // Fixed '/' Mirror
          enqueueRay(nr, nc, reflectDir(dir, 1));
        case 6: // Fixed '\' Mirror
          enqueueRay(nr, nc, reflectDir(dir, 2));
        case 7: // Fixed '/' Beam Splitter
          enqueueRay(nr, nc, dir);
          enqueueRay(nr, nc, reflectDir(dir, 1));
        case 8: // Fixed '\' Beam Splitter
          enqueueRay(nr, nc, dir);
          enqueueRay(nr, nc, reflectDir(dir, 2));
        default: // Modifiable floor (cell == 0)
          final m = nIdx < board.length ? board[nIdx] : 0;
          if (m == 1 || m == 2) {
            enqueueRay(nr, nc, reflectDir(dir, m));
          } else {
            enqueueRay(nr, nc, dir);
          }
      }
    }

    return LaserRaycastResult(
      segments: segments,
      litCells: litCells,
      litCrystals: litCrystals,
      targetHit: targetHit,
      totalCrystals: puzzle.crystalIndices.length,
    );
  }

  static bool isSolved(LaserMazePuzzle puzzle, List<int> board) {
    if (board.length != puzzle.size * puzzle.size) return false;
    return raycast(puzzle, board).isSolved;
  }

  /// Generates a 100% guaranteed-solvable Laser Maze puzzle for [size] (`6` or `7`).
  static LaserMazePuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    final emptyBoard = List<int>.filled(n, 0);

    for (var attempt = 0; attempt < 40; attempt++) {
      final used = List<bool>.filled(n, false);
      final er = rng.nextInt(size);
      final ec = rng.nextInt(size);
      used[er * size + ec] = true;

      // Pick initial direction with at least 2 cells available
      final validStartDirs = <int>[
        for (var d = 0; d < 4; d++)
          if (er + dr[d] * 2 >= 0 &&
              er + dr[d] * 2 < size &&
              ec + dc[d] * 2 >= 0 &&
              ec + dc[d] * 2 < size)
            d,
      ];
      if (validStartDirs.isEmpty) continue;
      final eDir = validStartDirs[rng.nextInt(validStartDirs.length)];

      var curR = er, curC = ec, curDir = eDir;
      final turns = <(int, int, int)>[]; // (r, c, mirrorType 1|2)
      final straightCells = <int>[];
      final targetTurns = 3 + rng.nextInt(2); // 3 or 4 turns

      var okPath = true;
      for (var seg = 0; seg <= targetTurns; seg++) {
        // Determine max unvisited steps in curDir
        var maxLen = 0;
        var tr = curR + dr[curDir], tc = curC + dc[curDir];
        while (tr >= 0 && tr < size && tc >= 0 && tc < size && !used[tr * size + tc]) {
          maxLen++;
          tr += dr[curDir];
          tc += dc[curDir];
        }
        if (maxLen < 1 || (seg == 0 && maxLen < 2)) {
          okPath = false;
          break;
        }
        final minLen = seg == 0 ? 2 : 1;
        final len = minLen + rng.nextInt(maxLen - minLen + 1);

        for (var step = 1; step <= len; step++) {
          final nr = curR + dr[curDir] * step;
          final nc = curC + dc[curDir] * step;
          final idx = nr * size + nc;
          used[idx] = true;
          if (step < len) {
            straightCells.add(idx);
          }
        }
        curR += dr[curDir] * len;
        curC += dc[curDir] * len;

        if (seg < targetTurns) {
          // Pick a perpendicular direction with at least 1 unvisited cell
          final perpDirs = <int>[curDir ^ 1, 3 - curDir]..shuffle(rng);
          int? nextDir;
          for (final nd in perpDirs) {
            final nr = curR + dr[nd], nc = curC + dc[nd];
            if (nr >= 0 && nr < size && nc >= 0 && nc < size && !used[nr * size + nc]) {
              nextDir = nd;
              break;
            }
          }
          if (nextDir == null) {
            okPath = false;
            break;
          }
          final mirrorType = nextDir == (curDir ^ 1) ? 1 : 2;
          turns.add((curR, curC, mirrorType));
          curDir = nextDir;
        }
      }

      if (!okPath || turns.length < 3 || straightCells.isEmpty) continue;

      final grid = List<int>.filled(n, 0);
      final solBoard = List<int>.filled(n, 0);

      grid[er * size + ec] = 1; // Emitter
      final targetIdx = curR * size + curC;
      grid[targetIdx] = 2; // Target Receiver
      final targetOpenDir = (curDir + 2) % 4;

      // Pick 1..3 Crystal Checkpoints along straight segments
      straightCells.shuffle(rng);
      final crystalCount = min(straightCells.length, 1 + rng.nextInt(3));
      final crystals = <int>[
        for (var i = 0; i < crystalCount; i++) straightCells[i],
      ]..sort();
      for (final cIdx in crystals) {
        grid[cIdx] = 3;
      }

      // First turn becomes either a Fixed Mirror (5/6) or Fixed Beam Splitter (7/8);
      // remaining turns are player-modifiable mirrors in solBoard
      for (var i = 0; i < turns.length; i++) {
        final (mr, mc, mType) = turns[i];
        final mIdx = mr * size + mc;
        if (i == 0) {
          final useSplitter = rng.nextBool();
          grid[mIdx] = useSplitter ? (mType == 1 ? 7 : 8) : (mType == 1 ? 5 : 6);
        } else {
          solBoard[mIdx] = mType;
        }
      }

      // Place 2..4 Fixed Walls on unused cells
      final unused = <int>[
        for (var i = 0; i < n; i++)
          if (!used[i]) i,
      ]..shuffle(rng);
      final wallCount = min(unused.length, 2 + rng.nextInt(3));
      for (var i = 0; i < wallCount; i++) {
        grid[unused[i]] = 4;
      }

      final puz = LaserMazePuzzle(
        size: size,
        grid: grid,
        emitterR: er,
        emitterC: ec,
        emitterDir: eDir,
        targetR: curR,
        targetC: curC,
        targetOpenDir: targetOpenDir,
        crystalIndices: crystals,
        solutionBoard: solBoard,
      );

      if (isSolved(puz, solBoard) && !isSolved(puz, emptyBoard)) {
        return puz;
      }
    }

    // Deterministic guaranteed fallback layout
    final grid = List<int>.filled(n, 0);
    final solBoard = List<int>.filled(n, 0);
    // Emitter at (0, 0) firing Right (1)
    // Fixed '/' Splitter at (0, 3) -> reflects Down (2) to (4, 3)
    // Crystal at (2, 3)
    // Modifiable '\' Mirror (2) at (4, 3) -> reflects Right (1) to (4, 5)
    // Modifiable '/' Mirror (1) at (4, 5) -> reflects Up (0) to (1, 5)
    // Crystal at (3, 5)
    // Modifiable '\' Mirror (2) at (1, 5) -> reflects Left (3) to Target at (1, 2) (open port Right = 1)
    grid[0 * size + 0] = 1;
    grid[0 * size + 3] = 8; // '\' Splitter: Right (1) reflects Down (2)
    grid[2 * size + 3] = 3; // Crystal 1
    solBoard[4 * size + 3] = 2; // '\': Down (2) -> Right (1)
    solBoard[4 * size + 5] = 1; // '/': Right (1) -> Up (0)
    grid[3 * size + 5] = 3; // Crystal 2
    solBoard[1 * size + 5] = 2; // '\': Up (0) -> Left (3)
    grid[1 * size + 2] = 2; // Target Receiver (entered moving Left=3, so openDir=1)
    grid[3 * size + 1] = 4; // Wall
    grid[5 * size + 2] = 4; // Wall

    final crystals = <int>[2 * size + 3, 3 * size + 5];
    return LaserMazePuzzle(
      size: size,
      grid: grid,
      emitterR: 0,
      emitterC: 0,
      emitterDir: 1,
      targetR: 1,
      targetC: 2,
      targetOpenDir: 1,
      crystalIndices: crystals,
      solutionBoard: solBoard,
    );
  }
}

/// 激光迷宫竞速 (Laser Maze Race, 1-6 人).
class LaserMazeGame extends GameEngine {
  LaserMazeGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late LaserMazePuzzle currentPuzzle;
  late List<LaserMazePlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<List<int>> get boards => [for (final p in ps) p.board];
  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a7Placings(ranking, players) : null;

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
    size = rawSize == 7 ? 7 : 6;
    totalRounds = setup.opt<int>('rounds', 3) == 1 ? 1 : 3;

    currentPuzzle = LaserMazeSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) LaserMazePlayer(size * size)];

    host.log('激光迷宫竞速开始（$size×$size 迷宫，共 $totalRounds 局）！旋转或放置反射镜点亮全部水晶并射入目标接收器即可过关！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = LaserMazeSolver.generatePuzzle(size, rng);
    }
    for (var s = 0; s < players; s++) {
      ps[s].resetForRound(size * size);
    }
  }

  void _clock() {
    if (over) return;
    roundSec++;
    if (roundSec >= roundMaxSec) {
      _endRound('本局时间到');
    }
    if (!over) host.schedule(1000, _clock);
  }

  bool _activeInRound(int s) => ps[s].resignNo == 0 && ps[s].status == 'play';

  @override
  List<int> get waitingFor {
    if (over) return const [];
    return a7Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
  }

  int _resolveEmptyCellIndex(Map<String, dynamic> a) {
    int idx;
    if (a.containsKey('r') && a.containsKey('c')) {
      final r = asInt(a['r']);
      final c = asInt(a['c']);
      if (r < 0 || r >= size || c < 0 || c >= size) {
        throw GameError('行列坐标超出迷宫范围');
      }
      idx = r * size + c;
    } else {
      idx = asInt(a['i']);
      if (idx < 0 || idx >= size * size) {
        throw GameError('格子索引超出迷宫范围');
      }
    }
    if (currentPuzzle.grid[idx] != 0) {
      throw GameError('该位置是固定光学元件或墙壁，不能放置或旋转反射镜');
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
    if (p.status != 'play') throw GameError('你已完成本局');

    switch (type) {
      case 'rotate':
      case 'toggle':
        final idx = _resolveEmptyCellIndex(a);
        p.board[idx] = (p.board[idx] + 1) % 3;
        moves++;
        if (LaserMazeSolver.isSolved(currentPuzzle, p.board)) {
          _markSolved(seat);
        }

      case 'place':
      case 'set':
        final idx = _resolveEmptyCellIndex(a);
        final mirror = a.containsKey('mirror') ? asInt(a['mirror']) : asInt(a['val']);
        if (mirror < 0 || mirror > 2) {
          throw GameError('反射镜类型必须为 0（无）、1（/）或 2（\\）');
        }
        p.board[idx] = mirror;
        moves++;
        if (LaserMazeSolver.isSolved(currentPuzzle, p.board)) {
          _markSolved(seat);
        }

      case 'reset':
      case 'clear':
        p.board.fillRange(0, p.board.length, 0);
        moves++;

      case 'pass':
      case 'give_up':
      case 'skip':
        p.status = 'pass';
        p.lastRoundPts = 0;
        moves++;
        host.log('${name(seat)} 放弃了第 $round 局');
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
    host.log('${name(seat)} 第 $roundSolvers 个导通激光激活全部水晶与接收器，+$pts 分！');
    _checkRoundComplete();
  }

  void _checkRoundComplete() {
    if (over) return;
    if ([for (var s = 0; s < players; s++) if (_activeInRound(s)) s].isEmpty) {
      _endRound('全员完成第 $round 局');
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
      _finish('全部 $totalRounds 局已完成');
    } else {
      _startRound(round + 1);
    }
  }

  void _finish(String why) {
    if (over) return;
    over = true;
    ranking = a7Ranking(players, (a, b) {
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
    host.log('游戏结束（$why）！冠军：${a7Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || !_activeInRound(seat)) return null;
    final p = ps[seat];
    final sol = currentPuzzle.solutionBoard;

    final anyPlaced = p.board.any((m) => m != 0);
    if (botLevel <= 0 && !anyPlaced && rng.nextInt(8) == 0) {
      return {'type': 'pass'};
    }

    // First fix any wrongly placed mirror
    for (var i = 0; i < p.board.length; i++) {
      if (p.board[i] != 0 && p.board[i] != sol[i]) {
        return {'type': 'place', 'r': i ~/ size, 'c': i % size, 'mirror': sol[i]};
      }
    }

    // Place a missing solution mirror
    final missing = <int>[
      for (var i = 0; i < sol.length; i++)
        if (sol[i] != 0 && p.board[i] != sol[i]) i,
    ];
    if (missing.isNotEmpty) {
      final pick = missing[rng.nextInt(missing.length)];
      return {'type': 'place', 'r': pick ~/ size, 'c': pick % size, 'mirror': sol[pick]};
    }

    return {'type': 'pass'};
  }

  // ---------------------------------------------------------------- view

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players ? ps[seat] : (ps.isNotEmpty ? ps[0] : null);
    final myBoard = me?.board ?? List<int>.filled(size * size, 0);
    final ray = LaserMazeSolver.raycast(currentPuzzle, myBoard);

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'grid': currentPuzzle.grid,
      'emitterR': currentPuzzle.emitterR,
      'emitterC': currentPuzzle.emitterC,
      'emitterDir': currentPuzzle.emitterDir,
      'targetR': currentPuzzle.targetR,
      'targetC': currentPuzzle.targetC,
      'targetOpenDir': currentPuzzle.targetOpenDir,
      'board': myBoard,
      'segments': [for (final seg in ray.segments) seg.toJson()],
      'litCells': ray.litCells.toList()..sort(),
      'litCrystals': ray.litCrystals.toList()..sort(),
      'targetHit': ray.targetHit,
      'litCrystalCount': ray.litCrystals.length,
      'totalCrystals': max(1, ray.totalCrystals),
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pRay = LaserMazeSolver.raycast(currentPuzzle, ps[s].board);
            final goalTotal = pRay.totalCrystals + 1;
            final goalDone = pRay.litCrystals.length + (pRay.targetHit ? 1 : 0);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'goalDone': goalDone,
              'goalTotal': max(1, goalTotal),
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class LaserMazePlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  LaserMazePlayer(int cellCount) : board = List<int>.filled(cellCount, 0);

  void resetForRound(int cellCount) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.filled(cellCount, 0);
  }
}
