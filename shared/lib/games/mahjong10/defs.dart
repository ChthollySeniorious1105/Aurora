import '../../src/engine.dart';
import 'changzhou.dart';
import 'chaoshan.dart';
import 'qingdao.dart';

const _chaoshanRules = '''
# 潮汕麻将（只能碰杠不能吃 · 捉铳包自摸×3 · 奖马买马 · 杠分即时结算）
4 人对局，使用万、筒、条、东南西北、白发中全部 34 种共 136 张牌。
# 核心规则
- 1. 【只能碰杠不能吃】：仅允许碰牌、明杠、补杠、暗杠，不允许吃牌！
- 2. 【自摸与捉铳包自摸（allowRon）】：
  - 自摸胡牌时三家各自按总番数支付；
  - 开启【可点炮包自摸】时，若点炮（捉铳胡），点炮者一人包赔全三家份额（×3 倍，含全部中马加成）！
- 3. 【奖马 / 买马（horseCount：4匹标准 / 2匹快速）】：
  - 胡牌后从牌墙翻出指定匹数的马牌（horseTiles）；
  - 按胡牌者门风方位判定中马：东位（1、5、9、东1z、白5z）、南位（2、6、南2z、发6z）、西位（3、7、西3z、中7z）、北位（4、8、北4z）；
  - 每中 1 匹马额外增加 +1 × 基础番数！
- 4. 【杠分即时结算】：明杠 / 补杠向三家各收 +1 分（共 +3），暗杠向三家各收 +2 分（共 +6）。
''';

const _changzhouRules = '''
# 常州麻将（翻财神百搭 · 白板计台 · 无财神硬胡 · 三口承包包三家）
4 人对局，使用万、筒、条、东南西北、白发中全部 34 种共 136 张牌。支持吃（仅上家）、碰、杠、点炮与自摸胡牌。
# 翻财神与白板计台
- 1. 【翻财神（caishenTile）】：开局从牌墙翻出指示牌（caishenIndicator），同花色或同字牌组循环顺位下一张即为本局万能百搭【财神（caishenTile）】。
- 2. 【白板与字牌计台】：白板（5z）刻子/杠牌计 +1 台，中、发及风牌刻子/杠牌各计 +1 台；【无财神硬胡】额外计 +1 台！
# 三口承包 / 包三家（feedCount[seat][from] >= 3）
- 统计每位玩家吃、碰、明杠各家打出的副露次数（feedCount[seat][from]）。
- 若某玩家向同一上家/对手吃、碰、明杠累计满 3 口及以上（feedCount[seat][from] >= 3），一旦该玩家胡牌（无论自摸或点炮），喂满三口者须独自承担全三家（×3 倍）赔付责任！
''';

const _qingdaoRules = '''
# 青岛麻将（258作将 · 翻混儿百搭 · 扭牌亮风亮箭立收三家分）
4 人对局，使用万、筒、条、东南西北、白发中全部 34 种共 136 张牌。支持吃（仅上家）、碰、杠、扭牌、点炮与自摸胡牌。
# 258将（strict258）与翻混儿（hunTile）
- 1. 【翻混儿（hunTile）】：开局从牌墙翻出混儿指示牌（hunIndicator），循环顺位下一张即为本局万能百搭【混儿（hunTile）】。
- 2. 【严格258将】：开启【严格258将】时，普通 4 面子 + 1 对子胡牌必须以万、筒、条的二、五、八（2/5/8，或混儿百搭代牌）作将牌！【七对】、【清一色】、【对对胡】大牌牌型免除 258 将限制！
# 扭牌（niupai — 亮风 / 亮箭）
- 轮到自己回合时，若手中持有【中发白（5z+6z+7z 亮箭）】或【任意 3 张不同风牌（1z..4z 亮风）】，可发动【扭牌】亮出作为 1 组有效 3 张副露，立即向每位对手收取 +2 分奖励并在胡牌时额外 +1 番！
''';

final List<GameDef> mahjong10Games = [
  GameDef(
    id: 'chaoshanmj',
    name: '潮汕麻将',
    category: '麻将',
    description: '潮汕麻将：136张牌，只能碰杠不能吃，支持【捉铳包自摸（点炮包赔三家×3）】与【奖马/买马（按门风中马加番）】！',
    playerRange: (_) => (4, 4),
    rules: _chaoshanRules,
    options: const [
      OptionDef('rounds', '局数', [OptionChoice(4, '4局东风战'), OptionChoice(1, '1局快速')], 4),
      OptionDef('allowRon', '胡牌方式', [OptionChoice(true, '可点炮（捉铳包自摸）'), OptionChoice(false, '仅自摸')], true),
      OptionDef('horseCount', '奖马匹数', [OptionChoice(4, '4匹马（标准）'), OptionChoice(2, '2匹马（快速）')], 4),
    ],
    create: ChaoshanGame.new,
  ),
  GameDef(
    id: 'changzhoumj',
    name: '常州麻将',
    category: '麻将',
    description: '常州麻将：136张牌，翻财神万能百搭，白板/字牌刻子与无财神硬胡计台，吃碰杠满三口触发【三口承包包三家（×3）】！',
    playerRange: (_) => (4, 4),
    rules: _changzhouRules,
    options: const [
      OptionDef('rounds', '局数', [OptionChoice(4, '4局东风战'), OptionChoice(1, '1局快速')], 4),
      OptionDef('baosanjia', '包三家', [OptionChoice(true, '三口承包（满3口包赔三家）'), OptionChoice(false, '不承包（各自结算）')], true),
    ],
    create: ChangzhouGame.new,
  ),
  GameDef(
    id: 'qingdaomj',
    name: '青岛麻将',
    category: '麻将',
    description: '青岛麻将：136张牌，翻混儿百搭，普通胡牌严守【258作将】（七对/清一色/对对胡免258），支持中发白与三风【扭牌（亮风/亮箭）】！',
    playerRange: (_) => (4, 4),
    rules: _qingdaoRules,
    options: const [
      OptionDef('rounds', '局数', [OptionChoice(4, '4局东风战'), OptionChoice(1, '1局快速')], 4),
      OptionDef('strict258', '将牌规则', [OptionChoice(true, '严格258将（平胡需二五八作将）'), OptionChoice(false, '任意将')], true),
    ],
    create: QingdaoGame.new,
  ),
];
