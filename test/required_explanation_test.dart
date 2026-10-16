import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/bank/task_bank.dart';
import 'package:math_trainer/bank_trainer.dart';
import 'package:math_trainer/main.dart';
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
  for (final size in [const Size(1366, 768), const Size(390, 844)]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      for (final input in [false, true]) {
        testWidgets(
          'third error requires 10 visible seconds $size $theme $input',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            Future<String> read(String p) async {
              final source = File(p).readAsStringSync();
              if (p != 'bank/manifest.json') return source;
              final manifest = jsonDecode(source) as Map<String, dynamic>;
              manifest['practice']['input_percent'] = input ? 0 : 100;
              return jsonEncode(manifest);
            }

            final bank = await TaskBank.load('bank/manifest.json', read);
            await tester.pumpWidget(
              MathTrainerApp(
                themeMode: theme,
                home: BankTrainer(readText: read),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('topic-0')));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Начать практику'));
            await tester.pumpAndSettle();
            for (var i = 0; i < 3; i++) {
              final task = bank.blocks.first.tasks[i];
              if (input) {
                await tester.enterText(
                  find.byKey(const ValueKey('bank-answer')),
                  '0',
                );
              } else {
                final choices = answerChoices(task);
                final wrong = choices.indexWhere(
                  (a) => a != task.expectedAnswer,
                );
                final choice = find.byKey(ValueKey('bank-choice-$wrong'));
                await tester.ensureVisible(choice);
                await tester.tap(choice);
              }
              await tester.pump();
              await tester.tap(find.byKey(const ValueKey('bank-primary')));
              await tester.pumpAndSettle();
              if (i < 2) {
                expect(
                  find.byKey(const ValueKey('bank-required-explanation')),
                  findsNothing,
                );
                await tester.tap(find.text('Дальше'));
                await tester.pumpAndSettle();
              }
            }
            expect(
              find.byKey(const ValueKey('bank-required-explanation')),
              findsOneWidget,
            );
            expect(find.byKey(const ValueKey('bank-primary')), findsNothing);
            expect(find.byKey(const ValueKey('bank-previous')), findsNothing);
            expect(find.byKey(const ValueKey('bank-finish')), findsNothing);
            expect(find.text('0%'), findsOneWidget);
            final continueButton = find.byKey(
              const ValueKey('bank-explanation-continue'),
            );
            final button = find.descendant(
              of: continueButton,
              matching: find.byType(FilledButton),
            );
            final topics = find.widgetWithText(TextButton, 'К темам');
            expect(tester.widget<FilledButton>(button).onPressed, isNull);
            expect(tester.widget<TextButton>(topics).onPressed, isNull);
            final rect = tester.getRect(continueButton);
            expect((Offset.zero & size).contains(rect.bottomRight), isTrue);
            await tester.tap(button);
            await tester.pump(const Duration(seconds: 9));
            expect(find.text('Продолжить можно через 1 с'), findsOneWidget);
            expect(tester.widget<FilledButton>(button).onPressed, isNull);
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.hidden,
            );
            await tester.pump(const Duration(milliseconds: 20500));
            expect(find.text('Продолжить можно через 1 с'), findsOneWidget);
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
            await tester.pump(const Duration(milliseconds: 500));
            expect(find.text('Продолжить можно через 1 с'), findsOneWidget);
            await tester.pump(const Duration(milliseconds: 500));
            expect(
              find.byKey(const ValueKey('bank-explanation-countdown')),
              findsNothing,
            );
            expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
            await tester.tap(button);
            await tester.pumpAndSettle();
            expect(find.byKey(const ValueKey('bank-task-4')), findsOneWidget);
            expect(
              find.text(bank.blocks.first.tasks[3].expression),
              findsOneWidget,
            );
            await tester.tap(find.text('Предыдущее задание'));
            await tester.pumpAndSettle();
            expect(find.byKey(const ValueKey('bank-task-3')), findsOneWidget);
            expect(
              find.byKey(const ValueKey('bank-required-explanation')),
              findsNothing,
            );
            expect(find.text('0%'), findsOneWidget);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(seconds: 20));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
