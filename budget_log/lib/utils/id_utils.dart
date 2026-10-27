import 'package:uuid/uuid.dart';

class IdUtils {
  IdUtils._();

  static const Uuid _uuid = Uuid();

  static String generate(String prefix) => '${prefix}_${_uuid.v4()}';
}
