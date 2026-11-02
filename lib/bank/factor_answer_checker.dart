import 'task_bank.dart';
import '../practice/power_notation.dart';

enum AnswerVerdict { correct, incorrect, incomplete, unsupported, partial }

/// Exact equality for the supported integer polynomials; null means unsupported.
/// Does not decide whether the required method/form has been demonstrated.
bool? equivalentExpressions(String first, String second) {
  try {
    return _samePolynomial(
      _Parser(first).parse().value,
      _Parser(second).parse().value,
    );
  } on _Incomplete {
    return null;
  } on FormatException {
    return null;
  }
}

/// Limited exact polynomial arithmetic for the bank's integer expressions.
/// Unknown equivalent forms remain unsupported, rather than marked incorrect.
AnswerVerdict checkFactorAnswer(BankTask task, String answer) {
  if (answer.trim().isEmpty) return AnswerVerdict.incomplete;
  try {
    final entered = _Parser(answer).parse();
    final original = _Parser(task.expression).parse();
    final examples = [task.expectedAnswer, ...task.acceptedExamples];
    if (!_samePolynomial(entered.value, original.value)) {
      return AnswerVerdict.incorrect;
    }
    if (task.operation == 'expand') {
      return entered.unexpanded || !_collectedMonomials(answer)
          ? entered.shape.replaceAll(RegExp(r'[\[\]]'), '') ==
                    original.shape.replaceAll(RegExp(r'[\[\]]'), '')
                ? AnswerVerdict.incorrect
                : AnswerVerdict.partial
          : AnswerVerdict.correct;
    }
    if (examples.any((e) => _Parser(e).parse().shape == entered.shape)) {
      return AnswerVerdict.correct;
    }
    if (task.requireCompleteFactor) {
      final expected = _Parser(task.expectedAnswer).parse().factored;
      final actual = entered.factored;
      if (expected != null &&
          actual != null &&
          expected.outside.length == 1 &&
          actual.outside.length == 1) {
        final target = expected.outside.entries.single;
        final extracted = actual.outside.entries.single;
        if (extracted.key.isEmpty &&
            extracted.value.abs() == 1 &&
            (target.key.isNotEmpty || target.value.abs() > 1)) {
          return AnswerVerdict.incorrect;
        }
        final remainder = _monomialQuotient(target, extracted);
        if (remainder != null) {
          return remainder.key.isEmpty && remainder.value.abs() == 1
              ? AnswerVerdict.correct
              : AnswerVerdict.partial;
        }
      }
    }
    // A sum alone cannot demonstrate the requested extraction.
    if (!entered.hasFactoredSum) return AnswerVerdict.incorrect;
    return AnswerVerdict.unsupported;
  } on _Incomplete {
    return AnswerVerdict.incomplete;
  } on FormatException {
    return AnswerVerdict.unsupported;
  }
}

bool _collectedMonomials(String answer) {
  final text = normalizePowers(answer).replaceAll(RegExp(r'[()\s]'), '');
  for (final term in text.split(RegExp('[+−-]'))) {
    final letters = RegExp(r'[a-zA-Z](?:\^\d+)?').allMatches(term).toList();
    if (letters.map((m) => m[0]![0]).toSet().length != letters.length) {
      return false;
    }
    final coefficients = term.replaceAll(RegExp(r'[a-zA-Z](?:\^\d+)?'), '');
    if (RegExp(r'\d+').allMatches(coefficients).length > 1) return false;
  }
  return true;
}

/// Canonical expanded integer polynomial for the supported expression subset.
/// Used by the bracket generator; unsupported syntax never becomes an exercise.
String expandedPolynomial(String expression) {
  return _polynomialText(_Parser(expression).parse().value);
}

String _polynomialText(Map<String, int> polynomial) {
  final terms = <String>[];
  for (final entry in polynomial.entries) {
    final counts = <String, int>{};
    for (final letter in entry.key.split('')) {
      counts[letter] = (counts[letter] ?? 0) + 1;
    }
    final letters = counts.entries
        .map((e) => e.value == 1 ? e.key : '${e.key}^${e.value}')
        .join();
    final coefficient = entry.value.abs();
    final body =
        '${coefficient == 1 && letters.isNotEmpty ? '' : coefficient}$letters';
    terms.add(
      '${entry.value < 0
          ? '− '
          : terms.isEmpty
          ? ''
          : '+ '}$body',
    );
  }
  return displayPowers(terms.isEmpty ? '0' : terms.join(' '));
}

bool _samePolynomial(Map<String, int> a, Map<String, int> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

Map<String, int> _add(Map<String, int> a, Map<String, int> b, [int sign = 1]) {
  final result = Map<String, int>.of(a);
  for (final term in b.entries) {
    result[term.key] = (result[term.key] ?? 0) + sign * term.value;
  }
  result.removeWhere((_, coefficient) => coefficient == 0);
  return result;
}

Map<String, int> _multiply(Map<String, int> a, Map<String, int> b) {
  if (a.length * b.length > 500) {
    throw const FormatException('Expression too large');
  }
  final result = <String, int>{};
  for (final x in a.entries) {
    for (final y in b.entries) {
      final letters = (x.key + y.key).split('')..sort();
      final key = letters.join();
      final coefficient = x.value * y.value;
      if (coefficient.abs() > 1000000000) {
        throw const FormatException('Number too large');
      }
      result[key] = (result[key] ?? 0) + coefficient;
    }
  }
  result.removeWhere((_, coefficient) => coefficient == 0);
  return result;
}

MapEntry<String, int>? _monomialQuotient(
  MapEntry<String, int> numerator,
  MapEntry<String, int> denominator,
) {
  if (denominator.value == 0 || numerator.value % denominator.value != 0) {
    return null;
  }
  var letters = numerator.key;
  for (final letter in denominator.key.split('')) {
    final index = letters.indexOf(letter);
    if (index < 0) return null;
    letters = letters.replaceRange(index, index + 1, '');
  }
  return MapEntry(letters, numerator.value ~/ denominator.value);
}

/// Only a proven proper part of the task's required outer monomial is used.
String? partialFactorExample(BankTask task) {
  if (!task.requireCompleteFactor || task.operation != 'factor') return null;
  final form = _Parser(task.expectedAnswer).parse().factored;
  if (form == null || form.outside.length != 1) return null;
  final target = form.outside.entries.single;
  MapEntry<String, int>? part;
  if (target.key.isNotEmpty && target.value.abs() > 1) {
    part = MapEntry('', target.value.abs());
  } else if (target.key.length > 1) {
    part = MapEntry(target.key[0], 1);
  } else if (target.key.isEmpty) {
    for (var divisor = 2; divisor * divisor <= target.value.abs(); divisor++) {
      if (target.value % divisor == 0) {
        part = MapEntry('', divisor);
        break;
      }
    }
  }
  if (part == null) return null;
  final quotient = <String, int>{};
  for (final term in _Parser(task.expression).parse().value.entries) {
    final divided = _monomialQuotient(term, part);
    if (divided == null) return null;
    quotient[divided.key] = divided.value;
  }
  final result =
      '${_polynomialText({part.key: part.value})}(${_polynomialText(quotient)})';
  return checkFactorAnswer(task, result) == AnswerVerdict.partial
      ? result
      : null;
}

String partialAnswerHint(BankTask task, [String? answer]) {
  if (task.operation == 'expand') {
    return 'Равенство сохранено, но преобразование ещё не закончено. Раскрой оставшиеся скобки и выполни умножение чисел и одинаковых букв. В следующем задании этого типа доведи запись до конца.';
  }
  String? remaining;
  if (answer != null) {
    try {
      final expected = _Parser(task.expectedAnswer).parse().factored;
      final actual = _Parser(answer).parse().factored;
      if (expected?.outside.length == 1 && actual?.outside.length == 1) {
        final quotient = _monomialQuotient(
          expected!.outside.entries.single,
          actual!.outside.entries.single,
        );
        if (quotient != null) {
          remaining = _polynomialText({quotient.key: quotient.value.abs()});
        }
      }
    } on FormatException {
      // A generic cue remains safe for an unsupported spelling.
    } on _Incomplete {
      // Syntax incompleteness is never counted as a partial mathematical answer.
    }
  }
  return 'Ты сохранил значение выражения и верно вынес часть общего множителя. '
      'Но в скобках ещё остался общий множитель${remaining == null ? '' : ' $remaining'}. '
      'Его тоже можно вынести. В следующем задании этого типа доведи вынесение до конца.';
}

class _Factored {
  _Factored(this.outside, this.inside);
  final Map<String, int> outside, inside;
}

class _Node {
  _Node(
    this.shape,
    this.value, {
    this.sum = false,
    this.groupedSum = false,
    this.hasFactoredSum = false,
    this.unexpanded = false,
    this.factored,
  });
  final String shape;
  final Map<String, int> value;
  final bool sum;
  final bool groupedSum;
  final bool hasFactoredSum;
  final bool unexpanded;
  final _Factored? factored;
}

class _Incomplete implements Exception {}

class _Parser {
  _Parser(String text)
    : text = normalizePowers(text)
          .replaceAll(RegExp(r'\s+'), '')
          .replaceAll('−', '-')
          .replaceAll('·', '*')
          .replaceAll('×', '*');
  final String text;
  int position = 0;
  String get symbol => position < text.length ? text[position] : '';

  _Node parse() {
    if (text.length > 200) throw const FormatException('Expression too long');
    final node = _sum();
    if (position != text.length) {
      throw const FormatException('Unsupported input');
    }
    return node;
  }

  _Node _sum() {
    var node = _product();
    while (symbol == '+' || symbol == '-') {
      final op = symbol;
      position++;
      final other = _product();
      node = _Node(
        '(${node.shape}$op${other.shape})',
        _add(node.value, other.value, op == '+' ? 1 : -1),
        sum: true,
        unexpanded: node.unexpanded || other.unexpanded,
      );
    }
    return node;
  }

  _Node _product() {
    var node = _unary();
    while (symbol == '*' ||
        symbol == '(' ||
        RegExp(r'^[0-9a-zA-Z]$').hasMatch(symbol)) {
      if (symbol == '*') position++;
      final other = _unary();
      _Factored? form;
      if (node.factored != null &&
          !other.sum &&
          !other.groupedSum &&
          other.factored == null) {
        form = _Factored(
          _multiply(node.factored!.outside, other.value),
          node.factored!.inside,
        );
      } else if (other.factored != null &&
          !node.sum &&
          !node.groupedSum &&
          node.factored == null) {
        form = _Factored(
          _multiply(other.factored!.outside, node.value),
          other.factored!.inside,
        );
      } else if (node.groupedSum && !other.sum && !other.groupedSum) {
        form = _Factored(other.value, node.value);
      } else if (other.groupedSum && !node.sum && !node.groupedSum) {
        form = _Factored(node.value, other.value);
      }
      node = _Node(
        '${node.shape}*${other.shape}',
        _multiply(node.value, other.value),
        hasFactoredSum:
            node.hasFactoredSum ||
            other.hasFactoredSum ||
            (node.groupedSum && !other.sum) ||
            (other.groupedSum && !node.sum),
        unexpanded:
            node.unexpanded ||
            other.unexpanded ||
            node.groupedSum ||
            other.groupedSum,
        factored: form,
      );
    }
    return node;
  }

  _Node _unary() {
    if (symbol != '+' && symbol != '-') return _power();
    final negative = symbol == '-';
    position++;
    final node = _unary();
    return negative
        ? _Node(
            '-${node.shape}',
            node.value.map((key, value) => MapEntry(key, -value)),
            hasFactoredSum: node.hasFactoredSum,
            unexpanded: node.unexpanded || node.groupedSum,
            factored: node.factored == null
                ? null
                : _Factored(
                    node.factored!.outside.map(
                      (key, value) => MapEntry(key, -value),
                    ),
                    node.factored!.inside,
                  ),
          )
        : node;
  }

  _Node _power() {
    final base = _atom();
    int exponent;
    if (symbol == '^') {
      position++;
      if (symbol.isEmpty) throw _Incomplete();
      final start = position;
      while (RegExp(r'^[0-9]$').hasMatch(symbol)) {
        position++;
      }
      if (position == start || position - start > 2) {
        throw const FormatException('Unsupported exponent');
      }
      exponent = int.parse(text.substring(start, position));
      if (exponent > 12) throw const FormatException('Exponent too large');
    } else {
      return base;
    }
    if (exponent == 1) return base;
    if (base.value.isEmpty && exponent == 0) {
      throw const FormatException('Zero to zero');
    }
    var value = <String, int>{'': 1};
    for (var i = 0; i < exponent; i++) {
      value = _multiply(value, base.value);
    }
    final constant = value.isEmpty || value.keys.every((k) => k.isEmpty);
    return _Node(
      constant
          ? '${value[''] ?? 0}'
          : List.filled(exponent, base.shape).join('*'),
      value,
      hasFactoredSum: base.hasFactoredSum || (base.groupedSum && exponent > 1),
      unexpanded: base.unexpanded || (base.groupedSum && exponent > 1),
    );
  }

  _Node _atom() {
    if (symbol.isEmpty) throw _Incomplete();
    if (symbol == '(') {
      position++;
      final node = _sum();
      if (symbol != ')') {
        if (symbol.isEmpty) throw _Incomplete();
        throw const FormatException('Missing parenthesis');
      }
      position++;
      return _Node(
        '[${node.shape}]',
        node.value,
        groupedSum: node.sum || node.groupedSum,
        hasFactoredSum: node.hasFactoredSum,
        unexpanded: node.unexpanded,
        factored: node.factored,
      );
    }
    if (RegExp(r'^[0-9]$').hasMatch(symbol)) {
      final start = position;
      while (RegExp(r'^[0-9]$').hasMatch(symbol)) {
        position++;
      }
      final digits = text.substring(start, position);
      if (digits.length > 6) throw const FormatException('Number too large');
      final value = int.parse(digits);
      return _Node('$value', value == 0 ? {} : {'': value});
    }
    if (RegExp(r'^[a-zA-Z]$').hasMatch(symbol)) {
      final variable = symbol;
      position++;
      return _Node(variable, {variable: 1});
    }
    if (symbol == ')' && position == text.length - 1) throw _Incomplete();
    throw const FormatException('Unsupported symbol');
  }
}
