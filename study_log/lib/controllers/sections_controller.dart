import 'dart:async';
import 'package:flutter/material.dart';
import '../models/section.dart';
import '../services/firestore_service.dart';
import '../services/local_section_storage.dart';
import '../services/service_locator.dart';

/// Controller managing Section entities for a given Course with offline persistence.
class SectionsController extends ChangeNotifier {
  final String courseId;
  final FirestoreService _firestoreService;
  StreamSubscription<List<Section>>? _sectionsSubscription;
  Timer? _loadingFallbackTimer;

  List<Section> _sections = [];
  final Set<String> _deletedSectionIds = {};
  bool _isLoading = true;
  String? _errorMessage;

  SectionsController({
    required this.courseId,
    FirestoreService? firestoreService,
  }) : _firestoreService = firestoreService ?? getIt<FirestoreService>() {
    _init();
  }

  List<Section> get sections => List.unmodifiable(_sections);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> _init() async {
    // 1. Immediately hydrate from local storage
    try {
      final cached = await LocalSectionStorage.loadSections(courseId);
      if (cached.isNotEmpty) {
        _sections = cached;
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Local sections hydration error: $e');
    }

    // 2. Start Firestore stream
    _initStream();
  }

  void _initStream() {
    _sectionsSubscription?.cancel();
    _loadingFallbackTimer?.cancel();
    _errorMessage = null;

    if (_sections.isEmpty) {
      _isLoading = true;
    }

    _loadingFallbackTimer = Timer(const Duration(seconds: 2), () {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    });

    try {
      _sectionsSubscription = _firestoreService.streamSections(courseId: courseId).listen(
        (remoteSections) {
          _loadingFallbackTimer?.cancel();
          _isLoading = false;
          _errorMessage = null;
          _mergeSections(remoteSections);
        },
        onError: (error) {
          _loadingFallbackTimer?.cancel();
          debugPrint('Error streaming sections: $error');
          _isLoading = false;
          if (_sections.isEmpty) {
            _errorMessage = error.toString();
          }
          notifyListeners();
        },
      );
    } catch (e) {
      _loadingFallbackTimer?.cancel();
      _isLoading = false;
      if (_sections.isEmpty) {
        _errorMessage = e.toString();
      }
      notifyListeners();
    }
  }

  void _mergeSections(List<Section> remoteSections) {
    final Map<String, Section> merged = {};

    for (final section in remoteSections) {
      if (!_deletedSectionIds.contains(section.id)) {
        merged[section.id] = section;
      }
    }

    for (final local in _sections) {
      if (!_deletedSectionIds.contains(local.id)) {
        if (!merged.containsKey(local.id)) {
          merged[local.id] = local;
        }
      }
    }

    final result = merged.values.toList();
    result.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    _sections = result;
    LocalSectionStorage.saveSectionsForCourse(courseId, _sections);
    notifyListeners();
  }

  Future<void> addSection({
    required String title,
    required String description,
    String status = 'active',
  }) async {
    final now = DateTime.now();
    final newId = 'section_${now.millisecondsSinceEpoch}';
    final nextOrder = _sections.isEmpty
        ? 1
        : (_sections.map((s) => s.orderIndex).reduce((a, b) => a > b ? a : b) + 1);

    final newSection = Section(
      id: newId,
      courseId: courseId,
      title: title,
      description: description,
      orderIndex: nextOrder,
      status: status,
      createdAt: now,
      updatedAt: now,
    );

    _deletedSectionIds.remove(newId);
    _sections.removeWhere((s) => s.id == newId);
    _sections.add(newSection);
    _sections.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    _isLoading = false;
    _errorMessage = null;
    await LocalSectionStorage.saveSectionsForCourse(courseId, _sections);
    notifyListeners();

    try {
      await _firestoreService.addSection(newSection).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('Firestore addSection timed out, stored locally.');
        },
      );
    } catch (e) {
      debugPrint('Firestore addSection error: $e');
    }
  }

  Future<void> deleteSection(String sectionId) async {
    _deletedSectionIds.add(sectionId);
    _sections.removeWhere((s) => s.id == sectionId);
    await LocalSectionStorage.saveSectionsForCourse(courseId, _sections);
    notifyListeners();
  }

  @override
  void dispose() {
    _loadingFallbackTimer?.cancel();
    _sectionsSubscription?.cancel();
    super.dispose();
  }
}
