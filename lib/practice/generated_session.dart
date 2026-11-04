import 'dart:convert';

import '../bank/task_bank.dart';
import '../generator/task_generator.dart';
import 'practice_session.dart';
import 'answer_choices.dart';

const generatedTopicTitles = {
  'numeric': 'Вынесение численного общего множителя за скобки',
  'literal': 'Вынесение буквенного общего множителя за скобки',
  'numeric_bracket': 'Умножение на скобку — числовой множитель',
  'literal_bracket': 'Умножение на скобку — буквенный множитель',
};

String generatedTopicId(String family) => switch (family) {
  'numeric_bracket' => 'numeric_bracket_multiplication',
  'literal_bracket' => 'literal_bracket_multiplication',
  _ => '${family}_common_factor',
};
String generatedTemplatePath(String family) => switch (family) {
  'numeric_bracket' => 'bank/templates/numeric_bracket_multiplication.json',
  'literal_bracket' => 'bank/templates/literal_bracket_multiplication.json',
  _ => 'bank/templates/common_factor.json',
};

/// Snapshot contains the actual exercises, not a recipe to regenerate them.
class GeneratedSession {
  GeneratedSession({
    required this.id,
    required this.createdAt,
    required this.templateSource,
    required this.seed,
    required this.practice,
    this.view,
  });
  final String id, createdAt, templateSource;
  final int seed;
  final PracticeSession practice;
  Map<String, dynamic>? view;

  factory GeneratedSession.start({
    required String family,
    required String source,
    required String id,
    required int seed,
    int perTemplate = 10,
  }) {
    final title = generatedTopicTitles[family];
    if (title == null) throw ArgumentError('Unknown topic');
    final templates = loadTemplates(source)
        .where((t) => t.active && t.family == family)
        .toList();
    final generated = TemplateTaskGenerator(seed: seed).generate(
      templates: templates,
      quantities: {for (final t in templates) t.id: perTemplate},
    );
    final blocks = <BankBlock>[];
    for (final template in templates) {
      final items = generated
          .where((e) => e.templateId == template.id)
          .toList();
      blocks.add(
        BankBlock(
          id: template.id,
          title: template.title,
          skill: template.title,
          sourceSectionId: family,
          tasks: [
            for (var i = 0; i < items.length; i++)
              withDemoChoices(
                withCompleteFactorRule(
                  BankTask(
                    id: '$id/${template.id}/${i + 1}',
                    revision: 1,
                    instruction: template.operation == 'expand'
                        ? 'Раскрой скобки'
                        : 'Вынеси общий множитель за скобки',
                    expression: items[i].expression,
                    expectedAnswer: items[i].answer,
                    acceptedExamples: const [],
                    methodicalStatus: 'generated',
                    templateId: template.id,
                    operation: template.operation,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return GeneratedSession(
      id: id,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      templateSource: source,
      seed: seed,
      practice: PracticeSession(
        bank: TaskBank(
          topicId: generatedTopicId(family),
          title: title,
          blocks: blocks,
        ),
        settings: PracticeSettings(
          minimumAnswers: 10,
          successWindow: 10,
          passPercent: 85,
          extraTasksPerError: 2,
        ),
      ),
    );
  }

  /// Upgrade only untouched stock: attempts and an existing draft retain their
  /// original alternatives. The added feedback is then part of the snapshot.
  GeneratedSession withDemoFeedback() {
    final tried = practice.attempts.map((a) => a.task.id).toSet();
    final currentText = (view?['current'] as Map?)?['text'] as String? ?? '';
    final savedText =
        ((view?['saved_views'] as Map?)?['-1'] as Map?)?['text'] as String? ??
        '';
    if (currentText.isNotEmpty || savedText.isNotEmpty) {
      tried.add(practice.currentTask.id);
    }
    final snapshot = toJson();
    final bank = (snapshot['practice'] as Map)['bank'] as Map;
    for (final block in bank['blocks'] as List) {
      final tasks = (block as Map)['tasks'] as List;
      for (var i = 0; i < tasks.length; i++) {
        final task = BankTask.fromJson(Map<String, dynamic>.from(tasks[i]));
        if (!tried.contains(task.id)) {
          var updated = withDemoChoices(withCompleteFactorRule(task));
          if (updated.methodicalStatus == 'generated' &&
              (updated.demoChoices ?? const <DemoAnswerChoice>[]).any(
                (c) => c.isPartial,
              )) {
            updated = withPartialFollowupChoice(updated, updated.id);
          }
          tasks[i] = updated.toJson();
        }
      }
    }
    return GeneratedSession.fromJson(snapshot);
  }

  Map<String, dynamic> toJson() => {
    'schema_version': 1,
    'generator_version': 3,
    'id': id,
    'created_at': createdAt,
    'template_source': templateSource,
    'seed': seed,
    'practice': practice.toJson(),
    'view': view,
  };

  factory GeneratedSession.fromJson(Map<String, dynamic> json) {
    if (json['schema_version'] != 1 ||
        ![1, 2, 3].contains(json['generator_version'])) {
      throw const FormatException('Unsupported session snapshot');
    }
    final practice = PracticeSession.fromJson(
      Map<String, dynamic>.from(json['practice']),
    );
    return GeneratedSession(
      id: json['id'] as String,
      createdAt: json['created_at'] as String,
      templateSource: json['template_source'] as String,
      seed: json['seed'] as int,
      practice: practice,
      view: json['view'] == null
          ? null
          : Map<String, dynamic>.from(json['view']),
    );
  }
}

String encodeGeneratedSessions(List<GeneratedSession> sessions) => jsonEncode({
  'schema_version': 1,
  'sessions': sessions.map((s) => s.toJson()).toList(),
});

List<GeneratedSession> decodeGeneratedSessions(String text) {
  final json = jsonDecode(text) as Map<String, dynamic>;
  if (json['schema_version'] != 1) {
    throw const FormatException('History version');
  }
  final result = (json['sessions'] as List)
      .map((s) => GeneratedSession.fromJson(Map<String, dynamic>.from(s)))
      .toList();
  if (result.map((s) => s.id).toSet().length != result.length) {
    throw const FormatException('Duplicate session ID');
  }
  return result;
}
