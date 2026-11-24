package com.fuse.camera;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.ColorMatrix;
import android.graphics.ColorMatrixColorFilter;
import android.graphics.Paint;

final class ImageFilters {

	private ImageFilters() {
	}

	static Bitmap applyColorMatrix(Bitmap source, String type, float amount) throws Exception {
		ColorMatrix matrix = colorMatrixForFilter(type, amount);
		if (matrix == null)
			throw new Exception("Unsupported filter type: " + type);

		Bitmap result = Bitmap.createBitmap(source.getWidth(), source.getHeight(), Bitmap.Config.ARGB_8888);
		Canvas canvas = new Canvas(result);
		Paint paint = new Paint();
		paint.setColorFilter(new ColorMatrixColorFilter(matrix));
		canvas.drawBitmap(source, 0, 0, paint);
		return result;
	}

	static ColorMatrix colorMatrixForFilter(String type, float amount) {
		ColorMatrix matrix = new ColorMatrix();

		if ("grayscale".equals(type)) {
			matrix.setSaturation(0.0f);
		} else if ("sepia".equals(type)) {
			matrix.set(new float[] {
				0.393f, 0.769f, 0.189f, 0, 0,
				0.349f, 0.686f, 0.168f, 0, 0,
				0.272f, 0.534f, 0.131f, 0, 0,
				0, 0, 0, 1, 0
			});
		} else if ("brightness".equals(type)) {
			float offset = amount * 255.0f;
			matrix.set(new float[] {
				1, 0, 0, 0, offset,
				0, 1, 0, 0, offset,
				0, 0, 1, 0, offset,
				0, 0, 0, 1, 0
			});
		} else if ("contrast".equals(type)) {
			float factor = 1.0f + amount;
			float translate = 127.5f * (1.0f - factor);
			matrix.set(new float[] {
				factor, 0, 0, 0, translate,
				0, factor, 0, 0, translate,
				0, 0, factor, 0, translate,
				0, 0, 0, 1, 0
			});
		} else if ("saturation".equals(type)) {
			matrix.setSaturation(1.0f + amount);
		} else {
			return null;
		}

		return matrix;
	}

	static Bitmap boxBlur(Bitmap source, int radius) {
		int width = source.getWidth();
		int height = source.getHeight();
		int[] src = new int[width * height];
		int[] tmp = new int[width * height];

		source.getPixels(src, 0, width, 0, 0, width, height);
		boxBlurHorizontal(src, tmp, width, height, radius);
		boxBlurVertical(tmp, src, width, height, radius);

		Bitmap result = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
		result.setPixels(src, 0, width, 0, 0, width, height);
		return result;
	}

	static void boxBlurHorizontal(int[] src, int[] dst, int width, int height, int radius) {
		int window = radius * 2 + 1;

		for (int y = 0; y < height; y++) {
			int row = y * width;
			int a = 0, r = 0, g = 0, b = 0;

			for (int i = -radius; i <= radius; i++) {
				int x = Math.max(0, Math.min(width - 1, i));
				int p = src[row + x];
				a += (p >>> 24) & 0xFF;
				r += (p >>> 16) & 0xFF;
				g += (p >>> 8) & 0xFF;
				b += p & 0xFF;
			}

			for (int x = 0; x < width; x++) {
				dst[row + x] = ((a / window) << 24) | ((r / window) << 16) | ((g / window) << 8) | (b / window);

				int addX = Math.min(width - 1, x + radius + 1);
				int subX = Math.max(0, x - radius);
				int add = src[row + addX];
				int sub = src[row + subX];

				a += ((add >>> 24) & 0xFF) - ((sub >>> 24) & 0xFF);
				r += ((add >>> 16) & 0xFF) - ((sub >>> 16) & 0xFF);
				g += ((add >>> 8) & 0xFF) - ((sub >>> 8) & 0xFF);
				b += (add & 0xFF) - (sub & 0xFF);
			}
		}
	}

	static void boxBlurVertical(int[] src, int[] dst, int width, int height, int radius) {
		int window = radius * 2 + 1;

		for (int x = 0; x < width; x++) {
			int a = 0, r = 0, g = 0, b = 0;

			for (int i = -radius; i <= radius; i++) {
				int y = Math.max(0, Math.min(height - 1, i));
				int p = src[y * width + x];
				a += (p >>> 24) & 0xFF;
				r += (p >>> 16) & 0xFF;
				g += (p >>> 8) & 0xFF;
				b += p & 0xFF;
			}

			for (int y = 0; y < height; y++) {
				dst[y * width + x] = ((a / window) << 24) | ((r / window) << 16) | ((g / window) << 8) | (b / window);

				int addY = Math.min(height - 1, y + radius + 1);
				int subY = Math.max(0, y - radius);
				int add = src[addY * width + x];
				int sub = src[subY * width + x];

				a += ((add >>> 24) & 0xFF) - ((sub >>> 24) & 0xFF);
				r += ((add >>> 16) & 0xFF) - ((sub >>> 16) & 0xFF);
				g += ((add >>> 8) & 0xFF) - ((sub >>> 8) & 0xFF);
				b += (add & 0xFF) - (sub & 0xFF);
			}
		}
	}
}
