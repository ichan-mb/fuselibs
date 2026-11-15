package com.fuse.controls.cameraview;

import android.graphics.Rect;
import android.graphics.RectF;

import java.nio.ByteBuffer;

/**
 * Geometry of a single analysed frame.
 *
 * Detectors report coordinates in the upright image, so converting them to the
 * preview only needs the upright size and whether the preview is mirrored. This
 * is the one place where that mapping is defined, so every consumer agrees on
 * it.
 */
final class FrameGeometry {

    /** Size of the analysed buffer, before rotation. */
    final int width;
    final int height;

    /** Clockwise rotation needed to make the buffer upright. */
    final int rotationDegrees;

    /** Whether the preview is mirrored horizontally. */
    final boolean mirrored;

    /** Size of the image after rotation. */
    final int uprightWidth;
    final int uprightHeight;

    private FrameGeometry(int width, int height, int rotationDegrees, boolean mirrored) {
        this.width = width;
        this.height = height;
        this.rotationDegrees = rotationDegrees;
        this.mirrored = mirrored;

        boolean swapped = rotationDegrees == 90 || rotationDegrees == 270;
        uprightWidth = swapped ? height : width;
        uprightHeight = swapped ? width : height;
    }

    static FrameGeometry of(int width, int height, int rotationDegrees, boolean mirrored) {
        return new FrameGeometry(width, height, rotationDegrees, mirrored);
    }

    boolean isValid() {
        return uprightWidth > 0 && uprightHeight > 0;
    }

    /** Height that keeps the upright aspect for the given mask width. */
    int heightForWidth(int targetWidth) {
        if (uprightWidth <= 0)
            return 1;

        return Math.max(1, Math.round((float)targetWidth * uprightHeight / uprightWidth));
    }

    /**
     * Converts an upright pixel rectangle to preview coordinates, normalized to
     * 0..1 with the origin in the top left corner of the preview as displayed.
     */
    void normalize(Rect source, RectF destination) {
        float left = (float)source.left / uprightWidth;
        float top = (float)source.top / uprightHeight;
        float width = (float)source.width() / uprightWidth;
        float height = (float)source.height() / uprightHeight;

        if (mirrored)
            left = 1.0f - left - width;

        destination.left = clamp01(left);
        destination.top = clamp01(top);
        destination.right = clamp01(left + width);
        destination.bottom = clamp01(top + height);
    }

    /**
     * Samples the luminance plane into an upright, optionally mirrored image.
     *
     * The destination is smaller than the frame, so this is a sparse read that
     * costs nothing close to a full pass. The buffer position is left alone,
     * since other consumers may read the same plane.
     */
    void sampleLuma(ByteBuffer buffer, int rowStride, int pixelStride, Rect crop,
                    int targetWidth, int targetHeight, byte[] destination) {
        int sourceWidth = crop.width();
        int sourceHeight = crop.height();

        for (int ty = 0; ty < targetHeight; ty++) {
            double v = (ty + 0.5) / targetHeight;
            int rowOffset = ty * targetWidth;

            for (int tx = 0; tx < targetWidth; tx++) {
                double u = (tx + 0.5) / targetWidth;
                if (mirrored)
                    u = 1.0 - u;

                int sx;
                int sy;
                switch (rotationDegrees) {
                case 90:
                    sx = (int)(v * sourceWidth);
                    sy = (int)((1.0 - u) * sourceHeight);
                    break;
                case 180:
                    sx = (int)((1.0 - u) * sourceWidth);
                    sy = (int)((1.0 - v) * sourceHeight);
                    break;
                case 270:
                    sx = (int)((1.0 - v) * sourceWidth);
                    sy = (int)(u * sourceHeight);
                    break;
                default:
                    sx = (int)(u * sourceWidth);
                    sy = (int)(v * sourceHeight);
                    break;
                }

                sx = clampIndex(sx, sourceWidth);
                sy = clampIndex(sy, sourceHeight);

                int index = (crop.top + sy) * rowStride + (crop.left + sx) * pixelStride;
                destination[rowOffset + tx] = buffer.get(index);
            }
        }
    }

    private static int clampIndex(int value, int size) {
        if (value < 0)
            return 0;
        return value >= size ? size - 1 : value;
    }

    static float clamp01(float value) {
        return Math.max(0.0f, Math.min(1.0f, value));
    }
}
