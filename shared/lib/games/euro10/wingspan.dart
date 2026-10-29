import 'dart:math';

import '../../src/engine.dart';

/// 5 Food types in Wingspan:
/// 0: 昆虫 🐛, 1: 种子 🌾, 2: 鱼类 🐟, 3: 浆果 🍒, 4: 啮齿鼠 🐁
const List<String> wsFoodNames = ['昆虫', '种子', '鱼类', '浆果', '啮齿鼠'];
const List<String> wsFoodEmojis = ['🐛', '🌾', '🐟', '🍒', '🐁'];

/// 3 Habitat rows:
/// 0: 森林 Forest, 1: 草原 Grassland, 2: 湿地 Wetland
const List<String> wsHabitatNames = ['森林', '草原', '湿地'];

/// Egg cost by column index 0..4
const List<int> wsEggCosts = [0, 1, 1, 2, 2];

class BirdCard {
  final int id;
  final String name;
  final List<int> habitats; // subset of [0, 1, 2]
  final List<int> foodCost; // length 5: [insect, seed, fish, berry, rodent]
  final int vp;
  final String nestType; // 'bowl', 'cavity', 'ground', 'platform', 'star'
  final int eggCap;
  final int wingspanCm;
  final String powerType; // 'none', 'on_play', 'brown'
  final String powerCode;
  final String powerDesc;

  const BirdCard({
    required this.id,
    required this.name,
    required this.habitats,
    required this.foodCost,
    required this.vp,
    required this.nestType,
    required this.eggCap,
    required this.wingspanCm,
    required this.powerType,
    required this.powerCode,
    required this.powerDesc,
  });

  int get totalFoodCost => foodCost.fold(0, (a, b) => a + b);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'habitats': habitats,
        'foodCost': foodCost,
        'vp': vp,
        'nestType': nestType,
        'eggCap': eggCap,
        'wingspanCm': wingspanCm,
        'powerType': powerType,
        'powerCode': powerCode,
        'powerDesc': powerDesc,
      };
}

class PlacedBird {
  final int cardId;
  int eggs;
  int cachedFood;
  int tuckedCards;

  PlacedBird({
    required this.cardId,
    this.eggs = 0,
    this.cachedFood = 0,
    this.tuckedCards = 0,
  });

  BirdCard get card => wsBirds[cardId];

  Map<String, dynamic> toJson() => {
        ...card.toJson(),
        'cardId': cardId,
        'eggs': eggs,
        'cachedFood': cachedFood,
        'tuckedCards': tuckedCards,
      };
}

class WsRoundGoal {
  final String id;
  final String name;
  final String desc;
  const WsRoundGoal(this.id, this.name, this.desc);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'desc': desc};
}

const List<WsRoundGoal> wsRoundGoalsCatalog = [
  WsRoundGoal('hab_0', '森林繁茂', '森林栖息地中的鸟类数量（每只 1 分，最高 5 分）'),
  WsRoundGoal('hab_1', '草原牧歌', '草原栖息地中的鸟类数量（每只 1 分，最高 5 分）'),
  WsRoundGoal('hab_2', '湿地水禽', '湿地栖息地中的鸟类数量（每只 1 分，最高 5 分）'),
  WsRoundGoal('nest_bowl', '碗状鸟巢', '碗状巢（含星型巢）鸟类上的鸟蛋总数（每个 1 分，最高 5 分）'),
  WsRoundGoal('nest_cavity', '树洞秘境', '洞穴巢（含星型巢）鸟类上的鸟蛋总数（每个 1 分，最高 5 分）'),
  WsRoundGoal('nest_ground', '大地育雏', '地面巢（含星型巢）鸟类上的鸟蛋总数（每个 1 分，最高 5 分）'),
  WsRoundGoal('nest_platform', '高台筑巢', '平台巢（含星型巢）鸟类上的鸟蛋总数（每个 1 分，最高 5 分）'),
  WsRoundGoal('birds_with_eggs', '繁衍生息', '至少拥有 1 枚鸟蛋的鸟类数量（每只 1 分，最高 5 分）'),
];

const List<BirdCard> wsBirds = [
  BirdCard(
    id: 0,
    name: '北美红雀',
    habitats: [0],
    foodCost: [0, 1, 0, 1, 0],
    vp: 3,
    nestType: 'bowl',
    eggCap: 4,
    wingspanCm: 31,
    powerType: 'brown',
    powerCode: 'gain_berry',
    powerDesc: '激活时：从供应堆获得 1 个🍒浆果。',
  ),
  BirdCard(
    id: 1,
    name: '蓝松鸦',
    habitats: [0],
    foodCost: [0, 1, 0, 0, 0],
    vp: 3,
    nestType: 'bowl',
    eggCap: 3,
    wingspanCm: 41,
    powerType: 'brown',
    powerCode: 'cache_seed',
    powerDesc: '激活时：在这只鸟上储存 1 个🌾种子（+1 分）。',
  ),
  BirdCard(
    id: 2,
    name: '绒啄木鸟',
    habitats: [0],
    foodCost: [1, 0, 0, 1, 0],
    vp: 4,
    nestType: 'cavity',
    eggCap: 4,
    wingspanCm: 30,
    powerType: 'on_play',
    powerCode: 'play_insect2',
    powerDesc: '打出时：获得 2 个🐛昆虫。',
  ),
  BirdCard(
    id: 3,
    name: '黑顶山雀',
    habitats: [0],
    foodCost: [1, 0, 0, 0, 0],
    vp: 2,
    nestType: 'cavity',
    eggCap: 5,
    wingspanCm: 21,
    powerType: 'brown',
    powerCode: 'cache_seed',
    powerDesc: '激活时：在这只鸟上储存 1 个🌾种子（+1 分）。',
  ),
  BirdCard(
    id: 4,
    name: '红胸鳾',
    habitats: [0],
    foodCost: [1, 1, 0, 0, 0],
    vp: 4,
    nestType: 'cavity',
    eggCap: 5,
    wingspanCm: 20,
    powerType: 'brown',
    powerCode: 'cache_insect',
    powerDesc: '激活时：在这只鸟上储存 1 个🐛昆虫（+1 分）。',
  ),
  BirdCard(
    id: 5,
    name: '白头海雕',
    habitats: [2],
    foodCost: [0, 0, 2, 0, 1],
    vp: 9,
    nestType: 'platform',
    eggCap: 2,
    wingspanCm: 203,
    powerType: 'on_play',
    powerCode: 'play_fish2',
    powerDesc: '打出时：获得 2 个🐟鱼类。',
  ),
  BirdCard(
    id: 6,
    name: '大蓝鹭',
    habitats: [2],
    foodCost: [1, 0, 1, 0, 0],
    vp: 5,
    nestType: 'platform',
    eggCap: 3,
    wingspanCm: 183,
    powerType: 'on_play',
    powerCode: 'play_draw2',
    powerDesc: '打出时：抽 2 张鸟类牌。',
  ),
  BirdCard(
    id: 7,
    name: '绿头鸭',
    habitats: [2],
    foodCost: [1, 1, 0, 0, 0],
    vp: 3,
    nestType: 'ground',
    eggCap: 5,
    wingspanCm: 89,
    powerType: 'brown',
    powerCode: 'draw_1',
    powerDesc: '激活时：抽 1 张鸟类牌。',
  ),
  BirdCard(
    id: 8,
    name: '加拿大雁',
    habitats: [1, 2],
    foodCost: [0, 2, 0, 0, 0],
    vp: 3,
    nestType: 'ground',
    eggCap: 4,
    wingspanCm: 152,
    powerType: 'brown',
    powerCode: 'tuck_1',
    powerDesc: '激活时：在这只鸟下塞入 1 张牌（+1 分）并获得 1 个🌾种子。',
  ),
  BirdCard(
    id: 9,
    name: '北美旅鸫',
    habitats: [0, 1],
    foodCost: [1, 0, 0, 1, 0],
    vp: 3,
    nestType: 'bowl',
    eggCap: 4,
    wingspanCm: 43,
    powerType: 'brown',
    powerCode: 'lay_1',
    powerDesc: '激活时：在任意鸟上产下 1 枚鸟蛋。',
  ),
  BirdCard(
    id: 10,
    name: '谷仓猫头鹰',
    habitats: [0, 1, 2],
    foodCost: [0, 0, 0, 0, 2],
    vp: 5,
    nestType: 'cavity',
    eggCap: 4,
    wingspanCm: 107,
    powerType: 'brown',
    powerCode: 'cache_rodent',
    powerDesc: '激活时：在这只鸟上储存 1 个🐁啮齿鼠（+1 分）。',
  ),
  BirdCard(
    id: 11,
    name: '林鸳鸯',
    habitats: [0, 2],
    foodCost: [0, 1, 0, 1, 0],
    vp: 4,
    nestType: 'cavity',
    eggCap: 4,
    wingspanCm: 74,
    powerType: 'on_play',
    powerCode: 'play_draw2',
    powerDesc: '打出时：抽 2 张鸟类牌。',
  ),
  BirdCard(
    id: 12,
    name: '红喉蜂鸟',
    habitats: [0, 1, 2],
    foodCost: [0, 0, 0, 1, 0],
    vp: 2,
    nestType: 'bowl',
    eggCap: 2,
    wingspanCm: 10,
    powerType: 'brown',
    powerCode: 'gain_any',
    powerDesc: '激活时：从喂鸟器获得 1 个食物。',
  ),
  BirdCard(
    id: 13,
    name: '游隼',
    habitats: [1, 2],
    foodCost: [1, 0, 0, 0, 1],
    vp: 5,
    nestType: 'platform',
    eggCap: 2,
    wingspanCm: 104,
    powerType: 'brown',
    powerCode: 'tuck_1',
    powerDesc: '激活时：捕猎成功，在这只鸟下塞入 1 张牌（+1 分）。',
  ),
  BirdCard(
    id: 14,
    name: '渡鸦',
    habitats: [0, 1, 2],
    foodCost: [1, 1, 0, 0, 1],
    vp: 5,
    nestType: 'platform',
    eggCap: 3,
    wingspanCm: 130,
    powerType: 'brown',
    powerCode: 'raven_food',
    powerDesc: '激活时：获得 1 个🌾种子与 1 个🍒浆果。',
  ),
  BirdCard(
    id: 15,
    name: '大雕鸮',
    habitats: [0],
    foodCost: [0, 0, 0, 0, 2],
    vp: 7,
    nestType: 'platform',
    eggCap: 2,
    wingspanCm: 127,
    powerType: 'brown',
    powerCode: 'cache_rodent',
    powerDesc: '激活时：在这只鸟上储存 1 个🐁啮齿鼠（+1 分）。',
  ),
  BirdCard(
    id: 16,
    name: '西草地鹨',
    habitats: [1],
    foodCost: [1, 1, 0, 0, 0],
    vp: 4,
    nestType: 'ground',
    eggCap: 4,
    wingspanCm: 38,
    powerType: 'brown',
    powerCode: 'lay_1',
    powerDesc: '激活时：产下 1 枚鸟蛋。',
  ),
  BirdCard(
    id: 17,
    name: '哀鸠',
    habitats: [0, 1],
    foodCost: [0, 1, 0, 0, 0],
    vp: 2,
    nestType: 'platform',
    eggCap: 5,
    wingspanCm: 46,
    powerType: 'brown',
    powerCode: 'lay_1',
    powerDesc: '激活时：在这只鸟或任意鸟上产下 1 枚鸟蛋。',
  ),
  BirdCard(
    id: 18,
    name: '带鱼狗（北美翠鸟）',
    habitats: [2],
    foodCost: [0, 0, 1, 0, 0],
    vp: 4,
    nestType: 'cavity',
    eggCap: 4,
    wingspanCm: 51,
    powerType: 'brown',
    powerCode: 'gain_fish',
    powerDesc: '激活时：获得 1 个🐟鱼类。',
  ),
  BirdCard(
    id: 19,
    name: '美洲白鹈鹕',
    habitats: [2],
    foodCost: [0, 0, 2, 0, 0],
    vp: 6,
    nestType: 'ground',
    eggCap: 2,
    wingspanCm: 274,
    powerType: 'brown',
    powerCode: 'tuck_1',
    powerDesc: '激活时：在这只鸟下塞入 1 张牌（+1 分）。',
  ),
  BirdCard(
    id: 20,
    name: '鱼鹰',
    habitats: [2],
    foodCost: [0, 0, 1, 0, 0],
    vp: 5,
    nestType: 'platform',
    eggCap: 3,
    wingspanCm: 160,
    powerType: 'brown',
    powerCode: 'gain_fish',
    powerDesc: '激活时：获得 1 个🐟鱼类。',
  ),
  BirdCard(
    id: 21,
    name: '黑嘴喜鹊',
    habitats: [1],
    foodCost: [1, 0, 0, 1, 0],
    vp: 3,
    nestType: 'bowl',
    eggCap: 4,
    wingspanCm: 61,
    powerType: 'brown',
    powerCode: 'gain_insect',
    powerDesc: '激活时：获得 1 个🐛昆虫。',
  ),
  BirdCard(
    id: 22,
    name: '红尾鵟',
    habitats: [0, 1],
    foodCost: [0, 0, 0, 0, 2],
    vp: 6,
    nestType: 'platform',
    eggCap: 2,
    wingspanCm: 124,
    powerType: 'brown',
    powerCode: 'cache_rodent',
    powerDesc: '激活时：在这只鸟上储存 1 个🐁啮齿鼠（+1 分）。',
  ),
  BirdCard(
    id: 23,
    name: '大草原榛鸡',
    habitats: [1],
    foodCost: [0, 2, 0, 1, 0],
    vp: 6,
    nestType: 'ground',
    eggCap: 4,
    wingspanCm: 71,
    powerType: 'on_play',
    powerCode: 'play_lay3',
    powerDesc: '打出时：在你的鸟类上产下 3 枚鸟蛋。',
  ),
  BirdCard(
    id: 24,
    name: '野火鸡',
    habitats: [0, 1],
    foodCost: [0, 2, 0, 1, 0],
    vp: 8,
    nestType: 'ground',
    eggCap: 5,
    wingspanCm: 145,
    powerType: 'none',
    powerCode: 'none',
    powerDesc: '无特殊能力（高分巨鸟）。',
  ),
  BirdCard(
    id: 25,
    name: '白冠带鹀',
    habitats: [0, 1],
    foodCost: [1, 1, 0, 0, 0],
    vp: 3,
    nestType: 'ground',
    eggCap: 5,
    wingspanCm: 24,
    powerType: 'brown',
    powerCode: 'gain_seed',
    powerDesc: '激活时：获得 1 个🌾种子。',
  ),
  BirdCard(
    id: 26,
    name: '家朱雀',
    habitats: [0, 1],
    foodCost: [0, 1, 0, 1, 0],
    vp: 3,
    nestType: 'star',
    eggCap: 5,
    wingspanCm: 25,
    powerType: 'on_play',
    powerCode: 'play_lay2',
    powerDesc: '打出时：产下 2 枚鸟蛋。',
  ),
  BirdCard(
    id: 27,
    name: '美洲金翅雀',
    habitats: [1],
    foodCost: [0, 2, 0, 0, 0],
    vp: 3,
    nestType: 'bowl',
    eggCap: 4,
    wingspanCm: 23,
    powerType: 'brown',
    powerCode: 'tuck_1',
    powerDesc: '激活时：在这只鸟下塞入 1 张牌（+1 分）。',
  ),
  BirdCard(
    id: 28,
    name: '雪鸮',
    habitats: [1, 2],
    foodCost: [0, 0, 1, 0, 1],
    vp: 6,
    nestType: 'ground',
    eggCap: 3,
    wingspanCm: 147,
    powerType: 'on_play',
    powerCode: 'play_draw2',
    powerDesc: '打出时：抽 2 张鸟类牌并获得 1 个🐁啮齿鼠。',
  ),
  BirdCard(
    id: 29,
    name: '美洲鹤',
    habitats: [1, 2],
    foodCost: [1, 1, 1, 0, 0],
    vp: 8,
    nestType: 'ground',
    eggCap: 2,
    wingspanCm: 221,
    powerType: 'none',
    powerCode: 'none',
    powerDesc: '无特殊能力（珍稀高分水鸟）。',
  ),
  BirdCard(
    id: 30,
    name: '东蓝鸲',
    habitats: [1],
    foodCost: [1, 0, 0, 1, 0],
    vp: 4,
    nestType: 'cavity',
    eggCap: 5,
    wingspanCm: 33,
    powerType: 'on_play',
    powerCode: 'play_lay2',
    powerDesc: '打出时：产下 2 枚鸟蛋。',
  ),
  BirdCard(
    id: 31,
    name: '双领鸻',
    habitats: [1, 2],
    foodCost: [1, 0, 0, 0, 0],
    vp: 2,
    nestType: 'ground',
    eggCap: 4,
    wingspanCm: 46,
    powerType: 'brown',
    powerCode: 'draw_1',
    powerDesc: '激活时：抽 1 张鸟类牌。',
  ),
  BirdCard(
    id: 32,
    name: '粉红琵鹭',
    habitats: [2],
    foodCost: [1, 0, 1, 0, 0],
    vp: 6,
    nestType: 'platform',
    eggCap: 3,
    wingspanCm: 127,
    powerType: 'on_play',
    powerCode: 'play_draw2',
    powerDesc: '打出时：抽 2 张鸟类牌。',
  ),
  BirdCard(
    id: 33,
    name: '北美山鹑',
    habitats: [1],
    foodCost: [0, 1, 0, 0, 0],
    vp: 2,
    nestType: 'ground',
    eggCap: 6,
    wingspanCm: 33,
    powerType: 'brown',
    powerCode: 'lay_1',
    powerDesc: '激活时：在这只鸟上产下 1 枚鸟蛋。',
  ),
  BirdCard(
    id: 34,
    name: '树燕',
    habitats: [1, 2],
    foodCost: [1, 0, 0, 0, 0],
    vp: 2,
    nestType: 'star',
    eggCap: 4,
    wingspanCm: 38,
    powerType: 'brown',
    powerCode: 'tuck_1',
    powerDesc: '激活时：在这只鸟下塞入 1 张牌（+1 分）。',
  ),
  BirdCard(
    id: 35,
    name: '星鸦',
    habitats: [0],
    foodCost: [0, 2, 0, 0, 0],
    vp: 5,
    nestType: 'platform',
    eggCap: 3,
    wingspanCm: 61,
    powerType: 'brown',
    powerCode: 'cache_seed',
    powerDesc: '激活时：在这只鸟上储存 1 个🌾种子（+1 分）。',
  ),
];

const String wingspanRules = '''
# 展翅翱翔 (Wingspan)

## 游戏简介
《展翅翱翔》是一款屡获殊荣的鸟类栖息地引擎构筑策略桌游。玩家扮演鸟类爱好者、研究员与保育员，通过吸引各具特色的鸟类入住自己的自然保护区，构建强大的生态联动引擎。

## 核心组件与资源
- **5 种食物类型**：0 昆虫 🐛、1 种子 🌾、2 鱼类 🐟、3 浆果 🍒、4 啮齿鼠 🐁。
- **喂鸟器 (Birdfeeder)**：包含 5 颗食物骰子，从中获取食物；若喂鸟器为空或全部骰面相同，将自动重掷补满 5 颗。
- **鸟类展示托盘 (Bird Tray)**：始终展示 3 张明置鸟类牌供抽取。
- **3 大栖息地行**：
  - **0 森林 (Forest)**：执行【获取食物】行动，并从右向左依次触发本行所有鸟类的褐色激活能力。
  - **1 草原 (Grassland)**：执行【产下鸟蛋】行动，并从右向左依次触发本行所有鸟类的褐色激活能力。
  - **2 湿地 (Wetland)**：执行【抽取鸟牌】行动，并从右向左依次触发本行所有鸟类的褐色激活能力。
  每个栖息地最多容纳 5 只鸟，第 1~5 格的鸟蛋费用依次为 `[0, 1, 1, 2, 2]` 枚鸟蛋。

## 回合行动（四选一）
每轮玩家拥有固定数量的行动方块（标准 4 轮依次为 `[8, 7, 6, 5]` 个，快速 3 轮依次为 `[7, 6, 5]` 个）。每回合消耗 1 个行动方块执行以下 4 项行动之一：
1. **打出鸟牌 (`play_bird`)**：支付手牌中某张鸟牌所需的食物费用及对应栖息地槽位的鸟蛋费用，将其放入对应栖息地，并立即触发其【打出时 (`on_play`)】能力。
2. **获取食物 (`gain_food`)**：从喂鸟器拿取 `1 + 森林鸟数 ~/ 2` 个食物，随后从右向左依次激活森林行所有褐色鸟类能力。
3. **产下鸟蛋 (`lay_eggs`)**：在你的鸟类上放置 `2 + 草原鸟数 ~/ 2` 枚鸟蛋（不超过每只鸟的鸟巢上限），随后从右向左依次激活草原行所有褐色鸟类能力。
4. **抽取鸟牌 (`draw_cards`)**：从托盘或牌库抽取 `1 + 湿地鸟数 ~/ 2` 张鸟类牌，随后从右向左依次激活湿地行所有褐色鸟类能力。

## 终局计分
游戏在所有轮次结束后结算总分，总分最高者获胜：
- **鸟类羽毛分**：保护区中所有已打出鸟类的牌面基础分数之和。
- **轮次目标分**：每轮结束时根据该轮保育目标（栖息地鸟数或特定鸟巢鸟蛋数）获得的分数。
- **鸟蛋分**：保护区鸟类上剩余的每枚鸟蛋 1 分。
- **储存食物分**：鸟类卡牌上储存的每个食物 (`cachedFood`) 1 分。
- **塞入鸟群分**：鸟类卡牌下塞入的每张鸟牌 (`tuckedCards`) 1 分。
''';

class Wingspan extends GameEngine {
  Wingspan(super.setup);

  late int maxRounds;
  late List<int> roundCubes;
  int round = 1;
  int firstPlayer = 0;
  int turn = 0;
  bool over = false;

  List<int> deck = [];
  List<int> tray = [];
  List<int> birdfeeder = [];
  List<WsRoundGoal> roundGoals = [];

  late List<List<int>> hand;
  late List<List<int>> food; // food[seat][0..4]
  late List<List<List<PlacedBird>>> preserve; // preserve[seat][hab 0..2]
  late List<int> cubesLeft;
  late List<List<int>> roundGoalScores;
  String lastAction = '游戏开始';

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore([for (var s = 0; s < players; s++) scoreOf(s)]) : null;

  @override
  void start() {
    maxRounds = setup.opt<int>('rounds', 4);
    roundCubes = maxRounds == 3 ? [7, 6, 5] : [8, 7, 6, 5];

    // Build deck (2 copies of each bird card so 5-player games have plenty of cards)
    deck = shuffled([
      for (var i = 0; i < wsBirds.length; i++) i,
      for (var i = 0; i < wsBirds.length; i++) i,
    ], rng);

    roundGoals = shuffled(wsRoundGoalsCatalog, rng).take(maxRounds).toList();
    rerollBirdfeeder();
    tray = [];
    refillTray();

    hand = List.generate(players, (_) => <int>[]);
    food = List.generate(players, (_) => [1, 1, 1, 1, 1]);
    preserve = List.generate(players, (_) => [<PlacedBird>[], <PlacedBird>[], <PlacedBird>[]]);
    cubesLeft = List.filled(players, roundCubes[0]);
    roundGoalScores = List.generate(players, (_) => List.filled(maxRounds, 0));

    for (var s = 0; s < players; s++) {
      for (var i = 0; i < 4; i++) {
        hand[s].add(_drawFromDeck());
      }
      // Guarantee at least 1 inexpensive playable bird in starting hand
      final cheapIds = [0, 1, 3, 7, 12, 17, 18, 20, 31, 33, 34];
      hand[s].add(cheapIds[rng.nextInt(cheapIds.length)]);
    }
    firstPlayer = 0;
    turn = 0;
  }

  int _drawFromDeck() {
    if (deck.isEmpty) {
      deck = shuffled([for (var i = 0; i < wsBirds.length; i++) i], rng);
    }
    return deck.removeLast();
  }

  void rerollBirdfeeder() {
    birdfeeder = [for (var i = 0; i < 5; i++) rng.nextInt(5)];
  }

  void refillTray() {
    while (tray.length < 3) {
      tray.add(_drawFromDeck());
    }
  }

  int totalEggs(int seat) {
    var sum = 0;
    for (final row in preserve[seat]) {
      for (final b in row) {
        sum += b.eggs;
      }
    }
    return sum;
  }

  int remainingEggSpace(int seat) {
    var space = 0;
    for (final row in preserve[seat]) {
      for (final b in row) {
        space += max(0, b.card.eggCap - b.eggs);
      }
    }
    return space;
  }

  bool canPayFood(int seat, BirdCard card) {
    var deficit = 0;
    var surplus = 0;
    for (var f = 0; f < 5; f++) {
      final have = food[seat][f];
      final need = card.foodCost[f];
      if (have >= need) {
        surplus += have - need;
      } else {
        deficit += need - have;
      }
    }
    // Exact match or 2-for-1 food substitution as in Wingspan rules
    return surplus >= deficit * 2;
  }

  void _payFood(int seat, BirdCard card) {
    var deficit = 0;
    for (var f = 0; f < 5; f++) {
      final have = food[seat][f];
      final need = card.foodCost[f];
      if (have >= need) {
        food[seat][f] -= need;
      } else {
        deficit += need - have;
        food[seat][f] = 0;
      }
    }
    var toPay = deficit * 2;
    for (var f = 0; f < 5 && toPay > 0; f++) {
      final take = min(food[seat][f], toPay);
      food[seat][f] -= take;
      toPay -= take;
    }
  }

  void _payEggs(int seat, int count) {
    var left = count;
    for (final row in preserve[seat]) {
      for (final b in row) {
        if (left <= 0) return;
        final take = min(b.eggs, left);
        b.eggs -= take;
        left -= take;
      }
    }
  }

  void _addEggs(int seat, int count) {
    var left = count;
    for (final row in preserve[seat]) {
      for (final b in row) {
        if (left <= 0) return;
        final room = b.card.eggCap - b.eggs;
        if (room > 0) {
          final add = min(room, left);
          b.eggs += add;
          left -= add;
        }
      }
    }
  }

  bool canPlayBird(int seat, int cardId, int hab) {
    if (hab < 0 || hab > 2) return false;
    final card = wsBirds[cardId];
    if (!card.habitats.contains(hab)) return false;
    final slot = preserve[seat][hab].length;
    if (slot >= 5) return false;
    final eggCost = wsEggCosts[slot];
    if (totalEggs(seat) < eggCost) return false;
    if (!canPayFood(seat, card)) return false;
    return true;
  }

  void _triggerPower(int seat, PlacedBird pb) {
    final code = pb.card.powerCode;
    switch (code) {
      case 'gain_insect':
        food[seat][0]++;
      case 'gain_seed':
        food[seat][1]++;
      case 'gain_fish':
        food[seat][2]++;
      case 'gain_berry':
        food[seat][3]++;
      case 'gain_any':
        if (birdfeeder.isEmpty) rerollBirdfeeder();
        food[seat][birdfeeder.removeAt(0)]++;
        if (birdfeeder.isEmpty) rerollBirdfeeder();
      case 'raven_food':
        food[seat][1]++;
        food[seat][3]++;
      case 'cache_insect':
      case 'cache_seed':
      case 'cache_rodent':
        pb.cachedFood++;
      case 'tuck_1':
        pb.tuckedCards++;
        if (code == 'tuck_1' && pb.card.id == 8) {
          food[seat][1]++;
        }
      case 'lay_1':
        _addEggs(seat, 1);
      case 'draw_1':
        hand[seat].add(_drawFromDeck());
      case 'play_insect2':
        food[seat][0] += 2;
      case 'play_fish2':
        food[seat][2] += 2;
      case 'play_draw2':
        hand[seat].add(_drawFromDeck());
        hand[seat].add(_drawFromDeck());
        if (pb.card.id == 28) food[seat][4]++;
      case 'play_lay2':
        _addEggs(seat, 2);
      case 'play_lay3':
        _addEggs(seat, 3);
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');
    if (cubesLeft[seat] <= 0) throw GameError('本轮已无可用行动方块');

    final type = asStr(action['type']);
    switch (type) {
      case 'play_bird':
        final hab = asInt(action['hab'], -1);
        if (hab < 0 || hab > 2) throw GameError('请选择有效的栖息地 (0..2)');
        var cardIdx = asInt(action['cardIdx'], -1);
        final cardIdParam = asInt(action['cardId'], -1);
        if (cardIdx < 0 || cardIdx >= hand[seat].length) {
          if (cardIdParam >= 0) {
            cardIdx = hand[seat].indexOf(cardIdParam);
          }
        }
        if (cardIdx < 0 || cardIdx >= hand[seat].length) {
          throw GameError('请选择有效的手牌');
        }
        final cardId = hand[seat][cardIdx];
        final card = wsBirds[cardId];
        if (!card.habitats.contains(hab)) {
          throw GameError('${card.name} 不能放置在${wsHabitatNames[hab]}');
        }
        final slot = preserve[seat][hab].length;
        if (slot >= 5) throw GameError('${wsHabitatNames[hab]}已满（最多 5 只鸟）');
        final eggCost = wsEggCosts[slot];
        if (totalEggs(seat) < eggCost) {
          throw GameError('鸟蛋不足（需要 $eggCost 枚鸟蛋）');
        }
        if (!canPayFood(seat, card)) {
          throw GameError('食物不足，无法打出 ${card.name}');
        }

        hand[seat].removeAt(cardIdx);
        _payFood(seat, card);
        _payEggs(seat, eggCost);
        final placed = PlacedBird(cardId: cardId);
        preserve[seat][hab].add(placed);
        if (card.powerType == 'on_play') {
          _triggerPower(seat, placed);
        }
        lastAction = '${name(seat)} 在${wsHabitatNames[hab]}打出了【${card.name}】';

      case 'gain_food':
        if (action['reroll'] == true && birdfeeder.toSet().length <= 1) {
          rerollBirdfeeder();
        }
        final count = 1 + preserve[seat][0].length ~/ 2;
        final requested = asIntList(action['foods']);
        for (var i = 0; i < count; i++) {
          if (birdfeeder.isEmpty) rerollBirdfeeder();
          int chosenFood;
          if (i < requested.length && birdfeeder.contains(requested[i])) {
            final f = requested[i];
            birdfeeder.remove(f);
            chosenFood = f;
          } else {
            final single = asInt(action['food'], -1);
            if (single >= 0 && birdfeeder.contains(single)) {
              birdfeeder.remove(single);
              chosenFood = single;
            } else {
              chosenFood = birdfeeder.removeAt(0);
            }
          }
          food[seat][chosenFood]++;
          if (birdfeeder.isEmpty) rerollBirdfeeder();
        }
        // Activate Forest brown powers right-to-left
        final forest = preserve[seat][0];
        for (var i = forest.length - 1; i >= 0; i--) {
          if (forest[i].card.powerType == 'brown') {
            _triggerPower(seat, forest[i]);
          }
        }
        lastAction = '${name(seat)} 在森林获取了 $count 个食物';

      case 'lay_eggs':
        final count = 2 + preserve[seat][1].length ~/ 2;
        _addEggs(seat, count);
        // Activate Grassland brown powers right-to-left
        final grassland = preserve[seat][1];
        for (var i = grassland.length - 1; i >= 0; i--) {
          if (grassland[i].card.powerType == 'brown') {
            _triggerPower(seat, grassland[i]);
          }
        }
        lastAction = '${name(seat)} 在草原产下了鸟蛋';

      case 'draw_cards':
        final count = 1 + preserve[seat][2].length ~/ 2;
        final trayReq = asIntList(action['trayIndices']);
        final singleTray = asInt(action['trayIdx'], -1);
        var drawn = 0;
        if (singleTray >= 0 && singleTray < tray.length && drawn < count) {
          hand[seat].add(tray.removeAt(singleTray));
          drawn++;
        } else if (trayReq.isNotEmpty) {
          final sorted = trayReq.where((idx) => idx >= 0 && idx < tray.length).toSet().toList()
            ..sort((a, b) => b.compareTo(a));
          for (final idx in sorted) {
            if (drawn >= count) break;
            if (idx < tray.length) {
              hand[seat].add(tray.removeAt(idx));
              drawn++;
            }
          }
        }
        while (drawn < count) {
          if (tray.isNotEmpty && action['fromTray'] == true) {
            hand[seat].add(tray.removeAt(0));
          } else {
            hand[seat].add(_drawFromDeck());
          }
          drawn++;
        }
        // Activate Wetland brown powers right-to-left
        final wetland = preserve[seat][2];
        for (var i = wetland.length - 1; i >= 0; i--) {
          if (wetland[i].card.powerType == 'brown') {
            _triggerPower(seat, wetland[i]);
          }
        }
        refillTray();
        lastAction = '${name(seat)} 在湿地抽取了 $count 张鸟类牌';

      default:
        throw GameError('未知的展翅翱翔行动: $type');
    }

    cubesLeft[seat]--;
    refillTray();
    _advanceTurn();
  }

  void _advanceTurn() {
    for (var i = 1; i <= players; i++) {
      final next = (turn + i) % players;
      if (cubesLeft[next] > 0) {
        turn = next;
        return;
      }
    }
    // Round end!
    _scoreRoundGoal(round - 1);
    if (round >= maxRounds) {
      over = true;
      host.log('展翅翱翔结束！最终得分：${[for (var s = 0; s < players; s++) '${name(s)} ${scoreOf(s)}分'].join('，')}');
      return;
    }
    round++;
    for (var s = 0; s < players; s++) {
      cubesLeft[s] = roundCubes[round - 1];
    }
    tray.clear();
    refillTray();
    firstPlayer = (firstPlayer + 1) % players;
    turn = firstPlayer;
  }

  int evaluateGoalProgress(int seat, WsRoundGoal goal) {
    switch (goal.id) {
      case 'hab_0':
        return preserve[seat][0].length;
      case 'hab_1':
        return preserve[seat][1].length;
      case 'hab_2':
        return preserve[seat][2].length;
      case 'nest_bowl':
        return _eggsInNest(seat, 'bowl');
      case 'nest_cavity':
        return _eggsInNest(seat, 'cavity');
      case 'nest_ground':
        return _eggsInNest(seat, 'ground');
      case 'nest_platform':
        return _eggsInNest(seat, 'platform');
      case 'birds_with_eggs':
        var c = 0;
        for (final row in preserve[seat]) {
          for (final b in row) {
            if (b.eggs > 0) c++;
          }
        }
        return c;
      default:
        return 0;
    }
  }

  int _eggsInNest(int seat, String nest) {
    var c = 0;
    for (final row in preserve[seat]) {
      for (final b in row) {
        if (b.card.nestType == nest || b.card.nestType == 'star') {
          c += b.eggs;
        }
      }
    }
    return c;
  }

  void _scoreRoundGoal(int rIdx) {
    if (rIdx < 0 || rIdx >= roundGoals.length) return;
    final goal = roundGoals[rIdx];
    final prog = [for (var s = 0; s < players; s++) evaluateGoalProgress(s, goal)];
    for (var s = 0; s < players; s++) {
      if (prog[s] <= 0) {
        roundGoalScores[s][rIdx] = 0;
      } else {
        final higher = prog.where((p) => p > prog[s]).length;
        final rankBonus = max(1, 4 - higher) + rIdx;
        roundGoalScores[s][rIdx] = min(5, max(prog[s], rankBonus));
      }
    }
  }

  int birdFeatherScore(int seat) {
    var s = 0;
    for (final row in preserve[seat]) {
      for (final b in row) {
        s += b.card.vp;
      }
    }
    return s;
  }

  int goalScore(int seat) => roundGoalScores[seat].fold(0, (a, b) => a + b);

  int cachedFoodScore(int seat) {
    var s = 0;
    for (final row in preserve[seat]) {
      for (final b in row) {
        s += b.cachedFood;
      }
    }
    return s;
  }

  int tuckedCardsScore(int seat) {
    var s = 0;
    for (final row in preserve[seat]) {
      for (final b in row) {
        s += b.tuckedCards;
      }
    }
    return s;
  }

  int scoreOf(int seat) =>
      birdFeatherScore(seat) +
      goalScore(seat) +
      totalEggs(seat) +
      cachedFoodScore(seat) +
      tuckedCardsScore(seat);

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'round': round,
      'maxRounds': maxRounds,
      'turn': turn,
      'firstPlayer': firstPlayer,
      'over': over,
      'lastAction': lastAction,
      'birdfeeder': birdfeeder,
      'tray': [for (final id in tray) wsBirds[id].toJson()],
      'trayIds': tray,
      'deckCount': deck.length,
      'roundGoals': [for (final g in roundGoals) g.toJson()],
      'cubesLeft': cubesLeft,
      'food': food,
      'preserve': [
        for (var s = 0; s < players; s++)
          [
            for (var h = 0; h < 3; h++) [for (final b in preserve[s][h]) b.toJson()],
          ],
      ],
      'hand': seat >= 0 && seat < players ? [for (final id in hand[seat]) wsBirds[id].toJson()] : const [],
      'handIds': seat >= 0 && seat < players ? hand[seat] : const [],
      'handCounts': [for (var s = 0; s < players; s++) hand[s].length],
      'roundGoalScores': roundGoalScores,
      'scores': [for (var s = 0; s < players; s++) scoreOf(s)],
      'breakdown': [
        for (var s = 0; s < players; s++)
          {
            'feathers': birdFeatherScore(s),
            'goals': goalScore(s),
            'eggs': totalEggs(s),
            'cached': cachedFoodScore(s),
            'tucked': tuckedCardsScore(s),
            'total': scoreOf(s),
          },
      ],
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    // Try playing the highest-VP playable bird in hand
    var bestIdx = -1;
    var bestHab = -1;
    var bestVal = -1;
    for (var i = 0; i < hand[seat].length; i++) {
      final cardId = hand[seat][i];
      final card = wsBirds[cardId];
      for (final h in card.habitats) {
        if (canPlayBird(seat, cardId, h)) {
          final val = card.vp * 2 + (card.powerType != 'none' ? 3 : 0) - preserve[seat][h].length;
          if (val > bestVal || botLevel == 0) {
            bestVal = val;
            bestIdx = i;
            bestHab = h;
          }
        }
      }
    }
    if (bestIdx >= 0) {
      return {'type': 'play_bird', 'cardIdx': bestIdx, 'hab': bestHab};
    }

    // If low on food, gain food
    final totalFood = food[seat].fold(0, (a, b) => a + b);
    if (totalFood < 3) {
      return {'type': 'gain_food'};
    }

    // If low on eggs and have birds with egg space, lay eggs
    if (totalEggs(seat) < 2 && remainingEggSpace(seat) > 0) {
      return {'type': 'lay_eggs'};
    }

    // If low on cards, draw cards
    if (hand[seat].length < 2) {
      return {'type': 'draw_cards', 'trayIdx': 0};
    }

    // Late game: lay eggs if space available, else gain food or draw cards
    if (remainingEggSpace(seat) >= 2) {
      return {'type': 'lay_eggs'};
    }
    return rng.nextBool() ? {'type': 'gain_food'} : {'type': 'draw_cards'};
  }
}
