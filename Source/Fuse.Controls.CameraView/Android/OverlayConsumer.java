package com.fuse.controls.cameraview;

import android.graphics.Rect;

import androidx.camera.core.ImageProxy;

import java.nio.ByteBuffer;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Zebra and focus peaking, drawn as a mask on the overlay view.
 *
 * The mask is computed from a downscaled luminance grid, so a frame costs a
 * sparse read plus one pass over the small grid. Two masks are kept so the
 * analysis thread can fill the next one while the UI thread draws the previous
 * one, and a frame is dropped when the UI thread has not caught up.
 */
final class OverlayConsumer implements FramePipeline.Consumer {

    private static final int MaskWidth = 160;

    private static final int ZebraColor = 0xffffffff;
    private static final int PeakingColor = 0xffffeb3b;

    private final FrameAnalysis.Host _host;
    private final FramePipeline _pipeline;
    private final CameraOverlayView _view;

    private double _zebra;
    private double _peaking;

    private byte[] _grid;
    private int _gridWidth;
    private int _gridHeight;

    private final int[][] _masks = new int[2][];
    private int _maskIndex;

    private volatile boolean _active;
    private final AtomicBoolean _pending = new AtomicBoolean(false);

    OverlayConsumer(FrameAnalysis.Host host, FramePipeline pipeline, CameraOverlayView view) {
        _host = host;
        _pipeline = pipeline;
        _view = view;
    }

    void configure(double zebra, double peaking) {
        _zebra = zebra;
        _peaking = peaking;
    }

    boolean isEmpty() {
        return _zebra <= 0 && _peaking <= 0;
    }

    boolean isActive() {
        return _active;
    }

    /** Returns null on success, or a message describing why the overlay cannot start. */
    String start() {
        if (_active)
            return null;

        _active = true;

        String error = _pipeline.attach(this, 24, null);
        if (error != null) {
            _active = false;
            return error;
        }

        return null;
    }

    void stop() {
        if (!_active)
            return;

        _active = false;
        _pipeline.detach(this);

        _host.mainHandler().post(new Runnable() {
            @Override
            public void run() {
                _view.clearMask();
            }
        });
    }

    @Override
    public void onFrame(FrameLease lease) {
        if (!_active || isEmpty())
            return;

        FrameGeometry geometry = lease.geometry();
        if (!geometry.isValid())
            return;

        ImageProxy proxy = lease.proxy();
        ImageProxy.PlaneProxy plane = proxy.getPlanes()[0];
        Rect crop = proxy.getCropRect();

        int width = MaskWidth;
        int height = geometry.heightForWidth(width);
        if (height <= 0)
            return;

        if (_grid == null || _gridWidth != width || _gridHeight != height) {
            _gridWidth = width;
            _gridHeight = height;
            _grid = new byte[width * height];
            _masks[0] = new int[width * height];
            _masks[1] = new int[width * height];
        }

        ByteBuffer buffer = plane.getBuffer();
        geometry.sampleLuma(buffer, plane.getRowStride(), plane.getPixelStride(), crop, width, height, _grid);

        final int index = _maskIndex;
        int[] pixels = _masks[index];
        render(pixels);

        if (!_pending.compareAndSet(false, true))
            return;

        // The other buffer is used by the next frame, so this one is safe to
        // read from the UI thread.
        _maskIndex = index ^ 1;

        _host.mainHandler().post(new Runnable() {
            @Override
            public void run() {
                _pending.set(false);

                if (!_active)
                    return;

                _view.drawMask(pixels, width, height);
            }
        });
    }

    private void render(int[] pixels) {
        byte[] grid = _grid;
        int width = _gridWidth;
        int height = _gridHeight;

        boolean zebra = _zebra > 0;
        boolean peaking = _peaking > 0;
        int zebraThreshold = (int)(_zebra * 255);

        for (int y = 0; y < height; y++) {
            int row = y * width;

            for (int x = 0; x < width; x++) {
                int index = row + x;
                int color = 0;

                if (zebra && (grid[index] & 0xff) >= zebraThreshold) {
                    // Diagonal stripes, so the marked area still shows what is
                    // underneath it.
                    color = ((x + y) & 7) < 4 ? ZebraColor : 0;
                }

                if (color == 0 && peaking && isEdge(grid, width, height, x, y))
                    color = PeakingColor;

                pixels[index] = color;
            }
        }
    }

    private boolean isEdge(byte[] grid, int width, int height, int x, int y) {
        int left = grid[y * width + Math.max(0, x - 1)];
        int right = grid[y * width + Math.min(width - 1, x + 1)];
        int top = grid[Math.max(0, y - 1) * width + x];
        int bottom = grid[Math.min(height - 1, y + 1) * width + x];

        int gradient = Math.abs((right & 0xff) - (left & 0xff)) + Math.abs((bottom & 0xff) - (top & 0xff));

        // A higher sensitivity means weaker edges are marked.
        int threshold = (int)((1.0 - _peaking) * 200) + 20;
        return gradient >= threshold;
    }
}
