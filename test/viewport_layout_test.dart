import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/demo_screens.dart';
import 'package:math_trainer/main.dart';

void main() {
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
  const titles = [
    'Вынесение численного общего множителя за скобки',
    'Вынесение буквенного общего множителя за скобки',
    'Тестовая карточка третьей темы',
    'Тестовая карточка четвёртой темы',
  ];
  for (final size in [
    const Size(1024, 600),
    const Size(1366, 620),
    const Size(1366, 768),
    const Size(1920, 1080),
  ]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('four desktop topics fit viewport $size $theme', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MathTrainerApp(
            themeMode: theme,
            home: TopicsScreen(
              titles: titles,
              successes: const [null, 30, 70, 90],
              onGeneratePdf: (_) {},
              onTopicSelected: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final rects = [
          for (var i = 0; i < 4; i++)
            tester.getRect(find.byKey(ValueKey('topic-$i'))),
        ];
        for (final rect in rects) {
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(rect.top, greaterThan(0));
          expect(rect.bottom, lessThanOrEqualTo(size.height));
        }
        expect(rects[0].top, rects[1].top);
        expect(rects[2].top, rects[3].top);
        expect(rects[0].bottom, lessThan(rects[2].top));
        expect(rects[0].right, lessThan(rects[1].left));
        final grid = tester.state<ScrollableState>(
          find.descendant(
            of: find.byKey(const ValueKey('topics-viewport-grid')),
            matching: find.byType(Scrollable),
          ),
        );
        expect(grid.position.maxScrollExtent, closeTo(0, .01));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('topic header stays visible during scroll and resize', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MathTrainerApp(
        home: TopicsScreen(
          titles: titles,
          successes: const [null, 30, 70, 90],
          onGeneratePdf: (_) {},
          onTopicSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final header = find.byKey(const ValueKey('topics-fixed-header'));
    final before = tester.getRect(header);
    await tester.drag(find.byType(GridView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(tester.getRect(header), before);
    await tester.ensureVisible(find.byKey(const ValueKey('pdf-topic-3')));
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(1366, 768);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('topic-3'))).bottom,
      lessThanOrEqualTo(768),
    );
    expect(tester.takeException(), isNull);
  });

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'practice header and footer stay visible while body scrolls $theme',
      (tester) async {
        tester.view.physicalSize = const Size(1366, 620);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MathTrainerApp(
            themeMode: theme,
            home: DemoPage(
              showLabel: false,
              showSuccess: true,
              successPercent: 70,
              visibleScrollbar: true,
              bodyBuilder: (_, _, _) =>
                  const SizedBox(height: 1800, child: Text('Задание')),
              footerBuilder: (_, _, _) => const Text('Нижние действия'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final header = find.byKey(const ValueKey('demo-fixed-header'));
        final footer = find.byKey(const ValueKey('demo-footer'));
        final beforeHeader = tester.getRect(header);
        final beforeFooter = tester.getRect(footer);
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(header), beforeHeader);
        expect(tester.getRect(footer), beforeFooter);
        expect(beforeFooter.bottom, lessThanOrEqualTo(620));
        expect(
          tester.widget<Scrollbar>(find.byType(Scrollbar)).controller!.offset,
          greaterThan(0),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
