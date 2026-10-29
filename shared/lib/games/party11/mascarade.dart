import 'dart:math';

import '../../src/engine.dart';

class MascaradeRole {
  final int id;
  final String name;
  final String title;
  final String desc;

  const MascaradeRole(this.id, this.name, this.title, this.desc);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'title': title,
        'desc': desc,
      };
}

const List<MascaradeRole> kMascaradeRoles = [
  MascaradeRole(0, '法官', 'Judge', '拿走法院（Courthouse）中的所有罚款金币'),
  MascaradeRole(1, '主教', 'Bishop', '从最富有的对手处拿走 2 枚金币'),
  MascaradeRole(2, '国王', 'King', '从银行获得 3 枚金币'),
  MascaradeRole(3, '王后', 'Queen', '从银行获得 2 枚金币'),
  MascaradeRole(4, '小偷', 'Thief', '从左右相邻的两名玩家处各偷取 1 枚金币'),
  MascaradeRole(5, '女巫', 'Witch', '与任意一名玩家交换全部金币财富'),
  MascaradeRole(6, '老千', 'Cheat', '若已拥有 ≥10 枚金币则直接获胜；否则从银行获得 2 枚金币'),
  MascaradeRole(7, '寡妇', 'Widow', '将自己的金币从银行补足至 10 枚（已 ≥10 枚则无效果）'),
];

class MascaradeGame extends GameEngine {
  MascaradeGame(super.setup);

  late List<int> coins;
  int courthouse = 0;

  late List<int> roles; // length = players
  late List<int> centerRoles; // remaining roles out of 0..7
  late List<bool> faceUp; // starts true for round 1, then flips false

  int turn = 0;
  int turnsCount = 0;
  String phase = 'action'; // 'action' | 'challenge' | 'end'

  int claimer = -1;
  int claimedRole = -1;
  int claimTarget = -1;
  int responseTurn = -1;
  late List<bool?> responses; // null = waiting, false = pass, true = challenge

  int? peekedSeat;
  int? peekedRole;
  Map<String, int> lastRevealed = {};
  int? cheatWinner;
  String lastEvent = '';
  bool _over = false;

  @override
  bool get isOver => _over;

  @override
  void start() {
    coins = List<int>.filled(players, 6);
    courthouse = 0;
    final allRoles = shuffled([0, 1, 2, 3, 4, 5, 6, 7], rng);
    roles = allRoles.sublist(0, players);
    centerRoles = allRoles.sublist(players);
    faceUp = List<bool>.filled(players, true);
    turn = 0;
    turnsCount = 0;
    phase = 'action';
    claimer = -1;
    claimedRole = -1;
    claimTarget = -1;
    responseTurn = -1;
    responses = List<bool?>.filled(players, null);
    peekedSeat = null;
    peekedRole = null;
    lastRevealed = {};
    cheatWinner = null;
    _over = false;
    lastEvent = '舞会开始！初始角色亮明，行动后卡牌将翻为暗置。';
    host.log(lastEvent);
  }

  void _flipAllFaceDown() {
    for (var i = 0; i < players; i++) {
      faceUp[i] = false;
    }
  }

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (phase == 'action') return [turn];
    if (phase == 'challenge' && responseTurn >= 0) return [responseTurn];
    return const [];
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (!waitingFor.contains(seat)) throw GameError('还没轮到你行动');
    final type = asStr(action['type']);

    if (phase == 'action') {
      lastRevealed = {};
      if (type == 'swap') {
        final doSwap = asBool(action['doSwap']);
        final centerIdx = asInt(action['center'], -1);
        final target = asInt(action['target'], -1);

        _flipAllFaceDown();
        peekedSeat = null;
        peekedRole = null;

        if (centerIdx >= 0 && centerIdx < centerRoles.length) {
          if (doSwap) {
            final tmp = roles[seat];
            roles[seat] = centerRoles[centerIdx];
            centerRoles[centerIdx] = tmp;
          }
          lastEvent = '${name(seat)} 将自己的卡牌与中央第 ${centerIdx + 1} 张牌置于桌下进行了洗混（真换或假换未知）';
          host.log(lastEvent);
          _endTurn();
          return;
        }

        if (target < 0 || target >= players || target == seat) {
          throw GameError('请选择一名其他玩家或中央卡牌进行交换');
        }
        if (doSwap) {
          final tmp = roles[seat];
          roles[seat] = roles[target];
          roles[target] = tmp;
        }
        lastEvent = '${name(seat)} 与 ${name(target)} 在桌下洗混了身份卡（真换或假换未知）';
        host.log(lastEvent);
        _endTurn();
        return;
      }

      if (type == 'peek') {
        _flipAllFaceDown();
        peekedSeat = seat;
        peekedRole = roles[seat];
        lastEvent = '${name(seat)} 秘密查看了自己的身份卡';
        host.log(lastEvent);
        _endTurn();
        return;
      }

      if (type == 'claim') {
        final role = asInt(action['role'], -1);
        if (role < 0 || role >= kMascaradeRoles.length) {
          throw GameError('无效的角色声明');
        }
        _flipAllFaceDown();
        peekedSeat = null;
        peekedRole = null;
        claimer = seat;
        claimedRole = role;
        claimTarget = asInt(action['target'], -1);
        responses = List<bool?>.filled(players, null);
        responses[seat] = false;
        phase = 'challenge';
        responseTurn = (seat + 1) % players;
        final roleName = kMascaradeRoles[role].name;
        lastEvent = '${name(seat)} 宣称自己是【$roleName】！其他玩家可选择质疑或放行';
        host.log(lastEvent);
        return;
      }

      throw GameError('无效的操作：$type');
    }

    if (phase == 'challenge') {
      if (type != 'pass' && type != 'challenge') {
        throw GameError('请选择放行 (pass) 或质疑 (challenge)');
      }
      responses[seat] = type == 'challenge';
      if (type == 'challenge') {
        host.log('${name(seat)} 质疑：“不，我才是【${kMascaradeRoles[claimedRole].name}】！”');
      }
      // Find next player to respond
      var next = (seat + 1) % players;
      if (next == claimer) {
        _resolveClaim();
      } else {
        responseTurn = next;
      }
      return;
    }

    throw GameError('未知阶段');
  }

  void _resolveClaim() {
    final r = claimedRole;
    final roleName = kMascaradeRoles[r].name;
    final challengers = <int>[
      for (var s = 0; s < players; s++)
        if (s != claimer && responses[s] == true) s,
    ];

    if (challengers.isEmpty) {
      // Unchallenged: claimer executes role power WITHOUT revealing card!
      final msg = _executeRolePower(claimer, r);
      lastEvent = '无人质疑！${name(claimer)} 不亮牌直接发动【$roleName】：$msg';
      host.log(lastEvent);
    } else {
      // 1+ challengers: claimer and all challengers reveal their cards!
      final involved = [claimer, ...challengers];
      lastRevealed = {for (final s in involved) '$s': roles[s]};

      int? realHolder;
      final liars = <int>[];
      for (final s in involved) {
        if (roles[s] == r) {
          realHolder = s;
        } else {
          liars.add(s);
        }
      }

      // Every liar pays 1 coin to Courthouse
      for (final liar in liars) {
        if (coins[liar] > 0) {
          coins[liar] -= 1;
          courthouse += 1;
        }
      }

      final liarNames = liars.map(name).join('、');
      if (realHolder != null) {
        final msg = _executeRolePower(realHolder, r);
        lastEvent = '翻牌验证！${name(realHolder)} 才是真正的【$roleName】并发动能力（$msg）；说谎者 [$liarNames] 各向法院缴纳 1 枚金币';
      } else {
        lastEvent = '翻牌验证！无人持有【$roleName】，说谎者 [$liarNames] 各向法院缴纳 1 枚金币';
      }
      host.log(lastEvent);
    }

    _endTurn();
  }

  String _executeRolePower(int actor, int role) {
    switch (role) {
      case 0: // Judge: take all Courthouse coins
        final taken = courthouse;
        coins[actor] += taken;
        courthouse = 0;
        return '拿走法院全部 $taken 枚金币';
      case 1: // Bishop: take 2 coins from richest opponent
        var richest = -1;
        var maxC = -1;
        for (var i = 1; i < players; i++) {
          final s = (actor + i) % players;
          if (coins[s] > maxC) {
            maxC = coins[s];
            richest = s;
          }
        }
        if (claimTarget >= 0 && claimTarget < players && claimTarget != actor && coins[claimTarget] == maxC) {
          richest = claimTarget;
        }
        if (richest < 0 || maxC <= 0) return '对手均无金币可拿';
        final take = min(2, coins[richest]);
        coins[richest] -= take;
        coins[actor] += take;
        return '从最富有的 ${name(richest)} 处拿走 $take 枚金币';
      case 2: // King: +3 coins from bank
        coins[actor] += 3;
        return '从银行获得 3 枚金币';
      case 3: // Queen: +2 coins from bank
        coins[actor] += 2;
        return '从银行获得 2 枚金币';
      case 4: // Thief: steal 1 coin from left and right neighbors
        final left = (actor - 1 + players) % players;
        final right = (actor + 1) % players;
        var stolen = 0;
        if (coins[left] > 0) {
          coins[left] -= 1;
          stolen += 1;
        }
        if (right != left && coins[right] > 0) {
          coins[right] -= 1;
          stolen += 1;
        }
        coins[actor] += stolen;
        return '从左右邻座各偷取金币，共得 $stolen 枚';
      case 5: // Witch: swap fortune with a player
        var target = (actor == claimer && claimTarget >= 0 && claimTarget < players && claimTarget != actor) ? claimTarget : -1;
        if (target < 0) {
          // Pick richest other player
          var maxC = -1;
          for (var s = 0; s < players; s++) {
            if (s != actor && coins[s] > maxC) {
              maxC = coins[s];
              target = s;
            }
          }
        }
        final tmp = coins[actor];
        coins[actor] = coins[target];
        coins[target] = tmp;
        return '与 ${name(target)} 互换全部财富（现为 ${coins[actor]} 枚）';
      case 6: // Cheat: win if >= 10 coins else +2 coins
        if (coins[actor] >= 10) {
          cheatWinner = actor;
          return '已拥有 ${coins[actor]} 枚金币，直接达成老千胜利！';
        } else {
          coins[actor] += 2;
          return '金币未满 10 枚，从银行获得 2 枚金币';
        }
      case 7: // Widow: raise fortune to 10 coins
        if (coins[actor] < 10) {
          final diff = 10 - coins[actor];
          coins[actor] = 10;
          return '将财富补足至 10 枚（+$diff）';
        }
        return '已不少于 10 枚金币，财富不变';
      default:
        return '';
    }
  }

  void _endTurn() {
    turnsCount++;
    // Check game end conditions:
    // 1. Cheat immediate win
    if (cheatWinner != null) {
      _over = true;
      phase = 'end';
      return;
    }
    // 2. Any player reaches >= 13 coins or goes bankrupt (<= 0 coins)
    if (coins.any((c) => c >= 13) || coins.any((c) => c <= 0)) {
      _over = true;
      phase = 'end';
      return;
    }
    phase = 'action';
    claimer = -1;
    claimedRole = -1;
    claimTarget = -1;
    responseTurn = -1;
    turn = (turn + 1) % players;
  }

  @override
  List<int>? get placings {
    if (!_over) return null;
    if (cheatWinner != null) {
      return [
        for (var s = 0; s < players; s++) s == cheatWinner ? 1 : 2,
      ];
    }
    return rankByScore(coins);
  }

  @override
  Map<String, dynamic> view(int seat) {
    final visibleRoles = [
      for (var s = 0; s < players; s++)
        (_over || faceUp[s] || (s == seat && peekedSeat == seat)) ? roles[s] : -1,
    ];
    return {
      'phase': phase,
      'turn': turn,
      'turnsCount': turnsCount,
      'coins': coins,
      'courthouse': courthouse,
      'faceUp': faceUp,
      'visibleRoles': visibleRoles,
      'centerCount': centerRoles.length,
      'centerRoles': _over ? centerRoles : List<int>.filled(centerRoles.length, -1),
      'myRole': (seat >= 0 && seat < players) ? visibleRoles[seat] : -1,
      'peekedRole': (seat >= 0 && peekedSeat == seat) ? peekedRole : null,
      'claimer': claimer,
      'claimedRole': claimedRole,
      'claimTarget': claimTarget,
      'responseTurn': responseTurn,
      'responses': responses,
      'lastRevealed': lastRevealed,
      'cheatWinner': cheatWinner,
      'lastEvent': lastEvent,
      'rolesCatalog': [for (final r in kMascaradeRoles) r.toJson()],
      if (_over) ...{
        'allRoles': roles,
        'placings': placings,
      },
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || !waitingFor.contains(seat)) return null;

    if (phase == 'challenge') {
      // Challenge occasionally if coins > 2
      if (coins[seat] > 2 && rng.nextDouble() < 0.2) {
        return {'type': 'challenge'};
      }
      return {'type': 'pass'};
    }

    if (phase == 'action') {
      // Prefer claiming roles that advance the game quickly
      final roll = rng.nextDouble();
      if (roll < 0.15) {
        final target = (seat + 1 + rng.nextInt(players - 1)) % players;
        return {'type': 'swap', 'target': target, 'doSwap': rng.nextBool()};
      }
      if (roll < 0.25) {
        return {'type': 'peek'};
      }
      if (coins[seat] >= 10 && rng.nextDouble() < 0.6) {
        return {'type': 'claim', 'role': 6}; // Cheat
      }
      if (coins[seat] < 7 && rng.nextDouble() < 0.5) {
        return {'type': 'claim', 'role': 7}; // Widow
      }
      if (courthouse >= 3 && rng.nextDouble() < 0.6) {
        return {'type': 'claim', 'role': 0}; // Judge
      }
      final preferred = [2, 3, 1, 4, 5]; // King, Queen, Bishop, Thief, Witch
      final role = preferred[rng.nextInt(preferred.length)];
      if (role == 5) {
        var richest = (seat + 1) % players;
        for (var s = 0; s < players; s++) {
          if (s != seat && coins[s] > coins[richest]) richest = s;
        }
        return {'type': 'claim', 'role': 5, 'target': richest};
      }
      return {'type': 'claim', 'role': role};
    }

    return null;
  }
}
