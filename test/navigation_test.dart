import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/main.dart';

void main() {
  for (final size in [const Size(1920, 1080), const Size(1366, 768)]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('Topics → start → practice → topics: $size $mode', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MathTrainerApp(themeMode: mode));
        await tester.pumpAndSettle();
        expect(find.text('Темы'), findsOneWidget);
        expect(find.text('86%'), findsOneWidget);
        expect(find.text('65%'), findsOneWidget);
        expect(find.text('Не начато'), findsNWidgets(2));
        await tester.tap(find.byKey(const ValueKey('topic-1')));
        await tester.pumpAndSettle();
        expect(
          find.text('Демонстрация заданий доступна для первой темы.'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('topic-0')));
        await tester.pumpAndSettle();
        expect(find.text('Начнём практику'), findsOneWidget);
        expect(find.text('Если ошибёшься'), findsOneWidget);
        await tester.tap(find.text('Начать практику'));
        await tester.pumpAndSettle();
        expect(find.text('6x + 9'), findsOneWidget);
        expect(find.text('0%'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.byKey(const ValueKey('check-answer')))
              .onPressed,
          isNull,
        );
        await tester.tap(find.text('К темам'));
        await tester.pumpAndSettle();
        expect(find.text('Темы'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('topic-0')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('К темам'));
        await tester.pumpAndSettle();
        expect(find.text('Темы'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, variant: TargetPlatformVariant({TargetPlatform.windows}));
    }
  }
}
