import 'dart:io';
import 'dart:convert';

import 'package:image/image.dart' as img;

// Run from the repository root: dart run tool/generate_app_icons.dart
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
    img.fill(canvas, color: img.ColorRgb8(18, 54, 74));
    // The supplied badge already has transparent margins. At 88% its opaque
    // artwork remains within radius 0.38 of the canvas (the safe radius is
    // 0.40), without shrinking the entire square into the safe circle again.
    final artwork = img.copyResize(
      source,
      width: (size * 0.88).floor(),
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
  File('web/favicon.png').writeAsBytesSync(
    img.encodePng(
      img.copyResize(
        source,
        width: 48,
        interpolation: img.Interpolation.average,
      ),
    ),
  );
  // Let browsers refresh the previous small/masked icons after deployment.
  final manifestFile = File('web/manifest.json');
  final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map;
  for (final icon in manifest['icons'] as List) {
    icon['src'] = '${(icon['src'] as String).split('?').first}?v=2';
  }
  manifestFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('    ').convert(manifest)}\n',
  );
}
