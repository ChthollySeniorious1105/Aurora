import 'dart:math';

import '../../src/engine.dart';
import 'a5_util.dart';

class NonogramPattern {
  final String name;
  final int size;
  final List<String> rows;
  const NonogramPattern(this.name, this.size, this.rows);
}

class NonogramSolver {
  static const List<NonogramPattern> patterns5 = [
    NonogramPattern('爱心', 5, [
      '.#.#.',
      '#####',
      '#####',
      '.###.',
      '..#..',
    ]),
    NonogramPattern('皇冠', 5, [
      '#.#.#',
      '#####',
      '#####',
      '.###.',
      '#####',
    ]),
    NonogramPattern('小猫', 5, [
      '#...#',
      '#####',
      '#.#.#',
      '#####',
      '.###.',
    ]),
    NonogramPattern('飞船', 5, [
      '..#..',
      '.###.',
      '#####',
      '#.#.#',
      '#...#',
    ]),
    NonogramPattern('帆船', 5, [
      '..#..',
      '.##..',
      '..#..',
      '#####',
      '.###.',
    ]),
    NonogramPattern('音符', 5, [
      '..###',
      '..#.#',
      '..#.#',
      '.##..',
      '.##..',
    ]),
    NonogramPattern('宝剑', 5, [
      '..#..',
      '..#..',
      '#####',
      '..#..',
      '.###.',
    ]),
    NonogramPattern('松树', 5, [
      '..#..',
      '.###.',
      '#####',
      '..#..',
      '.###.',
    ]),
    NonogramPattern('笑脸', 5, [
      '.###.',
      '#.#.#',
      '#####',
      '#...#',
      '.###.',
    ]),
    NonogramPattern('钻石', 5, [
      '.###.',
      '#####',
      '#####',
      '.###.',
      '..#..',
    ]),
  ];

  static const List<NonogramPattern> patterns7 = [
    NonogramPattern('爱心', 7, [
      '.##.##.',
      '#######',
      '#######',
      '#######',
      '.#####.',
      '..###..',
      '...#...',
    ]),
    NonogramPattern('皇冠', 7, [
      '#..#..#',
      '##.#.##',
      '#######',
      '#.#.#.#',
      '#######',
      '.#####.',
      '#######',
    ]),
    NonogramPattern('小猫', 7, [
      '#.....#',
      '##...##',
      '#######',
      '#.#.#.#',
      '#######',
      '.#####.',
      '..###..',
    ]),
    NonogramPattern('飞船', 7, [
      '...#...',
      '..###..',
      '.#####.',
      '#######',
      '##.#.##',
      '#..#..#',
      '#.....#',
    ]),
    NonogramPattern('帆船', 7, [
      '...#...',
      '..##...',
      '.###...',
      '####...',
      '...#...',
      '#######',
      '.#####.',
    ]),
    NonogramPattern('音符', 7, [
      '..#####',
      '..#...#',
      '..#...#',
      '..#..##',
      '.##..##',
      '###....',
      '.##....',
    ]),
    NonogramPattern('宝剑', 7, [
      '...#...',
      '..###..',
      '..###..',
      '..###..',
      '#######',
      '...#...',
      '..###..',
    ]),
    NonogramPattern('松树', 7, [
      '...#...',
      '..###..',
      '.#####.',
      '..###..',
      '.#####.',
      '#######',
      '..###..',
    ]),
    NonogramPattern('笑脸', 7, [
      '.#####.',
      '#.....#',
      '#.#.#.#',
      '#.....#',
      '#.#.#.#',
      '#..#..#',
      '.#####.',
    ]),
    NonogramPattern('钻石', 7, [
      '.#####.',
      '#######',
      '##.#.##',
      '.#####.',
      '..###..',
      '...#...',
      '...#...',
    ]),
  ];

  static const List<NonogramPattern> patterns9 = [
    NonogramPattern('爱心', 9, [
      '.###.###.',
      '#########',
      '#########',
      '#########',
      '.#######.',
      '..#####..',
      '...###...',
      '....#....',
      '....#....',
    ]),
    NonogramPattern('皇冠', 9, [
      '#...#...#',
      '##..#..##',
      '###.#.###',
      '#########',
      '#.#.#.#.#',
      '#########',
      '.#######.',
      '.#######.',
      '#########',
    ]),
    NonogramPattern('小猫', 9, [
      '#.......#',
      '##.....##',
      '#########',
      '##.#.#.##',
      '#########',
      '###...###',
      '.#######.',
      '..#####..',
      '...###...',
    ]),
    NonogramPattern('飞船', 9, [
      '....#....',
      '...###...',
      '..#####..',
      '.###.###.',
      '#########',
      '#########',
      '##..#..##',
      '#...#...#',
      '#.......#',
    ]),
    NonogramPattern('帆船', 9, [
      '....#....',
      '...##....',
      '..###....',
      '.####....',
      '#####....',
      '....#....',
      '#########',
      '.#######.',
      '..#####..',
    ]),
    NonogramPattern('音符', 9, [
      '...######',
      '...######',
      '...#....#',
      '...#....#',
      '...#..###',
      '.###..###',
      '####...##',
      '####.....',
      '.##......',
    ]),
    NonogramPattern('宝剑', 9, [
      '....#....',
      '...###...',
      '...###...',
      '...###...',
      '...###...',
      '.#######.',
      '....#....',
      '....#....',
      '...###...',
    ]),
    NonogramPattern('松树', 9, [
      '....#....',
      '...###...',
      '..#####..',
      '...###...',
      '..#####..',
      '.#######.',
      '#########',
      '...###...',
      '...###...',
    ]),
    NonogramPattern('笑脸', 9, [
      '..#####..',
      '.#######.',
      '##.#.#.##',
      '#########',
      '#########',
      '##.#.#.##',
      '###...###',
      '.#######.',
      '..#####..',
    ]),
    NonogramPattern('钻石', 9, [
      '..#####..',
      '.#######.',
      '#########',
      '.#######.',
      '..#####..',
      '...###...',
      '....#....',
      '....#....',
      '....#....',
    ]),
  ];

  static List<NonogramPattern> bankForSize(int size) => switch (size) {
        5 => patterns5,
        9 => patterns9,
        _ => patterns7,
      };

  /// Computes the Nonogram clue for a single line (row or column).
  /// Counts contiguous segments where `val == 1`. Returns `[0]` if none.
  static List<int> computeLineClue(Iterable<int> line) {
    final runs = <int>[];
    var cur = 0;
    for (final v in line) {
      if (v == 1) {
        cur++;
      } else if (cur > 0) {
        runs.add(cur);
        cur = 0;
      }
    }
    if (cur > 0) runs.add(cur);
    return runs.isEmpty ? const [0] : runs;
  }

  /// Computes `(rowClues, colClues)` for a `size × size` grid.
  static (List<List<int>>, List<List<int>>) computeClues(List<int> grid, int size) {
    final rows = <List<int>>[];
    final cols = <List<int>>[];
    for (var r = 0; r < size; r++) {
      rows.add(computeLineClue([for (var c = 0; c < size; c++) grid[r * size + c]]));
    }
    for (var c = 0; c < size; c++) {
      cols.add(computeLineClue([for (var r = 0; r < size; r++) grid[r * size + c]]));
    }
    return (rows, cols);
  }

  static bool clueEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static List<bool> rowSatisfaction(List<int> board, int size, List<List<int>> rowClues) => [
        for (var r = 0; r < size; r++)
          clueEquals(
            computeLineClue([for (var c = 0; c < size; c++) board[r * size + c]]),
            rowClues[r],
          ),
      ];

  static List<bool> colSatisfaction(List<int> board, int size, List<List<int>> colClues) => [
        for (var c = 0; c < size; c++)
          clueEquals(
            computeLineClue([for (var r = 0; r < size; r++) board[r * size + c]]),
            colClues[c],
          ),
      ];

  /// Returns true if the filled cells (`val == 1`) on [board] satisfy all
  /// [rowClues] and [colClues].
  static bool isSolved(
    List<int> board,
    int size,
    List<List<int>> rowClues,
    List<List<int>> colClues,
  ) {
    if (board.length != size * size) return false;
    for (var r = 0; r < size; r++) {
      final line = [for (var c = 0; c < size; c++) board[r * size + c]];
      if (!clueEquals(computeLineClue(line), rowClues[r])) return false;
    }
    for (var c = 0; c < size; c++) {
      final line = [for (var r = 0; r < size; r++) board[r * size + c]];
      if (!clueEquals(computeLineClue(line), colClues[c])) return false;
    }
    return true;
  }

  /// Generates a themed pattern with procedural variation for [size].
  static (String, List<int>, List<List<int>>, List<List<int>>) generatePuzzle(
    int size,
    Random rng, {
    Set<String> usedNames = const {},
  }) {
    final bank = bankForSize(size);
    final available = [for (final p in bank) if (!usedNames.contains(p.name)) p];
    final pat = (available.isNotEmpty ? available : bank)[rng.nextInt((available.isNotEmpty ? available : bank).length)];

    final mirrorH = rng.nextBool();
    final grid = List<int>.filled(size * size, 0);
    for (var r = 0; r < size; r++) {
      final rowStr = pat.rows[r];
      for (var c = 0; c < size; c++) {
        final srcC = mirrorH ? (size - 1 - c) : c;
        grid[r * size + c] = rowStr[srcC] == '#' ? 1 : 0;
      }
    }

    // Procedural symmetric accent variation
    if (rng.nextBool()) {
      final ar = rng.nextInt(size);
      final ac = rng.nextInt((size + 1) ~/ 2);
      final mc = size - 1 - ac;
      final newVal = 1 - grid[ar * size + ac];
      grid[ar * size + ac] = newVal;
      grid[ar * size + mc] = newVal;
    }

    // Ensure at least 4 filled cells
    final filledCount = grid.where((x) => x == 1).length;
    if (filledCount < 4) {
      for (var i = 0; i < min(5, grid.length); i++) {
        grid[i] = 1;
      }
    }

    final (rClues, cClues) = computeClues(grid, size);
    return (pat.name, grid, rClues, cClues);
  }
}

/// 数织竞速 (Nonogram Race / Picross, 1-6 人).
class NonogramGame extends GameEngine {
  NonogramGame(super.setup);

  static const roundMaxSec = 600;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  String themeName = '';
  List<int> targetPattern = const [];
  List<List<int>> rowClues = const [];
  List<List<int>> colClues = const [];
  final Set<String> _usedThemes = {};

  late List<NonogramPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<List<int>> get boards => [for (final p in ps) p.board];
  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a5Placings(ranking, players) : null;

  @override
  bool get canResign => !over;

  @override
  int get botDelayMs => switch (botLevel) { 0 => 750, 2 => 260, _ => 450 };

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
    final rawSize = setup.opt<int>('size', 7);
    size = (rawSize == 5 || rawSize == 9) ? rawSize : 7;
    totalRounds = setup.opt<int>('rounds', 3) == 1 ? 1 : 3;

    ps = [for (var s = 0; s < players; s++) NonogramPlayer(size * size)];
    host.log('数织竞速开始（$size×$size 网格，共 $totalRounds 题）！根据行列数字线索推理涂黑像素格，最先满足所有线索者获最高分！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    final (tName, pattern, rClues, cClues) = NonogramSolver.generatePuzzle(
      size,
      rng,
      usedNames: _usedThemes,
    );
    themeName = tName;
    targetPattern = pattern;
    rowClues = rClues;
    colClues = cClues;
    _usedThemes.add(tName);

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
    return a5Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
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
        final idx = _resolveCellIndex(a);
        final val = asInt(a['val']);
        if (val < 0 || val > 2) throw GameError('单元格状态值必须为 0、1 或 2');
        p.board[idx] = val;
        moves++;
        if (NonogramSolver.isSolved(p.board, size, rowClues, colClues)) {
          _markSolved(seat);
        }

      case 'toggle':
        final idx = _resolveCellIndex(a);
        final cur = p.board[idx];
        if (a.containsKey('mode')) {
          final mode = asInt(a['mode'], 1) == 2 ? 2 : 1;
          p.board[idx] = cur == mode ? 0 : mode;
        } else {
          p.board[idx] = (cur + 1) % 3;
        }
        moves++;
        if (NonogramSolver.isSolved(p.board, size, rowClues, colClues)) {
          _markSolved(seat);
        }

      case 'reset':
      case 'clear':
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
    host.log('${name(seat)} 第 $roundSolvers 个织出图案「$themeName」，+$pts 分！');
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
      'theme': themeName,
      'reason': reason,
      'pattern': targetPattern,
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
    ranking = a5Ranking(players, (a, b) {
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
    host.log('游戏结束（$why）！冠军：${a5Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || !_activeInRound(seat)) return null;
    final p = ps[seat];

    // Easy bot occasionally gives up at the start of a round
    final anyMarked = p.board.any((v) => v != 0);
    if (botLevel <= 0 && !anyMarked && rng.nextInt(8) == 0) {
      return {'type': 'pass'};
    }

    // First fix any mistakenly filled cell (val == 1 where targetPattern == 0)
    for (var i = 0; i < p.board.length; i++) {
      if (p.board[i] == 1 && targetPattern[i] == 0) {
        return {'type': 'set', 'r': i ~/ size, 'c': i % size, 'val': 2};
      }
    }

    // Collect remaining cells that need to be filled (targetPattern == 1 and board != 1)
    final missing = <int>[];
    for (var i = 0; i < p.board.length; i++) {
      if (targetPattern[i] == 1 && p.board[i] != 1) {
        missing.add(i);
      }
    }
    if (missing.isNotEmpty) {
      final pick = missing[rng.nextInt(missing.length)];
      return {'type': 'set', 'r': pick ~/ size, 'c': pick % size, 'val': 1};
    }

    return {'type': 'pass'};
  }

  // ---------------------------------------------------------------- view

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players ? ps[seat] : (ps.isNotEmpty ? ps[0] : null);
    final myBoard = me?.board ?? List<int>.filled(size * size, 0);
    final rowOk = NonogramSolver.rowSatisfaction(myBoard, size, rowClues);
    final colOk = NonogramSolver.colSatisfaction(myBoard, size, colClues);
    final totalLines = size * 2;

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'themeHint': '像素谜题 #$round',
      'themeName': over ? themeName : null,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'rowClues': rowClues,
      'colClues': colClues,
      'board': myBoard,
      'rowOk': rowOk,
      'colOk': colOk,
      'ps': [
        for (var s = 0; s < players; s++)
          {
            'score': ps[s].score,
            'solved': ps[s].solvedCount,
            'status': ps[s].status,
            'rank': ps[s].solveRank,
            'pts': ps[s].lastRoundPts,
            'linesOk': NonogramSolver.rowSatisfaction(ps[s].board, size, rowClues).where((x) => x).length +
                NonogramSolver.colSatisfaction(ps[s].board, size, colClues).where((x) => x).length,
            'totalLines': totalLines,
          },
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class NonogramPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  NonogramPlayer(int cellCount) : board = List<int>.filled(cellCount, 0);

  void resetForRound(int cellCount) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.filled(cellCount, 0);
  }
}
