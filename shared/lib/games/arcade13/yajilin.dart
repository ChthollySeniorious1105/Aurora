import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';
import 'a13_util.dart';

class YajilinPuzzle {
  final int size;
  /// `size × size` grid of Arrow Clues: `null` if not a clue cell, or
  /// `{'dir': 0..3, 'count': k}` (`0: 上 ↑, 1: 右 →, 2: 下 ↓, 3: 左 ←`).
  final List<List<Map<String, int>?>> clues;
  /// Flat `size * size` cell states in the solution (`0` = non-Black, `1` = Black `■`).
  final List<int> solutionBoard;
  /// `size × (size - 1)` horizontal loop segments (`0` or `1`).
  final List<List<int>> solutionHSegs;
  /// `(size - 1) × size` vertical loop segments (`0` or `1`).
  final List<List<int>> solutionVSegs;

  const YajilinPuzzle({
    required this.size,
    required this.clues,
    required this.solutionBoard,
    required this.solutionHSegs,
    required this.solutionVSegs,
  });

  List<Map<String, int>?> get cluesFlat => [
        for (var r = 0; r < size; r++)
          for (var c = 0; c < size; c++) clues[r][c],
      ];

  List<int> get initialBoard => List<int>.filled(size * size, 0);

  List<List<int>> get initialHSegs => [
        for (var r = 0; r < size; r++) List<int>.filled(size - 1, 0),
      ];

  List<List<int>> get initialVSegs => [
        for (var r = 0; r < size - 1; r++) List<int>.filled(size, 0),
      ];
}

class YajilinAnalysis {
  final Set<int> satisfiedClues;
  final Set<int> violatedClues;
  final Set<int> adjacentBlackCells;
  final Set<int> badDegreeCells;
  final Set<int> unvisitedLoopCells;
  final List<int> rayBlackCounts;
  final int totalClues;
  final int blackCount;
  final int activeSegCount;
  final int componentCount;
  final bool isSingleLoop;

  const YajilinAnalysis({
    required this.satisfiedClues,
    required this.violatedClues,
    required this.adjacentBlackCells,
    required this.badDegreeCells,
    required this.unvisitedLoopCells,
    required this.rayBlackCounts,
    required this.totalClues,
    required this.blackCount,
    required this.activeSegCount,
    required this.componentCount,
    required this.isSingleLoop,
  });

  bool get isSolved =>
      totalClues > 0 &&
      satisfiedClues.length == totalClues &&
      violatedClues.isEmpty &&
      adjacentBlackCells.isEmpty &&
      badDegreeCells.isEmpty &&
      unvisitedLoopCells.isEmpty &&
      isSingleLoop;
}

class YajilinSolver {
  static const List<int> orthoDr = [-1, 0, 1, 0];
  static const List<int> orthoDc = [0, 1, 0, -1];

  static bool isBlack(List<int> board, int idx) =>
      idx >= 0 && idx < board.length && board[idx] == 1;

  /// Counts Black (`== 1`) cells strictly along the ray starting from `(r, c)`
  /// in direction `dir` (`0: 上, 1: 右, 2: 下, 3: 左`) to the edge of the grid.
  static int countBlackInRay(int size, List<int> board, int r, int c, int dir) {
    if (dir < 0 || dir > 3) return 0;
    var count = 0;
    var nr = r + orthoDr[dir];
    var nc = c + orthoDc[dir];
    while (nr >= 0 && nr < size && nc >= 0 && nc < size) {
      if (isBlack(board, nr * size + nc)) {
        count++;
      }
      nr += orthoDr[dir];
      nc += orthoDc[dir];
    }
    return count;
  }

  static YajilinAnalysis analyze(
    YajilinPuzzle puz,
    List<int> board,
    List<List<int>> hSegs,
    List<List<int>> vSegs,
  ) {
    final size = puz.size;
    final n = size * size;
    final satisfiedClues = <int>{};
    final violatedClues = <int>{};
    final adjacentBlackCells = <int>{};
    final badDegreeCells = <int>{};
    final unvisitedLoopCells = <int>{};
    final rayBlackCounts = List<int>.filled(n, 0);

    var totalClues = 0;
    var blackCount = 0;

    for (var i = 0; i < n; i++) {
      if (isBlack(board, i)) blackCount++;
    }

    // 1. Check orthogonal adjacency of Black cells
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final idx = r * size + c;
        if (!isBlack(board, idx)) continue;
        if (puz.clues[r][c] != null) {
          // Clue cells cannot be shaded Black
          adjacentBlackCells.add(idx);
        }
        for (var d = 0; d < 4; d++) {
          final nr = r + orthoDr[d], nc = c + orthoDc[d];
          if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
          final nIdx = nr * size + nc;
          if (isBlack(board, nIdx)) {
            adjacentBlackCells.add(idx);
            adjacentBlackCells.add(nIdx);
          }
        }
      }
    }

    // 2. Check Arrow Clues
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final clue = puz.clues[r][c];
        if (clue == null) continue;
        totalClues++;
        final idx = r * size + c;
        final dir = clue['dir'] ?? 0;
        final target = clue['count'] ?? 0;
        final seen = countBlackInRay(size, board, r, c, dir);
        rayBlackCounts[idx] = seen;
        if (!isBlack(board, idx) && seen == target) {
          satisfiedClues.add(idx);
        } else {
          violatedClues.add(idx);
        }
      }
    }

    // 3. Build loop adjacency and check degree + single closed loop on all non-clue, non-Black cells
    final neighbors = [for (var i = 0; i < n; i++) <int>[]];
    var activeSegCount = 0;

    for (var r = 0; r < size; r++) {
      final row = r < hSegs.length ? hSegs[r] : const <int>[];
      for (var c = 0; c < size - 1; c++) {
        if (c < row.length && row[c] == 1) {
          activeSegCount++;
          final a = r * size + c;
          final b = r * size + (c + 1);
          neighbors[a].add(b);
          neighbors[b].add(a);
        }
      }
    }

    for (var r = 0; r < size - 1; r++) {
      final row = r < vSegs.length ? vSegs[r] : const <int>[];
      for (var c = 0; c < size; c++) {
        if (c < row.length && row[c] == 1) {
          activeSegCount++;
          final a = r * size + c;
          final b = (r + 1) * size + c;
          neighbors[a].add(b);
          neighbors[b].add(a);
        }
      }
    }

    var requiredLoopCells = 0;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final idx = r * size + c;
        final deg = neighbors[idx].length;
        final isClueCell = puz.clues[r][c] != null;
        final isBlackCell = isBlack(board, idx);

        if (isClueCell || isBlackCell) {
          if (deg > 0) {
            badDegreeCells.add(idx);
          }
        } else {
          requiredLoopCells++;
          if (deg == 0) {
            unvisitedLoopCells.add(idx);
          } else if (deg != 2) {
            badDegreeCells.add(idx);
          }
        }
      }
    }

    final visited = List<bool>.filled(n, false);
    var componentCount = 0;
    for (var i = 0; i < n; i++) {
      if (neighbors[i].isEmpty || visited[i]) continue;
      componentCount++;
      final q = Queue<int>()..add(i);
      visited[i] = true;
      while (q.isNotEmpty) {
        final cur = q.removeFirst();
        for (final nxt in neighbors[cur]) {
          if (!visited[nxt]) {
            visited[nxt] = true;
            q.add(nxt);
          }
        }
      }
    }

    final isSingleLoop = requiredLoopCells > 0 &&
        activeSegCount > 0 &&
        badDegreeCells.isEmpty &&
        unvisitedLoopCells.isEmpty &&
        componentCount == 1;

    return YajilinAnalysis(
      satisfiedClues: satisfiedClues,
      violatedClues: violatedClues,
      adjacentBlackCells: adjacentBlackCells,
      badDegreeCells: badDegreeCells,
      unvisitedLoopCells: unvisitedLoopCells,
      rayBlackCounts: rayBlackCounts,
      totalClues: totalClues,
      blackCount: blackCount,
      activeSegCount: activeSegCount,
      componentCount: componentCount,
      isSingleLoop: isSingleLoop,
    );
  }

  static bool isSolved(
    YajilinPuzzle puz,
    List<int> board,
    List<List<int>> hSegs,
    List<List<int>> vSegs,
  ) =>
      analyze(puz, board, hSegs, vSegs).isSolved;

  static (List<List<int>>, List<List<int>>) _boundarySegmentsFromFaces(
    int size,
    List<List<bool>> faces,
  ) {
    final fSize = size - 1;
    final hSegs = [
      for (var r = 0; r < size; r++) List<int>.filled(size - 1, 0),
    ];
    final vSegs = [
      for (var r = 0; r < size - 1; r++) List<int>.filled(size, 0),
    ];

    bool faceAt(int fr, int fc) {
      if (fr < 0 || fr >= fSize || fc < 0 || fc >= fSize) return false;
      return faces[fr][fc];
    }

    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size - 1; c++) {
        if (faceAt(r - 1, c) != faceAt(r, c)) {
          hSegs[r][c] = 1;
        }
      }
    }

    for (var r = 0; r < size - 1; r++) {
      for (var c = 0; c < size; c++) {
        if (faceAt(r, c - 1) != faceAt(r, c)) {
          vSegs[r][c] = 1;
        }
      }
    }

    return (hSegs, vSegs);
  }

  /// Returns `(loopCells, nonLoopCells, isValidSingleLoop)`.
  static (List<int>, List<int>, bool) _classifyLoopCells(
    int size,
    List<List<int>> hSegs,
    List<List<int>> vSegs,
  ) {
    final n = size * size;
    final neighbors = [for (var i = 0; i < n; i++) <int>[]];
    var segCount = 0;

    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size - 1; c++) {
        if (hSegs[r][c] == 1) {
          segCount++;
          final a = r * size + c, b = r * size + (c + 1);
          neighbors[a].add(b);
          neighbors[b].add(a);
        }
      }
    }
    for (var r = 0; r < size - 1; r++) {
      for (var c = 0; c < size; c++) {
        if (vSegs[r][c] == 1) {
          segCount++;
          final a = r * size + c, b = (r + 1) * size + c;
          neighbors[a].add(b);
          neighbors[b].add(a);
        }
      }
    }

    if (segCount < 4) return (const [], const [], false);

    final loopCells = <int>[];
    final nonLoopCells = <int>[];
    for (var i = 0; i < n; i++) {
      final deg = neighbors[i].length;
      if (deg == 0) {
        nonLoopCells.add(i);
      } else if (deg == 2) {
        loopCells.add(i);
      } else {
        return (const [], const [], false);
      }
    }
    if (loopCells.isEmpty || nonLoopCells.isEmpty) {
      return (const [], const [], false);
    }

    final vis = List<bool>.filled(n, false);
    final q = Queue<int>()..add(loopCells.first);
    vis[loopCells.first] = true;
    var visitedCount = 0;
    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      visitedCount++;
      for (final nxt in neighbors[cur]) {
        if (!vis[nxt]) {
          vis[nxt] = true;
          q.add(nxt);
        }
      }
    }
    if (visitedCount != loopCells.length) {
      return (const [], const [], false);
    }

    return (loopCells, nonLoopCells, true);
  }

  /// Generates a guaranteed-valid Yajilin puzzle for [size] (`5` or `6`).
  static YajilinPuzzle generatePuzzle(int size, Random rng) {
    final fSize = size - 1;
    final faces = [
      for (var r = 0; r < fSize; r++) List<bool>.filled(fSize, true),
    ];

    // Carve boundary dual faces to create interesting outside cells and turns
    final minNonLoop = size <= 5 ? 4 : 5;
    final maxNonLoop = size <= 5 ? 8 : 11;
    final targetCarves = size <= 5 ? (2 + rng.nextInt(3)) : (3 + rng.nextInt(4));
    var carved = 0;

    for (var step = 0; step < 14 && carved < targetCarves; step++) {
      final candidates = <(int, int)>[];
      for (var r = 0; r < fSize; r++) {
        for (var c = 0; c < fSize; c++) {
          if (!faces[r][c]) continue;
          final onBoundary = r == 0 ||
              r == fSize - 1 ||
              c == 0 ||
              c == fSize - 1 ||
              !faces[r - 1][c] ||
              !faces[r + 1][c] ||
              !faces[r][c - 1] ||
              !faces[r][c + 1];
          if (onBoundary) candidates.add((r, c));
        }
      }
      if (candidates.length <= 3) break;
      candidates.shuffle(rng);

      for (final (fr, fc) in candidates) {
        faces[fr][fc] = false;
        final (candH, candV) = _boundarySegmentsFromFaces(size, faces);
        final (loopCells, nonLoopCells, validLoop) =
            _classifyLoopCells(size, candH, candV);
        if (validLoop &&
            loopCells.length >= size * 2 &&
            nonLoopCells.length >= minNonLoop &&
            nonLoopCells.length <= maxNonLoop) {
          carved++;
          break;
        } else {
          faces[fr][fc] = true;
        }
      }
    }

    final (solH, solV) = _boundarySegmentsFromFaces(size, faces);
    final (_, rawNonLoop, _) = _classifyLoopCells(size, solH, solV);
    final nonLoopOrder = List<int>.of(rawNonLoop)..shuffle(rng);

    final n = size * size;
    final solBoard = List<int>.filled(n, 0);
    final clues = [
      for (var r = 0; r < size; r++) List<Map<String, int>?>.filled(size, null),
    ];

    // Reserve at least 2 cells in nonLoopOrder as Arrow Clue cells, and greedily
    // shade a non-adjacent subset of the remaining non-loop cells Black (1).
    final reserveClues = (nonLoopOrder.length ~/ 2).clamp(2, 4);
    final targetBlacks = size <= 5 ? 4 : 5;
    final clueIndices = <int>[];
    var placedBlacks = 0;

    for (var i = 0; i < nonLoopOrder.length; i++) {
      final idx = nonLoopOrder[i];
      if (i < reserveClues || placedBlacks >= targetBlacks) {
        clueIndices.add(idx);
        continue;
      }
      final r = idx ~/ size, c = idx % size;
      var adjBlack = false;
      for (var d = 0; d < 4; d++) {
        final nr = r + orthoDr[d], nc = c + orthoDc[d];
        if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
          if (solBoard[nr * size + nc] == 1) {
            adjBlack = true;
            break;
          }
        }
      }
      if (!adjBlack) {
        solBoard[idx] = 1;
        placedBlacks++;
      } else {
        clueIndices.add(idx);
      }
    }

    // Ensure at least 1 Black cell and 1 Clue cell exist
    if (placedBlacks == 0 && clueIndices.length >= 2) {
      final promote = clueIndices.removeLast();
      solBoard[promote] = 1;
    }

    // Assign a direction (0..3) and exact Black cell count to each Clue cell
    for (final idx in clueIndices) {
      final r = idx ~/ size, c = idx % size;
      final inBoundsDirs = <int>[
        for (var d = 0; d < 4; d++)
          if (r + orthoDr[d] >= 0 &&
              r + orthoDr[d] < size &&
              c + orthoDc[d] >= 0 &&
              c + orthoDc[d] < size)
            d,
      ]..shuffle(rng);

      var chosenDir = inBoundsDirs.isNotEmpty ? inBoundsDirs.first : 0;
      for (final d in inBoundsDirs) {
        if (countBlackInRay(size, solBoard, r, c, d) > 0) {
          chosenDir = d;
          break;
        }
      }
      final cnt = countBlackInRay(size, solBoard, r, c, chosenDir);
      clues[r][c] = {'dir': chosenDir, 'count': cnt};
    }

    return YajilinPuzzle(
      size: size,
      clues: clues,
      solutionBoard: solBoard,
      solutionHSegs: solH,
      solutionVSegs: solV,
    );
  }
}

/// 箭头回路竞速 (Yajilin Race, 1-6 人).
class YajilinGame extends GameEngine {
  YajilinGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late YajilinPuzzle currentPuzzle;
  late List<YajilinPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<List<int>> get boards => [for (final p in ps) p.board];
  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a13Placings(ranking, players) : null;

  @override
  bool get canResign => !over;

  @override
  int get botDelayMs => switch (botLevel) { 0 => 760, 2 => 220, _ => 420 };

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

    currentPuzzle = YajilinSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) YajilinPlayer(size)];

    host.log('箭头回路竞速开始（$size×$size 网格，共 $totalRounds 题）！按箭头计数涂黑方格并连接全白格单一闭环！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = YajilinSolver.generatePuzzle(size, rng);
    }
    for (var s = 0; s < players; s++) {
      ps[s].resetForRound(size);
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
    return a13Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
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
      case 'edge':
      case 'seg':
        if (a.containsKey('r1') && a.containsKey('c1') && a.containsKey('r2') && a.containsKey('c2')) {
          final r1 = asInt(a['r1']), c1 = asInt(a['c1']);
          final r2 = asInt(a['r2']), c2 = asInt(a['c2']);
          if (r1 < 0 || r1 >= size || c1 < 0 || c1 >= size || r2 < 0 || r2 >= size || c2 < 0 || c2 >= size) {
            throw GameError('线段端点超出棋盘范围');
          }
          if ((r1 - r2).abs() + (c1 - c2).abs() != 1) {
            throw GameError('只能在正交相邻的两个方格之间连线');
          }
          if (currentPuzzle.clues[r1][c1] != null || currentPuzzle.clues[r2][c2] != null) {
            throw GameError('箭头线索格不能连接回路线段');
          }
          if (r1 == r2) {
            final mc = min(c1, c2);
            if (a.containsKey('val')) {
              p.hSegs[r1][mc] = asInt(a['val']) != 0 ? 1 : 0;
            } else {
              p.hSegs[r1][mc] = p.hSegs[r1][mc] == 1 ? 0 : 1;
            }
          } else {
            final mr = min(r1, r2);
            if (a.containsKey('val')) {
              p.vSegs[mr][c1] = asInt(a['val']) != 0 ? 1 : 0;
            } else {
              p.vSegs[mr][c1] = p.vSegs[mr][c1] == 1 ? 0 : 1;
            }
          }
        } else {
          final dir = asStr(a['dir'], 'h');
          final r = asInt(a['r']);
          final c = asInt(a['c']);
          if (dir == 'h') {
            if (r < 0 || r >= size || c < 0 || c >= size - 1) {
              throw GameError('水平线段坐标超出棋盘范围');
            }
            if (currentPuzzle.clues[r][c] != null || currentPuzzle.clues[r][c + 1] != null) {
              throw GameError('箭头线索格不能连接回路线段');
            }
            if (a.containsKey('val')) {
              p.hSegs[r][c] = asInt(a['val']) != 0 ? 1 : 0;
            } else {
              p.hSegs[r][c] = p.hSegs[r][c] == 1 ? 0 : 1;
            }
          } else if (dir == 'v') {
            if (r < 0 || r >= size - 1 || c < 0 || c >= size) {
              throw GameError('垂直线段坐标超出棋盘范围');
            }
            if (currentPuzzle.clues[r][c] != null || currentPuzzle.clues[r + 1][c] != null) {
              throw GameError('箭头线索格不能连接回路线段');
            }
            if (a.containsKey('val')) {
              p.vSegs[r][c] = asInt(a['val']) != 0 ? 1 : 0;
            } else {
              p.vSegs[r][c] = p.vSegs[r][c] == 1 ? 0 : 1;
            }
          } else {
            throw GameError('线段方向必须为 h 或 v');
          }
        }
        moves++;
        if (YajilinSolver.isSolved(currentPuzzle, p.board, p.hSegs, p.vSegs)) {
          _markSolved(seat);
        }

      case 'shade':
      case 'toggle':
      case 'set':
        final (r, c) = _resolveCell(a);
        if (currentPuzzle.clues[r][c] != null) {
          throw GameError('箭头线索格不可涂黑或修改');
        }
        final idx = r * size + c;
        if (a.containsKey('val')) {
          final v = asInt(a['val'], -1);
          if (v < 0 || v > 2) {
            throw GameError('格子状态必须在 0～2 之间');
          }
          p.board[idx] = v;
        } else {
          p.board[idx] = p.board[idx] == 1 ? 0 : 1;
        }
        // If shaded Black (1), clear any incident loop segments on (r, c)
        if (p.board[idx] == 1) {
          if (c > 0) p.hSegs[r][c - 1] = 0;
          if (c < size - 1) p.hSegs[r][c] = 0;
          if (r > 0) p.vSegs[r - 1][c] = 0;
          if (r < size - 1) p.vSegs[r][c] = 0;
        }
        moves++;
        if (YajilinSolver.isSolved(currentPuzzle, p.board, p.hSegs, p.vSegs)) {
          _markSolved(seat);
        }

      case 'clear':
      case 'reset':
        p.clearAll();
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
    host.log('${name(seat)} 第 $roundSolvers 个解出箭头回路谜题，+$pts 分！');
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
    ranking = a13Ranking(players, (a, b) {
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
    host.log('游戏结束（$why）！冠军：${a13Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || !_activeInRound(seat)) return null;
    final p = ps[seat];
    final solBoard = currentPuzzle.solutionBoard;
    final solH = currentPuzzle.solutionHSegs;
    final solV = currentPuzzle.solutionVSegs;

    if (botLevel <= 0 && rng.nextInt(18) == 0) {
      return {'type': 'pass'};
    }

    // 1. Fix any cell shading mismatch first
    final cellDiffs = <int>[
      for (var i = 0; i < solBoard.length; i++)
        if (currentPuzzle.clues[i ~/ size][i % size] == null &&
            (p.board[i] == 1) != (solBoard[i] == 1))
          i,
    ];
    if (cellDiffs.isNotEmpty) {
      final pick = cellDiffs[rng.nextInt(cellDiffs.length)];
      return {
        'type': 'shade',
        'r': pick ~/ size,
        'c': pick % size,
      };
    }

    // 2. Fix any loop segment mismatch
    final segDiffs = <(int, int, int, int)>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size - 1; c++) {
        if (p.hSegs[r][c] != solH[r][c]) {
          segDiffs.add((r, c, r, c + 1));
        }
      }
    }
    for (var r = 0; r < size - 1; r++) {
      for (var c = 0; c < size; c++) {
        if (p.vSegs[r][c] != solV[r][c]) {
          segDiffs.add((r, c, r + 1, c));
        }
      }
    }

    if (segDiffs.isNotEmpty) {
      final (r1, c1, r2, c2) = segDiffs[rng.nextInt(segDiffs.length)];
      return {
        'type': 'edge',
        'r1': r1,
        'c1': c1,
        'r2': r2,
        'c2': c2,
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
    final myH = me?.hSegs ?? puz.initialHSegs;
    final myV = me?.vSegs ?? puz.initialVSegs;
    final an = YajilinSolver.analyze(puz, myBoard, myH, myV);

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'clues': puz.clues,
      'cluesFlat': puz.cluesFlat,
      'board': myBoard,
      'hSegs': myH,
      'vSegs': myV,
      'rayBlackCounts': an.rayBlackCounts,
      'satisfiedClues': an.satisfiedClues.toList()..sort(),
      'violatedClues': an.violatedClues.toList()..sort(),
      'adjacentBlacks': an.adjacentBlackCells.toList()..sort(),
      'badDegreeCells': an.badDegreeCells.toList()..sort(),
      'unvisitedLoopCells': an.unvisitedLoopCells.toList()..sort(),
      'satisfiedClueCount': an.satisfiedClues.length,
      'totalClues': an.totalClues,
      'blackCount': an.blackCount,
      'activeSegCount': an.activeSegCount,
      'isSingleLoop': an.isSingleLoop,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = YajilinSolver.analyze(puz, ps[s].board, ps[s].hSegs, ps[s].vSegs);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'satisfiedClues': pAn.satisfiedClues.length,
              'totalClues': pAn.totalClues,
              'isSingleLoop': pAn.isSingleLoop,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class YajilinPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  late List<int> board;
  late List<List<int>> hSegs;
  late List<List<int>> vSegs;

  YajilinPlayer(int size) {
    resetForRound(size);
  }

  void clearAll() {
    board.fillRange(0, board.length, 0);
    for (final row in hSegs) {
      row.fillRange(0, row.length, 0);
    }
    for (final row in vSegs) {
      row.fillRange(0, row.length, 0);
    }
  }

  void resetForRound(int size) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.filled(size * size, 0);
    hSegs = [for (var r = 0; r < size; r++) List<int>.filled(size - 1, 0)];
    vSegs = [for (var r = 0; r < size - 1; r++) List<int>.filled(size, 0)];
  }
}
