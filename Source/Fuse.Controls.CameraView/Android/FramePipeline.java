package com.fuse.controls.cameraview;

import android.util.Log;

import androidx.camera.core.ImageAnalysis;
import androidx.camera.core.ImageProxy;

import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.Executor;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * The shared frame analysis pipeline.
 *
 * CameraX binds a single ImageAnalysis use case, so every detector is a
 * {@link Consumer} registered here. The use case is created when the first
 * consumer is attached and released when the last one is detached.
 *
 * The pipeline owns frame lifetime: each analysed frame is handed to every
 * consumer as a {@link FrameLease}, and closed when the last reference is
 * released. It also owns frame cadence, so a consumer can ask for a lower frame
 * rate than the camera delivers, and it isolates consumers from each other so a
 * slow or failing detector cannot stall the preview.
 */
final class FramePipeline {

    private static final String Tag = "FuseCameraView";
    private static final int MaxConsecutiveFailures = 3;

    /** A detector that consumes analysed frames. */
    interface Consumer {
        /** Called for every frame admitted by the consumer's cadence. */
        void onFrame(FrameLease lease);
    }

    private static final class Registration {
        final Consumer consumer;
        final int maxFps;
        final Executor dispatch;
        final AtomicBoolean busy;
        long lastFrameNs;
        int failures;

        Registration(Consumer consumer, int maxFps, Executor dispatch) {
            this.consumer = consumer;
            this.maxFps = maxFps;
            this.dispatch = dispatch;
            this.busy = dispatch != null ? new AtomicBoolean(false) : null;
        }
    }

    private final FrameAnalysis.Host _host;
    private final List<Registration> _registrations = new CopyOnWriteArrayList<>();

    private volatile ImageAnalysis _useCase;
    private boolean _restoreVideoBinding;
    private int _requestedWidth;
    private int _requestedHeight;

    FramePipeline(FrameAnalysis.Host host) {
        _host = host;
    }

    /**
     * Sets the resolution requested for the analysis stream. It applies the next
     * time the use case is created.
     */
    void setResolution(int width, int height) {
        _requestedWidth = width;
        _requestedHeight = height;
    }

    /** The analysis use case when it is bound, otherwise null. */
    ImageAnalysis useCase() {
        return _useCase;
    }

    /**
     * Registers a consumer and binds the analysis use case.
     *
     * Returns null on success, or a message describing why it could not start.
     */
    String attach(Consumer consumer) {
        return attach(consumer, 0, null);
    }

    /**
     * Registers a consumer.
     *
     * A maxFps above zero limits how often the consumer is called. A non-null
     * dispatch executor runs the consumer off the analysis thread and drops
     * frames while it is still busy with the previous one.
     */
    String attach(Consumer consumer, int maxFps, Executor dispatch) {
        if (_host.isDisposed())
            return "Camera has been disposed";

        if (find(consumer) != null)
            return "Detector is already attached";

        Registration registration = new Registration(consumer, maxFps, dispatch);
        _registrations.add(registration);

        String error = ensureBound();
        if (error != null) {
            _registrations.remove(registration);
            return error;
        }

        return null;
    }

    void detach(Consumer consumer) {
        Registration registration = find(consumer);
        if (registration != null)
            _registrations.remove(registration);

        releaseIfIdle();
    }

    boolean isEmpty() {
        return _registrations.isEmpty();
    }

    void dispose() {
        _registrations.clear();
        _useCase = null;
    }

    // ---------------------------------------------------------------------
    // Use case lifetime
    // ---------------------------------------------------------------------

    private String ensureBound() {
        if (_useCase != null)
            return null;

        // Binding the analysis use case rebinds all use cases, so remember
        // whether video was part of the previous configuration.
        _restoreVideoBinding = _host.isVideoBound();

        try {
            ImageAnalysis.Builder builder = new ImageAnalysis.Builder()
                                                 .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST);

            if (_requestedWidth > 0 && _requestedHeight > 0)
                builder.setTargetResolution(new android.util.Size(_requestedWidth, _requestedHeight));

            ImageAnalysis analysis = builder.build();
            analysis.setAnalyzer(_host.cameraExecutor(), new ImageAnalysis.Analyzer() {
                @Override
                public void analyze(ImageProxy proxy) {
                    dispatchFrame(proxy);
                }
            });
            _useCase = analysis;
        } catch (Throwable t) {
            _useCase = null;
            return "Could not start frame analysis: " + messageOf(t);
        }

        boolean bound = _host.bindUseCases(_restoreVideoBinding);
        if (!bound && _restoreVideoBinding)
            bound = _host.bindUseCases(false);

        if (!bound) {
            _useCase = null;
            return "Could not start frame analysis";
        }

        _host.restorePreviewSurface();
        return null;
    }

    private void releaseIfIdle() {
        if (!isEmpty())
            return;

        ImageAnalysis analysis = _useCase;
        _useCase = null;

        if (analysis != null) {
            // Unbinding just the analysis use case keeps preview, photo and
            // video bound. The analyzer is not cleared here since clearAnalyzer()
            // can block until the current frame is closed.
            _host.unbindUseCase(analysis);
        }

        if (_host.isDisposed())
            return;

        // If starting the analysis left the camera unbound, restore the binding
        // the camera had before it started.
        if (_host.isCameraUnbound()) {
            if (!_host.bindUseCases(_restoreVideoBinding) && _restoreVideoBinding)
                _host.bindUseCases(false);
        }

        _host.restorePreviewSurface();
    }

    // ---------------------------------------------------------------------
    // Frame dispatch
    // ---------------------------------------------------------------------

    private void dispatchFrame(ImageProxy proxy) {
        if (_host.isDisposed() || _registrations.isEmpty() || proxy.getImage() == null) {
            proxy.close();
            return;
        }

        FrameGeometry geometry = FrameGeometry.of(
            proxy.getWidth(),
            proxy.getHeight(),
            proxy.getImageInfo().getRotationDegrees(),
            _host.isFrontCamera() && _host.isPreviewMirrored());

        FrameLease lease = new FrameLease(proxy, geometry);
        long nowNs = System.nanoTime();

        for (Registration registration : _registrations) {
            if (admit(registration, nowNs))
                dispatch(registration, lease);
        }

        lease.release();
    }

    private void dispatch(Registration registration, FrameLease lease) {
        Consumer consumer = registration.consumer;

        if (registration.dispatch == null) {
            try {
                consumer.onFrame(lease);
                registration.failures = 0;
            } catch (Throwable t) {
                onConsumerFailure(registration, t);
            }
            return;
        }

        // Off-thread consumers drop frames while they are busy instead of
        // slowing down the pipeline for everyone else.
        if (!registration.busy.compareAndSet(false, true))
            return;

        lease.retain();
        try {
            registration.dispatch.execute(new Runnable() {
                @Override
                public void run() {
                    try {
                        consumer.onFrame(lease);
                    } catch (Throwable t) {
                        onConsumerFailure(registration, t);
                    } finally {
                        registration.busy.set(false);
                        lease.release();
                    }
                }
            });
        } catch (Throwable t) {
            registration.busy.set(false);
            lease.release();
            onConsumerFailure(registration, t);
        }
    }

    private static boolean admit(Registration registration, long nowNs) {
        int maxFps = registration.maxFps;
        if (maxFps <= 0) {
            registration.lastFrameNs = nowNs;
            return true;
        }

        long minimumInterval = 1000000000L / maxFps;
        if (nowNs - registration.lastFrameNs < minimumInterval)
            return false;

        registration.lastFrameNs = nowNs;
        return true;
    }

    private void onConsumerFailure(Registration registration, Throwable error) {
        Log.w(Tag, "Frame consumer failed", error);
        registration.failures++;

        if (registration.failures < MaxConsecutiveFailures)
            return;

        // Detaching changes the camera binding, which belongs on the main thread.
        final Registration failed = registration;
        _host.mainHandler().post(new Runnable() {
            @Override
            public void run() {
                detach(failed.consumer);
            }
        });
    }

    private Registration find(Consumer consumer) {
        for (Registration registration : _registrations) {
            if (registration.consumer == consumer)
                return registration;
        }
        return null;
    }

    static String messageOf(Throwable t) {
        String message = t.getMessage();
        return message != null ? message : t.toString();
    }
}
