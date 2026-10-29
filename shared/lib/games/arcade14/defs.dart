import '../../src/engine.dart';
import 'creek.dart';
import 'heyawake.dart';
import 'rules.dart';
import 'shingoki.dart';

/// 分室涂黑竞速 / 信号灯回路竞速 / 溪流交点竞速
final List<GameDef> arcade14Games = [
  GameDef(
    id: 'heyawake',
    name: '分室涂黑竞速',
    category: '派对',
    description: 'Nikoli 经典分室黑格计数与禁三室直通白格竞速（Heyawake / へやわけ）：按房间线索涂黑方格使黑格禁邻、白格连通，且任意直线连续白格不得跨越 2 条房间边界！',
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
    rules: heyawakeRules,
    create: HeyawakeGame.new,
  ),
  GameDef(
    id: 'shingoki',
    name: '信号灯回路竞速',
    category: '派对',
    description: 'Nikoli 经典信号灯直转与双臂总长回路竞速（Shingoki / しんごき）：在格点网格连接唯一闭环，使白灯直行、黑灯 90° 转弯且两侧直线段长度之和精确匹配信号灯数字！',
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
    rules: shingokiRules,
    create: ShingokiGame.new,
  ),
  GameDef(
    id: 'creek',
    name: '溪流交点竞速',
    category: '派对',
    description: 'Nikoli 经典格点交点黑格计数与连通白格溪流竞速（Creek / クリーク）：根据网格交点数字涂黑周围河岸方格，同时确保所有白格连成唯一不断流的溪流！',
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
    rules: creekRules,
    create: CreekGame.new,
  ),
];
