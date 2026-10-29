import 'dart:collection';

import '../../src/engine.dart';
import 'a6_util.dart';

class KlotskiPiece {
  final int id; // 0: 曹操(2x2), 1..5: 五虎上将(1x2 or 2x1), 6..9: 兵卒(1x1)
  final String name;
  final int r;
  final int c;
  final int w;
  final int h;

  const KlotskiPiece({
    required this.id,
    required this.name,
    required this.r,
    required this.c,
    required this.w,
    required this.h,
  });

  KlotskiPiece copyWith({int? r, int? c}) => KlotskiPiece(
        id: id,
        name: name,
        r: r ?? this.r,
        c: c ?? this.c,
        w: w,
        h: h,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'r': r,
        'c': c,
        'w': w,
        'h': h,
      };
}

class KlotskiMove {
  final int piece;
  final int dir; // 0:上, 1:右, 2:下, 3:左
  const KlotskiMove(this.piece, this.dir);

  Map<String, dynamic> toJson() => {'piece': piece, 'dir': dir};
}

class KlotskiLevel {
  final int id;
  final String name;
  final String difficulty; // 'easy' (8..16 steps) | 'classic' (18..40 steps)
  final List<KlotskiPiece> pieces;
  final List<KlotskiMove> solution;

  const KlotskiLevel({
    required this.id,
    required this.name,
    required this.difficulty,
    required this.pieces,
    required this.solution,
  });

  int get parSteps => solution.length;
}

class KlotskiSolver {
  static const int boardW = 4;
  static const int boardH = 5;
  static const int targetR = 3;
  static const int targetC = 1;

  static const List<int> dr = [-1, 0, 1, 0];
  static const List<int> dc = [0, 1, 0, -1];

  static int oppositeDir(int dir) => dir ^ 2;

  static int mirrorDirH(int dir) => (dir == 1 || dir == 3) ? (dir ^ 2) : dir;

  static List<KlotskiPiece> mirrorPiecesH(List<KlotskiPiece> pieces) => [
        for (final p in pieces) p.copyWith(c: boardW - p.w - p.c),
      ];

  static List<KlotskiMove> mirrorMovesH(List<KlotskiMove> moves) => [
        for (final m in moves) KlotskiMove(m.piece, mirrorDirH(m.dir)),
      ];

  /// Checks that all pieces lie within the 4×5 grid and no two pieces overlap.
  static bool isValidLayout(List<KlotskiPiece> pieces) {
    final grid = List<int>.filled(boardW * boardH, -1);
    var hasCaoCao = false;
    for (final p in pieces) {
      if (p.id < 0 || p.id > 9) return false;
      if (p.id == 0) {
        if (p.w != 2 || p.h != 2) return false;
        hasCaoCao = true;
      } else if (p.id >= 1 && p.id <= 5) {
        if (!((p.w == 2 && p.h == 1) || (p.w == 1 && p.h == 2))) return false;
      } else {
        if (p.w != 1 || p.h != 1) return false;
      }
      if (p.r < 0 || p.c < 0 || p.r + p.h > boardH || p.c + p.w > boardW) {
        return false;
      }
      for (var rr = p.r; rr < p.r + p.h; rr++) {
        for (var cc = p.c; cc < p.c + p.w; cc++) {
          final idx = rr * boardW + cc;
          if (grid[idx] != -1) return false;
          grid[idx] = p.id;
        }
      }
    }
    return hasCaoCao;
  }

  /// Returns true if Cao Cao (piece 0) is at the bottom-center exit `(r: 3, c: 1)`.
  static bool isSolved(List<KlotskiPiece> pieces) {
    for (final p in pieces) {
      if (p.id == 0) {
        return p.r == targetR && p.c == targetC;
      }
    }
    return false;
  }

  /// Attempts to slide [pieceId] by 1 cell in direction [dir] (`0..3`).
  /// Returns a new piece list if legal, or `null` if out of bounds or blocked.
  static List<KlotskiPiece>? trySlide(List<KlotskiPiece> pieces, int pieceId, int dir) {
    if (dir < 0 || dir >= 4) return null;
    final idx = pieces.indexWhere((p) => p.id == pieceId);
    if (idx < 0) return null;
    final target = pieces[idx];
    final nr = target.r + dr[dir];
    final nc = target.c + dc[dir];
    if (nr < 0 || nc < 0 || nr + target.h > boardH || nc + target.w > boardW) {
      return null;
    }

    for (var i = 0; i < pieces.length; i++) {
      if (i == idx) continue;
      final other = pieces[i];
      final overlapR = nr < other.r + other.h && nr + target.h > other.r;
      final overlapC = nc < other.c + other.w && nc + target.w > other.c;
      if (overlapR && overlapC) return null;
    }

    final next = List<KlotskiPiece>.of(pieces);
    next[idx] = target.copyWith(r: nr, c: nc);
    return next;
  }

  /// Builds a level by starting from [solvedPieces] (where Cao Cao is at `(3,1)`)
  /// and applying [reverseMoves] to obtain the initial layout, while the exact
  /// reversed sequence becomes the verified [KlotskiLevel.solution].
  static KlotskiLevel buildFromSolved({
    required int id,
    required String name,
    required String difficulty,
    required List<KlotskiPiece> solvedPieces,
    required List<KlotskiMove> reverseMoves,
  }) {
    var cur = List<KlotskiPiece>.of(solvedPieces);
    for (final rm in reverseMoves) {
      final next = trySlide(cur, rm.piece, rm.dir);
      if (next == null) {
        throw StateError('Invalid reverse move (${rm.piece}, ${rm.dir}) in level $id ($name)');
      }
      cur = next;
    }
    final forwardSolution = [
      for (var i = reverseMoves.length - 1; i >= 0; i--)
        KlotskiMove(reverseMoves[i].piece, oppositeDir(reverseMoves[i].dir)),
    ];
    return KlotskiLevel(
      id: id,
      name: name,
      difficulty: difficulty,
      pieces: cur,
      solution: forwardSolution,
    );
  }

  /// Verifies that [lvl] has a valid non-overlapping initial layout, starts
  /// unsolved, and its [lvl.solution] legally reaches the solved state.
  static bool verifyLevel(KlotskiLevel lvl) {
    if (!isValidLayout(lvl.pieces)) return false;
    if (isSolved(lvl.pieces)) return false;
    if (lvl.difficulty == 'easy' && (lvl.solution.length < 8 || lvl.solution.length > 16)) {
      return false;
    }
    if (lvl.difficulty == 'classic' && (lvl.solution.length < 18 || lvl.solution.length > 40)) {
      return false;
    }
    var cur = List<KlotskiPiece>.of(lvl.pieces);
    for (final m in lvl.solution) {
      final next = trySlide(cur, m.piece, m.dir);
      if (next == null) return false;
      cur = next;
    }
    return isSolved(cur);
  }

  /// Finds a shortest solution from [initial] using BFS (bounded by [maxStates]).
  static List<KlotskiMove>? findShortestSolution(
    List<KlotskiPiece> initial, {
    int maxStates = 40000,
  }) {
    if (isSolved(initial)) return const [];
    String encode(List<KlotskiPiece> ps) {
      final buf = StringBuffer();
      for (final p in ps) {
        buf.writeCharCode(48 + p.r * boardW + p.c);
      }
      return buf.toString();
    }

    final startKey = encode(initial);
    final visited = <String>{startKey};
    final q = Queue<(List<KlotskiPiece>, List<KlotskiMove>)>();
    q.add((initial, const []));

    while (q.isNotEmpty && visited.length < maxStates) {
      final (cur, path) = q.removeFirst();
      for (final p in cur) {
        for (var dir = 0; dir < 4; dir++) {
          final next = trySlide(cur, p.id, dir);
          if (next == null) continue;
          final nPath = [...path, KlotskiMove(p.id, dir)];
          if (isSolved(next)) return nPath;
          final key = encode(next);
          if (visited.add(key)) {
            q.add((next, nPath));
          }
        }
      }
    }
    return null;
  }
}

// Base solved template A: Cao Cao at (3,1), empty at (2,1),(2,2)
const List<KlotskiPiece> _solvedBaseA = [
  KlotskiPiece(id: 0, name: '曹操', r: 3, c: 1, w: 2, h: 2),
  KlotskiPiece(id: 1, name: '关羽', r: 0, c: 1, w: 2, h: 1),
  KlotskiPiece(id: 2, name: '张飞', r: 0, c: 0, w: 1, h: 2),
  KlotskiPiece(id: 3, name: '赵云', r: 0, c: 3, w: 1, h: 2),
  KlotskiPiece(id: 4, name: '马超', r: 2, c: 0, w: 1, h: 2),
  KlotskiPiece(id: 5, name: '黄忠', r: 2, c: 3, w: 1, h: 2),
  KlotskiPiece(id: 6, name: '卒一', r: 1, c: 1, w: 1, h: 1),
  KlotskiPiece(id: 7, name: '卒二', r: 1, c: 2, w: 1, h: 1),
  KlotskiPiece(id: 8, name: '卒三', r: 4, c: 0, w: 1, h: 1),
  KlotskiPiece(id: 9, name: '卒四', r: 4, c: 3, w: 1, h: 1),
];

// Base solved template B: Cao Cao at (3,1), empty at (3,0),(4,0) (side exit entry)
const List<KlotskiPiece> _solvedBaseB = [
  KlotskiPiece(id: 0, name: '曹操', r: 3, c: 1, w: 2, h: 2),
  KlotskiPiece(id: 1, name: '关羽', r: 2, c: 0, w: 2, h: 1),
  KlotskiPiece(id: 2, name: '张飞', r: 0, c: 0, w: 1, h: 2),
  KlotskiPiece(id: 3, name: '赵云', r: 0, c: 3, w: 1, h: 2),
  KlotskiPiece(id: 4, name: '马超', r: 1, c: 2, w: 1, h: 2),
  KlotskiPiece(id: 5, name: '黄忠', r: 0, c: 1, w: 2, h: 1),
  KlotskiPiece(id: 6, name: '卒一', r: 1, c: 1, w: 1, h: 1),
  KlotskiPiece(id: 7, name: '卒二', r: 2, c: 3, w: 1, h: 1),
  KlotskiPiece(id: 8, name: '卒三', r: 3, c: 3, w: 1, h: 1),
  KlotskiPiece(id: 9, name: '卒四', r: 4, c: 3, w: 1, h: 1),
];

const List<KlotskiMove> _chainA36 = [
  KlotskiMove(0, 0), // 1: 0 -> (2,1)
  KlotskiMove(8, 1), // 2: 8 -> (4,1)
  KlotskiMove(9, 3), // 3: 9 -> (4,2)
  KlotskiMove(4, 2), // 4: 4 -> (3,0)
  KlotskiMove(5, 2), // 5: 5 -> (3,3)
  KlotskiMove(2, 2), // 6: 2 -> (1,0)
  KlotskiMove(3, 2), // 7: 3 -> (1,3)
  KlotskiMove(1, 3), // 8: 1 -> (0,0)
  KlotskiMove(7, 0), // 9: 7 -> (0,2)
  KlotskiMove(7, 1), // 10: 7 -> (0,3)
  KlotskiMove(6, 1), // 11: 6 -> (1,2)
  KlotskiMove(6, 0), // 12: 6 -> (0,2)
  KlotskiMove(0, 0), // 13: 0 -> (1,1)
  KlotskiMove(8, 0), // 14: 8 -> (3,1)
  KlotskiMove(8, 1), // 15: 8 -> (3,2)
  KlotskiMove(4, 1), // 16: 4 -> (3,1)
  KlotskiMove(2, 2), // 17: 2 -> (2,0)
  KlotskiMove(2, 2), // 18: 2 -> (3,0)
  KlotskiMove(0, 3), // 19: 0 -> (1,0)
  KlotskiMove(3, 3), // 20: 3 -> (1,2)
  KlotskiMove(7, 2), // 21: 7 -> (1,3)
  KlotskiMove(7, 2), // 22: 7 -> (2,3)
  KlotskiMove(6, 1), // 23: 6 -> (0,3)
  KlotskiMove(6, 2), // 24: 6 -> (1,3)
  KlotskiMove(1, 1), // 25: 1 -> (0,1)
  KlotskiMove(1, 1), // 26: 1 -> (0,2)
  KlotskiMove(0, 0), // 27: 0 -> (0,0)
  KlotskiMove(2, 0), // 28: 2 -> (2,0)
  KlotskiMove(4, 0), // 29: 4 -> (2,1)
  KlotskiMove(9, 3), // 30: 9 -> (4,1)
  KlotskiMove(9, 3), // 31: 9 -> (4,0)
  KlotskiMove(8, 2), // 32: 8 -> (4,2)
  KlotskiMove(8, 3), // 33: 8 -> (4,1)
  KlotskiMove(5, 3), // 34: 5 -> (3,2)
  KlotskiMove(7, 2), // 35: 7 -> (3,3)
  KlotskiMove(7, 2), // 36: 7 -> (4,3)
];

const List<KlotskiMove> _chainB22 = [
  KlotskiMove(0, 3), // 1: 0 -> (3,0), empty (3,2),(4,2)
  KlotskiMove(4, 2), // 2: 4 -> (2,2), empty (1,2),(4,2)
  KlotskiMove(4, 2), // 3: 4 -> (3,2), empty (1,2),(2,2)
  KlotskiMove(1, 1), // 4: 1 -> (2,1), empty (1,2),(2,0)
  KlotskiMove(6, 1), // 5: 6 -> (1,2), empty (1,1),(2,0)
  KlotskiMove(2, 2), // 6: 2 -> (1,0), empty (0,0),(1,1)
  KlotskiMove(5, 3), // 7: 5 -> (0,0), empty (0,2),(1,1)
  KlotskiMove(6, 0), // 8: 6 -> (0,2), empty (1,1),(1,2)
  KlotskiMove(1, 0), // 9: 1 -> (1,1), empty (2,1),(2,2)
];

/// 16 verified 4×5 Klotski levels across 'easy' (8..16 steps) and 'classic' (18..40 steps).
final List<KlotskiLevel> klotskiLevels = [
  // -------------------- EASY TIER (8..16 steps) --------------------
  KlotskiSolver.buildFromSolved(
    id: 1,
    name: '初出茅庐',
    difficulty: 'easy',
    solvedPieces: _solvedBaseA,
    reverseMoves: _chainA36.sublist(0, 8),
  ),
  KlotskiSolver.buildFromSolved(
    id: 2,
    name: '顺水推舟',
    difficulty: 'easy',
    solvedPieces: KlotskiSolver.mirrorPiecesH(_solvedBaseB),
    reverseMoves: KlotskiSolver.mirrorMovesH(_chainB22.sublist(0, 9)),
  ),
  KlotskiSolver.buildFromSolved(
    id: 3,
    name: '兵临城下',
    difficulty: 'easy',
    solvedPieces: _solvedBaseA,
    reverseMoves: _chainA36.sublist(0, 10),
  ),
  KlotskiSolver.buildFromSolved(
    id: 4,
    name: '左右逢源',
    difficulty: 'easy',
    solvedPieces: KlotskiSolver.mirrorPiecesH(_solvedBaseA),
    reverseMoves: KlotskiSolver.mirrorMovesH(_chainA36.sublist(0, 11)),
  ),
  KlotskiSolver.buildFromSolved(
    id: 5,
    name: '拨云见日',
    difficulty: 'easy',
    solvedPieces: _solvedBaseA,
    reverseMoves: _chainA36.sublist(0, 13),
  ),
  KlotskiSolver.buildFromSolved(
    id: 6,
    name: '移花接木',
    difficulty: 'easy',
    solvedPieces: KlotskiSolver.mirrorPiecesH(_solvedBaseA),
    reverseMoves: KlotskiSolver.mirrorMovesH(_chainA36.sublist(0, 14)),
  ),
  KlotskiSolver.buildFromSolved(
    id: 7,
    name: '暗度陈仓',
    difficulty: 'easy',
    solvedPieces: _solvedBaseA,
    reverseMoves: _chainA36.sublist(0, 15),
  ),
  KlotskiSolver.buildFromSolved(
    id: 8,
    name: '单骑救主',
    difficulty: 'easy',
    solvedPieces: KlotskiSolver.mirrorPiecesH(_solvedBaseA),
    reverseMoves: KlotskiSolver.mirrorMovesH(_chainA36.sublist(0, 16)),
  ),

  // -------------------- CLASSIC TIER (18..40 steps) --------------------
  KlotskiSolver.buildFromSolved(
    id: 9,
    name: '水泄不通',
    difficulty: 'classic',
    solvedPieces: _solvedBaseA,
    reverseMoves: _chainA36.sublist(0, 18),
  ),
  KlotskiSolver.buildFromSolved(
    id: 10,
    name: '围魏救赵',
    difficulty: 'classic',
    solvedPieces: KlotskiSolver.mirrorPiecesH(_solvedBaseA),
    reverseMoves: KlotskiSolver.mirrorMovesH(_chainA36.sublist(0, 20)),
  ),
  KlotskiSolver.buildFromSolved(
    id: 11,
    name: '四面楚歌',
    difficulty: 'classic',
    solvedPieces: _solvedBaseA,
    reverseMoves: _chainA36.sublist(0, 22),
  ),
  KlotskiSolver.buildFromSolved(
    id: 12,
    name: '草船借箭',
    difficulty: 'classic',
    solvedPieces: KlotskiSolver.mirrorPiecesH(_solvedBaseA),
    reverseMoves: KlotskiSolver.mirrorMovesH(_chainA36.sublist(0, 24)),
  ),
  KlotskiSolver.buildFromSolved(
    id: 13,
    name: '千里走单骑',
    difficulty: 'classic',
    solvedPieces: _solvedBaseA,
    reverseMoves: _chainA36.sublist(0, 27),
  ),
  KlotskiSolver.buildFromSolved(
    id: 14,
    name: '火烧赤壁',
    difficulty: 'classic',
    solvedPieces: KlotskiSolver.mirrorPiecesH(_solvedBaseA),
    reverseMoves: KlotskiSolver.mirrorMovesH(_chainA36.sublist(0, 30)),
  ),
  KlotskiSolver.buildFromSolved(
    id: 15,
    name: '过五关斩六将',
    difficulty: 'classic',
    solvedPieces: _solvedBaseA,
    reverseMoves: _chainA36.sublist(0, 33),
  ),
  KlotskiSolver.buildFromSolved(
    id: 16,
    name: '横刀立马',
    difficulty: 'classic',
    solvedPieces: KlotskiSolver.mirrorPiecesH(_solvedBaseA),
    reverseMoves: KlotskiSolver.mirrorMovesH(_chainA36.sublist(0, 36)),
  ),
];

/// 华容道竞速 (Klotski Race, 1-6 人).
class KlotskiGame extends GameEngine {
  KlotskiGame(super.setup);

  static const int roundMaxSec = 420;

  late String difficulty;
  late int totalRounds;
  late List<KlotskiLevel> matchLevels;

  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late KlotskiLevel currentLevel;
  late List<KlotskiPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a6Placings(ranking, players) : null;

  @override
  bool get canResign => !over;

  @override
  int get botDelayMs => switch (botLevel) { 0 => 800, 2 => 260, _ => 480 };

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
    final rawDiff = setup.opt<String>('difficulty', 'easy');
    difficulty = rawDiff == 'classic' ? 'classic' : 'easy';
    totalRounds = setup.opt<int>('rounds', 3) == 1 ? 1 : 3;

    final tierPool = [for (final l in klotskiLevels) if (l.difficulty == difficulty) l];
    final pool = List<KlotskiLevel>.of(tierPool.isNotEmpty ? tierPool : klotskiLevels)..shuffle(rng);
    matchLevels = pool.sublist(0, totalRounds);

    currentLevel = matchLevels[0];
    ps = [for (var s = 0; s < players; s++) KlotskiPlayer(currentLevel.pieces)];

    final diffLabel = difficulty == 'classic' ? '经典名局' : '入门突围';
    host.log('华容道竞速开始（$diffLabel，共 $totalRounds 局）！将 2×2「曹操」滑至底部中央出口 (3,1) 即可突围！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    currentLevel = matchLevels[r - 1];
    for (var s = 0; s < players; s++) {
      ps[s].resetForRound(currentLevel.pieces);
    }
  }

  void _clock() {
    if (over) return;
    roundSec++;
    if (roundSec >= roundMaxSec) {
      _endRound('本局时间到');
    }
    if (!over) host.schedule(1000, _clock);
  }

  bool _activeInRound(int s) => ps[s].resignNo == 0 && ps[s].status == 'play';

  @override
  List<int> get waitingFor {
    if (over) return const [];
    return a6Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
  }

  @override
  void handle(int seat, Map<String, dynamic> a) {
    if (over) throw GameError('对局已结束');
    if (seat < 0 || seat >= players) throw GameError('观众不能操作');
    final type = asStr(a['type']);
    if (type == 'idle' || type == 'next') return;
    final p = ps[seat];
    if (p.resignNo > 0) throw GameError('你已认输');
    if (p.status != 'play') throw GameError('你已完成本局');

    switch (type) {
      case 'slide':
      case 'move':
        final pieceId = asInt(a['piece']);
        final dir = asInt(a['dir']);
        if (dir < 0 || dir >= 4) throw GameError('移动方向无效');
        if (!p.pieces.any((x) => x.id == pieceId)) {
          throw GameError('指定的棋子不存在');
        }
        final next = KlotskiSolver.trySlide(p.pieces, pieceId, dir);
        if (next == null) {
          throw GameError('该方向受阻或超出棋盘边界，无法移动');
        }
        p.pushHistory();
        p.pieces = next;
        p.steps++;
        p.moveLog.add(KlotskiMove(pieceId, dir));
        moves++;
        if (KlotskiSolver.isSolved(p.pieces)) {
          _markSolved(seat);
        }

      case 'undo':
        if (p.history.isEmpty) throw GameError('没有可撤销的步骤');
        p.popHistory();
        moves++;

      case 'reset':
      case 'clear':
        p.resetWorkspace(currentLevel.pieces);
        moves++;

      case 'pass':
      case 'give_up':
      case 'skip':
        p.status = 'pass';
        p.lastRoundPts = 0;
        moves++;
        host.log('${name(seat)} 放弃了第 $round 局「${currentLevel.name}」');
        _checkRoundComplete();

      default:
        throw GameError('未知操作');
    }
  }

  void _markSolved(int seat) {
    final p = ps[seat];
    roundSolvers++;
    final basePts = switch (roundSolvers) {
      1 => 10,
      2 => 8,
      3 => 6,
      _ => 4,
    };
    final par = currentLevel.parSteps;
    final bonus = p.steps <= par ? 2 : (p.steps <= par + 4 ? 1 : 0);
    final pts = basePts + bonus;

    p.status = 'solved';
    p.solveRank = roundSolvers;
    p.lastRoundPts = pts;
    p.score += pts;
    p.solvedCount++;
    p.totalSteps += p.steps;
    host.log('${name(seat)} 第 $roundSolvers 个突围「${currentLevel.name}」（${p.steps}步，最优$par步），+$pts 分！');
    _checkRoundComplete();
  }

  void _checkRoundComplete() {
    if (over) return;
    if ([for (var s = 0; s < players; s++) if (_activeInRound(s)) s].isEmpty) {
      _endRound('全员完成第 $round 局');
    }
  }

  void _endRound(String reason) {
    lastRoundSummary = {
      'round': round,
      'levelName': currentLevel.name,
      'reason': reason,
      'parSteps': currentLevel.parSteps,
      'ps': [
        for (var s = 0; s < players; s++)
          {
            's': s,
            'status': ps[s].status,
            'steps': ps[s].steps,
            'pts': ps[s].lastRoundPts,
            'rank': ps[s].solveRank,
          },
      ],
    };

    if (round >= totalRounds) {
      _finish('全部 $totalRounds 局已完成');
    } else {
      _startRound(round + 1);
    }
  }

  void _finish(String why) {
    if (over) return;
    over = true;
    ranking = a6Ranking(players, (a, b) {
      final pa = ps[a], pb = ps[b];
      if (pa.resignNo != pb.resignNo) {
        return pa.resignNo == 0 ? -1 : (pb.resignNo == 0 ? 1 : pb.resignNo - pa.resignNo);
      }
      if (pa.score != pb.score) return pb.score - pa.score;
      if (pa.solvedCount != pb.solvedCount) return pb.solvedCount - pa.solvedCount;
      return pa.totalSteps - pb.totalSteps;
    }, (s) => {
          'score': ps[s].score,
          'solved': ps[s].solvedCount,
          'steps': ps[s].totalSteps,
        });
    host.log('游戏结束（$why）！冠军：${a6Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || !_activeInRound(seat)) return null;
    final p = ps[seat];
    final sol = currentLevel.solution;

    // Easy bot occasionally passes at the very start of a round
    if (botLevel <= 0 && p.moveLog.isEmpty && rng.nextInt(8) == 0) {
      return {'type': 'pass'};
    }

    // Check if player's moveLog is a clean prefix of the level's verified solution
    final k = p.moveLog.length;
    if (k < sol.length) {
      var matchesPrefix = true;
      for (var i = 0; i < k; i++) {
        if (p.moveLog[i].piece != sol[i].piece || p.moveLog[i].dir != sol[i].dir) {
          matchesPrefix = false;
          break;
        }
      }
      if (matchesPrefix) {
        final nextMove = sol[k];
        return {'type': 'slide', 'piece': nextMove.piece, 'dir': nextMove.dir};
      }
    }

    // If a human player diverged from the solution before bot took over, reset once
    if (p.moveLog.isNotEmpty) {
      return {'type': 'reset'};
    }
    return sol.isNotEmpty
        ? {'type': 'slide', 'piece': sol[0].piece, 'dir': sol[0].dir}
        : {'type': 'pass'};
  }

  // ---------------------------------------------------------------- view

  static double _progressForPieces(List<KlotskiPiece> pieces, String status) {
    if (status == 'solved') return 1.0;
    for (final p in pieces) {
      if (p.id == 0) {
        final dist = (KlotskiSolver.targetR - p.r).abs() + (KlotskiSolver.targetC - p.c).abs();
        return ((4 - dist) / 4.0).clamp(0.05, 0.9);
      }
    }
    return 0.0;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players ? ps[seat] : (ps.isNotEmpty ? ps[0] : null);
    final myPieces = me?.pieces ?? currentLevel.pieces;

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'difficulty': difficulty,
      'levelId': currentLevel.id,
      'levelName': currentLevel.name,
      'w': KlotskiSolver.boardW,
      'h': KlotskiSolver.boardH,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'pieces': [for (final p in myPieces) p.toJson()],
      'steps': me?.steps ?? 0,
      'parSteps': currentLevel.parSteps,
      'canUndo': me != null && me.history.isNotEmpty && me.status == 'play' && !over,
      'canReset': me != null && me.steps > 0 && me.status == 'play' && !over,
      'ps': [
        for (var s = 0; s < players; s++)
          {
            'score': ps[s].score,
            'solved': ps[s].solvedCount,
            'status': ps[s].status,
            'steps': ps[s].steps,
            'pts': ps[s].lastRoundPts,
            'rank': ps[s].solveRank,
            'pct': _progressForPieces(ps[s].pieces, ps[s].status),
          },
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class _KlotskiSnap {
  final List<KlotskiPiece> pieces;
  final int steps;
  final int logLen;
  _KlotskiSnap(this.pieces, this.steps, this.logLen);
}

class KlotskiPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSteps = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;

  List<KlotskiPiece> pieces;
  int steps = 0;
  final List<KlotskiMove> moveLog = [];
  final List<_KlotskiSnap> history = [];

  KlotskiPlayer(List<KlotskiPiece> initial) : pieces = List<KlotskiPiece>.of(initial);

  void resetForRound(List<KlotskiPiece> initial) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    resetWorkspace(initial);
  }

  void resetWorkspace(List<KlotskiPiece> initial) {
    pieces = List<KlotskiPiece>.of(initial);
    steps = 0;
    moveLog.clear();
    history.clear();
  }

  void pushHistory() {
    history.add(_KlotskiSnap(List<KlotskiPiece>.of(pieces), steps, moveLog.length));
  }

  void popHistory() {
    if (history.isEmpty) return;
    final snap = history.removeLast();
    pieces = snap.pieces;
    steps = snap.steps;
    if (moveLog.length > snap.logLen) {
      moveLog.removeRange(snap.logLen, moveLog.length);
    }
  }
}
