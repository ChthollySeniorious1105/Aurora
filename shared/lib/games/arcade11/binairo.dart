import 'dart:math';

import '../../src/engine.dart';
import 'a11_util.dart';

class BinairoPuzzle {
  final int size;
  /// 2D `size × size` fixed clues (`0` = empty, `1` = ☀️ Sun, `2` = 🌙 Moon).
  final List<List<int>> clues;
  /// Flat `size * size` valid Binairo solution of `1` and `2`.
  final List<int> solutionBoard;

  const BinairoPuzzle({
    required this.size,
    required this.clues,
    required this.solutionBoard,
  });

  List<int> get cluesFlat => [
        for (var r = 0; r < size; r++)
          for (var c = 0; c < size; c++) clues[r][c],
      ];
}

class BinairoAnalysis {
  final Set<int> threeInRowCells;
  final Set<int> unbalancedCells;
  final Set<int> duplicateLineCells;
  final Set<int> violatedClueCells;
  final Set<int> duplicateRows;
  final Set<int> duplicateCols;
  final List<int> rowSunCounts;
  final List<int> rowMoonCounts;
  final List<int> colSunCounts;
  final List<int> colMoonCounts;
  final int validLines;
  final int filledCount;

  const BinairoAnalysis({
    required this.threeInRowCells,
    required this.unbalancedCells,
    required this.duplicateLineCells,
    required this.violatedClueCells,
    required this.duplicateRows,
    required this.duplicateCols,
    required this.rowSunCounts,
    required this.rowMoonCounts,
    required this.colSunCounts,
    required this.colMoonCounts,
    required this.validLines,
    required this.filledCount,
  });

  Set<int> get conflictCells => {
        ...threeInRowCells,
        ...unbalancedCells,
        ...duplicateLineCells,
        ...violatedClueCells,
      };

  bool get isSolved =>
      filledCount > 0 &&
      threeInRowCells.isEmpty &&
      unbalancedCells.isEmpty &&
      duplicateLineCells.isEmpty &&
      violatedClueCells.isEmpty;
}

class BinairoSolver {
  static BinairoAnalysis analyze(BinairoPuzzle puz, List<int> board) {
    final size = puz.size;
    final half = size ~/ 2;
    final n = size * size;

    final threeInRowCells = <int>{};
    final unbalancedCells = <int>{};
    final duplicateLineCells = <int>{};
    final violatedClueCells = <int>{};
    final duplicateRows = <int>{};
    final duplicateCols = <int>{};

    final rowSunCounts = List<int>.filled(size, 0);
    final rowMoonCounts = List<int>.filled(size, 0);
    final colSunCounts = List<int>.filled(size, 0);
    final colMoonCounts = List<int>.filled(size, 0);

    var filledCount = 0;
    for (var i = 0; i < n; i++) {
      final v = i < board.length ? board[i] : 0;
      final r = i ~/ size, c = i % size;
      if (v == 1) {
        filledCount++;
        rowSunCounts[r]++;
        colSunCounts[c]++;
      } else if (v == 2) {
        filledCount++;
        rowMoonCounts[r]++;
        colMoonCounts[c]++;
      }
      final fixed = puz.clues[r][c];
      if (fixed > 0 && v != fixed) {
        violatedClueCells.add(i);
      }
    }

    final rowHasThree = List<bool>.filled(size, false);
    final colHasThree = List<bool>.filled(size, false);

    // 1. Check horizontal 3-in-a-row
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size - 2; c++) {
        final i0 = r * size + c;
        final i1 = i0 + 1;
        final i2 = i0 + 2;
        final v0 = i0 < board.length ? board[i0] : 0;
        final v1 = i1 < board.length ? board[i1] : 0;
        final v2 = i2 < board.length ? board[i2] : 0;
        if ((v0 == 1 || v0 == 2) && v0 == v1 && v1 == v2) {
          threeInRowCells.addAll([i0, i1, i2]);
          rowHasThree[r] = true;
        }
      }
    }

    // 2. Check vertical 3-in-a-row
    for (var c = 0; c < size; c++) {
      for (var r = 0; r < size - 2; r++) {
        final i0 = r * size + c;
        final i1 = (r + 1) * size + c;
        final i2 = (r + 2) * size + c;
        final v0 = i0 < board.length ? board[i0] : 0;
        final v1 = i1 < board.length ? board[i1] : 0;
        final v2 = i2 < board.length ? board[i2] : 0;
        if ((v0 == 1 || v0 == 2) && v0 == v1 && v1 == v2) {
          threeInRowCells.addAll([i0, i1, i2]);
          colHasThree[c] = true;
        }
      }
    }

    // 3. Check row/column balance
    for (var r = 0; r < size; r++) {
      final suns = rowSunCounts[r], moons = rowMoonCounts[r];
      if (suns > half || moons > half || (suns + moons == size && (suns != half || moons != half))) {
        for (var c = 0; c < size; c++) {
          final idx = r * size + c;
          final v = idx < board.length ? board[idx] : 0;
          if (v == 1 || v == 2) unbalancedCells.add(idx);
        }
      }
    }

    for (var c = 0; c < size; c++) {
      final suns = colSunCounts[c], moons = colMoonCounts[c];
      if (suns > half || moons > half || (suns + moons == size && (suns != half || moons != half))) {
        for (var r = 0; r < size; r++) {
          final idx = r * size + c;
          final v = idx < board.length ? board[idx] : 0;
          if (v == 1 || v == 2) unbalancedCells.add(idx);
        }
      }
    }

    // 4. Check duplicate completed rows and columns
    for (var r1 = 0; r1 < size; r1++) {
      if (rowSunCounts[r1] + rowMoonCounts[r1] < size) continue;
      for (var r2 = r1 + 1; r2 < size; r2++) {
        if (rowSunCounts[r2] + rowMoonCounts[r2] < size) continue;
        var same = true;
        for (var c = 0; c < size; c++) {
          if (board[r1 * size + c] != board[r2 * size + c]) {
            same = false;
            break;
          }
        }
        if (same) {
          duplicateRows.add(r1);
          duplicateRows.add(r2);
          for (var c = 0; c < size; c++) {
            duplicateLineCells.add(r1 * size + c);
            duplicateLineCells.add(r2 * size + c);
          }
        }
      }
    }

    for (var c1 = 0; c1 < size; c1++) {
      if (colSunCounts[c1] + colMoonCounts[c1] < size) continue;
      for (var c2 = c1 + 1; c2 < size; c2++) {
        if (colSunCounts[c2] + colMoonCounts[c2] < size) continue;
        var same = true;
        for (var r = 0; r < size; r++) {
          if (board[r * size + c1] != board[r * size + c2]) {
            same = false;
            break;
          }
        }
        if (same) {
          duplicateCols.add(c1);
          duplicateCols.add(c2);
          for (var r = 0; r < size; r++) {
            duplicateLineCells.add(r * size + c1);
            duplicateLineCells.add(r * size + c2);
          }
        }
      }
    }

    var validLines = 0;
    for (var r = 0; r < size; r++) {
      if (rowSunCounts[r] == half &&
          rowMoonCounts[r] == half &&
          !rowHasThree[r] &&
          !duplicateRows.contains(r)) {
        validLines++;
      }
    }
    for (var c = 0; c < size; c++) {
      if (colSunCounts[c] == half &&
          colMoonCounts[c] == half &&
          !colHasThree[c] &&
          !duplicateCols.contains(c)) {
        validLines++;
      }
    }

    return BinairoAnalysis(
      threeInRowCells: threeInRowCells,
      unbalancedCells: unbalancedCells,
      duplicateLineCells: duplicateLineCells,
      violatedClueCells: violatedClueCells,
      duplicateRows: duplicateRows,
      duplicateCols: duplicateCols,
      rowSunCounts: rowSunCounts,
      rowMoonCounts: rowMoonCounts,
      colSunCounts: colSunCounts,
      colMoonCounts: colMoonCounts,
      validLines: validLines,
      filledCount: filledCount,
    );
  }

  static bool isSolved(BinairoPuzzle puz, List<int> board) {
    final size = puz.size;
    if (board.length != size * size) return false;
    final an = analyze(puz, board);
    return an.filledCount == size * size &&
        an.validLines == 2 * size &&
        an.threeInRowCells.isEmpty &&
        an.unbalancedCells.isEmpty &&
        an.duplicateLineCells.isEmpty &&
        an.violatedClueCells.isEmpty;
  }

  /// Enumerates all balanced row patterns of length [size] (`1` and `2`) with no 3-in-a-row.
  static List<List<int>> _validRowPatterns(int size) {
    final half = size ~/ 2;
    final out = <List<int>>[];
    final cur = List<int>.filled(size, 0);

    void dfs(int c, int suns, int moons) {
      if (c == size) {
        out.add(List<int>.of(cur));
        return;
      }
      for (var v = 1; v <= 2; v++) {
        if (v == 1 && suns >= half) continue;
        if (v == 2 && moons >= half) continue;
        if (c >= 2 && cur[c - 1] == v && cur[c - 2] == v) continue;
        cur[c] = v;
        dfs(c + 1, suns + (v == 1 ? 1 : 0), moons + (v == 2 ? 1 : 0));
      }
    }

    dfs(0, 0, 0);
    return out;
  }

  /// Generates a guaranteed-valid Binairo puzzle for even [size] (`4` or `6`).
  static BinairoPuzzle generatePuzzle(int size, Random rng) {
    final half = size ~/ 2;
    final n = size * size;
    final patterns = _validRowPatterns(size)..shuffle(rng);
    final chosenRows = List<int>.filled(size, -1);
    final usedPattern = List<bool>.filled(patterns.length, false);
    final colSuns = List<int>.filled(size, 0);
    final colMoons = List<int>.filled(size, 0);

    bool solveRows(int r) {
      if (r == size) {
        // Verify all columns are distinct
        for (var c1 = 0; c1 < size; c1++) {
          for (var c2 = c1 + 1; c2 < size; c2++) {
            var same = true;
            for (var rr = 0; rr < size; rr++) {
              if (patterns[chosenRows[rr]][c1] != patterns[chosenRows[rr]][c2]) {
                same = false;
                break;
              }
            }
            if (same) return false;
          }
        }
        return true;
      }

      for (var pIdx = 0; pIdx < patterns.length; pIdx++) {
        if (usedPattern[pIdx]) continue;
        final row = patterns[pIdx];
        var ok = true;
        for (var c = 0; c < size; c++) {
          final v = row[c];
          if (v == 1 && colSuns[c] + 1 > half) {
            ok = false;
            break;
          }
          if (v == 2 && colMoons[c] + 1 > half) {
            ok = false;
            break;
          }
          if (r >= 2 &&
              patterns[chosenRows[r - 1]][c] == v &&
              patterns[chosenRows[r - 2]][c] == v) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;

        usedPattern[pIdx] = true;
        chosenRows[r] = pIdx;
        for (var c = 0; c < size; c++) {
          if (row[c] == 1) {
            colSuns[c]++;
          } else {
            colMoons[c]++;
          }
        }

        if (solveRows(r + 1)) return true;

        for (var c = 0; c < size; c++) {
          if (row[c] == 1) {
            colSuns[c]--;
          } else {
            colMoons[c]--;
          }
        }
        usedPattern[pIdx] = false;
      }
      return false;
    }

    solveRows(0);

    final sol = List<int>.filled(n, 1);
    for (var r = 0; r < size; r++) {
      final row = patterns[chosenRows[r]];
      for (var c = 0; c < size; c++) {
        sol[r * size + c] = row[c];
      }
    }

    // Expose initial clue cells (around 40% of the board)
    final clues = [
      for (var r = 0; r < size; r++) List<int>.filled(size, 0),
    ];
    final targetClues = size <= 4 ? 6 : 14;
    final cellOrder = [for (var i = 0; i < n; i++) i]..shuffle(rng);
    for (var i = 0; i < targetClues && i < cellOrder.length; i++) {
      final idx = cellOrder[i];
      final r = idx ~/ size, c = idx % size;
      clues[r][c] = sol[idx];
    }

    return BinairoPuzzle(
      size: size,
      clues: clues,
      solutionBoard: sol,
    );
  }
}

/// 黑白平衡二进制竞速 (Binairo Race, 1-6 人).
class BinairoGame extends GameEngine {
  BinairoGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late BinairoPuzzle currentPuzzle;
  late List<BinairoPlayer> ps;
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
    final rawSize = setup.opt<int>('size', 6);
    size = rawSize == 4 ? 4 : 6;
    totalRounds = setup.opt<int>('rounds', 3) == 1 ? 1 : 3;

    currentPuzzle = BinairoSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) BinairoPlayer(currentPuzzle.cluesFlat)];

    host.log('黑白平衡二进制竞速开始（$size×$size 网格，共 $totalRounds 题）！填入 ☀️ 与 🌙 使无三连、阴阳各半且行列唯一！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = BinairoSolver.generatePuzzle(size, rng);
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
      case 'toggle':
      case 'set':
        final (r, c) = _resolveCell(a);
        if (currentPuzzle.clues[r][c] > 0) {
          throw GameError('题目固定线索格不可修改');
        }
        final idx = r * size + c;
        if (a.containsKey('val')) {
          final v = asInt(a['val']);
          if (v < 0 || v > 2) {
            throw GameError('格值必须在 0～2 之间');
          }
          p.board[idx] = v;
        } else {
          p.board[idx] = (p.board[idx] + 1) % 3;
        }
        moves++;
        if (BinairoSolver.isSolved(currentPuzzle, p.board)) {
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
    host.log('${name(seat)} 第 $roundSolvers 个解出黑白平衡二进制谜题，+$pts 分！');
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
    final myBoard = me?.board ?? puz.cluesFlat;
    final an = BinairoSolver.analyze(puz, myBoard);
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
      'threeInRowCells': an.threeInRowCells.toList()..sort(),
      'unbalancedCells': an.unbalancedCells.toList()..sort(),
      'duplicateLineCells': an.duplicateLineCells.toList()..sort(),
      'duplicateRows': an.duplicateRows.toList()..sort(),
      'duplicateCols': an.duplicateCols.toList()..sort(),
      'rowSunCounts': an.rowSunCounts,
      'rowMoonCounts': an.rowMoonCounts,
      'colSunCounts': an.colSunCounts,
      'colMoonCounts': an.colMoonCounts,
      'validLines': an.validLines,
      'totalLines': 2 * size,
      'filledCount': an.filledCount,
      'totalCells': totalCells,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = BinairoSolver.analyze(puz, ps[s].board);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'filled': pAn.filledCount,
              'totalCells': totalCells,
              'validLines': pAn.validLines,
              'totalLines': 2 * size,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class BinairoPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  BinairoPlayer(List<int> initialClues) : board = List<int>.of(initialClues);

  void resetForRound(List<int> initialClues) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.of(initialClues);
  }
}
