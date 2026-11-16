# PlatformViewTest

Manual test app for `Fuse.PlatformView`.

## Requirements

This app (and the package it references) uses `*.kt:Kotlin:Android`, which requires an Uno
compiler built from the `kotlin` branch. See the main package README.

## Build

```sh
uno build -t=android PlatformViewTest.unoproj
uno build -t=ios-sim PlatformViewTest.unoproj
```

## Registration

- **iOS:** `FusePlatformViewSetup.swift` exports the `FusePlatformViewSetup` C symbol, which
  the package calls on first use to register `SampleView`.
- **Android:** `PlatformViewSetup.kt` provides `com.fuse.platformview.PlatformViewSetup.install()`,
  which the package invokes reflectively on first use.

## Coverage

The screen exercises:

- Two instances of the same `ViewName` with independent state.
- `DataString`, `DataInteger`, `DataDouble`, `DataObject` binding.
- Native → Fuse events (`EventHandler`), including structured `eventData`.
- Fuse → native commands (`invoke` / `onCommand`).
- Lifecycle events (`Loaded`, `Appeared`, `Disappeared`, `Unloaded`).
- `DataUpdateMode="Batched"` updates.
- Intrinsic sizing (`Height="Auto"`).
- Accessibility label/hint.
- `ColorScheme` / `LayoutDirection` overrides.
- A missing `ViewName` to confirm the diagnostic.
