import 'answer_form.dart';

// Recognizes the agreed forms of the demo factorization, not general algebra.
bool isCorrectDemoAnswer(String record) {
  if (!isCompleteAnswer(record)) return false;
  final text = record.replaceAll(RegExp(r'\s+'), '');
  const term = r'(?:2[×*]?x|x[×*]2)';
  const sum = '(?:$term\\+3|3\\+$term)';
  return RegExp('^(?:3[×*]?\\($sum\\)|\\($sum\\)[×*]?3)\$').hasMatch(text);
}
