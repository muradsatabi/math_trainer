import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'explanation_panel.dart';
import 'demo_screens.dart';
import 'constructor_screen.dart';
import 'completion_screens.dart';
import 'practice_record.dart';

void main() => runApp(
  MathTrainerApp(home: demoScreen(Uri.base.queryParameters['screen'])),
);

Widget demoScreen(String? name) => switch (name) {
  'start' => const StartScreen(),
  'task' => const PracticeScreen(),
  'constructor' => const ConstructorScreen(),
  'detailed' => const DetailedExplanationScreen(),
  'recap' => const RecapScreen(),
  'results' => const ResultsScreen(),
  'review' => const ErrorReviewScreen(),
  _ => const TopicsScreen(),
};

class MathTrainerApp extends StatelessWidget {
  const MathTrainerApp({
    super.key,
    this.themeMode = ThemeMode.system,
    this.home = const TopicsScreen(),
  });
  final ThemeMode themeMode;
  final Widget home;

  ThemeData _theme(Brightness brightness) => ThemeData(
    brightness: brightness,
    fontFamily: 'Segoe UI',
    colorScheme: ColorScheme.fromSeed(
      seedColor: brightness == Brightness.dark
          ? const Color(0xff3c70e6)
          : const Color(0xff285bd8),
      brightness: brightness,
    ),
    useMaterial3: true,
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Математический тренажёр — Практика',
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    themeMode: themeMode,
    home: home,
  );
}

// Temporary examples copied from V3, not an approved exercise bank.
const demoAnswers = ['3(2x + 9)', '3(2x + 3)', '3(3x + 2)', '3(2x − 3)'];

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    super.key,
    this.onTopics,
    this.onNext,
    this.onAdvance,
    this.record,
    this.onReturnToCurrent,
    this.returnLabel = 'Вернуться к текущему',
    this.showHistoryControls = false,
  });
  final VoidCallback? onTopics;
  final VoidCallback? onNext;
  final ValueChanged<PracticeRecord>? onAdvance;
  final PracticeRecord? record;
  final VoidCallback? onReturnToCurrent;
  final String returnLabel;
  final bool showHistoryControls;
  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  int? selected;
  bool checked = false;
  bool explanationOpen = false;
  bool get correct => checked && selected == 1;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    if (record != null) {
      selected = record.selected;
      checked = true;
      explanationOpen = record.explanationOpen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final paper = Color(dark ? 0xff182237 : 0xffffffff);
    final ink = Color(dark ? 0xffeef3ff : 0xff20304c);
    final sub = Color(dark ? 0xffb9c9e2 : 0xff586b87);
    final line = Color(dark ? 0xff3c506f : 0xffdce5f3);
    final blue = Color(dark ? 0xff3c70e6 : 0xff285bd8);
    final pale = Color(dark ? 0xff253d60 : 0xffeef4ff);
    return Scaffold(
      backgroundColor: paper,
      body: LayoutBuilder(
        builder: (context, bounds) {
          final m = _Metrics(bounds.maxWidth, bounds.maxHeight);
          final usable = math.max(0.0, bounds.maxWidth - m.side * 2);
          final rightWidth = m.wide ? (usable - m.gap) / 3.26 : 280.0;
          final leftWidth = usable - m.gap - rightWidth;
          final taskWidth = leftWidth - m.taskInset - 1;
          // Keep content accessible in smaller windows without clipping.
          if (taskWidth < 240) {
            return SingleChildScrollView(
              child: SizedBox(
                width: bounds.maxWidth,
                child: _page(
                  m,
                  bounds.maxHeight,
                  bounds.maxWidth - 32,
                  0,
                  paper,
                  ink,
                  sub,
                  line,
                  blue,
                  pale,
                  narrow: true,
                ),
              ),
            );
          }
          return SingleChildScrollView(
            child: _page(
              m,
              bounds.maxHeight,
              leftWidth,
              rightWidth,
              paper,
              ink,
              sub,
              line,
              blue,
              pale,
            ),
          );
        },
      ),
    );
  }

  Widget _page(
    _Metrics m,
    double height,
    double leftWidth,
    double rightWidth,
    Color paper,
    Color ink,
    Color sub,
    Color line,
    Color blue,
    Color pale, {
    bool narrow = false,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final greenBackground = Color(dark ? 0xff233e35 : 0xffeaf6ee);
    final greenBorder = Color(dark ? 0xff68c98b : 0xff28934c);
    final greenMark = Color(dark ? 0xff86d6a2 : 0xff287a45);
    final answerBackground = correct
        ? greenBackground
        : Color(dark ? 0xff452e36 : 0xfffff0ee);
    final answerBorder = correct
        ? greenBorder
        : Color(dark ? 0xffb97e84 : 0xffcf7772);
    final answerMark = correct
        ? greenMark
        : Color(dark ? 0xffe49b9b : 0xffb35550);
    final markBackground = correct
        ? Color(dark ? 0xff304f42 : 0xffd8eddf)
        : Color(dark ? 0xff593841 : 0xfff7deda);
    final textScale = MediaQuery.textScalerOf(context);
    final taskWidth = narrow ? leftWidth : leftWidth - m.taskInset - 1;
    double measured(TextSpan span, double width) {
      final p = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
        textScaler: textScale,
      )..layout(maxWidth: width);
      return p.height;
    }

    TextStyle normal(
      double size,
      double h, {
      Color? color,
      FontWeight weight = FontWeight.w400,
    }) => TextStyle(
      fontFamily: 'Segoe UI',
      fontSize: size,
      height: h,
      color: color ?? ink,
      fontWeight: weight,
    );
    final titleStyle = normal(
      m.title,
      m.titleLine / m.title,
      weight: FontWeight.w500,
    );
    final titleHeight = measured(
      TextSpan(text: 'Общий множитель за скобками', style: titleStyle),
      leftWidth,
    );
    final topHeight =
        m.vertical +
        m.exitHeight +
        m.exitGap +
        m.labelLine +
        m.headerGap +
        math.max(titleHeight, m.titleLine) +
        m.headerBottom +
        1 +
        m.layoutGap;
    var scale = 1.0;
    double rowHeight(double s) => math.max(
      m.row * (1 + (s - 1) * .7),
      measured(
            _formulaSpan(demoAnswers[0], m.answer * s, ink, 1.25),
            taskWidth - m.answerSide * 2 - 2,
          ) +
          (m.answerPad + (s > 1 ? 2 : 0)) * 2 +
          2,
    );
    double taskHeight(double s) =>
        measured(
          TextSpan(
            text: 'Вынеси общий множитель за скобки:',
            style: normal(m.instruction, m.instructionLine),
          ),
          taskWidth,
        ) +
        m.expressionTop +
        measured(
          _formulaSpan('6x + 9', m.expression * s, ink, m.expressionLine),
          taskWidth,
        ) +
        m.expressionBottom +
        m.chooseLine +
        m.chooseBottom +
        rowHeight(s) * 4 +
        m.answerGap * 3 +
        m.feedback +
        m.actionHeight * (s > 1 ? 1.08 : 1);
    for (final candidate in [1.25, 1.18, 1.10]) {
      if (topHeight + taskHeight(candidate) + m.vertical <= height - 8) {
        scale = candidate;
        break;
      }
    }
    final answerHeight = rowHeight(scale);
    final buttonSize = scale > 1
        ? math.min(22.0, m.actionText * 1.1)
        : m.actionText;
    final task = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Вынеси общий множитель за скобки:',
          style: normal(m.instruction, m.instructionLine),
        ),
        SizedBox(height: m.expressionTop),
        _Formula(
          '6x + 9',
          size: m.expression * scale,
          color: ink,
          height: m.expressionLine,
        ),
        SizedBox(height: m.expressionBottom),
        Text(
          'Выбери ответ:',
          style: normal(m.choose, m.chooseLine / m.choose, color: sub),
        ),
        SizedBox(height: m.chooseBottom),
        for (var i = 0; i < demoAnswers.length; i++) ...[
          Semantics(
            selected: selected == i,
            inMutuallyExclusiveGroup: true,
            label: 'Вариант ${i + 1}: ${demoAnswers[i]}',
            child: OutlinedButton(
              key: ValueKey('answer-$i'),
              onPressed: checked ? null : () => setState(() => selected = i),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, answerHeight),
                padding: EdgeInsets.symmetric(
                  horizontal: m.answerSide,
                  vertical: m.answerPad + (scale > 1 ? 2 : 0),
                ),
                alignment: Alignment.centerLeft,
                backgroundColor: selected == i
                    ? (checked ? answerBackground : pale)
                    : paper,
                foregroundColor: ink,
                side: BorderSide(
                  color: selected == i ? (checked ? answerBorder : blue) : line,
                  width: selected == i ? 2 : 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(m.radius),
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    Expanded(
                      child: _Formula(
                        demoAnswers[i],
                        size: m.answer * scale,
                        color: ink,
                      ),
                    ),
                    if (checked && selected == i)
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: markBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          correct ? Icons.check : Icons.close,
                          size: 24,
                          color: answerMark,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (i < demoAnswers.length - 1) SizedBox(height: m.answerGap),
        ],
        SizedBox(height: m.feedback),
        Row(
          children: [
            if (widget.showHistoryControls) ...[
              Expanded(
                child: SizedBox(
                  key: const ValueKey('previous-task-space'),
                  height: height <= 840 ? 50 : 54,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: FilledButton(
                key: ValueKey(checked ? 'next-task' : 'check-answer'),
                onPressed: selected == null
                    ? null
                    : () {
                        if (!checked) {
                          setState(() => checked = true);
                        } else {
                          if (widget.onReturnToCurrent != null) {
                            widget.onReturnToCurrent!();
                          } else if (widget.onAdvance != null) {
                            widget.onAdvance!(
                              PracticeRecord(
                                selected: selected!,
                                explanationOpen: explanationOpen,
                              ),
                            );
                          } else {
                            widget.onNext?.call();
                          }
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: blue.withValues(alpha: .55),
                  disabledForegroundColor: Colors.white.withValues(alpha: .55),
                  minimumSize: Size(
                    double.infinity,
                    m.actionHeight * (scale > 1 ? 1.08 : 1),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(m.radius),
                  ),
                  textStyle: normal(
                    buttonSize,
                    24 / buttonSize,
                    weight: FontWeight.w500,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  widget.onReturnToCurrent != null
                      ? widget.returnLabel
                      : checked
                      ? 'Дальше'
                      : 'Проверить себя',
                ),
              ),
            ),
          ],
        ),
      ],
    );
    Widget statistic() => InkWell(
      onTap: () => showSuccessInfo(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SuccessLabel(
            style: normal(m.label, m.labelLine / m.label, color: sub),
          ),
          SizedBox(height: m.headerGap),
          SizedBox(
            height: math.max(titleHeight, m.titleLine),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: m.wide ? 216 : 164,
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: 'Успешность 0 процентов',
                        child: Container(
                          key: const ValueKey('success-track'),
                          height: m.wide ? 12 : 10,
                          decoration: BoxDecoration(
                            color: paper == const Color(0xff182237)
                                ? const Color(0xff475773)
                                : const Color(0xffe4e9ef),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: m.wide ? 16 : 12),
                    Text(
                      '0%',
                      style: normal(
                        m.title,
                        m.titleLine / m.title,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: narrow ? 16 : m.side,
          vertical: m.vertical,
        ),
        child: DefaultTextStyle(
          style: normal(16, 1.45),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: widget.onTopics ?? () => returnToTopics(context),
                child: SizedBox(
                  height: m.exitHeight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, size: 16, color: sub),
                      const SizedBox(width: 8),
                      Text('К темам', style: normal(15, 24 / 15, color: sub)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: m.exitGap),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: leftWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Практика',
                          style: normal(
                            m.label,
                            m.labelLine / m.label,
                            color: sub,
                          ),
                        ),
                        SizedBox(height: m.headerGap),
                        Text('Общий множитель за скобками', style: titleStyle),
                      ],
                    ),
                  ),
                  if (!narrow) ...[
                    SizedBox(width: m.gap),
                    SizedBox(width: rightWidth, child: statistic()),
                  ],
                ],
              ),
              if (narrow) statistic(),
              SizedBox(height: m.headerBottom),
              Divider(height: 1, thickness: 1, color: line),
              SizedBox(height: m.layoutGap),
              if (narrow)
                task
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: leftWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(right: BorderSide(color: line)),
                        ),
                        padding: EdgeInsets.only(right: m.taskInset),
                        child: task,
                      ),
                    ),
                    SizedBox(width: m.gap),
                    SizedBox(
                      width: rightWidth,
                      child: explanationOpen
                          ? SizedBox(
                              height:
                                  taskHeight(scale) +
                                  Theme.of(context)
                                          .visualDensity
                                          .baseSizeAdjustment
                                          .dy *
                                      5,
                              child: ExplanationPanel(
                                answer: selected!,
                                wide: m.wide,
                                background: pale,
                                ink: ink,
                              ),
                            )
                          : correct
                          ? Semantics(
                              liveRegion: true,
                              label: 'Правильный ответ. Абсолютно верно!',
                              child: Container(
                                key: const ValueKey('correct-feedback'),
                                margin: const EdgeInsets.only(top: 44),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 22,
                                ),
                                constraints: const BoxConstraints(
                                  minHeight: 104,
                                ),
                                decoration: BoxDecoration(
                                  color: greenBackground,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: ExcludeSemantics(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Color(
                                            dark ? 0xff304f42 : 0xffd8eddf,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.check,
                                          size: 24,
                                          color: greenMark,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          'Абсолютно\nверно!',
                                          style: normal(
                                            m.wide ? 23 : 20,
                                            1.4,
                                            weight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : checked
                          ? Padding(
                              padding: EdgeInsets.only(
                                top: (height * .23).clamp(140.0, 206.0),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      'Пока не получилось!',
                                      key: const ValueKey('incorrect-feedback'),
                                      style: normal(
                                        m.wide ? 24 : 22,
                                        m.wide ? 32 / 24 : 30 / 22,
                                        color: Color(
                                          dark ? 0xffa7c5ff : 0xff285bd8,
                                        ),
                                        weight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  Tooltip(
                                    message: 'Открыть разбор ошибки',
                                    child: OutlinedButton(
                                      key: const ValueKey('learn-answer'),
                                      onPressed: () => setState(
                                        () => explanationOpen = true,
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: pale,
                                        foregroundColor: Color(
                                          dark ? 0xffc5d8ff : 0xff285bd8,
                                        ),
                                        minimumSize: Size(
                                          double.infinity,
                                          m.wide ? 96 : 84,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 20,
                                        ),
                                        side: BorderSide(color: blue),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.lightbulb_outline,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Flexible(
                                            child: Text(
                                              'Узнать,\nкак правильно',
                                              style: normal(
                                                m.wide ? 22 : 20,
                                                1.4,
                                                color: Color(
                                                  dark
                                                      ? 0xffc5d8ff
                                                      : 0xff285bd8,
                                                ),
                                                weight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

TextSpan _formulaSpan(String value, double size, Color color, double height) =>
    TextSpan(
      style: TextStyle(
        fontFamily: 'Cambria',
        fontSize: size,
        height: height,
        color: color,
      ),
      children: [
        for (final character in value.split(''))
          TextSpan(
            text: character,
            style: character == 'x'
                ? const TextStyle(fontStyle: FontStyle.italic)
                : null,
          ),
      ],
    );

class _Formula extends StatelessWidget {
  const _Formula(
    this.value, {
    required this.size,
    required this.color,
    this.height = 1.25,
  });
  final String value;
  final double size;
  final Color color;
  final double height;
  @override
  Widget build(BuildContext context) => Text.rich(
    _formulaSpan(value, size, color, height),
    semanticsLabel: value,
  );
}

// Final CSS cascade of 03-task-adaptive.html, before the fit enlargement.
class _Metrics {
  _Metrics(double width, double height) : wide = width >= 1280 {
    final compact = height <= 840;
    final low = height <= 680;
    side = wide ? 56 : 40;
    gap = wide ? 44 : 32;
    taskInset = wide ? 42 : 30;
    vertical = low
        ? 12
        : compact
        ? 16
        : 32;
    exitHeight = low
        ? 24
        : compact
        ? 26
        : 30;
    exitGap = low
        ? 6
        : compact
        ? 8
        : 12;
    label = low
        ? 13
        : compact
        ? 14
        : wide
        ? 17
        : 14;
    labelLine = low
        ? 18
        : compact
        ? 20
        : wide
        ? 24
        : 20;
    headerGap = compact ? 4 : 8;
    title = low
        ? 22
        : compact
        ? 25
        : wide
        ? 30
        : 25;
    titleLine = low
        ? 28
        : compact
        ? 32
        : wide
        ? 40
        : 32;
    headerBottom = low
        ? 10
        : compact
        ? 12
        : 20;
    layoutGap = low
        ? 12
        : compact
        ? 16
        : 24;
    instruction = low
        ? 17
        : compact
        ? 19
        : wide
        ? 23
        : 19;
    instructionLine = low
        ? 24 / 17
        : compact
        ? 28 / 19
        : 1.4;
    expression = low
        ? 36
        : compact
        ? 42
        : wide
        ? 54
        : 48;
    expressionLine = low ? 1.15 : 1.2;
    expressionTop = low
        ? 4
        : compact
        ? 8
        : 16;
    expressionBottom = low
        ? 8
        : compact
        ? 12
        : 20;
    choose = low
        ? 14
        : compact
        ? 15
        : wide
        ? 18
        : 15;
    chooseLine = compact ? 20 : choose * 1.4;
    chooseBottom = low
        ? 6
        : compact
        ? 8
        : 12;
    answer = low
        ? 22
        : compact
        ? 25
        : wide
        ? 30
        : 25;
    row = low
        ? 44
        : compact
        ? 52
        : wide
        ? 64
        : 58;
    answerPad = low
        ? 7
        : compact
        ? 9
        : 12;
    answerSide = low
        ? 20
        : compact
        ? 22
        : wide
        ? 28
        : 22;
    answerGap = low
        ? 6
        : compact
        ? 8
        : 12;
    feedback = low
        ? 8
        : compact
        ? 16
        : 24;
    actionHeight = low
        ? 44
        : compact
        ? 50
        : 58;
    actionText = low
        ? 16
        : compact
        ? 17
        : wide
        ? 20
        : 17;
    radius = wide ? 18 : 16;
  }
  final bool wide;
  late final double side,
      gap,
      taskInset,
      vertical,
      exitHeight,
      exitGap,
      label,
      labelLine,
      headerGap,
      title,
      titleLine,
      headerBottom,
      layoutGap,
      instruction,
      instructionLine,
      expression,
      expressionLine,
      expressionTop,
      expressionBottom,
      choose,
      chooseLine,
      chooseBottom,
      answer,
      row,
      answerPad,
      answerSide,
      answerGap,
      feedback,
      actionHeight,
      actionText,
      radius;
}
