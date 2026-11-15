package com.fuse.controls.cameraview;

import android.graphics.Rect;

import androidx.camera.core.ImageProxy;

import java.nio.ByteBuffer;
import java.util.Arrays;

/**
 * Exposure statistics on top of the frame pipeline.
 *
 * Statistics are computed from the luminance plane of the analysed frame, so no
 * color conversion takes place. The work is one pass over the plane for the
 * histogram, plus a sparse pass when a downscaled luminance image is requested.
 *
 * The delivered buffers are only valid until the next frame, and the Uno side
 * takes them once per delivery.
 */
final class StatisticsConsumer implements FramePipeline.Consumer {

    static final int HistogramBins = 64;

    private static final int ClippedLowBins = 2;
    private static final int ClippedHighBins = 2;

    interface Callback {
        void onStatistics(double timestamp, double mean, double p1, double p50, double p99,
                          double clippedLow, double clippedHigh, double analysisTime);
    }

    private final FrameAnalysis.Host _host;
    private final FramePipeline _pipeline;
    private final Callback _callback;
    private final int _maxFps;
    private final int _lumaWidth;
    private final int _lumaHeight;

    private boolean _active;

    private final int[] _counts = new int[HistogramBins];
    private byte[] _row;
    private volatile byte[] _histogram;
    private volatile byte[] _luma;

    StatisticsConsumer(FrameAnalysis.Host host, FramePipeline pipeline, int maxFps,
                       int lumaWidth, int lumaHeight, Callback callback) {
        _host = host;
        _pipeline = pipeline;
        _maxFps = maxFps;
        _lumaWidth = lumaWidth;
        _lumaHeight = lumaHeight;
        _callback = callback;
    }

    /** Returns null on success, or a message describing why analysis cannot start. */
    String start(int resolutionWidth, int resolutionHeight) {
        if (_active)
            return "Frame analysis is already running";

        _active = true;
        _pipeline.setResolution(resolutionWidth, resolutionHeight);

        String error = _pipeline.attach(this, _maxFps, null);
        if (error != null) {
            _active = false;
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

    /** The histogram of the last delivered frame, or null when already taken. */
    byte[] takeHistogram() {
        byte[] histogram = _histogram;
        _histogram = null;
        return histogram;
    }

    /** The luminance image of the last delivered frame, or null when already taken. */
    byte[] takeLuma() {
        byte[] luma = _luma;
        _luma = null;
        return luma;
    }

    int lumaWidth() {
        return _lumaWidth;
    }

    int lumaHeight() {
        return _lumaHeight;
    }

    @Override
    public void onFrame(FrameLease lease) {
        if (!_active)
            return;

        ImageProxy proxy = lease.proxy();
        ImageProxy.PlaneProxy plane = proxy.getPlanes()[0];
        Rect crop = proxy.getCropRect();

        int width = crop.width();
        int height = crop.height();
        if (width <= 0 || height <= 0)
            return;

        long startNs = System.nanoTime();

        ByteBuffer buffer = plane.getBuffer();
        int rowStride = plane.getRowStride();
        int pixelStride = plane.getPixelStride();

        int total = accumulate(buffer, rowStride, pixelStride, crop);
        if (total <= 0)
            return;

        long sum = 0;
        for (int i = 0; i < HistogramBins; i++)
            sum += (long)_counts[i] * (i * 256L / HistogramBins);

        publishHistogram(total);
        if (_lumaWidth > 0 && _lumaHeight > 0)
            publishLuma(buffer, rowStride, pixelStride, crop, lease.geometry());

        double analysisMs = (System.nanoTime() - startNs) / 1000000.0;
        double timestamp = proxy.getImageInfo().getTimestamp() / 1000000.0;

        deliver(new Statistics(
            timestamp,
            (double)sum / ((double)total * 255.0),
            percentile(0.01, total),
            percentile(0.50, total),
            percentile(0.99, total),
            clipped(ClippedLowBins, total, 0),
            clipped(ClippedHighBins, total, HistogramBins - ClippedHighBins),
            analysisMs));
    }

    // ---------------------------------------------------------------------
    // Pixel work
    // ---------------------------------------------------------------------

    private int accumulate(ByteBuffer buffer, int rowStride, int pixelStride, Rect crop) {
        int[] counts = _counts;
        Arrays.fill(counts, 0);

        int width = crop.width();
        int height = crop.height();

        // ML Kit reads the same plane buffer after this callback returns, so the
        // position is restored before leaving.
        int savedPosition = buffer.position();

        if (pixelStride == 1) {
            if (_row == null || _row.length < width)
                _row = new byte[width];

            byte[] row = _row;
            for (int y = 0; y < height; y++) {
                buffer.position((crop.top + y) * rowStride + crop.left);
                buffer.get(row, 0, width);

                for (int x = 0; x < width; x++)
                    counts[(row[x] & 0xff) * HistogramBins / 256]++;
            }

            buffer.position(savedPosition);
            return width * height;
        }

        for (int y = 0; y < height; y++) {
            int rowStart = (crop.top + y) * rowStride + crop.left * pixelStride;
            for (int x = 0; x < width; x++) {
                int value = buffer.get(rowStart + x * pixelStride) & 0xff;
                counts[value * HistogramBins / 256]++;
            }
        }
        return width * height;
    }

    private void publishHistogram(int total) {
        // A new buffer per frame: the Uno side takes the previous one on the main
        // thread, so the array must not be written to after it is published.
        byte[] histogram = new byte[HistogramBins];

        for (int i = 0; i < HistogramBins; i++)
            histogram[i] = (byte)Math.min(255, _counts[i] * 255 / total);

        _histogram = histogram;
    }

    private void publishLuma(ByteBuffer buffer, int rowStride, int pixelStride, Rect crop, FrameGeometry geometry) {
        // A new buffer per frame: the Uno side takes the previous one on the main
        // thread, so the array must not be written to after it is published.
        byte[] luma = new byte[_lumaWidth * _lumaHeight];
        geometry.sampleLuma(buffer, rowStride, pixelStride, crop, _lumaWidth, _lumaHeight, luma);
        _luma = luma;
    }

    // ---------------------------------------------------------------------
    // Derived values
    // ---------------------------------------------------------------------

    private double percentile(double fraction, int total) {
        int target = (int)Math.ceil(fraction * total);
        if (target <= 0)
            target = 1;

        int cumulative = 0;
        for (int i = 0; i < HistogramBins; i++) {
            cumulative += _counts[i];
            if (cumulative >= target)
                return (i + 0.5) / HistogramBins;
        }

        return 1.0;
    }

    private double clipped(int bins, int total, int start) {
        int clipped = 0;
        for (int i = start; i < start + bins && i < HistogramBins; i++)
            clipped += _counts[i];

        return (double)clipped / total;
    }

    // ---------------------------------------------------------------------
    // Delivery
    // ---------------------------------------------------------------------

    private static final class Statistics {
        final double timestamp;
        final double mean;
        final double p1;
        final double p50;
        final double p99;
        final double clippedLow;
        final double clippedHigh;
        final double analysisTime;

        Statistics(double timestamp, double mean, double p1, double p50, double p99,
                   double clippedLow, double clippedHigh, double analysisTime) {
            this.timestamp = timestamp;
            this.mean = mean;
            this.p1 = p1;
            this.p50 = p50;
            this.p99 = p99;
            this.clippedLow = clippedLow;
            this.clippedHigh = clippedHigh;
            this.analysisTime = analysisTime;
        }
    }

    private void deliver(final Statistics statistics) {
        _host.mainHandler().post(new Runnable() {
            @Override
            public void run() {
                if (!_active)
                    return;

                _callback.onStatistics(
                    statistics.timestamp,
                    statistics.mean,
                    statistics.p1,
                    statistics.p50,
                    statistics.p99,
                    statistics.clippedLow,
                    statistics.clippedHigh,
                    statistics.analysisTime);
            }
        });
    }

    private void finish() {
        if (!_active)
            return;

        _active = false;
        _luma = null;
        _histogram = null;
        _pipeline.detach(this);
    }
}
