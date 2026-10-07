/// Product rollout switches, not authorization. Server-side grants still apply.
abstract final class ReleaseFeatures {
  // Organization-led launch. Enable only in an explicitly prepared center pilot.
  static const centers = bool.fromEnvironment(
    'RESPONDCREW_CENTERS_ENABLED',
    defaultValue: false,
  );
}
