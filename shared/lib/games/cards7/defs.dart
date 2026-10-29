import '../../src/engine.dart';
import 'arboretum.dart';
import 'briscola.dart';
import 'euchre.dart';

/// 尤克牌 / 布里斯科拉 / 植物园
final List<GameDef> cards7Games = [
  GameDef(
    id: 'euchre',
    name: '尤克牌 Euchre',
    category: '牌类',
    description: '北美经典四人搭档 24 张吃墩扑克：主花色 J 与同色 J 化身为最强的正副司令（Right/Left Bower），'
        '两轮叫主支持独打（Alone）1挑2，吃满 5 墩翻倍、被守方反噬（Euchred）倒送 2 分！',
    playerRange: (_) => (4, 4),
    options: const [
      OptionDef('target', '目标分数', [
        OptionChoice(10, '10分（标准）'),
        OptionChoice(5, '5分（快速）'),
      ], 10),
      OptionDef('stickDealer', '庄家必叫', [
        OptionChoice(true, '开启（Stick the Dealer）'),
        OptionChoice(false, '关闭（允许重发）'),
      ], true),
    ],
    rules: euchreRules,
    create: Euchre.new,
  ),
  GameDef(
    id: 'briscola',
    name: '布里斯科拉 Briscola',
    category: '牌类',
    description: '意大利国粹 40 张抓分吃墩牌戏（支持 2~3 人个人战及 4 人搭档战）：A(11分) 与 3(10分) 统领牌阶，'
        '牌堆底牌亮明王牌花色，出牌完全不强制跟花色，围绕 120 分总分展开心理与控牌博弈！',
    playerRange: (_) => (2, 4),
    options: const [
      OptionDef('hands', '赛制局数', [
        OptionChoice(1, '1局决胜'),
        OptionChoice(3, '3局三盘两胜'),
      ], 1),
    ],
    rules: briscolaRules,
    create: Briscola.new,
  ),
  GameDef(
    id: 'arboretum',
    name: '植物园 Arboretum',
    category: '牌类',
    description: '精妙绝伦的林荫路径规划与手牌控权卡牌游戏：每回合摸二种一弃一，在个人植物园构建严格递增的林木小径，'
        '终局须比拼手牌同树种点数（且 1 可克制对手的 8）以夺取各树种的计分权！',
    playerRange: (_) => (2, 4),
    options: const [],
    rules: arboretumRules,
    create: Arboretum.new,
  ),
];
