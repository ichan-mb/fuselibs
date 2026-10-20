# Fuse.Share

Cross-app content sharing for Fuse/Uno apps.

`Fuse.Share` exposes the JavaScript module `FuseJS/Share` and uses the native
share UI on each platform:

- **iOS** — `UIActivityViewController`
- **Android** — `ACTION_SEND` / `ACTION_SEND_MULTIPLE` intents with the system chooser

It supports text, links, one or more files, MIME type detection, subjects for
targets that support them, and an optional iPad popover anchor.

For recipes, migration notes, and troubleshooting, see
[docs/GUIDE.md](docs/GUIDE.md).

## Installation

Add a reference to `Fuse.Share` in your project file:

```json
{
  "references": [
    "Fuse",
    "Fuse.Share"
  ]
}
```

Then require the module from JavaScript:

```js
var Share = require("FuseJS/Share");
```

## Quick start

```js
var Share = require("FuseJS/Share");

Share.share({
    text: "Check out Fuse Open:",
    url: "https://fuseopen.com/",
    subject: "Fuse Open"
}).then(function(result) {
    console.log("completed: " + result.completed);
    console.log("activityType: " + result.activityType);
}).catch(function(error) {
    console.log("Share failed: " + error);
});
```

## API

### `Share.share(options)`

Returns a `Promise` that resolves when the share finishes or is cancelled.

| Option | Type | Description |
|---|---|---|
| `text` | string | Text to share. |
| `url` | string | A link to share. On iOS it is passed as an `NSURL` so targets can show a link preview. On Android it is appended to the shared text. |
| `files` | string[] | File paths to share. |
| `mimeType` | string | Optional MIME type. Detected from the file extension when omitted. Multiple files with different types fall back to `*/*`. |
| `subject` | string | Subject for targets that support one, such as e-mail. |
| `chooserTitle` | string | Android chooser title. Ignored on iOS. |
| `origin` | Element | Optional iPad popover anchor, usually a UX element. |

At least one of `text`, `url` or `files` must be provided.

The result object contains:

| Property | Type | Description |
|---|---|---|
| `completed` | bool | On iOS, whether the activity completed. On Android, whether a target was selected or the result was reported as completed. Android cancellation detection is best-effort. |
| `activityType` | string or null | The iOS `UIActivityType` or the Android component name. `null` when the platform cannot report it. |

### `Share.shareFiles(files, mimetype, description, origin)`

Convenience wrapper around `share` for one or more files. `mimetype` is
optional and auto-detected when omitted.

```js
Share.shareFiles(["/path/a.jpg", "/path/b.jpg"], null, "Photos", ShareOrigin)
    .then(function(result) { /* ... */ });
```

### Legacy API

`shareText(text, description, origin)` and `shareFile(path, mimetype, description, origin)`
are kept for backwards compatibility. They return a `bool` synchronously and do
not report completion. New code should use `share` or `shareFiles`.

## Platform notes

### iOS

- The share sheet is presented from a dedicated full-screen window on compact
  widths (iPhone, Slide Over, narrow windows). On current iOS,
  `UIActivityViewController` forces a popover presentation even when a page
  sheet is requested, so the dedicated window is required for the normal wide
  sheet.
- On a wide iPad, a normal popover is used. Pass `origin` to control the anchor;
  otherwise the center of the presenting view is used.
- File paths must exist and be readable. Missing files reject before the share
  sheet is shown.
- `mimeType` is currently ignored on iOS; `UIActivityViewController` infers the
  type from the file URL.

### Android

- Files are staged into the app's `cache/share` directory and exposed through
  the package's `FileProvider`. Files already in that directory are used
  directly. Staged files older than 24 hours are cleaned up.
- `content://` URIs are passed through unchanged.
- The selected target is reported through the chooser's `IntentSender`. If the
  chooser is dismissed, the activity result is used to resolve the share as
  cancelled after a short grace period.
- `completed` means a target was selected; Android cannot always report whether
  the user finished sending.
- The system chooser can show a black background behind the sheet. Fuse renders
  into a native surface, which the chooser does not snapshot, so the dim layer
  is composited over a blank window. This is a platform rendering limitation,
  not a share-intent setting.

## Concurrency

Only one share can be active at a time. A second `share` / `shareFiles` call
while one is open rejects with:

```
A share is already in progress.
```

Legacy `shareText` / `shareFile` calls return `false` in the same situation.

## Errors

Promise rejections are user-facing strings. Common errors include:

- `A share is already in progress.`
- `Share is not supported on this platform.`
- `The file does not exist: <path>`
- `No content to share.`
- `No app is available to handle this share.`
- `No active Android activity to show the share dialog.`
- `No view controller available to present the share dialog.`

## iPad example

```xml
<Panel>
    <Button Text="Share" Clicked="{shareText}" />
    <Panel ux:Name="ShareOrigin" Width="1" Height="1" Alignment="Top" />

    <JavaScript>
        var Share = require("FuseJS/Share");

        module.exports = {
            shareText: function() {
                Share.share({
                    text: "The link to Fuse Open website",
                    url: "https://fuseopen.com/",
                    origin: ShareOrigin
                });
            }
        };
    </JavaScript>
</Panel>
```

## Development

The package lives in `Source/Fuse.Share`.

```sh
# Rebuild the local library cache after changing package sources
uno doctor Source

# Run the package tests
uno test Source/Fuse.Share/Tests/Fuse.Share.Test.unoproj
```

The manual test page is
`Tests/ManualTests/ManualTestingApp/Singles/Sharing.ux`.

### Package layout

- `ShareModule.uno` — public JS API and legacy methods
- `ShareRequest.uno` — options parsing and origin resolution
- `ShareResult.uno` — result object and Promise settlement
- `ShareSessionGuard.uno` — single-share concurrency guard
- `android/` — intent building, file staging, chooser session
- `ios/` — item construction and share-sheet presentation
- `docs/` — README guide with recipes and troubleshooting
- `Tests/` — parser and guard tests

## Known limitations

- One share at a time.
- Android cannot reliably distinguish “target selected” from “share finished”.
- Android shows a black scrim behind the system chooser for native-rendered
  Fuse apps.
- `mimeType` is not used on iOS.
- Inbound sharing (receiving content) is not supported by this package. Android
  would require intent filters; iOS requires a separate Share Extension target.
