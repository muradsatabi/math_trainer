import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/main.dart';
import 'package:math_trainer/demo_screens.dart';
import 'package:math_trainer/bank_trainer.dart';
import 'package:math_trainer/practice/topic_catalog.dart';
import 'package:math_trainer/practice/generated_practice_home.dart';
import 'package:math_trainer/practice/generated_session.dart';
import 'package:math_trainer/practice/answer_choices.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final name in ['Carlito', 'Caladea']) {
      final font = FontLoader(name)
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File('assets/fonts/$name-Regular.ttf').readAsBytesSync(),
            ),
          ),
        );
      await font.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              'D:/Dev/SDK/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytesSync(),
          ),
        ),
      );
    await icons.load();
  });
  for (final size in [
    const Size(1366, 768),
    const Size(1920, 1080),
    const Size(390, 844),
  ]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('generated practice screenshots $size $theme', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? stored;
        final source = File('bank/templates/common_factor.json')
            .readAsStringSync();
        const capture = ValueKey('generated-capture');
        Future<void> mount() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(
            MathTrainerApp(
              themeMode: theme,
              home: RepaintBoundary(
                key: capture,
                child: GeneratedPracticeHome(
                  allowHistoryReset: true,
                  readText: (_) async => source,
                  readHistory: () => stored,
                  writeHistory: (s) => stored = s,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        Future<void> save(String state) async {
          expect(tester.takeException(), isNull);
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(capture),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            final mode = theme == ThemeMode.dark ? 'dark' : 'light';
            await File(
              'docs/verification/generated-$state-$mode-${size.width.toInt()}x${size.height.toInt()}-widget.png',
            ).writeAsBytes(bytes.buffer.asUint8List());
            image.dispose();
          });
        }

        await mount();
        await save('topics');
        await tester.tap(find.byKey(const ValueKey('topic-1')));
        await tester.pumpAndSettle();
        final session = decodeGeneratedSessions(stored!).single;
        expect(session.practice.bank.taskCount, 90);
        await save('task');
        final choices = answerChoices(session.practice.currentTask);
        final choice = find.byKey(
          ValueKey(
            'bank-choice-${choices.indexOf(session.practice.currentTask.expectedAnswer)}',
          ),
        );
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('bank-primary')));
        await tester.pumpAndSettle();
        await mount();
        await tester.tap(find.byKey(const ValueKey('topic-1')));
        await tester.pumpAndSettle();
        await save('topics-restored');
        expect(find.text('10%'), findsOneWidget);
        expect(find.text('Абсолютно верно!'), findsOneWidget);
        await save('restored');
        await tester.tap(find.text('Дальше'));
        await tester.pumpAndSettle();
        for (var index = 1; index < 7; index++) {
          final task = decodeGeneratedSessions(stored!)
              .single
              .practice
              .currentTask;
          final options = answerChoices(task);
          final correct = find.byKey(
            ValueKey('bank-choice-${options.indexOf(task.expectedAnswer)}'),
          );
          await tester.ensureVisible(correct);
          await tester.tap(correct);
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('bank-primary')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Дальше'));
          await tester.pumpAndSettle();
        }
        final field = find.byKey(const ValueKey('bank-answer'));
        await tester.enterText(field, '2');
        await tester.pump();
        final power = find.byKey(const ValueKey('bank-symbol-^'));
        await tester.ensureVisible(power);
        await tester.tap(power);
        await tester.tap(find.byKey(const ValueKey('bank-symbol-3')));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(field).controller!.text, '2³');
        expect(
          tester
              .widget<FilledButton>(
                find.descendant(
                  of: find.byKey(const ValueKey('bank-primary')),
                  matching: find.byType(FilledButton),
                ),
              )
              .onPressed,
          isNotNull,
        );
        await save('power-input');
        await mount();
        await tester.tap(find.byKey(const ValueKey('topic-1')));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(field).controller!.text, '2³');
        expect(find.text('Занятия по теме'), findsNothing);
        for (var index = 0; index < 2; index++) {
          final current = decodeGeneratedSessions(stored!).first.practice;
          await tester.enterText(field, current.currentTask.expectedAnswer);
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('bank-primary')));
          await tester.pumpAndSettle();
          if (index == 0) {
            await tester.tap(find.text('Дальше'));
            await tester.pumpAndSettle();
          }
        }
        await tester.tap(find.text('К темам'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('topic-0')));
        await tester.pumpAndSettle();
        final numeric = decodeGeneratedSessions(stored!)
            .first
            .practice
            .currentTask;
        final numericChoices = answerChoices(numeric);
        final selected = find.byKey(
          ValueKey(
            'bank-choice-${numericChoices.indexOf(numeric.expectedAnswer)}',
          ),
        );
        await tester.ensureVisible(selected);
        await tester.tap(selected);
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('bank-primary')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('К темам'));
        await tester.pumpAndSettle();
        expect(find.text('10%'), findsOneWidget);
        expect(find.text('90%'), findsOneWidget);
        await save('topics-progress');
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('topic-${practiceTopicCatalog.length - 1}')),
          400,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('topics-viewport-grid')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        await save('topics-roadmap-end');
        for (final family in [
          'numeric',
          'literal',
          'numeric_bracket',
          'literal_bracket',
        ]) {
          final demo = GeneratedSession.start(
            family: family,
            source: family.endsWith('_bracket')
                ? File(generatedTemplatePath(family)).readAsStringSync()
                : source,
            id: 'feedback-$family',
            seed: 17,
          );
          final task = demo.practice.currentTask;
          final wrong = task.demoChoices!.firstWhere((c) => c.errorId != null);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(
            MathTrainerApp(
              themeMode: theme,
              home: RepaintBoundary(
                key: capture,
                child: BankTrainer(initialSession: demo.practice),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final index = answerChoices(task).indexOf(wrong.answer);
          await tester.ensureVisible(
            find.byKey(ValueKey('bank-choice-$index')),
          );
          await tester.tap(find.byKey(ValueKey('bank-choice-$index')));
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('bank-primary')));
          await tester.pumpAndSettle();
          expect(find.text(wrong.hint!), findsOneWidget);
          await save('feedback-$family');
        }
        // Four-card layout fixture only; no new topics enter the real bank.
        await tester.pumpWidget(
          MathTrainerApp(
            themeMode: theme,
            home: RepaintBoundary(
              key: capture,
              child: TopicsScreen(
                titles: const [
                  'Вынесение численного общего множителя за скобки',
                  'Вынесение буквенного общего множителя за скобки',
                  'Тестовая карточка третьей темы',
                  'Тестовая карточка четвёртой темы',
                ],
                successes: const [null, 30, 70, 90],
                onGeneratePdf: (_) {},
                onTopicSelected: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await save('four-topics-fixture');
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: MathTrainerApp(
              themeMode: theme,
              home: GeneratedPracticeHome(
                allowHistoryReset: true,
                readText: (_) async => source,
                readHistory: () => stored,
                writeHistory: (s) => stored = s,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await save('reset-action');
        await tester.tap(find.byKey(const ValueKey('reset-history-action')));
        await tester.pumpAndSettle();
        await save('reset-confirmation');
        await tester.tap(find.byKey(const ValueKey('reset-history-confirm')));
        await tester.pumpAndSettle();
        expect(decodeGeneratedSessions(stored!), isEmpty);
        await save('reset-complete');
        await tester.tap(find.byKey(const ValueKey('topic-0')));
        await tester.pumpAndSettle();
        expect(
          decodeGeneratedSessions(stored!).single.practice.usesInput,
          isFalse,
        );
        await save('reset-choice');
      });
    }
  }
}
