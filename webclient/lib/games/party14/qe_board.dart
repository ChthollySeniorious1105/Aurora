import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class QeBoard extends StatefulWidget {
  final GameContext g;
  const QeBoard(this.g, {super.key});

  @override
  State<QeBoard> createState() => _QeBoardState();
}

class _QeBoardState extends State<QeBoard> {
  int _bidAmount = 25;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 0;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 10;
    final phase = (v['phase'] as String?) ?? 'open_bid';
    final auctioneer = (v['auctioneer'] as num?)?.toInt() ?? 0;
    final openBid = (v['openBid'] as num?)?.toInt();
    final comp = v['currentCompany'] as Map<String, dynamic>?;
    final nations = (v['nations'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
    final secretNames = (v['secretIndustryNames'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final totalSpent = (v['totalSpent'] as List?)?.map((e) => (e as num?)?.toInt()).toList() ?? const <int?>[];
    final myTotalSpent = (v['myTotalSpent'] as num?)?.toInt();
    final wonCompanies = (v['wonCompanies'] as List?)
            ?.map((l) => (l as List).cast<Map<String, dynamic>>())
            .toList() ??
        const <List<Map<String, dynamic>>>[];
    final zeroBidVp = (v['zeroBidVp'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final eliminated = (v['eliminated'] as List?)?.map((e) => e == true).toList() ?? const <bool>[];
    final lastAuction = v['lastAuction'] as Map<String, dynamic>?;
    final waiting = (v['waitingFor'] as List?)?.map((e) => (e as num).toInt()).toSet() ?? <int>{};
    final myTurn = waiting.contains(g.seat) && !g.over;

    String statusText;
    if (g.over) {
      statusText = (v['resultText'] as String?) ?? '量化宽松拍卖结束';
    } else if (phase == 'open_bid') {
      statusText = myTurn
          ? '第 ${round + 1}/$totalRounds 轮：你是本轮拍卖官，请输入公开起拍价（1~999999）！'
          : '第 ${round + 1}/$totalRounds 轮：等待拍卖官 ${g.name(auctioneer)} 公开开标…';
    } else {
      statusText = myTurn
          ? '第 ${round + 1}/$totalRounds 轮：请提交秘密暗标（出 0 可获 +2 VP 零报价克制分）！'
          : '第 ${round + 1}/$totalRounds 轮：等待其余央行提交秘密暗标…';
    }

    return Container(
      color: g.table,
      child: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusBar(statusText, highlight: myTurn),
                      if (g.seat >= 0 && g.seat < g.players)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '🏦 我的央行：${g.seat < nations.length ? "${nations[g.seat]['flag']} ${nations[g.seat]['name']}" : ""} · '
                            '秘密产业：${g.seat < secretNames.length ? secretNames[g.seat] : ""} · '
                            '累计印钞：${myTotalSpent ?? 0} 亿',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Current Company Auction Card
                  if (comp != null && !g.over)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.primary, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${comp['nationFlag']} ${comp['industryIcon']}',
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '当前竞拍企业：【${comp['name']}】',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        '所属国：${comp['nationName']} · 产业：${comp['industryName']} · 基础分：⭐ ${comp['vp']} VP',
                                        style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.8)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: cs.secondaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  openBid == null
                                      ? '🔨 拍卖官：${g.name(auctioneer)}（待开标）'
                                      : '🔨 拍卖官 ${g.name(auctioneer)} 公开起拍价：$openBid 亿',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                ),
                              ),
                            ],
                          ),

                          if (myTurn) ...[
                            const Divider(height: 16),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text('快速印钞金额：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                if (phase == 'sealed_bid')
                                  ActionChip(
                                    avatar: const Icon(Icons.shield, size: 15),
                                    label: const Text('0 亿（零报价克制 +2VP）'),
                                    onPressed: () => g.act({'type': 'sealed_bid', 'amount': 0}),
                                  ),
                                for (final preset in const [15, 30, 50, 80, 120, 200, 500])
                                  ChoiceChip(
                                    label: Text('$preset 亿'),
                                    selected: _bidAmount == preset,
                                    onSelected: (_) => setState(() => _bidAmount = preset),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                OutlinedButton(
                                  onPressed: () => setState(() => _bidAmount = (_bidAmount - 10).clamp(phase == 'open_bid' ? 1 : 0, 999999)),
                                  child: const Text('-10'),
                                ),
                                OutlinedButton(
                                  onPressed: () => setState(() => _bidAmount = (_bidAmount + 10).clamp(1, 999999)),
                                  child: const Text('+10'),
                                ),
                                OutlinedButton(
                                  onPressed: () => setState(() => _bidAmount = (_bidAmount + 50).clamp(1, 999999)),
                                  child: const Text('+50'),
                                ),
                                FilledButton.icon(
                                  onPressed: () {
                                    final amt = _bidAmount.clamp(phase == 'open_bid' ? 1 : 0, 999999);
                                    g.act({
                                      'type': phase == 'open_bid' ? 'open_bid' : 'sealed_bid',
                                      'amount': amt,
                                    });
                                  },
                                  icon: const Icon(Icons.gavel, size: 16),
                                  label: Text(
                                    phase == 'open_bid' ? '公开叫价 $_bidAmount 亿' : '秘密暗标 $_bidAmount 亿',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                  // Last Auction Banner
                  if (lastAuction != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '📣 上轮成交：【${(lastAuction['company'] as Map)['name']}】由 ${g.name((lastAuction['winner'] as num).toInt())} 中标'
                        '（公开起拍 ${lastAuction['openBid']} 亿，'
                        '成交价：${lastAuction['winBid'] != null ? "${lastAuction['winBid']} 亿" : "🔒 保密"}）',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),

                  // Players Central Bank Portfolios
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var s = 0; s < g.players; s++)
                        _buildBankCard(
                          cs,
                          g,
                          s,
                          active: waiting.contains(s),
                          isAuctioneer: s == auctioneer && !g.over,
                          nation: s < nations.length ? nations[s] : const {},
                          secretName: s < secretNames.length ? secretNames[s] : '',
                          spent: s < totalSpent.length ? totalSpent[s] : null,
                          won: s < wonCompanies.length ? wonCompanies[s] : const [],
                          zbVp: s < zeroBidVp.length ? zeroBidVp[s] : 0,
                          score: s < scores.length ? scores[s] : 0,
                          isEliminated: s < eliminated.length && eliminated[s],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (g.over)
              Align(
                alignment: Alignment.center,
                child: ResultBanner(statusText),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankCard(
    ColorScheme cs,
    GameContext g,
    int s, {
    required bool active,
    required bool isAuctioneer,
    required Map<String, dynamic> nation,
    required String secretName,
    required int? spent,
    required List<Map<String, dynamic>> won,
    required int zbVp,
    required int score,
    required bool isEliminated,
  }) {
    final spentStr = spent != null ? '$spent 亿' : '🔒 保密';
    final sub = '${nation['flag'] ?? ""} ${nation['name'] ?? ""} · 印钞:$spentStr · 分数:$score';

    return Container(
      width: 245,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isEliminated
            ? cs.errorContainer.withValues(alpha: 0.7)
            : cs.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEliminated ? cs.error : (active ? cs.primary : cs.outline.withValues(alpha: 0.3)),
          width: (active || isEliminated) ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          g.tag(
            s,
            active: active,
            sub: sub,
            size: 30,
            trailing: isEliminated
                ? const Text('💥通胀出局', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.redAccent))
                : (isAuctioneer ? const Text('🔨', style: TextStyle(fontSize: 14)) : null),
          ),
          const SizedBox(height: 4),
          Text(
            '支柱产业：$secretName · 零报价：+$zbVp VP',
            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 4),
          if (won.isEmpty)
            Text('暂无收购企业', style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)))
          else
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final c in won)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${c['nationFlag']}${c['industryIcon']}${c['name']}(${c['vp']})',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
