import 'dart:math';

import '../../src/engine.dart';

class ParkCard {
  final int id;
  final String name;
  final int vp;
  final List<int> cost; // [tree, mountain, sun, water]

  const ParkCard(this.id, this.name, this.vp, this.cost);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'vp': vp,
        'cost': cost,
      };
}

class GearCard {
  final int id;
  final String name;
  final int sunCost;
  final int discountRes; // 0..3 resource discount by 1 when visiting parks
  final int bonusRes; // 0..4 bonus resource gained on purchase
  final String desc;

  const GearCard(
    this.id,
    this.name,
    this.sunCost,
    this.discountRes,
    this.bonusRes,
    this.desc,
  );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sunCost': sunCost,
        'discountRes': discountRes,
        'bonusRes': bonusRes,
        'desc': desc,
      };
}

class TrailSite {
  final int index;
  final String id;
  final String name;
  final String desc;

  const TrailSite(this.index, this.id, this.name, this.desc);

  Map<String, dynamic> toJson() => {
        'index': index,
        'id': id,
        'name': name,
        'desc': desc,
      };
}

const List<String> parksResourceNames = ['树木', '山脉', '阳光', '水滴', '野生动物'];
const List<String> parksResourceIcons = ['🌲', '⛰️', '☀️', '💧', '🦌'];

const List<TrailSite> parksDefaultTrail = [
  TrailSite(0, 'forest', '森林', '获得 +1🌲 树木'),
  TrailSite(1, 'mountain', '山脉', '获得 +1⛰️ 山脉'),
  TrailSite(2, 'sun', '阳光谷', '获得 +2☀️ 阳光'),
  TrailSite(3, 'water', '水域', '获得 +2💧 水滴'),
  TrailSite(4, 'wildlife', '动物保护区', '将1个基础资源换为1🦌（无资源则直接+1🦌）'),
  TrailSite(5, 'camp', '营地水壶/相机', '获得 +1🌲 与 +1💧 水壶补给'),
  TrailSite(6, 'end', '山径终点', '访问公园 / 预约公园 / 购买装备'),
];

const List<ParkCard> parksCatalog = [
  ParkCard(0, '黄石国家公园', 4, [2, 1, 1, 1]),
  ParkCard(1, '优胜美地', 4, [1, 2, 1, 1]),
  ParkCard(2, '大峡谷', 3, [0, 2, 2, 0]),
  ParkCard(3, '锡安国家公园', 3, [0, 2, 1, 1]),
  ParkCard(4, '奥林匹克', 4, [2, 1, 0, 2]),
  ParkCard(5, '大提顿', 3, [1, 2, 0, 1]),
  ParkCard(6, '冰川国家公园', 5, [2, 2, 1, 2]),
  ParkCard(7, '阿卡迪亚', 2, [1, 0, 1, 1]),
  ParkCard(8, '大雾山', 3, [2, 1, 0, 1]),
  ParkCard(9, '落基山', 3, [1, 2, 1, 0]),
  ParkCard(10, '拱门国家公园', 2, [0, 1, 2, 0]),
  ParkCard(11, '布莱斯峡谷', 3, [1, 1, 2, 0]),
  ParkCard(12, '红杉国家公园', 4, [3, 0, 1, 1]),
  ParkCard(13, '死谷国家公园', 2, [0, 1, 2, 0]),
  ParkCard(14, '大沼泽地', 3, [1, 0, 1, 2]),
  ParkCard(15, '火山口湖', 3, [1, 1, 0, 2]),
  ParkCard(16, '仙那度', 2, [2, 0, 1, 0]),
  ParkCard(17, '雷尼尔山', 4, [2, 2, 0, 1]),
  ParkCard(18, '峡谷地', 3, [0, 2, 1, 1]),
  ParkCard(19, '迪纳利', 5, [2, 3, 1, 1]),
  ParkCard(20, '约书亚树', 2, [1, 0, 2, 0]),
  ParkCard(21, '猛犸洞', 2, [1, 1, 0, 1]),
  ParkCard(22, '碧玉国家公园', 4, [1, 1, 1, 2]),
  ParkCard(23, '基奈峡湾', 4, [1, 1, 0, 3]),
];

const List<GearCard> parksGearCatalog = [
  GearCard(0, '登山杖', 1, 0, 0, '访问公园少付 1🌲，立即 +1🌲'),
  GearCard(1, '攀岩镐', 1, 1, 1, '访问公园少付 1⛰️，立即 +1⛰️'),
  GearCard(2, '遮阳帽', 1, 2, 2, '访问公园少付 1☀️，立即 +1☀️'),
  GearCard(3, '滤水壶', 1, 3, 3, '访问公园少付 1💧，立即 +1💧'),
  GearCard(4, '生态望远镜', 2, 0, 4, '访问公园少付 1🌲，立即 +1🦌'),
  GearCard(5, '野营指南针', 2, 1, 4, '访问公园少付 1⛰️，立即 +1🦌'),
  GearCard(6, '户外相机', 2, 2, 4, '访问公园少付 1☀️，立即 +1🦌'),
  GearCard(7, '探险背包', 2, 3, 4, '访问公园少付 1💧，立即 +1🦌'),
  GearCard(8, '森林图鉴', 1, 0, 2, '访问公园少付 1🌲，立即 +1☀️'),
  GearCard(9, '山岳地图', 1, 1, 3, '访问公园少付 1⛰️，立即 +1💧'),
];

class ParksGame extends GameEngine {
  late int totalSeasons;
  int season = 1;
  int turn = 0;
  int firstPlayer = 0;
  String phase = 'move'; // 'move' | 'end_action' | 'over'

  List<TrailSite> trail = List.of(parksDefaultTrail);
  late List<List<int>> hikers; // [seat][0..1], starts at -1, 6 = Trail End
  late List<bool> campfireLit;
  late List<List<int>> resources; // [seat][0..4]: Tree, Mountain, Sun, Water, Wildlife
  late List<List<int>> visitedParks;
  late List<List<int>> reservedParks;
  late List<List<int>> gears;
  late List<int> score;

  List<int> parkDeck = [];
  List<int> parksDisplay = [];
  List<int> gearDeck = [];
  List<int> gearDisplay = [];

  String lastAction = '新赛季开始';
  Map<String, dynamic>? result;

  ParksGame(super.setup);

  int get trailEndIdx => trail.length - 1;

  @override
  void start() {
    totalSeasons = setup.opt<int>('seasons', 3);
    season = 1;
    firstPlayer = 0;
    turn = 0;
    phase = 'move';

    hikers = List.generate(players, (_) => [-1, -1]);
    campfireLit = List.filled(players, true);
    resources = List.generate(players, (s) => [1, 1, 1 + (s % 2), 1, 0]);
    visitedParks = List.generate(players, (_) => <int>[]);
    reservedParks = List.generate(players, (_) => <int>[]);
    gears = List.generate(players, (_) => <int>[]);
    score = List.filled(players, 0);

    parkDeck = shuffled([for (var i = 0; i < parksCatalog.length; i++) i], rng);
    gearDeck = shuffled([for (var i = 0; i < parksGearCatalog.length; i++) i], rng);
    parksDisplay = [];
    gearDisplay = [];
    _refillDisplays();
    lastAction = '第 1 季开始，请移动徒步者前进';
    host.log(lastAction);
  }

  void _refillDisplays() {
    while (parksDisplay.length < 3 && parkDeck.isNotEmpty) {
      parksDisplay.add(parkDeck.removeLast());
    }
    while (gearDisplay.length < 3 && gearDeck.isNotEmpty) {
      gearDisplay.add(gearDeck.removeLast());
    }
  }

  @override
  bool get isOver => phase == 'over';

  @override
  List<int> get waitingFor => isOver ? const [] : [turn];

  @override
  List<int>? get placings => isOver ? rankByScore(score) : null;

  /// Effective cost of a park for [seat] after gear discounts (each gear reduces its resource by 1, min 0).
  List<int> effectiveParkCost(int seat, int parkId) {
    final base = List<int>.of(parksCatalog[parkId].cost);
    for (final gId in gears[seat]) {
      final d = parksGearCatalog[gId].discountRes;
      if (d >= 0 && d < 4 && base[d] > 0) {
        base[d]--;
      }
    }
    return base;
  }

  bool canAffordPark(int seat, int parkId) {
    final cost = effectiveParkCost(seat, parkId);
    var missing = 0;
    for (var r = 0; r < 4; r++) {
      if (resources[seat][r] < cost[r]) {
        missing += cost[r] - resources[seat][r];
      }
    }
    return resources[seat][4] >= missing;
  }

  void _payForPark(int seat, int parkId) {
    final cost = effectiveParkCost(seat, parkId);
    var missing = 0;
    for (var r = 0; r < 4; r++) {
      final useBasic = min(resources[seat][r], cost[r]);
      resources[seat][r] -= useBasic;
      missing += cost[r] - useBasic;
    }
    resources[seat][4] -= missing;
  }

  bool isSiteOccupied(int siteIdx) {
    if (siteIdx < 0 || siteIdx >= trailEndIdx) return false;
    for (var s = 0; s < players; s++) {
      if (hikers[s][0] == siteIdx || hikers[s][1] == siteIdx) return true;
    }
    return false;
  }

  bool canMoveHiker(int seat, int hikerIdx, int to) {
    if (hikerIdx < 0 || hikerIdx > 1) return false;
    final from = hikers[seat][hikerIdx];
    if (from >= trailEndIdx) return false;
    if (to <= from || to > trailEndIdx) return false;
    if (to < trailEndIdx && isSiteOccupied(to) && !campfireLit[seat]) {
      return false;
    }
    return true;
  }

  int minActivePos(int seat) {
    var m = 999;
    for (final p in hikers[seat]) {
      if (p < trailEndIdx && p < m) m = p;
    }
    return m;
  }

  void _updateScores() {
    for (var s = 0; s < players; s++) {
      var pts = 0;
      for (final pid in visitedParks[s]) {
        pts += parksCatalog[pid].vp;
      }
      if (isOver && s == firstPlayer) {
        pts += 1; // 起始玩家徽章 1 分
      }
      score[s] = pts;
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');
    final type = asStr(action['type']);

    if (type == 'move') {
      if (phase != 'move') throw GameError('请先完成山径终点行动');
      final h = asInt(action['hiker'], 0);
      final to = asInt(action['to'], -1);
      if (h < 0 || h > 1) throw GameError('无效的徒步者编号');
      final from = hikers[seat][h];
      if (from >= trailEndIdx) throw GameError('该徒步者已到达终点');
      if (to <= from || to > trailEndIdx) throw GameError('必须向前移动到有效地点');

      if (to < trailEndIdx) {
        final occupied = isSiteOccupied(to);
        if (occupied) {
          if (!campfireLit[seat]) {
            throw GameError('该地点已有其他徒步者且你的篝火已熄灭');
          }
          campfireLit[seat] = false;
        }
        hikers[seat][h] = to;
        _applyTrailSite(seat, to, action);
        _advanceTurn(seat);
      } else {
        // Reached Trail End
        hikers[seat][h] = trailEndIdx;
        campfireLit[seat] = true;
        final inlineEnd = asStr(action['endAction']);
        if (inlineEnd.isNotEmpty) {
          _handleEndAction(seat, inlineEnd, action);
        } else {
          phase = 'end_action';
          lastAction = '${name(seat)} 到达山径终点（篝火重燃），请选择终点行动';
        }
      }
      _updateScores();
      return;
    }

    if (type == 'visit_park' || type == 'reserve_park' || type == 'buy_gear') {
      if (phase == 'move') {
        // Convenience: if invoked directly during 'move', move rear-most active hiker to Trail End first
        final h = hikers[seat][0] < trailEndIdx
            ? (hikers[seat][1] < trailEndIdx && hikers[seat][1] < hikers[seat][0] ? 1 : 0)
            : 1;
        if (hikers[seat][h] >= trailEndIdx) {
          throw GameError('没有可移动到终点的徒步者');
        }
        hikers[seat][h] = trailEndIdx;
        campfireLit[seat] = true;
      }
      _handleEndAction(seat, type, action);
      _updateScores();
      return;
    }

    throw GameError('未知操作类型: $type');
  }

  void _applyTrailSite(int seat, int siteIdx, Map<String, dynamic> action) {
    final site = trail[siteIdx];
    switch (site.id) {
      case 'forest':
        resources[seat][0] += 1;
        lastAction = '${name(seat)} 前往森林 (+1🌲)';
        break;
      case 'mountain':
        resources[seat][1] += 1;
        lastAction = '${name(seat)} 前往山脉 (+1⛰️)';
        break;
      case 'sun':
        resources[seat][2] += 2;
        lastAction = '${name(seat)} 前往阳光谷 (+2☀️)';
        break;
      case 'water':
        resources[seat][3] += 2;
        lastAction = '${name(seat)} 前往水域 (+2💧)';
        break;
      case 'wildlife':
        final spend = asInt(action['spend'], -1);
        if (spend >= 0 && spend < 4 && resources[seat][spend] > 0) {
          resources[seat][spend]--;
          resources[seat][4] += 2;
          lastAction = '${name(seat)} 在保护区用1${parksResourceIcons[spend]}换取 +2🦌';
        } else {
          var traded = false;
          for (var r = 2; r <= 3; r++) {
            if (resources[seat][r] >= 3) {
              resources[seat][r]--;
              resources[seat][4] += 2;
              traded = true;
              break;
            }
          }
          if (!traded) {
            resources[seat][4] += 1;
          }
          lastAction = '${name(seat)} 前往动物保护区 (+1🦌)';
        }
        break;
      case 'camp':
        resources[seat][0] += 1;
        resources[seat][3] += 1;
        lastAction = '${name(seat)} 在营地使用水壶/相机 (+1🌲 +1💧)';
        break;
      default:
        break;
    }
  }

  void _handleEndAction(int seat, String type, Map<String, dynamic> action) {
    if (type == 'visit_park') {
      final fromReserved = asBool(action['reserved']) || asStr(action['from']) == 'reserved';
      final idx = asInt(action['park'], asInt(action['index'], 0));
      int parkId;
      if (fromReserved) {
        if (idx < 0 || idx >= reservedParks[seat].length) {
          throw GameError('无效的已预约公园编号');
        }
        parkId = reservedParks[seat][idx];
        if (!canAffordPark(seat, parkId)) {
          throw GameError('资源不足，无法访问该国家公园');
        }
        _payForPark(seat, parkId);
        reservedParks[seat].removeAt(idx);
      } else {
        if (idx < 0 || idx >= parksDisplay.length) {
          throw GameError('无效的公园编号');
        }
        parkId = parksDisplay[idx];
        if (!canAffordPark(seat, parkId)) {
          throw GameError('资源不足，无法访问该国家公园');
        }
        _payForPark(seat, parkId);
        parksDisplay.removeAt(idx);
        _refillDisplays();
      }
      visitedParks[seat].add(parkId);
      final p = parksCatalog[parkId];
      lastAction = '${name(seat)} 访问了【${p.name}】(+${p.vp}分)';
      host.log(lastAction);
    } else if (type == 'reserve_park') {
      final idx = asInt(action['park'], asInt(action['index'], 0));
      if (parksDisplay.isNotEmpty) {
        final safeIdx = idx.clamp(0, parksDisplay.length - 1);
        final parkId = parksDisplay.removeAt(safeIdx);
        reservedParks[seat].add(parkId);
        _refillDisplays();
        resources[seat][2] += 1; // 预约奖励 +1☀️
        firstPlayer = seat;
        lastAction = '${name(seat)} 预约了【${parksCatalog[parkId].name}】(+1☀️)';
      } else {
        resources[seat][4] += 1;
        lastAction = '${name(seat)} 在终点修整 (+1🦌)';
      }
    } else if (type == 'buy_gear') {
      final idx = asInt(action['gear'], asInt(action['index'], 0));
      if (idx < 0 || idx >= gearDisplay.length) {
        throw GameError('无效的装备编号');
      }
      final gId = gearDisplay[idx];
      final g = parksGearCatalog[gId];
      final sunNeed = g.sunCost;
      final useSun = min(resources[seat][2], sunNeed);
      final needWild = sunNeed - useSun;
      if (resources[seat][4] < needWild) {
        throw GameError('阳光不足，无法购买该装备');
      }
      resources[seat][2] -= useSun;
      resources[seat][4] -= needWild;
      gearDisplay.removeAt(idx);
      gears[seat].add(gId);
      resources[seat][g.bonusRes] += 1;
      _refillDisplays();
      lastAction = '${name(seat)} 购买了装备【${g.name}】';
    }

    phase = 'move';
    _advanceTurn(seat);
  }

  void _advanceTurn(int lastSeat) {
    // Check if any player still has an active hiker (< trailEndIdx)
    var bestMin = 999;
    for (var s = 0; s < players; s++) {
      final m = minActivePos(s);
      if (m < bestMin) bestMin = m;
    }

    if (bestMin >= trailEndIdx) {
      // All hikers reached Trail End -> end of Season!
      if (season < totalSeasons) {
        season++;
        for (var s = 0; s < players; s++) {
          hikers[s] = [-1, -1];
          campfireLit[s] = true;
          // Season weather supply bonus
          resources[s][(season + s) % 4] += 1;
        }
        turn = firstPlayer;
        phase = 'move';
        lastAction = '第 $season 季开始，所有徒步者回到起点且篝火重燃！';
        host.log(lastAction);
      } else {
        phase = 'over';
        _updateScores();
        final winners = <String>[];
        final p = placings!;
        for (var s = 0; s < players; s++) {
          if (p[s] == 1) winners.add(name(s));
        }
        result = {
          'winners': winners,
          'scores': score,
          'visitedCounts': [for (var s = 0; s < players; s++) visitedParks[s].length],
        };
        lastAction = '旅程结束！获胜者：${winners.join('、')}';
        host.log(lastAction);
      }
      return;
    }

    // Choose player with the rear-most hiker; break ties starting from (lastSeat + 1) % players
    for (var i = 1; i <= players; i++) {
      final s = (lastSeat + i) % players;
      if (minActivePos(s) == bestMin) {
        turn = s;
        return;
      }
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || seat != turn) return null;

    if (phase == 'end_action') {
      // 1. Try visiting the highest VP park we can afford (reserved or display)
      var bestIdx = -1;
      var bestVp = -1;
      var bestReserved = false;
      for (var i = 0; i < reservedParks[seat].length; i++) {
        final pid = reservedParks[seat][i];
        if (canAffordPark(seat, pid) && parksCatalog[pid].vp > bestVp) {
          bestVp = parksCatalog[pid].vp;
          bestIdx = i;
          bestReserved = true;
        }
      }
      for (var i = 0; i < parksDisplay.length; i++) {
        final pid = parksDisplay[i];
        if (canAffordPark(seat, pid) && parksCatalog[pid].vp > bestVp) {
          bestVp = parksCatalog[pid].vp;
          bestIdx = i;
          bestReserved = false;
        }
      }
      if (bestIdx != -1) {
        return {'type': 'visit_park', 'park': bestIdx, 'reserved': bestReserved};
      }

      // 2. Try buying gear if we have enough Sun and fewer than 3 gears
      if (gears[seat].length < 3) {
        for (var i = 0; i < gearDisplay.length; i++) {
          final g = parksGearCatalog[gearDisplay[i]];
          if (resources[seat][2] >= g.sunCost) {
            return {'type': 'buy_gear', 'gear': i};
          }
        }
      }

      // 3. Reserve a park
      return {'type': 'reserve_park', 'park': 0};
    }

    // phase == 'move': choose a hiker (prefer the rear-most one)
    final h = hikers[seat][0] <= hikers[seat][1] ? 0 : 1;
    final activeH = hikers[seat][h] < trailEndIdx ? h : (1 - h);
    final curPos = hikers[seat][activeH];

    // Try moving 1..2 steps forward to an unoccupied site (or use campfire if needed)
    for (var target = curPos + 1; target < trailEndIdx; target++) {
      if (!isSiteOccupied(target)) {
        return {'type': 'move', 'hiker': activeH, 'to': target};
      }
    }
    for (var target = curPos + 1; target < trailEndIdx; target++) {
      if (canMoveHiker(seat, activeH, target)) {
        return {'type': 'move', 'hiker': activeH, 'to': target};
      }
    }
    return {'type': 'move', 'hiker': activeH, 'to': trailEndIdx};
  }

  @override
  Map<String, dynamic> view(int seat) => {
        'season': season,
        'totalSeasons': totalSeasons,
        'turn': turn,
        'firstPlayer': firstPlayer,
        'phase': phase,
        'lastAction': lastAction,
        'trail': [for (final t in trail) t.toJson()],
        'hikers': hikers,
        'campfireLit': campfireLit,
        'resources': resources,
        'score': score,
        'parksDisplay': [for (final id in parksDisplay) parksCatalog[id].toJson()],
        'gearDisplay': [for (final id in gearDisplay) parksGearCatalog[id].toJson()],
        'visitedParks': [
          for (var s = 0; s < players; s++)
            [for (final id in visitedParks[s]) parksCatalog[id].toJson()]
        ],
        'reservedParks': [
          for (var s = 0; s < players; s++)
            [for (final id in reservedParks[s]) parksCatalog[id].toJson()]
        ],
        'gears': [
          for (var s = 0; s < players; s++)
            [for (final id in gears[s]) parksGearCatalog[id].toJson()]
        ],
        'canMove': [
          for (var h = 0; h < 2; h++)
            [
              if (seat >= 0 && seat < players)
                for (var to = 0; to <= trailEndIdx; to++)
                  if (canMoveHiker(seat, h, to)) to
            ]
        ],
        'result': result,
      };
}
