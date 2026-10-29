import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a9_common.dart';

class StarBattleBoard extends StatefulWidget {
  final GameContext g;
  const StarBattleBoard(this.g, {super.key});
  @override
  State<StarBattleBoard> createState() => _StarBattleBoardState();
}

class _StarBattleBoardState extends State<StarBattleBoard> {
  GameContext get g => widget.g;
  // 0 = cycle (0->1->2->0), 1 = place Star (toggle 1/0), 2 = place Cross dot (toggle 2/0)
  int _toolMode = 0;

  static const List<Color> _regionColors = [
    Color(0xFFFFF3E0), // Soft Amber
    Color(0xFFE3F2FD), // Soft Sky Blue
    Color(0xFFE8F5E9), // Soft Mint Green
    Color(0xFFF3E5F5), // Soft Lavender
    Color(0xFFFFEBEE), // Soft Coral Pink
    Color(0xFFE0F7FA), // Soft Cyan
    Color(0xFFFFFDE7), // Soft Lemon
  ];

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  List<int> _parseFlatRegions(Object? raw, int size) {
    if (raw is List && raw.isNotEmpty) {
      if (raw.first is List) {
        return [
          for (final row in raw)
            if (row is List)
              for (final cell in row) aInt(cell, 0),
        ];
      }
      return aInts(raw);
    }
    return List<int>.filled(size * size, 0);
  }

  void _onCellTap(int r, int c, int currentMark) {
    if (!_canPlay) return;
    if (_toolMode == 0) {
      g.act({'type': 'toggle', 'r': r, 'c': c});
    } else if (_toolMode == 1) {
      final next = currentMark == 1 ? 0 : 1;
      g.act({'type': 'toggle', 'r': r, 'c': c, 'val': next});
    } else {
      final next = currentMark == 2 ? 0 : 2;
      g.act({'type': 'toggle', 'r': r, 'c': c, 'val': next});
    }
  }

  void _onCellSecondaryTap(int r, int c, int currentMark) {
    if (!_canPlay) return;
    final next = currentMark == 2 ? 0 : 2;
    g.act({'type': 'toggle', 'r': r, 'c': c, 'val': next});
  }

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final phase = aStr(v['phase']);
    final round = aInt(v['round'], 1);
    final totalRounds = math.max(1, aInt(v['totalRounds'], 3));
    final size = math.max(5, aInt(v['size'], 6));
    final left = aInt(v['left'], 0);
    final regions = _parseFlatRegions(v['regions'], size);
    final marks = aInts(v['marks']);
    final rowCounts = aInts(v['rowCounts']);
    final colCounts = aInts(v['colCounts']);
    final conflicts = aInts(v['conflicts']).toSet();
    final touching = aInts(v['touching']).toSet();
    final satisfiedUnits = aInt(v['satisfiedUnits'], 0);
    final totalUnits = math.max(1, aInt(v['totalUnits'], 3 * size));
    final starCount = aInt(v['starCount'], 0);
    final ps = aMaps(v['ps']);

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '星战放星竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已完成星战放星（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final warnStr = conflicts.isNotEmpty
          ? (touching.isNotEmpty ? ' · ⚠ 星星八向接触' : ' · ⚠ 同行/列/区超额')
          : '';
      status =
          '第 $round/$totalRounds 题（$size×$size）· 星星 $starCount/$size · 达标单元 $satisfiedUnits/$totalUnits$warnStr · ${left}s';
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
        regions: regions,
        marks: marks,
        rowCounts: rowCounts,
        colCounts: colCounts,
        conflicts: conflicts,
        touching: touching,
        satisfiedUnits: satisfiedUnits,
        totalUnits: totalUnits,
        starCount: starCount,
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
                    (r) => '${r['score']} 分 · 解出 ${r['solved']}/$totalRounds 题',
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
    final satisfied = aInt(p['satisfied'], 0);
    final totalUnits = math.max(1, aInt(p['totalUnits'], 18));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$satisfied/$totalUnits项', null),
    };
    return A9ProgressTile(
      g,
      s,
      width: width,
      pct: st == 'solved' ? 1.0 : (satisfied / totalUnits),
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
    required List<int> regions,
    required List<int> marks,
    required List<int> rowCounts,
    required List<int> colCounts,
    required Set<int> conflicts,
    required Set<int> touching,
    required int satisfiedUnits,
    required int totalUnits,
    required int starCount,
    required bool wide,
  }) {
    final cellPx = size <= 5 ? 50.0 : 44.0;

    final gridCard = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.5), width: 1.8),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black38, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < size; r++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var c = 0; c < size; c++)
                  _buildCell(
                    r: r,
                    c: c,
                    size: size,
                    cellPx: cellPx,
                    regions: regions,
                    marks: marks,
                    conflicts: conflicts,
                  ),
                const SizedBox(width: 6),
                _buildUnitIndicator(r < rowCounts.length ? rowCounts[r] : 0),
              ],
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var c = 0; c < size; c++)
                SizedBox(
                  width: cellPx,
                  child: Center(
                    child: _buildUnitIndicator(c < colCounts.length ? colCounts[c] : 0),
                  ),
                ),
              const SizedBox(width: 28),
            ],
          ),
        ],
      ),
    );

    final toolbar = Container(
      constraints: BoxConstraints(maxWidth: wide ? 220 : 340),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              A9Chip('星星 $starCount/$size', const Color(0xFFF57F17), size: 11),
              A9Chip('达标 $satisfiedUnits/$totalUnits', cs.primary, size: 11),
              A9Chip(
                conflicts.isEmpty ? '✓ 无接触冲突' : '⚠ 存在冲突',
                conflicts.isEmpty ? Colors.green : Colors.redAccent,
                size: 11,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('循环切换', style: TextStyle(fontSize: 11)),
                selected: _toolMode == 0,
                onSelected: (_) => setState(() => _toolMode = 0),
                visualDensity: VisualDensity.compact,
              ),
              ChoiceChip(
                label: const Text('放星 ⭐', style: TextStyle(fontSize: 11)),
                selected: _toolMode == 1,
                onSelected: (_) => setState(() => _toolMode = 1),
                visualDensity: VisualDensity.compact,
              ),
              ChoiceChip(
                label: const Text('排除 ×', style: TextStyle(fontSize: 11)),
                selected: _toolMode == 2,
                onSelected: (_) => setState(() => _toolMode = 2),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _canPlay ? () => g.act({'type': 'clear'}) : null,
                icon: const Icon(Icons.layers_clear, size: 15),
                label: const Text('清空', style: TextStyle(fontSize: 12)),
              ),
              FilledButton.tonalIcon(
                onPressed: _canPlay ? () => g.act({'type': 'pass'}) : null,
                icon: const Icon(Icons.flag_outlined, size: 15),
                label: const Text('放弃', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: wide
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                gridCard,
                const SizedBox(width: 12),
                toolbar,
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                gridCard,
                const SizedBox(height: 8),
                toolbar,
              ]),
      ),
    );
  }

  Widget _buildUnitIndicator(int count) {
    final ok = count == 1;
    final over = count > 1;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: over
            ? const Color(0xFFD32F2F)
            : (ok ? const Color(0xFF2E7D32) : const Color(0xFF37474F)),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCell({
    required int r,
    required int c,
    required int size,
    required double cellPx,
    required List<int> regions,
    required List<int> marks,
    required Set<int> conflicts,
  }) {
    final idx = r * size + c;
    final reg = idx < regions.length ? regions[idx].clamp(0, 99) : 0;
    final mark = idx < marks.length ? marks[idx] : 0;
    final isConflict = conflicts.contains(idx);

    int regAt(int rr, int cc) {
      if (rr < 0 || rr >= size || cc < 0 || cc >= size) return -1;
      final i = rr * size + cc;
      return i < regions.length ? regions[i] : -1;
    }

    const wallBorder = BorderSide(color: Color(0xFF1E293B), width: 2.8);
    const innerBorder = BorderSide(color: Color(0x66475569), width: 0.7);

    final baseBg = _regionColors[reg % _regionColors.length];
    final bgColor = isConflict ? const Color(0xFFFFCDD2) : baseBg;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onCellTap(r, c, mark),
      onSecondaryTap: () => _onCellSecondaryTap(r, c, mark),
      child: Container(
        width: cellPx,
        height: cellPx,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            top: regAt(r - 1, c) != reg ? wallBorder : innerBorder,
            bottom: regAt(r + 1, c) != reg ? wallBorder : innerBorder,
            left: regAt(r, c - 1) != reg ? wallBorder : innerBorder,
            right: regAt(r, c + 1) != reg ? wallBorder : innerBorder,
          ),
        ),
        alignment: Alignment.center,
        child: mark == 1
            ? Icon(
                Icons.star_rounded,
                size: cellPx * 0.68,
                color: isConflict ? const Color(0xFFD32F2F) : const Color(0xFFF57F17),
              )
            : (mark == 2
                ? Icon(
                    Icons.close_rounded,
                    size: cellPx * 0.42,
                    color: const Color(0xFF64748B),
                  )
                : null),
      ),
    );
  }
}
