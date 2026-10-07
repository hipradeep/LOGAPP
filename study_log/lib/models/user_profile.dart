/// Complete User Profile document combining user identity & aggregated study statistics.
///
/// Stores profile details (name, role/headline, avatar) alongside lifetime progress stats
/// (streaks, total session hours, total active days, completed topics & revisions).
class UserProfile {
  final String id;
  final String name;
  final String headline;
  final String? email;
  final String? avatarUrl;
  final int currentStreak;
  final int longestStreak;
  final int totalActiveDays;
  final int totalStudyMinutes;
  final int totalTopicsFinished;
  final int totalTopicRevisions;
  final DateTime? lastActiveDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    this.id = 'profile',
    this.name = 'Learner',
    this.headline = 'Student',
    this.email,
    this.avatarUrl,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalActiveDays = 0,
    this.totalStudyMinutes = 0,
    this.totalTopicsFinished = 0,
    this.totalTopicRevisions = 0,
    this.lastActiveDate,
    required this.createdAt,
    required this.updatedAt,
  });

  /// First letter of name for the profile avatar fallback.
  String get initial {
    final trimmed = name.trim();
    return trimmed.isNotEmpty ? trimmed[0].toUpperCase() : 'P';
  }

  /// Total study time in decimal hours (e.g. 2.5 hrs).
  double get totalStudyHours => totalStudyMinutes / 60.0;

  /// User-friendly study duration string (e.g. "45m", "3h", or "3h 15m").
  String get formattedStudyDuration {
    if (totalStudyMinutes <= 0) return '0h';
    final hours = totalStudyMinutes ~/ 60;
    final mins = totalStudyMinutes % 60;
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  /// Compact study hours string (e.g. "0h", "1.5h", "12h").
  String get formattedStudyHours {
    if (totalStudyMinutes <= 0) return '0h';
    final hours = totalStudyMinutes / 60.0;
    if (hours < 1.0) {
      return '${totalStudyMinutes}m';
    }
    if (hours == hours.truncateToDouble()) {
      return '${hours.toInt()}h';
    }
    return '${hours.toStringAsFixed(1)}h';
  }

  Map<String, dynamic> toMap({bool forLocalJson = false}) {
    return {
      'id': id,
      'name': name,
      'headline': headline,
      if (email != null) 'email': email,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'totalActiveDays': totalActiveDays,
      'totalStudyMinutes': totalStudyMinutes,
      'totalTopicsFinished': totalTopicsFinished,
      'totalTopicRevisions': totalTopicRevisions,
      if (lastActiveDate != null)
        'lastActiveDate': lastActiveDate!.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, {String? documentId}) {
    final now = DateTime.now();
    return UserProfile(
      id: (documentId != null && documentId.isNotEmpty)
          ? documentId
          : (map['id']?.toString() ?? 'profile'),
      name: map['name']?.toString() ?? 'Learner',
      headline: map['headline']?.toString() ?? 'Student',
      email: map['email']?.toString(),
      avatarUrl: map['avatarUrl']?.toString(),
      currentStreak: _parseInt(map['currentStreak']),
      longestStreak: _parseInt(map['longestStreak']),
      totalActiveDays: _parseInt(map['totalActiveDays']),
      totalStudyMinutes: _parseInt(map['totalStudyMinutes']),
      totalTopicsFinished: _parseInt(map['totalTopicsFinished']),
      totalTopicRevisions: _parseInt(map['totalTopicRevisions']),
      lastActiveDate: _parseDateTime(map['lastActiveDate']),
      createdAt: _parseDateTime(map['createdAt']) ?? now,
      updatedAt: _parseDateTime(map['updatedAt']) ?? now,
    );
  }

  static int _parseInt(dynamic val) {
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 0;
    return 0;
  }

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? headline,
    String? email,
    String? avatarUrl,
    int? currentStreak,
    int? longestStreak,
    int? totalActiveDays,
    int? totalStudyMinutes,
    int? totalTopicsFinished,
    int? totalTopicRevisions,
    DateTime? lastActiveDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      headline: headline ?? this.headline,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalActiveDays: totalActiveDays ?? this.totalActiveDays,
      totalStudyMinutes: totalStudyMinutes ?? this.totalStudyMinutes,
      totalTopicsFinished: totalTopicsFinished ?? this.totalTopicsFinished,
      totalTopicRevisions: totalTopicRevisions ?? this.totalTopicRevisions,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
