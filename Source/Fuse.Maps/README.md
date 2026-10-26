# Fuse.Maps

Native maps for [Fuse](https://github.com/fuse-open/fuse) apps: **Google Maps on
Android** and **Apple Maps on iOS**.

`Fuse.Maps` gives you a `MapView` that hosts the platform's own map control,
plus Fuse nodes for markers, polygons, polylines, circles, image overlays and
custom tile layers. It also exposes camera control, location display,
geocoding and route calculation.

```xml
<NativeViewHost>
	<MapView Latitude="59.9115573" Longitude="10.73888" Zoom="12">
		<MapMarker Label="Fuse HQ" Latitude="59.9115573" Longitude="10.73888" />
	</MapView>
</NativeViewHost>
```

## Features

| Feature                                                | Android                    | iOS                |
| ------------------------------------------------------ | -------------------------- | ------------------ |
| Map, camera, zoom/tilt/bearing                         | Google Maps                | MapKit             |
| Markers: label, snippet, icon, color, drag, selection  | Yes                        | Yes                |
| Overlays: polyline, polygon (+holes), circle           | Yes                        | Yes                |
| Image (ground) overlays                                | `GroundOverlay`            | custom `MKOverlay` |
| Custom raster tile layers                              | `TileOverlay`              | `MKTileOverlay`    |
| Camera animation, bounds fitting, padding, zoom limits | Yes                        | Yes                |
| User location dot, tracking button, compass            | Yes                        | Yes                |
| Geocoding / reverse geocoding                          | `Geocoder`                 | `CLGeocoder`       |
| Routing (promise and `MapRoute` node)                  | Google Directions REST API | `MKDirections`     |
| Snapshots                                              | Yes                        | Yes                |
| Desktop                                                | Placeholder only           | Placeholder only   |

## Installation

Add `Fuse.Maps` to the `references`/`projects` of your `.unoproj`:

```json
"references": [
	"Fuse.Maps",
	"Fuse",
	"FuseJS"
]
```

### Android: API key

Google Maps requires an API key. Create one in the
[Google Cloud Console](https://console.cloud.google.com/google/maps-apis) with
**Maps SDK for Android** enabled, then put it in your project file:

```json
"Android": {
	"Geo": {
		"ApiKey": "YOUR_ANDROID_MAPS_KEY"
	}
}
```

Fuse writes this into the manifest as `com.google.android.geo.API_KEY`, which
is also what `Fuse.Maps` reads at runtime for route calculation.

If you use `MapView.CalculateRoute` / JS `calculateRoute()`, enable the
**Directions API** for the same key as well.

### iOS: location usage description

If you set `ShowMyLocation="true"`, iOS requires a usage description in
`Info.plist`. Add it to your project file:

```json
"iOS": {
	"PList": {
		"NSLocationWhenInUseUsageDescription": "This app shows your location on the map."
	}
}
```

No API key is needed on iOS.

## Basic usage

`MapView` is a native control, so it must be inside a `NativeViewHost`:

```xml
<NativeViewHost>
	<MapView Latitude="59.9115573" Longitude="10.73888" Zoom="12" />
</NativeViewHost>
```

The camera is controlled by these two-way bindable properties:

| Property                | Meaning                                                    |
| ----------------------- | ---------------------------------------------------------- |
| `Latitude`, `Longitude` | Center of the map                                          |
| `Zoom`                  | Google-style zoom level (`0`–`21`)                         |
| `Tilt`                  | Camera pitch in degrees (up to 67.5 on Android, 75 on iOS) |
| `Bearing`               | Rotation relative to true north, in degrees                |

```xml
<JavaScript>
	var Observable = require("FuseJS/Observable");
	module.exports = {
		lat: Observable(59.9115573),
		lng: Observable(10.73888)
	};
</JavaScript>

<NativeViewHost>
	<MapView Latitude="{lat}" Longitude="{lng}" Zoom="12" />
</NativeViewHost>
```

### Rendering style

```xml
<MapView Style="Satellite" />   <!-- Normal, Satellite, Hybrid, Terrain -->
```

`Terrain` is supported by Google Maps on Android and by `Fuse.Maps.Google` on
iOS. Native Apple Maps has no terrain style, so `Terrain` falls back to
`Normal` there.

### Gestures and zoom limits

```xml
<MapView AllowZoom="true" AllowTilt="true" AllowRotate="true" AllowScroll="true"
         MinZoom="3" MaxZoom="18" />
```

`Allow*` only controls user gestures — the camera can still be changed through
the API. All four default to `true`; `MinZoom` defaults to `0` and `MaxZoom` to
`21`.

### Map padding

`MapPadding` reserves space between the map edges and the camera target. This is
useful when a toolbar, bottom sheet or side panel covers part of the map. It is
a `float4` in `(left, top, right, bottom)` order, in points:

```xml
<MapView MapPadding="0,0,0,120" />
```

> Note: `MapPadding` is separate from the layout `Padding` that `MapView`
> inherits from `Element`. The inherited `Padding` affects Fuse layout, not the
> map camera.

### Readiness

The native map loads asynchronously. `IsReady` becomes `true` once it is usable,
and the `Ready` event is raised once:

```xml
<MapView ux:Name="map" Ready="{onMapReady}" />

<JavaScript>
	function onMapReady() {
		// Safe to call showAllMarkers(), snapshot(), etc.
	}
	module.exports = { onMapReady: onMapReady };
</JavaScript>
```

Calls that need a loaded map (`snapshot()`, `showAllMarkers()`) are queued until
readiness; geocoding and routing only need the native control to exist.

## Markers

### Declarative

```xml
<MapView Latitude="59.9" Longitude="10.7" Zoom="12">
	<MapMarker Label="Fuse HQ"
	           Snippet="Oslo, Norway"
	           Latitude="59.9115573"
	           Longitude="10.73888" />
</MapView>
```

A marker without `IconFile` uses the platform's default pin.

### From JavaScript

Use `Each` with an `Observable` of marker data:

```js
var Observable = require("FuseJS/Observable");
var markers = Observable();

markers.add({ latitude: 59.9115573, longitude: 10.73888, label: "Fuse HQ" });

module.exports = { markers: markers };
```

```xml
<MapView Latitude="59.9" Longitude="10.7" Zoom="12">
	<Each Items="{markers}">
		<MapMarker Latitude="{latitude}" Longitude="{longitude}" Label="{label}" />
	</Each>
</MapView>
```

Or replace the whole set from JS:

```js
map.setMarkers([
  {
    latitude: 59.9115573,
    longitude: 10.73888,
    label: "Fuse HQ",
    snippet: "Oslo",
  },
]);
```

`setMarkers` accepts a single object or an array and replaces the existing
markers. Supported fields:

```json
{
  "latitude": 0,
  "longitude": 0,
  "label": "Hello",
  "snippet": "Extra callout line",
  "iconFile": "Assets/marker.png",
  "iconAnchorX": 0.5,
  "iconAnchorY": 1.0,
  "color": "#ff3300",
  "draggable": false
}
```

### Icons and colors

```xml
<MapMarker IconFile="Assets/pin.png" IconAnchorX="0.5" IconAnchorY="1.0" />
```

`IconAnchorX`/`IconAnchorY` are normalized `(0..1)` image coordinates of the
point that sits on the map location. The default is `(0.5, 0.5)`.

`Color` tints the **default** pin; it is ignored when `IconFile` is set. A fully
transparent color (the default) means the platform's default color. On Android
the tint is derived from the color's hue, matching how Google Maps styles its
default marker.

### Selection

```xml
<MapView ux:Name="map" MarkerSelected="{onMarkerSelected}" />
```

```js
map.selectMarker(id); // id from a marker event
map.deselectMarker(id);
```

From Uno: `map.SelectMarker(marker)` / `map.DeselectMarker(marker)`.

### Dragging

```xml
<MapMarker ux:Name="pin" Latitude="59.9" Longitude="10.7" Draggable="true"
           DragEnded="{onDragEnded}" />
```

When the user drags the marker, `Latitude` and `Longitude` are updated and
`DragEnded` is raised. `Dragging` fires continuously while moving. On iOS
dragging requires `AllowScroll` to be `true` (MapKit behavior).

### Marker events

On `MapView`: `MarkerTapped`, `MarkerSelected`, `MarkerDeselected`,
`MarkerDragStarted`, `MarkerDragged`, `MarkerDragEnded`.

On `MapMarker`: `Tapped`, `Selected`, `Deselected`, `DragStarted`, `Dragging`,
`DragEnded`.

All marker event arguments (`MarkerEventArgs`) contain `label`, `id`,
`latitude` and `longitude`:

```js
function onMarkerTapped(args) {
  console.log(args.id, args.label, args.latitude, args.longitude);
}
```

## Overlays

`MapOverlay` draws geometry on top of the map. `Type` selects the kind:

| Type       | Uses                                                                    |
| ---------- | ----------------------------------------------------------------------- |
| `Polyline` | `Coordinates`                                                           |
| `Polygon`  | `Coordinates` (+ optional `Holes`)                                      |
| `Circle`   | `CenterLatitude`, `CenterLongitude`, `Radius` (meters)                  |
| `Image`    | `ImageFile` + `MinLatitude`/`MinLongitude`/`MaxLatitude`/`MaxLongitude` |
| `Tile`     | `TileUrlTemplate` + `TileMinZoom`/`TileMaxZoom`                         |

### Polyline

```xml
<MapView Latitude="-6.914742" Longitude="107.609820" Zoom="14">
	<MapOverlay Type="Polyline" StrokeColor="Blue" LineWidth="5">
		<Coordinate Latitude="-6.914742" Longitude="107.609820" />
		<Coordinate Latitude="-6.915850" Longitude="107.609929" />
		<Coordinate Latitude="-6.916959" Longitude="107.611009" />
	</MapOverlay>
</MapView>
```

### Polygon

```xml
<MapOverlay Type="Polygon" StrokeColor="#1e88e5" FillColor="#1e88e5" Alpha="0.4">
	<Coordinate Latitude="59.80" Longitude="10.60" />
	<Coordinate Latitude="59.80" Longitude="10.80" />
	<Coordinate Latitude="60.00" Longitude="10.80" />
</MapOverlay>
```

Polygons can also have holes. They can be added programmatically or from
JavaScript, since this UX version does not support property blocks such as
`<MapOverlay.Holes>`:

```js
map.setOverlays([
  {
    overlayType: "polygon",
    strokeColor: "#1e88e5",
    fillColor: "#1e88e5",
    alpha: 0.4,
    coordinates: [
      { latitude: 59.8, longitude: 10.6 },
      { latitude: 59.8, longitude: 10.8 },
      { latitude: 60.0, longitude: 10.8 },
    ],
    holes: [
      [
        { latitude: 59.9, longitude: 10.7 },
        { latitude: 59.9, longitude: 10.75 },
        { latitude: 59.95, longitude: 10.7 },
      ],
    ],
  },
]);
```

From Uno: `overlay.Holes.Add(new MapOverlayHole())` and populate its
`Coordinates`.

### Circle

```xml
<MapOverlay Type="Circle"
            CenterLatitude="59.91" CenterLongitude="10.74"
            Radius="500" StrokeColor="Red" FillColor="Red" Alpha="0.3" />
```

### Image overlay

```xml
<MapOverlay Type="Image" ImageFile="Assets/floorplan.png"
            MinLatitude="59.90" MinLongitude="10.70"
            MaxLatitude="59.93" MaxLongitude="10.75" Alpha="0.8" />
```

### Tile overlay

```xml
<MapOverlay Type="Tile"
            TileUrlTemplate="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
            TileMinZoom="1" TileMaxZoom="19" />
```

`{x}`, `{y}` and `{z}` are substituted per tile. Respect the tile provider's
usage policy and attribution requirements.

### Styling and ordering

| Property                   | Effect                                                    |
| -------------------------- | --------------------------------------------------------- |
| `StrokeColor`, `FillColor` | Colors (`float4` / CSS color strings in UX/JS)            |
| `LineWidth`                | Stroke width; Android uses screen pixels, iOS uses points |
| `StartCap`, `EndCap`       | `Round`, `Butt`, `Square`                                 |
| `JoinType`                 | `Round`, `Bevel`, `Miter`                                 |
| `DashPattern`              | `int2` of dash length and gap; `0,0` = solid              |
| `Geodesic`                 | Draw the shortest path on the globe                       |
| `ZIndex`                   | Higher values draw on top                                 |
| `Alpha`                    | `0`–`1` opacity                                           |
| `Visible`                  | Hides the overlay and stops it receiving taps             |

Overlay tap handlers receive no payload; attach one handler per overlay:

```xml
<MapOverlay Type="Polygon" Tapped="{onOverlayTapped}">...</MapOverlay>
```

Image and tile overlays are not tappable on either platform.

## Camera control

### From Uno

```xml
<MapView ux:Name="map" />
```

```uno
// Move instantly
map.SetLocation(59.9, 10.7);

// Animate: lat, lng, zoom, tilt, bearing, duration (seconds)
map.AnimateTo(59.9, 10.7, 14, 0, 0, 0.6);
map.CancelAnimation();

// Fit a rectangle
map.ShowBounds(59.8, 10.6, 60.0, 10.8);

// Relative moves
map.ZoomBy(1); // positive zooms in
map.ScrollBy(0, -80); // pan by points
```

`VisibleBounds` reports the current visible area, and `BoundsChanged`
(`MapBoundsEventArgs` with `minLatitude`, `minLongitude`, `maxLatitude`,
`maxLongitude`) fires when it changes:

```xml
<MapView BoundsChanged="{onBoundsChanged}" />
```

```js
function onBoundsChanged(bounds) {
  console.log(bounds.minLatitude, bounds.maxLongitude);
}
```

### From JavaScript

```js
map.setLocation(59.9, 10.7);
map.setZoom(14);
map.setTilt(30);
map.setBearing(45);

map.animateTo(59.9, 10.7, 14, 30, 45, 0.6);
map.cancelAnimation();
map.showBounds(59.8, 10.6, 60.0, 10.8);
map.zoomBy(1);
map.scrollBy(0, -80);
map.showAllMarkers(); // fit all markers in view
```

## User location

```xml
<MapView ShowMyLocation="true"
         ShowMyLocationButton="true"
         ShowCompass="true" />
```

- Android requests `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` at runtime
  when `ShowMyLocation` is enabled.
- iOS requests when-in-use authorization. Add
  `NSLocationWhenInUseUsageDescription` to your `Info.plist` (see
  [Installation](#ios-location-usage-description)).
- `ShowMyLocationButton` adds the platform's tracking button: Google's built-in
  button on Android, `MKUserTrackingButton` on iOS. On Android it has an effect
  only when `ShowMyLocation` is enabled.
- `ShowCompass` displays the map compass.

## Snapshots

`snapshot()` returns a promise resolving to the path of a PNG written to app
storage:

```js
map
  .snapshot()
  .then(function (path) {
    console.log("Saved to " + path);
  })
  .catch(function (error) {
    console.log("Snapshot failed: " + error);
  });
```

The snapshot includes markers.

## Geocoding

```js
map
  .geocode("Oslo, Norway")
  .then(function (places) {
    // places: [{ name, address, latitude, longitude }, ...]
    console.log(places[0].latitude, places[0].longitude);
  })
  .catch(function (error) {
    console.log("Geocoding failed: " + error);
  });

map.reverseGeocode(59.9115573, 10.73888).then(function (places) {
  console.log(places[0].address);
});
```

From Uno: `map.Geocode(query)` and `map.ReverseGeocode(lat, lng)` return
`Future<MapPlace[]>`.

Geocoding does not require the map to be ready and does not use an API key on
either platform. Results depend on the platform's geocoder and network
availability.

## Routing

```js
map
  .calculateRoute(59.9115573, 10.73888, 59.92, 10.75, "driving")
  .then(function (route) {
    // route.polyline: [{ latitude, longitude }, ...]
    // route.distance: meters
    // route.duration: seconds
    // route.name:     human readable summary, if available

    map.setOverlays([
      {
        overlayType: "polyline",
        coordinates: route.polyline,
        strokeColor: "#2196F3",
        lineWidth: 6,
        zIndex: 10,
      },
    ]);
  })
  .catch(function (error) {
    console.log("Routing failed: " + error);
  });
```

`mode` is optional and is one of `"driving"`, `"walking"`, `"transit"` or
`"cycling"`; it defaults to `"driving"`.

From Uno: `map.CalculateRoute(fromLat, fromLng, toLat, toLng, RouteMode.Driving)`
returns `Future<MapRouteResult>`.

Platform notes:

- **Android** uses the Google Directions REST API. The key from
  `Android.Geo.ApiKey` is read from the manifest, and the **Directions API**
  must be enabled for it.
- **iOS** uses `MKDirections` and needs no key. MapKit has no cycling transport
  type, so `RouteMode.Cycling` falls back to walking.

### Drawing routes with `MapRoute`

For declarative app UIs, use the `MapRoute` node. It requests the route
automatically when it is rooted or when its endpoints or mode change, draws the
polyline on the map, and exposes the result as properties:

```xml
<NativeViewHost>
	<MapView Latitude="59.9" Longitude="10.7" Zoom="12">
		<MapRoute ux:Name="route"
		          FromLatitude="59.9115573" FromLongitude="10.73888"
		          ToLatitude="59.95"       ToLongitude="10.78"
		          Mode="Driving"
		          StrokeColor="#2196F3" LineWidth="6"
		          Calculated="{onCalculated}"
		          Failed="{onFailed}" />
	</MapView>
</NativeViewHost>
```

```js
function onCalculated(args) {
  // The node's Distance, Duration and Polyline have been updated.
  console.log(args.distance, args.duration);
}

function onFailed(args) {
  console.log("Route failed: " + args.error);
}

module.exports = { onCalculated: onCalculated, onFailed: onFailed };
```

With `ux:Name="route"` you can bind `route.Distance`, `route.Duration`,
`route.IsCalculated`, `route.IsCalculating` and `route.Error` in UX. From Uno,
call `route.Refresh()` to request a new calculation.

A `MapRoute` has these properties: `FromLatitude`, `FromLongitude`,
`ToLatitude`, `ToLongitude`, `Mode`, `StrokeColor`, `LineWidth`, `ZIndex`,
`Alpha`, `Visible`, plus the read-only `Distance`, `Duration`, `Polyline`,
`IsCalculated`, `IsCalculating` and `Error`.

Multiple routes can coexist by adding more `MapRoute` nodes. From Uno, use
`map.Routes`, or `map.ClearRoutes()` to remove them all.

To create or replace routes dynamically from JavaScript, use `setRoutes`:

```js
map.setRoutes([
  {
    fromLatitude: 59.9115573,
    fromLongitude: 10.73888,
    toLatitude: 59.95,
    toLongitude: 10.78,
    mode: "driving",
    strokeColor: "#2196F3",
    lineWidth: 6,
  },
]);
```

`setRoutes` replaces the existing route nodes. To get the route data (polyline,
distance, duration) in JavaScript, use the `calculateRoute()` promise instead
and draw the result with `setOverlays`.

## JavaScript API reference

| Method                                                                  | Description                         |
| ----------------------------------------------------------------------- | ----------------------------------- |
| `setLocation(latitude, longitude)`                                      | Pan instantly                       |
| `setZoom(zoom)`                                                         | Set zoom level                      |
| `setTilt(degrees)`                                                      | Set tilt                            |
| `setBearing(degrees)`                                                   | Set bearing                         |
| `animateTo(latitude, longitude[, zoom[, tilt[, bearing[, duration]]]])` | Animated camera move                |
| `cancelAnimation()`                                                     | Stop the current animation          |
| `zoomBy(delta)`                                                         | Change zoom by `delta`              |
| `scrollBy(dx, dy)`                                                      | Pan by a screen offset              |
| `showBounds(minLat, minLng, maxLat, maxLng)`                            | Fit a rectangle                     |
| `showAllMarkers()`                                                      | Fit all markers                     |
| `setMarkers(markers)`                                                   | Replace all markers                 |
| `setRoutes(routes)`                                                     | Replace all route nodes             |
| `selectMarker(id)` / `deselectMarker(id)`                               | Show/hide a marker callout          |
| `setOverlays(overlays)`                                                 | Replace all overlays                |
| `snapshot()`                                                            | `Promise<string>` with the PNG path |
| `geocode(query)`                                                        | `Promise<MapPlace[]>`               |
| `reverseGeocode(latitude, longitude)`                                   | `Promise<MapPlace[]>`               |
| `calculateRoute(fromLat, fromLng, toLat, toLng[, mode])`                | `Promise<MapRouteResult>`           |

## Uno API reference

`MapView` exposes the same functionality from Uno. `showAllMarkers()` and
`snapshot()` are JavaScript-only.

### Properties

| Property                                                | Type                  | Default   | Description                                |
| ------------------------------------------------------- | --------------------- | --------- | ------------------------------------------ |
| `Latitude`, `Longitude`                                 | `double`              | `0`       | Camera center                              |
| `Zoom`                                                  | `double`              | `0`       | Zoom level                                 |
| `Tilt`                                                  | `double`              | `0`       | Pitch in degrees                           |
| `Bearing`                                               | `double`              | `0`       | Rotation in degrees                        |
| `Style`                                                 | `MapStyle`            | `Normal`  | `Normal`, `Satellite`, `Hybrid`, `Terrain` |
| `Provider`                                              | `string`              | platform  | Map provider name                          |
| `MinZoom`, `MaxZoom`                                    | `double`              | `0`, `21` | Zoom limits                                |
| `MapPadding`                                            | `float4`              | `0,0,0,0` | `(left, top, right, bottom)` insets        |
| `AllowZoom`, `AllowTilt`, `AllowRotate`, `AllowScroll`  | `bool`                | `true`    | User gestures                              |
| `ShowMyLocation`, `ShowMyLocationButton`, `ShowCompass` | `bool`                | `false`   | Map UI                                     |
| `IsReady`                                               | `bool`                | `false`   | Native map loaded                          |
| `VisibleBounds`                                         | `MapBounds`           | —         | Current visible area                       |
| `Markers`, `Overlays`, `Routes`                         | `ObservableList<...>` | empty     | Content collections                        |

### Methods

| Method                                                                 | Description                |
| ---------------------------------------------------------------------- | -------------------------- |
| `SetLocation(lat, lng)`                                                | Pan instantly              |
| `AnimateTo(lat, lng, zoom, tilt, bearing, duration)`                   | Animated camera move       |
| `CancelAnimation()`                                                    | Stop the current animation |
| `ShowBounds(minLat, minLng, maxLat, maxLng)` / `ShowBounds(MapBounds)` | Fit an area                |
| `ZoomBy(delta)`                                                        | Change zoom by `delta`     |
| `ScrollBy(dx, dy)`                                                     | Pan by an offset           |
| `SelectMarker(MapMarker)` / `DeselectMarker(MapMarker)`                | Show/hide a marker callout |
| `ClearMarkers()` / `ClearOverlays()` / `ClearRoutes()`                 | Remove content             |
| `Geocode(query)`                                                       | `Future<MapPlace[]>`       |
| `ReverseGeocode(lat, lng)`                                             | `Future<MapPlace[]>`       |
| `CalculateRoute(fromLat, fromLng, toLat, toLng, RouteMode)`            | `Future<MapRouteResult>`   |

### Events

`Ready`, `MarkerTapped`, `MarkerSelected`, `MarkerDeselected`,
`MarkerDragStarted`, `MarkerDragged`, `MarkerDragEnded`, `LocationTapped`,
`LocationLongPressed`, `BoundsChanged`.

## Platform differences and limitations

- **Desktop** targets show a placeholder; `MapView` is mobile only.
- **Holes** cannot be declared in UX in this Fuse version (dotted property
  blocks are not supported). Use `setOverlays` from JS or the Uno `Holes` list.
- **Overlay tap payloads** are empty; use a separate handler per overlay.
- **Image/tile overlays** cannot be tapped.
- **`LineWidth` and `ScrollBy`** use screen pixels on Android and points on iOS.
- **`Color`** only affects default pins, and is hue-based on Android.
- **iOS** requires the deployment target used by this Uno version (13.0 by
  default). `MKMarkerAnnotationView` and `MKUserTrackingButton` need iOS 11+.
- **Android routing** needs both the Maps SDK and Directions API enabled on the
  key.
- Map providers impose their own attribution and usage requirements (especially
  for tile overlays); follow them.

## Custom map providers (advanced)

`Fuse.Maps` uses a provider registry. The platform's native provider (Google
Maps on Android, Apple Maps on iOS) is registered automatically; additional
implementations can be registered before any `MapView` is created and selected
per map.

A provider implements `IMapProvider`, returns an `IMapView`, and reports user
interaction and results through the `IMapViewHost` it receives:

See [`Source/Fuse.Maps.Google`](../Fuse.Maps.Google) for a complete provider
implementation (Google Maps on iOS, delegating to the native provider on
Android).

```uno
public class MyMapProvider : IMapProvider
{
	public string Name { get { return "MyProvider"; } }

	public IMapView Create(IMapViewHost host)
	{
		return new MyMapView(host);
	}
}
```

```uno
MapProviders.Register(new MyMapProvider());

// Optional: use it when MapView.Provider is not set
MapProviders.Default = "MyProvider";
```

```xml
<MapView Provider="MyProvider" />
```

`Provider` must be set before the map view is created. If the named provider
is not registered, a diagnostic is reported and the platform default is used.

## Package layout

```
Source/Fuse.Maps/
	MapView.uno              MapView, IMapView, MapConfig
	MapView.Events.uno       Event arguments
	MapView.ScriptClass.uno  JavaScript API
	MapMarker.uno            MapMarker
	MapOverlay.uno           MapOverlay, MapOverlayHole, Coordinate
	MapBounds.uno            MapBounds
	MapPlace.uno             MapPlace, MapRouteResult, RouteMode
	MapRoute.uno             MapRoute node, RouteEventArgs
	Provider.uno             IMapView, IMapViewHost, IMapProvider, MapProviders
	MarkerState.uno          Marker diffing state (internal)
	MarkerIconCache.uno      Icon/image file cache (internal)
	Android/                 Google Maps implementation
	iOS/                     MapKit implementation
	Docs/                    Documentation included in API docs
```

## Development

The package is written in Uno, Fuse's own language, which compiles to C++ and
native platform code. It is built as part of Fuse. To verify that the sources
compile without a full native build:

```sh
uno build android -g -N path/to/a/project/referencing/Fuse.Maps
uno build ios -g -N path/to/a/project/referencing/Fuse.Maps
```

`-g` generates code without invoking the native toolchain, and `-N` skips the
native build step. A device/simulator build is still required to validate the
Java and Objective-C parts.

## License

Part of the Fuse Open project. See the repository's `LICENSE.txt`.
