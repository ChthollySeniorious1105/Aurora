import 'dart:collection';

import '../../src/engine.dart';

class TransAmericaGame extends GameEngine {
  TransAmericaGame(super.setup);

  static const int rows = 8;
  static const int cols = 10;

  static const List<String> regionNames = [
    '🔴 西岸',
    '🔵 中西',
    '🟢 北境',
    '🟡 南方',
    '🟠 东岸',
  ];

  /// 15 Major Cities across 5 Colored Regions (3 cities per region 0..4).
  static const List<Map<String, Object>> cities = [
    // Region 0: 🔴 西岸 (0..2)
    {'id': 0, 'name': '西雅图', 'region': 0, 'r': 1, 'c': 1},
    {'id': 1, 'name': '旧金山', 'region': 0, 'r': 4, 'c': 0},
    {'id': 2, 'name': '洛杉矶', 'region': 0, 'r': 6, 'c': 1},
    // Region 1: 🔵 中西 (3..5)
    {'id': 3, 'name': '盐湖城', 'region': 1, 'r': 2, 'c': 2},
    {'id': 4, 'name': '丹佛', 'region': 1, 'r': 3, 'c': 3},
    {'id': 5, 'name': '凤凰城', 'region': 1, 'r': 5, 'c': 2},
    // Region 2: 🟢 北境 (6..8)
    {'id': 6, 'name': '明尼阿波利斯', 'region': 2, 'r': 1, 'c': 4},
    {'id': 7, 'name': '芝加哥', 'region': 2, 'r': 2, 'c': 6},
    {'id': 8, 'name': '底特律', 'region': 2, 'r': 1, 'c': 7},
    // Region 3: 🟡 南方 (9..11)
    {'id': 9, 'name': '达拉斯', 'region': 3, 'r': 5, 'c': 4},
    {'id': 10, 'name': '新奥尔良', 'region': 3, 'r': 6, 'c': 6},
    {'id': 11, 'name': '亚特兰大', 'region': 3, 'r': 5, 'c': 7},
    // Region 4: 🟠 东岸 (12..14)
    {'id': 12, 'name': '纽约', 'region': 4, 'r': 2, 'c': 9},
    {'id': 13, 'name': '华盛顿', 'region': 4, 'r': 4, 'c': 8},
    {'id': 14, 'name': '迈阿密', 'region': 4, 'r': 7, 'c': 8},
  ];

  int totalRounds = 2;
  int round = 1;
  int turn = 0;
  String phase = 'hub'; // 'hub' | 'build' | 'over'

  /// 8x10 terrain cost grid: 1 = Plain (cost 1), 2 = Mountain/River (cost 2).
  late List<List<int>> terrain;

  /// 8x10 rail presence grid: true if a rail has been built on cell (r, c).
  late List<List<bool>> rails;

  /// Start Hub coordinates per player: [r, c], or empty list if not yet placed.
  late List<List<int>> hub;

  /// 5 Secret Target City IDs (one per region 0..4) per player.
  late List<List<int>> targetCities;

  /// Cumulative scores per player (starts at 0; each round losers lose missingSteps).
  late List<int> scores;

  /// Summary of the most recently completed round.
  Map<String, dynamic>? lastRoundSummary;

  String lastEvent = '横贯美利坚开启！请每位铁路大亨在北美版图上放置起始枢纽站 (Start Hub)！';

  @override
  bool get isOver => phase == 'over';

  @override
  bool get canResign => true;

  @override
  List<int>? get placings {
    if (!isOver) return null;
    return rankByScore(scores);
  }

  @override
  List<int> get waitingFor {
    if (isOver) return const [];
    return [turn];
  }

  @override
  void start() {
    final mode = setup.opt<String>('mode', 'standard');
    totalRounds = mode == 'fast' ? 1 : 2;
    round = 1;
    scores = List<int>.filled(players, 0);
    lastRoundSummary = null;
    _initRound(startSeat: 0);
    host.log('【横贯美利坚】北美铁路网建设开启！连接你的 5 座秘密目标城市，一旦两家铁路相连即刻共享全网！');
  }

  void _initRound({required int startSeat}) {
    phase = 'hub';
    turn = startSeat % players;

    // Initialize 8x10 terrain grid: Rocky Mountains & Mississippi River cost 2, Plains cost 1
    terrain = [
      for (var r = 0; r < rows; r++)
        [
          for (var c = 0; c < cols; c++)
            ((c == 2 && r >= 1 && r <= 4) || (c == 5 && r >= 2 && r <= 5) || (r == 3 && c == 7))
                ? 2
                : 1,
        ],
    ];
    // Ensure city cells themselves have cost 1 so connecting onto a city is always smooth
    for (final city in cities) {
      final cr = city['r'] as int;
      final cc = city['c'] as int;
      terrain[cr][cc] = 1;
    }

    rails = [
      for (var r = 0; r < rows; r++) List<bool>.filled(cols, false),
    ];

    hub = [
      for (var s = 0; s < players; s++) <int>[],
    ];

    // Deal 5 Secret City Cards (1 of each of the 5 regions 0..4) to each player
    targetCities = [
      for (var s = 0; s < players; s++) <int>[],
    ];
    for (var reg = 0; reg < 5; reg++) {
      final regCityIds = <int>[reg * 3, reg * 3 + 1, reg * 3 + 2];
      for (var s = 0; s < players; s++) {
        final pick = regCityIds[rng.nextInt(regCityIds.length)];
        targetCities[s].add(pick);
      }
    }

    lastEvent = '第 $round/$totalRounds 局开始：请 ${name(turn)} 选择任意网格放置起始枢纽 (Start Hub)！';
  }

  /// Return city ID at (r, c), or -1 if none.
  int cityAt(int r, int c) {
    for (final city in cities) {
      if (city['r'] == r && city['c'] == c) {
        return city['id'] as int;
      }
    }
    return -1;
  }

  /// Return all (r, c) cells encoded as `r * cols + c` in [seat]'s connected rail network.
  /// Because rails are shared on `rails[r][c]`, whenever two players' rail networks are
  /// orthogonally connected, BFS traverses the entire merged network for both players!
  Set<int> connectedCells(int seat) {
    if (seat < 0 || seat >= players || hub[seat].length < 2) return const <int>{};
    final hr = hub[seat][0];
    final hc = hub[seat][1];
    if (hr < 0 || hr >= rows || hc < 0 || hc >= cols || !rails[hr][hc]) {
      return const <int>{};
    }

    final visited = <int>{hr * cols + hc};
    final q = Queue<(int, int)>()..add((hr, hc));
    const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];

    while (q.isNotEmpty) {
      final (r, c) = q.removeFirst();
      for (final (dr, dc) in dirs) {
        final nr = r + dr;
        final nc = c + dc;
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && rails[nr][nc]) {
          final code = nr * cols + nc;
          if (visited.add(code)) {
            q.add((nr, nc));
          }
        }
      }
    }
    return visited;
  }

  /// Return which of [seat]'s 5 targetCities are currently connected to [seat]'s rail network.
  List<int> connectedTargetCities(int seat) {
    final net = connectedCells(seat);
    if (net.isEmpty) return const <int>[];
    final out = <int>[];
    for (final cid in targetCities[seat]) {
      final city = cities[cid];
      final cr = city['r'] as int;
      final cc = city['c'] as int;
      if (net.contains(cr * cols + cc)) {
        out.add(cid);
      }
    }
    return out;
  }

  /// Compute the number of missing steps from [seat]'s connected rail network to all
  /// unreached target cities in `targetCities[seat]`.
  int computeMissingSteps(int seat) {
    final net = connectedCells(seat);
    if (net.isEmpty) return 15;
    var missing = 0;
    for (final cid in targetCities[seat]) {
      final city = cities[cid];
      final cr = city['r'] as int;
      final cc = city['c'] as int;
      if (net.contains(cr * cols + cc)) continue;
      // Minimum Manhattan distance from (cr, cc) to any cell in seat's connected network
      var bestDist = 999;
      for (final code in net) {
        final nr = code ~/ cols;
        final nc = code % cols;
        final d = (cr - nr).abs() + (cc - nc).abs();
        if (d < bestDist) bestDist = d;
      }
      missing += bestDist;
    }
    return missing;
  }

  /// Return all empty cells `(r, c)` that are orthogonally adjacent to [seat]'s connected network.
  List<List<int>> buildableAdjacentCells(int seat) {
    final net = connectedCells(seat);
    if (net.isEmpty) return const <List<int>>[];
    const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];
    final seen = <int>{};
    final out = <List<int>>[];
    for (final code in net) {
      final r = code ~/ cols;
      final c = code % cols;
      for (final (dr, dc) in dirs) {
        final nr = r + dr;
        final nc = c + dc;
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && !rails[nr][nc]) {
          final nCode = nr * cols + nc;
          if (seen.add(nCode)) {
            out.add(<int>[nr, nc]);
          }
        }
      }
    }
    return out;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    switch (type) {
      case 'place_hub':
        _handlePlaceHub(seat, action);
        break;
      case 'build_rail':
        _handleBuildRail(seat, action);
        break;
      default:
        throw GameError('未知操作：$type');
    }
  }

  void _handlePlaceHub(int seat, Map<String, dynamic> action) {
    if (phase != 'hub') throw GameError('当前不是放置起始枢纽阶段');
    if (hub[seat].isNotEmpty) throw GameError('你已经放置过起始枢纽了');

    final r = asInt(action['r'], -1);
    final c = asInt(action['c'], -1);
    if (r < 0 || r >= rows || c < 0 || c >= cols) {
      throw GameError('枢纽坐标超出北美版图范围');
    }

    hub[seat] = <int>[r, c];
    rails[r][c] = true;

    final cid = cityAt(r, c);
    final cityNote = cid >= 0 ? '（位于【${cities[cid]['name']}】）' : '';

    if (_checkInstantRoundEnd(seat)) {
      return;
    }

    final allHubsPlaced = hub.every((h) => h.length == 2);
    if (allHubsPlaced) {
      phase = 'build';
      turn = (turn + 1) % players;
      lastEvent = '🚉 ${name(seat)} 在 ($r, $c)$cityNote 放置枢纽！全员枢纽就绪，进入铁路铺设阶段！';
    } else {
      for (var i = 1; i <= players; i++) {
        final next = (turn + i) % players;
        if (hub[next].isEmpty) {
          turn = next;
          break;
        }
      }
      lastEvent = '🚉 ${name(seat)} 在 ($r, $c)$cityNote 放置了起始枢纽站。';
    }
    host.log(lastEvent);
  }

  void _handleBuildRail(int seat, Map<String, dynamic> action) {
    if (phase != 'build') throw GameError('请先完成所有起始枢纽的放置');

    final rawCells = action['cells'];
    if (rawCells is! List || rawCells.isEmpty || rawCells.length > 2) {
      throw GameError('每回合必须铺设 1 或 2 格相连铁路');
    }

    final parsed = <(int, int)>[];
    for (final item in rawCells) {
      if (item is List && item.length >= 2) {
        final r = asInt(item[0], -1);
        final c = asInt(item[1], -1);
        if (r < 0 || r >= rows || c < 0 || c >= cols) {
          throw GameError('铁路坐标 ($r, $c) 超出棋盘范围');
        }
        if (rails[r][c]) {
          throw GameError('坐标 ($r, $c) 已经铺设过铁路了');
        }
        if (parsed.contains((r, c))) {
          throw GameError('不能重复铺设同一格 ($r, $c)');
        }
        parsed.add((r, c));
      } else {
        throw GameError('铁路坐标格式不正确');
      }
    }

    var totalCost = 0;
    for (final (r, c) in parsed) {
      totalCost += terrain[r][c];
    }
    if (totalCost > 2) {
      throw GameError('本回合铺设消耗 ($totalCost 点) 超过上限 2 点（山脉/河流需消耗 2 点）');
    }

    // Validate step-by-step orthogonal adjacency to seat's connected rail network
    final applied = <(int, int)>[];
    for (final (r, c) in parsed) {
      final net = connectedCells(seat);
      const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];
      var adjacent = false;
      for (final (dr, dc) in dirs) {
        final nr = r + dr;
        final nc = c + dc;
        if (net.contains(nr * cols + nc)) {
          adjacent = true;
          break;
        }
      }
      if (!adjacent) {
        // Rollback any earlier cell in this turn
        for (final (ar, ac) in applied) {
          rails[ar][ac] = false;
        }
        throw GameError('新铺设的铁路 ($r, $c) 必须与你当前的铁路网络正交相邻');
      }
      rails[r][c] = true;
      applied.add((r, c));
    }

    final coordStr = parsed.map((p) => '(${p.$1},${p.$2})').join('、');

    // Check if any player has connected all 5 of their secret target cities!
    if (_checkInstantRoundEnd(seat)) {
      return;
    }

    // Advance turn to next player who can still build (or settle if grid is completely full)
    turn = (turn + 1) % players;
    if (buildableAdjacentCells(turn).isEmpty) {
      _settleRound(seat);
      return;
    }

    lastEvent =
        '🛤️ ${name(seat)} 消耗 $totalCost 点铁轨铺设了 $coordStr（已连通 ${connectedTargetCities(seat).length}/5 座目标城市）！';
    host.log(lastEvent);
  }

  /// Check if ANY player has connected all 5 of their `targetCities` (Instant Round End!).
  bool _checkInstantRoundEnd(int activeSeat) {
    final winners = <int>[];
    for (var s = 0; s < players; s++) {
      if (hub[s].length == 2 && connectedTargetCities(s).length >= 5) {
        winners.add(s);
      }
    }
    if (winners.isEmpty) return false;
    _settleRound(winners.first, winners: winners);
    return true;
  }

  void _settleRound(int triggerSeat, {List<int>? winners}) {
    final roundMissing = List<int>.filled(players, 0);
    final roundDelta = List<int>.filled(players, 0);
    final details = <String>[];

    for (var s = 0; s < players; s++) {
      final m = computeMissingSteps(s);
      roundMissing[s] = m;
      roundDelta[s] = -m;
      scores[s] -= m;
      details.add('${name(s)}: ${m == 0 ? "全连通(0扣分)" : "-$m分"}');
    }

    lastRoundSummary = {
      'round': round,
      'winnerSeats': winners ?? <int>[triggerSeat],
      'missingSteps': roundMissing,
      'deltas': roundDelta,
    };

    if (round < totalRounds) {
      final finishedRound = round;
      round++;
      _initRound(startSeat: (triggerSeat + 1) % players);
      lastEvent =
          '🎉 第 $finishedRound 局铁路全线贯通（${name(triggerSeat)} 连齐 5 城）！结算：${details.join("，")}。现开启第 $round/$totalRounds 局！';
      host.log(lastEvent);
    } else {
      phase = 'over';
      var bestSeat = 0;
      for (var s = 1; s < players; s++) {
        if (scores[s] > scores[bestSeat]) bestSeat = s;
      }
      lastEvent =
          '🏆 横贯美利坚圆满竣工！本局结算：${details.join("，")}。${name(bestSeat)} 以总成绩 ${scores[bestSeat]} 分荣膺北美铁路大亨！';
      host.log(lastEvent);
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final validPlayer = seat >= 0 && seat < players;
    final myConnected = validPlayer ? connectedCells(seat).toList() : const <int>[];
    final myBuildOptions =
        (validPlayer && phase == 'build' && seat == turn) ? buildableAdjacentCells(seat) : const <List<int>>[];

    return {
      'round': round,
      'totalRounds': totalRounds,
      'turn': turn,
      'phase': phase,
      'rows': rows,
      'cols': cols,
      'regionNames': regionNames,
      'cities': cities,
      'terrain': [
        for (final row in terrain) List<int>.of(row),
      ],
      'rails': [
        for (final row in rails) List<bool>.of(row),
      ],
      'hub': [
        for (final h in hub) List<int>.of(h),
      ],
      // Strictly hide opponents' targetCities until game over!
      'myTargets': validPlayer ? List<int>.of(targetCities[seat]) : null,
      'revealedTargets': phase == 'over'
          ? [for (final t in targetCities) List<int>.of(t)]
          : null,
      'connectedCounts': [
        for (var s = 0; s < players; s++) connectedTargetCities(s).length,
      ],
      'myConnectedCells': myConnected,
      'myConnectedCities': validPlayer ? connectedTargetCities(seat) : const <int>[],
      'buildableCells': myBuildOptions,
      'scores': List<int>.of(scores),
      'lastRoundSummary': lastRoundSummary,
      'lastEvent': lastEvent,
      'canAct': !isOver && seat == turn,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || seat != turn) return null;

    if (phase == 'hub') {
      // Pick the central target city (e.g. Midwest or North) as the Start Hub
      final myTargets = targetCities[seat];
      final targetCid = myTargets[1]; // Region 1 (Midwest)
      final city = cities[targetCid];
      return {
        'type': 'place_hub',
        'r': city['r'] as int,
        'c': city['c'] as int,
      };
    }

    if (phase == 'build') {
      final adj = buildableAdjacentCells(seat);
      if (adj.isEmpty) return null;

      // Find the adjacent cell that reduces missing steps to unreached target cities the most
      final net = connectedCells(seat);
      final unreached = <(int, int)>[];
      for (final cid in targetCities[seat]) {
        final cr = cities[cid]['r'] as int;
        final cc = cities[cid]['c'] as int;
        if (!net.contains(cr * cols + cc)) {
          unreached.add((cr, cc));
        }
      }

      List<int> pickBestCell(List<List<int>> candidates) {
        var best = candidates.first;
        var bestDist = 999999;
        for (final cell in candidates) {
          final r = cell[0];
          final c = cell[1];
          var d = 0;
          if (unreached.isNotEmpty) {
            final (tr, tc) = unreached.first;
            d = (r - tr).abs() + (c - tc).abs();
          }
          // Bonus if this cell merges with another existing rail cell!
          const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];
          for (final (dr, dc) in dirs) {
            final nr = r + dr;
            final nc = c + dc;
            if (nr >= 0 &&
                nr < rows &&
                nc >= 0 &&
                nc < cols &&
                rails[nr][nc] &&
                !net.contains(nr * cols + nc)) {
              d -= 3;
            }
          }
          if (d < bestDist) {
            bestDist = d;
            best = cell;
          }
        }
        return best;
      }

      final firstCell = pickBestCell(adj);
      final firstCost = terrain[firstCell[0]][firstCell[1]];
      if (firstCost >= 2) {
        return {
          'type': 'build_rail',
          'cells': [firstCell],
        };
      }

      // Check if simply building firstCell already wins the round
      final firstCode = firstCell[0] * cols + firstCell[1];
      if (unreached.length == 1 &&
          unreached.first.$1 == firstCell[0] &&
          unreached.first.$2 == firstCell[1]) {
        return {
          'type': 'build_rail',
          'cells': [firstCell],
        };
      }

      // Try to add a second cost-1 cell adjacent to (network + firstCell)
      final secondCandidates = <List<int>>[];
      final seen = <int>{firstCode};
      for (final c in adj) {
        final code = c[0] * cols + c[1];
        if (seen.add(code) && terrain[c[0]][c[1]] == 1) {
          secondCandidates.add(c);
        }
      }
      const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];
      for (final (dr, dc) in dirs) {
        final nr = firstCell[0] + dr;
        final nc = firstCell[1] + dc;
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && !rails[nr][nc] && terrain[nr][nc] == 1) {
          final code = nr * cols + nc;
          if (seen.add(code)) {
            secondCandidates.add(<int>[nr, nc]);
          }
        }
      }

      if (secondCandidates.isNotEmpty) {
        final secondCell = pickBestCell(secondCandidates);
        return {
          'type': 'build_rail',
          'cells': [firstCell, secondCell],
        };
      }

      return {
        'type': 'build_rail',
        'cells': [firstCell],
      };
    }

    return null;
  }

  @override
  void resign(int seat) {
    if (isOver || seat < 0 || seat >= players) return;
    scores[seat] = -100;
    phase = 'over';
    lastEvent = '${name(seat)} 放弃铁路竞标，游戏结束！';
    host.log(lastEvent);
  }
}
