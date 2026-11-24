package com.fuse.camera;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.media.ExifInterface;
import android.net.Uri;
import android.util.Base64;

import java.io.File;
import java.io.FileOutputStream;
import java.io.ByteArrayOutputStream;
import java.util.Locale;

public class ImageUtils {

	public enum ResizeMode
	{
		IGNORE_ASPECT,
		KEEP_ASPECT,
		SCALE_AND_CROP,
		FIT,
		PAD
	}

	// ---------------------------------------------------------------------
	// Format handling
	// ---------------------------------------------------------------------

	static int clampQuality(int quality) {
		return Math.max(0, Math.min(100, quality));
	}

	static String normalizeFormat(String format, String mime) {
		if (format != null) {
			format = format.toLowerCase(Locale.ROOT);
			if (format.equals("jpeg"))
				format = "jpg";
			if (format.equals("jpg") || format.equals("png") || format.equals("webp"))
				return format;
			throw new IllegalArgumentException("Unsupported image format: " + format);
		}

		return formatFromMime(mime);
	}

	static String formatFromMime(String mime) {
		if (mime == null)
			return "jpg";

		mime = mime.toLowerCase(Locale.ROOT);
		if (mime.contains("png"))
			return "png";
		if (mime.contains("webp"))
			return "webp";
		if (mime.contains("jpeg") || mime.contains("jpg"))
			return "jpg";
		if (mime.contains("gif"))
			return "png";
		if (mime.contains("heic") || mime.contains("heif"))
			return "jpg";
		return "jpg";
	}

	static Bitmap.CompressFormat compressFormatFor(String format) {
		if ("png".equals(format))
			return Bitmap.CompressFormat.PNG;
		if ("webp".equals(format))
			return Bitmap.CompressFormat.WEBP;
		return Bitmap.CompressFormat.JPEG;
	}

	static String extensionFor(String format) {
		if ("png".equals(format))
			return "png";
		if ("webp".equals(format))
			return "webp";
		return "jpg";
	}

	static String getExtension(String path) {
		int i = path.lastIndexOf('.');
		return i >= 0 ? path.substring(i + 1).toLowerCase(Locale.ROOT) : "";
	}

	static boolean extensionMatches(String path, String format) {
		String ext = getExtension(path);
		if ("jpg".equals(format))
			return ext.equals("jpg") || ext.equals("jpeg");
		return ext.equals(format);
	}

	static String getMimeType(String path) {
		BitmapFactory.Options options = new BitmapFactory.Options();
		options.inJustDecodeBounds = true;
		BitmapFactory.decodeFile(path, options);
		return options.outMimeType;
	}

	// ---------------------------------------------------------------------
	// Decoding / orientation
	// ---------------------------------------------------------------------

	static int readOrientation(String path) {
		try {
			return new ExifInterface(path).getAttributeInt(
					ExifInterface.TAG_ORIENTATION,
					ExifInterface.ORIENTATION_NORMAL);
		} catch (Exception e) {
			return ExifInterface.ORIENTATION_NORMAL;
		}
	}

	static Matrix orientationMatrix(int orientation) {
		Matrix matrix = new Matrix();
		switch (orientation) {
			case ExifInterface.ORIENTATION_FLIP_HORIZONTAL:
				matrix.setScale(-1, 1);
				break;
			case ExifInterface.ORIENTATION_ROTATE_180:
				matrix.setRotate(180);
				break;
			case ExifInterface.ORIENTATION_FLIP_VERTICAL:
				matrix.setScale(1, -1);
				break;
			case ExifInterface.ORIENTATION_TRANSPOSE:
				matrix.setRotate(90);
				matrix.postScale(-1, 1);
				break;
			case ExifInterface.ORIENTATION_ROTATE_90:
				matrix.setRotate(90);
				break;
			case ExifInterface.ORIENTATION_TRANSVERSE:
				matrix.setRotate(-90);
				matrix.postScale(-1, 1);
				break;
			case ExifInterface.ORIENTATION_ROTATE_270:
				matrix.setRotate(-90);
				break;
			default:
				return null;
		}
		return matrix;
	}

	static Bitmap decodeFileSampled(String path, int reqWidth, int reqHeight) throws Exception {
		BitmapFactory.Options bounds = new BitmapFactory.Options();
		bounds.inJustDecodeBounds = true;
		BitmapFactory.decodeFile(path, bounds);

		BitmapFactory.Options options = new BitmapFactory.Options();
		if (reqWidth > 0 && reqHeight > 0)
			options.inSampleSize = Image.calculateInSampleSize(bounds, reqWidth, reqHeight);

		Bitmap bitmap = BitmapFactory.decodeFile(path, options);
		if (bitmap == null)
			throw new Exception("Could not decode image: " + path);
		return bitmap;
	}

	static Bitmap decodeOriented(String path, int reqWidth, int reqHeight) throws Exception {
		Bitmap bitmap = decodeFileSampled(path, reqWidth, reqHeight);
		Matrix matrix = orientationMatrix(readOrientation(path));
		if (matrix == null)
			return bitmap;

		Bitmap oriented = Bitmap.createBitmap(
				bitmap, 0, 0, bitmap.getWidth(), bitmap.getHeight(), matrix, true);
		if (oriented != bitmap)
			bitmap.recycle();
		return oriented;
	}

	// ---------------------------------------------------------------------
	// Encoding
	// ---------------------------------------------------------------------

	static Image writeResult(Image inImage, Bitmap bitmap, String format, int quality, boolean performInPlace) throws Exception {
		String fmt = normalizeFormat(format, getMimeType(inImage.getFilePath()));

		File target;
		if (performInPlace && extensionMatches(inImage.getFilePath(), fmt)) {
			target = inImage.getFile();
		} else {
			target = new File(ImageStorageTools.createFilePath(extensionFor(fmt), true));
		}

		writeBitmap(bitmap, target, fmt, quality);

		Image result = Image.fromPath(target.getAbsolutePath());
		result.setDims(bitmap.getWidth(), bitmap.getHeight());
		return result;
	}

	static void writeBitmap(Bitmap bitmap, File target, String format, int quality) throws Exception {
		Bitmap.CompressFormat compressFormat = compressFormatFor(format);
		int q = clampQuality(quality);

		FileOutputStream out = new FileOutputStream(target);
		try {
			if (!bitmap.compress(compressFormat, q, out))
				throw new Exception("Failed to encode image as " + format);
			out.flush();
		} finally {
			out.close();
		}
	}

	static Image writeAndRecycle(Image inImage, Bitmap source, Bitmap result, String format, int quality, boolean performInPlace) throws Exception {
		try {
			return writeResult(inImage, result, format, quality, performInPlace);
		} finally {
			if (result != source)
				result.recycle();
			if (!source.isRecycled())
				source.recycle();
		}
	}

	// ---------------------------------------------------------------------
	// Operations
	// ---------------------------------------------------------------------

	public static Image crop(Image inImage, int width, int height, int x, int y, int quality, String format, boolean performInPlace) throws Exception {
		Bitmap source = decodeOriented(inImage.getFilePath(), 0, 0);

		int left = Math.max(0, x);
		int top = Math.max(0, y);
		int w = Math.min(width, source.getWidth() - left);
		int h = Math.min(height, source.getHeight() - top);

		if (w <= 0 || h <= 0) {
			source.recycle();
			throw new Exception("Crop rectangle is outside image bounds");
		}

		Bitmap result = Bitmap.createBitmap(source, left, top, w, h);
		return writeAndRecycle(inImage, source, result, format, quality, performInPlace);
	}

	public static Image resize(Image inImage, int desiredWidth, int desiredHeight, ResizeMode mode, int quality, String format, int background, boolean performInPlace) throws Exception {
		if (desiredWidth <= 0 || desiredHeight <= 0)
			throw new Exception("desiredWidth and desiredHeight must be larger than 0");

		int originalOrientation = readOrientation(inImage.getFilePath());
		Bitmap source = decodeOriented(inImage.getFilePath(), desiredWidth, desiredHeight);
		int sourceWidth = source.getWidth();
		int sourceHeight = source.getHeight();

		Bitmap result;

		switch (mode) {
			case KEEP_ASPECT: {
				float ratio = 1.0f;
				if (sourceWidth > desiredWidth)
					ratio = (float)desiredWidth / sourceWidth;
				if (sourceHeight * ratio > desiredHeight)
					ratio = (float)desiredHeight / sourceHeight;

				int w = Math.max(1, Math.round(sourceWidth * ratio));
				int h = Math.max(1, Math.round(sourceHeight * ratio));
				result = Bitmap.createScaledBitmap(source, w, h, true);
				break;
			}
			case SCALE_AND_CROP: {
				// Scale to cover the target bounds, then crop the center.
				float ratio = Math.max(
						(float)desiredWidth / sourceWidth,
						(float)desiredHeight / sourceHeight);

				int w = Math.max(1, Math.round(sourceWidth * ratio));
				int h = Math.max(1, Math.round(sourceHeight * ratio));
				Bitmap scaled = Bitmap.createScaledBitmap(source, w, h, true);
				int left = Math.max(0, (w - desiredWidth) / 2);
				int top = Math.max(0, (h - desiredHeight) / 2);
				result = Bitmap.createBitmap(
						scaled, left, top,
						Math.min(desiredWidth, w), Math.min(desiredHeight, h));
				if (scaled != source && scaled != result)
					scaled.recycle();
				break;
			}
			case FIT: {
				float ratio = Math.min(
						(float)desiredWidth / sourceWidth,
						(float)desiredHeight / sourceHeight);
				int w = Math.max(1, Math.round(sourceWidth * ratio));
				int h = Math.max(1, Math.round(sourceHeight * ratio));
				result = Bitmap.createScaledBitmap(source, w, h, true);
				break;
			}
			case PAD: {
				float ratio = Math.min(
						(float)desiredWidth / sourceWidth,
						(float)desiredHeight / sourceHeight);
				int w = Math.max(1, Math.round(sourceWidth * ratio));
				int h = Math.max(1, Math.round(sourceHeight * ratio));

				Bitmap scaled = Bitmap.createScaledBitmap(source, w, h, true);
				Bitmap padded = Bitmap.createBitmap(desiredWidth, desiredHeight, Bitmap.Config.ARGB_8888);
				Canvas canvas = new Canvas(padded);
				canvas.drawColor(background == -1 ? 0xFFFFFFFF : background);
				canvas.drawBitmap(scaled, (desiredWidth - w) / 2.0f, (desiredHeight - h) / 2.0f, null);

				if (scaled != source && scaled != padded)
					scaled.recycle();

				result = padded;
				break;
			}
			default:
				result = Bitmap.createScaledBitmap(source, desiredWidth, desiredHeight, true);
				break;
		}

		if (result == source && format == null && originalOrientation == ExifInterface.ORIENTATION_NORMAL) {
			source.recycle();
			return inImage;
		}

		return writeAndRecycle(inImage, source, result, format, quality, performInPlace);
	}

	public static Image rotate(Image inImage, double degrees, int quality, String format, boolean performInPlace) throws Exception {
		degrees = degrees % 360.0;
		if (degrees < 0)
			degrees += 360.0;

		Bitmap source = decodeOriented(inImage.getFilePath(), 0, 0);

		if (degrees == 0 && format == null) {
			source.recycle();
			return inImage;
		}

		Bitmap result = source;
		if (degrees != 0) {
			Matrix matrix = new Matrix();
			matrix.setRotate((float)degrees);
			result = Bitmap.createBitmap(
					source, 0, 0, source.getWidth(), source.getHeight(), matrix, true);
		}

		return writeAndRecycle(inImage, source, result, format, quality, performInPlace);
	}

	public static Image flip(Image inImage, boolean horizontal, boolean vertical, int quality, String format, boolean performInPlace) throws Exception {
		Bitmap source = decodeOriented(inImage.getFilePath(), 0, 0);

		Matrix matrix = new Matrix();
		matrix.setScale(horizontal ? -1 : 1, vertical ? -1 : 1);
		Bitmap result = Bitmap.createBitmap(
				source, 0, 0, source.getWidth(), source.getHeight(), matrix, true);

		return writeAndRecycle(inImage, source, result, format, quality, performInPlace);
	}

	public static Image autoOrient(Image inImage, int quality, String format, boolean performInPlace) throws Exception {
		Bitmap source = decodeFileSampled(inImage.getFilePath(), 0, 0);
		Matrix matrix = orientationMatrix(readOrientation(inImage.getFilePath()));

		if (matrix == null && format == null) {
			source.recycle();
			return inImage;
		}

		Bitmap result = source;
		if (matrix != null) {
			result = Bitmap.createBitmap(
					source, 0, 0, source.getWidth(), source.getHeight(), matrix, true);
		}

		return writeAndRecycle(inImage, source, result, format, quality, performInPlace);
	}

	public static Image convert(Image inImage, String format, int quality, boolean performInPlace) throws Exception {
		Bitmap source = decodeOriented(inImage.getFilePath(), 0, 0);
		return writeAndRecycle(inImage, source, source, format, quality, performInPlace);
	}

	public static Image thumbnail(Image inImage, int maxWidth, int maxHeight, String format, int quality) throws Exception {
		if (maxWidth <= 0 && maxHeight <= 0)
			throw new Exception("maxWidth and/or maxHeight must be larger than 0");

		int reqWidth = maxWidth > 0 ? maxWidth : maxHeight;
		int reqHeight = maxHeight > 0 ? maxHeight : maxWidth;
		Bitmap source = decodeOriented(inImage.getFilePath(), reqWidth, reqHeight);

		try {
			int sourceWidth = source.getWidth();
			int sourceHeight = source.getHeight();

			float ratio = 1.0f;
			if (maxWidth > 0)
				ratio = Math.min(ratio, (float)maxWidth / sourceWidth);
			if (maxHeight > 0)
				ratio = Math.min(ratio, (float)maxHeight / sourceHeight);
			ratio = Math.min(ratio, 1.0f);

			int width = Math.max(1, Math.round(sourceWidth * ratio));
			int height = Math.max(1, Math.round(sourceHeight * ratio));
			Bitmap result = Bitmap.createScaledBitmap(source, width, height, true);

			try {
				String fmt = normalizeFormat(format, getMimeType(inImage.getFilePath()));
				File target = new File(ImageStorageTools.createFilePath(extensionFor(fmt), true));
				writeBitmap(result, target, fmt, quality);

				Image outImage = Image.fromPath(target.getAbsolutePath());
				outImage.setDims(result.getWidth(), result.getHeight());
				return outImage;
			} finally {
				if (result != source)
					result.recycle();
			}
		} finally {
			if (!source.isRecycled())
				source.recycle();
		}
	}

	public static Image save(Image inImage, String directory, String name, String format, int quality) throws Exception {
		Bitmap source = decodeOriented(inImage.getFilePath(), 0, 0);

		try {
			String selectedFormat = format;
			if ((selectedFormat == null || selectedFormat.length() == 0) && name != null) {
				int dot = name.lastIndexOf('.');
				if (dot >= 0 && dot < name.length() - 1) {
					String extension = name.substring(dot + 1).toLowerCase(Locale.ROOT);
					if (extension.equals("jpeg") || extension.equals("jpg") ||
							extension.equals("png") || extension.equals("webp"))
						selectedFormat = extension;
				}
			}

			String fmt = normalizeFormat(selectedFormat, getMimeType(inImage.getFilePath()));
			File target = ImageStorageTools.getSaveFilePath(directory, name, extensionFor(fmt));

			writeBitmap(source, target, fmt, quality);

			Image outImage = Image.fromPath(target.getAbsolutePath());
			outImage.setDims(source.getWidth(), source.getHeight());
			return outImage;
		} finally {
			source.recycle();
		}
	}

	public static Image composite(Image inImage, String overlayPath, int x, int y, float opacity, String format, int quality, boolean performInPlace) throws Exception {
		Bitmap base = decodeOriented(inImage.getFilePath(), 0, 0);
		Bitmap overlay = null;

		try {
			overlay = decodeOriented(overlayPath, 0, 0);

			Bitmap result = Bitmap.createBitmap(base.getWidth(), base.getHeight(), Bitmap.Config.ARGB_8888);
			Canvas canvas = new Canvas(result);
			canvas.drawBitmap(base, 0, 0, null);

			Paint paint = new Paint();
			paint.setAlpha(Math.round(Math.max(0.0f, Math.min(1.0f, opacity)) * 255.0f));
			canvas.drawBitmap(overlay, x, y, paint);

			return writeAndRecycle(inImage, base, result, format, quality, performInPlace);
		} finally {
			if (overlay != null && !overlay.isRecycled())
				overlay.recycle();
			if (!base.isRecycled())
				base.recycle();
		}
	}

	public static Image filter(Image inImage, String type, float amount, int radius, String format, int quality, boolean performInPlace) throws Exception {
		Bitmap source = decodeOriented(inImage.getFilePath(), 0, 0);

		try {
			Bitmap result = "blur".equals(type)
				? ImageFilters.boxBlur(source, Math.max(1, radius))
				: ImageFilters.applyColorMatrix(source, type, amount);

			return writeAndRecycle(inImage, source, result, format, quality, performInPlace);
		} finally {
			if (!source.isRecycled())
				source.recycle();
		}
	}


	public static Image fromUri(String uriString) throws Exception {
		if (uriString == null || uriString.length() == 0)
			throw new Exception("URI must not be empty");

		if (uriString.startsWith("content://"))
			return ImageStorageTools.createScratchFromUri(Uri.parse(uriString));

		String path = uriString;
		if (uriString.startsWith("file:")) {
			path = Uri.parse(uriString).getPath();
			if (path == null)
				throw new Exception("Invalid file URI: " + uriString);
		}

		File file = new File(path);
		if (!file.exists())
			throw new Exception("File not found: " + path);

		return Image.fromPath(path);
	}

	public static Image drawText(Image inImage, String text, int x, int y, float fontSize, String font, int color, String format, int quality, boolean performInPlace) throws Exception {
		Bitmap source = decodeOriented(inImage.getFilePath(), 0, 0);

		Bitmap result = Bitmap.createBitmap(source.getWidth(), source.getHeight(), Bitmap.Config.ARGB_8888);
		Canvas canvas = new Canvas(result);
		canvas.drawBitmap(source, 0, 0, null);

		Paint paint = new Paint();
		paint.setAntiAlias(true);
		paint.setTextSize(fontSize);
		paint.setColor(color);

		if (font != null && font.length() > 0)
			paint.setTypeface(Typeface.create(font, Typeface.NORMAL));
		else
			paint.setTypeface(Typeface.DEFAULT);

		Paint.FontMetrics metrics = paint.getFontMetrics();
		canvas.drawText(text, x, y - metrics.ascent, paint);

		return writeAndRecycle(inImage, source, result, format, quality, performInPlace);
	}

	public static byte[] getPixelBuffer(Image inImage) throws Exception {
		Bitmap source = decodeOriented(inImage.getFilePath(), 0, 0);

			try {
			int width = source.getWidth();
			int height = source.getHeight();
			long bufferSize = (long)width * height * 4;
			if (bufferSize > Integer.MAX_VALUE)
				throw new Exception("Image is too large for a pixel buffer");

			int[] pixels = new int[width * height];
			source.getPixels(pixels, 0, width, 0, 0, width, height);

			boolean premultiplied = source.isPremultiplied();
			byte[] rgba = new byte[(int)bufferSize];
			int index = 0;

			for (int pixel : pixels) {
				int a = (pixel >>> 24) & 0xFF;
				int r = (pixel >> 16) & 0xFF;
				int g = (pixel >> 8) & 0xFF;
				int b = pixel & 0xFF;

				if (premultiplied && a > 0 && a < 255) {
					r = Math.min(255, r * 255 / a);
					g = Math.min(255, g * 255 / a);
					b = Math.min(255, b * 255 / a);
				}

				rgba[index++] = (byte)r;
				rgba[index++] = (byte)g;
				rgba[index++] = (byte)b;
				rgba[index++] = (byte)a;
			}

			return rgba;
		} finally {
			source.recycle();
		}
	}


	public static byte[] getImageBytes(Image inImage, String format, int quality) throws Exception {
		Bitmap bitmap = decodeOriented(inImage.getFilePath(), 0, 0);
		String fmt = normalizeFormat(format, getMimeType(inImage.getFilePath()));
		Bitmap.CompressFormat compressFormat = compressFormatFor(fmt);

		try {
			ByteArrayOutputStream out = new ByteArrayOutputStream();
			bitmap.compress(compressFormat, clampQuality(quality), out);
			return out.toByteArray();
		} finally {
			bitmap.recycle();
		}
	}

	public static String getBase64FromImage(Image inImage, String format, int quality) throws Exception {
		return Base64.encodeToString(getImageBytes(inImage, format, quality), Base64.NO_WRAP);
	}
}
