import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/main.dart';
import 'package:math_trainer/practice/answer_choices.dart';
import 'package:math_trainer/practice/generated_practice_home.dart';
import 'package:math_trainer/practice/generated_session.dart';

void main() {
  final source = File('bank/templates/common_factor.json').readAsStringSync();
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
  GeneratedSession progressed(String family) {
    final s = GeneratedSession.start(
      family: family,
      source: source,
      id: 'old-$family',
      seed: 7,
    );
    for (var i = 0; i < 7; i++) {
      s.practice.submit(
        answer: s.practice.currentTask.expectedAnswer,
        correct: true,
      );
      s.practice.advance();
    }
    return s;
  }

  for (final size in [const Size(390, 844), const Size(1366, 768)]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        'reset confirms, clears all sessions and restarts choices $size $theme',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var stored = encodeGeneratedSessions([
            progressed('numeric'),
            progressed('literal'),
          ]);
          final original = stored;
          Future<void> mount() async {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpWidget(
              MathTrainerApp(
                themeMode: theme,
                home: GeneratedPracticeHome(
                  allowHistoryReset: true,
                  readText: (_) async => source,
                  readHistory: () => stored,
                  writeHistory: (s) => stored = s,
                ),
              ),
            );
            await tester.pumpAndSettle();
          }

          await mount();
          await tester.tap(find.byKey(const ValueKey('reset-history-action')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('reset-history-cancel')));
          await tester.pumpAndSettle();
          expect(stored, original);
          await tester.tap(find.byKey(const ValueKey('topic-0')));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('bank-answer')), findsOneWidget);
          await tester.tap(find.text('К темам'));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('reset-history-action')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('reset-history-confirm')));
          await tester.pumpAndSettle();
          expect(decodeGeneratedSessions(stored), isEmpty);
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('topic-percent-0')))
                .data,
            '0%',
          );
          await mount();
          expect(decodeGeneratedSessions(stored), isEmpty);
          await tester.tap(find.byKey(const ValueKey('topic-0')));
          await tester.pumpAndSettle();
          final fresh = decodeGeneratedSessions(stored).single;
          expect(fresh.id, isNot('old-numeric'));
          expect(fresh.practice.attempts, isEmpty);
          expect(fresh.practice.successPercent, 0);
          expect(fresh.practice.usesInput, isFalse);
          expect(find.byKey(const ValueKey('bank-answer')), findsNothing);
          final index = answerChoices(fresh.practice.currentTask)
              .indexOf(fresh.practice.currentTask.expectedAnswer);
          final choice = find.byKey(ValueKey('bank-choice-$index'));
          await tester.ensureVisible(choice);
          await tester.tap(choice);
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('bank-primary')));
          await tester.pumpAndSettle();
          expect(
            decodeGeneratedSessions(stored).single.practice.successPercent,
            10,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'failed reset preserves history; explicit reset can recover corrupt storage',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var stored = encodeGeneratedSessions([progressed('numeric')]);
      final original = stored;
      var fail = true;
      Future<void> mount() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MathTrainerApp(
            home: GeneratedPracticeHome(
              allowHistoryReset: true,
              readText: (_) async => source,
              readHistory: () => stored,
              writeHistory: (s) {
                if (fail) throw StateError('denied');
                stored = s;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> confirm() async {
        await tester.tap(find.byKey(const ValueKey('reset-history-action')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('reset-history-confirm')));
        await tester.pumpAndSettle();
      }

      await mount();
      await confirm();
      expect(stored, original);
      expect(find.textContaining('Данные не удалены'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('topic-percent-0'))).data,
        '70%',
      );
      stored = '{broken';
      fail = false;
      await mount();
      await confirm();
      expect(decodeGeneratedSessions(stored), isEmpty);
      expect(find.textContaining('Она не перезаписана'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('topic-0')));
      await tester.pumpAndSettle();
      expect(decodeGeneratedSessions(stored), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('reset is hidden unless the preview option is enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MathTrainerApp(
        home: GeneratedPracticeHome(
          readText: (_) async => source,
          readHistory: () => null,
          writeHistory: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reset-history-action')), findsNothing);
  });
}
