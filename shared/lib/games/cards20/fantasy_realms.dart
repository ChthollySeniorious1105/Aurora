import 'dart:math';

import '../../src/engine.dart';

const List<String> frSuits = [
  'army',
  'leader',
  'wizard',
  'weapon',
  'artifact',
  'beast',
  'land',
  'flood',
  'flame',
  'weather',
  'wild',
];

const Map<String, String> frSuitNames = {
  'army': '⚔️军队',
  'leader': '👑领袖',
  'wizard': '🔮法师',
  'weapon': '🗡️武器',
  'artifact': '🏆圣物',
  'beast': '🐉野兽',
  'land': '🏔️大地',
  'flood': '🌊洪水',
  'flame': '🔥火焰',
  'weather': '⛈️天气',
  'wild': '🃏百搭',
};

class FrCardDef {
  final String id;
  final String name;
  final String suit;
  final int base;
  final String ruleText;

  const FrCardDef({
    required this.id,
    required this.name,
    required this.suit,
    required this.base,
    required this.ruleText,
  });

  String get suitLabel => frSuitNames[suit] ?? suit;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'suit': suit,
        'suitLabel': suitLabel,
        'base': base,
        'ruleText': ruleText,
      };
}

/// Complete 53-card Fantasy Realms deck:
/// 10 suits × 5 cards + 3 `wild` cards = 53 unique cards.
const List<FrCardDef> kFrDeckDefs = [
  // 1. Army (5)
  FrCardDef(
    id: 'knights',
    name: '重装骑士',
    suit: 'army',
    base: 20,
    ruleText: '惩罚：若无【领袖】则 -8 分',
  ),
  FrCardDef(
    id: 'elven_archers',
    name: '精灵弓手',
    suit: 'army',
    base: 10,
    ruleText: '奖励：若手中无【天气】则 +5 分',
  ),
  FrCardDef(
    id: 'light_cavalry',
    name: '轻骑兵',
    suit: 'army',
    base: 17,
    ruleText: '惩罚：每有一张【大地】-2 分',
  ),
  FrCardDef(
    id: 'dwarven_infantry',
    name: '矮人步兵',
    suit: 'army',
    base: 15,
    ruleText: '惩罚：每有一张其他【军队】-2 分',
  ),
  FrCardDef(
    id: 'rangers',
    name: '游侠兵团',
    suit: 'army',
    base: 5,
    ruleText: '奖励：每有一张【大地】+10 分；清除手中所有【军队】的惩罚',
  ),

  // 2. Leader (5)
  FrCardDef(
    id: 'king',
    name: '国王',
    suit: 'leader',
    base: 8,
    ruleText: '奖励：每有一张【军队】+5 分（若同时有【王后】则改为每张【军队】+20 分）',
  ),
  FrCardDef(
    id: 'queen',
    name: '王后',
    suit: 'leader',
    base: 6,
    ruleText: '奖励：每有一张【军队】+5 分（若同时有【国王】则改为每张【军队】+20 分）',
  ),
  FrCardDef(
    id: 'princess',
    name: '公主',
    suit: 'leader',
    base: 2,
    ruleText: '奖励：每有一张【军队】【法师】或同僚【领袖】+8 分',
  ),
  FrCardDef(
    id: 'warlord',
    name: '督军',
    suit: 'leader',
    base: 4,
    ruleText: '奖励：等于手中所有【军队】基础战力之和',
  ),
  FrCardDef(
    id: 'empress',
    name: '女皇',
    suit: 'leader',
    base: 15,
    ruleText: '奖励：每有一张【军队】+10 分；惩罚：每有一张其他【领袖】-5 分',
  ),

  // 3. Wizard (5)
  FrCardDef(
    id: 'collector',
    name: '大收藏家',
    suit: 'wizard',
    base: 7,
    ruleText: '奖励：同一花色有 3/4/5 张不同牌时 +10/+40/+100 分',
  ),
  FrCardDef(
    id: 'beastmaster',
    name: '驯兽宗师',
    suit: 'wizard',
    base: 9,
    ruleText: '奖励：每有一张【野兽】+9 分；清除所有【野兽】的惩罚',
  ),
  FrCardDef(
    id: 'warlock_lord',
    name: '术士领主',
    suit: 'wizard',
    base: 25,
    ruleText: '惩罚：每有一张【领袖】或其他【法师】-10 分',
  ),
  FrCardDef(
    id: 'enchantress',
    name: '魅惑女巫',
    suit: 'wizard',
    base: 5,
    ruleText: '奖励：每有一张【大地】【天气】【洪水】或【火焰】+5 分',
  ),
  FrCardDef(
    id: 'necromancer',
    name: '死灵法师',
    suit: 'wizard',
    base: 3,
    ruleText: '奖励：每有一张【军队】【领袖】【法师】或【野兽】+6 分',
  ),

  // 4. Weapon (5)
  FrCardDef(
    id: 'sword_of_keth',
    name: '凯斯圣剑',
    suit: 'weapon',
    base: 7,
    ruleText: '奖励：若有【领袖】+10 分；若同时有【领袖】与【凯斯之盾】则 +40 分',
  ),
  FrCardDef(
    id: 'elven_longbow',
    name: '精灵长弓',
    suit: 'weapon',
    base: 3,
    ruleText: '奖励：若有【精灵弓手】【督军】或【驯兽宗师】则 +30 分',
  ),
  FrCardDef(
    id: 'war_dirigible',
    name: '战争飞艇',
    suit: 'weapon',
    base: 35,
    ruleText: '惩罚：若无【军队】或若有任何【天气】则 -25 分',
  ),
  FrCardDef(
    id: 'warship',
    name: '魔法战舰',
    suit: 'weapon',
    base: 23,
    ruleText: '惩罚：若无【洪水】则 -15 分；清除【洪水】对【军队】的惩罚',
  ),
  FrCardDef(
    id: 'magic_wand',
    name: '奥术魔杖',
    suit: 'weapon',
    base: 1,
    ruleText: '奖励：若有【法师】则 +25 分',
  ),

  // 5. Artifact (5)
  FrCardDef(
    id: 'shield_of_keth',
    name: '凯斯之盾',
    suit: 'artifact',
    base: 4,
    ruleText: '奖励：若有【领袖】+15 分；若同时有【领袖】与【凯斯圣剑】则 +40 分',
  ),
  FrCardDef(
    id: 'gem_of_order',
    name: '秩序宝石',
    suit: 'artifact',
    base: 5,
    ruleText: '奖励：基础战力构成 3/4/5/6/7 连顺时 +10/+30/+60/+100/+150 分',
  ),
  FrCardDef(
    id: 'world_tree',
    name: '世界树',
    suit: 'artifact',
    base: 2,
    ruleText: '奖励：若所有手牌花色互不相同则 +50 分',
  ),
  FrCardDef(
    id: 'book_of_changes',
    name: '变化之书',
    suit: 'artifact',
    base: 3,
    ruleText: '奖励：每多一种不同花色 +4 分；清除所有圣物与武器的惩罚',
  ),
  FrCardDef(
    id: 'protection_rune',
    name: '守护符文',
    suit: 'artifact',
    base: 1,
    ruleText: '特殊：清除你手中所有卡牌的一切惩罚！',
  ),

  // 6. Beast (5)
  FrCardDef(
    id: 'unicorn',
    name: '独角兽',
    suit: 'beast',
    base: 9,
    ruleText: '奖励：若有【公主】+30 分；否则若有【王后】或【魅惑女巫】+15 分',
  ),
  FrCardDef(
    id: 'basilisk',
    name: '石化蜥蜴',
    suit: 'beast',
    base: 35,
    ruleText: '惩罚：每有一张【军队】【领袖】或其他【野兽】-10 分',
  ),
  FrCardDef(
    id: 'warhorse',
    name: '铁甲战马',
    suit: 'beast',
    base: 6,
    ruleText: '奖励：若有【领袖】或【法师】则 +14 分',
  ),
  FrCardDef(
    id: 'dragon',
    name: '远古巨龙',
    suit: 'beast',
    base: 30,
    ruleText: '惩罚：若无【法师】则 -40 分',
  ),
  FrCardDef(
    id: 'hydra',
    name: '九头蛇',
    suit: 'beast',
    base: 12,
    ruleText: '奖励：若有【沼泽】则 +28 分',
  ),

  // 7. Land (5)
  FrCardDef(
    id: 'mountain',
    name: '巍峨高山',
    suit: 'land',
    base: 9,
    ruleText: '奖励：同时有【烟雾】与【野火】时 +50 分；清除【洪水】惩罚',
  ),
  FrCardDef(
    id: 'cavern',
    name: '深邃洞穴',
    suit: 'land',
    base: 6,
    ruleText: '奖励：若有【矮人步兵】或【远古巨龙】+25 分；清除【天气】惩罚',
  ),
  FrCardDef(
    id: 'bell_tower',
    name: '魔法钟楼',
    suit: 'land',
    base: 8,
    ruleText: '奖励：若有【法师】则 +15 分',
  ),
  FrCardDef(
    id: 'forest',
    name: '迷雾森林',
    suit: 'land',
    base: 7,
    ruleText: '奖励：每有一张【野兽】或【精灵弓手】+12 分',
  ),
  FrCardDef(
    id: 'earth_elemental',
    name: '大地元素',
    suit: 'land',
    base: 4,
    ruleText: '奖励：每有一张其他【大地】+15 分',
  ),

  // 8. Flood (5)
  FrCardDef(
    id: 'fountain_of_life',
    name: '生命之泉',
    suit: 'flood',
    base: 1,
    ruleText: '奖励：等于手中单张最高基础战力的【武器】【洪水】【火焰】【大地】或【天气】',
  ),
  FrCardDef(
    id: 'swamp',
    name: '剧毒沼泽',
    suit: 'flood',
    base: 18,
    ruleText: '惩罚：每有一张【军队】或【火焰】-3 分',
  ),
  FrCardDef(
    id: 'great_flood',
    name: '灭世大洪水',
    suit: 'flood',
    base: 32,
    ruleText: '惩罚：每有一张【军队】【大地】或【火焰】-8 分',
  ),
  FrCardDef(
    id: 'island',
    name: '避世孤岛',
    suit: 'flood',
    base: 14,
    ruleText: '特殊：清除手中所有【洪水】与【火焰】的惩罚',
  ),
  FrCardDef(
    id: 'water_elemental',
    name: '流水元素',
    suit: 'flood',
    base: 4,
    ruleText: '奖励：每有一张其他【洪水】+15 分',
  ),

  // 9. Flame (5)
  FrCardDef(
    id: 'wildfire',
    name: '燎原野火',
    suit: 'flame',
    base: 40,
    ruleText: '惩罚：每有一张【大地】【野兽】【军队】或【洪水】-10 分',
  ),
  FrCardDef(
    id: 'candle',
    name: '圣光烛台',
    suit: 'flame',
    base: 2,
    ruleText: '奖励：同时有【变化之书】【魔法钟楼】与任意【法师】时 +100 分；否则有【法师】+10 分',
  ),
  FrCardDef(
    id: 'forge',
    name: '矮人熔炉',
    suit: 'flame',
    base: 9,
    ruleText: '奖励：每有一张【武器】或【圣物】+9 分',
  ),
  FrCardDef(
    id: 'lightning',
    name: '雷霆闪电',
    suit: 'flame',
    base: 11,
    ruleText: '奖励：若有【暴风骤雨】则 +30 分',
  ),
  FrCardDef(
    id: 'fire_elemental',
    name: '烈焰元素',
    suit: 'flame',
    base: 4,
    ruleText: '奖励：每有一张其他【火焰】+15 分',
  ),

  // 10. Weather (5)
  FrCardDef(
    id: 'rainstorm',
    name: '暴风骤雨',
    suit: 'weather',
    base: 8,
    ruleText: '奖励：每有一张【洪水】+10 分；惩罚：每有一张非【雷霆闪电】的【火焰】-4 分',
  ),
  FrCardDef(
    id: 'blizzard',
    name: '极寒暴风雪',
    suit: 'weather',
    base: 30,
    ruleText: '惩罚：每有一张【军队】【领袖】【野兽】或【火焰】-5 分',
  ),
  FrCardDef(
    id: 'smoke',
    name: '滚滚浓烟',
    suit: 'weather',
    base: 27,
    ruleText: '惩罚：若无【火焰】则 -27 分',
  ),
  FrCardDef(
    id: 'whirlwind',
    name: '九天狂风',
    suit: 'weather',
    base: 13,
    ruleText: '奖励：若有【暴风骤雨】且有（【极寒暴风雪】或【灭世大洪水】）则 +40 分',
  ),
  FrCardDef(
    id: 'air_elemental',
    name: '疾风元素',
    suit: 'weather',
    base: 4,
    ruleText: '奖励：每有一张其他【天气】+15 分',
  ),

  // 11. Wild (3)
  FrCardDef(
    id: 'shapeshifter',
    name: '百变幻形者',
    suit: 'wild',
    base: 0,
    ruleText: '百搭：自动化身为最契合你手牌的花色，并提供 +12 协同加分',
  ),
  FrCardDef(
    id: 'mirage',
    name: '海市蜃楼',
    suit: 'wild',
    base: 0,
    ruleText: '百搭：自动化身为最契合你手牌的自然元素花色，并提供 +12 协同加分',
  ),
  FrCardDef(
    id: 'doppelganger',
    name: '镜像分身',
    suit: 'wild',
    base: 0,
    ruleText: '百搭：复制你手牌中基础战力最高的一张牌的战力，并提供最契合花色',
  ),
];

final Map<String, FrCardDef> kFrCardById = {
  for (final c in kFrDeckDefs) c.id: c,
};

List<String> buildFantasyRealmsDeck() => [for (final c in kFrDeckDefs) c.id];

FrCardDef frCard(String id) =>
    kFrCardById[id] ??
    FrCardDef(
      id: id,
      name: id,
      suit: 'army',
      base: 5,
      ruleText: '',
    );

/// Evaluates the longest consecutive run of integers in [nums].
int _longestRun(Iterable<int> nums) {
  final sorted = nums.toSet().toList()..sort();
  if (sorted.isEmpty) return 0;
  var best = 1;
  var cur = 1;
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i] == sorted[i - 1] + 1) {
      cur += 1;
      if (cur > best) best = cur;
    } else {
      cur = 1;
    }
  }
  return best;
}

/// Evaluates a Fantasy Realms hand and returns:
/// - `totalScore`: int
/// - `cardScores`: Map<String, int>
/// - `breakdown`: List<Map<String, dynamic>>
Map<String, dynamic> fantasyRealmsScoreHand(List<String> hand) {
  if (hand.isEmpty) {
    return {
      'totalScore': 0,
      'cardScores': const <String, int>{},
      'breakdown': const <Map<String, dynamic>>[],
    };
  }

  final defs = [for (final id in hand) frCard(id)];
  final idSet = hand.toSet();

  // Determine effective suits for any wild cards to maximize synergy
  final baseSuits = <String, int>{};
  for (final d in defs) {
    if (d.suit != 'wild') {
      baseSuits[d.suit] = (baseSuits[d.suit] ?? 0) + 1;
    }
  }

  String chooseWildSuit(FrCardDef w) {
    // If collector is in hand, match the most common suit to boost set bonus
    if (idSet.contains('collector') && baseSuits.isNotEmpty) {
      final sorted = baseSuits.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return sorted.first.key;
    }
    // If world_tree is in hand, pick a suit not currently in hand
    if (idSet.contains('world_tree') || idSet.contains('book_of_changes')) {
      for (final s in frSuits) {
        if (s != 'wild' && !baseSuits.containsKey(s)) {
          baseSuits[s] = 1;
          return s;
        }
      }
    }
    // Check specific suit needs
    if ((idSet.contains('king') ||
            idSet.contains('queen') ||
            idSet.contains('empress')) &&
        w.id != 'mirage') {
      return 'army';
    }
    if (idSet.contains('dragon') ||
        idSet.contains('magic_wand') ||
        idSet.contains('bell_tower')) {
      return 'wizard';
    }
    if (idSet.contains('knights') ||
        idSet.contains('sword_of_keth') ||
        idSet.contains('shield_of_keth')) {
      return 'leader';
    }
    if (idSet.contains('warship')) return 'flood';
    if (idSet.contains('smoke')) return 'flame';
    if (idSet.contains('rangers')) return 'land';
    if (idSet.contains('beastmaster') || idSet.contains('forest')) {
      return 'beast';
    }
    return w.id == 'mirage' ? 'land' : 'leader';
  }

  final effectiveSuitById = <String, String>{};
  for (final d in defs) {
    effectiveSuitById[d.id] = d.suit == 'wild' ? chooseWildSuit(d) : d.suit;
  }

  int countSuit(String s, {String? excludeId}) {
    var c = 0;
    for (final d in defs) {
      if (d.id == excludeId) continue;
      if (effectiveSuitById[d.id] == s) c++;
    }
    return c;
  }

  bool hasSuit(String s, {String? excludeId}) =>
      countSuit(s, excludeId: excludeId) > 0;

  // Penalty clearing flags
  final clearAllPenalties = idSet.contains('protection_rune');
  final clearArmyPenalties = clearAllPenalties || idSet.contains('rangers');
  final clearBeastPenalties =
      clearAllPenalties || idSet.contains('beastmaster');
  final clearFloodFlamePenalties =
      clearAllPenalties || idSet.contains('island') || idSet.contains('mountain');
  final clearWeatherPenalties = clearAllPenalties || idSet.contains('cavern');
  final clearWeaponArtifactPenalties =
      clearAllPenalties || idSet.contains('book_of_changes');

  bool isPenaltyCleared(FrCardDef d) {
    if (clearAllPenalties) return true;
    return switch (d.suit) {
      'army' => clearArmyPenalties,
      'beast' => clearBeastPenalties,
      'flood' || 'flame' => clearFloodFlamePenalties,
      'weather' => clearWeatherPenalties,
      'weapon' || 'artifact' => clearWeaponArtifactPenalties,
      _ => false,
    };
  }

  final cardScores = <String, int>{};
  final breakdown = <Map<String, dynamic>>[];
  var totalScore = 0;

  final maxBaseInHand = defs.fold<int>(0, (m, d) => max(m, d.base));

  for (final d in defs) {
    var baseVal = d.base;
    var bonus = 0;
    var penalty = 0;
    final cleared = isPenaltyCleared(d);

    switch (d.id) {
      // Army
      case 'knights':
        if (!hasSuit('leader')) penalty = -8;
      case 'elven_archers':
        if (!hasSuit('weather')) bonus = 5;
      case 'light_cavalry':
        penalty = -2 * countSuit('land');
      case 'dwarven_infantry':
        penalty = -2 * countSuit('army', excludeId: d.id);
      case 'rangers':
        bonus = 10 * countSuit('land');

      // Leader
      case 'king':
        final perArmy = idSet.contains('queen') ? 20 : 5;
        bonus = perArmy * countSuit('army');
      case 'queen':
        final perArmy = idSet.contains('king') ? 20 : 5;
        bonus = perArmy * countSuit('army');
      case 'princess':
        bonus = 8 *
            (countSuit('army') +
                countSuit('wizard') +
                countSuit('leader', excludeId: d.id));
      case 'warlord':
        bonus = defs
            .where((x) => effectiveSuitById[x.id] == 'army')
            .fold<int>(0, (s, x) => s + x.base);
      case 'empress':
        bonus = 10 * countSuit('army');
        penalty = -5 * countSuit('leader', excludeId: d.id);

      // Wizard
      case 'collector':
        final suitCounts = <String, int>{};
        for (final x in defs) {
          final s = effectiveSuitById[x.id]!;
          suitCounts[s] = (suitCounts[s] ?? 0) + 1;
        }
        final maxSame =
            suitCounts.values.fold<int>(0, (m, v) => max(m, v));
        if (maxSame >= 5) {
          bonus = 100;
        } else if (maxSame == 4) {
          bonus = 40;
        } else if (maxSame == 3) {
          bonus = 10;
        }
      case 'beastmaster':
        bonus = 9 * countSuit('beast');
      case 'warlock_lord':
        penalty = -10 *
            (countSuit('leader') + countSuit('wizard', excludeId: d.id));
      case 'enchantress':
        bonus = 5 *
            (countSuit('land') +
                countSuit('weather') +
                countSuit('flood') +
                countSuit('flame'));
      case 'necromancer':
        bonus = 6 *
            (countSuit('army') +
                countSuit('leader') +
                countSuit('wizard', excludeId: d.id) +
                countSuit('beast'));

      // Weapon
      case 'sword_of_keth':
        if (hasSuit('leader')) {
          bonus = idSet.contains('shield_of_keth') ? 40 : 10;
        }
      case 'elven_longbow':
        if (idSet.contains('elven_archers') ||
            idSet.contains('warlord') ||
            idSet.contains('beastmaster')) {
          bonus = 30;
        }
      case 'war_dirigible':
        if (!hasSuit('army') || hasSuit('weather')) penalty = -25;
      case 'warship':
        if (!hasSuit('flood')) penalty = -15;
      case 'magic_wand':
        if (hasSuit('wizard')) bonus = 25;

      // Artifact
      case 'shield_of_keth':
        if (hasSuit('leader')) {
          bonus = idSet.contains('sword_of_keth') ? 40 : 15;
        }
      case 'gem_of_order':
        final runLen = _longestRun(defs.map((x) => x.base));
        bonus = switch (runLen) {
          >= 7 => 150,
          6 => 100,
          5 => 60,
          4 => 30,
          3 => 10,
          _ => 0,
        };
      case 'world_tree':
        final uniqueSuits = defs.map((x) => effectiveSuitById[x.id]).toSet();
        if (uniqueSuits.length == defs.length) {
          bonus = 50;
        }
      case 'book_of_changes':
        final uniqueSuits = defs.map((x) => effectiveSuitById[x.id]).toSet();
        bonus = 4 * uniqueSuits.length;
      case 'protection_rune':
        bonus = 0;

      // Beast
      case 'unicorn':
        if (idSet.contains('princess')) {
          bonus = 30;
        } else if (idSet.contains('queen') || idSet.contains('enchantress')) {
          bonus = 15;
        }
      case 'basilisk':
        penalty = -10 *
            (countSuit('army') +
                countSuit('leader') +
                countSuit('beast', excludeId: d.id));
      case 'warhorse':
        if (hasSuit('leader') || hasSuit('wizard')) bonus = 14;
      case 'dragon':
        if (!hasSuit('wizard')) penalty = -40;
      case 'hydra':
        if (idSet.contains('swamp') || hasSuit('flood')) bonus = 28;

      // Land
      case 'mountain':
        if (idSet.contains('smoke') && idSet.contains('wildfire')) {
          bonus = 50;
        }
      case 'cavern':
        if (idSet.contains('dwarven_infantry') || idSet.contains('dragon')) {
          bonus = 25;
        }
      case 'bell_tower':
        if (hasSuit('wizard')) bonus = 15;
      case 'forest':
        bonus = 12 *
            (countSuit('beast') + (idSet.contains('elven_archers') ? 1 : 0));
      case 'earth_elemental':
        bonus = 15 * countSuit('land', excludeId: d.id);

      // Flood
      case 'fountain_of_life':
        bonus = defs
            .where((x) => const {
              'weapon',
              'flood',
              'flame',
              'land',
              'weather',
            }.contains(effectiveSuitById[x.id]))
            .fold<int>(0, (m, x) => max(m, x.base));
      case 'swamp':
        final armyCount = idSet.contains('warship') ? 0 : countSuit('army');
        penalty = -3 * (armyCount + countSuit('flame'));
      case 'great_flood':
        final armyCount = idSet.contains('warship') ? 0 : countSuit('army');
        penalty = -8 * (armyCount + countSuit('land') + countSuit('flame'));
      case 'island':
        bonus = 0;
      case 'water_elemental':
        bonus = 15 * countSuit('flood', excludeId: d.id);

      // Flame
      case 'wildfire':
        penalty = -10 *
            (countSuit('land') +
                countSuit('beast') +
                countSuit('army') +
                countSuit('flood'));
      case 'candle':
        if (idSet.contains('book_of_changes') &&
            idSet.contains('bell_tower') &&
            hasSuit('wizard')) {
          bonus = 100;
        } else if (hasSuit('wizard')) {
          bonus = 10;
        }
      case 'forge':
        bonus = 9 * (countSuit('weapon') + countSuit('artifact'));
      case 'lightning':
        if (idSet.contains('rainstorm') || hasSuit('weather')) bonus = 30;
      case 'fire_elemental':
        bonus = 15 * countSuit('flame', excludeId: d.id);

      // Weather
      case 'rainstorm':
        bonus = 10 * countSuit('flood');
        final nonLightningFlame = defs
            .where(
              (x) =>
                  effectiveSuitById[x.id] == 'flame' && x.id != 'lightning',
            )
            .length;
        penalty = -4 * nonLightningFlame;
      case 'blizzard':
        penalty = -5 *
            (countSuit('army') +
                countSuit('leader') +
                countSuit('beast') +
                countSuit('flame'));
      case 'smoke':
        if (!hasSuit('flame')) penalty = -27;
      case 'whirlwind':
        if (idSet.contains('rainstorm') &&
            (idSet.contains('blizzard') || idSet.contains('great_flood'))) {
          bonus = 40;
        } else if (hasSuit('flood') && hasSuit('weather', excludeId: d.id)) {
          bonus = 20;
        }
      case 'air_elemental':
        bonus = 15 * countSuit('weather', excludeId: d.id);

      // Wild
      case 'shapeshifter':
      case 'mirage':
        bonus = 12;
      case 'doppelganger':
        baseVal = maxBaseInHand;
    }

    final effectivePenalty = cleared ? 0 : penalty;
    final cardTotal = max(0, baseVal + bonus + effectivePenalty);
    cardScores[d.id] = cardTotal;
    totalScore += cardTotal;

    breakdown.add({
      'id': d.id,
      'name': d.name,
      'suit': effectiveSuitById[d.id],
      'base': baseVal,
      'bonus': bonus,
      'penalty': effectivePenalty,
      'penaltyCleared': cleared && penalty < 0,
      'score': cardTotal,
    });
  }

  return {
    'totalScore': totalScore,
    'cardScores': cardScores,
    'breakdown': breakdown,
  };
}

class FantasyRealmsGame extends GameEngine {
  late int discardLimit;
  int turn = 0;

  /// Current phase:
  /// - `'draw'`: Active player draws 1 from `deck` (`draw_deck`) or takes 1 from `discardArea` (`take_discard`)
  /// - `'discard'`: Active player discards 1 card from their 8-card hand to `discardArea` (`discard`)
  String phase = 'draw';

  List<String> deck = [];
  List<String> discardArea = [];
  late List<List<String>> hands;
  late List<int> scores;
  late List<Map<String, int>> cardScores;
  late List<List<Map<String, dynamic>>> handBreakdowns;

  String? lastTakenDiscard;
  List<String> actionLog = [];

  bool _over = false;
  List<int>? _placings;

  FantasyRealmsGame(super.setup) {
    discardLimit = setup.opt<int>('discardLimit', 10);
    hands = List.generate(players, (_) => <String>[]);
    scores = List.filled(players, 0);
    cardScores = List.generate(players, (_) => <String, int>{});
    handBreakdowns = List.generate(players, (_) => <Map<String, dynamic>>[]);
  }

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _placings;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (_over || seat < 0 || seat >= players) throw GameError('无法认输');
    _over = true;
    final winners = [
      for (var i = 0; i < players; i++)
        if (i != seat) i,
    ];
    _placings = rankWinners(players, winners);
    host.log('${name(seat)} 认输');
  }

  @override
  void start() {
    deck = shuffled(buildFantasyRealmsDeck(), rng);
    for (var s = 0; s < players; s++) {
      hands[s] = [for (var i = 0; i < 7; i++) deck.removeLast()];
    }
    discardArea = [];
    phase = 'draw';
    turn = 0;
    lastTakenDiscard = null;
    actionLog = [];
    _refreshLiveScores();
    host.log('奇幻国度开始：每人 7 张起始手牌，当公共弃牌区达到 $discardLimit 张时立即终局计分！');
  }

  void _refreshLiveScores() {
    for (var s = 0; s < players; s++) {
      final res = fantasyRealmsScoreHand(hands[s]);
      scores[s] = asInt(res['totalScore']);
      cardScores[s] = Map<String, int>.of(
        (res['cardScores'] as Map).cast<String, int>(),
      );
      handBreakdowns[s] = List<Map<String, dynamic>>.of(
        (res['breakdown'] as List).cast<Map<String, dynamic>>(),
      );
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);

    if (phase == 'draw') {
      if (type == 'draw_deck') {
        if (deck.isEmpty) throw GameError('牌库已空，请从弃牌区拿牌');
        final c = deck.removeLast();
        hands[seat].add(c);
        lastTakenDiscard = null;
        phase = 'discard';
        actionLog.add('${name(seat)} 从牌库摸取了 1 张暗牌');
        _refreshLiveScores();
        return;
      }

      if (type == 'take_discard') {
        if (discardArea.isEmpty) throw GameError('公共弃牌区为空，请从牌库摸牌');
        var cardId = asStr(action['card']);
        if (cardId.isEmpty && action['index'] != null) {
          final idx = asInt(action['index'], 0)
              .clamp(0, discardArea.length - 1);
          cardId = discardArea[idx];
        }
        if (cardId.isEmpty) {
          cardId = discardArea.last;
        }
        if (!discardArea.remove(cardId)) {
          throw GameError('公共弃牌区中没有卡牌 $cardId');
        }
        hands[seat].add(cardId);
        lastTakenDiscard = cardId;
        phase = 'discard';
        actionLog.add(
          '${name(seat)} 从公共弃牌区拿取了【${frCard(cardId).name}】',
        );
        _refreshLiveScores();
        return;
      }

      throw GameError('摸牌阶段请选择摸牌库 (draw_deck) 或从弃牌区拿牌 (take_discard)');
    }

    if (phase == 'discard') {
      if (type != 'discard') {
        throw GameError('弃牌阶段请选择一张手牌弃入公共弃牌区 (discard)');
      }
      var cardId = asStr(action['card']);
      if (cardId.isEmpty && hands[seat].isNotEmpty) {
        cardId = hands[seat].first;
      }
      if (!hands[seat].remove(cardId)) {
        throw GameError('手牌中没有该张牌：$cardId');
      }
      discardArea.add(cardId);
      lastTakenDiscard = null;
      actionLog.add(
        '${name(seat)} 将【${frCard(cardId).name}】弃入公共弃牌区 (${discardArea.length}/$discardLimit)',
      );
      _refreshLiveScores();

      if (discardArea.length >= discardLimit || deck.isEmpty) {
        _over = true;
        _placings = rankByScore(scores);
        host.log(
          '公共弃牌区达到 ${discardArea.length} 张，奇幻国度结束！${[
            for (var s = 0; s < players; s++) '${name(s)}: ${scores[s]}分'
          ].join(' · ')}',
        );
        return;
      }

      phase = 'draw';
      turn = (turn + 1) % players;
      return;
    }

    throw GameError('未知阶段：$phase');
  }

  /// Given an 8-card hand, finds which card to discard to maximize the remaining 7-card hand score.
  (String bestDiscard, int bestScore) _bestDiscardFrom8(
    List<String> eightCards, {
    String? avoidCard,
  }) {
    var bestCard = eightCards.first;
    var bestScore = -999999;
    for (final c in eightCards) {
      if (eightCards.length > 1 && c == avoidCard) continue;
      final rem = List<String>.of(eightCards)..remove(c);
      final sc = asInt(fantasyRealmsScoreHand(rem)['totalScore']);
      if (sc > bestScore) {
        bestScore = sc;
        bestCard = c;
      }
    }
    return (bestCard, bestScore);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    if (phase == 'draw') {
      final currentScore = scores[seat];
      var bestDiscardPick = '';
      var bestGain = 8; // minimum gain threshold to prefer taking from discard over drawing from deck

      for (final dCard in discardArea) {
        final eight = [...hands[seat], dCard];
        final (_, newScore) = _bestDiscardFrom8(eight, avoidCard: dCard);
        final gain = newScore - currentScore;
        if (gain > bestGain || deck.isEmpty) {
          bestGain = gain;
          bestDiscardPick = dCard;
        }
      }

      if (bestDiscardPick.isNotEmpty) {
        return {'type': 'take_discard', 'card': bestDiscardPick};
      }
      if (deck.isNotEmpty) {
        return {'type': 'draw_deck'};
      }
      return {'type': 'take_discard', 'card': discardArea.last};
    }

    if (phase == 'discard') {
      if (botLevel == 0 && hands[seat].length > 1) {
        final candidates = hands[seat]
            .where((c) => c != lastTakenDiscard)
            .toList();
        final pick = candidates.isNotEmpty
            ? candidates[rng.nextInt(candidates.length)]
            : hands[seat].first;
        return {'type': 'discard', 'card': pick};
      }
      final (bestDiscard, _) = _bestDiscardFrom8(
        hands[seat],
        avoidCard: lastTakenDiscard,
      );
      return {'type': 'discard', 'card': bestDiscard};
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final hasSeat = seat >= 0 && seat < players;
    final myHand = hasSeat ? List<String>.of(hands[seat]) : <String>[];
    final myCardScores = hasSeat
        ? Map<String, int>.of(cardScores[seat])
        : const <String, int>{};
    final myBreakdown = hasSeat
        ? List<Map<String, dynamic>>.of(handBreakdowns[seat])
        : const <Map<String, dynamic>>[];

    return {
      'discardLimit': discardLimit,
      'phase': phase,
      'turn': turn,
      'deckCount': deck.length,
      'discardArea': List<String>.of(discardArea),
      'handCounts': [for (final h in hands) h.length],
      'hand': myHand,
      'myTotalScore': hasSeat ? scores[seat] : 0,
      'cardScores': myCardScores,
      'breakdown': myBreakdown,
      'scores': _over ? List<int>.of(scores) : [
        for (var s = 0; s < players; s++) s == seat ? scores[s] : 0,
      ],
      'allHands': _over
          ? [for (final h in hands) List<String>.of(h)]
          : const <List<String>>[],
      'allBreakdowns': _over
          ? [for (final b in handBreakdowns) List<Map<String, dynamic>>.of(b)]
          : const <List<Map<String, dynamic>>>[],
      'actionLog': List<String>.of(actionLog.reversed.take(6)),
      'over': _over,
      'placings': _placings,
    };
  }
}
