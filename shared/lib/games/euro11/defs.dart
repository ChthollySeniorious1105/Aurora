import '../../src/engine.dart';
import 'calico.dart';
import 'photosynthesis.dart';
import 'stoneage.dart';
import 'takenoko.dart';

/// 猫咪与花被 / 熊猫园丁 / 光合作用 / 石器时代
final List<GameDef> euro11Games = [
  GameDef(
    id: 'calico',
    name: '猫咪与花被',
    category: '桌游',
    description: '在 5×5 六边形花被上缝制兼具色彩与图案的双属性布片，达成室内设计目标、缝制彩虹纽扣并吸引猫咪打盹。',
    playerRange: (_) => (1, 4),
    options: const [
      OptionDef(
        'catSetup',
        '猫咪配置',
        [
          OptionChoice('standard', '新手推荐（米莉/提比特/椰子固定图案）'),
          OptionChoice('random', '随机分配猫咪偏爱图案'),
        ],
        'standard',
      ),
    ],
    create: Calico.new,
    rules: calicoRules,
    undo: true,
  ),
  GameDef(
    id: 'takenoko',
    name: '熊猫园丁',
    category: '桌游',
    description: '扩建三色竹园、引水灌溉、指挥园丁培育竹子并引导熊猫品尝鲜笋，完成竹园/园丁/熊猫目标赢取天皇嘉奖。',
    playerRange: (_) => (2, 4),
    options: const [
      OptionDef(
        'targetGoals',
        '终局目标数',
        [
          OptionChoice(6, '标准（6张目标）'),
          OptionChoice(4, '快速（4张目标）'),
        ],
        6,
      ),
    ],
    create: Takenoko.new,
    rules: takenokoRules,
  ),
  GameDef(
    id: 'photosynthesis',
    name: '光合作用',
    category: '桌游',
    description: '随太阳旋转投射 3D 树影，在 19 格森林岛屿上播种、生长并采伐参天大树，争夺核心沃土得分。',
    playerRange: (_) => (2, 4),
    options: const [
      OptionDef(
        'rounds',
        '日照周数',
        [
          OptionChoice(12, '标准（12回合 · 2周日照）'),
          OptionChoice(18, '完整（18回合 · 3周日照）'),
        ],
        12,
      ),
    ],
    create: Photosynthesis.new,
    rules: photosynthesisRules,
    undo: true,
  ),
  GameDef(
    id: 'stoneage',
    name: '石器时代',
    category: '桌游',
    description: '派遣远古族人耕作农田、打造工具、投骰采集木砖石金、建造房屋并收集文明卡科技与倍率，每轮喂养部族。',
    playerRange: (_) => (2, 4),
    options: const [
      OptionDef(
        'rounds',
        '轮数',
        [
          OptionChoice(8, '标准（8轮）'),
          OptionChoice(6, '快速（6轮）'),
        ],
        8,
      ),
    ],
    create: StoneAge.new,
    rules: stoneAgeRules,
  ),
];
