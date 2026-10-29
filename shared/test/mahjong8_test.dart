import 'dart:math';

import 'package:aurora_shared/games/mahjong8/defs.dart';
import 'package:aurora_shared/games/mahjong8/guangxi.dart';
import 'package:aurora_shared/games/mahjong8/henan.dart';
import 'package:aurora_shared/games/mahjong8/ningbo.dart';
import 'package:aurora_shared/games/mahjong8/tiles.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

List<int> h(String s, [int kinds = kKinds]) => countsOf(parseTiles(s), kinds);

void main() {
  claimCoverEnabled = false;

  group('河南麻将 (henanmj)', () {
    test('选跑分阶段 (paofen 0..3)、翻混儿百搭 (hunTile)、四混儿 (sihun) 与杠/胡跑分结算', () {
      // 1. 翻混儿循环顺位与百搭代牌
      expect(nextCyclicTileCode('1m'), '2m');
      expect(nextCyclicTileCode('9p'), '1p');
      expect(nextCyclicTileCode('4z'), '1z');
      expect(nextCyclicTileCode('7z'), '5z');

      final hun = tileFromCode('2m');
      // 2m 作为混儿百搭代替 3p 与 6s
      final wildHand = h('12p45s789m111z99p22m');
      final wildRes = henanEvaluate(wildHand, const [], hunTile: hun, selfDrawn: true)!;
      expect(wildRes.noWild, isFalse);

      // 2. 四混儿直接自摸胡牌 (即使其余 10 张完全不搭)
      final siHunHand = h('2222m147p258s1357z');
      final shRes = henanEvaluate(siHunHand, const [], hunTile: hun, selfDrawn: true)!;
      expect(shRes.isSiHun, isTrue);
      expect(shRes.label, contains('四混儿'));

      // 3. 完整流程：Step 1 选跑分 (0..3) -> 暗杠跑分加分 -> 四混儿自摸胡牌跑分加分
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'allowRon': true},
        names: const ['A', 'B', 'C', 'D'],
        bots: const [false, false, false, false],
        rng: Random(13),
      );
      final g = HenanGame(setup)..start();
      g.setHunIndicator('1m');
      expect(g.hunTile, '2m');
      expect(g.phase, 'paofen');
      expect(g.waitingFor, [0, 1, 2, 3]);

      // 4 名玩家选择跑分：0号选 3分，1号选 1分，2号选 0分，3号选 2分
      final pfChoices = [3, 1, 0, 2];
      for (var s = 0; s < 4; s++) {
        g.handle(s, {'type': 'paofen', 'score': pfChoices[s]});
      }
      expect(g.phase, 'act');
      expect(g.paofen, pfChoices);

      // 庄家 (seat 0) 先暗杠 9p：每位输家 p 赔付 2(暗杠底) + paofen[0] + paofen[p]
      final w = g.turn;
      expect(w, 0);
      g.hands[w] = h('9999p2222m147s135z');
      g.handle(w, {'type': 'gang', 'tile': '9p'});
      final gangEvents = g.events.where((e) => e['kind'] == 'gang').toList();
      expect(gangEvents.length, 3);
      for (var p = 1; p < 4; p++) {
        final ev = gangEvents.firstWhere((e) => e['from'] == p);
        expect(ev['amount'], 2 + pfChoices[w] + pfChoices[p]);
      }

      // 补摸后手握 4 张混儿 ('2m')，直接发动 {'type': 'sihun'} 胡牌
      g.hands[w][tileFromCode('2m')] = 4;
      g.canZimo = true;
      g.handle(w, {'type': 'sihun'});
      expect(g.isOver, isTrue);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(huEv['sihun'], isTrue);
      final pfPay = (huEv['paofenPay'] as Map).cast<String, int>();
      for (var p = 1; p < 4; p++) {
        expect(pfPay['$p'], pfChoices[w] + pfChoices[p]);
      }
    });
  });

  group('广西买马麻将 (guangximj)', () {
    test('三口承包 / 封胡 (feedCount >= 3 双向自摸全包×3) 与买马 (horseTiles 中马加番)', () {
      // 1. 买马方位映射检验：
      // 东(0): 1,5,9,1z,5z; 南(1): 2,6,2z,6z; 西(2): 3,7,3z,7z; 北(3): 4,8,4z
      expect(countMatchedHorses(['1m', '5p', '9s', '1z', '5z', '2m'], 0), 5);
      expect(countMatchedHorses(['2m', '6p', '2z', '6z', '1m'], 1), 4);
      expect(countMatchedHorses(['3m', '7s', '3z', '7z', '4z'], 2), 4);
      expect(countMatchedHorses(['4p', '8s', '4z', '5z'], 3), 3);

      // 2. 中马翻倍/加番计算：每中 1 匹马增加 +1 × baseFan
      final baseHand = h('123m456p789s234m55p');
      final gxRes = guangxiEvaluate(
        baseHand,
        const [],
        horseTiles: const ['1m', '5p', '2s', '9m'],
        winnerWind: 0, // 东位中 1m, 5p, 9m 共 3 匹马
        selfDrawn: true,
      )!;
      expect(gxRes.matchedHorses, 3);
      expect(gxRes.fan, gxRes.baseFan * (1 + 3));

      // 3. 三口承包 (feedCount[seat][from] >= 3)：正向承包（吃碰者自摸，喂牌者全包×3）
      final setup1 = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'horseCount': 4},
        names: const ['东', '南', '西', '北'],
        bots: const [false, false, false, false],
        rng: Random(21),
      );
      final g1 = GuangxiGame(setup1)..start();
      // 模拟 seat 1 已经吃/碰/杠 seat 0 满 3 口
      g1.feedCount[1][0] = 3;
      g1.melds[1] = [
        Meld('peng', tileFromCode('1m'), claimed: tileFromCode('1m'), from: 0),
        Meld('peng', tileFromCode('2p'), claimed: tileFromCode('2p'), from: 0),
        Meld('chi', tileFromCode('3s'), claimed: tileFromCode('3s'), from: 0),
      ];
      expect(g1.isChengbaoPair(1, 0), isTrue);
      g1.turn = 1;
      g1.phase = 'act';
      g1.canZimo = true;
      g1.hands[1] = h('789m55p');
      g1.drawn[1] = tileFromCode('9m');
      g1.horseTiles = ['2m', '6p', '1m', '3s']; // 南位(1) 中 2m, 6p 共 2 匹马
      g1.handle(1, {'type': 'tsumo'});

      expect(g1.isOver, isTrue);
      final hu1 = (g1.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(hu1['chengbao'], isTrue);
      expect(hu1['matchedHorses'], 2);
      final pay1 = (hu1['pay'] as Map).cast<String, int>();
      // 仅喂牌者 seat 0 一人全包 3 家份额，seat 2 与 seat 3 免赔 (0)
      expect(pay1.keys.toList(), ['0']);
      expect(g1.scores[0], -pay1['0']!);
      expect(g1.scores[1], pay1['0']!);
      expect(g1.scores[2], 0);
      expect(g1.scores[3], 0);

      // 4. 三口承包反向承包（喂牌者 from 自摸，吃碰满三口者 seat 全包×3）
      final g2 = GuangxiGame(setup1)..start();
      g2.feedCount[2][0] = 3; // seat 2 吃了 seat 0 三口，现在 seat 0 自摸 -> seat 2 全包！
      g2.turn = 0;
      g2.phase = 'act';
      g2.canZimo = true;
      g2.hands[0] = h('123m456p789s234m55p');
      g2.drawn[0] = tileFromCode('5p');
      g2.horseTiles = ['1m', '5z', '2p', '3s']; // 东位(0) 中 1m, 5z 共 2 匹马
      g2.handle(0, {'type': 'tsumo'});
      final hu2 = (g2.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(hu2['chengbao'], isTrue);
      final pay2 = (hu2['pay'] as Map).cast<String, int>();
      expect(pay2.keys.toList(), ['2']);
      expect(g2.scores[2], -pay2['2']!);
      expect(g2.scores[1], 0);
      expect(g2.scores[3], 0);
    });
  });

  group('宁波麻将 (ningbomj)', () {
    test('百搭 (baidaTile)、台数计算 (中发白/风刻/无百搭/门清自摸/对对胡/混一色/清一色/七对/大吊车) 与 minTai 起胡门槛', () {
      final bd = tileFromCode('9s');

      // 1. 普通小平胡：无百搭(+1) + 门清/自摸(+1) = 2 台
      // 在 3 台标准门槛下不足 3 台，返回 null；在 2 台快速门槛下可胡牌！
      final plainHand = h('123m456p234s567m22p');
      expect(ningboEvaluate(plainHand, const [], baidaTile: bd, minTai: 3, selfDrawn: true), isNull);
      final fast2Res = ningboEvaluate(plainHand, const [], baidaTile: bd, minTai: 2, selfDrawn: true)!;
      expect(fast2Res.taiCount, 2);
      expect(fast2Res.noBaida, isTrue);

      // 2. 加上一组箭刻 (777z 红中 +1台) + 无百搭 (+1台) + 门清自摸 (+1台) = 3 台 >= 3 台！
      final dragonHand = h('123m456p234s777z22p');
      final dRes = ningboEvaluate(dragonHand, const [], baidaTile: bd, minTai: 3, selfDrawn: true)!;
      expect(dRes.dragonTriplets, 1);
      expect(dRes.taiCount, 3);
      expect(dRes.label, contains('中刻'));

      // 3. 风刻 (111z 东风 +1台) + 对对胡 (+2台) + 无百搭 (+1台) = 4 台 (开门点炮也可胡)
      final openPeng = [Meld('peng', tileFromCode('1z'), claimed: tileFromCode('1z'), from: 1)];
      final ddhRes = ningboEvaluate(h('222m555p888s33p'), openPeng, baidaTile: bd, minTai: 3, selfDrawn: false)!;
      expect(ddhRes.isDuiDuiHu, isTrue);
      expect(ddhRes.windTriplets, 1);
      expect(ddhRes.taiCount, 4);

      // 4. 混一色 (+2台)、清一色 (+4台)、七对 (+3台)、大吊车 (4副露单钓 +2台)
      final qysRes = ningboEvaluate(h('123456789m23455m'), const [], baidaTile: bd, minTai: 3)!;
      expect(qysRes.isQingYiSe, isTrue);
      expect(qysRes.taiCount, greaterThanOrEqualTo(4));

      // 带 1 张百搭 (9s) 的七对：七对 (+3台) + 门清 (+1台) = 4 台
      final qdWildRes = ningboEvaluate(h('112233m445566p1z9s'), const [], baidaTile: bd, minTai: 3)!;
      expect(qdWildRes.isQiDui, isTrue);
      expect(qdWildRes.noBaida, isFalse);
      expect(qdWildRes.taiCount, 4);

      // 大吊车 (4 组副露 + 单钓将牌)：大吊车 (+2台) + 对对胡 (+2台) + 无百搭 (+1台) = 5 台
      final fourMelds = [
        Meld('peng', tileFromCode('2m'), claimed: tileFromCode('2m'), from: 1),
        Meld('peng', tileFromCode('4p'), claimed: tileFromCode('4p'), from: 2),
        Meld('peng', tileFromCode('6s'), claimed: tileFromCode('6s'), from: 3),
        Meld('peng', tileFromCode('8m'), claimed: tileFromCode('8m'), from: 1),
      ];
      final ddcRes = ningboEvaluate(h('55p'), fourMelds, baidaTile: bd, minTai: 3)!;
      expect(ddcRes.isDaDiaoChe, isTrue);
      expect(ddcRes.taiCount, 5);
    });
  });

  test('simulate all mahjong8 games (count: 30)', () {
    expect(runSims(mahjong8Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
