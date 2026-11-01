import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/demo_screens.dart';
import 'package:math_trainer/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Carlito')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/Carlito-Regular.ttf').readAsBytesSync(),
          ),
        ),
      );
    await font.load();
  });
  for (final size in [
    const Size(320, 700),
    const Size(390, 844),
    const Size(1366, 768),
    const Size(1920, 1080),
  ]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        'state, progress and PDF aligned and independently clickable $size $theme',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          int? practice;
          int? pdf;
          await tester.pumpWidget(
            MathTrainerApp(
              themeMode: theme,
              home: TopicsScreen(
                titles: const [
                  'Вынесение численного общего множителя за скобки',
                  'Вынесение буквенного общего множителя за скобки',
                  'Тема с достигнутой успешностью',
                ],
                successes: const [null, 64, 90],
                onTopicSelected: (i) => practice = i,
                onGeneratePdf: (i) => pdf = i,
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (var i = 0; i < 3; i++) {
            final controls = find.byKey(ValueKey('topic-controls-$i'));
            await tester.ensureVisible(controls);
            await tester.pumpAndSettle();
            final row = tester.getRect(controls);
            final state = tester.getRect(
              find.byKey(ValueKey('topic-state-$i')),
            );
            final progress = tester.getRect(
              find.byKey(ValueKey('topic-progress-$i')),
            );
            final pdfButton = find.byKey(ValueKey('pdf-topic-$i'));
            final pdfRect = tester.getRect(pdfButton);
            expect(state.bottom, closeTo(pdfRect.bottom, .01));
            expect(state.right, lessThan(progress.left));
            expect(progress.right, lessThan(pdfRect.left));
            expect(state.left, closeTo(row.left, .01));
            expect(pdfRect.right, closeTo(row.right, .01));
            final title = tester.getRect(
              find.byKey(ValueKey('topic-title-$i')),
            );
            expect(title.left, closeTo(state.left, .01));
            expect(title.bottom, lessThanOrEqualTo(row.top));
            final percent = find.byKey(ValueKey('topic-percent-$i'));
            final bar = find.descendant(
              of: find.byKey(ValueKey('topic-progress-$i')),
              matching: find.byType(LinearProgressIndicator),
            );
            expect(
              tester.getRect(percent).bottom,
              closeTo(tester.getRect(bar).bottom, .01),
            );
            expect(state.bottom, closeTo(tester.getRect(bar).bottom, .01));
            expect(
              pdfRect.bottom,
              closeTo(tester.getRect(percent).bottom, .01),
            );
            expect(
              tester.widget<LinearProgressIndicator>(bar).value,
              [0, .64, .90][i],
            );
            await tester.tap(pdfButton);
            await tester.pumpAndSettle();
            expect(pdf, i);
            expect(practice, isNull);
            expect(tester.takeException(), isNull);
          }
          await tester.tap(find.byKey(const ValueKey('topic-progress-2')));
          await tester.pumpAndSettle();
          expect(practice, 2);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
