import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'task_generator.dart';

/// Pure PDF authoring: no storage, network access or practice-state mutation.
Future<Uint8List> buildWorksheetPdf({
  required List<GeneratedExercise> exercises,
  required ByteData textFont,
  required ByteData mathFont,
}) async {
  if (exercises.isEmpty || exercises.length > TemplateTaskGenerator.maxTotal) {
    throw ArgumentError('Invalid worksheet size');
  }
  final text = pw.Font.ttf(textFont);
  final math = pw.Font.ttf(mathFont);
  final document = pw.Document(
    title: 'Математическая практика',
    author: 'Математический тренажёр',
  );
  const mm = PdfPageFormat.mm;
  for (var offset = 0; offset < exercises.length; offset += 20) {
    final pageTasks = exercises.skip(offset).take(20).toList();
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Stack(
          children: [
            pw.Positioned.fill(
              child: pw.CustomPaint(
                painter: (canvas, size) {
                  canvas
                    ..setStrokeColor(const PdfColor(.83, .83, .83))
                    ..setLineWidth(.25);
                  for (var x = 12.0; x <= 287; x += 5) {
                    canvas
                      ..moveTo(x * mm, 10 * mm)
                      ..lineTo(x * mm, 175 * mm)
                      ..strokePath();
                  }
                  for (var y = 10.0; y <= 175; y += 5) {
                    canvas
                      ..moveTo(12 * mm, y * mm)
                      ..lineTo(287 * mm, y * mm)
                      ..strokePath();
                  }
                },
              ),
            ),
            pw.Positioned(
              left: 17 * mm,
              top: 13 * mm,
              child: pw.Text(
                'Имя: __________________________   Класс: ______   Дата: ______________',
                style: pw.TextStyle(font: text, fontSize: 12),
              ),
            ),
            pw.Positioned(
              left: 17 * mm,
              top: 27 * mm,
              child: pw.Text(
                'Вынеси общий множитель за скобки:',
                style: pw.TextStyle(font: text, fontSize: 12),
              ),
            ),
            for (var i = 0; i < pageTasks.length; i++)
              pw.Positioned(
                left: (i < 10 ? 17 : 150.5) * mm,
                top: (43 + (i % 10) * 15) * mm,
                child: pw.SizedBox(
                  width: 128 * mm,
                  height: 10 * mm,
                  child: pw.FittedBox(
                    alignment: pw.Alignment.topLeft,
                    fit: pw.BoxFit.scaleDown,
                    child: pw.Text(
                      '${pageTasks[i].expression} =',
                      style: pw.TextStyle(font: math, fontSize: 19.5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  return document.save();
}
