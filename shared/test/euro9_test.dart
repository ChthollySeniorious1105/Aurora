import 'dart:math';

import 'package:aurora_shared/games/euro9/defs.dart';
import 'package:aurora_shared/games/euro9/gizmos.dart';
import 'package:aurora_shared/games/euro9/istanbul.dart';
import 'package:aurora_shared/games/euro9/parks.dart';
import 'package:aurora_shared/games/euro9/ra.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(int n, [Map<String, dynamic> opts = const {}, int seed = 5]) =>
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
  group('parks', () {
    test('turn order follows rear-most hiker and campfire flips on occupied site', () {
      final e = _start(ParksGame(_setup(2)));
      expect(e.turn, 0);
      expect(e.hikers[0], [-1, -1]);
      expect(e.campfireLit[0], isTrue);

      // P0 moves hiker 0 to site 2 (+2 Sun)
      final sun0 = e.resources[0][2];
      e.handle(0, {'type': 'move', 'hiker': 0, 'to': 2});
      expect(e.resources[0][2], sun0 + 2);
      // P1 still has rear-most at -1
      expect(e.turn, 1);

      // P1 moves hiker 0 onto occupied site 2 -> flips P1's campfire to false!
      e.handle(1, {'type': 'move', 'hiker': 0, 'to': 2});
      expect(e.campfireLit[1], isFalse);

      // P0 moves hiker 1 to site 1
      expect(e.turn, 0);
      e.handle(0, {'type': 'move', 'hiker': 1, 'to': 1});

      // Now P1 has hiker 1 at -1 (rear-most), tries to move onto occupied site 1 while campfire is false -> throws!
      expect(e.turn, 1);
      expect(
        () => e.handle(1, {'type': 'move', 'hiker': 1, 'to': 1}),
        throwsA(isA<GameError>()),
      );

      // P1 reaches Trail End (6) -> campfire relights to true!
      e.handle(1, {'type': 'move', 'hiker': 1, 'to': 6});
      expect(e.campfireLit[1], isTrue);
      expect(e.phase, 'end_action');
      e.handle(1, {'type': 'reserve_park', 'park': 0});
      expect(e.reservedParks[1].length, 1);
    });

    test('wildlife acts as wildcard to visit a national park', () {
      final e = _start(ParksGame(_setup(2)));
      e.parksDisplay[0] = 0; // Yellowstone: cost [2, 1, 1, 1], 4 VP
      e.resources[0] = [1, 1, 1, 0, 2]; // missing 1 Tree and 1 Water, covered by 2 Wildlife
      e.handle(0, {'type': 'move', 'hiker': 0, 'to': 6});
      e.handle(0, {'type': 'visit_park', 'park': 0});
      expect(e.visitedParks[0], [0]);
      expect(e.score[0], 4);
      expect(e.resources[0], [0, 0, 0, 0, 0]);
    });
  });

  group('istanbul', () {
    test('assistant drop, pickup, and fountain recall', () {
      final e = _start(IstanbulGame(_setup(2)));
      expect(e.merchantPos[0], IstanbulGame.fountainLoc); // 5
      expect(e.assistants[0], 4);

      // P0 moves 1 step from 5 to 1 (Fabric Warehouse): drops 1 assistant, fills red fabric
      e.handle(0, {'type': 'move', 'to': 1});
      expect(e.merchantPos[0], 1);
      expect(e.assistants[0], 3);
      expect(e.droppedAssistants[0], [1]);
      expect(e.goods[0][0], e.capacity[0]);

      // P1 moves from 5 to 7 (Teahouse)
      e.handle(1, {'type': 'move', 'to': 7});

      // P0 moves from 1 to 0 (Wainwright): drops another assistant, expands capacity
      e.handle(0, {'type': 'move', 'to': 0});
      expect(e.assistants[0], 2);
      expect(e.capacity[0], 3);

      // P1 moves from 7 to 5 (Fountain): recalls dropped assistant at 7
      e.handle(1, {'type': 'move', 'to': 5});
      expect(e.assistants[1], 4);
      expect(e.droppedAssistants[1], isEmpty);

      // P0 moves back from 0 to 1: picks up dropped assistant at 1!
      e.handle(0, {'type': 'move', 'to': 1});
      expect(e.assistants[0], 3);
      expect(e.droppedAssistants[0], [0]);
    });

    test('reaching target rubies triggers end of round and finishes game', () {
      final e = _start(IstanbulGame(_setup(2, {'rubies': 4})));
      e.rubies[0] = 3;
      e.lira[0] = 10;
      e.merchantPos[0] = 9; // 1 step away from 13 (Gem Dealer)
      e.handle(0, {'type': 'move', 'to': 13});
      expect(e.rubies[0], 4);
      expect(e.endTriggered, isTrue);
      expect(e.isOver, isFalse);

      // P1 finishes the round -> game ends
      e.handle(1, {'type': 'move', 'to': 1});
      expect(e.isOver, isTrue);
      expect(e.placings, [1, 2]);
    });
  });

  group('ra', () {
    test('draw, invoke ra, and sun disk auction swap', () {
      final e = _start(RaGame(_setup(2)));
      final first = e.turn;
      final other = 1 - first;
      e.bag.add('gold'); // will be drawn first
      e.handle(first, {'type': 'draw'});
      expect(e.auctionTrack.contains('gold'), isTrue);
      expect(e.turn, other);

      // Other player invokes Ra
      e.handle(other, {'type': 'invoke_ra'});
      expect(e.phase, 'auction');
      expect(e.turn, first);

      final bidDisk = e.sunDisks[first].last;
      final oldCenter = e.centerDisk;
      e.handle(first, {'type': 'bid', 'disk': bidDisk});
      e.handle(other, {'type': 'pass'});

      expect(e.phase, 'play');
      expect(e.tiles[first].contains('gold'), isTrue);
      expect(e.usedDisks[first].contains(oldCenter), isTrue);
      expect(e.centerDisk, bidDisk);
      expect(e.sunDisks[first].contains(bidDisk), isFalse);
    });

    test('civilization and monument scoring', () {
      expect(RaGame.scoreCivilization(1), -5);
      expect(RaGame.scoreCivilization(2), 0);
      expect(RaGame.scoreCivilization(3), 5);
      expect(RaGame.scoreCivilization(4), 10);
      expect(RaGame.scoreCivilization(5), 15);
      expect(RaGame.scoreMonuments(['mon_0', 'mon_0', 'mon_0', 'mon_1']), 2 + 5);
    });
  });

  group('gizmos', () {
    test('pick, file, build, and chain reaction triggers', () {
      final e = _start(GizmosGame(_setup(2)));
      // Give P0 a pick_trigger gizmo for color 0 (Red)
      final pickGizmo = gizmosCatalog.firstWhere(
        (c) => c.kind == 'pick_trigger' && c.triggerColor == 0,
      );
      e.built[0].add(pickGizmo.id);
      e.energyRow[0] = 0; // Red marble at index 0
      final beforeTotal = e.totalMarbles(0);

      // P0 picks Red marble at index 0 -> gains 1 Red + 1 random marble from chain trigger!
      e.handle(0, {'type': 'pick', 'index': 0});
      expect(e.totalMarbles(0), beforeTotal + 2);

      // P1 files a card from Tier 1 display
      e.handle(1, {'type': 'file', 'tier': 1, 'index': 0});
      expect(e.archive[1].length, 1);

      // P0 builds a Tier 1 card
      final targetCard = gizmosCatalog[e.display[0][0]];
      e.marbles[0][targetCard.color] = targetCard.cost;
      e.handle(0, {'type': 'build', 'tier': 1, 'index': 0});
      expect(e.built[0].contains(targetCard.id), isTrue);
    });
  });

  test('sims', () {
    expect(runSims(euro9Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
