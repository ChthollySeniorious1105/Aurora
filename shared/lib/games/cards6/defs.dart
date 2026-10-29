import '../../src/engine.dart';
import 'cribbage.dart';
import 'durak.dart';
import 'ohhell.dart';

/// 克里比奇 / 猜墩牌 / 杜拉克
final List<GameDef> cards6Games = [
  GameDef(
    id: 'cribbage',
    name: '克里比奇',
    category: '牌类',
    description: '经典双人扑克计分赛（Cribbage）：每手选 2 张入庄家底牌（Crib），打点阶段凑 15、31、对子与顺子，'
        '亮牌阶段闲家先行计分，率先在计分孔板上抵达目标分数（61/121分）者获胜。',
    playerRange: (_) => (2, 2),
    options: const [
      OptionDef('target', '目标分数', [
        OptionChoice(61, '61分（半程快速）'),
        OptionChoice(121, '121分（标准全场）'),
      ], 61),
    ],
    rules: cribbageRules,
    create: Cribbage.new,
  ),
  GameDef(
    id: 'ohhell',
    name: '猜墩牌',
    category: '牌类',
    description: '3~6人精确合约吃墩博弈（Oh Hell）：每局按阶梯牌数发牌并翻开王牌，依序叫墩且庄家受“禁手规则”限制'
        '（总叫墩数不可等于总墩数），精确命中合约得 10+墩数分！',
    playerRange: (_) => (3, 6),
    options: const [
      OptionDef('schedule', '赛程局数', [
        OptionChoice('short', '短赛程 5局 (5-6-7-6-5)'),
        OptionChoice('full', '标准赛程 7局 (1-2-3-4-5-6-7)'),
      ], 'short'),
      OptionDef('scoring', '计分规则', [
        OptionChoice('standard', '标准（猜中10+墩，猜错0分）'),
        OptionChoice('penalty', '罚分（猜错倒扣差值）'),
      ], 'standard'),
    ],
    rules: ohHellRules,
    create: OhHell.new,
  ),
  GameDef(
    id: 'durak',
    name: '杜拉克',
    category: '牌类',
    description: '2~6人俄罗斯经典攻防扑克（Durak / 傻瓜牌）：36张牌亮底定主，攻方出牌与追加同点牌，守方以更大同花或主牌反击，'
        '成功防住则弃牌并接任攻方，失败则收下全桌牌，避免成为最后剩牌的杜拉克！',
    playerRange: (_) => (2, 6),
    options: const [],
    rules: durakRules,
    create: Durak.new,
  ),
];
