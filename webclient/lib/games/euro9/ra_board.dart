import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const Map<String, String> _tileLabels = {
  'ra': '☀️拉神',
  'pharaoh': '👑法老',
  'nile': '🌊尼罗河',
  'flood': '🌾泛滥',
  'god': '🦅神明',
  'gold': '🪙黄金',
  'civ_0': '🔭天文',
  'civ_1': '🏺农业',
  'civ_2': '📜文字',
  'civ_3': '🎨艺术',
  'civ_4': '⛩️宗教',
  'mon_0': '🔺金字塔',
  'mon_1': '🗼方尖碑',
  'mon_2': '🏛️神庙',
  'mon_3': '🦁狮身人面',
  'mon_4': '🕍神龛',
  'mon_5': '🗿雕像',
  'mon_6': '⛩️柱廊',
  'mon_7': '⚱️陵墓',
};

class RaBoard extends StatelessWidget {
  final GameContext g;
  const RaBoard(this.g, {super.key});

  String _tileSummary(List<dynamic> list) {
    final counts = <String, int>{};
    for (final raw in list) {
      final k = '$raw';
      counts[k] = (counts[k] ?? 0) + 1;
    }
    if (counts.isEmpty) return '暂无板块';
    return counts.entries.map((e) => '${_tileLabels[e.key] ?? e.key}×${e.value}').join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final epoch = (v['epoch'] as num?)?.toInt() ?? 1;
    final totalEpochs = (v['totalEpochs'] as num?)?.toInt() ?? 3;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final phase = '${v['phase'] ?? 'play'}';
    final raProgress = (v['raProgress'] as num?)?.toInt() ?? 0;
    final raLimit = (v['raLimit'] as num?)?.toInt() ?? 7;
    final centerDisk = (v['centerDisk'] as num?)?.toInt() ?? 1;
    final bagCount = (v['bagCount'] as num?)?.toInt() ?? 0;
    final auctionTrack = (v['auctionTrack'] as List?) ?? const [];
    final sunDisks = (v['sunDisks'] as List?) ?? const [];
    final usedDisks = (v['usedDisks'] as List?) ?? const [];
    final tiles = (v['tiles'] as List?) ?? const [];
    final scores = (v['score'] as List?) ?? const [];
    final highestBid = (v['highestBid'] as num?)?.toInt() ?? 0;
    final highestBidder = (v['highestBidder'] as num?)?.toInt() ?? -1;
    final lastAction = '${v['lastAction'] ?? ''}';

    final isMyTurn = !g.over && g.seat == turn;
    final myDisks = (g.seat >= 0 && g.seat < sunDisks.length)
        ? (sunDisks[g.seat] as List).map((e) => (e as num).toInt()).toList()
        : <int>[];

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: StatusBar(
                      g.over
                          ? '游戏已结束 — $lastAction'
                          : '第 $epoch/$totalEpochs 纪元 · 轮到 ${g.name(turn)}${phase == 'auction' ? '（竞拍中）' : ''} · $lastAction',
                      highlight: isMyTurn,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Players bar
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final s in g.seatsFromMe())
                        if (s < scores.length)
                          g.tag(
                            s,
                            active: s == turn && !g.over,
                            sub:
                                '⭐${scores[s]}分 | ☀️可用:[${(sunDisks[s] as List).join(',')}] | 🌙已赢:${(usedDisks[s] as List).length}枚',
                          ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Ra Track + Center Disk + Auction Track
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '⛵ 太阳船轨道: $raProgress / $raLimit',
                              style: TextStyle(fontWeight: FontWeight.bold, color: cs.error),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.amber.shade700),
                              ),
                              child: Text(
                                '☀️ 中央太阳圆盘: $centerDisk',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text('🎒 盲抽袋剩余: $bagCount 张', style: const TextStyle(fontSize: 12)),
                            if (phase == 'auction')
                              Text(
                                highestBidder >= 0
                                    ? '🔨 当前最高出价: ${g.name(highestBidder)} (圆盘 $highestBid)'
                                    : '🔨 当前尚无人出价',
                                style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '🏺 拍卖行板块 (${auctionTrack.length}/8)：',
                          style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                        const SizedBox(height: 6),
                        if (auctionTrack.isEmpty)
                          Text('当前拍卖行空置', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)))
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final t in auctionTrack)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: cs.primary),
                                  ),
                                  child: Text(
                                    _tileLabels['$t'] ?? '$t',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: cs.onPrimaryContainer),
                                  ),
                                ),
                            ],
                          ),
                        if (isMyTurn) ...[
                          const SizedBox(height: 10),
                          if (phase == 'play')
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                if (auctionTrack.length < 8)
                                  FilledButton.icon(
                                    onPressed: () => g.act({'type': 'draw'}),
                                    icon: const Icon(Icons.touch_app, size: 16),
                                    label: const Text('抽取板块 (Draw)'),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: () => g.act({'type': 'invoke_ra'}),
                                  icon: const Icon(Icons.wb_sunny, size: 16),
                                  label: const Text('召唤拉神发起拍卖 (Invoke Ra)'),
                                ),
                              ],
                            )
                          else if (phase == 'auction')
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                for (final d in myDisks)
                                  if (d > highestBid)
                                    FilledButton.tonal(
                                      onPressed: () => g.act({'type': 'bid', 'disk': d}),
                                      child: Text('☀️ 出价圆盘 $d'),
                                    ),
                                OutlinedButton(
                                  onPressed: () => g.act({'type': 'pass'}),
                                  child: const Text('跳过竞拍 (Pass)'),
                                ),
                              ],
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Player collections
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in g.seatsFromMe())
                        if (s < tiles.length)
                          Container(
                            width: 380,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cs.surface.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: s == turn && !g.over ? cs.primary : cs.outline.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${g.name(s)} 的王朝馆藏 (⭐${scores[s]}分)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '☀️ 可用圆盘: ${(sunDisks[s] as List).isEmpty ? '无' : (sunDisks[s] as List).join(', ')}  |  🌙 待翻面圆盘: ${(usedDisks[s] as List).isEmpty ? '无' : (usedDisks[s] as List).join(', ')}',
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _tileSummary(tiles[s] as List),
                                  style: TextStyle(fontSize: 11.5, color: cs.onSurface.withValues(alpha: 0.85)),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (g.over && v['result'] is Map)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(
                '🏆 获胜者：${((v['result'] as Map)['winners'] as List?)?.join('、') ?? ''}',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var s = 0; s < g.players && s < scores.length; s++)
                      Text('${g.name(s)}：${scores[s]} 分'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
