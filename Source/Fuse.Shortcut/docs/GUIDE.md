# Fuse.Shortcut guide

This guide covers common shortcut scenarios and the platform behavior behind
`FuseJS/Shortcut`. For the API summary, see [README.md](README.md).

## Setup

Add `Fuse.Shortcut` to your project:

```json
{
  "references": [
    "Fuse",
    "FuseJS",
    "Fuse.Shortcut"
  ]
}
```

If you use bundled icons, include them as bundle assets:

```json
{
  "includes": [
    "assets/book.png:bundle"
  ]
}
```

Then require the module:

```js
var Shortcut = require("FuseJS/Shortcut");
```

## Registering shortcuts

Register shortcuts when the app starts. This restores them after an app update,
reinstall, or when the launcher clears them.

```js
function registerShortcuts() {
    return Shortcut.registerShortcuts([
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
        },
        {
            id: "book_store",
            title: "Book Store",
            icon: "assets/book.png",
            extras: { action: "book_store" }
        }
    ]);
}

registerShortcuts()
    .then(function(ok) {
        console.log("Shortcuts registered: " + ok);
    })
    .catch(function(error) {
        console.log("Shortcut registration failed: " + error);
    });
```

`registerShortcuts` replaces the full set of dynamic shortcuts. Use
`updateShortcuts` when you want to add or change individual entries.

### Checking support and limits

```js
if (!Shortcut.isSupported()) {
    console.log("Shortcuts are not supported on this platform");
    return;
}

var max = Shortcut.getMaxShortcutCount();
console.log("This platform supports up to " + max + " shortcuts");
```

Android requires API level 25 (Android 7.1). iOS supports quick actions on all
current deployment targets. iOS shows at most four quick actions; Android's
limit is reported by `getMaxShortcutCount()` and is usually five.

`registerShortcuts` rejects if the list is longer than the platform limit.
`updateShortcuts` rejects if the resulting merged set would exceed it. Build
your shortcut list from `getMaxShortcutCount()` rather than hard-coding a
number.

## Handling a shortcut click

Attach the listener during startup. The module queues events that arrive before
the app is initialized.

```js
Shortcut.on("shortcutClicked", function(id, details) {
    var extras = details.extras || {};

    if (details.launchType === "cold") {
        console.log("The shortcut launched the app");
    } else {
        console.log("The app was already running");
    }

    switch (id) {
        case "compose":
            openComposer(extras.draftId);
            break;
        case "profile":
            openProfile(extras.userId);
            break;
        case "book_store":
            openBookStore();
            break;
    }
});
```

| Value | Meaning |
|---|---|
| `"cold"` | The shortcut launched the app. |
| `"resume"` | The app was already running and received a new intent/quick action. |

On Android, a click resumes the existing app task and delivers the event through
`onNewIntent`. The app is not restarted when it is already running.

## Deep linking with extras

`extras` is an object attached to the shortcut and returned in
`details.extras`.

```js
{
    id: "profile",
    title: "Profile",
    systemIcon: "person",
    extras: {
        userId: "42",
        tab: "activity"
    }
}
```

On iOS, `extras` becomes the `UIApplicationShortcutItem.userInfo` dictionary.
On Android, it is stored in the shortcut Intent and also in the native
`ShortcutInfo` extras as a `PersistableBundle`.

Android extras conversion is best-effort:

- nested objects become nested `PersistableBundle` values;
- arrays of strings, booleans, integers, longs, or numbers become primitive
  arrays;
- mixed arrays and arrays of objects are preserved as JSON strings.

`extras` is stored by the OS and the launcher. Do not use it for secrets.

## Choosing icons

### Bundled images

Use `icon` with the same path that is included as a bundle asset:

```js
{
    id: "book_store",
    title: "Book Store",
    icon: "assets/book.png"
}
```

On iOS the image is treated as a template image and tinted by the system. On
Android it is decoded into a bitmap for the shortcut.

If the path is not found in the bundle, the shortcut is still registered but has
no icon. Check the bundle include and the exact source path.

### System icons

Use `systemIcon` with a universal symbol name. The shared Fuse symbol mapping
resolves it to the platform icon:

```js
{
    id: "compose",
    title: "Compose",
    systemIcon: "square.and.pencil"
}
```

Common names include:

| Name | iOS SF Symbol | Android Material Symbol |
|---|---|---|
| `square.and.pencil` | `square.and.pencil` | `edit_square` |
| `person` | `person` | `person` |
| `heart` | `heart` | `favorite` |
| `gear` | `gear` | `settings` |
| `trash` | `trash` | `delete` |
| `magnifyingglass` | `magnifyingglass` | `search` |

The full mapping is provided by `Fuse.Controls.Primitives.SymbolProvider`.
Unknown names fall back to the “missing symbol” icon and emit a user warning.

`systemIcon` requires iOS 13 or newer. On older iOS versions it falls back to
`icon` when one is provided. On Android the symbol is rendered from the bundled
Material Symbols font and adapts to light/dark mode.

`systemIcon` takes precedence over `icon` when both are specified.

## Android-specific features

These properties are validated on all platforms but only applied on Android.
They are ignored on iOS.

### Rank

`rank` controls shortcut ordering. Lower values indicate higher priority.

```js
{
    id: "compose",
    title: "Compose",
    rank: 1
}
```

### Categories

`categories` associates the shortcut with Android shortcut categories.

```js
{
    id: "chat",
    title: "Chat",
    categories: ["android.shortcut.conversation"]
}
```

Categories are app-defined. Follow the Android conventions when using
well-known categories such as conversation shortcuts.

### Disabled shortcuts

Set `disabled` to disable a shortcut and `disabledMessage` to control the message
shown by the launcher.

```js
{
    id: "book_store",
    title: "Book Store",
    disabled: true,
    disabledMessage: "Book Store is currently unavailable"
}
```

- `disabled: true` disables the shortcut.
- `disabled: false` enables it.
- Omitting `disabled` leaves the current state unchanged.

Disabled shortcuts remain registered but cannot be launched. Use this for
features that require sign-in, are temporarily unavailable, or are
age-restricted.

### Reporting usage

`reportShortcutUsed(id)` tells Android that a shortcut was used. This helps the
launcher rank shortcuts.

```js
Shortcut.reportShortcutUsed("compose");
```

Call it when the user performs the same action through another path, such as an
in-app menu item. On iOS it resolves to `false` because there is no equivalent
API.

## Managing shortcuts at runtime

### Add or update individual shortcuts

```js
Shortcut.updateShortcuts([
    {
        id: "compose",
        title: "New Message",
        subtitle: "Compose now",
        systemIcon: "square.and.pencil",
        rank: 1
    },
    {
        id: "favorites",
        title: "Favorites",
        systemIcon: "heart",
        rank: 2
    }
]);
```

Other shortcuts are left untouched. On iOS, updated shortcuts keep their
position. On Android, `rank` controls display order.

### Remove shortcuts

```js
Shortcut.removeShortcuts(["profile"])
    .then(function(ok) {
        console.log("Removed: " + ok);
    });
```

### Clear all shortcuts

```js
Shortcut.clearShortcuts();
```

### Read the current set

```js
Shortcut.getShortcuts().then(function(items) {
    console.log(JSON.stringify(items, null, 2));
});
```

On Android the returned objects include `rank`, `categories`, `disabled`, and
`disabledMessage`. Icon objects cannot be converted back to their original
`icon` or `systemIcon` names.

## Platform behavior

| Behavior | iOS | Android |
|---|---|---|
| Native API | `UIApplicationShortcutItem` | `ShortcutManager` |
| Minimum version | iOS 9+ | Android 7.1 / API 25 |
| Maximum shortcuts | 4 | `getMaxShortcutCountPerActivity()` |
| Register behavior | Replaces `shortcutItems` | `setDynamicShortcuts` |
| Update behavior | Merge in place | `addDynamicShortcuts` |
| Remove behavior | Filter `shortcutItems` | `removeDynamicShortcuts` |
| Clear behavior | `shortcutItems = []` | `removeAllDynamicShortcuts` |
| Bundled icon | Template image | Bitmap icon |
| System icon | SF Symbols (iOS 13+) | Material Symbols |
| Extras | `userInfo` | Intent extra + `ShortcutInfo.extras` |
| Ordering | Array order | `rank` |
| Disabled state | Not applicable | `disableShortcuts` / `enableShortcuts` |
| Categories | Not applicable | `setCategories` |
| Usage reporting | Not applicable | `reportShortcutUsed` |
| Click while running | `"resume"` | `"resume"` |
| Cold launch | `"cold"` | `"cold"` |

## Testing checklist

Test on real devices, because launchers and shortcut surfaces vary.

1. Register three or four shortcuts and confirm they appear after long-pressing
   the app icon.
2. Tap each shortcut and verify `id`, `details.extras`, and `details.launchType`.
3. Launch the app from a shortcut when it is not running, then repeat while it
   is running. Verify `"cold"` and `"resume"`.
4. Run `updateShortcuts` and verify existing shortcuts are updated without
   removing the others.
5. Remove one shortcut and clear all shortcuts.
6. Call `getShortcuts` after each operation.
7. Register more than `getMaxShortcutCount()` shortcuts and confirm the Promise
   rejects with a clear message.
8. Submit duplicate ids, a missing title, invalid `rank`/`categories`, and
   non-object `extras`; confirm each rejects.
9. Test `systemIcon` on iOS 13+ and on an older iOS version (fallback to `icon`).
10. Test bundled icons and a missing icon path.
11. On Android, test light and dark mode, a few launchers, API 25, and a current
    API level.
12. On Android, test `rank`, `categories`, `disabled`, and
    `reportShortcutUsed`.
13. Update or reinstall the app and confirm the shortcuts are re-registered on
    startup.

## Troubleshooting

### No shortcuts appear

- Confirm `Shortcut.isSupported()` is `true`.
- Confirm `Fuse.Shortcut` is referenced in the project file.
- Register shortcuts at app startup, not only from a settings page.
- Check `getMaxShortcutCount()` and the registration Promise result.
- Remember that launchers decide how and where to display shortcuts.

### “duplicate shortcut id”

Every shortcut in a single registration or update call must have a unique `id`.
Remove the duplicate or merge the entries.

### “this platform supports at most N”

The input, or the merged result of an update, exceeds
`getMaxShortcutCount()`. Reduce the list or remove shortcuts first. On iOS the
limit is 4; Android reports the device-specific value.

### `systemIcon` does not appear

- Use a name from the shared symbol mapping.
- On iOS, system icons require iOS 13 or newer; provide `icon` as a fallback.
- On Android, confirm the app bundles the Material Symbols font (this is
  included through the `Fuse.Controls.Native` dependency).
- Check the device console for a “symbol not found” warning.

### `icon` does not appear

- Confirm the image is included as a bundle asset.
- Use the same path that appears in the bundle include.
- Check the file is a supported image format.

### A shortcut click restarts or resumes the app

On Android, shortcut clicks resume the existing app task. `details.launchType`
is `"resume"` when the app was already running and `"cold"` when the shortcut
launched it. Route accordingly.

### Shortcuts disappear after an update or reinstall

The operating system manages dynamic shortcuts and may remove them. Register
them again on every app startup.

### A disabled shortcut cannot be launched

That is expected. Set `disabled: false` or omit `disabled` in an update to
re-enable it.

### Android registration fails with a rate-limit or system error

Android rate-limits the dynamic shortcut APIs, especially while the app is in
the background. Register once at startup and avoid tight update loops. Keep the
`.catch` handler and surface the error during development.

### Android below 7.1

`isSupported()` returns `false`. Registration resolves `false` without touching
the native APIs. Gate the feature in your UI.

## Migration notes

- `registerShortcuts` now returns a `Promise<bool>`. Existing code that ignored
  the return value continues to work.
- `shortcutClicked` still passes the shortcut id as the first argument and adds
  a second `details` argument with `extras` and `launchType`.
- Android shortcut clicks now resume an existing app task instead of always
  restarting it.
- Registrations and updates that exceed the platform limit now reject instead of
  silently dropping shortcuts.
- iOS `updateShortcuts` updates entries in place, preserving their order.

## Limitations and future work

- Only dynamic shortcuts are managed. Static shortcuts in `Info.plist` or
  `res/xml/shortcuts.xml` are not supported.
- Pinned shortcuts (`requestPinShortcut`) are not supported.
- Multiple intents per shortcut, conversation participants, and localized
  shortcut resources are not exposed.
- `getShortcuts` does not return icon names.
- Android-only properties are ignored on iOS.
