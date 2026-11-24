# Fuse.Launcher.InterApp Guide

Recipes, platform details, migration notes and troubleshooting for
`Fuse.Launcher.InterApp`. For the API summary, see [README.md](README.md).

## 1. Setup

Reference the package in your project:

```json
{
  "references": [
    "Fuse",
    "Fuse.Launcher.InterApp"
  ]
}
```

You can also reference `Fuse.Launcher`, which includes the inter-app launcher.

When working from a local `fuselibs` checkout, rebuild the library caches after
changing the package:

```sh
cd fuselibs
npm run build
```

or:

```sh
cd fuselibs
uno doctor Source -c debug
```

## 2. Configuration

### Android package visibility

Android 11+ restricts which other applications an app can query. Availability
checks and `launchPackage` need visibility declarations.

Declare custom schemes, packages or both in the application's project file:

```json
{
  "Android": {
    "Queries": {
      "Schemes": ["myapp", "https"],
      "Packages": ["com.example.app"]
    }
  }
}
```

`Android.Queries.Schemes` emits an `ACTION_VIEW` intent query for each scheme.
`Android.Queries.Packages` emits a `<package>` query.

The package already declares the common schemes documented by
`FuseJS/InterApp`: `http`, `https`, `tel`, `sms`, `mailto` and `geo`.

### iOS query schemes

`canOpenURL:` only works for schemes listed in `LSApplicationQueriesSchemes`.
Declare them in the application's project file:

```json
{
  "iOS": {
    "PList": {
      "LSApplicationQueriesSchemes": ["myapp", "https"]
    }
  }
}
```

Declare every scheme passed to `canOpenUri` or `canLaunchApp`. Undeclared
schemes report `false`, even when the target app is installed.

### Receiving custom schemes

Register the scheme in the project file:

```json
{
  "Mobile": {
    "UriScheme": "myapp"
  }
}
```

On Android this adds the scheme to the main activity's intent filter. On iOS it
adds the scheme to `CFBundleURLSchemes`.

Additional iOS schemes can be registered with `iOS.PList.UriSchemes`.

### Universal links and Android App Links

For iOS universal links, add the associated domains to the `.unoproj`:

```json
{
  "iOS": {
    "SystemCapabilities": {
      "AssociatedDomains": ["applinks:example.com"]
    }
  }
}
```

For Android App Links, add the domains:

```json
{
  "Android": {
    "AssociatedDomains": ["example.com"]
  }
}
```

Also publish the corresponding Apple App Site Association and Android Asset
Links files on the website.

Incoming links are delivered through `receivedUri` and `receivedUriData`,
including when the app was started by the link.

## 3. Core concepts

### Launch result

All launch methods return a promise or future that resolves to
`InterAppLaunchStatus.Opened` when the platform has handed the request to
another application.

```js
InterApp.launchUri("https://fuseopen.com/")
    .then(function(result) {
        // result.status === "opened"
    })
    .catch(function(error) {
        // user-facing message
    });
```

A resolved result means the request was handed off. It does not mean the user
completed an action in the other app.

### Availability

Check availability before showing a button or link:

```js
if (InterApp.canOpenUri("https://fuseopen.com/")) {
    // show the link
}

if (InterApp.canLaunchApp("com.example.app")) {
    // show the app button
}
```

```csharp
if (Fuse.Launcher.CanOpenUri("https://fuseopen.com/")) { /* ... */ }
if (Fuse.Launcher.CanLaunchApp("com.example.app")) { /* ... */ }
```

On iOS `canLaunchApp` expects a URI scheme, not a bundle identifier.

## 4. Recipes

### Open a URL

```js
InterApp.launchUri("https://fuseopen.com/");
```

```csharp
Fuse.Launcher.LaunchUri("https://fuseopen.com/");
```

### Open a common URI scheme

```js
InterApp.launchUri("tel:+4712345678");
InterApp.launchUri("sms:+4712345678");
InterApp.launchUri("geo:59.911,10.740");
InterApp.launchUri("mailto:hello@example.com");
```

How the URI is handled depends on the platform and the installed applications.

### Launch an app on Android

```js
InterApp.launchPackage("com.example.app");
```

Use `launchPackage` when the argument is always a package id. Unlike
`launchApp`, it is never treated as a URI.

To open a specific activity:

```js
InterApp.launchUri("myapp://open", {
    androidPackage: "com.example.app",
    androidClassName: "com.example.app.MainActivity"
});
```

`androidClassName` requires `androidPackage`.

### Fall back to a store page

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

`launchPackage` also accepts `appStoreUri`.

For a dedicated store button use `openStore`:

```js
InterApp.openStore({
    androidPackage: "com.example.app",
    appStoreId: "123456789"
});
```

`storeUri` overrides the platform defaults.

### Open app settings after a permission denial

```js
InterApp.openSettings().catch(function(error) {
    // settings page could not be opened
});
```

```csharp
Fuse.Launcher.OpenSettings();
```

### Android intent flags and extras

```js
InterApp.launchUri("myapp://open", {
    androidFlags: ["newTask", "clearTop"],
    androidExtras: {
        "android.intent.extra.SUBJECT": "Hello"
    }
});
```

Supported flags: `newTask`, `clearTop`, `singleTop`, `clearTask`, `noHistory`,
`excludeFromRecents`, `reorderToFront`, `launchAdjacent`, `multipleTask`,
`noAnimation`, `retainInRecents`, `newDocument`, `taskOnHome`,
`resetTaskIfNeeded`, `noUserAction`.

Flags and extras are also applied by `launchApp`/`launchPackage` when the target
is an Android package id. When launching a package directly, `androidClassName`
and `mimeType` are ignored; use `launchUri` for those.

### MIME type

```js
InterApp.launchUri("https://fuseopen.com/", {
    mimeType: "text/html"
});
```

On Android this uses `Intent.setDataAndType` instead of `setData`.

## 5. Incoming links

### Receive the URI

```js
InterApp.on("receivedUri", function(uri) {
    console.log("Launched with URI", uri);
});
```

```csharp
Fuse.Platform.InterApp.ReceivedURI += uri => { /* ... */ };
```

### Receive metadata

```js
InterApp.on("receivedUriData", function(data) {
    if (data.query) {
        console.log("Query", data.query);
    }

    if (data.sourceApplication) {
        console.log("Opened by", data.sourceApplication);
    }

    if (data.universalLink) {
        console.log("Universal link or App Link");
    }

    if (data.coldStart) {
        console.log("Started by this link");
    }
});
```

```csharp
Fuse.Platform.InterApp.ReceivedURIData += data =>
{
    // data.Query, data.SourceApplication,
    // data.IsUniversalLink, data.IsOpenInPlace, data.IsColdStart
};
```

`query` includes the leading `?`. Parse it with the platform's URL utilities or
your own query parser.

`sourceApplication` is a package name on Android and a bundle identifier on iOS
when the platform reports it. It may be `null`.

`coldStart` is `true` when the link was part of starting the app. Cold-start
links are delivered after the app enters the foreground.

### Handle routing in one place

```js
var routes = {
    "open": function(query) { /* ... */ },
    "item": function(query) { /* ... */ }
};

InterApp.on("receivedUriData", function(data) {
    var path = data.uri.replace(/^[a-z]+:\/\//i, "").split("?")[0];
    var handler = routes[path];
    if (handler) {
        handler(data.query);
    }
});
```

## 6. Migration

The original C# and JavaScript APIs remain available.

### C#

```csharp
// Legacy: fire-and-forget
Fuse.Launcher.LaunchUri(new Uno.Net.Http.Uri("https://fuseopen.com/"));
Fuse.Launcher.LaunchApp("myapp://", "https://apps.apple.com/app/id123456789");
```

Use the new overloads to observe results:

```csharp
Fuse.Launcher.LaunchUri("https://fuseopen.com/")
    .Then(status => { /* opened */ }, error => { /* failed */ });
```

```csharp
Fuse.Launcher.LaunchApp(new InterAppLaunchOptions
{
    Uri = "myapp://",
    AppStoreUri = "https://apps.apple.com/app/id123456789"
});
```

### JavaScript

`launchUri` and `launchApp` now return promises. Existing calls still work
because the return value can be ignored:

```js
InterApp.launchUri("https://fuseopen.com/");
```

The positional `launchApp(uri, appStoreUri)` form is still supported.

### Behavior changes

- Launch failures now reject the promise/future instead of only writing to the
  debug log.
- `launchApp` on Android still accepts a package id and keeps the Play Store
  fallback for that legacy form.
- `LaunchUri` no longer requests the `INTERNET` permission.
- `receivedUri` is unchanged. `receivedUriData` is new.

## 7. Troubleshooting

### `canOpenUri` returns `false` on Android

The target scheme or package is not visible to the app. Add it to
`Android.Queries`:

```json
{
  "Android": {
    "Queries": {
      "Schemes": ["myapp"],
      "Packages": ["com.example.app"]
    }
  }
}
```

Rebuild the app after changing the manifest.

### `canOpenUri` returns `false` on iOS

The scheme is not declared in `LSApplicationQueriesSchemes`. Add it to the
application's `.unoproj`, not to the library:

```json
{
  "iOS": {
    "PList": {
      "LSApplicationQueriesSchemes": ["myapp"]
    }
  }
}
```

### `launchPackage` rejects on Android

The package is not installed or is not visible. Check the package id, add it to
`Android.Queries.Packages`, and consider passing `appStoreUri` for an install
fallback.

### `launchPackage` rejects on iOS

This is expected. iOS has no API for launching an app by bundle identifier. Use
a URI scheme with `launchUri` or `launchApp`.

### `launchApp` opens the Play Store

On Android, `launchApp` treats a package-id-looking argument as a package id. If
the package is not installed and no `appStoreUri` is supplied, the legacy form
falls back to the Play Store. Use `launchUri` for URI launches, or
`launchPackage` for explicit package launches.

### The custom scheme is not received

Check that the scheme is registered:

- Android: `Mobile.UriScheme` and the generated manifest intent filter.
- iOS: `CFBundleURLSchemes` in `Info.plist`.

The scheme must also match exactly, including case-insensitive host handling.

### A universal link opens the browser

Universal links require the associated domains in the project file, a matching
Apple App Site Association file, and a signed app build. In the simulator, test
custom schemes first or use `xcrun simctl openurl`.

### Android App Links are not received

Check `Android.AssociatedDomains`, the Asset Links file, and the signing
certificate fingerprint. App Link verification is handled by the platform.

### `sourceApplication` is `null`

Android referrers are best-effort and depend on the launching app. iOS does not
report a source application for universal links.

### `coldStart` is `false`

A link received while the app is already running is not a cold start. If a
launch link reports `false`, check whether the app was already running, or
whether a previous link was delivered first.

### Store page does not open on an emulator/simulator

The Play Store / App Store may not be available. `openStore` falls back to the
web store page. An explicit `storeUri` has no automatic fallback.

### Settings page does not show app-specific settings

Some devices open the general Settings app when the app has no settings to
show. This is platform behavior.

## 8. Testing

### Unit tests

```sh
cd fuselibs
uno test Source/Fuse.Launcher/Tests/Fuse.Launcher.Test.unoproj
```

The tests cover URI helpers, Android store URIs, flag normalization, extras
flattening and `InterAppInvokeArgs`.

### Manual app

The workspace contains a manual test app for device testing:

```text
/Users/hassan/project/fuse/InterAppTest
```

Run it with the local sources:

```sh
cd /Users/hassan/project/fuse/InterAppTest
node ../uno/bin/uno.js build android --run
node ../uno/bin/uno.js build ios --run
```

Test incoming links:

```sh
adb shell am start -W -a android.intent.action.VIEW \
  -d "interapptest://hello?id=42" com.fuseopen.interapptest
```

```sh
xcrun simctl openurl booted "interapptest://hello?id=42"
```

If an incremental Android build still uses an old generated `App.java`, remove
`build/debug/android` and rebuild.
