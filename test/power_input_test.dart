import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/answer_form.dart';
import 'package:math_trainer/bank/factor_answer_checker.dart';
import 'package:math_trainer/bank/task_bank.dart';
import 'package:math_trainer/practice/answer_keyboard.dart';

void main() {
  test('power notation respects numeric, literal and unary precedence', () {
    for (final pair in [
      ['2^3', '8'],
      ['2²', '4'],
      ['a^2', 'aa'],
      ['a²', 'aa'],
      ['a^3', 'a³'],
      ['(a+b)^2', 'aa+2ab+bb'],
      ['-2^2', '-4'],
      ['(-2)^2', '4'],
      ['-a²', '-aa'],
      ['3*(-a^2)', '-3aa'],
      ['2^0', '1'],
      ['2³', '8'],
      ['2¹⁰', '1024'],
      ['a¹²', 'aaaaaaaaaaaa'],
    ]) {
      expect(isCompleteAnswer(pair[0]), isTrue, reason: pair[0]);
      expect(
        equivalentExpressions(pair[0], pair[1]),
        isTrue,
        reason: pair.join(' = '),
      );
    }
    for (final text in ['2^', 'a^^2', '^2', '2^-3', 'a^x']) {
      expect(isCompleteAnswer(text), isFalse, reason: text);
    }
    expect(equivalentExpressions('0^0', '1'), isNull);
    expect(equivalentExpressions('a^99', 'a'), isNull);
    final task = BankTask(
      id: 'powers',
      revision: 1,
      instruction: 'Вынеси',
      expression: '8a+8b',
      expectedAnswer: '8(a+b)',
      acceptedExamples: const [],
      methodicalStatus: 'approved',
    );
    expect(checkFactorAnswer(task, '2^3(a+b)'), AnswerVerdict.correct);
    expect(checkFactorAnswer(task, '2^2(a+b)'), AnswerVerdict.incorrect);
  });

  testWidgets('calculator has one power operation key', (tester) async {
    final operations = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnswerKeyboard(
            letters: const ['a', 'b'],
            enabled: true,
            compact: true,
            onInsert: operations.add,
          ),
        ),
      ),
    );
    final power = find.byKey(const ValueKey('bank-symbol-^'));
    expect(find.byKey(const ValueKey('bank-symbol-²')), findsNothing);
    expect(find.text('xⁿ'), findsNothing);
    expect(find.text('x²'), findsNothing);
    expect(
      find.descendant(of: power, matching: find.text('x')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: power, matching: find.text('y')),
      findsOneWidget,
    );
    await tester.tap(power);
    await tester.tap(find.byKey(const ValueKey('bank-symbol-3')));
    expect(operations, ['^', '3']);
  });
}
