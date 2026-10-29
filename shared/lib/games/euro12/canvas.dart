import 'dart:math';

import '../../src/ai.dart';
import '../../src/engine.dart';

const List<String> canvasColorNames = ['赤红', '琥珀', '翠绿', '群青', '紫罗兰'];
const List<String> canvasColorEmojis = ['🟥', '🟨', '🟩', '🟦', '🟪'];

const List<String> canvasIconNames = ['色调', '构图', '笔触', '意境', '银章'];
const List<String> canvasIconEmojis = ['☀️', '🔺', '🌀', '🌿', '⭐'];
const List<int> canvasRibbonVps = [4, 3, 5, 4, 2];

class CanvasZone {
  final int color; // 0..4
  final int icon; // 0: ☀️, 1: 🔺, 2: 🌀, 3: 🌿, 4: ⭐

  const CanvasZone(this.color, this.icon);

  Map<String, dynamic> toJson() => {
        'color': color,
        'icon': icon,
      };
}

class CanvasCard {
  final int id;
  final String titlePart;
  final List<CanvasZone?> zones; // Length 3: [Left 0, Center 1, Right 2], null = Transparent!

  const CanvasCard({
    required this.id,
    required this.titlePart,
    required this.zones,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'titlePart': titlePart,
        'zones': [for (final z in zones) z?.toJson()],
      };
}

class CanvasMasterpiece {
  final String title;
  final List<CanvasCard> cards; // [bottom, middle, top]
  final List<CanvasZone?> finalZones; // [z0, z1, z2]
  final List<int> earnedRibbons; // Length 5: [r0, r1, r2, r3, silver]
  final int vp;

  const CanvasMasterpiece({
    required this.title,
    required this.cards,
    required this.finalZones,
    required this.earnedRibbons,
    required this.vp,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'cards': [for (final c in cards) c.toJson()],
        'finalZones': [for (final z in finalZones) z?.toJson()],
        'earnedRibbons': earnedRibbons,
        'vp': vp,
      };
}

const List<String> _titleWords = [
  '晨曦', '迷雾', '星空', '微风', '孤岛', '暮色', '秋水', '浮生', '幻境', '潮汐',
  '山岚', '流光', '花火', '静谧', '远航', '月影', '苍穹', '初雪', '秘密', '追忆',
  '回响', '破晓', '涟漪', '繁花', '拾光', '云端', '归途', '秘境', '森林', '灯塔',
  '飞鸟', '深海', '琥珀', '晚钟', '倒影', '晴空', '银河', '夏夜', '冬日', '春野',
];

List<CanvasCard> buildCanvasDeck() {
  final out = <CanvasCard>[];
  var id = 1;
  // Single-zone cards (1 opaque zone, 2 transparent zones)
  for (var pos = 0; pos < 3; pos++) {
    for (var col = 0; col < 5; col++) {
      final ic = (pos + col) % 5;
      final zones = List<CanvasZone?>.filled(3, null);
      zones[pos] = CanvasZone(col, ic);
      out.add(CanvasCard(
        id: id,
        titlePart: _titleWords[(id - 1) % _titleWords.length],
        zones: zones,
      ));
      id++;
    }
  }
  // Two-zone cards (2 opaque zones, 1 transparent zone)
  const pairs = [(0, 1), (1, 2), (0, 2)];
  for (final (p1, p2) in pairs) {
    for (var i = 0; i < 9; i++) {
      final c1 = (i + p1) % 5;
      final c2 = (i * 2 + p2 + 1) % 5;
      final ic1 = (i + p2) % 5;
      final ic2 = (i * 3 + 1) % 5;
      final zones = List<CanvasZone?>.filled(3, null);
      zones[p1] = CanvasZone(c1, ic1);
      zones[p2] = CanvasZone(c2, ic2);
      out.add(CanvasCard(
        id: id,
        titlePart: _titleWords[(id - 1) % _titleWords.length],
        zones: zones,
      ));
      id++;
    }
  }
  return out;
}

class CanvasGame extends GameEngine {
  CanvasGame(super.setup);

  final _ai = AiSlot();

  late int targetPaintings;
  late List<CanvasCard> deck;

  /// Central Market Row of up to 5 Art Cards (`market[0..4]`).
  late List<CanvasCard> market;

  /// Inspiration Tokens sitting on each market slot (`tokensOn[0..4]`).
  late List<int> tokensOn;

  /// Player hands (`hand[seat]`, max 5 cards).
  late List<List<CanvasCard>> hand;

  /// Inspiration Tokens held by each player (`tokens[seat]`, starts at 4).
  late List<int> tokens;

  /// Earned Ribbons per player (`ribbons[seat][0..4]` for ☀️, 🔺, 🌀, 🌿, ⭐).
  late List<List<int>> ribbons;

  /// Completed paintings (`gallery[seat]`).
  late List<List<CanvasMasterpiece>> gallery;

  late List<int> score;
  late List<bool> done;

  int turn = 0;
  int stepCount = 0;
  bool _over = false;
  int? resignedSeat;
  String lastAction = '画廊开幕！请从市场拿取透明艺术卡（或用 3 张卡叠合完成画作）！';

  @override
  bool get isOver => _over;

  @override
  bool get canResign => !_over && players > 1;

  @override
  void resign(int seat) {
    if (_over) return;
    resignedSeat = seat;
    _over = true;
    host.log('${name(seat)} 认输');
  }

  @override
  List<int>? get placings {
    if (!_over) return null;
    if (resignedSeat != null) {
      final winners = [
        for (var i = 0; i < players; i++)
          if (i != resignedSeat) i
      ];
      return rankWinners(players, winners);
    }
    // Tie-breaker: leftover inspiration tokens
    final adj = [
      for (var s = 0; s < players; s++) score[s] * 100 + tokens[s],
    ];
    return rankByScore(adj);
  }

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  void start() {
    targetPaintings = setup.opt<int>('paintings', 3);
    deck = shuffled(buildCanvasDeck(), rng);

    market = [];
    tokensOn = [];
    for (var i = 0; i < 5; i++) {
      if (deck.isNotEmpty) {
        market.add(deck.removeLast());
        tokensOn.add(0);
      }
    }

    hand = [
      for (var s = 0; s < players; s++)
        [
          for (var i = 0; i < 3; i++)
            if (deck.isNotEmpty) deck.removeLast(),
        ],
    ];
    tokens = List<int>.filled(players, 4);
    ribbons = [
      for (var s = 0; s < players; s++) List<int>.filled(5, 0),
    ];
    gallery = [
      for (var s = 0; s < players; s++) <CanvasMasterpiece>[],
    ];
    score = List<int>.filled(players, 0);
    done = List<bool>.filled(players, false);
    turn = 0;
  }

  /// Layers 3 cards in order `[bottom, middle, top]` so top-most non-null zone wins each slot `0..2`.
  List<CanvasZone?> layerCards(List<CanvasCard> cards3) {
    final result = List<CanvasZone?>.filled(3, null);
    for (final card in cards3) {
      for (var z = 0; z < 3; z++) {
        if (card.zones[z] != null) {
          result[z] = card.zones[z];
        }
      }
    }
    return result;
  }

  /// Evaluates the 5 Ribbon counts `[r0, r1, r2, r3, silver]` earned by [finalZones].
  List<int> evaluateRibbons(List<CanvasZone?> finalZones) {
    final earned = List<int>.filled(5, 0);
    final colors = <int>[];
    var nonNullCount = 0;

    for (final z in finalZones) {
      if (z == null) continue;
      nonNullCount++;
      colors.add(z.color);
      earned[z.icon]++;
    }

    // Objective 0 (☀️ 色调): +1 Ribbon if all 3 zones have distinct colors
    if (colors.toSet().length == 3) {
      earned[0]++;
    }
    // Objective 1 (🔺 构图): +1 Ribbon if all 3 zones are filled (opaque)
    if (nonNullCount == 3) {
      earned[1]++;
    }
    // Objective 2 (🌀 笔触): +1 Ribbon if at least 2 zones share the same color
    if (colors.length >= 2 && colors.toSet().length < colors.length) {
      earned[2]++;
    }
    // Objective 3 (🌿 意境): +1 Ribbon if both Hue (0) and Tone (3) or Shape (1) and Tone (3) appear
    if (earned[3] > 0 && (earned[0] > 0 || earned[1] > 0)) {
      earned[3]++;
    }

    return earned;
  }

  int calcMasterpieceVp(List<int> earnedRibbons) {
    var total = 0;
    for (var i = 0; i < 5; i++) {
      total += earnedRibbons[i] * canvasRibbonVps[i];
    }
    return total;
  }

  int recalcScore(int seat) {
    var total = 0;
    for (var i = 0; i < 5; i++) {
      total += ribbons[seat][i] * canvasRibbonVps[i];
    }
    score[seat] = total;
    return total;
  }

  bool canTakeSlot(int seat, int slot) {
    if (done[seat]) return false;
    if (hand[seat].length >= 5) return false;
    if (slot < 0 || slot >= market.length) return false;
    return tokens[seat] >= slot;
  }

  bool canPaint(int seat) => !done[seat] && hand[seat].length >= 3;

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);

    if (type == 'take') {
      final slot = asInt(action['slot'], -1);
      if (hand[seat].length >= 5) {
        throw GameError('手牌已满 5 张，必须先完成一幅画作');
      }
      if (slot < 0 || slot >= market.length) {
        throw GameError('选择的市场卡位无效');
      }
      if (tokens[seat] < slot) {
        throw GameError('灵感标记不足（需要 $slot 枚灵感标记）');
      }

      // Pay 1 token onto each earlier slot 0..slot-1
      tokens[seat] -= slot;
      for (var i = 0; i < slot; i++) {
        tokensOn[i]++;
      }

      // Gain the card and any tokens sitting on slot
      final card = market.removeAt(slot);
      final gainedTokens = tokensOn.removeAt(slot);
      tokens[seat] += gainedTokens;
      hand[seat].add(card);

      // Refill market at the right end
      if (deck.isNotEmpty) {
        market.add(deck.removeLast());
        tokensOn.add(0);
      }

      stepCount++;
      final gainMsg = gainedTokens > 0 ? '（并获得卡上 $gainedTokens 枚🎨灵感）' : '';
      lastAction =
          '${name(seat)} 花费 $slot 枚🎨灵感拿取了「${card.titlePart}」$gainMsg';
      host.log(lastAction);
      _advanceTurn();
      return;
    }

    if (type == 'paint') {
      if (hand[seat].length < 3) {
        throw GameError('至少需要 3 张艺术卡才能叠合完成一幅画作');
      }
      final rawCards = asIntList(action['cards']);
      if (rawCards.length != 3) {
        throw GameError('必须按顺序选择恰好 3 张艺术卡 [底层, 中层, 顶层]');
      }

      final playerHand = hand[seat];
      List<CanvasCard> chosen = [];
      final asIndicesValid = rawCards.toSet().length == 3 &&
          rawCards.every((i) => i >= 0 && i < playerHand.length);
      if (asIndicesValid) {
        chosen = [for (final idx in rawCards) playerHand[idx]];
      } else {
        // Fallback: interpret rawCards as card IDs in hand
        for (final cid in rawCards) {
          final found = playerHand.where((c) => c.id == cid).firstOrNull;
          if (found == null || chosen.contains(found)) {
            throw GameError('选择的艺术卡无效或重复');
          }
          chosen.add(found);
        }
      }

      for (final c in chosen) {
        playerHand.remove(c);
      }

      final finalZones = layerCards(chosen);
      final earned = evaluateRibbons(finalZones);
      final vp = calcMasterpieceVp(earned);
      for (var i = 0; i < 5; i++) {
        ribbons[seat][i] += earned[i];
      }

      final title =
          '《${chosen[0].titlePart}·${chosen[1].titlePart}·${chosen[2].titlePart}》';
      final mp = CanvasMasterpiece(
        title: title,
        cards: chosen,
        finalZones: finalZones,
        earnedRibbons: earned,
        vp: vp,
      );
      gallery[seat].add(mp);
      recalcScore(seat);
      stepCount++;

      if (gallery[seat].length >= targetPaintings) {
        done[seat] = true;
      }

      lastAction = '${name(seat)} 创作了画作 $title，斩获 $vp 分！';
      host.log(lastAction);
      _advanceTurn();
      return;
    }

    throw GameError('未知操作: $type');
  }

  void _advanceTurn() {
    // Check if any player is out of moves (market empty and <3 cards in hand)
    for (var s = 0; s < players; s++) {
      if (!done[s] && market.isEmpty && hand[s].length < 3) {
        done[s] = true;
      }
    }

    if (done.every((d) => d)) {
      _over = true;
      for (var s = 0; s < players; s++) {
        recalcScore(s);
      }
      host.log('画布艺术展圆满落幕！最终得分：${[
        for (var s = 0; s < players; s++) '${name(s)} ${score[s]}分'
      ].join('，')}');
      return;
    }

    for (var i = 1; i <= players; i++) {
      final cand = (turn + i) % players;
      if (!done[cand]) {
        turn = cand;
        return;
      }
    }
  }

  Map<String, dynamic> _heuristicMove(int seat) {
    final h = hand[seat];
    // Evaluate best 3-card painting currently in hand
    List<int>? bestTriplet;
    var bestVp = -1;
    if (h.length >= 3) {
      for (var i = 0; i < h.length; i++) {
        for (var j = 0; j < h.length; j++) {
          if (j == i) continue;
          for (var k = 0; k < h.length; k++) {
            if (k == i || k == j) continue;
            final fz = layerCards([h[i], h[j], h[k]]);
            final earned = evaluateRibbons(fz);
            final vp = calcMasterpieceVp(earned);
            if (vp > bestVp) {
              bestVp = vp;
              bestTriplet = [i, j, k];
            }
          }
        }
      }
    }

    // Must paint if hand has 5 cards or market is empty
    if (h.length >= 5 || market.isEmpty) {
      return {'type': 'paint', 'cards': bestTriplet ?? [0, 1, 2]};
    }

    // If we have >= 4 cards and a great painting (or botLevel == 0 with >= 3 cards), paint!
    if (bestTriplet != null && (h.length >= 4 || bestVp >= 18)) {
      return {'type': 'paint', 'cards': bestTriplet};
    }

    // Otherwise take the best affordable card from the market
    var bestSlot = 0;
    var bestSlotScore = -999;
    final maxSlot = min(tokens[seat], market.length - 1);
    for (var slot = 0; slot <= maxSlot; slot++) {
      final card = market[slot];
      final opaqueCount = card.zones.where((z) => z != null).length;
      final netTokenGain = tokensOn[slot] - slot;
      final val = opaqueCount * 10 + netTokenGain * 6;
      if (val > bestSlotScore) {
        bestSlotScore = val;
        bestSlot = slot;
      }
    }
    return {'type': 'take', 'slot': bestSlot};
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    if (aiOn) {
      final r = _ai.poll(
        setup.ai!,
        'cv:$stepCount:$seat',
        () => AiRequest(
          system: '你在玩《画布艺术 Canvas》。',
          prompt: '手牌 ${hand[seat].length} 张，灵感 ${tokens[seat]} 枚，已完成画作 ${gallery[seat].length}/$targetPaintings。',
        ),
      );
      if (r.pending) return null;
    }
    return _heuristicMove(seat);
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'targetPaintings': targetPaintings,
      'deckCount': deck.length,
      'market': [for (final c in market) c.toJson()],
      'tokensOn': tokensOn,
      'turn': turn,
      'over': _over,
      'lastAction': lastAction,
      'score': score,
      'tokens': tokens,
      'ribbons': ribbons,
      'done': done,
      'players': [
        for (var s = 0; s < players; s++)
          {
            'seat': s,
            'score': score[s],
            'tokens': tokens[s],
            'ribbons': ribbons[s],
            'done': done[s],
            'hand': [for (final c in hand[s]) c.toJson()],
            'gallery': [for (final mp in gallery[s]) mp.toJson()],
          },
      ],
    };
  }
}
