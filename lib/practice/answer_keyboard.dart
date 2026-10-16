import 'package:flutter/material.dart';

import '../demo_screens.dart';

/// The V3 layout: three groups, each a grid with two columns and three rows.
/// Additional digit/letter pages keep every source symbol reachable.
class AnswerKeyboard extends StatefulWidget {
  const AnswerKeyboard({
    super.key,
    required this.letters,
    this.requiredDigits = const [],
    this.message,
    required this.enabled,
    required this.compact,
    required this.onInsert,
  });

  final List<String> letters;
  final List<String> requiredDigits;
  final String? message;
  final bool enabled;
  final bool compact;
  final ValueChanged<String> onInsert;

  @override
  State<AnswerKeyboard> createState() => _AnswerKeyboardState();
}

class _AnswerKeyboardState extends State<AnswerKeyboard> {
  int digitPage = 0;
  int letterPage = 0;

  Widget _group(String title, List<String> symbols, ScreenColors c) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _group('Числа', digits, c)),
            const SizedBox(width: 24),
            Expanded(child: _group('Буквы', letters, c)),
            const SizedBox(width: 24),
            Expanded(
              child: _group('Знаки и скобки', [
                '+',
                '−',
                '×',
                '÷',
                '(',
                ')',
              ], c),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, bounds) => Row(
            children: [
              SizedBox(
                width: (bounds.maxWidth - 48) / 3,
                child: digitPages > 1
                    ? TextButton(
                        key: const ValueKey('bank-page-Числа'),
                        onPressed: widget.enabled
                            ? () => setState(() => digitPage++)
                            : null,
                        child: const Text('Другие числа'),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (pages > 1)
                      TextButton(
                        key: const ValueKey('bank-page-Буквы'),
                        onPressed: widget.enabled
                            ? () => setState(() => letterPage++)
                            : null,
                        child: const Text('Другие буквы'),
                      ),
                    if (widget.message != null)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          widget.message!,
                          key: const ValueKey('bank-input-message'),
                          style: screenText(16, c.ink, height: 1.5),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
