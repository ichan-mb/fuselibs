# Fuse.Launcher.InterApp

Launches other applications by URI, Android package id or store page, and
receives URIs that launch your own app.

- `canOpenUri(uri)` / `CanOpenUri(uri)` – check whether an app can handle a URI.
- `canLaunchApp(applicationId)` / `CanLaunchApp(applicationId)` – check whether
  an app can be launched.
- `launchUri(uri, options)` / `LaunchUri(uri | options)` – open a URI and report
  the result.
- `launchApp(uri, options)` / `LaunchApp(options)` – launch an app by URI, or on
  Android by package id.
- `launchPackage(applicationId, options)` / `LaunchPackage(...)` – launch an
  Android app by package id only.
- `openSettings()` / `OpenSettings()` – open the app's system settings page.
- `openStore(options)` / `OpenStore(options)` – open the app's store page.
- `receivedUri` – event raised when the app is launched by a URI.
- `receivedUriData` – event raised with the URI, query, source application,
  universal-link, open-in-place and cold-start metadata.

The legacy fire-and-forget overloads (`Launcher.LaunchUri(Uri)` and
`Launcher.LaunchApp(string, string)`) remain available.

- [API reference](docs/README.md)
- [Usage guide and troubleshooting](docs/GUIDE.md)

## Quick start

Add a reference to `Fuse.Launcher.InterApp` (or the aggregate `Fuse.Launcher`):

```json
{
  "references": [
    "Fuse",
    "Fuse.Launcher.InterApp"
  ]
}
```

```js
var InterApp = require("FuseJS/InterApp");

if (InterApp.canOpenUri("https://fuseopen.com/")) {
    InterApp.launchUri("https://fuseopen.com/").then(function(result) {
        console.log(result.status); // "opened"
    }).catch(function(error) {
        console.log("Could not open URI: " + error);
    });
}
```

```js
InterApp.launchPackage("com.example.app", {
    androidFlags: ["newTask"],
    appStoreUri: "https://play.google.com/store/apps/details?id=com.example.app"
});

InterApp.openSettings();
InterApp.openStore({ androidPackage: "com.example.app", appStoreId: "123456789" });
```

Android package-visibility queries, iOS `LSApplicationQueriesSchemes`, launch
options, incoming-link metadata, recipes and troubleshooting are documented in
[docs/README.md](docs/README.md) and [docs/GUIDE.md](docs/GUIDE.md).

## Testing

```sh
cd fuselibs
uno test Source/Fuse.Launcher/Tests/Fuse.Launcher.Test.unoproj
```

The workspace manual test app lives at
`/Users/hassan/project/fuse/InterAppTest` when developing from this checkout.
