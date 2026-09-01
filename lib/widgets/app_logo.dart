import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// EV Connect brand icon
class AppLogoMark extends StatelessWidget {
  final double size;
  final Color? pinColor; // unused now (real artwork has fixed brand colour); kept for API compatibility
  final Color background;

  const AppLogoMark({
    super.key,
    this.size = 36,
    this.pinColor,
    this.background = Colors.transparent,
  });

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/logo_icon.png',
      fit: BoxFit.contain,
    );
    final content = background == Colors.transparent
        ? image
        : Container(color: background, child: image);

    if (size.isInfinite) {
      return SizedBox.expand(child: content);
    }
    return SizedBox(width: size, height: size, child: content);
  }
}

class AppLogoFull extends StatelessWidget {
  final double iconSize;
  final bool showTagline; // kept for API compatibility; tagline is baked into the artwork
  final bool light; // true = place on a white card (for dark backgrounds)

  const AppLogoFull({
    super.key,
    this.iconSize = 96,
    this.showTagline = true,
    this.light = true,
  });

  @override
  Widget build(BuildContext context) {
    final width = iconSize * 2.6;
    final image = Image.asset(
      'assets/images/logo_full_trimmed.png',
      width: width,
      fit: BoxFit.contain,
    );

    if (!light) return image;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: width * 0.09, vertical: width * 0.07),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(iconSize * 0.26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: image,
    );
  }
}
