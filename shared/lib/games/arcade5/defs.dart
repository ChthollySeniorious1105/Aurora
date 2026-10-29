import '../../src/engine.dart';
import 'nonogram.dart';
import 'ricochet.dart';
import 'rules.dart';
import 'sokoban.dart';

/// 弹射机器人 / 数织竞速 / 推箱子竞速
final List<GameDef> arcade5Games = [
  GameDef(
    id: 'ricochet',
    name: '弹射机器人',
    category: '派对',
    description: '全员同时规划空间弹射路径：4 台彩色机器人在L墙迷宫中一滑到底，互作挡板将目标机器人送入终点，最少步数获双倍积分！',
    playerRange: (_) => (1, 8),
    options: const [
      OptionDef('rounds', '局数', [OptionChoice(5, '5 局标准'), OptionChoice(3, '3 局快速')], 5),
      OptionDef('size', '棋盘大小', [OptionChoice(10, '10×10 标准'), OptionChoice(12, '12×12 扩展')], 10),
    ],
    rules: ricochetRules,
    create: RicochetGame.new,
  ),
  GameDef(
    id: 'nonogram',
    name: '数织竞速',
    category: '派对',
    description: '像素逻辑推理竞速（Picross）：根据每行每列的连续涂黑数字线索还原隐藏像素图案，支持标记 X 辅助排除，最先解出者夺得高分！',
    playerRange: (_) => (1, 6),
    options: const [
      OptionDef(
        'size',
        '网格大小',
        [
          OptionChoice(5, '5×5 快速'),
          OptionChoice(7, '7×7 标准'),
          OptionChoice(9, '9×9 挑战'),
        ],
        7,
      ),
      OptionDef('rounds', '题数', [OptionChoice(3, '3 题标准'), OptionChoice(1, '1 题快速')], 3),
    ],
    rules: nonogramRules,
    create: NonogramGame.new,
  ),
  GameDef(
    id: 'sokoban',
    name: '推箱子竞速',
    category: '派对',
    description: '经典仓库推箱子空间解谜竞速：全员同时挑战精巧必有解微缩仓库，支持无限撤销与重置，将全部箱子推上目标点即可过关！',
    playerRange: (_) => (1, 6),
    options: const [
      OptionDef('rounds', '关卡数', [OptionChoice(3, '3 关标准'), OptionChoice(1, '1 关快速')], 3),
    ],
    rules: sokobanRules,
    create: SokobanGame.new,
  ),
];
