import 'dart:math';

import 'package:aurora_shared/games/cards13/belote.dart';
import 'package:aurora_shared/games/cards13/cassino.dart';
import 'package:aurora_shared/games/cards13/defs.dart';
import 'package:aurora_shared/games/cards13/millebornes.dart';
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
  group('Belote (法国贝洛特)', () {
    test('32-card deck, Trump (62 pts) vs Non-Trump (30 pts) rank/point order, and mandatory overtrump', () {
      final deck = buildBeloteDeck();
      expect(deck.length, 32);

      // Total card points across all 32 cards with Hearts as trump = 62 + 3*30 = 152 (+10 Dix de Der = 162)
      final totalCardPts = deck.fold<int>(0, (s, c) => s + beloteCardPoints(c, 'H'));
      expect(totalCardPts, 152);

      final trumpPts = deck
          .where((c) => beloteSuit(c) == 'H')
          .fold<int>(0, (s, c) => s + beloteCardPoints(c, 'H'));
      final nonTrumpPts = deck
          .where((c) => beloteSuit(c) == 'S')
          .fold<int>(0, (s, c) => s + beloteCardPoints(c, 'H'));
      expect(trumpPts, 62);
      expect(nonTrumpPts, 30);

      // Verify Trump order: J(20) > 9(14) > A(11) > T(10) > K(4) > Q(3) > 8(0) > 7(0)
      expect(beloteCardPoints('JH', 'H'), 20);
      expect(beloteCardPoints('9H', 'H'), 14);
      expect(beloteCardPoints('JS', 'H'), 2);
      expect(beloteCardPoints('9S', 'H'), 0);
      expect(
        beloteCardStrength('JH', 'H', 'H'),
        greaterThan(beloteCardStrength('9H', 'H', 'H')),
      );
      expect(
        beloteCardStrength('9H', 'H', 'H'),
        greaterThan(beloteCardStrength('AH', 'H', 'H')),
      );

      // Void in led suit ('S') when opponent is winning with trump 'TH':
      // Must overtrump with '9H' or 'JH' (cannot play undertrump '8H' or off-suit 'AD')
      final trick = [
        {'seat': 0, 'card': 'AS'},
        {'seat': 1, 'card': 'TH'},
      ];
      final legal = getBeloteLegalCards(
        cs('8H 9H JH AD'),
        trick,
        'H',
        seat: 2,
        players: 4,
      );
      expect(legal, unorderedEquals(['9H', 'JH']));
    });

    test('2-round bidding, Belote-Rebelote (+20), Contract success vs Dedans (162 sweep)', () {
      // 1. Contract success with Belote-Rebelote (K+Q of trump = +20, threshold = 92)
      final g = BeloteGame(_setup(2, {'rounds': 1}))..start();
      expect(g.phase, 'bid');
      expect(g.bidRound, 1);
      final upSuit = beloteSuit(g.upCard);
      final otherSuit = kBeloteSuits.firstWhere((s) => s != upSuit);

      // Both pass in Round 1 -> enters Round 2 ('choose_suit')
      final first = g.turn;
      final second = (first + 1) % 2;
      g.handle(first, {'type': 'pass'});
      g.handle(second, {'type': 'pass'});
      expect(g.bidRound, 2);

      //Cannot choose upSuit in Round 2
      expect(
        () => g.handle(first, {'type': 'choose_suit', 'suit': upSuit}),
        throwsA(isA<GameError>()),
      );
      g.handle(first, {'type': 'choose_suit', 'suit': otherSuit});
      expect(g.phase, 'play');
      expect(g.taker, first);
      expect(g.trumpSuit, otherSuit);
      expect(g.hands[0].length, 8);
      expect(g.hands[1].length, 8);

      // Fast-forward to last trick: Taker holds K+Q of trump (Belote +20) and wins >= 92 pts
      g.deck.clear();
      g.tricksPlayed = 7;
      g.beloteSeat = first;
      g.capturedCards[first] = cs('J$otherSuit 9$otherSuit A$otherSuit T$otherSuit K$otherSuit Q$otherSuit'); // 62 pts
      g.capturedCards[second] = cs('AS TS KS QS JS'); // 30 pts
      g.hands[first] = ['8$otherSuit']; // Wins 8th trick (+10 Dix de Der)
      g.hands[second] = ['7$otherSuit'];
      g.turn = first;

      g.handle(first, {'type': 'play', 'card': '8$otherSuit'});
      g.handle(second, {'type': 'play', 'card': '7$otherSuit'});

      expect(g.isOver, isTrue);
      expect(g.lastHandSummary!['contractSuccess'], isTrue);
      expect(g.lastHandSummary!['threshold'], 92);
      expect(g.scores[first], greaterThanOrEqualTo(92));

      // 2. Dedans (崩盘): Taker scores < 82 -> Defenders score all 162 points!
      final g2 = BeloteGame(_setup(2, {'rounds': 1}))..start();
      final f2 = g2.turn;
      final s2 = (f2 + 1) % 2;
      final tSuit = beloteSuit(g2.upCard);
      g2.handle(f2, {'type': 'take'});
      g2.deck.clear();
      g2.beloteSeat = null;
      g2.tricksPlayed = 7;
      g2.capturedCards[f2] = cs('K$tSuit 8$tSuit'); // Only 4 pts
      g2.capturedCards[s2] = cs('J$tSuit 9$tSuit A$tSuit T$tSuit AS TS');
      g2.hands[f2] = ['7S'];
      g2.hands[s2] = ['Q$tSuit'];
      g2.turn = f2;

      g2.handle(f2, {'type': 'play', 'card': '7S'});
      g2.handle(s2, {'type': 'play', 'card': 'Q$tSuit'});

      expect(g2.isOver, isTrue);
      expect(g2.lastHandSummary!['dedans'], isTrue);
      expect(g2.scores[f2], 0);
      expect(g2.scores[s2], 162);
    });
  });

  group('Cassino (卡西诺抓牌)', () {
    test('build validation (<=10 and requires matching V in hand), trail restriction, capture & Sweep (+1)', () {
      final g = CassinoGame(_setup(2, {'rounds': 1}))..start();
      g.turn = 0;
      g.tableCards = cs('2C 5D');
      g.builds = [];
      g.hands[0] = cs('3H 5S 9C KD');
      g.hands[1] = cs('7S 8H');

      // Seat 0 tries to build 3H + 5D = 8, but does NOT hold an 8 in hand -> throws GameError!
      expect(
        () => g.handle(0, {
          'type': 'play',
          'mode': 'build',
          'card': '3H',
          'cards': ['5D'],
        }),
        throwsA(isA<GameError>()),
      );

      // Seat 0 builds 3H + 2C = 5 (holds 5S in hand!) -> succeeds!
      g.handle(0, {
        'type': 'play',
        'mode': 'build',
        'card': '3H',
        'cards': ['2C'],
      });
      expect(g.builds.length, 1);
      expect(g.builds.first['value'], 5);
      expect(g.builds.first['owner'], 0);

      // Seat 1 trails 7S onto table
      g.handle(1, {'type': 'play', 'mode': 'trail', 'card': '7S'});

      // Seat 0 currently owns an active build -> CANNOT trail!
      expect(
        () => g.handle(0, {'type': 'play', 'mode': 'trail', 'card': '9C'}),
        throwsA(isA<GameError>()),
      );

      // Remove 7S from table so capturing 5D + the 5-build clears the entire table for a Sweep!
      g.tableCards = ['5D'];
      g.handle(0, {
        'type': 'play',
        'mode': 'capture',
        'card': '5S',
        'cards': ['5D'],
        'builds': [0],
      });
      expect(g.tableCards, isEmpty);
      expect(g.builds, isEmpty);
      expect(g.sweeps[0], 1); // +1 Sweep!
      expect(g.capturedCards[0], containsAll(['5S', '5D', '3H', '2C']));
    });

    test('End-of-Deck 11 base points + Sweeps scoring', () {
      final fullDeck = buildCassinoDeck();
      // Give Seat 0: 30 cards including TD (Big Cassino +2), 2S (Little Cassino +1), 3 Aces (+3), 9 Spades (Most Spades +1), Most Cards (+3) = 10 base pts + 2 sweeps = 12 pts
      // Give Seat 1: remaining 22 cards including 1 Ace ('AC', +1 pt) + 0 sweeps = 1 pt
      final p0Cards = fullDeck.where((c) => c != 'AC').take(30).toList();
      if (!p0Cards.contains('TD')) p0Cards[0] = 'TD';
      if (!p0Cards.contains('2S')) p0Cards[1] = '2S';
      for (final a in ['AS', 'AH', 'AD']) {
        if (!p0Cards.contains(a)) p0Cards.add(a);
      }
      final p1Cards = fullDeck.where((c) => !p0Cards.contains(c)).toList();

      final summary = computeCassinoDeckSummary([p0Cards, p1Cards], [2, 0]);
      final pts = (summary['points'] as List).cast<int>();
      expect(summary['mostCardsWinner'], 0);
      expect(summary['mostSpadesWinner'], 0);
      expect(summary['bigCassinoWinner'], 0);
      expect(summary['littleCassinoWinner'], 0);
      expect(pts[0], 3 + 1 + 2 + 1 + 3 + 2); // 10 base + 2 sweeps = 12
      expect(pts[1], 1); // 1 Ace ('AC') = 1
      expect((pts[0] - 2) + pts[1], 11); // Total base points = 11!
    });
  });

  group('Mille Bornes (千里之行)', () {
    test('106-card deck, rolling/speedLimit/D200/exact target restrictions', () {
      final deck = buildMilleBornesDeck();
      expect(deck.length, 106);

      final g = MilleBornesGame(_setup(2, {'target': 700}))..start();
      g.turn = 0;
      g.hands[0] = cs('D100 R_ROLL D200 D200 D200 D75 D50');
      g.hands[1] = cs('H_LIMIT D25 D25 D25 D25 D25 D25');

      // Cannot play D100 before R_ROLL
      expect(
        () => g.handle(0, {'type': 'play', 'card': 'D100'}),
        throwsA(isA<GameError>()),
      );

      // Play R_ROLL -> rolling[0] = true
      g.handle(0, {'type': 'play', 'card': 'R_ROLL'});
      expect(g.rolling[0], isTrue);

      // Seat 1 plays H_LIMIT on Seat 0 -> speedLimit[0] = true
      g.handle(1, {'type': 'play', 'card': 'H_LIMIT', 'targetSeat': 0});
      expect(g.speedLimit[0], isTrue);

      // Under speed limit, Seat 0 cannot play D100, but can play D50!
      expect(
        () => g.handle(0, {'type': 'play', 'card': 'D100'}),
        throwsA(isA<GameError>()),
      );
      g.handle(0, {'type': 'play', 'card': 'D50'});
      expect(g.distance[0], 50);

      // Clear speed limit and test max two D200s and exact target (700 km)
      g.speedLimit[0] = false;
      g.turn = 0;
      g.handle(0, {'type': 'play', 'card': 'D200'});
      g.turn = 0;
      g.handle(0, {'type': 'play', 'card': 'D200'});
      expect(g.d200Count[0], 2);
      expect(g.distance[0], 450);

      // 3rd D200 is illegal!
      g.turn = 0;
      expect(
        () => g.handle(0, {'type': 'play', 'card': 'D200'}),
        throwsA(isA<GameError>()),
      );

      // At 650 km, D75 (exceeding 700) is illegal, while D50 wins the game!
      g.distance[0] = 650;
      g.hands[0] = cs('D75 D50');
      expect(
        () => g.handle(0, {'type': 'play', 'card': 'D75'}),
        throwsA(isA<GameError>()),
      );
      g.handle(0, {'type': 'play', 'card': 'D50'});
      expect(g.distance[0], 700);
      expect(g.isOver, isTrue);
      expect(g.placings, [1, 2]);
    });

    test('Hazards, Remedies, Safety immunity (+100 & extra turn), and Coup-Fourré (+300)', () {
      final g = MilleBornesGame(_setup(2, {'target': 1000}))..start();
      g.turn = 0;
      g.rolling[0] = true;
      g.rolling[1] = true;
      g.hands[0] = cs('H_GAS S_TIRE D100 D50 D25 D25 D25');
      g.hands[1] = cs('S_GAS D100 H_TIRE D50 D25 D25 D25');

      // Seat 0 hits Seat 1 with H_GAS -> Seat 1 stops rolling and has H_GAS
      g.handle(0, {'type': 'play', 'card': 'H_GAS', 'targetSeat': 1});
      expect(g.battleHazard[1], 'H_GAS');
      expect(g.rolling[1], isFalse);

      // Seat 1 immediately plays S_GAS -> triggers Coup-Fourré (+300 pts), cures H_GAS, sets rolling=true, and grants extra turn!
      g.handle(1, {'type': 'play', 'card': 'S_GAS'});
      expect(g.battleHazard[1], isNull);
      expect(g.rolling[1], isTrue);
      expect(g.safeties[1], contains('S_GAS'));
      expect(g.bonusPoints[1], 300);
      expect(g.turn, 1); // Extra turn!

      // Seat 1 uses extra turn to play D100
      g.handle(1, {'type': 'play', 'card': 'D100'});
      expect(g.distance[1], 100);
      expect(g.scores[1], 400);

      // Seat 0 plays S_TIRE proactively (normal Safety -> +100 pts and extra turn)
      expect(g.turn, 0);
      g.handle(0, {'type': 'play', 'card': 'S_TIRE'});
      expect(g.safeties[0], contains('S_TIRE'));
      expect(g.bonusPoints[0], 100);
      expect(g.turn, 0); // Extra turn!
      g.handle(0, {'type': 'play', 'card': 'D100'});

      // Seat 1 tries to play H_TIRE on Seat 0 -> blocked by S_TIRE immunity!
      expect(g.turn, 1);
      expect(
        () => g.handle(1, {'type': 'play', 'card': 'H_TIRE', 'targetSeat': 0}),
        throwsA(isA<GameError>()),
      );
    });
  });

  test('bot simulations for cards13Games (count: 30)', () {
    expect(runSims(cards13Games, n: 30), 0);
  });
}
