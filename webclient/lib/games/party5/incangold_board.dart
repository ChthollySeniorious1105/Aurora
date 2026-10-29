import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class IncanGoldBoard extends StatelessWidget {
  final GameContext g;
  const IncanGoldBoard(this.g, {super.key});

  static const Map<String, String> _hazardEmoji = {
    'snake': '🐍',
    'spider': '🕷️',
    'mummy': '🧟',
    'rock': '🪨',
    'fire': '🔥',
  };

  static const Map<String, String> _hazardName = {
    'snake': '毒蛇',
    'spider': '蜘蛛',
    'mummy': '木乃伊',
    'rock': '落石',
    'fire': '火焰',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 5;
    final step = (v['step'] as num?)?.toInt() ?? 1;
    final over = v['over'] == true || g.over;
    final chest = (v['chest'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final pocket = (v['pocket'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final artifactsClaimed =
        (v['artifactsClaimed'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final inTemple = (v['inTemple'] as List?)?.map((e) => e == true).toList() ?? List.filled(g.players, true);
    final hasChosen = (v['hasChosen'] as List?)?.map((e) => e == true).toList() ?? List.filled(g.players, false);
    final myChoice = v['myChoice'] as String?;
    final pathCards = (v['pathCards'] as List?)?.cast<Map>() ?? const [];
    final pathGems = (v['pathGems'] as num?)?.toInt() ?? 0;
    final pathArtifacts = (v['pathArtifacts'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];
    final roundHazards = (v['roundHazards'] as Map?)?.cast<String, dynamic>() ?? const {};
    final hazardCopies = (v['hazardCopies'] as Map?)?.cast<String, dynamic>() ?? const {};
    final deckCount = (v['deckCount'] as num?)?.toInt() ?? 0;
    final riskPercent = (v['riskPercent'] as num?)?.toInt() ?? 0;
    final lastEvent = (v['lastEvent'] as String?) ?? '';
    final roundHistory = (v['roundHistory'] as List?)?.cast<Map>() ?? const [];
    final waiting = (v['waitingFor'] as List?)?.map((e) => (e as num).toInt()).toSet() ?? const <int>{};

    final amWaiting = g.seat >= 0 && waiting.contains(g.seat);

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top header & status bar
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusBar(
                        over
                            ? '神庙探险已结束'
                            : (amWaiting ? '第 $round/$totalRounds 轮 · 请选择继续前进或返回营地' : '第 $round/$totalRounds 轮 · 第 $step 步'),
                        highlight: amWaiting,
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _infoPill(cs, '牌库 $deckCount 张', Icons.style),
                          _riskPill(cs, riskPercent),
                          _infoPill(cs, '路上宝石 $pathGems 💎', Icons.diamond),
                          if (pathArtifacts.isNotEmpty)
                            _infoPill(
                              cs,
                              '路上神器 +${pathArtifacts.fold<int>(0, (a, b) => a + b)} 🏺',
                              Icons.emoji_events,
                              highlight: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Scrollable central area so landscape (390px height) never overflows
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (lastEvent.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: cs.surface.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                lastEvent,
                                style: TextStyle(fontSize: 12, color: cs.onSurface),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                          // Hazard warning tracker strip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: cs.surface.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
                            ),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              alignment: WrapAlignment.spaceAround,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                for (final h in const ['snake', 'spider', 'mummy', 'rock', 'fire'])
                                  _buildHazardChip(
                                    cs,
                                    h,
                                    (roundHazards[h] as num?)?.toInt() ?? 0,
                                    (hazardCopies[h] as num?)?.toInt() ?? 3,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Temple Path cards section
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cs.surface.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '🏛️ 神庙路径（已翻开 ${pathCards.length} 张）',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: cs.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '余留 $pathGems 💎${pathArtifacts.isNotEmpty ? ' · 神器 ${pathArtifacts.length} 件' : ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: cs.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (pathCards.isEmpty)
                                  Text('尚未翻开路径牌', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))
                                else
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      for (var i = 0; i < pathCards.length; i++)
                                        _buildPathCard(cs, pathCards[i], i == pathCards.length - 1),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Players status cards
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final s in g.seatsFromMe())
                                _buildPlayerCard(
                                  cs,
                                  s,
                                  chest: chest[s],
                                  pocket: pocket[s],
                                  artifacts: artifactsClaimed[s],
                                  exploring: inTemple[s],
                                  chosen: hasChosen[s],
                                  active: waiting.contains(s),
                                ),
                            ],
                          ),

                          // Completed rounds summary strip
                          if (roundHistory.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (final rh in roundHistory)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (rh['collapsed'] == true ? Colors.red : Colors.teal)
                                          .withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: (rh['collapsed'] == true ? Colors.redAccent : Colors.teal)
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Text(
                                      rh['collapsed'] == true
                                          ? '第${rh['round']}轮: 💥${rh['hazardName']}坍塌'
                                          : '第${rh['round']}轮: ✅安全撤离',
                                      style: TextStyle(fontSize: 11, color: cs.onSurface),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Bottom action controls for active player in temple
                  if (!over && g.seat >= 0 && inTemple[g.seat]) ...[
                    const SizedBox(height: 6),
                    _buildDecisionBar(
                      cs,
                      myChoice: myChoice,
                      myPocket: pocket[g.seat],
                      pathGems: pathGems,
                      artifactBonus: pathArtifacts.fold<int>(0, (a, b) => a + b),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (over)
            Align(
              alignment: Alignment.center,
              child: _buildResultBanner(cs, chest, artifactsClaimed),
            ),
        ],
      ),
    );
  }

  Widget _infoPill(ColorScheme cs, String text, IconData icon, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight ? Colors.amber.withValues(alpha: 0.25) : cs.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: highlight ? Colors.amber : cs.outline.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: highlight ? Colors.amber.shade800 : cs.primary),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurface)),
        ],
      ),
    );
  }

  Widget _riskPill(ColorScheme cs, int riskPercent) {
    final color = riskPercent == 0
        ? Colors.green
        : (riskPercent < 20 ? Colors.orange : Colors.redAccent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Text(
        '下张坍塌率 $riskPercent%',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.onSurface),
      ),
    );
  }

  Widget _buildHazardChip(ColorScheme cs, String h, int seenThisRound, int totalCopies) {
    final warning = seenThisRound >= 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: warning ? Colors.redAccent.withValues(alpha: 0.24) : cs.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: warning ? Colors.redAccent : cs.outline.withValues(alpha: 0.25),
          width: warning ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${_hazardEmoji[h]} ${_hazardName[h]}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(
            warning ? '⚠️已出1/$totalCopies' : '剩$totalCopies张',
            style: TextStyle(
              fontSize: 11,
              color: warning ? Colors.redAccent : cs.onSurface.withValues(alpha: 0.7),
              fontWeight: warning ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPathCard(ColorScheme cs, Map card, bool isLatest) {
    final kind = card['kind'] as String? ?? 'treasure';
    Color bg;
    Color border;
    String title;
    String sub;

    if (kind == 'treasure') {
      final val = card['value'] ?? 0;
      final share = card['share'] ?? 0;
      bg = Colors.teal.withValues(alpha: 0.2);
      border = Colors.teal;
      title = '💎 $val';
      sub = '各+$share';
    } else if (kind == 'artifact') {
      final val = card['value'] ?? 5;
      bg = Colors.amber.withValues(alpha: 0.25);
      border = Colors.amber.shade700;
      title = '🏺 神器';
      sub = '+$val💎';
    } else {
      final h = card['hazard'] as String? ?? 'snake';
      bg = Colors.redAccent.withValues(alpha: 0.22);
      border = Colors.redAccent;
      title = '${_hazardEmoji[h] ?? '⚠️'} ${_hazardName[h] ?? h}';
      sub = '灾难';
    }

    return Container(
      width: 66,
      height: 54,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: isLatest ? 2.2 : 1.2),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: cs.onSurface)),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCard(
    ColorScheme cs,
    int s, {
    required int chest,
    required int pocket,
    required int artifacts,
    required bool exploring,
    required bool chosen,
    required bool active,
  }) {
    final statusBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (exploring ? Colors.amber : Colors.blueGrey).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        exploring ? (chosen ? '已选 ✓' : '探险中 🔦') : '营地 ⛺',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.onSurface),
      ),
    );

    return g.tag(
      s,
      active: active,
      size: 32,
      sub: '⛺$chest💎 · 🎒$pocket💎${artifacts > 0 ? ' · 🏺$artifacts' : ''}',
      trailing: statusBadge,
    );
  }

  Widget _buildDecisionBar(
    ColorScheme cs, {
    required String? myChoice,
    required int myPocket,
    required int pathGems,
    required int artifactBonus,
  }) {
    if (myChoice != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.primary),
        ),
        child: Text(
          '已决定：【${myChoice == 'go' ? '🔦 继续前进' : '⛺ 返回营地'}】，等待其他探险家做出选择…',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary),
        ),
      );
    }

    final soloTotal = myPocket + pathGems + artifactBonus;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: () => g.act({'type': 'go'}),
            icon: const Icon(Icons.explore, size: 18),
            label: const Text('继续前进 (Go)'),
          ),
          OutlinedButton.icon(
            onPressed: () => g.act({'type': 'leave'}),
            icon: const Icon(Icons.roofing, size: 18),
            label: Text('返回营地 (独自撤离可带回 $soloTotal💎)'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultBanner(ColorScheme cs, List<int> chest, List<int> artifacts) {
    final order = [for (var i = 0; i < g.players; i++) i]
      ..sort((a, b) => (chest[b] * 100 + artifacts[b]).compareTo(chest[a] * 100 + artifacts[a]));
    final winner = order.first;
    return ResultBanner(
      '🏆 ${g.name(winner)} 夺得印加宝藏冠军！（${chest[winner]} 💎）',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in order)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${g.name(s)}：宝箱 ${chest[s]} 💎（神器 ${artifacts[s]} 件）',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: s == winner ? FontWeight.bold : FontWeight.normal,
                  color: cs.onSurface,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
