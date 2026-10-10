// An immutable record of a checked task, kept only during this practice.
class PracticeRecord {
  const PracticeRecord({required this.selected, required this.explanationOpen});
  final int selected;
  final bool explanationOpen;
}
