package com.fuse.controls.cameraview;

import androidx.annotation.NonNull;
import androidx.camera.core.ImageProxy;

import com.google.mlkit.vision.common.InputImage;

import java.util.concurrent.atomic.AtomicInteger;

/**
 * One analysed frame, shared by all consumers of a pipeline.
 *
 * The underlying ImageProxy stays open while the reference count is above zero.
 * Consumers that keep the frame after their callback returns, for example while
 * an asynchronous detector runs, must {@link #retain()} it first and
 * {@link #release()} it when they are done. The pipeline releases its own
 * reference once every consumer has been called.
 */
final class FrameLease {

    private final ImageProxy _proxy;
    private final FrameGeometry _geometry;
    private final AtomicInteger _references = new AtomicInteger(1);

    private InputImage _inputImage;
    private boolean _inputImageFailed;

    FrameLease(@NonNull ImageProxy proxy, @NonNull FrameGeometry geometry) {
        _proxy = proxy;
        _geometry = geometry;
    }

    ImageProxy proxy() {
        return _proxy;
    }

    FrameGeometry geometry() {
        return _geometry;
    }

    /**
     * The frame as an ML Kit input, or null when the frame cannot be converted.
     * The value is created once and shared, so consumers should not close it.
     */
    synchronized InputImage inputImage() {
        if (_inputImage == null && !_inputImageFailed) {
            try {
                _inputImage = InputImage.fromMediaImage(_proxy.getImage(), _geometry.rotationDegrees);
            } catch (Throwable t) {
                _inputImageFailed = true;
            }
        }

        return _inputImage;
    }

    void retain() {
        _references.incrementAndGet();
    }

    void release() {
        if (_references.decrementAndGet() != 0)
            return;

        try {
            _proxy.close();
        } catch (Throwable ignored) {
        }
    }
}
