import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/main.dart';
import 'package:math_trainer/completion_screens.dart';

void main() {
  for (final size in [
    const Size(615, 524),
    const Size(1366, 768),
    const Size(1920, 1080),
  ]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        'Learned material can be reopened without losing results $size $mode',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final errors = mode == ThemeMode.light ? <int>[] : <int>[2];
          await tester.pumpWidget(
            MathTrainerApp(
              themeMode: mode,
              home: ResultsScreen(successPercent: 87, errors: errors),
            ),
          );
          await tester.pumpAndSettle();
          for (var visit = 0; visit < 2; visit++) {
            final action = find.widgetWithText(
              OutlinedButton,
              'Чему мы научились',
            );
            expect(
              tester.getRect(action).bottom,
              lessThanOrEqualTo(size.height),
            );
            await tester.tap(action);
            await tester.pumpAndSettle();
            expect(find.text('Чему мы научились'), findsOneWidget);
            expect(find.text('Находить общий множитель'), findsOneWidget);
            expect(find.widgetWithText(FilledButton, 'Дальше'), findsNothing);
            await tester.tap(find.widgetWithText(FilledButton, 'К итогам'));
            await tester.pumpAndSettle();
            expect(find.text('Итоги практики'), findsOneWidget);
            expect(find.text('87%'), findsOneWidget);
            expect(
              find.widgetWithText(FilledButton, 'Разобрать ошибки'),
              errors.isEmpty ? findsNothing : findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          }
        },
        variant: TargetPlatformVariant({TargetPlatform.windows}),
      );
    }
  }
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final screen in ['constructor', 'recap', 'results', 'review']) {
      testWidgets('$screen actions stay visible in narrow browser $mode', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(615, 524);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MathTrainerApp(themeMode: mode, home: demoScreen(screen)),
        );
        await tester.pumpAndSettle();
        final label = switch (screen) {
          'constructor' => 'Проверить себя',
          'recap' => 'Дальше',
          'results' => 'Разобрать ошибки',
          _ => 'Следующая ошибка',
        };
        final action = find.widgetWithText(FilledButton, label);
        final initial = tester.getRect(action);
        expect(initial.top, greaterThanOrEqualTo(0));
        expect(initial.bottom, lessThanOrEqualTo(524));
        expect(initial.left, greaterThanOrEqualTo(0));
        expect(initial.right, lessThanOrEqualTo(615));
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(action), initial);
        expect(tester.takeException(), isNull);
      }, variant: TargetPlatformVariant({TargetPlatform.windows}));
    }
  }
  testWidgets('Results show exact percent and retain it after review', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MathTrainerApp(home: ResultsScreen(successPercent: 87)),
    );
    await tester.pumpAndSettle();
    expect(find.text('87%'), findsOneWidget);
    expect(find.text('85%+'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Разобрать ошибки'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'К итогам'));
    await tester.pumpAndSettle();
    expect(find.text('87%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.windows}));
}
