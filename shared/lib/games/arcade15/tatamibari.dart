import 'dart:math';

import '../../src/engine.dart';
import 'a15_util.dart';

class TatamibariPuzzle {
  final int size;
  /// Clue descriptors for each region `0..clues.length-1`:
  /// `{'id': k, 'r': cr, 'c': cc, 'sym': '+'|'-'|'|', 'code': 1|2|3, 'r1': r1, 'c1': c1, 'r2': r2, 'c2': c2}`.
  final List<Map<String, dynamic>> clues;
  /// `size × size` grid of clue codes (`0` = none, `1` = `'+'`, `2` = `'-'`, `3` = `'|'`).
  final List<List<int>> clueGrid;
  /// `size × size` grid of clue region IDs (`-1` if not a clue cell, else `0..R-1`).
  final List<List<int>> clueIdGrid;
  /// Flat `size * size` solution where each cell holds its region ID `0..R-1`.
  final List<int> solutionBoard;

  const TatamibariPuzzle({
    required this.size,
    required this.clues,
    required this.clueGrid,
    required this.clueIdGrid,
    required this.solutionBoard,
  });

  int get regionCount => clues.length;

  List<int> get clueGridFlat => [
        for (var r = 0; r < size; r++)
          for (var c = 0; c < size; c++) clueGrid[r][c],
      ];

  List<int> get clueIdFlat => [
        for (var r = 0; r < size; r++)
          for (var c = 0; c < size; c++) clueIdGrid[r][c],
      ];

  List<int> get initialBoard => List<int>.filled(size * size, -1);
}

class TatamibariAnalysis {
  final Set<int> satisfiedRegions;
  final Set<int> violatedRegions;
  final Set<int> nonRectCells;
  final Set<int> badProportionCells;
  /// Internal vertex indices `vr * (size + 1) + vc` (`1 <= vr < size, 1 <= vc < size`)
  /// where 4 different region IDs meet.
  final Set<int> fourCornerVertices;
  final Set<int> fourCornerCells;
  final int assignedCount;
  final int totalRegions;

  const TatamibariAnalysis({
    required this.satisfiedRegions,
    required this.violatedRegions,
    required this.nonRectCells,
    required this.badProportionCells,
    required this.fourCornerVertices,
    required this.fourCornerCells,
    required this.assignedCount,
    required this.totalRegions,
  });

  Set<int> get conflictCells => {
        ...nonRectCells,
        ...badProportionCells,
        ...fourCornerCells,
      };

  bool get isSolved =>
      totalRegions > 0 &&
      satisfiedRegions.length == totalRegions &&
      violatedRegions.isEmpty &&
      nonRectCells.isEmpty &&
      badProportionCells.isEmpty &&
      fourCornerVertices.isEmpty;
}

class TatamibariSolver {
  static String symbolForDims(int width, int height) {
    if (width == height) return '+';
    return width > height ? '-' : '|';
  }

  static int codeForDims(int width, int height) {
    if (width == height) return 1;
    return width > height ? 2 : 3;
  }

  static bool matchesProportion(int code, int width, int height) => switch (code) {
        1 => width == height,
        2 => width > height,
        3 => height > width,
        _ => false,
      };

  static TatamibariAnalysis analyze(TatamibariPuzzle puz, List<int> board) {
    final size = puz.size;
    final n = size * size;
    final rCount = puz.regionCount;

    final satisfiedRegions = <int>{};
    final violatedRegions = <int>{};
    final nonRectCells = <int>{};
    final badProportionCells = <int>{};
    final fourCornerVertices = <int>{};
    final fourCornerCells = <int>{};

    final cellsByRegion = List<List<int>>.generate(rCount, (_) => <int>[]);
    var assignedCount = 0;

    for (var i = 0; i < n; i++) {
      final reg = i < board.length ? board[i] : -1;
      if (reg >= 0 && reg < rCount) {
        assignedCount++;
        cellsByRegion[reg].add(i);
      } else if (reg != -1) {
        nonRectCells.add(i);
      }
    }

    // 1. Check each region k in 0..R-1:
    //    - forms a solid axis-aligned rectangle
    //    - contains ONLY its own Clue cell k
    //    - matches its Clue's proportion ('+': w == h, '-': w > h, '|': h > w)
    for (var k = 0; k < rCount; k++) {
      final cells = cellsByRegion[k];
      if (cells.isEmpty) continue;

      final clue = puz.clues[k];
      final cr = clue['r'] as int;
      final cc = clue['c'] as int;
      final code = clue['code'] as int;
      final clueIdx = cr * size + cc;

      var minR = size, maxR = -1, minC = size, maxC = -1;
      var containsOwnClue = false;
      var containsOtherClue = false;

      for (final idx in cells) {
        final r = idx ~/ size, c = idx % size;
        if (r < minR) minR = r;
        if (r > maxR) maxR = r;
        if (c < minC) minC = c;
        if (c > maxC) maxC = c;
        if (idx == clueIdx) containsOwnClue = true;
        final cid = puz.clueIdGrid[r][c];
        if (cid >= 0 && cid != k) {
          containsOtherClue = true;
        }
      }

      final h = maxR - minR + 1;
      final w = maxC - minC + 1;
      final isSolidRect = cells.length == w * h;
      final clueOk = containsOwnClue && !containsOtherClue;
      final propOk = matchesProportion(code, w, h);

      if (!isSolidRect || !clueOk) {
        nonRectCells.addAll(cells);
        violatedRegions.add(k);
      } else if (!propOk) {
        badProportionCells.addAll(cells);
        violatedRegions.add(k);
      } else {
        satisfiedRegions.add(k);
      }
    }

    // 2. Check No-4-Corner-Intersection at internal vertices (1 <= vr < size, 1 <= vc < size)
    final vSize = size + 1;
    for (var vr = 1; vr < size; vr++) {
      for (var vc = 1; vc < size; vc++) {
        final i00 = (vr - 1) * size + (vc - 1);
        final i01 = (vr - 1) * size + vc;
        final i10 = vr * size + (vc - 1);
        final i11 = vr * size + vc;
        final r00 = i00 < board.length ? board[i00] : -1;
        final r01 = i01 < board.length ? board[i01] : -1;
        final r10 = i10 < board.length ? board[i10] : -1;
        final r11 = i11 < board.length ? board[i11] : -1;
        if (r00 >= 0 && r01 >= 0 && r10 >= 0 && r11 >= 0) {
          if ({r00, r01, r10, r11}.length == 4) {
            fourCornerVertices.add(vr * vSize + vc);
            fourCornerCells.addAll([i00, i01, i10, i11]);
          }
        }
      }
    }

    return TatamibariAnalysis(
      satisfiedRegions: satisfiedRegions,
      violatedRegions: violatedRegions,
      nonRectCells: nonRectCells,
      badProportionCells: badProportionCells,
      fourCornerVertices: fourCornerVertices,
      fourCornerCells: fourCornerCells,
      assignedCount: assignedCount,
      totalRegions: rCount,
    );
  }

  static bool isSolved(TatamibariPuzzle puz, List<int> board) {
    final n = puz.size * puz.size;
    if (board.length != n) return false;
    final an = analyze(puz, board);
    return an.assignedCount == n && an.isSolved;
  }

  static bool _hasFourCornerIntersection(int size, List<int> sol) {
    for (var vr = 1; vr < size; vr++) {
      for (var vc = 1; vc < size; vc++) {
        final r00 = sol[(vr - 1) * size + (vc - 1)];
        final r01 = sol[(vr - 1) * size + vc];
        final r10 = sol[vr * size + (vc - 1)];
        final r11 = sol[vr * size + vc];
        if (r00 >= 0 && r01 >= 0 && r10 >= 0 && r11 >= 0) {
          if ({r00, r01, r10, r11}.length == 4) return true;
        }
      }
    }
    return false;
  }

  /// Generates a guaranteed-valid Tatamibari puzzle for [size] (`5` or `6`).
  static TatamibariPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    const baseDims = <(int, int)>[
      (1, 2),
      (2, 1),
      (1, 3),
      (3, 1),
      (2, 2),
      (2, 3),
      (3, 2),
      (1, 4),
      (4, 1),
    ];

    for (var attempt = 0; attempt < 50; attempt++) {
      final sol = List<int>.filled(n, -1);
      final rects = <Map<String, int>>[];
      var unitCount = 0;
      final maxUnits = size <= 5 ? 2 : 3;

      bool backtrack() {
        var firstEmpty = -1;
        for (var i = 0; i < n; i++) {
          if (sol[i] == -1) {
            firstEmpty = i;
            break;
          }
        }
        if (firstEmpty == -1) {
          return !_hasFourCornerIntersection(size, sol);
        }

        final r0 = firstEmpty ~/ size, c0 = firstEmpty % size;

        // If placing ANY new rectangle with top-left corner at (r0, c0) would
        // immediately create 4 distinct rectangles around vertex (r0, c0), prune!
        if (r0 > 0 && c0 > 0) {
          final tl = sol[(r0 - 1) * size + (c0 - 1)];
          final tr = sol[(r0 - 1) * size + c0];
          final bl = sol[r0 * size + (c0 - 1)];
          if (tl != tr && tl != bl && tr != bl) {
            return false;
          }
        }

        final candidates = <(int, int)>[
          ...(List<(int, int)>.of(baseDims)..shuffle(rng)),
          if (unitCount < maxUnits) (1, 1),
        ];

        for (final (h, w) in candidates) {
          if (r0 + h > size || c0 + w > size) continue;
          var fits = true;
          for (var dr = 0; dr < h && fits; dr++) {
            for (var dc = 0; dc < w; dc++) {
              if (sol[(r0 + dr) * size + (c0 + dc)] != -1) {
                fits = false;
                break;
              }
            }
          }
          if (!fits) continue;

          // Also check top-right corner at vertex (r0, c0 + w): if r0 > 0 and
          // c0 + w < size and (r0, c0 + w) is still empty, then if
          // sol[r0-1, c0+w-1] != sol[r0-1, c0+w], filling (r0, c0 + w) later with
          // another region would create a 4-corner violation at (r0, c0 + w).
          if (r0 > 0 && c0 + w < size && sol[r0 * size + (c0 + w)] == -1) {
            final ul = sol[(r0 - 1) * size + (c0 + w - 1)];
            final ur = sol[(r0 - 1) * size + (c0 + w)];
            if (ul != ur) continue;
          }

          final regId = rects.length;
          for (var dr = 0; dr < h; dr++) {
            for (var dc = 0; dc < w; dc++) {
              sol[(r0 + dr) * size + (c0 + dc)] = regId;
            }
          }
          rects.add({
            'id': regId,
            'r1': r0,
            'c1': c0,
            'r2': r0 + h - 1,
            'c2': c0 + w - 1,
          });
          if (h == 1 && w == 1) unitCount++;

          if (backtrack()) return true;

          if (h == 1 && w == 1) unitCount--;
          rects.removeLast();
          for (var dr = 0; dr < h; dr++) {
            for (var dc = 0; dc < w; dc++) {
              sol[(r0 + dr) * size + (c0 + dc)] = -1;
            }
          }
        }
        return false;
      }

      if (backtrack() && rects.length >= 5) {
        final codes = <int>{};
        for (final rm in rects) {
          final w = rm['c2']! - rm['c1']! + 1;
          final h = rm['r2']! - rm['r1']! + 1;
          codes.add(codeForDims(w, h));
        }
        // Prefer partitions that showcase all 3 clue types ('+', '-', '|')
        if (codes.length < 3 && attempt < 35) continue;

        return _buildPuzzleFromRects(size, rects, sol, rng);
      }
    }

    // Deterministic fallback with staggered brick-like rectangles (zero 4-corners)
    final sol = List<int>.filled(n, -1);
    final rects = <Map<String, int>>[];
    if (size == 5) {
      // 5x5 brick partition with '+', '-', '|'
      final spec = <(int, int, int, int)>[
        (0, 0, 1, 1), // 2x2 '+'
        (0, 2, 0, 4), // 1x3 '-'
        (1, 2, 2, 3), // 2x2 '+'
        (1, 4, 3, 4), // 3x1 '|'
        (2, 0, 4, 0), // 3x1 '|'
        (2, 1, 3, 1), // 2x1 '|'
        (3, 2, 3, 3), // 1x2 '-'
        (4, 1, 4, 2), // 1x2 '-'
        (4, 3, 4, 4), // 1x2 '-'
      ];
      for (var i = 0; i < spec.length; i++) {
        final (r1, c1, r2, c2) = spec[i];
        for (var r = r1; r <= r2; r++) {
          for (var c = c1; c <= c2; c++) {
            sol[r * size + c] = i;
          }
        }
        rects.add({'id': i, 'r1': r1, 'c1': c1, 'r2': r2, 'c2': c2});
      }
    } else {
      // 6x6 brick partition with '+', '-', '|'
      final spec = <(int, int, int, int)>[
        (0, 0, 1, 1), // 2x2 '+'
        (0, 2, 0, 4), // 1x3 '-'
        (0, 5, 2, 5), // 3x1 '|'
        (1, 2, 2, 3), // 2x2 '+'
        (1, 4, 3, 4), // 3x1 '|'
        (2, 0, 4, 0), // 3x1 '|'
        (2, 1, 3, 1), // 2x1 '|'
        (3, 2, 3, 3), // 1x2 '-'
        (3, 5, 5, 5), // 3x1 '|'
        (4, 1, 5, 2), // 2x2 '+'
        (4, 3, 4, 4), // 1x2 '-'
        (5, 0, 5, 0), // 1x1 '+'
        (5, 3, 5, 4), // 1x2 '-'
      ];
      for (var i = 0; i < spec.length; i++) {
        final (r1, c1, r2, c2) = spec[i];
        for (var r = r1; r <= r2; r++) {
          for (var c = c1; c <= c2; c++) {
            sol[r * size + c] = i;
          }
        }
        rects.add({'id': i, 'r1': r1, 'c1': c1, 'r2': r2, 'c2': c2});
      }
    }
    return _buildPuzzleFromRects(size, rects, sol, rng);
  }

  static TatamibariPuzzle _buildPuzzleFromRects(
    int size,
    List<Map<String, int>> rects,
    List<int> sol,
    Random rng,
  ) {
    final clueGrid = [
      for (var r = 0; r < size; r++) List<int>.filled(size, 0),
    ];
    final clueIdGrid = [
      for (var r = 0; r < size; r++) List<int>.filled(size, -1),
    ];
    final clues = <Map<String, dynamic>>[];

    for (var k = 0; k < rects.length; k++) {
      final rm = rects[k];
      final r1 = rm['r1']!, c1 = rm['c1']!, r2 = rm['r2']!, c2 = rm['c2']!;
      final h = r2 - r1 + 1;
      final w = c2 - c1 + 1;
      final cr = r1 + rng.nextInt(h);
      final cc = c1 + rng.nextInt(w);
      final sym = symbolForDims(w, h);
      final code = codeForDims(w, h);
      clueGrid[cr][cc] = code;
      clueIdGrid[cr][cc] = k;
      clues.add({
        'id': k,
        'r': cr,
        'c': cc,
        'sym': sym,
        'code': code,
        'r1': r1,
        'c1': c1,
        'r2': r2,
        'c2': c2,
      });
    }

    return TatamibariPuzzle(
      size: size,
      clues: clues,
      clueGrid: clueGrid,
      clueIdGrid: clueIdGrid,
      solutionBoard: sol,
    );
  }
}

/// 榻榻米分割竞速 (Tatamibari Race, 1-6 人).
class TatamibariGame extends GameEngine {
  TatamibariGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late TatamibariPuzzle currentPuzzle;
  late List<TatamibariPlayer> ps;
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

    currentPuzzle = TatamibariSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) TatamibariPlayer(size * size)];

    host.log('榻榻米分割竞速开始（$size×$size 网格，共 $totalRounds 题）！按 + / - / | 比例划分矩形且禁止内部四席交点！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = TatamibariSolver.generatePuzzle(size, rng);
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

    final rCount = currentPuzzle.regionCount;
    switch (type) {
      case 'set':
      case 'toggle':
        final (r, c) = _resolveCell(a);
        final idx = r * size + c;
        if (a.containsKey('val')) {
          final v = asInt(a['val'], -2);
          if (v < -1 || v >= rCount) {
            throw GameError('榻榻米区域编号必须在 -1～${rCount - 1} 之间');
          }
          p.board[idx] = v;
        } else {
          final cur = p.board[idx];
          p.board[idx] = cur + 1 >= rCount ? -1 : cur + 1;
        }
        moves++;
        if (TatamibariSolver.isSolved(currentPuzzle, p.board)) {
          _markSolved(seat);
        }

      case 'clear':
      case 'reset':
        p.board.fillRange(0, p.board.length, -1);
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
    host.log('${name(seat)} 第 $roundSolvers 个解出榻榻米分割谜题，+$pts 分！');
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
    final myBoard = me?.board ?? puz.initialBoard;
    final an = TatamibariSolver.analyze(puz, myBoard);
    final totalCells = size * size;
    final totalRegions = puz.regionCount;

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'clues': puz.clues,
      'clueGrid': puz.clueGrid,
      'clueGridFlat': puz.clueGridFlat,
      'clueIdGrid': puz.clueIdGrid,
      'clueIdFlat': puz.clueIdFlat,
      'regionCount': totalRegions,
      'totalRegions': totalRegions,
      'board': myBoard,
      'satisfiedRegions': an.satisfiedRegions.toList()..sort(),
      'violatedRegions': an.violatedRegions.toList()..sort(),
      'nonRectCells': an.nonRectCells.toList()..sort(),
      'badProportionCells': an.badProportionCells.toList()..sort(),
      'fourCornerVertices': an.fourCornerVertices.toList()..sort(),
      'fourCornerCells': an.fourCornerCells.toList()..sort(),
      'satisfiedRegionCount': an.satisfiedRegions.length,
      'assignedCount': an.assignedCount,
      'totalCells': totalCells,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = TatamibariSolver.analyze(puz, ps[s].board);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'assigned': pAn.assignedCount,
              'totalCells': totalCells,
              'satisfiedRegions': pAn.satisfiedRegions.length,
              'totalRegions': totalRegions,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class TatamibariPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  TatamibariPlayer(int cellCount) : board = List<int>.filled(cellCount, -1);

  void resetForRound(int cellCount) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.filled(cellCount, -1);
  }
}
