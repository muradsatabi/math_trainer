import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/bank/task_bank.dart';
import 'package:math_trainer/bank_trainer.dart';
import 'package:math_trainer/main.dart';
import 'package:math_trainer/practice/answer_choices.dart';

void main() {
  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'history opens actual tasks and preserves the live choice $theme',
      (tester) async {
        tester.view.physicalSize = const Size(1366, 768);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Future<String> read(String path) async => File(path).readAsStringSync();
        final bank = await TaskBank.load('bank/manifest.json', read);
        await tester.pumpWidget(
          MathTrainerApp(
            themeMode: theme,
            home: BankTrainer(readText: read),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> tap(Finder f) async {
          await tester.ensureVisible(f);
          await tester.tap(f);
          await tester.pumpAndSettle();
        }

        await tap(find.byKey(const ValueKey('topic-0')));
        await tap(find.text('Начать практику'));
        final first = bank.blocks.first.tasks.first;
        final firstChoices = answerChoices(first);
        final wrong = firstChoices.indexWhere((s) => s != first.expectedAnswer);
        await tap(find.byKey(ValueKey('bank-choice-$wrong')));
        await tap(find.text('Проверить себя'));
        await tap(find.text('Дальше'));
        final second = bank.blocks.first.tasks[1];
        final correct = answerChoices(second).indexOf(second.expectedAnswer);
        await tap(find.byKey(ValueKey('bank-choice-$correct')));
        await tap(find.text('Проверить себя'));
        await tap(find.text('Дальше'));
        await tap(find.byKey(const ValueKey('bank-choice-0')));
        await tap(find.text('Предыдущее задание'));
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byKey(const ValueKey('bank-task-2')), findsOneWidget);
        expect(find.text('Абсолютно верно!'), findsOneWidget);
        expect(find.text(second.expression), findsOneWidget);
        for (var i = 0; i < 4; i++) {
          expect(
            tester
                .widget<InkWell>(find.byKey(ValueKey('bank-choice-$i')))
                .onTap,
            isNull,
          );
        }
        await tap(find.text('Предыдущее задание'));
        expect(find.byKey(const ValueKey('bank-task-1')), findsOneWidget);
        expect(find.text('Предыдущее задание'), findsNothing);
        expect(find.text('Пока не получилось!'), findsOneWidget);
        expect(find.text('Твой ответ: ${firstChoices[wrong]}'), findsOneWidget);
        expect(find.text('10%'), findsOneWidget);
        await tap(find.text('Дальше'));
        expect(find.byKey(const ValueKey('bank-task-2')), findsOneWidget);
        await tap(find.text('Дальше'));
        expect(find.byKey(const ValueKey('bank-task-3')), findsOneWidget);
        expect(find.text('Твой ответ: ${firstChoices[wrong]}'), findsNothing);
        final choice = tester.widget<InkWell>(
          find.byKey(const ValueKey('bank-choice-0')),
        );
        final semantics = tester.widget<Semantics>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('bank-choice-0')),
                matching: find.byType(Semantics),
              )
              .first,
        );
        expect(semantics.properties.selected, isTrue);
        expect(choice.onTap, isNotNull);
        expect(find.text('10%'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
