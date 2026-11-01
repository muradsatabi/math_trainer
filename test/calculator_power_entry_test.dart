import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/bank_trainer.dart';
import 'package:math_trainer/main.dart';
import 'package:math_trainer/practice/answer_keyboard.dart';
import 'package:math_trainer/practice/generated_session.dart';
import 'package:math_trainer/practice/practice_session.dart';

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
  for (final size in [const Size(1366, 768), const Size(390, 844)]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        'calculator superscripts, mode and draft restoration $size $theme',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final generated = GeneratedSession.start(
            family: 'numeric',
            source: File('bank/templates/common_factor.json')
                .readAsStringSync(),
            id: 'power',
            seed: 5,
          );
          final session = PracticeSession(
            bank: generated.practice.bank,
            settings: PracticeSettings(
              minimumAnswers: 10,
              successWindow: 10,
              passPercent: 85,
              extraTasksPerError: 2,
              inputPercent: 0,
            ),
          );
          Map<String, dynamic>? view;
          Future<void> mount(Map<String, dynamic>? initialView) async {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpWidget(
              MathTrainerApp(
                themeMode: theme,
                home: BankTrainer(
                  initialSession: session,
                  initialView: initialView,
                  onSave: (saved) => view = saved,
                ),
              ),
            );
            await tester.pumpAndSettle();
          }

          await mount(null);
          final field = find.byKey(const ValueKey('bank-answer'));
          final power = find.byKey(const ValueKey('bank-symbol-^'));
          final check = find.descendant(
            of: find.byKey(const ValueKey('bank-primary')),
            matching: find.byType(FilledButton),
          );
          expect(
            find.descendant(of: power, matching: find.text('x')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: power, matching: find.text('y')),
            findsOneWidget,
          );
          expect(find.text('x²'), findsNothing);
          expect(tester.widget<OutlinedButton>(power).onPressed, isNull);
          await tester.enterText(field, '2');
          await tester.pump();
          await tester.ensureVisible(power);
          await tester.tap(power);
          await tester.pumpAndSettle();
          expect(tester.widget<FilledButton>(check).onPressed, isNull);
          expect(view!['current']['power_input'], isTrue);
          await mount(view);
          expect(
            tester
                .widget<AnswerKeyboard>(find.byType(AnswerKeyboard))
                .powerInput,
            isTrue,
          );
          await tester.ensureVisible(power);
          await tester.tap(find.byKey(const ValueKey('bank-symbol-3')));
          await tester.pumpAndSettle();
          expect(tester.widget<TextField>(field).controller!.text, '2³');
          expect(tester.widget<FilledButton>(check).onPressed, isNotNull);
          await tester.tap(find.byKey(const ValueKey('bank-symbol-+')));
          await tester.tap(find.byKey(const ValueKey('bank-symbol-4')));
          await tester.pumpAndSettle();
          expect(tester.widget<TextField>(field).controller!.text, '2³+4');
          expect(
            tester
                .widget<AnswerKeyboard>(find.byType(AnswerKeyboard))
                .powerInput,
            isFalse,
          );
          await tester.tap(find.byKey(const ValueKey('bank-clear')));
          await tester.pumpAndSettle();
          await tester.enterText(field, 'a');
          await tester.pump();
          await tester.tap(power);
          await tester.pump();
          await tester.enterText(field, 'a10');
          await tester.pumpAndSettle();
          expect(tester.widget<TextField>(field).controller!.text, 'a¹⁰');
          await tester.tap(power);
          await tester.pump();
          expect(
            tester
                .widget<AnswerKeyboard>(find.byType(AnswerKeyboard))
                .powerInput,
            isFalse,
          );
          final oldView = Map<String, dynamic>.from(view!);
          oldView['current'] = {
            'text': '2^3',
            'base': 3,
            'extent': 3,
            'message': null,
            'show_answer': false,
          };
          await mount(oldView);
          expect(tester.widget<TextField>(field).controller!.text, '2³');
          await tester.enterText(field, session.currentTask.expectedAnswer);
          await tester.pumpAndSettle();
          await tester.tap(check);
          await tester.pumpAndSettle();
          expect(find.text('Абсолютно верно!'), findsOneWidget);
          expect(tester.widget<OutlinedButton>(power).onPressed, isNull);
          expect(session.attempts.length, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
