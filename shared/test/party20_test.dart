import 'dart:math';

import 'package:aurora_shared/games/party20/defs.dart';
import 'package:aurora_shared/src/ai.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(
  int players, {
  Map<String, dynamic>? options,
  int seed = 42,
  AiService? ai,
}) {
  return GameSetup(
    players: players,
    options: options ?? const {},
    names: [for (var i = 0; i < players; i++) 'P$i'],
    bots: List<bool>.filled(players, false),
    hostSeat: 0,
    rng: Random(seed),
    ai: ai,
  );
}

void main() {
  group('ito (糸：数字共鸣)', () {
    test('Hidden secretNumber in view, clue digit validation, AI clue slot & ascending reveal with life loss on skipped cards', () {
      final g = ItoGame(_setup(3, options: {'rounds': 2, 'ai': true}, ai: FakeAi(1)));
      g.start();
      expect(ItoGame.themeBank.length, greaterThanOrEqualTo(20));
      expect(g.phase, 'clue');

      // Assign deterministic secret numbers: P0 = 15, P1 = 42, P2 = 88
      g.secretNumber = [15, 42, 88];

      // Verify secretNumber is strictly hidden from other players & spectators in view(seat)
      final v0 = g.view(0);
      final v1 = g.view(1);
      final vSpec = g.view(-1);
      expect(v0['mySecretNumber'], 15);
      expect(v0['secretNumbers'], [15, -1, -1]);
      expect(v1['mySecretNumber'], 42);
      expect(v1['secretNumbers'], [-1, 42, -1]);
      expect(vSpec['mySecretNumber'], -1);
      expect(vSpec['secretNumbers'], [-1, -1, -1]);

      // Clue validation: must reject Arabic numerals 0-9 or the secret number!
      expect(
        () => g.handle(0, {'type': 'clue', 'text': '大约15左右'}),
        throwsA(isA<GameError>()),
      );
      expect(
        () => g.handle(0, {'type': 'clue', 'text': '50分居中'}),
        throwsA(isA<GameError>()),
      );

      // Submit valid clues for all 3 players (test AI bot on P2 too)
      g.handle(0, {'type': 'clue', 'text': '偏弱的白萝卜'});
      g.handle(1, {'type': 'clue', 'text': '标准的冻豆腐'});
      final botClue2 = g.runBot(2)!;
      expect(botClue2['type'], 'clue');
      g.handle(2, botClue2);

      expect(g.phase, 'play');

      // P0 plays 15 first -> strictly smallest unplayed card -> Perfect Play (+10 pts, 0 lives lost)!
      final livesBefore = g.lives;
      g.handle(0, {'type': 'play_card'});
      expect(g.lives, livesBefore);
      expect(g.scores[0], 10);
      expect(g.cardPlayed[0], isTrue);
      // Now P0's card (15) is publicly visible to P1, while P2's (88) is still hidden!
      expect(g.view(1)['secretNumbers'], [15, 42, -1]);

      // Now P2 (88) plays BEFORE P1 (42) -> skips P1's 42!
      // P1's 42 is automatically discarded face-up, team loses -1 life, and P1 gets accuracy bonus!
      g.handle(2, {'type': 'play_card'});
      expect(g.lives, livesBefore - 1);
      expect(g.scores[1], greaterThan(0));
      // Since all 3 cards (15, 42, 88) are now revealed, Round 1 finishes and Round 2 begins!
      expect(g.round, 2);
      expect(g.phase, 'clue');
    });
  });

  group('criminal_dance (犯人在跳舞)', () {
    test('First finder Turn 1 rule, Witness private intel, Alibi denial vs Detective catch, Dog catch & Culprit last-card win', () {
      final g = CriminalDanceGame(_setup(3, options: {'rounds': 1}));
      g.start();

      // Set up deterministic hands for 3 players (4 cards each):
      // P0 holds first_finder, witness, detective, civilian
      // P1 holds culprit, alibi, trade, civilian
      // P2 holds accomplice, dog, info_exchange, rumor
      g.hands[0] = ['first_finder', 'witness', 'detective', 'civilian'];
      g.hands[1] = ['culprit', 'alibi', 'trade', 'civilian'];
      g.hands[2] = ['accomplice', 'dog', 'info_exchange', 'rumor'];
      g.turn = 0;
      g.firstTurn = true;

      // Verify other players' hands are strictly hidden in view(seat)
      expect(g.view(0)['myHand'], ['first_finder', 'witness', 'detective', 'civilian']);
      expect(g.view(0)['revealedHands'], isNull);
      expect(g.view(-1)['myHand'], isEmpty);

      // Turn 1: P0 MUST play first_finder (cannot play witness on Turn 1)
      expect(
        () => g.handle(0, {'type': 'play', 'card': 'witness', 'target': 1}),
        throwsA(isA<GameError>()),
      );
      g.handle(0, {'type': 'play', 'card': 'first_finder'});
      expect(g.turn, 1);

      // P1 tries to play 'culprit' while holding >1 cards -> forbidden!
      expect(
        () => g.handle(1, {'type': 'play', 'card': 'culprit'}),
        throwsA(isA<GameError>()),
      );
      // P1 plays 'civilian' (keeps 'culprit' and 'alibi')
      g.handle(1, {'type': 'play', 'card': 'civilian'});
      expect(g.turn, 2);

      // P2 plays 'accomplice' -> joins Culprit faction!
      g.handle(2, {'type': 'play', 'card': 'accomplice'});
      expect(g.accomplices.contains(2), isTrue);
      expect(g.turn, 0);

      // P0 plays 'witness' on P1 -> records P1's hand privately in P0's intel (hidden from P2!)
      g.handle(0, {'type': 'play', 'card': 'witness', 'target': 1});
      expect((g.view(0)['intel'] as Map)['1'], containsAll(['culprit', 'alibi', 'trade']));
      expect((g.view(2)['intel'] as Map).containsKey('1'), isFalse);

      // P1 plays 'trade' with P2? Wait: let P1 keep 'alibi' first to test Alibi blocking Detective!
      // Give P1 an extra civilian to play so P1 still holds ['culprit', 'alibi'] when P0 plays 'detective':
      g.hands[1] = ['culprit', 'alibi', 'civilian'];
      g.handle(1, {'type': 'play', 'card': 'civilian'});
      g.hands[2] = ['dog', 'civilian'];
      g.handle(2, {'type': 'play', 'card': 'civilian'});

      // Now P0 has 2 cards (<= 3) and plays 'detective' accusing P1, who holds both 'culprit' AND 'alibi'!
      // Because P1 holds 'alibi', P1 safely denies the accusation and the game continues!
      g.handle(0, {'type': 'play', 'card': 'detective', 'target': 1});
      expect(g.isOver, isFalse);

      // Now P1 plays 'alibi', leaving P1 with ONLY ['culprit'] (last 1 card in hand)!
      g.handle(1, {'type': 'play', 'card': 'alibi'});
      expect(g.hands[1], ['culprit']);

      // Now P2 plays 'dog' targeting P1 -> inspects 'culprit' and catches the Culprit immediately!
      g.handle(2, {'type': 'play', 'card': 'dog', 'target': 1, 'inspectCard': 'culprit'});
      expect(g.isOver, isTrue);
      expect(g.lastWinnerSide, 'good');
    });

    test('Culprit played as very last card in hand wins for Culprit & Accomplice', () {
      final g = CriminalDanceGame(_setup(3, options: {'rounds': 1}));
      g.start();
      g.firstTurn = false;
      g.accomplices.add(2);
      g.hands[0] = ['culprit']; // Very last card in P0's hand!
      g.hands[1] = ['civilian'];
      g.hands[2] = ['civilian'];
      g.turn = 0;

      g.handle(0, {'type': 'play', 'card': 'culprit'});
      expect(g.isOver, isTrue);
      expect(g.lastWinnerSide, 'culprit');
      expect(g.scores[0], 4);
      expect(g.scores[2], 3); // Accomplice also scores!
    });
  });

  group('bomb_busters (拆弹专家)', () {
    test('Sorted wire racks, hidden uncut wires in view, Dual Cut match/mismatch/Red-Boom & Solo Cut defusal', () {
      final g = BombBustersGame(_setup(2, options: {'mode': 'fast'}));
      g.start();

      // Verify each player's wire rack is sorted in ascending order
      for (var s = 0; s < 2; s++) {
        final vals = [for (final w in g.wires[s]) w['value'] as int];
        final sorted = List<int>.of(vals)..sort();
        expect(vals, sorted);
      }

      // Set up deterministic sorted wire racks for P0 and P1:
      // P0 has [2 (cut:false), 5 (cut:false), 99 (cut:false), 99 (cut:false)]
      // P1 has [2 (cut:false), 6 (cut:false), 100 (Red Bomb, cut:false)]
      g.wires[0] = [
        {'value': 2, 'cut': false, 'token': null},
        {'value': 5, 'cut': false, 'token': null},
        {'value': 99, 'cut': false, 'token': null},
        {'value': 99, 'cut': false, 'token': null},
      ];
      g.wires[1] = [
        {'value': 2, 'cut': false, 'token': null},
        {'value': 6, 'cut': false, 'token': null},
        {'value': 100, 'cut': false, 'token': null},
      ];
      g.turn = 0;
      g.detonator = 3;

      // Verify P1's uncut wires without tokens have value == -1 in P0's view(0)
      final v0WiresP1 = (g.view(0)['wires'] as List)[1] as List;
      expect((v0WiresP1[0] as Map)['value'], -1);
      expect((v0WiresP1[1] as Map)['value'], -1);
      expect((v0WiresP1[2] as Map)['value'], -1);

      // 1. P0 performs Dual Cut matching wire 2 (myIdx: 0) with P1's slot 0 (value 2) -> Success!
      g.handle(0, {'type': 'dual_cut', 'myIdx': 0, 'targetSeat': 1, 'targetIdx': 0});
      expect(g.wires[0][0]['cut'], isTrue);
      expect(g.wires[1][0]['cut'], isTrue);
      expect(g.scores[0], 3);

      // 2. P1's turn: P1 performs Dual Cut guessing P0's slot 1 (value 5) is 6 (myIdx: 1) -> Mismatch!
      // Detonator advances (3 -> 2) and an Info Token (5) is placed on P0's slot 1!
      expect(g.turn, 1);
      g.handle(1, {'type': 'dual_cut', 'myIdx': 1, 'targetSeat': 0, 'targetIdx': 1});
      expect(g.detonator, 2);
      expect(g.wires[0][1]['token'], 5);
      // Now P1's view(1) can see P0's slot 1 value (5) because of the Info Token!
      expect((((g.view(1)['wires'] as List)[0] as List)[1] as Map)['value'], 5);

      // 3. P0's turn: P0 holds BOTH Yellow Wires (99) -> performs Solo Cut on 99!
      expect(g.turn, 0);
      g.handle(0, {'type': 'solo_cut', 'value': 99});
      expect(g.wires[0][2]['cut'], isTrue);
      expect(g.wires[0][3]['cut'], isTrue);

      // 4. P1's turn: P1 holds the only copy of 6 -> performs Solo Cut on 6!
      expect(g.turn, 1);
      g.handle(1, {'type': 'solo_cut', 'value': 6});
      expect(g.wires[1][1]['cut'], isTrue);

      // 5. P0's turn: P0 holds the only remaining uncut non-Red wire (5) -> performs Solo Cut on 5!
      // Now all Number & Yellow wires are cut and only Red (100) remains untouched -> Bomb Defused!
      expect(g.turn, 0);
      g.handle(0, {'type': 'solo_cut', 'value': 5});
      expect(g.isOver, isTrue);
      expect(g.defused, isTrue);
      expect(g.exploded, isFalse);
    });

    test('Hitting the Red Wire (100) during Dual Cut immediately explodes the bomb', () {
      final g = BombBustersGame(_setup(2, options: {'mode': 'fast'}));
      g.start();
      g.wires[0] = [
        {'value': 4, 'cut': false, 'token': null},
      ];
      g.wires[1] = [
        {'value': 100, 'cut': false, 'token': null},
      ];
      g.turn = 0;

      g.handle(0, {'type': 'dual_cut', 'myIdx': 0, 'targetSeat': 1, 'targetIdx': 0});
      expect(g.isOver, isTrue);
      expect(g.exploded, isTrue);
      expect(g.defused, isFalse);
    });
  });

  group('taco_cat (塔可猫羊起司披萨)', () {
    test('Mantra match slap, Special Animal poses (Gorilla/Groundhog/Narwhal), Non-match hold & penalty pile absorption', () {
      final g = TacoCatGame(_setup(3, options: {'rounds': 8}));
      g.start();

      // 1. Mantra Match: spokenWord == 0 (🌮塔可) and cardType == 0 (🌮塔可) -> expected is 'slap'!
      // All 3 players slap, P0 is fastest (sheds 2 cards), P2 is slowest (absorbs pileCount)!
      g.spokenWord = 0;
      g.cardType = 0;
      g.pileCount = 4;
      final d0 = g.personalDeck[0];
      final d2 = g.personalDeck[2];
      g.handle(0, {'type': 'react', 'action': 'slap'});
      g.handle(1, {'type': 'react', 'action': 'slap'});
      g.handle(2, {'type': 'react', 'action': 'slap'});
      expect(g.personalDeck[0], d0 - 2); // Fastest shed 2 cards
      expect(g.personalDeck[2], d2 - 1 + 4); // Slowest absorbed 4-card pile

      // 2. Special Card 5 (🦍 Gorilla): expected is 'pose_gorilla'!
      // P0 and P1 do 'pose_gorilla', P2 mistakenly does 'slap' -> P2 absorbs penalty pile!
      g.spokenWord = 1;
      g.cardType = 5;
      g.pileCount = 3;
      final d2BeforeGorilla = g.personalDeck[2];
      g.handle(0, {'type': 'react', 'action': 'pose_gorilla'});
      g.handle(1, {'type': 'react', 'action': 'pose_gorilla'});
      g.handle(2, {'type': 'react', 'action': 'slap'});
      expect(g.personalDeck[2], d2BeforeGorilla + 3);

      // 3. Non-match Normal Card: spokenWord == 2 (🐐山羊) vs cardType == 4 (🍕披萨) -> expected is 'hold'!
      // P0 and P2 hold, P1 flinches and slaps -> P1 absorbs penalty pile!
      g.spokenWord = 2;
      g.cardType = 4;
      g.pileCount = 5;
      final d1BeforeFlinch = g.personalDeck[1];
      g.handle(0, {'type': 'react', 'action': 'hold'});
      g.handle(1, {'type': 'react', 'action': 'slap'});
      g.handle(2, {'type': 'react', 'action': 'hold'});
      expect(g.personalDeck[1], d1BeforeFlinch + 5);
    });
  });

  test('simulate all party20 games (30 seeds per player count & option)', () {
    final failures = runSims(party20Games, n: 30);
    expect(failures, 0);
  });
}
