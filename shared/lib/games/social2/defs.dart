import '../../src/engine.dart';
import 'chameleon.dart';
import 'rules.dart';
import 'secretpolicy.dart';
import 'themessage.dart';

/// 秘密法案 / 变色龙 / 风声
final List<GameDef> social2Games = [
  GameDef(
    id: 'secretpolicy',
    name: '秘密法案',
    category: '派对',
    description: '自由派与潜伏阵营的议会博弈：提名总理、全体表决、秘密颁布法案，揪出幕后首脑。',
    playerRange: (_) => (5, 10),
    options: const [
      OptionDef(
        'vetoRule',
        '否决权解锁',
        [
          OptionChoice('standard', '标准（5 红法案后）'),
          OptionChoice('early', '提前（4 红法案后）'),
        ],
        'standard',
      ),
      OptionDef(
        'ai',
        'AI 电脑',
        [
          OptionChoice(false, '关'),
          OptionChoice(true, '开（大模型扮演电脑玩家）'),
        ],
        false,
      ),
    ],
    rules: secretPolicyRules,
    create: SecretPolicy.new,
  ),
  GameDef(
    id: 'chameleon',
    name: '变色龙',
    category: '派对',
    description: '4×4 主题词板联想推理：一人潜伏充当变色龙，好人用精妙一词暗语找出变色龙又别暴露答案。',
    playerRange: (_) => (3, 8),
    options: const [
      OptionDef(
        'rounds',
        '轮数',
        [
          OptionChoice(3, '3 轮'),
          OptionChoice(5, '5 轮'),
        ],
        3,
      ),
      OptionDef(
        'tieCatch',
        '平票规则',
        [
          OptionChoice(false, '平票时变色龙逃脱'),
          OptionChoice(true, '最高票含变色龙即被抓'),
        ],
        false,
      ),
      OptionDef(
        'ai',
        'AI 电脑',
        [
          OptionChoice(false, '关'),
          OptionChoice(true, '开（大模型扮演电脑玩家）'),
        ],
        false,
      ),
    ],
    rules: chameleonRules,
    create: Chameleon.new,
  ),
  GameDef(
    id: 'themessage',
    name: '风声',
    category: '桌游',
    description: '潜伏战线、军情处与神秘酱油的谍战交锋：调包、破译、锁定、截获，传递真假情报决出胜负。',
    playerRange: (_) => (4, 7),
    options: const [
      OptionDef(
        'green',
        '阵营配置',
        [
          OptionChoice(true, '标准（含神秘酱油）'),
          OptionChoice(false, '纯阵营对抗（仅红蓝）'),
        ],
        true,
      ),
    ],
    rules: theMessageRules,
    create: TheMessage.new,
  ),
];
