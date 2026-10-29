import '../../src/engine.dart';
import 'lasermaze.dart';
import 'nurikabe.dart';
import 'rules.dart';
import 'slitherlink.dart';

/// 数墙竞速 / 数圈竞速 / 激光迷宫竞速
final List<GameDef> arcade7Games = [
  GameDef(
    id: 'nurikabe',
    name: '数墙竞速',
    category: '派对',
    description: 'Nikoli 经典「岛与海」逻辑竞速（Nurikabe）：涂黑连通海域、避免 2×2 黑块，使每座白岛恰好包含一个数字且格数相等！',
    playerRange: (_) => (1, 6),
    options: const [
      OptionDef(
        'size',
        '棋盘大小',
        [
          OptionChoice(5, '5×5 快速'),
          OptionChoice(7, '7×7 标准'),
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
    rules: nurikabeRules,
    create: NurikabeGame.new,
  ),
  GameDef(
    id: 'slitherlink',
    name: '数圈竞速',
    category: '派对',
    description: 'Nikoli 经典单环回路推理竞速（Slitherlink）：在格点间划线连成唯一无分叉闭合环，严格满足方格四周的边数线索！',
    playerRange: (_) => (1, 6),
    options: const [
      OptionDef(
        'size',
        '网格大小',
        [
          OptionChoice(5, '5×5 格子'),
          OptionChoice(6, '6×6 格子'),
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
    rules: slitherlinkRules,
    create: SlitherlinkGame.new,
  ),
  GameDef(
    id: 'lasermaze',
    name: '激光迷宫竞速',
    category: '派对',
    description: '光学反射路径规划解谜竞速（Laser Maze）：在迷宫中旋转或放置反射镜，利用固定分光镜引导激光穿过全部能量水晶并射入目标接收器！',
    playerRange: (_) => (1, 6),
    options: const [
      OptionDef(
        'size',
        '迷宫大小',
        [
          OptionChoice(6, '6×6 标准'),
          OptionChoice(7, '7×7 进阶'),
        ],
        6,
      ),
      OptionDef(
        'rounds',
        '局数',
        [
          OptionChoice(3, '3 局标准'),
          OptionChoice(1, '1 局决胜'),
        ],
        3,
      ),
    ],
    rules: laserMazeRules,
    create: LaserMazeGame.new,
  ),
];
