import 'dart:math';

import '../../src/engine.dart';
import 'a13_util.dart';

class ThermometersPuzzle {
  final int size;
  /// List of Thermometers: each is `[[r0, c0], [r1, c1], ...]` of length `2..5`,
  /// where `[r0, c0]` is the Bulb (`index 0`).
  final List<List<List<int>>> thermos;
  /// Flat `size * size` map: cell index -> thermometer index `0..thermos.length-1`.
  final List<int> thermoIdMap;
  /// Flat `size * size` map: cell index -> position `0..len-1` along its thermometer (`0` = Bulb).
  final List<int> thermoPosMap;
  /// Exact mercury count clue for each row `0..size-1`.
  final List<int> rowClues;
  /// Exact mercury count clue for each column `0..size-1`.
  final List<int> colClues;
  /// Flat `size * size` solution (`0` = Empty, `1` = Mercury-filled).
  final List<int> solutionBoard;

  const ThermometersPuzzle({
    required this.size,
    required this.thermos,
    required this.thermoIdMap,
    required this.thermoPosMap,
    required this.rowClues,
    required this.colClues,
    required this.solutionBoard,
  });

  int get thermoCount => thermos.length;

  List<int> get initialBoard => List<int>.filled(size * size, 0);
}

class ThermometersAnalysis {
  final List<int> rowCounts;
  final List<int> colCounts;
  final Set<int> satisfiedRows;
  final Set<int> violatedRows;
  final Set<int> satisfiedCols;
  final Set<int> violatedCols;
  final Set<int> validThermos;
  final Set<int> brokenThermos;
  final Set<int> gapCells;
  final int filledCount;
  final int totalTargetFilled;

  const ThermometersAnalysis({
    required this.rowCounts,
    required this.colCounts,
    required this.satisfiedRows,
    required this.violatedRows,
    required this.satisfiedCols,
    required this.violatedCols,
    required this.validThermos,
    required this.brokenThermos,
    required this.gapCells,
    required this.filledCount,
    required this.totalTargetFilled,
  });

  bool get isSolved =>
      brokenThermos.isEmpty &&
      gapCells.isEmpty &&
      violatedRows.isEmpty &&
      violatedCols.isEmpty &&
      satisfiedRows.length == rowCounts.length &&
      satisfiedCols.length == colCounts.length;
}

class ThermometersSolver {
  static const List<int> orthoDr = [-1, 0, 1, 0];
  static const List<int> orthoDc = [0, 1, 0, -1];

  static bool isFilled(List<int> board, int idx) =>
      idx >= 0 && idx < board.length && board[idx] == 1;

  static ThermometersAnalysis analyze(ThermometersPuzzle puz, List<int> board) {
    final size = puz.size;
    final rowCounts = List<int>.filled(size, 0);
    final colCounts = List<int>.filled(size, 0);
    final satisfiedRows = <int>{};
    final violatedRows = <int>{};
    final satisfiedCols = <int>{};
    final violatedCols = <int>{};
    final validThermos = <int>{};
    final brokenThermos = <int>{};
    final gapCells = <int>{};

    var filledCount = 0;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final idx = r * size + c;
        if (isFilled(board, idx)) {
          filledCount++;
          rowCounts[r]++;
          colCounts[c]++;
        }
      }
    }

    for (var r = 0; r < size; r++) {
      if (rowCounts[r] == puz.rowClues[r]) {
        satisfiedRows.add(r);
      } else if (rowCounts[r] > puz.rowClues[r]) {
        violatedRows.add(r);
      }
    }

    for (var c = 0; c < size; c++) {
      if (colCounts[c] == puz.colClues[c]) {
        satisfiedCols.add(c);
      } else if (colCounts[c] > puz.colClues[c]) {
        violatedCols.add(c);
      }
    }

    // Check continuous fill from Bulb (index 0) in every thermometer
    for (var t = 0; t < puz.thermos.length; t++) {
      final cells = puz.thermos[t];
      var seenEmpty = false;
      var broken = false;
      for (var k = 0; k < cells.length; k++) {
        final rc = cells[k];
        final idx = rc[0] * size + rc[1];
        final filled = isFilled(board, idx);
        if (!filled) {
          seenEmpty = true;
        } else if (seenEmpty) {
          broken = true;
          gapCells.add(idx);
        }
      }
      if (broken) {
        brokenThermos.add(t);
      } else {
        validThermos.add(t);
      }
    }

    final totalTargetFilled = puz.rowClues.fold<int>(0, (a, b) => a + b);

    return ThermometersAnalysis(
      rowCounts: rowCounts,
      colCounts: colCounts,
      satisfiedRows: satisfiedRows,
      violatedRows: violatedRows,
      satisfiedCols: satisfiedCols,
      violatedCols: violatedCols,
      validThermos: validThermos,
      brokenThermos: brokenThermos,
      gapCells: gapCells,
      filledCount: filledCount,
      totalTargetFilled: totalTargetFilled,
    );
  }

  static bool isSolved(ThermometersPuzzle puz, List<int> board) {
    final n = puz.size * puz.size;
    if (board.length != n) return false;
    return analyze(puz, board).isSolved;
  }

  static bool _hasIsolatedSingleCell(int size, List<int> assigned) {
    final n = size * size;
    for (var i = 0; i < n; i++) {
      if (assigned[i] != -1) continue;
      final r = i ~/ size, c = i % size;
      var unassignedNbs = 0;
      for (var d = 0; d < 4; d++) {
        final nr = r + orthoDr[d], nc = c + orthoDc[d];
        if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
          if (assigned[nr * size + nc] == -1) {
            unassignedNbs++;
            break;
          }
        }
      }
      if (unassignedNbs == 0) return true;
    }
    return false;
  }

  static List<List<int>> _enumPathsFrom(
    int size,
    List<int> assigned,
    int startIdx,
    Random rng,
  ) {
    final results = <List<int>>[];

    void dfs(List<int> cur) {
      if (cur.length >= 2) {
        results.add(List<int>.of(cur));
      }
      if (cur.length >= 4) return; // Keep lengths 2..4 (up to 5 allowed)
      final last = cur.last;
      final r = last ~/ size, c = last % size;
      final dirs = [0, 1, 2, 3]..shuffle(rng);
      for (final d in dirs) {
        final nr = r + orthoDr[d], nc = c + orthoDc[d];
        if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
        final nIdx = nr * size + nc;
        if (assigned[nIdx] != -1 || cur.contains(nIdx)) continue;
        cur.add(nIdx);
        dfs(cur);
        cur.removeLast();
        if (results.length >= 16) return;
      }
    }

    dfs([startIdx]);
    results.shuffle(rng);
    // Prefer length 3 and 4 over length 2 for varied thermometers
    results.sort((a, b) {
      int scoreLen(int l) => (l == 3 || l == 4) ? 0 : 1;
      return scoreLen(a.length).compareTo(scoreLen(b.length));
    });
    return results;
  }

  /// Generates a guaranteed-valid Thermometers puzzle for [size] (`5` or `6`).
  static ThermometersPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    List<List<int>>? flatThermos;

    for (var attempt = 0; attempt < 20; attempt++) {
      final assigned = List<int>.filled(n, -1);
      final paths = <List<int>>[];
      var steps = 0;

      bool backtrack() {
        if (++steps > 800) return false;
        // Pick an unassigned cell with the fewest unassigned neighbors first
        var bestCell = -1;
        var bestDeg = 99;
        for (var i = 0; i < n; i++) {
          if (assigned[i] != -1) continue;
          final r = i ~/ size, c = i % size;
          var deg = 0;
          for (var d = 0; d < 4; d++) {
            final nr = r + orthoDr[d], nc = c + orthoDc[d];
            if (nr >= 0 && nr < size && nc >= 0 && nc < size && assigned[nr * size + nc] == -1) {
              deg++;
            }
          }
          if (deg == 0) return false;
          if (deg < bestDeg) {
            bestDeg = deg;
            bestCell = i;
            if (deg == 1) break;
          }
        }
        if (bestCell == -1) return true;

        final candidates = _enumPathsFrom(size, assigned, bestCell, rng);
        for (final path in candidates) {
          final tId = paths.length;
          for (final idx in path) {
            assigned[idx] = tId;
          }
          if (!_hasIsolatedSingleCell(size, assigned)) {
            paths.add(path);
            if (backtrack()) return true;
            paths.removeLast();
          }
          for (final idx in path) {
            assigned[idx] = -1;
          }
        }
        return false;
      }

      if (backtrack()) {
        flatThermos = paths;
        break;
      }
    }

    // Deterministic snake-partition fallback if random backtracking hit step limit
    if (flatThermos == null) {
      final snake = <int>[];
      for (var r = 0; r < size; r++) {
        if (r.isEven) {
          for (var c = 0; c < size; c++) {
            snake.add(r * size + c);
          }
        } else {
          for (var c = size - 1; c >= 0; c--) {
            snake.add(r * size + c);
          }
        }
      }
      flatThermos = <List<int>>[];
      var idx = 0;
      while (idx < n) {
        final rem = n - idx;
        final take = rem == 5
            ? 5
            : (rem == 4
                ? 4
                : (rem == 6 ? 3 : 4));
        flatThermos.add(snake.sublist(idx, idx + take));
        idx += take;
      }
    }

    // Randomly orient each thermometer (bulb at either end)
    final thermos = <List<List<int>>>[];
    final thermoIdMap = List<int>.filled(n, 0);
    final thermoPosMap = List<int>.filled(n, 0);

    for (var t = 0; t < flatThermos.length; t++) {
      final path = List<int>.of(flatThermos[t]);
      if (rng.nextBool()) {
        path.replaceRange(0, path.length, path.reversed);
      }
      final coords = <List<int>>[];
      for (var k = 0; k < path.length; k++) {
        final cellIdx = path[k];
        final r = cellIdx ~/ size, c = cellIdx % size;
        coords.add([r, c]);
        thermoIdMap[cellIdx] = t;
        thermoPosMap[cellIdx] = k;
      }
      thermos.add(coords);
    }

    // Choose a valid continuous fill level 0..len for each thermometer
    final sol = List<int>.filled(n, 0);
    var totalFilled = 0;
    for (var t = 0; t < thermos.length; t++) {
      final cells = thermos[t];
      final len = cells.length;
      final fillLevel = rng.nextInt(len + 1);
      for (var k = 0; k < fillLevel; k++) {
        final rc = cells[k];
        sol[rc[0] * size + rc[1]] = 1;
        totalFilled++;
      }
    }

    // Ensure at least `size` cells are filled so initial empty board is never solved
    for (var t = 0; t < thermos.length && totalFilled < size; t++) {
      final cells = thermos[t];
      for (var k = 0; k < cells.length && totalFilled < size; k++) {
        final idx = cells[k][0] * size + cells[k][1];
        if (sol[idx] == 0) {
          sol[idx] = 1;
          totalFilled++;
        }
      }
    }

    final rowClues = List<int>.filled(size, 0);
    final colClues = List<int>.filled(size, 0);
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (sol[r * size + c] == 1) {
          rowClues[r]++;
          colClues[c]++;
        }
      }
    }

    return ThermometersPuzzle(
      size: size,
      thermos: thermos,
      thermoIdMap: thermoIdMap,
      thermoPosMap: thermoPosMap,
      rowClues: rowClues,
      colClues: colClues,
      solutionBoard: sol,
    );
  }
}

/// 温度计填充竞速 (Thermometers Race, 1-6 人).
class ThermometersGame extends GameEngine {
  ThermometersGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late ThermometersPuzzle currentPuzzle;
  late List<ThermometersPlayer> ps;
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

    currentPuzzle = ThermometersSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) ThermometersPlayer(size * size)];

    host.log('温度计填充竞速开始（$size×$size 网格，共 $totalRounds 题）！从水银球起连续注入水银并匹配行列总数！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = ThermometersSolver.generatePuzzle(size, rng);
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
      case 'toggle':
      case 'set':
        final (r, c) = _resolveCell(a);
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
        moves++;
        if (ThermometersSolver.isSolved(currentPuzzle, p.board)) {
          _markSolved(seat);
        }

      case 'fill_to':
        final (r, c) = _resolveCell(a);
        final idx = r * size + c;
        final tId = currentPuzzle.thermoIdMap[idx];
        final pos = currentPuzzle.thermoPosMap[idx];
        final cells = currentPuzzle.thermos[tId];
        for (var k = 0; k < cells.length; k++) {
          final rc = cells[k];
          final cIdx = rc[0] * size + rc[1];
          p.board[cIdx] = k <= pos ? 1 : 0;
        }
        moves++;
        if (ThermometersSolver.isSolved(currentPuzzle, p.board)) {
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
    host.log('${name(seat)} 第 $roundSolvers 个解出温度计谜题，+$pts 分！');
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
    final sol = currentPuzzle.solutionBoard;

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
    final an = ThermometersSolver.analyze(puz, myBoard);
    final totalLines = size * 2;
    final satisfiedLines = an.satisfiedRows.length + an.satisfiedCols.length;

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'thermos': puz.thermos,
      'thermoIdMap': puz.thermoIdMap,
      'thermoPosMap': puz.thermoPosMap,
      'rowClues': puz.rowClues,
      'colClues': puz.colClues,
      'board': myBoard,
      'rowCounts': an.rowCounts,
      'colCounts': an.colCounts,
      'satisfiedRows': an.satisfiedRows.toList()..sort(),
      'violatedRows': an.violatedRows.toList()..sort(),
      'satisfiedCols': an.satisfiedCols.toList()..sort(),
      'violatedCols': an.violatedCols.toList()..sort(),
      'validThermos': an.validThermos.toList()..sort(),
      'brokenThermos': an.brokenThermos.toList()..sort(),
      'gapCells': an.gapCells.toList()..sort(),
      'satisfiedLines': satisfiedLines,
      'totalLines': totalLines,
      'filledCount': an.filledCount,
      'totalTargetFilled': an.totalTargetFilled,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = ThermometersSolver.analyze(puz, ps[s].board);
            final pSatLines = pAn.satisfiedRows.length + pAn.satisfiedCols.length;
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'satisfiedLines': pSatLines,
              'totalLines': totalLines,
              'filledCount': pAn.filledCount,
              'totalTargetFilled': pAn.totalTargetFilled,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class ThermometersPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  ThermometersPlayer(int cellCount) : board = List<int>.filled(cellCount, 0);

  void resetForRound(int cellCount) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.filled(cellCount, 0);
  }
}
