import '../i18n/aurora_i18n.dart';
import 'dart:async';
import 'dart:math';
import 'package:aurora_shared/aurora_shared.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../state/app_state.dart';

class CreateRoomResult {
  final String name;
  final String game;
  final Map<String, dynamic> options;
  final String password;
  final bool private;
  CreateRoomResult(this.name, this.game, this.options, this.password, this.private);
}

/// Games grouped by category with a search box; returns a game id.
///
/// All game tiles are built lazily (one [SliverGrid] per section), so the
/// full 400+ game catalogue never builds eagerly.
class GamePickerGrid extends StatefulWidget {
  final List<Map<String, dynamic>> games;
  final String? selected;
  final ValueChanged<String> onPick;
  const GamePickerGrid({super.key, required this.games, required this.onPick, this.selected});

  static const categoryIcons = {
    '麻将': Icons.grid_view_rounded,
    '棋类': Icons.extension,
    '牌类': Icons.style,
    '桌游': Icons.casino,
    '派对': Icons.celebration,
  };

  /// Display order of the categories (unknown ones follow in catalogue order).
  static const categoryOrder = ['麻将', '棋类', '牌类', '桌游', '派对'];

  /// "2-4 人" style label for a game's player range ('' if unknown).
  static String playersLabel(Map<String, dynamic> g) {
    final p = (g['players'] as List?)?.cast<num>();
    if (p == null || p.length != 2) return '';
    return p[0] == p[1] ? auroraT('{0} 人', [p[0]]) : auroraT('{0}~{1} 人', [p[0], p[1]]);
  }

  @override
  State<GamePickerGrid> createState() => _GamePickerGridState();
}

class _GamePickerGridState extends State<GamePickerGrid> {
  final _searchCtl = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  Timer? _debounce;
  String _q = '';
  String? _cat;
  int _playersFilter = 0, _minutes = 0, _difficulty = 0;
  String _mode = '';

  // Lower-cased search text per game (id, Chinese + English name, description).
  List<String> _haystack = const [];
  Object? _haystackFor;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  static String _name(Map<String, dynamic> g) => auroraGameText('${g['name']}');
  static String _description(Map<String, dynamic> g) => auroraEnglish['${g['description']}'] ?? '${g['description']}';
  static String _category(String value) => auroraCategory(value);

  void _onQuery(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => _q = v);
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
    // Rebuild the clear button immediately.
    setState(() {});
  }

  void _clearQuery() {
    _debounce?.cancel();
    _searchCtl.clear();
    setState(() => _q = '');
  }

  List<String> _index() {
    final key = (widget.games, currentAuroraLanguage);
    if (_haystackFor != key || _haystack.length != widget.games.length) {
      _haystackFor = key;
      _haystack = [
        for (final g in widget.games)
          [
            '${g['id']}',
            '${g['name']}',
            auroraGameEnglish['${g['name']}'] ?? '',
            '${g['description']}',
            auroraEnglish['${g['description']}'] ?? '',
          ].join('\n').toLowerCase(),
      ];
    }
    return _haystack;
  }

  bool get _filtered => _playersFilter != 0 || _minutes != 0 || _difficulty != 0 || _mode.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = _q.trim().toLowerCase();
    final index = _index();
    final app = context.getInheritedWidgetOfExactType<AppScope>()?.notifier;

    // Games matching search + filters (category is applied separately so the
    // category chips can show how many matches each one has).
    final byCat = <String, List<Map<String, dynamic>>>{};
    for (final c in GamePickerGrid.categoryOrder) {
      byCat[c] = [];
    }
    var total = 0;
    for (var i = 0; i < widget.games.length; i++) {
      final g = widget.games[i];
      final c = '${g['category']}';
      final list = byCat.putIfAbsent(c, () => []);
      if (!matchesGame(g, players: _playersFilter, minutes: _minutes, difficulty: _difficulty, mode: _mode)) continue;
      if (q.isNotEmpty && !index[i].contains(q)) continue;
      list.add(g);
      total++;
    }
    byCat.removeWhere((k, v) => v.isEmpty && !GamePickerGrid.categoryOrder.contains(k));
    final shown = [
      for (final e in byCat.entries)
        if ((_cat == null || e.key == _cat) && e.value.isNotEmpty) e,
    ];

    Map<String, dynamic>? byId(String id) {
      for (final g in widget.games) {
        if (g['id'] == id) return g;
      }
      return null;
    }

    final showQuick = app != null && q.isEmpty && _cat == null && !_filtered;
    final favs = showQuick ? [for (final id in app.favoriteGames) ?byId(id)] : const <Map<String, dynamic>>[];
    final recents = showQuick
        ? [for (final id in app.recentGames) if (!app.favoriteGames.contains(id)) ?byId(id)]
        : const <Map<String, dynamic>>[];
    final sel = widget.selected;
    final candidates = [for (final e in shown) ...e.value];

    void pickRandom() {
      if (candidates.isEmpty) return;
      widget.onPick('${candidates[Random().nextInt(candidates.length)]['id']}');
    }

    final search = TextField(
      controller: _searchCtl,
      focusNode: _searchFocus,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: auroraT('搜索游戏（名称/简介）'),
        suffixIcon: _searchCtl.text.isEmpty
            ? null
            : IconButton(tooltip: auroraT('清除'), icon: const Icon(Icons.clear, size: 18), onPressed: _clearQuery),
      ),
      onChanged: _onQuery,
      onSubmitted: (v) {
        // Enter picks the first match of the current search.
        _debounce?.cancel();
        final query = v.trim().toLowerCase();
        setState(() => _q = v);
        if (query.isEmpty) return;
        for (var i = 0; i < widget.games.length; i++) {
          final g = widget.games[i];
          if ((_cat == null || g['category'] == _cat) &&
              matchesGame(g, players: _playersFilter, minutes: _minutes, difficulty: _difficulty, mode: _mode) &&
              index[i].contains(query)) {
            widget.onPick('${g['id']}');
            return;
          }
        }
      },
    );

    final catChips = <Widget>[
      _chipPad(ChoiceChip(
        label: Text(auroraT('全部 {0}', [total])),
        selected: _cat == null,
        onSelected: (_) => setState(() => _cat = null),
      )),
      for (final e in byCat.entries)
        _chipPad(ChoiceChip(
          avatar: Icon(GamePickerGrid.categoryIcons[e.key] ?? Icons.games, size: 16),
          label: Text('${_category(e.key)} ${e.value.length}'),
          selected: _cat == e.key,
          onSelected: (_) => setState(() => _cat = _cat == e.key ? null : e.key),
        )),
    ];
    final filterChips = <Widget>[
      _filter<int>('人数', _playersFilter, {0: '不限', for (var i = 1; i <= 12; i++) i: auroraT('{0} 人', [i])}, (v) => _playersFilter = v),
      _filter<int>('时长', _minutes, {0: '不限', 5: '约 5 分钟', 15: '约 15 分钟', 30: '30 分钟内', 60: '约 1 小时'}, (v) => _minutes = v),
      _filter<int>('难度', _difficulty, {0: '不限', 1: '入门', 2: '中等及以下', 3: '含进阶'}, (v) => _difficulty = v),
      _filter<String>('玩法', _mode, {'': '不限', 'coop': '合作', 'competitive': '对战'}, (v) => _mode = v),
      if (_filtered)
        _chipPad(ActionChip(
          avatar: const Icon(Icons.filter_alt_off, size: 16),
          label: const AuroraText('重置筛选'),
          onPressed: () => setState(() {
            _playersFilter = _minutes = _difficulty = 0;
            _mode = '';
          }),
        )),
      Tooltip(
        message: auroraT('从当前结果中随机挑一款'),
        child: TextButton.icon(
          onPressed: candidates.isEmpty ? null : pickRandom,
          icon: const Icon(Icons.shuffle, size: 18),
          label: const AuroraText('帮我选'),
        ),
      ),
    ];

    Widget row(List<Widget> children) => SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, children: children),
        );

    return LayoutBuilder(builder: (context, box) {
      // Short areas (phone landscape dialogs) merge categories and filters into one row.
      final compact = box.maxHeight.isFinite && box.maxHeight < 380;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: search),
          if (app != null && sel != null)
            IconButton(
              tooltip: auroraT(app.isFavorite(sel) ? '取消收藏当前游戏' : '收藏当前游戏（也可长按游戏）'),
              onPressed: () => setState(() => app.toggleFavorite(sel)),
              icon: Icon(app.isFavorite(sel) ? Icons.star : Icons.star_border,
                  color: app.isFavorite(sel) ? Colors.amber : null),
            ),
        ]),
        const SizedBox(height: 6),
        if (compact)
          row([...catChips, const VerticalDivider(width: 16, indent: 8, endIndent: 8), ...filterChips])
        else ...[
          row(catChips),
          const SizedBox(height: 4),
          row(filterChips),
        ],
        const SizedBox(height: 4),
        Expanded(
          child: shown.isEmpty
              ? _empty(cs)
              : Scrollbar(
                  controller: _scroll,
                  child: CustomScrollView(
                    controller: _scroll,
                    slivers: [
                      if (favs.isNotEmpty) ...[
                        _header(cs, Icons.star, auroraT('收藏'), favs.length),
                        _grid(favs, app),
                      ],
                      if (recents.isNotEmpty) ...[
                        _header(cs, Icons.history, auroraT('最近玩过'), recents.length),
                        _grid(recents, app),
                      ],
                      for (final e in shown) ...[
                        _header(cs, GamePickerGrid.categoryIcons[e.key] ?? Icons.games, _category(e.key), e.value.length),
                        _grid(e.value, app, q: q),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    ],
                  ),
                ),
        ),
      ]);
    });
  }

  Widget _empty(ColorScheme cs) => Center(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.search_off, size: 40, color: cs.onSurface.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            const AuroraText('没有匹配的游戏'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _clearQuery();
                setState(() {
                  _cat = null;
                  _playersFilter = _minutes = _difficulty = 0;
                  _mode = '';
                });
              },
              child: const AuroraText('清除搜索与筛选'),
            ),
          ]),
        ),
      );

  Widget _chipPad(Widget w) => Padding(padding: const EdgeInsets.only(right: 6), child: Center(child: w));

  Widget _header(ColorScheme cs, IconData icon, String title, int count) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
          child: Row(children: [
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$count', style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
      );

  Widget _grid(List<Map<String, dynamic>> gs, AppState? app, {String q = ''}) => SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 230,
          mainAxisExtent: 60,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: gs.length,
        itemBuilder: (context, i) => _tile(context, gs[i], app, q),
      );

  Widget _filter<T>(String label, T value, Map<T, String> choices, void Function(T) changed) {
    final active = value != choices.keys.first;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Center(
        child: PopupMenuButton<T>(
          initialValue: value,
          tooltip: auroraT(label),
          onSelected: (v) => setState(() => changed(v)),
          itemBuilder: (_) => [for (final e in choices.entries) PopupMenuItem(value: e.key, child: Text(auroraT(e.value)))],
          child: Builder(builder: (context) {
            final cs = Theme.of(context).colorScheme;
            return Chip(
              label: AuroraText('${auroraT(label)}：${auroraT(choices[value]!)}'),
              avatar: Icon(Icons.filter_list, size: 16, color: active ? cs.onSecondaryContainer : null),
              backgroundColor: active ? cs.secondaryContainer : null,
              side: active ? BorderSide(color: cs.secondary) : null,
            );
          }),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, Map<String, dynamic> g, AppState? app, String q) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final id = '${g['id']}';
    final fav = app?.isFavorite(id) ?? false;
    final selected = id == widget.selected;
    final name = _name(g);
    void toggle() {
      if (app == null) return;
      setState(() => app.toggleFavorite(id));
    }

    final meta = [
      GamePickerGrid.playersLabel(g),
      if (g['minutes'] is num) auroraT('约 {0} 分钟', [g['minutes']]),
    ].where((s) => s.isNotEmpty).join(' · ');
    final fg = selected ? cs.onPrimaryContainer : cs.onSurface;

    return Tooltip(
      key: ValueKey('game:$id'),
      message: '${_description(g)}${app == null ? '' : '\n${auroraT('（长按 / 右键：{0}）', [auroraT(fav ? '取消收藏' : '收藏')])}'}',
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        color: selected ? cs.primaryContainer : cs.surfaceContainerHighest.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.6),
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.onPick(id),
          onLongPress: toggle,
          onSecondaryTap: toggle,
          child: LayoutBuilder(builder: (context, box) {
            // Narrow phone tiles: drop the star button (long-press still toggles) so names fit.
            final compact = box.maxWidth < 200;
            return Padding(
            padding: EdgeInsets.fromLTRB(compact ? 6 : 8, 6, compact ? 6 : 2, 6),
            child: Row(children: [
              Container(
                width: compact ? 28 : 32,
                height: compact ? 28 : 32,
                decoration: BoxDecoration(
                  color: selected ? cs.primary : cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  selected ? Icons.check : (GamePickerGrid.categoryIcons['${g['category']}'] ?? Icons.games),
                  size: compact ? 16 : 18,
                  color: selected ? cs.onPrimary : cs.onSecondaryContainer,
                ),
              ),
              SizedBox(width: compact ? 6 : 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      _highlight(name, q, TextStyle(fontWeight: FontWeight.bold, color: fg), cs),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        compact && GamePickerGrid.playersLabel(g).isNotEmpty ? GamePickerGrid.playersLabel(g) : meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.65)),
                      ),
                  ],
                ),
              ),
              if (app != null && compact && fav)
                const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Icon(Icons.star, size: 14, color: Colors.amber),
                )
              else if (app != null && !compact)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  iconSize: 18,
                  tooltip: auroraT(fav ? '取消收藏' : '收藏'),
                  onPressed: toggle,
                  icon: Icon(
                    fav ? Icons.star : Icons.star_border,
                    color: fav ? Colors.amber : fg.withValues(alpha: 0.35),
                  ),
                ),
            ]),
            );
          }),
        ),
      ),
    );
  }

  /// Bold/tinted match of [q] inside [text].
  static TextSpan _highlight(String text, String q, TextStyle base, ColorScheme cs) {
    if (q.isEmpty) return TextSpan(text: text, style: base);
    final at = text.toLowerCase().indexOf(q);
    if (at < 0) return TextSpan(text: text, style: base);
    return TextSpan(style: base, children: [
      TextSpan(text: text.substring(0, at)),
      TextSpan(
        text: text.substring(at, at + q.length),
        style: TextStyle(color: cs.primary, backgroundColor: cs.primary.withValues(alpha: 0.18)),
      ),
      TextSpan(text: text.substring(at + q.length)),
    ]);
  }
}

/// Renders option dropdowns for a game definition.
class GameOptionsForm extends StatelessWidget {
  final Map<String, dynamic> game;
  final Map<String, dynamic> values;
  final void Function(String key, Object value)? onChanged;
  const GameOptionsForm({super.key, required this.game, required this.values, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final opts = (game['options'] as List? ?? []).cast<Map>();
    if (opts.isEmpty) return const AuroraText('该游戏没有可调整的选项');
    return Wrap(spacing: 12, runSpacing: 10, children: [
      for (final o in opts)
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<Object>(
            initialValue: values[o['key']] ?? o['default'],
            isExpanded: true,
            decoration: InputDecoration(labelText: auroraT('${o['label']}')),
            items: [
              for (final c in (o['choices'] as List).cast<Map>())
                DropdownMenuItem(value: c['value'] as Object, child: Text(auroraT('${c['label']}'), overflow: TextOverflow.ellipsis)),
            ],
            onChanged: onChanged == null ? null : (v) => onChanged!('${o['key']}', v!),
          ),
        ),
    ]);
  }
}

class CreateRoomDialog extends StatefulWidget {
  final AppState app;
  const CreateRoomDialog({super.key, required this.app});
  @override
  State<CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<CreateRoomDialog> {
  late final TextEditingController _name = TextEditingController(text: '${widget.app.name}的房间');
  final _pwd = TextEditingController();
  bool _private = false;
  bool _showPwd = false;
  late String _game = widget.app.prefs.getString('lastGame') ?? '${widget.app.games.first['id']}';
  final Map<String, dynamic> _opts = {};

  @override
  void dispose() {
    _name.dispose();
    _pwd.dispose();
    super.dispose();
  }

  void _submit() {
    widget.app.prefs.setString('lastGame', _game);
    Navigator.pop(context, CreateRoomResult(_name.text.trim(), _game, Map.of(_opts), _pwd.text, _private));
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.app.gameInfo(_game) ?? widget.app.games.first;
    _game = '${g['id']}';
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 760;
    final picker = GamePickerGrid(
      games: widget.app.games,
      selected: _game,
      onPick: (id) => setState(() {
        _game = id;
        _opts.clear();
      }),
    );
    final players = GamePickerGrid.playersLabel(g);
    final settings = ListView(
      padding: EdgeInsets.fromLTRB(wide ? 16 : 4, 12, 4, 12),
      children: [
        TextField(
          controller: _name,
          maxLength: 24,
          decoration: InputDecoration(
            labelText: auroraT('房间名'),
            prefixIcon: const Icon(Icons.meeting_room_outlined),
            counterText: '',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pwd,
          obscureText: !_showPwd,
          decoration: InputDecoration(
            labelText: auroraT('密码（可选）'),
            prefixIcon: const Icon(Icons.key),
            suffixIcon: IconButton(
              tooltip: auroraT(_showPwd ? '隐藏密码' : '显示密码'),
              icon: Icon(_showPwd ? Icons.visibility_off : Icons.visibility, size: 18),
              onPressed: () => setState(() => _showPwd = !_showPwd),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, icon: Icon(Icons.public, size: 16), label: AuroraText('公开')),
            ButtonSegment(value: true, icon: Icon(Icons.lock_outline, size: 16), label: AuroraText('私密')),
          ],
          selected: {_private},
          onSelectionChanged: (v) => setState(() => _private = v.first),
        ),
        const SizedBox(height: 6),
        AuroraText(
          _private ? '不在大厅显示，仅凭 5 位房间号进入' : '所有人都能在大厅看到并加入',
          style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(GamePickerGrid.categoryIcons[widget.app.games.firstWhere((x) => x['id'] == _game, orElse: () => g)['category']] ?? Icons.games,
                  size: 18, color: cs.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text('${g['name']}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface)),
              ),
              if (players.isNotEmpty)
                Text(players, style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.7))),
            ]),
            const SizedBox(height: 6),
            Text('${g['description']}', style: const TextStyle(fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 14),
        GameOptionsForm(
          key: ValueKey(_game),
          game: g,
          values: _opts,
          onChanged: (k, v) => setState(() => _opts[k] = v),
        ),
      ],
    );

    final footer = Row(children: [
      if (!wide)
        Expanded(
          child: Row(children: [
            Icon(Icons.sports_esports, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text('${g['name']}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ]),
        )
      else
        const Spacer(),
      TextButton(onPressed: () => Navigator.pop(context), child: const AuroraText('取消')),
      const SizedBox(width: 8),
      FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.add), label: const AuroraText('创建')),
    ]);

    final body = wide
        ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: picker),
            const VerticalDivider(width: 1),
            SizedBox(width: 320, child: settings),
          ])
        : DefaultTabController(
            length: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TabBar(tabs: [
                Tab(height: 36, child: AuroraText('选择游戏', maxLines: 1, overflow: TextOverflow.ellipsis)),
                Tab(height: 36, child: AuroraText('房间设置', maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 8),
              Expanded(child: TabBarView(children: [picker, settings])),
            ]),
          );

    final compactH = size.height < 500;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: size.width < 500 ? 8 : 32, vertical: compactH ? 8 : 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 680),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, compactH ? 6 : 12, 16, compactH ? 8 : 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(Icons.add_circle_outline, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: AuroraText('创建房间',
                    style: Theme.of(context).textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                tooltip: auroraT('关闭'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ]),
            SizedBox(height: compactH ? 2 : 6),
            Expanded(child: body),
            SizedBox(height: compactH ? 4 : 10),
            footer,
          ]),
        ),
      ),
    );
  }
}
