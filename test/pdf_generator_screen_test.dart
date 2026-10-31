import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/main.dart';
import 'package:math_trainer/bank_trainer.dart';
import 'package:math_trainer/generator/pdf_generator_screen.dart';

void main() {
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
        expect(
          find.text('Выбрано шаблонов: 16 · Заданий: 160'),
          findsOneWidget,
        );
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
