import 'dart:math';

import 'package:aurora_client/games/abstract9/boards.dart';
import 'package:aurora_client/state/app_state.dart';
import 'package:aurora_client/theme/themes.dart';
import 'package:aurora_client/widgets/common.dart';
import 'package:aurora_shared/games/abstract9/defs.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppState app;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'name': 'tester', 'avatar': 3});
    app = AppState();
    app.prefs = await SharedPreferences.getInstance();
  });

  const sizes = [Size(390, 800), Size(800, 390), Size(1280, 720)];

  for (final def in abstract9Games) {
    testWidgets('board renders: ${def.id}', (tester) async {
      final builder = abstract9Boards[def.id];
      expect(builder, isNotNull, reason: 'Missing board builder for ${def.id}');

      final combos = <Map<String, dynamic>>[def.defaultOptions()];
      for (final o in def.options) {
        for (final c in o.choices) {
          if (c.value != o.defaultValue) {
            combos.add({...def.defaultOptions(), o.key: c.value});
          }
        }
      }

      for (final opts in combos) {
        final players = def.playerRange(opts).$1;
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
        final checkpoints = {1, 5, 20, 60};
        while (!e.isOver && steps < 5000) {
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
        }
        snap();

        for (final size in sizes) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          for (var snapIdx = 0; snapIdx < snaps.length; snapIdx++) {
            final views = snaps[snapIdx];
            final isEndSnap = snapIdx == snaps.length - 1 && e.isOver;
            for (var s = -1; s < players; s++) {
              final v = views[s < 0 ? players : s];
              final gs = GameState(
                def.id,
                s,
                setup.names,
                setup.bots,
                List.generate(players, (i) => i + 1),
                v,
                isEndSnap,
              );
              await tester.pumpWidget(MaterialApp(
                theme: auroraThemes.first.toThemeData(),
                home: Scaffold(body: SizedBox.expand(child: builder!(GameContext(app, gs)))),
              ));
              await tester.pump(const Duration(milliseconds: 50));
              final err = tester.takeException();
              if (err != null) {
                fail('${def.id} opts=$opts seat=$s size=$size snap=$snapIdx: $err');
              }
            }
          }
        }
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  }
}

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
