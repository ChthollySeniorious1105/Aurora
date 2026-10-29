import '../../src/engine.dart';
import 'forsale.dart';
import 'rules.dart';
import 'ticketride.dart';
import 'tokyoking.dart';

/// 东京之王 / 车票之旅 / 房产拍卖
final List<GameDef> euro3Games = [
  GameDef(
    id: 'tokyoking',
    name: '东京之王',
    category: '桌游',
    description: '扮演巨型怪兽掷骰激战，进驻东京夺取高分，积攒闪电能量购买超能力卡，率先拿满 20 分或淘汰所有对手获胜。',
    playerRange: (_) => (2, 6),
    options: const [
      OptionDef(
        'targetVp',
        '获胜分数',
        [
          OptionChoice(20, '20 分（标准）'),
          OptionChoice(15, '15 分（快速）'),
        ],
        20,
      ),
    ],
    rules: tokyoKingRules,
    create: TokyoKing.new,
  ),
  GameDef(
    id: 'ticketride',
    name: '车票之旅',
    category: '桌游',
    description: '收集各色火车卡抢占城市间的铁路干线，连通车票任务并争夺最长连续铁路奖，总分最高者获胜。',
    playerRange: (_) => (2, 5),
    options: const [
      OptionDef(
        'cars',
        '起始车厢',
        [
          OptionChoice(35, '35 节（标准）'),
          OptionChoice(25, '25 节（快速）'),
        ],
        35,
      ),
    ],
    rules: ticketRideRules,
    create: TicketRide.new,
  ),
  GameDef(
    id: 'forsale',
    name: '房产拍卖',
    category: '桌游',
    description: '上半场加注或半价放弃竞拍 1～30 号房产，下半场同时暗选房产变现高额支票，总资产最高者获胜。',
    playerRange: (_) => (3, 6),
    options: const [
      OptionDef(
        'coins',
        '起始金币',
        [
          OptionChoice('standard', '标准起始金币'),
          OptionChoice('rich', '富裕起始金币（+4k）'),
        ],
        'standard',
      ),
    ],
    rules: forSaleRules,
    create: ForSale.new,
  ),
];
