import '../../src/engine.dart';
import 'cacao.dart';
import 'imhotep.dart';
import 'pointsalad.dart';

/// 点数沙拉 / 可可亚 / 埃及建造师
final List<GameDef> euro6Games = [
  GameDef(
    id: 'pointsalad',
    name: '点数沙拉',
    category: '桌游',
    description: '双面卡牌轮抽与组合构筑：每回合从计分牌堆拿 1 张计分规则或从市场拿 2 张蔬菜，也可将计分卡翻转为蔬菜，打造最高分的沙拉！',
    playerRange: (_) => (2, 6),
    options: const [
      OptionDef(
        'deckSize',
        '牌库规模',
        [
          OptionChoice('standard', '标准（每人数36张）'),
          OptionChoice('quick', '快速（减半）'),
        ],
        'standard',
      ),
    ],
    create: PointSalad.new,
    rules: pointSaladRules,
  ),
  GameDef(
    id: 'cacao',
    name: '可可亚',
    category: '桌游',
    description: '奇偶交错棋盘拼放与工人激活：旋转放置工人板块激活相邻丛林，采集可可、集市售卖、开采金矿、推进水源与争夺神庙。',
    playerRange: (_) => (2, 4),
    options: const [
      OptionDef(
        'mode',
        '游戏模式',
        [
          OptionChoice('standard', '标准版'),
          OptionChoice('short', '快速版（精简牌库）'),
        ],
        'standard',
      ),
    ],
    create: Cacao.new,
    rules: cacaoRules,
  ),
  GameDef(
    id: 'imhotep',
    name: '埃及建造师',
    category: '桌游',
    description: '古埃及纪念碑建造策略：采石、装船或驾驶满载石料的船只驶向集市、金字塔、神庙、墓室与方尖碑五大工地争夺最高荣誉。',
    playerRange: (_) => (2, 4),
    options: const [
      OptionDef(
        'rounds',
        '游戏轮数',
        [
          OptionChoice(6, '标准（6轮）'),
          OptionChoice(4, '快速（4轮）'),
        ],
        6,
      ),
    ],
    create: Imhotep.new,
    rules: imhotepRules,
  ),
];
