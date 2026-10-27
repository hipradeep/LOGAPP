import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

class DatabaseBackupService {
  DatabaseBackupService({DatabaseService? dbService})
    : _dbService = dbService ?? DatabaseService.instance;

  final DatabaseService _dbService;

  static const int backupVersion = 1;
  static const String backupFormat = 'budget_log';

  static const List<String> _paymentModeColumns = [
    'id',
    'name',
    'type',
    'icon',
    'created_at',
  ];
  static const List<String> _categoryColumns = [
    'id',
    'name',
    'type',
    'icon',
    'color_index',
    'created_at',
  ];
  static const List<String> _transactionColumns = [
    'id',
    'amount',
    'type',
    'category_id',
    'payment_mode_id',
    'budget_id',
    'title',
    'note',
    'timestamp',
    'created_at',
  ];
  static const List<String> _contactColumns = [
    'id',
    'name',
    'phone',
    'upi_id',
    'avatar_color_index',
    'created_at',
  ];
  static const List<String> _debtColumns = [
    'id',
    'contact_id',
    'transaction_id',
    'direction',
    'amount',
    'settled_amount',
    'status',
    'due_date',
    'notes',
    'created_at',
    'settled_at',
  ];
  static const List<String> _subscriptionColumns = [
    'id',
    'name',
    'amount',
    'category_id',
    'payment_mode_id',
    'frequency',
    'next_due_date',
    'reminder_days_before',
    'is_active',
    'is_autopay',
    'notes',
    'created_at',
  ];
  static const List<String> _stagedSmsColumns = [
    'id',
    'sms_sender',
    'raw_body',
    'extracted_amount',
    'extracted_merchant',
    'extracted_type',
    'account_ref',
    'sms_timestamp',
    'status',
    'created_at',
  ];
  static const List<String> _budgetColumns = [
    'id',
    'name',
    'category_name',
    'limit_amount',
    'period',
    'description',
    'repeat_days',
    'scheduled_time',
    'start_date',
    'end_date',
    'repeat',
    'is_active',
    'alert_threshold',
    'salary',
    'rule',
    'allocations',
    'created_at',
    'updated_at',
  ];
  static const List<String> _settingsColumns = ['key', 'value', 'updated_at'];

  static const List<String> _backupTables = [
    'paymentModes',
    'categories',
    'transactions',
    'contacts',
    'debtRecords',
    'subscriptions',
    'stagedSmsTransactions',
    'budgets',
    'appSettings',
  ];

  Future<Map<String, dynamic>> exportAllToJson() async {
    final db = await _dbService.database;

    return {
      'format': backupFormat,
      'version': backupVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'paymentModes': await db.query(
        'payment_modes',
        orderBy: 'created_at ASC',
      ),
      'categories': await db.query('categories', orderBy: 'created_at ASC'),
      'transactions': await db.query('transactions', orderBy: 'timestamp DESC'),
      'contacts': await db.query('contacts', orderBy: 'name ASC'),
      'debtRecords': await db.query('debt_records', orderBy: 'created_at DESC'),
      'subscriptions': await db.query(
        'subscriptions',
        orderBy: 'next_due_date ASC',
      ),
      'stagedSmsTransactions': (await db.query(
        'staged_sms_transactions',
        orderBy: 'sms_timestamp DESC',
      )).map((row) => {...row, 'raw_body': ''}).toList(),
      'budgets': await db.query('budgets', orderBy: 'created_at ASC'),
      'appSettings': await db.query(
        'app_settings',
        where: 'key != ?',
        whereArgs: ['active_account_email'],
        orderBy: 'key ASC',
      ),
    };
  }

  Future<String?> exportToFile() async {
    final data = await exportAllToJson();
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final fileName = 'budget_log_backup_$timestamp.json';

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Budget Log Backup',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: utf8.encode(jsonString),
    );

    if (savePath != null) {
      final file = File(savePath);
      if (!await file.exists() || (await file.length()) == 0) {
        await file.writeAsString(jsonString);
      }
      return savePath;
    }
    return null;
  }

  Future<bool> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return false;

    final file = result.files.single;
    String content;
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      content = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      content = await File(file.path!).readAsString();
    } else {
      return false;
    }

    var cleaned = content.trim();
    if (cleaned.startsWith('\uFEFF')) {
      cleaned = cleaned.substring(1).trim();
    }

    final decoded = jsonDecode(cleaned);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup file format');
    }

    await importAllFromJson(decoded);
    return true;
  }

  Future<void> importAllFromJson(Map<String, dynamic> data) async {
    _validateFormat(data);

    final paymentModes = _readRows(data, 'paymentModes');
    final categories = _readRows(data, 'categories');
    final transactions = _readRows(data, 'transactions');
    final contacts = _readRows(data, 'contacts');
    final debtRecords = _readRows(data, 'debtRecords');
    final subscriptions = _readRows(data, 'subscriptions');
    final stagedSms = _readRows(data, 'stagedSmsTransactions');
    final budgets = _readRows(data, 'budgets');
    final settings = _readRows(
      data,
      'appSettings',
    ).where((row) => row['key'] != 'active_account_email').toList();

    await _dbService.runWithoutChangeEventsAsync(() async {
      final db = await _dbService.database;
      await db.transaction((txn) async {
        await txn.delete('staged_sms_transactions');
        await txn.delete('subscriptions');
        await txn.delete('debt_records');
        await txn.delete('transactions');
        await txn.delete('contacts');
        await txn.delete('categories');
        await txn.delete('payment_modes');
        await txn.delete('budgets');
        await txn.delete('app_settings');

        await _insertRows(
          txn,
          'payment_modes',
          paymentModes,
          _paymentModeColumns,
        );
        await _insertRows(txn, 'categories', categories, _categoryColumns);
        await _insertRows(txn, 'budgets', budgets, _budgetColumns);
        await _insertRows(txn, 'contacts', contacts, _contactColumns);
        await _insertRows(
          txn,
          'transactions',
          transactions,
          _transactionColumns,
        );
        await _insertRows(txn, 'debt_records', debtRecords, _debtColumns);
        await _insertRows(
          txn,
          'subscriptions',
          subscriptions,
          _subscriptionColumns,
        );
        await _insertRows(
          txn,
          'staged_sms_transactions',
          stagedSms,
          _stagedSmsColumns,
        );
        await _insertRows(txn, 'app_settings', settings, _settingsColumns);

        await _verifyCounts(txn, {
          'payment_modes': paymentModes.length,
          'categories': categories.length,
          'transactions': transactions.length,
          'contacts': contacts.length,
          'debt_records': debtRecords.length,
          'subscriptions': subscriptions.length,
          'staged_sms_transactions': stagedSms.length,
          'budgets': budgets.length,
          'app_settings': settings.length,
        });
      });
    });

    await _dbService.reloadAllStreams();
    _dbService.notifyDatabaseChanged('all');
  }

  void _validateFormat(Map<String, dynamic> data) {
    if (data['format'] != backupFormat) {
      throw const FormatException('Invalid backup format');
    }
    final version = data['version'];
    if (version is! num || version.toInt() > backupVersion) {
      throw const FormatException('Unsupported backup version');
    }
    for (final key in _backupTables) {
      if (data[key] is! List) {
        throw FormatException('Invalid backup table: $key');
      }
    }
  }

  List<Map<String, dynamic>> _readRows(Map<String, dynamic> data, String key) {
    final raw = data[key];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> _insertRows(
    DatabaseExecutor executor,
    String table,
    List<Map<String, dynamic>> rows,
    List<String> allowedColumns,
  ) async {
    for (final row in rows) {
      final values = <String, dynamic>{
        for (final column in allowedColumns)
          if (row.containsKey(column)) column: row[column],
      };
      if (values.isEmpty) continue;
      await executor.insert(
        table,
        values,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _verifyCounts(
    DatabaseExecutor executor,
    Map<String, int> expected,
  ) async {
    for (final entry in expected.entries) {
      final result = await executor.rawQuery(
        'SELECT COUNT(*) AS count FROM ${entry.key}',
      );
      final actual = Sqflite.firstIntValue(result) ?? 0;
      if (actual != entry.value) {
        throw StateError(
          'Backup verification failed for ${entry.key}: '
          'expected ${entry.value}, got $actual',
        );
      }
    }
  }
}
