import '../../src/engine.dart';

class ShRoleDef {
  final String id;
  final String name;
  final String enName;
  final String faction; // 'shadow', 'hunter', 'neutral'
  final int maxHp;
  final String winCond;
  final String skillName;
  final String skillDesc;

  const ShRoleDef({
    required this.id,
    required this.name,
    required this.enName,
    required this.faction,
    required this.maxHp,
    required this.winCond,
    required this.skillName,
    required this.skillDesc,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enName': enName,
        'faction': faction,
        'maxHp': maxHp,
        'winCond': winCond,
        'skillName': skillName,
        'skillDesc': skillDesc,
      };
}

const List<ShRoleDef> kShadowRoles = [
  ShRoleDef(
    id: 'werewolf',
    name: '狼人',
    enName: 'Werewolf',
    faction: 'shadow',
    maxHp: 14,
    winCond: '消灭所有猎人，或令3名中立角色死亡',
    skillName: '狂暴反扑',
    skillDesc: '揭示身份后，所有攻击造成的伤害 +2',
  ),
  ShRoleDef(
    id: 'vampire',
    name: '吸血鬼',
    enName: 'Vampire',
    faction: 'shadow',
    maxHp: 13,
    winCond: '消灭所有猎人，或令3名中立角色死亡',
    skillName: '鲜血汲取',
    skillDesc: '揭示身份后，攻击造成伤害时自身回复 2 点生命',
  ),
  ShRoleDef(
    id: 'valkyrie',
    name: '暗影潜伏者',
    enName: 'Valkyrie',
    faction: 'shadow',
    maxHp: 12,
    winCond: '消灭所有猎人，或令3名中立角色死亡',
    skillName: '暗影斩杀',
    skillDesc: '揭示身份后，攻击额外造成 2 点伤害且无视护甲减免',
  ),
];

const List<ShRoleDef> kHunterRoles = [
  ShRoleDef(
    id: 'emi',
    name: '艾米',
    enName: 'Emi',
    faction: 'hunter',
    maxHp: 10,
    winCond: '消灭所有暗影生物',
    skillName: '圣光庇护',
    skillDesc: '揭示身份时立即回复 2 点生命，且攻击伤害 +1',
  ),
  ShRoleDef(
    id: 'franklin',
    name: '富兰克林',
    enName: 'Franklin',
    faction: 'hunter',
    maxHp: 12,
    winCond: '消灭所有暗影生物',
    skillName: '雷霆天罚',
    skillDesc: '揭示身份时立即对一名目标造成 3 点雷电伤害，且攻击伤害 +1',
  ),
  ShRoleDef(
    id: 'george',
    name: '乔治',
    enName: 'George',
    faction: 'hunter',
    maxHp: 14,
    winCond: '消灭所有暗影生物',
    skillName: '重锤粉碎',
    skillDesc: '揭示身份时立即对一名目标造成 3 点重击伤害，且攻击伤害 +1',
  ),
];

const List<ShRoleDef> kNeutralRoles = [
  ShRoleDef(
    id: 'allie',
    name: '艾丽',
    enName: 'Allie',
    faction: 'neutral',
    maxHp: 8,
    winCond: '在游戏结束时保持存活即可获胜',
    skillName: '母爱祈祷',
    skillDesc: '揭示身份时立即完全恢复所有生命值（伤害归零）',
  ),
  ShRoleDef(
    id: 'bob',
    name: '鲍勃',
    enName: 'Bob',
    faction: 'neutral',
    maxHp: 10,
    winCond: '收集满 3 件装备即可获胜',
    skillName: '宝物掠夺',
    skillDesc: '揭示身份时立即获得 1 件装备，且攻击伤害 +1',
  ),
  ShRoleDef(
    id: 'daniel',
    name: '丹尼尔',
    enName: 'Daniel',
    faction: 'neutral',
    maxHp: 13,
    winCond: '成为全场第一个死亡的角色，或所有暗影死亡时存活',
    skillName: '绝望怒吼',
    skillDesc: '揭示身份后，所有攻击造成的伤害 +2',
  ),
];

final Map<String, ShRoleDef> kRoleById = {
  for (final r in [...kShadowRoles, ...kHunterRoles, ...kNeutralRoles]) r.id: r,
};

class ShZoneDef {
  final int id;
  final String name;
  final String desc;
  final String icon;
  const ShZoneDef(this.id, this.name, this.desc, this.icon);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'desc': desc,
        'icon': icon,
      };
}

const List<ShZoneDef> kShZones = [
  ShZoneDef(0, '隐士木屋', '抽取隐士推理卡，试探一名角色的秘密阵营并使其受1伤或回复', '🛖'),
  ShZoneDef(1, '时空之门', '引导时空之力，随机获得一件神圣或暗黑装备并回复1点生命', '🌀'),
  ShZoneDef(2, '教堂', '抽取白卡获得神圣防具/圣物（减伤或攻击加成）', '⛪'),
  ShZoneDef(3, '墓地', '抽取黑卡获得暗黑重型武器（大幅提升攻击伤害）', '🪦'),
  ShZoneDef(4, '诡异森林', '对任意一名角色造成 2 点暗影伤害，或为其回复 1 点生命', '🌲'),
  ShZoneDef(5, '远古祭坛', '从另一名拥有装备的角色处夺取 1 件装备（若无人有则获新装备）', '⛩️'),
];

class ShEquipDef {
  final String id;
  final String name;
  final String type; // 'white' or 'black'
  final int atkBonus;
  final int defBonus;
  final String desc;

  const ShEquipDef(
    this.id,
    this.name,
    this.type,
    this.atkBonus,
    this.defBonus,
    this.desc,
  );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'atkBonus': atkBonus,
        'defBonus': defBonus,
        'desc': desc,
      };
}

const List<ShEquipDef> kWhiteEquips = [
  ShEquipDef('holy_robe', '神圣长袍', 'white', 0, 1, '受到的攻击伤害 -1'),
  ShEquipDef('talisman', '守护护符', 'white', 0, 1, '受到的攻击伤害 -1'),
  ShEquipDef('spear_longinus', '朗基努斯之枪', 'white', 2, 0, '攻击伤害 +2'),
  ShEquipDef('silver_rosary', '银十字念珠', 'white', 1, 0, '攻击伤害 +1'),
];

const List<ShEquipDef> kBlackEquips = [
  ShEquipDef('butcher_axe', '嗜血战斧', 'black', 2, 0, '攻击伤害 +2'),
  ShEquipDef('chainsaw', '狂暴电锯', 'black', 2, 0, '攻击伤害 +2'),
  ShEquipDef('cursed_katana', '妖刀村正', 'black', 2, 0, '攻击伤害 +2'),
  ShEquipDef('revolver', '暗黑左轮', 'black', 1, 0, '攻击伤害 +1'),
];

final Map<String, ShEquipDef> kEquipById = {
  for (final e in [...kWhiteEquips, ...kBlackEquips]) e.id: e,
};

class ShadowHuntersGame extends GameEngine {
  ShadowHuntersGame(super.setup);

  /// Secret role ID for each seat
  late List<String> roles;

  /// Whether each seat has revealed their identity
  late List<bool> revealed;

  /// Whether each seat is alive
  late List<bool> alive;

  /// Current accumulated damage for each seat (dies when damage >= role.maxHp)
  late List<int> damage;

  /// Current zone (0..5) for each seat
  late List<int> zones;

  /// Equipment IDs held by each seat
  late List<List<String>> equipments;

  /// Hermit clue history (publicly visible deduction log)
  late List<String> hermitClues;

  int turn = 0;
  String phase = 'move'; // 'move' or 'action'
  int? firstDeadSeat;
  int turnCount = 0;

  String lastActionText = '';
  bool over = false;
  List<int> winners = <int>[];
  String winSummary = '';

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? rankWinners(players, winners) : null;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  ShRoleDef roleOf(int seat) => kRoleById[roles[seat]]!;
  int maxHpOf(int seat) => roleOf(seat).maxHp;

  @override
  void start() {
    final mode = setup.opt<String>('mode', 'standard');

    // Determine faction counts by player count (4..8)
    int nShadow, nHunter, nNeutral;
    switch (players) {
      case 4:
        nShadow = 2;
        nHunter = 2;
        nNeutral = 0;
        break;
      case 5:
        nShadow = 2;
        nHunter = 2;
        nNeutral = 1;
        break;
      case 6:
        nShadow = 2;
        nHunter = 2;
        nNeutral = 2;
        break;
      case 7:
        nShadow = 2;
        nHunter = 2;
        nNeutral = 3;
        break;
      case 8:
      default:
        nShadow = 3;
        nHunter = 3;
        nNeutral = 2;
        break;
    }

    final shadows = shuffled(kShadowRoles, rng).sublist(0, nShadow);
    final hunters = shuffled(kHunterRoles, rng).sublist(0, nHunter);
    final neutrals = shuffled(kNeutralRoles, rng).sublist(0, nNeutral);
    final dealtRoles =
        shuffled([...shadows, ...hunters, ...neutrals], rng);

    roles = [for (final r in dealtRoles) r.id];
    revealed = List<bool>.filled(players, false);
    alive = List<bool>.filled(players, true);
    damage = List<int>.filled(players, 0);
    zones = [for (var s = 0; s < players; s++) s % 6];
    equipments = List.generate(players, (_) => <String>[]);
    hermitClues = <String>[];

    if (mode == 'fast') {
      final allEquips = [...kWhiteEquips, ...kBlackEquips];
      for (var s = 0; s < players; s++) {
        equipments[s].add(allEquips[rng.nextInt(allEquips.length)].id);
      }
    }

    turn = 0;
    phase = 'move';
    firstDeadSeat = null;
    turnCount = 0;
    over = false;
    winners = <int>[];
    winSummary = '';
    lastActionText = '暗影猎人开始！各方势力暗流涌动，请谨慎试探与出击。';
    host.log(lastActionText);
  }

  int atkBonusOf(int seat) {
    var b = 0;
    for (final eq in equipments[seat]) {
      b += kEquipById[eq]?.atkBonus ?? 0;
    }
    if (revealed[seat]) {
      final rId = roles[seat];
      if (rId == 'werewolf' || rId == 'valkyrie' || rId == 'daniel') {
        b += 2;
      } else if (rId == 'emi' ||
          rId == 'franklin' ||
          rId == 'george' ||
          rId == 'bob') {
        b += 1;
      }
    }
    return b;
  }

  int defBonusOf(int seat, {bool ignoreArmor = false}) {
    if (ignoreArmor) return 0;
    var b = 0;
    for (final eq in equipments[seat]) {
      b += kEquipById[eq]?.defBonus ?? 0;
    }
    return b;
  }

  /// Apply [dmg] to [target]. If [target] dies, records death, loots 1 item to [killer], and checks win conditions.
  void dealDamage(int target, int dmg, {int? killer}) {
    if (dmg <= 0 || !alive[target] || over) return;
    damage[target] += dmg;
    if (damage[target] >= maxHpOf(target)) {
      damage[target] = maxHpOf(target);
      alive[target] = false;
      revealed[target] = true;
      firstDeadSeat ??= target;
      final r = roleOf(target);
      host.log('💀 ${name(target)} 阵亡！真实身份为：【${r.name} (${_factionCn(r.faction)})】');

      if (killer != null &&
          killer != target &&
          alive[killer] &&
          equipments[target].isNotEmpty) {
        final loot = equipments[target].removeLast();
        equipments[killer].add(loot);
        host.log('${name(killer)} 夺取了阵亡者的【${kEquipById[loot]?.name ?? loot}】');
      }
    }
    checkWinConditions();
  }

  void healDamage(int target, int amount) {
    if (amount <= 0 || !alive[target]) return;
    damage[target] = (damage[target] - amount).clamp(0, maxHpOf(target) - 1);
  }

  void grantRandomEquip(int seat, String type) {
    final pool = type == 'white' ? kWhiteEquips : kBlackEquips;
    final chosen = pool[rng.nextInt(pool.length)];
    equipments[seat].add(chosen.id);
    checkWinConditions();
  }

  String _factionCn(String f) => f == 'shadow'
      ? '暗影'
      : f == 'hunter'
          ? '猎人'
          : '中立';

  /// Check if the game has ended and compute [winners] + [winSummary].
  void checkWinConditions() {
    if (over) return;

    // 1. Check if Bob has >= 3 equipments while alive
    for (var s = 0; s < players; s++) {
      if (alive[s] && roles[s] == 'bob' && equipments[s].length >= 3) {
        over = true;
        revealed[s] = true;
        winners = [
          s,
          for (var i = 0; i < players; i++)
            if (i != s && alive[i] && roles[i] == 'allie') i
        ];
        winSummary = '中立角色【鲍勃】(${name(s)}) 集齐 ${equipments[s].length} 件装备达成胜利！';
        lastActionText = winSummary;
        host.log(winSummary);
        return;
      }
    }

    // 2. Check if Daniel is the very first character to die
    if (firstDeadSeat != null && roles[firstDeadSeat!] == 'daniel') {
      final dSeat = firstDeadSeat!;
      over = true;
      winners = [
        dSeat,
        for (var i = 0; i < players; i++)
          if (alive[i] && roles[i] == 'allie') i
      ];
      winSummary = '中立角色【丹尼尔】(${name(dSeat)}) 成为全场首位阵亡者，达成特殊胜利！';
      lastActionText = winSummary;
      host.log(winSummary);
      return;
    }

    final livingShadows = [
      for (var s = 0; s < players; s++)
        if (alive[s] && roleOf(s).faction == 'shadow') s
    ];
    final livingHunters = [
      for (var s = 0; s < players; s++)
        if (alive[s] && roleOf(s).faction == 'hunter') s
    ];
    final deadNeutrals = [
      for (var s = 0; s < players; s++)
        if (!alive[s] && roleOf(s).faction == 'neutral') s
    ];

    if (livingShadows.isEmpty) {
      // Hunters win!
      over = true;
      winners = [
        for (var s = 0; s < players; s++)
          if (roleOf(s).faction == 'hunter' ||
              (alive[s] && (roles[s] == 'allie' || roles[s] == 'daniel')) ||
              (alive[s] && roles[s] == 'bob' && equipments[s].length >= 3))
            s
      ];
      winSummary = '所有暗影生物已被消灭，【猎人阵营】获得胜利！';
      lastActionText = winSummary;
      host.log(winSummary);
      return;
    }

    if (livingHunters.isEmpty || deadNeutrals.length >= 3) {
      // Shadows win!
      over = true;
      winners = [
        for (var s = 0; s < players; s++)
          if (roleOf(s).faction == 'shadow' ||
              (alive[s] && roles[s] == 'allie') ||
              (alive[s] && roles[s] == 'bob' && equipments[s].length >= 3))
            s
      ];
      winSummary = '猎人全军覆没，【暗影阵营】统治黑夜获胜！';
      lastActionText = winSummary;
      host.log(winSummary);
      return;
    }
  }

  int _pickDefaultTarget(int self) {
    final others = [
      for (var s = 0; s < players; s++)
        if (s != self && alive[s]) s
    ];
    if (others.isEmpty) return self;
    // Prefer enemy faction if revealed, else highest remaining HP
    final myFaction = roleOf(self).faction;
    final knownEnemies = others.where((s) {
      if (!revealed[s]) return false;
      final f = roleOf(s).faction;
      if (myFaction == 'shadow') return f == 'hunter';
      if (myFaction == 'hunter') return f == 'shadow';
      return true;
    }).toList();
    if (knownEnemies.isNotEmpty) {
      return knownEnemies[rng.nextInt(knownEnemies.length)];
    }
    return others[rng.nextInt(others.length)];
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('当前不是你的回合');
    if (!alive[seat]) throw GameError('你已经阵亡');

    final type = asStr(action['type']);

    if (type == 'reveal') {
      if (revealed[seat]) throw GameError('你已经揭示过身份了');
      revealed[seat] = true;
      final r = roleOf(seat);
      var skillLog = '${name(seat)} 揭示真实身份：【${r.name} (${_factionCn(r.faction)})】— 发动【${r.skillName}】！';

      if (r.id == 'allie') {
        damage[seat] = 0;
        skillLog += ' 生命值完全恢复！';
      } else if (r.id == 'emi') {
        healDamage(seat, 2);
        skillLog += ' 回复 2 点生命！';
      } else if (r.id == 'bob') {
        grantRandomEquip(seat, rng.nextBool() ? 'white' : 'black');
        skillLog += ' 获得 1 件新装备！';
      } else if (r.id == 'franklin' || r.id == 'george') {
        var target = asInt(action['target'], -1);
        if (target < 0 || target >= players || target == seat || !alive[target]) {
          target = _pickDefaultTarget(seat);
        }
        if (target != seat && alive[target]) {
          skillLog += ' 对 ${name(target)} 造成 3 点技能伤害！';
          lastActionText = skillLog;
          host.log(skillLog);
          dealDamage(target, 3, killer: seat);
          return;
        }
      }

      lastActionText = skillLog;
      host.log(skillLog);
      checkWinConditions();
      return;
    }

    if (type == 'move') {
      if (phase != 'move') throw GameError('本回合已经移动过了');
      var z = asInt(action['zone'], -1);
      if (z < 0 || z >= 6) {
        // Roll 2 dice to pick a zone different from current
        z = (zones[seat] + 1 + rng.nextInt(5)) % 6;
      }
      zones[seat] = z;
      phase = 'action';
      _resolveZoneEffect(seat, z, action);
      return;
    }

    if (type == 'attack') {
      var target = asInt(action['target'], -1);
      if (target < 0 || target >= players || target == seat || !alive[target]) {
        throw GameError('请选择一名有效的存活攻击目标');
      }

      final d1 = rng.nextInt(6) + 1;
      final d2 = rng.nextInt(6) + 1;
      final baseRoll = (d1 - d2).abs();
      final atkBonus = atkBonusOf(seat);
      final ignoreArmor = revealed[seat] && roles[seat] == 'valkyrie';
      final defBonus = defBonusOf(target, ignoreArmor: ignoreArmor);

      var totalDmg = baseRoll + atkBonus - defBonus;
      if (totalDmg <= 0 && (baseRoll > 0 || atkBonus > 0)) {
        totalDmg = 1;
      }
      if (totalDmg < 0) totalDmg = 0;

      if (totalDmg > 0) {
        if (revealed[seat] && roles[seat] == 'vampire') {
          healDamage(seat, 2);
        }
        lastActionText =
            '⚔️ ${name(seat)} 攻击 ${name(target)}（骰差 |$d1-$d2|=$baseRoll, 攻+$atkBonus, 防-$defBonus）造成 $totalDmg 点伤害！';
        host.log(lastActionText);
        dealDamage(target, totalDmg, killer: seat);
      } else {
        lastActionText =
            '⚔️ ${name(seat)} 攻击 ${name(target)}（骰点 $d1,$d2 擦肩而过），未造成伤害';
        host.log(lastActionText);
      }

      if (!over) {
        _advanceTurn();
      }
      return;
    }

    if (type == 'end_turn') {
      lastActionText = '${name(seat)} 结束了回合';
      host.log(lastActionText);
      _advanceTurn();
      return;
    }

    throw GameError('未知操作: $type');
  }

  void _resolveZoneEffect(int seat, int z, Map<String, dynamic> action) {
    final zoneName = kShZones[z].name;
    switch (z) {
      case 0: // 隐士木屋: Hermit deduction clue
        var target = asInt(action['target'], -1);
        if (target < 0 || target >= players || target == seat || !alive[target]) {
          target = _pickDefaultTarget(seat);
        }
        final testFactions = const ['shadow', 'hunter', 'neutral'];
        final testedFaction = testFactions[turnCount % 3];
        final actualFaction = roleOf(target).faction;
        final matched = actualFaction == testedFaction;
        if (matched) {
          dealDamage(target, 1, killer: seat);
        }
        final clue = matched
            ? '🔍 隐士预言：${name(seat)} 试探 ${name(target)}【是否属于${_factionCn(testedFaction)}】→ 触发反应（受1点伤害）！'
            : '🔍 隐士预言：${name(seat)} 试探 ${name(target)}【是否属于${_factionCn(testedFaction)}】→ 无事发生（非${_factionCn(testedFaction)}）';
        hermitClues.add(clue);
        lastActionText = '${name(seat)} 移动到【$zoneName】，$clue';
        host.log(lastActionText);
        break;

      case 1: // 时空之门
        healDamage(seat, 1);
        grantRandomEquip(seat, rng.nextBool() ? 'white' : 'black');
        final eqId = equipments[seat].last;
        lastActionText =
            '${name(seat)} 移动到【$zoneName】，回复 1 点生命并获得【${kEquipById[eqId]?.name}】';
        host.log(lastActionText);
        break;

      case 2: // 教堂
        grantRandomEquip(seat, 'white');
        final eqId = equipments[seat].last;
        lastActionText =
            '${name(seat)} 移动到【$zoneName】，获得神圣白卡装备【${kEquipById[eqId]?.name}】';
        host.log(lastActionText);
        break;

      case 3: // 墓地
        grantRandomEquip(seat, 'black');
        final eqId = equipments[seat].last;
        lastActionText =
            '${name(seat)} 移动到【$zoneName】，获得暗黑武器【${kEquipById[eqId]?.name}】';
        host.log(lastActionText);
        break;

      case 4: // 诡异森林
        final mode = asStr(action['mode'], '');
        var target = asInt(action['target'], -1);
        if (mode == 'heal' || (mode.isEmpty && damage[seat] >= 5 && target < 0)) {
          final healTarget =
              (target >= 0 && target < players && alive[target]) ? target : seat;
          healDamage(healTarget, 1);
          lastActionText =
              '${name(seat)} 移动到【$zoneName】，为 ${name(healTarget)} 回复了 1 点生命';
          host.log(lastActionText);
        } else {
          if (target < 0 ||
              target >= players ||
              target == seat ||
              !alive[target]) {
            target = _pickDefaultTarget(seat);
          }
          lastActionText =
              '${name(seat)} 移动到【$zoneName】，召唤暗影荆棘对 ${name(target)} 造成 2 点伤害！';
          host.log(lastActionText);
          dealDamage(target, 2, killer: seat);
        }
        break;

      case 5: // 远古祭坛
      default:
        var target = asInt(action['target'], -1);
        if (target < 0 ||
            target >= players ||
            target == seat ||
            equipments[target].isEmpty) {
          target = -1;
          for (var s = 0; s < players; s++) {
            if (s != seat && alive[s] && equipments[s].isNotEmpty) {
              target = s;
              break;
            }
          }
        }
        if (target >= 0 && equipments[target].isNotEmpty) {
          final stolen = equipments[target].removeLast();
          equipments[seat].add(stolen);
          lastActionText =
              '${name(seat)} 移动到【$zoneName】，从 ${name(target)} 处夺取了【${kEquipById[stolen]?.name}】！';
          host.log(lastActionText);
          checkWinConditions();
        } else {
          grantRandomEquip(seat, 'black');
          final eqId = equipments[seat].last;
          lastActionText =
              '${name(seat)} 移动到【$zoneName】，献祭获得【${kEquipById[eqId]?.name}】';
          host.log(lastActionText);
        }
        break;
    }
  }

  void _advanceTurn() {
    turnCount++;
    if (turnCount >= 80 && !over) {
      // Safety cap: resolve by surviving faction/HP
      over = true;
      final bestSeats = <int>[
        for (var s = 0; s < players; s++)
          if (alive[s]) s
      ];
      winners = bestSeats.isNotEmpty ? bestSeats : [0];
      winSummary = '黎明降临，存活者赢得最终胜利！';
      lastActionText = winSummary;
      host.log(winSummary);
      return;
    }

    for (var i = 1; i <= players; i++) {
      final next = (turn + i) % players;
      if (alive[next]) {
        turn = next;
        phase = 'move';
        return;
      }
    }
  }

  /// Players in the same paired area (0-1, 2-3, 4-5) are in close combat range;
  /// if none exist in the paired area, any living other player is attackable.
  List<int> attackableTargetsFor(int seat) {
    final myPair = zones[seat] ~/ 2;
    final inPair = [
      for (var s = 0; s < players; s++)
        if (s != seat && alive[s] && (zones[s] ~/ 2) == myPair) s
    ];
    if (inPair.isNotEmpty) return inPair;
    return [
      for (var s = 0; s < players; s++)
        if (s != seat && alive[s]) s
    ];
  }

  @override
  Map<String, dynamic> view(int seat) {
    final playerViews = <Map<String, dynamic>>[];
    for (var s = 0; s < players; s++) {
      final canSeeRole = s == seat || revealed[s] || !alive[s] || over;
      final r = roleOf(s);
      playerViews.add({
        'seat': s,
        'role': canSeeRole ? r.id : '?',
        'roleName': canSeeRole ? r.name : '神秘角色',
        'faction': canSeeRole ? r.faction : '?',
        'maxHp': canSeeRole ? r.maxHp : null,
        'winCond': canSeeRole ? r.winCond : '身份未公开',
        'skillName': canSeeRole ? r.skillName : '???',
        'skillDesc': canSeeRole ? r.skillDesc : '揭示身份后解锁专属技能',
        'revealed': revealed[s],
        'alive': alive[s],
        'damage': damage[s],
        'zone': zones[s],
        'equipments': [
          for (final eq in equipments[s])
            kEquipById[eq]?.toJson() ?? {'id': eq, 'name': eq}
        ],
        'atkBonus': atkBonusOf(s),
        'defBonus': defBonusOf(s),
      });
    }

    return {
      'players': playerViews,
      'zones': [for (final z in kShZones) z.toJson()],
      'hermitClues': [...hermitClues],
      'turn': turn,
      'phase': phase,
      'turnCount': turnCount,
      'firstDeadSeat': firstDeadSeat,
      'attackableTargets':
          (seat >= 0 && seat < players && alive[seat]) ? attackableTargetsFor(seat) : const <int>[],
      'lastActionText': lastActionText,
      'over': over,
      'winners': [...winners],
      'winSummary': winSummary,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn || !alive[seat]) return null;

    // Consider revealing identity if beneficial
    if (!revealed[seat]) {
      final myRole = roles[seat];
      if (myRole == 'allie' && damage[seat] >= 4) {
        return {'type': 'reveal'};
      }
      if (myRole != 'allie' && (damage[seat] >= 3 || turnCount >= players)) {
        return {'type': 'reveal'};
      }
    }

    if (phase == 'move') {
      // Bob prefers equipment zones (2, 3, 5); attackers prefer graveyard (3) or forest (4)
      final myRole = roles[seat];
      int targetZone;
      if (myRole == 'bob') {
        const eqZones = [1, 2, 3, 5];
        targetZone = eqZones[rng.nextInt(eqZones.length)];
      } else {
        targetZone = (zones[seat] + 1 + rng.nextInt(5)) % 6;
      }
      final target = _pickDefaultTarget(seat);
      return {'type': 'move', 'zone': targetZone, 'target': target};
    }

    // phase == 'action': attack a target in range!
    final targets = attackableTargetsFor(seat);
    if (targets.isNotEmpty) {
      // Pick best target using only public info + own faction
      final myFaction = roleOf(seat).faction;
      int chosen = targets[rng.nextInt(targets.length)];
      for (final t in targets) {
        if (revealed[t]) {
          final tf = roleOf(t).faction;
          if ((myFaction == 'shadow' && tf == 'hunter') ||
              (myFaction == 'hunter' && tf == 'shadow')) {
            chosen = t;
            break;
          }
        }
      }
      return {'type': 'attack', 'target': chosen};
    }

    return {'type': 'end_turn'};
  }
}
