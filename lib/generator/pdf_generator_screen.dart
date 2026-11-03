import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'task_generator.dart';
import 'worksheet_pdf.dart';
import 'pdf_download.dart';

typedef PdfExporter = Future<void> Function(Uint8List bytes, String filename);

String _featureGroup(String feature) =>
    feature == 'factor_power' ? 'powers' : feature;

String _templateTitle(ExerciseTemplate template) =>
    template.family == 'literal' && template.features.contains('unit')
    ? template.title.replaceAll(
        'Остаток — единица',
        'Свободное число в скобках',
      )
    : template.title;

const _featureLabels = {
  'powers': 'Степени',
  'subtraction': 'Вычитание',
  'position': 'Другой порядок множителей',
  'three_terms': 'Три слагаемых',
  'unit': 'Число в скобках без букв',
  'different': 'Разные коэффициенты',
  'two_letters': 'Две оставшиеся буквы',
  'bracket': 'Скобки в слагаемом',
};

class PdfGeneratorScreen extends StatefulWidget {
  const PdfGeneratorScreen({
    super.key,
    this.exporter,
    this.catalogText,
    this.pdfBuilder,
    this.family,
  });
  final PdfExporter? exporter;
  final String? catalogText;
  final String? family;
  final Future<Uint8List> Function(List<GeneratedExercise>)? pdfBuilder;
  @override
  State<PdfGeneratorScreen> createState() => _PdfGeneratorScreenState();
}

class _PdfGeneratorScreenState extends State<PdfGeneratorScreen> {
  late final Future<List<ExerciseTemplate>> loading = _load();
  final levels = <int>{1};
  final excludedFeatures = <String>{};
  late final families = widget.family == null
      ? <String>{'numeric', 'literal'}
      : <String>{widget.family!};
  final selected = <String>{};
  final quantities = <String, int>{};
  final templateOrder = <String>[];
  final quantityControllers = <String, TextEditingController>{};
  final commonQuantity = TextEditingController(text: '5');
  final variantQuantity = TextEditingController(text: '1');
  TaskOrder order = TaskOrder.grouped;

  @override
  void dispose() {
    commonQuantity.dispose();
    variantQuantity.dispose();
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
  int columns = 2;
  bool includeAnswers = false;
  bool testMode = false;
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
      final variants = TemplateTaskGenerator(varyLiteralConstants: true)
          .generateVariants(
            templates: options,
            quantities: counts,
            count: int.parse(variantQuantity.text),
            order: order,
          );
      final bytes = widget.pdfBuilder == null
          ? await _buildPdf(variants)
          : await widget.pdfBuilder!(variants.expand((v) => v).toList());
      final filename =
          'math-worksheet-${DateTime.now().millisecondsSinceEpoch}.pdf';
      await (widget.exporter ?? downloadPdf)(bytes, filename);
      if (mounted) {
        setState(
          () => success = variants.length == 1
              ? 'PDF готов: ${variants.first.length} заданий.'
              : 'PDF готов: ${variants.length} вариантов по ${variants.first.length} заданий.',
        );
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

  Future<Uint8List> _buildPdf(List<List<GeneratedExercise>> variants) async {
    final fonts = await Future.wait([
      rootBundle.load('assets/fonts/Carlito-Regular.ttf'),
      rootBundle.load('assets/fonts/Caladea-Regular.ttf'),
    ]);
    return buildWorksheetVariantsPdf(
      variants: variants,
      textFont: fonts[0],
      mathFont: fonts[1],
      landscape: landscape,
      columns: columns,
      includeAnswers: includeAnswers,
      testMode: testMode,
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
          final flat = templates.every((t) => t.flat);
          final options = generationOptions(templates);
          final featureGroups =
              options
                  .where((t) => families.contains(t.family))
                  .expand((t) => t.features)
                  .map(_featureGroup)
                  .toSet()
                  .toList()
                ..sort();
          final visible = options
              .where(
                (t) =>
                    levels.contains(t.level) &&
                    families.contains(t.family) &&
                    !t.features.any(
                      (f) => excludedFeatures.contains(_featureGroup(f)),
                    ),
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
              if (selected.contains(t.id)) t.id: quantities[t.id] ?? 5,
          };
          final total = counts.values.fold(0, (a, b) => a + b);
          final variantCount = int.tryParse(variantQuantity.text) ?? 0;
          final valid =
              counts.isNotEmpty &&
              variantCount >= 1 &&
              variantCount <= TemplateTaskGenerator.maxVariants &&
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
                              widget.family == 'numeric_bracket'
                                  ? 'Умножение на скобку — числовой множитель'
                                  : widget.family == 'literal_bracket'
                                  ? 'Умножение на скобку — буквенный множитель'
                                  : widget.family == 'numeric'
                                  ? 'Численный общий множитель'
                                  : widget.family == 'literal'
                                  ? 'Буквенный общий множитель'
                                  : 'Общий множитель за скобками',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Выберите шаблоны и количество заданий для каждого. '
                              'Числа и буквы будут меняться; повторов в наборе не будет.',
                            ),
                            const SizedBox(height: 20),
                            if (widget.family == null) ...[
                              Text(
                                'Какие шаблоны использовать',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  for (final entry
                                      in {
                                        'numeric': 'Числовой множитель',
                                        'literal': 'Буквенный множитель',
                                      }.entries.where(
                                        (entry) =>
                                            widget.family == null ||
                                            entry.key == widget.family,
                                      ))
                                    FilterChip(
                                      label: Text(entry.value),
                                      selected: families.contains(entry.key),
                                      onSelected: busy || widget.family != null
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
                            ],
                            if (!flat)
                              _levelsAndFeatures(options, featureGroups),
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
                                              child: Text(
                                                _templateTitle(visible[i]),
                                              ),
                                            ),
                                          ),
                                        ),
                                        childWhenDragging: Opacity(
                                          opacity: .3,
                                          child: Text(
                                            _templateTitle(visible[i]),
                                          ),
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
                              title: Text(
                                flat
                                    ? 'Не подключены к генерации'
                                    : 'Отложенные шаблоны',
                              ),
                              subtitle: const Text('Не участвуют в генерации'),
                              children: [
                                for (final t in templates.where(
                                  (t) =>
                                      !t.active &&
                                      (widget.family == null ||
                                          t.family == widget.family),
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
                              items: [
                                const DropdownMenuItem(
                                  value: TaskOrder.grouped,
                                  child: Text('Группами по шаблонам'),
                                ),
                                const DropdownMenuItem(
                                  value: TaskOrder.shuffled,
                                  child: Text('Вперемешку'),
                                ),
                                if (!flat)
                                  const DropdownMenuItem(
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
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              key: const ValueKey('pdf-columns'),
                              initialValue: columns,
                              decoration: const InputDecoration(
                                labelText: 'Количество столбцов',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 1,
                                  child: Text('Один столбец'),
                                ),
                                DropdownMenuItem(
                                  value: 2,
                                  child: Text('Два столбца'),
                                ),
                                DropdownMenuItem(
                                  value: 3,
                                  child: Text('Три столбца'),
                                ),
                              ],
                              onChanged: busy
                                  ? null
                                  : (value) => setState(() {
                                      columns = value!;
                                      success = null;
                                    }),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<bool>(
                              key: const ValueKey('pdf-test-mode'),
                              isExpanded: true,
                              initialValue: testMode,
                              decoration: const InputDecoration(
                                labelText: 'Формат работы',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: false,
                                  child: Text('Обычные задания'),
                                ),
                                DropdownMenuItem(
                                  value: true,
                                  child: Text('Тест — четыре ответа'),
                                ),
                              ],
                              onChanged: busy
                                  ? null
                                  : (value) => setState(() {
                                      testMode = value!;
                                      success = null;
                                    }),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Количество вариантов работы',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            _quantityInput(
                              'variants',
                              variantQuantity,
                              !busy,
                              (_) => setState(() {
                                success = null;
                              }),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Каждый вариант — с новой страницы, с теми же шаблонами и количеством заданий. От 1 до 100 вариантов.',
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
                          if (variantCount > 1)
                            Text(
                              'Вариантов: $variantCount · В каждом: $total · Всего заданий: ${total * variantCount}',
                            ),
                          if (!valid)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                counts.isEmpty
                                    ? 'Выберите хотя бы один шаблон.'
                                    : variantCount < 1 ||
                                          variantCount >
                                              TemplateTaskGenerator.maxVariants
                                    ? 'Введите от 1 до 100 вариантов.'
                                    : 'От 1 до 100 заданий на шаблон; не больше 1000 в каждом варианте.',
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

  Widget _levelsAndFeatures(
    List<ExerciseTemplate> options,
    List<String> groups,
  ) {
    final style = Theme.of(context).textTheme.titleMedium;
    final levelsPanel = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Уровни сочетаний', style: style),
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
                                .where((t) => t.level == level)
                                .map((t) => t.id),
                          );
                        } else {
                          levels.remove(level);
                        }
                        success = null;
                      }),
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          '1 — основа; 2 — одно усложнение; 3–6 — сочетания от двух до пяти. Это состав задания, а не оценка трудности.',
        ),
        if (levels.any((v) => v > 2)) ...[
          const SizedBox(height: 8),
          const Text(
            'Сочетания автоматически составлены из рабочих направлений и доступны для пробы; отдельного методического согласования они ещё не проходили.',
          ),
        ],
      ],
    );
    if (groups.isEmpty) return levelsPanel;
    final featuresPanel = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Разрешённые усложнения', style: style),
        const SizedBox(height: 6),
        const Text(
          'Снимите галочку, чтобы исключить признак во всех шаблонах и сочетаниях.',
        ),
        for (final group in groups)
          CheckboxListTile(
            key: ValueKey('generator-feature-$group'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              _featureLabels[group] ??
                  options
                      .firstWhere(
                        (t) => t.features.any((f) => _featureGroup(f) == group),
                      )
                      .title,
            ),
            value: !excludedFeatures.contains(group),
            onChanged: busy
                ? null
                : (allowed) => setState(() {
                    if (allowed!) {
                      excludedFeatures.remove(group);
                    } else {
                      excludedFeatures.add(group);
                    }
                    success = null;
                  }),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [levelsPanel, const SizedBox(height: 20), featuresPanel],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: levelsPanel),
            const SizedBox(width: 32),
            Expanded(child: featuresPanel),
          ],
        );
      },
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
                  t.flat
                      ? 'Шаблон · без назначения уровня'
                      : '${t.family == 'numeric' ? 'Числовой' : 'Буквенный'} · Уровень ${t.level}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  _templateTitle(t),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (t.example.isNotEmpty)
                  Text(
                    t.family == 'literal' && t.features.contains('unit')
                        ? 'ab + 3a → a(b + 3)'
                        : t.example,
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
              () => TextEditingController(text: '${quantities[t.id] ?? 5}'),
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
