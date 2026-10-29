import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';
import 'a15_util.dart';

class KurottoPuzzle {
  final int size;
  /// `size × size` grid of circled clues (`>= 0` for clue cells, `-1` for non-clue cells).
  final List<List<int>> clues;
  /// Flat `size * size` solution (`0` = White, `1` = Black `■`).
  final List<int> solutionBoard;

  const KurottoPuzzle({
    required this.size,
    required this.clues,
    required this.solutionBoard,
  });

  List<int> get cluesFlat => [
        for (var r = 0; r < size; r++)
          for (var c = 0; c < size; c++) clues[r][c],
      ];

  List<int> get initialBoard => List<int>.filled(size * size, 0);
}

class KurottoAnalysis {
  final Set<int> satisfiedClues;
  final Set<int> violatedClues;
  final Set<int> pendingClues;
  /// Flat `size * size` list of touching distinct Black-cluster size sums for each cell.
  final List<int> clueClusterSums;
  /// Flat `size * size` list where each Black cell holds the size of its orthogonally
  /// connected Black component (`0` for non-Black cells).
  final List<int> clusterSizes;
  final int totalClues;
  final int blackCount;
  final int dotCount;

  const KurottoAnalysis({
    required this.satisfiedClues,
    required this.violatedClues,
    required this.pendingClues,
    required this.clueClusterSums,
    required this.clusterSizes,
    required this.totalClues,
    required this.blackCount,
    required this.dotCount,
  });

  bool get isSolved =>
      totalClues > 0 &&
      satisfiedClues.length == totalClues &&
      violatedClues.isEmpty &&
      pendingClues.isEmpty;
}

class KurottoSolver {
  static const List<int> orthoDr = [-1, 0, 1, 0];
  static const List<int> orthoDc = [0, 1, 0, -1];

  static bool isBlack(List<int> board, int idx) =>
      idx >= 0 && idx < board.length && board[idx] == 1;

  /// Computes the orthogonal Black (`== 1`) connected components on [board],
  /// returning `(compId, compSizes)` where `compId[idx]` is the component index
  /// (`-1` if not Black) and `compSizes[cId]` is the size of component `cId`.
  static (List<int>, List<int>) computeBlackClusters(int size, List<int> board) {
    final n = size * size;
    final compId = List<int>.filled(n, -1);
    final compSizes = <int>[];

    for (var start = 0; start < n; start++) {
      if (!isBlack(board, start) || compId[start] != -1) continue;
      final cId = compSizes.length;
      final q = Queue<int>()..add(start);
      compId[start] = cId;
      var sz = 0;
      while (q.isNotEmpty) {
        final cur = q.removeFirst();
        sz++;
        final r = cur ~/ size, c = cur % size;
        for (var d = 0; d < 4; d++) {
          final nr = r + orthoDr[d], nc = c + orthoDc[d];
          if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
          final nxt = nr * size + nc;
          if (compId[nxt] == -1 && isBlack(board, nxt)) {
            compId[nxt] = cId;
            q.add(nxt);
          }
        }
      }
      compSizes.add(sz);
    }

    return (compId, compSizes);
  }

  /// Computes the exact sum of sizes of all distinct orthogonally connected
  /// Black components touching cell `(r, c)`.
  static int touchingBlackClusterSum(
    int size,
    List<int> compId,
    List<int> compSizes,
    int r,
    int c,
  ) {
    final touchingComps = <int>{};
    for (var d = 0; d < 4; d++) {
      final nr = r + orthoDr[d], nc = c + orthoDc[d];
      if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
      final cid = compId[nr * size + nc];
      if (cid >= 0) touchingComps.add(cid);
    }
    var sum = 0;
    for (final cid in touchingComps) {
      sum += compSizes[cid];
    }
    return sum;
  }

  static KurottoAnalysis analyze(KurottoPuzzle puz, List<int> board) {
    final size = puz.size;
    final n = size * size;

    final satisfiedClues = <int>{};
    final violatedClues = <int>{};
    final pendingClues = <int>{};

    var totalClues = 0;
    var blackCount = 0;
    var dotCount = 0;

    // Treat any clue cell as non-Black if someone passes an arbitrary board
    final cleanBoard = List<int>.generate(n, (i) {
      final r = i ~/ size, c = i % size;
      final v = i < board.length ? board[i] : 0;
      if (puz.clues[r][c] >= 0) return 0;
      return v;
    });

    for (var i = 0; i < n; i++) {
      final v = cleanBoard[i];
      if (v == 1) {
        blackCount++;
      } else if (v == 2) {
        dotCount++;
      }
    }

    final (compId, compSizes) = computeBlackClusters(size, cleanBoard);
    final clusterSizes = List<int>.generate(
      n,
      (i) => compId[i] >= 0 ? compSizes[compId[i]] : 0,
    );
    final clueClusterSums = List<int>.filled(n, 0);

    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final idx = r * size + c;
        final sum = touchingBlackClusterSum(size, compId, compSizes, r, c);
        clueClusterSums[idx] = sum;

        final clue = puz.clues[r][c];
        if (clue < 0) continue;
        totalClues++;
        if (idx < board.length && board[idx] == 1) {
          violatedClues.add(idx);
        } else if (sum == clue) {
          satisfiedClues.add(idx);
        } else if (sum > clue) {
          violatedClues.add(idx);
        } else {
          pendingClues.add(idx);
        }
      }
    }

    return KurottoAnalysis(
      satisfiedClues: satisfiedClues,
      violatedClues: violatedClues,
      pendingClues: pendingClues,
      clueClusterSums: clueClusterSums,
      clusterSizes: clusterSizes,
      totalClues: totalClues,
      blackCount: blackCount,
      dotCount: dotCount,
    );
  }

  static bool isSolved(KurottoPuzzle puz, List<int> board) {
    if (board.length != puz.size * puz.size) return false;
    return analyze(puz, board).isSolved;
  }

  /// Generates a guaranteed-valid Kurotto puzzle for [size] (`5` or `6`).
  static KurottoPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    final targetBlacks = size <= 5 ? (9 + rng.nextInt(4)) : (13 + rng.nextInt(5));

    for (var attempt = 0; attempt < 40; attempt++) {
      final sol = List<int>.filled(n, 0);
      final order = [for (var i = 0; i < n; i++) i]..shuffle(rng);
      var placed = 0;

      for (final idx in order) {
        if (placed >= targetBlacks) break;
        sol[idx] = 1;
        final (_, compSizes) = computeBlackClusters(size, sol);
        // Keep individual Black clusters to a fun size (1..6 cells)
        if (compSizes.any((sz) => sz > 6)) {
          sol[idx] = 0;
        } else {
          placed++;
        }
      }

      final (compId, compSizes) = computeBlackClusters(size, sol);
      if (compSizes.isEmpty) continue;

      final whiteCells = <int>[
        for (var i = 0; i < n; i++)
          if (sol[i] == 0) i,
      ]..shuffle(rng);
      if (whiteCells.length < 6) continue;

      final clues = [
        for (var r = 0; r < size; r++) List<int>.filled(size, -1),
      ];

      final coveredComps = <int>{};
      var clueCount = 0;
      var positiveClues = 0;
      final targetClues = size <= 5 ? 9 : 13;

      // First ensure every Black cluster touches at least one circled clue cell
      for (final idx in whiteCells) {
        final r = idx ~/ size, c = idx % size;
        final adjComps = <int>{};
        for (var d = 0; d < 4; d++) {
          final nr = r + orthoDr[d], nc = c + orthoDc[d];
          if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
            final cid = compId[nr * size + nc];
            if (cid >= 0) adjComps.add(cid);
          }
        }
        if (adjComps.any((cid) => !coveredComps.contains(cid))) {
          final sum = touchingBlackClusterSum(size, compId, compSizes, r, c);
          clues[r][c] = sum;
          coveredComps.addAll(adjComps);
          clueCount++;
          if (sum > 0) positiveClues++;
        }
      }

      if (coveredComps.length < compSizes.length) continue;

      // Add additional clue cells up to targetClues while leaving plenty of non-clue cells
      for (final idx in whiteCells) {
        if (clueCount >= targetClues) break;
        final r = idx ~/ size, c = idx % size;
        if (clues[r][c] >= 0) continue;
        final sum = touchingBlackClusterSum(size, compId, compSizes, r, c);
        clues[r][c] = sum;
        clueCount++;
        if (sum > 0) positiveClues++;
      }

      if (positiveClues < 3) continue;

      final puz = KurottoPuzzle(
        size: size,
        clues: clues,
        solutionBoard: sol,
      );
      if (isSolved(puz, sol) && !isSolved(puz, puz.initialBoard)) {
        return puz;
      }
    }

    // Deterministic fallback
    final sol = List<int>.filled(n, 0);
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if ((r + c) % 3 == 1) {
          sol[r * size + c] = 1;
        }
      }
    }
    final (compId, compSizes) = computeBlackClusters(size, sol);
    final clues = [
      for (var r = 0; r < size; r++) List<int>.filled(size, -1),
    ];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (sol[r * size + c] == 0 && (r + c).isEven) {
          clues[r][c] = touchingBlackClusterSum(size, compId, compSizes, r, c);
        }
      }
    }
    return KurottoPuzzle(
      size: size,
      clues: clues,
      solutionBoard: sol,
    );
  }
}

/// 黑格邻群计数竞速 (Kurotto Race, 1-6 人).
class KurottoGame extends GameEngine {
  KurottoGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late KurottoPuzzle currentPuzzle;
  late List<KurottoPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<List<int>> get boards => [for (final p in ps) p.board];
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

    currentPuzzle = KurottoSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) KurottoPlayer(size * size)];

    host.log('黑格邻群计数竞速开始（$size×$size 网格，共 $totalRounds 题）！使每个圆圈格相邻的不同黑格连通群总面积精确等于线索数字！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = KurottoSolver.generatePuzzle(size, rng);
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
    return a15Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
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
        if (currentPuzzle.clues[r][c] >= 0) {
          throw GameError('圆圈线索格不能涂黑');
        }
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
        if (KurottoSolver.isSolved(currentPuzzle, p.board)) {
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
    host.log('${name(seat)} 第 $roundSolvers 个解出黑格邻群计数谜题，+$pts 分！');
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
    final sol = puz.solutionBoard;

    if (botLevel <= 0 && rng.nextInt(15) == 0) {
      return {'type': 'pass'};
    }

    final diff = <int>[
      for (var i = 0; i < sol.length; i++)
        if (puz.clues[i ~/ size][i % size] < 0 && (p.board[i] == 1) != (sol[i] == 1)) i,
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
    final an = KurottoSolver.analyze(puz, myBoard);
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
      'totalClues': an.totalClues,
      'board': myBoard,
      'clueClusterSums': an.clueClusterSums,
      'clusterSizes': an.clusterSizes,
      'satisfiedClues': an.satisfiedClues.toList()..sort(),
      'violatedClues': an.violatedClues.toList()..sort(),
      'pendingClues': an.pendingClues.toList()..sort(),
      'satisfiedClueCount': an.satisfiedClues.length,
      'blackCount': an.blackCount,
      'dotCount': an.dotCount,
      'totalCells': totalCells,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = KurottoSolver.analyze(puz, ps[s].board);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'satisfiedClues': pAn.satisfiedClues.length,
              'totalClues': pAn.totalClues,
              'blackCount': pAn.blackCount,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class KurottoPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  KurottoPlayer(int cellCount) : board = List<int>.filled(cellCount, 0);

  void resetForRound(int cellCount) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.filled(cellCount, 0);
  }
}
