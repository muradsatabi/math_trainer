import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'task_generator.dart';
import 'worksheet_pdf.dart';
import 'pdf_download.dart';

typedef PdfExporter = Future<void> Function(Uint8List bytes, String filename);

class PdfGeneratorScreen extends StatefulWidget {
  const PdfGeneratorScreen({
    super.key,
    this.exporter,
    this.catalogText,
    this.pdfBuilder,
  });
  final PdfExporter? exporter;
  final String? catalogText;
  final Future<Uint8List> Function(List<GeneratedExercise>)? pdfBuilder;
  @override
  State<PdfGeneratorScreen> createState() => _PdfGeneratorScreenState();
}

class _PdfGeneratorScreenState extends State<PdfGeneratorScreen> {
  late final Future<List<ExerciseTemplate>> loading = _load();
  final levels = <int>{1, 2};
  final families = <String>{'numeric', 'literal'};
  final selected = <String>{};
  final quantities = <String, int>{};
  final templateOrder = <String>[];
  final quantityControllers = <String, TextEditingController>{};
  final commonQuantity = TextEditingController(text: '10');
  TaskOrder order = TaskOrder.grouped;

  @override
  void dispose() {
    commonQuantity.dispose();
    for (final controller in quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _move(List<ExerciseTemplate> visible, int index, int delta) {
    setState(() {
      final a = templateOrder.indexOf(visible[index].id);
      final b = templateOrder.indexOf(visible[index + delta].id);
      final id = templateOrder[a];
      templateOrder[a] = templateOrder[b];
      templateOrder[b] = id;
      success = null;
    });
  }

  Widget _quantityInput(
    String id,
    TextEditingController controller,
    bool enabled,
    ValueChanged<int> onChanged,
  ) {
    final value = int.tryParse(controller.text) ?? 0;
    void step(int delta) {
      final next = (value + delta).clamp(1, 100);
      controller.text = '$next';
      onChanged(next);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: ValueKey('minus-$id'),
          tooltip: 'Уменьшить количество',
          onPressed: enabled && value > 1 ? () => step(-1) : null,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove, size: 20),
        ),
        SizedBox(
          width: 64,
          child: TextFormField(
            key: ValueKey('quantity-$id'),
            controller: controller,
            enabled: enabled,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: const InputDecoration(
              labelText: 'Штук',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            ),
            onChanged: (text) => onChanged(int.tryParse(text) ?? 0),
          ),
        ),
        IconButton(
          key: ValueKey('plus-$id'),
          tooltip: 'Увеличить количество',
          onPressed: enabled && value < 100 ? () => step(1) : null,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add, size: 20),
        ),
      ],
    );
  }

  bool busy = false;
  bool landscape = true;
  bool includeAnswers = false;
  String? error;
  String? success;

  Future<List<ExerciseTemplate>> _load() async {
    final templates = loadTemplates(
      widget.catalogText ??
          await rootBundle.loadString('bank/templates/common_factor.json'),
    );
    selected.addAll(templates.where((t) => t.active).map((t) => t.id));
    templateOrder.addAll(generationOptions(templates).map((t) => t.id));
    return templates;
  }

  Future<void> _generate(
    List<ExerciseTemplate> options,
    Map<String, int> counts,
  ) async {
    setState(() {
      busy = true;
      error = null;
      success = null;
    });
    try {
      // Yield to paint the progress state before doing bounded local work.
      await Future<void>.delayed(Duration.zero);
      final tasks = TemplateTaskGenerator().generate(
        templates: options,
        quantities: counts,
        order: order,
      );
      final bytes = await (widget.pdfBuilder ?? _buildPdf)(tasks);
      final filename =
          'math-worksheet-${DateTime.now().millisecondsSinceEpoch}.pdf';
      await (widget.exporter ?? downloadPdf)(bytes, filename);
      if (mounted) {
        setState(() => success = 'PDF готов: ${tasks.length} заданий.');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Не удалось создать PDF. Попробуйте ещё раз или уменьшите количество заданий.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<Uint8List> _buildPdf(List<GeneratedExercise> tasks) async {
    final fonts = await Future.wait([
      rootBundle.load('assets/fonts/Carlito-Regular.ttf'),
      rootBundle.load('assets/fonts/Caladea-Regular.ttf'),
    ]);
    return buildWorksheetPdf(
      exercises: tasks,
      textFont: fonts[0],
      mathFont: fonts[1],
      landscape: landscape,
      includeAnswers: includeAnswers,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Задания в PDF'),
        leading: IconButton(
          tooltip: 'К темам',
          icon: const Icon(Icons.arrow_back),
          onPressed: busy ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<List<ExerciseTemplate>>(
        future: loading,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: snapshot.hasError
                  ? const Text(
                      'Не удалось загрузить шаблоны. Вернитесь к темам и попробуйте ещё раз.',
                    )
                  : const CircularProgressIndicator(),
            );
          }
          final templates = snapshot.data!;
          final options = generationOptions(templates);
          final visible = options
              .where(
                (t) => levels.contains(t.level) && families.contains(t.family),
              )
              .toList();
          visible.sort(
            (a, b) => templateOrder
                .indexOf(a.id)
                .compareTo(templateOrder.indexOf(b.id)),
          );
          final commonValue = int.tryParse(commonQuantity.text) ?? 0;
          final counts = {
            for (final t in visible)
              if (selected.contains(t.id)) t.id: quantities[t.id] ?? 10,
          };
          final total = counts.values.fold(0, (a, b) => a + b);
          final valid =
              counts.isNotEmpty &&
              total <= TemplateTaskGenerator.maxTotal &&
              counts.values.every(
                (v) => v >= 1 && v <= TemplateTaskGenerator.maxPerTemplate,
              );
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Общий множитель за скобками',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Выберите шаблоны и количество заданий для каждого. '
                              'Числа и буквы будут меняться; повторов в наборе не будет.',
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Какие шаблоны использовать',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                for (final entry in {
                                  'numeric': 'Числовой множитель',
                                  'literal': 'Буквенный множитель',
                                }.entries)
                                  FilterChip(
                                    label: Text(entry.value),
                                    selected: families.contains(entry.key),
                                    onSelected: busy
                                        ? null
                                        : (yes) => setState(() {
                                            if (yes) {
                                              families.add(entry.key);
                                            } else {
                                              families.remove(entry.key);
                                            }
                                          }),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Уровни сочетаний',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                for (var level = 1; level <= 6; level++)
                                  FilterChip(
                                    key: ValueKey('generator-level-$level'),
                                    label: Text('$level'),
                                    selected: levels.contains(level),
                                    onSelected: busy
                                        ? null
                                        : (yes) => setState(() {
                                            if (yes) {
                                              levels.add(level);
                                              selected.addAll(
                                                options
                                                    .where(
                                                      (t) => t.level == level,
                                                    )
                                                    .map((t) => t.id),
                                              );
                                            } else {
                                              levels.remove(level);
                                            }
                                          }),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '1 — основа; 2 — одно усложнение; 3–6 — сочетания от двух до пяти. '
                              'Это состав задания, а не оценка трудности.',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                            if (levels.any((v) => v > 2))
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Сочетания автоматически составлены из рабочих направлений '
                                  'и доступны для пробы; отдельного методического согласования они ещё не проходили.',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => setState(
                                          () => selected.addAll(
                                            visible.map((t) => t.id),
                                          ),
                                        ),
                                  child: const Text('Выбрать все'),
                                ),
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => setState(
                                          () => selected.removeAll(
                                            visible.map((t) => t.id),
                                          ),
                                        ),
                                  child: const Text('Снять выбор'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Одинаковое количество для выбранных шаблонов',
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _quantityInput(
                                  'all',
                                  commonQuantity,
                                  !busy,
                                  (_) => setState(() {}),
                                ),
                                OutlinedButton(
                                  key: const ValueKey('apply-quantity-all'),
                                  onPressed:
                                      busy ||
                                          counts.isEmpty ||
                                          commonValue < 1 ||
                                          commonValue > 100
                                      ? null
                                      : () => setState(() {
                                          for (final id in counts.keys) {
                                            quantities[id] = commonValue;
                                            quantityControllers[id]?.text =
                                                '$commonValue';
                                          }
                                          success = null;
                                        }),
                                  child: const Text('Применить к выбранным'),
                                ),
                              ],
                            ),
                            if (commonValue < 1 || commonValue > 100)
                              Text(
                                'Введите число от 1 до 100.',
                                style: TextStyle(color: colors.error),
                              ),
                            const SizedBox(height: 12),
                            const Text(
                              'Перетаскивайте строку шаблона или используйте стрелки. Этот порядок используется в PDF в режиме «Группами по шаблонам».',
                            ),
                            const SizedBox(height: 12),
                            if (visible.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'Выберите хотя бы одну тему и один уровень.',
                                ),
                              ),
                            for (var i = 0; i < visible.length; i++)
                              Padding(
                                key: ValueKey('row-${visible[i].id}'),
                                padding: const EdgeInsets.only(bottom: 8),
                                child: DragTarget<String>(
                                  onWillAcceptWithDetails: (d) =>
                                      !busy && d.data != visible[i].id,
                                  onAcceptWithDetails: (d) => setState(() {
                                    final from = templateOrder.indexOf(d.data);
                                    final to = templateOrder.indexOf(
                                      visible[i].id,
                                    );
                                    if (from < 0 || to < 0) return;
                                    templateOrder.insert(
                                      to,
                                      templateOrder.removeAt(from),
                                    );
                                    success = null;
                                  }),
                                  builder: (context, candidates, rejected) =>
                                      Draggable<String>(
                                        key: ValueKey('drag-${visible[i].id}'),
                                        data: visible[i].id,
                                        maxSimultaneousDrags: busy ? 0 : 1,
                                        feedback: Material(
                                          elevation: 8,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: SizedBox(
                                            width: 280,
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Text(visible[i].title),
                                            ),
                                          ),
                                        ),
                                        childWhenDragging: Opacity(
                                          opacity: .3,
                                          child: Text(visible[i].title),
                                        ),
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            border: candidates.isEmpty
                                                ? null
                                                : Border.all(
                                                    color: colors.primary,
                                                    width: 2,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: _templateRow(
                                            visible[i],
                                            colors,
                                            moveUp: i == 0 || busy
                                                ? null
                                                : () => _move(visible, i, -1),
                                            moveDown:
                                                i == visible.length - 1 || busy
                                                ? null
                                                : () => _move(visible, i, 1),
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                            ExpansionTile(
                              title: const Text('Отложенные шаблоны'),
                              subtitle: const Text('Не участвуют в генерации'),
                              children: [
                                for (final t in templates.where(
                                  (t) => !t.active,
                                ))
                                  ListTile(
                                    enabled: false,
                                    leading: const Icon(
                                      Icons.pause_circle_outline,
                                    ),
                                    title: Text(t.title),
                                    subtitle: Text(t.example),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            DropdownButtonFormField<TaskOrder>(
                              isExpanded: true,
                              initialValue: order,
                              decoration: const InputDecoration(
                                labelText: 'Порядок заданий',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: TaskOrder.grouped,
                                  child: Text('Группами по шаблонам'),
                                ),
                                DropdownMenuItem(
                                  value: TaskOrder.shuffled,
                                  child: Text('Вперемешку'),
                                ),
                                DropdownMenuItem(
                                  value: TaskOrder.increasing,
                                  child: Text('По возрастанию уровня'),
                                ),
                              ],
                              onChanged: busy
                                  ? null
                                  : (v) => setState(() => order = v!),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<bool>(
                              key: const ValueKey('pdf-orientation'),
                              initialValue: landscape,
                              decoration: const InputDecoration(
                                labelText: 'Ориентация PDF',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: true,
                                  child: Text('Альбомная'),
                                ),
                                DropdownMenuItem(
                                  value: false,
                                  child: Text('Книжная'),
                                ),
                              ],
                              onChanged: busy
                                  ? null
                                  : (value) => setState(() {
                                      landscape = value!;
                                      success = null;
                                    }),
                            ),
                            CheckboxListTile(
                              key: const ValueKey('include-answers'),
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Добавить ответы'),
                              subtitle: const Text(
                                'Отдельными страницами в конце PDF',
                              ),
                              value: includeAnswers,
                              onChanged: busy
                                  ? null
                                  : (value) => setState(() {
                                      includeAnswers = value!;
                                      success = null;
                                    }),
                            ),
                            const Text('A4, лист в клетку.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border(
                      top: BorderSide(color: colors.outlineVariant),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Выбрано шаблонов: ${counts.length} · Заданий: $total',
                            key: const ValueKey('generator-summary'),
                          ),
                          if (!valid)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                counts.isEmpty
                                    ? 'Выберите хотя бы один шаблон.'
                                    : 'От 1 до 100 заданий на шаблон; не больше 1000 в одном PDF.',
                                style: TextStyle(color: colors.error),
                              ),
                            ),
                          if (error != null)
                            Text(error!, style: TextStyle(color: colors.error)),
                          if (success != null)
                            Text(
                              success!,
                              key: const ValueKey('generator-success'),
                            ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            key: const ValueKey('generate-pdf'),
                            onPressed: busy || !valid
                                ? null
                                : () => _generate(options, counts),
                            icon: busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.picture_as_pdf_outlined),
                            label: Text(
                              busy ? 'Создаём PDF…' : 'Сгенерировать PDF',
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 48),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _templateRow(
    ExerciseTemplate t,
    ColorScheme colors, {
    VoidCallback? moveUp,
    VoidCallback? moveDown,
  }) {
    final checked = selected.contains(t.id);
    return Container(
      decoration: BoxDecoration(
        color: checked
            ? colors.primaryContainer.withValues(alpha: .2)
            : colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
      child: Row(
        children: [
          const Icon(Icons.drag_indicator, size: 18),
          Checkbox(
            key: ValueKey('select-${t.id}'),
            value: checked,
            onChanged: busy
                ? null
                : (v) => setState(() {
                    if (v!) {
                      selected.add(t.id);
                    } else {
                      selected.remove(t.id);
                    }
                  }),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: ValueKey('move-up-${t.id}'),
                tooltip: 'Поднять шаблон',
                onPressed: moveUp,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.keyboard_arrow_up, size: 22),
              ),
              IconButton(
                key: ValueKey('move-down-${t.id}'),
                tooltip: 'Опустить шаблон',
                onPressed: moveDown,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.keyboard_arrow_down, size: 22),
              ),
            ],
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t.family == 'numeric' ? 'Числовой' : 'Буквенный'} · Уровень ${t.level}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  t.title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (t.example.isNotEmpty)
                  Text(
                    t.example,
                    style: const TextStyle(fontFamily: 'Caladea', fontSize: 18),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _quantityInput(
            t.id,
            quantityControllers.putIfAbsent(
              t.id,
              () => TextEditingController(text: '${quantities[t.id] ?? 10}'),
            ),
            checked && !busy,
            (value) => setState(() {
              quantities[t.id] = value;
              success = null;
            }),
          ),
        ],
      ),
    );
  }
}
