import 'dart:math';

import '../../src/engine.dart';
import 'a11_util.dart';

class SkyscrapersPuzzle {
  final int size;
  /// 2D `size × size` fixed interior clues (`0` = empty, `1..size` = given building height).
  final List<List<int>> clues;
  /// Top border visibility clues (`0..size-1` columns, looking top-to-bottom).
  final List<int> topClues;
  /// Bottom border visibility clues (`0..size-1` columns, looking bottom-to-top).
  final List<int> bottomClues;
  /// Left border visibility clues (`0..size-1` rows, looking left-to-right).
  final List<int> leftClues;
  /// Right border visibility clues (`0..size-1` rows, looking right-to-left).
  final List<int> rightClues;
  /// Flat `size * size` Latin Square solution of `1..size`.
  final List<int> solutionBoard;

  const SkyscrapersPuzzle({
    required this.size,
    required this.clues,
    required this.topClues,
    required this.bottomClues,
    required this.leftClues,
    required this.rightClues,
    required this.solutionBoard,
  });

  List<int> get cluesFlat => [
        for (var r = 0; r < size; r++)
          for (var c = 0; c < size; c++) clues[r][c],
      ];
}

class SkyscrapersAnalysis {
  final Set<int> duplicateCells;
  final Set<int> violatedCells;
  final Set<int> satisfiedTop;
  final Set<int> satisfiedBottom;
  final Set<int> satisfiedLeft;
  final Set<int> satisfiedRight;
  final Set<int> violatedTop;
  final Set<int> violatedBottom;
  final Set<int> violatedLeft;
  final Set<int> violatedRight;
  final int satisfiedClues;
  final int totalClues;
  final int validLines;
  final int filledCount;

  const SkyscrapersAnalysis({
    required this.duplicateCells,
    required this.violatedCells,
    required this.satisfiedTop,
    required this.satisfiedBottom,
    required this.satisfiedLeft,
    required this.satisfiedRight,
    required this.violatedTop,
    required this.violatedBottom,
    required this.violatedLeft,
    required this.violatedRight,
    required this.satisfiedClues,
    required this.totalClues,
    required this.validLines,
    required this.filledCount,
  });

  Set<int> get conflictCells => {...duplicateCells, ...violatedCells};

  bool get isSolved =>
      filledCount > 0 &&
      duplicateCells.isEmpty &&
      violatedCells.isEmpty &&
      satisfiedClues == totalClues;
}

class SkyscrapersSolver {
  /// Counts running-maximum peaks seen along [line].
  static int visibleCount(Iterable<int> line) {
    var maxH = 0;
    var count = 0;
    for (final h in line) {
      if (h > maxH) {
        maxH = h;
        count++;
      }
    }
    return count;
  }

  static SkyscrapersAnalysis analyze(SkyscrapersPuzzle puz, List<int> board) {
    final size = puz.size;
    final n = size * size;
    final duplicateCells = <int>{};
    final violatedCells = <int>{};
    final satisfiedTop = <int>{};
    final satisfiedBottom = <int>{};
    final satisfiedLeft = <int>{};
    final satisfiedRight = <int>{};
    final violatedTop = <int>{};
    final violatedBottom = <int>{};
    final violatedLeft = <int>{};
    final violatedRight = <int>{};

    var filledCount = 0;
    for (var i = 0; i < n; i++) {
      final v = i < board.length ? board[i] : 0;
      if (v >= 1 && v <= size) filledCount++;
      final r = i ~/ size, c = i % size;
      final fixed = puz.clues[r][c];
      if (fixed > 0 && v != fixed) {
        violatedCells.add(i);
      }
    }

    var validLines = 0;
    final rowCompleteFlags = List<bool>.filled(size, false);
    final colCompleteFlags = List<bool>.filled(size, false);

    // Check rows
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
      rowCompleteFlags[r] = rowComplete;
      if (rowComplete && rowNoDup && seen.length == size) {
        validLines++;
      }
    }

    // Check columns
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
      colCompleteFlags[c] = colComplete;
      if (colComplete && colNoDup && seen.length == size) {
        validLines++;
      }
    }

    var totalClues = 0;
    var satisfiedClues = 0;

    // Top and Bottom column clues
    for (var c = 0; c < size; c++) {
      final topClue = c < puz.topClues.length ? puz.topClues[c] : 0;
      if (topClue > 0) {
        totalClues++;
        if (colCompleteFlags[c]) {
          final vis = visibleCount([for (var r = 0; r < size; r++) board[r * size + c]]);
          if (vis == topClue) {
            satisfiedClues++;
            satisfiedTop.add(c);
          } else {
            violatedTop.add(c);
            for (var r = 0; r < size; r++) {
              violatedCells.add(r * size + c);
            }
          }
        }
      }

      final bottomClue = c < puz.bottomClues.length ? puz.bottomClues[c] : 0;
      if (bottomClue > 0) {
        totalClues++;
        if (colCompleteFlags[c]) {
          final vis = visibleCount([for (var r = size - 1; r >= 0; r--) board[r * size + c]]);
          if (vis == bottomClue) {
            satisfiedClues++;
            satisfiedBottom.add(c);
          } else {
            violatedBottom.add(c);
            for (var r = 0; r < size; r++) {
              violatedCells.add(r * size + c);
            }
          }
        }
      }
    }

    // Left and Right row clues
    for (var r = 0; r < size; r++) {
      final leftClue = r < puz.leftClues.length ? puz.leftClues[r] : 0;
      if (leftClue > 0) {
        totalClues++;
        if (rowCompleteFlags[r]) {
          final vis = visibleCount([for (var c = 0; c < size; c++) board[r * size + c]]);
          if (vis == leftClue) {
            satisfiedClues++;
            satisfiedLeft.add(r);
          } else {
            violatedLeft.add(r);
            for (var c = 0; c < size; c++) {
              violatedCells.add(r * size + c);
            }
          }
        }
      }

      final rightClue = r < puz.rightClues.length ? puz.rightClues[r] : 0;
      if (rightClue > 0) {
        totalClues++;
        if (rowCompleteFlags[r]) {
          final vis = visibleCount([for (var c = size - 1; c >= 0; c--) board[r * size + c]]);
          if (vis == rightClue) {
            satisfiedClues++;
            satisfiedRight.add(r);
          } else {
            violatedRight.add(r);
            for (var c = 0; c < size; c++) {
              violatedCells.add(r * size + c);
            }
          }
        }
      }
    }

    return SkyscrapersAnalysis(
      duplicateCells: duplicateCells,
      violatedCells: violatedCells,
      satisfiedTop: satisfiedTop,
      satisfiedBottom: satisfiedBottom,
      satisfiedLeft: satisfiedLeft,
      satisfiedRight: satisfiedRight,
      violatedTop: violatedTop,
      violatedBottom: violatedBottom,
      violatedLeft: violatedLeft,
      violatedRight: violatedRight,
      satisfiedClues: satisfiedClues,
      totalClues: totalClues,
      validLines: validLines,
      filledCount: filledCount,
    );
  }

  static bool isSolved(SkyscrapersPuzzle puz, List<int> board) {
    final size = puz.size;
    if (board.length != size * size) return false;
    final an = analyze(puz, board);
    return an.filledCount == size * size &&
        an.validLines == 2 * size &&
        an.duplicateCells.isEmpty &&
        an.violatedCells.isEmpty &&
        an.satisfiedClues == an.totalClues;
  }

  /// Generates a guaranteed-valid Skyscrapers puzzle for [size] (`4` or `5`).
  static SkyscrapersPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;

    // 1. Construct a randomized Latin Square of `1..size`
    final rowPerm = [for (var i = 0; i < size; i++) i]..shuffle(rng);
    final colPerm = [for (var i = 0; i < size; i++) i]..shuffle(rng);
    final symPerm = [for (var i = 1; i <= size; i++) i]..shuffle(rng);

    final sol = List<int>.filled(n, 1);
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        sol[r * size + c] = symPerm[(rowPerm[r] + colPerm[c]) % size];
      }
    }

    // Extra row/column swaps for variety
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

    // 2. Expose a few interior clue digits
    final clues = [
      for (var r = 0; r < size; r++) List<int>.filled(size, 0),
    ];
    final targetClues = size <= 4 ? 3 : 5;
    final cellOrder = [for (var i = 0; i < n; i++) i]..shuffle(rng);
    for (var i = 0; i < targetClues && i < cellOrder.length; i++) {
      final idx = cellOrder[i];
      final r = idx ~/ size, c = idx % size;
      clues[r][c] = sol[idx];
    }

    // 3. Compute the 4 border visibility clues
    final topClues = [
      for (var c = 0; c < size; c++)
        visibleCount([for (var r = 0; r < size; r++) sol[r * size + c]]),
    ];
    final bottomClues = [
      for (var c = 0; c < size; c++)
        visibleCount([for (var r = size - 1; r >= 0; r--) sol[r * size + c]]),
    ];
    final leftClues = [
      for (var r = 0; r < size; r++)
        visibleCount([for (var c = 0; c < size; c++) sol[r * size + c]]),
    ];
    final rightClues = [
      for (var r = 0; r < size; r++)
        visibleCount([for (var c = size - 1; c >= 0; c--) sol[r * size + c]]),
    ];

    return SkyscrapersPuzzle(
      size: size,
      clues: clues,
      topClues: topClues,
      bottomClues: bottomClues,
      leftClues: leftClues,
      rightClues: rightClues,
      solutionBoard: sol,
    );
  }
}

/// 摩天楼可见数竞速 (Skyscrapers Race, 1-6 人).
class SkyscrapersGame extends GameEngine {
  SkyscrapersGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late SkyscrapersPuzzle currentPuzzle;
  late List<SkyscrapersPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<List<int>> get boards => [for (final p in ps) p.board];
  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a11Placings(ranking, players) : null;

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

    currentPuzzle = SkyscrapersSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) SkyscrapersPlayer(currentPuzzle.cluesFlat)];

    host.log('摩天楼可见数竞速开始（$size×$size 街区，共 $totalRounds 题）！填入 1～$size 层楼高使行列无重复且匹配四周视线可见数！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = SkyscrapersSolver.generatePuzzle(size, rng);
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
    return a11Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
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
      case 'set':
      case 'toggle':
        final (r, c) = _resolveCell(a);
        if (currentPuzzle.clues[r][c] > 0) {
          throw GameError('题目固定楼高不可修改');
        }
        final idx = r * size + c;
        if (a.containsKey('val')) {
          final v = asInt(a['val']);
          if (v < 0 || v > size) {
            throw GameError('楼高必须在 0～$size 之间');
          }
          p.board[idx] = v;
        } else {
          p.board[idx] = (p.board[idx] + 1) % (size + 1);
        }
        moves++;
        if (SkyscrapersSolver.isSolved(currentPuzzle, p.board)) {
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
    host.log('${name(seat)} 第 $roundSolvers 个解出摩天楼谜题，+$pts 分！');
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
    ranking = a11Ranking(players, (a, b) {
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
    host.log('游戏结束（$why）！冠军：${a11Winners(ranking!, name)}');
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
    final an = SkyscrapersSolver.analyze(puz, myBoard);
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
      'topClues': puz.topClues,
      'bottomClues': puz.bottomClues,
      'leftClues': puz.leftClues,
      'rightClues': puz.rightClues,
      'board': myBoard,
      'duplicates': an.duplicateCells.toList()..sort(),
      'violatedCells': an.violatedCells.toList()..sort(),
      'satisfiedTop': an.satisfiedTop.toList()..sort(),
      'satisfiedBottom': an.satisfiedBottom.toList()..sort(),
      'satisfiedLeft': an.satisfiedLeft.toList()..sort(),
      'satisfiedRight': an.satisfiedRight.toList()..sort(),
      'violatedTop': an.violatedTop.toList()..sort(),
      'violatedBottom': an.violatedBottom.toList()..sort(),
      'violatedLeft': an.violatedLeft.toList()..sort(),
      'violatedRight': an.violatedRight.toList()..sort(),
      'satisfiedClues': an.satisfiedClues,
      'totalClues': an.totalClues,
      'validLines': an.validLines,
      'totalLines': 2 * size,
      'filledCount': an.filledCount,
      'totalCells': totalCells,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = SkyscrapersSolver.analyze(puz, ps[s].board);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'filled': pAn.filledCount,
              'totalCells': totalCells,
              'satisfiedClues': pAn.satisfiedClues,
              'totalClues': pAn.totalClues,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class SkyscrapersPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  SkyscrapersPlayer(List<int> initialClues) : board = List<int>.of(initialClues);

  void resetForRound(List<int> initialClues) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.of(initialClues);
  }
}
