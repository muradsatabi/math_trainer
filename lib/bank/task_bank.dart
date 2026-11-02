/// Demonstration feedback saved with a generated exercise, not approved content.
class DemoAnswerChoice {
  const DemoAnswerChoice(
    this.answer, {
    this.errorId,
    this.hint,
    this.isPartial = false,
  });
  final String answer;
  final String? errorId, hint;
  final bool isPartial;
  Map<String, dynamic> toJson() => {
    'answer': answer,
    if (errorId != null) 'error_id': errorId,
    if (hint != null) 'hint': hint,
    if (isPartial) 'is_partial': true,
  };
  factory DemoAnswerChoice.fromJson(Map<String, dynamic> json) =>
      DemoAnswerChoice(
        json['answer'] as String,
        errorId: json['error_id'] as String?,
        hint: json['hint'] as String?,
        isPartial: json['is_partial'] as bool? ?? false,
      );
}

/// Published content is separate from practice results and UI state.
class BankTask {
  BankTask({
    required this.id,
    required this.revision,
    required this.instruction,
    required this.expression,
    required this.expectedAnswer,
    required List<String> acceptedExamples,
    required this.methodicalStatus,
    this.templateId,
    this.operation = 'factor',
    this.requireCompleteFactor = false,
    List<DemoAnswerChoice>? demoChoices,
  }) : demoChoices = demoChoices == null
           ? null
           : List.unmodifiable(demoChoices),
       acceptedExamples = List.unmodifiable(acceptedExamples) {
    if (id.isEmpty ||
        revision < 1 ||
        instruction.isEmpty ||
        expression.isEmpty ||
        expectedAnswer.isEmpty ||
        (methodicalStatus != 'approved' &&
            !(methodicalStatus == 'generated' && templateId != null))) {
      throw const FormatException('Incomplete or unapproved bank task');
    }
  }

  final String id;
  final int revision;
  final String instruction;
  final String expression;
  final String expectedAnswer;

  /// Examples are not an exhaustive whitelist of mathematically valid answers.
  final List<String> acceptedExamples;
  final String methodicalStatus;
  final String? templateId;
  final String operation;
  final bool requireCompleteFactor;
  final List<DemoAnswerChoice>? demoChoices;

  Map<String, dynamic> toJson() => {
    'task_id': id,
    'revision': revision,
    'instruction': instruction,
    'expression': expression,
    'expected_answer': expectedAnswer,
    'accepted_examples': acceptedExamples,
    'methodical_status': methodicalStatus,
    if (templateId != null) 'template_id': templateId,
    if (operation != 'factor') 'operation': operation,
    if (requireCompleteFactor) 'require_complete_factor': true,
    if (demoChoices != null)
      'demo_choices_v1': demoChoices!.map((c) => c.toJson()).toList(),
  };

  factory BankTask.fromJson(Map<String, dynamic> json) => BankTask(
    id: json['task_id'] as String,
    revision: json['revision'] as int,
    instruction: json['instruction'] as String,
    expression: json['expression'] as String,
    expectedAnswer: json['expected_answer'] as String,
    acceptedExamples: (json['accepted_examples'] as List).cast<String>(),
    methodicalStatus: json['methodical_status'] as String,
    templateId: json['template_id'] as String?,
    operation: json['operation'] as String? ?? 'factor',
    requireCompleteFactor: json['require_complete_factor'] as bool? ?? false,
    demoChoices: (json['demo_choices_v1'] as List?)
        ?.map((v) => DemoAnswerChoice.fromJson(Map<String, dynamic>.from(v)))
        .toList(),
  );
}

class BankBlock {
  BankBlock({
    required this.id,
    required this.title,
    required this.skill,
    required this.sourceSectionId,
    required List<BankTask> tasks,
  }) : tasks = List.unmodifiable(tasks) {
    if (id.isEmpty || title.isEmpty || skill.isEmpty || tasks.isEmpty) {
      throw const FormatException('Incomplete bank block');
    }
  }

  final String id;
  final String title;
  final String skill;

  /// Preserved source value, not a dependency or an approved catalog level.
  final String sourceSectionId;
  final List<BankTask> tasks;

  Map<String, dynamic> toJson() => {
    'schema_version': 1,
    'block_id': id,
    'title': title,
    'skill': skill,
    'source_section_id': sourceSectionId,
    'tasks': tasks.map((t) => t.toJson()).toList(),
  };

  factory BankBlock.fromJson(Map<String, dynamic> json) {
    if (json['schema_version'] != 1) {
      throw const FormatException('Unsupported bank schema');
    }
    return BankBlock(
      id: json['block_id'] as String,
      title: json['title'] as String,
      skill: json['skill'] as String,
      sourceSectionId: json['source_section_id'] as String,
      tasks: (json['tasks'] as List)
          .map((value) => BankTask.fromJson(value as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// The reader can be backed by Flutter assets, files or a future remote source.
typedef BankTextReader = Future<String> Function(String path);

class TaskBank {
  TaskBank({
    required this.topicId,
    required this.title,
    required List<BankBlock> blocks,
  }) : blocks = List.unmodifiable(blocks) {
    if (topicId.isEmpty || title.isEmpty || blocks.isEmpty) {
      throw const FormatException('Incomplete topic');
    }
    final blockIds = <String>{};
    final taskIds = <String>{};
    for (final block in blocks) {
      if (!blockIds.add(block.id)) {
        throw FormatException('Duplicate block ID: ${block.id}');
      }
      for (final task in block.tasks) {
        if (!taskIds.add(task.id)) {
          throw FormatException('Duplicate task ID: ${task.id}');
        }
      }
    }
  }

  final String topicId;
  final String title;
  final List<BankBlock> blocks;
  int get taskCount => blocks.fold(0, (sum, block) => sum + block.tasks.length);

  Map<String, dynamic> toJson() => {
    'topic_id': topicId,
    'title': title,
    'blocks': blocks.map((b) => b.toJson()).toList(),
  };

  factory TaskBank.fromSnapshot(Map<String, dynamic> json) => TaskBank(
    topicId: json['topic_id'] as String,
    title: json['title'] as String,
    blocks: (json['blocks'] as List)
        .map((b) => BankBlock.fromJson(Map<String, dynamic>.from(b)))
        .toList(),
  );
}
