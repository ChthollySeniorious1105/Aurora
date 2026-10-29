import '../i18n/aurora_i18n.dart';

import 'package:aurora_shared/aurora_shared.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../widgets/chat_panel.dart';
import '../widgets/common.dart';
import '../widgets/game_picker.dart';
import 'admin_screen.dart';
import 'local_game_screen.dart';
import 'profile_screen.dart';
import 'replay_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import '../widgets/invite_dialog.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final TextEditingController _searchCtl = TextEditingController();
  String _statusFilter = 'all';
  String _catFilter = 'all';

  static const _categories = ['麻将', '棋类', '牌类', '桌游', '派对'];

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  void _quickJoin(BuildContext context) {
    final app = AppScope.read(context);
    if (!app.quickJoin()) {
      app.toast('暂无可直接加入的等待房间，为你打开创建房间');
      _create(context);
    }
  }

  Future<void> _create(BuildContext context) async {
    final app = AppScope.read(context);
    final res = await showDialog<CreateRoomResult>(
      useRootNavigator: false,
      context: context,
      builder: (_) => CreateRoomDialog(app: app),
    );
    if (res == null) return;
    app.send({
      't': 'create_room',
      'name': res.name,
      'game': res.game,
      'options': res.options,
      'password': res.password,
      'private': res.private,
    });
  }

  /// Enter a (possibly private) room by its 5-character code.
  Future<void> _joinByCode(BuildContext context) async {
    final ctl = TextEditingController();
    final pwd = TextEditingController();
    var spectate = false;
    final ok = await showDialog<bool>(
      useRootNavigator: false,
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const AuroraText('输入房间号'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctl,
                  autofocus: true,
                  maxLength: 5,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    fontSize: 22,
                    letterSpacing: 6,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: auroraT('例如 A7K2Q'),
                    counterText: '',
                  ),
                  onSubmitted: (_) => Navigator.pop(c, true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pwd,
                  obscureText: true,
                  decoration: InputDecoration(labelText: auroraT('房间密码（如有）')),
                  onSubmitted: (_) => Navigator.pop(c, true),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: spectate,
                  onChanged: (v) => set(() => spectate = v ?? false),
                  title: const AuroraText('以观战者身份进入'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const AuroraText('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const AuroraText('进入'),
            ),
          ],
        ),
      ),
    );
    final code = ctl.text.trim().toUpperCase();
    if (ok != true || code.isEmpty) return;
    if (!context.mounted) return;
    AppScope.read(context).send({
      't': 'join_room',
      'room': code,
      'password': pwd.text,
      'spectate': spectate,
    });
  }

  Future<void> _join(
    BuildContext context,
    Map<String, dynamic> r, {
    bool spectate = false,
  }) async {
    final app = AppScope.read(context);
    var pwd = '';
    if (r['locked'] == true) {
      final ctl = TextEditingController();
      final ok = await showDialog<bool>(
        useRootNavigator: false,
        context: context,
        builder: (c) => AlertDialog(
          title: const AuroraText('输入房间密码'),
          content: TextField(
            controller: ctl,
            autofocus: true,
            obscureText: true,
            onSubmitted: (_) => Navigator.pop(c, true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const AuroraText('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const AuroraText('进入'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      pwd = ctl.text;
    }
    app.send({
      'room': r['id'],
      't': 'join_room',
      'password': pwd,
      'spectate': spectate,
    });
  }

  static void _push(BuildContext context, Widget w) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  static bool _playing(Map<String, dynamic> r) => r['playing'] == true;

  static bool _full(Map<String, dynamic> r) {
    final seats = asInt(r['seats'], 0);
    return seats > 0 && asInt(r['players'], 0) >= seats;
  }

  /// Waiting room with a free seat.
  static bool _joinable(Map<String, dynamic> r) => !_playing(r) && !_full(r);

  void _clearFilters() => setState(() {
        _searchCtl.clear();
        _statusFilter = 'all';
        _catFilter = 'all';
      });

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final wide = MediaQuery.of(context).size.width > 900;
    final q = _searchCtl.text.trim().toLowerCase();
    final catOf = {for (final g in app.games) '${g['id']}': '${g['category']}'};
    String cat(Map<String, dynamic> r) => catOf['${r['game']}'] ?? '';

    bool matchesSearch(Map<String, dynamic> r) =>
        q.isEmpty ||
        '${r['id']}'.toLowerCase().contains(q) ||
        '${r['name']}'.toLowerCase().contains(q) ||
        '${r['gameName']}'.toLowerCase().contains(q) ||
        auroraGameText('${r['gameName']}').toLowerCase().contains(q);
    bool matchesStatus(Map<String, dynamic> r) =>
        _statusFilter == 'all' ||
        (_statusFilter == 'waiting' && !_playing(r)) ||
        (_statusFilter == 'playing' && _playing(r));
    bool matchesCat(Map<String, dynamic> r) => _catFilter == 'all' || cat(r) == _catFilter;

    // Counts shown on the chips respect the other filters.
    final searched = [for (final r in app.rooms) if (matchesSearch(r)) r];
    final statusCount = {
      'all': searched.where(matchesCat).length,
      'waiting': searched.where((r) => matchesCat(r) && !_playing(r)).length,
      'playing': searched.where((r) => matchesCat(r) && _playing(r)).length,
    };
    final catCount = <String, int>{
      'all': searched.where(matchesStatus).length,
      for (final c in _categories) c: searched.where((r) => matchesStatus(r) && cat(r) == c).length,
    };
    // Rooms you can sit down in right away come first, then locked ones, then running games.
    int rank(Map<String, dynamic> r) => _joinable(r) ? (r['locked'] == true ? 1 : 0) : (_playing(r) ? 3 : 2);
    final filteredRooms = [
      for (final r in searched)
        if (matchesStatus(r) && matchesCat(r)) r,
    ];
    final order = {for (var i = 0; i < filteredRooms.length; i++) filteredRooms[i]: i};
    filteredRooms.sort((a, b) {
      final c = rank(a).compareTo(rank(b));
      return c != 0 ? c : order[a]!.compareTo(order[b]!);
    });

    Widget chip(String label, int count, bool selected, VoidCallback onTap, {IconData? icon}) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Center(
            child: ChoiceChip(
              visualDensity: VisualDensity.compact,
              avatar: icon == null ? null : Icon(icon, size: 16),
              label: Text('${auroraT(label)} $count'),
              selected: selected,
              onSelected: (_) => onTap(),
            ),
          ),
        );

    final quickJoinButton = FilledButton.tonalIcon(
      onPressed: () => _quickJoin(context),
      icon: const Icon(Icons.bolt, size: 18),
      label: const AuroraText('快速加入'),
    );

    final filterBar = Material(
      color: cs.surface.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _searchCtl,
                          onChanged: (_) => setState(() {}),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: auroraT('搜索房间号 / 房间名 / 游戏'),
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _searchCtl.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: auroraT('清除'),
                                    icon: const Icon(Icons.clear, size: 16),
                                    padding: EdgeInsets.zero,
                                    onPressed: () => setState(_searchCtl.clear),
                                  ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(message: auroraT('加入第一个有空位的等待房间'), child: quickJoinButton),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (val, label) in const [
                    ('all', '全部状态'),
                    ('waiting', '等待中'),
                    ('playing', '对局中'),
                  ])
                    chip(label, statusCount[val]!, _statusFilter == val, () => setState(() => _statusFilter = val)),
                  const VerticalDivider(width: 14, indent: 8, endIndent: 8),
                  chip('全部分类', catCount['all']!, _catFilter == 'all', () => setState(() => _catFilter = 'all')),
                  for (final c in _categories)
                    chip(
                      auroraCategory(c),
                      catCount[c]!,
                      _catFilter == c,
                      () => setState(() => _catFilter = _catFilter == c ? 'all' : c),
                      icon: GamePickerGrid.categoryIcons[c],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final fab = !(app.rooms.isEmpty || wide);
    final Widget roomList;
    if (app.rooms.isEmpty) {
      roomList = _EmptyLobby(
        onCreate: () => _create(context),
        onJoinCode: () => _joinByCode(context),
        onLocal: () => _push(context, const LocalSetupScreen()),
      );
    } else {
      roomList = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          filterBar,
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                app.send({'t': 'list_rooms'});
                await Future<void>.delayed(const Duration(milliseconds: 500));
              },
              child: filteredRooms.isEmpty
                  ? LayoutBuilder(
                      builder: (context, box) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: box.maxHeight),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off, size: 44, color: cs.onSurface.withValues(alpha: 0.5)),
                                const SizedBox(height: 8),
                                const AuroraText('没有匹配的房间'),
                                const SizedBox(height: 4),
                                TextButton(onPressed: _clearFilters, child: const AuroraText('清除搜索与筛选')),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(12, 8, 12, fab ? 88 : 12),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 380,
                        mainAxisExtent: 124,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemCount: filteredRooms.length,
                      itemBuilder: (context, i) {
                        final r = filteredRooms[i];
                        return _RoomCard(
                          key: ValueKey('room:${r['id']}'),
                          room: r,
                          category: cat(r),
                          onJoin: () => _join(context, r),
                          onSpectate: () => _join(context, r, spectate: true),
                        );
                      },
                    ),
            ),
          ),
        ],
      );
    }
    final lockColor = Theme.of(context).brightness == Brightness.dark ? Colors.greenAccent : Colors.green.shade700;
    return Scaffold(
      appBar: AppBar(
        title: Tooltip(
          message: auroraT('已加密连接 · 服务器指纹 {0}', [app.serverFingerprint ?? '-']),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock, size: 16, color: lockColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  app.serverName.isEmpty ? auroraT('大厅') : app.serverName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (wide && app.rooms.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: () => _create(context),
                icon: const Icon(Icons.add),
                label: const AuroraText('创建房间'),
              ),
            ),
          IconButton(
            tooltip: auroraT('输入房间号'),
            onPressed: () => _joinByCode(context),
            icon: const Icon(Icons.vpn_key),
          ),
          if (wide) ...[
            IconButton(
              tooltip: auroraT('对局回放'),
              onPressed: () => _push(context, const ReplaysScreen()),
              icon: const Icon(Icons.slideshow),
            ),
            IconButton(
              tooltip: auroraT('战绩与排行'),
              onPressed: () => _push(context, const StatsScreen()),
              icon: const Icon(Icons.emoji_events),
            ),
            IconButton(
              tooltip: auroraT('单机游戏'),
              onPressed: () => _push(context, const LocalSetupScreen()),
              icon: const Icon(Icons.smart_toy),
            ),
            _OnlinePill(count: app.onlineCount),
            IconButton(
              tooltip: auroraT('刷新'),
              onPressed: () => app.send({'t': 'list_rooms'}),
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: auroraT('主题与设置'),
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
              icon: const Icon(Icons.palette),
            ),
            if (app.serverHasAdmin)
              IconButton(
                tooltip: auroraT('服主管理'),
                onPressed: () => _push(context, const AdminScreen()),
                icon: const Icon(Icons.admin_panel_settings_outlined),
              ),
            Tooltip(
              message: auroraT('个人资料'),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Avatar(app.avatar, size: 32),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(app.name, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: auroraT('断开连接'),
              onPressed: app.disconnect,
              icon: const Icon(Icons.logout),
            ),
          ] else ...[
            Builder(
              builder: (context) => IconButton(
                tooltip: auroraT('大厅聊天'),
                icon: Badge(
                  isLabelVisible: app.unreadChat > 0,
                  label: Text('${app.unreadChat > 99 ? '99+' : app.unreadChat}'),
                  child: const Icon(Icons.chat),
                ),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: auroraT('菜单'),
              icon: Avatar(app.avatar, size: 30),
              onSelected: (v) {
                switch (v) {
                  case 'refresh':
                    app.send({'t': 'list_rooms'});
                  case 'replays':
                    _push(context, const ReplaysScreen());
                  case 'stats':
                    _push(context, const StatsScreen());
                  case 'local':
                    _push(context, const LocalSetupScreen());
                  case 'settings':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  case 'profile':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  case 'admin':
                    _push(context, const AdminScreen());
                  case 'logout':
                    app.disconnect();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text('${app.name} · ${auroraT('在线 {0}', [app.onlineCount])}'),
                ),
                const PopupMenuItem(
                  value: 'refresh',
                  child: ListTile(
                    leading: Icon(Icons.refresh),
                    title: AuroraText('刷新'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'replays',
                  child: ListTile(
                    leading: Icon(Icons.slideshow),
                    title: AuroraText('对局回放'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'stats',
                  child: ListTile(
                    leading: Icon(Icons.emoji_events),
                    title: AuroraText('战绩与排行'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'local',
                  child: ListTile(
                    leading: Icon(Icons.smart_toy),
                    title: AuroraText('单机游戏'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'profile',
                  child: ListTile(
                    leading: Icon(Icons.person),
                    title: AuroraText('个人资料'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                    leading: Icon(Icons.palette),
                    title: AuroraText('主题与设置'),
                  ),
                ),
                if (app.serverHasAdmin)
                  const PopupMenuItem(
                    value: 'admin',
                    child: ListTile(
                      leading: Icon(Icons.admin_panel_settings_outlined),
                      title: AuroraText('服主管理'),
                    ),
                  ),
                const PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout),
                    title: AuroraText('断开连接'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      endDrawer: wide
          ? null
          : const Drawer(
              width: 340,
              child: SafeArea(child: ChatPanel(title: '大厅聊天', voice: false)),
            ),
      floatingActionButton: fab
          ? FloatingActionButton.extended(
              onPressed: () => _create(context),
              icon: const Icon(Icons.add),
              label: const AuroraText('创建房间'),
            )
          : null,
      body: Column(
        children: [
          InvitationBanner(app: app),
          if (app.lastError != null)
            MaterialBanner(
              content: Text(app.lastError!),
              actions: [
                TextButton(
                  onPressed: app.disconnect,
                  child: const AuroraText('返回'),
                ),
              ],
            ),
          Expanded(
            child: wide
                ? Row(
                    children: [
                      Expanded(child: roomList),
                      SizedBox(
                        width: 340,
                        child: Card(
                          margin: const EdgeInsets.all(12),
                          child: ChatPanel(title: '大厅聊天', voice: false),
                        ),
                      ),
                    ],
                  )
                : roomList,
          ),
        ],
      ),
    );
  }
}

/// "● 在线 7" pill for the desktop app bar.
class _OnlinePill extends StatelessWidget {
  final int count;
  const _OnlinePill({required this.count});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(auroraT('在线 {0}', [count]), style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// Lobby with no rooms at all: explain what to do next.
class _EmptyLobby extends StatelessWidget {
  final VoidCallback onCreate, onJoinCode, onLocal;
  const _EmptyLobby({required this.onCreate, required this.onJoinCode, required this.onLocal});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
                      child: Icon(Icons.meeting_room_outlined, size: 38, color: cs.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AuroraText(
                    '还没有房间，创建一个吧！',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  AuroraText(
                    '创建房间后把房间号或邀请链接发给好友即可一起玩',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    autofocus: true,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    onPressed: onCreate,
                    icon: const Icon(Icons.add),
                    label: const AuroraText('创建房间'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onJoinCode,
                        icon: const Icon(Icons.vpn_key, size: 18),
                        label: const AuroraText('输入房间号'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onLocal,
                        icon: const Icon(Icons.smart_toy, size: 18),
                        label: const AuroraText('单机游戏'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One room in the lobby grid.
class _RoomCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final String category;
  final VoidCallback onJoin, onSpectate;
  const _RoomCard({
    super.key,
    required this.room,
    required this.category,
    required this.onJoin,
    required this.onSpectate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final r = room;
    final playing = r['playing'] == true;
    final locked = r['locked'] == true;
    final players = asInt(r['players'], 0), seats = asInt(r['seats'], 0);
    final full = seats > 0 && players >= seats;
    final joinable = !playing && !full;
    final (statusText, statusColor) = playing
        ? ('对局中', Colors.orange)
        : full
            ? ('已满', cs.outline)
            : ('等待中', Colors.green);
    final muted = cs.onSurface.withValues(alpha: 0.7);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: joinable
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: cs.primary.withValues(alpha: 0.55)),
            )
          : null,
      child: InkWell(
        onTap: onJoin,
        onLongPress: onSpectate,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      GamePickerGrid.categoryIcons[category] ?? Icons.sports_esports,
                      color: cs.onSecondaryContainer,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r['name']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: '#${r['id']}',
                              style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: '  ${auroraGameText('${r['gameName']}')}'),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: muted),
                        ),
                      ],
                    ),
                  ),
                  if (locked)
                    Tooltip(
                      message: auroraT('需要密码'),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4, right: 4),
                        child: Icon(Icons.lock, size: 18, color: cs.tertiary),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  _StatusPill(text: statusText, color: statusColor),
                  const SizedBox(width: 8),
                  // Counts shrink first so the actions always fit narrow cards.
                  Expanded(
                    child: Tooltip(
                      message: auroraT('座位 {0}/{1} · 房间内 {2} 人', [players, seats, r['members'] ?? players]),
                      // Scale the counts down (never overflow) when the card is narrow or labels are long.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SeatDots(players: players, seats: seats),
                            const SizedBox(width: 10),
                            Icon(Icons.people_alt_outlined, size: 15, color: muted),
                            const SizedBox(width: 2),
                            Text('${r['members'] ?? players}', style: TextStyle(fontSize: 12, color: muted)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: auroraT('观战'),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                    onPressed: onSpectate,
                  ),
                  if (joinable)
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      onPressed: onJoin,
                      child: const AuroraText('加入'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusPill({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          AuroraText(text, style: TextStyle(fontSize: 12, color: cs.onSurface, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Filled / empty seat dots (falls back to "3/12" for big tables).
class _SeatDots extends StatelessWidget {
  final int players, seats;
  const _SeatDots({required this.players, required this.seats});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = Text(
      seats > 0 ? '$players/$seats' : '$players',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
    );
    if (seats <= 0 || seats > 8) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.event_seat, size: 15, color: cs.onSurface.withValues(alpha: 0.7)),
        const SizedBox(width: 3),
        label,
      ]);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < seats; i++)
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < players ? cs.primary : Colors.transparent,
              border: Border.all(color: cs.primary.withValues(alpha: 0.7), width: 1.2),
            ),
          ),
        const SizedBox(width: 3),
        label,
      ],
    );
  }
}
