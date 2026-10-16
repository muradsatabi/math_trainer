import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bank/factor_answer_checker.dart';
import 'bank/task_bank.dart';
import 'completion_screens.dart' show DemoColumns, DemoMath;
import 'demo_screens.dart';
import 'practice/practice_session.dart';
import 'practice/answer_keyboard.dart';
import 'practice/answer_choices.dart';
import 'answer_form.dart';

/// Real practice entry point. The original V3 demo screens remain previewable.
class BankTrainer extends StatefulWidget {
  const BankTrainer({super.key, this.readText});
  final BankTextReader? readText;
  @override
  State<BankTrainer> createState() => _BankTrainerState();
}

class _BankTrainerState extends State<BankTrainer> {
  final entry = TextEditingController();
  late final Future<TaskBank> loading = _load();
  late PracticeSettings settings;
  PracticeSession? session;
  String page = 'topics';
  String? inputMessage;
  bool showAnswer = false;
  int reviewIndex = 0;
  bool get _complete => isCompleteAnswer(entry.text.replaceAll('·', '×'));
  bool get _unsupportedSymbol =>
      RegExp(r'[^0-9a-zA-Z\s()+−×÷*/·-]').hasMatch(entry.text);

  List<TaskAttempt> get _errors =>
      session!.attempts.where((a) => !a.correct).toList();

  Widget _actions(
    BuildContext context,
    bool wide,
    bool compact,
    TaskBank bank,
  ) {
    final s = session;
    if (page == 'practice') {
      final left = Container(
        padding: EdgeInsets.only(right: wide ? 42 : 30),
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: Colors.transparent)),
        ),
        child: LayoutBuilder(
          builder: (context, bounds) => Row(
            children: [
              SizedBox(
                width: s!.usesInput
                    ? (bounds.maxWidth - 48) / 3
                    : (bounds.maxWidth - 12) / 3,
                child: SecondaryAction(
                  key: const ValueKey('bank-previous'),
                  label: 'Предыдущее задание',
                  onPressed: _previousIndex >= 0 ? _previous : null,
                  compact: compact,
                ),
              ),
              SizedBox(width: s.usesInput ? 24 : 12),
              Expanded(
                child: PrimaryAction(
                  key: const ValueKey('bank-primary'),
                  label: s.checked ? 'Дальше' : 'Проверить себя',
                  onPressed: !s.checked && !_complete
                      ? null
                      : s.checked
                      ? _next
                      : _check,
                  wide: wide,
                  compact: compact,
                ),
              ),
            ],
          ),
        ),
      );
      return LayoutBuilder(
        builder: (context, bounds) => bounds.maxWidth < 720
            ? left
            : DemoColumns(
                wide: wide,
                left: left,
                right: const SizedBox.shrink(),
              ),
      );
    }
    if (page == 'results') {
      return FooterActions(
        allowWrap: true,
        children: [
          SecondaryAction(
            label: 'Назад к решению',
            compact: compact,
            onPressed: () => _showAttempt(s!.attempts.first, fromResults: true),
          ),
          SecondaryAction(
            label: 'Чему мы научились',
            compact: compact,
            onPressed: () => setState(() => page = 'recap'),
          ),
          SecondaryAction(
            label: 'К темам',
            compact: compact,
            onPressed: () => setState(() => page = 'topics'),
          ),
          if (_errors.isNotEmpty)
            PrimaryAction(
              label: 'Разобрать ошибки',
              wide: wide,
              compact: compact,
              onPressed: () => setState(() {
                reviewIndex = 0;
                page = 'review';
              }),
            ),
        ],
      );
    }
    if (page == 'review') {
      return FooterActions(
        allowWrap: true,
        children: [
          SecondaryAction(
            label: 'Назад',
            compact: compact,
            onPressed: reviewIndex > 0
                ? () => setState(() => reviewIndex--)
                : null,
          ),
          if (_errors.length > 1)
            if (reviewIndex < _errors.length - 1)
              SecondaryAction(
                label: 'Следующая ошибка',
                compact: compact,
                onPressed: () => setState(() => reviewIndex++),
              )
            else
              OutlinedButton.icon(
                onPressed: () => setState(() => reviewIndex = 0),
                icon: const Icon(Icons.restart_alt),
                label: const Text('К первой ошибке'),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(0, compact ? 50 : 58),
                  foregroundColor: ScreenColors(context).blue,
                  side: BorderSide(color: ScreenColors(context).line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
          PrimaryAction(
            label: 'К итогам',
            wide: wide,
            compact: compact,
            onPressed: () => setState(() => page = 'results'),
          ),
        ],
      );
    }
    return PrimaryAction(
      label: page == 'recap' ? 'К итогам' : 'Начать практику',
      wide: wide,
      compact: compact,
      onPressed: () => setState(() {
        if (page == 'recap') {
          page = 'results';
          return;
        }
        session = PracticeSession(bank: bank, settings: settings);
        page = 'practice';
        entry.clear();
      }),
    );
  }

  void _insert(String symbol) {
    if (session!.checked) return;
    final selection = entry.selection;
    final start = selection.isValid ? selection.start : entry.text.length;
    final end = selection.isValid ? selection.end : entry.text.length;
    setState(() {
      entry.value = TextEditingValue(
        text: entry.text.replaceRange(start, end, symbol),
        selection: TextSelection.collapsed(offset: start + symbol.length),
      );
      inputMessage = null;
    });
  }

  void _delete() {
    if (session!.checked) return;
    final selection = entry.selection;
    final start = selection.isValid ? selection.start : entry.text.length;
    final end = selection.isValid ? selection.end : entry.text.length;
    if (start == end && start == 0) return;
    final previous = start == end
        ? entry.text
              .substring(0, start)
              .characters
              .skipLast(1)
              .toString()
              .length
        : start;
    setState(() {
      entry.value = TextEditingValue(
        text: entry.text.replaceRange(previous, end, ''),
        selection: TextSelection.collapsed(offset: previous),
      );
      inputMessage = null;
    });
  }

  int get _previousIndex =>
      session!.attempts.length - (session!.checked ? 2 : 1);

  void _previous() {
    if (_previousIndex < 0) return;
    final record = session!.attempts[_previousIndex];
    _showAttempt(record);
  }

  void _showAttempt(TaskAttempt record, {bool fromResults = false}) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final c = ScreenColors(dialogContext);
        return AlertDialog(
          backgroundColor: c.paper,
          title: Text(fromResults ? 'Первое решение' : 'Предыдущее задание'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _text(record.task.instruction, c),
                  const SizedBox(height: 12),
                  DemoMath(record.task.expression, size: 32),
                  const SizedBox(height: 12),
                  _text('Твой ответ: ${record.answer}', c),
                  _text(
                    record.correct ? 'Абсолютно верно!' : 'Пока не получилось!',
                    c,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(fromResults ? 'К итогам' : 'Вернуться к текущему'),
            ),
          ],
        );
      },
    );
  }

  Future<TaskBank> _load() async {
    final read = widget.readText ?? rootBundle.loadString;
    final manifest =
        jsonDecode(await read('bank/manifest.json')) as Map<String, dynamic>;
    final config = manifest['practice'] as Map<String, dynamic>;
    settings = PracticeSettings(
      minimumAnswers: config['minimum_answers'] as int,
      successWindow: config['success_window'] as int,
      passPercent: config['pass_percent'] as int,
      extraTasksPerError: config['extra_tasks_per_error'] as int,
      inputPercent: config['input_percent'] as int? ?? 70,
    );
    return TaskBank.load('bank/manifest.json', read);
  }

  @override
  void dispose() {
    entry.dispose();
    super.dispose();
  }

  void _check() {
    final s = session!;
    if (s.checked || s.isFinished) return;
    if (!_complete) {
      setState(
        () => inputMessage = _unsupportedSymbol
            ? 'Эта запись пока не поддерживается. Ответ не оценён.'
            : 'Ты не закончил запись. Допиши ответ',
      );
      return;
    }
    final verdict = checkFactorAnswer(s.currentTask, entry.text);
    setState(() {
      inputMessage = null;
      if (verdict == AnswerVerdict.incomplete) {
        inputMessage = 'Заверши запись ответа.';
      } else if (verdict == AnswerVerdict.unsupported) {
        inputMessage =
            'Эта форма записи пока не поддерживается проверкой. '
            'Она не засчитана как ошибка. Попробуй записать ответ иначе.';
      } else {
        s.submit(answer: entry.text, correct: verdict == AnswerVerdict.correct);
        showAnswer = s.needsDetailedExplanation;
      }
    });
  }

  void _next() {
    final s = session!;
    setState(() {
      s.advance();
      entry.clear();
      inputMessage = null;
      showAnswer = false;
    });
  }

  void _finish() {
    final s = session!;
    if (!s.canFinish || s.isFinished) return;
    setState(() {
      s.finish();
      page = 'results';
    });
  }

  Widget _text(String text, ScreenColors c, {double size = 20}) =>
      Text(text, style: screenText(size, c.ink, height: 1.5));

  Widget _summary(TaskBank bank, ScreenColors c) {
    final s = session;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _text(
          '${bank.blocks.length} блоков · ${bank.taskCount} заданий в банке',
          c,
        ),
        const SizedBox(height: 16),
        _text(
          'Можно завершить занятие при успешности от ${settings.passPercent}%. '
          'Окно успешности — ${settings.successWindow} заданий.',
          c,
        ),
        const SizedBox(height: 12),
        _text(
          'После ошибки — ещё ${settings.extraTasksPerError} задания того же блока.',
          c,
        ),
        if (s != null) ...[
          const SizedBox(height: 12),
          _text(
            'Решено: ${s.attempts.length}. '
            'Пройдено блоков: ${s.initialBlocksAnswered} из ${bank.blocks.length}.',
            c,
          ),
        ],
      ],
    );
  }

  Widget _practice(TaskBank bank, ScreenColors c, bool wide, bool compact) {
    final s = session!;
    final task = s.currentTask;
    final correct = s.checked && s.attempts.last.correct;
    final message =
        inputMessage ??
        (_unsupportedSymbol
            ? 'Эта запись пока не поддерживается. Ответ не оценён.'
            : null);
    final feedbackColor = correct
        ? Color(c.dark ? 0xff86d6a2 : 0xff287a45)
        : Color(c.dark ? 0xfff0aaa5 : 0xffa74743);
    return DemoColumns(
      wide: wide,
      narrowRightFirst: s.checked || s.canFinish,
      left: Container(
        padding: EdgeInsets.only(right: wide ? 42 : 30),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: c.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.currentBlock.title, style: screenText(16, c.sub)),
            SizedBox(height: compact ? 8 : 16),
            _text(task.instruction, c, size: compact ? 19 : 23),
            SizedBox(height: compact ? 8 : 18),
            DemoMath(task.expression, size: compact ? 36 : 54, height: 1.2),
            SizedBox(height: compact ? 10 : 24),
            Text(
              s.usesInput ? 'Собери ответ:' : 'Выбери ответ:',
              style: screenText(compact ? 15 : 18, c.sub),
            ),
            const SizedBox(height: 12),
            if (!s.usesInput) _choiceCards(task, s, c, compact),
            if (s.usesInput) ...[
              Container(
                height: compact ? 56 : 72,
                decoration: BoxDecoration(
                  color: !s.checked
                      ? c.paper
                      : correct
                      ? Color(c.dark ? 0xff233e35 : 0xffeaf6ee)
                      : Color(c.dark ? 0xff452e36 : 0xfffff0ee),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    width: 2,
                    color: !s.checked
                        ? c.blue
                        : correct
                        ? Color(c.dark ? 0xff68c98b : 0xff28934c)
                        : Color(c.dark ? 0xffb97e84 : 0xffcf7772),
                  ),
                ),
                child: TextField(
                  key: const ValueKey('bank-answer'),
                  controller: entry,
                  readOnly: s.checked,
                  autofocus: false,
                  style: TextStyle(
                    fontFamily: 'Caladea',
                    fontSize: compact ? 28 : 32,
                    color: c.ink,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: compact ? 22 : 24,
                      vertical: compact ? 6 : 14,
                    ),
                    suffixIcon: s.checked
                        ? Icon(
                            correct ? Icons.check : Icons.close,
                            color: feedbackColor,
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() => inputMessage = null),
                  onTapOutside: (_) {
                    if (!s.checked && entry.text.isNotEmpty && !_complete) {
                      setState(
                        () => inputMessage = _unsupportedSymbol
                            ? 'Эта запись пока не поддерживается. Ответ не оценён.'
                            : 'Ты не закончил запись. Допиши ответ',
                      );
                    }
                  },
                  onSubmitted: (_) {
                    if (!s.checked) _check();
                  },
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                children: [
                  TextButton.icon(
                    key: const ValueKey('bank-delete'),
                    onPressed: s.checked || entry.text.isEmpty ? null : _delete,
                    icon: const Icon(Icons.backspace_outlined, size: 20),
                    label: const Text('Удалить символ'),
                  ),
                  TextButton(
                    key: const ValueKey('bank-clear'),
                    onPressed: s.checked || entry.text.isEmpty
                        ? null
                        : () => setState(() {
                            entry.clear();
                            inputMessage = null;
                          }),
                    child: const Text('Очистить'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFieldTapRegion(
                child: AnswerKeyboard(
                  key: ValueKey('keyboard-${task.id}'),
                  requiredDigits: RegExp(r'[0-9]')
                      .allMatches(task.expectedAnswer)
                      .map((m) => m.group(0)!)
                      .toSet()
                      .toList(),
                  letters:
                      (RegExp(r'[a-zA-Z]')
                          .allMatches(task.expression)
                          .map((m) => m.group(0)!)
                          .toSet()
                          .toList()
                        ..sort()),
                  enabled: !s.checked,
                  compact: compact,
                  onInsert: _insert,
                ),
              ),
            ],
            if (message != null) ...[
              const SizedBox(height: 12),
              _text(message, c, size: 16),
            ],
            const SizedBox(height: 20),
            Text(
              'Задание ${s.attempts.length + (s.checked ? 0 : 1)}'
              '${s.currentIsExtra ? ' · дополнительное' : ''}',
              style: screenText(16, c.sub),
            ),
            if (s.pendingExtraTasks > 0)
              Text(
                'Дополнительных заданий осталось: ${s.pendingExtraTasks}',
                style: screenText(16, c.sub),
              ),
          ],
        ),
      ),
      right: s.checked || s.canFinish
          ? Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: c.help,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (s.checked)
                    Text(
                      correct ? 'Абсолютно верно!' : 'Пока не получилось!',
                      key: const ValueKey('bank-feedback'),
                      style: screenText(24, feedbackColor, heading: true),
                    ),
                  if (s.checked && !correct && !showAnswer) ...[
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () => setState(() => showAnswer = true),
                      child: const Text('Узнать, как правильно'),
                    ),
                  ],
                  if (s.checked && showAnswer) ...[
                    const SizedBox(height: 16),
                    _text('Правильная запись', c),
                    const SizedBox(height: 8),
                    DemoMath(task.expectedAnswer, size: 28),
                    const SizedBox(height: 12),
                    _text(s.currentBlock.skill, c, size: 16),
                  ],
                  if (s.canFinish) ...[
                    if (s.checked) const Divider(height: 32),
                    Text(
                      'Целевая успешность достигнута',
                      key: const ValueKey('bank-finish-notice'),
                      style: screenText(22, c.ink, heading: true),
                    ),
                    const SizedBox(height: 12),
                    _text(
                      'Можно завершить занятие или продолжить практику.',
                      c,
                      size: 17,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const ValueKey('bank-finish'),
                      onPressed: _finish,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        backgroundColor: c.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Завершить занятие'),
                    ),
                  ],
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _choiceCards(
    BankTask task,
    PracticeSession s,
    ScreenColors c,
    bool compact,
  ) {
    final options = answerChoices(task);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) SizedBox(height: compact ? 8 : 12),
          Builder(
            builder: (context) {
              final selected = entry.text == options[i];
              final correct = s.checked && s.attempts.last.correct;
              final borderColor = selected
                  ? s.checked
                        ? correct
                              ? Color(c.dark ? 0xff68c98b : 0xff28934c)
                              : Color(c.dark ? 0xffb97e84 : 0xffcf7772)
                        : c.blue
                  : c.line;
              final background = selected
                  ? s.checked
                        ? correct
                              ? Color(c.dark ? 0xff233e35 : 0xffeaf6ee)
                              : Color(c.dark ? 0xff452e36 : 0xfffff0ee)
                        : c.help
                  : c.paper;
              return Semantics(
                button: true,
                selected: selected,
                enabled: !s.checked,
                child: Material(
                  color: background,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: borderColor,
                      width: selected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    key: ValueKey('bank-choice-$i'),
                    borderRadius: BorderRadius.circular(16),
                    onTap: s.checked
                        ? null
                        : () => setState(() {
                            entry.text = options[i];
                            inputMessage = null;
                          }),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: compact ? 52 : 64),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: selected ? 7 : 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: DemoMath(
                                options[i],
                                size: compact ? 25 : 30,
                                height: 1.2,
                              ),
                            ),
                            if (selected && s.checked) ...[
                              const SizedBox(width: 12),
                              Icon(
                                correct ? Icons.check : Icons.close,
                                color: borderColor,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TaskBank>(
    future: loading,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return Scaffold(
          body: Center(
            child: snapshot.hasError
                ? const Text(
                    'Не удалось загрузить банк заданий. Обнови страницу.',
                  )
                : const CircularProgressIndicator(),
          ),
        );
      }
      final bank = snapshot.data!;
      final s = session;
      if (page == 'topics') {
        return TopicsScreen(
          titles: [bank.title.replaceFirst('общего ', 'общего\n')],
          successes: [s?.successPercent.floor()],
          completedStates: [s?.isFinished ?? false],
          onTopicSelected: (_) => setState(() {
            page = s == null
                ? 'start'
                : s.isFinished
                ? 'results'
                : 'practice';
          }),
        );
      }
      return DemoPage(
        label: page == 'results'
            ? 'Итоги'
            : page == 'review'
            ? 'Разбор ошибок'
            : page == 'recap'
            ? 'Закрепление'
            : 'Практика',
        topic: bank.title,
        onTopics: () => setState(() => page = 'topics'),
        showSuccess: s != null,
        successPercent: s?.successPercent ?? 0,
        visibleScrollbar: true,
        scrollKey: page == 'practice'
            ? '${s!.currentTask.id}-${s.checked}'
            : page,
        bodyBuilder: (context, wide, compact) {
          final c = ScreenColors(context);
          if (page == 'practice') return _practice(bank, c, wide, compact);
          if (page == 'review') {
            final record = _errors[reviewIndex];
            return SharedField(
              wide: wide,
              compact: compact,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _text('Ошибка ${reviewIndex + 1} из ${_errors.length}', c),
                  const SizedBox(height: 16),
                  _text(record.task.instruction, c),
                  DemoMath(record.task.expression, size: compact ? 42 : 54),
                  const SizedBox(height: 20),
                  _text('Твой ответ: ${record.answer}', c),
                  const SizedBox(height: 12),
                  _text('Правильная запись', c),
                  DemoMath(record.task.expectedAnswer, size: 30),
                ],
              ),
            );
          }
          if (page == 'recap') {
            return SharedField(
              wide: wide,
              compact: compact,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _text('Что мы практиковали', c, size: 28),
                  for (final block in bank.blocks.where(
                    (b) => session!.attempts.any((a) => a.blockId == b.id),
                  )) ...[
                    const Divider(height: 28),
                    _text(block.skill, c),
                    DemoMath(
                      session!.attempts
                          .firstWhere((a) => a.blockId == block.id)
                          .task
                          .expectedAnswer,
                      size: 26,
                    ),
                  ],
                ],
              ),
            );
          }
          return SharedField(
            wide: wide,
            compact: compact,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (page == 'results') ...[
                  _text('Проходной порог достигнут', c, size: 28),
                  const SizedBox(height: 16),
                ],
                _summary(bank, c),
                if (page == 'results' && s != null) ...[
                  const SizedBox(height: 16),
                  _text(
                    'Ошибок: ${s.attempts.where((a) => !a.correct).length}',
                    c,
                  ),
                ],
              ],
            ),
          );
        },
        footerBuilder: (context, wide, compact) =>
            _actions(context, wide, compact, bank),
      );
    },
  );
}
