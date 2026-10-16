import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/bank/task_bank.dart';
import 'package:math_trainer/bank/factor_answer_checker.dart';

void main() {
  late TaskBank bank;
  setUpAll(() async {
    bank = await TaskBank.load(
      'bank/manifest.json',
      (p) => File(p).readAsString(),
    );
  });
  test(
    'all source answers and alternatives are exact equivalent factorizations',
    () {
      for (final block in bank.blocks) {
        for (final task in block.tasks) {
          for (final answer in [
            task.expectedAnswer,
            ...task.acceptedExamples,
          ]) {
            expect(
              checkFactorAnswer(task, answer),
              AnswerVerdict.correct,
              reason: '${task.id}: $answer',
            );
          }
          expect(
            checkFactorAnswer(task, task.expression),
            AnswerVerdict.incorrect,
            reason: '${task.id}: original sum does not perform extraction',
          );
        }
      }
    },
  );
  test('equivalent unknown forms are not marked wrong', () {
    final task = bank.blocks.first.tasks.first;
    expect(checkFactorAnswer(task, '7(b+a)'), AnswerVerdict.unsupported);
    expect(checkFactorAnswer(task, '1(7a+7b)'), AnswerVerdict.unsupported);
    expect(checkFactorAnswer(task, '7(a-b)'), AnswerVerdict.incorrect);
    expect(checkFactorAnswer(task, '7*(a + b)'), AnswerVerdict.correct);
    expect(checkFactorAnswer(task, '7(a+'), AnswerVerdict.incomplete);
    expect(checkFactorAnswer(task, '7(а+b)'), AnswerVerdict.unsupported);
    expect(checkFactorAnswer(task, '3.5(2a+2b)'), AnswerVerdict.unsupported);
  });
}
