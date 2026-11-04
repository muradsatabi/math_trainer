import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/bank/task_bank.dart';
import 'package:math_trainer/bank/factor_answer_checker.dart';
import 'package:math_trainer/bank_trainer.dart';
import 'package:math_trainer/main.dart';
import 'package:math_trainer/practice/answer_choices.dart';
import 'package:math_trainer/practice/practice_session.dart';

BankTask task(String id, {bool complete = true}) => withDemoChoices(
  BankTask(
    id: id,
    revision: 1,
    instruction: 'Вынеси общий множитель полностью',
    expression: '6a+6b',
    expectedAnswer: '6(a+b)',
    acceptedExamples: const [],
    methodicalStatus: 'generated',
    templateId: 'probe',
    requireCompleteFactor: complete,
  ),
);
PracticeSession practice({bool input = false}) => PracticeSession(
  bank: TaskBank(
    topicId: 'numeric_common_factor',
    title: 'Общий множитель',
    blocks: [
      BankBlock(
        id: 'probe',
        title: 'Проба',
        skill: 'Общий множитель',
        sourceSectionId: 'numeric',
        tasks: [for (var i = 0; i < 12; i++) task('probe-$i')],
      ),
    ],
  ),
  settings: PracticeSettings(
    minimumAnswers: 10,
    successWindow: 10,
    passPercent: 85,
    extraTasksPerError: 2,
    inputPercent: input ? 0 : 100,
  ),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in ['Carlito', 'Caladea', 'MaterialIcons']) {
      final data = font == 'MaterialIcons'
          ? rootBundle.load('fonts/MaterialIcons-Regular.otf')
          : Future.value(
              ByteData.sublistView(
                File('assets/fonts/$font-Regular.ttf').readAsBytesSync(),
              ),
            );
      await (FontLoader(font)..addFont(data)).load();
    }
  });
  test('partial form is equivalent but distinct from error, syntax and completed factor', () {
    final t = task('probe');
    for (final answer in ['3(2a+2b)', '(2a+2b)*3', '2*(3a+3b)']) {
      expect(checkFactorAnswer(t, answer), AnswerVerdict.partial);
    }
    for (final answer in ['6(a+b)', '(b+a)·6', '3*2*(a+b)']) {
      expect(checkFactorAnswer(t, answer), AnswerVerdict.correct);
    }
    expect(checkFactorAnswer(t, '3(2a+b)'), AnswerVerdict.incorrect);
    expect(checkFactorAnswer(t, '1(6a+6b)'), AnswerVerdict.incorrect);
    expect(checkFactorAnswer(t, '3(2a+2b'), AnswerVerdict.incomplete);
    expect(checkFactorAnswer(t, 'a/2'), AnswerVerdict.unsupported);
    expect(
      checkFactorAnswer(task('old', complete: false), '3(2a+2b)'),
      AnswerVerdict.unsupported,
    );
    final literal = BankTask(
      id: 'literal',
      revision: 1,
      instruction: 'Вынеси полностью',
      expression: '12a²+18ab',
      expectedAnswer: '6a(2a+3b)',
      acceptedExamples: const [],
      methodicalStatus: 'generated',
      templateId: 'literal',
      requireCompleteFactor: true,
    );
    expect(checkFactorAnswer(literal, '3a(4a+6b)'), AnswerVerdict.partial);
    expect(checkFactorAnswer(literal, '6(2a²+3ab)'), AnswerVerdict.partial);
    expect(checkFactorAnswer(literal, 'a(12a+18b)'), AnswerVerdict.partial);
    expect(checkFactorAnswer(literal, '(2a+3b)*6a'), AnswerVerdict.correct);
  });
  test('10k + 10d has comparable complete/partial pairs', () {
    final t = withPartialFollowupChoice(
      BankTask(
        id: 'pair',
        revision: 1,
        instruction: 'Вынеси полностью',
        expression: '10k+10d',
        expectedAnswer: '10(k+d)',
        acceptedExamples: const [],
        methodicalStatus: 'generated',
        templateId: 'pair',
        requireCompleteFactor: true,
      ),
      'pair',
    );
    final choices = t.demoChoices!;
    expect(choices.map((c) => c.answer.replaceAll(' ', '')).toSet(), {
      '10(k+d)',
      '10(k+10d)',
      '2(5k+5d)',
      '2(5k+10d)',
    });
    expect(choices, hasLength(4));
    expect(
      choices.where(
        (c) => checkFactorAnswer(t, c.answer) == AnswerVerdict.correct,
      ),
      hasLength(1),
    );
    expect(choices.where((c) => c.isPartial), hasLength(1));
    final errors = choices.where((c) => c.errorId != null).toList();
    expect(errors, hasLength(2));
    expect(
      errors.map((c) => c.answer).where((a) => a.startsWith('2(')),
      hasLength(1),
    );
    expect(
      errors.map((c) => c.answer).where((a) => a.startsWith('10(')),
      hasLength(1),
    );
    for (final c in choices) {
      expect(
        checkFactorAnswer(t, c.answer),
        c.isPartial
            ? AnswerVerdict.partial
            : c.errorId == null
            ? AnswerVerdict.correct
            : AnswerVerdict.incorrect,
      );
    }
  });
  test('neutral history preserves denominator, error streak and reinforcement on reload', () {
    var s = practice();
    s.submit(answer: '0', correct: false);
    s.advance();
    final debt = s.pendingExtraTasks;
    s.submit(answer: '3(2a+2b)', correct: false, partial: true);
    expect(s.successPercent, 0);
    expect(s.pendingExtraTasks, debt);
    expect(s.currentBlockErrorStreak, 1);
    expect(s.gradedAttempts.length, 1);
    s = PracticeSession.fromJson(jsonDecode(jsonEncode(s.toJson())));
    expect(s.attempts.last.partial, isTrue);
    s.advance();
    expect(s.currentBlock.id, 'probe');
    s.submit(answer: s.currentTask.expectedAnswer, correct: true);
    s.advance();
    s.submit(answer: '3(2a+2b)', correct: false, partial: true);
    s.advance();
    expect(s.successPercent, 10);
    expect(s.pendingExtraTasks, 1);
    s.submit(answer: s.currentTask.expectedAnswer, correct: true);
    expect(s.pendingExtraTasks, 0);
    expect(s.successPercent, 20);
    expect(s.attempts.where((a) => !a.correct && !a.partial).length, 1);
  });
  test('partial initial answer repeats the same block and preserves choices in snapshot', () {
    var s = practice();
    final before = s.currentTask.id;
    s.submit(answer: '3(2a+2b)', correct: false, partial: true);
    expect(s.initialBlocksAnswered, 0);
    expect(s.canFinish, isFalse);
    s = PracticeSession.fromJson(jsonDecode(jsonEncode(s.toJson())));
    s.advance();
    expect(s.currentTask.id, isNot(before));
    expect(s.currentBlock.id, 'probe');
    expect(s.currentTask.demoChoices!.any((c) => c.isPartial), isTrue);
    expect(s.currentTask.id, contains('/partial-followup-'));
    s = PracticeSession.fromJson(jsonDecode(jsonEncode(s.toJson())));
    expect(s.currentTask.demoChoices!.any((c) => c.isPartial), isTrue);
    for (final t in s.bank.blocks.single.tasks) {
      for (final c in t.demoChoices!.where((c) => c.isPartial)) {
        expect(c.errorId, isNull);
        expect(checkFactorAnswer(t, c.answer), AnswerVerdict.partial);
        expect(c.hint, isNotEmpty);
      }
    }
    expect(
      s.bank.blocks.single.tasks
          .expand((t) => t.demoChoices!)
          .where((c) => c.isPartial),
      isNotEmpty,
    );
  });
  test('partial preserves scored window and legacy history', () {
    final s = practice();
    for (var i = 0; i < 9; i++) {
      s.submit(answer: s.currentTask.expectedAnswer, correct: true);
      s.advance();
    }
    s.submit(answer: '3(2a+2b)', correct: false, partial: true);
    expect(s.successPercent, 90);
    expect(s.canFinish, isTrue);
    expect(s.recentAttempts.length, 9);
    final old = practice();
    old.submit(answer: old.currentTask.expectedAnswer, correct: true);
    final json = old.toJson()..['schema_version'] = 1;
    final restored = PracticeSession.fromJson(json);
    expect(restored.successPercent, 10);
    expect(restored.attempts.single.partial, isFalse);
    expect(restored.toJson()['schema_version'], 2);
    final conflicting = s.toJson();
    (conflicting['attempts'] as List).last['correct'] = true;
    expect(() => PracticeSession.fromJson(conflicting), throwsFormatException);
  });
  for (final size in [
    const Size(1920, 1080),
    const Size(1366, 768),
    const Size(390, 844),
  ]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      for (final input in [false, true]) {
        testWidgets(
          'yellow result, panel help and neutral history $size $theme $input',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            var s = practice(input: input);
            // Start at a task whose saved alternatives include a neutral option.
            while (!s.currentTask.demoChoices!.any((c) => c.isPartial)) {
              s.submit(answer: s.currentTask.expectedAnswer, correct: true);
              s.advance();
            }
            final score = s.successPercent;
            final original = s.currentTask;
            final partial = original.demoChoices!.singleWhere(
              (c) => c.isPartial,
            );
            Map<String, dynamic>? view;
            final captureKey = GlobalKey();
            Future<void> capture(String stage) async {
              if (input) return;
              final boundary =
                  captureKey.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              await tester.runAsync(() async {
                final shot = await boundary.toImage(pixelRatio: 1);
                final bytes = await shot.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                File(
                  '.dart_tool/help-${size.width.toInt()}-${theme.name}-$stage.png',
                ).writeAsBytesSync(bytes!.buffer.asUint8List());
                shot.dispose();
              });
            }

            Future<void> mount() async {
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pumpWidget(
                RepaintBoundary(
                  key: captureKey,
                  child: MathTrainerApp(
                    themeMode: theme,
                    home: BankTrainer(
                      initialSession: s,
                      initialView: view,
                      onSave: (value) => view = value,
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
            }

            await mount();
            expect(find.byKey(const ValueKey('bank-error-hint')), findsNothing);
            expect(find.byKey(const ValueKey('bank-open-hint')), findsNothing);
            expect(
              find.byKey(const ValueKey('bank-reveal-answer')),
              findsNothing,
            );
            if (input) {
              await tester.enterText(
                find.byKey(const ValueKey('bank-answer')),
                partial.answer,
              );
            } else {
              final index = answerChoices(original).indexOf(partial.answer);
              await tester.ensureVisible(
                find.byKey(ValueKey('bank-choice-$index')),
              );
              await tester.tap(find.byKey(ValueKey('bank-choice-$index')));
            }
            await tester.pump();
            await tester.tap(find.byKey(const ValueKey('bank-primary')));
            await tester.pumpAndSettle();
            expect(find.text('Верно, но не до конца'), findsOneWidget);
            expect(s.successPercent, score);
            expect(s.attempts.last.partial, isTrue);
            expect(
              find.byKey(const ValueKey('bank-reveal-answer')),
              findsNothing,
            );
            expect(tester.takeException(), isNull);
            s = PracticeSession.fromJson(jsonDecode(jsonEncode(s.toJson())));
            await mount();
            expect(find.text('Верно, но не до конца'), findsOneWidget);
            await tester.tap(find.byKey(const ValueKey('bank-primary')));
            await tester.pumpAndSettle();
            expect(s.currentBlock.id, 'probe');
            expect(s.currentTask.id, isNot(original.id));
            final wrong = answerChoices(s.currentTask).firstWhere(
              (a) =>
                  checkFactorAnswer(s.currentTask, a) ==
                  AnswerVerdict.incorrect,
            );
            if (input) {
              await tester.enterText(
                find.byKey(const ValueKey('bank-answer')),
                wrong,
              );
            } else {
              final index = answerChoices(s.currentTask).indexOf(wrong);
              await tester.ensureVisible(
                find.byKey(ValueKey('bank-choice-$index')),
              );
              await tester.tap(find.byKey(ValueKey('bank-choice-$index')));
            }
            await tester.pump();
            await tester.tap(find.byKey(const ValueKey('bank-primary')));
            await tester.pumpAndSettle();
            final hint = find.byKey(const ValueKey('bank-error-hint'));
            final openHint = find.byKey(const ValueKey('bank-open-hint'));
            expect(hint, findsNothing);
            expect(openHint, findsOneWidget);
            expect(view!['current']['show_answer'], isFalse);
            await capture('hidden');
            if (!input) {
              await tester.ensureVisible(openHint);
              await tester.tap(openHint);
              await tester.pumpAndSettle();
              expect(hint, findsOneWidget);
              expect(view!['current']['show_answer'], isFalse);
              s = PracticeSession.fromJson(jsonDecode(jsonEncode(s.toJson())));
              await mount();
              expect(hint, findsOneWidget);
              await capture('hint');
            }
            final reveal = find.byKey(const ValueKey('bank-reveal-answer'));
            await tester.ensureVisible(reveal);
            await tester.pumpAndSettle();
            expect(
              (Offset.zero & size).contains(tester.getRect(reveal).center),
              isTrue,
            );
            expect(
              find.descendant(
                of: find.byKey(const ValueKey('bank-feedback-panel')),
                matching: reveal,
              ),
              findsOneWidget,
            );
            if (size.width >= 720) {
              final panel = tester.getRect(
                find.byKey(const ValueKey('bank-feedback-panel')),
              );
              expect(
                tester.getRect(reveal).bottom,
                closeTo(panel.bottom - 24, 1),
              );
              expect(
                tester.getRect(reveal).width,
                closeTo(panel.width - 48, 1),
              );
            }
            final graded = s.gradedAttempts.length;
            await tester.tap(reveal);
            await tester.pumpAndSettle();
            expect(s.gradedAttempts.length, graded);
            expect(view!['current']['show_answer'], isTrue);
            await capture('answer');
            if (input) {
              expect(hint, findsNothing);
              expect(openHint, findsOneWidget);
            }
            if (input) {
              expect(
                find.byKey(const ValueKey('bank-revealed-answer')),
                findsOneWidget,
              );
              expect(
                tester
                    .widget<TextField>(
                      find.byKey(const ValueKey('bank-answer')),
                    )
                    .controller!
                    .text,
                wrong,
              );
            } else {
              final index = answerChoices(s.currentTask)
                  .indexOf(s.currentTask.expectedAnswer);
              expect(
                find.descendant(
                  of: find.byKey(ValueKey('bank-choice-$index')),
                  matching: find.byIcon(Icons.check),
                ),
                findsOneWidget,
              );
            }
            await tester.tap(find.byKey(const ValueKey('bank-primary')));
            await tester.pumpAndSettle();
            expect(hint, findsNothing);
            expect(openHint, findsNothing);
            final previous = find.widgetWithText(
              OutlinedButton,
              'Предыдущее задание',
            );
            await tester.ensureVisible(previous);
            await tester.tap(previous);
            await tester.pumpAndSettle();
            expect(view!['current']['show_answer'], isTrue);
            expect(hint, input ? findsNothing : findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
