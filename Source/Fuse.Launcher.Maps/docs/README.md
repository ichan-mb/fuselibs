# Fuse.Launcher.Maps

Opens the platform map application to show a location, search, or open
directions.

- Android: `geo:` intents, `google.navigation:` and Google Maps URLs.
- iOS: Apple Maps through MapKit and map links, with optional Google Maps support.
- Supports zoom, pin labels, map types, directions, travel modes, availability
  checks and launch results.

For recipes, migration notes and troubleshooting, see [GUIDE.md](GUIDE.md).

## Installation

Add a reference to `Fuse.Launcher.Maps` in your project file:

```json
{
  "references": [
    "Fuse",
    "Fuse.Launcher.Maps"
  ]
}
```

You can also reference the aggregate `Fuse.Launcher` package, which includes the
maps launcher.

## JavaScript API

```js
var Maps = require("FuseJS/Maps");

var available = Maps.isAvailable();
```

### `Maps.isAvailable()`

Returns `true` when the platform can launch a native map application.

- Android: checks for a handler for `geo:` intents.
- iOS: always `true` (Apple Maps is built in).
- Other platforms: `false`.

### `Maps.open(options)`

Shows a location on the map.

```js
Maps.open({
    latitude: 59.9117715,
    longitude: 10.7400957,
    label: "Fuse",
    zoom: 16,
    mapType: "standard"
}).then(function(result) {
    // result.status is "opened"
}).catch(function(error) {
    // user-facing error message
});
```

Options:

| Option | Type | Description |
|---|---|---|
| `latitude` | number | Latitude in decimal degrees. Required. |
| `longitude` | number | Longitude in decimal degrees. Required. |
| `label` | string | Optional label for the pin. |
| `zoom` | number | Zoom level, 1–23. `0` uses the platform default. |
| `mapType` | string | `"standard"`, `"satellite"` or `"hybrid"`. |
| `androidPackage` | string | Android package to target. |
| `preferGoogleMaps` | bool | Try Google Maps first on iOS. |
| `useWebFallback` | bool | Open a web map when no native app is available. Defaults to `true`. |

A nested `location` object is also accepted:

```js
Maps.open({
    location: { latitude: 59.9117715, longitude: 10.7400957, label: "Fuse" },
    zoom: 16
});
```

### `Maps.search(queryOrOptions)`

Searches for a place.

```js
// Shorthand
Maps.search("pizza");

// Search near a location
Maps.search({
    query: "pizza",
    near: { latitude: 59.9117715, longitude: 10.7400957 },
    zoom: 14
});
```

Options:

| Option | Type | Description |
|---|---|---|
| `query` | string | The search query. Required. |
| `near` | object | Optional `{ latitude, longitude, label }` search origin. |
| `zoom`, `mapType`, `androidPackage`, `preferGoogleMaps`, `useWebFallback` | | As for `open`. |

### `Maps.directions(options)`

Opens directions.

```js
Maps.directions({
    to: { latitude: 59.9117715, longitude: 10.7400957, label: "Fuse" },
    mode: "walking"
});
```

Options:

| Option | Type | Description |
|---|---|---|
| `from` | object | Optional origin `{ latitude, longitude, label }`. Defaults to the current location. |
| `to` | object or string | Destination location or address. Required. |
| `mode` | string | `"driving"`, `"walking"`, `"transit"` or `"cycling"`. Defaults to `"driving"`. |
| `startNavigation` | bool | Start turn-by-turn navigation when possible. |
| `mapType` | string | The base map. |
| `showTraffic` | bool | Show traffic in Apple Maps. iOS only. |
| `preferGoogleMaps` | bool | Try Google Maps first on iOS. |
| `androidPackage` | string | Android package to target. |
| `useWebFallback` | bool | Open a web map when no native app is available. Defaults to `true`. |

### Legacy JavaScript methods

The original methods are still supported and now return promises:

```js
Maps.openAt(59.9117715, 10.7400957);
Maps.searchNearby("pizza");
Maps.searchNear(59.9117715, 10.7400957, "pizza");
```

### Result statuses

| Status | Meaning |
|---|---|
| `opened` | The platform handed the request to a map application or browser. |

Failures reject the promise with a user-facing message. There is no `failed`
status.

## UX triggers

### `<LaunchMaps>`

```xml
<LaunchMaps
    Latitude="59.9139"
    Longitude="10.7522"
    Label="Fuse"
    Zoom="16"
    MapType="Satellite" />
```

```xml
<LaunchMaps
    Query="pizza"
    NearLatitude="59.9139"
    NearLongitude="10.7522" />
```

Properties:

| Property | Type | Description |
|---|---|---|
| `Latitude` | string | Latitude of the pin. |
| `Longitude` | string | Longitude of the pin. |
| `Query` | string | A place name or address to search for. |
| `Label` | string | Optional label for the pin. |
| `Zoom` | int | Zoom level, 1–23. `0` uses the platform default. |
| `MapType` | `MapType` | `Standard`, `Satellite` or `Hybrid`. |
| `NearLatitude` | string | Latitude to search near, used with `Query`. |
| `NearLongitude` | string | Longitude to search near, used with `Query`. |
| `AndroidPackage` | string | Android package to target. |
| `PreferGoogleMaps` | bool | Try Google Maps first on iOS. |
| `UseWebFallback` | bool | Open a web map when no native app is available. Defaults to `true`. |

### `<LaunchDirections>`

```xml
<LaunchDirections
    Latitude="59.9139"
    Longitude="10.7522"
    DestinationLatitude="59.9117"
    DestinationLongitude="10.7401"
    DestinationLabel="Fuse"
    TravelMode="Walking" />
```

```xml
<LaunchDirections DestinationAddress="Some Street 1, Oslo" TravelMode="Transit" />
```

Properties:

| Property | Type | Description |
|---|---|---|
| `Latitude` | string | Origin latitude. Empty starts at the current location. |
| `Longitude` | string | Origin longitude. |
| `OriginLabel` | string | Optional origin label. |
| `DestinationLatitude` | string | Destination latitude. |
| `DestinationLongitude` | string | Destination longitude. |
| `DestinationLabel` | string | Optional destination label. |
| `DestinationAddress` | string | Destination address, used when coordinates are not set. |
| `TravelMode` | `MapTravelMode` | `Driving`, `Walking`, `Transit` or `Cycling`. |
| `StartNavigation` | bool | Start turn-by-turn navigation when possible. |
| `MapType` | `MapType` | The base map. |
| `ShowTraffic` | bool | Show traffic in Apple Maps. iOS only. |
| `PreferGoogleMaps` | bool | Try Google Maps first on iOS. |
| `AndroidPackage` | string | Android package to target. |
| `UseWebFallback` | bool | Open a web map when no native app is available. Defaults to `true`. |

The UX triggers are fire-and-forget. Use the JavaScript or C# API when you need
the launch result.

## C# API

```csharp
using Fuse;

var options = new MapLaunchOptions
{
    Location = new MapLocation(59.9117715, 10.7400957, "Fuse"),
    Zoom = 16
};

Fuse.Launcher.LaunchMaps(options).Then(
    status => { /* MapLaunchStatus.Opened */ },
    error => { /* Exception */ });
```

### `Fuse.Launcher.IsMapAvailable()`

Returns whether the platform can launch a native map application.

### `Fuse.Launcher.LaunchMaps(MapLaunchOptions)`

Returns `Future<MapLaunchStatus>`. Failures reject the future.

### `Fuse.Launcher.LaunchDirections(origin, destination[, mode])`

Returns `Future<MapLaunchStatus>`. Pass `null` as `origin` to start at the
current location.

### `MapLocation`

| Property | Type | Description |
|---|---|---|
| `Latitude` | double | Latitude in decimal degrees. |
| `Longitude` | double | Longitude in decimal degrees. |
| `Label` | string | Optional place name. |

### `MapLaunchOptions`

| Property | Type | Description |
|---|---|---|
| `Location` | `MapLocation` | A location to show. |
| `Query` | string | A free-text search query. |
| `SearchNear` | `MapLocation` | Search origin. |
| `Origin` | `MapLocation` | Directions origin. `null` means current location. |
| `Destination` | `MapLocation` | Directions destination coordinates. |
| `DestinationAddress` | string | Directions destination address. Ignored when `Destination` is set. |
| `TravelMode` | `MapTravelMode` | `Driving`, `Walking`, `Transit` or `Cycling`. |
| `StartNavigation` | bool | Start turn-by-turn navigation when possible. |
| `MapType` | `MapType` | `Standard`, `Satellite` or `Hybrid`. |
| `Zoom` | int | Zoom level, 1–23. `0` uses the platform default. |
| `ShowTraffic` | bool | Show traffic in Apple Maps. iOS only. |
| `PreferGoogleMaps` | bool | Try Google Maps first on iOS. |
| `AndroidPackage` | string | Android package to target. |
| `UseWebFallback` | bool | Open a web map when no native app is available. Defaults to `true`. |

When `Destination` or `DestinationAddress` is set, the options describe
directions and `Location`, `Query` and `SearchNear` are ignored.

### Legacy C# API

The original overloads are still supported:

```csharp
Fuse.Launcher.LaunchMaps(59.9117715, 10.7400957);
Fuse.Launcher.LaunchMaps("pizza");
Fuse.Launcher.LaunchMaps(59.9117715, 10.7400957, "pizza");
```

They are fire-and-forget and use the same URI building and platform behavior as
the new API.

## Platform behavior

### Android

- Showing a location or searching uses an implicit `ACTION_VIEW` intent with a
  `geo:` URI.
- Directions with `StartNavigation` and a coordinate destination use
  `google.navigation:` when Google Maps is the target.
- Other directions use the Google Maps directions URL, which opens Google Maps
  or a browser.
- `androidPackage` targets a specific package. If the package is not installed,
  the launcher retries with the default map application.
- If no native handler exists, the launcher opens the Google Maps web URL when
  `useWebFallback` is enabled.
- The `geo:` intent has no map-type parameter, so `MapType` is not applied to
  native Android pins.

### iOS

- Showing a location or searching uses an Apple Maps link.
- Directions to coordinates use MapKit, which supports driving, walking, transit
  and cycling, map types, traffic, labeled origin/destination and the current
  location as origin.
- Directions to an address use the Apple Maps link.
- `preferGoogleMaps` tries `comgooglemaps://` first and falls back to Apple Maps.
- Failures are detected with `openURL:options:completionHandler:`; when
  `useWebFallback` is enabled the launcher then opens the Google Maps web URL.
- `startNavigation` is ignored; Maps opens the directions view instead.

### Other platforms

`IsMapAvailable()` returns `false` and `Launch` rejects with
`"Maps are not supported on this platform."`.

## Limitations

- Android `geo:` has no map-type parameter.
- Apple Maps links have no cycling flag; MapKit is used for cycling when
  available, and the link fallback uses walking.
- `startNavigation` only applies to Android/Google Maps URLs.
- `showTraffic` only applies to Apple Maps directions.
- Origin addresses are not supported; provide origin coordinates or omit the
  origin to use the current location.
- The launcher does not embed a map view. Use `Fuse.Maps` for an in-app map.

## Testing

```sh
cd fuselibs
uno test Source/Fuse.Launcher/Tests/Fuse.Launcher.Test.unoproj
```

The manual launcher page is `Tests/ManualTests/ManualTestingApp/Singles/Launchers.ux`.
