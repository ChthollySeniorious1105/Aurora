import '../../src/engine.dart';
import 'centuryspice.dart';
import 'citadels.dart';
import 'machikoro.dart';

/// 富饶之城 / 香料之路 / 骰子街
final List<GameDef> euro4Games = [
  GameDef(
    id: 'citadels',
    name: '富饶之城',
    category: '桌游',
    description: '每轮秘密轮抽八大角色，利用刺杀、偷窃、换牌与税收发展城市，率先建满城区并获最高分者胜。',
    playerRange: (_) => (2, 7),
    options: const [
      OptionDef(
        'targetDistricts',
        '终局建筑数',
        [
          OptionChoice(7, '7 建筑标准'),
          OptionChoice(6, '6 建筑快速'),
        ],
        7,
      ),
    ],
    create: Citadels.new,
    rules: citadelsRules,
  ),
  GameDef(
    id: 'centuryspice',
    name: '香料之路',
    category: '桌游',
    description: '构筑商队手牌生产、升级与交易四级香料，招募市场商人并完成高价值香料订单。',
    playerRange: (_) => (2, 5),
    options: const [
      OptionDef(
        'targetOrders',
        '终局订单数',
        [
          OptionChoice(5, '5 张标准'),
          OptionChoice(4, '4 张快速'),
        ],
        5,
      ),
    ],
    create: CenturySpice.new,
    rules: centurySpiceRules,
  ),
  GameDef(
    id: 'machikoro',
    name: '骰子街',
    category: '桌游',
    description: '投掷骰子触发红蓝绿紫四色产业赚取金币，扩建城市设施并率先建成全部主题地标获胜。',
    playerRange: (_) => (2, 4),
    options: const [
      OptionDef(
        'landmarks',
        '胜利地标数',
        [
          OptionChoice(4, '4 座标准'),
          OptionChoice(3, '3 座快速'),
        ],
        4,
      ),
    ],
    create: MachiKoro.new,
    rules: machiKoroRules,
  ),
];
