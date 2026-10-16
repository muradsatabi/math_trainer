import 'dart:async';

import 'package:flutter/material.dart';

import '../bank/task_bank.dart';
import '../completion_screens.dart' show DemoMath;
import '../demo_screens.dart';

/// Mandatory viewing mechanics; approved step-by-step content is added later.
class RequiredExplanationScreen extends StatefulWidget {
  const RequiredExplanationScreen({
    super.key,
    required this.topic,
    required this.task,
    required this.skill,
    required this.successPercent,
    required this.onContinue,
    required this.onTopics,
  });

  final String topic, skill;
  final BankTask task;
  final double successPercent;
  final VoidCallback onContinue, onTopics;

  @override
  State<RequiredExplanationScreen> createState() =>
      _RequiredExplanationScreenState();
}

class _RequiredExplanationScreenState extends State<RequiredExplanationScreen>
    with WidgetsBindingObserver {
  int remaining = 10;
  bool active = true;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    active =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (active) _startTimer();
  }

  void _startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => remaining--);
      if (remaining == 0) timer?.cancel();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (!active) {
      timer?.cancel();
    } else if (remaining > 0 && !(timer?.isActive ?? false)) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: DemoPage(
      showLabel: false,
      topic: widget.topic,
      showSuccess: true,
      successPercent: widget.successPercent,
      visibleScrollbar: true,
      topicsEnabled: remaining == 0,
      onTopics: widget.onTopics,
      bodyBuilder: (context, wide, compact) {
        final c = ScreenColors(context);
        return SharedField(
          wide: wide,
          compact: compact,
          body: Column(
            key: const ValueKey('bank-required-explanation'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Давай разберёмся',
                style: screenText(compact ? 26 : 32, c.ink, heading: true),
              ),
              const SizedBox(height: 16),
              Text(widget.skill, style: screenText(20, c.ink)),
              const SizedBox(height: 20),
              Text(widget.task.instruction, style: screenText(18, c.sub)),
              const SizedBox(height: 12),
              DemoMath(widget.task.expression, size: compact ? 34 : 44),
              const Divider(height: 32),
              Text('Правильная запись', style: screenText(18, c.sub)),
              const SizedBox(height: 12),
              DemoMath(widget.task.expectedAnswer, size: compact ? 30 : 40),
            ],
          ),
        );
      },
      footerBuilder: (context, wide, compact) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (remaining > 0) ...[
            Text(
              'Продолжить можно через $remaining с',
              key: const ValueKey('bank-explanation-countdown'),
              style: screenText(16, ScreenColors(context).sub),
            ),
            const SizedBox(height: 8),
          ],
          PrimaryAction(
            key: const ValueKey('bank-explanation-continue'),
            label: 'Продолжить решение',
            wide: wide,
            compact: compact,
            onPressed: remaining == 0 ? widget.onContinue : null,
          ),
        ],
      ),
    ),
  );
}
