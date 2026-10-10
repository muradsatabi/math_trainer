import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/main.dart';

void main() {
  for (final size in [const Size(1920, 1080), const Size(1366, 768)]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        'Previous task is read-only; current task survives: $size $mode',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(MathTrainerApp(themeMode: mode));
          await tester.tap(find.byKey(const ValueKey('topic-0')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Начать практику'));
          await tester.pumpAndSettle();
          final choicePrevious = tester.getRect(
            find.byKey(const ValueKey('previous-task-space')),
          );
          final choiceAction = tester.getRect(
            find.byKey(const ValueKey('check-answer')),
          );
          expect(choiceAction.left - choicePrevious.right, closeTo(12, .01));
          expect(choiceAction.width, closeTo(choicePrevious.width * 2, .01));
          expect(choicePrevious.center.dy, closeTo(choiceAction.center.dy, 1));
          expect(find.text('Предыдущее задание'), findsNothing);
          final selected = mode == ThemeMode.light ? 0 : 1;
          await tester.tap(find.byKey(ValueKey('answer-$selected')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('check-answer')));
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.byKey(const ValueKey('next-task'))),
            choiceAction,
          );
          expect(
            tester.getRect(find.byKey(const ValueKey('previous-task-space'))),
            choicePrevious,
          );
          expect(find.text('Предыдущее задание'), findsNothing);
          if (selected == 0) {
            await tester.tap(find.byKey(const ValueKey('learn-answer')));
            await tester.pumpAndSettle();
          }
          await tester.ensureVisible(find.text('Дальше'));
          await tester.tap(find.text('Дальше'));
          await tester.pumpAndSettle();
          for (final symbol in '3(2x'.split('')) {
            await tester.tap(find.byKey(ValueKey('symbol-$symbol')));
            await tester.pumpAndSettle();
          }
          final input = find.byKey(const ValueKey('assembly'));
          final previousButton = find.widgetWithText(
            OutlinedButton,
            'Предыдущее задание',
          );
          final previousRect = tester.getRect(previousButton);
          final actionRect = tester.getRect(
            find.byKey(const ValueKey('constructor-check')),
          );
          expect(previousRect.right, lessThan(actionRect.left));
          expect(actionRect.left - previousRect.right, closeTo(24, .01));
          expect(
            previousRect.left,
            closeTo(
              tester.getRect(find.byKey(const ValueKey('symbol-1'))).left,
              .01,
            ),
          );
          expect(
            previousRect.right,
            closeTo(
              tester.getRect(find.byKey(const ValueKey('symbol-2'))).right,
              .01,
            ),
          );
          expect(
            actionRect.left,
            closeTo(
              tester.getRect(find.byKey(const ValueKey('symbol-x'))).left,
              .01,
            ),
          );
          expect(
            actionRect.right,
            closeTo(
              tester.getRect(find.byKey(const ValueKey('symbol-−'))).right,
              .01,
            ),
          );
          expect(previousRect.center.dy, closeTo(actionRect.center.dy, 1));
          final controller = tester.widget<TextField>(input).controller!;
          controller.selection = const TextSelection.collapsed(offset: 2);
          Future<void> openPrevious() async {
            await tester.ensureVisible(find.text('Предыдущее задание'));
            await tester.tap(find.text('Предыдущее задание'));
            await tester.pumpAndSettle();
            for (var i = 0; i < 4; i++) {
              expect(
                tester
                    .widget<OutlinedButton>(find.byKey(ValueKey('answer-$i')))
                    .onPressed,
                isNull,
              );
            }
            expect(find.byKey(const ValueKey('check-answer')), findsNothing);
            expect(find.text('0%'), findsOneWidget);
            expect(find.text('Дальше'), findsNothing);
            expect(
              find.text(
                selected == 0 ? 'Давай разберёмся' : 'Абсолютно\nверно!',
              ),
              findsOneWidget,
            );
            await tester.ensureVisible(find.text('Вернуться к текущему'));
            await tester.tap(find.text('Вернуться к текущему'));
            await tester.pumpAndSettle();
          }

          await openPrevious();
          expect(tester.widget<TextField>(input).controller, same(controller));
          expect(controller.text, '3(2x');
          expect(controller.selection.baseOffset, 2);
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(const ValueKey('constructor-check')),
                )
                .onPressed,
            isNull,
          );
          controller.selection = TextSelection.collapsed(
            offset: controller.text.length,
          );
          for (final symbol in '+4)'.split('')) {
            await tester.tap(find.byKey(ValueKey('symbol-$symbol')));
            await tester.pumpAndSettle();
          }
          await tester.tap(find.byKey(const ValueKey('constructor-check')));
          await tester.pumpAndSettle();
          expect(tester.getRect(previousButton), previousRect);
          expect(
            tester.getRect(find.byKey(const ValueKey('constructor-check'))),
            actionRect,
          );
          await tester.tap(find.text('Узнать, как правильно'));
          await tester.pumpAndSettle();
          await openPrevious();
          expect(controller.text, '3(2x+4)');
          expect(find.text('Давай разберёмся'), findsOneWidget);
          expect(
            tester
                .widget<OutlinedButton>(find.byKey(const ValueKey('symbol-3')))
                .onPressed,
            isNull,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Дальше'));
          await tester.pumpAndSettle();
          final recapBack = tester.getRect(
            find.widgetWithText(OutlinedButton, 'Назад к решению'),
          );
          final recapNext = tester.getRect(
            find.widgetWithText(FilledButton, 'Дальше'),
          );
          expect(recapBack.right, lessThan(recapNext.left));
          expect(recapNext.left - recapBack.right, closeTo(12, .01));
          Future<void> viewFirst(String returnLabel) async {
            await tester.ensureVisible(find.text('Назад к решению'));
            await tester.tap(find.text('Назад к решению'));
            await tester.pumpAndSettle();
            for (var i = 0; i < 4; i++) {
              expect(
                tester
                    .widget<OutlinedButton>(find.byKey(ValueKey('answer-$i')))
                    .onPressed,
                isNull,
              );
            }
            expect(find.byKey(const ValueKey('assembly')), findsNothing);
            expect(find.byKey(const ValueKey('check-answer')), findsNothing);
            expect(
              find.text(
                selected == 0 ? 'Давай разберёмся' : 'Абсолютно\nверно!',
              ),
              findsOneWidget,
            );
            expect(find.text('0%'), findsOneWidget);
            await tester.ensureVisible(find.text(returnLabel));
            await tester.tap(find.text(returnLabel));
            await tester.pumpAndSettle();
          }

          await viewFirst('Вернуться к закреплению');
          expect(find.text('Чему мы научились'), findsOneWidget);
          await tester.ensureVisible(find.text('Дальше'));
          await tester.tap(find.text('Дальше'));
          await tester.pumpAndSettle();
          final resultsBack = tester.getRect(find.text('Назад к решению'));
          final topics = tester.getRect(find.text('К темам').last);
          final review = tester.getRect(find.text('Разобрать ошибки'));
          expect(resultsBack.right, lessThan(topics.left));
          expect(topics.right, lessThan(review.left));
          await viewFirst('Вернуться к итогам');
          expect(find.text('Итоги практики'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant({TargetPlatform.windows}),
      );
    }
  }
}
