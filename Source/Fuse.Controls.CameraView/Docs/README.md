This package provides a cross-platform abstraction over the native camera APIs on Android and iOS. On Android it uses CameraX and adds the required Gradle dependencies automatically. On iOS it uses AVFoundation photo and video outputs. In order to use this package you must add a reference to `Fuse.Controls.CameraView` in your `unoproj`.

The `CameraView` API is mostly exposed as a [`Promise`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise) based API in JavaScript. Lets have a look at how to get up and running:

```xml
<DockPanel>
    <!-- The size and aspect of the camera live preview
         does not always match they size your cameraview
         is given by layout. Set stretchmode to either Uniform
         or Fill to deal with this
     -->
    <CameraView ux:Name="_cameraView" PreviewStretchMode="UniformToFill" />
    <JavaScript>
        var Observable = require("FuseJS/Observable");
        var Camera = _cameraView;

        // Observables for dealing with
        // the different states of the camera
        var captureMode = Observable();
        var cameraFacing = Observable();
        var flashMode = Observable();
        var cameraReady = Observable(false);

        // getCamereInfo will resolve when the camera is fully loaded
        Camera.getCameraInfo()
            .then(function(info) {
                captureMode.value = info[Camera.INFO_CAPTURE_MODE];
                cameraFacing.value = info[Camera.INFO_CAMERA_FACING];
                flashMode.value = info[Camera.INFO_FLASH_MODE];
                console.log("zoom: " + info[Camera.INFO_ZOOM]);
                console.log("torch: " + info[Camera.INFO_TORCH_ON]);
                console.log("exposure: " + info[Camera.INFO_EXPOSURE_COMPENSATION]);
                console.log("lens: " + info[Camera.INFO_LENS_ID]);
                cameraReady.value = true;
            })
            .catch(function(error) {
                console.log("Failed to get camera info: " + error);
            });
    </JavaScript>
</DockPanel>
```

`PreviewStretchMode` controls how the preview fills the view: `Uniform` (fit) or `UniformToFill` (fill and crop).

The `<CameraView />` tag is the UI element that will display a live preview from the camera. The camera is loading asynchronously and the `getCameraInfo` promise wont resolve until it is loaded. This can be used to reflect if the camera is ready and its initial state in your UI.

### Capturing a photo

To capture a photo, make sure the camera is loaded as discussed above and set its capture mode to photo. If a photo capture was successful you will get an object representing the native photo result, you can call `save()` to store the photo on disk and get a filepath. A photo may require a lot of memory on your device, make sure to call `release()` on it when you are done using it. It is considered bad practice to keep many photo objects around as this can lead to out-of-memory crashes.

```js
Camera.setCaptureMode(Camera.CAPTURE_MODE_PHOTO)
  .then(function (newCaptureMode) {
    /* ready to capture photo */
  })
  .catch(function (error) {
    /* failed */
  });

function capturePhoto() {
  Camera.capturePhoto()
    .then(function (photo) {
      photo
        .save()
        .then(function (filePath) {
          console.log("Photo saved to: " + filePath);
          photo.release();
        })
        .catch(function (error) {
          console.log("Failed to save photo: " + error);
          photo.release();
        });
    })
    .catch(function (error) {
      console.log("Failed to capture photo: " + error);
    });
}
```

Use `photo.saveThumbnail(sizeHint)` to save a downscaled version and `photo.saveToCameraRoll()` to add the photo to the device gallery.

```js
Camera.capturePhoto().then(function (photo) {
  photo
    .saveThumbnail({ width: 128, height: 128 })
    .then(function (thumbnailPath) {
      console.log("Thumbnail saved to: " + thumbnailPath);
      photo.release();
    });

  photo.saveToCameraRoll().then(function (saved) {
    console.log("Added to the camera roll: " + saved);
  });
});
```

### Photo metadata

`photo.getMetadata()` resolves with the details of a captured photo:

```js
Camera.capturePhoto()
  .then(function (photo) {
    photo.getMetadata().then(function (metadata) {
      console.log(metadata.width + "x" + metadata.height);
      console.log("orientation: " + metadata.orientation);
      console.log(
        "iso: " +
          metadata.iso +
          ", exposure: " +
          metadata.exposureTime +
          "s, f/" +
          metadata.fNumber,
      );
      photo.release();
    });
  })
  .catch(function (error) {});
```

`width` and `height` are the displayed pixel dimensions (they are swapped for EXIF orientations 5 to 8), and `orientation` is the EXIF orientation value (1 to 8). `timestamp` is the capture time in milliseconds since the Unix epoch.

`iso`, `exposureTime` (in seconds), `fNumber` and `focalLength` (in millimeters) come from the JPEG's EXIF data and are `0` when the camera did not provide them. The metadata is read from the captured image data, so it is available before the photo is saved.

The field names are available as `META_WIDTH`, `META_HEIGHT`, `META_ORIENTATION`, `META_TIMESTAMP`, `META_ISO`, `META_EXPOSURE_TIME`, `META_F_NUMBER` and `META_FOCAL_LENGTH`, and the recording metadata fields as `RECORDING_META_WIDTH`, `RECORDING_META_HEIGHT`, `RECORDING_META_DURATION` and `RECORDING_META_FILE_SIZE`.

### Scanning a barcode or QR code

`scanBarcode()` turns the live preview into a barcode reader. It resolves with the first code found and then restores the camera to the state it had before the scan started. Pass an optional array of formats to restrict what is scanned.

```js
function scanBarcode() {
  Camera.scanBarcode()
    .then(function (barcode) {
      console.log("Value: " + barcode[Camera.BARCODE_VALUE]);
      console.log("Format: " + barcode[Camera.BARCODE_FORMAT]);
    })
    .catch(function (error) {
      console.log("Barcode scan failed: " + error);
    });
}

// Only look for QR codes
Camera.scanBarcode([Camera.BARCODE_FORMAT_QR_CODE]);

// Keep scanning: start again whenever a code is found
function scanForever() {
  Camera.scanBarcode()
    .then(function (barcode) {
      console.log(barcode[Camera.BARCODE_VALUE]);
      scanForever();
    })
    .catch(function (error) {});
}
```

For continuous scanning use `startBarcodeScanning()`. The callback is invoked once for every new code detected, and `stopBarcodeScanning()` ends the scan. Repeats of the same value are not reported again.

```js
Camera.startBarcodeScanning(
  function (barcode) {
    console.log("Detected: " + barcode[Camera.BARCODE_VALUE]);
  },
  [Camera.BARCODE_FORMAT_QR_CODE],
)
  .then(function () {
    /* scanning started */
  })
  .catch(function (error) {
    /* could not start */
  });

// Later
Camera.stopBarcodeScanning().then(function (wasScanning) {});
```

The format is one of the `BARCODE_FORMAT_*` constants: `QR_CODE`, `EAN_13`, `EAN_8`, `UPC_A`, `UPC_E`, `CODE_128`, `CODE_39`, `CODE_93`, `PDF417`, `AZTEC`, `DATA_MATRIX`, `ITF` or `CODABAR`. Note that iOS reports UPC-A codes as `EAN_13` (and also accepts `UPC_A` as a requested format), and `CODABAR` requires iOS 15.4 or newer.

Scanning is not available while a photo is being captured or a video is being recorded. Barcode scanning can run together with `startFaceDetection()`.

This feature adds the `com.google.mlkit:barcode-scanning` Gradle dependency on Android and uses `AVCaptureMetadataOutput` on iOS.

### Face detection

`startFaceDetection(callback)` analyzes the live preview and calls the callback with the faces found in each frame. The promise resolves when detection has started, and `stopFaceDetection()` stops it.

```js
Camera.startFaceDetection(function (faces) {
  faces.forEach(function (face) {
    console.log(
      face[Camera.FACE_ID] +
        ": " +
        face[Camera.FACE_X] +
        ", " +
        face[Camera.FACE_Y],
    );
  });
})
  .then(function () {
    /* detection started */
  })
  .catch(function (error) {
    /* could not start */
  });

// Later
Camera.stopFaceDetection().then(function (wasDetecting) {});
```

Face bounds are normalized to the preview (0 to 1), with the origin in the top left corner of the preview as it is displayed, so they can be used directly to position overlays. `FACE_ID` is the platform's tracking id, or `-1` when the platform does not track faces. `FACE_ROLL` and `FACE_YAW` give the head rotation in degrees (0 when the platform does not provide it).

Face detection and barcode scanning can run at the same time; both use the camera's frame analysis pipeline and share the analyzed frames.

### Frame analysis

`startFrameAnalysis()` delivers statistics for the frames the camera analyses: a 64 bin luminance histogram, mean and percentile luminance, how much of the frame is clipped, and how long the frame took to analyse. Everything is computed natively, so nothing is sent to JavaScript unless you ask for it.

```js
var options = {};
options[Camera.OPTION_ANALYSIS_MAX_FPS] = 10;
options[Camera.OPTION_ANALYSIS_RESOLUTION] = { width: 640, height: 480 };
options[Camera.OPTION_ANALYSIS_LUMA_WIDTH] = 96;
options[Camera.OPTION_ANALYSIS_LUMA_HEIGHT] = 72;

Camera.startFrameAnalysis(function (stats) {
    var mean = stats[Camera.STATS_MEAN];              /* 0..1 */
    var median = stats[Camera.STATS_P50];
    var clipped = stats[Camera.STATS_CLIPPED_HIGH];   /* fraction above 98% */
    var histogram = stats[Camera.STATS_HISTOGRAM];    /* 64 bins, each 0..1 */

    if (stats[Camera.STATS_LUMA]) {
        var pixels = new Uint8Array(stats[Camera.STATS_LUMA]);
        /* pixels[(y * width) + x], upright and mirrored like the preview */
    }
})
    .then(function () { })
    .catch(function (error) { });

/* Later */
Camera.stopFrameAnalysis().then(function (wasAnalysing) { });
```

Every payload contains `timestamp` (milliseconds on a monotonic clock), `mean`, `p1`, `p50`, `p99`, `clippedLow`, `clippedHigh` (all normalized to 0..1), `histogram` (an array of 64 values, each normalized to 0..1) and `analysisTime` (milliseconds spent analysing the frame). When `lumaWidth` and `lumaHeight` are set, `luma` (an `ArrayBuffer` with one byte per pixel), `lumaWidth` and `lumaHeight` are included as well.

The default rate is 15 callbacks per second and the default analysis resolution is 640x480. Raising either costs battery and can limit the other camera streams, so every payload includes `analysisTime` to make the cost visible on a given device. The resolution is applied when analysis starts.

Frame analysis shares the camera's analysis stream with barcode scanning and face detection, so all three can run at the same time. It cannot run while capturing a photo or recording video.

#### Zebra and focus peaking

`setOverlayOptions()` draws an analysis overlay on top of the preview. `zebra` marks pixels at or above the given luminance with diagonal stripes, and `peaking` highlights edges, where a higher value detects weaker edges. Both are normalized to 0..1 and 0 turns that part off.

```js
var options = {};
options[Camera.OPTION_OVERLAY_ZEBRA] = 0.95;   /* 95% luminance and above */
options[Camera.OPTION_OVERLAY_PEAKING] = 0.6;

Camera.setOverlayOptions(options)
    .then(function (applied) { })
    .catch(function (error) { });

/* Turn it off */
Camera.setOverlayOptions({});
```

The overlay is drawn natively at 24 frames per second from a downscaled luminance image, so it costs nothing in JavaScript. It follows the preview's letterboxing and mirroring, and it is not part of the captured photo or video.

### Recording video

Make sure the capture mode is set to video. When you start a recording you get a session object which you need to hold onto. When you call `stop()` on the recording session you will get a file path to the result.

```js
Camera.setCaptureMode(Camera.CAPTURE_MODE_VIDEO)
  .then(function (newCaptureMode) {
    /* ready to record video */
  })
  .catch(function (error) {
    /* failed */
  });

var recordingSession = null;

function startRecording() {
  Camera.startRecording()
    .then(function (session) {
      console.log("Video recording started!");
      recordingSession = session;
    })
    .catch(function (error) {
      console.log("Failed to start recording: " + error);
    });
}

function stopRecording() {
  if (session == null) return;

  session
    .stop()
    .then(function (recording) {
      console.log("Recording stopped, saved to: " + recording.filePath());
      session = null;
    })
    .catch(function (error) {
      console.log("Failed to stop recording: " + error);
      session = null;
    });
}
```

### Manual exposure

Use `setManualExposure(iso, shutterSeconds)` for manual ISO/shutter control and `setAutoExposure()` to return to automatic exposure. The supported ranges are reported by `getCameraCapabilities()`.

```js
Camera.getCameraCapabilities().then(function (caps) {
  console.log(
    "ISO: " + caps[Camera.CAP_MIN_ISO] + " - " + caps[Camera.CAP_MAX_ISO],
  );
  console.log(
    "Shutter: " +
      caps[Camera.CAP_MIN_SHUTTER_SECONDS] +
      " - " +
      caps[Camera.CAP_MAX_SHUTTER_SECONDS],
  );
});

Camera.setManualExposure(400, 1 / 60)
  .then(function (settings) {
    console.log(settings);
  })
  .catch(function (error) {});

Camera.setAutoExposure().then(function (settings) {
  console.log(settings);
});
```

`getManualExposure()` reports the current state:

```js
Camera.getManualExposure().then(function (settings) {
  console.log(settings.isManual, settings.iso, settings.shutterSeconds);
});
```

### White balance

Use `setWhiteBalance()` with one of the `WHITE_BALANCE_*` constants and `getWhiteBalance()` to read the current mode. The modes supported by the current camera are listed in `CAP_WHITE_BALANCE_MODES` by `getCameraCapabilities()`.

```js
Camera.getCameraCapabilities().then(function (caps) {
  console.log(
    "White balance modes: " + caps[Camera.CAP_WHITE_BALANCE_MODES].join(", "),
  );
});

Camera.setWhiteBalance(Camera.WHITE_BALANCE_DAYLIGHT)
  .then(function (mode) {
    console.log("White balance: " + mode);
  })
  .catch(function (error) {
    console.log("Failed to set white balance: " + error);
  });

Camera.getWhiteBalance().then(function (mode) {
  console.log("White balance: " + mode);
});
```

Available modes are `WHITE_BALANCE_AUTO`, `WHITE_BALANCE_INCANDESCENT`, `WHITE_BALANCE_FLUORESCENT`, `WHITE_BALANCE_WARM_FLUORESCENT`, `WHITE_BALANCE_DAYLIGHT`, `WHITE_BALANCE_CLOUDY`, `WHITE_BALANCE_TWILIGHT` and `WHITE_BALANCE_SHADE`. `getCameraInfo()` reports the current value in `INFO_WHITE_BALANCE`.

For finer control, `setWhiteBalanceTemperature(kelvin, tint)` locks the white balance to a color temperature in Kelvin and a tint in the `-150` to `150` range (positive is magenta, negative is green). `getWhiteBalanceTemperature()` returns the current values, and `getWhiteBalance()` reports `WHITE_BALANCE_MANUAL` while they are active. Use `CAP_MANUAL_WHITE_BALANCE_SUPPORTED` to check availability.

```js
Camera.setWhiteBalanceTemperature(5000, 0)
  .then(function (settings) {
    console.log(settings.isManual, settings.kelvin, settings.tint);
  })
  .catch(function (error) {
    console.log("Failed to set white balance temperature: " + error);
  });

Camera.getWhiteBalanceTemperature().then(function (settings) {
  console.log("Manual white balance: " + settings.isManual);
});
```

On Android the modes map directly to the Camera2 auto white balance modes, so a device may report only a subset. On iOS the presets are implemented with fixed temperature/tint values, so all modes are available. Manual white balance converts the temperature and tint to color correction gains on both platforms, but the exact rendering may differ slightly between them.

### Focus

`setCameraFocusPoint(x, y, cameraWidth, cameraHeight, lock)` focuses on a point in the preview. Pass `1` as `lock` to keep the focus, exposure and white balance fixed after focusing.

```js
// Focus on the middle of the preview (lock = 0 keeps continuous focus)
Camera.setCameraFocusPoint(width / 2, height / 2, width, height, 0).catch(function (
  error,
) {
  console.log("Failed to set focus point: " + error);
});
```

Use `setFocusMode()` to control how the camera focuses. The current mode is reported in `INFO_FOCUS_MODE` by `getCameraInfo()` and the supported modes are listed in `CAP_FOCUS_MODES`.

```js
// Focus once, then hold
Camera.setFocusMode(Camera.FOCUS_MODE_AUTO);

// Keep adjusting the focus (the default)
Camera.setFocusMode(Camera.FOCUS_MODE_CONTINUOUS);

// Keep the focus where it currently is; tap-to-focus is ignored
Camera.setFocusMode(Camera.FOCUS_MODE_LOCKED)
  .then(function (mode) {
    console.log("Focus mode: " + mode);
  })
  .catch(function (error) {
    console.log("Failed to set focus mode: " + error);
  });

Camera.getFocusMode().then(function (mode) {
  console.log("Focus mode: " + mode);
});
```

Tapping the preview never discards manual exposure or white balance settings.

### Lens selection

Use `getAvailableLenses()` to enumerate the device cameras and `setCameraLens()` to switch to one. Lens ids are opaque strings provided by the platform.

Camera settings such as zoom, torch, flash mode, exposure compensation, manual exposure, white balance, focus mode and mirror mode are kept when switching lens.

```js
Camera.getAvailableLenses().then(function (lenses) {
  lenses.forEach(function (lens) {
    console.log(lens[Camera.LENS_NAME] + " (" + lens[Camera.LENS_ID] + ")");
  });
});

Camera.setCameraLens(someLensId)
  .then(function (appliedLensId) {
    console.log("Using lens: " + appliedLensId);
  })
  .catch(function (error) {});
```

### Exposure compensation

Use `setExposureCompensation` to apply an exposure bias. The supported range and step are reported by `getCameraCapabilities()`.

```js
Camera.setExposureCompensation(0.5)
  .then(function (value) {
    console.log("Exposure compensation: " + value);
  })
  .catch(function (error) {
    console.log("Failed to set exposure compensation: " + error);
  });
```

`getExposureCompensation()` resolves to the current bias, in EV.

```js
Camera.getExposureCompensation().then(function (value) {
  console.log("Exposure compensation: " + value);
});
```

### Recording options

Use `setVideoOptions` before switching to video mode. The resolution is a hint; the platform picks the closest supported profile. Frame rate and bit rate are applied on Android; iOS currently ignores them.

```js
var videoOptions = {};
videoOptions[Camera.OPTION_VIDEO_RESOLUTION] = { width: 1920, height: 1080 };
videoOptions[Camera.OPTION_VIDEO_FRAME_RATE] = 30;
videoOptions[Camera.OPTION_VIDEO_BIT_RATE] = 8000000;
videoOptions[Camera.OPTION_VIDEO_AUDIO_ENABLED] = true;
videoOptions[Camera.OPTION_VIDEO_STABILIZATION_ENABLED] = true;

Camera.setVideoOptions(videoOptions)
  .then(function () {})
  .catch(function (error) {});
```

### Pause, resume and duration

While recording, `getDuration()` returns the recorded duration in milliseconds, excluding paused time. `pause()` stops adding to the recording and `resume()` continues it; both resolve to `false` when they do not apply (for example resuming when not paused).

Pausing is supported on Android (API 24+) and on iOS. On iOS the recording is written as segments that are joined when the recording is stopped, since AVFoundation's file output has no pause API.

```js
session.getDuration().then(function (ms) {
  console.log(ms);
});
session.pause().then(function (paused) {});
session.resume().then(function (resumed) {});
```

### Recording thumbnail and metadata

`recording.saveThumbnail(sizeHint)` writes a JPEG frame from the recording and resolves to its file path. `recording.getMetadata()` describes the finished video.

```js
session.stop().then(function (recording) {
  recording.getMetadata().then(function (metadata) {
    console.log(
      metadata.width + "x" + metadata.height + ", " + metadata.duration + "ms",
    );
    console.log("file size: " + metadata.fileSize + " bytes");
  });

  recording
    .saveThumbnail({ width: 128, height: 128 })
    .then(function (thumbnailPath) {
      console.log("Thumbnail saved to: " + thumbnailPath);
    });
});
```

`width` and `height` are the displayed dimensions of the video, `duration` is in milliseconds and `fileSize` is in bytes. The thumbnail keeps the aspect ratio of the video.

### Save to camera roll

```js
photo.saveToCameraRoll().then(function (saved) {});
recording.saveToCameraRoll().then(function (saved) {});
```

### Mirroring

Use `setMirrorMode()` to control whether the preview and captured photos and videos are mirrored. `MIRROR_MODE_AUTO` mirrors the preview for the front camera only (the default), `MIRROR_MODE_ON` mirrors everything and `MIRROR_MODE_OFF` mirrors nothing. The current mode is reported in `INFO_MIRROR_MODE` by `getCameraInfo()`.

```js
Camera.setMirrorMode(Camera.MIRROR_MODE_ON)
  .then(function (mode) {
    console.log("Mirror mode: " + mode);
  })
  .catch(function (error) {
    console.log("Failed to set mirror mode: " + error);
  });

Camera.getMirrorMode().then(function (mode) {
  console.log("Mirror mode: " + mode);
});
```

The supported modes are listed in `CAP_MIRROR_MODES` by `getCameraCapabilities()`. Changing the mirror mode is not possible while capturing a photo or recording video, since it requires reconfiguring the camera.

### Change camera facing

You can change the camera facing when the camera is not busy. For example, you cannot change camera facing while recording video or capturing a photo.

Camera settings such as zoom, torch, flash mode, exposure compensation, manual exposure, white balance, focus mode and mirror mode are kept when switching facing, and when the camera is recreated after the app returns to the foreground.

```js
var currentFacing = Camera.CAMERA_FACING_BACK;

function flipFacing() {
  var facing =
    currentFacing == Camera.CAMERA_FACING_BACK
      ? Camera.CAMERA_FACING_FRONT
      : Camera.CAMERA_FACING_BACK;

  Camera.setCameraFacing(facing)
    .then(function (newCameraFacing) {
      console.log("Camera facing set to: " + newCameraFacing);
    })
    .catch(function (error) {
      console.log("Failed to set camera facing: " + error);
    });
}
```

### Zoom

Use `setZoom` to apply a zoom factor. `1.0` means no zoom. Use `getCameraCapabilities()` to read the supported range.

```js
Camera.getCameraCapabilities().then(function (caps) {
  console.log(
    "zoom: " + caps[Camera.CAP_MIN_ZOOM] + " - " + caps[Camera.CAP_MAX_ZOOM],
  );
});

Camera.setZoom(2.0)
  .then(function (zoom) {
    console.log("Zoom set to: " + zoom);
  })
  .catch(function (error) {
    console.log("Failed to set zoom: " + error);
  });
```

`getZoom()` resolves to the current zoom factor.

```js
Camera.getZoom().then(function (zoom) {
  console.log("Current zoom: " + zoom);
});
```

### Flash mode

`setFlashMode()` selects how the capture flash is used: `FLASH_MODE_AUTO`, `FLASH_MODE_ON` or `FLASH_MODE_OFF`. The current mode is reported in `INFO_FLASH_MODE` and the supported modes in `CAP_SUPPORTED_FLASH_MODES`.

```js
Camera.setFlashMode(Camera.FLASH_MODE_AUTO)
  .then(function (mode) {
    console.log("Flash mode: " + mode);
  })
  .catch(function (error) {
    console.log("Failed to set flash mode: " + error);
  });
```

### Torch

The torch is independent of the capture flash mode. Check `CAP_TORCH_SUPPORTED` before using it.

```js
Camera.setTorchMode(true)
  .then(function (isOn) {
    console.log("Torch on: " + isOn);
  })
  .catch(function (error) {
    console.log("Failed to set torch mode: " + error);
  });
```

`isTorchOn()` resolves to the current torch state.

### Camera errors and interruptions

`startErrorMonitoring(callback)` reports problems with the camera session. The callback receives an object with a `type`, a platform specific `reason` and a human readable `message`.

```js
Camera.startErrorMonitoring(function (event) {
  console.log(event[Camera.EVENT_TYPE] + ": " + event[Camera.EVENT_REASON]);

  if (event[Camera.EVENT_TYPE] == Camera.EVENT_INTERRUPTED) {
    // for example a phone call or another app took the camera
  }
})
  .then(function () {
    /* monitoring started */
  })
  .catch(function (error) {
    /* could not start */
  });

// Later
Camera.stopErrorMonitoring().then(function (wasMonitoring) {});
```

The event types are `EVENT_ERROR` (the camera reported a problem), `EVENT_INTERRUPTED` (the session was interrupted) and `EVENT_RESUMED` (a previous interruption ended).

The `reason` is platform specific. Common values are `in-use` and `unknown`; iOS can also report `background`, `system-pressure`, `media-services-reset`, `disconnected`, `interrupted` and `too-many-captures`, while Android can report `disabled`, `fatal`, `recoverable`, `stream-config` and `do-not-disturb`.

### Camera info

`getCameraInfo()` resolves once the camera is loaded and reports its current state:

| Key | Description |
| --- | --- |
| `INFO_CAPTURE_MODE` | `CAPTURE_MODE_PHOTO` or `CAPTURE_MODE_VIDEO` |
| `INFO_CAMERA_FACING` | `CAMERA_FACING_FRONT` or `CAMERA_FACING_BACK` |
| `INFO_FLASH_MODE` | current flash mode |
| `INFO_SUPPORTED_FLASH_MODES` | flash modes supported by this camera |
| `INFO_ZOOM` | current zoom factor |
| `INFO_TORCH_ON` | whether the torch is on |
| `INFO_EXPOSURE_COMPENSATION` | current exposure bias, in EV |
| `INFO_WHITE_BALANCE` | current white balance mode, or `WHITE_BALANCE_MANUAL` |
| `INFO_FOCUS_MODE` | current focus mode |
| `INFO_MIRROR_MODE` | current mirror mode |
| `INFO_LENS_ID` | id of the active lens |
| `INFO_PHOTO_RESOLUTIONS` | available photo sizes, as `{ width, height }` (platform dependent) |

### Camera capabilities

`getCameraCapabilities()` describes what the loaded camera can do:

| Keys | Description |
| --- | --- |
| `CAP_ZOOM_SUPPORTED`, `CAP_MIN_ZOOM`, `CAP_MAX_ZOOM` | zoom support and range |
| `CAP_TORCH_SUPPORTED` | whether the torch is available |
| `CAP_PHOTO_RESOLUTIONS` | supported photo sizes |
| `CAP_SUPPORTED_FLASH_MODES` | supported flash modes |
| `CAP_SUPPORTED_FACINGS` | available camera facings |
| `CAP_MIN_EXPOSURE_COMPENSATION`, `CAP_MAX_EXPOSURE_COMPENSATION`, `CAP_EXPOSURE_COMPENSATION_STEP` | exposure compensation range and step |
| `CAP_MANUAL_EXPOSURE_SUPPORTED`, `CAP_MIN_ISO`, `CAP_MAX_ISO`, `CAP_MIN_SHUTTER_SECONDS`, `CAP_MAX_SHUTTER_SECONDS` | manual ISO/shutter support and range |
| `CAP_WHITE_BALANCE_MODES` | supported white balance modes |
| `CAP_MANUAL_WHITE_BALANCE_SUPPORTED` | whether manual Kelvin/tint is available |
| `CAP_FOCUS_MODES` | supported focus modes |
| `CAP_MIRROR_MODES` | supported mirror modes |

```js
Camera.getCameraCapabilities().then(function (caps) {
  console.log(
    "zoom: " + caps[Camera.CAP_MIN_ZOOM] + " - " + caps[Camera.CAP_MAX_ZOOM],
  );
  console.log("white balance: " + caps[Camera.CAP_WHITE_BALANCE_MODES].join(", "));
  console.log("focus: " + caps[Camera.CAP_FOCUS_MODES].join(", "));
});
```

### Set photo resolution

Use `setPhotoOptions()` with a `PhotoResolution` to pick the resolution for captured photos. The available resolutions are reported in `INFO_PHOTO_RESOLUTIONS` by `getCameraInfo()`.

On Android the resolution is passed to the capture pipeline as a target resolution and the full list of supported sizes is reported. On iOS 16 and newer the closest supported capture resolution is selected; on older iOS versions the option is rejected, since AVFoundation cannot change the capture resolution there. Use `OPTION_PHOTO_QUALITY` (JPEG quality from 1 to 100) to control the encoding quality; it remains Android only.

```js
Camera.getCameraInfo().then(function (info) {
  // The info object contains the available photo resolutions.
  if (Camera.INFO_PHOTO_RESOLUTIONS in info) {
    var supportedResolutions = info[Camera.INFO_PHOTO_RESOLUTIONS];

    // Make a function that picks the resolution you want
    var resolution = pickResolution(supportedResolutions);

    // Put your resolution in an object with the photo resolution key
    var options = {};
    options[Camera.OPTION_PHOTO_RESOLUTION] = resolution;

    Camera.setPhotoOptions(options)
      .then(function () {
        /* success */
      })
      .catch(function (error) {
        console.log("Failed to set photo options: " + error);
      });
  }
});
```
