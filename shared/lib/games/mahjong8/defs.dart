import '../../src/engine.dart';
import 'guangxi.dart';
import 'henan.dart';
import 'ningbo.dart';

const _henanRules = '''
# 河南麻将（选跑分 · 翻混儿百搭 · 四混儿直接胡牌）
4 人对局，使用万、筒、条、东南西北、白发中全部 34 种共 136 张牌。不可吃牌，可碰、杠、点炮或自摸胡牌。
# 第一阶段：选跑分（paofen 0~3 分）
- 每局发牌并翻出混儿牌后进入【选跑分（paofen）】阶段，每位玩家自由选择本局跑分（0 分 ~ 3 分）。
- 当任意玩家胡牌（自摸或点炮）或开杠（暗杠、明杠、补杠）时，赢家与每一位付款输家之间的结算金额均额外加上【赢家跑分 + 输家跑分】（+(paofen[winner] + paofen[loser])）！
# 翻混儿（hunTile）与四混儿（sihun）
- 翻混儿：开局从牌墙翻出 1 张混儿指示牌（hunIndicator），同花色或同字牌组循环顺位的下一张即为本局万能百搭【混儿牌（hunTile）】。
- 四混儿：轮到自己行动时，若手中集齐全部 4 张混儿牌，无需其余手牌成面子，即可立即发动【四混儿】直接自摸胡牌并翻倍结算！
''';

const _guangxiRules = '''
# 广西买马麻将（三口承包 / 封胡 · 买马翻倍加番）
4 人对局，使用万、筒、条、东南西北、白发中全部 34 种共 136 张牌。支持吃（仅上家）、碰、杠、点炮与自摸胡牌。
# 三口承包 / 封胡（feedCount[seat][from] >= 3）
- 系统实时记录每位玩家吃、碰、明杠其他玩家副露的口数 `feedCount[seat][from]`。
- 一旦玩家 A 吃/碰/明杠玩家 B 的牌达到 3 口及以上（`feedCount[A][B] >= 3`），A 与 B 立即进入双向【三口承包（Full Liability）】关系：
  - 若 A 自摸胡牌，由 B 一人全额承包全部 3 家闲家的输分（×3），其余两家免赔！
  - 若 B 自摸胡牌，同样由 A 一人全额承包全部 3 家的输分（×3）！
# 买马（horseTiles）与中马加番
- 当有玩家胡牌时，立即从牌墙翻出指定数量（标准 4 匹 / 快速 2 匹）的牌作为本局【马牌（horseTiles）】。
- 按胡牌者所在风位判定中马（庄家东风位中 1/5/9/东/白；南风位中 2/6/南/发；西风位中 3/7/西/中；北风位中 4/8/北）：每中 1 匹马（`matchedHorses++`），总番数额外叠加 `+1 × 基础番（baseFan）`！
''';

const _ningboRules = '''
# 宁波麻将（翻百搭 · 台数计算 · 3台/2台起胡门槛 · 大吊车）
4 人对局，使用万、筒、条、东南西北、白发中全部 34 种共 136 张牌。可吃（仅上家）、碰、杠、点炮或自摸胡牌。
# 翻百搭（baidaTile）与起胡台数门槛（minTai）
- 每局发牌后从牌墙翻出 1 张百搭指示牌（baidaIndicator），同花色或同字牌组循环顺位的下一张即为本局万能百搭【百搭牌（baidaTile）】。
- 严格执行起胡台数门槛（标准 3 台起胡 / 快速 2 台起胡）：只有当手牌总台数 `taiCount >= minTai` 时才允许自摸或点炮胡牌！
# 台数计算明细（taiCount）
- 中 / 发 / 白刻子或杠（5z, 6z, 7z）：每组 `+1` 台
- 风牌刻子或杠（1z..4z）：每组 `+1` 台
- 无百搭（硬胡，手牌中含 0 张百搭牌）：`+1` 台
- 门清 / 自摸：`+1` 台
- 对对胡：`+2` 台；混一色：`+2` 台；清一色：`+4` 台；七对：`+3` 台；大吊车（4 组副露单钓）：`+2` 台！
''';

final List<GameDef> mahjong8Games = [
  GameDef(
    id: 'henanmj',
    name: '河南麻将',
    category: '麻将',
    description: '河南麻将：136张牌，开局选跑分（0~3分）胡牌与杠牌双边加分，翻混儿百搭，手握四张混儿可立即【四混儿】自摸胡牌！',
    playerRange: (_) => (4, 4),
    rules: _henanRules,
    options: const [
      OptionDef('rounds', '局数', [OptionChoice(4, '4局东风战'), OptionChoice(1, '1局快速')], 4),
      OptionDef('allowRon', '点炮选项', [OptionChoice(true, '可点炮可自摸'), OptionChoice(false, '只许自摸')], true),
    ],
    create: HenanGame.new,
  ),
  GameDef(
    id: 'guangximj',
    name: '广西买马麻将',
    category: '麻将',
    description: '广西买马麻将：136张牌，吃碰杠满三口触发双向【三口承包（自摸全包×3）】，胡牌翻墙【买马】按方位中马叠加番数！',
    playerRange: (_) => (4, 4),
    rules: _guangxiRules,
    options: const [
      OptionDef('rounds', '局数', [OptionChoice(4, '4局东风战'), OptionChoice(1, '1局快速')], 4),
      OptionDef('horseCount', '买马数量', [OptionChoice(4, '4匹标准'), OptionChoice(2, '2匹快速')], 4),
    ],
    create: GuangxiGame.new,
  ),
  GameDef(
    id: 'ningbomj',
    name: '宁波麻将',
    category: '麻将',
    description: '宁波麻将：136张牌翻百搭，真实计算中发白、风刻、无百搭、门清自摸、对对胡、混一色、清一色、七对与大吊车台数，够台起胡！',
    playerRange: (_) => (4, 4),
    rules: _ningboRules,
    options: const [
      OptionDef('rounds', '局数', [OptionChoice(4, '4局东风战'), OptionChoice(1, '1局快速')], 4),
      OptionDef('minTai', '起胡台数', [OptionChoice(3, '3台标准'), OptionChoice(2, '2台快速')], 3),
    ],
    create: NingboGame.new,
  ),
];
