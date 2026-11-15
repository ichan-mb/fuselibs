using Uno;
using Uno.Threading;
using Fuse.Scripting;
using Fuse.Resources.Exif;

namespace Fuse.Controls
{
	internal abstract class PhotoTexture : IDisposable
	{
		public abstract ImageOrientation Orientation { get; }
		public abstract texture2D Texture { get; }
		public abstract void Dispose();
	}

	internal abstract class PhotoHandle { }

	/**
		Thumbnail size hint in points

		Used by `Photo` when saving as thumbnail. The implementation
		of `Photo` decides how to interpret this value.
	*/
	public class ThumbnailSizeHint
	{
		public readonly float Width;
		public readonly float Height;

		public ThumbnailSizeHint(float width, float height)
		{
			Width = width;
			Height = height;
		}
	}

	public abstract class Photo
	{
		internal abstract Future<PhotoTexture> GetTexture();
		internal abstract Future<PhotoHandle> GetPhotoHandle();

		public abstract Future<string> Save();
		public abstract Future<string> SaveThumbnail(ThumbnailSizeHint thumbnailSizeHint = null);
		public abstract Future<bool> SaveToCameraRoll();
		public abstract Future<PhotoMetadata> GetMetadata();
		public abstract void Release();

		static Photo()
		{
			ScriptClass.Register(typeof(Photo),
				new ScriptPromise<Photo,string,string>("save", ExecutionThread.Any, save),
				new ScriptPromise<Photo,string,string>("saveThumbnail", ExecutionThread.Any, saveThumbnail),
				new ScriptPromise<Photo,bool,object>("saveToCameraRoll", ExecutionThread.Any, saveToCameraRoll, convertBool),
				new ScriptPromise<Photo,PhotoMetadata,object>("getMetadata", ExecutionThread.Any, getMetadata, convertMetadata),
				new ScriptMethod<Photo>("release", release));
		}

		/**
			Save the photo to disk

			@scriptmethod save()

			Returns a Promise that resolves to a string containing the filepath to the photo.
			```xml
				<CameraView ux:Name="Camera" />
				<JavaScript>
					Camera.capturePhoto()
						.then(function(photo) {
							photo.save()
								.then(function(filePath) {
									photo.release();
								})
								.catch(function(err) {
									photo.release();
								})
						})
						.catch(function(err) { });
				</JavaScript>
			```
		*/
		static Future<string> save(Context context, Photo photo, object[] args)
		{
			if (args.Length > 0)
				return new Promise<string>().RejectWithMessage("Unexpected argument(s)");

			return photo.Save();
		}

		/**
			Save a downscaled version of the photo

			@scriptmethod saveThumbnail( sizeHint )

			Use this method if you need a downscaled versions of the photo. An optional argument can
			be passed with a size hint. The thumbnail will try to fit the provided size hint and maintain
			its aspect ratio.

			Its good practice to provide a sizehint if you know what size the thumbnail should be.
			The sizehint will be interpreted as points.
			```xml
				<CameraView ux:Name="Camera" />
				<JavaScript>
					Camera.capturePhoto()
						.then(function(photo) {
							var sizehint = {
								width: 128,
								height: 128
							};
							photo.saveThumbnail(sizehint)
								.then(function(outputFilePath) {
									console.log("Thumbnail saved to: " + outputFilePath);
									photo.release();
								})
								.catch(function(err) {
									photo.release();
								})
						})
						.catch(function(err) { });
				</JavaScript>
			```
		*/
		static Future<string> saveThumbnail(Context context, Photo photo, object[] args)
		{
			ThumbnailSizeHint sizeHint = null;
			if (args.Length > 0 && args[0] is Fuse.Scripting.Object)
			{
				var obj = (Fuse.Scripting.Object)args[0];
				if (obj.ContainsKey("width") && obj.ContainsKey("height"))
				{
					var width = Fuse.Scripting.Value.ToNumber(obj["width"]);
					var height = Fuse.Scripting.Value.ToNumber(obj["height"]);
					sizeHint = new ThumbnailSizeHint((float)width, (float)height);
				}
			}
			return photo.SaveThumbnail(sizeHint);
		}

		/**
			Save the photo to the device camera roll

			@scriptmethod saveToCameraRoll()

			Returns a promise that resolves to `true` when the photo was added to the camera roll.
			On iOS this requires photo library access.
		*/
		static Future<bool> saveToCameraRoll(Context context, Photo photo, object[] args)
		{
			if (args.Length > 0)
				return new Promise<bool>().RejectWithMessage("Unexpected argument(s)");

			return photo.SaveToCameraRoll();
		}

		static object convertBool(Context c, bool value)
		{
			return value;
		}

		/**
			Get the photo metadata

			@scriptmethod getMetadata()

			Returns a promise that resolves to an object describing the captured photo:

			* `width` and `height` - the size in pixels, as the photo will be displayed
			* `orientation` - the EXIF orientation (1 to 8)
			* `timestamp` - the capture time in milliseconds since the Unix epoch, or 0
			* `iso`, `exposureTime`, `fNumber` and `focalLength` - the camera settings
			  used for the capture, or 0 when the platform does not provide them

			```xml
				<JavaScript>
					Camera.capturePhoto()
						.then(function(photo) {
							photo.getMetadata()
								.then(function(metadata) {
									console.log(metadata.width + "x" + metadata.height);
									photo.release();
								});
						})
						.catch(function(err) { });
				</JavaScript>
			```
		*/
		static Future<PhotoMetadata> getMetadata(Context context, Photo photo, object[] args)
		{
			if (args.Length > 0)
				return new Promise<PhotoMetadata>().RejectWithMessage("Unexpected argument(s)");

			return photo.GetMetadata();
		}

		static object convertMetadata(Context c, PhotoMetadata metadata)
		{
			var obj = c.NewObject();
			obj[PhotoMetadata.WidthName] = metadata.Width;
			obj[PhotoMetadata.HeightName] = metadata.Height;
			obj[PhotoMetadata.OrientationName] = metadata.Orientation;
			obj[PhotoMetadata.TimestampName] = metadata.Timestamp;
			obj[PhotoMetadata.IsoName] = metadata.Iso;
			obj[PhotoMetadata.ExposureTimeName] = (double)metadata.ExposureTime;
			obj[PhotoMetadata.FNumberName] = (double)metadata.FNumber;
			obj[PhotoMetadata.FocalLengthName] = (double)metadata.FocalLength;
			return obj;
		}

		/**
			Release the photo and the resources it holds

			@scriptmethod release()

			A photo can hold onto large amounts of memory. Make sure to release your photo objects when you are done using them.
			Its considered bad practice to hold onto more than one photo at a time, older devices can run out of memory fast.
		*/
		static void release(Photo photo, object[] args)
		{
			photo.Release();
		}
	}
}
