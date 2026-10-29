import 'dart:math';

import '../../src/engine.dart';

const List<int> cacaoWaterTrack = [-10, -4, -1, 0, 2, 4, 7, 11, 16];

const Map<String, String> cacaoJungleNames = {
  'plant1': '可可园(1)',
  'plant2': '双倍园(2)',
  'market2': '集市(2金)',
  'market3': '集市(3金)',
  'market4': '集市(4金)',
  'mine1': '金矿(1金)',
  'mine2': '金矿(2金)',
  'water': '水源',
  'temple': '神庙(6/3)',
};

class PlacedWorker {
  final int seat;
  final List<int> edges; // [N, E, S, W] after rotation

  const PlacedWorker({required this.seat, required this.edges});

  Map<String, dynamic> toJson() => {
        'seat': seat,
        'edges': edges,
      };
}

const String cacaoRules = '''
# 可可亚 (Cacao) 规则说明

## 游戏概述
《可可亚》是一款经典的棋盘拼放与工人激活策略桌游，支持 2~4 名玩家。
玩家作为部落首领，通过放置带有不同方向工人数量的**工人板块**，开发丛林并激活相邻的**丛林板块**，采集可可果、在集市售出换金、开采金矿、汲取水源并进驻神庙。

## 棋盘与板块
- 棋盘呈奇偶交错的棋盘格结构：
  - `(行 + 列)` 为**偶数**的格子为**工人格**（只能放置工人板块）。
  - `(行 + 列)` 为**奇数**的格子为**丛林格**（只能放置丛林板块）。
- 初始棋盘上放有 2 块丛林板块：`(0, 1)` 单一可可园 与 `(1, 0)` 集市(2金)，市场翻开 2 块丛林板块。
- 每位玩家拥有个人工人牌库，手牌保持 3 张工人板块（四条边各有 0~3 名工人，可旋转 0°/90°/180°/270°）。

## 回合流程
1. **放置工人板块**：从手牌选择 1 张工人板块（可旋转），放置到任意与场上已有丛林板块正交相邻的空工人格上。
2. **填补丛林板块**：检查棋盘上是否有空的丛林格现在正交相邻 **2 块或以上** 的工人板块。若有（且丛林市场非空），当前玩家从丛林市场选择丛林板块填入该格（若只有唯一选择则自动填入）。
3. **激活相邻边**：
   - 新放置的工人板块四条边若接触已有的丛林板块，按该边工人数 `w` 激活对应丛林板块 `w` 次。
   - 新放置的丛林板块四条边若接触任何玩家已有的工人板块，均为对应工人板块的主人触发激活！
   - 系统会自动先结算可可采集、再结算集市售卖，使当回合采集的可可可立即售出。

## 丛林板块效果
- **可可园 (plant1 / plant2)**：每个工人获得 1 个 / 2 个可可果（每人上限 5 个可可果）。
- **集市 (market2 / market3 / market4)**：每个工人可将 1 个可可果按 2 / 3 / 4 金币售出。
- **金矿 (mine1 / mine2)**：每个工人直接获得 1 / 2 金币。
- **水源 (water)**：每个工人将本方饮水轨向前推进 1 格（轨迹分值：`-10, -4, -1, 0, 2, 4, 7, 11, 16`）。
- **神庙 (temple)**：游戏结束时结算，每座神庙周围相邻工人数最多的玩家获得 +6 金，第二名获得 +3 金（平局平分）。

## 游戏结束与计分
- 当所有玩家手牌中的工人板块全部放置完毕后，游戏结束。
- 总分 = **金币数 + 饮水轨得分 + 神庙奖励分**，最高分者获胜（若平分则剩余可可果多者胜）。
''';

class Cacao extends GameEngine {
  Cacao(super.setup);

  static const List<int> dr = [-1, 0, 1, 0]; // N, E, S, W
  static const List<int> dc = [0, 1, 0, -1];

  final Map<(int, int), PlacedWorker> workerBoard = {};
  final Map<(int, int), String> jungleBoard = {};

  final List<String> jungleDeck = [];
  final List<String> jungleMarket = [];

  late List<List<List<int>>> workerDecks;
  late List<List<List<int>>> hands;

  late List<int> gold;
  late List<int> cacao; // max 5
  late List<int> water; // index into cacaoWaterTrack (0..8)
  late List<int> templeBonus;

  int turn = 0;
  String phase = 'place_worker'; // 'place_worker' or 'place_jungle'
  (int, int)? lastPlacedWorker;
  final List<(int, int)> pendingJungleCells = [];
  final List<(int, int)> newlyPlacedJungles = [];

  bool _over = false;
  String lastAction = '游戏开始';

  @override
  bool get isOver => _over;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  List<int>? get placings {
    if (!_over) return null;
    // Tie-break with remaining cacao using fractional score
    return rankByScore([
      for (var s = 0; s < players; s++) totalScore(s) + cacao[s] * 0.01,
    ]);
  }

  static List<int> rotateEdges(List<int> edges, int rot) {
    final r = rot & 3;
    return [for (var d = 0; d < 4; d++) edges[(d - r) & 3]];
  }

  static List<List<int>> buildPlayerWorkerSet(int players, bool shortMode) {
    final base = <List<int>>[
      [1, 1, 1, 1],
      [1, 1, 1, 1],
      [1, 1, 1, 1],
      [1, 1, 1, 1],
      [2, 1, 0, 1],
      [2, 1, 0, 1],
      [2, 1, 0, 1],
      [2, 0, 1, 1],
      [3, 0, 0, 1],
      [2, 2, 0, 0],
      [3, 1, 0, 0],
    ];
    if (shortMode) {
      return base.sublist(3); // 8 tiles per player
    }
    if (players == 3) {
      return base.sublist(1); // 10 tiles
    }
    if (players >= 4) {
      return [
        ...base.sublist(1, 4),
        ...base.sublist(5),
      ]; // 9 tiles
    }
    return base; // 11 tiles for 2 players
  }

  static List<String> buildJungleDeck(int players) {
    final deck = <String>[
      for (var i = 0; i < 5; i++) 'plant1',
      'plant2',
      'plant2',
      'market2',
      for (var i = 0; i < 4; i++) 'market3',
      'market4',
      'mine1',
      'mine1',
      'mine2',
      for (var i = 0; i < 3; i++) 'water',
      for (var i = 0; i < 4; i++) 'temple',
    ];
    if (players >= 3) {
      deck.addAll(['plant1', 'market3', 'mine1', 'water', 'temple']);
    }
    return deck;
  }

  int waterScore(int seat) => cacaoWaterTrack[water[seat].clamp(0, cacaoWaterTrack.length - 1)];

  int totalScore(int seat) => gold[seat] + waterScore(seat) + templeBonus[seat];

  @override
  void start() {
    workerBoard.clear();
    jungleBoard.clear();
    jungleDeck.clear();
    jungleMarket.clear();
    pendingJungleCells.clear();
    newlyPlacedJungles.clear();
    lastPlacedWorker = null;

    // Initial board setup
    jungleBoard[(0, 1)] = 'plant1';
    jungleBoard[(1, 0)] = 'market2';

    final shortMode = setup.opt<String>('mode', 'standard') == 'short';
    jungleDeck.addAll(buildJungleDeck(players));
    jungleDeck.shuffle(rng);

    while (jungleMarket.length < 2 && jungleDeck.isNotEmpty) {
      jungleMarket.add(jungleDeck.removeLast());
    }

    workerDecks = List.generate(players, (_) {
      final list = [for (final t in buildPlayerWorkerSet(players, shortMode)) List<int>.of(t)];
      list.shuffle(rng);
      return list;
    });
    hands = List.generate(players, (s) {
      final h = <List<int>>[];
      while (h.length < 3 && workerDecks[s].isNotEmpty) {
        h.add(workerDecks[s].removeLast());
      }
      return h;
    });

    gold = List<int>.filled(players, 0);
    cacao = List<int>.filled(players, 0);
    water = List<int>.filled(players, 0);
    templeBonus = List<int>.filled(players, 0);

    turn = 0;
    phase = 'place_worker';
    _over = false;
    lastAction = '游戏开始，轮到 ${name(turn)} 放置工人板块';
  }

  /// All valid empty Worker Cells `(r, c)` (`(r + c).isEven`) orthogonally adjacent to >= 1 Jungle Tile.
  Set<(int, int)> validWorkerCells() {
    final out = <(int, int)>{};
    for (final jPos in jungleBoard.keys) {
      for (var d = 0; d < 4; d++) {
        final wr = jPos.$1 + dr[d];
        final wc = jPos.$2 + dc[d];
        if ((wr + wc).isEven && !workerBoard.containsKey((wr, wc))) {
          out.add((wr, wc));
        }
      }
    }
    if (out.isEmpty) {
      // Fallback if all jungle perimeters are somehow full: diagonal from any worker tile
      for (final wPos in workerBoard.keys) {
        for (final (dr2, dc2) in const [(-1, -1), (-1, 1), (1, -1), (1, 1), (-2, 0), (2, 0), (0, -2), (0, 2)]) {
          final wr = wPos.$1 + dr2;
          final wc = wPos.$2 + dc2;
          if ((wr + wc).isEven && !workerBoard.containsKey((wr, wc))) {
            out.add((wr, wc));
          }
        }
      }
    }
    return out;
  }

  /// Finds empty Jungle Cells `(jr, jc)` (`(jr + jc).isOdd`) with >= 2 adjacent Worker Tiles.
  List<(int, int)> findTriggeredJungleCells() {
    final candidates = <(int, int)>{};
    for (final wPos in workerBoard.keys) {
      for (var d = 0; d < 4; d++) {
        final jr = wPos.$1 + dr[d];
        final jc = wPos.$2 + dc[d];
        if ((jr + jc).isOdd && !jungleBoard.containsKey((jr, jc))) {
          candidates.add((jr, jc));
        }
      }
    }
    final result = <(int, int)>[];
    for (final jPos in candidates) {
      var adjWorkers = 0;
      for (var d = 0; d < 4; d++) {
        if (workerBoard.containsKey((jPos.$1 + dr[d], jPos.$2 + dc[d]))) {
          adjWorkers++;
        }
      }
      if (adjWorkers >= 2) {
        result.add(jPos);
      }
    }
    result.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
    return result;
  }

  void _ensureMarketForPending() {
    if (jungleMarket.isEmpty && jungleDeck.isNotEmpty) {
      jungleMarket.add(jungleDeck.removeLast());
    }
  }

  void _checkAutoOrFinishJungle() {
    _ensureMarketForPending();
    while (pendingJungleCells.isNotEmpty && jungleMarket.isNotEmpty) {
      // Auto-fill if there is only 1 distinct tile choice and 1 cell (or all market tiles are identical and 1 cell)
      final distinctMarket = jungleMarket.toSet();
      if (pendingJungleCells.length == 1 && distinctMarket.length == 1) {
        final cell = pendingJungleCells.removeAt(0);
        final tile = jungleMarket.removeAt(0);
        jungleBoard[cell] = tile;
        newlyPlacedJungles.add(cell);
        _ensureMarketForPending();
      } else {
        phase = 'place_jungle';
        return;
      }
    }
    pendingJungleCells.clear();
    _resolveTurnActivations();
  }

  static int _activationOrder(String jType) {
    if (jType == 'plant1' || jType == 'plant2') return 0;
    if (jType == 'mine1' || jType == 'mine2' || jType == 'water') return 1;
    if (jType == 'market2' || jType == 'market3' || jType == 'market4') return 2;
    return 3;
  }

  void _applyJungleEffect(int owner, String jType, int w) {
    if (w <= 0) return;
    switch (jType) {
      case 'plant1':
        cacao[owner] = min(5, cacao[owner] + w);
        break;
      case 'plant2':
        cacao[owner] = min(5, cacao[owner] + w * 2);
        break;
      case 'market2':
        final sold = min(cacao[owner], w);
        cacao[owner] -= sold;
        gold[owner] += sold * 2;
        break;
      case 'market3':
        final sold = min(cacao[owner], w);
        cacao[owner] -= sold;
        gold[owner] += sold * 3;
        break;
      case 'market4':
        final sold = min(cacao[owner], w);
        cacao[owner] -= sold;
        gold[owner] += sold * 4;
        break;
      case 'mine1':
        gold[owner] += w;
        break;
      case 'mine2':
        gold[owner] += w * 2;
        break;
      case 'water':
        water[owner] = min(cacaoWaterTrack.length - 1, water[owner] + w);
        break;
      case 'temple':
        break;
    }
  }

  void _resolveTurnActivations() {
    final acts = <(int, String, int)>[]; // (ownerSeat, jungleType, workers)
    final newlySet = newlyPlacedJungles.toSet();

    // 1. Newly placed Worker Tile against pre-existing Jungle Tiles
    final wPos = lastPlacedWorker;
    if (wPos != null && workerBoard.containsKey(wPos)) {
      final pw = workerBoard[wPos]!;
      for (var d = 0; d < 4; d++) {
        final jPos = (wPos.$1 + dr[d], wPos.$2 + dc[d]);
        if (jungleBoard.containsKey(jPos) && !newlySet.contains(jPos)) {
          final w = pw.edges[d];
          if (w > 0) {
            acts.add((pw.seat, jungleBoard[jPos]!, w));
          }
        }
      }
    }

    // 2. Newly placed Jungle Tiles against ANY touching Worker Tile
    for (final jPos in newlyPlacedJungles) {
      final jType = jungleBoard[jPos]!;
      for (var d = 0; d < 4; d++) {
        final adjW = (jPos.$1 + dr[d], jPos.$2 + dc[d]);
        final pw = workerBoard[adjW];
        if (pw != null) {
          final w = pw.edges[(d + 2) & 3];
          if (w > 0) {
            acts.add((pw.seat, jType, w));
          }
        }
      }
    }

    // Sort so Cacao harvesting happens before Market selling
    acts.sort((a, b) => _activationOrder(a.$2).compareTo(_activationOrder(b.$2)));
    for (final (owner, jType, w) in acts) {
      _applyJungleEffect(owner, jType, w);
    }

    // Refill player's hand
    if (workerDecks[turn].isNotEmpty && hands[turn].length < 3) {
      hands[turn].add(workerDecks[turn].removeLast());
    }

    // Refill jungleMarket up to 2
    while (jungleMarket.length < 2 && jungleDeck.isNotEmpty) {
      jungleMarket.add(jungleDeck.removeLast());
    }

    // Check if game is over
    if (hands.every((h) => h.isEmpty)) {
      _scoreTemples();
      _over = true;
      final scores = [for (var s = 0; s < players; s++) totalScore(s)];
      final ranks = placings!;
      final winners = [
        for (var s = 0; s < players; s++)
          if (ranks[s] == 1) '${name(s)}(${scores[s]}金)'
      ];
      lastAction = '所有工人放置完毕，游戏结束！获胜：${winners.join("、")}';
      host.log(lastAction);
      return;
    }

    // Advance turn to next player who still has tiles in hand
    for (var step = 1; step <= players; step++) {
      final next = (turn + step) % players;
      if (hands[next].isNotEmpty) {
        turn = next;
        break;
      }
    }
    phase = 'place_worker';
  }

  void computeTemplesInto(List<int> outTemple) {
    for (var s = 0; s < players; s++) {
      outTemple[s] = 0;
    }
    for (final entry in jungleBoard.entries) {
      if (entry.value != 'temple') continue;
      final jPos = entry.key;
      final counts = List<int>.filled(players, 0);
      for (var d = 0; d < 4; d++) {
        final adjW = (jPos.$1 + dr[d], jPos.$2 + dc[d]);
        final pw = workerBoard[adjW];
        if (pw != null) {
          counts[pw.seat] += pw.edges[(d + 2) & 3];
        }
      }
      var max1 = 0;
      for (final c in counts) {
        if (c > max1) max1 = c;
      }
      if (max1 == 0) continue;
      final firsts = [for (var s = 0; s < players; s++) if (counts[s] == max1) s];
      if (firsts.length == 1) {
        outTemple[firsts.first] += 6;
        var max2 = 0;
        for (var s = 0; s < players; s++) {
          if (counts[s] < max1 && counts[s] > max2) max2 = counts[s];
        }
        if (max2 > 0) {
          final seconds = [for (var s = 0; s < players; s++) if (counts[s] == max2) s];
          final share = 3 ~/ seconds.length;
          for (final s in seconds) {
            outTemple[s] += share;
          }
        }
      } else {
        final share = 6 ~/ firsts.length;
        for (final s in firsts) {
          outTemple[s] += share;
        }
      }
    }
  }

  void _scoreTemples() {
    computeTemplesInto(templeBonus);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    if (phase == 'place_worker') {
      if (type != 'place_worker') throw GameError('当前请放置工人板块');
      final handIdx = asInt(action['handIdx'], -1);
      final r = asInt(action['r'], 999999);
      final c = asInt(action['c'], 999999);
      final rot = asInt(action['rot'], 0);

      if (handIdx < 0 || handIdx >= hands[seat].length) {
        throw GameError('无效的手牌序号');
      }
      if (rot < 0 || rot > 3) {
        throw GameError('无效的旋转角度');
      }
      final valid = validWorkerCells();
      if (!valid.contains((r, c))) {
        throw GameError('该位置不能放置工人板块（需放在与丛林板块相邻的空工人格）');
      }

      final baseEdges = hands[seat].removeAt(handIdx);
      final rotated = rotateEdges(baseEdges, rot);
      workerBoard[(r, c)] = PlacedWorker(seat: seat, edges: rotated);
      lastPlacedWorker = (r, c);
      newlyPlacedJungles.clear();

      lastAction = '${name(seat)} 在 ($r, $c) 放置了工人板块 [${rotated.join("/")}]';
      host.log(lastAction);

      pendingJungleCells
        ..clear()
        ..addAll(findTriggeredJungleCells());
      _checkAutoOrFinishJungle();
      return;
    }

    if (phase == 'place_jungle') {
      if (type != 'place_jungle') throw GameError('当前请选择丛林板块填补空位');
      final mIdx = asInt(action['marketIdx'], -1);
      if (mIdx < 0 || mIdx >= jungleMarket.length) {
        throw GameError('无效的丛林市场序号');
      }
      final r = action.containsKey('r') ? asInt(action['r'], 999999) : pendingJungleCells.first.$1;
      final c = action.containsKey('c') ? asInt(action['c'], 999999) : pendingJungleCells.first.$2;
      final cellIdx = pendingJungleCells.indexOf((r, c));
      if (cellIdx == -1) {
        throw GameError('该格子不在待填补的丛林格列表中');
      }

      final cell = pendingJungleCells.removeAt(cellIdx);
      final tile = jungleMarket.removeAt(mIdx);
      jungleBoard[cell] = tile;
      newlyPlacedJungles.add(cell);
      lastAction = '${name(seat)} 在 (${cell.$1}, ${cell.$2}) 放置了丛林板块【${cacaoJungleNames[tile] ?? tile}】';
      host.log(lastAction);

      _checkAutoOrFinishJungle();
      return;
    }

    throw GameError('未知阶段：$phase');
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    if (phase == 'place_jungle') {
      if (pendingJungleCells.isEmpty || jungleMarket.isEmpty) return null;
      if (botLevel == 0) {
        final cell = pendingJungleCells.first;
        return {'type': 'place_jungle', 'marketIdx': 0, 'r': cell.$1, 'c': cell.$2};
      }
      var bestM = 0;
      var bestCell = pendingJungleCells.first;
      var bestVal = -999999.0;
      for (final cell in pendingJungleCells) {
        for (var m = 0; m < jungleMarket.length; m++) {
          final jType = jungleMarket[m];
          var val = 0.0;
          for (var d = 0; d < 4; d++) {
            final pw = workerBoard[(cell.$1 + dr[d], cell.$2 + dc[d])];
            if (pw != null) {
              final w = pw.edges[(d + 2) & 3];
              final sign = pw.seat == seat ? 1.0 : -0.7;
              val += sign * _evalTileActivation(pw.seat, jType, w);
            }
          }
          if (val > bestVal) {
            bestVal = val;
            bestM = m;
            bestCell = cell;
          }
        }
      }
      return {'type': 'place_jungle', 'marketIdx': bestM, 'r': bestCell.$1, 'c': bestCell.$2};
    }

    final cells = validWorkerCells().toList();
    if (cells.isEmpty || hands[seat].isEmpty) return null;

    if (botLevel == 0) {
      final cell = cells[rng.nextInt(cells.length)];
      return {
        'type': 'place_worker',
        'handIdx': rng.nextInt(hands[seat].length),
        'r': cell.$1,
        'c': cell.$2,
        'rot': rng.nextInt(4),
      };
    }

    var bestAct = <String, dynamic>{
      'type': 'place_worker',
      'handIdx': 0,
      'r': cells.first.$1,
      'c': cells.first.$2,
      'rot': 0,
    };
    var bestScore = -999999.0;

    for (var h = 0; h < hands[seat].length; h++) {
      final base = hands[seat][h];
      for (final cell in cells) {
        for (var rot = 0; rot < 4; rot++) {
          final edges = rotateEdges(base, rot);
          var score = 0.0;
          var tempCacao = cacao[seat];
          // First pass: plantations
          for (var d = 0; d < 4; d++) {
            final jPos = (cell.$1 + dr[d], cell.$2 + dc[d]);
            final jType = jungleBoard[jPos];
            if (jType == 'plant1' || jType == 'plant2') {
              final w = edges[d];
              final gain = jType == 'plant1' ? w : w * 2;
              final actual = min(5 - tempCacao, gain);
              tempCacao += actual;
              score += actual * 2.2;
            }
          }
          // Second pass: other existing jungle tiles & potential new jungle triggers
          for (var d = 0; d < 4; d++) {
            final jPos = (cell.$1 + dr[d], cell.$2 + dc[d]);
            final jType = jungleBoard[jPos];
            final w = edges[d];
            if (jType != null) {
              if (jType == 'market2' || jType == 'market3' || jType == 'market4') {
                final price = jType == 'market2' ? 2 : (jType == 'market3' ? 3 : 4);
                final sold = min(tempCacao, w);
                tempCacao -= sold;
                score += sold * price * 1.1;
              } else if (jType != 'plant1' && jType != 'plant2') {
                score += _evalTileActivation(seat, jType, w);
              }
            } else if (jungleMarket.isNotEmpty) {
              // Check if placing at cell causes jPos to have >= 2 adjacent workers
              var adj = 1;
              for (var d2 = 0; d2 < 4; d2++) {
                final w2 = (jPos.$1 + dr[d2], jPos.$2 + dc[d2]);
                if (w2 != cell && workerBoard.containsKey(w2)) adj++;
              }
              if (adj >= 2) {
                score += w * 2.0;
              }
            }
          }
          if (score > bestScore) {
            bestScore = score;
            bestAct = {
              'type': 'place_worker',
              'handIdx': h,
              'r': cell.$1,
              'c': cell.$2,
              'rot': rot,
            };
          }
        }
      }
    }
    return bestAct;
  }

  double _evalTileActivation(int seat, String jType, int w) {
    if (w <= 0) return 0;
    switch (jType) {
      case 'plant1':
        return min(5 - cacao[seat], w) * 2.2;
      case 'plant2':
        return min(5 - cacao[seat], w * 2) * 2.2;
      case 'market2':
        return min(cacao[seat], w) * 2.0;
      case 'market3':
        return min(cacao[seat], w) * 3.0;
      case 'market4':
        return min(cacao[seat], w) * 4.0;
      case 'mine1':
        return w * 1.0;
      case 'mine2':
        return w * 2.0;
      case 'water':
        final cur = water[seat];
        final next = min(cacaoWaterTrack.length - 1, cur + w);
        return (cacaoWaterTrack[next] - cacaoWaterTrack[cur]).toDouble();
      case 'temple':
        return w * 2.5;
      default:
        return 0;
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final liveTemples = List<int>.filled(players, 0);
    computeTemplesInto(liveTemples);

    final validCells = [
      for (final c in validWorkerCells()) [c.$1, c.$2],
    ];

    return {
      'turn': turn,
      'phase': phase,
      'over': _over,
      'lastAction': lastAction,
      'lastPlacedWorker': lastPlacedWorker != null ? [lastPlacedWorker!.$1, lastPlacedWorker!.$2] : null,
      'pendingJungleCells': [
        for (final c in pendingJungleCells) [c.$1, c.$2],
      ],
      'validWorkerCells': validCells,
      'jungleMarket': List<String>.of(jungleMarket),
      'jungleDeckCount': jungleDeck.length,
      'workerBoard': [
        for (final e in workerBoard.entries)
          {
            'r': e.key.$1,
            'c': e.key.$2,
            'seat': e.value.seat,
            'edges': e.value.edges,
          },
      ],
      'jungleBoard': [
        for (final e in jungleBoard.entries)
          {
            'r': e.key.$1,
            'c': e.key.$2,
            'type': e.value,
            'name': cacaoJungleNames[e.value] ?? e.value,
          },
      ],
      'hand': seat >= 0 && seat < players ? [for (final t in hands[seat]) List<int>.of(t)] : const [],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'seat': s,
            'gold': gold[s],
            'cacao': cacao[s],
            'waterIndex': water[s],
            'waterScore': waterScore(s),
            'templeBonus': _over ? templeBonus[s] : liveTemples[s],
            'totalScore': gold[s] + waterScore(s) + (_over ? templeBonus[s] : liveTemples[s]),
            'handCount': hands[s].length,
            'deckCount': workerDecks[s].length,
          },
      ],
      'scores': [
        for (var s = 0; s < players; s++) gold[s] + waterScore(s) + (_over ? templeBonus[s] : liveTemples[s]),
      ],
      'placings': placings,
    };
  }
}
