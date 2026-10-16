import 'task_bank.dart';

enum AnswerVerdict { correct, incorrect, incomplete, unsupported }

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
    if (examples.any((e) => _Parser(e).parse().shape == entered.shape)) {
      return AnswerVerdict.correct;
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

class _Node {
  _Node(
    this.shape,
    this.value, {
    this.sum = false,
    this.groupedSum = false,
    this.hasFactoredSum = false,
  });
  final String shape;
  final Map<String, int> value;
  final bool sum;
  final bool groupedSum;
  final bool hasFactoredSum;
}

class _Incomplete implements Exception {}

class _Parser {
  _Parser(String text)
    : text = text
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
      );
    }
    return node;
  }

  _Node _product() {
    var node = _atom();
    while (symbol == '*' ||
        symbol == '(' ||
        RegExp(r'^[0-9a-zA-Z]$').hasMatch(symbol)) {
      if (symbol == '*') position++;
      final other = _atom();
      node = _Node(
        '${node.shape}*${other.shape}',
        _multiply(node.value, other.value),
        hasFactoredSum:
            node.hasFactoredSum ||
            other.hasFactoredSum ||
            (node.groupedSum && !other.sum) ||
            (other.groupedSum && !node.sum),
      );
    }
    return node;
  }

  _Node _atom() {
    if (symbol.isEmpty) throw _Incomplete();
    if (symbol == '+' || symbol == '-') {
      final negative = symbol == '-';
      position++;
      final node = _atom();
      return negative
          ? _Node(
              '-${node.shape}',
              node.value.map((key, value) => MapEntry(key, -value)),
              hasFactoredSum: node.hasFactoredSum,
            )
          : node;
    }
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
        groupedSum: node.sum,
        hasFactoredSum: node.hasFactoredSum,
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
