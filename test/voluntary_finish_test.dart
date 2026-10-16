import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/bank/task_bank.dart';
import 'package:math_trainer/bank_trainer.dart';
import 'package:math_trainer/main.dart';
import 'package:math_trainer/practice/answer_choices.dart';

void main() {
  for (final size in [const Size(1366, 768), const Size(1920, 1080)]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        '85% offers finish; continuing and early recap are safe $size $theme',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          Future<String> read(String p) async => File(p).readAsStringSync();
          final bank = await TaskBank.load('bank/manifest.json', read);
          await tester.pumpWidget(
            MathTrainerApp(
              themeMode: theme,
              home: BankTrainer(readText: read),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('topic-0')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Начать практику'));
          await tester.pumpAndSettle();
          for (var i = 0; i < 9; i++) {
            expect(find.text('Завершить занятие'), findsNothing);
            final task = bank.blocks[i].tasks.first;
            if (i < 7) {
              final choices = answerChoices(task);
              await tester.tap(
                find.byKey(
                  ValueKey(
                    'bank-choice-${choices.indexOf(task.expectedAnswer)}',
                  ),
                ),
              );
            } else {
              await tester.enterText(
                find.byKey(const ValueKey('bank-answer')),
                task.expectedAnswer,
              );
            }
            await tester.pump();
            await tester.tap(find.text('Проверить себя'));
            await tester.pumpAndSettle();
            expect(find.text('Абсолютно верно!'), findsOneWidget);
            if (i < 8) {
              expect(find.text('Завершить занятие'), findsNothing);
              await tester.tap(find.text('Дальше'));
              await tester.pumpAndSettle();
            }
          }
          expect(find.text('90%'), findsOneWidget);
          final finish = find.byKey(const ValueKey('bank-finish'));
          final bounds = tester.getRect(finish);
          expect((Offset.zero & size).contains(bounds.topLeft), isTrue);
          expect((Offset.zero & size).contains(bounds.bottomRight), isTrue);
          expect(find.text('Целевая успешность достигнута'), findsOneWidget);
          // Continue explicitly: eligibility must not automatically open results.
          await tester.tap(find.text('Дальше'));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('bank-task-10')), findsOneWidget);
          expect(
            tester
                .widget<TextField>(find.byKey(const ValueKey('bank-answer')))
                .readOnly,
            isFalse,
          );
          expect(finish, findsOneWidget);
          // Leaving and returning while eligible still resumes practice.
          await tester.tap(find.text('К темам'));
          await tester.pumpAndSettle();
          expect(find.byIcon(Icons.check_rounded), findsOneWidget);
          expect(find.byIcon(Icons.schedule_rounded), findsNothing);
          await tester.tap(find.byKey(const ValueKey('topic-0')));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('bank-task-10')), findsOneWidget);
          await tester.enterText(
            find.byKey(const ValueKey('bank-answer')),
            '2(a',
          );
          await tester.pump();
          await tester.tap(finish);
          await tester.pumpAndSettle();
          expect(
            find.text('Решено: 9. Пройдено блоков: 9 из 22.'),
            findsOneWidget,
          );
          await tester.tap(find.text('Чему мы научились'));
          await tester.pumpAndSettle();
          expect(find.text('Что мы практиковали'), findsOneWidget);
          expect(find.text(bank.blocks.last.skill), findsNothing);
          await tester.tap(find.text('К итогам'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Назад к решению'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.byKey(const ValueKey('bank-task-1')), findsOneWidget);
          expect(find.text('Предыдущее задание'), findsNothing);
          expect(
            tester
                .widget<InkWell>(find.byKey(const ValueKey('bank-choice-0')))
                .onTap,
            isNull,
          );
          expect(find.textContaining('Твой ответ:'), findsNothing);
          final footer = find.byKey(const ValueKey('demo-footer'));
          final backToResults = find.byKey(
            const ValueKey('bank-history-results'),
          );
          expect(
            find.descendant(of: footer, matching: backToResults),
            findsOneWidget,
          );
          final resultBounds = tester.getRect(backToResults);
          final continueBounds = tester.getRect(
            find.byKey(const ValueKey('bank-return-current')),
          );
          expect(resultBounds.right, closeTo(size.width - 56, .01));
          expect(resultBounds.bottom, lessThanOrEqualTo(size.height));
          expect(
            continueBounds.bottom,
            lessThanOrEqualTo(tester.getRect(footer).top),
          );
          expect(continueBounds.right, closeTo(resultBounds.right, .01));

          await tester.tap(find.byKey(const ValueKey('bank-history-results')));
          await tester.pumpAndSettle();
          expect(
            find.text('Решено: 9. Пройдено блоков: 9 из 22.'),
            findsOneWidget,
          );
          await tester.tap(find.text('Назад к решению'));
          await tester.pumpAndSettle();
          // Walk forward through the actual saved screens, preserving format.
          for (var i = 0; i < 8; i++) {
            await tester.tap(find.text('Дальше'));
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('bank-history-results')),
              findsOneWidget,
            );
          }
          expect(find.byKey(const ValueKey('bank-task-9')), findsOneWidget);
          expect(
            tester
                .widget<TextField>(find.byKey(const ValueKey('bank-answer')))
                .readOnly,
            isTrue,
          );
          expect(find.text('Проверить себя'), findsNothing);
          await tester.ensureVisible(find.text('Продолжить решение'));
          await tester.tap(find.text('Продолжить решение'));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('bank-task-10')), findsOneWidget);
          final field = tester.widget<TextField>(
            find.byKey(const ValueKey('bank-answer')),
          );
          expect(field.readOnly, isFalse);
          expect(field.controller!.text, '2(a');
          expect(find.text('90%'), findsOneWidget);
          await tester.enterText(
            find.byKey(const ValueKey('bank-answer')),
            bank.blocks[9].tasks.first.expectedAnswer,
          );
          await tester.pump();
          await tester.tap(find.text('Проверить себя'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Завершить занятие'));
          await tester.pumpAndSettle();
          expect(
            find.text('Решено: 10. Пройдено блоков: 10 из 22.'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
