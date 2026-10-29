import 'dart:math';

import '../../src/engine.dart';
import 'a10_util.dart';

class KenKenCage {
  final int id;
  /// Sorted flat cell indices (`r * size + c`) belonging to this cage (`1..3` cells).
  final List<int> cells;
  /// Arithmetic operator: `'+'`, `'-'`, `'×'`, `'÷'`, or `'='` (for 1-cell cages).
  final String op;
  /// Target value of the cage under [op].
  final int target;

  const KenKenCage({
    required this.id,
    required this.cells,
    required this.op,
    required this.target,
  });

  int get anchorCell => cells.first;

  String get label => op == '=' ? '$target' : '$target$op';

  Map<String, dynamic> toJson() => {
        'id': id,
        'cells': cells,
        'op': op,
        'target': target,
        'anchor': anchorCell,
        'label': label,
      };
}

class KenKenPuzzle {
  final int size;
  final List<KenKenCage> cages;
  /// Flat `size * size` list mapping each cell index to its cage ID (`0..cages.length-1`).
  final List<int> cageMap;
  /// Flat `size * size` Latin Square solution of `1..size`.
  final List<int> solutionBoard;

  const KenKenPuzzle({
    required this.size,
    required this.cages,
    required this.cageMap,
    required this.solutionBoard,
  });
}

class KenKenAnalysis {
  final Set<int> duplicateCells;
  final Set<int> violatedCells;
  final Set<int> satisfiedCages;
  final Set<int> violatedCages;
  final int validLines;
  final int filledCount;
  final int totalCages;

  const KenKenAnalysis({
    required this.duplicateCells,
    required this.violatedCells,
    required this.satisfiedCages,
    required this.violatedCages,
    required this.validLines,
    required this.filledCount,
    required this.totalCages,
  });

  Set<int> get conflictCells => {...duplicateCells, ...violatedCells};

  bool get isSolved =>
      filledCount > 0 &&
      duplicateCells.isEmpty &&
      violatedCages.isEmpty &&
      satisfiedCages.length == totalCages;
}

class KenKenSolver {
  static const List<int> dr = [-1, 0, 1, 0];
  static const List<int> dc = [0, 1, 0, -1];

  /// Evaluates whether a filled [cage] satisfies its [cage.target] under [cage.op].
  /// Returns `null` if any cell in the cage is still empty (`0`).
  static bool? evaluateCage(KenKenCage cage, List<int> board, int size) {
    final vals = <int>[];
    for (final idx in cage.cells) {
      final v = idx >= 0 && idx < board.length ? board[idx] : 0;
      if (v < 1 || v > size) return null;
      vals.add(v);
    }
    if (vals.isEmpty) return false;

    switch (cage.op) {
      case '=':
      case '':
        return vals.first == cage.target;
      case '+':
        var sum = 0;
        for (final v in vals) {
          sum += v;
        }
        return sum == cage.target;
      case '×':
      case '*':
        var prod = 1;
        for (final v in vals) {
          prod *= v;
        }
        return prod == cage.target;
      case '-':
        if (vals.length == 2) {
          return (vals[0] - vals[1]).abs() == cage.target;
        }
        final maxVal = vals.reduce(max);
        final rest = vals.fold<int>(0, (a, b) => a + b) - maxVal;
        return (maxVal - rest) == cage.target;
      case '÷':
      case '/':
        if (vals.length == 2) {
          final big = max(vals[0], vals[1]);
          final small = min(vals[0], vals[1]);
          return small > 0 && big % small == 0 && (big ~/ small) == cage.target;
        }
        return false;
      default:
        return false;
    }
  }

  static KenKenAnalysis analyze(KenKenPuzzle puz, List<int> board) {
    final size = puz.size;
    final n = size * size;
    final duplicateCells = <int>{};
    final violatedCells = <int>{};
    final satisfiedCages = <int>{};
    final violatedCages = <int>{};

    var filledCount = 0;
    for (var i = 0; i < n; i++) {
      final v = i < board.length ? board[i] : 0;
      if (v >= 1 && v <= size) filledCount++;
    }

    var validLines = 0;
    // Rows
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

    // Columns
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

    // Cages
    for (final cage in puz.cages) {
      final ok = evaluateCage(cage, board, size);
      if (ok == true) {
        satisfiedCages.add(cage.id);
      } else if (ok == false) {
        violatedCages.add(cage.id);
        violatedCells.addAll(cage.cells);
      }
    }

    return KenKenAnalysis(
      duplicateCells: duplicateCells,
      violatedCells: violatedCells,
      satisfiedCages: satisfiedCages,
      violatedCages: violatedCages,
      validLines: validLines,
      filledCount: filledCount,
      totalCages: puz.cages.length,
    );
  }

  static bool isSolved(KenKenPuzzle puz, List<int> board) {
    final size = puz.size;
    if (board.length != size * size) return false;
    final an = analyze(puz, board);
    return an.filledCount == size * size &&
        an.validLines == 2 * size &&
        an.duplicateCells.isEmpty &&
        an.violatedCages.isEmpty &&
        an.satisfiedCages.length == puz.cages.length;
  }

  /// Generates a guaranteed-valid KenKen puzzle for [size] (`4` or `5`).
  static KenKenPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;

    // 1. Generate a randomized Latin Square of `1..size`
    final rowPerm = [for (var i = 0; i < size; i++) i]..shuffle(rng);
    final colPerm = [for (var i = 0; i < size; i++) i]..shuffle(rng);
    final symPerm = [for (var i = 1; i <= size; i++) i]..shuffle(rng);

    final sol = List<int>.filled(n, 1);
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        sol[r * size + c] = symPerm[(rowPerm[r] + colPerm[c]) % size];
      }
    }

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

    // 2. Partition the N×N cells into contiguous Cages of size 1..3
    final cageMap = List<int>.filled(n, -1);
    final cages = <KenKenCage>[];
    final cellOrder = [for (var i = 0; i < n; i++) i]..shuffle(rng);

    for (final start in cellOrder) {
      if (cageMap[start] != -1) continue;
      final cageId = cages.length;
      final desiredSize = rng.nextInt(10) < 6 ? 2 : 3;
      final cells = <int>[start];
      cageMap[start] = cageId;

      while (cells.length < desiredSize) {
        final frontier = <int>[];
        for (final cur in cells) {
          final r = cur ~/ size, c = cur % size;
          for (var d = 0; d < 4; d++) {
            final nr = r + dr[d], nc = c + dc[d];
            if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
            final nIdx = nr * size + nc;
            if (cageMap[nIdx] == -1 && !frontier.contains(nIdx)) {
              frontier.add(nIdx);
            }
          }
        }
        if (frontier.isEmpty) break;
        final pick = frontier[rng.nextInt(frontier.length)];
        cageMap[pick] = cageId;
        cells.add(pick);
      }

      cells.sort();
      final vals = [for (final idx in cells) sol[idx]];
      String op;
      int target;

      if (cells.length == 1) {
        op = '=';
        target = vals.first;
      } else if (cells.length == 2) {
        final a = vals[0], b = vals[1];
        final big = max(a, b), small = min(a, b);
        final candidates = <(String, int)>[
          ('+', a + b),
          ('×', a * b),
          if (big != small) ('-', big - small),
          if (big != small) ('-', big - small),
          if (small > 0 && big % small == 0 && big ~/ small > 1)
            ('÷', big ~/ small),
          if (small > 0 && big % small == 0 && big ~/ small > 1)
            ('÷', big ~/ small),
        ];
        final choice = candidates[rng.nextInt(candidates.length)];
        op = choice.$1;
        target = choice.$2;
      } else {
        if (rng.nextBool()) {
          op = '+';
          target = vals.fold<int>(0, (a, b) => a + b);
        } else {
          op = '×';
          target = vals.fold<int>(1, (a, b) => a * b);
        }
      }

      cages.add(KenKenCage(
        id: cageId,
        cells: cells,
        op: op,
        target: target,
      ));
    }

    return KenKenPuzzle(
      size: size,
      cages: cages,
      cageMap: cageMap,
      solutionBoard: sol,
    );
  }
}

/// 算术笼数独竞速 (KenKen Race, 1-6 人).
class KenKenGame extends GameEngine {
  KenKenGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late KenKenPuzzle currentPuzzle;
  late List<KenKenPlayer> ps;
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

    currentPuzzle = KenKenSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) KenKenPlayer(size * size)];

    host.log('算术笼数独竞速开始（$size×$size 网格，共 $totalRounds 题）！填入 1～$size 满足行列不重复与全部算术笼目标！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = KenKenSolver.generatePuzzle(size, rng);
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
    return a10Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
  }

  int _resolveCellIndex(Map<String, dynamic> a) {
    if (a.containsKey('r') && a.containsKey('c')) {
      final r = asInt(a['r']);
      final c = asInt(a['c']);
      if (r < 0 || r >= size || c < 0 || c >= size) {
        throw GameError('行列坐标超出棋盘范围');
      }
      return r * size + c;
    }
    final idx = asInt(a['i']);
    if (idx < 0 || idx >= size * size) {
      throw GameError('格子索引超出棋盘范围');
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
      case 'set':
      case 'toggle':
        final idx = _resolveCellIndex(a);
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
        if (KenKenSolver.isSolved(currentPuzzle, p.board)) {
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
    host.log('${name(seat)} 第 $roundSolvers 个解出算术笼数独，+$pts 分！');
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
    final myBoard = me?.board ?? List<int>.filled(size * size, 0);
    final an = KenKenSolver.analyze(puz, myBoard);
    final totalCages = puz.cages.length;

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'cages': [for (final c in puz.cages) c.toJson()],
      'cageMap': puz.cageMap,
      'board': myBoard,
      'duplicates': an.duplicateCells.toList()..sort(),
      'violatedCells': an.violatedCells.toList()..sort(),
      'satisfiedCages': an.satisfiedCages.toList()..sort(),
      'violatedCages': an.violatedCages.toList()..sort(),
      'satisfiedCageCount': an.satisfiedCages.length,
      'totalCages': totalCages,
      'validLines': an.validLines,
      'totalLines': 2 * size,
      'filledCount': an.filledCount,
      'totalCells': size * size,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = KenKenSolver.analyze(puz, ps[s].board);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'satisfiedCages': pAn.satisfiedCages.length,
              'totalCages': totalCages,
              'filled': pAn.filledCount,
              'totalCells': size * size,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class KenKenPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  KenKenPlayer(int cellCount) : board = List<int>.filled(cellCount, 0);

  void resetForRound(int cellCount) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.filled(cellCount, 0);
  }
}
