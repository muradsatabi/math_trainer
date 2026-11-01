import 'dart:convert';

import 'package:math_trainer/bank/task_bank.dart';
import 'package:math_trainer/practice/practice_session.dart';

/// Synthetic scenarios for UI regression tests; never shipped as study content.
/// Generated in memory, not a copy of the removed historical exercise bank.
Future<String> fixtureText(String path) async {
  if (path != 'fixture/config.json') {
    throw ArgumentError('Unknown fixture path');
  }
  return jsonEncode({
    'blocks': List.generate(22, (i) => i),
    'practice': {
      'minimum_answers': 10,
      'success_window': 10,
      'pass_percent': 85,
      'extra_tasks_per_error': 2,
      'input_percent': 70,
    },
  });
}

Future<TaskBank> fixtureBank(String path, BankTextReader read) async {
  final config = jsonDecode(await read(path)) as Map;
  return TaskBank(
    topicId: 'common_factor',
    title: 'Вынесение общего множителя за скобки',
    blocks: [
      for (final value in config['blocks'] as List)
        BankBlock(
          id: 'fixture-block-$value',
          title: 'Тестовый блок ${value + 1}',
          skill: 'Тестовое умение ${value + 1}',
          sourceSectionId: 'fixture',
          tasks: [
            for (var n = 0; n < 5; n++)
              BankTask(
                id: 'fixture-$value-$n',
                revision: 1,
                instruction: 'Вынеси общий множитель за скобки',
                expression: '${7 + value * 5 + n}a + ${7 + value * 5 + n}b',
                expectedAnswer: '${7 + value * 5 + n}(a + b)',
                acceptedExamples: const [],
                methodicalStatus: 'generated',
                templateId: 'fixture-template-$value',
              ),
          ],
        ),
    ],
  );
}

Future<PracticeSession> fixturePractice(BankTextReader read) async {
  final config =
      jsonDecode(await read('fixture/config.json'))['practice'] as Map;
  return PracticeSession(
    bank: await fixtureBank('fixture/config.json', read),
    settings: PracticeSettings(
      minimumAnswers: config['minimum_answers'],
      successWindow: config['success_window'],
      passPercent: config['pass_percent'],
      extraTasksPerError: config['extra_tasks_per_error'],
      inputPercent: config['input_percent'],
    ),
  );
}
