import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';
import 'a17_util.dart';

/// Validates whether [board] (flat `size * size` list of `0..4` on white cells)
/// and [clues] (flat `size * size` list where `-2` = white fillable cell,
/// `-1` = unnumbered black cell, `0..4` = numbered black clue cell)
/// satisfy all Nikoli Shakashaka rules:
/// 1. Every numbered Black Clue Cell (`0..4`) has exactly `clue` orthogonally adjacent
///    triangles (`val in 1..4`).
/// 2. Every connected component of white quarter-triangles forms an exact
///    axis-aligned rectangle or 45°-tilted rectangle.
bool validateShakashaka(int size, List<int> board, List<int> clues) {
  if (size <= 0 || board.length != size * size || clues.length != size * size) {
    return false;
  }
  final puz = ShakashakaPuzzle(
    size: size,
    clues: clues,
    solutionBoard: board,
  );
  return ShakashakaSolver.analyze(puz, board).isSolved;
}

class ShakashakaPuzzle {
  final int size;
  /// Flat `size * size` cell clues:
  /// `-2`: White fillable cell
  /// `-1`: Unnumbered black cell
  /// `0..4`: Numbered black clue cell (requires `0..4` orthogonally adjacent triangles)
  final List<int> clues;
  /// Flat `size * size` valid solution (`0` on black cells; `0..4` on white cells).
  final List<int> solutionBoard;

  const ShakashakaPuzzle({
    required this.size,
    required this.clues,
    required this.solutionBoard,
  });

  List<int> get initialBoard => List<int>.filled(size * size, 0);

  bool isBlackCell(int idx) => idx >= 0 && idx < clues.length && clues[idx] >= -1;
}

class ShakashakaAnalysis {
  final Set<int> satisfiedClueCells;
  final Set<int> violatedClueCells;
  final Set<int> pendingClueCells;
  final Map<int, int> clueAdjacentTriangleCounts;
  final int totalNumberedClues;
  final int whiteRegionCount;
  final int validRectRegionCount;
  final int axisRectCount;
  final int tiltedRectCount;
  final Set<int> nonRectCells;
  final Set<int> conflictCells;
  final int triangleCount;

  const ShakashakaAnalysis({
    required this.satisfiedClueCells,
    required this.violatedClueCells,
    required this.pendingClueCells,
    required this.clueAdjacentTriangleCounts,
    required this.totalNumberedClues,
    required this.whiteRegionCount,
    required this.validRectRegionCount,
    required this.axisRectCount,
    required this.tiltedRectCount,
    required this.nonRectCells,
    required this.conflictCells,
    required this.triangleCount,
  });

  bool get isSolved =>
      violatedClueCells.isEmpty &&
      pendingClueCells.isEmpty &&
      satisfiedClueCells.length == totalNumberedClues &&
      whiteRegionCount > 0 &&
      validRectRegionCount == whiteRegionCount &&
      nonRectCells.isEmpty;
}

class _ShakashakaTemplate {
  final int size;
  /// `-1` = Black cell, `0..4` = White cell solution state (`0` empty, `1..4` triangle).
  final List<int> grid;
  const _ShakashakaTemplate(this.size, this.grid);
}

class ShakashakaSolver {
  static const List<int> orthoDr = [-1, 0, 1, 0];
  static const List<int> orthoDc = [0, 1, 0, -1];

  /// Quarter-triangle white mask `[North, East, South, West]` for cell value `0..4`:
  /// - `0` (□ Empty White): `[true, true, true, true]`
  /// - `1` (◤ TL Black, BR White): `[false, true, true, false]`
  /// - `2` (◥ TR Black, BL White): `[false, false, true, true]`
  /// - `3` (◣ BL Black, TR White): `[true, true, false, false]`
  /// - `4` (◢ BR Black, TL White): `[true, false, false, true]`
  static List<bool> whiteQuartersForVal(int val, {required bool isBlackCell}) {
    if (isBlackCell) return const [false, false, false, false];
    return switch (val) {
      0 => const [true, true, true, true],
      1 => const [false, true, true, false],
      2 => const [false, false, true, true],
      3 => const [true, true, false, false],
      4 => const [true, false, false, true],
      _ => const [false, false, false, false],
    };
  }

  static const List<_ShakashakaTemplate> _templates5x5 = [
    // Template 1: two 2x2 diamonds + axis-aligned rectangles
    _ShakashakaTemplate(5, [
      1, 2, -1, 0, 0, //
      3, 4, -1, 0, 0, //
      -1, -1, 1, 2, -1, //
      0, 0, 3, 4, -1, //
      0, 0, -1, 0, 0, //
    ]),
    // Template 2: centered 2x2 diamond + surrounding white rectangles
    _ShakashakaTemplate(5, [
      0, 0, -1, 1, 2, //
      0, 0, -1, 3, 4, //
      -1, 1, 2, -1, -1, //
      -1, 3, 4, 0, 0, //
      0, -1, -1, 0, 0, //
    ]),
    // Template 3: 3x3 diamond at top-left + bottom-right rectangles
    _ShakashakaTemplate(5, [
      -1, 1, 2, -1, 0, //
      1, 0, 0, 2, 0, //
      3, 0, 0, 4, -1, //
      -1, 3, 4, -1, 0, //
      0, -1, 0, 0, -1, //
    ]),
  ];

  static const List<_ShakashakaTemplate> _templates6x6 = [
    // Template 1: two 2x2 diamonds + axis-aligned rectangles
    _ShakashakaTemplate(6, [
      1, 2, -1, 0, 0, 0, //
      3, 4, -1, 0, 0, 0, //
      -1, -1, 1, 2, -1, -1, //
      0, 0, 3, 4, 1, 2, //
      0, 0, -1, -1, 3, 4, //
      0, 0, -1, 0, 0, -1, //
    ]),
    // Template 2: 3x3 diamond + 2x2 diamond + axis-aligned rectangles
    _ShakashakaTemplate(6, [
      -1, 1, 2, -1, 0, 0, //
      1, 0, 0, 2, 0, 0, //
      3, 0, 0, 4, -1, -1, //
      -1, 3, 4, -1, 1, 2, //
      0, 0, -1, -1, 3, 4, //
      0, 0, -1, 0, 0, -1, //
    ]),
    // Template 3: three 2x2 diamonds + rectangles
    _ShakashakaTemplate(6, [
      0, 0, -1, 1, 2, -1, //
      0, 0, -1, 3, 4, -1, //
      -1, 1, 2, -1, 0, 0, //
      -1, 3, 4, -1, 0, 0, //
      1, 2, -1, -1, -1, -1, //
      3, 4, -1, 0, 0, 0, //
    ]),
  ];

  static ShakashakaAnalysis analyze(ShakashakaPuzzle puz, List<int> board) {
    final size = puz.size;
    final n = size * size;

    final satisfiedClueCells = <int>{};
    final violatedClueCells = <int>{};
    final pendingClueCells = <int>{};
    final clueAdjacentTriangleCounts = <int, int>{};
    var totalNumberedClues = 0;
    var triangleCount = 0;

    for (var i = 0; i < n; i++) {
      final isBlk = puz.isBlackCell(i);
      final v = i < board.length ? board[i] : 0;
      if (!isBlk && v >= 1 && v <= 4) {
        triangleCount++;
      }
      if (isBlk && puz.clues[i] >= 0) {
        totalNumberedClues++;
        final clue = puz.clues[i];
        final r = i ~/ size, c = i % size;
        var triAdj = 0;
        for (var d = 0; d < 4; d++) {
          final nr = r + orthoDr[d], nc = c + orthoDc[d];
          if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
          final nb = nr * size + nc;
          if (!puz.isBlackCell(nb)) {
            final nbVal = nb < board.length ? board[nb] : 0;
            if (nbVal >= 1 && nbVal <= 4) triAdj++;
          }
        }
        clueAdjacentTriangleCounts[i] = triAdj;
        if (triAdj == clue) {
          satisfiedClueCells.add(i);
        } else if (triAdj > clue) {
          violatedClueCells.add(i);
        } else {
          pendingClueCells.add(i);
        }
      }
    }

    // Build quarter-triangle white array: 4 quarters per cell (0=N, 1=E, 2=S, 3=W)
    final totalQuarters = n * 4;
    final isWhiteQ = List<bool>.filled(totalQuarters, false);
    for (var i = 0; i < n; i++) {
      final isBlk = puz.isBlackCell(i);
      final v = i < board.length ? board[i] : 0;
      final mask = whiteQuartersForVal(v, isBlackCell: isBlk);
      for (var dir = 0; dir < 4; dir++) {
        isWhiteQ[i * 4 + dir] = mask[dir];
      }
    }

    final visitedQ = List<bool>.filled(totalQuarters, false);
    var whiteRegionCount = 0;
    var validRectRegionCount = 0;
    var axisRectCount = 0;
    var tiltedRectCount = 0;
    final nonRectCells = <int>{};

    for (var startQ = 0; startQ < totalQuarters; startQ++) {
      if (!isWhiteQ[startQ] || visitedQ[startQ]) continue;
      whiteRegionCount++;

      final comp = <int>[];
      final compCells = <int>{};
      final q = Queue<int>()..add(startQ);
      visitedQ[startQ] = true;

      var minR = size, maxR = -1, minC = size, maxC = -1;
      var minU = 1 << 20, maxU = -(1 << 20), minV = 1 << 20, maxV = -(1 << 20);

      while (q.isNotEmpty) {
        final curQ = q.removeFirst();
        comp.add(curQ);
        final cellIdx = curQ ~/ 4;
        final dir = curQ % 4;
        compCells.add(cellIdx);

        final r = cellIdx ~/ size, c = cellIdx % size;
        if (r < minR) minR = r;
        if (r > maxR) maxR = r;
        if (c < minC) minC = c;
        if (c > maxC) maxC = c;

        // (uSq, vSq) unit square in 45°-rotated coordinates where U = c + r, V = c - r
        final uBase = c + r;
        final vBase = c - r;
        final (uSq, vSq) = switch (dir) {
          0 => (uBase, vBase), // North
          1 => (uBase + 1, vBase), // East
          2 => (uBase + 1, vBase - 1), // South
          _ => (uBase, vBase - 1), // West
        };
        if (uSq < minU) minU = uSq;
        if (uSq > maxU) maxU = uSq;
        if (vSq < minV) minV = vSq;
        if (vSq > maxV) maxV = vSq;

        // 1. Internal diagonal edges within the same cell (N<->E, E<->S, S<->W, W<->N)
        final adjDir1 = (dir + 1) % 4;
        final adjDir2 = (dir + 3) % 4;
        final q1 = cellIdx * 4 + adjDir1;
        final q2 = cellIdx * 4 + adjDir2;
        if (isWhiteQ[q1] && !visitedQ[q1]) {
          visitedQ[q1] = true;
          q.add(q1);
        }
        if (isWhiteQ[q2] && !visitedQ[q2]) {
          visitedQ[q2] = true;
          q.add(q2);
        }

        // 2. Shared grid edge with orthogonally adjacent cell in direction `dir`
        final nr = r + orthoDr[dir], nc = c + orthoDc[dir];
        if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
          final oppDir = (dir + 2) % 4;
          final nbQ = (nr * size + nc) * 4 + oppDir;
          if (isWhiteQ[nbQ] && !visitedQ[nbQ]) {
            visitedQ[nbQ] = true;
            q.add(nbQ);
          }
        }
      }

      final expectedAxisQuarters = 4 * (maxR - minR + 1) * (maxC - minC + 1);
      final expectedTiltedQuarters = 2 * (maxU - minU + 1) * (maxV - minV + 1);
      final isAxisRect = comp.length == expectedAxisQuarters;
      final isTiltedRect = comp.length == expectedTiltedQuarters;

      if (isAxisRect) {
        validRectRegionCount++;
        axisRectCount++;
      } else if (isTiltedRect) {
        validRectRegionCount++;
        tiltedRectCount++;
      } else {
        nonRectCells.addAll(compCells);
      }
    }

    final conflictCells = <int>{
      ...violatedClueCells,
      ...nonRectCells,
    };

    return ShakashakaAnalysis(
      satisfiedClueCells: satisfiedClueCells,
      violatedClueCells: violatedClueCells,
      pendingClueCells: pendingClueCells,
      clueAdjacentTriangleCounts: clueAdjacentTriangleCounts,
      totalNumberedClues: totalNumberedClues,
      whiteRegionCount: whiteRegionCount,
      validRectRegionCount: validRectRegionCount,
      axisRectCount: axisRectCount,
      tiltedRectCount: tiltedRectCount,
      nonRectCells: nonRectCells,
      conflictCells: conflictCells,
      triangleCount: triangleCount,
    );
  }

  static bool isSolved(ShakashakaPuzzle puz, List<int> board) =>
      validateShakashaka(puz.size, board, puz.clues);

  static int _rotateVal90CW(int v) => switch (v) {
        1 => 2, // ◤ -> ◥
        2 => 4, // ◥ -> ◢
        4 => 3, // ◢ -> ◣
        3 => 1, // ◣ -> ◤
        _ => v,
      };

  static int _flipValH(int v) => switch (v) {
        1 => 2, // ◤ <-> ◥
        2 => 1,
        3 => 4, // ◣ <-> ◢
        4 => 3,
        _ => v,
      };

  static List<int> _transformGrid(
    int size,
    List<int> base, {
    required int rot,
    required bool flipH,
  }) {
    final out = List<int>.filled(size * size, 0);
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        var nr = r, nc = c;
        var v = base[r * size + c];
        for (var k = 0; k < (rot % 4); k++) {
          final tr = nc;
          final tc = size - 1 - nr;
          nr = tr;
          nc = tc;
          if (v >= 1 && v <= 4) v = _rotateVal90CW(v);
        }
        if (flipH) {
          nc = size - 1 - nc;
          if (v >= 1 && v <= 4) v = _flipValH(v);
        }
        out[nr * size + nc] = v;
      }
    }
    return out;
  }

  /// Generates a guaranteed-valid Shakashaka puzzle for [size] (`5` or `6`).
  static ShakashakaPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    final bank = size <= 5 ? _templates5x5 : _templates6x6;
    final tmpl = bank[rng.nextInt(bank.length)];
    final transformed = _transformGrid(
      size,
      tmpl.grid,
      rot: rng.nextInt(4),
      flipH: rng.nextBool(),
    );

    final clues = List<int>.filled(n, -2);
    final sol = List<int>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      if (transformed[i] == -1) {
        clues[i] = -1;
        sol[i] = 0;
      } else {
        clues[i] = -2;
        sol[i] = transformed[i];
      }
    }

    // Compute exact orthogonally adjacent triangle counts for each black cell
    final blackIndices = <int>[];
    for (var i = 0; i < n; i++) {
      if (clues[i] == -1) {
        blackIndices.add(i);
        final r = i ~/ size, c = i % size;
        var adjTri = 0;
        for (var d = 0; d < 4; d++) {
          final nr = r + orthoDr[d], nc = c + orthoDc[d];
          if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
          final nb = nr * size + nc;
          if (clues[nb] == -2 && sol[nb] >= 1 && sol[nb] <= 4) {
            adjTri++;
          }
        }
        clues[i] = adjTri;
      }
    }

    // Optionally make 1 black cell with 0 adjacent triangles an unnumbered black cell (-1)
    final zeroBlack = [for (final i in blackIndices) if (clues[i] == 0) i];
    if (zeroBlack.isNotEmpty && rng.nextBool()) {
      clues[zeroBlack[rng.nextInt(zeroBlack.length)]] = -1;
    }

    return ShakashakaPuzzle(
      size: size,
      clues: clues,
      solutionBoard: sol,
    );
  }
}

/// 数间直角三角竞速 (Shakashaka Race, 1-6 人).
class ShakashakaGame extends GameEngine {
  ShakashakaGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late ShakashakaPuzzle currentPuzzle;
  late List<ShakashakaPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<List<int>> get boards => [for (final p in ps) p.board];
  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a17Placings(ranking, players) : null;

  @override
  bool get canResign => !over;

  @override
  int get botDelayMs => switch (botLevel) { 0 => 760, 2 => 240, _ => 440 };

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
    final rawSize = setup.opt<int>('size', 5);
    size = rawSize == 6 ? 6 : 5;
    totalRounds = setup.opt<int>('rounds', 3) == 1 ? 1 : 3;

    currentPuzzle = ShakashakaSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) ShakashakaPlayer(size * size)];

    host.log('数间直角三角竞速开始（$size×$size 网格，共 $totalRounds 题）！放置直角三角形使所有白区成正交或 45° 旋转矩形，并匹配黑格线索！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = ShakashakaSolver.generatePuzzle(size, rng);
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
    return a17Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
  }

  (int, int) _resolveCell(Map<String, dynamic> a) {
    if (a.containsKey('r') && a.containsKey('c')) {
      final r = asInt(a['r']);
      final c = asInt(a['c']);
      if (r < 0 || r >= size || c < 0 || c >= size) {
        throw GameError('行列坐标超出棋盘范围');
      }
      return (r, c);
    }
    final idx = asInt(a['i']);
    if (idx < 0 || idx >= size * size) {
      throw GameError('格子索引超出棋盘范围');
    }
    return (idx ~/ size, idx % size);
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
      case 'cycle':
      case 'toggle':
        final (r, c) = _resolveCell(a);
        final idx = r * size + c;
        if (currentPuzzle.isBlackCell(idx)) {
          throw GameError('黑色线索格不可填入三角形');
        }
        if (type == 'set' || a.containsKey('val')) {
          final v = asInt(a['val'], -1);
          if (v < 0 || v > 4) {
            throw GameError('直角三角形状态必须在 0～4 之间');
          }
          p.board[idx] = v;
        } else {
          p.board[idx] = (p.board[idx] + 1) % 5;
        }
        moves++;
        if (ShakashakaSolver.isSolved(currentPuzzle, p.board)) {
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
    host.log('${name(seat)} 第 $roundSolvers 个解出数间直角三角谜题，+$pts 分！');
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
    ranking = a17Ranking(players, (a, b) {
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
    host.log('游戏结束（$why）！冠军：${a17Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || !_activeInRound(seat)) return null;
    final p = ps[seat];
    final puz = currentPuzzle;
    final sol = puz.solutionBoard;

    if (botLevel <= 0 && rng.nextInt(15) == 0) {
      return {'type': 'pass'};
    }

    final diff = <int>[
      for (var i = 0; i < sol.length; i++)
        if (!puz.isBlackCell(i) && p.board[i] != sol[i]) i,
    ];
    if (diff.isNotEmpty) {
      final pick = diff[rng.nextInt(diff.length)];
      return {
        'type': 'set',
        'r': pick ~/ size,
        'c': pick % size,
        'val': sol[pick],
      };
    }

    return {'type': 'pass'};
  }

  // ---------------------------------------------------------------- view

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players ? ps[seat] : (ps.isNotEmpty ? ps[0] : null);
    final puz = currentPuzzle;
    final myBoard = me?.board ?? puz.initialBoard;
    final an = ShakashakaSolver.analyze(puz, myBoard);

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'clues': puz.clues,
      'board': myBoard,
      'satisfiedClueCells': an.satisfiedClueCells.toList()..sort(),
      'violatedClueCells': an.violatedClueCells.toList()..sort(),
      'pendingClueCells': an.pendingClueCells.toList()..sort(),
      'satisfiedClueCount': an.satisfiedClueCells.length,
      'totalNumberedClues': an.totalNumberedClues,
      'whiteRegionCount': an.whiteRegionCount,
      'validRectRegionCount': an.validRectRegionCount,
      'axisRectCount': an.axisRectCount,
      'tiltedRectCount': an.tiltedRectCount,
      'nonRectCells': an.nonRectCells.toList()..sort(),
      'conflictCells': an.conflictCells.toList()..sort(),
      'triangleCount': an.triangleCount,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = ShakashakaSolver.analyze(puz, ps[s].board);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'satisfiedClueCount': pAn.satisfiedClueCells.length,
              'totalNumberedClues': pAn.totalNumberedClues,
              'validRectRegionCount': pAn.validRectRegionCount,
              'whiteRegionCount': pAn.whiteRegionCount,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class ShakashakaPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  ShakashakaPlayer(int cellCount) : board = List<int>.filled(cellCount, 0);

  void resetForRound(int cellCount) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.filled(cellCount, 0);
  }
}
