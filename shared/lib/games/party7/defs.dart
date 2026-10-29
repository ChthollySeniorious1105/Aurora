import '../../src/engine.dart';
import 'canstop.dart';
import 'qwirkle.dart';
import 'saboteur.dart';

/// 欲罢不能 / 形色牌 / 矮人矿坑
final List<GameDef> party7Games = [
  GameDef(
    id: 'canstop',
    name: '欲罢不能',
    category: '桌游',
    description: 'Sid Sackson 经典押注运气骰子登山桌游：4 颗骰子两两配对推进最多 3 条山道，见好就收扎营还是贪心坠崖？',
    playerRange: (_) => (2, 4),
    options: [
      OptionDef(
        'targetCols',
        '胜利列数',
        [
          OptionChoice(3, '3列（标准）'),
          OptionChoice(2, '2列（快速）'),
        ],
        3,
      ),
    ],
    create: CanStopGame.new,
    rules: canStopRules,
  ),
  GameDef(
    id: 'qwirkle',
    name: '形色牌',
    category: '桌游',
    description: '6 种颜色 × 6 种形状的图案拼接经典桌游：在棋盘上构建同色异形或同形异色的连续队列，凑齐 6 张达成 Qwirkle！',
    playerRange: (_) => (2, 4),
    options: [
      OptionDef(
        'copies',
        '每种牌数',
        [
          OptionChoice(3, '3张（标准108张）'),
          OptionChoice(2, '2张（快速72张）'),
        ],
        3,
      ),
    ],
    create: QwirkleGame.new,
    rules: qwirkleRules,
  ),
  GameDef(
    id: 'saboteur',
    name: '矮人矿坑',
    category: '派对',
    description: '淘金矮人与暗藏的破坏者斗智斗勇：拼接矿道通往金矿、使用藏宝图探路，小心破坏者的死胡同、落石塌方与工具破坏！',
    playerRange: (_) => (3, 8),
    options: [
      OptionDef(
        'rounds',
        '局数',
        [
          OptionChoice(3, '3局（标准）'),
          OptionChoice(1, '1局（快速）'),
        ],
        3,
      ),
    ],
    create: SaboteurGame.new,
    rules: saboteurRules,
  ),
];
