import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/bank/task_bank.dart';
import 'package:math_trainer/practice/practice_session.dart';

TaskBank fixtureBank(int blockCount) => TaskBank(
  topicId: 'test',
  title: 'Test fixture',
  blocks: List.generate(
    blockCount,
    (b) => BankBlock(
      id: 'block-$b',
      title: 'Block $b',
      skill: 'Fixture',
      sourceSectionId: 'fixture',
      tasks: List.generate(
        5,
        (t) => BankTask(
          id: 'task-$b-$t',
          revision: 1,
          instruction: 'Fixture',
          expression: 'fixture',
          expectedAnswer: 'fixture',
          acceptedExamples: [],
          methodicalStatus: 'approved',
        ),
      ),
    ),
  ),
);

PracticeSession session({int blocks = 22, int minimum = 22, int window = 22}) =>
    PracticeSession(
      bank: fixtureBank(blocks),
      settings: PracticeSettings(
        minimumAnswers: minimum,
        successWindow: window,
        passPercent: 85,
        extraTasksPerError: 2,
      ),
    );

void main() {
  test('finish is optional at 85%; eligibility follows the current window', () {
    final s = session(blocks: 22, minimum: 100, window: 20);
    expect(() => s.finish(), throwsStateError);
    for (var i = 0; i < 20; i++) {
      s.submit(answer: 'fixture', correct: i < 17);
      s.advance();
    }
    expect(s.successPercent, 85);
    expect(s.canFinish, isTrue);
    expect(s.isFinished, isFalse);
    expect(s.pendingExtraTasks, greaterThan(0));
    s.submit(answer: 'wrong', correct: false);
    expect(s.successPercent, 80);
    expect(s.canFinish, isFalse);
    expect(() => s.finish(), throwsStateError);
    expect(s.isFinished, isFalse);
  });

  test('denominator is 22 from zero, then only the last 22 attempts count', () {
    final s = session(blocks: 1, minimum: 100);
    expect(s.successPercent, 0);
    expect(s.attempts, isEmpty);
    for (var i = 1; i <= 22; i++) {
      final correct = i != 2;
      s.submit(answer: 'fixture', correct: correct);
      final correctCount = i == 1 ? 1 : i - 1;
      expect(s.successPercent, closeTo(correctCount * 100 / 22, .000001));
      expect(s.attempts.length, i);
      expect(s.usesInput, i > 17);
      s.advance();
    }
    expect(s.recentAttempts.length, 22);
    // The first correct answer leaves the window.
    s.submit(answer: 'fixture', correct: false);
    expect(s.successPercent, closeTo(20 * 100 / 22, .000001));
    expect(s.recentAttempts.length, 22);
    s.advance();
    // The original incorrect answer now leaves; a correct one replaces it.
    s.submit(answer: 'fixture', correct: true);
    expect(s.successPercent, closeTo(21 * 100 / 22, .000001));
    expect(s.attempts.where((a) => !a.correct).length, 2);
  });

  test('input starts at exact 70%, task format stays fixed until advance', () {
    final s = session(blocks: 22, minimum: 100, window: 10);
    expect(s.usesInput, isFalse);
    for (final correct in [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
    ]) {
      final format = s.usesInput;
      s.submit(answer: 'fixture', correct: correct);
      expect(s.usesInput, format);
      s.advance();
    }
    expect(s.successPercent, 70);
    expect(s.usesInput, isTrue);
    s.submit(answer: 'fixture', correct: false);
    expect(s.successPercent, 60);
    expect(s.usesInput, isTrue);
    s.advance();
    expect(s.usesInput, isFalse);
  });

  test('22 correct initial answers cover 22 blocks and pass', () {
    final s = session();
    for (var i = 0; i < 22; i++) {
      expect(s.currentBlock.id, 'block-$i');
      s.submit(answer: 'fixture', correct: true);
      expect(s.canFinish, i >= 18);
      if (i < 21) s.advance();
    }
    expect(s.successPercent, 100);
    expect(s.attempts.length, 22);
    expect(s.isFinished, isFalse);
    s.finish();
    expect(s.isFinished, isTrue);
    expect(() => s.advance(), throwsStateError);
    expect(() => s.submit(answer: 'fixture', correct: true), throwsStateError);
  });

  test('error inserts exactly two distinct source tasks of the same block', () {
    final s = session();
    final firstId = s.currentTask.id;
    s.submit(answer: 'wrong', correct: false);
    expect(s.pendingExtraTasks, 2);
    s.advance();
    expect(s.currentBlock.id, 'block-0');
    expect(s.currentTask.id, isNot(firstId));
    expect(s.currentIsExtra, isTrue);
    s.submit(answer: 'fixture', correct: true);
    expect(s.pendingExtraTasks, 1);
    s.advance();
    expect(s.currentTask.id, 'task-0-2');
    s.submit(answer: 'fixture', correct: true);
    s.advance();
    expect(s.currentBlock.id, 'block-1');
    expect(s.currentIsExtra, isFalse);
  });

  test(
    'new remedial errors add two; three consecutive errors request detail',
    () {
      final s = session();
      for (var i = 0; i < 3; i++) {
        s.submit(answer: 'wrong', correct: false);
        expect(s.pendingExtraTasks, i + 2);
        if (i < 2) s.advance();
      }
      expect(s.needsDetailedExplanation, isTrue);
      s.advance();
      s.submit(answer: 'fixture', correct: true);
      expect(s.currentBlockErrorStreak, 0);
      expect(s.needsDetailedExplanation, isFalse);
    },
  );

  test(
    'window excludes older answers, counts extras and uses exact threshold',
    () {
      final s = session(blocks: 1);
      final answers = [
        false,
        true,
        true,
        false,
        true,
        true,
        false,
        true,
        true,
        false,
        ...List.filled(12, true),
      ];
      for (var i = 0; i < answers.length; i++) {
        s.submit(answer: 'fixture', correct: answers[i]);
        if (i < answers.length - 1) s.advance();
      }
      expect(s.attempts.length, 22);
      expect(s.successPercent, closeTo(100 * 18 / 22, .00001));
      expect(s.canFinish, isFalse);
      s.advance();
      s.submit(answer: 'fixture', correct: true);
      expect(s.recentAttempts.length, 22);
      expect(s.successPercent, closeTo(100 * 19 / 22, .00001));
      expect(s.canFinish, isTrue);
    },
  );

  test('outstanding extras do not prevent voluntary finish at the target', () {
    final s = session(blocks: 1, minimum: 2, window: 1);
    s.submit(answer: 'wrong', correct: false);
    s.advance();
    s.submit(answer: 'fixture', correct: true);
    expect(s.successPercent, 100);
    expect(s.canFinish, isTrue);
    expect(s.pendingExtraTasks, 1);
    expect(s.isFinished, isFalse);
    s.advance();
    s.submit(answer: 'fixture', correct: true);
    expect(s.canFinish, isTrue);
  });

  test('display/history reads cannot submit or advance an unchecked task', () {
    final s = session();
    expect(() => s.advance(), throwsStateError);
    expect(
      () => s.attempts.add(
        TaskAttempt(
          task: s.currentTask,
          blockId: s.currentBlock.id,
          answer: '',
          correct: true,
          isExtra: false,
        ),
      ),
      throwsUnsupportedError,
    );
    expect(s.attempts, isEmpty);
  });

  test('duplicate IDs across blocks are rejected', () {
    final bank = fixtureBank(2);
    expect(
      () => TaskBank(
        topicId: 'test',
        title: 'Test',
        blocks: [bank.blocks.first, bank.blocks.first],
      ),
      throwsFormatException,
    );
    expect(
      () => PracticeSettings(
        minimumAnswers: 0,
        successWindow: 22,
        passPercent: 85,
        extraTasksPerError: 2,
      ),
      throwsArgumentError,
    );
  });
}
