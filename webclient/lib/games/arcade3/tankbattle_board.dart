import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/common.dart';
import 'a3_common.dart';

const _tankColors = [
  Color(0xFFFFCA28), // Gold/Yellow
  Color(0xFF42A5F5), // Blue
  Color(0xFFEF5350), // Red
  Color(0xFF66BB6A), // Green
];
const _tankDarkColors = [
  Color(0xFFF57F17),
  Color(0xFF1565C0),
  Color(0xFFB71C1C),
  Color(0xFF2E7D32),
];
const _tankColorNames = ['黄', '蓝', '红', '绿'];

class TankBattleBoard extends StatefulWidget {
  final GameContext g;
  const TankBattleBoard(this.g, {super.key});
  @override
  State<TankBattleBoard> createState() => _TankBattleBoardState();
}

class _TankBattleBoardState extends State<TankBattleBoard> {
  GameContext get g => widget.g;
  final Set<int> _held = {};
  int? _sentDir;

  bool get _canPlay {
    final ps = aMaps(g.view['ps']);
    return !g.over && g.seat >= 0 && g.seat < ps.length && ps[g.seat]['al'] == true;
  }

  void _sendDir(int? d) {
    if (!_canPlay) return;
    if (d == null) {
      if (_sentDir == null) return;
      _sentDir = null;
      g.act({'type': 'move', 'dir': 'none'});
      return;
    }
    _sentDir = d;
    g.act({'type': 'move', 'dir': d});
  }

  void _fire() {
    if (!_canPlay) return;
    g.act({'type': 'fire'});
  }

  void _press(int d) {
    _held.remove(d);
    _held.add(d);
    _sendDir(d);
  }

  void _release(int d) {
    _held.remove(d);
    _sendDir(_held.isEmpty ? null : _held.last);
  }

  static final _keyDirs = {
    LogicalKeyboardKey.arrowUp: 0,
    LogicalKeyboardKey.keyW: 0,
    LogicalKeyboardKey.arrowRight: 1,
    LogicalKeyboardKey.keyD: 1,
    LogicalKeyboardKey.arrowDown: 2,
    LogicalKeyboardKey.keyS: 2,
    LogicalKeyboardKey.arrowLeft: 3,
    LogicalKeyboardKey.keyA: 3,
  };

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    final d = _keyDirs[e.logicalKey];
    if (d != null) {
      if (e is KeyDownEvent) _press(d);
      if (e is KeyUpEvent) _release(d);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.space ||
        e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.keyJ) {
      if (e is KeyDownEvent) _fire();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final ps = aMaps(v['ps']);
    final phase = aStr(v['phase']);
    final w = aInt(v['w'], 15), h = aInt(v['h'], 15);
    final left = aInt(v['left'], 0);
    final tickMs = aInt(v['tickMs'], 100);
    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final meAlive = me?['al'] == true;

    String status;
    if (phase == 'over') {
      status = '游戏结束';
    } else if (phase == 'countdown') {
      final sec = (aInt(v['cd'], 0) * tickMs / 1000).ceil();
      status = '准备出击… $sec   你是 ${g.seat >= 0 ? '${_tankColorNames[g.seat % 4]}色坦克' : '观众'}';
    } else if (g.seat < 0) {
      status = '观战中 · 剩余 ${mmss(left)}';
    } else if (!meAlive) {
      status = '你的坦克已被击毁 · 剩余 ${mmss(left)}';
    } else {
      status = '方向键/WASD 移动 · 空格 开火 · ❤️${me?['lv']} ⭐${me?['st']} · 剩余 ${mmss(left)}';
    }

    return A3Keys(
      onKeyEvent: _onKey,
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth > box.maxHeight * 1.15;
        final showPad = me != null && meAlive && phase != 'over';
        final sideW = wide ? math.min(210.0, box.maxWidth * 0.24) : 0.0;
        final padW = wide && showPad ? math.min(190.0, box.maxWidth * 0.24) : 0.0;
        final padH = !wide && showPad ? 148.0 : 0.0;
        final listH = wide ? 0.0 : 54.0;
        final availW = box.maxWidth - sideW - padW - 12;
        final availH = box.maxHeight - 44 - padH - listH;
        final cellSize = math.max(4.0, math.min(availW / w, availH / h));

        final arena = SizedBox(
          width: cellSize * w,
          height: cellSize * h,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _TankArenaPainter(
                w: w,
                h: h,
                grid: aStr(v['g']),
                items: aMaps(v['items']),
                bullets: aMaps(v['bullets']),
                blasts: v['blasts'] is List ? v['blasts'] as List : const [],
                ps: ps,
                me: g.seat,
              ),
            ),
          ),
        );

        final tags = Wrap(
          direction: wide ? Axis.vertical : Axis.horizontal,
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final s in g.seatsFromMe())
              if (s < ps.length) _TankPlayerTag(g, s, ps[s]),
          ],
        );

        final pad = _TankControls(
          onPress: _press,
          onRelease: _release,
          onFire: _fire,
          compact: wide,
        );

        Widget body;
        if (wide) {
          body = Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(
              width: sideW,
              child: SingleChildScrollView(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: tags))),
            ),
            arena,
            if (showPad) SizedBox(width: padW, child: Center(child: pad)),
          ]);
        } else {
          body = Column(children: [
            SizedBox(height: listH, child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: tags))),
            Expanded(child: Center(child: arena)),
            if (showPad) SizedBox(height: padH, child: Center(child: pad)),
          ]);
        }

        return Column(children: [
          SizedBox(height: 40, child: aStatus(status, highlight: meAlive && phase == 'play')),
          Expanded(
            child: Stack(children: [
              Positioned.fill(child: body),
              if (phase == 'countdown')
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Text(
                        '${(aInt(v['cd'], 0) * tickMs / 1000).ceil()}',
                        style: const TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [Shadow(blurRadius: 12, color: Colors.black)],
                        ),
                      ),
                    ),
                  ),
                ),
              if (phase == 'over')
                Positioned.fill(
                  child: Container(
                    color: Colors.black38,
                    child: aRanking(
                      g,
                      aMaps(v['final']),
                      (r) => '击杀 ${r['kills']} · 积分 ${r['score']}${r['alive'] == true ? ' · 存活(${r['lives']}命)' : ''}',
                    ),
                  ),
                ),
            ]),
          ),
        ]);
      }),
    );
  }
}

class _TankPlayerTag extends StatelessWidget {
  final GameContext g;
  final int s;
  final Map<String, dynamic> p;
  const _TankPlayerTag(this.g, this.s, this.p);

  @override
  Widget build(BuildContext context) {
    final alive = p['al'] == true;
    final lv = aInt(p['lv'], 0);
    final st = aInt(p['st'], 0);
    final k = aInt(p['k'], 0);
    final sh = aInt(p['sh'], 0);
    final rf = p['rf'] == true;
    final buffs = '${sh > 0 ? "🛡️" : ""}${rf ? "⚡" : ""}${st > 0 ? "⭐×$st" : ""}';
    return Opacity(
      opacity: alive ? 1 : 0.45,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: _tankColors[s % 4],
            shape: BoxShape.circle,
            border: Border.all(color: _tankDarkColors[s % 4], width: 2),
          ),
        ),
        const SizedBox(width: 3),
        g.tag(
          s,
          size: 24,
          active: s == g.seat,
          sub: alive ? '❤️$lv 击杀$k $buffs' : '被击毁 · 击杀$k',
        ),
      ]),
    );
  }
}

class _TankControls extends StatelessWidget {
  final void Function(int) onPress, onRelease;
  final VoidCallback onFire;
  final bool compact;
  const _TankControls({
    required this.onPress,
    required this.onRelease,
    required this.onFire,
    this.compact = false,
  });

  Widget _key(BuildContext context, int d, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Listener(
      onPointerDown: (_) => onPress(d),
      onPointerUp: (_) => onRelease(d),
      onPointerCancel: (_) => onRelease(d),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38, offset: Offset(0, 2))],
        ),
        child: Icon(icon, color: cs.onPrimary, size: 30),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dpad = SizedBox(
      width: 150,
      height: 150,
      child: Stack(children: [
        Positioned(left: 51, top: 0, child: _key(context, 0, Icons.keyboard_arrow_up)),
        Positioned(left: 102, top: 51, child: _key(context, 1, Icons.keyboard_arrow_right)),
        Positioned(left: 51, top: 102, child: _key(context, 2, Icons.keyboard_arrow_down)),
        Positioned(left: 0, top: 51, child: _key(context, 3, Icons.keyboard_arrow_left)),
      ]),
    );
    final fireBtn = GestureDetector(
      onTapDown: (_) => onFire(),
      child: Container(
        width: 74,
        height: 74,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [Color(0xFFFF7043), Color(0xFFC62828)],
            center: Alignment(-0.3, -0.3),
          ),
          boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black45, offset: Offset(0, 3))],
        ),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.gps_fixed, color: Colors.white, size: 28),
          Text('开火', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
      ),
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: compact
          ? Column(mainAxisSize: MainAxisSize.min, children: [dpad, const SizedBox(height: 18), fireBtn])
          : Row(mainAxisSize: MainAxisSize.min, children: [dpad, const SizedBox(width: 48), fireBtn]),
    );
  }
}

class _TankArenaPainter extends CustomPainter {
  final int w, h, me;
  final String grid;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> bullets;
  final List blasts;
  final List<Map<String, dynamic>> ps;

  _TankArenaPainter({
    required this.w,
    required this.h,
    required this.grid,
    required this.items,
    required this.bullets,
    required this.blasts,
    required this.ps,
    required this.me,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.width / w;
    Rect rc(int i) => Rect.fromLTWH((i % w) * c, (i ~/ w) * c, c, c);
    Offset ctr(int i) => Offset((i % w + 0.5) * c, (i ~/ w + 0.5) * c);

    // 1. Dark battlefield floor
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(c * 0.25)),
      Paint()..color = const Color(0xFF1B2326),
    );
    final floorAlt = Paint()..color = const Color(0xFF222C30);
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1 + (y % 2); x < w - 1; x += 2) {
        canvas.drawRect(Rect.fromLTWH(x * c, y * c, c, c), floorAlt);
      }
    }

    // 2. Terrain (except grass '~', which renders over tanks for concealment)
    final steelBase = Paint()..color = const Color(0xFF546E7A);
    final steelPlate = Paint()..color = const Color(0xFFB0BEC5);
    final brickPaint = Paint()..color = const Color(0xFFB85D3B);
    final mortarPaint = Paint()
      ..color = const Color(0xFF6D321B)
      ..strokeWidth = math.max(1, c * 0.05)
      ..style = PaintingStyle.stroke;
    final waterPaint = Paint()..color = const Color(0xFF0277BD);
    final wavePaint = Paint()
      ..color = const Color(0xFF81D4FA).withValues(alpha: 0.65)
      ..strokeWidth = math.max(1, c * 0.06)
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < grid.length && i < w * h; i++) {
      final ch = grid[i];
      final r = rc(i);
      if (ch == '#') {
        canvas.drawRect(r, steelBase);
        final inner = r.deflate(c * 0.12);
        canvas.drawRRect(RRect.fromRectAndRadius(inner, Radius.circular(c * 0.08)), steelPlate);
      } else if (ch == '+') {
        final rr = r.deflate(c * 0.03);
        canvas.drawRRect(RRect.fromRectAndRadius(rr, Radius.circular(c * 0.06)), brickPaint);
        canvas.drawLine(Offset(rr.left, rr.top + rr.height / 2), Offset(rr.right, rr.top + rr.height / 2), mortarPaint);
        canvas.drawLine(Offset(rr.left + rr.width / 2, rr.top), Offset(rr.left + rr.width / 2, rr.top + rr.height / 2), mortarPaint);
        canvas.drawLine(Offset(rr.left + rr.width / 4, rr.top + rr.height / 2), Offset(rr.left + rr.width / 4, rr.bottom), mortarPaint);
      } else if (ch == 'w') {
        canvas.drawRect(r, waterPaint);
        canvas.drawLine(Offset(r.left + c * 0.18, r.top + c * 0.35), Offset(r.right - c * 0.18, r.top + c * 0.35), wavePaint);
        canvas.drawLine(Offset(r.left + c * 0.25, r.top + c * 0.68), Offset(r.right - c * 0.15, r.top + c * 0.68), wavePaint);
      }
    }

    // 3. Power-up items
    for (final it in items) {
      final idx = aInt(it['c']);
      if (idx < 0 || idx >= w * h) continue;
      final t = aStr(it['t']);
      final r = rc(idx).deflate(c * 0.1);
      final (col, sym) = switch (t) {
        'S' => (const Color(0xFF1E88E5), '🛡️'),
        'F' => (const Color(0xFFFF8F00), '⚡'),
        'U' => (const Color(0xFF8E24AA), '⭐'),
        _ => (const Color(0xFF43A047), '🔧'),
      };
      final rr = RRect.fromRectAndRadius(r, Radius.circular(c * 0.18));
      canvas.drawRRect(rr, Paint()..color = col);
      canvas.drawRRect(
        rr,
        Paint()
          ..color = Colors.white70
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, c * 0.05),
      );
      _drawText(canvas, sym, r.center, c * 0.46);
    }

    // 4. Tanks
    for (var s = 0; s < ps.length; s++) {
      final p = ps[s];
      if (p['al'] != true) continue;
      final idx = aInt(p['c']);
      if (idx < 0 || idx >= w * h) continue;
      _drawTank(
        canvas,
        ctr(idx),
        c,
        s,
        aInt(p['d'], 0),
        s == me,
        aInt(p['sh'], 0) > 0,
        aInt(p['st'], 0),
      );
    }

    // 5. Bullets
    for (final b in bullets) {
      final idx = aInt(b['c']);
      if (idx < 0 || idx >= w * h) continue;
      final o = ctr(idx);
      final power = aInt(b['p'], 1);
      canvas.drawCircle(o, c * (power >= 2 ? 0.2 : 0.14), Paint()..color = power >= 2 ? const Color(0xFFFF5252) : const Color(0xFFFFF176));
      canvas.drawCircle(o, c * 0.07, Paint()..color = Colors.white);
    }

    // 6. Grass overlay '~' (drawn above tanks for bush concealment)
    final grassPaint = Paint()..color = const Color(0xFF2E7D32).withValues(alpha: 0.78);
    final leafPaint = Paint()..color = const Color(0xFF66BB6A).withValues(alpha: 0.85);
    for (var i = 0; i < grid.length && i < w * h; i++) {
      if (grid[i] != '~') continue;
      final r = rc(i).deflate(c * 0.06);
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(c * 0.2)), grassPaint);
      canvas.drawCircle(r.topLeft + Offset(c * 0.28, c * 0.28), c * 0.14, leafPaint);
      canvas.drawCircle(r.bottomRight - Offset(c * 0.28, c * 0.28), c * 0.14, leafPaint);
    }

    // 7. Blast flashes
    for (final bl in blasts) {
      if (bl is List && bl.length >= 2) {
        final idx = aInt(bl[0]);
        if (idx >= 0 && idx < w * h) {
          final o = ctr(idx);
          canvas.drawCircle(o, c * 0.42, Paint()..color = const Color(0xFFFF6D00).withValues(alpha: 0.75));
          canvas.drawCircle(o, c * 0.24, Paint()..color = const Color(0xFFFFEE58));
        }
      }
    }
  }

  void _drawTank(Canvas canvas, Offset center, double c, int s, int dir, bool isMe, bool shielded, int stars) {
    final col = _tankColors[s % 4];
    final dark = _tankDarkColors[s % 4];
    if (isMe) {
      canvas.drawCircle(center, c * 0.48, Paint()..color = Colors.white.withValues(alpha: 0.22));
    }
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(dir * math.pi / 2);

    // Treads
    final treadPaint = Paint()..color = const Color(0xFF37474F);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(-c * 0.3, 0), width: c * 0.16, height: c * 0.74), Radius.circular(c * 0.04)),
      treadPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c * 0.3, 0), width: c * 0.16, height: c * 0.74), Radius.circular(c * 0.04)),
      treadPaint,
    );

    // Hull
    final hull = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: c * 0.52, height: c * 0.62),
      Radius.circular(c * 0.1),
    );
    canvas.drawRRect(hull, Paint()..color = dark);
    canvas.drawRRect(hull.deflate(c * 0.04), Paint()..color = col);

    // Gun barrel pointing up (0 rad)
    final barrelW = stars >= 2 ? c * 0.16 : c * 0.11;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, -c * 0.28), width: barrelW, height: c * 0.44),
        Radius.circular(c * 0.03),
      ),
      Paint()..color = const Color(0xFFECEFF1),
    );

    // Turret dome
    canvas.drawCircle(Offset.zero, c * 0.18, Paint()..color = dark);
    canvas.drawCircle(Offset.zero, c * 0.13, Paint()..color = col);
    canvas.restore();

    if (shielded) {
      canvas.drawCircle(
        center,
        c * 0.46,
        Paint()
          ..color = const Color(0xFF40C4FF).withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, c * 0.07),
      );
    }
  }

  void _drawText(Canvas canvas, String text, Offset center, double size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size, fontFamilyFallback: kFontFallback)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_TankArenaPainter oldDelegate) => true;
}
