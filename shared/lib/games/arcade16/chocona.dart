import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';
import 'a16_util.dart';

class ChoconaPuzzle {
  final int size;
  final int regionCount;
  /// `size × size` grid of polyomino Region IDs `0..regionCount-1`.
  final List<List<int>> regions;
  /// Exact count of Black (`1`) cells required in each Region `0..regionCount-1` (`-1` if un-clued).
  final List<int> regionClues;
  /// Total cell count of each Region `0..regionCount-1`.
  final List<int> regionSizes;
  /// Top-left-most flat cell index `r * size + c` for each Region `0..regionCount-1`.
  final List<int> regionAnchorCells;
  /// Flat `size * size` solution (`0` = White, `1` = Black Chocolate `■`).
  final List<int> solutionBoard;

  const ChoconaPuzzle({
    required this.size,
    required this.regionCount,
    required this.regions,
    required this.regionClues,
    required this.regionSizes,
    required this.regionAnchorCells,
    required this.solutionBoard,
  });

  List<int> get regionMap => [
        for (var r = 0; r < size; r++)
          for (var c = 0; c < size; c++) regions[r][c],
      ];

  List<int> get initialBoard => List<int>.filled(size * size, 0);
}

class ChoconaAnalysis {
  final Set<int> satisfiedRegions;
  final Set<int> violatedRegions;
  final Set<int> pendingRegions;
  final List<int> regionBlackCounts;
  /// Flat cell indices belonging to any orthogonally connected Black component
  /// that is NOT a solid axis-aligned rectangle.
  final Set<int> nonRectCells;
  final int blackComponentCount;
  final int rectComponentCount;
  final int cluedRegionCount;
  final int blackCount;
  final int dotCount;
  final int regionCount;

  const ChoconaAnalysis({
    required this.satisfiedRegions,
    required this.violatedRegions,
    required this.pendingRegions,
    required this.regionBlackCounts,
    required this.nonRectCells,
    required this.blackComponentCount,
    required this.rectComponentCount,
    required this.cluedRegionCount,
    required this.blackCount,
    required this.dotCount,
    required this.regionCount,
  });

  bool get isSolved =>
      cluedRegionCount > 0 &&
      satisfiedRegions.length == cluedRegionCount &&
      violatedRegions.isEmpty &&
      pendingRegions.isEmpty &&
      nonRectCells.isEmpty;
}

class ChoconaSolver {
  static const List<int> orthoDr = [-1, 0, 1, 0];
  static const List<int> orthoDc = [0, 1, 0, -1];

  /// Checks all orthogonally connected components of Black (`1`) cells on [board]
  /// and returns `(blackCompCount, rectCompCount, nonRectCells)`.
  static (int, int, Set<int>) inspectBlackRectangles(int size, List<int> board) {
    final n = size * size;
    final visited = List<bool>.filled(n, false);
    final nonRectCells = <int>{};
    var blackCompCount = 0;
    var rectCompCount = 0;

    for (var start = 0; start < n; start++) {
      if (start >= board.length || board[start] != 1 || visited[start]) continue;
      blackCompCount++;
      final comp = <int>[];
      final q = Queue<int>()..add(start);
      visited[start] = true;

      var minR = size, maxR = -1, minC = size, maxC = -1;
      while (q.isNotEmpty) {
        final cur = q.removeFirst();
        comp.add(cur);
        final r = cur ~/ size, c = cur % size;
        if (r < minR) minR = r;
        if (r > maxR) maxR = r;
        if (c < minC) minC = c;
        if (c > maxC) maxC = c;

        for (var d = 0; d < 4; d++) {
          final nr = r + orthoDr[d], nc = c + orthoDc[d];
          if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
          final nxt = nr * size + nc;
          if (!visited[nxt] && nxt < board.length && board[nxt] == 1) {
            visited[nxt] = true;
            q.add(nxt);
          }
        }
      }

      final h = maxR - minR + 1;
      final w = maxC - minC + 1;
      if (comp.length == h * w) {
        rectCompCount++;
      } else {
        nonRectCells.addAll(comp);
      }
    }

    return (blackCompCount, rectCompCount, nonRectCells);
  }

  static ChoconaAnalysis analyze(ChoconaPuzzle puz, List<int> board) {
    final size = puz.size;
    final n = size * size;
    final regionCount = puz.regionCount;

    final regionBlackCounts = List<int>.filled(regionCount, 0);
    var blackCount = 0;
    var dotCount = 0;

    for (var i = 0; i < n; i++) {
      final v = i < board.length ? board[i] : 0;
      if (v == 1) {
        blackCount++;
        final reg = puz.regions[i ~/ size][i % size];
        if (reg >= 0 && reg < regionCount) {
          regionBlackCounts[reg]++;
        }
      } else if (v == 2) {
        dotCount++;
      }
    }

    final satisfiedRegions = <int>{};
    final violatedRegions = <int>{};
    final pendingRegions = <int>{};
    var cluedRegionCount = 0;

    for (var reg = 0; reg < regionCount; reg++) {
      final clue = reg < puz.regionClues.length ? puz.regionClues[reg] : -1;
      if (clue < 0) continue;
      cluedRegionCount++;
      final cnt = regionBlackCounts[reg];
      if (cnt == clue) {
        satisfiedRegions.add(reg);
      } else if (cnt > clue) {
        violatedRegions.add(reg);
      } else {
        pendingRegions.add(reg);
      }
    }

    final (blackCompCount, rectCompCount, nonRectCells) = inspectBlackRectangles(size, board);

    return ChoconaAnalysis(
      satisfiedRegions: satisfiedRegions,
      violatedRegions: violatedRegions,
      pendingRegions: pendingRegions,
      regionBlackCounts: regionBlackCounts,
      nonRectCells: nonRectCells,
      blackComponentCount: blackCompCount,
      rectComponentCount: rectCompCount,
      cluedRegionCount: cluedRegionCount,
      blackCount: blackCount,
      dotCount: dotCount,
      regionCount: regionCount,
    );
  }

  static bool isSolved(ChoconaPuzzle puz, List<int> board) {
    if (board.length != puz.size * puz.size) return false;
    return analyze(puz, board).isSolved;
  }

  /// Generates a guaranteed-valid Chocona puzzle for [size] (`5` or `6`).
  static ChoconaPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    final targetRegions = size <= 5 ? (6 + rng.nextInt(2)) : (8 + rng.nextInt(2));
    final minBlackCells = size <= 5 ? 8 : 11;
    final maxBlackCells = size <= 5 ? 13 : 17;

    for (var attempt = 0; attempt < 50; attempt++) {
      // 1. Place non-touching solid axis-aligned Black rectangles across the grid
      final sol = List<int>.filled(n, 0);
      var totalBlack = 0;
      var rectCount = 0;
      var multiCellRects = 0;

      for (var t = 0; t < 35 && totalBlack < minBlackCells; t++) {
        final h = 1 + rng.nextInt(3);
        final w = 1 + rng.nextInt(3);
        if (h * w > 6) continue;
        final r1 = rng.nextInt(size - h + 1);
        final c1 = rng.nextInt(size - w + 1);
        final r2 = r1 + h - 1;
        final c2 = c1 + w - 1;
        if (totalBlack + h * w > maxBlackCells) continue;

        // Check that neither the rectangle nor its 4-neighborhood already contains Black cells
        var touchesOrOverlaps = false;
        for (var r = r1; r <= r2 && !touchesOrOverlaps; r++) {
          for (var c = c1; c <= c2; c++) {
            if (sol[r * size + c] == 1) {
              touchesOrOverlaps = true;
              break;
            }
            for (var d = 0; d < 4; d++) {
              final nr = r + orthoDr[d], nc = c + orthoDc[d];
              if (nr >= 0 && nr < size && nc >= 0 && nc < size && sol[nr * size + nc] == 1) {
                touchesOrOverlaps = true;
                break;
              }
            }
          }
        }
        if (touchesOrOverlaps) continue;

        for (var r = r1; r <= r2; r++) {
          for (var c = c1; c <= c2; c++) {
            sol[r * size + c] = 1;
          }
        }
        totalBlack += h * w;
        rectCount++;
        if (h * w >= 2) multiCellRects++;
      }

      if (totalBlack < minBlackCells || rectCount < 3 || multiCellRects < 2) continue;

      final (_, _, nonRects) = inspectBlackRectangles(size, sol);
      if (nonRects.isNotEmpty) continue;

      // 2. Partition the grid into orthogonally connected polyomino regions
      final regFlat = List<int>.filled(n, -1);
      final seeds = ([for (var i = 0; i < n; i++) i]..shuffle(rng)).take(targetRegions).toList();
      final regSizes = List<int>.filled(targetRegions, 0);
      for (var k = 0; k < targetRegions; k++) {
        regFlat[seeds[k]] = k;
        regSizes[k] = 1;
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
              final nbReg = regFlat[nr * size + nc];
              if (nbReg != -1) {
                candidates.add((i, nbReg));
              }
            }
          }
        }
        if (candidates.isEmpty) break;
        candidates.sort((a, b) => regSizes[a.$2].compareTo(regSizes[b.$2]));
        final topCount = min(candidates.length, 4);
        final (cellIdx, chosenReg) = candidates[rng.nextInt(topCount)];
        if (regFlat[cellIdx] == -1) {
          regFlat[cellIdx] = chosenReg;
          regSizes[chosenReg]++;
          unassigned--;
        }
      }
      if (unassigned > 0 || regSizes.any((s) => s < 2)) continue;

      final regions = [
        for (var r = 0; r < size; r++)
          [for (var c = 0; c < size; c++) regFlat[r * size + c]],
      ];
      final regionClues = List<int>.filled(targetRegions, 0);
      final regionAnchors = List<int>.filled(targetRegions, -1);
      for (var i = 0; i < n; i++) {
        final reg = regFlat[i];
        if (regionAnchors[reg] == -1) regionAnchors[reg] = i;
        if (sol[i] == 1) regionClues[reg]++;
      }

      final puz = ChoconaPuzzle(
        size: size,
        regionCount: targetRegions,
        regions: regions,
        regionClues: regionClues,
        regionSizes: regSizes,
        regionAnchorCells: regionAnchors,
        solutionBoard: sol,
      );
      if (isSolved(puz, sol) && !isSolved(puz, puz.initialBoard)) {
        return puz;
      }
    }

    // Deterministic fallback
    final sol = List<int>.filled(n, 0);
    // Rect 1: 2x2 at (0..1, 0..1)
    for (final r in [0, 1]) {
      for (final c in [0, 1]) {
        sol[r * size + c] = 1;
      }
    }
    // Rect 2: 1x3 at (0, 3..min(5, size-1))
    for (var c = 3; c < size; c++) {
      sol[c] = 1;
    }
    // Rect 3: 2x2 at (3..4, 1..2)
    for (final r in [3, 4]) {
      for (final c in [1, 2]) {
        sol[r * size + c] = 1;
      }
    }
    // Rect 4: 2x1 at (2..3, 4)
    sol[2 * size + 4] = 1;
    sol[3 * size + 4] = 1;

    final regions = [
      for (var r = 0; r < size; r++)
        [
          for (var c = 0; c < size; c++)
            r < 2 ? (c < 2 ? 0 : (c < 4 ? 1 : 2)) : (r < 4 ? (c < 3 ? 3 : 4) : 5),
        ],
    ];
    const regCount = 6;
    final regionClues = List<int>.filled(regCount, 0);
    final regionSizes = List<int>.filled(regCount, 0);
    final regionAnchors = List<int>.filled(regCount, -1);
    for (var i = 0; i < n; i++) {
      final reg = regions[i ~/ size][i % size];
      regionSizes[reg]++;
      if (regionAnchors[reg] == -1) regionAnchors[reg] = i;
      if (sol[i] == 1) regionClues[reg]++;
    }
    return ChoconaPuzzle(
      size: size,
      regionCount: regCount,
      regions: regions,
      regionClues: regionClues,
      regionSizes: regionSizes,
      regionAnchorCells: regionAnchors,
      solutionBoard: sol,
    );
  }
}

/// 巧克块矩形竞速 (Chocona Race, 1-6 人).
class ChoconaGame extends GameEngine {
  ChoconaGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late ChoconaPuzzle currentPuzzle;
  late List<ChoconaPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<List<int>> get boards => [for (final p in ps) p.board];
  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a16Placings(ranking, players) : null;

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

    currentPuzzle = ChoconaSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) ChoconaPlayer(size * size)];

    host.log('巧克块矩形竞速开始（$size×$size 网格，共 $totalRounds 题）！匹配每个区域黑格计数，且所有黑格连通群必须为实心矩形！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = ChoconaSolver.generatePuzzle(size, rng);
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
    return a16Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
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
      case 'toggle':
      case 'set':
      case 'shade':
        final (r, c) = _resolveCell(a);
        final idx = r * size + c;
        if (a.containsKey('val')) {
          final v = asInt(a['val'], -1);
          if (v < 0 || v > 2) {
            throw GameError('格子状态必须在 0～2 之间');
          }
          p.board[idx] = v;
        } else if (type == 'shade') {
          p.board[idx] = p.board[idx] == 1 ? 0 : 1;
        } else {
          p.board[idx] = (p.board[idx] + 1) % 3;
        }
        moves++;
        if (ChoconaSolver.isSolved(currentPuzzle, p.board)) {
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
    host.log('${name(seat)} 第 $roundSolvers 个解出巧克块矩形谜题，+$pts 分！');
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
    ranking = a16Ranking(players, (a, b) {
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
    host.log('游戏结束（$why）！冠军：${a16Winners(ranking!, name)}');
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
        if ((p.board[i] == 1) != (sol[i] == 1)) i,
    ];
    if (diff.isNotEmpty) {
      final pick = diff[rng.nextInt(diff.length)];
      return {
        'type': 'toggle',
        'r': pick ~/ size,
        'c': pick % size,
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
    final an = ChoconaSolver.analyze(puz, myBoard);

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
      'regionClues': puz.regionClues,
      'regionSizes': puz.regionSizes,
      'regionAnchorCells': puz.regionAnchorCells,
      'cluedRegionCount': an.cluedRegionCount,
      'board': myBoard,
      'regionBlackCounts': an.regionBlackCounts,
      'satisfiedRegions': an.satisfiedRegions.toList()..sort(),
      'violatedRegions': an.violatedRegions.toList()..sort(),
      'pendingRegions': an.pendingRegions.toList()..sort(),
      'nonRectCells': an.nonRectCells.toList()..sort(),
      'satisfiedRegionCount': an.satisfiedRegions.length,
      'blackComponentCount': an.blackComponentCount,
      'rectComponentCount': an.rectComponentCount,
      'blackCount': an.blackCount,
      'dotCount': an.dotCount,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = ChoconaSolver.analyze(puz, ps[s].board);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'satisfiedRegions': pAn.satisfiedRegions.length,
              'regionCount': pAn.cluedRegionCount,
              'blackCount': pAn.blackCount,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class ChoconaPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  ChoconaPlayer(int cellCount) : board = List<int>.filled(cellCount, 0);

  void resetForRound(int cellCount) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.filled(cellCount, 0);
  }
}
