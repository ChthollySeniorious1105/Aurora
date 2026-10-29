import 'dart:math';

import '../../src/engine.dart';
import 'a15_util.dart';

class StitchesPuzzle {
  final int size;
  final int regionCount;
  /// `size × size` grid of polyomino Region IDs `0..regionCount-1`.
  final List<List<int>> regions;
  /// All unordered pairs `[a, b]` (`0 <= a < b < regionCount`) of orthogonally
  /// adjacent Regions.
  final List<List<int>> adjacentPairs;
  /// Exact number of stitch endpoints (holes) in each row `0..size-1`.
  final List<int> rowClues;
  /// Exact number of stitch endpoints (holes) in each column `0..size-1`.
  final List<int> colClues;
  /// `size × (size - 1)` horizontal stitch solution (`1` = stitched between `(r,c)` and `(r,c+1)`).
  final List<List<int>> solutionHStitches;
  /// `(size - 1) × size` vertical stitch solution (`1` = stitched between `(r,c)` and `(r+1,c)`).
  final List<List<int>> solutionVStitches;

  const StitchesPuzzle({
    required this.size,
    required this.regionCount,
    required this.regions,
    required this.adjacentPairs,
    required this.rowClues,
    required this.colClues,
    required this.solutionHStitches,
    required this.solutionVStitches,
  });

  int get totalPairs => adjacentPairs.length;

  List<int> get regionMap => [
        for (var r = 0; r < size; r++)
          for (var c = 0; c < size; c++) regions[r][c],
      ];

  List<List<int>> get initialHStitches => [
        for (var r = 0; r < size; r++) List<int>.filled(size - 1, 0),
      ];

  List<List<int>> get initialVStitches => [
        for (var r = 0; r < size - 1; r++) List<int>.filled(size, 0),
      ];
}

class StitchesAnalysis {
  final Set<int> satisfiedPairs;
  final Set<int> violatedPairs;
  final Set<int> missingPairs;
  final List<int> pairStitchCounts;
  final List<int> cellHoleCounts;
  final Set<int> overloadedCells;
  final List<int> rowCounts;
  final List<int> colCounts;
  final Set<int> satisfiedRows;
  final Set<int> violatedRows;
  final Set<int> satisfiedCols;
  final Set<int> violatedCols;
  final int activeStitchCount;
  final int totalPairs;
  final int size;
  final bool hasSameRegionStitch;

  const StitchesAnalysis({
    required this.satisfiedPairs,
    required this.violatedPairs,
    required this.missingPairs,
    required this.pairStitchCounts,
    required this.cellHoleCounts,
    required this.overloadedCells,
    required this.rowCounts,
    required this.colCounts,
    required this.satisfiedRows,
    required this.violatedRows,
    required this.satisfiedCols,
    required this.violatedCols,
    required this.activeStitchCount,
    required this.totalPairs,
    required this.size,
    required this.hasSameRegionStitch,
  });

  bool get isSolved =>
      totalPairs > 0 &&
      !hasSameRegionStitch &&
      satisfiedPairs.length == totalPairs &&
      violatedPairs.isEmpty &&
      missingPairs.isEmpty &&
      overloadedCells.isEmpty &&
      satisfiedRows.length == size &&
      satisfiedCols.length == size &&
      violatedRows.isEmpty &&
      violatedCols.isEmpty;
}

class StitchesSolver {
  static const List<int> orthoDr = [-1, 0, 1, 0];
  static const List<int> orthoDc = [0, 1, 0, -1];

  static String _pairKey(int a, int b) => a < b ? '$a:$b' : '$b:$a';

  static List<List<int>> computeAdjacentPairs(int size, List<List<int>> regions) {
    final seen = <String>{};
    final out = <List<int>>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final regA = regions[r][c];
        if (c + 1 < size) {
          final regB = regions[r][c + 1];
          if (regA != regB) {
            final lo = min(regA, regB), hi = max(regA, regB);
            if (seen.add('$lo:$hi')) out.add([lo, hi]);
          }
        }
        if (r + 1 < size) {
          final regB = regions[r + 1][c];
          if (regA != regB) {
            final lo = min(regA, regB), hi = max(regA, regB);
            if (seen.add('$lo:$hi')) out.add([lo, hi]);
          }
        }
      }
    }
    out.sort((x, y) => x[0] != y[0] ? x[0] - y[0] : x[1] - y[1]);
    return out;
  }

  static StitchesAnalysis analyze(
    StitchesPuzzle puz,
    List<List<int>> hStitches,
    List<List<int>> vStitches,
  ) {
    final size = puz.size;
    final n = size * size;
    final totalPairs = puz.totalPairs;

    final pairIndexByKey = <String, int>{
      for (var i = 0; i < totalPairs; i++)
        _pairKey(puz.adjacentPairs[i][0], puz.adjacentPairs[i][1]): i,
    };

    final pairStitchCounts = List<int>.filled(totalPairs, 0);
    final cellHoleCounts = List<int>.filled(n, 0);
    final rowCounts = List<int>.filled(size, 0);
    final colCounts = List<int>.filled(size, 0);

    var activeStitchCount = 0;
    var hasSameRegionStitch = false;

    // 1. Scan horizontal stitches
    for (var r = 0; r < size; r++) {
      final row = r < hStitches.length ? hStitches[r] : const <int>[];
      for (var c = 0; c < size - 1; c++) {
        if (c < row.length && row[c] == 1) {
          activeStitchCount++;
          final idx1 = r * size + c;
          final idx2 = r * size + (c + 1);
          cellHoleCounts[idx1]++;
          cellHoleCounts[idx2]++;
          rowCounts[r] += 2;
          colCounts[c]++;
          colCounts[c + 1]++;

          final reg1 = puz.regions[r][c];
          final reg2 = puz.regions[r][c + 1];
          if (reg1 == reg2) {
            hasSameRegionStitch = true;
          } else {
            final pIdx = pairIndexByKey[_pairKey(reg1, reg2)];
            if (pIdx != null) pairStitchCounts[pIdx]++;
          }
        }
      }
    }

    // 2. Scan vertical stitches
    for (var r = 0; r < size - 1; r++) {
      final row = r < vStitches.length ? vStitches[r] : const <int>[];
      for (var c = 0; c < size; c++) {
        if (c < row.length && row[c] == 1) {
          activeStitchCount++;
          final idx1 = r * size + c;
          final idx2 = (r + 1) * size + c;
          cellHoleCounts[idx1]++;
          cellHoleCounts[idx2]++;
          rowCounts[r]++;
          rowCounts[r + 1]++;
          colCounts[c] += 2;

          final reg1 = puz.regions[r][c];
          final reg2 = puz.regions[r + 1][c];
          if (reg1 == reg2) {
            hasSameRegionStitch = true;
          } else {
            final pIdx = pairIndexByKey[_pairKey(reg1, reg2)];
            if (pIdx != null) pairStitchCounts[pIdx]++;
          }
        }
      }
    }

    final satisfiedPairs = <int>{};
    final violatedPairs = <int>{};
    final missingPairs = <int>{};
    for (var i = 0; i < totalPairs; i++) {
      final cnt = pairStitchCounts[i];
      if (cnt == 1) {
        satisfiedPairs.add(i);
      } else if (cnt > 1) {
        violatedPairs.add(i);
      } else {
        missingPairs.add(i);
      }
    }

    final overloadedCells = <int>{
      for (var i = 0; i < n; i++)
        if (cellHoleCounts[i] > 1) i,
    };

    final satisfiedRows = <int>{};
    final violatedRows = <int>{};
    for (var r = 0; r < size; r++) {
      if (rowCounts[r] == puz.rowClues[r]) {
        satisfiedRows.add(r);
      } else if (rowCounts[r] > puz.rowClues[r]) {
        violatedRows.add(r);
      }
    }

    final satisfiedCols = <int>{};
    final violatedCols = <int>{};
    for (var c = 0; c < size; c++) {
      if (colCounts[c] == puz.colClues[c]) {
        satisfiedCols.add(c);
      } else if (colCounts[c] > puz.colClues[c]) {
        violatedCols.add(c);
      }
    }

    return StitchesAnalysis(
      satisfiedPairs: satisfiedPairs,
      violatedPairs: violatedPairs,
      missingPairs: missingPairs,
      pairStitchCounts: pairStitchCounts,
      cellHoleCounts: cellHoleCounts,
      overloadedCells: overloadedCells,
      rowCounts: rowCounts,
      colCounts: colCounts,
      satisfiedRows: satisfiedRows,
      violatedRows: violatedRows,
      satisfiedCols: satisfiedCols,
      violatedCols: violatedCols,
      activeStitchCount: activeStitchCount,
      totalPairs: totalPairs,
      size: size,
      hasSameRegionStitch: hasSameRegionStitch,
    );
  }

  static bool isSolved(
    StitchesPuzzle puz,
    List<List<int>> hStitches,
    List<List<int>> vStitches,
  ) {
    if (hStitches.length != puz.size || vStitches.length != puz.size - 1) return false;
    return analyze(puz, hStitches, vStitches).isSolved;
  }

  /// Generates a guaranteed-valid Stitches puzzle for [size] (`5` or `6`).
  static StitchesPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    final targetRegions = size <= 5 ? (5 + rng.nextInt(2)) : (6 + rng.nextInt(2));

    for (var attempt = 0; attempt < 60; attempt++) {
      // Grow connected polyomino regions from random seeds
      final regFlat = List<int>.filled(n, -1);
      final seeds = ([for (var i = 0; i < n; i++) i]..shuffle(rng)).take(targetRegions).toList();
      final sizes = List<int>.filled(targetRegions, 0);
      for (var k = 0; k < targetRegions; k++) {
        regFlat[seeds[k]] = k;
        sizes[k] = 1;
      }

      var unassigned = n - targetRegions;
      var guard = 0;
      while (unassigned > 0 && guard++ < 400) {
        final candidates = <(int, int)>[];
        for (var i = 0; i < n; i++) {
          if (regFlat[i] != -1) continue;
          final r = i ~/ size, c = i % size;
          for (var d = 0; d < 4; d++) {
            final nr = r + orthoDr[d], nc = c + orthoDc[d];
            if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
              final nReg = regFlat[nr * size + nc];
              if (nReg != -1) {
                candidates.add((i, nReg));
              }
            }
          }
        }
        if (candidates.isEmpty) break;
        // Prefer growing smaller regions so every region has >= 3 cells
        candidates.sort((a, b) => sizes[a.$2].compareTo(sizes[b.$2]));
        final topCount = min(candidates.length, 4);
        final (cellIdx, chosenReg) = candidates[rng.nextInt(topCount)];
        if (regFlat[cellIdx] == -1) {
          regFlat[cellIdx] = chosenReg;
          sizes[chosenReg]++;
          unassigned--;
        }
      }
      if (unassigned > 0) continue;
      if (sizes.any((s) => s < 3)) continue;

      final regions = [
        for (var r = 0; r < size; r++)
          [for (var c = 0; c < size; c++) regFlat[r * size + c]],
      ];

      final adjPairs = computeAdjacentPairs(size, regions);
      if (adjPairs.length < 5) continue;

      // Collect candidate cross-border edges (idx1, idx2, isHoriz, er, ec) for each adjacent region pair
      final pairEdges = List<List<(int, int, bool, int, int)>>.generate(
        adjPairs.length,
        (_) => <(int, int, bool, int, int)>[],
      );
      final pairIdxByKey = <String, int>{
        for (var i = 0; i < adjPairs.length; i++)
          _pairKey(adjPairs[i][0], adjPairs[i][1]): i,
      };

      for (var r = 0; r < size; r++) {
        for (var c = 0; c < size; c++) {
          final regA = regions[r][c];
          if (c + 1 < size) {
            final regB = regions[r][c + 1];
            if (regA != regB) {
              final pIdx = pairIdxByKey[_pairKey(regA, regB)]!;
              pairEdges[pIdx].add((r * size + c, r * size + c + 1, true, r, c));
            }
          }
          if (r + 1 < size) {
            final regB = regions[r + 1][c];
            if (regA != regB) {
              final pIdx = pairIdxByKey[_pairKey(regA, regB)]!;
              pairEdges[pIdx].add((r * size + c, (r + 1) * size + c, false, r, c));
            }
          }
        }
      }

      for (final list in pairEdges) {
        list.shuffle(rng);
      }

      // Order region pairs by fewest available border edges first
      final pairOrder = [for (var i = 0; i < adjPairs.length; i++) i]
        ..sort((a, b) => pairEdges[a].length.compareTo(pairEdges[b].length));

      final usedCell = List<bool>.filled(n, false);
      final chosenEdge = List<(int, int, bool, int, int)?>.filled(adjPairs.length, null);
      var searchSteps = 0;

      bool matchPairs(int ordIdx) {
        if (++searchSteps > 2000) return false;
        if (ordIdx == pairOrder.length) return true;
        final pIdx = pairOrder[ordIdx];
        for (final edge in pairEdges[pIdx]) {
          final u = edge.$1, v = edge.$2;
          if (usedCell[u] || usedCell[v]) continue;
          usedCell[u] = true;
          usedCell[v] = true;
          chosenEdge[pIdx] = edge;
          if (matchPairs(ordIdx + 1)) return true;
          chosenEdge[pIdx] = null;
          usedCell[u] = false;
          usedCell[v] = false;
        }
        return false;
      }

      if (!matchPairs(0)) continue;

      final solH = [
        for (var r = 0; r < size; r++) List<int>.filled(size - 1, 0),
      ];
      final solV = [
        for (var r = 0; r < size - 1; r++) List<int>.filled(size, 0),
      ];
      final rowClues = List<int>.filled(size, 0);
      final colClues = List<int>.filled(size, 0);

      for (final edge in chosenEdge) {
        final (u, v, isHoriz, er, ec) = edge!;
        if (isHoriz) {
          solH[er][ec] = 1;
        } else {
          solV[er][ec] = 1;
        }
        rowClues[u ~/ size]++;
        colClues[u % size]++;
        rowClues[v ~/ size]++;
        colClues[v % size]++;
      }

      final puz = StitchesPuzzle(
        size: size,
        regionCount: targetRegions,
        regions: regions,
        adjacentPairs: adjPairs,
        rowClues: rowClues,
        colClues: colClues,
        solutionHStitches: solH,
        solutionVStitches: solV,
      );
      if (isSolved(puz, solH, solV)) {
        return puz;
      }
    }

    // Deterministic 5-region fallback guaranteed to have disjoint stitch endpoints
    final regions = [
      for (var r = 0; r < size; r++)
        [
          for (var c = 0; c < size; c++)
            r < 2 ? (c < 3 ? 0 : 1) : (r < 4 ? (c < 3 ? 2 : 3) : 4),
        ],
    ];
    final adjPairs = computeAdjacentPairs(size, regions);
    final solH = [
      for (var r = 0; r < size; r++) List<int>.filled(size - 1, 0),
    ];
    final solV = [
      for (var r = 0; r < size - 1; r++) List<int>.filled(size, 0),
    ];
    // (0,1): (0,2)-(0,3); (0,2): (1,0)-(2,0); (1,3): (1,3)-(2,3);
    // (2,3): (3,2)-(3,3); (2,4): (3,1)-(4,1); (3,4): (3,4)-(4,4)
    solH[0][2] = 1;
    solV[1][0] = 1;
    solV[1][3] = 1;
    solH[3][2] = 1;
    solV[3][1] = 1;
    solV[3][4] = 1;

    final rowClues = List<int>.filled(size, 0);
    final colClues = List<int>.filled(size, 0);
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size - 1; c++) {
        if (solH[r][c] == 1) {
          rowClues[r] += 2;
          colClues[c]++;
          colClues[c + 1]++;
        }
      }
    }
    for (var r = 0; r < size - 1; r++) {
      for (var c = 0; c < size; c++) {
        if (solV[r][c] == 1) {
          rowClues[r]++;
          rowClues[r + 1]++;
          colClues[c] += 2;
        }
      }
    }

    return StitchesPuzzle(
      size: size,
      regionCount: 5,
      regions: regions,
      adjacentPairs: adjPairs,
      rowClues: rowClues,
      colClues: colClues,
      solutionHStitches: solH,
      solutionVStitches: solV,
    );
  }
}

/// 跨宫缝线竞速 (Stitches Race, 1-6 人).
class StitchesGame extends GameEngine {
  StitchesGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late StitchesPuzzle currentPuzzle;
  late List<StitchesPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a15Placings(ranking, players) : null;

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

    currentPuzzle = StitchesSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) StitchesPlayer(size)];

    host.log('跨宫缝线竞速开始（$size×$size 网格，共 $totalRounds 题）！每对相邻区域缝 1 针，单格最多 1 孔并匹配行列计数！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = StitchesSolver.generatePuzzle(size, rng);
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
    return a15Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
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
      case 'stitch':
      case 'edge':
      case 'toggle':
        final r1 = asInt(a['r1']);
        final c1 = asInt(a['c1']);
        final r2 = asInt(a['r2']);
        final c2 = asInt(a['c2']);
        if (r1 < 0 || r1 >= size || c1 < 0 || c1 >= size || r2 < 0 || r2 >= size || c2 < 0 || c2 >= size) {
          throw GameError('格子坐标超出棋盘范围');
        }
        final dr = (r1 - r2).abs();
        final dc = (c1 - c2).abs();
        if (dr + dc != 1) {
          throw GameError('只能在正交相邻的两个方格之间缝合');
        }
        if (currentPuzzle.regions[r1][c1] == currentPuzzle.regions[r2][c2]) {
          throw GameError('只能在相邻的不同区域边界之间缝合');
        }
        if (dr == 0) {
          final c = min(c1, c2);
          final cur = p.hStitches[r1][c];
          p.hStitches[r1][c] = a.containsKey('val') ? (asInt(a['val']) == 1 ? 1 : 0) : (1 - cur);
        } else {
          final r = min(r1, r2);
          final cur = p.vStitches[r][c1];
          p.vStitches[r][c1] = a.containsKey('val') ? (asInt(a['val']) == 1 ? 1 : 0) : (1 - cur);
        }
        moves++;
        if (StitchesSolver.isSolved(currentPuzzle, p.hStitches, p.vStitches)) {
          _markSolved(seat);
        }

      case 'clear':
      case 'reset':
        p.clearStitches(size);
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
    host.log('${name(seat)} 第 $roundSolvers 个解出跨宫缝线谜题，+$pts 分！');
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
    ranking = a15Ranking(players, (a, b) {
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
    host.log('游戏结束（$why）！冠军：${a15Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || !_activeInRound(seat)) return null;
    final p = ps[seat];
    final puz = currentPuzzle;

    if (botLevel <= 0 && rng.nextInt(15) == 0) {
      return {'type': 'pass'};
    }

    final diffs = <Map<String, dynamic>>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size - 1; c++) {
        if (p.hStitches[r][c] != puz.solutionHStitches[r][c]) {
          diffs.add({'type': 'stitch', 'r1': r, 'c1': c, 'r2': r, 'c2': c + 1});
        }
      }
    }
    for (var r = 0; r < size - 1; r++) {
      for (var c = 0; c < size; c++) {
        if (p.vStitches[r][c] != puz.solutionVStitches[r][c]) {
          diffs.add({'type': 'stitch', 'r1': r, 'c1': c, 'r2': r + 1, 'c2': c});
        }
      }
    }

    if (diffs.isNotEmpty) {
      return diffs[rng.nextInt(diffs.length)];
    }

    return {'type': 'pass'};
  }

  // ---------------------------------------------------------------- view

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players ? ps[seat] : (ps.isNotEmpty ? ps[0] : null);
    final puz = currentPuzzle;
    final myH = me?.hStitches ?? puz.initialHStitches;
    final myV = me?.vStitches ?? puz.initialVStitches;
    final an = StitchesSolver.analyze(puz, myH, myV);

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'regionCount': puz.regionCount,
      'regions': puz.regions,
      'regionMap': puz.regionMap,
      'adjacentPairs': puz.adjacentPairs,
      'totalPairs': puz.totalPairs,
      'rowClues': puz.rowClues,
      'colClues': puz.colClues,
      'hStitches': myH,
      'vStitches': myV,
      'pairStitchCounts': an.pairStitchCounts,
      'satisfiedPairs': an.satisfiedPairs.toList()..sort(),
      'violatedPairs': an.violatedPairs.toList()..sort(),
      'missingPairs': an.missingPairs.toList()..sort(),
      'cellHoleCounts': an.cellHoleCounts,
      'overloadedCells': an.overloadedCells.toList()..sort(),
      'rowCounts': an.rowCounts,
      'colCounts': an.colCounts,
      'satisfiedRows': an.satisfiedRows.toList()..sort(),
      'violatedRows': an.violatedRows.toList()..sort(),
      'satisfiedCols': an.satisfiedCols.toList()..sort(),
      'violatedCols': an.violatedCols.toList()..sort(),
      'satisfiedPairCount': an.satisfiedPairs.length,
      'activeStitchCount': an.activeStitchCount,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = StitchesSolver.analyze(puz, ps[s].hStitches, ps[s].vStitches);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'satisfiedPairs': pAn.satisfiedPairs.length,
              'totalPairs': puz.totalPairs,
              'activeStitches': pAn.activeStitchCount,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class StitchesPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  late List<List<int>> hStitches;
  late List<List<int>> vStitches;

  StitchesPlayer(int size) {
    clearStitches(size);
  }

  void clearStitches(int size) {
    hStitches = [for (var r = 0; r < size; r++) List<int>.filled(size - 1, 0)];
    vStitches = [for (var r = 0; r < size - 1; r++) List<int>.filled(size, 0)];
  }

  void resetForRound(int size) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    clearStitches(size);
  }
}
