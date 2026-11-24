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
			@scriptmethod getImageFromBuffer(imageData)
			@param imageData (ArrayBuffer) The image data
			@return (Promise) a Promise of an Image

			Creates a new temporary image file from an ArrayBuffer of image data.

			## Example
			```js
				var ImageTools = require("FuseJS/ImageTools");
				ImageTools.getImageFromBuffer(imageData).
					then(function (image) { console.log("Scratch image path is: " + image.path); });
			```
		*/
		Future<Image> ImageFromBufferInterface(Context c, object[] args)
		{
			var p = new Promise<Image>();
			var cb = new ImagePromiseCallback(p);
			if(args.Length == 1){
				var bytes = args[0] as byte[];
				if(bytes!=null)
				{
					if defined(Android)
					{
						sbyte[] sbytes = new sbyte[bytes.Length];
						for(var i = 0; i<bytes.Length; i++)
							sbytes[i] = (sbyte) bytes[i];
						AndroidImageUtils.GetImageFromBuffer(sbytes, cb.Resolve, cb.Reject);
					}
					else if defined(iOS)
					{
						iOSImageUtils.GetImageFromBuffer(bytes, cb.Resolve, cb.Reject);
					}
					else
					{
						cb.Reject("Not supported on current platform.");
					}
				}else{
						cb.Reject("getImageFromBuffer requires an arraybuffer argument");
				}
			}else{
					cb.Reject("getImageFromBuffer requires an arraybuffer argument");
			}

			return p;
		}

		/**
			@scriptmethod getBufferFromImage(image)
			@param image (Object) The image to fetch data for
			@return (Promise) a Promise of an ArrayBuffer of image data

			Retrieves the underlying image data for an image as an ArrayBuffer.

			## Example
			```js
				// Here image is expected to be an `Image` object
				var ImageTools = require("FuseJS/ImageTools");
				ImageTools.getBufferFromImage(image)
					.then(function(buf) { console.log("Image contains " + buf.byteLength + " bytes"); });
			```
		*/
		Future<byte[]> BufferFromImageInterface(Context c, object[] args)
		{
			var p = new Promise<byte[]>();
			if(args.Length == 1){
				var img = Image.FromObject(args[0]);
				if(img != null)
				{
					try
					{
						byte[] bytes = Uno.IO.File.ReadAllBytes(img.Path);
						p.Resolve(bytes);
					}catch(Exception e)
					{
						p.Reject(e);
					}
				}else{
					p.Reject(new Exception("Invalid image reference"));
				}
			}else{
				p.Reject(new Exception("Invalid arguments"));
			}
			return p;
		}

		/**
			@scriptmethod getPixelBuffer(image)
			@param image (Object) The image to read
			@return (Promise) a Promise of an ArrayBuffer

			Returns the raw RGBA pixel data of an image, with 4 bytes per pixel in row-major order.
			The alpha channel is straight (non-premultiplied). The buffer length is
			`image.width * image.height * 4`.
		*/
		Future<byte[]> PixelBufferInterface(Context c, object[] args)
		{
			var p = new Promise<byte[]>();
			if(args.Length != 1)
			{
				p.Reject(new Exception("getPixelBuffer takes 1 argument: An Image"));
				return p;
			}

			var image = Image.FromObject(args[0]);
			if(image == null)
			{
				p.Reject(new Exception("Invalid image reference"));
				return p;
			}

			return GetPixelBuffer(image);
		}

		/**
		}

		/**
			@scriptmethod getImageFromUri(uri)
			@param uri (string) A file:// URI, an absolute path, or an Android content:// URI
			@return (Promise) a Promise of an Image

			Loads an image from a URI. On Android, `content://` URIs are copied to a temporary file first.
			On iOS and .NET, only `file://` URIs and absolute paths are supported.

			## Example
			```js
				var ImageTools = require("FuseJS/ImageTools");
				ImageTools.getImageFromUri("file:///path/to/image.jpg")
					.then(function(image) { console.log("Loaded: " + image.path); });
			```
		*/
		Future<Image> ImageFromUriInterface(Context c, object[] args)
		{
			if(args.Length != 1)
				throw new Exception("getImageFromUri takes 1 argument: A URI string");

			var uri = args.ValueOrDefault<string>(0);
			if(string.IsNullOrEmpty(uri))
				throw new Exception("getImageFromUri requires a URI string");

			return ImageFromUri(uri);
		}

		/**
			@scriptmethod getImageFromBase64(base64)
			@param base64 (string) The data to decode
			@return (Promise) a Promise of an Image

			Takes base64 string encoded image data and returns a Promise of an Image.

			## Example
			```js
				// Here we assume that someBase64ImageString contains a base-64 encoded image
				var ImageTools = require("FuseJS/ImageTools");
				ImageTools.getImageFromBase64(someBase64ImageString);
					.then(function(image) {
						console.log("Scratch path of image is " + image.path);
					});
			```
		*/
		Future<Image> ImageFromBase64Interface(Context c, object[] args)
		{
			if(args.Length!=1)
				throw new Exception("imageFromBase64 needs a base64 string argument");
			var str = args.ValueOrDefault<string>(0);
			return ImageFromBase64(str);
		}

		/**
			@scriptmethod getBase64FromImage(image, options)
			@param image (Object) The Image to encode
			@param options (Object) Optional encoding options
			@return (Promise) a Promise of a string of base64 data

			Encodes the given image as a base64 string. The output is not line-wrapped.

			The optional `options` object may contain:

			* `format` - Optional output format: `"jpeg"`, `"png"` or `"webp"`. Defaults to the format of the input image.
			* `quality` - Optional output quality from 0 to 100 (or 0.0 to 1.0), used for lossy formats. Defaults to 90.

			## Example
			```js
				// Here we assume that we have an existing `image` object
				var ImageTools = require("FuseJS/ImageTools");
				ImageTools.getBase64FromImage(image)
					.then(function(base64Image) { console.log("The base64 encoded image is \"" + base64Image + "\""); });
			```
		*/
		Future<string> Base64FromImageInterface(Context c, object[] args)
		{
			if(args.Length < 1 || args.Length > 2)
				throw new Exception("getBase64FromImage takes 1 or 2 arguments: An Image and an optional options object");

			var image = Image.FromObject(args[0]);
			if(image == null)
				throw new Exception("Invalid image reference");

			var opts = args.Length == 2 ? args[1] as Scripting.Object : null;
			return ImageToBase64(image, ReadFormat(opts), ReadQuality(opts));
		}
	}
}
