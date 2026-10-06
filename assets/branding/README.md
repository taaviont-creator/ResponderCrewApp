# RespondCrew logo

`respondcrew-logo.png` is the original logo supplied by the project owner.
Keep this master unchanged; the login screen and desktop navigation use it.

Regenerate Android, iOS, Windows and web icons from the repository root:

```sh
flutter pub get
dart run tool/generate_app_icons.dart
```

Use this wrapper rather than invoking the launcher generator directly: it
preserves the existing Xcode settings and fits the complete artwork inside the
web maskable icon safe area. The Android notification icon is a separate white
anchor (`ic_stat_respondcrew`), because status bars require a silhouette.

Installed native apps receive the icons with their next app update.
