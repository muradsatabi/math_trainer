import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/bank/task_bank.dart';

import 'support/practice_fixture.dart';

void main() {
  test('session snapshot retains hierarchy, IDs and expressions', () async {
    final bank = await fixtureBank('fixture/config.json', fixtureText);
    final restored = TaskBank.fromSnapshot(
      jsonDecode(jsonEncode(bank.toJson())),
    );
    expect(restored.toJson(), bank.toJson());
  });
  test('duplicate IDs reject a corrupted snapshot', () async {
    final bank = await fixtureBank('fixture/config.json', fixtureText);
    final json = bank.toJson();
    (json['blocks'] as List).add((json['blocks'] as List).first);
    expect(() => TaskBank.fromSnapshot(json), throwsFormatException);
  });
}
