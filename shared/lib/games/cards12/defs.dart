import '../../src/engine.dart';
import 'skullking.dart';
import 'tarot.dart';
import 'tichu.dart';

/// 地主牌 Tichu / 法国塔罗牌 Jeu de Tarot / 骷髅王 Skull King
final List<GameDef> cards12Games = [
  GameDef(
    id: 'tichu',
    name: '地主牌 Tichu',
    category: '牌类',
    description: 'Urs Hostettler 殿堂级 4 人 2v2 搭档 56 张攀爬吃分名作：雀（MJ）许愿强制跟点、犬（DOG）传球搭档、'
        '凤（PHX）百搭与 +0.5 单张、龙（DRG）霸主赠墩，叫地主（±100分）与双关（200:0）巅峰博弈！',
    playerRange: (_) => (4, 4),
    options: const [
      OptionDef('targetScore', '目标分', [
        OptionChoice(300, '300分标准'),
        OptionChoice(200, '200分快速'),
        OptionChoice(500, '500分长局'),
      ], 300),
    ],
    rules: tichuRules,
    create: TichuGame.new,
  ),
  GameDef(
    id: 'tarot',
    name: '法国塔罗牌 Jeu de Tarot',
    category: '牌类',
    description: '法国国粹 78 张塔罗吃墩经典：21 张编号主牌（T1..T21）、免死愚者（T0）与三大关键牌（Oudlers: T1/T21/T0）'
        '动态决定独庄目标分线（56/51/41/36），严格断门强制上打与末墩小主牌（Petit au Bout）加倍决胜！',
    playerRange: (_) => (3, 5),
    options: const [
      OptionDef('rounds', '对局局数', [
        OptionChoice(3, '3局标准'),
        OptionChoice(1, '1局快速'),
        OptionChoice(5, '5局长局'),
      ], 3),
    ],
    rules: tarotRules,
    create: TarotGame.new,
  ),
  GameDef(
    id: 'skullking',
    name: '骷髅王 Skull King',
    category: '牌类',
    description: 'Grandpa Beck 经典「同时暗叫墩数 + 海盗猜拳克制」吃墩杰作：黑旗主牌之上，海盗胜数牌、骷髅王斩海盗（+30/张）、'
        '美人鱼诱捕骷髅王（+40分），女海盗自由切换海盗/白旗逃跑，精准命中的高倍豪赌！',
    playerRange: (_) => (2, 6),
    options: const [
      OptionDef('rounds', '对局轮数', [
        OptionChoice(6, '6轮标准 (1~6张)'),
        OptionChoice(4, '4轮快速 (2~5张)'),
      ], 6),
    ],
    rules: skullKingRules,
    create: SkullKingGame.new,
  ),
];
