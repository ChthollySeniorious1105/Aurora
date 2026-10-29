import 'dart:math';

import 'package:aurora_shared/games/cards5/defs.dart';
import 'package:aurora_shared/games/cards5/gwent.dart';
import 'package:aurora_shared/games/cards5/hongshi.dart';
import 'package:aurora_shared/games/cards5/sanguosha.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

List<String> cs(String s) => s.split(' ');

GameSetup _setup(int n, Map<String, dynamic> opts, {int seed = 1}) => GameSetup(
      players: n,
      options: opts,
      names: [for (var i = 0; i < n; i++) 'P$i'],
      bots: List.filled(n, true),
      rng: Random(seed),
    );

void main() {
  group('红十 (hongshi)', () {
    test('deck sizes and rank order: 红十 > 大王 > 小王 > 2 > A > K > Q > J > 黑10 > 9...', () {
      expect(hsDeckForPlayers(4).length, 52);
      expect(hsDeckForPlayers(5).length, 50);
      expect(hsDeckForPlayers(6).length, 54);
      expect(hsRank('TH'), greaterThan(hsRank('RJ')));
      expect(hsRank('TD'), greaterThan(hsRank('RJ')));
      expect(hsRank('RJ'), greaterThan(hsRank('BJ')));
      expect(hsRank('BJ'), greaterThan(hsRank('2S')));
      expect(hsRank('2S'), greaterThan(hsRank('AS')));
      expect(hsRank('JS'), greaterThan(hsRank('TS')));
      expect(hsRank('TS'), greaterThan(hsRank('9S')));
    });

    test('combo classification & beating rules (单张/对子/三张/顺子/四张炸弹/双红十王炸)', () {
      final singleRed = hsClassify(['TH'])!;
      final singleJoker = hsClassify(['RJ'])!;
      expect(singleRed.beats(singleJoker), isTrue);

      final pairBlack10 = hsClassify(cs('TS TC'))!;
      final pair9 = hsClassify(cs('9S 9H'))!;
      expect(pairBlack10.type, 'pair');
      expect(pairBlack10.beats(pair9), isTrue);

      final triple = hsClassify(cs('KS KH KD'))!;
      expect(triple.type, 'triple');

      final straight = hsClassify(cs('6S 7H 8D 9C TS'))!;
      expect(straight.type, 'straight');
      expect(hsClassify(cs('JS QH KD AC 2S')), isNull); // 2 不能进顺子

      final bomb4 = hsClassify(cs('5S 5H 5D 5C'))!;
      expect(bomb4.isBomb, isTrue);
      expect(bomb4.beats(straight), isTrue);
      expect(bomb4.beats(singleRed), isTrue);

      final redTenBomb = hsClassify(cs('TH TD'))!;
      expect(redTenBomb.type, 'red_ten_bomb');
      expect(redTenBomb.beats(bomb4), isTrue);
      expect(redTenBomb.beats(hsClassify(cs('BJ RJ'))!), isTrue);
    });

    test('declare phase (亮十 vs 暗打) and winning hand', () {
      final e = Hongshi(_setup(4, {'rounds': 1}))..start();
      e.hands = [
        cs('TH 4S'),
        cs('TD 5S'),
        cs('6S 6H'),
        cs('7S 7H'),
      ];
      e.syncRedSeats();
      e.declared = [false, false, true, true];
      expect(e.phase, 'declare');
      expect(e.waitingFor, [0, 1]);

      // 非红十玩家不能亮十
      expect(() => e.handle(2, {'type': 'liang'}), throwsA(isA<GameError>()));
      e.handle(0, {'type': 'liang'});
      e.handle(1, {'type': 'an'});
      expect(e.phase, 'play');
      expect(e.stakesMultiplier, 2);
      expect(e.turn, 0);

      // P0 出单4，P1 出单5，P2/P3 不要，P0 出 TH 走完，所有人不要后 P1 接风出 TD 走完 -> 红十方获胜
      e.handle(0, {'type': 'play', 'cards': ['4S']});
      e.handle(1, {'type': 'play', 'cards': ['5S']});
      e.handle(2, {'type': 'pass'});
      e.handle(3, {'type': 'pass'});
      e.handle(0, {'type': 'play', 'cards': ['TH']});
      e.handle(1, {'type': 'pass'});
      e.handle(2, {'type': 'pass'});
      e.handle(3, {'type': 'pass'});
      e.handle(1, {'type': 'play', 'cards': ['TD']});

      expect(e.isOver, isTrue);
      expect(e.result!['redWin'], isTrue);
      expect(e.placings, [1, 1, 3, 3]);
    });
  });

  group('三国杀 (sanguosha)', () {
    test('roles for 2..5 players & distance with +1/-1 horses', () {
      expect(sgRolesForPlayers(2), ['lord', 'rebel']);
      expect(sgRolesForPlayers(3), ['lord', 'rebel', 'spy']);
      expect(sgRolesForPlayers(4), ['lord', 'loyalist', 'rebel', 'spy']);
      expect(sgRolesForPlayers(5), ['lord', 'loyalist', 'rebel', 'rebel', 'spy']);

      final e = Sanguosha(_setup(4, {'pick': false}))..start();
      expect(e.distance(0, 1), 1);
      expect(e.distance(0, 2), 2);
      e.equips[2].plusHorse = 'plus_horse:H:13';
      expect(e.distance(0, 2), 3);
      e.equips[0].minusHorse = 'minus_horse:H:5';
      expect(e.distance(0, 2), 2);
    });

    test('basic cards (杀/闪/桃), dying rescue, and general skills (仁德/奸雄/武圣)', () {
      final e = Sanguosha(_setup(2, {'pick': false}))..start();
      e.generals = ['liubei', 'caocao'];
      e.hp = [3, 1];
      e.maxHp = [4, 4];
      e.turn = 0;
      e.phase = 'play';
      e.pending = null;
      e.hands[0] = ['sha:S:7', 'shan:D:2', 'wuzhong:H:7', 'sha:H:8'];
      e.hands[1] = ['tao:H:3'];

      // 刘备发动【仁德】给出 2 张牌，回复 1 点体力
      e.handle(0, {
        'type': 'skill',
        'skill': 'rende',
        'target': 1,
        'cards': ['shan:D:2', 'wuzhong:H:7'],
      });
      expect(e.hp[0], 4);

      // 刘备对曹操出【杀】，曹操放弃出闪进入濒死，然后自救吃【桃】并触发【奸雄】
      e.hands[1] = ['tao:H:3']; // 清掉刚收到的闪以便测试受伤害
      e.handle(0, {'type': 'play', 'card': 'sha:S:7', 'target': 1});
      expect(e.pending?.type, 'shan');
      e.handle(1, {'type': 'pass'});
      expect(e.pending?.type, 'dying');
      expect(e.hp[1], 0);

      // 濒死求桃：0号放弃，1号吃桃自救
      e.handle(0, {'type': 'pass'});
      e.handle(1, {'type': 'tao', 'card': 'tao:H:3'});
      expect(e.hp[1], 1);
      expect(e.pending, isNull);
      // 曹操【奸雄】获得了那张造成伤害的 sha:S:7
      expect(e.hands[1].contains('sha:S:7'), isTrue);
    });
  });

  group('昆特牌 (gwent)', () {
    test('mulligan, spy, tight bond, weather, horn, scorch, and best-of-3 rounds', () {
      final e = Gwent(_setup(2, {'mulligan': true}))..start();
      expect(e.phase, 'mulligan');
      expect(e.hands[0].length, 10);
      expect(e.hands[1].length, 10);

      // 完成调度
      e.handle(0, {'type': 'mulligan', 'card': e.hands[0].first});
      e.handle(0, {'type': 'done'});
      e.handle(1, {'type': 'done'});
      expect(e.phase, 'play');

      // 设置特定手牌验证间谍、同袍、天气、号角与灼烧
      e.turn = 0;
      e.hands[0] = ['dijkstra', 'blue_stripes', 'blue_stripes', 'horn', 'clear'];
      e.hands[1] = ['geralt', 'frost', 'catapult', 'scorch'];
      final deckBefore = e.decks[0].length;

      // P0 打出间谍 dijkstra (战力4，进P1近战排，P0抽2张牌)
      e.handle(0, {'type': 'play', 'card': 'dijkstra'});
      expect(e.rows[1][0], contains('dijkstra'));
      expect(e.totalPower(1), 4);
      expect(e.decks[0].length, deckBefore - 2);

      // P1 打出英雄 geralt (战力15，进P1近战排)
      e.handle(1, {'type': 'play', 'card': 'geralt'});
      expect(e.totalPower(1), 19);

      // P0 打出两张同袍 blue_stripes (4*2 + 4*2 = 16)
      e.handle(0, {'type': 'play', 'card': 'blue_stripes'});
      e.handle(1, {'type': 'play', 'card': 'catapult'}); // P1 攻城 +8 -> 27
      e.handle(0, {'type': 'play', 'card': 'blue_stripes'});
      expect(e.rowPower(0, 0), 16);

      // P1 打出刺骨冰霜 (frost)：近战非英雄基础战力变1 -> P0 蓝衣铁卫 1*2 + 1*2 = 4；P1 杰洛特仍为15，dijkstra 变1
      e.handle(1, {'type': 'play', 'card': 'frost'});
      expect(e.rowPower(0, 0), 4);
      expect(e.rowPower(1, 0), 16);

      // P0 打出晴空解除冰霜，再吹号角翻倍 (16 * 2 = 32)
      e.handle(0, {'type': 'play', 'card': 'clear'});
      expect(e.rowPower(0, 0), 16);
      e.handle(1, {'type': 'pass'}); // P1 放弃跟牌
      e.handle(0, {'type': 'play', 'card': 'horn', 'row': 0});
      expect(e.rowPower(0, 0), 32);

      // P0 放弃跟牌赢下第1局
      e.handle(0, {'type': 'pass'});
      expect(e.round, 2);
      expect(e.gems, [2, 1]);
    });
  });

  test('bot simulations (all 3 games, all player counts & options)', () {
    expect(runSims(cards5Games, n: 30), 0);
  });
}
