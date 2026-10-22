# Fuse.Launcher.Maps

Opens the platform map application to show a location, search, or open
directions.

- Android: `geo:` intents, `google.navigation:` for turn-by-turn navigation and
  Google Maps directions URLs.
- iOS: Apple Maps through MapKit and map links, with optional Google Maps launch
  through `comgooglemaps://`.
- Supports zoom, pin labels, map types, directions, driving/walking/transit/cycling
  travel modes, availability checks and launch results.

- [API reference](docs/README.md)
- [Usage guide and troubleshooting](docs/GUIDE.md)

## Quick start

Add a reference to `Fuse.Launcher.Maps` (or the aggregate `Fuse.Launcher`):

```json
{
  "references": [
    "Fuse",
    "Fuse.Launcher.Maps"
  ]
}
```

JavaScript:

```js
var Maps = require("FuseJS/Maps");

Maps.open({
    latitude: 59.9117715,
    longitude: 10.7400957,
    label: "Fuse",
    zoom: 16
}).then(function(result) {
    console.log(result.status);
}).catch(function(error) {
    console.log("Maps failed: " + error);
});
```

C#:

```csharp
using Fuse;

Fuse.Launcher.LaunchMaps(new MapLaunchOptions
{
    Location = new MapLocation(59.9117715, 10.7400957, "Fuse"),
    Zoom = 16
}).Then(
    status => { /* MapLaunchStatus.Opened */ },
    error => { /* Exception */ });
```

Directions from the current location:

```js
Maps.directions({
    to: { latitude: 59.9117715, longitude: 10.7400957, label: "Fuse" },
    mode: "walking"
});
```

See [docs/README.md](docs/README.md) for the full API and
[docs/GUIDE.md](docs/GUIDE.md) for platform behavior, recipes, migration and
troubleshooting.
