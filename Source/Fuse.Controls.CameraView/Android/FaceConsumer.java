package com.fuse.controls.cameraview;

import android.graphics.Rect;
import android.graphics.RectF;

import androidx.annotation.NonNull;

import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.OnSuccessListener;
import com.google.android.gms.tasks.Task;
import com.google.mlkit.vision.common.InputImage;
import com.google.mlkit.vision.face.Face;
import com.google.mlkit.vision.face.FaceDetection;
import com.google.mlkit.vision.face.FaceDetector;
import com.google.mlkit.vision.face.FaceDetectorOptions;

import java.util.List;

/**
 * Face detection on top of the frame pipeline.
 *
 * Bounds are reported normalized to the preview, with the origin in the top left
 * corner of the preview as displayed, using the frame geometry shared by all
 * consumers.
 */
final class FaceConsumer implements FramePipeline.Consumer {

    private final FrameAnalysis.Host _host;
    private final FramePipeline _pipeline;

    private FaceDetector _detector;
    private boolean _active;
    private CameraXSession.FaceCallback _callback;

    FaceConsumer(FrameAnalysis.Host host, FramePipeline pipeline) {
        _host = host;
        _pipeline = pipeline;
    }

    /** Returns null on success, or a message describing why detection cannot start. */
    String start(CameraXSession.FaceCallback callback) {
        if (_active)
            return "Face detection is already running";

        _active = true;
        _callback = callback;

        try {
            _detector = FaceDetection.getClient(new FaceDetectorOptions.Builder()
                .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
                .enableTracking()
                .build());
        } catch (Throwable t) {
            finish();
            return "Could not start face detection: " + FramePipeline.messageOf(t);
        }

        String error = _pipeline.attach(this);
        if (error != null) {
            finish();
            return error;
        }

        return null;
    }

    boolean stop() {
        boolean wasActive = _active;
        finish();
        return wasActive;
    }

    boolean isActive() {
        return _active;
    }

    void dispose() {
        finish();
    }

    @Override
    public void onFrame(FrameLease lease) {
        FaceDetector detector = _active ? _detector : null;
        if (detector == null)
            return;

        FrameGeometry geometry = lease.geometry();
        if (!geometry.isValid())
            return;

        InputImage input = lease.inputImage();
        if (input == null)
            return;

        // ML Kit keeps working after this callback returns, so hold the frame
        // open until the task completes.
        lease.retain();

        Task<List<Face>> task;
        try {
            task = detector.process(input);
        } catch (Throwable t) {
            lease.release();
            return;
        }

        task.addOnSuccessListener(new OnSuccessListener<List<Face>>() {
            @Override
            public void onSuccess(List<Face> faces) {
                if (faces != null)
                    deliver(faces, geometry);
            }
        }).addOnCompleteListener(new OnCompleteListener<List<Face>>() {
            @Override
            public void onComplete(@NonNull Task<List<Face>> task) {
                lease.release();
            }
        });
    }

    private void finish() {
        if (!_active)
            return;

        _active = false;
        _callback = null;

        if (_detector != null) {
            try {
                _detector.close();
            } catch (Throwable ignored) {
            }
            _detector = null;
        }

        _pipeline.detach(this);
    }

    private void deliver(List<Face> faces, final FrameGeometry geometry) {
        if (!_active || _callback == null)
            return;

        final List<Face> detected = faces;

        _host.mainHandler().post(new Runnable() {
            @Override
            public void run() {
                CameraXSession.FaceCallback callback = _callback;
                if (!_active || callback == null)
                    return;

                RectF bounds = new RectF();

                for (Face face : detected) {
                    Rect box = face.getBoundingBox();
                    geometry.normalize(box, bounds);

                    Integer trackingId = face.getTrackingId();
                    callback.onFace(
                        trackingId == null ? -1 : trackingId,
                        bounds.left,
                        bounds.top,
                        bounds.width(),
                        bounds.height(),
                        face.getHeadEulerAngleZ(),
                        face.getHeadEulerAngleY());
                }

                callback.onFrame();
            }
        });
    }
}
