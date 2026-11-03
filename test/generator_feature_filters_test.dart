import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/bank/factor_answer_checker.dart';
import 'package:math_trainer/generator/pdf_generator_screen.dart';
import 'package:math_trainer/generator/task_generator.dart';
import 'package:math_trainer/generator/worksheet_test_choices.dart';
import 'package:math_trainer/generator/worksheet_pdf.dart';
import 'package:math_trainer/main.dart';

void main() {
  final source = File('bank/templates/common_factor.json').readAsStringSync();
  final options = generationOptions(loadTemplates(source));
  test('PDF literal constants vary and keep the common factor in every original term', () async {
    final unitTemplates = options
        .where((t) => t.family == 'literal' && t.features.contains('unit'))
        .toList();
    final generator = TemplateTaskGenerator(
      seed: 113,
      varyLiteralConstants: true,
    );
    final all = <GeneratedExercise>[];
    for (final template in unitTemplates) {
      final tasks = generator.generate(
        templates: [template],
        quantities: {template.id: 5},
      );
      for (final task in tasks) {
        final number = int.parse(
          RegExp(r'[+−] ([1-9])\)$').firstMatch(task.answer)![1]!,
        );
        final common = task.answer[0];
        expect(
          task.expression,
          endsWith('${number == 1 ? '' : number}$common'),
        );
        expect(equivalentExpressions(task.expression, task.answer), true);
      }
      all.addAll(tasks);
    }
    // The test format can still construct exactly four different choices.
    final items = worksheetTestItems([all], seed: 12).single;
    expect(items.length, all.length);
    expect(items.every((item) => item.choices.length == 4), true);
    final baseUnit = unitTemplates.firstWhere((t) => !t.combined);
    final sample = generator.generate(
      templates: [baseUnit],
      quantities: {baseUnit.id: 100},
    );
    expect(
      sample
          .map((t) => RegExp(r'[+−] ([1-9])\)$').firstMatch(t.answer)![1])
          .toSet(),
      {'1', '2', '3', '4', '5', '6', '7', '8', '9'},
    );
    final canonical = TemplateTaskGenerator(seed: 113)
        .generate(templates: [baseUnit], quantities: {baseUnit.id: 10});
    expect(canonical.every((t) => t.answer.endsWith(' 1)')), true);
    for (final testMode in [false, true]) {
      final bytes = await buildWorksheetPdf(
        exercises: sample.take(21).toList(),
        textFont: ByteData.sublistView(
          File('assets/fonts/Carlito-Regular.ttf').readAsBytesSync(),
        ),
        mathFont: ByteData.sublistView(
          File('assets/fonts/Caladea-Regular.ttf').readAsBytesSync(),
        ),
        includeAnswers: true,
        testMode: testMode,
      );
      File(
        '.dart_tool/literal-constants-${testMode ? 'test' : 'worksheet'}.pdf',
      ).writeAsBytesSync(bytes);
    }
  });

  for (final size in [const Size(1366, 900), const Size(390, 844)]) {
    testWidgets(
      'feature filters exclude singles and combinations, preserve hidden quantities $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        List<GeneratedExercise>? exported;
        await tester.pumpWidget(
          MathTrainerApp(
            home: PdfGeneratorScreen(
              family: 'literal',
              catalogText: source,
              pdfBuilder: (tasks) async {
                exported = tasks;
                return Uint8List.fromList('%PDF'.codeUnits);
              },
              exporter: (_, _) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> tap(String key) async {
          final finder = find.byKey(ValueKey(key));
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        final feature = find.byKey(const ValueKey('generator-feature-powers'));
        final level = find.byKey(const ValueKey('generator-level-1'));
        expect(tester.widget<CheckboxListTile>(feature).value, true);
        if (size.width > 700) {
          expect(
            tester.getRect(feature).left,
            greaterThan(tester.getRect(level).right),
          );
        } else {
          expect(
            tester.getRect(feature).top,
            greaterThan(tester.getRect(level).bottom),
          );
        }
        await tap('generator-level-2');
        await tap('generator-level-3');
        expect(find.text('Свободное число в скобках'), findsOneWidget);
        expect(find.text('ab + 3a → a(b + 3)'), findsOneWidget);
        const powersId = 'literal_common_factor_tpl_007';
        final quantity = find.byKey(const ValueKey('quantity-$powersId'));
        await tester.ensureVisible(quantity);
        await tester.pumpAndSettle();
        await tester.enterText(quantity, '7');
        await tester.pumpAndSettle();
        await tap('generator-feature-powers');
        await tap('generator-feature-bracket');
        for (final t in options.where(
          (t) =>
              t.family == 'literal' &&
              t.features.any(
                (f) => ['powers', 'factor_power', 'bracket'].contains(f),
              ),
        )) {
          expect(find.byKey(ValueKey('row-${t.id}')), findsNothing);
        }
        expect(
          tester
              .widget<FilterChip>(
                find.byKey(const ValueKey('generator-level-3')),
              )
              .selected,
          true,
        );
        final common = find.byKey(const ValueKey('quantity-all'));
        await tester.ensureVisible(common);
        await tester.pumpAndSettle();
        await tester.enterText(common, '3');
        await tester.pumpAndSettle();
        await tap('apply-quantity-all');
        await tap('generator-feature-powers');
        expect(tester.widget<TextFormField>(quantity).controller!.text, '7');
        await tap('generator-feature-powers');
        await tester.tap(find.byKey(const ValueKey('generate-pdf')));
        await tester.pumpAndSettle();
        expect(exported, isNotNull);
        final byId = {for (final t in options) t.id: t};
        for (final task in exported!) {
          expect(
            byId[task.templateId]!.features.any(
              (f) => ['powers', 'factor_power', 'bracket'].contains(f),
            ),
            false,
          );
          expect(task.expression, isNot(matches(RegExp('[²³^]'))));
        }
        // Turning every feature off leaves the base template, even on levels 2–3.
        final remaining = tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .where(
              (c) =>
                  c.key is ValueKey<String> &&
                  (c.key! as ValueKey<String>).value.startsWith(
                    'generator-feature-',
                  ) &&
                  c.value == true,
            )
            .map((c) => (c.key! as ValueKey<String>).value)
            .toList();
        for (final key in remaining) {
          await tap(key);
        }
        expect(find.text('Выбрано шаблонов: 1 · Заданий: 3'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
