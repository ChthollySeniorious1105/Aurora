import 'dart:math';

import '../../src/engine.dart';

/// 5 Dice Colors in Sagrada:
/// 0: 红 Red, 1: 黄 Yellow, 2: 绿 Green, 3: 蓝 Blue, 4: 紫 Purple
const List<String> sgColorNames = ['红', '黄', '绿', '蓝', '紫'];

class SagradaDie {
  int color; // 0..4
  int val; // 1..6

  SagradaDie(this.color, this.val);

  int get value => val;

  Map<String, dynamic> toJson() => {'color': color, 'val': val};

  @override
  bool operator ==(Object other) => other is SagradaDie && other.color == color && other.val == val;

  @override
  int get hashCode => Object.hash(color, val);

  @override
  String toString() => '${sgColorNames[color]}$val';
}

class SagradaConstraint {
  final int? color; // 0..4 or null
  final int? shade; // 1..6 or null

  const SagradaConstraint({this.color, this.shade});
  const SagradaConstraint.none()
      : color = null,
        shade = null;
  const SagradaConstraint.color(int this.color) : shade = null;
  const SagradaConstraint.shade(int this.shade) : color = null;

  bool get isNone => color == null && shade == null;

  bool matches(SagradaDie die) {
    if (color != null && die.color != color) return false;
    if (shade != null && die.val != shade) return false;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'type': color != null ? 'color' : (shade != null ? 'shade' : 'none'),
        'color': color,
        'shade': shade,
      };
}

class SagradaWindowPattern {
  final String name;
  final int difficulty; // starting favor tokens 3..6
  final List<List<SagradaConstraint>> grid; // 4 rows x 5 cols

  const SagradaWindowPattern(this.name, this.difficulty, this.grid);
}

SagradaConstraint _n() => const SagradaConstraint.none();
SagradaConstraint _c(int c) => SagradaConstraint.color(c);
SagradaConstraint _s(int v) => SagradaConstraint.shade(v);

final List<SagradaWindowPattern> sgWindowPatterns = [
  SagradaWindowPattern('万花筒之光 (Kaleidoscopic Dream)', 4, [
    [_c(1), _c(3), _n(), _n(), _s(1)],
    [_c(2), _n(), _s(5), _n(), _s(4)],
    [_s(3), _n(), _c(0), _n(), _c(2)],
    [_s(2), _n(), _n(), _c(3), _c(1)],
  ]),
  SagradaWindowPattern('圣洁之冠 (Virtus)', 5, [
    [_s(4), _n(), _s(2), _s(5), _c(2)],
    [_n(), _n(), _s(6), _c(2), _s(2)],
    [_n(), _s(3), _c(2), _s(4), _n()],
    [_s(5), _c(2), _s(1), _n(), _n()],
  ]),
  SagradaWindowPattern('晨曦极光 (Aurora Sagradis)', 4, [
    [_c(0), _n(), _c(3), _n(), _c(1)],
    [_s(4), _c(4), _s(3), _c(2), _s(2)],
    [_n(), _s(1), _n(), _s(5), _n()],
    [_n(), _n(), _s(6), _n(), _n()],
  ]),
  SagradaWindowPattern('暗影交响 (Shadow Thief)', 5, [
    [_s(6), _c(4), _n(), _n(), _s(5)],
    [_s(5), _n(), _c(4), _n(), _n()],
    [_c(0), _s(6), _n(), _c(4), _n()],
    [_c(1), _c(0), _s(5), _s(4), _s(3)],
  ]),
  SagradaWindowPattern('太阳神辉 (Sun Catcher)', 3, [
    [_n(), _c(3), _s(2), _n(), _c(1)],
    [_n(), _s(4), _n(), _c(0), _n()],
    [_n(), _n(), _s(5), _c(1), _n()],
    [_c(2), _s(3), _n(), _n(), _c(4)],
  ]),
  SagradaWindowPattern('洗礼玫瑰 (Bellesguard)', 3, [
    [_c(3), _s(6), _n(), _n(), _c(1)],
    [_n(), _s(3), _c(3), _n(), _n()],
    [_n(), _s(5), _s(6), _s(2), _n()],
    [_n(), _s(4), _n(), _s(1), _c(2)],
  ]),
];

class SgPublicObjective {
  final String id;
  final String name;
  final String desc;
  final int vp;

  const SgPublicObjective(this.id, this.name, this.desc, this.vp);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'desc': desc, 'vp': vp};
}

const List<SgPublicObjective> sgPublicObjectivesCatalog = [
  SgPublicObjective('row_color', '行色彩缤纷', '每行包含 5颗且无重复颜色的骰子：每行 +6 分', 6),
  SgPublicObjective('col_color', '列色彩缤纷', '每列包含 4颗且无重复颜色的骰子：每列 +5 分', 5),
  SgPublicObjective('row_shade', '行明暗各异', '每行包含 5颗且无重复点数的骰子：每行 +5 分', 5),
  SgPublicObjective('col_shade', '列明暗各异', '每列包含 4颗且无重复点数的骰子：每列 +4 分', 4),
  SgPublicObjective('shades_12', '浅色浮光 (1 & 2)', '窗格上每凑齐一对点数 1 和 2 的骰子：每对 +2 分', 2),
  SgPublicObjective('shades_34', '中调琉璃 (3 & 4)', '窗格上每凑齐一对点数 3 和 4 的骰子：每对 +2 分', 2),
  SgPublicObjective('shades_56', '深邃暗影 (5 & 6)', '窗格上每凑齐一对点数 5 和 6 的骰子：每对 +2 分', 2),
  SgPublicObjective('color_diags', '彩绘斜纹', '对角相邻的同色骰子数量：每颗此类骰子 +1 分', 1),
];

class SgToolCard {
  final String id;
  final String name;
  final String desc;

  const SgToolCard(this.id, this.name, this.desc);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'desc': desc};
}

const List<SgToolCard> sgToolsCatalog = [
  SgToolCard('grozing_pliers', '粗调钳', '将选秀池中 1 颗骰子的点数 +1 或 -1（1 与 6 不可循环）。'),
  SgToolCard('grinding_stone', '研磨石', '将选秀池中 1 颗骰子翻转至对面点数（1↔6, 2↔5, 3↔4）。'),
  SgToolCard('glazing_hammer', '琉璃锤', '重新投掷当前选秀池中的所有骰子。'),
  SgToolCard('flux_brush', '助焊刷', '重新投掷选秀池中指定的 1 颗骰子。'),
];

const String sagradaRules = '''
# 圣家族大教堂 (Sagrada)

## 游戏简介
《圣家族大教堂》是一款精美的彩绘玻璃骰子轮抽与网格约束解谜桌游。玩家扮演玻璃彩绘大师，为巴塞罗那圣家族大教堂打造壮丽的彩绘玻璃花窗。每轮通过蛇形轮抽挑选彩色骰子镶嵌进 `4×5` 窗格，同时严守花窗的颜色、明暗与相邻约束！

## 核心配件与设定
- **5 种骰子颜色**：0 红、1 黄、2 绿、3 蓝、4 紫；点数（明暗度）为 `1..6`。
- **个人花窗图样 (`4×5`)**：每个格子可能带有指定的**颜色约束**或**点数约束**；图样难度决定初始获得的**恩宠标记 (`favor`)** 数量（3~6 个）。
- **秘密个人目标 (`privateColor`)**：每位玩家秘密抽取 1 种专属颜色，终局时自己窗格上所有该颜色骰子的点数之和直接计入总分。
- **3 张公共目标卡 (`publicObjectives`)** 与 **3 张公共工具卡 (`tools`)**。

## 轮次与蛇形轮抽（8 轮标准 / 6 轮快速）
每轮开始时，抽取并投掷 `2 × 玩家数 + 1` 颗骰子放入公共选秀池 (`draftPool`)。
按**蛇形轮抽 (`0 → 1 → ... → P-1 → P-1 → ... → 0`)** 顺序，每位玩家每轮共有 2 次行动机会。每次轮到你时可：
1. **使用工具卡 (`use_tool`，可选)**：花费 1 个恩宠标记（若该工具此前已被使用过则需花费 2 个），调整或重掷选秀池中的骰子。
2. **镶嵌骰子 (`place`)**：从选秀池选择 1 颗骰子放入自己 `4×5` 窗格的空位 `(r, c)`。
3. **跳过 (`pass`)**：若无合适位置可选择跳过本次镶嵌。

## 严格的花窗镶嵌铁律
1. **边缘与相邻规则**：每位玩家的**第一颗骰子**必须放置在窗格的**最外圈边框**（`r ∈ {0, 3}` 或 `c ∈ {0, 4}`）；此后的**每一颗骰子**都必须与窗格上已有的某颗骰子**八向相邻（正交或对角相邻）**！
2. **图样约束规则**：若目标格子标有颜色或点数约束，放入的骰子必须严格匹配该颜色或点数。
3. **正交不重复铁律**：放入的骰子**绝不能与上下左右正交相邻**的任何已放置骰子拥有**相同颜色**或**相同点数**！

## 终局计分
所有轮次结束后结算总分，总分最高者获胜：
- **公共目标分**：3 张公共目标卡的达成奖励之和。
- **个人秘密目标分**：窗格上符合你个人秘密颜色的所有骰子点数总和。
- **剩余恩宠标记**：每个未使用的恩宠标记 `+1` 分。
- **空位扣分**：窗格上每剩余 1 个未填满的空格 `-1` 分。
''';

class Sagrada extends GameEngine {
  Sagrada(super.setup);

  late int maxRounds;
  int round = 1;
  int firstPlayer = 0;
  List<int> draftOrder = [];
  int draftStep = 0;
  bool usedToolThisTurn = false;
  bool over = false;

  List<SagradaDie> draftPool = [];
  List<SagradaDie> roundTrack = [];
  List<SgPublicObjective> publicObjectives = [];
  List<SgToolCard> tools = [];
  List<bool> toolUsed = [false, false, false];

  late List<String> patternNames;
  late List<List<List<SagradaConstraint>>> pattern; // pattern[seat][4][5]
  late List<List<List<SagradaDie?>>> window; // window[seat][4][5]
  late List<int> privateColor; // 0..4
  late List<int> favor;
  String lastAction = '游戏开始，开始第 1 轮彩绘花窗轮抽！';

  int get turn => over || draftOrder.isEmpty ? 0 : draftOrder[draftStep.clamp(0, draftOrder.length - 1)];

  List<List<List<SagradaDie?>>> get grid => window;

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore([for (var s = 0; s < players; s++) scoreOf(s)]) : null;

  @override
  void start() {
    maxRounds = setup.opt<int>('rounds', 8);
    round = 1;
    firstPlayer = 0;
    over = false;

    final chosenPatterns = shuffled(sgWindowPatterns, rng);
    patternNames = [for (var s = 0; s < players; s++) chosenPatterns[s % chosenPatterns.length].name];
    pattern = [
      for (var s = 0; s < players; s++)
        [
          for (var r = 0; r < 4; r++)
            [
              for (var c = 0; c < 5; c++) chosenPatterns[s % chosenPatterns.length].grid[r][c],
            ],
        ],
    ];
    favor = [for (var s = 0; s < players; s++) chosenPatterns[s % chosenPatterns.length].difficulty];
    window = List.generate(players, (_) => List.generate(4, (_) => List<SagradaDie?>.filled(5, null)));

    final colors = shuffled([0, 1, 2, 3, 4], rng);
    privateColor = [for (var s = 0; s < players; s++) colors[s % 5]];

    publicObjectives = shuffled(sgPublicObjectivesCatalog, rng).take(3).toList();
    tools = shuffled(sgToolsCatalog, rng).take(3).toList();
    toolUsed = [false, false, false];
    roundTrack = [];

    _startRound();
  }

  void _startRound() {
    draftPool = [
      for (var i = 0; i < 2 * players + 1; i++) SagradaDie(rng.nextInt(5), 1 + rng.nextInt(6)),
    ];
    draftOrder = [
      for (var i = 0; i < players; i++) (firstPlayer + i) % players,
      for (var i = players - 1; i >= 0; i--) (firstPlayer + i) % players,
    ];
    draftStep = 0;
    usedToolThisTurn = false;
  }

  bool isWindowEmpty(int seat) {
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 5; c++) {
        if (window[seat][r][c] != null) return false;
      }
    }
    return true;
  }

  /// Strict Sagrada placement check for [die] at `(r, c)` on [seat]'s 4x5 window.
  bool canPlace(int seat, SagradaDie die, int r, int c) {
    if (r < 0 || r >= 4 || c < 0 || c >= 5) return false;
    if (window[seat][r][c] != null) return false;

    // 1. First die must be on outer border; subsequent dice must be 8-way adjacent to an existing die
    if (isWindowEmpty(seat)) {
      final onBorder = r == 0 || r == 3 || c == 0 || c == 4;
      if (!onBorder) return false;
    } else {
      var hasAdjacent = false;
      for (var dr = -1; dr <= 1; dr++) {
        for (var dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          final nr = r + dr;
          final nc = c + dc;
          if (nr >= 0 && nr < 4 && nc >= 0 && nc < 5 && window[seat][nr][nc] != null) {
            hasAdjacent = true;
            break;
          }
        }
        if (hasAdjacent) break;
      }
      if (!hasAdjacent) return false;
    }

    // 2. Must satisfy pattern cell's Color or Shade constraint (if any)
    final cellConstraint = pattern[seat][r][c];
    if (!cellConstraint.matches(die)) return false;

    // 3. Never orthogonally adjacent to a die of the same Color OR same Value!
    const ortho = [(-1, 0), (1, 0), (0, -1), (0, 1)];
    for (final (dr, dc) in ortho) {
      final nr = r + dr;
      final nc = c + dc;
      if (nr >= 0 && nr < 4 && nc >= 0 && nc < 5) {
        final neighbor = window[seat][nr][nc];
        if (neighbor != null) {
          if (neighbor.color == die.color || neighbor.val == die.val) {
            return false;
          }
        }
      }
    }

    return true;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你选骰');

    final type = asStr(action['type']);
    switch (type) {
      case 'place':
        final dieIdx = asInt(action['die'], -1);
        final r = asInt(action['r'], -1);
        final c = asInt(action['c'], -1);
        if (dieIdx < 0 || dieIdx >= draftPool.length) {
          throw GameError('请选择选秀池中的有效骰子');
        }
        final die = draftPool[dieIdx];
        if (!canPlace(seat, die, r, c)) {
          throw GameError('该位置不满足花窗镶嵌规则（需满足边缘/相邻、图样约束且正交异色异点）');
        }
        draftPool.removeAt(dieIdx);
        window[seat][r][c] = die;
        lastAction = '${name(seat)} 将【${sgColorNames[die.color]} ${die.val}】镶嵌至 ($r, $c)';
        _advanceDraftStep();

      case 'use_tool':
        if (usedToolThisTurn) throw GameError('每回合最多使用 1 次工具卡');
        final toolIdx = asInt(action['toolIdx'], -1);
        if (toolIdx < 0 || toolIdx >= tools.length) throw GameError('无效的工具卡索引');
        final cost = toolUsed[toolIdx] ? 2 : 1;
        if (favor[seat] < cost) throw GameError('恩宠标记不足（需要 $cost 个）');
        final tool = tools[toolIdx];
        final dieIdx = asInt(action['die'], 0);
        if (draftPool.isEmpty) throw GameError('选秀池中没有骰子');
        final validIdx = dieIdx.clamp(0, draftPool.length - 1);

        switch (tool.id) {
          case 'grozing_pliers':
            final delta = asInt(action['delta'], 1) >= 0 ? 1 : -1;
            final newVal = draftPool[validIdx].val + delta;
            if (newVal < 1 || newVal > 6) throw GameError('点数 1 与 6 不能循环翻转');
            draftPool[validIdx].val = newVal;
          case 'grinding_stone':
            draftPool[validIdx].val = 7 - draftPool[validIdx].val;
          case 'glazing_hammer':
            for (final d in draftPool) {
              d.val = 1 + rng.nextInt(6);
            }
          case 'flux_brush':
            draftPool[validIdx].val = 1 + rng.nextInt(6);
        }
        favor[seat] -= cost;
        toolUsed[toolIdx] = true;
        usedToolThisTurn = true;
        lastAction = '${name(seat)} 花费 $cost 个恩宠标记使用了工具【${tool.name}】';

      case 'pass':
        lastAction = '${name(seat)} 跳过了本次镶嵌';
        _advanceDraftStep();

      default:
        throw GameError('未知的圣家族大教堂操作: $type');
    }
  }

  void _advanceDraftStep() {
    usedToolThisTurn = false;
    draftStep++;
    if (draftStep < draftOrder.length) return;

    // End of round
    if (draftPool.isNotEmpty) {
      roundTrack.add(draftPool.first);
    }
    if (round >= maxRounds) {
      over = true;
      host.log('圣家族大教堂结束！最终得分：${[for (var s = 0; s < players; s++) '${name(s)} ${scoreOf(s)}分'].join('，')}');
      return;
    }
    round++;
    firstPlayer = (firstPlayer + 1) % players;
    _startRound();
  }

  int evaluatePublicObjective(int seat, SgPublicObjective obj) {
    final w = window[seat];
    switch (obj.id) {
      case 'row_color':
        var pts = 0;
        for (var r = 0; r < 4; r++) {
          final colors = <int>{};
          var full = true;
          for (var c = 0; c < 5; c++) {
            final d = w[r][c];
            if (d == null) {
              full = false;
              break;
            }
            colors.add(d.color);
          }
          if (full && colors.length == 5) pts += 6;
        }
        return pts;
      case 'col_color':
        var pts = 0;
        for (var c = 0; c < 5; c++) {
          final colors = <int>{};
          var full = true;
          for (var r = 0; r < 4; r++) {
            final d = w[r][c];
            if (d == null) {
              full = false;
              break;
            }
            colors.add(d.color);
          }
          if (full && colors.length == 4) pts += 5;
        }
        return pts;
      case 'row_shade':
        var pts = 0;
        for (var r = 0; r < 4; r++) {
          final shades = <int>{};
          var full = true;
          for (var c = 0; c < 5; c++) {
            final d = w[r][c];
            if (d == null) {
              full = false;
              break;
            }
            shades.add(d.val);
          }
          if (full && shades.length == 5) pts += 5;
        }
        return pts;
      case 'col_shade':
        var pts = 0;
        for (var c = 0; c < 5; c++) {
          final shades = <int>{};
          var full = true;
          for (var r = 0; r < 4; r++) {
            final d = w[r][c];
            if (d == null) {
              full = false;
              break;
            }
            shades.add(d.val);
          }
          if (full && shades.length == 4) pts += 4;
        }
        return pts;
      case 'shades_12':
        return _countPairValues(w, 1, 2) * 2;
      case 'shades_34':
        return _countPairValues(w, 3, 4) * 2;
      case 'shades_56':
        return _countPairValues(w, 5, 6) * 2;
      case 'color_diags':
        var count = 0;
        for (var r = 0; r < 4; r++) {
          for (var c = 0; c < 5; c++) {
            final d = w[r][c];
            if (d == null) continue;
            var hasDiag = false;
            for (final (dr, dc) in const [(-1, -1), (-1, 1), (1, -1), (1, 1)]) {
              final nr = r + dr;
              final nc = c + dc;
              if (nr >= 0 && nr < 4 && nc >= 0 && nc < 5 && w[nr][nc]?.color == d.color) {
                hasDiag = true;
                break;
              }
            }
            if (hasDiag) count++;
          }
        }
        return count;
      default:
        return 0;
    }
  }

  int _countPairValues(List<List<SagradaDie?>> w, int v1, int v2) {
    var c1 = 0;
    var c2 = 0;
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 5; c++) {
        final v = w[r][c]?.val;
        if (v == v1) c1++;
        if (v == v2) c2++;
      }
    }
    return min(c1, c2);
  }

  int publicScore(int seat) =>
      publicObjectives.fold(0, (s, obj) => s + evaluatePublicObjective(seat, obj));

  int privateScore(int seat) {
    var sum = 0;
    final targetColor = privateColor[seat];
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 5; c++) {
        final d = window[seat][r][c];
        if (d != null && d.color == targetColor) {
          sum += d.val;
        }
      }
    }
    return sum;
  }

  int emptySpaces(int seat) {
    var count = 0;
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 5; c++) {
        if (window[seat][r][c] == null) count++;
      }
    }
    return count;
  }

  int scoreOf(int seat) =>
      max(0, publicScore(seat) + privateScore(seat) + favor[seat] - emptySpaces(seat));

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'round': round,
      'maxRounds': maxRounds,
      'turn': turn,
      'firstPlayer': firstPlayer,
      'draftOrder': draftOrder,
      'draftStep': draftStep,
      'over': over,
      'lastAction': lastAction,
      'draftPool': [for (final d in draftPool) d.toJson()],
      'roundTrack': [for (final d in roundTrack) d.toJson()],
      'publicObjectives': [for (final o in publicObjectives) o.toJson()],
      'tools': [
        for (var i = 0; i < tools.length; i++)
          {
            ...tools[i].toJson(),
            'used': toolUsed[i],
            'cost': toolUsed[i] ? 2 : 1,
          },
      ],
      'patternNames': patternNames,
      'pattern': [
        for (var s = 0; s < players; s++)
          [
            for (var r = 0; r < 4; r++)
              [
                for (var c = 0; c < 5; c++) pattern[s][r][c].toJson(),
              ],
          ],
      ],
      'window': [
        for (var s = 0; s < players; s++)
          [
            for (var r = 0; r < 4; r++)
              [
                for (var c = 0; c < 5; c++) window[s][r][c]?.toJson(),
              ],
          ],
      ],
      'favor': favor,
      'privateColor': seat >= 0 && seat < players ? privateColor[seat] : null,
      'allPrivateColors': over ? privateColor : null,
      'scores': [for (var s = 0; s < players; s++) scoreOf(s)],
      'breakdown': [
        for (var s = 0; s < players; s++)
          {
            'public': publicScore(s),
            'private': over || s == seat ? privateScore(s) : 0,
            'favor': favor[s],
            'emptyPenalty': emptySpaces(s),
            'total': scoreOf(s),
          },
      ],
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    var bestDie = -1;
    var bestR = -1;
    var bestC = -1;
    var bestScore = -999;

    for (var dIdx = 0; dIdx < draftPool.length; dIdx++) {
      final die = draftPool[dIdx];
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 5; c++) {
          if (canPlace(seat, die, r, c)) {
            var sc = 10;
            // Prefer matching private color with high value
            if (die.color == privateColor[seat]) sc += die.val * 3;
            // Prefer filling constrained cells first
            if (!pattern[seat][r][c].isNone) sc += 8;
            if (sc > bestScore || (botLevel == 0 && bestDie < 0)) {
              bestScore = sc;
              bestDie = dIdx;
              bestR = r;
              bestC = c;
            }
          }
        }
      }
    }

    if (bestDie >= 0) {
      return {'type': 'place', 'die': bestDie, 'r': bestR, 'c': bestC};
    }
    return {'type': 'pass'};
  }
}
