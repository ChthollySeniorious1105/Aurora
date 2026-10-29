import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<String> _roomNames = [
  '🎰 老虎机厅 (+2收/+1望)',
  '🎲 赌桌大厅 (+3收/+1望)',
  '🍽️ 豪华餐厅 (+1收/+3望)',
  '🎭 剧场秀 (+4望)',
  '👑 皇冠娱乐城 (+5望)',
];

const List<String> _shortRoomIcons = ['🎰', '🎲', '🍽️', '🎭', '👑'];

class VegasShowdownBoard extends StatefulWidget {
  final GameContext g;
  const VegasShowdownBoard(this.g, {super.key});

  @override
  State<VegasShowdownBoard> createState() => _VegasShowdownBoardState();
}

class _VegasShowdownBoardState extends State<VegasShowdownBoard> {
  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 8;
    final phase = v['phase'] as String? ?? 'bid';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final cash = (v['cash'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 15);
    final revenue = (v['revenue'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 3);
    final fame = (v['fame'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final market = (v['market'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const [0, 1, 2, 3, 4];
    final highBids = (v['highBids'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const [0, 0, 0, 0, 0];
    final highBidders = (v['highBidders'] as List?)?.map((e) => (e as num?)?.toInt()).toList() ??
        const [null, null, null, null, null];
    final wonRoom = (v['wonRoom'] as List?)?.map((e) => (e as num?)?.toInt()).toList() ??
        List<int?>.filled(g.players, null);
    final casino = (v['casino'] as List?) ?? const [];
    final lastEvent = v['lastEvent'] as String? ?? '';

    final isMyTurn = g.seat == turn && !g.over;
    final myCash = g.seat >= 0 && g.seat < cash.length ? cash[g.seat] : 0;

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
                          ? '赌城大亨 — 建设完成'
                          : '第 $round/$maxRounds 轮 · ${phase == "bid" ? "多轨反弹竞拍" : "5×5 赌场蓝图建造"} · ${isMyTurn ? "轮到你行动" : "等待 ${g.name(turn)}"}',
                      highlight: isMyTurn,
                    ),
                  ),
                  if (lastEvent.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      lastEvent,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.85)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // 5 Auction Tracks
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                '🔨 5 条娱乐厅竞拍轨道（超价立即退还前标者资金）：',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                              ),
                            ),
                            if (isMyTurn && phase == 'bid')
                              OutlinedButton(
                                onPressed: () => g.act({'type': 'publicity'}),
                                child: const Text('📣 公关宣传 (+2资金/+1名望)'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var slot = 0; slot < 5; slot++)
                              _buildAuctionTrack(
                                g: g,
                                cs: cs,
                                slot: slot,
                                roomType: slot < market.length ? market[slot] : slot,
                                highBid: slot < highBids.length ? highBids[slot] : 0,
                                highBidder: slot < highBidders.length ? highBidders[slot] : null,
                                canBid: isMyTurn &&
                                    phase == 'bid' &&
                                    (slot >= highBidders.length || highBidders[slot] != g.seat) &&
                                    myCash >= ((slot < highBids.length ? highBids[slot] : 0) + 1),
                                nextBid: (slot < highBids.length ? highBids[slot] : 0) + 1,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Players & 5x5 Casino Grids
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final s in g.seatsFromMe())
                        _buildPlayerCasinoCard(
                          g: g,
                          cs: cs,
                          seat: s,
                          active: turn == s && !g.over,
                          cash: s < cash.length ? cash[s] : 0,
                          rev: s < revenue.length ? revenue[s] : 0,
                          fame: s < fame.length ? fame[s] : 0,
                          pendingRoom: s < wonRoom.length ? wonRoom[s] : null,
                          grid: s < casino.length ? (casino[s] as List) : const [],
                          canPlace: isMyTurn && phase == 'place' && g.seat == s,
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

  Widget _buildAuctionTrack({
    required GameContext g,
    required ColorScheme cs,
    required int slot,
    required int roomType,
    required int highBid,
    required int? highBidder,
    required bool canBid,
    required int nextBid,
  }) {
    return Container(
      width: 175,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: canBid ? cs.primary : cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '轨道 #${slot + 1} ${_roomNames[roomType % _roomNames.length]}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            highBidder != null ? '当前最高: \$$highBid (${g.name(highBidder)})' : '暂无出价 (起拍 \$1)',
            style: TextStyle(fontSize: 11, color: cs.onSecondaryContainer),
          ),
          if (canBid) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () => g.act({'type': 'bid', 'slot': slot, 'bid': nextBid}),
                child: Text('出价 \$$nextBid'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerCasinoCard({
    required GameContext g,
    required ColorScheme cs,
    required int seat,
    required bool active,
    required int cash,
    required int rev,
    required int fame,
    required int? pendingRoom,
    required List grid,
    required bool canPlace,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? cs.primary : cs.outline.withValues(alpha: 0.25),
          width: active ? 1.8 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          g.tag(
            seat,
            active: active,
            sub: '💵\$$cash · 📈收入+$rev · ⭐名望$fame',
          ),
          if (pendingRoom != null) ...[
            const SizedBox(height: 4),
            Text(
              '待建造: ${_roomNames[pendingRoom % _roomNames.length]}（点击下方空位放置）',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary),
            ),
          ],
          const SizedBox(height: 6),
          // 5x5 Compact Grid
          for (var r = 0; r < 5; r++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var c = 0; c < 5; c++)
                  _buildCell(
                    g: g,
                    cs: cs,
                    r: r,
                    c: c,
                    room: (r < grid.length && c < (grid[r] as List).length)
                        ? ((grid[r] as List)[c] as num?)?.toInt()
                        : null,
                    canPlace: canPlace,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCell({
    required GameContext g,
    required ColorScheme cs,
    required int r,
    required int c,
    required int? room,
    required bool canPlace,
  }) {
    final occupied = room != null;
    final box = Container(
      width: 28,
      height: 28,
      margin: const EdgeInsets.all(1.5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: occupied
            ? cs.primaryContainer
            : cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: canPlace && !occupied ? cs.primary : cs.outline.withValues(alpha: 0.25),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          occupied ? _shortRoomIcons[room % _shortRoomIcons.length] : '·',
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
    if (!canPlace || occupied) return box;
    return InkWell(
      onTap: () => g.act({'type': 'place', 'r': r, 'c': c}),
      child: box,
    );
  }
}
