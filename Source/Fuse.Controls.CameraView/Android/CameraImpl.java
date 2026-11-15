package com.fuse.controls.cameraview;

import android.content.Context;
import android.widget.FrameLayout;

import androidx.camera.view.PreviewView;

/**
 * Preview container for the CameraX backend.
 *
 * PreviewView is final in CameraX, so the native view exposed to Fuse is a
 * FrameLayout containing a PreviewView.
 */
public class CameraImpl extends FrameLayout {
    final CameraXSession _session;
    final PreviewView _previewView;
    final CameraOverlayView _overlayView;

    public CameraImpl(Context context, CameraXSession session) {
        super(context);
        _session = session;
        _previewView = new PreviewView(context);
        _previewView.setLayoutParams(new FrameLayout.LayoutParams(
            android.view.ViewGroup.LayoutParams.MATCH_PARENT,
            android.view.ViewGroup.LayoutParams.MATCH_PARENT));
        addView(_previewView);
        session.attachPreviewView(_previewView);

        _overlayView = new CameraOverlayView(context);
        _overlayView.setLayoutParams(new FrameLayout.LayoutParams(
            android.view.ViewGroup.LayoutParams.MATCH_PARENT,
            android.view.ViewGroup.LayoutParams.MATCH_PARENT));
        addView(_overlayView);
        session.attachOverlayView(_overlayView);
    }

    public void updateStretchMode(boolean shouldFill) {
        _session.updateStretchMode(shouldFill);
    }

    public String saveParameters() {
        return "";
    }

    public void restoreParameters(String parameters) {
    }

    public void setPictureSize(int width, int height) {
        _session.setPictureSize(width, height);
    }

    public void setFlashMode(String flashMode) {
        _session.setFlashMode(flashMode);
    }

    public void setCameraFocusPoint(double x, double y, int cameraWidth, int cameraHeight, int isFocusLocked) {
        float px = cameraWidth > 0 ? (float)(x / cameraWidth) * _previewView.getWidth() : (float)x;
        float py = cameraHeight > 0 ? (float)(y / cameraHeight) * _previewView.getHeight() : (float)y;
        _session.setFocusPoint(px, py, isFocusLocked == 1);
    }

    public void takePicture(IPictureCallback callback) {
        _session.takePicture(callback);
    }

    public void startRecording(
            IStartRecordingSession startRecordingSession,
            int width,
            int height,
            int frameRate,
            int bitRate,
            boolean audioEnabled,
            boolean stabilizationEnabled) {
        _session.startRecording(
            startRecordingSession,
            width,
            height,
            frameRate,
            bitRate,
            audioEnabled,
            stabilizationEnabled);
    }

    public void dispose() {
        _session.dispose();
    }
}
