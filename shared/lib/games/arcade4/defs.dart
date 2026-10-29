import '../../src/engine.dart';
import 'paohuzi.dart';
import 'pentago.dart';
import 'puyobattle.dart';
import 'rules.dart';

/// 魔法气泡对战 / 旋转五子棋 / 跑胡子
final List<GameDef> arcade4Games = [
  GameDef(
    id: 'puyobattle',
    name: '魔法气泡对战',
    category: '派对',
    description: '6×12 魔法气泡连锁对战：旋转并落下双生彩色气泡，4 颗同色正交相连即爆裂消除，重力引发多段连锁，相杀抵消并向对手倾泻障碍气泡！',
    playerRange: (_) => (2, 4),
    options: const [
      OptionDef(
        'colors',
        '气泡颜色数',
        [
          OptionChoice(4, '4 色（标准）'),
          OptionChoice(3, '3 色（爽快连锁）'),
        ],
        4,
      ),
      OptionDef(
        'garbageRate',
        '障碍强度',
        [
          OptionChoice('normal', '标准'),
          OptionChoice('high', '高强度'),
        ],
        'normal',
      ),
    ],
    rules: puyoBattleRules,
    create: PuyoBattle.new,
  ),
  GameDef(
    id: 'pentago',
    name: '旋转五子棋',
    category: '棋类',
    description: '6×6 四象限旋转五子棋：每回合在空位落一子，并将任意一个 3×3 象限顺时针或逆时针旋转 90°，率先在横竖斜连成五子者获胜！',
    playerRange: (_) => (2, 2),
    undo: true,
    options: const [
      OptionDef(
        'first',
        '先手规则',
        [
          OptionChoice('seat0', '一号位先手'),
          OptionChoice('random', '随机先手'),
        ],
        'seat0',
      ),
    ],
    rules: pentagoRules,
    create: Pentago.new,
  ),
  GameDef(
    id: 'paohuzi',
    name: '跑胡子',
    category: '牌类',
    description: '传统三人 80 张大小写字牌（一～十、壹～拾，二七十红字）：支持提、偎、跑、碰、吃与绞牌，凑满胡息即可胡牌！',
    playerRange: (_) => (3, 3),
    options: const [
      OptionDef(
        'minHuxi',
        '起胡胡息',
        [
          OptionChoice(15, '15 胡标准'),
          OptionChoice(10, '10 胡轻松'),
        ],
        15,
      ),
      OptionDef(
        'rounds',
        '局数',
        [
          OptionChoice(4, '4 局'),
          OptionChoice(8, '8 局'),
          OptionChoice(1, '1 局'),
        ],
        4,
      ),
    ],
    rules: paohuziRules,
    create: Paohuzi.new,
  ),
];
