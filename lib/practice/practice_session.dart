import '../bank/task_bank.dart';

class PracticeSettings {
  PracticeSettings({
    required this.minimumAnswers,
    required this.successWindow,
    required this.passPercent,
    required this.extraTasksPerError,
    this.inputPercent = 70,
  }) {
    if (minimumAnswers < 1 ||
        successWindow < 1 ||
        passPercent < 1 ||
        passPercent > 100 ||
        extraTasksPerError < 1 ||
        inputPercent < 0 ||
        inputPercent > 100) {
      throw ArgumentError('Invalid practice settings');
    }
  }

  final int minimumAnswers;
  final int successWindow;
  final int passPercent;
  final int extraTasksPerError;
  final int inputPercent;
}

class TaskAttempt {
  const TaskAttempt({
    required this.task,
    required this.blockId,
    required this.answer,
    required this.correct,
    required this.isExtra,
    this.usesInput = false,
  });
  final BankTask task;
  final String blockId;
  final String answer;
  final bool correct;
  final bool isExtra;
  final bool usesInput;
}

/// One initial task per block. After an error, require a consecutive correct
/// streak on that block; another error resets the required streak.
/// No new mathematical exercises are generated; source tasks rotate on reuse.
class PracticeSession {
  PracticeSession({required this.bank, required this.settings}) {
    _nextTask();
  }

  final TaskBank bank;
  final PracticeSettings settings;
  final List<TaskAttempt> _attempts = [];
  final List<int> _extraBlocks = [];
  final Map<int, int> _taskCursors = {};
  final Map<int, int> _errorStreaks = {};
  int _primaryCursor = 0;
  int _reviewCursor = 0;
  late int _blockIndex;
  late BankTask _task;
  bool _isExtra = false;
  bool _checked = false;
  bool _usesInput = false;
  bool _finished = false;

  List<TaskAttempt> get attempts => List.unmodifiable(_attempts);
  BankTask get currentTask => _task;
  BankBlock get currentBlock => bank.blocks[_blockIndex];
  bool get currentIsExtra => _isExtra;
  bool get checked => _checked;
  bool get isFinished => _finished;

  /// Fixed for the open task, even when its answer changes the percentage.
  bool get usesInput => _usesInput;
  int get pendingExtraTasks => _extraBlocks.length;
  int get initialBlocksAnswered => _primaryCursor;
  int get currentBlockErrorStreak => _errorStreaks[_blockIndex] ?? 0;
  bool get needsDetailedExplanation => currentBlockErrorStreak >= 3;

  List<TaskAttempt> get recentAttempts => List.unmodifiable(
    _attempts.skip(
      (_attempts.length - settings.successWindow).clamp(0, _attempts.length),
    ),
  );

  double get successPercent {
    final recent = recentAttempts;
    // The denominator is the full configured window from the first attempt.
    // Empty slots lower the initial percentage but are not recorded as errors.
    return recent.where((a) => a.correct).length * 100 / settings.successWindow;
  }

  bool get canFinish {
    final recent = recentAttempts;
    return recent.where((a) => a.correct).length * 100 >=
        settings.successWindow * settings.passPercent;
  }

  void finish() {
    if (_finished || !canFinish) {
      throw StateError('This session cannot be finished');
    }
    _finished = true;
  }

  /// Continuing is an explicit action; viewing old answers does not reopen it.
  void resume() {
    if (!_finished) throw StateError('Practice is already active');
    _finished = false;
  }

  /// Called only after a supported answer has been checked, never for previews.
  void submit({required String answer, required bool correct}) {
    if (_checked || _finished) {
      throw StateError('This task cannot be submitted again');
    }
    _attempts.add(
      TaskAttempt(
        task: _task,
        blockId: currentBlock.id,
        answer: answer,
        correct: correct,
        isExtra: _isExtra,
        usesInput: _usesInput,
      ),
    );
    if (_isExtra) {
      _extraBlocks.removeAt(0);
    } else if (_primaryCursor < bank.blocks.length) {
      _primaryCursor++;
    }
    _errorStreaks[_blockIndex] = correct ? 0 : currentBlockErrorStreak + 1;
    if (!correct) {
      // A new error restarts the streak, rather than accumulating a task debt.
      _extraBlocks.removeWhere((block) => block == _blockIndex);
      _extraBlocks.insertAll(
        0,
        List.filled(settings.extraTasksPerError, _blockIndex),
      );
    }
    _checked = true;
  }

  void advance() {
    if (!_checked) throw StateError('Check the current task first');
    if (_finished) throw StateError('Practice has already finished');
    _nextTask();
  }

  Map<String, dynamic> toJson() => {
    'schema_version': 1,
    'bank': bank.toJson(),
    'settings': {
      'minimum_answers': settings.minimumAnswers,
      'success_window': settings.successWindow,
      'pass_percent': settings.passPercent,
      'extra_tasks_per_error': settings.extraTasksPerError,
      'input_percent': settings.inputPercent,
    },
    'attempts': _attempts
        .map(
          (a) => {
            'task_id': a.task.id,
            'block_id': a.blockId,
            'answer': a.answer,
            'correct': a.correct,
            'is_extra': a.isExtra,
            'uses_input': a.usesInput,
          },
        )
        .toList(),
    'extra_blocks': _extraBlocks,
    'task_cursors': _taskCursors.map((k, v) => MapEntry('$k', v)),
    'error_streaks': _errorStreaks.map((k, v) => MapEntry('$k', v)),
    'primary_cursor': _primaryCursor,
    'review_cursor': _reviewCursor,
    'block_index': _blockIndex,
    'task_id': _task.id,
    'is_extra': _isExtra,
    'checked': _checked,
    'uses_input': _usesInput,
    'finished': _finished,
  };

  factory PracticeSession.fromJson(Map<String, dynamic> json) {
    if (json['schema_version'] != 1) {
      throw const FormatException('Session version');
    }
    final bank = TaskBank.fromSnapshot(Map<String, dynamic>.from(json['bank']));
    final config = json['settings'] as Map;
    final s = PracticeSession(
      bank: bank,
      settings: PracticeSettings(
        minimumAnswers: config['minimum_answers'] as int,
        successWindow: config['success_window'] as int,
        passPercent: config['pass_percent'] as int,
        extraTasksPerError: config['extra_tasks_per_error'] as int,
        inputPercent: config['input_percent'] as int,
      ),
    );
    final tasks = {
      for (final b in bank.blocks)
        for (final t in b.tasks) t.id: t,
    };
    s._blockIndex = json['block_index'] as int;
    if (s._blockIndex < 0 || s._blockIndex >= bank.blocks.length) {
      throw const FormatException('Session block');
    }
    s._task =
        tasks[json['task_id']] ?? (throw const FormatException('Session task'));
    if (!s.currentBlock.tasks.contains(s._task)) {
      throw const FormatException('Task outside block');
    }
    s._attempts.addAll(
      (json['attempts'] as List).map((a) {
        final task =
            tasks[a['task_id']] ??
            (throw const FormatException('Attempt task'));
        if (!bank.blocks.any(
          (b) => b.id == a['block_id'] && b.tasks.contains(task),
        )) {
          throw const FormatException('Attempt block');
        }
        return TaskAttempt(
          task: task,
          blockId: a['block_id'] as String,
          answer: a['answer'] as String,
          correct: a['correct'] as bool,
          isExtra: a['is_extra'] as bool,
          usesInput: a['uses_input'] as bool,
        );
      }),
    );
    s._extraBlocks.addAll((json['extra_blocks'] as List).cast<int>());
    if (s._extraBlocks.any((b) => b < 0 || b >= bank.blocks.length)) {
      throw const FormatException('Extra blocks');
    }
    void restoreMap(String key, Map<int, int> target) {
      target.clear();
      (json[key] as Map).forEach((k, v) {
        final index = int.parse(k as String);
        if (index < 0 || index >= bank.blocks.length || v is! int || v < 0) {
          throw const FormatException('Session cursor');
        }
        target[index] = v;
      });
    }

    restoreMap('task_cursors', s._taskCursors);
    restoreMap('error_streaks', s._errorStreaks);
    s._primaryCursor = json['primary_cursor'] as int;
    s._reviewCursor = json['review_cursor'] as int;
    if (s._primaryCursor < 0 ||
        s._primaryCursor > bank.blocks.length ||
        s._reviewCursor < 0) {
      throw const FormatException('Session position');
    }
    s._isExtra = json['is_extra'] as bool;
    s._checked = json['checked'] as bool;
    s._usesInput = json['uses_input'] as bool;
    s._finished = json['finished'] as bool;
    if (s._checked &&
        (s._attempts.isEmpty || s._attempts.last.task.id != s._task.id)) {
      throw const FormatException('Checked task');
    }
    return s;
  }

  void _nextTask() {
    final recent = recentAttempts;
    _usesInput =
        settings.inputPercent == 0 ||
        (recent.isNotEmpty &&
            recent.where((a) => a.correct).length * 100 >=
                settings.successWindow * settings.inputPercent);
    _checked = false;
    _isExtra = _extraBlocks.isNotEmpty;
    _blockIndex = _isExtra
        ? _extraBlocks.first
        : _primaryCursor < bank.blocks.length
        ? _primaryCursor
        : _reviewCursor++ % bank.blocks.length;
    final tasks = currentBlock.tasks;
    final cursor = _taskCursors[_blockIndex] ?? 0;
    _task = tasks[cursor % tasks.length];
    _taskCursors[_blockIndex] = cursor + 1;
  }
}
