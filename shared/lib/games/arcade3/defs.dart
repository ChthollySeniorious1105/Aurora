import '../../src/engine.dart';
import 'math24.dart';
import 'mjconnect.dart';
import 'rules.dart';
import 'tankbattle.dart';

/// 算术24点 / 坦克大战 / 连连看竞速
final List<GameDef> arcade3Games = [
  GameDef(
    id: 'math24',
    name: '算术24点',
    category: '派对',
    description: '每轮发 4 张数字牌（严格保证有解），全员同时在各自工作区用加减乘除分步合成 24！支持精确分数、撤销与重置，越快算出得分越高。',
    playerRange: (_) => (1, 8),
    options: const [
      OptionDef('rounds', '题数', [OptionChoice(5, '5 题'), OptionChoice(10, '10 题')], 5),
      OptionDef('maxNum', '数字范围', [OptionChoice(10, '1~10 简单'), OptionChoice(13, '1~13 标准')], 13),
    ],
    rules: math24Rules,
    create: Math24Game.new,
  ),
  GameDef(
    id: 'tankbattle',
    name: '坦克大战',
    category: '派对',
    description: '经典 15×15 战场实时对战：穿梭于砖墙、钢铁、草丛与水域之间，拾取护盾、速射、星级强化与维修包，击毁所有敌方坦克！',
    playerRange: (_) => (2, 4),
    options: const [
      OptionDef('lives', '生命数', [OptionChoice(3, '3 命'), OptionChoice(5, '5 命')], 3),
      OptionDef(
        'map',
        '战场地图',
        [
          OptionChoice('standard', '标准战场'),
          OptionChoice('steel', '钢铁迷宫'),
          OptionChoice('jungle', '丛林水网'),
        ],
        'standard',
      ),
    ],
    rules: tankBattleRules,
    create: TankBattle.new,
  ),
  GameDef(
    id: 'mjconnect',
    name: '连连看竞速',
    category: '派对',
    description: '全员同图麻将连连看竞速：两次转弯（最多 3 段直线，可走外圈边界）内连通相同麻将牌即可消除，无解自动洗牌，最先清空棋盘者获胜！',
    playerRange: (_) => (1, 6),
    options: const [
      OptionDef(
        'size',
        '棋盘大小',
        [
          OptionChoice('small', '小型 6×4'),
          OptionChoice('medium', '标准 6×6'),
          OptionChoice('large', '大型 8×6'),
        ],
        'medium',
      ),
    ],
    rules: mjConnectRules,
    create: MjConnect.new,
  ),
];
