import 'package:flutter/material.dart';

// These explanations describe only the demonstration answers from V3.
class DemoExplanation {
  const DemoExplanation(this.mistake, this.expansion);
  final String mistake;
  final String expansion;

  static DemoExplanation forAnswer(int answer) => switch (answer) {
    -1 => const DemoExplanation(
      'Проверь, на какое число нужно разделить каждое слагаемое '
          'при вынесении множителя 3.',
      '',
    ),
    0 => const DemoExplanation(
      'В скобках число 9 не изменилось.',
      '3(2x + 9) = 6x + 27',
    ),
    2 => const DemoExplanation(
      'В скобках изменились оба слагаемых.',
      '3(3x + 2) = 9x + 6',
    ),
    3 => const DemoExplanation(
      'В скобках изменился знак числа.',
      '3(2x − 3) = 6x − 9',
    ),
    _ => throw ArgumentError.value(
      answer,
      'answer',
      'Expected a wrong demo answer',
    ),
  };
}

class ExplanationPanel extends StatefulWidget {
  const ExplanationPanel({
    super.key,
    required this.answer,
    required this.wide,
    required this.background,
    required this.ink,
  });
  final int answer;
  final bool wide;
  final Color background;
  final Color ink;

  @override
  State<ExplanationPanel> createState() => _ExplanationPanelState();
}

class _ExplanationPanelState extends State<ExplanationPanel> {
  final controller = ScrollController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = widget.wide;
    final ink = widget.ink;
    final explanation = DemoExplanation.forAnswer(widget.answer);
    final headingSize = wide ? 23.0 : 21.0;
    final sectionSize = wide ? 19.0 : 16.0;
    const copySize = 15.0;
    final mathSize = wide ? 30.0 : 23.0;
    TextStyle style(double size, double height, {bool bold = false}) =>
        TextStyle(
          fontFamily: 'Carlito',
          fontSize: size,
          height: height,
          color: ink,
          fontWeight: bold ? FontWeight.w500 : FontWeight.w400,
        );
    Widget section(String text) => Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Text(text, style: style(sectionSize, 1.5, bold: true)),
    );
    Widget formula(String text) => Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontFamily: 'Caladea',
            fontSize: mathSize,
            height: wide ? 1.45 : 1.4,
            color: ink,
          ),
          children: [
            for (final char in text.split(''))
              TextSpan(
                text: char,
                style: char == 'x'
                    ? const TextStyle(fontStyle: FontStyle.italic)
                    : null,
              ),
          ],
        ),
        semanticsLabel: text,
      ),
    );
    return Semantics(
      label: 'Разбор ошибки',
      liveRegion: true,
      child: Container(
        key: const ValueKey('explanation-panel'),
        decoration: BoxDecoration(
          color: widget.background,
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Scrollbar(
          controller: controller,
          child: SingleChildScrollView(
            controller: controller,
            key: const ValueKey('explanation-scroll'),
            primary: false,
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 28 : 22,
              vertical: 14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 24, color: ink),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Давай разберёмся',
                        style: style(headingSize, 1.4, bold: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                section('Что не получилось?'),
                Text(explanation.mistake, style: style(copySize, 1.55)),
                if (explanation.expansion.isNotEmpty)
                  formula(explanation.expansion),
                section('Главная мысль'),
                Text(
                  'Каждое слагаемое делим на 3.',
                  style: style(copySize, 1.55),
                ),
                formula('6x : 3 = 2x\n9 : 3 = 3'),
                section('Как правильно'),
                formula('6x + 9 = 3(2x + 3)'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
