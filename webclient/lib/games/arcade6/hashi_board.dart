import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a6_common.dart';

class HashiBoard extends StatefulWidget {
  final GameContext g;
  const HashiBoard(this.g, {super.key});
  @override
  State<HashiBoard> createState() => _HashiBoardState();
}

class _HashiBoardState extends State<HashiBoard> {
  GameContext get g => widget.g;
  int? _selectedIsland;
  Offset? _dragStart;
  int? _dragIsland;

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  bool _isVisiblePair(List<Map<String, dynamic>> visiblePairs, int a, int b) {
    final u = math.min(a, b), v = math.max(a, b);
    return visiblePairs.any((p) => aInt(p['i1']) == u && aInt(p['i2']) == v);
  }

  int? _neighborInDir(
    List<Map<String, dynamic>> islands,
    List<Map<String, dynamic>> visiblePairs,
    int fromId,
    int dir,
  ) {
    if (fromId < 0 || fromId >= islands.length) return null;
    final src = islands[fromId];
    final sr = aInt(src['r']), sc = aInt(src['c']);
    for (final other in islands) {
      final oid = aInt(other['id']);
      if (oid == fromId || !_isVisiblePair(visiblePairs, fromId, oid)) continue;
      final or = aInt(other['r']), oc = aInt(other['c']);
      if (dir == 0 && oc == sc && or < sr) return oid;
      if (dir == 1 && or == sr && oc > sc) return oid;
      if (dir == 2 && oc == sc && or > sr) return oid;
      if (dir == 3 && or == sr && oc < sc) return oid;
    }
    return null;
  }

  void _toggleBridge(int a, int b) {
    if (!_canPlay) return;
    g.act({'type': 'bridge', 'i1': a, 'i2': b});
  }

  void _onTapGrid(
     int r,
    int c,
    List<Map<String, dynamic>> islands,
    List<Map<String, dynamic>> visiblePairs,
  ) {
    // Check if an island is at (r, c)
    for (final isl in islands) {
      if (aInt(isl['r']) == r && aInt(isl['c']) == c) {
        final id = aInt(isl['id']);
        if (_selectedIsland != null && _selectedIsland != id && _isVisiblePair(visiblePairs, _selectedIsland!, id)) {
          _toggleBridge(_selectedIsland!, id);
          return;
        }
        setState(() => _selectedIsland = _selectedIsland == id ? null : id);
        return;
      }
    }

    if (!_canPlay) return;
    // Check if (r, c) lies on a corridor between a visible island pair
    for (final pair in visiblePairs) {
      final u = aInt(pair['i1']), v = aInt(pair['i2']);
      if (u < 0 || u >= islands.length || v < 0 || v >= islands.length) continue;
      final ia = islands[u], ib = islands[v];
      final r1 = aInt(ia['r']), c1 = aInt(ia['c']);
      final r2 = aInt(ib['r']), c2 = aInt(ib['c']);
      if (r1 == r2 && r == r1 && c > math.min(c1, c2) && c < math.max(c1, c2)) {
        _toggleBridge(u, v);
        return;
      }
      if (c1 == c2 && c == c1 && r > math.min(r1, r2) && r < math.max(r1, r2)) {
        _toggleBridge(u, v);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final phase = aStr(v['phase']);
    final round = aInt(v['round'], 1);
    final totalRounds = math.max(1, aInt(v['totalRounds'], 3));
    final size = math.max(6, aInt(v['size'], 6));
    final left = aInt(v['left'], 0);
    final islands = aMaps(v['islands']);
    final bridges = aMaps(v['bridges']);
    final visiblePairs = aMaps(v['visiblePairs']);
    final connected = v['connected'] == true;
    final crossingCount = aInt(v['crossingCount'], 0);
    final ps = aMaps(v['ps']);

    if (_selectedIsland != null && _selectedIsland! >= islands.length) {
      _selectedIsland = islands.isNotEmpty ? 0 : null;
    }

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';
    final okCount = islands.where((x) => x['ok'] == true).length;
    final totalIslands = islands.length;

    String status;
    if (phase == 'over') {
      status = '数回连桥竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已连通全部岛屿（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final crossWarn = crossingCount > 0 ? ' · ⚠ 有交叉桥' : (connected ? ' · 已全连通' : '');
      status = '第 $round/$totalRounds 题（$size×$size）· 岛屿达标 $okCount/$totalIslands$crossWarn · ${left}s';
    }

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth > box.maxHeight * 1.12;
      final sideW = wide ? math.min(200.0, box.maxWidth * 0.24) : 0.0;
      final topStripH = wide ? 0.0 : 58.0;

      final playerTiles = Wrap(
        direction: wide ? Axis.vertical : Axis.horizontal,
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final s in g.seatsFromMe())
            if (s < ps.length) _buildPlayerTile(s, ps[s], totalRounds, wide ? sideW - 12 : 140),
        ],
      );

      final workspace = _buildWorkspace(
        context,
        cs: cs,
        size: size,
        round: round,
        totalRounds: totalRounds,
        islands: islands,
        bridges: bridges,
        visiblePairs: visiblePairs,
        connected: connected,
        crossingCount: crossingCount,
        wide: wide,
      );

      Widget body;
      if (wide) {
        body = Row(children: [
          SizedBox(
            width: sideW,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(6),
                child: FittedBox(fit: BoxFit.scaleDown, child: playerTiles),
              ),
            ),
          ),
          Expanded(child: Center(child: workspace)),
        ]);
      } else {
        body = Column(children: [
          SizedBox(
            height: topStripH,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: playerTiles),
              ),
            ),
          ),
          Expanded(child: Center(child: workspace)),
        ]);
      }

      return Column(children: [
        SizedBox(height: 38, child: aStatus(status, highlight: _canPlay)),
        Expanded(
          child: Stack(children: [
            Positioned.fill(child: body),
            if (phase == 'over')
              Positioned.fill(
                child: Container(
                  color: Colors.black38,
                  child: aRanking(
                    g,
                    aMaps(v['final']),
                    (r) => '${r['score']} 分 · 连通 ${r['solved']}/$totalRounds 题',
                  ),
                ),
              ),
          ]),
        ),
      ]);
    });
  }

  Widget _buildPlayerTile(int s, Map<String, dynamic> p, int totalRounds, double width) {
    final st = aStr(p['status']);
    final score = aInt(p['score'], 0);
    final solved = aInt(p['solved'], 0);
    final okIslands = aInt(p['okIslands'], 0);
    final totalIslands = math.max(1, aInt(p['totalIslands'], 8));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$okIslands/$totalIslands岛', null),
    };
    return A6ProgressTile(
      g,
      s,
      width: width,
      pct: st == 'solved' ? 1.0 : (okIslands / totalIslands),
      badge: badge,
      badgeColor: col,
      dim: st == 'resigned',
      sub: '积分 $score · 解出 $solved/$totalRounds',
    );
  }

  Widget _buildWorkspace(
    BuildContext context, {
    required ColorScheme cs,
    required int size,
    required int round,
    required int totalRounds,
    required List<Map<String, dynamic>> islands,
    required List<Map<String, dynamic>> bridges,
    required List<Map<String, dynamic>> visiblePairs,
    required bool connected,
    required int crossingCount,
    required bool wide,
  }) {
    final cellPx = size <= 6 ? 50.0 : 40.0;
    final boardPx = size * cellPx;

    final mapCard = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2538),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF4FC3F7).withValues(alpha: 0.45), width: 1.8),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black38, offset: Offset(0, 4))],
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final c = (d.localPosition.dx ~/ cellPx).clamp(0, size - 1);
          final r = (d.localPosition.dy ~/ cellPx).clamp(0, size - 1);
          _onTapGrid(r, c, islands, visiblePairs);
        },
        onPanStart: (d) {
          final c = (d.localPosition.dx ~/ cellPx).clamp(0, size - 1);
          final r = (d.localPosition.dy ~/ cellPx).clamp(0, size - 1);
          _dragStart = d.localPosition;
          _dragIsland = null;
          for (final isl in islands) {
            if (aInt(isl['r']) == r && aInt(isl['c']) == c) {
              final id = aInt(isl['id']);
              setState(() => _selectedIsland = id);
              _dragIsland = id;
              break;
            }
          }
        },
        onPanUpdate: (d) {
          if (_dragStart == null || _dragIsland == null) return;
          final delta = d.localPosition - _dragStart!;
          if (delta.distance >= 22) {
            final dir = delta.dx.abs() > delta.dy.abs()
                ? (delta.dx > 0 ? 1 : 3)
                : (delta.dy > 0 ? 2 : 0);
            final nb = _neighborInDir(islands, visiblePairs, _dragIsland!, dir);
            _dragStart = null;
            _dragIsland = null;
            if (nb != null) {
              _toggleBridge(_selectedIsland!, nb);
            }
          }
        },
        child: SizedBox(
          width: boardPx,
          height: boardPx,
          child: CustomPaint(
            size: Size(boardPx, boardPx),
            painter: _HashiPainter(
              gridSize: size,
              islands: islands,
              bridges: bridges,
              visiblePairs: visiblePairs,
              selectedIsland: _selectedIsland,
            ),
          ),
        ),
      ),
    );

    final sel = _selectedIsland ?? (islands.isNotEmpty ? 0 : null);
    final controlPanel = Container(
      width: wide ? 220 : boardPx + 20,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          A6Chip('第 $round/$totalRounds 题', cs.primary, size: 12),
          A6Chip(
            crossingCount > 0 ? '桥梁交叉!' : (connected ? '全岛已连通' : '尚未全连通'),
            crossingCount > 0 ? Colors.redAccent : (connected ? Colors.green : Colors.blueGrey),
            size: 11,
          ),
        ]),
        const SizedBox(height: 8),
        Text(
          '点击两座正对岛屿、点击航道或拖拽岛屿可循环切换「无桥 → 单桥 → 双桥」',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.8)),
        ),
        if (sel != null) ...[
          const SizedBox(height: 8),
          A6Dpad(
            enabled: _canPlay,
            onDir: (dir) {
              final nb = _neighborInDir(islands, visiblePairs, sel, dir);
              if (nb != null) _toggleBridge(sel, nb);
            },
          ),
        ],
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          OutlinedButton.icon(
            onPressed: _canPlay ? () => g.act({'type': 'clear'}) : null,
            icon: const Icon(Icons.layers_clear, size: 16),
            label: const Text('清空桥梁', style: TextStyle(fontSize: 12)),
          ),
          FilledButton.tonalIcon(
            onPressed: _canPlay ? () => g.act({'type': 'pass'}) : null,
            icon: const Icon(Icons.flag_outlined, size: 16),
            label: const Text('放弃本题', style: TextStyle(fontSize: 12)),
          ),
        ]),
      ]),
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: wide
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                mapCard,
                const SizedBox(width: 14),
                controlPanel,
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                mapCard,
                const SizedBox(height: 10),
                controlPanel,
              ]),
      ),
    );
  }
}

class _HashiPainter extends CustomPainter {
  final int gridSize;
  final List<Map<String, dynamic>> islands;
  final List<Map<String, dynamic>> bridges;
  final List<Map<String, dynamic>> visiblePairs;
  final int? selectedIsland;

  _HashiPainter({
    required this.gridSize,
    required this.islands,
    required this.bridges,
    required this.visiblePairs,
    required this.selectedIsland,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / gridSize;

    // Subtle sea coordinate grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF81D4FA).withValues(alpha: 0.14)
      ..strokeWidth = 1.0;
    for (var i = 0; i < gridSize; i++) {
      final pos = (i + 0.5) * cell;
      canvas.drawLine(Offset(pos, cell * 0.5), Offset(pos, size.height - cell * 0.5), gridPaint);
      canvas.drawLine(Offset(cell * 0.5, pos), Offset(size.width - cell * 0.5, pos), gridPaint);
    }

    // Highlight visible channels from selected island
    if (selectedIsland != null && selectedIsland! >= 0 && selectedIsland! < islands.length) {
      final sIsl = islands[selectedIsland!];
      final p1 = Offset((aInt(sIsl['c']) + 0.5) * cell, (aInt(sIsl['r']) + 0.5) * cell);
      for (final vp in visiblePairs) {
        final u = aInt(vp['i1']), v = aInt(vp['i2']);
        if (u != selectedIsland && v != selectedIsland) continue;
        final otherId = u == selectedIsland ? v : u;
        if (otherId < 0 || otherId >= islands.length) continue;
        final oIsl = islands[otherId];
        final p2 = Offset((aInt(oIsl['c']) + 0.5) * cell, (aInt(oIsl['r']) + 0.5) * cell);
        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = const Color(0xFFFFD54F).withValues(alpha: 0.25)
            ..strokeWidth = cell * 0.28
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // Draw active bridges
    for (final b in bridges) {
      final u = aInt(b['i1']), v = aInt(b['i2']);
      final count = aInt(b['count'], 0);
      final cross = b['cross'] == true;
      if (count <= 0 || u < 0 || u >= islands.length || v < 0 || v >= islands.length) continue;

      final ia = islands[u], ib = islands[v];
      final p1 = Offset((aInt(ia['c']) + 0.5) * cell, (aInt(ia['r']) + 0.5) * cell);
      final p2 = Offset((aInt(ib['c']) + 0.5) * cell, (aInt(ib['r']) + 0.5) * cell);

      final bridgePaint = Paint()
        ..color = cross ? const Color(0xFFFF5252) : const Color(0xFFFFCA28)
        ..strokeWidth = 4.2
        ..strokeCap = StrokeCap.round;

      if (count == 1) {
        canvas.drawLine(p1, p2, bridgePaint);
      } else {
        final horiz = aInt(ia['r']) == aInt(ib['r']);
        final offset = horiz ? const Offset(0, 4.5) : const Offset(4.5, 0);
        canvas.drawLine(p1 - offset, p2 - offset, bridgePaint);
        canvas.drawLine(p1 + offset, p2 + offset, bridgePaint);
      }
    }

    // Draw islands
    final radius = cell * 0.37;
    for (final isl in islands) {
      final id = aInt(isl['id']);
      final r = aInt(isl['r']);
      final c = aInt(isl['c']);
      final clue = aInt(isl['clue']);
      final deg = aInt(isl['deg']);
      final ok = isl['ok'] == true;
      final overloaded = deg > clue;
      final selected = id == selectedIsland;

      final center = Offset((c + 0.5) * cell, (r + 0.5) * cell);

      final fillCol = ok
          ? const Color(0xFF2E7D32)
          : (overloaded ? const Color(0xFFC62828) : const Color(0xFFECEFF1));
      final textCol = (ok || overloaded) ? Colors.white : const Color(0xFF102027);
      final ringCol = selected
          ? const Color(0xFFFFEA00)
          : (ok
              ? const Color(0xFF69F0AE)
              : (overloaded ? const Color(0xFFFF8A80) : const Color(0xFF4FC3F7)));

      canvas.drawCircle(center + const Offset(0, 2), radius, Paint()..color = Colors.black45);
      canvas.drawCircle(center, radius, Paint()..color = fillCol);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = ringCol
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 3.2 : 2.2,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: '$clue',
          style: TextStyle(
            fontSize: radius * 1.15,
            fontWeight: FontWeight.w900,
            color: textCol,
            fontFamilyFallback: kFontFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _HashiPainter old) =>
      old.gridSize != gridSize ||
      old.selectedIsland != selectedIsland ||
      old.islands != islands ||
      old.bridges != bridges;
}
