import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class MilleBornesBoard extends StatefulWidget {
  final GameContext g;
  const MilleBornesBoard(this.g, {super.key});

  @override
  State<MilleBornesBoard> createState() => _MilleBornesBoardState();
}

class _MilleBornesBoardState extends State<MilleBornesBoard> {
  int _selectedIdx = 0;

  static const Map<String, (String, IconData, Color)> _cardMeta = {
    'D25': ('25 km', Icons.speed, Color(0xFF1565C0)),
    'D50': ('50 km', Icons.speed, Color(0xFF1565C0)),
    'D75': ('75 km', Icons.speed, Color(0xFF0277BD)),
    'D100': ('100 km', Icons.directions_car, Color(0xFF00695C)),
    'D200': ('200 km', Icons.rocket_launch, Color(0xFF6A1B9A)),
    'H_STOP': ('红灯', Icons.traffic, Color(0xFFC62828)),
    'H_LIMIT': ('限速50', Icons.do_not_disturb_on, Color(0xFFD84315)),
    'H_GAS': ('没油', Icons.local_gas_station_outlined, Color(0xFFC62828)),
    'H_TIRE': ('爆胎', Icons.tire_repair, Color(0xFFC62828)),
    'H_ACC': ('车祸', Icons.car_crash, Color(0xFFB71C1C)),
    'R_ROLL': ('绿灯', Icons.play_circle_fill, Color(0xFF2E7D32)),
    'R_LIMIT': ('解限速', Icons.speed, Color(0xFF388E3C)),
    'R_GAS': ('加油', Icons.local_gas_station, Color(0xFF2E7D32)),
    'R_TIRE': ('备胎', Icons.build_circle, Color(0xFF2E7D32)),
    'R_ACC': ('修理', Icons.handyman, Color(0xFF2E7D32)),
    'S_ROW': ('优先通行', Icons.verified, Color(0xFFF57F17)),
    'S_GAS': ('副油箱', Icons.workspace_premium, Color(0xFFF57F17)),
    'S_TIRE': ('防爆胎', Icons.shield, Color(0xFFF57F17)),
    'S_ACC': ('王牌车手', Icons.emoji_events, Color(0xFFF57F17)),
  };

  static String _labelOf(String code) => _cardMeta[code]?.$1 ?? code;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final target = (v['target'] as num?)?.toInt() ?? 1000;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final deckCount = (v['deckCount'] as num?)?.toInt() ?? 0;
    final hand = (v['hand'] as List?)?.cast<String>() ?? const [];
    final distance = (v['distance'] as List?)?.cast<num>() ?? const [];
    final d200Count = (v['d200Count'] as List?)?.cast<num>() ?? const [];
    final rolling = (v['rolling'] as List?)?.cast<bool>() ?? const [];
    final speedLimit = (v['speedLimit'] as List?)?.cast<bool>() ?? const [];
    final battleHazard = (v['battleHazard'] as List?) ?? const [];
    final safeties = (v['safeties'] as List?) ?? const [];
    final coupFourres = (v['coupFourres'] as List?) ?? const [];
    final scores = (v['scores'] as List?)?.cast<num>() ?? const [];
    final lastMove = v['lastMove'] as Map?;

    if (_selectedIdx >= hand.length) {
      _selectedIdx = hand.isEmpty ? 0 : hand.length - 1;
    }

    final isMyTurn = !g.over && g.seat >= 0 && g.seat == turn;
    final selectedCard =
        (hand.isNotEmpty && _selectedIdx < hand.length) ? hand[_selectedIdx] : null;
    final seats = g.seatsFromMe();

    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxHeight < 460 || c.maxWidth < 460;
      final cardW = compact ? 42.0 : 56.0;

      final statusText = g.over
          ? '千里之行结束'
          : '目标 $target km · 牌库 $deckCount 张 · 轮到 ${g.name(turn)}';

      return Container(
        color: g.table,
        padding: EdgeInsets.all(compact ? 6 : 10),
        child: Stack(children: [
          Column(children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusBar(statusText, highlight: isMyTurn),
                if (lastMove != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '最新动态: ${g.name((lastMove['seat'] as num?)?.toInt() ?? 0)} '
                      '${lastMove['type'] == 'discard' ? '弃置' : '打出'} ${_labelOf('${lastMove['card'] ?? ''}')}',
                      style: TextStyle(fontSize: compact ? 11 : 12),
                    ),
                  ),
              ],
            ),
            SizedBox(height: compact ? 4 : 8),

            // Road-rally lanes for all players
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final s in seats)
                        _buildPlayerLane(
                          g,
                          cs,
                          s,
                          turn,
                          target,
                          distance,
                          d200Count,
                          rolling,
                          speedLimit,
                          battleHazard,
                          safeties,
                          coupFourres,
                          scores,
                          compact,
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Action bar when it's my turn
            if (isMyTurn && selectedCard != null) ...[
              SizedBox(height: compact ? 4 : 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  if (selectedCard.startsWith('H_'))
                    for (var opp = 0; opp < g.players; opp++)
                      if (opp != g.seat)
                        FilledButton.icon(
                          onPressed: () => g.act({
                            'type': 'play',
                            'card': selectedCard,
                            'targetSeat': opp,
                          }),
                          icon: const Icon(Icons.warning_amber, size: 15),
                          label: Text(
                              '对 ${g.name(opp)} 出 ${_labelOf(selectedCard)}'),
                        )
                  else
                    FilledButton.icon(
                      onPressed: () =>
                          g.act({'type': 'play', 'card': selectedCard}),
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: Text('打出 ${_labelOf(selectedCard)}'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        g.act({'type': 'discard', 'card': selectedCard}),
                    icon: const Icon(Icons.delete_outline, size: 15),
                    label: Text('弃置 ${_labelOf(selectedCard)}'),
                  ),
                ],
              ),
            ],

            // Hand row
            if (hand.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: compact ? 4 : 8),
                child: OverlapRow(
                  itemWidth: cardW,
                  children: [
                    for (var i = 0; i < hand.length; i++)
                      _buildMilleCard(
                        hand[i],
                        width: cardW,
                        selected: i == _selectedIdx,
                        onTap: isMyTurn
                            ? () => setState(() => _selectedIdx = i)
                            : null,
                      ),
                  ],
                ),
              ),
          ]),
          if (g.over)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(_buildFinalResultText(g, scores, distance, target)),
            ),
        ]),
      );
    });
  }

  Widget _buildPlayerLane(
    GameContext g,
    ColorScheme cs,
    int s,
    int turn,
    int target,
    List<num> distance,
    List<num> d200Count,
    List<bool> rolling,
    List<bool> speedLimit,
    List battleHazard,
    List safeties,
    List coupFourres,
    List<num> scores,
    bool compact,
  ) {
    final km = s < distance.length ? distance[s].toInt() : 0;
    final d200 = s < d200Count.length ? d200Count[s].toInt() : 0;
    final isRoll = s < rolling.length && rolling[s];
    final isLim = s < speedLimit.length && speedLimit[s];
    final haz = s < battleHazard.length ? battleHazard[s] as String? : null;
    final safList = s < safeties.length
        ? (safeties[s] as List).cast<String>()
        : const <String>[];
    final cfList = s < coupFourres.length
        ? (coupFourres[s] as List).cast<String>()
        : const <String>[];
    final sc = s < scores.length ? scores[s].toInt() : 0;
    final ratio = (km / target).clamp(0.0, 1.0);

    return Container(
      width: compact ? 250 : 300,
      padding: EdgeInsets.all(compact ? 6 : 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (!g.over && s == turn)
              ? cs.primary
              : cs.outline.withValues(alpha: 0.3),
          width: (!g.over && s == turn) ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: g.tag(
                  s,
                  active: !g.over && s == turn,
                  size: compact ? 26 : 30,
                  sub: '$km/$target km · 总分 $sc',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: compact ? 6 : 8,
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _statusChip(
                haz != null
                    ? '故障: ${_labelOf(haz)}'
                    : (isRoll ? '🟢 行驶中' : '🔴 停止'),
                haz != null
                    ? Colors.red.shade700
                    : (isRoll ? Colors.green.shade700 : Colors.grey.shade700),
              ),
              if (isLim) _statusChip('限速 50', Colors.deepOrange),
              if (d200 > 0) _statusChip('200km×$d200', Colors.purple),
              for (final saf in safList)
                _statusChip(
                  '${cfList.contains(saf) ? "⚡反击:" : "🛡️"}${_labelOf(saf)}',
                  Colors.amber.shade800,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMilleCard(
    String code, {
    required double width,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    final h = width * 1.4;
    final meta =
        _cardMeta[code] ?? (code, Icons.help_outline, const Color(0xFF455A64));
    final label = meta.$1;
    final icon = meta.$2;
    final color = meta.$3;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: width,
      height: h,
      transform: Matrix4.translationValues(0, selected ? -width * 0.25 : 0, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF7),
        borderRadius: BorderRadius.circular(width * 0.12),
        border: Border.all(
          color: selected ? Colors.amber : color,
          width: selected ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 3,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: width * 0.5),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: width * 0.24,
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }

  String _buildFinalResultText(
    GameContext g,
    List<num> scores,
    List<num> distance,
    int target,
  ) {
    for (var i = 0; i < distance.length; i++) {
      if (distance[i].toInt() >= target) {
        final sc = i < scores.length ? scores[i].toInt() : target;
        return '${g.name(i)} 抵达终点 $target km 获胜！（$sc 分）';
      }
    }
    if (scores.isEmpty) return '对局结束';
    var maxScore = scores.first.toInt();
    for (final s in scores) {
      if (s.toInt() > maxScore) maxScore = s.toInt();
    }
    final winners = [
      for (var i = 0; i < scores.length; i++)
        if (scores[i].toInt() == maxScore) g.name(i),
    ];
    return '${winners.join(" & ")} 获胜！（$maxScore 分）';
  }
}
