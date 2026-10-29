import '../../src/engine.dart';

const String cassinoRules = '''
# 卡西诺抓牌 Cassino 规则说明

## 基本配置
- **人数**：2～4 人。
- **牌堆**：标准 52 张扑克牌（无大小王）。
- **点数定义**：`A = 1`、`2..9 = 2..9`、`T(10) = 10`、`J = 11`、`Q = 12`、`K = 13`。
- **发牌流程**：开局向每位玩家发 4 张手牌，桌面翻开 4 张明牌；当所有玩家手牌打光后，从牌库继续给每人补发 4 张手牌，直至 52 张牌库发完并打光。

## 回合行动（三选一）
轮到自己时，必须从手牌打出 1 张牌，执行以下三种行动之一：
1. **抓牌（`'capture'`）**：
   - 打出点数为 `V` 的手牌，可抓走桌面上：
     - 点数同为 `V` 的散牌；
     - 合成点数为 `V` 的建造牌堆（Build Pile）；
     - 若干张点数之和等于 `V` 的桌面数字牌（`A..10`）。
   - **清台（Sweep）**：若一次抓牌后将桌面所有散牌与建造牌堆全部清空，立即获得 **+1 分清台分（Sweep）**！
2. **建堆（`'build'`）**：
   - 将打出的手牌与桌面 1 张或多张散牌合并为一个 **合成点数为 `V`（`V <= 10`）的建造牌堆**。
   - **限制条件**：你手中**必须还持有另一张点数为 `V` 的手牌**（以便后续回合抓走该牌堆），否则不允许建堆！
3. **放牌（`'trail'`）**：
   - 将 1 张手牌正面朝上放到桌面成为散牌。
   - **限制条件**：若你当前在桌面上拥有未抓走的建造牌堆（Build Pile），则 **禁止放牌（Trail）**！

## 终局计分（11 分基础分 + 清台分）
牌库发完且所有手牌打光后，桌面剩余牌归最后一次抓牌的玩家所有（不计清台），随后结算：
- **最多牌数（Most Cards）**：获得 **+3 分**（2 人局需 `>= 27` 张；多人局为唯一最多者，平局不计）。
- **最多黑桃（Most Spades, `♠`）**：获得 **+1 分**（全副牌共 13 张黑桃，唯一最多者得 1 分）。
- **大卡西诺（Big Cassino, `TD` ♦10）**：获得 **+2 分**。
- **小卡西诺（Little Cassino, `2S` ♠2）**：获得 **+1 分**。
- **每张 A（`AS, AH, AD, AC`）**：每张 **+1 分**（共 **4 分**）。
- **清台奖励（Sweeps）**：每次清台 **+1 分**。
''';

const List<String> kCassinoSuits = ['S', 'H', 'D', 'C'];
const List<String> kCassinoRanks = [
  'A',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  'T',
  'J',
  'Q',
  'K',
];

/// Builds a standard 52-card deck for Cassino.
List<String> buildCassinoDeck() => [
      for (final s in kCassinoSuits)
        for (final r in kCassinoRanks) '$r$s',
    ];

String cassinoRank(String card) =>
    card.length >= 2 ? card.substring(0, card.length - 1) : '';

String cassinoSuit(String card) =>
    card.length >= 2 ? card.substring(card.length - 1) : '';

/// Numeric value of [card] in Cassino (`A=1 .. T=10, J=11, Q=12, K=13`).
int cassinoCardValue(String card) {
  switch (cassinoRank(card)) {
    case 'A':
      return 1;
    case '2':
      return 2;
    case '3':
      return 3;
    case '4':
      return 4;
    case '5':
      return 5;
    case '6':
      return 6;
    case '7':
      return 7;
    case '8':
      return 8;
    case '9':
      return 9;
    case 'T':
      return 10;
    case 'J':
      return 11;
    case 'Q':
      return 12;
    case 'K':
      return 13;
    default:
      return 0;
  }
}

/// Checks whether [values] (all `<= 10`) can be partitioned into disjoint subsets
/// that each sum to [target].
bool canPartitionCassinoSum(List<int> values, int target) {
  if (values.isEmpty) return true;
  if (target <= 0) return false;
  for (final v in values) {
    if (v <= 0 || v > 10 || v > target) return false;
  }
  final total = values.fold<int>(0, (a, b) => a + b);
  if (total % target != 0) return false;
  final groups = total ~/ target;
  final sorted = List<int>.of(values)..sort((a, b) => b.compareTo(a));
  final used = List<bool>.filled(sorted.length, false);

  bool backtrack(int groupsRemaining, int currentSum, int startIdx) {
    if (groupsRemaining == 0) return true;
    if (currentSum == target) {
      return backtrack(groupsRemaining - 1, 0, 0);
    }
    for (var i = startIdx; i < sorted.length; i++) {
      if (used[i]) continue;
      if (currentSum + sorted[i] > target) continue;
      used[i] = true;
      if (backtrack(groupsRemaining, currentSum + sorted[i], i + 1)) {
        return true;
      }
      used[i] = false;
      if (currentSum == 0) return false;
    }
    return false;
  }

  return backtrack(groups, 0, 0);
}

/// Finds a maximal subset of [tableCards] that can be captured by a card of value [target].
List<String> findBestCassinoCaptureCards(List<String> tableCards, int target) {
  final exact = <String>[];
  final numberCards = <String>[];
  for (final c in tableCards) {
    final v = cassinoCardValue(c);
    if (v == target) {
      exact.add(c);
    } else if (v < target && v <= 10 && target <= 10) {
      numberCards.add(c);
    }
  }
  if (numberCards.isEmpty) return exact;

  // Search for largest subset of numberCards that partitions into target sums
  List<String> bestSubset = const [];
  final n = numberCards.length;
  final limit = 1 << n;
  for (var mask = 1; mask < limit; mask++) {
    final sub = <String>[];
    final vals = <int>[];
    var sum = 0;
    for (var i = 0; i < n; i++) {
      if ((mask & (1 << i)) != 0) {
        sub.add(numberCards[i]);
        final v = cassinoCardValue(numberCards[i]);
        vals.add(v);
        sum += v;
      }
    }
    if (sum % target == 0 && sub.length > bestSubset.length) {
      if (canPartitionCassinoSum(vals, target)) {
        bestSubset = sub;
      }
    }
  }
  return [...exact, ...bestSubset];
}

/// Computes end-of-deck Cassino scores (`11` base points + `sweeps`).
Map<String, dynamic> computeCassinoDeckSummary(
  List<List<String>> capturedCards,
  List<int> sweeps,
) {
  final n = capturedCards.length;
  final cardCounts = [for (var s = 0; s < n; s++) capturedCards[s].length];
  final spadeCounts = [
    for (var s = 0; s < n; s++)
      capturedCards[s].where((c) => cassinoSuit(c) == 'S').length,
  ];
  final acesCounts = [
    for (var s = 0; s < n; s++)
      capturedCards[s].where((c) => cassinoRank(c) == 'A').length,
  ];

  int? mostCardsWinner;
  final maxCards = cardCounts.fold<int>(0, (a, b) => a > b ? a : b);
  final maxCardSeats = [
    for (var s = 0; s < n; s++)
      if (cardCounts[s] == maxCards && maxCards > 0) s,
  ];
  if (n == 2) {
    for (var s = 0; s < n; s++) {
      if (cardCounts[s] >= 27) {
        mostCardsWinner = s;
        break;
      }
    }
  } else if (maxCardSeats.length == 1) {
    mostCardsWinner = maxCardSeats.first;
  }

  int? mostSpadesWinner;
  final maxSpades = spadeCounts.fold<int>(0, (a, b) => a > b ? a : b);
  final maxSpadeSeats = [
    for (var s = 0; s < n; s++)
      if (spadeCounts[s] == maxSpades && maxSpades > 0) s,
  ];
  if (maxSpadeSeats.length == 1) {
    mostSpadesWinner = maxSpadeSeats.first;
  }

  int? bigCassinoWinner;
  int? littleCassinoWinner;
  for (var s = 0; s < n; s++) {
    if (capturedCards[s].contains('TD')) bigCassinoWinner = s;
    if (capturedCards[s].contains('2S')) littleCassinoWinner = s;
  }

  final points = List<int>.filled(n, 0);
  if (mostCardsWinner != null) points[mostCardsWinner] += 3;
  if (mostSpadesWinner != null) points[mostSpadesWinner] += 1;
  if (bigCassinoWinner != null) points[bigCassinoWinner] += 2;
  if (littleCassinoWinner != null) points[littleCassinoWinner] += 1;
  for (var s = 0; s < n; s++) {
    points[s] += acesCounts[s];
    points[s] += (s < sweeps.length ? sweeps[s] : 0);
  }

  return {
    'points': points,
    'cardCounts': cardCounts,
    'spadeCounts': spadeCounts,
    'acesCounts': acesCounts,
    'sweeps': List<int>.of(sweeps),
    'mostCardsWinner': mostCardsWinner,
    'mostSpadesWinner': mostSpadesWinner,
    'bigCassinoWinner': bigCassinoWinner,
    'littleCassinoWinner': littleCassinoWinner,
  };
}

class CassinoGame extends GameEngine {
  CassinoGame(super.setup);

  late int totalRounds;
  int currentRound = 1;
  int dealer = 0;
  int turn = 0;
  String phase = 'play';

  List<String> deck = [];
  List<String> tableCards = [];
  List<Map<String, dynamic>> builds = [];
  late List<List<String>> hands;
  late List<List<String>> capturedCards;
  late List<int> sweeps;
  late List<int> scores;
  int lastCapturer = -1;
  Map<String, dynamic>? lastMove;
  Map<String, dynamic>? lastHandSummary;
  bool _over = false;

  /// Alias getter/setter for tests that access `table` directly.
  List<String> get table => tableCards;
  set table(List<String> value) => tableCards = value;

  @override
  void start() {
    totalRounds = setup.opt<int>('rounds', 1);
    scores = List.filled(players, 0);
    dealer = 0;
    _startRound();
  }

  void _startRound() {
    phase = 'play';
    deck = shuffled(buildCassinoDeck(), rng);
    hands = List.generate(players, (_) => <String>[]);
    capturedCards = List.generate(players, (_) => <String>[]);
    sweeps = List.filled(players, 0);
    builds = [];
    lastCapturer = -1;
    lastMove = null;

    for (var s = 0; s < players; s++) {
      hands[s] = deck.sublist(0, 4);
      deck.removeRange(0, 4);
    }
    tableCards = deck.sublist(0, 4);
    deck.removeRange(0, 4);

    turn = (dealer + 1) % players;
    host.log('第 $currentRound/$totalRounds 局开始，桌面初始 4 张明牌：${tableCards.join(" ")}');
  }

  bool hasActiveBuild(int seat) => builds.any((b) => asInt(b['owner']) == seat);

  @override
  bool get isOver => _over;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  List<int>? get placings => _over ? rankByScore(scores) : null;

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final rawType = asStr(action['type']);
    final mode = (rawType == 'play')
        ? asStr(action['mode'], asStr(action['action'], 'trail'))
        : rawType;
    final card = asStr(action['card']);
    if (!hands[seat].contains(card)) {
      throw GameError('你手中没有这张牌：$card');
    }

    if (mode == 'capture') {
      _handleCapture(seat, card, action);
    } else if (mode == 'build') {
      _handleBuild(seat, card, action);
    } else if (mode == 'trail') {
      _handleTrail(seat, card);
    } else {
      throw GameError('未知的操作类型：$mode');
    }

    _advanceAfterTurn();
  }

  void _handleCapture(int seat, String card, Map<String, dynamic> action) {
    final v = cassinoCardValue(card);
    final rawCards = action['cards'];
    final rawBuilds = action['builds'];

    List<String> selectedCards;
    List<int> selectedBuildIndices;

    if (rawCards == null && rawBuilds == null) {
      // Auto-select all matching builds of value v and best loose table cards
      selectedCards = findBestCassinoCaptureCards(tableCards, v);
      selectedBuildIndices = [
        for (var i = 0; i < builds.length; i++)
          if (asInt(builds[i]['value']) == v) i,
      ];
    } else {
      selectedCards = rawCards is List
          ? [for (final e in rawCards) asStr(e)]
          : <String>[];
      selectedBuildIndices = rawBuilds is List
          ? [for (final e in rawBuilds) asInt(e)]
          : <int>[];
      // If player owns a build of value v and didn't list it, auto-include it
      for (var i = 0; i < builds.length; i++) {
        if (asInt(builds[i]['owner']) == seat &&
            asInt(builds[i]['value']) == v &&
            !selectedBuildIndices.contains(i)) {
          selectedBuildIndices.add(i);
        }
      }
      // If rawBuilds was omitted but there is a build of value v and no loose cards were given
      if (rawCards == null && selectedBuildIndices.isEmpty) {
        for (var i = 0; i < builds.length; i++) {
          if (asInt(builds[i]['value']) == v) selectedBuildIndices.add(i);
        }
      }
    }

    if (selectedCards.isEmpty && selectedBuildIndices.isEmpty) {
      throw GameError('桌面上没有可用 $card（点数 $v）抓走的牌或牌堆');
    }

    // Validate selected loose cards exist on table
    final tempTable = List<String>.of(tableCards);
    for (final c in selectedCards) {
      if (!tempTable.remove(c)) {
        throw GameError('桌面上没有卡牌 $c');
      }
    }

    // Validate selected builds
    final uniqueBuildIdx = selectedBuildIndices.toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    for (final idx in uniqueBuildIdx) {
      if (idx < 0 || idx >= builds.length) {
        throw GameError('无效的建造牌堆编号');
      }
      if (asInt(builds[idx]['value']) != v) {
        throw GameError('建造牌堆点数（${builds[idx]['value']}）与出牌点数（$v）不匹配');
      }
    }

    // Validate loose cards values: each card is either == v, or part of number cards (<=10) summing to v
    final nonExactVals = <int>[];
    for (final c in selectedCards) {
      final cv = cassinoCardValue(c);
      if (cv == v) continue;
      if (cv > 10 || v > 10) {
        throw GameError('人头牌（J/Q/K）只能通过相同点数配对抓走，不能参与算术凑点');
      }
      nonExactVals.add(cv);
    }
    if (nonExactVals.isNotEmpty && !canPartitionCassinoSum(nonExactVals, v)) {
      throw GameError('所选桌面散牌点数无法凑成 $v');
    }

    // Verify any remaining builds owned by seat still have a matching value card in remaining hand
    final remainingHand = List<String>.of(hands[seat])..remove(card);
    for (var i = 0; i < builds.length; i++) {
      if (uniqueBuildIdx.contains(i)) continue;
      if (asInt(builds[i]['owner']) == seat) {
        final bv = asInt(builds[i]['value']);
        if (!remainingHand.any((hc) => cassinoCardValue(hc) == bv)) {
          throw GameError('你还拥有点数为 $bv 的建造牌堆，必须保留点数 $bv 的手牌');
        }
      }
    }

    // Perform capture
    hands[seat].remove(card);
    final gained = <String>[card];
    for (final c in selectedCards) {
      tableCards.remove(c);
      gained.add(c);
    }
    for (final idx in uniqueBuildIdx) {
      final b = builds.removeAt(idx);
      final bCards = (b['cards'] as List).map((e) => asStr(e)).toList();
      gained.addAll(bCards);
    }

    capturedCards[seat].addAll(gained);
    lastCapturer = seat;

    final isSweep = tableCards.isEmpty && builds.isEmpty;
    if (isSweep) {
      sweeps[seat]++;
      host.log('${name(seat)} 打出 $card 抓走 ${gained.length - 1} 张牌并完成【清台 Sweep】（+1分）！');
    } else {
      host.log('${name(seat)} 打出 $card 抓走 ${gained.length - 1} 张牌');
    }

    lastMove = {
      'seat': seat,
      'mode': 'capture',
      'card': card,
      'capturedCount': gained.length,
      'sweep': isSweep,
    };
  }

  void _handleBuild(int seat, String card, Map<String, dynamic> action) {
    final cv = cassinoCardValue(card);
    if (cv >= 10) {
      throw GameError('建堆手牌点数必须小于 10');
    }
    final rawCards = action['cards'];
    final selectedCards = rawCards is List
        ? [for (final e in rawCards) asStr(e)]
        : <String>[];
    if (selectedCards.isEmpty) {
      throw GameError('建堆必须至少选择 1 张桌面散牌');
    }

    final tempTable = List<String>.of(tableCards);
    var sum = cv;
    for (final c in selectedCards) {
      if (!tempTable.remove(c)) {
        throw GameError('桌面上没有散牌 $c');
      }
      final v = cassinoCardValue(c);
      if (v > 10) {
        throw GameError('人头牌（J/Q/K）不能参与建堆');
      }
      sum += v;
    }

    final targetVal = asInt(action['value'], sum);
    if (targetVal != sum || targetVal > 10) {
      throw GameError('建造牌堆合成点数不能超过 10（当前为 $sum）');
    }

    final remainingHand = List<String>.of(hands[seat])..remove(card);
    if (!remainingHand.any((hc) => cassinoCardValue(hc) == targetVal)) {
      throw GameError('手中必须持有另一张点数为 $targetVal 的牌才能建造 $targetVal 点牌堆');
    }

    // Also ensure any existing build owned by seat still has a matching card in remainingHand
    for (final b in builds) {
      if (asInt(b['owner']) == seat) {
        final bv = asInt(b['value']);
        if (!remainingHand.any((hc) => cassinoCardValue(hc) == bv)) {
          throw GameError('你还拥有点数为 $bv 的建造牌堆，不能消耗唯一对应的抓牌手牌');
        }
      }
    }

    hands[seat].remove(card);
    for (final c in selectedCards) {
      tableCards.remove(c);
    }
    builds.add({
      'value': targetVal,
      'cards': [...selectedCards, card],
      'owner': seat,
    });

    lastMove = {
      'seat': seat,
      'mode': 'build',
      'card': card,
      'value': targetVal,
    };
    host.log('${name(seat)} 打出 $card 与 ${selectedCards.join("+")} 建造了 $targetVal 点牌堆');
  }

  void _handleTrail(int seat, String card) {
    if (hasActiveBuild(seat)) {
      // Check if player actually holds a card that can capture their build
      final canCaptureOwnBuild = builds.any((b) =>
          asInt(b['owner']) == seat &&
          hands[seat].any((hc) => cassinoCardValue(hc) == asInt(b['value'])));
      if (canCaptureOwnBuild || builds.any((b) => asInt(b['owner']) == seat)) {
        throw GameError('你当前拥有桌面建造牌堆，不能放牌（Trail）');
      }
    }

    hands[seat].remove(card);
    tableCards.add(card);
    lastMove = {
      'seat': seat,
      'mode': 'trail',
      'card': card,
    };
    host.log('${name(seat)} 放牌 $card 到桌面');
  }

  void _advanceAfterTurn() {
    if (hands.every((h) => h.isEmpty)) {
      if (deck.isNotEmpty) {
        for (var s = 0; s < players; s++) {
          final count = deck.length >= 4 ? 4 : deck.length;
          if (count > 0) {
            hands[s].addAll(deck.sublist(0, count));
            deck.removeRange(0, count);
          }
        }
        turn = (turn + 1) % players;
        host.log('新一轮发牌（牌库剩余 ${deck.length} 张）');
        return;
      }
      _finishRound();
      return;
    }

    // Advance to next player who still has cards
    for (var step = 1; step <= players; step++) {
      final next = (turn + step) % players;
      if (hands[next].isNotEmpty) {
        turn = next;
        break;
      }
    }
  }

  void _finishRound() {
    // Remaining table cards and builds go to lastCapturer (no sweep)
    if (lastCapturer >= 0 && lastCapturer < players) {
      capturedCards[lastCapturer].addAll(tableCards);
      tableCards.clear();
      for (final b in builds) {
        final bCards = (b['cards'] as List).map((e) => asStr(e)).toList();
        capturedCards[lastCapturer].addAll(bCards);
      }
      builds.clear();
    } else {
      tableCards.clear();
      builds.clear();
    }

    final summary = computeCassinoDeckSummary(capturedCards, sweeps);
    final roundPts = (summary['points'] as List).cast<int>();
    for (var s = 0; s < players; s++) {
      scores[s] += roundPts[s];
    }
    lastHandSummary = {
      'round': currentRound,
      ...summary,
    };

    host.log('第 $currentRound 局结束，本局得分：${roundPts.join(" / ")}');

    if (currentRound >= totalRounds) {
      _over = true;
    } else {
      currentRound++;
      dealer = (dealer + 1) % players;
      _startRound();
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn || hands[seat].isEmpty) return null;

    // 1. If player owns an active build, prioritize capturing it or another valid capture
    for (final c in hands[seat]) {
      final v = cassinoCardValue(c);
      final capCards = findBestCassinoCaptureCards(tableCards, v);
      final capBuilds = [
        for (var i = 0; i < builds.length; i++)
          if (asInt(builds[i]['value']) == v) i,
      ];
      if (capCards.isNotEmpty || capBuilds.isNotEmpty) {
        // Check that capturing with c doesn't strand another build owned by seat
        final rem = List<String>.of(hands[seat])..remove(c);
        var strandsOwnBuild = false;
        for (var i = 0; i < builds.length; i++) {
          if (capBuilds.contains(i)) continue;
          if (asInt(builds[i]['owner']) == seat) {
            final bv = asInt(builds[i]['value']);
            if (!rem.any((hc) => cassinoCardValue(hc) == bv)) {
              strandsOwnBuild = true;
              break;
            }
          }
        }
        if (!strandsOwnBuild) {
          return {
            'type': 'play',
            'mode': 'capture',
            'card': c,
            'cards': capCards,
            'builds': capBuilds,
          };
        }
      }
    }

    // 2. Try building if possible
    if (botLevel > 0 && !hasActiveBuild(seat) && hands[seat].length >= 2) {
      for (final c in hands[seat]) {
        final cv = cassinoCardValue(c);
        if (cv >= 10) continue;
        final rem = List<String>.of(hands[seat])..remove(c);
        for (final tc in tableCards) {
          final tv = cassinoCardValue(tc);
          if (tv > 10) continue;
          final sum = cv + tv;
          if (sum <= 10 && rem.any((hc) => cassinoCardValue(hc) == sum)) {
            return {
              'type': 'play',
              'mode': 'build',
              'card': c,
              'cards': [tc],
              'value': sum,
            };
          }
        }
      }
    }

    // 3. Otherwise trail a card (prefer non-scoring low card)
    final sorted = List<String>.of(hands[seat])
      ..sort((a, b) => _trailPriority(a).compareTo(_trailPriority(b)));
    return {
      'type': 'play',
      'mode': 'trail',
      'card': sorted.first,
    };
  }

  int _trailPriority(String card) {
    if (card == 'TD') return 100;
    if (card == '2S') return 90;
    if (cassinoRank(card) == 'A') return 80;
    if (cassinoSuit(card) == 'S') return 50 + cassinoCardValue(card);
    return cassinoCardValue(card);
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myHand = (seat >= 0 && seat < players)
        ? List<String>.of(hands[seat])
        : <String>[];
    return {
      'phase': phase,
      'round': currentRound,
      'totalRounds': totalRounds,
      'dealer': dealer,
      'turn': turn,
      'deckCount': deck.length,
      'table': List<String>.of(tableCards),
      'tableCards': List<String>.of(tableCards),
      'builds': [
        for (final b in builds)
          {
            'value': b['value'],
            'cards': List<String>.from(b['cards'] as List),
            'owner': b['owner'],
          },
      ],
      'hand': myHand,
      'handCounts': [for (var s = 0; s < players; s++) hands[s].length],
      'capturedCounts': [for (var s = 0; s < players; s++) capturedCards[s].length],
      'spadeCounts': [
        for (var s = 0; s < players; s++)
          capturedCards[s].where((c) => cassinoSuit(c) == 'S').length,
      ],
      'sweeps': List<int>.of(sweeps),
      'scores': List<int>.of(scores),
      'lastCapturer': lastCapturer,
      'lastMove': lastMove,
      'lastHandSummary': lastHandSummary,
      'over': _over,
    };
  }
}
