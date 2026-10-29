import 'dart:math';

import '../../src/engine.dart';

class BazaarSite {
  final int index;
  final String id;
  final String name;
  final String desc;

  const BazaarSite(this.index, this.id, this.name, this.desc);

  Map<String, dynamic> toJson() => {
        'index': index,
        'id': id,
        'name': name,
        'desc': desc,
      };
}

const List<String> istanbulGoodNames = ['红布', '绿香料', '蓝丝绸', '黄水果'];
const List<String> istanbulGoodIcons = ['🧣', '🌿', '🧵', '🍋'];

const List<BazaarSite> istanbulLocations = [
  BazaarSite(0, 'wainwright', '制车厂', '扩充货车容量+1（满5格送1💎红宝石）'),
  BazaarSite(1, 'fabric', '布行', '将🧣红布装满至货车上限'),
  BazaarSite(2, 'spice', '香料行', '将🌿绿香料装满至货车上限'),
  BazaarSite(3, 'silk', '丝绸行', '将🧵蓝丝绸装满至货车上限'),
  BazaarSite(4, 'post', '邮局', '获得 +3里拉 与 +1件紧缺货物'),
  BazaarSite(5, 'fountain', '喷泉', '免费召回所有散落在巴扎的助手'),
  BazaarSite(6, 'fruit', '水果行', '每种货物各 +1（不超过货车容量）'),
  BazaarSite(7, 'teahouse', '茶馆', '获得 +6里拉'),
  BazaarSite(8, 'large_market', '大市场', '高价出售最多4件货物换取里拉'),
  BazaarSite(9, 'small_market', '小市场', '出售最多4件货物换取里拉'),
  BazaarSite(10, 'small_mosque', '小清真寺', '献上1货物获清真寺板块奖励与 +1💎'),
  BazaarSite(11, 'great_mosque', '大清真寺', '献上1货物获额外助手板块与 +1💎'),
  BazaarSite(12, 'palace', '苏丹王宫', '用货物进贡苏丹换取 +1💎红宝石'),
  BazaarSite(13, 'gem_dealer', '宝石商', '支付里拉购买 +1💎红宝石'),
  BazaarSite(14, 'caravanserai', '商队旅馆', '获得 +2件货物与 +2里拉'),
  BazaarSite(15, 'black_market', '黑市', '获得 +1🧵蓝丝绸、+1🍋黄水果与 +3里拉'),
];

class IstanbulGame extends GameEngine {
  static const int fountainLoc = 5;

  late int targetRubies;
  int turn = 0;
  int round = 1;
  bool endTriggered = false;
  String phase = 'play'; // 'play' | 'over'

  List<BazaarSite> board = List.of(istanbulLocations);
  late List<int> merchantPos;
  late List<int> assistants;
  late List<List<int>> droppedAssistants;
  late List<List<int>> goods; // [seat][0..3]
  late List<int> capacity;
  late List<int> lira;
  late List<int> rubies;
  late List<List<int>> claimedMosques;

  String lastAction = '巴扎开市';
  Map<String, dynamic>? result;

  IstanbulGame(super.setup);

  @override
  void start() {
    targetRubies = setup.opt<int>('rubies', 5);
    turn = 0;
    round = 1;
    endTriggered = false;
    phase = 'play';

    merchantPos = List.filled(players, fountainLoc);
    assistants = List.filled(players, 4);
    droppedAssistants = List.generate(players, (_) => <int>[]);
    goods = List.generate(players, (_) => [0, 0, 0, 0]);
    capacity = List.filled(players, 2);
    lira = [for (var s = 0; s < players; s++) 2 + s];
    rubies = List.filled(players, 0);
    claimedMosques = List.generate(players, (_) => <int>[]);

    lastAction = '巴扎开市！各位商人从喷泉出发';
    host.log(lastAction);
  }

  @override
  bool get isOver => phase == 'over';

  @override
  List<int> get waitingFor => isOver ? const [] : [turn];

  int totalGoods(int seat) => goods[seat][0] + goods[seat][1] + goods[seat][2] + goods[seat][3];

  int scoreOf(int seat) => rubies[seat] * 100 + lira[seat] * 2 + totalGoods(seat);

  @override
  List<int>? get placings => isOver ? rankByScore([for (var s = 0; s < players; s++) scoreOf(s)]) : null;

  static int manhattan(int a, int b) => ((a ~/ 4) - (b ~/ 4)).abs() + ((a % 4) - (b % 4)).abs();

  bool canMoveTo(int seat, int to) {
    if (to < 0 || to >= 16) return false;
    final from = merchantPos[seat];
    if (to == from) return false;
    final d = manhattan(from, to);
    if (d < 1 || d > 2) {
      // Allow emergency recall to fountain if no 1..2 step move is legal
      if (to == fountainLoc && !_hasAnyStandardMove(seat)) return true;
      return false;
    }
    if (to == fountainLoc) return true;
    if (droppedAssistants[seat].contains(to)) return true;
    return assistants[seat] >= 1;
  }

  bool _hasAnyStandardMove(int seat) {
    final from = merchantPos[seat];
    for (var loc = 0; loc < 16; loc++) {
      final d = manhattan(from, loc);
      if (d >= 1 && d <= 2) {
        if (loc == fountainLoc || droppedAssistants[seat].contains(loc) || assistants[seat] >= 1) {
          return true;
        }
      }
    }
    return false;
  }

  List<int> legalMoves(int seat) => [
        for (var loc = 0; loc < 16; loc++)
          if (canMoveTo(seat, loc)) loc
      ];

  void _addGood(int seat, int g, int amount) {
    goods[seat][g] = min(capacity[seat], goods[seat][g] + amount);
  }

  void _removeGoods(int seat, int count) {
    var rem = count;
    for (var pass = 0; pass < 4 && rem > 0; pass++) {
      for (var g = 3; g >= 0 && rem > 0; g--) {
        if (goods[seat][g] > 0) {
          goods[seat][g]--;
          rem--;
        }
      }
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');
    final type = asStr(action['type']);
    if (type != 'move') throw GameError('未知操作: $type');

    final to = asInt(action['to'], -1);
    if (to < 0 || to >= 16) throw GameError('无效的巴扎地点');
    final from = merchantPos[seat];
    if (to == from) throw GameError('商人必须移动到不同的地点');
    final d = manhattan(from, to);
    if (d < 1 || d > 2) {
      if (!(to == fountainLoc && !_hasAnyStandardMove(seat))) {
        throw GameError('商人只能正交移动 1 或 2 步');
      }
    }

    // Assistant rule
    String assistantNote;
    if (to == fountainLoc) {
      final recalled = droppedAssistants[seat].length;
      assistants[seat] += recalled;
      droppedAssistants[seat].clear();
      assistantNote = '在喷泉召回 $recalled 名助手';
    } else if (droppedAssistants[seat].contains(to)) {
      droppedAssistants[seat].remove(to);
      assistants[seat]++;
      assistantNote = '接回 1 名助手';
    } else {
      if (assistants[seat] < 1) {
        throw GameError('没有随行助手可留在目的地，请接回助手或前往喷泉');
      }
      assistants[seat]--;
      droppedAssistants[seat].add(to);
      assistantNote = '留下 1 名助手';
    }

    merchantPos[seat] = to;
    final locEffect = _executeLocation(seat, to);
    lastAction = '${name(seat)} 移至【${board[to].name}】（$assistantNote）：$locEffect';
    host.log(lastAction);

    if (rubies[seat] >= targetRubies) {
      endTriggered = true;
    }

    _advanceTurn();
  }

  String _executeLocation(int seat, int loc) {
    final site = board[loc];
    switch (site.id) {
      case 'wainwright':
        if (capacity[seat] < 5) {
          if (lira[seat] >= 2) lira[seat] -= 2;
          capacity[seat]++;
          if (capacity[seat] == 5) {
            rubies[seat]++;
            return '货车扩充至满格 5 格，获得 +1💎红宝石！';
          }
          return '货车容量扩充至 ${capacity[seat]} 格';
        }
        lira[seat] += 3;
        return '货车已满级，获得 +3里拉';

      case 'fabric':
        goods[seat][0] = capacity[seat];
        return '🧣红布装满至 ${capacity[seat]} 件';

      case 'spice':
        goods[seat][1] = capacity[seat];
        return '🌿绿香料装满至 ${capacity[seat]} 件';

      case 'silk':
        goods[seat][2] = capacity[seat];
        return '🧵蓝丝绸装满至 ${capacity[seat]} 件';

      case 'post':
        lira[seat] += 3;
        var minG = 0;
        for (var g = 1; g < 4; g++) {
          if (goods[seat][g] < goods[seat][minG]) minG = g;
        }
        _addGood(seat, minG, 1);
        return '获得 +3里拉 与 +1${istanbulGoodIcons[minG]}';

      case 'fountain':
        return '整顿商队完毕';

      case 'fruit':
        for (var g = 0; g < 4; g++) {
          _addGood(seat, g, 1);
        }
        return '四种货物各 +1';

      case 'teahouse':
        lira[seat] += 6;
        return '在茶馆博弈获得 +6里拉';

      case 'large_market':
        final sold = min(4, totalGoods(seat));
        if (sold == 0) {
          lira[seat] += 2;
          return '无货可售，打零工 +2里拉';
        }
        _removeGoods(seat, sold);
        const table = [0, 4, 9, 15, 22];
        final gain = table[sold];
        lira[seat] += gain;
        return '售出 $sold 件货物，获得 +$gain里拉';

      case 'small_market':
        final sold = min(4, totalGoods(seat));
        if (sold == 0) {
          lira[seat] += 2;
          return '无货可售，打零工 +2里拉';
        }
        _removeGoods(seat, sold);
        const table = [0, 3, 7, 12, 18];
        final gain = table[sold];
        lira[seat] += gain;
        return '售出 $sold 件货物，获得 +$gain里拉';

      case 'small_mosque':
        if (!claimedMosques[seat].contains(loc) && (totalGoods(seat) >= 1 || lira[seat] >= 2)) {
          if (totalGoods(seat) >= 1) {
            _removeGoods(seat, 1);
          } else {
            lira[seat] -= 2;
          }
          claimedMosques[seat].add(loc);
          _addGood(seat, 0, 1);
          _addGood(seat, 1, 1);
          rubies[seat]++;
          return '获得小清真寺赐福板块与 +1💎红宝石！';
        }
        _addGood(seat, 0, 1);
        return '在清真寺祈福 (+1🧣)';

      case 'great_mosque':
        if (!claimedMosques[seat].contains(loc) && (totalGoods(seat) >= 1 || lira[seat] >= 2)) {
          if (totalGoods(seat) >= 1) {
            _removeGoods(seat, 1);
          } else {
            lira[seat] -= 2;
          }
          claimedMosques[seat].add(loc);
          assistants[seat]++;
          rubies[seat]++;
          return '获得大清真寺赐福（额外助手+1）与 +1💎红宝石！';
        }
        _addGood(seat, 2, 1);
        return '在大清真寺祈福 (+1🧵)';

      case 'palace':
        final tot = totalGoods(seat);
        if (tot >= 2) {
          _removeGoods(seat, 2);
          rubies[seat]++;
          return '向苏丹进贡 2 件货物，获得 +1💎红宝石！';
        } else if (tot == 1 && lira[seat] >= 2) {
          _removeGoods(seat, 1);
          lira[seat] -= 2;
          rubies[seat]++;
          return '向苏丹进贡 1 件货物与 2 里拉，获得 +1💎红宝石！';
        }
        _addGood(seat, 3, 1);
        return '货物不足进贡，获宫廷赏赐 +1🍋';

      case 'gem_dealer':
        if (lira[seat] >= 5) {
          final cost = min(6, lira[seat]);
          lira[seat] -= cost;
          rubies[seat]++;
          return '花费 $cost 里拉购买 +1💎红宝石！';
        }
        lira[seat] += 3;
        return '里拉不足购买宝石，鉴定获利 +3里拉';

      case 'caravanserai':
        lira[seat] += 2;
        _addGood(seat, 0, 1);
        _addGood(seat, 3, 1);
        return '获得 +1🧣、+1🍋 与 +2里拉';

      case 'black_market':
        lira[seat] += 3;
        _addGood(seat, 2, 1);
        _addGood(seat, 3, 1);
        return '获得 +1🧵、+1🍋 与 +3里拉';

      default:
        return '';
    }
  }

  void _advanceTurn() {
    final next = (turn + 1) % players;
    if (next == 0) {
      if (endTriggered) {
        phase = 'over';
        final winners = <String>[];
        final p = placings!;
        for (var s = 0; s < players; s++) {
          if (p[s] == 1) winners.add(name(s));
        }
        result = {
          'winners': winners,
          'rubies': rubies,
          'lira': lira,
          'scores': [for (var s = 0; s < players; s++) scoreOf(s)],
        };
        lastAction = '巴扎闭市！获胜者：${winners.join('、')}';
        host.log(lastAction);
        return;
      }
      round++;
    }
    turn = next;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || seat != turn) return null;
    final moves = legalMoves(seat);
    if (moves.isEmpty) return {'type': 'move', 'to': fountainLoc};

    // Priority 1: Immediate Ruby locations if requirements met
    if (lira[seat] >= 6 && moves.contains(13)) {
      return {'type': 'move', 'to': 13}; // gem_dealer
    }
    if (totalGoods(seat) >= 2 && moves.contains(12)) {
      return {'type': 'move', 'to': 12}; // palace
    }
    for (final mLoc in const [10, 11]) {
      if (moves.contains(mLoc) && !claimedMosques[seat].contains(mLoc) && (totalGoods(seat) >= 1 || lira[seat] >= 2)) {
        return {'type': 'move', 'to': mLoc};
      }
    }
    if (capacity[seat] < 5 && moves.contains(0)) {
      return {'type': 'move', 'to': 0}; // wainwright
    }

    // Priority 2: If low on assistants, go to fountain or pick up a dropped assistant
    if (assistants[seat] <= 1 && moves.contains(fountainLoc) && droppedAssistants[seat].length >= 2) {
      return {'type': 'move', 'to': fountainLoc};
    }

    // Priority 3: If we have goods and can sell at market or go toward palace
    if (totalGoods(seat) >= 2) {
      if (moves.contains(8)) return {'type': 'move', 'to': 8};
      if (moves.contains(9)) return {'type': 'move', 'to': 9};
    }

    // Priority 4: Gain goods or Lira
    for (final pref in const [6, 15, 7, 1, 2, 3, 4, 14]) {
      if (moves.contains(pref)) {
        return {'type': 'move', 'to': pref};
      }
    }

    return {'type': 'move', 'to': moves[rng.nextInt(moves.length)]};
  }

  @override
  Map<String, dynamic> view(int seat) => {
        'round': round,
        'turn': turn,
        'phase': phase,
        'targetRubies': targetRubies,
        'endTriggered': endTriggered,
        'lastAction': lastAction,
        'board': [for (final b in board) b.toJson()],
        'merchantPos': merchantPos,
        'assistants': assistants,
        'droppedAssistants': droppedAssistants,
        'goods': goods,
        'capacity': capacity,
        'lira': lira,
        'rubies': rubies,
        'claimedMosques': claimedMosques,
        'legalMoves': seat >= 0 && seat < players ? legalMoves(seat) : const <int>[],
        'result': result,
      };
}
