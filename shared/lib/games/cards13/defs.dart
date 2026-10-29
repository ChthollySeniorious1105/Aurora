import '../../src/engine.dart';
import 'belote.dart';
import 'cassino.dart';
import 'millebornes.dart';

/// 法国贝洛特 Belote / 卡西诺抓牌 Cassino / 千里之行 Mille Bornes
final List<GameDef> cards13Games = [
  GameDef(
    id: 'belote',
    name: '法国贝洛特 Belote',
    category: '牌类',
    description: '法国第一国民 32 张吃墩纸牌：主牌 J(20分)/9(14分) 逆转乾坤，主花色 K+Q 触发 +20 分 Belote-Rebelote 奖励，'
        '断门强制将吃与超吃，围绕 82 分成约线展开成约与崩盘（Dedans 162 分通吃）的经典博弈！',
    playerRange: (_) => (2, 4),
    options: const [
      OptionDef('rounds', '对局局数', [
        OptionChoice(3, '3局标准'),
        OptionChoice(1, '1局快速'),
        OptionChoice(5, '5局长局'),
      ], 3),
    ],
    rules: beloteRules,
    create: BeloteGame.new,
  ),
  GameDef(
    id: 'cassino',
    name: '卡西诺抓牌 Cassino',
    category: '牌类',
    description: '经典 52 张算术凑点与建堆抓牌（Fishing）名作：合点抓牌（Capture）、预留底牌建堆（Build <= 10）与放牌限制（Trail），'
        '争夺清台（Sweep +1）、大卡西诺（♦10 +2）、小卡西诺（♠2 +1）、四张 A 与最多牌/最多黑桃共 11 分基础大奖！',
    playerRange: (_) => (2, 4),
    options: const [
      OptionDef('rounds', '对局局数', [
        OptionChoice(1, '1局标准 (52张)'),
        OptionChoice(2, '2局累计'),
      ], 1),
    ],
    rules: cassinoRules,
    create: CassinoGame.new,
  ),
  GameDef(
    id: 'millebornes',
    name: '千里之行 Mille Bornes',
    category: '牌类',
    description: '风靡全球的法国公路拉力赛纸牌：绿灯起步冲刺 1000 km，向对手施加红灯、限速50、没油、爆胎、车祸五大故障，'
        '或亮出四大王牌安全卡永久免疫并触发 +300 分 Coup-Fourré 绝妙反击与额外回合！',
    playerRange: (_) => (2, 4),
    options: const [
      OptionDef('target', '目标里程', [
        OptionChoice(1000, '1000 km 标准'),
        OptionChoice(700, '700 km 快速'),
      ], 1000),
    ],
    rules: milleBornesRules,
    create: MilleBornesGame.new,
  ),
];
