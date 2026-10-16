import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/bank/task_bank.dart';
import 'package:math_trainer/bank_trainer.dart';
import 'package:math_trainer/main.dart';

// These scenarios specifically exercise the constructor, not format admission.
Future<String> inputOnlyText(String path) async {
  final text = File(path).readAsStringSync();
  if (path != 'bank/manifest.json') return text;
  final manifest = jsonDecode(text) as Map<String, dynamic>;
  manifest['practice']['input_percent'] = 0;
  return jsonEncode(manifest);
}

void main() {
  for (final size in [const Size(1024, 620), const Size(615, 524)]) {
    testWidgets(
      'real constructor editing, locking and read-only history: $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MathTrainerApp(home: BankTrainer(readText: inputOnlyText)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('topic-0')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Начать практику'));
        await tester.pumpAndSettle();
        Future<void> tapVisible(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        final previous = find.widgetWithText(
          OutlinedButton,
          'Предыдущее задание',
        );
        expect(previous, findsNothing);
        final numbers = tester.getRect(
          find.byKey(const ValueKey('bank-key-group-Числа')),
        );
        final letters = tester.getRect(
          find.byKey(const ValueKey('bank-key-group-Буквы')),
        );
        final signs = tester.getRect(
          find.byKey(const ValueKey('bank-key-group-Знаки и скобки')),
        );
        final previousBounds = tester.getRect(
          find.byKey(const ValueKey('bank-previous-slot')),
        );
        final primaryBounds = tester.getRect(
          find.byKey(const ValueKey('bank-primary')),
        );
        expect(previousBounds.left, closeTo(numbers.left, .01));
        expect(previousBounds.right, closeTo(numbers.right, .01));
        expect(primaryBounds.left, closeTo(letters.left, .01));
        expect(primaryBounds.right, closeTo(signs.right, .01));
        for (final symbol in ['7', '(', 'a', '+', 'b', ')']) {
          await tapVisible(find.byKey(ValueKey('bank-symbol-$symbol')));
        }
        final field = find.byKey(const ValueKey('bank-answer'));
        final controller = tester.widget<TextField>(field).controller!;
        expect(controller.text, '7(a+b)');
        controller.selection = const TextSelection(
          baseOffset: 0,
          extentOffset: 1,
        );
        await tapVisible(find.byKey(const ValueKey('bank-symbol-3')));
        expect(controller.text, '3(a+b)');
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Проверить себя'),
              )
              .onPressed,
          isNotNull,
        );
        controller.selection = const TextSelection(
          baseOffset: 0,
          extentOffset: 1,
        );
        await tapVisible(find.byKey(const ValueKey('bank-delete')));
        expect(controller.text, '(a+b)');
        await tapVisible(find.byKey(const ValueKey('bank-symbol-7')));
        expect(controller.text, '7(a+b)');
        await tapVisible(find.text('Проверить себя'));
        expect(tester.widget<TextField>(field).readOnly, isTrue);
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const ValueKey('bank-symbol-7')),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.text('Дальше'));
        await tester.pumpAndSettle();
        await tester.enterText(field, '5(a');
        await tester.pump();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Проверить себя'),
              )
              .onPressed,
          isNull,
        );
        controller.selection = const TextSelection.collapsed(offset: 2);
        final draft = controller.value;
        await tester.tap(find.text('Предыдущее задание'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('7a + 7b'), findsOneWidget);
        expect(find.text('Твой ответ: 7(a+b)'), findsOneWidget);
        await tester.tap(find.text('Вернуться к текущему'));
        await tester.pumpAndSettle();
        expect(controller.value, draft);
        expect(find.byKey(const ValueKey('bank-task-2')), findsOneWidget);
        expect(find.text('10%'), findsOneWidget);
        await tapVisible(find.text('К темам'));
        expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsNothing);
        await tester.tap(find.byKey(const ValueKey('topic-0')));
        await tester.pumpAndSettle();
        expect(controller.value, draft);
        expect(find.byKey(const ValueKey('bank-task-2')), findsOneWidget);
        await tapVisible(find.byKey(const ValueKey('bank-clear')));
        expect(controller.text, isEmpty);
        expect(find.byKey(const ValueKey('bank-task-2')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final size in [const Size(1366, 768), const Size(1920, 1080)]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        'real bank: 22 blocks, error, extra tasks and actual results $size $theme',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final bank = await TaskBank.load(
            'bank/manifest.json',
            (p) async => File(p).readAsStringSync(),
          );
          await tester.pumpWidget(
            MathTrainerApp(
              themeMode: theme,
              home: BankTrainer(readText: inputOnlyText),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Темы'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('topic-0')));
          await tester.pumpAndSettle();
          expect(find.text('22 блоков · 110 заданий в банке'), findsOneWidget);
          await tester.tap(find.text('Начать практику'));
          await tester.pumpAndSettle();
          expect(find.text('7a + 7b'), findsOneWidget);
          await tester.enterText(
            find.byKey(const ValueKey('bank-answer')),
            '7(b+a)',
          );
          await tester.pump();
          await tester.tap(find.text('Проверить себя'));
          await tester.pumpAndSettle();
          expect(
            find.textContaining('не засчитана как ошибка'),
            findsOneWidget,
          );
          expect(find.byKey(const ValueKey('bank-task-1')), findsOneWidget);
          await tester.enterText(
            find.byKey(const ValueKey('bank-answer')),
            '0',
          );
          await tester.pump();
          await tester.tap(find.text('Проверить себя'));
          await tester.pumpAndSettle();
          expect(find.text('Пока не получилось!'), findsOneWidget);
          expect(
            find.text('Дополнительных заданий осталось: 2'),
            findsOneWidget,
          );
          await tester.tap(find.text('Узнать, как правильно'));
          await tester.pumpAndSettle();
          expect(find.text('7(a + b)'), findsOneWidget);
          await tester.tap(find.text('Дальше'));
          await tester.pumpAndSettle();
          for (final task in [
            bank.blocks.first.tasks[1],
            bank.blocks.first.tasks[2],
            ...bank.blocks.skip(1).map((b) => b.tasks.first),
          ]) {
            expect(find.text(task.expression), findsOneWidget);
            final viewport = Offset.zero & size;
            for (final key in [
              'bank-answer',
              'bank-key-group-Числа',
              'bank-key-group-Буквы',
              'bank-key-group-Знаки и скобки',
              'bank-primary',
            ]) {
              final rect = tester.getRect(find.byKey(ValueKey(key)));
              expect(
                viewport.contains(rect.topLeft),
                isTrue,
                reason: '${task.id}: $key',
              );
              expect(
                viewport.contains(rect.bottomRight),
                isTrue,
                reason: '${task.id}: $key',
              );
            }
            await tester.enterText(
              find.byKey(const ValueKey('bank-answer')),
              task.expectedAnswer,
            );
            await tester.pump();
            await tester.tap(find.text('Проверить себя'));
            await tester.pumpAndSettle();
            expect(find.text('Абсолютно верно!'), findsOneWidget);
            final feedback = tester.getRect(
              find.byKey(const ValueKey('bank-feedback')),
            );
            expect(
              viewport.contains(feedback.topLeft),
              isTrue,
              reason: task.id,
            );
            expect(
              viewport.contains(feedback.bottomRight),
              isTrue,
              reason: task.id,
            );
            await tester.tap(find.text('Дальше'));
            await tester.pumpAndSettle();
          }
          await tester.tap(find.text('Завершить занятие'));
          await tester.pumpAndSettle();
          expect(find.text('Проходной порог достигнут'), findsOneWidget);
          expect(
            find.text('Решено: 24. Пройдено блоков: 22 из 22.'),
            findsOneWidget,
          );
          expect(find.text('100%'), findsOneWidget);
          expect(find.text('Ошибок: 1'), findsOneWidget);
          await tester.tap(find.text('Чему мы научились'));
          await tester.pumpAndSettle();
          expect(find.text('Что мы практиковали'), findsOneWidget);
          expect(find.text(bank.blocks.first.skill), findsOneWidget);
          await tester.tap(find.text('К итогам'));
          await tester.pumpAndSettle();
          expect(
            find.text('Решено: 24. Пройдено блоков: 22 из 22.'),
            findsOneWidget,
          );
          await tester.tap(find.text('Разобрать ошибки'));
          await tester.pumpAndSettle();
          expect(find.text('Ошибка 1 из 1'), findsOneWidget);
          expect(find.text('Твой ответ: 0'), findsOneWidget);
          expect(find.text('7(a + b)'), findsOneWidget);
          expect(
            tester
                .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, 'Назад'),
                )
                .onPressed,
            isNull,
          );
          expect(find.text('Следующая ошибка'), findsNothing);
          expect(find.text('К первой ошибке'), findsNothing);
          await tester.tap(find.text('К итогам'));
          await tester.pumpAndSettle();
          expect(find.text('Ошибок: 1'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'review cycles multiple real errors without changing scores in compact window',
    (tester) async {
      tester.view.physicalSize = const Size(615, 524);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<String> read(String path) async {
        final text = await inputOnlyText(path);
        if (path != 'bank/manifest.json') return text;
        final manifest = jsonDecode(text) as Map<String, dynamic>;
        manifest['blocks'] = (manifest['blocks'] as List).take(2).toList();
        manifest['practice']['minimum_answers'] = 2;
        manifest['practice']['success_window'] = 2;
        return jsonEncode(manifest);
      }

      final bank = await TaskBank.load('bank/manifest.json', read);
      await tester.pumpWidget(
        MathTrainerApp(home: BankTrainer(readText: read)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('topic-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Начать практику'));
      await tester.pumpAndSettle();
      for (final answer in [
        '0',
        bank.blocks[0].tasks[1].expectedAnswer,
        bank.blocks[0].tasks[2].expectedAnswer,
        '0',
        bank.blocks[1].tasks[1].expectedAnswer,
        bank.blocks[1].tasks[2].expectedAnswer,
      ]) {
        await tester.enterText(
          find.byKey(const ValueKey('bank-answer')),
          answer,
        );
        await tester.pump();
        await tester.tap(find.text('Проверить себя'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Дальше'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Завершить занятие'));
      await tester.pumpAndSettle();
      expect(find.text('Решено: 6. Пройдено блоков: 2 из 2.'), findsOneWidget);
      await tester.tap(find.text('Разобрать ошибки'));
      await tester.pumpAndSettle();
      expect(find.text('Ошибка 1 из 2'), findsOneWidget);
      await tester.tap(find.text('Следующая ошибка'));
      await tester.pumpAndSettle();
      expect(find.text('Ошибка 2 из 2'), findsOneWidget);
      expect(find.text('Следующая ошибка'), findsNothing);
      await tester.tap(find.text('К первой ошибке'));
      await tester.pumpAndSettle();
      expect(find.text('Ошибка 1 из 2'), findsOneWidget);
      await tester.tap(find.text('К итогам'));
      await tester.pumpAndSettle();
      expect(find.text('Решено: 6. Пройдено блоков: 2 из 2.'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'topic config changes minimum/window; no-errors result can be revisited',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<String> read(String path) async {
        final text = await inputOnlyText(path);
        if (path != 'bank/manifest.json') return text;
        final manifest = jsonDecode(text) as Map<String, dynamic>;
        manifest['blocks'] = (manifest['blocks'] as List).take(1).toList();
        manifest['practice']['minimum_answers'] = 1;
        manifest['practice']['success_window'] = 1;
        return jsonEncode(manifest);
      }

      await tester.pumpWidget(
        MathTrainerApp(home: BankTrainer(readText: read)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('topic-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Начать практику'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('bank-answer')),
        '7(a+b)',
      );
      await tester.pump();
      await tester.tap(find.text('Проверить себя'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Завершить занятие'));
      await tester.pumpAndSettle();
      expect(find.text('Решено: 1. Пройдено блоков: 1 из 1.'), findsOneWidget);
      expect(find.text('Ошибок: 0'), findsOneWidget);
      expect(find.text('Разобрать ошибки'), findsNothing);
      await tester.tap(find.text('Назад к решению'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Твой ответ: 7(a+b)'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('bank-answer')))
            .readOnly,
        isTrue,
      );
      await tester.tap(find.widgetWithText(TextButton, 'К итогам'));
      await tester.pumpAndSettle();
      expect(find.text('Решено: 1. Пройдено блоков: 1 из 1.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
