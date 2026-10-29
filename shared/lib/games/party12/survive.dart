import 'dart:math';

import '../../src/engine.dart';

class SurviveExplorer {
  final int id;
  final int owner;
  final int value; // 1, 1, 2, 2, 3, 4
  int r;
  int c;
  String status; // 'alive' | 'rescued' | 'dead'
  int? boatId;

  SurviveExplorer({
    required this.id,
    required this.owner,
    required this.value,
    required this.r,
    required this.c,
    this.status = 'alive',
    this.boatId,
  });

  Map<String, dynamic> toView(int viewerSeat, {required bool isOver}) {
    final canSeeValue = isOver || viewerSeat == owner || status != 'alive';
    return {
      'id': id,
      'owner': owner,
      'value': canSeeValue ? value : null,
      'r': r,
      'c': c,
      'status': status,
      'boatId': boatId,
    };
  }
}

class SurviveBoat {
  final int id;
  int r;
  int c;
  SurviveBoat({required this.id, required this.r, required this.c});

  Map<String, dynamic> toJson() => {'id': id, 'r': r, 'c': c};
}

class SurviveCreature {
  final int id;
  final String type; // 'serpent' | 'shark' | 'whale'
  int r;
  int c;
  SurviveCreature({
    required this.id,
    required this.type,
    required this.r,
    required this.c,
  });

  int get maxRange => type == 'serpent' ? 1 : (type == 'shark' ? 2 : 3);

  String get label => type == 'serpent' ? '海怪' : (type == 'shark' ? '鲨鱼' : '鲸鱼');

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'label': label,
        'maxRange': maxRange,
        'r': r,
        'c': c,
      };
}

class SurviveGame extends GameEngine {
  static const int boardSize = 7;

  /// Terrain grid 7x7: 0 = Ocean, 1 = Beach (沙滩), 2 = Forest (森林), 3 = Mountain (山峰)
  late List<List<int>> terrain;

  /// Hidden underside effects on island tiles: '' | 'shark' | 'whale' | 'boat' | 'whirlpool' | 'volcano'
  late List<List<String>> tileEffects;

  final List<SurviveExplorer> explorers = [];
  final List<SurviveBoat> boats = [];
  final List<SurviveCreature> creatures = [];

  late List<int> score;
  late List<int> rescuedCount;

  /// Phase: 'move' | 'sink' | 'creature' | 'end'
  String phase = 'move';
  int turnSeat = 0;
  int movesLeft = 3;
  int _nextEntityId = 1;
  bool volcanoErupted = false;
  Map<String, dynamic>? lastSinkEvent;

  SurviveGame(super.setup);

  static bool isSafeIsland(int r, int c) =>
      (r == 0 || r == boardSize - 1) && (c == 0 || c == boardSize - 1);

  static bool isInBounds(int r, int c) =>
      r >= 0 && r < boardSize && c >= 0 && c < boardSize;

  static int distToNearestSafe(int r, int c) {
    const corners = [(0, 0), (0, 6), (6, 0), (6, 6)];
    var best = 99;
    for (final (cr, cc) in corners) {
      final d = (r - cr).abs() + (c - cc).abs();
      if (d < best) best = d;
    }
    return best;
  }

  @override
  void start() {
    terrain = List.generate(boardSize, (_) => List.filled(boardSize, 0));
    tileEffects = List.generate(boardSize, (_) => List.filled(boardSize, ''));
    explorers.clear();
    boats.clear();
    creatures.clear();
    score = List.filled(players, 0);
    rescuedCount = List.filled(players, 0);
    _nextEntityId = 1;
    volcanoErupted = false;
    lastSinkEvent = null;

    // 21 island spaces inside rows 1..5, cols 1..5 excluding (1,1), (1,5), (5,1), (5,5)
    final islandCells = <(int, int)>[];
    for (var r = 1; r <= 5; r++) {
      for (var c = 1; c <= 5; c++) {
        if ((r == 1 || r == 5) && (c == 1 || c == 5)) continue;
        islandCells.add((r, c));
      }
    }

    // 8 Beach (1), 7 Forest (2), 6 Mountain (3)
    final terrains = shuffled(<int>[
      1, 1, 1, 1, 1, 1, 1, 1,
      2, 2, 2, 2, 2, 2, 2,
      3, 3, 3, 3, 3, 3,
    ], rng);

    final beachEffects = shuffled(<String>[
      'boat', 'boat', 'boat', 'shark', 'shark', 'shark', 'whale', 'whale'
    ], rng);
    final forestEffects = shuffled(<String>[
      'shark', 'shark', 'whale', 'whale', 'boat', 'whirlpool', 'whirlpool'
    ], rng);
    final mountainEffects = shuffled(<String>[
      'volcano', 'whirlpool', 'whirlpool', 'shark', 'shark', 'whale'
    ], rng);

    var bIdx = 0, fIdx = 0, mIdx = 0;
    for (var i = 0; i < islandCells.length; i++) {
      final (r, c) = islandCells[i];
      final t = terrains[i];
      terrain[r][c] = t;
      if (t == 1) {
        tileEffects[r][c] = beachEffects[bIdx++];
      } else if (t == 2) {
        tileEffects[r][c] = forestEffects[fIdx++];
      } else {
        tileEffects[r][c] = mountainEffects[mIdx++];
      }
    }

    // Place 6 Explorers per player with secret values [1, 1, 2, 2, 3, 4]
    const secretValues = [1, 1, 2, 2, 3, 4];
    final startCells = shuffled(islandCells, rng);
    for (var s = 0; s < players; s++) {
      final vals = shuffled(secretValues, rng);
      for (var i = 0; i < 6; i++) {
        final (r, c) = startCells[(s * 6 + i) % startCells.length];
        explorers.add(SurviveExplorer(
          id: _nextEntityId++,
          owner: s,
          value: vals[i],
          r: r,
          c: c,
        ));
      }
    }

    // Place initial Boats on coastal ocean spaces
    const startBoatSpaces = [(1, 1), (1, 5), (5, 1), (5, 5)];
    for (var i = 0; i < players; i++) {
      final (r, c) = startBoatSpaces[i % startBoatSpaces.length];
      boats.add(SurviveBoat(id: _nextEntityId++, r: r, c: c));
    }

    // Place 2 initial Sea Serpents in outer ocean spaces
    creatures.add(SurviveCreature(id: _nextEntityId++, type: 'serpent', r: 0, c: 3));
    creatures.add(SurviveCreature(id: _nextEntityId++, type: 'serpent', r: 6, c: 3));

    turnSeat = 0;
    phase = 'move';
    movesLeft = 3;
    if (!_hasAnyLivingExplorer(turnSeat)) {
      _enterSinkPhase();
    }
    host.log('逃离亚特兰蒂斯开始！趁火山爆发前，护送探险家逃往四角安全岛！');
  }

  bool _hasAnyLivingExplorer([int? seat]) => explorers.any(
        (e) => e.status == 'alive' && (seat == null || e.owner == seat),
      );

  int get minIslandTerrain {
    var minT = 99;
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        final t = terrain[r][c];
        if (t > 0 && t < minT) minT = t;
      }
    }
    return minT == 99 ? 0 : minT;
  }

  List<SurviveExplorer> passengersOnBoat(int boatId) =>
      explorers.where((e) => e.status == 'alive' && e.boatId == boatId).toList();

  bool canControlBoat(int seat, SurviveBoat boat) {
    final pass = passengersOnBoat(boat.id);
    if (pass.isEmpty) return true;
    final counts = List.filled(players, 0);
    for (final p in pass) {
      counts[p.owner]++;
    }
    final maxCount = counts.reduce(max);
    return counts[seat] > 0 && counts[seat] == maxCount;
  }

  @override
  bool get isOver => phase == 'end';

  @override
  List<int> get waitingFor => isOver ? const [] : [turnSeat];

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('游戏已结束');
    if (seat != turnSeat) throw GameError('当前不是你的回合');

    final type = asStr(action['type']);

    if (phase == 'move') {
      if (type == 'end_move' || type == 'pass') {
        _enterSinkPhase();
        return;
      }
      if (type == 'move') {
        final expId = asInt(action['explorerId'] ?? action['id'], -1);
        final toR = asInt(action['r'], -1);
        final toC = asInt(action['c'], -1);
        final exp = explorers.where((e) => e.id == expId).firstOrNull;
        if (exp == null || exp.owner != seat || exp.status != 'alive') {
          throw GameError('请选择你方存活的探险家');
        }
        if (!isInBounds(toR, toC) || (exp.r - toR).abs() + (exp.c - toC).abs() != 1) {
          throw GameError('探险家每次只能向相邻正交格移动 1 步');
        }
        _moveExplorer(exp, toR, toC);
        movesLeft--;
        if (movesLeft <= 0 || !_hasAnyLivingExplorer(seat)) {
          _enterSinkPhase();
        }
        return;
      }
      if (type == 'move_boat') {
        final boatId = asInt(action['boatId'] ?? action['id'], -1);
        final toR = asInt(action['r'], -1);
        final toC = asInt(action['c'], -1);
        final boat = boats.where((b) => b.id == boatId).firstOrNull;
        if (boat == null) throw GameError('未找到指定的小船');
        if (!canControlBoat(seat, boat)) {
          throw GameError('你在这艘船上没有控制权（需空船或拥有最多探险家）');
        }
        if (!isInBounds(toR, toC) || (boat.r - toR).abs() + (boat.c - toC).abs() != 1) {
          throw GameError('小船每次只能向相邻正交海域移动 1 步');
        }
        if (terrain[toR][toC] > 0) {
          throw GameError('小船不能驶上陆地');
        }
        _moveBoat(boat, toR, toC);
        movesLeft--;
        if (movesLeft <= 0 || !_hasAnyLivingExplorer(seat)) {
          _enterSinkPhase();
        }
        return;
      }
      throw GameError('移动阶段请移动探险家(move)、移动小船(move_boat)或结束移动(end_move)');
    }

    if (phase == 'sink') {
      if (type != 'sink') throw GameError('请选择一块最低海拔的岛屿板块使其沉没(sink)');
      final r = asInt(action['r'], -1);
      final c = asInt(action['c'], -1);
      if (!isInBounds(r, c) || terrain[r][c] <= 0) {
        throw GameError('请选择一块尚未沉没的岛屿板块');
      }
      final reqTerrain = minIslandTerrain;
      if (terrain[r][c] != reqTerrain) {
        const names = ['', '沙滩', '森林', '山峰'];
        throw GameError('必须优先沉没当前最低海拔板块：【${names[reqTerrain]}】');
      }
      _sinkTile(seat, r, c);
      return;
    }

    if (phase == 'creature') {
      if (type == 'pass') {
        _finishTurn();
        return;
      }
      if (type != 'creature' && type != 'move_creature') {
        throw GameError('请移动一只海怪/海洋生物(creature)或跳过(pass)');
      }
      final cId = asInt(action['creatureId'] ?? action['id'], -1);
      final toR = asInt(action['r'], -1);
      final toC = asInt(action['c'], -1);
      final creature = creatures.where((cr) => cr.id == cId).firstOrNull;
      if (creature == null) throw GameError('未找到指定的海洋生物');
      if (!isInBounds(toR, toC) || isSafeIsland(toR, toC) || terrain[toR][toC] > 0) {
        throw GameError('海洋生物只能在海域格中移动');
      }
      final dist = (creature.r - toR).abs() + (creature.c - toC).abs();
      if (dist < 1 || dist > creature.maxRange) {
        throw GameError('${creature.label}最多只能移动 ${creature.maxRange} 格');
      }
      creature.r = toR;
      creature.c = toC;
      _resolveCreaturesAt(toR, toC);
      _finishTurn();
      return;
    }
  }

  void _moveExplorer(SurviveExplorer exp, int toR, int toC) {
    exp.r = toR;
    exp.c = toC;
    exp.boatId = null;

    if (isSafeIsland(toR, toC)) {
      exp.status = 'rescued';
      score[exp.owner] += exp.value;
      rescuedCount[exp.owner]++;
      host.log('${name(exp.owner)} 的探险家成功登上安全岛，带回 ${exp.value} 分宝藏！');
      return;
    }

    if (terrain[toR][toC] == 0) {
      // Check if there is a boat with capacity < 3
      for (final b in boats) {
        if (b.r == toR && b.c == toC && passengersOnBoat(b.id).length < 3) {
          exp.boatId = b.id;
          break;
        }
      }
      _resolveCreaturesAt(toR, toC);
    }
  }

  void _moveBoat(SurviveBoat boat, int toR, int toC) {
    final pass = passengersOnBoat(boat.id);
    if (isSafeIsland(toR, toC)) {
      // Unload and rescue all passengers on the safe island!
      for (final exp in pass) {
        exp.r = toR;
        exp.c = toC;
        exp.boatId = null;
        exp.status = 'rescued';
        score[exp.owner] += exp.value;
        rescuedCount[exp.owner]++;
        host.log('${name(exp.owner)} 的探险家乘船抵达安全岛，获得 ${exp.value} 分！');
      }
      return;
    }

    boat.r = toR;
    boat.c = toC;
    for (final exp in pass) {
      exp.r = toR;
      exp.c = toC;
    }
    // Also pick up any swimmers at destination up to capacity 3
    for (final exp in explorers) {
      if (exp.status == 'alive' && exp.r == toR && exp.c == toC && exp.boatId == null) {
        if (passengersOnBoat(boat.id).length < 3) {
          exp.boatId = boat.id;
        }
      }
    }
    _resolveCreaturesAt(toR, toC);
  }

  void _enterSinkPhase() {
    if (!_hasAnyLivingExplorer() || minIslandTerrain == 0) {
      phase = 'end';
      host.log('逃离亚特兰蒂斯结束！');
      return;
    }
    phase = 'sink';
  }

  void _sinkTile(int seat, int r, int c) {
    final oldTerrain = terrain[r][c];
    final effect = tileEffects[r][c];
    terrain[r][c] = 0;
    tileEffects[r][c] = '';

    const tNames = ['', '沙滩', '森林', '山峰'];
    lastSinkEvent = {
      'seat': seat,
      'r': r,
      'c': c,
      'terrain': oldTerrain,
      'effect': effect,
    };

    if (effect == 'volcano') {
      volcanoErupted = true;
      for (final e in explorers) {
        if (e.status == 'alive') {
          e.status = 'dead';
          e.boatId = null;
        }
      }
      phase = 'end';
      host.log('${name(seat)} 翻开了【火山爆发】！亚特兰蒂斯彻底沉没，游戏立即结束！');
      return;
    }

    if (effect == 'whirlpool') {
      host.log('${name(seat)} 沉没了 (${r + 1},${c + 1}) 的${tNames[oldTerrain]}，触发【大漩涡】！周边海域船只与生物全部卷入深渊！');
      for (final (dr, dc) in const [(0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)]) {
        final nr = r + dr;
        final nc = c + dc;
        if (!isInBounds(nr, nc) || isSafeIsland(nr, nc) || terrain[nr][nc] > 0) continue;
        boats.removeWhere((b) => b.r == nr && b.c == nc);
        creatures.removeWhere((cr) => cr.r == nr && cr.c == nc);
        for (final e in explorers) {
          if (e.status == 'alive' && e.r == nr && e.c == nc) {
            e.status = 'dead';
            e.boatId = null;
          }
        }
      }
    } else if (effect == 'boat') {
      final b = SurviveBoat(id: _nextEntityId++, r: r, c: c);
      boats.add(b);
      for (final e in explorers) {
        if (e.status == 'alive' && e.r == r && e.c == c && e.boatId == null) {
          if (passengersOnBoat(b.id).length < 3) {
            e.boatId = b.id;
          }
        }
      }
      host.log('${name(seat)} 沉没了 (${r + 1},${c + 1}) 的${tNames[oldTerrain]}，发现一艘【救生小船】！');
    } else if (effect == 'shark' || effect == 'whale') {
      final cr = SurviveCreature(id: _nextEntityId++, type: effect, r: r, c: c);
      creatures.add(cr);
      host.log('${name(seat)} 沉没了 (${r + 1},${c + 1}) 的${tNames[oldTerrain]}，引出了【${cr.label}】！');
      _resolveCreaturesAt(r, c);
    } else {
      host.log('${name(seat)} 沉没了 (${r + 1},${c + 1}) 的${tNames[oldTerrain]}。');
    }

    if (!_hasAnyLivingExplorer() || minIslandTerrain == 0) {
      phase = 'end';
      host.log('所有探险家均已结算，游戏结束！');
      return;
    }

    if (creatures.isNotEmpty) {
      phase = 'creature';
    } else {
      _finishTurn();
    }
  }

  void _resolveCreaturesAt(int r, int c) {
    final cellCreatures = creatures.where((cr) => cr.r == r && cr.c == c).toList();
    if (cellCreatures.isEmpty) return;

    final hasSerpent = cellCreatures.any((cr) => cr.type == 'serpent');
    final hasWhale = cellCreatures.any((cr) => cr.type == 'whale');
    final hasShark = cellCreatures.any((cr) => cr.type == 'shark');

    if (hasSerpent) {
      boats.removeWhere((b) => b.r == r && b.c == c);
      for (final e in explorers) {
        if (e.status == 'alive' && e.r == r && e.c == c) {
          e.status = 'dead';
          e.boatId = null;
        }
      }
      return;
    }

    if (hasWhale) {
      final removedBoats = boats.where((b) => b.r == r && b.c == c).toList();
      if (removedBoats.isNotEmpty) {
        boats.removeWhere((b) => b.r == r && b.c == c);
        for (final e in explorers) {
          if (e.status == 'alive' && e.r == r && e.c == c) {
            e.boatId = null;
          }
        }
      }
    }

    if (hasShark) {
      for (final e in explorers) {
        if (e.status == 'alive' && e.r == r && e.c == c && e.boatId == null) {
          e.status = 'dead';
        }
      }
    }
  }

  void _finishTurn() {
    if (!_hasAnyLivingExplorer() || minIslandTerrain == 0) {
      phase = 'end';
      host.log('逃离亚特兰蒂斯结束！');
      return;
    }
    turnSeat = (turnSeat + 1) % players;
    phase = 'move';
    movesLeft = 3;
    if (!_hasAnyLivingExplorer(turnSeat)) {
      _enterSinkPhase();
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (!waitingFor.contains(seat)) return null;

    if (phase == 'move') {
      final myAlive = explorers
          .where((e) => e.owner == seat && e.status == 'alive')
          .toList();
      if (myAlive.isEmpty) return {'type': 'end_move'};

      // Sort by secret value descending on normal/hard bot so high-value explorers escape first
      if (botLevel >= 1) {
        myAlive.sort((a, b) => b.value.compareTo(a.value));
      } else {
        myAlive.shuffle(rng);
      }

      // Check if we can move a controlled boat closer to a Safe Island
      for (final b in boats) {
        final pass = passengersOnBoat(b.id);
        final myOnBoat = pass.where((e) => e.owner == seat).length;
        if (myOnBoat > 0 && canControlBoat(seat, b)) {
          final curDist = distToNearestSafe(b.r, b.c);
          for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
            final nr = b.r + dr;
            final nc = b.c + dc;
            if (!isInBounds(nr, nc) || terrain[nr][nc] > 0) continue;
            final danger = creatures.any((cr) => cr.r == nr && cr.c == nc && (cr.type == 'serpent' || cr.type == 'whale'));
            if (!danger && distToNearestSafe(nr, nc) < curDist) {
              return {'type': 'move_boat', 'boatId': b.id, 'r': nr, 'c': nc};
            }
          }
        }
      }

      // Move an explorer closer to a Safe Island
      for (final e in myAlive) {
        final curDist = distToNearestSafe(e.r, e.c);
        var bestR = -1, bestC = -1, bestDist = curDist;
        for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
          final nr = e.r + dr;
          final nc = e.c + dc;
          if (!isInBounds(nr, nc)) continue;
          if (isSafeIsland(nr, nc)) {
            return {'type': 'move', 'explorerId': e.id, 'r': nr, 'c': nc};
          }
          final danger = terrain[nr][nc] == 0 &&
              creatures.any((cr) => cr.r == nr && cr.c == nc && (cr.type == 'serpent' || cr.type == 'shark'));
          if (danger) continue;
          final d = distToNearestSafe(nr, nc);
          if (d < bestDist) {
            bestDist = d;
            bestR = nr;
            bestC = nc;
          }
        }
        if (bestR >= 0) {
          return {'type': 'move', 'explorerId': e.id, 'r': bestR, 'c': bestC};
        }
      }
      return {'type': 'end_move'};
    }

    if (phase == 'sink') {
      final reqT = minIslandTerrain;
      final candidates = <(int, int)>[];
      for (var r = 0; r < boardSize; r++) {
        for (var c = 0; c < boardSize; c++) {
          if (terrain[r][c] == reqT) candidates.add((r, c));
        }
      }
      if (candidates.isEmpty) return null;

      // Prefer sinking tiles with opponent explorers and without our own explorers
      var bestCell = candidates.first;
      var bestScore = -999;
      for (final (r, c) in candidates) {
        final myHere = explorers.where((e) => e.status == 'alive' && e.r == r && e.c == c && e.owner == seat).length;
        final oppHere = explorers.where((e) => e.status == 'alive' && e.r == r && e.c == c && e.owner != seat).length;
        final s = oppHere * 10 - myHere * 15 + rng.nextInt(3);
        if (s > bestScore) {
          bestScore = s;
          bestCell = (r, c);
        }
      }
      return {'type': 'sink', 'r': bestCell.$1, 'c': bestCell.$2};
    }

    if (phase == 'creature') {
      if (creatures.isEmpty) return {'type': 'pass'};
      for (final cr in creatures) {
        for (var r = 0; r < boardSize; r++) {
          for (var c = 0; c < boardSize; c++) {
            if (isSafeIsland(r, c) || terrain[r][c] > 0) continue;
            final dist = (cr.r - r).abs() + (cr.c - c).abs();
            if (dist < 1 || dist > cr.maxRange) continue;
            final oppHere = explorers.any((e) => e.status == 'alive' && e.r == r && e.c == c && e.owner != seat);
            final myHere = explorers.any((e) => e.status == 'alive' && e.r == r && e.c == c && e.owner == seat);
            if (oppHere && !myHere) {
              return {'type': 'creature', 'creatureId': cr.id, 'r': r, 'c': c};
            }
          }
        }
      }
      // Otherwise make any valid move with the first creature or pass
      final cr = creatures.first;
      for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
        final nr = cr.r + dr;
        final nc = cr.c + dc;
        if (isInBounds(nr, nc) && !isSafeIsland(nr, nc) && terrain[nr][nc] == 0) {
          return {'type': 'creature', 'creatureId': cr.id, 'r': nr, 'c': nc};
        }
      }
      return {'type': 'pass'};
    }

    return null;
  }

  @override
  List<int>? get placings => isOver ? rankByScore(score) : null;

  @override
  Map<String, dynamic> view(int seat) => {
        'phase': phase,
        'turnSeat': turnSeat,
        'movesLeft': movesLeft,
        'minIslandTerrain': minIslandTerrain,
        'terrain': terrain,
        'explorers': [
          for (final e in explorers) e.toView(seat, isOver: isOver)
        ],
        'boats': [for (final b in boats) b.toJson()],
        'creatures': [for (final cr in creatures) cr.toJson()],
        'score': score,
        'rescuedCount': rescuedCount,
        'volcanoErupted': volcanoErupted,
        'lastSinkEvent': lastSinkEvent,
        'waitingFor': waitingFor,
      };
}
