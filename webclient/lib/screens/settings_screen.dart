import 'package:flutter/material.dart';

import '../main.dart';
import '../i18n/aurora_i18n.dart';
import '../platform/sfx.dart';
import '../theme/themes.dart';
import '../widgets/chat_panel.dart';
import '../widgets/mahjong_table.dart';
import 'admin_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final v = app.voice;
    final current = themeById(app.themeId);
    return Scaffold(
      appBar: AppBar(title: const AuroraText('主题与设置')),
      body: ListenableBuilder(
        listenable: v,
        // Exactly one scrollable on this screen (tests scroll it with scrollUntilVisible).
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            _Section(
              icon: Icons.palette_outlined,
              title: '${context.at('界面主题')} (${auroraThemes.length})',
              trailing: Text(
                current.name,
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
              ),
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final t in auroraThemes)
                      _ThemeTile(
                        t,
                        selected: t.id == app.themeId,
                        onTap: () => app.setTheme(t.id),
                      ),
                  ],
                ),
              ],
            ),
            _Section(
              icon: Icons.tune,
              title: context.at('界面'),
              children: [
                _AdaptiveTile(
                  title: const AuroraText('界面缩放'),
                  control: Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: app.uiScale,
                          min: 0.8,
                          max: 1.4,
                          divisions: 6,
                          label: '${(app.uiScale * 100).round()}%',
                          onChanged: app.setUiScale,
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text('${(app.uiScale * 100).round()}%', textAlign: TextAlign.end),
                      ),
                    ],
                  ),
                ),
                _AdaptiveTile(
                  title: const AuroraText('语言'),
                  control: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'zh', label: AuroraText('简体中文')),
                        ButtonSegment(value: 'en', label: AuroraText('English')),
                      ],
                      selected: {app.language},
                      onSelectionChanged: (v) => app.setLanguage(v.first),
                    ),
                  ),
                ),
              ],
            ),
            _Section(
              icon: Icons.volume_up_outlined,
              title: context.at('音效'),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const AuroraText('游戏音效'),
                  subtitle: const AuroraText('轮到我、开局、胜利/失败、表情提示音'),
                  value: app.sfx.enabled,
                  onChanged: app.setSfx,
                ),
                _AdaptiveTile(
                  title: const AuroraText('音效音量'),
                  control: Slider(
                    value: app.sfx.volume.clamp(0.0, 1.0),
                    divisions: 10,
                    label: '${(app.sfx.volume * 100).round()}%',
                    onChanged: app.sfx.enabled ? app.setSfxVolume : null,
                    onChangeEnd: (_) => app.sfx.play(SfxKind.turn),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const AuroraText('对局聊天弹幕'),
                  subtitle: const AuroraText('对局进行中将房间聊天与观战互动作为浮动气泡飘过'),
                  value: app.danmakuEnabled,
                  onChanged: app.setDanmaku,
                ),
              ],
            ),
            _Section(
              icon: Icons.grid_view_rounded,
              title: context.at('麻将'),
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: MjAutoState.doubleTap,
                  builder: (context, dbl, _) => _AdaptiveTile(
                    title: const AuroraText('出牌方式'),
                    subtitle: Text(
                      dbl
                          ? context.at('双击：先点选中，再点同一张打出')
                          : context.at('单击：点一下直接打出'),
                    ),
                    control: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: AuroraText('单击')),
                          ButtonSegment(value: true, label: AuroraText('双击')),
                        ],
                        selected: {dbl},
                        onSelectionChanged: (s) => MjAutoState.setDoubleTap(s.first),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            _Section(
              icon: Icons.mic_none,
              title: context.at('语音'),
              children: [
                _AdaptiveTile(
                  title: const AuroraText('降噪强度'),
                  subtitle: Text(
                    context.at(
                      const ['关闭降噪', '轻度', '标准', '强力'][v.noiseLevel.round().clamp(
                        0,
                        3,
                      )],
                    ),
                  ),
                  control: Slider(
                    value: v.noiseLevel,
                    min: 0,
                    max: 3,
                    divisions: 3,
                    onChanged: app.setNoise,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const AuroraText('按键说话'),
                  subtitle: const AuroraText('开启后需按住房间内的“按住说话”按钮才会发送语音'),
                  value: v.pushToTalk,
                  onChanged: app.setPtt,
                ),
                const SizedBox(height: 4),
                const VolumeSliders(),
              ],
            ),
            _Section(
              icon: Icons.dns_outlined,
              title: context.at('服务器'),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const AuroraText('服主管理面板'),
                  subtitle: const AuroraText('广播公告、管理房间与在线玩家、热重载自定义词库'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const AdminScreen())),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled card that groups related settings; centred and width-limited on desktop.
class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final List<Widget> children;
  const _Section({required this.icon, required this.title, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Card(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
                const SizedBox(height: 8),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Label on the left and control on the right; stacks vertically on narrow screens.
class _AdaptiveTile extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget control;
  const _AdaptiveTile({required this.title, required this.control, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DefaultTextStyle.merge(style: Theme.of(context).textTheme.bodyLarge, child: title),
        if (subtitle != null)
          DefaultTextStyle.merge(
            style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7)),
            child: subtitle!,
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, box) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: box.maxWidth < 520
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [label, const SizedBox(height: 4), control],
              )
            : Row(
                children: [
                  Expanded(child: label),
                  const SizedBox(width: 16),
                  SizedBox(width: 280, child: control),
                ],
              ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final AuroraTheme t;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeTile(this.t, {required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = t.dark ? Colors.white : Colors.black87;
    return Tooltip(
      message: '${t.name} · ${auroraT(t.dark ? '深色' : '浅色')}',
      waitDuration: const Duration(milliseconds: 500),
      child: Semantics(
        selected: selected,
        button: true,
        label: t.name,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 118,
              height: 78,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: t.background,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? t.primary : fg.withValues(alpha: 0.18),
                  width: selected ? 3 : 1,
                ),
                boxShadow: selected
                    ? [BoxShadow(color: t.primary.withValues(alpha: 0.45), blurRadius: 10)]
                    : null,
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _dot(t.primary, fg),
                      _dot(t.accent, fg),
                      _dot(t.table, fg),
                      const Spacer(),
                      if (selected)
                        Icon(Icons.check_circle, color: t.primary, size: 18)
                      else
                        Icon(
                          t.dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                          size: 14,
                          color: fg.withValues(alpha: 0.55),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot(Color c, Color fg) => Container(
    width: 14,
    height: 14,
    margin: const EdgeInsets.only(right: 4),
    decoration: BoxDecoration(
      color: c,
      shape: BoxShape.circle,
      border: Border.all(color: fg.withValues(alpha: 0.35)),
    ),
  );
}
