// Pixel captures of the real widget tree. These are not browser screenshots.
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/bank_trainer.dart';
import 'package:math_trainer/main.dart';
import 'package:math_trainer/bank/task_bank.dart';
import 'package:math_trainer/practice/answer_choices.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final uiFont = FontLoader('Carlito')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/Carlito-Regular.ttf').readAsBytesSync(),
          ),
        ),
      );
    final mathFont = FontLoader('Caladea')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/Caladea-Regular.ttf').readAsBytesSync(),
          ),
        ),
      );
    final configFile = File('.dart_tool/package_config.json');
    final config =
        jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    final flutterPackage = (config['packages'] as List).firstWhere(
      (p) => p['name'] == 'flutter',
    );
    final flutterRoot = Directory.fromUri(
      configFile.absolute.uri.resolve(flutterPackage['rootUri'] as String),
    ).parent.parent;
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File.fromUri(
              flutterRoot.uri.resolve(
                'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
              ),
            ).readAsBytesSync(),
          ),
        ),
      );
    await uiFont.load();
    await mathFont.load();
    await icons.load();
  });
  for (final (size, theme, name) in [
    (const Size(1366, 768), ThemeMode.light, 'light-1366x768'),
    (const Size(1366, 768), ThemeMode.dark, 'dark-1366x768'),
    (const Size(1920, 1080), ThemeMode.light, 'light-1920x1080'),
    (const Size(1920, 1080), ThemeMode.dark, 'dark-1920x1080'),
    (const Size(390, 844), ThemeMode.light, 'light-390x844'),
    (const Size(390, 844), ThemeMode.dark, 'dark-390x844'),
  ]) {
    testWidgets('capture real bank $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const capture = ValueKey('bank-capture');
      await tester.pumpWidget(
        MathTrainerApp(
          themeMode: theme,
          home: RepaintBoundary(
            key: capture,
            child: BankTrainer(
              readText: (p) async => File(p).readAsStringSync(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('topic-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Начать практику'));
      await tester.pumpAndSettle();
      Future<void> save(String state) async {
        final title = tester.getRect(
          find.byKey(const ValueKey('demo-topic-title')),
        );
        final percent = tester.getRect(
          find.byKey(const ValueKey('demo-success-percent')),
        );
        expect(title.bottom, closeTo(percent.bottom, .01));
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(capture),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          final path = 'docs/verification/bank-$state-$name-widget.png';
          await File(path).writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      }

      final bank = await TaskBank.load(
        'bank/manifest.json',
        (p) async => File(p).readAsStringSync(),
      );
      await save('choice');
      final choices = answerChoices(bank.blocks.first.tasks.first);
      final correctIndex = choices.indexOf(
        bank.blocks.first.tasks.first.expectedAnswer,
      );
      await tester.tap(find.byKey(ValueKey('bank-choice-$correctIndex')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Проверить себя'));
      await tester.pumpAndSettle();
      await save('choice-correct');
      await tester.tap(find.text('Дальше'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Предыдущее задание'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await save('history-choice');
      await tester.tap(find.text('Дальше'));
      await tester.pumpAndSettle();
      // Fill the real 10-answer window enough to admit input (7/10 >= 70%).
      for (var blockIndex = 1; blockIndex < 7; blockIndex++) {
        final task = bank.blocks[blockIndex].tasks.first;
        final options = answerChoices(task);
        await tester.tap(
          find.byKey(
            ValueKey('bank-choice-${options.indexOf(task.expectedAnswer)}'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Проверить себя'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Дальше'));
        await tester.pumpAndSettle();
      }
      await tester.enterText(
        find.byKey(const ValueKey('bank-answer')),
        bank.blocks[7].tasks.first.expectedAnswer,
      );
      await tester.pumpAndSettle();
      final viewport = Offset.zero & size;
      for (final key in [
        'bank-answer',
        'bank-delete',
        'bank-clear',
        'bank-key-group-Числа',
        'bank-key-group-Буквы',
        'bank-key-group-Знаки и скобки',
        'bank-primary',
      ]) {
        final rect = tester.getRect(find.byKey(ValueKey(key)));
        expect(viewport.contains(rect.topLeft), isTrue, reason: key);
        expect(viewport.contains(rect.bottomRight), isTrue, reason: key);
      }
      await save('feedback-input');
      await tester.tap(find.text('Проверить себя'));
      await tester.pumpAndSettle();
      final feedback = tester.getRect(
        find.byKey(const ValueKey('bank-feedback')),
      );
      expect(viewport.contains(feedback.topLeft), isTrue);
      expect(viewport.contains(feedback.bottomRight), isTrue);
      await save('feedback-correct');
      for (var blockIndex = 8; blockIndex < 9; blockIndex++) {
        await tester.tap(find.text('Дальше'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('bank-answer')),
          bank.blocks[blockIndex].tasks.first.expectedAnswer,
        );
        await tester.pump();
        await tester.tap(find.text('Проверить себя'));
        await tester.pumpAndSettle();
      }
      final finish = tester.getRect(find.byKey(const ValueKey('bank-finish')));
      expect(viewport.contains(finish.topLeft), isTrue);
      expect(viewport.contains(finish.bottomRight), isTrue);
      await save('finish-available');
      await tester.tap(find.text('Завершить занятие'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Назад к решению'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 7; i++) {
        await tester.tap(find.text('Дальше'));
        await tester.pumpAndSettle();
      }
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('bank-answer')))
            .readOnly,
        isTrue,
      );
      await save('history-input');
    });
  }
}
