import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/bank/task_bank.dart';
import 'package:math_trainer/demo_screens.dart';
import 'package:math_trainer/main.dart';
import 'package:math_trainer/practice/answer_keyboard.dart';

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('ten success bands and shared badge/bar color: $mode', (
      tester,
    ) async {
      await tester.pumpWidget(MathTrainerApp(themeMode: mode));
      final context = tester.element(find.byType(TopicsScreen));
      final colors = ScreenColors(context);
      final palette = List.generate(10, (i) => colors.successFill(i * 10));
      expect(palette.toSet(), hasLength(10));
      for (var percent = 0; percent <= 100; percent++) {
        expect(
          colors.successFill(percent),
          palette[(percent ~/ 10).clamp(0, 9)],
        );
      }
      expect(colors.successFill(-1), palette.first);
      expect(colors.successFill(101), palette.last);
      await tester.pumpWidget(
        MathTrainerApp(
          themeMode: mode,
          home: const TopicsScreen(successes: [0, 25, 75, 100]),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        final card = find.byKey(ValueKey('topic-$i'));
        final bar = tester.widget<LinearProgressIndicator>(
          find.descendant(
            of: card,
            matching: find.byType(LinearProgressIndicator),
          ),
        );
        final badge = find.descendant(
          of: card,
          matching: find.byType(TopicStateBadge),
        );
        expect(
          tester
              .widget<Icon>(
                find.descendant(of: badge, matching: find.byType(Icon)),
              )
              .color,
          bar.color,
        );
        if (i == 0) expect(bar.value, 0);
      }
    });
  }

  testWidgets(
    'all bank answers have digits immediately; letters allow mistakes',
    (tester) async {
      final bank = await TaskBank.load(
        'bank/manifest.json',
        (p) async => File(p).readAsStringSync(),
      );
      for (final task in bank.blocks.expand((b) => b.tasks)) {
        final letters = RegExp('[a-zA-Z]')
            .allMatches(task.expression)
            .map((m) => m[0]!)
            .toSet();
        final digits = RegExp('[0-9]')
            .allMatches(task.expectedAnswer)
            .map((m) => m[0]!)
            .toSet();
        String? inserted;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnswerKeyboard(
                key: ValueKey(task.id),
                letters: letters.toList(),
                requiredDigits: digits.toList(),
                enabled: true,
                compact: true,
                onInsert: (s) => inserted = s,
              ),
            ),
          ),
        );
        for (final symbol in {...digits, ...letters}) {
          expect(
            find.byKey(ValueKey('bank-symbol-$symbol')),
            findsOneWidget,
            reason: task.id,
          );
        }
        final letterGroup = find.byKey(const ValueKey('bank-key-group-Буквы'));
        final buttons = tester.widgetList<OutlinedButton>(
          find.descendant(
            of: letterGroup,
            matching: find.byType(OutlinedButton),
          ),
        );
        expect(
          buttons.where((b) => b.onPressed != null).length,
          greaterThan(letters.length),
          reason: task.id,
        );
        if (task.id == 'ВМ-001') {
          await tester.tap(find.byKey(const ValueKey('bank-symbol-7')));
          expect(inserted, '7');
          await tester.tap(find.text('Другие числа'));
          await tester.pump();
          expect(find.byKey(const ValueKey('bank-symbol-0')), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
}
