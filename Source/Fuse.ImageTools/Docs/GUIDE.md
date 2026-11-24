# Fuse.ImageTools guide

Recipes and platform details for `FuseJS/ImageTools`.

## Getting an image

Images can come from the camera, the camera roll, Base64, an encoded buffer or a
URI:

```js
var ImageTools = require("FuseJS/ImageTools");

// Base64
ImageTools.getImageFromBase64(base64Data)

// Encoded bytes (Android/iOS)
ImageTools.getImageFromBuffer(arrayBuffer)

// Absolute path or file:// URI
ImageTools.getImageFromUri("file:///path/to/photo.jpg")

// Android content:// URI
ImageTools.getImageFromUri(contentUri)
```

All of these resolve with an Image object containing `path`, `name`, `width`,
`height` and `info`.

## Choosing in-place vs. a new file

Every transform has `performInPlace`, which defaults to `true`.

```js
// Overwrite the source file.
ImageTools.resize(image, { desiredWidth: 1280 });

// Keep the source and return a new scratch image.
ImageTools.resize(image, {
    desiredWidth: 1280,
    performInPlace: false
});
```

Prefer `performInPlace: false` while composing a pipeline. In-place transforms
re-encode the file, so a chain of lossy JPEG operations loses quality each time.

## Resizing

### Exact size

```js
ImageTools.resize(image, {
    desiredWidth: 640,
    desiredHeight: 480,
    mode: ImageTools.IGNORE_ASPECT
});
```

### Fit inside bounds

```js
ImageTools.resize(image, {
    desiredWidth: 1920,
    desiredHeight: 1080,
    mode: ImageTools.KEEP_ASPECT // does not upscale
});
```

Use `FIT` instead when you want to upscale smaller images:

```js
ImageTools.resize(image, {
    desiredWidth: 1920,
    desiredHeight: 1080,
    mode: ImageTools.FIT
});
```

### Square or fixed-aspect output

`SCALE_AND_CROP` scales to cover the target bounds and crops the center:

```js
ImageTools.resize(image, {
    desiredWidth: 512,
    desiredHeight: 512,
    mode: ImageTools.SCALE_AND_CROP,
    performInPlace: false
});
```

### Padding / letterboxing

`PAD` fits the image inside the target and fills the remaining area:

```js
ImageTools.resize(image, {
    desiredWidth: 1280,
    desiredHeight: 720,
    mode: ImageTools.PAD,
    background: 0xFFFFFFFF, // opaque white; use 0 for transparent
    performInPlace: false
});
```

For JPEG output, use an opaque background; transparent padding becomes black.

## Cropping

### Absolute rectangle

```js
ImageTools.crop(image, {
    x: 100,
    y: 50,
    width: 640,
    height: 480,
    performInPlace: false
});
```

### Anchor-based crop

Omit `x` and `y` and use `anchor`:

```js
ImageTools.crop(image, {
    width: 512,
    height: 512,
    anchor: "center",
    performInPlace: false
});
```

Supported anchors: `top-left`, `top`, `top-right`, `left`, `center`, `right`,
`bottom-left`, `bottom`, `bottom-right`.

### Aspect-ratio crop

```js
// Largest 16:9 crop, centered.
ImageTools.crop(image, {
    aspectRatio: 16 / 9,
    anchor: "center",
    performInPlace: false
});

// 512 wide, height derived from the ratio.
ImageTools.crop(image, {
    width: 512,
    aspectRatio: 16 / 9,
    performInPlace: false
});
```

The rectangle is clamped to the image bounds.

## Rotating and flipping

```js
ImageTools.rotate(image, { degrees: 90, performInPlace: false });
ImageTools.flip(image, { horizontal: true, performInPlace: false });
ImageTools.flip(image, { horizontal: true, vertical: true, performInPlace: false });
```

`rotate` accepts any angle. 90/180/270 are the most efficient.

## EXIF orientation

`resize` and `crop` apply EXIF orientation automatically. Image `width` and
`height` also report the displayed, oriented dimensions.

To normalize an image without changing its size:

```js
ImageTools.autoOrient(image, { performInPlace: false });
```

`image.info.orientation` still exposes the raw EXIF value.

## Thumbnails

```js
ImageTools.thumbnail(image, {
    maxWidth: 256,
    maxHeight: 256
}).then(function (thumb) {
    // thumb.width and thumb.height are at most 256 and preserve aspect.
});
```

Thumbnails never upscale and always return a new file. At least one bound is
required:

```js
ImageTools.thumbnail(image, { maxWidth: 320 });
ImageTools.thumbnail(image, { maxHeight: 200 });
```

## Format conversion and quality

```js
ImageTools.convert(image, {
    format: "jpeg",
    quality: 85,
    performInPlace: false
});
```

`format` is `"jpeg"`, `"png"` or `"webp"`. When omitted, the input format is
preserved. `quality` accepts `0`–`100` or `0.0`–`1.0`; the default is `90`.

WebP encoding is Android-only. iOS and .NET reject `format: "webp"`.

The same options are available on `resize`, `crop`, `rotate`, `flip`,
`autoOrient`, `composite`, `filter`, `drawText` and `getBase64FromImage`.

## Watermarks and compositing

### Image watermark

```js
ImageTools.composite(photo, logo, {
    x: photo.width - logo.width - 16,
    y: photo.height - logo.height - 16,
    opacity: 0.8,
    performInPlace: false
});
```

The result keeps the base image dimensions. `opacity` is `0`–`1`.

### Text caption

```js
ImageTools.drawText(photo, {
    text: "Hello",
    x: 24,
    y: 24,
    fontSize: 48,
    font: "Helvetica",
    color: 0xFFFFFFFF, // opaque white
    performInPlace: false
});
```

Text is drawn on a single line. `color` accepts `0xAARRGGBB` or `0xRRGGBB` and
defaults to opaque black. `font` defaults to the system font.

## Filters

```js
ImageTools.filter(image, { type: "grayscale", performInPlace: false });
ImageTools.filter(image, { type: "sepia", performInPlace: false });

ImageTools.filter(image, {
    type: "brightness",
    amount: 0.2,
    performInPlace: false
});

ImageTools.filter(image, {
    type: "contrast",
    amount: 0.3,
    performInPlace: false
});

ImageTools.filter(image, {
    type: "saturation",
    amount: -0.5, // -1 = grayscale, 1 = double saturation
    performInPlace: false
});
```

Blur:

```js
ImageTools.filter(image, {
    type: "blur",
    radius: 8,
    performInPlace: false
});
```

`blur` is Android/iOS-only. The .NET target rejects it. `amount` is clamped to
`-1`–`1`.

## Base64 and buffers

```js
ImageTools.getBase64FromImage(image, {
    format: "png"
}).then(function (base64) {
    // No line breaks, safe to embed in a data URI.
});
```

The decoder accepts data URI prefixes:

```js
ImageTools.getImageFromBase64("data:image/png;base64,…");
```

`getBufferFromImage` returns the encoded file bytes:

```js
ImageTools.getBufferFromImage(image).then(function (buffer) {
    // buffer is an ArrayBuffer containing the encoded file.
});
```

`getImageFromBuffer` creates an image from encoded bytes on Android and iOS.

## Pixel access

```js
ImageTools.getPixelBuffer(image).then(function (pixels) {
    // Uint8Array view over the ArrayBuffer.
    var rgba = new Uint8Array(pixels);
    var length = image.width * image.height * 4;
    console.log(length === rgba.length);
});
```

The buffer is straight (non-premultiplied) RGBA8888, row-major, top-down. It is
oriented according to EXIF orientation.

## Saving and managing scratch files

Scratch images live in the app temporary directory. Persist them with `save`:

```js
ImageTools.save(image, {
    directory: "documents", // or "temp"
    name: "profile",
    format: "jpeg",
    quality: 90
}).then(function (saved) {
    console.log("Saved to " + saved.path);
});
```

If the name already exists, a numeric suffix is added. `save` re-encodes the
image and applies EXIF orientation, so metadata is not preserved.

Delete scratch images when done:

```js
ImageTools.delete(image);
```

Clear all temporary ImageTools files:

```js
ImageTools.clearCache();
```

`clearCache` only deletes files named `IMG_*`.

## Metadata

```js
ImageTools.getImageInfo(image).then(function (info) {
    console.log(info.width, info.height, info.mimeType, info.frameCount);
    console.log(info.exif.dateTime, info.exif.make, info.exif.model);
});
```

The same fields are available on `image.info`.

`frameCount` is `1` for still images. Animated counts are extracted from GIF and
WebP files on Android, from ImageIO on iOS, and from System.Drawing on .NET.
There is currently no frame-extraction API.

## Platform behavior

| Area | Android | iOS | .NET |
|---|---|---|---|
| JPEG/PNG | yes | yes | yes |
| WebP encode | yes | no | no |
| Blur | yes | yes | no |
| `getImageFromBuffer` | yes | yes | no |
| `content://` URIs | yes | no | no |
| EXIF metadata | yes | yes | common fields |
| Animated count | GIF/WebP | ImageIO formats | System.Drawing formats |
| Pixel buffer | yes | yes | yes |

### Android

Android 13+ requests `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO` and
`READ_MEDIA_AUDIO`. Older versions request `READ_EXTERNAL_STORAGE` and
`WRITE_EXTERNAL_STORAGE`.

`content://` URIs are copied into a scratch file before use. This is the
recommended path for images received from other apps.

### iOS

`file://` URIs and absolute paths are supported. Other URI schemes are rejected.
WebP encoding is not available.

### .NET

`System.Drawing.Common` is used. On .NET 6 macOS/Linux, set the
`System.Drawing.EnableUnixSupport` runtime switch or run on Windows.

`blur` and `getImageFromBuffer` are not available.

## Performance and memory

- Prefer `thumbnail` over `resize` when creating small previews.
- Pass realistic `maxWidth`/`maxHeight` to `thumbnail`.
- Use `FIT`/`KEEP_ASPECT` rather than `IGNORE_ASPECT` when the target aspect
  differs from the source.
- `getPixelBuffer` and `blur` allocate buffers proportional to
  `width * height`; very large images can exhaust memory.
- Repeated in-place JPEG transforms accumulate compression artifacts.
- Reuse the returned Image objects instead of re-reading files.

## Testing

The package tests live in `Source/Fuse.ImageTools/Tests`. A standalone companion
test project (`ImageToolsTests`, created next to the repository) covers the C#
API:

```sh
uno test -t dotnet ImageToolsTests
```

The companion project also contains `js-smoke-test.js`, which exercises the full
JavaScript API on a device, including buffer round-trips, `clearCache`,
`file://` URIs, crop anchors/aspect ratios, FIT/PAD, conversion, compositing,
filters, text and pixel buffers.

## Troubleshooting

### "Unsupported platform"

The operation is not implemented on the current target. Check the platform
table above; `blur`, WebP encoding and `getImageFromBuffer` have known gaps.

### "WebP encoding is not supported on iOS"

Use JPEG or PNG on iOS, or convert to WebP on Android before transferring.

### "blur is not supported on .NET"

Use Android or iOS for blur, or pre-blur the image before loading it.

### Android permission prompts

Operations use permission-gated commands. If a prompt is denied, the promise
rejects with a permission error.

### Black padding

JPEG has no alpha channel. When using `PAD` with JPEG output, set an opaque
`background`, for example `0xFFFFFFFF`.

### `File not found` from `getImageFromUri`

`file://` paths must be absolute and readable by the app. On Android, prefer
`content://` URIs from the system picker.

### Memory pressure on large images

Use `thumbnail` or resize before applying filters or reading pixels. The native
decoder samples large images for resize/thumbnail, but `getPixelBuffer` and
`blur` still need full-size buffers.

## See also

- [README.md](README.md) — API reference and platform table.
