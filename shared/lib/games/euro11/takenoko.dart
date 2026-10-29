import 'dart:math';

import '../../src/engine.dart';

const String takenokoRules = '''
# 熊猫园丁 (Takenoko) 规则说明

## 游戏概述
《熊猫园丁》(Takenoko) 是著名设计师 Antoine Bauza 创作的竹林园艺策略桌游（支持 2~4 人）。日本天皇获赠一只可爱的大熊猫，玩家作为御用园丁需要扩建竹园地块、引水灌溉、指挥园丁培育绿/黄/粉三色竹子，并引导贪吃的熊猫品尝鲜笋，完成各类御前目标卡！

## 竹园与三种竹子
- 游戏开始时，中央仅有 **池塘 `(0, 0)`**，**园丁 (`gardenerPos`)** 与 **熊猫 (`pandaPos`)** 均位于池塘上。
- 竹园地块共有 3 种颜色：`0 绿竹`、`1 黄竹`、`2 粉竹`。
- 每个地块拥有属性：`color`（颜色）、`irrigated`（是否已灌溉）与 `bambooHeight`（竹子高度 `0..4`）。
- 与中央池塘 `(0, 0)` 直接相邻的地块天然获得灌溉，且在首次获得灌溉时立即生长 **1 节竹子**。

## 回合流程
1. **投掷天气骰（Weather）**：
   - `0 ☀️ 阳光`：本回合额外获得 **+1 行动点**（共 3 个行动点）。
   - `1 🌧️ 春雨`：令任意 1 个已灌溉且未满 4 节的地块立即生长 **+1 节竹子**。
   - `2 🍃 微风`：本回合可执行重复类型的行动。
   - `3 ⛈️ 雷雨`：熊猫受惊移动并立即吃掉所在地的 **1 节竹子**。
   - `4 ☁️ 白云`：获得 **+1 灌溉水渠** 储备。
2. **执行 2 个行动（阳光天气为 3 个）**：
   - **铺设地块 (`place_plot`)**：在紧邻池塘或至少与 2 个已有地块相邻的空位放置新地块。
   - **引水灌溉 (`irrigate`)**：为尚未灌溉的地块铺设水渠，使其变为已灌溉并立即长出 1 节竹子。
   - **移动园丁 (`move_gardener`)**：沿六边形直线移动园丁至目标地块；若目标地块已灌溉则长出 +1 节竹子，且周围所有 **同色且已灌溉** 的相邻地块也各长出 +1 节竹子（最高 4 节）！
   - **移动熊猫 (`move_panda`)**：沿六边形直线移动熊猫至目标地块；若该处有竹子，熊猫吃掉 1 节竹子并收入你的个人竹笋胃袋 (`eaten[seat][color]`)。
   - **抽取目标 (`draw_goal`)**：抽取 1 张新的目标卡（上限 5 张）。
   - **宣告达成目标 (`claim_goal`)**：展示手牌中已满足条件的目标卡获得分数（不消耗行动点；熊猫目标会消耗对应竹笋）。

## 终局与天皇奖励
- 当有玩家率先完成达到目标数量（标准 **6 张** / 快速 **4 张**）时，立即获得 **+2 分天皇奖励（Emperor Bonus）** 并触发最后一轮！
- 所有其他玩家完成各自最后一回合后游戏结束，总分最高者获胜。
''';

class TakenokoPlot {
  final int q;
  final int r;
  int color; // -1 = Pond, 0 = Green, 1 = Yellow, 2 = Pink
  bool irrigated;
  int bambooHeight; // 0..4

  TakenokoPlot({
    required this.q,
    required this.r,
    required this.color,
    required this.irrigated,
    required this.bambooHeight,
  });

  Map<String, dynamic> toJson() => {
        'q': q,
        'r': r,
        'color': color,
        'irrigated': irrigated,
        'bambooHeight': bambooHeight,
      };
}

class TakenokoGoal {
  final String id;
  final String kind; // 'plot' | 'gardener' | 'panda'
  final String title;
  final int vp;
  final int color; // 0..2, or -1 for tricolor panda goal
  final int count; // required plots / height / bamboo count

  const TakenokoGoal({
    required this.id,
    required this.kind,
    required this.title,
    required this.vp,
    required this.color,
    required this.count,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'title': title,
        'vp': vp,
        'color': color,
        'count': count,
      };
}

class Takenoko extends GameEngine {
  static const List<(int, int)> hexDirs = [
    (1, 0),
    (1, -1),
    (0, -1),
    (-1, 0),
    (-1, 1),
    (0, 1),
  ];

  static const List<String> colorNames = ['绿竹', '黄竹', '粉竹'];
  static const List<String> weatherNames = ['☀️ 阳光', '🌧️ 春雨', '🍃 微风', '⛈️ 雷雨', '☁️ 白云'];

  final Map<(int, int), TakenokoPlot> plots = {};
  (int, int) gardenerPos = (0, 0);
  (int, int) pandaPos = (0, 0);

  late List<List<int>> eaten; // [seat][0..2]
  late List<int> irrigationStock;
  late List<List<TakenokoGoal>> goals;
  late List<List<TakenokoGoal>> completedGoals;
  late List<int> score;
  late List<TakenokoGoal> goalDeck;
  late List<int> plotOffer;

  int targetGoals = 6;
  int emperorSeat = -1;
  bool finalRound = false;
  int finalTriggerSeat = -1;

  int turn = 0;
  int round = 1;
  int weather = 0;
  int actionsLeft = 2;
  bool over = false;
  int resignedSeat = -1;
  final List<String> recent = [];

  Takenoko(super.setup);

  void _log(String msg) {
    host.log(msg);
    recent.add(msg);
    if (recent.length > 12) recent.removeAt(0);
  }

  @override
  void start() {
    targetGoals = setup.opt<int>('targetGoals', 6);
    plots.clear();
    plots[(0, 0)] = TakenokoPlot(q: 0, r: 0, color: -1, irrigated: true, bambooHeight: 0);
    gardenerPos = (0, 0);
    pandaPos = (0, 0);

    eaten = List.generate(players, (_) => [0, 0, 0]);
    irrigationStock = List.filled(players, 1);
    score = List.filled(players, 0);
    completedGoals = List.generate(players, (_) => []);

    goalDeck = _buildGoalDeck();
    goalDeck.shuffle(rng);

    goals = List.generate(players, (_) => [_drawGoalCard('plot'), _drawGoalCard('gardener'), _drawGoalCard('panda')]);
    plotOffer = [0, 1, 2];

    turn = 0;
    round = 1;
    emperorSeat = -1;
    finalRound = false;
    finalTriggerSeat = -1;
    over = false;
    actionsLeft = 2;
    weather = 2; // Breeze on turn 1
    _log('熊猫园丁开始！达成 $targetGoals 张目标卡即可赢得天皇奖励。');
  }

  List<TakenokoGoal> _buildGoalDeck() {
    final deck = <TakenokoGoal>[];
    var id = 1;
    for (var c = 0; c < 3; c++) {
      final cn = colorNames[c];
      for (var k = 0; k < 4; k++) {
        deck.add(TakenokoGoal(
          id: 'G${id++}',
          kind: 'plot',
          title: '竹园：2块已灌溉$cn地块',
          vp: 2 + (c == 2 ? 1 : 0),
          color: c,
          count: 2,
        ));
        deck.add(TakenokoGoal(
          id: 'G${id++}',
          kind: 'gardener',
          title: '园丁：1处$cn长至3节',
          vp: 4 + (c == 2 ? 1 : 0),
          color: c,
          count: 3,
        ));
        deck.add(TakenokoGoal(
          id: 'G${id++}',
          kind: 'panda',
          title: '熊猫：品尝2节$cn竹笋',
          vp: 3 + c,
          color: c,
          count: 2,
        ));
      }
    }
    for (var k = 0; k < 3; k++) {
      deck.add(TakenokoGoal(
        id: 'G${id++}',
        kind: 'panda',
        title: '熊猫：绿/黄/粉竹笋各1节',
        vp: 6,
        color: -1,
        count: 1,
      ));
    }
    return deck;
  }

  TakenokoGoal _drawGoalCard([String? preferredKind]) {
    if (preferredKind != null) {
      final idx = goalDeck.indexWhere((g) => g.kind == preferredKind);
      if (idx >= 0) return goalDeck.removeAt(idx);
    }
    if (goalDeck.isNotEmpty) return goalDeck.removeLast();
    final c = rng.nextInt(3);
    return TakenokoGoal(
      id: 'GX${rng.nextInt(9999)}',
      kind: 'panda',
      title: '熊猫：品尝2节${colorNames[c]}竹笋',
      vp: 3 + c,
      color: c,
      count: 2,
    );
  }

  static bool areNeighbors((int, int) a, (int, int) b) {
    final dq = b.$1 - a.$1;
    final dr = b.$2 - a.$2;
    return hexDirs.contains((dq, dr));
  }

  static bool isStraightLine((int, int) from, (int, int) to) {
    if (from == to) return false;
    final dq = to.$1 - from.$1;
    final dr = to.$2 - from.$2;
    return dq == 0 || dr == 0 || (dq + dr == 0);
  }

  /// Valid empty coordinates where a new plot may be placed.
  List<(int, int)> validPlotPlacements() {
    final candidates = <(int, int)>{};
    for (final pos in plots.keys) {
      for (final (dq, dr) in hexDirs) {
        final next = (pos.$1 + dq, pos.$2 + dr);
        if (!plots.containsKey(next)) candidates.add(next);
      }
    }
    final valid = <(int, int)>[];
    for (final c in candidates) {
      if (areNeighbors(c, (0, 0))) {
        valid.add(c);
      } else {
        var adjCount = 0;
        for (final (dq, dr) in hexDirs) {
          if (plots.containsKey((c.$1 + dq, c.$2 + dr))) adjCount++;
        }
        if (adjCount >= 2) valid.add(c);
      }
    }
    valid.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
    return valid;
  }

  /// Valid coordinates reachable in a straight line from [from].
  List<(int, int)> validLineMoves((int, int) from) {
    final out = <(int, int)>[];
    for (final pos in plots.keys) {
      if (isStraightLine(from, pos)) out.add(pos);
    }
    return out;
  }

  bool canClaimGoal(int seat, TakenokoGoal g) {
    switch (g.kind) {
      case 'plot':
        final matching = plots.values.where((p) => p.color == g.color && p.irrigated).length;
        return matching >= g.count;
      case 'gardener':
        return plots.values.any((p) => p.color == g.color && p.bambooHeight >= g.count);
      case 'panda':
        if (g.color == -1) {
          return eaten[seat][0] >= 1 && eaten[seat][1] >= 1 && eaten[seat][2] >= 1;
        }
        return eaten[seat][g.color] >= g.count;
      default:
        return false;
    }
  }

  (int, int) _parseCoord(Map<String, dynamic> action) {
    final to = action['to'];
    if (to is List && to.length >= 2) {
      return (asInt(to[0], 999), asInt(to[1], 999));
    }
    if (to is Map) {
      return (asInt(to['q'], 999), asInt(to['r'], 999));
    }
    return (asInt(action['q'], 999), asInt(action['r'], 999));
  }

  void applyWeather(int seat, int w) {
    weather = w.clamp(0, 4);
    actionsLeft = weather == 0 ? 3 : 2;
    if (weather == 1) {
      // Rain: grow 1 bamboo on an irrigated plot with height < 4
      final candidates = plots.values.where((p) => p.color >= 0 && p.irrigated && p.bambooHeight < 4).toList();
      if (candidates.isNotEmpty) {
        candidates.sort((a, b) => a.bambooHeight.compareTo(b.bambooHeight));
        candidates.first.bambooHeight++;
      }
    } else if (weather == 3) {
      // Thunderstorm: Panda moves to a plot with bamboo and eats 1
      final withBamboo = plots.values.where((p) => p.color >= 0 && p.bambooHeight > 0).toList();
      if (withBamboo.isNotEmpty) {
        final target = withBamboo.first;
        pandaPos = (target.q, target.r);
        target.bambooHeight--;
        eaten[seat][target.color]++;
      }
    } else if (weather == 4) {
      irrigationStock[seat]++;
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('尚未轮到你行动');

    final type = asStr(action['type']);
    switch (type) {
      case 'roll_weather':
        final w = asInt(action['weather'], rng.nextInt(5));
        applyWeather(seat, w);
        _log('${name(seat)} 投出天气【${weatherNames[weather]}】');
        return;

      case 'place_plot':
        if (actionsLeft <= 0) throw GameError('本回合行动点已用完');
        final (q, r) = _parseCoord(action);
        final valid = validPlotPlacements();
        if (!valid.contains((q, r))) throw GameError('该位置不能铺设竹园地块');
        final color = asInt(action['color'], plotOffer.first).clamp(0, 2);
        final adjPond = areNeighbors((q, r), (0, 0));
        plots[(q, r)] = TakenokoPlot(
          q: q,
          r: r,
          color: color,
          irrigated: adjPond,
          bambooHeight: adjPond ? 1 : 0,
        );
        plotOffer = [(color + 1) % 3, (color + 2) % 3, rng.nextInt(3)];
        actionsLeft--;
        _log('${name(seat)} 在 ($q,$r) 铺设了【${colorNames[color]}】地块${adjPond ? '（临池自动灌溉长竹1节）' : ''}');
        _afterAction(seat);
        return;

      case 'irrigate':
        if (actionsLeft <= 0) throw GameError('本回合行动点已用完');
        final (q, r) = _parseCoord(action);
        final plot = plots[(q, r)];
        if (plot != null && plot.color >= 0 && !plot.irrigated) {
          plot.irrigated = true;
          if (plot.bambooHeight == 0) plot.bambooHeight = 1;
          if (irrigationStock[seat] > 0) irrigationStock[seat]--;
          actionsLeft--;
          _log('${name(seat)} 引水灌溉了 ($q,$r) 的【${colorNames[plot.color]}】地块，长出 1 节竹子');
        } else {
          // Take irrigation channel into stock or irrigate first unirrigated plot
          final unirrigated = plots.values.where((p) => p.color >= 0 && !p.irrigated).toList();
          if (unirrigated.isNotEmpty) {
            final p = unirrigated.first;
            p.irrigated = true;
            if (p.bambooHeight == 0) p.bambooHeight = 1;
            _log('${name(seat)} 灌溉了 (${p.q},${p.r}) 的【${colorNames[p.color]}】地块');
          } else {
            irrigationStock[seat]++;
            _log('${name(seat)} 领取了 1 条灌溉水渠');
          }
          actionsLeft--;
        }
        _afterAction(seat);
        return;

      case 'move_gardener':
        if (actionsLeft <= 0) throw GameError('本回合行动点已用完');
        final (q, r) = _parseCoord(action);
        final dest = plots[(q, r)];
        if (dest == null) throw GameError('目标地块不存在');
        if (!isStraightLine(gardenerPos, (q, r))) {
          throw GameError('园丁必须沿六边形直线移动至少 1 格');
        }
        gardenerPos = (q, r);
        var grown = 0;
        if (dest.color >= 0 && dest.irrigated && dest.bambooHeight < 4) {
          dest.bambooHeight++;
          grown++;
        }
        if (dest.color >= 0) {
          for (final (dq, dr) in hexDirs) {
            final nb = plots[(q + dq, r + dr)];
            if (nb != null && nb.color == dest.color && nb.irrigated && nb.bambooHeight < 4) {
              nb.bambooHeight++;
              grown++;
            }
          }
        }
        actionsLeft--;
        _log('${name(seat)} 将园丁移动至 ($q,$r)，共培育生长了 $grown 节竹子');
        _afterAction(seat);
        return;

      case 'move_panda':
        if (actionsLeft <= 0) throw GameError('本回合行动点已用完');
        final (q, r) = _parseCoord(action);
        final dest = plots[(q, r)];
        if (dest == null) throw GameError('目标地块不存在');
        if (!isStraightLine(pandaPos, (q, r))) {
          throw GameError('熊猫必须沿六边形直线移动至少 1 格');
        }
        pandaPos = (q, r);
        var ate = false;
        if (dest.color >= 0 && dest.bambooHeight > 0) {
          dest.bambooHeight--;
          eaten[seat][dest.color]++;
          ate = true;
        }
        actionsLeft--;
        _log('${name(seat)} 将熊猫移动至 ($q,$r)${ate ? '，吃掉 1 节【${colorNames[dest.color]}】' : ''}');
        _afterAction(seat);
        return;

      case 'draw_goal':
        if (actionsLeft <= 0) throw GameError('本回合行动点已用完');
        if (goals[seat].length >= 5) throw GameError('手牌目标卡已达上限 5 张');
        final kind = action['kind'] is String ? action['kind'] as String : null;
        final card = _drawGoalCard(kind);
        goals[seat].add(card);
        actionsLeft--;
        _log('${name(seat)} 抽取了 1 张目标卡');
        _afterAction(seat);
        return;

      case 'claim_goal':
        final idx = asInt(action['index'], -1);
        if (idx < 0 || idx >= goals[seat].length) throw GameError('无效的目标卡索引');
        final g = goals[seat][idx];
        if (!canClaimGoal(seat, g)) throw GameError('尚未满足该目标卡的条件');
        if (g.kind == 'panda') {
          if (g.color == -1) {
            eaten[seat][0]--;
            eaten[seat][1]--;
            eaten[seat][2]--;
          } else {
            eaten[seat][g.color] -= g.count;
          }
        }
        goals[seat].removeAt(idx);
        completedGoals[seat].add(g);
        score[seat] += g.vp;
        _log('${name(seat)} 完成了目标【${g.title}】（+${g.vp} 分）！');

        if (!finalRound && completedGoals[seat].length >= targetGoals) {
          finalRound = true;
          finalTriggerSeat = seat;
          emperorSeat = seat;
          score[seat] += 2;
          _log('👑 ${name(seat)} 率先完成 $targetGoals 张目标，获得天皇奖励 +2 分！触发最后一轮！');
        }
        if (actionsLeft <= 0) {
          _advanceTurn();
        }
        return;

      default:
        throw GameError('未知操作：$type');
    }
  }

  void _afterAction(int seat) {
    // Auto-check if all actions are spent
    if (actionsLeft <= 0) {
      _advanceTurn();
    }
  }

  void _advanceTurn() {
    final next = (turn + 1) % players;
    if (finalRound && next == finalTriggerSeat) {
      _finishGame();
      return;
    }
    if (next == 0) {
      round++;
      if (round > 18) {
        _finishGame();
        return;
      }
    }
    turn = next;
    applyWeather(turn, rng.nextInt(5));
  }

  void _finishGame() {
    over = true;
    final best = score.reduce(max);
    final winners = [for (var s = 0; s < players; s++) if (score[s] == best) name(s)];
    _log('熊猫园丁结束！${winners.join('、')} 以 $best 分荣获御用园丁称号！');
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    // 1. Always claim any completed goal card first!
    for (var i = 0; i < goals[seat].length; i++) {
      if (canClaimGoal(seat, goals[seat][i])) {
        return {'type': 'claim_goal', 'index': i};
      }
    }

    // 2. If unirrigated plots exist, irrigate one
    final unirrigated = plots.values.where((p) => p.color >= 0 && !p.irrigated).toList();
    if (unirrigated.isNotEmpty) {
      return {'type': 'irrigate', 'q': unirrigated.first.q, 'r': unirrigated.first.r};
    }

    // 3. If few plots on board (< 7), place a plot matching one of our goals
    if (plots.length < 7) {
      final valid = validPlotPlacements();
      if (valid.isNotEmpty) {
        final (q, r) = valid[rng.nextInt(valid.length)];
        final preferredColor = goals[seat].isNotEmpty && goals[seat].first.color >= 0
            ? goals[seat].first.color
            : plotOffer.first;
        return {'type': 'place_plot', 'q': q, 'r': r, 'color': preferredColor};
      }
    }

    // 4. Check if Panda can eat a bamboo needed for a panda goal
    final pandaMoves = validLineMoves(pandaPos);
    for (final (q, r) in pandaMoves) {
      final p = plots[(q, r)]!;
      if (p.color >= 0 && p.bambooHeight > 0) {
        final needed = goals[seat].any((g) => g.kind == 'panda' && (g.color == p.color || g.color == -1));
        if (needed || botLevel == 0) {
          return {'type': 'move_panda', 'to': [q, r]};
        }
      }
    }

    // 5. Move Gardener to grow bamboo on an irrigated plot with bambooHeight < 4
    final gardenerMoves = validLineMoves(gardenerPos);
    for (final (q, r) in gardenerMoves) {
      final p = plots[(q, r)]!;
      if (p.color >= 0 && p.irrigated && p.bambooHeight < 4) {
        return {'type': 'move_gardener', 'to': [q, r]};
      }
    }

    // 6. Draw goal if hand < 4
    if (goals[seat].length < 4 && goalDeck.isNotEmpty) {
      return {'type': 'draw_goal'};
    }

    // 7. Fallback: place a plot or move gardener/panda
    final valid = validPlotPlacements();
    if (valid.isNotEmpty) {
      final (q, r) = valid.first;
      return {'type': 'place_plot', 'q': q, 'r': r, 'color': plotOffer.first};
    }
    if (gardenerMoves.isNotEmpty) {
      final (q, r) = gardenerMoves.first;
      return {'type': 'move_gardener', 'to': [q, r]};
    }
    return {'type': 'irrigate'};
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'phase': over ? 'over' : 'play',
      'turn': turn,
      'round': round,
      'weather': weather,
      'weatherName': weatherNames[weather],
      'actionsLeft': actionsLeft,
      'targetGoals': targetGoals,
      'emperorSeat': emperorSeat,
      'finalRound': finalRound,
      'gardenerPos': {'q': gardenerPos.$1, 'r': gardenerPos.$2},
      'pandaPos': {'q': pandaPos.$1, 'r': pandaPos.$2},
      'plots': [for (final p in plots.values) p.toJson()],
      'validPlacements': [
        for (final (q, r) in validPlotPlacements()) {'q': q, 'r': r}
      ],
      'plotOffer': plotOffer,
      'goalDeckCount': goalDeck.length,
      'myGoals': seat >= 0 && seat < players
          ? [
              for (var i = 0; i < goals[seat].length; i++)
                {
                  ...goals[seat][i].toJson(),
                  'claimable': canClaimGoal(seat, goals[seat][i]),
                }
            ]
          : const <Map<String, dynamic>>[],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'seat': s,
            'score': score[s],
            'eaten': eaten[s],
            'irrigation': irrigationStock[s],
            'goalCount': goals[s].length,
            'completedCount': completedGoals[s].length,
            'completed': [for (final g in completedGoals[s]) g.toJson()],
            'emperor': emperorSeat == s,
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
