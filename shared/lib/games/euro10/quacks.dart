import 'dart:math';

import '../../src/engine.dart';

class QuacksChip {
  final String color; // 'white', 'orange', 'green', 'blue', 'red', 'yellow', 'purple'
  final int val; // 1, 2, 3 (white only), 4

  const QuacksChip(this.color, this.val);

  int get value => val;

  Map<String, dynamic> toJson() => {'color': color, 'val': val};

  @override
  bool operator ==(Object other) => other is QuacksChip && other.color == color && other.val == val;

  @override
  int get hashCode => Object.hash(color, val);

  @override
  String toString() => '$color:$val';
}

const Map<String, String> quacksColorNames = {
  'white': '白色樱桃炸弹',
  'orange': '橙色南瓜',
  'green': '绿色蜘蛛',
  'blue': '蓝色骷髅',
  'red': '红色毒蝇伞',
  'yellow': '黄色曼德拉草',
  'purple': '紫色幽灵息',
};

const Map<String, String> quacksColorDesc = {
  'white': '白色炸弹：锅中白片总点数 > 7 时立即炸锅！',
  'orange': '橙色南瓜：纯粹推进步数，配合红蘑菇效果极佳。',
  'green': '绿色蜘蛛：若位于锅中最后 2 枚药片内，结算时每枚 +1 红宝石💎。',
  'blue': '蓝色骷髅：抽出时从袋中额外窥视 1/2/4 枚药片，自动挑最好的一枚非白片免费入锅！',
  'red': '红色毒蝇伞：若锅中已有橙色南瓜，额外前进 +1 步（若有 3 枚以上橙色则 +2 步）！',
  'yellow': '黄色曼德拉草：若前一枚入锅的是白色炸弹，立即将该白色炸弹退回袋中！',
  'purple': '紫色幽灵息：熬药结束时 1 枚得 +1 分，2 枚得 +1 分 +1 宝石，3 枚以上得 +2 分 +1 水滴推进！',
};

const List<String> quacksShopColors = ['orange', 'green', 'blue', 'red', 'yellow', 'purple'];

int quacksChipPrice(String color, int val) {
  switch (color) {
    case 'orange':
      return val == 1 ? 3 : (val == 2 ? 6 : 10);
    case 'green':
      return val == 1 ? 4 : (val == 2 ? 8 : 14);
    case 'blue':
      return val == 1 ? 5 : (val == 2 ? 10 : 19);
    case 'red':
      return val == 1 ? 4 : (val == 2 ? 8 : 14);
    case 'yellow':
      return val == 1 ? 6 : (val == 2 ? 11 : 18);
    case 'purple':
      return val == 1 ? 7 : (val == 2 ? 12 : 18);
    default:
      return 99;
  }
}

/// Cauldron Track 0..33
const List<int> quacksTrackCoins = [
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, // 0..9
  10, 11, 12, 13, 14, 15, 15, 16, 16, 17, // 10..19
  17, 18, 18, 19, 19, 20, 20, 21, 21, 22, // 20..29
  22, 23, 24, 25, // 30..33
];

const List<int> quacksTrackVp = [
  0, 0, 0, 0, 0, 0, 1, 1, 1, 1, // 0..9
  2, 2, 2, 2, 3, 3, 3, 4, 4, 4, // 10..19
  5, 5, 5, 6, 6, 7, 7, 8, 8, 9, // 20..29
  10, 11, 12, 14, // 30..33
];

const Set<int> quacksTrackRubySpots = {5, 9, 13, 16, 20, 24, 28, 30, 32};

const String quacksRules = '''
# 奎德林堡的庸医 (The Quacks of Quedlinburg)

## 游戏简介
《奎德林堡的庸医》是一款荣获德国年度行家游戏奖 (Kennerspiel des Jahres) 的手气推进与牌袋构筑桌游。每位玩家扮演炼金庸医，不断从自己的原料袋中盲抽药片投入大锅熬制魔药——抽得越多，魔药越值钱，但一旦白色樱桃炸弹总值超过 7 点，大锅就会轰然爆炸！

## 初始配置
- **个人药袋**：初始包含 7 枚白色樱桃炸弹（`4 × 白1、2 × 白2、1 × 白3`）+ `1 × 橙1` + `1 × 绿1`。
- **水滴标记 (`droplet`)**：初始位于大锅轨道 `0` 格（可花费红宝石永久前移起点）。
- **药瓶 (`flaskFull`)**：初始为装满状态，可在未炸锅时将刚抽出的 1 枚白色药片退回袋中。
- **红宝石 (`rubies`)**：初始拥有 1 颗红宝石。

## 回合流程（共 7 轮标准 / 5 轮快速）
每轮分为两个阶段：

### 1. 熬药阶段 (`brew`)
玩家轮流操作，每次可选择：
- **抽取药片 (`draw`)**：从药袋随机抽取 1 枚药片放入大锅，按其数值在 `0..33` 大锅轨道上前进，并触发药片特效：
  - **白色樱桃炸弹**：累计锅中白片总点数；若 `whiteSum > 7`，立刻**炸锅 (`exploded = true`)** 并停止熬药！
  - **橙色南瓜**：无额外特效，提供稳定的步数推进。
  - **绿色蜘蛛**：若在熬药结束时位于锅中最后 2 枚药片内，每枚奖励 +1 颗红宝石。
  - **蓝色骷髅**：抽出时按其点数（1/2/4）从袋中窥视药片，自动挑出其中数值最高的一枚非白药片免费入锅！
  - **红色毒蝇伞**：若锅中已有橙色南瓜，额外多前进 1 步（若有 3 枚以上橙色则额外 +2 步）。
  - **黄色曼德拉草**：若紧邻的前一枚入锅药片是白色炸弹，立即将该枚白片退回袋中！
  - **紫色幽灵息**：熬药结束时，锅中有 1/2/3+ 枚紫片分别获得 `+1分` / `+1分+1宝石` / `+2分+1水滴`。
- **使用药瓶 (`use_flask`)**：若药瓶装满、尚未炸锅且刚抽出的最后一枚药片为白色炸弹，可消耗药瓶将其退回袋中。
- **见好就收 (`stop`)**：主动停止熬药，锁定当前大锅位置。

### 2. 结算与采购阶段 (`shop`)
- **未炸锅玩家**：同时获得大锅当前格子的 **胜利分数 (VP)** 与 **采购金币 (Coins)**！
- **炸锅玩家 (`choose_explosion`)**：必须在 **胜利分数** 与 **采购金币** 之间二选一！
- **购买药片 (`buy`)**：使用本轮采购金币购买最多 2 枚不同颜色的彩色药片（点数 1 / 2 / 4）加入自己的药袋。
- **红宝石兑换 (`spend_rubies`)**：每花费 2 颗红宝石，可将水滴起点永久前进 1 格 (`droplet`)，或将空药瓶重新灌满 (`flask`)。
''';

class Quacks extends GameEngine {
  Quacks(super.setup);

  late int maxRounds;
  int round = 1;
  String phase = 'brew'; // 'brew' or 'shop'
  int turn = 0;
  bool over = false;

  late List<List<QuacksChip>> ownedChips;
  late List<List<QuacksChip>> bag;
  late List<List<QuacksChip>> cauldron;
  late List<int> droplet;
  late List<int> pos;
  late List<int> whiteSum;
  late List<bool> exploded;
  late List<bool> stopped;
  late List<bool> flaskFull;
  late List<int> rubies;
  late List<int> vp;
  late List<int> coins;
  late List<bool> explosionResolved;
  late List<int> boughtCount;
  late List<Set<String>> boughtColors;
  late List<bool> shopDone;
  String lastAction = '游戏开始，开始第 1 轮熬药！';

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor {
    if (over) return const [];
    if (phase == 'brew') {
      for (var i = 0; i < players; i++) {
        final s = (turn + i) % players;
        if (!stopped[s] && !exploded[s]) return [s];
      }
      return const [];
    } else {
      for (var i = 0; i < players; i++) {
        final s = (turn + i) % players;
        if (!shopDone[s]) return [s];
      }
      return const [];
    }
  }

  @override
  List<int>? get placings => over ? rankByScore(vp) : null;

  List<int> get score => vp;

  @override
  void start() {
    maxRounds = setup.opt<int>('rounds', 7);
    round = 1;
    phase = 'brew';
    turn = 0;
    over = false;

    ownedChips = List.generate(players, (_) => _startingChips());
    bag = List.generate(players, (s) => shuffled(ownedChips[s], rng));
    cauldron = List.generate(players, (_) => <QuacksChip>[]);
    droplet = List.filled(players, 0);
    pos = List.filled(players, 0);
    whiteSum = List.filled(players, 0);
    exploded = List.filled(players, false);
    stopped = List.filled(players, false);
    flaskFull = List.filled(players, true);
    rubies = List.filled(players, 1);
    vp = List.filled(players, 0);
    coins = List.filled(players, 0);
    explosionResolved = List.filled(players, false);
    boughtCount = List.filled(players, 0);
    boughtColors = List.generate(players, (_) => <String>{});
    shopDone = List.filled(players, false);
  }

  List<QuacksChip> _startingChips() => [
        const QuacksChip('white', 1),
        const QuacksChip('white', 1),
        const QuacksChip('white', 1),
        const QuacksChip('white', 1),
        const QuacksChip('white', 2),
        const QuacksChip('white', 2),
        const QuacksChip('white', 3),
        const QuacksChip('orange', 1),
        const QuacksChip('green', 1),
      ];

  void _placeChipInPot(int seat, QuacksChip chip) {
    // Yellow checks if the immediately preceding chip in pot is white
    final prevWasWhite = cauldron[seat].isNotEmpty && cauldron[seat].last.color == 'white';
    cauldron[seat].add(chip);
    var steps = chip.val;

    if (chip.color == 'red') {
      final oranges = cauldron[seat].where((c) => c.color == 'orange').length;
      if (oranges >= 3) {
        steps += 2;
      } else if (oranges >= 1) {
        steps += 1;
      }
    }

    pos[seat] = min(33, pos[seat] + steps);

    if (chip.color == 'white') {
      whiteSum[seat] += chip.val;
      if (whiteSum[seat] > 7) {
        exploded[seat] = true;
        stopped[seat] = true;
      }
    } else if (chip.color == 'yellow' && prevWasWhite && cauldron[seat].length >= 2) {
      final prevIdx = cauldron[seat].length - 2;
      final removed = cauldron[seat].removeAt(prevIdx);
      whiteSum[seat] = max(0, whiteSum[seat] - removed.val);
      bag[seat].add(removed);
      bag[seat] = shuffled(bag[seat], rng);
    } else if (chip.color == 'blue' && bag[seat].isNotEmpty) {
      final peekCount = min(chip.val, bag[seat].length);
      final peeked = <QuacksChip>[];
      for (var i = 0; i < peekCount; i++) {
        peeked.add(bag[seat].removeLast());
      }
      var bestIdx = -1;
      var bestVal = -1;
      for (var i = 0; i < peeked.length; i++) {
        if (peeked[i].color != 'white' && peeked[i].val > bestVal) {
          bestVal = peeked[i].val;
          bestIdx = i;
        }
      }
      if (bestIdx >= 0) {
        final bonus = peeked.removeAt(bestIdx);
        for (final rem in peeked) {
          bag[seat].add(rem);
        }
        bag[seat] = shuffled(bag[seat], rng);
        cauldron[seat].add(bonus);
        pos[seat] = min(33, pos[seat] + bonus.val);
      } else {
        for (final rem in peeked) {
          bag[seat].add(rem);
        }
        bag[seat] = shuffled(bag[seat], rng);
      }
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat < 0 || seat >= players) throw GameError('无效座位');

    final type = asStr(action['type']);
    if (phase == 'brew') {
      if (stopped[seat] || exploded[seat]) {
        throw GameError('你本轮已结束熬药');
      }
      switch (type) {
        case 'draw':
          if (bag[seat].isEmpty) {
            stopped[seat] = true;
            lastAction = '${name(seat)} 药袋已空，停止熬药';
          } else {
            final chip = bag[seat].removeLast();
            _placeChipInPot(seat, chip);
            if (exploded[seat]) {
              lastAction = '${name(seat)} 抽出了【${quacksColorNames[chip.color]} ${chip.val}】，白片总和 ${whiteSum[seat]} > 7，大锅爆炸！';
            } else {
              if (bag[seat].isEmpty) stopped[seat] = true;
              lastAction = '${name(seat)} 抽出了【${quacksColorNames[chip.color]} ${chip.val}】，前进至 ${pos[seat]} 格';
            }
          }
          _advanceBrewTurn(seat);

        case 'use_flask':
          if (!flaskFull[seat]) throw GameError('药瓶已空，无法使用');
          if (exploded[seat]) throw GameError('已经炸锅，无法使用药瓶');
          if (cauldron[seat].isEmpty || cauldron[seat].last.color != 'white') {
            throw GameError('只能对刚抽出的白色樱桃炸弹使用药瓶');
          }
          final lastChip = cauldron[seat].removeLast();
          whiteSum[seat] = max(0, whiteSum[seat] - lastChip.val);
          pos[seat] = max(droplet[seat], pos[seat] - lastChip.val);
          bag[seat].add(lastChip);
          bag[seat] = shuffled(bag[seat], rng);
          flaskFull[seat] = false;
          lastAction = '${name(seat)} 使用药瓶，将【白色炸弹 ${lastChip.val}】退回袋中！';

        case 'stop':
          stopped[seat] = true;
          lastAction = '${name(seat)} 见好就收，停在 ${pos[seat]} 格';
          _advanceBrewTurn(seat);

        default:
          throw GameError('熬药阶段不支持的操作: $type');
      }
    } else if (phase == 'shop') {
      if (shopDone[seat]) throw GameError('你已完成本轮结算与采购');
      switch (type) {
        case 'choose_explosion':
          if (!exploded[seat]) throw GameError('你本轮未炸锅，无需二选一');
          if (explosionResolved[seat]) throw GameError('你已做出炸锅选择');
          final choice = asStr(action['choice']);
          if (choice != 'vp' && choice != 'coins') {
            throw GameError('请选择 vp（分数）或 coins（采购金币）');
          }
          final spot = pos[seat].clamp(0, 33);
          if (choice == 'vp') {
            vp[seat] += quacksTrackVp[spot];
            coins[seat] = 0;
            lastAction = '${name(seat)} 炸锅后选择获得 ${quacksTrackVp[spot]} 分';
          } else {
            coins[seat] = quacksTrackCoins[spot];
            lastAction = '${name(seat)} 炸锅后选择获得 ${quacksTrackCoins[spot]} 采购金币';
          }
          explosionResolved[seat] = true;

        case 'buy':
          if (!explosionResolved[seat]) throw GameError('请先决定炸锅结算方式');
          if (boughtCount[seat] >= 2) throw GameError('每轮最多购买 2 枚药片');
          final color = asStr(action['color']);
          final val = asInt(action['val'], 1);
          if (!quacksShopColors.contains(color)) throw GameError('无效的药片颜色: $color');
          if (val != 1 && val != 2 && val != 4) throw GameError('只能购买点数为 1、2 或 4 的彩色药片');
          if (boughtColors[seat].contains(color)) throw GameError('同一轮不能购买两枚相同颜色的药片');
          final price = quacksChipPrice(color, val);
          if (coins[seat] < price) throw GameError('采购金币不足（需要 $price 金币）');
          coins[seat] -= price;
          final newChip = QuacksChip(color, val);
          ownedChips[seat].add(newChip);
          bag[seat].add(newChip);
          boughtCount[seat]++;
          boughtColors[seat].add(color);
          lastAction = '${name(seat)} 购买了【${quacksColorNames[color]} $val】';

        case 'spend_rubies':
          if (rubies[seat] < 2) throw GameError('需要至少 2 颗红宝石');
          final target = asStr(action['target'], 'droplet');
          if (target == 'droplet') {
            if (droplet[seat] >= 33) throw GameError('水滴标记已达终点');
            rubies[seat] -= 2;
            droplet[seat]++;
            lastAction = '${name(seat)} 花费 2 颗红宝石将水滴起点推进至 ${droplet[seat]} 格';
          } else if (target == 'flask') {
            if (flaskFull[seat]) throw GameError('药瓶已经是满的');
            rubies[seat] -= 2;
            flaskFull[seat] = true;
            lastAction = '${name(seat)} 花费 2 颗红宝石灌满了药瓶';
          } else {
            throw GameError('无效的红宝石兑换项: $target');
          }

        case 'end_shop':
        case 'done':
        case 'pass':
          if (!explosionResolved[seat]) {
            final spot = pos[seat].clamp(0, 33);
            if (round >= maxRounds) {
              vp[seat] += quacksTrackVp[spot];
            } else {
              coins[seat] = quacksTrackCoins[spot];
            }
            explosionResolved[seat] = true;
          }
          shopDone[seat] = true;
          lastAction = '${name(seat)} 完成了采购阶段';
          _advanceShopTurn(seat);

        default:
          throw GameError('采购阶段不支持的操作: $type');
      }
    }
  }

  void _advanceBrewTurn(int actedSeat) {
    for (var i = 1; i <= players; i++) {
      final next = (actedSeat + i) % players;
      if (!stopped[next] && !exploded[next]) {
        turn = next;
        return;
      }
    }
    // All players have finished brewing! Enter shop phase.
    _enterShopPhase();
  }

  void _enterShopPhase() {
    phase = 'shop';
    // Bonus die for non-exploded player(s) with highest pos
    var maxPos = -1;
    for (var s = 0; s < players; s++) {
      if (!exploded[s] && pos[s] > maxPos) {
        maxPos = pos[s];
      }
    }
    for (var s = 0; s < players; s++) {
      if (!exploded[s] && maxPos >= 0 && pos[s] == maxPos) {
        // Winner of bonus die gets +1 VP and +1 Ruby
        vp[s] += 1;
        rubies[s] += 1;
      }
      // Green spider bonus: last 2 chips in cauldron
      final pot = cauldron[s];
      for (var i = max(0, pot.length - 2); i < pot.length; i++) {
        if (pot[i].color == 'green') {
          rubies[s]++;
        }
      }
      // Purple bonus
      final purples = pot.where((c) => c.color == 'purple').length;
      if (purples == 1) {
        vp[s] += 1;
      } else if (purples == 2) {
        vp[s] += 1;
        rubies[s] += 1;
      } else if (purples >= 3) {
        vp[s] += 2;
        droplet[s] = min(33, droplet[s] + 1);
      }
      // Track Ruby spot
      final spot = pos[s].clamp(0, 33);
      if (quacksTrackRubySpots.contains(spot)) {
        rubies[s]++;
      }
      if (!exploded[s]) {
        vp[s] += quacksTrackVp[spot];
        coins[s] = quacksTrackCoins[spot];
        explosionResolved[s] = true;
      } else {
        coins[s] = 0;
        explosionResolved[s] = false;
      }
      boughtCount[s] = 0;
      boughtColors[s].clear();
      shopDone[s] = false;
    }
    turn = 0;
  }

  void _advanceShopTurn(int actedSeat) {
    for (var i = 1; i <= players; i++) {
      final next = (actedSeat + i) % players;
      if (!shopDone[next]) {
        turn = next;
        return;
      }
    }
    // All players finished shopping!
    if (round >= maxRounds) {
      for (var s = 0; s < players; s++) {
        vp[s] += coins[s] ~/ 5;
        vp[s] += rubies[s] ~/ 2;
      }
      over = true;
      host.log('奎德林堡的庸医结束！最终得分：${[for (var s = 0; s < players; s++) '${name(s)} ${vp[s]}分'].join('，')}');
      return;
    }

    round++;
    phase = 'brew';
    turn = (round - 1) % players;
    for (var s = 0; s < players; s++) {
      bag[s] = shuffled(ownedChips[s], rng);
      cauldron[s].clear();
      pos[s] = droplet[s];
      whiteSum[s] = 0;
      exploded[s] = false;
      stopped[s] = false;
      coins[s] = 0;
      explosionResolved[s] = false;
      boughtCount[s] = 0;
      boughtColors[s].clear();
      shopDone[s] = false;
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'round': round,
      'maxRounds': maxRounds,
      'phase': phase,
      'turn': waitingFor.isEmpty ? turn : waitingFor.first,
      'over': over,
      'lastAction': lastAction,
      'droplet': droplet,
      'pos': pos,
      'whiteSum': whiteSum,
      'exploded': exploded,
      'stopped': stopped,
      'flaskFull': flaskFull,
      'rubies': rubies,
      'vp': vp,
      'scores': vp,
      'coins': coins,
      'explosionResolved': explosionResolved,
      'boughtCount': boughtCount,
      'boughtColors': [for (var s = 0; s < players; s++) boughtColors[s].toList()],
      'shopDone': shopDone,
      'cauldron': [
        for (var s = 0; s < players; s++) [for (final c in cauldron[s]) c.toJson()],
      ],
      'bagCounts': [for (var s = 0; s < players; s++) bag[s].length],
      'ownedChips': [
        for (var s = 0; s < players; s++) [for (final c in ownedChips[s]) c.toJson()],
      ],
      'trackCoins': quacksTrackCoins,
      'trackVp': quacksTrackVp,
      'trackRubySpots': quacksTrackRubySpots.toList(),
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over) return null;
    if (phase == 'brew') {
      if (stopped[seat] || exploded[seat]) return null;
      // If just drew a large white chip and flask is full and whiteSum >= 5, use flask
      if (flaskFull[seat] &&
          cauldron[seat].isNotEmpty &&
          cauldron[seat].last.color == 'white' &&
          cauldron[seat].last.val >= 2 &&
          whiteSum[seat] >= 5) {
        return {'type': 'use_flask'};
      }
      // Calculate bust risk from remaining white chips in bag
      if (bag[seat].isEmpty) return {'type': 'stop'};
      final limit = 7 - whiteSum[seat];
      if (limit <= 1 && pos[seat] >= droplet[seat] + 4) {
        return {'type': 'stop'};
      }
      if (limit <= 2 && pos[seat] >= droplet[seat] + 8 && botLevel >= 1) {
        return {'type': 'stop'};
      }
      return {'type': 'draw'};
    } else {
      if (shopDone[seat]) return null;
      if (!explosionResolved[seat]) {
        return {
          'type': 'choose_explosion',
          'choice': round >= maxRounds ? 'vp' : 'coins',
        };
      }
      // Try buying best affordable chip
      if (boughtCount[seat] < 2 && round < maxRounds) {
        for (final val in const [4, 2, 1]) {
          for (final color in const ['blue', 'yellow', 'purple', 'red', 'green', 'orange']) {
            if (!boughtColors[seat].contains(color)) {
              final price = quacksChipPrice(color, val);
              if (coins[seat] >= price) {
                return {'type': 'buy', 'color': color, 'val': val};
              }
            }
          }
        }
      }
      if (rubies[seat] >= 2) {
        if (!flaskFull[seat] && round < maxRounds) {
          return {'type': 'spend_rubies', 'target': 'flask'};
        }
        if (droplet[seat] < 33 && round < maxRounds) {
          return {'type': 'spend_rubies', 'target': 'droplet'};
        }
      }
      return {'type': 'end_shop'};
    }
  }
}
