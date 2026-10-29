import 'dart:math';

import '../../src/engine.dart';

const List<String> forestSpeciesNames = ['橡树', '冷杉', '山毛榉', '槭树', '桦树'];
const List<String> forestSpeciesEmojis = ['🌳', '🌲', '🍂', '🍁', '🌿'];

const List<String> forestSlotNames = ['树冠(上)', '树根(下)', '树干左', '树干右'];
const List<String> forestSlotShortNames = ['上', '下', '左', '右'];
const List<String> forestSlotArrows = ['⬆️', '⬇️', '⬅️', '➡️'];

class ForestCard {
  final int id;
  final String name;
  final String emoji;
  final String kind; // 'tree' or 'dweller'
  final int species; // 0..4 (橡树, 冷杉, 山毛榉, 槭树, 桦树)
  final int slotDir; // -1 for tree; 0=top, 1=bottom, 2=left, 3=right
  final int cost; // 0..2 cards from hand to clearing
  final int baseVp;
  final String synergyType; // 'tree','butterfly','owl','mushroom','frog','deer','wolf','plant','hare'
  final String synergyDesc;

  const ForestCard({
    required this.id,
    required this.name,
    required this.emoji,
    required this.kind,
    required this.species,
    this.slotDir = -1,
    required this.cost,
    required this.baseVp,
    required this.synergyType,
    required this.synergyDesc,
  });

  bool get isTree => kind == 'tree';
  bool get isDweller => kind == 'dweller';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'kind': kind,
        'species': species,
        'speciesName': forestSpeciesNames[species % forestSpeciesNames.length],
        'speciesEmoji':
            forestSpeciesEmojis[species % forestSpeciesEmojis.length],
        'slotDir': slotDir,
        'slotName': slotDir >= 0 && slotDir < 4 ? forestSlotNames[slotDir] : '树木基座',
        'slotShort': slotDir >= 0 && slotDir < 4 ? forestSlotShortNames[slotDir] : '树',
        'cost': cost,
        'baseVp': baseVp,
        'synergyType': synergyType,
        'synergyDesc': synergyDesc,
      };
}

class ForestTreeSlot {
  final ForestCard tree;
  final ForestCard? top; // dir 0
  final ForestCard? bottom; // dir 1
  final ForestCard? left; // dir 2
  final ForestCard? right; // dir 3

  const ForestTreeSlot({
    required this.tree,
    this.top,
    this.bottom,
    this.left,
    this.right,
  });

  ForestCard? slotAt(int dir) {
    switch (dir) {
      case 0:
        return top;
      case 1:
        return bottom;
      case 2:
        return left;
      case 3:
        return right;
      default:
        return null;
    }
  }

  ForestTreeSlot withSlot(int dir, ForestCard card) {
    switch (dir) {
      case 0:
        return ForestTreeSlot(
            tree: tree, top: card, bottom: bottom, left: left, right: right);
      case 1:
        return ForestTreeSlot(
            tree: tree, top: top, bottom: card, left: left, right: right);
      case 2:
        return ForestTreeSlot(
            tree: tree, top: top, bottom: bottom, left: card, right: right);
      case 3:
        return ForestTreeSlot(
            tree: tree, top: top, bottom: bottom, left: left, right: card);
      default:
        return this;
    }
  }

  List<ForestCard> get dwellers => [
        if (top != null) top!,
        if (bottom != null) bottom!,
        if (left != null) left!,
        if (right != null) right!,
      ];

  Map<String, dynamic> toJson() => {
        'tree': tree.toJson(),
        'top': top?.toJson(),
        'bottom': bottom?.toJson(),
        'left': left?.toJson(),
        'right': right?.toJson(),
      };
}

class ForestShuffleGame extends GameEngine {
  static const int handLimit = 10;
  static const int maxClearingBeforeSweep = 10;

  /// Butterfly set collection scoring table for 0..5 distinct butterfly species:
  /// `1/2/3/4/5 kinds -> 0/3/6/12/20 pts`
  static const List<int> butterflySetScores = [0, 0, 3, 6, 12, 20];

  /// Tree Frog scoring table for 0..3+ frogs: `0/2/6/12 pts`
  static const List<int> frogSetScores = [0, 2, 6, 12];

  late final int maxRounds;
  late List<ForestCard> deck;
  late List<ForestCard> clearing;
  late List<List<ForestCard>> hands;
  late List<List<ForestTreeSlot>> forests;
  late List<int> speciesBonusVp;
  late List<int> turnsTaken;
  late List<int> score;

  int round = 1;
  int turn = 0;
  bool over = false;
  String lastAction = '森林洗牌生态构筑开启';

  ForestShuffleGame(super.setup) : maxRounds = setup.opt<int>('rounds', 10);

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(score) : null;

  List<ForestCard> _buildDeck() {
    var id = 1;
    final out = <ForestCard>[];

    // 1. Tree cards (5 species × 6 copies = 30 trees)
    const treeTemplates = [
      ('千年橡树', '🌳', 0, 2, 4, '基座4分·集齐树种额外加分'),
      ('银叶冷杉', '🌲', 1, 1, 3, '基座3分·冷杉生灵同种+2分'),
      ('金秋山毛榉', '🍂', 2, 1, 3, '基座3分·山毛榉生灵同种+2分'),
      ('红叶槭树', '🍁', 3, 2, 4, '基座4分·槭树生灵同种+2分'),
      ('白皮桦树', '🌿', 4, 1, 2, '基座2分·低费快速造林'),
    ];
    for (var copy = 0; copy < 6; copy++) {
      for (final (nm, em, sp, cost, vp, desc) in treeTemplates) {
        out.add(ForestCard(
          id: id++,
          name: nm,
          emoji: em,
          kind: 'tree',
          species: sp,
          slotDir: -1,
          cost: cost,
          baseVp: vp,
          synergyType: 'tree',
          synergyDesc: desc,
        ));
      }
    }

    // 2. Top-slot Dwellers (slotDir = 0): 5 Butterfly species + Owls
    const butterflyTemplates = [
      ('帝王斑蝶', '🦋', 0),
      ('孔雀蛱蝶', '🦋', 1),
      ('紫闪蛱蝶', '🦋', 2),
      ('凤尾蝶', '🦋', 3),
      ('柠檬粉蝶', '🦋', 4),
    ];
    for (var copy = 0; copy < 3; copy++) {
      for (final (nm, em, sp) in butterflyTemplates) {
        out.add(ForestCard(
          id: id++,
          name: nm,
          emoji: em,
          kind: 'dweller',
          species: sp,
          slotDir: 0,
          cost: 0,
          baseVp: 0,
          synergyType: 'butterfly',
          synergyDesc: '蝴蝶套组(1~5种➔0/3/6/12/20分)',
        ));
      }
    }
    for (var copy = 0; copy < 6; copy++) {
      out.add(ForestCard(
        id: id++,
        name: '林间猫头鹰',
        emoji: '🦉',
        kind: 'dweller',
        species: copy % 5,
        slotDir: 0,
        cost: 2,
        baseVp: 3,
        synergyType: 'owl',
        synergyDesc: '基础3分 + 每棵树+1分',
      ));
    }

    // 3. Bottom-slot Dwellers (slotDir = 1): Mushrooms + Tree Frogs
    const mushroomNames = ['牛肝菌', '鸡油菌', '红伞菌'];
    for (var copy = 0; copy < 3; copy++) {
      for (var i = 0; i < mushroomNames.length; i++) {
        out.add(ForestCard(
          id: id++,
          name: mushroomNames[i],
          emoji: '🍄',
          kind: 'dweller',
          species: (copy + i) % 5,
          slotDir: 1,
          cost: 1,
          baseVp: 1,
          synergyType: 'mushroom',
          synergyDesc: '基础1分 + 每个树根生灵+2分',
        ));
      }
    }
    for (var copy = 0; copy < 8; copy++) {
      out.add(ForestCard(
        id: id++,
        name: '翠绿树蛙',
        emoji: '🐸',
        kind: 'dweller',
        species: copy % 5,
        slotDir: 1,
        cost: 0,
        baseVp: 0,
        synergyType: 'frog',
        synergyDesc: '树蛙群落(1/2/3+只➔2/6/12分)',
      ));
    }

    // 4. Left-slot Dwellers (slotDir = 2): Deer + Wolves
    const deerNames = ['赤鹿', '梅花鹿', '黇鹿'];
    for (var copy = 0; copy < 3; copy++) {
      for (var i = 0; i < deerNames.length; i++) {
        out.add(ForestCard(
          id: id++,
          name: deerNames[i],
          emoji: '🦌',
          kind: 'dweller',
          species: (copy + i) % 5,
          slotDir: 2,
          cost: 1,
          baseVp: 2,
          synergyType: 'deer',
          synergyDesc: '基础2分 + 每个树右生灵+2分',
        ));
      }
    }
    for (var copy = 0; copy < 7; copy++) {
      out.add(ForestCard(
        id: id++,
        name: '灰森林狼',
        emoji: '🐺',
        kind: 'dweller',
        species: copy % 5,
        slotDir: 2,
        cost: 2,
        baseVp: 2,
        synergyType: 'wolf',
        synergyDesc: '基础2分 + 每只鹿+3分',
      ));
    }

    // 5. Right-slot Dwellers (slotDir = 3): Plants + Hares
    const plantNames = ['森林蕨草', '野黑莓丛', '林地苔藓'];
    for (var copy = 0; copy < 3; copy++) {
      for (var i = 0; i < plantNames.length; i++) {
        out.add(ForestCard(
          id: id++,
          name: plantNames[i],
          emoji: '🌿',
          kind: 'dweller',
          species: (copy + i) % 5,
          slotDir: 3,
          cost: 1,
          baseVp: 2,
          synergyType: 'plant',
          synergyDesc: '基础2分 + 每种不同树木+2分',
        ));
      }
    }
    for (var copy = 0; copy < 8; copy++) {
      out.add(ForestCard(
        id: id++,
        name: '欧洲野兔',
        emoji: '🐰',
        kind: 'dweller',
        species: copy % 5,
        slotDir: 3,
        cost: 0,
        baseVp: 2,
        synergyType: 'hare',
        synergyDesc: '群居野兔(每只为全体野兔+1分)',
      ));
    }

    return shuffled(out, rng);
  }

  ForestCard _drawCard() {
    if (deck.isEmpty) {
      deck = _buildDeck();
    }
    return deck.removeLast();
  }

  @override
  void start() {
    deck = _buildDeck();
    clearing = [for (var i = 0; i < 4; i++) _drawCard()];
    hands = List.generate(players, (_) => <ForestCard>[]);
    forests = List.generate(players, (_) => <ForestTreeSlot>[]);
    speciesBonusVp = List.filled(players, 0);
    turnsTaken = List.filled(players, 0);
    score = List.filled(players, 0);

    // Give each player 1 starter sapling tree in their forest and 6 hand cards
    for (var s = 0; s < players; s++) {
      final starterTree = ForestCard(
        id: 900 + s,
        name: '初始${forestSpeciesNames[s % 5]}苗',
        emoji: forestSpeciesEmojis[s % 5],
        kind: 'tree',
        species: s % 5,
        slotDir: -1,
        cost: 0,
        baseVp: 2,
        synergyType: 'tree',
        synergyDesc: '初始林木基座(2分)',
      );
      forests[s].add(ForestTreeSlot(tree: starterTree));
      for (var i = 0; i < 6; i++) {
        hands[s].add(_drawCard());
      }
      score[s] = calcScore(s);
    }

    round = 1;
    turn = 0;
    over = false;
    lastAction = '第 1 轮开始，可抓牌补充手牌、种植新树木或将生灵塞入树木四向槽位';
  }

  Map<String, int> calcScoreBreakdown(int seat) {
    final f = forests[seat];
    var treeBase = 0;
    final treeSpeciesSet = <int>{};
    final butterflyNames = <String>{};
    var owlCount = 0;
    var mushroomCount = 0;
    var bottomCount = 0;
    var frogCount = 0;
    var deerCount = 0;
    var wolfCount = 0;
    var plantCount = 0;
    var hareCount = 0;
    var rightCount = 0;

    for (final slot in f) {
      treeBase += slot.tree.baseVp;
      treeSpeciesSet.add(slot.tree.species);
      if (slot.bottom != null) bottomCount++;
      if (slot.right != null) rightCount++;

      for (final d in slot.dwellers) {
        switch (d.synergyType) {
          case 'butterfly':
            butterflyNames.add(d.name);
          case 'owl':
            owlCount++;
          case 'mushroom':
            mushroomCount++;
          case 'frog':
            frogCount++;
          case 'deer':
            deerCount++;
          case 'wolf':
            wolfCount++;
          case 'plant':
            plantCount++;
          case 'hare':
            hareCount++;
        }
      }
    }

    final distinctSpecies = treeSpeciesSet.length;
    final treeDiversityBonus =
        distinctSpecies >= 5 ? 8 : (distinctSpecies >= 3 ? 3 : 0);
    final treeVp = treeBase + treeDiversityBonus;

    final bKinds = min(5, butterflyNames.length);
    final butterflyVp = butterflySetScores[bKinds];
    final owlVp = owlCount * (3 + f.length);
    final mushroomVp = mushroomCount * (1 + 2 * bottomCount);
    final frogVp = frogSetScores[min(3, frogCount)];
    final deerVp = deerCount * (2 + 2 * rightCount);
    final wolfVp = wolfCount * (2 + 3 * deerCount);
    final plantVp = plantCount * (2 + 2 * distinctSpecies);
    final hareVp = hareCount * (2 + hareCount);
    final spBonus = speciesBonusVp[seat];

    final total = treeVp +
        butterflyVp +
        owlVp +
        mushroomVp +
        frogVp +
        deerVp +
        wolfVp +
        plantVp +
        hareVp +
        spBonus;

    return {
      'treeVp': treeVp,
      'butterflyVp': butterflyVp,
      'owlVp': owlVp,
      'mushroomVp': mushroomVp,
      'frogVp': frogVp,
      'deerVp': deerVp,
      'wolfVp': wolfVp,
      'plantVp': plantVp,
      'hareVp': hareVp,
      'speciesBonusVp': spBonus,
      'total': total,
    };
  }

  int calcScore(int seat) => calcScoreBreakdown(seat)['total']!;

  List<ForestCard> _selectPaymentCards(
      int seat, int mainCardId, int cost, List<int> requestedPayIds) {
    if (cost <= 0) return const [];
    final hand = hands[seat];
    if (hand.length - 1 < cost) {
      throw GameError('手牌数量不足以支付 $cost 张卡牌费用');
    }
    final chosen = <ForestCard>[];
    final usedIds = <int>{mainCardId};

    for (final pid in requestedPayIds) {
      if (chosen.length >= cost) break;
      if (usedIds.contains(pid)) continue;
      final idx = hand.indexWhere((c) => c.id == pid);
      if (idx < 0) {
        throw GameError('指定的支付卡牌 #$pid 不在手牌中');
      }
      usedIds.add(pid);
      chosen.add(hand[idx]);
    }

    // Auto-fill any remaining required payment cards from hand
    if (chosen.length < cost) {
      final candidates = [
        for (final c in hand)
          if (!usedIds.contains(c.id)) c,
      ]..sort((a, b) => a.baseVp.compareTo(b.baseVp));
      for (final c in candidates) {
        if (chosen.length >= cost) break;
        usedIds.add(c.id);
        chosen.add(c);
      }
    }

    if (chosen.length < cost) {
      throw GameError('手牌不足以支付 $cost 张卡牌费用');
    }
    return chosen;
  }

  void _checkClearingSweep() {
    if (clearing.length >= maxClearingBeforeSweep) {
      clearing.clear();
      for (var i = 0; i < 3; i++) {
        clearing.add(_drawCard());
      }
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);
    switch (type) {
      case 'take_cards':
        if (hands[seat].length >= handLimit) {
          throw GameError('手牌已达上限 ($handLimit 张)，请打出树木或安放生灵');
        }
        final clearingIds = asIntList(action['clearingIds']);
        final canDraw = min(2, handLimit - hands[seat].length);
        var taken = 0;
        final takenNames = <String>[];

        for (final cid in clearingIds) {
          if (taken >= canDraw) break;
          final idx = clearing.indexWhere((c) => c.id == cid);
          if (idx < 0) {
            throw GameError('林间空地中找不到卡牌 #$cid');
          }
          final card = clearing.removeAt(idx);
          hands[seat].add(card);
          taken++;
          takenNames.add('${card.emoji}${card.name}');
        }

        while (taken < canDraw) {
          final card = _drawCard();
          hands[seat].add(card);
          taken++;
          takenNames.add('牌库卡');
        }

        turnsTaken[seat]++;
        score[seat] = calcScore(seat);
        lastAction = '${name(seat)} 拿取了 $taken 张卡牌 (${takenNames.join("、")})';
        host.log(lastAction);
        _advanceTurn();

      case 'play_tree':
        final cardId = asInt(action['cardId'], -1);
        final idx = hands[seat].indexWhere((c) => c.id == cardId);
        if (idx < 0) throw GameError('手牌中找不到该树木卡 #$cardId');
        final rawCard = hands[seat][idx];
        final asSapling = asBool(action['asSapling']);
        if (!rawCard.isTree && !asSapling) {
          throw GameError('${rawCard.name} 不是树木基座卡，请使用 tuck_dweller 安放');
        }
        final treeCard = asSapling
            ? ForestCard(
                id: rawCard.id,
                name: '幼林树苗',
                emoji: '🌱',
                kind: 'tree',
                species: rawCard.species,
                slotDir: -1,
                cost: 0,
                baseVp: 1,
                synergyType: 'tree',
                synergyDesc: '树苗基座(1分)',
              )
            : rawCard;

        final payIds = asIntList(action['payIds']);
        final paidCards =
            _selectPaymentCards(seat, treeCard.id, treeCard.cost, payIds);

        // Remove treeCard and paidCards from hand
        hands[seat].removeWhere(
            (c) => c.id == treeCard.id || paidCards.any((p) => p.id == c.id));
        clearing.addAll(paidCards);

        forests[seat].add(ForestTreeSlot(tree: treeCard));
        // Reveal 1 bonus card from deck to clearing when planting a Tree
        final bonusClearing = _drawCard();
        clearing.add(bonusClearing);
        _checkClearingSweep();

        turnsTaken[seat]++;
        score[seat] = calcScore(seat);
        lastAction =
            '${name(seat)} 支付 ${paidCards.length} 张手牌种下 ${treeCard.emoji}${treeCard.name} (林间空地翻出 ${bonusClearing.emoji}${bonusClearing.name})';
        host.log(lastAction);
        _advanceTurn();

      case 'tuck_dweller':
        final cardId = asInt(action['cardId'], -1);
        final idx = hands[seat].indexWhere((c) => c.id == cardId);
        if (idx < 0) throw GameError('手牌中找不到该生灵卡 #$cardId');
        final dweller = hands[seat][idx];
        if (!dweller.isDweller) {
          throw GameError('${dweller.name} 是树木基座卡，请使用 play_tree 种植');
        }

        final treeIdx = asInt(action['treeIdx'], -1);
        if (treeIdx < 0 || treeIdx >= forests[seat].length) {
          throw GameError('无效的目标树木编号: $treeIdx');
        }
        final targetSlot = forests[seat][treeIdx];
        if (targetSlot.slotAt(dweller.slotDir) != null) {
          throw GameError(
              '目标树木的 ${forestSlotNames[dweller.slotDir]} 槽位已有生灵，请选择其他树木');
        }

        final payIds = asIntList(action['payIds']);
        final paidCards =
            _selectPaymentCards(seat, dweller.id, dweller.cost, payIds);

        hands[seat].removeWhere(
            (c) => c.id == dweller.id || paidCards.any((p) => p.id == c.id));
        clearing.addAll(paidCards);

        forests[seat][treeIdx] = targetSlot.withSlot(dweller.slotDir, dweller);

        // Check matching tree species bonus!
        var bonusDesc = '';
        if (targetSlot.tree.species == dweller.species) {
          speciesBonusVp[seat] += 2;
          if (hands[seat].length < handLimit) {
            hands[seat].add(_drawCard());
            bonusDesc = ' (🌲树种完美契合 +2⭐ 并奖励抓1张牌！)';
          } else {
            bonusDesc = ' (🌲树种完美契合 +2⭐！)';
          }
        }

        _checkClearingSweep();
        turnsTaken[seat]++;
        score[seat] = calcScore(seat);
        lastAction =
            '${name(seat)} 将 ${dweller.emoji}${dweller.name} 塞入 ${targetSlot.tree.name} 的${forestSlotNames[dweller.slotDir]}$bonusDesc';
        host.log(lastAction);
        _advanceTurn();

      default:
        throw GameError('未知操作: $type');
    }
  }

  void _advanceTurn() {
    for (var offset = 1; offset <= players; offset++) {
      final nextSeat = (turn + offset) % players;
      if (turnsTaken[nextSeat] < maxRounds) {
        turn = nextSeat;
        round = turnsTaken[turn] + 1;
        return;
      }
    }
    over = true;
    for (var s = 0; s < players; s++) {
      score[s] = calcScore(s);
    }
    lastAction = '森林洗牌生态季结束！终局协同计分完成';
    host.log(lastAction);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    final hand = hands[seat];
    final myForest = forests[seat];

    // 1. Try to tuck a Dweller with a matching tree species or good synergy
    ForestCard? bestDweller;
    int bestTreeIdx = -1;
    int bestDwellerVal = -1;

    for (final c in hand) {
      if (!c.isDweller) continue;
      if (hand.length - 1 < c.cost) continue;
      for (var tIdx = 0; tIdx < myForest.length; tIdx++) {
        if (myForest[tIdx].slotAt(c.slotDir) != null) continue;
        final speciesMatch = myForest[tIdx].tree.species == c.species ? 6 : 0;
        final val = c.baseVp * 2 + speciesMatch + 5 - c.cost;
        if (val > bestDwellerVal) {
          bestDwellerVal = val;
          bestDweller = c;
          bestTreeIdx = tIdx;
        }
      }
    }

    // 2. Check if we should plant a new Tree (especially when slots are filling up)
    ForestCard? bestTree;
    int bestTreeVal = -1;
    for (final c in hand) {
      if (!c.isTree) continue;
      if (hand.length - 1 < c.cost) continue;
      final alreadyHasSpecies =
          myForest.any((s) => s.tree.species == c.species);
      final val = c.baseVp * 2 + (alreadyHasSpecies ? 2 : 7) - c.cost;
      if (val > bestTreeVal) {
        bestTreeVal = val;
        bestTree = c;
      }
    }

    if (bestTree != null && (myForest.length < 3 || bestDweller == null)) {
      return {
        'type': 'play_tree',
        'cardId': bestTree.id,
      };
    }

    if (bestDweller != null) {
      return {
        'type': 'tuck_dweller',
        'cardId': bestDweller.id,
        'treeIdx': bestTreeIdx,
      };
    }

    if (bestTree != null) {
      return {
        'type': 'play_tree',
        'cardId': bestTree.id,
      };
    }

    // 3. Otherwise take cards from clearing / deck (if hand < handLimit)
    if (hand.length < handLimit) {
      final pickIds = <int>[];
      for (final c in clearing) {
        if (pickIds.length >= 2) break;
        if (c.isTree || c.cost <= 1) {
          pickIds.add(c.id);
        }
      }
      return {
        'type': 'take_cards',
        'clearingIds': pickIds,
      };
    }

    // Fallback if hand is full (10 cards): any 10-card hand has enough cards to pay cost<=2
    // If all dwellers in hand have no open tree slot and there are no trees in hand,
    // discard 2 cards to plant a sapling or take_cards isn't needed because we check above.
    // Wait: what if hand has 10 Dwellers and all matching slots on existing trees are full?
    // Let's make sure: if a player has no trees in hand and no open slots for their dwellers,
    // allow `play_tree` to plant any card face-down as a Sapling (cost 0, 1 VP)!
    // Let's support that in `play_tree` or ensure we never get stuck!
    return {
      'type': 'play_tree',
      'cardId': hand.first.id,
      'asSapling': true,
    };
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'round': round,
      'maxRounds': maxRounds,
      'turn': turn,
      'over': over,
      'lastAction': lastAction,
      'deckCount': deck.length,
      'clearing': [for (final c in clearing) c.toJson()],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'score': score[s],
            'breakdown': calcScoreBreakdown(s),
            'speciesBonusVp': speciesBonusVp[s],
            'turnsTaken': turnsTaken[s],
            'handCount': hands[s].length,
            'hand': (s == seat || seat < 0 || over)
                ? [for (final c in hands[s]) c.toJson()]
                : const <Map<String, dynamic>>[],
            'forest': [
              for (final slot in forests[s]) slot.toJson(),
            ],
          },
      ],
    };
  }
}
