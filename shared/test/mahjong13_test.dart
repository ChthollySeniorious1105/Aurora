import 'dart:math';

import 'package:aurora_shared/games/mahjong13/beijing.dart';
import 'package:aurora_shared/games/mahjong13/defs.dart';
import 'package:aurora_shared/games/mahjong13/hongzhong.dart';
import 'package:aurora_shared/games/mahjong13/nanjing.dart';
import 'package:aurora_shared/games/mahjong13/ningxia.dart';
import 'package:aurora_shared/games/mahjong13/tiles.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

List<int> h(String s, [int kinds = kKinds]) => countsOf(parseTiles(s), kinds);

void main() {
  claimCoverEnabled = false;

  group('红中赖子麻将 (hongzhongmj)', () {
    test('112张牌、红中(7z)万能赖子、四红中天胡、硬胡无红中、豪华七对/碰碰胡/清一色 与 扎鸟抓码 (birdTiles & hitBirds)', () {
      // 1. 四红中直接可胡 (siHongZhong)
      final siHzRes = hongzhongEvaluate(
        h('7777z147m258p369s1m'),
        const [],
        selfDrawn: true,
      );
      expect(siHzRes, isNotNull, reason: '手握4张红中可直接自摸胡牌');
      expect(siHzRes!.siHongZhong, isTrue);

      // 2. 硬胡无红中 (+2番) + 豪华七对 (+4番) + 清一色 (+4番) + 门清 (+1番)
      final hardLuxuryQing = hongzhongEvaluate(
        h('11112233445566m'),
        const [],
        selfDrawn: true,
      )!;
      expect(hardLuxuryQing.isYingHu, isTrue);
      expect(hardLuxuryQing.isHaoHuaQiDui, isTrue);
      expect(hardLuxuryQing.isQiDui, isTrue);
      expect(hardLuxuryQing.isQingYiSe, isTrue);
      expect(hardLuxuryQing.isMenQing, isTrue);

      // 3. 红中代牌组成碰碰胡（软胡，isYingHu == false）
      final softPeng = hongzhongEvaluate(
        h('111m222p333s44m55p7z'),
        const [],
        selfDrawn: true,
      )!;
      expect(softPeng.isPengPeng, isTrue);
      expect(softPeng.isYingHu, isFalse);

      // 4. 对局流程验证：112张牌不可吃、扎鸟抓码 (1/5/9/7z 中鸟)
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'allowRon': false, 'birds': 4},
        names: const ['东', '南', '西', '北'],
        bots: const [false, false, false, false],
        rng: Random(13),
      );
      final g = HongzhongGame(setup)..start();
      expect(g.laiziTile, '7z');
      // 112 total tiles: 13*4 + 1 = 53 dealt, 59 remaining in wall
      expect(g.wall.length, 112 - 53);

      // 预设扎鸟牌：1m(中), 2p(不中), 9s(中), 7z(中) -> 共中 3 鸟
      g.setBirdTiles(['1m', '2p', '9s', '7z']);
      g.hands[0] = h('7777z147m258p369s1m');
      expect(g.canSelfHu, isTrue);

      g.handle(0, {'type': 'tsumo'});
      expect(g.isOver, isTrue);
      expect(g.birdTiles, ['1m', '2p', '9s', '7z']);
      expect(g.hitBirds, ['1m', '9s', '7z']);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(huEv['siHongZhong'], isTrue);
      expect(huEv['hitBirdCount'], 3);
    });
  });

  group('北京麻将 (beijingmj)', () {
    test('翻混儿 (hunTile)、捉五魁 (+4)、一条龙 (+4)、本混儿龙 (+8)、素胡 (+2) 与 混儿吊 (+2)', () {
      // 1. 本混儿龙 (+8番)：一条龙花色与 hunTile 花色相同 (万字一条龙 + 混儿 2m)
      final benHunLongRes = beijingEvaluate(
        h('123456789m111p22s'),
        const [],
        hunTile: '2m',
        winTile: '9m',
        selfDrawn: true,
      )!;
      expect(benHunLongRes.isBenHunLong, isTrue);
      expect(benHunLongRes.isYiTiaoLong, isTrue);

      // 2. 普通一条龙 (+4番)：一条龙花色与 hunTile 花色不同 (万字一条龙 + 混儿 2p)
      final yiTiaoLongRes = beijingEvaluate(
        h('123456789m111p22s'),
        const [],
        hunTile: '2p',
        winTile: '9m',
        selfDrawn: true,
      )!;
      expect(yiTiaoLongRes.isYiTiaoLong, isTrue);
      expect(yiTiaoLongRes.isBenHunLong, isFalse);

      // 3. 捉五魁 (+4番) + 素胡 (+2番)：胡 5m 嵌张完成 456m 且无混儿
      final zhuoWuKuiRes = beijingEvaluate(
        h('456m123p789s111z22p'),
        const [],
        hunTile: '7z',
        winTile: '5m',
        selfDrawn: false,
      )!;
      expect(zhuoWuKuiRes.isZhuoWuKui, isTrue);
      expect(zhuoWuKuiRes.isSuHu, isTrue);

      // 4. 混儿吊 (+2番)：混儿与单张组成将牌
      final hunDiaoRes = beijingEvaluate(
        h('123m456p789s111z5m7z'),
        const [],
        hunTile: '7z',
        winTile: '5m',
        selfDrawn: true,
      )!;
      expect(hunDiaoRes.isHunDiao, isTrue);
      expect(hunDiaoRes.isSuHu, isFalse);

      // 5. 对局流程验证：捉五魁点炮胡
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'allowRon': true},
        names: const ['东', '南', '西', '北'],
        bots: const [false, false, false, false],
        rng: Random(17),
      );
      final g = BeijingGame(setup)..start();
      g.setHunIndicator('6z'); // hunTile = '7z'
      expect(g.hunTile, '7z');

      g.hands[0] = h('5m147m258p369s1234z');
      g.hands[1] = h('46m123p789s111z22p'); // 嵌 5m 捉五魁听口
      g.hands[2] = h('147m258p369s123z');
      g.hands[3] = h('147m258p369s123z');

      g.handle(0, {'type': 'discard', 'tile': '5m'});
      expect(g.phase, 'claim');
      expect(g.claim!.opts[1], contains('ron'));
      g.handle(1, {'type': 'ron'});

      expect(g.isOver, isTrue);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(huEv['isZhuoWuKui'], isTrue);
      expect(huEv['isSuHu'], isTrue);
    });
  });

  group('南京麻将 (nanjingmj)', () {
    test('硬花与算花 (huaCount, 无花果, 满堂花)、比下胡 (bixiahu ×2) 与 清一色/混一色/对对胡/七对/全球人独钓/门清', () {
      // 1. 无花果 (+1番) + 清一色 (+6番) + 门清 (+2番)
      final wuHuaQing = nanjingEvaluate(
        h('123456789m23455m'),
        const [],
        bixiahu: false,
        selfDrawn: false,
      )!;
      expect(wuHuaQing.huaCount, 0);
      expect(wuHuaQing.isWuHuaGuo, isTrue);
      expect(wuHuaQing.isQingYiSe, isTrue);
      expect(wuHuaQing.isMenQing, isTrue);

      // 2. 满堂花 (>=4花, +2番) + 对对胡 (+4番) + 混一色 (+4番) + 比下胡 (×2)
      final manTangRes = nanjingEvaluate(
        h('111222m555z66z'),
        [Meld('agang', tileFromCode('7z'))],
        bixiahu: true,
        selfDrawn: true,
      )!;
      expect(manTangRes.huaCount, greaterThanOrEqualTo(4));
      expect(manTangRes.isManTangHua, isTrue);
      expect(manTangRes.isPengPeng, isTrue);
      expect(manTangRes.isHunYiSe, isTrue);
      expect(manTangRes.isBiXiaHu, isTrue);

      // 3. 全球人独钓 (+4番)：4组明副露 + 手牌单钓将牌，且 >=3 组明副露自动触发比下胡
      final quanQiuRenRes = nanjingEvaluate(
        h('55p'),
        [
          Meld('chi', tileFromCode('1m'), claimed: tileFromCode('1m'), from: 3),
          Meld('peng', tileFromCode('2p'), claimed: tileFromCode('2p'), from: 2),
          Meld('peng', tileFromCode('3s'), claimed: tileFromCode('3s'), from: 1),
          Meld('peng', tileFromCode('1z'), claimed: tileFromCode('1z'), from: 0),
        ],
        selfDrawn: false,
      )!;
      expect(quanQiuRenRes.isQuanQiuRen, isTrue);
      expect(quanQiuRenRes.isBiXiaHu, isTrue);

      // 4. 对局流程验证：庄家胡牌触发连庄与比下胡
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 2, 'allowRon': true},
        names: const ['东', '南', '西', '北'],
        bots: const [false, false, false, false],
        rng: Random(29),
      );
      final g = NanjingGame(setup)..start();
      g.setBiXiaHu(true);
      g.hands[0] = h('112233m4455p66s77z'); // 七对 + 2张红中(2花)
      expect(g.canSelfHu, isTrue);

      g.handle(0, {'type': 'tsumo'});
      expect(g.phase, 'settle');
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(huEv['isQiDui'], isTrue);
      expect(huEv['isBiXiaHu'], isTrue);
      expect(huEv['huaCount'], 2);
    });
  });

  group('宁夏滑水麻将 (ningxiamj)', () {
    test('开局下鱼/滑水 (xiayu phase -> play, yu[winner]+yu[payer])、甩张 (+2番) 与 豪华七对/清一色/对对胡/一条龙', () {
      // 1. 牌型番种评估：甩张 (+2番) + 豪华七对 (+4番) + 清一色 (+4番) + 门清 (+1番) + 连庄 (+1番)
      final evalRes = ningxiaEvaluate(
        h('11112233445566p'),
        const [],
        shuaizhang: true,
        shuaizhangCount: 1,
        lianZhuang: 1,
        selfDrawn: false,
      )!;
      expect(evalRes.isShuaizhang, isTrue);
      expect(evalRes.isHaoHuaQiDui, isTrue);
      expect(evalRes.isQiDui, isTrue);
      expect(evalRes.isQingYiSe, isTrue);
      expect(evalRes.isMenQing, isTrue);
      // 底番(1) + 甩张(2) + 豪华七对(4) + 清一色(4) + 门清(1) + 连庄(1) = 13 番
      expect(evalRes.fan, 13);

      // 2. 开局下鱼 (xiayu phase: 0/2/5/8) -> 进入 play 阶段 -> 甩张 + 点炮结算加 yu[winner] + yu[payer]
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'allowRon': true},
        names: const ['东', '南', '西', '北'],
        bots: const [false, false, false, false],
        rng: Random(37),
      );
      final g = NingxiaGame(setup)..start();
      expect(g.phase, 'xiayu');
      expect(g.waitingFor, [0, 1, 2, 3]);

      g.handle(0, {'type': 'xiayu', 'yu': 5});
      g.handle(1, {'type': 'xiayu', 'yu': 8});
      g.handle(2, {'type': 'xiayu', 'yu': 2});
      g.handle(3, {'type': 'xiayu', 'yu': 0});
      expect(g.phase, 'play');
      expect(g.yu, [5, 8, 2, 0]);

      // 庄家 (0) 手握七对听牌型 + 1z，宣告甩张打出 1z 听 6s
      g.hands[0] = h('1122m3344p556s77z1z');
      g.hands[1] = h('6s147m258p369s1234z');
      g.hands[2] = h('147m258p369s1234z');
      g.hands[3] = h('147m258p369s1234z');

      g.handle(0, {'type': 'shuaizhang', 'tile': '1z'});
      expect(g.shuaizhang[0], isTrue);
      expect(g.shuaizhangCount[0], 1);
      expect(g.turn, 1);

      // 南家 (1, 8鱼) 打出 6s 点炮给 东家 (0, 5鱼)
      // 东家番数：底番(1) + 甩张(2) + 七对(2) + 门清(1) = 6 番
      // 滑水鱼分：yu[0](5) + yu[1](8) = 13 分 -> 总计 6 + 13 = 19 分！
      g.handle(1, {'type': 'discard', 'tile': '6s'});
      expect(g.phase, 'claim');
      g.handle(0, {'type': 'ron'});

      expect(g.isOver, isTrue);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(huEv['shuaizhang'], isTrue);
      expect(huEv['fan'], 6);
      expect(huEv['yuBonus'], 13);
      expect(huEv['total'], 19);
      expect(g.scores[0], 19);
      expect(g.scores[1], -19);
    });
  });

  test('simulate all mahjong13 games (count: 30)', () {
    expect(runSims(mahjong13Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
