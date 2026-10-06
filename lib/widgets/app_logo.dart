import 'package:flutter/material.dart';

/// The supplied brand artwork; adjacent headings provide its accessible name.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 160});

  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size / 10),
    child: Image.asset(
      'assets/branding/respondcrew-logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      // Mipmapped sampling preserves thin lines when reducing the 1024px
      // artwork. `high` uses bicubic sampling and aliases at these scales.
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    ),
  );
}
