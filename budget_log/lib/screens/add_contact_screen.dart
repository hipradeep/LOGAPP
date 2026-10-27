import 'package:flutter/material.dart';

import '../controllers/contacts_controller.dart';
import '../models/contact.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/custom_app_bar.dart';

class AddContactScreen extends StatefulWidget {
  final Contact? existingContact;

  const AddContactScreen({super.key, this.existingContact});

  static Future<void> navigate(
    BuildContext context, {
    Contact? existingContact,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AddContactScreen(existingContact: existingContact),
      ),
    );
  }

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _upiController = TextEditingController();

  late int _avatarColorIndex;
  bool _isSaving = false;
  bool _isDeleting = false;

  ContactsController get _controller => getIt<ContactsController>();
  bool get _isEditing => widget.existingContact != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingContact;
    _nameController.text = existing?.name ?? '';
    _phoneController.text = existing?.phone ?? '';
    _upiController.text = existing?.upiId ?? '';
    _avatarColorIndex = existing?.avatarColorIndex ?? 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final existing = widget.existingContact;
      if (existing == null) {
        await _controller.createContact(
          name: _nameController.text,
          phone: _phoneController.text,
          upiId: _upiController.text,
          avatarColorIndex: _avatarColorIndex,
        );
      } else {
        await _controller.updateContact(
          existing.copyWith(
            name: _nameController.text,
            phone: _phoneController.text,
            upiId: _upiController.text,
            avatarColorIndex: _avatarColorIndex,
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Contact updated' : 'Contact added'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save contact: $error')),
      );
    }
  }

  Future<void> _delete() async {
    final existing = widget.existingContact;
    if (existing == null) return;
    final confirmed = await ConfirmationDialog.showDelete(
      context,
      entityName: 'contact',
      message: 'All ledger entries for ${existing.name} will also be removed.',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isDeleting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _controller.deleteContact(existing.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('Contact deleted')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete contact: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: _isEditing ? 'Edit contact' : 'New contact',
              subtitle: _isEditing
                  ? 'Update details or remove this person.'
                  : 'Add someone you lend to or borrow from.',
              actions: [
                if (_isEditing)
                  IconButton(
                    onPressed: _isDeleting ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: AppTheme.errorColor,
                    tooltip: 'Delete contact',
                  ),
              ],
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacingMd,
                    AppTheme.spacingSm,
                    AppTheme.spacingMd,
                    AppTheme.spacingXl,
                  ),
                  children: [
                    Center(
                      child: _AvatarPreview(
                        name: _nameController.text,
                        colorIndex: _avatarColorIndex,
                      ),
                    ),
                    const VGapLg(),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      autofocus: !_isEditing,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'Friend, family, colleague...',
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Enter a name';
                        }
                        return null;
                      },
                    ),
                    const VGapMd(),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        hintText: 'Optional',
                      ),
                    ),
                    const VGapMd(),
                    TextFormField(
                      controller: _upiController,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'UPI ID',
                        hintText: 'name@bank',
                      ),
                    ),
                    const VGapLg(),
                    Text('Avatar tint', style: textTheme.titleMedium),
                    const VGapSm(),
                    Wrap(
                      spacing: AppTheme.spacingSm,
                      runSpacing: AppTheme.spacingSm,
                      children: List.generate(AppTheme.tintCount, (index) {
                        final selected = index == _avatarColorIndex;
                        final tint = AppTheme.tintFor(context, index);
                        return InkWell(
                          onTap: () {
                            setState(() => _avatarColorIndex = index);
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: tint.$1,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? AppTheme.primaryColor
                                    : tint.$3,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: selected
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: tint.$2,
                                  )
                                : null,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(
                AppTheme.spacingMd,
                AppTheme.spacingSm,
                AppTheme.spacingMd,
                AppTheme.spacingSm,
              ),
              child: SizedBox(
                width: double.infinity,
                height: AppTheme.buttonHeight,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(_isEditing ? 'Save changes' : 'Add contact'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  final String name;
  final int colorIndex;

  const _AvatarPreview({required this.name, required this.colorIndex});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'))
      ..removeWhere((part) => part.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final tint = AppTheme.tintFor(context, colorIndex);
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: tint.$1,
        shape: BoxShape.circle,
        border: Border.all(color: tint.$3),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: tint.$2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
