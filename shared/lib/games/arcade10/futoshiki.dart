import 'dart:math';

import '../../src/engine.dart';
import 'a10_util.dart';

class FutoshikiPuzzle {
  final int size;
  /// 2D `size × size` fixed clues (`0` = empty, `1..size` = given digit).
  final List<List<int>> clues;
  /// 2D `size × (size - 1)` horizontal inequalities between `(r,c)` and `(r,c+1)`:
  /// `-1` means `(r,c) < (r,c+1)`, `1` means `(r,c) > (r,c+1)`, `0` means no clue.
  final List<List<int>> hIneq;
  /// 2D `(size - 1) × size` vertical inequalities between `(r,c)` and `(r+1,c)`:
  /// `-1` means `(r,c) < (r+1,c)`, `1` means `(r,c) > (r+1,c)`, `0` means no clue.
  final List<List<int>> vIneq;
  /// Flat `size * size` Latin Square solution of `1..size`.
  final List<int> solutionBoard;

  const FutoshikiPuzzle({
    required this.size,
    required this.clues,
    required this.hIneq,
    required this.vIneq,
    required this.solutionBoard,
  });

  List<int> get cluesFlat => [
        for (var r = 0; r < size; r++)
          for (var c = 0; c < size; c++) clues[r][c],
      ];
}

class FutoshikiAnalysis {
  final Set<int> duplicateCells;
  final Set<int> violatedCells;
  final Set<int> violatedH;
  final Set<int> violatedV;
  final int satisfiedIneq;
  final int totalIneq;
  final int validLines;
  final int filledCount;

  const FutoshikiAnalysis({
    required this.duplicateCells,
    required this.violatedCells,
    required this.violatedH,
    required this.violatedV,
    required this.satisfiedIneq,
    required this.totalIneq,
    required this.validLines,
    required this.filledCount,
  });

  Set<int> get conflictCells => {...duplicateCells, ...violatedCells};

  bool get isSolved =>
      filledCount > 0 &&
      duplicateCells.isEmpty &&
      violatedCells.isEmpty &&
      satisfiedIneq == totalIneq;
}

class FutoshikiSolver {
  static FutoshikiAnalysis analyze(FutoshikiPuzzle puz, List<int> board) {
    final size = puz.size;
    final n = size * size;
    final duplicateCells = <int>{};
    final violatedCells = <int>{};
    final violatedH = <int>{};
    final violatedV = <int>{};

    var filledCount = 0;
    for (var i = 0; i < n; i++) {
      final v = i < board.length ? board[i] : 0;
      if (v >= 1 && v <= size) filledCount++;
    }

    var validLines = 0;
    // Check rows
    for (var r = 0; r < size; r++) {
      final seen = <int, int>{};
      var rowComplete = true;
      var rowNoDup = true;
      for (var c = 0; c < size; c++) {
        final idx = r * size + c;
        final v = idx < board.length ? board[idx] : 0;
        if (v < 1 || v > size) {
          rowComplete = false;
          continue;
        }
        if (seen.containsKey(v)) {
          rowNoDup = false;
          duplicateCells.add(idx);
          duplicateCells.add(seen[v]!);
        } else {
          seen[v] = idx;
        }
      }
      if (rowComplete && rowNoDup && seen.length == size) {
        validLines++;
      }
    }

    // Check columns
    for (var c = 0; c < size; c++) {
      final seen = <int, int>{};
      var colComplete = true;
      var colNoDup = true;
      for (var r = 0; r < size; r++) {
        final idx = r * size + c;
        final v = idx < board.length ? board[idx] : 0;
        if (v < 1 || v > size) {
          colComplete = false;
          continue;
        }
        if (seen.containsKey(v)) {
          colNoDup = false;
          duplicateCells.add(idx);
          duplicateCells.add(seen[v]!);
        } else {
          seen[v] = idx;
        }
      }
      if (colComplete && colNoDup && seen.length == size) {
        validLines++;
      }
    }

    var totalIneq = 0;
    var satisfiedIneq = 0;

    // Horizontal inequalities
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size - 1; c++) {
        final sign = puz.hIneq[r][c];
        if (sign == 0) continue;
        totalIneq++;
        final idxA = r * size + c;
        final idxB = r * size + (c + 1);
        final a = idxA < board.length ? board[idxA] : 0;
        final b = idxB < board.length ? board[idxB] : 0;
        if (a >= 1 && a <= size && b >= 1 && b <= size) {
          final ok = sign < 0 ? (a < b) : (a > b);
          if (ok) {
            satisfiedIneq++;
          } else {
            violatedH.add(r * (size - 1) + c);
            violatedCells.add(idxA);
            violatedCells.add(idxB);
          }
        }
      }
    }

    // Vertical inequalities
    for (var r = 0; r < size - 1; r++) {
      for (var c = 0; c < size; c++) {
        final sign = puz.vIneq[r][c];
        if (sign == 0) continue;
        totalIneq++;
        final idxA = r * size + c;
        final idxB = (r + 1) * size + c;
        final a = idxA < board.length ? board[idxA] : 0;
        final b = idxB < board.length ? board[idxB] : 0;
        if (a >= 1 && a <= size && b >= 1 && b <= size) {
          final ok = sign < 0 ? (a < b) : (a > b);
          if (ok) {
            satisfiedIneq++;
          } else {
            violatedV.add(r * size + c);
            violatedCells.add(idxA);
            violatedCells.add(idxB);
          }
        }
      }
    }

    return FutoshikiAnalysis(
      duplicateCells: duplicateCells,
      violatedCells: violatedCells,
      violatedH: violatedH,
      violatedV: violatedV,
      satisfiedIneq: satisfiedIneq,
      totalIneq: totalIneq,
      validLines: validLines,
      filledCount: filledCount,
    );
  }

  static bool isSolved(FutoshikiPuzzle puz, List<int> board) {
    final size = puz.size;
    if (board.length != size * size) return false;
    final an = analyze(puz, board);
    return an.filledCount == size * size &&
        an.validLines == 2 * size &&
        an.duplicateCells.isEmpty &&
        an.violatedCells.isEmpty &&
        an.satisfiedIneq == an.totalIneq;
  }

  /// Generates a guaranteed-valid Futoshiki puzzle for [size] (`4` or `5`).
  static FutoshikiPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;

    // 1. Construct a randomized Latin Square of `1..size`
    final rowPerm = [for (var i = 0; i < size; i++) i]..shuffle(rng);
    final colPerm = [for (var i = 0; i < size; i++) i]..shuffle(rng);
    final symPerm = [for (var i = 1; i <= size; i++) i]..shuffle(rng);

    final sol = List<int>.filled(n, 1);
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        sol[r * size + c] = symPerm[(rowPerm[r] + colPerm[c]) % size];
      }
    }

    // Perform extra random row/column swaps for variety
    for (var k = 0; k < size; k++) {
      final r1 = rng.nextInt(size), r2 = rng.nextInt(size);
      if (r1 != r2) {
        for (var c = 0; c < size; c++) {
          final tmp = sol[r1 * size + c];
          sol[r1 * size + c] = sol[r2 * size + c];
          sol[r2 * size + c] = tmp;
        }
      }
    }

    // 2. Expose a few fixed clue digits
    final clues = [
      for (var r = 0; r < size; r++) List<int>.filled(size, 0),
    ];
    final targetClues = size <= 4 ? 3 : 5;
    final cellOrder = [for (var i = 0; i < n; i++) i]..shuffle(rng);
    for (var i = 0; i < targetClues && i < cellOrder.length; i++) {
      final idx = cellOrder[i];
      final r = idx ~/ size, c = idx % size;
      clues[r][c] = sol[idx];
    }

    // 3. Expose Horizontal and Vertical Inequality constraints
    final hIneq = [
      for (var r = 0; r < size; r++) List<int>.filled(size - 1, 0),
    ];
    final vIneq = [
      for (var r = 0; r < size - 1; r++) List<int>.filled(size, 0),
    ];

    final allEdges = <(bool, int, int)>[
      for (var r = 0; r < size; r++)
        for (var c = 0; c < size - 1; c++) (true, r, c),
      for (var r = 0; r < size - 1; r++)
        for (var c = 0; c < size; c++) (false, r, c),
    ]..shuffle(rng);

    final targetIneq = size <= 4 ? 6 : 10;
    for (var i = 0; i < targetIneq && i < allEdges.length; i++) {
      final (isH, r, c) = allEdges[i];
      if (isH) {
        final a = sol[r * size + c];
        final b = sol[r * size + (c + 1)];
        hIneq[r][c] = a < b ? -1 : 1;
      } else {
        final a = sol[r * size + c];
        final b = sol[(r + 1) * size + c];
        vIneq[r][c] = a < b ? -1 : 1;
      }
    }

    return FutoshikiPuzzle(
      size: size,
      clues: clues,
      hIneq: hIneq,
      vIneq: vIneq,
      solutionBoard: sol,
    );
  }
}

/// 不等号数独竞速 (Futoshiki Race, 1-6 人).
class FutoshikiGame extends GameEngine {
  FutoshikiGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late FutoshikiPuzzle currentPuzzle;
  late List<FutoshikiPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<List<int>> get boards => [for (final p in ps) p.board];
  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a10Placings(ranking, players) : null;

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
    final rawSize = setup.opt<int>('size', 4);
    size = rawSize == 5 ? 5 : 4;
    totalRounds = setup.opt<int>('rounds', 3) == 1 ? 1 : 3;

    currentPuzzle = FutoshikiSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) FutoshikiPlayer(currentPuzzle.cluesFlat)];

    host.log('不等号数独竞速开始（$size×$size 网格，共 $totalRounds 题）！填入 1～$size 使每行每列无重复且满足全部不等号！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = FutoshikiSolver.generatePuzzle(size, rng);
    }
    final cluesFlat = currentPuzzle.cluesFlat;
    for (var s = 0; s < players; s++) {
      ps[s].resetForRound(cluesFlat);
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
    return a10Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
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
      case 'toggle':
        final (r, c) = _resolveCell(a);
        if (currentPuzzle.clues[r][c] > 0) {
          throw GameError('题目固定数字不可修改');
        }
        final idx = r * size + c;
        if (a.containsKey('val')) {
          final v = asInt(a['val']);
          if (v < 0 || v > size) {
            throw GameError('数字必须在 0～$size 之间');
          }
          p.board[idx] = v;
        } else {
          p.board[idx] = (p.board[idx] + 1) % (size + 1);
        }
        moves++;
        if (FutoshikiSolver.isSolved(currentPuzzle, p.board)) {
          _markSolved(seat);
        }

      case 'clear':
      case 'reset':
        final cluesFlat = currentPuzzle.cluesFlat;
        for (var i = 0; i < p.board.length; i++) {
          p.board[i] = cluesFlat[i];
        }
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
    host.log('${name(seat)} 第 $roundSolvers 个解出不等号数独，+$pts 分！');
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
    ranking = a10Ranking(players, (a, b) {
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
    host.log('游戏结束（$why）！冠军：${a10Winners(ranking!, name)}');
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
        if (p.board[i] != sol[i]) i,
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
    final myBoard = me?.board ?? puz.cluesFlat;
    final an = FutoshikiSolver.analyze(puz, myBoard);
    final totalCells = size * size;

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
      'hIneq': puz.hIneq,
      'vIneq': puz.vIneq,
      'board': myBoard,
      'duplicates': an.duplicateCells.toList()..sort(),
      'violatedCells': an.violatedCells.toList()..sort(),
      'violatedH': an.violatedH.toList()..sort(),
      'violatedV': an.violatedV.toList()..sort(),
      'satisfiedIneq': an.satisfiedIneq,
      'totalIneq': an.totalIneq,
      'validLines': an.validLines,
      'totalLines': 2 * size,
      'filledCount': an.filledCount,
      'totalCells': totalCells,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = FutoshikiSolver.analyze(puz, ps[s].board);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'filled': pAn.filledCount,
              'totalCells': totalCells,
              'satisfiedIneq': pAn.satisfiedIneq,
              'totalIneq': pAn.totalIneq,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class FutoshikiPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  FutoshikiPlayer(List<int> initialClues) : board = List<int>.of(initialClues);

  void resetForRound(List<int> initialClues) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.of(initialClues);
  }
}
