package com.fuse.mediapicker;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.util.Log;
import androidx.annotation.Nullable;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.Locale;

class ImageResizer {
	private final File externalFilesDirectory;
	private final ExifDataCopier exifDataCopier;

	ImageResizer(File externalFilesDirectory, ExifDataCopier exifDataCopier) {
		this.externalFilesDirectory = externalFilesDirectory;
		this.exifDataCopier = exifDataCopier;
	}

	/** Resizes/re-encodes when needed; returns the original path when no work is required. */
	String resizeImageIfNeeded(
			String imagePath,
			@Nullable Double maxWidth,
			@Nullable Double maxHeight,
			@Nullable Integer imageQuality) {
		if (imagePath == null || imagePath.isEmpty())
			return null;

		double maxW = (maxWidth != null && maxWidth > 0) ? maxWidth : 0;
		double maxH = (maxHeight != null && maxHeight > 0) ? maxHeight : 0;
		// Also re-encode formats Fuse's texture loader cannot display.
		boolean shouldRecompress = isImageQualityValid(imageQuality) || !isCompatibleImage(imagePath);

		if (maxW == 0 && maxH == 0 && !shouldRecompress)
			return imagePath;

		BitmapFactory.Options bounds = new BitmapFactory.Options();
		bounds.inJustDecodeBounds = true;
		BitmapFactory.decodeFile(imagePath, bounds);

		int originalWidth = bounds.outWidth;
		int originalHeight = bounds.outHeight;
		if (originalWidth <= 0 || originalHeight <= 0)
			return null;

		double scale = 1.0;
		if (maxW > 0)
			scale = Math.min(scale, maxW / originalWidth);
		if (maxH > 0)
			scale = Math.min(scale, maxH / originalHeight);

		boolean shouldDownscale = scale < 1.0;
		if (!shouldDownscale && !shouldRecompress)
			return imagePath;

		int targetWidth = shouldDownscale
				? Math.max(1, (int)Math.round(originalWidth * scale))
				: originalWidth;
		int targetHeight = shouldDownscale
				? Math.max(1, (int)Math.round(originalHeight * scale))
				: originalHeight;

		try {
			Bitmap bmp = decodeFile(imagePath, originalWidth, originalHeight, targetWidth, targetHeight);
			if (bmp == null)
				return null;

			Bitmap scaledBmp = bmp;
			if (bmp.getWidth() != targetWidth || bmp.getHeight() != targetHeight)
				scaledBmp = Bitmap.createScaledBitmap(bmp, targetWidth, targetHeight, true);

			int quality = isImageQualityValid(imageQuality) ? imageQuality : 100;
			File file = writeImage(outputImageName(imagePath, scaledBmp.hasAlpha()), scaledBmp, quality);
			exifDataCopier.copyExif(imagePath, file.getPath());

			if (scaledBmp != bmp)
				bmp.recycle();
			scaledBmp.recycle();

			return file.getPath();
		} catch (IOException e) {
			throw new RuntimeException(e);
		} catch (OutOfMemoryError e) {
			Log.e("ImageResizer", "media_picker: could not resize image: out of memory");
			return null;
		}
	}

	private Bitmap decodeFile(String path, int originalWidth, int originalHeight, int targetWidth, int targetHeight) {
		BitmapFactory.Options options = new BitmapFactory.Options();
		options.inSampleSize = calculateInSampleSize(originalWidth, originalHeight, targetWidth, targetHeight);
		return BitmapFactory.decodeFile(path, options);
	}

	private int calculateInSampleSize(int width, int height, int targetWidth, int targetHeight) {
		if (width <= 0 || height <= 0 || targetWidth <= 0 || targetHeight <= 0)
			return 1;

		int inSampleSize = 1;
		while ((width / (inSampleSize * 2)) >= targetWidth
				&& (height / (inSampleSize * 2)) >= targetHeight)
			inSampleSize *= 2;

		return inSampleSize;
	}

	private File createFile(String child) {
		File image = new File(externalFilesDirectory, child);
		if (!image.getParentFile().exists())
			image.getParentFile().mkdirs();
		return image;
	}


	private boolean isImageQualityValid(Integer imageQuality) {
		return imageQuality != null && imageQuality > 0 && imageQuality < 100;
	}

	private boolean isCompatibleImage(String path) {
		String lower = path.toLowerCase(Locale.US);
		return lower.endsWith(".jpg") || lower.endsWith(".jpeg") || lower.endsWith(".png");
	}

	private String outputImageName(String path, boolean hasAlpha) {
		String name = new File(path).getName();
		int dot = name.lastIndexOf('.');
		if (dot > 0)
			name = name.substring(0, dot);
		return "scaled_" + name + (hasAlpha ? ".png" : ".jpg");
	}

	private File writeImage(String name, Bitmap bitmap, int imageQuality) throws IOException {
		ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
		boolean saveAsPNG = bitmap.hasAlpha();
		if (saveAsPNG && isImageQualityValid(imageQuality)) {
			Log.d("ImageResizer", "media_picker: PNG compression ignores imageQuality");
		}
		bitmap.compress(
				saveAsPNG ? Bitmap.CompressFormat.PNG : Bitmap.CompressFormat.JPEG,
				imageQuality,
				outputStream);

		File imageFile = createFile(name);
		try (FileOutputStream fileOutput = new FileOutputStream(imageFile)) {
			outputStream.writeTo(fileOutput);
		}
		return imageFile;
	}
}
