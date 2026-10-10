import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/main.dart';

void main() {
  for (final size in [
    const Size(1920, 1080),
    const Size(1366, 768),
    const Size(1366, 620),
  ]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (var selected = 0; selected < demoAnswers.length; selected++) {
        testWidgets(
          'Practice $size $mode answer $selected: result and stable layout',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              MathTrainerApp(themeMode: mode, home: const PracticeScreen()),
            );
            await tester.pumpAndSettle();
            final check = find.byKey(const ValueKey('check-answer'));
            expect(tester.widget<FilledButton>(check).onPressed, isNull);
            expect(find.text('0%'), findsOneWidget);
            expect(find.byKey(const ValueKey('success-track')), findsOneWidget);
            final scroll = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
            );
            expect(scroll.position.maxScrollExtent, 0);
            await tester.tap(
              find.byKey(ValueKey('answer-${(selected + 1) % 4}')),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(ValueKey('answer-$selected')));
            await tester.pumpAndSettle();
            expect(tester.widget<FilledButton>(check).onPressed, isNotNull);
            expect(
              find.byKey(const ValueKey('incorrect-feedback')),
              findsNothing,
            );
            expect(
              find.byKey(const ValueKey('correct-feedback')),
              findsNothing,
            );
            final rects = [
              for (var i = 0; i < 4; i++)
                tester.getRect(find.byKey(ValueKey('answer-$i'))),
            ];
            final buttonRect = tester.getRect(check);
            await tester.tap(check);
            await tester.pumpAndSettle();
            final correct = selected == 1;
            expect(find.text('Дальше'), findsOneWidget);
            expect(find.byKey(const ValueKey('check-answer')), findsNothing);
            expect(
              find.byKey(
                ValueKey(correct ? 'correct-feedback' : 'incorrect-feedback'),
              ),
              findsOneWidget,
            );
            expect(
              find.byIcon(Icons.check),
              correct ? findsNWidgets(2) : findsNothing,
            );
            expect(
              find.byIcon(Icons.close),
              correct ? findsNothing : findsOneWidget,
            );
            for (var i = 0; i < 4; i++) {
              final answer = find.byKey(ValueKey('answer-$i'));
              final button = tester.widget<OutlinedButton>(answer);
              expect(button.onPressed, isNull);
              expect(tester.getRect(answer), rects[i]);
              final expected = i != selected
                  ? Color(mode == ThemeMode.dark ? 0xff182237 : 0xffffffff)
                  : correct
                  ? Color(mode == ThemeMode.dark ? 0xff233e35 : 0xffeaf6ee)
                  : Color(mode == ThemeMode.dark ? 0xff452e36 : 0xfffff0ee);
              expect(
                button.style!.backgroundColor!.resolve({WidgetState.disabled}),
                expected,
              );
            }
            if (!correct) {
              expect(find.text('Пока не получилось!'), findsOneWidget);
              final learn = find.byKey(const ValueKey('learn-answer'));
              expect(tester.widget<OutlinedButton>(learn).onPressed, isNotNull);
              expect(
                tester.getBottomRight(learn).dy,
                lessThanOrEqualTo(size.height),
              );
            }
            final next = find.byKey(const ValueKey('next-task'));
            expect(tester.getRect(next), buttonRect);
            expect(find.text('0%'), findsOneWidget);
            expect(scroll.position.maxScrollExtent, 0);
            await tester.tap(next);
            await tester.pumpAndSettle();
            expect(
              find.byKey(
                ValueKey(correct ? 'correct-feedback' : 'incorrect-feedback'),
              ),
              findsOneWidget,
            );
            if (!correct) {
              final nextRect = tester.getRect(next);
              await tester.tap(find.byKey(const ValueKey('learn-answer')));
              await tester.pumpAndSettle();
              final panel = find.byKey(const ValueKey('explanation-panel'));
              expect(panel, findsOneWidget);
              expect(find.text('Давай разберёмся'), findsOneWidget);
              expect(
                find.byKey(const ValueKey('incorrect-feedback')),
                findsNothing,
              );
              expect(find.byKey(const ValueKey('learn-answer')), findsNothing);
              expect(tester.getRect(next), nextRect);
              expect(
                tester.getBottomRight(panel).dy,
                closeTo(nextRect.bottom, 1),
              );
              for (var i = 0; i < 4; i++) {
                final answer = find.byKey(ValueKey('answer-$i'));
                expect(tester.getRect(answer), rects[i]);
                expect(tester.widget<OutlinedButton>(answer).onPressed, isNull);
              }
              final expansion = switch (selected) {
                0 => '3(2x + 9) = 6x + 27',
                2 => '3(3x + 2) = 9x + 6',
                _ => '3(2x − 3) = 6x − 9',
              };
              expect(find.text(expansion), findsOneWidget);
              final panelScroll = tester.state<ScrollableState>(
                find.descendant(
                  of: find.byKey(const ValueKey('explanation-scroll')),
                  matching: find.byType(Scrollable),
                ),
              );
              if (panelScroll.position.maxScrollExtent > 0) {
                await tester.drag(
                  find.byKey(const ValueKey('explanation-scroll')),
                  const Offset(0, -500),
                );
                await tester.pumpAndSettle();
                expect(panelScroll.position.pixels, greaterThan(0));
                expect(scroll.position.pixels, 0);
              }
              expect(find.text('6x + 9 = 3(2x + 3)'), findsOneWidget);
              await tester.tap(next);
              await tester.pumpAndSettle();
              expect(panel, findsOneWidget);
              expect(find.text('0%'), findsOneWidget);
            }
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant({TargetPlatform.windows}),
        );
      }
    }
  }
}
