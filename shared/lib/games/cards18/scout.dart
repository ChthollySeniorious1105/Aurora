import 'dart:math';

import '../../src/engine.dart';

/// Builds the full 45-card SCOUT deck: every unordered pair `[a, b]` with `1 <= a < b <= 10`.
List<List<int>> buildScoutDeck() => [
      for (var a = 1; a <= 10; a++)
        for (var b = a + 1; b <= 10; b++) <int>[a, b],
    ];

/// Flips a single dual-number card `[top, bottom] -> [bottom, top]`.
List<int> scoutFlipCard(List<int> card) => <int>[card[1], card[0]];

/// Flips an entire hand upside-down: swaps `[top, bottom] -> [bottom, top]` for every card
/// and reverses the hand order (rotating the fan 180°).
List<List<int>> scoutFlipHand(List<List<int>> hand) => [
      for (final c in hand.reversed) <int>[c[1], c[0]],
    ];

/// Evaluates whether [cards] (using active top numbers `c[0]`) is a valid SCOUT Show play.
/// Returns `(type, length, minRank)` where:
/// - `type`: `'set'` (all tops equal, including single card) or `'run'` (consecutive ascending or descending)
/// - `length`: `cards.length`
/// - `minRank`: minimum top value in [cards]
/// Returns `null` if [cards] is empty or not a valid Set or Run.
(String, int, int)? scoutEvaluatePlay(List<List<int>> cards) {
  if (cards.isEmpty) return null;
  final tops = [for (final c in cards) c[0]];
  if (tops.length == 1) {
    return ('set', 1, tops.first);
  }

  final allEqual = tops.every((v) => v == tops.first);
  if (allEqual) {
    return ('set', tops.length, tops.first);
  }

  var isAsc = true;
  var isDesc = true;
  for (var i = 1; i < tops.length; i++) {
    if (tops[i] != tops[i - 1] + 1) isAsc = false;
    if (tops[i] != tops[i - 1] - 1) isDesc = false;
  }
  if (isAsc || isDesc) {
    final minVal = tops.reduce(min);
    return ('run', tops.length, minVal);
  }

  return null;
}

/// Numerical strength of a valid play for direct comparison:
/// `length * 1000 + (type == 'set' ? 100 : 0) + minRank`.
int scoutPlayStrength(List<List<int>> cards) {
  final eval = scoutEvaluatePlay(cards);
  if (eval == null) return -1;
  final (type, len, minRank) = eval;
  // For single cards, 'set' bonus doesn't matter since all single cards are 'set'
  final typeBonus = (len >= 2 && type == 'set') ? 100 : 0;
  return len * 1000 + typeBonus + minRank;
}

/// Returns true iff [candidate] is a valid Set or Run AND strictly beats [stageCards]:
/// 1. Empty [stageCards] is beaten by any valid play.
/// 2. More cards beats fewer cards (`candidate.length > stageCards.length`).
/// 3. For equal card count (`>= 2`), a Set (`'set'`) beats a Run (`'run'`).
/// 4. For equal card count and same type, higher `minRank` beats lower `minRank`.
bool scoutBeatsStage(List<List<int>> candidate, List<List<int>> stageCards) {
  final candStr = scoutPlayStrength(candidate);
  if (candStr < 0) return false;
  if (stageCards.isEmpty) return true;
  final stageStr = scoutPlayStrength(stageCards);
  return candStr > stageStr;
}

/// Finds all valid `'show'` contiguous slices `(start, end)` in [hand] that beat [stageCards].
List<(int, int)> scoutLegalShows(
  List<List<int>> hand,
  List<List<int>> stageCards,
) {
  final out = <(int, int)>[];
  for (var i = 0; i < hand.length; i++) {
    for (var j = i; j < hand.length; j++) {
      final slice = hand.sublist(i, j + 1);
      if (scoutBeatsStage(slice, stageCards)) {
        out.add((i, j));
      }
    }
  }
  return out;
}

/// Computes the round score for a player:
/// `capturedCount + scoutTokens - (isRoundEnder ? 0 : remainingHandSize)`.
int scoutComputeRoundScore({
  required int capturedCount,
  required int scoutTokens,
  required int remainingHandSize,
  required bool isRoundEnder,
}) =>
    capturedCount + scoutTokens - (isRoundEnder ? 0 : remainingHandSize);

class ScoutGame extends GameEngine {
  late int totalRounds;
  int round = 1;
  int startPlayer = 0;
  int turn = 0;
  String phase = 'flip'; // 'flip' | 'play'
  String subPhase = ''; // '' | 'must_show' (during 2-step scout_and_show)

  late List<List<List<int>>> hands;
  late List<bool> oriented;
  late List<int> scores;
  late List<int> capturedCount;
  late List<int> scoutTokens;
  late List<bool> scoutAndShowUsed;

  List<List<int>> stageCards = [];
  int stageOwner = -1;
  String stageComboType = '';
  Map<String, dynamic>? lastAction;
  Map<String, dynamic>? lastRoundSummary;

  bool _over = false;
  List<int>? _placings;

  ScoutGame(super.setup) {
    totalRounds = setup.opt<int>('rounds', 2);
    hands = List.generate(players, (_) => <List<int>>[]);
    oriented = List.filled(players, false);
    scores = List.filled(players, 0);
    capturedCount = List.filled(players, 0);
    scoutTokens = List.filled(players, 0);
    scoutAndShowUsed = List.filled(players, false);
  }

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _placings;

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (phase == 'flip') {
      return [
        for (var s = 0; s < players; s++)
          if (!oriented[s]) s,
      ];
    }
    return [turn];
  }

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (_over || seat < 0 || seat >= players) throw GameError('无法认输');
    _over = true;
    final winners = [for (var i = 0; i < players; i++) if (i != seat) i];
    _placings = rankWinners(players, winners);
    host.log('${name(seat)} 认输');
  }

  @override
  void start() {
    _startRound();
  }

  List<List<int>> _buildDeckForPlayerCount() {
    final full = buildScoutDeck();
    List<List<int>> filtered;
    if (players == 2 || players == 3) {
      // Remove cards containing 10 -> 36 cards
      filtered = full.where((c) => c[0] != 10 && c[1] != 10).toList();
    } else if (players == 4) {
      // Remove [9, 10] -> 44 cards
      filtered = full.where((c) => !(c[0] == 9 && c[1] == 10)).toList();
    } else {
      // 5 players -> all 45 cards
      filtered = full;
    }
    final deck = shuffled(filtered, rng);
    return [
      for (final c in deck)
        rng.nextBool() ? <int>[c[0], c[1]] : <int>[c[1], c[0]],
    ];
  }

  int _handSizeForPlayerCount() => switch (players) {
        2 => 11,
        3 => 12,
        4 => 11,
        _ => 9,
      };

  void _startRound() {
    final deck = _buildDeckForPlayerCount();
    final handSize = _handSizeForPlayerCount();
    for (var s = 0; s < players; s++) {
      hands[s] = [
        for (final c in deck.sublist(s * handSize, (s + 1) * handSize))
          <int>[c[0], c[1]],
      ];
      oriented[s] = false;
      capturedCount[s] = 0;
      scoutTokens[s] = 0;
      scoutAndShowUsed[s] = false;
    }
    stageCards = [];
    stageOwner = -1;
    stageComboType = '';
    subPhase = '';
    lastAction = null;
    phase = 'flip';
    turn = startPlayer;
    host.log('第 $round/$totalRounds 局开始：请确认手牌正反方向（注意：手牌顺序不可重排！）');
  }

  List<Map<String, dynamic>> legalShowMoves(int seat) {
    final hand = hands[seat];
    final pairs = scoutLegalShows(hand, stageCards);
    return [
      for (final (i, j) in pairs)
        {
          'start': i,
          'end': j,
          'cards': [
            for (final c in hand.sublist(i, j + 1)) <int>[c[0], c[1]]
          ],
          'type': scoutEvaluatePlay(hand.sublist(i, j + 1))!.$1,
        },
    ];
  }

  void _applyScoutStep(
    int seat, {
    required String endSide,
    required bool flip,
    required int insertAt,
  }) {
    if (stageCards.isEmpty) {
      throw GameError('舞台上没有牌，无法进行星探挖角 (Scout)');
    }
    if (endSide != 'left' && endSide != 'right') {
      throw GameError('只能从舞台最左侧 (left) 或最右侧 (right) 挖角');
    }
    if (insertAt < 0 || insertAt > hands[seat].length) {
      throw GameError('插入手牌的位置越界');
    }

    final raw = endSide == 'left'
        ? stageCards.removeAt(0)
        : stageCards.removeLast();
    final taken = flip ? scoutFlipCard(raw) : <int>[raw[0], raw[1]];
    hands[seat].insert(insertAt, taken);

    if (stageOwner >= 0 && stageOwner < players && stageOwner != seat) {
      scoutTokens[stageOwner] += 1;
    }
    if (stageCards.isEmpty) {
      stageOwner = -1;
      stageComboType = '';
    } else {
      stageComboType = scoutEvaluatePlay(stageCards)?.$1 ?? 'set';
    }
  }

  void _applyShowStep(
    int seat, {
    required int start,
    required int end,
    bool fromScoutAndShow = false,
  }) {
    final hand = hands[seat];
    if (start < 0 || end < start || end >= hand.length) {
      throw GameError('所选连续手牌范围无效');
    }
    final slice = [
      for (final c in hand.sublist(start, end + 1)) <int>[c[0], c[1]],
    ];
    if (!scoutBeatsStage(slice, stageCards)) {
      throw GameError('所选连续手牌不是合法的同点组/顺子，或强度不足以压过当前舞台牌');
    }

    final prevCount = stageCards.length;
    capturedCount[seat] += prevCount;
    hand.removeRange(start, end + 1);
    stageCards = slice;
    stageOwner = seat;
    stageComboType = scoutEvaluatePlay(slice)!.$1;
    subPhase = '';

    final topsStr = slice.map((c) => '${c[0]}').join('-');
    lastAction = {
      'type': fromScoutAndShow ? 'scout_and_show' : 'show',
      'seat': seat,
      'cards': slice,
      'captured': prevCount,
    };
    host.log('${name(seat)} ${fromScoutAndShow ? "挖角连演 (Scout & Show)" : "演出压牌 (Show)"} [$topsStr]，收下舞台 $prevCount 张牌！');

    if (hand.isEmpty) {
      host.log('${name(seat)} 出完所有手牌，本局立即结束！');
      _finishRound(roundEnder: seat, reason: 'empty_hand');
      return;
    }

    turn = (turn + 1) % players;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'flip') {
      if (seat < 0 || seat >= players || oriented[seat]) {
        throw GameError('已确认过手牌方向');
      }
      if (type != 'orient' && type != 'flip') {
        throw GameError('请确认手牌正反方向 (orient)');
      }
      final doFlip = asBool(action['flip']);
      if (doFlip) {
        hands[seat] = scoutFlipHand(hands[seat]);
      }
      oriented[seat] = true;
      host.log('${name(seat)} ${doFlip ? "将整副手牌上下颠倒翻转" : "保持初始手牌方向"}');

      if (oriented.every((x) => x)) {
        phase = 'play';
        turn = startPlayer;
        host.log('全员准备就绪，由 ${name(turn)} 率先登台演出！');
      }
      return;
    }

    if (phase == 'play') {
      if (seat != turn) throw GameError('还没轮到你行动');

      if (subPhase == 'must_show' && type != 'show') {
        throw GameError('已执行「挖角连演」的挖角步骤，现在必须立刻演出压牌 (show)');
      }

      if (type == 'show') {
        final start = asInt(action['start'], -1);
        final end = asInt(action['end'], start);
        _applyShowStep(
          seat,
          start: start,
          end: end,
          fromScoutAndShow: subPhase == 'must_show',
        );
        return;
      }

      if (type == 'scout') {
        final endSide = asStr(action['endSide'], asStr(action['side'], 'left'));
        final flip = asBool(action['flip']);
        final insertAt = asInt(action['insertAt'], hands[seat].length);
        final prevOwner = stageOwner;

        _applyScoutStep(
          seat,
          endSide: endSide,
          flip: flip,
          insertAt: insertAt,
        );

        lastAction = {
          'type': 'scout',
          'seat': seat,
          'endSide': endSide,
          'flip': flip,
          'insertAt': insertAt,
          'stageOwner': prevOwner,
        };
        host.log('${name(seat)} 进行星探挖角 (Scout)，${prevOwner >= 0 ? "${name(prevOwner)} 获得 +1 星探筹码" : ""}');

        turn = (turn + 1) % players;
        if (stageCards.isNotEmpty && turn == stageOwner) {
          host.log('${name(stageOwner)} 的舞台演出无人能压过，本局立即结束！');
          _finishRound(roundEnder: stageOwner, reason: 'unchallenged');
        }
        return;
      }

      if (type == 'scout_and_show') {
        if (scoutAndShowUsed[seat]) {
          throw GameError('每局每人只能使用一次「挖角连演 (Scout & Show)」');
        }
        if (stageCards.isEmpty) {
          throw GameError('舞台上没有牌，无法使用「挖角连演」');
        }
        final endSide = asStr(action['endSide'], asStr(action['side'], 'left'));
        final flip = asBool(action['flip']);
        final insertAt = asInt(action['insertAt'], hands[seat].length);

        // Save snapshot in case combined show fails validation
        final savedHand = [
          for (final c in hands[seat]) <int>[c[0], c[1]],
        ];
        final savedStage = [
          for (final c in stageCards) <int>[c[0], c[1]],
        ];
        final savedOwner = stageOwner;
        final savedTokens = List<int>.of(scoutTokens);

        _applyScoutStep(
          seat,
          endSide: endSide,
          flip: flip,
          insertAt: insertAt,
        );

        if (action.containsKey('start')) {
          final start = asInt(action['start'], -1);
          final end = asInt(action['end'], start);
          try {
            scoutAndShowUsed[seat] = true;
            _applyShowStep(
              seat,
              start: start,
              end: end,
              fromScoutAndShow: true,
            );
            return;
          } catch (e) {
            hands[seat] = savedHand;
            stageCards = savedStage;
            stageOwner = savedOwner;
            scoutTokens = savedTokens;
            scoutAndShowUsed[seat] = false;
            rethrow;
          }
        }

        // Two-step mode: verify at least one legal show exists after scouting
        if (scoutLegalShows(hands[seat], stageCards).isEmpty) {
          hands[seat] = savedHand;
          stageCards = savedStage;
          stageOwner = savedOwner;
          scoutTokens = savedTokens;
          throw GameError('挖角后手中没有任何能压过当前舞台的牌型，无法发动「挖角连演」');
        }

        scoutAndShowUsed[seat] = true;
        subPhase = 'must_show';
        host.log('${name(seat)} 发动「挖角连演 (Scout & Show)」！请继续选择连续手牌进行演出');
        return;
      }

      throw GameError('无效操作：$type');
    }

    throw GameError('未知阶段');
  }

  void _finishRound({required int roundEnder, required String reason}) {
    final roundDelta = List<int>.filled(players, 0);
    final handPenalties = List<int>.filled(players, 0);
    for (var s = 0; s < players; s++) {
      final isEnder = s == roundEnder;
      handPenalties[s] = isEnder ? 0 : hands[s].length;
      roundDelta[s] = scoutComputeRoundScore(
        capturedCount: capturedCount[s],
        scoutTokens: scoutTokens[s],
        remainingHandSize: hands[s].length,
        isRoundEnder: isEnder,
      );
      scores[s] += roundDelta[s];
    }

    lastRoundSummary = {
      'round': round,
      'roundEnder': roundEnder,
      'reason': reason,
      'capturedCount': List<int>.of(capturedCount),
      'scoutTokens': List<int>.of(scoutTokens),
      'handPenalties': handPenalties,
      'roundDelta': roundDelta,
      'scores': List<int>.of(scores),
    };

    if (round >= totalRounds) {
      _over = true;
      _placings = rankByScore(scores);
      host.log('比赛结束！');
    } else {
      round += 1;
      startPlayer = (startPlayer + 1) % players;
      _startRound();
    }
  }

  int _evaluateHandOrientationScore(List<List<int>> hand) {
    var score = 0;
    for (var i = 0; i < hand.length; i++) {
      score += hand[i][0];
      if (i > 0) {
        final d = (hand[i][0] - hand[i - 1][0]).abs();
        if (d == 0) score += 18; // Adjacent pair!
        if (d == 1) score += 12; // Adjacent consecutive!
      }
    }
    return score;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over) return null;

    if (phase == 'flip') {
      if (oriented[seat]) return null;
      final normalScore = _evaluateHandOrientationScore(hands[seat]);
      final flippedScore =
          _evaluateHandOrientationScore(scoutFlipHand(hands[seat]));
      return {'type': 'orient', 'flip': flippedScore > normalScore};
    }

    if (phase == 'play') {
      if (seat != turn) return null;
      final hand = hands[seat];
      final shows = scoutLegalShows(hand, stageCards);

      if (subPhase == 'must_show') {
        if (shows.isEmpty) return null;
        shows.sort((a, b) => (b.$2 - b.$1).compareTo(a.$2 - a.$1));
        final best = shows.first;
        return {'type': 'show', 'start': best.$1, 'end': best.$2};
      }

      if (shows.isNotEmpty) {
        // Sort by longest slice first, then strongest play
        shows.sort((a, b) {
          final lenCmp = (b.$2 - b.$1).compareTo(a.$2 - a.$1);
          if (lenCmp != 0) return lenCmp;
          final sa = scoutPlayStrength(hand.sublist(a.$1, a.$2 + 1));
          final sb = scoutPlayStrength(hand.sublist(b.$1, b.$2 + 1));
          return sb.compareTo(sa);
        });
        final best = shows.first;
        final bestLen = best.$2 - best.$1 + 1;
        // Play if it empties hand, beats a multi-card stage, or plays >= 2 cards, or stage is empty
        if (bestLen == hand.length ||
            stageCards.isEmpty ||
            bestLen >= 2 ||
            hand.length <= 4 ||
            botLevel == 0) {
          return {'type': 'show', 'start': best.$1, 'end': best.$2};
        }
      }

      // Consider Scout & Show if available and we have few cards or strong combo after scouting
      if (!scoutAndShowUsed[seat] && stageCards.isNotEmpty && hand.length <= 5 && botLevel >= 1) {
        for (final side in const ['left', 'right']) {
          final raw = side == 'left' ? stageCards.first : stageCards.last;
          final remStage = side == 'left'
              ? stageCards.sublist(1)
              : stageCards.sublist(0, stageCards.length - 1);
          for (final fl in const [false, true]) {
            final card = fl ? scoutFlipCard(raw) : raw;
            for (var idx = 0; idx <= hand.length; idx++) {
              final nextHand = List<List<int>>.of(hand)..insert(idx, card);
              final nextShows = scoutLegalShows(nextHand, remStage);
              for (final (si, sj) in nextShows) {
                if (sj - si + 1 >= 3 || sj - si + 1 == nextHand.length) {
                  return {
                    'type': 'scout_and_show',
                    'endSide': side,
                    'flip': fl,
                    'insertAt': idx,
                    'start': si,
                    'end': sj,
                  };
                }
              }
            }
          }
        }
      }

      if (stageCards.isEmpty) {
        return {'type': 'show', 'start': 0, 'end': 0};
      }

      // Find best Scout placement (side, flip, insertAt) to create a longer Set or Run
      var bestSide = 'left';
      var bestFlip = false;
      var bestIdx = hand.length;
      var bestEval = -9999;

      final sides = stageCards.length == 1 ? const ['left'] : const ['left', 'right'];
      for (final side in sides) {
        final raw = side == 'left' ? stageCards.first : stageCards.last;
        for (final fl in const [false, true]) {
          final card = fl ? scoutFlipCard(raw) : raw;
          for (var idx = 0; idx <= hand.length; idx++) {
            final nextHand = List<List<int>>.of(hand)..insert(idx, card);
            final val = _evaluateHandOrientationScore(nextHand);
            if (val > bestEval) {
              bestEval = val;
              bestSide = side;
              bestFlip = fl;
              bestIdx = idx;
            }
          }
        }
      }

      // If no show was available or scouting improves hand significantly, scout; else show
      if (shows.isEmpty || bestEval > _evaluateHandOrientationScore(hand) + 12) {
        return {
          'type': 'scout',
          'endSide': bestSide,
          'flip': bestFlip,
          'insertAt': bestIdx,
        };
      }

      final fallback = shows.first;
      return {'type': 'show', 'start': fallback.$1, 'end': fallback.$2};
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myHand = (seat >= 0 && seat < players)
        ? [
            for (final c in hands[seat]) <int>[c[0], c[1]],
          ]
        : <List<int>>[];
    final myOriented = (seat >= 0 && seat < players) ? oriented[seat] : true;
    final myLegalShows =
        (seat >= 0 && seat < players && phase == 'play' && seat == turn)
            ? legalShowMoves(seat)
            : const <Map<String, dynamic>>[];

    return {
      'round': round,
      'totalRounds': totalRounds,
      'phase': phase,
      'subPhase': subPhase,
      'startPlayer': startPlayer,
      'turn': turn,
      'scores': List<int>.of(scores),
      'capturedCount': List<int>.of(capturedCount),
      'scoutTokens': List<int>.of(scoutTokens),
      'scoutAndShowUsed': List<bool>.of(scoutAndShowUsed),
      'oriented': List<bool>.of(oriented),
      'myOriented': myOriented,
      'handCounts': [for (final h in hands) h.length],
      'hand': myHand,
      'legalShows': myLegalShows,
      'stageCards': [
        for (final c in stageCards) <int>[c[0], c[1]],
      ],
      'stageOwner': stageOwner,
      'stageComboType': stageComboType,
      'lastAction': lastAction,
      'lastRoundSummary': lastRoundSummary,
      'over': _over,
      'placings': _placings,
    };
  }
}
