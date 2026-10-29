import 'dart:math';

import 'package:aurora_shared/games/euro10/defs.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(int n, [Map<String, dynamic> opts = const {}, int seed = 7]) => GameSetup(
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
  group('wingspan', () {
    test('play bird pays food & egg costs and triggers on_play power', () {
      final e = _start(Wingspan(_setup(2)));
      final s = e.turn;
      // Card 2: 绒啄木鸟, habitat [0], foodCost [1,0,0,1,0], on_play: +2 insects
      e.hand[s] = [2, 1];
      e.food[s] = [1, 1, 0, 1, 0];
      e.handle(s, {'type': 'play_bird', 'cardIdx': 0, 'hab': 0});
      expect(e.preserve[s][0].length, 1);
      expect(e.preserve[s][0].first.cardId, 2);
      // Paid 1 insect + 1 berry, then gained 2 insects from on_play
      expect(e.food[s][0], 2);
      expect(e.food[s][3], 0);

      // Next turn for P1: lay eggs so we can test slot 1 egg cost for P0
      e.handle(1 - s, {'type': 'gain_food'});

      // Slot 1 in Forest requires 1 egg (wsEggCosts = [0, 1, 1, 2, 2])
      expect(
        () => e.handle(s, {'type': 'play_bird', 'cardIdx': 0, 'hab': 0}),
        throwsA(isA<GameError>()),
      );
      e.preserve[s][0].first.eggs = 1;
      e.handle(s, {'type': 'play_bird', 'cardIdx': 0, 'hab': 0});
      expect(e.preserve[s][0].length, 2);
      expect(e.preserve[s][0].first.eggs, 0); // 1 egg spent
    });

    test('gain_food, lay_eggs, draw_cards activate brown powers right-to-left', () {
      final e = _start(Wingspan(_setup(2)));
      // Place 2 forest birds for P0: card 1 (蓝松鸦: cache_seed) and card 0 (北美红雀: gain_berry)
      e.preserve[0][0] = [PlacedBird(cardId: 1), PlacedBird(cardId: 0)];
      e.food[0] = [0, 0, 0, 0, 0];
      e.birdfeeder = [1, 2, 0, 3, 4];
      e.turn = 0;
      // With 2 forest birds, gain_food takes 1 + 2~/2 = 2 dice from birdfeeder, then triggers brown powers
      e.handle(0, {'type': 'gain_food', 'foods': [1, 2]});
      expect(e.food[0][1], 1);
      expect(e.food[0][2], 1);
      expect(e.food[0][3], 1); // from 北美红雀 brown power
      expect(e.preserve[0][0][0].cachedFood, 1); // from 蓝松鸦 brown power

      // Place wetland bird for P1: card 8 (加拿大雁: tuck_1 + gain 1 seed)
      e.preserve[1][2] = [PlacedBird(cardId: 8)];
      final handBefore = e.hand[1].length;
      e.handle(1, {'type': 'draw_cards', 'trayIdx': 0});
      expect(e.hand[1].length, handBefore + 1);
      expect(e.preserve[1][2][0].tuckedCards, 1);

      // Lay eggs for P0
      e.handle(0, {'type': 'lay_eggs'});
      expect(e.totalEggs(0), 2);
    });
  });

  group('quacks', () {
    test('starting bag, draw, white explosion > 7, and flask return', () {
      final e = _start(Quacks(_setup(2)));
      expect(e.bag[0].length, 9);
      expect(e.rubies[0], 1);
      expect(e.flaskFull[0], isTrue);

      // Put a White 2 at the end of P0's bag and draw it
      e.bag[0].add(const QuacksChip('white', 2));
      e.handle(0, {'type': 'draw'});
      expect(e.whiteSum[0], 2);
      expect(e.pos[0], 2);

      // Use flask to return the just-drawn White 2 chip
      e.handle(0, {'type': 'use_flask'});
      expect(e.flaskFull[0], isFalse);
      expect(e.whiteSum[0], 0);
      expect(e.pos[0], 0);

      // Force White chips totaling 8 -> explodes!
      e.bag[0] = [const QuacksChip('white', 3), const QuacksChip('white', 3), const QuacksChip('white', 2)];
      e.handle(0, {'type': 'draw'}); // +2 -> whiteSum 2
      e.handle(1, {'type': 'stop'});
      e.handle(0, {'type': 'draw'}); // +3 -> whiteSum 5
      e.handle(0, {'type': 'draw'}); // +3 -> whiteSum 8 -> EXPLODED!
      expect(e.exploded[0], isTrue);
      expect(e.phase, 'shop');
    });

    test('shop phase: exploded choice, buying chips, and spending rubies', () {
      final e = _start(Quacks(_setup(2)));
      e.pos[0] = 12;
      e.exploded[0] = true;
      e.stopped[0] = true;
      e.pos[1] = 10;
      e.stopped[1] = true;
      // Trigger transition via P1 stopping in brew phase
      e.stopped[1] = false;
      e.handle(1, {'type': 'stop'});
      expect(e.phase, 'shop');
      expect(e.explosionResolved[0], isFalse);
      expect(e.explosionResolved[1], isTrue); // non-exploded gets both VP and coins automatically

      // Exploded P0 chooses coins
      e.handle(0, {'type': 'choose_explosion', 'choice': 'coins'});
      expect(e.coins[0], quacksTrackCoins[12]);

      // P0 buys an Orange 1 (cost 3) and Red 1 (cost 4)
      final bagSizeBefore = e.ownedChips[0].length;
      e.handle(0, {'type': 'buy', 'color': 'orange', 'val': 1});
      e.handle(0, {'type': 'buy', 'color': 'red', 'val': 1});
      expect(e.ownedChips[0].length, bagSizeBefore + 2);

      // Spend 2 rubies to advance droplet
      e.rubies[0] = 2;
      e.handle(0, {'type': 'spend_rubies', 'target': 'droplet'});
      expect(e.droplet[0], 1);
      expect(e.rubies[0], 0);
    });
  });

  group('everdell', () {
    test('Critter-Construction free pairing marks construction occupied', () {
      final e = _start(Everdell(_setup(2)));
      // Put 农场 (id 0, cost [2,1,0,0]) and 农夫 (id 1, cost [0,0,0,2]) in P0's hand
      e.hand[0] = [0, 1];
      e.resources[0] = [2, 1, 0, 0]; // 0 berries!
      e.handle(0, {'type': 'play_card', 'source': 'hand', 'idx': 0});
      expect(e.city[0].length, 1);
      expect(e.city[0][0].card.name, '农场');
      expect(e.city[0][0].occupied, isFalse);
      // Playing 农场 (green production) immediately produced 1 berry; reset berries to 0 to verify free pairing
      e.resources[0][3] = 0;

      // P1 places a worker
      e.handle(1, {'type': 'place_worker', 'loc': 1});

      // P0 plays 农夫 for FREE (0 berries) using the unoccupied 农场!
      e.handle(0, {'type': 'play_card', 'source': 'hand', 'idx': 0});
      expect(e.city[0].length, 2);
      expect(e.city[0][1].card.name, '农夫');
      expect(e.city[0][0].occupied, isTrue);
    });

    test('worker placement and prepare_season progression', () {
      final e = _start(Everdell(_setup(1)));
      expect(e.season[0], 0); // Winter
      expect(e.workersAvail[0], 2);

      e.handle(0, {'type': 'place_worker', 'loc': 0});
      e.handle(0, {'type': 'place_worker', 'loc': 1});
      expect(e.workersAvail[0], 0);

      // Prepare for Spring -> recalls workers, +1 worker (total 3)
      e.handle(0, {'type': 'prepare_season'});
      expect(e.season[0], 1);
      expect(e.workersAvail[0], 3);
      expect(e.workerLocs[0], isEmpty);
    });
  });

  group('sagrada', () {
    test('strict window placement rules: border first, 8-way adjacency, constraints, no ortho same color/shade', () {
      final e = _start(Sagrada(_setup(2)));
      // Clear pattern constraints on seat 0 for isolated rule testing, except (0,1) color=2 and (0,2) shade=5
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 5; c++) {
          e.pattern[0][r][c] = const SagradaConstraint.none();
        }
      }
      e.pattern[0][0][1] = const SagradaConstraint.color(2);
      e.pattern[0][0][2] = const SagradaConstraint.shade(5);

      final red3 = SagradaDie(0, 3);
      // 1. First die cannot be placed in interior (1, 1)
      expect(e.canPlace(0, red3, 1, 1), isFalse);
      // First die can be placed on border (0, 0)
      expect(e.canPlace(0, red3, 0, 0), isTrue);
      e.window[0][0][0] = red3;

      // 2. Subsequent die must be 8-way adjacent to (0, 0) -> (0, 3) is not adjacent
      expect(e.canPlace(0, SagradaDie(2, 4), 0, 3), isFalse);
      // Diagonal (1, 1) IS 8-way adjacent and allows same color/value diagonally!
      expect(e.canPlace(0, SagradaDie(0, 3), 1, 1), isTrue);

      // 3. Orthogonal neighbor (0, 1) cannot have same color (0) or same shade (3), and must match constraint color=2
      expect(e.canPlace(0, SagradaDie(0, 4), 0, 1), isFalse); // wrong constraint color & same ortho color
      expect(e.canPlace(0, SagradaDie(2, 3), 0, 1), isFalse); // same ortho value 3!
      expect(e.canPlace(0, SagradaDie(2, 4), 0, 1), isTrue); // color 2 matches constraint, value 4 != 3
    });

    test('snake draft order and tool card usage', () {
      final e = _start(Sagrada(_setup(3)));
      expect(e.draftOrder, [0, 1, 2, 2, 1, 0]);
      expect(e.draftPool.length, 7);

      final f0 = e.favor[0];
      e.draftPool[0] = SagradaDie(1, 3);
      e.handle(0, {'type': 'use_tool', 'toolIdx': 0, 'die': 0, 'delta': 1});
      expect(e.favor[0], f0 - 1);
      expect(e.toolUsed[0], isTrue);
    });
  });

  test('sims', () {
    expect(runSims(euro10Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
