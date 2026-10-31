// Widget captures with production fonts, not browser screenshots.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/main.dart';
import 'package:math_trainer/bank_trainer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry in {
      'Carlito': 'assets/fonts/Carlito-Regular.ttf',
      'Caladea': 'assets/fonts/Caladea-Regular.ttf',
      'MaterialIcons': 'D:/Dev/SDK/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(entry.key)..addFont(
            Future.value(
              ByteData.sublistView(File(entry.value).readAsBytesSync()),
            ),
          ))
          .load();
    }
  });
  for (final size in [
    const Size(1366, 768),
    const Size(1920, 1080),
    const Size(390, 844),
  ]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('generator capture $size $mode', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const key = ValueKey('generator-capture');
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MathTrainerApp(
              themeMode: mode,
              home: BankTrainer(
                readText: (p) async => File(p).readAsStringSync(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> capture(String label) async {
          expect(tester.takeException(), isNull);
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(key),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final folder = Directory('.dart_tool/generator-captures')
              ..createSync(recursive: true);
            File('${folder.path}/$label-${size.width.toInt()}-${mode.name}.png')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await capture('topics');
        await tester.tap(find.byKey(const ValueKey('pdf-topic-0')));
        await tester.pumpAndSettle();
        await capture('generator');
        await tester.tap(find.byKey(const ValueKey('generator-level-3')));
        await tester.pumpAndSettle();
        expect(
          find.text('Выбрано шаблонов: 59 · Заданий: 590'),
          findsOneWidget,
        );
        await capture('combinations');
      });
    }
  }
}
