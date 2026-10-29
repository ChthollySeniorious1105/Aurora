import '../../src/engine.dart';

const Map<String, String> raTileNames = {
  'ra': '太阳神拉 ☀️',
  'pharaoh': '法老 👑',
  'nile': '尼罗河 🌊',
  'flood': '泛滥 🌾',
  'god': '神明 🦅',
  'gold': '黄金 🪙',
  'civ_0': '文明·天文 🔭',
  'civ_1': '文明·农业 🏺',
  'civ_2': '文明·文字 📜',
  'civ_3': '文明·艺术 🎨',
  'civ_4': '文明·宗教 ⛩️',
  'mon_0': '建筑·金字塔 🔺',
  'mon_1': '建筑·方尖碑 🗼',
  'mon_2': '建筑·神庙 🏛️',
  'mon_3': '建筑·狮身人面 🦁',
  'mon_4': '建筑·神龛 🕍',
  'mon_5': '建筑·雕像 🗿',
  'mon_6': '建筑·柱廊 ⛩️',
  'mon_7': '建筑·陵墓 ⚱️',
};

const List<List<int>> _raStartingDisks = [
  [2, 5, 8, 13],
  [3, 6, 9, 12],
  [4, 7, 10, 11],
  [1, 14, 15, 16],
  [2, 7, 12, 16],
];

class RaGame extends GameEngine {
  late int totalEpochs;
  int epoch = 1;
  int turn = 0;
  String phase = 'play'; // 'play' | 'auction' | 'over'

  int raProgress = 0;
  late int raLimit;
  int centerDisk = 1;

  List<String> bag = [];
  List<String> auctionTrack = [];

  late List<List<int>> sunDisks; // face-up available disks
  late List<List<int>> usedDisks; // face-down won disks for next epoch
  late List<List<String>> tiles; // collected tiles per seat
  late List<int> score;

  // Auction state
  int auctioneer = -1;
  bool voluntaryAuction = false;
  List<int> bidders = [];
  int bidderIdx = 0;
  int highestBid = 0;
  int highestBidder = -1;

  String lastAction = '太阳船启航';
  Map<String, dynamic>? result;

  RaGame(super.setup);

  @override
  void start() {
    totalEpochs = setup.opt<int>('epochs', 3);
    epoch = 1;
    phase = 'play';
    raProgress = 0;
    raLimit = 5 + players;
    centerDisk = 1;

    final disksPerPlayer = players <= 3 ? 4 : 3;
    final pool = [for (var d = 2; d <= 16; d++) d];
    sunDisks = List.generate(players, (s) {
      if (players <= 3 && s < 3) {
        return List<int>.of(_raStartingDisks[s]);
      }
      return [
        for (var k = 0; k < disksPerPlayer; k++) pool[(s + k * players) % pool.length]
      ]..sort();
    });
    usedDisks = List.generate(players, (_) => <int>[]);
    tiles = List.generate(players, (_) => <String>[]);
    score = List.filled(players, 10); // Standard Ra starts with 10 VP in tablets

    // Player with highest sun disk starts
    turn = 0;
    var bestMax = -1;
    for (var s = 0; s < players; s++) {
      for (final d in sunDisks[s]) {
        if (d > bestMax) {
          bestMax = d;
          turn = s;
        }
      }
    }

    _buildBag();
    auctionTrack = [];
    lastAction = '第 1 纪元开始，轮到 ${name(turn)} 行动';
    host.log(lastAction);
  }

  void _buildBag() {
    final raw = <String>[
      for (var i = 0; i < 18; i++) 'ra',
      for (var i = 0; i < 16; i++) 'pharaoh',
      for (var i = 0; i < 16; i++) 'nile',
      for (var i = 0; i < 10; i++) 'flood',
      for (var i = 0; i < 8; i++) 'god',
      for (var i = 0; i < 5; i++) 'gold',
      for (var c = 0; c < 5; c++)
        for (var i = 0; i < 5; i++) 'civ_$c',
      for (var m = 0; m < 8; m++)
        for (var i = 0; i < 4; i++) 'mon_$m',
    ];
    bag = shuffled(raw, rng);
  }

  @override
  bool get isOver => phase == 'over';

  @override
  List<int> get waitingFor => isOver ? const [] : [turn];

  @override
  List<int>? get placings => isOver ? rankByScore(score) : null;

  static int scoreCivilization(int distinctCount) {
    const table = [-5, -5, 0, 5, 10, 15];
    return table[distinctCount.clamp(0, 5)];
  }

  static int scoreMonuments(List<String> playerTiles) {
    final counts = List.filled(8, 0);
    for (final t in playerTiles) {
      if (t.startsWith('mon_')) {
        final idx = int.tryParse(t.substring(4)) ?? -1;
        if (idx >= 0 && idx < 8) counts[idx]++;
      }
    }
    var pts = 0;
    final distinct = counts.where((c) => c > 0).length;
    if (distinct == 8) {
      pts += 15;
    } else if (distinct == 7) {
      pts += 10;
    } else {
      pts += distinct;
    }
    for (final c in counts) {
      if (c >= 5) {
        pts += 15;
      } else if (c == 4) {
        pts += 10;
      } else if (c == 3) {
        pts += 5;
      }
    }
    return pts;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');
    final type = asStr(action['type']);

    if (phase == 'play') {
      if (type == 'draw') {
        if (auctionTrack.length >= 8) {
          throw GameError('拍卖行已满（8张），必须召唤拉神发起拍卖');
        }
        if (bag.isEmpty) {
          _endEpoch();
          return;
        }
        final tile = bag.removeLast();
        if (tile == 'ra') {
          raProgress++;
          if (raProgress >= raLimit) {
            lastAction = '${name(seat)} 抽到【太阳神拉】，太阳船抵达终点，第 $epoch 纪元立即结束！';
            host.log(lastAction);
            _endEpoch();
            return;
          }
          lastAction = '${name(seat)} 抽到【太阳神拉】（进度 $raProgress/$raLimit），触发拍卖！';
          host.log(lastAction);
          _startAuction(seat, voluntary: false);
        } else {
          auctionTrack.add(tile);
          lastAction = '${name(seat)} 抽取了【${raTileNames[tile] ?? tile}】放入拍卖行';
          _advancePlayTurn(seat);
        }
        return;
      }

      if (type == 'invoke_ra') {
        lastAction = '${name(seat)} 主动高呼“拉！”，发起拍卖！';
        host.log(lastAction);
        _startAuction(seat, voluntary: true);
        return;
      }

      throw GameError('当前阶段只能抽牌(draw)或召唤拉神(invoke_ra)');
    }

    if (phase == 'auction') {
      if (type == 'bid') {
        final d = asInt(action['disk'], -1);
        if (!sunDisks[seat].contains(d)) {
          throw GameError('你没有该太阳圆盘($d)');
        }
        if (d <= highestBid) {
          throw GameError('出价必须高于当前最高出价($highestBid)');
        }
        highestBid = d;
        highestBidder = seat;
        lastAction = '${name(seat)} 出价太阳圆盘【$d】';
        _advanceAuction();
        return;
      }

      if (type == 'pass') {
        lastAction = '${name(seat)} 跳过竞拍';
        _advanceAuction();
        return;
      }

      throw GameError('竞拍阶段只能出价(bid)或跳过(pass)');
    }

    throw GameError('未知阶段: $phase');
  }

  void _startAuction(int triggerSeat, {required bool voluntary}) {
    auctioneer = triggerSeat;
    voluntaryAuction = voluntary;
    bidders = [];
    for (var i = 1; i <= players; i++) {
      final s = (triggerSeat + i) % players;
      if (sunDisks[s].isNotEmpty) {
        bidders.add(s);
      }
    }
    if (bidders.isEmpty) {
      _endEpoch();
      return;
    }
    phase = 'auction';
    bidderIdx = 0;
    highestBid = 0;
    highestBidder = -1;
    turn = bidders[0];
  }

  void _advanceAuction() {
    bidderIdx++;
    if (bidderIdx < bidders.length) {
      turn = bidders[bidderIdx];
      return;
    }

    // Auction finished
    if (highestBidder != -1) {
      final w = highestBidder;
      final wonCount = auctionTrack.length;
      tiles[w].addAll(auctionTrack);
      auctionTrack.clear();
      sunDisks[w].remove(highestBid);
      final oldCenter = centerDisk;
      usedDisks[w].add(oldCenter);
      centerDisk = highestBid;
      lastAction = '${name(w)} 以圆盘【$highestBid】拍得 $wonCount 张板块与中央圆盘【$oldCenter】';
      host.log(lastAction);
    } else {
      if (auctionTrack.length >= 8) {
        auctionTrack.clear();
      }
      lastAction = '无人出价，流拍';
    }

    phase = 'play';
    _advancePlayTurn(auctioneer);
  }

  void _advancePlayTurn(int fromSeat) {
    for (var i = 1; i <= players; i++) {
      final s = (fromSeat + i) % players;
      if (sunDisks[s].isNotEmpty) {
        turn = s;
        return;
      }
    }
    // No player has available sun disks left -> Epoch ends!
    _endEpoch();
  }

  void _endEpoch() {
    // Score Epoch for all players
    final pharaohCounts = [
      for (var s = 0; s < players; s++) tiles[s].where((t) => t == 'pharaoh').length
    ];
    var maxP = pharaohCounts.reduce((a, b) => a > b ? a : b);
    var minP = pharaohCounts.reduce((a, b) => a < b ? a : b);

    for (var s = 0; s < players; s++) {
      var delta = 0;
      // Pharaohs
      if (maxP > minP) {
        if (pharaohCounts[s] == maxP) delta += 5;
        if (pharaohCounts[s] == minP) delta -= 2;
      }
      // Nile & Flood
      final niles = tiles[s].where((t) => t == 'nile').length;
      final floods = tiles[s].where((t) => t == 'flood').length;
      if (floods > 0) {
        delta += niles + floods;
      }
      // Gods (+2) & Gold (+3)
      final gods = tiles[s].where((t) => t == 'god').length;
      final golds = tiles[s].where((t) => t == 'gold').length;
      delta += gods * 2 + golds * 3;
      // Civilizations
      final civTypes = <String>{
        for (final t in tiles[s])
          if (t.startsWith('civ_')) t
      };
      delta += scoreCivilization(civTypes.length);

      score[s] += delta;

      // Discard temporary tiles (flood, god, gold, civ_*); keep pharaoh, nile, mon_*
      tiles[s].removeWhere(
        (t) => t == 'flood' || t == 'god' || t == 'gold' || t.startsWith('civ_'),
      );
    }

    if (epoch < totalEpochs) {
      epoch++;
      raProgress = 0;
      auctionTrack.clear();
      for (var s = 0; s < players; s++) {
        sunDisks[s].addAll(usedDisks[s]);
        sunDisks[s].sort();
        usedDisks[s].clear();
      }
      phase = 'play';
      // Highest sun disk starts the new epoch
      var bestMax = -1;
      for (var s = 0; s < players; s++) {
        for (final d in sunDisks[s]) {
          if (d > bestMax) {
            bestMax = d;
            turn = s;
          }
        }
      }
      if (bag.length < 25) _buildBag();
      lastAction = '第 ${epoch - 1} 纪元结算完成，进入第 $epoch 纪元！';
      host.log(lastAction);
      return;
    }

    // Final Epoch scoring: Monuments + Sun Disks total
    final diskSums = [
      for (var s = 0; s < players; s++)
        [...sunDisks[s], ...usedDisks[s]].fold<int>(0, (a, b) => a + b)
    ];
    final maxD = diskSums.reduce((a, b) => a > b ? a : b);
    final minD = diskSums.reduce((a, b) => a < b ? a : b);

    for (var s = 0; s < players; s++) {
      score[s] += scoreMonuments(tiles[s]);
      if (maxD > minD) {
        if (diskSums[s] == maxD) score[s] += 5;
        if (diskSums[s] == minD) score[s] -= 2;
      }
    }

    phase = 'over';
    final winners = <String>[];
    final p = placings!;
    for (var s = 0; s < players; s++) {
      if (p[s] == 1) winners.add(name(s));
    }
    result = {
      'winners': winners,
      'scores': score,
      'diskSums': diskSums,
    };
    lastAction = '三纪元终局结算完毕！获胜者：${winners.join('、')}';
    host.log(lastAction);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || seat != turn) return null;

    if (phase == 'play') {
      if (auctionTrack.length >= 8) {
        return {'type': 'invoke_ra'};
      }
      if (auctionTrack.length >= 4 && sunDisks[seat].any((d) => d >= 8)) {
        return {'type': 'invoke_ra'};
      }
      return {'type': 'draw'};
    }

    if (phase == 'auction') {
      final validDisks = [
        for (final d in sunDisks[seat])
          if (d > highestBid) d
      ]..sort();
      if (validDisks.isEmpty) return {'type': 'pass'};

      // Bid if the auction track has >= 2 tiles or centerDisk is good or voluntary
      if (auctionTrack.length >= 2 || centerDisk >= 8 || (voluntaryAuction && seat == auctioneer && highestBid == 0)) {
        return {'type': 'bid', 'disk': validDisks.first};
      }
      return {'type': 'pass'};
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) => {
        'epoch': epoch,
        'totalEpochs': totalEpochs,
        'turn': turn,
        'phase': phase,
        'raProgress': raProgress,
        'raLimit': raLimit,
        'centerDisk': centerDisk,
        'bagCount': bag.length,
        'auctionTrack': auctionTrack,
        'sunDisks': sunDisks,
        'usedDisks': usedDisks,
        'tiles': tiles,
        'score': score,
        'auctioneer': auctioneer,
        'highestBid': highestBid,
        'highestBidder': highestBidder,
        'lastAction': lastAction,
        'result': result,
      };
}
