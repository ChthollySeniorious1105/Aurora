import '../i18n/aurora_i18n.dart';

import 'package:flutter/material.dart';

import '../main.dart';
import '../net/connection.dart';
import '../widgets/common.dart';
import 'local_game_screen.dart';
import 'profile_screen.dart';
import 'replay_screen.dart';
import 'settings_screen.dart';

/// Entry screen of the web client. The page was served by the Aurora server,
/// so it connects to that same server automatically (one click: open the URL);
/// the button is only needed after a manual disconnect or an error.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});
  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).maybeAutoConnect();
    });
  }

  /// Host part shown to the player (e.g. `play.example.com` / `192.168.1.10:7790`).
  String _serverLabel(String address) {
    final u = Uri.tryParse(address);
    if (u == null || u.host.isEmpty) return address;
    return u.hasPort ? '${u.host}:${u.port}' : u.host;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final busy = app.state == ConnState.connecting;
    final server = _serverLabel(app.address.isNotEmpty ? app.address : app.homeServer);
    final invite = app.pendingInvitation?.room;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'AURORA',
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 10,
                      color: cs.primary,
                      shadows: [Shadow(color: cs.secondary, blurRadius: 24)],
                    ),
                  ),
                  AuroraText(
                    '联机小游戏',
                    style: TextStyle(
                      fontSize: 16,
                      letterSpacing: 6,
                      color: cs.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Tooltip(
                            message: context.at('编辑昵称与头像'),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ProfileScreen(),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Row(
                                  children: [
                                    Avatar(app.avatar, size: 52),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            app.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          AuroraText(
                                            '点击修改昵称与头像',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: cs.onSurface.withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.edit, size: 18, color: cs.primary),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Divider(height: 20),
                          if (server.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.dns, size: 18, color: cs.onSurface.withValues(alpha: 0.7)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${context.at('服务器')}：$server',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.8)),
                                  ),
                                ),
                                _StatusDot(state: app.state),
                              ],
                            ),
                          if (invite != null) ...[
                            const SizedBox(height: 10),
                            _Notice(
                              icon: Icons.mail_outline,
                              color: cs.primary,
                              text: context.at('受邀加入房间 {0}，进入大厅后点击加入', [invite]),
                            ),
                          ],
                          if (app.lastError != null) ...[
                            const SizedBox(height: 10),
                            _Notice(
                              icon: Icons.error_outline,
                              color: cs.error,
                              text: app.lastError!,
                            ),
                          ],
                          if (app.keyMismatch != null) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.warning_amber),
                              label: const AuroraText('我确认服务器是可信的，信任新身份'),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  useRootNavigator: false,
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const AuroraText('信任新的服务器身份？'),
                                    content: const AuroraText(
                                      '只有在你确认服务器管理员重装/更换过服务器时才这样做。'
                                      '可以请管理员核对服务器控制台显示的"服务器指纹"。',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c, false),
                                        child: const AuroraText('取消'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const AuroraText('信任'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  app.trustNewServerKey(app.keyMismatch!);
                                }
                              },
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            // Enter / Space connects right away on desktop.
                            autofocus: true,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              // Derive from the theme so the font family / CJK fallback is kept.
                              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            onPressed: busy ? null : () => app.connect(),
                            icon: busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: AuroraText(busy ? '正在连接服务器…' : '进入大厅'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(260, 46),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LocalSetupScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.smart_toy),
                    label: const AuroraText('单机游戏（与电脑对战）'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ReplaysScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.slideshow),
                        label: const AuroraText('本机回放'),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.palette),
                        label: const AuroraText('主题与设置'),
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

/// Small coloured dot + label for the connection state.
class _StatusDot extends StatelessWidget {
  final ConnState state;
  const _StatusDot({required this.state});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (color, label) = switch (state) {
      ConnState.connected => (Colors.green, '已连接'),
      ConnState.connecting => (Colors.orange, '连接中…'),
      _ => (cs.outline, '未连接'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        AuroraText(label, style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.7))),
      ],
    );
  }
}

/// Tinted one-line notice (invitation / error) inside the connect card.
class _Notice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Notice({required this.icon, required this.color, required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}
