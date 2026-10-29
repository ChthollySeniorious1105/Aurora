import 'dart:math';

import 'package:aurora_shared/games/euro16/defs.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(int n,
        [Map<String, dynamic> opts = const {}, int seed = 7]) =>
    GameSetup(
      players: n,
      options: opts,
      names: [for (var i = 0; i < n; i++) 'P$i'],
      bots: List.filled(n, false),
      rng: Random(seed),
    );

T _start<T extends GameEngine>(T e) {
  e.host = SimHost();
  e.start();
  return e;
}

void main() {
  group('meadow', () {
    test('path token depth matching, symbol prerequisite chain validation, and campfire goal scoring', () {
      final e = _start(MeadowGame(_setup(2)));

      // Clear P0's ecosystem and hand for deterministic testing
      e.ecosystem[0] = [
        const MeadowCard(
          id: 901,
          tier: 0,
          name: '测试草地',
          emoji: '🌱',
          provides: 0, // 🌱 Grass
          reqs: [],
          vp: 1,
        ),
      ];
      e.hand[0] = [];
      e.tokensLeft[0] = [1, 3]; // Only depths 1 and 3 available

      // Put a Tier 1 Insect card at market[0][1] (row 0 -> depth 1, col 1 -> depth 2)
      // Requires 🌱 (0), provides 🐛 (3), 2 VP
      const insectCard = MeadowCard(
        id: 902,
        tier: 1,
        name: '七星瓢虫',
        emoji: '🐞',
        provides: 3, // 🐛 Insect
        reqs: [0], // requires 🌱 Grass
        vp: 2,
      );
      e.market[0][1] = insectCard;

      // Put an Apex Fox card in P0's hand that requires [0 (🌱), 5 (🐦)] -> cannot play yet!
      const foxCard = MeadowCard(
        id: 903,
        tier: 3,
        name: '丛林赤狐',
        emoji: '🦊',
        provides: 6,
        reqs: [0, 5],
        vp: 4,
      );
      e.hand[0].add(foxCard);

      // Trying to draft market[1][1] (needs depth 2) when P0 only has [1, 3] must fail!
      expect(
        () => e.handle(0, {'type': 'draft_play', 'row': 1, 'col': 1, 'playCard': -1}),
        throwsA(isA<GameError>()),
      );

      // Trying to play foxCard (hand index 0) which requires 🐦 (5) not in ecosystem must fail!
      expect(
        () => e.handle(0, {'type': 'draft_play', 'row': 0, 'col': 1, 'playCard': 0}),
        throwsA(isA<GameError>()),
      );

      // Draft market[0][1] using depth 1 token and immediately play the drafted insectCard (hand index 1)!
      e.handle(0, {'type': 'draft_play', 'row': 0, 'col': 1, 'playCard': 1});
      expect(e.tokensLeft[0], [3]);
      expect(e.symbolCounts(0)[0], 1); // 🌱
      expect(e.symbolCounts(0)[3], 1); // 🐛
      expect(e.calcEcosystemVp(0), 3); // 1 + 2 VP

      // P1 takes a turn
      e.handle(1, e.bot(1)!);

      // Now P0 has both 🌱 (0) and 🐛 (3) in ecosystem -> matches Campfire Goal 0 (symA: 0, symB: 3)!
      // Visiting Campfire Goal 2 (🌊 + 🐸) must fail since P0 lacks 🌊 and 🐸:
      expect(
        () => e.handle(0, {'type': 'campfire', 'goalIdx': 2}),
        throwsA(isA<GameError>()),
      );

      // Visiting Campfire Goal 0 succeeds and awards +2 VP!
      e.handle(0, {'type': 'campfire', 'goalIdx': 0});
      expect(e.campfireVp[0], 2);
      expect(e.score[0], 5);
    });
  });

  group('furnace', () {
    test('disc bidding rules (no duplicate value or same player on card), multiplied outbid compensation, and factory upgrade/production', () {
      final e = _start(FurnaceGame(_setup(2)));
      expect(e.phase, 'auction');

      // Rig market[0] with a card giving 2 Coal (compType=0, compAmount=2) per disc value when outbid
      e.market[0] = const FurnaceFactoryCard(
        id: 801,
        name: '跨国铁路网',
        emoji: '🚂',
        compType: 0, // Coal 🪨
        compAmount: 2,
        extractRes: [1, 0, 0],
        extractMoney: 2,
        costRes: [2, 0, 0],
        outMoney: 6,
      );
      e.resources[0] = [0, 0, 0];
      e.resources[1] = [0, 0, 0];

      // P0 places disc 2 on slot 0
      e.handle(0, {'type': 'bid', 'slot': 0, 'disc': 2});

      // P1 trying to place the SAME disc value (2) on slot 0 must fail!
      expect(
        () => e.handle(1, {'type': 'bid', 'slot': 0, 'disc': 2}),
        throwsA(isA<GameError>()),
      );

      // P1 places disc 4 on slot 0 (outbidding P0's disc 2!)
      e.handle(1, {'type': 'bid', 'slot': 0, 'disc': 4});

      // P0 trying to place a SECOND disc of their own on slot 0 must fail!
      expect(
        () => e.handle(0, {'type': 'bid', 'slot': 0, 'disc': 3}),
        throwsA(isA<GameError>()),
      );

      // Place remaining discs on slots 1, 2, 3
      e.handle(0, {'type': 'bid', 'slot': 1, 'disc': 1});
      e.handle(1, {'type': 'bid', 'slot': 1, 'disc': 3});
      e.handle(0, {'type': 'bid', 'slot': 2, 'disc': 3});
      e.handle(1, {'type': 'bid', 'slot': 2, 'disc': 2});
      e.handle(0, {'type': 'bid', 'slot': 3, 'disc': 4});
      e.handle(1, {'type': 'bid', 'slot': 3, 'disc': 1});

      // Auction resolves automatically after all 4 discs are placed!
      expect(e.phase, 'production');
      // On slot 0, P0 had non-highest disc 2 -> receives 2 * 2 = 4 Coal (plus any compensation from slot 1)!
      expect(e.resources[0][0], greaterThanOrEqualTo(4));
      // P1 had highest disc 4 on slot 0 -> claims '跨国铁路网' (id 801) into factories[1]!
      expect(e.factories[1].any((f) => f.id == 801), isTrue);

      // In production phase, P0 upgrades a factory and activates it for money
      final p0MoneyBefore = e.money[0];
      e.handle(0, {'type': 'activate', 'factoryIdx': 0});
      expect(e.money[0], greaterThan(p0MoneyBefore));
    });
  });

  group('trekking_history', () {
    test('rear-most time traveler turn order, chronological trek streak vs reset, time crystals, and hour-12 punctuality bonus', () {
      final e = _start(TrekkingHistoryGame(_setup(2)));
      e.crystals[0] = 2;
      e.market = [
        const TrekkingEventCard(
          id: 701,
          dayDeck: 1,
          title: '胡夫金字塔',
          emoji: '🔺',
          year: -2560,
          hours: 5,
          tokens: [3, 2],
        ),
        const TrekkingEventCard(
          id: 702,
          dayDeck: 1,
          title: '秦始皇统一六国',
          emoji: '👑',
          year: -221,
          hours: 3,
          tokens: [0, 1],
        ),
        const TrekkingEventCard(
          id: 703,
          dayDeck: 1,
          title: '古腾堡印刷机',
          emoji: '📚',
          year: 1440,
          hours: 4,
          tokens: [2, 1],
        ),
        const TrekkingEventCard(
          id: 704,
          dayDeck: 1,
          title: '商朝甲骨文',
          emoji: '🐢',
          year: -1200,
          hours: 4,
          tokens: [2, 3],
        ),
      ];

      // P0 visits slot 0 (-2560, 5 hours) spending 2 crystals -> effective hours = 5 - 2 = 3!
      e.handle(0, {'type': 'visit', 'slot': 0, 'useCrystals': 2});
      expect(e.hourPos[0], 3);
      expect(e.crystals[0], 0);
      expect(e.trekLen[0], 1);
      expect(e.currentTrekLastYear[0], -2560);

      // P1 is now rear-most (hourPos[1] == 0 < hourPos[0] == 3) -> turn is 1!
      expect(e.turn, 1);

      // P1 visits slot 0 (now '秦始皇统一六国', -221, 3 hours) with 0 crystals -> hourPos[1] = 3
      e.handle(1, {'type': 'visit', 'slot': 0, 'useCrystals': 0});
      expect(e.hourPos[1], 3);

      // Both at hour 3 -> P0 is next (tie-breaker lowest seat)
      expect(e.turn, 0);
      // P0 visits '古腾堡印刷机' (+1440 >= -2560, 4 hours) -> Trek continues to length 2!
      // And P0 is at hour 3 + 4 = 7; set P0's hourPos to 8 before visit so 8 + 4 == 12 triggers Punctuality Bonus (+3 VP)!
      e.hourPos[0] = 8;
      e.handle(0, {'type': 'visit', 'slot': 0, 'useCrystals': 0});
      expect(e.hourPos[0], 12);
      expect(e.punctualityVp[0], 3); // Exact hour 12 Punctuality Bonus!
      expect(e.trekLen[0], 2);
      expect(e.currentTrekLastYear[0], 1440);

      // Now if P0 visits an earlier year (-1200 < 1440) on a later turn, old Trek of len 2 scores 1 VP and resets to 1
      e.hourPos[0] = 0;
      e.turn = 0;
      e.handle(0, {'type': 'visit', 'slot': 0, 'useCrystals': 0});
      expect(e.completedTrekVp[0], 1); // len 2 trek = 1 VP
      expect(e.trekLen[0], 1);
      expect(e.currentTrekLastYear[0], -1200);
    });
  });

  group('aquatica', () {
    test('manta ray flip, location buy/conquer, 3-depth rising engine rewards,vault scoring, and character recall', () {
      final e = _start(AquaticaGame(_setup(2)));
      e.coins[0] = 2;
      e.strength[0] = 1;
      e.freeRises[0] = 2;

      e.locationMarket[0] = const AquaticaLocationCard(
        id: 601,
        name: '亚特兰蒂斯遗迹',
        emoji: '🏛️',
        buyCost: 4,
        conquerCost: 3,
        vp: 6,
        depthRewards: [0, 2, 3], // D1: +2🪙, D2: +1⬆️, D3: +2⭐VP
      );

      // Flip Manta 0 (+2🪙) -> coins[0] becomes 4
      e.handle(0, {'type': 'use_manta', 'manta': 0});
      expect(e.mantas[0][0], isFalse);
      expect(e.coins[0], 4);

      // Buy '亚特兰蒂斯遗迹' into depth slot 0 -> coins[0] becomes 0, currentDepth = 0
      e.handle(0, {'type': 'buy_loc', 'marketIdx': 0, 'slot': 0});
      expect(e.coins[0], 0);
      expect(e.depthSlots[0][0]?.id, 601);
      expect(e.depthSlots[0][0]?.currentDepth, 0);

      // Cannot score_loc before reaching maxDepth (3)!
      expect(
        () => e.handle(0, {'type': 'score_loc', 'slot': 0}),
        throwsA(isA<GameError>()),
      );

      // Rise 1 (0 -> 1): triggers D1 reward (0: +2🪙)
      e.handle(0, {'type': 'rise', 'slot': 0});
      expect(e.depthSlots[0][0]?.currentDepth, 1);
      expect(e.coins[0], 2);

      // Rise 2 (1 -> 2): triggers D2 reward (2: +1⬆️) -> grants an extra freeRise!
      e.handle(0, {'type': 'rise', 'slot': 0});
      expect(e.depthSlots[0][0]?.currentDepth, 2);
      expect(e.freeRises[0], 1);

      // Rise 3 (2 -> 3): triggers D3 reward (3: +2⭐VP)
      e.handle(0, {'type': 'rise', 'slot': 0});
      expect(e.depthSlots[0][0]?.currentDepth, 3);
      expect(e.bonusVp[0], 2);

      // Score top-depth location into Vault (+6 VP)!
      e.handle(0, {'type': 'score_loc', 'slot': 0});
      expect(e.depthSlots[0][0], isNull);
      expect(e.vault[0].length, 1);
      expect(e.score[0], 8); // 6 vault VP + 2 bonus VP

      // Play a character card then Recall -> played card returns to hand & Manta 0 flips back to true!
      e.handle(0, {'type': 'play_card', 'cardIdx': 0});
      expect(e.playedCards[0].length, 1);
      e.handle(0, {'type': 'recall'});
      expect(e.playedCards[0], isEmpty);
      expect(e.mantas[0][0], isTrue);
    });
  });

  test('sims', () {
    expect(runSims(euro16Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
