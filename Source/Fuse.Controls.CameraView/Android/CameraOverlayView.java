package com.fuse.controls.cameraview;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.RectF;
import android.view.View;

/**
 * Draws the analysis overlay on top of the preview.
 *
 * The mask is computed at a low resolution on the analysis thread and drawn
 * scaled, so a frame costs one bitmap upload and one draw call. The bitmap is
 * reused between frames.
 */
final class CameraOverlayView extends View {

    private static final int MaskAlpha = 190;

    private final Paint _paint = new Paint();
    private final Rect _source = new Rect();
    private final RectF _destination = new RectF();

    private Bitmap _bitmap;
    private boolean _fill;

    CameraOverlayView(Context context) {
        super(context);
        _paint.setAlpha(MaskAlpha);
    }

    /** Matches the letterboxing of the preview. */
    void setFill(boolean fill) {
        if (_fill == fill)
            return;

        _fill = fill;
        invalidate();
    }

    /** Must be called on the UI thread. */
    void drawMask(int[] pixels, int width, int height) {
        if (width <= 0 || height <= 0 || pixels == null)
            return;

        Bitmap bitmap = _bitmap;
        if (bitmap == null || bitmap.getWidth() != width || bitmap.getHeight() != height) {
            bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
            _bitmap = bitmap;
        }

        bitmap.setPixels(pixels, 0, width, 0, 0, width, height);
        invalidate();
    }

    /** Must be called on the UI thread. */
    void clearMask() {
        if (_bitmap == null)
            return;

        _bitmap = null;
        invalidate();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        Bitmap bitmap = _bitmap;
        if (bitmap == null)
            return;

        _source.set(0, 0, bitmap.getWidth(), bitmap.getHeight());
        computeDestination(bitmap, _destination);
        canvas.drawBitmap(bitmap, _source, _destination, _paint);
    }

    // Nearest neighbour scaling is enough for a mask, and it keeps the stripes
    // crisp instead of smearing them.
    private void computeDestination(Bitmap bitmap, RectF destination) {
        float viewWidth = getWidth();
        float viewHeight = getHeight();
        if (viewWidth <= 0 || viewHeight <= 0) {
            destination.set(0, 0, 0, 0);
            return;
        }

        float scaleX = viewWidth / bitmap.getWidth();
        float scaleY = viewHeight / bitmap.getHeight();
        float scale = _fill ? Math.max(scaleX, scaleY) : Math.min(scaleX, scaleY);

        float width = bitmap.getWidth() * scale;
        float height = bitmap.getHeight() * scale;
        float left = (viewWidth - width) * 0.5f;
        float top = (viewHeight - height) * 0.5f;

        destination.set(left, top, left + width, top + height);
    }
}
