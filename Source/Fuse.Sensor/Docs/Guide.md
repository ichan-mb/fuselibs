# Fuse.Sensor guide

This guide walks through using `Fuse.Sensor` in an app: reading a sensor, choosing a sampling
rate, taking one-off readings, working with timestamps, and handling the platform requirements.

For the full API reference, data shapes and platform notes see [README.md](README.md).

## 1. Set up the project

Add the package to your `.unoproj`:

```json
"References": [
	"Fuse",
	"Fuse.Sensor"
]
```

Add the iOS usage description if you plan to use `PRESSURE` or `STEP_COUNTER` (see
[Platform setup](#9-platform-setup)).

## 2. Read your first sensor

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

module.exports = {
	acceleration: acceleration,
	stop: function () { Sensor.stopListening(Sensor.ACCELEROMETER); }
};

// Start at roughly 20 Hz.
Sensor.startListening(Sensor.ACCELEROMETER, 50);
```

```xml
<StackPanel>
	<Text Value="{acceleration}" />
	<Button Text="Stop" Clicked="{stop}" />
</StackPanel>
```

The accelerometer reports m/s² including gravity, so a phone lying flat on a table reads close to
`0, 0, 9.81`. For movement without gravity use `USER_ACCELERATION`, and for the gravity vector
alone use `GRAVITY`.

## 3. Check what the device has

Not every device has every sensor — cheap or old devices often lack a gyroscope, magnetometer or
barometer. Check before starting, so you can show a sensible message instead of an empty screen:

```js
if (Sensor.isAvailable(Sensor.PRESSURE)) {
	Sensor.startListening(Sensor.PRESSURE);
}

// Everything this device can do:
console.log("Available: " + Sensor.getAvailable().join(", "));
```

`startListening` on a missing sensor reports an `"error"`, which is otherwise harmless, so the
check is about UX rather than stability.

## 4. Choose a sampling rate

The second argument of `startListening` is the desired interval in milliseconds:

```js
Sensor.startListening(Sensor.ACCELEROMETER, 16);   // ~60 Hz
Sensor.startListening(Sensor.ACCELEROMETER, 200);  // ~5 Hz
```

It is a hint. High rates cost battery and CPU, so pick the lowest rate the UI can live with; a
sensor driving a number on screen does not need 60 Hz, while a tilt gesture might. The interval is
applied when the sensor starts — to change it, stop and start again:

```js
function setRate(milliseconds) {
	Sensor.stopListening(Sensor.ACCELEROMETER);
	Sensor.startListening(Sensor.ACCELEROMETER, milliseconds);
}
```

`STEP_COUNTER`, `BATTERY` and `CONNECTION_STATE` ignore the interval. See
[Sampling rate](README.md#sampling-rate).

## 5. Listen to one sensor, or all of them

`"changed"` carries every reading; each sensor type also has its own event. Prefer the specific
event — the handler stays small and you never forget to check `data.type`:

```js
Sensor.on("gyroscope", function (data) { /* rad/s */ });
Sensor.on("magnetometer", function (data) { /* µT */ });
Sensor.on("pressure", function (data) { /* hPa in x, relative altitude in y on iOS */ });
```

If you are already using observables, `observe` turns an event into one:

```js
var acceleration = Sensor.observe("accelerometer");
var magnitude = acceleration.map(function (data) {
	return Math.sqrt(data.x * data.x + data.y * data.y + data.z * data.z);
});
```

`observe` only follows the event; you still have to call `startListening`, and you can call
`stopListening` when nobody is watching anymore.

## 6. Take a single reading

For a value you need once — the current pressure, the battery level, one compass sample — use
`getOnce` instead of starting a stream you will forget to stop:

```js
function readPressure() {
	return Sensor.getOnce(Sensor.PRESSURE).then(function (data) {
		console.log(data.x.toFixed(1) + " hPa");
	}).catch(function (err) {
		console.log("Could not read pressure: " + err);
	});
}
```

`getOnce` starts the sensor for one reading and stops it again, unless the sensor was already
listening — in which case it simply resolves with the next reading and leaves it running. The
promise rejects if the sensor cannot be started.

## 7. Compare readings over time

Every reading has two timestamps:

- `timestamp` — wall clock, milliseconds since the Unix epoch. Good for showing a time, or for
  correlating a reading with other events in the app.
- `elapsed` — seconds on the platform's monotonic clock, taken from the sensor. Good for
  measuring how long things took, because it never jumps when the clock is adjusted.

Measuring the interval you actually get:

```js
var last = 0;

Sensor.on("accelerometer", function (data) {
	if (last !== 0 && data.elapsed !== 0) {
		var milliseconds = (data.elapsed - last) * 1000;
		console.log("interval: " + milliseconds.toFixed(1) + " ms");
	}
	if (data.elapsed !== 0)
		last = data.elapsed;
});
```

Showing a reading with the time it was taken:

```js
Sensor.on("pressure", function (data) {
	var taken = new Date(data.timestamp);
	console.log(taken.toLocaleTimeString() + " " + data.x.toFixed(1) + " hPa");
});
```

Integrating over time — this is where `elapsed` matters, since a wall clock jump would produce a
wrong `dt`:

```js
var velocity = 0;
var lastElapsed = 0;

Sensor.on("user_acceleration", function (data) {
	if (data.elapsed === 0)
		return;

	if (lastElapsed !== 0) {
		var dt = data.elapsed - lastElapsed;
		velocity += data.x * dt;
	}
	lastElapsed = data.elapsed;
});
```

Velocity computed this way drifts and is only meaningful for short intervals; treat it as an
estimate, and reset it when the device is at rest.

`elapsed` is `0` for battery, connectivity and the iOS step counter.

## 8. Battery and connectivity

Both are ordinary sensor types, so they use the same calls and events:

```js
var batteryLevel = Observable("--");
var batteryState = Observable("--");
var online = Observable(false);

Sensor.on("battery", function (data) {
	batteryLevel.value = data.levelPercent.toFixed(0) + "%";
	batteryState.value = data.state;               // "charging", "unplugged", ...
});

Sensor.on("connection_state", function (data) {
	online.value = data.state;
});

Sensor.startListening(Sensor.BATTERY);
Sensor.startListening(Sensor.CONNECTION_STATE);
```

Both report their current state as soon as they start, so the UI does not have to wait for a
change. Use `levelPercent` (0–100) or `levelRatio` (0.0–1.0) rather than `level`, whose range
differs between Android and iOS.

## 9. Platform setup

### Android: step counter permission

`STEP_COUNTER` needs the runtime permission `ACTIVITY_RECOGNITION` on Android 10 and later. Ask
for it before starting the sensor; without it the sensor simply produces no readings.

The permission is exposed by `Fuse.Android.Permissions` (see that package for the full request
API) as `Android.ACTIVITY_RECOGNITION`. Add `"Fuse.Android.Permissions"` to your project's
references, then request it from native code:

```uno
if defined(Android)
	Fuse.Android.Permissions.Permissions.Request(
		Fuse.Android.Permissions.Permissions.Android.ACTIVITY_RECOGNITION);
```

`Request` returns a future, so you can wait for the answer before calling `startListening`.
Alternatively, grant the permission by hand in the app settings — the sensor starts working as
soon as it is granted.

`CONNECTION_STATE` needs `ACCESS_NETWORK_STATE`, which the package declares itself, so nothing to
do.

### iOS: usage description

`PRESSURE` and `STEP_COUNTER` read CoreMotion data that iOS protects. Declare the reason in the
**application** project file:

```json
"ios": {
	"pList": {
		"NSMotionUsageDescription": "Tracks altitude changes and step count to show your activity."
	}
}
```

Without it iOS terminates the app the moment either sensor is used. Putting the declaration in
`Fuse.Sensor.unoproj` does not help — the build only applies `ios.pList` from the app project.

The remaining sensors need no declaration.

## 10. Develop without a device

On targets without native sensors (desktop preview) the module produces simulated data, so layouts
and JavaScript can be built without a phone:

- motion sensors: smooth sine signals around their typical ranges
- step counter: about 1.5 steps per second
- pressure: around 1013 hPa, slowly varying
- battery: level cycling between 55% and 95%, state `"charging"`
- connectivity: flips between connected and disconnected every 10 seconds

`isAvailable` reports every type as available there. Values follow the interval you request, so
rate-related UI can be tested too.

## Recipes

### Detect movement

```js
var MOVEMENT_THRESHOLD = 1.5;   // m/s², tune for your use case

Sensor.on("user_acceleration", function (data) {
	var magnitude = Math.sqrt(data.x * data.x + data.y * data.y + data.z * data.z);
	if (magnitude > MOVEMENT_THRESHOLD)
		console.log("moving");
});
```

### Steps in the last minute

Step counts differ per platform (see [Step counter](README.md#step-counter)), so work with
changes in the counter rather than the absolute value:

```js
var history = [];   // { at: epoch ms, steps: number }

Sensor.on("step_counter", function (data) {
	history.push({ at: data.timestamp, steps: data.x });

	var cutoff = data.timestamp - 60 * 1000;
	while (history.length > 0 && history[0].at < cutoff)
		history.shift();
});
```

### Stop everything when the app is not visible

```js
Sensor.stopListening();   // stops every sensor that is listening
```

Calling `stopListening` with no argument is the easiest way to release the sensors from a "pause"
handler or when the screen is dismissed.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| No readings at all | `startListening` was never called, or the sensor is not available — check `isAvailable` and listen for `"error"`. |
| Readings stop after a while | Something called `stopListening` — check your own handlers, and `isSensing` to see the current state. |
| Step counter reports nothing on Android 10+ | `ACTIVITY_RECOGNITION` has not been granted. |
| App crashes on iOS when reading pressure or steps | `NSMotionUsageDescription` missing from the **app** project file. |
| Battery `level` looks wrong | It is platform specific; use `levelPercent` or `levelRatio`. |
| `ROTATION` values differ between Android and iOS | The reference frames differ; see [Rotation](README.md#rotation). |
| Actual rate differs from the requested interval | The interval is a hint and some sources are system paced; measure with `elapsed`. |
| `getOnce` never resolves | The sensor never delivered a reading — check availability and the `"error"` event; the promise rejects when the start fails. |
| Everything works in preview, not on device | Preview uses simulated data and reports every sensor as available; check `isAvailable` and the platform setup above. |

## Performance

- Stop sensors when nothing is listening to them. A sensor left running keeps the device awake and
  drains the battery.
- Prefer the lowest useful sampling rate; 5–20 Hz is enough for most UI.
- Use `getOnce` for values that do not need continuous updates.
- Do not do heavy work in the event handler — it runs at the sensor's rate. Store the value and let
  the UI update on its own.
