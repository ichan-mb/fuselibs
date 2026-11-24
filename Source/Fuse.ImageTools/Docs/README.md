# Fuse.ImageTools

Native image manipulation for Fuse/Uno apps.

`Fuse.ImageTools` exposes the `FuseJS/ImageTools` module. It provides resizing,
cropping, rotation, flipping, EXIF orientation handling, thumbnails, format
conversion, compositing, color filters, text drawing, Base64/buffer encoding,
raw pixel access, and persistent storage.

For recipes, platform behavior, testing, and troubleshooting, see
[GUIDE.md](GUIDE.md).

## Installation

Add `Fuse.ImageTools` to your project references:

```json
{
  "references": [
    "Fuse",
    "FuseJS",
    "Fuse.ImageTools"
  ]
}
```

Then require the module:

```js
var ImageTools = require("FuseJS/ImageTools");
```

## Quick start

```js
var ImageTools = require("FuseJS/ImageTools");

ImageTools.getImageFromBase64(base64Data)
    .then(function (image) {
        console.log(image.width + "x" + image.height);
        return ImageTools.resize(image, {
            desiredWidth: 320,
            desiredHeight: 240,
            mode: ImageTools.KEEP_ASPECT,
            performInPlace: false
        });
    })
    .then(function (resized) {
        return ImageTools.getBase64FromImage(resized, {
            format: "jpeg",
            quality: 85
        });
    })
    .then(function (base64) {
        console.log("Encoded " + base64.length + " characters");
    })
    .catch(function (error) {
        console.log("Image operation failed: " + error);
    });
```

## Image objects

Every operation resolves with a frozen JavaScript object:

| Property | Type | Description |
|---|---|---|
| `path` | string | Absolute path to the backing file. |
| `name` | string | File name. |
| `width` | number | Displayed width in pixels, honoring EXIF orientation. |
| `height` | number | Displayed height in pixels, honoring EXIF orientation. |
| `info` | object | Metadata, populated lazily. |

### `image.info`

| Property | Type | Description |
|---|---|---|
| `mimeType` | string | MIME type, e.g. `image/jpeg`. Empty if unknown. |
| `fileSize` | number | File size in bytes. |
| `orientation` | number | EXIF orientation, `1`–`8`, or `0` if unknown. |
| `hasAlpha` | boolean | Whether the format may contain an alpha channel. |
| `frameCount` | number | Frames in the file. `1` for still images. |
| `isAnimated` | boolean | `true` when `frameCount > 1`. |
| `exif` | object | Common EXIF fields when available. |

`exif` may contain `dateTime`, `make`, `model`, `iso`, `fNumber`,
`exposureTime`, `focalLength`, `flash`, `gpsLatitude`, `gpsLongitude`, and
`gpsAltitude`.

## API

All operations return a `Promise`.

### `resize(image, options)`

| Option | Type | Description |
|---|---|---|
| `desiredWidth` | number | Required new width in pixels. |
| `desiredHeight` | number | New height. Defaults to `desiredWidth`. |
| `mode` | number | Resize mode. Defaults to `IGNORE_ASPECT`. |
| `performInPlace` | boolean | Overwrite the source image. Defaults to `true`. |
| `format` | string | `"jpeg"`, `"png"` or `"webp"`. Defaults to the input format. |
| `quality` | number | `0`–`100` or `0.0`–`1.0`. Defaults to `90`. |
| `background` | number | `PAD` color as `0xAARRGGBB` or `0xRRGGBB`. Defaults to opaque white. `0` is transparent. |

Resize modes:

| Constant | Value | Behavior |
|---|---:|---|
| `ImageTools.IGNORE_ASPECT` | 0 | Resize exactly to the requested size. May upscale. |
| `ImageTools.KEEP_ASPECT` | 1 | Fit within the bounds, preserving aspect. Does not upscale. |
| `ImageTools.SCALE_AND_CROP` | 2 | Scale to cover the bounds, then crop the center. |
| `ImageTools.FIT` | 3 | Fit entirely within the bounds, preserving aspect. May upscale. |
| `ImageTools.PAD` | 4 | Fit within the bounds, then center on a canvas of the requested size. |

### `crop(image, options)`

| Option | Type | Description |
|---|---|---|
| `x` | number | Left offset. Defaults to the value implied by `anchor`. |
| `y` | number | Top offset. Defaults to the value implied by `anchor`. |
| `width` | number | Crop width. |
| `height` | number | Crop height. Defaults to `width` when `aspectRatio` is absent. |
| `aspectRatio` | number | Width/height ratio. Derives a missing dimension, or selects the largest matching crop when both are omitted. |
| `anchor` | string | `"top-left"` (default), `"top"`, `"top-right"`, `"left"`, `"center"`, `"right"`, `"bottom-left"`, `"bottom"`, `"bottom-right"`. |
| `performInPlace` | boolean | Overwrite the source image. Defaults to `true`. |
| `format` | string | Output format. Defaults to the input format. |
| `quality` | number | Output quality. Defaults to `90`. |

The crop rectangle is clamped to the image bounds. If `aspectRatio` is set and
both dimensions are omitted, the largest crop with that ratio is used.

### `rotate(image, options)`

| Option | Type | Description |
|---|---|---|
| `degrees` | number | Clockwise rotation. Values are normalized to 0–360. |
| `performInPlace` | boolean | Overwrite the source image. Defaults to `true`. |
| `format` | string | Output format. Defaults to the input format. |
| `quality` | number | Output quality. Defaults to `90`. |

### `flip(image, options)`

| Option | Type | Description |
|---|---|---|
| `horizontal` | boolean | Flip horizontally. |
| `vertical` | boolean | Flip vertically. |
| `performInPlace` | boolean | Overwrite the source image. Defaults to `true`. |
| `format` | string | Output format. Defaults to the input format. |
| `quality` | number | Output quality. Defaults to `90`. |

At least one of `horizontal` or `vertical` must be `true`.

### `autoOrient(image, options?)`

Applies the image's EXIF orientation to its pixels. `resize` and `crop` already
do this automatically, so `autoOrient` is mainly useful when normalizing an
image without changing its dimensions.

Options: `performInPlace`, `format`, `quality`.

### `thumbnail(image, options)`

| Option | Type | Description |
|---|---|---|
| `maxWidth` | number | Maximum width. |
| `maxHeight` | number | Maximum height. |
| `format` | string | Output format. Defaults to the input format. |
| `quality` | number | Output quality. Defaults to `90`. |

At least one of `maxWidth` or `maxHeight` must be greater than `0`. Thumbnails
preserve aspect ratio, never upscale, and always return a new image.

### `convert(image, options?)`

Re-encodes an image without changing its dimensions.

Options: `format`, `quality`, `performInPlace`.

### `composite(image, overlay, options?)`

Draws `overlay` on top of `image`.

| Option | Type | Description |
|---|---|---|
| `x` | number | Overlay X position. Defaults to `0`. |
| `y` | number | Overlay Y position. Defaults to `0`. |
| `opacity` | number | Overlay opacity from `0` to `1`. Defaults to `1`. |
| `performInPlace` | boolean | Overwrite the base image. Defaults to `true`. |
| `format` | string | Output format. Defaults to the base image format. |
| `quality` | number | Output quality. Defaults to `90`. |

The result keeps the base image dimensions.

### `filter(image, options)`

| Option | Type | Description |
|---|---|---|
| `type` | string | `grayscale`, `sepia`, `brightness`, `contrast`, `saturation` or `blur`. |
| `amount` | number | Strength from `-1` to `1` for brightness, contrast and saturation. Defaults to `0`. |
| `radius` | number | Blur radius in pixels. Defaults to `10`. |
| `performInPlace` | boolean | Overwrite the source image. Defaults to `true`. |
| `format` | string | Output format. Defaults to the input format. |
| `quality` | number | Output quality. Defaults to `90`. |

`blur` is supported on Android and iOS. The .NET target rejects it.

### `drawText(image, options)`

| Option | Type | Description |
|---|---|---|
| `text` | string | Text to draw. Required. |
| `x` | number | X position of the top-left of the text. Defaults to `0`. |
| `y` | number | Y position of the top-left of the text. Defaults to `0`. |
| `fontSize` | number | Font size in pixels. Defaults to `32`. |
| `font` | string | Optional font family name. Defaults to the system font. |
| `color` | number | Text color as `0xAARRGGBB` or `0xRRGGBB`. Defaults to opaque black. |
| `performInPlace` | boolean | Overwrite the source image. Defaults to `true`. |
| `format` | string | Output format. Defaults to the input format. |
| `quality` | number | Output quality. Defaults to `90`. |

Text is drawn on a single line; newline characters are not interpreted.

### `getImageInfo(image)`

Resolves with the same metadata as `image.info`, plus `path`, `name`, `width`
and `height`.

### `delete(image)`

Deletes the image's backing file. Resolves with `true`. Use this for scratch
images that are no longer needed.

### `clearCache()`

Deletes temporary images created by `Fuse.ImageTools`. Resolves with `true`.

### `getImageFromBase64(base64)`

Decodes a Base64 image. Accepts an optional `data:image/...;base64,` prefix and
preserves the source format.

### `getBase64FromImage(image, options?)`

| Option | Type | Description |
|---|---|---|
| `format` | string | `"jpeg"`, `"png"` or `"webp"`. Defaults to the input format. |
| `quality` | number | Output quality. Defaults to `90`. |

The output is not line-wrapped.

### `getImageFromBuffer(arrayBuffer)`

Creates an image from encoded image bytes. Supported on Android and iOS.

### `getBufferFromImage(image)`

Resolves with an `ArrayBuffer` containing the encoded file bytes.

### `getPixelBuffer(image)`

Resolves with an `ArrayBuffer` of straight (non-premultiplied) RGBA8888 pixels,
4 bytes per pixel in row-major order. The length is
`image.width * image.height * 4`.

### `getImageFromUri(uri)`

Loads an image from:
- an absolute path,
- a `file://` URI,
- an Android `content://` URI (copied to a scratch file).

Other URI schemes are rejected.

## Platform support

| Feature | Android | iOS | .NET |
|---|---|---|---|
| JPEG/PNG encode/decode | yes | yes | yes |
| WebP encode | yes | no | no |
| Animated frame count | GIF/WebP | ImageIO formats | System.Drawing formats |
| `blur` filter | yes | yes | no |
| `getImageFromBuffer` | yes | yes | no |
| `content://` URIs | yes | no | no |
| EXIF metadata | yes | yes | common fields |
| Pixel buffer | yes | yes | yes |

## Android permissions

On Android 13 and newer the API requests `READ_MEDIA_IMAGES`,
`READ_MEDIA_VIDEO` and `READ_MEDIA_AUDIO`. Older versions request
`READ_EXTERNAL_STORAGE` and `WRITE_EXTERNAL_STORAGE`.

## Limitations

- `performInPlace` defaults to `true`. Pass `false` to keep the original file.
- Transform operations re-encode the image. Repeated lossy JPEG operations
  reduce quality.
- `save` re-encodes and applies EXIF orientation, so metadata is not preserved.
- `getPixelBuffer` and `blur` allocate buffers proportional to the image size.
- `.NET` uses `System.Drawing.Common`; on .NET 6 macOS/Linux it requires
  `System.Drawing.EnableUnixSupport=true`.
- `blur` is not available on .NET.
- `getImageFromBuffer` is not available on .NET.
- WebP encoding is Android-only.

## See also

- [GUIDE.md](GUIDE.md) — recipes, platform behavior, testing, and troubleshooting.
