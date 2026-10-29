import 'dart:math';

import '../../src/engine.dart';

const List<String> dorfTerrainNames = [
  '麦田',
  '森林',
  '村落',
  '铁路',
  '河流',
];

const List<String> dorfTerrainEmojis = [
  '🌾',
  '🌲',
  '🏘️',
  '🚂',
  '🌊',
];

class DorfromantikTile {
  final int id;
  final int type; // 0: Wheat, 1: Forest, 2: Village, 3: Railway, 4: River
  final List<int> edges; // length 6 (dirs 0..5)
  final bool hasFlag;
  final int taskType; // -1 if none, 0..4 if Task Tile
  final int taskTarget; // 0 if none, 4..7 if Task Tile
  int taskState; // 0: none, 1: active, 2: fulfilled, 3: cancelled

  DorfromantikTile({
    required this.id,
    required this.type,
    List<int>? edges,
    this.hasFlag = false,
    this.taskType = -1,
    this.taskTarget = 0,
    int? taskState,
  })  : edges = edges ?? _defaultEdges(type),
        taskState = taskState ?? ((taskType >= 0 && taskTarget > 0) ? 1 : 0);

  static List<int> _defaultEdges(int type) {
    if (type == 3) return const [3, 0, 0, 3, 0, 0];
    if (type == 4) return const [4, 0, 0, 4, 0, 0];
    return List.filled(6, type);
  }

  DorfromantikTile rotated(int rot) {
    final shift = ((rot % 6) + 6) % 6;
    return DorfromantikTile(
      id: id,
      type: type,
      edges: [
        for (var d = 0; d < 6; d++) edges[(d - shift + 6) % 6],
      ],
      hasFlag: hasFlag,
      taskType: taskType,
      taskTarget: taskTarget,
      taskState: taskState,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'edges': edges,
        'hasFlag': hasFlag,
        'taskType': taskType,
        'taskTarget': taskTarget,
        'taskState': taskState,
      };
}

class DorfromantikGame extends GameEngine {
  static const List<(int, int)> hexDirs = [
    (0, -1),
    (1, -1),
    (1, 0),
    (0, 1),
    (-1, 1),
    (-1, 0),
  ];

  late final int maxTiles;
  final Map<(int, int), DorfromantikTile> grid = {};
  final List<DorfromantikTile> deck = [];
  DorfromantikTile? currentTile;

  int fulfilledTaskScore = 0;
  int fulfilledTasksCount = 0;
  int cancelledTasksCount = 0;
  late List<int> score;
  late List<int> playerContributions;

  int turn = 0;
  bool over = false;
  String lastAction = '筑梦颂歌田园铺设开始';

  DorfromantikGame(super.setup) : maxTiles = setup.opt<int>('tiles', 32);

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(score) : null;

  static (int, int) neighborOf(int q, int r, int dir) {
    final (dq, dr) = hexDirs[dir];
    return (q + dq, r + dr);
  }

  static List<(int, int)> neighbors(int q, int r) => [
        for (var d = 0; d < 6; d++) neighborOf(q, r, d),
      ];

  List<DorfromantikTile> _buildDeck() {
    final raw = <DorfromantikTile>[];
    var id = 2;
    // Task tiles for terrains 0..4 with targets 4..6
    for (var t = 0; t < 5; t++) {
      for (final target in const [4, 5, 6]) {
        raw.add(DorfromantikTile(
          id: id++,
          type: t,
          taskType: t,
          taskTarget: target,
        ));
      }
    }
    // Flag tiles for terrains 0..2
    for (var copy = 0; copy < 2; copy++) {
      for (var t = 0; t <= 2; t++) {
        raw.add(DorfromantikTile(
          id: id++,
          type: t,
          hasFlag: true,
        ));
      }
    }
    // Landscape & River/Railway tiles
    for (var copy = 0; copy < 3; copy++) {
      for (var t = 0; t < 5; t++) {
        raw.add(DorfromantikTile(
          id: id++,
          type: t,
        ));
      }
    }
    final shuffledList = shuffled(raw, rng);
    return shuffledList.take(maxTiles - 1).toList();
  }

  @override
  void start() {
    grid.clear();
    fulfilledTaskScore = 0;
    fulfilledTasksCount = 0;
    cancelledTasksCount = 0;
    score = List.filled(players, 0);
    playerContributions = List.filled(players, 0);
    turn = 0;
    over = false;

    // Starting center tile at (0, 0): Wheat with Task Target 4
    grid[(0, 0)] = DorfromantikTile(
      id: 1,
      type: 0,
      taskType: 0,
      taskTarget: 4,
    );

    deck
      ..clear()
      ..addAll(_buildDeck());
    currentTile = deck.isNotEmpty ? deck.removeLast() : null;
    _recalcAll();
  }

  bool canPlaceAt(DorfromantikTile tile, int q, int r, int rot) {
    if (grid.containsKey((q, r))) return false;
    if (grid.isNotEmpty) {
      var hasNeighbor = false;
      for (final nbPos in neighbors(q, r)) {
        if (grid.containsKey(nbPos)) {
          hasNeighbor = true;
          break;
        }
      }
      if (!hasNeighbor) return false;
    }

    final rotated = tile.rotated(rot);
    for (var d = 0; d < 6; d++) {
      final nbPos = neighborOf(q, r, d);
      final nb = grid[nbPos];
      if (nb == null) continue;
      final myEdge = rotated.edges[d];
      final nbEdge = nb.edges[(d + 3) % 6];
      // River (4) and Railway (3) Edge Constraint: must match if either side is River or Railway
      if ((myEdge == 4) != (nbEdge == 4)) return false;
      if ((myEdge == 3) != (nbEdge == 3)) return false;
    }
    return true;
  }

  List<(int, int, int)> validPlacements([DorfromantikTile? tile]) {
    final t = tile ?? currentTile;
    if (t == null) return const [];
    final frontier = <(int, int)>{};
    for (final (q, r) in grid.keys) {
      for (final nb in neighbors(q, r)) {
        if (!grid.containsKey(nb)) {
          frontier.add(nb);
        }
      }
    }
    final sortedFrontier = frontier.toList()
      ..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));

    final valid = <(int, int, int)>[];
    for (final (q, r) in sortedFrontier) {
      for (var rot = 0; rot < 6; rot++) {
        if (canPlaceAt(t, q, r, rot)) {
          valid.add((q, r, rot));
        }
      }
    }
    return valid;
  }

  Set<(int, int)> connectedComponent((int, int) startPos, int terrainType) {
    final startTile = grid[startPos];
    if (startTile == null || startTile.type != terrainType) return const {};
    final visited = <(int, int)>{startPos};
    final queue = <(int, int)>[startPos];
    while (queue.isNotEmpty) {
      final (cq, cr) = queue.removeLast();
      final cur = grid[(cq, cr)]!;
      for (var d = 0; d < 6; d++) {
        final nbPos = neighborOf(cq, cr, d);
        if (visited.contains(nbPos)) continue;
        final nb = grid[nbPos];
        if (nb == null || nb.type != terrainType) continue;
        // For River (4) and Railway (3), check edge connection if edges use 3/4, or direct type adjacency
        if (terrainType == 3 || terrainType == 4) {
          final edgeMatch =
              (cur.edges[d] == terrainType && nb.edges[(d + 3) % 6] == terrainType) ||
              (cur.type == terrainType && nb.type == terrainType);
          if (!edgeMatch) continue;
        }
        visited.add(nbPos);
        queue.add(nbPos);
      }
    }
    return visited;
  }

  void resolveTasks([int? actingSeat]) {
    for (final entry in grid.entries) {
      final pos = entry.key;
      final tile = entry.value;
      if (tile.taskState != 1 || tile.taskType < 0 || tile.taskTarget <= 0) {
        continue;
      }
      final comp = connectedComponent(pos, tile.taskType);
      final size = comp.length;
      if (size == tile.taskTarget) {
        tile.taskState = 2; // Fulfilled!
        fulfilledTaskScore += tile.taskTarget;
        fulfilledTasksCount++;
        if (actingSeat != null && actingSeat >= 0 && actingSeat < players) {
          playerContributions[actingSeat] += tile.taskTarget;
        }
      } else if (size > tile.taskTarget) {
        tile.taskState = 3; // Cancelled (0 VP)!
        cancelledTasksCount++;
      }
    }
  }

  int calcClosedFlagScore() {
    var total = 0;
    for (var terrain = 0; terrain <= 2; terrain++) {
      final visited = <(int, int)>{};
      for (final pos in grid.keys) {
        if (visited.contains(pos)) continue;
        final tile = grid[pos]!;
        if (tile.type != terrain) continue;
        final comp = connectedComponent(pos, terrain);
        visited.addAll(comp);

        var hasFlag = false;
        var isClosed = true;
        for (final p in comp) {
          final t = grid[p]!;
          if (t.hasFlag) hasFlag = true;
          for (var d = 0; d < 6; d++) {
            if (t.edges[d] == terrain) {
              final nbPos = neighborOf(p.$1, p.$2, d);
              if (!grid.containsKey(nbPos)) {
                isClosed = false;
                break;
              }
            }
          }
          if (!isClosed) break;
        }

        if (hasFlag && isClosed) {
          total += comp.length;
        }
      }
    }
    return total;
  }

  int calcLongestTerrain(int terrainType) {
    var longest = 0;
    final visited = <(int, int)>{};
    for (final pos in grid.keys) {
      if (visited.contains(pos)) continue;
      final tile = grid[pos]!;
      if (tile.type != terrainType) continue;
      final comp = connectedComponent(pos, terrainType);
      visited.addAll(comp);
      if (comp.length > longest) {
        longest = comp.length;
      }
    }
    return longest;
  }

  int calcLongestRiver() => calcLongestTerrain(4);

  int calcLongestRailway() => calcLongestTerrain(3);

  int calcTotalScore() =>
      fulfilledTaskScore +
      calcClosedFlagScore() +
      calcLongestRiver() +
      calcLongestRailway();

  void _recalcAll([int? actingSeat]) {
    resolveTasks(actingSeat);
    final total = calcTotalScore();
    for (var s = 0; s < players; s++) {
      score[s] = total;
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('尚未轮到你行动');
    if (currentTile == null) throw GameError('没有可放置的板块');

    final type = asStr(action['type']);
    if (type != 'place') throw GameError('未知操作: $type');

    final q = asInt(action['q'], 9999);
    final r = asInt(action['r'], 9999);
    final rot = asInt(action['rot'], 0);
    if (rot < 0 || rot >= 6) throw GameError('旋转角度必须在 0..5 之间');

    if (!canPlaceAt(currentTile!, q, r, rot)) {
      throw GameError('该位置违反相邻法则或河流/铁路边缘匹配规则');
    }

    final placed = currentTile!.rotated(rot);
    grid[(q, r)] = placed;
    playerContributions[seat] += 1;

    final tasksBefore = fulfilledTasksCount;
    final cancelBefore = cancelledTasksCount;
    _recalcAll(seat);
    final newlyFulfilled = fulfilledTasksCount - tasksBefore;
    final newlyCancelled = cancelledTasksCount - cancelBefore;

    var note = '';
    if (newlyFulfilled > 0) note += ' 🎯完成任务+$newlyFulfilled！';
    if (newlyCancelled > 0) note += ' 💥任务超额取消！';
    lastAction =
        '${name(seat)} 放置 ${dorfTerrainEmojis[placed.type]}${dorfTerrainNames[placed.type]} 于 ($q,$r)$note';
    host.log(lastAction);

    if (deck.isEmpty) {
      currentTile = null;
      over = true;
      _recalcAll();
      lastAction = '筑梦颂歌画卷完成！总分 ${calcTotalScore()} 分';
      host.log(lastAction);
      return;
    }

    currentTile = deck.removeLast();
    // Ensure currentTile has at least 1 valid placement
    if (validPlacements(currentTile).isEmpty) {
      over = true;
      _recalcAll();
      lastAction = '筑梦颂歌画卷完成！总分 ${calcTotalScore()} 分';
      host.log(lastAction);
      return;
    }

    turn = (turn + 1) % players;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn || currentTile == null) return null;
    final moves = validPlacements(currentTile);
    if (moves.isEmpty) return null;

    if (botLevel == 0) {
      final (q, r, rot) = moves[rng.nextInt(moves.length)];
      return {'type': 'place', 'q': q, 'r': r, 'rot': rot};
    }

    final tile = currentTile!;
    var bestVal = -999999;
    var bestMove = moves.first;
    final limit = min(moves.length, botLevel >= 2 ? 30 : 14);
    for (var i = 0; i < limit; i++) {
      final (q, r, rot) = moves[i];
      var val = 0;
      for (var d = 0; d < 6; d++) {
        final nb = grid[neighborOf(q, r, d)];
        if (nb == null) continue;
        if (nb.type == tile.type) {
          // Check if joining this group would exceed an active task
          final comp = connectedComponent(neighborOf(q, r, d), tile.type);
          var hasTask = false;
          for (final p in comp) {
            final t = grid[p]!;
            if (t.taskState == 1 && t.taskType == tile.type) {
              hasTask = true;
              if (comp.length + 1 == t.taskTarget) {
                val += 50; // Exact fulfillment!
              } else if (comp.length + 1 > t.taskTarget) {
                val -= 60; // Would cancel active task!
              } else {
                val += 15;
              }
            }
          }
          if (!hasTask) val += 8;
        } else {
          // Surrounding a flag tile of another terrain helps close it!
          if (nb.hasFlag) val += 6;
        }
      }
      if (val > bestVal) {
        bestVal = val;
        bestMove = moves[i];
      }
    }

    return {
      'type': 'place',
      'q': bestMove.$1,
      'r': bestMove.$2,
      'rot': bestMove.$3,
    };
  }

  @override
  Map<String, dynamic> view(int seat) {
    final moves = (!over && currentTile != null)
        ? validPlacements(currentTile)
        : const <(int, int, int)>[];
    return {
      'turn': turn,
      'over': over,
      'deckCount': deck.length,
      'maxTiles': maxTiles,
      'lastAction': lastAction,
      'currentTile': currentTile?.toJson(),
      'totalScore': calcTotalScore(),
      'fulfilledTaskScore': fulfilledTaskScore,
      'fulfilledTasksCount': fulfilledTasksCount,
      'cancelledTasksCount': cancelledTasksCount,
      'closedFlagScore': calcClosedFlagScore(),
      'longestRiver': calcLongestRiver(),
      'longestRailway': calcLongestRailway(),
      'validMoves': [
        for (final (q, r, rot) in moves.take(36))
          {'q': q, 'r': r, 'rot': rot},
      ],
      'tiles': [
        for (final e in grid.entries)
          {
            'q': e.key.$1,
            'r': e.key.$2,
            ...e.value.toJson(),
          },
      ],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'score': score[s],
            'contribution': playerContributions[s],
          },
      ],
    };
  }
}
