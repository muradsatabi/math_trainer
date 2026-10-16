import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/bank/task_bank.dart';
import 'package:math_trainer/bank_trainer.dart';
import 'package:math_trainer/main.dart';
import 'package:math_trainer/practice/answer_choices.dart';

void main() {
  for (final inputOnly in [false, true]) {
    testWidgets('two correct in a row after a new error; input=$inputOnly', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<String> read(String path) async {
        final text = File(path).readAsStringSync();
        if (!inputOnly || path != 'bank/manifest.json') return text;
        final data = jsonDecode(text) as Map<String, dynamic>;
        data['practice']['input_percent'] = 0;
        return jsonEncode(data);
      }

      final bank = await TaskBank.load('bank/manifest.json', read);
      await tester.pumpWidget(
        MathTrainerApp(home: BankTrainer(readText: read)),
      );
      await tester.pumpAndSettle();
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap(find.byKey(const ValueKey('topic-0')));
      await tap(find.text('Начать практику'));
      const answers = [false, true, false, true, true];
      for (var i = 0; i < answers.length; i++) {
        final task = bank.blocks.first.tasks[i];
        expect(find.text(task.expression), findsOneWidget);
        if (inputOnly) {
          await tester.enterText(
            find.byKey(const ValueKey('bank-answer')),
            answers[i] ? task.expectedAnswer : '0',
          );
          await tester.pump();
        } else {
          final options = answerChoices(task);
          final selected = answers[i]
              ? options.indexOf(task.expectedAnswer)
              : options.indexWhere((o) => o != task.expectedAnswer);
          await tap(find.byKey(ValueKey('bank-choice-$selected')));
        }
        await tap(find.text('Проверить себя'));
        expect(find.textContaining('Верных подряд:'), findsNothing);
        await tap(find.text('Дальше'));
      }
      expect(find.text(bank.blocks[1].tasks.first.expression), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
