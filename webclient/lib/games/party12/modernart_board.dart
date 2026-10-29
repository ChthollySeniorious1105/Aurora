import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class ModernArtBoard extends StatefulWidget {
  final GameContext g;
  const ModernArtBoard(this.g, {super.key});

  @override
  State<ModernArtBoard> createState() => _ModernArtBoardState();
}

class _ModernArtBoardState extends State<ModernArtBoard> {
  int? _selectedDoublePrimaryId;
  final int _customBid = 10;
  int _customFixedPrice = 15;

  static const List<(String, Color)> _artistMeta = [
    ('莱特金属', Color(0xFF00838F)),
    ('小野洋子', Color(0xFF2E7D32)),
    ('克里斯汀', Color(0xFFC62828)),
    ('卡尔·吉特', Color(0xFFF57F17)),
    ('克里普托', Color(0xFF6A1B9A)),
  ];

  static const Map<String, String> _auctionTypeLabel = {
    'open': '公开竞拍',
    'once': '一轮竞价',
    'sealed': '暗标竞拍',
    'fixed': '一口价',
    'double': '联合双拍',
  };

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final phase = (v['phase'] as String?) ?? 'play';
    final season = (v['season'] as int?) ?? 1;
    final maxSeasons = (v['maxSeasons'] as int?) ?? 4;
    final turnSeat = (v['turnSeat'] as int?) ?? 0;
    final sellerSeat = (v['sellerSeat'] as int?) ?? 0;
    final currentBidder = (v['currentBidder'] as int?) ?? -1;
    final waiting = (v['waitingFor'] as List?)?.cast<int>() ?? const <int>[];
    final isMyTurn = g.seat >= 0 && waiting.contains(g.seat);

    final cash = (v['cash'] as List? ?? const []).cast<int>();
    final hand = (v['hand'] as List? ?? const []).cast<Map<String, dynamic>>();
    final handCounts = (v['handCounts'] as List? ?? const []).cast<int>();
    final seasonCount = (v['seasonCount'] as List? ?? const []).cast<int>();
    final cumulativeValue = (v['cumulativeValue'] as List? ?? const []).cast<int>();
    final seasonPaintings = [
      for (final l in (v['seasonPaintings'] as List? ?? const []))
        (l as List).cast<int>(),
    ];
    final activeCards = (v['activeCards'] as List? ?? const []).cast<Map<String, dynamic>>();
    final activeAuctionType = (v['activeAuctionType'] as String?) ?? 'open';
    final highBid = (v['highBid'] as int?) ?? 0;
    final highBidder = (v['highBidder'] as int?) ?? -1;
    final fixedPrice = (v['fixedPrice'] as int?) ?? 0;
    final mySealedBid = v['mySealedBid'] as int?;
    final myCash = (g.seat >= 0 && g.seat < cash.length) ? cash[g.seat] : 0;

    String statusText;
    if (g.over) {
      statusText = '现代艺术结束！全部 $maxSeasons 个赛季结算完毕';
    } else if (phase == 'play') {
      statusText = isMyTurn
          ? '第 $season/$maxSeasons 季：请从手牌中选择 1 幅画作送拍'
          : '第 $season/$maxSeasons 季：等待 ${g.name(turnSeat)} 拿出画作拍卖…';
    } else if (phase == 'set_price') {
      statusText = isMyTurn ? '一口价拍卖：请设定固定售价' : '等待拍卖师 ${g.name(sellerSeat)} 设定一口价…';
    } else if (phase == 'sealed') {
      statusText = isMyTurn ? '暗标竞拍：请秘密输入出价并提交' : '暗标竞拍：等待其他买家提交暗标…';
    } else if (phase == 'fixed') {
      statusText = isMyTurn
          ? '一口价 \$$fixedPrice：轮到你决定是否购买'
          : '一口价 \$$fixedPrice：等待 ${g.name(currentBidder)} 决定…';
    } else {
      final typeLabel = _auctionTypeLabel[phase] ?? phase;
      statusText = isMyTurn
          ? '$typeLabel（当前最高 \$$highBid）：轮到你出价或放弃'
          : '$typeLabel（当前最高 \$$highBid）：等待 ${g.name(currentBidder)} 出价…';
    }

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    StatusBar(statusText, highlight: isMyTurn),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildMarketBoard(cs, season, maxSeasons, seasonCount, cumulativeValue),
                      const SizedBox(height: 8),
                      if (phase != 'play' && !g.over) ...[
                        _buildAuctionStage(
                          cs: cs,
                          phase: phase,
                          sellerSeat: sellerSeat,
                          activeCards: activeCards,
                          activeAuctionType: activeAuctionType,
                          highBid: highBid,
                          highBidder: highBidder,
                          fixedPrice: fixedPrice,
                          mySealedBid: mySealedBid,
                          myCash: myCash,
                          isMyTurn: isMyTurn,
                        ),
                        const SizedBox(height: 8),
                      ],
                      _buildPlayersRow(cs, cash, handCounts, seasonPaintings, turnSeat, currentBidder, phase),
                      const SizedBox(height: 8),
                      if (hand.isNotEmpty)
                        _buildHandSection(cs, hand, phase == 'play' && isMyTurn),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (g.over)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(
                '现代艺术结束！',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    for (var s = 0; s < g.players; s++)
                      Text(
                        '${g.name(s)}: \$${s < cash.length ? cash[s] : 0}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMarketBoard(
    ColorScheme cs,
    int season,
    int maxSeasons,
    List<int> seasonCount,
    List<int> cumulativeValue,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '画作行情看板（第 $season / $maxSeasons 季 · 任意画家达第 5 幅立即结束本季）',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (var a = 0; a < _artistMeta.length; a++)
                Container(
                  width: 148,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: _artistMeta[a].$2.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _artistMeta[a].$2, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              _artistMeta[a].$1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: _artistMeta[a].$2,
                              ),
                            ),
                          ),
                          Text(
                            '累计 \$${a < cumulativeValue.length ? cumulativeValue[a] : 0}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text('本季:', style: TextStyle(fontSize: 11)),
                          const SizedBox(width: 4),
                          for (var i = 0; i < 5; i++)
                            Container(
                              width: 11,
                              height: 11,
                              margin: const EdgeInsets.only(right: 3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i < (a < seasonCount.length ? seasonCount[a] : 0)
                                    ? _artistMeta[a].$2
                                    : cs.outline.withValues(alpha: 0.25),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuctionStage({
    required ColorScheme cs,
    required String phase,
    required int sellerSeat,
    required List<Map<String, dynamic>> activeCards,
    required String activeAuctionType,
    required int highBid,
    required int highBidder,
    required int fixedPrice,
    required int? mySealedBid,
    required int myCash,
    required bool isMyTurn,
  }) {
    final g = widget.g;
    final minNextBid = highBid + 1;
    final effectiveBid = _customBid.clamp(minNextBid, max(minNextBid, myCash)).toInt();
    final effectiveFixed = _customFixedPrice.clamp(1, max(1, myCash)).toInt();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '当前拍品（卖家：${g.name(sellerSeat)} · ${_auctionTypeLabel[activeAuctionType] ?? activeAuctionType}）',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: cs.onPrimaryContainer),
              ),
              if (phase == 'open' || phase == 'once')
                Text(
                  highBidder >= 0 ? '最高出价：\$$highBid (${g.name(highBidder)})' : '尚无人出价 (\$0)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              if (phase == 'fixed')
                Text(
                  '一口价：\$$fixedPrice',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final c in activeCards) _buildPaintingChip(cs, c, null),
            ],
          ),
          if (isMyTurn) ...[
            const SizedBox(height: 8),
            if (phase == 'set_price')
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final preset in const [10, 20, 30, 40])
                    if (preset <= myCash)
                      ActionChip(
                        label: Text('\$$preset', style: const TextStyle(fontSize: 11)),
                        onPressed: () => setState(() => _customFixedPrice = preset),
                      ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    onPressed: () => setState(() => _customFixedPrice = max(1, effectiveFixed - 5)),
                  ),
                  Text('设定: \$$effectiveFixed', style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    onPressed: () => setState(() => _customFixedPrice = min(max(1, myCash), effectiveFixed + 5)),
                  ),
                  FilledButton(
                    onPressed: () => g.act({'type': 'set_price', 'price': effectiveFixed}),
                    child: Text('确认一口价 \$$effectiveFixed'),
                  ),
                ],
              ),
            if (phase == 'open' || phase == 'once')
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (myCash >= minNextBid) ...[
                    for (final step in const [1, 5, 10])
                      if (highBid + step <= myCash)
                        FilledButton.tonal(
                          onPressed: () => g.act({'type': 'bid', 'amount': highBid + step}),
                          child: Text('出价 \$${highBid + step}'),
                        ),
                    FilledButton(
                      onPressed: () => g.act({'type': 'bid', 'amount': effectiveBid}),
                      child: Text('出价 \$$effectiveBid'),
                    ),
                  ],
                  OutlinedButton(
                    onPressed: () => g.act({'type': 'pass'}),
                    child: const Text('放弃加价'),
                  ),
                ],
              ),
            if (phase == 'sealed')
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final preset in const [0, 10, 20, 30])
                    if (preset <= myCash)
                      FilledButton.tonal(
                        onPressed: () => g.act({'type': 'bid', 'amount': preset}),
                        child: Text('暗标 \$$preset'),
                      ),
                  FilledButton(
                    onPressed: () => g.act({'type': 'bid', 'amount': _customBid.clamp(0, myCash)}),
                    child: Text('提交暗标 \$${_customBid.clamp(0, myCash)}'),
                  ),
                ],
              ),
            if (phase == 'fixed')
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (myCash >= fixedPrice)
                    FilledButton.icon(
                      onPressed: () => g.act({'type': 'buy'}),
                      icon: const Icon(Icons.shopping_cart_checkout, size: 16),
                      label: Text('按 \$$fixedPrice 买下'),
                    ),
                  OutlinedButton(
                    onPressed: () => g.act({'type': 'pass'}),
                    child: const Text('放弃购买'),
                  ),
                ],
              ),
          ] else if (phase == 'sealed' && mySealedBid != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('你已提交暗标：\$$mySealedBid', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayersRow(
    ColorScheme cs,
    List<int> cash,
    List<int> handCounts,
    List<List<int>> seasonPaintings,
    int turnSeat,
    int currentBidder,
    String phase,
  ) {
    final g = widget.g;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var s = 0; s < g.players; s++)
          Container(
            width: 210,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (phase == 'play' ? s == turnSeat : s == currentBidder)
                    ? cs.primary
                    : cs.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                g.tag(
                  s,
                  active: phase == 'play' ? s == turnSeat : s == currentBidder,
                  size: 28,
                  sub: '💰 \$${s < cash.length ? cash[s] : 0} · 手牌 ${s < handCounts.length ? handCounts[s] : 0}',
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    for (var a = 0; a < _artistMeta.length; a++)
                      if (s < seasonPaintings.length && a < seasonPaintings[s].length && seasonPaintings[s][a] > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: _artistMeta[a].$2.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_artistMeta[a].$1}×${seasonPaintings[s][a]}',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _artistMeta[a].$2),
                          ),
                        ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHandSection(ColorScheme cs, List<Map<String, dynamic>> hand, bool canPlay) {
    final g = widget.g;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                canPlay ? '我的画作手牌（点击出牌送拍）' : '我的画作手牌',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              if (_selectedDoublePrimaryId != null && canPlay) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    final id = _selectedDoublePrimaryId!;
                    setState(() => _selectedDoublePrimaryId = null);
                    g.act({'type': 'play', 'cardId': id});
                  },
                  child: const Text('单独打出双拍卡', style: TextStyle(fontSize: 11)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final c in hand)
                _buildPaintingChip(
                  cs,
                  c,
                  canPlay ? () => _onTapHandCard(c, hand) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _onTapHandCard(Map<String, dynamic> card, List<Map<String, dynamic>> hand) {
    final g = widget.g;
    final id = (card['id'] as int?) ?? -1;
    final artist = (card['artist'] as int?) ?? 0;
    final aType = (card['auctionType'] as String?) ?? 'open';

    if (_selectedDoublePrimaryId != null) {
      if (_selectedDoublePrimaryId == id) {
        setState(() => _selectedDoublePrimaryId = null);
        g.act({'type': 'play', 'cardId': id});
        return;
      }
      final pId = _selectedDoublePrimaryId!;
      setState(() => _selectedDoublePrimaryId = null);
      g.act({'type': 'play', 'cardId': pId, 'secondCardId': id});
      return;
    }

    if (aType == 'double') {
      final hasPartner = hand.any((other) => other['id'] != id && other['artist'] == artist);
      if (hasPartner) {
        setState(() => _selectedDoublePrimaryId = id);
        return;
      }
    }
    g.act({'type': 'play', 'cardId': id});
  }

  Widget _buildPaintingChip(ColorScheme cs, Map<String, dynamic> card, VoidCallback? onTap) {
    final id = (card['id'] as int?) ?? 0;
    final artist = ((card['artist'] as int?) ?? 0).clamp(0, 4);
    final title = (card['title'] as String?) ?? '';
    final aLabel = (card['auctionLabel'] as String?) ?? '';
    final meta = _artistMeta[artist];
    final isSelectedDouble = _selectedDoublePrimaryId == id;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 128,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: isSelectedDouble ? meta.$2.withValues(alpha: 0.35) : cs.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: meta.$2, width: isSelectedDouble ? 2.5 : 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              meta.$1,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: meta.$2),
            ),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: meta.$2,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                aLabel,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
