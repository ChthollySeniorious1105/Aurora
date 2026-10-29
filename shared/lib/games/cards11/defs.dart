import '../../src/engine.dart';
import 'bohnanza.dart';
import 'pinochle.dart';
import 'skat.dart';
import 'yaniv.dart';

/// 德国斯卡特 Skat / 皮诺克 Pinochle / 雅尼夫 Yaniv / 种豆得豆 Bohnanza
final List<GameDef> cards11Games = [
  GameDef(
    id: 'skat',
    name: '德国斯卡特 Skat',
    category: '牌类',
    description: '德国国粹 3 人 32 张独庄叫牌与吃墩经典：四张 J（JC>JS>JH>JD）恒为最高四大王牌，'
        '独庄围绕 2 张暗底（Skat）抉择提底埋牌或明手（Hand），挑战花色、大满贯（Grand）或 0 墩全败空门（Null）定约！',
    playerRange: (_) => (3, 3),
    options: const [
      OptionDef('rounds', '对局局数', [
        OptionChoice(3, '3局标准'),
        OptionChoice(1, '1局快速'),
        OptionChoice(6, '6局全庄'),
      ], 3),
    ],
    rules: skatRules,
    create: SkatGame.new,
  ),
  GameDef(
    id: 'pinochle',
    name: '皮诺克 Pinochle',
    category: '牌类',
    description: '欧美殿堂级 48 张双副牌「亮牌组合 + 吃墩」名作：叫分夺庄定主花色，比拼主同花顺（150）、'
        '双皮诺克对（300）、皇家婚姻与四门 A/K/Q/J 组合分，再展开 A>10>K>Q>J>9 12 墩吃墩较量！',
    playerRange: (_) => (2, 4),
    options: const [
      OptionDef('rounds', '对局局数', [
        OptionChoice(2, '2局标准'),
        OptionChoice(1, '1局快速'),
        OptionChoice(4, '4局长局'),
      ], 2),
    ],
    rules: pinochleRules,
    create: PinochleGame.new,
  ),
  GameDef(
    id: 'yaniv',
    name: '雅尼夫 Yaniv',
    category: '牌类',
    description: '风靡全球背包客的快节奏低分比拼与「Assaf 反杀」纸牌：打出单张、对子或百搭同花顺并摸牌压低点数，'
        '满手 <=7 点即可高呼「Yaniv!」，但若有人点数更低或持平将触发 +30 分残酷反杀，踩中整 50/100 分还能瞬间减半！',
    playerRange: (_) => (2, 5),
    options: const [
      OptionDef('targetLimit', '淘汰分线', [
        OptionChoice(100, '100分标准'),
        OptionChoice(60, '60分快速'),
      ], 100),
    ],
    rules: yanivRules,
    create: YanivGame.new,
  ),
  GameDef(
    id: 'bohnanza',
    name: '种豆得豆 Bohnanza',
    category: '牌类',
    description: '乌玫瑰山经典「手牌顺序绝对锁定」种豆与集市赠换卡牌：8 大稀有度各异的豆子品种，'
        '每回合强制种下左手第 1 张牌（hand[0]），严格遵守护豆规则收割兑现金币，翻开集市双豆合纵连横扩建第三豆田！',
    playerRange: (_) => (2, 5),
    options: const [
      OptionDef('deckCycles', '牌库轮数', [
        OptionChoice(1, '1轮牌库（快速）'),
        OptionChoice(2, '2轮牌库（标准）'),
      ], 1),
    ],
    rules: bohnanzaRules,
    create: BohnanzaGame.new,
  ),
];
