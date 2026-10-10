import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/main.dart';

void main() {
  for (final size in [
    const Size(1366, 768),
    const Size(1366, 620),
    const Size(1024, 620),
  ]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final screen in ['recap', 'review']) {
        testWidgets('$screen scroll and footer access $size $mode', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MathTrainerApp(
              themeMode: mode,
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(
                      size.height <= 620 ? 1.25 : 1,
                    ),
                  ),
                  child: demoScreen(screen),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
          expect(scrollbar.thumbVisibility, isTrue);
          expect(scrollbar.controller, isNotNull);
          if (size.height <= 620) {
            expect(
              scrollbar.controller!.position.maxScrollExtent,
              greaterThan(0),
            );
          }
          await tester.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, -3000),
          );
          await tester.pumpAndSettle();
          final action = find.widgetWithText(
            FilledButton,
            screen == 'recap' ? 'Дальше' : 'Следующая ошибка',
          );
          final rect = tester.getRect(action);
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(size.height));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(tester.takeException(), isNull);
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(
            find.text(screen == 'recap' ? 'Итоги практики' : 'Задание 2 из 4'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }, variant: TargetPlatformVariant({TargetPlatform.windows}));
      }
    }
  }
}
