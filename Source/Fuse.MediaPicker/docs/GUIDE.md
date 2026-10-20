# Fuse.MediaPicker guide

This guide walks through using `Fuse.MediaPicker` in a Fuse app, explains the platform
behaviour, and documents testing and migration notes.

- [1. What it does](#1-what-it-does)
- [2. Add the package](#2-add-the-package)
- [3. Core concepts](#3-core-concepts)
- [4. Picking images](#4-picking-images)
- [5. Picking videos](#5-picking-videos)
- [6. Camera capture](#6-camera-capture)
- [7. Displaying results](#7-displaying-results)
- [8. Options](#8-options)
- [9. Permissions](#9-permissions)
- [10. Platform differences](#10-platform-differences)
- [11. Errors and cancellation](#11-errors-and-cancellation)
- [12. File lifecycle](#12-file-lifecycle)
- [13. Testing checklist](#13-testing-checklist)
- [14. Troubleshooting](#14-troubleshooting)
- [15. Migration notes](#15-migration-notes)
- [16. Implementation notes](#16-implementation-notes)

## 1. What it does

`Fuse.MediaPicker` exposes the platform media pickers through one FuseJS module:

```javascript
var MediaPicker = require("FuseJS/MediaPicker");
```

It supports:

| Feature | Method |
| --- | --- |
| One image | `pickImage({ maxImages: 1 })` |
| Multiple images | `pickImage({ maxImages: n })` |
| One video | `pickVideo()` |
| Multiple videos | `pickVideos({ maxVideos: n })` |
| Camera photo | `pickImage({ source: SOURCE_CAMERA })` |
| Camera video | `pickVideo({ source: SOURCE_CAMERA })` |

It returns local file paths, not media-library identifiers. Copy the files somewhere permanent if
the app needs them after the current session.

## 2. Add the package

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

Local fuselibs checkout:

```json
{
  "projects": [
    "../fuselibs/Source/Fuse.MediaPicker/Fuse.MediaPicker.unoproj"
  ]
}
```

The package depends on `Fuse.Common`, `Fuse.Marshal`, `Fuse.Scripting`, `Uno.Data.Json` and
`Uno.Threading`; these are pulled in automatically.

When building against a local source checkout, refresh the library cache after editing the
package:

```sh
cd path/to/fuselibs
uno doctor Source
```

Then rebuild the app. Uno otherwise keeps using the cached copy under `Source/build`.

## 3. Core concepts

### Results

| Method | Resolves with |
| --- | --- |
| `pickImage` | `string[]` — one or more absolute paths |
| `pickVideo` | `string` — one absolute path |
| `pickVideos` | `string[]` — one or more absolute paths |

`pickImage` always returns an array, even when `maxImages` is `1`.

### Paths

Paths point to files owned by the app, in its cache or temporary directory. They are valid for
`Image.File` immediately after the promise resolves.

For video playback use `Video.Url` with a `file://` prefix:

```javascript
function fileUrl(path) {
    return path.indexOf("file://") === 0 ? path : "file://" + path;
}
```

`Video.File` combines the path with the platform media directory, which breaks absolute paths.

### Validation

Options are validated before native code runs. Invalid values log a `MediaPicker: option ...`
warning and use a default or a clamped value. The promise does not reject for invalid options.

## 4. Picking images

### One image

```javascript
var MediaPicker = require("FuseJS/MediaPicker");

function pickOneImage() {
    return MediaPicker.pickImage({
        source: MediaPicker.SOURCE_GALLERY,
        maxWidth: 2048,
        maxHeight: 2048,
        quality: 90
    }).then(function (paths) {
        var path = paths[0];
        // Use path with an Image control.
    });
}
```

Setting `maxImages` explicitly is optional; the default is `1`.

### Multiple images

```javascript
function pickManyImages() {
    return MediaPicker.pickImage({
        source: MediaPicker.SOURCE_GALLERY,
        maxImages: 5,
        maxWidth: 1600,
        maxHeight: 1600,
        quality: 85
    }).then(function (paths) {
        paths.forEach(function (path) {
            // Add each path to a list.
        });
    });
}
```

`maxImages: 0` means unlimited. The system picker may still impose its own maximum.

### iOS behaviour

On iOS 14+, images are picked with `PHPickerViewController`, so the app does not request full
photo-library access. On older iOS versions, `UIImagePickerController` is used and
`NSPhotoLibraryUsageDescription` is required.

## 5. Picking videos

### One video

```javascript
function pickOneVideo() {
    return MediaPicker.pickVideo({
        source: MediaPicker.SOURCE_GALLERY
    }).then(function (path) {
        // Play with Video.Url = fileUrl(path).
    });
}
```

### Multiple videos

```javascript
function pickManyVideos() {
    return MediaPicker.pickVideos({
        source: MediaPicker.SOURCE_GALLERY,
        maxVideos: 3
    }).then(function (paths) {
        // paths is an array.
    });
}
```

`pickVideos` always uses the gallery; multiple video capture is not supported. On iOS 14+ it
uses `PHPickerFilter.videosFilter`. Android uses the Photo Picker or a multi-select
`ACTION_GET_CONTENT` intent.

## 6. Camera capture

### Photo

```javascript
function takePhoto(useFrontCamera) {
    return MediaPicker.pickImage({
        source: MediaPicker.SOURCE_CAMERA,
        cameraDevice: useFrontCamera
            ? MediaPicker.CAMERA_FRONT
            : MediaPicker.CAMERA_REAR,
        maxWidth: 2048,
        maxHeight: 2048,
        quality: 90
    }).then(function (paths) {
        // paths[0] is the captured photo.
    });
}
```

### Video

```javascript
function recordVideo() {
    return MediaPicker.pickVideo({
        source: MediaPicker.SOURCE_CAMERA,
        cameraDevice: MediaPicker.CAMERA_REAR,
        maxDuration: 60
    }).then(function (path) {
        // path is the recorded video.
    });
}
```

`maxDuration` is applied to camera recording on iOS. Android applies it through the camera
app's `EXTRA_DURATION_LIMIT`, and some camera apps ignore it.

The camera can capture only one item at a time, so `maxImages` is forced to `1` for
`SOURCE_CAMERA`.

## 7. Displaying results

### Images

```xml
<JavaScript>
    var Observable = require("FuseJS/Observable");
    var MediaPicker = require("FuseJS/MediaPicker");
    var imagePath = Observable("");

    function pick() {
        MediaPicker.pickImage({ maxImages: 1 }).then(function (paths) {
            imagePath.value = paths[0];
        });
    }

    module.exports = { imagePath: imagePath, pick: pick };
</JavaScript>

<StackPanel>
    <Button Text="Pick image" Clicked="{pick}" />
    <Image File="{imagePath}" StretchMode="Uniform" Height="240" />
</StackPanel>
```

### Videos

```javascript
function fileUrl(path) {
    return path.indexOf("file://") === 0 ? path : "file://" + path;
}
```

```xml
<Panel Height="240" Background="#000000">
    <Video Url="{videoUrl}" AutoPlay="true" StretchMode="Uniform" />
</Panel>
```

Do not bind an empty string to `Video.File`, `Video.Url`, or `Image.File`; create the control
only after a path exists, or initialize the binding with a valid bundled asset.

## 8. Options

| Option | Default | Range | Notes |
| --- | --- | --- | --- |
| `source` | `SOURCE_GALLERY` | `0`-`1` | Camera or gallery. |
| `cameraDevice` | `CAMERA_REAR` | `0`-`1` | Camera source only. |
| `maxWidth` | `0` | `0`-`16384` | `0` keeps the original width. |
| `maxHeight` | `0` | `0`-`16384` | `0` keeps the original height. |
| `quality` | `100` | `1`-`100` | JPEG only; PNG ignores it. |
| `maxImages` | `1` | `0`-`1000` | `0` means unlimited. |
| `maxVideos` | `1` | `0`-`1000` | `0` means unlimited. |
| `maxDuration` | `0` | `0`-`86400` | Seconds; `0` means no limit. |

Images are downscaled preserving aspect ratio. Width and height are rounded to whole pixels.

On iOS, images are re-encoded to baseline JPEG or PNG so Fuse's texture loader can display them.
Orientation is applied to the pixels and other EXIF metadata is not preserved. On Android,
unsupported formats are re-encoded while compatible files are returned as-is with their
orientation tag preserved.

## 9. Permissions

### iOS

| Feature | Key |
| --- | --- |
| Camera photo/video | `NSCameraUsageDescription` |
| Camera video with audio | `NSMicrophoneUsageDescription` |
| Legacy gallery picker (iOS 13 and earlier) | `NSPhotoLibraryUsageDescription` |

PHPicker on iOS 14+ does not require photo-library permission.

### Android

- System gallery pickers require no storage permission.
- If the app declares `CAMERA`, the library requests it at runtime before capture.
- If the app does not declare `CAMERA`, camera apps still work through the capture intent.

## 10. Platform differences

| Topic | iOS | Android |
| --- | --- | --- |
| Gallery images | PHPicker (14+) / UIImagePicker (<14) | Photo Picker (33+) / GET_CONTENT |
| Gallery videos | PHPicker (14+) / UIImagePicker (<14) | Photo Picker (33+) / GET_CONTENT |
| Multi-image | PHPicker (14+) | System picker / multi-select |
| Multi-video | PHPicker (14+) | System picker / multi-select |
| Camera | `UIImagePickerController` | `ACTION_IMAGE_CAPTURE` / `ACTION_VIDEO_CAPTURE` |
| Front camera | `cameraDevice` | `cameraDevice` extra |
| `maxDuration` | Camera recording | Camera app dependent |
| Cancel | Rejects the promise | Rejects the promise |
| Image output | Re-encoded JPEG/PNG | Re-encoded JPEG/PNG when needed |

## 11. Errors and cancellation

All methods return promises and reject instead of leaving the app waiting:

```javascript
MediaPicker.pickImage(options).then(function (paths) {
    // Success.
}).catch(function (error) {
    console.log("MediaPicker: " + (error.message || error));
});
```

Common rejection reasons:

- `User cancelled ...`
- `The user did not allow camera access.`
- `The user did not allow photo access.`
- `Could not read the selected image/video.`
- `Could not process the selected image.`
- `Another media picker request is already in progress.`
- `Unsupported on current platform`

## 12. File lifecycle

- Files are written to the app's cache/temporary directory.
- The library does not delete them after the promise resolves.
- They are not visible in the system gallery.
- The OS may clear cache/temporary files at any time.
- Copy important media into app storage using `FuseJS/FileSystem` if it must survive.

## 13. Testing checklist

1. Pick one image and display it with `Image.File`.
2. Pick multiple images with `maxImages: 3`, then with `maxImages: 0`.
3. Set `maxWidth`/`maxHeight` to `512` and verify downscaling.
4. Set `quality` to `40` and verify JPEG size/quality changes.
5. Set `maxWidth`/`maxHeight` to `0` and `quality` to `100`.
6. Pick a PNG with alpha and verify transparency is preserved.
7. Pick a GIF and verify it displays as a static image.
8. Pick a HEIC photo and verify it displays (converted to JPEG).
9. Pick one video and play it through `Video.Url`.
10. Pick multiple videos and verify the returned array.
11. Take a photo with the front and rear camera.
12. Record a video with `maxDuration: 10`.
13. Cancel every picker and verify the promise rejects.
14. Tap two actions quickly and verify the second rejects.
15. Press “Test invalid options” in the demo and check the warnings.
16. Pick a file whose path contains a space and verify the path is intact.

## 14. Troubleshooting

### Images are white on iOS

Older fuselibs versions tint every image with `Image.Color` (white by default). On iOS 13+,
`imageWithTintColor:renderingMode:` produces a white silhouette. Update fuselibs; the fix returns
the original image when the tint is white.

### `Video` throws `Can't open file` or shows `Movies//private/...`

Use `Video.Url` with `file://`, not `Video.File`:

```javascript
var videoUrl = "file://" + path;
```

### Empty image or video path crashes

Do not bind `""` to `Image.File`, `Video.File`, or `Video.Url`. Create the control only after a
path is available, or initialize the binding with a valid bundled asset.

### Generated Objective-C contains broken `setObject: forKey:`

Uno treats `@(...)` as its own expression interpolation in bundled Objective-C. Use explicit
`NSNumber` objects:

```objc
[args setObject:[NSNumber numberWithInt:value] forKey:@"key"];
```

### The app still uses old picker code

Run `uno doctor Source` from the fuselibs checkout, remove the app's `build` directory, and
rebuild.

### Invalid option values are ignored

Check the console for `MediaPicker: option ...` lines. Values are logged and replaced with
defaults or clamped ranges.

## 15. Migration notes

From the original `Fuse.MediaPicker` behaviour:

- `maxWidth` and `maxHeight` now default to `0` (original size), not `1024`.
- `pickVideos(options)` is new.
- `cameraDevice` is now actually passed from JavaScript; it was previously unreachable.
- iOS gallery picking on 14+ no longer requests full photo-library access.
- Android 13+ uses the system Photo Picker instead of `ACTION_GET_CONTENT`.
- Cancelling on iOS now rejects the promise instead of leaving it pending.
- Multiple picker requests are rejected instead of silently replacing callbacks.
- Invalid options log warnings and are clamped/defaulted instead of throwing.
- On iOS, images are re-encoded and other EXIF metadata is no longer preserved (orientation
  is applied to the pixels). Android preserves orientation when resizing.
- Multi-result paths are sent as JSON internally, so paths containing spaces or commas are safe.

From `Fuse.CameraRoll.getImage`:

- `CameraRoll.getImage` returns an `Image` object with width/height.
- `MediaPicker.pickImage` returns an array of paths.
- `MediaPicker` adds camera capture, video, multi-select and resizing options.

## 16. Implementation notes

### JavaScript module

`MediaPickerModule.uno` registers `FuseJS/MediaPicker`, validates options, and converts native
results into JavaScript arrays. Multi-result paths arrive as a JSON array string and are parsed
with `Uno.Data.Json`.

### iOS

- `FOMediaPicker` owns the picker flow and delegate callbacks.
- `FOPHPickerSaveImageOps` loads each PHPicker result and saves it on the main queue.
- `FOMediaPickerImageUtil` scales images.
- `FOMediaPickerMetaDataUtil` detects the image type and produces baseline JPEG/PNG data.
- `FOMediaPickerPhotoAssetUtil` writes the final temporary file.

Images are scaled and encoded on the main queue because UIKit image drawing is not thread-safe.

### Android

- `MediaPicker` maps JavaScript options to picker intents.
- `MediaPickerImpl` owns activity results, permissions, and camera capture.
- `FileUtils` copies content URIs into the app cache.
- `ImageResizer` downsamples and re-encodes images.
- `ExifDataCopier` copies orientation metadata when resizing.

Results are delivered as JSON arrays for multi-item operations.

### Fuse integration

`Fuse.Controls.Native.iOS.ImageView` contains a fix for white image silhouettes: an identity
white tint now returns the original image instead of calling `imageWithTintColor:`.

## See also

- Package API comments: `Source/Fuse.MediaPicker/MediaPickerModule.uno`
- Demo app: `MediaPickerDemo` in the Fuse workspace
- Existing manual tests for images and videos: `Tests/ManualTests/ManualTestingApp`
