class Milestone {
  String title;
  DateTime date;
  bool isCompleted;

  Milestone({
    required this.title,
    required this.date,
    this.isCompleted = false,
  });
}
