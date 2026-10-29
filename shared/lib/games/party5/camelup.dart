import 'dart:math';

import '../../src/engine.dart';

const String camelUpRules = '''
# 骆驼大赛（Camel Up）规则说明

## 游戏概述
《骆驼大赛》是一款充满戏剧性与欢乐气氛的赛骆驼竞猜桌游，支持 2～8 名玩家。5 只不同颜色的骆驼（蓝、绿、红、黄、白）围绕赛道展开角逐，玩家通过分段下注、放置绿洲/海市蜃楼瓦片、摇动金字塔骰子以及暗投全场总冠军/垫底骆驼来赚取金币。当任意骆驼冲过终点线时游戏立即结束，金币最多的玩家获胜！

## 核心机制：骆驼叠罗汉与领先顺序
- **叠罗汉移动**：同一格上的骆驼会叠成一摞。当某只骆驼移动时，它会**背着叠在它上面的所有骆驼一起移动**，而叠在它下面的骆驼留在原地。
- **落点规则**：正常移动（或踩到绿洲前进 1 格）时，移动的骆驼摞会叠在目标格已有骆驼的**最上方**；若踩到海市蜃楼后退 1 格，则会钻入目标格已有骆驼的**最下方**。
- **名次判定**：在赛道上位置更靠前的骆驼名次更高；位于同一格时，叠在**越上方**的骆驼名次越高（最顶层为领先，最底层为落后）。

## 分段（Leg）与金字塔
- 金字塔内共有 5 颗彩色骰子（对应 5 只骆驼），每颗骰子的点数为 **1、2、3**。
- 每次选择“摇金字塔”会随机摇出 1 颗本分段尚未摇出的骆驼骰子，使对应骆驼前进 1～3 步。
- 当金字塔内的 **5 颗骰子全部被摇出**时，当前分段结束并进行分段结算，随后将 5 颗骰子放回金字塔、重置分段下注牌并收回沙漠瓦片，开始下一分段。

## 玩家回合（4 选 1 行动）
轮到自己时，必须从以下 4 项行动中选择 1 项执行：
- **摇金字塔（Roll）**：领取 1 张金字塔票据（立即获得 **+1 金币**），并从金字塔中随机摇出 1 颗未摇出的骆驼骰子。
- **分段下注（Leg Bet）**：拿取某只骆驼当前最顶层的分段下注板块（按先来后到依次为 **5 / 3 / 2** 金币）。分段结束时：
  - 若该骆驼排在**第 1 名**，获得板块所示金币（5 / 3 / 2）；
  - 若该骆驼排在**第 2 名**，固定获得 **+1 金币**；
  - 若该骆驼排在**第 3～5 名**，扣除 **1 金币**（金币最少扣至 0）。
- **放置/移动沙漠瓦片（Desert Tile）**：将自己的个人瓦片以**绿洲（+1 步，叠到目标格最上方）**或**海市蜃楼（-1 步，钻到目标格最下方）**面朝上放置或移动到赛道上的任意空格（不能放在起点第 0 格、不能放在有骆驼的格子、不能与其他玩家的沙漠瓦片相邻）。每当有骆驼停留在你的瓦片上，你立即获得 **+1 金币**！
- **全场总下注（Race Bet）**：从手牌中暗出一张尚未押注的骆驼牌，秘密押注其为**全场总冠军（Win）**或**全场垫底（Lose）**。游戏结束时按押注先后顺序结算：猜对者依次获得 **8 / 5 / 3 / 2 / 1** 金币，猜错者每张扣 **1 金币**（最少至 0）。

## 游戏结束与房间选项
- 一旦有骆驼跨过终点格（标准模式 >= 16 格，快速模式 >= 12 格），游戏**立即结束**，先结算当前分段下注，再结算全场总冠军与全场垫底下注，总金币最高者获胜。
- **赛道长度选项**：可选 16 格（标准模式）或 12 格（快速模式）。
''';

class CamelUp extends GameEngine {
  CamelUp(super.setup);

  static const int kCamelCount = 5;
  static const List<String> kCamelNames = ['蓝', '绿', '红', '黄', '白'];
  static const List<int> kLegBetValues = [5, 3, 2];
  static const List<int> kRacePayouts = [8, 5, 3, 2, 1];

  late int trackLen;
  int leg = 1;
  int turn = 0;
  bool _over = false;

  /// Player coins (starts at 3 each, never drops below 0).
  late List<int> coins;

  /// Pyramid tickets taken in the current leg by each player.
  late List<int> pyramidTickets;

  /// Camel stacks per track position: pos -> [bottomCamel, ..., topCamel].
  final Map<int, List<int>> stacks = {};

  /// Desert tiles on the track: space -> {'owner': seat, 'dir': 1 (oasis) or -1 (mirage)}.
  final Map<int, Map<String, int>> desertTiles = {};

  /// Unrolled camel colors in the pyramid for the current leg.
  List<int> unrolledCamels = [];

  /// Dice rolled so far in the current leg: [{'camel': c, 'steps': s, 'seat': seat}].
  final List<Map<String, int>> rolledHistory = [];

  /// Available leg-betting tiles per camel color (starts each leg with [5, 3, 2]).
  late List<List<int>> legBetTiles;

  /// Leg bets taken by each player in the current leg: seat -> [{'camel': c, 'payout': p}].
  late List<List<Map<String, int>>> playerLegBets;

  /// Remaining race-betting camel cards in each player's hand (starts with [0, 1, 2, 3, 4]).
  late List<List<int>> raceHand;

  /// Secret overall Race Winner bets in placement order: [{'seat': s, 'camel': c}].
  final List<Map<String, int>> winBets = [];

  /// Secret overall Race Loser bets in placement order: [{'seat': s, 'camel': c}].
  final List<Map<String, int>> loseBets = [];

  /// Latest action/event summary.
  String lastEvent = '';

  /// Last leg settlement summary for UI display.
  Map<String, dynamic>? lastLegSummary;

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _over ? rankByScore(coins) : null;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  void start() {
    trackLen = setup.opt<int>('trackLen', 16);
    coins = List.filled(players, 3);
    pyramidTickets = List.filled(players, 0);
    raceHand = [
      for (var s = 0; s < players; s++) [0, 1, 2, 3, 4],
    ];
    stacks.clear();
    desertTiles.clear();
    winBets.clear();
    loseBets.clear();

    // Initial camel placement: roll all 5 camels onto spaces 0..2
    final initOrder = shuffled([0, 1, 2, 3, 4], rng);
    for (final c in initOrder) {
      final pos = rng.nextInt(3); // 0, 1, or 2
      stacks.putIfAbsent(pos, () => []).add(c);
    }

    _resetLegState();
    lastEvent = '骆驼大赛开始！5 只骆驼已在起点就位。';
    host.log(lastEvent);
  }

  void _resetLegState() {
    unrolledCamels = [0, 1, 2, 3, 4];
    rolledHistory.clear();
    pyramidTickets = List.filled(players, 0);
    legBetTiles = [
      for (var c = 0; c < kCamelCount; c++) List<int>.of(kLegBetValues),
    ];
    playerLegBets = [for (var s = 0; s < players; s++) <Map<String, int>>[]];
    desertTiles.clear();
  }

  /// Returns the current track position of [camel].
  int camelPos(int camel) {
    for (final e in stacks.entries) {
      if (e.value.contains(camel)) return e.key;
    }
    return 0;
  }

  /// Returns all 5 camels ordered from 1st place (index 0) to 5th place (index 4).
  /// Further space is ahead; on the same space, higher in stack is ahead.
  List<int> get camelRanking {
    final positions = stacks.keys.toList()..sort((a, b) => b.compareTo(a));
    final order = <int>[];
    for (final pos in positions) {
      final st = stacks[pos]!;
      for (var i = st.length - 1; i >= 0; i--) {
        order.add(st[i]);
      }
    }
    return order;
  }

  /// Moves [camel] and all camels stacked on top of it by [steps] (1..3).
  /// Applies any desert tile at the destination space.
  void moveCamel(int camel, int steps) {
    final p0 = camelPos(camel);
    final stack0 = stacks[p0]!;
    final idx = stack0.indexOf(camel);
    final moving = stack0.sublist(idx);
    stack0.removeRange(idx, stack0.length);
    if (stack0.isEmpty) stacks.remove(p0);

    var p1 = p0 + steps;
    String desertMsg = '';
    if (p1 < trackLen && desertTiles.containsKey(p1)) {
      final tile = desertTiles[p1]!;
      final owner = tile['owner']!;
      final dir = tile['dir']!;
      coins[owner] += 1;
      if (dir == 1) {
        p1 = p1 + 1;
        stacks.putIfAbsent(p1, () => []).addAll(moving);
        desertMsg = '（踩中 ${name(owner)} 的绿洲 +1 步，${name(owner)} +1 金币）';
      } else {
        p1 = max(0, p1 - 1);
        stacks.putIfAbsent(p1, () => []).insertAll(0, moving);
        desertMsg = '（踩中 ${name(owner)} 的海市蜃楼 -1 步垫底，${name(owner)} +1 金币）';
      }
    } else {
      stacks.putIfAbsent(p1, () => []).addAll(moving);
    }

    final carriedNames = moving.map((c) => '${kCamelNames[c]}驼').join('+');
    lastEvent = '${kCamelNames[camel]}驼摇出 $steps 步：$carriedNames 移至第 $p1 格$desertMsg';
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    switch (type) {
      case 'roll':
        _handleRoll(seat);
      case 'leg_bet':
        _handleLegBet(seat, action);
      case 'desert':
        _handleDesert(seat, action);
      case 'race_bet':
        _handleRaceBet(seat, action);
      default:
        throw GameError('未知行动类型：$type');
    }

    if (!_over) {
      turn = (turn + 1) % players;
    }
  }

  void _handleRoll(int seat) {
    if (unrolledCamels.isEmpty) throw GameError('金字塔内已无骰子');
    coins[seat] += 1;
    pyramidTickets[seat] += 1;

    final pickIdx = rng.nextInt(unrolledCamels.length);
    final camel = unrolledCamels.removeAt(pickIdx);
    final steps = 1 + rng.nextInt(3);
    rolledHistory.add({'camel': camel, 'steps': steps, 'seat': seat});

    moveCamel(camel, steps);
    lastEvent = '${name(seat)} 摇金字塔（+1 金币）：$lastEvent';
    host.log(lastEvent);

    final newPos = camelPos(camel);
    if (newPos >= trackLen) {
      _settleLegBets();
      _settleRaceBetsAndFinish();
      return;
    }

    if (unrolledCamels.isEmpty) {
      _settleLegBets();
      leg++;
      _resetLegState();
      host.log('第 ${leg - 1} 分段结算完成，进入第 $leg 分段！');
    }
  }

  void _handleLegBet(int seat, Map<String, dynamic> action) {
    final camel = asInt(action['camel']);
    if (camel < 0 || camel >= kCamelCount) throw GameError('无效的骆驼颜色');
    if (legBetTiles[camel].isEmpty) throw GameError('${kCamelNames[camel]}驼的分段下注牌已拿完');

    final payout = legBetTiles[camel].removeAt(0);
    playerLegBets[seat].add({'camel': camel, 'payout': payout});
    lastEvent = '${name(seat)} 拿取了【${kCamelNames[camel]}驼】分段下注牌（头名奖 $payout 金币）。';
    host.log(lastEvent);
  }

  void _handleDesert(int seat, Map<String, dynamic> action) {
    final space = asInt(action['space']);
    final dir = (action['dir'] == -1 || action['side'] == 'mirage' || action['oasis'] == false) ? -1 : 1;

    if (space < 1 || space >= trackLen) {
      throw GameError('沙漠瓦片只能放在第 1～${trackLen - 1} 格');
    }
    if (stacks[space] != null && stacks[space]!.isNotEmpty) {
      throw GameError('第 $space 格上有骆驼，不能放置沙漠瓦片');
    }
    for (final e in desertTiles.entries) {
      final otherOwner = e.value['owner']!;
      if (otherOwner != seat && (e.key - space).abs() <= 1) {
        throw GameError('不能放在其他玩家沙漠瓦片上或相邻格');
      }
    }

    int? oldSpace;
    for (final e in desertTiles.entries) {
      if (e.value['owner'] == seat) {
        oldSpace = e.key;
        break;
      }
    }
    if (oldSpace == space && desertTiles[space]!['dir'] == dir) {
      throw GameError('你的瓦片已经在该位置');
    }
    if (oldSpace != null) {
      desertTiles.remove(oldSpace);
    }
    desertTiles[space] = {'owner': seat, 'dir': dir};
    final kindName = dir == 1 ? '绿洲（+1 步）' : '海市蜃楼（-1 步）';
    lastEvent = '${name(seat)} 在第 $space 格放置了【$kindName】瓦片。';
    host.log(lastEvent);
  }

  void _handleRaceBet(int seat, Map<String, dynamic> action) {
    final camel = asInt(action['camel']);
    final betKind = asStr(action['bet'], asStr(action['kind']));
    if (camel < 0 || camel >= kCamelCount) throw GameError('无效的骆驼颜色');
    if (betKind != 'win' && betKind != 'lose') throw GameError('请选择押注总冠军（win）或垫底（lose）');
    if (!raceHand[seat].contains(camel)) throw GameError('你已经押出过这张骆驼牌了');

    raceHand[seat].remove(camel);
    if (betKind == 'win') {
      winBets.add({'seat': seat, 'camel': camel});
      lastEvent = '${name(seat)} 暗投了一张【全场总冠军】竞猜牌。';
    } else {
      loseBets.add({'seat': seat, 'camel': camel});
      lastEvent = '${name(seat)} 暗投了一张【全场垫底】竞猜牌。';
    }
    host.log(lastEvent);
  }

  void _settleLegBets() {
    final rank = camelRanking;
    final first = rank[0];
    final second = rank[1];
    final deltas = List.filled(players, 0);

    for (var s = 0; s < players; s++) {
      for (final bet in playerLegBets[s]) {
        final c = bet['camel']!;
        final p = bet['payout']!;
        if (c == first) {
          coins[s] += p;
          deltas[s] += p;
        } else if (c == second) {
          coins[s] += 1;
          deltas[s] += 1;
        } else {
          final loss = coins[s] > 0 ? 1 : 0;
          coins[s] = max(0, coins[s] - 1);
          deltas[s] -= loss;
        }
      }
    }

    lastLegSummary = {
      'leg': leg,
      'first': first,
      'second': second,
      'ranking': rank,
      'deltas': deltas,
    };
  }

  void _settleRaceBetsAndFinish() {
    final rank = camelRanking;
    final winnerCamel = rank.first;
    final loserCamel = rank.last;

    var winRightIdx = 0;
    for (final b in winBets) {
      final s = b['seat']!;
      final c = b['camel']!;
      if (c == winnerCamel) {
        final reward = kRacePayouts[min(winRightIdx, kRacePayouts.length - 1)];
        coins[s] += reward;
        winRightIdx++;
      } else {
        coins[s] = max(0, coins[s] - 1);
      }
    }

    var loseRightIdx = 0;
    for (final b in loseBets) {
      final s = b['seat']!;
      final c = b['camel']!;
      if (c == loserCamel) {
        final reward = kRacePayouts[min(loseRightIdx, kRacePayouts.length - 1)];
        coins[s] += reward;
        loseRightIdx++;
      } else {
        coins[s] = max(0, coins[s] - 1);
      }
    }

    _over = true;
    final pRanks = placings!;
    final champNames = [
      for (var s = 0; s < players; s++)
        if (pRanks[s] == 1) '${name(s)}(${coins[s]}🪙)',
    ];
    lastEvent =
        '${kCamelNames[winnerCamel]}驼冲线夺冠，${kCamelNames[loserCamel]}驼垫底！总冠军玩家：${champNames.join('、')}';
    host.log(lastEvent);
  }

  /// Checks if [seat] can legally place a desert tile on [space].
  bool canPlaceDesert(int seat, int space) {
    if (space < 1 || space >= trackLen) return false;
    if (stacks[space] != null && stacks[space]!.isNotEmpty) return false;
    for (final e in desertTiles.entries) {
      if (e.value['owner'] != seat && (e.key - space).abs() <= 1) return false;
    }
    return true;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    final rank = camelRanking;
    final leadCamel = rank.first;
    final secondCamel = rank[1];
    final lastCamel = rank.last;
    final leadPos = camelPos(leadCamel);

    // Easy bot: mostly rolls or takes top leg bet
    if (botLevel == 0) {
      if (legBetTiles[leadCamel].isNotEmpty && rng.nextDouble() < 0.45) {
        return {'type': 'leg_bet', 'camel': leadCamel};
      }
      return {'type': 'roll'};
    }

    // 1. Late in the race (leadPos >= trackLen - 5), consider placing a high-value Race Bet
    if (leadPos >= trackLen - 6) {
      if (raceHand[seat].contains(leadCamel) && winBets.length < 3) {
        return {'type': 'race_bet', 'camel': leadCamel, 'bet': 'win'};
      }
      if (raceHand[seat].contains(lastCamel) && loseBets.length < 3 && camelPos(lastCamel) <= 4) {
        return {'type': 'race_bet', 'camel': lastCamel, 'bet': 'lose'};
      }
    }

    // 2. If the leading camel (or second camel) has a 5 or 3 leg bet tile available, grab it!
    if (legBetTiles[leadCamel].isNotEmpty && legBetTiles[leadCamel].first >= 3) {
      return {'type': 'leg_bet', 'camel': leadCamel};
    }
    if (botLevel == 2 &&
        unrolledCamels.contains(secondCamel) &&
        !unrolledCamels.contains(leadCamel) &&
        legBetTiles[secondCamel].isNotEmpty &&
        legBetTiles[secondCamel].first == 5) {
      return {'type': 'leg_bet', 'camel': secondCamel};
    }

    // 3. Place personal desert tile once per leg right in front of the main pack if not placed yet
    final alreadyHasDesert = desertTiles.values.any((t) => t['owner'] == seat);
    if (!alreadyHasDesert && unrolledCamels.length >= 2) {
      // Find a legal space 1..3 steps ahead of an unrolled camel
      for (final c in unrolledCamels) {
        final p = camelPos(c);
        for (final delta in const [2, 1, 3]) {
          final target = p + delta;
          if (canPlaceDesert(seat, target)) {
            return {'type': 'desert', 'space': target, 'dir': 1};
          }
        }
      }
    }

    // 4. Otherwise, take the 2-coin leg bet on the leader if it has already rolled or is far ahead
    if (legBetTiles[leadCamel].isNotEmpty && !unrolledCamels.contains(leadCamel)) {
      return {'type': 'leg_bet', 'camel': leadCamel};
    }

    // 5. Default: Roll the pyramid for a guaranteed +1 coin and advance the race
    return {'type': 'roll'};
  }

  @override
  Map<String, dynamic> view(int seat) {
    // Serialize stacks as Map<String, List<int>> for JSON compatibility
    final stacksJson = <String, List<int>>{
      for (final e in stacks.entries)
        if (e.value.isNotEmpty) '${e.key}': List<int>.of(e.value),
    };
    final desertJson = <String, Map<String, dynamic>>{
      for (final e in desertTiles.entries)
        '${e.key}': {
          'owner': e.value['owner'],
          'ownerName': name(e.value['owner']!),
          'dir': e.value['dir'],
        },
    };

    return {
      'trackLen': trackLen,
      'leg': leg,
      'turn': turn,
      'over': _over,
      'coins': List<int>.of(coins),
      'pyramidTickets': List<int>.of(pyramidTickets),
      'stacks': stacksJson,
      'camelPos': [for (var c = 0; c < kCamelCount; c++) camelPos(c)],
      'camelRanking': camelRanking,
      'desertTiles': desertJson,
      'unrolledCount': unrolledCamels.length,
      'unrolledCamels': List<int>.of(unrolledCamels),
      'rolledHistory': [for (final r in rolledHistory) Map<String, int>.of(r)],
      'legBetTiles': [for (final l in legBetTiles) List<int>.of(l)],
      'playerLegBets': [
        for (final pb in playerLegBets) [for (final b in pb) Map<String, int>.of(b)],
      ],
      'myRaceHand': seat >= 0 && seat < players ? List<int>.of(raceHand[seat]) : const <int>[],
      'winBetsCount': winBets.length,
      'loseBetsCount': loseBets.length,
      // Only reveal race bet camel colors to the owner during the game, or to everyone when game is over
      'winBets': [
        for (final b in winBets)
          {
            'seat': b['seat'],
            'camel': (_over || b['seat'] == seat) ? b['camel'] : -1,
          },
      ],
      'loseBets': [
        for (final b in loseBets)
          {
            'seat': b['seat'],
            'camel': (_over || b['seat'] == seat) ? b['camel'] : -1,
          },
      ],
      'lastEvent': lastEvent,
      'lastLegSummary': lastLegSummary,
      'waitingFor': waitingFor,
      if (_over) 'placings': placings,
    };
  }
}
