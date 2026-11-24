package com.fuse.camera;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.util.Base64;

import java.io.File;


public class Image {

	public final static String DEFAULT_FORMAT = "jpg";
	private class Pt
	{
		public int x;
		public int y;
		public Pt(int x, int y)
		{
			this.x = x;
			this.y = y;
		}
	}

	Pt _dims;

	private Uri _fileUri;
	public Uri getFileUri()
	{
		return _fileUri;
	}

	public File getFile()
	{
		return new File(_fileUri.getPath());
	}

	public String getFileName()
	{
		return ImageStorageTools.getFileName(getFilePath());
	}

	public String getExtension()
	{
		String name = getFileName();
		int dot = name.lastIndexOf('.');
		return dot >= 0 ? name.substring(dot + 1) : "";
	}

	public String getFilePath()
	{
		return getFile().getAbsolutePath();
	}

	//ref: https://developer.android.com/topic/performance/graphics/load-bitmap
	public static int calculateInSampleSize(BitmapFactory.Options options, int reqWidth, int reqHeight) {
		// Raw height and width of image
		final int height = options.outHeight;
		final int width = options.outWidth;
		int inSampleSize = 1;

		if (height > reqHeight || width > reqWidth) {

			final int halfHeight = height / 2;
			final int halfWidth = width / 2;

			// Calculate the largest inSampleSize value that is a power of 2 and keeps both
			// height and width larger than the requested height and width.
			while ((halfHeight / inSampleSize) >= reqHeight
							&& (halfWidth / inSampleSize) >= reqWidth) {
				inSampleSize *= 2;
			}
		}

		return inSampleSize;
	}

	public void correctOrientationFromExif()
	{
		try{
			Image result = ImageUtils.autoOrient(this, 100, null, true);
			if (result != null && result != this)
				setDims(result.getWidth(), result.getHeight());
		}catch(Exception e){
			e.printStackTrace();
		}
	}

	void setDims(int width, int height)
	{
		_dims = new Pt(width, height);
	}

	public int getWidth()
	{
		checkDims();
		return _dims.x;
	}
	public int getHeight()
	{
		checkDims();
		return _dims.y;
	}

	private void checkDims()
	{
		if(_dims!=null) return;
		BitmapFactory.Options options = new BitmapFactory.Options();
		options.inJustDecodeBounds = true;
		BitmapFactory.decodeFile(_fileUri.getPath(), options);

		int orientation = ImageUtils.readOrientation(_fileUri.getPath());
		if (orientation >= 5 && orientation <= 8)
			_dims = new Pt(options.outHeight, options.outWidth);
		else
			_dims = new Pt(options.outWidth, options.outHeight);
	}

	private Image(Uri fileUri) {
		_fileUri = fileUri;
	}

	private Image() throws Exception
	{
		_fileUri = Uri.fromFile(new File(ImageStorageTools.createFilePath(DEFAULT_FORMAT, true)));
	}

	public static Image fromUri(Uri fileUri)
	{
		return new Image(fileUri);
	}

	public static Image fromPath(String filePath)
	{
		return new Image(Uri.fromFile(new File(filePath)));
	}

	public static Image fromBase64(String b64) throws Exception
	{
		byte[] decodedString = Base64.decode(stripDataUri(b64), Base64.DEFAULT);
		return fromBytes(decodedString);
	}

	static String stripDataUri(String value)
	{
		int comma = value.indexOf(',');
		if (value.startsWith("data:") && comma >= 0)
			return value.substring(comma + 1);
		return value;
	}

	public static Image fromBytes(byte[] bitmapdata) throws Exception
	{
		BitmapFactory.Options options = new BitmapFactory.Options();
		Bitmap bmp = BitmapFactory.decodeByteArray(bitmapdata, 0, bitmapdata.length, options);
		if (bmp == null)
			throw new Exception("Could not decode image data");
		String format = ImageUtils.formatFromMime(options.outMimeType);
		return ImageStorageTools.saveBitmapAndGetImage(bmp, true, ImageUtils.compressFormatFor(format), 100);
	}

	public static Image create() throws Exception
	{
		return new Image();
	}
}
