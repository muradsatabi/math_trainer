// Checks the form of a record, without comparing it with the task's answer.
bool isCompleteAnswer(String record) {
  final text = record.replaceAll(RegExp(r'\s+'), '');
  if (text.isEmpty) return false;
  var depth = 0;
  var needsOperand = true;
  for (var i = 0; i < text.length; i++) {
    final symbol = text[i];
    if (RegExp(r'[0-9a-zA-Z]').hasMatch(symbol)) {
      needsOperand = false;
    } else if (symbol == '(') {
      depth++;
      needsOperand = true;
    } else if (symbol == ')') {
      if (depth == 0 || needsOperand) return false;
      depth--;
      needsOperand = false;
    } else if ('+−-×÷*/'.contains(symbol)) {
      // A leading sign is allowed at the beginning or inside parentheses.
      final leadingSign =
          '+−-'.contains(symbol) && (i == 0 || text[i - 1] == '(');
      if (needsOperand && !leadingSign) return false;
      needsOperand = true;
    } else {
      return false;
    }
  }
  return depth == 0 && !needsOperand;
}
