import 'dart:math';

import '../../src/engine.dart';

const List<String> kVegasRoomNames = [
  '🎰 老虎机厅',
  '🎲 赌桌大厅',
  '🍽️ 豪华餐厅',
  '🎭 剧场秀',
  '👑 皇冠娱乐城',
];

const List<int> kVegasRoomRevenue = [2, 3, 1, 0, 0];
const List<int> kVegasRoomFame = [1, 1, 3, 4, 5];
const List<int> kVegasRoomMinBid = [1, 2, 2, 3, 4];

class VegasShowdownGame extends GameEngine {
  VegasShowdownGame(super.setup);

  int round = 1;
  int maxRounds = 8;
  String phase = 'bid'; // 'bid', 'place', 'over'
  int turn = 0;

  late List<int> cash;
  late List<int> revenue;
  late List<int> fame;

  List<int> market = [0, 1, 2, 3, 4]; // 5 Auction Tracks
  List<int> highBids = [0, 0, 0, 0, 0];
  List<int?> highBidders = [null, null, null, null, null];
  late List<bool> tookPublicity;
  late List<int?> wonRoom;

  // Personal 5x5 Casino Grid: casino[seat][r][c] = roomId (0..4) or null
  late List<List<List<int?>>> casino;
  late List<Set<String>> claimedBonuses;

  String lastEvent = '';
  bool _over = false;

  @override
  bool get isOver => _over;

  List<int> get scores => List<int>.of(fame);

  @override
  List<int>? get placings => _over ? rankByScore(scores) : null;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  void start() {
    final fast = setup.opt<String>('mode', 'standard') == 'fast';
    maxRounds = fast ? 5 : 8;
    round = 1;
    cash = List<int>.filled(players, 15);
    revenue = List<int>.filled(players, 3);
    fame = List<int>.filled(players, 0);
    casino = [
      for (var s = 0; s < players; s++)
        [
          for (var r = 0; r < 5; r++) List<int?>.filled(5, null),
        ],
    ];
    claimedBonuses = [for (var s = 0; s < players; s++) <String>{}];
    _over = false;
    _startRound(1);
    lastEvent = '🎰 赌城大亨开幕！第 1/$maxRounds 轮多轨反弹竞拍开始，轮到 ${name(turn)} 出价。';
    host.log(lastEvent);
  }

  void _startRound(int r) {
    round = r;
    phase = 'bid';
    turn = (r - 1) % players;
    market = [for (var i = 0; i < 5; i++) (i + r - 1) % 5];
    highBids = List<int>.filled(5, 0);
    highBidders = List<int?>.filled(5, null);
    tookPublicity = List<bool>.filled(players, false);
    wonRoom = List<int?>.filled(players, null);
  }

  bool _isSettled(int seat) =>
      tookPublicity[seat] || highBidders.contains(seat);

  void _advanceBidOrTransition() {
    final unsettled = [
      for (var s = 0; s < players; s++)
        if (!_isSettled(s)) s,
    ];
    if (unsettled.isNotEmpty) {
      for (var i = 1; i <= players; i++) {
        final next = (turn + i) % players;
        if (!_isSettled(next)) {
          turn = next;
          return;
        }
      }
    }

    // All players are settled! Assign won rooms to winning bidders
    for (var slot = 0; slot < 5; slot++) {
      final winner = highBidders[slot];
      if (winner != null) {
        wonRoom[winner] = market[slot];
      }
    }

    final firstPlacer = wonRoom.indexWhere((r) => r != null);
    if (firstPlacer >= 0) {
      phase = 'place';
      turn = firstPlacer;
      lastEvent = '🏗️ 竞拍完成！请得标玩家将赢得的娱乐厅板块放置到个人 5×5 赌场蓝图。';
      host.log(lastEvent);
    } else {
      _endRound();
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);

    if (phase == 'bid') {
      if (type == 'publicity' || type == 'pass') {
        tookPublicity[seat] = true;
        cash[seat] += 2;
        fame[seat] += 1;
        lastEvent = '${name(seat)} 选择公关宣传 (Publicity)，获得 +2 资金 与 +1 名望！';
        host.log(lastEvent);
        _advanceBidOrTransition();
        return;
      }

      if (type == 'bid') {
        final slot = asInt(action['slot'], -1);
        if (slot < 0 || slot >= 5) throw GameError('无效的竞拍轨道编号 (0~4)');
        if (highBidders[slot] == seat) {
          throw GameError('你已经是该轨道的最高出价者');
        }
        final bid = asInt(action['bid'], asInt(action['amount'], -1));
        final minRequired = highBids[slot] > 0 ? highBids[slot] + 1 : 1;
        if (bid < minRequired) {
          throw GameError('出价必须至少为 $minRequired');
        }
        if (bid > cash[seat]) {
          throw GameError('资金不足（当前拥有 ${cash[seat]}）');
        }

        // Pay new bid and refund previous bidder if outbid (Rebound!)
        final prevBidder = highBidders[slot];
        final prevBid = highBids[slot];
        cash[seat] -= bid;
        if (prevBidder != null) {
          cash[prevBidder] += prevBid;
        }
        highBids[slot] = bid;
        highBidders[slot] = seat;

        final roomName = kVegasRoomNames[market[slot]];
        if (prevBidder != null) {
          lastEvent =
              '💰 ${name(seat)} 在轨道 #${slot + 1}【$roomName】出价 $bid，超越并退还 ${name(prevBidder)} 的 $prevBid 资金！';
        } else {
          lastEvent =
              '💰 ${name(seat)} 在轨道 #${slot + 1}【$roomName】出价 $bid！';
        }
        host.log(lastEvent);
        _advanceBidOrTransition();
        return;
      }

      throw GameError('竞拍阶段请出价 (bid) 或选择公关宣传 (publicity)');
    }

    if (phase == 'place') {
      if (type != 'place') throw GameError('请将赢得的板块放入赌场网格 (place)');
      final room = wonRoom[seat];
      if (room == null) throw GameError('你本轮没有待放置的板块');

      final r = asInt(action['r'], -1);
      final c = asInt(action['c'], -1);
      if (r < 0 || r >= 5 || c < 0 || c >= 5) {
        throw GameError('坐标 (r, c) 必须在 0~4 之间');
      }
      if (casino[seat][r][c] != null) {
        throw GameError('该网格位置已有建筑板块');
      }

      casino[seat][r][c] = room;
      wonRoom[seat] = null;

      final revGain = kVegasRoomRevenue[room];
      var fameGain = kVegasRoomFame[room];
      revenue[seat] += revGain;

      // Check Full-Row, Full-Col, or Connected-Section (+5 Fame) Bonuses!
      var bonusDesc = '';
      if (!claimedBonuses[seat].contains('row:$r') &&
          casino[seat][r].every((cell) => cell != null)) {
        claimedBonuses[seat].add('row:$r');
        fameGain += 5;
        bonusDesc += ' + 整行贯通奖励(+5名望)';
      }
      if (!claimedBonuses[seat].contains('col:$c') &&
          [for (var rr = 0; rr < 5; rr++) casino[seat][rr][c]].every((cell) => cell != null)) {
        claimedBonuses[seat].add('col:$c');
        fameGain += 5;
        bonusDesc += ' + 整列贯通奖励(+5名望)';
      }
      if (!claimedBonuses[seat].contains('wing3') && _hasConnectedWing(seat, r, c)) {
        claimedBonuses[seat].add('wing3');
        fameGain += 5;
        bonusDesc += ' + 走廊连通专区奖励(+5名望)';
      }

      fame[seat] += fameGain;
      lastEvent =
          '🏛️ ${name(seat)} 在 ($r, $c) 建造了【${kVegasRoomNames[room]}】（+$revGain 收入, +$fameGain 名望$bonusDesc）！';
      host.log(lastEvent);

      final nextPlacer = wonRoom.indexWhere((rm) => rm != null);
      if (nextPlacer >= 0) {
        turn = nextPlacer;
      } else {
        _endRound();
      }
      return;
    }

    throw GameError('未知阶段：$phase');
  }

  bool _hasConnectedWing(int seat, int r, int c) {
    // Checks if the newly placed room at (r, c) has at least 2 orthogonal neighbors (forming a 3+ connected wing)
    var neighbors = 0;
    const dirs = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];
    for (final d in dirs) {
      final nr = r + d[0];
      final nc = c + d[1];
      if (nr >= 0 && nr < 5 && nc >= 0 && nc < 5 && casino[seat][nr][nc] != null) {
        neighbors++;
      }
    }
    return neighbors >= 2;
  }

  void _endRound() {
    if (round >= maxRounds) {
      // End of game: remaining cash gives +1 Fame per 5 Cash
      for (var s = 0; s < players; s++) {
        fame[s] += cash[s] ~/ 5;
      }
      _over = true;
      phase = 'over';
      final best = fame.reduce(max);
      final winners = [
        for (var s = 0; s < players; s++)
          if (fame[s] == best) name(s),
      ];
      lastEvent =
          '🏆 赌城大亨 $maxRounds 轮建设结束！最终赢家：${winners.join("、")}（$best 名望）！';
      host.log(lastEvent);
      return;
    }

    // Pay revenue at the start of the next round
    for (var s = 0; s < players; s++) {
      cash[s] += revenue[s];
    }
    final finishedRound = round;
    _startRound(round + 1);
    lastEvent =
        '💵 第 $finishedRound 轮结束，全员领取赌场收入！开始第 $round/$maxRounds 轮多轨竞拍。';
    host.log(lastEvent);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    if (phase == 'bid') {
      // Prefer empty tracks first, or outbid cheap tracks within budget
      for (var slot = 4; slot >= 0; slot--) {
        if (highBidders[slot] == null) {
          final b = min(cash[seat], kVegasRoomMinBid[market[slot]]);
          if (b >= 1 && cash[seat] >= b) {
            return {'type': 'bid', 'slot': slot, 'bid': b};
          }
        }
      }
      if (botLevel >= 1) {
        for (var slot = 4; slot >= 0; slot--) {
          if (highBidders[slot] != seat) {
            final nextBid = highBids[slot] + 1;
            final maxVal = 3 + kVegasRoomFame[market[slot]] + kVegasRoomRevenue[market[slot]];
            if (nextBid <= maxVal && cash[seat] >= nextBid) {
              return {'type': 'bid', 'slot': slot, 'bid': nextBid};
            }
          }
        }
      }
      return {'type': 'publicity'};
    }

    if (phase == 'place') {
      // Prefer filling row 2 or col 2 to earn Connected-Hallway / Full-Row bonuses
      for (var c = 0; c < 5; c++) {
        if (casino[seat][2][c] == null) {
          return {'type': 'place', 'r': 2, 'c': c};
        }
      }
      for (var r = 0; r < 5; r++) {
        for (var c = 0; c < 5; c++) {
          if (casino[seat][r][c] == null) {
            return {'type': 'place', 'r': r, 'c': c};
          }
        }
      }
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) => {
        'round': round,
        'maxRounds': maxRounds,
        'phase': phase,
        'turn': turn,
        'cash': List<int>.of(cash),
        'revenue': List<int>.of(revenue),
        'fame': List<int>.of(fame),
        'market': List<int>.of(market),
        'highBids': List<int>.of(highBids),
        'highBidders': List<int?>.of(highBidders),
        'tookPublicity': List<bool>.of(tookPublicity),
        'wonRoom': List<int?>.of(wonRoom),
        'casino': [
          for (var s = 0; s < players; s++)
            [
              for (var r = 0; r < 5; r++) List<int?>.of(casino[s][r]),
            ],
        ],
        'scores': scores,
        'lastEvent': lastEvent,
        'over': _over,
      };
}
