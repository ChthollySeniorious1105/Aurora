import 'dart:math';

import 'package:aurora_shared/games/party6/defs.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

void main() {
  group('BloodClock (血染钟楼·灾祸滋生) unit tests', () {
    BloodClock createBotc({int players = 5, int seed = 42}) {
      final setup = GameSetup(
        players: players,
        options: const {'ai': false},
        names: [for (var i = 0; i < players; i++) 'P$i'],
        bots: List.filled(players, false),
        rng: Random(seed),
      );
      final g = BloodClock(setup);
      g.start();
      return g;
    }

    test('Baron adds +2 Outsiders and Drunk thinks they are a Townsfolk', () {
      expect(botcDistribution(5, hasBaron: false), (3, 0, 1, 1));
      expect(botcDistribution(5, hasBaron: true), (1, 2, 1, 1));
      expect(botcDistribution(7, hasBaron: true), (3, 2, 1, 1));

      final g = createBotc(players: 6, seed: 11);
      g.trueRole = ['imp', 'baron', 'drunk', 'saint', 'washerwoman', 'empath'];
      g.shownRole = ['imp', 'baron', 'chef', 'saint', 'washerwoman', 'empath'];
      // Drunk at seat 2 sees 'chef' in view(2), while Spy / game over sees trueRole 'drunk'
      expect(g.view(2)['myRole'], 'chef');
      expect(g.isHealthy(2), isFalse);
    });

    test('voiceListeners restricts Night channels and opens Day to everyone including dead', () {
      final g = createBotc(players: 5);
      g.trueRole = ['imp', 'poisoner', 'washerwoman', 'monk', 'mayor'];
      g.shownRole = List.of(g.trueRole);
      g.phase = 'night';
      // Evil players hear evil team at night; good players only hear themselves
      expect(g.voiceListeners(0), {0, 1});
      expect(g.voiceListeners(1), {0, 1});
      expect(g.voiceListeners(2), {2});

      // During day, everyone (including dead players) hears everyone (null)
      g.phase = 'day';
      g.alive[2] = false;
      expect(g.voiceListeners(0), isNull);
      expect(g.voiceListeners(2), isNull);
    });

    test('Imp night kill, Monk protection, Soldier immunity, and Imp self-kill (starpass)', () {
      final g = createBotc(players: 5);
      g.trueRole = ['imp', 'poisoner', 'monk', 'soldier', 'mayor'];
      g.shownRole = List.of(g.trueRole);
      g.day = 2;
      g.beginNightForTest();

      // Night 2 order: Poisoner (1) -> Monk (2) -> Imp (0)
      expect(g.waitingFor, [1]);
      g.handle(1, {'type': 'night_act', 'target': 4}); // Poison Mayor (4)
      expect(g.poisonedSeat, 4);

      expect(g.waitingFor, [2]);
      // Monk protects Mayor (4) -> Imp attacking 4 fails!
      g.handle(2, {'type': 'night_act', 'target': 4});
      expect(g.waitingFor, [0]);
      g.handle(0, {'type': 'night_act', 'target': 4});
      expect(g.alive[4], isTrue);
      expect(g.phase, 'day');

      // Night 3: Imp attacks healthy Soldier (3) -> Soldier is immune!
      g.day = 3;
      g.beginNightForTest();
      g.handle(1, {'type': 'night_act', 'target': 4});
      g.handle(2, {'type': 'night_act', 'target': 4});
      g.handle(0, {'type': 'night_act', 'target': 3});
      expect(g.alive[3], isTrue);

      // Night 4: Imp kills self (0) -> Poisoner (1) becomes the new Imp!
      g.day = 4;
      g.beginNightForTest();
      g.handle(1, {'type': 'night_act', 'target': 4});
      g.handle(2, {'type': 'night_act', 'target': 4});
      g.handle(0, {'type': 'night_act', 'target': 0});
      expect(g.alive[0], isFalse);
      expect(g.trueRole[1], 'imp');
      expect(g.isOver, isFalse);
    });

    test('Ravenkeeper wakes when killed by Imp at night to learn a role', () {
      final g = createBotc(players: 5);
      g.trueRole = ['imp', 'baron', 'ravenkeeper', 'washerwoman', 'mayor'];
      g.shownRole = List.of(g.trueRole);
      g.day = 2;
      g.beginNightForTest();

      // Imp (0) kills Ravenkeeper (2)
      expect(g.waitingFor, [0]);
      g.handle(0, {'type': 'night_act', 'target': 2});
      expect(g.alive[2], isFalse);
      // Ravenkeeper (2) is immediately woken up to choose a player
      expect(g.phase, 'night');
      expect(g.waitingFor, [2]);
      g.handle(2, {'type': 'night_act', 'target': 0});
      expect(g.privateNotes[2].last, contains('小恶魔'));
      expect(g.phase, 'day');
    });

    test('Slayer day shot kills Demon, Scarlet Woman takes over at >=5 alive', () {
      final g = createBotc(players: 5);
      g.trueRole = ['imp', 'scarlet_woman', 'slayer', 'washerwoman', 'mayor'];
      g.shownRole = List.of(g.trueRole);
      g.phase = 'day';

      // With 5 players alive, Slayer (2) shoots Imp (0) -> Imp dies, Scarlet Woman (1) becomes Imp!
      g.handle(2, {'type': 'slayer', 'target': 0});
      expect(g.alive[0], isFalse);
      expect(g.trueRole[1], 'imp');
      expect(g.isOver, isFalse);

      // Give seat 3 Slayer and shoot the new Imp (1) when only 4 alive -> Good wins!
      g.trueRole[3] = 'slayer';
      g.shownRole[3] = 'slayer';
      g.handle(3, {'type': 'slayer', 'target': 1});
      expect(g.isOver, isTrue);
      expect(g.winner, 'good');
    });

    test('Virgin executes Townsfolk nominator immediately; Saint execution wins for Evil; Mayor wins on 3 alive no execution', () {
      // 1. Virgin test
      final g = createBotc(players: 5);
      g.trueRole = ['imp', 'baron', 'virgin', 'washerwoman', 'mayor'];
      g.shownRole = List.of(g.trueRole);
      g.phase = 'day';
      g.day = 1;
      // Washerwoman (3) nominates Virgin (2) -> Washerwoman is immediately executed and Night 2 begins!
      g.handle(3, {'type': 'nominate', 'target': 2});
      expect(g.alive[3], isFalse);
      expect(g.day, 2);

      // 2. Saint execution -> Evil wins immediately
      final g2 = createBotc(players: 5);
      g2.trueRole = ['imp', 'baron', 'saint', 'washerwoman', 'mayor'];
      g2.shownRole = List.of(g2.trueRole);
      g2.phase = 'day';
      g2.handle(0, {'type': 'nominate', 'target': 2});
      for (var s = 0; s < 5; s++) {
        g2.handle(s, {'type': 'vote', 'yes': true});
      }
      for (var s = 0; s < 5; s++) {
        g2.handle(s, {'type': 'skip_day'});
      }
      expect(g2.isOver, isTrue);
      expect(g2.winner, 'evil');

      // 3. Mayor 3-alive no execution -> Good wins!
      final g3 = createBotc(players: 5);
      g3.trueRole = ['imp', 'baron', 'mayor', 'washerwoman', 'soldier'];
      g3.shownRole = List.of(g3.trueRole);
      g3.alive = [true, false, true, false, true]; // 3 alive: 0, 2 (mayor), 4
      g3.phase = 'day';
      g3.onBlock = -1;
      g3.handle(0, {'type': 'skip_day'});
      g3.handle(2, {'type': 'skip_day'});
      g3.handle(4, {'type': 'skip_day'});
      expect(g3.isOver, isTrue);
      expect(g3.winner, 'good');
    });

    test('Ghost Vote token is spent once by dead player and Butler respects master vote', () {
      final g = createBotc(players: 5);
      g.trueRole = ['imp', 'baron', 'butler', 'washerwoman', 'mayor'];
      g.shownRole = List.of(g.trueRole);
      g.alive = [true, false, true, true, true]; // Seat 1 is dead (has 1 ghost vote)
      g.butlerMaster[2] = 3; // Seat 2 (Butler) chose Seat 3 as master
      g.phase = 'day';

      g.handle(0, {'type': 'nominate', 'target': 4});
      expect(g.phase, 'vote');

      // Master (3) votes false -> Butler (2) cannot vote yes
      g.handle(3, {'type': 'vote', 'yes': false});
      expect(() => g.handle(2, {'type': 'vote', 'yes': true}), throwsA(isA<GameError>()));
      g.handle(2, {'type': 'vote', 'yes': false});

      // Dead player (1) spends their Ghost Vote token to vote yes
      g.handle(1, {'type': 'vote', 'yes': true});
      g.handle(0, {'type': 'vote', 'yes': true});
      g.handle(4, {'type': 'vote', 'yes': false});

      expect(g.ghostVote[1], isFalse);

      // Next nomination today: dead player (1) has no ghost vote left, cannot vote yes
      g.handle(2, {'type': 'nominate', 'target': 0});
      expect(g.waitingFor.contains(1), isFalse);
      expect(() => g.handle(1, {'type': 'vote', 'yes': true}), throwsA(isA<GameError>()));
    });
  });

  group('Insider (局内人) unit tests', () {
    InsiderGame createInsider({int players = 5, int maxQuestions = 20, int seed = 7}) {
      final setup = GameSetup(
        players: players,
        options: {'maxQuestions': maxQuestions, 'words': 'builtin', 'ai': false},
        names: [for (var i = 0; i < players; i++) 'P$i'],
        bots: List.filled(players, false),
        rng: Random(seed),
      );
      final g = InsiderGame(setup);
      g.start();
      return g;
    }

    test('Master and Insider know secretWord in QA phase while Commons do not', () {
      final g = createInsider(players: 5);
      final common = [0, 1, 2, 3, 4].firstWhere((s) => s != g.masterSeat && s != g.insiderSeat);

      expect(g.view(g.masterSeat)['secretWord'], g.secretWord);
      expect(g.view(g.insiderSeat)['secretWord'], g.secretWord);
      expect(g.view(common)['secretWord'], isNull);
      expect(g.view(-1)['secretWord'], isNull);
      // Nobody sees insiderSeat before game over
      expect(g.view(g.masterSeat)['insiderSeat'], isNull);
    });

    test('Phase 1 QA transitions to Phase 2 Accuse on correct guess; majority Yes on guesser resolves game', () {
      final g = createInsider(players: 4);
      final common = [0, 1, 2, 3].firstWhere((s) => s != g.masterSeat && s != g.insiderSeat);

      // Ask a question and Master answers 'yes'
      g.handle(common, {'type': 'ask', 'text': '它是日常物品吗？'});
      expect(g.waitingFor, [g.masterSeat]);
      g.handle(g.masterSeat, {'type': 'answer', 'answer': 'yes'});
      expect(g.questionsUsed, 1);

      // Insider guesses the secretWord!
      g.handle(g.insiderSeat, {'type': 'guess_word', 'text': g.secretWord});
      expect(g.phase, 'accuse');
      expect(g.accuseStep, 1);
      expect(g.guesser, g.insiderSeat);

      // Majority votes Yes (guesser IS the Insider) -> Commons & Master win!
      for (var s = 0; s < 4; s++) {
        g.handle(s, {'type': 'vote', 'yes': s != g.insiderSeat});
      }
      expect(g.isOver, isTrue);
      expect(g.winner, 'commons');
      expect(g.placings![g.insiderSeat], 2);
      expect(g.placings![g.masterSeat], 1);
    });

    test('Phase 2 Step 2 suspect vote when majority votes No on guesser', () {
      final g = createInsider(players: 5);
      final commons = [0, 1, 2, 3, 4].where((s) => s != g.masterSeat && s != g.insiderSeat).toList();
      final guesserCommon = commons.first;
      final otherCommon = commons.last;

      // A Common guesses the secretWord
      g.handle(guesserCommon, {'type': 'guess_word', 'text': g.secretWord});
      expect(g.phase, 'accuse');
      expect(g.accuseStep, 1);

      // Majority votes No (guesser is NOT the Insider) -> advances to Step 2
      for (var s = 0; s < 5; s++) {
        g.handle(s, {'type': 'vote', 'yes': false});
      }
      expect(g.isOver, isFalse);
      expect(g.accuseStep, 2);
      // Cannot vote for Master or Guesser in Step 2
      expect(() => g.handle(0, {'type': 'vote', 'target': g.masterSeat}), throwsA(isA<GameError>()));
      expect(() => g.handle(0, {'type': 'vote', 'target': guesserCommon}), throwsA(isA<GameError>()));

      // Everyone votes for otherCommon (wrong suspect) -> Insider wins!
      for (var s = 0; s < 5; s++) {
        g.handle(s, {'type': 'vote', 'target': otherCommon});
      }
      expect(g.isOver, isTrue);
      expect(g.winner, 'insider');
      expect(g.placings![g.insiderSeat], 1);
    });

    test('Question limit exhaustion causes everyone to lose', () {
      final g = createInsider(players: 4, maxQuestions: 2);
      final common = [0, 1, 2, 3].firstWhere((s) => s != g.masterSeat && s != g.insiderSeat);

      g.handle(common, {'type': 'guess_word', 'text': '绝对错误的词1'});
      expect(g.isOver, isFalse);
      g.handle(common, {'type': 'guess_word', 'text': '绝对错误的词2'});
      expect(g.isOver, isTrue);
      expect(g.winner, 'none');
      expect(g.placings, isNotNull);
    });
  });

  group('Dixit (妙语说书人) unit tests', () {
    DixitGame createDixit({int players = 4, int target = 30, int seed = 9}) {
      final setup = GameSetup(
        players: players,
        options: {'target': target, 'ai': false},
        names: [for (var i = 0; i < players; i++) 'P$i'],
        bots: List.filled(players, false),
        rng: Random(seed),
      );
      final g = DixitGame(setup);
      g.start();
      return g;
    }

    test('72 cards deck, 6 cards per hand, partial correct guess scoring (+3/+3 and +1 decoy)', () {
      expect(kDixitCards.length, 72);
      final g = createDixit(players: 4);
      for (var s = 0; s < 4; s++) {
        expect(g.hands[s].length, 6);
      }

      final stCard = g.hands[0].first;
      final c1 = g.hands[1].first;
      final c2 = g.hands[2].first;
      final c3 = g.hands[3].first;

      g.handle(0, {'type': 'story', 'card': stCard, 'clue': '银河里的漂流者'});
      expect(g.phase, 'submit');

      g.handle(1, {'type': 'submit', 'card': c1});
      g.handle(2, {'type': 'submit', 'card': c2});
      g.handle(3, {'type': 'submit', 'card': c3});
      expect(g.phase, 'vote');

      // Player 1 cannot vote for their own card c1
      expect(() => g.handle(1, {'type': 'vote', 'card': c1}), throwsA(isA<GameError>()));

      // Player 1 guesses stCard (correct!), Player 2 & 3 vote for Player 1's decoy card c1!
      g.handle(1, {'type': 'vote', 'card': stCard});
      g.handle(2, {'type': 'vote', 'card': c1});
      g.handle(3, {'type': 'vote', 'card': c1});

      // Storyteller (0) gets +3; Player 1 gets +3 (correct) + 2 (decoy votes from P2 & P3) = 5; P2 & P3 get 0
      expect(g.scores, [3, 5, 0, 0]);
      expect(g.round, 2);
      expect(g.storyteller, 1);
      // Hands replenished back to 6
      for (var s = 0; s < 4; s++) {
        expect(g.hands[s].length, 6);
      }
    });

    test('Everyone or nobody finding Storyteller card gives Storyteller 0 and others +2 (plus decoy votes)', () {
      final g = createDixit(players: 3, target: 18);
      final stCard = g.hands[0].first;
      final c1 = g.hands[1].first;
      final c2 = g.hands[2].first;

      g.handle(0, {'type': 'story', 'card': stCard, 'clue': '太直白的提示'});
      g.handle(1, {'type': 'submit', 'card': c1});
      g.handle(2, {'type': 'submit', 'card': c2});

      // Both P1 and P2 find stCard -> everyone guessed right!
      g.handle(1, {'type': 'vote', 'card': stCard});
      g.handle(2, {'type': 'vote', 'card': stCard});
      expect(g.scores, [0, 2, 2]);

      // Round 2 (storyteller = 1): nobody finds stCard -> P1 gets 0, P0 & P2 get +2 + 1 decoy vote each = +3!
      final stCard2 = g.hands[1].first;
      final c0 = g.hands[0].first;
      final c2b = g.hands[2].first;
      g.handle(1, {'type': 'story', 'card': stCard2, 'clue': '太晦涩的提示'});
      g.handle(0, {'type': 'submit', 'card': c0});
      g.handle(2, {'type': 'submit', 'card': c2b});
      // P0 votes for P2's card, P2 votes for P0's card
      g.handle(0, {'type': 'vote', 'card': c2b});
      g.handle(2, {'type': 'vote', 'card': c0});
      expect(g.scores, [3, 2, 5]);
    });
  });

  test('simulate 30 games for all party6 games', () {
    final failures = runSims(party6Games, n: 30);
    expect(failures, 0);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
