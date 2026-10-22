# Fuse.Vibration Guide

Practical recipes and platform notes for `Fuse.Vibration`.

## Recipes

### Button tap feedback

```xml
<Button Text="Save">
    <Clicked>
        <Vibrate Duration="0.15" Amplitude="0.5" />
    </Clicked>
</Button>
```

For a named impact instead of a duration:

```xml
<Vibrate VibrationType="Light" />
```

### Selection change

Use `selection` for pickers, segmented controls, and list selection:

```js
Vibration.vibrate("selection");
```

On Android, this maps to the closest `VibrationEffect` tick or haptic feedback
constant. On iOS, it uses the Taptic Engine selection feedback style.

### Success, warning, and error

```js
function saveSucceeded() {
    Vibration.vibrate("success");
}

function saveFailed() {
    Vibration.vibrate("error");
}
```

These map to notification feedback on iOS and short waveforms on Android.

### Long vibration with cancellation

```js
// Start a long vibration.
Vibration.vibrate(5);

// Stop it later.
setTimeout(function () {
    Vibration.cancel();
}, 1000);
```

The UX equivalent:

```xml
<Vibrate Duration="5" />
<StopVibration Delay="1" />
```

`cancel()` stops the current sequence. Starting a new vibration also stops the
current one.

### Patterns

Patterns are lists of off/on durations in milliseconds:

```js
// Wait 100 ms, vibrate 50 ms, wait 100 ms, vibrate 50 ms.
Vibration.vibrate([100, 50, 100, 50]);
```

Loop the whole pattern:

```js
Vibration.vibrate([100, 50, 100, 50], 0);
```

Loop from a specific index:

```js
// Play the prefix once, then loop from index 2.
Vibration.vibrate([0, 100, 60, 100, 60, 100], 2);
```

Per-segment amplitudes:

```js
Vibration.vibrate({
    pattern: [0, 100, 80, 100],
    repeat: 0,
    amplitude: 0.7,
    amplitudes: [0, 1, 0, 0.5]
});
```

The `amplitudes` array must be the same length as the pattern. Off-segments
should normally use `0`.

### Amplitude and sharpness

Amplitude controls strength from `0` to `1`:

```js
Vibration.vibrate(0.5, 0.3);    // weaker
Vibration.vibrate(0.5, 1);      // full strength
```

Sharpness controls texture on iOS:

```js
Vibration.vibrate({
    duration: 0.4,
    amplitude: 0.8,
    sharpness: 0.2    // soft
});

Vibration.vibrate({
    duration: 0.4,
    amplitude: 0.8,
    sharpness: 0.9    // rigid
});
```

On Android, sharpness has no direct equivalent and is ignored.

### Android usage categories

Usage tells Android how the vibration should be classified:

```js
Vibration.vibrate({ duration: 0.3, usage: "touch" });
Vibration.vibrate({ duration: 0.3, usage: "notification" });
Vibration.vibrate({ duration: 0.3, usage: "alarm" });
Vibration.vibrate({ duration: 0.3, usage: "accessibility" });
```

This maps to `AudioAttributes` usage. It does not bypass Do Not Disturb; the
system still applies the user's settings. `usage` is ignored on iOS.

### Primitives

```js
Vibration.primitive("click");
Vibration.primitive("thud", 0.7);
Vibration.primitive("tick", 0.4);
Vibration.primitive("spin", 0.6);
```

Valid names are `click`, `thud`, `tick`, `lowTick`, `spin`, `quickRise`,
`quickFall`, and `slowRise`. Names are case-insensitive.

On Android 11 / API 30 and newer, primitives use
`VibrationEffect.Composition`. Older Android versions use a one-shot
approximation. On iOS, primitives map to impact feedback styles.

### UX actions

```xml
<Vibrate Duration="0.5" Amplitude="0.6" Sharpness="0.3" Usage="Touch" />

<Vibrate VibrationType="Success" Amplitude="0.8" />

<Vibrate Pattern="0,100,60,100" Repeat="0" Amplitude="0.7" />

<Vibrate Primitive="Thud" Amplitude="0.6" />

<StopVibration />
```

The action priority is:

1. `Pattern`
2. `Primitive`
3. `VibrationType`
4. `Duration`

## How it works

### Android

- Uses `Vibrator.hasVibrator()` to check capability.
- Timed vibrations and patterns use `VibrationEffect.createWaveform` on API 26+
  and `Vibrator.vibrate(long[], repeat)` below API 26.
- Single durations use waveform effects with a leading off segment.
- Amplitude is mapped from `0..1` to `1..255`. Amplitude is ignored below
  API 26 or on devices without amplitude control.
- Named feedback types use predefined effects on API 29+ and fall back to
  haptic feedback constants or one-shot effects.
- Usage categories are mapped to `AudioAttributes` usage.
- `cancel()` calls `Vibrator.cancel()`.

### iOS

- Uses `UIImpactFeedbackGenerator` with a timed impact sequencer. It does not
  start a Core Haptics engine and does not activate an audio session.
- The sequencer ticks every `0.02s` and emits impacts at most every `0.12s`.
  A long duration is therefore a pulse train rather than a single continuous
  vibration.
- Patterns are interpreted with the same off/on semantics as Android, so the
  rhythm is preserved.
- Amplitude maps to `impactOccurredWithIntensity:`.
- Sharpness selects the Soft, Medium, or Rigid impact style.
- `cancel()` invalidates the impact timer.
- `usage` has no iOS equivalent and is ignored.

### Why an impact sequencer instead of Core Haptics?

Core Haptics is the ideal API for continuous haptics, but it can fail at
engine or player creation on some devices and audio-session states. The impact
sequencer uses the same Taptic Engine path as the named feedback types, works
consistently across iPhones with a Taptic Engine, and has no audio-session side
effects.

## Testing

Haptics require real hardware. The iOS Simulator, Android emulator, and desktop
preview do not vibrate.

A useful test checklist:

1. `isSupported()` returns `true` on a real phone.
2. `vibrate(0.2)`, `vibrate(0.5)`, and `vibrate(2)` feel progressively longer.
3. `vibrate(0.5, 0.3)` feels weaker than `vibrate(0.5, 1)` on a device with
   amplitude control.
4. Each named feedback type is distinguishable.
5. A click pattern and a heartbeat pattern preserve their rhythm.
6. A repeating pattern loops and stops with `cancel()`.
7. An invalid type or repeat index throws an error.
8. A long pattern stops when `StopVibration` fires.

A manual test app, `VibrationTest`, exercises every API and displays the
native/helper build markers. Run it on real hardware.

## Troubleshooting

### Nothing vibrates

- Confirm you are on real hardware.
- Check `Vibration.isSupported()`.
- On Android, check that the device has a vibrator and is not in a mode that
  suppresses vibration (silent mode, Do Not Disturb, or system haptics
  disabled).
- On iOS, an iPad returns `isSupported() === false`.

### All durations feel the same

This usually means the app is not reaching the duration sequencer and is
falling back to a fixed system vibration. Check:

1. `Vibration.helperBuild` in the app. Rebuild the native package and app after
   changing `ios/VibrationHelper`.
2. That the pattern has at least one positive on-duration.
3. That `Vibration.isSupported()` is `true`.

If the helper build marker is current and durations still feel identical, verify
that the generated `ios/VibrationHelper.m` contains the expected
`[NSNumber numberWithDouble:seconds * 1000.0]` expression. Avoid `@(...)` boxing
inside Uno foreign blocks; the Uno foreign parser can strip it and produce an
empty pattern.

### Amplitude has no effect

- Check `Vibration.hasAmplitudeControl()`.
- On Android below API 26, amplitude is not supported.
- On iOS, intensity changes are subtle with impact feedback. Try a larger
  difference, such as `0.1` versus `1`.
- On Android, devices without amplitude control ignore the value.

### Android usage categories seem ignored

`usage` is a classification hint. Do Not Disturb, silent mode, and the user's
vibration settings still take precedence. Usage is not a permission and cannot
force a vibration through system restrictions.

### `cancel()` does not stop a pattern

Confirm the pattern is running on the current version and that
`helperBuild` matches the app build. `cancel()` stops the current impact
sequence; a new vibration started afterward will run normally.

## Migration notes

If you used an older `Fuse.Vibration`:

- `vibrate()` now returns a boolean instead of `null`.
- Unknown type strings now throw instead of silently falling back to `soft`.
- `Vibrate.Duration` defaults to `0.4` seconds instead of `0`.
- iOS now honors durations (as a Taptic Engine impact sequence) instead of
  always playing a fixed system vibration.
- `cancel()` and `<StopVibration>` are new.
- `isSupported()`, `hasAmplitudeControl()`, and `prepare()` are new.
- Patterns, amplitude, sharpness, usage categories, and primitives are new.

The existing calls remain source-compatible:

```js
Vibration.vibrate(0.8);
Vibration.vibrate("medium");
```
