import 'dart:math';

import '../../src/engine.dart';
import 'a12_util.dart';

class _SymTemplate {
  /// Offsets `(dr, dc)` relative to the topmost-leftmost cell `(0, 0)`.
  final List<(int, int)> cells;
  /// Doubled center offset `(dr2, dc2)` relative to `(2 * r0, 2 * c0)`.
  final int dr2;
  final int dc2;

  const _SymTemplate(this.cells, this.dr2, this.dc2);
}

class GalaxiesPuzzle {
  final int size;
  /// Center Dots `[r2, c2]` in doubled coordinates (`r2 = r_min + r_max`, `c2 = c_min + c_max`)
  /// for each Galaxy `0..centers.length-1`.
  final List<List<int>> centers;
  /// Flat `size * size` solution where each cell holds its Galaxy ID `0..centers.length-1`.
  final List<int> solutionBoard;

  const GalaxiesPuzzle({
    required this.size,
    required this.centers,
    required this.solutionBoard,
  });

  int get galaxyCount => centers.length;

  List<int> get initialBoard => List<int>.filled(size * size, -1);
}

class GalaxiesAnalysis {
  final Set<int> asymmetricCells;
  final Set<int> disconnectedCells;
  final Set<int> satisfiedGalaxies;
  final Set<int> violatedGalaxies;
  final int assignedCount;
  final int totalGalaxies;

  const GalaxiesAnalysis({
    required this.asymmetricCells,
    required this.disconnectedCells,
    required this.satisfiedGalaxies,
    required this.violatedGalaxies,
    required this.assignedCount,
    required this.totalGalaxies,
  });

  Set<int> get conflictCells => {
        ...asymmetricCells,
        ...disconnectedCells,
      };

  bool get isSolved =>
      assignedCount > 0 &&
      asymmetricCells.isEmpty &&
      disconnectedCells.isEmpty &&
      violatedGalaxies.isEmpty &&
      satisfiedGalaxies.length == totalGalaxies;
}

class GalaxiesSolver {
  static const List<int> orthoDr = [-1, 0, 1, 0];
  static const List<int> orthoDc = [0, 1, 0, -1];

  /// All 180°-rotationally-symmetric polyomino templates anchored at their
  /// topmost-leftmost cell `(0, 0)`.
  static const List<_SymTemplate> _multiTemplates = [
    // 1x2 and 2x1 dominoes
    _SymTemplate([(0, 0), (0, 1)], 0, 1),
    _SymTemplate([(0, 0), (1, 0)], 1, 0),
    // 1x3 and 3x1 trominoes
    _SymTemplate([(0, 0), (0, 1), (0, 2)], 0, 2),
    _SymTemplate([(0, 0), (1, 0), (2, 0)], 2, 0),
    // 2x2 square
    _SymTemplate([(0, 0), (0, 1), (1, 0), (1, 1)], 1, 1),
    // 4-cell Z / S tetrominoes (180°-symmetric)
    _SymTemplate([(0, 0), (0, 1), (1, 1), (1, 2)], 1, 2),
    _SymTemplate([(0, 0), (0, 1), (1, -1), (1, 0)], 1, 0),
    _SymTemplate([(0, 0), (1, 0), (1, 1), (2, 1)], 2, 1),
    _SymTemplate([(0, 0), (1, -1), (1, 0), (2, -1)], 2, -1),
    // 5-cell Plus pentomino
    _SymTemplate([(0, 0), (1, -1), (1, 0), (1, 1), (2, 0)], 2, 0),
    // 2x3 and 3x2 rectangles
    _SymTemplate([(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2)], 1, 2),
    _SymTemplate([(0, 0), (0, 1), (1, 0), (1, 1), (2, 0), (2, 1)], 2, 1),
  ];

  static const _SymTemplate _monoTemplate = _SymTemplate([(0, 0)], 0, 0);

  /// Returns the cell indices immediately touching/containing the Center Dot
  /// `[r2, c2]` (1 cell for cell center, 2 cells for edge midpoint, 4 cells for vertex).
  static List<int> centerCoreCells(int size, int r2, int c2) {
    final rows = r2.isEven ? <int>[r2 ~/ 2] : <int>[r2 ~/ 2, r2 ~/ 2 + 1];
    final cols = c2.isEven ? <int>[c2 ~/ 2] : <int>[c2 ~/ 2, c2 ~/ 2 + 1];
    final out = <int>[];
    for (final r in rows) {
      for (final c in cols) {
        if (r >= 0 && r < size && c >= 0 && c < size) {
          out.add(r * size + c);
        }
      }
    }
    return out;
  }

  static GalaxiesAnalysis analyze(GalaxiesPuzzle puz, List<int> board) {
    final size = puz.size;
    final n = size * size;
    final gCount = puz.galaxyCount;
    final asymmetricCells = <int>{};
    final disconnectedCells = <int>{};
    final satisfiedGalaxies = <int>{};
    final violatedGalaxies = <int>{};

    final cellsByGalaxy = List<List<int>>.generate(gCount, (_) => <int>[]);
    var assignedCount = 0;

    for (var i = 0; i < n; i++) {
      final g = i < board.length ? board[i] : -1;
      if (g >= 0 && g < gCount) {
        assignedCount++;
        cellsByGalaxy[g].add(i);
      } else if (g != -1) {
        asymmetricCells.add(i);
      }
    }

    for (var g = 0; g < gCount; g++) {
      final cells = cellsByGalaxy[g];
      if (cells.isEmpty) continue;
      final center = puz.centers[g];
      final r2 = center[0], c2 = center[1];
      var symOk = true;

      // 1. Check 180° rotational symmetry around [r2, c2]
      for (final idx in cells) {
        final r = idx ~/ size, c = idx % size;
        final sr = r2 - r, sc = c2 - c;
        if (sr < 0 || sr >= size || sc < 0 || sc >= size) {
          symOk = false;
          asymmetricCells.add(idx);
        } else {
          final sIdx = sr * size + sc;
          final sg = sIdx < board.length ? board[sIdx] : -1;
          if (sg != g) {
            symOk = false;
            asymmetricCells.add(idx);
          }
        }
      }

      // 2. Check Center Dot containment
      final core = centerCoreCells(size, r2, c2);
      final containsCenter = core.any((idx) => idx < board.length && board[idx] == g);

      // 3. Check orthogonal connectivity of cells in Galaxy g
      final cellSet = cells.toSet();
      final visited = <int>{cells.first};
      final q = <int>[cells.first];
      var head = 0;
      while (head < q.length) {
        final cur = q[head++];
        final r = cur ~/ size, c = cur % size;
        for (var d = 0; d < 4; d++) {
          final nr = r + orthoDr[d], nc = c + orthoDc[d];
          if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
          final nIdx = nr * size + nc;
          if (cellSet.contains(nIdx) && visited.add(nIdx)) {
            q.add(nIdx);
          }
        }
      }
      final connected = visited.length == cells.length;

      if (!containsCenter || !connected) {
        disconnectedCells.addAll(cells);
      }

      if (symOk && containsCenter && connected) {
        satisfiedGalaxies.add(g);
      } else {
        violatedGalaxies.add(g);
      }
    }

    return GalaxiesAnalysis(
      asymmetricCells: asymmetricCells,
      disconnectedCells: disconnectedCells,
      satisfiedGalaxies: satisfiedGalaxies,
      violatedGalaxies: violatedGalaxies,
      assignedCount: assignedCount,
      totalGalaxies: gCount,
    );
  }

  static bool isSolved(GalaxiesPuzzle puz, List<int> board) {
    final n = puz.size * puz.size;
    if (board.length != n) return false;
    final an = analyze(puz, board);
    return an.assignedCount == n && an.isSolved;
  }

  /// Generates a guaranteed-valid Spiral Galaxies puzzle for [size] (`5` or `6`).
  static GalaxiesPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    final maxMonominoes = size <= 5 ? 2 : 3;

    for (var attempt = 0; attempt < 30; attempt++) {
      final sol = List<int>.filled(n, -1);
      final centers = <List<int>>[];
      var monoCount = 0;

      bool backtrack() {
        var firstEmpty = -1;
        for (var i = 0; i < n; i++) {
          if (sol[i] == -1) {
            firstEmpty = i;
            break;
          }
        }
        if (firstEmpty == -1) return true;

        final r0 = firstEmpty ~/ size, c0 = firstEmpty % size;
        final templates = <_SymTemplate>[
          ...(List<_SymTemplate>.of(_multiTemplates)..shuffle(rng)),
          if (monoCount < maxMonominoes) _monoTemplate,
        ];

        for (final tpl in templates) {
          var fits = true;
          for (final (dr, dc) in tpl.cells) {
            final nr = r0 + dr, nc = c0 + dc;
            if (nr < 0 || nr >= size || nc < 0 || nc >= size || sol[nr * size + nc] != -1) {
              fits = false;
              break;
            }
          }
          if (!fits) continue;

          final gId = centers.length;
          for (final (dr, dc) in tpl.cells) {
            sol[(r0 + dr) * size + (c0 + dc)] = gId;
          }
          centers.add([2 * r0 + tpl.dr2, 2 * c0 + tpl.dc2]);
          if (tpl.cells.length == 1) monoCount++;

          if (backtrack()) return true;

          if (tpl.cells.length == 1) monoCount--;
          centers.removeLast();
          for (final (dr, dc) in tpl.cells) {
            sol[(r0 + dr) * size + (c0 + dc)] = -1;
          }
        }
        return false;
      }

      if (backtrack() && centers.length >= 4) {
        return GalaxiesPuzzle(
          size: size,
          centers: centers,
          solutionBoard: sol,
        );
      }
    }

    // Deterministic fallback partition of symmetric dominoes/trominoes/squares
    final sol = List<int>.filled(n, -1);
    final centers = <List<int>>[];
    for (var i = 0; i < n; i++) {
      if (sol[i] != -1) continue;
      final r = i ~/ size, c = i % size;
      final gId = centers.length;
      if (c + 1 < size && sol[r * size + c + 1] == -1) {
        sol[r * size + c] = gId;
        sol[r * size + c + 1] = gId;
        centers.add([2 * r, 2 * c + 1]);
      } else if (r + 1 < size && sol[(r + 1) * size + c] == -1) {
        sol[r * size + c] = gId;
        sol[(r + 1) * size + c] = gId;
        centers.add([2 * r + 1, 2 * c]);
      } else {
        sol[r * size + c] = gId;
        centers.add([2 * r, 2 * c]);
      }
    }
    return GalaxiesPuzzle(
      size: size,
      centers: centers,
      solutionBoard: sol,
    );
  }
}

/// 对称星系分割竞速 (Spiral Galaxies Race, 1-6 人).
class GalaxiesGame extends GameEngine {
  GalaxiesGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late GalaxiesPuzzle currentPuzzle;
  late List<GalaxiesPlayer> ps;
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

    currentPuzzle = GalaxiesSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) GalaxiesPlayer(size * size)];

    host.log('对称星系分割竞速开始（$size×$size 网格，共 $totalRounds 题）！围绕中心圆点划分 180° 旋转对称星系！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = GalaxiesSolver.generatePuzzle(size, rng);
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

    final gCount = currentPuzzle.galaxyCount;
    switch (type) {
      case 'set':
      case 'toggle':
        final (r, c) = _resolveCell(a);
        final idx = r * size + c;
        if (a.containsKey('val')) {
          final v = asInt(a['val'], -2);
          if (v < -1 || v >= gCount) {
            throw GameError('星系编号必须在 -1～${gCount - 1} 之间');
          }
          p.board[idx] = v;
        } else {
          final cur = p.board[idx];
          p.board[idx] = cur + 1 >= gCount ? -1 : cur + 1;
        }
        moves++;
        if (GalaxiesSolver.isSolved(currentPuzzle, p.board)) {
          _markSolved(seat);
        }

      case 'clear':
      case 'reset':
        for (var i = 0; i < p.board.length; i++) {
          p.board[i] = -1;
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
    host.log('${name(seat)} 第 $roundSolvers 个解出对称星系分割谜题，+$pts 分！');
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
    final myBoard = me?.board ?? puz.initialBoard;
    final an = GalaxiesSolver.analyze(puz, myBoard);
    final totalCells = size * size;
    final totalGalaxies = puz.galaxyCount;

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'centers': puz.centers,
      'galaxyCount': totalGalaxies,
      'board': myBoard,
      'asymmetricCells': an.asymmetricCells.toList()..sort(),
      'disconnectedCells': an.disconnectedCells.toList()..sort(),
      'satisfiedGalaxies': an.satisfiedGalaxies.toList()..sort(),
      'violatedGalaxies': an.violatedGalaxies.toList()..sort(),
      'satisfiedGalaxyCount': an.satisfiedGalaxies.length,
      'totalGalaxies': totalGalaxies,
      'assignedCount': an.assignedCount,
      'totalCells': totalCells,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = GalaxiesSolver.analyze(puz, ps[s].board);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'assigned': pAn.assignedCount,
              'totalCells': totalCells,
              'satisfiedGalaxies': pAn.satisfiedGalaxies.length,
              'totalGalaxies': totalGalaxies,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class GalaxiesPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  GalaxiesPlayer(int cellCount) : board = List<int>.filled(cellCount, -1);

  void resetForRound(int cellCount) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.filled(cellCount, -1);
  }
}
