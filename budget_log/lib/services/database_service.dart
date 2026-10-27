import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/budget.dart';
import '../models/budget_transaction.dart';
import '../models/category.dart';
import '../models/contact.dart';
import '../models/debt_record.dart';
import '../models/payment_mode.dart';
import '../models/staged_sms_transaction.dart';
import '../models/subscription.dart';
import '../utils/date_utils.dart';
import '../utils/id_utils.dart';
import '../utils/subscription_schedule.dart';

class DatabaseService {
  DatabaseService({DatabaseFactory? factory, String? path})
    : _factory = factory ?? databaseFactory,
      _databasePath = path;

  static final DatabaseService instance = DatabaseService();

  static const int schemaVersion = 2;

  static const List<String> _indexStatements = [
    'CREATE INDEX IF NOT EXISTS idx_transactions_timestamp ON transactions(timestamp);',
    'CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type);',
    'CREATE INDEX IF NOT EXISTS idx_transactions_budget ON transactions(budget_id);',
    'CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id);',
    'CREATE INDEX IF NOT EXISTS idx_transactions_payment_mode ON transactions(payment_mode_id);',
    'CREATE INDEX IF NOT EXISTS idx_categories_type ON categories(type);',
    'CREATE INDEX IF NOT EXISTS idx_payment_modes_type ON payment_modes(type);',
    'CREATE INDEX IF NOT EXISTS idx_contacts_name ON contacts(name);',
    'CREATE INDEX IF NOT EXISTS idx_debt_contact ON debt_records(contact_id);',
    'CREATE INDEX IF NOT EXISTS idx_debt_status ON debt_records(status);',
    'CREATE INDEX IF NOT EXISTS idx_debt_transaction ON debt_records(transaction_id);',
    'CREATE INDEX IF NOT EXISTS idx_subscriptions_due ON subscriptions(next_due_date);',
    'CREATE INDEX IF NOT EXISTS idx_subscriptions_active ON subscriptions(is_active);',
    'CREATE INDEX IF NOT EXISTS idx_staged_sms_status ON staged_sms_transactions(status);',
    'CREATE INDEX IF NOT EXISTS idx_staged_sms_timestamp ON staged_sms_transactions(sms_timestamp);',
    'CREATE INDEX IF NOT EXISTS idx_budgets_active ON budgets(is_active);',
  ];

  final DatabaseFactory _factory;
  final String? _databasePath;

  Database? _db;
  bool _suppressChangeEvents = false;

  final _changeController = StreamController<String>.broadcast();
  final _paymentModesController =
      StreamController<List<PaymentMode>>.broadcast();
  final _categoriesController = StreamController<List<Category>>.broadcast();
  final _transactionsController =
      StreamController<List<BudgetTransaction>>.broadcast();
  final _contactsController = StreamController<List<Contact>>.broadcast();
  final _debtRecordsController = StreamController<List<DebtRecord>>.broadcast();
  final _subscriptionsController =
      StreamController<List<Subscription>>.broadcast();
  final _stagedSmsController =
      StreamController<List<StagedSmsTransaction>>.broadcast();
  final _budgetsController = StreamController<List<Budget>>.broadcast();
  final _settingsController = StreamController<Map<String, String>>.broadcast();

  bool get isAvailable => true;

  Stream<String> get onDatabaseChanged => _changeController.stream;

  Stream<List<PaymentMode>> get paymentModesStream =>
      _paymentModesController.stream;

  Stream<List<Category>> get categoriesStream => _categoriesController.stream;

  Stream<List<BudgetTransaction>> get transactionsStream =>
      _transactionsController.stream;

  Stream<List<Contact>> get contactsStream => _contactsController.stream;

  Stream<List<DebtRecord>> get debtRecordsStream =>
      _debtRecordsController.stream;

  Stream<List<Subscription>> get subscriptionsStream =>
      _subscriptionsController.stream;

  Stream<List<StagedSmsTransaction>> get stagedSmsStream =>
      _stagedSmsController.stream;

  Stream<List<Budget>> get budgetsStream => _budgetsController.stream;

  Stream<Map<String, String>> get settingsStream => _settingsController.stream;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _openDatabase();
    return _db!;
  }

  Future<void> init() async {
    await database;
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }

  Future<Database> _openDatabase() async {
    final dbPath =
        _databasePath ??
        join(await _factory.getDatabasesPath(), 'budget_log.db');

    return _factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) async {
          await db.rawQuery('PRAGMA journal_mode=WAL;');
          for (final statement in _indexStatements) {
            await db.execute(statement);
          }
        },
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE payment_modes (
        id         TEXT PRIMARY KEY,
        name       TEXT NOT NULL,
        type       TEXT NOT NULL,
        icon       TEXT,
        created_at INTEGER NOT NULL
      );
    ''');

    batch.execute('''
      CREATE TABLE categories (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        type        TEXT NOT NULL,
        icon        TEXT,
        color_index INTEGER NOT NULL DEFAULT 0,
        created_at  INTEGER NOT NULL
      );
    ''');

    batch.execute('''
      CREATE TABLE budgets (
        id              TEXT PRIMARY KEY,
        name            TEXT NOT NULL,
        category_name   TEXT NOT NULL DEFAULT '',
        limit_amount    REAL NOT NULL,
        period          TEXT NOT NULL DEFAULT 'monthly',
        description     TEXT NOT NULL DEFAULT '',
        repeat_days     TEXT NOT NULL DEFAULT '[1,2,3,4,5,6,7]',
        scheduled_time  TEXT,
        start_date      INTEGER,
        end_date        INTEGER,
        repeat          INTEGER NOT NULL DEFAULT 1,
        is_active       INTEGER NOT NULL DEFAULT 1,
        alert_threshold REAL NOT NULL DEFAULT 0.7,
        salary          REAL,
        rule            TEXT,
        allocations     TEXT NOT NULL DEFAULT '[]',
        created_at      INTEGER NOT NULL,
        updated_at      INTEGER NOT NULL
      );
    ''');

    batch.execute('''
      CREATE TABLE transactions (
        id              TEXT PRIMARY KEY,
        amount          REAL NOT NULL,
        type            TEXT NOT NULL,
        category_id     TEXT,
        payment_mode_id TEXT,
        budget_id       TEXT,
        title           TEXT NOT NULL,
        note            TEXT,
        timestamp       INTEGER NOT NULL,
        created_at      INTEGER NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
        FOREIGN KEY (payment_mode_id) REFERENCES payment_modes(id) ON DELETE SET NULL,
        FOREIGN KEY (budget_id) REFERENCES budgets(id) ON DELETE SET NULL
      );
    ''');

    batch.execute('''
      CREATE TABLE contacts (
        id                 TEXT PRIMARY KEY,
        name               TEXT NOT NULL,
        phone              TEXT,
        upi_id             TEXT,
        avatar_color_index INTEGER NOT NULL DEFAULT 0,
        created_at         INTEGER NOT NULL
      );
    ''');

    batch.execute('''
      CREATE TABLE debt_records (
        id             TEXT PRIMARY KEY,
        contact_id     TEXT NOT NULL,
        transaction_id TEXT,
        direction      TEXT NOT NULL,
        amount         REAL NOT NULL,
        settled_amount REAL NOT NULL DEFAULT 0,
        status         TEXT NOT NULL DEFAULT 'pending',
        due_date       INTEGER,
        notes          TEXT,
        created_at     INTEGER NOT NULL,
        settled_at     INTEGER,
        FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE CASCADE,
        FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE SET NULL
      );
    ''');

    batch.execute('''
      CREATE TABLE subscriptions (
        id                  TEXT PRIMARY KEY,
        name                TEXT NOT NULL,
        amount              REAL NOT NULL,
        category_id         TEXT,
        payment_mode_id     TEXT,
        frequency           TEXT NOT NULL,
        next_due_date       INTEGER NOT NULL,
        reminder_days_before INTEGER NOT NULL DEFAULT 1,
        is_active           INTEGER NOT NULL DEFAULT 1,
        is_autopay          INTEGER NOT NULL DEFAULT 0,
        notes               TEXT,
        created_at          INTEGER NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
        FOREIGN KEY (payment_mode_id) REFERENCES payment_modes(id) ON DELETE SET NULL
      );
    ''');

    batch.execute('''
      CREATE TABLE staged_sms_transactions (
        id                 TEXT PRIMARY KEY,
        sms_sender         TEXT NOT NULL,
        raw_body           TEXT NOT NULL,
        extracted_amount   REAL,
        extracted_merchant TEXT,
        extracted_type     TEXT,
        account_ref        TEXT,
        sms_timestamp      INTEGER NOT NULL,
        status             TEXT NOT NULL DEFAULT 'pending',
        created_at         INTEGER NOT NULL
      );
    ''');

    batch.execute('''
      CREATE TABLE app_settings (
        key        TEXT PRIMARY KEY,
        value      TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    for (final statement in _indexStatements) {
      batch.execute(statement);
    }

    await batch.commit(noResult: true);
    await _seedDefaults(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (var version = oldVersion + 1; version <= newVersion; version++) {
      switch (version) {
        case 1:
          break;
        case 2:
          await db.execute(
            'ALTER TABLE subscriptions '
            'ADD COLUMN is_autopay INTEGER NOT NULL DEFAULT 0;',
          );
          break;
      }
    }
  }

  Future<void> _seedDefaults(DatabaseExecutor executor) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    const paymentModes = [
      ('pm_cash', 'Cash', 'cash'),
      ('pm_bank', 'Bank', 'bank'),
      ('pm_upi', 'UPI', 'wallet'),
      ('pm_debit_card', 'Debit Card', 'card'),
      ('pm_credit_card', 'Credit Card', 'card'),
      ('pm_wallet', 'Wallet', 'wallet'),
    ];

    for (final item in paymentModes) {
      await executor.insert('payment_modes', {
        'id': item.$1,
        'name': item.$2,
        'type': item.$3,
        'icon': null,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    const categories = [
      ('cat_food', 'Food', 'expense', 2),
      ('cat_groceries', 'Groceries', 'expense', 1),
      ('cat_transport', 'Transport', 'expense', 3),
      ('cat_shopping', 'Shopping', 'expense', 0),
      ('cat_bills', 'Bills', 'expense', 4),
      ('cat_entertainment', 'Entertainment', 'expense', 5),
      ('cat_health', 'Health', 'expense', 6),
      ('cat_education', 'Education', 'expense', 3),
      ('cat_rent', 'Rent', 'expense', 2),
      ('cat_salary', 'Salary', 'income', 1),
      ('cat_other', 'Other', 'expense', 0),
    ];

    for (final item in categories) {
      await executor.insert('categories', {
        'id': item.$1,
        'name': item.$2,
        'type': item.$3,
        'icon': null,
        'color_index': item.$4,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  void _notifyChange(String table) {
    if (_suppressChangeEvents || _changeController.isClosed) return;
    _changeController.add(table);
  }

  void notifyDatabaseChanged([String table = 'general']) {
    _notifyChange(table);
  }

  Future<T> runWithoutChangeEventsAsync<T>(Future<T> Function() action) async {
    final previous = _suppressChangeEvents;
    _suppressChangeEvents = true;
    try {
      return await action();
    } finally {
      _suppressChangeEvents = previous;
    }
  }

  Future<List<PaymentMode>> getPaymentModes() async {
    final db = await database;
    final rows = await db.query('payment_modes', orderBy: 'created_at ASC');
    return rows.map(PaymentMode.fromMap).toList();
  }

  Stream<List<PaymentMode>> watchPaymentModes() async* {
    yield await getPaymentModes();
    yield* _paymentModesController.stream;
  }

  Future<void> addPaymentMode(PaymentMode mode) async {
    final db = await database;
    await db.insert(
      'payment_modes',
      mode.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _refreshPaymentModes();
    _notifyChange('payment_modes');
  }

  Future<void> updatePaymentMode(PaymentMode mode) async {
    final db = await database;
    await db.update(
      'payment_modes',
      mode.toMap(),
      where: 'id = ?',
      whereArgs: [mode.id],
    );
    await _refreshPaymentModes();
    _notifyChange('payment_modes');
  }

  Future<void> deletePaymentMode(String id) async {
    final db = await database;
    await db.delete('payment_modes', where: 'id = ?', whereArgs: [id]);
    await _refreshPaymentModes();
    await _refreshTransactions();
    _notifyChange('payment_modes');
    _notifyChange('transactions');
  }

  Future<List<Category>> getCategories({String? type}) async {
    final db = await database;
    final rows = await db.query(
      'categories',
      where: type == null ? null : 'type = ?',
      whereArgs: type == null ? null : [type],
      orderBy: 'created_at ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  Stream<List<Category>> watchCategories() async* {
    yield await getCategories();
    yield* _categoriesController.stream;
  }

  Future<void> addCategory(Category category) async {
    final db = await database;
    await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _refreshCategories();
    _notifyChange('categories');
  }

  Future<void> updateCategory(Category category) async {
    final db = await database;
    await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
    await _refreshCategories();
    _notifyChange('categories');
  }

  Future<void> deleteCategory(String id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    await _refreshCategories();
    await _refreshTransactions();
    _notifyChange('categories');
    _notifyChange('transactions');
  }

  Future<List<BudgetTransaction>> getTransactions({
    String? budgetId,
    String? type,
    String? categoryId,
    String? paymentModeId,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await database;
    final clauses = <String>[];
    final args = <Object?>[];

    if (budgetId != null) {
      clauses.add('budget_id = ?');
      args.add(budgetId);
    }
    if (type != null) {
      clauses.add('type = ?');
      args.add(type);
    }
    if (categoryId != null) {
      clauses.add('category_id = ?');
      args.add(categoryId);
    }
    if (paymentModeId != null) {
      clauses.add('payment_mode_id = ?');
      args.add(paymentModeId);
    }
    if (from != null) {
      clauses.add('timestamp >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      clauses.add('timestamp <= ?');
      args.add(to.millisecondsSinceEpoch);
    }

    final rows = await db.query(
      'transactions',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'timestamp DESC, created_at DESC',
    );
    return rows.map(BudgetTransaction.fromMap).toList();
  }

  Stream<List<BudgetTransaction>> watchTransactions() async* {
    yield await getTransactions();
    yield* _transactionsController.stream;
  }

  Future<void> addTransaction(BudgetTransaction transaction) async {
    final db = await database;
    await db.insert(
      'transactions',
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _refreshTransactions();
    _notifyChange('transactions');
  }

  Future<void> addTransactionWithDebtRecords(
    BudgetTransaction transaction,
    List<DebtRecord> debtRecords,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'transactions',
        transaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final record in debtRecords) {
        await txn.insert(
          'debt_records',
          record.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    await _refreshTransactions();
    await _refreshDebtRecords();
    _notifyChange('transactions');
    _notifyChange('debt_records');
  }

  Future<void> updateTransaction(BudgetTransaction transaction) async {
    final db = await database;
    await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
    await _refreshTransactions();
    _notifyChange('transactions');
  }

  Future<void> deleteTransaction(String id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
    await _refreshTransactions();
    _notifyChange('transactions');
  }

  Future<List<Contact>> getContacts() async {
    final db = await database;
    final rows = await db.query('contacts', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Contact.fromMap).toList();
  }

  Stream<List<Contact>> watchContacts() async* {
    yield await getContacts();
    yield* _contactsController.stream;
  }

  Future<void> addContact(Contact contact) async {
    final db = await database;
    await db.insert(
      'contacts',
      contact.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _refreshContacts();
    _notifyChange('contacts');
  }

  Future<void> updateContact(Contact contact) async {
    final db = await database;
    await db.update(
      'contacts',
      contact.toMap(),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
    await _refreshContacts();
    _notifyChange('contacts');
  }

  Future<void> deleteContact(String id) async {
    final db = await database;
    await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
    await _refreshContacts();
    await _refreshDebtRecords();
    _notifyChange('contacts');
    _notifyChange('debt_records');
  }

  Future<List<DebtRecord>> getDebtRecords({
    String? contactId,
    String? status,
  }) async {
    final db = await database;
    final clauses = <String>[];
    final args = <Object?>[];
    if (contactId != null) {
      clauses.add('contact_id = ?');
      args.add(contactId);
    }
    if (status != null) {
      clauses.add('status = ?');
      args.add(status);
    }
    final rows = await db.query(
      'debt_records',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );
    return rows.map(DebtRecord.fromMap).toList();
  }

  Stream<List<DebtRecord>> watchDebtRecords() async* {
    yield await getDebtRecords();
    yield* _debtRecordsController.stream;
  }

  Future<void> addDebtRecord(DebtRecord record) async {
    final db = await database;
    await db.insert(
      'debt_records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _refreshDebtRecords();
    _notifyChange('debt_records');
  }

  Future<void> updateDebtRecord(DebtRecord record) async {
    final db = await database;
    await db.update(
      'debt_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
    await _refreshDebtRecords();
    _notifyChange('debt_records');
  }

  Future<void> deleteDebtRecord(String id) async {
    final db = await database;
    await db.delete('debt_records', where: 'id = ?', whereArgs: [id]);
    await _refreshDebtRecords();
    _notifyChange('debt_records');
  }

  Future<void> settleDebt(
    String id,
    double paymentAmount, {
    DateTime? settledAt,
    BudgetTransaction? settlementTransaction,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'debt_records',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;

      final record = DebtRecord.fromMap(rows.first);
      final nextSettled = (record.settledAmount + paymentAmount)
          .clamp(0, record.amount)
          .toDouble();
      final fullySettled = nextSettled >= record.amount - 0.000001;
      final nextStatus = fullySettled
          ? 'settled'
          : nextSettled > 0
          ? 'partially_settled'
          : 'pending';

      final updated = record.copyWith(
        settledAmount: nextSettled,
        status: nextStatus,
        settledAt: fullySettled ? settledAt ?? DateTime.now() : null,
      );

      await txn.update(
        'debt_records',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );

      if (settlementTransaction != null) {
        await txn.insert(
          'transactions',
          settlementTransaction.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    await _refreshDebtRecords();
    if (settlementTransaction != null) {
      await _refreshTransactions();
    }
    _notifyChange('debt_records');
    if (settlementTransaction != null) {
      _notifyChange('transactions');
    }
  }

  Future<List<Subscription>> getSubscriptions({bool? activeOnly}) async {
    final db = await database;
    final rows = await db.query(
      'subscriptions',
      where: activeOnly == true ? 'is_active = 1' : null,
      orderBy: 'next_due_date ASC',
    );
    return rows.map(Subscription.fromMap).toList();
  }

  Future<List<Subscription>> getUpcomingSubscriptions({
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await database;
    final start = AppDateUtils.startOfDay(
      from ?? DateTime.now(),
    ).millisecondsSinceEpoch;
    final clauses = <String>['is_active = 1', 'next_due_date >= ?'];
    final args = <Object?>[start];
    if (to != null) {
      clauses.add('next_due_date <= ?');
      args.add(to.millisecondsSinceEpoch);
    }
    final rows = await db.query(
      'subscriptions',
      where: clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'next_due_date ASC',
    );
    return rows.map(Subscription.fromMap).toList();
  }

  Stream<List<Subscription>> watchSubscriptions() async* {
    yield await getSubscriptions();
    yield* _subscriptionsController.stream;
  }

  Future<void> addSubscription(Subscription subscription) async {
    final db = await database;
    await db.insert(
      'subscriptions',
      subscription.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _refreshSubscriptions();
    _notifyChange('subscriptions');
  }

  Future<void> updateSubscription(Subscription subscription) async {
    final db = await database;
    await db.update(
      'subscriptions',
      subscription.toMap(),
      where: 'id = ?',
      whereArgs: [subscription.id],
    );
    await _refreshSubscriptions();
    _notifyChange('subscriptions');
  }

  Future<void> deleteSubscription(String id) async {
    final db = await database;
    await db.delete('subscriptions', where: 'id = ?', whereArgs: [id]);
    await _refreshSubscriptions();
    _notifyChange('subscriptions');
  }

  Future<Subscription?> markSubscriptionPaid(
    String id, {
    DateTime? paidAt,
    DateTime? expectedDueDate,
  }) async {
    final db = await database;
    Subscription? updated;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'subscriptions',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;

      final subscription = Subscription.fromMap(rows.first);
      if (!subscription.isActive) return;
      if (expectedDueDate != null &&
          !AppDateUtils.isSameDay(subscription.nextDueDate, expectedDueDate)) {
        return;
      }

      final timestamp = paidAt ?? DateTime.now();
      final nextDueDate = SubscriptionSchedule.nextDueDate(
        subscription.nextDueDate,
        subscription.frequency,
      );
      final transaction = BudgetTransaction(
        id: IdUtils.generate('txn'),
        amount: subscription.amount,
        type: 'expense',
        categoryId: subscription.categoryId,
        paymentModeId: subscription.paymentModeId,
        title: subscription.name,
        note: 'Subscription payment',
        timestamp: timestamp,
        createdAt: timestamp,
      );

      await txn.insert(
        'transactions',
        transaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.update(
        'subscriptions',
        {'next_due_date': nextDueDate.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );
      updated = subscription.copyWith(nextDueDate: nextDueDate);
    });

    if (updated != null) {
      await _refreshSubscriptions();
      await _refreshTransactions();
      _notifyChange('subscriptions');
      _notifyChange('transactions');
    }
    return updated;
  }

  Future<List<StagedSmsTransaction>> getStagedSmsTransactions({
    String? status,
  }) async {
    final db = await database;
    final rows = await db.query(
      'staged_sms_transactions',
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : [status],
      orderBy: 'sms_timestamp DESC',
    );
    return rows.map(StagedSmsTransaction.fromMap).toList();
  }

  Stream<List<StagedSmsTransaction>> watchStagedSms() async* {
    yield await getStagedSmsTransactions();
    yield* _stagedSmsController.stream;
  }

  Future<void> addStagedSms(StagedSmsTransaction transaction) async {
    final db = await database;
    await db.insert(
      'staged_sms_transactions',
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _refreshStagedSms();
    _notifyChange('staged_sms_transactions');
  }

  Future<int> addStagedSmsBatch(List<StagedSmsTransaction> transactions) async {
    if (transactions.isEmpty) return 0;
    final db = await database;
    var inserted = 0;
    await db.transaction((txn) async {
      for (final transaction in transactions) {
        final rowId = await txn.insert(
          'staged_sms_transactions',
          transaction.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (rowId != 0) inserted++;
      }
    });
    if (inserted > 0) {
      await _refreshStagedSms();
      _notifyChange('staged_sms_transactions');
    }
    return inserted;
  }

  Future<StagedSmsTransaction?> getStagedSmsById(String id) async {
    final db = await database;
    final rows = await db.query(
      'staged_sms_transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : StagedSmsTransaction.fromMap(rows.first);
  }

  Future<Set<String>> getPendingStagedSmsIds() async {
    final db = await database;
    final rows = await db.query(
      'staged_sms_transactions',
      columns: ['id'],
      where: 'status = ?',
      whereArgs: ['pending'],
    );
    return rows.map((row) => row['id'] as String).toSet();
  }

  Future<BudgetTransaction?> acceptStagedSms({
    required String stagedSmsId,
    required BudgetTransaction transaction,
    List<DebtRecord> debtRecords = const [],
  }) async {
    final db = await database;
    var accepted = false;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'staged_sms_transactions',
        columns: ['id'],
        where: 'id = ? AND status = ?',
        whereArgs: [stagedSmsId, 'pending'],
        limit: 1,
      );
      if (rows.isEmpty) return;

      await txn.insert(
        'transactions',
        transaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final record in debtRecords) {
        await txn.insert(
          'debt_records',
          record.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.update(
        'staged_sms_transactions',
        {'status': 'accepted'},
        where: 'id = ?',
        whereArgs: [stagedSmsId],
      );
      accepted = true;
    });

    if (accepted) {
      await _refreshTransactions();
      await _refreshDebtRecords();
      await _refreshStagedSms();
      _notifyChange('transactions');
      _notifyChange('debt_records');
      _notifyChange('staged_sms_transactions');
    }
    return accepted ? transaction : null;
  }

  Future<void> updateStagedSms(StagedSmsTransaction transaction) async {
    final db = await database;
    await db.update(
      'staged_sms_transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
    await _refreshStagedSms();
    _notifyChange('staged_sms_transactions');
  }

  Future<void> deleteStagedSms(String id) async {
    final db = await database;
    await db.delete(
      'staged_sms_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    await _refreshStagedSms();
    _notifyChange('staged_sms_transactions');
  }

  Future<void> markStagedSmsStatus(String id, String status) async {
    final db = await database;
    await db.update(
      'staged_sms_transactions',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _refreshStagedSms();
    _notifyChange('staged_sms_transactions');
  }

  Future<StagedSmsTransaction?> findDuplicateStagedSms({
    String? accountRef,
    required double amount,
    required DateTime smsTimestamp,
    Duration tolerance = const Duration(seconds: 5),
  }) async {
    final db = await database;
    final clauses = <String>[
      'extracted_amount = ?',
      'sms_timestamp BETWEEN ? AND ?',
    ];
    final args = <Object?>[
      amount,
      smsTimestamp.subtract(tolerance).millisecondsSinceEpoch,
      smsTimestamp.add(tolerance).millisecondsSinceEpoch,
    ];
    if (accountRef == null || accountRef.isEmpty) {
      clauses.add("(account_ref IS NULL OR account_ref = '')");
    } else {
      clauses.add('account_ref = ?');
      args.add(accountRef);
    }
    final rows = await db.query(
      'staged_sms_transactions',
      where: clauses.join(' AND '),
      whereArgs: args,
      limit: 1,
    );
    return rows.isEmpty ? null : StagedSmsTransaction.fromMap(rows.first);
  }

  Future<List<Budget>> getBudgets() async {
    final db = await database;
    final rows = await db.query(
      'budgets',
      orderBy: 'is_active DESC, created_at DESC',
    );
    return rows.map(Budget.fromMap).toList();
  }

  Future<Budget?> getActiveBudget() async {
    final db = await database;
    final rows = await db.query(
      'budgets',
      where: 'is_active = 1',
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : Budget.fromMap(rows.first);
  }

  Stream<List<Budget>> watchBudgets() async* {
    yield await getBudgets();
    yield* _budgetsController.stream;
  }

  Future<void> addBudget(Budget budget, {bool activate = false}) async {
    final db = await database;
    final shouldActivate = activate || budget.isActive;
    await db.transaction((txn) async {
      if (shouldActivate) {
        await txn.update('budgets', {'is_active': 0});
      }
      final value = shouldActivate ? budget.copyWith(isActive: true) : budget;
      await txn.insert(
        'budgets',
        value.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await _refreshBudgets();
    _notifyChange('budgets');
  }

  Future<void> updateBudget(Budget budget) async {
    final db = await database;
    await db.transaction((txn) async {
      if (budget.isActive) {
        await txn.update(
          'budgets',
          {'is_active': 0},
          where: 'id != ?',
          whereArgs: [budget.id],
        );
      }
      await txn.update(
        'budgets',
        budget.toMap(),
        where: 'id = ?',
        whereArgs: [budget.id],
      );
    });
    await _refreshBudgets();
    _notifyChange('budgets');
  }

  Future<void> setActiveBudget(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('budgets', {'is_active': 0});
      await txn.update(
        'budgets',
        {'is_active': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    await _refreshBudgets();
    _notifyChange('budgets');
  }

  Future<void> deleteBudget(String id) async {
    final db = await database;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
    await _refreshBudgets();
    await _refreshTransactions();
    _notifyChange('budgets');
    _notifyChange('transactions');
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final rows = await db.query('app_settings', orderBy: 'key ASC');
    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  Stream<Map<String, String>> watchSettings() async* {
    yield await getAllSettings();
    yield* _settingsController.stream;
  }

  Future<void> setSetting(
    String key,
    String value, {
    bool notify = true,
  }) async {
    final db = await database;
    await db.insert('app_settings', {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (notify) {
      await _refreshSettings();
      _notifyChange('app_settings');
    }
  }

  Future<void> deleteSetting(String key, {bool notify = true}) async {
    final db = await database;
    await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
    if (notify) {
      await _refreshSettings();
      _notifyChange('app_settings');
    }
  }

  Future<void> clearAllData() async {
    final db = await database;
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
      await _seedDefaults(txn);
    });
    await reloadAllStreams();
    _notifyChange('all');
  }

  Future<void> reloadAllStreams() async {
    _paymentModesController.add(await getPaymentModes());
    _categoriesController.add(await getCategories());
    _transactionsController.add(await getTransactions());
    _contactsController.add(await getContacts());
    _debtRecordsController.add(await getDebtRecords());
    _subscriptionsController.add(await getSubscriptions());
    _stagedSmsController.add(await getStagedSmsTransactions());
    _budgetsController.add(await getBudgets());
    _settingsController.add(await getAllSettings());
  }

  Future<void> _refreshPaymentModes() async {
    _paymentModesController.add(await getPaymentModes());
  }

  Future<void> _refreshCategories() async {
    _categoriesController.add(await getCategories());
  }

  Future<void> _refreshTransactions() async {
    _transactionsController.add(await getTransactions());
  }

  Future<void> _refreshContacts() async {
    _contactsController.add(await getContacts());
  }

  Future<void> _refreshDebtRecords() async {
    _debtRecordsController.add(await getDebtRecords());
  }

  Future<void> _refreshSubscriptions() async {
    _subscriptionsController.add(await getSubscriptions());
  }

  Future<void> _refreshStagedSms() async {
    _stagedSmsController.add(await getStagedSmsTransactions());
  }

  Future<void> _refreshBudgets() async {
    _budgetsController.add(await getBudgets());
  }

  Future<void> _refreshSettings() async {
    _settingsController.add(await getAllSettings());
  }
}
