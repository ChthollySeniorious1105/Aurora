import 'package:aurora_client/i18n/aurora_i18n.dart';
import 'package:aurora_client/main.dart';
import 'package:aurora_client/screens/settings_screen.dart';
import 'package:aurora_client/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Language switching and settings screen rendering.
void main() {
  Future<AppState> makeApp(String lang) async {
    SharedPreferences.setMockInitialValues({'name': 'tester', 'avatar': 3});
    final app = AppState();
    app.prefs = await SharedPreferences.getInstance();
    app.name = 'tester';
    app.setLanguage(lang);
    return app;
  }

  for (final lang in AuroraLanguage.values) {
    testWidgets('app builds in ${lang.label}', (tester) async {
      final app = await makeApp(lang.code);
      await tester.pumpWidget(AuroraApp(app));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.byType(FilledButton), findsWidgets);
    });
  }

  testWidgets('switching to Chinese keeps Material widgets working', (tester) async {
    final app = await makeApp('en');
    await tester.pumpWidget(AuroraApp(app));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Enter lobby'), findsWidgets);
    app.setLanguage('zh');
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text('进入大厅'), findsWidgets);
  });

  testWidgets('settings screen switches theme and language', (tester) async {
    final app = await makeApp('zh');
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(AppScope(
      app: app,
      child: AuroraI18n(
        language: app.auroraLanguage,
        child: MaterialApp(
          locale: app.auroraLanguage.locale,
          supportedLocales: AuroraLanguage.locales,
          localizationsDelegates: AuroraLanguage.delegates,
          home: const SettingsScreen(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('English'), 200);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(app.language, 'en');
  });
}
