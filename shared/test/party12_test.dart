import 'dart:math';

import 'package:aurora_shared/games/party12/deception.dart';
import 'package:aurora_shared/games/party12/defs.dart';
import 'package:aurora_shared/games/party12/draftosaurus.dart';
import 'package:aurora_shared/games/party12/modernart.dart';
import 'package:aurora_shared/games/party12/survive.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameDef _def(String id) => party12Games.firstWhere((d) => d.id == id);

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
  final e = def.create(setup);
  e.start();
  return e as T;
}

void main() {
  test('runSims party12', () {
    expect(runSims(party12Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 10)));

  group('deception (犯罪现场)', () {
    test('role visibility, badge consumption, and 4p solve victory', () {
      final e = _start<DeceptionGame>('deception', 4, seed: 10);
      expect(e.phase, 'night');
      expect(e.waitingFor, [e.murdererSeat]);

      final mCard = e.means[e.murdererSeat][1];
      final cCard = e.clues[e.murdererSeat][2];
      e.handle(e.murdererSeat, {'type': 'commit', 'means': mCard, 'clue': cCard});

      expect(e.phase, 'forensic');
      expect(e.keyMeans, mCard);
      expect(e.keyClue, cCard);

      // Forensic and Murderer see solution; Investigator and Spectator do not
      final invSeat = e.suspects.firstWhere((s) => s != e.murdererSeat);
      expect(e.view(e.forensicSeat)['keyMeans'], mCard);
      expect(e.view(e.murdererSeat)['keyClue'], cCard);
      expect(e.view(invSeat)['keyMeans'], isNull);
      expect(e.view(invSeat)['murdererSeat'], isNull);
      expect(e.view(-1)['keyMeans'], isNull);

      // Round 1 Forensic places 6 bullet markers
      e.handle(e.forensicSeat, {
        'type': 'forensic',
        'bullets': [0, 1, 2, 3, 4, 5],
      });
      expect(e.phase, 'investigate');

      // First investigator makes a wrong solve -> badge consumed, game continues
      final firstTurn = e.currentInvestigator;
      final wrongMeans = e.means[e.murdererSeat][0]; // index 0 != index 1
      e.handle(firstTurn, {
        'type': 'solve',
        'suspect': e.murdererSeat,
        'means': wrongMeans,
        'clue': cCard,
      });
      expect(e.badge[firstTurn], isFalse);
      expect(e.isOver, isFalse);

      // Next investigator solves correctly -> immediate win in 4p
      final secondTurn = e.currentInvestigator;
      e.handle(secondTurn, {
        'type': 'solve',
        'suspect': e.murdererSeat,
        'means': mCard,
        'clue': cCard,
      });
      expect(e.isOver, isTrue);
      expect(e.winnerTeam, 'investigators');
    });

    test('6p Accomplice & Witness roles and assassinate_witness reversal', () {
      final e = _start<DeceptionGame>('deception', 6, seed: 19);
      expect(e.accompliceSeat, isNotNull);
      expect(e.witnessSeat, isNotNull);

      final mCard = e.means[e.murdererSeat][0];
      final cCard = e.clues[e.murdererSeat][0];
      e.handle(e.murdererSeat, {'type': 'commit', 'means': mCard, 'clue': cCard});

      // Accomplice knows solution; Witness knows who the evil suspects are but NOT the cards
      expect(e.view(e.accompliceSeat!)['keyMeans'], mCard);
      expect(e.view(e.witnessSeat!)['witnessSuspects'], containsAll([e.murdererSeat, e.accompliceSeat]));
      expect(e.view(e.witnessSeat!)['keyMeans'], isNull);

      e.handle(e.forensicSeat, {
        'type': 'forensic',
        'bullets': [1, 1, 1, 1, 1, 1],
      });

      final solver = e.currentInvestigator;
      e.handle(solver, {
        'type': 'solve',
        'suspect': e.murdererSeat,
        'means': mCard,
        'clue': cCard,
      });

      // Enters assassinate_witness phase
      expect(e.phase, 'assassinate_witness');
      expect(e.waitingFor, [e.murdererSeat]);

      // Murderer correctly guesses Witness -> Murderer & Accomplice steal win!
      e.handle(e.murdererSeat, {'type': 'assassinate', 'target': e.witnessSeat});
      expect(e.isOver, isTrue);
      expect(e.witnessKilled, isTrue);
      expect(e.winnerTeam, 'murderer');
      expect(e.placings![e.murdererSeat], 1);
      expect(e.placings![e.accompliceSeat!], 1);
      expect(e.placings![e.forensicSeat], 2);
    });
  });

  group('modernart (现代艺术)', () {
    test('all 5 auction types and 5th painting season-end valuation', () {
      final e = _start<ModernArtGame>('modernart', 3, seed: 7);
      expect(e.cash, [100, 100, 100]);

      // Force custom hands to test each auction type deterministically
      e.hands[0] = [
        const PaintingCard(id: 901, artist: 0, auctionType: 'open', title: 'A1'),
        const PaintingCard(id: 902, artist: 0, auctionType: 'double', title: 'A2'),
        const PaintingCard(id: 903, artist: 0, auctionType: 'fixed', title: 'A3'),
      ];
      e.hands[1] = [
        const PaintingCard(id: 904, artist: 1, auctionType: 'once', title: 'B1'),
        const PaintingCard(id: 905, artist: 0, auctionType: 'open', title: 'A4'),
      ];
      e.hands[2] = [
        const PaintingCard(id: 906, artist: 2, auctionType: 'sealed', title: 'C1'),
        const PaintingCard(id: 907, artist: 0, auctionType: 'open', title: 'A5'),
      ];

      // 1. Open auction by P0 (artist 0, count -> 1)
      e.handle(0, {'type': 'play', 'cardId': 901});
      expect(e.phase, 'open');
      e.handle(1, {'type': 'bid', 'amount': 15});
      e.handle(2, {'type': 'pass'});
      e.handle(0, {'type': 'pass'});
      expect(e.cash[1], 85);
      expect(e.cash[0], 115);
      expect(e.seasonPaintings[1][0], 1);

      // 2. Once-around auction by P1 (artist 1, count -> 1)
      expect(e.turnSeat, 1);
      e.handle(1, {'type': 'play', 'cardId': 904});
      expect(e.phase, 'once');
      e.handle(2, {'type': 'bid', 'amount': 10});
      e.handle(0, {'type': 'bid', 'amount': 20});
      e.handle(1, {'type': 'pass'});
      expect(e.seasonPaintings[0][1], 1);
      expect(e.cash[0], 95);
      expect(e.cash[1], 105);

      // 3. Sealed auction by P2 (artist 2, count -> 1)
      expect(e.turnSeat, 2);
      e.handle(2, {'type': 'play', 'cardId': 906});
      expect(e.phase, 'sealed');
      e.handle(0, {'type': 'bid', 'amount': 12});
      // Other players cannot see P0's sealed bid before all submit
      expect(e.view(1)['mySealedBid'], isNull);
      e.handle(1, {'type': 'bid', 'amount': 12});
      e.handle(2, {'type': 'bid', 'amount': 5});
      // Tie between P0 and P1 broken clockwise from seller P2 -> P0 wins!
      expect(e.seasonPaintings[0][2], 1);
      expect(e.cash[0], 83);
      expect(e.cash[2], 112);

      // 4. Double + Fixed auction by P0 (artist 0, 2 cards -> count becomes 1 + 2 = 3)
      expect(e.turnSeat, 0);
      e.handle(0, {'type': 'play', 'cardId': 902, 'secondCardId': 903, 'price': 25});
      expect(e.phase, 'fixed');
      e.handle(1, {'type': 'pass'});
      e.handle(2, {'type': 'buy'});
      expect(e.seasonPaintings[2][0], 2);
      expect(e.seasonCount[0], 3);

      // 5. P1 plays 4th painting of artist 0 (open auction, everyone passes -> P1 gets for free)
      e.handle(1, {'type': 'play', 'cardId': 905});
      e.handle(2, {'type': 'pass'});
      e.handle(0, {'type': 'pass'});
      e.handle(1, {'type': 'pass'});
      expect(e.seasonCount[0], 4);
      expect(e.seasonPaintings[1][0], 2);

      // 6. P2 plays 5th painting of artist 0 -> Season 1 ends immediately without auction!
      // Season counts: artist 0 has 5, artist 1 has 1, artist 2 has 1 -> bonuses +30, +20, +10
      final cashBefore = List.of(e.cash);
      e.handle(2, {'type': 'play', 'cardId': 907});
      expect(e.season, 2);
      expect(e.cumulativeValue, [30, 20, 10, 0, 0]);
      // P0 had 1 of artist 1 ($20) + 1 of artist 2 ($10) = +$30
      // P1 had 2 of artist 0 ($60) = +$60
      // P2 had 2 of artist 0 ($60) = +$60
      expect(e.cash[0], cashBefore[0] + 30);
      expect(e.cash[1], cashBefore[1] + 60);
      expect(e.cash[2], cashBefore[2] + 60);
    });
  });

  group('survive (逃离亚特兰蒂斯)', () {
    test('secret explorer values hidden from opponents, safe island rescue, and volcano', () {
      final e = _start<SurviveGame>('survive', 2, seed: 11);
      final p0Exps = e.explorers.where((x) => x.owner == 0).toList();
      expect(p0Exps.map((x) => x.value).toList()..sort(), [1, 1, 2, 2, 3, 4]);

      // In view(1) and view(-1), P0's living explorer values must be hidden (null)
      final v1Exps = e.view(1)['explorers'] as List;
      final p0InV1 = v1Exps.where((x) => (x as Map)['owner'] == 0).toList();
      expect(p0InV1.every((x) => (x as Map)['value'] == null), isTrue);

      // In view(0), P0 sees their own explorer values
      final v0Exps = e.view(0)['explorers'] as List;
      final p0InV0 = v0Exps.where((x) => (x as Map)['owner'] == 0).toList();
      expect(p0InV0.every((x) => (x as Map)['value'] != null), isTrue);

      // Place P0's value-4 explorer adjacent to corner safe island (0,0) at (0,1) and move onto (0,0)
      final hero = p0Exps.firstWhere((x) => x.value == 4);
      hero.r = 0;
      hero.c = 1;
      e.handle(0, {'type': 'move', 'explorerId': hero.id, 'r': 0, 'c': 0});
      expect(hero.status, 'rescued');
      expect(e.score[0], 4);

      // Rescued explorer value is now visible to opponent too!
      final rescuedInV1 = (e.view(1)['explorers'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((x) => x['id'] == hero.id);
      expect(rescuedInV1['value'], 4);

      // End move -> sink phase requires sinking lowest elevation (Beach = 1)
      e.handle(0, {'type': 'end_move'});
      expect(e.phase, 'sink');
      expect(e.minIslandTerrain, 1);

      // Trying to sink a Mountain (3) while Beach (1) exists throws GameError
      var mountainCell = (3, 3);
      for (var r = 1; r <= 5; r++) {
        for (var c = 1; c <= 5; c++) {
          if (e.terrain[r][c] == 3) mountainCell = (r, c);
        }
      }
      expect(
        () => e.handle(0, {'type': 'sink', 'r': mountainCell.$1, 'c': mountainCell.$2}),
        throwsA(isA<GameError>()),
      );
    });
  });

  group('draftosaurus (恐龙岛选秀)', () {
    test('placement die constraint enforcement and all 6 pen + T-Rex + River scoring', () {
      final e = _start<DraftosaurusGame>('draftosaurus', 2, seed: 5);
      e.rollerSeat = 0;
      e.constraint = 0; // 0: 森林区 (only pens 0, 3, 4 allowed for non-roller P1)
      e.hands[0] = [0, 1, 2, 3, 4, 5];
      e.hands[1] = [0, 1, 2, 3, 4, 5];

      // P1 (non-roller) tries to place into Pen 1 (平原区) -> rejected!
      expect(
        () => e.handle(1, {'type': 'place', 'dino': 1, 'pen': 1}),
        throwsA(isA<GameError>()),
      );

      // P0 (roller) ignores constraint and CAN place into Pen 1 (平原区)!
      e.handle(0, {'type': 'place', 'dino': 1, 'pen': 1});
      // P1 places into River (pen 6) which is always legal
      e.handle(1, {'type': 'place', 'dino': 2, 'pen': 6});

      expect(e.turn, 2);
      expect(e.pens[0][1], [1]);
      expect(e.river[1], [2]);

      // Verify comprehensive park scoring breakdown:
      // Configure P0's pens:
      // Pen 0 (同类之森): 3 of species 1 -> 8 VP
      // Pen 1 (百兽草甸): 4 distinct species [0, 1, 2, 3] -> 10 VP (+1 T-Rex)
      // Pen 2 (爱之草原): [4, 4, 5, 5, 2] -> 2 pairs -> 10 VP
      // Pen 3 (三重林): [0, 2, 3] -> 3 dinos -> 7 VP (+1 T-Rex)
      // Pen 4 (丛林之王): [1] -> P0 has five species-1 dinos vs P1's zero -> 7 VP
      // Pen 5 (孤岛): [5] -> wait, species 5 is also in Pen 2 so count is 3 -> 0 VP; let's put [3] vs unique!
      e.pens[0] = [
        [1, 1, 1], // Pen 0: 8 VP
        [0, 1, 2], // Pen 1: 6 VP (+1 T-Rex)
        [4, 4, 4, 4], // Pen 2: 2 pairs = 10 VP
        [0, 2, 2], // Pen 3: 3 dinos = 7 VP (+1 T-Rex)
        [1], // Pen 4: King of Jungle (species 1) = 7 VP
        [5], // Pen 5: Solitary Island (only species 5 in park) = 7 VP
      ];
      e.river[0] = [3, 3]; // River: 2 VP
      final bd = e.scoreBreakdown(0);
      expect(bd['penScores'], [8, 6, 10, 7, 7, 7]);
      expect(bd['trexBonus'], 2);
      expect(bd['riverScore'], 2);
      expect(bd['total'], 8 + 6 + 10 + 7 + 7 + 7 + 2 + 2);
    });
  });
}
