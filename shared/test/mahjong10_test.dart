import 'dart:math';

import 'package:aurora_shared/games/mahjong10/changzhou.dart';
import 'package:aurora_shared/games/mahjong10/chaoshan.dart';
import 'package:aurora_shared/games/mahjong10/defs.dart';
import 'package:aurora_shared/games/mahjong10/qingdao.dart';
import 'package:aurora_shared/games/mahjong10/tiles.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

List<int> h(String s, [int kinds = kKinds]) => countsOf(parseTiles(s), kinds);

void main() {
  claimCoverEnabled = false;

  group('潮汕麻将 (chaoshanmj)', () {
    test('只能碰杠不能吃、奖马买马 (按门风中马 +1×baseFan)、捉铳包自摸 (×3) 与杠分即时结算', () {
      // 1. 门风奖马映射校验：东(1,5,9,1z,5z)、南(2,6,2z,6z)、西(3,7,3z,7z)、北(4,8,4z)
      for (final c in const ['1m', '5p', '9s', '1z', '5z']) {
        expect(isChaoshanHorseMatch(c, 0), isTrue, reason: '东位应中 $c');
        expect(isChaoshanHorseMatch(c, 1), isFalse);
      }
      for (final c in const ['2m', '6p', '2z', '6z']) {
        expect(isChaoshanHorseMatch(c, 1), isTrue, reason: '南位应中 $c');
        expect(isChaoshanHorseMatch(c, 0), isFalse);
      }
      for (final c in const ['3m', '7s', '3z', '7z']) {
        expect(isChaoshanHorseMatch(c, 2), isTrue, reason: '西位应中 $c');
        expect(isChaoshanHorseMatch(c, 3), isFalse);
      }
      for (final c in const ['4p', '8s', '4z']) {
        expect(isChaoshanHorseMatch(c, 3), isTrue, reason: '北位应中 $c');
        expect(isChaoshanHorseMatch(c, 2), isFalse);
      }

      // 2. 奖马番数计算：碰碰胡 (baseFan = 2)，东位中 2 匹马 -> fan = 2 * (1 + 2) = 6
      final evalRes = chaoshanEvaluate(
        h('111m222p333s444m55p'),
        const [],
        horseTiles: const ['1m', '5z', '2p', '4z'],
        seatWind: 0,
        selfDrawn: false,
      )!;
      expect(evalRes.baseFan, 2);
      expect(evalRes.matchedHorses, 2);
      expect(evalRes.horseBonus, 4);
      expect(evalRes.fan, 6);

      // 3. 对局校验：只能碰杠不能吃 + 杠分即时结算 + 捉铳包自摸 (含奖马加成 ×3)
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'allowRon': true, 'horseCount': 4},
        names: const ['东', '南', '西', '北'],
        bots: const [false, false, false, false],
        rng: Random(11),
      );
      final g = ChaoshanGame(setup)..start();

      // 庄家 (0) 暗杠 1m -> 立即向三家各收 +2 分 (共 +6 分)
      g.hands[0] = h('1111m234m456p789s5p');
      g.handle(0, {'type': 'agang', 'tile': '1m'});
      expect(g.scores, [6, -2, -2, -2]);

      // 下家 (1) 手握 2m, 3m（非听牌），庄家 (0) 打出 1m：下家 (1) 不能吃牌！
      g.hands[0] = h('1m234m456p789s1z');
      g.hands[1] = h('23m147p258s12345z');
      g.hands[2] = h('147m258p369s1234z');
      g.hands[3] = h('147m258p369s1234z');
      g.handle(0, {'type': 'discard', 'tile': '1m'});
      expect(g.phase, 'act', reason: '潮汕麻将不可吃牌，无人可碰杠胡时直接轮到下家摸牌');
      expect(() => g.handle(1, {'type': 'chi', 'tile': '1m'}), throwsA(isA<GameError>()));

      // 预设 4 匹奖马：['2m', '6z', '1m', '9s'] -> 南家 (seat 1, wind 1) 中 2m, 6z 共 2 匹马！
      g.setHorseTiles(const ['2m', '6z', '1m', '9s']);
      // 轮到南家 (1) 出牌，南家打出 9z，西家 (2) 听牌，或者让西家 (2) 打出銃牌给南家 (1) 捉铳胡！
      g.turn = 2;
      g.phase = 'act';
      g.hands[2] = h('5p147m258p369s1234z');
      g.hands[1] = h('123m456p789s234m5p'); // 鸡胡 (baseFan = 1) 听 5p
      g.handle(2, {'type': 'discard', 'tile': '5p'});
      expect(g.phase, 'claim');
      g.handle(1, {'type': 'ron'});

      // 南家 (1) 鸡胡 baseFan = 1，中 2 马 -> fan = 1 * (1 + 2) = 3；
      // 西家 (2) 点炮捉铳包自摸 -> 独自包赔三家份额 3 * 3 = 9 分！
      expect(g.isOver, isTrue);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(huEv['baoZimo'], isTrue);
      expect(huEv['matchedHorses'], 2);
      expect(huEv['fan'], 3);
      expect(huEv['total'], 9);
      expect((huEv['pay'] as Map)['2'], 9);
    });
  });

  group('常州麻将 (changzhoumj)', () {
    test('翻财神百搭 (caishenTile)、白板计台 (5z刻+1台 / 硬胡+1台) 与三口承包包三家 (feedCount >= 3)', () {
      // 1. 白板计台与无财神硬胡校验
      final cs = tileFromCode('2m');
      // 含白板暗刻 (555z) + 红中暗刻 (777z) + 无财神硬胡
      final yingRes = changzhouEvaluate(
        h('555z777z123m456p55s'),
        const [],
        caishenTile: cs,
        selfDrawn: false,
      )!;
      expect(yingRes.hakuTai, 1);
      expect(yingRes.dragonWindTai, 1);
      expect(yingRes.isYingHu, isTrue);
      // 底台(1) + 白板刻(1) + 红中刻(1) + 无财神硬胡(1) = 4 台
      expect(yingRes.tai, 4);

      // 使用财神 ('2m') 代替 '6p' 组成软胡 -> isYingHu 为 false
      final softRes = changzhouEvaluate(
        h('555z777z678m45p2m55s'),
        const [],
        caishenTile: cs,
        selfDrawn: false,
      )!;
      expect(softRes.isYingHu, isFalse);
      expect(softRes.tai, 3);

      // 2. 三口承包 (feedCount[seat][from] >= 3)：seat 1 连续吃/碰 seat 0 满 3 口，seat 1 自摸时由 seat 0 包赔三家 (×3)！
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'baosanjia': true},
        names: const ['东', '南', '西', '北'],
        bots: const [false, false, false, false],
        rng: Random(23),
      );
      final g = ChangzhouGame(setup)..start();
      g.setCaishenIndicator('8z'); // keep default or explicit
      g.setCaishenIndicator('8m'); // caishenTile = '9m'
      expect(g.caishenTile, '9m');

      // 让 seat 1 向 seat 0 吃/碰满 3 口
      g.hands[0] = h('1m2p3s147m258p36s123z');
      g.hands[1] = h('23m22p45s678m555z22s');
      g.hands[2] = h('147m258p369s1234z');
      g.hands[3] = h('147m258p369s1234z');

      // 第 1 口：seat 0 打 1m，seat 1 吃 123m
      g.turn = 0;
      g.phase = 'act';
      g.handle(0, {'type': 'discard', 'tile': '1m'});
      g.handle(1, {'type': 'chi', 'tile': '1m'});
      expect(g.feedCount[1][0], 1);
      g.handle(1, {'type': 'discard', 'tile': '2s'});

      // 第 2 口：seat 0 打 2p，seat 1 碰 222p
      g.turn = 0;
      g.phase = 'act';
      g.handle(0, {'type': 'discard', 'tile': '2p'});
      g.handle(1, {'type': 'peng'});
      expect(g.feedCount[1][0], 2);
      g.handle(1, {'type': 'discard', 'tile': '2s'});

      // 第 3 口：seat 0 打 3s，seat 1 吃 345s -> feedCount[1][0] == 3，触发三口承包！
      g.turn = 0;
      g.phase = 'act';
      g.handle(0, {'type': 'discard', 'tile': '3s'});
      g.handle(1, {'type': 'chi', 'tile': '3s'});
      expect(g.feedCount[1][0], 3);
      expect(g.contractorFor(1), 0);

      // seat 1 摸牌自摸胡牌（由承包人 seat 0 独自包赔 ×3 份，seat 2 与 seat 3 得失分为 0！）
      g.hands[1] = h('678m55z'); // 已露 3 组 + 手牌 678m55z (5张) 自摸！
      g.drawn[1] = tileFromCode('8m');
      g.canZimo = true;
      g.handle(1, {'type': 'tsumo'});
      expect(g.isOver, isTrue);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(huEv['baosanjia'], isTrue);
      expect(huEv['baoSeat'], 0);
      expect(g.scores[2], 0);
      expect(g.scores[3], 0);
      expect(g.scores[0], -g.scores[1]);
    });
  });

  group('青岛麻将 (qingdaomj)', () {
    test('严格258作将 (七对/清一色/对对胡免258)、翻混儿百搭 (hunTile) 与扭牌 (niupai 亮风/亮箭立收三家+2分且+1番)', () {
      // 1. 严格 258 将检验：普通手非 258 将 (11p) 不可胡，258 将 (55p) 或混儿代将可胡！
      expect(
        qingdaoEvaluate(h('123m456p789s234m11p'), const [], strict258: true),
        isNull,
        reason: 'strict258 开启时，普通平胡以 1p 作将不可胡牌',
      );
      expect(
        qingdaoEvaluate(h('123m456p789s234m11p'), const [], strict258: false),
        isNotNull,
        reason: 'strict258 关闭时，任意将可胡',
      );
      final res258 = qingdaoEvaluate(h('123m456p789s234m55p'), const [], strict258: true);
      expect(res258, isNotNull, reason: '5p 作将满足 258 将要求');
      expect(res258!.has258Pair, isTrue);

      // 混儿百搭 (hunTile = '9z' / '3m') 与单张 5p 凑成 258 将
      final hunRes = qingdaoEvaluate(
        h('123m456p789s234m5p1z'),
        const [],
        hunTile: '1z',
        strict258: true,
      );
      expect(hunRes, isNotNull, reason: '混儿 (1z) 代 5p 组成 55p 将可胡');

      // 2. 七对、清一色、对对胡免 258 将限制（以 1z 或 1m 作将均可胡！）
      final qiduiRes = qingdaoEvaluate(h('1122m3344p5566s11z'), const [], strict258: true);
      expect(qiduiRes, isNotNull, reason: '七对免 258 将限制');
      expect(qiduiRes!.isQiDui, isTrue);

      final qysRes = qingdaoEvaluate(h('123m234m345m678m11m'), const [], strict258: true);
      expect(qysRes, isNotNull, reason: '清一色免 258 将限制');
      expect(qysRes!.isQingYiSe, isTrue);

      final duiduiRes = qingdaoEvaluate(h('111m333p777s999m11z'), const [], strict258: true);
      expect(duiduiRes, isNotNull, reason: '对对胡免 258 将限制');
      expect(duiduiRes!.isDuiDui, isTrue);

      // 3. 扭牌 ('niupai' 亮箭 5z+6z+7z / 亮风 1z+2z+3z) 校验
      expect(classifyNiupai(const ['5z', '6z', '7z']), 'dragon');
      expect(classifyNiupai(const ['1z', '2z', '3z']), 'wind');
      expect(classifyNiupai(const ['1z', '3z', '4z']), 'wind');
      expect(classifyNiupai(const ['1z', '2z', '5z']), isNull);

      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'strict258': true},
        names: const ['东', '南', '西', '北'],
        bots: const [false, false, false, false],
        rng: Random(41),
      );
      final g = QingdaoGame(setup)..start();
      g.setHunIndicator('1m');
      expect(g.hunTile, '2m');

      // 庄家 (0) 手握中发白 (5z+6z+7z) + 3 组顺子 + 55p (258将)
      g.hands[0] = h('567z345m456p789s55p');
      g.handle(0, {'type': 'niupai', 'tiles': const ['5z', '6z', '7z']});
      expect(g.melds[0].length, 1);
      expect(g.melds[0].first.kind, 'niupai');
      expect(g.melds[0].first.subKind, 'dragon');
      // 立即向每位对手收取 +2 分（庄家 +6，其余三家各 -2）
      expect(g.scores, [6, -2, -2, -2]);
      expect(g.canSelfHu, isTrue);

      // 庄家自摸胡牌，扭牌额外 +1 番
      g.handle(0, {'type': 'tsumo'});
      expect(g.isOver, isTrue);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(huEv['niupaiCount'], 1);
      expect(huEv['fan'], (huEv['baseFan'] as int) + 1);
    });
  });

  test('simulate all mahjong10 games (count: 30)', () {
    expect(runSims(mahjong10Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
