import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';

/// 6 axial hex directions: E, NE, NW, W, SW, SE.
const List<(int, int)> punctHexDirs = [
  (1, 0),
  (1, -1),
  (0, -1),
  (-1, 0),
  (-1, 1),
  (0, 1),
];

/// Hex distance between (q1, r1) and (q2, r2).
int punctHexDist(int q1, int r1, [int q2 = 0, int r2 = 0]) {
  final dq = (q1 - q2).abs();
  final dr = (r1 - r2).abs();
  final ds = ((q1 + r1) - (q2 + r2)).abs();
  return max(dq, max(dr, ds));
}

/// All 61 hex cells on the radius-4 PÜNCT board.
final List<(int, int)> punctBoardCells = List.unmodifiable([
  for (var q = -4; q <= 4; q++)
    for (var r = -4; r <= 4; r++)
      if (punctHexDist(q, r) <= 4) (q, r),
]);

/// The 7 center hexes (distance <= 1) forming the Central Restricted Zone.
final List<(int, int)> punctCentralZone = List.unmodifiable([
  for (final (q, r) in punctBoardCells)
    if (punctHexDist(q, r) <= 1) (q, r),
]);

/// Normalize shape identifier from string or integer.
String normalizePunctShape(Object? raw) {
  if (raw is int) {
    switch (raw) {
      case 0:
        return 'straight';
      case 1:
        return 'angled';
      case 2:
        return 'triangle';
    }
  }
  final s = '$raw'.trim().toLowerCase();
  if (s == '0' || s == 'straight' || s == 'line' || s == 'i') return 'straight';
  if (s == '1' || s == 'angled' || s == 'angle' || s == 'v' || s == 'bend') return 'angled';
  if (s == '2' || s == 'triangle' || s == 'tri' || s == 't') return 'triangle';
  return '';
}

/// Compute the 3 hex coordinates occupied by a Tri-Hex piece with its PÜNCT hex
/// at (q, r) and rotation [rot] (0..5).
/// Index 0 is always the PÜNCT hex (q, r); indices 1 and 2 are the 2 satellites.
List<(int, int)> punctPieceCells(String shape, int q, int r, int rot) {
  final r0 = ((rot % 6) + 6) % 6;
  final d1 = punctHexDirs[r0];
  final (int, int) d2;
  switch (shape) {
    case 'straight':
      d2 = punctHexDirs[(r0 + 3) % 6];
      break;
    case 'angled':
      d2 = punctHexDirs[(r0 + 2) % 6];
      break;
    case 'triangle':
      d2 = punctHexDirs[(r0 + 1) % 6];
      break;
    default:
      throw GameError('未知棋子形状：$shape');
  }
  return [
    (q, r),
    (q + d1.$1, r + d1.$2),
    (q + d2.$1, r + d2.$2),
  ];
}

class PunctCellEntry {
  final int pieceId;
  final int owner; // 0: White, 1: Black
  final bool isPunct;

  const PunctCellEntry({
    required this.pieceId,
    required this.owner,
    required this.isPunct,
  });

  Map<String, dynamic> toJson() => {
        'pieceId': pieceId,
        'owner': owner,
        'isPunct': isPunct,
      };
}

class PunctPiece {
  final int id;
  final int owner;
  final String shape;
  int q;
  int r;
  int rot;

  PunctPiece({
    required this.id,
    required this.owner,
    required this.shape,
    required this.q,
    required this.r,
    required this.rot,
  });

  List<(int, int)> get cells => punctPieceCells(shape, q, r, rot);

  Map<String, dynamic> toJson({required bool topMost, required int level}) => {
        'id': id,
        'owner': owner,
        'shape': shape,
        'q': q,
        'r': r,
        'rot': rot,
        'topMost': topMost,
        'level': level,
        'cells': [
          for (final (cq, cr) in cells) [cq, cr],
        ],
      };
}

/// 彭克特桥接棋 (PÜNCT) — Kris Burm's Project GIPF Tri-Hex connection game.
class PunctGame extends GameEngine {
  PunctGame(super.setup);

  late String mode;
  late int maxTurns;
  late List<Map<String, int>> reserves;

  final Map<(int, int), List<PunctCellEntry>> _stacks = {};
  final Map<int, PunctPiece> pieces = {};
  int _nextPieceId = 1;

  int turn = 0;
  int turnCount = 0;
  int movesSinceLastDrop = 0;
  bool _over = false;
  int? winner; // 0, 1, or -1 for draw
  String? winReason;
  int? winningPair;
  List<(int, int)> winningChain = [];
  Map<String, dynamic>? lastMove;

  @override
  bool get isOver => _over;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  bool get canResign => true;

  @override
  bool get canDraw => true;

  @override
  List<int>? get placings {
    if (!_over) return null;
    if (winner == null || winner == -1) return const [1, 1];
    return rankWinners(2, [winner!]);
  }

  bool isValidHex(int q, int r) => punctHexDist(q, r) <= 4;

  bool isCentralHex(int q, int r) => punctHexDist(q, r) <= 1;

  /// Checks whether (q, r) lies on side [end] (0 or 1) of opposite side pair [pair] (0..2).
  bool isOnOuterSide(int q, int r, int pair, int end) {
    if (!isValidHex(q, r)) return false;
    switch (pair) {
      case 0:
        return end == 0 ? q == -4 : q == 4;
      case 1:
        return end == 0 ? r == -4 : r == 4;
      case 2:
        return end == 0 ? (q + r) == -4 : (q + r) == 4;
      default:
        return false;
    }
  }

  List<PunctCellEntry> stackAt(int q, int r) => _stacks[(q, r)] ?? const [];

  int stackHeight(int q, int r) => _stacks[(q, r)]?.length ?? 0;

  int topColorAt(int q, int r) {
    final st = _stacks[(q, r)];
    if (st == null || st.isEmpty) return -1;
    return st.last.owner;
  }

  int? topPieceIdAt(int q, int r) {
    final st = _stacks[(q, r)];
    if (st == null || st.isEmpty) return null;
    return st.last.pieceId;
  }

  int totalReserve(int seat) {
    final m = reserves[seat];
    return (m['straight'] ?? 0) + (m['angled'] ?? 0) + (m['triangle'] ?? 0);
  }

  bool isPieceTopMost(int pieceId) {
    final p = pieces[pieceId];
    if (p == null) return false;
    for (final (cq, cr) in p.cells) {
      final st = _stacks[(cq, cr)];
      if (st == null || st.isEmpty || st.last.pieceId != pieceId) {
        return false;
      }
    }
    return true;
  }

  int pieceLevel(int pieceId) {
    final p = pieces[pieceId];
    if (p == null) return 0;
    var maxH = 1;
    for (final (cq, cr) in p.cells) {
      final st = _stacks[(cq, cr)];
      if (st != null) {
        final idx = st.lastIndexWhere((e) => e.pieceId == pieceId);
        if (idx >= 0 && idx + 1 > maxH) maxH = idx + 1;
      }
    }
    return maxH;
  }

  @override
  void start() {
    mode = setup.opt<String>('mode', 'standard');
    final perShape = mode == 'quick' ? 4 : 6;
    maxTurns = mode == 'quick' ? 70 : 100;
    reserves = [
      {'straight': perShape, 'angled': perShape, 'triangle': perShape},
      {'straight': perShape, 'angled': perShape, 'triangle': perShape},
    ];
    _stacks.clear();
    for (final cell in punctBoardCells) {
      _stacks[cell] = <PunctCellEntry>[];
    }
    pieces.clear();
    _nextPieceId = 1;
    turn = 0;
    turnCount = 0;
    movesSinceLastDrop = 0;
    _over = false;
    winner = null;
    winReason = null;
    winningPair = null;
    winningChain = [];
    lastMove = null;
  }

  @override
  void resign(int seat) {
    if (_over) throw GameError('对局已结束');
    _over = true;
    winner = 1 - seat;
    winReason = '${name(seat)} 认输，${name(winner!)} 获胜！';
    host.log(winReason!);
  }

  @override
  void agreeDraw() {
    if (_over) throw GameError('对局已结束');
    _over = true;
    winner = -1;
    winReason = '双方同意和棋';
    host.log(winReason!);
  }

  /// Directly place a piece on the board for unit testing.
  int debugPlacePiece({
    required int owner,
    required String shape,
    required int q,
    required int r,
    required int rot,
  }) {
    final normShape = normalizePunctShape(shape);
    final normRot = ((rot % 6) + 6) % 6;
    final cells = punctPieceCells(normShape, q, r, normRot);
    final id = _nextPieceId++;
    final piece = PunctPiece(
      id: id,
      owner: owner,
      shape: normShape,
      q: q,
      r: r,
      rot: normRot,
    );
    pieces[id] = piece;
    for (var i = 0; i < cells.length; i++) {
      _stacks[cells[i]]!.add(PunctCellEntry(
        pieceId: id,
        owner: owner,
        isPunct: i == 0,
      ));
    }
    return id;
  }

  bool canDrop(int seat, String rawShape, int q, int r, int rot) {
    final shape = normalizePunctShape(rawShape);
    if (shape.isEmpty) return false;
    if ((reserves[seat][shape] ?? 0) <= 0) return false;
    final cells = punctPieceCells(shape, q, r, rot);
    for (final (cq, cr) in cells) {
      if (!isValidHex(cq, cr)) return false;
      if (isCentralHex(cq, cr)) return false;
      if (stackHeight(cq, cr) != 0) return false;
    }
    return true;
  }

  static bool isStraightHexLine(int fromQ, int fromR, int toQ, int toR) {
    final dq = toQ - fromQ;
    final dr = toR - fromR;
    if (dq == 0 && dr == 0) return false;
    for (final (ux, uy) in punctHexDirs) {
      if (ux == 0) {
        if (dq == 0 && dr * uy > 0) return true;
      } else if (uy == 0) {
        if (dr == 0 && dq * ux > 0) return true;
      } else {
        if (dq * ux > 0 && dr * uy > 0 && dq.abs() == dr.abs()) return true;
      }
    }
    return false;
  }

  bool canMove(int seat, int pieceId, int toQ, int toR, int rot) {
    final p = pieces[pieceId];
    if (p == null || p.owner != seat) return false;
    if (!isPieceTopMost(pieceId)) return false;
    if (!isStraightHexLine(p.q, p.r, toQ, toR)) return false;

    final normRot = ((rot % 6) + 6) % 6;
    final targetCells = punctPieceCells(p.shape, toQ, toR, normRot);
    for (final (cq, cr) in targetCells) {
      if (!isValidHex(cq, cr)) return false;
    }

    final oldCells = p.cells.toSet();
    int effectiveHeight(int cq, int cr) {
      final h = stackHeight(cq, cr);
      return oldCells.contains((cq, cr)) ? h - 1 : h;
    }

    int effectiveTopColor(int cq, int cr) {
      final st = _stacks[(cq, cr)]!;
      final len = oldCells.contains((cq, cr)) ? st.length - 1 : st.length;
      if (len <= 0) return -1;
      return st[len - 1].owner;
    }

    final h0 = effectiveHeight(targetCells[0].$1, targetCells[0].$2);
    final h1 = effectiveHeight(targetCells[1].$1, targetCells[1].$2);
    final h2 = effectiveHeight(targetCells[2].$1, targetCells[2].$2);

    // Either all 3 hexes land on empty level-0 cells:
    if (h0 == 0 && h1 == 0 && h2 == 0) {
      return true;
    }

    // Or stacked on top of existing pieces where the PÜNCT hex lands on own color:
    if (h0 > 0 && h1 > 0 && h2 > 0) {
      if (effectiveTopColor(toQ, toR) == seat) {
        return true;
      }
    }

    return false;
  }

  /// Checks if [seat] connects any of the 3 pairs of opposite outer sides.
  (bool, int?, List<(int, int)>) checkConnection(int seat) {
    for (var pair = 0; pair < 3; pair++) {
      final starts = <(int, int)>[];
      for (final (q, r) in punctBoardCells) {
        if (isOnOuterSide(q, r, pair, 0) && topColorAt(q, r) == seat) {
          starts.add((q, r));
        }
      }
      if (starts.isEmpty) continue;

      final parent = <(int, int), (int, int)?>{};
      final queue = Queue<(int, int)>();
      for (final s in starts) {
        parent[s] = null;
        queue.add(s);
      }

      while (queue.isNotEmpty) {
        final cur = queue.removeFirst();
        if (isOnOuterSide(cur.$1, cur.$2, pair, 1)) {
          final chain = <(int, int)>[];
          (int, int)? node = cur;
          while (node != null) {
            chain.add(node);
            node = parent[node];
          }
          return (true, pair, chain.reversed.toList());
        }
        for (final (dq, dr) in punctHexDirs) {
          final next = (cur.$1 + dq, cur.$2 + dr);
          if (!isValidHex(next.$1, next.$2)) continue;
          if (parent.containsKey(next)) continue;
          if (topColorAt(next.$1, next.$2) != seat) continue;
          parent[next] = cur;
          queue.add(next);
        }
      }
    }
    return (false, null, const []);
  }

  int countCentralControl(int seat) {
    var count = 0;
    for (final (q, r) in punctCentralZone) {
      if (topColorAt(q, r) == seat) count++;
    }
    return count;
  }

  int countTotalControl(int seat) {
    var count = 0;
    for (final (q, r) in punctBoardCells) {
      if (topColorAt(q, r) == seat) count++;
    }
    return count;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);
    if (type == 'drop') {
      final shape = normalizePunctShape(action['shape']);
      if (shape.isEmpty) throw GameError('无效的棋子形状');
      if ((reserves[seat][shape] ?? 0) <= 0) {
        throw GameError('储备区没有剩余的该形状棋子');
      }
      final q = asInt(action['q'], 999);
      final r = asInt(action['r'], 999);
      final rot = ((asInt(action['rot'], 0) % 6) + 6) % 6;

      final cells = punctPieceCells(shape, q, r, rot);
      for (final (cq, cr) in cells) {
        if (!isValidHex(cq, cr)) {
          throw GameError('棋子超出棋盘范围');
        }
        if (isCentralHex(cq, cr)) {
          throw GameError('新投放的棋子不能进入中央禁区');
        }
        if (stackHeight(cq, cr) != 0) {
          throw GameError('新投放的棋子必须落在三个空格上');
        }
      }

      reserves[seat][shape] = reserves[seat][shape]! - 1;
      final id = _nextPieceId++;
      final piece = PunctPiece(
        id: id,
        owner: seat,
        shape: shape,
        q: q,
        r: r,
        rot: rot,
      );
      pieces[id] = piece;
      for (var i = 0; i < cells.length; i++) {
        _stacks[cells[i]]!.add(PunctCellEntry(
          pieceId: id,
          owner: seat,
          isPunct: i == 0,
        ));
      }
      lastMove = {
        'type': 'drop',
        'seat': seat,
        'pieceId': id,
        'shape': shape,
        'q': q,
        'r': r,
        'rot': rot,
        'cells': [
          for (final (cq, cr) in cells) [cq, cr],
        ],
      };
      movesSinceLastDrop = 0;
    } else if (type == 'move') {
      var pieceId = asInt(action['pieceId'], -1);
      if (!pieces.containsKey(pieceId)) {
        final fq = asInt(action['fromQ'], 999);
        final fr = asInt(action['fromR'], 999);
        if (isValidHex(fq, fr)) {
          final topId = topPieceIdAt(fq, fr);
          if (topId != null) pieceId = topId;
        }
      }
      final p = pieces[pieceId];
      if (p == null || p.owner != seat) {
        throw GameError('请选择一枚属于你的棋子');
      }
      if (!isPieceTopMost(pieceId)) {
        throw GameError('该棋子被其他棋子压住，无法移动');
      }
      final toQ = asInt(action['toQ'], 999);
      final toR = asInt(action['toR'], 999);
      final rot = ((asInt(action['rot'], p.rot) % 6) + 6) % 6;

      if (!isStraightHexLine(p.q, p.r, toQ, toR)) {
        throw GameError('PÜNCT 中心点必须沿六角直线方向移动');
      }
      if (!canMove(seat, pieceId, toQ, toR, rot)) {
        throw GameError('目标位置不合法：必须落在三个空格上，或叠放在已有棋子之上且 PÜNCT 点落在己方颜色上');
      }

      final fromQ = p.q;
      final fromR = p.r;
      final oldCells = p.cells;
      for (final cell in oldCells) {
        _stacks[cell]!.removeLast();
      }
      p.q = toQ;
      p.r = toR;
      p.rot = rot;
      final newCells = p.cells;
      for (var i = 0; i < newCells.length; i++) {
        _stacks[newCells[i]]!.add(PunctCellEntry(
          pieceId: p.id,
          owner: seat,
          isPunct: i == 0,
        ));
      }
      lastMove = {
        'type': 'move',
        'seat': seat,
        'pieceId': p.id,
        'shape': p.shape,
        'fromQ': fromQ,
        'fromR': fromR,
        'q': toQ,
        'r': toR,
        'rot': rot,
        'cells': [
          for (final (cq, cr) in newCells) [cq, cr],
        ],
      };
      movesSinceLastDrop++;
    } else {
      throw GameError('未知操作类型：$type');
    }

    turnCount++;

    // Check active player connection first, then opponent (in case uncovering connected opponent)
    for (final s in [seat, 1 - seat]) {
      final (connected, pairIdx, chain) = checkConnection(s);
      if (connected) {
        _over = true;
        winner = s;
        winningPair = pairIdx;
        winningChain = chain;
        final pairLabel = pairIdx == 0 ? '左右对边' : (pairIdx == 1 ? '上下对边' : '斜向对边');
        winReason = '${name(s)} 成功贯通$pairLabel，赢得胜利！';
        host.log(winReason!);
        return;
      }
    }

    final nextSeat = 1 - seat;
    final bothReservesEmpty = totalReserve(0) == 0 && totalReserve(1) == 0;
    if (turnCount >= maxTurns ||
        (bothReservesEmpty && movesSinceLastDrop >= 12) ||
        !_hasAnyLegalAction(nextSeat)) {
      _adjudicateByTiebreaker();
      return;
    }

    turn = nextSeat;
  }

  bool _hasAnyLegalAction(int seat) {
    if (totalReserve(seat) > 0) {
      for (final shape in const ['straight', 'angled', 'triangle']) {
        if ((reserves[seat][shape] ?? 0) <= 0) continue;
        for (final (q, r) in punctBoardCells) {
          if (isCentralHex(q, r) || stackHeight(q, r) != 0) continue;
          for (var rot = 0; rot < 6; rot++) {
            if (canDrop(seat, shape, q, r, rot)) return true;
          }
        }
      }
    }
    for (final p in pieces.values) {
      if (p.owner != seat || !isPieceTopMost(p.id)) continue;
      for (final (dq, dr) in punctHexDirs) {
        for (var step = 1; step <= 8; step++) {
          final toQ = p.q + dq * step;
          final toR = p.r + dr * step;
          if (!isValidHex(toQ, toR)) break;
          for (var rot = 0; rot < 6; rot++) {
            if (canMove(seat, p.id, toQ, toR, rot)) return true;
          }
        }
      }
    }
    return false;
  }

  void _adjudicateByTiebreaker() {
    _over = true;
    final c0 = countCentralControl(0);
    final c1 = countCentralControl(1);
    if (c0 != c1) {
      winner = c0 > c1 ? 0 : 1;
      winReason = '对局结束：${name(winner!)} 控制更多中央禁区格（$c0 : $c1）获胜！';
    } else {
      final t0 = countTotalControl(0);
      final t1 = countTotalControl(1);
      if (t0 != t1) {
        winner = t0 > t1 ? 0 : 1;
        winReason = '对局结束：中央控制持平，${name(winner!)} 控制更多顶层棋格（$t0 : $t1）获胜！';
      } else {
        winner = -1;
        winReason = '对局结束：双方中央与顶层控制数完全相同，平局！';
      }
    }
    host.log(winReason!);
  }

  /// Evaluates how close [seat] is to connecting any pair of opposite sides, plus center control.
  double _evaluatePosition(int seat) {
    // Max coordinate span across any of the 3 axis directions in a single connected component
    var bestSpan = 0;
    final visited = <(int, int)>{};
    for (final cell in punctBoardCells) {
      if (topColorAt(cell.$1, cell.$2) != seat || visited.contains(cell)) continue;
      var minQ = cell.$1, maxQ = cell.$1;
      var minR = cell.$2, maxR = cell.$2;
      var minS = cell.$1 + cell.$2, maxS = cell.$1 + cell.$2;
      final q = Queue<(int, int)>()..add(cell);
      visited.add(cell);
      while (q.isNotEmpty) {
        final cur = q.removeFirst();
        if (cur.$1 < minQ) minQ = cur.$1;
        if (cur.$1 > maxQ) maxQ = cur.$1;
        if (cur.$2 < minR) minR = cur.$2;
        if (cur.$2 > maxR) maxR = cur.$2;
        final s = cur.$1 + cur.$2;
        if (s < minS) minS = s;
        if (s > maxS) maxS = s;
        for (final (dq, dr) in punctHexDirs) {
          final n = (cur.$1 + dq, cur.$2 + dr);
          if (isValidHex(n.$1, n.$2) && !visited.contains(n) && topColorAt(n.$1, n.$2) == seat) {
            visited.add(n);
            q.add(n);
          }
        }
      }
      final span = max(maxQ - minQ, max(maxR - minR, maxS - minS));
      if (span > bestSpan) bestSpan = span;
    }
    return bestSpan * 12.0 + countCentralControl(seat) * 4.5 + countTotalControl(seat) * 0.8;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    final candidates = <Map<String, dynamic>>[];

    // 1. Collect legal drop actions
    if (totalReserve(seat) > 0) {
      for (final shape in const ['straight', 'angled', 'triangle']) {
        if ((reserves[seat][shape] ?? 0) <= 0) continue;
        final maxRot = shape == 'straight' ? 3 : 6;
        for (final (q, r) in punctBoardCells) {
          if (isCentralHex(q, r) || stackHeight(q, r) != 0) continue;
          for (var rot = 0; rot < maxRot; rot++) {
            if (canDrop(seat, shape, q, r, rot)) {
              candidates.add({
                'type': 'drop',
                'shape': shape,
                'q': q,
                'r': r,
                'rot': rot,
              });
            }
          }
        }
      }
    }

    // 2. Collect legal move/stack actions
    for (final p in pieces.values) {
      if (p.owner != seat || !isPieceTopMost(p.id)) continue;
      for (final (dq, dr) in punctHexDirs) {
        for (var step = 1; step <= 8; step++) {
          final toQ = p.q + dq * step;
          final toR = p.r + dr * step;
          if (!isValidHex(toQ, toR)) break;
          for (var rot = 0; rot < 6; rot++) {
            if (canMove(seat, p.id, toQ, toR, rot)) {
              candidates.add({
                'type': 'move',
                'pieceId': p.id,
                'toQ': toQ,
                'toR': toR,
                'rot': rot,
              });
            }
          }
        }
      }
    }

    if (candidates.isEmpty) return null;
    if (botLevel == 0 && rng.nextDouble() < 0.45) {
      return candidates[rng.nextInt(candidates.length)];
    }

    // Subsample if candidates list is large while keeping all moves and outer/adjacent drops
    final evalPool = <Map<String, dynamic>>[];
    for (final c in candidates) {
      if (c['type'] == 'move') {
        evalPool.add(c);
      } else {
        final q = c['q'] as int;
        final r = c['r'] as int;
        // Prefer drops adjacent to existing pieces or near outer edge / center ring
        var touchesOwn = false;
        for (final (dq, dr) in punctHexDirs) {
          final nq = q + dq;
          final nr = r + dr;
          if (isValidHex(nq, nr) && topColorAt(nq, nr) == seat) {
            touchesOwn = true;
            break;
          }
        }
        if (touchesOwn || punctHexDist(q, r) == 2 || evalPool.length < 48 || rng.nextDouble() < 0.18) {
          evalPool.add(c);
        }
      }
    }
    if (evalPool.isEmpty) evalPool.addAll(candidates.take(40));

    Map<String, dynamic>? bestAction;
    var bestScore = double.negativeInfinity;

    for (final act in evalPool) {
      final score = _scoreCandidate(seat, act);
      if (score >= 9000) return act; // Immediate win!
      final jitter = rng.nextDouble() * 0.4;
      if (score + jitter > bestScore) {
        bestScore = score + jitter;
        bestAction = act;
      }
    }

    return bestAction ?? candidates.first;
  }

  double _scoreCandidate(int seat, Map<String, dynamic> act) {
    final opp = 1 - seat;
    if (act['type'] == 'drop') {
      final shape = act['shape'] as String;
      final q = act['q'] as int;
      final r = act['r'] as int;
      final rot = act['rot'] as int;
      final cells = punctPieceCells(shape, q, r, rot);
      final id = -999;
      var blockBonus = 0.0;
      for (var i = 0; i < 3; i++) {
        final (cq, cr) = cells[i];
        for (final (dq, dr) in punctHexDirs) {
          if (topColorAt(cq + dq, cr + dr) == opp) {
            blockBonus += 4.5;
          }
        }
        _stacks[cells[i]]!.add(PunctCellEntry(pieceId: id, owner: seat, isPunct: i == 0));
      }
      final (won, _, _) = checkConnection(seat);
      final myEval = won
          ? 10000.0
          : _evaluatePosition(seat) * 0.9 - _evaluatePosition(opp) * 0.65 + blockBonus;
      for (var i = 0; i < 3; i++) {
        _stacks[cells[i]]!.removeLast();
      }
      return myEval + 2.0;
    } else {
      final pid = act['pieceId'] as int;
      final p = pieces[pid]!;
      final toQ = act['toQ'] as int;
      final toR = act['toR'] as int;
      final rot = act['rot'] as int;
      final oldQ = p.q, oldR = p.r, oldRot = p.rot;
      final oldCells = p.cells;
      final savedEntries = <PunctCellEntry>[];
      for (final c in oldCells) {
        savedEntries.add(_stacks[c]!.removeLast());
      }
      p.q = toQ;
      p.r = toR;
      p.rot = rot;
      final newCells = p.cells;
      for (var i = 0; i < 3; i++) {
        _stacks[newCells[i]]!.add(PunctCellEntry(pieceId: pid, owner: seat, isPunct: i == 0));
      }
      final (won, _, _) = checkConnection(seat);
      final (oppWon, _, _) = checkConnection(opp);
      double myEval;
      if (won) {
        myEval = 10000.0;
      } else if (oppWon) {
        myEval = -10000.0;
      } else {
        myEval = _evaluatePosition(seat) - _evaluatePosition(opp) * 1.15;
      }
      for (var i = 0; i < 3; i++) {
        _stacks[newCells[i]]!.removeLast();
      }
      p.q = oldQ;
      p.r = oldR;
      p.rot = oldRot;
      for (var i = 0; i < 3; i++) {
        _stacks[oldCells[i]]!.add(savedEntries[i]);
      }
      return myEval;
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final cellViews = <Map<String, dynamic>>[];
    for (final (q, r) in punctBoardCells) {
      final st = _stacks[(q, r)]!;
      cellViews.add({
        'q': q,
        'r': r,
        'central': isCentralHex(q, r),
        'height': st.length,
        'topColor': st.isEmpty ? -1 : st.last.owner,
        'topPieceId': st.isEmpty ? null : st.last.pieceId,
        'topIsPunct': st.isEmpty ? false : st.last.isPunct,
      });
    }

    final pieceViews = <Map<String, dynamic>>[];
    final sortedIds = pieces.keys.toList()..sort();
    for (final id in sortedIds) {
      final p = pieces[id]!;
      pieceViews.add(p.toJson(
        topMost: isPieceTopMost(id),
        level: pieceLevel(id),
      ));
    }

    return {
      'mode': mode,
      'turn': turn,
      'turnCount': turnCount,
      'maxTurns': maxTurns,
      'over': _over,
      'winner': winner,
      'winReason': winReason,
      'winningPair': winningPair,
      'winningChain': [
        for (final (q, r) in winningChain) [q, r],
      ],
      'reserves': [
        Map<String, int>.of(reserves[0]),
        Map<String, int>.of(reserves[1]),
      ],
      'totalReserves': [totalReserve(0), totalReserve(1)],
      'centralControl': [countCentralControl(0), countCentralControl(1)],
      'totalControl': [countTotalControl(0), countTotalControl(1)],
      'cells': cellViews,
      'pieces': pieceViews,
      'lastMove': lastMove,
    };
  }
}
