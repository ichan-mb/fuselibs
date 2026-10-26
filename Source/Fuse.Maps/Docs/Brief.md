The `MapView` allows you to present annotated, interactive world-wide maps to the user using the mapping APIs native to the platform: Google Maps on Android and Apple Maps on iOS.

The `MapView` is a native control, and thus needs to be contained in a @NativeViewHost to be displayed. As with other native mobile controls, there currently isn't a `MapView` available for desktop targets.

_Note:_ You need to add a reference to `Fuse.Maps` to your `.unoproj`:

```json
"references": [
	"Fuse.Maps",
	"Fuse",
	"FuseJS"
]
```

Getting a `MapView` included in your app is straight forward: Simply include the node in your UX as you normally would with a native control:

```XML
<NativeViewHost>
	<MapView/>
</NativeViewHost>
```

## Camera

To initialize and manipulate the map camera, use the [Latitude](api:fuse/controls/mapview/latitude), [Longitude](api:fuse/controls/mapview/longitude), [Zoom](api:fuse/controls/mapview/zoom), [Tilt](api:fuse/controls/mapview/tilt) and [Bearing](api:fuse/controls/mapview/bearing) properties, all of which are two-way bindable.
`Zoom` follows Google's "zoom levels", which can be read about in detail [here](https://developers.google.com/maps/documentation/static-maps/intro#Zoomlevels).

```XML
<NativeViewHost>
	<MapView Latitude="{latitude}" Longitude="{longitude}" Zoom="12" />
</NativeViewHost>
```

The camera can also be moved imperatively:

```js
// Instantly
map.setLocation(59.9115573, 10.73888);

// Animated. The last argument is the duration in seconds.
map.animateTo(59.9115573, 10.73888, 14, 0, 0, 0.6);
map.cancelAnimation();

// Fit a rectangle (south-west and north-east corners)
map.showBounds(59.8, 10.6, 60.0, 10.8);

// Relative moves
map.zoomBy(1); // positive values zoom in
map.scrollBy(0, -80); // pan by a screen offset
```

From Uno code, the same operations are available as `SetLocation`,
`AnimateTo`, `CancelAnimation`, `ShowBounds`, `ZoomBy` and `ScrollBy`.

`MinZoom` and `MaxZoom` limit how far the user can zoom, while the
[AllowZoom](api:fuse/controls/mapview/allowzoom), [AllowTilt](api:fuse/controls/mapview/allowtilt), [AllowRotate](api:fuse/controls/mapview/allowrotate) and [AllowScroll](api:fuse/controls/mapview/allowscroll) properties control the gestures. These only restrict user interaction; the camera can still be changed through the API. The gesture properties default to `true`, `MinZoom` defaults to `0` and `MaxZoom` to `21`.

```XML
<MapView MinZoom="3" MaxZoom="18" AllowRotate="false" />
```

## Layout and padding

`MapPadding` reserves space between the edges of the map and its camera target, which is useful when a toolbar, sheet or panel covers part of the map. It is a `float4` in `(left, top, right, bottom)` order, measured in points:

```XML
<MapView MapPadding="0,0,0,120" />
```

_Note:_ `MapPadding` is separate from the layout `Padding` inherited from `Element`; the latter affects Fuse layout, not the map.

## Readiness

The native map loads asynchronously. [IsReady](api:fuse/controls/mapview/isready) becomes `true` when it is usable, and the `Ready` event is raised once:

```XML
<MapView ux:Name="map" Ready="{onMapReady}" />

<JavaScript>
	function onMapReady() {
		map.showAllMarkers();
	}
	module.exports = { onMapReady: onMapReady };
</JavaScript>
```

Operations that need a loaded map, such as `snapshot()` and `showAllMarkers()`, are deferred until the map is ready. If the `MapView` is disposed first, `snapshot()` rejects instead of hanging.

## Styles

The map can be further customized by setting the rendering style using the [Style](api:fuse/controls/mapview/style) property.
Options are `Normal`, `Satellite`, `Hybrid` and `Terrain`.

```XML
<MapView Style="Satellite" />
```

`Terrain` is supported by Google Maps on Android and by `Fuse.Maps.Google` on iOS. The native Apple Maps provider does not expose a terrain style, so `Terrain` falls back to `Normal` there.

## Markers

To annotate the map with labelled markers, see @MapMarker.

```XML
<NativeViewHost>
	<MapView Latitude="59.9115573" Longitude="10.73888" Zoom="12">
		<MapMarker Label="Fuse HQ"
		           Snippet="Oslo, Norway"
		           Latitude="59.9115573"
		           Longitude="10.73888" />
	</MapView>
</NativeViewHost>
```

For dynamic markers, bind an `Observable` with `Each`:

```XML
<Each Items="{markers}">
	<MapMarker Latitude="{latitude}" Longitude="{longitude}" Label="{label}"
	           Snippet="{snippet}" Tapped="{onMarkerTapped}" />
</Each>
```

Markers can also be replaced from JavaScript with `setMarkers(markers)`. Each marker object supports `latitude`, `longitude`, `label`, `snippet`, `iconFile`, `iconAnchorX`, `iconAnchorY`, `color` and `draggable`.

A marker without an `IconFile` uses the platform's default pin. `Color` tints that default pin and is ignored when an icon is supplied.

Markers can be selected and dragged:

```XML
<MapMarker Latitude="59.9" Longitude="10.7" Draggable="true" DragEnded="{onDragEnded}" />
```

```js
map.selectMarker(id); // id is provided in marker event arguments
map.deselectMarker(id);
```

Marker event arguments contain `label`, `id`, `latitude` and `longitude`:

```js
function onMarkerTapped(args) {
  console.log(args.id + ": " + args.label);
}
```

## Overlays

To draw shapes on the map, see @MapOverlay. Overlays support polylines, polygons (including holes), circles, geo-referenced images and custom raster tile layers.

```XML
<NativeViewHost>
	<MapView Latitude="-6.914742" Longitude="107.609820" Zoom="14">
		<MapOverlay Type="Polyline" StrokeColor="Blue" LineWidth="5">
			<Coordinate Latitude="-6.914742" Longitude="107.609820" />
			<Coordinate Latitude="-6.915850" Longitude="107.609929" />
			<Coordinate Latitude="-6.916959" Longitude="107.611009" />
		</MapOverlay>
	</MapView>
</NativeViewHost>
```

Overlays support `ZIndex`, `Alpha` and `Visible` for ordering and fading, and `Tapped` for polylines, polygons and circles. Image and tile overlays are not tappable.

Polygon holes and the more complex overlay types are easiest to create from JavaScript with `setOverlays(overlays)`:

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

_Note:_ This Fuse version does not support property blocks such as `<MapOverlay.Holes>`, so holes must be added from JavaScript or from Uno through the `Holes` list.

## User location

To show the user's location, set [ShowMyLocation](api:fuse/controls/mapview/showmylocation) to `true`. [ShowMyLocationButton](api:fuse/controls/mapview/showmylocationbutton) adds the platform's button for focusing the camera on the user, and [ShowCompass](api:fuse/controls/mapview/showcompass) shows the map compass. On Android the my-location button has an effect only when `ShowMyLocation` is enabled.

```XML
<MapView ShowMyLocation="true" ShowMyLocationButton="true" ShowCompass="true" />
```

Android requests the location permissions at runtime. On iOS you must add a usage description to your `Info.plist`:

```json
"iOS": {
	"PList": {
		"NSLocationWhenInUseUsageDescription": "This app shows your location on the map."
	}
}
```

## Geocoding and routing

`MapView` can look up addresses and calculate routes. Both return promises from JavaScript:

```js
map.geocode("Oslo, Norway").then(function (places) {
  // places: [{ name, address, latitude, longitude }, ...]
});

map.reverseGeocode(59.9115573, 10.73888).then(function (places) {
  console.log(places[0].address);
});

map
  .calculateRoute(59.9115573, 10.73888, 59.92, 10.75, "driving")
  .then(function (route) {
    // route.polyline: [{ latitude, longitude }, ...]
    // route.distance: meters
    // route.duration: seconds
    // route.name:     route summary, if available
  });
```

The route mode is optional and is one of `"driving"`, `"walking"`, `"transit"` or `"cycling"`.

From Uno, use `Geocode`, `ReverseGeocode` and `CalculateRoute`, which return `Future<MapPlace[]>` and `Future<MapRouteResult>`.

_Note:_ On Android, routing uses the Google Directions REST API. The key configured with `Android.Geo.ApiKey` is used, and the **Directions API** must be enabled for that key. On iOS, routing uses `MKDirections` and needs no key; since MapKit has no cycling transport type, `Cycling` falls back to walking.

Routing can also be done declaratively with the @MapRoute node. It requests the route when it is rooted or when its endpoints or `Mode` change, and draws the result automatically:

```XML
<NativeViewHost>
	<MapView Latitude="59.9" Longitude="10.7" Zoom="12">
		<MapRoute FromLatitude="59.9115573" FromLongitude="10.73888"
		          ToLatitude="59.95"       ToLongitude="10.78"
		          Mode="Driving" StrokeColor="Blue" LineWidth="6" />
	</MapView>
</NativeViewHost>
```

The node exposes `Distance`, `Duration`, `Polyline`, `IsCalculated`, `IsCalculating` and `Error`, and raises `Calculated` and `Failed` events. Call `Refresh()` to request a new calculation. Multiple routes can coexist by adding more `MapRoute` nodes, and Uno can manage them through the `Routes` collection or `ClearRoutes()`.

From JavaScript, `setRoutes(routes)` replaces the current routes with new ones created from plain objects:

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

## Snapshots

`snapshot()` returns a promise resolving to the path of a PNG file containing the map and its markers:

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

## Events

| Event                                                     | Description                                                                                    |
| --------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `Ready`                                                   | The native map has loaded                                                                      |
| `MarkerTapped`                                            | A marker was tapped                                                                            |
| `MarkerSelected` / `MarkerDeselected`                     | A marker callout was shown or hidden                                                           |
| `MarkerDragStarted` / `MarkerDragged` / `MarkerDragEnded` | A draggable marker was moved                                                                   |
| `LocationTapped`                                          | The map was tapped, with `latitude` and `longitude`                                            |
| `LocationLongPressed`                                     | The map was pressed and held                                                                   |
| `BoundsChanged`                                           | The visible area changed, with `minLatitude`, `minLongitude`, `maxLatitude` and `maxLongitude` |

The current visible area is also available through `VisibleBounds`.

A @MapRoute node additionally raises `Calculated` and `Failed` events.

## Maps on Android

Google Maps requires a valid Google Maps API key. Follow [Google's documentation](https://developers.google.com/maps/documentation/android-api/signup) to get one set up. Once you have your key it must be added to your project file, as shown below

```JSON
"Android": {
   "Geo": {
        "ApiKey": "your_key_here"
    }
}
```

If you use route calculation, enable the **Directions API** for the same key.

## Map providers

`Fuse.Maps` registers the platform's native provider automatically: Google Maps on Android and Apple Maps on iOS. Additional implementations can be registered with `MapProviders.Register` and selected per map with the [Provider](api:fuse/controls/mapview/provider) property, which must be set before the map view is created.

```XML
<MapView Provider="MyProvider" />
```

A provider implements `IMapProvider`, creates an `IMapView`, and reports user interaction and results through the `IMapViewHost` it is given. See @IMapProvider and @IMapViewHost for the complete contract.

## Limitations

- `MapView` is available on Android and iOS only; desktop targets show a placeholder.
- `LineWidth` and `ScrollBy` are measured in screen pixels on Android and points on iOS.
- `MapMarker.Color` tints only the default pin, and is hue-based on Android.
- Image and tile overlays cannot be tapped.
- Tile providers and map providers have their own attribution and usage requirements.
