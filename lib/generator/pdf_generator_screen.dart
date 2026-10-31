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
  TaskOrder order = TaskOrder.grouped;
  bool busy = false;
  String? error;
  String? success;

  Future<List<ExerciseTemplate>> _load() async {
    final templates = loadTemplates(
      widget.catalogText ??
          await rootBundle.loadString('bank/templates/common_factor.json'),
    );
    selected.addAll(templates.where((t) => t.active).map((t) => t.id));
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
                            if (visible.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'Выберите хотя бы одну тему и один уровень.',
                                ),
                              ),
                            for (final t in visible)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _templateRow(t, colors),
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
                            const Text(
                              'A4, альбомный лист в клетку. Только задания — без ответов и подсказок.',
                            ),
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

  Widget _templateRow(ExerciseTemplate t, ColorScheme colors) {
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
          SizedBox(
            width: 70,
            child: TextFormField(
              key: ValueKey('quantity-${t.id}'),
              initialValue: '${quantities[t.id] ?? 10}',
              enabled: checked && !busy,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: const InputDecoration(
                labelText: 'Штук',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
              ),
              onChanged: (v) => setState(() {
                quantities[t.id] = int.tryParse(v) ?? 0;
                success = null;
              }),
            ),
          ),
        ],
      ),
    );
  }
}
