import 'dart:math';

import 'package:aurora_shared/games/euro3/ticketride.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<Color> _kPlayerSeatColors = [
  Color(0xFFE53935), // P0 Red
  Color(0xFF1E88E5), // P1 Blue
  Color(0xFF43A047), // P2 Green
  Color(0xFFFFB300), // P3 Amber
  Color(0xFF8E24AA), // P4 Purple
];

Color _trainCardColor(String code) {
  switch (code) {
    case 'R':
      return const Color(0xFFD32F2F);
    case 'B':
      return const Color(0xFF1976D2);
    case 'G':
      return const Color(0xFF388E3C);
    case 'Y':
      return const Color(0xFFFBC02D);
    case 'K':
      return const Color(0xFF37474F);
    case 'P':
      return const Color(0xFF7B1FA2);
    case 'O':
      return const Color(0xFFF57C00);
    case 'C':
      return const Color(0xFFCFD8DC);
    case 'W':
      return const Color(0xFFEC407A);
    default:
      return const Color(0xFF9E9E9E);
  }
}

class TicketRideBoard extends StatefulWidget {
  final GameContext g;
  const TicketRideBoard(this.g, {super.key});

  @override
  State<TicketRideBoard> createState() => _TicketRideBoardState();
}

class _TicketRideBoardState extends State<TicketRideBoard> {
  final Set<int> _selectedTicketIdx = {0, 1};
  String _selectedPayColor = '';
  int _lastPendingCount = -1;

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final phase = '${v['phase'] ?? 'play'}';
    final drawsLeft = (v['drawsLeft'] as num?)?.toInt() ?? 2;
    final finalTurnsLeft = (v['finalTurnsLeft'] as num?)?.toInt();
    final market = (v['market'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final deckCount = (v['deckCount'] as num?)?.toInt() ?? 0;
    final ticketDeckCount = (v['ticketDeckCount'] as num?)?.toInt() ?? 0;
    final routeOwners =
        (v['routeOwners'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(kTicketRoutes.length, -1);
    final myHand = (v['myHand'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final myTickets = (v['myTickets'] as List?)?.cast<Map>() ?? const <Map>[];
    final pendingTickets = (v['pendingTickets'] as List?)?.cast<Map>() ?? const <Map>[];
    final pList = (v['players'] as List?)?.cast<Map>() ?? const <Map>[];
    final lastAction = '${v['lastAction'] ?? ''}';

    if (pendingTickets.length != _lastPendingCount) {
      _selectedTicketIdx
        ..clear()
        ..addAll([for (var i = 0; i < pendingTickets.length; i++) i]);
      _lastPendingCount = pendingTickets.length;
    }

    final isMyTurn = !g.over && g.seat == turn;
    final needKeepTickets = !g.over &&
        pendingTickets.isNotEmpty &&
        (phase == 'init_tickets' || (phase == 'keep_tickets' && isMyTurn));

    String statusText = lastAction;
    if (!g.over) {
      if (needKeepTickets) {
        final minKeep = phase == 'init_tickets' ? min(2, pendingTickets.length) : 1;
        statusText = '🎫 请选择要保留的车票任务（至少保留 $minKeep 张）';
      } else if (isMyTurn) {
        if (phase == 'draw2') {
          statusText = '🃏 请摸第 2 张车厢卡（不能拿明牌彩车头）';
        } else {
          statusText = '🚂 轮到你：摸车厢卡、修建地图上的铁路，或抽取新车票';
        }
      }
    }

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusBar(statusText, highlight: isMyTurn || needKeepTickets),
                      if (finalTurnsLeft != null && !g.over)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '⚠️ 最后一轮（剩余 $finalTurnsLeft 回合）',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildPlayersBar(cs, pList, turn),
                  const SizedBox(height: 6),
                  if (needKeepTickets)
                    _buildPendingTicketsPanel(cs, pendingTickets, phase == 'init_tickets' ? 2 : 1),
                  _buildRailwayMapCard(cs, routeOwners, myHand, isMyTurn && phase == 'play'),
                  const SizedBox(height: 6),
                  _buildMarketAndControls(
                    cs,
                    market: market,
                    deckCount: deckCount,
                    ticketDeckCount: ticketDeckCount,
                    phase: phase,
                    drawsLeft: drawsLeft,
                    isMyTurn: isMyTurn,
                    myHand: myHand,
                    routeOwners: routeOwners,
                  ),
                  const SizedBox(height: 6),
                  _buildMyHandAndTickets(cs, myHand, myTickets),
                ],
              ),
            ),
          ),
          if (g.over)
            Align(
              alignment: Alignment.center,
              child: _buildFinalBanner(cs),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayersBar(ColorScheme cs, List<Map> pList, int turn) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        for (final p in pList)
          Builder(builder: (context) {
            final s = (p['seat'] as num?)?.toInt() ?? 0;
            final cars = (p['cars'] as num?)?.toInt() ?? 0;
            final rScore = (p['routeScore'] as num?)?.toInt() ?? 0;
            final hCount = (p['handCount'] as num?)?.toInt() ?? 0;
            final tCount = (p['ticketCount'] as num?)?.toInt() ?? 0;
            final seatColor = _kPlayerSeatColors[s % _kPlayerSeatColors.length];
            final active = s == turn && !g.over;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: active ? seatColor : cs.outline.withValues(alpha: 0.3),
                  width: active ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: seatColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    g.name(s),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '🚂$cars ⭐$rScore 🃏$hCount 🎫$tCount',
                    style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildPendingTicketsPanel(ColorScheme cs, List<Map> pending, int minKeep) {
    final effectiveMin = min(minKeep, pending.length);
    final valid = _selectedTicketIdx.length >= effectiveMin;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < pending.length; i++)
                Builder(builder: (context) {
                  final t = pending[i];
                  final from = kTicketCities[(t['from'] as num).toInt()].name;
                  final to = kTicketCities[(t['to'] as num).toInt()].name;
                  final pts = t['points'];
                  final checked = _selectedTicketIdx.contains(i);
                  return FilterChip(
                    selected: checked,
                    label: Text('$from ↔ $to (+$pts分)'),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedTicketIdx.add(i);
                        } else {
                          _selectedTicketIdx.remove(i);
                        }
                      });
                    },
                  );
                }),
              FilledButton.icon(
                onPressed: valid
                    ? () => g.act({
                          'type': 'keep_tickets',
                          'indices': _selectedTicketIdx.toList()..sort(),
                        })
                    : null,
                icon: const Icon(Icons.check, size: 16),
                label: Text('确认保留 (${_selectedTicketIdx.length}/${pending.length})'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _clientClaimColors(int routeId, List<int> routeOwners, List<String> myHand) {
    if (routeOwners[routeId] != -1) return const [];
    final r = kTicketRoutes[routeId];
    final counts = <String, int>{};
    for (final c in myHand) {
      counts[c] = (counts[c] ?? 0) + 1;
    }
    final wilds = counts[kWildCard] ?? 0;
    if (r.color != kGreyRoute) {
      final have = (counts[r.color] ?? 0) + wilds;
      return have >= r.length ? [r.color] : const [];
    }
    final valid = <String>[];
    for (final c in kTrainColors) {
      final cnt = counts[c] ?? 0;
      if (cnt > 0 && cnt + wilds >= r.length) valid.add(c);
    }
    if (wilds >= r.length) valid.add(kWildCard);
    return valid;
  }

  Widget _buildRailwayMapCard(
    ColorScheme cs,
    List<int> routeOwners,
    List<String> myHand,
    bool canClaimNow,
  ) {
    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: const Color(0xFF1E272E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          return GestureDetector(
            onTapUp: canClaimNow
                ? (details) => _onMapTap(details.localPosition, c.biggest, routeOwners, myHand)
                : null,
            child: CustomPaint(
              size: c.biggest,
              painter: _RailwayMapPainter(routeOwners: routeOwners),
            ),
          );
        },
      ),
    );
  }

  void _onMapTap(
    Offset pos,
    Size size,
    List<int> routeOwners,
    List<String> myHand,
  ) {
    var bestRoute = -1;
    var bestDist = 18.0;
    for (final r in kTicketRoutes) {
      if (routeOwners[r.id] != -1) continue;
      final c1 = kTicketCities[r.from];
      final c2 = kTicketCities[r.to];
      final p1 = Offset(c1.x * size.width, c1.y * size.height);
      final p2 = Offset(c2.x * size.width, c2.y * size.height);
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2 + (r.slot == 1 ? 7 : 0));
      final d = (pos - mid).distance;
      if (d < bestDist) {
        bestDist = d;
        bestRoute = r.id;
      }
    }
    if (bestRoute >= 0) {
      final colors = _clientClaimColors(bestRoute, routeOwners, myHand);
      final chosen = _selectedPayColor.isNotEmpty && colors.contains(_selectedPayColor)
          ? _selectedPayColor
          : (colors.isNotEmpty ? colors.first : kTicketRoutes[bestRoute].color);
      g.act({'type': 'claim', 'route': bestRoute, 'color': chosen});
    }
  }

  Widget _buildMarketAndControls(
    ColorScheme cs, {
    required List<String> market,
    required int deckCount,
    required int ticketDeckCount,
    required String phase,
    required int drawsLeft,
    required bool isMyTurn,
    required List<String> myHand,
    required List<int> routeOwners,
  }) {
    final canDraw = isMyTurn && (phase == 'play' || phase == 'draw2');
    final canClaim = isMyTurn && phase == 'play';

    // Find claimable routes for quick buttons
    final claimableRoutes = <RouteDef>[];
    if (canClaim) {
      for (final r in kTicketRoutes) {
        if (_clientClaimColors(r.id, routeOwners, myHand).isNotEmpty) {
          claimableRoutes.add(r);
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('🃏 车厢市场：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              for (var i = 0; i < market.length; i++)
                _buildMarketCardButton(
                  index: i,
                  code: market[i],
                  enabled: canDraw && !(market[i] == kWildCard && drawsLeft < 2),
                ),
              FilledButton.tonalIcon(
                onPressed: canDraw && deckCount > 0 ? () => g.act({'type': 'draw_deck'}) : null,
                icon: const Icon(Icons.layers, size: 15),
                label: Text('盲抽 ($deckCount)', style: const TextStyle(fontSize: 12)),
              ),
              if (isMyTurn && phase == 'play')
                FilledButton.tonalIcon(
                  onPressed: ticketDeckCount > 0 ? () => g.act({'type': 'draw_tickets'}) : null,
                  icon: const Icon(Icons.confirmation_number, size: 15),
                  label: Text('抽车票 ($ticketDeckCount)', style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
          if (claimableRoutes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('🔨 可修线路：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                for (final r in claimableRoutes.take(8))
                  Builder(builder: (context) {
                    final c1 = kTicketCities[r.from].name;
                    final c2 = kTicketCities[r.to].name;
                    final colors = _clientClaimColors(r.id, routeOwners, myHand);
                    final chosen = colors.first;
                    return ActionChip(
                      visualDensity: VisualDensity.compact,
                      avatar: CircleAvatar(
                        backgroundColor: _trainCardColor(r.color),
                        radius: 6,
                      ),
                      label: Text(
                        '$c1-$c2 (${r.length}节/${kColorNames[r.color]})',
                        style: const TextStyle(fontSize: 11),
                      ),
                      onPressed: () => g.act({
                        'type': 'claim',
                        'route': r.id,
                        'color': chosen,
                      }),
                    );
                  }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMarketCardButton({
    required int index,
    required String code,
    required bool enabled,
  }) {
    final bg = _trainCardColor(code);
    final isLight = code == 'Y' || code == 'C';
    return InkWell(
      onTap: enabled ? () => g.act({'type': 'draw_market', 'index': index}) : null,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white54),
          ),
          child: Text(
            code == kWildCard ? '🌈彩车头' : '🚃${kColorNames[code]}',
            style: TextStyle(
              color: isLight ? Colors.black87 : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyHandAndTickets(ColorScheme cs, List<String> myHand, List<Map> myTickets) {
    final counts = <String, int>{};
    for (final c in myHand) {
      counts[c] = (counts[c] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('🎒 我的车厢手牌：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              if (counts.isEmpty)
                const Text('暂无手牌', style: TextStyle(fontSize: 11)),
              for (final entry in counts.entries)
                GestureDetector(
                  onTap: () => setState(() => _selectedPayColor = entry.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _trainCardColor(entry.key),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedPayColor == entry.key ? Colors.amberAccent : Colors.white38,
                        width: _selectedPayColor == entry.key ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      '${kColorNames[entry.key]} ×${entry.value}',
                      style: TextStyle(
                        color: (entry.key == 'Y' || entry.key == 'C') ? Colors.black87 : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (myTickets.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('🎫 我的车票：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                for (final t in myTickets)
                  Builder(builder: (context) {
                    final from = kTicketCities[(t['from'] as num).toInt()].name;
                    final to = kTicketCities[(t['to'] as num).toInt()].name;
                    final pts = t['points'];
                    final done = t['done'] == true;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: done
                            ? Colors.green.shade800.withValues(alpha: 0.85)
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: done ? Colors.greenAccent : cs.outline.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${done ? "✅" : "⏳"} $from ↔ $to (${done ? "+$pts" : "±$pts"}分)',
                        style: TextStyle(
                          fontSize: 11,
                          color: done ? Colors.white : cs.onSurface,
                          fontWeight: done ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinalBanner(ColorScheme cs) {
    final fin = (v['final'] as List?)?.cast<Map>() ?? const <Map>[];
    final winners = fin.where((m) => m['win'] == true).map((m) => '${m['name']}').join('、');
    return ResultBanner(
      winners.isEmpty ? '游戏结束' : '🏆 $winners 赢得车票之旅！',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in fin)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${m['win'] == true ? "👑 " : ""}${m['name']}：总分 ${m['score']}（线路 ${m['routeScore']} | 车票 ${m['ticketBonus']} | 最长路径 ${m['longestPath']}节${m['longestBonus'] == true ? "+10" : ""}）',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: m['win'] == true ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RailwayMapPainter extends CustomPainter {
  final List<int> routeOwners;
  const _RailwayMapPainter({required this.routeOwners});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw routes
    for (final r in kTicketRoutes) {
      final c1 = kTicketCities[r.from];
      final c2 = kTicketCities[r.to];
      var p1 = Offset(c1.x * size.width, c1.y * size.height);
      var p2 = Offset(c2.x * size.width, c2.y * size.height);

      // Offset double routes perpendicularly
      if (r.slot == 1) {
        final dx = p2.dx - p1.dx;
        final dy = p2.dy - p1.dy;
        final len = sqrt(dx * dx + dy * dy);
        if (len > 0) {
          final nx = -dy / len * 5.0;
          final ny = dx / len * 5.0;
          p1 = p1.translate(nx, ny);
          p2 = p2.translate(nx, ny);
        }
      }

      final owner = r.id < routeOwners.length ? routeOwners[r.id] : -1;
      final trackColor = _trainCardColor(r.color);

      if (owner >= 0) {
        final pColor = _kPlayerSeatColors[owner % _kPlayerSeatColors.length];
        final claimPaint = Paint()
          ..color = pColor
          ..strokeWidth = 5.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(p1, p2, claimPaint);
      } else {
        final basePaint = Paint()
          ..color = trackColor.withValues(alpha: 0.78)
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(p1, p2, basePaint);
      }
    }

    // Draw cities
    final dotPaint = Paint()..color = Colors.amberAccent;
    final ringPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final city in kTicketCities) {
      final p = Offset(city.x * size.width, city.y * size.height);
      canvas.drawCircle(p, 4.5, dotPaint);
      canvas.drawCircle(p, 4.5, ringPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: city.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            fontFamilyFallback: kFontFallback,
            shadows: [Shadow(color: Colors.black, blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final tx = (p.dx - tp.width / 2).clamp(2.0, max(2.0, size.width - tp.width - 2.0)).toDouble();
      final ty = (p.dy - tp.height - 5).clamp(2.0, max(2.0, size.height - tp.height - 2.0)).toDouble();
      tp.paint(canvas, Offset(tx, ty));
    }
  }

  @override
  bool shouldRepaint(covariant _RailwayMapPainter oldDelegate) => true;
}
