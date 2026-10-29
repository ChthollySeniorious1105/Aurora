import 'dart:math';

import '../../src/engine.dart';
import 'a9_util.dart';

class StarBattlePuzzle {
  final int size;
  /// 2D region map (`regions[r][c]` in `0..size-1`).
  final List<List<int>> regions;
  /// Flat `size * size` region map (`0..size-1`).
  final List<int> flatRegions;
  /// Valid solution board (`1` for Star, `0` for empty).
  final List<int> solutionBoard;

  const StarBattlePuzzle({
    required this.size,
    required this.regions,
    required this.flatRegions,
    required this.solutionBoard,
  });
}

class StarBattleAnalysis {
  final List<int> rowCounts;
  final List<int> colCounts;
  final List<int> regionCounts;
  final Set<int> touchingStars;
  final Set<int> conflictCells;
  final int satisfiedUnits;
  final int totalUnits;
  final int starCount;

  const StarBattleAnalysis({
    required this.rowCounts,
    required this.colCounts,
    required this.regionCounts,
    required this.touchingStars,
    required this.conflictCells,
    required this.satisfiedUnits,
    required this.totalUnits,
    required this.starCount,
  });

  bool get isSolved =>
      starCount == rowCounts.length &&
      satisfiedUnits == totalUnits &&
      touchingStars.isEmpty;
}

class StarBattleSolver {
  static const List<int> dr4 = [-1, 0, 1, 0];
  static const List<int> dc4 = [0, 1, 0, -1];

  static StarBattleAnalysis analyze(StarBattlePuzzle puz, List<int> marks) {
    final size = puz.size;
    final n = size * size;
    final rowCounts = List<int>.filled(size, 0);
    final colCounts = List<int>.filled(size, 0);
    final regionCounts = List<int>.filled(size, 0);
    final stars = <int>[];

    for (var i = 0; i < n; i++) {
      final m = i < marks.length ? marks[i] : 0;
      if (m == 1) {
        final r = i ~/ size, c = i % size;
        final reg = puz.flatRegions[i];
        rowCounts[r]++;
        colCounts[c]++;
        if (reg >= 0 && reg < size) regionCounts[reg]++;
        stars.add(i);
      }
    }

    final touchingStars = <int>{};
    for (var i = 0; i < stars.length; i++) {
      final r1 = stars[i] ~/ size, c1 = stars[i] % size;
      for (var j = i + 1; j < stars.length; j++) {
        final r2 = stars[j] ~/ size, c2 = stars[j] % size;
        if ((r1 - r2).abs() <= 1 && (c1 - c2).abs() <= 1) {
          touchingStars.add(stars[i]);
          touchingStars.add(stars[j]);
        }
      }
    }

    final conflictCells = <int>{...touchingStars};
    for (final idx in stars) {
      final r = idx ~/ size, c = idx % size;
      final reg = puz.flatRegions[idx];
      if (rowCounts[r] > 1 ||
          colCounts[c] > 1 ||
          (reg >= 0 && reg < size && regionCounts[reg] > 1)) {
        conflictCells.add(idx);
      }
    }

    var satisfiedUnits = 0;
    for (var i = 0; i < size; i++) {
      if (rowCounts[i] == 1) satisfiedUnits++;
      if (colCounts[i] == 1) satisfiedUnits++;
      if (regionCounts[i] == 1) satisfiedUnits++;
    }

    return StarBattleAnalysis(
      rowCounts: rowCounts,
      colCounts: colCounts,
      regionCounts: regionCounts,
      touchingStars: touchingStars,
      conflictCells: conflictCells,
      satisfiedUnits: satisfiedUnits,
      totalUnits: 3 * size,
      starCount: stars.length,
    );
  }

  static bool isSolved(StarBattlePuzzle puz, List<int> marks) {
    if (marks.length != puz.size * puz.size) return false;
    return analyze(puz, marks).isSolved;
  }

  static bool _placeQueens(
    int row,
    int size,
    List<int> colOfRow,
    List<bool> usedCols,
    Random rng,
  ) {
    if (row >= size) return true;
    final cols = [for (var c = 0; c < size; c++) c]..shuffle(rng);
    for (final c in cols) {
      if (usedCols[c]) continue;
      if (row > 0 && (c - colOfRow[row - 1]).abs() < 2) continue;
      colOfRow[row] = c;
      usedCols[c] = true;
      if (_placeQueens(row + 1, size, colOfRow, usedCols, rng)) return true;
      usedCols[c] = false;
    }
    return false;
  }

  /// Generates a 100% guaranteed-valid Star Battle puzzle for [size] (`5` or `6`).
  static StarBattlePuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    final colOfRow = List<int>.filled(size, 0);
    final usedCols = List<bool>.filled(size, false);
    if (!_placeQueens(0, size, colOfRow, usedCols, rng)) {
      // Deterministic valid fallback for N>=5: even columns then odd columns
      var idx = 0;
      for (var c = 0; c < size; c += 2) {
        colOfRow[idx++] = c;
      }
      for (var c = 1; c < size; c += 2) {
        colOfRow[idx++] = c;
      }
    }

    final solBoard = List<int>.filled(n, 0);
    final flatRegions = List<int>.filled(n, -1);
    final regSizes = List<int>.filled(size, 1);

    for (var r = 0; r < size; r++) {
      final idx = r * size + colOfRow[r];
      solBoard[idx] = 1;
      flatRegions[idx] = r;
    }

    var unassigned = n - size;
    while (unassigned > 0) {
      // Collect frontier candidates (cellIdx, regId)
      final frontier = <(int, int)>[];
      for (var i = 0; i < n; i++) {
        if (flatRegions[i] != -1) continue;
        final r = i ~/ size, c = i % size;
        for (var d = 0; d < 4; d++) {
          final nr = r + dr4[d], nc = c + dc4[d];
          if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
          final nReg = flatRegions[nr * size + nc];
          if (nReg != -1) {
            frontier.add((i, nReg));
          }
        }
      }
      frontier.shuffle(rng);
      // Prefer growing whichever region currently has the fewest cells
      frontier.sort((a, b) => regSizes[a.$2] - regSizes[b.$2]);
      final chosen = frontier.first;
      flatRegions[chosen.$1] = chosen.$2;
      regSizes[chosen.$2]++;
      unassigned--;
    }

    final regions2D = [
      for (var r = 0; r < size; r++)
        [for (var c = 0; c < size; c++) flatRegions[r * size + c]],
    ];

    return StarBattlePuzzle(
      size: size,
      regions: regions2D,
      flatRegions: flatRegions,
      solutionBoard: solBoard,
    );
  }
}

/// 星战放星竞速 (Star Battle Race, 1-6 人).
class StarBattleGame extends GameEngine {
  StarBattleGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late StarBattlePuzzle currentPuzzle;
  late List<StarBattlePlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<List<int>> get boards => [for (final p in ps) p.marks];
  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a9Placings(ranking, players) : null;

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
    size = rawSize == 5 ? 5 : 6;
    totalRounds = setup.opt<int>('rounds', 3) == 1 ? 1 : 3;

    currentPuzzle = StarBattleSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) StarBattlePlayer(size * size)];

    host.log('星战放星竞速开始（$size×$size 网格，共 $totalRounds 题）！每行、每列、每个色块各放 1 颗星且八向不接触！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = StarBattleSolver.generatePuzzle(size, rng);
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
    return a9Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
  }

  int _resolveCellIndex(Map<String, dynamic> a) {
    if (a.containsKey('r') && a.containsKey('c')) {
      final r = asInt(a['r']);
      final c = asInt(a['c']);
      if (r < 0 || r >= size || c < 0 || c >= size) {
        throw GameError('行列坐标超出棋盘范围');
      }
      return r * size + c;
    }
    final idx = asInt(a['i']);
    if (idx < 0 || idx >= size * size) {
      throw GameError('格子索引超出棋盘范围');
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
      case 'toggle':
      case 'set':
        final idx = _resolveCellIndex(a);
        if (a.containsKey('val')) {
          final v = asInt(a['val']);
          if (v < 0 || v > 2) throw GameError('状态值必须为 0、1 或 2');
          p.marks[idx] = v;
        } else {
          p.marks[idx] = (p.marks[idx] + 1) % 3;
        }
        moves++;
        if (StarBattleSolver.isSolved(currentPuzzle, p.marks)) {
          _markSolved(seat);
        }

      case 'clear':
      case 'reset':
        p.marks.fillRange(0, p.marks.length, 0);
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
    host.log('${name(seat)} 第 $roundSolvers 个完成星战放星，+$pts 分！');
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
    ranking = a9Ranking(players, (a, b) {
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
    host.log('游戏结束（$why）！冠军：${a9Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || !_activeInRound(seat)) return null;
    final p = ps[seat];
    final sol = currentPuzzle.solutionBoard;

    if (botLevel <= 0 && rng.nextInt(14) == 0) {
      return {'type': 'pass'};
    }

    // First remove any misplaced star
    for (var i = 0; i < sol.length; i++) {
      if (p.marks[i] == 1 && sol[i] != 1) {
        return {'type': 'toggle', 'r': i ~/ size, 'c': i % size};
      }
    }

    // Then place a missing solution star
    final missing = <int>[
      for (var i = 0; i < sol.length; i++)
        if (sol[i] == 1 && p.marks[i] != 1) i,
    ];
    if (missing.isNotEmpty) {
      final pick = missing[rng.nextInt(missing.length)];
      return {'type': 'toggle', 'r': pick ~/ size, 'c': pick % size};
    }

    return {'type': 'pass'};
  }

  // ---------------------------------------------------------------- view

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players ? ps[seat] : (ps.isNotEmpty ? ps[0] : null);
    final puz = currentPuzzle;
    final myMarks = me?.marks ?? List<int>.filled(size * size, 0);
    final analysis = StarBattleSolver.analyze(puz, myMarks);

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'regions': puz.flatRegions,
      'regions2D': puz.regions,
      'marks': myMarks,
      'rowCounts': analysis.rowCounts,
      'colCounts': analysis.colCounts,
      'regionCounts': analysis.regionCounts,
      'conflicts': analysis.conflictCells.toList()..sort(),
      'touching': analysis.touchingStars.toList()..sort(),
      'satisfiedUnits': analysis.satisfiedUnits,
      'totalUnits': analysis.totalUnits,
      'starCount': analysis.starCount,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = StarBattleSolver.analyze(puz, ps[s].marks);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'satisfied': pAn.satisfiedUnits,
              'totalUnits': pAn.totalUnits,
              'stars': pAn.starCount,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class StarBattlePlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> marks;

  StarBattlePlayer(int cellCount) : marks = List<int>.filled(cellCount, 0);

  void resetForRound(int cellCount) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    marks = List<int>.filled(cellCount, 0);
  }
}
