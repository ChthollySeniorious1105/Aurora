import 'dart:math';

import 'package:aurora_shared/games/cards16/claim.dart';
import 'package:aurora_shared/games/cards16/defs.dart';
import 'package:aurora_shared/games/cards16/doppelkopf.dart';
import 'package:aurora_shared/games/cards16/klaverjassen.dart';
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
  group('doppelkopf (德国双头牌 Doppelkopf)', () {
    test('40-card deck sums to 240 points and permanent trump hierarchy TH > Q > J > AD > TD > KD', () {
      final deck = buildDoppelkopfDeck();
      expect(deck.length, 40);
      final totalPts = deck.fold<int>(0, (acc, c) => acc + doppelkopfCardPoints(c));
      expect(totalPts, 240);

      // TH (Dullen) > QC > QS > QH > QD > JC > JS > JH > JD > AD > TD > KD
      expect(doppelkopfCardStrength('TH_0', 'normal', 'TRUMP'),
          greaterThan(doppelkopfCardStrength('QC_0', 'normal', 'TRUMP')));
      expect(doppelkopfCardStrength('QC_0', 'normal', 'TRUMP'),
          greaterThan(doppelkopfCardStrength('QS_0', 'normal', 'TRUMP')));
      expect(doppelkopfCardStrength('QD_0', 'normal', 'TRUMP'),
          greaterThan(doppelkopfCardStrength('JC_0', 'normal', 'TRUMP')));
      expect(doppelkopfCardStrength('JD_0', 'normal', 'TRUMP'),
          greaterThan(doppelkopfCardStrength('AD_0', 'normal', 'TRUMP')));
      expect(doppelkopfCardStrength('AD_0', 'normal', 'TRUMP'),
          greaterThan(doppelkopfCardStrength('TD_0', 'normal', 'TRUMP')));
      expect(doppelkopfCardStrength('TD_0', 'normal', 'TRUMP'),
          greaterThan(doppelkopfCardStrength('KD_0', 'normal', 'TRUMP')));

      // First-played identical card beats second-played identical card!
      final trick = [
        {'seat': 1, 'card': 'TH_0'},
        {'seat': 2, 'card': 'TH_1'},
        {'seat': 3, 'card': 'QC_0'},
        {'seat': 0, 'card': 'AD_0'},
      ];
      expect(doppelkopfTrickWinner(trick, 'normal'), 1);

      // Damensolo: only Queens are trump
      expect(isDoppelkopfTrump('QC_0', 'solo_queens'), isTrue);
      expect(isDoppelkopfTrump('TH_0', 'solo_queens'), isFalse);
      expect(isDoppelkopfTrump('JC_0', 'solo_queens'), isFalse);
    });

    test('Secret QC (Re vs Kontra), call_re/call_kontra, Fuchs gefangen (AD), and Karlchen (JC on 10th trick)', () {
      final g = DoppelkopfGame(_setup(4, {'rounds': 1}))..start();
      // Seat 0 and Seat 2 hold QC_0 and QC_1 -> Secret Team Re!
      g.hands[0] = ['QC_0', 'TH_0', 'JC_0', 'AC_0', 'TC_0', 'KC_0', 'AS_0', 'TS_0', 'KS_0', 'AH_0'];
      g.hands[1] = ['AD_0', 'QS_0', 'QH_0', 'QD_0', 'JS_0', 'JH_0', 'JD_0', 'AC_1', 'AS_1', 'AH_1'];
      g.hands[2] = ['QC_1', 'TH_1', 'TD_0', 'KD_0', 'TC_1', 'KC_1', 'TS_1', 'KS_1', 'KH_0', 'KH_1'];
      g.hands[3] = ['AD_1', 'QS_1', 'QH_1', 'QD_1', 'JC_1', 'JS_1', 'JH_1', 'JD_1', 'TD_1', 'KD_1'];

      // All 4 pass -> Normal game
      for (var s = 0; s < 4; s++) {
        g.handle(s, {'type': 'pass'});
      }
      expect(g.phase, 'play');
      expect(g.contract, 'normal');
      expect(g.isReTeam, [true, false, true, false]);
      // Seat 2's Re identity is hidden from Seat 0 before QC_1 is played
      expect((g.view(0)['visibleTeams'] as List)[2], isNull);

      // Seat 0 calls Re and Seat 1 calls Kontra
      g.handle(0, {'type': 'call_re'});
      g.handle(1, {'type': 'call_kontra'});
      expect(g.reCalled, isTrue);
      expect(g.kontraCalled, isTrue);

      // Fast-forward to Trick 10 (last trick): Seat 0 plays JC_0, Seat 1 plays AD_0 (Fox!), Seat 2 plays KD_0, Seat 3 plays TD_1
      g.trickNumber = 10;
      g.hands[0] = ['JC_0'];
      g.hands[1] = ['AD_0'];
      g.hands[2] = ['KD_0'];
      g.hands[3] = ['TD_1'];
      g.handPoints = [120, 40, 30, 22]; // Re already has 150, plus 28 in last trick = 178
      g.tricksWon = [5, 2, 2, 0];

      g.handle(0, {'type': 'play', 'card': 'JC_0'});
      g.handle(1, {'type': 'play', 'card': 'AD_0'});
      g.handle(2, {'type': 'play', 'card': 'KD_0'});
      g.handle(3, {'type': 'play', 'card': 'TD_1'});

      // Seat 0 won the 10th trick with JC_0 (Karlchen!) and captured Seat 1's AD_0 (Fuchs gefangen!)
      expect(g.fuchsCaughtRe, 1);
      expect(g.karlchenRe, isTrue);
      expect(g.lastHandSummary!['reWon'], isTrue);
      expect(g.isOver, isTrue);
      expect(g.placings, [1, 3, 1, 3]);
    });
  });

  group('klaverjassen (荷兰克劳弗牌 Klaverjassen)', () {
    test('32-card deck sums to 152 card points (+10 last trick = 162) and Jas(J=20) > Nel(9=14) trump order', () {
      final deck = buildKlaverjassenDeck();
      expect(deck.length, 32);
      final cardPts = deck.fold<int>(0, (acc, c) => acc + klaverjassenCardPoints(c, 'H'));
      expect(cardPts, 152); // 62 in trump suit + 3 * 30 in non-trump suits = 152 (+10 last trick = 162)

      // In Trump ('H'): JH (20) > 9H (14) > AH (11) > TH (10) > KH (4) > QH (3) > 8H > 7H
      expect(klaverjassenCardPoints('JH', 'H'), 20);
      expect(klaverjassenCardPoints('9H', 'H'), 14);
      expect(klaverjassenCardStrength('JH', 'H', 'H'),
          greaterThan(klaverjassenCardStrength('9H', 'H', 'H')));
      expect(klaverjassenCardStrength('9H', 'H', 'H'),
          greaterThan(klaverjassenCardStrength('AH', 'H', 'H')));
    });

    test('Mandatory Trump & Overtrump rule and Roem (+20 / +50 / Stuk +20 / Four of a Kind +100) + Nat', () {
      // Roem calculations
      expect(klaverjassenTrickRoem(['7S', '8S', '9S', 'AC'], 'H'), 20); // 3-card sequence
      expect(klaverjassenTrickRoem(['TS', 'JS', 'QS', 'KS'], 'H'), 50); // 4-card sequence
      expect(klaverjassenTrickRoem(['KH', 'QH', '7D', '8C'], 'H'), 20); // Stuk (K+Q of trumps)
      expect(klaverjassenTrickRoem(['JH', 'QH', 'KH', '7C'], 'H'), 40); // 3-card run (20) + Stuk (20)
      expect(klaverjassenTrickRoem(['AS', 'AH', 'AD', 'AC'], 'H'), 100); // Four of a Kind

      // Mandatory Trump & Overtrump
      final g = KlaverjassenGame(_setup(4, {'rounds': 1}))..start();
      g.turn = 0;
      g.forehand = 0;
      g.handle(0, {'type': 'choose_trump', 'suit': 'H'});
      expect(g.phase, 'play');
      expect(g.trumpSuit, 'H');
      expect(g.declarerTeam, 0);

      // Seat 0 leads 'AS'; Seat 1 is void in Spades and holds ['8H', '7D'] -> MUST play trump '8H'
      // Seat 2 is void in Spades and holds ['7H', '9H', 'AC'] -> MUST overtrump '8H' with '9H'!
      g.hands[0] = ['AS'];
      g.hands[1] = ['8H', '7D'];
      g.hands[2] = ['7H', '9H', 'AC'];
      g.hands[3] = ['KS'];
      g.handle(0, {'type': 'play', 'card': 'AS'});
      expect(g.legalCards(1), ['8H']);
      g.handle(1, {'type': 'play', 'card': '8H'});
      expect(g.legalCards(2), ['9H']);

      // Test Nat (宕牌): Declarer team (Team 0) scores 80 <= 81 -> goes Nat (0 pts), Team 1 gets all 162 pts!
      for (var s = 0; s < 4; s++) {
        g.hands[s].clear();
      }
      g.teamBasePoints = [80, 82];
      g.teamRoem = [0, 0];
      g.teamTricks = [4, 4];
      g.resolveRound();
      expect(g.lastHandSummary!['isNat'], isTrue);
      expect(g.lastHandSummary!['awarded'], [0, 162]);
      expect(g.teamScores, [0, 162]);
    });
  });

  group('claim (王位争夺战 Claim)', () {
    test('52-card deck and Faction Powers: Knights beat Goblins, Doppelgänger wildcard, Undead Phase 1, Dwarves Phase 2', () {
      final deck = buildClaimDeck();
      expect(deck.length, 52);
      expect(deck.where((c) => claimCardFaction(c) == 0).length, 14); // Goblins
      expect(deck.where((c) => claimCardFaction(c) == 1).length, 8); // Knights
      expect(deck.where((c) => claimCardFaction(c) == 2).length, 10); // Undead
      expect(deck.where((c) => claimCardFaction(c) == 3).length, 10); // Dwarves
      expect(deck.where((c) => claimCardFaction(c) == 4).length, 10); // Doppelgängers

      // Knights Power: Knight K0 played as follower beats Goblin G9 led!
      expect(
        claimTrickWinner([
          {'seat': 0, 'card': 'G9'},
          {'seat': 1, 'card': 'K0'},
        ]),
        1,
      );

      // Doppelgänger Power: M8 played as follower copies led suit (U5) and wins!
      expect(
        claimTrickWinner([
          {'seat': 0, 'card': 'U5'},
          {'seat': 1, 'card': 'M8'},
        ]),
        1,
      );

      // Phase 1 Undead Power & Phase 2 Dwarves Power
      final g = ClaimGame(_setup(2, {'rounds': 1}))..start();
      g.leader = 0;
      g.turn = 0;
      g.prizeCard = 'K9';
      g.followerDeck = ['G1'];
      g.hands[0] = ['U7'];
      g.hands[1] = ['U3'];
      g.phase2Hands[0] = ['D8'];
      g.phase2Hands[1] = ['D2'];

      // Phase 1 last trick: Seat 0 plays U7, Seat 1 plays U3 -> Seat 0 wins BOTH Undead into scorePile[0][2]
      // AND takes prizeCard 'K9' into Phase 2 hand while Seat 1 draws 'G1'!
      g.handle(0, {'type': 'play', 'card': 'U7'});
      g.handle(1, {'type': 'play', 'card': 'U3'});
      expect(g.scorePile[0][2], 2);
      expect(g.phase, 'phase2');
      expect(g.hands[0].toSet(), {'D8', 'K9'});
      expect(g.hands[1].toSet(), {'D2', 'G1'});

      // Phase 2 trick 1: Seat 0 leads D8, Seat 1 follows D2 -> Seat 0 wins trick, so both Dwarves go to LOSER (Seat 1)!
      g.handle(0, {'type': 'play', 'card': 'D8'});
      g.handle(1, {'type': 'play', 'card': 'D2'});
      expect(g.scorePile[0][3], 0);
      expect(g.scorePile[1][3], 2);
    });
  });

  test('bot simulations (30 runs per option/player combination)', () {
    expect(runSims(cards16Games, n: 30), 0);
  });
}
