package com.fuse.camera;

import android.content.ContentResolver;
import android.database.Cursor;
import android.net.Uri;
import android.os.Environment;
import android.provider.MediaStore;
import android.util.Log;
import android.graphics.Bitmap;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import android.webkit.MimeTypeMap;
import java.util.UUID;

public class ImageStorageTools {
	public static void clearCache()
	{
		try{
			File[] files = new File(getTempFileDir()).listFiles();
			if(files == null)
				return;

			for(File f : files){
				if(f.getName().startsWith("IMG_"))
					f.delete();
			}
		}catch(Exception e){
			e.printStackTrace();
		}
	}

	public static String getFileName(String path)
	{
		return path.substring(path.lastIndexOf(File.separator)+1);
	}

	static void copyStream(InputStream in, OutputStream out) throws Exception
	{
		byte[] buffer = new byte[1024];
		int read;
		while ((read = in.read(buffer)) != -1)
			out.write(buffer, 0, read);

		in.close();
		out.flush();
		out.close();
	}

	public static Image copyImage(File inputFile, File targetFile, boolean move) throws Exception
	{
		copyStream(new FileInputStream(inputFile), new FileOutputStream(targetFile));

		if(move)
			inputFile.delete();

		return Image.fromPath(targetFile.getAbsolutePath());
	}

	static String getAppName()
	{
		//android - uses default app name in title, can override by defining title, fallback to package name if title set to nothing
		return ("@(project.title)" != "") ? "@(project.title)" : com.fuse.Activity.getRootActivity().getPackageName();
	}

	public static Image saveBitmapAndGetImage(Bitmap bmp, boolean temp, Bitmap.CompressFormat fmt) throws Exception
	{
		return saveBitmapAndGetImage(bmp, temp, fmt, 100);
	}

	public static Image saveBitmapAndGetImage(Bitmap bmp, boolean temp, Bitmap.CompressFormat fmt, int quality) throws Exception
	{
		String ext;
		if (fmt == Bitmap.CompressFormat.PNG)
			ext = "png";
		else if (fmt == Bitmap.CompressFormat.WEBP)
			ext = "webp";
		else
			ext = "jpg";

		File f = new File(createFilePath(ext, temp));
		ImageUtils.writeBitmap(bmp, f, ext, quality);

		Image image = Image.fromPath(f.getAbsolutePath());
		image.setDims(bmp.getWidth(), bmp.getHeight());
		bmp.recycle();
		return image;
	}

	public static String createFilePath(String ext, boolean temp) throws Exception
	{
		return getOutputMediaFile(temp, getImageFileName(ext)).getAbsolutePath();
	}

	public static String getTempFileDir()
	{
		File cacheDir = com.fuse.Activity.getRootActivity().getExternalCacheDir();
		if (cacheDir == null)
			cacheDir = com.fuse.Activity.getRootActivity().getCacheDir();

		return new File(cacheDir, "images").getAbsolutePath();
	}

	public static String getDocumentsFileDir()
	{
		File dir = new File(com.fuse.Activity.getRootActivity().getFilesDir(), "images");
		if (!dir.exists() && !dir.mkdirs())
			throw new RuntimeException("Failed to create application directory: " + dir.getAbsolutePath());
		return dir.getAbsolutePath();
	}

	public static File getSaveFilePath(String directory, String name, String extension) throws Exception
	{
		File dir = "temp".equals(directory)
			? new File(getTempFileDir())
			: new File(getDocumentsFileDir());

		if (!dir.exists() && !dir.mkdirs())
			throw new Exception("Failed to create directory: " + dir.getAbsolutePath());

		String fileName = (name == null || name.length() == 0)
			? getImageFileName(extension)
			: ensureExtension(name, extension);

		File file = new File(dir, fileName);
		if (!file.exists())
			return file;

		String base = fileName.substring(0, fileName.length() - extension.length() - 1);
		for (int i = 1; i < 1000; i++) {
			File candidate = new File(dir, base + "-" + i + "." + extension);
			if (!candidate.exists())
				return candidate;
		}

		throw new Exception("Could not create a unique file name for: " + name);
	}

	static String ensureExtension(String name, String extension)
	{
		int dot = name.lastIndexOf('.');
		String base = dot > 0 ? name.substring(0, dot) : name;
		return base + "." + extension;
	}

	public static File getOutputMediaFile(boolean temp, String fileName) throws Exception {
		File mediaStorageDir;
		if(temp)
			mediaStorageDir = new File(getTempFileDir());
		else
			mediaStorageDir = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), getAppName());

		if (!mediaStorageDir.exists()) {
			if (!mediaStorageDir.mkdirs()) {
				Log.e(getAppName(), "failed to create directory");
				throw new Exception("Failed to create application directory for: "+getAppName());
			}
		}

		return new File(mediaStorageDir.getAbsolutePath() + File.separator + fileName);
	}

	public static String getImageFileName(String extension)
	{
		return "IMG_" + UUID.randomUUID().toString() + "." + extension;
	}

	public static String getMimeType(Uri uriImage)
	{
		ContentResolver cr = com.fuse.Activity.getRootActivity().getContentResolver();
		String strMimeType = null;
		Cursor cursor = cr.query(uriImage,
												new String[] { MediaStore.MediaColumns.MIME_TYPE },
												null, null, null);

		if (cursor != null && cursor.moveToNext())
		{
			strMimeType = cursor.getString(0);
		}

		return strMimeType;
	}

	public static Image createScratchFromUri(Uri contentUri) throws Exception
	{
		String type = getMimeType(contentUri);
		String ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(type);
		String name = getImageFileName(ext);
		File outFile = getOutputMediaFile(true, name);
		ContentResolver cr = com.fuse.Activity.getRootActivity().getContentResolver();
		copyStream(cr.openInputStream(contentUri), new FileOutputStream(outFile));
		return Image.fromUri(Uri.fromFile(outFile));
	}
}
