import 'dart:math';

import '../../src/engine.dart';
import 'a9_util.dart';

class TentsPuzzle {
  final int size;
  /// `true` if cell `r * size + c` contains a Tree (`🌲`).
  final List<bool> isTree;
  /// Sorted indices of all Trees on the board.
  final List<int> treeIndices;
  /// Required Tent count for each row `0..size-1`.
  final List<int> rowClues;
  /// Required Tent count for each column `0..size-1`.
  final List<int> colClues;
  /// Valid solution board (`1` for Tent, `0` otherwise).
  final List<int> solutionBoard;

  const TentsPuzzle({
    required this.size,
    required this.isTree,
    required this.treeIndices,
    required this.rowClues,
    required this.colClues,
    required this.solutionBoard,
  });
}

class TentsAnalysis {
  final List<int> rowCounts;
  final List<int> colCounts;
  final Set<int> touchingTents;
  final Set<int> orphanTents;
  final Set<int> conflictCells;
  final int matchedPairs;
  final int totalTrees;
  final int tentCount;
  final int satisfiedLines;
  final int totalLines;

  const TentsAnalysis({
    required this.rowCounts,
    required this.colCounts,
    required this.touchingTents,
    required this.orphanTents,
    required this.conflictCells,
    required this.matchedPairs,
    required this.totalTrees,
    required this.tentCount,
    required this.satisfiedLines,
    required this.totalLines,
  });

  bool get isSolved =>
      totalTrees > 0 &&
      satisfiedLines == totalLines &&
      touchingTents.isEmpty &&
      tentCount == totalTrees &&
      matchedPairs == totalTrees;
}

class TentsSolver {
  static const List<int> dr4 = [-1, 0, 1, 0];
  static const List<int> dc4 = [0, 1, 0, -1];

  /// Computes maximum 1-to-1 bipartite matching size between [tents] and [trees]
  /// where an edge exists iff a Tent is orthogonally adjacent to a Tree.
  static int maxMatching(List<int> tents, List<int> trees, int size) {
    final m = tents.length;
    final k = trees.length;
    if (m == 0 || k == 0) return 0;

    final adj = List<List<int>>.generate(m, (_) => <int>[]);
    for (var u = 0; u < m; u++) {
      final ru = tents[u] ~/ size, cu = tents[u] % size;
      for (var v = 0; v < k; v++) {
        final rv = trees[v] ~/ size, cv = trees[v] % size;
        if ((ru - rv).abs() + (cu - cv).abs() == 1) {
          adj[u].add(v);
        }
      }
    }

    final matchTree = List<int>.filled(k, -1);

    bool dfs(int u, List<bool> visited) {
      for (final v in adj[u]) {
        if (visited[v]) continue;
        visited[v] = true;
        if (matchTree[v] == -1 || dfs(matchTree[v], visited)) {
          matchTree[v] = u;
          return true;
        }
      }
      return false;
    }

    var matched = 0;
    for (var u = 0; u < m; u++) {
      final visited = List<bool>.filled(k, false);
      if (dfs(u, visited)) matched++;
    }
    return matched;
  }

  static TentsAnalysis analyze(TentsPuzzle puz, List<int> marks) {
    final size = puz.size;
    final n = size * size;
    final rowCounts = List<int>.filled(size, 0);
    final colCounts = List<int>.filled(size, 0);
    final tents = <int>[];

    for (var i = 0; i < n; i++) {
      if (puz.isTree[i]) continue;
      final m = i < marks.length ? marks[i] : 0;
      if (m == 1) {
        final r = i ~/ size, c = i % size;
        rowCounts[r]++;
        colCounts[c]++;
        tents.add(i);
      }
    }

    final touchingTents = <int>{};
    for (var i = 0; i < tents.length; i++) {
      final r1 = tents[i] ~/ size, c1 = tents[i] % size;
      for (var j = i + 1; j < tents.length; j++) {
        final r2 = tents[j] ~/ size, c2 = tents[j] % size;
        if ((r1 - r2).abs() <= 1 && (c1 - c2).abs() <= 1) {
          touchingTents.add(tents[i]);
          touchingTents.add(tents[j]);
        }
      }
    }

    final orphanTents = <int>{};
    for (final tIdx in tents) {
      final r = tIdx ~/ size, c = tIdx % size;
      var hasAdjTree = false;
      for (var d = 0; d < 4; d++) {
        final nr = r + dr4[d], nc = c + dc4[d];
        if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
          if (puz.isTree[nr * size + nc]) {
            hasAdjTree = true;
            break;
          }
        }
      }
      if (!hasAdjTree) orphanTents.add(tIdx);
    }

    final conflictCells = <int>{...touchingTents, ...orphanTents};
    for (final tIdx in tents) {
      final r = tIdx ~/ size, c = tIdx % size;
      if (rowCounts[r] > puz.rowClues[r] || colCounts[c] > puz.colClues[c]) {
        conflictCells.add(tIdx);
      }
    }

    var satisfiedLines = 0;
    for (var i = 0; i < size; i++) {
      if (rowCounts[i] == puz.rowClues[i]) satisfiedLines++;
      if (colCounts[i] == puz.colClues[i]) satisfiedLines++;
    }

    final matchedPairs = maxMatching(tents, puz.treeIndices, size);

    return TentsAnalysis(
      rowCounts: rowCounts,
      colCounts: colCounts,
      touchingTents: touchingTents,
      orphanTents: orphanTents,
      conflictCells: conflictCells,
      matchedPairs: matchedPairs,
      totalTrees: puz.treeIndices.length,
      tentCount: tents.length,
      satisfiedLines: satisfiedLines,
      totalLines: 2 * size,
    );
  }

  static bool isSolved(TentsPuzzle puz, List<int> marks) {
    if (marks.length != puz.size * puz.size) return false;
    return analyze(puz, marks).isSolved;
  }

  /// Generates a 100% guaranteed-valid Tents & Trees puzzle for [size] (`5` or `6`).
  static TentsPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    final targetPairs = size <= 5 ? 5 : 7;
    final minPairs = size <= 5 ? 4 : 5;

    for (var attempt = 0; attempt < 30; attempt++) {
      final solBoard = List<int>.filled(n, 0);
      final isTree = List<bool>.filled(n, false);
      final candidates = [for (var i = 0; i < n; i++) i]..shuffle(rng);
      var pairs = 0;

      for (final idx in candidates) {
        if (pairs >= targetPairs) break;
        if (solBoard[idx] != 0 || isTree[idx]) continue;
        final r = idx ~/ size, c = idx % size;

        // Check no 8-way adjacent Tent
        var adjTent = false;
        for (var dr = -1; dr <= 1 && !adjTent; dr++) {
          for (var dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            final nr = r + dr, nc = c + dc;
            if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
              if (solBoard[nr * size + nc] == 1) {
                adjTent = true;
                break;
              }
            }
          }
        }
        if (adjTent) continue;

        // Find available orthogonally adjacent cell for the paired Tree
        final dirs = [0, 1, 2, 3]..shuffle(rng);
        var treeIdx = -1;
        for (final d in dirs) {
          final nr = r + dr4[d], nc = c + dc4[d];
          if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
          final nIdx = nr * size + nc;
          if (solBoard[nIdx] == 0 && !isTree[nIdx]) {
            treeIdx = nIdx;
            break;
          }
        }
        if (treeIdx == -1) continue;

        solBoard[idx] = 1;
        isTree[treeIdx] = true;
        pairs++;
      }

      if (pairs >= minPairs) {
        final rowClues = List<int>.filled(size, 0);
        final colClues = List<int>.filled(size, 0);
        final treeIndices = <int>[];
        for (var i = 0; i < n; i++) {
          if (solBoard[i] == 1) {
            rowClues[i ~/ size]++;
            colClues[i % size]++;
          }
          if (isTree[i]) {
            treeIndices.add(i);
          }
        }
        return TentsPuzzle(
          size: size,
          isTree: isTree,
          treeIndices: treeIndices,
          rowClues: rowClues,
          colClues: colClues,
          solutionBoard: solBoard,
        );
      }
    }

    // Deterministic fallback
    final solBoard = List<int>.filled(n, 0);
    final isTree = List<bool>.filled(n, false);
    final rowClues = List<int>.filled(size, 0);
    final colClues = List<int>.filled(size, 0);
    final treeIndices = <int>[];
    for (var r = 0; r < size; r += 2) {
      for (var c = 0; c + 1 < size; c += 2) {
        final tentIdx = r * size + c;
        final treeIdx = r * size + c + 1;
        solBoard[tentIdx] = 1;
        isTree[treeIdx] = true;
        treeIndices.add(treeIdx);
        rowClues[r]++;
        colClues[c]++;
      }
    }
    return TentsPuzzle(
      size: size,
      isTree: isTree,
      treeIndices: treeIndices,
      rowClues: rowClues,
      colClues: colClues,
      solutionBoard: solBoard,
    );
  }
}

/// 帐篷露营竞速 (Tents & Trees Race, 1-6 人).
class TentsGame extends GameEngine {
  TentsGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late TentsPuzzle currentPuzzle;
  late List<TentsPlayer> ps;
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
    final rawSize = setup.opt<int>('size', 5);
    size = rawSize == 6 ? 6 : 5;
    totalRounds = setup.opt<int>('rounds', 3) == 1 ? 1 : 3;

    currentPuzzle = TentsSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) TentsPlayer(size * size)];

    host.log('帐篷露营竞速开始（$size×$size 网格，共 $totalRounds 题）！按行列线索为每棵树配对正交相邻帐篷且八向不接触！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = TentsSolver.generatePuzzle(size, rng);
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

  int _resolveNonTreeCellIndex(Map<String, dynamic> a) {
    int idx;
    if (a.containsKey('r') && a.containsKey('c')) {
      final r = asInt(a['r']);
      final c = asInt(a['c']);
      if (r < 0 || r >= size || c < 0 || c >= size) {
        throw GameError('行列坐标超出棋盘范围');
      }
      idx = r * size + c;
    } else {
      idx = asInt(a['i']);
      if (idx < 0 || idx >= size * size) {
        throw GameError('格子索引超出棋盘范围');
      }
    }
    if (currentPuzzle.isTree[idx]) {
      throw GameError('树木格不能放置帐篷或草地');
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
        final idx = _resolveNonTreeCellIndex(a);
        if (a.containsKey('val')) {
          final v = asInt(a['val']);
          if (v < 0 || v > 2) throw GameError('状态值必须为 0、1 或 2');
          p.marks[idx] = v;
        } else {
          p.marks[idx] = (p.marks[idx] + 1) % 3;
        }
        moves++;
        if (TentsSolver.isSolved(currentPuzzle, p.marks)) {
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
    host.log('${name(seat)} 第 $roundSolvers 个完成帐篷露营配对，+$pts 分！');
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

    // First remove any misplaced Tent
    for (var i = 0; i < sol.length; i++) {
      if (!currentPuzzle.isTree[i] && p.marks[i] == 1 && sol[i] != 1) {
        return {'type': 'toggle', 'r': i ~/ size, 'c': i % size};
      }
    }

    // Then place a missing solution Tent
    final missing = <int>[
      for (var i = 0; i < sol.length; i++)
        if (!currentPuzzle.isTree[i] && sol[i] == 1 && p.marks[i] != 1) i,
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
    final analysis = TentsSolver.analyze(puz, myMarks);

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'isTree': puz.isTree,
      'trees': puz.treeIndices,
      'rowClues': puz.rowClues,
      'colClues': puz.colClues,
      'marks': myMarks,
      'rowCounts': analysis.rowCounts,
      'colCounts': analysis.colCounts,
      'conflicts': analysis.conflictCells.toList()..sort(),
      'touching': analysis.touchingTents.toList()..sort(),
      'orphans': analysis.orphanTents.toList()..sort(),
      'matchedPairs': analysis.matchedPairs,
      'totalTrees': max(1, analysis.totalTrees),
      'tentCount': analysis.tentCount,
      'satisfiedLines': analysis.satisfiedLines,
      'totalLines': analysis.totalLines,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = TentsSolver.analyze(puz, ps[s].marks);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'matched': pAn.matchedPairs,
              'totalTrees': max(1, pAn.totalTrees),
              'satisfied': pAn.satisfiedLines,
              'totalLines': pAn.totalLines,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class TentsPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> marks;

  TentsPlayer(int cellCount) : marks = List<int>.filled(cellCount, 0);

  void resetForRound(int cellCount) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    marks = List<int>.filled(cellCount, 0);
  }
}
