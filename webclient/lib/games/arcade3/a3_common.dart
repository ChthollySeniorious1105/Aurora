import 'package:flutter/material.dart';

import '../../widgets/common.dart';

/// Shared helpers for the arcade3 boards.

int aInt(Object? o, [int d = -1]) => o is num ? o.toInt() : d;
List<int> aInts(Object? o) => o is List ? [for (final e in o) aInt(e)] : <int>[];
List<String> aStrs(Object? o) => o is List ? [for (final e in o) aStr(e)] : <String>[];
Map<String, dynamic>? aMap(Object? o) => o is Map ? o.cast<String, dynamic>() : null;
List<Map<String, dynamic>> aMaps(Object? o) =>
    o is List ? [for (final e in o) if (e is Map) e.cast<String, dynamic>()] : <Map<String, dynamic>>[];
String aStr(Object? o) => o is String ? o : '';

String mmss(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

/// Top status line, scaled down when narrow.
Widget aStatus(String text, {bool highlight = false}) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: FittedBox(fit: BoxFit.scaleDown, child: StatusBar(text, highlight: highlight)),
    );

/// Final ranking banner (rows of {'s', 'rank', ...}), scrollable if needed.
Widget aRanking(GameContext g, List<Map<String, dynamic>> rows, String Function(Map<String, dynamic>) sub,
    {Alignment alignment = Alignment.center}) {
  final me = rows.where((r) => r['s'] == g.seat).firstOrNull;
  final title = me == null
      ? '游戏结束'
      : (me['rank'] == 1 ? '你赢了！' : '游戏结束 · 你是第 ${me['rank']} 名');
  return Align(
    alignment: alignment,
    child: SingleChildScrollView(
      child: ResultBanner(
        title,
        child: Wrap(spacing: 10, runSpacing: 6, alignment: WrapAlignment.center, children: [
          for (final r in rows)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(r['rank'] == 1 ? '🏆 ' : '#${r['rank']} ', style: const TextStyle(fontWeight: FontWeight.bold)),
              Flexible(child: g.tag(aInt(r['s']), size: 26, sub: sub(r), active: r['rank'] == 1)),
            ]),
        ]),
      ),
    ),
  );
}

///Small colored pill label.
class A3Chip extends StatelessWidget {
  final String text;
  final Color color;
  final double size;
  const A3Chip(this.text, this.color, {super.key, this.size = 11});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Text(text, maxLines: 1, style: TextStyle(fontSize: size, color: Colors.white, fontWeight: FontWeight.bold)),
      );
}

/// Compact player progress tile used by Math24 and MjConnect.
class A3ProgressTile extends StatelessWidget {
  final GameContext g;
  final int seat;
  final double pct;
  final String sub;
  final String? badge;
  final Color? badgeColor;
  final bool dim;
  final double width;
  const A3ProgressTile(
    this.g,
    this.seat, {
    super.key,
    required this.pct,
    required this.sub,
    this.badge,
    this.badgeColor,
    this.dim = false,
    this.width = 148,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: seat == g.seat ? cs.primary : cs.outline.withValues(alpha: 0.3),
          width: seat == g.seat ? 2 : 1,
        ),
      ),
      child: Opacity(
        opacity: dim ? 0.5 : 1,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: g.tag(seat, size: 22))),
            if (badge != null) A3Chip(badge!, badgeColor ?? cs.primary, size: 10),
          ]),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: cs.onSurface.withValues(alpha: 0.12),
              color: badgeColor ?? cs.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.82)),
          ),
        ]),
      ),
    );
  }
}

/// Gives the board keyboard focus and forwards key events.
class A3Keys extends StatefulWidget {
  final Widget child;
  final KeyEventResult Function(FocusNode node, KeyEvent event) onKeyEvent;
  const A3Keys({super.key, required this.child, required this.onKeyEvent});
  @override
  State<A3Keys> createState() => _A3KeysState();
}

class _A3KeysState extends State<A3Keys> {
  final _node = FocusNode(debugLabel: 'arcade3');
  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
        focusNode: _node,
        autofocus: true,
        onKeyEvent: widget.onKeyEvent,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            if (!_node.hasFocus) _node.requestFocus();
          },
          child: widget.child,
        ),
      );
}
