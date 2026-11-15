package com.fuse.controls.cameraview;

import android.content.Context;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CameraMetadata;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.params.RggbChannelVector;
import android.media.Image;
import android.os.Handler;
import android.os.Looper;
import android.util.Range;
import android.util.Rational;
import android.util.Size;

import androidx.annotation.NonNull;
import androidx.camera.core.Camera;
import androidx.camera.core.CameraFilter;
import androidx.camera.core.CameraInfo;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ExposureState;
import androidx.camera.core.FocusMeteringAction;
import androidx.camera.core.ImageAnalysis;
import androidx.camera.core.ImageCapture;
import androidx.camera.core.ImageCaptureException;
import androidx.camera.core.MeteringPoint;
import androidx.camera.core.MirrorMode;
import androidx.camera.core.Preview;
import androidx.camera.core.TorchState;
import androidx.camera.core.ZoomState;
import androidx.camera.core.UseCase;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.camera.video.FallbackStrategy;
import androidx.camera.video.FileOutputOptions;
import androidx.camera.video.PendingRecording;
import androidx.camera.video.Quality;
import androidx.camera.video.QualitySelector;
import androidx.camera.video.Recorder;
import androidx.camera.video.Recording;
import androidx.camera.video.VideoCapture;
import androidx.camera.view.PreviewView;
import androidx.core.content.ContextCompat;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleOwner;
import androidx.lifecycle.LifecycleRegistry;

import com.google.common.util.concurrent.ListenableFuture;

import androidx.camera.camera2.interop.Camera2CameraControl;
import androidx.camera.camera2.interop.Camera2CameraInfo;
import androidx.camera.camera2.interop.CaptureRequestOptions;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

/**
 * CameraX based camera session.
 *
 * This class owns the CameraX use cases and exposes the small, synchronous
 * API surface used by the Uno layer.
 */
public class CameraXSession implements FrameAnalysis.Host {

    public interface OpenCallback {
        void onOpened(CameraXSession session);
        void onError(String message);
    }

    public interface BoolCallback {
        void onResult(boolean value);
        void onError(String message);
    }

    public interface FloatCallback {
        void onResult(float value);
        void onError(String message);
    }

    public interface ManualExposureCallback {
        void onResult(boolean isManual, float iso, float shutterSeconds);
        void onError(String message);
    }

    public interface BarcodeCallback {
        void onResult(String value, String format);
        void onError(String message);
    }

    public interface StringCallback {
        void onResult(String mode);
        void onError(String message);
    }

    public interface WhiteBalanceSettingsCallback {
        void onResult(boolean isManual, float kelvin, float tint);
        void onError(String message);
    }

    public interface FaceCallback {
        void onFace(int id, float x, float y, float width, float height, float roll, float yaw);
        void onFrame();
    }

    public interface CameraEventCallback {
        void onEvent(String type, String reason, String message);
    }

    public interface StartCallback {
        void onStarted();
        void onError(String message);
    }

    static final class CameraLifecycleOwner implements LifecycleOwner {
        private final LifecycleRegistry _registry;

        CameraLifecycleOwner() {
            _registry = new LifecycleRegistry(this);
            _registry.setCurrentState(Lifecycle.State.STARTED);
        }

        @NonNull
        @Override
        public Lifecycle getLifecycle() {
            return _registry;
        }

        void destroy() {
            _registry.setCurrentState(Lifecycle.State.DESTROYED);
        }
    }

    final Context _context;
    final ProcessCameraProvider _provider;
    final String _cameraId;
    final int _facing;
    final boolean _allowFacingFallback;
    final CameraLifecycleOwner _lifecycleOwner;
    final ExecutorService _cameraExecutor;
    final Handler _mainHandler;
    final CameraCharacteristics _characteristics;

    Preview _preview;
    ImageCapture _imageCapture;
    VideoCapture<Recorder> _videoCapture;
    Recorder _recorder;
    Camera _camera;
    PreviewView _previewView;
    CameraOverlayView _overlayView;

    int _pictureWidth;
    int _pictureHeight;
    int _jpegQuality = 100;
    String _flashMode = "off";
    int _videoHeight;
    boolean _videoBound;
    boolean _disposed;
    RecordingSession _recordingSession;

    boolean _manualExposure;
    float _manualIso;
    float _manualShutterSeconds;
    String _whiteBalanceMode = "auto";
    float _whiteBalanceKelvin;
    float _whiteBalanceTint;
    String _focusMode = "continuous";
    String _mirrorMode = "auto";

    boolean _capturingPhoto;
    boolean _fillPreview;
    CameraEventCallback _cameraEventCallback;

    final FrameAnalysis _frameAnalysis;
    final CameraStateMonitor _stateMonitor;

    CameraXSession(Context context, ProcessCameraProvider provider, String cameraId, int facing, boolean allowFacingFallback, CameraCharacteristics characteristics) {
        _context = context;
        _provider = provider;
        _cameraId = cameraId;
        _facing = facing;
        _allowFacingFallback = allowFacingFallback;
        _lifecycleOwner = new CameraLifecycleOwner();
        _cameraExecutor = Executors.newSingleThreadExecutor();
        _mainHandler = new Handler(Looper.getMainLooper());
        _characteristics = characteristics;

        _frameAnalysis = new FrameAnalysis(this);
        _stateMonitor = new CameraStateMonitor(new CameraStateMonitor.Listener() {
            @Override
            public void onError(String reason, String message) {
                CameraEventCallback callback = _cameraEventCallback;
                if (callback != null)
                    callback.onEvent("error", reason, message);
            }
        });
    }

    public static void open(final Context context, final String cameraId, final int facing, final boolean allowFacingFallback, final OpenCallback callback) {
        final ListenableFuture<ProcessCameraProvider> providerFuture = ProcessCameraProvider.getInstance(context);
        providerFuture.addListener(new Runnable() {
            @Override
            public void run() {
                try {
                    ProcessCameraProvider provider = providerFuture.get();
                    CameraManager manager = (CameraManager)context.getSystemService(Context.CAMERA_SERVICE);
                    CameraCharacteristics characteristics = manager.getCameraCharacteristics(cameraId);
                    CameraXSession session = new CameraXSession(context, provider, cameraId, facing, allowFacingFallback, characteristics);
                    session.bindInitial(callback);
                } catch (Throwable t) {
                    callback.onError(messageOf(t));
                }
            }
        }, ContextCompat.getMainExecutor(context));
    }

    static String messageOf(Throwable t) {
        String message = t.getMessage();
        return message != null ? message : t.toString();
    }

    void bindInitial(OpenCallback callback) {
        try {
            createUseCases();
            if (!bindUseCases(true) && !bindUseCases(false)) {
                callback.onError("Could not bind camera use cases");
                return;
            }
            callback.onOpened(this);
        } catch (Throwable t) {
            callback.onError(messageOf(t));
        }
    }

    void createUseCases() {
        _preview = new Preview.Builder()
                       .setMirrorMode(previewMirrorMode())
                       .build();

        ImageCapture.Builder imageBuilder = new ImageCapture.Builder()
                                                .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
                                                .setJpegQuality(_jpegQuality)
                                                .setMirrorMode(captureMirrorMode());

        if (_pictureWidth > 0 && _pictureHeight > 0)
            imageBuilder.setTargetResolution(new Size(_pictureWidth, _pictureHeight));

        _imageCapture = imageBuilder.build();
        _imageCapture.setFlashMode(flashModeToImageCapture(_flashMode));

        _recorder = new Recorder.Builder()
                        .setExecutor(_cameraExecutor)
                        .setQualitySelector(qualitySelectorForHeight(_videoHeight))
                        .build();
        _videoCapture = new VideoCapture.Builder<>(_recorder)
                            .setMirrorMode(captureMirrorMode())
                            .build();
    }

    public boolean bindUseCases(boolean includeVideo) {
        CameraSelector exact = new CameraSelector.Builder()
                                   .addCameraFilter(new CameraFilter() {
                                       @Override
                                       public List<CameraInfo> filter(List<CameraInfo> cameraInfos) {
                                           List<CameraInfo> result = new ArrayList<>();
                                           for (CameraInfo info : cameraInfos) {
                                               if (_cameraId.equals(Camera2CameraInfo.from(info).getCameraId()))
                                                   result.add(info);
                                           }
                                           return result;
                                       }
                                   })
                                   .build();

        if (bindWithSelector(exact, includeVideo))
            return true;

        if (!_allowFacingFallback)
            return false;

        CameraSelector facing = _facing == 0
                                    ? CameraSelector.DEFAULT_BACK_CAMERA
                                    : CameraSelector.DEFAULT_FRONT_CAMERA;

        return bindWithSelector(facing, includeVideo);
    }

    boolean bindWithSelector(CameraSelector selector, boolean includeVideo) {
        try {
            _provider.unbindAll();

            List<UseCase> useCases = new ArrayList<>();
            useCases.add(_preview);
            useCases.add(_imageCapture);
            if (includeVideo && _videoCapture != null)
                useCases.add(_videoCapture);
            ImageAnalysis analysis = _frameAnalysis.useCase();
            if (analysis != null)
                useCases.add(analysis);

            _camera = _provider.bindToLifecycle(_lifecycleOwner, selector, useCases.toArray(new UseCase[useCases.size()]));

            _videoBound = includeVideo;

            // The camera is recreated on rebind, so the state observer has to
            // follow it.
            if (_cameraEventCallback != null)
                _stateMonitor.attach(_camera);

            if (_previewView != null)
                _preview.setSurfaceProvider(_previewView.getSurfaceProvider());
            return true;
        } catch (Throwable t) {
            _camera = null;
            _videoBound = false;
            return false;
        }
    }

    public void attachPreviewView(PreviewView view) {
        _previewView = view;
        view.setImplementationMode(PreviewView.ImplementationMode.COMPATIBLE);
        view.setScaleType(PreviewView.ScaleType.FIT_CENTER);
        if (_preview != null)
            _preview.setSurfaceProvider(view.getSurfaceProvider());
    }

    public void attachOverlayView(CameraOverlayView view) {
        _overlayView = view;
        view.setFill(_fillPreview);
    }

    public void updateStretchMode(boolean shouldFill) {
        _fillPreview = shouldFill;

        if (_previewView != null)
            _previewView.setScaleType(shouldFill
                                          ? PreviewView.ScaleType.FILL_CENTER
                                          : PreviewView.ScaleType.FIT_CENTER);

        if (_overlayView != null)
            _overlayView.setFill(shouldFill);
    }

    // ---------------------------------------------------------------------
    // Capabilities
    // ---------------------------------------------------------------------

    public int getSupportedPictureSizesCount() {
        Size[] sizes = CameraCapabilitiesReader.pictureSizes(_characteristics);
        return sizes == null ? 0 : sizes.length;
    }

    public int[] getSupportedPictureSizes() {
        return CameraCapabilitiesReader.pictureSizesFlat(_characteristics);
    }

    public boolean isZoomSupported() {
        return CameraCapabilitiesReader.isZoomSupported(_camera, _characteristics);
    }

    public float getMinZoom() {
        return CameraCapabilitiesReader.minZoom(_camera);
    }

    public float getMaxZoom() {
        return CameraCapabilitiesReader.maxZoom(_camera, _characteristics);
    }

    public boolean isTorchSupported() {
        return CameraCapabilitiesReader.isTorchSupported(_camera, _characteristics);
    }

    public float getMinExposureCompensation() {
        return CameraCapabilitiesReader.minExposureCompensation(_camera);
    }

    public float getMaxExposureCompensation() {
        return CameraCapabilitiesReader.maxExposureCompensation(_camera);
    }

    public float getExposureCompensationStep() {
        return CameraCapabilitiesReader.exposureCompensationStep(_camera);
    }

    public float getExposureCompensationNow() {
        return CameraCapabilitiesReader.exposureCompensationNow(_camera);
    }

    public void setExposureCompensation(float value, final FloatCallback callback) {
        if (_camera == null) {
            callback.onError("Camera is not ready");
            return;
        }

        ExposureState exposure = _camera.getCameraInfo().getExposureState();
        if (exposure == null || !exposure.isExposureCompensationSupported()) {
            callback.onError("Exposure compensation is not supported");
            return;
        }

        Range<Integer> range = exposure.getExposureCompensationRange();
        final Rational step = exposure.getExposureCompensationStep();
        if (range == null || step == null || step.floatValue() == 0.0f) {
            callback.onError("Exposure compensation is not supported");
            return;
        }

        int index = Math.round(value / step.floatValue());
        int clamped = Math.max(range.getLower(), Math.min(range.getUpper(), index));

        final ListenableFuture<Integer> future = _camera.getCameraControl().setExposureCompensationIndex(clamped);
        future.addListener(new Runnable() {
            @Override
            public void run() {
                try {
                    Integer appliedIndex = future.get();
                    callback.onResult(appliedIndex == null ? 0.0f : appliedIndex * step.floatValue());
                } catch (Throwable t) {
                    callback.onError(messageOf(t));
                }
            }
        }, ContextCompat.getMainExecutor(_context));
    }

    public boolean isManualExposureSupported() {
        return CameraCapabilitiesReader.isManualExposureSupported(_characteristics);
    }

    public float getMinIso() {
        return CameraCapabilitiesReader.minIso(_characteristics);
    }

    public float getMaxIso() {
        return CameraCapabilitiesReader.maxIso(_characteristics);
    }

    public float getMinShutterSeconds() {
        return CameraCapabilitiesReader.minShutterSeconds(_characteristics);
    }

    public float getMaxShutterSeconds() {
        return CameraCapabilitiesReader.maxShutterSeconds(_characteristics);
    }

    public boolean isManualExposureNow() {
        return _manualExposure;
    }

    public float getManualIsoNow() {
        return _manualIso;
    }

    public float getManualShutterSecondsNow() {
        return _manualShutterSeconds;
    }

    public void setManualExposure(float iso, float shutterSeconds, final ManualExposureCallback callback) {
        if (_camera == null) {
            callback.onError("Camera is not ready");
            return;
        }
        if (!isManualExposureSupported()) {
            callback.onError("Manual exposure is not supported");
            return;
        }

        Range<Integer> isoRange = CameraCapabilitiesReader.isoRange(_characteristics);
        Range<Long> exposureRange = CameraCapabilitiesReader.exposureTimeRange(_characteristics);
        float clampedIso = Math.max(isoRange.getLower(), Math.min(isoRange.getUpper(), iso));
        long nanos = (long)(Math.max(0.0, shutterSeconds) * 1000000000.0);
        nanos = Math.max(exposureRange.getLower(), Math.min(exposureRange.getUpper(), nanos));

        final float appliedIso = clampedIso;
        final float appliedShutter = nanos / 1000000000.0f;

        final boolean previousManual = _manualExposure;
        final float previousIso = _manualIso;
        final float previousShutter = _manualShutterSeconds;

        _manualExposure = true;
        _manualIso = appliedIso;
        _manualShutterSeconds = appliedShutter;

        final ListenableFuture<Void> future = applyCaptureRequestOptions();
        future.addListener(new Runnable() {
            @Override
            public void run() {
                try {
                    future.get();
                    callback.onResult(true, appliedIso, appliedShutter);
                } catch (Throwable t) {
                    _manualExposure = previousManual;
                    _manualIso = previousIso;
                    _manualShutterSeconds = previousShutter;
                    callback.onError(messageOf(t));
                }
            }
        }, ContextCompat.getMainExecutor(_context));
    }

    public void setAutoExposure(final ManualExposureCallback callback) {
        if (_camera == null) {
            callback.onError("Camera is not ready");
            return;
        }

        final boolean previousManual = _manualExposure;
        final float previousIso = _manualIso;
        final float previousShutter = _manualShutterSeconds;

        _manualExposure = false;
        _manualIso = 0.0f;
        _manualShutterSeconds = 0.0f;

        final ListenableFuture<Void> future = applyCaptureRequestOptions();
        future.addListener(new Runnable() {
            @Override
            public void run() {
                try {
                    future.get();
                    callback.onResult(false, 0.0f, 0.0f);
                } catch (Throwable t) {
                    _manualExposure = previousManual;
                    _manualIso = previousIso;
                    _manualShutterSeconds = previousShutter;
                    callback.onError(messageOf(t));
                }
            }
        }, ContextCompat.getMainExecutor(_context));
    }

    // ---------------------------------------------------------------------
    // White balance
    // ---------------------------------------------------------------------

    static final String[] WhiteBalanceNames = {
        "auto", "incandescent", "fluorescent", "warm-fluorescent",
        "daylight", "cloudy", "twilight", "shade"};

    public String getWhiteBalanceNow() {
        return _whiteBalanceMode;
    }

    public String getSupportedWhiteBalanceModes() {
        int[] modes = _characteristics.get(CameraCharacteristics.CONTROL_AWB_AVAILABLE_MODES);
        if (modes == null)
            return "auto";

        StringBuilder builder = new StringBuilder();
        for (String name : WhiteBalanceNames) {
            if (!containsMode(modes, awbModeOf(name)))
                continue;
            if (builder.length() > 0)
                builder.append(',');
            builder.append(name);
        }

        return builder.length() == 0 ? "auto" : builder.toString();
    }

    public void setWhiteBalance(String mode, final StringCallback callback) {
        if (_camera == null) {
            callback.onError("Camera is not ready");
            return;
        }

        String normalized = normalizeWhiteBalance(mode);
        if (normalized == null) {
            callback.onError("Unknown white balance mode: " + mode);
            return;
        }

        int[] available = _characteristics.get(CameraCharacteristics.CONTROL_AWB_AVAILABLE_MODES);
        if (available != null && !containsMode(available, awbModeOf(normalized))) {
            callback.onError("White balance mode not supported: " + normalized);
            return;
        }

        final String applied = normalized;
        final String previous = _whiteBalanceMode;
        _whiteBalanceMode = applied;

        final ListenableFuture<Void> future = applyCaptureRequestOptions();
        future.addListener(new Runnable() {
            @Override
            public void run() {
                try {
                    future.get();
                    _whiteBalanceKelvin = 0.0f;
                    _whiteBalanceTint = 0.0f;
                    callback.onResult(applied);
                } catch (Throwable t) {
                    _whiteBalanceMode = previous;
                    callback.onError(messageOf(t));
                }
            }
        }, ContextCompat.getMainExecutor(_context));
    }

    static final float MinKelvin = 1000.0f;
    static final float MaxKelvin = 15000.0f;
    static final float MaxTint = 150.0f;

    public boolean isManualWhiteBalanceSupported() {
        int[] modes = _characteristics.get(CameraCharacteristics.CONTROL_AWB_AVAILABLE_MODES);
        return modes != null && containsMode(modes, CameraMetadata.CONTROL_AWB_MODE_OFF);
    }

    public boolean isManualWhiteBalanceNow() {
        return "manual".equals(_whiteBalanceMode);
    }

    public float getWhiteBalanceKelvinNow() {
        return _whiteBalanceKelvin;
    }

    public float getWhiteBalanceTintNow() {
        return _whiteBalanceTint;
    }

    public void setWhiteBalanceTemperature(float kelvin, float tint, final WhiteBalanceSettingsCallback callback) {
        if (_camera == null) {
            callback.onError("Camera is not ready");
            return;
        }

        if (!isManualWhiteBalanceSupported()) {
            callback.onError("Manual white balance is not supported");
            return;
        }

        final float appliedKelvin = Math.max(MinKelvin, Math.min(MaxKelvin, kelvin));
        final float appliedTint = Math.max(-MaxTint, Math.min(MaxTint, tint));

        final String previousMode = _whiteBalanceMode;
        final float previousKelvin = _whiteBalanceKelvin;
        final float previousTint = _whiteBalanceTint;

        _whiteBalanceMode = "manual";
        _whiteBalanceKelvin = appliedKelvin;
        _whiteBalanceTint = appliedTint;

        final ListenableFuture<Void> future = applyCaptureRequestOptions();
        future.addListener(new Runnable() {
            @Override
            public void run() {
                try {
                    future.get();
                    callback.onResult(true, appliedKelvin, appliedTint);
                } catch (Throwable t) {
                    _whiteBalanceMode = previousMode;
                    _whiteBalanceKelvin = previousKelvin;
                    _whiteBalanceTint = previousTint;
                    callback.onError(messageOf(t));
                }
            }
        }, ContextCompat.getMainExecutor(_context));
    }

    // The correction gains are the inverse of the illuminant color, normalized
    // so that green is 1.0. Positive tint shifts the image towards magenta,
    // negative tint towards green (matching the iOS convention).
    static RggbChannelVector whiteBalanceGains(float kelvin, float tint) {
        double temperature = Math.max(MinKelvin, Math.min(MaxKelvin, kelvin));
        double t = temperature / 100.0;

        double red, green, blue;
        if (t <= 66.0) {
            red = 255.0;
            green = 99.4708025861 * Math.log(t) - 161.1195681661;
            blue = t <= 19.0 ? 0.0 : 138.5177312231 * Math.log(t - 10.0) - 305.0447927307;
        } else {
            red = 329.698727446 * Math.pow(t - 60.0, -0.1332047592);
            green = 288.1221695283 * Math.pow(t - 60.0, -0.0755148492);
            blue = 255.0;
        }

        red = Math.max(1.0, Math.min(255.0, red));
        green = Math.max(1.0, Math.min(255.0, green));
        blue = Math.max(1.0, Math.min(255.0, blue));

        float r = (float)(green / red);
        float g = 1.0f;
        float b = (float)(green / blue);

        float tintFactor = Math.max(-1.0f, Math.min(1.0f, tint / MaxTint));
        if (tintFactor > 0.0f) {
            r *= 1.0f + tintFactor;
            b *= 1.0f + tintFactor;
        } else if (tintFactor < 0.0f) {
            g *= 1.0f - tintFactor;
        }

        return new RggbChannelVector(r, g, g, b);
    }

    static String normalizeWhiteBalance(String mode) {
        if (mode == null)
            return null;

        String name = mode.trim().toLowerCase(java.util.Locale.US);
        if ("warmfluorescent".equals(name))
            name = "warm-fluorescent";

        for (String supported : WhiteBalanceNames)
            if (supported.equals(name))
                return name;

        return null;
    }

    static int awbModeOf(String mode) {
        if ("incandescent".equals(mode))
            return CameraMetadata.CONTROL_AWB_MODE_INCANDESCENT;
        if ("fluorescent".equals(mode))
            return CameraMetadata.CONTROL_AWB_MODE_FLUORESCENT;
        if ("warm-fluorescent".equals(mode))
            return CameraMetadata.CONTROL_AWB_MODE_WARM_FLUORESCENT;
        if ("daylight".equals(mode))
            return CameraMetadata.CONTROL_AWB_MODE_DAYLIGHT;
        if ("cloudy".equals(mode))
            return CameraMetadata.CONTROL_AWB_MODE_CLOUDY_DAYLIGHT;
        if ("twilight".equals(mode))
            return CameraMetadata.CONTROL_AWB_MODE_TWILIGHT;
        if ("shade".equals(mode))
            return CameraMetadata.CONTROL_AWB_MODE_SHADE;
        return CameraMetadata.CONTROL_AWB_MODE_AUTO;
    }

    static boolean containsMode(int[] modes, int mode) {
        for (int value : modes)
            if (value == mode)
                return true;
        return false;
    }

    // ---------------------------------------------------------------------
    // Mirroring
    // ---------------------------------------------------------------------

    public String getMirrorModeNow() {
        return _mirrorMode;
    }

    int previewMirrorMode() {
        if ("on".equals(_mirrorMode))
            return MirrorMode.MIRROR_MODE_ON;
        if ("off".equals(_mirrorMode))
            return MirrorMode.MIRROR_MODE_OFF;
        return MirrorMode.MIRROR_MODE_ON_FRONT_ONLY;
    }

    int captureMirrorMode() {
        return "on".equals(_mirrorMode) ? MirrorMode.MIRROR_MODE_ON : MirrorMode.MIRROR_MODE_OFF;
    }

    public void setMirrorMode(String mode, final StringCallback callback) {
        if (_camera == null) {
            callback.onError("Camera is not ready");
            return;
        }

        if (!"auto".equals(mode) && !"on".equals(mode) && !"off".equals(mode)) {
            callback.onError("Unknown mirror mode: " + mode);
            return;
        }

        if (_recordingSession != null) {
            callback.onError("Cannot change mirror mode while recording video");
            return;
        }

        if (_capturingPhoto) {
            callback.onError("Cannot change mirror mode while capturing a photo");
            return;
        }

        if (mode.equals(_mirrorMode)) {
            callback.onResult(mode);
            return;
        }

        final String previous = _mirrorMode;
        _mirrorMode = mode;

        // Mirroring is a property of the use cases, so they have to be rebuilt.
        createUseCases();
        boolean bound = bindUseCases(_videoBound);
        if (!bound && _videoBound)
            bound = bindUseCases(false);

        if (!bound) {
            _mirrorMode = previous;
            createUseCases();
            if (!bindUseCases(_videoBound))
                bindUseCases(false);
            callback.onError("Could not change mirror mode");
            return;
        }

        if (_previewView != null)
            _preview.setSurfaceProvider(_previewView.getSurfaceProvider());

        callback.onResult(mode);
    }

    // ---------------------------------------------------------------------
    // Focus
    // ---------------------------------------------------------------------

    public String getFocusModeNow() {
        return _focusMode;
    }

    public String getSupportedFocusModes() {
        int[] modes = _characteristics.get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES);
        if (modes == null)
            return "continuous";

        StringBuilder builder = new StringBuilder();
        if (containsMode(modes, CameraMetadata.CONTROL_AF_MODE_AUTO))
            appendMode(builder, "auto");
        if (containsMode(modes, CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_PICTURE) ||
            containsMode(modes, CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_VIDEO))
            appendMode(builder, "continuous");
        if (containsMode(modes, CameraMetadata.CONTROL_AF_MODE_OFF))
            appendMode(builder, "locked");

        return builder.length() == 0 ? "continuous" : builder.toString();
    }

    public boolean isFocusModeSupported(String mode) {
        for (String supported : getSupportedFocusModes().split(","))
            if (supported.equals(mode))
                return true;
        return false;
    }

    public void setFocusMode(String mode, final StringCallback callback) {
        if (_camera == null) {
            callback.onError("Camera is not ready");
            return;
        }

        if (!isFocusModeSupported(mode)) {
            callback.onError("Focus mode not supported: " + mode);
            return;
        }

        final String previous = _focusMode;
        _focusMode = mode;

        final ListenableFuture<Void> future = applyCaptureRequestOptions();
        future.addListener(new Runnable() {
            @Override
            public void run() {
                try {
                    future.get();
                    callback.onResult(mode);
                } catch (Throwable t) {
                    _focusMode = previous;
                    callback.onError(messageOf(t));
                }
            }
        }, ContextCompat.getMainExecutor(_context));
    }

    int afModeFor(String mode) {
        if ("auto".equals(mode))
            return CameraMetadata.CONTROL_AF_MODE_AUTO;
        if ("locked".equals(mode))
            return CameraMetadata.CONTROL_AF_MODE_OFF;

        int[] available = _characteristics.get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES);
        if (available != null && containsMode(available, CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_PICTURE))
            return CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_PICTURE;
        if (available != null && containsMode(available, CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_VIDEO))
            return CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_VIDEO;
        return CameraMetadata.CONTROL_AF_MODE_AUTO;
    }

    static void appendMode(StringBuilder builder, String mode) {
        if (builder.length() > 0)
            builder.append(',');
        builder.append(mode);
    }

    // Manual exposure and white balance share the same Camera2 capture request
    // options, so they are always applied together. Calling
    // setCaptureRequestOptions() replaces the previous options.
    CaptureRequestOptions captureRequestOptions() {
        CaptureRequestOptions.Builder builder = new CaptureRequestOptions.Builder();

        if (_manualExposure) {
            builder.setCaptureRequestOption(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_OFF)
                .setCaptureRequestOption(CaptureRequest.SENSOR_SENSITIVITY, (int)_manualIso)
                .setCaptureRequestOption(CaptureRequest.SENSOR_EXPOSURE_TIME, (long)(_manualShutterSeconds * 1000000000.0));
        } else {
            builder.setCaptureRequestOption(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_ON);
        }

        if ("manual".equals(_whiteBalanceMode)) {
            builder.setCaptureRequestOption(CaptureRequest.CONTROL_AWB_MODE, CameraMetadata.CONTROL_AWB_MODE_OFF)
                .setCaptureRequestOption(CaptureRequest.CONTROL_AWB_LOCK, true)
                .setCaptureRequestOption(CaptureRequest.COLOR_CORRECTION_MODE, CameraMetadata.COLOR_CORRECTION_MODE_TRANSFORM_MATRIX)
                .setCaptureRequestOption(CaptureRequest.COLOR_CORRECTION_GAINS, whiteBalanceGains(_whiteBalanceKelvin, _whiteBalanceTint));
        } else {
            builder.setCaptureRequestOption(CaptureRequest.CONTROL_AWB_MODE, awbModeOf(_whiteBalanceMode));
        }

        builder.setCaptureRequestOption(CaptureRequest.CONTROL_AF_MODE, afModeFor(_focusMode));

        return builder.build();
    }

    ListenableFuture<Void> applyCaptureRequestOptions() {
        Camera2CameraControl control = Camera2CameraControl.from(_camera.getCameraControl());
        return control.setCaptureRequestOptions(captureRequestOptions());
    }

    public boolean isFlashModeSupported(String mode) {
        if ("off".equals(mode))
            return true;
        return isTorchSupported();
    }

    // ---------------------------------------------------------------------
    // Zoom / torch / flash / focus
    // ---------------------------------------------------------------------

    public float getZoomNow() {
        if (_camera == null)
            return 1.0f;

        ZoomState state = _camera.getCameraInfo().getZoomState().getValue();
        return state == null ? 1.0f : state.getZoomRatio();
    }

    public void setZoom(float zoom, final FloatCallback callback) {
        if (_camera == null) {
            callback.onError("Camera is not ready");
            return;
        }

        ZoomState state = _camera.getCameraInfo().getZoomState().getValue();
        float min = state == null ? 1.0f : state.getMinZoomRatio();
        float max = state == null ? 1.0f : state.getMaxZoomRatio();
        final float applied = Math.max(min, Math.min(max, zoom));

        ListenableFuture<Void> future = _camera.getCameraControl().setZoomRatio(applied);
        future.addListener(new Runnable() {
            @Override
            public void run() {
                try {
                    future.get();
                    callback.onResult(applied);
                } catch (Throwable t) {
                    callback.onError(messageOf(t));
                }
            }
        }, ContextCompat.getMainExecutor(_context));
    }

    public boolean isTorchOnNow() {
        if (_camera == null)
            return false;

        Integer state = _camera.getCameraInfo().getTorchState().getValue();
        return state != null && state == TorchState.ON;
    }

    public void setTorchMode(final boolean on, final BoolCallback callback) {
        if (_camera == null) {
            callback.onError("Camera is not ready");
            return;
        }

        if (on && !isTorchSupported()) {
            callback.onError("Torch is not supported");
            return;
        }

        ListenableFuture<Void> future = _camera.getCameraControl().enableTorch(on);
        future.addListener(new Runnable() {
            @Override
            public void run() {
                try {
                    future.get();
                    callback.onResult(on);
                } catch (Throwable t) {
                    callback.onError(messageOf(t));
                }
            }
        }, ContextCompat.getMainExecutor(_context));
    }

    public void setFlashMode(String mode) {
        _flashMode = mode;
        if (_imageCapture != null)
            _imageCapture.setFlashMode(flashModeToImageCapture(mode));
    }

    static int flashModeToImageCapture(String mode) {
        if ("auto".equals(mode))
            return ImageCapture.FLASH_MODE_AUTO;
        if ("on".equals(mode))
            return ImageCapture.FLASH_MODE_ON;
        return ImageCapture.FLASH_MODE_OFF;
    }

    public void setFocusPoint(float x, float y, boolean lock) {
        if (_camera == null || _previewView == null)
            return;

        MeteringPoint point = _previewView.getMeteringPointFactory().createPoint(x, y);
        FocusMeteringAction.Builder builder = new FocusMeteringAction.Builder(
            point, FocusMeteringAction.FLAG_AF | FocusMeteringAction.FLAG_AE);

        if (lock)
            builder.setAutoCancelDuration(1, TimeUnit.HOURS);

        _camera.getCameraControl().startFocusAndMetering(builder.build());
    }

    // ---------------------------------------------------------------------
    // Barcode scanning and face detection
    // ---------------------------------------------------------------------

    public void scanBarcode(BarcodeCallback callback) {
        scanBarcode(null, callback);
    }

    public void scanBarcode(String[] formats, BarcodeCallback callback) {
        if (callback == null)
            return;

        String unusable = checkCameraUsable("scan a barcode");
        if (unusable != null) {
            callback.onError(unusable);
            return;
        }

        String error = _frameAnalysis.startBarcode(false, formats, callback);
        if (error != null)
            callback.onError(error);
    }

    public void startBarcodeScanning(String[] formats, BarcodeCallback onDetected, StartCallback onStart) {
        if (onDetected == null || onStart == null)
            return;

        String unusable = checkCameraUsable("scan a barcode");
        if (unusable != null) {
            onStart.onError(unusable);
            return;
        }

        String error = _frameAnalysis.startBarcode(true, formats, onDetected);
        if (error != null)
            onStart.onError(error);
        else
            onStart.onStarted();
    }

    public void stopBarcodeScanning(BoolCallback callback) {
        boolean wasScanning = _frameAnalysis.stopBarcode();

        if (callback != null)
            callback.onResult(wasScanning);
    }

    public void startFaceDetection(FaceCallback onFaces, StartCallback onStart) {
        if (onFaces == null || onStart == null)
            return;

        String unusable = checkCameraUsable("detect faces");
        if (unusable != null) {
            onStart.onError(unusable);
            return;
        }

        String error = _frameAnalysis.startFaces(onFaces);
        if (error != null)
            onStart.onError(error);
        else
            onStart.onStarted();
    }

    public void stopFaceDetection(BoolCallback callback) {
        boolean wasDetecting = _frameAnalysis.stopFaces();

        if (callback != null)
            callback.onResult(wasDetecting);
    }

    // ---------------------------------------------------------------------
    // Frame analysis
    // ---------------------------------------------------------------------

    public interface StatisticsCallback {
        void onStatistics(double timestamp, double mean, double p1, double p50, double p99,
                          double clippedLow, double clippedHigh, double analysisTime);
    }

    public interface StatisticsStartCallback {
        void onStarted(Object statistics);
        void onError(String message);
    }

    public void startFrameAnalysis(int maxFps, int resolutionWidth, int resolutionHeight,
                                   int lumaWidth, int lumaHeight,
                                   StatisticsCallback onStatistics, StatisticsStartCallback onStart) {
        if (onStatistics == null || onStart == null)
            return;

        String unusable = checkCameraUsable("analyse frames");
        if (unusable != null) {
            onStart.onError(unusable);
            return;
        }

        final StatisticsCallback callback = onStatistics;
        String error = _frameAnalysis.startStatistics(
            maxFps, resolutionWidth, resolutionHeight, lumaWidth, lumaHeight,
            new StatisticsConsumer.Callback() {
                @Override
                public void onStatistics(double timestamp, double mean, double p1, double p50, double p99,
                                         double clippedLow, double clippedHigh, double analysisTime) {
                    callback.onStatistics(timestamp, mean, p1, p50, p99, clippedLow, clippedHigh, analysisTime);
                }
            });

        if (error != null)
            onStart.onError(error);
        else
            onStart.onStarted(_frameAnalysis.statistics());
    }

    public void stopFrameAnalysis(BoolCallback callback) {
        boolean wasAnalysing = _frameAnalysis.stopStatistics();

        if (callback != null)
            callback.onResult(wasAnalysing);
    }

    public interface OverlayOptionsCallback {
        void onResult(double zebra, double peaking);
        void onError(String message);
    }

    public void setOverlayOptions(double zebra, double peaking, OverlayOptionsCallback callback) {
        if (callback == null)
            return;

        String unusable = checkCameraUsable("draw the analysis overlay");
        if (unusable != null) {
            callback.onError(unusable);
            return;
        }

        String error = _frameAnalysis.setOverlay(_overlayView, zebra, peaking);
        if (error != null)
            callback.onError(error);
        else
            callback.onResult(zebra, peaking);
    }

    // The statistics object is opaque to the Uno layer, so these helpers keep
    // the consumer itself package private.
    public static byte[] takeStatisticsHistogram(Object statistics) {
        return statistics == null ? null : ((StatisticsConsumer)statistics).takeHistogram();
    }

    public static byte[] takeStatisticsLuma(Object statistics) {
        return statistics == null ? null : ((StatisticsConsumer)statistics).takeLuma();
    }

    public static int statisticsLumaWidth(Object statistics) {
        return statistics == null ? 0 : ((StatisticsConsumer)statistics).lumaWidth();
    }

    public static int statisticsLumaHeight(Object statistics) {
        return statistics == null ? 0 : ((StatisticsConsumer)statistics).lumaHeight();
    }

    // Returns an error message when frame analysis cannot start, otherwise null.
    String checkCameraUsable(String action) {
        if (_disposed)
            return "Camera has been disposed";

        if (_camera == null)
            return "Camera is not ready";

        if (_recordingSession != null)
            return "Cannot " + action + " while recording video";

        if (_capturingPhoto)
            return "Cannot " + action + " while capturing a photo";

        return null;
    }

    // ---------------------------------------------------------------------
    // Camera state monitoring
    // ---------------------------------------------------------------------

    public void startErrorMonitoring(CameraEventCallback callback, StartCallback onStart) {
        if (callback == null || onStart == null)
            return;

        if (_disposed) {
            onStart.onError("Camera has been disposed");
            return;
        }

        if (_cameraEventCallback != null) {
            onStart.onError("Error monitoring is already active");
            return;
        }

        _cameraEventCallback = callback;
        _stateMonitor.attach(_camera);
        onStart.onStarted();
    }

    public void stopErrorMonitoring(BoolCallback callback) {
        boolean wasMonitoring = _cameraEventCallback != null;
        _cameraEventCallback = null;
        _stateMonitor.detach();

        if (callback != null)
            callback.onResult(wasMonitoring);
    }

    // ---------------------------------------------------------------------
    // Photo options and capture
    // ---------------------------------------------------------------------

    public void setPictureSize(int width, int height) {
        if (width <= 0 || height <= 0)
            return;

        _pictureWidth = width;
        _pictureHeight = height;
        rebuildImageCapture();
    }

    public void setJpegQuality(int quality) {
        _jpegQuality = Math.max(1, Math.min(100, quality));
        rebuildImageCapture();
    }

    void rebuildImageCapture() {
        if (_disposed)
            return;

        createUseCases();
        if (!bindUseCases(_videoBound) && !bindUseCases(false)) {
            if (_previewView != null)
                _preview.setSurfaceProvider(_previewView.getSurfaceProvider());
            return;
        }
        if (_previewView != null)
            _preview.setSurfaceProvider(_previewView.getSurfaceProvider());
    }

    public void takePicture(final IPictureCallback callback) {
        if (_imageCapture == null) {
            callback.onError(new Exception("Camera is not ready"));
            return;
        }

        final ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
        ImageCapture.OutputFileOptions options =
            new ImageCapture.OutputFileOptions.Builder(outputStream).build();

        _capturingPhoto = true;
        try {
            _imageCapture.takePicture(options, _cameraExecutor, new ImageCapture.OnImageSavedCallback() {
                @Override
                public void onImageSaved(ImageCapture.OutputFileResults results) {
                    _capturingPhoto = false;
                    callback.onPictureTaken(outputStream.toByteArray());
                }

                @Override
                public void onError(ImageCaptureException exception) {
                    _capturingPhoto = false;
                    callback.onError(exception);
                }
            });
        } catch (Throwable t) {
            _capturingPhoto = false;
            callback.onError(new Exception(messageOf(t)));
        }
    }

    // ---------------------------------------------------------------------
    // Video recording
    // ---------------------------------------------------------------------

    public void startRecording(
        final IStartRecordingSession callback,
        int width,
        int height,
        int frameRate,
        int bitRate,
        boolean audioEnabled,
        boolean stabilizationEnabled) {
        if (_disposed) {
            callback.onException("Camera has been disposed");
            return;
        }

        if (_recordingSession != null) {
            callback.onException("A recording is already in progress");
            return;
        }

        _videoHeight = height;

        Recorder.Builder recorderBuilder = new Recorder.Builder()
                                               .setExecutor(_cameraExecutor)
                                               .setQualitySelector(qualitySelectorForHeight(height));
        if (bitRate > 0)
            recorderBuilder.setTargetVideoEncodingBitRate(bitRate);
        _recorder = recorderBuilder.build();

        VideoCapture.Builder<Recorder> videoBuilder = new VideoCapture.Builder<>(_recorder)
                                                          .setMirrorMode(captureMirrorMode());
        if (frameRate > 0)
            videoBuilder.setTargetFrameRate(new Range<Integer>(frameRate, frameRate));
        _videoCapture = videoBuilder.build();

        if (!bindUseCases(true)) {
            bindUseCases(false);
            if (_previewView != null)
                _preview.setSurfaceProvider(_previewView.getSurfaceProvider());
            callback.onException("Video recording is not supported with this camera configuration");
            return;
        }

        if (_previewView != null)
            _preview.setSurfaceProvider(_previewView.getSurfaceProvider());

        try {
            String outputPath = CameraStorage.createVideoFilePath();
            File outputFile = new File(outputPath);
            FileOutputOptions options = new FileOutputOptions.Builder(outputFile).build();

            PendingRecording pending = _recorder.prepareRecording(_context, options);
            if (audioEnabled)
                pending = pending.withAudioEnabled();

            RecordingSession session = new RecordingSession(outputPath);
            Recording recording = pending.start(_cameraExecutor, session);
            session.setRecording(recording);

            _recordingSession = session;
            callback.onSuccess(session);
        } catch (Throwable t) {
            callback.onException(messageOf(t));
        }
    }

    static QualitySelector qualitySelectorForHeight(int height) {
        Quality quality;
        if (height <= 0)
            quality = Quality.HD;
        else if (height <= 480)
            quality = Quality.SD;
        else if (height <= 720)
            quality = Quality.HD;
        else if (height <= 1080)
            quality = Quality.FHD;
        else
            quality = Quality.UHD;

        return QualitySelector.from(quality, FallbackStrategy.lowerQualityOrHigherThan(quality));
    }

    void onRecordingFinalized(RecordingSession session) {
        if (_recordingSession == session)
            _recordingSession = null;
    }

    public void dispose() {
        if (_disposed)
            return;
        _disposed = true;

        _cameraEventCallback = null;
        _stateMonitor.detach();
        _frameAnalysis.dispose();

        if (_recordingSession != null) {
            _recordingSession.close();
            _recordingSession = null;
        }

        Runnable cleanup = new Runnable() {
            @Override
            public void run() {
                try {
                    _provider.unbindAll();
                } catch (Throwable ignored) {
                }
                _lifecycleOwner.destroy();
                _cameraExecutor.shutdown();
            }
        };

        if (Looper.myLooper() == Looper.getMainLooper())
            cleanup.run();
        else
            _mainHandler.post(cleanup);
    }

    // ---------------------------------------------------------------------
    // FrameAnalysis.Host
    // ---------------------------------------------------------------------

    @Override
    public boolean isDisposed() {
        return _disposed;
    }

    @Override
    public boolean isCapturingPhoto() {
        return _capturingPhoto;
    }

    @Override
    public boolean isRecordingVideo() {
        return _recordingSession != null;
    }

    @Override
    public boolean isFrontCamera() {
        return _facing == 1;
    }

    @Override
    public boolean isPreviewMirrored() {
        return !"off".equals(_mirrorMode);
    }

    @Override
    public ExecutorService cameraExecutor() {
        return _cameraExecutor;
    }

    @Override
    public Handler mainHandler() {
        return _mainHandler;
    }

    @Override
    public boolean isVideoBound() {
        return _videoBound;
    }

    @Override
    public boolean isCameraUnbound() {
        return _camera == null;
    }

    @Override
    public void unbindUseCase(ImageAnalysis useCase) {
        try {
            _provider.unbind(useCase);
        } catch (Throwable ignored) {
        }
    }

    @Override
    public void restorePreviewSurface() {
        if (_previewView != null && _preview != null)
            _preview.setSurfaceProvider(_previewView.getSurfaceProvider());
    }
}
