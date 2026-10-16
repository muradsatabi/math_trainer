import '../bank/factor_answer_checker.dart';
import '../bank/task_bank.dart';

/// UI alternatives only: never changes or publishes the canonical task bank.
/// Every distractor is proven unequal, rather than inferred from its spelling.
List<String> answerChoices(BankTask task) {
  final correct = task.expectedAnswer;
  if (checkFactorAnswer(task, correct) != AnswerVerdict.correct) {
    throw StateError('Unsupported expected answer: ${task.id}');
  }
  final wrong = <String>[];
  void consider(String candidate) {
    if (wrong.length == 3 ||
        equivalentExpressions(candidate, task.expression) != false ||
        wrong.any(
          (other) => equivalentExpressions(other, candidate) != false,
        )) {
      return;
    }
    wrong.add(candidate);
  }

  // Typical local changes: one coefficient, a sign, or a missing outer factor.
  for (final match in RegExp(r'\d+').allMatches(correct)) {
    final value = int.parse(match[0]!);
    for (final delta in [-1, 1]) {
      if (value + delta > 0) {
        consider(
          correct.replaceRange(match.start, match.end, '${value + delta}'),
        );
      }
    }
  }
  for (final match in RegExp(r'[+−-]').allMatches(correct)) {
    consider(
      correct.replaceRange(match.start, match.end, match[0] == '+' ? '−' : '+'),
    );
  }
  final outer = RegExp(r'^[0-9a-zA-Z]+\((.+)\)$').firstMatch(correct);
  if (outer != null) consider(outer[1]!);

  // Bounded fallback also works for tasks with only literal factors.
  for (final offset in [1, -1, 2, -2, 3, -3]) {
    consider('($correct) ${offset > 0 ? '+' : '−'} ${offset.abs()}');
  }
  if (wrong.length != 3) {
    throw StateError('Cannot create safe choices: ${task.id}');
  }
  final choices = [...wrong];
  final position = task.id.codeUnits.fold(0, (sum, c) => sum + c) % 4;
  choices.insert(position, correct);
  return List.unmodifiable(choices);
}
