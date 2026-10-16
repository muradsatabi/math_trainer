import 'package:flutter/material.dart';

import '../demo_screens.dart';

/// The V3 layout: three groups, each a grid with two columns and three rows.
/// Additional digit/letter pages keep every source symbol reachable.
class AnswerKeyboard extends StatefulWidget {
  const AnswerKeyboard({
    super.key,
    required this.letters,
    this.requiredDigits = const [],
    required this.enabled,
    required this.compact,
    required this.onInsert,
  });

  final List<String> letters;
  final List<String> requiredDigits;
  final bool enabled;
  final bool compact;
  final ValueChanged<String> onInsert;

  @override
  State<AnswerKeyboard> createState() => _AnswerKeyboardState();
}

class _AnswerKeyboardState extends State<AnswerKeyboard> {
  int digitPage = 0;
  int letterPage = 0;

  Widget _group(
    String title,
    List<String> symbols,
    ScreenColors c, {
    VoidCallback? onPage,
    String? pageLabel,
  }) {
    return Column(
      key: ValueKey('bank-key-group-$title'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: screenText(widget.compact ? 15 : 16, c.sub)),
        SizedBox(height: widget.compact ? 6 : 8),
        for (
          var row = 0;
          row < ((symbols.length + 1) ~/ 2).clamp(3, 99);
          row++
        ) ...[
          if (row > 0) SizedBox(height: widget.compact ? 6 : 8),
          Row(
            children: [
              for (var col = 0; col < 2; col++) ...[
                if (col > 0) SizedBox(width: widget.compact ? 6 : 8),
                Expanded(
                  child: _key(symbols.elementAtOrNull(row * 2 + col), c),
                ),
              ],
            ],
          ),
        ],
        if (onPage != null)
          TextButton(
            key: ValueKey('bank-page-$title'),
            onPressed: widget.enabled ? onPage : null,
            child: Text(pageLabel!),
          ),
      ],
    );
  }

  Widget _key(String? symbol, ScreenColors c) => OutlinedButton(
    key: symbol == null ? null : ValueKey('bank-symbol-$symbol'),
    onPressed: !widget.enabled || symbol == null
        ? null
        : () => widget.onInsert(symbol),
    style: OutlinedButton.styleFrom(
      foregroundColor: c.ink,
      backgroundColor: c.paper,
      side: BorderSide(color: c.line),
      visualDensity: VisualDensity.standard,
      minimumSize: Size(0, widget.compact ? 44 : 54),
      padding: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Text(
      symbol ?? '',
      style: TextStyle(
        fontFamily: 'Caladea',
        fontSize: widget.compact ? 26 : 28,
        height: 1.2,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = ScreenColors(context);
    final allDigits = <String>{
      ...widget.requiredDigits,
      '1',
      '2',
      '3',
      '4',
      '6',
      '9',
      '0',
      '5',
      '7',
      '8',
    }.toList();
    // Keep every required digit visible together; extra digits remain paged.
    final digitPageSize = widget.requiredDigits.length > 6
        ? widget.requiredDigits.length
        : 6;
    final digitPages = (allDigits.length / digitPageSize).ceil();
    final digits =
        allDigits
            .skip((digitPage % digitPages) * digitPageSize)
            .take(digitPageSize)
            .toList()
          ..sort();
    final allLetters = <String>{...widget.letters};
    final letterPageSize = (allLetters.length + 2).clamp(6, 52);
    for (final letter in 'abcxyzmnkpqrstuvdefghijlow'.split('')) {
      if (allLetters.length >= letterPageSize) break;
      allLetters.add(letter);
    }
    final pages = (allLetters.length / letterPageSize).ceil().clamp(1, 100);
    final letters =
        allLetters
            .skip((letterPage % pages) * letterPageSize)
            .take(letterPageSize)
            .toList()
          ..sort();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _group(
            'Числа',
            digits,
            c,
            onPage: digitPages > 1 ? () => setState(() => digitPage++) : null,
            pageLabel: 'Другие числа',
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _group(
            'Буквы',
            letters,
            c,
            onPage: pages > 1 ? () => setState(() => letterPage++) : null,
            pageLabel: 'Другие буквы',
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _group('Знаки и скобки', ['+', '−', '×', '÷', '(', ')'], c),
        ),
      ],
    );
  }
}
