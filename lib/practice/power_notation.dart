const superscriptDigits = '⁰¹²³⁴⁵⁶⁷⁸⁹';

bool isSuperscriptDigit(String character) =>
    character.length == 1 && superscriptDigits.contains(character);

String superscriptDigit(String digit) => superscriptDigits[int.parse(digit)];

String displayPowers(String text) => text.replaceAllMapped(
  RegExp(r'\^([0-9]+)'),
  (match) => match[1]!.split('').map(superscriptDigit).join(),
);

/// The editor stores visible superscripts; the bounded checker reads ^ notation.
String normalizePowers(String text) => text.replaceAllMapped(
  RegExp('[$superscriptDigits]+'),
  (match) => '^${match[0]!.split('').map(superscriptDigits.indexOf).join()}',
);
