# Fuse.Launcher.Maps Guide

This guide covers the map launcher: showing locations, searching, opening
directions and handling platform differences.

- [1. Setup](#1-setup)
- [2. Core concepts](#2-core-concepts)
- [3. Recipes](#3-recipes)
- [4. Platform details](#4-platform-details)
- [5. Migration from the original API](#5-migration-from-the-original-api)
- [6. Limitations](#6-limitations)
- [7. Troubleshooting](#7-troubleshooting)
- [8. Testing](#8-testing)
- [9. Implementation notes](#9-implementation-notes)

## 1. Setup

Add a reference to `Fuse.Launcher.Maps` (or the aggregate `Fuse.Launcher`) in
your project file:

```json
{
  "references": [
    "Fuse",
    "Fuse.Launcher.Maps"
  ]
}
```

For JavaScript, require the module:

```js
var Maps = require("FuseJS/Maps");
```

For C#, use the `Fuse.Launcher` facade:

```csharp
using Fuse;
```

## 2. Core concepts

### `MapLocation`

A coordinate with an optional label:

```csharp
var location = new MapLocation(59.9117715, 10.7400957, "Fuse");
```

Latitude must be between -90 and 90, longitude between -180 and 180.

### `MapLaunchOptions`

Describes what to open:

- Set `Location` to show a point.
- Set `Query` to search.
- Set `Query` and `SearchNear` to search near a point.
- Set `Destination` or `DestinationAddress` to open directions.

When a destination is set, `Location`, `Query` and `SearchNear` are ignored.

### `MapLaunchStatus`

Only `Opened` is reported. Failures reject the `Future` / `Promise` instead of
returning a failure status.

### Availability

```js
var available = Maps.isAvailable();
```

```csharp
var available = Fuse.Launcher.IsMapAvailable();
```

Android checks for a native `geo:` handler. iOS always returns `true` because
Apple Maps is built in. The web fallback may still work when
`IsMapAvailable()` is `false`.

## 3. Recipes

### Show a location

```js
Maps.open({ latitude: 59.9117715, longitude: 10.7400957 });
```

```csharp
Fuse.Launcher.LaunchMaps(new MapLaunchOptions
{
    Location = new MapLocation(59.9117715, 10.7400957)
});
```

### Show a labeled pin with zoom

```js
Maps.open({
    latitude: 59.9117715,
    longitude: 10.7400957,
    label: "Fuse",
    zoom: 16
});
```

### Search for a place

```js
Maps.search("pizza restaurant");
```

### Search near a location

```js
Maps.search({
    query: "pizza restaurant",
    near: { latitude: 59.9117715, longitude: 10.7400957 }
});
```

```csharp
Fuse.Launcher.LaunchMaps(new MapLaunchOptions
{
    Query = "pizza restaurant",
    SearchNear = new MapLocation(59.9117715, 10.7400957)
});
```

### Directions from the current location

```js
Maps.directions({
    to: { latitude: 59.9117715, longitude: 10.7400957, label: "Fuse" }
});
```

```csharp
Fuse.Launcher.LaunchDirections(
    null,
    new MapLocation(59.9117715, 10.7400957, "Fuse"));
```

### Directions with an origin

```js
Maps.directions({
    from: { latitude: 59.9139, longitude: 10.7522 },
    to: { latitude: 59.9117715, longitude: 10.7400957 }
});
```

### Directions to an address

```js
Maps.directions({
    to: "Some Street 1, Oslo",
    mode: "transit"
});
```

On iOS, address destinations use the Apple Maps link. MapKit directions require
coordinates.

### Choose a travel mode

```js
Maps.directions({ to: destination, mode: "walking" });
Maps.directions({ to: destination, mode: "transit" });
Maps.directions({ to: destination, mode: "cycling" });
```

Supported modes:

| Mode | Android | iOS |
|---|---|---|
| `driving` | `google.navigation:` or Google Maps URL | MapKit / `dirflg=d` |
| `walking` | `google.navigation:` or Google Maps URL | MapKit / `dirflg=w` |
| `transit` | Google Maps URL | MapKit / `dirflg=r` |
| `cycling` | `google.navigation:` or Google Maps URL | MapKit; link fallback uses walking |

### Start navigation

```js
Maps.directions({
    to: destination,
    mode: "driving",
    startNavigation: true
});
```

On Android, this uses `google.navigation:` when Google Maps is the target, or
`dir_action=navigate` on the Google Maps URL. On iOS it is ignored and Maps
opens the directions view.

### Prefer Google Maps on iOS

```js
Maps.directions({
    to: destination,
    preferGoogleMaps: true
});
```

The launcher tries `comgooglemaps://` first. If Google Maps is not installed, it
falls back to Apple Maps.

### Target a specific Android app

```js
Maps.open({
    latitude: 59.9117715,
    longitude: 10.7400957,
    androidPackage: "com.google.android.apps.maps"
});
```

If the package is not installed, the launcher retries with the default map
application.

### Use map types

```js
Maps.open({
    latitude: 59.9117715,
    longitude: 10.7400957,
    mapType: "satellite",
    zoom: 15
});
```

`hybrid` is supported by Apple Maps. Google Maps has no hybrid basemap, so the
Google Maps URL and the `comgooglemaps://` scheme use satellite for hybrid.

### Handle errors

```js
Maps.directions({ to: destination }).then(function(result) {
    console.log(result.status);
}).catch(function(error) {
    console.log("Could not open maps: " + error);
});
```

```csharp
Fuse.Launcher.LaunchMaps(options).Then(
    status => { /* MapLaunchStatus.Opened */ },
    error => { /* Exception */ });
```

## 4. Platform details

### Android

- Location/search uses an implicit `ACTION_VIEW` intent with a `geo:` URI.
- `zoom` and labels are encoded in the `geo:` URI.
- Directions with `StartNavigation` and coordinate destinations use
  `google.navigation:` when Google Maps is the target.
- Other directions use the Google Maps directions URL, which opens Google Maps
  or a browser.
- `androidPackage` constrains the intent. If the package is missing, the
  launcher retries with the default map app.
- If no native handler exists, the launcher opens the Google Maps web URL when
  `useWebFallback` is enabled (the default).
- The `<queries>` manifest entry for `geo:` is added automatically.

### iOS

- Location/search uses an Apple Maps link.
- Directions to coordinates use MapKit (`MKMapItem`), which supports travel
  modes, map types, traffic and the current location as origin.
- Directions to an address use the Apple Maps link, because MapKit would require
  geocoding.
- `preferGoogleMaps` tries `comgooglemaps://` first.
- Launch failures are detected with `openURL:options:completionHandler:`.
- If Apple Maps fails, the launcher falls back to the Google Maps web URL when
  `useWebFallback` is enabled.

### Other platforms

`IsMapAvailable()` returns `false` and `Launch` rejects with
`"Maps are not supported on this platform."`.

## 5. Migration from the original API

The original methods still work:

```js
Maps.openAt(59.9117715, 10.7400957);
Maps.searchNearby("pizza");
Maps.searchNear(59.9117715, 10.7400957, "pizza");
```

They now return promises, so the existing fire-and-forget calls are unaffected
and you can start using the result:

```js
Maps.openAt(59.9117715, 10.7400957).catch(function(error) {
    console.log(error);
});
```

In C#, the original overloads are still available:

```csharp
Fuse.Launcher.LaunchMaps(59.9117715, 10.7400957);
Fuse.Launcher.LaunchMaps("pizza");
Fuse.Launcher.LaunchMaps(59.9117715, 10.7400957, "pizza");
```

Use `LaunchMaps(MapLaunchOptions)` or `LaunchDirections` when you need the
launch result.

Behavior changes from the original implementation:

- Android no longer hardcodes Google Maps; it uses the user's default map app.
- iOS uses `https://maps.apple.com/` links instead of the legacy `/maps` path.
- If no native app is available, the launcher opens a web map by default.
- Invalid coordinates are reported through diagnostics instead of being ignored.

## 6. Limitations

- Android `geo:` intents have no map-type parameter.
- Apple Maps links have no cycling flag; MapKit handles cycling when available.
- `startNavigation` only applies to Android/Google Maps URLs.
- `showTraffic` only applies to Apple Maps directions.
- Origin addresses are not supported. Provide origin coordinates or omit the
  origin to use the current location.
- The launcher does not embed a map view. Use `Fuse.Maps` for an in-app map.

## 7. Troubleshooting

### Nothing happens on Android

- Check that a map app is installed, or leave `UseWebFallback` enabled.
- If you targeted an `AndroidPackage`, the launcher retries with the default app
  when the package is missing.
- Check `Maps.isAvailable()`.

### Google Maps is not used on Android

- Without `AndroidPackage`, the launcher uses the user's default map app.
- Set `androidPackage: "com.google.android.apps.maps"` to target Google Maps.
- Turn-by-turn navigation uses `google.navigation:`, which only Google Maps
  handles.

### “Maps are not supported on this platform.”

The launcher is running on a platform other than Android or iOS. The call rejects
instead of doing nothing.

### Zoom is ignored

- Android `geo:` supports `z`, Apple Maps links support `z`, and the Google Maps
  map-view URL supports `zoom`.
- The Google Maps search URL has no zoom parameter, so zoom is ignored for text
  searches in the web fallback.
- Each platform clamps zoom to its supported range: Android 23, Apple 20,
  Google 21.

### Map type is ignored

- Android `geo:` has no map-type parameter.
- The Google Maps search URL has no map-type parameter.
- Apple Maps links support `t=k` (satellite) and `t=h` (hybrid).
- Google Maps has no hybrid basemap, so hybrid uses satellite.

### Cycling opens walking directions

This can happen in the Apple Maps link fallback. Apple's URL scheme has no
cycling flag; MapKit handles cycling natively. Keep `PreferGoogleMaps` off to
use MapKit.

### `StartNavigation` does nothing on iOS

iOS has no equivalent flag in the MapKit launch options. Maps opens the
directions view and the user starts navigation.

### Directions to an address use the link instead of MapKit on iOS

MapKit needs coordinates. The launcher uses the Apple Maps link for address
destinations so Apple Maps can geocode them.

## 8. Testing

```sh
cd fuselibs
uno test Source/Fuse.Launcher/Tests/Fuse.Launcher.Test.unoproj
```

The manual launcher page is
`Tests/ManualTests/ManualTestingApp/Singles/Launchers.ux`.

## 9. Implementation notes

- `MapsUriHelper` builds and validates all URIs without a device, which keeps
  the behavior covered by unit tests.
- Android uses a small Java helper (`MapsLauncherHelper.java`) to run the intent
  on the UI thread, catch `ActivityNotFoundException` and retry without a
  package.
- iOS uses `MapsPlatformIOS` with MapKit for coordinate directions and
  `openURL:options:completionHandler:` for links.
- `MapsLauncher` returns a `Future<MapLaunchStatus>`; the original void overloads
  are thin wrappers that ignore the result.
