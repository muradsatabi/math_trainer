part of 'demo_screens.dart';

/// Four desktop slots use the available viewport, not physical monitor pixels.
class _ViewportTopics extends StatelessWidget {
  const _ViewportTopics({
    required this.titles,
    required this.successes,
    required this.completedStates,
    this.enabledStates,
    this.subtitles,
    this.onResetHistory,
    required this.onOpen,
    required this.onPdf,
  });
  final List<String> titles;
  final List<int?> successes;
  final List<bool>? completedStates;
  final List<bool>? enabledStates;
  final List<String>? subtitles;
  final VoidCallback? onResetHistory;
  final ValueChanged<int> onOpen, onPdf;

  @override
  Widget build(BuildContext context) {
    final c = ScreenColors(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final side = (viewport.maxWidth * .04).clamp(16.0, 56.0);
            final vertical = (viewport.maxHeight * .025).clamp(12.0, 28.0);
            final gap = (viewport.maxHeight * .025).clamp(12.0, 28.0);
            final compact = viewport.maxHeight <= 680;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: c.dark
                      ? const [Color(0xff15243c), Color(0xff1b293d)]
                      : const [Color(0xffe5edfa), Color(0xfff5f7fb)],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: vertical),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: side),
                      child: Column(
                        key: const ValueKey('topics-fixed-header'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Математическая практика',
                            style: screenText(compact ? 13 : 16, c.sub),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Темы',
                                  style: screenText(
                                    compact ? 24 : 30,
                                    c.ink,
                                    heading: true,
                                  ),
                                ),
                              ),
                              if (onResetHistory != null) ...[
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  key: const ValueKey('reset-history-action'),
                                  onPressed: onResetHistory,
                                  icon: const Icon(Icons.restart_alt, size: 20),
                                  label: Text(
                                    'Сбросить историю',
                                    style: screenText(14, c.sub),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(height: 1, color: c.line),
                        ],
                      ),
                    ),
                    SizedBox(height: gap),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, bounds) {
                          final columns = viewport.maxWidth >= 800 ? 2 : 1;
                          final rows = columns == 2 ? 2 : 4;
                          final cardWidth =
                              (bounds.maxWidth -
                                  side * 2 -
                                  gap * (columns - 1)) /
                              columns;
                          final padding = (cardWidth * .04).clamp(16.0, 32.0);
                          final fontSize = (cardWidth * .035).clamp(20.0, 30.0);
                          final scaler = MediaQuery.textScalerOf(context);
                          var titleHeight = 0.0;
                          for (var index = 0; index < titles.length; index++) {
                            final title = titles[index];
                            final painter = TextPainter(
                              text: TextSpan(
                                text: title,
                                style: Theme.of(context).textTheme.bodyMedium!
                                    .merge(
                                      screenText(
                                        fontSize,
                                        c.ink,
                                        heading: true,
                                      ),
                                    ),
                              ),
                              textDirection: Directionality.of(context),
                              textScaler: scaler,
                            )..layout(maxWidth: cardWidth - padding * 2);
                            var height = painter.height;
                            if (subtitles != null) {
                              final caption = TextPainter(
                                text: TextSpan(
                                  text: subtitles![index],
                                  style: Theme.of(context).textTheme.bodyMedium!
                                      .merge(screenText(12, c.sub)),
                                ),
                                textDirection: Directionality.of(context),
                                textScaler: scaler,
                              )..layout(maxWidth: cardWidth - padding * 2);
                              height += caption.height + 8;
                              caption.dispose();
                            }
                            if (height > titleHeight) {
                              titleHeight = height;
                            }
                            painter.dispose();
                          }
                          final minimum =
                              titleHeight +
                              padding * 2 +
                              16 +
                              (scaler.scale(12) * 1.4).ceilToDouble() +
                              6 +
                              44;
                          final desired =
                              (bounds.maxHeight - gap * (rows - 1)) / rows;
                          final height = desired > minimum ? desired : minimum;
                          return _TopicGridScroll(
                            margin: (side - 8) / 2,
                            child: GridView.builder(
                              key: const ValueKey('topics-viewport-grid'),
                              primary: true,
                              padding: EdgeInsets.symmetric(horizontal: side),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisSpacing: gap,
                                    crossAxisSpacing: gap,
                                    mainAxisExtent: height,
                                  ),
                              itemCount: titles.length,
                              itemBuilder: (context, index) =>
                                  _TopicCardWithPdf(
                                    index: index,
                                    title: titles[index],
                                    percent: successes[index],
                                    completed: completedStates?[index],
                                    enabled: enabledStates?[index] ?? true,
                                    subtitle: subtitles?[index],
                                    wide: viewport.maxWidth >= 1280,
                                    titleSize: fontSize,
                                    contentPadding: padding,
                                    titleHeight: titleHeight,
                                    onOpen: () => onOpen(index),
                                    onPdf: () => onPdf(index),
                                  ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: gap),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: side),
                      child: Divider(height: 1, color: c.line),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Own the controller and put the thumb in the outer page gutter. The grid's
/// padding remains inside this viewport, so its card geometry is unchanged.
class _TopicGridScroll extends StatefulWidget {
  const _TopicGridScroll({required this.child, required this.margin});
  final Widget child;
  final double margin;
  @override
  State<_TopicGridScroll> createState() => _TopicGridScrollState();
}

class _TopicGridScrollState extends State<_TopicGridScroll> {
  final controller = ScrollController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PrimaryScrollController(
    controller: controller,
    child: RawScrollbar(
      key: const ValueKey('topics-gutter-scrollbar'),
      controller: controller,
      thumbVisibility: true,
      interactive: true,
      thickness: 8,
      radius: const Radius.circular(8),
      crossAxisMargin: widget.margin,
      thumbColor: Theme.of(context).colorScheme.onSurfaceVariant
          .withValues(alpha: .45),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: widget.child,
      ),
    ),
  );
}
