import '../i18n/aurora_i18n.dart';

import 'package:aurora_shared/aurora_shared.dart';
import 'package:flutter/material.dart';

import '../state/app_state.dart';

class PartyPanel extends StatelessWidget {
  final AppState app;
  const PartyPanel({super.key, required this.app});

  String _game(String id) => '${app.gameInfo(id)?['name'] ?? id}';

  @override
  Widget build(BuildContext context) {
    final party = app.room?['party'] as Map?;
    if (party == null) {
      return app.isHost
          ? OutlinedButton.icon(
              onPressed: () => _configure(context),
              icon: const Icon(Icons.celebration),
              label: const AuroraText('创建派对之夜'),
            )
          : const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    final q = (party['queue'] as List).cast<String>(),
        index = party['index'] as int;
    final finished = party['finished'] == true,
        complete = party['roundComplete'] == true;
    final rows = (party['scores'] as List).cast<Map>();
    final top = rows.isEmpty ? 0 : rows.first['points'];
    final winners = rows
        .where((r) => r['points'] == top)
        .map((r) => '${r['name']}')
        .join('、');
    final votes = (party['votes'] as Map?) ?? const {};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(finished ? Icons.emoji_events : Icons.celebration, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    finished
                        ? '${auroraT('派对结束！')}${winners.isEmpty ? '' : auroraT('获胜：{0}', [winners])}'
                        : auroraT('派对之夜 · 第 {0}/{1} 局', [index + 1, q.length]),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Queue with the current game highlighted.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < q.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: i == index && !finished
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest.withValues(alpha: i < index ? 0.35 : 0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: i == index && !finished ? cs.primary : cs.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      '${i + 1}. ${_game(q[i])}',
                      style: TextStyle(
                        fontSize: 13,
                        color: i < index ? cs.onSurface.withValues(alpha: 0.55) : cs.onSurface,
                        decoration: i < index ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            AuroraText(
              '每局第一名 100 分，其他名次按人数折算；跨游戏累计。',
              style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < rows.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: i == 0 ? cs.primary : null),
                      ),
                    ),
                    Expanded(
                      child: Text('${rows[i]['name']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      auroraT('{0} 分 · {1} 胜', [rows[i]['points'], rows[i]['wins']]),
                      style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary),
                    ),
                  ],
                ),
              ),
            if (complete && !finished) ...[
              const Divider(),
              const AuroraText('投票选择下一款游戏（同票按队列顺序）'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in q.skip(index + 1))
                    ChoiceChip(
                      label: Text(
                        '${_game(id)} · ${auroraT('{0} 票', [votes.values.where((v) => v == id).length])}',
                      ),
                      selected: votes['${app.myId}'] == id,
                      onSelected: app.mySeat >= 0
                          ? (_) => app.send({'t': Msg.partyVote, 'game': id})
                          : null,
                    ),
                ],
              ),
              if (app.isHost) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.skip_next),
                  onPressed: () => app.send({'t': Msg.partyNext}),
                  label: const AuroraText('按投票进入下一局'),
                ),
              ],
            ],
            if (app.isHost && app.room?['playing'] != true)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      useRootNavigator: false,
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const AuroraText('结束当前派对？'),
                        content: const AuroraText('本次派对累计积分将清空。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const AuroraText('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const AuroraText('结束'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) app.send({'t': Msg.partyConfig, 'queue': []});
                  },
                  label: const AuroraText('结束派对'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _configure(BuildContext context) async {
    final selected = <String>[];
    var query = '';
    final count = app.seats
        .where((s) => s['client'] != null || s['bot'] == true)
        .length;
    final available = app.games
        .where((g) => matchesGame(g, players: count))
        .toList();
    await showDialog<void>(
      useRootNavigator: false,
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) {
          final cs = Theme.of(c).colorScheme;
          final ql = query.trim().toLowerCase();
          final shown = ql.isEmpty
              ? available
              : [
                  for (final g in available)
                    if ('${g['id']}'.contains(ql) ||
                        '${g['name']}'.toLowerCase().contains(ql) ||
                        auroraGameText('${g['name']}').toLowerCase().contains(ql))
                      g,
                ];
          return AlertDialog(
            title: const AuroraText('派对之夜'),
            content: SizedBox(
              width: 520,
              height: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    auroraT('当前 {0} 人，选择 2~8 款游戏。点击顺序就是初始队列。已选 {1}/8。', [count, selected.length]),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: auroraT('搜索游戏（名称/简介）'),
                    ),
                    onChanged: (v) => set(() => query = v),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: shown.isEmpty
                        ? const Center(child: AuroraText('没有匹配的游戏'))
                        : ListView.builder(
                            itemCount: shown.length,
                            itemBuilder: (_, i) {
                              final g = shown[i];
                              final id = '${g['id']}';
                              final at = selected.indexOf(id);
                              return CheckboxListTile(
                                dense: true,
                                secondary: at < 0
                                    ? null
                                    : CircleAvatar(
                                        radius: 12,
                                        backgroundColor: cs.primary,
                                        child: Text('${at + 1}', style: TextStyle(fontSize: 12, color: cs.onPrimary)),
                                      ),
                                title: Text(auroraGameText('${g['name']}')),
                                subtitle: Text(auroraT('约 {0} 分钟', [g['minutes']])),
                                value: at >= 0,
                                onChanged: (v) => set(() {
                                  if (v == false) {
                                    selected.remove(id);
                                  } else if (selected.length < 8) {
                                    selected.add(id);
                                  }
                                }),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const AuroraText('取消'),
              ),
              FilledButton(
                onPressed: selected.length < 2
                    ? null
                    : () {
                        app.send({
                          't': Msg.partyConfig,
                          'queue': List.of(selected),
                        });
                        Navigator.pop(c);
                      },
                child: const AuroraText('创建派对'),
              ),
            ],
          );
        },
      ),
    );
  }
}
