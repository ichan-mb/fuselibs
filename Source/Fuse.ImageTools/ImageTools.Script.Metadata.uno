using Uno.Threading;
using Uno;
using Fuse;
using Fuse.Scripting;
using Fuse.Scripting.JSObjectUtils;

namespace Fuse.ImageTools
{
	public partial class ImageTools
	{
		/**
			@scriptmethod getImageInfo(image)
			@param image (Object) The image to inspect
			@return (Promise) a Promise of an object describing the image

			Returns metadata about an image without modifying it. The returned object contains
			`path`, `name`, `width`, `height`, `mimeType`, `fileSize`, `orientation`, `hasAlpha`,
			`frameCount`, `isAnimated`, and an `exif` object with common EXIF fields when available.

			## Example
			```js
				var ImageTools = require("FuseJS/ImageTools");
				ImageTools.getImageInfo(originalImage).then(function(info) {
					console.log(info.width + "x" + info.height + " " + info.mimeType);
				});
			```
		*/
		Future<Image> GetImageInfoInterface(Context c, object[] args)
		{
			var p = new Promise<Image>();
			if(args.Length != 1)
			{
				p.Reject(new Exception("getImageInfo takes 1 argument: An Image"));
				return p;
			}

			var image = Image.FromObject(args[0]);
			if(image == null)
				p.Reject(new Exception("Invalid image reference"));
			else
				p.Resolve(image);

			return p;
		}

		/**
			@scriptmethod delete(image)
			@param image (Object) The image to delete
			@return (Promise) a Promise of a boolean

			Deletes the underlying file of an image. Only use this on scratch images that are no longer needed.

			## Example
			```js
				var ImageTools = require("FuseJS/ImageTools");
				ImageTools.delete(image).then(function() { console.log("Image deleted"); });
			```
		*/
		Future<bool> DeleteImageInterface(Context c, object[] args)
		{
			var p = new Promise<bool>();
			if(args.Length != 1)
			{
				p.Reject(new Exception("delete takes 1 argument: An Image"));
				return p;
			}

			var image = Image.FromObject(args[0]);
			if(image == null)
			{
				p.Reject(new Exception("Invalid image reference"));
				return p;
			}

			return Delete(image);
		}

		public static Future<bool> Delete(Image img)
		{
			var p = new Promise<bool>();
			try
			{
				if(Uno.IO.File.Exists(img.Path))
					Uno.IO.File.Delete(img.Path);
				p.Resolve(true);
			}
			catch(Exception e)
			{
				p.Reject(e);
			}
			return p;
		}

		/**
			@scriptmethod clearCache()
			@return (Promise) a Promise of a boolean

			Deletes all temporary images created by Fuse.ImageTools.
		*/
		Future<bool> ClearCacheInterface(Context c, object[] args)
		{
			var p = new Promise<bool>();
			try
			{
				ClearCache();
				p.Resolve(true);
			}
			catch(Exception e)
			{
				p.Reject(e);
			}
			return p;
		}

		static string ReadFormat(Scripting.Object opts)
		{
			if(opts == null)
				return null;

			var format = opts.ValueOrDefault<string>("format", null);
			if(format == null)
				return null;

			format = format.ToLower();
			if(format == "jpeg")
				format = "jpg";

			if(format != "jpg" && format != "png" && format != "webp")
				throw new Exception("format must be one of \"jpeg\", \"png\" or \"webp\"");

			return format;
		}

		static int ReadQuality(Scripting.Object opts)
		{
			if(opts == null)
				return 90;

			var quality = opts.ValueOrDefault<double>("quality", 90.0);
			if(quality > 0 && quality <= 1.0)
				quality *= 100.0;

			if(quality < 0)
				quality = 0;
			if(quality > 100)
				quality = 100;

			return (int)Math.Round(quality);
		}

		static int ReadBackground(Scripting.Object opts)
		{
			return ReadColor(opts, "background", -1);
		}

		static int ReadColor(Scripting.Object opts, string key, int defaultValue)
		{
			if(opts == null)
				return defaultValue;

			var raw = opts.ValueOrDefault<double>(key, (double)defaultValue);
			long value = (long)raw;

			if(value == 0L)
				return 0;

			// Accept both 0xRRGGBB and 0xAARRGGBB.
			if(value <= 0xFFFFFFL)
				value |= 0xFF000000L;

			int a = (int)((value >> 24) & 0xFFL);
			int r = (int)((value >> 16) & 0xFFL);
			int g = (int)((value >> 8) & 0xFFL);
			int b = (int)(value & 0xFFL);

			return (a << 24) | (r << 16) | (g << 8) | b;
		}
	}
}
