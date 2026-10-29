import '../../src/engine.dart';
import 'akari.dart';
import 'hashi.dart';
import 'klotski.dart';
import 'rules.dart';

/// 华容道竞速 / 数回连桥竞速 / 美术馆照明竞速
final List<GameDef> arcade6Games = [
  GameDef(
    id: 'klotski',
    name: '华容道竞速',
    category: '派对',
    description: '中国传统 4×5 滑块空间解谜竞速：全员同时调遣五虎上将与兵卒开辟通道，护送 2×2 曹操从底部中央出口突围，支持无限撤销与重置！',
    playerRange: (_) => (1, 6),
    options: const [
      OptionDef(
        'difficulty',
        '难度档位',
        [
          OptionChoice('easy', '入门突围 (8~16步)'),
          OptionChoice('classic', '经典名局 (18~40步)'),
        ],
        'easy',
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
    rules: klotskiRules,
    create: KlotskiGame.new,
  ),
  GameDef(
    id: 'hashi',
    name: '数回连桥竞速',
    category: '派对',
    description: 'Nikoli 经典岛屿连桥推理竞速（Hashiwokakero）：在正对可见的岛屿间架设单桥或双桥，使所有岛屿连通、互不交叉且完全匹配数字线索！',
    playerRange: (_) => (1, 6),
    options: const [
      OptionDef(
        'size',
        '海域大小',
        [
          OptionChoice(6, '6×6 轻松'),
          OptionChoice(8, '8×8 标准'),
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
    rules: hashiRules,
    create: HashiGame.new,
  ),
  GameDef(
    id: 'akari',
    name: '美术馆照明竞速',
    category: '派对',
    description: 'Nikoli 经典光线逻辑竞速（Light Up）：在展厅白格中布置灯泡照亮全场，确保灯泡之间互不直射且严格满足黑色墙壁四邻数字要求！',
    playerRange: (_) => (1, 6),
    options: const [
      OptionDef(
        'size',
        '展厅大小',
        [
          OptionChoice(6, '6×6 轻松'),
          OptionChoice(8, '8×8 标准'),
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
    rules: akariRules,
    create: AkariGame.new,
  ),
];
