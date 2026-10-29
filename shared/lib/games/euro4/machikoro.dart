import 'dart:math';

import '../../src/engine.dart';

class MachiCardDef {
  final String id;
  final String name;
  final String color; // 'blue' | 'green' | 'red' | 'purple'
  final String tag; // 'wheat' | 'cow' | 'shop' | 'cup' | 'gear' | 'tower' | 'factory' | 'fruit'
  final List<int> rolls;
  final int cost;
  final int reward;
  final String desc;

  const MachiCardDef(
    this.id,
    this.name,
    this.color,
    this.tag,
    this.rolls,
    this.cost,
    this.reward,
    this.desc,
  );

  String get rollLabel => rolls.length == 1 ? '${rolls.first}' : '${rolls.first}-${rolls.last}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'tag': tag,
        'rolls': rolls,
        'rollLabel': rollLabel,
        'cost': cost,
        'reward': reward,
        'desc': desc,
      };
}

class MachiLandmarkDef {
  final String id;
  final String name;
  final int cost;
  final String desc;

  const MachiLandmarkDef(this.id, this.name, this.cost, this.desc);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cost': cost,
        'desc': desc,
      };
}

const List<MachiLandmarkDef> machiLandmarks = [
  MachiLandmarkDef('station', '火车站', 4, '可选择掷 1 颗或 2 颗骰子'),
  MachiLandmarkDef('mall', '购物中心', 10, '你的咖啡馆、西餐厅、面包房、便利店收益 +1 金币'),
  MachiLandmarkDef('park', '游乐园', 16, '掷出双数（两颗相同点数）时获得一个额外回合'),
  MachiLandmarkDef('tower', '广播塔', 22, '每回合可选择重新投掷一次骰子'),
];

final Map<String, MachiLandmarkDef> landmarkById = {
  for (final l in machiLandmarks) l.id: l,
};

const List<MachiCardDef> machiCatalog = [
  MachiCardDef('wheat', '麦田', 'blue', 'wheat', [1], 1, 1, '任何人掷出 1：从银行获得 1 金币'),
  MachiCardDef('ranch', '农场', 'blue', 'cow', [2], 1, 1, '任何人掷出 2：从银行获得 1 金币'),
  MachiCardDef('bakery', '面包房', 'green', 'shop', [2, 3], 1, 1, '自己掷出 2-3：从银行获得 1 金币'),
  MachiCardDef('cafe', '咖啡馆', 'red', 'cup', [3], 2, 1, '别人掷出 3：从当前玩家拿取 1 金币'),
  MachiCardDef('store', '便利店', 'green', 'shop', [4], 2, 3, '自己掷出 4：从银行获得 3 金币'),
  MachiCardDef('forest', '森林', 'blue', 'gear', [5], 3, 1, '任何人掷出 5：从银行获得 1 金币'),
  MachiCardDef('stadium', '体育馆', 'purple', 'tower', [6], 6, 2, '自己掷出 6：从每位对手处各拿取 2 金币'),
  MachiCardDef('tv', '电视台', 'purple', 'tower', [6], 7, 5, '自己掷出 6：从最富有对手处拿取最多 5 金币'),
  MachiCardDef('cheese', '奶酪工厂', 'green', 'factory', [7], 5, 3, '自己掷出 7：每座【农场】从银行获得 3 金币'),
  MachiCardDef('furniture', '家具工厂', 'green', 'factory', [8], 3, 3, '自己掷出 8：每座【森林/矿场】从银行获得 3 金币'),
  MachiCardDef('mine', '矿场', 'blue', 'gear', [9], 6, 5, '任何人掷出 9：从银行获得 5 金币'),
  MachiCardDef('restaurant', '西餐厅', 'red', 'cup', [9, 10], 3, 2, '别人掷出 9-10：从当前玩家拿取 2 金币'),
  MachiCardDef('orchard', '苹果园', 'blue', 'wheat', [10], 3, 3, '任何人掷出 10：从银行获得 3 金币'),
  MachiCardDef('market', '果蔬市场', 'green', 'fruit', [11, 12], 2, 2, '自己掷出 11-12：每座【麦田/苹果园】获得 2 金币'),
];

final Map<String, MachiCardDef> machiCardById = {
  for (final c in machiCatalog) c.id: c,
};

const String machiKoroRules = '''
# 骰子街 (Machi Koro)

## 游戏目标
你将担任一座新兴城市的市长，通过投掷骰子获取收入、扩建城市设施并修建标志性地标。**率先建成所需数量的主题地标（标准 4 座 / 快速 3 座）的玩家立即获胜！**

## 初始配置
- 每位玩家开局拥有 **3 枚金币**、1 座【麦田】（蓝 [1]）和 1 座【面包房】（绿 [2-3]）。
- 每位玩家有 4 座待建地标：
  1. **火车站（费用 4）**：建成后每回合可自由选择投掷 1 颗或 2 颗骰子。
  2. **购物中心（费用 10）**：你的每座【咖啡馆】【西餐厅】【面包房】【便利店】结算时多获得 +1 金币。
  3. **游乐园（费用 16）**：若投掷 2 颗骰子且点数相同（双数），本回合结束后额外获得一个回合。
  4. **广播塔（费用 22）**：每回合投掷骰子后，可选择免费重掷一次。

## 回合流程
1. **掷骰阶段 (Roll)**：当前玩家投掷 1 颗骰子（已建火车站可选 1 或 2 颗）；若已建广播塔，可选择保留结果或重掷一次。
2. **收入结算（自动按序执行）**：
   - **① 红色建筑（餐厅）**：其他玩家拥有的匹配红色卡牌先结算，直接从当前回合玩家手中夺取金币。
   - **② 蓝色建筑（初级产业）**：所有玩家拥有的匹配蓝色卡牌同时结算，各自从银行领取金币。
   - **③ 绿色与紫色建筑（商店/工厂/大型设施）**：仅当前回合玩家拥有的匹配绿色与紫色卡牌结算。
3. **建设阶段 (Build)**：当前玩家可选择支付金币 **购买 1 张市场设施卡** 或 **修建 1 座未建地标**（每回合限建 1 项），也可以选择跳过。
''';

class MachiKoro extends GameEngine {
  late final int targetLandmarks;

  late final List<int> coins;
  late final List<Map<String, int>> cards; // seat -> cardId -> count
  late final List<Set<String>> builtLandmarks; // seat -> landmarkIds
  final Map<String, int> supply = {};

  int round = 1;
  int turn = 0;
  String phase = 'roll'; // 'roll' | 'reroll' | 'build' | 'over'
  List<int> dice = [1];
  bool rerolledThisTurn = false;
  bool extraTurnGranted = false;
  List<String> rollEvents = [];
  String lastAction = '';

  int winner = -1;
  bool over = false;
  List<int>? _placings;
  Map<String, dynamic>? result;

  MachiKoro(super.setup) {
    targetLandmarks = setup.opt<int>('landmarks', 4);
    coins = List.filled(players, 3);
    cards = List.generate(players, (_) => <String, int>{});
    builtLandmarks = List.generate(players, (_) => <String>{});
  }

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => _placings;

  @override
  void start() {
    supply.clear();
    for (final c in machiCatalog) {
      supply[c.id] = c.color == 'purple' ? players : 6;
    }

    for (var s = 0; s < players; s++) {
      coins[s] = 3;
      cards[s] = {
        for (final c in machiCatalog) c.id: 0,
      };
      cards[s]['wheat'] = 1;
      cards[s]['bakery'] = 1;
      builtLandmarks[s] = <String>{};
    }

    round = 1;
    turn = 0;
    phase = 'roll';
    dice = [1];
    rerolledThisTurn = false;
    extraTurnGranted = false;
    rollEvents = [];
    winner = -1;
    over = false;
    lastAction = '骰子街开始！轮到 ${name(0)} 投掷骰子';
    host.log(lastAction);
  }

  int cardCount(int seat, String id) => cards[seat][id] ?? 0;

  bool hasLandmark(int seat, String id) => builtLandmarks[seat].contains(id);

  int get diceSum => dice.fold(0, (a, b) => a + b);

  bool get isDoubles => dice.length == 2 && dice[0] == dice[1];

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);

    if (phase == 'roll') {
      if (type != 'roll') throw GameError('请先投掷骰子');
      final numDice = asInt(action['dice'], 1);
      if (numDice != 1 && numDice != 2) throw GameError('骰子数量只能为 1 或 2');
      if (numDice == 2 && !hasLandmark(seat, 'station')) {
        throw GameError('尚未修建【火车站】，只能投掷 1 颗骰子');
      }
      _rollDice(seat, numDice);
      if (hasLandmark(seat, 'tower') && !rerolledThisTurn) {
        phase = 'reroll';
        lastAction = '${name(seat)} 掷出了 ${dice.join('+')} = $diceSum（可使用广播塔重掷）';
      } else {
        _resolveDiceAndEnterBuild();
      }
      return;
    }

    if (phase == 'reroll') {
      if (type == 'keep') {
        _resolveDiceAndEnterBuild();
        return;
      }
      if (type == 'reroll') {
        final numDice = asInt(action['dice'], dice.length);
        if (numDice != 1 && numDice != 2) throw GameError('骰子数量只能为 1 或 2');
        if (numDice == 2 && !hasLandmark(seat, 'station')) {
          throw GameError('尚未修建【火车站】，只能投掷 1 颗骰子');
        }
        rerolledThisTurn = true;
        _rollDice(seat, numDice);
        _resolveDiceAndEnterBuild();
        return;
      }
      throw GameError('请选择保留点数 (keep) 或重掷 (reroll)');
    }

    if (phase == 'build') {
      if (type == 'pass') {
        lastAction = '${name(seat)} 跳过建设';
        _endTurn();
        return;
      }
      if (type == 'buy_card') {
        final id = asStr(action['id']);
        final def = machiCardById[id];
        if (def == null) throw GameError('未知的设施卡：$id');
        if ((supply[id] ?? 0) <= 0) throw GameError('【${def.name}】已售罄');
        if (def.color == 'purple' && cardCount(seat, id) >= 1) {
          throw GameError('紫色设施【${def.name}】每人限建 1 座');
        }
        if (coins[seat] < def.cost) {
          throw GameError('金币不足，购买【${def.name}】需要 ${def.cost} 金币');
        }
        coins[seat] -= def.cost;
        supply[id] = supply[id]! - 1;
        cards[seat][id] = cardCount(seat, id) + 1;
        lastAction = '${name(seat)} 购买了【${def.name}】（花费 ${def.cost} 金币）';
        host.log(lastAction);
        _endTurn();
        return;
      }
      if (type == 'buy_landmark') {
        final id = asStr(action['id']);
        final def = landmarkById[id];
        if (def == null) throw GameError('未知的地标：$id');
        if (hasLandmark(seat, id)) throw GameError('已建成【${def.name}】');
        if (coins[seat] < def.cost) {
          throw GameError('金币不足，修建【${def.name}】需要 ${def.cost} 金币');
        }
        coins[seat] -= def.cost;
        builtLandmarks[seat].add(id);
        lastAction = '${name(seat)} 修建了地标【${def.name}】（花费 ${def.cost} 金币）！';
        host.log(lastAction);

        if (builtLandmarks[seat].length >= targetLandmarks) {
          _finishGame(seat);
          return;
        }
        _endTurn();
        return;
      }
      throw GameError('建设阶段只能执行 buy_card、buy_landmark 或 pass');
    }
  }

  void _rollDice(int seat, int numDice) {
    final forced = actionForcedDice;
    if (forced != null) {
      dice = forced;
      actionForcedDice = null;
      return;
    }
    dice = [
      rng.nextInt(6) + 1,
      if (numDice == 2) rng.nextInt(6) + 1,
    ];
  }

  // Test hook for deterministic dice rolls if needed
  List<int>? actionForcedDice;

  void _resolveDiceAndEnterBuild() {
    rollEvents = [];
    final sum = diceSum;
    final active = turn;

    // 1. Red cards (opponents steal from active player)
    for (var offset = 1; offset < players; offset++) {
      final opp = (active + offset) % players;
      if (coins[active] <= 0) break;
      final mallBonus = hasLandmark(opp, 'mall') ? 1 : 0;
      for (final def in machiCatalog.where((c) => c.color == 'red')) {
        if (!def.rolls.contains(sum)) continue;
        final cnt = cardCount(opp, def.id);
        if (cnt <= 0) continue;
        final demand = cnt * (def.reward + mallBonus);
        final stolen = min(coins[active], demand);
        if (stolen > 0) {
          coins[active] -= stolen;
          coins[opp] += stolen;
          rollEvents.add('${name(opp)} 的【${def.name}】从 ${name(active)} 拿取 $stolen 金币');
        }
      }
    }

    // 2. Blue cards (all players gain from bank)
    for (var s = 0; s < players; s++) {
      for (final def in machiCatalog.where((c) => c.color == 'blue')) {
        if (!def.rolls.contains(sum)) continue;
        final cnt = cardCount(s, def.id);
        if (cnt <= 0) continue;
        final gain = cnt * def.reward;
        coins[s] += gain;
        rollEvents.add('${name(s)} 的【${def.name}】获得 $gain 金币');
      }
    }

    // 3. Green & Purple cards (active player only)
    final activeMallBonus = hasLandmark(active, 'mall') ? 1 : 0;
    for (final def in machiCatalog.where((c) => c.color == 'green')) {
      if (!def.rolls.contains(sum)) continue;
      final cnt = cardCount(active, def.id);
      if (cnt <= 0) continue;
      var gain = 0;
      if (def.id == 'bakery' || def.id == 'store') {
        gain = cnt * (def.reward + activeMallBonus);
      } else if (def.id == 'cheese') {
        gain = cnt * def.reward * cardCount(active, 'ranch');
      } else if (def.id == 'furniture') {
        gain = cnt * def.reward * (cardCount(active, 'forest') + cardCount(active, 'mine'));
      } else if (def.id == 'market') {
        gain = cnt * def.reward * (cardCount(active, 'wheat') + cardCount(active, 'orchard'));
      }
      if (gain > 0) {
        coins[active] += gain;
        rollEvents.add('${name(active)} 的【${def.name}】获得 $gain 金币');
      }
    }

    if (sum == 6) {
      if (cardCount(active, 'stadium') > 0) {
        var totalStolen = 0;
        for (var s = 0; s < players; s++) {
          if (s == active) continue;
          final st = min(coins[s], 2);
          coins[s] -= st;
          coins[active] += st;
          totalStolen += st;
        }
        if (totalStolen > 0) {
          rollEvents.add('${name(active)} 的【体育馆】从所有对手处收取了 $totalStolen 金币');
        }
      }
      if (cardCount(active, 'tv') > 0) {
        var richest = -1;
        var maxC = 0;
        for (var s = 0; s < players; s++) {
          if (s != active && coins[s] > maxC) {
            maxC = coins[s];
            richest = s;
          }
        }
        if (richest >= 0 && maxC > 0) {
          final st = min(coins[richest], 5);
          coins[richest] -= st;
          coins[active] += st;
          rollEvents.add('${name(active)} 的【电视台】从 ${name(richest)} 处拿取了 $st 金币');
        }
      }
    }

    final evSummary = rollEvents.isEmpty ? '无建筑触发' : rollEvents.join('；');
    lastAction = '${name(active)} 掷出 ${dice.join('+')} = $diceSum：$evSummary';
    phase = 'build';
  }

  void _endTurn() {
    rerolledThisTurn = false;
    if (hasLandmark(turn, 'park') && isDoubles && !extraTurnGranted) {
      extraTurnGranted = true;
      phase = 'roll';
      lastAction = '${name(turn)} 因【游乐园】双数获得额外回合！';
      host.log(lastAction);
      return;
    }
    extraTurnGranted = false;
    turn = (turn + 1) % players;
    if (turn == 0) round++;
    phase = 'roll';
  }

  int landmarkValue(int seat) => builtLandmarks[seat]
      .fold(0, (s, id) => s + (landmarkById[id]?.cost ?? 0));

  int scoreMetric(int seat) =>
      (seat == winner ? 100000 : 0) +
      builtLandmarks[seat].length * 1000 +
      landmarkValue(seat) * 10 +
      coins[seat];

  void _finishGame(int winSeat) {
    winner = winSeat;
    over = true;
    phase = 'over';
    final metrics = [for (var s = 0; s < players; s++) scoreMetric(s)];
    _placings = rankByScore(metrics);
    result = {
      'winner': winSeat,
      'winners': [winSeat],
      'landmarksBuilt': [for (var s = 0; s < players; s++) builtLandmarks[s].length],
      'coins': List<int>.of(coins),
      'placings': _placings,
    };
    host.log('游戏结束！${name(winSeat)} 率先建成 $targetLandmarks 座地标获胜！');
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'round': round,
      'turn': turn,
      'phase': phase,
      'targetLandmarks': targetLandmarks,
      'dice': dice,
      'diceSum': diceSum,
      'rerolledThisTurn': rerolledThisTurn,
      'rollEvents': rollEvents,
      'lastAction': lastAction,
      'supply': supply,
      'catalog': [for (final c in machiCatalog) c.toJson()],
      'landmarks': [for (final l in machiLandmarks) l.toJson()],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'seat': s,
            'coins': coins[s],
            'cards': cards[s],
            'landmarks': builtLandmarks[s].toList(),
            'landmarkCount': builtLandmarks[s].length,
          },
      ],
      if (result != null) 'result': result,
    };
  }

  int _chooseDiceCount(int seat) {
    if (!hasLandmark(seat, 'station')) return 1;
    // Choose 2 dice if player owns high-roll cards (7..12)
    final highCards = cardCount(seat, 'cheese') +
        cardCount(seat, 'furniture') +
        cardCount(seat, 'mine') +
        cardCount(seat, 'orchard') +
        cardCount(seat, 'market');
    final lowCards = cardCount(seat, 'wheat') +
        cardCount(seat, 'ranch') +
        cardCount(seat, 'bakery') +
        cardCount(seat, 'store');
    if (highCards >= 2) return 2;
    if (highCards == 1 && rng.nextBool()) return 2;
    if (lowCards >= 4) return 1;
    return rng.nextBool() ? 2 : 1;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    if (phase == 'roll') {
      return {'type': 'roll', 'dice': _chooseDiceCount(seat)};
    }

    if (phase == 'reroll') {
      // Estimate if current roll gives active player any income
      final sum = diceSum;
      var myGain = 0;
      for (final def in machiCatalog) {
        if (!def.rolls.contains(sum)) continue;
        if (def.color == 'blue' || def.color == 'green' || def.color == 'purple') {
          myGain += cardCount(seat, def.id) * def.reward;
        }
      }
      if (myGain == 0) {
        return {'type': 'reroll', 'dice': _chooseDiceCount(seat)};
      }
      return {'type': 'keep'};
    }

    // phase == 'build'
    // 1. Always build an affordable landmark if possible!
    // Order landmarks from cheapest or highest priority
    for (final lm in machiLandmarks) {
      if (!hasLandmark(seat, lm.id) && coins[seat] >= lm.cost) {
        return {'type': 'buy_landmark', 'id': lm.id};
      }
    }

    // 2. If close to affording the next landmark, save coins!
    var nextLandmarkCost = 999;
    for (final lm in machiLandmarks) {
      if (!hasLandmark(seat, lm.id)) {
        nextLandmarkCost = min(nextLandmarkCost, lm.cost);
      }
    }
    final totalIncomeCards = cards[seat].values.fold(0, (a, b) => a + b);
    if (coins[seat] >= nextLandmarkCost - 3 && totalIncomeCards >= 5) {
      return {'type': 'pass'};
    }

    // 3. Buy a strong establishment from supply
    final hasStation = hasLandmark(seat, 'station');
    final priorities = hasStation
        ? ['mine', 'cheese', 'furniture', 'orchard', 'stadium', 'tv', 'forest', 'store', 'ranch', 'bakery', 'wheat', 'cafe', 'restaurant']
        : ['store', 'forest', 'ranch', 'bakery', 'wheat', 'cafe', 'stadium'];

    for (final id in priorities) {
      final def = machiCardById[id]!;
      if ((supply[id] ?? 0) <= 0) continue;
      if (def.color == 'purple' && cardCount(seat, id) >= 1) continue;
      if (coins[seat] < def.cost) continue;
      if (id == 'cheese' && cardCount(seat, 'ranch') == 0) continue;
      if (id == 'furniture' && cardCount(seat, 'forest') + cardCount(seat, 'mine') == 0) continue;
      if (totalIncomeCards < 9 || coins[seat] >= def.cost + 4) {
        return {'type': 'buy_card', 'id': id};
      }
    }

    return {'type': 'pass'};
  }
}
