import 'revision_module.dart';
import 'topic_revision.dart';

/// Distinguishes between an individual topic revision and a whole module revision.
enum RevisionItemType {
  topic,
  module,
}

/// Alias for [RevisionItemType] to match specification naming.
typedef RevisionType = RevisionItemType;

/// Polymorphic interface representing any revision item (Topic or Module)
/// in the unified spaced repetition stream.
abstract class UnifiedRevisionItem {
  String get id;
  String get courseId;
  String get moduleId;
  String get title;
  int get currentLevel;
  RevisionStatus get status;
  DateTime get nextRevisionAt;
  DateTime? get lastRevisionAt;
  DateTime? get completedAt;
  RevisionItemType get type;

  bool isDueAt(DateTime now);
  bool get isFinished;
}

/// Adapter wrapping a [TopicRevision] as a [UnifiedRevisionItem].
class UnifiedTopicRevisionItem implements UnifiedRevisionItem {
  final TopicRevision topicRevision;

  const UnifiedTopicRevisionItem(this.topicRevision);

  @override
  String get id => topicRevision.id;

  @override
  String get courseId => topicRevision.courseId;

  @override
  String get moduleId => topicRevision.moduleId;

  @override
  String get title => topicRevision.title;

  @override
  int get currentLevel => topicRevision.currentLevel;

  @override
  RevisionStatus get status => topicRevision.status;

  @override
  DateTime get nextRevisionAt => topicRevision.nextRevisionAt;

  @override
  DateTime? get lastRevisionAt => topicRevision.lastRevisionAt;

  @override
  DateTime? get completedAt => topicRevision.completedAt;

  @override
  RevisionItemType get type => RevisionItemType.topic;

  @override
  bool isDueAt(DateTime now) => topicRevision.isDueAt(now);

  @override
  bool get isFinished => topicRevision.isFinished;
}

/// Adapter wrapping a [RevisionModule] as a [UnifiedRevisionItem].
class UnifiedModuleRevisionItem implements UnifiedRevisionItem {
  final RevisionModule moduleRevision;
  final String resolvedTitle;
  final int topicCount;

  const UnifiedModuleRevisionItem(
    this.moduleRevision, {
    this.resolvedTitle = '',
    this.topicCount = 0,
  });

  @override
  String get id => moduleRevision.id;

  @override
  String get courseId => moduleRevision.courseId;

  @override
  String get moduleId => moduleRevision.moduleId;

  @override
  String get title => resolvedTitle;

  @override
  int get currentLevel => moduleRevision.currentLevel;

  @override
  RevisionStatus get status => moduleRevision.status;

  @override
  DateTime get nextRevisionAt => moduleRevision.nextRevisionAt;

  @override
  DateTime? get lastRevisionAt => moduleRevision.lastRevisionAt;

  @override
  DateTime? get completedAt => moduleRevision.completedAt;

  @override
  RevisionItemType get type => RevisionItemType.module;

  @override
  bool isDueAt(DateTime now) => moduleRevision.isDueAt(now);

  @override
  bool get isFinished => moduleRevision.isFinished;
}
