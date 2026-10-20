# Fuse.Share guide

This guide covers common sharing scenarios and the platform behavior behind
`FuseJS/Share`. For the API summary, see [README.md](../README.md).

## Choosing the API

Use `Share.share(options)` for all new code. It supports text, links, files, and
multiple files in one call and returns a Promise with a result object.

Use `Share.shareFiles(files, mimetype, description, origin)` when you only need
to share files.

`shareText` and `shareFile` are legacy methods. They return a `bool`
synchronously and do not report completion. Keep them only for existing code.

## Sharing text and links

```js
// Text only
Share.share({
    text: "Hello from my app",
    subject: "A subject"
});

// Link with a rich preview on iOS
Share.share({
    url: "https://fuseopen.com/"
});

// Text and link
Share.share({
    text: "Check out Fuse Open:",
    url: "https://fuseopen.com/",
    subject: "Fuse Open"
});
```

On Android the link is appended to the text. On iOS it is passed as an `NSURL`,
which lets targets such as Messages and Mail show a link preview.

`subject` is used by targets that support a subject, such as e-mail. On Android
it is also written to `EXTRA_SUBJECT`.

`chooserTitle` controls the Android chooser title. iOS ignores it.

## Sharing files

`files` accepts one or more absolute paths:

```js
// Single file
Share.share({
    files: ["/path/photo.jpg"],
    subject: "A photo"
});

// Multiple files
Share.share({
    files: ["/path/a.jpg", "/path/b.jpg", "/path/c.jpg"],
    mimeType: "image/*"
});
```

`mimeType` is optional. When omitted, Android detects the type from the file
extension. If multiple files have different types, Android uses `*/*`.

On Android, files are copied into the app's `cache/share` directory before they
are exposed through the `FileProvider`. This keeps the provider surface limited
to that directory. Files already inside `cache/share` are used directly. Cached
files older than 24 hours are cleaned up on the next share.

`content://` URIs are passed through on Android. The app must already have read
access to the URI.

On iOS, paths must exist and be readable, otherwise the share is rejected before
the sheet is shown.

### Using Camera or MediaPicker

```js
var MediaPicker = require("FuseJS/MediaPicker");
var Share = require("FuseJS/Share");

MediaPicker.pickImage({
    source: MediaPicker.SOURCE_CAMERA,
    maxWidth: 2048,
    maxHeight: 2048
}).then(function(paths) {
    return Share.share({
        files: [paths[0]],
        subject: "A photo from my app"
    });
});
```

For multiple images, use `SOURCE_GALLERY` with `maxImages` and pass the
returned array directly to `files`.

## Handling the result

```js
Share.share({ text: "Hello" })
    .then(function(result) {
        if (result.completed) {
            console.log("Shared via " + result.activityType);
        } else {
            console.log("Share cancelled or not reported as completed");
        }
    })
    .catch(function(error) {
        console.log("Share failed: " + error);
    });
```

### What `completed` means

- **iOS**: `UIActivityViewController` reports whether the activity completed.
- **Android**: `completed` means a target was selected, or the chooser reported
  a successful result. Android cannot always tell whether the user finished
  composing or sending.

`activityType` is the iOS `UIActivityType` or the Android component name. It is
`null` when the platform cannot report the target.

## iPad popover anchor

On a wide iPad the share sheet is a popover. Pass a UX element as `origin` to
anchor it:

```xml
<Button ux:Name="ShareButton" Text="Share" Clicked="{shareText}" />

<JavaScript>
    var Share = require("FuseJS/Share");

    module.exports = {
        shareText: function() {
            Share.share({
                text: "Hello",
                origin: ShareButton
            });
        }
    };
</JavaScript>
```

If `origin` is omitted, the popover is centered on the presenting view.

## Concurrency

The system share UI is modal, so only one share can be active at a time. A
second call while a share is open rejects with:

```
A share is already in progress.
```

Legacy `shareText` / `shareFile` return `false` instead.

Wait for the Promise to settle before starting another share:

```js
var sharing = false;

function shareContent() {
    if (sharing)
        return;

    sharing = true;
    Share.share({ text: "Hello" })
        .then(function(result) { /* ... */ })
        .catch(function(error) { /* ... */ })
        .then(function() { sharing = false; });
}
```

## Error handling

All platform failures reject with a user-facing string. Treat the value as an
error message, not a stable error code:

```js
Share.share({ files: [path] })
    .catch(function(error) {
        // Examples:
        // "The file does not exist: /path"
        // "No app is available to handle this share."
        // "A share is already in progress."
    });
```

Validate paths and arguments before starting a share to avoid predictable
failures.

## Platform differences

| Behavior | iOS | Android |
|---|---|---|
| Native UI | `UIActivityViewController` | System chooser + `ACTION_SEND` |
| Multiple files | Multiple activity items | `ACTION_SEND_MULTIPLE` |
| Link handling | `NSURL` with link preview | Appended to shared text |
| Subject | `UIActivityItemSource` subject | `EXTRA_SUBJECT` |
| Chooser title | Ignored | `Intent.createChooser` title |
| MIME type | Inferred from file URL | Used from option or detected from extension |
| File access | Path must exist | Staged in `cache/share` + `FileProvider` |
| Completion | Activity completion | Best-effort target selection |
| iPad origin | Popover anchor | Not applicable |

## Migrating from the legacy API

Before:

```js
Share.shareText("Hello", "Subject");
Share.shareFile(path, "image/jpeg", "Photo");
```

After:

```js
Share.share({ text: "Hello", subject: "Subject" });

Share.share({ files: [path], mimeType: "image/jpeg", subject: "Photo" })
    .then(function(result) { /* ... */ });
```

The new API does not append the description as extra content on iOS. It is used
as a subject where the target supports one.

## Troubleshooting

### The share sheet is narrow on iPhone

The package presents compact-width shares from a dedicated full-screen window.
On current iOS, `UIActivityViewController` otherwise converts the requested page
sheet into a popover. If you see a narrow sheet, make sure the library cache is
up to date:

```sh
uno doctor Source
```

### The Android background is black

The Android system chooser dims the caller. Fuse renders to a native surface,
which the chooser does not snapshot, so the dim layer can appear over a blank
window. This is a platform rendering limitation. A custom in-app share sheet is
the only way to show the app content behind the chooser.

### “A share is already in progress.”

Wait for the previous Promise to settle. Do not start a second share from a
button that can be tapped while the sheet is open.

### “The file does not exist”

Pass an absolute path to a readable file. On Android, files outside the app's
cache/files directories are copied into `cache/share`; the source must still be
readable.

### No share targets

If no app can handle the content, Android rejects with
`No app is available to handle this share.` On iOS the system share sheet may
show only the built-in actions.
