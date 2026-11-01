import 'dart:math';

import '../bank/factor_answer_checker.dart';
import '../bank/task_bank.dart';
import '../practice/answer_choices.dart';
import 'task_generator.dart';

/// Demonstration error models, not a methodically approved distractor bank.
class WorksheetTestItem {
  WorksheetTestItem(this.exercise, List<DemoAnswerChoice> choices)
    : choices = List.unmodifiable(choices);

  final GeneratedExercise exercise;
  final List<DemoAnswerChoice> choices;
  int get correctIndex => choices.indexWhere((c) => c.errorId == null);
  static const labels = ['А', 'Б', 'В', 'Г'];
}

List<List<WorksheetTestItem>> worksheetTestItems(
  List<List<GeneratedExercise>> variants, {
  int? seed,
}) {
  final random = Random(seed);
  return [
    for (var v = 0; v < variants.length; v++)
      [
        for (var i = 0; i < variants[v].length; i++)
          _testItem(variants[v][i], 'pdf-$v-$i', random),
      ],
  ];
}

WorksheetTestItem _testItem(
  GeneratedExercise exercise,
  String id,
  Random random,
) {
  final task = withDemoChoices(
    BankTask(
      id: id,
      revision: 1,
      instruction: 'Вынеси общий множитель за скобки',
      expression: exercise.expression,
      expectedAnswer: exercise.answer,
      acceptedExamples: [exercise.answer],
      methodicalStatus: 'generated',
      templateId: exercise.templateId,
      operation: exercise.operation,
    ),
  );
  if (exercise.operation == 'expand' && task.demoChoices != null) {
    final choices = task.demoChoices!.toList()..shuffle(random);
    return WorksheetTestItem(exercise, choices);
  }
  final factor = RegExp(r'^([0-9a-zA-Z]+)\(').firstMatch(exercise.answer)?[1];
  if (task.demoChoices == null || factor == null) {
    throw StateError(
      'Нет подходящих вариантов ответа для ${exercise.templateId}.',
    );
  }
  // Reuse the practice models for a missed division of the first/last term.
  // A sign error gives an alternative of the same length as the correct one:
  // correct must not be the only shortest answer. All options retain the factor.
  var depth = 0;
  int? lastSign;
  for (
    var i = exercise.answer.indexOf('(') + 1;
    i < exercise.answer.length - 1;
    i++
  ) {
    final c = exercise.answer[i];
    if (c == '(') depth++;
    if (c == ')') depth--;
    if (depth == 0 && (c == '+' || c == '−' || c == '-')) lastSign = i;
  }
  if (lastSign == null) throw StateError('Нет подходящей модели ошибки знака.');
  final signError = exercise.answer.replaceRange(
    lastSign,
    lastSign + 1,
    exercise.answer[lastSign] == '+' ? '−' : '+',
  );
  final choices = [
    DemoAnswerChoice(exercise.answer),
    ...task.demoChoices!.where(
      (c) =>
          c.errorId == 'first_term_not_divided' ||
          c.errorId == 'last_term_not_divided',
    ),
    DemoAnswerChoice(signError, errorId: 'last_term_sign_changed'),
  ];
  if (choices.length != 4 ||
      equivalentExpressions(choices.first.answer, exercise.expression) !=
          true) {
    throw StateError('Невозможно подготовить четыре ответа.');
  }
  for (var i = 1; i < choices.length; i++) {
    if (equivalentExpressions(choices[i].answer, exercise.expression) !=
        false) {
      throw StateError('Неверный вариант не прошёл математическую проверку.');
    }
    for (var j = 0; j < i; j++) {
      if (equivalentExpressions(choices[i].answer, choices[j].answer) !=
          false) {
        throw StateError('Варианты ответа совпадают или не поддерживаются.');
      }
    }
  }
  choices.shuffle(random);
  return WorksheetTestItem(exercise, choices);
}
