using Uno.Threading;
using Uno;
using Uno.Compiler.ExportTargetInterop;
using Android;
namespace Fuse.ImageTools
{
	[ForeignInclude(Language.Java, "java.lang.Thread", "java.lang.Runnable", "java.util.Locale", "android.util.Log", "android.provider.MediaStore", "android.graphics.BitmapFactory", "android.media.ExifInterface", "java.io.File", "com.fuse.Activity", "com.fuse.camera.Image", "com.fuse.camera.ImageUtils", "com.fuse.camera.ImageStorageTools", "android.content.Intent")]
	extern (Android) static internal class AndroidImageUtils
	{

		public static int2 GetSize(Image inImage)
		{
			var size = new int[2] {0, 0};
			GetSizeInternal(inImage.Path, size);
			return int2(size[0], size[1]);
		}

		[Foreign(Language.Java)]
		static void GetSizeInternal(string path, int[] values)
		@{
			try{
				Image inImage = Image.fromPath(path);
				values.set(0, inImage.getWidth());
				values.set(1, inImage.getHeight());
			}catch(Exception e){
			}
		@}

		[Foreign(Language.Java)]
		public static string GetMimeType(string path)
		@{
			try{
				BitmapFactory.Options options = new BitmapFactory.Options();
				options.inJustDecodeBounds = true;
				BitmapFactory.decodeFile(path, options);
				return options.outMimeType != null ? options.outMimeType : "";
			}catch(Exception e){
				return "";
			}
		@}

		[Foreign(Language.Java)]
		public static long GetFileSize(string path)
		@{
			try{
				return new File(path).length();
			}catch(Exception e){
				return 0L;
			}
		@}

		[Foreign(Language.Java)]
		public static int GetOrientation(string path)
		@{
			try{
				ExifInterface exif = new ExifInterface(path);
				return exif.getAttributeInt(
					ExifInterface.TAG_ORIENTATION,
					ExifInterface.ORIENTATION_NORMAL);
			}catch(Exception e){
				return ExifInterface.ORIENTATION_NORMAL;
			}
		@}

		[Foreign(Language.Java)]
		public static bool HasAlpha(string path)
		@{
			try{
				BitmapFactory.Options options = new BitmapFactory.Options();
				options.inJustDecodeBounds = true;
				BitmapFactory.decodeFile(path, options);
				String mime = options.outMimeType != null
					? options.outMimeType.toLowerCase(Locale.ROOT)
					: "";
				return mime.contains("png") || mime.contains("gif") ||
					mime.contains("webp") || mime.contains("heic") || mime.contains("heif");
			}catch(Exception e){
				return false;
			}
		@}

		[Foreign(Language.Java)]
		public static int GetFrameCount(string path)
		@{
			try{
				return ImageFrameCounter.getFrameCount(path);
			}catch(Exception e){
				return 1;
			}
		@}

		[Foreign(Language.Java)]
		public static string GetExif(string path)
		@{
			try{
				ExifInterface exif = new ExifInterface(path);
				StringBuilder sb = new StringBuilder();

				String value = exif.getAttribute(ExifInterface.TAG_DATETIME);
				if (value != null && value.length() > 0) sb.append("dateTime\t").append(value).append('\n');
				value = exif.getAttribute(ExifInterface.TAG_MAKE);
				if (value != null && value.length() > 0) sb.append("make\t").append(value).append('\n');
				value = exif.getAttribute(ExifInterface.TAG_MODEL);
				if (value != null && value.length() > 0) sb.append("model\t").append(value).append('\n');
				value = exif.getAttribute(ExifInterface.TAG_ISO_SPEED_RATINGS);
				if (value != null && value.length() > 0) sb.append("iso\t").append(value).append('\n');
				value = exif.getAttribute(ExifInterface.TAG_F_NUMBER);
				if (value != null && value.length() > 0) sb.append("fNumber\t").append(value).append('\n');
				value = exif.getAttribute(ExifInterface.TAG_EXPOSURE_TIME);
				if (value != null && value.length() > 0) sb.append("exposureTime\t").append(value).append('\n');
				value = exif.getAttribute(ExifInterface.TAG_FOCAL_LENGTH);
				if (value != null && value.length() > 0) sb.append("focalLength\t").append(value).append('\n');
				value = exif.getAttribute(ExifInterface.TAG_FLASH);
				if (value != null && value.length() > 0) sb.append("flash\t").append(value).append('\n');

				float[] latitudeLongitude = new float[2];
				if (exif.getLatLong(latitudeLongitude)) {
					sb.append("gpsLatitude\t").append(Float.toString(latitudeLongitude[0])).append('\n');
					sb.append("gpsLongitude\t").append(Float.toString(latitudeLongitude[1])).append('\n');
				}

				value = exif.getAttribute(ExifInterface.TAG_GPS_ALTITUDE);
				if (value != null && value.length() > 0) sb.append("gpsAltitude\t").append(value).append('\n');

				return sb.toString();
			}catch(Exception e){
				return "";
			}
		@}

		[Foreign(Language.Java)]
		public static void ClearCache()
		@{
			ImageStorageTools.clearCache();
		@}

		[Foreign(Language.Java)]
		public static void Resize(string path, int width, int height, int mode, string format, int quality, int background, Action<string> onSuccess, Action<string> onFail, bool performInPlace = true)
		@{
			final Image inImage = Image.fromPath(path);
			Thread t = new Thread(new Runnable() { public void run() {
					try{
						Image outImage = ImageUtils.resize(inImage, width, height, ImageUtils.ResizeMode.values()[mode], quality, format, background, performInPlace);
						onSuccess.run(outImage.getFilePath());
					}catch(Exception e){
						onFail.run(e.getMessage());
						e.printStackTrace();
					}
			}});
			t.start();
		@}

		[Foreign(Language.Java)]
		public static void GetImageFromBuffer(sbyte[] bytes, Action<string> onSuccess, Action<string> onFail)
		@{
			Thread t = new Thread(new Runnable() { public void run() {
				try{
					byte[] bitmapdata = bytes.copyArray();
					Image outImage = Image.fromBytes(bitmapdata);
					onSuccess.run(outImage.getFilePath());
				}catch(Exception e){
					onFail.run(e.getMessage());
				}
			}});
			t.start();
		@}

		[Foreign(Language.Java)]
		public static string GetImageFromBufferSync(sbyte[] bytes)
		@{
			try{
				byte[] bitmapdata = bytes.copyArray();
				Image outImage = Image.fromBytes(bitmapdata);
				return outImage.getFilePath();
			}catch(Exception e){
				e.printStackTrace();
				return null;
			}
		@}

		[Foreign(Language.Java)]
		public static void Crop(string path, int width, int height, int x, int y, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool performInPlace = true)
		@{
			final Image inImage = Image.fromPath(path);
			Thread t = new Thread(new Runnable() { public void run() {
				try{
					Image outImage = ImageUtils.crop(inImage, width, height, x, y, quality, format, performInPlace);
					onSuccess.run(outImage.getFilePath());
				}catch(Exception e){
					onFail.run(e.getMessage());
					e.printStackTrace();
				}
			}});
			t.start();
		@}

		[Foreign(Language.Java)]
		public static void Rotate(string path, double degrees, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool performInPlace = true)
		@{
			final Image inImage = Image.fromPath(path);
			Thread t = new Thread(new Runnable() { public void run() {
				try{
					Image outImage = ImageUtils.rotate(inImage, degrees, quality, format, performInPlace);
					onSuccess.run(outImage.getFilePath());
				}catch(Exception e){
					onFail.run(e.getMessage());
					e.printStackTrace();
				}
			}});
			t.start();
		@}

		[Foreign(Language.Java)]
		public static void Flip(string path, bool horizontal, bool vertical, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool performInPlace = true)
		@{
			final Image inImage = Image.fromPath(path);
			Thread t = new Thread(new Runnable() { public void run() {
				try{
					Image outImage = ImageUtils.flip(inImage, horizontal, vertical, quality, format, performInPlace);
					onSuccess.run(outImage.getFilePath());
				}catch(Exception e){
					onFail.run(e.getMessage());
					e.printStackTrace();
				}
			}});
			t.start();
		@}

		[Foreign(Language.Java)]
		public static void AutoOrient(string path, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool performInPlace = true)
		@{
			final Image inImage = Image.fromPath(path);
			Thread t = new Thread(new Runnable() { public void run() {
				try{
					Image outImage = ImageUtils.autoOrient(inImage, quality, format, performInPlace);
					onSuccess.run(outImage.getFilePath());
				}catch(Exception e){
					onFail.run(e.getMessage());
					e.printStackTrace();
				}
			}});
			t.start();
		@}

		[Foreign(Language.Java)]
		public static void Thumbnail(string path, int maxWidth, int maxHeight, string format, int quality, Action<string> onSuccess, Action<string> onFail)
		@{
			final Image inImage = Image.fromPath(path);
			Thread t = new Thread(new Runnable() { public void run() {
				try{
					Image outImage = ImageUtils.thumbnail(inImage, maxWidth, maxHeight, format, quality);
					onSuccess.run(outImage.getFilePath());
				}catch(Exception e){
					onFail.run(e.getMessage());
					e.printStackTrace();
				}
			}});
			t.start();
		@}

		[Foreign(Language.Java)]
		public static void Convert(string path, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool performInPlace = true)
		@{
			final Image inImage = Image.fromPath(path);
			Thread t = new Thread(new Runnable() { public void run() {
				try{
					Image outImage = ImageUtils.convert(inImage, format, quality, performInPlace);
					onSuccess.run(outImage.getFilePath());
				}catch(Exception e){
					onFail.run(e.getMessage());
					e.printStackTrace();
				}
			}});
			t.start();
		@}

		[Foreign(Language.Java)]
		public static void Save(string path, string directory, string name, string format, int quality, Action<string> onSuccess, Action<string> onFail)
		@{
			final Image inImage = Image.fromPath(path);
			Thread t = new Thread(new Runnable() { public void run() {
				try{
					Image outImage = ImageUtils.save(inImage, directory, name, format, quality);
					onSuccess.run(outImage.getFilePath());
				}catch(Exception e){
					onFail.run(e.getMessage());
					e.printStackTrace();
				}
			}});
			t.start();
		@}

		[Foreign(Language.Java)]
		public static void Composite(string path, string overlayPath, int x, int y, double opacity, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool performInPlace = true)
		@{
			final Image inImage = Image.fromPath(path);
			Thread t = new Thread(new Runnable() { public void run() {
				try{
					Image outImage = ImageUtils.composite(inImage, overlayPath, x, y, (float)opacity, format, quality, performInPlace);
					onSuccess.run(outImage.getFilePath());
				}catch(Exception e){
					onFail.run(e.getMessage());
					e.printStackTrace();
				}
			}});
			t.start();
		@}

		[Foreign(Language.Java)]
		public static void Filter(string path, string type, double amount, int radius, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool performInPlace = true)
		@{
			final Image inImage = Image.fromPath(path);
			Thread t = new Thread(new Runnable() { public void run() {
				try{
					Image outImage = ImageUtils.filter(inImage, type, (float)amount, radius, format, quality, performInPlace);
					onSuccess.run(outImage.getFilePath());
				}catch(Exception e){
					onFail.run(e.getMessage());
					e.printStackTrace();
				}
			}});
			t.start();
		@}

		[Foreign(Language.Java)]
		public static void DrawText(string path, string text, int x, int y, double fontSize, string font, int color, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool performInPlace = true)
		@{
			final Image inImage = Image.fromPath(path);
			Thread t = new Thread(new Runnable() { public void run() {
				try{
					Image outImage = ImageUtils.drawText(inImage, text, x, y, (float)fontSize, font, color, format, quality, performInPlace);
					onSuccess.run(outImage.getFilePath());
				}catch(Exception e){
					onFail.run(e.getMessage());
					e.printStackTrace();
				}
			}});
			t.start();
		@}

		[Foreign(Language.Java)]
		public static sbyte[] GetPixelBuffer(string path)
		@{
			try{
				return ImageUtils.getPixelBuffer(Image.fromPath(path));
			}catch(Exception e){
				e.printStackTrace();
				return null;
			}
		@}

		[Foreign(Language.Java)]
		public static void GetImageFromUri(string uri, Action<string> onSuccess, Action<string> onFail)
		@{
			Thread t = new Thread(new Runnable() { public void run() {
				try{
					Image outImage = ImageUtils.fromUri(uri);
					onSuccess.run(outImage.getFilePath());
				}catch(Exception e){
					onFail.run(e.getMessage());
					e.printStackTrace();
				}
			}});
			t.start();
		@}

		[Foreign(Language.Java)]
		public static void GetImageFromBase64(string b64, Action<string> onSuccess, Action<string> onFail)
		@{
			Thread t = new Thread(new Runnable() { public void run() {
				try
				{
					Image outImage = Image.fromBase64(b64);
					onSuccess.run(outImage.getFilePath());
				}catch(Exception e)
				{
					onFail.run(e.getMessage());
				}
			}});
			t.start();
		@}

		[Foreign(Language.Java)]
		public static void GetBase64FromImage(string path, string format, int quality, Action<string> onSuccess, Action<string> onFail)
		@{
			Thread t = new Thread(new Runnable() { public void run() {
				try
				{
					String encoded = ImageUtils.getBase64FromImage(Image.fromPath(path), format, quality);
					onSuccess.run(encoded);
				}catch(Exception e)
				{
					onFail.run(e.getMessage());
				}
			}});
			t.start();
		@}
	}
}
