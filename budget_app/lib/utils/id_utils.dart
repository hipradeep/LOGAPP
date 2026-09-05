import 'package:uuid/uuid.dart';

class IdUtils {
  IdUtils._();

  static const _uuid = Uuid();

  /// Generates a v4 UUID string
  static String generateId() => _uuid.v4();
}
