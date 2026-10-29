import 'dart:math';

import 'package:aurora_shared/games/euro7/alhambra.dart';
import 'package:aurora_shared/games/euro7/defs.dart';
import 'package:aurora_shared/games/euro7/dominion.dart';
import 'package:aurora_shared/games/euro7/sheriff.dart';
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
  group('dominion', () {
    test('initial deck, draw 5, play treasures, buy, end turn', () {
      final e = _start(DominionGame(_setup(2)));
      expect(e.hand[0].length, 5);
      expect(e.deck[0].length, 5);
      expect(e.supply['province'], 8);
      expect(e.scoreOf(0), 3);

      e.hand[0] = ['copper', 'copper', 'copper', 'estate', 'estate'];
      e.handle(0, {'type': 'play_treasures'});
      expect(e.coins, 3);
      expect(e.hand[0].length, 2);
      e.handle(0, {'type': 'buy', 'card': 'silver'});
      expect(e.buys, 0);
      expect(e.coins, 0);
      expect(e.discard[0].contains('silver'), isTrue);

      e.handle(0, {'type': 'end_turn'});
      expect(e.turn, 1);
      expect(e.hand[0].length, 5);
    });

    test('chapel trash, workshop gain, moneylender', () {
      final e = _start(DominionGame(_setup(2)));
      e.hand[0] = ['chapel', 'estate', 'copper', 'workshop', 'moneylender'];
      e.actions = 3;

      e.handle(0, {'type': 'play', 'card': 'chapel'});
      expect(e.phase, 'chapel');
      e.handle(0, {
        'type': 'chapel_trash',
        'cards': ['estate'],
      });
      expect(e.phase, 'turn');
      expect(e.trash, ['estate']);

      e.handle(0, {'type': 'play', 'card': 'workshop'});
      expect(e.phase, 'workshop');
      expect(() => e.handle(0, {'type': 'workshop_gain', 'card': 'market'}), throwsA(isA<GameError>()));
      e.handle(0, {'type': 'workshop_gain', 'card': 'smithy'});
      expect(e.phase, 'turn');
      expect(e.discard[0].contains('smithy'), isTrue);

      e.handle(0, {'type': 'play', 'card': 'moneylender'});
      expect(e.coins, 3);
      expect(e.trash.contains('copper'), isTrue);
    });

    test('witch curses opponents unless moat is in hand', () {
      final e = _start(DominionGame(_setup(3)));
      e.hand[0] = ['witch'];
      e.hand[1] = ['moat', 'copper'];
      e.hand[2] = ['copper', 'estate'];

      e.handle(0, {'type': 'play', 'card': 'witch'});
      expect(e.discard[1].contains('curse'), isFalse);
      expect(e.discard[2].contains('curse'), isTrue);
    });

    test('game ends when province pile is empty', () {
      final e = _start(DominionGame(_setup(2, {'provinces': 5})));
      expect(e.supply['province'], 5);
      e.supply['province'] = 1;
      e.coins = 8;
      e.handle(0, {'type': 'buy', 'card': 'province'});
      e.handle(0, {'type': 'end_turn'});
      expect(e.isOver, isTrue);
      expect(e.placings, isNotNull);
    });
  });

  group('alhambra', () {
    test('take 1 money of any value or 2+ money with sum <= 5', () {
      final e = _start(AlhambraGame(_setup(2)));
      e.moneyMarket
        ..clear()
        ..addAll(const [
          AlhambraMoney(0, 8),
          AlhambraMoney(1, 2),
          AlhambraMoney(2, 3),
          AlhambraMoney(3, 4),
        ]);
      final h0 = e.hand[0].length;
      // Cannot take 2 cards with sum > 5
      expect(
        () => e.handle(0, {
          'type': 'take_money',
          'indices': [1, 3],
        }),
        throwsA(isA<GameError>()),
      );
      // Can take 2 cards with sum == 5 (2 + 3)
      e.handle(0, {
        'type': 'take_money',
        'indices': [1, 2],
      });
      expect(e.hand[0].length, h0 + 2);
      expect(e.turn, 1);

      // Player 1 can take a single high-value card (value 8)
      final h1 = e.hand[1].length;
      e.handle(1, {
        'type': 'take_money',
        'indices': [0],
      });
      expect(e.hand[1].length, h1 + 1);
    });

    test('exact change grants bonus action, overpayment ends turn', () {
      final e = _start(AlhambraGame(_setup(2)));
      e.tileMarket[0] = const AlhambraTile(id: 0, type: 2, cost: 5, walls: 1 | 2);
      e.tileMarket[1] = const AlhambraTile(id: 1, type: 4, cost: 6, walls: 4);
      e.hand[0] = [
        const AlhambraMoney(0, 2),
        const AlhambraMoney(0, 3),
        const AlhambraMoney(1, 8),
      ];

      // Exact payment (2 + 3 == 5) keeps turn on seat 0!
      e.handle(0, {
        'type': 'buy_tile',
        'slot': 0,
        'cards': [0, 1],
      });
      expect(e.turn, 0);
      expect(e.bonusAction, isTrue);
      expect(e.buildings[0][2], 1);
      expect(e.walls[0], 2);

      // Overpayment (8 > 6) on bonus action finishes turn
      e.handle(0, {
        'type': 'buy_tile',
        'slot': 1,
        'cards': [0],
      });
      expect(e.turn, 1);
      expect(e.bonusAction, isFalse);
      expect(e.buildings[0][4], 1);
      expect(e.walls[0], 3);
    });

    test('majority scoring and wall length points', () {
      final e = _start(AlhambraGame(_setup(3)));
      e.buildings[0][5] = 3; // Tower (type 5): P0 has 1st
      e.buildings[1][5] = 2; // P1 has 2nd
      e.buildings[2][5] = 1; // P2 has 3rd
      e.walls[0] = 4;
      e.walls[1] = 2;
      e.walls[2] = 1;

      e.scoreRound(2); // 3rd round scoring for type 5: [21, 13, 6]
      expect(e.scores[0], 21 + 4);
      expect(e.scores[1], 13 + 2);
      expect(e.scores[2], 6 + 1);
    });
  });

  group('sheriff', () {
    test('pass transfers bribe and puts all bagged cards on stand', () {
      final e = _start(SheriffGame(_setup(3)));
      expect(e.sheriff, 0);
      e.hand[1] = [0, 4, 5, 1, 2, 3]; // Apple + Pepper + Mead
      e.hand[2] = [1, 1, 2, 2, 3, 3];

      e.handle(1, {
        'type': 'pack',
        'indices': [0, 1, 2],
        'declared': 0,
        'bribe': 4,
      });
      e.handle(2, {
        'type': 'pack',
        'indices': [0, 1],
        'declared': 1,
        'bribe': 0,
      });

      expect(e.phase, 'inspect');
      expect(e.currentMerchant, 1);

      // Sheriff passes Merchant 1
      e.handle(0, {'type': 'pass'});
      expect(e.gold[0], 54);
      expect(e.gold[1], 46);
      expect(e.stand[1][0], 1);
      expect(e.stand[1][4], 1);
      expect(e.stand[1][5], 1);
    });

    test('open honest bag pays merchant penalty, open lying bag confiscates and fines', () {
      final e = _start(SheriffGame(_setup(3)));
      e.hand[1] = [0, 0, 0, 1, 2, 3]; // 3 Apples (honest)
      e.hand[2] = [3, 6, 7, 0, 1, 2]; // 1 Chicken + Silk (penalty 4) + Crossbow (penalty 4)

      e.handle(1, {
        'type': 'pack',
        'indices': [0, 1, 2],
        'declared': 0,
        'bribe': 3,
      });
      e.handle(2, {
        'type': 'pack',
        'indices': [0, 1, 2],
        'declared': 3,
        'bribe': 5,
      });

      // Sheriff opens honest Merchant 1 (3 Apples -> penalty 2 * 3 = 6)
      e.handle(0, {'type': 'open'});
      expect(e.gold[0], 44);
      expect(e.gold[1], 56); // Kept bribe and gained 6 compensation
      expect(e.stand[1][0], 3);

      // Sheriff opens lying Merchant 2 (1 Chicken passes, Silk+Crossbow confiscated -> penalty 4 + 4 = 8)
      e.handle(0, {'type': 'open'});
      expect(e.gold[0], 44 + 8);
      expect(e.gold[2], 50 - 8);
      expect(e.stand[2][3], 1);
      expect(e.stand[2][6], 0);
      expect(e.stand[2][7], 0);
    });

    test('king and queen bonuses at game end', () {
      final e = _start(SheriffGame(_setup(3)));
      e.stand[0][0] = 5; // Apple King (+15)
      e.stand[1][0] = 3; // Apple Queen (+10)
      e.stand[2][3] = 4; // Chicken King (+10)
      final bonuses = e.computeKingQueenBonuses();
      expect(bonuses[0], 15);
      expect(bonuses[1], 10);
      expect(bonuses[2], 10);
    });
  });

  test('sims', () {
    expect(runSims(euro7Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
