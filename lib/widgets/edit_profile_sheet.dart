import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

class EditProfileSheet extends StatefulWidget {
  final String initialName;
  final String initialAvatar;
  final Function(String name, String avatar) onSave;

  const EditProfileSheet({
    super.key,
    required this.initialName,
    required this.initialAvatar,
    required this.onSave,
  });

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _nameController;
  late String _selectedAvatar;

  static const List<String> _avatarOptions = [
    '🦁', '🦊', '🐼', '🐨', '🦖', '🚀', '💻', '🧠', '⚡', '🌟', '🎨', '✈️'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _selectedAvatar = widget.initialAvatar;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const VGapMd(),
          Text('Edit Profile', style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold)),
          const VGapMd(),
          
          // Username Field
          Text('Display Name', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold)),
          const VGapSm(),
          TextField(
            controller: _nameController,
            maxLength: 18,
            style: AppTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'Enter your name',
              counterText: '',
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const VGapMd(),

          // Avatar Pick
          Text('Choose Avatar', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold)),
          const VGapSm(),
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _avatarOptions.length,
              itemBuilder: (context, idx) {
                final avatar = _avatarOptions[idx];
                final isSelected = avatar == _selectedAvatar;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedAvatar = avatar;
                    });
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    margin: const EdgeInsets.only(right: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppTheme.primaryColor.withValues(alpha: 0.2) 
                          : Colors.white.withValues(alpha: 0.04),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Text(avatar, style: const TextStyle(fontSize: 24)),
                  ),
                );
              },
            ),
          ),
          const VGapLg(),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: AppTheme.buttonHeight,
            child: ElevatedButton(
              onPressed: () {
                final newName = _nameController.text.trim();
                if (newName.isNotEmpty) {
                  widget.onSave(newName, _selectedAvatar);
                }
                Navigator.pop(context);
              },
              child: const Text('Save Profile'),
            ),
          ),
        ],
      ),
    );
  }
}
