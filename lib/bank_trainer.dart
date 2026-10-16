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

class _SavedPracticeView {
  const _SavedPracticeView(this.entry, this.message, this.showAnswer);
  final TextEditingValue entry;
  final String? message;
  final bool showAnswer;
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
  int? historyIndex;
  final Map<int, _SavedPracticeView> savedViews = {};
  bool get _history => historyIndex != null;
  TaskAttempt? get _record =>
      _history ? session!.attempts[historyIndex!] : null;
  BankTask get _task => _record?.task ?? session!.currentTask;
  BankBlock get _block => _history
      ? session!.bank.blocks.firstWhere((b) => b.id == _record!.blockId)
      : session!.currentBlock;
  bool get _checked => _history || session!.checked;
  bool get _correct => _history
      ? _record!.correct
      : session!.checked && session!.attempts.last.correct;
  bool get _usesInput => _record?.usesInput ?? session!.usesInput;
  bool get _offerFinish => !session!.isFinished && session!.canFinish;

  void _saveView() {
    savedViews[historyIndex ?? -1] = _SavedPracticeView(
      entry.value,
      inputMessage,
      showAnswer,
    );
  }

  void _openTask(int? index) {
    setState(() {
      if (page == 'practice') _saveView();
      historyIndex = index;
      final saved = savedViews[index ?? -1];
      entry.value =
          saved?.entry ??
          TextEditingValue(
            text: index == null ? '' : session!.attempts[index].answer,
          );
      inputMessage = saved?.message;
      showAnswer = saved?.showAnswer ?? false;
      page = 'practice';
    });
  }

  void _returnToPractice() {
    final finished = session!.isFinished;
    if (finished) session!.resume();
    _openTask(null);
    if (finished && session!.checked) _next();
  }

  void _returnToResults() {
    _saveView();
    setState(() => page = 'results');
  }

  Widget _historyActions(bool compact) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (session!.isFinished) ...[
          Expanded(
            child: SecondaryAction(
              key: const ValueKey('bank-history-results'),
              label: 'К итогам',
              compact: compact,
              onPressed: _returnToResults,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 2,
          child: SecondaryAction(
            key: const ValueKey('bank-return-current'),
            label: session!.isFinished
                ? 'Продолжить решение'
                : 'Вернуться к текущему',
            compact: compact,
            onPressed: _returnToPractice,
          ),
        ),
      ],
    ),
  );

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
                key: const ValueKey('bank-previous-slot'),
                width: _usesInput
                    ? (bounds.maxWidth - 48) / 3
                    : (bounds.maxWidth - 12) / 3,
                child: _previousIndex < 0
                    ? const SizedBox.shrink()
                    : SecondaryAction(
                        key: const ValueKey('bank-previous'),
                        label: 'Предыдущее задание',
                        onPressed: _previousIndex >= 0 ? _previous : null,
                        compact: compact,
                      ),
              ),
              SizedBox(width: _usesInput ? 24 : 12),
              Expanded(
                child: PrimaryAction(
                  key: const ValueKey('bank-primary'),
                  label: _checked ? 'Дальше' : 'Проверить себя',
                  onPressed: !_checked && !_complete
                      ? null
                      : _checked
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
      final historyActions = _history
          ? _historyActions(compact)
          : const SizedBox.shrink();
      return LayoutBuilder(
        builder: (context, bounds) => bounds.maxWidth < 720
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  left,
                  if (_history) ...[const SizedBox(height: 8), historyActions],
                ],
              )
            : DemoColumns(wide: wide, left: left, right: historyActions),
      );
    }
    if (page == 'results') {
      return FooterActions(
        allowWrap: true,
        children: [
          SecondaryAction(
            label: 'Назад к решению',
            compact: compact,
            onPressed: () => _openTask(0),
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
    if (_checked) return;
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

  void _clear() {
    if (_checked) return;
    setState(() {
      entry.clear();
      inputMessage = null;
    });
  }

  void _delete() {
    if (_checked) return;
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

  int get _previousIndex => _history
      ? historyIndex! - 1
      : session!.attempts.length - (session!.checked ? 2 : 1);

  void _previous() {
    if (_previousIndex >= 0) _openTask(_previousIndex);
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
    if (_checked || (!_history && s.isFinished)) return;
    if (!_complete) {
      setState(
        () => inputMessage = _unsupportedSymbol
            ? 'Эта запись пока не поддерживается. Ответ не оценён.'
            : 'Ты не закончил запись. Допиши ответ',
      );
      return;
    }
    final verdict = checkFactorAnswer(_task, entry.text);
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
    if (_history) {
      final next = historyIndex! + 1;
      if (next < s.attempts.length) {
        _openTask(next);
      } else if (s.isFinished) {
        _saveView();
        setState(() => page = 'results');
      } else {
        _openTask(null);
        if (s.checked) _next();
      }
      return;
    }
    setState(() {
      s.advance();
      savedViews.remove(-1);
      entry.clear();
      inputMessage = null;
      showAnswer = false;
    });
  }

  void _finish() {
    final s = session!;
    if (!s.canFinish || s.isFinished) return;
    setState(() {
      _saveView();
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
          'После ошибки нужно решить ${settings.extraTasksPerError} задания того же типа правильно подряд.',
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
    final task = _task;
    final correct = _correct;
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
      narrowRightFirst: _checked || _offerFinish,
      left: Container(
        key: ValueKey(
          'bank-task-${_history ? historyIndex! + 1 : s.attempts.length + (_checked ? 0 : 1)}',
        ),
        padding: EdgeInsets.only(right: wide ? 42 : 30),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: c.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _text(task.instruction, c, size: compact ? 19 : 23),
            SizedBox(height: compact ? 8 : 18),
            DemoMath(task.expression, size: compact ? 36 : 54, height: 1.2),
            SizedBox(height: compact ? 10 : 24),
            Text(
              _usesInput ? 'Собери ответ:' : 'Выбери ответ:',
              style: screenText(compact ? 15 : 18, c.sub),
            ),
            const SizedBox(height: 12),
            if (!_usesInput) _choiceCards(task, c, compact),
            if (_usesInput) ...[
              LayoutBuilder(
                builder: (context, bounds) {
                  final textActions = bounds.maxWidth >= 600;
                  final canEdit = !_checked && entry.text.isNotEmpty;
                  return TextFieldTapRegion(
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: compact ? 56 : 72,
                            decoration: BoxDecoration(
                              color: !_checked
                                  ? c.paper
                                  : correct
                                  ? Color(c.dark ? 0xff233e35 : 0xffeaf6ee)
                                  : Color(c.dark ? 0xff452e36 : 0xfffff0ee),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                width: 2,
                                color: !_checked
                                    ? c.blue
                                    : correct
                                    ? Color(c.dark ? 0xff68c98b : 0xff28934c)
                                    : Color(c.dark ? 0xffb97e84 : 0xffcf7772),
                              ),
                            ),
                            child: TextField(
                              key: const ValueKey('bank-answer'),
                              controller: entry,
                              readOnly: _checked,
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
                                suffixIcon: _checked
                                    ? Icon(
                                        correct ? Icons.check : Icons.close,
                                        color: feedbackColor,
                                      )
                                    : null,
                              ),
                              onChanged: (_) =>
                                  setState(() => inputMessage = null),
                              onTapOutside: (_) {
                                if (!_checked &&
                                    entry.text.isNotEmpty &&
                                    !_complete) {
                                  setState(
                                    () => inputMessage = _unsupportedSymbol
                                        ? 'Эта запись пока не поддерживается. Ответ не оценён.'
                                        : 'Ты не закончил запись. Допиши ответ',
                                  );
                                }
                              },
                              onSubmitted: (_) {
                                if (!_checked) _check();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (textActions)
                          TextButton.icon(
                            key: const ValueKey('bank-delete'),
                            onPressed: canEdit ? _delete : null,
                            icon: const Icon(
                              Icons.backspace_outlined,
                              size: 20,
                            ),
                            label: const Text('Удалить символ'),
                          )
                        else
                          IconButton(
                            key: const ValueKey('bank-delete'),
                            onPressed: canEdit ? _delete : null,
                            tooltip: 'Удалить символ',
                            icon: const Icon(
                              Icons.backspace_outlined,
                              size: 20,
                            ),
                          ),
                        if (textActions)
                          TextButton(
                            key: const ValueKey('bank-clear'),
                            onPressed: canEdit ? _clear : null,
                            child: const Text('Очистить'),
                          )
                        else
                          IconButton(
                            key: const ValueKey('bank-clear'),
                            onPressed: canEdit ? _clear : null,
                            tooltip: 'Очистить',
                            icon: const Icon(Icons.clear_all, size: 22),
                          ),
                      ],
                    ),
                  );
                },
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
                  enabled: !_checked,
                  compact: compact,
                  onInsert: _insert,
                ),
              ),
            ],
            if (message != null) ...[
              const SizedBox(height: 12),
              _text(message, c, size: 16),
            ],
          ],
        ),
      ),
      right: _checked || _offerFinish
          ? Container(
              key: const ValueKey('bank-feedback-panel'),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: c.help,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_checked)
                    Text(
                      correct ? 'Абсолютно верно!' : 'Пока не получилось!',
                      key: const ValueKey('bank-feedback'),
                      style: screenText(24, feedbackColor, heading: true),
                    ),
                  if (_checked && !correct && !showAnswer) ...[
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () => setState(() => showAnswer = true),
                      child: const Text('Узнать, как правильно'),
                    ),
                  ],
                  if (_checked && showAnswer) ...[
                    const SizedBox(height: 16),
                    _text('Правильная запись', c),
                    const SizedBox(height: 8),
                    DemoMath(task.expectedAnswer, size: 28),
                    const SizedBox(height: 12),
                    _text(_block.skill, c, size: 16),
                  ],
                  if (_offerFinish) ...[
                    if (_checked) const Divider(height: 32),
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

  Widget _choiceCards(BankTask task, ScreenColors c, bool compact) {
    final options = answerChoices(task);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) SizedBox(height: compact ? 8 : 12),
          Builder(
            builder: (context) {
              final selected = entry.text == options[i];
              final correct = _correct;
              final borderColor = selected
                  ? _checked
                        ? correct
                              ? Color(c.dark ? 0xff68c98b : 0xff28934c)
                              : Color(c.dark ? 0xffb97e84 : 0xffcf7772)
                        : c.blue
                  : c.line;
              final background = selected
                  ? _checked
                        ? correct
                              ? Color(c.dark ? 0xff233e35 : 0xffeaf6ee)
                              : Color(c.dark ? 0xff452e36 : 0xfffff0ee)
                        : c.help
                  : c.paper;
              return Semantics(
                button: true,
                selected: selected,
                enabled: !_checked,
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
                    onTap: _checked
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
                            if (selected && _checked) ...[
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
          completedStates: [s?.canFinish ?? false],
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
        showLabel: page != 'practice',
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
            ? '${historyIndex ?? -1}-${_task.id}-$_checked'
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
