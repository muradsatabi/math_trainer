import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/bank/factor_answer_checker.dart';
import 'package:math_trainer/generator/task_generator.dart';
import 'package:math_trainer/generator/worksheet_pdf.dart';

String expandPowers(String s) => s.replaceAllMapped(
  RegExp(r'([a-z])([²³])'),
  (m) => List.filled(m[2] == '²' ? 2 : 3, m[1]!).join(),
);

void main() {
  final templates = loadTemplates(
    File('bank/templates/common_factor.json').readAsStringSync(),
  );
  final options = generationOptions(templates);

  test('30 distinct variants keep 35 tasks and template counts, export with answers', () async {
    final selected = templates
        .where((t) => t.active && t.family == 'numeric')
        .toList();
    final quantities = {for (final t in selected) t.id: 5};
    final variants = TemplateTaskGenerator(
      seed: 61,
    ).generateVariants(templates: selected, quantities: quantities, count: 30);
    expect(variants.length, 30);
    final signatures = <String>{};
    for (final tasks in variants) {
      expect(tasks.length, 35);
      expect(tasks.map((t) => t.expression).toSet().length, 35);
      for (final t in selected) {
        expect(tasks.where((task) => task.templateId == t.id).length, 5);
      }
      signatures.add(
        (tasks.map((t) => t.expression).toList()..sort()).join('|'),
      );
    }
    expect(signatures.length, 30);
    final repeated = TemplateTaskGenerator(
      seed: 61,
    ).generateVariants(templates: selected, quantities: quantities, count: 30);
    expect(
      repeated.map((v) => v.map((t) => t.expression).toList()).toList(),
      variants.map((v) => v.map((t) => t.expression).toList()).toList(),
    );
    for (final count in [0, 101]) {
      expect(
        () => TemplateTaskGenerator().generateVariants(
          templates: selected,
          quantities: quantities,
          count: count,
        ),
        throwsArgumentError,
      );
    }
    final bytes = await buildWorksheetVariantsPdf(
      variants: variants,
      textFont: ByteData.sublistView(
        File('assets/fonts/Carlito-Regular.ttf').readAsBytesSync(),
      ),
      mathFont: ByteData.sublistView(
        File('assets/fonts/Caladea-Regular.ttf').readAsBytesSync(),
      ),
      includeAnswers: true,
    );
    File('.dart_tool/worksheet-30-variants.pdf').writeAsBytesSync(bytes);
  });

  test(
    'all active templates and combinations produce unique exact identities',
    () {
      expect(templates.length, 21);
      expect(templates.where((t) => t.active).length, 16);
      expect(
        options.where((t) => t.combined && t.family == 'numeric').length,
        56,
      );
      expect(
        options.where((t) => t.combined && t.family == 'literal').length,
        210,
      );
      for (final seed in [7, 41, 2026]) {
        final tasks = TemplateTaskGenerator(seed: seed).generate(
          templates: options,
          quantities: {for (final t in options) t.id: 3},
        );
        expect(tasks.length, 846);
        expect(tasks.map((t) => t.expression).toSet().length, tasks.length);
        for (final task in tasks) {
          expect(
            equivalentExpressions(
              expandPowers(task.expression),
              expandPowers(task.answer),
            ),
            isTrue,
            reason: '${task.templateId}: ${task.expression} = ${task.answer}',
          );
        }
      }
    },
  );

  test(
    'counts, levels, order, reproducibility and rejection of invalid requests',
    () {
      final chosen = {for (final t in options.take(8)) t.id: 10};
      List<GeneratedExercise> run(TaskOrder order) =>
          TemplateTaskGenerator(seed: 8)
              .generate(templates: options, quantities: chosen, order: order);
      final grouped = run(TaskOrder.grouped);
      expect(
        grouped.map((t) => t.expression),
        run(TaskOrder.grouped).map((t) => t.expression),
      );
      for (final entry in chosen.entries) {
        expect(
          grouped.where((t) => t.templateId == entry.key).length,
          entry.value,
        );
      }
      final sorted = run(TaskOrder.increasing).map((t) => t.level).toList();
      expect(sorted, [...sorted]..sort());
      expect(
        run(TaskOrder.shuffled).map((t) => t.expression).toSet(),
        grouped.map((t) => t.expression).toSet(),
      );
      final gen = TemplateTaskGenerator(seed: 1);
      for (final counts in [
        <String, int>{},
        {'unknown': 10},
        {templates.first.id: 0},
        {templates.first.id: 101},
        {templates.firstWhere((t) => !t.active).id: 10},
        {for (final t in options.take(11)) t.id: 100},
      ]) {
        expect(
          () => gen.generate(templates: templates, quantities: counts),
          throwsArgumentError,
        );
      }
    },
  );

  test('different coefficients vary both residuals; requested features stay present', () {
    final t = templates.firstWhere(
      (t) => t.id == 'numeric_common_factor_tpl_006',
    );
    final tasks = TemplateTaskGenerator(seed: 98)
        .generate(templates: [t], quantities: {t.id: 100});
    final answers = tasks.map((t) => t.answer).join(' ');
    expect(RegExp(r'\([2-9][a-z] \+ [2-9][a-z]\)').hasMatch(answers), isTrue);
    for (final t in options) {
      final task = TemplateTaskGenerator(seed: 5)
          .generate(templates: [t], quantities: {t.id: 1})
          .single;
      if (t.features.contains('subtraction')) {
        expect(task.expression, contains(' − '));
      }
      if (t.features.contains('position') && t.family == 'numeric') {
        expect(task.expression, contains(' · '));
      }
      if (t.features.contains('unit')) {
        expect(task.answer, matches(RegExp(r'[+−] 1\)$')));
      }
      if (t.features.contains('powers')) {
        expect(task.expression, matches(RegExp('[²³]')));
      }
      if (t.features.contains('bracket')) {
        expect(task.expression, contains('('));
      }
      if (t.features.contains('factor_power')) {
        expect(task.expression, matches(RegExp('[²³]')));
      }
    }
  });

  test(
    'worksheet PDF embeds fonts, paginates, and exports examples for visual QA',
    () async {
      final selected = [
        ...options.where((t) => t.level <= 2),
        options.lastWhere((t) => t.family == 'numeric'),
        options.lastWhere((t) => t.family == 'literal'),
      ];
      final tasks = TemplateTaskGenerator(seed: 39).generate(
        templates: options,
        quantities: {for (final t in selected) t.id: 2},
        order: TaskOrder.increasing,
      );
      final bytes = await buildWorksheetPdf(
        exercises: tasks,
        textFont: ByteData.sublistView(
          File('assets/fonts/Carlito-Regular.ttf').readAsBytesSync(),
        ),
        mathFont: ByteData.sublistView(
          File('assets/fonts/Caladea-Regular.ttf').readAsBytesSync(),
        ),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(10000));
      final output = File('.dart_tool/generator-preview.pdf');
      output.parent.createSync(recursive: true);
      output.writeAsBytesSync(bytes);
      expect(tasks.length, 36);
    },
  );
  test('portrait and landscape support answer pages in the same PDF', () async {
    final tasks = TemplateTaskGenerator(seed: 12)
        .generate(templates: options, quantities: {options.first.id: 21});
    for (final landscape in [false, true]) {
      for (final columns in [1, 2, 3]) {
        final bytes = await buildWorksheetPdf(
          exercises: tasks,
          textFont: ByteData.sublistView(
            File('assets/fonts/Carlito-Regular.ttf').readAsBytesSync(),
          ),
          mathFont: ByteData.sublistView(
            File('assets/fonts/Caladea-Regular.ttf').readAsBytesSync(),
          ),
          landscape: landscape,
          columns: columns,
          includeAnswers: true,
        );
        File(
          '.dart_tool/worksheet-${landscape ? 'landscape' : 'portrait'}-$columns-columns-answers.pdf',
        ).writeAsBytesSync(bytes);
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      }
    }
  });
}
