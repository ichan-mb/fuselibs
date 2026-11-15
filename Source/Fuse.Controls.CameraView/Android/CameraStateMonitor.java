package com.fuse.controls.cameraview;

import androidx.camera.core.Camera;
import androidx.camera.core.CameraState;
import androidx.lifecycle.LiveData;
import androidx.lifecycle.Observer;

/**
 * Reports errors from the CameraX camera state.
 */
final class CameraStateMonitor {
    interface Listener {
        void onError(String reason, String message);
    }

    private final Listener _listener;

    private LiveData<CameraState> _state;
    private Observer<CameraState> _observer;
    private int _lastError;

    CameraStateMonitor(Listener listener) {
        _listener = listener;
    }

    /**
     * Starts observing the camera. A null camera only detaches the current observer.
     */
    void attach(Camera camera) {
        detach();

        if (camera == null)
            return;

        LiveData<CameraState> state = camera.getCameraInfo().getCameraState();
        if (state == null)
            return;

        _state = state;
        _observer = new Observer<CameraState>() {
            @Override
            public void onChanged(CameraState cameraState) {
                if (cameraState == null)
                    return;

                CameraState.StateError error = cameraState.getError();
                int code = error == null ? 0 : error.getCode();
                if (code == _lastError)
                    return;

                _lastError = code;
                if (code != 0)
                    _listener.onError(reasonOf(code), messageOf(code));
            }
        };
        state.observeForever(_observer);
    }

    void detach() {
        if (_state != null && _observer != null) {
            try {
                _state.removeObserver(_observer);
            } catch (Throwable ignored) {
            }
        }

        _state = null;
        _observer = null;
        _lastError = 0;
    }

    static String reasonOf(int code) {
        switch (code) {
        case CameraState.ERROR_CAMERA_IN_USE:
        case CameraState.ERROR_MAX_CAMERAS_IN_USE:
            return "in-use";
        case CameraState.ERROR_CAMERA_DISABLED:
            return "disabled";
        case CameraState.ERROR_CAMERA_FATAL_ERROR:
            return "fatal";
        case CameraState.ERROR_STREAM_CONFIG:
            return "stream-config";
        case CameraState.ERROR_OTHER_RECOVERABLE_ERROR:
            return "recoverable";
        case CameraState.ERROR_DO_NOT_DISTURB_MODE_ENABLED:
            return "do-not-disturb";
        default:
            return "unknown";
        }
    }

    static String messageOf(int code) {
        switch (code) {
        case CameraState.ERROR_CAMERA_IN_USE:
            return "The camera is in use by another app";
        case CameraState.ERROR_MAX_CAMERAS_IN_USE:
            return "Too many cameras are already in use";
        case CameraState.ERROR_CAMERA_DISABLED:
            return "The camera is disabled by the device policy";
        case CameraState.ERROR_CAMERA_FATAL_ERROR:
            return "The camera reported a fatal error";
        case CameraState.ERROR_STREAM_CONFIG:
            return "The camera stream configuration failed";
        case CameraState.ERROR_OTHER_RECOVERABLE_ERROR:
            return "The camera reported a recoverable error";
        case CameraState.ERROR_DO_NOT_DISTURB_MODE_ENABLED:
            return "The camera is not available while do not disturb is enabled";
        default:
            return "The camera reported an unknown error";
        }
    }
}
