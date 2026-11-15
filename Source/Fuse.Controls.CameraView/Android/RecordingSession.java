package com.fuse.controls.cameraview;

import androidx.camera.video.Recording;
import androidx.camera.video.VideoRecordEvent;
import androidx.core.util.Consumer;

/**
 * Wrapper around a CameraX Recording.
 */
public class RecordingSession implements Consumer<VideoRecordEvent> {

    final String _outputFilePath;

    volatile Recording _recording;
    volatile IStopRecordingSession _stopCallback;

    volatile long _durationNanos;
    volatile boolean _started;
    volatile boolean _finalized;
    volatile String _finalError;
    volatile boolean _closed;

    public RecordingSession(String outputFilePath) {
        _outputFilePath = outputFilePath;
    }

    public void setRecording(Recording recording) {
        _recording = recording;
    }

    @Override
    public void accept(VideoRecordEvent event) {
        if (event instanceof VideoRecordEvent.Start) {
            _started = true;
        } else if (event instanceof VideoRecordEvent.Status) {
            _durationNanos = ((VideoRecordEvent.Status)event).getRecordingStats().getRecordedDurationNanos();
        } else if (event instanceof VideoRecordEvent.Finalize) {
            VideoRecordEvent.Finalize finalized = (VideoRecordEvent.Finalize)event;
            _finalized = true;
            if (finalized.hasError()) {
                Throwable cause = finalized.getCause();
                String message = cause != null ? cause.getMessage() : null;
                _finalError = message != null ? message : "Video recording failed: " + finalized.getError();
            }

            IStopRecordingSession callback = _stopCallback;
            _stopCallback = null;

            if (callback != null) {
                if (_finalError != null)
                    callback.onException(_finalError);
                else
                    callback.onSuccess(_outputFilePath);
            }

            closeInternal();
        }
    }

    public void stop(IStopRecordingSession callback) {
        if (_finalized) {
            if (_finalError != null)
                callback.onException(_finalError);
            else
                callback.onSuccess(_outputFilePath);
            return;
        }

        _stopCallback = callback;

        if (_recording == null) {
            _finalized = true;
            _finalError = "Recording was not started";
            _stopCallback = null;
            callback.onException(_finalError);
            return;
        }

        _recording.stop();
    }

    public boolean pause() {
        if (_recording == null || _finalized)
            return false;

        try {
            _recording.pause();
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    public boolean resume() {
        if (_recording == null || _finalized)
            return false;

        try {
            _recording.resume();
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    public long getDurationMillis() {
        return _durationNanos / 1000000L;
    }

    public void close() {
        closeInternal();
    }

    void closeInternal() {
        if (_closed)
            return;
        _closed = true;

        if (_recording != null) {
            try {
                _recording.close();
            } catch (Exception ignored) {
            }
            _recording = null;
        }
    }
}
