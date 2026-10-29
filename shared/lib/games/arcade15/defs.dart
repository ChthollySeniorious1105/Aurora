import '../../src/engine.dart';
import 'kurotto.dart';
import 'rules.dart';
import 'stitches.dart';
import 'tatamibari.dart';

/// 榻榻米分割竞速 / 跨宫缝线竞速 / 黑格邻群计数竞速
final List<GameDef> arcade15Games = [
  GameDef(
    id: 'tatamibari',
    name: '榻榻米分割竞速',
    category: '派对',
    description: 'Nikoli 经典 + / - / | 长宽比例矩形分割与禁四席交点竞速（Tatamibari / タタミバリ）：将网格划分为各含 1 个符号的矩形，严格匹配正方/横长/竖长比例且无四宫十字交点！',
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
    rules: tatamibariRules,
    create: TatamibariGame.new,
  ),
  GameDef(
    id: 'stitches',
    name: '跨宫缝线竞速',
    category: '派对',
    description: '经典跨区域边界唯一缝线与行列针孔计数竞速（Stitches）：在每对正交相邻区域之间恰好缝合 1 针，确保单格最多 1 个针孔并精确匹配每行每列针孔数！',
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
    rules: stitchesRules,
    create: StitchesGame.new,
  ),
  GameDef(
    id: 'kurotto',
    name: '黑格邻群计数竞速',
    category: '派对',
    description: 'Nikoli 经典圆圈邻接黑格连通群总面积计数竞速（Kurotto / クロット）：涂黑非线索方格，使每个圆圈格四向正交接触的所有不同黑格连通群总格数之和精确匹配！',
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
    rules: kurottoRules,
    create: KurottoGame.new,
  ),
];
