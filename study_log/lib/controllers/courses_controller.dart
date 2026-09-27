import 'package:flutter/material.dart';
import '../models/course.dart';

class CoursesController extends ChangeNotifier {
  final List<Course> _courses = [
    Course(
      id: '1',
      title: 'Advanced Data Structures & Algorithms',
      description: 'Master trees, graphs, dynamic programming, and system design algorithms.',
      status: 'active',
      deadline: DateTime.now().add(const Duration(days: 45)),
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      updatedAt: DateTime.now(),
    ),
    Course(
      id: '2',
      title: 'Operating Systems & Architecture',
      description: 'Concurrency, memory virtualization, kernel scheduling, and file systems.',
      status: 'active',
      deadline: DateTime.now().add(const Duration(days: 30)),
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      updatedAt: DateTime.now(),
    ),
    Course(
      id: '3',
      title: 'Linear Algebra & Optimization',
      description: 'Matrix decompositions, vector spaces, eigenvalues, and convex optimization.',
      status: 'active',
      deadline: DateTime.now().add(const Duration(days: 60)),
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now(),
    ),
  ];

  List<Course> get courses => List.unmodifiable(_courses);

  void addCourse({
    required String title,
    required String description,
    DateTime? deadline,
    String status = 'active',
  }) {
    final now = DateTime.now();
    final newCourse = Course(
      id: now.millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      status: status,
      deadline: deadline,
      createdAt: now,
      updatedAt: now,
    );
    _courses.insert(0, newCourse);
    notifyListeners();
  }
}
