import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'task_generator.dart';

Future<Uint8List> buildWorksheetPdf({
  required List<GeneratedExercise> exercises,
  required ByteData textFont,
  required ByteData mathFont,
  bool landscape = true,
  bool includeAnswers = false,
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
  final format = landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
  const mm = PdfPageFormat.mm;
  final width = format.width / mm;
  final height = format.height / mm;
  for (final answers in [false, if (includeAnswers) true]) {
    for (var offset = 0; offset < exercises.length; offset += 20) {
      final tasks = exercises.skip(offset).take(20).toList();
      document.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Stack(
            children: [
              if (!answers)
                pw.Positioned.fill(
                  child: pw.CustomPaint(
                    painter: (canvas, size) {
                      canvas
                        ..setStrokeColor(const PdfColor(.83, .83, .83))
                        ..setLineWidth(.25);
                      for (var x = 12.0; x <= width - 10; x += 5) {
                        canvas
                          ..moveTo(x * mm, 10 * mm)
                          ..lineTo(x * mm, (height - 35) * mm)
                          ..strokePath();
                      }
                      for (var y = height - 35; y >= 10; y -= 5) {
                        canvas
                          ..moveTo(12 * mm, y * mm)
                          ..lineTo((width - 10) * mm, y * mm)
                          ..strokePath();
                      }
                    },
                  ),
                ),
              pw.Positioned(
                left: 17 * mm,
                top: 13 * mm,
                child: pw.Text(
                  answers ? 'Ответы (по порядку заданий)' : 'Имя: __________________________   Класс: ______   Дата: ______________',
                  style: pw.TextStyle(font: text, fontSize: 12),
                ),
              ),
              if (!answers)
                pw.Positioned(
                  left: 17 * mm,
                  top: 27 * mm,
                  child: pw.Text(
                    'Вынеси общий множитель за скобки:',
                    style: pw.TextStyle(font: text, fontSize: 12),
                  ),
                ),
              for (var i = 0; i < tasks.length; i++)
                pw.Positioned(
                  left: (landscape && i >= 10 ? 150.5 : 17) * mm,
                  top:
                      ((answers ? 30 : 43) +
                          (landscape ? i % 10 : i) * (landscape ? 15 : 11.5)) *
                      mm,
                  child: pw.SizedBox(
                    width: (landscape ? 128 : 176) * mm,
                    height: 10 * mm,
                    child: pw.FittedBox(
                      alignment: pw.Alignment.topLeft,
                      fit: pw.BoxFit.scaleDown,
                      child: pw.Text(
                        answers
                            ? '${offset + i + 1}. ${tasks[i].answer}'
                            : '${tasks[i].expression} =',
                        style: pw.TextStyle(
                          font: math,
                          fontSize: answers ? 16 : 19.5,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
  }
  return document.save();
}
