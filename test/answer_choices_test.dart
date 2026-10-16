import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/bank/factor_answer_checker.dart';
import 'package:math_trainer/bank/task_bank.dart';
import 'package:math_trainer/practice/answer_choices.dart';

void main() {
  test(
    'all 110 tasks have one correct and three distinct proven wrong choices',
    () async {
      final bank = await TaskBank.load(
        'bank/manifest.json',
        (p) async => File(p).readAsStringSync(),
      );
      final correctPositions = <int>{};
      for (final task in bank.blocks.expand((b) => b.tasks)) {
        final choices = answerChoices(task);
        expect(choices, hasLength(4), reason: task.id);
        expect(answerChoices(task), choices);
        correctPositions.add(choices.indexOf(task.expectedAnswer));
        expect(
          choices.where(
            (c) => checkFactorAnswer(task, c) == AnswerVerdict.correct,
          ),
          hasLength(1),
          reason: task.id,
        );
        for (final choice in choices.where((c) => c != task.expectedAnswer)) {
          expect(
            equivalentExpressions(choice, task.expression),
            isFalse,
            reason: '${task.id}: $choice',
          );
          expect(checkFactorAnswer(task, choice), AnswerVerdict.incorrect);
        }
        for (var i = 0; i < choices.length; i++) {
          for (var j = i + 1; j < choices.length; j++) {
            expect(
              equivalentExpressions(choices[i], choices[j]),
              isFalse,
              reason: task.id,
            );
          }
        }
      }
      expect(correctPositions, hasLength(4));
    },
  );

  test('polynomial equality is separate from extraction form and unsupported input', () {
    expect(equivalentExpressions('7(a+b)', '7a+7b'), isTrue);
    expect(equivalentExpressions('7(a-b)', '7a+7b'), isFalse);
    expect(equivalentExpressions('7(a+b', '7a+7b'), isNull);
    expect(equivalentExpressions('a/2', 'a'), isNull);
  });
}
