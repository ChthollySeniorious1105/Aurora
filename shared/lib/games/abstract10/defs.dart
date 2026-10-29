import '../../src/engine.dart';
import 'epaminondas.dart';
import 'neutreeko.dart';
import 'twixt.dart';

export 'epaminondas.dart';
export 'neutreeko.dart';
export 'twixt.dart';

final List<GameDef> abstract10Games = [
  GameDef(
    id: 'twixt',
    name: '桥联棋 TwixT',
    category: '棋类',
    description: '德国年度游戏奖经典马步搭桥棋：在孔位插桩并自动连接不交叉的马步桥，率先连通己方两侧边界者获胜！',
    playerRange: (_) => (2, 2),
    options: const [
      OptionDef('size', '棋盘尺寸', [
        OptionChoice(12, '12×12 标准'),
        OptionChoice(10, '10×10 快速'),
      ], 12),
    ],
    create: TwixtGame.new,
    rules: twixtRules,
    undo: true,
  ),
  GameDef(
    id: 'epaminondas',
    name: '斜阵冲击棋 Epaminondas',
    category: '棋类',
    description: 'Robert Abbott 经典方阵战术棋：构筑横竖斜连续方阵整体推进，以长击短冲锋歼敌并突破对手底线！',
    playerRange: (_) => (2, 2),
    options: const [
      OptionDef('size', '棋盘规模', [
        OptionChoice('quick', '8×10 快速'),
        OptionChoice('standard', '10×12 标准'),
      ], 'quick'),
    ],
    create: EpaminondasGame.new,
    rules: epaminondasRules,
    undo: true,
  ),
  GameDef(
    id: 'neutreeko',
    name: '滑冰三连棋 Neutreeko',
    category: '棋类',
    description: '5×5 冰面滑行三子连珠策略棋：棋子向八方向一滑到底直至触壁或遇子阻挡，率先连成紧邻三子者获胜！',
    playerRange: (_) => (2, 2),
    create: NeutreekoGame.new,
    rules: neutreekoRules,
    undo: true,
  ),
];
