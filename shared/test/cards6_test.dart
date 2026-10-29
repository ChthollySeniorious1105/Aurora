import 'dart:math';

import 'package:aurora_shared/games/cards6/cribbage.dart';
import 'package:aurora_shared/games/cards6/defs.dart';
import 'package:aurora_shared/games/cards6/durak.dart';
import 'package:aurora_shared/games/cards6/ohhell.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

List<String> cs(String s) => s.split(' ');

GameSetup _setup(int n, Map<String, dynamic> opts, {int seed = 1}) => GameSetup(
      players: n,
      options: opts,
      names: [for (var i = 0; i < n; i++) 'P$i'],
      bots: List.filled(n, true),
      rng: Random(seed),
    );

void main() {
  group('Cribbage', () {
    test('pegging scoring: 15, 31, pairs, runs', () {
      expect(scorePeggingPlay(cs('7S 8H'), 15).pts, 2);
      expect(scorePeggingPlay(cs('TS QH AS KC'), 31).pts, 2);
      expect(scorePeggingPlay(cs('6S 6H'), 12).pts, 2);
      expect(scorePeggingPlay(cs('6S 6H 6D'), 18).pts, 6);
      expect(scorePeggingPlay(cs('6S 6H 6D 6C'), 24).pts, 12);
      // 3-card run in out-of-order sequence: 5, 3, 4 -> count 12, run of 3 (+3)
      expect(scorePeggingPlay(cs('5S 3H 4D'), 12).pts, 3);
      // 3-card run summing to 15: 4, 6, 5 -> 15 (+2) + run of 3 (+3) = 5
      expect(scorePeggingPlay(cs('4S 6H 5D'), 15).pts, 5);
    });

    test('show scoring: 29-point hand, double run, flush, nobs', () {
      // Classic highest possible Cribbage hand: 5S, 5D, 5C, JH with starter 5H -> 29 pts!
      final maxHand = scoreCribbageHand(cs('5S 5D 5C JH'), '5H');
      expect(maxHand.fifteens, 16);
      expect(maxHand.pairs, 12);
      expect(maxHand.nobs, 1);
      expect(maxHand.total, 29);

      // Double run of 3: 4S, 5H, 6D, 6C + starter AH -> 4+5+6=15 (x2 = 4), pair of 6s (2), two 3-runs (6) = 12
      final dblRun = scoreCribbageHand(cs('4S 5H 6D 6C'), 'AH');
      expect(dblRun.fifteens, 4);
      expect(dblRun.pairs, 2);
      expect(dblRun.runs, 6);
      expect(dblRun.total, 12);

      // 4-card flush in hand vs crib
      expect(scoreCribbageHand(cs('2S 4S 7S 9S'), 'KH', isCrib: false).flush, 4);
      expect(scoreCribbageHand(cs('2S 4S 7S 9S'), 'KH', isCrib: true).flush, 0);
      expect(scoreCribbageHand(cs('2S 4S 7S 9S'), 'KS', isCrib: true).flush, 5);
    });

    test('discard, pegging go, show order and immediate win', () {
      final e = Cribbage(_setup(2, {'target': 61}, seed: 10))..start();
      e.dealer = 0;
      e.hands = [
        cs('5S 5D 5C JH 2S 3C'),
        cs('TS QH KC 9D 2H 3D'),
      ];
      e.deck = List.filled(20, '5H'); // starter will be 5H (not Jack)

      e.handle(0, {'type': 'discard', 'cards': cs('2S 3C')});
      e.handle(1, {'type': 'discard', 'cards': cs('2H 3D')});
      expect(e.phase, 'pegging');
      expect(e.starter, '5H');
      expect(e.turn, 1); // Non-dealer leads

      // Play until Go: P1 plays TS(10), P0 plays JH(20), P1 plays QH(30 -> T-J-Q 3-card run +3!)
      e.handle(1, {'type': 'play', 'card': 'TS'});
      e.handle(0, {'type': 'play', 'card': 'JH'});
      e.handle(1, {'type': 'play', 'card': 'QH'});
      expect(e.count, 30);
      expect(e.scores[1], 3);
      // P0 has only 5s (30+5 > 31), so P0 must say 'go'
      expect(() => e.handle(0, {'type': 'play', 'card': '5S'}), throwsA(isA<GameError>()));
      e.handle(0, {'type': 'go'});
      // P1 also has only KC and 9D (>1), so P1 immediately scores +1 for Go (total 4) and count resets to 0!
      expect(e.count, 0);
      expect(e.scores[1], 4);
    });
  });

  group('Oh Hell', () {
    test('Hook Rule (庄家禁手规则) forbids dealer from making total bids == N', () {
      final e = OhHell(_setup(3, {'schedule': 'short', 'scoring': 'standard'}))..start();
      e.dealer = 2;
      e.turn = 0;
      // N = 5 cards in round 1 of short schedule
      expect(e.cardsThisRound, 5);
      e.handle(0, {'type': 'bid', 'bid': 2});
      e.handle(1, {'type': 'bid', 'bid': 1});
      // Dealer (seat 2) is forbidden from bidding 5 - (2 + 1) = 2
      expect(e.forbiddenBidFor(2), 2);
      expect(() => e.handle(2, {'type': 'bid', 'bid': 2}), throwsA(isA<GameError>()));
      e.handle(2, {'type': 'bid', 'bid': 3});
      expect(e.phase, 'play');
    });

    test('trick-taking and exact contract scoring', () {
      final e = OhHell(_setup(3, {'schedule': 'full', 'scoring': 'penalty'}))..start();
      // Round 1 of 'full' has N = 1 card per player
      e.dealer = 2;
      e.turn = 0;
      e.trumpCard = '2S';
      e.trumpSuit = 'S';
      e.hands = [
        ['AH'],
        ['3S'], // Trump beats AH
        ['KH'],
      ];
      e.handle(0, {'type': 'bid', 'bid': 1});
      e.handle(1, {'type': 'bid', 'bid': 1});
      // Total so far = 2 != 1, so dealer can bid 0
      e.handle(2, {'type': 'bid', 'bid': 0});

      e.handle(0, {'type': 'play', 'card': 'AH'});
      e.handle(1, {'type': 'play', 'card': '3S'});
      e.handle(2, {'type': 'play', 'card': 'KH'});

      // Seat 1 won 1 trick (bid 1 -> +11), Seat 0 won 0 (bid 1 -> -1), Seat 2 won 0 (bid 0 -> +10)
      expect(e.scores, [-1, 11, 10]);
      expect(e.roundIndex, 1);
    });
  });

  group('Durak', () {
    test('attack, throw-in matching rank, defend, done, and take', () {
      final e = Durak(_setup(2, {}, seed: 5))..start();
      e.trumpSuit = 'S';
      e.trumpCard = '6S';
      e.attacker = 0;
      e.defender = 1;
      e.turn = 0;
      e.phase = 'attack';
      e.hands = [
        cs('7H 8H 9D KC'),
        cs('8D 9H TD JC'),
      ];
      e.talon = [];

      // P0 attacks with 7H
      e.handle(0, {'type': 'attack', 'card': '7H'});
      expect(e.phase, 'defend');
      expect(e.turn, 1);

      // P1 cannot defend 7H with 8D (wrong suit, not trump)
      expect(() => e.handle(1, {'type': 'defend', 'card': '8D'}), throwsA(isA<GameError>()));
      // P1 defends 7H with 9H
      e.handle(1, {'type': 'defend', 'card': '9H'});
      expect(e.phase, 'attack');
      expect(e.turn, 0);

      // P0 cannot throw in 8H (neither 7 nor 9), but CAN throw in 9D (matches 9H)!
      expect(() => e.handle(0, {'type': 'attack', 'card': '8H'}), throwsA(isA<GameError>()));
      e.handle(0, {'type': 'attack', 'card': '9D'});
      expect(e.phase, 'defend');

      // P1 defends 9D with TD
      e.handle(1, {'type': 'defend', 'card': 'TD'});
      expect(e.phase, 'attack');

      // P0 ends bout ('done'): P1 becomes next attacker!
      e.handle(0, {'type': 'done'});
      expect(e.attacker, 1);
      expect(e.defender, 0);
      expect(e.discardCount, 4);
    });
  });

  test('bot simulations for cards6Games', () {
    expect(runSims(cards6Games, n: 30), 0);
  });
}
