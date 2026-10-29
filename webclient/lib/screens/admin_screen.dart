import 'package:flutter/material.dart';

import '../i18n/aurora_i18n.dart';
import '../main.dart';
import '../widgets/common.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _tokenCtl;
  final TextEditingController _announceCtl = TextEditingController();
  late final TabController _tabs = TabController(length: 3, vsync: this);
  String _selectedWordFile = 'drawguess.txt';
  final TextEditingController _wordEditorCtl = TextEditingController();
  String? _loadedWordSnapshot;

  @override
  void initState() {
    super.initState();
    final app = AppScope.read(context);
    _tokenCtl = TextEditingController(text: app.adminToken);
    if (app.adminToken.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) app.sendAdmin('state');
      });
    }
  }

  @override
  void dispose() {
    _tokenCtl.dispose();
    _announceCtl.dispose();
    _wordEditorCtl.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _syncWordEditor(Map<String, dynamic>? words) {
    if (words == null) return;
    final raw = '${words[_selectedWordFile] ?? ''}';
    final sig = '$_selectedWordFile:${raw.hashCode}:${raw.length}';
    if (_loadedWordSnapshot != sig) {
      _loadedWordSnapshot = sig;
      _wordEditorCtl.text = raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final st = app.adminState;
    final words = (st?['words'] as Map?)?.cast<String, dynamic>();
    _syncWordEditor(words);
    final users = [
      for (final u in (st?['users'] as List? ?? const []))
        if (u is Map) u.cast<String, dynamic>(),
    ];
    final rooms = [
      for (final r in (st?['rooms'] as List? ?? const []))
        if (r is Map) r.cast<String, dynamic>(),
    ];
    final bannedIps = [
      for (final ip in (st?['bannedIps'] as List? ?? const [])) '$ip',
    ];
    final uptimeSec = (st?['uptimeSec'] as num?)?.toInt() ?? 0;
    final uptimeStr =
        '${uptimeSec ~/ 3600}h ${(uptimeSec % 3600) ~/ 60}m ${uptimeSec % 60}s';

    return Scaffold(
      appBar: AppBar(
        title: const AuroraText('服主管理面板'),
        actions: [
          if (st != null)
            IconButton(
              tooltip: auroraT('刷新状态'),
              icon: const Icon(Icons.refresh),
              onPressed: () => app.sendAdmin('state'),
            ),
        ],
        bottom: st == null
            ? null
            : TabBar(
                controller: _tabs,
                tabs: [
                  Tab(text: '概览与房间 (${rooms.length})'),
                  Tab(text: '在线玩家 (${users.length})'),
                  const Tab(text: '自定义词库热重载'),
                ],
              ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tokenCtl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: auroraT('管理员密钥 (adminToken)'),
                      hintText: auroraT('在服务端控制台或 aurora_server.json 查看'),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (v) => app.sendAdmin('state', token: v),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () =>
                      app.sendAdmin('state', token: _tokenCtl.text),
                  icon: const Icon(Icons.lock_open, size: 18),
                  label: const AuroraText('验证并读取'),
                ),
              ],
            ),
          ),
          if (st == null)
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: AuroraText(
                    '请输入服务端启动时显示的管理员密钥（adminToken）以解锁网页端管理功能。',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  // Tab 1: Overview, Broadcast & Rooms
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.timer, size: 16),
                            label: Text('运行时长: $uptimeStr'),
                          ),
                          Chip(
                            avatar: const Icon(Icons.people, size: 16),
                            label: Text('在线玩家: ${users.length}'),
                          ),
                          Chip(
                            avatar: const Icon(Icons.meeting_room, size: 16),
                            label: Text('活动房间: ${rooms.length}'),
                          ),
                          Chip(
                            avatar: const Icon(Icons.smart_toy, size: 16),
                            label: Text('${st['aiStatus'] ?? ''}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.bolt, size: 16),
                            label: const AuroraText('测试 AI 连接'),
                            onPressed: () => app.sendAdmin('test_ai'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _announceCtl,
                              decoration: InputDecoration(
                                labelText: auroraT('发送全服公告'),
                                hintText: auroraT('输入公告内容，所有在线玩家将收到弹窗与系统消息'),
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => _sendAnnounce(app),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => _sendAnnounce(app),
                            icon: const Icon(Icons.campaign),
                            label: const AuroraText('广播'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const AuroraText(
                        '当前房间列表',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (rooms.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: AuroraText('暂无活动房间'),
                        )
                      else
                        for (final r in rooms)
                          Card(
                            child: ListTile(
                              title: Text(
                                '#${r['id']} ${r['name']} (${r['gameName']})',
                              ),
                              subtitle: Text(
                                '${r['playing'] == true ? '对局中' : '等待中'} · 座位 ${r['players']}/${r['seats']} · 成员 ${r['members']}${r['private'] == true ? ' · 私密' : ''}',
                              ),
                              trailing: OutlinedButton.icon(
                                onPressed: () => app.sendAdmin(
                                  'close_room',
                                  extra: {'room': r['id']},
                                ),
                                icon: const Icon(Icons.delete_outline, size: 18),
                                label: const AuroraText('强制关闭'),
                              ),
                            ),
                          ),
                    ],
                  ),
                  // Tab 2: Online Players & Banned IPs
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (bannedIps.isNotEmpty) ...[
                        const AuroraText(
                          '已封禁 IP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final ip in bannedIps)
                              InputChip(
                                label: Text(ip),
                                onDeleted: () => app.sendAdmin(
                                  'unban',
                                  extra: {'ip': ip},
                                ),
                              ),
                          ],
                        ),
                        const Divider(height: 24),
                      ],
                      const AuroraText(
                        '在线玩家',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final u in users)
                        Card(
                          child: ListTile(
                            leading: Avatar(
                              (u['avatar'] as num?)?.toInt() ?? 1,
                              size: 36,
                            ),
                            title: Text('#${u['id']} ${u['name']}'),
                            subtitle: Text(
                              'IP: ${u['ip']} · ${(u['room'] as String?)?.isNotEmpty == true ? '房间 ${u['room']}' : '大厅'}',
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () => app.sendAdmin(
                                    'kick',
                                    extra: {'id': u['id'], 'ban': false},
                                  ),
                                  child: const AuroraText('踢出'),
                                ),
                                FilledButton.tonal(
                                  onPressed: () => app.sendAdmin(
                                    'kick',
                                    extra: {'id': u['id'], 'ban': true},
                                  ),
                                  child: const AuroraText('封禁IP'),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Tab 3: Word bank editor & hot reload
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (final f in const [
                              'drawguess.txt',
                              'undercover.txt',
                              'turtlesoup.txt',
                              'decrypto.txt',
                              'justone.txt',
                              'wavelength.txt',
                            ])
                              ChoiceChip(
                                label: Text(f),
                                selected: _selectedWordFile == f,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedWordFile = f;
                                    _loadedWordSnapshot = null;
                                    _syncWordEditor(words);
                                  });
                                },
                              ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => app.sendAdmin('reload_words'),
                              icon: const Icon(Icons.sync, size: 18),
                              label: const AuroraText('重载磁盘词库'),
                            ),
                            FilledButton.icon(
                              onPressed: () => app.sendAdmin(
                                'save_words',
                                extra: {
                                  'file': _selectedWordFile,
                                  'content': _wordEditorCtl.text,
                                },
                              ),
                              icon: const Icon(Icons.save, size: 18),
                              label: const AuroraText('保存并热重载'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: TextField(
                            controller: _wordEditorCtl,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: '# 每行一条词条，以 # 开头的行是注释',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _sendAnnounce(dynamic app) {
    final text = _announceCtl.text.trim();
    if (text.isEmpty) return;
    app.sendAdmin('announce', extra: {'text': text});
    _announceCtl.clear();
  }
}
