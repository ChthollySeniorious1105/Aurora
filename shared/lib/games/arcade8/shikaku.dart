import 'dart:math';

import '../../src/engine.dart';
import 'a8_util.dart';

class ShikakuRect {
  final int r1;
  final int c1;
  final int r2;
  final int c2;

  const ShikakuRect(this.r1, this.c1, this.r2, this.c2);

  factory ShikakuRect.normalized(int aR1, int aC1, int aR2, int aC2) => ShikakuRect(
        min(aR1, aR2),
        min(aC1, aC2),
        max(aR1, aR2),
        max(aC1, aC2),
      );

  int get width => c2 - c1 + 1;
  int get height => r2 - r1 + 1;
  int get area => width * height;

  bool containsCell(int r, int c) => r >= r1 && r <= r2 && c >= c1 && c <= c2;

  bool overlaps(ShikakuRect other) =>
      !(r2 < other.r1 || r1 > other.r2 || c2 < other.c1 || c1 > other.c2);

  Map<String, dynamic> toJson({bool ok = false, int clueCount = 0, int clueVal = 0}) => {
        'r1': r1,
        'c1': c1,
        'r2': r2,
        'c2': c2,
        'area': area,
        'ok': ok,
        'clueCount': clueCount,
        'clueVal': clueVal,
      };

  @override
  bool operator ==(Object other) =>
      other is ShikakuRect &&
      other.r1 == r1 &&
      other.c1 == c1 &&
      other.r2 == r2 &&
      other.c2 == c2;

  @override
  int get hashCode => Object.hash(r1, c1, r2, c2);
}

class ShikakuPuzzle {
  final int size;
  /// `0`: non-clue cell, `>0`: rectangle area clue.
  final List<int> clues;
  final List<ShikakuRect> solutionRects;

  const ShikakuPuzzle({
    required this.size,
    required this.clues,
    required this.solutionRects,
  });
}

class ShikakuAnalysis {
  final int coveredCount;
  final bool hasOverlap;
  final List<bool> rectOk;
  final List<int> rectClueCounts;
  final List<int> rectClueVals;
  final Map<int, bool> clueOk;
  final int okRects;
  final int totalClues;
  final int totalCells;

  const ShikakuAnalysis({
    required this.coveredCount,
    required this.hasOverlap,
    required this.rectOk,
    required this.rectClueCounts,
    required this.rectClueVals,
    required this.clueOk,
    required this.okRects,
    required this.totalClues,
    required this.totalCells,
  });

  bool get isSolved =>
      !hasOverlap &&
      coveredCount == totalCells &&
      totalClues > 0 &&
      rectOk.length == totalClues &&
      okRects == totalClues;
}

class ShikakuSolver {
  static ShikakuAnalysis analyze(List<int> clues, List<ShikakuRect> rects, int size) {
    final n = size * size;
    final coverCount = List<int>.filled(n, 0);
    var hasOverlap = false;

    final clueOk = <int, bool>{};
    var totalClues = 0;
    for (var i = 0; i < n; i++) {
      if (i < clues.length && clues[i] > 0) {
        totalClues++;
        clueOk[i] = false;
      }
    }

    final rectOk = <bool>[];
    final rectClueCounts = <int>[];
    final rectClueVals = <int>[];
    var okRects = 0;

    for (final rect in rects) {
      if (rect.r1 < 0 ||
          rect.c1 < 0 ||
          rect.r2 >= size ||
          rect.c2 >= size ||
          rect.r1 > rect.r2 ||
          rect.c1 > rect.c2) {
        hasOverlap = true;
        rectOk.add(false);
        rectClueCounts.add(0);
        rectClueVals.add(0);
        continue;
      }

      var cCount = 0;
      var cIdx = -1;
      var cVal = 0;
      for (var r = rect.r1; r <= rect.r2; r++) {
        for (var c = rect.c1; c <= rect.c2; c++) {
          final idx = r * size + c;
          coverCount[idx]++;
          if (coverCount[idx] > 1) hasOverlap = true;
          if (idx < clues.length && clues[idx] > 0) {
            cCount++;
            cIdx = idx;
            cVal = clues[idx];
          }
        }
      }

      final ok = cCount == 1 && cVal == rect.area;
      rectOk.add(ok);
      rectClueCounts.add(cCount);
      rectClueVals.add(cVal);
      if (ok && cIdx >= 0) {
        clueOk[cIdx] = true;
        okRects++;
      }
    }

    var coveredCells = 0;
    for (final c in coverCount) {
      if (c > 0) coveredCells++;
    }

    return ShikakuAnalysis(
      coveredCount: coveredCells,
      hasOverlap: hasOverlap,
      rectOk: rectOk,
      rectClueCounts: rectClueCounts,
      rectClueVals: rectClueVals,
      clueOk: clueOk,
      okRects: okRects,
      totalClues: totalClues,
      totalCells: n,
    );
  }

  static bool isSolved(List<int> clues, List<ShikakuRect> rects, int size) {
    if (clues.length != size * size) return false;
    return analyze(clues, rects, size).isSolved;
  }

  static bool _hasIsolatedUncoveredCell(List<bool> used, int size) {
    const dr = [-1, 0, 1, 0];
    const dc = [0, 1, 0, -1];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (used[r * size + c]) continue;
        var freeNeighbors = 0;
        for (var d = 0; d < 4; d++) {
          final nr = r + dr[d], nc = c + dc[d];
          if (nr >= 0 && nr < size && nc >= 0 && nc < size && !used[nr * size + nc]) {
            freeNeighbors++;
            break;
          }
        }
        if (freeNeighbors == 0) return true;
      }
    }
    return false;
  }

  static bool _tileGrid(
    List<bool> used,
    int size,
    Random rng,
    List<ShikakuRect> out,
  ) {
    final firstFree = used.indexOf(false);
    if (firstFree < 0) return true;

    final r1 = firstFree ~/ size;
    final c1 = firstFree % size;

    final candidates = <ShikakuRect>[];
    for (var r2 = r1; r2 < size; r2++) {
      for (var c2 = c1; c2 < size; c2++) {
        final area = (r2 - r1 + 1) * (c2 - c1 + 1);
        if (area < 2 || area > 8) continue;
        var fits = true;
        for (var r = r1; r <= r2 && fits; r++) {
          for (var c = c1; c <= c2; c++) {
            if (used[r * size + c]) {
              fits = false;
              break;
            }
          }
        }
        if (fits) {
          candidates.add(ShikakuRect(r1, c1, r2, c2));
        }
      }
    }
    candidates.shuffle(rng);

    for (final rect in candidates) {
      for (var r = rect.r1; r <= rect.r2; r++) {
        for (var c = rect.c1; c <= rect.c2; c++) {
          used[r * size + c] = true;
        }
      }
      if (!_hasIsolatedUncoveredCell(used, size)) {
        out.add(rect);
        if (_tileGrid(used, size, rng, out)) return true;
        out.removeLast();
      }
      for (var r = rect.r1; r <= rect.r2; r++) {
        for (var c = rect.c1; c <= rect.c2; c++) {
          used[r * size + c] = false;
        }
      }
    }
    return false;
  }

  /// Generates a 100% guaranteed-valid Shikaku puzzle for [size] (`5` or `6`).
  static ShikakuPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    for (var attempt = 0; attempt < 25; attempt++) {
      final used = List<bool>.filled(n, false);
      final rects = <ShikakuRect>[];
      if (_tileGrid(used, size, rng, rects) && rects.length >= (size <= 5 ? 6 : 8)) {
        final clues = List<int>.filled(n, 0);
        for (final rect in rects) {
          final cells = <int>[
            for (var r = rect.r1; r <= rect.r2; r++)
              for (var c = rect.c1; c <= rect.c2; c++) r * size + c,
          ];
          final pick = cells[rng.nextInt(cells.length)];
          clues[pick] = rect.area;
        }
        if (isSolved(clues, rects, size)) {
          return ShikakuPuzzle(size: size, clues: clues, solutionRects: rects);
        }
      }
    }

    // Deterministic fallback partition
    final fallbackRects = size <= 5
        ? const [
            ShikakuRect(0, 0, 0, 2),
            ShikakuRect(0, 3, 1, 4),
            ShikakuRect(1, 0, 2, 1),
            ShikakuRect(1, 2, 3, 2),
            ShikakuRect(2, 3, 3, 4),
            ShikakuRect(3, 0, 4, 1),
            ShikakuRect(4, 2, 4, 4),
          ]
        : const [
            ShikakuRect(0, 0, 1, 1),
            ShikakuRect(0, 2, 0, 4),
            ShikakuRect(0, 5, 2, 5),
            ShikakuRect(1, 2, 2, 3),
            ShikakuRect(1, 4, 3, 4),
            ShikakuRect(2, 0, 3, 1),
            ShikakuRect(3, 2, 4, 3),
            ShikakuRect(3, 5, 5, 5),
            ShikakuRect(4, 0, 5, 1),
            ShikakuRect(4, 4, 5, 4),
            ShikakuRect(5, 2, 5, 3),
          ];
    final clues = List<int>.filled(n, 0);
    for (final rect in fallbackRects) {
      final cells = <int>[
        for (var r = rect.r1; r <= rect.r2; r++)
          for (var c = rect.c1; c <= rect.c2; c++) r * size + c,
      ];
      clues[cells[rng.nextInt(cells.length)]] = rect.area;
    }
    return ShikakuPuzzle(size: size, clues: clues, solutionRects: List.of(fallbackRects));
  }
}

/// 数方分割竞速 (Shikaku Race, 1-6 人).
class ShikakuGame extends GameEngine {
  ShikakuGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late ShikakuPuzzle currentPuzzle;
  late List<ShikakuPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a8Placings(ranking, players) : null;

  @override
  bool get canResign => !over;

  @override
  int get botDelayMs => switch (botLevel) { 0 => 760, 2 => 260, _ => 460 };

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

    currentPuzzle = ShikakuSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) ShikakuPlayer()];

    host.log('数方分割竞速开始（$size×$size 网格，共 $totalRounds 题）！把网格划分为不重叠矩形，使每个矩形恰好含 1 个等于其面积的数字！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = ShikakuSolver.generatePuzzle(size, rng);
    }
    for (var s = 0; s < players; s++) {
      ps[s].resetForRound();
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
    return a8Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
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
      case 'rect':
        final r1 = asInt(a['r1']);
        final c1 = asInt(a['c1']);
        final r2 = asInt(a['r2']);
        final c2 = asInt(a['c2']);
        if (r1 < 0 ||
            r1 >= size ||
            c1 < 0 ||
            c1 >= size ||
            r2 < 0 ||
            r2 >= size ||
            c2 < 0 ||
            c2 >= size) {
          throw GameError('矩形坐标超出棋盘范围');
        }
        final nr = ShikakuRect.normalized(r1, c1, r2, c2);
        p.rects.removeWhere((existing) => existing.overlaps(nr));
        p.rects.add(nr);
        moves++;
        if (ShikakuSolver.isSolved(currentPuzzle.clues, p.rects, size)) {
          _markSolved(seat);
        }

      case 'remove':
        if (a.containsKey('index')) {
          final idx = asInt(a['index']);
          if (idx < 0 || idx >= p.rects.length) {
            throw GameError('矩形索引超出范围');
          }
          p.rects.removeAt(idx);
        } else if (a.containsKey('r') && a.containsKey('c')) {
          final r = asInt(a['r']);
          final c = asInt(a['c']);
          if (r < 0 || r >= size || c < 0 || c >= size) {
            throw GameError('格子坐标超出范围');
          }
          final hit = p.rects.indexWhere((rect) => rect.containsCell(r, c));
          if (hit < 0) {
            throw GameError('该位置没有可移除的矩形');
          }
          p.rects.removeAt(hit);
        } else {
          throw GameError('请指定要移除的矩形索引或坐标');
        }
        moves++;
        if (ShikakuSolver.isSolved(currentPuzzle.clues, p.rects, size)) {
          _markSolved(seat);
        }

      case 'clear':
      case 'reset':
        p.rects.clear();
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
    host.log('${name(seat)} 第 $roundSolvers 个完成数方分割，+$pts 分！');
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
    ranking = a8Ranking(players, (a, b) {
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
    host.log('游戏结束（$why）！冠军：${a8Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || !_activeInRound(seat)) return null;
    final p = ps[seat];
    final solRects = currentPuzzle.solutionRects;

    if (botLevel <= 0 && p.rects.isEmpty && rng.nextInt(8) == 0) {
      return {'type': 'pass'};
    }

    final missing = <ShikakuRect>[
      for (final r in solRects)
        if (!p.rects.contains(r)) r,
    ];
    if (missing.isNotEmpty) {
      final pick = missing[rng.nextInt(missing.length)];
      return {
        'type': 'rect',
        'r1': pick.r1,
        'c1': pick.c1,
        'r2': pick.r2,
        'c2': pick.c2,
      };
    }

    // Remove any non-solution rectangle
    for (var i = 0; i < p.rects.length; i++) {
      if (!solRects.contains(p.rects[i])) {
        return {'type': 'remove', 'index': i};
      }
    }

    return {'type': 'pass'};
  }

  // ---------------------------------------------------------------- view

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players ? ps[seat] : (ps.isNotEmpty ? ps[0] : null);
    final clues = currentPuzzle.clues;
    final myRects = me?.rects ?? const <ShikakuRect>[];
    final analysis = ShikakuSolver.analyze(clues, myRects, size);

    final clueOkList = <bool>[
      for (var i = 0; i < clues.length; i++)
        clues[i] > 0 ? (analysis.clueOk[i] ?? false) : true,
    ];

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'clues': clues,
      'rects': [
        for (var i = 0; i < myRects.length; i++)
          myRects[i].toJson(
            ok: i < analysis.rectOk.length && analysis.rectOk[i],
            clueCount: i < analysis.rectClueCounts.length ? analysis.rectClueCounts[i] : 0,
            clueVal: i < analysis.rectClueVals.length ? analysis.rectClueVals[i] : 0,
          ),
      ],
      'clueOk': clueOkList,
      'coveredCount': analysis.coveredCount,
      'totalCells': analysis.totalCells,
      'okRects': analysis.okRects,
      'totalClues': max(1, analysis.totalClues),
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = ShikakuSolver.analyze(clues, ps[s].rects, size);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'okRects': pAn.okRects,
              'totalClues': max(1, pAn.totalClues),
              'covered': pAn.coveredCount,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class ShikakuPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<ShikakuRect> rects = [];

  void resetForRound() {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    rects = [];
  }
}
