import 'dart:math';

import '../../src/engine.dart';

const List<int> imhotepPyramidValues = [2, 1, 3, 2, 4, 3, 2, 1, 3, 2, 3, 4, 2, 4];

const List<String> imhotepDestNames = ['集市', '金字塔', '神庙', '墓室', '方尖碑'];

const Map<String, String> imhotepMarketNames = {
  'statue': '雕像 (+2分)',
  'sled3': '采石车 (+3石料)',
  'pyramid': '金字塔营造 (+1石入塔)',
  'obelisk': '方尖碑加高 (+1石入碑)',
};

class ImhotepShip {
  final int id;
  final int size;
  final int minRequired;
  final List<int> slots; // -1 = empty, 0..players-1 = seat
  bool sailed;
  int dest; // -1 if unsailed, 0..4 if sailed

  ImhotepShip({
    required this.id,
    required this.size,
    required this.minRequired,
    List<int>? slots,
    this.sailed = false,
    this.dest = -1,
  }) : slots = slots ?? List<int>.filled(size, -1);

  int get loadedCount => slots.where((s) => s >= 0).length;
  bool get canSail => !sailed && loadedCount >= minRequired;
  bool get hasOpenSlot => !sailed && slots.any((s) => s == -1);

  Map<String, dynamic> toJson() => {
        'id': id,
        'size': size,
        'minRequired': minRequired,
        'slots': List<int>.of(slots),
        'loadedCount': loadedCount,
        'sailed': sailed,
        'dest': dest,
        'canSail': canSail,
      };
}

const String imhotepRules = '''
# 埃及建造师 (Imhotep) 规则说明

## 游戏概述
《埃及建造师》是一款经典的古埃及纪念碑建造策略桌游，支持 2~4 名玩家，进行 6 轮（标准）或 4 轮（快速）。
玩家扮演古埃及建筑大师，从采石场开采石料装上木撬，将石料装上不同尺寸的船只，并驾驶船只驶往 5 大建筑工地卸货得分。

## 游戏准备
- 每位玩家拥有一辆**木撬**（容量上限为 **5 块石料**）。起始石料按顺位依次为：1号位 2 块、2号位 3 块、3号位 4 块、4号位 5 块。
- 每轮开始时，生成 4 艘船只（尺寸为 `[2, 3, 3, 4]`，对应的最低起航石料数为 `[1, 2, 2, 3]`），并刷新 5 个目的地的停靠状态（每个目的地每轮最多停靠 1 艘船）。

## 回合行动（三选一）
轮到你的回合时，必须从以下 3 项行动中选择 1 项执行：
1. **采石 (quarry)**：从采石场补充至多 **+3 块石料** 到自己的木撬上（总石料数不超过上限 5）。
2. **装船 (load)**：消耗自己木撬上的 **1 块石料**，放置到任意一艘尚未起航船只的任意空槽位上。
3. **起航 (sail)**：选择一艘尚未起航且已装载石料数 **达到最低起航要求** 的船只，驶向任意一个本轮尚未停靠船只的目的地（0~4），并按船头到船尾的槽位顺序（`0..size-1`）依次卸载石料触发效果！

## 五大建筑工地（目的地 0~4）
- **0 集市 (Market)**：每块卸下的石料为其主人赢得一张集市奖励（雕像 +2分 / 立即补充 +3石料 / 立即向金字塔放1石 / 立即向方尖碑放1石）。
- **1 金字塔 (Pyramid)**：石料按顺序填入金字塔的 14 个槽位，立即获得槽位对应的分数（`[2, 1, 3, 2, 4, 3, 2, 1, 3, 2, 3, 4, 2, 4]`；若填满后继续放入则每块得 +1 分）。
- **2 神庙 (Temple)**：石料按环形顺序依次铺在神庙的 5 个基座上（新石料会覆盖旧石料）。**每轮结束时**，从上方俯瞰可见的 5 个顶层石料各为其主人赢得 **+1 分**。
- **3 墓室 (Burial Chamber)**：石料按列填入 3 行墓室网格。**游戏结束时**，按每位玩家正交相连的同色石料群大小计分：1块=1分、2块=3分、3块=6分、4块=10分、5块及以上=`15 + 2×(n-5)`分。
- **4 方尖碑 (Obelisk)**：石料累加在玩家各自的方尖碑上。**游戏结束时**按高度排名：第1名 +12 分，第2名 +6 分，第3名 +3 分（至少需有1块石料）。

## 轮次与终局
- 当本轮的 **4 艘船全部起航** 后，本轮结束，进行神庙俯瞰计分。
- 全部轮次结束后，结算墓室相连群分与方尖碑排名分，总分最高者获胜！
''';

class Imhotep extends GameEngine {
  Imhotep(super.setup);

  int round = 1;
  int maxRounds = 6;
  int turn = 0;
  bool _over = false;
  String lastAction = '游戏开始';

  final List<ImhotepShip> ships = [];
  final List<int> destShip = List<int>.filled(5, -1); // which ship sailed to dest 0..4 this round
  final List<String> marketCards = [];

  late List<int> sled; // stones on sled (0..5)
  late List<int> vp; // immediate VP (Pyramid + Temple + Market Statues)
  late List<int> statues; // count of statues collected

  final List<int> pyramidStones = []; // owner seats in order
  final List<int> templeTop = List<int>.filled(5, -1); // visible top stone owner at 0..4
  int templeCursor = 0;
  int templeTotalStones = 0;

  final List<int> burialStones = []; // owner seats in order (r = i % 3, c = i ~/ 3)
  late List<int> obelisk; // height per player

  @override
  bool get isOver => _over;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  List<int>? get placings {
    if (!_over) return null;
    return rankByScore([
      for (var s = 0; s < players; s++) totalScore(s) + sled[s] * 0.01,
    ]);
  }

  static int burialGroupPoints(int n) {
    if (n <= 0) return 0;
    if (n == 1) return 1;
    if (n == 2) return 3;
    if (n == 3) return 6;
    if (n == 4) return 10;
    return 15 + 2 * (n - 5);
  }

  static int scoreBurialForSeat(List<int> stones, int seat) {
    final n = stones.length;
    if (n == 0) return 0;
    final visited = List<bool>.filled(n, false);
    var total = 0;

    int indexAt(int r, int c) {
      if (r < 0 || r >= 3 || c < 0) return -1;
      final idx = c * 3 + r;
      return idx < n ? idx : -1;
    }

    for (var i = 0; i < n; i++) {
      if (visited[i] || stones[i] != seat) continue;
      var compSize = 0;
      final q = <int>[i];
      visited[i] = true;
      while (q.isNotEmpty) {
        final cur = q.removeLast();
        compSize++;
        final r = cur % 3;
        final c = cur ~/ 3;
        for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
          final nb = indexAt(r + dr, c + dc);
          if (nb != -1 && !visited[nb] && stones[nb] == seat) {
            visited[nb] = true;
            q.add(nb);
          }
        }
      }
      total += burialGroupPoints(compSize);
    }
    return total;
  }

  static List<int> scoreObelisks(List<int> heights) {
    final pCount = heights.length;
    final out = List<int>.filled(pCount, 0);
    const prizes = [12, 6, 3];
    final ranks = rankByScore(heights);
    for (var s = 0; s < pCount; s++) {
      if (heights[s] <= 0) continue;
      final r = ranks[s]; // 1-based rank
      if (r >= 1 && r <= 3) {
        out[s] = prizes[r - 1];
      }
    }
    return out;
  }

  int burialScore(int seat) => scoreBurialForSeat(burialStones, seat);

  int obeliskScore(int seat) => scoreObelisks(obelisk)[seat];

  int totalScore(int seat) => vp[seat] + burialScore(seat) + obeliskScore(seat);

  @override
  void start() {
    maxRounds = setup.opt<int>('rounds', 6);
    round = 1;
    turn = 0;
    _over = false;

    sled = [for (var s = 0; s < players; s++) min(5, 2 + s)];
    vp = List<int>.filled(players, 0);
    statues = List<int>.filled(players, 0);
    obelisk = List<int>.filled(players, 0);

    pyramidStones.clear();
    for (var i = 0; i < 5; i++) {
      templeTop[i] = -1;
    }
    templeCursor = 0;
    templeTotalStones = 0;
    burialStones.clear();

    _setupRound();
    lastAction = '第 1 轮开始，轮到 ${name(turn)} 行动';
  }

  void _setupRound() {
    ships.clear();
    const sizes = [2, 3, 3, 4];
    const mins = [1, 2, 2, 3];
    for (var i = 0; i < 4; i++) {
      ships.add(ImhotepShip(id: i, size: sizes[i], minRequired: mins[i]));
    }
    for (var d = 0; d < 5; d++) {
      destShip[d] = -1;
    }
    marketCards
      ..clear()
      ..addAll(['statue', 'sled3', 'pyramid', 'obelisk']);
    marketCards.shuffle(rng);
  }

  void _placeInPyramid(int owner) {
    final idx = pyramidStones.length;
    pyramidStones.add(owner);
    final pts = idx < imhotepPyramidValues.length ? imhotepPyramidValues[idx] : 1;
    vp[owner] += pts;
  }

  void _placeInTemple(int owner) {
    templeTop[templeCursor] = owner;
    templeCursor = (templeCursor + 1) % 5;
    templeTotalStones++;
  }

  void _placeInBurial(int owner) {
    burialStones.add(owner);
  }

  void _placeInObelisk(int owner) {
    obelisk[owner]++;
  }

  void _giveMarketCard(int owner) {
    final card = marketCards.isNotEmpty ? marketCards.removeAt(0) : 'statue';
    switch (card) {
      case 'statue':
        statues[owner]++;
        vp[owner] += 2;
        break;
      case 'sled3':
        sled[owner] = min(5, sled[owner] + 3);
        break;
      case 'pyramid':
        _placeInPyramid(owner);
        break;
      case 'obelisk':
        _placeInObelisk(owner);
        break;
    }
  }

  void _scoreEndOfRoundTemple() {
    for (var i = 0; i < 5; i++) {
      final owner = templeTop[i];
      if (owner >= 0 && owner < players) {
        vp[owner] += 1;
      }
    }
  }

  void _advanceTurnOrRound(int actor) {
    if (ships.every((s) => s.sailed)) {
      _scoreEndOfRoundTemple();
      if (round >= maxRounds) {
        _over = true;
        final scores = [for (var s = 0; s < players; s++) totalScore(s)];
        final ranks = placings!;
        final winners = [
          for (var s = 0; s < players; s++)
            if (ranks[s] == 1) '${name(s)}(${scores[s]}分)'
        ];
        lastAction = '第 $round 轮结束，全局终结！获胜：${winners.join("、")}';
        host.log(lastAction);
        return;
      }
      round++;
      _setupRound();
      turn = (actor + 1) % players;
      lastAction = '$lastAction（神庙结算完毕，进入第 $round 轮）';
      host.log('进入第 $round 轮');
      return;
    }
    turn = (actor + 1) % players;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    switch (type) {
      case 'quarry':
        if (sled[seat] >= 5) {
          throw GameError('木撬已满（5块石料），无法继续采石');
        }
        final gained = min(3, 5 - sled[seat]);
        sled[seat] += gained;
        lastAction = '${name(seat)} 采石 +$gained（当前木撬 ${sled[seat]}/5）';
        host.log(lastAction);
        _advanceTurnOrRound(seat);
        break;

      case 'load':
        if (sled[seat] <= 0) {
          throw GameError('木撬上没有石料，请先采石');
        }
        final sIdx = asInt(action['ship'], -1);
        if (sIdx < 0 || sIdx >= ships.length) {
          throw GameError('无效的船只编号');
        }
        final ship = ships[sIdx];
        if (ship.sailed) {
          throw GameError('该船只已经起航');
        }
        final slot = action.containsKey('slot')
            ? asInt(action['slot'], -1)
            : ship.slots.indexWhere((x) => x == -1);
        if (slot < 0 || slot >= ship.size || ship.slots[slot] != -1) {
          throw GameError('该船位无效或已有石料');
        }
        sled[seat]--;
        ship.slots[slot] = seat;
        lastAction = '${name(seat)} 将石料装上 ${sIdx + 1}号船 的第 ${slot + 1} 舱位';
        host.log(lastAction);
        _advanceTurnOrRound(seat);
        break;

      case 'sail':
        final sIdx = asInt(action['ship'], -1);
        final dest = asInt(action['dest'], -1);
        if (sIdx < 0 || sIdx >= ships.length) {
          throw GameError('无效的船只编号');
        }
        if (dest < 0 || dest >= 5) {
          throw GameError('无效的目的地编号');
        }
        final ship = ships[sIdx];
        if (ship.sailed) {
          throw GameError('该船只已经起航');
        }
        if (!ship.canSail) {
          throw GameError('该船只装载石料不足最低起航要求（需至少 ${ship.minRequired} 块）');
        }
        if (destShip[dest] != -1) {
          throw GameError('目的地【${imhotepDestNames[dest]}】本轮已有船只停靠');
        }

        ship.sailed = true;
        ship.dest = dest;
        destShip[dest] = sIdx;

        // Unload stones in slot order 0..size-1
        for (var k = 0; k < ship.size; k++) {
          final owner = ship.slots[k];
          if (owner < 0) continue;
          switch (dest) {
            case 0:
              _giveMarketCard(owner);
              break;
            case 1:
              _placeInPyramid(owner);
              break;
            case 2:
              _placeInTemple(owner);
              break;
            case 3:
              _placeInBurial(owner);
              break;
            case 4:
              _placeInObelisk(owner);
              break;
          }
        }

        lastAction = '${name(seat)} 驾驶 ${sIdx + 1}号船 驶往【${imhotepDestNames[dest]}】';
        host.log(lastAction);
        _advanceTurnOrRound(seat);
        break;

      default:
        throw GameError('未知行动：$type');
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    final openDests = <int>[
      for (var d = 0; d < 5; d++)
        if (destShip[d] == -1) d,
    ];
    final sailableShips = <int>[
      for (var s = 0; s < ships.length; s++)
        if (ships[s].canSail) s,
    ];
    final loadableShips = <int>[
      for (var s = 0; s < ships.length; s++)
        if (ships[s].hasOpenSlot) s,
    ];

    if (botLevel == 0) {
      if (sled[seat] > 0 && loadableShips.isNotEmpty && rng.nextBool()) {
        final s = loadableShips[rng.nextInt(loadableShips.length)];
        final slot = ships[s].slots.indexWhere((x) => x == -1);
        return {'type': 'load', 'ship': s, 'slot': slot};
      }
      if (sailableShips.isNotEmpty && openDests.isNotEmpty && (sled[seat] == 0 || rng.nextBool())) {
        final s = sailableShips[rng.nextInt(sailableShips.length)];
        final d = openDests[rng.nextInt(openDests.length)];
        return {'type': 'sail', 'ship': s, 'dest': d};
      }
      if (sled[seat] < 5) {
        return {'type': 'quarry'};
      }
      if (sailableShips.isNotEmpty && openDests.isNotEmpty) {
        return {'type': 'sail', 'ship': sailableShips.first, 'dest': openDests.first};
      }
    }

    // Check if sailing a ship right now where we have majority of stones is high value
    if (sailableShips.isNotEmpty && openDests.isNotEmpty) {
      var bestSailShip = -1;
      var bestDest = -1;
      var bestNet = -999.0;
      for (final s in sailableShips) {
        final ship = ships[s];
        final myStones = ship.slots.where((x) => x == seat).length;
        final otherStones = ship.loadedCount - myStones;
        for (final d in openDests) {
          final destVal = d == 1 ? 3.2 : (d == 3 ? 2.8 : (d == 4 ? 2.6 : 2.3));
          final net = (myStones - otherStones * 0.65) * destVal;
          if (net > bestNet) {
            bestNet = net;
            bestSailShip = s;
            bestDest = d;
          }
        }
      }
      if (bestSailShip != -1 && (bestNet >= 2.2 || (sled[seat] == 5 && loadableShips.isEmpty))) {
        return {'type': 'sail', 'ship': bestSailShip, 'dest': bestDest};
      }
    }

    // Load a stone if we have stones on sled and open ship slots
    if (sled[seat] > 0 && loadableShips.isNotEmpty) {
      // Prefer a ship that is close to minRequired or empty front slot
      var bestShip = loadableShips.first;
      var bestPriority = -999;
      for (final s in loadableShips) {
        final ship = ships[s];
        final myCount = ship.slots.where((x) => x == seat).length;
        final prio = myCount * 3 + ship.loadedCount;
        if (prio > bestPriority) {
          bestPriority = prio;
          bestShip = s;
        }
      }
      final slot = ships[bestShip].slots.indexWhere((x) => x == -1);
      return {'type': 'load', 'ship': bestShip, 'slot': slot};
    }

    // Quarry if low on stones
    if (sled[seat] < 4) {
      return {'type': 'quarry'};
    }

    if (sailableShips.isNotEmpty && openDests.isNotEmpty) {
      return {'type': 'sail', 'ship': sailableShips.first, 'dest': openDests.first};
    }
    if (sled[seat] < 5) {
      return {'type': 'quarry'};
    }
    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final obScores = scoreObelisks(obelisk);
    final burScores = [for (var s = 0; s < players; s++) burialScore(s)];
    final totals = [for (var s = 0; s < players; s++) vp[s] + burScores[s] + obScores[s]];

    return {
      'round': round,
      'maxRounds': maxRounds,
      'turn': turn,
      'over': _over,
      'lastAction': lastAction,
      'ships': [for (final s in ships) s.toJson()],
      'destShip': List<int>.of(destShip),
      'marketCards': List<String>.of(marketCards),
      'pyramidStones': List<int>.of(pyramidStones),
      'templeTop': List<int>.of(templeTop),
      'templeCursor': templeCursor,
      'templeTotalStones': templeTotalStones,
      'burialStones': List<int>.of(burialStones),
      'obelisk': List<int>.of(obelisk),
      'players': [
        for (var s = 0; s < players; s++)
          {
            'seat': s,
            'sled': sled[s],
            'vp': vp[s],
            'statues': statues[s],
            'burialScore': burScores[s],
            'obeliskHeight': obelisk[s],
            'obeliskScore': obScores[s],
            'totalScore': totals[s],
          },
      ],
      'scores': totals,
      'placings': placings,
    };
  }
}
