import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/bank/factor_answer_checker.dart';
import 'package:math_trainer/main.dart';
import 'package:math_trainer/practice/demo_topic_lesson.dart';
import 'package:math_trainer/practice/generated_session.dart';
import 'package:math_trainer/practice/required_explanation_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in ['Carlito', 'Caladea']) {
      final loader = FontLoader(family)
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File('assets/fonts/$family-Regular.ttf').readAsBytesSync(),
            ),
          ),
        );
      await loader.load();
    }
  });
  test('all supported worked equalities in the lesson copy are exact', () {
    var checked = 0;
    for (final lesson in [
      DemoTopicLesson.numericFactor,
      DemoTopicLesson.literalFactor,
      DemoTopicLesson.numericExpansion,
      DemoTopicLesson.literalExpansion,
    ]) {
      for (final section in lesson.sections) {
        String? previous;
        for (final line in (section.formula ?? '').split('\n')) {
          if (!line.contains('=') || line.contains('…') || line.contains(':')) {
            continue;
          }
          final parts = line.split('=').map((s) => s.trim()).toList();
          if (parts.first.isEmpty) {
            if (previous == null) fail('Missing previous step: $line');
            parts[0] = previous;
          }
          for (var index = 1; index < parts.length; index++) {
            expect(
              equivalentExpressions(parts[index - 1], parts[index]),
              isTrue,
              reason: '${lesson.title}: $line',
            );
            checked++;
          }
          previous = parts.last;
        }
      }
    }
    expect(checked, greaterThan(25));
  });

  for (final family in [
    'numeric',
    'literal',
    'numeric_bracket',
    'literal_bracket',
  ]) {
    for (final size in [const Size(1366, 768), const Size(390, 844)]) {
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('topic lesson scroll and timer: $family $size $theme', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final session = GeneratedSession.start(
            family: family,
            source: File(generatedTemplatePath(family)).readAsStringSync(),
            id: 'lesson-$family',
            seed: 5,
          ).practice;
          final lesson = DemoTopicLesson.forTopic(
            session.bank.topicId,
            session.currentTask.operation,
          );
          var continued = false;
          await tester.pumpWidget(
            MathTrainerApp(
              themeMode: theme,
              home: RequiredExplanationScreen(
                topic: session.bank.title,
                topicId: session.bank.topicId,
                task: session.currentTask,
                skill: session.currentBlock.skill,
                successPercent: 0,
                onContinue: () => continued = true,
                onTopics: () {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(lesson.title), findsOneWidget);
          expect(find.text('Пробное объяснение темы'), findsOneWidget);
          final button = find.descendant(
            of: find.byKey(const ValueKey('bank-explanation-continue')),
            matching: find.byType(FilledButton),
          );
          expect(tester.widget<FilledButton>(button).onPressed, isNull);
          final last = find.text('Теперь вернёмся к твоему заданию');
          await tester.ensureVisible(last);
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.text(session.currentTask.expectedAnswer),
          );
          await tester.pumpAndSettle();
          final bounds = Offset.zero & size;
          expect(bounds.contains(tester.getRect(button).center), isTrue);
          expect(tester.takeException(), isNull);
          await tester.pump(const Duration(seconds: 10));
          expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
          await tester.tap(button);
          expect(continued, isTrue);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
}
