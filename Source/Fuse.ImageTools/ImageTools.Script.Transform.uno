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
			@scriptmethod resize(image, options)
			@param image (Object) The image to resize
			@param options (Object) The resize options
			@return (Promise) a Promise of an Image

			Resizes an image using the options provided, and returns a Promise of the transformed Image.

			The `options` parameter must be an object with one or more of the following properties defined:

			* `desiredWidth` - The new width in pixels
			* `desiredHeight` - The new height in pixels
			* `mode` - The resizing mode, which can be:
			  - `ImageTools.IGNORE_ASPECT` - The image is resized exactly to the desired width and height. This is the default.
			  - `ImageTools.KEEP_ASPECT`- The image is resized to within the closest size possible to the desired size while still maintaining the original aspect ratio.
			  - `ImageTools.SCALE_AND_CROP` - The image is first scaled and centered while maintaining aspect to the closest edge of the desired bounds, then cropped according to the Crop rule. This allows you to make an aspect correct square portrait out of a landscape shot, for instance.
			  - `ImageTools.FIT` - The image is scaled to fit entirely within the desired bounds while maintaining aspect ratio. The result may be smaller than the requested bounds, and may be upscaled.
			  - `ImageTools.PAD` - The image is scaled like `FIT`, then centered on a canvas of exactly the requested size, filling the remaining area with `background`.
			* `background` - Optional background color for `PAD`, as `0xAARRGGBB` or `0xRRGGBB`. Defaults to opaque white.
			* `performInPlace` - Boolean value determining whether the existing image will replaced
			* `format` - Optional output format: `"jpeg"`, `"png"` or `"webp"`. Defaults to the format of the input image.
			* `quality` - Optional output quality from 0 to 100 (or 0.0 to 1.0), used for lossy formats. Defaults to 90.

			## Example
			```js
				// Here we assume that we have an existing image variable `originalImage`
				var ImageTools = require("FuseJS/ImageTools");

				var options = {
					mode: ImageTools.IGNORE_ASPECT,
					desiredWidth: 320, //The desired width in pixels
					desiredHeight: 240 //The desired height in pixels
				};

				ImageTools.resize(originalImage, options)
					.then(function(newImage) { console.log("Path of resized image is " + newImage.path); });
			```
		*/
		Future<Image> ResizeImageInterface(Context c, object[] args)
		{
			if(args.Length!=2)
				throw new Exception("resize takes 2 arguments: An Image and an Object of options");

			var image = Image.FromObject(args[0]);
			if(image == null)
				throw new Exception("Invalid image reference");

			var opts = args[1] as Scripting.Object;
			if(opts == null)
				throw new Exception("resize requires an options object");

			var w = opts.ValueOrDefault<int>("desiredWidth", -1);
			if(w==-1)
				throw new Exception("desiredWidth must be defined");
			var h = opts.ValueOrDefault<int>("desiredHeight", w);
			var m = (ResizeMode)opts.ValueOrDefault<int>("mode", (int)ResizeMode.IgnoreAspect);
			var inPlace = opts.ValueOrDefault<bool>("performInPlace", true);
			var format = ReadFormat(opts);
			var quality = ReadQuality(opts);
			var background = ReadBackground(opts);

			return Resize(image, w, h, m, inPlace, format, quality, background);
		}

		/**
			@scriptmethod crop(image, options)
			@param image (Object) The image to crop
			@param options (Object) The crop options
			@return (Promise) a Promise of an Image

			Crops the supplied `image`, and returns a Promise of the transformed Image.

			The `options` parameter must be an object with one or more of the following properties defined:

			* `x` - X offset for cropped image, from left. Defaults to the value implied by `anchor`.
			* `y` - Y offset for cropped image, from top. Defaults to the value implied by `anchor`.
			* `width` - Width of cropped image
			* `height` - Height of cropped image. Defaults to `width` when `aspectRatio` is not specified.
			* `aspectRatio` - Optional width/height ratio. When specified, a missing `width` or `height` is derived from it; if both are missing, the largest crop with that ratio is used.
			* `anchor` - Optional crop position: `"top-left"` (default), `"top"`, `"top-right"`, `"left"`, `"center"`, `"right"`, `"bottom-left"`, `"bottom"` or `"bottom-right"`. Used when `x` and/or `y` are omitted.
			* `performInPlace` - Boolean value determining whether the existing image will replaced
			* `format` - Optional output format: `"jpeg"`, `"png"` or `"webp"`. Defaults to the format of the input image.
			* `quality` - Optional output quality from 0 to 100 (or 0.0 to 1.0), used for lossy formats. Defaults to 90.

			## Example
			```js
				// Here we assume that we have an existing image variable `originalImage`
				var ImageTools = require("FuseJS/ImageTools");

				var options = {
					width: 10, // Width of cropped image
					height: 10 // Height of cropped image
				};

				ImageTools.crop(originalImage, options)
					.then(function(newImage) { console.log("Path of cropped image is " + newImage.path); });
			```
		*/
		Future<Image> CropImageInterface(Context c, object[] args)
		{
			if(args.Length!=2)
				throw new Exception("crop takes 2 arguments: An Image and an options object");

			var image = Image.FromObject(args[0]);
			if(image == null)
				throw new Exception("Invalid image reference");

			var opts = args[1] as Scripting.Object;
			if(opts == null)
				throw new Exception("crop requires an options object");

			var width = opts.ValueOrDefault<int>("width", 0);
			var height = opts.ValueOrDefault<int>("height", 0);
			var aspectRatio = opts.ValueOrDefault<double>("aspectRatio", 0.0);
			var inPlace = opts.ValueOrDefault<bool>("performInPlace", true);

			var hasX = opts.ContainsKey("x");
			var hasY = opts.ContainsKey("y");
			var x = opts.ValueOrDefault<int>("x", 0);
			var y = opts.ValueOrDefault<int>("y", 0);

			var sourceWidth = image.Width;
			var sourceHeight = image.Height;
			if(sourceWidth <= 0 || sourceHeight <= 0)
				throw new Exception("Could not determine image size");

			if(aspectRatio > 0)
			{
				if(width > 0 && height <= 0)
					height = (int)Math.Round(width / aspectRatio);
				else if(height > 0 && width <= 0)
					width = (int)Math.Round(height * aspectRatio);
				else if(width <= 0 && height <= 0)
				{
					var sourceAspect = (double)sourceWidth / sourceHeight;
					if(sourceAspect > aspectRatio)
					{
						height = sourceHeight;
						width = (int)Math.Round(height * aspectRatio);
					}
					else
					{
						width = sourceWidth;
						height = (int)Math.Round(width / aspectRatio);
					}
				}
			}
			else if(width > 0 && height <= 0)
			{
				height = width;
			}

			if(width <= 0 || height <= 0)
				throw new Exception("width and height (or aspectRatio) must be larger than 0");

			width = Math.Min(width, sourceWidth);
			height = Math.Min(height, sourceHeight);

			if(!hasX || !hasY)
			{
				var anchor = opts.ValueOrDefault<string>("anchor", "top-left").ToLower();
				int left;
				int top;

				if(anchor == "top-left" || anchor == "left" || anchor == "bottom-left")
					left = 0;
				else if(anchor == "top" || anchor == "center" || anchor == "bottom")
					left = (sourceWidth - width) / 2;
				else if(anchor == "top-right" || anchor == "right" || anchor == "bottom-right")
					left = sourceWidth - width;
				else
					throw new Exception("Invalid anchor: " + anchor);

				if(anchor == "top-left" || anchor == "top" || anchor == "top-right")
					top = 0;
				else if(anchor == "left" || anchor == "center" || anchor == "right")
					top = (sourceHeight - height) / 2;
				else if(anchor == "bottom-left" || anchor == "bottom" || anchor == "bottom-right")
					top = sourceHeight - height;
				else
					throw new Exception("Invalid anchor: " + anchor);

				if(!hasX)
					x = left;
				if(!hasY)
					y = top;
			}

			if(x < 0) x = 0;
			if(y < 0) y = 0;
			if(x + width > sourceWidth) x = sourceWidth - width;
			if(y + height > sourceHeight) y = sourceHeight - height;

			return Crop(image, width, height, x, y, inPlace, ReadFormat(opts), ReadQuality(opts));
		}

		/**
			@scriptmethod rotate(image, options)
			@param image (Object) The image to rotate
			@param options (Object) The rotate options
			@return (Promise) a Promise of an Image

			Rotates an image clockwise by the given number of degrees, and returns a Promise of the transformed Image.

			The `options` parameter must be an object with one or more of the following properties defined:

			* `degrees` - Number of degrees to rotate clockwise. Can be any number; values are normalized to 0-360.
			* `performInPlace` - Boolean value determining whether the existing image will be replaced
			* `format` - Optional output format: `"jpeg"`, `"png"` or `"webp"`. Defaults to the format of the input image.
			* `quality` - Optional output quality from 0 to 100 (or 0.0 to 1.0), used for lossy formats. Defaults to 90.

			## Example
			```js
				var ImageTools = require("FuseJS/ImageTools");
				ImageTools.rotate(originalImage, { degrees: 90 })
					.then(function(newImage) { console.log("Path of rotated image is " + newImage.path); });
			```
		*/
		Future<Image> RotateImageInterface(Context c, object[] args)
		{
			if(args.Length!=2)
				throw new Exception("rotate takes 2 arguments: An Image and an Object of options");

			var image = Image.FromObject(args[0]);
			if(image == null)
				throw new Exception("Invalid image reference");

			var opts = args[1] as Scripting.Object;
			if(opts == null)
				throw new Exception("rotate requires an options object");

			var degrees = opts.ValueOrDefault<double>("degrees", 0.0);
			var inPlace = opts.ValueOrDefault<bool>("performInPlace", true);

			return Rotate(image, degrees, ReadFormat(opts), ReadQuality(opts), inPlace);
		}

		/**
			@scriptmethod flip(image, options)
			@param image (Object) The image to flip
			@param options (Object) The flip options
			@return (Promise) a Promise of an Image

			Flips an image horizontally and/or vertically, and returns a Promise of the transformed Image.

			The `options` parameter must be an object with one or more of the following properties defined:

			* `horizontal` - Boolean value determining whether the image is flipped horizontally
			* `vertical` - Boolean value determining whether the image is flipped vertically
			* `performInPlace` - Boolean value determining whether the existing image will be replaced
			* `format` - Optional output format: `"jpeg"`, `"png"` or `"webp"`. Defaults to the format of the input image.
			* `quality` - Optional output quality from 0 to 100 (or 0.0 to 1.0), used for lossy formats. Defaults to 90.

			## Example
			```js
				var ImageTools = require("FuseJS/ImageTools");
				ImageTools.flip(originalImage, { horizontal: true })
					.then(function(newImage) { console.log("Path of flipped image is " + newImage.path); });
			```
		*/
		Future<Image> FlipImageInterface(Context c, object[] args)
		{
			if(args.Length!=2)
				throw new Exception("flip takes 2 arguments: An Image and an Object of options");

			var image = Image.FromObject(args[0]);
			if(image == null)
				throw new Exception("Invalid image reference");

			var opts = args[1] as Scripting.Object;
			if(opts == null)
				throw new Exception("flip requires an options object");

			var horizontal = opts.ValueOrDefault<bool>("horizontal", false);
			var vertical = opts.ValueOrDefault<bool>("vertical", false);
			if(!horizontal && !vertical)
				throw new Exception("flip requires at least one of horizontal or vertical to be true");

			var inPlace = opts.ValueOrDefault<bool>("performInPlace", true);

			return Flip(image, horizontal, vertical, ReadFormat(opts), ReadQuality(opts), inPlace);
		}

		/**
			@scriptmethod autoOrient(image, options)
			@param image (Object) The image to orient
			@param options (Object) Optional options
			@return (Promise) a Promise of an Image

			Applies the image's EXIF orientation so that its pixel data matches the way it is displayed.
			Resize and crop already apply EXIF orientation automatically, so this is mainly useful when you
			want to normalize an image without changing its dimensions.

			The optional `options` object may contain:

			* `performInPlace` - Boolean value determining whether the existing image will be replaced
			* `format` - Optional output format: `"jpeg"`, `"png"` or `"webp"`. Defaults to the format of the input image.
			* `quality` - Optional output quality from 0 to 100 (or 0.0 to 1.0), used for lossy formats. Defaults to 90.
		*/
		Future<Image> AutoOrientImageInterface(Context c, object[] args)
		{
			if(args.Length < 1 || args.Length > 2)
				throw new Exception("autoOrient takes 1 or 2 arguments: An Image and an optional options object");

			var image = Image.FromObject(args[0]);
			if(image == null)
				throw new Exception("Invalid image reference");

			var opts = args.Length == 2 ? args[1] as Scripting.Object : null;
			var inPlace = opts != null ? opts.ValueOrDefault<bool>("performInPlace", true) : true;

			return AutoOrient(image, ReadFormat(opts), ReadQuality(opts), inPlace);
		}

		/**
			@scriptmethod thumbnail(image, options)
			@param image (Object) The image to create a thumbnail from
			@param options (Object) The thumbnail options
			@return (Promise) a Promise of an Image

			Creates a new thumbnail that fits within `maxWidth` and `maxHeight` while preserving the
			aspect ratio. Thumbnails never upscale, and always return a new image.

			The `options` parameter must define at least one of:

			* `maxWidth` - Maximum width in pixels
			* `maxHeight` - Maximum height in pixels
			* `format` - Optional output format: `"jpeg"`, `"png"` or `"webp"`. Defaults to the format of the input image.
			* `quality` - Optional output quality from 0 to 100 (or 0.0 to 1.0). Defaults to 90.

			## Example
			```js
				var ImageTools = require("FuseJS/ImageTools");
				ImageTools.thumbnail(originalImage, { maxWidth: 256, maxHeight: 256 })
					.then(function(thumb) { console.log("Thumbnail size: " + thumb.width + "x" + thumb.height); });
			```
		*/
		Future<Image> ThumbnailImageInterface(Context c, object[] args)
		{
			if(args.Length!=2)
				throw new Exception("thumbnail takes 2 arguments: An Image and an Object of options");

			var image = Image.FromObject(args[0]);
			if(image == null)
				throw new Exception("Invalid image reference");

			var opts = args[1] as Scripting.Object;
			if(opts == null)
				throw new Exception("thumbnail requires an options object");

			var maxWidth = opts.ValueOrDefault<int>("maxWidth", 0);
			var maxHeight = opts.ValueOrDefault<int>("maxHeight", 0);
			if(maxWidth <= 0 && maxHeight <= 0)
				throw new Exception("thumbnail requires maxWidth and/or maxHeight to be larger than 0");

			return Thumbnail(image, maxWidth, maxHeight, ReadFormat(opts), ReadQuality(opts));
		}

		/**
			@scriptmethod convert(image, options)
			@param image (Object) The image to convert
			@param options (Object) The conversion options
			@return (Promise) a Promise of an Image

			Re-encodes an image without changing its dimensions. This can be used to change the
			image format or to adjust the compression quality.

			The optional `options` object may contain:

			* `format` - Output format: `"jpeg"`, `"png"` or `"webp"`. Defaults to the format of the input image.
			* `quality` - Output quality from 0 to 100 (or 0.0 to 1.0). Defaults to 90.
			* `performInPlace` - Boolean value determining whether the existing image will be replaced

			## Example
			```js
				var ImageTools = require("FuseJS/ImageTools");
				ImageTools.convert(originalImage, { format: "jpeg", quality: 80 })
					.then(function(converted) { console.log("Converted image: " + converted.path); });
			```
		*/
		Future<Image> ConvertImageInterface(Context c, object[] args)
		{
			if(args.Length < 1 || args.Length > 2)
				throw new Exception("convert takes 1 or 2 arguments: An Image and an optional options object");

			var image = Image.FromObject(args[0]);
			if(image == null)
				throw new Exception("Invalid image reference");

			var opts = args.Length == 2 ? args[1] as Scripting.Object : null;
			var inPlace = opts != null ? opts.ValueOrDefault<bool>("performInPlace", true) : true;

			return Convert(image, ReadFormat(opts), ReadQuality(opts), inPlace);
		}

		/**
			@scriptmethod save(image, options)
			@param image (Object) The image to save
			@param options (Object) Optional save options
			@return (Promise) a Promise of an Image

			Saves an image to persistent application storage (or the temporary directory) and returns
			a new Image pointing to the saved file. The image is re-encoded and EXIF orientation is applied.

			The optional `options` object may contain:

			* `directory` - `"documents"` (default) or `"temp"`
			* `name` - Optional file name. A unique suffix is added if the file already exists.
			* `format` - Output format: `"jpeg"`, `"png"` or `"webp"`. Defaults to the input format or the name's extension.
			* `quality` - Output quality from 0 to 100 (or 0.0 to 1.0). Defaults to 90.

			## Example
			```js
				var ImageTools = require("FuseJS/ImageTools");
				ImageTools.save(image, { name: "profile", format: "jpeg" })
					.then(function(saved) { console.log("Saved to " + saved.path); });
			```
		*/
		Future<Image> SaveImageInterface(Context c, object[] args)
		{
			if(args.Length < 1 || args.Length > 2)
				throw new Exception("save takes 1 or 2 arguments: An Image and an optional options object");

			var image = Image.FromObject(args[0]);
			if(image == null)
				throw new Exception("Invalid image reference");

			var opts = args.Length == 2 ? args[1] as Scripting.Object : null;
			var directory = opts != null ? opts.ValueOrDefault<string>("directory", "documents") : "documents";
			if(directory != "documents" && directory != "temp")
				throw new Exception("directory must be \"documents\" or \"temp\"");

			var name = opts != null ? opts.ValueOrDefault<string>("name", null) : null;
			if(name != null && (name.Contains("/") || name.Contains("\\")))
				throw new Exception("name must not contain path separators");

			return Save(image, directory, name, ReadFormat(opts), ReadQuality(opts));
		}

		/**
			@scriptmethod composite(image, overlay, options)
			@param image (Object) The base image
			@param overlay (Object) The image to draw on top of the base image
			@param options (Object) Optional composite options
			@return (Promise) a Promise of an Image

			Draws `overlay` on top of `image` and returns the combined Image. This can be used for
			watermarks, logos and simple image composition.

			The optional `options` object may contain:

			* `x` - X position of the overlay, from the top-left of the base image. Defaults to 0.
			* `y` - Y position of the overlay, from the top-left of the base image. Defaults to 0.
			* `opacity` - Overlay opacity from 0 to 1. Defaults to 1.
			* `performInPlace` - Boolean value determining whether the base image will be replaced. Defaults to true.
			* `format` - Optional output format: `"jpeg"`, `"png"` or `"webp"`.
			* `quality` - Optional output quality from 0 to 100 (or 0.0 to 1.0). Defaults to 90.

			## Example
			```js
				var ImageTools = require("FuseJS/ImageTools");
				ImageTools.composite(photo, logo, { x: 16, y: 16, opacity: 0.8 })
					.then(function(result) { console.log("Composited: " + result.path); });
			```
		*/
		Future<Image> CompositeImageInterface(Context c, object[] args)
		{
			if(args.Length < 2 || args.Length > 3)
				throw new Exception("composite takes 2 or 3 arguments: A base Image, an overlay Image and an optional Object of options");

			var image = Image.FromObject(args[0]);
			var overlay = Image.FromObject(args[1]);
			if(image == null || overlay == null)
				throw new Exception("Invalid image reference");

			var opts = args.Length == 3 ? args[2] as Scripting.Object : null;

			var x = opts != null ? opts.ValueOrDefault<int>("x", 0) : 0;
			var y = opts != null ? opts.ValueOrDefault<int>("y", 0) : 0;
			var opacity = opts != null ? opts.ValueOrDefault<double>("opacity", 1.0) : 1.0;
			if(opacity < 0) opacity = 0;
			if(opacity > 1) opacity = 1;

			var inPlace = opts != null ? opts.ValueOrDefault<bool>("performInPlace", true) : true;

			return Composite(image, overlay, x, y, opacity, ReadFormat(opts), ReadQuality(opts), inPlace);
		}

		/**
			@scriptmethod filter(image, options)
			@param image (Object) The image to filter
			@param options (Object) The filter options
			@return (Promise) a Promise of an Image

			Applies a color filter to an image.

			The `options` object must contain:

			* `type` - One of `"grayscale"`, `"sepia"`, `"brightness"`, `"contrast"`, `"saturation"` or `"blur"`.
			* `amount` - Filter strength from -1 to 1 for `brightness`, `contrast` and `saturation`. Defaults to 0.
			* `radius` - Blur radius in pixels for `"blur"`. Defaults to 10. Blur is supported on Android and iOS.
			* `performInPlace` - Boolean value determining whether the existing image will be replaced.
			* `format` - Optional output format: `"jpeg"`, `"png"` or `"webp"`.
			* `quality` - Optional output quality from 0 to 100 (or 0.0 to 1.0). Defaults to 90.

			## Example
			```js
				var ImageTools = require("FuseJS/ImageTools");
				ImageTools.filter(image, { type: "grayscale" })
					.then(function(result) { console.log("Filtered: " + result.path); });
			```
		*/
		Future<Image> FilterImageInterface(Context c, object[] args)
		{
			if(args.Length != 2)
				throw new Exception("filter takes 2 arguments: An Image and an Object of options");

			var image = Image.FromObject(args[0]);
			if(image == null)
				throw new Exception("Invalid image reference");

			var opts = args[1] as Scripting.Object;
			if(opts == null)
				throw new Exception("filter requires an options object");

			var type = opts.ValueOrDefault<string>("type", null);
			if(type == null)
				throw new Exception("filter requires a type");

			type = type.ToLower();
			if(type != "grayscale" && type != "sepia" && type != "brightness" &&
				type != "contrast" && type != "saturation" && type != "blur")
				throw new Exception("type must be one of \"grayscale\", \"sepia\", \"brightness\", \"contrast\", \"saturation\" or \"blur\"");

			var amount = opts.ValueOrDefault<double>("amount", 0.0);
			if(amount < -1) amount = -1;
			if(amount > 1) amount = 1;

			var radius = opts.ValueOrDefault<int>("radius", 10);
			if(type == "blur" && radius <= 0)
				throw new Exception("blur requires a radius larger than 0");

			var inPlace = opts.ValueOrDefault<bool>("performInPlace", true);

			return Filter(image, type, amount, radius, ReadFormat(opts), ReadQuality(opts), inPlace);
		}

		/**
			@scriptmethod drawText(image, options)
			@param image (Object) The image to draw on
			@param options (Object) The text options
			@return (Promise) a Promise of an Image

			Draws text on top of an image. This can be used for simple captions and text watermarks.
			The text is drawn on a single line; newline characters are not interpreted.

			The `options` object must contain:

			* `text` - The text to draw.
			* `x` - X position of the top-left of the text. Defaults to 0.
			* `y` - Y position of the top-left of the text. Defaults to 0.
			* `fontSize` - Font size in pixels. Defaults to 32.
			* `font` - Optional font family name. Defaults to the system font.
			* `color` - Text color as `0xAARRGGBB` or `0xRRGGBB`. Defaults to opaque black.
			* `performInPlace` - Boolean value determining whether the existing image will be replaced.
			* `format` - Optional output format: `"jpeg"`, `"png"` or `"webp"`.
			* `quality` - Optional output quality from 0 to 100 (or 0.0 to 1.0). Defaults to 90.

			## Example
			```js
				var ImageTools = require("FuseJS/ImageTools");
				ImageTools.drawText(image, { text: "Hello", x: 20, y: 20, fontSize: 48, color: 0xFFFFFFFF })
					.then(function(result) { console.log("Captioned: " + result.path); });
			```
		*/
		Future<Image> DrawTextImageInterface(Context c, object[] args)
		{
			if(args.Length != 2)
				throw new Exception("drawText takes 2 arguments: An Image and an Object of options");

			var image = Image.FromObject(args[0]);
			if(image == null)
				throw new Exception("Invalid image reference");

			var opts = args[1] as Scripting.Object;
			if(opts == null)
				throw new Exception("drawText requires an options object");

			var text = opts.ValueOrDefault<string>("text", null);
			if(text == null)
				throw new Exception("drawText requires text");

			var x = opts.ValueOrDefault<int>("x", 0);
			var y = opts.ValueOrDefault<int>("y", 0);
			var fontSize = (float)opts.ValueOrDefault<double>("fontSize", 32.0);
			if(fontSize <= 0)
				fontSize = 32;

			var font = opts.ValueOrDefault<string>("font", null);
			var color = ReadColor(opts, "color", -16777216); // opaque black
			var inPlace = opts.ValueOrDefault<bool>("performInPlace", true);

			return DrawText(image, text, x, y, fontSize, font, color, ReadFormat(opts), ReadQuality(opts), inPlace);
		}
	}
}
