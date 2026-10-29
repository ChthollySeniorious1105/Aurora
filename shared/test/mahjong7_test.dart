import 'dart:math';

import 'package:aurora_shared/games/mahjong7/defs.dart';
import 'package:aurora_shared/games/mahjong7/shandong.dart';
import 'package:aurora_shared/games/mahjong7/shanxi.dart';
import 'package:aurora_shared/games/mahjong7/tiles.dart';
import 'package:aurora_shared/games/mahjong7/yunnan.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

List<int> h(String s, [int kinds = kKinds]) => countsOf(parseTiles(s), kinds);

void main() {
  claimCoverEnabled = false;

  group('山东麻将 (shandongmj)', () {
    test('二五八将硬性要求、大胡免258将、明楼 (minglou ×2) 与手把一 (×2)', () {
      // 1. 普通平胡若将牌不是 2/5/8 (例如 99p 作将)，不允许胡牌 (null)
      expect(shandongEvaluate(h('123m456p789s234s99p'), const []), isNull);

      // 普通平胡将牌为 2m / 5p / 8s 时合法胡牌
      final std258 = shandongEvaluate(h('123m456p789s234s55p'), const [])!;
      expect(std258.is258Pair, isTrue);
      expect(std258.label, contains('二五八将'));

      // 2. 大胡免二五八将：七对、碰碰胡、混一色、清一色、将一色、手把一
      final qiduiRes = shandongEvaluate(h('113344m667799p11z'), const [])!;
      expect(qiduiRes.isQiDui, isTrue);
      expect(qiduiRes.mult, 2);

      final pengpengRes = shandongEvaluate(h('111m333p777s111z99m'), const [])!;
      expect(pengpengRes.isPengPeng, isTrue);
      expect(pengpengRes.mult, 2);

      final hunyiseRes = shandongEvaluate(h('123456789m111z99m'), const [])!;
      expect(hunyiseRes.isHunYiSe, isTrue);
      expect(hunyiseRes.mult, 2);

      final qingyiseRes = shandongEvaluate(h('1112345678999m1m'), const [])!;
      expect(qingyiseRes.isQingYiSe, isTrue);
      expect(qingyiseRes.mult, 4);

      final jiangyiseRes = shandongEvaluate(h('222555888m222p88s'), const [])!;
      expect(jiangyiseRes.isJiangYiSe, isTrue);

      // 3. 手把一 (4 组副露 + 单钓 1 对非258将牌，×2)
      final fourMelds = [
        Meld('peng', tileFromCode('1m'), claimed: tileFromCode('1m'), from: 1),
        Meld('peng', tileFromCode('3p'), claimed: tileFromCode('3p'), from: 2),
        Meld('chi', tileFromCode('4s'), claimed: tileFromCode('4s'), from: 3),
        Meld('peng', tileFromCode('1z'), claimed: tileFromCode('1z'), from: 1),
      ];
      final sbyRes = shandongEvaluate(h('99p'), fourMelds, selfDrawn: true)!;
      expect(sbyRes.isShouBaYi, isTrue);
      expect(sbyRes.mult, 2);
      expect(sbyRes.label, contains('手把一'));

      // 4. 明楼 ({'type': 'minglou', 'tile': d}) 流程：锁定手牌且赢/输均 ×2 翻倍
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'allowRon': true},
        names: const ['A', 'B', 'C', 'D'],
        bots: const [false, false, false, false],
        rng: Random(17),
      );
      final g = ShandongGame(setup)..start();
      final s0 = g.turn;
      // 13张听牌 + 1张废牌 9z: 123m 456p 789s 234m 55p + 7z
      g.hands[s0] = h('123456m456p789s5p7z');
      g.drawn[s0] = tileFromCode('7z');
      expect(g.minglouTiles(s0), contains(tileFromCode('7z')));

      g.handle(s0, {'type': 'minglou', 'tile': '7z'});
      expect(g.minglou[s0], isTrue);

      // 下家打出 5p 点炮给已明楼的 s0
      final s1 = g.turn;
      g.hands[s1][tileFromCode('5p')] = 1;
      g.handle(s1, {'type': 'discard', 'tile': '5p'});
      expect(g.phase, 'claim');
      g.handle(s0, {'type': 'ron'});
      expect(g.isOver, isTrue);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(huEv['minglou'], isTrue);
      expect(huEv['mult'], greaterThanOrEqualTo(2));
    });
  });

  group('山西抠点麻将 (shanximj)', () {
    test('tilePoint 点数、点炮>=6点门槛、自摸>=3点门槛、1/2点大胡计10点、报听与耗子百搭', () {
      // 1. tilePoint 点数规则：1..9 数牌为 1..9 点，字牌 1z..7z 为 10 点
      expect(tilePoint('1m'), 1);
      expect(tilePoint('5p'), 5);
      expect(tilePoint('9s'), 9);
      for (var z = 1; z <= 7; z++) {
        expect(tilePoint('${z}z'), 10);
      }

      // 2. 点炮 (selfDrawn: false) 门槛：点数 < 6 (如 5m) 不可胡，>= 6 (如 6m、1z) 可胡
      final hand5m = h('123p456s789s22z345m');
      expect(shanxiEvaluate(hand5m, const [], winTile: '5m', selfDrawn: false), isNull);
      final hand6m = h('123p456s789s22z456m');
      final ron6 = shanxiEvaluate(hand6m, const [], winTile: '6m', selfDrawn: false)!;
      expect(ron6.basePoints, 6);
      expect(ron6.score, 6);

      // 3. 自摸 (selfDrawn: true) 门槛：普通牌型 1、2 点不可自摸，>= 3 点可自摸
      final plain2m = h('123p456s789s22z123m');
      expect(shanxiEvaluate(plain2m, const [], winTile: '2m', selfDrawn: true), isNull);
      final plain3m = shanxiEvaluate(plain2m, const [], winTile: '3m', selfDrawn: true)!;
      expect(plain3m.basePoints, 3);
      expect(plain3m.score, 6); // 3 * 2 (zimo)

      // 4. 1点或2点自摸大胡（清一色 / 一条龙 / 七对）允许胡牌且按 10 点底分计算，再乘大胡倍率 ×2 与自摸 ×2
      final ytlHand = h('123456789m234p55p');
      final ytl1m = shanxiEvaluate(ytlHand, const [], winTile: '1m', selfDrawn: true)!;
      expect(ytl1m.isYiTiaoLong, isTrue);
      expect(ytl1m.basePoints, 10);
      expect(ytl1m.mult, 2);
      expect(ytl1m.score, 40); // 10 * 2(一条龙) * 2(自摸)

      final qysHand = h('11223344556677m');
      final qysQidui2m = shanxiEvaluate(qysHand, const [], winTile: '2m', selfDrawn: true)!;
      expect(qysQidui2m.isQingYiSe, isTrue);
      expect(qysQidui2m.isQiDui, isTrue);
      expect(qysQidui2m.basePoints, 10);
      expect(qysQidui2m.mult, 4); // 清一色×2 * 七对×2

      // 5. 报听 ({'type': 'ting', 'tile': d}) 流程测试
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'useHaozi': false},
        names: const ['A', 'B', 'C', 'D'],
        bots: const [false, false, false, false],
        rng: Random(23),
      );
      final g = ShanxiGame(setup)..start();
      final s0 = g.turn;
      g.hands[s0] = h('123p456s789s11z78m2m');
      g.drawn[s0] = tileFromCode('2m');
      g.handle(s0, {'type': 'ting', 'tile': '2m'});
      expect(g.ting[s0], isTrue);
    });
  });

  group('云南十风麻将 (yunnanmj)', () {
    test('幺鸡 (1s) 任用百搭、连续字牌十风胡 (shifeng ×4)、杠上花 (×3) 与五梅花 (5p/1s ×5)', () {
      // 1. 幺鸡 ('1s') 作为万能百搭代牌
      final wildHand = h('12m45p789s222p99m11s');
      final wildRes = yunnanEvaluate(wildHand, const [], winTile: '2p', selfDrawn: true)!;
      expect(wildRes.noWild, isFalse);

      // 2. 杠上花 (×3) vs 五梅花 (杠上补摸 5p 或 1s 成胡，×5)
      final normalHand = h('123m456p789s234m55p');
      final gshRes = yunnanEvaluate(normalHand, const [], winTile: '4m', selfDrawn: true, gangKai: true)!;
      expect(gshRes.isGangShangHua, isTrue);
      expect(gshRes.isWuMeiHua, isFalse);
      expect(gshRes.mult, 3);
      expect(gshRes.label, contains('杠上花'));

      final wmh5pRes = yunnanEvaluate(normalHand, const [], winTile: '5p', selfDrawn: true, gangKai: true)!;
      expect(wmh5pRes.isWuMeiHua, isTrue);
      expect(wmh5pRes.mult, 5);
      expect(wmh5pRes.label, contains('五梅花'));

      final wmh1sRes = yunnanEvaluate(h('123m456p789s234m5p1s'), const [], winTile: '1s', selfDrawn: true, gangKai: true)!;
      expect(wmh1sRes.isWuMeiHua, isTrue);
      expect(wmh1sRes.mult, 5);

      // 3. 十风胡 ('shifeng') 连续字牌追踪与 ×4 全场结算
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'targetHonors': 8},
        names: const ['A', 'B', 'C', 'D'],
        bots: const [false, false, false, false],
        rng: Random(29),
      );
      final g = YunnanGame(setup)..start();
      final s0 = g.turn;
      // 打出字牌计数 +1，打出数牌重置为 0
      g.hands[s0][tileFromCode('1z')] = 2;
      g.hands[s0][tileFromCode('2m')] = 2;
      g.handle(s0, {'type': 'discard', 'tile': '1z'});
      expect(g.consecutiveHonors[s0], 1);

      // 模拟 s0 已连续打出 7 张字牌，轮到 s0 手握第 8 张字牌发动 {'type': 'shifeng'}
      g.phase = 'act';
      g.turn = s0;
      g.consecutiveHonors[s0] = 7;
      g.hands[s0][tileFromCode('2z')] = 1;
      expect(g.canShifeng(s0), isTrue);
      g.handle(s0, {'type': 'shifeng'});
      expect(g.consecutiveHonors[s0], 8);
      expect(g.isOver, isTrue);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(huEv['shifeng'], isTrue);
      expect(huEv['mult'], 4);
    });
  });

  test('simulate all mahjong7 games (count: 30)', () {
    expect(runSims(mahjong7Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
