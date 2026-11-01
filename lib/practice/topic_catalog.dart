/// Display roadmap, not a template bank or an approved prerequisite graph.
/// Sources and provisional grouping: docs/planning/topic_roadmap.md.
class PracticeTopicEntry {
  const PracticeTopicEntry(this.id, this.title, this.section, {this.family});
  final String id, title, section;
  final String? family;
  bool get available => family != null;
  String get caption => available ? section : '$section · Планируется';
}

const practiceTopicCatalog = <PracticeTopicEntry>[
  PracticeTopicEntry(
    "numeric_common_factor",
    "Вынесение численного общего множителя за скобки",
    "Алгебра · Общий множитель",
    family: "numeric",
  ),
  PracticeTopicEntry(
    "literal_common_factor",
    "Вынесение буквенного общего множителя за скобки",
    "Алгебра · Общий множитель",
    family: "literal",
  ),
  PracticeTopicEntry(
    "numeric_bracket_multiplication",
    "Умножение на скобку — числовой множитель",
    "Алгебра · Раскрытие скобок",
    family: "numeric_bracket",
  ),
  PracticeTopicEntry(
    "literal_bracket_multiplication",
    "Умножение на скобку — буквенный множитель",
    "Алгебра · Раскрытие скобок",
    family: "literal_bracket",
  ),
  PracticeTopicEntry(
    "fraction_cancellation",
    "Сокращение дробей: множители и слагаемые",
    "Дроби · Болевые точки",
  ),
  PracticeTopicEntry(
    "bracket_multiplication",
    "Умножение скобки на скобку",
    "Алгебра · Раскрытие скобок",
  ),
  PracticeTopicEntry(
    "multiple_common_factors",
    "Вынесение нескольких общих множителей за скобки",
    "Алгебра · Общий множитель",
  ),
  PracticeTopicEntry(
    "negative_common_factor",
    "Вынесение отрицательного множителя",
    "Алгебра · Отложено",
  ),
  PracticeTopicEntry(
    "fractional_common_factor",
    "Вынесение обыкновенного дробного множителя",
    "Алгебра · Отложено",
  ),
  PracticeTopicEntry(
    "decimal_common_factor",
    "Десятичный общий множитель",
    "Алгебра · Отложено",
  ),
  PracticeTopicEntry(
    "common_bracket",
    "Вынесение общей скобки за скобки",
    "Алгебра · Общий множитель",
  ),
  PracticeTopicEntry(
    "power_properties",
    "Свойства степеней",
    "Алгебра · Степени",
  ),
  PracticeTopicEntry(
    "sum_product_notation",
    "Запись произведения суммы и числа: скобки",
    "Выражения · Скобки",
  ),
  PracticeTopicEntry(
    "difference_product_notation",
    "Запись произведения разности и числа: скобки",
    "Выражения · Скобки",
  ),
  PracticeTopicEntry(
    "division",
    "Действие деления (без остатка) для целых предметов",
    "Арифметика · Делимость",
  ),
  PracticeTopicEntry(
    "division_elements",
    "Элементы деления",
    "Арифметика · Делимость",
  ),
  PracticeTopicEntry("divisors", "Делители числа", "Арифметика · Делимость"),
  PracticeTopicEntry(
    "prime_composite",
    "Простые и составные числа",
    "Арифметика · Делимость",
  ),
  PracticeTopicEntry(
    "prime_factorization",
    "Разложение числа на простые множители",
    "Арифметика · Делимость",
  ),
  PracticeTopicEntry(
    "common_divisors",
    "Общие делители нескольких чисел",
    "Арифметика · Делимость",
  ),
  PracticeTopicEntry(
    "gcd",
    "Наибольший общий делитель (НОД)",
    "Арифметика · Делимость",
  ),
  PracticeTopicEntry(
    "gcd_properties",
    "Важные свойства НОД",
    "Арифметика · Делимость",
  ),
  PracticeTopicEntry("multiples", "Кратные числа", "Арифметика · Делимость"),
  PracticeTopicEntry(
    "common_multiples",
    "Общие кратные нескольких чисел",
    "Арифметика · Делимость",
  ),
  PracticeTopicEntry(
    "lcm",
    "Наименьшее общее кратное (НОК)",
    "Арифметика · Делимость",
  ),
  PracticeTopicEntry(
    "lcm_properties",
    "Важные свойства НОК",
    "Арифметика · Делимость",
  ),
  PracticeTopicEntry(
    "parts",
    "Доли: деление ОДНОЙ вещи на равные части",
    "Арифметика · Дроби",
  ),
  PracticeTopicEntry(
    "fraction_as_division",
    "Дробь как деление: соответствие a/b и a : b",
    "Арифметика · Дроби",
  ),
  PracticeTopicEntry(
    "ordinary_fraction",
    "Обыкновенная дробь (ядро)",
    "Арифметика · Дроби",
  ),
  PracticeTopicEntry(
    "compare_same_denominator",
    "Сравнение дробей с одинаковым знаменателем",
    "Арифметика · Дроби",
  ),
  PracticeTopicEntry(
    "add_same_denominator",
    "Сложение дробей с одинаковым знаменателем",
    "Арифметика · Дроби",
  ),
  PracticeTopicEntry(
    "subtract_same_denominator",
    "Вычитание дробей с одинаковым знаменателем",
    "Арифметика · Дроби",
  ),
  PracticeTopicEntry(
    "fraction_property",
    "Основное свойство дроби",
    "Арифметика · Дроби",
  ),
  PracticeTopicEntry(
    "irreducible_fraction",
    "Несократимая дробь",
    "Арифметика · Дроби",
  ),
  PracticeTopicEntry(
    "change_denominator",
    "Приведение дроби к другому знаменателю",
    "Арифметика · Дроби",
  ),
  PracticeTopicEntry(
    "compare_different_denominators",
    "Сравнение дробей с разным знаменателем",
    "Арифметика · Дроби",
  ),
  PracticeTopicEntry(
    "add_different_denominators",
    "Сложение дробей с разным знаменателем",
    "Арифметика · Дроби",
  ),
  PracticeTopicEntry(
    "subtract_different_denominators",
    "Вычитание дробей с разным знаменателем",
    "Арифметика · Дроби",
  ),
];
