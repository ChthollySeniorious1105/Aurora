import '../../src/engine.dart';
import 'camelup.dart';
import 'incangold.dart';

export 'camelup.dart';
export 'incangold.dart';

/// 印加宝藏（Incan Gold） / 骆驼大赛（Camel Up）
final List<GameDef> party5Games = [
  GameDef(
    id: 'incangold',
    name: '印加宝藏',
    category: '桌游',
    description: '深入古印加神庙平分宝石，独自撤退才能带走神器；若翻出第二张相同灾难，神庙坍塌血本无归！',
    playerRange: (_) => (3, 8),
    options: [
      OptionDef('rounds', '轮数', [
        OptionChoice(5, '5 轮（标准）'),
        OptionChoice(3, '3 轮（快速）'),
      ], 5),
    ],
    create: IncanGold.new,
    rules: incanGoldRules,
  ),
  GameDef(
    id: 'camelup',
    name: '骆驼大赛',
    category: '桌游',
    description: '五只骆驼叠罗汉狂飙！摇金字塔、抢分段下注牌、放绿洲或海市蜃楼，暗猜全场总冠军与垫底骆驼。',
    playerRange: (_) => (2, 8),
    options: [
      OptionDef('trackLen', '赛道长度', [
        OptionChoice(16, '16 格（标准）'),
        OptionChoice(12, '12 格（快速）'),
      ], 16),
    ],
    create: CamelUp.new,
    rules: camelUpRules,
  ),
];
