import '../../src/engine.dart';
import 'galaxies.dart';
import 'hidato.dart';
import 'kuromasu.dart';
import 'rules.dart';

/// 数链寻路竞速 / 黑格视线竞速 / 对称星系分割竞速
final List<GameDef> arcade12Games = [
  GameDef(
    id: 'hidato',
    name: '数链寻路竞速',
    category: '派对',
    description: '经典八方向连续数链哈密顿路径竞速（Hidato）：填入 1～N² 使每一对相邻数字（k 与 k+1）均八方向正交或对角相邻！',
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
    rules: hidatoRules,
    create: HidatoGame.new,
  ),
  GameDef(
    id: 'kuromasu',
    name: '黑格视线竞速',
    category: '派对',
    description: 'Nikoli 经典四向白格视线计数竞速（Kuromasu / 黒どこ）：涂黑方格使每个数字格四向可见白格数匹配、黑格禁邻且白格全连通！',
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
    rules: kuromasuRules,
    create: KuromasuGame.new,
  ),
  GameDef(
    id: 'galaxies',
    name: '对称星系分割竞速',
    category: '派对',
    description: 'Nikoli 经典 180° 中心旋转对称星系分割竞速（Spiral Galaxies / 天体ショー）：围绕星系中心圆点划分正交连通且 180° 旋转对称的星系区域！',
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
    rules: galaxiesRules,
    create: GalaxiesGame.new,
  ),
];
