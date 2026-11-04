import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/bank/factor_answer_checker.dart';
import 'package:math_trainer/bank/task_bank.dart';
import 'package:math_trainer/bank_trainer.dart';
import 'package:math_trainer/main.dart';
import 'package:math_trainer/practice/answer_choices.dart';
import 'package:math_trainer/practice/generated_session.dart';

void main() {
  final source = File('bank/templates/common_factor.json').readAsStringSync();
  GeneratedSession session(String family, int seed) => GeneratedSession.start(
    family: family,
    source: source,
    id: 'demo-$family-$seed',
    seed: seed,
  );
  setUpAll(() async {
    await (FontLoader('Carlito')..addFont(
          Future.value(
            ByteData.sublistView(
              File('assets/fonts/Carlito-Regular.ttf').readAsBytesSync(),
            ),
          ),
        ))
        .load();
  });
  for (final family in ['numeric', 'literal']) {
    test(
      'every active $family template has mapped errors and optional neutral partial choice',
      () {
        for (var seed = 0; seed < 5; seed++) {
          final s = session(family, seed);
          for (final task in s.practice.bank.blocks.expand((b) => b.tasks)) {
            expect(task.demoChoices, hasLength(4), reason: task.expression);
            final errors = task.demoChoices!
                .where((c) => c.errorId != null)
                .toList();
            final partials = task.demoChoices!
                .where((c) => c.isPartial)
                .toList();
            expect(partials.length, lessThanOrEqualTo(1));
            expect(errors, hasLength(3 - partials.length));
            expect(
              errors.map((c) => c.errorId).toSet(),
              hasLength(errors.length),
            );
            expect(errors.map((c) => c.hint).toSet(), hasLength(errors.length));
            for (final partial in partials) {
              expect(partial.errorId, isNull);
              expect(
                equivalentExpressions(partial.answer, task.expression),
                isTrue,
              );
              expect(
                checkFactorAnswer(task, partial.answer),
                AnswerVerdict.partial,
              );
              expect(partial.hint, isNotEmpty);
            }
            for (final error in errors) {
              expect(
                equivalentExpressions(error.answer, task.expression),
                isFalse,
              );
              expect(
                checkFactorAnswer(task, error.answer),
                AnswerVerdict.incorrect,
              );
              expect(answerFeedback(task, error.answer)?.hint, error.hint);
            }
            expect(answerFeedback(task, task.expectedAnswer), isNull);
            expect(answerFeedback(task, '999999'), isNull);
            final restored = BankTask.fromJson(
              jsonDecode(jsonEncode(task.toJson())),
            );
            expect(
              restored.demoChoices!.map((c) => c.toJson()),
              task.demoChoices!.map((c) => c.toJson()),
            );
          }
        }
      },
    );

    test(
      'old $family attempts and draft retain their original alternatives during upgrade',
      () {
        final raw = jsonDecode(
          jsonEncode(session(family, 1).toJson()),
        ) as Map<String, dynamic>;
        for (final block in raw['practice']['bank']['blocks']) {
          for (final task in block['tasks']) {
            task.remove('demo_choices_v1');
          }
        }
        final old = GeneratedSession.fromJson(raw);
        final first = old.practice.currentTask;
        final choices = answerChoices(first);
        old.practice.submit(
          answer: choices.firstWhere((c) => c != first.expectedAnswer),
          correct: false,
        );
        old.practice.advance();
        final draftTask = old.practice.currentTask;
        old.view = {
          'current': {'text': '2('},
        };
        final upgraded = old.withDemoFeedback();
        expect(upgraded.practice.attempts.single.task.demoChoices, isNull);
        expect(answerChoices(upgraded.practice.attempts.single.task), choices);
        expect(upgraded.practice.currentTask.id, draftTask.id);
        expect(upgraded.practice.currentTask.demoChoices, isNull);
        expect(
          upgraded.practice.bank.blocks
              .expand((b) => b.tasks)
              .where((t) => t.demoChoices != null),
          isNotEmpty,
        );
        expect(
          jsonEncode(upgraded.withDemoFeedback().toJson()),
          jsonEncode(upgraded.toJson()),
        );
      },
    );

    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        'different $family choices show their own hint and survive reload $theme',
        (tester) async {
          tester.view.physicalSize = const Size(1366, 768);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final fixture = session(family, 3);
          final task = fixture.practice.currentTask;
          for (final wrong in task.demoChoices!.where(
            (c) => c.errorId != null,
          )) {
            final fresh = GeneratedSession.fromJson(
              jsonDecode(jsonEncode(fixture.toJson())),
            );
            Map<String, dynamic>? saved;
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpWidget(
              MathTrainerApp(
                themeMode: theme,
                home: BankTrainer(
                  initialSession: fresh.practice,
                  onSave: (v) => saved = v,
                ),
              ),
            );
            await tester.pumpAndSettle();
            final index = answerChoices(task).indexOf(wrong.answer);
            await tester.tap(find.byKey(ValueKey('bank-choice-$index')));
            await tester.pump();
            await tester.tap(find.byKey(const ValueKey('bank-primary')));
            await tester.pumpAndSettle();
            expect(find.text(wrong.hint!), findsNothing);
            expect(
              find.byKey(const ValueKey('bank-revealed-answer')),
              findsNothing,
            );
            await tester.tap(find.byKey(const ValueKey('bank-open-hint')));
            await tester.pumpAndSettle();
            expect(saved!['current']['show_hint'], isTrue);
            expect(saved!['current']['show_answer'], isFalse);
            expect(find.text(wrong.hint!), findsOneWidget);
            expect(
              find.text('Подсказка · демонстрационный вариант'),
              findsOneWidget,
            );
            expect(fresh.practice.attempts.single.correct, isFalse);
            final restored = GeneratedSession.fromJson(
              jsonDecode(jsonEncode(fresh.toJson())),
            );
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpWidget(
              MathTrainerApp(
                themeMode: theme,
                home: BankTrainer(
                  initialSession: restored.practice,
                  initialView: saved,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text(wrong.hint!), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
