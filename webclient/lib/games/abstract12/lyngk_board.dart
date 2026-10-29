import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<Color> _kLyngkColors = [
  Color(0xFF1E88E5), // 0: 蓝 Blue
  Color(0xFFE53935), // 1: 红 Red
  Color(0xFF43A047), // 2: 绿 Green
  Color(0xFF263238), // 3: 黑 Black
  Color(0xFFFFB300), // 4: 金黄 Gold
  Color(0xFFF5F5F5), // 5: 白百搭 White Wildcard
];

const List<String> _kLyngkColorLabels = ['蓝', '红', '绿', '黑', '金', '百搭'];

class LyngkBoard extends StatefulWidget {
  final GameContext g;
  const LyngkBoard(this.g, {super.key});

  @override
  State<LyngkBoard> createState() => _LyngkBoardState();
}

class _LyngkBoardState extends State<LyngkBoard> {
  int? _selectedFrom;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true;
    final myTurn = !over && g.seat == turn;

    final rawCoords = (v['coords'] as List?) ?? const [];
    final coords = <(int, int)>[
      for (final c in rawCoords)
        if (c is List && c.length >= 2) ((c[0] as num).toInt(), (c[1] as num).toInt()),
    ];

    final rawStacks = (v['stacks'] as List?) ?? const [];
    final stacks = <List<int>>[
      for (final s in rawStacks)
        if (s is List) [for (final x in s) (x as num).toInt()] else const <int>[],
    ];

    final ownerOfColor = <int>[
      for (final x in (v['ownerOfColor'] as List? ?? const [-1, -1, -1, -1, -1])) (x as num).toInt(),
    ];

    final rawClaimed = (v['claimedColors'] as List?) ?? const [[], []];
    final claimedColors = <List<int>>[
      for (var p = 0; p < 2; p++)
        if (p < rawClaimed.length && rawClaimed[p] is List)
          [for (final x in rawClaimed[p] as List) (x as num).toInt()]
        else
          const <int>[],
    ];

    final scoreStacks = <int>[
      for (final x in (v['scoreStacks'] as List? ?? const [0, 0])) (x as num).toInt(),
    ];

    final claimableColors = <int>[
      for (final x in (v['claimableColors'] as List? ?? const [])) (x as num).toInt(),
    ];

    final rawMoves = (v['legalMoves'] as Map?) ?? const {};
    final legalMoves = <int, List<int>>{};
    for (final entry in rawMoves.entries) {
      final k = int.tryParse('${entry.key}');
      if (k != null && entry.value is List) {
        legalMoves[k] = [for (final x in entry.value as List) (x as num).toInt()];
      }
    }

    if (_selectedFrom != null && !legalMoves.containsKey(_selectedFrom)) {
      _selectedFrom = null;
    }

    final lastMove = v['lastMove'] as Map?;
    final result = v['result'] as String?;

    String statusText;
    if (over) {
      statusText = result ?? '游戏结束';
    } else if (myTurn) {
      statusText = _selectedFrom == null
          ? '轮到你：可先声明 1 种中立颜色，或点击棋盘叠堆进行移动'
          : '已选中起点 #$_selectedFrom，请点击高亮目标格合并叠堆';
    } else {
      statusText = '等待 ${g.name(turn)} 行动…';
    }

    return Container(
      color: g.table,
      padding: const EdgeInsets.all(6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            children: [
              // Top bar: Player tags & status
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildPlayerSummary(g, 0, turn == 0 && !over, scoreStacks, claimedColors),
                  StatusBar(statusText, highlight: myTurn),
                  _buildPlayerSummary(g, 1, turn == 1 && !over, scoreStacks, claimedColors),
                ],
              ),
              const SizedBox(height: 4),
              // Shared Color Claiming Bar
              _buildColorClaimBar(context, g, myTurn, ownerOfColor, claimableColors),
              const SizedBox(height: 4),
              // Hex Board
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final side = min(constraints.maxWidth, constraints.maxHeight);
                    if (side <= 0 || coords.isEmpty) return const SizedBox();
                    return Center(
                      child: SizedBox(
                        width: side,
                        height: side,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (details) => _onBoardTap(
                            details.localPosition,
                            Size(side, side),
                            coords,
                            myTurn,
                            legalMoves,
                            g,
                          ),
                          child: CustomPaint(
                            size: Size(side, side),
                            painter: _LyngkBoardPainter(
                              coords: coords,
                              stacks: stacks,
                              ownerOfColor: ownerOfColor,
                              selectedFrom: _selectedFrom,
                              legalMoves: legalMoves,
                              lastMove: lastMove,
                              myTurn: myTurn,
                              colorScheme: Theme.of(context).colorScheme,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (over && result != null) ResultBanner(result),
        ],
      ),
    );
  }

  Widget _buildPlayerSummary(
    GameContext g,
    int seat,
    bool active,
    List<int> scoreStacks,
    List<List<int>> claimedColors,
  ) {
    final pts = seat < scoreStacks.length ? scoreStacks[seat] : 0;
    final cols = seat < claimedColors.length ? claimedColors[seat] : const <int>[];
    final colStr = cols.isEmpty ? '未声明颜色' : cols.map((c) => _kLyngkColorLabels[c]).join('·');
    return g.tag(
      seat,
      active: active,
      sub: '5层塔:$pts | 颜色:$colStr',
      size: 32,
    );
  }

  Widget _buildColorClaimBar(
    BuildContext context,
    GameContext g,
    bool myTurn,
    List<int> ownerOfColor,
    List<int> claimableColors,
  ) {
    final cs = Theme.of(context).colorScheme;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var c = 0; c < 5; c++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _buildColorChip(context, g, c, ownerOfColor, myTurn && claimableColors.contains(c), cs),
            ),
        ],
      ),
    );
  }

  Widget _buildColorChip(
    BuildContext context,
    GameContext g,
    int colorIdx,
    List<int> ownerOfColor,
    bool canClaim,
    ColorScheme cs,
  ) {
    final owner = colorIdx < ownerOfColor.length ? ownerOfColor[colorIdx] : -1;
    final ownerLabel = owner == -1 ? '中立' : g.name(owner);
    final pieceColor = _kLyngkColors[colorIdx];
    final fg = colorIdx == 4 ? Colors.black87 : Colors.white;

    return Material(
      color: cs.surface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: canClaim ? () => g.act({'type': 'claim', 'color': colorIdx}) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: canClaim ? cs.primary : cs.outline.withValues(alpha: 0.35),
              width: canClaim ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: pieceColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white70, width: 1),
                ),
                child: Text(
                  _kLyngkColorLabels[colorIdx],
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fg),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                canClaim ? '$ownerLabel(点此声明)' : ownerLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: canClaim ? FontWeight.bold : FontWeight.normal,
                  color: canClaim ? cs.primary : cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onBoardTap(
    Offset pos,
    Size size,
    List<(int, int)> coords,
    bool myTurn,
    Map<int, List<int>> legalMoves,
    GameContext g,
  ) {
    if (!myTurn) return;
    final hit = _LyngkBoardPainter.hitTestCell(pos, size, coords);
    if (hit == null) {
      setState(() => _selectedFrom = null);
      return;
    }

    if (_selectedFrom != null) {
      final targets = legalMoves[_selectedFrom] ?? const [];
      if (targets.contains(hit)) {
        final from = _selectedFrom!;
        setState(() => _selectedFrom = null);
        g.act({'type': 'move', 'from': from, 'to': hit});
        return;
      }
    }

    if (legalMoves.containsKey(hit)) {
      setState(() {
        _selectedFrom = (_selectedFrom == hit) ? null : hit;
      });
    } else {
      setState(() => _selectedFrom = null);
    }
  }
}

class _LyngkBoardPainter extends CustomPainter {
  final List<(int, int)> coords;
  final List<List<int>> stacks;
  final List<int> ownerOfColor;
  final int? selectedFrom;
  final Map<int, List<int>> legalMoves;
  final Map? lastMove;
  final bool myTurn;
  final ColorScheme colorScheme;

  const _LyngkBoardPainter({
    required this.coords,
    required this.stacks,
    required this.ownerOfColor,
    required this.selectedFrom,
    required this.legalMoves,
    required this.lastMove,
    required this.myTurn,
    required this.colorScheme,
  });

  static Offset cellCenter(int q, int r, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final spacing = size.shortestSide / 9.2;
    // Pointy-top axial to pixel
    final x = cx + spacing * sqrt(3) * (q + r / 2.0);
    final y = cy + spacing * 1.5 * r;
    return Offset(x, y);
  }

  static int? hitTestCell(Offset pos, Size size, List<(int, int)> coords) {
    final radius = size.shortestSide / 15.0;
    int? bestIdx;
    var bestDist = radius * 1.35;
    for (var i = 0; i < coords.length; i++) {
      final (q, r) = coords[i];
      final c = cellCenter(q, r, size);
      final d = (pos - c).distance;
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final coordMap = <(int, int), Offset>{
      for (final (q, r) in coords) (q, r): cellCenter(q, r, size),
    };

    // Draw board background disc
    final bgPaint = Paint()
      ..color = colorScheme.surface.withValues(alpha: 0.32)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.shortestSide * 0.48, bgPaint);

    // Draw grid lines between adjacent axial coordinates
    final linePaint = Paint()
      ..color = colorScheme.onSurface.withValues(alpha: 0.22)
      ..strokeWidth = 1.5;

    const dirs = [(1, 0), (0, 1), (1, -1)];
    for (final (q, r) in coords) {
      final p1 = coordMap[(q, r)]!;
      for (final (dq, dr) in dirs) {
        final p2 = coordMap[(q + dq, r + dr)];
        if (p2 != null) {
          canvas.drawLine(p1, p2, linePaint);
        }
      }
    }

    final targets = selectedFrom != null ? (legalMoves[selectedFrom] ?? const <int>[]) : const <int>[];
    final lastFrom = (lastMove?['from'] as num?)?.toInt();
    final lastTo = (lastMove?['to'] as num?)?.toInt();
    final cellRadius = size.shortestSide / 17.5;

    for (var i = 0; i < coords.length; i++) {
      final (q, r) = coords[i];
      final center = coordMap[(q, r)]!;
      final stack = i < stacks.length ? stacks[i] : const <int>[];
      final isSelected = selectedFrom == i;
      final isTarget = targets.contains(i);
      final isMovable = myTurn && legalMoves.containsKey(i);

      if (lastFrom == i || lastTo == i) {
        final hlPaint = Paint()
          ..color = Colors.amber.withValues(alpha: 0.35)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, cellRadius * 1.28, hlPaint);
      }

      if (stack.isEmpty) {
        canvas.drawCircle(
          center,
          cellRadius * 0.28,
          Paint()..color = colorScheme.onSurface.withValues(alpha: 0.35),
        );
        continue;
      }

      // Draw stack layers from bottom to top with slight vertical offset
      final h = stack.length;
      for (var layer = 0; layer < h; layer++) {
        final cIdx = stack[layer].clamp(0, 5);
        final layerCenter = center.translate(0, (h - 1 - layer) * 2.2 - (h - 1) * 1.1);
        final rLayer = cellRadius * (1.0 - (h - 1 - layer) * 0.04);
        canvas.drawCircle(
          layerCenter,
          rLayer,
          Paint()..color = _kLyngkColors[cIdx],
        );
        canvas.drawCircle(
          layerCenter,
          rLayer,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1,
        );
      }

      // Draw selection / target / movable ring
      if (isSelected) {
        canvas.drawCircle(
          center,
          cellRadius * 1.22,
          Paint()
            ..color = Colors.cyanAccent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.8,
        );
      } else if (isTarget) {
        canvas.drawCircle(
          center,
          cellRadius * 1.22,
          Paint()
            ..color = Colors.lightGreenAccent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.8,
        );
      } else if (isMovable && selectedFrom == null) {
        canvas.drawCircle(
          center,
          cellRadius * 1.12,
          Paint()
            ..color = colorScheme.primary.withValues(alpha: 0.65)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }

      // Label top piece color & stack height
      final topColor = stack.last.clamp(0, 5);
      final textColor = (topColor == 4 || topColor == 5) ? Colors.black87 : Colors.white;
      final label = h > 1 ? '${_kLyngkColorLabels[topColor]}$h' : _kLyngkColorLabels[topColor];
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: textColor,
            fontSize: cellRadius * 0.68,
            fontWeight: FontWeight.bold,
            fontFamilyFallback: kFontFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _LyngkBoardPainter oldDelegate) => true;
}
