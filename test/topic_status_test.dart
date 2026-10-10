import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/main.dart';
import 'package:math_trainer/demo_screens.dart';

void main() {
  for (final size in [const Size(1920, 1080), const Size(1366, 768)]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        'Topic states, exact percentages and shared colors $size $mode',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(MathTrainerApp(themeMode: mode));
          await tester.pumpAndSettle();
          expect(find.text('86%'), findsOneWidget);
          expect(find.text('85%+'), findsNothing);
          expect(find.byIcon(Icons.check_rounded), findsOneWidget);
          expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
          for (var i = 0; i < 4; i++) {
            final card = find.byKey(ValueKey('topic-$i'));
            final badge = find.descendant(
              of: card,
              matching: find.byType(TopicStateBadge),
            );
            final title = find
                .descendant(of: card, matching: find.byType(Text))
                .first;
            expect(
              tester.getRect(badge).right,
              lessThan(tester.getRect(title).left),
            );
            final icons = find.descendant(
              of: badge,
              matching: find.byType(Icon),
            );
            if (i < 2) {
              final bar = tester.widget<LinearProgressIndicator>(
                find.descendant(
                  of: card,
                  matching: find.byType(LinearProgressIndicator),
                ),
              );
              expect(tester.widget<Icon>(icons).color, bar.color);
              expect(bar.value, i == 0 ? .86 : .65);
            } else {
              expect(icons, findsNothing);
              final decoration =
                  tester
                          .widget<Container>(
                            find.descendant(
                              of: badge,
                              matching: find.byType(Container),
                            ),
                          )
                          .decoration!
                      as BoxDecoration;
              expect(decoration.color, isNull);
            }
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(
            MathTrainerApp(
              themeMode: mode,
              home: const TopicsScreen(successes: [87, 85, 84, null]),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('87%'), findsOneWidget);
          expect(find.text('85%'), findsOneWidget);
          expect(find.text('84%'), findsOneWidget);
          expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
          expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant({TargetPlatform.windows}),
      );
    }
  }
}
