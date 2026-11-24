# Fuse.GeoLocation guide

This guide walks through using `Fuse.GeoLocation` in an app: requesting permission, getting a
one-shot location, watching the location continuously, reading the compass heading, geocoding,
and geofencing.

For the full API reference, data shapes and platform notes see [README.md](README.md).

## 1. Set up the project

Add the package to your `.unoproj`:

```json
"References": [
	"Fuse",
	"Fuse.GeoLocation"
]
```

Require the module in JavaScript:

```js
var GeoLocation = require("FuseJS/GeoLocation");
```

On iOS the package supplies default `NSLocation*UsageDescription` values. If you need custom
wording, or you are enabling background location, see [Platform setup](#9-platform-setup).

## 2. Ask for permission

The package requests the default "when in use" permission at launch on Android. You can also ask
explicitly at a point where the request makes sense in your UI:

```js
function ensurePermission() {
	// Resolves immediately when permission is already granted.
	return GeoLocation.requestAuthorization();
}

ensurePermission().then(function (status) {
	console.log("Location authorization: " + status);
}).catch(function (error) {
	console.log("Authorization failed: " + error);
});
```

For background geofencing, ask for "always" instead:

```js
GeoLocation.requestAuthorization(2).then(function (status) {
	console.log("Background authorization: " + status);
});
```

`authorizationStatus` is one of `"notDetermined"`, `"restricted"`, `"denied"`,
`"authorizedWhenInUse"` or `"authorizedAlways"`. You can also react to changes:

```js
GeoLocation.on("authorizationStatusChanged", function (status) {
	console.log("Authorization changed: " + status);
});
```

Permission prompts should not be triggered by reading `GeoLocation.location` in a UI binding at
unexpected times. Request permission from an explicit action when possible.

## 3. Get the current location once

```js
var Observable = require("FuseJS/Observable");
var GeoLocation = require("FuseJS/GeoLocation");

var position = Observable("--");
var error = Observable("");

function locate() {
	position.value = "locating...";

	GeoLocation.getLocation({ timeout: 15000 }).then(function (location) {
		position.value = location.latitude.toFixed(5) + ", " + location.longitude.toFixed(5) +
			"  ±" + location.accuracy.toFixed(0) + " m";
		error.value = "";
	}).catch(function (message) {
		position.value = "--";
		error.value = String(message);
	});
}

module.exports = {
	position: position,
	error: error,
	locate: locate
};
```

```xml
<StackPanel>
	<Button Text="Locate me" Clicked="{locate}" />
	<Text Value="{position}" />
	<Text Value="{error}" TextColor="#c00" TextWrapping="Wrap" />
</StackPanel>
```

`getLocation` rejects when permission is denied, location services are disabled, or the timeout
expires. A `maximumAge` value lets you accept a recent cached position instead of waiting for a
fresh fix:

```js
// Show something immediately if the cache is less than a minute old.
GeoLocation.getLocation({ timeout: 20000, maximumAge: 60000 })
	.then(showLocation)
	.catch(requestFreshLocation);
```

## 4. Watch the location continuously

Use `watchPosition` when the UI should follow the device. It returns an id that you pass to
`clearWatch` later:

```js
var lastSeen = Observable("--");
var watchId = -1;

function startWatching() {
	if (watchId >= 0)
		return;

	watchId = GeoLocation.watchPosition(function (location) {
		lastSeen.value = location.latitude.toFixed(5) + ", " + location.longitude.toFixed(5);
	}, function (message) {
		console.log("Location watcher error: " + message);
	}, {
		interval: 1000,
		accuracy: 10,
		distanceFilter: 5
	});
}

function stopWatching() {
	if (watchId < 0)
		return;

	GeoLocation.clearWatch(watchId);
	watchId = -1;
}

module.exports = {
	lastSeen: lastSeen,
	startWatching: startWatching,
	stopWatching: stopWatching
};
```

- `interval` is the desired minimum report interval in milliseconds.
- `accuracy` is the desired accuracy in meters.
- `distanceFilter` is the minimum distance between updates, in meters.

All three are hints; the actual values depend on the device. Several watchers can be active at
once. They share one platform listener, and the listener uses the most demanding settings among
them. Removing the last watcher stops the listener.

If a location is already cached, the watcher receives it asynchronously just after registration,
so the UI can show something before the first fresh fix arrives.

## 5. Use the legacy `changed` listener

Apps that used the older continuous API can keep using it:

```js
GeoLocation.on("changed", function (location) {
	console.log(location.latitude + ", " + location.longitude);
});

GeoLocation.startListening(1000, 10, 10);
// ...
GeoLocation.stopListening();
```

`startListening` and `watchPosition` share the same platform listener. The `"changed"` event is
only raised by `startListening`; watcher callbacks are independent. Prefer `watchPosition` in new
code because it supports multiple subscribers and does not need a module-wide event.

On iOS the report interval is ignored because `CLLocationManager` has no equivalent setting; the
distance filter is honored.

## 6. Read the compass heading

The location payload's `heading` is the direction of travel. Compass heading is a separate stream:

```js
var degrees = Observable("--");
var accuracy = Observable("--");

GeoLocation.on("headingChanged", function (heading) {
	degrees.value = heading.degrees.toFixed(1) + "°";
	accuracy.value = heading.accuracy >= 0
		? "±" + heading.accuracy.toFixed(1) + "°"
		: "unknown";
});

function startHeading() {
	GeoLocation.startUpdatingHeading({ interval: 100 });
}

function stopHeading() {
	GeoLocation.stopUpdatingHeading();
}

module.exports = {
	degrees: degrees,
	accuracy: accuracy,
	startHeading: startHeading,
	stopHeading: stopHeading
};
```

On iOS the heading uses true north when the platform can determine it, otherwise magnetic north.
Android uses magnetic north. The interval is a hint; iOS ignores it.

## 7. Geocode and reverse geocode

Forward geocoding turns an address into coordinates:

```js
GeoLocation.geocode("Oslo, Norway", { maxResults: 5 })
	.then(function (addresses) {
		addresses.forEach(function (address) {
			console.log(address.formattedAddress);
			console.log(address.latitude + ", " + address.longitude);
		});
	})
	.catch(function (message) {
		console.log("Geocode failed: " + message);
	});
```

Reverse geocoding turns coordinates into an address:

```js
GeoLocation.getLocation({ timeout: 15000 }).then(function (location) {
	return GeoLocation.reverseGeocode({
		latitude: location.latitude,
		longitude: location.longitude
	}, { maxResults: 1 });
}).then(function (addresses) {
	if (addresses.length > 0)
		console.log(addresses[0].formattedAddress);
});
```

Both calls return a promise for an array of address objects. `maxResults` defaults to `5` for
`geocode` and `1` for `reverseGeocode`. Geocoding needs a network connection and a platform
geocoder; the promise rejects when the platform reports an error or geocoding is unavailable.

All address string fields exist but may be empty (`""`) when the platform has no value. Use
`formattedAddress` for display and the individual fields for logic.

## 8. Geofencing

A geofence is a circle with a center and a radius in meters:

```js
var fenceId = GeoLocation.addGeofence({
	latitude: 59.91,
	longitude: 10.75,
	radius: 100,
	identifier: "home"
});

GeoLocation.on("geofenceEntered", function (fence) {
	console.log("Entered " + fence.identifier);
});

GeoLocation.on("geofenceExited", function (fence) {
	console.log("Exited " + fence.identifier);
});

// Later:
GeoLocation.removeGeofence(fenceId);

// Or stop every fence:
GeoLocation.removeAllGeofences();
```

Fences are circular; `radius` must be greater than zero. A fence that already contains the device
raises `geofenceEntered` when it starts. An initial "outside" state does not raise
`geofenceExited`, and repeated identical transitions are suppressed.

Platform notes:

- **iOS** uses `CLCircularRegion` region monitoring. At most 20 regions can be monitored at once,
  and the radius must not exceed the platform maximum; both limits are reported through the
  `"error"` event. Background geofencing requires "Always" authorization.
- **Android** uses `LocationManager.addProximityAlert`. It needs fine location permission and
  background location permission if the app is in the background. Transitions are delivered to a
  manifest-registered receiver; if the app process was not running, the transition cannot reach
  JavaScript until the app registers its callback again.

Geofences are not persisted across app restarts by the package. Re-add them on startup if they
should survive a restart.

## 9. Platform setup

### Android permissions

The package declares `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION` and requests them at
launch by default. To manage the request yourself, set:

```
project.android.geoLocation.requestPermissionsOnLaunch = false
```

Background updates and background geofencing need
`android.permission.ACCESS_BACKGROUND_LOCATION` in the **application** manifest, plus:

```
project.android.geoLocation.backgroundLocation.enabled = true
```

The package declares the foreground service, `FOREGROUND_SERVICE`,
`FOREGROUND_SERVICE_LOCATION`, and the `location` foreground-service type required by Android 14.
The notification icon can be customized with
`project.android.geoLocation.backgroundLocation.notificationIcon.*`.

Add the background permission in an app-level `.uxl`:

```xml
<extensions backend="cplusplus" condition="ANDROID">
	<require androidManifest.permission="android.permission.ACCESS_BACKGROUND_LOCATION" />
</extensions>
```

The permission package deliberately does not declare it automatically, because apps that request
it without a background location use case can be rejected by Google Play.

### iOS usage descriptions

The package supplies default `NSLocation*UsageDescription` values through
`Fuse.iOS.LocationPermissions`. These defaults are suitable for most apps. If you need custom
wording, declare the keys in the **application** project file and avoid having both the library
defaults and the app-level entries active at once, because the generated `Info.plist` would then
contain duplicates:

```json
"ios": {
	"pList": {
		"NSLocationWhenInUseUsageDescription": "Explain here why the app needs your location."
	}
}
```

Background geofencing requires "Always" authorization, and the app needs the `location` background
mode enabled in its project. Call `requestAuthorization(2)` or set
`GeoLocation.authorizationRequest = 2` before using the API.

## 10. Develop without a device

On targets without native location support — including desktop preview — the module uses a spoof
provider:

- a fixed location in Oslo,
- heading `0`,
- deterministic geocoding results,
- an immediate `geofenceEntered` when a fence contains the spoof position.

`isLocationEnabled()` reports `true` and `authorizationStatus` reports `"authorizedWhenInUse"`.
This lets you build and test the UI without a phone. Use a real device to check accuracy, battery
impact, permission prompts and background behaviour.

## Recipes

### Show a readable location line

```js
function formatLocation(location) {
	var parts = [];
	parts.push(location.latitude.toFixed(5) + ", " + location.longitude.toFixed(5));
	parts.push("±" + location.accuracy.toFixed(0) + " m");

	if (location.hasAltitude)
		parts.push("alt " + location.altitude.toFixed(0) + " m");
	if (location.hasHeading)
		parts.push("heading " + location.heading.toFixed(0) + "°");
	if (location.hasSpeed)
		parts.push("speed " + location.speed.toFixed(1) + " m/s");
	if (location.isMock)
		parts.push("mock");

	return parts.join("  ");
}
```

### Accept a cached position first

```js
function showSomethingFast() {
	return GeoLocation.getLocation({ maximumAge: 300000 }).then(function (location) {
		console.log("Cached: " + formatLocation(location));
	});
}
```

`maximumAge` is in milliseconds. When it is greater than zero and the cached location is younger,
the promise resolves without waiting for a fresh fix.

### Stop everything when the app is backgrounded

```js
var watchId = -1;

function suspendLocation() {
	if (watchId >= 0) {
		GeoLocation.clearWatch(watchId);
		watchId = -1;
	}

	GeoLocation.stopListening();
	GeoLocation.stopUpdatingHeading();
}
```

Keep geofences registered if they should keep working in the background. Otherwise call
`GeoLocation.removeAllGeofences()` as well.

### Geofence the place the user is now

```js
function fenceHere(identifier, radiusMeters) {
	return GeoLocation.getLocation({ timeout: 15000 }).then(function (location) {
		return GeoLocation.addGeofence({
			latitude: location.latitude,
			longitude: location.longitude,
			radius: radiusMeters,
			identifier: identifier
		});
	});
}
```

### Surface errors in one place

```js
GeoLocation.on("error", function (message) {
	console.log("GeoLocation error: " + message);
});
```

This catches recoverable location, heading and geofence failures. Promise-based calls reject their
own promise instead, so handle those with `.catch`.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `getLocation` rejects with an authorization error | Permission was denied, or the system location switch is off. Check `isLocationEnabled()` and `authorizationStatus`. |
| `getLocation` always times out | The device has no fix yet, or location services are disabled. Try a longer timeout, and check that another app is not holding the GPS. |
| No `"changed"` events | `startListening` was not called. Watchers do not raise `"changed"`; use the `watchPosition` callback. |
| Watcher receives only one update | On desktop the spoof provider emits once. On a device, check the distance filter and whether location services are enabled. |
| Heading never changes | The device has no magnetometer, or heading updates were not started. Start them with `startUpdatingHeading`. |
| Heading is inaccurate | Compass calibration is needed; move the device in a figure-eight. iOS calibration prompts are disabled by the package. |
| `geocode` rejects on Android | The device has no geocoder backend (`Geocoder.isPresent()` is false), or there is no network connection. |
| Geofence never fires | Permission is missing, location services are off, or the fence is not being monitored. Check the `"error"` event. On Android, transitions while the process is dead are lost. |
| iOS app terminates when location is used | The location usage description is missing from the app project. |
| Background geofencing does not work on iOS | The app does not have "Always" authorization, or the `location` background mode is not enabled. |
| Android geofencing does not work in the background | `ACCESS_BACKGROUND_LOCATION` is not in the application manifest, or background location is not enabled for the project. |

## Performance

- Stop watchers and legacy listening when the screen does not need them.
- Use a larger `interval` and `distanceFilter` for UI that does not need frequent updates.
- Use `getLocation({ maximumAge: ... })` to avoid waiting for a fresh fix when a recent position is
  good enough.
- Prefer `getLocation` over a permanent watcher for a single "locate me" action.
- Geofencing is more battery efficient than continuous location updates for "notify me when I
  arrive" style features.
- Do not do heavy work in location callbacks; store the value and let the UI update.
