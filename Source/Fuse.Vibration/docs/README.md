# Fuse.Vibration

Native vibration and haptic feedback for Fuse/Uno apps.

`Fuse.Vibration` exposes the `FuseJS/Vibration` module and the UX `<Vibrate>`
trigger action. It supports:

- timed vibrations with amplitude and sharpness
- named feedback types
- waveform patterns with repeat and per-segment amplitudes
- native haptic primitives
- cancellation and capability queries
- Android usage categories

For recipes, platform behavior, testing, and troubleshooting, see
[GUIDE.md](GUIDE.md).

## Installation

Add a reference to `Fuse.Vibration` in your project file:

```json
{
  "references": [
    "Fuse",
    "FuseJS",
    "Fuse.Vibration"
  ]
}
```

Then require the module from JavaScript:

```js
var Vibration = require("FuseJS/Vibration");
```

## Quick start

```js
var Vibration = require("FuseJS/Vibration");

// 0.5 seconds
Vibration.vibrate(0.5);

// named feedback type
Vibration.vibrate("medium");

// pattern: off 100 ms, on 50 ms, off 100 ms, on 50 ms, loop
Vibration.vibrate([100, 50, 100, 50], { repeat: 0 });

// options object
Vibration.vibrate({
    duration: 0.5,
    amplitude: 0.6,
    sharpness: 0.3,
    usage: "touch"
});
```

## API

### `vibrate(...)`

Starts a vibration. Returns `true` when a vibration was started, otherwise
`false`.

Accepted forms:

```js
Vibration.vibrate();                            // 0.4 seconds
Vibration.vibrate(seconds);                     // e.g. 0.5
Vibration.vibrate(seconds, amplitude);          // 0..1
Vibration.vibrate(type);                        // e.g. "medium"
Vibration.vibrate(type, intensity);             // 0..1
Vibration.vibrate(pattern, repeat?);            // timings in milliseconds
Vibration.vibrate(pattern, options?);
Vibration.vibrate(pattern, repeat, options);
Vibration.vibrate(options);
```

Options:

| Property | Type | Description |
|---|---|---|
| `duration` | number | Duration in seconds. Used when `pattern` and `type` are absent. |
| `pattern` | number[] | Waveform timings in milliseconds, starting with an off duration. |
| `type` | string | A named feedback type. |
| `amplitude` | number | Strength from `0` to `1`. Defaults to `1`. |
| `intensity` | number | Alias for `amplitude`. |
| `sharpness` | number | Texture from `0` to `1` (iOS only). Defaults to `0.5`. |
| `usage` | string | Android usage: `default`, `touch`, `notification`, `alarm`, `accessibility`. |
| `repeat` | number | Index in `pattern` to loop from, or `-1` to play once. Defaults to `-1`. |
| `amplitudes` | number[] | Per-segment strengths from `0` to `1`, same length as `pattern`. |

`duration` must be positive and finite. A non-positive or non-finite duration
returns `false`.

Examples:

```js
Vibration.vibrate(0.25);
Vibration.vibrate(0.5, 0.3);
Vibration.vibrate("success");
Vibration.vibrate("heavy", 0.6);
Vibration.vibrate([0, 40, 80, 40], -1);
Vibration.vibrate([0, 100, 80, 100], { repeat: 0, amplitude: 0.7 });
Vibration.vibrate({
    pattern: [0, 100, 80, 100],
    repeat: 0,
    amplitude: 0.6,
    amplitudes: [0, 1, 0, 0.5]
});
Vibration.vibrate({ duration: 0.5, amplitude: 0.6, sharpness: 0.3 });
Vibration.vibrate({ type: "warning", intensity: 0.8 });
```

### `primitive(name, scale?)`

Plays a native haptic primitive. Returns `true` when a vibration was started,
otherwise `false`.

```js
Vibration.primitive("click");
Vibration.primitive("thud", 0.7);
```

Valid names (case-insensitive):

`click`, `thud`, `tick`, `lowTick`, `spin`, `quickRise`, `quickFall`,
`slowRise`.

`scale` is a strength from `0` to `1` and defaults to `1`.

### `cancel()`

Stops the current vibration or impact sequence.

```js
Vibration.cancel();
```

### `prepare()`

Returns whether haptics are available on the current platform. Kept as a
preparation hook for code that warms up haptics before an interaction.

```js
Vibration.prepare();
```

### `isSupported()`

Returns whether the device can vibrate.

```js
if (!Vibration.isSupported()) {
    console.log("Haptics are not available on this device");
}
```

### `hasAmplitudeControl()`

Returns whether the device can vary vibration strength.

```js
if (Vibration.hasAmplitudeControl()) {
    Vibration.vibrate(0.5, 0.4);
}
```

### Diagnostics

These read-only strings identify the native code that is running. They are
useful when verifying that a rebuilt app includes the latest native helper.

| Property | Type | Description |
|---|---|---|
| `build` | string | Build marker of the JS/native module. |
| `helperBuild` | string | Build marker of the iOS native helper. Returns `"android"` or `"desktop"` on other targets. |

```js
console.log("Vibration native: " + Vibration.build);
console.log("Vibration helper: " + Vibration.helperBuild);
```

## Feedback types

The `type` argument is case-insensitive.

| Type | Typical use |
|---|---|
| `soft` | Gentle tap |
| `rigid` | Crisp tap |
| `light` | Light impact |
| `medium` | Standard impact |
| `heavy` | Strong impact |
| `success` | Successful action |
| `warning` | Warning |
| `error` | Error or failure |
| `selection` | Picker or segmented control change |

```js
Vibration.vibrate("selection");
```

## Haptic primitives

Primitives are lower-level than feedback types and map to the closest native
haptic primitive on each platform.

| Primitive | Character |
|---|---|
| `click` | Short click |
| `thud` | Heavy thud |
| `tick` | Short tick |
| `lowTick` | Lower-pitched tick |
| `spin` | Spinning texture |
| `quickRise` | Rising texture |
| `quickFall` | Falling texture |
| `slowRise` | Gentle rising texture |

```js
Vibration.primitive("tick", 0.4);
```

## Patterns

Pattern timings alternate off/on durations in milliseconds and start with an
off duration:

```
[off, on, off, on, ...]
```

For example:

```js
// Wait 100 ms, vibrate 50 ms, wait 100 ms, vibrate 50 ms.
Vibration.vibrate([100, 50, 100, 50]);

// Play once.
Vibration.vibrate([0, 100, 60, 100], -1);

// Loop the whole pattern.
Vibration.vibrate([0, 100, 60, 100], 0);

// Loop from index 2 (the second off duration).
Vibration.vibrate([0, 100, 60, 100, 60, 100], 2);
```

`repeat` must be `-1` or an index inside the pattern. Invalid values throw an
error.

`amplitudes` can be supplied to vary the strength of each segment:

```js
Vibration.vibrate({
    pattern: [0, 100, 80, 100],
    repeat: 0,
    amplitudes: [0, 1, 0, 0.5]
});
```

## UX trigger actions

```xml
<Button Text="Vibrate">
    <Clicked>
        <Vibrate Duration="0.5" />
    </Clicked>
</Button>

<Button Text="Success">
    <Clicked>
        <Vibrate VibrationType="Success" Amplitude="0.8" />
    </Clicked>
</Button>

<Button Text="Pattern">
    <Clicked>
        <Vibrate Pattern="0,100,60,100" Repeat="0" Amplitude="0.7" />
    </Clicked>
</Button>

<Button Text="Primitive">
    <Clicked>
        <Vibrate Primitive="Thud" Amplitude="0.6" />
    </Clicked>
</Button>

<Button Text="Stop">
    <Clicked>
        <StopVibration />
    </Clicked>
</Button>
```

`Vibrate` properties:

| Property | Type | Description |
|---|---|---|
| `Duration` | number | Duration in seconds. Defaults to `0.4`. |
| `VibrationType` | enum | `Soft`, `Rigid`, `Light`, `Medium`, `Heavy`, `Success`, `Warning`, `Error`, `Selection`. |
| `Pattern` | string | Comma-separated millisecond timings, starting with an off duration. |
| `Repeat` | number | Index in `Pattern` to loop from, or `-1`. Defaults to `-1`. |
| `Amplitude` | number | Strength from `0` to `1`. Defaults to `1`. |
| `Sharpness` | number | Texture from `0` to `1` (iOS only). Defaults to `0.5`. |
| `Usage` | enum | `Default`, `Touch`, `Notification`, `Alarm`, `Accessibility` (Android only). |
| `Primitive` | enum | `Click`, `Thud`, `Tick`, `LowTick`, `Spin`, `QuickRise`, `QuickFall`, `SlowRise`. |

The action uses `Pattern` first, then `Primitive`, then `VibrationType`, then
`Duration`.

## Errors and validation

The JavaScript API throws a `Fuse.Scripting.Error` for:

- an unknown feedback type
- an unknown primitive
- an unknown usage category
- a pattern that is not an array of finite, non-negative numbers
- an `amplitudes` array whose length does not match the pattern
- a `repeat` value outside `-1 .. pattern.length - 1`
- options that contain none of `duration`, `pattern`, or `type`
- a non-number where a number is required

A non-positive or non-finite duration returns `false` instead of throwing.

```js
try {
    Vibration.vibrate("nope");
} catch (error) {
    console.log(error.message);
}
```

## Platform notes

| Feature | iOS | Android |
|---|---|---|
| Native API | `UIImpactFeedbackGenerator` impact sequencer | `Vibrator` + `VibrationEffect` |
| Timed vibration | Timed sequence of Taptic Engine impacts | Waveform or one-shot |
| Amplitude | `impactOccurredWithIntensity:` | `VibrationEffect` amplitude (`1..255`) |
| Sharpness | Soft / Medium / Rigid impact styles | Not available |
| Usage categories | Not available | `AudioAttributes` usage |
| Primitives | Mapped impact styles | `VibrationEffect.Composition` (API 30+), one-shot fallback |
| Cancel | Stops the impact sequence | `Vibrator.cancel()` |
| Capability check | iPhone idiom and Taptic Engine | `Vibrator.hasVibrator()` |

- Haptics require real hardware. The iOS Simulator, Android emulator, and
  desktop preview do not vibrate.
- On iOS, durations are represented by a timed sequence of Taptic Engine
  impacts rather than a continuous Core Haptics vibration.
- `sharpness` is iOS-only.
- `usage` is Android-only.
- Android below API 26 ignores amplitude.
- Android below API 30 approximates primitives with one-shot vibrations.

## Limitations

- No haptic event queue. Starting a new vibration cancels the current one.
- `cancel()` stops the current sequence; it does not clear a queue.
- Android-only and iOS-only options are ignored on the other platform.
- `isSupported()` reports device capability, not whether the user has disabled
  system haptics or enabled Do Not Disturb.
- Long iOS durations are pulse trains, not a single continuous vibration.

## See also

- [GUIDE.md](GUIDE.md) - recipes, platform behavior, testing, and troubleshooting
