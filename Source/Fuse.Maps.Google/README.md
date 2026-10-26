# Fuse.Maps.Google

Google Maps provider for [`Fuse.Maps`](../Fuse.Maps).

On iOS this provider renders maps with the [Google Maps SDK for iOS](https://developers.google.com/maps/documentation/ios-sdk).
On Android it delegates to the platform's native provider, which already uses
Google Maps, so `<MapView Provider="Google" />` means Google Maps on both
platforms.

## Installation

Reference both packages from your `.unoproj`:

```json
"references": [
	"Fuse.Maps",
	"Fuse.Maps.Google",
	"Fuse",
	"FuseJS"
]
```

The provider registers itself automatically and is selected per map:

```xml
<NativeViewHost>
	<MapView Provider="Google" Latitude="59.9115573" Longitude="10.73888" Zoom="12">
		<MapMarker Label="Fuse HQ" Latitude="59.9115573" Longitude="10.73888" />
	</MapView>
</NativeViewHost>
```

Maps that do not set `Provider` keep using the platform default (Apple Maps on
iOS).

## iOS setup

The Google Maps SDK for iOS is distributed through CocoaPods. The package ships
a UXL extension that:
The package ships a UXL extension that:

- enables Uno's CocoaPods integration (`COCOAPODS`) when the package is referenced,
- adds `pod 'GoogleMaps'`, and
- adds the `-ObjC` linker flag through a Podfile `post_install` hook.

Install CocoaPods (`sudo gem install cocoapods`) if it is not already
available. The Uno iOS build runs `pod install` and builds the generated
`.xcworkspace`.

If your project overrides the build defines, make sure `COCOAPODS` remains
defined, or build with:

```sh
uno build ios -DCOCOAPODS
```

### API key

Create a key in the [Google Cloud Console](https://console.cloud.google.com/google/maps-apis)
with **Maps SDK for iOS** enabled.

Set it before any map is created, for example in a `[UXGlobalModule]` of your
app:

```uno
GoogleMapProvider.ApiKey = "YOUR_IOS_KEY";
```

or add it to `Info.plist`:

```json
"iOS": {
	"PList": {
		"GoogleMapsAPIKey": "YOUR_IOS_KEY"
	}
}
```

The same key is used for geocoding and routing. Enable the **Geocoding API**
and **Directions API** for it if you use those features.

If you set `ShowMyLocation="true"`, also add a location usage description:

```json
"iOS": {
	"PList": {
		"NSLocationWhenInUseUsageDescription": "This app shows your location on the map."
	}
}
```

## Feature notes

The provider implements the full `IMapView` contract:

- camera, animation, bounds fitting, padding and zoom limits,
- markers with label, snippet, icon, color, drag and selection,
- polylines, polygons with holes, circles, image overlays and URL tile layers,
- geocoding, reverse geocoding and route calculation through the Google REST
  APIs,
- snapshots.

Platform limitations:

- `MapStyle` supports `Normal`, `Satellite`, `Hybrid` and `Terrain`.
- Google's polylines do not expose line caps, joins or dash patterns. Those
  properties are ignored on this provider.
- `AnimateTo` uses the SDK's built-in camera animation; the requested duration
  is advisory.
- `CancelAnimation` is best effort (`removeAllAnimations`).
- Geocoding and routing require network access and a valid API key.
- `snapshot()` renders the view hierarchy. Because the Google SDK draws with
  Metal, the captured image may be empty on some devices; prefer a Google
  Static Maps request if you need a guaranteed image.
- The Android side reuses the native provider, so all `Fuse.Maps` Android
  behavior applies unchanged.
