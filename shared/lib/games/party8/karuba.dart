import '../../src/engine.dart';

class KarubaGame extends GameEngine {
  KarubaGame(super.setup);

  static const List<String> colorNames = ['蓝', '黄', '棕', '紫'];

  /// Beach start coordinates outside the 6x6 grid for adventurers 0..3.
  static const List<(int, int)> startCoords = [
    (1, -1), // 0: 蓝 (West beach row 1 -> enters (1,0))
    (4, -1), // 1: 黄 (West beach row 4 -> enters (4,0))
    (6, 1),  // 2: 棕 (South beach col 1 -> enters (5,1))
    (6, 4),  // 3: 紫 (South beach col 4 -> enters (5,4))
  ];

  /// First grid cell adjacent to each adventurer's beach start.
  static const List<(int, int)> entryCells = [
    (1, 0),
    (4, 0),
    (5, 1),
    (5, 4),
  ];

  /// Grid cell adjacent to each temple.
  static const List<(int, int)> templeEntryCells = [
    (0, 4), // 0: 蓝 (North edge col 4)
    (1, 5), // 1: 黄 (East edge row 1)
    (0, 2), // 2: 棕 (North edge col 2)
    (4, 5), // 3: 紫 (East edge row 4)
  ];

  /// Temple virtual coordinates outside the 6x6 grid for temples 0..3.
  static const List<(int, int)> templeCoords = [
    (-1, 4), // 0: 蓝
    (1, 6),  // 1: 黄
    (-1, 2), // 2: 棕
    (4, 6),  // 3: 紫
  ];

  static const List<int> dr = [-1, 0, 1, 0]; // N, E, S, W
  static const List<int> dc = [0, 1, 0, -1];

  static const List<List<int>> _shapes = [
    [0, 2],       // NS
    [1, 3],       // EW
    [0, 1],       // NE
    [1, 2],       // ES
    [2, 3],       // SW
    [0, 3],       // WN
    [0, 1, 2],    // NES
    [1, 2, 3],    // ESW
    [0, 2, 3],    // SWN
    [0, 1, 3],    // WNE
    [0, 1, 2, 3], // NESW
    [0, 1, 2, 3], // NESW
  ];

  static List<int> tileDirs(int tileId) =>
      _shapes[(tileId - 1).clamp(0, 35) % _shapes.length];

  static bool hasGold(int tileId) => tileId % 5 == 0;
  static bool hasCrystal(int tileId) => tileId % 5 != 0 && tileId % 3 == 0;

  late final int maxTiles = setup.opt<int>('tiles', 36);

  late List<int> tileDeck;
  int round = 0;
  int currentTile = 1;
  bool over = false;

  /// grids[seat][r][c] is null or {'id': int, 'dirs': List<int>, 'gold': bool, 'crystal': bool}
  late List<List<List<Map<String, dynamic>?>>> grids;
  late List<List<int>> advR;
  late List<List<int>> advC;
  late List<List<bool>> inTemple;
  late List<List<int>> templeClaimed;
  late List<int> goldCount;
  late List<int> crystalCount;
  late List<int> scores;
  late List<bool> acted;
  late List<String> lastActions;
  late List<List<int>> templeTreasures;
  final List<List<int>> _pendingTempleClaims = [[], [], [], []];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? rankByScore(scores) : null;

  @override
  List<int> get waitingFor {
    if (over) return const [];
    return [
      for (var s = 0; s < players; s++)
        if (!acted[s]) s,
    ];
  }

  @override
  void start() {
    tileDeck =
        shuffled([for (var i = 1; i <= 36; i++) i], rng).take(maxTiles).toList();
    round = 0;
    currentTile = tileDeck[0];
    over = false;

    grids = [
      for (var s = 0; s < players; s++)
        [for (var r = 0; r < 6; r++) List<Map<String, dynamic>?>.filled(6, null)],
    ];
    advR = [
      for (var s = 0; s < players; s++) [for (var a = 0; a < 4; a++) startCoords[a].$1],
    ];
    advC = [
      for (var s = 0; s < players; s++) [for (var a = 0; a < 4; a++) startCoords[a].$2],
    ];
    inTemple = [
      for (var s = 0; s < players; s++) List<bool>.filled(4, false),
    ];
    templeClaimed = [
      for (var s = 0; s < players; s++) List<int>.filled(4, 0),
    ];
    goldCount = List<int>.filled(players, 0);
    crystalCount = List<int>.filled(players, 0);
    scores = List<int>.filled(players, 0);
    acted = List<bool>.filled(players, false);
    lastActions = List<String>.filled(players, '');
    templeTreasures = [
      for (var a = 0; a < 4; a++) [5, 4, 3, 2],
    ];
    for (final l in _pendingTempleClaims) {
      l.clear();
    }
    host.log('卡鲁巴寻宝开始！第 1 块丛林板块：#$currentTile');
  }

  bool _occupiedByOtherAdv(int seat, int r, int c, int exceptAdv) {
    for (var a = 0; a < 4; a++) {
      if (a == exceptAdv || inTemple[seat][a]) continue;
      if (advR[seat][a] == r && advC[seat][a] == c) return true;
    }
    return false;
  }

  /// Returns all reachable target coordinates for adventurer [adv] of [seat]
  /// within [maxSteps] steps along connected jungle tiles.
  List<Map<String, dynamic>> legalMovesFor(int seat, int adv, int maxSteps) {
    if (adv < 0 || adv >= 4 || inTemple[seat][adv] || maxSteps <= 0) {
      return const [];
    }
    final sr = advR[seat][adv];
    final sc = advC[seat][adv];
    final visited = <(int, int), int>{(sr, sc): 0};
    final queue = <(int, int)>[(sr, sc)];
    final results = <Map<String, dynamic>>[];

    var head = 0;
    while (head < queue.length) {
      final (cr, cc) = queue[head++];
      final dist = visited[(cr, cc)]!;
      if (dist >= maxSteps) continue;

      if (cr < 0 || cr >= 6 || cc < 0 || cc >= 6) {
        // Currently on the beach start: can step onto entryCells[adv] if a tile is placed there
        final (er, ec) = entryCells[adv];
        if (grids[seat][er][ec] != null &&
            !_occupiedByOtherAdv(seat, er, ec, adv) &&
            !visited.containsKey((er, ec))) {
          visited[(er, ec)] = dist + 1;
          queue.add((er, ec));
          results.add({
            'r': er,
            'c': ec,
            'steps': dist + 1,
            'temple': false,
          });
        }
        continue;
      }

      final cell = grids[seat][cr][cc];
      if (cell == null) continue;
      final dirs = (cell['dirs'] as List).cast<int>();

      // Check if standing on the entry cell of matching temple
      final (ter, tec) = templeEntryCells[adv];
      final (tr, tc) = templeCoords[adv];
      if (cr == ter && cc == tec && !visited.containsKey((tr, tc))) {
        visited[(tr, tc)] = dist + 1;
        results.add({
          'r': tr,
          'c': tc,
          'steps': dist + 1,
          'temple': true,
        });
      }

      // Traverse connected adjacent grid cells
      for (final d in dirs) {
        final nr = cr + dr[d];
        final nc = cc + dc[d];
        if (nr < 0 || nr >= 6 || nc < 0 || nc >= 6) continue;
        final nextCell = grids[seat][nr][nc];
        if (nextCell == null) continue;
        final nextDirs = (nextCell['dirs'] as List).cast<int>();
        final opp = (d + 2) % 4;
        if (!nextDirs.contains(opp)) continue;
        if (_occupiedByOtherAdv(seat, nr, nc, adv)) continue;
        if (visited.containsKey((nr, nc))) continue;
        visited[(nr, nc)] = dist + 1;
        queue.add((nr, nc));
        results.add({
          'r': nr,
          'c': nc,
          'steps': dist + 1,
          'temple': false,
        });
      }
    }
    return results;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat < 0 || seat >= players || acted[seat]) {
      throw GameError('当前无需操作');
    }

    final type = asStr(action['type']);
    if (type == 'place') {
      final r = asInt(action['r']);
      final c = asInt(action['c']);
      if (r < 0 || r >= 6 || c < 0 || c >= 6) {
        throw GameError('板块坐标超出 6×6 丛林范围');
      }
      if (grids[seat][r][c] != null) {
        throw GameError('该格子已放置过板块');
      }
      grids[seat][r][c] = {
        'id': currentTile,
        'dirs': List<int>.of(tileDirs(currentTile)),
        'gold': hasGold(currentTile),
        'crystal': hasCrystal(currentTile),
      };
      acted[seat] = true;
      lastActions[seat] = '放置#${currentTile}于(${r + 1},${c + 1})';
    } else if (type == 'move') {
      final adv = asInt(action['adv']);
      final targetR = asInt(action['targetR']);
      final targetC = asInt(action['targetC']);
      if (adv < 0 || adv >= 4 || inTemple[seat][adv]) {
        throw GameError('无效的探险家');
      }
      final maxSteps = tileDirs(currentTile).length;
      final moves = legalMovesFor(seat, adv, maxSteps);
      final match = moves.where((m) => m['r'] == targetR && m['c'] == targetC);
      if (match.isEmpty) {
        throw GameError('探险家无法沿连通小径移动到该目标位置');
      }
      advR[seat][adv] = targetR;
      advC[seat][adv] = targetC;
      final isTemple = match.first['temple'] == true;
      if (isTemple) {
        inTemple[seat][adv] = true;
        final val =
            templeTreasures[adv].isNotEmpty ? templeTreasures[adv].first : 2;
        scores[seat] += val;
        templeClaimed[seat][adv] = val;
        _pendingTempleClaims[adv].add(seat);
        lastActions[seat] = '${colorNames[adv]}色探险家抵达神庙(+${val}分)';
        host.log('${name(seat)} 的${colorNames[adv]}色探险家进入了神庙，获得 $val 分宝藏！');
      } else {
        final cell = grids[seat][targetR][targetC]!;
        var bonusMsg = '';
        if (cell['gold'] == true) {
          cell['gold'] = false;
          scores[seat] += 2;
          goldCount[seat]++;
          bonusMsg = '(拾取金块+2分)';
        } else if (cell['crystal'] == true) {
          cell['crystal'] = false;
          scores[seat] += 1;
          crystalCount[seat]++;
          bonusMsg = '(拾取水晶+1分)';
        }
        lastActions[seat] =
            '移动${colorNames[adv]}色探险家至(${targetR + 1},${targetC + 1})$bonusMsg';
      }
      acted[seat] = true;
    } else {
      throw GameError('未知操作类型');
    }

    if (acted.every((b) => b)) {
      _endRound();
    }
  }

  void _endRound() {
    for (var a = 0; a < 4; a++) {
      final count = _pendingTempleClaims[a].length;
      for (var i = 0; i < count && templeTreasures[a].isNotEmpty; i++) {
        templeTreasures[a].removeAt(0);
      }
      _pendingTempleClaims[a].clear();
    }

    final anyAllTemples = [
      for (var s = 0; s < players; s++) inTemple[s].every((b) => b),
    ].any((b) => b);

    if (anyAllTemples || round + 1 >= tileDeck.length) {
      over = true;
      host.log('卡鲁巴寻宝结束！最终得分：${[
        for (var s = 0; s < players; s++) '${name(s)}:${scores[s]}分'
      ].join('，')}');
      return;
    }

    round++;
    currentTile = tileDeck[round];
    acted = List<bool>.filled(players, false);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || acted[seat]) return null;
    final maxSteps = tileDirs(currentTile).length;

    // 1. Check if any adventurer can enter a temple or collect gold/crystal
    for (var a = 0; a < 4; a++) {
      final moves = legalMovesFor(seat, a, maxSteps);
      for (final m in moves) {
        if (m['temple'] == true) {
          return {
            'type': 'move',
            'adv': a,
            'targetR': m['r'],
            'targetC': m['c'],
          };
        }
      }
      for (final m in moves) {
        final r = m['r'] as int;
        final c = m['c'] as int;
        if (r >= 0 && r < 6 && c >= 0 && c < 6) {
          final cell = grids[seat][r][c];
          if (cell != null &&
              (cell['gold'] == true ||
                  (cell['crystal'] == true && botLevel >= 1))) {
            return {'type': 'move', 'adv': a, 'targetR': r, 'targetC': c};
          }
        }
      }
    }

    // 2. In later rounds, move adventurers closer to their temples if possible
    if (round >= maxTiles ~/ 2) {
      int bestAdv = -1;
      int bestR = 0;
      int bestC = 0;
      int bestGain = 0;
      for (var a = 0; a < 4; a++) {
        if (inTemple[seat][a]) continue;
        final (ter, tec) = templeEntryCells[a];
        final curDist = (advR[seat][a] - ter).abs() + (advC[seat][a] - tec).abs();
        for (final m in legalMovesFor(seat, a, maxSteps)) {
          final mr = m['r'] as int;
          final mc = m['c'] as int;
          final newDist = (mr - ter).abs() + (mc - tec).abs();
          final gain = curDist - newDist;
          if (gain > bestGain) {
            bestGain = gain;
            bestAdv = a;
            bestR = mr;
            bestC = mc;
          }
        }
      }
      if (bestAdv != -1 && bestGain >= 2) {
        return {
          'type': 'move',
          'adv': bestAdv,
          'targetR': bestR,
          'targetC': bestC,
        };
      }
    }

    // 3. Otherwise place currentTile on the best empty grid cell
    final dirs = tileDirs(currentTile);
    int bestR = -1;
    int bestC = -1;
    int bestScore = -999;

    for (var r = 0; r < 6; r++) {
      for (var c = 0; c < 6; c++) {
        if (grids[seat][r][c] != null) continue;
        var sc = 0;
        // Prefer entry cells and temple entry cells first
        for (var a = 0; a < 4; a++) {
          if (entryCells[a] == (r, c) || templeEntryCells[a] == (r, c)) {
            sc += 5;
          }
        }
        // Prefer matching open directions with neighbors
        for (final d in dirs) {
          final nr = r + dr[d];
          final nc = c + dc[d];
          if (nr >= 0 && nr < 6 && nc >= 0 && nc < 6) {
            final nb = grids[seat][nr][nc];
            if (nb != null) {
              final nbDirs = (nb['dirs'] as List).cast<int>();
              if (nbDirs.contains((d + 2) % 4)) {
                sc += 4;
              } else {
                sc -= 1;
              }
            }
          }
        }
        if (sc > bestScore) {
          bestScore = sc;
          bestR = r;
          bestC = c;
        }
      }
    }

    return {'type': 'place', 'r': bestR, 'c': bestC};
  }

  @override
  Map<String, dynamic> view(int seat) {
    final sValid = seat >= 0 && seat < players;
    final maxSteps = tileDirs(currentTile).length;
    return {
      'round': round,
      'maxTiles': maxTiles,
      'currentTile': currentTile,
      'currentDirs': List<int>.of(tileDirs(currentTile)),
      'currentGold': hasGold(currentTile),
      'currentCrystal': hasCrystal(currentTile),
      'maxSteps': maxSteps,
      'phase': over ? 'over' : 'play',
      'acted': List<bool>.of(acted),
      'lastActions': List<String>.of(lastActions),
      'scores': List<int>.of(scores),
      'goldCount': List<int>.of(goldCount),
      'crystalCount': List<int>.of(crystalCount),
      'templeTreasures': [
        for (var a = 0; a < 4; a++) List<int>.of(templeTreasures[a]),
      ],
      'grids': [
        for (var s = 0; s < players; s++)
          [
            for (var r = 0; r < 6; r++)
              [
                for (var c = 0; c < 6; c++)
                  grids[s][r][c] == null
                      ? null
                      : {
                          'id': grids[s][r][c]!['id'],
                          'dirs': List<int>.of(
                              (grids[s][r][c]!['dirs'] as List).cast<int>()),
                          'gold': grids[s][r][c]!['gold'] == true,
                          'crystal': grids[s][r][c]!['crystal'] == true,
                        },
              ],
          ],
      ],
      'advR': [for (var s = 0; s < players; s++) List<int>.of(advR[s])],
      'advC': [for (var s = 0; s < players; s++) List<int>.of(advC[s])],
      'inTemple': [for (var s = 0; s < players; s++) List<bool>.of(inTemple[s])],
      'templeClaimed': [
        for (var s = 0; s < players; s++) List<int>.of(templeClaimed[s]),
      ],
      'legalMoves': sValid
          ? [
              for (var a = 0; a < 4; a++) legalMovesFor(seat, a, maxSteps),
            ]
          : const <List<Map<String, dynamic>>>[],
      'over': over,
      'result': over ? {'scores': scores, 'placings': placings} : null,
    };
  }
}
