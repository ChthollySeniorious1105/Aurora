import 'dart:math';

import '../../src/engine.dart';

/// 追赶大集群棋（Catchup）—— Nick Bentley 经典六角网格“1-2-3 子追赶触发”连通群博弈名作。
///
/// 核心规则：
/// - 六角网格棋盘：快速模式半径 `3`（37 格），标准模式半径 `4`（61 格）。
/// - 首回合（Turn 1）：先手（玩家 0）放置 `1` 枚棋子（`quota = 1`）。
/// - 后续回合：当前行动玩家可放置 `1..quota` 枚棋子（每放一子执行 `place`，放满 `quota` 子或棋盘填满时自动结束回合；若已放至少 `1` 子且未满 `quota`，也可主动执行 `end_turn` 提前结束回合）。
/// - 成大群触发三子追赶法则（Catchup Trigger）：
///   - 在玩家 `seat` 回合开始时，记录其当前最大连通群大小 `startMax = maxGroupSize(seat)`。
///   - 在玩家 `seat` 回合结束时，计算 `endMax = maxGroupSize(seat)` 与对手最大连通群大小 `oppMax = maxGroupSize(1 - seat)`。
///   - 若 `oppMax > 0 && endMax > startMax && endMax >= oppMax`（即本回合扩大或新建了己方最大连通群，且其规模追平或超越了对手的最大连通群），则对手紧接着的下一回合落子配额变为 `quota = 3`；否则对手下一回合配额为默认的 `quota = 2`！
/// - 终局计分与字典序比较决胜：
///   - 当棋盘所有六角格全部填满时对局结束。
///   - 将双方各自所有同色连通群的大小按从大到小排序得到列表 `groups(0)` 与 `groups(1)`，从第 1 大群开始逐项比较，首个大小不同的位置上群更大的一方获胜！
class CatchupGame extends GameEngine {
  CatchupGame(super.setup);

  static const List<(int, int)> kHexDirs = [
    (1, 0),
    (-1, 0),
    (0, 1),
    (0, -1),
    (1, -1),
    (-1, 1),
  ];

  late String mode;
  late int radius;
  late List<(int, int)> allHexes;

  /// Keyed by `(q, r)`. `-1` (or absent) = empty, `0` = Player 0, `1` = Player 1.
  final Map<(int, int), int> _owner = {};

  int turn = 0;
  int quota = 1;
  int placedThisTurn = 0;
  int startMax = 0;
  bool catchupTriggered = false;
  int turnNumber = 0;

  bool over = false;
  int? winner;
  String? winReason;
  int? decideGroupIndex;
  List<int>? _placings;
  List<Map<String, int>> lastTurnPlacements = [];
  List<Map<String, int>> currentTurnPlacements = [];

  int get totalHexes => allHexes.length;

  int get emptyCount => totalHexes - _owner.length;

  bool isValidHex(int q, int r) =>
      q.abs() <= radius && r.abs() <= radius && (q + r).abs() <= radius;

  int getOwner(int q, int r) => _owner[(q, r)] ?? -1;

  void setStone(int q, int r, int owner) {
    if (!isValidHex(q, r)) return;
    if (owner < 0) {
      _owner.remove((q, r));
    } else {
      _owner[(q, r)] = owner;
    }
    if (placedThisTurn == 0) {
      startMax = maxGroupSize(turn);
    }
  }

  @override
  void start() {
    mode = setup.opt<String>('mode', 'standard');
    radius = mode == 'quick' ? 3 : 4;
    allHexes = [
      for (var r = -radius; r <= radius; r++)
        for (var q = -radius; q <= radius; q++)
          if ((q + r).abs() <= radius) (q, r),
    ];
    _owner.clear();

    turn = 0;
    quota = 1;
    placedThisTurn = 0;
    startMax = 0;
    catchupTriggered = false;
    turnNumber = 0;
    over = false;
    winner = null;
    winReason = null;
    decideGroupIndex = null;
    _placings = null;
    lastTurnPlacements = [];
    currentTurnPlacements = [];
  }

  /// Sorted list of connected group sizes for [seat] in descending order.
  List<int> groups(int seat) {
    final visited = <(int, int)>{};
    final sizes = <int>[];
    for (final hex in allHexes) {
      if (_owner[hex] != seat || visited.contains(hex)) continue;
      var compSize = 0;
      final queue = <(int, int)>[hex];
      visited.add(hex);
      var head = 0;
      while (head < queue.length) {
        final (cq, cr) = queue[head++];
        compSize++;
        for (final (dq, dr) in kHexDirs) {
          final nq = cq + dq;
          final nr = cr + dr;
          final nh = (nq, nr);
          if (!visited.contains(nh) && _owner[nh] == seat) {
            visited.add(nh);
            queue.add(nh);
          }
        }
      }
      sizes.add(compSize);
    }
    sizes.sort((a, b) => b.compareTo(a));
    return sizes;
  }

  int maxGroupSize(int seat) {
    final g = groups(seat);
    return g.isEmpty ? 0 : g.first;
  }

  /// Map each occupied hex `(q, r)` to the size of its connected group (for UI badges).
  Map<(int, int), int> groupSizeMap() {
    final visited = <(int, int)>{};
    final out = <(int, int), int>{};
    for (final hex in allHexes) {
      final seat = _owner[hex];
      if (seat == null || visited.contains(hex)) continue;
      final comp = <(int, int)>[hex];
      visited.add(hex);
      var head = 0;
      while (head < comp.length) {
        final (cq, cr) = comp[head++];
        for (final (dq, dr) in kHexDirs) {
          final nh = (cq + dq, cr + dr);
          if (!visited.contains(nh) && _owner[nh] == seat) {
            visited.add(nh);
            comp.add(nh);
          }
        }
      }
      for (final h in comp) {
        out[h] = comp.length;
      }
    }
    return out;
  }

  void _finishGame() {
    over = true;
    final g0 = groups(0);
    final g1 = groups(1);
    final minLen = min(g0.length, g1.length);
    int? decider;
    int? winSeat;
    for (var i = 0; i < minLen; i++) {
      if (g0[i] != g1[i]) {
        decider = i;
        winSeat = g0[i] > g1[i] ? 0 : 1;
        break;
      }
    }
    if (winSeat == null) {
      if (g0.length != g1.length) {
        decider = minLen;
        winSeat = g0.length > g1.length ? 0 : 1;
      } else {
        winSeat = -1;
      }
    }

    decideGroupIndex = decider;
    winner = winSeat;
    if (winSeat == 0) {
      _placings = [1, 2];
    } else if (winSeat == 1) {
      _placings = [2, 1];
    } else {
      _placings = [1, 1];
    }

    final g0Str = g0.isEmpty ? '[0]' : '[${g0.take(5).join(', ')}${g0.length > 5 ? ', …' : ''}]';
    final g1Str = g1.isEmpty ? '[0]' : '[${g1.take(5).join(', ')}${g1.length > 5 ? ', …' : ''}]';
    if (winSeat >= 0) {
      final rankLabel = decider != null ? '第 ${decider + 1} 大连通群' : '连通群数量';
      winReason = '棋盘填满！${name(0)} 群序列 $g0Str vs ${name(1)} 群序列 $g1Str，凭$rankLabel优势，${name(winSeat)} 获胜！';
    } else {
      winReason = '棋盘填满！双方连通群序列完全相同 $g0Str，平局！';
    }
    host.log(winReason!);
  }

  void _endCurrentTurn() {
    final seat = turn;
    final opp = 1 - seat;
    final endMax = maxGroupSize(seat);
    final oppMax = maxGroupSize(opp);

    lastTurnPlacements = List.of(currentTurnPlacements);
    currentTurnPlacements = [];

    if (emptyCount == 0) {
      _finishGame();
      return;
    }

    final triggered = oppMax > 0 && endMax > startMax && endMax >= oppMax;
    if (triggered) {
      quota = 3;
      catchupTriggered = true;
      host.log('${name(seat)} 将最大群由 $startMax 扩大至 $endMax（追平/超越对手最大群 $oppMax），触发 ${name(opp)} 下回合 3 子追赶配额！');
    } else {
      quota = 2;
      catchupTriggered = false;
    }

    turn = opp;
    turnNumber++;
    placedThisTurn = 0;
    startMax = maxGroupSize(turn);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('当前不是你的回合');

    final type = asStr(action['type']);
    if (type == 'place') {
      final q = asInt(action['q'], 999);
      final r = asInt(action['r'], 999);
      if (!isValidHex(q, r)) throw GameError('目标六角格坐标越界');
      if (getOwner(q, r) != -1) throw GameError('该六角格已有棋子');
      if (placedThisTurn >= quota) throw GameError('本回合落子配额已满');

      _owner[(q, r)] = seat;
      placedThisTurn++;
      currentTurnPlacements.add({'q': q, 'r': r, 'seat': seat});

      if (emptyCount == 0 || placedThisTurn >= quota) {
        _endCurrentTurn();
      }
      return;
    }

    if (type == 'end_turn') {
      if (placedThisTurn < 1) {
        throw GameError('每回合至少需要放置 1 枚棋子后才能结束回合');
      }
      _endCurrentTurn();
      return;
    }

    throw GameError('未知操作类型：$type');
  }

  static int _hexDist(int q1, int r1, int q2, int r2) =>
      ((q1 - q2).abs() + (r1 - r2).abs() + ((q1 + r1) - (q2 + r2)).abs()) ~/ 2;

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    final empties = <(int, int)>[
      for (final hex in allHexes)
        if (!_owner.containsKey(hex)) hex,
    ];
    if (empties.isEmpty) return {'type': 'end_turn'};

    if (botLevel <= 0) {
      final pick = empties[rng.nextInt(empties.length)];
      return {'type': 'place', 'q': pick.$1, 'r': pick.$2};
    }

    final opp = 1 - seat;
    final compSizes = groupSizeMap();
    final oppMax = maxGroupSize(opp);

    var bestVal = -1e9;
    var bestHexes = <(int, int)>[];

    for (final (q, r) in empties) {
      var friendlyAdjGroups = 0;
      var friendlyAdjMax = 0;
      var enemyAdjGroups = 0;
      var enemyAdjSum = 0;

      for (final (dq, dr) in kHexDirs) {
        final nh = (q + dq, r + dr);
        final o = _owner[nh];
        final sz = compSizes[nh] ?? 0;
        if (o == seat) {
          friendlyAdjGroups++;
          if (sz > friendlyAdjMax) friendlyAdjMax = sz;
        } else if (o == opp) {
          enemyAdjGroups++;
          enemyAdjSum += sz;
        }
      }

      var val = (radius - _hexDist(q, r, 0, 0)) * 1.5;
      // Connecting multiple friendly groups or growing a group
      val += friendlyAdjMax * 5.0 + friendlyAdjGroups * 4.0;
      // Blocking opponent from merging multiple enemy groups
      if (enemyAdjGroups >= 2) {
        val += enemyAdjSum * 4.5;
      } else if (enemyAdjGroups == 1) {
        val += enemyAdjSum * 1.5;
      }

      if (botLevel >= 2) {
        _owner[(q, r)] = seat;
        final newMax = maxGroupSize(seat);
        final gMy = groups(seat);
        _owner.remove((q, r));

        final secondGroup = gMy.length >= 2 ? gMy[1] : 0;
        val += newMax * 4.0 + secondGroup * 3.0;

        // Avoid prematurely triggering opponent's 3-stone catchup on our last stone of the turn
        // if we only barely tie oppMax and could instead grow our 2nd largest group!
        final isLastPlacementOfTurn = (placedThisTurn + 1 >= quota);
        if (isLastPlacementOfTurn &&
            oppMax > 0 &&
            newMax > startMax &&
            newMax == oppMax &&
            emptyCount > 6) {
          val -= 8.0;
        }
      }

      if (val > bestVal + 1e-6) {
        bestVal = val;
        bestHexes = [(q, r)];
      } else if ((val - bestVal).abs() <= 1e-6) {
        bestHexes.add((q, r));
      }
    }

    final chosen = bestHexes[rng.nextInt(bestHexes.length)];
    return {'type': 'place', 'q': chosen.$1, 'r': chosen.$2};
  }

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (over) throw GameError('对局已结束');
    over = true;
    winner = 1 - seat;
    _placings = [for (var i = 0; i < players; i++) i == winner ? 1 : 2];
    winReason = '${name(seat)} 认输，${name(winner!)} 获胜！';
    host.log(winReason!);
  }

  @override
  bool get canDraw => true;

  @override
  void agreeDraw() {
    if (over) throw GameError('对局已结束');
    over = true;
    winner = -1;
    _placings = [1, 1];
    winReason = '双方同意和棋！';
    host.log(winReason!);
  }

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => _placings;

  @override
  Map<String, dynamic> view(int seat) {
    final szMap = groupSizeMap();
    final cells = <Map<String, dynamic>>[];
    for (final (q, r) in allHexes) {
      final o = getOwner(q, r);
      cells.add({
        'q': q,
        'r': r,
        'owner': o,
        'groupSize': szMap[(q, r)] ?? 0,
      });
    }

    final g0 = groups(0);
    final g1 = groups(1);

    return {
      'mode': mode,
      'radius': radius,
      'totalHexes': totalHexes,
      'emptyCount': emptyCount,
      'cells': cells,
      'turn': turn,
      'quota': quota,
      'placedThisTurn': placedThisTurn,
      'startMax': startMax,
      'catchupTriggered': catchupTriggered,
      'turnNumber': turnNumber,
      'groups': [g0, g1],
      'maxGroups': [g0.isEmpty ? 0 : g0.first, g1.isEmpty ? 0 : g1.first],
      'over': over,
      'winner': winner,
      'winReason': winReason,
      'decideGroupIndex': decideGroupIndex,
      'lastTurnPlacements': lastTurnPlacements,
      'currentTurnPlacements': currentTurnPlacements,
    };
  }
}
