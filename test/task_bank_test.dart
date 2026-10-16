import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/bank/task_bank.dart';

void main() {
  test('all 110 source records survive import exactly and in order', () async {
    final bank = await TaskBank.load(
      'bank/manifest.json',
      (p) => File(p).readAsString(),
    );
    final snapshot = jsonDecode(
      await File('bank/sources/common_factor_v8.json').readAsString(),
    ) as Map<String, dynamic>;
    final rows = snapshot['rows'] as List;
    expect(bank.blocks.length, 22);
    expect(bank.taskCount, 110);
    var index = 0;
    for (final block in bank.blocks) {
      expect(block.tasks.length, 5);
      for (final task in block.tasks) {
        final row = rows[index++] as List;
        expect(bank.topicId, row[0]);
        expect(block.sourceSectionId, row[1]);
        expect(task.id, row[2]);
        expect(block.title, row[3]);
        expect(block.skill, row[4]);
        expect(task.instruction, row[5]);
        expect(task.expression, row[6]);
        expect(task.expectedAnswer, row[7]);
        expect(task.acceptedExamples, [row[8]]);
        expect(task.methodicalStatus, 'approved');
        expect(task.revision, 1);
      }
    }
    expect(index, rows.length);
  });

  test('missing or mismatched micro-skill stops loading', () async {
    Future<String> read(String path) async {
      final text = await File(path).readAsString();
      if (!path.startsWith('bank/skills/')) return text;
      final skill = jsonDecode(text) as Map<String, dynamic>;
      skill['revision'] = 99;
      return jsonEncode(skill);
    }

    await expectLater(
      TaskBank.load('bank/manifest.json', read),
      throwsFormatException,
    );
  });
}
