import 'dart:math';

import 'package:aurora_shared/games/mahjong5/defs.dart';
import 'package:aurora_shared/games/mahjong5/hangzhou.dart';
import 'package:aurora_shared/games/mahjong5/nanchang.dart';
import 'package:aurora_shared/games/mahjong5/tianjin.dart';
import 'package:aurora_shared/games/mahjong5/tiles.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

List<int> h(String s, [int kinds = kKinds]) => countsOf(parseTiles(s), kinds);

void main() {
  claimCoverEnabled = false;

  group('杭州麻将 (hangzhoumj)', () {
    test('白板财神 (5z), 爆头 (Baotou ×2), 财飘 (Caipiao ×4), and Ron rules', () {
      // 1. 爆头 (Baotou): 4 complete melds (123m 456p 789s 111z) + pair ('5z' + '9p') on self-draw -> ×2
      final baotouHand = h('123m456p789s111z5z9p');
      final btRes = hangzhouEvaluate(baotouHand, const [], selfDrawn: true)!;
      expect(btRes.isBaotou, isTrue);
      expect(btRes.mult, 2);
      expect(btRes.label, contains('爆头'));

      // Cannot Ron with Baotou / Caishen wildcard substitution
      expect(hangzhouEvaluate(baotouHand, const [], selfDrawn: false), isNull);

      // Plain hand without Caishen substitution CAN Ron when allowRon == true
      final plainHand = h('123m456p789s111z99p');
      expect(hangzhouEvaluate(plainHand, const [], selfDrawn: false), isNotNull);

      // 2. Live game flow: discarding '5z' sets caipiao[seat] = true, nobody can Ron it, next self-draw scores 财飘 (×4)!
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'allowRon': true},
        names: const ['A', 'B', 'C', 'D'],
        bots: const [false, false, false, false],
        rng: Random(17),
      );
      final g = HangzhouGame(setup)..start();
      expect(g.caishenTile, '5z');
      final s0 = g.turn;
      final s1 = (s0 + 1) % 4;

      // Give s1 a hand waiting on '5z' so we verify nobody can Ron when s0 discards '5z'
      g.hands[s1] = h('123m456p789s111z5z');
      // Give s0 a 14-tile hand with '5z' to discard for Caipiao, leaving tenpai 123m 456p 789s 234p 8s
      g.hands[s0] = h('123m456p789s234p8s5z');
      g.handle(s0, {'type': 'discard', 'tile': '5z'});
      expect(g.caipiao[s0], isTrue);
      // Nobody can claim '5z', so turn advances directly to s1
      expect(g.phase, 'act');
      expect(g.turn, s1);

      // Now on s0's next draw, s0 draws '8s' and wins by tsumo -> 财飘 (×4)!
      g.turn = s0;
      g.phase = 'act';
      g.hands[s0][tileFromCode('8s')]++;
      g.drawn[s0] = tileFromCode('8s');
      g.canZimo = true;
      g.handle(s0, {'type': 'tsumo'});
      expect(g.isOver, isTrue);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(huEv['caipiao'], isTrue);
      expect(huEv['mult'], 4);
      final itemNames = [for (final it in huEv['items'] as List) it[0]];
      expect(itemNames, contains('财飘'));
    });
  });

  group('南昌麻将 (nanchangmj)', () {
    test('上下翻精 (zhengJing & fuJing), 十三烂, 七星十三烂 (×4), and 德国 (Deguo)', () {
      // Verify cyclic next tile for number suits, winds, and dragons
      expect(nextCyclicTileCode('1m'), '2m');
      expect(nextCyclicTileCode('9p'), '1p');
      expect(nextCyclicTileCode('4z'), '1z');
      expect(nextCyclicTileCode('7z'), '5z');

      final zj = tileFromCode('1m');
      // 1. 七星十三烂 (14 distinct tiles, rank gap >= 3 in each suit: 147m 25p 36s + 1234567z)
      // Note: '1m' is present as its natural tile without wildcard substitution -> 德国 + 七星十三烂 (×4 * ×2 = ×8)!
      final qixingHand = h('147m25p36s1234567z');
      expect(isPureShisanlan(qixingHand), isTrue);
      final qxRes = nanchangEvaluate(qixingHand, const [], zhengJing: zj, selfDrawn: true)!;
      expect(qxRes.isShisanlan, isTrue);
      expect(qxRes.isQixing, isTrue);
      expect(qxRes.isDeguo, isTrue);
      expect(qxRes.label, contains('七星十三烂'));
      expect(qxRes.label, contains('德国'));

      // 2. Invalid 十三烂 (rank gap < 3: 1m and 3m have difference 2 < 3)
      final badSsl = h('137m258p36s123456z');
      expect(isPureShisanlan(badSsl), isFalse);
      expect(nanchangEvaluate(badSsl, const [], zhengJing: tileFromCode('9s'), selfDrawn: true), isNull);

      // 3. Wildcard substitution (non-Deguo): using zhengJing ('1m') as a wildcard for '3m' in 123m
      final wildHand = h('112m456p789s111z22p');
      final wildRes = nanchangEvaluate(wildHand, const [], zhengJing: zj, selfDrawn: true)!;
      expect(wildRes.isDeguo, isFalse);
    });

    test('霸王精 (sole Jing holder ×2) and 冲关 (>= 5 Jing points ×2) settlement', () {
      // Sole holder s0 has 2 zhengJing (4 pts) + 1 fuJing (1 pt) = 5 base pts -> 霸王精 (×2) AND 冲关 (×2) = 20 pts per opponent!
      final summary = nanchangJingSettle([2, 0, 0, 0], [1, 0, 0, 0]);
      expect(summary.basePoints[0], 5);
      expect(summary.bawangSeat, 0);
      expect(summary.chongguan[0], isTrue);
      expect(summary.effectivePoints[0], 20);
      expect(summary.deltas[0], 60);
      expect(summary.deltas[1], -20);

      // When 2 players hold Jing, no 霸王精
      final summary2 = nanchangJingSettle([1, 0, 0, 0], [0, 1, 0, 0]);
      expect(summary2.bawangSeat, -1);
      expect(summary2.effectivePoints[0], 2);
      expect(summary2.effectivePoints[1], 1);
    });
  });

  group('天津麻将 (tianjinmj)', () {
    test('只许自摸 (self-draw only), 没混儿 (×2), 混儿吊 (×2), 捉五魁 (×4), and 龙 (×4) / 本混儿龙 (×8)', () {
      final hunP = tileFromCode('3p');
      final hunM = tileFromCode('3m');

      // 1. Cannot win by Ron (selfDrawn: false returns null)
      expect(
        tianjinEvaluate(h('123m456p789s11122z'), const [], hunTile: hunP, selfDrawn: false),
        isNull,
      );

      // 2. 没混儿 (×2): winning with 0 wildcards in hand
      final noHunRes = tianjinEvaluate(
        h('123m456p789s11122z'),
        const [],
        hunTile: hunP,
        winTile: tileFromCode('1m'),
        selfDrawn: true,
      )!;
      expect(noHunRes.noHun, isTrue);
      expect(noHunRes.mult, 2);
      expect(noHunRes.label, contains('没混儿'));

      // 3. 混儿吊 (×2): 4 complete melds + pair of hunTile ('3p') + '9s'
      final hunDiaoRes = tianjinEvaluate(
        h('123m456s789s111z3p9s'),
        const [],
        hunTile: hunP,
        winTile: tileFromCode('9s'),
        selfDrawn: true,
      )!;
      expect(hunDiaoRes.hunDiao, isTrue);
      expect(hunDiaoRes.label, contains('混儿吊'));

      // 4. 捉五魁 (×4): catching '5m' in a 4m-5m-6m sequence
      final zhuoRes = tianjinEvaluate(
        h('456m123p789s11122z'),
        const [],
        hunTile: hunP,
        winTile: tileFromCode('5m'),
        selfDrawn: true,
      )!;
      expect(zhuoRes.zhuoWuKui, isTrue);
      expect(zhuoRes.label, contains('捉五魁'));

      // 5. 龙 (×4) in Man suit when hunTile is in Pin suit ('3p')
      final longRes = tianjinEvaluate(
        h('123456789m11122z'),
        const [],
        hunTile: hunP,
        winTile: tileFromCode('9m'),
        selfDrawn: true,
      )!;
      expect(longRes.isLong, isTrue);
      expect(longRes.benHunLong, isFalse);
      expect(longRes.label, contains('龙'));

      // 6. 本混儿龙 (×8) in Man suit when hunTile is also in Man suit ('3m')
      final benHunLongRes = tianjinEvaluate(
        h('123456789m11122z'),
        const [],
        hunTile: hunM,
        winTile: tileFromCode('9m'),
        selfDrawn: true,
      )!;
      expect(benHunLongRes.isLong, isTrue);
      expect(benHunLongRes.benHunLong, isTrue);
      expect(benHunLongRes.label, contains('本混儿龙'));
      expect(benHunLongRes.mult, greaterThanOrEqualTo(8));
    });

    test('TianjinGame rejects ron and allows tsumo win', () {
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1},
        names: const ['A', 'B', 'C', 'D'],
        bots: const [false, false, false, false],
        rng: Random(29),
      );
      final g = TianjinGame(setup)..start();
      g.setHunIndicator(tileFromCode('2p'));
      expect(g.hunTile, '3p');
      final s0 = g.turn;
      expect(() => g.handle(s0, {'type': 'ron'}), throwsA(isA<GameError>()));

      g.hands[s0] = h('456m123p789s11122z');
      g.drawn[s0] = tileFromCode('5m');
      g.canZimo = true;
      g.handle(s0, {'type': 'tsumo'});
      expect(g.isOver, isTrue);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(huEv['zhuoWuKui'], isTrue);
    });
  });

  test('simulate all mahjong5 games (count: 30)', () {
    expect(runSims(mahjong5Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
