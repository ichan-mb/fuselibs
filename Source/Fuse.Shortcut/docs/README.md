# Fuse.Shortcut

Home screen shortcuts for Fuse/Uno apps.

`Fuse.Shortcut` exposes the `FuseJS/Shortcut` module and uses the native
shortcut APIs on each platform:

- **iOS** — home screen quick actions (`UIApplicationShortcutItem`)
- **Android** — dynamic app shortcuts (`ShortcutManager`, Android 7.1 / API 25+)

The package supports dynamic shortcuts, bundled images, shared system icons,
extras/deep-link payloads, cold/resume launch detection, and the Android
`rank`, `categories`, `disabled`, and usage-reporting features.

For recipes, platform behavior, testing, and troubleshooting, see
[GUIDE.md](GUIDE.md).

## Installation

Add a reference to `Fuse.Shortcut` in your project file:

```json
{
  "references": [
    "Fuse",
    "FuseJS",
    "Fuse.Shortcut"
  ]
}
```

Then require the module from JavaScript:

```js
var Shortcut = require("FuseJS/Shortcut");
```

## Quick start

```js
var Shortcut = require("FuseJS/Shortcut");

Shortcut.registerShortcuts([
    {
        id: "compose",
        title: "Compose",
        subtitle: "New message",
        systemIcon: "square.and.pencil",
        extras: { action: "compose" }
    },
    {
        id: "profile",
        title: "Profile",
        systemIcon: "person",
        systemIconFilled: true
    }
]).then(function(ok) {
    console.log("Shortcuts registered: " + ok);
}).catch(function(error) {
    console.log("Shortcut registration failed: " + error);
});

Shortcut.on("shortcutClicked", function(id, details) {
    console.log("Clicked: " + id);
    console.log("Launch type: " + details.launchType);
    console.log("Extras: " + JSON.stringify(details.extras));
});
```

Register shortcuts when the app starts, not only from a settings screen. The
operating system may remove dynamic shortcuts after an app update or reinstall.

## Shortcut objects

`registerShortcuts` and `updateShortcuts` accept an array of objects with these
properties:

| Property | Type | Platforms | Description |
|---|---|---|---|
| `id` | string | all | Unique shortcut id. Passed to `shortcutClicked`. Required. |
| `title` | string | all | Short label shown in the shortcut menu. Required. |
| `subtitle` | string | all | Subtitle on iOS; long label on Android. Optional. |
| `icon` | string | all | Bundled image path. Must be included as a bundle asset. Optional. |
| `systemIcon` | string | all | Universal symbol name, such as `"square.and.pencil"`, `"person"`, `"heart"`, or `"gear"`. Optional. |
| `systemIconFilled` | bool | all | Use the filled variant of `systemIcon`. Defaults to `false`. Optional. |
| `extras` | object | all | Custom payload delivered as `details.extras`. Optional. |
| `rank` | number | Android | Display rank. Lower values indicate higher priority. Optional. |
| `categories` | string[] | Android | Category names, such as `"android.shortcut.conversation"`. Optional. |
| `disabled` | bool | Android | Whether the shortcut is disabled. Omit to leave the current state unchanged. Optional. |
| `disabledMessage` | string | Android | Message shown by the launcher when the shortcut is disabled. Optional. |

`systemIcon` takes precedence over `icon` when both are specified. Android-only
properties are ignored on iOS.

### Icons

Bundled images must be registered as assets:

```json
{
  "includes": [
    "assets/book.png:bundle"
  ]
}
```

```js
{
    id: "book_store",
    title: "Book Store",
    icon: "assets/book.png"
}
```

`systemIcon` uses the shared Fuse symbol mapping. On iOS it becomes an SF Symbol
and requires iOS 13 or newer; older versions fall back to `icon`. On Android it
becomes a Material Symbol rendered from the bundled symbol font. The Android
glyph uses a dark color in light mode and a light color in dark mode.

## API

### `registerShortcuts(shortcuts)`

Replaces all dynamic shortcuts. Returns a `Promise<bool>`.

- Resolves `true` on success.
- Resolves `false` when shortcuts are not supported on the current platform.
- Rejects when the input is invalid or exceeds `getMaxShortcutCount()`.

```js
Shortcut.registerShortcuts(shortcuts).then(function(ok) {
    console.log(ok);
});
```

### `updateShortcuts(shortcuts)`

Adds new shortcuts and updates existing ones with the same `id`. Shortcuts that
are not mentioned are left untouched. Returns a `Promise<bool>`.

On iOS, updated shortcuts keep their position in the list. On Android, display
order is controlled by `rank`.

Rejects when the resulting set would exceed `getMaxShortcutCount()`.

```js
Shortcut.updateShortcuts([
    { id: "compose", title: "New Message", systemIcon: "square.and.pencil" },
    { id: "favorites", title: "Favorites", systemIcon: "heart" }
]);
```

### `removeShortcuts(ids)`

Removes the shortcuts with the given ids. Returns a `Promise<bool>`.

```js
Shortcut.removeShortcuts(["profile"]);
```

### `clearShortcuts()`

Removes all dynamic shortcuts managed by the app. Returns a `Promise<bool>`.

```js
Shortcut.clearShortcuts();
```

### `getShortcuts()`

Returns a `Promise` that resolves to an array describing the current dynamic
shortcuts.

Each object contains `id`, `title`, and `subtitle`; `extras` is included when a payload was registered. On Android the objects also contain `rank`, `categories`, `disabled`, and `disabledMessage`.

```js
Shortcut.getShortcuts().then(function(items) {
    console.log(JSON.stringify(items, null, 2));
});
```

Platform icon objects cannot be converted back to their original `icon` or
`systemIcon` names.

### `isSupported()`

Returns whether shortcuts are supported on the current platform. Android
requires API level 25 (Android 7.1) or newer.

```js
if (!Shortcut.isSupported()) {
    console.log("Shortcuts are not available on this platform");
}
```

### `getMaxShortcutCount()`

Returns the maximum number of dynamic shortcuts supported by the platform.
This is typically 4 on iOS and device-dependent on Android (usually 5).

```js
var max = Shortcut.getMaxShortcutCount();
```

Use this value to limit the UI and avoid registration failures.

### `reportShortcutUsed(id)`

Reports that a shortcut was used, which helps Android rank shortcuts. Returns a
`Promise<bool>`.

- Android: calls `ShortcutManager.reportShortcutUsed(id)`.
- iOS: resolves `false` because there is no equivalent API.

Call it when the user performs the shortcut's action through another path, such
as an in-app menu item.

```js
Shortcut.reportShortcutUsed("compose");
```

## Events

### `shortcutClicked`

Emitted when a shortcut is clicked.

```js
Shortcut.on("shortcutClicked", function(id, details) {
    // id: the shortcut id
    // details.extras: the payload passed at registration (or {})
    // details.launchType: "cold" or "resume"
});
```

| Field | Type | Description |
|---|---|---|
| `id` | string | The id of the clicked shortcut. |
| `details.extras` | object | The shortcut's `extras` payload. Empty object when none was provided. |
| `details.launchType` | string | `"cold"` when the shortcut launched the app, `"resume"` when the app was already running. |

The module queues events that arrive before the app is initialized, so attach
the listener during startup.

## Validation and errors

The mutating APIs reject with an error message when:

- the argument is not an array;
- a shortcut is missing a non-empty `id` or `title`;
- two shortcuts have the same `id`;
- `subtitle`, `icon`, `systemIcon`, or `disabledMessage` is not a string;
- `rank` is not a number;
- `categories` is not an array of non-empty strings;
- `disabled` or `systemIconFilled` is not a boolean;
- `extras` is not an object;
- the input or resulting shortcut set exceeds `getMaxShortcutCount()`.

Native failures, such as Android rate limiting or an unavailable
`ShortcutManager`, are also reported as rejections.

```js
Shortcut.registerShortcuts(shortcuts).catch(function(error) {
    console.log("Registration failed: " + error);
});
```

## Platform notes

| Feature | iOS | Android |
|---|---|---|
| Native API | `UIApplicationShortcutItem` | `ShortcutManager` dynamic shortcuts |
| Minimum version | iOS 9+ | Android 7.1 / API 25 |
| Maximum shortcuts | 4 | `getMaxShortcutCountPerActivity()` |
| Bundled image icon | Template image | Bitmap icon |
| System icon | SF Symbols (iOS 13+) | Material Symbols |
| `extras` storage | `userInfo` | Shortcut Intent + native `ShortcutInfo` extras |
| Display order | Registration/update order | `rank` |
| Disabled state | Not applicable | `disabled` + `disabledMessage` |
| Categories | Not applicable | `categories` |
| Usage reporting | Not applicable | `reportShortcutUsed` |
| Click while running | `"resume"` | `"resume"` |
| Cold launch | `"cold"` | `"cold"` |

On Android, a click resumes an existing app task and delivers the event through
`onNewIntent`. The app is not restarted when it is already running.

## Limitations

- Only dynamic shortcuts are managed. Static shortcuts declared in
  `Info.plist` (iOS) or `res/xml/shortcuts.xml` (Android) are not supported.
- Pinned shortcuts (`ShortcutManager.requestPinShortcut`) are not supported.
- Multiple intents per shortcut, `Person`/conversation participants, and
  localized shortcut resources are not exposed.
- `getShortcuts` does not return icon names.
- Android-only properties are ignored on iOS.
- `extras` is stored by the OS and the launcher. Do not use it for secrets.
