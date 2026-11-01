import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bank_trainer.dart';
import '../demo_screens.dart';
import '../generator/pdf_generator_screen.dart';
import 'generated_session.dart';
import 'session_storage.dart';
import 'topic_catalog.dart';

class GeneratedPracticeHome extends StatefulWidget {
  const GeneratedPracticeHome({
    super.key,
    this.readText,
    this.readHistory,
    this.writeHistory,
    this.allowHistoryReset = false,
  });
  final Future<String> Function(String)? readText;
  final String? Function()? readHistory;
  final void Function(String)? writeHistory;
  final bool allowHistoryReset;
  @override
  State<GeneratedPracticeHome> createState() => _GeneratedPracticeHomeState();
}

class _GeneratedPracticeHomeState extends State<GeneratedPracticeHome> {
  late final Future<String> loading = _load();
  List<GeneratedSession> sessions = [];
  GeneratedSession? active;
  String? error;
  bool corruptHistory = false;

  Future<String> _load() async {
    final source = await (widget.readText ?? rootBundle.loadString)(
      'bank/templates/common_factor.json',
    );
    try {
      final history = (widget.readHistory ?? readPracticeHistory)();
      if (history != null) sessions = decodeGeneratedSessions(history);
    } catch (_) {
      corruptHistory = true;
      error = 'Сохранённая история недоступна. Она не перезаписана. Новые занятия сохраняются только до закрытия страницы.';
    }
    return source;
  }

  void _save() {
    if (corruptHistory) return;
    try {
      (widget.writeHistory ?? writePracticeHistory)(
        encodeGeneratedSessions(sessions),
      );
      if (error != null) setState(() => error = null);
    } catch (_) {
      const message =
          'Не удалось сохранить занятие в браузере. Не закрывай страницу: изменения пока только в памяти.';
      if (error != message) setState(() => error = message);
    }
  }

  Future<void> _resetHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Сбросить историю?'),
        content: const Text(
          'Все сохранённые занятия, ответы и успешность в этом браузере будут удалены. '
          'Отменить это действие нельзя.\n\n'
          'Новые занятия начнутся с 0% и выбора ответа.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('reset-history-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const ValueKey('reset-history-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      // Replace only this app's history, including unreadable old snapshots.
      // Persist first: if storage refuses the write, keep the in-memory history.
      (widget.writeHistory ?? writePracticeHistory)(
        encodeGeneratedSessions([]),
      );
      setState(() {
        sessions = [];
        active = null;
        corruptHistory = false;
        error = null;
      });
    } catch (_) {
      setState(
        () => error =
            'Не удалось сбросить историю. Данные не удалены. Попробуй ещё раз.',
      );
    }
  }

  void _start(String source, String family) {
    try {
      final seed = DateTime.now().microsecondsSinceEpoch;
      final session = GeneratedSession.start(
        family: family,
        source: source,
        id: '$family-$seed',
        seed: seed,
      );
      setState(() {
        sessions.insert(0, session);
        active = session;
      });
      _save();
    } catch (_) {
      setState(
        () => error =
            'Не удалось подготовить задания. Попробуй начать занятие ещё раз.',
      );
    }
  }

  Future<void> _openTopic(String family, String source) async {
    final saved = sessions
        .where((s) => s.practice.bank.topicId == generatedTopicId(family))
        .firstOrNull;
    if (saved == null) {
      if (family.endsWith('_bracket')) {
        try {
          source = await (widget.readText ?? rootBundle.loadString)(
            generatedTemplatePath(family),
          );
          if (!mounted) return;
        } catch (_) {
          if (mounted) {
            setState(
              () => error =
                  'Не удалось загрузить шаблоны темы. Попробуй ещё раз.',
            );
          }
          return;
        }
      }
      _start(source, family);
      return;
    }
    try {
      final restored = GeneratedSession.fromJson(
        jsonDecode(jsonEncode(saved.toJson())),
      ).withDemoFeedback();
      setState(() {
        sessions[sessions.indexOf(saved)] = restored;
        active = restored;
      });
    } catch (_) {
      setState(
        () => error =
            'Не удалось открыть сохранённую практику. Данные не удалены.',
      );
    }
  }

  Widget _warning(Widget content) => Column(
    children: [
      if (error != null)
        Material(
          color: Theme.of(context).colorScheme.errorContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(error!),
            ),
          ),
        ),
      Expanded(child: content),
    ],
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: loading,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return Scaffold(
          body: Center(
            child: snapshot.hasError
                ? const Text('Не удалось загрузить шаблоны. Обнови страницу.')
                : const CircularProgressIndicator(),
          ),
        );
      }
      final source = snapshot.data!;
      if (active != null) {
        final current = active!;
        return _warning(
          BankTrainer(
            key: ValueKey(current.id),
            initialSession: current.practice,
            initialView: current.view,
            onSave: (view) {
              current.view = view;
              _save();
            },
            onExit: () => setState(() => active = null),
          ),
        );
      }
      {
        const topics = practiceTopicCatalog;
        final latest = [
          for (final topic in topics)
            topic.available
                ? sessions
                      .where((s) => s.practice.bank.topicId == topic.id)
                      .firstOrNull
                : null,
        ];
        return _warning(
          TopicsScreen(
            onResetHistory: widget.allowHistoryReset ? _resetHistory : null,
            titles: topics.map((t) => t.title).toList(),
            subtitles: topics.map((t) => t.caption).toList(),
            enabledStates: topics.map((t) => t.available).toList(),
            successes: latest
                .map((s) => s?.practice.successPercent.floor())
                .toList(),
            completedStates: latest
                .map((s) => s?.practice.canFinish ?? false)
                .toList(),
            onTopicSelected: (index) {
              final family = topics[index].family;
              if (family != null) _openTopic(family, source);
            },
            onGeneratePdf: (index) async {
              final family = topics[index].family;
              if (family == null) return;
              var catalog = source;
              if (family.endsWith('_bracket')) {
                try {
                  catalog = await (widget.readText ?? rootBundle.loadString)(
                    generatedTemplatePath(family),
                  );
                  if (!mounted) return;
                } catch (_) {
                  if (mounted) {
                    setState(
                      () => error =
                          'Не удалось загрузить шаблоны PDF. Попробуй ещё раз.',
                    );
                  }
                  return;
                }
              }
              if (!context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      PdfGeneratorScreen(catalogText: catalog, family: family),
                ),
              );
            },
          ),
        );
      }
    },
  );
}
