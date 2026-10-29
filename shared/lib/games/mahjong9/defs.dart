import '../../src/engine.dart';
import 'changchun.dart';
import 'shenyang.dart';
import 'wenzhou.dart';

const _shenyangRules = '''
# 沈阳麻将（四大硬条件：开门 / 三门齐 / 有横牌 / 有幺九 · 旋风杠 · 翻会牌）
4 人对局，使用万、筒、条、东南西北、白发中全部 34 种共 136 张牌。可吃（仅上家）、碰、杠、旋风杠、点炮或自摸胡牌。
# 沈阳胡牌四大硬条件（缺一不可）
- 1. 【开门（isOpened）】：必须至少有 1 组明副露（吃、碰、明杠、补杠或旋风杠），或牌型为【七对】；门清平胡不可胡牌！
- 2. 【三门齐（hasAllThreeSuits）】：手牌与副露合算必须同时包含万（m）、筒（p）、条（s）全部三门花色！
- 3. 【有横牌（hasHeng）】：必须包含至少 1 组刻子/杠牌（碰、明杠、暗杠、旋风杠或手牌暗刻），或以中、发、白（5z/6z/7z）作将（掌）！
- 4. 【有幺九（hasYaoJiu）】：手牌与副露中必须至少包含 1 张幺九牌（1、9）或字牌（1z..7z）！
# 旋风杠（xfgang）与翻会牌（huiTile）
- 旋风杠：自己回合手握齐备的【东南西北（1z+2z+3z+4z 风杠）】或【白发中（5z+6z+7z 喜杠）】时，可发动旋风杠亮出副露，立即向三家收取杠分并从牌墙补摸 1 张牌！
- 翻会牌：开启【带会牌】模式时，开局翻出指示牌（huiIndicator），同花色或同字牌组循环顺位下一张即为本局万能百搭【会牌（huiTile）】。
''';

const _changchunRules = '''
# 长春麻将（喜蛋 / 风蛋 / 幺蛋 / 九蛋 · 小鸡飞蛋 · 摸宝与抱宝加番）
4 人对局，使用万、筒、条、东南西北、白发中全部 34 种共 136 张牌。支持吃（仅上家）、碰、杠、下蛋、补蛋、点炮与自摸胡牌。
# 下蛋（xiadan）与小鸡飞蛋 / 补蛋（jiadan）
- 轮到自己出牌前，若手中持有以下任意 3 张不同牌组合，即可发动【下蛋】亮出副露，立即向每位对手收取 +2 分并补摸 1 张牌：
  - 【喜蛋】：白、发、中（5z, 6z, 7z）
  - 【风蛋】：东、南、西、北中任意 3 张不同风牌（1z..4z）
  - 【幺蛋】：一万、一筒、一条（1m, 1p, 1s）
  - 【九蛋】：九万、九筒、九条（9m, 9p, 9s）
- 【小鸡飞蛋】：一条（1s 幺鸡）可万能顶替上述任意蛋组合中缺少的 1 张牌！已亮出的蛋后续摸到同组牌或幺鸡可发动【补蛋】继续收分并补牌！
# 宝牌（baoTile：摸宝与抱宝）
- 开局从牌墙翻出宝牌指示牌（baoIndicator），循环下一张即为本局【宝牌（baoTile）】。
- 玩家自摸或点炮胡牌时，若胡牌张正是宝牌（【摸宝】）或手牌/副露中含有宝牌（【抱宝】），总番数额外获得 +2 番加成！
''';

const _wenzhouRules = '''
# 温州麻将（买底与顶底 · 翻财神与白板顶替 · 三财神推倒胡 · 硬牌×2与软牌×1）
4 人对局，使用万、筒、条、东南西北、白发中全部 34 种共 136 张牌。支持吃（仅上家）、碰、杠、点炮与自摸胡牌。
# 第一阶段：买底与顶底（maidi）
- 每局发牌并翻出财神后进入【买底 / 顶底】阶段：庄家选择是否【买底】，闲家各自选择是否【顶底】。
- 买底与顶底均会使双方结算倍数各增加 +1 倍（庄闲均选时结算倍数叠加至 ×3 倍）！
# 翻财神（caishenTile）、白板顶替（5z）与三财神推倒胡
- 翻财神与白板顶替：开局翻出指示牌（caishenIndicator），循环下一张为万能百搭【财神（caishenTile）】；同时【白板（5z）】在牌型组合中直接顶替财神原本的牌面点数与花色参与顺子、刻子与将牌组成！
- 三财神推倒胡：自己回合手握 3 张及以上财神牌时，无需其余手牌成面子，即可直接发动【三财神】自摸胡牌！
- 硬牌与软牌：手牌含 0 张财神或财神仅作为原本牌面自然成牌（未充当百搭代牌）时为【硬牌（×2 番）】；使用财神百搭代牌成胡则为【软牌（×1 番）】！
''';

final List<GameDef> mahjong9Games = [
  GameDef(
    id: 'shenyangmj',
    name: '沈阳麻将',
    category: '麻将',
    description: '沈阳麻将：136张牌，严守【开门、三门齐、有横牌、有幺九】四大胡牌条件，支持东南西北/中发白【旋风杠】与翻会牌百搭！',
    playerRange: (_) => (4, 4),
    rules: _shenyangRules,
    options: const [
      OptionDef('rounds', '局数', [OptionChoice(4, '4局东风战'), OptionChoice(1, '1局快速')], 4),
      OptionDef('useHui', '会牌模式', [OptionChoice(true, '带会牌百搭'), OptionChoice(false, '纯硬胡无会')], true),
    ],
    create: ShenyangGame.new,
  ),
  GameDef(
    id: 'changchunmj',
    name: '长春麻将',
    category: '麻将',
    description: '长春麻将：136张牌，喜蛋/风蛋/幺蛋/九蛋亮出立收三家蛋分，支持【小鸡飞蛋（1s代蛋）】与【摸宝/抱宝（+2番）】！',
    playerRange: (_) => (4, 4),
    rules: _changchunRules,
    options: const [
      OptionDef('rounds', '局数', [OptionChoice(4, '4局东风战'), OptionChoice(1, '1局快速')], 4),
      OptionDef('feidan', '小鸡飞蛋', [OptionChoice(true, '开启（幺鸡可代蛋）'), OptionChoice(false, '关闭（纯正下蛋）')], true),
    ],
    create: ChangchunGame.new,
  ),
  GameDef(
    id: 'wenzhoumj',
    name: '温州麻将',
    category: '麻将',
    description: '温州麻将：136张牌，开局庄家【买底】闲家【顶底】加倍，翻财神且【白板（5z）顶替财神本牌】，支持【三财神推倒胡】与【硬牌×2/软牌×1】！',
    playerRange: (_) => (4, 4),
    rules: _wenzhouRules,
    options: const [
      OptionDef('rounds', '局数', [OptionChoice(4, '4局东风战'), OptionChoice(1, '1局快速')], 4),
      OptionDef('allowRon', '点炮选项', [OptionChoice(true, '可点炮可自摸'), OptionChoice(false, '只许自摸')], true),
    ],
    create: WenzhouGame.new,
  ),
];
