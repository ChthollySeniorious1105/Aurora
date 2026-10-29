import 'dart:math';

import 'package:aurora_shared/games/mahjong12/dalian.dart';
import 'package:aurora_shared/games/mahjong12/defs.dart';
import 'package:aurora_shared/games/mahjong12/gansu.dart';
import 'package:aurora_shared/games/mahjong12/tiles.dart';
import 'package:aurora_shared/games/mahjong12/yangzhou.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

List<int> h(String s, [int kinds = kKinds]) => countsOf(parseTiles(s), kinds);

void main() {
  claimCoverEnabled = false;

  group('扬州麻将 (yangzhoumj)', () {
    test('翻配子 (peiziIndicator->peiziTile)、白板顶替 (5z 顶替配子本牌) 与软胡自摸 vs 硬牌/大胡可捉铳 (strictRon)', () {
      // 1. 白板顶替 (5z acts as natural face value/suit of peiziTile):
      // 设配子为 '2m'，手牌用 '5z' 代替 '2m' 组成 1m-5z-3m 顺子，且未使用 '2m' 百搭 -> 硬牌 (isYingPai == true)！
      final hakuSubHard = yangzhouEvaluate(
        h('13m5z456p789s234m55p'),
        const [],
        peiziTile: '2m',
        selfDrawn: false,
        strictRon: true,
      );
      expect(hakuSubHard, isNotNull, reason: '白板 5z 顶替 2m 组成 123m 顺子且0张配子百搭，属硬牌可捉铳');
      expect(hakuSubHard!.isYingPai, isTrue);

      // 2. 软屁胡：使用 '2m' 配子百搭代替 '6p' 组成杂色平胡 (非对对胡/混一色/清一色/七对/一条龙)
      // - 自摸 (selfDrawn: true) 可胡！
      // - 点炮捉铳 (selfDrawn: false, strictRon: true) 禁胡 (returns null)！
      final softPihuHand = h('123m45p2m789s234m55s');
      final softTsumo = yangzhouEvaluate(
        softPihuHand,
        const [],
        peiziTile: '2m',
        selfDrawn: true,
        strictRon: true,
      );
      expect(softTsumo, isNotNull, reason: '软屁胡自摸可胡');
      expect(softTsumo!.isYingPai, isFalse);
      expect(softTsumo.isDaHu, isFalse);

      final softRonStrict = yangzhouEvaluate(
        softPihuHand,
        const [],
        peiziTile: '2m',
        selfDrawn: false,
        strictRon: true,
      );
      expect(softRonStrict, isNull, reason: 'strictRon=true 时软屁胡禁止点炮捉铳');

      // 3. 软大胡（如配子百搭组成的对对胡 / 清一色 / 混一色 / 七对 / 一条龙）在 strictRon=true 下仍可捉铳点炮！
      final softDaHuRon = yangzhouEvaluate(
        h('111m444p77s2m222m55s'),
        const [],
        peiziTile: '2m',
        selfDrawn: false,
        strictRon: true,
      );
      expect(softDaHuRon, isNotNull, reason: '软对对胡属于大胡，在 strictRon=true 时允许捉铳点炮');
      expect(softDaHuRon!.isYingPai, isFalse);
      expect(softDaHuRon.isPengPeng, isTrue);
      expect(softDaHuRon.isDaHu, isTrue);

      // 4. 对局流程验证：翻配子 + 软屁胡禁捉铳 vs 硬牌可捉铳
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'strictRon': true},
        names: const ['东', '南', '西', '北'],
        bots: const [false, false, false, false],
        rng: Random(11),
      );
      final g = YangzhouGame(setup)..start();
      g.setPeiziIndicator('1m'); // peiziTile = '2m'
      expect(g.peiziTile, '2m');

      // seat 1 软屁胡听 5s（不可捉铳），seat 2 白板顶替硬牌听 5s（可捉铳）
      g.hands[0] = h('5s147m258p369s1234z');
      g.hands[1] = h('123m45p2m789s234m5s'); // 软屁胡听 5s
      g.hands[2] = h('13m5z456p789s234m5s'); // 5z 顶替 2m 硬牌听 5s
      g.hands[3] = h('147m258p369s123z');

      g.handle(0, {'type': 'discard', 'tile': '5s'});
      expect(g.phase, 'claim');
      // seat 1 软屁胡无 ron 权限，seat 2 硬牌有 ron 权限
      expect(g.claim!.opts.containsKey(1), isFalse);
      expect(g.claim!.opts[2], contains('ron'));

      g.handle(2, {'type': 'ron'});
      expect(g.isOver, isTrue);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(huEv['seat'], 2);
      expect(huEv['isYingPai'], isTrue);
    });
  });

  group('大连穷胡麻将 (dalianmj)', () {
    test('大连四门硬条件 (开门+三门齐+有横+有幺九 或 七对) 与报听亮明宝 (baoting & baoTile) / 摸宝冲宝胡 (chongbao)', () {
      // 1. 大连四门硬条件校验：
      // (a) 未开门（0明副露且非七对） -> 不可胡
      expect(
        dalianEvaluate(h('123m456p789s222m55z'), const []),
        isNull,
        reason: '未开门的普通手牌不可胡',
      );
      // (b) 缺一门（无条子 s） -> 不可胡
      expect(
        dalianEvaluate(h('456m789m222p55z'), [Meld('chi', tileFromCode('1m'))]),
        isNull,
        reason: '不满足三门齐不可胡',
      );
      // (c) 无横牌（全顺子且将牌为数牌 55p，无刻子/杠且非字牌将） -> 不可胡
      expect(
        dalianEvaluate(h('456p789s234m55p'), [Meld('chi', tileFromCode('1m'))]),
        isNull,
        reason: '无刻子/杠且将牌非东南西北中发白，不满足有横条件',
      );
      // (d) 无幺九（全为 2..8 中张且无字牌） -> 不可胡
      expect(
        dalianEvaluate(h('456p234s345m55p'), [Meld('peng', tileFromCode('2m'))]),
        isNull,
        reason: '无 1/9 及字牌，不满足有幺九条件',
      );
      // (e) 四门硬条件齐备（已吃 123m 开门+幺九，含 m/p/s 三门，且有刻子或字牌将 55z） -> 可胡！
      final validRes = dalianEvaluate(
        h('456p789s234m55z'),
        [Meld('chi', tileFromCode('1m'))],
      );
      expect(validRes, isNotNull);
      expect(validRes!.isOpened, isTrue);
      expect(validRes.hasAllThreeSuits, isTrue);
      expect(validRes.hasHeng, isTrue);
      expect(validRes.hasYaoJiu, isTrue);

      // (f) 七对免开门直接可胡
      final qiduiRes = dalianEvaluate(h('1122m3344p5566s11z'), const []);
      expect(qiduiRes, isNotNull);
      expect(qiduiRes!.isQiDui, isTrue);

      // 2. 报听亮明宝 ('baoting' & baoTile) + 摸宝/冲宝胡 ('chongbao' 即使非普通听口也立即获胜并 +2 番)
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'allowRon': true},
        names: const ['东', '南', '西', '北'],
        bots: const [false, false, false, false],
        rng: Random(23),
      );
      final g = DalianGame(setup)..start();
      g.setBaoTile('8p'); // 明宝设为 8p

      // 庄家 (0) 已吃 123m 开门，手牌 456p 789s 111z + 4m + 9s，打出 9s 报听（正常只听 4m 单钓）
      g.melds[0] = [Meld('chi', tileFromCode('1m'), claimed: tileFromCode('1m'), from: 3)];
      g.hands[0] = h('456p789s111z4m9s');
      g.hands[1] = h('2m147m258p369s123z');
      g.hands[2] = h('147m258p369s123z');
      g.hands[3] = h('147m258p369s123z');

      expect(g.baoRevealed, isFalse);
      expect(g.view(0)['baoTile'], isNull, reason: '未报听前明宝尚未亮出');

      // 将 8p（明宝，并非庄家原本听口 4m）放入牌墙，让三家依次摸切后使庄家 (0) 摸到 8p
      g.wall.add(tileFromCode('8p')); // 第 4 张摸牌：庄家 (0) 摸到 8p
      g.wall.add(tileFromCode('2s')); // 第 3 张摸牌：北家 (3) 摸到 2s
      g.wall.add(tileFromCode('2p')); // 第 2 张摸牌：西家 (2) 摸到 2p
      g.wall.add(tileFromCode('2m')); // 第 1 张摸牌：南家 (1) 摸到 2m

      // 庄家 (0) 宣告报听打出 9s -> 立即亮出明宝 8p，且南家 (1) 摸到 2m
      g.handle(0, {'type': 'baoting', 'tile': '9s'});
      expect(g.baoting[0], isTrue);
      expect(g.baoRevealed, isTrue);
      expect(g.view(0)['baoTile'], '8p');

      g.handle(1, {'type': 'discard', 'tile': '2m'});
      g.handle(2, {'type': 'discard', 'tile': '2p'});
      g.handle(3, {'type': 'discard', 'tile': '2s'});

      expect(g.turn, 0);
      expect(g.drawn[0], tileFromCode('8p'));
      expect(g.canChongBao, isTrue, reason: '已报听玩家摸到明宝 8p，立即触发冲宝胡');

      // 庄家发动 {'type': 'chongbao'} 冲宝胡直接获胜 (+2 番)！
      g.handle(0, {'type': 'chongbao'});
      expect(g.isOver, isTrue);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(huEv['chongbao'], isTrue);
      expect(huEv['baoting'], isTrue);
      expect(huEv['baoTile'], '8p');
      // 底番(1) + 冲宝胡(2) + 报听(1) + 自摸(1) = 5 番
      expect(huEv['fan'], greaterThanOrEqualTo(5));
    });
  });

  group('甘肃兰州麻将 (gansumj)', () {
    test('翻混儿 (hunIndicator->hunTile)、甩张报听 (shuaizhang +2番/×2倍) 与豪华七对(+4)/清一色(+4)/对对胡(+2)/门清(+1)/无混硬胡(+2)', () {
      // 1. 豪华七对 (+4番) + 清一色 (+4番) + 门清 (+1番) + 无混硬胡 (+2番) + 甩张报听 (+2番, ×2) 评估校验
      final resLuxuryQing = gansuEvaluate(
        h('11112233445566m'),
        const [],
        hunTile: '7z',
        shuaizhang: true,
        selfDrawn: false,
      )!;
      expect(resLuxuryQing.isShuaizhang, isTrue);
      expect(resLuxuryQing.isHaoHuaQiDui, isTrue);
      expect(resLuxuryQing.isQiDui, isTrue);
      expect(resLuxuryQing.isQingYiSe, isTrue);
      expect(resLuxuryQing.isMenQing, isTrue);
      expect(resLuxuryQing.isYingHu, isTrue);
      // 底番(1) + 甩张报听(2) + 豪华七对(4) + 清一色(4) + 门清(1) + 无混硬胡(2) = 14 番
      expect(resLuxuryQing.fan, 14);

      // 2. 对对胡 (+2番) + 混儿百搭代牌校验（软胡，isYingHu == false）
      final resSoftPeng = gansuEvaluate(
        h('111m222p333s44z55m7z'),
        const [],
        hunTile: '7z',
        shuaizhang: false,
        selfDrawn: false,
      )!;
      expect(resSoftPeng.isPengPeng, isTrue);
      expect(resSoftPeng.isMenQing, isTrue);
      expect(resSoftPeng.isYingHu, isFalse);
      // 底番(1) + 对对胡(2) + 门清(1) = 4 番
      expect(resSoftPeng.fan, 4);

      // 3. 甩张报听对局流程验证：宣告 {'type': 'shuaizhang', 'tile': d} 锁手 + 胡牌 +2 番且 ×2 倍结算
      final setup = GameSetup(
        players: 4,
        options: const {'rounds': 1, 'allowRon': true},
        names: const ['东', '南', '西', '北'],
        bots: const [false, false, false, false],
        rng: Random(31),
      );
      final g = GansuGame(setup)..start();
      g.setHunIndicator('6z'); // hunTile = '7z'
      expect(g.hunTile, '7z');

      // 庄家 (0) 手握豪华七对听牌型 1111m 2233p 4455s 6s + 9p，甩张打出 9p 听 6s
      g.hands[0] = h('1111m2233p4455s6s9p');
      g.hands[1] = h('6s147m258p369s1234z');
      g.hands[2] = h('147m258p369s1234z');
      g.hands[3] = h('147m258p369s1234z');

      expect(g.canShuaizhang(0), isTrue);
      expect(g.shuaizhangTiles(0), contains(tileFromCode('9p')));

      g.handle(0, {'type': 'shuaizhang', 'tile': '9p'});
      expect(g.shuaizhang[0], isTrue);
      expect(g.turn, 1);

      // 下家 (1) 打出 6s 点炮 -> 庄家 (0) 荣和（豪华七对+4 · 甩张报听+2 · 无混硬胡+2 · 门清+1 · 底番1 = 10番，×2倍 = 20分）
      g.handle(1, {'type': 'discard', 'tile': '6s'});
      expect(g.phase, 'claim');
      g.handle(0, {'type': 'ron'});

      expect(g.isOver, isTrue);
      final huEv = (g.settle!['events'] as List).firstWhere((e) => e['kind'] == 'hu');
      expect(huEv['shuaizhang'], isTrue);
      expect(huEv['isHaoHuaQiDui'], isTrue);
      expect(huEv['isYingHu'], isTrue);
      expect(huEv['isMenQing'], isTrue);
      expect(huEv['fan'], 10);
      expect(huEv['total'], 20);
      expect(g.scores[0], 20);
      expect(g.scores[1], -20);
    });
  });

  test('simulate all mahjong12 games (count: 30)', () {
    expect(runSims(mahjong12Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
