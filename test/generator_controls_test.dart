import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/main.dart';
import 'package:math_trainer/generator/pdf_generator_screen.dart';

void main() {
  testWidgets('bulk quantity, steppers and reordered groups reach PDF', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? firstTemplate;
    int? taskCount;
    await tester.pumpWidget(
      MathTrainerApp(
        home: PdfGeneratorScreen(
          catalogText: File('bank/templates/common_factor.json')
              .readAsStringSync(),
          pdfBuilder: (tasks) async {
            firstTemplate = tasks.first.templateId;
            taskCount = tasks.length;
            return Uint8List.fromList('%PDF-test'.codeUnits);
          },
          exporter: (_, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> tap(String key) async {
      final f = find.byKey(ValueKey(key));
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    await tester.enterText(find.byKey(const ValueKey('quantity-all')), '2');
    await tester.pumpAndSettle();
    await tap('apply-quantity-all');
    expect(find.text('Выбрано шаблонов: 16 · Заданий: 32'), findsOneWidget);
    await tap('plus-numeric_common_factor_tpl_001');
    expect(find.text('Выбрано шаблонов: 16 · Заданий: 33'), findsOneWidget);
    await tap('minus-numeric_common_factor_tpl_001');
    expect(find.text('Выбрано шаблонов: 16 · Заданий: 32'), findsOneWidget);
    await tap('move-down-numeric_common_factor_tpl_001');
    final controller = tester
        .widget<TextFormField>(
          find.byKey(const ValueKey('quantity-numeric_common_factor_tpl_001')),
        )
        .controller!;
    expect(controller.text, '2');
    // Move the second row back above the first using a real drag gesture.
    final dragged = find.byKey(
      const ValueKey('drag-numeric_common_factor_tpl_001'),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('drag-numeric_common_factor_tpl_002')),
    );
    await tester.pumpAndSettle();
    final target = tester.getRect(
      find.byKey(const ValueKey('drag-numeric_common_factor_tpl_002')),
    );
    final gesture = await tester.startGesture(
      Offset(
        tester.getRect(dragged).left + 9,
        tester.getRect(dragged).center.dy,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(Offset(target.center.dx, target.center.dy - 15));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('generate-pdf')));
    await tester.pumpAndSettle();
    expect(firstTemplate, 'numeric_common_factor_tpl_001');
    expect(taskCount, 32);
    expect(tester.takeException(), isNull);
  });
}
