import 'dart:math';

import 'package:aurora_shared/games/mahjong4/defs.dart';
import 'package:aurora_shared/games/mahjong4/fujian.dart';
import 'package:aurora_shared/games/mahjong4/guizhou.dart';
import 'package:aurora_shared/games/mahjong4/harbin.dart';
import 'package:aurora_shared/games/mahjong4/tiles.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

List<int> h(String s, [int kinds = kKinds]) => countsOf(parseTiles(s), kinds);

void main() {
  claimCoverEnabled = false;

  group('贵阳捉鸡麻将 (guizhoumj)', () {
    test('通行证规则 (Pass Rule): Ron requires bean or big hand, Tsumo always wins', () {
      // Small平胡 hand: 123m 456p 789s 234p 55s
      final smallHand = h('123m456p789s234p55s', kNumKinds);
      // Cannot Ron without a Bean
      expect(guizhouEvaluate(smallHand, const [], beans: 0, selfDrawn: false), isNull);
      // Can Ron WITH a Bean
      expect(guizhouEvaluate(smallHand, const [], beans: 1, selfDrawn: false), isNotNull);
      // Can always Tsumo even without a Bean
      expect(guizhouEvaluate(smallHand, const [], beans: 0, selfDrawn: true), isNotNull);

      // Big hands (大对子, 七对, 清一色, 单钓) can Ron even with beans == 0
      final daduizi = guizhouEvaluate(h('111m333p555s777m99p', kNumKinds), const [], beans: 0, selfDrawn: false)!;
      expect(daduizi.isBig, isTrue);
      expect(daduizi.label, contains('大对子'));

      final qidui = guizhouEvaluate(h('1122m3344p5566s77m', kNumKinds), const [], beans: 0, selfDrawn: false)!;
      expect(qidui.isBig, isTrue);
      expect(qidui.label, contains('七对'));

      final qingyise = guizhouEvaluate(h('12345678911222m', kNumKinds), const [], beans: 0, selfDrawn: false)!;
      expect(qingyise.isBig, isTrue);
      expect(qingyise.label, contains('清一色'));

      final dandiao = guizhouEvaluate(
        h('55m', kNumKinds),
        [Meld('peng', 0), Meld('peng', 9), Meld('peng', 18), Meld('peng', 1)],
        beans: 0,
        selfDrawn: false,
      )!;
      expect(dandiao.isBig, isTrue);
      expect(dandiao.label, contains('单钓'));
    });

    test('通行豆 (闷豆 / 转弯豆 / 点豆), 冲锋鸡, 责任鸡, and 翻鸡 (Golden Chicken)', () {
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'goldenChicken': true},
        names: const ['A', 'B', 'C', 'D'],
        bots: const [false, false, false, false],
        rng: Random(19),
      );
      final g = GuizhouGame(setup)..start();
      final s0 = g.turn;
      final s1 = (s0 + 1) % 4;

      // 1. 闷豆 (AnGang): +2 pts from all 3 opponents (+6 to s0)
      g.hands[s0] = h('1111m234m456p789s1s', kNumKinds);
      g.handle(s0, {'type': 'gang', 'tile': '1m'});
      expect(g.beans[s0], 1);
      expect(g.scores[s0], 6);
      expect(g.scores[s1], -2);

      // 2. 冲锋鸡 & 责任鸡: s0 discards the very first '1s', s1 claims it for Peng -> 责任鸡 (+2 from s0 to s1)!
      g.hands[s0][kYaoji] = 1;
      g.hands[s1] = h('11s234m567p789s22p', kNumKinds);
      final scoreS0Before = g.scores[s0];
      final scoreS1Before = g.scores[s1];
      g.handle(s0, {'type': 'discard', 'tile': '1s'});
      expect(g.firstYaojiSeen, isTrue);
      expect(g.phase, 'claim');
      g.handle(s1, {'type': 'peng'});
      for (final w in List.of(g.waitingFor)) {
        if (w != s1 && g.phase == 'claim') g.handle(w, {'type': 'pass'});
      }
      expect(g.zerenFrom, s0);
      expect(g.zerenTo, s1);
      expect(g.chongfengSeat, -1);
      expect(g.scores[s0], scoreS0Before - 2);
      expect(g.scores[s1], scoreS1Before + 2);

      // 3. 翻鸡 (Golden Chicken when chickenIndicator is '9s' -> luckyChicken is '1s')
      expect(guizhouChickenFromCode('9s'), '1s');
      expect(guizhouChickenFromCode('1m'), '2m');
      g.wall.add(tileFromCode('9s')); // Will be flipped on win -> luckyChicken == '1s' (Golden Chicken!)
      final turnNow = g.turn;
      g.hands[turnNow] = h('234m567p789s22p', kNumKinds);
      g.drawn[turnNow] = tileFromCode('2p');
      g.canZimo = true;
      g.handle(turnNow, {'type': 'hu'});
      expect(g.chickenIndicator, '9s');
      expect(g.luckyChicken, '1s');
      expect(g.isGoldenChicken, isTrue);
      expect(g.isOver, isTrue);
    });
  });

  group('哈尔滨麻将 (harbinmj)', () {
    test('开门, 报听 (ting), secret baoTile visibility, 摸宝 / 红中满天飞, and 刮大风', () {
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'hongzhongFly': true},
        names: const ['A', 'B', 'C', 'D'],
        bots: const [false, false, false, false],
        rng: Random(23),
      );
      final g = HarbinGame(setup)..start();
      final s0 = g.turn;
      final s1 = (s0 + 1) % 4;

      // Before Ting, baoTile is hidden (null) in view(s0) and view(s1)
      expect(g.view(s0)['baoTile'], isNull);
      expect(g.view(s1)['baoTile'], isNull);

      // Give s0 a 14-tile hand that is 1 tile away from winning: 111m 456p 789s 234p 5s 9m
      // Discarding '9m' leaves tenpai waiting on '5s' (and triplets 111m for 刮大风!)
      g.hands[s0] = h('111m456p789s234p5s9m');
      g.handle(s0, {'type': 'ting', 'tile': '9m'});
      for (final w in List.of(g.waitingFor)) {
        if (g.phase == 'claim') g.handle(w, {'type': 'pass'});
      }

      expect(g.ting[s0], isTrue);
      expect(g.kaimen[s0], isTrue);
      // Now baoTile is visible to s0, but STILL hidden from s1!
      expect(g.view(s0)['baoTile'], g.baoTile);
      expect(g.view(s1)['baoTile'], isNull);

      // Test 刮大风: when Ting player s0 draws the 4th '1m' matching their triplet '111m'
      g.turn = s0;
      g.phase = 'act';
      g.wall.add(tileFromCode('1m'));
      final scoreBeforeWind = g.scores[s0];
      // Simulate drawing '1m' by having player s3 discard a non-claimable tile or calling gang
      g.hands[s0][tileFromCode('1m')]++;
      g.drawn[s0] = tileFromCode('1m');
      g.canZimo = true;
      expect(g.isGuaDaFengDraw(s0), isTrue);
      g.handle(s0, {'type': 'gang', 'tile': '1m'});
      expect(g.guaDaFeng[s0], isTrue);
      expect(g.scores[s0], greaterThan(scoreBeforeWind));

      // Test 摸宝 / 红中满天飞: Ting player s0 draws '7z' (红中) and wins via 'mobao'
      g.hands[s0][kChun]++;
      g.drawn[s0] = kChun;
      g.canZimo = true;
      expect(g.canMoBao(s0), isTrue);
      g.handle(s0, {'type': 'mobao'});
      expect(g.isOver, isTrue);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      final itemNames = [for (final it in huEv['items'] as List) it[0]];
      expect(itemNames, contains('红中满天飞'));
    });
  });

  group('福建游金麻将 (fujianmj)', () {
    test('三金倒 (sanjindao) immediate win with 3 Gold tiles regardless of remaining tiles', () {
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1},
        names: const ['A', 'B', 'C', 'D'],
        bots: const [false, false, false, false],
        rng: Random(31),
      );
      final g = FujianGame(setup)..start();
      g.goldTileId = tileFromCode('5m');
      final s0 = g.turn;
      // Scattered unformed hand with 3 Gold tiles ('5m')
      g.hands[s0] = h('555m147p258s12345z');
      g.canZimo = true;
      expect(g.canSanJinDao(s0), isTrue);
      g.handle(s0, {'type': 'sanjindao'});
      expect(g.isOver, isTrue);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      final itemNames = [for (final it in huEv['items'] as List) it[0]];
      expect(itemNames, contains('三金倒'));
    });

    test('游金 -> 双游 -> 三游 progression and 34-tile universal wait', () {
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1},
        names: const ['A', 'B', 'C', 'D'],
        bots: const [false, false, false, false],
        rng: Random(37),
      );
      final g = FujianGame(setup)..start();
      g.goldTileId = tileFromCode('5m');
      final s0 = g.turn;

      // 4 complete melds (123m 456p 789s 111z) + pair (gold '5m' + '9p')
      g.hands[s0] = h('123m456p789s111z5m9p');
      expect(g.swimTiles(s0), contains(tileFromCode('9p')));

      // 1. Declare 游金 (单游, swimState == 1) by discarding '9p'
      g.handle(s0, {'type': 'swim', 'tile': '9p'});
      expect(g.swimState[s0], 1);
      // Lone goldTile waits on ALL 34 tiles!
      expect(fujianWaits(g.hands[s0], g.melds[s0], goldTile: g.goldTileId, swimState: g.swimState[s0]).length, 34);

      // 2. Next turn for s0: draw a tile ('2z') and advance to 双游 (swimState == 2)
      g.turn = s0;
      g.phase = 'act';
      g.hands[s0][tileFromCode('2z')]++;
      g.drawn[s0] = tileFromCode('2z');
      g.canZimo = true;
      g.handle(s0, {'type': 'swim', 'tile': '2z'});
      expect(g.swimState[s0], 2);

      // 3. Next turn for s0: draw a tile ('3z') and advance to 三游 (swimState == 3)
      g.turn = s0;
      g.phase = 'act';
      g.hands[s0][tileFromCode('3z')]++;
      g.drawn[s0] = tileFromCode('3z');
      g.canZimo = true;
      g.handle(s0, {'type': 'swim', 'tile': '3z'});
      expect(g.swimState[s0], 3);

      // 4. Next turn for s0: self-draw ANY tile ('7z') and win as 三游 (×8)!
      g.turn = s0;
      g.phase = 'act';
      g.hands[s0][tileFromCode('7z')]++;
      g.drawn[s0] = tileFromCode('7z');
      g.canZimo = true;
      g.handle(s0, {'type': 'hu'});
      expect(g.isOver, isTrue);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(huEv['mult'], 8);
      final itemNames = [for (final it in huEv['items'] as List) it[0]];
      expect(itemNames, contains('三游'));
    });
  });

  test('simulate all mahjong4 games (count: 30)', () {
    expect(runSims(mahjong4Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
