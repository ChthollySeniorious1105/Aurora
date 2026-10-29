import 'dart:math';

import '../../src/engine.dart';

const String arboretumRules = '''
# 植物园 (Arboretum) 规则说明

## 基本配置
- **人数与树种数量**：支持 2~4 人游玩。共有 10 种名贵树木（编号 `0..9`：樱花、枫树、橡树、蓝花楹、柳树、金合欢、桦树、松树、雪松、紫荆），每种树包含数值 `1..8` 的 8 张牌：
  - **2人局**：使用前 **6 种**树木（共 48 张牌）。
  - **3人局**：使用前 **8 种**树木（共 64 张牌）。
  - **4人局**：使用全部 **10 种**树木（共 80 张牌）。
- **初始设置**：每位玩家起始摸 **7 张手牌**，拥有各自独立的**个人弃牌堆**（正面朝上）与**个人植物园网格**（初始为空）。

## 回合流程（四步操作）
轮到一名玩家时，依次执行以下子步骤（`draw1 -> draw2 -> plant -> discard`）：
1. **摸第一张牌 (`draw1`)**：可选择从**中央摸牌堆**摸 1 张暗牌，或从**任意玩家（含自己）非空弃牌堆顶**摸走最上面的 1 张明牌。
2. **摸第二张牌 (`draw2`)**：同样可选择从中央摸牌堆或任意玩家非空弃牌堆顶摸 1 张牌（此时手牌为 9 张）。
3. **栽种树木 (`plant`)**：从手中选择 1 张牌栽种到自己的植物园网格中：
   - 第 1 张牌固定栽种在中心坐标 `(0, 0)`。
   - 之后的每张牌必须栽种在已有树木的**上下左右正交相邻空位**上。
4. **弃置手牌 (`discard`)**：从手中选择 1 张牌正面朝上放到**自己的个人弃牌堆顶**（手牌恢复为 7 张）。

## 游戏结束与终局结算
当一名玩家完成弃牌、且此时**中央摸牌堆已被摸空（剩余 0 张）**时，游戏立即结束！
随后对本局使用的每一种树木 `sp` 依次进行两阶段结算：

### 第一步：判定计分权 (Scoring Rights)
- 比较所有玩家**最终手牌**中持有的树种 `sp` 的数值总和：
  - **1 克 8 特殊规则**：若某玩家手牌持有树种 `sp` 的 **`8`**，而**另一名对手**手牌中持有同树种 `sp` 的 **`1`**，则该张 `8` 在比较计分权时**视为 `0` 点**！
- 手牌中树种 `sp` 有效点数总和**最高**的玩家（平手则共享）获得该树种的**计分权**。
- 若所有玩家手牌中树种 `sp` 的有效点数均为 `0`，则**全体玩家**均获得该树种的计分权！
- 未获得树种 `sp` 计分权的玩家，其植物园中该树种的得分为 `0` 分（哪怕种出了很长的路径也无法得分！）。

### 第二步：植物园路径计分 (Path Scoring)
获得树种 `sp` 计分权的玩家，在自己的植物园网格中寻找一条**得分最高**的正交路径，须满足：
1. **首尾同种**：路径的**起点**与**终点**都必须是树种 `sp` 的牌（中间经过的树木可以是任意树种，路径至少包含 2 张牌）。
2. **严格递增**：沿路径从起点到终点，每一步正交相邻卡牌的**数值必须严格递增**（例如 `1 -> 3 -> 4 -> 7 -> 8`）。
3. **路径分值计算**：
   - **基础分**：路径上每有 1 张牌得 **1 分**（长度为 L 得 L 分）。
   - **同种长路奖励**：若路径长度 **≥ 4 张**且路径上**所有牌全部是树种 `sp`**，则每张牌额外 **+1 分**（即双倍基础分）。
   - **起点为 1 奖励**：若路径起点的数值为 `1`，额外 **+1 分**。
   - **终点为 8 奖励**：若路径终点的数值为 `8`，额外 **+2 分**。

所有树种结算完毕后，总分最高的玩家获胜！
''';

const List<String> kSpeciesNames = [
  '樱花',
  '枫树',
  '橡树',
  '蓝花楹',
  '柳树',
  '金合欢',
  '桦树',
  '松树',
  '雪松',
  '紫荆',
];

int speciesCountForPlayers(int players) {
  if (players <= 2) return 6;
  if (players == 3) return 8;
  return 10;
}

String arboretumCard(int species, int rank) => '$species-$rank';

int arboretumSpeciesOf(String card) {
  final dash = card.indexOf('-');
  if (dash > 0) return int.tryParse(card.substring(0, dash)) ?? 0;
  final colon = card.indexOf(':');
  if (colon > 0) return int.tryParse(card.substring(0, colon)) ?? 0;
  return 0;
}

int arboretumRankOf(String card) {
  final dash = card.indexOf('-');
  if (dash > 0) return int.tryParse(card.substring(dash + 1)) ?? 1;
  final colon = card.indexOf(':');
  if (colon > 0) return int.tryParse(card.substring(colon + 1)) ?? 1;
  return 1;
}

List<String> buildArboretumDeck(int players) {
  final nSpecies = speciesCountForPlayers(players);
  return [
    for (var sp = 0; sp < nSpecies; sp++)
      for (var r = 1; r <= 8; r++) arboretumCard(sp, r),
  ];
}

/// Computes effective hand sums and the set of seats with scoring rights for [species].
({List<int> sums, List<int> rightHolders}) computeArboretumScoringRights(
  List<List<String>> hands,
  int species,
) {
  final n = hands.length;
  final hasOne = [
    for (var s = 0; s < n; s++)
      hands[s].any((c) => arboretumSpeciesOf(c) == species && arboretumRankOf(c) == 1),
  ];
  final sums = List<int>.filled(n, 0);
  for (var s = 0; s < n; s++) {
    final otherHasOne = [
      for (var other = 0; other < n; other++)
        if (other != s && hasOne[other]) other,
    ].isNotEmpty;
    var sum = 0;
    for (final c in hands[s]) {
      if (arboretumSpeciesOf(c) != species) continue;
      final r = arboretumRankOf(c);
      if (r == 8 && otherHasOne) continue; // 8 neutralized by another player's 1!
      sum += r;
    }
    sums[s] = sum;
  }

  final maxSum = sums.fold<int>(0, max);
  if (maxSum == 0) {
    return (sums: sums, rightHolders: [for (var s = 0; s < n; s++) s]);
  }
  return (
    sums: sums,
    rightHolders: [
      for (var s = 0; s < n; s++)
        if (sums[s] == maxSum) s,
    ],
  );
}

/// Evaluates the score of a valid strictly-ascending path of [cards] for [species].
int scoreArboretumPathCards(List<String> cards, int species) {
  if (cards.length < 2) return 0;
  if (arboretumSpeciesOf(cards.first) != species || arboretumSpeciesOf(cards.last) != species) {
    return 0;
  }
  for (var i = 1; i < cards.length; i++) {
    if (arboretumRankOf(cards[i]) <= arboretumRankOf(cards[i - 1])) return 0;
  }
  final len = cards.length;
  var pts = len; // 1 pt per card
  final allSameSpecies = cards.every((c) => arboretumSpeciesOf(c) == species);
  if (len >= 4 && allSameSpecies) {
    pts += len; // +1 extra pt per card
  }
  if (arboretumRankOf(cards.first) == 1) {
    pts += 1;
  }
  if (arboretumRankOf(cards.last) == 8) {
    pts += 2;
  }
  return pts;
}

/// Finds the highest-scoring orthogonal strictly-ascending path in [grid] starting and ending with [species].
/// [grid] keys are `'r,c'` strings.
({int score, List<List<int>> coords, List<String> cards}) bestArboretumPathForSpecies(
  Map<String, String> grid,
  int species,
) {
  final parsed = <(int, int), String>{};
  for (final e in grid.entries) {
    final parts = e.key.split(',');
    if (parts.length == 2) {
      final r = int.tryParse(parts[0]);
      final c = int.tryParse(parts[1]);
      if (r != null && c != null) parsed[(r, c)] = e.value;
    }
  }

  var bestScore = 0;
  var bestCoords = <List<int>>[];
  var bestCards = <String>[];

  const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];

  void dfs((int, int) pos, List<List<int>> pathCoords, List<String> pathCards) {
    final currCard = pathCards.last;
    final currRank = arboretumRankOf(currCard);
    if (pathCards.length >= 2 && arboretumSpeciesOf(currCard) == species) {
      final sc = scoreArboretumPathCards(pathCards, species);
      if (sc > bestScore) {
        bestScore = sc;
        bestCoords = List.of(pathCoords);
        bestCards = List.of(pathCards);
      }
    }

    for (final (dr, dc) in dirs) {
      final nextPos = (pos.$1 + dr, pos.$2 + dc);
      final nextCard = parsed[nextPos];
      if (nextCard == null) continue;
      if (arboretumRankOf(nextCard) > currRank) {
        pathCoords.add([nextPos.$1, nextPos.$2]);
        pathCards.add(nextCard);
        dfs(nextPos, pathCoords, pathCards);
        pathCards.removeLast();
        pathCoords.removeLast();
      }
    }
  }

  for (final entry in parsed.entries) {
    if (arboretumSpeciesOf(entry.value) == species) {
      dfs(entry.key, [[entry.key.$1, entry.key.$2]], [entry.value]);
    }
  }

  return (score: bestScore, coords: bestCoords, cards: bestCards);
}

class Arboretum extends GameEngine {
  late int numSpecies;
  int turn = 0;
  int turnCount = 1;
  String step = 'draw1'; // 'draw1', 'draw2', 'plant', 'discard', 'over'

  List<String> deck = [];
  List<List<String>> hands = [];
  List<List<String>> discards = [];
  List<Map<String, String>> grids = [];

  List<int> totalScores = [];
  List<Map<String, dynamic>> speciesBreakdown = [];
  bool _over = false;

  Arboretum(super.setup) {
    numSpecies = speciesCountForPlayers(players);
  }

  @override
  bool get isOver => _over;

  @override
  bool get canResign => !_over;

  @override
  void resign(int seat) {
    if (_over) throw GameError('游戏已结束');
    _over = true;
    step = 'over';
    totalScores = [
      for (var s = 0; s < players; s++) s == seat ? -1 : 10,
    ];
    host.log('${name(seat)} 认输！');
  }

  @override
  List<int>? get placings => _over ? rankByScore(totalScores) : null;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  void start() {
    final all = shuffled(buildArboretumDeck(players), rng);
    hands = [
      for (var s = 0; s < players; s++) all.sublist(s * 7, (s + 1) * 7),
    ];
    deck = all.sublist(players * 7);
    discards = [for (var s = 0; s < players; s++) <String>[]];
    grids = [for (var s = 0; s < players; s++) <String, String>{}];
    totalScores = List.filled(players, 0);
    speciesBreakdown = [];
    turn = 0;
    turnCount = 1;
    step = 'draw1';
    _sortAllHands();
  }

  void _sortAllHands() {
    for (var s = 0; s < players; s++) {
      hands[s].sort((a, b) {
        final sa = arboretumSpeciesOf(a);
        final sb = arboretumSpeciesOf(b);
        if (sa != sb) return sa.compareTo(sb);
        return arboretumRankOf(a).compareTo(arboretumRankOf(b));
      });
    }
  }

  /// Returns all valid empty `(r, c)` positions where [seat] may plant a card.
  List<List<int>> validPlantPositions(int seat) {
    final g = grids[seat];
    if (g.isEmpty) return const [[0, 0]];
    final candidates = <(int, int)>{};
    const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];
    for (final key in g.keys) {
      final parts = key.split(',');
      final r = int.parse(parts[0]);
      final c = int.parse(parts[1]);
      for (final (dr, dc) in dirs) {
        final nr = r + dr;
        final nc = c + dc;
        if (!g.containsKey('$nr,$nc')) {
          candidates.add((nr, nc));
        }
      }
    }
    final list = [for (final p in candidates) [p.$1, p.$2]];
    list.sort((a, b) => a[0] != b[0] ? a[0].compareTo(b[0]) : a[1].compareTo(b[1]));
    return list;
  }

  bool isValidPlantPosition(int seat, int r, int c) {
    final g = grids[seat];
    if (g.isEmpty) return r == 0 && c == 0;
    if (g.containsKey('$r,$c')) return false;
    return g.containsKey('${r - 1},$c') ||
        g.containsKey('${r + 1},$c') ||
        g.containsKey('$r,${c - 1}') ||
        g.containsKey('$r,${c + 1}');
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);

    if (step == 'draw1' || step == 'draw2') {
      if (type != 'draw') throw GameError('当前处于摸牌阶段，请先摸牌');
      final source = asStr(action['source'], 'deck');
      if (source == 'deck') {
        if (deck.isEmpty) throw GameError('中央摸牌堆已空，请从任意非空弃牌堆摸牌');
        final card = deck.removeAt(0);
        hands[seat].add(card);
      } else if (source == 'discard') {
        final fromSeat = asInt(action['seat'], -1);
        if (fromSeat < 0 || fromSeat >= players || discards[fromSeat].isEmpty) {
          throw GameError('所选弃牌堆为空或无效');
        }
        final card = discards[fromSeat].removeLast();
        hands[seat].add(card);
      } else {
        throw GameError('无效的摸牌来源：$source');
      }
      _sortAllHands();

      if (step == 'draw1') {
        final canDrawMore = deck.isNotEmpty || discards.any((d) => d.isNotEmpty);
        step = canDrawMore ? 'draw2' : 'plant';
      } else {
        step = 'plant';
      }
      return;
    }

    if (step == 'plant') {
      if (type != 'plant') throw GameError('当前请栽种一张树木卡牌到植物园');
      final card = asStr(action['card']);
      if (!hands[seat].contains(card)) throw GameError('你手里没有这张牌：$card');
      final r = asInt(action['r'], 999999);
      final c = asInt(action['c'], 999999);
      if (r == 999999 || c == 999999 || !isValidPlantPosition(seat, r, c)) {
        throw GameError('栽种位置 ($r, $c) 不合法：首张牌须在 (0,0)，后续须与已有树木正交相邻且为空位');
      }
      hands[seat].remove(card);
      grids[seat]['$r,$c'] = card;
      step = 'discard';
      return;
    }

    if (step == 'discard') {
      if (type != 'discard') throw GameError('当前请选择一张手牌弃置到个人弃牌堆');
      final card = asStr(action['card']);
      if (!hands[seat].contains(card)) throw GameError('你手里没有这张牌：$card');
      hands[seat].remove(card);
      discards[seat].add(card);

      if (deck.isEmpty) {
        _scoreGame();
      } else {
        turn = (turn + 1) % players;
        turnCount++;
        step = 'draw1';
      }
      return;
    }

    throw GameError('当前阶段无法执行该操作');
  }

  void _scoreGame() {
    _over = true;
    step = 'over';
    totalScores = List.filled(players, 0);
    speciesBreakdown = [];

    for (var sp = 0; sp < numSpecies; sp++) {
      final rights = computeArboretumScoringRights(hands, sp);
      final scoresForSp = List.filled(players, 0);
      final bestPaths = <List<String>>[];
      final bestCoords = <List<List<int>>>[];

      for (var s = 0; s < players; s++) {
        if (rights.rightHolders.contains(s)) {
          final res = bestArboretumPathForSpecies(grids[s], sp);
          scoresForSp[s] = res.score;
          totalScores[s] += res.score;
          bestPaths.add(res.cards);
          bestCoords.add(res.coords);
        } else {
          bestPaths.add(const []);
          bestCoords.add(const []);
        }
      }

      speciesBreakdown.add({
        'species': sp,
        'name': kSpeciesNames[sp],
        'handSums': rights.sums,
        'rightHolders': rights.rightHolders,
        'scores': scoresForSp,
        'bestPaths': bestPaths,
        'bestCoords': bestCoords,
      });
    }

    host.log('植物园终局结算完成！各座总分：$totalScores');
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    final h = hands[seat];

    if (step == 'draw1' || step == 'draw2') {
      // Always prefer drawing from deck when non-empty so game progresses briskly;
      // on draw1 at higher botLevel, occasionally grab a rank 1 or 8 from discard if present.
      if (step == 'draw1' && botLevel >= 1 && deck.length > 4) {
        for (var s = 0; s < players; s++) {
          if (discards[s].isNotEmpty) {
            final top = discards[s].last;
            final r = arboretumRankOf(top);
            final sp = arboretumSpeciesOf(top);
            final hasSameSp = h.any((c) => arboretumSpeciesOf(c) == sp);
            if (hasSameSp && (r == 1 || r == 8) && rng.nextDouble() < 0.35) {
              return {'type': 'draw', 'source': 'discard', 'seat': s};
            }
          }
        }
      }
      if (deck.isNotEmpty) {
        return {'type': 'draw', 'source': 'deck'};
      }
      for (var s = 0; s < players; s++) {
        if (discards[s].isNotEmpty) {
          return {'type': 'draw', 'source': 'discard', 'seat': s};
        }
      }
      return null;
    }

    if (step == 'plant') {
      final slots = validPlantPositions(seat);
      if (botLevel == 0 || h.length == 1) {
        final c = h[rng.nextInt(h.length)];
        final pos = slots[rng.nextInt(slots.length)];
        return {'type': 'plant', 'card': c, 'r': pos[0], 'c': pos[1]};
      }

      // Heuristic: choose card & slot that maximizes immediate or potential ascending adjacency
      var bestCard = h.first;
      var bestSlot = slots.first;
      var bestVal = -9999;
      final g = grids[seat];
      const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];

      for (final card in h) {
        final sp = arboretumSpeciesOf(card);
        final rk = arboretumRankOf(card);
        // Count how many cards of this species we still keep in hand for scoring rights
        final sameSpInHand = h.where((x) => x != card && arboretumSpeciesOf(x) == sp).length;

        for (final pos in slots) {
          final r = pos[0];
          final c = pos[1];
          var val = sameSpInHand * 4;
          // Prefer planting lower ranks slightly top/left and higher ranks bottom/right for natural gradient
          val += (r + c) * (rk - 4);
          for (final (dr, dc) in dirs) {
            final nb = g['${r + dr},${c + dc}'];
            if (nb == null) continue;
            final nbRank = arboretumRankOf(nb);
            final nbSp = arboretumSpeciesOf(nb);
            final diff = (rk - nbRank).abs();
            if (diff >= 1 && diff <= 3) val += 10 - diff * 2;
            if (nbSp == sp && rk != nbRank) val += 6;
          }
          if (val > bestVal) {
            bestVal = val;
            bestCard = card;
            bestSlot = pos;
          }
        }
      }
      return {'type': 'plant', 'card': bestCard, 'r': bestSlot[0], 'c': bestSlot[1]};
    }

    if (step == 'discard') {
      if (botLevel == 0 || h.length == 1) {
        return {'type': 'discard', 'card': h[rng.nextInt(h.length)]};
      }
      // Keep high-value cards of species we have planted in our grid; discard lowest-value / unplanted species
      final plantedSpecies = {
        for (final c in grids[seat].values) arboretumSpeciesOf(c),
      };
      final sorted = List.of(h)
        ..sort((a, b) {
          final sa = arboretumSpeciesOf(a);
          final sb = arboretumSpeciesOf(b);
          final pa = (plantedSpecies.contains(sa) ? 10 : 0) + arboretumRankOf(a);
          final pb = (plantedSpecies.contains(sb) ? 10 : 0) + arboretumRankOf(b);
          return pa.compareTo(pb);
        });
      return {'type': 'discard', 'card': sorted.first};
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myHand = (seat >= 0 && seat < players) ? List<String>.of(hands[seat]) : const <String>[];
    final validSlots = (!_over && seat == turn && step == 'plant')
        ? validPlantPositions(seat)
        : const <List<int>>[];

    return {
      'step': step,
      'phase': step,
      'turn': turn,
      'turnCount': turnCount,
      'numSpecies': numSpecies,
      'speciesNames': kSpeciesNames.sublist(0, numSpecies),
      'deckCount': deck.length,
      'handCounts': [for (var s = 0; s < players; s++) hands[s].length],
      'hand': myHand,
      // Reveal all hands once the game is over so players can inspect Scoring Rights
      'revealedHands': _over ? [for (var s = 0; s < players; s++) List<String>.of(hands[s])] : null,
      'discards': [for (var s = 0; s < players; s++) List<String>.of(discards[s])],
      'grids': [for (var s = 0; s < players; s++) Map<String, String>.of(grids[s])],
      'validSlots': validSlots,
      'totalScores': List<int>.of(totalScores),
      'speciesBreakdown': speciesBreakdown,
      'over': _over,
    };
  }
}
