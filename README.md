# Beatter

Beatter is a premium rhythm-training app built with Flutter, aimed primarily at
drummers (with support for other musicians planned). It's designed to feel
like a focused, professional practice tool — closer to Pro Metronome or
Ableton Note than a casual game.

## Features

- **Flow Mode** — a rhythm sight-reading trainer. Generates a phrase of
  configurable length from a pool of rhythmic figures (eighth notes, sixteenths,
  triplets, rests, …), plays it on a loop at a settable BPM/time signature with
  an optional metronome click, and highlights the current figure in real time
  so you can read and play along. Includes an auto-generate mode that swaps in
  a new random figure on a timer to keep varying the exercise.
- **Composer Mode** — a full music editor: tap to place notes on a real
  5-line staff, drag to change pitch, pick note duration from a toolbar, set
  tempo/time signature, undo/redo, and save/rename/duplicate compositions to a
  personal library.
- **Sheet Mode** — browse a built-in library of rhythm patterns and your own
  saved compositions on a read-only staff view with playback.
- **Admin tools** — an internal dashboard and a 16-step pattern creator for
  authoring the rhythm/pattern content the app ships with.

Login supports two roles (User / Admin) against a mock in-memory auth service
— there's no real backend; everything is local state and `shared_preferences`.

## Getting started

Requires the Flutter SDK (`^3.9.2` or later — check with `flutter --version`).

```bash
flutter pub get
flutter run
```

`flutter run` will target whatever device/simulator/browser is connected;
use `flutter devices` to see what's available and `-d <device>` to pick one.

## Building for release

Platform-specific build scripts live at the project root:

- **iOS** — `./build_ios.sh`, see [doc/BUILD_IOS.md](doc/BUILD_IOS.md) (macOS + Xcode required)
- **Android** — `./build_android.sh`, see [doc/BUILD_ANDROID.md](doc/BUILD_ANDROID.md)

Both default to a release build and print usage with `--help`.

## Project structure

```
lib/
  core/            Shared, feature-agnostic widgets and layout helpers
                    (BeatterScaffold, BeatterAppBar, dialogs, EmptyState,
                    responsive breakpoints, …)
  theme/            Design system: colors, typography, spacing/radius scales,
                    shadows, and the assembled ThemeData
  models/           Plain data models (Composition, RhythmElement/Pattern, …)
  services/         Playback engine, repositories, audio/asset generation
  widgets/
    music_staff/    The staff CustomPainter, its geometry math, and the
                    read-only/editable staff view widgets built on it
  features/
    auth/           Login
    music/          Flow Mode, Composer Mode, Sheet Mode + shared widgets
    admin/          Admin dashboard and rhythm pattern creator
assets/
  audio/            Metronome clicks, drum hits, generated note samples
  icon/             Rhythmic-figure notation icons used by Flow Mode
  logos/            App branding
```

## Testing

```bash
flutter test
```

Covers the staff-layout/reflow geometry (`staff_geometry.dart`) and the
`CompositionRepository`/`PatternRepository` save/rename/duplicate/delete
flows, plus a login-screen smoke test.

## Tech notes

- No backend — auth, compositions, and patterns are all local
  (`shared_preferences` + in-memory repositories backed by `ChangeNotifier`).
- Audio playback is timer-scheduled in `RhythmPlaybackService` using
  `audioplayers`, with separate handling for metronome clicks vs. melodic/
  percussive note playback.
- UI is a single light theme (see `lib/theme/`) built on Flutter's platform
  default font — no dark mode, no custom typeface.
