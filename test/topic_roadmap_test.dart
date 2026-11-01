import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/demo_screens.dart';
import 'package:math_trainer/main.dart';
import 'package:math_trainer/practice/generated_practice_home.dart';
import 'package:math_trainer/practice/generated_session.dart';
import 'package:math_trainer/practice/topic_catalog.dart';

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
  test(
    'roadmap does not activate topics without a supported template source',
    () {
      final ids = practiceTopicCatalog.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(
        practiceTopicCatalog.where((t) => t.available).map((t) => t.id),
        generatedTopicTitles.keys.map(generatedTopicId),
      );
      expect(
        ids,
        containsAll([
          'fraction_cancellation',
          'power_properties',
          'numeric_bracket_multiplication',
          'literal_bracket_multiplication',
          'bracket_multiplication',
          'sum_product_notation',
          'difference_product_notation',
          'gcd',
          'lcm',
          'ordinary_fraction',
        ]),
      );
    },
  );
  for (final size in [const Size(390, 844), const Size(1366, 768)]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('planned topics cannot open practice or PDF $size $theme', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? saved;
        await tester.pumpWidget(
          MathTrainerApp(
            themeMode: theme,
            home: GeneratedPracticeHome(
              readText: (_) async =>
                  File('bank/templates/common_factor.json').readAsStringSync(),
              readHistory: () => saved,
              writeHistory: (s) => saved = s,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final header = find.byKey(const ValueKey('topics-fixed-header'));
        final headerRect = tester.getRect(header);
        final scrollbarFinder = find.byKey(
          const ValueKey('topics-gutter-scrollbar'),
        );
        final scrollbar = tester.widget<RawScrollbar>(scrollbarFinder);
        final scrollbarRect = tester.getRect(scrollbarFinder);
        final card = tester.getRect(
          find.byKey(ValueKey(size.width >= 800 ? 'topic-1' : 'topic-0')),
        );
        final thumbLeft =
            scrollbarRect.right -
            scrollbar.crossAxisMargin -
            scrollbar.thickness!;
        expect(scrollbarRect.right, size.width);
        expect(thumbLeft, greaterThan(card.right));
        expect(scrollbar.controller!.hasClients, isTrue);
        await tester.dragFrom(
          Offset(thumbLeft + scrollbar.thickness! / 2, scrollbarRect.top + 16),
          const Offset(0, 30),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        expect(scrollbar.controller!.offset, greaterThan(0));
        if (size.width >= 800) {
          expect(
            tester.getRect(find.byKey(const ValueKey('topic-3'))).bottom,
            lessThanOrEqualTo(size.height),
          );
        }
        final grid = find.byKey(const ValueKey('topics-viewport-grid'));
        final scrollable = find.descendant(
          of: grid,
          matching: find.byType(Scrollable),
        );
        for (final index in [4, 5, practiceTopicCatalog.length - 1]) {
          final card = find.byKey(ValueKey('topic-$index'));
          await tester.scrollUntilVisible(card, 350, scrollable: scrollable);
          await tester.ensureVisible(card);
          await tester.pumpAndSettle();
          expect(tester.widget<InkWell>(card).onTap, isNull);
          final badge = tester.widget<TopicStateBadge>(
            find.byKey(ValueKey('topic-state-$index')),
          );
          expect(badge.locked, isTrue);
          final pdf = find.byKey(ValueKey('pdf-topic-$index'));
          expect(tester.widget<OutlinedButton>(pdf).onPressed, isNull);
          await tester.tap(card, warnIfMissed: false);
          await tester.tap(pdf, warnIfMissed: false);
          await tester.pumpAndSettle();
          expect(saved, isNull);
          expect(
            find.byKey(const ValueKey('topics-viewport-grid')),
            findsOneWidget,
          );
          expect(tester.getRect(header), headerRect);
          expect(scrollbar.controller!.offset, greaterThan(0));
          expect(tester.takeException(), isNull);
        }
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('topic-0')),
          -350,
          scrollable: scrollable,
        );
        await tester.ensureVisible(find.byKey(const ValueKey('topic-0')));
        await tester.tap(find.byKey(const ValueKey('topic-0')));
        await tester.pumpAndSettle();
        expect(
          decodeGeneratedSessions(saved!).single.practice.bank.topicId,
          'numeric_common_factor',
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
