import '../../src/engine.dart';
import 'cascadia.dart';
import 'nidavellir.dart';
import 'puertorico.dart';
import 'starrealms.dart';

/// 卡斯卡迪亚之旅 / 波多黎各 / 尼达维利亚 / 星域奇航
final List<GameDef> euro8Games = [
  GameDef(
    id: 'cascadia',
    name: '卡斯卡迪亚之旅',
    category: '桌游',
    description: '2022德国年度桌游大奖得主：轮抽并拼放太平洋西北部五种地形板块与五种野生动物标记，构筑和谐自然生态圈！',
    playerRange: (_) => (1, 4),
    options: const [
      OptionDef(
        'rounds',
        '游戏轮数',
        [
          OptionChoice(20, '标准（20轮）'),
          OptionChoice(12, '快速（12轮）'),
        ],
        20,
      ),
    ],
    create: Cascadia.new,
    rules: cascadiaRules,
  ),
  GameDef(
    id: 'puertorico',
    name: '波多黎各',
    category: '桌游',
    description: '殿堂级德式策略经典：轮流选择开拓者、市长、建筑师、工艺师、商人与船长六大角色，经营种植园与城市建筑，装船远航夺取最高荣誉！',
    playerRange: (_) => (2, 5),
    options: const [
      OptionDef(
        'mode',
        '游戏规模',
        [
          OptionChoice('standard', '标准版'),
          OptionChoice('quick', '快速版'),
        ],
        'standard',
      ),
    ],
    create: PuertoRico.new,
    rules: puertoRicoRules,
  ),
  GameDef(
    id: 'nidavellir',
    name: '尼达维利亚',
    category: '桌游',
    description: '硬币盲拍与硬币锻造矮人军团招募：在三座酒馆部署硬币、用0号币熔铸升级皇家钱袋高面值金币，集齐五大兵种招募传奇英雄！',
    playerRange: (_) => (2, 5),
    options: const [
      OptionDef(
        'rounds',
        '游戏轮数',
        [
          OptionChoice(6, '标准（6轮）'),
          OptionChoice(4, '快速（4轮）'),
        ],
        6,
      ),
    ],
    create: Nidavellir.new,
    rules: nidavellirRules,
  ),
  GameDef(
    id: 'starrealms',
    name: '星域奇航',
    category: '桌游',
    description: '快节奏双人科幻太空战斗牌库构筑：招募贸易联盟、异虫、星际帝国与机械神教四大阵营舰队与前哨站，触发同盟连击摧毁敌方母舰！',
    playerRange: (_) => (2, 2),
    options: const [
      OptionDef(
        'authority',
        '起始权威值',
        [
          OptionChoice(50, '标准（50点）'),
          OptionChoice(35, '快速（35点）'),
        ],
        50,
      ),
    ],
    create: StarRealms.new,
    rules: starRealmsRules,
  ),
];
