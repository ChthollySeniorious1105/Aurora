import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';
import 'a10_util.dart';

class MasyuPuzzle {
  final int size;
  /// `size × size` grid of pearls: `0` = empty, `1` = White Pearl (○), `2` = Black Pearl (●).
  final List<List<int>> pearls;
  /// `size × (size - 1)` horizontal segments (`0` or `1`).
  final List<List<int>> solutionHSegs;
  /// `(size - 1) × size` vertical segments (`0` or `1`).
  final List<List<int>> solutionVSegs;

  const MasyuPuzzle({
    required this.size,
    required this.pearls,
    required this.solutionHSegs,
    required this.solutionVSegs,
  });

  List<int> get pearlsFlat => [
        for (var r = 0; r < size; r++)
          for (var c = 0; c < size; c++) pearls[r][c],
      ];
}

class MasyuAnalysis {
  final int activeSegCount;
  final Set<int> badDegreeCells;
  final Set<int> satisfiedPearlCells;
  final Set<int> violatedPearlCells;
  final int totalPearls;
  final int visitedPearls;
  final int satisfiedPearls;
  final int componentCount;
  final bool isSingleLoop;

  const MasyuAnalysis({
    required this.activeSegCount,
    required this.badDegreeCells,
    required this.satisfiedPearlCells,
    required this.violatedPearlCells,
    required this.totalPearls,
    required this.visitedPearls,
    required this.satisfiedPearls,
    required this.componentCount,
    required this.isSingleLoop,
  });

  bool get isSolved =>
      isSingleLoop &&
      totalPearls > 0 &&
      visitedPearls == totalPearls &&
      satisfiedPearls == totalPearls &&
      violatedPearlCells.isEmpty;
}

class MasyuSolver {
  static MasyuAnalysis analyze(
    MasyuPuzzle puz,
    List<List<int>> hSegs,
    List<List<int>> vSegs,
  ) {
    final size = puz.size;
    final n = size * size;
    // Directions: 0 = Up, 1 = Right, 2 = Down, 3 = Left
    final dirs = [for (var i = 0; i < n; i++) <int>[]];
    final neighbors = [for (var i = 0; i < n; i++) <int>[]];

    var activeSegCount = 0;

    for (var r = 0; r < size; r++) {
      final row = r < hSegs.length ? hSegs[r] : const <int>[];
      for (var c = 0; c < size - 1; c++) {
        if (c < row.length && row[c] == 1) {
          activeSegCount++;
          final a = r * size + c;
          final b = r * size + (c + 1);
          dirs[a].add(1);
          neighbors[a].add(b);
          dirs[b].add(3);
          neighbors[b].add(a);
        }
      }
    }

    for (var r = 0; r < size - 1; r++) {
      final row = r < vSegs.length ? vSegs[r] : const <int>[];
      for (var c = 0; c < size; c++) {
        if (c < row.length && row[c] == 1) {
          activeSegCount++;
          final a = r * size + c;
          final b = (r + 1) * size + c;
          dirs[a].add(2);
          neighbors[a].add(b);
          dirs[b].add(0);
          neighbors[b].add(a);
        }
      }
    }

    final badDegreeCells = <int>{};
    for (var i = 0; i < n; i++) {
      final deg = dirs[i].length;
      if (deg > 0 && deg != 2) {
        badDegreeCells.add(i);
      }
    }

    // Connected components among cells with deg > 0
    final visited = List<bool>.filled(n, false);
    var componentCount = 0;
    for (var i = 0; i < n; i++) {
      if (dirs[i].isEmpty || visited[i]) continue;
      componentCount++;
      final q = Queue<int>()..add(i);
      visited[i] = true;
      while (q.isNotEmpty) {
        final cur = q.removeFirst();
        for (final nxt in neighbors[cur]) {
          if (!visited[nxt]) {
            visited[nxt] = true;
            q.add(nxt);
          }
        }
      }
    }

    final isSingleLoop =
        activeSegCount > 0 && badDegreeCells.isEmpty && componentCount == 1;

    bool isStraight(int idx) =>
        dirs[idx].length == 2 && (dirs[idx][0] - dirs[idx][1]).abs() == 2;
    bool isTurn(int idx) =>
        dirs[idx].length == 2 && (dirs[idx][0] - dirs[idx][1]).abs() != 2;

    var totalPearls = 0;
    var visitedPearls = 0;
    var satisfiedPearls = 0;
    final satisfiedPearlCells = <int>{};
    final violatedPearlCells = <int>{};

    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final pType = puz.pearls[r][c];
        if (pType == 0) continue;
        totalPearls++;
        final idx = r * size + c;
        final deg = dirs[idx].length;
        if (deg == 2) visitedPearls++;

        if (deg > 2) {
          violatedPearlCells.add(idx);
          continue;
        }
        if (deg < 2) continue;

        final n0 = neighbors[idx][0];
        final n1 = neighbors[idx][1];

        if (pType == 1) {
          // White pearl: must go straight at idx, and turn 90° in at least one neighbor
          if (!isStraight(idx)) {
            violatedPearlCells.add(idx);
          } else if (isTurn(n0) || isTurn(n1)) {
            satisfiedPearls++;
            satisfiedPearlCells.add(idx);
          } else if (dirs[n0].length == 2 &&
              dirs[n1].length == 2 &&
              isStraight(n0) &&
              isStraight(n1)) {
            violatedPearlCells.add(idx);
          }
        } else if (pType == 2) {
          // Black pearl: must turn 90° at idx, and go straight through BOTH neighbors
          if (!isTurn(idx)) {
            violatedPearlCells.add(idx);
          } else if (isStraight(n0) && isStraight(n1)) {
            satisfiedPearls++;
            satisfiedPearlCells.add(idx);
          } else if ((dirs[n0].length == 2 && isTurn(n0)) ||
              (dirs[n1].length == 2 && isTurn(n1))) {
            violatedPearlCells.add(idx);
          }
        }
      }
    }

    return MasyuAnalysis(
      activeSegCount: activeSegCount,
      badDegreeCells: badDegreeCells,
      satisfiedPearlCells: satisfiedPearlCells,
      violatedPearlCells: violatedPearlCells,
      totalPearls: totalPearls,
      visitedPearls: visitedPearls,
      satisfiedPearls: satisfiedPearls,
      componentCount: componentCount,
      isSingleLoop: isSingleLoop,
    );
  }

  static bool isSolved(
    MasyuPuzzle puz,
    List<List<int>> hSegs,
    List<List<int>> vSegs,
  ) =>
      analyze(puz, hSegs, vSegs).isSolved;

  static (List<List<int>>, List<List<int>>) _boundarySegmentsFromFaces(
    int size,
    List<List<bool>> faces,
  ) {
    final fSize = size - 1;
    final hSegs = [
      for (var r = 0; r < size; r++) List<int>.filled(size - 1, 0),
    ];
    final vSegs = [
      for (var r = 0; r < size - 1; r++) List<int>.filled(size, 0),
    ];

    bool faceAt(int fr, int fc) {
      if (fr < 0 || fr >= fSize || fc < 0 || fc >= fSize) return false;
      return faces[fr][fc];
    }

    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size - 1; c++) {
        if (faceAt(r - 1, c) != faceAt(r, c)) {
          hSegs[r][c] = 1;
        }
      }
    }

    for (var r = 0; r < size - 1; r++) {
      for (var c = 0; c < size; c++) {
        if (faceAt(r, c - 1) != faceAt(r, c)) {
          vSegs[r][c] = 1;
        }
      }
    }

    return (hSegs, vSegs);
  }

  static (List<int>, List<int>, bool) _classifyLoopPearls(
    int size,
    List<List<int>> hSegs,
    List<List<int>> vSegs,
  ) {
    final n = size * size;
    final dirs = [for (var i = 0; i < n; i++) <int>[]];
    final neighbors = [for (var i = 0; i < n; i++) <int>[]];
    var segCount = 0;

    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size - 1; c++) {
        if (hSegs[r][c] == 1) {
          segCount++;
          final a = r * size + c, b = r * size + (c + 1);
          dirs[a].add(1);
          neighbors[a].add(b);
          dirs[b].add(3);
          neighbors[b].add(a);
        }
      }
    }
    for (var r = 0; r < size - 1; r++) {
      for (var c = 0; c < size; c++) {
        if (vSegs[r][c] == 1) {
          segCount++;
          final a = r * size + c, b = (r + 1) * size + c;
          dirs[a].add(2);
          neighbors[a].add(b);
          dirs[b].add(0);
          neighbors[b].add(a);
        }
      }
    }

    if (segCount == 0) return (const [], const [], false);
    for (var i = 0; i < n; i++) {
      if (dirs[i].isNotEmpty && dirs[i].length != 2) {
        return (const [], const [], false);
      }
    }

    // Verify 1 connected component
    final start = dirs.indexWhere((d) => d.isNotEmpty);
    if (start < 0) return (const [], const [], false);
    final vis = List<bool>.filled(n, false);
    final q = Queue<int>()..add(start);
    vis[start] = true;
    var visitedNodes = 0;
    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      visitedNodes++;
      for (final nxt in neighbors[cur]) {
        if (!vis[nxt]) {
          vis[nxt] = true;
          q.add(nxt);
        }
      }
    }
    final totalActiveNodes = dirs.where((d) => d.isNotEmpty).length;
    if (visitedNodes != totalActiveNodes) {
      return (const [], const [], false);
    }

    bool isStraight(int idx) =>
        dirs[idx].length == 2 && (dirs[idx][0] - dirs[idx][1]).abs() == 2;
    bool isTurn(int idx) =>
        dirs[idx].length == 2 && (dirs[idx][0] - dirs[idx][1]).abs() != 2;

    final whiteEligible = <int>[];
    final blackEligible = <int>[];

    for (var i = 0; i < n; i++) {
      if (dirs[i].length != 2) continue;
      final n0 = neighbors[i][0];
      final n1 = neighbors[i][1];
      if (isStraight(i) && (isTurn(n0) || isTurn(n1))) {
        whiteEligible.add(i);
      } else if (isTurn(i) && isStraight(n0) && isStraight(n1)) {
        blackEligible.add(i);
      }
    }

    return (whiteEligible, blackEligible, true);
  }

  /// Generates a guaranteed-valid Masyu puzzle for [size] (`5` or `6`).
  static MasyuPuzzle generatePuzzle(int size, Random rng) {
    final fSize = size - 1;
    final faces = [
      for (var r = 0; r < fSize; r++) List<bool>.filled(fSize, true),
    ];

    // Carve random boundary indentations while preserving a single loop with
    // both White-eligible and Black-eligible pearl positions.
    final carveAttempts = size <= 5 ? 7 : 11;
    final targetCarves = size <= 5 ? (1 + rng.nextInt(3)) : (2 + rng.nextInt(4));
    var carved = 0;

    for (var step = 0; step < carveAttempts && carved < targetCarves; step++) {
      // Collect faces currently in `faces` that touch the outside
      final candidates = <(int, int)>[];
      for (var r = 0; r < fSize; r++) {
        for (var c = 0; c < fSize; c++) {
          if (!faces[r][c]) continue;
          final onBoundary = r == 0 ||
              r == fSize - 1 ||
              c == 0 ||
              c == fSize - 1 ||
              !faces[r - 1][c] ||
              !faces[r + 1][c] ||
              !faces[r][c - 1] ||
              !faces[r][c + 1];
          if (onBoundary) candidates.add((r, c));
        }
      }
      if (candidates.length <= 4) break;
      candidates.shuffle(rng);

      for (final (fr, fc) in candidates) {
        faces[fr][fc] = false;
        final (candH, candV) = _boundarySegmentsFromFaces(size, faces);
        final (whites, blacks, validLoop) =
            _classifyLoopPearls(size, candH, candV);
        if (validLoop && whites.length >= 2 && blacks.isNotEmpty) {
          carved++;
          break;
        } else {
          faces[fr][fc] = true;
        }
      }
    }

    final (solH, solV) = _boundarySegmentsFromFaces(size, faces);
    final (whitePool, blackPool, _) = _classifyLoopPearls(size, solH, solV);

    whitePool.shuffle(rng);
    blackPool.shuffle(rng);

    final pearls = [
      for (var r = 0; r < size; r++) List<int>.filled(size, 0),
    ];

    final keepBlack = blackPool.length.clamp(1, size <= 5 ? 3 : 4);
    for (var i = 0; i < keepBlack && i < blackPool.length; i++) {
      final idx = blackPool[i];
      pearls[idx ~/ size][idx % size] = 2;
    }

    final keepWhite = whitePool.length.clamp(2, size <= 5 ? 4 : 6);
    for (var i = 0; i < keepWhite && i < whitePool.length; i++) {
      final idx = whitePool[i];
      pearls[idx ~/ size][idx % size] = 1;
    }

    return MasyuPuzzle(
      size: size,
      pearls: pearls,
      solutionHSegs: solH,
      solutionVSegs: solV,
    );
  }
}

/// 黑白珍珠回路竞速 (Masyu Race, 1-6 人).
class MasyuGame extends GameEngine {
  MasyuGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late MasyuPuzzle currentPuzzle;
  late List<MasyuPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a10Placings(ranking, players) : null;

  @override
  bool get canResign => !over;

  @override
  int get botDelayMs => switch (botLevel) { 0 => 760, 2 => 220, _ => 400 };

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

    currentPuzzle = MasyuSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) MasyuPlayer(size)];

    host.log('黑白珍珠回路竞速开始（$size×$size 网格，共 $totalRounds 题）！白珍珠直行邻转弯，黑珍珠转弯双邻直行！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = MasyuSolver.generatePuzzle(size, rng);
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
    return a10Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
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
      case 'seg':
      case 'toggle':
        final dir = asStr(a['dir'], 'h');
        final r = asInt(a['r']);
        final c = asInt(a['c']);
        if (dir == 'h') {
          if (r < 0 || r >= size || c < 0 || c >= size - 1) {
            throw GameError('水平线段坐标超出棋盘范围');
          }
          if (a.containsKey('val')) {
            p.hSegs[r][c] = asInt(a['val']) != 0 ? 1 : 0;
          } else {
            p.hSegs[r][c] = p.hSegs[r][c] == 1 ? 0 : 1;
          }
        } else if (dir == 'v') {
          if (r < 0 || r >= size - 1 || c < 0 || c >= size) {
            throw GameError('垂直线段坐标超出棋盘范围');
          }
          if (a.containsKey('val')) {
            p.vSegs[r][c] = asInt(a['val']) != 0 ? 1 : 0;
          } else {
            p.vSegs[r][c] = p.vSegs[r][c] == 1 ? 0 : 1;
          }
        } else {
          throw GameError('线段方向必须为 h 或 v');
        }
        moves++;
        if (MasyuSolver.isSolved(currentPuzzle, p.hSegs, p.vSegs)) {
          _markSolved(seat);
        }

      case 'clear':
      case 'reset':
        p.clearSegs();
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
    host.log('${name(seat)} 第 $roundSolvers 个连通黑白珍珠回路，+$pts 分！');
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
    final solH = currentPuzzle.solutionHSegs;
    final solV = currentPuzzle.solutionVSegs;

    if (botLevel <= 0 && rng.nextInt(18) == 0) {
      return {'type': 'pass'};
    }

    final diffs = <(String, int, int)>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size - 1; c++) {
        if (p.hSegs[r][c] != solH[r][c]) {
          diffs.add(('h', r, c));
        }
      }
    }
    for (var r = 0; r < size - 1; r++) {
      for (var c = 0; c < size; c++) {
        if (p.vSegs[r][c] != solV[r][c]) {
          diffs.add(('v', r, c));
        }
      }
    }

    if (diffs.isNotEmpty) {
      final (dir, r, c) = diffs[rng.nextInt(diffs.length)];
      return {
        'type': 'seg',
        'dir': dir,
        'r': r,
        'c': c,
      };
    }

    return {'type': 'pass'};
  }

  // ---------------------------------------------------------------- view

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players ? ps[seat] : (ps.isNotEmpty ? ps[0] : null);
    final puz = currentPuzzle;
    final myH = me?.hSegs ??
        [for (var r = 0; r < size; r++) List<int>.filled(size - 1, 0)];
    final myV = me?.vSegs ??
        [for (var r = 0; r < size - 1; r++) List<int>.filled(size, 0)];
    final an = MasyuSolver.analyze(puz, myH, myV);

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'pearls': puz.pearls,
      'pearlsFlat': puz.pearlsFlat,
      'hSegs': myH,
      'vSegs': myV,
      'activeSegCount': an.activeSegCount,
      'badDegreeCells': an.badDegreeCells.toList()..sort(),
      'satisfiedPearlCells': an.satisfiedPearlCells.toList()..sort(),
      'violatedPearlCells': an.violatedPearlCells.toList()..sort(),
      'totalPearls': an.totalPearls,
      'visitedPearls': an.visitedPearls,
      'satisfiedPearls': an.satisfiedPearls,
      'isSingleLoop': an.isSingleLoop,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = MasyuSolver.analyze(puz, ps[s].hSegs, ps[s].vSegs);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'satisfiedPearls': pAn.satisfiedPearls,
              'totalPearls': pAn.totalPearls,
              'isSingleLoop': pAn.isSingleLoop,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class MasyuPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  late List<List<int>> hSegs;
  late List<List<int>> vSegs;

  MasyuPlayer(int size) {
    resetForRound(size);
  }

  void clearSegs() {
    for (final row in hSegs) {
      row.fillRange(0, row.length, 0);
    }
    for (final row in vSegs) {
      row.fillRange(0, row.length, 0);
    }
  }

  void resetForRound(int size) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    hSegs = [for (var r = 0; r < size; r++) List<int>.filled(size - 1, 0)];
    vSegs = [for (var r = 0; r < size - 1; r++) List<int>.filled(size, 0)];
  }
}
