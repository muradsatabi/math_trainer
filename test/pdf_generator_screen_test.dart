import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/main.dart';
import 'package:math_trainer/bank_trainer.dart';
import 'package:math_trainer/generator/pdf_generator_screen.dart';
import 'package:math_trainer/practice/generated_practice_home.dart';

void main() {
  testWidgets('variant quantity validates and exports all requested work', (
    tester,
  ) async {
    var exports = 0;
    await tester.pumpWidget(
      MathTrainerApp(
        home: PdfGeneratorScreen(
          catalogText: File('bank/templates/common_factor.json')
              .readAsStringSync(),
          pdfBuilder: (tasks) async {
            expect(tasks.length, 30);
            return Uint8List.fromList('%PDF-test'.codeUnits);
          },
          exporter: (_, _) async {
            exports++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final quantity = find.byKey(const ValueKey('quantity-variants'));
    await tester.ensureVisible(quantity);
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(quantity).controller!.text, '1');
    for (final invalid in ['0', '101', '']) {
      await tester.enterText(quantity, invalid);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('generate-pdf')))
            .onPressed,
        isNull,
      );
    }
    await tester.enterText(quantity, '3');
    await tester.pumpAndSettle();
    expect(
      find.text('Вариантов: 3 · В каждом: 10 · Всего заданий: 30'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('generate-pdf')));
    await tester.pumpAndSettle();
    expect(exports, 1);
    expect(find.text('PDF готов: 3 вариантов по 10 заданий.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final index in [0, 1]) {
    testWidgets(
      'topic PDF keeps its family and starts with level 1 and five tasks $index',
      (tester) async {
        final family = index == 0 ? 'numeric' : 'literal';
        final other = index == 0 ? 'literal' : 'numeric';
        await tester.pumpWidget(
          MathTrainerApp(
            home: GeneratedPracticeHome(
              readText: (path) async => File(path).readAsStringSync(),
              readHistory: () => null,
              writeHistory: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('pdf-topic-$index')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<PdfGeneratorScreen>(find.byType(PdfGeneratorScreen))
              .family,
          family,
        );
        expect(find.text('Выбрано шаблонов: 1 · Заданий: 5'), findsOneWidget);
        expect(find.text('Какие шаблоны использовать'), findsNothing);
        final format = find.byKey(const ValueKey('pdf-test-mode'));
        await tester.ensureVisible(format);
        await tester.pumpAndSettle();
        expect(find.text('Обычные задания'), findsOneWidget);
        await tester.tap(format);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Тест — четыре ответа').last);
        await tester.pumpAndSettle();
        expect(find.text('Тест — четыре ответа'), findsOneWidget);
        final columns = find.byKey(const ValueKey('pdf-columns'));
        await tester.ensureVisible(columns);
        await tester.pumpAndSettle();
        expect(find.text('Два столбца'), findsOneWidget);
        await tester.tap(columns);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Три столбца').last);
        await tester.pumpAndSettle();
        final orientation = find.byKey(const ValueKey('pdf-orientation'));
        await tester.ensureVisible(orientation);
        await tester.pumpAndSettle();
        await tester.tap(orientation);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Книжная').last);
        await tester.pumpAndSettle();
        expect(find.text('Три столбца'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('generator-level-1')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('select-${other}_common_factor_tpl_001')),
          findsNothing,
        );
        for (var level = 1; level <= 6; level++) {
          expect(
            tester
                .widget<FilterChip>(
                  find.byKey(ValueKey('generator-level-$level')),
                )
                .selected,
            level == 1,
          );
        }
        expect(
          tester
              .widget<TextFormField>(find.byKey(const ValueKey('quantity-all')))
              .controller!
              .text,
          '5',
        );
        await tester.tap(find.byKey(const ValueKey('generator-level-2')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('select-${other}_common_factor_tpl_002')),
          findsNothing,
        );
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(
                  ValueKey('quantity-${family}_common_factor_tpl_002'),
                ),
              )
              .controller!
              .text,
          '5',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final size in [const Size(1366, 768), const Size(390, 844)]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('PDF action is separate from practice, $size $theme', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MathTrainerApp(
            themeMode: theme,
            home: BankTrainer(
              readText: (path) async => File(path).readAsStringSync(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final pdf = find.byKey(const ValueKey('pdf-topic-0'));
        final card = find.byKey(const ValueKey('topic-0'));
        expect(
          tester.getRect(pdf).center.dx,
          greaterThan(tester.getRect(card).center.dx),
        );
        await tester.tap(pdf);
        await tester.pumpAndSettle();
        expect(find.byType(PdfGeneratorScreen), findsOneWidget);
        expect(find.byKey(const ValueKey('generator-summary')), findsOneWidget);
        expect(find.text('Выбрано шаблонов: 2 · Заданий: 10'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('К темам'));
        await tester.pumpAndSettle();
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(find.text('Начать практику'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('per-template counts, disabled empty request, export and retry', (
    tester,
  ) async {
    Uint8List? exported;
    var fail = true;
    await tester.pumpWidget(
      MathTrainerApp(
        home: PdfGeneratorScreen(
          catalogText: File('bank/templates/common_factor.json')
              .readAsStringSync(),
          pdfBuilder: (tasks) async {
            expect(tasks.length, 3);
            return Uint8List.fromList('%PDF-test-export'.codeUnits);
          },
          exporter: (bytes, name) async {
            expect(name, endsWith('.pdf'));
            if (fail) throw StateError('download failed');
            exported = bytes;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Снять выбор'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('generate-pdf')))
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('select-literal_common_factor_tpl_001')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('select-literal_common_factor_tpl_001')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('quantity-literal_common_factor_tpl_001')),
      '3',
    );
    await tester.pumpAndSettle();
    expect(find.text('Выбрано шаблонов: 1 · Заданий: 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('generate-pdf')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Не удалось создать PDF'), findsOneWidget);
    fail = false;
    await tester.tap(find.byKey(const ValueKey('generate-pdf')));
    await tester.pumpAndSettle();
    expect(exported, isNotNull);
    expect(String.fromCharCodes(exported!.take(5)), '%PDF-');
    expect(find.text('PDF готов: 3 заданий.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
