import '../../src/engine.dart';

class CryptidCell {
  final int index;
  final int row;
  final int col;
  final int terrain; // 0: 森林, 1: 沙漠, 2: 水域, 3: 沼泽, 4: 山脉
  final int animal; // 0: 无, 1: 熊领地, 2: 美洲狮领地
  final int structType; // 0: 无, 1: 木屋 Shack, 2: 巨石 Standing Stone
  final int structColor; // -1: 无, 0: 蓝, 1: 白, 2: 绿

  const CryptidCell({
    required this.index,
    required this.row,
    required this.col,
    required this.terrain,
    required this.animal,
    this.structType = 0,
    this.structColor = -1,
  });

  Map<String, dynamic> toJson() => {
        'index': index,
        'row': row,
        'col': col,
        'terrain': terrain,
        'animal': animal,
        'structType': structType,
        'structColor': structColor,
      };
}

class CryptidClue {
  final int id;
  final String text;
  final Set<int> matchingHexes;
  final int mask;

  CryptidClue({
    required this.id,
    required this.text,
    required this.matchingHexes,
  }) : mask = _buildMask(matchingHexes);

  static int _buildMask(Set<int> hexes) {
    var m = 0;
    for (final h in hexes) {
      m |= (1 << h);
    }
    return m;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'matchingHexes': matchingHexes.toList()..sort(),
      };
}

class CryptidGame extends GameEngine {
  CryptidGame(super.setup);

  static const int cols = 9;
  static const int rows = 6;
  static const int numHexes = 54;

  static const List<String> terrainNames = ['森林', '沙漠', '水域', '沼泽', '山脉'];
  static const List<String> animalNames = ['无', '熊领地', '美洲狮领地'];
  static const List<String> structTypeNames = ['无', '木屋', '巨石'];
  static const List<String> structColorNames = ['蓝', '白', '绿'];

  // Base terrain layout (9 cols x 6 rows = 54 cells, values 0..4)
  static const List<int> _baseTerrains = [
    0, 0, 2, 2, 1, 1, 4, 4, 3,
    0, 3, 2, 1, 1, 4, 4, 3, 3,
    3, 3, 0, 0, 2, 2, 4, 1, 1,
    4, 4, 0, 2, 2, 3, 3, 1, 0,
    4, 1, 1, 0, 3, 3, 2, 0, 0,
    1, 1, 4, 4, 0, 2, 2, 4, 3,
  ];

  // Animal territory layout (0: none, 1: bear, 2: cougar)
  static const List<int> _baseAnimals = [
    0, 1, 0, 0, 0, 2, 0, 0, 0,
    0, 1, 1, 0, 0, 2, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 2, 0,
    0, 0, 2, 0, 0, 0, 0, 1, 0,
    2, 0, 0, 0, 1, 0, 0, 0, 0,
    0, 0, 0, 1, 0, 0, 2, 0, 0,
  ];

  static final List<List<int>> _neighbors = _computeNeighbors();
  static final List<List<int>> _distances = _computeAllDistances();

  static List<List<int>> _computeNeighbors() {
    final adj = List.generate(numHexes, (_) => <int>[]);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final idx = r * cols + c;
        final candidates = <(int, int)>[
          (r, c - 1),
          (r, c + 1),
          if (r.isEven) ...[
            (r - 1, c - 1),
            (r - 1, c),
            (r + 1, c - 1),
            (r + 1, c),
          ] else ...[
            (r - 1, c),
            (r - 1, c + 1),
            (r + 1, c),
            (r + 1, c + 1),
          ],
        ];
        for (final (nr, nc) in candidates) {
          if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
            adj[idx].add(nr * cols + nc);
          }
        }
      }
    }
    return adj;
  }

  static List<List<int>> _computeAllDistances() {
    final dist = List.generate(numHexes, (_) => List.filled(numHexes, 99));
    for (var src = 0; src < numHexes; src++) {
      dist[src][src] = 0;
      final q = <int>[src];
      var head = 0;
      while (head < q.length) {
        final u = q[head++];
        final d = dist[src][u];
        for (final v in _neighbors[u]) {
          if (dist[src][v] > d + 1) {
            dist[src][v] = d + 1;
            q.add(v);
          }
        }
      }
    }
    return dist;
  }

  static int hexDistance(int a, int b) => _distances[a][b];

  static int _popCount(int mask) {
    var x = mask;
    var c = 0;
    while (x != 0) {
      x &= (x - 1);
      c++;
    }
    return c;
  }

  static int _lowestBitIndex(int mask) {
    for (var i = 0; i < numHexes; i++) {
      if ((mask & (1 << i)) != 0) return i;
    }
    return -1;
  }

  late List<CryptidCell> cells;
  late List<CryptidClue> cluePool;
  late List<CryptidClue> playerClues;
  int targetHex = 0;

  late List<int?> cubes; // cubes[h] = seat that placed a Cube (■ = No) on h, or null
  late List<List<int>> discs; // discs[h] = seats that placed a Disc (◯ = Yes) on h

  int turn = 0;
  String phase = 'turn'; // 'turn', 'penalty_cube', 'over'
  int winner = -1;
  String lastEvent = '';
  Map<String, dynamic>? lastAction;
  bool _over = false;

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _over && winner >= 0 ? rankWinners(players, [winner]) : null;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  void _buildMapAndCluePool() {
    // 6 structure placements across well-spaced anchor cells
    const anchorGroups = [
      [3, 12, 13],
      [7, 16, 17],
      [19, 20, 28],
      [23, 24, 32],
      [37, 38, 46],
      [42, 43, 51],
    ];
    final anchors = [
      for (final g in anchorGroups) g[rng.nextInt(g.length)],
    ];
    final structs = <(int, int)>[
      (1, 0), // 蓝木屋
      (1, 1), // 白木屋
      (1, 2), // 绿木屋
      (2, 0), // 蓝巨石
      (2, 1), // 白巨石
      (2, 2), // 绿巨石
    ]..shuffle(rng);

    final structAt = <int, (int, int)>{};
    for (var i = 0; i < 6; i++) {
      structAt[anchors[i]] = structs[i];
    }

    cells = [
      for (var idx = 0; idx < numHexes; idx++)
        CryptidCell(
          index: idx,
          row: idx ~/ cols,
          col: idx % cols,
          terrain: _baseTerrains[idx],
          animal: _baseAnimals[idx],
          structType: structAt[idx]?.$1 ?? 0,
          structColor: structAt[idx]?.$2 ?? -1,
        ),
    ];

    Set<int> withinRange(bool Function(CryptidCell) pred, int maxDist) {
      final sources = [
        for (final c in cells)
          if (pred(c)) c.index,
      ];
      final res = <int>{};
      for (var h = 0; h < numHexes; h++) {
        for (final s in sources) {
          if (_distances[h][s] <= maxDist) {
            res.add(h);
            break;
          }
        }
      }
      return res;
    }

    Set<int> complement(Set<int> s) => {
          for (var h = 0; h < numHexes; h++)
            if (!s.contains(h)) h,
        };

    final pool = <CryptidClue>[];
    void addClue(String text, Set<int> hexes) {
      if (hexes.length >= 5 && hexes.length <= numHexes - 6) {
        pool.add(CryptidClue(id: pool.length, text: text, matchingHexes: hexes));
      }
    }

    // 1. 10 Terrain pair clues + 10 negative terrain pair clues
    for (var t1 = 0; t1 < 5; t1++) {
      for (var t2 = t1 + 1; t2 < 5; t2++) {
        final pos = {
          for (final c in cells)
            if (c.terrain == t1 || c.terrain == t2) c.index,
        };
        addClue('在${terrainNames[t1]}或${terrainNames[t2]}上', pos);
        addClue('不在${terrainNames[t1]}或${terrainNames[t2]}上', complement(pos));
      }
    }

    // 2. Within 1 hex of each terrain + negative
    for (var t = 0; t < 5; t++) {
      final s = withinRange((c) => c.terrain == t, 1);
      addClue('距${terrainNames[t]} 1 格内', s);
      addClue('不在距${terrainNames[t]} 1 格内', complement(s));
    }

    // 3. Animal territory clues
    final animal1 = withinRange((c) => c.animal > 0, 1);
    addClue('距动物领地 1 格内', animal1);
    addClue('不在距动物领地 1 格内', complement(animal1));

    final animal2 = withinRange((c) => c.animal > 0, 2);
    addClue('距动物领地 2 格内', animal2);

    final bear2 = withinRange((c) => c.animal == 1, 2);
    addClue('距熊领地 2 格内', bear2);
    addClue('不在距熊领地 2 格内', complement(bear2));

    final cougar2 = withinRange((c) => c.animal == 2, 2);
    addClue('距美洲狮领地 2 格内', cougar2);
    addClue('不在距美洲狮领地 2 格内', complement(cougar2));

    // 4. Structure type clues (within 2)
    final shack2 = withinRange((c) => c.structType == 1, 2);
    addClue('距木屋 2 格内', shack2);
    addClue('不在距木屋 2 格内', complement(shack2));

    final stone2 = withinRange((c) => c.structType == 2, 2);
    addClue('距巨石 2 格内', stone2);
    addClue('不在距巨石 2 格内', complement(stone2));

    // 5. Structure color clues (within 3)
    for (var col = 0; col < 3; col++) {
      final col3 = withinRange((c) => c.structColor == col, 3);
      addClue('距${structColorNames[col]}色建筑 3 格内', col3);
      addClue('不在距${structColorNames[col]}色建筑 3 格内', complement(col3));
    }

    cluePool = pool;
  }

  bool _selectPlayerClues() {
    final fullMask = (1 << numHexes) - 1;
    final candidates = shuffled(cluePool, rng);
    final chosen = <CryptidClue>[];

    bool search(int startIdx, int curMask) {
      final depth = chosen.length;
      if (depth == players) {
        if (_popCount(curMask) != 1) return false;
        // Verify removing any single player's clue leaves >= 2 hexes
        for (var i = 0; i < players; i++) {
          var m = fullMask;
          for (var j = 0; j < players; j++) {
            if (j != i) m &= chosen[j].mask;
          }
          if (_popCount(m) < 2) return false;
        }
        playerClues = List<CryptidClue>.of(chosen);
        targetHex = _lowestBitIndex(curMask);
        return true;
      }

      final rem = players - depth;
      final minNeeded = rem == 1 ? 1 : 2;
      for (var i = startIdx; i < candidates.length; i++) {
        final c = candidates[i];
        final nextMask = curMask & c.mask;
        if (nextMask == curMask) continue; // must narrow down
        final cnt = _popCount(nextMask);
        if (cnt < minNeeded) continue;
        chosen.add(c);
        if (search(i + 1, nextMask)) return true;
        chosen.removeLast();
      }
      return false;
    }

    return search(0, fullMask);
  }

  @override
  void start() {
    _over = false;
    winner = -1;
    turn = 0;
    phase = 'turn';
    lastAction = null;

    var ok = false;
    for (var attempt = 0; attempt < 10; attempt++) {
      _buildMapAndCluePool();
      if (_selectPlayerClues()) {
        ok = true;
        break;
      }
    }
    assert(ok, 'Failed to select valid Cryptid clues');

    cubes = List<int?>.filled(numHexes, null);
    discs = List.generate(numHexes, (_) => <int>[]);

    // Each player starts by placing 2 Cube markers (■ = No) on hexes that do NOT match their clue
    for (var round = 0; round < 2; round++) {
      for (var s = 0; s < players; s++) {
        final nonMatching = [
          for (var h = 0; h < numHexes; h++)
            if (!playerClues[s].matchingHexes.contains(h) && cubes[h] == null) h,
        ];
        if (nonMatching.isNotEmpty) {
          final pick = nonMatching[rng.nextInt(nonMatching.length)];
          cubes[pick] = s;
        }
      }
    }

    lastEvent = '诡影寻踪开始！每位玩家已放置 2 枚初始排除方块（■）。轮到 ${name(0)} 行动。';
    host.log(lastEvent);
  }

  bool _hasValidPenaltyHex(int seat) {
    for (var h = 0; h < numHexes; h++) {
      if (cubes[h] == null && !playerClues[seat].matchingHexes.contains(h)) {
        return true;
      }
    }
    return false;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('当前未轮到你行动');

    final type = asStr(action['type']);

    if (phase == 'turn') {
      if (type == 'question') {
        final targetSeat = asInt(action['target']);
        final hex = asInt(action['hex']);
        if (targetSeat < 0 || targetSeat >= players || targetSeat == seat) {
          throw GameError('必须选择另一名玩家进行询问');
        }
        if (hex < 0 || hex >= numHexes) {
          throw GameError('无效的地图格编号');
        }
        if (cubes[hex] != null) {
          throw GameError('该格已有排除方块（■），不能询问');
        }

        final matches = playerClues[targetSeat].matchingHexes.contains(hex);
        lastAction = {
          'type': 'question',
          'seat': seat,
          'target': targetSeat,
          'hex': hex,
          'result': matches ? 'disc' : 'cube',
        };

        if (matches) {
          if (!discs[hex].contains(targetSeat)) {
            discs[hex].add(targetSeat);
          }
          lastEvent = '${name(seat)} 询问 ${name(targetSeat)} 格 #$hex：符合线索（放置圆盘 ◯）！';
          host.log(lastEvent);
          turn = (turn + 1) % players;
        } else {
          cubes[hex] = targetSeat;
          if (_hasValidPenaltyHex(seat)) {
            phase = 'penalty_cube';
            lastEvent =
                '${name(seat)} 询问 ${name(targetSeat)} 格 #$hex：不符合（放置方块 ■）！请 ${name(seat)} 放置 1 枚惩罚方块。';
          } else {
            turn = (turn + 1) % players;
            lastEvent = '${name(seat)} 询问 ${name(targetSeat)} 格 #$hex：不符合（放置方块 ■）！';
          }
          host.log(lastEvent);
        }
        return;
      }

      if (type == 'search') {
        final hex = asInt(action['hex']);
        if (hex < 0 || hex >= numHexes) {
          throw GameError('无效的地图格编号');
        }
        if (cubes[hex] != null) {
          throw GameError('该格已有排除方块（■），不能搜索');
        }
        if (!playerClues[seat].matchingHexes.contains(hex)) {
          throw GameError('只能在符合你自己线索的格子上发起搜索');
        }

        if (!discs[hex].contains(seat)) {
          discs[hex].add(seat);
        }

        int? refuter;
        for (var i = 1; i < players; i++) {
          final other = (seat + i) % players;
          if (playerClues[other].matchingHexes.contains(hex)) {
            if (!discs[hex].contains(other)) {
              discs[hex].add(other);
            }
          } else {
            cubes[hex] = other;
            refuter = other;
            break;
          }
        }

        if (refuter == null) {
          winner = seat;
          _over = true;
          phase = 'over';
          lastAction = {
            'type': 'search',
            'seat': seat,
            'hex': hex,
            'result': 'win',
          };
          lastEvent = '${name(seat)} 搜索格 #$hex，所有玩家线索全部吻合！成功发现神秘生物获胜！';
          host.log(lastEvent);
        } else {
          lastAction = {
            'type': 'search',
            'seat': seat,
            'hex': hex,
            'refuter': refuter,
            'result': 'cube',
          };
          if (_hasValidPenaltyHex(seat)) {
            phase = 'penalty_cube';
            lastEvent = '${name(seat)} 搜索格 #$hex，被 ${name(refuter)} 放置方块（■）否决！请放置 1 枚惩罚方块。';
          } else {
            turn = (turn + 1) % players;
            lastEvent = '${name(seat)} 搜索格 #$hex，被 ${name(refuter)} 放置方块（■）否决！';
          }
          host.log(lastEvent);
        }
        return;
      }

      throw GameError('未知行动类型');
    }

    if (phase == 'penalty_cube') {
      if (type != 'place_cube') {
        throw GameError('当前必须放置惩罚排除方块 (place_cube)');
      }
      final hex = asInt(action['hex']);
      if (hex < 0 || hex >= numHexes) {
        throw GameError('无效的地图格编号');
      }
      if (cubes[hex] != null) {
        throw GameError('该格已有排除方块（■）');
      }
      if (playerClues[seat].matchingHexes.contains(hex)) {
        throw GameError('排除方块只能放在不符合你自己线索的格子上');
      }

      cubes[hex] = seat;
      lastEvent = '${name(seat)} 在格 #$hex 放置了排除方块（■）。';
      host.log(lastEvent);
      phase = 'turn';
      turn = (turn + 1) % players;
      return;
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    final myHexes = playerClues[seat].matchingHexes;

    if (phase == 'penalty_cube') {
      final valid = [
        for (var h = 0; h < numHexes; h++)
          if (cubes[h] == null && !myHexes.contains(h)) h,
      ];
      if (valid.isEmpty) return null;
      return {
        'type': 'place_cube',
        'hex': valid[rng.nextInt(valid.length)],
      };
    }

    // phase == 'turn':
    // Only use seat's own clue + public board markers (cubes & discs) + public cluePool!
    final possibleTargets = [
      for (final h in myHexes)
        if (cubes[h] == null) h,
    ]..sort();

    if (possibleTargets.isEmpty) {
      // Fallback question if somehow all own hexes had cubes
      final unCubed = [
        for (var h = 0; h < numHexes; h++)
          if (cubes[h] == null) h,
      ];
      return {
        'type': 'question',
        'target': (seat + 1) % players,
        'hex': unCubed.first,
      };
    }

    // For each other player p, filter cluePool to clues consistent with p's public cubes and discs
    final consistentClues = <int, List<CryptidClue>>{};
    for (var p = 0; p < players; p++) {
      if (p == seat) continue;
      final pCubes = [
        for (var h = 0; h < numHexes; h++)
          if (cubes[h] == p) h,
      ];
      final pDiscs = [
        for (var h = 0; h < numHexes; h++)
          if (discs[h].contains(p)) h,
      ];
      final list = <CryptidClue>[];
      for (final c in cluePool) {
        var ok = true;
        for (final ch in pCubes) {
          if (c.matchingHexes.contains(ch)) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
        for (final dh in pDiscs) {
          if (!c.matchingHexes.contains(dh)) {
            ok = false;
            break;
          }
        }
        if (ok) list.add(c);
      }
      consistentClues[p] = list.isEmpty ? cluePool : list;
    }

    // Score each candidate hex in possibleTargets by likelihood of matching all other players
    var bestHex = possibleTargets.first;
    var bestLikelihood = -1.0;
    for (final h in possibleTargets) {
      var score = 1.0 + discs[h].length * 0.5;
      for (var p = 0; p < players; p++) {
        if (p == seat) continue;
        if (discs[h].contains(p)) {
          score *= 2.0;
        } else {
          final list = consistentClues[p]!;
          final matchCnt = list.where((c) => c.matchingHexes.contains(h)).length;
          score *= (matchCnt + 0.1) / (list.length + 0.1);
        }
      }
      if (score > bestLikelihood) {
        bestLikelihood = score;
        bestHex = h;
      }
    }

    // Decide between search (directly tests bestHex and either wins or eliminates it)
    // and question (asks a specific player about bestHex).
    if (botLevel == 0 && possibleTargets.length > 3 && rng.nextDouble() < 0.5) {
      final targetPlayer = (seat + 1 + rng.nextInt(players - 1)) % players;
      final qHex = possibleTargets[rng.nextInt(possibleTargets.length)];
      return {
        'type': 'question',
        'target': targetPlayer,
        'hex': qHex,
      };
    }

    if (possibleTargets.length <= 4 || discs[bestHex].isNotEmpty || rng.nextDouble() < 0.65) {
      return {
        'type': 'search',
        'hex': bestHex,
      };
    }

    // Otherwise question a player who hasn't placed a disc on bestHex yet
    var askSeat = (seat + 1) % players;
    for (var i = 1; i < players; i++) {
      final p = (seat + i) % players;
      if (!discs[bestHex].contains(p)) {
        askSeat = p;
        break;
      }
    }
    return {
      'type': 'question',
      'target': askSeat,
      'hex': bestHex,
    };
  }

  @override
  Map<String, dynamic> view(int seat) {
    final hasSeat = seat >= 0 && seat < players;
    final myClue = hasSeat ? playerClues[seat] : null;
    return {
      'cols': cols,
      'rows': rows,
      'cells': [for (final c in cells) c.toJson()],
      'cubes': List<int?>.of(cubes),
      'discs': [for (final d in discs) List<int>.of(d)],
      'turn': turn,
      'phase': phase,
      'winner': winner,
      'myClue': myClue?.text,
      'myMatchingHexes': myClue != null ? (myClue.matchingHexes.toList()..sort()) : const <int>[],
      'cluePoolTexts': [for (final c in cluePool) c.text],
      if (_over) ...{
        'targetHex': targetHex,
        'allClues': [for (final c in playerClues) c.toJson()],
        'placings': placings,
      },
      'lastAction': lastAction,
      'lastEvent': lastEvent,
      'waitingFor': waitingFor,
      'over': _over,
    };
  }
}
