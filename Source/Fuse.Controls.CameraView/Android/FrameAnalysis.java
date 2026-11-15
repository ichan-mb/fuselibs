package com.fuse.controls.cameraview;

import android.os.Handler;

import androidx.camera.core.ImageAnalysis;

import java.util.concurrent.ExecutorService;

/**
 * Barcode scanning and face detection.
 *
 * Both features are consumers of one shared {@link FramePipeline}, which owns
 * the ImageAnalysis use case, the frame geometry and the frame lifetime. This
 * class only exposes the operations the camera session calls.
 */
final class FrameAnalysis {

    interface Host {
        boolean isDisposed();

        boolean isCapturingPhoto();

        boolean isRecordingVideo();

        boolean isFrontCamera();

        boolean isPreviewMirrored();

        ExecutorService cameraExecutor();

        Handler mainHandler();

        boolean bindUseCases(boolean includeVideo);

        void unbindUseCase(ImageAnalysis useCase);

        boolean isVideoBound();

        boolean isCameraUnbound();

        void restorePreviewSurface();
    }

    private final FrameAnalysis.Host _host;
    private final FramePipeline _pipeline;
    private final BarcodeConsumer _barcode;
    private final FaceConsumer _faces;

    private StatisticsConsumer _statistics;
    private OverlayConsumer _overlay;

    FrameAnalysis(Host host) {
        _host = host;
        _pipeline = new FramePipeline(host);
        _barcode = new BarcodeConsumer(host, _pipeline);
        _faces = new FaceConsumer(host, _pipeline);
    }

    ImageAnalysis useCase() {
        return _pipeline.useCase();
    }

    String startBarcode(boolean continuous, String[] formats, CameraXSession.BarcodeCallback callback) {
        return _barcode.start(continuous, formats, callback);
    }

    boolean stopBarcode() {
        return _barcode.stop();
    }

    String startFaces(CameraXSession.FaceCallback callback) {
        return _faces.start(callback);
    }

    boolean stopFaces() {
        return _faces.stop();
    }

    String startStatistics(int maxFps, int resolutionWidth, int resolutionHeight,
                           int lumaWidth, int lumaHeight, StatisticsConsumer.Callback callback) {
        if (_statistics != null)
            return "Frame analysis is already running";

        StatisticsConsumer statistics = new StatisticsConsumer(
            _host, _pipeline, maxFps, lumaWidth, lumaHeight, callback);

        String error = statistics.start(resolutionWidth, resolutionHeight);
        if (error != null)
            return error;

        _statistics = statistics;
        return null;
    }

    boolean stopStatistics() {
        StatisticsConsumer statistics = _statistics;
        if (statistics == null)
            return false;

        _statistics = null;
        return statistics.stop();
    }

    StatisticsConsumer statistics() {
        return _statistics;
    }

    /**
     * Applies the analysis overlay. A value of zero disables that part, and when
     * both are zero the overlay is removed.
     */
    String setOverlay(CameraOverlayView view, double zebra, double peaking) {
        if (zebra <= 0 && peaking <= 0) {
            stopOverlay();
            return null;
        }

        if (view == null)
            return "The camera view does not support an overlay";

        if (_overlay == null)
            _overlay = new OverlayConsumer(_host, _pipeline, view);

        _overlay.configure(zebra, peaking);
        return _overlay.start();
    }

    boolean stopOverlay() {
        OverlayConsumer overlay = _overlay;
        if (overlay == null)
            return false;

        _overlay = null;
        overlay.stop();
        return true;
    }

    void dispose() {
        // The pipeline goes first so the consumers cannot touch the camera
        // binding while the session is being torn down.
        _pipeline.dispose();

        StatisticsConsumer statistics = _statistics;
        _statistics = null;
        if (statistics != null)
            statistics.dispose();

        OverlayConsumer overlay = _overlay;
        _overlay = null;
        if (overlay != null)
            overlay.stop();

        _barcode.dispose();
        _faces.dispose();
    }
}
