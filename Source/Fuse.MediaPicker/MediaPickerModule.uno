using Uno.Threading;
using Uno;
using Uno.Data.Json;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;
using Fuse;
using Fuse.Scripting;

namespace Fuse.MediaPicker
{
	/**
		@scriptmodule FuseJS/MediaPicker

		Allows for picking images or video from the image library, and taking new pictures or record video with the camera.
		To use these features, you can invoke the provided `pickImage`, `pickVideo` or `pickVideos` methods. You have to pass an object javascript as a method's argument to setup on how you want to get the media from the device. Take a look at the example to see the detail.
		You can also pick multiple images, but only works with iOS 14 later, and Android starts from 4.4 later.
		Multiple video selection requires iOS 14 or later and Android 4.4 or later.

		You need to add a reference to `"Fuse.MediaPicker"` in your project file to use this feature.
		On modern Android and iOS versions the system pickers do not require any storage permissions. Camera capture requests the camera permission when it is declared in the app manifest.

		Invalid option values are reported with `debug_log` and replaced with safe defaults; numeric values outside their supported range are clamped.

		## Example
		```js
			var mediaPicker = require('FuseJS/MediaPicker');
			var options = {
				source: mediaPicker.SOURCE_GALLERY, // pick image from gallery, use mediaPicker.SOURCE_CAMERA for taking picture or record video from the device camera
				cameraDevice: mediaPicker.CAMERA_REAR, // use mediaPicker.CAMERA_FRONT for the front facing camera (SOURCE_CAMERA only)
				maxWidth: 1024, // resize image width, 0 or omitted keeps the original width
				maxHeight: 1024, // resize image height, 0 or omitted keeps the original height
				quality: 100, // the image quality: 1 - 100
				maxDuration: 120, // filter the duration of the video file to pick or record (in seconds) note: on Android it might not be work 100% or even completely ignored. it depends on the device manufacturer to implement the video picker
				maxImages: 5, // allow for maximum 5 image to pick, 0 means unlimited
				maxVideos: 5 // allow for maximum 5 videos to pick, 0 means unlimited
			}
			mediaPicker.pickImage(options).then(function(imagePaths)
			{
				//imagePaths is a string array of image paths
			}).catch(function(error) {
				//Something went wrong, see error for details
			});

			mediaPicker.pickVideo(options).then(function(videoPath)
			{
				//videoPath is a string containing the path of the video
			}).catch(function(error) {
				//Something went wrong, see error for details
			});

			mediaPicker.pickVideos(options).then(function(videoPaths)
			{
				//videoPaths is a string array of video paths
			}).catch(function(error) {
				//Something went wrong, see error for details
			});
		```
		> **Note**: This package is considered as the advanced version of the `Fuse.CameraRoll` `getImage` method, where in this package we have options to pick media (images & video) from the gallery or by taking from the device camera.
		>
		> **Note**: Returned paths are absolute file paths. To play a video with the `Video` control, use `Url` with a `file://` prefix (for example `Video.Url = "file://" + path`) instead of `Video.File`.
	*/
	[UXGlobalModule]
	public sealed class MediaPicker : NativeModule
	{
		static readonly MediaPicker _instance;
		public MediaPicker()
		{
			if(_instance != null) return;

			Resource.SetGlobalKey(_instance = this, "FuseJS/MediaPicker");

			AddMember(new NativePromise<string, Scripting.Array>("pickImage", PickImageInterface, Converter));
			AddMember(new NativePromise<string, string>("pickVideo", PickVideoInterface));
			AddMember(new NativePromise<string, Scripting.Array>("pickVideos", PickVideosInterface, Converter));
			AddMember(new NativeProperty<int, int>("SOURCE_CAMERA", SourceCamera));
			AddMember(new NativeProperty<int, int>("SOURCE_GALLERY", SourceGallery));
			AddMember(new NativeProperty<int, int>("CAMERA_REAR", CameraRear));
			AddMember(new NativeProperty<int, int>("CAMERA_FRONT", CameraFront));
		}

		/**
			@scriptmethod pickImage(options)

			Starts an OS-specific image picker view.

			@return (Promise) a Promise of an array of image paths.
		*/
		static Future<string> PickImageInterface(Context context, object[] args)
		{
			var p = new Promise<string>();
			PickImage(p, GetOptions(args));
			return p;
		}

		internal static Future<string> PickImage(Promise<string> p, Scripting.Object args)
		{
			try
			{
				if defined(iOS)
					iOSMediaPicker.PickImage(p, ConstructArguments(args));
				else if defined(Android)
					AndroidMediaPicker.PickImage(p, ConstructArguments(args));
				else
					p.Reject(new Exception("Unsupported on current platform"));
			}
			catch (Exception e)
			{
				var message = "MediaPicker: could not start the image picker: " + e.Message;
				debug_log(message);
				p.Reject(new Exception(message));
			}

			return p;
		}

		static int SourceCamera() {
			return 0;
		}

		static int SourceGallery() {
			return 1;
		}

		static int CameraRear() {
			return 0;
		}

		static int CameraFront() {
			return 1;
		}

		/**
			@scriptmethod pickVideo(options)

			Starts an OS-specific video picker view.

			@return (Promise) a Promise of a video path.
		*/
		static Future<string> PickVideoInterface(Context context, object[] args)
		{
			var p = new Promise<string>();
			PickVideo(p, GetOptions(args));
			return p;
		}

		internal static Future<string> PickVideo(Promise<string> p, Scripting.Object args)
		{
			try
			{
				if defined(iOS)
					iOSMediaPicker.PickVideo(p, ConstructArguments(args));
				else if defined(Android)
					AndroidMediaPicker.PickVideo(p, ConstructArguments(args));
				else
					p.Reject(new Exception("Unsupported on current platform"));
			}
			catch (Exception e)
			{
				var message = "MediaPicker: could not start the video picker: " + e.Message;
				debug_log(message);
				p.Reject(new Exception(message));
			}

			return p;
		}

		/**
			@scriptmethod pickVideos(options)

			Starts an OS-specific video picker view that allows selecting multiple videos from the gallery.
			Recording multiple videos with the camera is not supported, so `source` is always treated as `SOURCE_GALLERY`.

			@return (Promise) a Promise of a video path array.
		*/
		static Future<string> PickVideosInterface(Context context, object[] args)
		{
			var p = new Promise<string>();
			PickVideos(p, GetOptions(args));
			return p;
		}

		internal static Future<string> PickVideos(Promise<string> p, Scripting.Object args)
		{
			try
			{
				if defined(iOS)
					iOSMediaPicker.PickVideos(p, ConstructArguments(args));
				else if defined(Android)
					AndroidMediaPicker.PickVideos(p, ConstructArguments(args));
				else
					p.Reject(new Exception("Unsupported on current platform"));
			}
			catch (Exception e)
			{
				var message = "MediaPicker: could not start the video picker: " + e.Message;
				debug_log(message);
				p.Reject(new Exception(message));
			}

			return p;
		}

		static Scripting.Object GetOptions(object[] args)
		{
			if (args == null || args.Length == 0)
				return null;

			var options = args[0] as Scripting.Object;
			if (options == null && args[0] != null)
				debug_log("MediaPicker: options must be an object; using defaults.");

			return options;
		}

		sealed class MediaPickerOptions
		{
			public int Source = SourceGallery();
			public int MaxImages = 1;
			public int MaxVideos = 1;
			public int MaxDuration = 0;
			public double MaxWidth = 0;
			public double MaxHeight = 0;
			public int Quality = 100;
			public int CameraDevice = CameraRear();
		}

		static MediaPickerOptions ParseOptions(Scripting.Object args)
		{
			var options = new MediaPickerOptions();
			if (args == null)
				return options;

			// Validate and clamp once, so invalid JavaScript input never reaches native code.
			options.Source = GetIntOption(args, "source", options.Source, 0, 1);
			options.CameraDevice = GetIntOption(args, "cameraDevice", options.CameraDevice, 0, 1000);
			options.MaxImages = GetIntOption(args, "maxImages", options.MaxImages, 0, 1000);
			options.MaxVideos = GetIntOption(args, "maxVideos", options.MaxVideos, 0, 1000);
			options.MaxDuration = GetIntOption(args, "maxDuration", options.MaxDuration, 0, 86400);
			options.Quality = GetIntOption(args, "quality", options.Quality, 1, 100);
			options.MaxWidth = GetDoubleOption(args, "maxWidth", options.MaxWidth, 0, 16384);
			options.MaxHeight = GetDoubleOption(args, "maxHeight", options.MaxHeight, 0, 16384);

			options.Source = options.Source == SourceCamera() ? SourceCamera() : SourceGallery();
			options.CameraDevice = options.CameraDevice == CameraFront() ? CameraFront() : CameraRear();

			if (options.MaxWidth > 0)
				options.MaxWidth = Math.Round(options.MaxWidth);
			if (options.MaxHeight > 0)
				options.MaxHeight = Math.Round(options.MaxHeight);

			// The camera can only capture one item at a time.
			if (options.Source == SourceCamera())
				options.MaxImages = 1;

			return options;
		}

		static int GetIntOption(Scripting.Object args, string key, int fallback, int min, int max)
		{
			return (int)Math.Round(GetDoubleOption(args, key, fallback, min, max));
		}

		static double GetDoubleOption(Scripting.Object args, string key, double fallback, double min, double max)
		{
			if (!args.ContainsKey(key))
				return fallback;

			var value = args[key];
			if (value == null)
			{
				debug_log("MediaPicker: option '" + key + "' is null; using " + fallback + ".");
				return fallback;
			}

			double numeric;
			if (!Marshal.TryToDouble(value, out numeric))
			{
				debug_log("MediaPicker: option '" + key + "' must be a number; using " + fallback + ".");
				return fallback;
			}

			if (Double.IsNaN(numeric) || double.IsInfinity(numeric))
			{
				debug_log("MediaPicker: option '" + key + "' must be a finite number; using " + fallback + ".");
				return fallback;
			}

			if (numeric < min)
			{
				debug_log("MediaPicker: option '" + key + "' (" + numeric + ") is below " + min + "; using " + fallback + ".");
				return fallback;
			}
			if (numeric > max)
			{
				debug_log("MediaPicker: option '" + key + "' (" + numeric + ") is above " + max + "; using " + max + ".");
				return max;
			}

			return numeric;
		}

		static extern(Android) Java.Object ConstructArguments(Scripting.Object args)
		{
			var options = ParseOptions(args);
			return ConstructArgumentsAndroid(
				options.Source, options.MaxWidth, options.MaxHeight, options.Quality,
				options.MaxImages, options.MaxVideos, options.MaxDuration, options.CameraDevice);
		}

		[Foreign(Language.Java)]
		static extern(Android) Java.Object ConstructArgumentsAndroid(int source, double maxWidth, double maxHeight, int quality, int maxImages, int maxVideos, int maxDuration, int cameraDevice)
		@{
			java.util.Map<String, Object> args = new java.util.HashMap<String, Object>();
			args.put("source", source);
			args.put("maxWidth", new Double(maxWidth));
			args.put("maxHeight", new Double(maxHeight));
			args.put("imageQuality", quality);
			args.put("maxImages", maxImages);
			args.put("maxVideos", maxVideos);
			args.put("maxDuration", maxDuration);
			args.put("cameraDevice", cameraDevice);
			return args;
		@}

		static extern(iOS) ObjC.Object ConstructArguments(Scripting.Object args)
		{
			var options = ParseOptions(args);
			return ConstructArgumentsIOS(
				options.Source, (int)options.MaxWidth, (int)options.MaxHeight, options.Quality,
				options.MaxImages, options.MaxVideos, options.MaxDuration, options.CameraDevice);
		}

		[Foreign(Language.ObjC)]
		static extern(iOS) ObjC.Object ConstructArgumentsIOS(int source, int maxWidth, int maxHeight, int quality, int maxImages, int maxVideos, int maxDuration, int cameraDevice)
		@{
			NSMutableDictionary* args = [NSMutableDictionary dictionary];
			[args setObject:[NSNumber numberWithInt:source] forKey:@"source"];
			[args setObject:[NSNumber numberWithInt:maxWidth] forKey:@"maxWidth"];
			[args setObject:[NSNumber numberWithInt:maxHeight] forKey:@"maxHeight"];
			[args setObject:[NSNumber numberWithInt:quality] forKey:@"imageQuality"];
			[args setObject:[NSNumber numberWithInt:maxImages] forKey:@"maxImages"];
			[args setObject:[NSNumber numberWithInt:maxVideos] forKey:@"maxVideos"];
			[args setObject:[NSNumber numberWithInt:maxDuration] forKey:@"maxDuration"];
			[args setObject:[NSNumber numberWithInt:cameraDevice] forKey:@"cameraDevice"];
			return args;
		@}

		/**
			Converts the native result into a JavaScript array.

			Native results are JSON arrays of paths. A plain path is also accepted
			for backwards compatibility and for single-item results.
		*/
		public static Scripting.Array Converter(Context context, string result)
		{
			var output = context.NewArray();
			if (string.IsNullOrEmpty(result))
				return output;

			try
			{
				var reader = JsonReader.Parse(result);
				if (reader.JsonDataType == JsonDataType.Array)
				{
					for (int i = 0; i < reader.Count; ++i)
					{
						var item = reader[i];
						if (item != null && item.JsonDataType == JsonDataType.String)
							output[i] = item.AsString();
					}
					return output;
				}
			}
			catch (Exception e)
			{
				// Not JSON, treat the result as a single path below.
			}

			output[0] = result;
			return output;
		}

	}

	internal sealed class StringPromiseCallback
	{
		Promise<string> _p;
		public StringPromiseCallback(Promise<string> p)
		{
			_p = p;
		}

		public void Resolve(string v)
		{
			_p.Resolve(v);
		}

		public void Reject(string reason)
		{
			_p.Reject(new Exception(reason));
		}
	}
}
