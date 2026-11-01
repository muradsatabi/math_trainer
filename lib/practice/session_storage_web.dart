import 'package:web/web.dart' as web;

const _key = 'math_trainer.generated_sessions.v1';
String? readPracticeHistory() => web.window.localStorage.getItem(_key);
void writePracticeHistory(String value) =>
    web.window.localStorage.setItem(_key, value);
