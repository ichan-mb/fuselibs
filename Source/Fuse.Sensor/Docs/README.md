# Fuse.Sensor

`Fuse.Sensor` gives JavaScript access to the device's motion sensors, the step counter, the
barometer, the battery state and network connectivity, through the `FuseJS/Sensor` module.

- [Guide](Guide.md) — task oriented walkthrough with complete examples.
- This file — API reference, data shapes and platform requirements.

## Installation

Add a reference to the package in your `.unoproj`:

```json
"References": [
	"Fuse",
	"Fuse.Sensor"
]
```

Then require the module from JavaScript:

```js
var Sensor = require("FuseJS/Sensor");
```

Reading sensors on iOS also needs a usage description in the **app** project (see
[Requirements](#requirements)).

## Quick start

```js
var Observable = require("FuseJS/Observable");
var Sensor = require("FuseJS/Sensor");

var acceleration = Observable("--");

Sensor.on("accelerometer", function (data) {
	acceleration.value = data.x.toFixed(2) + ", " + data.y.toFixed(2) + ", " + data.z.toFixed(2);
});

Sensor.on("error", function (message) {
	console.log("Sensor error: " + message);
});

function start() { Sensor.startListening(Sensor.ACCELEROMETER, 50); }
function stop() { Sensor.stopListening(Sensor.ACCELEROMETER); }

module.exports = { acceleration, start, stop };
```

```xml
<StackPanel>
	<Text Value="{acceleration}" />
	<Button Text="Start" Clicked="{start}" />
	<Button Text="Stop" Clicked="{stop}" />
</StackPanel>
```

## Sensor types

| Constant | Value | Unit | Description |
|---|---|---|---|
| `Sensor.ACCELEROMETER` | 0 | m/s² | Acceleration on all three axes, including gravity. |
| `Sensor.GYROSCOPE` | 1 | rad/s | Rate of rotation around each axis. |
| `Sensor.MAGNETOMETER` | 2 | µT | Ambient geomagnetic field. |
| `Sensor.GRAVITY` | 3 | m/s² | Gravity vector only. |
| `Sensor.USER_ACCELERATION` | 4 | m/s² | Acceleration excluding gravity. |
| `Sensor.ROTATION` | 5 | — | Three elements of the device rotation vector (see [Rotation](#rotation)). |
| `Sensor.STEP_COUNTER` | 6 | steps | Step count (see [Step counter](#step-counter)). |
| `Sensor.PRESSURE` | 7 | hPa | Ambient air pressure; `y` carries relative altitude on iOS. |
| `Sensor.BATTERY` | 8 | — | Battery level and charging state. |
| `Sensor.CONNECTION_STATE` | 9 | — | Network connectivity. |

`BATTERY` and `CONNECTION_STATE` are event sources rather than hardware sensors. They are listed
with the sensor types so that one module, one set of events and one `startListening` call cover
everything.

## Methods

### `startListening(sensorType, interval)`

Starts the sensor and emits events as readings arrive. Calling it again for a sensor that is
already listening does nothing.

- `interval` (optional, milliseconds, 0–60000) is the desired sampling interval. It is a **hint**:
  the actual rate depends on the device, and some sources ignore it entirely (see
  [Sampling rate](#sampling-rate)). Omit it, or pass `0`, for the platform default.

### `stopListening([sensorType])`

Stops one sensor, or every sensor that is currently listening when called without an argument.

### `isSensing(sensorType)`

`true` while the sensor is delivering readings. It is `false` before the first successful start,
and stays `false` if starting the sensor failed.

### `isAvailable(sensorType)`

`true` if the device has the hardware (or platform support) for the sensor. Check this before
starting a sensor that may not exist on the device.

### `getAvailable()`

Returns an array of the sensor type constants that are available on this device, for example
`[0, 1, 2, 3, 7]`.

### `getOnce(sensorType)`

Returns a promise that resolves with a single reading, in the same shape as an event payload. If
the sensor is not already listening it is started for that one reading and stopped afterwards; if
it is already listening it stays running. A failed start rejects the promise.

```js
Sensor.getOnce(Sensor.PRESSURE)
	.then(function (data) { console.log(data.x + " hPa"); })
	.catch(function (err) { console.log("Unavailable: " + err); });
```

This is the recommended way to read a sensor that does not need continuous updates: it avoids
draining the battery with a sensor nobody is looking at.

## Events

The module is an `EventEmitter`, so `on`, `once`, `off`/`removeListener` and `observe` all work.

### `"changed"`

Carries every reading. Use `data.type` to tell them apart.

### Per-sensor events

Every sensor type also has its own event, so listeners do not have to filter:

| Event | Payload |
|---|---|
| `"accelerometer"` | motion |
| `"gyroscope"` | motion |
| `"magnetometer"` | motion |
| `"gravity"` | motion |
| `"user_acceleration"` | motion |
| `"rotation"` | motion |
| `"step_counter"` | motion |
| `"pressure"` | motion |
| `"battery"` | battery |
| `"connection_state"` | connectivity |

```js
Sensor.on("accelerometer", function (data) { /* ... */ });
```

### `"error"`

Reports a recoverable problem as a string: requesting an unknown sensor type, starting a sensor
that failed, or reading a sensor the device does not have. Errors are safe to ignore — emitting
`"error"` without a listener no longer throws.

## Payloads

### Motion sensors

`ACCELEROMETER`, `GYROSCOPE`, `MAGNETOMETER`, `GRAVITY`, `USER_ACCELERATION`, `ROTATION`,
`STEP_COUNTER` and `PRESSURE` share one shape:

| Field | Type | Description |
|---|---|---|
| `type` | `number` | One of the sensor type constants. |
| `x` | `number` | First axis, in the unit listed above. |
| `y` | `number` | Second axis. For `PRESSURE` on iOS: relative altitude in meters. |
| `z` | `number` | Third axis. `0` for step counter and pressure. |
| `timestamp` | `number` | Milliseconds since the Unix epoch, when the reading reached the app. |
| `elapsed` | `number` | Seconds on the sensor's monotonic clock, or `0` when unavailable. |

### `BATTERY`

| Field | Type | Description |
|---|---|---|
| `type` | `number` | `Sensor.BATTERY` |
| `level` | `number` | The raw platform value: 0–100 on Android, 0.0–1.0 on iOS. |
| `levelPercent` | `number` | 0–100 on every platform. |
| `levelRatio` | `number` | 0.0–1.0 on every platform. |
| `state` | `string` | `"charging"`, `"full"`, `"unplugged"`, `"not_charging"`, `"unknown"` or `"unsupported"`. |
| `timestamp` | `number` | Milliseconds since the Unix epoch. |
| `elapsed` | `number` | Always `0`: battery changes have no sensor timestamp. |

Prefer `levelPercent` or `levelRatio` in cross platform code; `level` is kept for compatibility
and still has the platform specific range.

### `CONNECTION_STATE`

| Field | Type | Description |
|---|---|---|
| `type` | `number` | `Sensor.CONNECTION_STATE` |
| `state` | `boolean` | `true` when connected. |
| `stateString` | `string` | `"connected"` or `"disconnected"`. |
| `timestamp` | `number` | Milliseconds since the Unix epoch. |
| `elapsed` | `number` | Always `0`. |

## Timestamps

Every reading carries two time values:

- `timestamp` — milliseconds since the Unix epoch, taken when the reading reaches the app. Compare
  it with `Date.now()`, or convert it with `new Date(timestamp)`. Use it to relate readings to the
  rest of the app and to each other.
- `elapsed` — seconds on the platform's **monotonic** clock (time since boot), taken from the
  sensor hardware. It does not jump when the wall clock is adjusted and has no delivery delay, so
  it is the right value for measuring intervals and for integrating values over time.

`elapsed` is `0` when the source has no sensor timestamp: battery, connectivity, and the step
counter on iOS. `elapsed` is comparable between sensors on the same device, but not between
devices.

```js
var last = 0;
Sensor.on("accelerometer", function (data) {
	if (last !== 0 && data.elapsed !== 0)
		console.log("interval: " + ((data.elapsed - last) * 1000).toFixed(1) + " ms");
	if (data.elapsed !== 0)
		last = data.elapsed;
});
```

## Sampling rate

The `interval` argument of `startListening` is a hint. What a sensor actually delivers depends on
the platform and the device:

- `ACCELEROMETER`, `GYROSCOPE`, `MAGNETOMETER`, `GRAVITY`, `USER_ACCELERATION`, `ROTATION` respect
  it closely on Android and iOS (iOS is capped by `CMMotionManager`).
- `PRESSURE` respects it on Android; iOS paces it through `CMAltimeter`.
- `STEP_COUNTER`, `BATTERY` and `CONNECTION_STATE` are paced by the system and ignore it.

Measure the rate you actually get with `elapsed` rather than assuming the hint was honoured. The
interval applies when the sensor starts; to change it while running, stop and start again.

## Rotation

`ROTATION` reports the three vector elements of the device's rotation vector (the vector part of
the attitude quaternion). Note that the reference frame differs between platforms:

- Android: `TYPE_ROTATION_VECTOR`, relative to an East–North–Up frame.
- iOS: the attitude quaternion of `CMDeviceMotion`, in a Z-vertical frame.

The values have the same shape and can be used to derive orientation the same way, but they are
not directly comparable between platforms. If you only need the change in orientation, prefer
`GYROSCOPE`.

## Step counter

The two platforms count differently:

- Android reports `TYPE_STEP_COUNTER`: the number of steps since the last device reboot.
- iOS reports `CMPedometer` steps since `startListening` was called.

Treat the value as a counter that increases, not as a per-session total, and derive the number of
steps in a period from the change in `x`.

## Requirements

### Android

The package declares `android.permission.ACCESS_NETWORK_STATE`, which `CONNECTION_STATE` needs.
This is a normal permission and is granted at install time.

`STEP_COUNTER` additionally needs the **runtime** permission `ACTIVITY_RECOGNITION` on Android 10
(API 29) and later. The app has to request it; `Fuse.Android.Permissions` exposes it as
`Android.ACTIVITY_RECOGNITION`. Without the grant the step counter simply delivers no readings.

### iOS

`STEP_COUNTER` and `PRESSURE` read data that iOS protects with a usage description. Declare it in
**your application's** `.unoproj`, otherwise iOS terminates the app as soon as either sensor is
used:

```json
"ios": {
	"pList": {
		"NSMotionUsageDescription": "Explain here why the app reads motion data"
	}
}
```

Declaring it inside `Fuse.Sensor.unoproj` (or any other referenced library) does **not** work: the
build only applies `ios.pList` from the app project. The other sensors do not require a usage
description.

## Desktop preview

On targets without native sensor support, the module produces simulated data instead of failing:
smooth sine signals for the motion sensors, a walking pace for the step counter, a pressure around
1013 hPa, a battery level that cycles and connectivity that flips every 10 seconds.
`isAvailable` reports every type as available there. This lets sensor driven UI be built and tested
without a device.

## Limitations

- No proximity, ambient light, heart rate or step detector support yet.
- No sensor metadata (vendor, resolution, power); only availability is exposed.
- `BATTERY` does not expose temperature, voltage or health.
- The pedometer exposes the step count only; distance, floors, pace and cadence are not available.

## Upgrading

If you are coming from an older `Fuse.Sensor`, these behaviours changed:

- Battery `state` is now lowercase on both platforms (`"unplugged"`, `"not_charging"`, …). It used
  to be capitalized on iOS and inconsistently capitalized on Android.
- Battery payloads gained `levelPercent` and `levelRatio`; `level` keeps its platform specific
  range.
- Emitting `"error"` without a listener no longer throws an uncaught JavaScript exception.
- Invalid sensor type arguments are reported through `"error"` instead of throwing or silently
  using the accelerometer.
- `ROTATION` on iOS now reports the rotation vector instead of the gyroscope rate, and `GRAVITY`
  and `USER_ACCELERATION` report m/s² instead of g.
- Readings gained `timestamp` and `elapsed`, and the per-sensor events were added; `"changed"`
  still receives everything.
