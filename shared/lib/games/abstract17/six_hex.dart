import 'dart:collection';

import '../../src/engine.dart';

/// 六角六形棋（SIX）—— Steffen Mühlhäuser 门萨精选大奖（Mensa Select）得主。
///
/// 核心规则：
/// - 无边界轴向六角网格 `(q, r)`，初始在中心放置 2 红（座位 0）与 2 黑（座位 1）共 4 枚六角砖：
///   `(0, 0): 0, (1, 0): 1, (0, 1): 0, (1, -1): 1`。
/// - 每位玩家手持 `18` 枚储备六角砖（快速模式为 `12` 枚）。
/// - **阶段 1（布子阶段 `'place'`）**：
///   - 双方轮流从储备中取出 1 枚六角砖，放置到任意与场上已有砖块相邻的空六角格 `(q, r)`（`{'type': 'place', 'q': q, 'r': r}`）。
///   - 当双方储备均耗尽（`reserve[0] == 0 && reserve[1] == 0`）且无人获胜时，进入阶段 2（移子阶段 `'move'`）。
/// - **阶段 2（移子阶段 `'move'`）**：
///   - 双方轮流将场上 1 枚己方外缘六角砖 `(fromQ, fromR)` 移动到另一个与剩余棋盘相连的空六角格 `(toQ, toR)`
///     （`{'type': 'move', 'fromQ': q1, 'fromR': r1, 'toQ': q2, 'toR': r2}`）。
///   - 若移除 `(fromQ, fromR)` 后棋盘分裂为不连通的岛屿，则自动淘汰移除较小的孤立岛屿（保留最大连通主岛）。
/// - **三种六子即时获胜图形（Three Winning Shapes of 6）**：
///   1. **六子直线（`'line'`）**：沿任意六角轴向（`(1,0)`, `(0,1)`, `(1,-1)`）连续排成 6 枚己方六角砖！
///   2. **六子圆环（`'ring'`）**：围绕任意中心格 `(cq, cr)` 的全部 6 个相邻六角格均被己方六角砖占领！
///   3. **六子三角（`'triangle'`）**：由 `1 + 2 + 3 = 6` 枚己方六角砖组成的正/倒等边三角形！
class SixHexGame extends GameEngine {
  SixHexGame(super.setup);

  static const List<(int, int)> kHexDirs = [
    (1, 0),
    (-1, 0),
    (0, 1),
    (0, -1),
    (1, -1),
    (-1, 1),
  ];

  static const List<(int, int)> kHexAxes = [
    (1, 0),
    (0, 1),
    (1, -1),
  ];

  static const List<(int, int)> kTriUp = [
    (0, 0),
    (1, 0),
    (2, 0),
    (0, 1),
    (1, 1),
    (0, 2),
  ];

  static const List<(int, int)> kTriDown = [
    (0, 0),
    (-1, 0),
    (-2, 0),
    (0, -1),
    (-1, -1),
    (0, -2),
  ];

  static const Map<String, String> kShapeNames = {
    'line': '六子直线',
    'ring': '六子圆环',
    'triangle': '六子三角',
  };

  late String mode;
  final Map<(int, int), int> board = {};
  List<int> reserve = [18, 18];
  String phase = 'place';

  int turn = 0;
  bool over = false;
  int? winner;
  String? winReason;
  String? winningShape;
  List<(int, int)> winningCells = [];
  List<int>? _placings;
  int moveCount = 0;
  Map<String, dynamic>? lastMove;

  int? getTile(int q, int r) => board[(q, r)];

  void setTile(int q, int r, int? owner) {
    if (owner == null || owner < 0) {
      board.remove((q, r));
    } else {
      board[(q, r)] = owner;
    }
  }

  @override
  void start() {
    mode = setup.opt<String>('mode', 'standard');
    final initReserve = mode == 'quick' ? 12 : 18;
    reserve = [initReserve, initReserve];

    board.clear();
    // Classic 4-tile diamond starting configuration:
    board[(0, 0)] = 0;
    board[(1, 0)] = 1;
    board[(0, 1)] = 0;
    board[(1, -1)] = 1;

    phase = 'place';
    turn = 0;
    over = false;
    winner = null;
    winReason = null;
    winningShape = null;
    winningCells = [];
    _placings = null;
    moveCount = 0;
    lastMove = null;
  }

  /// Returns all empty hexes `(q, r)` adjacent to at least 1 occupied hex in `tiles`.
  static List<(int, int)> emptyNeighborsOf(Iterable<(int, int)> tiles) {
    final occupied = tiles.toSet();
    final seen = <(int, int)>{};
    final result = <(int, int)>[];
    for (final (q, r) in occupied) {
      for (final (dq, dr) in kHexDirs) {
        final npos = (q + dq, r + dr);
        if (!occupied.contains(npos) && seen.add(npos)) {
          result.add(npos);
        }
      }
    }
    return result;
  }

  List<(int, int)> legalPlacements() => emptyNeighborsOf(board.keys);

  int occupiedNeighborCount(int q, int r, [Map<(int, int), int>? b]) {
    final map = b ?? board;
    var c = 0;
    for (final (dq, dr) in kHexDirs) {
      if (map.containsKey((q + dq, r + dr))) c++;
    }
    return c;
  }

  /// Connected components of `coords`.
  static List<Set<(int, int)>> connectedComponents(Set<(int, int)> coords) {
    final unvisited = Set<(int, int)>.of(coords);
    final comps = <Set<(int, int)>>[];
    while (unvisited.isNotEmpty) {
      final start = unvisited.first;
      unvisited.remove(start);
      final comp = <(int, int)>{start};
      final q = Queue<(int, int)>()..add(start);
      while (q.isNotEmpty) {
        final (cq, cr) = q.removeFirst();
        for (final (dq, dr) in kHexDirs) {
          final nb = (cq + dq, cr + dr);
          if (unvisited.remove(nb)) {
            comp.add(nb);
            q.add(nb);
          }
        }
      }
      comps.add(comp);
    }
    return comps;
  }

  /// Checks whether `(fromQ, fromR)` is an outer-edge tile of `seat` that can be lifted,
  /// and returns the remaining main component of the board after lifting it (or `null` if invalid).
  Set<(int, int)>? remainingAfterLift(int seat, int fromQ, int fromR) {
    if (board[(fromQ, fromR)] != seat) return null;
    // Outer-edge tile must have at least 1 empty neighbor (< 6 occupied neighbors)
    if (occupiedNeighborCount(fromQ, fromR) >= 6) return null;

    final rem = Set<(int, int)>.of(board.keys)..remove((fromQ, fromR));
    if (rem.isEmpty) return null;

    final comps = connectedComponents(rem);
    if (comps.length == 1) return comps.first;

    // Sort components by size descending; if tied, prefer component closest to (0, 0)
    comps.sort((a, b) {
      final cmp = b.length.compareTo(a.length);
      if (cmp != 0) return cmp;
      int minDist(Set<(int, int)> s) {
        var best = 999999;
        for (final (q, r) in s) {
          final d = q.abs() + r.abs() + (q + r).abs();
          if (d < best) best = d;
        }
        return best;
      }
      return minDist(a).compareTo(minDist(b));
    });
    return comps.first;
  }

  bool canMoveTile(int seat, int fromQ, int fromR, int toQ, int toR) {
    if (fromQ == toQ && fromR == toR) return false;
    if (board.containsKey((toQ, toR))) return false;
    final mainComp = remainingAfterLift(seat, fromQ, fromR);
    if (mainComp == null) return false;
    for (final (dq, dr) in kHexDirs) {
      if (mainComp.contains((toQ + dq, toR + dr))) return true;
    }
    return false;
  }

  List<Map<String, int>> legalMovesInMovePhase(int seat) {
    final nonCutMoves = <Map<String, int>>[];
    final cutMoves = <Map<String, int>>[];
    final totalRemaining = board.length - 1;

    for (final entry in board.entries) {
      if (entry.value != seat) continue;
      final (fq, fr) = entry.key;
      final mainComp = remainingAfterLift(seat, fq, fr);
      if (mainComp == null) continue;
      final isNonCut = mainComp.length == totalRemaining;
      final targets = emptyNeighborsOf(mainComp);
      for (final (tq, tr) in targets) {
        if (tq == fq && tr == fr) continue;
        if (board.containsKey((tq, tr))) continue;
        final m = {
          'fromQ': fq,
          'fromR': fr,
          'toQ': tq,
          'toR': tr,
        };
        if (isNonCut) {
          nonCutMoves.add(m);
        } else {
          cutMoves.add(m);
        }
      }
    }
    return nonCutMoves.isNotEmpty ? nonCutMoves : cutMoves;
  }

  /// Checks if `seat` has formed any of the 3 winning shapes of 6 on `b` (defaults to `board`).
  /// Returns `(shapeType, cells)` where `shapeType` is `'line'`, `'ring'`, or `'triangle'`.
  (String, List<(int, int)>)? findWinningShape(int seat, [Map<(int, int), int>? b]) {
    final map = b ?? board;
    final myCells = <(int, int)>[
      for (final e in map.entries)
        if (e.value == seat) e.key,
    ];
    if (myCells.length < 6) return null;
    final mySet = myCells.toSet();

    // 1. Line of 6 along any of the 3 hex axes
    for (final (q, r) in myCells) {
      for (final (dq, dr) in kHexAxes) {
        var ok = true;
        for (var k = 1; k < 6; k++) {
          if (!mySet.contains((q + dq * k, r + dr * k))) {
            ok = false;
            break;
          }
        }
        if (ok) {
          return (
            'line',
            [for (var k = 0; k < 6; k++) (q + dq * k, r + dr * k)],
          );
        }
      }
    }

    // 2. Ring of 6 around any center hex (cq, cr)
    final checkedCenters = <(int, int)>{};
    for (final (q, r) in myCells) {
      for (final (dq, dr) in kHexDirs) {
        final center = (q + dq, r + dr);
        if (!checkedCenters.add(center)) continue;
        var ok = true;
        for (final (ndq, ndr) in kHexDirs) {
          if (!mySet.contains((center.$1 + ndq, center.$2 + ndr))) {
            ok = false;
            break;
          }
        }
        if (ok) {
          return (
            'ring',
            [for (final (ndq, ndr) in kHexDirs) (center.$1 + ndq, center.$2 + ndr)],
          );
        }
      }
    }

    // 3. Triangle of 6 (1 + 2 + 3 equilateral triangle in either orientation)
    for (final (q, r) in myCells) {
      var okUp = true;
      for (final (dq, dr) in kTriUp) {
        if (!mySet.contains((q + dq, r + dr))) {
          okUp = false;
          break;
        }
      }
      if (okUp) {
        return (
          'triangle',
          [for (final (dq, dr) in kTriUp) (q + dq, r + dr)],
        );
      }

      var okDown = true;
      for (final (dq, dr) in kTriDown) {
        if (!mySet.contains((q + dq, r + dr))) {
          okDown = false;
          break;
        }
      }
      if (okDown) {
        return (
          'triangle',
          [for (final (dq, dr) in kTriDown) (q + dq, r + dr)],
        );
      }
    }

    return null;
  }

  void _endWithShape(int winSeat, String shape, List<(int, int)> cells) {
    over = true;
    winner = winSeat;
    winningShape = shape;
    winningCells = cells;
    _placings = winSeat == 0 ? [1, 2] : [2, 1];
    final label = kShapeNames[shape] ?? shape;
    winReason = '${name(winSeat)} 成功构筑「$label」，获得胜利！';
    host.log(winReason!);
  }

  void _endGame(int winSeat, String reason) {
    over = true;
    winner = winSeat;
    _placings = winSeat == 0
        ? [1, 2]
        : (winSeat == 1 ? [2, 1] : [1, 1]);
    winReason = reason;
    host.log(reason);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('当前不是你的回合');

    final type = asStr(action['type']);
    if (phase == 'place') {
      if (type != 'place') throw GameError('当前处于布子阶段，请放置六角砖');
      if (reserve[seat] <= 0) throw GameError('你的储备六角砖已用尽');

      final q = asInt(action['q'], 999999);
      final r = asInt(action['r'], 999999);
      if (q == 999999 || r == 999999) throw GameError('六角格坐标无效');
      if (board.containsKey((q, r))) throw GameError('目标六角格 ($q, $r) 已有砖块');
      if (occupiedNeighborCount(q, r) == 0) {
        throw GameError('新放置的六角砖必须与场上已有砖块相邻');
      }

      board[(q, r)] = seat;
      reserve[seat]--;
      moveCount++;
      lastMove = {
        'type': 'place',
        'seat': seat,
        'q': q,
        'r': r,
      };
      host.log('${name(seat)} 在 ($q, $r) 放置六角砖（剩余储备 ${reserve[seat]}）');

      final win = findWinningShape(seat);
      if (win != null) {
        _endWithShape(seat, win.$1, win.$2);
        return;
      }

      if (reserve[0] == 0 && reserve[1] == 0) {
        phase = 'move';
        host.log('双方储备六角砖全部放完，进入第二阶段：移子阶段！');
      }

      turn = 1 - turn;
      if (phase == 'move' && legalMovesInMovePhase(turn).isEmpty) {
        _endGame(seat, '${name(turn)} 无可移动的外缘六角砖，${name(seat)} 获胜！');
      }
      return;
    }

    if (phase == 'move') {
      if (type != 'move') throw GameError('当前处于移子阶段，请移动外缘六角砖');
      final fromQ = asInt(action['fromQ'], 999999);
      final fromR = asInt(action['fromR'], 999999);
      final toQ = asInt(action['toQ'], 999999);
      final toR = asInt(action['toR'], 999999);

      if (board[(fromQ, fromR)] != seat) {
        throw GameError('只能选择己方在场上的六角砖进行移动');
      }
      if (occupiedNeighborCount(fromQ, fromR) >= 6) {
        throw GameError('被 6 枚砖块完全包围的内部砖块无法移动');
      }
      if (fromQ == toQ && fromR == toR) {
        throw GameError('目标格不能与起始格相同');
      }
      if (board.containsKey((toQ, toR))) {
        throw GameError('目标六角格 ($toQ, $toR) 已被占据');
      }

      final mainComp = remainingAfterLift(seat, fromQ, fromR);
      if (mainComp == null) {
        throw GameError('无法移除该六角砖');
      }

      var adjToMain = false;
      for (final (dq, dr) in kHexDirs) {
        if (mainComp.contains((toQ + dq, toR + dr))) {
          adjToMain = true;
          break;
        }
      }
      if (!adjToMain) {
        throw GameError('移动后的目标格 ($toQ, $toR) 必须与剩余棋盘主连通群相邻');
      }

      // Remove lifted tile and any dropped smaller disconnected islands
      final droppedCount = (board.length - 1) - mainComp.length;
      board.remove((fromQ, fromR));
      if (droppedCount > 0) {
        board.removeWhere((k, _) => !mainComp.contains(k));
      }
      board[(toQ, toR)] = seat;
      moveCount++;

      lastMove = {
        'type': 'move',
        'seat': seat,
        'fromQ': fromQ,
        'fromR': fromR,
        'toQ': toQ,
        'toR': toR,
        'dropped': droppedCount,
      };
      host.log(
        '${name(seat)} 将六角砖从 ($fromQ, $fromR) 移至 ($toQ, $toR)'
        '${droppedCount > 0 ? '（脱落移除 $droppedCount 枚孤岛砖）' : ''}',
      );

      final win = findWinningShape(seat);
      if (win != null) {
        _endWithShape(seat, win.$1, win.$2);
        return;
      }

      final opp = 1 - seat;
      final winOpp = findWinningShape(opp);
      if (winOpp != null) {
        _endWithShape(opp, winOpp.$1, winOpp.$2);
        return;
      }

      // Check if either player has fewer than 6 tiles left on board
      final count0 = board.values.where((v) => v == 0).length;
      final count1 = board.values.where((v) => v == 1).length;
      if (count0 < 6 && count1 < 6) {
        _endGame(-1, '双方场上剩余六角砖均不足 6 枚，对局平局！');
        return;
      } else if (count0 < 6) {
        _endGame(1, '${name(0)} 场上剩余六角砖不足 6 枚，${name(1)} 获胜！');
        return;
      } else if (count1 < 6) {
        _endGame(0, '${name(1)} 场上剩余六角砖不足 6 枚，${name(0)} 获胜！');
        return;
      }

      turn = opp;
      if (legalMovesInMovePhase(opp).isEmpty) {
        _endGame(seat, '${name(opp)} 无合法移动步数，${name(seat)} 获胜！');
        return;
      }

      if (moveCount >= 110) {
        final s0 = _bestTemplateProgress(0, board);
        final s1 = _bestTemplateProgress(1, board);
        if (s0 > s1) {
          _endGame(0, '移子阶段达到回合上限，${name(0)} 阵型完成度更高获胜！');
        } else if (s1 > s0) {
          _endGame(1, '移子阶段达到回合上限，${name(1)} 阵型完成度更高获胜！');
        } else {
          _endGame(-1, '移子阶段达到回合上限，双方势均力敌握手言和！');
        }
      }
      return;
    }

    throw GameError('未知阶段：$phase');
  }

  /// Evaluates how close `seat` is to forming a Line of 6, Ring of 6, or Triangle of 6 on `b`.
  static double _bestTemplateProgress(int seat, Map<(int, int), int> b) {
    final opp = 1 - seat;
    var score = 0.0;
    final anchors = <(int, int)>{...b.keys};
    for (final (q, r) in b.keys) {
      for (final (dq, dr) in kHexDirs) {
        anchors.add((q + dq, r + dr));
      }
    }

    void evalTemplate(List<(int, int)> cells) {
      var myCnt = 0;
      for (final pos in cells) {
        final v = b[pos];
        if (v == opp) return; // Blocked by opponent in place phase
        if (v == seat) myCnt++;
      }
      if (myCnt >= 6) {
        score += 100000.0;
      } else if (myCnt == 5) {
        score += 450.0;
      } else if (myCnt == 4) {
        score += 55.0;
      } else if (myCnt == 3) {
        score += 8.0;
      } else if (myCnt == 2) {
        score += 1.2;
      }
    }

    for (final (q, r) in anchors) {
      for (final (dq, dr) in kHexAxes) {
        evalTemplate([for (var k = 0; k < 6; k++) (q + dq * k, r + dr * k)]);
      }
      evalTemplate([for (final (dq, dr) in kHexDirs) (q + dq, r + dr)]);
      evalTemplate([for (final (dq, dr) in kTriUp) (q + dq, r + dr)]);
      evalTemplate([for (final (dq, dr) in kTriDown) (q + dq, r + dr)]);
    }
    return score;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    final opp = 1 - seat;

    if (phase == 'place') {
      final targets = legalPlacements();
      if (targets.isEmpty) return null;

      // Always take an immediate win if available
      for (final (q, r) in targets) {
        board[(q, r)] = seat;
        final win = findWinningShape(seat);
        board.remove((q, r));
        if (win != null) {
          return {'type': 'place', 'q': q, 'r': r};
        }
      }

      // Always block an opponent's immediate 1-move win if available
      for (final (q, r) in targets) {
        board[(q, r)] = opp;
        final oppWin = findWinningShape(opp);
        board.remove((q, r));
        if (oppWin != null) {
          return {'type': 'place', 'q': q, 'r': r};
        }
      }

      if (botLevel <= 0) {
        final pick = targets[rng.nextInt(targets.length)];
        return {'type': 'place', 'q': pick.$1, 'r': pick.$2};
      }

      var bestVal = -1e9;
      var bestTargets = <(int, int)>[];
      for (final (q, r) in targets) {
        board[(q, r)] = seat;
        final myProg = _bestTemplateProgress(seat, board);
        final oppProg = _bestTemplateProgress(opp, board);
        board.remove((q, r));

        final val = myProg * 1.15 - oppProg * 0.95 + rng.nextDouble() * 0.5;
        if (val > bestVal) {
          bestVal = val;
          bestTargets = [(q, r)];
        }
      }
      final chosen = bestTargets[rng.nextInt(bestTargets.length)];
      return {'type': 'place', 'q': chosen.$1, 'r': chosen.$2};
    } else {
      final moves = legalMovesInMovePhase(seat);
      if (moves.isEmpty) return null;

      for (final m in moves) {
        final fq = m['fromQ']!;
        final fr = m['fromR']!;
        final tq = m['toQ']!;
        final tr = m['toR']!;
        final sim = Map<(int, int), int>.of(board)..remove((fq, fr));
        sim[(tq, tr)] = seat;
        if (findWinningShape(seat, sim) != null) {
          return {'type': 'move', ...m};
        }
      }

      if (botLevel <= 0) {
        final pick = moves[rng.nextInt(moves.length)];
        return {'type': 'move', ...pick};
      }

      var bestVal = -1e9;
      var bestMove = moves.first;
      // Sample up to 40 candidate moves for fast evaluation
      final candidates = moves.length <= 40
          ? moves
          : (shuffled(moves, rng).take(40).toList());
      for (final m in candidates) {
        final fq = m['fromQ']!;
        final fr = m['fromR']!;
        final tq = m['toQ']!;
        final tr = m['toR']!;
        final sim = Map<(int, int), int>.of(board)..remove((fq, fr));
        sim[(tq, tr)] = seat;
        final val = _bestTemplateProgress(seat, sim) * 1.1 -
            _bestTemplateProgress(opp, sim) * 0.9 +
            rng.nextDouble() * 0.5;
        if (val > bestVal) {
          bestVal = val;
          bestMove = m;
        }
      }
      return {'type': 'move', ...bestMove};
    }
  }

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (over) throw GameError('对局已结束');
    _endGame(1 - seat, '${name(seat)} 认输，${name(1 - seat)} 获胜！');
  }

  @override
  bool get canDraw => true;

  @override
  void agreeDraw() {
    if (over) throw GameError('对局已结束');
    _endGame(-1, '双方同意和棋！');
  }

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => _placings;

  @override
  Map<String, dynamic> view(int seat) {
    final cells = <Map<String, int>>[
      for (final e in board.entries)
        {
          'q': e.key.$1,
          'r': e.key.$2,
          'owner': e.value,
        },
    ];

    final legalPlaceList = (!over && phase == 'place')
        ? [
            for (final (q, r) in legalPlacements()) {'q': q, 'r': r},
          ]
        : const <Map<String, int>>[];

    final legalMoveList = (!over && phase == 'move')
        ? legalMovesInMovePhase(turn)
        : const <Map<String, int>>[];

    return {
      'mode': mode,
      'phase': phase,
      'reserve': List<int>.of(reserve),
      'cells': cells,
      'turn': turn,
      'over': over,
      'winner': winner,
      'winReason': winReason,
      'winningShape': winningShape,
      'winningCells': [
        for (final (q, r) in winningCells) [q, r],
      ],
      'moveCount': moveCount,
      'lastMove': lastMove,
      'legalPlacements': legalPlaceList,
      'legalMoves': legalMoveList,
    };
  }
}
