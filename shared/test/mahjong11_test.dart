import 'dart:math';

import 'package:aurora_shared/games/mahjong11/defs.dart';
import 'package:aurora_shared/games/mahjong11/hainan.dart';
import 'package:aurora_shared/games/mahjong11/tangshan.dart';
import 'package:aurora_shared/games/mahjong11/tiles.dart';
import 'package:aurora_shared/games/mahjong11/wuxi.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

List<int> h(String s, [int kinds = kKinds]) => countsOf(parseTiles(s), kinds);

void main() {
  claimCoverEnabled = false;

  group('唐山麻将 (tangshanmj)', () {
    test('本混儿钻山 (hunIndicator->hunTile)、报听封手 (baoting +2番/×2倍) 与捉五魁/一条龙/七对/门清 (+2番)', () {
      // 1. 捉五魁 (+2番) + 一条龙 (+2番) + 门清 (+2番) + 报听 (+2番, ×2) 评估校验
      final res5m = tangshanEvaluate(
        h('123456789m456p55m'),
        const [],
        hunTile: '1z',
        winTile: '5m',
        baoting: true,
        selfDrawn: false,
      )!;
      expect(res5m.isBaoting, isTrue);
      expect(res5m.isZhuoWuKui, isTrue);
      expect(res5m.isYiTiaoLong, isTrue);
      expect(res5m.isMenQing, isTrue);
      // 底番(1) + 报听(2) + 捉五魁(2) + 一条龙(2) + 门清(2) + 素胡(1) = 10 番
      expect(res5m.fan, 10);

      // 七对 (+2番) + 本混儿百搭代牌校验
      final resQidui = tangshanEvaluate(
        h('1122m3344p5566s5p1z'),
        const [],
        hunTile: '1z',
        winTile: '5p',
        baoting: false,
        selfDrawn: false,
      )!;
      expect(resQidui.isQiDui, isTrue);
      expect(resQidui.isZhuoWuKui, isTrue);
      expect(resQidui.isMenQing, isTrue);
      expect(resQidui.isYingHu, isFalse);

      // 2. 报听封手对局校验：差1张听牌时声明 {'type': 'baoting', 'tile': d} 锁手 + 胡牌 ×2 倍！
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'allowRon': true},
        names: const ['东', '南', '西', '北'],
        bots: const [false, false, false, false],
        rng: Random(19),
      );
      final g = TangshanGame(setup)..start();
      g.setHunIndicator('9m'); // hunTile = '1m'
      expect(g.hunTile, '1m');

      // 庄家 (0) 手握 123m 456p 789s 46s 22p + 7z，打出 7z 后卡张听 5s（捉五魁）
      g.hands[0] = h('123m456p789s46s22p7z');
      g.hands[1] = h('5s147m258p369s1234z');
      g.hands[2] = h('147m258p369s1234z');
      g.hands[3] = h('147m258p369s1234z');

      expect(g.canBaoting(0), isTrue);
      expect(g.baotingTiles(0), contains(tileFromCode('7z')));

      // 庄家 (0) 宣告报听打出 7z
      g.handle(0, {'type': 'baoting', 'tile': '7z'});
      expect(g.baoting[0], isTrue);
      expect(g.phase, 'act');
      expect(g.turn, 1);

      // 下家 (1) 打出 5s 点炮 -> 庄家 (0) 触发捉五魁 + 报听 (+2番 且 ×2 倍)！
      g.handle(1, {'type': 'discard', 'tile': '5s'});
      expect(g.phase, 'claim');
      g.handle(0, {'type': 'ron'});

      expect(g.isOver, isTrue);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(huEv['baoting'], isTrue);
      expect(huEv['isZhuoWuKui'], isTrue);
      expect(huEv['isMenQing'], isTrue);
      // 报听胡牌结算按 fan * 2 翻倍赔付
      expect(huEv['total'], (huEv['fan'] as int) * 2);
      expect(g.scores[0], huEv['total']);
      expect(g.scores[1], -(huEv['total'] as int));
    });
  });

  group('无锡麻将 (wuximj)', () {
    test('翻百搭 (baidaIndicator->baidaTile)、无百搭硬胡 (+1番) / 门清双倍 (+1番) 与放冲独付 (点炮独赔×3)', () {
      // 1. 翻百搭 + 无百搭硬胡 (+1番) + 门清双倍 (+1番, mult*=2) 评估校验
      final hardRes = wuxiEvaluate(
        h('123m456p789s234m55p'),
        const [],
        baidaTile: '1z',
        selfDrawn: false,
      )!;
      expect(hardRes.isYingHu, isTrue);
      expect(hardRes.isMenQing, isTrue);
      // 底番(1) + 无百搭硬胡(1) + 门清双倍(1) = 3 番
      expect(hardRes.fan, 3);
      expect(hardRes.mult, 2);

      // 使用百搭 ('1z') 代替 '3m' 组成软胡 -> isYingHu 为 false
      final softRes = wuxiEvaluate(
        h('12m1z456p789s234m55p'),
        const [],
        baidaTile: '1z',
        selfDrawn: false,
      )!;
      expect(softRes.isYingHu, isFalse);
      expect(softRes.isMenQing, isTrue);
      expect(softRes.fan, 2);

      // 2. 放冲独付校验：自摸三家各付 1×；点炮（ron）由放冲者一人独付全三家份额 (×3)，其余两家付 0！
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'fangchongDufu': true},
        names: const ['东', '南', '西', '北'],
        bots: const [false, false, false, false],
        rng: Random(29),
      );
      final g = WuxiGame(setup)..start();
      g.setBaidaIndicator('4z'); // baidaTile = '1z'
      expect(g.baidaTile, '1z');

      // 让 seat 2 打出 5p 给 seat 1 捉铳胡（放冲独付）
      g.turn = 2;
      g.phase = 'act';
      g.hands[1] = h('123m456p789s234m5p'); // 门清 + 无百搭硬胡 听 5p (fan = 3)
      g.hands[2] = h('5p147m258p369s2345z');
      g.hands[0] = h('147m258p369s2345z');
      g.hands[3] = h('147m258p369s2345z');

      g.handle(2, {'type': 'discard', 'tile': '5p'});
      expect(g.phase, 'claim');
      g.handle(1, {'type': 'ron'});

      expect(g.isOver, isTrue);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(huEv['fangchongDufu'], isTrue);
      expect(huEv['fan'], 3);
      expect(huEv['total'], 9); // 3 番 × 3 家份额 = 9 分
      // 点炮者 seat 2 独付 -9 分，其余两家 (seat 0, seat 3) 为 0 分！
      expect(g.scores, [0, 9, -9, 0]);
    });
  });

  group('海南麻将 (hainanmj)', () {
    test('开局上噶 (gama 0~3 双边加分)、有番起胡 (令牌/门清/平胡全顺/对对胡等) 与首圈跟庄 (genzhuang 庄赔三家各+2)', () {
      // 1. 有番起胡校验：有吃有碰（非门清、非全顺、非对对胡）且无令牌、非清/混一色 -> 无番！
      final noFanHand = h('456s789s55m');
      final noFanMelds = [Meld('chi', tileFromCode('1m')), Meld('peng', tileFromCode('2p'))];
      expect(
        hainanEvaluate(noFanHand, noFanMelds, seatWind: 1, roundWind: 0, requireFan: true),
        isNull,
        reason: '有番起胡开启时，有吃有碰且无令牌的杂牌无番手不可胡牌',
      );
      expect(
        hainanEvaluate(noFanHand, noFanMelds, seatWind: 1, roundWind: 0, requireFan: false),
        isNotNull,
        reason: '关闭有番起胡时，无番平胡可胡牌',
      );

      // 有番条件 1：令牌（中/发/白 5z..7z 刻，或门风/圈风刻）可胡！
      final lingMelds = [Meld('chi', tileFromCode('1m')), Meld('peng', tileFromCode('7z'))];
      final lingRes = hainanEvaluate(noFanHand, lingMelds, seatWind: 1, roundWind: 0, requireFan: true);
      expect(lingRes, isNotNull, reason: '持有红中刻（令牌）满足有番起胡');
      expect(lingRes!.hasLingPai, isTrue);

      // 有番条件 2：平胡全顺（4顺子 + 非字牌将，即便有吃牌副露也算有番！）
      final quanShunMelds = [Meld('chi', tileFromCode('1m')), Meld('chi', tileFromCode('2p'))];
      final quanShunRes = hainanEvaluate(noFanHand, quanShunMelds, seatWind: 1, roundWind: 0, requireFan: true);
      expect(quanShunRes, isNotNull, reason: '4顺子 + 数牌将满足平胡全顺有番起胡');
      expect(quanShunRes!.isPingHuQuanShun, isTrue);

      // 2. 第一阶段 上噶 ('gama' 0..3) + 首圈跟庄 ('genzhuang') + 结算 +(gama[winner] + gama[loser]) 校验
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'requireFan': true},
        names: const ['东', '南', '西', '北'],
        bots: const [false, false, false, false],
        rng: Random(37),
      );
      final g = HainanGame(setup)..start();
      expect(g.phase, 'gama');

      // 四家依次选择上噶：seat 0 选 3噶，seat 1 选 2噶，seat 2 选 1噶，seat 3 选 0噶
      g.handle(0, {'type': 'gama', 'score': 3});
      g.handle(1, {'type': 'gama', 'score': 2});
      g.handle(2, {'type': 'gama', 'score': 1});
      g.handle(3, {'type': 'gama', 'score': 0});
      expect(g.gama, [3, 2, 1, 0]);
      expect(g.phase, 'act');

      // 预设四家手牌，令首圈 4 张舍牌全部打出 '4z'（北风）且无人吃碰杠 -> 触发首圈跟庄！
      g.hands[0] = h('4z123m456p789s234m5p');
      g.hands[1] = h('4z147m258p369s123z');
      g.hands[2] = h('4z147m258p369s123z');
      g.hands[3] = h('4z147m258p369s123z');

      g.handle(0, {'type': 'discard', 'tile': '4z'});
      g.handle(1, {'type': 'discard', 'tile': '4z'});
      g.handle(2, {'type': 'discard', 'tile': '4z'});
      g.handle(3, {'type': 'discard', 'tile': '4z'});

      expect(g.discardHistory.length, 4);
      expect(g.genzhuang, isTrue, reason: '首圈四家连打同一张牌且0副露，立即触发跟庄');
      // 庄家 (0) 立即向三家闲家各赔 +2 分！
      expect(g.scores, [-6, 2, 2, 2]);

      // 轮回庄家 (0) 自摸胡牌：门清 (1) + 平胡全顺 (1) + 自摸 (1) = 3 番
      // 每位输家 p 额外支付 +(gama[0] + gama[p])：
      // seat 1 付 3 + (3+2) = 8；seat 2 付 3 + (3+1) = 7；seat 3 付 3 + (3+0) = 6（共 +21 分）
      g.hands[0] = h('123m456p789s234m55p');
      g.drawn[0] = tileFromCode('5p');
      g.canZimo = true;
      g.handle(0, {'type': 'tsumo'});

      expect(g.isOver, isTrue);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(huEv['fan'], 3);
      expect((huEv['gamaPay'] as Map), {'1': 5, '2': 4, '3': 3});
      expect((huEv['pay'] as Map), {'1': 8, '2': 7, '3': 6});
      expect(huEv['total'], 21);
      // 加上跟庄的 [-6, 2, 2, 2]，最终总分为 [15, -6, -5, -4]
      expect(g.scores, [15, -6, -5, -4]);
    });
  });

  test('simulate all mahjong11 games (count: 30)', () {
    expect(runSims(mahjong11Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
