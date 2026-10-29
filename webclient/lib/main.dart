import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/connect_screen.dart';
import 'screens/local_game_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/room_screen.dart';
import 'state/app_state.dart';
import 'net/connection.dart';
import 'theme/themes.dart';
import 'widgets/mahjong_table.dart';
import 'platform/resume_scope.dart';
import 'i18n/aurora_i18n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = AppState();
  await app.load();
  await MjAutoState.load(app.prefs);
  runApp(AuroraApp(app));
}

/// Makes AppState available to the whole tree.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState app, required super.child})
    : super(notifier: app);
  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

class AuroraApp extends StatefulWidget {
  final AppState app;
  const AuroraApp(this.app, {super.key});
  @override
  State<AuroraApp> createState() => _AuroraAppState();
}

class _AuroraAppState extends State<AuroraApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<String>? _toastSub;

  @override
  void initState() {
    super.initState();
    widget.app.addListener(_rebuild);
    _toastSub = widget.app.toasts.listen((t) {
      _messenger.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(t),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
    });
  }

  void _rebuild() {
    // AppState notifies on every chat line, game update, voice level... Screens
    // depend on AppScope and rebuild themselves; the root (MaterialApp, theme,
    // locale) only needs to rebuild when something it actually uses changed.
    final sig = _signature(widget.app);
    if (_sigEquals(sig, _lastSig)) return;
    setState(() {});
  }

  List<Object?> _lastSig = const [];

  static int _homeKind(AppState app) {
    if (!app.hasProfile) return 0;
    if (app.local != null) return 1;
    if (app.state != ConnState.connected && app.myId == 0) return 2;
    if (app.room != null) return 3;
    return 4;
  }

  static List<Object?> _signature(AppState app) =>
      [_homeKind(app), app.themeId, app.fontFamily, app.language, app.uiScale];

  static bool _sigEquals(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  final Map<String, ThemeData> _themeCache = {};

  ThemeData _themeData(AppState app) => _themeCache.putIfAbsent(
        '${app.themeId}|${app.fontFamily}',
        () => themeById(app.themeId).toThemeData(fontFamily: app.fontFamily),
      );

  @override
  void dispose() {
    widget.app.removeListener(_rebuild);
    _toastSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    _lastSig = _signature(app);
    final theme = themeById(app.themeId);
    final Widget home = switch (_homeKind(app)) {
      0 => const ProfileScreen(firstRun: true),
      1 => const LocalGameScreen(),
      2 => const ConnectScreen(),
      3 => const RoomScreen(),
      _ => const LobbyScreen(),
    };
    return AppScope(
      app: app,
      child: AuroraI18n(
        language: app.auroraLanguage,
        child: MaterialApp(
          title: 'Aurora',
          locale: app.auroraLanguage.locale,
          supportedLocales: AuroraLanguage.locales,
          localizationsDelegates: AuroraLanguage.delegates,
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: _messenger,
          theme: _themeData(app),
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.linear(app.uiScale)),
              child: DecoratedBox(
                decoration: theme.backgroundDecoration,
                child: Shortcuts(
                  shortcuts: const <ShortcutActivator, Intent>{},
                  child: child!,
                ),
              ),
            );
          },
          home: ResumeScope(
            app: app,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey('${home.runtimeType}:${app.language}'),
                child: home,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Utility used by screens for copy-to-clipboard.
void copyText(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  AppScope.read(context).toast('已复制');
}
