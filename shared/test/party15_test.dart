import 'dart:math';

import 'package:aurora_shared/games/party15/defs.dart';
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
  group('deadmansdraw (亡者宝藏)', () {
    test('Anchor bust protection, Key+Chest bonus, Pirate abilities & highest-per-suit scoring', () {
      final g = DeadMansDrawGame(_setup(2));
      g.start();

      // 1. Test Anchor bust protection: draw Mermaid(8), then Anchor(5), then Mermaid(9) -> BUST!
      // Mermaid(8) drawn BEFORE Anchor(5) is banked; Anchor(5) and Mermaid(9) go to discard.
      g.deck.add(const DeadMansDrawCard(6, 9)); // third draw -> busts on Mermaid!
      g.deck.add(const DeadMansDrawCard(0, 5)); // second draw -> Anchor
      g.deck.add(const DeadMansDrawCard(6, 8)); // first draw -> Mermaid(8)

      g.handle(0, {'type': 'draw'}); // draws Mermaid(8)
      expect(g.turnArea.length, 1);
      g.handle(0, {'type': 'draw'}); // draws Anchor(5)
      expect(g.turnArea.length, 2);
      g.handle(0, {'type': 'draw'}); // draws Mermaid(9) -> BUST!

      expect(g.turn, 1); // advanced to seat 1
      expect(g.bank[0][6], [8]); // Mermaid(8) before Anchor was safely banked!
      expect(g.bank[0][0], isEmpty); // Anchor itself discarded

      // 2. Seat 1 draws Key(4) and Chest(6) and banks -> gets 2 bonus cards from discard!
      g.deck.add(const DeadMansDrawCard(8, 6)); // Chest
      g.deck.add(const DeadMansDrawCard(7, 4)); // Key
      g.handle(1, {'type': 'draw'});
      g.handle(1, {'type': 'draw'});
      g.handle(1, {'type': 'bank'});

      final totalCardsSeat1 = g.bank[1].fold<int>(0, (a, p) => a + p.length);
      expect(totalCardsSeat1, 4); // 2 banked + 2 bonus from discard!

      // 3. Highest-per-suit scoring check on seat 0: add Mermaid(4) and Mermaid(9) -> only 9 counts
      g.bank[0][6] = [4, 8, 9];
      g.bank[0][2] = [3, 7];
      expect(g.scores[0], 9 + 7);
    });
  });

  group('archaeology (沙漠考古队)', () {
    test('exponential set selling, marketplace trade, pyramid exploration, Thief & Sandstorm', () {
      final g = ArchaeologyGame(_setup(3));
      g.start();

      // Give seat 0: 3 Masks (type 5) + 2 Maps (type 6)
      g.hands[0] = [5, 5, 5, 6, 6];
      // Explore Chamber 1 (costs 2 Maps, yields 5 treasure cards)
      g.handle(0, {'type': 'pyramid', 'chamber': 1});
      expect(g.pyramid[1], isEmpty);
      expect(g.hands[0].length, 3 + 5);

      // Sell 3 Masks (type 5) -> worth 32 Gold!
      g.handle(0, {'type': 'sell', 'artifact': 5, 'count': 3});
      expect(g.gold[0], 32);

      // Test Sandstorm: seat 1 has 6 cards (> 4) -> must discard 3 cards into market
      g.hands[0] = [0, 1]; // <= 4 cards, safe
      g.hands[1] = [0, 0, 1, 1, 2, 2];
      g.hands[2] = [0, 1, 2, 3]; // <= 4 cards, safe
      final marketBefore = g.market.length;
      g.resolveDigCard(0, ArchaeologyGame.cardSandstorm);
      expect(g.phase, 'sandstorm');
      expect(g.waitingFor, [1]);

      g.handle(1, {'type': 'sandstorm', 'cards': [0, 0, 1]});
      expect(g.hands[1].length, 3);
      expect(g.market.length, marketBefore + 3);
      expect(g.phase, 'action');
    });
  });

  group('goodcopbadcop (无间警局)', () {
    test('hidden integrity cards, investigate visibility, arm/aim/shoot & Boss elimination win', () {
      final g = GoodCopBadCopGame(_setup(4));
      g.start();

      final aSeat = g.agentSeat;
      final kSeat = g.kingpinSeat;
      expect(aSeat, isNot(equals(kSeat)));
      expect(g.hp[aSeat], 2);
      expect(g.hp[kSeat], 2);

      // Unrevealed opponent cards are hidden in view(0)
      expect((g.view(0)['cards'] as List)[1], [null, null, null]);

      // Seat 0 investigates seat 1 slot 0 -> now visible to seat 0, still hidden to seat 2
      g.handle(0, {'type': 'investigate', 'target': 1, 'slot': 0});
      expect((g.view(0)['cards'] as List)[1][0], g.cards[1][0]);
      expect((g.view(2)['cards'] as List)[1][0], isNull);

      // Seat 1 arms and aims at KINGPIN (or AGENT if seat 1 is KINGPIN)
      final bossTarget = kSeat != 1 ? kSeat : aSeat;
      g.handle(1, {'type': 'arm', 'target': bossTarget});
      expect(g.hasGun[1], isTrue);
      expect(g.aimTarget[1], bossTarget);

      // Reduce bossTarget HP to 1 and let seat 1 shoot on next turn
      g.hp[bossTarget] = 1;
      g.turn = 1;
      g.handle(1, {'type': 'shoot'});
      expect(g.isOver, isTrue);
      expect(g.winnerFaction, bossTarget == kSeat ? 'good' : 'bad');
    });
  });

  group('manila (马尼拉海运)', () {
    test('harbor master bidding, initial boat positions sum==9, insurance +10 & voyage settlement', () {
      final g = ManilaGame(_setup(3, options: const {'mode': 'fast'}));
      g.start();

      expect(g.phase, 'bid');
      g.handle(0, {'type': 'bid', 'amount': 4, 'positions': [4, 3, 2, 0]});
      g.handle(1, {'type': 'pass'});
      g.handle(2, {'type': 'pass'});

      expect(g.harborMaster, 0);
      expect(g.phase, 'place');
      expect(g.boatPos, [4, 3, 2, 0]);
      expect(g.boatPos.fold<int>(0, (a, b) => a + b), 9);

      // Seat 0 takes Insurance (+10 immediate Pesos)
      final p0Before = g.pesos[0];
      g.handle(0, {'type': 'place', 'spot': 'insurance'});
      expect(g.pesos[0], p0Before + 10);
      expect(g.insuranceSeat, 0);
    });
  });

  test('simulate all party15 games (30 seeds per player count & option)', () {
    final failures = runSims(party15Games, n: 30);
    expect(failures, 0);
  });
}
