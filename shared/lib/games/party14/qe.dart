import 'dart:math';

import '../../src/engine.dart';

const List<String> kQeNations = ['美国 US', '中国 CN', '欧盟 EU', '日本 JP', '英国 UK'];
const List<String> kQeNationFlags = ['🇺🇸', '🇨🇳', '🇪🇺', '🇯🇵', '🇬🇧'];
const List<String> kQeIndustries = ['农业', '工业', '地产', '科技', '金融'];
const List<String> kQeIndustryIcons = ['🌾', '🏭', '🏢', '💻', '🏦'];

class QeCompany {
  final int id;
  final String name;
  final int vp;
  final int nation;
  final int industry;

  const QeCompany({
    required this.id,
    required this.name,
    required this.vp,
    required this.nation,
    required this.industry,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'vp': vp,
        'nation': nation,
        'nationName': kQeNations[nation],
        'nationFlag': kQeNationFlags[nation],
        'industry': industry,
        'industryName': kQeIndustries[industry],
        'industryIcon': kQeIndustryIcons[industry],
      };
}

const List<QeCompany> _kAllCompanies = [
  QeCompany(id: 1, name: '北美谷物集团', vp: 2, nation: 0, industry: 0),
  QeCompany(id: 2, name: '硅谷量子科技', vp: 4, nation: 0, industry: 3),
  QeCompany(id: 3, name: '东方重工制造', vp: 3, nation: 1, industry: 1),
  QeCompany(id: 4, name: '神州都会置业', vp: 3, nation: 1, industry: 2),
  QeCompany(id: 5, name: '莱茵精密工业', vp: 2, nation: 2, industry: 1),
  QeCompany(id: 6, name: '欧陆联合银行', vp: 4, nation: 2, industry: 4),
  QeCompany(id: 7, name: '东京半导体社', vp: 3, nation: 3, industry: 3),
  QeCompany(id: 8, name: '北海道农产株', vp: 1, nation: 3, industry: 0),
  QeCompany(id: 9, name: '伦敦金丝雀地产', vp: 2, nation: 4, industry: 2),
  QeCompany(id: 10, name: '泰晤士皇家信托', vp: 4, nation: 4, industry: 4),
  QeCompany(id: 11, name: '华尔街投资控股', vp: 3, nation: 0, industry: 4),
  QeCompany(id: 12, name: '江南生态农业', vp: 2, nation: 1, industry: 0),
  QeCompany(id: 13, name: '塞纳河不动产', vp: 3, nation: 2, industry: 2),
  QeCompany(id: 14, name: '大阪重型机械', vp: 4, nation: 3, industry: 1),
  QeCompany(id: 15, name: '剑桥生物智能', vp: 3, nation: 4, industry: 3),
];

class QeGame extends GameEngine {
  QeGame(super.setup);

  late List<int> nations;
  late List<int> _secretIndustry;
  late List<QeCompany> companies;

  int round = 0;
  int auctioneer = 0;
  String phase = 'open_bid'; // 'open_bid' | 'sealed_bid'
  int? openBid;
  final Map<int, int> _sealedBids = {};

  late List<int> _totalSpent;
  late List<List<QeCompany>> wonCompanies;
  late List<int> zeroBidVp;
  late List<int> zeroBidCount;

  final List<Map<String, dynamic>> _history = [];
  int? lastWinner;
  int? lastAuctioneer;
  int? lastWinBid;
  int? lastOpenBid;
  QeCompany? lastCompany;

  bool _over = false;
  late List<bool> eliminated;
  late List<int> finalScores;
  late List<Map<String, dynamic>> scoreBreakdowns;
  List<int>? _placings;
  String resultText = '';

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _placings;

  @override
  void start() {
    final fast = setup.opt<String>('mode', 'standard') == 'fast';
    final count = fast ? 8 : 10;

    final natPool = shuffled([0, 1, 2, 3, 4], rng);
    final indPool = shuffled([0, 1, 2, 3, 4], rng);
    nations = [for (var s = 0; s < players; s++) natPool[s]];
    _secretIndustry = [for (var s = 0; s < players; s++) indPool[s]];

    final deck = shuffled(_kAllCompanies, rng);
    companies = deck.take(count).toList();

    _totalSpent = List<int>.filled(players, 0);
    wonCompanies = [for (var s = 0; s < players; s++) <QeCompany>[]];
    zeroBidVp = List<int>.filled(players, 0);
    zeroBidCount = List<int>.filled(players, 0);
    eliminated = List<bool>.filled(players, false);
    finalScores = List<int>.filled(players, 0);
    scoreBreakdowns = [for (var s = 0; s < players; s++) <String, dynamic>{}];
    _history.clear();

    round = 0;
    auctioneer = 0;
    phase = 'open_bid';
    openBid = null;
    _sealedBids.clear();

    host.log('量化宽松 Q.E. 开始！共拍卖 ${companies.length} 家企业，印钞无上限，但印钱最多的央行将因恶性通胀出局！');
  }

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (phase == 'open_bid') return [auctioneer];
    if (phase == 'sealed_bid') {
      return [
        for (var s = 0; s < players; s++)
          if (s != auctioneer && !_sealedBids.containsKey(s)) s,
      ];
    }
    return const [];
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'open_bid') {
      if (seat != auctioneer) throw GameError('等待本轮拍卖官开标');
      if (type != 'open_bid') throw GameError('拍卖官需要提交 open_bid');
      final amount = asInt(action['amount'], -1);
      if (amount < 1 || amount > 999999) {
        throw GameError('开标金额必须是 1..999999 之间的正整数');
      }
      openBid = amount;
      _sealedBids.clear();
      phase = 'sealed_bid';
      host.log('第 ${round + 1} 轮：拍卖官 ${name(auctioneer)} 为【${companies[round].name}】公开叫价 $amount 亿！');
      return;
    }

    if (phase == 'sealed_bid') {
      if (seat == auctioneer || seat < 0 || seat >= players) {
        throw GameError('只有非拍卖官玩家需要进行暗标出价');
      }
      if (_sealedBids.containsKey(seat)) {
        throw GameError('本轮你已提交暗标');
      }
      if (type != 'sealed_bid') throw GameError('请提交 sealed_bid');
      final amount = asInt(action['amount'], -1);
      if (amount < 0 || amount > 999999) {
        throw GameError('暗标金额必须是 0..999999 之间的整数');
      }
      _sealedBids[seat] = amount;
      if (amount == 0) {
        zeroBidCount[seat]++;
        zeroBidVp[seat] += 2;
        host.log('${name(seat)} 提交了 0 元克制报价（获得 +2 VP 零报价克制奖励）！');
      }

      if (waitingFor.isEmpty) {
        _resolveAuction();
      }
      return;
    }

    throw GameError('未知阶段或操作');
  }

  void _resolveAuction() {
    final comp = companies[round];
    var winner = auctioneer;
    var bestBid = openBid!;

    for (var offset = 1; offset < players; offset++) {
      final s = (auctioneer + offset) % players;
      final b = _sealedBids[s] ?? 0;
      if (b > bestBid) {
        bestBid = b;
        winner = s;
      }
    }

    _totalSpent[winner] += bestBid;
    wonCompanies[winner].add(comp);

    lastCompany = comp;
    lastAuctioneer = auctioneer;
    lastOpenBid = openBid;
    lastWinner = winner;
    lastWinBid = bestBid;

    _history.add({
      'round': round + 1,
      'company': comp.toJson(),
      'auctioneer': auctioneer,
      'openBid': openBid,
      'winner': winner,
      'winBid': bestBid,
    });

    host.log('【${comp.name}】（${comp.vp} VP）由 ${name(winner)} 中标收购！（成交价仅对拍卖官与中标者可见）');

    round++;
    if (round >= companies.length) {
      _finishGame();
    } else {
      auctioneer = round % players;
      phase = 'open_bid';
      openBid = null;
      _sealedBids.clear();
    }
  }

  Map<String, dynamic> _computeBreakdown(int s, {required bool isLeastSpent}) {
    final won = wonCompanies[s];
    var baseVp = 0;
    var natMatch = 0;
    var indMatch = 0;
    final indCounts = <int, int>{};

    for (final c in won) {
      baseVp += c.vp;
      if (c.nation == nations[s]) natMatch++;
      if (c.industry == _secretIndustry[s]) indMatch++;
      indCounts[c.industry] = (indCounts[c.industry] ?? 0) + 1;
    }

    const tierVp = [0, 3, 6, 10, 14];
    final natVp = tierVp[min(natMatch, 4)];
    final monoVp = tierVp[min(indMatch, 4)];

    // Diversification sets (3/4/5 distinct industries -> 4/8/12 VP per set)
    final tempCounts = Map<int, int>.of(indCounts);
    var divVp = 0;
    while (true) {
      final distinct = tempCounts.entries.where((e) => e.value > 0).map((e) => e.key).toList();
      if (distinct.length < 3) break;
      if (distinct.length >= 5) {
        divVp += 12;
      } else if (distinct.length == 4) {
        divVp += 8;
      } else {
        divVp += 4;
      }
      for (final k in distinct) {
        tempCounts[k] = tempCounts[k]! - 1;
      }
    }

    final zbVp = zeroBidVp[s];
    final leastVp = (players == 5 && isLeastSpent) ? 6 : 0;
    final total = baseVp + natVp + monoVp + divVp + zbVp + leastVp;

    return {
      'baseVp': baseVp,
      'natMatch': natMatch,
      'natVp': natVp,
      'indMatch': indMatch,
      'monoVp': monoVp,
      'divVp': divVp,
      'zeroBidVp': zbVp,
      'leastSpentVp': leastVp,
      'totalVp': total,
    };
  }

  void _finishGame() {
    _over = true;
    final maxSpent = _totalSpent.reduce(max);
    for (var s = 0; s < players; s++) {
      eliminated[s] = maxSpent > 0 && _totalSpent[s] == maxSpent;
    }

    final survivors = [
      for (var s = 0; s < players; s++)
        if (!eliminated[s]) s,
    ];
    final minSpent = survivors.isEmpty
        ? _totalSpent.reduce(min)
        : survivors.map((s) => _totalSpent[s]).reduce(min);

    for (var s = 0; s < players; s++) {
      final isLeast = !eliminated[s] && _totalSpent[s] == minSpent;
      final bd = _computeBreakdown(s, isLeastSpent: isLeast);
      scoreBreakdowns[s] = bd;
      finalScores[s] = bd['totalVp'] as int;
    }

    // Compute placings: non-eliminated players rank above eliminated players;
    // among survivors, higher finalScores (tiebreaker: lower _totalSpent) wins.
    if (survivors.isNotEmpty) {
      final composite = <num>[
        for (var s = 0; s < players; s++)
          eliminated[s]
              ? -1000000 + finalScores[s]
              : finalScores[s] * 1000000 - _totalSpent[s],
      ];
      _placings = rankByScore(composite);
    } else {
      _placings = rankByScore(finalScores);
    }

    final winSeats = [
      for (var s = 0; s < players; s++)
        if (_placings![s] == 1) name(s),
    ];
    final elimSeats = [
      for (var s = 0; s < players; s++)
        if (eliminated[s]) '${name(s)}(${_totalSpent[s]}亿)',
    ];
    resultText = '恶性通胀出局：${elimSeats.isEmpty ? "无" : elimSeats.join("、")}；最终赢家：${winSeats.join("、")}！';
    host.log('量化宽松结束！$resultText');
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || !waitingFor.contains(seat)) return null;
    final comp = companies[round];
    final matchesNat = comp.nation == nations[seat];
    final matchesInd = comp.industry == _secretIndustry[seat];
    final baseVal = comp.vp * 12 + (matchesNat ? 25 : 0) + (matchesInd ? 25 : 0);

    if (phase == 'open_bid' && seat == auctioneer) {
      final jitter = rng.nextInt(25) + 5;
      final bid = max(10, baseVal + jitter - (_totalSpent[seat] ~/ 6));
      return {'type': 'open_bid', 'amount': bid.clamp(1, 999999)};
    }

    if (phase == 'sealed_bid' && seat != auctioneer) {
      final currentOpen = openBid ?? 20;
      // If opening bid is already very high or company isn't critical for us, bid 0 for +2 VP Restraint!
      if (botLevel >= 1 && !matchesNat && !matchesInd && (currentOpen > baseVal + 15 || rng.nextDouble() < 0.35)) {
        return {'type': 'sealed_bid', 'amount': 0};
      }
      if (rng.nextDouble() < 0.25) {
        return {'type': 'sealed_bid', 'amount': 0};
      }
      final wantToWin = matchesNat || matchesInd || comp.vp >= 3;
      final bid = wantToWin
          ? currentOpen + 5 + rng.nextInt(30)
          : max(1, currentOpen - 5 + rng.nextInt(15));
      return {'type': 'sealed_bid', 'amount': bid.clamp(0, 999999)};
    }
    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final liveScores = [
      for (var s = 0; s < players; s++)
        _over
            ? finalScores[s]
            : wonCompanies[s].fold<int>(0, (a, c) => a + c.vp) + zeroBidVp[s],
    ];

    return {
      'round': round,
      'totalRounds': companies.length,
      'phase': phase,
      'auctioneer': auctioneer,
      'nations': [
        for (var s = 0; s < players; s++)
          {
            'id': nations[s],
            'name': kQeNations[nations[s]],
            'flag': kQeNationFlags[nations[s]],
          },
      ],
      'secretIndustry': [
        for (var s = 0; s < players; s++)
          (_over || seat == s) ? _secretIndustry[s] : null,
      ],
      'secretIndustryNames': [
        for (var s = 0; s < players; s++)
          (_over || seat == s)
              ? '${kQeIndustryIcons[_secretIndustry[s]]} ${kQeIndustries[_secretIndustry[s]]}'
              : '🔒 保密产业',
      ],
      'mySecretIndustry': (seat >= 0 && seat < players) ? _secretIndustry[seat] : null,
      'currentCompany': round < companies.length ? companies[round].toJson() : null,
      'openBid': openBid,
      'sealedBidSubmitted': [
        for (var s = 0; s < players; s++)
          s == auctioneer ? true : _sealedBids.containsKey(s),
      ],
      'mySealedBid': (seat >= 0 && seat < players) ? _sealedBids[seat] : null,
      'totalSpent': [
        for (var s = 0; s < players; s++)
          (_over || seat == s || (s == lastWinner && seat == lastAuctioneer))
              ? _totalSpent[s]
              : null,
      ],
      'myTotalSpent': (seat >= 0 && seat < players) ? _totalSpent[seat] : null,
      'wonCompanies': [
        for (var s = 0; s < players; s++)
          [for (final c in wonCompanies[s]) c.toJson()],
      ],
      'zeroBidVp': zeroBidVp,
      'zeroBidCount': zeroBidCount,
      'lastAuction': lastCompany == null
          ? null
          : {
              'company': lastCompany!.toJson(),
              'auctioneer': lastAuctioneer,
              'openBid': lastOpenBid,
              'winner': lastWinner,
              'winBid': (_over || seat == lastWinner || seat == lastAuctioneer)
                  ? lastWinBid
                  : null,
            },
      'history': [
        for (final h in _history)
          {
            'round': h['round'],
            'company': h['company'],
            'auctioneer': h['auctioneer'],
            'openBid': h['openBid'],
            'winner': h['winner'],
            'winBid': (_over || seat == h['winner'] || seat == h['auctioneer'])
                ? h['winBid']
                : null,
          },
      ],
      'scores': liveScores,
      'eliminated': _over ? eliminated : List<bool>.filled(players, false),
      'scoreBreakdowns': _over ? scoreBreakdowns : const <Map<String, dynamic>>[],
      'waitingFor': waitingFor,
      'over': _over,
      'resultText': resultText,
    };
  }
}
