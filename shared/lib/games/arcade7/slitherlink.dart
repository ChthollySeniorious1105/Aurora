import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';
import 'a7_util.dart';

class SlitherlinkPuzzle {
  final int size;
  /// `-1`: unnumbered cell, `0..3`: clue number of active edges around cell `(r, c)`.
  final List<int> clues;
  /// `(size + 1) * size` horizontal edges (`0` or `1`) in the generated solution loop.
  final List<int> solutionHEdges;
  /// `size * (size + 1)` vertical edges (`0` or `1`) in the generated solution loop.
  final List<int> solutionVEdges;

  const SlitherlinkPuzzle({
    required this.size,
    required this.clues,
    required this.solutionHEdges,
    required this.solutionVEdges,
  });
}

class SlitherlinkAnalysis {
  final int activeEdges;
  final List<int> vertexDegrees;
  final Set<int> badVertices;
  final int loopComponents;
  final bool isSingleLoop;
  final List<bool> cellOk;
  final int okClues;
  final int totalClues;

  const SlitherlinkAnalysis({
    required this.activeEdges,
    required this.vertexDegrees,
    required this.badVertices,
    required this.loopComponents,
    required this.isSingleLoop,
    required this.cellOk,
    required this.okClues,
    required this.totalClues,
  });

  bool get isSolved => isSingleLoop && okClues == totalClues;
}

class SlitherlinkSolver {
  static const List<int> dr = [-1, 0, 1, 0];
  static const List<int> dc = [0, 1, 0, -1];

  static int hIndex(int size, int r, int c) => r * size + c;
  static int vIndex(int size, int r, int c) => r * (size + 1) + c;

  /// Counts active (`1`) surrounding edges of cell `(r, c)`.
  static int cellEdgeCount(List<int> hEdges, List<int> vEdges, int size, int r, int c) {
    var count = 0;
    if (hEdges[r * size + c] == 1) count++;
    if (hEdges[(r + 1) * size + c] == 1) count++;
    if (vEdges[r * (size + 1) + c] == 1) count++;
    if (vEdges[r * (size + 1) + (c + 1)] == 1) count++;
    return count;
  }

  /// Computes degree of every vertex `(vr, vc)` in `0..size` × `0..size`.
  static List<int> computeVertexDegrees(List<int> hEdges, List<int> vEdges, int size) {
    final vSide = size + 1;
    final deg = List<int>.filled(vSide * vSide, 0);

    for (var r = 0; r <= size; r++) {
      for (var c = 0; c < size; c++) {
        if (hEdges[r * size + c] == 1) {
          deg[r * vSide + c]++;
          deg[r * vSide + (c + 1)]++;
        }
      }
    }
    for (var r = 0; r < size; r++) {
      for (var c = 0; c <= size; c++) {
        if (vEdges[r * vSide + c] == 1) {
          deg[r * vSide + c]++;
          deg[(r + 1) * vSide + c]++;
        }
      }
    }
    return deg;
  }

  /// Analyzes loop validity and cell clue satisfaction.
  static SlitherlinkAnalysis analyze(
    List<int> clues,
    List<int> hEdges,
    List<int> vEdges,
    int size,
  ) {
    final vSide = size + 1;
    final vCount = vSide * vSide;
    final deg = computeVertexDegrees(hEdges, vEdges, size);

    var activeEdges = 0;
    for (final e in hEdges) {
      if (e == 1) activeEdges++;
    }
    for (final e in vEdges) {
      if (e == 1) activeEdges++;
    }

    final badVertices = <int>{};
    for (var v = 0; v < vCount; v++) {
      if (deg[v] != 0 && deg[v] != 2) {
        badVertices.add(v);
      }
    }

    // Build vertex adjacency for active edges to count connected components
    final adj = [for (var v = 0; v < vCount; v++) <int>[]];
    for (var r = 0; r <= size; r++) {
      for (var c = 0; c < size; c++) {
        if (hEdges[r * size + c] == 1) {
          final u = r * vSide + c;
          final w = r * vSide + (c + 1);
          adj[u].add(w);
          adj[w].add(u);
        }
      }
    }
    for (var r = 0; r < size; r++) {
      for (var c = 0; c <= size; c++) {
        if (vEdges[r * vSide + c] == 1) {
          final u = r * vSide + c;
          final w = (r + 1) * vSide + c;
          adj[u].add(w);
          adj[w].add(u);
        }
      }
    }

    var loopComponents = 0;
    final visited = List<bool>.filled(vCount, false);
    for (var v = 0; v < vCount; v++) {
      if (deg[v] > 0 && !visited[v]) {
        loopComponents++;
        final q = Queue<int>()..add(v);
        visited[v] = true;
        while (q.isNotEmpty) {
          final cur = q.removeFirst();
          for (final nxt in adj[cur]) {
            if (!visited[nxt]) {
              visited[nxt] = true;
              q.add(nxt);
            }
          }
        }
      }
    }

    final isSingleLoop = activeEdges >= 4 && badVertices.isEmpty && loopComponents == 1;

    final cellOk = <bool>[];
    var okClues = 0;
    var totalClues = 0;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final clue = clues[r * size + c];
        if (clue >= 0) {
          totalClues++;
          final ok = cellEdgeCount(hEdges, vEdges, size, r, c) == clue;
          cellOk.add(ok);
          if (ok) okClues++;
        } else {
          cellOk.add(true);
        }
      }
    }

    return SlitherlinkAnalysis(
      activeEdges: activeEdges,
      vertexDegrees: deg,
      badVertices: badVertices,
      loopComponents: loopComponents,
      isSingleLoop: isSingleLoop,
      cellOk: cellOk,
      okClues: okClues,
      totalClues: totalClues,
    );
  }

  /// Returns true if:
  /// 1. Every numbered cell `(r, c)` has exact count of active (`1`) surrounding edges == its clue,
  /// 2. Every vertex with any active edge has degree == 2, and
  /// 3. All active edges form a single connected loop!
  static bool isSolved(
    List<int> clues,
    List<int> hEdges,
    List<int> vEdges,
    int size,
  ) {
    if (clues.length != size * size) return false;
    if (hEdges.length != (size + 1) * size) return false;
    if (vEdges.length != size * (size + 1)) return false;
    return analyze(clues, hEdges, vEdges, size).isSolved;
  }

  static (List<int>, List<int>) _boundaryEdgesFromRegion(List<bool> inRegion, int size) {
    final hEdges = List<int>.filled((size + 1) * size, 0);
    final vEdges = List<int>.filled(size * (size + 1), 0);

    for (var r = 0; r <= size; r++) {
      for (var c = 0; c < size; c++) {
        final topIn = r > 0 && inRegion[(r - 1) * size + c];
        final botIn = r < size && inRegion[r * size + c];
        if (topIn != botIn) {
          hEdges[r * size + c] = 1;
        }
      }
    }
    for (var r = 0; r < size; r++) {
      for (var c = 0; c <= size; c++) {
        final leftIn = c > 0 && inRegion[r * size + (c - 1)];
        final rightIn = c < size && inRegion[r * size + c];
        if (leftIn != rightIn) {
          vEdges[r * (size + 1) + c] = 1;
        }
      }
    }
    return (hEdges, vEdges);
  }

  /// Generates a 100% guaranteed-valid Slitherlink puzzle for [size] (`5` or `6`).
  static SlitherlinkPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    final emptyClues = List<int>.filled(n, -1);
    final targetCells = (n * 0.44).round() + rng.nextInt(max(2, (n * 0.16).round()));

    final inRegion = List<bool>.filled(n, false);
    final startR = 1 + rng.nextInt(max(1, size - 2));
    final startC = 1 + rng.nextInt(max(1, size - 2));
    inRegion[startR * size + startC] = true;
    var regionCount = 1;

    for (var step = 0; step < n * 3 && regionCount < targetCells; step++) {
      final frontier = <int>[];
      for (var i = 0; i < n; i++) {
        if (inRegion[i]) continue;
        final r = i ~/ size, c = i % size;
        for (var d = 0; d < 4; d++) {
          final nr = r + dr[d], nc = c + dc[d];
          if (nr >= 0 && nr < size && nc >= 0 && nc < size && inRegion[nr * size + nc]) {
            frontier.add(i);
            break;
          }
        }
      }
      if (frontier.isEmpty) break;
      frontier.shuffle(rng);

      var added = false;
      for (final cand in frontier) {
        inRegion[cand] = true;
        final (h, v) = _boundaryEdgesFromRegion(inRegion, size);
        if (analyze(emptyClues, h, v, size).isSingleLoop) {
          regionCount++;
          added = true;
          break;
        } else {
          inRegion[cand] = false;
        }
      }
      if (!added) break;
    }

    final (solH, solV) = _boundaryEdgesFromRegion(inRegion, size);
    final clues = List<int>.filled(n, -1);
    var clueCount = 0;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final idx = r * size + c;
        final edges = cellEdgeCount(solH, solV, size, r, c);
        // Expose ~72% of cells as clues, prioritizing cells with 1..3 edges
        final prob = edges > 0 ? 0.78 : 0.55;
        if (rng.nextDouble() < prob || clueCount < size) {
          clues[idx] = edges;
          clueCount++;
        }
      }
    }

    return SlitherlinkPuzzle(
      size: size,
      clues: clues,
      solutionHEdges: solH,
      solutionVEdges: solV,
    );
  }
}

/// 数圈竞速 (Slitherlink Race, 1-6 人).
class SlitherlinkGame extends GameEngine {
  SlitherlinkGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late SlitherlinkPuzzle currentPuzzle;
  late List<SlitherlinkPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a7Placings(ranking, players) : null;

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

    currentPuzzle = SlitherlinkSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) SlitherlinkPlayer(size)];

    host.log('数圈竞速开始（$size×$size 网格，共 $totalRounds 题）！连成唯一无分叉闭合环且满足四周边数线索即可过关！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = SlitherlinkSolver.generatePuzzle(size, rng);
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
    return a7Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
  }

  (bool, int) _resolveEdge(Map<String, dynamic> a) {
    final dir = asStr(a['dir']).toLowerCase();
    final r = asInt(a['r']);
    final c = asInt(a['c']);
    if (dir == 'h') {
      if (r < 0 || r > size || c < 0 || c >= size) {
        throw GameError('水平边坐标超出范围');
      }
      return (true, r * size + c);
    } else if (dir == 'v') {
      if (r < 0 || r >= size || c < 0 || c > size) {
        throw GameError('垂直边坐标超出范围');
      }
      return (false, r * (size + 1) + c);
    } else {
      throw GameError('边方向 dir 必须为 h 或 v');
    }
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
      case 'set_edge':
        final (isHoriz, idx) = _resolveEdge(a);
        final list = isHoriz ? p.hEdges : p.vEdges;
        final cur = list[idx];
        if (type == 'set_edge' || a.containsKey('val')) {
          final val = asInt(a['val']);
          if (val < 0 || val > 2) {
            throw GameError('边状态值必须为 0、1 或 2');
          }
          list[idx] = val;
        } else if (a.containsKey('mode')) {
          final mode = asInt(a['mode'], 1) == 2 ? 2 : 1;
          list[idx] = cur == mode ? 0 : mode;
        } else {
          list[idx] = (cur + 1) % 3;
        }
        moves++;
        if (SlitherlinkSolver.isSolved(currentPuzzle.clues, p.hEdges, p.vEdges, size)) {
          _markSolved(seat);
        }

      case 'clear':
      case 'reset':
        p.hEdges.fillRange(0, p.hEdges.length, 0);
        p.vEdges.fillRange(0, p.vEdges.length, 0);
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
    host.log('${name(seat)} 第 $roundSolvers 个连成闭合数圈，+$pts 分！');
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
    ranking = a7Ranking(players, (a, b) {
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
    host.log('游戏结束（$why）！冠军：${a7Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || !_activeInRound(seat)) return null;
    final p = ps[seat];
    final solH = currentPuzzle.solutionHEdges;
    final solV = currentPuzzle.solutionVEdges;

    final anyMarked = p.hEdges.any((e) => e != 0) || p.vEdges.any((e) => e != 0);
    if (botLevel <= 0 && !anyMarked && rng.nextInt(8) == 0) {
      return {'type': 'pass'};
    }

    // First remove any wrong active edge
    for (var i = 0; i < p.hEdges.length; i++) {
      if (p.hEdges[i] == 1 && solH[i] != 1) {
        return {'type': 'edge', 'dir': 'h', 'r': i ~/ size, 'c': i % size, 'val': 2};
      }
    }
    for (var i = 0; i < p.vEdges.length; i++) {
      if (p.vEdges[i] == 1 && solV[i] != 1) {
        return {'type': 'edge', 'dir': 'v', 'r': i ~/ (size + 1), 'c': i % (size + 1), 'val': 2};
      }
    }

    // Add a missing solution edge
    final missing = <(String, int, int)>[];
    for (var i = 0; i < solH.length; i++) {
      if (solH[i] == 1 && p.hEdges[i] != 1) {
        missing.add(('h', i ~/ size, i % size));
      }
    }
    for (var i = 0; i < solV.length; i++) {
      if (solV[i] == 1 && p.vEdges[i] != 1) {
        missing.add(('v', i ~/ (size + 1), i % (size + 1)));
      }
    }

    if (missing.isNotEmpty) {
      final pick = missing[rng.nextInt(missing.length)];
      return {'type': 'edge', 'dir': pick.$1, 'r': pick.$2, 'c': pick.$3, 'val': 1};
    }

    return {'type': 'pass'};
  }

  // ---------------------------------------------------------------- view

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players ? ps[seat] : (ps.isNotEmpty ? ps[0] : null);
    final clues = currentPuzzle.clues;
    final myH = me?.hEdges ?? List<int>.filled((size + 1) * size, 0);
    final myV = me?.vEdges ?? List<int>.filled(size * (size + 1), 0);
    final analysis = SlitherlinkSolver.analyze(clues, myH, myV, size);

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'clues': clues,
      'hEdges': myH,
      'vEdges': myV,
      'badVertices': analysis.badVertices.toList()..sort(),
      'loopComponents': analysis.loopComponents,
      'isSingleLoop': analysis.isSingleLoop,
      'cellOk': analysis.cellOk,
      'okClues': analysis.okClues,
      'totalClues': max(1, analysis.totalClues),
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = SlitherlinkSolver.analyze(clues, ps[s].hEdges, ps[s].vEdges, size);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'okClues': pAn.okClues,
              'totalClues': max(1, pAn.totalClues),
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class SlitherlinkPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> hEdges;
  List<int> vEdges;

  SlitherlinkPlayer(int size)
      : hEdges = List<int>.filled((size + 1) * size, 0),
        vEdges = List<int>.filled(size * (size + 1), 0);

  void resetForRound(int size) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    hEdges = List<int>.filled((size + 1) * size, 0);
    vEdges = List<int>.filled(size * (size + 1), 0);
  }
}
