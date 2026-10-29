import 'dart:math';

import '../../src/engine.dart';
import 'a12_util.dart';

class KuromasuPuzzle {
  final int size;
  /// 2D `size × size` line-of-sight clues (`0` = no clue, `> 0` = visible White cell count).
  final List<List<int>> clues;
  /// Flat `size * size` solution (`0` = White, `1` = Black `■`).
  final List<int> solutionBoard;

  const KuromasuPuzzle({
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

class KuromasuAnalysis {
  final Set<int> satisfiedClues;
  final Set<int> violatedClues;
  final Set<int> adjacentBlackCells;
  final Set<int> isolatedWhiteCells;
  final List<int> visibleCounts;
  final int totalClues;
  final int blackCount;
  final int dotCount;
  final bool whiteConnected;

  const KuromasuAnalysis({
    required this.satisfiedClues,
    required this.violatedClues,
    required this.adjacentBlackCells,
    required this.isolatedWhiteCells,
    required this.visibleCounts,
    required this.totalClues,
    required this.blackCount,
    required this.dotCount,
    required this.whiteConnected,
  });

  Set<int> get conflictCells => {
        ...violatedClues,
        ...adjacentBlackCells,
        ...isolatedWhiteCells,
      };

  bool get isSolved =>
      totalClues > 0 &&
      satisfiedClues.length == totalClues &&
      violatedClues.isEmpty &&
      adjacentBlackCells.isEmpty &&
      whiteConnected;
}

class KuromasuSolver {
  static const List<int> orthoDr = [-1, 0, 1, 0];
  static const List<int> orthoDc = [0, 1, 0, -1];

  static bool isBlack(List<int> board, int idx) =>
      idx >= 0 && idx < board.length && board[idx] == 1;

  /// Counts the number of White (`!= 1`) cells visible in the 4 orthogonal rays
  /// from `(r, c)`, including `(r, c)` itself, stopping at Black (`== 1`) cells
  /// or grid borders.
  static int visibleWhiteCount(int size, List<int> board, int r, int c) {
    final startIdx = r * size + c;
    if (isBlack(board, startIdx)) return 0;
    var count = 1;
    for (var d = 0; d < 4; d++) {
      var nr = r + orthoDr[d];
      var nc = c + orthoDc[d];
      while (nr >= 0 && nr < size && nc >= 0 && nc < size) {
        if (isBlack(board, nr * size + nc)) break;
        count++;
        nr += orthoDr[d];
        nc += orthoDc[d];
      }
    }
    return count;
  }

  static KuromasuAnalysis analyze(KuromasuPuzzle puz, List<int> board) {
    final size = puz.size;
    final n = size * size;
    final satisfiedClues = <int>{};
    final violatedClues = <int>{};
    final adjacentBlackCells = <int>{};
    final isolatedWhiteCells = <int>{};
    final visibleCounts = List<int>.filled(n, 0);

    var totalClues = 0;
    var blackCount = 0;
    var dotCount = 0;

    for (var i = 0; i < n; i++) {
      final v = i < board.length ? board[i] : 0;
      if (v == 1) {
        blackCount++;
      } else if (v == 2) {
        dotCount++;
      }
    }

    // 1. Check orthogonal adjacency of Black cells
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final idx = r * size + c;
        if (!isBlack(board, idx)) continue;
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

    // 2. Check White cell orthogonal connectivity
    final visited = List<bool>.filled(n, false);
    final components = <List<int>>[];
    for (var i = 0; i < n; i++) {
      if (visited[i] || isBlack(board, i)) continue;
      final comp = <int>[i];
      visited[i] = true;
      var head = 0;
      while (head < comp.length) {
        final cur = comp[head++];
        final r = cur ~/ size, c = cur % size;
        for (var d = 0; d < 4; d++) {
          final nr = r + orthoDr[d], nc = c + orthoDc[d];
          if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
          final nIdx = nr * size + nc;
          if (!visited[nIdx] && !isBlack(board, nIdx)) {
            visited[nIdx] = true;
            comp.add(nIdx);
          }
        }
      }
      components.add(comp);
    }

    if (components.length > 1) {
      components.sort((a, b) => b.length.compareTo(a.length));
      for (var k = 1; k < components.length; k++) {
        isolatedWhiteCells.addAll(components[k]);
      }
    }
    final whiteConnected = components.length == 1;

    // 3. Check each numbered clue cell
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final clue = puz.clues[r][c];
        if (clue <= 0) continue;
        totalClues++;
        final idx = r * size + c;
        final vis = visibleWhiteCount(size, board, r, c);
        visibleCounts[idx] = vis;
        if (!isBlack(board, idx) && vis == clue) {
          satisfiedClues.add(idx);
        } else {
          violatedClues.add(idx);
        }
      }
    }

    return KuromasuAnalysis(
      satisfiedClues: satisfiedClues,
      violatedClues: violatedClues,
      adjacentBlackCells: adjacentBlackCells,
      isolatedWhiteCells: isolatedWhiteCells,
      visibleCounts: visibleCounts,
      totalClues: totalClues,
      blackCount: blackCount,
      dotCount: dotCount,
      whiteConnected: whiteConnected,
    );
  }

  static bool isSolved(KuromasuPuzzle puz, List<int> board) {
    final n = puz.size * puz.size;
    if (board.length != n) return false;
    return analyze(puz, board).isSolved;
  }

  static bool _isWhiteConnected(int size, List<int> board) {
    final n = size * size;
    var firstWhite = -1;
    var totalWhite = 0;
    for (var i = 0; i < n; i++) {
      if (board[i] != 1) {
        totalWhite++;
        if (firstWhite < 0) firstWhite = i;
      }
    }
    if (totalWhite == 0) return false;
    final visited = List<bool>.filled(n, false);
    final q = <int>[firstWhite];
    visited[firstWhite] = true;
    var head = 0;
    while (head < q.length) {
      final cur = q[head++];
      final r = cur ~/ size, c = cur % size;
      for (var d = 0; d < 4; d++) {
        final nr = r + orthoDr[d], nc = c + orthoDc[d];
        if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
        final nIdx = nr * size + nc;
        if (!visited[nIdx] && board[nIdx] != 1) {
          visited[nIdx] = true;
          q.add(nIdx);
        }
      }
    }
    return q.length == totalWhite;
  }

  /// Generates a guaranteed-valid Kuromasu puzzle for [size] (`5` or `6`).
  static KuromasuPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    final sol = List<int>.filled(n, 0);
    final targetBlack = size <= 5 ? 5 : 7;
    final candidates = [for (var i = 0; i < n; i++) i]..shuffle(rng);

    var placedBlack = 0;
    for (final idx in candidates) {
      if (placedBlack >= targetBlack) break;
      final r = idx ~/ size, c = idx % size;
      var adjBlack = false;
      for (var d = 0; d < 4; d++) {
        final nr = r + orthoDr[d], nc = c + orthoDc[d];
        if (nr >= 0 && nr < size && nc >= 0 && nc < size && sol[nr * size + nc] == 1) {
          adjBlack = true;
          break;
        }
      }
      if (adjBlack) continue;

      sol[idx] = 1;
      if (_isWhiteConnected(size, sol)) {
        placedBlack++;
      } else {
        sol[idx] = 0;
      }
    }

    // Fallback if somehow no black cell was placed
    if (placedBlack == 0) {
      sol[0] = 1;
      sol[size - 1] = 1;
    }

    final clues = [
      for (var r = 0; r < size; r++) List<int>.filled(size, 0),
    ];

    // Ensure every Black cell has at least one adjacent White cell exposed as a clue
    // (this guarantees the initial all-White board is never already solved).
    for (var i = 0; i < n; i++) {
      if (sol[i] != 1) continue;
      final r = i ~/ size, c = i % size;
      final whiteNbs = <int>[];
      for (var d = 0; d < 4; d++) {
        final nr = r + orthoDr[d], nc = c + orthoDc[d];
        if (nr >= 0 && nr < size && nc >= 0 && nc < size && sol[nr * size + nc] == 0) {
          whiteNbs.add(nr * size + nc);
        }
      }
      if (whiteNbs.isNotEmpty) {
        final pick = whiteNbs[rng.nextInt(whiteNbs.length)];
        final pr = pick ~/ size, pc = pick % size;
        clues[pr][pc] = visibleWhiteCount(size, sol, pr, pc);
      }
    }

    // Expose a couple more White cells up to a balanced clue count
    final targetClues = size <= 5 ? 7 : 10;
    var currentClues = 0;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (clues[r][c] > 0) currentClues++;
      }
    }

    final whiteOrder = [
      for (var i = 0; i < n; i++)
        if (sol[i] == 0 && clues[i ~/ size][i % size] == 0) i,
    ]..shuffle(rng);

    for (final idx in whiteOrder) {
      if (currentClues >= targetClues) break;
      final r = idx ~/ size, c = idx % size;
      clues[r][c] = visibleWhiteCount(size, sol, r, c);
      currentClues++;
    }

    return KuromasuPuzzle(
      size: size,
      clues: clues,
      solutionBoard: sol,
    );
  }
}

/// 黑格视线竞速 (Kuromasu Race, 1-6 人).
class KuromasuGame extends GameEngine {
  KuromasuGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late KuromasuPuzzle currentPuzzle;
  late List<KuromasuPlayer> ps;
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
    final rawSize = setup.opt<int>('size', 5);
    size = rawSize == 6 ? 6 : 5;
    totalRounds = setup.opt<int>('rounds', 3) == 1 ? 1 : 3;

    currentPuzzle = KuromasuSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) KuromasuPlayer(size * size)];

    host.log('黑格视线竞速开始（$size×$size 网格，共 $totalRounds 题）！涂黑方格使四向白格视线数匹配、黑格禁邻且白格全连通！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = KuromasuSolver.generatePuzzle(size, rng);
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

    switch (type) {
      case 'toggle':
      case 'set':
        final (r, c) = _resolveCell(a);
        if (currentPuzzle.clues[r][c] > 0) {
          throw GameError('题目视线数字格不可涂黑或修改');
        }
        final idx = r * size + c;
        if (a.containsKey('val')) {
          final v = asInt(a['val']);
          if (v < 0 || v > 2) {
            throw GameError('格子状态必须在 0～2 之间');
          }
          p.board[idx] = v;
        } else {
          p.board[idx] = (p.board[idx] + 1) % 3;
        }
        moves++;
        if (KuromasuSolver.isSolved(currentPuzzle, p.board)) {
          _markSolved(seat);
        }

      case 'clear':
      case 'reset':
        for (var i = 0; i < p.board.length; i++) {
          p.board[i] = 0;
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
    host.log('${name(seat)} 第 $roundSolvers 个解出黑格视线谜题，+$pts 分！');
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
    final an = KuromasuSolver.analyze(puz, myBoard);
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
      'visibleCounts': an.visibleCounts,
      'satisfiedClues': an.satisfiedClues.toList()..sort(),
      'violatedClues': an.violatedClues.toList()..sort(),
      'adjacentBlacks': an.adjacentBlackCells.toList()..sort(),
      'isolatedWhites': an.isolatedWhiteCells.toList()..sort(),
      'satisfiedClueCount': an.satisfiedClues.length,
      'totalClues': an.totalClues,
      'blackCount': an.blackCount,
      'dotCount': an.dotCount,
      'whiteConnected': an.whiteConnected,
      'totalCells': totalCells,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = KuromasuSolver.analyze(puz, ps[s].board);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'satisfiedClues': pAn.satisfiedClues.length,
              'totalClues': pAn.totalClues,
              'blackCount': pAn.blackCount,
              'totalCells': totalCells,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class KuromasuPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  KuromasuPlayer(int cellCount) : board = List<int>.filled(cellCount, 0);

  void resetForRound(int cellCount) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.filled(cellCount, 0);
  }
}
