package com.fuse.mediapicker;

import android.content.Context;
import android.net.Uri;
import android.webkit.MimeTypeMap;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

class FileUtils {

	String getPathFromUri(final Context context, final Uri uri) {
		if (uri == null)
			return null;

		File file = null;
		InputStream inputStream = null;
		OutputStream outputStream = null;
		boolean success = false;
		try {
			String extension = getMediaExtension(context, uri);
			inputStream = context.getContentResolver().openInputStream(uri);
			file = File.createTempFile("media_picker", extension, context.getCacheDir());
			outputStream = new FileOutputStream(file);
			if (inputStream != null) {
				copy(inputStream, outputStream);
				success = true;
			}
		} catch (IOException ignored) {
		} catch (SecurityException ignored) {
		} finally {
			try {
				if (inputStream != null) inputStream.close();
			} catch (IOException ignored) {
			}
			try {
				if (outputStream != null) outputStream.close();
			} catch (IOException ignored) {
				// If closing the output stream fails, we cannot be sure that the
				// target file was written in full. Flushing the stream merely moves
				// the bytes into the OS, not necessarily to the file.
				success = false;
			}
		}

		if (!success && file != null)
			file.delete();

		return success ? file.getPath() : null;
	}

	private static String getMediaExtension(Context context, Uri uri) {
		String extension = null;

		try {
			String mimeType = context.getContentResolver().getType(uri);
			if (mimeType != null) {
				extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType);
			}

			if (extension == null || extension.isEmpty()) {
				String path = uri.getPath();
				if (path != null)
					extension = MimeTypeMap.getFileExtensionFromUrl(path);
			}
		} catch (Exception e) {
			extension = null;
		}

		if (extension == null || extension.isEmpty()) {
			// Default extension matching the previous behavior of the package.
			extension = "jpg";
		}

		return "." + extension;
	}

	private static void copy(InputStream in, OutputStream out) throws IOException {
		final byte[] buffer = new byte[4 * 1024];
		int bytesRead;
		while ((bytesRead = in.read(buffer)) != -1) {
			out.write(buffer, 0, bytesRead);
		}
		out.flush();
	}
}
