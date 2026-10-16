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
  });
  final BankTask task;
  final String blockId;
  final String answer;
  final bool correct;
  final bool isExtra;
}

/// One initial task per block. Every error adds tasks from that same block.
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
      ),
    );
    if (_isExtra) {
      _extraBlocks.removeAt(0);
    } else if (_primaryCursor < bank.blocks.length) {
      _primaryCursor++;
    }
    _errorStreaks[_blockIndex] = correct ? 0 : currentBlockErrorStreak + 1;
    if (!correct) {
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
