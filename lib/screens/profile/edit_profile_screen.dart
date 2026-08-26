import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/common_widgets.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  final AppUser user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.user.fullName);
  late final _phoneController = TextEditingController(text: widget.user.phone);
  late String? _photoPath = widget.user.photoPath;
  bool _saving = false;
  bool _pickingPhoto = false;

  static final _phoneRegex = RegExp(r'^0\d{1,2}-?\d{7,8}$');

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final updated = widget.user.copyWith(
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      photoPath: _photoPath,
      clearPhoto: _photoPath == null,
    );
    await AuthService.instance.updateUser(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(updated);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    Navigator.of(context).pop(); // close the bottom sheet
    setState(() => _pickingPhoto = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;

      // Copy into permanent app storage so it survives cache clears and
      // the picker's temp file being deleted.
      final dir = await getApplicationDocumentsDirectory();
      final ext = p.extension(picked.path);
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}$ext';
      final savedFile = await File(picked.path).copy(p.join(dir.path, fileName));

      if (!mounted) return;
      setState(() => _photoPath = savedFile.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not set photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  void _removePhoto() {
    Navigator.of(context).pop();
    setState(() => _photoPath = null);
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take a photo'),
              onTap: () => _pickPhoto(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => _pickPhoto(ImageSource.gallery),
            ),
            if (_photoPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                title: const Text('Remove photo', style: TextStyle(color: AppColors.danger)),
                onTap: _removePhoto,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Edit Profile'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: _pickingPhoto
                  ? const SizedBox(
                      width: 92,
                      height: 92,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : ProfileAvatar(
                      photoPath: _photoPath,
                      radius: 46,
                      onEditTap: _showPhotoOptions,
                    ),
            ),
            const SizedBox(height: 24),
            LabeledField(
              label: 'Full Name',
              controller: _nameController,
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'Enter your full name' : null,
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Email', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(widget.user.email)),
                      const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'Phone Number',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Phone number is required';
                if (!_phoneRegex.hasMatch(v.trim())) return 'Enter a valid phone number';
                return null;
              },
            ),
            const SizedBox(height: 26),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
