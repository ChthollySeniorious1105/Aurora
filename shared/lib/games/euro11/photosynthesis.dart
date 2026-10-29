import 'dart:math';

import '../../src/engine.dart';

const String photosynthesisRules = '''
# 光合作用 (Photosynthesis) 规则说明

## 游戏概述
《光合作用》(Photosynthesis) 是 Hjalmar Hach 设计的 3D 森林光影策略桌游（支持 2~4 人）。在半径为 2（共 19 格）的六边形森林岛屿上，玩家们播种、培育幼苗直至参天大树，并在树木成熟后将其化作肥沃土壤获得高额分数。

## 森林版图与土壤肥力
- 森林由 19 个六边形格 `(q, r)` 组成（满足 `max(|q|, |r|, |q+r|) <= 2`）：
  - **外环（距离中心 2 格，共 12 格）**：1 叶贫瘠土壤（采伐得分 `12~14` 分）。
  - **中环（距离中心 1 格，共 6 格）**：2 叶肥沃土壤（采伐得分 `13~17` 分）。
  - **中心 `(0, 0)`（共 1 格）**：3 叶核心沃土（采伐得分 `17~21` 分）。

## 太阳旋转与阴影遮挡（核心机制）
- 太阳共有 6 个照射方向（`sunDir in 0..5`），每回合开始时顺时针旋转 1 格：`sunDir = (sunDir + 1) % 6`。
- 树木共有 4 个生长阶段：`0 种子 (Seed)`、`1 小树 (Small)`、`2 中树 (Medium)`、`3 大树 (Large)`。
- **阴影投射规则**：
  - 树木会向太阳光线方向投射与其高度相等长度（`1..3` 格）的阴影。
  - 位于格子 `H`、高度为 `size >= 1` 的树木，若沿迎向太阳的上游方向距离 `d (1..3)` 格处存在另一棵高度满足 `otherSize >= max(size, d)` 的树木（不区分归属玩家），则 `H` 处的树木被 **阴影遮挡**！
  - 每棵 **未被遮挡** 的树木为其拥有者产生 `size` 点 **阳光点数 (`light[owner] += size`)**！

## 行动阶段
轮到你时，可消耗阳光点数执行任意次行动，直至选择 **跳过 (`pass`)** 结束本轮：
- **播撒种子 (`plant`，消耗 1 点阳光)**：从己方一棵高度 `size >= 1` 的树木出发，在距离不超过 `size` 格的空地上播下 1 颗种子 (`size = 0`)。
- **树木生长 (`grow`，消耗 `size + 1` 点阳光)**：令己方一棵 `size < 3` 的种子或树木长高 1 级（`0->1` 耗 1 光，`1->2` 耗 2 光，`2->3` 耗 3 光）。同一格子每回合最多激活 1 次。
- **采伐大树 (`harvest`，消耗 3 点阳光)**：回收己方一棵大树 (`size == 3`)，清空该格并立即获得对应土壤环最高分数的肥力计分片（`12..21` 分）！
- **结束本轮 (`pass`)**：保留剩余阳光进入下一回合。

## 终局与胜负
- 经过设定的总回合数（标准 **12 回合** = 2 周日照 / 完整 **18 回合** = 3 周日照）后游戏结束。
- 每剩余 3 点阳光折算 +1 分，总分最高者获胜！
''';

class PsTree {
  final int owner;
  int size; // 0: Seed, 1: Small, 2: Medium, 3: Large

  PsTree({required this.owner, required this.size});

  Map<String, dynamic> toJson() => {
        'owner': owner,
        'size': size,
      };
}

class Photosynthesis extends GameEngine {
  /// 6 axial directions for sun rays (downstream ray direction).
  /// Upstream toward the sun from (q, r) is (q - d*dq, r - d*dr).
  static const List<(int, int)> sunDirs = [
    (1, 0),
    (1, -1),
    (0, -1),
    (-1, 0),
    (-1, 1),
    (0, 1),
  ];

  static const List<String> treeNames = ['种子', '小树', '中树', '大树'];

  /// All 19 hex coordinates of radius 2.
  static final List<(int, int)> allHexes = [
    for (var r = -2; r <= 2; r++)
      for (var q = -2; q <= 2; q++)
        if ((q + r).abs() <= 2) (q, r),
  ];

  static const List<(int, int)> outerRingOrder = [
    (-2, 0),
    (-2, 1),
    (-2, 2),
    (-1, 2),
    (0, 2),
    (1, 1),
    (2, 0),
    (2, -1),
    (2, -2),
    (1, -2),
    (0, -2),
    (-1, -1),
  ];

  static int hexDist((int, int) a, (int, int) b) {
    final dq = a.$1 - b.$1;
    final dr = a.$2 - b.$2;
    return (dq.abs() + dr.abs() + (dq + dr).abs()) ~/ 2;
  }

  static int soilRichness(int q, int r) {
    final d = hexDist((0, 0), (q, r));
    return (3 - d).clamp(1, 3);
  }

  final Map<(int, int), PsTree> board = {};
  late List<int> light;
  late List<int> score;
  late List<int> harvestedCount;
  late List<bool> passed;
  final Set<(int, int)> activatedThisRound = {};
  late Map<int, List<int>> soilStacks;

  int sunDir = 0;
  int round = 1;
  int maxRounds = 12;
  int firstPlayer = 0;
  int turn = 0;
  bool over = false;
  int resignedSeat = -1;
  final List<String> recent = [];

  Photosynthesis(super.setup);

  void _log(String msg) {
    host.log(msg);
    recent.add(msg);
    if (recent.length > 12) recent.removeAt(0);
  }

  @override
  void start() {
    maxRounds = setup.opt<int>('rounds', 12);
    board.clear();
    light = List.filled(players, 0);
    score = List.filled(players, 0);
    harvestedCount = List.filled(players, 0);
    passed = List.filled(players, false);
    activatedThisRound.clear();

    soilStacks = {
      1: [14, 13, 13, 12, 12, 12, 12],
      2: [17, 16, 16, 14, 14, 13, 13],
      3: [21, 20, 19, 18, 17],
    };

    // Place 2 initial small trees per player on symmetric outer-ring hexes
    for (var s = 0; s < players; s++) {
      final idx1 = (s * 3) % outerRingOrder.length;
      final idx2 = (s * 3 + 6 + (s ~/ 2)) % outerRingOrder.length;
      final h1 = outerRingOrder[idx1];
      var h2 = outerRingOrder[idx2];
      if (board.containsKey(h2)) {
        h2 = outerRingOrder.firstWhere((h) => !board.containsKey(h));
      }
      board[h1] = PsTree(owner: s, size: 1);
      board[h2] = PsTree(owner: s, size: 1);
    }

    sunDir = 0;
    round = 1;
    firstPlayer = 0;
    turn = 0;
    over = false;

    collectSunlight();
    _log('光合作用开始！共 $maxRounds 回合，第 1 回合阳光方向 $sunDir。');
  }

  /// Checks whether the tree at [pos] is shadowed by an upstream tree along [sunDir].
  bool isShadowed((int, int) pos, [int? dirOverride]) {
    final tree = board[pos];
    if (tree == null || tree.size <= 0) return false;
    final dVec = sunDirs[(dirOverride ?? sunDir) % 6];
    for (var d = 1; d <= 3; d++) {
      final up = (pos.$1 - d * dVec.$1, pos.$2 - d * dVec.$2);
      final upTree = board[up];
      if (upTree != null && upTree.size >= max(tree.size, d)) {
        return true;
      }
    }
    return false;
  }

  /// Runs the Photosynthesis phase for the current [sunDir], awarding Light Points.
  Map<int, int> collectSunlight() {
    final gained = {for (var s = 0; s < players; s++) s: 0};
    for (final entry in board.entries) {
      final pos = entry.key;
      final tree = entry.value;
      if (tree.size >= 1 && !isShadowed(pos)) {
        gained[tree.owner] = (gained[tree.owner] ?? 0) + tree.size;
        light[tree.owner] = min(20, light[tree.owner] + tree.size);
      }
    }
    return gained;
  }

  /// Returns all valid empty hexes where [seat] can plant a seed this turn.
  List<(int, int)> validPlantHexes(int seat) {
    if (light[seat] < 1) return const [];
    final sources = board.entries
        .where((e) => e.value.owner == seat && e.value.size >= 1 && !activatedThisRound.contains(e.key))
        .toList();
    if (sources.isEmpty) return const [];
    final out = <(int, int)>[];
    for (final h in allHexes) {
      if (board.containsKey(h) || activatedThisRound.contains(h)) continue;
      if (sources.any((s) => hexDist(s.key, h) <= s.value.size)) {
        out.add(h);
      }
    }
    return out;
  }

  (int, int) _parseCoord(Map<String, dynamic> action, [String key = 'to']) {
    final sub = action[key];
    if (sub is List && sub.length >= 2) {
      return (asInt(sub[0], 999), asInt(sub[1], 999));
    }
    if (sub is Map) {
      return (asInt(sub['q'], 999), asInt(sub['r'], 999));
    }
    return (asInt(action['q'], 999), asInt(action['r'], 999));
  }

  int _drawSoilVp(int richness) {
    for (var r = richness; r >= 1; r--) {
      final stack = soilStacks[r]!;
      if (stack.isNotEmpty) return stack.removeAt(0);
    }
    return 12;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('尚未轮到你行动');

    final type = asStr(action['type']);
    switch (type) {
      case 'plant':
        if (light[seat] < 1) throw GameError('阳光点数不足（播种需 1 点阳光）');
        final (q, r) = _parseCoord(action);
        if (!allHexes.contains((q, r))) throw GameError('目标坐标不在森林版图内');
        if (board.containsKey((q, r))) throw GameError('目标格子已有树木');
        if (activatedThisRound.contains((q, r))) throw GameError('该格子本回合已激活过');

        (int, int)? srcPos;
        if (action['from'] != null) {
          final cand = _parseCoord(action, 'from');
          final st = board[cand];
          if (st != null && st.owner == seat && st.size >= 1 && hexDist(cand, (q, r)) <= st.size) {
            srcPos = cand;
          }
        }
        srcPos ??= board.entries
            .where((e) =>
                e.value.owner == seat &&
                e.value.size >= 1 &&
                !activatedThisRound.contains(e.key) &&
                hexDist(e.key, (q, r)) <= e.value.size)
            .map((e) => e.key)
            .firstOrNull;
        srcPos ??= board.entries
            .where((e) => e.value.owner == seat && e.value.size >= 1 && hexDist(e.key, (q, r)) <= e.value.size)
            .map((e) => e.key)
            .firstOrNull;

        if (srcPos == null) throw GameError('附近没有射程足够的己方树木可播撒种子');

        light[seat] -= 1;
        board[(q, r)] = PsTree(owner: seat, size: 0);
        activatedThisRound.add((q, r));
        _log('${name(seat)} 在 ($q,$r) 播撒了 1 颗种子（消耗 1 ☀️）');
        return;

      case 'grow':
        final (q, r) = _parseCoord(action, 'at');
        final tree = board[(q, r)];
        if (tree == null || tree.owner != seat) throw GameError('该格没有你的树木');
        if (tree.size >= 3) throw GameError('大树已达最高生长阶段，请执行采伐');
        if (activatedThisRound.contains((q, r))) throw GameError('该格子本回合已操作过');
        final cost = tree.size + 1;
        if (light[seat] < cost) throw GameError('阳光点数不足（生长需 $cost 点阳光）');

        light[seat] -= cost;
        tree.size++;
        activatedThisRound.add((q, r));
        _log('${name(seat)} 将 ($q,$r) 的树木培育成【${treeNames[tree.size]}】（消耗 $cost ☀️）');
        return;

      case 'harvest':
        final (q, r) = _parseCoord(action, 'at');
        final tree = board[(q, r)];
        if (tree == null || tree.owner != seat) throw GameError('该格没有你的树木');
        if (tree.size != 3) throw GameError('只有大树 (size=3) 才能采伐');
        if (activatedThisRound.contains((q, r))) throw GameError('该格子本回合已操作过');
        const cost = 3;
        if (light[seat] < cost) throw GameError('阳光点数不足（采伐大树需 $cost 点阳光）');

        light[seat] -= cost;
        board.remove((q, r));
        activatedThisRound.add((q, r));
        final richness = soilRichness(q, r);
        final vp = _drawSoilVp(richness);
        score[seat] += vp;
        harvestedCount[seat]++;
        _log('${name(seat)} 采伐了 ($q,$r) 的大树，获得 $richness 叶土壤计分片 +$vp 分！');
        return;

      case 'pass':
        passed[seat] = true;
        _log('${name(seat)} 结束本轮行动（剩余 ${light[seat]} ☀️）');
        _advanceTurnOrRound();
        return;

      default:
        throw GameError('未知操作：$type');
    }
  }

  void _advanceTurnOrRound() {
    for (var i = 1; i <= players; i++) {
      final next = (turn + i) % players;
      if (!passed[next]) {
        turn = next;
        return;
      }
    }

    // All players have passed: end of round
    if (round >= maxRounds) {
      over = true;
      for (var s = 0; s < players; s++) {
        score[s] += light[s] ~/ 3;
      }
      final best = score.reduce(max);
      final winners = [for (var s = 0; s < players; s++) if (score[s] == best) name(s)];
      _log('光合作用结束！${winners.join('、')} 以 $best 分获胜！');
      return;
    }

    round++;
    sunDir = (sunDir + 1) % 6;
    firstPlayer = (firstPlayer + 1) % players;
    turn = firstPlayer;
    passed = List.filled(players, false);
    activatedThisRound.clear();
    collectSunlight();
    _log('☀️ 第 $round / $maxRounds 回合开始，太阳转至方向 $sunDir。');
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    // 1. Harvest any Large tree (size == 3) if we have >= 3 light
    if (light[seat] >= 3) {
      final largeTrees = board.entries
          .where((e) => e.value.owner == seat && e.value.size == 3 && !activatedThisRound.contains(e.key))
          .toList();
      if (largeTrees.isNotEmpty) {
        largeTrees.sort((a, b) => soilRichness(b.key.$1, b.key.$2).compareTo(soilRichness(a.key.$1, a.key.$2)));
        final pos = largeTrees.first.key;
        return {'type': 'harvest', 'q': pos.$1, 'r': pos.$2};
      }
    }

    // 2. Grow existing trees (prefer richer soil and higher trees)
    final growable = board.entries
        .where((e) =>
            e.value.owner == seat &&
            e.value.size < 3 &&
            !activatedThisRound.contains(e.key) &&
            light[seat] >= e.value.size + 1)
        .toList();
    if (growable.isNotEmpty) {
      growable.sort((a, b) {
        final sCmp = b.value.size.compareTo(a.value.size);
        if (sCmp != 0) return sCmp;
        return soilRichness(b.key.$1, b.key.$2).compareTo(soilRichness(a.key.$1, a.key.$2));
      });
      final pos = growable.first.key;
      return {'type': 'grow', 'q': pos.$1, 'r': pos.$2};
    }

    // 3. Plant a seed on a rich empty hex if we have < 5 trees/seeds
    final myTreeCount = board.values.where((t) => t.owner == seat).length;
    if (light[seat] >= 1 && myTreeCount < 5) {
      final plantHexes = validPlantHexes(seat);
      if (plantHexes.isNotEmpty) {
        plantHexes.sort((a, b) => soilRichness(b.$1, b.$2).compareTo(soilRichness(a.$1, a.$2)));
        final pos = plantHexes.first;
        return {'type': 'plant', 'q': pos.$1, 'r': pos.$2};
      }
    }

    return {'type': 'pass'};
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'phase': over ? 'over' : 'play',
      'turn': turn,
      'round': round,
      'maxRounds': maxRounds,
      'sunDir': sunDir,
      'firstPlayer': firstPlayer,
      'hexes': [
        for (final (q, r) in allHexes)
          {
            'q': q,
            'r': r,
            'soil': soilRichness(q, r),
            'tree': board[(q, r)]?.toJson(),
            'shadowed': isShadowed((q, r)),
            'activated': activatedThisRound.contains((q, r)),
          },
      ],
      'validPlants': seat >= 0 && seat < players && turn == seat && !over
          ? [
              for (final (q, r) in validPlantHexes(seat)) {'q': q, 'r': r}
            ]
          : const <Map<String, int>>[],
      'soilStacks': {
        '1': soilStacks[1],
        '2': soilStacks[2],
        '3': soilStacks[3],
      },
      'players': [
        for (var s = 0; s < players; s++)
          {
            'seat': s,
            'light': light[s],
            'score': score[s],
            'harvested': harvestedCount[s],
            'passed': passed[s],
            'trees': board.values.where((t) => t.owner == s).length,
          },
      ],
      'placings': placings,
      'resigned': resignedSeat,
      'recent': recent,
    };
  }

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings {
    if (!over) return null;
    if (resignedSeat >= 0 && players == 2) {
      return rankWinners(players, [1 - resignedSeat]);
    }
    return rankByScore(score);
  }

  @override
  bool get canResign => players >= 2;

  @override
  void resign(int seat) {
    if (over || seat < 0 || seat >= players) throw GameError('无法认输');
    resignedSeat = seat;
    over = true;
    _log('${name(seat)} 认输');
  }
}
