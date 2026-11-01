import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/main.dart';
import 'package:math_trainer/practice/generated_practice_home.dart';
import 'package:math_trainer/practice/generated_session.dart';
import 'package:math_trainer/practice/answer_choices.dart';
import 'package:math_trainer/bank/factor_answer_checker.dart';
import 'package:math_trainer/generator/task_generator.dart';
import 'package:math_trainer/generator/worksheet_test_choices.dart';
import 'package:math_trainer/generator/pdf_generator_screen.dart';
import 'package:math_trainer/generator/worksheet_pdf.dart';
import 'package:math_trainer/bank/task_bank.dart';

void main() {
  test('expansion must finish every bracket and combine repeated factors', () {
    BankTask task(String expression, String answer) => BankTask(
      id: 'form',
      revision: 1,
      instruction: 'Раскрой скобки',
      expression: expression,
      expectedAnswer: answer,
      acceptedExamples: const [],
      methodicalStatus: 'generated',
      templateId: 'form',
      operation: 'expand',
    );
    final three = task('2(a+b+c)', '2a+2b+2c');
    expect(checkFactorAnswer(three, '2(a+b)+2c'), AnswerVerdict.incorrect);
    expect(checkFactorAnswer(three, '2((a+b+c))'), AnswerVerdict.incorrect);
    expect(
      checkFactorAnswer(task('a(a+b)', 'a²+ab'), 'a*a+ab'),
      AnswerVerdict.incorrect,
    );
    expect(
      checkFactorAnswer(task('2(2a+b)', '4a+2b'), '2*2a+2b'),
      AnswerVerdict.incorrect,
    );
    expect(
      checkFactorAnswer(task('−(a+b)', '−a−b'), '−(a+b)'),
      AnswerVerdict.incorrect,
    );
    expect(checkFactorAnswer(three, '2c+2a+2b'), AnswerVerdict.correct);
  });
  for (final family in ['numeric_bracket', 'literal_bracket']) {
    final source = File(generatedTemplatePath(family)).readAsStringSync();
    test(
      'approved $family templates generate supported, reproducible practice and PDF',
      () async {
        final templates = loadTemplates(source);
        expect(
          templates.where((t) => t.active),
          hasLength(family == 'numeric_bracket' ? 12 : 17),
        );
        expect(templates.every((t) => t.flat), isTrue);
        for (var seed = 0; seed < 4; seed++) {
          final s = GeneratedSession.start(
            family: family,
            source: source,
            id: 'fixture-$family',
            seed: seed,
          );
          for (final task in s.practice.bank.blocks.expand((b) => b.tasks)) {
            expect(
              checkFactorAnswer(task, task.expectedAnswer),
              AnswerVerdict.correct,
              reason: task.expression,
            );
            expect(
              checkFactorAnswer(task, task.expression),
              AnswerVerdict.incorrect,
            );
            expect(
              task.demoChoices,
              hasLength(4),
              reason: '${task.expression} → ${task.expectedAnswer}',
            );
            for (final choice in task.demoChoices!.where(
              (c) => c.errorId != null,
            )) {
              expect(
                checkFactorAnswer(task, choice.answer),
                AnswerVerdict.incorrect,
              );
              expect(answerFeedback(task, choice.answer)?.hint, isNotEmpty);
            }
          }
          final restored = GeneratedSession.fromJson(
            jsonDecode(jsonEncode(s.toJson())),
          );
          expect(jsonEncode(restored.toJson()), jsonEncode(s.toJson()));
        }
        final exercises = TemplateTaskGenerator(seed: 1).generate(
          templates: templates,
          quantities: {
            for (final t in templates.where((t) => t.active)) t.id: 2,
          },
        );
        expect(
          worksheetTestItems([exercises]).single,
          hasLength(exercises.length),
        );
        for (final testMode in [false, true]) {
          final bytes = await buildWorksheetPdf(
            exercises: exercises,
            textFont: ByteData.sublistView(
              File('assets/fonts/Carlito-Regular.ttf').readAsBytesSync(),
            ),
            mathFont: ByteData.sublistView(
              File('assets/fonts/Caladea-Regular.ttf').readAsBytesSync(),
            ),
            includeAnswers: true,
            testMode: testMode,
          );
          expect(String.fromCharCodes(bytes.take(4)), '%PDF');
          expect(bytes.length, greaterThan(1000));
        }
      },
    );
    testWidgets('$family opens from topic, checks, saves and restores', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? stored;
      Future<void> mount() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MathTrainerApp(
            home: GeneratedPracticeHome(
              readText: (p) async => File(p).readAsStringSync(),
              readHistory: () => stored,
              writeHistory: (s) => stored = s,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(ValueKey('topic-${family == 'numeric_bracket' ? 2 : 3}')),
        );
        await tester.pumpAndSettle();
      }

      await mount();
      final session = decodeGeneratedSessions(stored!).single;
      final task = session.practice.currentTask;
      expect(task.instruction, 'Раскрой скобки');
      final index = answerChoices(task).indexOf(task.expectedAnswer);
      await tester.ensureVisible(find.byKey(ValueKey('bank-choice-$index')));
      await tester.tap(find.byKey(ValueKey('bank-choice-$index')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bank-primary')));
      await tester.pumpAndSettle();
      expect(find.text('Абсолютно верно!'), findsOneWidget);
      await mount();
      expect(find.text('Абсолютно верно!'), findsOneWidget);
      expect(
        decodeGeneratedSessions(stored!).single.practice.successPercent,
        10,
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets('$family PDF uses its own templates without invented levels', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MathTrainerApp(
          home: GeneratedPracticeHome(
            readText: (p) async => File(p).readAsStringSync(),
            readHistory: () => null,
            writeHistory: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          ValueKey('pdf-topic-${family == 'numeric_bracket' ? 2 : 3}'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PdfGeneratorScreen), findsOneWidget);
      expect(find.text(generatedTopicTitles[family]!), findsOneWidget);
      expect(find.text('Уровни сочетаний'), findsNothing);
      expect(
        find.byKey(
          ValueKey(
            'row-${family == 'numeric_bracket' ? 'numeric' : 'literal'}_bracket_multiplication_tpl_001',
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
