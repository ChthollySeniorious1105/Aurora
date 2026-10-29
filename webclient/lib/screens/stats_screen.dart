import '../i18n/aurora_i18n.dart';

import 'package:aurora_shared/aurora_shared.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../widgets/common.dart';
import '../widgets/game_picker.dart';

/// 我的战绩 + 排行榜.
class StatsScreen extends StatefulWidget {
  final int initialTab;
  const StatsScreen({super.key, this.initialTab = 0});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String? _game;

  @override
  void initState() {
    super.initState();
    final app = AppScope.read(context);
    app.myStats = null;
    app.requestStats();
    _game =
        app.recentGames.isNotEmpty &&
            app.gameInfo(app.recentGames.first) != null
        ? app.recentGames.first
        : (app.games.isNotEmpty ? '${app.games.first['id']}' : null);
    if (_game != null) app.requestLeaderboard(_game!);
  }

  String _gameName(String id) => '${AppScope.read(context).gameInfo(id)?['name'] ?? auroraGameText(id)}';

  void _selectGame(String id) {
    setState(() => _game = id);
    AppScope.read(context).requestLeaderboard(id);
  }

  /// Searchable game chooser (the catalogue has 400+ games, too many for a dropdown).
  Future<void> _chooseGame(BuildContext context) async {
    final app = AppScope.read(context);
    final picked = await showDialog<String>(
      useRootNavigator: false,
      context: context,
      builder: (c) {
        final size = MediaQuery.sizeOf(c);
        return Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: size.width < 500 ? 8 : 32, vertical: size.height < 500 ? 8 : 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 620),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(
                    child: AuroraText('选择游戏', style: Theme.of(c).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(tooltip: auroraT('关闭'), onPressed: () => Navigator.pop(c), icon: const Icon(Icons.close)),
                ]),
                Expanded(
                  child: GamePickerGrid(
                    games: app.games,
                    selected: _game,
                    onPick: (id) => Navigator.pop(c, id),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
    if (picked != null) _selectGame(picked);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const AuroraText('战绩与排行'),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.person_outline, size: 18), iconMargin: EdgeInsets.zero, height: 52, text: auroraT('我的战绩')),
              Tab(icon: const Icon(Icons.leaderboard_outlined, size: 18), iconMargin: EdgeInsets.zero, height: 52, text: auroraT('排行榜')),
            ],
          ),
        ),
        body: TabBarView(children: [_mine(context), _board(context)]),
      ),
    );
  }

  static Widget _constrained(Widget child) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 860), child: child),
      );

  Widget _mine(BuildContext context) {
    final app = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final s = app.myStats;
    if (s == null) return const Center(child: CircularProgressIndicator());
    final games = asInt(s['games'], 0), wins = asInt(s['wins'], 0);
    final per = ((s['per'] as Map?) ?? const {}).cast<String, dynamic>();
    final rows =
        per.entries
            .where((e) => e.value is Map)
            .map((e) => (e.key, (e.value as Map).cast<String, dynamic>()))
            .toList()
          ..sort((a, b) => asInt(b.$2['p'], 0).compareTo(asInt(a.$2['p'], 0)));
    Widget stat(IconData icon, String label, String value) => Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: cs.secondary),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
          ),
          AuroraText(label, style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.75)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
    return _constrained(ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Row(
              children: [
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Avatar(app.avatar, size: 52),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  ),
                ]),
                const SizedBox(width: 8),
                stat(Icons.sports_esports_outlined, '总局数', '$games'),
                stat(Icons.emoji_events_outlined, '胜局', '$wins'),
                stat(
                  Icons.percent,
                  '胜率',
                  games == 0 ? '-' : '${(wins * 100 / games).round()}%',
                ),
              ],
            ),
          ),
        ),
        if (app.pid.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: AuroraText('服务器未返回玩家身份，暂不记录战绩'),
          ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Icon(Icons.history_toggle_off, size: 44, color: cs.onSurface.withValues(alpha: 0.45)),
              const SizedBox(height: 8),
              const AuroraText('还没有对局记录（与电脑或好友完成一局后显示）', textAlign: TextAlign.center),
            ]),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Row(children: [
              Expanded(
                child: AuroraText('各游戏战绩', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
              ),
              AuroraText('Elo', style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.7))),
              const SizedBox(width: 16),
            ]),
          ),
        for (final (id, r) in rows)
          Card(
            margin: const EdgeInsets.only(top: 6),
            child: ListTile(
              title: Text(_gameName(id), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(auroraT('{0} 局 · {1} 胜', [asInt(r['p'], 0), asInt(r['w'], 0)])),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      value: asInt(r['p'], 0) == 0 ? 0 : asInt(r['w'], 0) / asInt(r['p'], 0),
                      backgroundColor: cs.onSurface.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  '${asInt(r['elo'], 1500)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: cs.onSurface.withValues(alpha: 0.5)),
              ]),
              onTap: () {
                _selectGame(id);
                DefaultTabController.of(context).animateTo(1);
              },
            ),
          ),
      ],
    ));
  }

  Widget _board(BuildContext context) {
    final app = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final g = _game;
    final rows = g == null ? null : app.leaderboards[g];
    final info = g == null ? null : app.gameInfo(g);
    return _constrained(Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: app.games.isEmpty ? null : () => _chooseGame(context),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: auroraT('游戏'),
                prefixIcon: Icon(GamePickerGrid.categoryIcons[app.games.where((x) => x['id'] == g).firstOrNull?['category']] ?? Icons.sports_esports),
                suffixIcon: const Icon(Icons.search),
              ),
              child: Text(
                g == null ? '-' : '${info?['name'] ?? auroraGameText(g)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        Expanded(
          child: rows == null
              ? const Center(child: CircularProgressIndicator())
              : rows.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.leaderboard_outlined, size: 44, color: cs.onSurface.withValues(alpha: 0.45)),
                      const SizedBox(height: 8),
                      const AuroraText('暂无上榜玩家（至少完成 3 局才上榜）', textAlign: TextAlign.center),
                    ]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  itemCount: rows.length,
                  itemBuilder: (c, i) {
                    final r = rows[i];
                    final me = (app.pid.isNotEmpty && r['pid'] == app.pid) ||
                        (r['pid'] == null && asStr(r['name']) == app.name);
                    final medal = i < 3
                        ? [
                            const Color(0xFFFFC107),
                            const Color(0xFFB0BEC5),
                            const Color(0xFFBC8A5F),
                          ][i]
                        : null;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: me ? cs.primaryContainer.withValues(alpha: 0.55) : null,
                        borderRadius: BorderRadius.circular(12),
                        border: me ? Border.all(color: cs.primary.withValues(alpha: 0.6)) : null,
                      ),
                      child: ListTile(
                        leading: SizedBox(
                          width: 72,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 30,
                                child: medal != null
                                    ? Icon(Icons.workspace_premium, color: medal, size: 24)
                                    : Text(
                                        '${i + 1}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: cs.onSurface.withValues(alpha: 0.8),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 4),
                              Avatar(asInt(r['avatar'], 0), size: 34),
                            ],
                          ),
                        ),
                        title: Text(
                          me ? '${asStr(r['name'])} · ${auroraT('我')}' : asStr(r['name']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: me ? FontWeight.bold : null),
                        ),
                        subtitle: Text(
                          auroraT('{0} 局 · {1} 胜', [asInt(r['p'], 0), asInt(r['w'], 0)]),
                        ),
                        trailing: Text(
                          '${asInt(r['elo'], 1500)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    ));
  }
}
