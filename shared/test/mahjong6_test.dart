import 'dart:math';

import 'package:aurora_shared/games/mahjong6/defs.dart';
import 'package:aurora_shared/games/mahjong6/hefei.dart';
import 'package:aurora_shared/games/mahjong6/shaanxi.dart';
import 'package:aurora_shared/games/mahjong6/suzhou.dart';
import 'package:aurora_shared/games/mahjong6/tiles.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

List<int> h(String s, [int kinds = kKinds]) => countsOf(parseTiles(s), kinds);

void main() {
  claimCoverEnabled = false;

  group('陕西麻将 (shaanximj)', () {
    test('112张牌池、下炮子 (paozi 0..4) 双边加分、红中赖子 (7z) 与四红中 (sihongzhong)', () {
      // 1. 四红中直接胡牌 (even when remaining 10 tiles do not form sets)
      final siHzHand = h('7777z147m258p369s1m');
      final shzRes = shaanxiEvaluate(siHzHand, const [], selfDrawn: true)!;
      expect(shzRes.isSiHongZhong, isTrue);
      expect(shzRes.label, contains('四红中'));

      // 2. 红中 ('7z') 作为万能百搭赖子代替 '3m' 与 '6p'
      final wildHand = h('12m45p789s222s99p77z');
      final wildRes = shaanxiEvaluate(wildHand, const [], selfDrawn: true)!;
      expect(wildRes.noWild, isFalse);

      // 3. 完整流程测试：下炮子阶段 -> 四红中自摸 -> 验证 +(paozi[winner] + paozi[loser]) 结算
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'allowRon': true},
        names: const ['A', 'B', 'C', 'D'],
        bots: const [false, false, false, false],
        rng: Random(11),
      );
      final g = ShaanxiGame(setup)..start();
      expect(g.phase, 'paozi');
      expect(g.waitingFor, [0, 1, 2, 3]);

      // All 4 players select paozi: seat 0 -> 3, seat 1 -> 2, seat 2 -> 0, seat 3 -> 4
      final paoziChoices = [3, 2, 0, 4];
      for (var s = 0; s < 4; s++) {
        g.handle(s, {'type': 'paozi', 'count': paoziChoices[s]});
      }
      expect(g.phase, 'act');
      expect(g.paozi, paoziChoices);

      final w = g.turn;
      // Give current turn player 4 '7z' tiles to trigger {'type': 'sihongzhong'}
      g.hands[w] = h('7777z147m258p369s1m');
      g.drawn[w] = kChun;
      g.canZimo = true;
      g.handle(w, {'type': 'sihongzhong'});

      expect(g.isOver, isTrue);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(huEv['sihongzhong'], isTrue);
      final paoziPay = (huEv['paoziPay'] as Map).cast<String, int>();
      final pay = (huEv['pay'] as Map).cast<String, int>();
      for (var p = 0; p < 4; p++) {
        if (p == w) continue;
        expect(paoziPay['$p'], paoziChoices[w] + paoziChoices[p]);
        // Base is fan(6) * mult(2) * 2(zimo) = 24, plus paozi[w] + paozi[p]
        expect(pay['$p'], 24 + paoziChoices[w] + paoziChoices[p]);
      }
    });
  });

  group('合肥麻将 (hefeimj)', () {
    test('84张断幺牌池 (2..8 m/p/s)、缺一门 + 够八支硬性条件、十同 / 双八支 / 清一色 / 七对', () {
      expect(kHefeiTileKinds.length, 21);

      // 1. 含幺九 (1m) 或含三门花色 -> 不允许胡牌 (null)
      expect(hefeiEvaluate(h('12345678m23455p'), const []), isNull);
      // 三门花色且主花色够 8 张 (8张万 + 3张筒 + 3张条) -> 违反【缺一门】，返回 null
      expect(hefeiEvaluate(h('23456788m234p234s'), const []), isNull);
      // 主花色不足 8 张 (6张万 + 6张筒 + 2张条，最高仅 6 支) -> 违反【够八支】与【缺一门】，返回 null
      expect(hefeiEvaluate(h('234567m234567p22s'), const []), isNull);

      // 2. 满足缺一门 (万+筒) 且万有 8 张 (够八支) -> 合法胡牌
      final bazhiRes = hefeiEvaluate(h('23456788m234666p'), const [])!;
      expect(bazhiRes.isQueYiMen, isTrue);
      expect(bazhiRes.isBaZhi, isTrue);
      expect(bazhiRes.mainSuitCount, 8);
      expect(bazhiRes.label, contains('够八支'));

      // 3. 十同 (主花色 >= 10 张：11 张万 + 3 张筒)
      final shitongRes = hefeiEvaluate(h('22234567888m234p'), const [], selfDrawn: true)!;
      expect(shitongRes.isShiTong, isTrue);
      expect(shitongRes.mainSuitCount, 11);
      expect(shitongRes.label, contains('十同'));

      // 4. 双八支 (带两个杠牌使万达到 4+4=8 张，筒 3+3+2=8 张，两门同时达到 8 支)
      final shuangBaZhiRes = hefeiEvaluate(
        h('23456788p'),
        [Meld('agang', tileFromCode('2m')), Meld('agang', tileFromCode('3m'))],
        selfDrawn: true,
      )!;
      expect(shuangBaZhiRes.isShuangBaZhi, isTrue);
      expect(shuangBaZhiRes.suitCounts[0], 8);
      expect(shuangBaZhiRes.suitCounts[1], 8);
      expect(shuangBaZhiRes.label, contains('双八支'));

      // 5. 清一色 (14 张同花色) + 七对
      final qysQiduiRes = hefeiEvaluate(h('22334455667788m'), const [], selfDrawn: true)!;
      expect(qysQiduiRes.isQingYiSe, isTrue);
      expect(qysQiduiRes.isQiDui, isTrue);
      expect(qysQiduiRes.label, contains('清一色'));
      expect(qysQiduiRes.label, contains('七对'));
    });
  });

  group('苏州麻将 (suzhoumj)', () {
    test('翻百搭 (baidaTile)、中发白拔花 (bahua)、滴麻子硬花门槛与大吊车', () {
      final baida = tileFromCode('2m');

      // 1. 滴麻子平胡：副露开门后若硬花 < 2 (huaCount == 1)，不允许胡平胡！
      final openPlain = h('234p567s234s22p');
      final onePeng = [Meld('peng', tileFromCode('8p'), claimed: tileFromCode('8p'), from: 1)];
      expect(suzhouEvaluate(openPlain, onePeng, baidaTile: baida, huaCount: 1), isNull);

      // 当硬花 >= 2 (huaCount == 2) 时，副露平胡可以胡牌（滴麻子）
      final dimaziRes = suzhouEvaluate(openPlain, onePeng, baidaTile: baida, huaCount: 2)!;
      expect(dimaziRes.isDiMaZi, isTrue);
      expect(dimaziRes.huaCount, 2);
      expect(dimaziRes.label, contains('滴麻子'));

      // 门清平胡即使 0 花也可以胡牌
      final closedPlain = h('123m234p567s234s22p');
      final mqRes = suzhouEvaluate(closedPlain, const [], baidaTile: baida, huaCount: 0)!;
      expect(mqRes.isMenqing, isTrue);

      // 2. 大吊车 (4 组副露后单钓将牌，即使 0 花也是大胡并翻倍)
      final fourMelds = [
        Meld('peng', tileFromCode('3m'), claimed: tileFromCode('3m'), from: 1),
        Meld('peng', tileFromCode('4p'), claimed: tileFromCode('4p'), from: 2),
        Meld('peng', tileFromCode('5s'), claimed: tileFromCode('5s'), from: 3),
        Meld('peng', tileFromCode('1z'), claimed: tileFromCode('1z'), from: 1),
      ];
      final ddcRes = suzhouEvaluate(h('9p2m'), fourMelds, baidaTile: baida, huaCount: 0, selfDrawn: true)!;
      expect(ddcRes.isDaDiaoChe, isTrue);
      expect(ddcRes.isDuiDuiHu, isTrue);
      expect(ddcRes.label, contains('大吊车'));

      // 3. 拔花 (bahua) 实时流程：打出 '5z'/'6z'/'7z' 拔花进入 flowers[seat]、huaCount++ 并补摸一张牌
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1},
        names: const ['A', 'B', 'C', 'D'],
        bots: const [false, false, false, false],
        rng: Random(19),
      );
      final g = SuzhouGame(setup)..start();
      g.setBaidaIndicator(tileFromCode('1m'));
      expect(g.baidaTile, '2m');
      final s0 = g.turn;
      g.hands[s0] = h('123m456p789s111z2p5z');
      final wallBefore = g.wall.length;
      g.handle(s0, {'type': 'bahua', 'tile': '5z'});
      expect(g.flowers[s0], contains('5z'));
      expect(g.huaCount[s0], 1);
      expect(g.wall.length, wallBefore - 1);
      expect(countTotal(g.hands[s0]), 14);
    });
  });

  test('simulate all mahjong6 games (count: 30)', () {
    expect(runSims(mahjong6Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
