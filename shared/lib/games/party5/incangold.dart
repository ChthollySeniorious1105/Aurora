import 'dart:math';

import '../../src/engine.dart';

const String incanGoldRules = '''
# 印加宝藏（Incan Gold / 钻石）规则说明

## 游戏概述
《印加宝藏》是一款经典的胆量考验（Push-your-luck）桌面游戏，支持 3～8 名玩家。游戏共进行 5 轮（快速模式为 3 轮）神庙探险。每位探险家需要在财富的诱惑与神庙坍塌的危险之间做出抉择，最终在营地帐篷中积累最多宝石的玩家获胜。

## 牌库构成
- **宝石牌（12 张）**：面值分别为 1、2、3、4、5、7、9、11、13、14、15、17。
- **灾难牌（15 张）**：共 5 种灾难（毒蛇、蜘蛛、木乃伊、落石、火焰），每种各 3 张。
- **神器牌（5 张）**：前 3 张被发现的神器每张价值 5 宝石，第 4、5 张神器每张价值 10 宝石。

## 每轮探险流程
- 每轮开始时，所有玩家一同进入神庙，并翻开第一张神庙路径牌。
- 在每个探险步骤中，所有仍在神庙内的玩家**同时秘密选择**：
  - **继续前进（Go）**：留在神庙中，迎接下一张未知卡牌。
  - **返回营地（Leave）**：带着本轮口袋中的宝石撤回安全营地。
- **结算返回营地的玩家**：
  - 所有在同一回合选择返回营地的玩家，**平分**当前路径上所有剩余的零散宝石（除不尽的余数继续留在路径上）。
  - **神器独占规则**：如果本回合**只有恰好 1 名玩家**独自选择返回营地，该玩家还将独吞路径上所有已翻出的神器牌（直接折算为对应宝石收入营地）！如果有 2 名或更多玩家同时返回，谁也无法拿走神器。
  - 返回营地的玩家将本轮口袋中的宝石与路上分得的宝石、神器一并锁入营地宝箱，本轮不再行动，但这些宝石在之后绝对安全。
- **结算继续前进的玩家**：
  - 若所有人都返回了营地，本轮立即安全结束，路径上未被带走的神器将被移出游戏。
  - 若至少有 1 名玩家选择继续前进，则翻开牌库顶的下一张牌：
    - **宝石牌**：牌面宝石数由当前仍在神庙内的探险家**平分**并放入各自本轮口袋；除不尽的余数留在路径上。
    - **神器牌**：放置在路径上，本身在翻出时不分给任何人，只有之后某回合**独自一人返回营地**的玩家才能带走它。
    - **灾难牌**：如果这是本轮翻出的**第 1 张**该类型灾难，仅作为警告留在路径上；如果本轮翻出了**第 2 张相同类型**的灾难牌，神庙立即坍塌！所有仍在神庙内的玩家失去本轮口袋里的所有宝石，空手逃回营地；触发坍塌的那张灾难牌（以及路径上未被带走的神器）永久移出牌库，本轮结束。

## 胜负判定与房间选项
- 完成全部轮数后，营地宝箱中总宝石数最多的玩家获胜（若平手则获得神器多者排名靠前，仍平手则共享名次）。
- **轮数选项**：可选 5 轮（标准模式）或 3 轮（快速模式）。
''';

class IncanGold extends GameEngine {
  IncanGold(super.setup);

  static const List<int> kTreasureValues = [1, 2, 3, 4, 5, 7, 9, 11, 13, 14, 15, 17];
  static const List<String> kHazardTypes = ['snake', 'spider', 'mummy', 'rock', 'fire'];
  static const Map<String, String> kHazardNames = {
    'snake': '毒蛇',
    'spider': '蜘蛛',
    'mummy': '木乃伊',
    'rock': '落石',
    'fire': '火焰',
  };

  late int totalRounds;
  int round = 0;
  int step = 0;
  bool _over = false;

  /// Permanent safe gems in each player's camp tent/chest.
  late List<int> chest;

  /// Gems collected in the current round's pocket (lost if temple collapses).
  late List<int> pocket;

  /// Number of artifacts claimed by each player across the game.
  late List<int> artifactsClaimed;

  /// Whether each player is currently inside the temple this round.
  late List<bool> inTemple;

  /// Remaining copies of each hazard type in the game (starts at 3 each).
  final Map<String, int> hazardCopies = {for (final h in kHazardTypes) h: 3};

  /// Number of unrevealed artifacts still in the deck pool (starts at 5).
  int unrevealedArtifacts = 5;

  /// Total number of artifacts revealed so far across the game (1st..3rd = 5, 4th..5th = 10).
  int artifactsRevealedCount = 0;

  /// Current round's shuffled deck.
  List<Map<String, dynamic>> deck = [];

  /// Cards revealed on the temple path in the current round.
  List<Map<String, dynamic>> pathCards = [];

  /// Remainder gems sitting on the temple path in the current round.
  int pathGems = 0;

  /// Values of unclaimed artifacts currently sitting on the temple path.
  List<int> pathArtifacts = [];

  /// Count of each hazard type currently on the path in this round.
  Map<String, int> roundHazards = {};

  /// Simultaneous choices for the current step: seat -> 'go' | 'leave'.
  final Map<int, String> choices = {};

  /// Last step's choices for UI display: seat -> 'go' | 'leave'.
  Map<int, String> lastChoices = {};

  /// History of completed rounds for UI summary.
  final List<Map<String, dynamic>> roundHistory = [];

  /// Latest event description for status banner.
  String lastEvent = '';

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings {
    if (!_over) return null;
    // Rank primarily by chest gems, with artifactsClaimed as tie-breaker
    final composite = [
      for (var i = 0; i < players; i++) chest[i] * 100 + artifactsClaimed[i],
    ];
    return rankByScore(composite);
  }

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    return [
      for (var s = 0; s < players; s++)
        if (inTemple[s] && !choices.containsKey(s)) s,
    ];
  }

  @override
  void start() {
    totalRounds = setup.opt<int>('rounds', 5);
    chest = List.filled(players, 0);
    pocket = List.filled(players, 0);
    artifactsClaimed = List.filled(players, 0);
    inTemple = List.filled(players, true);
    _startNextRound();
  }

  void _startNextRound() {
    if (round >= totalRounds) {
      _finishGame();
      return;
    }
    round++;
    step = 1;
    inTemple = List.filled(players, true);
    pocket = List.filled(players, 0);
    pathCards = [];
    pathGems = 0;
    pathArtifacts = [];
    roundHazards = {for (final h in kHazardTypes) h: 0};
    choices.clear();
    lastChoices = {};

    // Build and shuffle deck for this round
    final rawDeck = <Map<String, dynamic>>[
      for (final v in kTreasureValues) {'kind': 'treasure', 'value': v},
      for (final h in kHazardTypes)
        for (var i = 0; i < (hazardCopies[h] ?? 0); i++)
          {'kind': 'hazard', 'hazard': h, 'name': kHazardNames[h]!},
      for (var i = 0; i < unrevealedArtifacts; i++) {'kind': 'artifact'},
    ];
    deck = shuffled(rawDeck, rng);

    host.log('第 $round / $totalRounds 轮神庙探险开始！');
    _flipCard(initialFlip: true);
  }

  void _flipCard({bool initialFlip = false}) {
    if (deck.isEmpty) {
      // Extremely rare: all cards drawn without a 2nd hazard; everyone banks their pocket
      for (var s = 0; s < players; s++) {
        if (inTemple[s]) {
          chest[s] += pocket[s];
          pocket[s] = 0;
          inTemple[s] = false;
        }
      }
      lastEvent = '第 $round 轮神庙深处已探索殆尽，探险家全部安全返回！';
      host.log(lastEvent);
      roundHistory.add({
        'round': round,
        'collapsed': false,
        'hazard': null,
        'cardsCount': pathCards.length,
        'summary': lastEvent,
      });
      _startNextRound();
      return;
    }

    var card = Map<String, dynamic>.of(deck.removeLast());
    // Note: on the very first card of a round, a collapse is impossible anyway.
    final activeExplorers = [for (var s = 0; s < players; s++) if (inTemple[s]) s];
    final count = activeExplorers.length;
    final kind = card['kind'] as String;

    if (kind == 'treasure') {
      final val = card['value'] as int;
      final share = count > 0 ? val ~/ count : 0;
      final rem = count > 0 ? val % count : val;
      for (final s in activeExplorers) {
        pocket[s] += share;
      }
      pathGems += rem;
      card['share'] = share;
      card['rem'] = rem;
      pathCards.add(card);
      lastEvent = '翻出宝石牌【$val】：在场 $count 人各得 $share 颗，路径留下 $rem 颗（路径共 $pathGems 颗）。';
      host.log(lastEvent);
    } else if (kind == 'artifact') {
      unrevealedArtifacts = max(0, unrevealedArtifacts - 1);
      artifactsRevealedCount++;
      final val = artifactsRevealedCount <= 3 ? 5 : 10;
      card['value'] = val;
      card['artifactIndex'] = artifactsRevealedCount;
      pathArtifacts.add(val);
      pathCards.add(card);
      lastEvent = '翻出第 $artifactsRevealedCount 件印加神器（价值 $val 宝石）！独自返回营地者可将其带走。';
      host.log(lastEvent);
    } else if (kind == 'hazard') {
      final h = card['hazard'] as String;
      final hName = kHazardNames[h] ?? h;
      final seen = (roundHazards[h] ?? 0) + 1;
      roundHazards[h] = seen;
      card['seen'] = seen;
      pathCards.add(card);

      if (seen >= 2) {
        // Temple collapses!
        hazardCopies[h] = max(0, (hazardCopies[h] ?? 3) - 1);
        for (final s in activeExplorers) {
          pocket[s] = 0;
          inTemple[s] = false;
        }
        final collapseMsg = '第 $round 轮翻出第 2 张【$hName】！神庙坍塌，未撤离的探险家失去本轮口袋宝石！';
        lastEvent = collapseMsg;
        host.log(collapseMsg);
        roundHistory.add({
          'round': round,
          'collapsed': true,
          'hazard': h,
          'hazardName': hName,
          'cardsCount': pathCards.length,
          'summary': collapseMsg,
        });
        _startNextRound();
        return;
      } else {
        lastEvent = '翻出灾难警告【$hName】（第 1 张）！若再翻出【$hName】神庙将坍塌。';
        host.log(lastEvent);
      }
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat < 0 || seat >= players) throw GameError('无效座位');
    if (!inTemple[seat]) throw GameError('你本轮已返回营地');
    if (choices.containsKey(seat)) throw GameError('你本回合已做出选择');

    final rawType = asStr(action['type']);
    final choice = (rawType == 'go' || rawType == 'leave')
        ? rawType
        : asStr(action['choice'] ?? action['action']);
    if (choice != 'go' && choice != 'leave') {
      throw GameError('请选择继续前进（go）或返回营地（leave）');
    }

    choices[seat] = choice;

    if (waitingFor.isEmpty) {
      _resolveStep();
    }
  }

  void _resolveStep() {
    final leavers = <int>[];
    final goers = <int>[];
    for (var s = 0; s < players; s++) {
      if (!inTemple[s]) continue;
      if (choices[s] == 'leave') {
        leavers.add(s);
      } else {
        goers.add(s);
      }
    }
    lastChoices = Map<int, String>.of(choices);
    choices.clear();

    if (leavers.isNotEmpty) {
      final pathShare = pathGems ~/ leavers.length;
      pathGems = pathGems % leavers.length;
      var artifactBonus = 0;
      var artifactCount = 0;
      if (leavers.length == 1 && pathArtifacts.isNotEmpty) {
        artifactBonus = pathArtifacts.fold<int>(0, (a, b) => a + b);
        artifactCount = pathArtifacts.length;
        pathArtifacts.clear();
      }
      for (final s in leavers) {
        final totalGain = pocket[s] + pathShare + artifactBonus;
        chest[s] += totalGain;
        pocket[s] = 0;
        inTemple[s] = false;
        if (artifactCount > 0) {
          artifactsClaimed[s] += artifactCount;
        }
      }
      final namesStr = leavers.map(name).join('、');
      if (leavers.length == 1 && artifactBonus > 0) {
        host.log('$namesStr 独自返回营地，分得路径宝石 $pathShare 颗并独吞神器（+$artifactBonus 宝石）！');
      } else {
        host.log('$namesStr 返回营地（路径平分各得 $pathShare 颗宝石）。');
      }
    }

    if (goers.isEmpty) {
      final endMsg = '第 $round 轮全员安全返回营地！';
      lastEvent = endMsg;
      host.log(endMsg);
      roundHistory.add({
        'round': round,
        'collapsed': false,
        'hazard': null,
        'cardsCount': pathCards.length,
        'summary': endMsg,
      });
      _startNextRound();
      return;
    }

    step++;
    _flipCard();
  }

  void _finishGame() {
    _over = true;
    final ranks = placings!;
    final winners = [
      for (var s = 0; s < players; s++)
        if (ranks[s] == 1) '${name(s)}(${chest[s]}💎)',
    ];
    lastEvent = '探险结束！获胜者：${winners.join('、')}';
    host.log(lastEvent);
  }

  /// Calculates the exact probability that the next card in the deck causes a collapse,
  /// based only on publicly visible information (revealed hazards this round + removed hazards).
  double collapseRisk() {
    if (deck.isEmpty) return 0.0;
    var dangerCards = 0;
    for (final h in kHazardTypes) {
      if ((roundHazards[h] ?? 0) == 1) {
        // 1 copy is on the path, so remaining copies of h in deck are (hazardCopies[h] - 1)
        dangerCards += max(0, (hazardCopies[h] ?? 3) - 1);
      }
    }
    return dangerCards / deck.length;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (!waitingFor.contains(seat)) return null;

    final risk = collapseRisk();
    final myPocket = pocket[seat];
    final activeCount = inTemple.where((b) => b).length;
    final artifactSum = pathArtifacts.fold<int>(0, (a, b) => a + b);

    // If there is zero risk of collapsing on the next card:
    if (risk <= 0.0) {
      // Only consider leaving if there's an artifact + big path gems and very few explorers
      if (artifactSum >= 10 && pathGems >= 4 && activeCount <= 2 && rng.nextDouble() < 0.35) {
        return {'type': 'leave'};
      }
      return {'type': 'go'};
    }

    // If we have nothing in pocket and nothing worth grabbing on path, always go
    final soloLeaveGain = pathGems + artifactSum;
    if (myPocket == 0 && soloLeaveGain == 0) {
      return {'type': 'go'};
    }

    if (botLevel == 0) {
      // Easy bot: simple threshold with randomness
      final leaveProb = (risk * 1.4 + myPocket / 30.0).clamp(0.05, 0.9);
      return {'type': rng.nextDouble() < leaveProb ? 'leave' : 'go'};
    }

    // Expected treasure value on next card (~8.6 average treasure card)
    final expectedNextShare = 8.6 / max(1, activeCount);
    // Estimate chance of leaving alone if we leave now
    final soloFactor = activeCount == 1 ? 1.0 : (1.0 / activeCount);
    final expectedLeaveBonus = (pathGems / max(1.0, activeCount * 0.45)) + artifactSum * soloFactor;

    final totalAtStake = myPocket + expectedLeaveBonus;
    final evGo = (1.0 - risk) * expectedNextShare - risk * totalAtStake;

    if (botLevel == 2) {
      // Hard bot: strictly evaluates EV + endgame lead protection
      if (evGo < -0.2 || (myPocket >= 12 && risk >= 0.22) || (artifactSum > 0 && activeCount <= 2 && myPocket >= 4)) {
        return {'type': 'leave'};
      }
      return {'type': 'go'};
    }

    // Normal bot
    if (evGo < -0.5 || (myPocket >= 10 && risk >= 0.25)) {
      return {'type': 'leave'};
    }
    return {'type': 'go'};
  }

  @override
  Map<String, dynamic> view(int seat) {
    final activeCount = inTemple.where((b) => b).length;
    var dangerCards = 0;
    for (final h in kHazardTypes) {
      if ((roundHazards[h] ?? 0) == 1) {
        dangerCards += max(0, (hazardCopies[h] ?? 3) - 1);
      }
    }
    return {
      'round': round,
      'totalRounds': totalRounds,
      'step': step,
      'over': _over,
      'chest': List<int>.of(chest),
      'pocket': List<int>.of(pocket),
      'artifactsClaimed': List<int>.of(artifactsClaimed),
      'inTemple': List<bool>.of(inTemple),
      'activeCount': activeCount,
      'deckCount': deck.length,
      'dangerCards': dangerCards,
      'riskPercent': deck.isEmpty ? 0 : ((dangerCards * 100) / deck.length).round(),
      'pathCards': [for (final c in pathCards) Map<String, dynamic>.of(c)],
      'pathGems': pathGems,
      'pathArtifacts': List<int>.of(pathArtifacts),
      'roundHazards': Map<String, int>.of(roundHazards),
      'hazardCopies': Map<String, int>.of(hazardCopies),
      'unrevealedArtifacts': unrevealedArtifacts,
      'hasChosen': [for (var s = 0; s < players; s++) choices.containsKey(s)],
      'myChoice': seat >= 0 && seat < players ? choices[seat] : null,
      'lastChoices': {for (final e in lastChoices.entries) '${e.key}': e.value},
      'roundHistory': [for (final h in roundHistory) Map<String, dynamic>.of(h)],
      'lastEvent': lastEvent,
      'waitingFor': waitingFor,
      if (_over) 'placings': placings,
    };
  }
}
