import '../../src/engine.dart';
import 'kakuro.dart';
import 'plumber.dart';
import 'rules.dart';
import 'shikaku.dart';

/// 数方分割竞速 / 数和填字竞速 / 水管工接管竞速
final List<GameDef> arcade8Games = [
  GameDef(
    id: 'shikaku',
    name: '数方分割竞速',
    category: '派对',
    description: 'Nikoli 经典矩形面积分割竞速（Shikaku）：将网格划分为互不重叠的矩形，使每个矩形内恰好包含一个等于其面积的数字线索！',
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
    rules: shikakuRules,
    create: ShikakuGame.new,
  ),
  GameDef(
    id: 'kakuro',
    name: '数和填字竞速',
    category: '派对',
    description: '经典交叉数字填字逻辑竞速（Kakuro / Cross Sums）：在白格填入 1～9，使每段横向与纵向数字之和严格等于斜线黑格线索且无重复数字！',
    playerRange: (_) => (1, 6),
    options: const [
      OptionDef(
        'size',
        '棋盘大小',
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
    rules: kakuroRules,
    create: KakuroGame.new,
  ),
  GameDef(
    id: 'plumber',
    name: '水管工接管竞速',
    category: '派对',
    description: '经典管道连通与水压导流空间解谜竞速（Plumber）：旋转直管、弯管与三通管，构建从水源总阀通往排出口与水压表的无泄漏加压水网！',
    playerRange: (_) => (1, 6),
    options: const [
      OptionDef(
        'size',
        '管网大小',
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
    rules: plumberRules,
    create: PlumberGame.new,
  ),
];
