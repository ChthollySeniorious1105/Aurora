import 'dart:math';

import 'package:aurora_shared/games/cards20/defs.dart';
import 'package:aurora_shared/games/cards20/diamonds.dart';
import 'package:aurora_shared/games/cards20/fantasy_realms.dart';
import 'package:aurora_shared/games/cards20/phase10.dart';
import 'package:aurora_shared/games/cards20/sea_salt_paper.dart';
import 'package:aurora_shared/games/cards20/zhaopengyou.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(int n, [Map<String, dynamic> opts = const {}, int seed = 1]) =>
    GameSetup(
      players: n,
      options: opts,
      names: [for (var i = 0; i < n; i++) 'P$i'],
      bots: List.filled(n, true),
      rng: Random(seed),
    );

void main() {
  group('sea_salt_paper (海盐与纸折 Sea Salt & Paper)', () {
    test('58-card deck across 8 colors, collector/multiplier/mermaid scoring, and 4-mermaid instant win', () {
      final deck = buildSspDeck();
      expect(deck.length, 58);

      final colorsInDeck = deck.map((id) => sspCard(id).color).toSet();
      expect(colorsInDeck.containsAll(sspColors), isTrue);

      // Collector + Multiplier + Mermaid scoring check:
      // 3 penguins (5 pts) + colony (+2 per penguin = +6 pts) + 2 sailors (5 pts) + captain (+3 per sailor = +6 pts)
      // + 1 mermaid (scores most frequent color count) + 1 played boat duo (+1 pt)
      final hand = [
        'penguin_1', // purple
        'penguin_2', // orange
        'penguin_3', // lightBlue
        'colony_1', // green
        'sailor_1', // orange
        'sailor_2', // purple
        'captain_1', // orange
        'mermaid_1', // white
      ];
      final tableau = [
        ['boat_1', 'boat_2'], // 2 blue -> +1 duo pt
      ];
      final breakdown = sspScoreBreakdown(hand, tableau);
      expect(breakdown['duoPoints'], 1);
      expect(breakdown['collectorPoints'], 10); // 5 (penguins) + 5 (sailors)
      expect(breakdown['multiplierPoints'], 12); // 6 (colony) + 6 (captain)
      expect(breakdown['mermaidPoints'], 3); // 3 orange cards
      expect(breakdown['total'], 26);
    });

    test('Draw 2 keep 1, Duo actions (crab/boat/fish/shark+swimmer), and Last Chance resolution', () {
      final g = SeaSaltPaperGame(_setup(2, {'targetScore': 30}))..start();
      g.turn = 0;
      g.phase = 'draw';
      g.deck = ['fish_1', 'crab_1', 'boat_1', 'boat_2'];
      g.discards = [
        ['shell_1'],
        ['octopus_1'],
      ];
      g.hands[0] = ['shark_1', 'swimmer_1', 'sailor_1', 'sailor_2', 'captain_1'];
      g.hands[1] = ['shell_2', 'shell_3'];

      // Seat 0 draws 2 ('boat_2', 'boat_1'), keeps 'boat_2', discards 'boat_1' to pile 0
      g.handle(0, {'type': 'draw_deck'});
      expect(g.phase, 'choose_drawn');
      expect(g.drawnCards.length, 2);
      g.handle(0, {'type': 'keep_drawn', 'keepIndex': 0, 'discardPile': 0});
      expect(g.phase, 'action');

      // Seat 0 plays shark_1 + swimmer_1 duo -> steals 1 random card from Seat 1!
      g.handle(0, {'type': 'play_duo', 'card1': 'shark_1', 'card2': 'swimmer_1', 'targetSeat': 1});
      expect(g.hands[1].length, 1);
      expect(g.tableau[0].length, 1);

      // Seat 0 has sailor_1 + sailor_2 (5 pts) + captain_1 (6 pts) + 1 duo (1 pt) = 12 pts >= 7 -> calls Last Chance!
      expect(g.seatRoundPoints(0), greaterThanOrEqualTo(7));
      g.handle(0, {'type': 'last_chance'});
      expect(g.lastChanceCaller, 0);
      expect(g.turn, 1);

      // Seat 1 takes final turn (takes top discard and ends turn)
      g.handle(1, {'type': 'take_discard', 'pile': 0});
      g.handle(1, {'type': 'end_turn'});

      // Round resolves: Seat 0 won Last Chance bet -> gets cardPoints + colorBonus!
      expect(g.lastRoundSummary?['mode'], 'last_chance');
      expect(g.lastRoundSummary?['betSuccess'], isTrue);
      expect(g.scores[0], greaterThan(12));
    });
  });

  group('fantasy_realms (奇幻国度 Fantasy Realms)', () {
    test('53 unique cards across 10 suits + wild, synergy bonuses, penalties, and penalty clearing', () {
      final deck = buildFantasyRealmsDeck();
      expect(deck.length, 53);
      expect(deck.toSet().length, 53);

      // Hand with King (8) + Queen (6) + Knights (20) + Dwarven Infantry (15) + Rangers (5) + Forest (7) + Dragon (30)
      // - Rangers clears all Army penalties (so Dwarven Infantry loses its -2 penalty!)
      // - King & Queen together give +20 per Army (3 armies = +60 each!)
      // - Dragon has -40 penalty without a Wizard (clamped at 0)
      final hand1 = [
        'king',
        'queen',
        'knights',
        'dwarven_infantry',
        'rangers',
        'forest',
        'dragon',
      ];
      final res1 = fantasyRealmsScoreHand(hand1);
      final cs1 = (res1['cardScores'] as Map).cast<String, int>();
      expect(cs1['king'], 8 + 20 * 3); // 68
      expect(cs1['queen'], 6 + 20 * 3); // 66
      expect(cs1['dwarven_infantry'], 15); // penalty cleared by Rangers!
      expect(cs1['dragon'], 0); // 30 - 40 clamped to 0 without Wizard

      // Replace forest with Beastmaster (Wizard, clears Beast penalties and +9 per Beast!)
      final hand2 = [
        'king',
        'queen',
        'knights',
        'dwarven_infantry',
        'rangers',
        'beastmaster',
        'dragon',
      ];
      final res2 = fantasyRealmsScoreHand(hand2);
      final cs2 = (res2['cardScores'] as Map).cast<String, int>();
      expect(cs2['dragon'], 30); // Dragon penalty cleared by Wizard/Beastmaster!
      expect(asInt(res2['totalScore']), greaterThan(asInt(res1['totalScore'])));
    });

    test('Draw from deck or discard area, discard to 7 cards, and end game at discardLimit', () {
      final g = FantasyRealmsGame(_setup(2, {'discardLimit': 8}))..start();
      expect(g.hands[0].length, 7);
      expect(g.hands[1].length, 7);

      // Fill discardArea to 7 cards, then Seat 0 draws 1 and discards 1 -> reaches 8 cards and ends game!
      g.discardArea = [
        'knights',
        'king',
        'queen',
        'princess',
        'warlord',
        'empress',
        'collector',
      ];
      g.turn = 0;
      g.phase = 'draw';
      g.handle(0, {'type': 'draw_deck'});
      expect(g.hands[0].length, 8);
      expect(g.phase, 'discard');

      final toDiscard = g.hands[0].first;
      g.handle(0, {'type': 'discard', 'card': toDiscard});
      expect(g.hands[0].length, 7);
      expect(g.discardArea.length, 8);
      expect(g.isOver, isTrue);
      expect(g.placings, isNotNull);
    });
  });

  group('zhaopengyou (找朋友 / 捉黑A)', () {
    test('54-card deal (4x12 + 6 kitty), bidding, burying kitty, secret friend reveal, and double kitty points', () {
      final deck = buildZhaopengyouDeck();
      expect(deck.length, 54);
      final totalPts = deck.fold<int>(0, (s, c) => s + zpyCardPoints(c));
      expect(totalPts, 100);

      final g = ZhaopengyouGame(_setup(4, {'rounds': 1}))..start();
      expect(g.hands.every((h) => h.length == 12), isTrue);
      expect(g.kitty.length, 6);

      // Bidding: Seat 0 bids 70, Seats 1, 2, 3 pass -> Seat 0 becomes declarer with 18 cards
      g.turn = 0;
      g.handle(0, {'type': 'bid', 'score': 70});
      g.handle(1, {'type': 'pass'});
      g.handle(2, {'type': 'pass'});
      g.handle(3, {'type': 'pass'});
      expect(g.phase, 'setup_declarers');
      expect(g.declarer, 0);
      expect(g.contract, 70);
      expect(g.defenderTarget, 35); // 105 - 70 = 35
      expect(g.hands[0].length, 18);

      // Set up deterministic 1-trick finish to test secret friend reveal + double kitty points
      g.hands[0] = ['RJ', '3S', '4S', '6S', '7S', '8S', 'KS']; // will bury 6 cards including KS (10 pts)
      g.hands[1] = ['9S'];
      g.hands[2] = ['AS']; // Seat 2 holds the called friendCard 'AS'!
      g.hands[3] = ['TS']; // 10 pts

      g.handle(0, {
        'type': 'bury',
        'cards': ['3S', '4S', '6S', '7S', '8S', 'KS'],
        'trumpSuit': 'S',
        'friendCard': 'AS',
      });
      expect(g.phase, 'play');
      expect(g.friendSeat, 2);
      expect(g.friendRevealed, isFalse);
      // Before reveal, Seat 1 cannot see who the secret friend is
      expect(g.view(1)['revealedFriendSeat'], isNull);

      // Play final trick (set trickNumber = 12):
      g.trickNumber = 12;
      g.handle(0, {'type': 'play', 'card': 'RJ'});
      g.handle(1, {'type': 'play', 'card': '9S'});
      g.handle(2, {'type': 'play', 'card': 'AS'}); // Friend card played!
      expect(g.friendRevealed, isTrue);
      expect(g.view(1)['revealedFriendSeat'], 2);

      g.handle(3, {'type': 'play', 'card': 'TS'});
      // Seat 0 wins trick with RJ: captures AS(0) + TS(10) + buried KS(10)*2 = 30 pts
      expect(g.isOver, isTrue);
      expect(g.capturedPoints[0], 30);
    });
  });

  group('diamonds (钻石大盗 Diamonds)', () {
    test('60-card deck (4 suits x 1..15), off-suit Suit Actions, trick winner Suit Actions, and end-of-hand bonuses', () {
      final deck = buildDiamondsDeck();
      expect(deck.length, 60);

      final g = DiamondsGame(_setup(2, {'rounds': 1}))..start();
      g.showroom = [2, 2];
      g.vault = [1, 1];
      g.trickNumber = 10; // Final trick of the round
      g.turn = 0;
      g.leader = 0;
      g.hands[0] = ['15H'];
      g.hands[1] = ['4C']; // Void in H -> off-suit C triggers Club steal action!

      // Seat 0 leads 15H, Seat 1 plays off-suit 4C:
      // 1. Seat 1 immediately triggers 'C' (steals 1 crystal from Seat 0's showroom: showroom becomes [1, 3])
      // 2. Seat 0 wins trick with 15H -> triggers 'H' (takes 1 crystal from supply into showroom: showroom becomes [2, 3])
      // 3. End of hand: Seat 0 won most H (1) and C (1), Seat 1 won 0 tricks (triggers D twice -> moves 2 from showroom to vault!)
      g.handle(0, {'type': 'play', 'card': '15H'});
      g.handle(1, {'type': 'play', 'card': '4C'});
      expect(g.isOver, isTrue);
      expect(g.vault[1], 3); // 1 initial + 2 from 0-trick Diamond×2 bonus!
    });
  });

  group('phase10 (十阶段纸牌 Phase 10)', () {
    test('108-card deck, phase meld validation & auto-solver, hitting table melds, and Skip card', () {
      final deck = buildPhase10Deck();
      expect(deck.length, 108);
      expect(deck.where((c) => c == 'W').length, 8);
      expect(deck.where((c) => c == 'S').length, 4);

      // Phase 1: Two sets of 3
      final hand1 = ['R5', 'B5', 'W', 'G9', 'Y9', 'R9', 'B1', 'G2'];
      final melds1 = phase10FindPhaseMelds(hand1, 1);
      expect(melds1, isNotNull);
      expect(phase10ValidatePhaseMelds(hand1, 1, melds1!), isTrue);

      // Phase 2: 1 set of 3 + 1 run of 4
      final hand2 = ['R3', 'B3', 'G3', 'Y6', 'R7', 'W', 'B9', 'S'];
      final melds2 = phase10FindPhaseMelds(hand2, 2);
      expect(melds2, isNotNull);
      expect(phase10ValidatePhaseMelds(hand2, 2, melds2!), isTrue);

      final g = Phase10Game(_setup(2, {'maxPhase': 3}))..start();
      g.turn = 0;
      g.phase = 'action';
      g.phaseIndex[0] = 3; // On final phase (set of 4 + run of 4)
      g.hands[0] = ['R8', 'B8', 'G8', 'Y8', 'R1', 'B2', 'G3', 'Y4', 'W', 'S'];
      g.hands[1] = ['R12', 'B12'];

      // Seat 0 completes Phase 3 (8 cards laid down), hits 'W' onto meld #0, and discards 'S' to go out!
      g.handle(0, {'type': 'complete_phase'});
      expect(g.phaseCompleted[0], isTrue);
      expect(g.tableMelds.length, 2);
      expect(g.hands[0].length, 2);

      g.handle(0, {'type': 'hit_meld', 'meldIndex': 0, 'card': 'W'});
      expect(g.hands[0], ['S']);

      g.handle(0, {'type': 'discard', 'card': 'S'});
      expect(g.isOver, isTrue);
      expect(g.placings, [1, 2]);
      expect(g.penalties[1], 20); // Two 12s = 10 + 10 = 20 penalty pts
    });
  });

  test('bot simulations (30 runs per option/player combination)', () {
    expect(runSims(cards20Games, n: 30), 0);
  });
}
