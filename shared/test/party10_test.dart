import 'dart:math';

import 'package:aurora_shared/games/party10/defs.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameDef _def(String id) => party10Games.firstWhere((d) => d.id == id);

T _start<T extends GameEngine>(
  String id,
  int players, {
  Map<String, dynamic> opts = const {},
  int seed = 42,
}) {
  final def = _def(id);
  final setup = GameSetup(
    players: players,
    options: def.normalizeOptions(opts),
    names: [for (var i = 0; i < players; i++) 'P$i'],
    bots: List.filled(players, true),
    hostSeat: 0,
    rng: Random(seed),
  );
  final e = def.create(setup) as T;
  e.start();
  return e;
}

void main() {
  test('runSims party10 (30 games per player count & option)', () {
    expect(runSims(party10Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 10)));

  group('Scotland Yard (苏格兰场)', () {
    test('Mister X position is hidden except on reveal rounds (3, 8, 13, 18)', () {
      final e = _start<ScotlandYardGame>('scotlandyard', 3);
      expect(e.round, 1);
      expect(e.view(0)['misterXPos'], e.positions[0]);
      expect(e.view(1)['misterXPos'], isNull);
      expect(e.view(-1)['misterXPos'], isNull);

      // Play rounds 1 and 2, verify still hidden on round 2, then revealed on round 3.
      while (e.round < 3 && !e.isOver) {
        final s = e.turn;
        e.handle(s, e.runBot(s)!);
      }
      if (!e.isOver) {
        expect(e.round, 3);
        expect(e.view(1)['misterXPos'], e.positions[0]);
      }
    });

    test('Detective ticket transfers to Mister X; capture wins for Detectives', () {
      final e = _start<ScotlandYardGame>('scotlandyard', 3);
      e.positions[0] = 1; // Baker Street
      e.positions[1] = 2; // Regent's Park (adjacent to 1 via taxi & bus)
      e.positions[2] = 20;

      // Mister X moves from 1 -> 5 via taxi
      final xMove = e.legalMovesFor(0).firstWhere((m) => m['to'] == 5);
      e.handle(0, {'type': 'move', 'to': 5, 'ticket': xMove['ticket']});
      expect(e.positions[0], 5);
      expect(e.turn, 1);

      final xTaxiBefore = e.tickets[0]['taxi']!;
      final d1TaxiBefore = e.tickets[1]['taxi']!;

      // Detective 1 moves from 2 -> 5 via taxi, landing on Mister X!
      e.handle(1, {'type': 'move', 'to': 5, 'ticket': 'taxi'});
      expect(e.tickets[1]['taxi'], d1TaxiBefore - 1);
      expect(e.tickets[0]['taxi'], xTaxiBefore + 1);
      expect(e.isOver, isTrue);
      expect(e.winner, 'detectives');
      expect(e.placings, [2, 1, 1]);
    });

    test('Mister X double ticket allows two consecutive moves', () {
      final e = _start<ScotlandYardGame>('scotlandyard', 2);
      final doublesBefore = e.tickets[0]['double']!;
      e.handle(0, {'type': 'double'});
      expect(e.tickets[0]['double'], doublesBefore - 1);
      expect(e.doubleMovesLeft, 2);

      final m1 = e.legalMovesFor(0).first;
      e.handle(0, {'type': 'move', 'to': m1['to'], 'ticket': m1['ticket']});
      expect(e.turn, 0); // Still Mister X's turn for second move!
      expect(e.doubleMovesLeft, 1);

      final m2 = e.legalMovesFor(0).first;
      e.handle(0, {'type': 'move', 'to': m2['to'], 'ticket': m2['ticket']});
      expect(e.doubleMovesLeft, 0);
      expect(e.turn, 1);
    });
  });

  group('Colt Express (疯狂快车)', () {
    test('Scheming phase plays face-up/face-down and transitions to stealin', () {
      final e = _start<ColtExpressGame>('coltexpress', 3);
      expect(e.phase, 'scheming');

      // Turn 0 of scheming is normal (faceUp = true)
      final s0 = e.turn;
      final idx0 = e.hands[s0].indexWhere((c) => c != 'bullet');
      e.handle(s0, {'type': 'play', 'index': idx0});
      expect(e.programStack.last['faceUp'], isTrue);
      expect((e.view((s0 + 1) % 3)['programStack'] as List).last['card'], isNot('hidden'));

      // Finish remaining players in scheme turn 0
      for (var i = 1; i < 3; i++) {
        e.handle(e.turn, {'type': 'draw'});
      }

      // Turn 1 of scheming is a Tunnel turn (faceUp = false)
      expect(e.isTunnelTurn, isTrue);
      final s1 = e.turn;
      final idx1 = e.hands[s1].indexWhere((c) => c != 'bullet');
      e.handle(s1, {'type': 'play', 'index': idx1});
      expect(e.programStack.last['faceUp'], isFalse);
      // Hidden from other players during scheming
      expect((e.view((s1 + 1) % 3)['programStack'] as List).last['card'], 'hidden');
      // Visible to self
      expect((e.view(s1)['programStack'] as List).last['card'], isNot('hidden'));
    });

    test('Action resolution: rob, punch, shoot, and marshal', () {
      final e = _start<ColtExpressGame>('coltexpress', 3);
      e.phase = 'stealin';
      e.carPos = [1, 1, 2];
      e.onRoof = [false, false, false];
      e.marshalCar = 0;
      e.insideLoot[1] = [
        {'type': 'gem', 'value': 500},
      ];
      e.programStack
        ..clear()
        ..addAll([
          {'seat': 0, 'card': 'rob', 'faceUp': true, 'resolved': false},
          {'seat': 1, 'card': 'punch', 'faceUp': true, 'resolved': false},
          {'seat': 2, 'card': 'shoot', 'faceUp': true, 'resolved': false},
          {'seat': 0, 'card': 'marshal', 'faceUp': true, 'resolved': false},
        ]);
      e.execIndex = 0;
      e.turn = 0;

      // 1. Seat 0 robs the $500 gem in car 1
      final lootBefore = e.lootScore(0);
      e.handle(0, {'type': 'resolve'});
      expect(e.lootScore(0), lootBefore + 500);

      // 2. Seat 1 punches Seat 0 in car 1 -> Seat 0 drops highest item ($500 gem) and moves to car 2
      e.handle(1, {'type': 'resolve', 'targetSeat': 0, 'targetCar': 2});
      expect(e.carPos[0], 2);
      expect(e.lootScore(0), lootBefore);
      expect(e.insideLoot[1].any((it) => it['value'] == 500), isTrue);

      // 3. Seat 2 (in car 2) shoots Seat 1 (in adjacent car 1)
      final bullets2Before = e.bulletsLeft[2];
      e.handle(2, {'type': 'resolve', 'targetSeat': 1});
      expect(e.bulletsLeft[2], bullets2Before - 1);
      expect(e.shotsFired[2], 1);
      expect(e.wounds[1], 1);
      expect(e.discards[1].contains('bullet'), isTrue);

      // 4. Seat 0 moves Marshal from car 0 to car 1 -> Seat 1 is inside car 1, gets shot & chased to roof!
      e.handle(0, {'type': 'resolve', 'targetCar': 1});
      expect(e.marshalCar, 1);
      expect(e.onRoof[1], isTrue);
      expect(e.wounds[1], 2);
    });
  });

  group('Heimlich & Co. (特工暗棋)', () {
    test('Secret agent privacy, ruins penalty, safe scoring trigger, and move_safe', () {
      final e = _start<HeimlichGame>('heimlich', 4);
      // Each player sees only their own secret agent
      for (var s = 0; s < 4; s++) {
        expect(e.view(s)['myAgent'], e.secretAgent[s]);
        expect(e.view(s)['secretAgents'], isNull);
      }
      expect(e.view(-1)['myAgent'], isNull);

      // Give agent 0 some points on Building 0 (Ruins -3), agent 1 on Building 8, and land agent 2 on Safe (Building 7)
      e.agentScores[0] = 5;
      e.agentPos[0] = 0; // Ruins (-3)
      e.agentPos[1] = 8; // 8 pts
      e.agentPos[2] = 5;
      e.safeBuilding = 7;
      e.moveBudget = 2;

      final actor = e.turn;
      // Validate sum must equal moveBudget
      expect(
        () => e.handle(actor, {
          'type': 'move',
          'steps': [1, 0, 0, 0, 0, 0, 0],
        }),
        throwsA(isA<GameError>()),
      );

      // Move agent 2 by 2 steps: 5 -> 7 (Safe!), triggering scoring!
      e.handle(actor, {
        'type': 'move',
        'steps': [0, 0, 2, 0, 0, 0, 0],
      });

      expect(e.agentScores[0], 2); // 5 - 3 = 2
      expect(e.agentScores[1], 8); // 0 + 8 = 8
      expect(e.agentScores[2], 7); // 0 + 7 = 7
      expect(e.phase, 'move_safe');
      expect(e.turn, actor);

      // Move safe to building 4
      expect(
        () => e.handle(actor, {'type': 'move_safe', 'building': 7}),
        throwsA(isA<GameError>()),
      );
      e.handle(actor, {'type': 'move_safe', 'building': 4});
      expect(e.safeBuilding, 4);
      expect(e.phase, 'move');
    });

    test('Reaching targetScore ends the game and reveals secret identities', () {
      final e = _start<HeimlichGame>('heimlich', 3, opts: {'target': 28});
      final winAgent = e.secretAgent[1];
      e.agentScores[winAgent] = 25;
      e.agentPos[winAgent] = 7;
      e.safeBuilding = 8;
      e.moveBudget = 1;

      final steps = List<int>.filled(7, 0);
      steps[winAgent] = 1; // 7 -> 8 (Safe! +8 points -> 33 >= 28)
      e.handle(e.turn, {'type': 'move', 'steps': steps});

      expect(e.isOver, isTrue);
      expect(e.view(0)['secretAgents'], isNotNull);
      expect(e.placings![1], 1);
    });
  });
}
