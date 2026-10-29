import 'dart:io';
import 'dart:ui' as ui;

import 'package:aurora_client/i18n/aurora_i18n.dart';
import 'package:aurora_client/main.dart';
import 'package:aurora_client/net/connection.dart';
import 'package:aurora_client/screens/connect_screen.dart';
import 'package:aurora_client/screens/lobby_screen.dart';
import 'package:aurora_client/screens/profile_screen.dart';
import 'package:aurora_client/screens/settings_screen.dart';
import 'package:aurora_client/screens/stats_screen.dart';
import 'package:aurora_client/state/app_state.dart';
import 'package:aurora_client/theme/themes.dart';
import 'package:aurora_client/widgets/game_picker.dart';
import 'package:aurora_client/widgets/invite_dialog.dart';
import 'package:aurora_client/widgets/party_panel.dart';
import 'package:aurora_shared/aurora_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lobby / picker / connect / profile / settings / stats screens at phone
/// portrait, phone landscape and desktop sizes. Fails on any exception or
/// layout overflow.
///
/// With `SHOTS=1` it also writes PNGs to `build/ui_shots/<TAG>_<theme>_<screen>_<size>.png`
/// (TAG env var, default `after`) for visual review.
void main() {
  final shots = Platform.environment['SHOTS'] == '1';
  final tag = Platform.environment['TAG'] ?? 'after';
  late AppState app;

  const sizes = {
    'phone': Size(390, 800),
    'land': Size(800, 390),
    'desk': Size(1280, 720),
  };

  final sampleRooms = <Map<String, dynamic>>[
    {'id': 'A7K2Q', 'name': '小明的房间', 'game': 'riichi4', 'gameName': '日本麻将（四人）', 'players': 3, 'seats': 4, 'members': 3, 'playing': false, 'locked': false},
    {'id': 'B5120', 'name': '斗地主开黑（有密码的超长房间名字测试一下省略号）', 'game': 'doudizhu', 'gameName': '斗地主', 'players': 3, 'seats': 3, 'members': 4, 'playing': true, 'locked': true},
    {'id': 'C7001', 'name': '卧底局', 'game': 'undercover', 'gameName': '谁是卧底', 'players': 6, 'seats': 12, 'members': 6, 'playing': false, 'locked': false},
    {'id': 'D1234', 'name': '象棋一盘', 'game': 'xiangqi', 'gameName': '中国象棋', 'players': 2, 'seats': 2, 'members': 2, 'playing': false, 'locked': false},
    {'id': 'E9999', 'name': 'UNO 派对', 'game': 'uno', 'gameName': 'UNO', 'players': 5, 'seats': 10, 'members': 7, 'playing': true, 'locked': false},
  ];

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'name': '小明', 'avatar': 42});
    app = AppState();
    app.prefs = await SharedPreferences.getInstance();
    app.name = '小明';
    app.avatar = 342;
    app.address = 'http://192.168.1.11:7790';
    app.games = [for (final g in gameRegistry) g.toJson()];
    app.serverName = '周末麻将局';
    app.onlineCount = 7;
    app.pid = 'p1';
    app.favoriteGames = ['doudizhu', 'gomoku'];
    app.recentGames = ['riichi4', 'uno', 'gomoku'];
    if (shots) await _loadFonts();
  });

  void setRoom() {
    app.myId = 1;
    app.room = {
      'id': 'A7K2Q',
      'host': 1,
      'playing': false,
      'seats': [
        {'client': {'id': 1, 'name': '小明'}, 'bot': false},
        {'client': {'id': 2, 'name': 'Alice'}, 'bot': false},
        {'client': null, 'bot': true},
      ],
      'party': {
        'queue': ['memorypairs', 'wordtiles', 'lightsout'],
        'index': 0,
        'finished': false,
        'roundComplete': true,
        'votes': {'1': 'wordtiles'},
        'scores': [
          {'name': '小明', 'points': 100, 'wins': 1},
          {'name': 'Alice', 'points': 50, 'wins': 0},
        ],
      },
    };
  }

  void fillStats() {
    app.myStats = {
      'games': 42,
      'wins': 17,
      'per': {
        'riichi4': {'p': 20, 'w': 7, 'elo': 1588},
        'doudizhu': {'p': 15, 'w': 8, 'elo': 1532},
        'gomoku': {'p': 7, 'w': 2, 'elo': 1470},
      },
    };
    app.leaderboards['riichi4'] = [
      {'name': 'Alice', 'avatar': 7, 'elo': 1712, 'p': 30, 'w': 20, 'pid': 'p2'},
      {'name': '雀士', 'avatar': 77, 'elo': 1650, 'p': 22, 'w': 12, 'pid': 'p3'},
      {'name': '小明', 'avatar': 342, 'elo': 1588, 'p': 20, 'w': 7, 'pid': 'p1'},
      {'name': 'Bob', 'avatar': 120, 'elo': 1501, 'p': 9, 'w': 3, 'pid': 'p4'},
    ];
  }

  /// name -> (build home, optional action after the first frame)
  final screens = <String, (Widget Function(), Future<void> Function(WidgetTester, BuildContext)?)>{
    'connect': (() {
      app.state = ConnState.disconnected;
      app.myId = 0;
      app.room = null;
      return const ConnectScreen();
    }, null),
    'lobby': (() {
      app.state = ConnState.connected;
      app.myId = 1;
      app.room = null;
      app.rooms = List.of(sampleRooms);
      return const LobbyScreen();
    }, null),
    'lobby_empty': (() {
      app.state = ConnState.connected;
      app.myId = 1;
      app.room = null;
      app.rooms = [];
      return const LobbyScreen();
    }, null),
    'create_room': (() {
      app.rooms = List.of(sampleRooms);
      return const Scaffold(body: SizedBox.expand());
    }, (tester, ctx) async {
      showDialog<CreateRoomResult>(context: ctx, builder: (_) => CreateRoomDialog(app: app));
    }),
    'picker': (() => Scaffold(body: SafeArea(child: GamePickerGrid(games: app.games, selected: 'doudizhu', onPick: (_) {}))), null),
    'profile': (() => const ProfileScreen(), null),
    'settings': (() => const SettingsScreen(), null),
    'stats': (() => const StatsScreen(), (tester, ctx) async {
      fillStats();
      app.touch();
    }),
    'stats_board': (() => const StatsScreen(initialTab: 1), (tester, ctx) async {
      fillStats();
      app.touch();
    }),
    'invite': (() {
      setRoom();
      app.publicWebUrl = 'https://play.example.com/';
      return const Scaffold(body: SizedBox.expand());
    }, (tester, ctx) async {
      showDialog<void>(context: ctx, builder: (_) => InviteDialog(app: app));
    }),
    'party': (() {
      setRoom();
      return Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(12), child: PartyPanel(app: app)));
    }, null),
  };

  Future<void> pumpScreen(WidgetTester tester, String name, Size size, AuroraTheme theme) async {
    final (build, after) = screens[name]!;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    final key = GlobalKey();
    final navKey = GlobalKey<NavigatorState>();
    final home = build();
    await tester.pumpWidget(AppScope(
      app: app,
      child: AuroraI18n(
        language: app.auroraLanguage,
        child: MaterialApp(
          key: ValueKey('$name$size${theme.id}${app.language}'),
          navigatorKey: navKey,
          debugShowCheckedModeBanner: false,
          locale: app.auroraLanguage.locale,
          supportedLocales: AuroraLanguage.locales,
          localizationsDelegates: AuroraLanguage.delegates,
          theme: theme.toThemeData(),
          builder: (c, child) => RepaintBoundary(
            key: key,
            child: DecoratedBox(decoration: theme.backgroundDecoration, child: child),
          ),
          home: home,
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    if (after != null) {
      await after(tester, navKey.currentContext!);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 400));
    }
    final err = tester.takeException();
    if (err != null && !'$err'.contains('MissingPluginException')) {
      fail('${app.language} ${theme.id} $name $size: $err');
    }
    if (!shots) return;
    await tester.runAsync(() async {
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 50));
      }
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 1.0);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('build/ui_shots/${tag}_${app.language}_${theme.id}_${name}_${sizes.entries.firstWhere((e) => e.value == size).key}.png')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    final err2 = tester.takeException();
    if (err2 != null && !'$err2'.contains('MissingPluginException')) {
      fail('${app.language} ${theme.id} $name $size (after settle): $err2');
    }
  }

  // Dark default theme + one light theme; English for a subset to catch longer labels.
  final themes = [themeById('majsoul'), themeById('sakura')];
  for (final name in screens.keys) {
    testWidgets('ui screen renders: $name', (tester) async {
      for (final lang in const ['zh', 'en']) {
        app.setLanguage(lang);
        for (final theme in themes) {
          if (lang == 'en' && theme != themes.first) continue;
          for (final size in sizes.values) {
            await pumpScreen(tester, name, size, theme);
          }
        }
      }
      app.setLanguage('zh');
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('game picker builds lazily and searches by name / id', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    String? picked;
    await tester.pumpWidget(AppScope(
      app: app,
      child: MaterialApp(
        theme: auroraThemes.first.toThemeData(),
        home: Scaffold(body: GamePickerGrid(games: app.games, onPick: (id) => picked = id)),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    final built = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('game:'));
    expect(built.evaluate().length, lessThan(app.games.length ~/ 2), reason: 'tiles must be built lazily');
    await tester.enterText(find.byType(TextField).first, 'gomoku');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('game:gomoku')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('game:gomoku')));
    await tester.pump();
    expect(picked, 'gomoku');
    await tester.enterText(find.byType(TextField).first, '五子棋');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('game:gomoku')), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.pumpWidget(const SizedBox());
  });
}

Future<void> _loadFonts() async {
  // Real CJK font so screenshots show text instead of boxes.
  for (final path in [r'C:\Windows\Fonts\msyh.ttc', r'C:\Windows\Fonts\simhei.ttf']) {
    final f = File(path);
    if (!f.existsSync()) continue;
    for (final fam in ['Microsoft YaHei', 'Roboto', 'FlutterTest', AuroraTheme.defaultFont]) {
      final l = FontLoader(fam)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      await l.load();
    }
    break;
  }
  for (final (fam, path) in [('Segoe UI Symbol', r'C:\Windows\Fonts\seguisym.ttf'), ('Segoe UI Emoji', r'C:\Windows\Fonts\seguiemj.ttf')]) {
    final f = File(path);
    if (!f.existsSync()) continue;
    final l = FontLoader(fam)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    await l.load();
  }
  final icons = File(r'D:\Tools\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf');
  if (icons.existsSync()) {
    final l = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await l.load();
  }
}
