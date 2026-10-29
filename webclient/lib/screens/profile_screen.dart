import '../i18n/aurora_i18n.dart';

import 'dart:math';

import 'package:aurora_shared/aurora_shared.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../widgets/common.dart';

/// Name + avatar editor (also shown on first launch).
class ProfileScreen extends StatefulWidget {
  final bool firstRun;
  const ProfileScreen({super.key, this.firstRun = false});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _tileExtent = 76.0, _spacing = 8.0, _gridPad = 10.0;

  late final TextEditingController _name;
  final _scroll = ScrollController();
  late int _avatar;
  String? _error;

  /// Grid geometry from the last layout, used to scroll the selection into view.
  int _cols = 1;
  double _rowExtent = _tileExtent + _spacing;
  bool _scrolledToInitial = false;

  @override
  void initState() {
    super.initState();
    final app = AppScope.read(context);
    _name = TextEditingController(text: app.name);
    _avatar = app.avatar.clamp(1, kAvatarCount);
  }

  @override
  void dispose() {
    _name.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _save() {
    final app = AppScope.read(context);
    final err = app.saveProfile(_name.text, _avatar);
    setState(() => _error = err);
    if (err == null && !widget.firstRun) Navigator.of(context).pop();
  }

  /// Scrolls the avatar grid so [_avatar] is visible (roughly centred).
  void _reveal({bool animate = true}) {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final row = (_avatar - 1) ~/ _cols;
    final target = (_gridPad + row * _rowExtent - (pos.viewportDimension - _rowExtent) / 2)
        .clamp(0.0, pos.maxScrollExtent);
    if (animate) {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    } else {
      _scroll.jumpTo(target);
    }
  }

  void _random() {
    setState(() => _avatar = 1 + Random().nextInt(kAvatarCount));
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  @override
  Widget build(BuildContext context) {
    final width = nameWidth(_name.text.trim());
    final cs = Theme.of(context).colorScheme;
    final narrow = MediaQuery.sizeOf(context).width < 560;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final nameField = TextField(
      controller: _name,
      maxLength: 18,
      textInputAction: TextInputAction.done,
      buildCounter:
          (
            _, {
            required currentLength,
            required isFocused,
            maxLength,
          }) => Text(
            '$width/18',
            style: TextStyle(
              fontSize: 12,
              color: width > kMaxNameWidth ? cs.error : null,
            ),
          ),
      decoration: InputDecoration(
        labelText: auroraT('昵称'),
        prefixIcon: const Icon(Icons.badge_outlined),
        helperText: auroraT('英文≤18 / 中文≤9 字'),
        helperMaxLines: 2,
        errorText:
            _error ?? (width > kMaxNameWidth ? auroraT('名称过长') : null),
      ),
      onChanged: (_) => setState(() => _error = null),
      onSubmitted: (_) => _save(),
    );
    final saveButton = FilledButton.icon(
      onPressed: _save,
      icon: const Icon(Icons.check),
      label: AuroraText(widget.firstRun ? '开始游戏' : '保存'),
    );
    final preview = Tooltip(
      message: auroraT('随机'),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _random,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: cs.primary, width: 2),
          ),
          child: Avatar(_avatar, size: narrow ? 60 : 72),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: AuroraText(widget.firstRun ? '欢迎来到 Aurora' : '个人资料'),
        automaticallyImplyLeading: !widget.firstRun,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          preview,
                          const SizedBox(width: 14),
                          Expanded(child: nameField),
                          if (!narrow) ...[
                            const SizedBox(width: 12),
                            Padding(padding: const EdgeInsets.only(top: 4), child: saveButton),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          auroraT('选择形象（共 {0} 种）', [kAvatarCount]),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text('#$_avatar', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: _random,
                        icon: const Icon(Icons.casino),
                        label: const AuroraText('随机'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final usable = box.maxWidth - _gridPad * 2;
                          _cols = max(1, ((usable + _spacing) / (_tileExtent + _spacing)).ceil());
                          final tile = (usable - (_cols - 1) * _spacing) / _cols;
                          _rowExtent = tile + _spacing;
                          // Decode thumbnails at the size they're shown (source PNGs are 128px).
                          final cache = min(128, (tile * dpr).ceil());
                          if (!_scrolledToInitial) {
                            _scrolledToInitial = true;
                            WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(animate: false));
                          }
                          return Scrollbar(
                            controller: _scroll,
                            child: GridView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.all(_gridPad),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: _cols,
                                mainAxisSpacing: _spacing,
                                crossAxisSpacing: _spacing,
                              ),
                              itemCount: kAvatarCount,
                              itemBuilder: (context, i) {
                                final id = i + 1;
                                return _AvatarChoice(
                                  id: id,
                                  selected: id == _avatar,
                                  cacheSize: cache,
                                  onTap: () => setState(() => _avatar = id),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (narrow) ...[
                    const SizedBox(height: 8),
                    SizedBox(height: 46, child: saveButton),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarChoice extends StatefulWidget {
  final int id;
  final bool selected;
  final int cacheSize;
  final VoidCallback onTap;
  const _AvatarChoice({required this.id, required this.selected, required this.cacheSize, required this.onTap});
  @override
  State<_AvatarChoice> createState() => _AvatarChoiceState();
}

class _AvatarChoiceState extends State<_AvatarChoice> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sel = widget.selected;
    return Semantics(
      selected: sel,
      button: true,
      label: auroraT('形象 {0}', [widget.id]),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: widget.onTap,
        onHover: (h) => setState(() => _hover = h),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedScale(
              scale: sel ? 1.0 : (_hover ? 0.96 : 0.9),
              duration: const Duration(milliseconds: 150),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: sel
                        ? cs.primary
                        : _hover
                            ? cs.primary.withValues(alpha: 0.5)
                            : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: sel ? [BoxShadow(color: cs.primary.withValues(alpha: 0.45), blurRadius: 10)] : null,
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: Image.asset(
                    Avatar.path(widget.id),
                    cacheWidth: widget.cacheSize,
                    cacheHeight: widget.cacheSize,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => ColoredBox(color: cs.surfaceContainerHighest),
                  ),
                ),
              ),
            ),
            if (sel)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 2),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.check, size: 14, color: cs.onPrimary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
