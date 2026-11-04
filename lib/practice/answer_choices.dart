import '../bank/factor_answer_checker.dart';
import '../bank/task_bank.dart';

/// UI alternatives only: never changes or publishes the canonical task bank.
/// Every distractor is proven unequal, rather than inferred from its spelling.
List<String> answerChoices(BankTask task) {
  if (task.demoChoices != null) {
    return List.unmodifiable(task.demoChoices!.map((c) => c.answer));
  }
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

/// MVP: only recognises an explicitly represented error, including equivalent
/// typed spellings. Does not infer the student's thinking from an arbitrary input.
DemoAnswerChoice? answerFeedback(BankTask task, String answer) {
  for (final choice in task.demoChoices ?? <DemoAnswerChoice>[]) {
    if (choice.isPartial &&
        checkFactorAnswer(task, answer) == AnswerVerdict.partial) {
      return choice;
    }
    if (choice.errorId != null &&
        equivalentExpressions(choice.answer, answer) == true) {
      return choice;
    }
  }
  return null;
}

/// The original and factored sums have matching term order in these generators.
/// Keep the sign and all nested brackets: never use a flat split on + or -.
List<String> _sumTerms(String text) {
  final terms = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c == '(') depth++;
    if (c == ')') depth--;
    if (depth == 0 && i > start && (c == '+' || c == '−' || c == '-')) {
      terms.add(text.substring(start, i).trim());
      start = i;
    }
  }
  terms.add(text.substring(start).trim());
  return terms;
}

String _joinTerms(List<String> terms) => terms.asMap().entries.map((entry) {
  final value = entry.value.trim();
  if (entry.key == 0) return value;
  return value.startsWith(RegExp('[+−-]')) ? ' $value' : ' + $value';
}).join();

BankTask withDemoChoices(BankTask task) {
  if (task.methodicalStatus != 'generated' || task.demoChoices != null) {
    return task;
  }
  if (task.operation == 'expand') return _expansionChoices(task);
  final match = RegExp(r'^([0-9a-zA-Z]+)\((.*)\)$')
      .firstMatch(task.expectedAnswer);
  if (match == null) return task;
  final factor = match[1]!;
  final residuals = _sumTerms(match[2]!);
  final originals = _sumTerms(task.expression);
  if (residuals.length != originals.length || residuals.length < 2) return task;
  final choices = <DemoAnswerChoice>[];
  // Two distinct errors: the first or the last term was not divided.
  for (final index in [0, residuals.length - 1]) {
    final values = List<String>.of(residuals);
    values[index] = originals[index];
    choices.add(
      DemoAnswerChoice(
        '$factor(${_joinTerms(values)})',
        errorId: index == 0
            ? 'first_term_not_divided'
            : 'last_term_not_divided',
        hint:
            'Проверь ${index == 0 ? 'первое' : 'последнее'} слагаемое: '
            'внутри скобок оно осталось без деления на $factor. '
            'Раздели на вынесенный множитель каждое слагаемое. '
            'Затем раскрой скобки для проверки.',
      ),
    );
  }
  choices.add(
    DemoAnswerChoice(
      _joinTerms(residuals),
      errorId: 'outer_factor_missing',
      hint:
          'В скобках ты получил нужные слагаемые, но множитель $factor потерялся. '
          'Оставь его перед скобками: вынесение множителя не должно менять значение выражения.',
    ),
  );
  // An uncertain or equivalent candidate never becomes a wrong option.
  for (var i = 0; i < choices.length; i++) {
    if (equivalentExpressions(choices[i].answer, task.expression) != false) {
      return task;
    }
    for (var j = 0; j < i; j++) {
      if (equivalentExpressions(choices[i].answer, choices[j].answer) !=
          false) {
        return task;
      }
    }
  }
  final position = task.id.codeUnits.fold(0, (sum, c) => sum + c) % 4;
  final partial = partialFactorExample(task);
  if (partial != null &&
      task.id.codeUnits.fold(0, (sum, c) => sum + c) % 3 == 0) {
    return withPartialFollowupChoice(task, task.id);
  }
  choices.insert(position, DemoAnswerChoice(task.expectedAnswer));
  return BankTask(
    id: task.id,
    revision: task.revision,
    instruction: task.instruction,
    expression: task.expression,
    expectedAnswer: task.expectedAnswer,
    acceptedExamples: task.acceptedExamples,
    methodicalStatus: task.methodicalStatus,
    templateId: task.templateId,
    operation: task.operation,
    requireCompleteFactor: task.requireCompleteFactor,
    demoChoices: choices,
  );
}

BankTask withCompleteFactorRule(BankTask task) {
  if (task.methodicalStatus != 'generated' ||
      task.operation != 'factor' ||
      task.requireCompleteFactor) {
    return task;
  }
  return BankTask(
    id: task.id,
    revision: task.revision,
    instruction: 'Вынеси общий множитель полностью',
    expression: task.expression,
    expectedAnswer: task.expectedAnswer,
    acceptedExamples: task.acceptedExamples,
    methodicalStatus: task.methodicalStatus,
    templateId: task.templateId,
    operation: task.operation,
    requireCompleteFactor: true,
  );
}

BankTask _expansionChoices(BankTask task) {
  final open = task.expression.indexOf('(');
  final close = task.expression.lastIndexOf(')');
  if (open < 0 || close <= open) return task;
  final factor =
      (task.expression.substring(0, open) +
              task.expression.substring(close + 1))
          .replaceAll('·', '')
          .trim();
  final inside = _sumTerms(task.expression.substring(open + 1, close));
  final expanded = _sumTerms(task.expectedAnswer);
  if (inside.length != expanded.length || inside.length < 2) return task;
  final choices = <DemoAnswerChoice>[];
  for (final index in [0, inside.length - 1]) {
    final terms = List<String>.of(expanded);
    terms[index] = inside[index];
    choices.add(
      DemoAnswerChoice(
        _joinTerms(terms),
        errorId: index == 0
            ? 'first_term_not_multiplied'
            : 'last_term_not_multiplied',
        hint:
            'Проверь ${index == 0 ? 'первое' : 'последнее'} слагаемое: оно осталось без умножения на $factor. '
            'Множитель перед скобками относится к каждому слагаемому внутри.',
      ),
    );
  }
  choices.add(
    DemoAnswerChoice(
      _joinTerms(inside),
      errorId: 'outer_multiplier_ignored',
      hint:
          'Скобки исчезли, но внешний множитель $factor ещё нужно умножить на каждое слагаемое. '
          'Сохрани знаки и запиши полученные произведения.',
    ),
  );
  for (var i = 0; i < choices.length; i++) {
    if (equivalentExpressions(choices[i].answer, task.expression) != false) {
      return task;
    }
    for (var j = 0; j < i; j++) {
      if (equivalentExpressions(choices[i].answer, choices[j].answer) !=
          false) {
        return task;
      }
    }
  }
  choices.insert(
    task.id.codeUnits.fold(0, (a, b) => a + b) % 4,
    DemoAnswerChoice(task.expectedAnswer),
  );
  return BankTask(
    id: task.id,
    revision: task.revision,
    instruction: task.instruction,
    expression: task.expression,
    expectedAnswer: task.expectedAnswer,
    acceptedExamples: task.acceptedExamples,
    methodicalStatus: task.methodicalStatus,
    templateId: task.templateId,
    operation: task.operation,
    demoChoices: choices,
  );
}

/// Two comparable pairs: full/partial factor, each with a valid and wrong form.
/// A follow-up always uses this set; ordinary tasks use it selectively.
BankTask withPartialFollowupChoice(BankTask task, String id) {
  final rawPartial = partialFactorExample(task);
  if (rawPartial == null) throw StateError('No supported partial factor');
  final partialMatch = RegExp(r'^(.+?)\((.*)\)$').firstMatch(rawPartial)!;
  final remaining = _sumTerms(partialMatch[2]!);
  final orderedTerms = <String>[];
  for (final term in _sumTerms(task.expression)) {
    final index = remaining.indexWhere(
      (candidate) =>
          equivalentExpressions('${partialMatch[1]}($candidate)', term) == true,
    );
    if (index < 0) throw StateError('Cannot align partial terms: ${task.id}');
    orderedTerms.add(remaining.removeAt(index));
  }
  final partial = '${partialMatch[1]}(${_joinTerms(orderedTerms)})';
  DemoAnswerChoice missedLastTerm(String expression, String errorId) {
    final match = RegExp(r'^(.+?)\((.*)\)$').firstMatch(expression)!;
    final terms = _sumTerms(match[2]!);
    final original = _sumTerms(task.expression).last;
    final index = terms.lastIndexWhere(
      (term) => equivalentExpressions('${match[1]}($term)', original) == true,
    );
    if (index < 0) throw StateError('Cannot align error terms: ${task.id}');
    terms[index] = original;
    return DemoAnswerChoice(
      '${match[1]}(${_joinTerms(terms)})',
      errorId: errorId,
      hint:
          'Проверь последнее слагаемое: оно осталось без деления на ${match[1]}. '
          'Раздели на вынесенный множитель каждое слагаемое и проверь обратным умножением.',
    );
  }

  final fullWrong = missedLastTerm(
    task.expectedAnswer,
    'last_term_not_divided',
  );
  final partialWrong = missedLastTerm(partial, 'partial_last_term_not_divided');
  for (final wrong in [fullWrong, partialWrong]) {
    if (checkFactorAnswer(task, wrong.answer) != AnswerVerdict.incorrect) {
      throw StateError('Unsupported competing error: ${task.id}');
    }
  }
  if (equivalentExpressions(fullWrong.answer, partialWrong.answer) != false) {
    throw StateError('Competing errors must differ: ${task.id}');
  }
  final choices = [
    DemoAnswerChoice(
      partial,
      isPartial: true,
      hint: partialAnswerHint(task, partial),
    ),
    partialWrong,
    DemoAnswerChoice(task.expectedAnswer),
    fullWrong,
  ];
  final offset = id.codeUnits.fold(0, (sum, c) => sum + c) % choices.length;
  final ordered = [...choices.skip(offset), ...choices.take(offset)];
  return BankTask.fromJson({
    ...task.toJson(),
    'task_id': id,
    'demo_choices_v1': ordered.map((c) => c.toJson()).toList(),
  });
}
