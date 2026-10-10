import 'package:flutter/material.dart';

import 'demo_screens.dart';
import 'completion_screens.dart';
import 'explanation_panel.dart';
import 'answer_form.dart';
import 'demo_answer.dart';
import 'practice_record.dart';
import 'main.dart' show PracticeScreen;

// Known demo records provide specific explanations; they do not gate checking.
const constructorRecords = ['3(2x+9)', '3(2x+3)', '3(3x+2)', '3(2x−3)'];

class ConstructorScreen extends StatefulWidget {
  const ConstructorScreen({super.key, this.previousRecord});
  final PracticeRecord? previousRecord;
  @override
  State<ConstructorScreen> createState() => _ConstructorScreenState();
}

class _ConstructorScreenState extends State<ConstructorScreen> {
  final entry = TextEditingController();
  bool checked = false, explanation = false, incomplete = false;
  int get answer => constructorRecords.indexOf(entry.text.replaceAll(' ', ''));
  bool get complete => isCompleteAnswer(entry.text);
  bool get correct => isCorrectDemoAnswer(entry.text);
  @override
  void dispose() {
    entry.dispose();
    super.dispose();
  }

  void insert(String symbol) {
    final at = entry.selection.baseOffset.clamp(0, entry.text.length);
    entry.value = TextEditingValue(
      text: entry.text.substring(0, at) + symbol + entry.text.substring(at),
      selection: TextSelection.collapsed(offset: at + symbol.length),
    );
    setState(() {
      if (complete) incomplete = false;
    });
  }

  Widget _actions(BuildContext context, bool wide, bool compact) {
    final c = ScreenColors(context);
    final action = LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          if (widget.previousRecord != null) ...[
            SizedBox(
              width: (constraints.maxWidth - 48) / 3,
              child: SecondaryAction(
                label: 'Предыдущее задание',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (previewContext) => PracticeScreen(
                      record: widget.previousRecord,
                      onReturnToCurrent: () =>
                          Navigator.of(previewContext).pop(),
                    ),
                  ),
                ),
                compact: compact,
              ),
            ),
            const SizedBox(width: 24),
          ],
          Expanded(
            flex: 2,
            child: FilledButton(
              key: const ValueKey('constructor-check'),
              onPressed: checked
                  ? () => openDemo(
                      context,
                      RecapScreen(firstRecord: widget.previousRecord),
                    )
                  : complete
                  ? () => setState(() => checked = true)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: c.blue,
                disabledBackgroundColor: c.blue.withValues(alpha: .55),
                disabledForegroundColor: Colors.white.withValues(alpha: .55),
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, compact ? 50 : 58),
                textStyle: screenText(
                  wide ? 20 : 17,
                  Colors.white,
                  heading: true,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(checked ? 'Дальше' : 'Проверить себя'),
            ),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, bounds) => bounds.maxWidth < 720
          ? Container(
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Colors.transparent)),
              ),
              padding: const EdgeInsets.only(right: 30),
              child: action,
            )
          : DemoColumns(
              wide: wide,
              left: Container(
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Colors.transparent)),
                ),
                padding: EdgeInsets.only(right: wide ? 42 : 30),
                child: action,
              ),
              right: const SizedBox.shrink(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) => DemoPage(
    footerBuilder: _actions,
    visibleScrollbar: true,
    topic: 'Общий множитель за скобками',
    showSuccess: true,
    bodyBuilder: (context, wide, compact) {
      final c = ScreenColors(context);
      final groups = [
        ('Числа', ['1', '2', '3', '4', '6', '9']),
        ('Буквы', ['x', 'y', 'a', 'b', 'c', 'm']),
        ('Знаки и скобки', ['+', '−', '×', '÷', '(', ')']),
      ];
      final recordColor = !checked
          ? c.paper
          : correct
          ? Color(c.dark ? 0xff233e35 : 0xffeaf6ee)
          : Color(c.dark ? 0xff452e36 : 0xfffff0ee);
      final border = !checked
          ? c.blue
          : correct
          ? Color(c.dark ? 0xff68c98b : 0xff28934c)
          : Color(c.dark ? 0xffb97e84 : 0xffcf7772);
      return DemoColumns(
        wide: wide,
        left: Container(
          padding: EdgeInsets.only(right: wide ? 42 : 30),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: c.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Вынеси общий множитель за скобки:',
                style: screenText(compact ? 19 : 23, c.ink),
              ),
              SizedBox(height: compact ? 8 : 16),
              DemoMath('6x + 9', size: compact ? 42 : 54),
              SizedBox(height: compact ? 12 : 20),
              Text(
                'Собери ответ:',
                style: screenText(compact ? 15 : 18, c.sub),
              ),
              const SizedBox(height: 12),
              TextFieldTapRegion(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: compact ? 56 : 72,
                      decoration: BoxDecoration(
                        color: recordColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border, width: 2),
                      ),
                      child: TextField(
                        key: const ValueKey('assembly'),
                        controller: entry,
                        readOnly: true,
                        showCursor: !checked,
                        enableInteractiveSelection: !checked,
                        onTapOutside: (_) {
                          if (!checked && entry.text.isNotEmpty && !complete) {
                            setState(() => incomplete = true);
                          }
                        },
                        style: TextStyle(
                          fontFamily: 'Cambria',
                          fontSize: compact ? 30 : 32,
                          height: 1.2,
                          color: c.ink,
                        ),
                        decoration: InputDecoration(
                          visualDensity: VisualDensity.standard,
                          constraints: BoxConstraints.tightFor(
                            height: compact ? 56 : 72,
                          ),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 32,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: compact ? 22 : 24,
                            vertical: compact ? 6 : 14,
                          ),
                          suffixIcon: checked
                              ? Icon(
                                  correct ? Icons.check : Icons.close,
                                  color: border,
                                )
                              : null,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          key: const ValueKey('delete-symbol'),
                          onPressed: checked
                              ? null
                              : () {
                                  final at = entry.selection.baseOffset.clamp(
                                    0,
                                    entry.text.length,
                                  );
                                  if (at > 0) {
                                    entry.value = TextEditingValue(
                                      text:
                                          entry.text.substring(0, at - 1) +
                                          entry.text.substring(at),
                                      selection: TextSelection.collapsed(
                                        offset: at - 1,
                                      ),
                                    );
                                    setState(() {});
                                  }
                                },
                          icon: const Icon(Icons.backspace_outlined, size: 20),
                          label: const Text('Удалить символ'),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          key: const ValueKey('clear-entry'),
                          onPressed: checked
                              ? null
                              : () {
                                  entry.clear();
                                  setState(() => incomplete = false);
                                },
                          child: const Text('Очистить'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var g = 0; g < groups.length; g++) ...[
                          if (g > 0) const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  groups[g].$1,
                                  style: screenText(compact ? 15 : 16, c.sub),
                                ),
                                SizedBox(height: compact ? 6 : 8),
                                for (var r = 0; r < 3; r++) ...[
                                  if (r > 0) SizedBox(height: compact ? 6 : 8),
                                  Row(
                                    children: [
                                      for (var col = 0; col < 2; col++) ...[
                                        if (col > 0)
                                          SizedBox(width: compact ? 6 : 8),
                                        Expanded(
                                          child: OutlinedButton(
                                            key: ValueKey(
                                              'symbol-${groups[g].$2[r * 2 + col]}',
                                            ),
                                            onPressed: checked
                                                ? null
                                                : () => insert(
                                                    groups[g].$2[r * 2 + col],
                                                  ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: c.ink,
                                              backgroundColor: c.paper,
                                              side: BorderSide(color: c.line),
                                              visualDensity:
                                                  VisualDensity.standard,
                                              minimumSize: Size(
                                                0,
                                                compact ? 44 : 54,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 4,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: DemoMath(
                                              groups[g].$2[r * 2 + col],
                                              size: compact ? 26 : 28,
                                              height: 1.2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (incomplete && !complete)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Ты не закончил запись. Допиши ответ',
                    style: screenText(16, c.sub),
                  ),
                ),
              SizedBox(height: compact ? 16 : 24),
            ],
          ),
        ),
        right: !checked
            ? const SizedBox.shrink()
            : correct
            ? Container(
                margin: const EdgeInsets.only(top: 44),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: recordColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check, color: border),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Абсолютно\nверно!',
                        style: screenText(23, c.ink, heading: true),
                      ),
                    ),
                  ],
                ),
              )
            : explanation
            ? SizedBox(
                height: compact ? 430 : 550,
                child: ExplanationPanel(
                  answer: answer,
                  wide: wide,
                  background: c.help,
                  ink: c.ink,
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(top: 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Пока не получилось!',
                      style: screenText(24, c.blue, heading: true),
                    ),
                    const SizedBox(height: 22),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => explanation = true),
                      icon: const Icon(Icons.lightbulb_outline),
                      label: const Text('Узнать, как правильно'),
                    ),
                  ],
                ),
              ),
      );
    },
  );
}
