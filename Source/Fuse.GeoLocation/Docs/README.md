# Fuse.GeoLocation

`Fuse.GeoLocation` gives JavaScript access to the device's location services through the
`FuseJS/GeoLocation` module: one-shot fixes, continuous watchers, compass heading, forward and
reverse geocoding, and circular geofences.

- [Guide](Guide.md) — task oriented walkthrough with complete examples.
- This file — API reference, data shapes and platform requirements.

## Installation

Add the package to your `.unoproj`:

```json
"References": [
	"Fuse",
	"Fuse.GeoLocation"
]
```

Then require the module from JavaScript:

```js
var GeoLocation = require("FuseJS/GeoLocation");
```

On iOS the package supplies default `NSLocation*UsageDescription` values through
`Fuse.iOS.LocationPermissions`. If you need your own wording, see
[Requirements](#requirements).

## Quick start

```js
var Observable = require("FuseJS/Observable");
var GeoLocation = require("FuseJS/GeoLocation");

var position = Observable("--");

GeoLocation.getLocation({ timeout: 15000 })
	.then(function (location) {
		position.value = location.latitude.toFixed(5) + ", " + location.longitude.toFixed(5);
	})
	.catch(function (error) {
		console.log("Location failed: " + error);
	});

module.exports = { position: position };
```

```xml
<StackPanel>
	<Text Value="{position}" />
</StackPanel>
```

## Quick start: continuous updates

```js
var watchId = GeoLocation.watchPosition(function (location) {
	console.log(location.latitude + ", " + location.longitude);
}, function (error) {
	console.log("Location error: " + error);
}, {
	interval: 1000,
	accuracy: 10,
	distanceFilter: 10
});

// Later:
GeoLocation.clearWatch(watchId);
```

`watchPosition` allows several independent watchers. They share one platform listener, which uses
the most demanding interval, accuracy and distance filter across all active watchers.

## Authorization

Location services require permission from the user. The package requests the default
"when in use" permission at launch on Android unless the project disables it. The status is:

```js
console.log(GeoLocation.authorizationStatus);
```

One of:

| Status | Meaning |
|---|---|
| `"notDetermined"` | The user has not been asked yet. |
| `"restricted"` | The device or parental controls prevent access. |
| `"denied"` | The user denied access. |
| `"authorizedWhenInUse"` | Access is allowed while the app is in use. |
| `"authorizedAlways"` | Access is allowed in the background as well. |

Request permission explicitly when it makes sense in your UI:

```js
GeoLocation.requestAuthorization().then(function (status) {
	console.log("Authorization: " + status);
});

// Or ask for background access:
GeoLocation.requestAuthorization(2).then(function (status) {
	console.log("Authorization: " + status);
});
```

The argument is `1` for "when in use" and `2` for "always". `GeoLocation.authorizationRequest`
still sets the type used by the rest of the API; set it before calling `getLocation`,
`startListening` or `watchPosition` if you need "always".

Listen for changes:

```js
GeoLocation.on("authorizationStatusChanged", function (status) {
	console.log("New authorization status: " + status);
});
```

## Methods

### `isLocationEnabled()`

Returns `true` when location services are enabled and the app is authorized. On Android it checks
both the location providers and the runtime permission; on iOS it checks
`CLLocationManager.locationServicesEnabled` and the authorization status. The spoof provider on
desktop reports `true`.

```js
if (!GeoLocation.isLocationEnabled())
	console.log("Location services are disabled or permission was denied");
```

### `authorizationStatus`

A read-only string property, one of the values in [Authorization](#authorization).

### `requestAuthorization(type)`

Requests permission and returns a promise resolving to the resulting status string. `type` is
optional: `1` for "when in use" (the default), `2` for "always". Passing `0` resolves with the
current status without prompting.

### `location`

A read-only property containing the last known location, or an empty object if none is available.
It is updated by `watchPosition`, `startListening` and `getLocation`. See
[Location payload](#location-payload).

```js
var last = GeoLocation.location;
if (last.latitude !== undefined)
	console.log(last.latitude + ", " + last.longitude);
```

### `getLocation(options)`

Returns a promise for the current location.

```js
GeoLocation.getLocation({ timeout: 20000, maximumAge: 60000 })
	.then(function (location) { /* ... */ })
	.catch(function (error) { /* string */ });
```

- `timeout` — milliseconds before the promise rejects. Default `20000`.
- `maximumAge` — when greater than zero and a cached location is younger than this value, the
  promise resolves immediately with the cache. Default `0` (always request a fresh fix).
- The numeric form `getLocation(timeout)` is still supported.

The promise rejects with an error string when permission is denied, location services are disabled,
or the request times out.

### `watchPosition(onLocation, onError, options)`

Starts a watcher and returns an integer id. `onLocation` is called with each
[location payload](#location-payload); `onError` is optional and receives an error string.

```js
var watchId = GeoLocation.watchPosition(onLocation, onError, {
	interval: 1000,
	accuracy: 10,
	distanceFilter: 10
});
```

Options:

| Option | Meaning |
|---|---|
| `interval` | Desired minimum report interval in milliseconds. Default `500`. |
| `accuracy` | Desired accuracy in meters. Default `10`. |
| `distanceFilter` | Minimum distance in meters between updates. Default `0`. |

The values are hints; the actual rate and accuracy depend on the device. If a last known location
is cached, the watcher receives it asynchronously after registration. Multiple watchers are
supported; the platform listener uses the smallest interval, best accuracy and smallest distance
filter requested by any active watcher.

### `clearWatch(id)`

Stops the watcher with the given id. Unknown ids are ignored.

### `startListening(interval, accuracy, distanceFilter)`

The legacy continuous API. It emits the [`"changed"`](#changed) event and is independent from
`watchPosition` callbacks.

```js
GeoLocation.on("changed", function (location) {
	console.log(location.latitude + ", " + location.longitude);
});

GeoLocation.startListening(1000, 10, 10);
// ...
GeoLocation.stopListening();
```

The arguments are optional and default to `500` ms, `10` m and `0` m. On iOS the interval is
ignored because `CLLocationManager` has no report interval; the distance filter is honored.
`startListening` and `watchPosition` share the same platform listener.

### `stopListening()`

Stops the legacy continuous listener. Active `watchPosition` watchers continue to run.

### `startUpdatingHeading(options)`

Starts compass heading updates. Listen to the
[`"headingChanged"`](#headingchanged) event to receive them.

```js
GeoLocation.on("headingChanged", function (heading) {
	console.log(heading.degrees.toFixed(1) + "°");
});

GeoLocation.startUpdatingHeading({ interval: 100 });
```

`interval` is the desired report interval in milliseconds. It is a hint; iOS ignores it and uses
`CLLocationManager`'s heading updates.

### `stopUpdatingHeading()`

Stops compass heading updates.

### `geocode(address, options)`

Looks up addresses matching a text query and returns a promise resolving to an array of
[address objects](#address-payload).

```js
GeoLocation.geocode("Oslo, Norway", { maxResults: 5 })
	.then(function (addresses) {
		addresses.forEach(function (address) {
			console.log(address.formattedAddress);
		});
	})
	.catch(function (error) { /* string */ });
```

`maxResults` defaults to `5`. Android uses `android.location.Geocoder` on a background thread; iOS
uses `CLGeocoder`. Both require a network connection. The promise rejects when geocoding is
unavailable or the platform reports an error.

### `reverseGeocode(coordinates, options)`

Looks up addresses describing a coordinate.

```js
GeoLocation.reverseGeocode({ latitude: 59.91, longitude: 10.75 }, { maxResults: 1 })
	.then(function (addresses) {
		console.log(addresses[0].formattedAddress);
	});
```

The coordinate form `reverseGeocode(latitude, longitude, maxResults)` is also supported.
`maxResults` defaults to `1`.

### `addGeofence(options)`

Starts monitoring a circular geofence and returns an integer id.

```js
var fenceId = GeoLocation.addGeofence({
	latitude: 59.91,
	longitude: 10.75,
	radius: 100,
	identifier: "home"
});
```

| Option | Meaning |
|---|---|
| `latitude`, `longitude` | Center of the fence. |
| `radius` | Radius in meters; must be greater than zero. |
| `identifier` | Optional application-defined label, returned in events. |

iOS uses `CLCircularRegion` region monitoring (at most 20 regions). Android uses
`LocationManager.addProximityAlert`. Errors are reported through the [`"error"`](#error) event.
Invalid input throws a JavaScript exception.

### `removeGeofence(id)`

Stops monitoring the given fence. Unknown ids are ignored.

### `removeAllGeofences()`

Stops monitoring every fence.

## Events

The module is an `EventEmitter`, so `on`, `once`, `off`/`removeListener` and `observe` work.

### `"changed"`

Raised by the legacy `startListening` API with each new location. It is **not** raised for
`watchPosition` callbacks, so watcher-only apps should use their callback instead.

### `"headingChanged"`

Raised by `startUpdatingHeading` with a [heading payload](#heading-payload).

```js
GeoLocation.on("headingChanged", function (heading) { /* ... */ });
```

### `"geofenceEntered"` and `"geofenceExited"`

Raised when the device crosses a fence boundary. The payload is a
[geofence object](#geofence-payload). A newly registered fence that already contains the device
raises `"geofenceEntered"`; an initial "outside" state does not raise `"geofenceExited"`, and
repeated platform events for the same state are suppressed.

### `"authorizationStatusChanged"`

Raised when the platform authorization status changes. The parameter is a status string from
[Authorization](#authorization).

### `"error"`

Raised with an error string for location, heading and geofence failures. Promise-based calls
(`getLocation`, `geocode`, `reverseGeocode`) reject their promise instead.

## Payloads

### Location payload

| Field | Type | Description |
|---|---|---|
| `latitude` | `number` | Decimal degrees. |
| `longitude` | `number` | Decimal degrees. |
| `accuracy` | `number` | Horizontal accuracy in meters. |
| `altitude` | `number` | Altitude in meters. |
| `hasAltitude` | `boolean` | Whether `altitude` is valid. |
| `altitudeAccuracy` | `number` | Vertical accuracy in meters, or `-1` when unavailable. |
| `heading` | `number` | Direction of travel in degrees clockwise from north, or `-1` when unavailable. |
| `hasHeading` | `boolean` | Whether `heading` is valid. |
| `speed` | `number` | Speed in meters per second. |
| `hasSpeed` | `boolean` | Whether `speed` is valid. |
| `speedAccuracy` | `number` | Speed accuracy in meters per second, or `-1` when unavailable. |
| `timestamp` | `number` | Milliseconds since the Unix epoch. |
| `isMock` | `boolean` | Whether the platform reports a mock/spoofed location. |
| `provider` | `string` | Provider name when available (`"gps"`, `"network"`, `"corelocation"`, …). Omitted when unknown. |

`heading` is the direction of travel (course/bearing). It is not the compass heading; use
`startUpdatingHeading` for that.

### Heading payload

| Field | Type | Description |
|---|---|---|
| `degrees` | `number` | Compass heading in degrees clockwise from north (`0`–`360`). |
| `accuracy` | `number` | Accuracy in degrees, or `-1` when unavailable. |
| `timestamp` | `number` | Milliseconds since the Unix epoch. |

On iOS `degrees` uses true north when the platform can determine it, otherwise magnetic north.
Android uses magnetic north.

### Address payload

| Field | Type | Description |
|---|---|---|
| `name` | `string` | Feature or place name. |
| `street` | `string` | Thoroughfare. |
| `streetNumber` | `string` | Street number. |
| `city` | `string` | Locality. |
| `subLocality` | `string` | Sub-locality or neighbourhood. |
| `region` | `string` | Administrative area (state/province). |
| `subRegion` | `string` | Sub-administrative area. |
| `country` | `string` | Country name. |
| `countryCode` | `string` | ISO country code. |
| `postalCode` | `string` | Postal code. |
| `formattedAddress` | `string` | A display-ready address assembled from the fields above. |
| `latitude` | `number` | Coordinates of the result, when the platform provides them. |
| `longitude` | `number` | Coordinates of the result, when the platform provides them. |

All string fields are `""` when the platform has no value.

### Geofence payload

| Field | Type | Description |
|---|---|---|
| `id` | `number` | The id returned by `addGeofence`. |
| `identifier` | `string` | The application-defined identifier, or `""`. |
| `latitude` | `number` | Center latitude. |
| `longitude` | `number` | Center longitude. |
| `radius` | `number` | Radius in meters. |

## Requirements

### Android

The package declares `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`, and requests them at
launch by default. Set the project property below to request them yourself instead:

```
project.android.geoLocation.requestPermissionsOnLaunch = false
```

Background geofencing and background location updates also need
`android.permission.ACCESS_BACKGROUND_LOCATION` in the **application** manifest. The permission
package intentionally does not declare it automatically, because apps that request it without a
background location use case can be rejected by Google Play. The manual test app in
`/Users/hassan/project/fuse/GeoLocationTest` shows an app-level `Android.uxl` declaration.

Background location uses a foreground service. The package declares
`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, and the `location` foreground-service type
required by Android 14. Enable background updates with:

```
project.android.geoLocation.backgroundLocation.enabled = true
```

The notification icon can be customized with
`project.android.geoLocation.backgroundLocation.notificationIcon.*`.

### iOS

`Fuse.GeoLocation` references `Fuse.iOS.LocationPermissions`, which supplies default
`NSLocationUsageDescription`, `NSLocationWhenInUseUsageDescription`,
`NSLocationAlwaysUsageDescription` and `NSLocationAlwaysAndWhenInUseUsageDescription` values. The
same values are mirrored in `Fuse.GeoLocation.unoproj` for reference.

Background geofencing requires "Always" authorization. Call `requestAuthorization(2)` or set
`GeoLocation.authorizationRequest = 2` before using the API, and enable the `location` background
mode in the app project.

iOS region monitoring supports at most 20 simultaneous geofences, and each radius must not exceed
`CLLocationManager.maximumRegionMonitoringDistance`. The package reports violations through the
`"error"` event.

`CLGeocoder` is used for geocoding. It is deprecated in iOS 26 in favour of MapKit, but remains
functional.

## Desktop preview

On targets without native location support the module uses a spoof provider:

- a fixed location in Oslo,
- heading `0`,
- deterministic geocoding results,
- an immediate `geofenceEntered` when a fence contains the spoof location.

This lets location-driven UI be developed without a device. `isLocationEnabled` reports `true` and
`authorizationStatus` reports `"authorizedWhenInUse"`.

## Limitations

- Android still uses `LocationManager`, not `FusedLocationProviderClient`; there is no
  `LocationRequest` priority selection or batching.
- Android geofencing uses proximity alerts, so a transition delivered while the app process is
  dead is received by the broadcast receiver but cannot reach JavaScript until the app registers
  its callback again.
- iOS ignores the report interval for location and heading updates.
- `startListening` and `watchPosition` share one platform listener; watchers cannot use
  independent accuracy or distance settings.
- The `"changed"` event only covers the legacy `startListening` API.
- Geofences report enter/exit only; dwell and other transition types are not exposed.
- Geocoding has no timeout option.
- Heading calibration is not configurable; iOS always declines the calibration prompt.
- There is no explicit provider selection (GPS, network, passive).

## Upgrading

If you are coming from an older `Fuse.GeoLocation`, these behaviours changed:

- Android `authorizationStatus` returns the normalized strings listed in
  [Authorization](#authorization) instead of `"on"`/`"off"`.
- `location` now updates after `startListening`, `watchPosition` and `getLocation`; it used to
  remain at the first cached value.
- `getLocation` rejects when permission is denied or location services are disabled instead of
  waiting for a timeout.
- `startListening` and `watchPosition` default to a 500 ms interval, 10 m accuracy and no distance
  filter instead of requesting the most aggressive updates.
- `watchPosition` watchers do not raise the legacy `"changed"` event.
- Geofences deduplicate their initial state: an initial "outside" does not raise
  `"geofenceExited"`, and repeated identical transitions are suppressed.
- Location objects gained `timestamp`, `altitudeAccuracy`, `heading`, `speedAccuracy`, `isMock`,
  `provider`, `hasAltitude`, `hasSpeed` and `hasHeading`.

## Tests

- Unit tests: `Source/Fuse.GeoLocation/Tests/Fuse.GeoLocation.Test.unoproj` covers coordinate math,
  payload models, watchers, heading, geofences and geocoding.
- Manual test app: `/Users/hassan/project/fuse/GeoLocationTest` exercises the complete JavaScript
  API on desktop, Android and iOS.
