import '../../src/engine.dart';
import 'hitori.dart';
import 'rules.dart';
import 'starbattle.dart';
import 'tents.dart';

/// 数独涂黑竞速 / 星战放星竞速 / 帐篷露营竞速
final List<GameDef> arcade9Games = [
  GameDef(
    id: 'hitori',
    name: '数独涂黑竞速',
    category: '派对',
    description: 'Nikoli 经典涂黑消重推理竞速（Hitori）：将盘面部分数字涂黑，使每行每列无重复数字、黑格不正交相邻且白格全连通！',
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
    rules: hitoriRules,
    create: HitoriGame.new,
  ),
  GameDef(
    id: 'starbattle',
    name: '星战放星竞速',
    category: '派对',
    description: '世界谜题锦标赛经典区域放星竞速（Star Battle / Queens）：在每行、每列、每个彩色区域各放入 1 颗星，且任意两星八向不相邻！',
    playerRange: (_) => (1, 6),
    options: const [
      OptionDef(
        'size',
        '网格大小',
        [
          OptionChoice(6, '6×6 标准'),
          OptionChoice(5, '5×5 快速'),
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
    rules: starBattleRules,
    create: StarBattleGame.new,
  ),
  GameDef(
    id: 'tents',
    name: '帐篷露营竞速',
    category: '派对',
    description: '经典帐篷与树木配对推理竞速（Tents & Trees）：根据行列计数线索为每棵树搭建正交相邻的帐篷，且帐篷之间八向不接触！',
    playerRange: (_) => (1, 6),
    options: const [
      OptionDef(
        'size',
        '营地大小',
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
    rules: tentsRules,
    create: TentsGame.new,
  ),
];
