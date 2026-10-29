import 'dart:math';

import '../../src/engine.dart';

class SheriffGoodDef {
  final int id; // 0..7
  final String name;
  final int value;
  final int penalty;
  final bool legal;
  final int deckCopies;
  final int kingBonus;
  final int queenBonus;

  const SheriffGoodDef({
    required this.id,
    required this.name,
    required this.value,
    required this.penalty,
    required this.legal,
    required this.deckCopies,
    this.kingBonus = 0,
    this.queenBonus = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'value': value,
        'penalty': penalty,
        'legal': legal,
        'kingBonus': kingBonus,
        'queenBonus': queenBonus,
      };
}

const List<SheriffGoodDef> kSheriffGoods = [
  // Legal Goods (0..3)
  SheriffGoodDef(
    id: 0,
    name: '苹果',
    value: 2,
    penalty: 2,
    legal: true,
    deckCopies: 48,
    kingBonus: 15,
    queenBonus: 10,
  ),
  SheriffGoodDef(
    id: 1,
    name: '奶酪',
    value: 3,
    penalty: 2,
    legal: true,
    deckCopies: 36,
    kingBonus: 15,
    queenBonus: 10,
  ),
  SheriffGoodDef(
    id: 2,
    name: '面包',
    value: 3,
    penalty: 2,
    legal: true,
    deckCopies: 36,
    kingBonus: 15,
    queenBonus: 10,
  ),
  SheriffGoodDef(
    id: 3,
    name: '鸡肉',
    value: 4,
    penalty: 2,
    legal: true,
    deckCopies: 24,
    kingBonus: 10,
    queenBonus: 5,
  ),
  // Contraband Goods (4..7)
  SheriffGoodDef(
    id: 4,
    name: '胡椒',
    value: 6,
    penalty: 4,
    legal: false,
    deckCopies: 22,
  ),
  SheriffGoodDef(
    id: 5,
    name: '蜂蜜酒',
    value: 7,
    penalty: 4,
    legal: false,
    deckCopies: 21,
  ),
  SheriffGoodDef(
    id: 6,
    name: '丝绸',
    value: 8,
    penalty: 4,
    legal: false,
    deckCopies: 12,
  ),
  SheriffGoodDef(
    id: 7,
    name: '弩箭',
    value: 9,
    penalty: 4,
    legal: false,
    deckCopies: 15,
  ),
];

const String sheriffRules = '''
# 诺丁汉警长（Sheriff of Nottingham）规则说明

## 游戏简介
《诺丁汉警长》是一款融合心理博弈、吹牛欺骗与贿赂谈判的欢乐派对桌游。玩家们轮流担任诺丁汉警长，其余玩家作为商人试图将高价值的违禁品偷偷运入城内的市场摊位，或诚实申报赚取警长的误查赔偿金！

## 货物种类
- **合法货物（0～3）**：
  - **苹果**：价值 2 金，罚金 2 金（国王奖 +15，王后奖 +10）
  - **奶酪**：价值 3 金，罚金 2 金（国王奖 +15，王后奖 +10）
  - **面包**：价值 3 金，罚金 2 金（国王奖 +15，王后奖 +10）
  - **鸡肉**：价值 4 金，罚金 2 金（国王奖 +10，王后奖 +5）
- **违禁品（4～7）**：
  - **胡椒**：价值 6 金，罚金 4 金
  - **蜂蜜酒**：价值 7 金，罚金 4 金
  - **丝绸**：价值 8 金，罚金 4 金
  - **弩箭**：价值 9 金，罚金 4 金

## 回合流程
每轮由 1 名玩家担任 **警长**，其余玩家均为 **商人**：
1. **装袋与申报阶段（`pack`）**：
   - 所有商人同时从 6 张手牌中选择 **1～5 张** 装入货袋；
   - 公开申报袋中货物为某 **1 种合法货物**（如“4个苹果”），并可附带 **0～10 金币的贿赂**。
2. **警长盘查阶段（`inspect`）**：
   - 警长依次对每位商人的货袋做出决定：**放行（`pass`）** 或 **开袋检查（`open`）**：
   - **选择放行**：商人向警长支付所承诺的贿赂金币，并将袋中所有货物（含违禁品）安全放入自己的市场摊位！
   - **选择开袋检查**：
     - **商人完全诚实**（袋中所有牌均与申报的合法货物一致）：警长必须按袋中所有货物的罚金总和赔偿给商人，货物全部进入商人摊位，且商人无需支付贿赂！
     - **商人撒谎**（袋中有任何未如实申报的合法货物或违禁品）：与申报种类一致的合法货物仍进入商人摊位，所有不符的货物被没收充公，且商人必须按被没收货物的罚金总和向警长交纳罚款（无需再付贿赂）。
3. **补牌与轮换**：所有商人结算完毕后，每人将手牌补满 6 张，警长职位顺时针传给下一位玩家。

## 终局与计分
- 当每位玩家都担任过指定次数（1 次或 2 次）警长后，游戏结束。
- 每位玩家统计：所持金币 + 摊位上所有合法货物与违禁品的总价值 + 4 种合法货物的 **国王奖（数量最多者 +15/+10）** 与 **王后奖（数量第二多者 +10/+5）**（平局平分向下取整）。总财富最高者获胜！
''';

class SheriffGame extends GameEngine {
  SheriffGame(super.setup);

  final List<int> deck = [];
  final List<int> discard = [];

  late List<List<int>> hand;
  late List<List<int>> stand; // stand[seat][goodId]
  late List<int> gold;

  late List<bool> packed;
  late List<List<int>> bags;
  late List<int> declaredType;
  late List<int> bribes;

  int sheriff = 0;
  int round = 0;
  late int maxRounds;
  String phase = 'pack'; // 'pack', 'inspect'
  List<int> inspectOrder = [];
  int inspectIdx = 0;
  String lastLog = '游戏开始';
  Map<String, dynamic>? lastInspectResult;

  bool _over = false;
  List<int>? _finalScores;
  List<int>? _kingQueenBonuses;

  int get turnsAsSheriff => setup.opt<int>('turnsAsSheriff', 1);

  int get currentMerchant =>
      phase == 'inspect' && inspectIdx < inspectOrder.length ? inspectOrder[inspectIdx] : -1;

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _over && _finalScores != null ? rankByScore(_finalScores!) : null;

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (phase == 'pack') {
      return [
        for (var s = 0; s < players; s++)
          if (s != sheriff && !packed[s]) s,
      ];
    }
    if (phase == 'inspect') {
      return [sheriff];
    }
    return const [];
  }

  @override
  void start() {
    deck.clear();
    discard.clear();
    for (final g in kSheriffGoods) {
      for (var i = 0; i < g.deckCopies; i++) {
        deck.add(g.id);
      }
    }
    deck.shuffle(rng);

    hand = List.generate(players, (_) => <int>[]);
    stand = List.generate(players, (_) => List<int>.filled(8, 0));
    gold = List<int>.filled(players, 50);

    packed = List<bool>.filled(players, false);
    bags = List.generate(players, (_) => <int>[]);
    declaredType = List<int>.filled(players, 0);
    bribes = List<int>.filled(players, 0);

    for (var s = 0; s < players; s++) {
      _refillHand(s);
    }

    sheriff = 0;
    round = 0;
    maxRounds = players * turnsAsSheriff;
    phase = 'pack';
    inspectOrder = [];
    inspectIdx = 0;
    _over = false;
    _finalScores = null;
    _kingQueenBonuses = null;
    lastInspectResult = null;
    lastLog = '第 1 轮开始，${name(sheriff)} 担任警长，请各位商人装袋申报';
    host.log(lastLog);
  }

  void _refillHand(int seat) {
    while (hand[seat].length < 6) {
      if (deck.isEmpty && discard.isNotEmpty) {
        deck.addAll(discard..shuffle(rng));
        discard.clear();
      }
      if (deck.isEmpty) break;
      hand[seat].add(deck.removeLast());
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'pack') {
      if (type != 'pack') throw GameError('当前处于商人装袋申报阶段');
      _handlePack(seat, action);
      return;
    }

    if (phase == 'inspect') {
      if (seat != sheriff) throw GameError('只有当前警长可以执行检查或放行');
      if (type == 'pass' || type == 'open') {
        _handleInspect(type == 'open');
      } else if (type == 'inspect') {
        final choice = asStr(action['choice'] ?? action['action']);
        if (choice == 'open' || action['open'] == true) {
          _handleInspect(true);
        } else if (choice == 'pass' || action['open'] == false) {
          _handleInspect(false);
        } else {
          throw GameError('未知检查选项');
        }
      } else {
        throw GameError('未知操作：$type');
      }
      return;
    }

    throw GameError('未知阶段：$phase');
  }

  void _handlePack(int seat, Map<String, dynamic> action) {
    if (seat == sheriff) throw GameError('警长本轮无需装袋');
    if (packed[seat]) throw GameError('你本轮已经完成装袋');

    final indices = asIntList(action['indices']);
    if (indices.isEmpty || indices.length > 5) {
      throw GameError('必须选择 1～5 张手牌装入货袋');
    }
    final unique = indices.toSet();
    if (unique.length != indices.length) {
      throw GameError('不能重复选择同一张手牌');
    }
    for (final idx in indices) {
      if (idx < 0 || idx >= hand[seat].length) {
        throw GameError('手牌索引无效：$idx');
      }
    }

    final decl = asInt(action['declared'] ?? action['declaredType'], -1);
    if (decl < 0 || decl > 3) {
      throw GameError('只能申报合法货物（0:苹果, 1:奶酪, 2:面包, 3:鸡肉）');
    }

    final bribe = asInt(action['bribe'], 0);
    if (bribe < 0 || bribe > 10) {
      throw GameError('贿赂金额须在 0～10 金币之间');
    }
    if (bribe > gold[seat]) {
      throw GameError('贿赂金额不能超过你当前持有的金币（${gold[seat]}）');
    }

    final chosen = [for (final idx in indices) hand[seat][idx]];
    final sortedDesc = List<int>.of(indices)..sort((a, b) => b.compareTo(a));
    for (final idx in sortedDesc) {
      hand[seat].removeAt(idx);
    }

    bags[seat] = chosen;
    declaredType[seat] = decl;
    bribes[seat] = bribe;
    packed[seat] = true;

    lastLog = '${name(seat)} 装好了 ${chosen.length} 件货物，申报为「${kSheriffGoods[decl].name}」'
        '${bribe > 0 ? '，并出价 $bribe 金贿赂' : ''}';
    host.log(lastLog);

    if (waitingFor.isEmpty) {
      phase = 'inspect';
      inspectOrder = [
        for (var i = 1; i < players; i++) (sheriff + i) % players,
      ];
      inspectIdx = 0;
      lastLog = '所有商人已装袋，请警长 ${name(sheriff)} 盘查 ${name(currentMerchant)} 的货袋';
      host.log(lastLog);
    }
  }

  void _handleInspect(bool openBag) {
    final m = currentMerchant;
    if (m < 0) throw GameError('没有待盘查的商人');
    final bag = bags[m];
    final decl = declaredType[m];
    final bribe = bribes[m];

    if (!openBag) {
      // Sheriff lets the bag pass!
      final paid = min(bribe, gold[m]);
      gold[m] -= paid;
      gold[sheriff] += paid;
      for (final c in bag) {
        stand[m][c] += 1;
      }
      lastLog = '警长 ${name(sheriff)} 放行了 ${name(m)} 的货袋（${ bag.length }件）'
          '${paid > 0 ? '，收下 $paid 金贿赂' : ''}';
      lastInspectResult = {
        'merchant': m,
        'sheriff': sheriff,
        'opened': false,
        'honest': null,
        'bribePaid': paid,
        'count': bag.length,
        'declared': decl,
      };
      host.log(lastLog);
    } else {
      // Sheriff opens the bag!
      final honest = bag.every((c) => c == decl);
      if (honest) {
        final penaltySum = bag.fold<int>(0, (s, c) => s + kSheriffGoods[c].penalty);
        final paid = min(penaltySum, gold[sheriff]);
        gold[sheriff] -= paid;
        gold[m] += penaltySum;
        for (final c in bag) {
          stand[m][c] += 1;
        }
        lastLog = '警长 ${name(sheriff)} 开袋检查：${name(m)} 完全诚实（${bag.length}个${kSheriffGoods[decl].name}）！'
            '警长赔偿 $penaltySum 金！';
        lastInspectResult = {
          'merchant': m,
          'sheriff': sheriff,
          'opened': true,
          'honest': true,
          'penalty': penaltySum,
          'cards': List<int>.of(bag),
          'declared': decl,
        };
        host.log(lastLog);
      } else {
        var passedCount = 0;
        final confiscated = <int>[];
        for (final c in bag) {
          if (c == decl) {
            stand[m][c] += 1;
            passedCount++;
          } else {
            confiscated.add(c);
            discard.add(c);
          }
        }
        final penaltySum = confiscated.fold<int>(0, (s, c) => s + kSheriffGoods[c].penalty);
        final paid = min(penaltySum, gold[m]);
        gold[m] -= paid;
        gold[sheriff] += paid;
        final confNames = confiscated.map((c) => kSheriffGoods[c].name).join('、');
        lastLog = '警长 ${name(sheriff)} 开袋查获 ${name(m)} 走私（没收 $confNames）！'
            '${name(m)} 被罚款 $paid 金${passedCount > 0 ? '，$passedCount 件申报货物入摊' : ''}';
        lastInspectResult = {
          'merchant': m,
          'sheriff': sheriff,
          'opened': true,
          'honest': false,
          'penalty': paid,
          'cards': List<int>.of(bag),
          'confiscated': confiscated,
          'declared': decl,
        };
        host.log(lastLog);
      }
    }

    inspectIdx++;
    if (inspectIdx < inspectOrder.length) {
      return;
    }

    // All merchants inspected for this round
    round++;
    if (round >= maxRounds) {
      _finishGame();
      return;
    }

    for (var s = 0; s < players; s++) {
      _refillHand(s);
      packed[s] = false;
      bags[s] = [];
      declaredType[s] = 0;
      bribes[s] = 0;
    }
    sheriff = (sheriff + 1) % players;
    phase = 'pack';
    inspectOrder = [];
    inspectIdx = 0;
  }

  /// Computes King & Queen bonuses for each seat across the 4 Legal Goods (0..3).
  List<int> computeKingQueenBonuses() {
    final bonuses = List<int>.filled(players, 0);
    for (var g = 0; g < 4; g++) {
      final def = kSheriffGoods[g];
      var max1 = 0;
      for (var s = 0; s < players; s++) {
        if (stand[s][g] > max1) max1 = stand[s][g];
      }
      if (max1 == 0) continue;

      final kings = [
        for (var s = 0; s < players; s++)
          if (stand[s][g] == max1) s,
      ];
      if (kings.length > 1) {
        // Tie for King: split King + Queen bonus (rounded down), no separate Queen bonus
        final share = (def.kingBonus + def.queenBonus) ~/ kings.length;
        for (final s in kings) {
          bonuses[s] += share;
        }
      } else {
        bonuses[kings.first] += def.kingBonus;
        var max2 = 0;
        for (var s = 0; s < players; s++) {
          if (s != kings.first && stand[s][g] > max2) {
            max2 = stand[s][g];
          }
        }
        if (max2 > 0) {
          final queens = [
            for (var s = 0; s < players; s++)
              if (stand[s][g] == max2) s,
          ];
          final share = def.queenBonus ~/ queens.length;
          for (final s in queens) {
            bonuses[s] += share;
          }
        }
      }
    }
    return bonuses;
  }

  int goodsValueOf(int seat) {
    var total = 0;
    for (var g = 0; g < 8; g++) {
      total += stand[seat][g] * kSheriffGoods[g].value;
    }
    return total;
  }

  int publicStandScoreOf(int seat) {
    var total = gold[seat];
    for (var g = 0; g < 4; g++) {
      total += stand[seat][g] * kSheriffGoods[g].value;
    }
    return total;
  }

  void _finishGame() {
    _over = true;
    _kingQueenBonuses = computeKingQueenBonuses();
    _finalScores = [
      for (var s = 0; s < players; s++) gold[s] + goodsValueOf(s) + _kingQueenBonuses![s],
    ];
    final maxScore = _finalScores!.reduce(max);
    final winners = [
      for (var s = 0; s < players; s++)
        if (_finalScores![s] == maxScore) name(s),
    ];
    lastLog = '游戏结束！${winners.join('、')} 以 $maxScore 金总财富获胜！';
    host.log(lastLog);
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'sheriff': sheriff,
      'round': round + 1,
      'maxRounds': maxRounds,
      'phase': phase,
      'currentMerchant': currentMerchant,
      'inspectOrder': inspectOrder,
      'inspectIdx': inspectIdx,
      'deckCount': deck.length,
      'lastLog': lastLog,
      if (lastInspectResult != null) 'lastInspect': lastInspectResult,
      'hand': seat >= 0 && seat < players ? List<int>.of(hand[seat]) : const <int>[],
      'myBag': seat >= 0 && seat < players ? List<int>.of(bags[seat]) : const <int>[],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'seat': s,
            'gold': gold[s],
            'handCount': hand[s].length,
            'packed': packed[s],
            'bagCount': bags[s].length,
            'declared': packed[s] ? declaredType[s] : null,
            'bribe': packed[s] ? bribes[s] : 0,
            'legalStand': stand[s].sublist(0, 4),
            'contrabandCount': stand[s].sublist(4, 8).fold<int>(0, (a, b) => a + b),
            if (s == seat || _over) 'fullStand': List<int>.of(stand[s]),
            'score': _over && _finalScores != null ? _finalScores![s] : publicStandScoreOf(s),
          },
      ],
      if (_over && _finalScores != null)
        'result': {
          'scores': _finalScores,
          'bonuses': _kingQueenBonuses,
          'placings': placings,
        },
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over) return null;

    if (phase == 'pack') {
      if (seat == sheriff || packed[seat]) return null;
      final h = hand[seat];
      if (h.isEmpty) return null;

      // Count legal goods in hand
      var bestLegal = 0;
      var bestCount = 0;
      for (var g = 0; g < 4; g++) {
        final cnt = h.where((c) => c == g).length;
        if (cnt > bestCount) {
          bestCount = cnt;
          bestLegal = g;
        }
      }

      // Decide whether to be honest or smuggle contraband
      final contrabandIdxs = [
        for (var i = 0; i < h.length; i++)
          if (h[i] >= 4) i,
      ];
      final legalIdxs = [
        for (var i = 0; i < h.length; i++)
          if (h[i] == bestLegal) i,
      ];

      // 60% honest if holding at least 2 matching legal goods, otherwise smuggle 1-2 contraband
      if (legalIdxs.length >= 2 && (contrabandIdxs.isEmpty || rng.nextDouble() < 0.6)) {
        final take = legalIdxs.take(5).toList();
        return {
          'type': 'pack',
          'indices': take,
          'declared': bestLegal,
          'bribe': 0,
        };
      }

      if (contrabandIdxs.isNotEmpty) {
        final picked = <int>[...legalIdxs.take(2)];
        for (final ci in contrabandIdxs.take(2)) {
          if (picked.length < 5) picked.add(ci);
        }
        final maxBribe = min(4, gold[seat]);
        final bribe = maxBribe >= 2 ? 2 + rng.nextInt(maxBribe - 1) : 0;
        return {
          'type': 'pack',
          'indices': picked,
          'declared': bestLegal,
          'bribe': bribe,
        };
      }

      return {
        'type': 'pack',
        'indices': [0],
        'declared': h[0].clamp(0, 3),
        'bribe': 0,
      };
    }

    if (phase == 'inspect' && seat == sheriff) {
      final m = currentMerchant;
      if (m < 0) return null;
      final count = bags[m].length;
      final bribe = bribes[m];
      // Bot sheriff only uses public info: bag size & bribe offered
      if (bribe >= 3) {
        return {'type': 'pass'};
      }
      final openProb = count >= 4 ? 0.65 : (bribe > 0 ? 0.5 : 0.35);
      return {'type': rng.nextDouble() < openProb ? 'open' : 'pass'};
    }

    return null;
  }
}
