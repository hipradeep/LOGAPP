import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../models/contact.dart';
import '../services/database_service.dart';
import '../utils/id_utils.dart';

class ContactsController extends ChangeNotifier {
  ContactsController({DatabaseService? dbService, bool watchDatabase = true})
    : _dbService = dbService ?? DatabaseService.instance {
    if (watchDatabase) {
      _changeSubscription = _dbService.onDatabaseChanged.listen((_) {
        if (_isDisposed) return;
        _reloadTimer?.cancel();
        _reloadTimer = Timer(
          const Duration(milliseconds: 150),
          () => unawaited(reload()),
        );
      });
    }
  }

  final DatabaseService _dbService;

  StreamSubscription<String>? _changeSubscription;
  Timer? _reloadTimer;
  Future<void>? _reloadFuture;
  bool _reloadQueued = false;
  bool _isDisposed = false;
  bool _isLoading = true;

  List<Contact> _contacts = const [];
  final Map<String, Contact> _contactById = {};

  bool get isLoading => _isLoading;
  List<Contact> get contacts => _contacts;

  Contact? contactById(String? id) => id == null ? null : _contactById[id];

  Future<void> load() async {
    _reloadTimer?.cancel();
    await reload();
  }

  Future<void> reload() async {
    if (_isDisposed) return;
    if (_reloadFuture != null) {
      _reloadQueued = true;
      return _reloadFuture;
    }

    final future = _performLoad();
    _reloadFuture = future;
    try {
      await future;
    } finally {
      _reloadFuture = null;
      if (_reloadQueued && !_isDisposed) {
        _reloadQueued = false;
        await reload();
      }
    }
  }

  Future<void> _performLoad() async {
    final contacts = await _dbService.getContacts();
    if (_isDisposed) return;

    _contacts = contacts;
    _contactById
      ..clear()
      ..addEntries(contacts.map((item) => MapEntry(item.id, item)));
    _isLoading = false;
    notifyListeners();
  }

  Future<Contact> createContact({
    required String name,
    String? phone,
    String? upiId,
    int avatarColorIndex = 0,
  }) async {
    final contact = Contact(
      id: IdUtils.generate('contact'),
      name: name.trim(),
      phone: _clean(phone),
      upiId: _clean(upiId),
      avatarColorIndex: avatarColorIndex,
      createdAt: DateTime.now(),
    );
    await _dbService.addContact(contact);
    await reload();
    return contact;
  }

  Future<void> updateContact(Contact contact) async {
    await _dbService.updateContact(
      contact.copyWith(
        name: contact.name.trim(),
        phone: _clean(contact.phone),
        upiId: _clean(contact.upiId),
      ),
    );
    await reload();
  }

  Future<void> deleteContact(String id) async {
    await _dbService.deleteContact(id);
    await reload();
  }

  String? _clean(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _reloadTimer?.cancel();
    _changeSubscription?.cancel();
    super.dispose();
  }
}
