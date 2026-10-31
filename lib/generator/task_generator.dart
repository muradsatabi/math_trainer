import 'dart:convert';
import 'dart:math';

enum TaskOrder { grouped, shuffled, increasing }

class ExerciseTemplate {
  const ExerciseTemplate({
    required this.id,
    required this.title,
    required this.family,
    required this.features,
    required this.example,
    this.active = true,
    this.combined = false,
  });
  final String id, title, family, example;
  final List<String> features;
  final bool active, combined;
  int get level => features.length + 1;

  factory ExerciseTemplate.fromJson(Map<String, dynamic> json) =>
      ExerciseTemplate(
        id: json['id'] as String,
        title: json['title'] as String,
        family: json['family'] as String,
        features: (json['features'] as List).cast<String>(),
        example: json['example'] as String,
        active: json['status'] == 'active',
      );
}

List<ExerciseTemplate> loadTemplates(String text) {
  final json = jsonDecode(text) as Map<String, dynamic>;
  if (json['schema_version'] != 1) {
    throw const FormatException('Template schema');
  }
  final result = (json['templates'] as List)
      .map((v) => ExerciseTemplate.fromJson(v as Map<String, dynamic>))
      .toList();
  if (result.map((v) => v.id).toSet().length != result.length) {
    throw const FormatException('Duplicate template ID');
  }
  return List.unmodifiable(result);
}

/// Derived combinations are generation configurations, not newly approved templates.
List<ExerciseTemplate> generationOptions(List<ExerciseTemplate> templates) {
  final result = templates.where((t) => t.active).toList();
  for (final family in ['numeric', 'literal']) {
    final branches = templates
        .where((t) => t.active && t.family == family && t.features.length == 1)
        .toList();
    for (var mask = 1; mask < (1 << branches.length); mask++) {
      final parts = [
        for (var i = 0; i < branches.length; i++)
          if ((mask & (1 << i)) != 0) branches[i],
      ];
      if (parts.length < 2 || parts.length > 5) continue;
      final features = parts.expand((t) => t.features).toList()..sort();
      result.add(
        ExerciseTemplate(
          id: '${family}_combination_${features.join('_')}',
          title: parts.map((t) => t.title).join(' + '),
          family: family,
          features: List.unmodifiable(features),
          example: '',
          combined: true,
        ),
      );
    }
  }
  result.sort((a, b) {
    final byFamily = (a.family == 'numeric' ? 0 : 1).compareTo(
      b.family == 'numeric' ? 0 : 1,
    );
    if (byFamily != 0) return byFamily;
    final byLevel = a.level.compareTo(b.level);
    return byLevel != 0 ? byLevel : a.id.compareTo(b.id);
  });
  return List.unmodifiable(result);
}

class GeneratedExercise {
  const GeneratedExercise(
    this.templateId,
    this.level,
    this.expression,
    this.answer,
  );
  final String templateId, expression, answer;
  final int level;
}

class TemplateTaskGenerator {
  TemplateTaskGenerator({int? seed}) : random = Random(seed);
  final Random random;
  static const maxPerTemplate = 100;
  static const maxTotal = 1000;
  static const _letters = 'abcdefghkmnpqrstuvwxyz';

  List<GeneratedExercise> generate({
    required List<ExerciseTemplate> templates,
    required Map<String, int> quantities,
    TaskOrder order = TaskOrder.grouped,
  }) {
    final byId = {for (final t in templates) t.id: t};
    final total = quantities.values.fold(0, (a, b) => a + b);
    if (quantities.isEmpty || total < 1 || total > maxTotal) {
      throw ArgumentError('Нужно выбрать от 1 до $maxTotal заданий.');
    }
    final seen = <String>{};
    final result = <GeneratedExercise>[];
    for (final entry in quantities.entries) {
      final template = byId[entry.key];
      if (template == null ||
          !template.active ||
          entry.value < 1 ||
          entry.value > maxPerTemplate) {
        throw ArgumentError('Недопустимый шаблон или количество заданий.');
      }
      var attempts = 0;
      var count = 0;
      while (count < entry.value) {
        if (++attempts > entry.value * 100) {
          throw StateError(
            'Не удалось получить достаточно разных заданий. Уменьшите количество.',
          );
        }
        final item = _exercise(template);
        if (!seen.add(item.expression)) continue;
        result.add(item);
        count++;
      }
    }
    if (order == TaskOrder.shuffled) result.shuffle(random);
    if (order == TaskOrder.increasing) {
      result.shuffle(random);
      result.sort((a, b) => a.level.compareTo(b.level));
    }
    return List.unmodifiable(result);
  }

  GeneratedExercise _exercise(ExerciseTemplate template) {
    final f = template.features.toSet();
    final pool = _letters.split('')..shuffle(random);
    var cursor = 0;
    String letter() => pool[cursor++];
    String power(String v) =>
        f.contains('powers') ? '$v${random.nextBool() ? '²' : '³'}' : v;
    String residual() {
      final a = power(letter());
      return f.contains('two_letters') ? '$a${power(letter())}' : a;
    }

    final isNumeric = template.family == 'numeric';
    if (!isNumeric && template.family != 'literal') {
      throw ArgumentError('Unknown family');
    }
    final common = isNumeric ? '${2 + random.nextInt(11)}' : letter();
    final count = f.contains('three_terms') ? 3 : 2;
    final unit = f.contains('unit');
    final residuals = <String>[];
    for (var i = 0; i < count; i++) {
      residuals.add(unit && i == count - 1 ? '' : residual());
    }
    if (f.contains('bracket')) {
      residuals[0] = '(${residuals[0]} + ${residual()})';
    }
    final coefficients = List.filled(count, 1);
    if (isNumeric && f.contains('different')) {
      // Vary both remaining coefficients. Their gcd is one, so the common
      // numeric factor is exactly the generated k; unit terms remain k.
      do {
        for (var i = 0; i < count; i++) {
          coefficients[i] = unit && i == count - 1 ? 1 : 1 + random.nextInt(9);
        }
      } while (coefficients.toSet().length == 1 ||
          coefficients.reduce((a, b) => a.gcd(b)) != 1);
    }
    final rightIndex = random.nextInt(unit ? count - 1 : count);
    final originals = <String>[];
    final answers = <String>[];
    for (var i = 0; i < count; i++) {
      final rest = residuals[i];
      if (isNumeric) {
        final coefficient = int.parse(common) * coefficients[i];
        originals.add(
          rest.isEmpty
              ? '$coefficient'
              : f.contains('position') && i == rightIndex
              ? '$rest · $coefficient'
              : '$coefficient$rest',
        );
        answers.add(
          rest.isEmpty
              ? '1'
              : '${coefficients[i] == 1 ? '' : coefficients[i]}$rest',
        );
      } else {
        final fromPower = f.contains('factor_power') && i == 0;
        final exponent = fromPower ? 2 + random.nextInt(2) : 1;
        final displayedCommon = exponent == 1
            ? common
            : '$common${exponent == 2 ? '²' : '³'}';
        originals.add(
          rest.isEmpty
              ? common
              : f.contains('position') && i == rightIndex
              ? '$rest$displayedCommon'
              : '$displayedCommon$rest',
        );
        answers.add(
          rest.isEmpty
              ? '1'
              : '${exponent == 3
                    ? '$common²'
                    : exponent == 2
                    ? common
                    : ''}$rest',
        );
      }
    }
    // Draw signs once rather than independently for the two equal forms.
    final signs = [
      for (var i = 1; i < count; i++)
        f.contains('subtraction') && (i == 1 || random.nextBool())
            ? ' − '
            : ' + ',
    ];
    String withSigns(List<String> values) =>
        values.first +
        [for (var i = 1; i < count; i++) '${signs[i - 1]}${values[i]}'].join();
    return GeneratedExercise(
      template.id,
      template.level,
      withSigns(originals),
      '$common(${withSigns(answers)})',
    );
  }
}
