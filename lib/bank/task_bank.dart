import 'dart:convert';

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
  }) : acceptedExamples = List.unmodifiable(acceptedExamples) {
    if (id.isEmpty ||
        revision < 1 ||
        instruction.isEmpty ||
        expression.isEmpty ||
        expectedAnswer.isEmpty ||
        methodicalStatus != 'approved') {
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

  factory BankTask.fromJson(Map<String, dynamic> json) => BankTask(
    id: json['task_id'] as String,
    revision: json['revision'] as int,
    instruction: json['instruction'] as String,
    expression: json['expression'] as String,
    expectedAnswer: json['expected_answer'] as String,
    acceptedExamples: (json['accepted_examples'] as List).cast<String>(),
    methodicalStatus: json['methodical_status'] as String,
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

  static Future<TaskBank> load(String manifestPath, BankTextReader read) async {
    final manifest =
        jsonDecode(await read(manifestPath)) as Map<String, dynamic>;
    if (manifest['schema_version'] != 1) {
      throw const FormatException('Unsupported bank manifest schema');
    }
    final blocks = <BankBlock>[];
    for (final path in (manifest['blocks'] as List).cast<String>()) {
      final blockJson = jsonDecode(await read(path)) as Map<String, dynamic>;
      final block = BankBlock.fromJson(blockJson);
      final ref = blockJson['micro_skill_ref'] as Map<String, dynamic>;
      final skill = jsonDecode(
        await read('bank/skills/${ref['id']}.json'),
      ) as Map<String, dynamic>;
      if (skill['schema_version'] != 1 ||
          skill['micro_skill_id'] != ref['id'] ||
          skill['revision'] != ref['revision'] ||
          skill['title'] != block.skill ||
          skill['topic_id'] != manifest['topic_id']) {
        throw FormatException('Invalid micro-skill reference: ${block.id}');
      }
      blocks.add(block);
    }
    return TaskBank(
      topicId: manifest['topic_id'] as String,
      title: manifest['title'] as String,
      blocks: blocks,
    );
  }
}
