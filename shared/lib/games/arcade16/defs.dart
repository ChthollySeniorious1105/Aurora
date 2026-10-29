import '../../src/engine.dart';
import 'chocona.dart';
import 'lits.dart';
import 'magnets.dart';
import 'rules.dart';

/// 四格骨牌竞速 / 巧克块矩形竞速 / 磁铁正负极竞速
final List<GameDef> arcade16Games = [
  GameDef(
    id: 'lits',
    name: '四格骨牌竞速',
    category: '派对',
    description: 'Nikoli 经典每宫四格骨牌与同形不相邻连通竞速（LITS / ヌルオミノ）：在每个区域内涂黑 1 个 L/I/T/S 四格骨牌，确保全盘黑格连通、无 2×2 全黑且相邻骨牌不同形！',
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
    rules: litsRules,
    create: LitsGame.new,
  ),
  GameDef(
    id: 'chocona',
    name: '巧克块矩形竞速',
    category: '派对',
    description: 'Nikoli 经典分宫黑格计数与实心巧克块矩形竞速（Chocona / チョコナ）：涂黑方格使每个区域的黑格数等于其线索，且所有跨边界或宫内的黑格连通群均为实心矩形！',
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
    rules: choconaRules,
    create: ChoconaGame.new,
  ),
  GameDef(
    id: 'magnets',
    name: '磁铁正负极竞速',
    category: '派对',
    description: '经典多米诺磁铁正负极填充与同极互斥计数竞速（Magnets）：将多米诺槽位填入 [+, -] 或保持中性，确保任意同极正交不相邻并精确匹配每行每列的正负极总数！',
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
    rules: magnetsRules,
    create: MagnetsGame.new,
  ),
];
