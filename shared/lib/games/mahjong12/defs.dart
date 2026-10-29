import '../../src/engine.dart';
import 'dalian.dart';
import 'gansu.dart';
import 'yangzhou.dart';

const _yangzhouRules = '''
# 扬州麻将（翻配子百搭 · 白板顶替本牌 · 软胡自摸 vs 硬牌/大胡可捉铳）
4 人对局，使用万、筒、条、东南西北、白发中全部 34 种共 136 张牌。支持吃（仅上家）、碰、杠、点炮（捉铳）与自摸胡牌。
# 核心规则
- 1. 【翻配子（peiziTile）与白板顶替（5z）】：
  - 开局从牌墙翻出配子指示牌（peiziIndicator），同花色或同字牌组循环顺位下一张即为本局万能百搭【配子（peiziTile）】；
  - 【白板（5z）】在牌型组合中直接顶替配子原本的自然牌面点数与花色参与顺子、刻子、将牌及一色判定！
- 2. 【软胡自摸 vs 硬牌/大胡可捉铳（strictRon）】：
  - 自摸（tsumo）时，任意成牌牌型（4面子+1将牌 或 七对，无论软牌或硬牌）均可自摸胡牌！
  - 开启【软屁胡禁点炮（strictRon = true）】时，点炮捉铳（ron）必须满足【硬牌（使用 0 张配子作百搭代牌）】或构成【大胡（对对胡、混一色、清一色、七对、一条龙）】方可捉铳胡牌；软屁胡禁止捉铳点炮！
''';

const _dalianRules = '''
# 大连穷胡麻将（四门硬条件：开门/三门齐/有横/有幺九 · 报听亮明宝 · 摸宝冲宝胡）
4 人对局，使用万、筒、条、东南西北、白发中全部 34 种共 136 张牌。支持吃（仅上家）、碰、杠、报听、冲宝胡、点炮与自摸胡牌。
# 大连四门硬条件（开门 + 三门齐 + 有横 + 有幺九，或七对）
- 1. 【开门（isOpened）】：必须至少有 1 组明副露（吃、碰、明杠、补杠），或牌型为【七对】；门清普通平胡不可胡牌！
- 2. 【三门齐（hasAllThreeSuits）】：手牌与副露必须同时包含万（m）、筒（p）、条（s）全部三门花色！
- 3. 【有横（hasHeng）】：必须包含至少 1 组刻子/杠牌（碰、杠或手牌暗刻），或以风牌/箭牌（东南西北白发中 1z..7z）作将！
- 4. 【有幺九（hasYaoJiu）】：手牌与副露中必须至少包含 1 张幺九数牌（1、9）或字牌（1z..7z）！
# 报听亮明宝（baoting & baoTile）与摸宝 / 冲宝胡（chongbao）
- 当任意玩家听牌并声明【报听（baoting）】打出舍牌时，牌桌立即亮出本局【明宝（baoTile）】！
- 任何已报听玩家在自己回合摸到【明宝（baoTile）】时，无论该宝牌是否为原本所听之牌，均可立即触发【摸宝 / 冲宝胡（chongbao）】直接自摸获胜，并额外获得 +2 番（×2倍）奖励！
''';

const _gansuRules = '''
# 甘肃兰州麻将（翻混儿百搭 · 甩张报听+2番/×2倍 · 豪华七对+4番 · 无混硬胡+2番）
4 人对局，使用万、筒、条、东南西北、白发中全部 34 种共 136 张牌。支持吃（仅上家）、碰、杠、甩张报听、点炮与自摸胡牌。
# 核心规则
- 1. 【翻混儿（hunTile）】：开局从牌墙翻出混儿指示牌（hunIndicator），同花色或同字牌组循环顺位下一张即为本局万能百搭【混儿（hunTile）】。
- 2. 【甩张报听（shuaizhang，+2番 / ×2倍）】：
  - 当玩家手牌差 1 张即可胡牌（waits 非空）且尚未报听时，可在出牌同时宣告【甩张报听（shuaizhang）】；
  - 甩张报听后手牌锁定（不可吃、碰、杠改牌，摸牌不胡只能摸切），胡牌时额外获得 +2 番且结算总分 ×2 倍加成！
- 3. 【特色大番】：
  - 【豪华七对（+4番）】、【清一色（+4番）】、【对对胡（+2番）】、【一条龙（+2番）】、【门清（+1番）】与【无混硬胡（+2番）】可叠加计番！
''';

final List<GameDef> mahjong12Games = [
  GameDef(
    id: 'yangzhoumj',
    name: '扬州麻将',
    category: '麻将',
    description: '扬州麻将：136张牌，翻配子万能百搭且【白板（5z）顶替配子本牌】，严格区分【软胡自摸 vs 硬牌/大胡可捉铳】！',
    playerRange: (_) => (4, 4),
    rules: _yangzhouRules,
    options: const [
      OptionDef('rounds', '局数', [OptionChoice(4, '4局东风战'), OptionChoice(1, '1局快速')], 4),
      OptionDef('strictRon', '捉铳规则', [OptionChoice(true, '软屁胡禁点炮（硬牌/大胡可捉铳）'), OptionChoice(false, '软硬皆可捉铳')], true),
    ],
    create: YangzhouGame.new,
  ),
  GameDef(
    id: 'dalianmj',
    name: '大连穷胡麻将',
    category: '麻将',
    description: '大连穷胡麻将：136张牌，严守【开门+三门齐+有横+有幺九（或七对）】四门硬条件，报听亮出【明宝】支持【摸宝/冲宝胡（+2番）】！',
    playerRange: (_) => (4, 4),
    rules: _dalianRules,
    options: const [
      OptionDef('rounds', '局数', [OptionChoice(4, '4局东风战'), OptionChoice(1, '1局快速')], 4),
      OptionDef('allowRon', '胡牌方式', [OptionChoice(true, '可点炮可自摸'), OptionChoice(false, '只许自摸')], true),
    ],
    create: DalianGame.new,
  ),
  GameDef(
    id: 'gansumj',
    name: '甘肃兰州麻将',
    category: '麻将',
    description: '甘肃兰州麻将：136张牌翻混儿百搭，支持【甩张报听（+2番/×2倍）】及【豪华七对(+4)/清一色(+4)/对对胡(+2)/无混硬胡(+2)/门清(+1)】！',
    playerRange: (_) => (4, 4),
    rules: _gansuRules,
    options: const [
      OptionDef('rounds', '局数', [OptionChoice(4, '4局东风战'), OptionChoice(1, '1局快速')], 4),
      OptionDef('allowRon', '胡牌方式', [OptionChoice(true, '可点炮可自摸'), OptionChoice(false, '只许自摸')], true),
    ],
    create: GansuGame.new,
  ),
];
