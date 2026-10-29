import '../../src/engine.dart';

class CitadelsRole {
  final int id; // 1..8
  final String name;
  final String en;
  final String color; // '' | 'yellow' | 'blue' | 'green' | 'red'
  final String desc;
  const CitadelsRole(this.id, this.name, this.en, this.color, this.desc);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'en': en,
        'color': color,
        'desc': desc,
      };
}

const List<CitadelsRole> citadelsRoles = [
  CitadelsRole(1, '刺客', 'Assassin', '', '宣布刺杀一个 2~8 号角色，被刺杀的角色本轮跳过回合。'),
  CitadelsRole(2, '盗贼', 'Thief', '', '宣布偷窃一个 3~8 号（未被刺杀）角色，该角色行动前夺取其全部金币。'),
  CitadelsRole(3, '魔术师', 'Magician', '', '与一名玩家交换全部手牌，或弃置任意张手牌并从牌库摸等量牌。'),
  CitadelsRole(4, '国王', 'King', 'yellow', '获得王冠（下轮起手选角）；每座黄色（贵族）建筑获得 1 金币。'),
  CitadelsRole(5, '主教', 'Bishop', 'blue', '建筑免受军阀摧毁；每座蓝色（宗教）建筑获得 1 金币。'),
  CitadelsRole(6, '商人', 'Merchant', 'green', '行动额外获得 1 金币；每座绿色（商业）建筑获得 1 金币。'),
  CitadelsRole(7, '建筑师', 'Architect', '', '拿取收入后额外摸 2 张建筑牌；本回合最多可建造 3 座建筑。'),
  CitadelsRole(8, '军阀', 'Warlord', 'red', '每座红色（军事）建筑获得 1 金币；可支付（费用-1）金币摧毁一座建筑。'),
];

CitadelsRole roleById(int id) => citadelsRoles[(id - 1).clamp(0, 7)];

class CitadelsDistrict {
  final String id;
  final String name;
  final String color; // 'yellow', 'blue', 'green', 'red', 'purple'
  final int cost;
  final int count;
  final int bonusPts;
  final String effect;

  const CitadelsDistrict(
    this.id,
    this.name,
    this.color,
    this.cost,
    this.count, {
    this.bonusPts = 0,
    this.effect = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'cost': cost,
        'bonusPts': bonusPts,
        'effect': effect,
      };
}

const List<CitadelsDistrict> citadelsCatalog = [
  // Yellow (贵族) - 12 cards
  CitadelsDistrict('manor', '庄园', 'yellow', 3, 5),
  CitadelsDistrict('castle', '城堡', 'yellow', 4, 4),
  CitadelsDistrict('palace', '皇宫', 'yellow', 5, 3),
  // Blue (宗教) - 11 cards
  CitadelsDistrict('temple', '神庙', 'blue', 1, 3),
  CitadelsDistrict('church', '教堂', 'blue', 2, 3),
  CitadelsDistrict('monastery', '修道院', 'blue', 3, 3),
  CitadelsDistrict('cathedral', '大教堂', 'blue', 5, 2),
  // Green (商业) - 20 cards
  CitadelsDistrict('tavern', '酒馆', 'green', 1, 5),
  CitadelsDistrict('market', '集市', 'green', 2, 4),
  CitadelsDistrict('trading_post', '贸易站', 'green', 2, 3),
  CitadelsDistrict('docks', '码头', 'green', 3, 3),
  CitadelsDistrict('harbor', '海港', 'green', 4, 3),
  CitadelsDistrict('town_hall', '市政厅', 'green', 5, 2),
  // Red (军事) - 11 cards
  CitadelsDistrict('watchtower', '瞭望塔', 'red', 1, 3),
  CitadelsDistrict('prison', '监狱', 'red', 2, 3),
  CitadelsDistrict('barracks', '兵营', 'red', 3, 3),
  CitadelsDistrict('fortress', '要塞', 'red', 5, 2),
  // Purple (特殊) - 11 cards
  CitadelsDistrict('haunted_city', '鬼城', 'purple', 2, 1, effect: '终局计分时可视为任意一种缺失颜色'),
  CitadelsDistrict('keep', '堡垒', 'purple', 3, 2, effect: '不能被军阀摧毁'),
  CitadelsDistrict('treasury', '帝国宝库', 'purple', 4, 1, effect: '终局每持有1枚金币额外+1分'),
  CitadelsDistrict('map_room', '地图室', 'purple', 5, 1, effect: '终局每持有1张手牌额外+1分'),
  CitadelsDistrict('observatory', '天文台', 'purple', 5, 1, effect: '拿牌收入时摸3张牌'),
  CitadelsDistrict('library', '图书馆', 'purple', 6, 1, effect: '拿牌收入时保留摸到的2张牌'),
  CitadelsDistrict('magic_school', '魔法学校', 'purple', 6, 1, effect: '税收时视为当前角色的对应颜色'),
  CitadelsDistrict('dragon_gate', '龙门', 'purple', 6, 1, bonusPts: 2, effect: '终局价值8分'),
  CitadelsDistrict('university', '大学', 'purple', 6, 1, bonusPts: 2, effect: '终局价值8分'),
  CitadelsDistrict('great_wall', '皇家园林', 'purple', 5, 1, bonusPts: 1, effect: '终局价值6分'),
];

final Map<String, CitadelsDistrict> districtById = {
  for (final d in citadelsCatalog) d.id: d,
};

const String citadelsRules = '''
# 富饶之城 (Citadels)

## 游戏目标
玩家通过每轮轮抽秘密角色、获取金币与建筑牌，在自己的城市中建造建筑。当任意玩家建满目标数量的建筑（标准 7 座 / 快速 6 座）时，该轮结束后游戏结束，总分最高者获胜。

## 每轮流程
- **选角阶段 (Draft)**：从持有王冠的玩家开始，按顺时针顺序从可用角色牌中秘密挑选 1 张角色牌（开局会按人数弃置部分明置/暗置角色牌，国王绝不会被明置弃除）。
- **行动阶段 (Turn)**：按角色编号 1~8 依次叫号行动：
  1. **拿取收入**：选择拿取 **2 枚金币**，或 **摸 2 张建筑牌保留 1 张**（拥有图书馆可保留 2 张，拥有天文台摸 3 张）。
  2. **执行行动**：
     - **建造建筑**：支付费用建造至多 1 座同名未建过的建筑（建筑师可建至多 3 座）。
     - **角色技能**：发动当前角色的专属能力（每回合限 1 次）。
     - **领地税收**：国王（黄）、主教（蓝）、商人（绿）、军阀（红）可按城市中对应颜色建筑数量获得等量金币。

## 八大角色能力
- **1 刺客 (Assassin)**：指定 2~8 号中的一个角色刺杀，被刺杀者本轮跳过回合。
- **2 盗贼 (Thief)**：指定 3~8 号中未被刺杀的一个角色偷窃，该角色翻开行动前夺走其全部金币。
- **3 魔术师 (Magician)**：与另一名玩家互换全部手牌，或弃置任意张手牌从牌库重摸等量牌。
- **4 国王 (King)**：获得王冠（下轮首先选角），每座黄色（贵族）建筑获得 1 金币。
- **5 主教 (Bishop)**：本轮城市建筑免疫军阀摧毁，每座蓝色（宗教）建筑获得 1 金币。
- **6 商人 (Merchant)**：本回合额外获得 +1 金币，每座绿色（商业）建筑获得 1 金币。
- **7 建筑师 (Architect)**：拿取收入后额外摸 2 张建筑牌，本回合可建造最多 3 座建筑。
- **8 军阀 (Warlord)**：每座红色（军事）建筑获得 1 金币；可支付（建筑费用 - 1）金币摧毁任一未完工城市中的 1 座非【堡垒】建筑（不能摧毁主教的城市）。

## 终局计分
- 城市中所有建筑的建造成本总和（加上特殊建筑额外加分）。
- **五色俱全奖励 (+3 分)**：城市包含黄、蓝、绿、红、紫全部 5 种颜色（【鬼城】可充当任意缺失颜色）。
- **完工奖励**：首位建满目标建筑数的玩家 **+4 分**，同轮其他建满的玩家 **+2 分**。
''';

class Citadels extends GameEngine {
  late final int targetDistricts;

  final List<CitadelsDistrict> deck = [];
  final List<CitadelsDistrict> discardPile = [];

  late final List<int> gold;
  late final List<List<CitadelsDistrict>> hand;
  late final List<List<CitadelsDistrict>> city;

  int round = 1;
  int crown = 0;
  String phase = 'draft'; // 'draft' | 'turn' | 'over'
  String subphase = 'income'; // 'income' | 'keep_card' | 'action'

  // Draft state
  List<int> availableRoles = [];
  List<int> faceUpDiscards = [];
  int faceDownDiscardCount = 0;
  int initialFaceDownRole = 0;
  int draftOrderIdx = 0;
  late List<int> draftedRole; // seat -> roleId (0 if none)
  late List<int> revealedRole; // seat -> roleId (0 if hidden)
  late List<int> lastDraftedRole; // kept for tiebreak

  // Turn state
  int currentRole = 0; // 1..8
  int activeSeat = -1;
  int killedRole = 0;
  int robbedRole = 0;
  int thiefSeat = -1;
  bool skillUsed = false;
  bool taxTaken = false;
  int buildsRemaining = 1;
  List<CitadelsDistrict> drawnCards = [];
  int keepRemaining = 0;

  int firstToComplete = -1;
  bool over = false;
  List<int>? _placings;
  Map<String, dynamic>? result;
  String lastAction = '';

  Citadels(super.setup) {
    targetDistricts = setup.opt<int>('targetDistricts', 7);
    gold = List.filled(players, 2);
    hand = List.generate(players, (_) => <CitadelsDistrict>[]);
    city = List.generate(players, (_) => <CitadelsDistrict>[]);
    draftedRole = List.filled(players, 0);
    revealedRole = List.filled(players, 0);
    lastDraftedRole = List.filled(players, 0);
  }

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => _placings;

  @override
  void start() {
    deck.clear();
    discardPile.clear();
    for (final d in citadelsCatalog) {
      for (var i = 0; i < d.count; i++) {
        deck.add(d);
      }
    }
    deck.shuffle(rng);

    for (var s = 0; s < players; s++) {
      gold[s] = 2;
      hand[s].clear();
      city[s].clear();
      for (var i = 0; i < 4; i++) {
        final c = _drawOne();
        if (c != null) hand[s].add(c);
      }
    }
    crown = rng.nextInt(players);
    _startRound();
  }

  CitadelsDistrict? _drawOne() {
    if (deck.isEmpty && discardPile.isNotEmpty) {
      deck.addAll(discardPile);
      discardPile.clear();
      deck.shuffle(rng);
    }
    if (deck.isEmpty) return null;
    return deck.removeLast();
  }

  void _startRound() {
    phase = 'draft';
    draftedRole.fillRange(0, players, 0);
    revealedRole.fillRange(0, players, 0);
    killedRole = 0;
    robbedRole = 0;
    thiefSeat = -1;
    currentRole = 0;
    activeSeat = -1;

    final roles = shuffled([1, 2, 3, 4, 5, 6, 7, 8], rng);
    initialFaceDownRole = roles.removeLast();
    faceDownDiscardCount = 1;
    faceUpDiscards = [];

    final faceUpTarget = players <= 4 ? 2 : (players == 5 ? 1 : 0);
    var idx = 0;
    while (faceUpDiscards.length < faceUpTarget && idx < roles.length) {
      if (roles[idx] != 4) {
        faceUpDiscards.add(roles.removeAt(idx));
      } else {
        idx++;
      }
    }
    faceUpDiscards.sort();
    roles.sort();
    availableRoles = roles;
    draftOrderIdx = 0;
    lastAction = '第 $round 轮选角开始，由 ${name(crown)}（王冠）先选';
    host.log(lastAction);
  }

  int get currentDraftSeat => (crown + draftOrderIdx) % players;

  bool hasDistrict(int seat, String id) => city[seat].any((d) => d.id == id);

  bool canBuildCard(int seat, CitadelsDistrict d) {
    if (buildsRemaining <= 0) return false;
    if (gold[seat] < d.cost) return false;
    if (hasDistrict(seat, d.id)) return false;
    return true;
  }

  int taxAmountFor(int seat, int roleId) {
    final rColor = roleById(roleId).color;
    if (rColor.isEmpty) return 0;
    var count = city[seat].where((d) => d.color == rColor).length;
    if (hasDistrict(seat, 'magic_school')) count += 1;
    return count;
  }

  List<Map<String, int>> warlordTargets(int warlordSeat) {
    final out = <Map<String, int>>[];
    for (var s = 0; s < players; s++) {
      if (city[s].length >= targetDistricts) continue;
      if (draftedRole[s] == 5 && killedRole != 5) continue; // Bishop immune
      for (var i = 0; i < city[s].length; i++) {
        final d = city[s][i];
        if (d.id == 'keep') continue;
        final destroyCost = d.cost - 1;
        if (gold[warlordSeat] >= destroyCost) {
          out.add({'targetSeat': s, 'districtIdx': i, 'cost': destroyCost});
        }
      }
    }
    return out;
  }

  @override
  List<int> get waitingFor {
    if (over) return const [];
    if (phase == 'draft') return [currentDraftSeat];
    if (phase == 'turn' && activeSeat >= 0) return [activeSeat];
    return const [];
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'draft') {
      if (seat != currentDraftSeat) throw GameError('还没轮到你选角');
      if (type != 'draft') throw GameError('请先选择一个角色');
      final role = asInt(action['role']);
      if (!availableRoles.contains(role)) throw GameError('该角色不可选');

      availableRoles.remove(role);
      draftedRole[seat] = role;
      lastDraftedRole[seat] = role;
      draftOrderIdx++;

      // In a 7-player game, the 7th player chooses between the last remaining role and the initial face-down role.
      if (players == 7 && draftOrderIdx == 6 && initialFaceDownRole != 0) {
        availableRoles.add(initialFaceDownRole);
        availableRoles.sort();
        initialFaceDownRole = 0;
        faceDownDiscardCount = 0;
      }

      if (draftOrderIdx >= players) {
        faceDownDiscardCount += availableRoles.length;
        availableRoles.clear();
        phase = 'turn';
        currentRole = 0;
        _advanceRole();
      }
      return;
    }

    if (phase != 'turn' || seat != activeSeat) {
      throw GameError('还没轮到你行动');
    }

    if (subphase == 'income') {
      if (type != 'income') throw GameError('请先选择本回合收入（金币或摸牌）');
      final choice = asStr(action['choice']);
      if (choice == 'gold') {
        gold[seat] += 2;
        lastAction = '${name(seat)}（${roleById(currentRole).name}）拿取了 2 金币';
        _afterIncome(seat);
      } else if (choice == 'cards') {
        final drawCount = hasDistrict(seat, 'observatory') ? 3 : 2;
        drawnCards = [];
        for (var i = 0; i < drawCount; i++) {
          final c = _drawOne();
          if (c != null) drawnCards.add(c);
        }
        if (drawnCards.isEmpty) {
          // Fallback to 2 gold if deck is completely empty
          gold[seat] += 2;
          lastAction = '牌库已空，${name(seat)} 改为拿取 2 金币';
          _afterIncome(seat);
        } else {
          final keepMax = hasDistrict(seat, 'library') ? 2 : 1;
          if (drawnCards.length <= keepMax) {
            hand[seat].addAll(drawnCards);
            final count = drawnCards.length;
            drawnCards = [];
            lastAction = '${name(seat)}（${roleById(currentRole).name}）摸取并保留了 $count 张建筑牌';
            _afterIncome(seat);
          } else {
            keepRemaining = keepMax;
            subphase = 'keep_card';
          }
        }
      } else {
        throw GameError('无效的收入选择');
      }
      return;
    }

    if (subphase == 'keep_card') {
      if (type != 'keep_card') throw GameError('请选择要保留的建筑牌');
      final idx = asInt(action['index']);
      if (idx < 0 || idx >= drawnCards.length) throw GameError('选择的卡牌无效');
      final chosen = drawnCards.removeAt(idx);
      hand[seat].add(chosen);
      keepRemaining--;
      if (keepRemaining <= 0 || drawnCards.isEmpty) {
        discardPile.addAll(drawnCards);
        drawnCards = [];
        lastAction = '${name(seat)}（${roleById(currentRole).name}）完成了摸牌选择';
        _afterIncome(seat);
      }
      return;
    }

    // subphase == 'action'
    switch (type) {
      case 'tax':
        if (taxTaken) throw GameError('本回合已领取过领地税收');
        final amt = taxAmountFor(seat, currentRole);
        taxTaken = true;
        gold[seat] += amt;
        lastAction = '${name(seat)} 领取了 $amt 枚领地税收金币';
        break;

      case 'build':
        final idx = asInt(action['card']);
        if (idx < 0 || idx >= hand[seat].length) throw GameError('手牌索引无效');
        if (buildsRemaining <= 0) throw GameError('本回合建造次数已用尽');
        final d = hand[seat][idx];
        if (gold[seat] < d.cost) throw GameError('金币不足，需要 ${d.cost} 金币');
        if (hasDistrict(seat, d.id)) throw GameError('城市中已有同名建筑【${d.name}】');
        gold[seat] -= d.cost;
        hand[seat].removeAt(idx);
        city[seat].add(d);
        buildsRemaining--;
        if (city[seat].length >= targetDistricts && firstToComplete < 0) {
          firstToComplete = seat;
          host.log('${name(seat)} 率先建成了 $targetDistricts 座建筑！');
        }
        lastAction = '${name(seat)} 建造了【${d.name}】（费用 ${d.cost}）';
        break;

      case 'skill':
        if (skillUsed) throw GameError('本回合已使用过角色技能');
        _handleSkill(seat, action);
        break;

      case 'end_turn':
        if (!taxTaken) {
          final amt = taxAmountFor(seat, currentRole);
          if (amt > 0) {
            gold[seat] += amt;
          }
          taxTaken = true;
        }
        _advanceRole();
        break;

      default:
        throw GameError('未知的操作类型：$type');
    }
  }

  void _afterIncome(int seat) {
    if (currentRole == 6) {
      // Merchant +1 extra gold
      gold[seat] += 1;
    } else if (currentRole == 7) {
      // Architect +2 extra district cards
      for (var i = 0; i < 2; i++) {
        final c = _drawOne();
        if (c != null) hand[seat].add(c);
      }
    }
    subphase = 'action';
  }

  void _handleSkill(int seat, Map<String, dynamic> action) {
    switch (currentRole) {
      case 1: // Assassin
        final targetRole = asInt(action['targetRole'] ?? action['role']);
        if (targetRole < 2 || targetRole > 8) throw GameError('刺客只能指定 2~8 号角色');
        killedRole = targetRole;
        skillUsed = true;
        lastAction = '${name(seat)}（刺客）宣布刺杀了 ${roleById(targetRole).name}！';
        host.log(lastAction);
        break;

      case 2: // Thief
        final targetRole = asInt(action['targetRole'] ?? action['role']);
        if (targetRole < 3 || targetRole > 8) throw GameError('盗贼只能指定 3~8 号角色');
        if (targetRole == killedRole) throw GameError('不能偷窃已被刺杀的角色');
        robbedRole = targetRole;
        thiefSeat = seat;
        skillUsed = true;
        lastAction = '${name(seat)}（盗贼）宣布偷窃 ${roleById(targetRole).name}！';
        host.log(lastAction);
        break;

      case 3: // Magician
        final mode = asStr(action['mode']);
        if (mode == 'swap') {
          final target = asInt(action['targetSeat'] ?? action['target']);
          if (target < 0 || target >= players || target == seat) {
            throw GameError('请选择一名其他玩家交换手牌');
          }
          final tmp = List<CitadelsDistrict>.of(hand[seat]);
          hand[seat]
            ..clear()
            ..addAll(hand[target]);
          hand[target]
            ..clear()
            ..addAll(tmp);
          skillUsed = true;
          lastAction = '${name(seat)}（魔术师）与 ${name(target)} 互换了全部手牌';
          host.log(lastAction);
        } else if (mode == 'exchange') {
          final rawIdxs = asIntList(action['cards']);
          final unique = rawIdxs.toSet().toList()..sort((a, b) => b.compareTo(a));
          if (unique.any((i) => i < 0 || i >= hand[seat].length)) {
            throw GameError('要置换的手牌索引无效');
          }
          for (final i in unique) {
            discardPile.add(hand[seat].removeAt(i));
          }
          for (var i = 0; i < unique.length; i++) {
            final c = _drawOne();
            if (c != null) hand[seat].add(c);
          }
          skillUsed = true;
          lastAction = '${name(seat)}（魔术师）置换了 ${unique.length} 张手牌';
          host.log(lastAction);
        } else {
          throw GameError('魔术师技能模式无效（swap 或 exchange）');
        }
        break;

      case 8: // Warlord
        final target = asInt(action['targetSeat'] ?? action['target']);
        final dIdx = asInt(action['districtIdx'] ?? action['index'] ?? action['card']);
        if (target < 0 || target >= players) throw GameError('目标玩家无效');
        if (city[target].length >= targetDistricts) {
          throw GameError('不能摧毁已完工城市的建筑');
        }
        if (draftedRole[target] == 5 && killedRole != 5) {
          throw GameError('主教的城市免疫军阀摧毁');
        }
        if (dIdx < 0 || dIdx >= city[target].length) throw GameError('目标建筑无效');
        final d = city[target][dIdx];
        if (d.id == 'keep') throw GameError('【堡垒】不能被军阀摧毁');
        final cost = d.cost - 1;
        if (gold[seat] < cost) throw GameError('金币不足，摧毁需要 $cost 金币');
        gold[seat] -= cost;
        city[target].removeAt(dIdx);
        discardPile.add(d);
        skillUsed = true;
        lastAction = '${name(seat)}（军阀）支付 $cost 金币摧毁了 ${name(target)} 的【${d.name}】！';
        host.log(lastAction);
        break;

      default:
        throw GameError('当前角色没有主动技能');
    }
  }

  void _advanceRole() {
    while (currentRole < 8) {
      currentRole++;
      if (currentRole == killedRole) {
        // If King was killed, its holder still receives the crown at round end
        final kingSeat = draftedRole.indexOf(4);
        if (currentRole == 4 && kingSeat >= 0) {
          crown = kingSeat;
        }
        continue;
      }
      final seat = draftedRole.indexOf(currentRole);
      if (seat < 0) continue;

      activeSeat = seat;
      revealedRole[seat] = currentRole;
      subphase = 'income';
      skillUsed = false;
      taxTaken = false;
      buildsRemaining = currentRole == 7 ? 3 : 1;
      drawnCards = [];
      keepRemaining = 0;

      if (currentRole == 4) {
        crown = seat;
      }
      if (currentRole == robbedRole && thiefSeat >= 0 && thiefSeat != seat) {
        final stolen = gold[seat];
        if (stolen > 0) {
          gold[thiefSeat] += stolen;
          gold[seat] = 0;
          host.log('${name(thiefSeat)}（盗贼）从 ${name(seat)}（${roleById(currentRole).name}）处偷走了 $stolen 金币！');
        }
      }
      return;
    }

    // All 8 roles finished
    activeSeat = -1;
    final kingSeat = draftedRole.indexOf(4);
    if (kingSeat >= 0) crown = kingSeat;

    final someoneCompleted = city.any((c) => c.length >= targetDistricts);
    if (someoneCompleted) {
      _finishGame();
    } else {
      round++;
      _startRound();
    }
  }

  bool hasAllFiveColors(int seat) {
    final colors = <String>{};
    var hasHaunted = false;
    for (final d in city[seat]) {
      if (d.id == 'haunted_city') {
        hasHaunted = true;
      } else {
        colors.add(d.color);
      }
    }
    if (colors.length >= 5) return true;
    if (hasHaunted && colors.length >= 4) return true;
    return false;
  }

  Map<String, int> scoreBreakdown(int seat) {
    var baseCost = 0;
    var purpleBonus = 0;
    for (final d in city[seat]) {
      baseCost += d.cost;
      purpleBonus += d.bonusPts;
      if (d.id == 'treasury') purpleBonus += gold[seat];
      if (d.id == 'map_room') purpleBonus += hand[seat].length;
    }
    final fiveColor = hasAllFiveColors(seat) ? 3 : 0;
    final completeBonus = seat == firstToComplete
        ? 4
        : (city[seat].length >= targetDistricts ? 2 : 0);
    final total = baseCost + purpleBonus + fiveColor + completeBonus;
    return {
      'base': baseCost,
      'purple': purpleBonus,
      'fiveColor': fiveColor,
      'complete': completeBonus,
      'total': total,
    };
  }

  int scoreOf(int seat) => scoreBreakdown(seat)['total']!;

  void _finishGame() {
    over = true;
    phase = 'over';
    for (var s = 0; s < players; s++) {
      revealedRole[s] = draftedRole[s];
    }
    final breakdowns = [for (var s = 0; s < players; s++) scoreBreakdown(s)];
    final totals = [for (final b in breakdowns) b['total']!];
    _placings = rankByScore(totals);
    final winners = [
      for (var s = 0; s < players; s++)
        if (_placings![s] == 1) s,
    ];
    result = {
      'scores': totals,
      'breakdowns': breakdowns,
      'winners': winners,
      'placings': _placings,
    };
    host.log('游戏结束！胜者：${winners.map(name).join('、')}');
  }

  @override
  Map<String, dynamic> view(int seat) {
    final isMe = seat >= 0 && seat < players;
    return {
      'round': round,
      'phase': phase,
      'subphase': subphase,
      'crown': crown,
      'targetDistricts': targetDistricts,
      'deckCount': deck.length,
      'discardCount': discardPile.length,
      'availableRoles': phase == 'draft' && seat == currentDraftSeat
          ? availableRoles
          : const <int>[],
      'availableRoleCount': availableRoles.length,
      'faceUpDiscards': faceUpDiscards,
      'faceDownDiscardCount': faceDownDiscardCount,
      'draftSeat': phase == 'draft' ? currentDraftSeat : -1,
      'currentRole': currentRole,
      'activeSeat': activeSeat,
      'killedRole': killedRole,
      'robbedRole': robbedRole,
      'skillUsed': skillUsed,
      'taxTaken': taxTaken,
      'buildsRemaining': buildsRemaining,
      'firstToComplete': firstToComplete,
      'lastAction': lastAction,
      'myHand': isMe ? [for (final d in hand[seat]) d.toJson()] : const [],
      'drawnCards': isMe && seat == activeSeat
          ? [for (final d in drawnCards) d.toJson()]
          : const [],
      'keepRemaining': isMe && seat == activeSeat ? keepRemaining : 0,
      'taxAvailable': isMe && seat == activeSeat && !taxTaken
          ? taxAmountFor(seat, currentRole)
          : 0,
      'warlordTargets': isMe &&
              seat == activeSeat &&
              currentRole == 8 &&
              !skillUsed &&
              subphase == 'action'
          ? warlordTargets(seat)
          : const [],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'seat': s,
            'gold': gold[s],
            'handCount': hand[s].length,
            'city': [for (final d in city[s]) d.toJson()],
            'role': (over || s == seat) ? draftedRole[s] : revealedRole[s],
            'revealedRole': revealedRole[s],
            'score': scoreOf(s),
          },
      ],
      'roles': [for (final r in citadelsRoles) r.toJson()],
      if (result != null) 'result': result,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over) return null;

    if (phase == 'draft') {
      if (seat != currentDraftSeat || availableRoles.isEmpty) return null;
      if (botLevel == 0) {
        return {'type': 'draft', 'role': availableRoles[rng.nextInt(availableRoles.length)]};
      }
      // Smart role evaluation based on seat's hand and city
      var bestRole = availableRoles.first;
      var bestScore = -999;
      for (final r in availableRoles) {
        var sc = 0;
        sc += taxAmountFor(seat, r) * 3;
        if (r == 6) sc += 4; // Merchant gives +1 gold + green tax
        if (r == 7 && gold[seat] >= 4) sc += 5; // Architect great when rich
        if (r == 4) sc += 3; // King gets crown
        if (r == 3 && hand[seat].length <= 1) sc += 6; // Magician great when low cards
        if (r == 1 || r == 2) sc += 3;
        if (r == 5 && city[seat].length >= targetDistricts - 2) sc += 4;
        if (r == 8) sc += 2;
        if (sc > bestScore) {
          bestScore = sc;
          bestRole = r;
        }
      }
      return {'type': 'draft', 'role': bestRole};
    }

    if (phase != 'turn' || seat != activeSeat) return null;

    if (subphase == 'income') {
      final builtIds = {for (final d in city[seat]) d.id};
      final buildableInHand = hand[seat].where((d) => !builtIds.contains(d.id)).toList();
      if (buildableInHand.isEmpty && (deck.isNotEmpty || discardPile.isNotEmpty)) {
        return {'type': 'income', 'choice': 'cards'};
      }
      return {'type': 'income', 'choice': 'gold'};
    }

    if (subphase == 'keep_card') {
      final builtIds = {for (final d in city[seat]) d.id};
      var bestIdx = 0;
      var bestVal = -999;
      for (var i = 0; i < drawnCards.length; i++) {
        final d = drawnCards[i];
        var v = d.cost + d.bonusPts;
        if (builtIds.contains(d.id)) v -= 50;
        if (d.cost <= gold[seat] + 2) v += 3;
        if (v > bestVal) {
          bestVal = v;
          bestIdx = i;
        }
      }
      return {'type': 'keep_card', 'index': bestIdx};
    }

    // subphase == 'action'
    // 1. Collect tax first so we have more gold to build
    if (!taxTaken && taxAmountFor(seat, currentRole) > 0) {
      return {'type': 'tax'};
    }

    // 2. Use character skill if beneficial
    if (!skillUsed) {
      if (currentRole == 1) {
        // Assassin: pick a role not in faceUpDiscards
        final candidates = [
          for (var r = 2; r <= 8; r++)
            if (!faceUpDiscards.contains(r)) r,
        ];
        final target = candidates.isNotEmpty
            ? candidates[rng.nextInt(candidates.length)]
            : 7;
        return {'type': 'skill', 'targetRole': target};
      }
      if (currentRole == 2) {
        // Thief: pick a role 3..8 not killed and not in faceUpDiscards
        final candidates = [
          for (var r = 3; r <= 8; r++)
            if (r != killedRole && !faceUpDiscards.contains(r)) r,
        ];
        if (candidates.isNotEmpty) {
          final target = candidates[rng.nextInt(candidates.length)];
          return {'type': 'skill', 'targetRole': target};
        }
      }
      if (currentRole == 3) {
        final builtIds = {for (final d in city[seat]) d.id};
        final useful = hand[seat].where((d) => !builtIds.contains(d.id)).length;
        if (useful == 0) {
          // Swap with player who has most cards
          var bestTarget = -1;
          var maxCards = hand[seat].length;
          for (var s = 0; s < players; s++) {
            if (s != seat && hand[s].length > maxCards) {
              maxCards = hand[s].length;
              bestTarget = s;
            }
          }
          if (bestTarget >= 0) {
            return {'type': 'skill', 'mode': 'swap', 'targetSeat': bestTarget};
          } else if (hand[seat].isNotEmpty) {
            return {
              'type': 'skill',
              'mode': 'exchange',
              'cards': [for (var i = 0; i < hand[seat].length; i++) i],
            };
          }
        }
      }
    }

    // 3. Build the best affordable district
    if (buildsRemaining > 0) {
      final builtIds = {for (final d in city[seat]) d.id};
      final cityColors = {for (final d in city[seat]) d.color};
      var bestIdx = -1;
      var bestVal = -1;
      for (var i = 0; i < hand[seat].length; i++) {
        final d = hand[seat][i];
        if (gold[seat] >= d.cost && !builtIds.contains(d.id)) {
          var v = d.cost * 10 + d.bonusPts * 10;
          if (!cityColors.contains(d.color)) v += 15;
          if (v > bestVal) {
            bestVal = v;
            bestIdx = i;
          }
        }
      }
      if (bestIdx >= 0) {
        return {'type': 'build', 'card': bestIdx};
      }
    }

    // 4. Warlord skill after building
    if (!skillUsed && currentRole == 8) {
      final targets = warlordTargets(seat)
          .where((t) => t['targetSeat'] != seat)
          .toList();
      if (targets.isNotEmpty) {
        // Pick a cheap destruction (cost <= 1) or against leader
        targets.sort((a, b) => a['cost']!.compareTo(b['cost']!));
        if (targets.first['cost']! <= 1 || botLevel >= 2) {
          return {
            'type': 'skill',
            'targetSeat': targets.first['targetSeat'],
            'districtIdx': targets.first['districtIdx'],
          };
        }
      }
    }

    return {'type': 'end_turn'};
  }
}
