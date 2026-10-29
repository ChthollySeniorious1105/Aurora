import 'dart:math';

import 'package:aurora_client/games/arcade12/boards.dart';
import 'package:aurora_client/state/app_state.dart';
import 'package:aurora_client/theme/themes.dart';
import 'package:aurora_client/widgets/common.dart';
import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/arcade12/defs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders every arcade12 game board with real engine views (start, mid-game,
/// interim settlement, end) at phone portrait, phone landscape and desktop
/// sizes. Fails on any exception or layout overflow.
void main() {
  late AppState app;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'name': 'tester', 'avatar': 3});
    app = AppState();
    app.prefs = await SharedPreferences.getInstance();
  });

  const sizes = [Size(390, 800), Size(800, 390), Size(1280, 720)];

  for (final def in arcade12Games) {
    for (final useMaxPlayers in [false, true]) {
      testWidgets('board renders: ${def.id} (${useMaxPlayers ? "maxPlayers" : "minPlayers"})', (tester) async {
        final builder = arcade12Boards[def.id];
        expect(builder, isNotNull, reason: 'missing board builder for ${def.id}');

        final opts = def.defaultOptions();
        if (useMaxPlayers && def.id == 'hidato') opts['size'] = 5;
        if (useMaxPlayers && def.id == 'kuromasu') opts['size'] = 6;
        if (useMaxPlayers && def.id == 'galaxies') opts['size'] = 6;
        final range = def.playerRange(opts);
        final players = useMaxPlayers ? range.$2 : range.$1;
        final setup = GameSetup(
          players: players,
          options: opts,
          names: [for (var i = 0; i < players; i++) '玩家${i + 1}'],
          bots: List.filled(players, true),
          hostSeat: 0,
          rng: Random(7),
        );
        final e = def.create(setup);
        final host = _QueueHost();
        e.host = host;
        e.start();
        host.run();

        final snaps = <List<Map<String, dynamic>>>[];
        void snap() => snaps.add([for (var s = 0; s < players; s++) e.view(s), e.view(-1)]);
        snap();
        var steps = 0;
        var resultSnaps = 0;
        final seenPhases = <String>{};
        final checkpoints = {3, 25, 120};
        while (!e.isOver && steps < 20000) {
          final w = e.waitingFor;
          if (w.isEmpty) {
            if (!host.run()) break;
            continue;
          }
          var acted = false;
          for (final s in w) {
            final a = e.runBot(s);
            if (a == null) continue;
            e.handle(s, a);
            acted = true;
            break;
          }
          host.run();
          if (!acted) break;
          steps++;
          if (checkpoints.contains(steps)) snap();
          if (resultSnaps < 12) {
            final v0 = e.view(0);
            final k = v0.keys.firstWhere((k) => _resultKeys.contains(k) && v0[k] != null, orElse: () => '');
            final phase = '${v0['phase'] ?? v0['stage'] ?? ''}';
            final newPhase = phase.isNotEmpty && !seenPhases.contains(phase);
            if (newPhase) seenPhases.add(phase);
            if ((k.isNotEmpty && resultSnaps < 3) || newPhase) {
              snap();
              resultSnaps++;
            }
          }
        }
        snap();

        for (final size in sizes) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          for (final views in snaps) {
            for (var s = -1; s < players; s++) {
              final v = views[s < 0 ? players : s];
              final gs =
                  GameState(def.id, s, setup.names, setup.bots, List.generate(players, (i) => i + 1), v, e.isOver);
              await tester.pumpWidget(MaterialApp(
                theme: auroraThemes.first.toThemeData(),
                home: Scaffold(body: SizedBox.expand(child: builder!(GameContext(app, gs)))),
              ));
              await tester.pump(const Duration(milliseconds: 50));
              final err = tester.takeException();
              if (err != null) {
                fail('${def.id} seat=$s size=$size step-snapshot=${snaps.indexOf(views)}: $err');
              }
            }
          }
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      });
    }
  }
}

const _resultKeys = {'result', 'handResult', 'settlement', 'roundResult', 'roundEnd', 'lastResult', 'summary', 'final'};

class _QueueHost implements GameHost {
  final List<void Function()> q = [];
  @override
  void log(String text) {}
  @override
  void Function() schedule(int ms, void Function() fn) {
    var c = false;
    q.add(() {
      if (!c) fn();
    });
    return () => c = true;
  }

  bool run() {
    if (q.isEmpty) return false;
    final l = List.of(q);
    q.clear();
    for (final f in l) {
      f();
    }
    return true;
  }
}
