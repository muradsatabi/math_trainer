import 'generator/pdf_generator_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bank/factor_answer_checker.dart';
import 'bank/task_bank.dart';
import 'practice/required_explanation_screen.dart';
import 'completion_screens.dart' show DemoColumns, DemoMath;
import 'demo_screens.dart';
import 'practice/practice_session.dart';
import 'practice/answer_keyboard.dart';
import 'practice/power_notation.dart';
import 'practice/answer_choices.dart';
import 'practice/generated_session.dart';
import 'answer_form.dart';

/// Real practice entry point. The original V3 demo screens remain previewable.
class BankTrainer extends StatefulWidget {
  const BankTrainer({
    super.key,
    this.readText,
    this.initialSession,
    this.initialView,
    this.onSave,
    this.onExit,
    this.loadPractice,
  });
  final PracticeSession? initialSession;
  final Map<String, dynamic>? initialView;
  final void Function(Map<String, dynamic> view)? onSave;
  final VoidCallback? onExit;
  final BankTextReader? readText;
  final Future<PracticeSession> Function()? loadPractice;
  @override
  State<BankTrainer> createState() => _BankTrainerState();
}

class _SavedPracticeView {
  const _SavedPracticeView(
    this.entry,
    this.message,
    this.showAnswer, {
    this.powerInput = false,
  });
  final TextEditingValue entry;
  final String? message;
  final bool showAnswer;
  final bool powerInput;
}

class _BankTrainerState extends State<BankTrainer> {
  final entry = TextEditingController();
  late final Future<TaskBank> loading = _load();
  late PracticeSettings settings;
  PracticeSession? session;
  String page = 'topics';
  String? inputMessage;
  bool showAnswer = false;
  bool _powerInput = false;
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

  bool _restoring = false;

  void _update(VoidCallback change) {
    setState(change);
    _persist();
  }

  Map<String, dynamic> _encodeView(_SavedPracticeView view) => {
    'text': view.entry.text,
    'base': view.entry.selection.baseOffset,
    'extent': view.entry.selection.extentOffset,
    'message': view.message,
    'show_answer': view.showAnswer,
    'power_input': view.powerInput,
  };

  _SavedPracticeView _decodeView(Map value) {
    final rawText = value['text'] as String;
    final text = displayPowers(rawText);
    int offset(String key) {
      final saved = (value[key] as int).clamp(-1, rawText.length);
      return saved < 0
          ? saved
          : displayPowers(rawText.substring(0, saved)).length
                .clamp(0, text.length);
    }

    return _SavedPracticeView(
      TextEditingValue(
        text: text,
        selection: TextSelection(
          baseOffset: offset('base'),
          extentOffset: offset('extent'),
        ),
      ),
      value['message'] as String?,
      value['show_answer'] as bool,
      powerInput: value['power_input'] as bool? ?? false,
    );
  }

  void _persist() {
    if (_restoring || session == null || widget.onSave == null) return;
    widget.onSave!({
      'page': page,
      'history_index': historyIndex,
      'review_index': reviewIndex,
      'current': _encodeView(
        _SavedPracticeView(
          entry.value,
          inputMessage,
          showAnswer,
          powerInput: _powerInput,
        ),
      ),
      'saved_views': savedViews.map((k, v) => MapEntry('$k', _encodeView(v))),
    });
  }

  void _goTopics() {
    if (widget.onExit != null) {
      _persist();
      widget.onExit!();
    } else {
      _update(() => page = 'topics');
    }
  }

  void _saveView() {
    savedViews[historyIndex ?? -1] = _SavedPracticeView(
      entry.value,
      inputMessage,
      showAnswer,
      powerInput: _powerInput,
    );
  }

  void _openTask(int? index) {
    _update(() {
      if (page == 'practice') _saveView();
      historyIndex = index;
      final saved = savedViews[index ?? -1];
      entry.value =
          saved?.entry ??
          TextEditingValue(
            text: index == null
                ? ''
                : displayPowers(session!.attempts[index].answer),
          );
      inputMessage = saved?.message;
      showAnswer = saved?.showAnswer ?? false;
      _powerInput = index == null && (saved?.powerInput ?? false);
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
    _update(() => page = 'results');
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

  int get _entryCursor =>
      entry.selection.isValid ? entry.selection.end : entry.text.length;
  bool _canPowerAt(String text, int cursor) =>
      cursor > 0 &&
      cursor <= text.length &&
      (RegExp(r'[0-9a-zA-Z)]').hasMatch(text[cursor - 1]) ||
          isSuperscriptDigit(text[cursor - 1]));
  bool get _canPower => _powerInput || _canPowerAt(entry.text, _entryCursor);
  bool get _powerPending =>
      _powerInput &&
      (_entryCursor == 0 || !isSuperscriptDigit(entry.text[_entryCursor - 1]));
  bool get _complete =>
      !_powerPending && isCompleteAnswer(entry.text.replaceAll('·', '×'));

  TextEditingValue _formatPowerEntry(
    TextEditingValue oldValue,
    TextEditingValue value,
  ) {
    if (!_powerInput) return value;
    var prefix = 0;
    while (prefix < oldValue.text.length &&
        prefix < value.text.length &&
        oldValue.text[prefix] == value.text[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < oldValue.text.length - prefix &&
        suffix < value.text.length - prefix &&
        oldValue.text[oldValue.text.length - 1 - suffix] ==
            value.text[value.text.length - 1 - suffix]) {
      suffix++;
    }
    if (!_canPowerAt(value.text, prefix)) {
      _powerInput = false;
      return value;
    }
    final inserted = value.text.substring(prefix, value.text.length - suffix);
    final converted = StringBuffer();
    for (final char in inserted.split('')) {
      if (_powerInput && RegExp(r'^[0-9]$').hasMatch(char)) {
        converted.write(superscriptDigit(char));
      } else {
        _powerInput = false;
        converted.write(char);
      }
    }
    return value.copyWith(
      text:
          value.text.substring(0, prefix) +
          converted.toString() +
          value.text.substring(value.text.length - suffix),
    );
  }

  bool get _unsupportedSymbol =>
      RegExp(r'[^0-9a-zA-Z⁰¹²³⁴⁵⁶⁷⁸⁹^\s()+−×÷*/·-]').hasMatch(entry.text);

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
            onPressed: () => _update(() => page = 'recap'),
          ),
          SecondaryAction(
            label: 'К темам',
            compact: compact,
            onPressed: _goTopics,
          ),
          if (_errors.isNotEmpty)
            PrimaryAction(
              label: 'Разобрать ошибки',
              wide: wide,
              compact: compact,
              onPressed: () => _update(() {
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
                ? () => _update(() => reviewIndex--)
                : null,
          ),
          if (_errors.length > 1)
            if (reviewIndex < _errors.length - 1)
              SecondaryAction(
                label: 'Следующая ошибка',
                compact: compact,
                onPressed: () => _update(() => reviewIndex++),
              )
            else
              OutlinedButton.icon(
                onPressed: () => _update(() => reviewIndex = 0),
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
            onPressed: () => _update(() => page = 'results'),
          ),
        ],
      );
    }
    return PrimaryAction(
      label: page == 'recap' ? 'К итогам' : 'Начать практику',
      wide: wide,
      compact: compact,
      onPressed: () => _update(() {
        if (page == 'recap') {
          page = 'results';
          return;
        }
        session = PracticeSession(bank: bank, settings: settings);
        page = 'practice';
        _powerInput = false;
        entry.clear();
      }),
    );
  }

  void _insert(String symbol) {
    if (_checked) return;
    final selection = entry.selection;
    final start = selection.isValid ? selection.start : entry.text.length;
    final end = selection.isValid ? selection.end : entry.text.length;
    if (symbol == '^') {
      if (!_canPower) return;
      _update(() {
        _powerInput = !_powerInput;
        entry.selection = TextSelection.collapsed(offset: end);
        inputMessage = null;
      });
      return;
    }
    _update(() {
      if (_powerInput &&
          _canPowerAt(entry.text, start) &&
          RegExp(r'^[0-9]$').hasMatch(symbol)) {
        symbol = superscriptDigit(symbol);
      } else {
        _powerInput = false;
      }
      entry.value = TextEditingValue(
        text: entry.text.replaceRange(start, end, symbol),
        selection: TextSelection.collapsed(offset: start + symbol.length),
      );
      inputMessage = null;
    });
  }

  void _clear() {
    if (_checked) return;
    _update(() {
      entry.clear();
      _powerInput = false;
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
    _update(() {
      entry.value = TextEditingValue(
        text: entry.text.replaceRange(previous, end, ''),
        selection: TextSelection.collapsed(offset: previous),
      );
      if (entry.text.isEmpty) _powerInput = false;
      inputMessage = null;
    });
  }

  int get _previousIndex => _history
      ? historyIndex! - 1
      : session!.attempts.length - (session!.checked ? 2 : 1);

  void _previous() {
    if (_previousIndex >= 0) _openTask(_previousIndex);
  }

  bool _openingGenerator = false;
  Future<void> _openPdfGenerator() async {
    if (_openingGenerator) return;
    _openingGenerator = true;
    try {
      final text = await (widget.readText ?? rootBundle.loadString)(
        'bank/templates/common_factor.json',
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PdfGeneratorScreen(catalogText: text),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось загрузить шаблоны. Попробуйте ещё раз.'),
          ),
        );
      }
    } finally {
      _openingGenerator = false;
    }
  }

  Future<TaskBank> _load() async {
    if (widget.initialSession != null) {
      _restoring = true;
      session = widget.initialSession;
      settings = session!.settings;
      page = session!.isFinished ? 'results' : 'practice';
      final view = widget.initialView;
      if (view != null) {
        final savedPage = view['page'] as String;
        if ([
          'practice',
          'results',
          'review',
          'recap',
          'explanation',
        ].contains(savedPage)) {
          page = savedPage;
        }
        historyIndex = view['history_index'] as int?;
        if (historyIndex != null &&
            (historyIndex! < 0 || historyIndex! >= session!.attempts.length)) {
          throw const FormatException('Invalid saved history position');
        }
        reviewIndex = view['review_index'] as int;
        final current = _decodeView(view['current'] as Map);
        entry.value = current.entry;
        inputMessage = current.message;
        showAnswer = current.showAnswer;
        _powerInput = current.powerInput;
        (view['saved_views'] as Map).forEach(
          (k, v) => savedViews[int.parse(k as String)] = _decodeView(v as Map),
        );
      }
      _restoring = false;
      entry.addListener(_persist);
      return session!.bank;
    }
    final prepared = widget.loadPractice != null
        ? await widget.loadPractice!()
        : GeneratedSession.start(
            family: 'numeric',
            source: await (widget.readText ?? rootBundle.loadString)(
              'bank/templates/common_factor.json',
            ),
            id: 'practice-${DateTime.now().microsecondsSinceEpoch}',
            seed: DateTime.now().microsecondsSinceEpoch,
          ).practice;
    settings = prepared.settings;
    return prepared.bank;
  }

  @override
  void dispose() {
    entry.removeListener(_persist);
    entry.dispose();
    super.dispose();
  }

  void _check() {
    final s = session!;
    if (_checked || (!_history && s.isFinished)) return;
    if (!_complete) {
      _update(
        () => inputMessage = _unsupportedSymbol
            ? 'Эта запись пока не поддерживается. Ответ не оценён.'
            : 'Ты не закончил запись. Допиши ответ',
      );
      return;
    }
    final verdict = checkFactorAnswer(_task, entry.text);
    _update(() {
      _powerInput = false;
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
        if (verdict == AnswerVerdict.incorrect && s.needsDetailedExplanation) {
          page = 'explanation';
        }
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
        _update(() => page = 'results');
      } else {
        _openTask(null);
        if (s.checked) _next();
      }
      return;
    }
    _update(() {
      s.advance();
      savedViews.remove(-1);
      entry.clear();
      _powerInput = false;
      inputMessage = null;
      showAnswer = false;
    });
  }

  void _finish() {
    final s = session!;
    if (!s.canFinish || s.isFinished) return;
    _update(() {
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
                              inputFormatters: [
                                TextInputFormatter.withFunction(
                                  _formatPowerEntry,
                                ),
                              ],
                              style: TextStyle(
                                fontFamily: 'Caladea',
                                fontFamilyFallback: const ['Carlito'],
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
                                  _update(() => inputMessage = null),
                              onTapOutside: (_) {
                                if (!_checked &&
                                    entry.text.isNotEmpty &&
                                    !_complete) {
                                  _update(
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
                  powerInput: _powerInput,
                  powerEnabled: _canPower,
                  message: message,
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
            if (!_usesInput && message != null) ...[
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
                  if (_checked && !correct && task.demoChoices != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      answerFeedback(task, entry.text)?.hint ?? 'Проверь обратным действием: раскрой скобки и сравни каждое слагаемое с исходным выражением.',
                      key: const ValueKey('bank-error-hint'),
                      style: screenText(17, c.ink, height: 1.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Подсказка · демонстрационный вариант',
                      style: screenText(12, c.sub),
                    ),
                  ],
                  if (_checked && !correct && !showAnswer) ...[
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () => _update(() => showAnswer = true),
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
                        : () => _update(() {
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
          onGeneratePdf: (_) => _openPdfGenerator(),
          onTopicSelected: (_) => _update(() {
            page = s == null
                ? 'start'
                : s.isFinished
                ? 'results'
                : 'practice';
          }),
        );
      }
      if (page == 'explanation') {
        return RequiredExplanationScreen(
          topic: bank.title,
          topicId: bank.topicId,
          task: s!.currentTask,
          skill: s.currentBlock.skill,
          successPercent: s.successPercent,
          onTopics: _goTopics,
          onContinue: () {
            _update(() => page = 'practice');
            _next();
          },
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
        onTopics: _goTopics,
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
