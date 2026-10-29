import '../../src/engine.dart';
import 'entropy.dart';
import 'konane.dart';
import 'pente.dart';

export 'entropy.dart';
export 'konane.dart';
export 'pente.dart';

final List<GameDef> abstract9Games = [
  GameDef(
    id: 'pente',
    name: '夹吃五子棋 Pente',
    category: '棋类',
    description: '经典五子连珠结合双子夹吃机制：达成五子连珠或累计夹吃对手指定对数棋子即可获胜！',
    playerRange: (_) => (2, 2),
    options: const [
      OptionDef('size', '棋盘尺寸', [
        OptionChoice(13, '13×13 标准'),
        OptionChoice(11, '11×11 快速'),
      ], 13),
      OptionDef('targetPairs', '夹吃胜目标', [
        OptionChoice(5, '5 对 (10子 标准)'),
        OptionChoice(4, '4 对 (8子 快速)'),
      ], 5),
    ],
    create: PenteGame.new,
    rules: penteRules,
    undo: true,
  ),
  GameDef(
    id: 'entropy',
    name: '熵增与秩序 Entropy',
    category: '棋类',
    description: '混沌与秩序的非对称博弈：混沌方抽色布子制造无序，秩序方滑移棋子构筑横纵回文串得分！',
    playerRange: (_) => (2, 2),
    options: const [
      OptionDef('size', '棋盘规模', [
        OptionChoice(5, '5×5 快速 (5色25子)'),
        OptionChoice(7, '7×7 标准 (7色49子)'),
      ], 5),
      OptionDef('halves', '赛制模式', [
        OptionChoice(2, '半场换边公平赛'),
        OptionChoice(1, '单局决胜'),
      ], 2),
    ],
    create: EntropyGame.new,
    rules: entropyRules,
    undo: true,
  ),
  GameDef(
    id: 'konane',
    name: '夏威夷跳棋 Konane',
    category: '棋类',
    description: '夏威夷皇室传统跳吃策略棋：黑白交错满盘开局，正交单方向跳吃或连跳敌子，无子可跳者落败！',
    playerRange: (_) => (2, 2),
    options: const [
      OptionDef('size', '棋盘规模', [
        OptionChoice(6, '6×6 快速'),
        OptionChoice(8, '8×8 标准'),
      ], 6),
    ],
    create: KonaneGame.new,
    rules: konaneRules,
    undo: true,
  ),
];
