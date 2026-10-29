import '../../src/engine.dart';
import 'norinori.dart';
import 'rules.dart';
import 'thermometers.dart';
import 'yajilin.dart';

/// 箭头回路竞速 / 多米诺双格竞速 / 温度计填充竞速
final List<GameDef> arcade13Games = [
  GameDef(
    id: 'yajilin',
    name: '箭头回路竞速',
    category: '派对',
    description: 'Nikoli 经典方向箭头黑格计数与单一闭环竞速（Yajilin / ヤジリン）：按箭头指向涂黑方格使黑格禁邻，并用单一闭环串起全部剩余白格！',
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
    rules: yajilinRules,
    create: YajilinGame.new,
  ),
  GameDef(
    id: 'norinori',
    name: '多米诺双格竞速',
    category: '派对',
    description: 'Nikoli 经典区域双黑与多米诺骨牌配对竞速（Norinori / のりのり）：涂黑方格使每个区域恰好包含 2 个黑格，且所有黑格两两配成互不接触的 1×2 多米诺！',
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
    rules: norinoriRules,
    create: NorinoriGame.new,
  ),
  GameDef(
    id: 'thermometers',
    name: '温度计填充竞速',
    category: '派对',
    description: '经典水银温度计连续填充与行列计数竞速（Thermometers）：从每个水银球起点连续注入水银无断层，且严格匹配每行每列的水银格总数！',
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
    rules: thermometersRules,
    create: ThermometersGame.new,
  ),
];
