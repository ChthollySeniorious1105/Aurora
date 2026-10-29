import 'dart:math';

import '../../src/engine.dart';

const List<String> akropolisTypeNames = [
  '采石场',
  '住宅',
  '市场',
  '兵营',
  '神庙',
  '花园',
];

const List<String> akropolisTypeEmojis = [
  '⬜',
  '🟦',
  '🟨',
  '🟥',
  '🟪',
  '🟩',
];

class AkropolisCell {
  final int type; // 0: Quarry, 1: Housing, 2: Market, 3: Barracks, 4: Temple, 5: Garden
  final bool isPlaza;
  final int stars; // 0 for Districts/Quarry, 1..3 for Plazas

  const AkropolisCell({
    required this.type,
    this.isPlaza = false,
    this.stars = 0,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'isPlaza': isPlaza,
        'stars': stars,
      };
}

class AkropolisTile {
  final int id;
  final List<AkropolisCell> cells; // length 3

  const AkropolisTile({
    required this.id,
    required this.cells,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'cells': [for (final c in cells) c.toJson()],
      };
}

class AkropolisGame extends GameEngine {
  static const int gridSize = 7;

  late final int maxRounds;
  late List<List<List<int>>> height;
  late List<List<List<int>>> topType;
  late List<List<List<bool>>> topIsPlaza;
  late List<List<List<int>>> topStars;
  late List<int> stones;
  late List<int> score;

  final List<AkropolisTile> deck = [];
  final List<AkropolisTile> market = [];

  int round = 1;
  int turn = 0;
  bool over = false;
  String lastAction = '雅典卫城筑城开始';

  AkropolisGame(super.setup) : maxRounds = setup.opt<int>('rounds', 9);

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(score) : null;

  static List<(int, int)> hexNeighbors(int r, int c) {
    const dirs = [
      (-1, 0),
      (1, 0),
      (0, -1),
      (0, 1),
      (-1, 1),
      (1, -1),
    ];
    return [
      for (final (dr, dc) in dirs)
        if (r + dr >= 0 &&
            r + dr < gridSize &&
            c + dc >= 0 &&
            c + dc < gridSize)
          (r + dr, c + dc),
    ];
  }

  static bool areHexAdjacent((int, int) a, (int, int) b) {
    final dr = b.$1 - a.$1;
    final dc = b.$2 - a.$2;
    return (dr == -1 && dc == 0) ||
        (dr == 1 && dc == 0) ||
        (dr == 0 && dc == -1) ||
        (dr == 0 && dc == 1) ||
        (dr == -1 && dc == 1) ||
        (dr == 1 && dc == -1);
  }

  static bool isConnectedTriHex(List<(int, int)> cells) {
    if (cells.length != 3) return false;
    final a = cells[0], b = cells[1], c = cells[2];
    if (a == b || b == c || a == c) return false;
    for (final (r, col) in cells) {
      if (r < 0 || r >= gridSize || col < 0 || col >= gridSize) return false;
    }
    final ab = areHexAdjacent(a, b);
    final bc = areHexAdjacent(b, c);
    final ac = areHexAdjacent(a, c);
    final edges = (ab ? 1 : 0) + (bc ? 1 : 0) + (ac ? 1 : 0);
    return edges >= 2;
  }

  List<AkropolisTile> _buildDeck() {
    final raw = <AkropolisTile>[];
    var id = 1;
    const starsByColor = [0, 1, 2, 2, 2, 3];
    // Generate balanced tri-hex tiles with Quarries, Districts, and Plazas
    for (var copy = 0; copy < 2; copy++) {
      for (var c1 = 1; c1 <= 5; c1++) {
        final c2 = (c1 % 5) + 1;
        final c3 = ((c1 + 1) % 5) + 1;
        // Tile with Plaza + Quarry + District
        raw.add(AkropolisTile(
          id: id++,
          cells: [
            const AkropolisCell(type: 0),
            AkropolisCell(type: c1, isPlaza: true, stars: starsByColor[c1]),
            AkropolisCell(type: c2),
          ],
        ));
        // Tile with 2 Quarries + Plaza
        raw.add(AkropolisTile(
          id: id++,
          cells: [
            const AkropolisCell(type: 0),
            const AkropolisCell(type: 0),
            AkropolisCell(type: c2, isPlaza: true, stars: starsByColor[c2]),
          ],
        ));
        // Tile with Quarry + 2 Districts
        raw.add(AkropolisTile(
          id: id++,
          cells: [
            const AkropolisCell(type: 0),
            AkropolisCell(type: c1),
            AkropolisCell(type: c3),
          ],
        ));
        // Tile with 3 Districts
        raw.add(AkropolisTile(
          id: id++,
          cells: [
            AkropolisCell(type: c1),
            AkropolisCell(type: c2),
            AkropolisCell(type: c3),
          ],
        ));
      }
    }
    return shuffled(raw, rng);
  }

  @override
  void start() {
    height = List.generate(
      players,
      (_) => List.generate(gridSize, (_) => List.filled(gridSize, 0)),
    );
    topType = List.generate(
      players,
      (_) => List.generate(gridSize, (_) => List.filled(gridSize, -1)),
    );
    topIsPlaza = List.generate(
      players,
      (_) => List.generate(gridSize, (_) => List.filled(gridSize, false)),
    );
    topStars = List.generate(
      players,
      (_) => List.generate(gridSize, (_) => List.filled(gridSize, 0)),
    );
    stones = [for (var s = 0; s < players; s++) s + 1];
    score = List.filled(players, 0);

    // Starting 4-hex foundation at center (3,3) Blue Plaza + 3 Quarries at (3,2),(2,3),(4,3)
    for (var s = 0; s < players; s++) {
      _setCell(s, 3, 3, 1, const AkropolisCell(type: 1, isPlaza: true, stars: 1));
      _setCell(s, 3, 2, 1, const AkropolisCell(type: 0));
      _setCell(s, 2, 3, 1, const AkropolisCell(type: 0));
      _setCell(s, 4, 3, 1, const AkropolisCell(type: 0));
      score[s] = calcScore(s);
    }

    deck
      ..clear()
      ..addAll(_buildDeck());
    market.clear();
    _refillMarket();
  }

  void _setCell(int seat, int r, int c, int h, AkropolisCell cell) {
    height[seat][r][c] = h;
    topType[seat][r][c] = cell.type;
    topIsPlaza[seat][r][c] = cell.isPlaza;
    topStars[seat][r][c] = cell.stars;
  }

  int get targetMarketSize => players + 2;

  void _refillMarket() {
    while (market.length < targetMarketSize && deck.isNotEmpty) {
      market.add(deck.removeLast());
    }
  }

  bool canPlaceCells(int seat, List<(int, int)> cells) {
    if (!isConnectedTriHex(cells)) return false;
    final h0 = height[seat][cells[0].$1][cells[0].$2];
    for (final (r, c) in cells) {
      if (height[seat][r][c] != h0) return false;
    }
    if (h0 == 0) {
      // Must be adjacent to at least 1 existing city cell
      var touchesCity = false;
      for (final (r, c) in cells) {
        for (final (nr, nc) in hexNeighbors(r, c)) {
          if (height[seat][nr][nc] > 0) {
            touchesCity = true;
            break;
          }
        }
        if (touchesCity) break;
      }
      return touchesCity;
    }
    // h0 >= 1: stacking on Level (h0 + 1) >= 2 covering 3 connected cells of height h0
    return true;
  }

  List<List<(int, int)>> validTriHexPlacements(int seat) {
    final results = <List<(int, int)>>[];
    final seen = <String>{};
    // Candidate triangles and connected triples
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        final h = height[seat][r][c];
        final nbs = [
          for (final (nr, nc) in hexNeighbors(r, c))
            if (height[seat][nr][nc] == h) (nr, nc),
        ];
        for (var i = 0; i < nbs.length; i++) {
          for (var j = i + 1; j < nbs.length; j++) {
            final triple = [(r, c), nbs[i], nbs[j]];
            if (!canPlaceCells(seat, triple)) continue;
            final sorted = List.of(triple)
              ..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
            final key = '${sorted[0].$1},${sorted[0].$2};${sorted[1].$1},${sorted[1].$2};${sorted[2].$1},${sorted[2].$2}';
            if (seen.add(key)) {
              results.add(triple);
            }
          }
        }
      }
    }
    return results;
  }

  int calcColorPlazaStars(int seat, int color) {
    var total = 0;
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        if (height[seat][r][c] > 0 &&
            topType[seat][r][c] == color &&
            topIsPlaza[seat][r][c]) {
          total += topStars[seat][r][c];
        }
      }
    }
    return total;
  }

  int calcColorDistrictSum(int seat, int color) {
    switch (color) {
      case 1: // 🟦 Housing: largest contiguous group of Blue Districts (sum of heights)
        final visited = List.generate(gridSize, (_) => List.filled(gridSize, false));
        var bestSum = 0;
        for (var r = 0; r < gridSize; r++) {
          for (var c = 0; c < gridSize; c++) {
            if (visited[r][c]) continue;
            if (height[seat][r][c] <= 0 ||
                topType[seat][r][c] != 1 ||
                topIsPlaza[seat][r][c]) {
              continue;
            }
            var compSum = 0;
            final q = <(int, int)>[(r, c)];
            visited[r][c] = true;
            while (q.isNotEmpty) {
              final (cr, cc) = q.removeLast();
              compSum += height[seat][cr][cc];
              for (final (nr, nc) in hexNeighbors(cr, cc)) {
                if (!visited[nr][nc] &&
                    height[seat][nr][nc] > 0 &&
                    topType[seat][nr][nc] == 1 &&
                    !topIsPlaza[seat][nr][nc]) {
                  visited[nr][nc] = true;
                  q.add((nr, nc));
                }
              }
            }
            if (compSum > bestSum) bestSum = compSum;
          }
        }
        return bestSum;

      case 2: // 🟨 Market: Yellow Districts with 0 adjacent Yellow Districts
        var sum = 0;
        for (var r = 0; r < gridSize; r++) {
          for (var c = 0; c < gridSize; c++) {
            if (height[seat][r][c] <= 0 ||
                topType[seat][r][c] != 2 ||
                topIsPlaza[seat][r][c]) {
              continue;
            }
            var adjYellowDistrict = false;
            for (final (nr, nc) in hexNeighbors(r, c)) {
              if (height[seat][nr][nc] > 0 &&
                  topType[seat][nr][nc] == 2 &&
                  !topIsPlaza[seat][nr][nc]) {
                adjYellowDistrict = true;
                break;
              }
            }
            if (!adjYellowDistrict) {
              sum += height[seat][r][c];
            }
          }
        }
        return sum;

      case 3: // 🟥 Barracks: Red Districts on the outer perimeter (at least 1 empty adjacent cell or edge)
        var sum = 0;
        for (var r = 0; r < gridSize; r++) {
          for (var c = 0; c < gridSize; c++) {
            if (height[seat][r][c] <= 0 ||
                topType[seat][r][c] != 3 ||
                topIsPlaza[seat][r][c]) {
              continue;
            }
            final nbs = hexNeighbors(r, c);
            var onPerimeter = nbs.length < 6;
            if (!onPerimeter) {
              for (final (nr, nc) in nbs) {
                if (height[seat][nr][nc] == 0) {
                  onPerimeter = true;
                  break;
                }
              }
            }
            if (onPerimeter) {
              sum += height[seat][r][c];
            }
          }
        }
        return sum;

      case 4: // 🟪 Temple: Purple Districts completely surrounded (0 empty adjacent cells, all 6 neighbors occupied)
        var sum = 0;
        for (var r = 0; r < gridSize; r++) {
          for (var c = 0; c < gridSize; c++) {
            if (height[seat][r][c] <= 0 ||
                topType[seat][r][c] != 4 ||
                topIsPlaza[seat][r][c]) {
              continue;
            }
            final nbs = hexNeighbors(r, c);
            if (nbs.length < 6) continue;
            var surrounded = true;
            for (final (nr, nc) in nbs) {
              if (height[seat][nr][nc] == 0) {
                surrounded = false;
                break;
              }
            }
            if (surrounded) {
              sum += height[seat][r][c];
            }
          }
        }
        return sum;

      case 5: // 🟩 Garden: ALL Green Districts
        var sum = 0;
        for (var r = 0; r < gridSize; r++) {
          for (var c = 0; c < gridSize; c++) {
            if (height[seat][r][c] > 0 &&
                topType[seat][r][c] == 5 &&
                !topIsPlaza[seat][r][c]) {
              sum += height[seat][r][c];
            }
          }
        }
        return sum;

      default:
        return 0;
    }
  }

  int calcScore(int seat) {
    var total = stones[seat];
    for (var color = 1; color <= 5; color++) {
      total += calcColorPlazaStars(seat, color) * calcColorDistrictSum(seat, color);
    }
    return total;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('尚未轮到你行动');

    final type = asStr(action['type']);
    if (type != 'build') throw GameError('未知操作');

    final slot = asInt(action['slot'], -1);
    if (slot < 0 || slot >= market.length) {
      throw GameError('无效的工地板块编号');
    }
    if (stones[seat] < slot) {
      throw GameError('石材不足，需要 $slot 枚石材');
    }

    final rawCells = action['cells'];
    if (rawCells is! List || rawCells.length != 3) {
      throw GameError('必须指定 3 个相邻六角格进行拼放');
    }
    final cells = <(int, int)>[];
    for (final item in rawCells) {
      if (item is! List || item.length < 2) {
        throw GameError('坐标格式错误');
      }
      cells.add((asInt(item[0], -1), asInt(item[1], -1)));
    }

    if (!canPlaceCells(seat, cells)) {
      throw GameError('不满足雅典卫城拼放或叠层规则');
    }

    final tile = market.removeAt(slot);
    stones[seat] -= slot;

    final baseHeight = height[seat][cells[0].$1][cells[0].$2];
    final newHeight = baseHeight + 1;
    var quarriesCovered = 0;
    if (baseHeight >= 1) {
      for (final (r, c) in cells) {
        if (topType[seat][r][c] == 0) {
          quarriesCovered++;
        }
      }
      stones[seat] += quarriesCovered;
    }

    for (var i = 0; i < 3; i++) {
      final (r, c) = cells[i];
      _setCell(seat, r, c, newHeight, tile.cells[i]);
    }

    score[seat] = calcScore(seat);
    lastAction =
        '${name(seat)} 选用工地 #${slot + 1} 筑于 ${newHeight}层${quarriesCovered > 0 ? ' (覆盖采石场 +$quarriesCovered⬜)' : ''}';
    host.log(lastAction);

    _advanceTurn();
  }

  void _advanceTurn() {
    if (market.length <= 1) {
      _refillMarket();
    }
    final nextSeat = (turn + 1) % players;
    if (nextSeat == 0) {
      if (round >= maxRounds || (market.isEmpty && deck.isEmpty)) {
        over = true;
        for (var s = 0; s < players; s++) {
          score[s] = calcScore(s);
        }
        lastAction = '雅典卫城竣工！最高总分获胜';
        host.log(lastAction);
        return;
      }
      round++;
      _refillMarket();
    }
    turn = nextSeat;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    final placements = validTriHexPlacements(seat);
    if (placements.isEmpty || market.isEmpty) return null;

    final maxSlot = min(market.length - 1, stones[seat]);
    if (botLevel == 0) {
      final chosen = placements[rng.nextInt(placements.length)];
      return {
        'type': 'build',
        'slot': 0,
        'cells': [
          for (final (r, c) in chosen) [r, c],
        ],
      };
    }

    var bestVal = -999999;
    var bestSlot = 0;
    List<(int, int)> bestCells = placements.first;

    final sampleLimit = min(placements.length, botLevel >= 2 ? 24 : 12);
    for (var s = 0; s <= maxSlot; s++) {
      final tile = market[s];
      for (var i = 0; i < sampleLimit; i++) {
        final cells = placements[i];
        final baseH = height[seat][cells[0].$1][cells[0].$2];
        // Backup
        final oldH = [for (final (r, c) in cells) height[seat][r][c]];
        final oldT = [for (final (r, c) in cells) topType[seat][r][c]];
        final oldP = [for (final (r, c) in cells) topIsPlaza[seat][r][c]];
        final oldS = [for (final (r, c) in cells) topStars[seat][r][c]];
        final oldStones = stones[seat];

        stones[seat] -= s;
        if (baseH >= 1) {
          for (final (r, c) in cells) {
            if (topType[seat][r][c] == 0) stones[seat]++;
          }
        }
        for (var k = 0; k < 3; k++) {
          _setCell(seat, cells[k].$1, cells[k].$2, baseH + 1, tile.cells[k]);
        }
        final val = calcScore(seat) * 10 + stones[seat] * 3 + baseH * 4;

        // Restore
        stones[seat] = oldStones;
        for (var k = 0; k < 3; k++) {
          final (r, c) = cells[k];
          height[seat][r][c] = oldH[k];
          topType[seat][r][c] = oldT[k];
          topIsPlaza[seat][r][c] = oldP[k];
          topStars[seat][r][c] = oldS[k];
        }

        if (val > bestVal) {
          bestVal = val;
          bestSlot = s;
          bestCells = cells;
        }
      }
    }

    return {
      'type': 'build',
      'slot': bestSlot,
      'cells': [
        for (final (r, c) in bestCells) [r, c],
      ],
    };
  }

  @override
  Map<String, dynamic> view(int seat) {
    final validList = (!over && seat >= 0 && seat < players)
        ? validTriHexPlacements(seat)
        : const <List<(int, int)>>[];
    return {
      'gridSize': gridSize,
      'round': round,
      'maxRounds': maxRounds,
      'turn': turn,
      'over': over,
      'deckCount': deck.length,
      'lastAction': lastAction,
      'market': [for (final t in market) t.toJson()],
      'validTriples': [
        for (final triple in validList.take(30))
          [
            for (final (r, c) in triple) [r, c],
          ],
      ],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'stones': stones[s],
            'score': score[s],
            'height': [
              for (var r = 0; r < gridSize; r++) List<int>.of(height[s][r]),
            ],
            'topType': [
              for (var r = 0; r < gridSize; r++) List<int>.of(topType[s][r]),
            ],
            'topIsPlaza': [
              for (var r = 0; r < gridSize; r++) List<bool>.of(topIsPlaza[s][r]),
            ],
            'topStars': [
              for (var r = 0; r < gridSize; r++) List<int>.of(topStars[s][r]),
            ],
            'colorBreakdown': [
              for (var c = 1; c <= 5; c++)
                {
                  'color': c,
                  'stars': calcColorPlazaStars(s, c),
                  'heights': calcColorDistrictSum(s, c),
                  'vp': calcColorPlazaStars(s, c) * calcColorDistrictSum(s, c),
                },
            ],
          },
      ],
    };
  }
}
