import 'package:flutter/material.dart';

/// The supplied brand artwork; adjacent headings provide its accessible name.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 160});

  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size / 10),
    child: Image.asset(
      size <= 64
          ? 'assets/branding/compact/logo.png'
          : 'assets/branding/display/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      // Pre-sized density variants avoid reducing the 1024px master by a
      // large factor in the browser. Medium handles any remaining scaling.
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    ),
  );
}
