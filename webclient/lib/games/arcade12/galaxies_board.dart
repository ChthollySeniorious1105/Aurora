import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a12_common.dart';

class GalaxiesBoard extends StatefulWidget {
  final GameContext g;
  const GalaxiesBoard(this.g, {super.key});
  @override
  State<GalaxiesBoard> createState() => _GalaxiesBoardState();
}

class _GalaxiesBoardState extends State<GalaxiesBoard> {
  GameContext get g => widget.g;
  int _activeGalaxy = 0;

  static const List<Color> _galaxyBgColors = [
    Color(0xFFFFF8E1), // Amber
    Color(0xFFE3F2FD), // Blue
    Color(0xFFF3E5F5), // Purple
    Color(0xFFE0F2F1), // Teal
    Color(0xFFFFF3E0), // Orange
    Color(0xFFFCE4EC), // Pink
    Color(0xFFF1F8E9), // Lime
    Color(0xFFE8EAF6), // Indigo
    Color(0xFFE0F7FA), // Cyan
    Color(0xFFFBE9E7), // Deep Orange
    Color(0xFFEDE7F6), // Deep Purple
    Color(0xFFF9FBE7), // Yellow Green
  ];

  static const List<Color> _galaxyBadgeColors = [
    Color(0xFFF57F17),
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
    Color(0xFF00695C),
    Color(0xFFE65100),
    Color(0xFFAD1457),
    Color(0xFF33691E),
    Color(0xFF283593),
    Color(0xFF00838F),
    Color(0xFFBF360C),
    Color(0xFF4527A0),
    Color(0xFF827717),
  ];

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  void _onCellTap(int r, int c, int curVal, int galaxyCount) {
    if (!_canPlay) return;
    final active = _activeGalaxy.clamp(0, math.max(0, galaxyCount - 1));
    if (curVal != active) {
      g.act({'type': 'set', 'r': r, 'c': c, 'val': active});
    } else {
      g.act({'type': 'toggle', 'r': r, 'c': c});
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final phase = aStr(v['phase']);
    final round = aInt(v['round'], 1);
    final totalRounds = math.max(1, aInt(v['totalRounds'], 3));
    final size = math.max(5, aInt(v['size'], 5));
    final left = aInt(v['left'], 0);
    final centers = aIntGrid(v['centers']);
    final galaxyCount = math.max(1, aInt(v['galaxyCount'], centers.length));
    final board = aInts(v['board']);
    final asymmetricCells = aInts(v['asymmetricCells']).toSet();
    final disconnectedCells = aInts(v['disconnectedCells']).toSet();
    final satisfiedGalaxies = aInts(v['satisfiedGalaxies']).toSet();
    final violatedGalaxies = aInts(v['violatedGalaxies']).toSet();
    final satisfiedGalaxyCount = aInt(v['satisfiedGalaxyCount'], 0);
    final totalGalaxies = math.max(1, aInt(v['totalGalaxies'], galaxyCount));
    final assignedCount = aInt(v['assignedCount'], 0);
    final totalCells = math.max(1, aInt(v['totalCells'], size * size));
    final ps = aMaps(v['ps']);

    if (_activeGalaxy >= galaxyCount) {
      _activeGalaxy = 0;
    }

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '对称星系分割竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已解出对称星系分割（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final warnings = <String>[
        if (asymmetricCells.isNotEmpty) '不满足180°中心对称',
        if (disconnectedCells.isNotEmpty) '星系未连通/未含中心',
      ];
      final warnStr = warnings.isEmpty ? '对称正常' : warnings.join(' · ');
      status =
          '第 $round/$totalRounds 题（$size×$size）· 对称星系 $satisfiedGalaxyCount/$totalGalaxies · 已划 $assignedCount/$totalCells · $warnStr · ${left}s';
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
        centers: centers,
        galaxyCount: galaxyCount,
        board: board,
        asymmetricCells: asymmetricCells,
        disconnectedCells: disconnectedCells,
        satisfiedGalaxies: satisfiedGalaxies,
        violatedGalaxies: violatedGalaxies,
        satisfiedGalaxyCount: satisfiedGalaxyCount,
        totalGalaxies: totalGalaxies,
        assignedCount: assignedCount,
        totalCells: totalCells,
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
    final sat = aInt(p['satisfiedGalaxies'], 0);
    final tot = math.max(1, aInt(p['totalGalaxies'], 6));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$sat/$tot星系', null),
    };
    return A12ProgressTile(
      g,
      s,
      width: width,
      pct: st == 'solved' ? 1.0 : (sat / tot),
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
    required List<List<int>> centers,
    required int galaxyCount,
    required List<int> board,
    required Set<int> asymmetricCells,
    required Set<int> disconnectedCells,
    required Set<int> satisfiedGalaxies,
    required Set<int> violatedGalaxies,
    required int satisfiedGalaxyCount,
    required int totalGalaxies,
    required int assignedCount,
    required int totalCells,
    required bool wide,
  }) {
    final cellPx = size <= 5 ? 50.0 : 44.0;
    final gridSpan = size * cellPx;
    final conflictCells = {...asymmetricCells, ...disconnectedCells};

    final gridCard = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF141C26),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.45), width: 1.8),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black38, offset: Offset(0, 4))],
      ),
      child: SizedBox(
        width: gridSpan,
        height: gridSpan,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
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
                          galaxyCount: galaxyCount,
                          board: board,
                          conflictCells: conflictCells,
                          satisfiedGalaxies: satisfiedGalaxies,
                        ),
                    ],
                  ),
              ],
            ),
            // Render the Center Dots [r2, c2] on top of the grid
            for (var gId = 0; gId < centers.length; gId++)
              if (centers[gId].length >= 2)
                () {
                  final r2 = centers[gId][0];
                  final c2 = centers[gId][1];
                  final cx = (c2 + 1) * cellPx * 0.5;
                  final cy = (r2 + 1) * cellPx * 0.5;
                  const dotSize = 20.0;
                  final isAct = _activeGalaxy == gId;
                  final isSat = satisfiedGalaxies.contains(gId);
                  final isViol = violatedGalaxies.contains(gId);
                  final badgeCol = _galaxyBadgeColors[gId % _galaxyBadgeColors.length];
                  return Positioned(
                    left: cx - dotSize / 2,
                    top: cy - dotSize / 2,
                    child: GestureDetector(
                      onTap: () => setState(() => _activeGalaxy = gId),
                      child: Container(
                        width: dotSize,
                        height: dotSize,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: badgeCol,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isAct
                                ? const Color(0xFF00E5FF)
                                : (isViol
                                    ? const Color(0xFFFF5252)
                                    : (isSat ? const Color(0xFF69F0AE) : Colors.white)),
                            width: isAct ? 2.6 : 1.8,
                          ),
                          boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black54)],
                        ),
                        child: Text(
                          '${gId + 1}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                }(),
          ],
        ),
      ),
    );

    final toolbar = Container(
      constraints: BoxConstraints(maxWidth: wide ? 245 : 350),
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
              A12Chip('对称星系 $satisfiedGalaxyCount/$totalGalaxies', const Color(0xFF00897B), size: 11),
              A12Chip('已划 $assignedCount/$totalCells', cs.primary, size: 11),
              A12Chip(
                conflictCells.isEmpty ? '✓ 对称正常' : '⚠ 对称/连通冲突',
                conflictCells.isEmpty ? Colors.green : Colors.redAccent,
                size: 11,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            alignment: WrapAlignment.center,
            children: [
              for (var gId = 0; gId < galaxyCount; gId++)
                () {
                  final isAct = _activeGalaxy == gId;
                  final badgeCol = _galaxyBadgeColors[gId % _galaxyBadgeColors.length];
                  final isSat = satisfiedGalaxies.contains(gId);
                  return SizedBox(
                    height: 30,
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        backgroundColor: isAct ? badgeCol : badgeCol.withValues(alpha: 0.18),
                        foregroundColor: isAct ? Colors.white : badgeCol,
                        side: BorderSide(
                          color: isAct ? Colors.white : badgeCol.withValues(alpha: 0.6),
                          width: isAct ? 1.8 : 1.0,
                        ),
                      ),
                      onPressed: () => setState(() => _activeGalaxy = gId),
                      child: Text(
                        '${isSat ? "✓" : "★"}${gId + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ),
                  );
                }(),
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
                label: const Text('重置', style: TextStyle(fontSize: 12)),
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

  Widget _buildCell({
    required int r,
    required int c,
    required int size,
    required double cellPx,
    required int galaxyCount,
    required List<int> board,
    required Set<int> conflictCells,
    required Set<int> satisfiedGalaxies,
  }) {
    final idx = r * size + c;
    final gId = idx < board.length ? board[idx] : -1;
    final assigned = gId >= 0 && gId < galaxyCount;
    final isConflict = conflictCells.contains(idx);
    final isSat = assigned && satisfiedGalaxies.contains(gId);

    int galAt(int rr, int cc) {
      if (rr < 0 || rr >= size || cc < 0 || cc >= size) return -2;
      final i = rr * size + cc;
      return i < board.length ? board[i] : -1;
    }

    const wallBorder = BorderSide(color: Color(0xFF0F172A), width: 2.6);
    const innerBorder = BorderSide(color: Color(0x55475569), width: 0.7);

    Color bgColor;
    if (isConflict) {
      bgColor = const Color(0xFFFFCDD2);
    } else if (assigned) {
      final base = _galaxyBgColors[gId % _galaxyBgColors.length];
      bgColor = isSat ? Color.alphaBlend(const Color(0x222E7D32), base) : base;
    } else {
      bgColor = const Color(0xFF1E293B);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onCellTap(r, c, gId, galaxyCount),
      onSecondaryTap: () {
        if (_canPlay) {
          g.act({'type': 'set', 'r': r, 'c': c, 'val': -1});
        }
      },
      child: Container(
        width: cellPx,
        height: cellPx,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            top: assigned && galAt(r - 1, c) != gId ? wallBorder : innerBorder,
            bottom: assigned && galAt(r + 1, c) != gId ? wallBorder : innerBorder,
            left: assigned && galAt(r, c - 1) != gId ? wallBorder : innerBorder,
            right: assigned && galAt(r, c + 1) != gId ? wallBorder : innerBorder,
          ),
        ),
        child: assigned
            ? Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 3, bottom: 2),
                  child: Text(
                    '#${gId + 1}',
                    style: TextStyle(
                      fontSize: cellPx * 0.21,
                      fontWeight: FontWeight.w800,
                      color: isConflict
                          ? const Color(0xFFB71C1C)
                          : _galaxyBadgeColors[gId % _galaxyBadgeColors.length].withValues(alpha: 0.75),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
