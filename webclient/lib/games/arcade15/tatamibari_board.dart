import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a15_common.dart';

class TatamibariBoard extends StatefulWidget {
  final GameContext g;
  const TatamibariBoard(this.g, {super.key});
  @override
  State<TatamibariBoard> createState() => _TatamibariBoardState();
}

class _TatamibariBoardState extends State<TatamibariBoard> {
  GameContext get g => widget.g;
  int _activeRegion = 0;

  static const List<Color> _regionBgColors = [
    Color(0xFFFFF8E1), // Soft Amber
    Color(0xFFE3F2FD), // Soft Blue
    Color(0xFFF3E5F5), // Soft Purple
    Color(0xFFE0F2F1), // Soft Teal
    Color(0xFFFFF3E0), // Soft Orange
    Color(0xFFFCE4EC), // Soft Pink
    Color(0xFFF1F8E9), // Soft Lime
    Color(0xFFE8EAF6), // Soft Indigo
    Color(0xFFE0F7FA), // Soft Cyan
    Color(0xFFFBE9E7), // Soft Deep Orange
    Color(0xFFEDE7F6), // Soft Deep Purple
    Color(0xFFF9FBE7), // Soft Yellow Green
  ];

  static const List<Color> _regionBadgeColors = [
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

  void _onCellTap(int r, int c, int curVal, int clueId, int regionCount) {
    if (clueId >= 0 && clueId < regionCount) {
      setState(() => _activeRegion = clueId);
      if (!_canPlay) return;
      if (curVal != clueId) {
        g.act({'type': 'set', 'r': r, 'c': c, 'val': clueId});
      }
      return;
    }
    if (!_canPlay) return;
    final active = _activeRegion.clamp(0, math.max(0, regionCount - 1));
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
    final clues = aMaps(v['clues']);
    final clueGridFlat = aInts(v['clueGridFlat']);
    final clueIdFlat = aInts(v['clueIdFlat']);
    final regionCount = math.max(1, aInt(v['regionCount'], clues.length));
    final board = aInts(v['board']);
    final satisfiedRegions = aInts(v['satisfiedRegions']).toSet();
    final violatedRegions = aInts(v['violatedRegions']).toSet();
    final nonRectCells = aInts(v['nonRectCells']).toSet();
    final badProportionCells = aInts(v['badProportionCells']).toSet();
    final fourCornerVertices = aInts(v['fourCornerVertices']).toSet();
    final fourCornerCells = aInts(v['fourCornerCells']).toSet();
    final satisfiedRegionCount = aInt(v['satisfiedRegionCount'], 0);
    final totalRegions = math.max(1, aInt(v['totalRegions'], regionCount));
    final assignedCount = aInt(v['assignedCount'], 0);
    final totalCells = math.max(1, aInt(v['totalCells'], size * size));
    final ps = aMaps(v['ps']);

    if (_activeRegion >= regionCount) {
      _activeRegion = 0;
    }

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '榻榻米分割竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已解出榻榻米分割（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final warnings = <String>[
        if (nonRectCells.isNotEmpty) '非矩形或跨多线索',
        if (badProportionCells.isNotEmpty) '长宽比例不符(+/-/|)',
        if (fourCornerVertices.isNotEmpty) '内部四席十字交点冲突',
      ];
      final warnStr = warnings.isEmpty ? '铺设规则良好' : warnings.join(' · ');
      status =
          '第 $round/$totalRounds 题（$size×$size）· 达标榻榻米 $satisfiedRegionCount/$totalRegions · 已铺 $assignedCount/$totalCells · $warnStr · ${left}s';
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
        clues: clues,
        clueGridFlat: clueGridFlat,
        clueIdFlat: clueIdFlat,
        regionCount: regionCount,
        board: board,
        satisfiedRegions: satisfiedRegions,
        violatedRegions: violatedRegions,
        nonRectCells: nonRectCells,
        badProportionCells: badProportionCells,
        fourCornerVertices: fourCornerVertices,
        fourCornerCells: fourCornerCells,
        satisfiedRegionCount: satisfiedRegionCount,
        totalRegions: totalRegions,
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
    final sat = aInt(p['satisfiedRegions'], 0);
    final tot = math.max(1, aInt(p['totalRegions'], 6));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$sat/$tot席', null),
    };
    return A15ProgressTile(
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
    required List<Map<String, dynamic>> clues,
    required List<int> clueGridFlat,
    required List<int> clueIdFlat,
    required int regionCount,
    required List<int> board,
    required Set<int> satisfiedRegions,
    required Set<int> violatedRegions,
    required Set<int> nonRectCells,
    required Set<int> badProportionCells,
    required Set<int> fourCornerVertices,
    required Set<int> fourCornerCells,
    required int satisfiedRegionCount,
    required int totalRegions,
    required int assignedCount,
    required int totalCells,
    required bool wide,
  }) {
    final cellPx = size <= 5 ? 50.0 : 44.0;
    final gridSpan = size * cellPx;
    final vSize = size + 1;
    final conflictCells = {
      ...nonRectCells,
      ...badProportionCells,
      ...fourCornerCells,
    };

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
                          regionCount: regionCount,
                          board: board,
                          clueGridFlat: clueGridFlat,
                          clueIdFlat: clueIdFlat,
                          conflictCells: conflictCells,
                          satisfiedRegions: satisfiedRegions,
                        ),
                    ],
                  ),
              ],
            ),
            // Highlight any 4-corner violation vertices
            for (final vIdx in fourCornerVertices)
              () {
                final vr = vIdx ~/ vSize;
                final vc = vIdx % vSize;
                final vx = vc * cellPx;
                final vy = vr * cellPx;
                return Positioned(
                  left: vx - 9,
                  top: vy - 9,
                  child: IgnorePointer(
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.8),
                      ),
                      child: const Text(
                        '×',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0),
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
              A15Chip('榻榻米 $satisfiedRegionCount/$totalRegions', const Color(0xFF00897B), size: 11),
              A15Chip('已铺 $assignedCount/$totalCells', cs.primary, size: 11),
              A15Chip(
                conflictCells.isEmpty
                    ? '✓ 无四席交点/比例正常'
                    : (fourCornerVertices.isNotEmpty ? '⚠ 四席十字交点' : '⚠ 矩形/比例冲突'),
                conflictCells.isEmpty ? Colors.green : Colors.redAccent,
                size: 11,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: const [
              A15Chip('+ 正方形 (W=H)', Color(0xFF475569), size: 10),
              A15Chip('- 横长 (W>H)', Color(0xFF475569), size: 10),
              A15Chip('| 竖长 (H>W)', Color(0xFF475569), size: 10),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            alignment: WrapAlignment.center,
            children: [
              for (var regId = 0; regId < regionCount; regId++)
                () {
                  final isAct = _activeRegion == regId;
                  final badgeCol = _regionBadgeColors[regId % _regionBadgeColors.length];
                  final isSat = satisfiedRegions.contains(regId);
                  final sym = regId < clues.length ? aStr(clues[regId]['sym']) : '';
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
                      onPressed: () => setState(() => _activeRegion = regId),
                      child: Text(
                        '${isSat ? "✓" : "#"}${regId + 1}($sym)',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
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
    required int regionCount,
    required List<int> board,
    required List<int> clueGridFlat,
    required List<int> clueIdFlat,
    required Set<int> conflictCells,
    required Set<int> satisfiedRegions,
  }) {
    final idx = r * size + c;
    final regId = idx < board.length ? board[idx] : -1;
    final assigned = regId >= 0 && regId < regionCount;
    final clueCode = idx < clueGridFlat.length ? clueGridFlat[idx] : 0;
    final clueId = idx < clueIdFlat.length ? clueIdFlat[idx] : -1;
    final isConflict = conflictCells.contains(idx);
    final isSat = assigned && satisfiedRegions.contains(regId);

    int regAt(int rr, int cc) {
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
      final base = _regionBgColors[regId % _regionBgColors.length];
      bgColor = isSat ? Color.alphaBlend(const Color(0x222E7D32), base) : base;
    } else {
      bgColor = const Color(0xFF1E293B);
    }

    final symText = switch (clueCode) {
      1 => '＋',
      2 => '－',
      3 => '｜',
      _ => '',
    };

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onCellTap(r, c, regId, clueId, regionCount),
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
            top: assigned && regAt(r - 1, c) != regId ? wallBorder : innerBorder,
            bottom: assigned && regAt(r + 1, c) != regId ? wallBorder : innerBorder,
            left: assigned && regAt(r, c - 1) != regId ? wallBorder : innerBorder,
            right: assigned && regAt(r, c + 1) != regId ? wallBorder : innerBorder,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (clueCode > 0 && clueId >= 0)
              Container(
                width: cellPx * 0.66,
                height: cellPx * 0.66,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _regionBadgeColors[clueId % _regionBadgeColors.length],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _activeRegion == clueId ? const Color(0xFF00E5FF) : Colors.white,
                    width: _activeRegion == clueId ? 2.4 : 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      symText,
                      style: TextStyle(
                        fontSize: cellPx * 0.30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      '#${clueId + 1}',
                      style: TextStyle(
                        fontSize: cellPx * 0.16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white70,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            if (assigned && clueId < 0)
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 3, bottom: 2),
                  child: Text(
                    '#${regId + 1}',
                    style: TextStyle(
                      fontSize: cellPx * 0.21,
                      fontWeight: FontWeight.w800,
                      color: isConflict
                          ? const Color(0xFFB71C1C)
                          : _regionBadgeColors[regId % _regionBadgeColors.length].withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
