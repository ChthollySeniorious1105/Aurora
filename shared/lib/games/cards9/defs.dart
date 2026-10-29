import '../../src/engine.dart';
import 'koikoi.dart';
import 'piquet.dart';
import 'thecrew.dart';

/// 花札·来来 / 星际探险队 / 皮克牌
final List<GameDef> cards9Games = [
  GameDef(
    id: 'koikoi',
    name: '花札·来来 Koi-Koi',
    category: '牌类',
    description: '日本传统 48 张四季花札经典对战：12 月份花草配对捕牌，凑齐五光、猪鹿蝶、花见酒、月见酒、赤短青短等役种后，'
        '面临立即「胜负」收分或高风险高回报「来来 (Koi-Koi)」冲击翻倍的灵魂抉择！',
    playerRange: (_) => (2, 2),
    options: const [
      OptionDef('rounds', '对局月数', [
        OptionChoice(6, '6月半庄'),
        OptionChoice(3, '3月快速'),
        OptionChoice(12, '12月全庄'),
      ], 6),
    ],
    rules: koikoiRules,
    create: KoiKoiGame.new,
  ),
  GameDef(
    id: 'thecrew',
    name: '星际探险队 The Crew',
    category: '桌游',
    description: '荣获德国年度游戏奖的太空合作吃墩佳作：40 张四色数字牌与火箭王牌（R4 持有者担任指挥官），'
        '认领带有顺序标记的任务牌，利用每关一次的无线电通信传递最高/最低/唯一牌情报，协力让正确的船员赢下目标墩！',
    playerRange: (_) => (3, 5),
    options: const [
      OptionDef('missions', '任务关数', [
        OptionChoice(3, '3关连续任务'),
        OptionChoice(1, '1关快速挑战'),
      ], 3),
      OptionDef('difficulty', '任务难度', [
        OptionChoice('normal', '标准模式'),
        OptionChoice('hard', '进阶多任务'),
      ], 'normal'),
    ],
    rules: theCrewRules,
    create: TheCrewGame.new,
  ),
  GameDef(
    id: 'piquet',
    name: '皮克牌 Piquet',
    category: '牌类',
    description: '欧洲殿堂级 32 张双人古典技巧扑克：先手与后手从底牌堆（Talon）策略换牌，'
        '首引前比拼长套（Point）、同花顺（Sequence）与同点组（Set）三大宣告冲击暗倍（Repique +60），再展开 12 墩无主吃墩博弈！',
    playerRange: (_) => (2, 2),
    options: const [
      OptionDef('target', '目标分数', [
        OptionChoice(100, '100分标准'),
        OptionChoice(60, '60分快速'),
      ], 100),
    ],
    rules: piquetRules,
    create: PiquetGame.new,
  ),
];
