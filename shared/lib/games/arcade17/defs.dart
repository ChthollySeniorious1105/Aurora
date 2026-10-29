import '../../src/engine.dart';
import 'match3_battle.dart';
import 'rules.dart';
import 'shakashaka.dart';
import 'yinyang.dart';

/// 宝石消消乐对战 / 阴阳连通竞速 / 数间直角三角竞速
final List<GameDef> arcade17Games = [
  GameDef(
    id: 'match3_battle',
    name: '宝石消消乐对战',
    category: '派对',
    description: '7×7 宝石三消连锁与冰封护盾对战（Match-3 Battle）：交换相邻宝石触发重力下落与多重 Cascade 连锁，合成激光炸弹与彩虹棱镜并向对手发射冰封护盾！',
    playerRange: (_) => (1, 6),
    options: const [
      OptionDef(
        'moves',
        '步数',
        [
          OptionChoice(15, '15 步标准'),
          OptionChoice(10, '10 步快速'),
        ],
        15,
      ),
      OptionDef(
        'colors',
        '宝石色数',
        [
          OptionChoice(5, '5 色标准'),
          OptionChoice(6, '6 色挑战'),
        ],
        5,
      ),
    ],
    rules: match3BattleRules,
    create: Match3BattleGame.new,
  ),
  GameDef(
    id: 'yinyang',
    name: '阴阳连通竞速',
    category: '派对',
    description: 'Nikoli 经典黑白双色连通与禁 2×2 同色竞速（Yin-Yang / しろまるくろまる）：在网格中填满白圆与黑圆，确保白圆整体正交连通、黑圆整体正交连通且无任何 2×2 同色方框！',
    playerRange: (_) => (1, 6),
    options: const [
      OptionDef(
        'size',
        '网格大小',
        [
          OptionChoice(5, '5×5 快速'),
          OptionChoice(6, '6×6 标准'),
        ],
        5,
      ),
      OptionDef(
        'rounds',
        '题数',
        [
          OptionChoice(3, '3 题标准'),
          OptionChoice(1, '1 题决胜'),
        ],
        3,
      ),
    ],
    rules: yinyangRules,
    create: YinYangGame.new,
  ),
  GameDef(
    id: 'shakashaka',
    name: '数间直角三角竞速',
    category: '派对',
    description: 'Nikoli 经典直角三角形填充与斜置矩形竞速（Shakashaka / シャカシャカ）：在白格中填入四种朝向的黑直角三角形，使所有白色区域构成正交或 45° 旋转矩形并匹配黑格数字线索！',
    playerRange: (_) => (1, 6),
    options: const [
      OptionDef(
        'size',
        '网格大小',
        [
          OptionChoice(5, '5×5 快速'),
          OptionChoice(6, '6×6 标准'),
        ],
        5,
      ),
      OptionDef(
        'rounds',
        '题数',
        [
          OptionChoice(3, '3 题标准'),
          OptionChoice(1, '1 题决胜'),
        ],
        3,
      ),
    ],
    rules: shakashakaRules,
    create: ShakashakaGame.new,
  ),
];
