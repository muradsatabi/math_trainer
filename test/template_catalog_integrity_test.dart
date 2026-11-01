import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/generator/task_generator.dart';
import 'package:math_trainer/bank/factor_answer_checker.dart';
import 'package:math_trainer/bank/task_bank.dart';

void main() {
  test('every active canonical example is supported, equal and fulfils its operation', () {
    for (final file in Directory(
      'bank/templates',
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.json'))) {
      for (final template in loadTemplates(
        file.readAsStringSync(),
      ).where((t) => t.active)) {
        final sides = template.example.split('→');
        expect(
          equivalentExpressions(sides.first, sides.last),
          isTrue,
          reason: template.id,
        );
        final task = BankTask(
          id: template.id,
          revision: 1,
          instruction: 'Fixture',
          expression: sides.first.trim(),
          expectedAnswer: sides.last.trim(),
          acceptedExamples: const [],
          methodicalStatus: 'generated',
          templateId: template.id,
          operation: template.operation,
        );
        expect(
          checkFactorAnswer(task, task.expectedAnswer),
          AnswerVerdict.correct,
          reason: template.id,
        );
      }
    }
  });
}
