import 'package:aurora_shared/aurora_shared.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class BibliosBoard extends StatelessWidget {
  final GameContext g;
  const BibliosBoard(this.g, {super.key});

  static const List<String> _catNames = ['修士', '颜料', '经卷', '草药', '秘典'];
  static const List<IconData> _catIcons = [
    Icons.self_improvement,
    Icons.palette,
    Icons.menu_book,
    Icons.eco,
    Icons.auto_stories,
  ];
  static const List<Color> _catColors = [
    Color(0xFF8D6E63),
    Color(0xFF1E88E5),
    Color(0xFFE53935),
    Color(0xFF43A047),
    Color(0xFF8E24AA),
  ];

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final phase = asStr(v['phase'], 'gift');
    final subPhase = asStr(v['subPhase'], 'allocate');
    final turn = asInt(v['turn'], 0);
    final draftSeat = asInt(v['draftSeat'], 0);
    final churchSeat = asInt(v['churchSeat'], -1);
    final churchRem = asInt(v['churchRemaining'], 0);
    final bidSeat = asInt(v['bidSeat'], 0);
    final dice = asIntList(v['dice']);
    final deckCount = asInt(v['deckCount'], 0);
    final auctionCount = asInt(v['auctionCount'], 0);
    final keepLeft = asInt(v['keepLeft'], 0);
    final auctionLeft = asInt(v['auctionLeft'], 0);
    final publicLeft = asInt(v['publicLeft'], 0);
    final currentBid = asInt(v['currentBid'], 0);
    final highBidder = asInt(v['highBidder'], -1);
    final myGold = asInt(v['myGold'], 0);
    final maxBid = asInt(v['maxBid'], 0);
    final lastEvent = asStr(v['lastEvent']);

    final currentCard = (v['currentCard'] as Map?)?.cast<String, dynamic>();
    final publicPool = (v['publicPool'] as List?)?.cast<Map>() ?? const [];
    final auctionCard = (v['auctionCard'] as Map?)?.cast<String, dynamic>();
    final handCounts = asIntList(v['handCounts']);
    final myHand = (v['myHand'] as List?)?.cast<Map>() ?? const [];

    int activeSeat = turn;
    if (churchRem > 0 && churchSeat >= 0) {
      activeSeat = churchSeat;
    } else if (phase == 'gift') {
      activeSeat = subPhase == 'draft' ? draftSeat : turn;
    } else if (phase == 'auction') {
      activeSeat = bidSeat;
    }
    final isMyTurn = !g.over && g.seat == activeSeat;

    String statusText;
    if (g.over) {
      statusText = '藏书阁评选结束！';
    } else if (churchRem > 0 && churchSeat >= 0) {
      statusText = '主教调分：请 ${g.name(churchSeat)} 调整分类骰子（剩余 $churchRem 次）';
    } else if (phase == 'gift' && subPhase == 'allocate') {
      statusText = '第一阶段·赠予分配：轮到 ${g.name(turn)} 决定当前卡牌去向';
    } else if (phase == 'gift' && subPhase == 'draft') {
      statusText = '第一阶段·公共选牌：轮到 ${g.name(draftSeat)} 从公共池挑选 1 张牌';
    } else {
      statusText = '第二阶段·修道院拍卖：轮到 ${g.name(bidSeat)} 竞标';
    }

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
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      StatusBar(statusText, highlight: isMyTurn),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '牌库 $deckCount 张 · 拍卖堆 $auctionCount 张 · 我的金币 $myGold',
                          style: TextStyle(fontSize: 12, color: cs.onSurface),
                        ),
                      ),
                    ],
                  ),
                  if (lastEvent.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(lastEvent, style: TextStyle(fontSize: 12, color: cs.onSecondaryContainer)),
                    ),
                  ],
                  const SizedBox(height: 8),

                  // 5 Category Dice panel
                  _buildCategoryDicePanel(
                    context,
                    dice,
                    canAdjust: isMyTurn && churchRem > 0 && churchSeat == g.seat,
                  ),

                  const SizedBox(height: 8),

                  // Center stage: Gift or Auction
                  if (!g.over) ...[
                    if (phase == 'gift')
                      _buildGiftStage(
                        context,
                        subPhase: subPhase,
                        isMyAllocate: isMyTurn && churchRem == 0 && subPhase == 'allocate',
                        isMyDraft: isMyTurn && churchRem == 0 && subPhase == 'draft',
                        currentCard: currentCard,
                        publicPool: publicPool,
                        keepLeft: keepLeft,
                        auctionLeft: auctionLeft,
                        publicLeft: publicLeft,
                      )
                    else if (phase == 'auction')
                      _buildAuctionStage(
                        context,
                        auctionCard: auctionCard,
                        currentBid: currentBid,
                        highBidder: highBidder,
                        isMyBid: isMyTurn && churchRem == 0,
                        maxBid: maxBid,
                      ),
                  ],

                  const SizedBox(height: 8),

                  // My hand & category totals
                  if (!g.spectator) _buildMyHandPanel(context, myHand, myGold),

                  const SizedBox(height: 8),

                  // Players bar
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final s in g.seatsFromMe())
                        g.tag(
                          s,
                          active: !g.over && s == activeSeat,
                          size: 32,
                          sub: '手牌 ${s < handCounts.length ? handCounts[s] : 0} 张',
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
              child: _buildResultBanner(context),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryDicePanel(BuildContext context, List<int> dice, {required bool canAdjust}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: canAdjust ? Colors.amber : cs.outline.withValues(alpha: 0.3), width: canAdjust ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            canAdjust ? '⛪ 请点击 +1 或 -1 调整五大领域分值骰：' : '🎲 五大藏书领域分值骰（第一名独得对应分数）：',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: cs.onSurface),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (var c = 0; c < 5; c++)
                Container(
                  width: 132,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _catColors[c].withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _catColors[c], width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_catIcons[c], size: 15, color: _catColors[c]),
                          const SizedBox(width: 4),
                          Text(
                            _catNames[c],
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: cs.onSurface),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (canAdjust)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              icon: const Icon(Icons.remove_circle_outline, size: 18),
                              onPressed: c < dice.length && dice[c] > 1
                                  ? () => g.act({'type': 'church', 'cat': c, 'delta': -1})
                                  : null,
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: DieFace(c < dice.length ? dice[c] : 3, size: 28),
                          ),
                          if (canAdjust)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              icon: const Icon(Icons.add_circle_outline, size: 18),
                              onPressed: c < dice.length && dice[c] < 6
                                  ? () => g.act({'type': 'church', 'cat': c, 'delta': 1})
                                  : null,
                            ),
                        ],
                      ),
                      Text(
                        '价值 ${c < dice.length ? dice[c] : 3} 分',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
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

  Widget _buildGiftStage(
    BuildContext context, {
    required String subPhase,
    required bool isMyAllocate,
    required bool isMyDraft,
    required Map<String, dynamic>? currentCard,
    required List<Map> publicPool,
    required int keepLeft,
    required int auctionLeft,
    required int publicLeft,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subPhase == 'allocate' && currentCard != null) ...[
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildBibliosCard(context, currentCard),
                if (isMyAllocate)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: keepLeft > 0 ? () => g.act({'type': 'allocate', 'dest': 'keep'}) : null,
                        icon: const Icon(Icons.person, size: 16),
                        label: Text('留给自己 ($keepLeft)'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: auctionLeft > 0 ? () => g.act({'type': 'allocate', 'dest': 'auction'}) : null,
                        icon: const Icon(Icons.gavel, size: 16),
                        label: Text('暗置拍卖堆 ($auctionLeft)'),
                      ),
                      OutlinedButton.icon(
                        onPressed: publicLeft > 0 ? () => g.act({'type': 'allocate', 'dest': 'public'}) : null,
                        icon: const Icon(Icons.groups, size: 16),
                        label: Text('明置公共池 ($publicLeft)'),
                      ),
                    ],
                  ),
              ],
            ),
            const Divider(height: 16),
          ],
          Text(
            '公共展示池 (${publicPool.length} 张)${isMyDraft ? ' — 请点击挑选 1 张收入手牌' : ''}：',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: cs.onSurface),
          ),
          const SizedBox(height: 6),
          if (publicPool.isEmpty)
            Text('公共池暂无卡牌', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < publicPool.length; i++)
                  _buildBibliosCard(
                    context,
                    publicPool[i],
                    onTap: isMyDraft ? () => g.act({'type': 'draft', 'index': i}) : null,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAuctionStage(
    BuildContext context, {
    required Map<String, dynamic>? auctionCard,
    required int currentBid,
    required int highBidder,
    required bool isMyBid,
    required int maxBid,
  }) {
    final cs = Theme.of(context).colorScheme;
    if (auctionCard == null) return const SizedBox();
    final isGoldCard = auctionCard['type'] == 'gold';
    final unit = isGoldCard ? '张手牌' : '金币';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber, width: 1.5),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildBibliosCard(context, auctionCard),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🔨 当前拍品：【${auctionCard['name']}】',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: cs.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                highBidder < 0 ? '当前无人出价（起拍价 1 $unit）' : '当前最高价：$currentBid $unit（${g.name(highBidder)}）',
                style: TextStyle(fontSize: 12.5, color: cs.primary, fontWeight: FontWeight.w600),
              ),
              if (isMyBid) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final step in const [1, 2, 3])
                      if (currentBid + step <= maxBid)
                        FilledButton(
                          onPressed: () => g.act({'type': 'bid', 'amount': currentBid + step}),
                          child: Text('出价 ${currentBid + step} $unit'),
                        ),
                    OutlinedButton(
                      onPressed: () => g.act({'type': 'pass'}),
                      child: const Text('放弃竞标'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyHandPanel(BuildContext context, List<Map> myHand, int myGold) {
    final cs = Theme.of(context).colorScheme;
    // Summarize my category sums
    final catSums = List<int>.filled(5, 0);
    for (final c in myHand) {
      if (c['type'] == 'cat') {
        final idx = asInt(c['cat'], 0);
        if (idx >= 0 && idx < 5) catSums[idx] += asInt(c['val'], 0);
      }
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '📚 我的藏书与手牌 (${myHand.length} 张 · 💰金币总额 $myGold)：',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: cs.onSurface),
              ),
              for (var c = 0; c < 5; c++)
                Text(
                  '${_catNames[c]}:${catSums[c]}',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _catColors[c]),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (myHand.isEmpty)
            Text('暂无手牌', style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final card in myHand) _buildBibliosCard(context, card, compact: true),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBibliosCard(BuildContext context, Map card, {VoidCallback? onTap, bool compact = false}) {
    final cs = Theme.of(context).colorScheme;
    final type = asStr(card['type']);
    Color color = cs.primary;
    String subtitle = '';

    if (type == 'cat') {
      final cIdx = asInt(card['cat'], 0).clamp(0, 4);
      color = _catColors[cIdx];
      subtitle = '数值 +${card['val']} · 平局字母 ${card['tie']}';
    } else if (type == 'gold') {
      color = const Color(0xFFF9A825);
      subtitle = '💰 提供 ${card['val']} 金币';
    } else if (type == 'church') {
      color = const Color(0xFF5C6BC0);
      subtitle = '⛪ 立即调整骰子 ×${card['adjusts']}';
    } else {
      color = Colors.blueGrey;
      subtitle = '仅当前行动院长可见';
    }

    final widget = Container(
      width: compact ? 115 : 145,
      padding: EdgeInsets.all(compact ? 6 : 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color, width: onTap != null ? 2 : 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
            child: Text(
              asStr(card['name']),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: compact ? 11 : 12),
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: compact ? 10 : 11, color: cs.onSurface)),
        ],
      ),
    );

    if (onTap == null) return widget;
    return InkWell(borderRadius: BorderRadius.circular(9), onTap: onTap, child: widget);
  }

  Widget _buildResultBanner(BuildContext context) {
    final v = g.view;
    final pts = asIntList(v['finalPoints']);
    final gold = asIntList(v['finalGold']);
    final placings = asIntList(v['placings']);
    final catRes = (v['categoryResults'] as List?)?.cast<Map>() ?? const [];

    return ResultBanner(
      '修道院藏书阁 · 终局评选',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var s = 0; s < g.players; s++)
            Text(
              '第 ${s < placings.length ? placings[s] : 1} 名：${g.name(s)} — ${s < pts.length ? pts[s] : 0} 分（余 ${s < gold.length ? gold[s] : 0} 金）',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 6),
          for (final r in catRes)
            Builder(builder: (context) {
              final w = asInt(r['winner'], -1);
              final wName = w >= 0 ? g.name(w) : '无人获得';
              return Text(
                '【${r['catName']}】(${r['die']}分) → 归属：$wName',
                style: const TextStyle(fontSize: 11.5),
              );
            }),
        ],
      ),
    );
  }
}
