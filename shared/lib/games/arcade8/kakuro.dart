import 'dart:math';

import '../../src/engine.dart';
import 'a8_util.dart';

class KakuroRun {
  final bool isAcross;
  final int clueCell;
  final int targetSum;
  final List<int> cells;

  const KakuroRun({
    required this.isAcross,
    required this.clueCell,
    required this.targetSum,
    required this.cells,
  });
}

class KakuroPuzzle {
  final int size;
  final List<bool> isWhite;
  final List<int> acrossClues;
  final List<int> downClues;
  final List<int> solutionBoard;

  const KakuroPuzzle({
    required this.size,
    required this.isWhite,
    required this.acrossClues,
    required this.downClues,
    required this.solutionBoard,
  });
}

class KakuroAnalysis {
  final int filledWhite;
  final int totalWhite;
  final Set<int> conflictCells;
  final Map<int, bool> acrossOk;
  final Map<int, bool> downOk;
  final int okRuns;
  final int totalRuns;

  const KakuroAnalysis({
    required this.filledWhite,
    required this.totalWhite,
    required this.conflictCells,
    required this.acrossOk,
    required this.downOk,
    required this.okRuns,
    required this.totalRuns,
  });

  bool get isSolved =>
      totalWhite > 0 &&
      filledWhite == totalWhite &&
      conflictCells.isEmpty &&
      totalRuns > 0 &&
      okRuns == totalRuns;
}

class KakuroSolver {
  static List<KakuroRun> extractRuns(
    List<bool> isWhite,
    List<int> acrossClues,
    List<int> downClues,
    int size,
  ) {
    final runs = <KakuroRun>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final idx = r * size + c;
        if (isWhite[idx]) continue;

        if (c + 1 < size && isWhite[r * size + (c + 1)]) {
          final cells = <int>[];
          var cc = c + 1;
          while (cc < size && isWhite[r * size + cc]) {
            cells.add(r * size + cc);
            cc++;
          }
          runs.add(KakuroRun(
            isAcross: true,
            clueCell: idx,
            targetSum: acrossClues[idx],
            cells: cells,
          ));
        }

        if (r + 1 < size && isWhite[(r + 1) * size + c]) {
          final cells = <int>[];
          var rr = r + 1;
          while (rr < size && isWhite[rr * size + c]) {
            cells.add(rr * size + c);
            rr++;
          }
          runs.add(KakuroRun(
            isAcross: false,
            clueCell: idx,
            targetSum: downClues[idx],
            cells: cells,
          ));
        }
      }
    }
    return runs;
  }

  static KakuroAnalysis analyze(KakuroPuzzle puz, List<int> board) {
    final n = puz.size * puz.size;
    var filledWhite = 0;
    var totalWhite = 0;
    final conflicts = <int>{};

    for (var i = 0; i < n; i++) {
      if (puz.isWhite[i]) {
        totalWhite++;
        final v = i < board.length ? board[i] : 0;
        if (v >= 1 && v <= 9) {
          filledWhite++;
        } else if (v != 0) {
          conflicts.add(i);
        }
      }
    }

    final runs = extractRuns(puz.isWhite, puz.acrossClues, puz.downClues, puz.size);
    final acrossOk = <int, bool>{};
    final downOk = <int, bool>{};
    var okRuns = 0;

    for (final run in runs) {
      var sum = 0;
      var allFilled = true;
      var hasDup = false;
      final seen = <int, int>{};

      for (final cellIdx in run.cells) {
        final v = cellIdx < board.length ? board[cellIdx] : 0;
        if (v >= 1 && v <= 9) {
          sum += v;
          if (seen.containsKey(v)) {
            hasDup = true;
            conflicts.add(cellIdx);
            conflicts.add(seen[v]!);
          } else {
            seen[v] = cellIdx;
          }
        } else {
          allFilled = false;
        }
      }

      if (sum > run.targetSum || (allFilled && sum != run.targetSum)) {
        for (final cellIdx in run.cells) {
          if (cellIdx < board.length && board[cellIdx] > 0) {
            conflicts.add(cellIdx);
          }
        }
      }

      final ok = allFilled && !hasDup && sum == run.targetSum;
      if (run.isAcross) {
        acrossOk[run.clueCell] = ok;
      } else {
        downOk[run.clueCell] = ok;
      }
      if (ok) okRuns++;
    }

    return KakuroAnalysis(
      filledWhite: filledWhite,
      totalWhite: totalWhite,
      conflictCells: conflicts,
      acrossOk: acrossOk,
      downOk: downOk,
      okRuns: okRuns,
      totalRuns: runs.length,
    );
  }

  static bool isSolved(KakuroPuzzle puz, List<int> board) {
    if (board.length != puz.size * puz.size) return false;
    return analyze(puz, board).isSolved;
  }

  static const List<List<int>> _templates5 = [
    // Template 0: 4x4 interior with black corners (1,4) and (4,1)
    [
      0, 0, 0, 0, 0,
      0, 1, 1, 1, 0,
      0, 1, 1, 1, 1,
      0, 1, 1, 1, 1,
      0, 0, 1, 1, 1,
    ],
    // Template 1: 4x4 interior with black corners (1,1) and (4,4)
    [
      0, 0, 0, 0, 0,
      0, 0, 1, 1, 1,
      0, 1, 1, 1, 1,
      0, 1, 1, 1, 1,
      0, 1, 1, 1, 0,
    ],
    // Template 2: 4x4 interior with (1,1),(1,2) and (4,3),(4,4) black
    [
      0, 0, 0, 0, 0,
      0, 0, 0, 1, 1,
      0, 1, 1, 1, 1,
      0, 1, 1, 1, 1,
      0, 1, 1, 0, 0,
    ],
    // Template 3: 4x4 interior with (1,4),(2,4) and (3,1),(4,1) black
    [
      0, 0, 0, 0, 0,
      0, 1, 1, 1, 0,
      0, 1, 1, 1, 0,
      0, 0, 1, 1, 1,
      0, 0, 1, 1, 1,
    ],
  ];

  static const List<List<int>> _templates6 = [
    // Template 0: 5x5 interior with center black (3,3) and corners (1,5), (5,1)
    [
      0, 0, 0, 0, 0, 0,
      0, 1, 1, 1, 1, 0,
      0, 1, 1, 1, 1, 1,
      0, 1, 1, 0, 1, 1,
      0, 1, 1, 1, 1, 1,
      0, 0, 1, 1, 1, 1,
    ],
    // Template 1: 5x5 interior with center black (3,3) and corners (1,1), (5,5)
    [
      0, 0, 0, 0, 0, 0,
      0, 0, 1, 1, 1, 1,
      0, 1, 1, 1, 1, 1,
      0, 1, 1, 0, 1, 1,
      0, 1, 1, 1, 1, 1,
      0, 1, 1, 1, 1, 0,
    ],
    // Template 2: 5x5 interior with center black (3,3) and (1,4),(1,5), (5,1),(5,2)
    [
      0, 0, 0, 0, 0, 0,
      0, 1, 1, 1, 0, 0,
      0, 1, 1, 1, 1, 1,
      0, 1, 1, 0, 1, 1,
      0, 1, 1, 1, 1, 1,
      0, 0, 0, 1, 1, 1,
    ],
    // Template 3: 5x5 interior with (2,2) and (4,4) black
    [
      0, 0, 0, 0, 0, 0,
      0, 0, 1, 1, 1, 1,
      0, 0, 0, 1, 1, 1,
      0, 1, 1, 1, 1, 1,
      0, 1, 1, 1, 0, 0,
      0, 1, 1, 1, 1, 0,
    ],
  ];

  static bool _fillDigits(
    List<int> whiteCells,
    int pos,
    List<bool> isWhite,
    List<int> board,
    int size,
    Random rng,
  ) {
    if (pos >= whiteCells.length) return true;
    final idx = whiteCells[pos];
    final r = idx ~/ size;
    final c = idx % size;

    // Collect digits already used in the current horizontal and vertical runs
    final used = <int>{};
    for (var cc = c - 1; cc >= 0 && isWhite[r * size + cc]; cc--) {
      final v = board[r * size + cc];
      if (v > 0) used.add(v);
    }
    for (var cc = c + 1; cc < size && isWhite[r * size + cc]; cc++) {
      final v = board[r * size + cc];
      if (v > 0) used.add(v);
    }
    for (var rr = r - 1; rr >= 0 && isWhite[rr * size + c]; rr--) {
      final v = board[rr * size + c];
      if (v > 0) used.add(v);
    }
    for (var rr = r + 1; rr < size && isWhite[rr * size + c]; rr++) {
      final v = board[rr * size + c];
      if (v > 0) used.add(v);
    }

    final digits = [1, 2, 3, 4, 5, 6, 7, 8, 9]..shuffle(rng);
    for (final d in digits) {
      if (used.contains(d)) continue;
      board[idx] = d;
      if (_fillDigits(whiteCells, pos + 1, isWhite, board, size, rng)) return true;
      board[idx] = 0;
    }
    return false;
  }

  /// Generates a 100% guaranteed-valid Kakuro puzzle for [size] (`5` or `6`).
  static KakuroPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    final templates = size <= 5 ? _templates5 : _templates6;
    final mask = templates[rng.nextInt(templates.length)];
    final isWhite = [for (final v in mask) v == 1];
    final whiteCells = [
      for (var i = 0; i < n; i++)
        if (isWhite[i]) i,
    ];

    final solBoard = List<int>.filled(n, 0);
    _fillDigits(whiteCells, 0, isWhite, solBoard, size, rng);

    final acrossClues = List<int>.filled(n, 0);
    final downClues = List<int>.filled(n, 0);

    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final idx = r * size + c;
        if (isWhite[idx]) continue;

        if (c + 1 < size && isWhite[r * size + (c + 1)]) {
          var sum = 0;
          var cc = c + 1;
          while (cc < size && isWhite[r * size + cc]) {
            sum += solBoard[r * size + cc];
            cc++;
          }
          acrossClues[idx] = sum;
        }

        if (r + 1 < size && isWhite[(r + 1) * size + c]) {
          var sum = 0;
          var rr = r + 1;
          while (rr < size && isWhite[rr * size + c]) {
            sum += solBoard[rr * size + c];
            rr++;
          }
          downClues[idx] = sum;
        }
      }
    }

    return KakuroPuzzle(
      size: size,
      isWhite: isWhite,
      acrossClues: acrossClues,
      downClues: downClues,
      solutionBoard: solBoard,
    );
  }
}

/// 数和填字竞速 (Kakuro Race, 1-6 人).
class KakuroGame extends GameEngine {
  KakuroGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late KakuroPuzzle currentPuzzle;
  late List<KakuroPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<List<int>> get boards => [for (final p in ps) p.board];
  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a8Placings(ranking, players) : null;

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

    currentPuzzle = KakuroSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) KakuroPlayer(size * size)];

    host.log('数和填字竞速开始（$size×$size 网格，共 $totalRounds 题）！填入 1～9 使各横向与纵向区段和等于线索且无重复数字！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = KakuroSolver.generatePuzzle(size, rng);
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
    return a8Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
  }

  int _resolveWhiteCellIndex(Map<String, dynamic> a) {
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
    if (!currentPuzzle.isWhite[idx]) {
      throw GameError('黑色线索格不能填入数字');
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
        final idx = _resolveWhiteCellIndex(a);
        final val = asInt(a['val']);
        if (val < 0 || val > 9) {
          throw GameError('数字必须为 1～9（或 0 清除）');
        }
        p.board[idx] = val;
        moves++;
        if (KakuroSolver.isSolved(currentPuzzle, p.board)) {
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
    host.log('${name(seat)} 第 $roundSolvers 个完成数和填字，+$pts 分！');
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
    final sol = currentPuzzle.solutionBoard;

    final anyFilled = p.board.any((v) => v != 0);
    if (botLevel <= 0 && !anyFilled && rng.nextInt(8) == 0) {
      return {'type': 'pass'};
    }

    final diff = <int>[
      for (var i = 0; i < sol.length; i++)
        if (currentPuzzle.isWhite[i] && p.board[i] != sol[i]) i,
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
    final analysis = KakuroSolver.analyze(puz, myBoard);

    final acrossOkList = <bool>[
      for (var i = 0; i < size * size; i++)
        puz.acrossClues[i] > 0 ? (analysis.acrossOk[i] ?? false) : false,
    ];
    final downOkList = <bool>[
      for (var i = 0; i < size * size; i++)
        puz.downClues[i] > 0 ? (analysis.downOk[i] ?? false) : false,
    ];

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'isWhite': puz.isWhite,
      'acrossClues': puz.acrossClues,
      'downClues': puz.downClues,
      'board': myBoard,
      'conflicts': analysis.conflictCells.toList()..sort(),
      'acrossOk': acrossOkList,
      'downOk': downOkList,
      'filledWhite': analysis.filledWhite,
      'totalWhite': max(1, analysis.totalWhite),
      'okRuns': analysis.okRuns,
      'totalRuns': max(1, analysis.totalRuns),
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = KakuroSolver.analyze(puz, ps[s].board);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'okRuns': pAn.okRuns,
              'totalRuns': max(1, pAn.totalRuns),
              'filled': pAn.filledWhite,
              'totalWhite': max(1, pAn.totalWhite),
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class KakuroPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  KakuroPlayer(int cellCount) : board = List<int>.filled(cellCount, 0);

  void resetForRound(int cellCount) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.filled(cellCount, 0);
  }
}
