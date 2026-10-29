import '../../src/engine.dart';
import 'alhambra.dart';
import 'dominion.dart';
import 'sheriff.dart';

/// 皇舆争霸 / 阿尔罕布拉宫 / 诺丁汉警长
final List<GameDef> euro7Games = [
  GameDef(
    id: 'dominion',
    name: '皇舆争霸',
    category: '桌游',
    description: '经典牌库构筑卡牌游戏：从铜币与庄园起步，用行动牌与钱币牌购买王国卡与行省，争夺最高胜点。',
    playerRange: (_) => (2, 4),
    options: const [
      OptionDef(
        'provinces',
        '行省数量',
        [
          OptionChoice(8, '标准（2人8张 / 3-4人12张）'),
          OptionChoice(5, '快速（5张行省）'),
        ],
        8,
      ),
    ],
    create: DominionGame.new,
    rules: dominionRules,
  ),
  GameDef(
    id: 'alhambra',
    name: '阿尔罕布拉宫',
    category: '桌游',
    description: '收集四种货币购买六类宫殿建筑板块，精准支付可获额外行动，通过多轮建筑多数与外城墙长度计分。',
    playerRange: (_) => (2, 5),
    options: const [
      OptionDef(
        'rounds',
        '计分轮数',
        [
          OptionChoice('standard', '三轮标准计分'),
          OptionChoice('quick', '两轮快速计分'),
        ],
        'standard',
      ),
    ],
    create: AlhambraGame.new,
    rules: alhambraRules,
  ),
  GameDef(
    id: 'sheriff',
    name: '诺丁汉警长',
    category: '派对',
    description: '轮流担任诺丁汉警长盘查过关货袋，商人可诚实申报、贿赂警长或夹带高价违禁品，终局争夺国王与王后大奖。',
    playerRange: (_) => (3, 6),
    options: const [
      OptionDef(
        'turnsAsSheriff',
        '每人当警长次数',
        [
          OptionChoice(1, '快速（每人1次）'),
          OptionChoice(2, '标准（每人2次）'),
        ],
        1,
      ),
    ],
    create: SheriffGame.new,
    rules: sheriffRules,
  ),
];
