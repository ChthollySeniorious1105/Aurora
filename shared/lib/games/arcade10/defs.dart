import '../../src/engine.dart';
import 'futoshiki.dart';
import 'kenken.dart';
import 'masyu.dart';
import 'rules.dart';

/// 不等号数独竞速 / 黑白珍珠回路竞速 / 算术笼数独竞速
final List<GameDef> arcade10Games = [
  GameDef(
    id: 'futoshiki',
    name: '不等号数独竞速',
    category: '派对',
    description: 'Nikoli 经典不等号拉丁方推理竞速（Futoshiki）：填入 1～N 使每行每列无重复数字，且严格满足相邻方格间的全部大于/小于不等号！',
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
    rules: futoshikiRules,
    create: FutoshikiGame.new,
  ),
  GameDef(
    id: 'masyu',
    name: '黑白珍珠回路竞速',
    category: '派对',
    description: 'Nikoli 经典黑白珍珠单环回路推理竞速（Masyu）：连接相邻方格中心构成穿过所有珍珠的唯一闭环——白珍珠直行邻转弯，黑珍珠转弯双邻直行！',
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
    rules: masyuRules,
    create: MasyuGame.new,
  ),
  GameDef(
    id: 'kenken',
    name: '算术笼数独竞速',
    category: '派对',
    description: '经典四则运算算术笼拉丁方推理竞速（KenKen / Calcudoku）：填入 1～N 使每行每列无重复，且每个算术笼按 +、-、×、÷ 精确算出目标值！',
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
    rules: kenkenRules,
    create: KenKenGame.new,
  ),
];
