import 'dart:collection';

import '../../src/engine.dart';

class RailroadRouteTemplate {
  final String id;
  final String name;
  final String emoji;
  /// Base edges `[N, E, S, W]`, where `0 = Empty`, `1 = Highway (🛣️)`, `2 = Railway (🛤️)`.
  final List<int> baseEdges;
  final bool isOverpass;
  final bool isStation;
  final bool isSpecial;

  const RailroadRouteTemplate({
    required this.id,
    required this.name,
    required this.emoji,
    required this.baseEdges,
    this.isOverpass = false,
    this.isStation = false,
    this.isSpecial = false,
  });

  List<int> rotatedEdges(int rot) {
    final r = ((rot % 4) + 4) % 4;
    return [
      for (var d = 0; d < 4; d++) baseEdges[(d - r + 4) % 4],
    ];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'baseEdges': baseEdges,
        'isOverpass': isOverpass,
        'isStation': isStation,
        'isSpecial': isSpecial,
      };
}

class RailroadPlacedTile {
  final String templateId;
  final String name;
  final String emoji;
  final int rot;
  final List<int> edges; // [N, E, S, W] after rotation
  final bool isOverpass;
  final bool isStation;
  final bool isSpecial;

  const RailroadPlacedTile({
    required this.templateId,
    required this.name,
    required this.emoji,
    required this.rot,
    required this.edges,
    this.isOverpass = false,
    this.isStation = false,
    this.isSpecial = false,
  });

  Map<String, dynamic> toJson() => {
        'templateId': templateId,
        'name': name,
        'emoji': emoji,
        'rot': rot,
        'edges': edges,
        'isOverpass': isOverpass,
        'isStation': isStation,
        'isSpecial': isSpecial,
      };
}

class RailroadInkGame extends GameEngine {
  static const int size = 7;
  static const int maxSpecialsPerGame = 3;

  // Directions: 0 = North (-1, 0), 1 = East (0, +1), 2 = South (+1, 0), 3 = West (0, -1)
  static const List<(int, int)> dirs = [
    (-1, 0),
    (0, 1),
    (1, 0),
    (0, -1),
  ];

  static const List<RailroadRouteTemplate> routeTemplates = [
    RailroadRouteTemplate(
      id: 'h_straight',
      name: '公路直道',
      emoji: '🛣️',
      baseEdges: [1, 0, 1, 0],
    ),
    RailroadRouteTemplate(
      id: 'h_curve',
      name: '公路弯道',
      emoji: '🛣️',
      baseEdges: [1, 1, 0, 0],
    ),
    RailroadRouteTemplate(
      id: 'r_straight',
      name: '铁路直道',
      emoji: '🛤️',
      baseEdges: [2, 0, 2, 0],
    ),
    RailroadRouteTemplate(
      id: 'r_curve',
      name: '铁路弯道',
      emoji: '🛤️',
      baseEdges: [2, 2, 0, 0],
    ),
    RailroadRouteTemplate(
      id: 'overpass',
      name: '立交天桥',
      emoji: '🌉',
      baseEdges: [1, 2, 1, 2],
      isOverpass: true,
    ),
    RailroadRouteTemplate(
      id: 'station',
      name: '换乘车站',
      emoji: '🚉',
      baseEdges: [1, 0, 2, 0],
      isStation: true,
    ),
  ];

  static const List<RailroadRouteTemplate> specialTemplates = [
    RailroadRouteTemplate(
      id: 'spec_h_cross',
      name: '公路十字',
      emoji: '🛣️',
      baseEdges: [1, 1, 1, 1],
      isSpecial: true,
    ),
    RailroadRouteTemplate(
      id: 'spec_r_cross',
      name: '铁路十字',
      emoji: '🛤️',
      baseEdges: [2, 2, 2, 2],
      isSpecial: true,
    ),
    RailroadRouteTemplate(
      id: 'spec_station_cross',
      name: '综合四向站',
      emoji: '🚉',
      baseEdges: [1, 2, 1, 2],
      isStation: true,
      isSpecial: true,
    ),
    RailroadRouteTemplate(
      id: 'spec_h3_r1',
      name: '三公一铁站',
      emoji: '🚉',
      baseEdges: [1, 1, 2, 1],
      isStation: true,
      isSpecial: true,
    ),
    RailroadRouteTemplate(
      id: 'spec_r3_h1',
      name: '三铁一公站',
      emoji: '🚉',
      baseEdges: [2, 2, 1, 2],
      isStation: true,
      isSpecial: true,
    ),
    RailroadRouteTemplate(
      id: 'spec_station_t',
      name: '换乘丁字站',
      emoji: '🚉',
      baseEdges: [1, 2, 1, 0],
      isStation: true,
      isSpecial: true,
    ),
  ];

  /// Returns the border Exit type (`0 = None`, `1 = Highway 🛣️`, `2 = Railway 🛤️`)
  /// at cell `(r, c)` facing outward direction `dir`.
  static int exitEdgeType(int r, int c, int dir) {
    if (dir == 0 && r == 0) {
      if (c == 1 || c == 5) return 1;
      if (c == 3) return 2;
    }
    if (dir == 2 && r == size - 1) {
      if (c == 1 || c == 5) return 1;
      if (c == 3) return 2;
    }
    if (dir == 3 && c == 0) {
      if (r == 1 || r == 5) return 2;
      if (r == 3) return 1;
    }
    if (dir == 1 && c == size - 1) {
      if (r == 1 || r == 5) return 2;
      if (r == 3) return 1;
    }
    return 0;
  }

  static bool isCenterCell(int r, int c) => r >= 2 && r <= 4 && c >= 2 && c <= 4;

  late final int maxRounds;
  late List<RailroadRouteTemplate> currentDice;
  late List<List<bool>> diceUsed; // [seat][0..3]
  late List<List<bool>> specialsUsed; // [seat][0..5]
  late List<bool> specialUsedThisRound;
  late List<int> specialsCount;
  late List<bool> turnFinished;
  late List<List<List<RailroadPlacedTile?>>> grid;
  late List<int> score;

  int round = 1;
  int turn = 0;
  bool over = false;
  String lastAction = '铁道涂鸦规划开启，请将本轮路线骰画入 7×7 交通网格';

  RailroadInkGame(super.setup) : maxRounds = setup.opt<int>('rounds', 7);

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(score) : null;

  void _rollRoundDice() {
    currentDice = [
      for (var i = 0; i < 4; i++)
        routeTemplates[rng.nextInt(routeTemplates.length)],
    ];
    for (var s = 0; s < players; s++) {
      diceUsed[s] = List.filled(4, false);
      specialUsedThisRound[s] = false;
      turnFinished[s] = false;
    }
  }

  @override
  void start() {
    grid = List.generate(
      players,
      (_) => List.generate(
        size,
        (_) => List.filled(size, null),
      ),
    );
    diceUsed = List.generate(players, (_) => List.filled(4, false));
    specialsUsed = List.generate(players, (_) => List.filled(6, false));
    specialUsedThisRound = List.filled(players, false);
    specialsCount = List.filled(players, 0);
    turnFinished = List.filled(players, false);
    score = List.filled(players, 0);

    round = 1;
    turn = 0;
    over = false;
    _rollRoundDice();
    lastAction =
        '第 1 轮投出路线骰: ${currentDice.map((d) => "${d.emoji}${d.name}").join("、")}';
  }

  /// Validates whether placing a tile with rotated `edges` `[N, E, S, W]` at `(r, c)`
  /// on `seat`'s board is legal:
  /// 1. Cell `(r, c)` is in bounds and empty.
  /// 2. No active edge conflicts with a mismatched Border Exit or adjacent tile's opposing edge.
  /// 3. At least one active edge connects to a matching Border Exit or an adjacent tile's matching edge.
  bool canPlaceEdges(int seat, int r, int c, List<int> edges) {
    if (r < 0 || r >= size || c < 0 || c >= size) return false;
    if (grid[seat][r][c] != null) return false;

    var connects = 0;
    for (var d = 0; d < 4; d++) {
      final myEdge = edges[d];
      final ex = exitEdgeType(r, c, d);
      if (ex > 0 && myEdge > 0) {
        if (myEdge != ex) return false; // Mismatched exit type!
        connects++;
      }

      final nr = r + dirs[d].$1;
      final nc = c + dirs[d].$2;
      if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
        final nb = grid[seat][nr][nc];
        if (nb != null) {
          final nbEdge = nb.edges[(d + 2) % 4];
          if (myEdge > 0 && nbEdge > 0) {
            if (myEdge != nbEdge) return false; // Mismatched track type!
            connects++;
          }
        }
      }
    }
    return connects > 0;
  }

  bool canPlaceTemplate(
      int seat, RailroadRouteTemplate tpl, int r, int c, int rot) {
    return canPlaceEdges(seat, r, c, tpl.rotatedEdges(rot));
  }

  bool _hasAnyRemainingDiePlacement(int seat) {
    for (var i = 0; i < currentDice.length; i++) {
      if (diceUsed[seat][i]) continue;
      final tpl = currentDice[i];
      for (var r = 0; r < size; r++) {
        for (var c = 0; c < size; c++) {
          if (grid[seat][r][c] != null) continue;
          for (var rot = 0; rot < 4; rot++) {
            if (canPlaceTemplate(seat, tpl, r, c, rot)) return true;
          }
        }
      }
    }
    return false;
  }

  Map<String, int> calcScoreBreakdown(int seat) {
    final g = grid[seat];

    // 1. Connected Exits Network VP (`exitVp`)
    // Node ID = (r * size + c) * 4 + d for every cell edge with edges[d] > 0.
    final adj = <int, List<int>>{};
    final exitNodes = <int>{};

    int nodeId(int r, int c, int d) => (r * size + c) * 4 + d;

    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final tile = g[r][c];
        if (tile == null) continue;

        for (var d = 0; d < 4; d++) {
          if (tile.edges[d] <= 0) continue;
          final u = nodeId(r, c, d);
          adj.putIfAbsent(u, () => <int>[]);
          if (exitEdgeType(r, c, d) == tile.edges[d]) {
            exitNodes.add(u);
          }
          // Connect across cell border to neighbor if matching
          final nr = r + dirs[d].$1;
          final nc = c + dirs[d].$2;
          if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
            final nb = g[nr][nc];
            final oppD = (d + 2) % 4;
            if (nb != null && nb.edges[oppD] == tile.edges[d]) {
              adj[u]!.add(nodeId(nr, nc, oppD));
            }
          }
        }

        // Internal cell connections:
        if (tile.isOverpass) {
          // Overpass bridge: N(0)<->S(2) and E(1)<->W(3) do NOT connect to each other
          if (tile.edges[0] > 0 && tile.edges[2] > 0) {
            adj[nodeId(r, c, 0)]!.add(nodeId(r, c, 2));
            adj[nodeId(r, c, 2)]!.add(nodeId(r, c, 0));
          }
          if (tile.edges[1] > 0 && tile.edges[3] > 0) {
            adj[nodeId(r, c, 1)]!.add(nodeId(r, c, 3));
            adj[nodeId(r, c, 3)]!.add(nodeId(r, c, 1));
          }
        } else {
          final activeDirs = [
            for (var d = 0; d < 4; d++)
              if (tile.edges[d] > 0) d,
          ];
          for (var i = 0; i < activeDirs.length; i++) {
            for (var j = i + 1; j < activeDirs.length; j++) {
              final u = nodeId(r, c, activeDirs[i]);
              final v = nodeId(r, c, activeDirs[j]);
              adj[u]!.add(v);
              adj[v]!.add(u);
            }
          }
        }
      }
    }

    var exitVp = 0;
    final visited = <int>{};
    for (final startNode in adj.keys) {
      if (!visited.add(startNode)) continue;
      final q = Queue<int>()..add(startNode);
      var exitsInComp = 0;
      while (q.isNotEmpty) {
        final cur = q.removeFirst();
        if (exitNodes.contains(cur)) exitsInComp++;
        for (final nxt in adj[cur] ?? const <int>[]) {
          if (visited.add(nxt)) q.add(nxt);
        }
      }
      if (exitsInComp >= 2) {
        exitVp += (exitsInComp - 1) * 4;
      }
    }

    // 2. Longest Highway (trackType = 1) & Longest Railway (trackType = 2)
    final longestHighwayVp = _calcLongestTrack(g, 1);
    final longestRailwayVp = _calcLongestTrack(g, 2);

    // 3. Central 3x3 Squares (+1 VP each) & Dead-End Errors (-1 VP each)
    var centerVp = 0;
    var errors = 0;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final tile = g[r][c];
        if (tile == null) continue;
        if (isCenterCell(r, c)) centerVp++;
        for (var d = 0; d < 4; d++) {
          if (tile.edges[d] <= 0) continue;
          final nr = r + dirs[d].$1;
          final nc = c + dirs[d].$2;
          // Only internal board edges count as errors if unconnected
          if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
            final nb = g[nr][nc];
            if (nb == null || nb.edges[(d + 2) % 4] != tile.edges[d]) {
              errors++;
            }
          }
        }
      }
    }

    final total =
        exitVp + longestHighwayVp + longestRailwayVp + centerVp - errors;
    return {
      'exitVp': exitVp,
      'longestHighwayVp': longestHighwayVp,
      'longestRailwayVp': longestRailwayVp,
      'centerVp': centerVp,
      'errors': errors,
      'total': total,
    };
  }

  int _calcLongestTrack(List<List<RailroadPlacedTile?>> g, int trackType) {
    final neighbors = <int, List<int>>{};
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final tile = g[r][c];
        if (tile == null) continue;
        if (!tile.edges.contains(trackType)) continue;
        final u = r * size + c;
        neighbors.putIfAbsent(u, () => <int>[]);
        for (var d = 0; d < 4; d++) {
          if (tile.edges[d] != trackType) continue;
          final nr = r + dirs[d].$1;
          final nc = c + dirs[d].$2;
          if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
            final nb = g[nr][nc];
            if (nb != null && nb.edges[(d + 2) % 4] == trackType) {
              neighbors[u]!.add(nr * size + nc);
            }
          }
        }
      }
    }
    if (neighbors.isEmpty) return 0;

    var bestLen = 1;
    final vis = <int>{};

    void dfs(int u, int len) {
      if (len > bestLen) bestLen = len;
      for (final v in neighbors[u] ?? const <int>[]) {
        if (vis.add(v)) {
          dfs(v, len + 1);
          vis.remove(v);
        }
      }
    }

    for (final start in neighbors.keys) {
      vis
        ..clear()
        ..add(start);
      dfs(start, 1);
    }
    return bestLen;
  }

  int calcScore(int seat) => calcScoreBreakdown(seat)['total']!;

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);
    switch (type) {
      case 'place_route':
        final dieIdx = asInt(action['dieIdx'], -1);
        if (dieIdx < 0 || dieIdx >= currentDice.length) {
          throw GameError('无效的路线骰编号: $dieIdx');
        }
        if (diceUsed[seat][dieIdx]) {
          throw GameError('该路线骰本轮已经使用过了');
        }
        final r = asInt(action['r'], -1);
        final c = asInt(action['c'], -1);
        final rot = ((asInt(action['rot'], 0) % 4) + 4) % 4;
        final tpl = currentDice[dieIdx];
        final edges = tpl.rotatedEdges(rot);

        if (!canPlaceEdges(seat, r, c, edges)) {
          throw GameError(
              '无法在 ($r,$c) 放置 ${tpl.name}：必须连接已有路线或边界出口，且公路/铁路不可直接错接');
        }

        diceUsed[seat][dieIdx] = true;
        grid[seat][r][c] = RailroadPlacedTile(
          templateId: tpl.id,
          name: tpl.name,
          emoji: tpl.emoji,
          rot: rot,
          edges: edges,
          isOverpass: tpl.isOverpass,
          isStation: tpl.isStation,
        );
        score[seat] = calcScore(seat);
        lastAction =
            '${name(seat)} 在 ($r,$c) 绘入 ${tpl.emoji}${tpl.name} (旋转${rot * 90}°)';
        host.log(lastAction);

        if (!_hasAnyRemainingDiePlacement(seat)) {
          _finishPlayerTurn(seat);
        }

      case 'place_special':
        if (specialUsedThisRound[seat]) {
          throw GameError('本轮已使用过 1 块特殊枢纽，每轮最多使用 1 块');
        }
        if (specialsCount[seat] >= maxSpecialsPerGame) {
          throw GameError('整局游戏最多使用 $maxSpecialsPerGame 块特殊枢纽');
        }
        final sIdx = asInt(action['specialIdx'], -1);
        if (sIdx < 0 || sIdx >= specialTemplates.length) {
          throw GameError('无效的特殊枢纽编号: $sIdx');
        }
        if (specialsUsed[seat][sIdx]) {
          throw GameError('该特殊枢纽本局已经使用过了');
        }
        final r = asInt(action['r'], -1);
        final c = asInt(action['c'], -1);
        final rot = ((asInt(action['rot'], 0) % 4) + 4) % 4;
        final tpl = specialTemplates[sIdx];
        final edges = tpl.rotatedEdges(rot);

        if (!canPlaceEdges(seat, r, c, edges)) {
          throw GameError('无法在 ($r,$c) 放置特殊枢纽 ${tpl.name}：必须连接已有路线或出口且不能错接');
        }

        specialsUsed[seat][sIdx] = true;
        specialUsedThisRound[seat] = true;
        specialsCount[seat]++;
        grid[seat][r][c] = RailroadPlacedTile(
          templateId: tpl.id,
          name: tpl.name,
          emoji: tpl.emoji,
          rot: rot,
          edges: edges,
          isStation: tpl.isStation,
          isSpecial: true,
        );
        score[seat] = calcScore(seat);
        lastAction =
            '${name(seat)} 启用特殊枢纽 ${tpl.emoji}${tpl.name} 绘入 ($r,$c)';
        host.log(lastAction);

        if (!_hasAnyRemainingDiePlacement(seat)) {
          _finishPlayerTurn(seat);
        }

      case 'end_turn':
        _finishPlayerTurn(seat);

      default:
        throw GameError('未知操作: $type');
    }
  }

  void _finishPlayerTurn(int seat) {
    turnFinished[seat] = true;
    score[seat] = calcScore(seat);
    for (var offset = 1; offset <= players; offset++) {
      final nextSeat = (turn + offset) % players;
      if (!turnFinished[nextSeat]) {
        turn = nextSeat;
        return;
      }
    }

    if (round >= maxRounds) {
      over = true;
      for (var s = 0; s < players; s++) {
        score[s] = calcScore(s);
      }
      lastAction = '铁道涂鸦 $maxRounds 轮全部完成！终局路网计分结束';
      host.log(lastAction);
      return;
    }

    round++;
    turn = (round - 1) % players;
    _rollRoundDice();
    lastAction =
        '第 $round 轮开始，投出路线骰: ${currentDice.map((d) => "${d.emoji}${d.name}").join("、")}';
    host.log(lastAction);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    // Maybe place a Special Intersection if we haven't used one this round and have < 3 used
    if (!specialUsedThisRound[seat] &&
        specialsCount[seat] < maxSpecialsPerGame &&
        round <= 3) {
      for (var sIdx = 0; sIdx < specialTemplates.length; sIdx++) {
        if (specialsUsed[seat][sIdx]) continue;
        final tpl = specialTemplates[sIdx];
        for (var r = 1; r < size - 1; r++) {
          for (var c = 1; c < size - 1; c++) {
            for (var rot = 0; rot < 4; rot++) {
              if (canPlaceTemplate(seat, tpl, r, c, rot)) {
                return {
                  'type': 'place_special',
                  'specialIdx': sIdx,
                  'r': r,
                  'c': c,
                  'rot': rot,
                };
              }
            }
          }
        }
      }
    }

    // Place next available Route Die at the highest-scoring legal cell/rotation
    int bestDieIdx = -1;
    int bestR = -1;
    int bestC = -1;
    int bestRot = 0;
    int bestVal = -999999;

    for (var dIdx = 0; dIdx < currentDice.length; dIdx++) {
      if (diceUsed[seat][dIdx]) continue;
      final tpl = currentDice[dIdx];
      for (var r = 0; r < size; r++) {
        for (var c = 0; c < size; c++) {
          if (grid[seat][r][c] != null) continue;
          for (var rot = 0; rot < 4; rot++) {
            final edges = tpl.rotatedEdges(rot);
            if (!canPlaceEdges(seat, r, c, edges)) continue;

            // Evaluate placement quality
            var val = isCenterCell(r, c) ? 6 : 0;
            for (var d = 0; d < 4; d++) {
              final e = edges[d];
              if (e <= 0) continue;
              if (exitEdgeType(r, c, d) == e) val += 10;
              final nr = r + dirs[d].$1;
              final nc = c + dirs[d].$2;
              if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
                final nb = grid[seat][nr][nc];
                if (nb != null && nb.edges[(d + 2) % 4] == e) {
                  val += 8;
                } else if (nb != null && nb.edges[(d + 2) % 4] == 0) {
                  val -= 5; // Dead-end into existing empty side
                }
              }
            }
            if (val > bestVal) {
              bestVal = val;
              bestDieIdx = dIdx;
              bestR = r;
              bestC = c;
              bestRot = rot;
            }
          }
        }
      }
      if (bestDieIdx >= 0) break;
    }

    if (bestDieIdx >= 0) {
      return {
        'type': 'place_route',
        'dieIdx': bestDieIdx,
        'r': bestR,
        'c': bestC,
        'rot': bestRot,
      };
    }

    return {'type': 'end_turn'};
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'round': round,
      'maxRounds': maxRounds,
      'turn': turn,
      'over': over,
      'lastAction': lastAction,
      'currentDice': [for (final d in currentDice) d.toJson()],
      'specialTemplates': [for (final s in specialTemplates) s.toJson()],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'score': score[s],
            'breakdown': calcScoreBreakdown(s),
            'diceUsed': List<bool>.of(diceUsed[s]),
            'specialsUsed': List<bool>.of(specialsUsed[s]),
            'specialUsedThisRound': specialUsedThisRound[s],
            'specialsCount': specialsCount[s],
            'turnFinished': turnFinished[s],
            'grid': [
              for (var r = 0; r < size; r++)
                [
                  for (var c = 0; c < size; c++) grid[s][r][c]?.toJson(),
                ],
            ],
          },
      ],
    };
  }
}
