import 'dart:developer' as developer;
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'cache_service.dart';

@pragma('vm:entry-point')
void onNotificationCallback(NotificationEvent event) {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  NotificationTransactionService.handleNotificationEvent(event);
}

class NotificationTransactionService {
  static const String _logName = 'NotificationTxService';
  static const _channel = MethodChannel('com.pradeepapp.log/sms_scanner');
  
  // Package name whitelists to focus on (SMS apps and major UPI/payment apps in India)
  static const List<String> _whitelistedPackages = [
    'com.google.android.apps.messaging', // Google Messages
    'com.samsung.android.messaging',      // Samsung Messages
    'com.android.mms',                    // Xiaomi/AOSP MMS
    'com.google.android.apps.nbu.paisa.user', // Google Pay
    'com.phonepe.app',                     // PhonePe
    'net.one97.paytm',                     // Paytm
    'com.hdfc.customers',                  // HDFC Bank
    'com.csam.icici.bank.imobile',         // ICICI iMobile
    'com.sbi.lotusintouch',                // SBI YONO
    'com.axis.mobile',                     // Axis Bank
    'com.kotak.mahindra.kotak',            // Kotak Bank
    'com.rbl.rblbank',                     // RBL Bank
    'in.finacle.canara',                   // Canara Bank
    'com.pradeepapp.log',                  // LOG App (for test/dummy transactions)
  ];

  static const _tagKeywords = {
    'Bill': ['bill', 'recharge', 'electricity', 'water', 'internet', 'dth', 'mobile recharge', 'broadband'],
    'Dinner': ['restaurant', 'cafe', 'dinner', 'lunch', 'food', 'zomato', 'swiggy', 'eat', 'pizza', 'burger'],
    'Drink': ['drink', 'bar', 'beer', 'wine', 'coffee', 'tea', 'chai', 'starbucks'],
    'Fuel': ['fuel', 'petrol', 'diesel', 'gas', 'indian oil', 'hpcl', 'bpcl', 'shell'],
    'Grocery': ['grocery', 'supermarket', 'dmart', 'bigbasket', 'reliance fresh', 'zepto', 'blinkit', 'instamart'],
    'Shopping': ['amazon', 'flipkart', 'myntra', 'shopping', 'meesho', 'ajio', 'nykaa', 'purchase'],
    'Health': ['medical', 'hospital', 'pharmacy', 'doctor', 'medicine', 'apollo', 'health', 'clinic'],
    'Snack': ['snack', 'fast food', 'mcdonald', 'kfc', 'domino', 'subway', 'chaat'],
    'Travel': ['flight', 'travel', 'train', 'uber', 'ola', 'rapido', 'bus', 'metro', 'cab', 'irctc', 'make my trip'],
  };

  /// Check if the app currently has Notification Access permission
  static Future<bool> isPermissionGranted() async {
    try {
      final granted = await NotificationsListener.hasPermission ?? false;
      return granted;
    } catch (e) {
      developer.log('Error checking permission: $e', name: _logName);
      return false;
    }
  }

  /// Request Notification Access by redirecting user to system settings
  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('openNotificationListenerSettings');
    } catch (e) {
      developer.log('Error opening settings via MethodChannel: $e. Falling back to listener openPermissionSettings...', name: _logName);
      try {
        await NotificationsListener.openPermissionSettings();
      } catch (ex) {
        developer.log('Error opening permission settings: $ex', name: _logName);
      }
    }
  }

  /// Initialize the listener and start background service
  static Future<void> startService() async {
    try {
      final isEnabled = await CacheService().getNotificationScannerEnabled();
      if (!isEnabled) {
        developer.log('Notification scanner is disabled in settings. Skipping start.', name: _logName);
        return;
      }

      final hasPermission = await isPermissionGranted();
      if (!hasPermission) {
        developer.log('Cannot start service: Permission not granted.', name: _logName);
        return;
      }

      final isRunning = await NotificationsListener.isRunning ?? false;
      if (isRunning) {
        developer.log('Service is already running. Skipping start.', name: _logName);
        return;
      }

      await NotificationsListener.initialize(callbackHandle: onNotificationCallback);
      await NotificationsListener.startService(
        foreground: true,
        title: 'LOG Transaction Scanner',
        description: 'Scanning active notifications for banking alerts...',
      );

      developer.log('Notification listener service started successfully.', name: _logName);
    } catch (e) {
      developer.log('Error starting service: $e', name: _logName);
    }
  }

  /// Stop the listener background service
  static Future<void> stopService() async {
    try {
      await NotificationsListener.stopService();
      developer.log('Notification listener service stopped.', name: _logName);
    } catch (e) {
      developer.log('Error stopping service: $e', name: _logName);
    }
  }

  /// Main handler invoked inside the background isolate whenever a notification is intercepted
  static Future<void> handleNotificationEvent(NotificationEvent event) async {
    final packageName = event.packageName ?? '';
    final title = event.title ?? '';
    final text = event.text ?? '';
    
    // 1. Filter packages: check if it is a whitelisted app or has message/bank components
    final isMatchingPackage = _whitelistedPackages.contains(packageName) || 
        packageName.contains('message') || 
        packageName.contains('messaging') || 
        packageName.contains('mms') ||
        packageName.contains('telephony') ||
        packageName.contains('wallet') ||
        packageName.contains('bank');

    if (!isMatchingPackage) {
      return;
    }

    final lowerBody = text.toLowerCase();
    
    // 2. Perform transaction filters (reusing original logic)
    if (_isPromotional(lowerBody)) {
      return;
    }

    if (!_isTransactionText(lowerBody)) {
      return;
    }

    final amount = _extractAmount(text);
    if (amount == null || amount <= 0) {
      return;
    }

    final isCredit = _isCreditText(lowerBody);
    final sender = title.isNotEmpty ? title : 'Alert';
    final description = _extractDescription(lowerBody, sender);
    final tag = getTagForDescription(description);

    developer.log('INTERCEPTED TRANSACTION: Amount=₹$amount, Type=${isCredit ? "CREDIT" : "DEBIT"}, Sender=$sender, Desc=$description', name: _logName);

    try {
      // 3. Initialize Firebase inside background isolate if not loaded
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp(
            options: const FirebaseOptions(
              apiKey: 'AIzaSyCRscOIxEaSnmztsF0DHGrm8sZNa6dEjec',
              appId: '1:1093748425101:android:b5d45281b53d038ff3fdc4',
              messagingSenderId: '1093748425101',
              projectId: 'logapp-c7867',
              storageBucket: 'logapp-c7867.firebasestorage.app',
            ),
          );
        } catch (e) {
          developer.log('Firebase initialization failed in background isolate: $e', name: _logName);
          return;
        }
      }

      if (Firebase.apps.isEmpty) {
        developer.log('Firebase has no active apps after init. Aborting notification insert.', name: _logName);
        return;
      }

      // 4. Fetch the active budget document
      var budgetsQuery = await FirebaseFirestore.instance
          .collection('budgets')
          .where('checked', isEqualTo: true)
          .limit(1)
          .get();

      if (budgetsQuery.docs.isEmpty) {
        developer.log('No checked budget found. Falling back to the first available budget...', name: _logName);
        budgetsQuery = await FirebaseFirestore.instance
            .collection('budgets')
            .limit(1)
            .get();
      }

      if (budgetsQuery.docs.isEmpty) {
        developer.log('No budget category found at all. Aborting notification insert.', name: _logName);
        return;
      }

      final activeDoc = budgetsQuery.docs.first;
      final budgetCategoryName = activeDoc.data()['category'] as String? ?? 'Active Budget';
      
      // 5. Add direct transaction document to 'transactions' collection
      await FirebaseFirestore.instance.collection('transactions').add({
        'budgetId': activeDoc.id,
        'tag': tag,
        'description': description,
        'amount': isCredit ? -amount : amount,
        'entryDate': Timestamp.fromDate(DateTime.now()),
        'expenseDate': Timestamp.fromDate(DateTime.now()), // defaults to entry date
        'isValidated': false,
        'rawBody': '$title: $text',
      });

      developer.log('Successfully auto-inserted transaction into budget category: $budgetCategoryName', name: _logName);
    } catch (e) {
      developer.log('Error inserting background notification transaction: $e', name: _logName);
    }
  }

  // ==================== PARSING HELPER METHODS ====================

  static bool _isPromotional(String body) {
    return body.contains('personal loan') ||
        body.contains('home loan') ||
        body.contains('car loan') ||
        body.contains('loan amount') ||
        (body.contains('up to') && body.contains('loan')) ||
        body.contains('pre-approved') ||
        body.contains('preapproved') ||
        body.contains('apply now') ||
        body.contains('apply today') ||
        body.contains('quick approval') ||
        body.contains('limited period') ||
        body.contains('hurry') ||
        body.contains('exclusive offer') ||
        body.contains('get up to') ||
        body.contains('avail ') ||
        body.contains('check eligibility') ||
        body.contains('upgrade your') ||
        (body.contains('interest') && body.contains('rate')) ||
        (body.contains('reward') && body.contains('point')) ||
        body.contains('demat') ||
        body.contains('mutual fund') ||
        body.contains('fixed deposit') ||
        body.contains('recurring deposit') ||
        body.contains('forex');
  }

  static bool _isTransactionText(String body) {
    return body.contains('rs.') ||
        body.contains('inr') ||
        body.contains('₹') ||
        body.contains('debited') ||
        body.contains('credited') ||
        body.contains('spent') ||
        body.contains('paid') ||
        body.contains('purchase') ||
        body.contains('withdrawal') ||
        body.contains('withdrawn') ||
        body.contains('transfer') ||
        body.contains('transaction') ||
        body.contains('trf') ||
        body.contains('ref no') ||
        body.contains('ref:') ||
        body.contains('utr') ||
        body.contains('emi') ||
        (body.contains('a/c') && (body.contains('debited') || body.contains('credited')));
  }

  static double? _extractAmount(String body) {
    final patterns = [
      RegExp(r'rs\.?\s*([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(r'inr\s*([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(r'₹\s*([\d,]+\.?\d*)'),
      RegExp(r'amount\s+[a-z]+\s+([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(r'([\d,]+\.?\d*)\s*(?:rs|inr)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        final parsed = double.tryParse(match.group(1)!.replaceAll(',', ''));
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    return null;
  }

  static bool _isCreditText(String body) {
    if (body.contains('debited')) return false;
    return body.contains('credited') ||
        body.contains('received') ||
        body.contains('deposited') ||
        body.contains('refund') ||
        body.contains('cashback');
  }

  static String _extractDescription(String body, String sender) {
    final lower = body.toLowerCase();
    for (final entry in _tagKeywords.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          return '${entry.key} - $sender';
        }
      }
    }
    return sender;
  }

  static String getTagForDescription(String description) {
    final lower = description.toLowerCase();
    for (final entry in _tagKeywords.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) return entry.key;
      }
    }
    return 'Other';
  }
}
