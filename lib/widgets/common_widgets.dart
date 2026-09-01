import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final String? hintText;
  final String? helperText;
  final String? suffixText;

  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.inputFormatters,
    this.maxLines = 1,
    this.hintText,
    this.helperText,
    this.suffixText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : AppColors.textDark)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          style: const TextStyle(color: AppColors.textDark),
          decoration: InputDecoration(
            suffixIcon: suffixIcon,
            suffixText: suffixText,
            hintText: hintText,
            hintStyle: const TextStyle(color: AppColors.textMuted),
            helperText: helperText,
            helperMaxLines: 2,
            helperStyle: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// Rounded action tile used for quick actions and settings rows.
class RoundedActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;

  const RoundedActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.background = AppColors.primaryPale,
    this.foreground = AppColors.primaryDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: foreground),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  final String? photoPath;
  final double radius;
  final VoidCallback? onEditTap;

  const ProfileAvatar({
    super.key,
    required this.photoPath,
    this.radius = 34,
    this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    ImageProvider? image;
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('data:')) {
        try {
          final base64Part = path.substring(path.indexOf(',') + 1);
          image = MemoryImage(base64Decode(base64Part));
        } catch (_) {
          // Corrupted/malformed data URI — fall through to the icon
          // rather than crashing the screen.
        }
      } else if (path.startsWith('http')) {
        image = NetworkImage(path);
      } else {
        final file = File(path);
        if (file.existsSync()) image = FileImage(file);
      }
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.primaryLight,
          backgroundImage: image,
          onBackgroundImageError: image == null
              ? null
              : (_, __) {
                  // e.g. a stale/unreachable legacy network URL
                },
          child: image == null
              ? Icon(Icons.person_rounded, size: radius * 1.1, color: Colors.white)
              : null,
        ),
        if (onEditTap != null)
          Positioned(
            right: -2,
            bottom: -2,
            child: Material(
              color: AppColors.primaryDark,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onEditTap,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Small chip used for connector types (Type 2, CCS2, CHAdeMO...)
class Tag extends StatelessWidget {
  final String label;
  const Tag(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: Theme.of(context).textTheme.titleLarge),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class SocialSignInButtons extends StatelessWidget {
  final bool loading;
  final VoidCallback onGoogleTap;

  const SocialSignInButtons({
    super.key,
    required this.loading,
    required this.onGoogleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: const [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('or continue with',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: loading ? null : onGoogleTap,
          icon: const _GoogleGlyph(),
          label: const Text('Continue with Google'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textDark,
            side: const BorderSide(color: Color(0xFFDDDDDD)),
          ),
        ),
      ],
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: Text(
        'G',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 16,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }
}
