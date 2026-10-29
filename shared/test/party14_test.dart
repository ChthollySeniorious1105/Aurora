import 'dart:math';

import 'package:aurora_shared/games/party14/defs.dart';
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
  group('notalone (绝命异星)', () {
    test('asymmetric setup, hidden hands, explore/hunt resolution, give_up, and rover unlock', () {
      final g = NotAloneGame(_setup(3));
      g.start();

      expect(g.rescueLeft, 11);
      expect(g.assimilationLeft, 9); // 6 + 3
      expect(g.waitingFor, [1, 2]);

      // Creature (seat 0) cannot see Hunted hands in view(0)
      final v0 = g.view(0);
      expect((v0['hands'] as List)[1], isEmpty);
      expect((v0['hands'] as List)[2], isEmpty);
      expect((g.view(1)['hands'] as List)[1], [1, 2, 3, 4, 5]);

      // Seat 1 plays 5 (Rover -> unlocks a 6..10 card), Seat 2 plays 4 (Beach -> rescue -1)
      g.handle(1, {'type': 'explore', 'place': 5, 'unlock': 9});
      expect(g.waitingFor, [2]);
      g.handle(2, {'type': 'explore', 'place': 4});
      expect(g.phase, 'hunt');
      expect(g.waitingFor, [0]);

      // Creature hunts location 4 (catches Seat 2 on Beach; Seat 1 on Rover is safe!)
      g.handle(0, {'type': 'hunt', 'targets': [4]});

      // Seat 1 resolved Rover (unlocked 9 into hand), Seat 2 was caught on 4 (will 3->2, assimilation 9->8), end of round rescue 11->10
      expect(g.hands[1].contains(9), isTrue);
      expect(g.will[2], 2);
      expect(g.assimilationLeft, 8);
      expect(g.rescueLeft, 10);
      expect(g.phase, 'explore');

      // Round 2: Seat 1 gives up -> will restored to 3, discards returned to hand, assimilation 8->7
      g.handle(1, {'type': 'give_up'});
      expect(g.assimilationLeft, 7);
      expect(g.discards[1], isEmpty);
    });
  });

  group('qe (量化宽松)', () {
    test('unlimited bidding, zero-bid +2 VP, secret totalSpent visibility, and hyperinflation elimination', () {
      final g = QeGame(_setup(3, options: const {'mode': 'fast'}));
      g.start();

      expect(g.companies.length, 8);
      expect(g.phase, 'open_bid');
      expect(g.waitingFor, [0]);

      // Secret industry is hidden from other seats
      expect((g.view(0)['secretIndustry'] as List)[0], isNotNull);
      expect((g.view(0)['secretIndustry'] as List)[1], isNull);

      // Round 1: seat 0 auctioneer opens at 100, seat 1 bids 500000, seat 2 bids 0 (+2 VP restraint)
      g.handle(0, {'type': 'open_bid', 'amount': 100});
      expect(g.phase, 'sealed_bid');
      expect(g.waitingFor, [1, 2]);
      g.handle(1, {'type': 'sealed_bid', 'amount': 500000});
      g.handle(2, {'type': 'sealed_bid', 'amount': 0});

      expect(g.zeroBidVp[2], 2);
      // Winner is seat 1 (500000). Only seat 1 (winner) and seat 0 (this round's auctioneer) can see totalSpent[1] / winBid!
      expect((g.view(1)['totalSpent'] as List)[1], 500000);
      expect((g.view(0)['totalSpent'] as List)[1], 500000);
      expect((g.view(2)['totalSpent'] as List)[1], isNull);
      expect((g.view(2)['lastAuction'] as Map)['winBid'], isNull);

      // Play remaining 7 rounds with modest bids from seat 0 and seat 2 so seat 1 has highest totalSpent
      for (var r = 1; r < 8; r++) {
        final auct = g.auctioneer;
        g.handle(auct, {'type': 'open_bid', 'amount': 10});
        for (var s = 0; s < 3; s++) {
          if (s == auct) continue;
          g.handle(s, {'type': 'sealed_bid', 'amount': s == 1 ? 0 : 20});
        }
      }

      expect(g.isOver, isTrue);
      // Seat 1 spent 500000 (highest) -> eliminated for Hyperinflation!
      expect(g.eliminated[1], isTrue);
      expect(g.eliminated[0], isFalse);
      expect(g.eliminated[2], isFalse);
      // Eliminated player cannot place 1st
      expect(g.placings![1], greaterThan(1));
      expect(g.placings!.contains(1), isTrue);
    });
  });

  group('similo (相似物语)', () {
    test('secret target hidden from guessers, 5 rounds quota [1,2,3,4,1] victory & target elimination defeat', () {
      // 1. Test full 5-round victory
      final g = SimiloGame(_setup(3, seed: 10));
      g.start();
      final target = g.view(0)['secretTarget'] as int;
      expect(g.view(1)['secretTarget'], isNull);
      expect(g.view(-1)['secretTarget'], isNull);

      const quotas = [1, 2, 3, 4, 1];
      for (var r = 0; r < 5; r++) {
        expect(g.phase, 'clue');
        g.handle(0, {'type': 'clue', 'cardIdx': 0, 'similar': r.isEven});
        expect(g.phase, 'eliminate');
        for (var q = 0; q < quotas[r]; q++) {
          final safeSlot = [for (var i = 0; i < 12; i++) i]
              .firstWhere((i) => i != target && !g.eliminated[i]);
          g.handle(1, {'type': 'eliminate', 'slot': safeSlot});
        }
      }
      expect(g.isOver, isTrue);
      expect(g.won, isTrue);
      expect(g.placings, [1, 1, 1]);

      // 2. Test eliminating secretTarget causes immediate defeat
      final g2 = SimiloGame(_setup(2, seed: 20));
      g2.start();
      final target2 = g2.view(0)['secretTarget'] as int;
      g2.handle(0, {'type': 'clue', 'cardIdx': 0, 'similar': true});
      g2.handle(1, {'type': 'eliminate', 'slot': target2});
      expect(g2.isOver, isTrue);
      expect(g2.won, isFalse);
    });
  });

  group('spicy (猫吃三椒)', () {
    test('single-attribute challenge check, wild cards, and hand-empty +10 VP trophy', () {
      final g = SpicyGame(_setup(3, seed: 99));
      g.start();

      // Force seat 0's first card to be ('chili', 2)
      g.hands[0][0] = {'id': 901, 'type': 'normal', 'kind': 'normal', 'spice': 'chili', 'num': 2};
      // Seat 0 plays ('chili', 2) but claims ('chili', 3) -> Spice is TRUE, Num is FALSE!
      g.handle(0, {'type': 'play', 'cardIdx': 0, 'spice': 'chili', 'num': 3});

      // Seat 1 challenges SPICE ('spice') -> since actual spice IS 'chili', declarer (seat 0) wins challenge!
      g.handle(1, {'type': 'challenge', 'attr': 'spice'});
      expect(g.wonCards[0], 1);
      expect(g.turn, 1); // Loser (seat 1) goes next

      // Now test WILD_SPICE failing 'num' check
      g.hands[1][0] = {'id': 902, 'type': 'WILD_SPICE', 'kind': 'WILD_SPICE', 'spice': 'WILD_SPICE', 'num': 0};
      g.handle(1, {'type': 'play', 'cardIdx': 0, 'spice': 'wasabi', 'num': 2});
      g.handle(2, {'type': 'challenge', 'attr': 'num'});
      // WILD_SPICE fails 'num' check -> challenger (seat 2) wins!
      expect(g.wonCards[2], 1);
      expect(g.turn, 1);

      // Test emptying hand awards +10 VP Trophy
      g.hands[1] = [
        {'id': 903, 'type': 'normal', 'kind': 'normal', 'spice': 'pepper', 'num': 1},
      ];
      g.handle(1, {'type': 'play', 'cardIdx': 0, 'spice': 'pepper', 'num': 1});
      expect(g.trophies[1], 1);
      expect(g.scores[1], 10);
    });
  });

  test('simulate all party14 games (30 seeds per player count & option)', () {
    final failures = runSims(party14Games, n: 30);
    expect(failures, 0);
  });
}
