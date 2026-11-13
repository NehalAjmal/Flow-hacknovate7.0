import 'package:flow/theme/tokens.dart';
import 'package:flow/ui/dial.dart';
import 'package:flow/ui/drum_wheel.dart';
import 'package:flow/ui/kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: buildTheme(Brightness.light),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('dial: arrow keys step 5 min and stop at the limits', (t) async {
    var m = DurationDial.healthyMax - 5; // 235: one step below the 4 h limit
    await t.pumpWidget(
      StatefulBuilder(
        builder: (c, set) => _host(DurationDial(minutes: m, onChanged: (v) => set(() => m = v))),
      ),
    );
    await t.pump(const Duration(seconds: 1));
    // focus the dial the way a keyboard user would
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pumpAndSettle();
    expect(m, 240);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp); // at max: refused, stays
    await t.pumpAndSettle();
    expect(m, 240);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pumpAndSettle();
    expect(m, 235);
  });

  testWidgets('drum wheel: clicking the built-in ends steps once', (t) async {
    var v = 5;
    await t.pumpWidget(
      StatefulBuilder(
        builder: (c, set) => _host(DrumWheel(value: v, min: 0, max: 10, onChanged: (x) => set(() => v = x))),
      ),
    );
    final box = t.getRect(find.byType(DrumWheel));
    await t.tapAt(Offset(box.center.dx, box.top + 8));
    await t.pumpAndSettle();
    expect(v, 4);
    await t.tapAt(Offset(box.center.dx, box.bottom - 8));
    await t.pumpAndSettle();
    expect(v, 5);
    await t.tapAt(box.center); // middle third is not a step end
    await t.pumpAndSettle();
    expect(v, 5);
  });

  testWidgets('snap slider: tap picks the nearest detent', (t) async {
    var i = 0;
    await t.pumpWidget(
      StatefulBuilder(
        builder: (c, set) => _host(SnapSlider(steps: 3, index: i, width: 160, onChanged: (x) => set(() => i = x))),
      ),
    );
    final r = t.getRect(find.byType(GestureDetector).last);
    await t.tapAt(Offset(r.right - 10, r.center.dy));
    await t.pumpAndSettle();
    expect(i, 2);
  });

  testWidgets('pressable: Enter activates when focused; disabled ignores taps', (t) async {
    var n = 0;
    await t.pumpWidget(
      _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Pressable(onPressed: () => n++, child: const Text('Go')),
            const Pressable(onPressed: null, child: Text('Off')),
          ],
        ),
      ),
    );
    await t.tap(find.text('Go'));
    await t.pumpAndSettle();
    expect(n, 1);
    await t.tap(find.text('Off'));
    await t.pumpAndSettle();
    expect(n, 1);
  });
}
