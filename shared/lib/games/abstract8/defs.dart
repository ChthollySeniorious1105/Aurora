import '../../src/engine.dart';
import 'fogchess.dart';
import 'stratego.dart';
import 'zertz.dart';

export 'fogchess.dart';
export 'stratego.dart';
export 'zertz.dart';

final List<GameDef> abstract8Games = [
  GameDef(
    id: 'zertz',
    name: '泽茨棋 ZÈRTZ',
    category: '棋类',
    description: '共用黑白灰三色弹珠与不断缩小的六角棋环，强制连跳或放珠移环、割裂孤岛定胜负。',
    playerRange: (_) => (2, 2),
    options: const [
      OptionDef('mode', '目标模式', [
        OptionChoice('standard', '标准 (4白/5灰/6黑/各3)'),
        OptionChoice('quick', '快速 (3白/4灰/5黑/各2)'),
      ], 'standard'),
      OptionDef('board', '棋盘规模', [
        OptionChoice(37, '标准 37 环'),
        OptionChoice(48, '锦标赛 48 环'),
      ], 37),
    ],
    create: ZertzGame.new,
    rules: zertzRules,
    undo: true,
  ),
  GameDef(
    id: 'fogchess',
    name: '雾战国际象棋',
    category: '棋类',
    description: '在战争迷雾中行军的国际象棋：只能看见己方棋子与可达格，无将军限制，直接擒获敌王获胜。',
    playerRange: (_) => (2, 2),
    options: const [
      OptionDef('maxTurns', '回合上限', [
        OptionChoice(160, '标准 160 步'),
        OptionChoice(100, '快速 100 步'),
      ], 160),
    ],
    create: FogChessGame.new,
    rules: fogChessRules,
    undo: false,
  ),
  GameDef(
    id: 'stratego',
    name: '西洋陆战棋 Stratego',
    category: '棋类',
    description: '经典暗棋战场博弈：元帅至侦察兵十级军衔加间谍、工兵、地雷与军旗，间谍刺元帅、工兵排雷、夺旗制胜。',
    playerRange: (_) => (2, 2),
    options: const [
      OptionDef('size', '战场规模', [
        OptionChoice('quick', '8×8 快速军团 (16子)'),
        OptionChoice('standard', '10×10 标准战场 (40子)'),
      ], 'quick'),
      OptionDef('setup', '布阵方式', [
        OptionChoice('auto', '自动开始 (智能布阵)'),
        OptionChoice('manual', '手动微调布阵'),
      ], 'auto'),
    ],
    create: StrategoGame.new,
    rules: strategoRules,
    undo: false,
  ),
];
