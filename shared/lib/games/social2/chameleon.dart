import '../../src/ai.dart';
import '../../src/engine.dart';

class ChameleonTopic {
  final String title;
  final List<String> words; // 16 words (4x4)
  final Map<String, List<String>> wordClues;
  final List<String> chameleonClues;

  const ChameleonTopic({
    required this.title,
    required this.words,
    required this.wordClues,
    required this.chameleonClues,
  });
}

const List<ChameleonTopic> chameleonTopics = [
  ChameleonTopic(
    title: '动物',
    words: [
      '大熊猫', '长颈鹿', '企鹅', '袋鼠',
      '北极熊', '变色龙', '海豚', '猫头鹰',
      '大象', '孔雀', '考拉', '骆驼',
      '猎豹', '火烈鸟', '刺猬', '章鱼',
    ],
    wordClues: {
      '大熊猫': ['竹子', '国宝', '黑白', '四川'],
      '长颈鹿': ['高挑', '树叶', '脖子', '斑纹'],
      '企鹅': ['南极', '燕尾服', '摇摆', '冰川'],
      '袋鼠': ['跳跃', '育儿袋', '澳洲', '拳击'],
      '北极熊': ['浮冰', '雪白', '严寒', '荒原'],
      '变色龙': ['伪装', '舌头', '树枝', '保护色'],
      '海豚': ['声呐', '回声', '聪慧', '跃水'],
      '猫头鹰': ['夜行', '守夜', '森林', '转头'],
      '大象': ['长鼻', '象牙', '厚重', '温厚'],
      '孔雀': ['开屏', '尾羽', '绚丽', '云南'],
      '考拉': ['桉树', '嗜睡', '树栖', '呆萌'],
      '骆驼': ['沙漠', '驼峰', '绿洲', '商队'],
      '猎豹': ['疾驰', '斑点', '冲刺', '草原'],
      '火烈鸟': ['粉红', '单腿', '浅滩', '修长'],
      '刺猬': ['尖刺', '蜷缩', '防御', '灌木'],
      '章鱼': ['触手', '墨汁', '吸盘', '深海'],
    },
    chameleonClues: ['野生', '自然', '生灵', '栖息', '温和', '奇特', '动物园', '纪录片'],
  ),
  ChameleonTopic(
    title: '美食',
    words: [
      '火锅', '寿司', '披萨', '北京烤鸭',
      '小笼包', '拉面', '牛排', '麻辣烫',
      '蛋炒饭', '烤肉', '煎饼果子', '螺蛳粉',
      '红烧肉', '饺子', '咖喱饭', '炸鸡',
    ],
    wordClues: {
      '火锅': ['沸腾', '毛肚', '鸳鸯锅', '蘸料'],
      '寿司': ['芥末', '海苔', '醋饭', '刺身'],
      '披萨': ['芝士', '拉丝', '烘烤', '切角'],
      '北京烤鸭': ['片皮', '甜面酱', '薄饼', '果木'],
      '小笼包': ['汤汁', '蒸笼', '褶子', '姜丝'],
      '拉面': ['高汤', '筋道', '豚骨', '叉烧'],
      '牛排': ['五分熟', '黑椒', '刀叉', '铁板'],
      '麻辣烫': ['自选', '签子', '浓汤', '麻酱'],
      '蛋炒饭': ['隔夜饭', '葱花', '粒粒分明', '颠勺'],
      '烤肉': ['炭火', '生菜', '滋滋响', '五花'],
      '煎饼果子': ['薄脆', '早餐摊', '摊平', '刷酱'],
      '螺蛳粉': ['酸笋', '柳州', '腐竹', '浓郁'],
      '红烧肉': ['浓油赤酱', '冰糖', '五花', '软糯'],
      '饺子': ['冬至', '擀皮', '蘸醋', '团圆'],
      '咖喱饭': ['浓郁酱汁', '土豆胡萝卜', '姜黄', '拌饭'],
      '炸鸡': ['酥脆', '金黄', '啤酒', '裹粉'],
    },
    chameleonClues: ['香气', '饱腹', '聚餐', '夜宵', '热腾腾', '招牌', '美味', '回味'],
  ),
  ChameleonTopic(
    title: '电影',
    words: [
      '泰坦尼克号', '盗梦空间', '阿凡达', '星际穿越',
      '千与千寻', '肖申克的救赎', '黑客帝国', '流浪地球',
      '教父', '哈利波特', '侏罗纪公园', '狮子王',
      '功夫', '卧虎藏龙', '疯狂动物城', '寻梦环游记',
    ],
    wordClues: {
      '泰坦尼克号': ['冰山', '巨轮', '海洋之心', '甲板'],
      '盗梦空间': ['陀螺', '潜意识', '造梦', '折叠城市'],
      '阿凡达': ['潘多拉', '蓝皮肤', '神树', '悬浮山'],
      '星际穿越': ['虫洞', '黑洞', '五维空间', '玉米地'],
      '千与千寻': ['汤屋', '无脸男', '海上列车', '神隐'],
      '肖申克的救赎': ['越狱', '小锤子', '暴雨', '自由'],
      '黑客帝国': ['红蓝药丸', '代码雨', '母体', '躲子弹'],
      '流浪地球': ['行星发动机', '木星', '地下城', '推进'],
      '教父': ['黑帮', '西西里', '家族', '玫瑰'],
      '哈利波特': ['魔杖', '霍格沃茨', '猫头鹰信使', '扫帚'],
      '侏罗纪公园': ['琥珀', '暴龙', '基因复活', '海岛'],
      '狮子王': ['荣耀石', '草原日出', '成长', '辛巴'],
      '功夫': ['斧头帮', '包租婆', '如来神掌', '猪笼城寨'],
      '卧虎藏龙': ['竹林', '青冥剑', '江湖', '轻功'],
      '疯狂动物城': ['树懒', '警官', '狐兔', '都市'],
      '寻梦环游记': ['万寿菊', '吉他', '亡灵节', '家族记忆'],
    },
    chameleonClues: ['经典', '银幕', '票房', '配乐', '震撼', '名作', '导演', '影院'],
  ),
  ChameleonTopic(
    title: '运动',
    words: [
      '足球', '篮球', '羽毛球', '乒乓球',
      '游泳', '网球', '马拉松', '滑雪',
      '击剑', '射箭', '排球', '体操',
      '拳击', '高尔夫', '攀岩', '花样滑冰',
    ],
    wordClues: {
      '足球': ['绿茵场', '点球', '越位', '世界杯'],
      '篮球': ['三分线', '扣篮', '篮板', '运球'],
      '羽毛球': ['扣杀', '高远球', '球拍', '吊球'],
      '乒乓球': ['国球', '旋转', '直拍', '削球'],
      '游泳': ['泳道', '换气', '蛙姿', '浪花'],
      '网球': ['大满贯', '红土', '草地', '发球局'],
      '马拉松': ['四十二公里', '耐力', '补给站', '撞线'],
      '滑雪': ['雪道', '雪板', '高山', '缆车'],
      '击剑': ['面罩', '花剑', '突刺', '剑道'],
      '射箭': ['靶心', '满弓', '箭袋', '十环'],
      '排球': ['拦网', '二传', '扣球', '垫球'],
      '体操': ['平衡木', '吊环', '鞍马', '转体'],
      '拳击': ['拳套', '擂台', '勾拳', '读秒'],
      '高尔夫': ['果岭', '球杆', '沙坑', '一杆进洞'],
      '攀岩': ['岩点', '安全绳', '峭壁', '镁粉'],
      '花样滑冰': ['冰刀', '旋转跳跃', '冰面', '艺术分'],
    },
    chameleonClues: ['竞技', '奥运', '汗水', '赛场', '训练', '体能', '金牌', '裁判'],
  ),
  ChameleonTopic(
    title: '国家',
    words: [
      '中国', '日本', '法国', '意大利',
      '埃及', '巴西', '澳大利亚', '瑞士',
      '冰岛', '希腊', '加拿大', '泰国',
      '英国', '德国', '墨西哥', '挪威',
    ],
    wordClues: {
      '中国': ['长城', '汉字', '丝绸', '茶文化'],
      '日本': ['樱花', '富士山', '温泉', '新干线'],
      '法国': ['铁塔', '卢浮宫', '浪漫', '香颂'],
      '意大利': ['斗兽场', '水城', '文艺复兴', '靴子形'],
      '埃及': ['金字塔', '尼罗河', '法老', '狮身人面'],
      '巴西': ['桑巴', '雨林', '嘉年华', '热情'],
      '澳大利亚': ['歌剧院', '大堡礁', '南半球', '红土中心'],
      '瑞士': ['阿尔卑斯', '钟表', '中立', '雪山'],
      '冰岛': ['极光', '间歇泉', '火山', '冰川湖'],
      '希腊': ['爱琴海', '神庙', '蓝白小屋', '奥林匹斯'],
      '加拿大': ['枫叶', '落基山', '冰雪', '广袤'],
      '泰国': ['大皇宫', '热带', '夜市', '冬阴功'],
      '英国': ['大本钟', '下午茶', '雾都', '泰晤士'],
      '德国': ['啤酒节', '古堡', '严谨', '工业'],
      '墨西哥': ['仙人掌', '草帽', '玛雅', '玉米饼'],
      '挪威': ['峡湾', '午夜太阳', '北欧', '极圈'],
    },
    chameleonClues: ['旅游', '文化', '风情', '疆域', '历史', '地标', '签证', '航线'],
  ),
  ChameleonTopic(
    title: '职业',
    words: [
      '医生', '教师', '程序员', '厨师',
      '宇航员', '消防员', '侦探', '建筑师',
      '飞行员', '画家', '律师', '考古学家',
      '魔术师', '摄影师', '交响乐指挥', '航海家',
    ],
    wordClues: {
      '医生': ['听诊器', '白大褂', '处方', '问诊'],
      '教师': ['讲台', '粉笔', '备课', '桃李'],
      '程序员': ['代码', '键盘', '调试', '算法'],
      '厨师': ['高帽', '颠勺', '火候', '调味'],
      '宇航员': ['失重', '太空舱', '星辰', '舱外'],
      '消防员': ['云梯', '水枪', '逆行', '警铃'],
      '侦探': ['放大镜', '推理', '脚印', '真相'],
      '建筑师': ['蓝图', '结构', '地标', '空间'],
      '飞行员': ['驾驶舱', '云层', '航线', '塔台'],
      '画家': ['调色盘', '画布', '写生', '笔触'],
      '律师': ['辩护', '法条', '卷宗', '法庭'],
      '考古学家': ['洛阳铲', '遗迹', '毛刷', '地层'],
      '魔术师': ['礼帽', '障眼法', '扑克', '奇迹'],
      '摄影师': ['快门', '构图', '光影', '镜头'],
      '交响乐指挥': ['燕尾服', '乐谱', '节拍', '乐团'],
      '航海家': ['罗盘', '风帆', '远洋', '海图'],
    },
    chameleonClues: ['专业', '岗位', '技能', '敬业', '资深', '历练', '使命', '专注'],
  ),
  ChameleonTopic(
    title: '水果',
    words: [
      '西瓜', '榴莲', '草莓', '芒果',
      '葡萄', '菠萝', '荔枝', '猕猴桃',
      '樱桃', '香蕉', '山竹', '火龙果',
      '水蜜桃', '蓝莓', '石榴', '椰子',
    ],
    wordClues: {
      '西瓜': ['盛夏', '冰镇', '绿皮红瓤', '吐籽'],
      '榴莲': ['浓烈', '硬刺', '猫山王', '金枕'],
      '草莓': ['红艳', '奶油甜点', '果园采摘', '芝麻点'],
      '芒果': ['热带金黄', '甜滑', '西米露', '大核'],
      '葡萄': ['一串串', '酿酒', '藤蔓', '紫晶'],
      '菠萝': ['盐水泡', '凤梨酥', '菱形格', '叶子扎手'],
      '荔枝': ['一骑红尘', '晶莹半透明', '岭南', '剥壳'],
      '猕猴桃': ['绒毛皮', '维C', '奇异', '翠绿果肉'],
      '樱桃': ['深红小巧', '车厘子', '果柄', '蛋糕点缀'],
      '香蕉': ['弯月', '剥皮', '补充体力', '黄皮'],
      '山竹': ['果后', '紫厚壳', '蒜瓣果肉', '清甜'],
      '火龙果': ['仙人掌科', '黑籽', '紫红心', '鳞片外壳'],
      '水蜜桃': ['粉嫩绒毛', '多汁', '阳山', '寿桃'],
      '蓝莓': ['护眼', '白霜', '深蓝果酱', '小浆果'],
      '石榴': ['红宝石籽', '多子', '剥粒', '晶莹'],
      '椰子': ['海风沙滩', '吸管清汁', '硬壳', '高树'],
    },
    chameleonClues: ['鲜甜', '多汁', '时令', '果篮', '清爽', '维生素', '成熟', '果香'],
  ),
  ChameleonTopic(
    title: '乐器',
    words: [
      '钢琴', '小提琴', '吉他', '古筝',
      '二胡', '架子鼓', '萨克斯', '长笛',
      '琵琶', '大提琴', '手风琴', '竖琴',
      '唢呐', '口琴', '编钟', '尤克里里',
    ],
    wordClues: {
      '钢琴': ['黑白键', '踏板', '乐器之王', '奏鸣曲'],
      '小提琴': ['琴弓', '肩托', '四根弦', '协奏'],
      '吉他': ['六弦', '民谣', '扫弦', '拨片'],
      '古筝': ['二十一弦', '高山流水', '义甲', '雁柱'],
      '二胡': ['赛马', '两根弦', '凄美', '弓毛'],
      '架子鼓': ['鼓槌', '踩镲', '节奏感', '摇滚'],
      '萨克斯': ['爵士', '黄铜弯管', '吹奏', '浪漫'],
      '长笛': ['横吹', '金属银管', '清亮', '木管组'],
      '琵琶': ['大珠小珠', '十面埋伏', '半遮面', '轮指'],
      '大提琴': ['低沉浑厚', '坐姿夹琴', '天鹅', '长尾柱'],
      '手风琴': ['风箱', '推拉', '喀秋莎', '背带'],
      '竖琴': ['天使', '拨弦', '三角框架', '梦幻'],
      '唢呐': ['百鸟朝凤', '高亢穿透', '红白喜事', '喇叭口'],
      '口琴': ['口袋随身', '吸吹', '簧片', '布鲁斯'],
      '编钟': ['青铜礼器', '曾侯乙', '木槌敲击', '古音'],
      '尤克里里': ['夏威夷', '四弦小巧', '海滩弹唱', '欢快'],
    },
    chameleonClues: ['旋律', '音色', '独奏', '共鸣', '音符', '演奏', '舞台', '古典'],
  ),
  ChameleonTopic(
    title: '交通工具',
    words: [
      '高铁', '飞机', '地铁', '自行车',
      '游轮', '热气球', '直升机', '帆船',
      '潜艇', '摩托车', '缆车', '双层巴士',
      '有轨电车', '雪橇', '宇宙飞船', '皮划艇',
    ],
    wordClues: {
      '高铁': ['复兴号', '铁轨', '平稳迅速', '站台'],
      '飞机': ['机翼', '跑道起降', '万米高空', '舷窗'],
      '地铁': ['隧道', '换乘', '早晚高峰', '地下交通'],
      '自行车': ['脚踏', '链条', '车把', '低碳骑行'],
      '游轮': ['甲板', '远洋度假', '船舱', '汽笛'],
      '热气球': ['吊篮', '火焰升空', '卡帕多奇亚', '随风飘'],
      '直升机': ['旋翼', '悬停', '停机坪', '救援'],
      '帆船': ['借风', '桅杆', '乘风破浪', '海面'],
      '潜艇': ['深海潜航', '潜望镜', '声呐', '水密舱'],
      '摩托车': ['头盔', '引擎轰鸣', '两轮', '油门'],
      '缆车': ['钢索', '山谷跨越', '悬空车厢', '观景'],
      '双层巴士': ['上层观光', '红色车身', '城市漫游', '楼梯'],
      '有轨电车': ['铛铛声', '街道轨道', '复古', '集电弓'],
      '雪橇': ['冰原滑行', '驯鹿', '极地', '雪地'],
      '宇宙飞船': ['火箭助推', '星际轨道', '对接舱', '太空'],
      '皮划艇': ['双叶桨', '激流', '单人狭长', '划水'],
    },
    chameleonClues: ['出行', '旅途', '速度', '远方', '乘客', '动力', '路线', '抵达'],
  ),
  ChameleonTopic(
    title: '神话人物',
    words: [
      '孙悟空', '哪吒', '嫦娥', '雅典娜',
      '宙斯', '雷神托尔', '波塞冬', '阿波罗',
      '姜子牙', '二郎神', '精卫', '女娲',
      '夸父', '普罗米修斯', '丘比特', '美杜莎',
    ],
    wordClues: {
      '孙悟空': ['金箍棒', '筋斗云', '火眼金睛', '花果山'],
      '哪吒': ['风火轮', '混天绫', '莲花化身', '乾坤圈'],
      '嫦娥': ['广寒宫', '玉兔', '奔月', '桂树'],
      '雅典娜': ['智慧女神', '猫头鹰圣鸟', '盾牌', '雅典守护'],
      '宙斯': ['众神之王', '雷霆闪电', '奥林匹斯山', '神王'],
      '雷神托尔': ['妙尔尼尔战锤', '阿斯加德', '北欧神', '雷电'],
      '波塞冬': ['三叉戟', '海皇', '掀起巨浪', '深海神殿'],
      '阿波罗': ['太阳金车', '竖琴与箭', '光明预言', '桂冠'],
      '姜子牙': ['封神榜', '直钩垂钓', '愿者上钩', '渭水'],
      '二郎神': ['天眼', '哮天犬', '三尖两刃刀', '七十二变'],
      '精卫': ['衔木石', '填沧海', '炎帝之女', '不屈小鸟'],
      '女娲': ['五彩石', '补苍天', '抟土造人', '上古圣母'],
      '夸父': ['逐日', '饮干黄河', '桃林手杖', '巨人'],
      '普罗米修斯': ['盗取火种', '高加索山', '造福人类', '先知泰坦'],
      '丘比特': ['爱神之箭', '小翅膀', '金箭铅箭', '一见钟情'],
      '美杜莎': ['蛇发', '凝视石化', '盾牌倒影', '戈耳工'],
    },
    chameleonClues: ['传说', '神力', '史诗', '古老', '信仰', '故事', '不朽', '传奇'],
  ),
  ChameleonTopic(
    title: '日常用品',
    words: [
      '雨伞', '闹钟', '保温杯', '指甲刀',
      '吹风机', '牙刷', '梳子', '台灯',
      '钥匙', '眼镜', '剪刀', '镜子',
      '手电筒', '充电宝', '抱枕', '拖鞋',
    ],
    wordClues: {
      '雨伞': ['遮雨', '伞骨', '撑开', '屋檐水滴'],
      '闹钟': ['清晨铃声', '赖床', '定时唤醒', '指针滴答'],
      '保温杯': ['真空夹层', '热水', '随身喝水', '拧盖'],
      '指甲刀': ['修剪', '金属小杠杆', '磨砂锉', '指尖'],
      '吹风机': ['热风', '洗头后', '嗡嗡声', '干发'],
      '牙刷': ['刷毛', '早晚清洁', '牙膏搭档', '漱口杯'],
      '梳子': ['理顺发丝', '齿列', '木质或牛角', '清晨整理'],
      '台灯': ['书桌照明', '灯罩', '夜读', '护眼光源'],
      '钥匙': ['齿痕', '开锁', '金属环串', '门锁拍档'],
      '眼镜': ['镜片度数', '鼻托', '镜框', '清晰视野'],
      '剪刀': ['双刃交叉', '裁纸', '支点', '咔嚓'],
      '镜子': ['反光映像', '梳妆', '玻璃镀银', '对称人影'],
      '手电筒': ['光束', '夜间照明', '停电备用', '聚光'],
      '充电宝': ['续航救急', '移动电源', '数据线', '电量格'],
      '抱枕': ['沙发靠垫', '柔软填充', '怀抱', '棉麻套'],
      '拖鞋': ['居家换穿', '防滑鞋底', '轻便放松', '玄关'],
    },
    chameleonClues: ['实用', '居家', '顺手', '常备', '生活', '便捷', '随手', '高频'],
  ),
  ChameleonTopic(
    title: '自然景观',
    words: [
      '极光', '瀑布', '沙漠', '珊瑚礁',
      '冰川', '火山', '峡谷', '热带雨林',
      '溶洞', '星空', '彩虹', '梯田',
      '间歇泉', '雪山', '青海湖', '丹霞地貌',
    ],
    wordClues: {
      '极光': ['高纬夜空', '绿紫光带', '太阳风', '绚丽天幕'],
      '瀑布': ['飞流直下', '水雾轰鸣', '悬崖落差', '深潭'],
      '沙漠': ['沙丘连绵', '海市蜃楼', '干旱', '绿洲'],
      '珊瑚礁': ['海底花园', '五彩鱼群', '浅海生态', '钙质骨骼'],
      '冰川': ['万年寒冰', '蓝色冰舌', '缓慢移动', '极寒'],
      '火山': ['岩浆喷发', '熔岩', '地壳裂缝', '地热'],
      '峡谷': ['两岸峭壁', '急流切割', '深邃', '回音'],
      '热带雨林': ['藤蔓交错', '地球之肺', '潮湿多雨', '物种宝库'],
      '溶洞': ['钟乳石', '石笋', '地下暗河', '喀斯特'],
      '星空': ['银河璀璨', '猎户座', '夜幕繁星', '天文观测'],
      '彩虹': ['雨后天晴', '七色拱桥', '阳光折射', '天际'],
      '梯田': ['层层等高线', '山坡水镜', '农耕杰作', '云雾缭绕'],
      '间歇泉': ['周期喷涌', '沸水蒸汽柱', '地热奇观', '泉眼'],
      '雪山': ['终年积雪', '日照金山', '高海拔峰峦', '圣洁'],
      '青海湖': ['高原蓝宝石', '油菜花海', '候鸟咸水', '辽阔湖面'],
      '丹霞地貌': ['赤壁丹崖', '红砂岩层', '七彩山峦', '风化奇峰'],
    },
    chameleonClues: ['壮丽', '奇观', '风光', '鬼斧神工', '摄影', '震撼', '远足', '大自然'],
  ),
];

String chameleonCoord(int index) {
  final r = (index ~/ 4).clamp(0, 3);
  final c = (index % 4) + 1;
  return '${"ABCD"[r]}$c';
}

class Chameleon extends GameEngine {
  Chameleon(super.setup);

  final AiSlot _ai = AiSlot();

  late List<int> scores;
  final List<int> _usedTopicIndices = [];

  int round = 1;
  late int maxRounds;
  late bool tieCatch;

  late ChameleonTopic currentTopic;
  int chameleonSeat = 0;
  int secretIndex = 0;
  int startSeat = 0;
  int turnOffset = 0;

  /// Phases: clue, vote, guess, roundEnd, over
  String phase = 'clue';

  final List<Map<String, dynamic>> clues = [];
  final Map<int, int> votes = {};
  final Set<int> readyNext = {};
  final List<Map<String, dynamic>> roundHistory = [];
  Map<String, dynamic>? lastRoundResult;

  String winner = '';
  String reason = '';

  int get currentTurn => (startSeat + turnOffset) % players;
  String get secretWord => currentTopic.words[secretIndex];

  @override
  bool get isOver => phase == 'over';

  @override
  int get botDelayMs => 700;

  @override
  List<int>? get placings => isOver ? rankByScore(scores) : null;

  @override
  void start() {
    scores = List.filled(players, 0);
    maxRounds = setup.opt<int>('rounds', 3);
    tieCatch = setup.opt<bool>('tieCatch', false);
    startSeat = rng.nextInt(players);
    _startRound(1);
  }

  void _startRound(int r) {
    round = r;
    final available = [
      for (var i = 0; i < chameleonTopics.length; i++)
        if (!_usedTopicIndices.contains(i)) i,
    ];
    final pool = available.isNotEmpty
        ? available
        : [for (var i = 0; i < chameleonTopics.length; i++) i];
    final topicIdx = pool[rng.nextInt(pool.length)];
    _usedTopicIndices.add(topicIdx);
    currentTopic = chameleonTopics[topicIdx];

    chameleonSeat = rng.nextInt(players);
    secretIndex = rng.nextInt(16);
    startSeat = (startSeat + 1) % players;
    turnOffset = 0;
    clues.clear();
    votes.clear();
    readyNext.clear();
    phase = 'clue';
    host.log('第 $round/$maxRounds 轮开始！主题：【${currentTopic.title}】，由 ${name(currentTurn)} 率先发言');
  }

  /// Validate a clue string so it's non-empty, short, and never equals/contains any board word.
  static bool isValidClue(String raw, List<String> boardWords) {
    final cleaned = AiText.firstLine(raw, maxLen: 16).replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty || cleaned.length > 12) return false;
    for (final w in boardWords) {
      if (cleaned == w || cleaned.contains(w)) return false;
    }
    return true;
  }

  @override
  List<int> get waitingFor {
    if (isOver) return const [];
    switch (phase) {
      case 'clue':
        return [currentTurn];
      case 'vote':
        return [
          for (var s = 0; s < players; s++)
            if (!votes.containsKey(s)) s,
        ];
      case 'guess':
        return [chameleonSeat];
      case 'roundEnd':
        return [
          for (var s = 0; s < players; s++)
            if (!readyNext.contains(s)) s,
        ];
      default:
        return const [];
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('对局已结束');
    if (seat < 0 || seat >= players) throw GameError('无效座位');
    final type = asStr(action['type']);

    switch (phase) {
      case 'clue':
        if (seat != currentTurn) throw GameError('还没轮到你发言');
        if (type != 'clue') throw GameError('请提交你的线索词');
        final text = AiText.firstLine(asStr(action['text']), maxLen: 16).trim();
        if (text.isEmpty) throw GameError('线索词不能为空');
        if (text.length > 12) throw GameError('线索词过长（最多 12 个字）');
        if (currentTopic.words.any((w) => text == w || text.contains(w))) {
          throw GameError('线索不能直接包含题目卡上的词语');
        }
        clues.add({'seat': seat, 'text': text});
        host.log('${name(seat)} 给出线索：「$text」');
        turnOffset++;
        if (turnOffset >= players) {
          phase = 'vote';
          host.log('全员发言完毕！请投票指认谁是变色龙');
        }
        break;

      case 'vote':
        if (type != 'vote') throw GameError('请投票指认变色龙');
        if (votes.containsKey(seat)) throw GameError('你已经投过票了');
        final target = asInt(action['target']);
        if (target < 0 || target >= players) throw GameError('无效的投票目标');
        votes[seat] = target;
        if (votes.length == players) {
          _resolveVotes();
        }
        break;

      case 'guess':
        if (seat != chameleonSeat) throw GameError('等待变色龙反猜秘密词');
        if (type != 'guess') throw GameError('请在题目卡上点击要猜的词');
        final idx = asInt(action['index']);
        if (idx < 0 || idx >= 16) throw GameError('无效的词语位置');
        final right = idx == secretIndex;
        final delta = List.filled(players, 0);
        if (right) {
          scores[chameleonSeat] += 1;
          delta[chameleonSeat] = 1;
          host.log('变色龙 ${name(chameleonSeat)} 反猜「${currentTopic.words[idx]}」正确！获得 +1 分');
        } else {
          for (var s = 0; s < players; s++) {
            if (s != chameleonSeat) {
              scores[s] += 2;
              delta[s] = 2;
            }
          }
          host.log(
            '变色龙 ${name(chameleonSeat)} 猜了「${currentTopic.words[idx]}」，但秘密词是「$secretWord」！普通玩家各 +2 分',
          );
        }
        _finishRound(
          caught: true,
          guessIndex: idx,
          guessedRight: right,
          delta: delta,
          outcome: right ? '变色龙反猜成功（+1分）' : '好人阵营识破变色龙（各+2分）',
        );
        break;

      case 'roundEnd':
        if (type != 'next') throw GameError('请点击继续进入下一轮');
        readyNext.add(seat);
        if (readyNext.length == players) {
          _startRound(round + 1);
        }
        break;

      default:
        throw GameError('当前阶段无法执行此操作');
    }
  }

  void _resolveVotes() {
    final tally = List.filled(players, 0);
    for (final t in votes.values) {
      tally[t]++;
    }
    var maxV = 0;
    for (final c in tally) {
      if (c > maxV) maxV = c;
    }
    final topSeats = [for (var s = 0; s < players; s++) if (tally[s] == maxV) s];
    final caught = tieCatch
        ? topSeats.contains(chameleonSeat)
        : (topSeats.length == 1 && topSeats.first == chameleonSeat);

    if (caught) {
      phase = 'guess';
      host.log('投票结束：变色龙 ${name(chameleonSeat)} 被成功抓获！现在有 1 次机会反猜秘密词');
    } else {
      final delta = List.filled(players, 0);
      scores[chameleonSeat] += 2;
      delta[chameleonSeat] = 2;
      host.log('投票结束：变色龙 ${name(chameleonSeat)} 成功潜伏逃脱（+2分）！本轮秘密词为「$secretWord」');
      _finishRound(
        caught: false,
        guessIndex: -1,
        guessedRight: false,
        delta: delta,
        outcome: '变色龙成功逃脱（+2分）',
      );
    }
  }

  void _finishRound({
    required bool caught,
    required int guessIndex,
    required bool guessedRight,
    required List<int> delta,
    required String outcome,
  }) {
    lastRoundResult = {
      'round': round,
      'topic': currentTopic.title,
      'chameleon': chameleonSeat,
      'secretIndex': secretIndex,
      'secretCoord': chameleonCoord(secretIndex),
      'secretWord': secretWord,
      'caught': caught,
      'guessIndex': guessIndex,
      'guessWord': guessIndex >= 0 && guessIndex < 16 ? currentTopic.words[guessIndex] : null,
      'guessedRight': guessedRight,
      'delta': delta,
      'votes': {for (final e in votes.entries) '${e.key}': e.value},
      'clues': List<Map<String, dynamic>>.of(clues),
      'outcome': outcome,
    };
    roundHistory.add(lastRoundResult!);

    if (round >= maxRounds) {
      phase = 'over';
      var best = 0;
      for (final sc in scores) {
        if (sc > best) best = sc;
      }
      final winners = [for (var s = 0; s < players; s++) if (scores[s] == best) name(s)];
      winner = winners.join('、');
      reason = '经过 $maxRounds 轮角逐，$winner 以 $best 分夺冠！';
      host.log('游戏结束！$reason');
    } else {
      phase = 'roundEnd';
      readyNext.clear();
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players;
    final revealSecret = phase == 'guess' || phase == 'roundEnd' || phase == 'over';
    final isChameleon = me && seat == chameleonSeat;
    final canSeeWord = (me && !isChameleon) || (revealSecret && phase != 'guess');

    return {
      'phase': phase,
      'round': round,
      'maxRounds': maxRounds,
      'tieCatch': tieCatch,
      'topic': currentTopic.title,
      'words': currentTopic.words,
      'startSeat': startSeat,
      'turn': phase == 'clue' ? currentTurn : -1,
      'myRole': me ? (isChameleon ? 'chameleon' : 'citizen') : null,
      'secretIndex': canSeeWord ? secretIndex : -1,
      'secretCoord': canSeeWord ? chameleonCoord(secretIndex) : null,
      'secretWord': canSeeWord ? secretWord : null,
      'chameleonSeat': revealSecret ? chameleonSeat : (isChameleon ? seat : -1),
      'clues': clues,
      'voted': [for (var s = 0; s < players; s++) votes.containsKey(s)],
      'myVote': me && votes.containsKey(seat) ? votes[seat] : null,
      'votes': (phase == 'guess' || phase == 'roundEnd' || phase == 'over')
          ? {for (final e in votes.entries) '${e.key}': e.value}
          : null,
      'scores': scores,
      'readyNext': [for (var s = 0; s < players; s++) readyNext.contains(s)],
      'lastRoundResult': lastRoundResult,
      'roundHistory': roundHistory,
      'winner': winner,
      'reason': reason,
    };
  }

  // ---------------------------------------------------------------- Bot & AI
  String _pickHeuristicClue(int seat) {
    final usedTexts = {for (final c in clues) c['text'] as String};
    final isCham = seat == chameleonSeat;

    if (!isCham) {
      // Citizen knows secretWord
      final bank = currentTopic.wordClues[secretWord] ?? const <String>[];
      final validBank = bank.where((w) => !usedTexts.contains(w) && isValidClue(w, currentTopic.words)).toList();
      if (validBank.isNotEmpty) {
        return validBank[rng.nextInt(validBank.length)];
      }
    } else {
      // Chameleon does NOT know secretWord! If botLevel == 2 and earlier clues match a specific word's bank, blend in
      if (botLevel == 2 && clues.isNotEmpty) {
        for (final w in currentTopic.words) {
          final b = currentTopic.wordClues[w] ?? const <String>[];
          if (clues.any((c) => b.contains(c['text']))) {
            final unused = b.where((x) => !usedTexts.contains(x) && isValidClue(x, currentTopic.words)).toList();
            if (unused.isNotEmpty) return unused[rng.nextInt(unused.length)];
          }
        }
      }
    }

    final fallbacks = currentTopic.chameleonClues
        .where((w) => !usedTexts.contains(w) && isValidClue(w, currentTopic.words))
        .toList();
    if (fallbacks.isNotEmpty) {
      return fallbacks[rng.nextInt(fallbacks.length)];
    }
    return '印象${clues.length + 1}';
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver) return null;
    final isCham = seat == chameleonSeat;

    switch (phase) {
      case 'clue':
        if (seat != currentTurn) return null;
        if (aiOn) {
          final key = 'cham:clue:$round:$seat';
          final poll = _ai.poll(setup.ai!, key, () {
            final prev = clues.isEmpty
                ? '暂无'
                : clues.map((c) => '${name(c["seat"] as int)}:${c["text"]}').join('，');
            return AiRequest(
              system: '你在玩《变色龙》(The Chameleon)词汇推理游戏。只输出一个简短中文词（2~4字）作为线索，严禁输出题目卡上的任何原词。',
              prompt: isCham
                  ? '主题：【${currentTopic.title}】，16个词：${currentTopic.words.join("、")}。你是【变色龙】（不知道秘密词）。前人线索：$prev。请给出一个既合理又不露馅的词：'
                  : '主题：【${currentTopic.title}】，16个词：${currentTopic.words.join("、")}。秘密词是【$secretWord】。前人线索：$prev。请给出一个只有知情者能懂的联想词（绝不能包含“$secretWord”）：',
              maxTokens: 40,
            );
          });
          if (poll.pending) return null;
          if (poll.text != null) {
            String candidate = AiText.firstLine(poll.text!, maxLen: 12);
            final j = AiText.json(poll.text!);
            if (j != null && j['clue'] is String) {
              candidate = AiText.firstLine(j['clue'] as String, maxLen: 12);
            }
            if (isValidClue(candidate, currentTopic.words)) {
              return {'type': 'clue', 'text': candidate};
            }
          }
        }
        return {'type': 'clue', 'text': _pickHeuristicClue(seat)};

      case 'vote':
        if (votes.containsKey(seat)) return null;
        final others = [for (var s = 0; s < players; s++) if (s != seat) s];
        if (botLevel == 0) {
          return {'type': 'vote', 'target': others[rng.nextInt(others.length)]};
        }
        if (!isCham) {
          // Citizen knows secretWord: check whose clue was NOT in secretWord's clue bank
          final goodClues = (currentTopic.wordClues[secretWord] ?? const <String>[]).toSet();
          final suspectSeats = <int>[];
          for (final c in clues) {
            final s = c['seat'] as int;
            final txt = c['text'] as String;
            if (s != seat && !goodClues.contains(txt)) {
              suspectSeats.add(s);
            }
          }
          if (suspectSeats.isNotEmpty) {
            return {'type': 'vote', 'target': suspectSeats[rng.nextInt(suspectSeats.length)]};
          }
        } else {
          // Chameleon votes for someone who spoke early or gave a generic clue
          final genericSeats = [
            for (final c in clues)
              if (c['seat'] != seat && currentTopic.chameleonClues.contains(c['text'])) c['seat'] as int,
          ];
          if (genericSeats.isNotEmpty) {
            return {'type': 'vote', 'target': genericSeats.first};
          }
        }
        return {'type': 'vote', 'target': others[rng.nextInt(others.length)]};

      case 'guess':
        if (seat != chameleonSeat) return null;
        // Chameleon infers secretIndex ONLY from public clues + topic clue bank (never reads secretIndex!)
        if (botLevel > 0) {
          final matchScores = List.filled(16, 0);
          for (var i = 0; i < 16; i++) {
            final w = currentTopic.words[i];
            final bank = currentTopic.wordClues[w] ?? const <String>[];
            for (final c in clues) {
              if (c['seat'] == seat) continue;
              final txt = c['text'] as String;
              if (bank.contains(txt)) {
                matchScores[i] += 3;
              }
            }
          }
          var bestIdx = -1;
          var bestScore = 0;
          for (var i = 0; i < 16; i++) {
            if (matchScores[i] > bestScore) {
              bestScore = matchScores[i];
              bestIdx = i;
            }
          }
          if (bestIdx >= 0 && (botLevel == 2 || rng.nextDouble() < 0.6)) {
            return {'type': 'guess', 'index': bestIdx};
          }
        }
        return {'type': 'guess', 'index': rng.nextInt(16)};

      case 'roundEnd':
        if (readyNext.contains(seat)) return null;
        return {'type': 'next'};

      default:
        return null;
    }
  }
}
