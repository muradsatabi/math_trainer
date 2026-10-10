import 'package:flutter/material.dart';

import 'demo_screens.dart';
import 'explanation_panel.dart';
import 'main.dart';
import 'practice_record.dart';

void viewFirstSolution(
  BuildContext context,
  PracticeRecord record,
  String returnLabel,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (previewContext) => PracticeScreen(
        record: record,
        returnLabel: returnLabel,
        onReturnToCurrent: () => Navigator.of(previewContext).pop(),
      ),
    ),
  );
}

void openDemo(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

class DemoMath extends StatelessWidget {
  const DemoMath(this.value, {super.key, this.size = 30, this.height = 1.45});
  final String value;
  final double size;
  final double height;
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      style: TextStyle(
        fontFamily: 'Cambria',
        fontSize: size,
        height: height,
        color: ScreenColors(context).ink,
      ),
      children: [
        for (final char in value.split(''))
          TextSpan(
            text: char,
            style: 'xyabcm'.contains(char)
                ? const TextStyle(fontStyle: FontStyle.italic)
                : null,
          ),
      ],
    ),
    semanticsLabel: value,
  );
}

class DemoColumns extends StatelessWidget {
  const DemoColumns({
    super.key,
    required this.left,
    required this.right,
    required this.wide,
  });
  final Widget left, right;
  final bool wide;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => bounds.maxWidth < 720
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 16), right],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 226, child: left),
              SizedBox(width: wide ? 44 : 32),
              Expanded(flex: 100, child: right),
            ],
          ),
  );
}

class RecapScreen extends StatelessWidget {
  const RecapScreen({super.key, this.firstRecord, this.onReturnToResults});
  final PracticeRecord? firstRecord;
  final VoidCallback? onReturnToResults;
  Widget _actions(BuildContext context, bool wide, bool compact) {
    return FooterActions(
      children: [
        SecondaryAction(
          label: 'Назад к решению',
          onPressed: firstRecord != null
              ? () => viewFirstSolution(
                  context,
                  firstRecord!,
                  'Вернуться к закреплению',
                )
              : null,
          compact: compact,
        ),
        const SizedBox(width: 12),
        PrimaryAction(
          label: onReturnToResults == null ? 'Дальше' : 'К итогам',
          onPressed:
              onReturnToResults ??
              () => openDemo(context, ResultsScreen(firstRecord: firstRecord)),
          wide: wide,
          compact: compact,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => DemoPage(
    footerBuilder: _actions,
    visibleScrollbar: true,
    bodyBuilder: (context, wide, compact) {
      final c = ScreenColors(context);
      const skills = [
        (
          'Находить общий множитель',
          'Ищем множитель, который есть у обоих слагаемых.',
          '6x = 3 · 2x\n9 = 3 · 3',
        ),
        (
          'Выносить его за скобки',
          'Каждое слагаемое делим на общий множитель. Результаты записываем в скобках.',
          '6x + 9 =\n3(2x + 3)',
        ),
        (
          'Проверять полученную запись',
          'Раскрываем скобки: должно получиться исходное выражение.',
          '3(2x + 3) =\n6x + 9',
        ),
      ];
      return SharedField(
        wide: wide,
        compact: compact,
        body: Column(
          children: [
            DemoColumns(
              wide: wide,
              left: Text(
                'Чему мы научились',
                style: screenText(28, c.ink, heading: true),
              ),
              right: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: DemoMath('6x + 9', size: 44),
              ),
            ),
            SizedBox(height: compact ? 12 : 20),
            for (final skill in skills)
              Container(
                padding: EdgeInsets.symmetric(vertical: compact ? 12 : 26),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.line)),
                ),
                child: DemoColumns(
                  wide: wide,
                  left: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skill.$1,
                        style: screenText(20, c.ink, heading: true),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Text(
                          skill.$2,
                          style: screenText(
                            compact
                                ? 17
                                : wide
                                ? 20
                                : 17,
                            c.sub,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  right: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: compact ? 8 : 14,
                    ),
                    decoration: BoxDecoration(
                      color: c.help,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: DemoMath(
                      skill.$3,
                      size: compact
                          ? 24
                          : wide
                          ? 30
                          : 24,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    super.key,
    this.errors = const [0, 2, 3, 0],
    this.firstRecord,
    this.successPercent = 86,
  });
  final PracticeRecord? firstRecord;
  final int successPercent;
  final List<int> errors;
  Widget _actions(BuildContext context, bool wide, bool compact) {
    final c = ScreenColors(context);
    return FooterActions(
      allowWrap: true,
      children: [
        SecondaryAction(
          label: 'Назад к решению',
          onPressed: firstRecord != null
              ? () => viewFirstSolution(
                  context,
                  firstRecord!,
                  'Вернуться к итогам',
                )
              : null,
          compact: compact,
        ),
        const SizedBox(width: 12),
        SecondaryAction(
          label: 'Чему мы научились',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (previewContext) => RecapScreen(
                firstRecord: firstRecord,
                onReturnToResults: () => Navigator.of(previewContext).pop(),
              ),
            ),
          ),
          compact: compact,
        ),
        const SizedBox(width: 12),
        SecondaryAction(
          onPressed: () => returnToTopics(context),
          label: 'К темам',
          compact: compact,
        ),
        const SizedBox(width: 20),
        if (errors.isNotEmpty)
          PrimaryAction(
            label: 'Разобрать ошибки',
            onPressed: () => openDemo(
              context,
              ErrorReviewScreen(
                errors: errors,
                firstRecord: firstRecord,
                successPercent: successPercent,
              ),
            ),
            wide: wide,
            compact: compact,
          )
        else
          Text('В этой практике ошибок не было', style: screenText(17, c.sub)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => DemoPage(
    footerBuilder: _actions,
    visibleScrollbar: true,
    bodyBuilder: (context, wide, compact) {
      final c = ScreenColors(context);
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 28 : 32,
              vertical: compact ? 20 : 28,
            ),
            decoration: BoxDecoration(
              color: Color(c.dark ? 0xff194f3c : 0xff17573e),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '$successPercent%',
                  style: screenText(
                    56,
                    Colors.white,
                    heading: true,
                    height: 64 / 56,
                  ),
                ),
                const SizedBox(width: 30),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Целевая успешность достигнута',
                              style: screenText(
                                22,
                                Colors.white,
                                heading: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'По последним оцениваемым заданиям',
                        style: screenText(16, Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SharedField(
            joinedTop: true,
            wide: wide,
            compact: compact,
            body: DemoColumns(
              wide: wide,
              left: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Итоги практики',
                    style: screenText(28, c.ink, heading: true),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Этот блок завершён. Посмотрим на проделанную работу.',
                    style: screenText(wide ? 20 : 18, c.ink, height: 1.6),
                  ),
                  SizedBox(height: compact ? 16 : 24),
                  for (final result in [
                    ('Решено заданий', '20'),
                    ('Правильных ответов', '${20 - errors.length}'),
                    ('Неправильных ответов', '${errors.length}'),
                  ])
                    Container(
                      padding: EdgeInsets.symmetric(
                        vertical: compact ? 12 : 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: c.line)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              result.$1,
                              style: screenText(18, c.ink),
                            ),
                          ),
                          Text(
                            result.$2,
                            style: screenText(25, c.ink, heading: true),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 22),
                  Text(
                    'Числа показаны для примера.',
                    style: screenText(13, c.sub),
                  ),
                ],
              ),
              right: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: c.help,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Можно разобрать',
                      style: screenText(20, c.ink, heading: true),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Задания, в которых ответ оказался неправильным.',
                      style: screenText(wide ? 20 : 17, c.ink, height: 1.6),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Вернись к объяснениям и посмотри, что нужно исправить.',
                      style: screenText(wide ? 20 : 17, c.ink, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class ErrorReviewScreen extends StatefulWidget {
  const ErrorReviewScreen({
    super.key,
    this.errors = const [0, 2, 3, 0],
    this.firstRecord,
    this.successPercent = 86,
  });
  final PracticeRecord? firstRecord;
  final int successPercent;
  final List<int> errors;
  @override
  State<ErrorReviewScreen> createState() => _ErrorReviewScreenState();
}

class _ErrorReviewScreenState extends State<ErrorReviewScreen> {
  int index = 0;
  void returnToResults() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ResultsScreen(
            errors: widget.errors,
            firstRecord: widget.firstRecord,
            successPercent: widget.successPercent,
          ),
        ),
      );
    }
  }

  Widget _actions(BuildContext context, bool wide, bool compact) {
    return FooterActions(
      children: [
        SecondaryAction(
          onPressed: returnToResults,
          label: 'К итогам',
          compact: compact,
        ),
        const SizedBox(width: 12),
        SecondaryAction(
          onPressed: index == 0 ? null : () => setState(() => index--),
          label: 'Назад',
          compact: compact,
        ),
        if (widget.errors.length > 1) ...[
          const SizedBox(width: 12),
          if (index == widget.errors.length - 1)
            SizedBox(
              width: 230,
              child: SecondaryAction(
                label: 'К первой ошибке',
                icon: Icons.replay,
                onPressed: () => setState(() => index = 0),
                compact: compact,
              ),
            )
          else
            PrimaryAction(
              width: 230,
              label: 'Следующая ошибка',
              onPressed: () =>
                  setState(() => index = (index + 1) % widget.errors.length),
              wide: wide,
              compact: compact,
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => DemoPage(
    footerBuilder: _actions,
    visibleScrollbar: true,
    bodyBuilder: (context, wide, compact) {
      final c = ScreenColors(context);
      final answer = widget.errors[index];
      final detail = DemoExplanation.forAnswer(answer);
      final wrong = ['3(2x + 9)', '', '3(3x + 2)', '3(2x − 3)'][answer];
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Разбор ошибок',
                  style: screenText(compact ? 25 : 27, c.ink, heading: true),
                ),
              ),
              Text(
                'Задание ${index + 1} из ${widget.errors.length}',
                style: screenText(16, c.sub),
              ),
            ],
          ),
          SizedBox(height: compact ? 12 : 20),
          SharedField(
            wide: wide,
            compact: compact,
            body: DemoColumns(
              wide: wide,
              left: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Вынеси общий множитель за скобки:',
                    style: screenText(
                      compact
                          ? 20
                          : wide
                          ? 23
                          : 18,
                      c.ink,
                    ),
                  ),
                  SizedBox(height: compact ? 12 : 18),
                  DemoMath(
                    '6x + 9',
                    size: compact
                        ? 43
                        : wide
                        ? 58
                        : 43,
                    height: 1.3,
                  ),
                  SizedBox(height: compact ? 18 : 28),
                  Text('Твой ответ', style: screenText(16, c.sub)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Color(c.dark ? 0xff452e36 : 0xfffff0ee),
                      border: Border.all(
                        color: Color(c.dark ? 0xffb97e84 : 0xffcf7772),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: DemoMath(wrong, size: wide ? 30 : 28)),
                        Icon(
                          Icons.close,
                          color: Color(c.dark ? 0xfff0aaa5 : 0xffa74743),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Неправильный ответ',
                    style: screenText(
                      15,
                      Color(c.dark ? 0xfff0aaa5 : 0xffa74743),
                    ),
                  ),
                ],
              ),
              right: Container(
                padding: EdgeInsets.all(compact ? 18 : 24),
                decoration: BoxDecoration(
                  color: c.help,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: c.ink),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Разберём запись',
                            style: screenText(
                              compact ? 19 : 21,
                              c.ink,
                              heading: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 10 : 16),
                    Text(
                      '${detail.mistake} На вынесенный множитель нужно разделить каждое слагаемое.',
                      style: screenText(
                        compact
                            ? 16
                            : wide
                            ? 20
                            : 17,
                        c.ink,
                        height: compact ? 1.45 : 1.6,
                      ),
                    ),
                    SizedBox(height: compact ? 10 : 16),
                    DemoMath(
                      '6x : 3 = 2x\n9 : 3 = 3',
                      size: compact ? 24 : 30,
                      height: compact ? 1.3 : 1.45,
                    ),
                    SizedBox(height: compact ? 10 : 16),
                    Text(
                      'Поэтому внутри скобок будет 2x + 3.',
                      style: screenText(
                        compact
                            ? 16
                            : wide
                            ? 20
                            : 17,
                        c.ink,
                        height: compact ? 1.45 : 1.6,
                      ),
                    ),
                    SizedBox(height: compact ? 14 : 20),
                    Divider(height: 1, color: c.line),
                    SizedBox(height: compact ? 14 : 20),
                    Text('Правильная запись', style: screenText(15, c.sub)),
                    const SizedBox(height: 8),
                    DemoMath(
                      '6x + 9 = 3(2x + 3)',
                      size: compact ? 24 : 30,
                      height: compact ? 1.3 : 1.45,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class DetailedExplanationScreen extends StatelessWidget {
  const DetailedExplanationScreen({super.key});
  @override
  Widget build(BuildContext context) => DemoPage(
    topic: 'Общий множитель за скобками',
    showSuccess: true,
    bodyBuilder: (context, wide, compact) {
      final c = ScreenColors(context);
      const steps = [
        (
          'Найдём общий множитель',
          'Оба слагаемых можно представить как произведение с множителем 3.',
          '6x = 3 · 2x\n9 = 3 · 3',
        ),
        (
          'Определим, что останется в скобках',
          'На вынесенный множитель делим каждое слагаемое — и 6x, и 9. Знак «+» сохраняем.',
          '6x : 3 = 2x\n9 : 3 = 3',
        ),
        (
          'Проверим обратным действием',
          'Умножим 3 на каждое слагаемое в скобках. Получаем исходное выражение.',
          '3(2x + 3)\n= 6x + 9',
        ),
      ];
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 28 : 40,
          vertical: compact ? 24 : 36,
        ),
        decoration: BoxDecoration(
          color: c.help,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: c.ink),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Давай разберёмся по шагам',
                    style: screenText(27, c.ink, heading: true),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 12 : 20),
            DemoColumns(
              wide: wide,
              left: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Наш пример', style: screenText(17, c.sub)),
                  const SizedBox(height: 8),
                  const DemoMath('6x + 9', size: 36),
                ],
              ),
              right: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Твой ответ', style: screenText(17, c.sub)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(child: DemoMath('3(2x + 9)', size: 27)),
                      Icon(
                        Icons.close,
                        color: Color(c.dark ? 0xffe49b9b : 0xffb35550),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Множитель 3 вынесен, но число 9 внутри скобок осталось прежним.',
                    style: screenText(17, c.ink, height: 1.5),
                  ),
                ],
              ),
            ),
            SizedBox(height: compact ? 14 : 22),
            for (var i = 0; i < steps.length; i++)
              Container(
                padding: EdgeInsets.symmetric(vertical: compact ? 14 : 26),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.line)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.paper,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: screenText(18, c.ink, heading: true),
                      ),
                    ),
                    SizedBox(width: wide ? 24 : 16),
                    Expanded(
                      child: DemoColumns(
                        wide: wide,
                        left: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              steps[i].$1,
                              style: screenText(19, c.ink, heading: true),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              steps[i].$2,
                              style: screenText(17, c.ink, height: 1.5),
                            ),
                          ],
                        ),
                        right: DemoMath(steps[i].$3),
                      ),
                    ),
                  ],
                ),
              ),
            Divider(height: 1, color: c.line),
            SizedBox(height: compact ? 16 : 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Получаем', style: screenText(17, c.sub)),
                      const DemoMath('6x + 9 = 3(2x + 3)'),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                PrimaryAction(
                  label: 'Кажется, я понял',
                  onPressed: () => openDemo(context, const RecapScreen()),
                  wide: wide,
                  compact: compact,
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
