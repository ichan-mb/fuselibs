# Fuse.Launcher.InterApp

Launches other applications by URI, Android package id or store page, and
receives URIs that launch your own app.

- Android: `ACTION_VIEW` intents with package, class, flag, MIME type and extra
  support.
- iOS: `canOpenURL:` availability checks and
  `openURL:options:completionHandler:` launches, including universal links.
- Reports launch results with a `Promise` / `Future`.
- Opens the app settings page and the Play Store / App Store page.
- Emits `receivedUri` and `receivedUriData` for incoming deep links.

For setup, recipes, migration and troubleshooting, see [GUIDE.md](GUIDE.md).

## Installation

Add a reference to `Fuse.Launcher.InterApp` in your project file:

```json
{
  "references": [
    "Fuse",
    "Fuse.Launcher.InterApp"
  ]
}
```

You can also reference the aggregate `Fuse.Launcher` package, which includes
the inter-app launcher.

## JavaScript API

```js
var InterApp = require("FuseJS/InterApp");
```

### `InterApp.canOpenUri(uri)`

Returns `true` when the platform has an application that can open the URI.

- Android: uses `PackageManager.resolveActivity`. Subject to Android 11+
  package visibility; declare custom schemes with `Android.Queries.Schemes`.
- iOS: uses `canOpenURL:`. The scheme must be declared in
  `LSApplicationQueriesSchemes`.
- Other platforms: returns `false`.

### `InterApp.canLaunchApp(applicationId)`

Returns `true` when the platform can launch the application.

- Android: `applicationId` is a package name.
- iOS: `applicationId` is a URI scheme, for example `"myapp://"`.
- Other platforms: returns `false`.

### `InterApp.launchUri(uri, options)`

Opens a URI and returns a `Promise`.

```js
InterApp.launchUri("https://fuseopen.com/", {
    androidFlags: ["newTask"]
}).then(function(result) {
    // result.status is "opened"
}).catch(function(error) {
    // user-facing error message
});
```

Options:

| Option | Type | Description |
|---|---|---|
| `androidPackage` | string | Android package to target. |
| `androidClassName` | string | Explicit Android activity class. Requires `androidPackage`. |
| `androidFlags` | string[] | Android intent flags. See the flag list below. |
| `mimeType` | string | Android MIME type for the intent data. Uses `setDataAndType`. |
| `androidExtras` | object | String extras added to the Android intent. |
| `universalLinksOnly` | bool | iOS: only open universal links. |
| `appStoreUri` | string | Store URI to open when the launch fails. |

### `InterApp.launchApp(uri, options)`

Launches an app by URI, or on Android by package id.

```js
InterApp.launchApp("com.example.app", {
    appStoreUri: "https://play.google.com/store/apps/details?id=com.example.app"
});
```

```js
InterApp.launchApp("myapp://", {
    appStoreUri: "https://apps.apple.com/app/id123456789"
});
```

`uri` may be a URI or, on Android, a package id. On iOS it must be a URI that
the target app registers a scheme for.

Options are the same as `launchUri`. When `uri` is an Android package id,
`androidFlags` and `androidExtras` are applied; `androidClassName` and
`mimeType` are ignored. Use `launchUri` for those.

The positional form `launchApp(uri, appStoreUri)` is still supported. On
Android it falls back to the Play Store when `uri` is a package id and no store
URI is supplied.

### `InterApp.launchPackage(applicationId, options)`

Launches an Android application by package id. Unlike `launchApp`, the argument
is never treated as a URI. This rejects on iOS.

```js
InterApp.launchPackage("com.example.app", {
    androidFlags: ["newTask"],
    appStoreUri: "https://play.google.com/store/apps/details?id=com.example.app"
});
```

Options: `appStoreUri`, `androidFlags`, `androidExtras`.

### `InterApp.openSettings()`

Opens the operating system's settings page for this application.

```js
InterApp.openSettings().then(function(result) {
    // result.status is "opened"
});
```

### `InterApp.openStore(options)`

Opens the store page for an application.

```js
InterApp.openStore({
    androidPackage: "com.example.app",
    appStoreId: "123456789"
});
```

| Option | Type | Description |
|---|---|---|
| `androidPackage` | string | Android package whose Play Store page is opened. |
| `appStoreId` | string | iOS App Store id, with or without the `id` prefix. |
| `storeUri` | string | Explicit store URI. Overrides the platform defaults. |

When `androidPackage` or `appStoreId` is used, the native store page is tried
first and the corresponding web store page is used as a fallback. When
`storeUri` is used, it is opened as given.

### Events

```js
InterApp.on("receivedUri", function(uri) {
    console.log("Launched with URI", uri);
});

InterApp.on("receivedUriData", function(data) {
    console.log(data.uri);
    console.log(data.query);
    console.log(data.sourceApplication);
    console.log(data.universalLink);
    console.log(data.openInPlace);
    console.log(data.coldStart);
});
```

`receivedUriData` fields:

| Field | Type | Description |
|---|---|---|
| `uri` | string | The URI that launched the app. |
| `query` | string or null | The URI query string, including the leading `?`. |
| `sourceApplication` | string or null | Android package name or iOS bundle identifier, when reported. |
| `universalLink` | bool | The URI arrived as an iOS universal link or Android App Link. |
| `openInPlace` | bool | iOS opened the URI in place. |
| `coldStart` | bool | The URI arrived while the app was starting. |

`receivedUri` remains available for code that only needs the URI.

### Android intent flags

`androidFlags` accepts these names. Matching is case-insensitive and ignores
surrounding whitespace.

`newTask`, `clearTop`, `singleTop`, `clearTask`, `noHistory`,
`excludeFromRecents`, `reorderToFront`, `launchAdjacent`, `multipleTask`,
`noAnimation`, `retainInRecents`, `newDocument`, `taskOnHome`,
`resetTaskIfNeeded`, `noUserAction`.

Unknown names reject the launch with a user-facing error.

## C# API

`Fuse.Launcher` exposes the inter-app launcher:

```csharp
bool available = Fuse.Launcher.CanOpenUri("https://fuseopen.com/");
bool installed = Fuse.Launcher.CanLaunchApp("com.example.app");

Future<InterAppLaunchStatus> uri =
    Fuse.Launcher.LaunchUri("https://fuseopen.com/");

Future<InterAppLaunchStatus> options =
    Fuse.Launcher.LaunchUri(new InterAppLaunchOptions
    {
        Uri = "myapp://open",
        AndroidPackage = "com.example.app",
        AndroidFlags = new[] { "newTask" }
    });

Future<InterAppLaunchStatus> package =
    Fuse.Launcher.LaunchPackage("com.example.app");

Future<InterAppLaunchStatus> settings =
    Fuse.Launcher.OpenSettings();

Future<InterAppLaunchStatus> store =
    Fuse.Launcher.OpenStore(new InterAppStoreOptions
    {
        AndroidPackage = "com.example.app",
        AppStoreId = "123456789"
    });
```

The same methods are available on
`Fuse.LauncherImpl.InterAppLauncher`.

### `InterAppLaunchOptions`

| Property | Type | Description |
|---|---|---|
| `Uri` | string | URI to open, or Android package id for `LaunchApp`. |
| `AndroidPackage` | string | Android package to target. |
| `AndroidClassName` | string | Explicit Android activity class. Requires `AndroidPackage`. |
| `AndroidFlags` | string[] | Android intent flags. |
| `MimeType` | string | Android MIME type for the intent data. |
| `AndroidExtras` | `Dictionary<string, string>` | String extras for Android. |
| `UniversalLinksOnly` | bool | iOS: only open universal links. |
| `AppStoreUri` | string | Store URI to open when the launch fails. |

### `InterAppStoreOptions`

| Property | Type | Description |
|---|---|---|
| `AndroidPackage` | string | Android package whose Play Store page is opened. |
| `AppStoreId` | string | iOS App Store id, with or without the `id` prefix. |
| `StoreUri` | string | Explicit store URI. |

### `InterAppLaunchStatus`

| Value | Meaning |
|---|---|
| `Opened` | The platform handed the request to another application. |

Failures are reported as a rejected `Future` / `Promise`.

### Receiving URIs in C#

```csharp
Fuse.Platform.InterApp.ReceivedURI += uri => { /* ... */ };

Fuse.Platform.InterApp.ReceivedURIData += data =>
{
    // data.Uri, data.Query, data.SourceApplication,
    // data.IsUniversalLink, data.IsOpenInPlace, data.IsColdStart
};
```

## Trigger actions

```xml
<LaunchUri Uri="https://fuseopen.com/"
           AndroidPackage="com.example.app"
           AndroidFlags="newTask,clearTop"
           MimeType="text/html" />
```

```xml
<LaunchApp Uri="myapp://"
           AppStoreUri="https://apps.apple.com/app/id123456789" />
```

```xml
<LaunchPackage ApplicationId="com.example.app"
               AndroidFlags="newTask" />
```

```xml
<OpenSettings />
<OpenStore AndroidPackage="com.example.app" AppStoreId="123456789" />
```

`<LaunchUri>` supports `Uri`, `AndroidPackage`, `AndroidClassName`, `MimeType`
and comma-separated `AndroidFlags`.
`<LaunchPackage>` supports `ApplicationId`, `AppStoreUri` and
comma-separated `AndroidFlags`.
`<OpenStore>` supports `AndroidPackage`, `AppStoreId` and `StoreUri`.

Trigger actions are fire-and-forget; failures are written to the debug log.

## Legacy API

The original fire-and-forget signatures remain available:

```csharp
Fuse.Launcher.LaunchUri(new Uno.Net.Http.Uri("https://fuseopen.com/"));
Fuse.Launcher.LaunchApp("myapp://", "https://apps.apple.com/app/id123456789");
```

In JavaScript, `launchUri` and `launchApp` now return promises. The positional
`launchApp(uri, appStoreUri)` form is still accepted.

## Platform behavior

### Android

- `launchUri` uses `ACTION_VIEW`. `androidPackage` adds `setPackage`;
  `androidClassName` adds `setClassName` instead.
- `mimeType` uses `setDataAndType`.
- `androidFlags` are added with `Intent.addFlags`.
- `androidExtras` are added with `Intent.putExtra(String, String)`.
- If a targeted package cannot handle the URI, the launch is retried without
  the package restriction.
- `launchPackage` uses `getLaunchIntentForPackage`.
- `openSettings` uses `ACTION_APPLICATION_DETAILS_SETTINGS`.
- `openStore` uses `market://details?id=...` with a Play Store web fallback.
- Incoming URIs report the referring package from the intent referrer extras,
  App Link status from `Android.associatedDomains`, and cold start from the
  first `onResume`.

### iOS

- `launchUri` uses `canOpenURL:` where applicable and
  `openURL:options:completionHandler:` for results.
- `universalLinksOnly` adds `UIApplicationOpenURLOptionUniversalLinksOnly`.
- `launchApp` opens a URI. iOS cannot launch by bundle identifier.
- `launchPackage` rejects.
- `openSettings` uses `UIApplicationOpenSettingsURLString`.
- `openStore` uses `itms-apps://` with an App Store web fallback.
- Incoming URIs report `UIApplicationOpenURLOptionsSourceApplicationKey`,
  `UIApplicationOpenURLOptionsOpenInPlaceKey`, and whether the URI arrived via
  `continueUserActivity` as a universal link.

### Other platforms

Availability checks return `false`, and launch methods reject with a
user-facing message.

## Limitations

- `androidExtras` supports string values only.
- Android source-application reporting is best-effort and may be `null`.
- iOS does not report a source application for universal links.
- Availability checks are restricted by Android package visibility and iOS
  query-scheme declarations.
- Trigger actions do not report results; use the JavaScript or C# API when the
  result matters.
- Sharing is provided by `Fuse.Share`, not by this package.

## Testing

Run the unit tests:

```sh
cd fuselibs
uno test Source/Fuse.Launcher/Tests/Fuse.Launcher.Test.unoproj
```

The workspace also contains a manual test app at
`/Users/hassan/project/fuse/InterAppTest` when developing from this checkout.
