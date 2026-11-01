import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'task_generator.dart';
import 'worksheet_test_choices.dart';

Future<Uint8List> buildWorksheetPdf({
  required List<GeneratedExercise> exercises,
  required ByteData textFont,
  required ByteData mathFont,
  bool landscape = true,
  int columns = 2,
  bool includeAnswers = false,
  bool testMode = false,
}) => buildWorksheetVariantsPdf(
  variants: [exercises],
  textFont: textFont,
  mathFont: mathFont,
  landscape: landscape,
  columns: columns,
  includeAnswers: includeAnswers,
  testMode: testMode,
);

Future<Uint8List> buildWorksheetVariantsPdf({
  required List<List<GeneratedExercise>> variants,
  required ByteData textFont,
  required ByteData mathFont,
  bool landscape = true,
  int columns = 2,
  bool includeAnswers = false,
  bool testMode = false,
}) async {
  if (variants.isEmpty ||
      variants.length > TemplateTaskGenerator.maxVariants ||
      variants.any(
        (exercises) =>
            exercises.isEmpty ||
            exercises.length > TemplateTaskGenerator.maxTotal,
      )) {
    throw ArgumentError('Invalid worksheet size');
  }
  if (columns < 1 || columns > 3) {
    throw ArgumentError.value(columns, 'columns', 'Expected 1, 2 or 3');
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
  final testItems = testMode ? worksheetTestItems(variants) : null;
  const gap = 5.5;
  final columnWidth = (width - 27 - gap * (columns - 1)) / columns;
  for (final answers in [false, if (includeAnswers) true]) {
    final quiz = testMode && !answers;
    final rows = quiz ? (landscape ? 3 : 5) : (20 / columns).ceil();
    final tasksPerPage = quiz ? rows * columns : 20;
    final rowStep = (landscape ? 150.0 : 230.0) / rows;
    for (var variant = 0; variant < variants.length; variant++) {
      final exercises = variants[variant];
      for (var offset = 0; offset < exercises.length; offset += tasksPerPage) {
        final tasks = exercises.skip(offset).take(tasksPerPage).toList();
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
                    answers ? 'Ответы — Вариант ${variant + 1}' : 'Имя: __________________________   Класс: ______   Дата: ______________',
                    style: pw.TextStyle(font: text, fontSize: 12),
                  ),
                ),
                if (!answers)
                  pw.Positioned(
                    left: 17 * mm,
                    top: 27 * mm,
                    child: pw.Text(
                      quiz
                          ? 'Вариант ${variant + 1}. Выбери верное вынесение общего множителя:'
                          : 'Вариант ${variant + 1}. Вынеси общий множитель за скобки:',
                      style: pw.TextStyle(font: text, fontSize: 12),
                    ),
                  ),
                for (var i = 0; i < tasks.length; i++)
                  pw.Positioned(
                    left: (17 + (i ~/ rows) * (columnWidth + gap)) * mm,
                    top: ((answers ? 30 : 43) + (i % rows) * rowStep) * mm,
                    child: pw.SizedBox(
                      width: columnWidth * mm,
                      height:
                          (quiz ? rowStep - 3 : (rowStep < 10 ? rowStep : 10)) *
                          mm,
                      child: pw.FittedBox(
                        alignment: pw.Alignment.topLeft,
                        fit: pw.BoxFit.scaleDown,
                        child: quiz
                            ? pw.Column(
                                mainAxisSize: pw.MainAxisSize.min,
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    '${offset + i + 1}. ${tasks[i].expression}',
                                    style: pw.TextStyle(
                                      font: math,
                                      fontSize: 16,
                                    ),
                                  ),
                                  pw.SizedBox(height: 3 * mm),
                                  for (var c = 0; c < 4; c++)
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.only(
                                        bottom: 1.5 * mm,
                                      ),
                                      child: pw.Text(
                                        '${WorksheetTestItem.labels[c]}) ${testItems![variant][offset + i].choices[c].answer}',
                                        style: pw.TextStyle(
                                          font: math,
                                          fontFallback: [text],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : pw.Text(
                                answers
                                    ? testMode
                                          ? '${offset + i + 1}. ${WorksheetTestItem.labels[testItems![variant][offset + i].correctIndex]}) ${tasks[i].answer}'
                                          : '${offset + i + 1}. ${tasks[i].answer}'
                                    : '${tasks[i].expression} =',
                                style: pw.TextStyle(
                                  font: math,
                                  fontFallback: [text],
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
  }
  return document.save();
}
