import '../../src/engine.dart';
import 'beijing.dart';
import 'hongzhong.dart';
import 'nanjing.dart';
import 'ningxia.dart';

const _hongzhongRules = '''
# 红中赖子麻将（112张牌 · 红中7z恒为赖子 · 四红中天胡 · 扎鸟1/5/9/红中中码）
4 人对局，使用万、筒、条 1..9 共 108 张 + 4 张红中（7z），共计 112 张牌。不可吃牌，支持碰、杠（暗杠、明杠、补杠）、抢杠胡与自摸（可选开启点炮胡）。
# 核心规则
- 1. 【红中恒为万能赖子（laiziTile = '7z'）】：红中（7z）在手牌中可代替任意花色与点数的麻将牌组合面子或将牌。
- 2. 【四红中大胡（siHongZhong，+4番）】：手握全部 4 张红中（7z）可直接自摸胡牌！
- 3. 【特色大番】：
  - 【硬胡无红中（+2番）】、【豪华七对（+4番）】、【七对（+2番）】、【碰碰胡（+2番）】、【清一色（+4番）】、【门清（+1番）】可叠加计番。
- 4. 【扎鸟/抓码（birdTiles & hitBirds）】：胡牌后从剩余牌墙翻出指定数量（2/4/6）的鸟牌，点数为 1、5、9 或红中（7z）即算中鸟（hitBirds），每中 1 鸟结算额外 +1 倍加成！
''';

const _beijingRules = '''
# 北京麻将（136张牌 · 翻混儿百搭 · 捉五魁+4 · 本混儿龙+8 · 素胡+2 · 混儿吊+2）
4 人对局，使用万、筒、条、东南西北、白发中全部 34 种共 136 张牌。支持吃（仅上家）、碰、杠、点炮与自摸胡牌。
# 核心规则
- 1. 【翻混儿（hunTile）】：开局从牌墙翻出混儿指示牌（hunIndicator），同花色或同字牌组循环顺位下一张即为本局万能百搭【混儿（hunTile）】。
- 2. 【京味特色番种】：
  - 【本混儿龙（isBenHunLong，+8番）】：手牌达成一条龙（同花色 1..9）且该花色与本局混儿（hunTile）花色一致！
  - 【一条龙（isYiTiaoLong，+4番）】：手牌包含同花色 1..9 三组顺子。
  - 【捉五魁（isZhuoWuKui，+4番）】：胡牌张为五万（5m）且嵌入四万、六万完成 456m 顺子。
  - 【素胡/无混硬胡（isSuHu，+2番）】：不使用混儿代牌达成自然胡牌。
  - 【混儿吊（isHunDiao，+2番）】：以混儿配单张作将牌成胡。
  - 另支持【豪华七对（+4番）】、【七对（+2番）】、【清一色（+4番）】、【混一色（+2番）】、【对对胡（+2番）】、【门清（+1番）】。
''';

const _nanjingRules = '''
# 南京麻将（136张牌 · 硬花算花 · 比下胡×2 · 门清/混一色/清一色/全球人独钓/满堂花）
4 人对局，使用万、筒、条、东南西北、白发中全部 34 种共 136 张牌。支持吃（仅上家）、碰、杠、点炮与自摸胡牌。
# 核心规则
- 1. 【硬花与算花（huaCount）】：
  - 中（7z）、发（6z）、白（5z）刻子/杠/亮牌、风刻（东南西北 1z..4z）以及暗杠（+2花）、明杠（+1花）均计入硬花数（huaCount），每花 +1 番；
  - 0 花成牌触发【无花果（+1番）】，满 4 花及以上触发【满堂花（+2番）】！
- 2. 【比下胡（bixiahu，×2倍）】：庄家胡牌连庄、流局连庄或三副露以上包牌触发比下胡，结算总分 ×2 倍！
- 3. 【特色番种】：【清一色（+6番）】、【混一色（+4番）】、【对对胡（+4番）】、【七对（+4番）】、【全球人独钓（+4番）】、【一条龙（+4番）】、【门清（+2番）】。
''';

const _ningxiaRules = '''
# 宁夏滑水麻将（136张牌 · 开局下鱼0/2/5/8 · 甩张+2番 · 连庄加番）
4 人对局，使用万、筒、条、东南西北、白发中全部 34 种共 136 张牌。支持开局下鱼（滑水）、吃（仅上家）、碰、杠、甩张、点炮与自摸胡牌。
# 核心规则
- 1. 【开局下鱼/滑水（xiayu phase）】：
  - 每局发牌后进入下鱼阶段（phase == 'xiayu'），4 名玩家同时选择本局鱼数（0、2、5、8 鱼）后进入行牌阶段（phase == 'play'）；
  - 胡牌结算时，赢家与每位输家之间额外加上【赢家鱼数 + 输家鱼数（yu[winner] + yu[payer]）】的滑水鱼分！
- 2. 【甩张（shuaizhang，+2番）】：早巡打出字牌（1z..7z）或宣告甩张报听（{'type': 'shuaizhang', 'tile': t}），胡牌额外获得 +2 番！
- 3. 【特色番种】：支持【豪华七对（+4番）】、【七对（+2番）】、【清一色（+4番）】、【混一色（+2番）】、【对对胡（+2番）】、【一条龙（+2番）】、【门清（+1番）】与【连庄加番】。
''';

final List<GameDef> mahjong13Games = [
  GameDef(
    id: 'hongzhongmj',
    name: '红中赖子麻将',
    category: '麻将',
    description: '红中赖子麻将：112张牌，【红中（7z）恒为万能赖子】，不可吃牌，支持【四红中大胡】、【硬胡无红中】与【1/5/9/红中扎鸟抓码】！',
    playerRange: (_) => (4, 4),
    rules: _hongzhongRules,
    options: const [
      OptionDef('rounds', '局数', [OptionChoice(4, '4局东风战'), OptionChoice(1, '1局快速')], 4),
      OptionDef('allowRon', '胡牌方式', [OptionChoice(false, '自摸胡/抢杠胡'), OptionChoice(true, '可点炮可自摸')], false),
      OptionDef('birds', '扎鸟数', [OptionChoice(2, '扎2鸟'), OptionChoice(4, '扎4鸟'), OptionChoice(6, '扎6鸟')], 4),
    ],
    create: HongzhongGame.new,
  ),
  GameDef(
    id: 'beijingmj',
    name: '北京麻将',
    category: '麻将',
    description: '北京麻将：136张牌翻混儿百搭，支持【捉五魁(+4)】、【本混儿龙(+8)】、【一条龙(+4)】、【素胡(+2)】与【混儿吊(+2)】！',
    playerRange: (_) => (4, 4),
    rules: _beijingRules,
    options: const [
      OptionDef('rounds', '局数', [OptionChoice(4, '4局东风战'), OptionChoice(1, '1局快速')], 4),
      OptionDef('allowRon', '胡牌方式', [OptionChoice(true, '可点炮可自摸'), OptionChoice(false, '只许自摸')], true),
    ],
    create: BeijingGame.new,
  ),
  GameDef(
    id: 'nanjingmj',
    name: '南京麻将',
    category: '麻将',
    description: '南京麻将：136张牌，中发白/风刻/明暗杠计【硬花（无花果/满堂花）】，支持【比下胡（×2）】与【门清/清一色/全球人独钓】！',
    playerRange: (_) => (4, 4),
    rules: _nanjingRules,
    options: const [
      OptionDef('rounds', '局数', [OptionChoice(4, '4局东风战'), OptionChoice(1, '1局快速')], 4),
      OptionDef('allowRon', '胡牌方式', [OptionChoice(true, '可点炮可自摸'), OptionChoice(false, '只许自摸')], true),
    ],
    create: NanjingGame.new,
  ),
  GameDef(
    id: 'ningxiamj',
    name: '宁夏滑水麻将',
    category: '麻将',
    description: '宁夏滑水麻将：136张牌，开局全员【下鱼滑水（0/2/5/8鱼双向加分）】，支持【甩张（+2番）】、【豪华七对】与【连庄加番】！',
    playerRange: (_) => (4, 4),
    rules: _ningxiaRules,
    options: const [
      OptionDef('rounds', '局数', [OptionChoice(4, '4局东风战'), OptionChoice(1, '1局快速')], 4),
      OptionDef('allowRon', '胡牌方式', [OptionChoice(true, '可点炮可自摸'), OptionChoice(false, '只许自摸')], true),
    ],
    create: NingxiaGame.new,
  ),
];
