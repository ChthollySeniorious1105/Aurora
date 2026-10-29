import '../../src/engine.dart';
import 'binairo.dart';
import 'rules.dart';
import 'skyscrapers.dart';
import 'suguru.dart';

/// 摩天楼可见数竞速 / 黑白平衡二进制竞速 / 数块邻格互斥竞速
final List<GameDef> arcade11Games = [
  GameDef(
    id: 'skyscrapers',
    name: '摩天楼可见数竞速',
    category: '派对',
    description: '经典三维摩天楼视线遮挡拉丁方推理竞速（Skyscrapers）：填入 1～N 层楼高使每行每列无重复，且严格匹配四周边缘可见楼栋数！',
    playerRange: (_) => (1, 6),
    options: const [
      OptionDef(
        'size',
        '网格大小',
        [
          OptionChoice(4, '4×4 快速'),
          OptionChoice(5, '5×5 标准'),
        ],
        4,
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
    rules: skyscrapersRules,
    create: SkyscrapersGame.new,
  ),
  GameDef(
    id: 'binairo',
    name: '黑白平衡二进制竞速',
    category: '派对',
    description: '经典黑白平衡无三连二进制推理竞速（Binairo / Takuzu）：填入 ☀️ 与 🌙 使同行同列无三连、阴阳各半且无重复行列！',
    playerRange: (_) => (1, 6),
    options: const [
      OptionDef(
        'size',
        '网格大小',
        [
          OptionChoice(6, '6×6 标准'),
          OptionChoice(4, '4×4 快速'),
        ],
        6,
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
    rules: binairoRules,
    create: BinairoGame.new,
  ),
  GameDef(
    id: 'suguru',
    name: '数块邻格互斥竞速',
    category: '派对',
    description: '稻叶直贵经典多联骨牌数块推理竞速（Suguru / Tectonic）：每个 K 格数块填入 1～K，且八方向（含对角线）邻格严禁同数！',
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
    rules: suguruRules,
    create: SuguruGame.new,
  ),
];
