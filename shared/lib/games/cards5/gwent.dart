import 'dart:math';

import '../../src/engine.dart';

/// 昆特牌（Gwent）：2人三局两胜（Best-of-3）三排战术卡牌对战。
/// 三排：0 = 近战 (Melee)，1 = 远程 (Ranged)，2 = 攻城 (Siege)。

class GwCardDef {
  final String id;
  final String name;
  /// 'unit' | 'weather' | 'horn' | 'scorch'
  final String type;
  /// 0 = 近战, 1 = 远程, 2 = 攻城, -1 = 特殊/天气
  final int row;
  final int power;
  final bool hero;
  /// 'none' | 'medic' | 'spy' | 'bond' | 'scorch' | 'muster'
  final String ability;
  final String group; // 用于同袍之情 (bond) 或集结 (muster)
  final String desc;

  const GwCardDef({
    required this.id,
    required this.name,
    this.type = 'unit',
    this.row = 0,
    this.power = 0,
    this.hero = false,
    this.ability = 'none',
    this.group = '',
    this.desc = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'row': row,
        'power': power,
        'hero': hero,
        'ability': ability,
        'group': group,
        'desc': desc,
      };
}

const List<GwCardDef> kGwCatalog = [
  // 英雄单位 (Hero immunity)
  GwCardDef(id: 'geralt', name: '杰洛特', row: 0, power: 15, hero: true, desc: '英雄：不受天气、灼烧或号角影响'),
  GwCardDef(id: 'ciri', name: '希里', row: 0, power: 15, hero: true, desc: '英雄：不受天气、灼烧或号角影响'),
  GwCardDef(id: 'roche', name: '弗农·罗契', row: 0, power: 10, hero: true, desc: '英雄：北方领域近战统帅'),
  GwCardDef(id: 'philippa', name: '菲丽芭', row: 1, power: 10, hero: true, desc: '英雄：远程女术士'),
  GwCardDef(
    id: 'yennefer',
    name: '叶奈法',
    row: 1,
    power: 7,
    hero: true,
    ability: 'medic',
    desc: '英雄·医护：从墓地复活1张非英雄单位牌',
  ),
  GwCardDef(
    id: 'avallach',
    name: '阿瓦拉克',
    row: 0,
    power: 1,
    hero: true,
    ability: 'spy',
    desc: '英雄·间谍：置入对手近战排，自己抽2张牌',
  ),

  // 间谍单位 (Spy)
  GwCardDef(
    id: 'dijkstra',
    name: '迪科斯彻',
    row: 0,
    power: 4,
    ability: 'spy',
    desc: '间谍：置入对手近战排，自己抽2张牌',
  ),
  GwCardDef(
    id: 'stennis',
    name: '斯坦尼斯王子',
    row: 0,
    power: 5,
    ability: 'spy',
    desc: '间谍：置入对手近战排，自己抽2张牌',
  ),
  GwCardDef(
    id: 'thaler',
    name: '塔勒',
    row: 2,
    power: 1,
    ability: 'spy',
    desc: '间谍：置入对手攻城排，自己抽2张牌',
  ),

  // 同袍之情 (Tight Bond)
  GwCardDef(
    id: 'blue_stripes',
    name: '蓝衣铁卫',
    row: 0,
    power: 4,
    ability: 'bond',
    group: 'blue_stripes',
    desc: '同袍：同名牌在同排时战力按数量翻倍',
  ),
  GwCardDef(
    id: 'crinfrid',
    name: '巨龙猎人',
    row: 1,
    power: 5,
    ability: 'bond',
    group: 'crinfrid',
    desc: '同袍：同名牌在同排时战力按数量翻倍',
  ),
  GwCardDef(
    id: 'catapult',
    name: '投石机',
    row: 2,
    power: 8,
    ability: 'bond',
    group: 'catapult',
    desc: '同袍：同名牌在同排时战力按数量翻倍',
  ),

  // 医护单位 (Medic)
  GwCardDef(
    id: 'medic_banner',
    name: '褐旗营医护兵',
    row: 2,
    power: 5,
    ability: 'medic',
    desc: '医护：从己方墓地复活1张非英雄单位',
  ),
  GwCardDef(
    id: 'healer',
    name: '随军医师',
    row: 1,
    power: 3,
    ability: 'medic',
    desc: '医护：从己方墓地复活1张非英雄单位',
  ),

  // 集结单位 (Muster)
  GwCardDef(
    id: 'arachas',
    name: '蟹蜘蛛',
    row: 0,
    power: 4,
    ability: 'muster',
    group: 'arachas',
    desc: '集结：打出时自动从手牌与牌库召唤所有同名组单位',
  ),

  // 灼烧单位 (Scorch unit)
  GwCardDef(
    id: 'villen',
    name: '三寒鸦·金龙',
    row: 0,
    power: 7,
    ability: 'scorch',
    desc: '灼烧：摧毁对手场上战力最高的非英雄单位',
  ),

  // 普通强力单位
  GwCardDef(id: 'vesemir', name: '维瑟米尔', row: 0, power: 6, desc: '狼学派大师'),
  GwCardDef(id: 'keira', name: '凯拉·梅兹', row: 1, power: 5, desc: '北方女术士'),
  GwCardDef(id: 'sile', name: '席儿', row: 1, power: 5, desc: '科维尔女术士'),
  GwCardDef(id: 'trebuchet', name: '重型攻城槌', row: 2, power: 6, desc: '攻城器械'),
  GwCardDef(id: 'ballista', name: '重型弩炮', row: 2, power: 6, desc: '攻城器械'),

  // 天气牌 (Weather)
  GwCardDef(id: 'frost', name: '刺骨冰霜', type: 'weather', row: 0, desc: '天气：双方近战排所有非英雄单位基础战力变为1'),
  GwCardDef(id: 'fog', name: '蔽日浓雾', type: 'weather', row: 1, desc: '天气：双方远程排所有非英雄单位基础战力变为1'),
  GwCardDef(id: 'rain', name: '倾盆大雨', type: 'weather', row: 2, desc: '天气：双方攻城排所有非英雄单位基础战力变为1'),
  GwCardDef(id: 'clear', name: '晴空', type: 'weather', row: -1, desc: '天气：清除场上所有天气效果'),

  // 特殊牌 (Special)
  GwCardDef(id: 'horn', name: '指挥官号角', type: 'horn', row: -1, desc: '号角：使己方指定一排所有非英雄单位战力翻倍'),
  GwCardDef(id: 'scorch', name: '灼烧', type: 'scorch', row: -1, desc: '特殊：摧毁全场当前战力最高的所有非英雄单位'),
];

final Map<String, GwCardDef> _gwById = {for (final c in kGwCatalog) c.id: c};

String gwBaseId(String code) {
  final i = code.indexOf('#');
  return i < 0 ? code : code.substring(0, i);
}

GwCardDef gwDef(String code) =>
    _gwById[gwBaseId(code)] ??
    const GwCardDef(id: 'vesemir', name: '战士', row: 0, power: 5);

const List<String> kGwRowNames = ['近战', '远程', '攻城'];

/// 构建 26 张标准昆特牌牌组
List<String> gwBuildDeck() => [
      'geralt',
      'ciri',
      'roche',
      'philippa',
      'yennefer',
      'dijkstra',
      'stennis',
      'thaler',
      'blue_stripes',
      'blue_stripes',
      'blue_stripes',
      'crinfrid',
      'crinfrid',
      'catapult',
      'catapult',
      'medic_banner',
      'healer',
      'arachas',
      'arachas',
      'villen',
      'vesemir',
      'trebuchet',
      'frost',
      'fog',
      'rain',
      'clear',
      'horn',
      'scorch',
    ];

class Gwent extends GameEngine {
  Gwent(super.setup);

  /// 'mulligan' | 'play' | 'over'
  String phase = 'mulligan';
  int round = 1; // 1..3
  int turn = 0;

  late List<int> gems; // 每人初始 2 颗红宝石（赢2小局获胜）
  late List<List<String>> decks;
  late List<List<String>> hands;
  late List<List<String>> graveyards;

  /// rows[seat][row] (seat: 0..1, row: 0..2)
  late List<List<List<String>>> rows;
  /// horns[seat][row]
  late List<List<bool>> horns;
  /// weather[row] (0: 刺骨冰霜, 1: 蔽日浓雾, 2: 倾盆大雨)
  List<bool> weather = [false, false, false];

  List<bool> passed = [false, false];
  List<int> mulligansLeft = [2, 2];
  List<bool> mulliganDone = [false, false];

  List<Map<String, dynamic>> roundHistory = [];
  Map<String, dynamic>? result;
  int? resignedSeat;
  final List<String> log = [];

  void _log(String s) {
    log.add(s);
    if (log.length > 18) log.removeAt(0);
    host.log(s);
  }

  @override
  bool get isOver => phase == 'over';

  @override
  bool get canResign => !isOver;

  @override
  void resign(int seat) {
    if (seat < 0 || seat >= players || isOver) throw GameError('无法认输');
    resignedSeat = seat;
    gems[seat] = 0;
    phase = 'over';
    final w = 1 - seat;
    result = {
      'winner': w,
      'reason': '${name(seat)} 认输，${name(w)} 获胜！',
      'gems': List.of(gems),
      'history': roundHistory,
    };
    _log('${name(seat)} 认输，${name(w)} 赢得比赛！');
  }

  @override
  List<int>? get placings {
    if (!isOver) return null;
    if (resignedSeat != null) {
      return resignedSeat == 0 ? [2, 1] : [1, 2];
    }
    if (gems[0] != gems[1]) {
      return gems[0] > gems[1] ? [1, 2] : [2, 1];
    }
    // 宝石相同（如双双归零平局）按各小局总战力之和排名，仍相同则并列第1
    var sum0 = 0, sum1 = 0;
    for (final h in roundHistory) {
      sum0 += asInt(h['p0'], 0);
      sum1 += asInt(h['p1'], 0);
    }
    if (sum0 == sum1) return [1, 1];
    return sum0 > sum1 ? [1, 2] : [2, 1];
  }

  @override
  List<int> get waitingFor {
    if (isOver) return const [];
    if (phase == 'mulligan') {
      return [for (var s = 0; s < players; s++) if (!mulliganDone[s]) s];
    }
    return [turn];
  }

  @override
  void start() {
    gems = [2, 2];
    decks = [
      for (var s = 0; s < players; s++) shuffled(gwBuildDeck(), rng),
    ];
    hands = [
      for (var s = 0; s < players; s++) _drawFrom(s, 10),
    ];
    graveyards = [[], []];
    _resetBoard();
    round = 1;
    turn = rng.nextInt(players);

    final enableMulligan = setup.opt<bool>('mulligan', true);
    if (enableMulligan) {
      phase = 'mulligan';
      mulligansLeft = [2, 2];
      mulliganDone = [false, false];
      _log('昆特牌开局：双方各抽 10 张初始手牌，最多可调度更换 2 张手牌');
    } else {
      phase = 'play';
      mulliganDone = [true, true];
      _log('昆特牌第 1 小局开始，由 ${name(turn)} 先手');
    }
  }

  void _resetBoard() {
    rows = [
      [[], [], []],
      [[], [], []],
    ];
    horns = [
      [false, false, false],
      [false, false, false],
    ];
    weather = [false, false, false];
    passed = [false, false];
  }

  List<String> _drawFrom(int seat, int count) {
    final out = <String>[];
    for (var i = 0; i < count && decks[seat].isNotEmpty; i++) {
      out.add(decks[seat].removeLast());
    }
    return out;
  }

  /// 计算 seat 第 r 排某个单位当前的实际战力
  int unitPowerOnRow(int seat, int r, String code) {
    final d = gwDef(code);
    if (d.type != 'unit') return 0;
    if (d.hero) return d.power;
    var p = weather[r] ? min(d.power, 1) : d.power;
    if (d.ability == 'bond' && d.group.isNotEmpty) {
      final count = rows[seat][r].where((c) => gwDef(c).group == d.group && !gwDef(c).hero).length;
      if (count > 1) p *= count;
    }
    if (horns[seat][r]) p *= 2;
    return p;
  }

  int rowPower(int seat, int r) {
    var sum = 0;
    for (final c in rows[seat][r]) {
      sum += unitPowerOnRow(seat, r, c);
    }
    return sum;
  }

  int totalPower(int seat) => rowPower(seat, 0) + rowPower(seat, 1) + rowPower(seat, 2);

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (seat < 0 || seat >= players) throw GameError('无效座位');
    if (isOver) throw GameError('比赛已结束');
    final type = asStr(action['type']);

    if (phase == 'mulligan') {
      // 如果在调度阶段直接发送了 play，则自动完成调度并继续处理出牌
      if (type == 'play') {
        mulliganDone = [true, true];
        phase = 'play';
      } else {
        if (mulliganDone[seat]) throw GameError('你已完成手牌调度');
        if (type == 'done' || type == 'finishMulligan' || type == 'pass') {
          mulliganDone[seat] = true;
          _log('${name(seat)} 完成调度');
        } else if (type == 'mulligan' || type == 'swap') {
          if (mulligansLeft[seat] <= 0) throw GameError('调度次数已用完');
          final card = asStr(action['card']);
          if (!hands[seat].remove(card)) throw GameError('手牌中没有 $card');
          decks[seat].insert(0, card);
          hands[seat].addAll(_drawFrom(seat, 1));
          mulligansLeft[seat]--;
          if (mulligansLeft[seat] <= 0) mulliganDone[seat] = true;
          _log('${name(seat)} 调度更换了 1 张手牌');
        } else {
          throw GameError('请更换手牌(mulligan)或完成调度(done)');
        }
        if (mulliganDone.every((x) => x)) {
          phase = 'play';
          _log('第 $round 小局开始，由 ${name(turn)} 先手出牌');
        }
        return;
      }
    }

    if (phase != 'play') throw GameError('当前不在出牌阶段');
    if (seat != turn) throw GameError('还没轮到你行动');
    if (passed[seat]) throw GameError('你本小局已放弃跟牌');

    if (type == 'pass') {
      passed[seat] = true;
      _log('${name(seat)} 选择【放弃跟牌】（当前战力 ${totalPower(seat)}）');
      _afterAction(seat);
      return;
    }

    if (type != 'play') throw GameError('未知操作: $type');
    final card = asStr(action['card']);
    if (!hands[seat].remove(card)) throw GameError('手牌中没有 $card');
    final d = gwDef(card);

    switch (d.type) {
      case 'weather':
        _playWeather(seat, d);
        break;
      case 'horn':
        final r = asInt(action['row'], 0).clamp(0, 2);
        if (horns[seat][r]) {
          hands[seat].add(card);
          throw GameError('${kGwRowNames[r]}排已有指挥官号角');
        }
        horns[seat][r] = true;
        _log('${name(seat)} 在【${kGwRowNames[r]}排】吹响了【指挥官号角】！');
        break;
      case 'scorch':
        _log('${name(seat)} 使用了【灼烧】！');
        _scorchBattlefield();
        break;
      case 'unit':
        _playUnit(seat, card, d, action);
        break;
    }

    // 若打完后手牌为空且另一方已 pass 或常规推进，若无手牌自动在下一次轮到时或当即 pass
    if (hands[seat].isEmpty && !passed[seat]) {
      passed[seat] = true;
      _log('${name(seat)} 手牌出尽，自动结束本小局出牌');
    }
    _afterAction(seat);
  }

  void _playWeather(int seat, GwCardDef d) {
    if (d.id == 'clear') {
      weather = [false, false, false];
      _log('${name(seat)} 打出【晴空】，消除了所有天气效果！');
    } else if (d.row >= 0 && d.row <= 2) {
      weather[d.row] = true;
      _log('${name(seat)} 打出天气牌【${d.name}】，${kGwRowNames[d.row]}排受到天气影响！');
    }
  }

  void _playUnit(int seat, String card, GwCardDef d, Map<String, dynamic> action) {
    final targetRow = d.row.clamp(0, 2);
    if (d.ability == 'spy') {
      final opp = 1 - seat;
      rows[opp][targetRow].add(card);
      final drawn = _drawFrom(seat, 2);
      hands[seat].addAll(drawn);
      _log('${name(seat)} 派出间谍【${d.name}】（战力 ${d.power}）潜入 ${name(opp)} 的${kGwRowNames[targetRow]}排，并抽取 ${drawn.length} 张牌！');
      return;
    }

    rows[seat][targetRow].add(card);
    _log('${name(seat)} 在${kGwRowNames[targetRow]}排部署【${d.name}】（战力 ${d.power}）');

    if (d.ability == 'muster' && d.group.isNotEmpty) {
      final summoned = <String>[];
      // 从手牌召唤同名组
      hands[seat].removeWhere((c) {
        if (gwDef(c).group == d.group) {
          summoned.add(c);
          return true;
        }
        return false;
      });
      // 从牌库召唤同名组
      decks[seat].removeWhere((c) {
        if (gwDef(c).group == d.group) {
          summoned.add(c);
          return true;
        }
        return false;
      });
      for (final sc in summoned) {
        final sr = gwDef(sc).row.clamp(0, 2);
        rows[seat][sr].add(sc);
      }
      if (summoned.isNotEmpty) {
        _log('【${d.name}】触发【集结】，额外召唤了 ${summoned.length} 个同伴入场！');
      }
    } else if (d.ability == 'medic') {
      final revivable = graveyards[seat].where((c) => gwDef(c).type == 'unit' && !gwDef(c).hero).toList();
      if (revivable.isNotEmpty) {
        final reqRev = asStr(action['revive']);
        String chosen;
        if (reqRev.isNotEmpty && revivable.contains(reqRev)) {
          chosen = reqRev;
        } else {
          revivable.sort((a, b) => gwDef(b).power - gwDef(a).power);
          chosen = revivable.first;
        }
        graveyards[seat].remove(chosen);
        final cd = gwDef(chosen);
        final cr = cd.row.clamp(0, 2);
        rows[seat][cr].add(chosen);
        _log('【${d.name}】发动【医护】，从墓地复活了【${cd.name}】！');
      }
    } else if (d.ability == 'scorch') {
      _scorchOpponentStrongest(1 - seat);
    }
  }

  /// 全场灼烧：摧毁双方场上当前战力最高的非英雄单位
  void _scorchBattlefield() {
    var maxP = 0;
    for (var s = 0; s < players; s++) {
      for (var r = 0; r < 3; r++) {
        for (final c in rows[s][r]) {
          if (gwDef(c).hero) continue;
          final p = unitPowerOnRow(s, r, c);
          if (p > maxP) maxP = p;
        }
      }
    }
    if (maxP <= 0) {
      _log('场上没有可被【灼烧】摧毁的非英雄单位');
      return;
    }
    final destroyed = <String>[];
    for (var s = 0; s < players; s++) {
      for (var r = 0; r < 3; r++) {
        final keep = <String>[];
        for (final c in rows[s][r]) {
          if (!gwDef(c).hero && unitPowerOnRow(s, r, c) == maxP) {
            destroyed.add(gwDef(c).name);
            graveyards[s].add(c);
          } else {
            keep.add(c);
          }
        }
        rows[s][r] = keep;
      }
    }
    _log('【灼烧】摧毁了战力 $maxP 的单位：${destroyed.join('、')}');
  }

  /// 灼烧对手场上最高战力的非英雄单位（三寒鸦效果）
  void _scorchOpponentStrongest(int opp) {
    var maxP = 0;
    for (var r = 0; r < 3; r++) {
      for (final c in rows[opp][r]) {
        if (gwDef(c).hero) continue;
        final p = unitPowerOnRow(opp, r, c);
        if (p > maxP) maxP = p;
      }
    }
    if (maxP <= 0) return;
    final destroyed = <String>[];
    for (var r = 0; r < 3; r++) {
      final keep = <String>[];
      for (final c in rows[opp][r]) {
        if (!gwDef(c).hero && unitPowerOnRow(opp, r, c) == maxP) {
          destroyed.add(gwDef(c).name);
          graveyards[opp].add(c);
        } else {
          keep.add(c);
        }
      }
      rows[opp][r] = keep;
    }
    if (destroyed.isNotEmpty) {
      _log('【三寒鸦】喷吐烈焰，摧毁了 ${name(opp)} 战力 $maxP 的【${destroyed.join('、')}】！');
    }
  }

  void _afterAction(int seat) {
    final other = 1 - seat;
    if (!passed[other] && hands[other].isEmpty) {
      passed[other] = true;
    }
    if (passed[0] && passed[1]) {
      _endRound();
      return;
    }
    turn = passed[other] ? seat : other;
  }

  void _endRound() {
    final p0 = totalPower(0);
    final p1 = totalPower(1);
    int roundWinner = -1; // -1 表示平局
    if (p0 > p1) {
      roundWinner = 0;
      gems[1] = max(0, gems[1] - 1);
      _log('=== 第 $round 小局结束：${name(0)}（$p0 点）战胜 ${name(1)}（$p1 点）！ ===');
    } else if (p1 > p0) {
      roundWinner = 1;
      gems[0] = max(0, gems[0] - 1);
      _log('=== 第 $round 小局结束：${name(1)}（$p1 点）战胜 ${name(0)}（$p0 点）！ ===');
    } else {
      gems[0] = max(0, gems[0] - 1);
      gems[1] = max(0, gems[1] - 1);
      _log('=== 第 $round 小局平局（$p0 : $p1），双方各失去 1 颗红宝石！ ===');
    }

    roundHistory.add({
      'round': round,
      'p0': p0,
      'p1': p1,
      'winner': roundWinner,
    });

    // 将场上单位移入各自墓地（非英雄单位可被医护复活）
    for (var s = 0; s < players; s++) {
      for (var r = 0; r < 3; r++) {
        graveyards[s].addAll(rows[s][r]);
      }
    }

    if (gems[0] <= 0 || gems[1] <= 0 || round >= 3) {
      phase = 'over';
      int matchWinner;
      if (gems[0] != gems[1]) {
        matchWinner = gems[0] > gems[1] ? 0 : 1;
      } else {
        final pl = placings!;
        matchWinner = pl[0] == pl[1] ? -1 : (pl[0] == 1 ? 0 : 1);
      }
      final reason = matchWinner == -1
          ? '三局战罢，双方战成平手！'
          : '${name(matchWinner)} 赢得昆特牌比赛胜利！';
      result = {
        'winner': matchWinner,
        'reason': reason,
        'gems': List.of(gems),
        'history': roundHistory,
      };
      _log('*** $reason ***');
      return;
    }

    // 进入下一小局：每人抽 1 张牌，上一小局胜者先手
    round++;
    _resetBoard();
    for (var s = 0; s < players; s++) {
      hands[s].addAll(_drawFrom(s, 1));
      if (hands[s].isEmpty) passed[s] = true;
    }
    if (roundWinner >= 0) {
      turn = roundWinner;
    }
    if (passed[turn] && !passed[1 - turn]) {
      turn = 1 - turn;
    } else if (passed[0] && passed[1]) {
      _endRound();
      return;
    }
    _log('--- 第 $round 小局开始（双方各抽 1 张牌），由 ${name(turn)} 先手 ---');
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver) return null;
    if (phase == 'mulligan') {
      if (mulliganDone[seat]) return null;
      return {'type': 'done'};
    }
    if (seat != turn || passed[seat]) return null;

    final h = hands[seat];
    if (h.isEmpty) return {'type': 'pass'};

    final opp = 1 - seat;
    final myP = totalPower(seat);
    final oppP = totalPower(opp);

    // 策略 1：对手已经 pass，若我方已领先，立刻 pass 赢下小局节省手牌！
    if (passed[opp] && myP > oppP) {
      return {'type': 'pass'};
    }
    // 策略 2：若对手已 pass 且分差过大（且我还剩 2 颗红宝石），战略放弃本小局保留手牌
    if (passed[opp] && gems[seat] == 2 && oppP - myP >= 22 && round < 3) {
      return {'type': 'pass'};
    }
    // 策略 3：若我方大幅领先（>= 20 点）且还不是决胜局，可提前 pass 逼对手亏卡
    if (!passed[opp] && myP - oppP >= 22 && round < 3 && h.length <= 6) {
      return {'type': 'pass'};
    }

    // 优先打出间谍牌补充手牌（只要不是对手已 pass 且我方只差一点就能赢）
    final spies = h.where((c) => gwDef(c).ability == 'spy').toList();
    if (spies.isNotEmpty && !passed[opp]) {
      return {'type': 'play', 'card': spies.first};
    }

    // 若我方受天气压制严重且手里有晴空，打出晴空
    if (weather.any((w) => w)) {
      var weatherLoss = 0;
      for (var r = 0; r < 3; r++) {
        if (weather[r]) {
          weatherLoss += rows[seat][r].where((c) => !gwDef(c).hero).length * 4;
        }
      }
      if (weatherLoss >= 8 && h.contains('clear')) {
        return {'type': 'play', 'card': 'clear'};
      }
    }

    // 灼烧：当最高非英雄单位在对手场上时使用
    if (h.contains('scorch')) {
      var myMax = 0, oppMax = 0;
      for (var r = 0; r < 3; r++) {
        for (final c in rows[seat][r]) {
          if (!gwDef(c).hero) myMax = max(myMax, unitPowerOnRow(seat, r, c));
        }
        for (final c in rows[opp][r]) {
          if (!gwDef(c).hero) oppMax = max(oppMax, unitPowerOnRow(opp, r, c));
        }
      }
      if (oppMax >= 8 && oppMax > myMax) {
        return {'type': 'play', 'card': 'scorch'};
      }
    }

    // 号角：找己方非英雄战力之和最高且未吹号角的一排
    if (h.contains('horn')) {
      var bestRow = -1, bestVal = 0;
      for (var r = 0; r < 3; r++) {
        if (horns[seat][r]) continue;
        final val = rows[seat][r]
            .where((c) => !gwDef(c).hero)
            .fold<int>(0, (a, c) => a + unitPowerOnRow(seat, r, c));
        if (val > bestVal) {
          bestVal = val;
          bestRow = r;
        }
      }
      if (bestRow >= 0 && bestVal >= 10) {
        return {'type': 'play', 'card': 'horn', 'row': bestRow};
      }
    }

    // 优先打出单位牌（非英雄或英雄）
    final units = h.where((c) => gwDef(c).type == 'unit' && gwDef(c).ability != 'spy').toList();
    if (units.isNotEmpty) {
      units.sort((a, b) => gwDef(a).power - gwDef(b).power);
      // 决胜局出大牌，前两局优先出普通单位保留英雄
      final chosen = round == 3 ? units.last : units.first;
      return {'type': 'play', 'card': chosen};
    }

    // 若只剩特殊牌/天气牌且对手已 pass 且无法反超，直接 pass
    if (passed[opp] && myP <= oppP && units.isEmpty && spies.isEmpty) {
      return {'type': 'pass'};
    }

    // 打出剩余可用手牌（注意号角不能打在已有号角的排）
    for (final c in h) {
      final d = gwDef(c);
      if (d.type == 'horn') {
        final freeRow = [0, 1, 2].where((r) => !horns[seat][r]).firstOrNull;
        if (freeRow != null) return {'type': 'play', 'card': c, 'row': freeRow};
      } else {
        return {'type': 'play', 'card': c};
      }
    }
    return {'type': 'pass'};
  }

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players;
    return {
      'phase': phase,
      'round': round,
      'turn': turn,
      'gems': gems,
      'passed': passed,
      'mulligansLeft': mulligansLeft,
      'mulliganDone': mulliganDone,
      'hand': me ? hands[seat] : <String>[],
      'handDetails': me ? [for (final c in hands[seat]) gwDef(c).toJson()] : const [],
      'counts': [for (final h in hands) h.length],
      'deckCounts': [for (final d in decks) d.length],
      'graveyards': graveyards,
      'rows': rows,
      'rowUnitPowers': [
        for (var s = 0; s < players; s++)
          [
            for (var r = 0; r < 3; r++)
              [
                for (final c in rows[s][r])
                  {
                    ...gwDef(c).toJson(),
                    'currentPower': unitPowerOnRow(s, r, c),
                  },
              ],
          ],
      ],
      'rowPowers': [
        for (var s = 0; s < players; s++) [for (var r = 0; r < 3; r++) rowPower(s, r)],
      ],
      'totalPowers': [totalPower(0), totalPower(1)],
      'horns': horns,
      'weather': weather,
      'roundHistory': roundHistory,
      'log': log,
      'result': result,
    };
  }
}

const String gwentRules = '''
# 昆特牌（Gwent）
经典双人三局两胜制（Best-of-3）战术卡牌博弈。双方开局各抽 10 张手牌（可调度更换最多 2 张），此后仅在第 1、2 小局结束时各补抽 1 张牌——合理分配手牌资源、把握“放弃跟牌”（Pass）的时机是取胜的关键！
# 战场与三排
- 每位玩家拥有三排战场：【近战排】（Melee）、【远程排】（Ranged）、【攻城排】（Siege）。
- 每回合你必须选择“打出 1 张手牌”或选择“放弃跟牌（Pass）”。一旦放弃跟牌，本小局内你将不再出牌。
- 当双方都放弃跟牌（或手牌打光）时，本小局结算：三排总战力更高的一方赢得本小局，败方失去 1 颗红宝石（平局则双方各失 1 颗红宝石）。先赢下 2 小局（令对手失去全部 2 颗红宝石）者赢得整场比赛。
# 单位技能与特殊牌
- 英雄牌（Hero）：金色边框，拥有绝对免疫，不受任何天气牌、指挥官号角或灼烧效果影响。
- 间谍（Spy）：部署到**对手**的对应战排（为对手增加战力），但让你立即从牌库抽取 2 张牌！
- 医护（Medic）：部署时立即从己方墓地中选择并复活 1 张非英雄单位牌。
- 同袍之情（Tight Bond）：当同名同袍单位并肩处于同一排时，它们各自的战力按同名数量成倍增加（2张×2、3张×3）。
- 集结（Muster）：打出时自动将手牌与牌库中所有同名组单位一并召唤上场。
- 天气牌：【刺骨冰霜】（近战变1）、【蔽日浓雾】（远程变1）、【倾盆大雨】（攻城变1）、【晴空】（清除所有天气）。
- 指挥官号角（Horn）：使己方指定一排的所有非英雄单位战力翻倍（×2）。
- 灼烧（Scorch）：立即摧毁全场上当前战力最高的所有非英雄单位（不分敌我，需谨慎使用！）。
''';
