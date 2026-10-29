import '../../src/engine.dart';
import 'canasta.dart';
import 'daifugo.dart';
import 'germanwhist.dart';

/// 德国惠斯特 / 卡纳斯塔 / 大富豪
final List<GameDef> cards10Games = [
  GameDef(
    id: 'germanwhist',
    name: '德国惠斯特',
    category: '牌类',
    description: '经典双人52张两阶段吃墩对决：前13墩不计分，赢家收走牌堆顶翻开的明牌、输家暗摸底牌；'
        '牌堆摸空后进入后13墩决胜战，凭记忆与算牌争夺超过6墩赢取积分！',
    playerRange: (_) => (2, 2),
    options: const [
      OptionDef('hands', '局数', [OptionChoice(1, '1局决胜'), OptionChoice(3, '3局积分赛')], 1),
    ],
    rules: germanWhistRules,
    create: GermanWhist.new,
  ),
  GameDef(
    id: 'canasta',
    name: '卡纳斯塔',
    category: '牌类',
    description: '南美经典拉米组牌游戏：108张双副牌，2与王牌百搭、红3奖励100分、黑3封锁弃牌堆；'
        '凑齐7张同点牌组成纯篮（+500）或混篮（+300），满足至少1个篮后出完手牌即可出局！',
    playerRange: (_) => (2, 4),
    options: const [
      OptionDef('hands', '局数', [OptionChoice(1, '1局决胜'), OptionChoice(2, '2局积分赛')], 1),
    ],
    rules: canastaRules,
    create: Canasta.new,
  ),
  GameDef(
    id: 'daifugo',
    name: '大富豪',
    category: '牌类',
    description: '日本国民阶梯跑牌游戏：四张同点发动【革命】彻底颠倒点数大小，打出8触发【8切】清空桌面连出，'
        '♠3可返杀单王；局间大富豪与大贫民互换2张手牌！',
    playerRange: (_) => (3, 6),
    options: const [
      OptionDef('rounds', '局数', [OptionChoice(3, '3局阶梯赛'), OptionChoice(1, '1局快速')], 3),
      OptionDef('spade3', '黑桃3返王', [OptionChoice(true, '开启（♠3管单王）'), OptionChoice(false, '关闭')], true),
    ],
    rules: daifugoRules,
    create: Daifugo.new,
  ),
];
