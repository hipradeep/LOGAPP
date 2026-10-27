import 'dart:io';

import 'package:budget_log/controllers/contacts_controller.dart';
import 'package:budget_log/controllers/debt_controller.dart';
import 'package:budget_log/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDirectory;
  late DatabaseService databaseService;
  late ContactsController contactsController;
  late DebtController debtController;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('debt_test_');
    databaseService = DatabaseService(
      factory: databaseFactoryFfi,
      path: path.join(tempDirectory.path, 'budget_log.db'),
    );
    await databaseService.init();
    contactsController = ContactsController(
      dbService: databaseService,
      watchDatabase: false,
    );
    debtController = DebtController(
      dbService: databaseService,
      watchDatabase: false,
    );
    await contactsController.load();
    await debtController.load();
  });

  tearDown(() async {
    contactsController.dispose();
    debtController.dispose();
    await databaseService.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('creates, updates, and removes contacts', () async {
    final contact = await contactsController.createContact(
      name: '  Alex  ',
      phone: ' 9876543210 ',
      upiId: 'alex@upi',
      avatarColorIndex: 2,
    );

    expect(contactsController.contacts, hasLength(1));
    expect(contact.name, 'Alex');
    expect(contact.phone, '9876543210');
    expect(contactsController.contactById(contact.id)?.upiId, 'alex@upi');

    await contactsController.updateContact(contact.copyWith(name: 'Alex Doe'));
    expect(contactsController.contactById(contact.id)?.name, 'Alex Doe');

    await contactsController.deleteContact(contact.id);
    expect(contactsController.contacts, isEmpty);
  });

  test('tracks given and taken balances with partial settlements', () async {
    final alex = await contactsController.createContact(name: 'Alex');
    final sam = await contactsController.createContact(name: 'Sam');

    final lent = await debtController.addDebt(
      contactId: alex.id,
      direction: 'give',
      amount: 1000,
      notes: 'Dinner',
    );
    await debtController.addDebt(
      contactId: sam.id,
      direction: 'take',
      amount: 400,
    );

    expect(debtController.totalGiven, 1000);
    expect(debtController.totalTaken, 400);
    expect(debtController.netBalance, 600);
    expect(debtController.netForContact(alex.id), 1000);
    expect(debtController.netForContact(sam.id), -400);
    expect(debtController.outstandingCountForContact(alex.id), 1);

    await debtController.settleDebt(
      record: lent,
      contact: alex,
      amount: 400,
      paymentModeId: 'pm_upi',
    );

    expect(debtController.totalGiven, 600);
    expect(debtController.netForContact(alex.id), 600);
    expect(
      debtController.recordsForContact(alex.id).single.status,
      'partially_settled',
    );

    var transactions = await databaseService.getTransactions();
    expect(transactions, hasLength(1));
    expect(transactions.single.type, 'income');
    expect(transactions.single.amount, 400);

    final samRecord = debtController.recordsForContact(sam.id).single;
    await debtController.settleDebt(
      record: samRecord,
      contact: sam,
      amount: 400,
      paymentModeId: 'pm_cash',
    );

    expect(debtController.totalTaken, 0);
    expect(debtController.netBalance, 600);
    transactions = await databaseService.getTransactions();
    expect(transactions, hasLength(2));
    expect(
      transactions.firstWhere((item) => item.type == 'expense').amount,
      400,
    );
  });

  test('removing a contact cascades its ledger records', () async {
    final alex = await contactsController.createContact(name: 'Alex');
    await debtController.addDebt(
      contactId: alex.id,
      direction: 'give',
      amount: 250,
    );
    expect(debtController.records, hasLength(1));

    await contactsController.deleteContact(alex.id);
    await debtController.reload();
    expect(debtController.records, isEmpty);
    expect(debtController.totalGiven, 0);
  });
}
