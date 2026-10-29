import 'dart:math';

import 'package:aurora_shared/games/mahjong3/aotenjou.dart';
import 'package:aurora_shared/games/mahjong3/defs.dart';
import 'package:aurora_shared/games/mahjong3/tiles.dart';
import 'package:aurora_shared/games/mahjong3/wuhan.dart';
import 'package:aurora_shared/games/mahjong3/xueliu.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

List<int> h(String s, [int kinds = kKinds]) => countsOf(parseTiles(s), kinds);

void main() {
  claimCoverEnabled = false;

  group('武汉麻将 (wuhanmj)', () {
    test('laizi indicator cyclic order and 7z -> 5z rule', () {
      expect(wuhanLaiziFromCode('1m'), '2m');
      expect(wuhanLaiziFromCode('9m'), '1m');
      expect(wuhanLaiziFromCode('9p'), '1p');
      expect(wuhanLaiziFromCode('9s'), '1s');
      expect(wuhanLaiziFromCode('1z'), '2z');
      expect(wuhanLaiziFromCode('4z'), '1z');
      expect(wuhanLaiziFromCode('5z'), '6z');
      // 6z next would be 7z (红中), must become 5z (白板)
      expect(wuhanLaiziFromCode('6z'), '5z');
      expect(wuhanLaiziFromCode('7z'), '5z');
    });

    test('kaikou requirement and 2-5-8 jiang with laizi wildcard', () {
      final laizi = tileFromCode('3m');
      // Normal hand with 5s pair: valid when kaikou=true, invalid when kaikou=false & requireKaikou=true
      expect(
        wuhanEvaluate(h('123m456p789s234p55s'), const [], laiziTile: laizi, kaikou: false, requireKaikou: true),
        isNull,
      );
      expect(
        wuhanEvaluate(h('123m456p789s234p55s'), const [], laiziTile: laizi, kaikou: true, requireKaikou: true),
        isNotNull,
      );
      expect(
        wuhanEvaluate(h('123m456p789s234p55s'), const [], laiziTile: laizi, kaikou: false, requireKaikou: false),
        isNotNull,
      );

      // Non-258 pair fails for normal hand
      expect(
        wuhanEvaluate(h('123m456p789s234p11s'), const [], laiziTile: laizi, kaikou: true, requireKaikou: true),
        isNull,
      );

      // Laizi ('3m') substitutes for missing tile in sequence or 2-5-8 pair
      expect(
        wuhanEvaluate(h('123m456p789s234p5s3m'), const [], laiziTile: laizi, kaikou: true, requireKaikou: true),
        isNotNull,
      );

      // Big hands (碰碰胡 / 清一色 / 将一色 / 风一色) do not require 2-5-8 pair
      final pengRes = wuhanEvaluate(
        h('111m333p777s999m11z'),
        const [],
        laiziTile: laizi,
        kaikou: true,
        requireKaikou: true,
      )!;
      expect(pengRes.isBig, isTrue);
      expect(pengRes.label, contains('碰碰胡'));

      final qingRes = wuhanEvaluate(
        h('11123456789999p'),
        const [],
        laiziTile: laizi,
        kaikou: true,
        requireKaikou: true,
      )!;
      expect(qingRes.isBig, isTrue);
      expect(qingRes.label, contains('清一色'));

      final jiangRes = wuhanEvaluate(
        h('222555888m2255p8s'),
        const [],
        laiziTile: laizi,
        kaikou: true,
        requireKaikou: true,
      )!;
      expect(jiangRes.isBig, isTrue);
      expect(jiangRes.label, contains('将一色'));

      final fengRes = wuhanEvaluate(
        h('11122233344455z'),
        const [],
        laiziTile: laizi,
        kaikou: true,
        requireKaikou: true,
      )!;
      expect(fengRes.isBig, isTrue);
      expect(fengRes.label, contains('风一色'));
    });

    test('laizi_gang multiplies gangMultipliers and draws replacement tile', () {
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'requireKaikou': false},
        names: const ['A', 'B', 'C', 'D'],
        bots: const [false, false, false, false],
        rng: Random(42),
      );
      final g = WuhanGame(setup)..start();
      final s = g.turn;
      g.hands[s][kChun]++; // give Red Dragon '7z'
      final wallBefore = g.wall.length;
      expect(g.gangMultipliers[s], 1);
      g.handle(s, {'type': 'laizi_gang', 'tile': '7z'});
      expect(g.gangMultipliers[s], 2);
      expect(g.wall.length, wallBefore - 1);
      expect(g.specialGangs[s], contains('7z'));
    });
  });

  group('血流成河 (xueliu)', () {
    test('swap -> dingque -> play continuous wins and wall exhaustion checks', () {
      final setup = GameSetup(
        players: 4,
        options: const {'hands': 1, 'swap': true, 'cap': 5},
        names: const ['A', 'B', 'C', 'D'],
        bots: const [false, false, false, false],
        rng: Random(11),
      );
      final g = XueliuGame(setup)..start();
      expect(g.phase, 'swap');

      // Step 1: swap 3 same-suit tiles for each seat
      for (var s = 0; s < 4; s++) {
        final a = g.bot(s)!;
        expect(a['type'], 'swap');
        g.handle(s, a);
      }
      expect(g.phase, 'dingque');

      // Step 2: dingque
      final suits = ['s', 's', 's', 's'];
      for (var s = 0; s < 4; s++) {
        g.handle(s, {'type': 'dingque', 'suit': suits[s]});
      }
      expect(g.phase, 'play');
      expect(g.queSuit, ['s', 's', 's', 's']);

      // Set up dealer (g.turn) with a winning self-draw hand (no 's' tiles)
      final d = g.turn;
      g.hands[d] = h('123456789m1122p', kNumKinds);
      g.hands[d][tileFromCode('1p')]++; // 14th winning tile: 123456789m 111p 22p
      g.drawn[d] = tileFromCode('1p');
      g.canZimo = true;

      // First win! Player scores immediately AND stays in game with locked hand!
      g.handle(d, {'type': 'hu'});
      expect(g.winCounts[d], 1);
      expect(g.locked[d], isTrue);
      expect(g.scores[d], greaterThan(0));
      expect(g.isOver, isFalse);
      expect(countTotal(g.hands[d]), 13); // 13-tile locked tenpai hand remains!

      // Next player discards '1p' -> player d (even though already won once) can Ron ('hu') AGAIN!
      final nextP = g.turn;
      g.hands[nextP] = h('1123456789m234p1p', kNumKinds); // no 's' tiles (queSuit)
      g.drawn[nextP] = tileFromCode('1p');
      final scoreAfterFirstWin = g.scores[d];
      g.handle(nextP, {'type': 'discard', 'tile': '1p'});
      expect(g.phase, 'claim');
      expect(g.waitingFor, contains(d));
      g.handle(d, {'type': 'hu'});
      for (final w in List.of(g.waitingFor)) {
        if (w != d && g.phase == 'claim') g.handle(w, {'type': 'pass'});
      }
      expect(g.winCounts[d], 2);
      expect(g.scores[d], greaterThan(scoreAfterFirstWin));
    });
  });

  group('青天井麻将 (aotenjou)', () {
    test('uncapped exponential scoring formula', () {
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'redDora': true},
        names: const ['A', 'B', 'C', 'D'],
        bots: const [false, false, false, false],
        rng: Random(7),
      );
      final g = AotenjouGame(setup)..start();
      expect(g.scores, [1000000, 1000000, 1000000, 1000000]);

      // 40 fu, 10 han -> basePoints = 40 * 2^12 = 163,840; non-dealer ron = ceil100(4 * 163840) = 655,400
      expect(aotenjouBasePoints(40, 10), 163840);
      expect(aotenjouRonPoints(40, 10, isDealer: false), 655400);
      expect(aotenjouRonPoints(40, 10, isDealer: true), 983100);

      // Evaluate a Chinitsu + Pinfu + Tanyao + Iipeikou hand
      final val = aotenjouEvaluate(
        h('22334456767888m'),
        const [],
        AotenjouCtx(
          winTile: tileFromCode('5m'),
          tsumo: false,
          riichi: true,
          dora: 2,
        ),
      )!;
      // 立直(1) + 平和(1) + 断幺九(1) + 一杯口(1) + 清一色(6) + 宝牌(2) = 12 han, 30 fu
      expect(val.fu, 30);
      expect(val.han, 12);
      expect(val.basePoints, 30 * (1 << 14)); // 491,520
    });
  });

  test('simulate all mahjong3 games (count: 30)', () {
    expect(runSims(mahjong3Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
