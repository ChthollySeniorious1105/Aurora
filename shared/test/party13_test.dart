import 'dart:math';

import 'package:aurora_shared/games/party13/defs.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(
  int n, {
  Map<String, dynamic> opts = const {},
  bool bots = false,
  int seed = 42,
}) =>
    GameSetup(
      players: n,
      options: opts,
      names: [for (var i = 0; i < n; i++) 'P$i'],
      bots: List.filled(n, bots),
      rng: Random(seed),
    );

T _start<T extends GameEngine>(T e) {
  final h = SimHost();
  e.host = h;
  e.start();
  h.runPending();
  return e;
}

void main() {
  group('noirkiller (黑色追缉令)', () {
    test('secret identities hidden in view(seat) and shift wraps around', () {
      final g = _start(NoirKillerGame(_setup(2)));
      // Seat 0 sees killerSuspect, hides inspectorSuspect
      expect(g.view(0)['killerSuspect'], g.killerSuspect);
      expect(g.view(0)['inspectorSuspect'], -1);
      // Seat 1 sees inspectorSuspect, hides killerSuspect
      expect(g.view(1)['killerSuspect'], -1);
      expect(g.view(1)['inspectorSuspect'], g.inspectorSuspect);
      // Spectator sees neither
      expect(g.view(-1)['killerSuspect'], -1);
      expect(g.view(-1)['inspectorSuspect'], -1);

      final row0Before = List<int>.of(g.grid[0]);
      g.handle(0, {'type': 'shift', 'axis': 'row', 'index': 0, 'dir': 1});
      expect(g.grid[0], [
        row0Before[4],
        row0Before[0],
        row0Before[1],
        row0Before[2],
        row0Before[3],
      ]);

      // Inspector cannot immediately reverse Killer's shift
      expect(
        () => g.handle(1, {'type': 'shift', 'axis': 'row', 'index': 0, 'dir': -1}),
        throwsA(isA<GameError>()),
      );
    });

    test('killer kill adjacent, disguise, and inspector accuse win', () {
      final g = _start(NoirKillerGame(_setup(2)));
      g.grid = [
        for (var r = 0; r < 5; r++) [for (var c = 0; c < 5; c++) r * 5 + c]
      ];
      g.killerSuspect = 6; // (1, 1)
      g.inspectorSuspect = 12; // (2, 2), adjacent to 6!

      // Non-adjacent kill fails
      expect(
        () => g.handle(0, {'type': 'kill', 'target': 24}),
        throwsA(isA<GameError>()),
      );

      // Adjacent kill succeeds
      g.handle(0, {'type': 'kill', 'target': 0});
      expect(g.status[0], 2);
      expect(g.deadCount, 1);
      expect(g.turn, 1);

      // Inspector accuses killer (6 is 8-way adjacent to 12) -> Inspector wins!
      g.handle(1, {'type': 'accuse', 'target': 6});
      expect(g.isOver, isTrue);
      expect(g.winner, 'inspector');
      expect(g.placings, [2, 1]);
    });

    test('killer disguise swaps identity and exonerates old suspect', () {
      final g = _start(NoirKillerGame(_setup(2)));
      final oldKiller = g.killerSuspect;
      g.evidenceDeck = [10];
      g.status[10] = 0;
      g.handle(0, {'type': 'disguise'});
      expect(g.status[oldKiller], 1);
      expect(g.killerSuspect, 10);
    });
  });

  group('cartographers (制图师)', () {
    test('mountain surround grants gold coin and monster penalty counts empty orthogonal neighbors', () {
      final g = _start(CartographersGame(_setup(2)));
      // Surround mountain at (1, 2) on seat 0's map
      g.maps[0][0][2] = 1;
      g.maps[0][2][2] = 1;
      g.maps[0][1][1] = 2;
      g.maps[0][1][3] = 2;
      g.updateCoinsForSeat(0);
      expect(g.coins[0], 1);

      // Place a monster at (4, 1) -> orthogonal neighbors (3,1), (5,1=mountain!), (4,0), (4,2)
      // (5,1) is already a mountain (5), so 3 empty neighbors!
      g.maps[0][4][1] = 6;
      expect(countMonsterPenalty(g.maps[0]), 3);
    });

    test('simultaneous placement advances time and triggers season scoring', () {
      final g = _start(CartographersGame(_setup(2, opts: {'mode': 'fast'})));
      g.currentCard = const ExploreCardDef(
        id: 'test_card',
        name: '测试卡',
        time: 5,
        terrainOptions: [1, 2],
        shapes: [
          [
            [0, 0],
            [0, 1],
          ]
        ],
      );
      g.handle(0, {
        'type': 'place',
        'terrain': 1,
        'cells': [
          [0, 0],
          [0, 1]
        ],
      });
      expect(g.waitingFor, [1]);
      g.handle(1, {
        'type': 'place',
        'terrain': 2,
        'cells': [
          [0, 0],
          [1, 0]
        ],
      });
      // Season 0 threshold in fast mode is 5, so season advances to 1 (Summer)!
      expect(g.season, 1);
    });
  });

  group('flip7 (翻转七号)', () {
    test('pyramid deck has 79 number cards and 94 total cards', () {
      expect(buildFlip7NumberCards().length, 79);
      expect(buildFlip7FullDeck().length, 94);
    });

    test('duplicate bust vs Second Chance protection', () {
      final g = _start(Flip7Game(_setup(2)));
      g.turn = 0;
      g.numberCards[0] = [5, 8];
      g.hasSecondChance[0] = true;
      g.deck.add('8'); // Duplicate 8!
      g.handle(0, {'type': 'hit'});
      // Second Chance saves seat 0 from busting!
      expect(g.playerStatus[0], 'active');
      expect(g.hasSecondChance[0], isFalse);

      // Next turn back to seat 0: duplicate without Second Chance busts!
      g.turn = 0;
      g.deck.add('5');
      g.handle(0, {'type': 'hit'});
      expect(g.playerStatus[0], 'busted');
    });

    test('Flip 7 instant bonus ends round immediately and grants +15 pts', () {
      final g = _start(Flip7Game(_setup(2)));
      g.turn = 0;
      g.numberCards[0] = [1, 2, 3, 4, 5, 6];
      g.modifiers[0] = ['+4'];
      g.deck.add('7');
      g.handle(0, {'type': 'hit'});
      // Sum 1..7 = 28, +4 modifier = 32, +15 Flip 7 bonus = 47!
      expect(g.scores[0], 47);
      expect(g.round, 2);
    });
  });

  group('shadowhunters (暗影猎人)', () {
    test('roles hidden in view until revealed or dead', () {
      final g = _start(ShadowHuntersGame(_setup(4)));
      final v0 = g.view(0)['players'] as List;
      expect(v0[0]['role'], g.roles[0]);
      expect(v0[1]['role'], '?');
      expect((g.view(-1)['players'] as List)[0]['role'], '?');

      g.turn = 0;
      g.handle(0, {'type': 'reveal'});
      expect((g.view(1)['players'] as List)[0]['role'], g.roles[0]);
    });

    test('move, attack, and faction win conditions', () {
      final g = _start(ShadowHuntersGame(_setup(5)));
      g.roles = ['werewolf', 'vampire', 'emi', 'franklin', 'daniel'];
      g.turn = 0;
      g.phase = 'move';
      g.handle(0, {'type': 'move', 'zone': 3});
      expect(g.zones[0], 3);
      expect(g.phase, 'action');

      // Test Daniel first-to-die win condition
      g.dealDamage(4, 20, killer: 0);
      expect(g.isOver, isTrue);
      expect(g.winners.contains(4), isTrue);
    });
  });

  test('party13 sims (count: 30)', () {
    expect(runSims(party13Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
