import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/bank/factor_answer_checker.dart';
import 'package:math_trainer/generator/task_generator.dart';
import 'package:math_trainer/generator/worksheet_pdf.dart';
import 'package:math_trainer/generator/worksheet_test_choices.dart';

void main() {
  final templates = generationOptions(
    loadTemplates(File('bank/templates/common_factor.json').readAsStringSync()),
  );
  test('every template and combination has four plausible distinct answers with one correct', () {
    final tasks = TemplateTaskGenerator(seed: 75).generate(
      templates: templates,
      quantities: {for (final t in templates) t.id: 2},
    );
    final positions = <int>{};
    final items = worksheetTestItems([tasks], seed: 91).single;
    expect(items.length, 564);
    for (final item in items) {
      expect(item.choices.length, 4);
      expect(item.choices.where((c) => c.errorId == null).length, 1);
      expect(
        item.choices
            .singleWhere((c) => c.errorId == 'last_term_sign_changed')
            .answer
            .length,
        item.exercise.answer.length,
      );
      expect(item.choices.map((c) => c.errorId).toSet(), {
        null,
        'first_term_not_divided',
        'last_term_not_divided',
        'last_term_sign_changed',
      });
      final factor = RegExp(r'^([0-9a-zA-Z]+)\(')
          .firstMatch(item.exercise.answer)![1]!;
      for (var i = 0; i < 4; i++) {
        expect(item.choices[i].answer, startsWith('$factor('));
        expect(
          equivalentExpressions(
            item.choices[i].answer,
            item.exercise.expression,
          ),
          i == item.correctIndex,
        );
        for (var j = 0; j < i; j++) {
          expect(
            equivalentExpressions(
              item.choices[i].answer,
              item.choices[j].answer,
            ),
            false,
          );
        }
      }
      positions.add(item.correctIndex);
    }
    expect(positions, {0, 1, 2, 3});
  });

  test('test worksheets paginate four choices and answer keys in all six layouts', () async {
    final selected = [
      templates.lastWhere((t) => t.family == 'numeric'),
      templates.lastWhere((t) => t.family == 'literal'),
    ];
    final variants = TemplateTaskGenerator(seed: 71).generateVariants(
      templates: selected,
      quantities: {for (final t in selected) t.id: 7},
      count: 2,
      order: TaskOrder.shuffled,
    );
    File('.dart_tool/quiz-expected.json').writeAsStringSync(
      jsonEncode([
        for (final tasks in variants)
          [
            for (final t in tasks)
              {'expression': t.expression, 'answer': t.answer},
          ],
      ]),
    );
    for (final landscape in [false, true]) {
      for (final columns in [1, 2, 3]) {
        final bytes = await buildWorksheetVariantsPdf(
          variants: variants,
          textFont: ByteData.sublistView(
            File('assets/fonts/Carlito-Regular.ttf').readAsBytesSync(),
          ),
          mathFont: ByteData.sublistView(
            File('assets/fonts/Caladea-Regular.ttf').readAsBytesSync(),
          ),
          testMode: true,
          landscape: landscape,
          columns: columns,
          includeAnswers: true,
        );
        File(
          '.dart_tool/quiz-${landscape ? 'landscape' : 'portrait'}-$columns.pdf',
        ).writeAsBytesSync(bytes);
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      }
    }
  });
}
