import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class ZertzBoard extends StatefulWidget {
  final GameContext g;
  const ZertzBoard(this.g, {super.key});

  @override
  State<ZertzBoard> createState() => _ZertzBoardState();
}

class _ZertzBoardState extends State<ZertzBoard> {
  String _selectedColor = 'W';
  int? _placeCell;
  int? _captureFrom;

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  void _syncState() {
    final avail = ((v['availableColors'] as List?) ?? const []).cast<String>();
    if (avail.isNotEmpty && !avail.contains(_selectedColor)) {
      _selectedColor = avail.first;
    }
    final mustFrom = v['mustContinueFrom'] as int?;
    if (mustFrom != null) {
      _captureFrom = mustFrom;
    }
    final cells = (v['cells'] as List?) ?? const [];
    if (_placeCell != null) {
      if (_placeCell! < 0 || _placeCell! >= cells.length) {
        _placeCell = null;
      } else {
        final c = cells[_placeCell!] as Map;
        if (c['ring'] != true || c['marble'] != null) {
          _placeCell = null;
        }
      }
    }
  }

  void _onCellTap(int idx) {
    final turn = (v['turn'] as int?) ?? 0;
    final over = v['over'] == true || g.over;
    if (over || g.seat != turn) return;

    final cells = (v['cells'] as List?) ?? const [];
    if (idx < 0 || idx >= cells.length) return;
    final cell = cells[idx] as Map;
    if (cell['ring'] != true) return;

    final mustCapture = v['mustCapture'] == true;
    final legalCaps = ((v['legalCaptures'] as List?) ?? const []).cast<Map>();

    if (mustCapture) {
      final mustFrom = v['mustContinueFrom'] as int?;
      final activeFrom = mustFrom ?? _captureFrom;
      if (activeFrom != null) {
        final match = legalCaps.where((c) => c['from'] == activeFrom && c['to'] == idx).toList();
        if (match.isNotEmpty) {
          setState(() => _captureFrom = null);
          g.act({'type': 'capture', 'from': activeFrom, 'to': idx});
          return;
        }
      }
      if (mustFrom == null && legalCaps.any((c) => c['from'] == idx)) {
        setState(() => _captureFrom = idx);
      }
      return;
    }

    // Place marble & remove outer ring mode
    if (_placeCell == null) {
      if (cell['marble'] == null) {
        final freeOthers = _freeRingsExcluding(idx, cells);
        if (freeOthers.isEmpty) {
          // Only 1 ring left on the board: place immediately without needing removeCell
          g.act({
            'type': 'place',
            'color': _selectedColor,
            'placeCell': idx,
            'removeCell': -1,
          });
        } else {
          setState(() => _placeCell = idx);
        }
      }
      return;
    }

    if (idx == _placeCell) {
      setState(() => _placeCell = null);
      return;
    }

    final freeOthers = _freeRingsExcluding(_placeCell!, cells);
    if (freeOthers.contains(idx)) {
      final p = _placeCell!;
      setState(() => _placeCell = null);
      g.act({
        'type': 'place',
        'color': _selectedColor,
        'placeCell': p,
        'removeCell': idx,
      });
    } else if (cell['marble'] == null) {
      setState(() => _placeCell = idx);
    }
  }

  List<int> _freeRingsExcluding(int excludeIdx, List cells) {
    final rawFree = ((v['freeRings'] as List?) ?? const []).cast<int>();
    final filtered = rawFree.where((i) => i != excludeIdx).toList();
    if (filtered.isNotEmpty) return filtered;
    return [
      for (final c in cells)
        if ((c as Map)['index'] != excludeIdx && c['ring'] == true && c['marble'] == null)
          c['index'] as int,
    ];
  }

  @override
  Widget build(BuildContext context) {
    _syncState();
    final cs = Theme.of(context).colorScheme;
    final turn = (v['turn'] as int?) ?? 0;
    final over = v['over'] == true || g.over;
    final myTurn = !over && g.seat == turn;
    final mustCapture = v['mustCapture'] == true;
    final seats = g.seatsFromMe();
    final me = seats.first;
    final opp = seats.length > 1 ? seats[1] : 1 - me;

    String statusText;
    if (over) {
      statusText = (v['winReason'] as String?) ?? '对局结束';
    } else if (myTurn) {
      if (mustCapture) {
        statusText = _captureFrom == null ? '强制跳吃：请选择要起跳的弹珠' : '强制跳吃：请点击高亮的目标空环完成跳吃';
      } else if (_placeCell == null) {
        statusText = '你的回合：选择弹珠颜色并点击任意空环放入';
      } else {
        statusText = '第 2 步：请点击高亮的外圈自由空环将其移出';
      }
    } else {
      statusText = '等待 ${g.name(turn)} ${mustCapture ? "执行跳吃" : "放珠并移环"}…';
    }

    return Container(
      color: g.table,
      child: LayoutBuilder(builder: (context, c) {
        final isWide = c.maxWidth > c.maxHeight * 1.25;
        final boardWidget = _buildHexBoard(cs, myTurn, mustCapture);
        final sidePanel = _buildInfoAndControls(cs, statusText, myTurn, mustCapture, me, opp);

        return Stack(
          children: [
            if (isWide)
              Row(
                children: [
                  Expanded(child: Padding(padding: const EdgeInsets.all(8), child: boardWidget)),
                  SizedBox(
                    width: math.min(280, c.maxWidth * 0.38),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                      child: sidePanel,
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                    child: _buildCompactHeader(cs, statusText, myTurn, opp),
                  ),
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: boardWidget)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                    child: _buildCompactFooter(cs, myTurn, mustCapture, me),
                  ),
                ],
              ),
            if (over)
              Center(
                child: ResultBanner(
                  (v['winReason'] as String?) ?? '对局结束',
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildCompactHeader(ColorScheme cs, String statusText, bool myTurn, int opp) {
    final turn = (v['turn'] as int?) ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: StatusBar(statusText, highlight: myTurn),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Flexible(
              child: g.tag(
                opp,
                active: turn == opp,
                sub: _capturedSummary(opp),
                size: 32,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: _buildSupplyBadge(cs))),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactFooter(ColorScheme cs, bool myTurn, bool mustCapture, int me) {
    final turn = (v['turn'] as int?) ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!mustCapture)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: FittedBox(fit: BoxFit.scaleDown, child: _buildColorSelector(cs, myTurn)),
          ),
        Row(
          children: [
            Flexible(
              child: g.tag(
                me,
                active: turn == me,
                sub: _capturedSummary(me),
                size: 32,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: _buildGoalHint(cs))),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoAndControls(
    ColorScheme cs,
    String statusText,
    bool myTurn,
    bool mustCapture,
    int me,
    int opp,
  ) {
    final turn = (v['turn'] as int?) ?? 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
      ),
      child: LayoutBuilder(builder: (context, pc) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: pc.maxHeight > 20 ? pc.maxHeight - 20 : 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StatusBar(statusText, highlight: myTurn),
                    const SizedBox(height: 8),
                    g.tag(opp, active: turn == opp, sub: _capturedSummary(opp), size: 32),
                    const SizedBox(height: 8),
                    Center(child: FittedBox(fit: BoxFit.scaleDown, child: _buildSupplyBadge(cs))),
                    const SizedBox(height: 6),
                    Center(child: FittedBox(fit: BoxFit.scaleDown, child: _buildGoalHint(cs))),
                  ],
                ),
                if (!mustCapture)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: _buildColorSelector(cs, myTurn))),
                  ),
                g.tag(me, active: turn == me, sub: _capturedSummary(me), size: 32),
              ],
            ),
          ),
        );
      }),
    );
  }

  String _capturedSummary(int seat) {
    final caps = (v['captured'] as List?) ?? const [];
    if (seat < 0 || seat >= caps.length) return '';
    final m = caps[seat] as Map;
    return '俘获: 白${m['W'] ?? 0} 灰${m['G'] ?? 0} 黑${m['B'] ?? 0}';
  }

  Widget _buildSupplyBadge(ColorScheme cs) {
    final sup = (v['supply'] as Map?) ?? const {'W': 6, 'G': 8, 'B': 10};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('公共池: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSecondaryContainer)),
          _marbleDot(Colors.white, Colors.black87, '白${sup['W'] ?? 0}'),
          const SizedBox(width: 6),
          _marbleDot(const Color(0xFF8C96A6), Colors.white, '灰${sup['G'] ?? 0}'),
          const SizedBox(width: 6),
          _marbleDot(const Color(0xFF22262E), Colors.white, '黑${sup['B'] ?? 0}'),
        ],
      ),
    );
  }

  Widget _marbleDot(Color bg, Color fg, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black38),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _buildGoalHint(ColorScheme cs) {
    final goals = (v['goals'] as Map?) ?? const {'W': 4, 'G': 5, 'B': 6, 'EACH': 3};
    return Text(
      '胜机: ${goals['W']}白 / ${goals['G']}灰 / ${goals['B']}黑 / 各${goals['EACH']}',
      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
    );
  }

  Widget _buildColorSelector(ColorScheme cs, bool myTurn) {
    final avail = ((v['availableColors'] as List?) ?? const ['W', 'G', 'B']).cast<String>();
    final sup = (v['supply'] as Map?) ?? const {'W': 6, 'G': 8, 'B': 10};
    final items = [
      ('W', '白珠', Colors.white, Colors.black87, sup['W'] ?? 0),
      ('G', '灰珠', const Color(0xFF7D8796), Colors.white, sup['G'] ?? 0),
      ('B', '黑珠', const Color(0xFF22262E), Colors.white, sup['B'] ?? 0),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (code, label, bg, fg, count) in items)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: avail.contains(code) ? () => setState(() => _selectedColor = code) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: bg.withValues(alpha: avail.contains(code) ? 1.0 : 0.35),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _selectedColor == code ? cs.primary : Colors.black38,
                    width: _selectedColor == code ? 2.5 : 1,
                  ),
                  boxShadow: _selectedColor == code
                      ? [BoxShadow(color: cs.primary.withValues(alpha: 0.45), blurRadius: 6)]
                      : null,
                ),
                child: Text(
                  '$label($count)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: fg.withValues(alpha: avail.contains(code) ? 1.0 : 0.5),
                  ),
                ),
              ),
            ),
          ),
        if (_placeCell != null)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: TextButton.icon(
              onPressed: () => setState(() => _placeCell = null),
              icon: const Icon(Icons.undo, size: 15),
              label: const Text('重选落点', style: TextStyle(fontSize: 12)),
            ),
          ),
      ],
    );
  }

  Widget _buildHexBoard(ColorScheme cs, bool myTurn, bool mustCapture) {
    final cells = ((v['cells'] as List?) ?? const []).cast<Map>();
    if (cells.isEmpty) return const SizedBox();

    final legalCaps = ((v['legalCaptures'] as List?) ?? const []).cast<Map>();
    final mustFrom = v['mustContinueFrom'] as int?;
    final activeFrom = mustFrom ?? _captureFrom;
    final lastMove = v['lastMove'] as Map?;

    final jumpFromSet = <int>{for (final c in legalCaps) c['from'] as int};
    final jumpToSet = <int>{
      if (activeFrom != null)
        for (final c in legalCaps)
          if (c['from'] == activeFrom) c['to'] as int,
    };
    final freeSet = (_placeCell != null && !mustCapture)
        ? _freeRingsExcluding(_placeCell!, cells).toSet()
        : const <int>{};

    return LayoutBuilder(builder: (context, bc) {
      final w = bc.maxWidth;
      final h = bc.maxHeight;
      if (w <= 10 || h <= 10) return const SizedBox();

      // Compute normalized unit coordinates for each cell
      final sqrt3 = math.sqrt(3);
      var minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;
      final unitCoords = <(double, double)>[];
      for (final c in cells) {
        final q = (c['q'] as num).toDouble();
        final r = (c['r'] as num).toDouble();
        final ux = sqrt3 * (q + r * 0.5);
        final uy = 1.5 * r;
        unitCoords.add((ux, uy));
        if (ux < minX) minX = ux;
        if (ux > maxX) maxX = ux;
        if (uy < minY) minY = uy;
        if (uy > maxY) maxY = uy;
      }

      final spanX = (maxX - minX) + 2.4;
      final spanY = (maxY - minY) + 2.4;
      final radius = math.min(w / spanX, h / spanY);
      final centerU = ((minX + maxX) * 0.5, (minY + maxY) * 0.5);
      final cx0 = w * 0.5;
      final cy0 = h * 0.5;
      final ringSize = radius * 1.58;

      return SizedBox(
        width: w,
        height: h,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < cells.length; i++)
              if (cells[i]['ring'] == true)
                Builder(builder: (context) {
                  final cell = cells[i];
                  final idx = cell['index'] as int;
                  final (ux, uy) = unitCoords[i];
                  final px = cx0 + (ux - centerU.$1) * radius;
                  final py = cy0 + (uy - centerU.$2) * radius;
                  final marble = cell['marble'] as String?;
                  final isPlacePreview = _placeCell == idx && marble == null;
                  final isRemovableTarget = freeSet.contains(idx);
                  final isJumper = mustCapture && jumpFromSet.contains(idx);
                  final isSelectedJumper = mustCapture && activeFrom == idx;
                  final isJumpTarget = mustCapture && jumpToSet.contains(idx);
                  final isLast = lastMove != null &&
                      (lastMove['placeCell'] == idx || lastMove['to'] == idx);

                  return Positioned(
                    left: px - ringSize * 0.5,
                    top: py - ringSize * 0.5,
                    width: ringSize,
                    height: ringSize,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _onCellTap(idx),
                      child: CustomPaint(
                        painter: _ZertzRingPainter(
                          marble: isPlacePreview ? _selectedColor : marble,
                          isPreview: isPlacePreview,
                          isRemovableTarget: isRemovableTarget,
                          isJumper: isJumper,
                          isSelectedJumper: isSelectedJumper,
                          isJumpTarget: isJumpTarget,
                          isLast: isLast,
                          primaryColor: cs.primary,
                        ),
                      ),
                    ),
                  );
                }),
          ],
        ),
      );
    });
  }
}

class _ZertzRingPainter extends CustomPainter {
  final String? marble;
  final bool isPreview;
  final bool isRemovableTarget;
  final bool isJumper;
  final bool isSelectedJumper;
  final bool isJumpTarget;
  final bool isLast;
  final Color primaryColor;

  _ZertzRingPainter({
    required this.marble,
    required this.isPreview,
    required this.isRemovableTarget,
    required this.isJumper,
    required this.isSelectedJumper,
    required this.isJumpTarget,
    required this.isLast,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final outerR = size.width * 0.45;
    final holeR = outerR * 0.46;

    // Outer ring shadow
    canvas.drawCircle(
      center.translate(0, 2),
      outerR,
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    // Ring body
    final ringColor = isRemovableTarget
        ? const Color(0xFF4E6E58)
        : (isJumpTarget ? const Color(0xFF5D5330) : const Color(0xFF2B3240));
    canvas.drawCircle(
      center,
      outerR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.25),
          radius: 0.9,
          colors: [
            Color.lerp(ringColor, Colors.white, 0.22)!,
            ringColor,
            Color.lerp(ringColor, Colors.black, 0.35)!,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: outerR)),
    );

    // Highlight border for targets / jumpers / last move
    if (isSelectedJumper || isJumpTarget || isRemovableTarget || isJumper || isLast) {
      final borderCol = isSelectedJumper
          ? Colors.amberAccent
          : (isJumpTarget
              ? Colors.greenAccent
              : (isRemovableTarget
                  ? Colors.cyanAccent
                  : (isJumper ? Colors.orangeAccent : primaryColor)));
      canvas.drawCircle(
        center,
        outerR - 1.2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (isSelectedJumper || isJumpTarget || isRemovableTarget) ? 2.6 : 1.8
          ..color = borderCol,
      );
    } else {
      canvas.drawCircle(
        center,
        outerR - 0.8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = Colors.white.withValues(alpha: 0.18),
      );
    }

    // Inner recessed hole
    canvas.drawCircle(
      center,
      holeR,
      Paint()..color = const Color(0xFF141820),
    );

    // Draw Marble if present
    if (marble != null) {
      final mr = outerR * 0.68;
      final alpha = isPreview ? 0.65 : 1.0;
      final (lightCol, midCol, darkCol) = switch (marble) {
        'W' => (
            Colors.white.withValues(alpha: alpha),
            const Color(0xFFE6E9F0).withValues(alpha: alpha),
            const Color(0xFFA5B0C2).withValues(alpha: alpha),
          ),
        'G' => (
            const Color(0xFFC2CAD6).withValues(alpha: alpha),
            const Color(0xFF7D8796).withValues(alpha: alpha),
            const Color(0xFF434A54).withValues(alpha: alpha),
          ),
        _ => (
            const Color(0xFF5A6270).withValues(alpha: alpha),
            const Color(0xFF22262E).withValues(alpha: alpha),
            const Color(0xFF0B0D11).withValues(alpha: alpha),
          ),
      };

      canvas.drawCircle(
        center.translate(0, 1.5),
        mr,
        Paint()..color = Colors.black.withValues(alpha: 0.45 * alpha),
      );
      canvas.drawCircle(
        center,
        mr,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.35),
            radius: 0.85,
            colors: [lightCol, midCol, darkCol],
          ).createShader(Rect.fromCircle(center: center, radius: mr)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ZertzRingPainter old) =>
      old.marble != marble ||
      old.isPreview != isPreview ||
      old.isRemovableTarget != isRemovableTarget ||
      old.isJumper != isJumper ||
      old.isSelectedJumper != isSelectedJumper ||
      old.isJumpTarget != isJumpTarget ||
      old.isLast != isLast;
}
