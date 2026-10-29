import '../../src/engine.dart';
import 'hainan.dart';
import 'tangshan.dart';
import 'wuxi.dart';

const _tangshanRules = '''
# 唐山麻将（本混儿钻山 · 报听封手×2 · 捉五魁+2番）
4 人对局，使用万、筒、条、东南西北、白发中全部 34 种共 136 张牌。支持吃（仅上家）、碰、杠、报听、点炮与自摸胡牌。
# 核心规则
- 1. 【本混儿 / 钻山（hunTile）】：开局从牌墙翻出指示牌（hunIndicator），同花色或同字牌组循环顺位下一张即为本局万能百搭【本混儿（hunTile）】。
- 2. 【报听封手（baoting，+2番 / ×2倍）】：
  - 当玩家手牌差 1 张即可听牌（waits 非空）且尚未报听时，可在出牌的同时宣告【报听（baoting）】；
  - 报听后手牌立即封手锁定（后续不可吃、碰、开杠改牌，摸牌不胡只能摸切），胡牌时额外获得 +2 番且结算总分 ×2 倍加成！
- 3. 【捉五魁与特色大番（+2番）】：
  - 【捉五魁】：胡牌张为五万（5m）、五筒（5p）或五条（5s）时额外计 +2 番！
  - 【一条龙】、【七对】、【门清】各计 +2 番，叠加【对对胡】、【混一色】、【清一色】、【素胡（无混儿）】与【杠上开花】！
''';

const _wuxiRules = '''
# 无锡麻将（翻百搭 · 无百搭硬胡 · 门清双倍 · 放冲独付×3）
4 人对局，使用万、筒、条、东南西北、白发中全部 34 种共 136 张牌。支持吃（仅上家）、碰、杠、点炮与自摸胡牌。
# 翻百搭与硬胡 / 门清计番
- 1. 【翻百搭（baidaTile）】：开局从牌墙翻出百搭指示牌（baidaIndicator），循环顺位下一张即为本局万能百搭【百搭（baidaTile）】。
- 2. 【无百搭硬胡与门清双倍】：
  - 手中无百搭或百搭自然成牌（未作万能代牌）达成【无百搭硬胡】额外计 +1 番；
  - 无吃、碰、明杠副露达成【门清双倍】额外计 +1 番且倍率翻倍！
# 放冲独付（点炮一人包三家 ×3）
- 自摸胡牌（tsumo）时，三家对手各自赔付 1 份（1×）；
- 点炮捉铳（ron）时，触发无锡麻将特色【放冲独付】——由点炮者一人独自承担全部三家份额（×3 倍），其余两家免赔（付 0 分）！
''';

const _hainanRules = '''
# 海南麻将（开局上噶0~3 · 有番起胡 · 首圈跟庄）
4 人对局，使用万、筒、条、东南西北、白发中全部 34 种共 136 张牌。支持吃（仅上家）、碰、杠、点炮与自摸胡牌。
# 第一阶段：上噶 / 噶码（gama 0~3）
- 每局发牌后进入【上噶（gama）】阶段，每位玩家自由选择本局噶码（不噶 0 ~ 3 噶）。
- 任意玩家胡牌结算时，赢家与每位付款输家之间的赔付分数均额外加上【赢家上噶 + 输家上噶】（+(gama[winner] + gama[loser])）！
# 有番起胡（requireFan）
- 开启【有番起胡】时，手牌必须至少具备以下 1 种海南有效番型方可胡牌：
  - 【令牌】：中、发、白箭牌刻子/杠（5z..7z）或门风/圈风刻子/杠（1z..4z）；
  - 【门清】：0 组明副露（无吃、碰、明杠）；
  - 【平胡全顺】：全部 4 组面子均为顺子且将牌为万、筒、条数牌（非字牌将）；
  - 【对对胡】、【混一色】、【清一色】、【七对】或【杠上开花】！
# 首圈跟庄（genzhuang）
- 若本局前 4 张舍牌（discardHistory.length == 4，且期间无人吃、碰、杠）中，三名闲家连续打出与庄家第一张舍牌完全相同的牌，立即触发【首圈跟庄】——庄家当场向三家闲家各赔 +2 分！
''';

final List<GameDef> mahjong11Games = [
  GameDef(
    id: 'tangshanmj',
    name: '唐山麻将',
    category: '麻将',
    description: '唐山麻将：136张牌，翻本混儿（钻山）万能百搭，支持【报听封手（+2番/×2倍）】与【捉五魁/一条龙/七对/门清（+2番）】！',
    playerRange: (_) => (4, 4),
    rules: _tangshanRules,
    options: const [
      OptionDef('rounds', '局数', [OptionChoice(4, '4局东风战'), OptionChoice(1, '1局快速')], 4),
      OptionDef('allowRon', '胡牌方式', [OptionChoice(true, '可点炮可自摸'), OptionChoice(false, '只许自摸')], true),
    ],
    create: TangshanGame.new,
  ),
  GameDef(
    id: 'wuximj',
    name: '无锡麻将',
    category: '麻将',
    description: '无锡麻将：136张牌，翻百搭万能代牌，无百搭硬胡与门清双倍加番，点炮触发【放冲独付（点炮者独赔三家×3）】！',
    playerRange: (_) => (4, 4),
    rules: _wuxiRules,
    options: const [
      OptionDef('rounds', '局数', [OptionChoice(4, '4局东风战'), OptionChoice(1, '1局快速')], 4),
      OptionDef('fangchongDufu', '点炮规则', [OptionChoice(true, '放冲独付（点炮独赔三家×3）'), OptionChoice(false, '各自赔付（点炮1份）')], true),
    ],
    create: WuxiGame.new,
  ),
  GameDef(
    id: 'hainanmj',
    name: '海南麻将',
    category: '麻将',
    description: '海南麻将：136张牌，开局【上噶（0~3噶）】双边加分，严守【有番起胡（令牌/门清/平胡全顺/对对胡等）】，支持【首圈跟庄】！',
    playerRange: (_) => (4, 4),
    rules: _hainanRules,
    options: const [
      OptionDef('rounds', '局数', [OptionChoice(4, '4局东风战'), OptionChoice(1, '1局快速')], 4),
      OptionDef('requireFan', '起胡规则', [OptionChoice(true, '有番起胡（标准）'), OptionChoice(false, '可无番平胡（快速）')], true),
    ],
    create: HainanGame.new,
  ),
];
