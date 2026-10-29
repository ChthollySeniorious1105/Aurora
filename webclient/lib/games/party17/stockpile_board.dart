import 'package:aurora_shared/games/party17/stockpile.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class StockpileBoard extends StatefulWidget {
  final GameContext g;
  const StockpileBoard(this.g, {super.key});

  @override
  State<StockpileBoard> createState() => _StockpileBoardState();
}

class _StockpileBoardState extends State<StockpileBoard> {
  int _upPile = 0;
  int _downPile = 1;
  final List<int> _sellDraft = [0, 0, 0, 0, 0, 0];

  String _fmtShift(int s) => s >= 0 ? '+$s' : '$s';

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 6;
    final phase = v['phase'] as String? ?? 'supply';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final prices = (v['prices'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const [5, 5, 5, 5, 5, 5];
    final shares = (v['shares'] as List?) ?? const [];
    final splitShares = (v['splitShares'] as List?) ?? const [];
    final cash = (v['cash'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 20);
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 50);
    final publicCorp = (v['publicCorp'] as num?)?.toInt() ?? 0;
    final publicShift = (v['publicShift'] as num?)?.toInt() ?? 2;
    final myInsiderCorp = (v['myInsiderCorp'] as num?)?.toInt();
    final myInsiderShift = (v['myInsiderShift'] as num?)?.toInt();
    final mySupplyHand = (v['mySupplyHand'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];
    final piles = (v['piles'] as List?) ?? const [];
    final pileBidder = (v['pileBidder'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, -1);
    final pileBid = (v['pileBid'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final lastEvent = v['lastEvent'] as String? ?? '';
    final canAct = v['canAct'] == true && !g.over;

    final myShares = (g.seat >= 0 && g.seat < shares.length && shares[g.seat] is List)
        ? (shares[g.seat] as List).map((e) => (e as num).toInt()).toList()
        : const [0, 0, 0, 0, 0, 0];
    final mySplits = (g.seat >= 0 && g.seat < splitShares.length && splitShares[g.seat] is List)
        ? (splitShares[g.seat] as List).map((e) => (e as num).toInt()).toList()
        : const [0, 0, 0, 0, 0, 0];

    final phaseLabel = phase == 'supply'
        ? '1明1暗塞牌阶段'
        : (phase == 'bid' ? '股票堆竞拍阶段' : '内幕抛售与大盘结算');

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: StatusBar(
                      g.over
                          ? '股市大亨 — 终盘结算'
                          : '第 $round/$maxRounds 财年 · $phaseLabel · ${canAct ? "请执行操作" : "等待其他投资者"}',
                      highlight: canAct,
                    ),
                  ),
                  if (lastEvent.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      lastEvent,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.88)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Insider & Public Forecast Banner + 6 Corporations
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Text(
                              '📢 公开大盘预测: ${kStockCorps[publicCorp % 6].emoji}${kStockCorps[publicCorp % 6].name} (${_fmtShift(publicShift)})',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                            ),
                            if (myInsiderCorp != null && myInsiderShift != null)
                              Text(
                                '🕵️ 我的专属内幕: ${kStockCorps[myInsiderCorp % 6].emoji}${kStockCorps[myInsiderCorp % 6].name} (${_fmtShift(myInsiderShift)})',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.tertiary),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var c = 0; c < 6; c++)
                              _buildCorpTile(
                                cs: cs,
                                corp: kStockCorps[c],
                                price: c < prices.length ? prices[c] : 5,
                                myReg: c < myShares.length ? myShares[c] : 0,
                                mySplit: c < mySplits.length ? mySplits[c] : 0,
                                isPublic: publicCorp == c,
                                publicShift: publicShift,
                                isInsider: myInsiderCorp == c,
                                insiderShift: myInsiderShift ?? 0,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Stockpiles & Phase Controls
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: canAct ? cs.primary : cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📦 ${g.players} 个股票竞拍堆：',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var p = 0; p < g.players; p++)
                              _buildPileCard(
                                g: g,
                                cs: cs,
                                p: p,
                                pileData: p < piles.length && piles[p] is Map ? (piles[p] as Map) : const {},
                                bidder: p < pileBidder.length ? pileBidder[p] : -1,
                                bid: p < pileBid.length ? pileBid[p] : 0,
                                canBid: canAct && phase == 'bid' && turn == g.seat,
                              ),
                          ],
                        ),
                        if (canAct && phase == 'supply') ...[
                          const Divider(height: 16),
                          _buildSupplyControls(g, cs, mySupplyHand),
                        ],
                        if (canAct && phase == 'sell') ...[
                          const Divider(height: 16),
                          _buildSellControls(g, cs, prices, myShares),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Player Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in g.seatsFromMe())
                        g.tag(
                          s,
                          active: (phase != 'bid' || turn == s) && !g.over,
                          sub: '💵现金:\$${s < cash.length ? cash[s] : 20} · ⭐总资产:\$${s < scores.length ? scores[s] : 50}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (g.over)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(lastEvent.isNotEmpty ? lastEvent : '游戏结束'),
            ),
        ],
      ),
    );
  }

  Widget _buildCorpTile({
    required ColorScheme cs,
    required StockCorpInfo corp,
    required int price,
    required int myReg,
    required int mySplit,
    required bool isPublic,
    required int publicShift,
    required bool isInsider,
    required int insiderShift,
  }) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isInsider ? cs.tertiary : (isPublic ? cs.primary : cs.outline.withValues(alpha: 0.25)),
          width: (isInsider || isPublic) ? 1.8 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${corp.emoji}${corp.name}  \$$price',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Text(
            '我持有: 普通$myReg股 · 拆股$mySplit股',
            style: TextStyle(fontSize: 10, color: cs.onSecondaryContainer),
          ),
          if (isPublic)
            Text('📢公开预测: ${_fmtShift(publicShift)}', style: TextStyle(fontSize: 10, color: cs.primary)),
          if (isInsider)
            Text('🕵️我的内幕: ${_fmtShift(insiderShift)}', style: TextStyle(fontSize: 10, color: cs.tertiary)),
        ],
      ),
    );
  }

  Widget _buildPileCard({
    required GameContext g,
    required ColorScheme cs,
    required int p,
    required Map pileData,
    required int bidder,
    required int bid,
    required bool canBid,
  }) {
    final upCards = (pileData['up'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];
    final downCount = (pileData['downCount'] as num?)?.toInt() ?? 0;

    return Container(
      width: 175,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: canBid && bidder == -1 ? cs.primary : cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '📦 股票堆 #${p + 1}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          Text(
            '明牌: ${upCards.map(marketCardLabel).join("、")}',
            style: const TextStyle(fontSize: 10),
          ),
          Text(
            '暗牌: $downCount 张 · ${bidder >= 0 ? "最高标:${g.name(bidder)}(\$$bid)" : "暂无出价"}',
            style: const TextStyle(fontSize: 10),
          ),
          if (canBid && bidder != g.seat) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                if (bidder == -1)
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                    onPressed: () => g.act({'type': 'bid', 'pile': p, 'amount': 0}),
                    child: const Text('\$0 起拍', style: TextStyle(fontSize: 11)),
                  ),
                FilledButton(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  onPressed: () => g.act({
                    'type': 'bid',
                    'pile': p,
                    'amount': bidder == -1 ? 2 : (bid + 2).clamp(1, 25),
                  }),
                  child: Text(
                    bidder == -1 ? '出价 \$2' : '超价 \$${(bid + 2).clamp(1, 25)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSupplyControls(GameContext g, ColorScheme cs, List<int> hand) {
    final c0 = hand.isNotEmpty ? marketCardLabel(hand[0]) : '股票卡1';
    final c1 = hand.length > 1 ? marketCardLabel(hand[1]) : '股票卡2';
    final safeUp = _upPile.clamp(0, g.players - 1);
    final safeDown = _downPile.clamp(0, g.players - 1);

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '🃏 塞牌操作：明牌【$c0】→ 堆#${safeUp + 1}，暗牌【$c1】→ 堆#${safeDown + 1}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        for (var p = 0; p < g.players; p++)
          OutlinedButton(
            onPressed: () => setState(() {
              _upPile = p;
              _downPile = (p + 1) % g.players;
            }),
            child: Text('明#${p + 1}/暗#${((p + 1) % g.players) + 1}'),
          ),
        FilledButton(
          onPressed: () => g.act({'type': 'supply', 'upPile': safeUp, 'downPile': safeDown}),
          child: const Text('✅ 确认塞牌'),
        ),
      ],
    );
  }

  Widget _buildSellControls(GameContext g, ColorScheme cs, List<int> prices, List<int> myShares) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '💰 内幕抛售阶段（点击切换是否全额抛售某企业普通股，随后进入大盘涨跌结算）：',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var c = 0; c < 6; c++)
              if (c < myShares.length && myShares[c] > 0)
                FilterChip(
                  label: Text(
                    '${kStockCorps[c].emoji} 抛售 ${_sellDraft[c].clamp(0, myShares[c])}/${myShares[c]}股 (@\$${prices[c]})',
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: _sellDraft[c] > 0,
                  onSelected: (sel) {
                    setState(() {
                      _sellDraft[c] = sel ? myShares[c] : 0;
                    });
                  },
                ),
            FilledButton(
              onPressed: () => g.act({
                'type': 'sell',
                'counts': [
                  for (var c = 0; c < 6; c++)
                    _sellDraft[c].clamp(0, c < myShares.length ? myShares[c] : 0),
                ],
              }),
              child: const Text('📊 确认抛售并结算大盘'),
            ),
          ],
        ),
      ],
    );
  }
}
