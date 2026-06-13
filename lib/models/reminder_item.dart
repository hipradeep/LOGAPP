class ReminderItem {
  String title;
  String time;
  bool isActive;

  ReminderItem({
    required this.title,
    required this.time,
    this.isActive = true,
  });
}
