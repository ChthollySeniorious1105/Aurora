import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

/// Responsive shell for the abstract4 boards.
/// Portrait: tags + status on top, board in the middle, [tray] and actions below.
/// Landscape: board on the left, side panel (tags, status, tray, actions, info) on the right.
class A4Shell extends StatelessWidget {
  final List<Widget> tags;
  final String status;
  final bool statusHighlight;
  final double aspect;
  final Widget board;
  final Widget? tray;
  final double trayFraction;
  final double? trayLandscapeHeight;
  final List<Widget> actions;
  final List<String> info;
  final String? result;
  final String? resultSub;

  const A4Shell({
    super.key,
    required this.tags,
    required this.status,
    this.statusHighlight = false,
    this.aspect = 1,
    required this.board,
    this.tray,
    this.trayFraction = 0.22,
    this.trayLandscapeHeight,
    this.actions = const [],
    this.info = const [],
    this.result,
    this.resultSub,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final landscape = c.maxWidth > c.maxHeight * 1.15;
      final boardBox = aspect <= 0 ? board : Center(child: AspectRatio(aspectRatio: aspect, child: board));
      final banner = result == null
          ? null
          : ResultBanner(result!, child: resultSub == null ? null : Text(resultSub!, textAlign: TextAlign.center));
      if (landscape) {
        final panelW = (c.maxWidth * 0.36).clamp(210.0, 390.0);
        return Row(children: [
          Expanded(
            child: Stack(children: [
              Positioned.fill(child: Padding(padding: const EdgeInsets.all(8), child: boardBox)),
              if (banner != null) Positioned(left: 0, right: 0, top: 0, child: Center(child: banner)),
            ]),
          ),
          SizedBox(
            width: panelW,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: max(52, c.maxHeight * 0.28)),
                  child: SingleChildScrollView(
                    child: Wrap(spacing: 6, runSpacing: 6, children: tags),
                  ),
                ),
                const SizedBox(height: 6),
                StatusBar(status, highlight: statusHighlight),
                if (tray != null) ...[
                  const SizedBox(height: 6),
                  if (trayLandscapeHeight != null)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: min(trayLandscapeHeight!, c.maxHeight * 0.36)),
                      child: tray!,
                    )
                  else
                    Expanded(flex: 3, child: tray!),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: actions),
                ],
                if (info.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Expanded(flex: tray == null || trayLandscapeHeight != null ? 3 : 2, child: A4Info(info)),
                ] else if (tray == null || trayLandscapeHeight != null)
                  const Spacer(),
              ]),
            ),
          ),
        ]);
      }
      return Column(children: [
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Wrap(spacing: 8, runSpacing: 4, alignment: WrapAlignment.center, children: tags),
        ),
        const SizedBox(height: 4),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: StatusBar(status, highlight: statusHighlight)),
        Expanded(
          child: Stack(children: [
            Positioned.fill(child: Padding(padding: const EdgeInsets.all(6), child: boardBox)),
            if (banner != null) Positioned(left: 0, right: 0, top: 0, child: Center(child: banner)),
          ]),
        ),
        if (tray != null) ConstrainedBox(constraints: BoxConstraints(maxHeight: c.maxHeight * trayFraction), child: tray!),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Wrap(spacing: 6, runSpacing: 4, alignment: WrapAlignment.center, children: actions),
          ),
        if (info.isNotEmpty) SizedBox(height: 44, child: A4Info(info)),
        const SizedBox(height: 4),
      ]);
    });
  }
}

class A4Info extends StatelessWidget {
  final List<String> lines;
  const A4Info(this.lines, {super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: cs.surface.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10)),
      child: SingleChildScrollView(
        child: Text(lines.join('\n'), style: TextStyle(fontSize: 12.5, color: cs.onSurface)),
      ),
    );
  }
}

class A4Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool highlight;
  const A4Panel({super.key, required this.child, this.padding = const EdgeInsets.all(6), this.highlight = false});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      padding: padding,
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? cs.primary : cs.outlineVariant.withValues(alpha: 0.5), width: highlight ? 2 : 1),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: child,
    );
  }
}

Widget a4Button(BuildContext context, String label, IconData icon, VoidCallback? onTap, {bool primary = false}) {
  const style = ButtonStyle(
    visualDensity: VisualDensity.compact,
    padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
  );
  return primary
      ? FilledButton.icon(style: style, onPressed: onTap, icon: Icon(icon, size: 16), label: Text(label))
      : FilledButton.tonalIcon(style: style, onPressed: onTap, icon: Icon(icon, size: 16), label: Text(label));
}

String? a4Banner(GameContext g, bool over, int winner, int players) {
  if (!over) return null;
  if (winner == players) return '和棋';
  if (winner < 0) return '对局结束';
  return winner == g.seat ? '你赢了！' : (g.seat >= 0 && g.seat < players ? '你输了' : '${g.name(winner)} 获胜');
}

TextPainter a4Text(String s, double size, Color color, {FontWeight weight = FontWeight.w700}) => TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              fontFamily: kFontFallback.first, fontFamilyFallback: kFontFallback, fontSize: size, color: color, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();

void a4PaintTextCentered(Canvas canvas, String s, Offset c, double size, Color color, {FontWeight weight = FontWeight.w700}) {
  final tp = a4Text(s, size, color, weight: weight);
  tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
}

Paint a4Shadow(double blur, {double alpha = 0.35}) => Paint()
  ..color = Colors.black.withValues(alpha: alpha)
  ..maskFilter = MaskFilter.blur(BlurStyle.normal, max(0.5, blur));
