import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/bank/task_bank.dart';
import 'package:math_trainer/bank_trainer.dart';
import 'package:math_trainer/main.dart';
import 'package:math_trainer/practice/answer_choices.dart';
import 'package:math_trainer/practice/practice_session.dart';

void main() {
  for (final size in [const Size(1366, 768), const Size(1920, 1080)]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('choice → input at 70% → choice below 70%: $size $theme', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Future<String> read(String p) async => File(p).readAsStringSync();
        final bank = await TaskBank.load('bank/manifest.json', read);
        final reference = PracticeSession(
          bank: bank,
          settings: PracticeSettings(
            minimumAnswers: 10,
            successWindow: 10,
            passPercent: 85,
            extraTasksPerError: 2,
          ),
        );
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
        final primary = find.widgetWithText(FilledButton, 'Проверить себя');
        expect(find.text('0%'), findsOneWidget);
        for (var answerIndex = 0; answerIndex < 8; answerIndex++) {
          final correct = answerIndex > 0;
          expect(find.byKey(const ValueKey('bank-answer')), findsNothing);
          expect(find.text('Выбери ответ:'), findsOneWidget);
          expect(tester.widget<FilledButton>(primary).onPressed, isNull);
          final choices = answerChoices(reference.currentTask);
          final index = correct
              ? choices.indexOf(reference.currentTask.expectedAnswer)
              : choices.indexWhere(
                  (c) => c != reference.currentTask.expectedAnswer,
                );
          final lastCard = tester.getRect(
            find.byKey(const ValueKey('bank-choice-3')),
          );
          expect((Offset.zero & size).contains(lastCard.bottomRight), isTrue);
          await tester.tap(find.byKey(ValueKey('bank-choice-$index')));
          await tester.pump();
          expect(find.text('Абсолютно верно!'), findsNothing);
          expect(find.text('Пока не получилось!'), findsNothing);
          await tester.tap(primary);
          await tester.pumpAndSettle();
          reference.submit(answer: choices[index], correct: correct);
          expect(
            reference.successPercent,
            closeTo(answerIndex * 100 / 10, .000001),
          );
          expect(
            find.text('${(answerIndex * 100 / 10).floor()}%'),
            findsOneWidget,
          );
          expect(
            find.text(correct ? 'Абсолютно верно!' : 'Пока не получилось!'),
            findsOneWidget,
          );
          expect(find.byKey(const ValueKey('bank-answer')), findsNothing);
          for (var i = 0; i < 4; i++) {
            expect(
              tester
                  .widget<InkWell>(find.byKey(ValueKey('bank-choice-$i')))
                  .onTap,
              isNull,
            );
          }
          await tester.tap(find.text('Дальше'));
          await tester.pumpAndSettle();
          reference.advance();
        }
        expect(reference.successPercent, closeTo(7 * 100 / 10, .000001));
        final field = find.byKey(const ValueKey('bank-answer'));
        expect(field, findsOneWidget);
        expect(find.byKey(const ValueKey('bank-choice-0')), findsNothing);
        for (final correct in List.filled(4, false)) {
          await tester.enterText(
            field,
            correct ? reference.currentTask.expectedAnswer : '0',
          );
          await tester.pump();
          await tester.tap(primary);
          await tester.pumpAndSettle();
          reference.submit(
            answer: correct ? reference.currentTask.expectedAnswer : '0',
            correct: correct,
          );
          if (reference.needsDetailedExplanation) {
            expect(
              find.byKey(const ValueKey('bank-required-explanation')),
              findsOneWidget,
            );
            await tester.pump(const Duration(seconds: 10));
            await tester.tap(
              find.byKey(const ValueKey('bank-explanation-continue')),
            );
          } else {
            expect(tester.widget<TextField>(field).readOnly, isTrue);
            await tester.tap(find.text('Дальше'));
          }
          await tester.pumpAndSettle();
          reference.advance();
        }
        expect(reference.successPercent, lessThan(70));
        expect(field, findsNothing);
        expect(find.byKey(const ValueKey('bank-choice-0')), findsOneWidget);
        expect(tester.widget<FilledButton>(primary).onPressed, isNull);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
