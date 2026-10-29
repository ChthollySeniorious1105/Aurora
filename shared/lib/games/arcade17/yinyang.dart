import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';
import 'a17_util.dart';

/// Validates whether [board] (flat `size * size` list of `0` empty, `1` White, `2` Black)
/// satisfies all three Nikoli Yin-Yang rules (and matches [clues] if provided):
/// 1. Every cell is filled (`1` or `2`).
/// 2. All White (`1`) cells form a single 4-connected component, and all Black (`2`) cells
///    form a single 4-connected component.
/// 3. No `2×2` subgrid is all White (`1,1,1,1`) or all Black (`2,2,2,2`).
bool validateYinYang(int size, List<int> board, [List<int>? clues]) {
  if (size <= 0 || board.length != size * size) return false;
  final n = size * size;
  var whiteCount = 0;
  var blackCount = 0;
  for (var i = 0; i < n; i++) {
    final v = board[i];
    if (v != 1 && v != 2) return false;
    if (clues != null && i < clues.length && clues[i] != 0 && clues[i] != v) {
      return false;
    }
    if (v == 1) {
      whiteCount++;
    } else {
      blackCount++;
    }
  }
  if (whiteCount == 0 || blackCount == 0) return false;
  if (YinYangSolver.findTwoByTwoSameColorCells(size, board).isNotEmpty) return false;
  if (YinYangSolver.countComponents(size, board, 1) != 1) return false;
  if (YinYangSolver.countComponents(size, board, 2) != 1) return false;
  return true;
}

class YinYangPuzzle {
  final int size;
  /// Flat `size * size` initial clues (`0` = empty, `1` = given White `⚪`, `2` = given Black `⚫`).
  final List<int> clues;
  /// Flat `size * size` valid full solution (`1` = White `⚪`, `2` = Black `⚫`).
  final List<int> solutionBoard;

  const YinYangPuzzle({
    required this.size,
    required this.clues,
    required this.solutionBoard,
  });

  List<int> get initialBoard => List<int>.of(clues);
}

class YinYangAnalysis {
  final int whiteCount;
  final int blackCount;
  final int emptyCount;
  final int whiteComponentCount;
  final int blackComponentCount;
  final bool isWhiteConnected;
  final bool isBlackConnected;
  final Set<int> twoByTwoWhiteCells;
  final Set<int> twoByTwoBlackCells;
  final Set<int> twoByTwoCells;
  final Set<int> clueConflictCells;
  final Set<int> conflictCells;
  final int satisfiedConditionCount;

  const YinYangAnalysis({
    required this.whiteCount,
    required this.blackCount,
    required this.emptyCount,
    required this.whiteComponentCount,
    required this.blackComponentCount,
    required this.isWhiteConnected,
    required this.isBlackConnected,
    required this.twoByTwoWhiteCells,
    required this.twoByTwoBlackCells,
    required this.twoByTwoCells,
    required this.clueConflictCells,
    required this.conflictCells,
    required this.satisfiedConditionCount,
  });

  bool get isSolved =>
      emptyCount == 0 &&
      whiteCount > 0 &&
      blackCount > 0 &&
      isWhiteConnected &&
      isBlackConnected &&
      twoByTwoCells.isEmpty &&
      clueConflictCells.isEmpty;
}

class YinYangSolver {
  static const List<int> orthoDr = [-1, 0, 1, 0];
  static const List<int> orthoDc = [0, 1, 0, -1];

  static const List<List<int>> _base5x5 = [
    [
      1, 1, 1, 1, 1, //
      1, 2, 2, 2, 1, //
      1, 2, 1, 2, 1, //
      1, 2, 1, 1, 1, //
      2, 2, 2, 2, 2, //
    ],
    [
      1, 1, 1, 1, 2, //
      1, 2, 2, 1, 2, //
      1, 2, 1, 1, 2, //
      1, 2, 2, 2, 2, //
      1, 1, 1, 1, 2, //
    ],
    [
      1, 1, 1, 1, 1, //
      2, 2, 2, 2, 1, //
      2, 1, 1, 2, 1, //
      2, 1, 2, 2, 1, //
      2, 1, 1, 1, 1, //
    ],
  ];

  static const List<List<int>> _base6x6 = [
    [
      1, 1, 1, 1, 1, 1, //
      1, 2, 2, 2, 2, 1, //
      1, 2, 1, 1, 2, 1, //
      1, 2, 1, 2, 2, 1, //
      1, 2, 1, 1, 1, 1, //
      2, 2, 2, 2, 2, 2, //
    ],
    [
      1, 1, 1, 1, 1, 2, //
      1, 2, 2, 2, 1, 2, //
      1, 2, 1, 2, 1, 2, //
      1, 2, 1, 1, 1, 2, //
      1, 2, 2, 2, 2, 2, //
      1, 1, 1, 1, 1, 2, //
    ],
    [
      1, 1, 1, 1, 1, 2, //
      1, 2, 2, 2, 1, 2, //
      1, 2, 1, 1, 1, 2, //
      1, 2, 1, 2, 2, 2, //
      1, 2, 1, 1, 1, 2, //
      1, 2, 2, 2, 2, 2, //
    ],
  ];

  /// Counts the number of 4-connected orthogonal components of cells with value [color].
  static int countComponents(int size, List<int> board, int color) {
    final n = size * size;
    final visited = List<bool>.filled(n, false);
    var comps = 0;
    for (var start = 0; start < n; start++) {
      if (start >= board.length || board[start] != color || visited[start]) continue;
      comps++;
      final q = Queue<int>()..add(start);
      visited[start] = true;
      while (q.isNotEmpty) {
        final cur = q.removeFirst();
        final r = cur ~/ size, c = cur % size;
        for (var d = 0; d < 4; d++) {
          final nr = r + orthoDr[d], nc = c + orthoDc[d];
          if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
          final nxt = nr * size + nc;
          if (!visited[nxt] && nxt < board.length && board[nxt] == color) {
            visited[nxt] = true;
            q.add(nxt);
          }
        }
      }
    }
    return comps;
  }

  /// Returns all flat cell indices belonging to any `2×2` subgrid of identical non-zero color.
  static Set<int> findTwoByTwoSameColorCells(int size, List<int> board, [int? filterColor]) {
    final out = <int>{};
    for (var r = 0; r < size - 1; r++) {
      for (var c = 0; c < size - 1; c++) {
        final i00 = r * size + c;
        final i01 = r * size + (c + 1);
        final i10 = (r + 1) * size + c;
        final i11 = (r + 1) * size + (c + 1);
        if (i11 >= board.length) continue;
        final v = board[i00];
        if (v != 1 && v != 2) continue;
        if (filterColor != null && v != filterColor) continue;
        if (board[i01] == v && board[i10] == v && board[i11] == v) {
          out
            ..add(i00)
            ..add(i01)
            ..add(i10)
            ..add(i11);
        }
      }
    }
    return out;
  }

  static YinYangAnalysis analyze(YinYangPuzzle puz, List<int> board) {
    final size = puz.size;
    final n = size * size;
    var whiteCount = 0;
    var blackCount = 0;
    var emptyCount = 0;
    final clueConflictCells = <int>{};

    for (var i = 0; i < n; i++) {
      final v = i < board.length ? board[i] : 0;
      if (v == 1) {
        whiteCount++;
      } else if (v == 2) {
        blackCount++;
      } else {
        emptyCount++;
      }
      if (i < puz.clues.length && puz.clues[i] != 0 && v != puz.clues[i]) {
        clueConflictCells.add(i);
      }
    }

    final twoByTwoWhiteCells = findTwoByTwoSameColorCells(size, board, 1);
    final twoByTwoBlackCells = findTwoByTwoSameColorCells(size, board, 2);
    final twoByTwoCells = <int>{...twoByTwoWhiteCells, ...twoByTwoBlackCells};
    final conflictCells = <int>{...twoByTwoCells, ...clueConflictCells};

    final whiteComps = countComponents(size, board, 1);
    final blackComps = countComponents(size, board, 2);
    final isWhiteConnected = whiteCount > 0 && whiteComps == 1;
    final isBlackConnected = blackCount > 0 && blackComps == 1;

    var sat = 0;
    if (emptyCount == 0) sat++;
    if (isWhiteConnected) sat++;
    if (isBlackConnected) sat++;
    if (twoByTwoCells.isEmpty) sat++;

    return YinYangAnalysis(
      whiteCount: whiteCount,
      blackCount: blackCount,
      emptyCount: emptyCount,
      whiteComponentCount: whiteComps,
      blackComponentCount: blackComps,
      isWhiteConnected: isWhiteConnected,
      isBlackConnected: isBlackConnected,
      twoByTwoWhiteCells: twoByTwoWhiteCells,
      twoByTwoBlackCells: twoByTwoBlackCells,
      twoByTwoCells: twoByTwoCells,
      clueConflictCells: clueConflictCells,
      conflictCells: conflictCells,
      satisfiedConditionCount: sat,
    );
  }

  static bool isSolved(YinYangPuzzle puz, List<int> board) =>
      validateYinYang(puz.size, board, puz.clues);

  static List<int> _transformSolution(
    int size,
    List<int> base, {
    required int rot,
    required bool flipH,
    required bool swapColors,
  }) {
    final out = List<int>.filled(size * size, 1);
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        var nr = r, nc = c;
        for (var k = 0; k < (rot % 4); k++) {
          final tr = nc;
          final tc = size - 1 - nr;
          nr = tr;
          nc = tc;
        }
        if (flipH) {
          nc = size - 1 - nc;
        }
        var v = base[r * size + c];
        if (swapColors) {
          v = v == 1 ? 2 : 1;
        }
        out[nr * size + nc] = v;
      }
    }
    return out;
  }

  /// Generates a guaranteed-valid Yin-Yang puzzle for [size] (`5` or `6`).
  static YinYangPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    final bank = size <= 5 ? _base5x5 : _base6x6;
    final base = bank[rng.nextInt(bank.length)];
    final sol = _transformSolution(
      size,
      base,
      rot: rng.nextInt(4),
      flipH: rng.nextBool(),
      swapColors: rng.nextBool(),
    );

    // Reveal ~42% of cells as locked clues, ensuring both White (1) and Black (2) clues appear
    final indices = [for (var i = 0; i < n; i++) i]..shuffle(rng);
    final clueCount = (n * 0.42).round().clamp(8, n - 6);
    final clues = List<int>.filled(n, 0);
    for (var k = 0; k < clueCount; k++) {
      final idx = indices[k];
      clues[idx] = sol[idx];
    }
    // Ensure at least one White clue and at least one Black clue
    if (!clues.contains(1)) {
      final wIdx = indices.firstWhere((i) => sol[i] == 1);
      clues[wIdx] = 1;
    }
    if (!clues.contains(2)) {
      final bIdx = indices.firstWhere((i) => sol[i] == 2);
      clues[bIdx] = 2;
    }

    return YinYangPuzzle(
      size: size,
      clues: clues,
      solutionBoard: sol,
    );
  }
}

/// 阴阳连通竞速 (Yin-Yang Race, 1-6 人).
class YinYangGame extends GameEngine {
  YinYangGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late YinYangPuzzle currentPuzzle;
  late List<YinYangPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<List<int>> get boards => [for (final p in ps) p.board];
  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a17Placings(ranking, players) : null;

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

    currentPuzzle = YinYangSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) YinYangPlayer(currentPuzzle.initialBoard)];

    host.log('阴阳连通竞速开始（$size×$size 网格，共 $totalRounds 题）！填满黑白圆，确保白圆整体连通、黑圆整体连通且无 2×2 同色！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = YinYangSolver.generatePuzzle(size, rng);
    }
    for (var s = 0; s < players; s++) {
      ps[s].resetForRound(currentPuzzle.initialBoard);
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
    return a17Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
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
      case 'cycle':
      case 'toggle':
        final (r, c) = _resolveCell(a);
        final idx = r * size + c;
        if (currentPuzzle.clues[idx] != 0) {
          throw GameError('初始线索格不可修改');
        }
        if (type == 'set' || a.containsKey('val')) {
          final v = asInt(a['val'], -1);
          if (v < 0 || v > 2) {
            throw GameError('格子状态必须在 0～2 之间（0=空，1=白圆，2=黑圆）');
          }
          p.board[idx] = v;
        } else {
          p.board[idx] = (p.board[idx] + 1) % 3;
        }
        moves++;
        if (YinYangSolver.isSolved(currentPuzzle, p.board)) {
          _markSolved(seat);
        }

      case 'clear':
      case 'reset':
        final init = currentPuzzle.initialBoard;
        for (var i = 0; i < init.length; i++) {
          p.board[i] = init[i];
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
    host.log('${name(seat)} 第 $roundSolvers 个解出阴阳连通谜题，+$pts 分！');
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
    ranking = a17Ranking(players, (a, b) {
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
    host.log('游戏结束（$why）！冠军：${a17Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || !_activeInRound(seat)) return null;
    final p = ps[seat];
    final puz = currentPuzzle;
    final sol = puz.solutionBoard;

    if (botLevel <= 0 && rng.nextInt(15) == 0) {
      return {'type': 'pass'};
    }

    final diff = <int>[
      for (var i = 0; i < sol.length; i++)
        if (puz.clues[i] == 0 && p.board[i] != sol[i]) i,
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
    final an = YinYangSolver.analyze(puz, myBoard);
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
      'board': myBoard,
      'whiteCount': an.whiteCount,
      'blackCount': an.blackCount,
      'emptyCount': an.emptyCount,
      'filledCount': totalCells - an.emptyCount,
      'totalCells': totalCells,
      'whiteComponentCount': an.whiteComponentCount,
      'blackComponentCount': an.blackComponentCount,
      'isWhiteConnected': an.isWhiteConnected,
      'isBlackConnected': an.isBlackConnected,
      'twoByTwoWhiteCells': an.twoByTwoWhiteCells.toList()..sort(),
      'twoByTwoBlackCells': an.twoByTwoBlackCells.toList()..sort(),
      'twoByTwoCells': an.twoByTwoCells.toList()..sort(),
      'conflictCells': an.conflictCells.toList()..sort(),
      'satisfiedConditionCount': an.satisfiedConditionCount,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = YinYangSolver.analyze(puz, ps[s].board);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'filledCount': totalCells - pAn.emptyCount,
              'totalCells': totalCells,
              'satisfiedConditionCount': pAn.satisfiedConditionCount,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class YinYangPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  YinYangPlayer(List<int> initialBoard) : board = List<int>.of(initialBoard);

  void resetForRound(List<int> initialBoard) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.of(initialBoard);
  }
}
