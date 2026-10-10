import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/answer_form.dart';
import 'package:math_trainer/constructor_screen.dart';
import 'package:math_trainer/main.dart';
import 'package:math_trainer/demo_answer.dart';

void main() {
  test('Equivalent forms of the demo factorization are accepted', () {
    for (final record in [
      '3(2x+3)',
      '3 × (2x + 3)',
      '(2x+3)×3',
      '(2x+3)3',
      '3(2×x+3)',
      '(x×2+3)×3',
      '3(3+2x)',
      '3*(2*x+3)',
    ]) {
      expect(isCorrectDemoAnswer(record), isTrue, reason: record);
    }
    for (final record in [
      '3×(2x+4)',
      '(3x+2)×3',
      '3÷(2x+3)',
      '3×2x+3',
      '3(2x+3',
      '3××(2x+3)',
      '6x+9',
      '4(2x+3)',
    ]) {
      expect(isCorrectDemoAnswer(record), isFalse, reason: record);
    }
  });
  for (final record in ['3×(2x+3)', '(2x+3)×3', '(2x+3)3']) {
    testWidgets('Constructor accepts $record', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MathTrainerApp(home: ConstructorScreen()));
      for (final symbol in record.split('')) {
        await tester.tap(find.byKey(ValueKey('symbol-$symbol')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('constructor-check')));
      await tester.pumpAndSettle();
      expect(find.text('Абсолютно\nверно!'), findsOneWidget);
      expect(find.text('Пока не получилось!'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('assembly')))
            .controller!
            .text,
        record,
      );
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({TargetPlatform.windows}));
  }
  test('Completeness depends on syntax rather than the correct answer', () {
    for (final record in [
      '3(2x+3)',
      '3(2x+4)',
      '4(3x+6)',
      'x',
      '6x+9',
      '(x+3)(x−2)',
      '3((2x)+4)',
      '−3(x+2)',
      '3×x',
      '6÷3',
    ]) {
      expect(isCompleteAnswer(record), isTrue, reason: record);
    }
    for (final record in [
      '',
      ' ',
      '3(',
      '3(2x+',
      '3(2x+4',
      '3(2x+4))',
      ')x(',
      '()',
      '3()',
      '3(+)',
      '3×',
      '3÷',
      '3++4',
      '×3',
    ]) {
      expect(isCompleteAnswer(record), isFalse, reason: record);
    }
  });
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('An unfamiliar wrong answer can be checked: $mode', (
      tester,
    ) async {
      tester.view.physicalSize = mode == ThemeMode.light
          ? const Size(1366, 768)
          : const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MathTrainerApp(themeMode: mode, home: const ConstructorScreen()),
      );
      await tester.pumpAndSettle();
      final check = find.byKey(const ValueKey('constructor-check'));
      for (final symbol in '3(2x+4'.split('')) {
        await tester.tap(find.byKey(ValueKey('symbol-$symbol')));
        await tester.pumpAndSettle();
      }
      expect(tester.widget<FilledButton>(check).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('assembly')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Собери ответ:'));
      await tester.pumpAndSettle();
      expect(find.text('Ты не закончил запись. Допиши ответ'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('symbol-)')));
      await tester.pumpAndSettle();
      expect(find.text('Ты не закончил запись. Допиши ответ'), findsNothing);
      expect(tester.widget<FilledButton>(check).onPressed, isNotNull);
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(find.text('Пока не получилось!'), findsOneWidget);
      expect(find.text('Дальше'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('symbol-4')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('assembly')))
            .controller!
            .text,
        '3(2x+4)',
      );
      await tester.tap(find.text('Узнать, как правильно'));
      await tester.pumpAndSettle();
      expect(find.text('Давай разберёмся'), findsOneWidget);
      expect(find.text('В скобках число 9 не изменилось.'), findsNothing);
      expect(find.text('0%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({TargetPlatform.windows}));
  }
}
