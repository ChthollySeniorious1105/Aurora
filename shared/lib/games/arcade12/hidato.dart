import 'dart:math';

import '../../src/engine.dart';
import 'a12_util.dart';

class HidatoPuzzle {
  final int size;
  /// 2D `size × size` fixed anchor clues (`0` = empty, `1..size*size` = given number).
  final List<List<int>> clues;
  /// Flat `size * size` 8-way Hamiltonian path solution containing `1..size*size`.
  final List<int> solutionBoard;

  const HidatoPuzzle({
    required this.size,
    required this.clues,
    required this.solutionBoard,
  });

  List<int> get cluesFlat => [
        for (var r = 0; r < size; r++)
          for (var c = 0; c < size; c++) clues[r][c],
      ];
}

class HidatoAnalysis {
  final Set<int> duplicateCells;
  final Set<int> violatedClueCells;
  final Set<int> disconnectedCells;
  final List<List<int>> connectedLinks;
  final int validLinks;
  final int totalLinks;
  final int filledCount;
  final int nextMissing;

  const HidatoAnalysis({
    required this.duplicateCells,
    required this.violatedClueCells,
    required this.disconnectedCells,
    required this.connectedLinks,
    required this.validLinks,
    required this.totalLinks,
    required this.filledCount,
    required this.nextMissing,
  });

  Set<int> get conflictCells => {
        ...duplicateCells,
        ...violatedClueCells,
        ...disconnectedCells,
      };

  bool get isSolved =>
      filledCount == totalLinks + 1 &&
      duplicateCells.isEmpty &&
      violatedClueCells.isEmpty &&
      disconnectedCells.isEmpty &&
      validLinks == totalLinks;
}

class HidatoSolver {
  static const List<int> adj8Dr = [-1, -1, -1, 0, 0, 1, 1, 1];
  static const List<int> adj8Dc = [-1, 0, 1, -1, 1, -1, 0, 1];

  static bool isKingAdjacent(int idxA, int idxB, int size) {
    if (idxA == idxB) return false;
    final r1 = idxA ~/ size, c1 = idxA % size;
    final r2 = idxB ~/ size, c2 = idxB % size;
    return (r1 - r2).abs() <= 1 && (c1 - c2).abs() <= 1;
  }

  static HidatoAnalysis analyze(HidatoPuzzle puz, List<int> board) {
    final size = puz.size;
    final n = size * size;
    final duplicateCells = <int>{};
    final violatedClueCells = <int>{};
    final disconnectedCells = <int>{};
    final connectedLinks = <List<int>>[];

    final firstSeen = <int, int>{};
    final counts = List<int>.filled(n + 1, 0);
    var filledCount = 0;

    for (var i = 0; i < n; i++) {
      final v = i < board.length ? board[i] : 0;
      final r = i ~/ size, c = i % size;
      final fixed = puz.clues[r][c];
      if (fixed > 0 && v != fixed) {
        violatedClueCells.add(i);
      }
      if (v == 0) continue;
      if (v < 1 || v > n) {
        duplicateCells.add(i);
        continue;
      }
      filledCount++;
      counts[v]++;
      if (firstSeen.containsKey(v)) {
        duplicateCells.add(i);
        duplicateCells.add(firstSeen[v]!);
      } else {
        firstSeen[v] = i;
      }
    }

    for (var k = 1; k < n; k++) {
      if (counts[k] == 1 && counts[k + 1] == 1) {
        final idxA = firstSeen[k]!;
        final idxB = firstSeen[k + 1]!;
        if (isKingAdjacent(idxA, idxB, size)) {
          connectedLinks.add([idxA, idxB]);
        } else {
          disconnectedCells.add(idxA);
          disconnectedCells.add(idxB);
        }
      }
    }

    var nextMissing = 0;
    for (var k = 1; k <= n; k++) {
      if (counts[k] == 0) {
        nextMissing = k;
        break;
      }
    }

    return HidatoAnalysis(
      duplicateCells: duplicateCells,
      violatedClueCells: violatedClueCells,
      disconnectedCells: disconnectedCells,
      connectedLinks: connectedLinks,
      validLinks: connectedLinks.length,
      totalLinks: n - 1,
      filledCount: filledCount,
      nextMissing: nextMissing,
    );
  }

  static bool isSolved(HidatoPuzzle puz, List<int> board) {
    final n = puz.size * puz.size;
    if (board.length != n) return false;
    final an = analyze(puz, board);
    return an.isSolved;
  }

  /// Generates an 8-way Hamiltonian path of `1..size*size` using Warnsdorff's
  /// heuristic + bounded backtracking, with a guaranteed snake fallback.
  static List<int> _generateHamiltonianPath(int size, Random rng) {
    final n = size * size;
    final adj8 = List<List<int>>.generate(n, (idx) {
      final r = idx ~/ size, c = idx % size;
      final list = <int>[];
      for (var d = 0; d < 8; d++) {
        final nr = r + adj8Dr[d], nc = c + adj8Dc[d];
        if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
          list.add(nr * size + nc);
        }
      }
      return list;
    });

    for (var attempt = 0; attempt < 20; attempt++) {
      final board = List<int>.filled(n, 0);
      final start = rng.nextInt(n);
      board[start] = 1;
      var nodes = 0;

      int onwardDegree(int idx) {
        var deg = 0;
        for (final nb in adj8[idx]) {
          if (board[nb] == 0) deg++;
        }
        return deg;
      }

      bool dfs(int cur, int step) {
        if (step == n) return true;
        if (++nodes > 1200) return false;
        final candidates = <int>[
          for (final nb in adj8[cur])
            if (board[nb] == 0) nb,
        ];
        if (candidates.isEmpty) return false;
        candidates.shuffle(rng);
        candidates.sort((a, b) => onwardDegree(a).compareTo(onwardDegree(b)));
        for (final next in candidates) {
          board[next] = step + 1;
          if (dfs(next, step + 1)) return true;
          board[next] = 0;
          if (nodes > 1200) return false;
        }
        return false;
      }

      if (dfs(start, 1)) {
        return board;
      }
    }

    // Deterministic fallback: boustrophedon snake path with random symmetry
    final sol = List<int>.filled(n, 0);
    final flipR = rng.nextBool();
    final flipC = rng.nextBool();
    final transpose = rng.nextBool();
    var val = 1;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final cc = r.isEven ? c : (size - 1 - c);
        var rr = flipR ? (size - 1 - r) : r;
        var col = flipC ? (size - 1 - cc) : cc;
        if (transpose) {
          final tmp = rr;
          rr = col;
          col = tmp;
        }
        sol[rr * size + col] = val++;
      }
    }
    return sol;
  }

  /// Generates a guaranteed-valid Hidato puzzle for [size] (`4` or `5`).
  static HidatoPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    final sol = _generateHamiltonianPath(size, rng);
    final posOfVal = List<int>.filled(n + 1, 0);
    for (var i = 0; i < n; i++) {
      posOfVal[sol[i]] = i;
    }

    final clues = [
      for (var r = 0; r < size; r++) List<int>.filled(size, 0),
    ];

    void exposeVal(int v) {
      final idx = posOfVal[v];
      clues[idx ~/ size][idx % size] = v;
    }

    // Always expose 1 and N*N
    exposeVal(1);
    exposeVal(n);

    // Expose anchor numbers along the chain so every gap is at most 2..3 steps
    var cur = 1;
    while (cur < n - 2) {
      final step = 2 + rng.nextInt(2); // 2 or 3
      cur = (cur + step).clamp(2, n - 1);
      exposeVal(cur);
    }

    return HidatoPuzzle(
      size: size,
      clues: clues,
      solutionBoard: sol,
    );
  }
}

/// 数链寻路竞速 (Hidato Race, 1-6 人).
class HidatoGame extends GameEngine {
  HidatoGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late HidatoPuzzle currentPuzzle;
  late List<HidatoPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<List<int>> get boards => [for (final p in ps) p.board];
  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a12Placings(ranking, players) : null;

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

    currentPuzzle = HidatoSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) HidatoPlayer(currentPuzzle.cluesFlat)];

    host.log('数链寻路竞速开始（$size×$size 网格，共 $totalRounds 题）！填入 1～${size * size} 使相邻数字八方向连通！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = HidatoSolver.generatePuzzle(size, rng);
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
    return a12Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
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

    final maxVal = size * size;
    switch (type) {
      case 'set':
      case 'toggle':
        final (r, c) = _resolveCell(a);
        if (currentPuzzle.clues[r][c] > 0) {
          throw GameError('题目固定锚点数字不可修改');
        }
        final idx = r * size + c;
        if (a.containsKey('val')) {
          final v = asInt(a['val']);
          if (v < 0 || v > maxVal) {
            throw GameError('数字必须在 0～$maxVal 之间');
          }
          p.board[idx] = v;
        } else {
          final an = HidatoSolver.analyze(currentPuzzle, p.board);
          if (p.board[idx] == 0 && an.nextMissing > 0) {
            p.board[idx] = an.nextMissing;
          } else {
            p.board[idx] = (p.board[idx] + 1) % (maxVal + 1);
          }
        }
        moves++;
        if (HidatoSolver.isSolved(currentPuzzle, p.board)) {
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
    host.log('${name(seat)} 第 $roundSolvers 个解出数链寻路谜题，+$pts 分！');
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
    ranking = a12Ranking(players, (a, b) {
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
    host.log('游戏结束（$why）！冠军：${a12Winners(ranking!, name)}');
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
    final an = HidatoSolver.analyze(puz, myBoard);
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
      'board': myBoard,
      'duplicates': an.duplicateCells.toList()..sort(),
      'violatedClues': an.violatedClueCells.toList()..sort(),
      'disconnectedCells': an.disconnectedCells.toList()..sort(),
      'connectedLinks': an.connectedLinks,
      'validLinks': an.validLinks,
      'totalLinks': an.totalLinks,
      'filledCount': an.filledCount,
      'totalCells': totalCells,
      'nextMissing': an.nextMissing,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = HidatoSolver.analyze(puz, ps[s].board);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'filled': pAn.filledCount,
              'totalCells': totalCells,
              'validLinks': pAn.validLinks,
              'totalLinks': pAn.totalLinks,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class HidatoPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  HidatoPlayer(List<int> initialClues) : board = List<int>.of(initialClues);

  void resetForRound(List<int> initialClues) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.of(initialClues);
  }
}
