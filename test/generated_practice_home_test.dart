import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/main.dart';
import 'package:math_trainer/practice/generated_practice_home.dart';
import 'package:math_trainer/practice/generated_session.dart';
import 'package:math_trainer/practice/answer_choices.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Carlito')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/Carlito-Regular.ttf').readAsBytesSync(),
          ),
        ),
      );
    await font.load();
  });
  final source = File('bank/templates/common_factor.json').readAsStringSync();
  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'reload restores actual tasks, scores, history and draft $theme',
      (tester) async {
        tester.view.physicalSize = const Size(1366, 768);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? stored;
        Future<void> mount() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(
            MathTrainerApp(
              themeMode: theme,
              home: GeneratedPracticeHome(
                readText: (p) async {
                  expect(p, 'bank/templates/common_factor.json');
                  return source;
                },
                readHistory: () => stored,
                writeHistory: (s) => stored = s,
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await mount();
        expect(find.byKey(const ValueKey('topic-1')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('topic-0')));
        await tester.pumpAndSettle();
        expect(find.text('Занятия по теме'), findsNothing);
        expect(find.text('История занятий'), findsNothing);
        final initial = decodeGeneratedSessions(stored!).single;
        expect(initial.practice.bank.taskCount, 70);
        for (var i = 0; i < 9; i++) {
          final current = decodeGeneratedSessions(stored!).single.practice;
          if (current.usesInput) {
            await tester.enterText(
              find.byKey(const ValueKey('bank-answer')),
              current.currentTask.expectedAnswer,
            );
          } else {
            final choices = answerChoices(current.currentTask);
            await tester.tap(
              find.byKey(
                ValueKey(
                  'bank-choice-${choices.indexOf(current.currentTask.expectedAnswer)}',
                ),
              ),
            );
          }
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('bank-primary')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Дальше'));
          await tester.pumpAndSettle();
        }
        await tester.enterText(find.byKey(const ValueKey('bank-answer')), '2');
        await tester.pump();
        await tester.ensureVisible(find.byKey(const ValueKey('bank-symbol-^')));
        await tester.tap(find.byKey(const ValueKey('bank-symbol-^')));
        await tester.tap(find.byKey(const ValueKey('bank-symbol-3')));
        await tester.pump();
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('bank-answer')))
              .controller!
              .text,
          '2³',
        );
        await tester.enterText(
          find.byKey(const ValueKey('bank-answer')),
          '2(a',
        );
        await tester.pump();
        await tester.tap(find.text('Предыдущее задание'));
        await tester.pumpAndSettle();
        final before = stored;
        await mount();
        expect(stored, before);
        await tester.tap(find.byKey(const ValueKey('topic-0')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('bank-task-9')), findsOneWidget);
        expect(find.text('90%'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('bank-finish')));
        await tester.pumpAndSettle();
        expect(
          decodeGeneratedSessions(stored!).single.practice.attempts.length,
          9,
        );
        await mount();
        await tester.tap(find.byKey(const ValueKey('topic-0')));
        await tester.pumpAndSettle();
        expect(find.text('Проходной порог достигнут'), findsOneWidget);
        await tester.tap(find.text('Назад к решению'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('bank-return-current')));
        await tester.pumpAndSettle();
        final field = tester.widget<TextField>(
          find.byKey(const ValueKey('bank-answer')),
        );
        expect(field.controller!.text, '2(a');
        expect(field.readOnly, isFalse);
        final restored = decodeGeneratedSessions(stored!).single;
        expect(restored.practice.bank.toJson(), initial.practice.bank.toJson());
        expect(restored.practice.attempts.length, 9);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'topic resumes latest saved practice without creating duplicates',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final latest = GeneratedSession.start(
        family: 'numeric',
        source: source,
        id: 'latest',
        seed: 9,
      );
      final older = GeneratedSession.start(
        family: 'numeric',
        source: source,
        id: 'older',
        seed: 3,
      );
      latest.practice.submit(
        answer: latest.practice.currentTask.expectedAnswer,
        correct: true,
      );
      var stored = encodeGeneratedSessions([latest, older]);
      await tester.pumpWidget(
        MathTrainerApp(
          home: GeneratedPracticeHome(
            readText: (_) async => source,
            readHistory: () => stored,
            writeHistory: (s) => stored = s,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('topic-0')));
      await tester.pumpAndSettle();
      expect(find.text(latest.practice.currentTask.expression), findsOneWidget);
      expect(find.text('10%'), findsOneWidget);
      expect(find.text('История занятий'), findsNothing);
      await tester.tap(find.text('К темам'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('topic-0')));
      await tester.pumpAndSettle();
      final saved = decodeGeneratedSessions(stored);
      expect(saved.map((s) => s.id), ['latest', 'older']);
      expect(saved.first.practice.attempts.length, 1);
      expect(find.text('10%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bad history is preserved; failed writes are explicitly reported',
    (tester) async {
      var writes = 0;
      await tester.pumpWidget(
        MathTrainerApp(
          home: GeneratedPracticeHome(
            readText: (_) async => source,
            readHistory: () => '{broken',
            writeHistory: (_) => writes++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Она не перезаписана'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('topic-0')));
      await tester.pumpAndSettle();
      expect(writes, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MathTrainerApp(
          home: GeneratedPracticeHome(
            readText: (_) async => source,
            readHistory: () => null,
            writeHistory: (_) => throw StateError('quota'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('topic-0')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Не удалось сохранить занятие'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
