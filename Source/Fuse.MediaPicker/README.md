# Fuse.MediaPicker

`Fuse.MediaPicker` picks images and videos from the device gallery or captures them with the
camera. It exposes a small FuseJS API (`FuseJS/MediaPicker`) that returns local file paths ready
to use with `Image` and `Video`.

- iOS uses `PHPickerViewController` on iOS 14+ and `UIImagePickerController` for camera capture.
- Android uses the system Photo Picker on API 33+ and `ACTION_GET_CONTENT` on older versions.
- Gallery picking needs no storage permission. Camera capture requests `CAMERA` at runtime when
  the app declares it in the manifest.

## Installation

Reference the package from your app's project file.

Installed package:

```json
{
  "references": [
    "Fuse",
    "FuseJS",
    "Fuse.MediaPicker"
  ]
}
```

Building against a local fuselibs checkout:

```json
{
  "projects": [
    "path/to/fuselibs/Source/Fuse.MediaPicker/Fuse.MediaPicker.unoproj"
  ]
}
```

When building from source, refresh the library cache after changing the package:

```sh
cd path/to/fuselibs
uno doctor Source
```

## Quick start

```javascript
var MediaPicker = require("FuseJS/MediaPicker");

var options = {
    source: MediaPicker.SOURCE_GALLERY,
    maxWidth: 2048,
    maxHeight: 2048,
    quality: 90,
    maxImages: 5,
    maxVideos: 3
};

MediaPicker.pickImage(options).then(function (imagePaths) {
    // imagePaths is an array of absolute file paths.
});

MediaPicker.pickVideo(options).then(function (videoPath) {
    // videoPath is a single absolute file path.
});

MediaPicker.pickVideos(options).then(function (videoPaths) {
    // videoPaths is an array of absolute file paths.
});
```

## API

| Method | Result | Description |
| --- | --- | --- |
| `pickImage(options)` | `Promise<string[]>` | Picks one or more images. |
| `pickVideo(options)` | `Promise<string>` | Picks or records one video. |
| `pickVideos(options)` | `Promise<string[]>` | Picks one or more videos from the gallery. |

### Constants

| Constant | Value | Meaning |
| --- | --- | --- |
| `SOURCE_CAMERA` | `0` | Use the camera. |
| `SOURCE_GALLERY` | `1` | Use the gallery. |
| `CAMERA_REAR` | `0` | Rear camera (`cameraDevice`). |
| `CAMERA_FRONT` | `1` | Front camera (`cameraDevice`). |

### Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `source` | number | `SOURCE_GALLERY` | Gallery or camera. |
| `cameraDevice` | number | `CAMERA_REAR` | Front or rear camera; camera source only. |
| `maxWidth` | number | `0` | Maximum image width in pixels; `0` keeps the original. |
| `maxHeight` | number | `0` | Maximum image height in pixels; `0` keeps the original. |
| `quality` | number | `100` | JPEG quality, `1`-`100`. Ignored for PNG. |
| `maxImages` | number | `1` | Maximum images to pick; `0` means unlimited. |
| `maxVideos` | number | `1` | Maximum videos to pick; `0` means unlimited. |
| `maxDuration` | number | `0` | Maximum video duration in seconds; `0` means no limit. |

The camera can only capture one item at a time, so `maxImages` is forced to `1` when
`source` is `SOURCE_CAMERA`.

### Behaviour

- `pickImage` always resolves an array, even for a single image.
- `pickVideo` resolves a single path.
- `pickVideos` always uses the gallery; recording multiple videos is not supported.
- `maxImages`/`maxVideos` are subject to the system picker's own limits.
- `maxDuration` is applied to camera recording on iOS. Android may ignore it depending on the
  device's camera app.

## Displaying results

Images can be displayed directly:

```xml
<Image File="{imagePath}" StretchMode="Uniform" />
```

Videos should be played through `Video.Url` with a `file://` URL. `Video.File` joins absolute
paths with the platform's media directory and fails for returned temporary paths.

```javascript
function fileUrl(path) {
    return path.indexOf("file://") === 0 ? path : "file://" + path;
}
```

```xml
<Video Url="{videoUrl}" AutoPlay="true" StretchMode="Uniform" />
```

## Invalid options

Option values are validated in the library:

- non-numeric or `null` values log a warning and use the default,
- values below the minimum log a warning and use the fallback,
- values above the maximum log a warning and are clamped.

Warnings are written with `debug_log`, for example:

```text
MediaPicker: option 'quality' (500) is above 100; using 100.
```

Supported ranges:

| Option | Range |
| --- | --- |
| `source` | `0`-`1` |
| `cameraDevice` | `0`-`1` |
| `maxImages`, `maxVideos` | `0`-`1000` |
| `maxDuration` | `0`-`86400` |
| `quality` | `1`-`100` |
| `maxWidth`, `maxHeight` | `0`-`16384` |

## Errors and cancellation

Every method returns a promise. The promise rejects with a readable message when:

- the user cancels the picker,
- the camera or photo permission is denied,
- the selected file cannot be read or processed,
- another picker request is already open,
- the current platform has no native picker.

```javascript
MediaPicker.pickImage(options).catch(function (error) {
    console.log("MediaPicker: " + (error.message || error));
});
```

## Returned files

- Returned files are copies in the app's cache or temporary directory.
- They are not added to the system gallery.
- On iOS, images are re-encoded to a baseline JPEG or PNG so Fuse's texture loader can decode
  them. Orientation is applied to the pixels and other EXIF metadata is not preserved.
- On Android, unsupported formats are re-encoded to JPEG/PNG. Compatible files are returned
  as-is, with the orientation tag preserved.
- GIFs and other unsupported formats are returned as a static JPEG/PNG.

## Platform notes

### iOS

- Gallery images and videos use `PHPickerViewController` on iOS 14+; no photo-library access is
  requested.
- iOS 13 and earlier use `UIImagePickerController` and require `NSPhotoLibraryUsageDescription`.
- Camera capture requires `NSCameraUsageDescription`. Video recording may require
  `NSMicrophoneUsageDescription`.
- Multi-image and multi-video selection require iOS 14+.

### Android

- API 33+ uses the system Photo Picker (`ACTION_PICK_IMAGES`).
- Older versions use `ACTION_GET_CONTENT`.
- No storage permission is required for the system pickers.
- If the app declares `CAMERA`, the library requests it at runtime before capture.

## API stability

The public API is the `"FuseJS/MediaPicker"` module (`pickImage`, `pickVideo`, `pickVideos`),
its constants and options. Native classes and helper types are internal.

## Troubleshooting

- **Images are white silhouettes on iOS.** Update fuselibs: older versions applied a white
  `Image.Color` tint with `imageWithTintColor:`, producing a white frame.
- **Video playback throws `Can't open file`.** Use `Video.Url` with a `file://` prefix, not
  `Video.File`.
- **A video path contains `Movies//private/...`.** That is the same `Video.File` path bug; use
  `Video.Url`.
- **`@(...)` appears broken in generated Objective-C.** Uno treats `@(expr)` as its own
  interpolation syntax. Use explicit `NSNumber` objects in bundled `.m` files.
- **The picker keeps using old code.** Run `uno doctor Source` after editing fuselibs, then
  rebuild the app.

See [docs/GUIDE.md](docs/GUIDE.md) for a full walkthrough, migration notes and a test checklist.
