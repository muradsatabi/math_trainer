import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/main.dart';
import 'package:math_trainer/constructor_screen.dart';
import 'package:math_trainer/completion_screens.dart';

void main() {
  testWidgets('Success explanation opens and closes without evaluation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MathTrainerApp(home: PracticeScreen()));
    await tester.tap(find.text('Успешность'));
    await tester.pumpAndSettle();
    expect(find.text('Что означает успешность?'), findsOneWidget);
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    expect(find.text('Что означает успешность?'), findsNothing);
    expect(find.text('0%'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('check-answer')))
          .onPressed,
      isNull,
    );
  });
  testWidgets('Results without errors and review of a single demo error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MathTrainerApp(home: ResultsScreen(errors: [])),
    );
    await tester.pumpAndSettle();
    expect(find.text('В этой практике ошибок не было'), findsOneWidget);
    expect(find.text('Разобрать ошибки'), findsNothing);
    await tester.pumpWidget(
      const MathTrainerApp(home: ErrorReviewScreen(errors: [0])),
    );
    await tester.pumpAndSettle();
    expect(find.text('Задание 1 из 1'), findsOneWidget);
    expect(find.text('Следующая ошибка'), findsNothing);
    expect(find.text('К первой ошибке'), findsNothing);
    expect(find.text('Задание 1 из 1'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Назад'))
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('К итогам'));
    await tester.tap(find.text('К итогам'));
    await tester.pumpAndSettle();
    expect(find.text('Итоги практики'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(1920, 1080), const Size(1366, 768)]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final screen in [
        'constructor',
        'detailed',
        'recap',
        'results',
        'review',
      ]) {
        testWidgets('$screen $size $mode renders without overflow', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MathTrainerApp(themeMode: mode, home: demoScreen(screen)),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }, variant: TargetPlatformVariant({TargetPlatform.windows}));
      }
    }
  }
  for (var answer = 0; answer < 4; answer++) {
    testWidgets('Constructor edits and locks demo answer $answer', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MathTrainerApp(home: ConstructorScreen()));
      await tester.pumpAndSettle();
      final check = find.byKey(const ValueKey('constructor-check'));
      final input = find.byKey(const ValueKey('assembly'));
      final controller = tester.widget<TextField>(input).controller!;
      expect(controller.text, isEmpty);
      expect(tester.widget<FilledButton>(check).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('delete-symbol')));
      await tester.tap(find.byKey(const ValueKey('symbol-3')));
      await tester.pumpAndSettle();
      controller.selection = const TextSelection.collapsed(offset: 0);
      await tester.tap(find.byKey(const ValueKey('symbol-2')));
      await tester.pumpAndSettle();
      expect(controller.text, '23');
      await tester.tap(find.byKey(const ValueKey('delete-symbol')));
      await tester.pumpAndSettle();
      expect(controller.text, '3');
      await tester.tap(find.byKey(const ValueKey('clear-entry')));
      await tester.pumpAndSettle();
      for (final symbol in constructorRecords[answer].split('')) {
        await tester.tap(find.byKey(ValueKey('symbol-$symbol')));
        await tester.pumpAndSettle();
      }
      expect(tester.widget<FilledButton>(check).onPressed, isNotNull);
      final inputRect = tester.getRect(input);
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(tester.getRect(input), inputRect);
      expect(
        find.text(answer == 1 ? 'Абсолютно\nверно!' : 'Пока не получилось!'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('symbol-3')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('clear-entry')))
            .onPressed,
        isNull,
      );
      expect(controller.text, constructorRecords[answer]);
      if (answer != 1) {
        await tester.tap(find.text('Узнать, как правильно'));
        await tester.pumpAndSettle();
        expect(find.text('Давай разберёмся'), findsOneWidget);
      }
      await tester.tap(find.text('Дальше'));
      await tester.pumpAndSettle();
      expect(find.text('Чему мы научились'), findsOneWidget);
      await tester.ensureVisible(find.text('Назад к решению'));
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Назад к решению'),
            )
            .onPressed,
        isNull,
      );
      expect(controller.text, constructorRecords[answer]);
      await tester.ensureVisible(find.text('Дальше'));
      await tester.tap(find.text('Дальше'));
      await tester.pumpAndSettle();
      expect(find.text('Итоги практики'), findsOneWidget);
      await tester.ensureVisible(find.text('Разобрать ошибки'));
      await tester.tap(find.text('Разобрать ошибки'));
      await tester.pumpAndSettle();
      expect(find.text('Задание 1 из 4'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Назад'),
            )
            .onPressed,
        isNull,
      );
      for (var i = 2; i <= 4; i++) {
        await tester.ensureVisible(find.text('Следующая ошибка'));
        await tester.tap(find.text('Следующая ошибка'));
        await tester.pumpAndSettle();
        expect(find.text('Задание $i из 4'), findsOneWidget);
      }
      await tester.tap(find.text('Назад'));
      await tester.pumpAndSettle();
      expect(find.text('Задание 3 из 4'), findsOneWidget);
      await tester.tap(find.text('Следующая ошибка'));
      await tester.pumpAndSettle();
      expect(find.text('К итогам'), findsOneWidget);
      expect(find.text('Следующая ошибка'), findsNothing);
      expect(
        find.widgetWithText(OutlinedButton, 'К первой ошибке'),
        findsOneWidget,
      );
      await tester.tap(find.text('К первой ошибке'));
      await tester.pumpAndSettle();
      expect(find.text('Задание 1 из 4'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Назад'),
            )
            .onPressed,
        isNull,
      );
      final back = tester.getRect(find.text('Назад'));
      final results = tester.getRect(find.text('К итогам'));
      final next = tester.getRect(find.text('Следующая ошибка'));
      expect(results.right, lessThan(back.left));
      expect(back.right, lessThan(next.left));
      await tester.tap(find.text('К итогам'));
      await tester.pumpAndSettle();
      expect(find.text('Итоги практики'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({TargetPlatform.windows}));
  }
}
