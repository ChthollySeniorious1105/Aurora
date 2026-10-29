import 'dart:math';

import 'package:aurora_shared/games/social2/chameleon.dart';
import 'package:aurora_shared/games/social2/defs.dart';
import 'package:aurora_shared/games/social2/secretpolicy.dart';
import 'package:aurora_shared/games/social2/themessage.dart';
import 'package:aurora_shared/src/ai.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(int n, [Map<String, dynamic> opts = const {}, int seed = 1]) => GameSetup(
      players: n,
      options: opts,
      names: [for (var i = 0; i < n; i++) 'P$i'],
      bots: List.filled(n, false),
      rng: Random(seed),
    );

class _CustomAi extends FakeAi {
  final String? Function(AiRequest) fn;
  _CustomAi(this.fn);
  @override
  String? completeNow(AiRequest req) {
    requests.add(req);
    return fn(req);
  }
}

void main() {
  group('secretpolicy', () {
    test('role distribution and knowledge across 5..10 players', () {
      const expected = {
        5: (3, 1, 1),
        6: (4, 1, 1),
        7: (4, 2, 1),
        8: (5, 2, 1),
        9: (5, 3, 1),
        10: (6, 3, 1),
      };
      expected.forEach((n, counts) {
        final r = secretPolicyRoles(n);
        expect(r.length, n);
        expect(r.where((x) => x == 'liberal').length, counts.$1);
        expect(r.where((x) => x == 'agent').length, counts.$2);
        expect(r.where((x) => x == 'leader').length, counts.$3);

        final g = SecretPolicy(_setup(n))..start();
        final leader = g.roles.indexOf('leader');
        final agents = [for (var s = 0; s < n; s++) if (g.roles[s] == 'agent') s];
        final lib = g.roles.indexOf('liberal');

        expect(g.knowledge(lib), isEmpty);
        for (final a in agents) {
          expect(g.knowledge(a)['$leader'], '幕后首脑');
        }
        if (n <= 6) {
          expect(g.knowledge(leader)['${agents.first}'], '潜伏派');
        } else {
          expect(g.knowledge(leader), isEmpty);
        }
        expect(g.view(lib)['roles'], isNull);
        expect(g.view(-1)['myRole'], isNull);
      });
    });

    test('3 failed elections trigger chaos auto-enactment and reset term limits', () {
      final g = SecretPolicy(_setup(6))..start();
      g.lastPresident = 1;
      g.lastChancellor = 2;
      for (var i = 0; i < 3; i++) {
        final p = g.president;
        final c = g.eligibleChancellors().first;
        g.handle(p, {'type': 'nominate', 'target': c});
        for (var s = 0; s < 6; s++) {
          g.handle(s, {'type': 'vote', 'vote': 'nein'});
        }
      }
      expect(g.electionTracker, 0);
      expect(g.bluePolicies + g.redPolicies, 1);
      expect(g.lastPresident, -1);
      expect(g.lastChancellor, -1);
    });

    test('shadow leader elected chancellor at >= 3 red policies wins immediately', () {
      final g = SecretPolicy(_setup(5))..start();
      g.redPolicies = 3;
      final leader = g.roles.indexOf('leader');
      g.president = (leader + 1) % 5;
      g.handle(g.president, {'type': 'nominate', 'target': leader});
      for (var s = 0; s < 5; s++) {
        g.handle(s, {'type': 'vote', 'vote': 'ja'});
      }
      expect(g.isOver, true);
      expect(g.winner, 'shadow');
      expect(g.placings![leader], 1);
    });

    test('legislative session, veto power, and execution of leader', () {
      final g = SecretPolicy(_setup(5))..start();
      g.redPolicies = 4;
      final lib = g.roles.indexOf('liberal');
      final leader = g.roles.indexOf('leader');
      final other = [for (var s = 0; s < 5; s++) if (s != lib && s != leader) s].first;
      g.president = lib;
      g.deck = ['blue', 'red', 'red', 'red', 'red'];
      g.handle(lib, {'type': 'nominate', 'target': other});
      for (var s = 0; s < 5; s++) {
        g.handle(s, {'type': 'vote', 'vote': 'ja'});
      }
      expect(g.phase, 'president_discard');
      g.handle(lib, {'type': 'discard', 'index': 0});
      expect(g.phase, 'chancellor_discard');
      g.handle(other, {'type': 'discard', 'index': 0});
      // 5th red enacted -> triggers execute power in 5-player game
      expect(g.redPolicies, 5);
      expect(g.phase, 'execute');
      g.handle(lib, {'type': 'execute', 'target': leader});
      expect(g.isOver, true);
      expect(g.winner, 'liberal');
    });
  });

  group('chameleon', () {
    test('has at least 12 built-in 4x4 topic cards with valid fallback clues', () {
      expect(chameleonTopics.length, greaterThanOrEqualTo(12));
      for (final t in chameleonTopics) {
        expect(t.words.length, 16);
        expect(t.words.toSet().length, 16);
        for (final w in t.words) {
          final clues = t.wordClues[w]!;
          expect(clues, isNotEmpty);
          for (final c in clues) {
            expect(Chameleon.isValidClue(c, t.words), isTrue, reason: '${t.title} word $w clue $c');
          }
        }
        for (final c in t.chameleonClues) {
          expect(Chameleon.isValidClue(c, t.words), isTrue, reason: '${t.title} cham clue $c');
        }
      }
    });

    test('hides secret word from chameleon and spectator, validates clues, and scores properly', () {
      final g = Chameleon(_setup(4, {'rounds': 3, 'tieCatch': false}, 10))..start();
      final cham = g.chameleonSeat;
      final citizen = (cham + 1) % 4;
      expect(g.view(cham)['secretIndex'], -1);
      expect(g.view(cham)['secretWord'], isNull);
      expect(g.view(-1)['secretIndex'], -1);
      expect(g.view(citizen)['secretIndex'], g.secretIndex);
      expect(g.view(citizen)['secretWord'], g.secretWord);

      // Cannot submit a word that is on the board
      expect(
        () => g.handle(g.currentTurn, {'type': 'clue', 'text': g.currentTopic.words[0]}),
        throwsA(isA<GameError>()),
      );

      for (var i = 0; i < 4; i++) {
        g.handle(g.currentTurn, {'type': 'clue', 'text': '线索${i + 1}'});
      }
      expect(g.phase, 'vote');

      // Everyone votes for chameleon -> caught -> guess wrong -> citizens get +2 each
      for (var s = 0; s < 4; s++) {
        g.handle(s, {'type': 'vote', 'target': cham});
      }
      expect(g.phase, 'guess');
      final wrongIdx = (g.secretIndex + 1) % 16;
      g.handle(cham, {'type': 'guess', 'index': wrongIdx});
      expect(g.phase, 'roundEnd');
      expect(g.scores[cham], 0);
      expect(g.scores[citizen], 2);
    });

    test('AI clue rejects board words and falls back safely', () {
      late Chameleon g;
      g = Chameleon(GameSetup(
        players: 4,
        options: const {'rounds': 3, 'ai': true},
        names: const ['P0', 'P1', 'P2', 'P3'],
        bots: List.filled(4, true),
        rng: Random(3),
        ai: _CustomAi((_) => g.secretWord),
      ))
        ..start();
      final act = g.runBot(g.currentTurn)!;
      expect(act['type'], 'clue');
      expect(Chameleon.isValidClue(act['text'] as String, g.currentTopic.words), isTrue);
    });
  });

  group('themessage', () {
    test('factions, turn flow, lock, pass, and win/death conditions', () {
      final g = TheMessage(_setup(5, {'green': true}, 12))..start();
      expect(g.factions.length, 5);
      expect(g.factions.where((f) => f == 'red').length, 2);
      expect(g.factions.where((f) => f == 'blue').length, 2);
      expect(g.factions.where((f) => f == 'green').length, 1);

      final s0 = g.turn;
      final s1 = (s0 + 1) % 5;
      expect(g.view(s1)['myFaction'], g.factions[s1]);
      expect((g.view(s1)['factions'] as List)[s0], isNull);

      // Give s0 a lock card and a black card
      g.hands[s0] = [
        const MessageCard(id: 901, action: 'lock', color: 'red', delivery: 'direct'),
        const MessageCard(id: 902, action: 'decrypt', color: 'black', delivery: 'text'),
      ];
      g.handle(s0, {'type': 'play_action', 'index': 0, 'target': s1});
      expect(g.locked.contains(s1), isTrue);

      g.handle(s0, {'type': 'transmit', 'index': 0, 'target': s1});
      expect(g.phase, 'receive');
      expect(g.currentTarget, s1);
      // s1 is locked, so passing must throw GameError
      expect(() => g.handle(s1, {'type': 'pass'}), throwsA(isA<GameError>()));

      // Give s1 2 existing black cards so accepting the 3rd eliminates s1
      g.intel[s1] = [
        const MessageCard(id: 801, action: 'burn', color: 'black', delivery: 'direct'),
        const MessageCard(id: 802, action: 'burn', color: 'black', delivery: 'direct'),
      ];
      g.handle(s1, {'type': 'accept'});
      expect(g.alive[s1], isFalse);
    });

    test('collecting 3 intelligence of own faction color wins the game', () {
      final g = TheMessage(_setup(4, {'green': false}, 7))..start();
      final redSeat = g.factions.indexOf('red');
      final otherSeat = (redSeat + 1) % 4;
      g.turn = otherSeat;
      g.intel[redSeat] = [
        const MessageCard(id: 701, action: 'lock', color: 'red', delivery: 'direct'),
        const MessageCard(id: 702, action: 'swap', color: 'red', delivery: 'text'),
      ];
      g.hands[otherSeat] = [
        const MessageCard(id: 703, action: 'burn', color: 'red', delivery: 'direct'),
      ];
      g.handle(otherSeat, {'type': 'transmit', 'index': 0, 'target': redSeat});
      g.handle(redSeat, {'type': 'accept'});
      expect(g.isOver, isTrue);
      expect(g.winner, 'red');
      expect(g.placings![redSeat], 1);
    });
  });

  test('social2 games: bots finish every variant and player count', () {
    expect(runSims(social2Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
