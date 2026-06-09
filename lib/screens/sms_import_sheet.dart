import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:telephony/telephony.dart';
import '../models/sms_transaction.dart';
import '../models/budget_item.dart';
import '../services/sms_transaction_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';

class SmsImportSheet extends StatefulWidget {
  final String budgetId;
  final List<BudgetExpense> existingExpenses;

  const SmsImportSheet({
    super.key,
    required this.budgetId,
    required this.existingExpenses,
  });

  @override
  State<SmsImportSheet> createState() => _SmsImportSheetState();
}

class _SmsImportSheetState extends State<SmsImportSheet> {
  final SmsTransactionService _service = SmsTransactionService();
  List<SmsMessage>? _rawMessages;
  List<SmsMessage>? _filteredMessages;
  List<SmsTransaction> _newTransactions = [];
  List<SmsTransaction> _duplicates = [];
  bool _loading = true;
  bool _scanning = false;
  bool _importing = false;
  int _importedCount = 0;

  @override
  void initState() {
    super.initState();
    _scanSms();
  }

  Future<void> _scanSms() async {
    setState(() => _scanning = true);
    try {
      final messages = await _service.fetchSmsLast7Days();
      final financial = _service.filterFinancialSms(messages);
      final parsed = _service.parseTransactions(financial);
      final debits = parsed.where((t) => !t.isCredit).toList();
      final duplicates = _service.findDuplicates(debits, widget.existingExpenses);
      final newTxs = debits.where((t) =>
          !duplicates.any((d) => d.id == t.id)).toList();

      if (mounted) {
        setState(() {
          _rawMessages = messages;
          _filteredMessages = financial;
          _newTransactions = newTxs;
          _duplicates = duplicates;
          _loading = false;
          _scanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _scanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _saveLog() async {
    final raw = _rawMessages;
    final filtered = _filteredMessages;
    if (raw == null || filtered == null) return;
    try {
      final path = await _service.saveSmsLog(
        rawMessages: raw,
        filteredMessages: filtered,
        parsedTransactions: _newTransactions,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Log saved'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  Future<void> _importAll() async {
    setState(() => _importing = true);
    try {
      final count = await _service.logTransactions(
        widget.budgetId,
        _newTransactions,
      );
      if (mounted) {
        setState(() {
          _importedCount = count;
          _importing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported $count transactions'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _importing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child:                 Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Import from SMS',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.save_alt_rounded, color: AppTheme.textSecondary, size: 20),
                          onPressed: _loading ? null : _saveLog,
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryLight),
                          onPressed: _scanning ? null : _scanSms,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12),
              // Body
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(24),
                        children: [
                          if (_scanning)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: Row(
                                children: [
                                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                  SizedBox(width: 12),
                                  Text('Scanning SMS...', style: TextStyle(color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),

                          // Duplicates section
                          if (_duplicates.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.warningColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${_duplicates.length} possible duplicate(s)',
                                        style: const TextStyle(color: AppTheme.warningColor, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ..._duplicates.map((d) => _buildDuplicateItem(d)),
                                ],
                              ),
                            ),
                            const VGapMd(),
                          ],

                          if (_newTransactions.isEmpty && !_scanning)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Text(
                                  'No new transactions found\nin the last 7 days.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppTheme.textSecondary),
                                ),
                              ),
                            ),

                          // New transactions
                          ..._newTransactions.map((tx) => _buildTransactionItem(tx)),
                        ],
                      ),
              ),
              // Bottom bar
              if (_newTransactions.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  child: ElevatedButton(
                    onPressed: _importing ? null : _importAll,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _importing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            _importedCount > 0
                                ? 'Imported $_importedCount'
                                : 'Import ${_newTransactions.length} transaction(s)',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionItem(SmsTransaction tx) {
    final dateStr = DateFormat('d MMM, h:mm a').format(tx.date);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: (tx.isCredit ? AppTheme.successColor : AppTheme.primaryColor).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                tx.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: tx.isCredit ? AppTheme.successColor : AppTheme.primaryLight,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(dateStr, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
              ],
            ),
          ),
          Text(
            '${tx.isCredit ? '+' : '-'}₹${tx.amount.toStringAsFixed(1)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: tx.isCredit ? AppTheme.successColor : AppTheme.errorColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicateItem(SmsTransaction tx) {
    final dateStr = DateFormat('d MMM, h:mm a').format(tx.date);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppTheme.warningColor, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '₹${tx.amount.toStringAsFixed(1)} - ${tx.description} ($dateStr)',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
