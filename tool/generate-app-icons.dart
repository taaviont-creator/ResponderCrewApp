import 'dart:io';

import 'package:image/image.dart' as img;

// Run from the repository root: dart run tool/generate-app-icons.dart
Future<void> main() async {
  final project = File('ios/Runner.xcodeproj/project.pbxproj');
  final originalProject = project.readAsBytesSync();
  try {
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'flutter_launcher_icons',
    ]);
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode != 0) {
      exitCode = result.exitCode;
      return;
    }
  } finally {
    // The existing AppIcon catalog is already wired up. Version 0.14.4 also
    // rewrites unrelated ASSETCATALOG settings; retain all project settings.
    project.writeAsBytesSync(originalProject);
  }

  final source = img.decodePng(
    File('assets/branding/respondcrew-logo.png').readAsBytesSync(),
  )!;
  for (final size in [192, 512]) {
    final canvas = img.Image(width: size, height: size);
    img.fill(canvas, color: img.ColorRgb8(58, 62, 63));
    // Keep the entire supplied square inside the maskable icon's safe circle.
    final artwork = img.copyResize(
      source,
      width: (size * 0.56).floor(),
      interpolation: img.Interpolation.average,
    );
    img.compositeImage(
      canvas,
      artwork,
      dstX: (size - artwork.width) ~/ 2,
      dstY: (size - artwork.height) ~/ 2,
    );
    File(
      'web/icons/Icon-maskable-$size.png',
    ).writeAsBytesSync(img.encodePng(canvas));
  }
  // Browsers downsample this higher resolution source for their tab icon.
  File(
    'web/favicon.png',
  ).writeAsBytesSync(img.encodePng(img.copyResize(source, width: 48)));
}
