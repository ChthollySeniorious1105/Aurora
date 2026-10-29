import '../../src/engine.dart';
import 'gwent.dart';
import 'hongshi.dart';
import 'sanguosha.dart';

/// 红十 / 三国杀 / 昆特牌
final List<GameDef> cards5Games = [
  GameDef(
    id: 'hongshi',
    name: '红十',
    category: '牌类',
    description: '经典东北抓红十（4~6人）：持 ♥10 与 ♦10 的玩家为一伙（同在一人手中则独打），可选择亮十（翻倍）或暗打；'
        '支持单张、对子、三张、顺子、四张炸弹与双红十王炸，先全员走完的一方获胜。',
    playerRange: (_) => (4, 6),
    options: const [
      OptionDef('rounds', '局数', [OptionChoice(4, '4局'), OptionChoice(8, '8局'), OptionChoice(1, '1局')], 4),
    ],
    rules: hongshiRules,
    create: Hongshi.new,
  ),
  GameDef(
    id: 'sanguosha',
    name: '三国杀',
    category: '牌类',
    description: '经典三国卡牌对战（2~5人身份局：主公/忠臣/反贼/内奸），12位名将技能、杀闪桃基本牌、锦囊妙计与神兵坐骑俱全。',
    playerRange: (_) => (2, 5),
    options: const [
      OptionDef('pick', '选将模式', [OptionChoice(false, '随机分配武将'), OptionChoice(true, '开局三选一/二选一选将')], false),
    ],
    rules: sanguoshaRules,
    create: Sanguosha.new,
  ),
  GameDef(
    id: 'gwent',
    name: '昆特牌',
    category: '牌类',
    description: '三局两胜三排战术卡牌博弈：开局10张手牌掌控全场，近战/远程/攻城三排部署英雄、间谍、医护、同袍与天气号角，审时度势放弃跟牌夺取胜利。',
    playerRange: (_) => (2, 2),
    options: const [
      OptionDef('mulligan', '开局调度', [OptionChoice(true, '允许更换最多2张手牌'), OptionChoice(false, '直接开战')], true),
    ],
    rules: gwentRules,
    create: Gwent.new,
  ),
];
