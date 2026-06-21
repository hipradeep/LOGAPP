import 'package:uuid/uuid.dart';

/// Single source of truth for local ID generation.
/// All services import this — never import uuid directly in a service.
class IdUtils {
  IdUtils._();

  static const _uuid = Uuid();

  /// Generates a v4 UUID string (e.g. "550e8400-e29b-41d4-a716-446655440000").
  static String generateId() => _uuid.v4();
}
