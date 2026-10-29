import '../../src/engine.dart';
import 'bloodclock.dart';
import 'dixit.dart';
import 'insider.dart';
import 'rules.dart';

export 'bloodclock.dart';
export 'dixit.dart';
export 'insider.dart';
export 'rules.dart';

const OptionDef _kAiOption = OptionDef(
  'ai',
  'AI 电脑',
  [
    OptionChoice(false, '关'),
    OptionChoice(true, '开（大模型扮演电脑玩家）'),
  ],
  false,
);

/// 血染钟楼·灾祸滋生 / 局内人 / 妙语说书人
final List<GameDef> party6Games = [
  GameDef(
    id: 'bloodclock',
    name: '血染钟楼·灾祸滋生',
    category: '派对',
    description: '系统自动说书人的经典哥特社交推理：小恶魔与爪牙暗夜行凶，镇民与外来者凭蛛丝马迹公投处决真凶，死亡玩家仍可发言并握有一枚死人票！',
    playerRange: (_) => (5, 10),
    options: const [
      _kAiOption,
    ],
    rules: bloodClockRules,
    create: BloodClock.new,
  ),
  GameDef(
    id: 'insider',
    name: '局内人',
    category: '派对',
    description: '二十问猜词与抓内鬼的巧妙融合：大家向主持人提是非问句猜出神秘词，但人群中潜伏着早已知道答案的“局内人”暗中引导方向！',
    playerRange: (_) => (4, 8),
    options: const [
      OptionDef(
        'maxQuestions',
        '提问上限',
        [
          OptionChoice(15, '15 问（紧张）'),
          OptionChoice(20, '20 问（标准）'),
          OptionChoice(25, '25 问（宽松）'),
        ],
        20,
      ),
      OptionDef(
        'words',
        '词库',
        [
          OptionChoice('both', '内置+自定义'),
          OptionChoice('builtin', '仅内置'),
          OptionChoice('custom', '仅自定义'),
        ],
        'both',
      ),
      _kAiOption,
    ],
    rules: insiderRules,
    create: InsiderGame.new,
  ),
  GameDef(
    id: 'dixit',
    name: '妙语说书人',
    category: '派对',
    description: '72 张超现实梦境画牌的诗意联想派对游戏：说书人给出半真半幻的妙语，太直白或太晦涩都会得零分，唯有心有灵犀才能摘取桂冠！',
    playerRange: (_) => (3, 6),
    options: const [
      OptionDef(
        'target',
        '目标分数',
        [
          OptionChoice(18, '18 分（速战）'),
          OptionChoice(24, '24 分（畅玩）'),
          OptionChoice(30, '30 分（标准）'),
        ],
        30,
      ),
      _kAiOption,
    ],
    rules: dixitRules,
    create: DixitGame.new,
  ),
];
