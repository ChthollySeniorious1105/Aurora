import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class Sherlock13Board extends StatefulWidget {
  final GameContext g;
  const Sherlock13Board(this.g, {super.key});

  @override
  State<Sherlock13Board> createState() => _Sherlock13BoardState();
}

class _Sherlock13BoardState extends State<Sherlock13Board> {
  int _selectedTarget = -1;

  GameContext get g => widget.g;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final eliminated = ((v['eliminated'] as List?) ?? const []).map((e) => e == true).toList();
    final winner = (v['winner'] as num?)?.toInt();
    final culprit = (v['culprit'] as num?)?.toInt() ?? -1;
    final myHand = ((v['myHand'] as List?) ?? const []).map((e) => (e as num).toInt()).toSet();
    final handCounts = ((v['handCounts'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    final knownExact = (v['knownExactCounts'] as Map?)?.cast<String, dynamic>() ?? const {};
    final candidates = ((v['candidates'] as List?) ?? const []).map((e) => (e as num).toInt()).toSet();
    final symbols = ((v['symbolsCatalog'] as List?) ?? const []).cast<Map>();
    final suspects = ((v['suspectsCatalog'] as List?) ?? const []).cast<Map>();
    final lastEvent = (v['lastEvent'] as String?) ?? '';

    final isMyTurn = !g.over && g.seat == turn && (g.seat >= 0 && g.seat < eliminated.length && !eliminated[g.seat]);

    if (_selectedTarget < 0 || _selectedTarget == g.seat || _selectedTarget >= g.players) {
      _selectedTarget = g.seat >= 0 ? (g.seat + 1) % g.players : 0;
    }

    String statusText;
    if (g.over) {
      statusText = winner != null ? '${g.name(winner)} 成功侦破真凶！' : '全员指认失败，真凶逃脱！';
    } else {
      statusText = isMyTurn ? '轮到你探案：全场询问 / 单独询问 / 指认凶手' : '等待 ${g.name(turn)} 进行推理调查…';
    }

    String suspectName(int id) {
      if (id < 0 || id >= suspects.length) return '❓ 未知真凶';
      return '${suspects[id]['name']}';
    }

    return Container(
      color: g.table,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusBar(statusText, highlight: isMyTurn),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '🕵️ 剩余可疑候选: ${candidates.length} / 13',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSecondaryContainer),
                          ),
                        ),
                      ],
                    ),
                    if (lastEvent.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        lastEvent,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.85)),
                      ),
                    ],
                    if (g.over) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: ResultBanner(
                          winner != null ? '${g.name(winner)} 破案获胜！' : '真凶逃之夭夭',
                          child: Text(
                            '中央真凶档案：【${suspectName(culprit)}】',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Players Row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in g.seatsFromMe())
                          Container(
                            width: 220,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cs.surface.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (!g.over && s == turn) ? cs.primary : cs.outline.withValues(alpha: 0.3),
                                width: (!g.over && s == turn) ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                g.tag(
                                  s,
                                  active: !g.over && s == turn,
                                  sub: '手牌 ${s < handCounts.length ? handCounts[s] : 0} 张${(s < eliminated.length && eliminated[s]) ? " (指认失败)" : ""}',
                                  size: 28,
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 2,
                                  children: [
                                    for (final sym in symbols)
                                      _buildPlayerSymbolBadge(cs, s, sym, knownExact),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Inquiry Controls for Active Player
                    if (isMyTurn) _buildInquiryPanel(cs, symbols),
                    const SizedBox(height: 8),
                    // 13 Suspects Deduction Sheet & Accusation
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '13 名嫌疑人推理笔记${isMyTurn ? "（点击嫌疑人可直接指认凶手！）" : ""}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final sus in suspects)
                                _buildSuspectChip(
                                  cs: cs,
                                  sus: sus,
                                  symbols: symbols,
                                  inMyHand: myHand.contains(sus['id']),
                                  isCandidate: candidates.contains(sus['id']),
                                  canAccuse: isMyTurn,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlayerSymbolBadge(ColorScheme cs, int playerSeat, Map sym, Map<String, dynamic> knownExact) {
    final symId = (sym['id'] as num).toInt();
    final exact = (knownExact['$playerSeat:$symId'] as num?)?.toInt();
    final label = exact != null ? '${sym['icon']}$exact' : '${sym['icon']}?';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: exact != null ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _buildInquiryPanel(ColorScheme cs, List<Map> symbols) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('① 全场询问（谁持有至少 1 个该证物符号）：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final sym in symbols)
                ActionChip(
                  label: Text('${sym['icon']} ${sym['name']} (共${sym['totalInDeck']})', style: const TextStyle(fontSize: 11)),
                  onPressed: () => g.act({'type': 'ask_all', 'symbol': sym['id']}),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('② 单独询问精确数量 — 选择目标对手：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              for (var s = 0; s < g.players; s++)
                if (s != g.seat)
                  ChoiceChip(
                    label: Text(g.name(s), style: const TextStyle(fontSize: 11)),
                    selected: _selectedTarget == s,
                    onSelected: (_) => setState(() => _selectedTarget = s),
                  ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final sym in symbols)
                ActionChip(
                  label: Text('问 ${g.name(_selectedTarget)}: ${sym['icon']}${sym['name']}', style: const TextStyle(fontSize: 11)),
                  onPressed: () => g.act({'type': 'ask_one', 'target': _selectedTarget, 'symbol': sym['id']}),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuspectChip({
    required ColorScheme cs,
    required Map sus,
    required List<Map> symbols,
    required bool inMyHand,
    required bool isCandidate,
    required bool canAccuse,
  }) {
    final id = (sus['id'] as num).toInt();
    final symIds = ((sus['symbols'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    final icons = symIds.map((sid) => sid < symbols.length ? '${symbols[sid]['icon']}' : '').join();
    final tag = inMyHand ? ' [我手中]' : (isCandidate ? ' [可疑]' : ' [已排除]');

    return ActionChip(
      backgroundColor: isCandidate ? cs.primaryContainer : cs.surfaceContainerHighest.withValues(alpha: 0.55),
      label: Text(
        '$icons ${sus['name']}$tag',
        style: TextStyle(
          fontSize: 11,
          decoration: isCandidate ? null : TextDecoration.lineThrough,
          fontWeight: isCandidate ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onPressed: canAccuse ? () => g.act({'type': 'accuse', 'suspect': id}) : null,
    );
  }
}
