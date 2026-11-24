using Uno.Threading;
using Uno;
using Fuse;
using Uno.UX;
using Fuse.Scripting;
namespace Fuse.ImageTools
{

	public enum ResizeMode
	{
		IgnoreAspect = 0,
		KeepAspect = 1,
		ScaleAndCrop = 2,
		Fit = 3,
		Pad = 4
	}

	/**
		@scriptmodule FuseJS/ImageTools

		Utility methods for common Image manipulation.

		Supports resizing, cropping, rotation, flipping, EXIF auto-orientation, thumbnails, format conversion,
		compositing, color filters, Base64 and buffer encoding, and saving images to persistent application storage.

		> To use this module, add `Fuse.ImageTools` to your package references in your `.unoproj`.

		Fuse represents images as frozen JavaScript Image objects, consisting of a path, a filename, a width and a height.
		The `info` property contains metadata such as `mimeType`, `fileSize`, `orientation`, `hasAlpha`,
		`frameCount` and `isAnimated`.
		Once created or acquired, Images can be passed around to other APIs to use, fetch or alter their underlying data.
		All images are temporary "scratch images" until storage has been specified either through publishing to the CameraRoll or other.

		Transform operations accept optional `format` and `quality` options. WebP encoding is supported on Android;
		iOS and .NET targets reject `format: "webp"` because their native encoders do not support it.

		On Android 13 and newer this API requests the READ_MEDIA_IMAGES, READ_MEDIA_VIDEO and READ_MEDIA_AUDIO
		permissions. Older versions request READ_EXTERNAL_STORAGE and WRITE_EXTERNAL_STORAGE.

		## Example
		```xml
			<JavaScript>
				var ImageTools = require("FuseJS/ImageTools");
				var Observable = require("FuseJS/Observable");

				var imagePath = Observable();
				var base64Image =	"iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPAQMAAAABGAcJAAAABlBMVEX9//wAAQATpOzaAAAAH0l" +
									"EQVQI12MAAoMHIFLAAYSEwIiJgYGZASrI38AAAwBamgM5VF7xgwAAAABJRU5ErkJggg==";
				ImageTools.getImageFromBase64(base64Image)
				.then(function(image) {
					imagePath.value = image.path;
				});

				module.exports = { test: new Date().toString(), image: imagePath };
			</JavaScript>
			<Image File="{image}" />
		```
	*/
	[UXGlobalModule]
	public partial class ImageTools : NativeModule
	{

		static readonly ImageTools _instance;

		public ImageTools()
		{
			if(_instance != null) return;
			Resource.SetGlobalKey(_instance = this, "FuseJS/ImageTools");
			AddMember(new NativePromise<Image, Scripting.Object>("resize", ResizeImageInterface, Image.Converter));
			AddMember(new NativePromise<Image, Scripting.Object>("crop", CropImageInterface, Image.Converter));
			AddMember(new NativePromise<Image, Scripting.Object>("rotate", RotateImageInterface, Image.Converter));
			AddMember(new NativePromise<Image, Scripting.Object>("flip", FlipImageInterface, Image.Converter));
			AddMember(new NativePromise<Image, Scripting.Object>("autoOrient", AutoOrientImageInterface, Image.Converter));
			AddMember(new NativePromise<Image, Scripting.Object>("thumbnail", ThumbnailImageInterface, Image.Converter));
			AddMember(new NativePromise<Image, Scripting.Object>("convert", ConvertImageInterface, Image.Converter));
			AddMember(new NativePromise<Image, Scripting.Object>("composite", CompositeImageInterface, Image.Converter));
			AddMember(new NativePromise<Image, Scripting.Object>("filter", FilterImageInterface, Image.Converter));
			AddMember(new NativePromise<Image, Scripting.Object>("drawText", DrawTextImageInterface, Image.Converter));
			AddMember(new NativePromise<byte[], Scripting.Object>("getPixelBuffer", PixelBufferInterface, null));
			AddMember(new NativePromise<Image, Scripting.Object>("save", SaveImageInterface, Image.Converter));
			AddMember(new NativePromise<Image, Scripting.Object>("getImageInfo", GetImageInfoInterface, Image.InfoConverter));
			AddMember(new NativePromise<bool, Scripting.Object>("delete", DeleteImageInterface, null));
			AddMember(new NativePromise<bool, Scripting.Object>("clearCache", ClearCacheInterface, null));
			AddMember(new NativePromise<Image, Scripting.Object>("getImageFromBase64", ImageFromBase64Interface, Image.Converter));
			AddMember(new NativePromise<Image, Scripting.Object>("getImageFromUri", ImageFromUriInterface, Image.Converter));
			AddMember(new NativePromise<string, Scripting.Object>("getBase64FromImage", Base64FromImageInterface, null));
			AddMember(new NativePromise<Image, Scripting.Object>("getImageFromBuffer", ImageFromBufferInterface, Image.Converter));
			AddMember(new NativePromise<byte[], Scripting.Object>("getBufferFromImage", BufferFromImageInterface, null));
			AddMember(new NativeProperty<object, int>("IGNORE_ASPECT", ResizeMode.IgnoreAspect));
			AddMember(new NativeProperty<object, int>("KEEP_ASPECT", ResizeMode.KeepAspect));
			AddMember(new NativeProperty<object, int>("SCALE_AND_CROP", ResizeMode.ScaleAndCrop));
			AddMember(new NativeProperty<object, int>("FIT", ResizeMode.Fit));
			AddMember(new NativeProperty<object, int>("PAD", ResizeMode.Pad));
		}

		public static Image ImageFromByteArray(byte[] bytes)
		{
			if defined(Android)
			{
				sbyte[] sbytes = new sbyte[bytes.Length];
				for(var i = 0; i<bytes.Length; i++)
					sbytes[i] = (sbyte) bytes[i];
				return new Image(AndroidImageUtils.GetImageFromBufferSync(sbytes));
			}
			else if defined(iOS)
			{
				return new Image(iOSImageUtils.GetImageFromBufferSync(bytes));
			}
			else
			{
				debug_log("ImageFromByteArray not supported on current platform.");
				return null;
			}
		}

		public static Future<Image> Resize(Image img, int desiredWidth, int desiredHeight, ResizeMode mode, bool inPlace = true, string format = null, int quality = 90, int background = -1)
		{
			var p = new Promise<Image>();
			var closure = new ImagePromiseCallback(p);
			if defined(Android)
			{
				new ResizeCommand(img.Path, desiredWidth, desiredHeight, (int)mode, format, quality, background, closure.Resolve, closure.Reject, inPlace).Execute();
			}
			else if defined(iOS)
			{
				iOSImageUtils.Resize(img.Path, desiredWidth, desiredHeight, (int)mode, format, quality, background, closure.Resolve, closure.Reject, inPlace);
			}
			else if defined(dotnet)
			{
				DotNetImageUtils.Resize(img.Path, desiredWidth, desiredHeight, (int)mode, format, quality, background, closure.Resolve, closure.Reject, inPlace);
			}
			else
			{
				closure.Reject("Unsupported platform");
			}
			return p;
		}

		public static Future<Image> Crop(Image img, int width, int height, int x, int y, bool inPlace = true, string format = null, int quality = 90)
		{
			var p = new Promise<Image>();
			var closure = new ImagePromiseCallback(p);
			if defined(Android)
				new CropCommand(img.Path, x, y, width, height, format, quality, closure.Resolve, closure.Reject, inPlace).Execute();
			else if defined(iOS)
				iOSImageUtils.Crop(img.Path, x, y, width, height, format, quality, closure.Resolve, closure.Reject, inPlace);
			else if defined(dotnet)
				DotNetImageUtils.Crop(img.Path, x, y, width, height, format, quality, closure.Resolve, closure.Reject, inPlace);
			else
				closure.Reject("Unsupported platform");
			return p;
		}

		public static Future<Image> Rotate(Image img, double degrees, string format = null, int quality = 90, bool inPlace = true)
		{
			var p = new Promise<Image>();
			var closure = new ImagePromiseCallback(p);
			if defined(Android)
				new RotateCommand(img.Path, degrees, format, quality, closure.Resolve, closure.Reject, inPlace).Execute();
			else if defined(iOS)
				iOSImageUtils.Rotate(img.Path, degrees, format, quality, closure.Resolve, closure.Reject, inPlace);
			else if defined(dotnet)
				DotNetImageUtils.Rotate(img.Path, degrees, format, quality, closure.Resolve, closure.Reject, inPlace);
			else
				closure.Reject("Unsupported platform");
			return p;
		}

		public static Future<Image> Flip(Image img, bool horizontal, bool vertical, string format = null, int quality = 90, bool inPlace = true)
		{
			var p = new Promise<Image>();
			var closure = new ImagePromiseCallback(p);
			if defined(Android)
				new FlipCommand(img.Path, horizontal, vertical, format, quality, closure.Resolve, closure.Reject, inPlace).Execute();
			else if defined(iOS)
				iOSImageUtils.Flip(img.Path, horizontal, vertical, format, quality, closure.Resolve, closure.Reject, inPlace);
			else if defined(dotnet)
				DotNetImageUtils.Flip(img.Path, horizontal, vertical, format, quality, closure.Resolve, closure.Reject, inPlace);
			else
				closure.Reject("Unsupported platform");
			return p;
		}

		public static Future<Image> AutoOrient(Image img, string format = null, int quality = 90, bool inPlace = true)
		{
			var p = new Promise<Image>();
			var closure = new ImagePromiseCallback(p);
			if defined(Android)
				new AutoOrientCommand(img.Path, format, quality, closure.Resolve, closure.Reject, inPlace).Execute();
			else if defined(iOS)
				iOSImageUtils.AutoOrient(img.Path, format, quality, closure.Resolve, closure.Reject, inPlace);
			else if defined(dotnet)
				DotNetImageUtils.AutoOrient(img.Path, format, quality, closure.Resolve, closure.Reject, inPlace);
			else
				closure.Reject("Unsupported platform");
			return p;
		}

		public static Future<Image> Thumbnail(Image img, int maxWidth, int maxHeight, string format = null, int quality = 90)
		{
			var p = new Promise<Image>();
			var closure = new ImagePromiseCallback(p);
			if defined(Android)
				new ThumbnailCommand(img.Path, maxWidth, maxHeight, format, quality, closure.Resolve, closure.Reject).Execute();
			else if defined(iOS)
				iOSImageUtils.Thumbnail(img.Path, maxWidth, maxHeight, format, quality, closure.Resolve, closure.Reject);
			else if defined(dotnet)
				DotNetImageUtils.Thumbnail(img.Path, maxWidth, maxHeight, format, quality, closure.Resolve, closure.Reject);
			else
				closure.Reject("Unsupported platform");
			return p;
		}

		public static Future<Image> Convert(Image img, string format = null, int quality = 90, bool inPlace = true)
		{
			var p = new Promise<Image>();
			var closure = new ImagePromiseCallback(p);
			if defined(Android)
				new ConvertCommand(img.Path, format, quality, closure.Resolve, closure.Reject, inPlace).Execute();
			else if defined(iOS)
				iOSImageUtils.Convert(img.Path, format, quality, closure.Resolve, closure.Reject, inPlace);
			else if defined(dotnet)
				DotNetImageUtils.Convert(img.Path, format, quality, closure.Resolve, closure.Reject, inPlace);
			else
				closure.Reject("Unsupported platform");
			return p;
		}

		public static Future<Image> Composite(Image img, Image overlay, int x, int y, double opacity, string format = null, int quality = 90, bool inPlace = true)
		{
			var p = new Promise<Image>();
			var closure = new ImagePromiseCallback(p);
			if defined(Android)
				new CompositeCommand(img.Path, overlay.Path, x, y, opacity, format, quality, closure.Resolve, closure.Reject, inPlace).Execute();
			else if defined(iOS)
				iOSImageUtils.Composite(img.Path, overlay.Path, x, y, opacity, format, quality, closure.Resolve, closure.Reject, inPlace);
			else if defined(dotnet)
				DotNetImageUtils.Composite(img.Path, overlay.Path, x, y, opacity, format, quality, closure.Resolve, closure.Reject, inPlace);
			else
				closure.Reject("Unsupported platform");
			return p;
		}

		public static Future<Image> Filter(Image img, string type, double amount, int radius, string format = null, int quality = 90, bool inPlace = true)
		{
			var p = new Promise<Image>();
			var closure = new ImagePromiseCallback(p);
			if defined(Android)
				new FilterCommand(img.Path, type, amount, radius, format, quality, closure.Resolve, closure.Reject, inPlace).Execute();
			else if defined(iOS)
				iOSImageUtils.Filter(img.Path, type, amount, radius, format, quality, closure.Resolve, closure.Reject, inPlace);
			else if defined(dotnet)
				DotNetImageUtils.Filter(img.Path, type, amount, radius, format, quality, closure.Resolve, closure.Reject, inPlace);
			else
				closure.Reject("Unsupported platform");
			return p;
		}

		public static Future<Image> DrawText(Image img, string text, int x, int y, float fontSize, string font, int color, string format = null, int quality = 90, bool inPlace = true)
		{
			var p = new Promise<Image>();
			var closure = new ImagePromiseCallback(p);
			if defined(Android)
				new DrawTextCommand(img.Path, text, x, y, fontSize, font, color, format, quality, closure.Resolve, closure.Reject, inPlace).Execute();
			else if defined(iOS)
				iOSImageUtils.DrawText(img.Path, text, x, y, fontSize, font, color, format, quality, closure.Resolve, closure.Reject, inPlace);
			else if defined(dotnet)
				DotNetImageUtils.DrawText(img.Path, text, x, y, fontSize, font, color, format, quality, closure.Resolve, closure.Reject, inPlace);
			else
				closure.Reject("Unsupported platform");
			return p;
		}

		public static Future<byte[]> GetPixelBuffer(Image img)
		{
			var p = new Promise<byte[]>();
			try
			{
				if defined(Android)
				{
					var signed = AndroidImageUtils.GetPixelBuffer(img.Path);
					if(signed == null)
						throw new Exception("Could not read pixel buffer");

					var bytes = new byte[signed.Length];
					for(int i = 0; i < signed.Length; i++)
						bytes[i] = (byte)signed[i];

					p.Resolve(bytes);
				}
				else if defined(iOS)
					p.Resolve(iOSImageUtils.GetPixelBuffer(img.Path));
				else if defined(dotnet)
					p.Resolve(DotNetImageUtils.GetPixelBuffer(img.Path));
				else
					p.Reject(new Exception("Unsupported platform"));
			}
			catch(Exception e)
			{
				p.Reject(e);
			}
			return p;
		}

		public static Future<Image> Save(Image img, string directory, string name, string format = null, int quality = 90)
		{
			var p = new Promise<Image>();
			var closure = new ImagePromiseCallback(p);
			if defined(Android)
				new SaveCommand(img.Path, directory, name, format, quality, closure.Resolve, closure.Reject).Execute();
			else if defined(iOS)
				iOSImageUtils.Save(img.Path, directory, name, format, quality, closure.Resolve, closure.Reject);
			else if defined(dotnet)
				DotNetImageUtils.Save(img.Path, directory, name, format, quality, closure.Resolve, closure.Reject);
			else
				closure.Reject("Unsupported platform");
			return p;
		}

		extern(Android) void ClearCache()
		{
			AndroidImageUtils.ClearCache();
		}

		extern(iOS) void ClearCache()
		{
			iOSImageUtils.ClearCache();
		}

		extern(!Mobile && !DOTNET) void ClearCache() { }

		extern(DOTNET) void ClearCache()
		{
			DotNetImageUtils.ClearCache();
		}

		public static Future<string> ImageToBase64(Image img)
		{
			return ImageToBase64(img, null, 90);
		}

		public static Future<string> ImageToBase64(Image img, string format, int quality)
		{
			var p = new Promise<string>();
			var closure = new PromiseCallback<string>(p);
			if defined(Android)
				new GetBase64Command(img.Path, format, quality, closure.Resolve, closure.Reject).Execute();
			else if defined(iOS)
				iOSImageUtils.GetBase64FromImage(img.Path, format, quality, closure.Resolve, closure.Reject);
			else if defined(dotnet)
				DotNetImageUtils.GetBase64FromImage(img.Path, format, quality, closure.Resolve, closure.Reject);
			else
				closure.Reject("Unsupported platform");
			return p;
		}

		public static Future<Image> ImageFromUri(string uri)
		{
			var p = new Promise<Image>();
			var closure = new ImagePromiseCallback(p);
			if defined(Android)
				new ImageFromUriCommand(uri, closure.Resolve, closure.Reject).Execute();
			else if defined(iOS)
				iOSImageUtils.GetImageFromUri(uri, closure.Resolve, closure.Reject);
			else if defined(dotnet)
				DotNetImageUtils.GetImageFromUri(uri, closure.Resolve, closure.Reject);
			else
				closure.Reject("Unsupported platform");
			return p;
		}

		public static Future<Image> ImageFromBase64(string b64)
		{
			var p = new Promise<Image>();
			var closure = new ImagePromiseCallback(p);
			if defined(Android)
				new ImageFromBase64Command(b64, closure.Resolve, closure.Reject).Execute();
			else if defined(iOS)
				iOSImageUtils.GetImageFromBase64(b64, closure.Resolve, closure.Reject);
			else if defined(dotnet)
				DotNetImageUtils.GetImageFromBase64(b64, closure.Resolve, closure.Reject);
			else
				closure.Reject("Unsupported platform");
			return p;
		}

	}
}
