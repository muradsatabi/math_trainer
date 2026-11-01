import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/bank/factor_answer_checker.dart';
import 'package:math_trainer/practice/answer_choices.dart';
import 'package:math_trainer/practice/generated_session.dart';
import 'package:math_trainer/practice/practice_session.dart';

void main() {
  final source = File('bank/templates/common_factor.json').readAsStringSync();
  for (final family in ['numeric', 'literal']) {
    test(
      'all generated $family tasks are supported and immutable snapshots',
      () {
        final generated = GeneratedSession.start(
          family: family,
          source: source,
          id: 'fixture-$family',
          seed: 42,
        );
        final bank = generated.practice.bank;
        expect(bank.blocks.length, family == 'numeric' ? 7 : 9);
        expect(bank.taskCount, family == 'numeric' ? 70 : 90);
        final expressions = <String>{};
        for (final block in bank.blocks) {
          expect(block.tasks.length, 10);
          for (final task in block.tasks) {
            expect(expressions.add(task.expression), isTrue);
            expect(
              checkFactorAnswer(task, task.expectedAnswer),
              AnswerVerdict.correct,
              reason: '${task.expression} = ${task.expectedAnswer}',
            );
            expect(answerChoices(task), contains(task.expectedAnswer));
            expect(task.templateId, block.id);
          }
        }
        generated.practice.submit(answer: '0', correct: false);
        generated.practice.advance();
        generated.practice.submit(answer: '0', correct: false);
        generated.practice.advance();
        generated.practice.submit(answer: '0', correct: false);
        generated.view = {'page': 'explanation', 'draft': '2(a', 'history': 1};
        final encoded = encodeGeneratedSessions([generated]);
        final restored = decodeGeneratedSessions(encoded).single;
        expect(jsonEncode(restored.toJson()), jsonEncode(generated.toJson()));
        expect(restored.practice.needsDetailedExplanation, isTrue);
        expect(restored.practice.pendingExtraTasks, 2);
        expect(restored.templateSource, source);
        restored.practice.advance();
        generated.practice.advance();
        expect(
          restored.practice.currentTask.id,
          generated.practice.currentTask.id,
        );
        for (var i = 0; i < 2; i++) {
          for (final s in [generated.practice, restored.practice]) {
            s.submit(answer: s.currentTask.expectedAnswer, correct: true);
            s.advance();
          }
        }
        expect(restored.practice.currentBlock.id, bank.blocks[1].id);
        expect(jsonEncode(restored.toJson()), jsonEncode(generated.toJson()));
      },
    );
  }

  test(
    'finished session restores scores, task order, input format and queue',
    () {
      final s = GeneratedSession.start(
        family: 'literal',
        source: source,
        id: 'finished',
        seed: 6,
      );
      for (var i = 0; i < 9; i++) {
        s.practice.submit(
          answer: s.practice.currentTask.expectedAnswer,
          correct: true,
        );
        s.practice.advance();
      }
      s.practice.finish();
      final restored = decodeGeneratedSessions(encodeGeneratedSessions([s]))
          .single;
      expect(restored.practice.isFinished, isTrue);
      expect(restored.practice.successPercent, 90);
      expect(restored.practice.usesInput, isTrue);
      expect(
        () => restored.practice.submit(answer: '0', correct: false),
        throwsStateError,
      );
      restored.practice.resume();
      restored.practice.submit(
        answer: restored.practice.currentTask.expectedAnswer,
        correct: true,
      );
      expect(restored.practice.attempts.length, 10);
      expect(s.practice.attempts.length, 9);
    },
  );

  test(
    'corrupt references and unknown history versions fail instead of resetting',
    () {
      final s = GeneratedSession.start(
        family: 'numeric',
        source: source,
        id: 'bad',
        seed: 1,
      );
      final bad =
          jsonDecode(jsonEncode(s.practice.toJson())) as Map<String, dynamic>;
      bad['task_id'] = 'missing';
      expect(() => PracticeSession.fromJson(bad), throwsFormatException);
      expect(
        () => decodeGeneratedSessions('{"schema_version":99,"sessions":[]}'),
        throwsFormatException,
      );
      expect(
        () => decodeGeneratedSessions(encodeGeneratedSessions([s, s])),
        throwsFormatException,
      );
    },
  );
}
