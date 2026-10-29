import 'dart:math';

import 'package:aurora_shared/games/mahjong9/changchun.dart';
import 'package:aurora_shared/games/mahjong9/defs.dart';
import 'package:aurora_shared/games/mahjong9/shenyang.dart';
import 'package:aurora_shared/games/mahjong9/tiles.dart';
import 'package:aurora_shared/games/mahjong9/wenzhou.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

List<int> h(String s, [int kinds = kKinds]) => countsOf(parseTiles(s), kinds);

void main() {
  claimCoverEnabled = false;

  group('沈阳麻将 (shenyangmj)', () {
    test('四大硬条件（开门、三门齐、有横牌、有幺九）、翻会牌百搭 (huiTile) 与旋风杠 (xfgang)', () {
      final openChi1m = [Meld('chi', tileFromCode('1m'), claimed: tileFromCode('1m'), from: 3)];
      final openPeng2m = [Meld('peng', tileFromCode('2m'), claimed: tileFromCode('2m'), from: 1)];

      // 1. 条件一【开门 (isOpened)】：门清标准手（即使三门齐、有刻子、有幺九）不可胡；但门清七对可胡！
      expect(
        shenyangEvaluate(h('111m456p789s234m55p'), const [], useHui: false),
        isNull,
        reason: '门清非七对未开门不可胡牌',
      );
      final qiduiRes = shenyangEvaluate(h('1122m3344p5566s11z'), const [], useHui: false);
      expect(qiduiRes, isNotNull, reason: '七对满足开门、三门齐、有幺九可胡');
      expect(qiduiRes!.isQiDui, isTrue);

      // 2. 条件二【三门齐 (hasAllThreeSuits)】：缺条子 (s) 不可胡
      expect(
        shenyangEvaluate(h('456p789p222m55p'), openChi1m, useHui: false),
        isNull,
        reason: '缺条子（未满足三门齐）不可胡牌',
      );

      // 3. 条件三【有横牌 (hasHeng)】：全顺子 + 普通数牌将 (55p) 不可胡；有暗刻 (222m) 或中发白作将 (55z) 可胡！
      expect(
        shenyangEvaluate(h('456p789s234m55p'), openChi1m, useHui: false),
        isNull,
        reason: '全顺子且非中发白作掌（无横牌）不可胡牌',
      );
      final dragonPairRes = shenyangEvaluate(h('456p789s234m55z'), openChi1m, useHui: false);
      expect(dragonPairRes, isNotNull, reason: '中发白 (5z) 作掌/将满足有横牌条件');
      expect(dragonPairRes!.hasHeng, isTrue);

      final tripRes = shenyangEvaluate(h('456p789s222m55p'), openChi1m, useHui: false);
      expect(tripRes, isNotNull, reason: '含暗刻 (222m) 满足有横牌条件');

      // 4. 条件四【有幺九 (hasYaoJiu)】：全断幺（全 2..8 数牌，无 1/9 与字牌）不可胡；加入 1/9 或字牌可胡！
      expect(
        shenyangEvaluate(h('345p678s345m55p'), openPeng2m, useHui: false),
        isNull,
        reason: '全断幺无 1/9 及字牌（无幺九）不可胡牌',
      );
      final yaojiuRes = shenyangEvaluate(h('345p789s345m55p'), openPeng2m, useHui: false);
      expect(yaojiuRes, isNotNull, reason: '含 9s 满足有幺九条件');

      // 5. 翻会牌百搭 (useHui: true) 与旋风杠 ('xfgang': 'wind' | 'dragon') 完整对局验证
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'useHui': true},
        names: const ['东', '南', '西', '北'],
        bots: const [false, false, false, false],
        rng: Random(19),
      );
      final g = ShenyangGame(setup)..start();
      g.setHuiIndicator('1m');
      expect(g.huiTile, '2m');

      // 庄家 (seat 0) 手握白发中 (5z,6z,7z) 亮出喜杠 ('dragon')，立即向三家各收 +2 分并开门 + 满足横牌与幺九！
      g.hands[0] = h('567z345m456p78s2m55p'); // 2m 为会牌，代 9s 凑成 789s
      g.handle(0, {'type': 'xfgang', 'kind': 'dragon'});
      expect(g.melds[0].length, 1);
      expect(g.melds[0].first.kind, 'xfgang');
      expect(g.scores[0], 6);
      expect(g.scores[1], -2);
      expect(g.canSelfHu, isTrue);

      g.handle(0, {'type': 'tsumo'});
      expect(g.isOver, isTrue);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(huEv['xfgangCount'], 1);
    });
  });

  group('长春麻将 (changchunmj)', () {
    test('下蛋 (喜蛋/风蛋/幺蛋/九蛋)、小鸡飞蛋 (1s代蛋)、补蛋 (jiadan) 与摸宝/抱宝 (+2番)', () {
      // 1. 校验 4 种标准下蛋与 1s 幺鸡代蛋（小鸡飞蛋）分类
      expect(classifyXiadan(parseTiles('567z')), 'dragon');
      expect(classifyXiadan(parseTiles('123z')), 'wind');
      expect(classifyXiadan(parseTiles('1m1p1s')), 'yao');
      expect(classifyXiadan(parseTiles('9m9p9s')), 'jiu');
      expect(classifyXiadan(parseTiles('56z1s'), feidan: true), 'dragon');
      expect(classifyXiadan(parseTiles('9m9p1s'), feidan: true), 'jiu');
      expect(classifyXiadan(parseTiles('56z1s'), feidan: false), isNull);

      // 2. 宝牌加番校验：无宝 vs 抱宝 (+2番) vs 摸宝 (+2番)
      final baseRes = changchunEvaluate(
        h('123m456p789s234m55p'),
        const [],
        baoTile: '9z',
        selfDrawn: true,
      )!;
      final baoBaoRes = changchunEvaluate(
        h('123m456p789s234m55p'),
        const [],
        baoTile: '5p', // 手中含 5p -> 抱宝 +2 番
        winTile: '1m',
        selfDrawn: true,
      )!;
      final moBaoRes = changchunEvaluate(
        h('123m456p789s234m55p'),
        const [],
        baoTile: '5p',
        winTile: '5p', // 胡牌张为 5p -> 摸宝 +2 番
        selfDrawn: true,
      )!;
      expect(baoBaoRes.isBaoBao, isTrue);
      expect(baoBaoRes.fan, baseRes.fan + 2);
      expect(moBaoRes.isMoBao, isTrue);
      expect(moBaoRes.fan, baseRes.fan + 2);

      // 3. 完整流程：下蛋 ('xiadan' 含 1s 小鸡飞蛋) 立即收三家各 +2 分 -> 补蛋 ('jiadan') -> 摸宝自摸胡牌
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'feidan': true},
        names: const ['A', 'B', 'C', 'D'],
        bots: const [false, false, false, false],
        rng: Random(29),
      );
      final g = ChangchunGame(setup)..start();
      g.setBaoIndicator('4p');
      expect(g.baoTile, '5p');

      // 庄家使用 5z, 6z, 1s (小鸡飞蛋代 7z) 亮出喜蛋，立即向三家各收 +2 分（共 +6 分）
      g.hands[0] = h('56z1s123m456p789s55p');
      g.handle(0, {'type': 'xiadan', 'tiles': const ['5z', '6z', '1s']});
      expect(g.melds[0].length, 1);
      expect(g.melds[0].first.kind, 'xiadan');
      expect(g.melds[0].first.subKind, 'dragon');
      expect(g.scores, [6, -2, -2, -2]);

      // 庄家手握宝牌 5p 自摸胡牌
      g.drawn[0] = tileFromCode('5p');
      g.handle(0, {'type': 'tsumo'});
      expect(g.isOver, isTrue);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(huEv['hasBao'], isTrue);
      expect(huEv['eggCount'], 1);
    });
  });

  group('温州麻将 (wenzhoumj)', () {
    test('买底与顶底阶段 (maidi)、翻财神与白板顶替 (5z)、三财神推倒胡 (sancaishen) 与硬牌(×2)/软牌(×1)', () {
      // 1. 翻财神 (caishenTile = '2m') 与白板 (5z) 顶替 2m 组成 1m-2m-3m 顺子（且 0 张财神算硬牌 ×2 番！）
      final cs = tileFromCode('2m');
      final hakuSubHand = h('1m5z3m456p789s234m55p'); // 5z 白板顶替 2m 组成 123m，无财神 -> 硬牌！
      final yingRes = wenzhouEvaluate(hakuSubHand, const [], caishenTile: cs, selfDrawn: true)!;
      expect(yingRes.isYingPai, isTrue);
      expect(yingRes.label, contains('硬牌×2'));

      // 2. 财神 ('2m') 仅作为原本牌面自然成牌 (1m-2m-3m) 同样算硬牌 (×2 番) vs 财神充当百搭代牌算软牌 (×1 番)
      final naturalCsHand = h('123m456p789s234m55p');
      final naturalYingRes = wenzhouEvaluate(naturalCsHand, const [], caishenTile: cs, selfDrawn: true)!;
      expect(naturalYingRes.isYingPai, isTrue);

      final softCsHand = h('678m45p2m789s345m55p'); // 1张 2m 代替 6p -> 软牌 (×1 番)
      final ruanRes = wenzhouEvaluate(softCsHand, const [], caishenTile: cs, selfDrawn: true)!;
      expect(ruanRes.isYingPai, isFalse);
      expect(yingRes.fan, ruanRes.fan * 2);
      expect(yingRes.mult, ruanRes.mult * 2);

      // 3. 完整流程：Step 1 买底/顶底 ('maidi') -> 三财神推倒胡 ('sancaishen') 倍数加成验证
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'allowRon': true},
        names: const ['东庄', '南闲', '西闲', '北闲'],
        bots: const [false, false, false, false],
        rng: Random(37),
      );
      final g = WenzhouGame(setup)..start();
      g.setCaishenIndicator('1m');
      expect(g.caishenTile, '2m');
      expect(g.phase, 'maidi');
      expect(g.waitingFor, [0, 1, 2, 3]);

      // 庄家 (0) 买底 (true)，南闲 (1) 顶底 (true)，西闲 (2) 不顶底 (false)，北闲 (3) 顶底 (true)
      final buys = [true, true, false, true];
      for (var s = 0; s < 4; s++) {
        g.handle(s, {'type': 'maidi', 'buy': buys[s]});
      }
      expect(g.phase, 'act');
      expect(g.maidi, buys);
      expect(g.maidiMultiplier(0, 1), 3); // 庄买底(+1) + 南顶底(+1) -> ×3
      expect(g.maidiMultiplier(0, 2), 2); // 庄买底(+1) + 西不顶底(0) -> ×2

      // 庄家手握 3 张财神 ('2m')，发动 {'type': 'sancaishen'} 立即自摸推倒胡！
      g.hands[0] = h('222m147p258s13467z');
      g.canZimo = true;
      expect(g.canSanCaiShen, isTrue);
      g.handle(0, {'type': 'sancaishen'});
      expect(g.isOver, isTrue);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(huEv['sancaishen'], isTrue);
      final mults = (huEv['maidiMults'] as Map).cast<String, int>();
      expect(mults['1'], 3);
      expect(mults['2'], 2);
      expect(mults['3'], 3);
    });
  });

  test('simulate all mahjong9 games (count: 30)', () {
    expect(runSims(mahjong9Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
