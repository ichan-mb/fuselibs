using Uno;
using Uno.Threading;
using Fuse.Scripting;

namespace Fuse.Controls
{
	public abstract class Recording
	{
		readonly string _filePath;

		protected Recording(string filePath)
		{
			_filePath = filePath;
		}

		public string FilePath
		{
			get { return _filePath; }
		}

		public abstract Future<bool> SaveToCameraRoll();
		public abstract Future<string> SaveThumbnail(ThumbnailSizeHint thumbnailSizeHint = null);
		public abstract Future<RecordingMetadata> GetMetadata();

		static Recording()
		{
			ScriptClass.Register(typeof(Recording),
				new ScriptMethod<Recording>("filePath", filePath),
				new ScriptPromise<Recording,bool,object>("saveToCameraRoll", ExecutionThread.Any, saveToCameraRoll, convertBool),
				new ScriptPromise<Recording,string,string>("saveThumbnail", ExecutionThread.Any, saveThumbnail),
				new ScriptPromise<Recording,RecordingMetadata,object>("getMetadata", ExecutionThread.Any, getMetadata, convertMetadata));
		}

		/**
			Get the filepath of the video

			@scriptmethod filePath

			Returns a string containing the filepath to the video
			```xml
				<CameraView ux:Name="Camera" />
				<JavaScript>
					Camera.startRecording()
						.then(function(recordingSession) {
							recordingSession.stop()
								.then(function(recording) {
									var filePath = recording.filePath();
								});
						});
				</JavaScript>
			```
		*/
		static object filePath(Context context, Recording self, object[] args)
		{
			return self.FilePath;
		}

		/**
			Save the recording to the device camera roll

			@scriptmethod saveToCameraRoll()

			Returns a promise that resolves to `true` when the recording was added to the camera roll.
			On iOS this requires photo library access.
		*/
		static Future<bool> saveToCameraRoll(Context context, Recording self, object[] args)
		{
			if (args.Length > 0)
				return new Promise<bool>().RejectWithMessage("Unexpected argument(s)");

			return self.SaveToCameraRoll();
		}

		static object convertBool(Context c, bool value)
		{
			return value;
		}

		/**
			Save a downscaled thumbnail of the video

			@scriptmethod saveThumbnail( sizeHint )

			Returns a promise that resolves to the filepath of a JPEG thumbnail. An
			optional size hint can be passed; the thumbnail keeps the aspect ratio of
			the video.

			```xml
				<JavaScript>
					recording.saveThumbnail({ width: 128, height: 128 })
						.then(function(thumbnailPath) {
							console.log("Thumbnail saved to: " + thumbnailPath);
						})
						.catch(function(err) { });
				</JavaScript>
			```
		*/
		static Future<string> saveThumbnail(Context context, Recording self, object[] args)
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
			return self.SaveThumbnail(sizeHint);
		}

		/**
			Get the recording metadata

			@scriptmethod getMetadata()

			Returns a promise that resolves to an object with the `width` and `height`
			of the video (as displayed), its `duration` in milliseconds and the
			`fileSize` in bytes.

			```xml
				<JavaScript>
					recording.getMetadata().then(function(metadata) {
						console.log(metadata.width + "x" + metadata.height + ", " + metadata.duration + "ms");
					});
				</JavaScript>
			```
		*/
		static Future<RecordingMetadata> getMetadata(Context context, Recording self, object[] args)
		{
			if (args.Length > 0)
				return new Promise<RecordingMetadata>().RejectWithMessage("Unexpected argument(s)");

			return self.GetMetadata();
		}

		static object convertMetadata(Context c, RecordingMetadata metadata)
		{
			var obj = c.NewObject();
			obj[RecordingMetadata.WidthName] = metadata.Width;
			obj[RecordingMetadata.HeightName] = metadata.Height;
			obj[RecordingMetadata.DurationName] = metadata.Duration;
			obj[RecordingMetadata.FileSizeName] = metadata.FileSize;
			return obj;
		}
	}
}
