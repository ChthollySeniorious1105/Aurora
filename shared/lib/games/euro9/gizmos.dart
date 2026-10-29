import 'dart:math';

import '../../src/engine.dart';

const List<String> gizmoColorNames = ['红热能', '黄电能', '蓝水能', '黑原子能'];
const List<String> gizmoColorIcons = ['🔴', '🟡', '🔵', '⚫'];

class GizmoCard {
  final int id;
  final int tier; // 1, 2, 3
  final int color; // 0..3
  final int cost; // 1..7
  final int vp;
  final String kind; // 'converter' | 'upgrade' | 'file_trigger' | 'pick_trigger' | 'build_trigger'
  final int triggerColor; // 0..3
  final String name;
  final String desc;

  const GizmoCard({
    required this.id,
    required this.tier,
    required this.color,
    required this.cost,
    required this.vp,
    required this.kind,
    required this.triggerColor,
    required this.name,
    required this.desc,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'tier': tier,
        'color': color,
        'cost': cost,
        'vp': vp,
        'kind': kind,
        'triggerColor': triggerColor,
        'name': name,
        'desc': desc,
      };
}

final List<GizmoCard> gizmosCatalog = _buildGizmosCatalog();

List<GizmoCard> _buildGizmosCatalog() {
  final out = <GizmoCard>[];
  var id = 0;

  // Tier 1: 32 cards (cost 1..2)
  for (var copy = 0; copy < 2; copy++) {
    for (var c = 0; c < 4; c++) {
      out.add(GizmoCard(
        id: id++,
        tier: 1,
        color: c,
        cost: 1,
        vp: 1,
        kind: 'file_trigger',
        triggerColor: c,
        name: '${gizmoColorNames[c]}归档感应器',
        desc: '【归档时】随机盲抽 1 颗能量球',
      ));
      out.add(GizmoCard(
        id: id++,
        tier: 1,
        color: c,
        cost: 1,
        vp: 1,
        kind: 'pick_trigger',
        triggerColor: c,
        name: '${gizmoColorNames[c]}采集共鸣器',
        desc: '【拿取${gizmoColorIcons[c]}时】随机盲抽 1 颗能量球',
      ));
      out.add(GizmoCard(
        id: id++,
        tier: 1,
        color: c,
        cost: 2,
        vp: 2,
        kind: 'converter',
        triggerColor: c,
        name: '${gizmoColorNames[c]}倍增转换器',
        desc: '【转换】建造时 1 颗${gizmoColorIcons[c]}可抵 2 颗同色能量（费用-1）',
      ));
      out.add(GizmoCard(
        id: id++,
        tier: 1,
        color: c,
        cost: 2,
        vp: 2,
        kind: 'upgrade',
        triggerColor: c,
        name: '${gizmoColorNames[c]}扩容槽',
        desc: '【升级】能量存储上限+2，归档上限+1，研究上限+1',
      ));
    }
  }

  // Tier 2: 24 cards (cost 2..3)
  for (var copy = 0; copy < 2; copy++) {
    for (var c = 0; c < 4; c++) {
      out.add(GizmoCard(
        id: id++,
        tier: 2,
        color: c,
        cost: 2,
        vp: 2,
        kind: 'build_trigger',
        triggerColor: c,
        name: '${gizmoColorNames[c]}建造增幅仪',
        desc: '【建造${gizmoColorIcons[c]}时】获得 +1 计分芯片并拿取 1 颗能量球',
      ));
      out.add(GizmoCard(
        id: id++,
        tier: 2,
        color: c,
        cost: 3,
        vp: 3,
        kind: 'pick_trigger',
        triggerColor: (c + 1) % 4,
        name: '${gizmoColorNames[c]}连锁采集器',
        desc: '【拿取${gizmoColorIcons[(c + 1) % 4]}时】随机盲抽 1 颗能量球',
      ));
      out.add(GizmoCard(
        id: id++,
        tier: 2,
        color: c,
        cost: 3,
        vp: 3,
        kind: 'converter',
        triggerColor: c,
        name: '${gizmoColorNames[c]}高阶转换器',
        desc: '【转换】建造任何装置时少付 1 颗能量球',
      ));
    }
  }

  // Tier 3: 12 cards (cost 4..6)
  for (var c = 0; c < 4; c++) {
    out.add(GizmoCard(
      id: id++,
      tier: 3,
      color: c,
      cost: 4,
      vp: 5,
      kind: 'build_trigger',
      triggerColor: c,
      name: '${gizmoColorNames[c]}聚变核心',
      desc: '【建造${gizmoColorIcons[c]}时】获得 +2 计分芯片并拿取 1 颗能量球',
    ));
    out.add(GizmoCard(
      id: id++,
      tier: 3,
      color: c,
      cost: 5,
      vp: 6,
      kind: 'file_trigger',
      triggerColor: c,
      name: '${gizmoColorNames[c]}量子智库',
      desc: '【归档时】获得 +1 计分芯片并随机盲抽 1 颗能量球',
    ));
    out.add(GizmoCard(
      id: id++,
      tier: 3,
      color: c,
      cost: 6,
      vp: 7,
      kind: 'upgrade',
      triggerColor: c,
      name: '${gizmoColorNames[c]}终极反应堆',
      desc: '【升级】上限提升，立即获得 +2 计分芯片',
    ));
  }

  return out;
}

class GizmosGame extends GameEngine {
  late int targetGizmos;
  int turn = 0;
  int round = 1;
  bool endTriggered = false;
  String phase = 'play'; // 'play' | 'over'

  List<int> energyRow = []; // 6 visible marbles (0..3)
  List<List<int>> decks = [[], [], []]; // Tier 1, 2, 3 card IDs
  List<List<int>> display = [[], [], []]; // Tier 1 (4), Tier 2 (3), Tier 3 (2)

  late List<List<int>> marbles; // [seat][0..3] counts of each color
  late List<int> storageLimit;
  late List<int> archiveLimit;
  late List<int> researchLimit;
  late List<List<int>> archive; // [seat] card IDs
  late List<List<int>> built; // [seat] card IDs
  late List<int> vpTokens;

  String lastAction = '松鼠实验室启动';
  Map<String, dynamic>? result;

  GizmosGame(super.setup);

  @override
  void start() {
    targetGizmos = setup.opt<int>('target', 12);
    turn = 0;
    round = 1;
    endTriggered = false;
    phase = 'play';

    energyRow = [for (var i = 0; i < 6; i++) (i + rng.nextInt(4)) % 4];
    for (var t = 1; t <= 3; t++) {
      final tierIds = [
        for (final c in gizmosCatalog)
          if (c.tier == t) c.id
      ];
      decks[t - 1] = shuffled(tierIds, rng);
      display[t - 1] = [];
    }
    _refillDisplay();

    marbles = List.generate(players, (s) {
      final m = [0, 0, 0, 0];
      m[s % 4] = 1;
      m[(s + 1) % 4] = 1;
      return m;
    });
    storageLimit = List.filled(players, 5);
    archiveLimit = List.filled(players, 1);
    researchLimit = List.filled(players, 3);
    archive = List.generate(players, (_) => <int>[]);
    built = List.generate(players, (_) => <int>[]);
    vpTokens = List.filled(players, 0);

    lastAction = '松鼠实验室开赛！请选择：归档、拿取能量、建造或研究';
    host.log(lastAction);
  }

  void _refillDisplay() {
    const counts = [4, 3, 2];
    for (var t = 0; t < 3; t++) {
      while (display[t].length < counts[t] && decks[t].isNotEmpty) {
        display[t].add(decks[t].removeLast());
      }
    }
    while (energyRow.length < 6) {
      energyRow.add(rng.nextInt(4));
    }
  }

  @override
  bool get isOver => phase == 'over';

  @override
  List<int> get waitingFor => isOver ? const [] : [turn];

  int totalMarbles(int seat) =>
      marbles[seat][0] + marbles[seat][1] + marbles[seat][2] + marbles[seat][3];

  int tier3Count(int seat) =>
      built[seat].where((id) => gizmosCatalog[id].tier == 3).length;

  int scoreOf(int seat) {
    var pts = vpTokens[seat];
    for (final id in built[seat]) {
      pts += gizmosCatalog[id].vp;
    }
    return pts;
  }

  @override
  List<int>? get placings => isOver
      ? rankByScore([
          for (var s = 0; s < players; s++)
            scoreOf(s) * 1000 + built[s].length * 10 + totalMarbles(s)
        ])
      : null;

  int converterDiscount(int seat, GizmoCard card) {
    var disc = 0;
    for (final id in built[seat]) {
      final g = gizmosCatalog[id];
      if (g.kind == 'converter') {
        if (g.tier >= 2 || g.triggerColor == card.color) {
          disc++;
        }
      }
    }
    return disc;
  }

  int effectiveCost(int seat, int cardId) {
    final card = gizmosCatalog[cardId];
    return max(1, card.cost - converterDiscount(seat, card));
  }

  bool canAfford(int seat, int cardId) {
    final card = gizmosCatalog[cardId];
    final need = effectiveCost(seat, cardId);
    // Primary color marbles + any wild conversion if player has >=2 of other colors
    final haveColor = marbles[seat][card.color];
    if (haveColor >= need) return true;
    // Allow spending 2 marbles of any other color as 1 missing marble
    final otherMarbles = totalMarbles(seat) - haveColor;
    return haveColor + (otherMarbles ~/ 2) >= need;
  }

  void _payForCard(int seat, int cardId) {
    final card = gizmosCatalog[cardId];
    final need = effectiveCost(seat, cardId);
    final usePrimary = min(marbles[seat][card.color], need);
    marbles[seat][card.color] -= usePrimary;
    var rem = (need - usePrimary) * 2;
    for (var c = 0; c < 4 && rem > 0; c++) {
      if (c == card.color) continue;
      final take = min(marbles[seat][c], rem);
      marbles[seat][c] -= take;
      rem -= take;
    }
  }

  bool _gainMarble(int seat, int color) {
    if (totalMarbles(seat) >= storageLimit[seat]) return false;
    marbles[seat][color.clamp(0, 3)]++;
    return true;
  }

  int _fireFileTriggers(int seat) {
    var chains = 0;
    // Base starter filing bonus: if player has file_trigger gizmos, fire each one
    for (final id in List<int>.of(built[seat])) {
      final g = gizmosCatalog[id];
      if (g.kind == 'file_trigger') {
        if (g.tier == 3) vpTokens[seat]++;
        final c = rng.nextInt(4);
        if (_gainMarble(seat, c)) {
          chains++;
          chains += _firePickTriggers(seat, c);
        }
      }
    }
    return chains;
  }

  int _firePickTriggers(int seat, int pickedColor) {
    var chains = 0;
    for (final id in List<int>.of(built[seat])) {
      final g = gizmosCatalog[id];
      if (g.kind == 'pick_trigger' && g.triggerColor == pickedColor) {
        final c = rng.nextInt(4);
        if (_gainMarble(seat, c)) {
          chains++;
        }
      }
    }
    return chains;
  }

  int _fireBuildTriggers(int seat, GizmoCard builtCard) {
    var chains = 0;
    for (final id in List<int>.of(built[seat])) {
      if (id == builtCard.id) continue;
      final g = gizmosCatalog[id];
      if (g.kind == 'build_trigger' && g.triggerColor == builtCard.color) {
        vpTokens[seat] += g.tier == 3 ? 2 : 1;
        chains++;
        if (energyRow.isNotEmpty && totalMarbles(seat) < storageLimit[seat]) {
          final c = energyRow.removeAt(0);
          energyRow.add(rng.nextInt(4));
          _gainMarble(seat, c);
          chains += _firePickTriggers(seat, c);
        }
      }
    }
    return chains;
  }

  void _installGizmo(int seat, int cardId) {
    built[seat].add(cardId);
    final card = gizmosCatalog[cardId];
    if (card.kind == 'upgrade') {
      storageLimit[seat] += 2;
      archiveLimit[seat] += 1;
      researchLimit[seat] += 1;
      if (card.tier == 3) {
        vpTokens[seat] += 2;
      }
    }
    _fireBuildTriggers(seat, card);
    if (built[seat].length >= targetGizmos || tier3Count(seat) >= 4) {
      endTriggered = true;
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');
    final type = asStr(action['type']);

    if (type == 'pick') {
      if (totalMarbles(seat) >= storageLimit[seat]) {
        throw GameError('能量环已达存储上限(${storageLimit[seat]})，请先建造装置或扩容');
      }
      var idx = asInt(action['index'], asInt(action['i'], -1));
      if (idx < 0 && action.containsKey('color')) {
        final col = asInt(action['color'], 0);
        idx = energyRow.indexOf(col);
      }
      if (idx < 0) idx = 0;
      if (idx < 0 || idx >= energyRow.length) {
        throw GameError('无效的能量球位置');
      }
      final color = energyRow.removeAt(idx);
      energyRow.add(rng.nextInt(4));
      _gainMarble(seat, color);
      final chains = _firePickTriggers(seat, color);
      lastAction =
          '${name(seat)} 拿取了 ${gizmoColorIcons[color]}${gizmoColorNames[color]}${chains > 0 ? '（触发 $chains 次连锁反应！）' : ''}';
      _advanceTurn();
      return;
    }

    if (type == 'file') {
      if (archive[seat].length >= archiveLimit[seat]) {
        throw GameError('个人归档区已满(${archiveLimit[seat]})');
      }
      final byCardId = asInt(action['card'], -1);
      var tIdx = asInt(action['tier'], 1) - 1;
      var cIdx = asInt(action['index'], asInt(action['i'], 0));
      if (byCardId >= 0) {
        for (var t = 0; t < 3; t++) {
          final pos = display[t].indexOf(byCardId);
          if (pos != -1) {
            tIdx = t;
            cIdx = pos;
            break;
          }
        }
      }
      if (tIdx < 0 || tIdx >= 3 || cIdx < 0 || cIdx >= display[tIdx].length) {
        throw GameError('无效的展示区卡牌位置');
      }
      final cardId = display[tIdx].removeAt(cIdx);
      archive[seat].add(cardId);
      _refillDisplay();
      final chains = _fireFileTriggers(seat);
      lastAction =
          '${name(seat)} 归档了【${gizmosCatalog[cardId].name}】${chains > 0 ? '（触发 $chains 次连锁反应！）' : ''}';
      _advanceTurn();
      return;
    }

    if (type == 'build') {
      final fromArchive =
          asBool(action['fromArchive']) || asStr(action['source']) == 'archive' || action.containsKey('archive');
      final byCardId = asInt(action['card'], -1);

      int cardId;
      if (byCardId >= 0 && archive[seat].contains(byCardId)) {
        if (!canAfford(seat, byCardId)) throw GameError('能量球不足，无法建造该归档装置');
        _payForCard(seat, byCardId);
        archive[seat].remove(byCardId);
        cardId = byCardId;
      } else if (fromArchive) {
        final aIdx = asInt(action['archive'], asInt(action['index'], 0));
        if (aIdx < 0 || aIdx >= archive[seat].length) {
          throw GameError('无效的归档卡牌编号');
        }
        cardId = archive[seat][aIdx];
        if (!canAfford(seat, cardId)) throw GameError('能量球不足，无法建造该归档装置');
        _payForCard(seat, cardId);
        archive[seat].removeAt(aIdx);
      } else {
        var tIdx = asInt(action['tier'], 1) - 1;
        var cIdx = asInt(action['index'], asInt(action['i'], 0));
        if (byCardId >= 0) {
          for (var t = 0; t < 3; t++) {
            final pos = display[t].indexOf(byCardId);
            if (pos != -1) {
              tIdx = t;
              cIdx = pos;
              break;
            }
          }
        }
        if (tIdx < 0 || tIdx >= 3 || cIdx < 0 || cIdx >= display[tIdx].length) {
          throw GameError('无效的展示区卡牌位置');
        }
        cardId = display[tIdx][cIdx];
        if (!canAfford(seat, cardId)) throw GameError('能量球不足，无法建造该装置');
        _payForCard(seat, cardId);
        display[tIdx].removeAt(cIdx);
        _refillDisplay();
      }

      _installGizmo(seat, cardId);
      final c = gizmosCatalog[cardId];
      lastAction = '${name(seat)} 建造了 ${c.tier} 级装置【${c.name}】(+${c.vp}分)';
      host.log(lastAction);
      _advanceTurn();
      return;
    }

    if (type == 'research') {
      final tier = asInt(action['tier'], 1).clamp(1, 3);
      final deck = decks[tier - 1];
      if (deck.isEmpty) {
        throw GameError('该等级牌库已空，无法研究');
      }
      final drawCount = min(researchLimit[seat], deck.length);
      final drawn = <int>[];
      for (var i = 0; i < drawCount; i++) {
        drawn.add(deck.removeLast());
      }

      final mode = asStr(action['mode'], 'auto');
      int? builtId;
      int? filedId;

      if (mode != 'file') {
        for (final id in drawn) {
          if (canAfford(seat, id)) {
            builtId = id;
            break;
          }
        }
      }
      if (builtId != null) {
        drawn.remove(builtId);
        deck.insertAll(0, drawn);
        _payForCard(seat, builtId);
        _installGizmo(seat, builtId);
        final c = gizmosCatalog[builtId];
        lastAction = '${name(seat)} 研究了 $tier 级牌库并直接建造【${c.name}】';
        host.log(lastAction);
      } else if (archive[seat].length < archiveLimit[seat] && drawn.isNotEmpty) {
        filedId = drawn.removeAt(0);
        deck.insertAll(0, drawn);
        archive[seat].add(filedId);
        _fireFileTriggers(seat);
        lastAction = '${name(seat)} 研究了 $tier 级牌库并归档【${gizmosCatalog[filedId].name}】';
      } else {
        deck.insertAll(0, drawn);
        // Fallback bonus: gain 1 random marble if space allows
        if (totalMarbles(seat) < storageLimit[seat]) {
          _gainMarble(seat, rng.nextInt(4));
        }
        lastAction = '${name(seat)} 研究了 $tier 级牌库并整理了实验笔记';
      }

      _advanceTurn();
      return;
    }

    throw GameError('未知操作类型: $type');
  }

  void _advanceTurn() {
    final next = (turn + 1) % players;
    if (next == 0) {
      if (endTriggered) {
        phase = 'over';
        final winners = <String>[];
        final p = placings!;
        for (var s = 0; s < players; s++) {
          if (p[s] == 1) winners.add(name(s));
        }
        result = {
          'winners': winners,
          'scores': [for (var s = 0; s < players; s++) scoreOf(s)],
          'builtCounts': [for (var s = 0; s < players; s++) built[s].length],
          'tier3Counts': [for (var s = 0; s < players; s++) tier3Count(s)],
        };
        lastAction = '实验结束！获胜者：${winners.join('、')}';
        host.log(lastAction);
        return;
      }
      round++;
    }
    turn = next;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || seat != turn) return null;

    // 1. Try building the highest-tier affordable card from display or archive
    for (var t = 2; t >= 0; t--) {
      for (var i = 0; i < display[t].length; i++) {
        if (canAfford(seat, display[t][i])) {
          return {'type': 'build', 'tier': t + 1, 'index': i};
        }
      }
    }
    for (var i = 0; i < archive[seat].length; i++) {
      if (canAfford(seat, archive[seat][i])) {
        return {'type': 'build', 'fromArchive': true, 'archive': i};
      }
    }

    // 2. Pick an energy marble if we have storage capacity
    if (totalMarbles(seat) < storageLimit[seat] && energyRow.isNotEmpty) {
      // Prefer a color needed by display cards
      final neededColors = <int>{};
      for (var t = 0; t < 3; t++) {
        for (final id in display[t]) {
          neededColors.add(gizmosCatalog[id].color);
        }
      }
      for (var i = 0; i < energyRow.length; i++) {
        if (neededColors.contains(energyRow[i])) {
          return {'type': 'pick', 'index': i};
        }
      }
      return {'type': 'pick', 'index': 0};
    }

    // 3. File a card if archive has space
    if (archive[seat].length < archiveLimit[seat]) {
      for (var t = 0; t < 3; t++) {
        if (display[t].isNotEmpty) {
          return {'type': 'file', 'tier': t + 1, 'index': 0};
        }
      }
    }

    // 4. Research
    for (var t = 1; t <= 3; t++) {
      if (decks[t - 1].isNotEmpty) {
        return {'type': 'research', 'tier': t};
      }
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) => {
        'round': round,
        'turn': turn,
        'phase': phase,
        'targetGizmos': targetGizmos,
        'endTriggered': endTriggered,
        'lastAction': lastAction,
        'energyRow': energyRow,
        'deckCounts': [for (var t = 0; t < 3; t++) decks[t].length],
        'display': [
          for (var t = 0; t < 3; t++)
            [for (final id in display[t]) gizmosCatalog[id].toJson()]
        ],
        'marbles': marbles,
        'storageLimit': storageLimit,
        'archiveLimit': archiveLimit,
        'researchLimit': researchLimit,
        'archive': [
          for (var s = 0; s < players; s++)
            [for (final id in archive[s]) gizmosCatalog[id].toJson()]
        ],
        'built': [
          for (var s = 0; s < players; s++)
            [for (final id in built[s]) gizmosCatalog[id].toJson()]
        ],
        'vpTokens': vpTokens,
        'scores': [for (var s = 0; s < players; s++) scoreOf(s)],
        'result': result,
      };
}
