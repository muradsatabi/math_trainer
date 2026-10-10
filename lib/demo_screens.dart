import 'package:flutter/material.dart';

import 'main.dart' show PracticeScreen;
import 'constructor_screen.dart';

const fullTopic = 'Вынесение общего множителя за скобки';

void returnToTopics(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const TopicsScreen()),
    (_) => false,
  );
}

void showSuccessInfo(BuildContext context) {
  final c = ScreenColors(context);
  showDialog<void>(
    context: context,
    barrierColor: Color(c.dark ? 0x99000000 : 0x6620304c),
    builder: (context) => Dialog(
      backgroundColor: c.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: c.line),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Что означает успешность?',
                style: screenText(20, c.ink, heading: true),
              ),
              const SizedBox(height: 16),
              Text(
                'Это результат последних оцениваемых заданий. Процент может расти и снижаться. Он не означает процент освоения темы.',
                style: screenText(16, c.ink, height: 1.5),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Понятно'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class SuccessLabel extends StatelessWidget {
  const SuccessLabel({super.key, required this.style});
  final TextStyle style;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => showSuccessInfo(context),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Успешность', style: style),
        const SizedBox(width: 6),
        Icon(Icons.info_outline, size: 16, color: style.color),
      ],
    ),
  );
}

class ScreenColors {
  ScreenColors(BuildContext context)
    : dark = Theme.of(context).brightness == Brightness.dark;
  final bool dark;
  Color get paper => Color(dark ? 0xff182237 : 0xffffffff);
  Color get ink => Color(dark ? 0xffeef3ff : 0xff20304c);
  Color get sub => Color(dark ? 0xffb9c9e2 : 0xff586b87);
  Color get line => Color(dark ? 0xff3c506f : 0xffdce5f3);
  Color get blue => Color(dark ? 0xff3c70e6 : 0xff285bd8);
  Color get soft => Color(dark ? 0xff1e2c43 : 0xfff7f9fd);
  Color get help => Color(dark ? 0xff253d60 : 0xffeef4ff);
  Color successFill(int percent) => percent >= 85
      ? Color(dark ? 0xff68c98b : 0xff28934c)
      : Color(dark ? 0xffd6da72 : 0xffb5b644);
  Color get successTrack => Color(dark ? 0xff475773 : 0xffe4e9ef);
}

TextStyle screenText(
  double size,
  Color color, {
  double height = 1.4,
  bool heading = false,
}) => TextStyle(
  fontFamily: 'Segoe UI',
  fontSize: size,
  height: height,
  color: color,
  fontWeight: heading ? FontWeight.w500 : FontWeight.w400,
);

class TopicsScreen extends StatelessWidget {
  const TopicsScreen({super.key, this.successes = const [86, 65, null, null]});
  final List<int?> successes;
  @override
  Widget build(BuildContext context) {
    final c = ScreenColors(context);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, bounds) {
          final wide = bounds.maxWidth >= 1280;
          final compact = bounds.maxHeight <= 840;
          final low = bounds.maxHeight <= 680;
          final side = wide ? 56.0 : 40.0;
          final gap = wide ? 32.0 : 24.0;
          final width = (bounds.maxWidth - side * 2 - gap) / 2;
          const titles = [
            'Вынесение общего\nмножителя за скобки',
            'Умножение числа\nна скобку',
            'Умножение скобок',
            'Свойства степеней',
          ];
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0, .55, 1],
                colors: c.dark
                    ? const [
                        Color(0xff15243c),
                        Color(0xff19283e),
                        Color(0xff1b293d),
                      ]
                    : const [
                        Color(0xffe5edfa),
                        Color(0xffeff3fa),
                        Color(0xfff5f7fb),
                      ],
              ),
            ),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: bounds.maxHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: side,
                    vertical: low
                        ? 12
                        : compact
                        ? 16
                        : 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Математическая практика',
                        style: screenText(
                          low
                              ? 13
                              : wide
                              ? 17
                              : 14,
                          c.sub,
                        ),
                      ),
                      SizedBox(height: compact ? 4 : 8),
                      Text(
                        'Темы',
                        style: screenText(
                          low
                              ? 22
                              : compact
                              ? 25
                              : wide
                              ? 30
                              : 28,
                          c.ink,
                          heading: true,
                        ),
                      ),
                      SizedBox(
                        height: low
                            ? 10
                            : compact
                            ? 12
                            : 20,
                      ),
                      Divider(height: 1, color: c.line),
                      SizedBox(
                        height: low
                            ? 12
                            : compact
                            ? 16
                            : 24,
                      ),
                      Wrap(
                        spacing: gap,
                        runSpacing: wide ? 24 : 16,
                        children: [
                          for (var i = 0; i < 4; i++)
                            SizedBox(
                              width: width,
                              height: wide ? 166 : 144,
                              child: OutlinedButton(
                                key: ValueKey('topic-$i'),
                                onPressed: () {
                                  if (i == 0) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const StartScreen(),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Демонстрация заданий доступна для первой темы.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Color(
                                    c.dark ? 0xff25354d : 0xffffffff,
                                  ),
                                  side: BorderSide(
                                    color: Color(
                                      c.dark ? 0xff40536f : 0xffd6e0ef,
                                    ),
                                  ),
                                  minimumSize: Size(
                                    0,
                                    wide
                                        ? 160
                                        : low
                                        ? 100
                                        : compact
                                        ? 112
                                        : 128,
                                  ),
                                  padding: EdgeInsets.all(wide ? 30 : 24),
                                  visualDensity: VisualDensity.standard,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    TopicStateBadge(percent: successes[i]),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        titles[i],
                                        style: screenText(
                                          wide ? 24 : 20,
                                          c.ink,
                                          heading: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    TopicSuccess(
                                      percent: successes[i],
                                      wide: wide,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Divider(height: 1, color: c.line),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class TopicStateBadge extends StatelessWidget {
  const TopicStateBadge({super.key, required this.percent});
  final int? percent;
  @override
  Widget build(BuildContext context) {
    final c = ScreenColors(context);
    final fill = percent == null ? null : c.successFill(percent!);
    return Semantics(
      label: percent == null
          ? 'Не начато'
          : percent! >= 85
          ? 'Целевая успешность достигнута'
          : 'В процессе',
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: fill?.withValues(alpha: c.dark ? .18 : .10),
          border: Border.all(color: fill ?? c.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: percent == null
            ? null
            : Icon(
                percent! >= 85 ? Icons.check_rounded : Icons.schedule_rounded,
                color: fill,
                size: 26,
              ),
      ),
    );
  }
}

class TopicSuccess extends StatelessWidget {
  const TopicSuccess({super.key, required this.percent, required this.wide});
  final int? percent;
  final bool wide;
  @override
  Widget build(BuildContext context) {
    final c = ScreenColors(context);
    return SizedBox(
      width: wide ? 136 : 112,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Успешность',
            maxLines: 1,
            softWrap: false,
            style: screenText(wide ? 14 : 12, c.sub),
          ),
          SizedBox(height: wide ? 12 : 8),
          if (percent == null)
            Text('Не начато', style: screenText(wide ? 17 : 15, c.sub))
          else ...[
            Text(
              '$percent%',
              style: screenText(wide ? 30 : 25, c.ink, heading: true),
            ),
            SizedBox(height: wide ? 12 : 8),
            SizedBox(
              width: wide ? 112 : 92,
              height: wide ? 12 : 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: percent! / 100,
                  backgroundColor: c.successTrack,
                  color: c.successFill(percent!),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});
  @override
  Widget build(BuildContext context) => DemoPage(
    bodyBuilder: (context, wide, compact) {
      final c = ScreenColors(context);
      return SharedField(
        wide: wide,
        compact: compact,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 226,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Начнём практику',
                      style: screenText(
                        28,
                        c.ink,
                        heading: true,
                        height: 36 / 28,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Решай по одному заданию.',
                      style: screenText(20, c.ink, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Выбери ответ, затем нажми\n«Проверить себя».',
                      style: screenText(wide ? 20 : 18, c.sub, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: wide ? 44 : 32),
            Expanded(
              flex: 100,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: c.help,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: c.blue, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Если ошибёшься',
                            style: screenText(20, c.ink, heading: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Можно открыть объяснение и разобраться, как решить задание.',
                      style: screenText(wide ? 20 : 17, c.ink, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        footer: PrimaryAction(
          label: 'Начать практику',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PracticeScreen(
                showHistoryControls: true,
                onAdvance: (record) => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ConstructorScreen(previousRecord: record),
                  ),
                ),
                onTopics: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
            ),
          ),
          wide: wide,
          compact: compact,
        ),
      );
    },
  );
}

typedef DemoBodyBuilder = Widget Function(
  BuildContext,
  bool wide,
  bool compact,
);

class DemoPage extends StatelessWidget {
  const DemoPage({
    super.key,
    required this.bodyBuilder,
    this.label = 'Практика',
    this.topic = fullTopic,
    this.showSuccess = false,
    this.visibleScrollbar = false,
    this.footerBuilder,
  });
  final DemoBodyBuilder bodyBuilder;
  final String label, topic;
  final bool showSuccess;
  final bool visibleScrollbar;
  final DemoBodyBuilder? footerBuilder;
  @override
  Widget build(BuildContext context) {
    final c = ScreenColors(context);
    return Scaffold(
      backgroundColor: c.paper,
      bottomNavigationBar: footerBuilder == null
          ? null
          : LayoutBuilder(
              builder: (context, bounds) {
                final size = MediaQuery.sizeOf(context);
                final wide = size.width >= 1280;
                return SafeArea(
                  child: Container(
                    key: const ValueKey('demo-footer'),
                    decoration: BoxDecoration(
                      color: c.paper,
                      border: Border(top: BorderSide(color: c.line)),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: wide
                          ? 56
                          : size.width < 720
                          ? 16
                          : 40,
                      vertical: 12,
                    ),
                    child: footerBuilder!(context, wide, size.height <= 840),
                  ),
                );
              },
            ),
      body: LayoutBuilder(
        builder: (context, bounds) {
          final wide = bounds.maxWidth >= 1280;
          final compact = bounds.maxHeight <= 840;
          final low = bounds.maxHeight <= 680;
          Widget scrollable(Widget child) => visibleScrollbar
              ? _VisiblePageScroll(child: child)
              : SingleChildScrollView(child: child);
          return scrollable(
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: bounds.maxHeight),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: wide
                      ? 56
                      : bounds.maxWidth < 720
                      ? 16
                      : 40,
                  vertical: low
                      ? 12
                      : compact
                      ? 16
                      : 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => returnToTopics(context),
                        style: TextButton.styleFrom(
                          foregroundColor: c.sub,
                          padding: EdgeInsets.zero,
                          minimumSize: Size(
                            0,
                            low
                                ? 24
                                : compact
                                ? 26
                                : 30,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: Text('К темам', style: screenText(15, c.sub)),
                      ),
                    ),
                    SizedBox(
                      height: low
                          ? 6
                          : compact
                          ? 8
                          : 12,
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 226,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: screenText(
                                  low
                                      ? 13
                                      : wide
                                      ? 17
                                      : 14,
                                  c.sub,
                                ),
                              ),
                              SizedBox(height: compact ? 4 : 8),
                              Text(
                                topic,
                                style: screenText(
                                  low
                                      ? 22
                                      : compact
                                      ? 25
                                      : wide
                                      ? 30
                                      : 25,
                                  c.ink,
                                  heading: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (showSuccess) ...[
                          SizedBox(width: wide ? 44 : 32),
                          Expanded(
                            flex: 100,
                            child: InkWell(
                              onTap: () => showSuccessInfo(context),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SuccessLabel(
                                    style: screenText(wide ? 17 : 14, c.sub),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: bounds.maxWidth < 720 ? 140 : 216,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: Color(
                                                c.dark
                                                    ? 0xff475773
                                                    : 0xffe4e9ef,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          '0%',
                                          style: screenText(
                                            compact ? 25 : 30,
                                            c.ink,
                                            heading: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(
                      height: low
                          ? 10
                          : compact
                          ? 12
                          : 20,
                    ),
                    Divider(height: 1, color: c.line),
                    SizedBox(
                      height: low
                          ? 12
                          : compact
                          ? 16
                          : 24,
                    ),
                    bodyBuilder(context, wide, compact),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VisiblePageScroll extends StatefulWidget {
  const _VisiblePageScroll({required this.child});
  final Widget child;
  @override
  State<_VisiblePageScroll> createState() => _VisiblePageScrollState();
}

class _VisiblePageScrollState extends State<_VisiblePageScroll> {
  final controller = ScrollController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
    child: Scrollbar(
      controller: controller,
      thumbVisibility: true,
      child: SingleChildScrollView(controller: controller, child: widget.child),
    ),
  );
}

class SharedField extends StatelessWidget {
  const SharedField({
    super.key,
    required this.body,
    this.footer,
    required this.wide,
    required this.compact,
    this.joinedTop = false,
  });
  final Widget body;
  final Widget? footer;
  final bool wide, compact;
  final bool joinedTop;
  @override
  Widget build(BuildContext context) {
    final c = ScreenColors(context);
    final horizontal = compact
        ? 28.0
        : wide
        ? 40.0
        : 32.0;
    return Container(
      decoration: BoxDecoration(
        color: c.soft,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(joinedTop ? 0 : 20),
          bottom: const Radius.circular(20),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontal,
              vertical: compact ? 24 : 36,
            ),
            child: body,
          ),
          if (footer != null)
            Container(
              decoration: BoxDecoration(
                color: c.paper,
                border: Border(top: BorderSide(color: c.line)),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: horizontal,
                vertical: compact
                    ? 14
                    : wide
                    ? 28
                    : 22,
              ),
              child: Align(alignment: Alignment.centerRight, child: footer),
            ),
        ],
      ),
    );
  }
}

class FooterActions extends StatelessWidget {
  const FooterActions({
    super.key,
    required this.children,
    this.allowWrap = false,
  });
  final List<Widget> children;
  final bool allowWrap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => allowWrap || bounds.maxWidth < 720
        ? Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 8,
            children: children
                .where((child) => child is! SizedBox || child.child != null)
                .toList(),
          )
        : Row(mainAxisAlignment: MainAxisAlignment.end, children: children),
  );
}

class PrimaryAction extends StatelessWidget {
  const PrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
    required this.wide,
    required this.compact,
    this.width = 280,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool wide, compact;
  final double width;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: ScreenColors(context).blue,
        foregroundColor: Colors.white,
        visualDensity: VisualDensity.standard,
        minimumSize: Size(
          0,
          compact
              ? 50
              : wide
              ? 64
              : 54,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(wide ? 18 : 16),
        ),
        textStyle: screenText(wide ? 20 : 17, Colors.white, heading: true),
      ),
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}

class SecondaryAction extends StatelessWidget {
  const SecondaryAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool compact;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final c = ScreenColors(context);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        backgroundColor: c.paper,
        side: BorderSide(color: c.line),
        visualDensity: VisualDensity.standard,
        minimumSize: Size(0, compact ? 50 : 54),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: screenText(17, c.ink, heading: true),
      ),
      child: icon == null
          ? Text(label)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Flexible(child: Text(label, textAlign: TextAlign.center)),
              ],
            ),
    );
  }
}
