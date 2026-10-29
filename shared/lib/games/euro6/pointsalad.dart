import 'dart:math';

import '../../src/engine.dart';

const List<String> psVeggieNames = ['番茄', '生菜', '胡萝卜', '卷心菜', '洋葱', '青椒'];

class PsCard {
  final int id;
  final int veggie; // 0..5
  final String rule; // per_one, per_two, pair, trio, pos_neg, most, least, even_odd, variety
  final int v1;
  final int v2;
  final int v3;
  final String label;

  const PsCard({
    required this.id,
    required this.veggie,
    required this.rule,
    this.v1 = -1,
    this.v2 = -1,
    this.v3 = -1,
    required this.label,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'veggie': veggie,
        'veggieName': psVeggieNames[veggie],
        'rule': rule,
        'v1': v1,
        'v2': v2,
        'v3': v3,
        'label': label,
      };
}

const String pointSaladRules = '''
# 点数沙拉 (Point Salad) 规则说明

## 游戏概述
《点数沙拉》是一款节奏轻快、策略丰富的双面卡牌轮抽与牌组构建桌游，支持 2~6 名玩家。
每张卡牌都有两面：**正面为计分规则（计分卡）**，**背面为一种蔬菜（蔬菜卡）**。共有 6 种蔬菜：番茄、生菜、胡萝卜、卷心菜、洋葱、青椒。

## 游戏准备
- 根据玩家人数调整牌库规模：标准模式下每种蔬菜取 `6 × 玩家人数` 张（共 `36 × 玩家人数` 张）；快速模式下卡牌数量减半。
- 洗混牌库后平均分为 3 个**计分牌堆**（正面朝上，显示计分公式）。
- 从每个计分牌堆顶各翻开 2 张牌到蔬菜面，组成中间 6 格的**蔬菜市场**。

## 回合流程
轮到你的回合时，你可以执行以下步骤：
- **可选翻转（每回合限 1 次）**：在拿牌前，你可以将自己面前已有的 1 张计分卡翻转为背面的蔬菜卡（一旦翻转为蔬菜卡，本局不能再翻回计分卡）。
- **必须拿牌（二选一）**：
  - **拿取 1 张计分卡**：从 3 个计分牌堆顶任选 1 张计分卡放到自己面前。
  - **拿取至多 2 张蔬菜卡**：从 6 格蔬菜市场中任选 2 张蔬菜卡（若整个市场只剩 1 张则拿 1 张）收入自己的蔬菜区。
- **补充市场**：拿完牌后，将蔬菜市场的空位由对应列的计分牌堆顶翻牌补满。如果某个计分牌堆已空，则将当前剩余卡牌最多的计分牌堆平均分成两堆。

## 计分规则类型
- **单项计分 (per_one)**：每个指定蔬菜 +2 分。
- **双项计分 (per_two)**：两个指定蔬菜每个各 +1 分。
- **成对计分 (pair)**：每凑齐一对指定蔬菜组合 +5 分。
- **三联计分 (trio)**：每凑齐一组三种指定蔬菜 +8 分。
- **正负计分 (pos_neg)**：每个蔬菜 A +3 分，但每个蔬菜 B -1 分。
- **最多/最少 (most / least)**：拥有指定蔬菜最多者 +10 分，最少者 +7 分（平局均可得满分）。
- **奇偶计分 (even_odd)**：指定蔬菜数量为偶数得 +7 分，奇数得 +4 分。
- **多样性计分 (variety)**：每集齐一套全部 6 种蔬菜 +12 分，或指定蔬菜数量达到 3 个及以上得 +5 分。

## 游戏结束与胜负
- 当所有计分牌堆与蔬菜市场的卡牌都被拿光时，游戏立即结束。
- 每位玩家根据自己面前所有计分卡的公式，结合各自拥有的蔬菜数量计算总分，总分最高者获胜！
''';

class PointSalad extends GameEngine {
  PointSalad(super.setup);

  final List<List<PsCard>> piles = [[], [], []];
  final List<PsCard?> market = List<PsCard?>.filled(6, null);
  late List<List<PsCard>> pointCards;
  late List<List<int>> veggies;

  int turn = 0;
  bool flippedThisTurn = false;
  bool _over = false;
  String lastAction = '游戏开始';

  @override
  bool get isOver => _over;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  List<int>? get placings => _over ? rankByScore([for (var s = 0; s < players; s++) scoreSeat(s)]) : null;

  /// Generates the base templates for a single 36-card cycle (6 per veggie).
  static List<PsCard> buildCycle(int startId) {
    final out = <PsCard>[];
    var id = startId;
    for (var v = 0; v < 6; v++) {
      final v1 = (v + 1) % 6;
      final v2 = (v + 2) % 6;
      final v3 = (v + 3) % 6;
      final v4 = (v + 4) % 6;
      final v5 = (v + 5) % 6;

      // 1. per_one: +2 per v1
      out.add(PsCard(
        id: id++,
        veggie: v,
        rule: 'per_one',
        v1: v1,
        label: '每个${psVeggieNames[v1]} +2',
      ));

      // 2. per_two: +1 per v2 + +1 per v3
      out.add(PsCard(
        id: id++,
        veggie: v,
        rule: 'per_two',
        v1: v2,
        v2: v3,
        label: '${psVeggieNames[v2]}/${psVeggieNames[v3]} 各+1',
      ));

      // 3. pair: +5 per pair of (v1 + v4)
      out.add(PsCard(
        id: id++,
        veggie: v,
        rule: 'pair',
        v1: v1,
        v2: v4,
        label: '每对(${psVeggieNames[v1]}+${psVeggieNames[v4]}) +5',
      ));

      // 4. trio or pos_neg alternating by v
      if (v.isEven) {
        out.add(PsCard(
          id: id++,
          veggie: v,
          rule: 'trio',
          v1: v1,
          v2: v3,
          v3: v5,
          label: '每组(${psVeggieNames[v1]}+${psVeggieNames[v3]}+${psVeggieNames[v5]}) +8',
        ));
      } else {
        out.add(PsCard(
          id: id++,
          veggie: v,
          rule: 'pos_neg',
          v1: v2,
          v2: v5,
          label: '每个${psVeggieNames[v2]} +3，每个${psVeggieNames[v5]} -1',
        ));
      }

      // 5. most / least / even_odd cycling
      if (v % 3 == 0) {
        out.add(PsCard(
          id: id++,
          veggie: v,
          rule: 'most',
          v1: v3,
          label: '最多${psVeggieNames[v3]} +10',
        ));
      } else if (v % 3 == 1) {
        out.add(PsCard(
          id: id++,
          veggie: v,
          rule: 'least',
          v1: v4,
          label: '最少${psVeggieNames[v4]} +7',
        ));
      } else {
        out.add(PsCard(
          id: id++,
          veggie: v,
          rule: 'even_odd',
          v1: v5,
          label: '${psVeggieNames[v5]}偶+7/奇+4',
        ));
      }

      // 6. variety: full set of 6 (+12) or >=3 of v2 (+5)
      if (v < 3) {
        out.add(PsCard(
          id: id++,
          veggie: v,
          rule: 'variety',
          v1: -1,
          label: '每套6种蔬菜 +12',
        ));
      } else {
        out.add(PsCard(
          id: id++,
          veggie: v,
          rule: 'variety',
          v1: v2,
          label: '拥有≥3个${psVeggieNames[v2]} +5',
        ));
      }
    }
    return out;
  }

  /// Evaluates a single Point Card for [seat] given all players' veggie counts.
  static int evalCard(PsCard card, int seat, List<List<int>> allVeggies) {
    final c = allVeggies[seat];
    switch (card.rule) {
      case 'per_one':
        return c[card.v1] * 2;
      case 'per_two':
        return c[card.v1] + c[card.v2];
      case 'pair':
        return min(c[card.v1], c[card.v2]) * 5;
      case 'trio':
        return min(c[card.v1], min(c[card.v2], c[card.v3])) * 8;
      case 'pos_neg':
        return c[card.v1] * 3 - c[card.v2];
      case 'most':
        var maxV = 0;
        for (final pv in allVeggies) {
          if (pv[card.v1] > maxV) maxV = pv[card.v1];
        }
        return c[card.v1] == maxV ? 10 : 0;
      case 'least':
        var minV = c[card.v1];
        for (final pv in allVeggies) {
          if (pv[card.v1] < minV) minV = pv[card.v1];
        }
        return c[card.v1] == minV ? 7 : 0;
      case 'even_odd':
        return c[card.v1].isEven ? 7 : 4;
      case 'variety':
        if (card.v1 >= 0 && card.v1 < 6) {
          return c[card.v1] >= 3 ? 5 : 0;
        }
        var minSet = c[0];
        for (var i = 1; i < 6; i++) {
          if (c[i] < minSet) minSet = c[i];
        }
        return minSet * 12;
      default:
        return 0;
    }
  }

  int scoreSeat(int seat) {
    var total = 0;
    for (final card in pointCards[seat]) {
      total += evalCard(card, seat, veggies);
    }
    return total;
  }

  @override
  void start() {
    pointCards = List.generate(players, (_) => <PsCard>[]);
    veggies = List.generate(players, (_) => List<int>.filled(6, 0));
    for (var p = 0; p < 3; p++) {
      piles[p].clear();
    }
    for (var s = 0; s < 6; s++) {
      market[s] = null;
    }

    final quick = setup.opt<String>('deckSize', 'standard') == 'quick';
    final perVeggie = quick ? 3 * players : 6 * players;

    // Build cycles and take exactly perVeggie of each vegetable
    final byVeggie = List.generate(6, (_) => <PsCard>[]);
    var nextId = 1;
    while (byVeggie[0].length < perVeggie) {
      final cycle = buildCycle(nextId);
      nextId += cycle.length;
      for (final card in cycle) {
        byVeggie[card.veggie].add(card);
      }
    }

    final deck = <PsCard>[];
    for (var v = 0; v < 6; v++) {
      byVeggie[v].shuffle(rng);
      deck.addAll(byVeggie[v].take(perVeggie));
    }
    deck.shuffle(rng);

    final perPile = deck.length ~/ 3;
    piles[0].addAll(deck.sublist(0, perPile));
    piles[1].addAll(deck.sublist(perPile, perPile * 2));
    piles[2].addAll(deck.sublist(perPile * 2));

    // Flip 2 cards from each pile into the 6-slot Veggie Market
    for (var p = 0; p < 3; p++) {
      market[p * 2] = piles[p].removeLast();
      market[p * 2 + 1] = piles[p].removeLast();
    }
    _balancePiles();

    turn = 0;
    flippedThisTurn = false;
    _over = false;
    lastAction = '游戏开始，轮到 ${name(turn)}';
  }

  void _balancePiles() {
    for (var p = 0; p < 3; p++) {
      if (piles[p].isEmpty) {
        var maxP = -1;
        var maxLen = 1; // Need at least 2 cards to split in half
        for (var i = 0; i < 3; i++) {
          if (piles[i].length > maxLen) {
            maxLen = piles[i].length;
            maxP = i;
          }
        }
        if (maxP != -1) {
          final half = piles[maxP].length ~/ 2;
          piles[p].addAll(piles[maxP].sublist(0, half));
          piles[maxP].removeRange(0, half);
        }
      }
    }
  }

  void _refillMarket() {
    for (var s = 0; s < 6; s++) {
      if (market[s] == null) {
        final p = s ~/ 2;
        if (piles[p].isEmpty) {
          _balancePiles();
          // If still empty because largest pile has only 1 card, take from any non-empty pile
          if (piles[p].isEmpty) {
            for (var i = 0; i < 3; i++) {
              if (piles[i].isNotEmpty) {
                piles[p].add(piles[i].removeAt(0));
                break;
              }
            }
          }
        }
        if (piles[p].isNotEmpty) {
          market[s] = piles[p].removeLast();
        }
      }
    }
    _balancePiles();
  }

  bool _allCardsGone() {
    for (final p in piles) {
      if (p.isNotEmpty) return false;
    }
    for (final m in market) {
      if (m != null) return false;
    }
    return true;
  }

  void _endTurn() {
    _refillMarket();
    if (_allCardsGone()) {
      _over = true;
      final scores = [for (var s = 0; s < players; s++) scoreSeat(s)];
      final ranks = placings!;
      final winners = [
        for (var s = 0; s < players; s++)
          if (ranks[s] == 1) '${name(s)}(${scores[s]}分)'
      ];
      lastAction = '牌库抽空，游戏结束！获胜：${winners.join("、")}';
      host.log(lastAction);
      return;
    }
    turn = (turn + 1) % players;
    flippedThisTurn = false;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    switch (type) {
      case 'flip':
        if (flippedThisTurn) throw GameError('本回合已经翻转过计分卡了');
        final idx = asInt(action['index'], -1);
        if (idx < 0 || idx >= pointCards[seat].length) {
          throw GameError('无效的计分卡序号');
        }
        final card = pointCards[seat].removeAt(idx);
        veggies[seat][card.veggie]++;
        flippedThisTurn = true;
        lastAction = '${name(seat)} 将计分卡【${card.label}】翻转为 ${psVeggieNames[card.veggie]}';
        host.log(lastAction);
        break;

      case 'take_point':
        final p = asInt(action['pile'], -1);
        if (p < 0 || p >= 3 || piles[p].isEmpty) {
          throw GameError('该计分牌堆为空或无效');
        }
        final card = piles[p].removeLast();
        pointCards[seat].add(card);
        lastAction = '${name(seat)} 拿取了计分卡【${card.label}】';
        host.log(lastAction);
        _endTurn();
        break;

      case 'take_veggies':
        final slots = asIntList(action['slots']);
        final availCount = market.where((c) => c != null).length;
        if (availCount == 0) throw GameError('蔬菜市场已空');
        if (slots.isEmpty || slots.length > 2) {
          throw GameError('请选择 1~2 张蔬菜卡');
        }
        if (slots.length == 2 && slots[0] == slots[1]) {
          throw GameError('不能重复选择同一个槽位');
        }
        for (final s in slots) {
          if (s < 0 || s >= 6 || market[s] == null) {
            throw GameError('所选市场槽位无效或为空');
          }
        }
        final names = <String>[];
        for (final s in slots) {
          final card = market[s]!;
          market[s] = null;
          veggies[seat][card.veggie]++;
          names.add(psVeggieNames[card.veggie]);
        }
        lastAction = '${name(seat)} 拿取了蔬菜：${names.join("、")}';
        host.log(lastAction);
        _endTurn();
        break;

      default:
        throw GameError('未知操作：$type');
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    // Optionally flip a point card that currently scores negatively (or 0 near end)
    if (!flippedThisTurn && pointCards[seat].isNotEmpty && botLevel > 0) {
      final baseScore = scoreSeat(seat);
      var bestFlipIdx = -1;
      var bestGain = 0;
      for (var i = 0; i < pointCards[seat].length; i++) {
        final card = pointCards[seat][i];
        pointCards[seat].removeAt(i);
        veggies[seat][card.veggie]++;
        final afterScore = scoreSeat(seat);
        veggies[seat][card.veggie]--;
        pointCards[seat].insert(i, card);
        final gain = afterScore - baseScore;
        if (gain > bestGain) {
          bestGain = gain;
          bestFlipIdx = i;
        }
      }
      if (bestFlipIdx != -1) {
        return {'type': 'flip', 'index': bestFlipIdx};
      }
    }

    final availSlots = <int>[
      for (var s = 0; s < 6; s++)
        if (market[s] != null) s,
    ];
    final availPiles = <int>[
      for (var p = 0; p < 3; p++)
        if (piles[p].isNotEmpty) p,
    ];

    if (botLevel == 0) {
      if (availSlots.length >= 2 && (availPiles.isEmpty || rng.nextBool())) {
        availSlots.shuffle(rng);
        return {'type': 'take_veggies', 'slots': [availSlots[0], availSlots[1]]};
      }
      if (availPiles.isNotEmpty) {
        return {'type': 'take_point', 'pile': availPiles[rng.nextInt(availPiles.length)]};
      }
      if (availSlots.isNotEmpty) {
        return {'type': 'take_veggies', 'slots': [availSlots.first]};
      }
    }

    final curScore = scoreSeat(seat);
    Map<String, dynamic>? bestAct;
    var bestVal = -999999.0;

    // Evaluate taking a point card
    for (final p in availPiles) {
      final card = piles[p].last;
      pointCards[seat].add(card);
      final delta = (scoreSeat(seat) - curScore).toDouble();
      pointCards[seat].removeLast();
      // Give bonus to point cards early if player has few point cards
      final bonus = pointCards[seat].length < 3 ? 2.5 : 0.5;
      final val = delta + bonus;
      if (val > bestVal) {
        bestVal = val;
        bestAct = {'type': 'take_point', 'pile': p};
      }
    }

    // Evaluate taking veggies
    if (availSlots.length >= 2) {
      for (var i = 0; i < availSlots.length; i++) {
        for (var j = i + 1; j < availSlots.length; j++) {
          final s1 = availSlots[i];
          final s2 = availSlots[j];
          final v1 = market[s1]!.veggie;
          final v2 = market[s2]!.veggie;
          veggies[seat][v1]++;
          veggies[seat][v2]++;
          final delta = (scoreSeat(seat) - curScore).toDouble() + 1.2;
          veggies[seat][v1]--;
          veggies[seat][v2]--;
          if (delta > bestVal) {
            bestVal = delta;
            bestAct = {'type': 'take_veggies', 'slots': [s1, s2]};
          }
        }
      }
    } else if (availSlots.length == 1) {
      final s1 = availSlots.first;
      final v1 = market[s1]!.veggie;
      veggies[seat][v1]++;
      final delta = (scoreSeat(seat) - curScore).toDouble() + 0.6;
      veggies[seat][v1]--;
      if (delta > bestVal || bestAct == null) {
        bestVal = delta;
        bestAct = {'type': 'take_veggies', 'slots': [s1]};
      }
    }

    return bestAct;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final scores = [for (var s = 0; s < players; s++) scoreSeat(s)];
    return {
      'turn': turn,
      'over': _over,
      'flippedThisTurn': flippedThisTurn,
      'lastAction': lastAction,
      'piles': [
        for (var p = 0; p < 3; p++)
          {
            'count': piles[p].length,
            'top': piles[p].isNotEmpty ? piles[p].last.toJson() : null,
          },
      ],
      'market': [
        for (var s = 0; s < 6; s++) market[s]?.toJson(),
      ],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'seat': s,
            'score': scores[s],
            'veggies': List<int>.of(veggies[s]),
            'pointCards': [
              for (final c in pointCards[s])
                {
                  ...c.toJson(),
                  'cardScore': evalCard(c, s, veggies),
                },
            ],
          },
      ],
      'scores': scores,
      'placings': placings,
    };
  }
}
