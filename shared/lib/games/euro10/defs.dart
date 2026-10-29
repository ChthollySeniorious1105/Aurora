import '../../src/engine.dart';
import 'everdell.dart';
import 'quacks.dart';
import 'sagrada.dart';
import 'wingspan.dart';

export 'everdell.dart';
export 'quacks.dart';
export 'sagrada.dart';
export 'wingspan.dart';

/// 展翅翱翔 / 奎德林堡的庸医 / 仙境幽谷 / 圣家族大教堂
final List<GameDef> euro10Games = [
  GameDef(
    id: 'wingspan',
    name: '展翅翱翔',
    category: '桌游',
    description: '在森林、草原与湿地三大栖息地招徕鸟类，联动觅食、产蛋与抽牌的褐色能力引擎，争夺保育高分！',
    playerRange: (_) => (1, 5),
    options: const [
      OptionDef(
        'rounds',
        '轮数模式',
        [OptionChoice(4, '4 轮标准'), OptionChoice(3, '3 轮快速')],
        4,
      ),
    ],
    create: Wingspan.new,
    rules: wingspanRules,
  ),
  GameDef(
    id: 'quacks',
    name: '奎德林堡的庸医',
    category: '桌游',
    description: '从个人药袋盲抽药片投入大锅推进轨道，白色樱桃炸弹超过 7 点即会炸锅；采购彩色药片构筑最强魔药袋！',
    playerRange: (_) => (2, 4),
    options: const [
      OptionDef(
        'rounds',
        '轮数模式',
        [OptionChoice(7, '7 轮标准'), OptionChoice(5, '5 轮快速')],
        7,
      ),
    ],
    create: Quacks.new,
    rules: quacksRules,
  ),
  GameDef(
    id: 'everdell',
    name: '仙境幽谷',
    category: '桌游',
    description: '派遣小动物工人采集树枝、树脂、鹅卵石与浆果，通过建筑与动物免费配对联动，在四季更迭中建设 15 卡牌梦幻城市！',
    playerRange: (_) => (1, 4),
    options: const [
      OptionDef(
        'mode',
        '游戏模式',
        [OptionChoice('standard', '四季标准版'), OptionChoice('fast', '三季快速版')],
        'standard',
      ),
    ],
    create: Everdell.new,
    rules: everdellRules,
  ),
  GameDef(
    id: 'sagrada',
    name: '圣家族大教堂',
    category: '桌游',
    description: '蛇形轮抽五色骰子镶嵌 4×5 彩绘玻璃花窗，严守边缘起手、八向相邻、图样约束与正交异色异点铁律！',
    playerRange: (_) => (1, 4),
    options: const [
      OptionDef(
        'rounds',
        '轮数模式',
        [OptionChoice(8, '8 轮标准'), OptionChoice(6, '6 轮快速')],
        8,
      ),
    ],
    create: Sagrada.new,
    rules: sagradaRules,
  ),
];
