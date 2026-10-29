import 'dart:math';

import 'package:aurora_shared/games/party16/defs.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(int players, {Map<String, dynamic>? options, int seed = 42}) {
  return GameSetup(
    players: players,
    options: options ?? const {},
    names: [for (var i = 0; i < players; i++) 'P$i'],
    bots: List<bool>.filled(players, false),
    hostSeat: 0,
    rng: Random(seed),
  );
}

void main() {
  group('mysterium_park (诡秘马戏团)', () {
    test('Vision clues, Innocent Witness re-guess, 3x3 suspect/location deduction & Finale vote', () {
      final g = MysteriumParkGame(_setup(3));
      g.start();

      expect(g.stage, 1);
      expect(g.phase, 'clue');
      expect(g.suspects.length, 9);

      // Force deterministic targets for testing
      g.witnessSlot = 0;
      g.targetSlot[1] = 1;
      g.targetSlot[2] = 2;

      // Guide (seat 0) gives Vision Clues to Psychics 1 and 2
      g.handle(0, {'type': 'clue', 'seat': 1, 'vision': 1});
      expect(g.phase, 'clue');
      g.handle(0, {'type': 'clue', 'seat': 2, 'vision': 2});
      expect(g.phase, 'guess');

      // Psychic 1 guesses slot 0 (Innocent Witness 👁️!) -> cleared immediately and gets to guess again!
      g.handle(1, {'type': 'guess', 'slot': 0});
      expect(g.gridCleared[0], isTrue);
      expect(g.currentGuess[1], isNull); // gets to guess again!
      expect(g.waitingFor, contains(1));

      // Now Psychic 1 guesses slot 1 (correct!) and Psychic 2 guesses slot 2 (correct!)
      g.handle(1, {'type': 'guess', 'slot': 1});
      g.handle(2, {'type': 'guess', 'slot': 2});

      // Both solved Stage 1 -> automatically advances to Stage 2 (Locations)!
      expect(g.stage, 2);
      expect(g.phase, 'clue');

      // Force Stage 2 targets and solve
      g.witnessSlot = 0;
      g.targetSlot[1] = 3;
      g.targetSlot[2] = 4;
      g.handle(0, {'type': 'clue', 'seat': 1, 'vision': 3});
      g.handle(0, {'type': 'clue', 'seat': 2, 'vision': 4});
      g.handle(1, {'type': 'guess', 'slot': 3});
      g.handle(2, {'type': 'guess', 'slot': 4});

      // Advances to Round 3 ('finale')!
      expect(g.stage, 3);
      expect(g.phase, 'finale');
      expect(g.finaleCandidates.length, 3);

      final culprit = g.finaleCulprit;
      g.handle(0, {'type': 'vote', 'candidate': culprit});
      g.handle(1, {'type': 'vote', 'candidate': culprit});
      g.handle(2, {'type': 'vote', 'candidate': culprit});

      expect(g.isOver, isTrue);
      expect(g.teamWon, isTrue);
    });
  });

  group('vegas_showdown (赌城大亨)', () {
    test('Outbid-rebound auction refund, Publicity pass & 5x5 Casino floor-plan building', () {
      final g = VegasShowdownGame(_setup(3, options: const {'mode': 'fast'}));
      g.start();

      expect(g.phase, 'bid');
      final p0StartCash = g.cash[0];
      final p1StartCash = g.cash[1];

      // Seat 0 bids 3 on track 0
      g.handle(0, {'type': 'bid', 'slot': 0, 'bid': 3});
      expect(g.highBids[0], 3);
      expect(g.highBidders[0], 0);
      expect(g.cash[0], p0StartCash - 3);

      // Seat 1 outbids Seat 0 on track 0 with 5 -> Seat 0 is refunded 3 and rebounds!
      g.handle(1, {'type': 'bid', 'slot': 0, 'bid': 5});
      expect(g.highBids[0], 5);
      expect(g.highBidders[0], 1);
      expect(g.cash[0], p0StartCash); // refunded!
      expect(g.cash[1], p1StartCash - 5);

      // Seat 2 takes Publicity (+2 Cash, +1 Fame)
      final p2StartCash = g.cash[2];
      g.handle(2, {'type': 'publicity'});
      expect(g.cash[2], p2StartCash + 2);
      expect(g.fame[2], 1);

      // Seat 0 (rebounded!) now bids 4 on track 1
      g.handle(0, {'type': 'bid', 'slot': 1, 'bid': 4});

      // All 3 players settled -> transitions to 'place' phase!
      expect(g.phase, 'place');
      expect(g.turn, 0);

      // Seat 0 places won room on (2, 2), Seat 1 places won room on (2, 3)
      g.handle(0, {'type': 'place', 'r': 2, 'c': 2});
      expect(g.casino[0][2][2], isNotNull);
      expect(g.turn, 1);
      g.handle(1, {'type': 'place', 'r': 2, 'c': 3});
      expect(g.casino[1][2][3], isNotNull);

      // Round 2 starts and players received their revenue
      expect(g.round, 2);
      expect(g.phase, 'bid');
    });
  });

  group('jamaica (牙买加海盗赛船)', () {
    test('Captain morning/evening dice assignment, 3-hold cargo & Naval Cannon Combat', () {
      final g = JamaicaGame(_setup(2));
      g.start();

      expect(g.phase, 'roll');
      g.handle(0, {'type': 'assign_dice', 'morning': 3, 'evening': 2});
      expect(g.phase, 'choose');
      expect(g.morningVal, 3);
      expect(g.eveningVal, 2);

      // Give Seat 0 card 0 (load_gold + move_fwd) and Seat 1 card 1 (load_food + move_fwd)
      // Both move forward 2 spaces to space 2 -> triggers Naval Cannon Combat!
      g.hands[0] = [0, 1, 2];
      g.hands[1] = [1, 2, 3];
      g.handle(0, {'type': 'play', 'card': 0, 'hold': 0});
      g.handle(1, {'type': 'play', 'card': 1, 'hold': 1});

      expect(g.pos[0], 2);
      expect(g.pos[1], 2);
      expect(g.phase, 'combat');
      expect(g.waitingFor, containsAll([0, 1]));

      // Both spend gunpowder in combat
      g.handle(0, {'type': 'combat', 'powder': 2});
      g.handle(1, {'type': 'combat', 'powder': 0});

      expect(g.round, 2);
      expect(g.phase, 'roll');
    });
  });

  group('downforce (极速方程式)', () {
    test('Car auction, multi-car speed card movement, chicane blocking & 3-line betting', () {
      final g = DownforceGame(_setup(2, options: const {'mode': 'fast'}));
      g.start();

      expect(g.phase, 'auction');
      // Auction all 6 cars between 2 players
      for (var c = 0; c < 6; c++) {
        g.handle(0, {'type': 'bid', 'amount': c.isEven ? 4 : 1});
        g.handle(1, {'type': 'bid', 'amount': c.isEven ? 2 : 3});
      }

      expect(g.phase, 'race');
      expect(g.ownedCars[0], [0, 2, 4]);
      expect(g.ownedCars[1], [1, 3, 5]);
      expect(g.auctionCost[0], 12);
      expect(g.auctionCost[1], 9);

      // Test Chicane blocking at space 5 (fast mode first chicane is at space 5):
      // Put Car 0 at space 4 and Car 1 at space 4.
      // Play card {0: 1, 1: 3} -> Car 1 (speed 3) moves first to space 7 (crosses betLine 6!),
      // Now test Chicane blocking directly: put Car 2 at space 5 (chicane) and Car 3 at space 4, try moving Car 3 by 2 -> blocked at 4!
      g.carPos[2] = 5; // occupying 1-lane Chicane at 5
      g.carPos[3] = 4;
      final moved3 = g.moveSingleCar(3, 2);
      expect(moved3, 0);
      expect(g.carPos[3], 4); // blocked by Car 2 on Chicane!

      // Now clear the Chicane and play a speed card that moves Car 0 to Betting Line 1 (space 6)
      g.carPos[2] = 0;
      g.hands[0][0] = {0: 6, 1: 4};
      g.handle(0, {'type': 'play', 'cardIdx': 0});
      expect(g.phase, 'bet');
      expect(g.betStage, 0);

      g.handle(0, {'type': 'bet', 'car': 0});
      g.handle(1, {'type': 'bet', 'car': 1});
      expect(g.phase, 'race');
      expect(g.betStage, 1);
    });
  });

  test('simulate all party16 games (30 seeds per player count & option)', () {
    final failures = runSims(party16Games, n: 30);
    expect(failures, 0);
  });
}
