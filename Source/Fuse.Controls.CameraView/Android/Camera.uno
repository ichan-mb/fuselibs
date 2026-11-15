using Uno;
using OpenGL;
using Uno.Collections;
using Uno.Compiler.ExportTargetInterop;
using Uno.Threading;
using Uno.Graphics;

using Fuse;
using Fuse.Controls;
using Fuse.Controls.Native;

namespace Fuse.Controls.Android
{
	extern(ANDROID) class AndroidRecording : Recording
	{
		public AndroidRecording(string outputFilePath) : base(outputFilePath)
		{
		}

		public override Future<bool> SaveToCameraRoll()
		{
			var p = new SaveToCameraRollPromise(FilePath);
			p.Save();
			return p;
		}

		public override Future<string> SaveThumbnail(ThumbnailSizeHint thumbnailSizeHint = null)
		{
			var p = new ThumbnailPromise();
			p.Save(FilePath, thumbnailSizeHint);
			return p;
		}

		public override Future<RecordingMetadata> GetMetadata()
		{
			var p = new MetadataPromise();
			p.Get(FilePath);
			return p;
		}

		class ThumbnailPromise : CameraPromise<string>
		{
			public void Save(string filePath, ThumbnailSizeHint sizeHint)
			{
				var widthHint = 0.0f;
				var heightHint = 0.0f;
				var useSizeHint = false;
				if (sizeHint != null)
				{
					var pixelsPerPoint = Fuse.App.Current.RootViewport.PixelsPerPoint;
					widthHint = Math.Max(sizeHint.Width, 8) * pixelsPerPoint;
					heightHint = Math.Max(sizeHint.Height, 8) * pixelsPerPoint;
					useSizeHint = true;
				}
				SaveThumbnail(filePath, OnResolve, OnReject, useSizeHint, widthHint, heightHint);
			}

			public void OnResolve(string filePath) { Resolve(filePath); }
			public void OnReject(string message) { Reject(new Exception(message)); }
		}

		class MetadataPromise : CameraPromise<RecordingMetadata>
		{
			public void Get(string filePath) { GetMetadata(filePath, OnResolve, OnReject); }

			public void OnResolve(int width, int height, int duration, double fileSize)
			{
				Resolve(new RecordingMetadata(width, height, duration, fileSize));
			}

			public void OnReject(string message) { Reject(new Exception(message)); }
		}

		[Foreign(Language.Java)]
		static void SaveThumbnail(string filePath, Action<string> resolve, Action<string> reject, bool useHint, float widthHint, float heightHint)
		@{
			new java.lang.Thread(new java.lang.Runnable() {
				public void run() {
					android.media.MediaMetadataRetriever retriever = new android.media.MediaMetadataRetriever();
					android.graphics.Bitmap frame = null;
					android.graphics.Bitmap scaled = null;
					try {
						retriever.setDataSource(filePath);
						frame = retriever.getFrameAtTime(-1);
						if (frame == null) {
							reject.run("Failed to generate a video thumbnail");
							return;
						}

						float width = (float)frame.getWidth();
						float height = (float)frame.getHeight();
						float targetWidth;
						float targetHeight;
						if (useHint) {
							targetWidth = Math.min(widthHint, width);
							targetHeight = Math.min(heightHint, height);
						} else {
							android.util.DisplayMetrics displayMetrics = new android.util.DisplayMetrics();
							com.fuse.Activity.getRootActivity().getWindowManager().getDefaultDisplay().getMetrics(displayMetrics);
							targetWidth = (float)displayMetrics.widthPixels / 2;
							targetHeight = (float)displayMetrics.heightPixels / 2;
						}

						float scale = Math.min(targetWidth / width, targetHeight / height);
						int scaledWidth = (int)Math.ceil(width * scale);
						int scaledHeight = (int)Math.ceil(height * scale);
						if (scaledWidth < 1 || scaledHeight < 1) {
							reject.run("Video thumbnail has invalid dimensions");
							return;
						}

						scaled = android.graphics.Bitmap.createScaledBitmap(frame, scaledWidth, scaledHeight, true);
						String thumbnailPath = com.fuse.controls.cameraview.CameraStorage.createImageFilePath("jpeg");
						java.io.FileOutputStream output = new java.io.FileOutputStream(new java.io.File(thumbnailPath));
						scaled.compress(android.graphics.Bitmap.CompressFormat.JPEG, 100, output);
						output.close();

						resolve.run(thumbnailPath);
					} catch (Exception e) {
						reject.run(e.getMessage());
					} finally {
						if (frame != null) frame.recycle();
						if (scaled != null && !scaled.isRecycled()) scaled.recycle();
						try { retriever.release(); } catch (Exception ignored) { }
					}
				}
			}).start();
		@}

		[Foreign(Language.Java)]
		static void GetMetadata(string filePath, Action<int,int,int,double> onResolve, Action<string> onReject)
		@{
			new java.lang.Thread(new java.lang.Runnable() {
				public void run() {
					android.media.MediaMetadataRetriever retriever = new android.media.MediaMetadataRetriever();
					try {
						retriever.setDataSource(filePath);

						int width = 0;
						int height = 0;
						int duration = 0;

						String widthValue = retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH);
						String heightValue = retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT);
						String durationValue = retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION);
						String rotationValue = retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION);

						if (widthValue != null) width = Integer.parseInt(widthValue);
						if (heightValue != null) height = Integer.parseInt(heightValue);
						if (durationValue != null) duration = Integer.parseInt(durationValue);
						if (rotationValue != null) {
							int rotation = Integer.parseInt(rotationValue);
							if (rotation == 90 || rotation == 270) {
								int tmp = width;
								width = height;
								height = tmp;
							}
						}

						java.io.File file = new java.io.File(filePath);
						double fileSize = file.exists() ? (double)file.length() : 0.0;

						onResolve.run(width, height, duration, fileSize);
					} catch (Exception e) {
						onReject.run(e.getMessage());
					} finally {
						try { retriever.release(); } catch (Exception ignored) { }
					}
				}
			}).start();
		@}

		class SaveToCameraRollPromise : CameraPromise<bool>
		{
			string _filePath;

			public SaveToCameraRollPromise(string filePath)
			{
				_filePath = filePath;
			}

			public void Save()
			{
				SaveToCameraRoll(_filePath, OnResolve, OnReject);
			}

			public void OnResolve(bool success) { Resolve(success); }
			public void OnReject(string message) { Reject(new Exception(message)); }
		}

		[Foreign(Language.Java)]
		static void SaveToCameraRoll(string filePath, Action<bool> onResolve, Action<string> onReject)
		@{
			new java.lang.Thread(new java.lang.Runnable() {
				public void run() {
					try {
						final boolean success = com.fuse.controls.cameraview.CameraStorage.saveVideoToGallery(filePath);
						new android.os.Handler(android.os.Looper.getMainLooper()).post(new Runnable() {
							public void run() { onResolve.run(success); }
						});
					} catch (final Exception e) {
						new android.os.Handler(android.os.Looper.getMainLooper()).post(new Runnable() {
							public void run() { onReject.run(e.getMessage()); }
						});
					}
				}
			}).start();
		@}
	}

	[ForeignInclude(Language.Java,
		"com.fuse.controls.cameraview.RecordingSession",
		"com.fuse.controls.cameraview.IStopRecordingSession")]
	extern(ANDROID) class AndroidRecordingSession : RecordingSession, IDisposable
	{
		Java.Object _session;
		Action _doneCallback;

		public AndroidRecordingSession(Java.Object session, Action doneCallback)
		{
			_session = session;
			_doneCallback = doneCallback;
		}

		bool _stopped = false;
		public override Future<Recording> Stop()
		{
			return InternalStop().Intercept(_doneCallback);
		}

		Future<Recording> InternalStop()
		{
			if (!_stopped)
			{
				_stopped = true;
				var p = new RecordingPromise();
				Stop(_session, p.OnResolve, p.OnReject);
				return p;
			}
			else
			{
				var p = new Promise<Recording>();
				p.Reject(new Exception("Recording already stopped!"));
				return p;
			}
		}

		public override Future<bool> Pause()
		{
			var p = new BoolPromise();
			Pause(_session, p.OnResolve, p.OnReject);
			return p;
		}

		public override Future<bool> Resume()
		{
			var p = new BoolPromise();
			Resume(_session, p.OnResolve, p.OnReject);
			return p;
		}

		public override Future<int> GetDuration()
		{
			var p = new IntPromise();
			GetDuration(_session, p.OnResolve, p.OnReject);
			return p;
		}

		void IDisposable.Dispose()
		{
			InternalStop();
		}

		class RecordingPromise : CameraPromise<Recording>
		{
			public void OnResolve(string outputFilePath) { Resolve(new AndroidRecording(outputFilePath)); }
			public void OnReject(string exceptionMessage) { Reject(new Exception(exceptionMessage)); }
		}

		class BoolPromise : CameraPromise<bool>
		{
			public void OnResolve(bool value) { Resolve(value); }
			public void OnReject(string message) { Reject(new Exception(message)); }
		}

		class IntPromise : CameraPromise<int>
		{
			public void OnResolve(int value) { Resolve(value); }
			public void OnReject(string message) { Reject(new Exception(message)); }
		}

		[Foreign(Language.Java)]
		static void Stop(Java.Object session, Action<string> resolve, Action<string> reject)
		@{
			((RecordingSession)session).stop(new IStopRecordingSession() {
				public void onSuccess(String outputFilePath) {
					resolve.run(outputFilePath);
				}
				public void onException(String message) {
					reject.run(message);
				}
			});
		@}

		[Foreign(Language.Java)]
		static void Pause(Java.Object session, Action<bool> resolve, Action<string> reject)
		@{
			try {
				resolve.run(((RecordingSession)session).pause());
			} catch (Exception e) {
				reject.run(e.getMessage());
			}
		@}

		[Foreign(Language.Java)]
		static void Resume(Java.Object session, Action<bool> resolve, Action<string> reject)
		@{
			try {
				resolve.run(((RecordingSession)session).resume());
			} catch (Exception e) {
				reject.run(e.getMessage());
			}
		@}

		[Foreign(Language.Java)]
		static void GetDuration(Java.Object session, Action<int> resolve, Action<string> reject)
		@{
			try {
				long ms = ((RecordingSession)session).getDurationMillis();
				resolve.run((int)Math.min(ms, Integer.MAX_VALUE));
			} catch (Exception e) {
				reject.run(e.getMessage());
			}
		@}
	}

	[ForeignInclude(Language.Java,
		"com.fuse.controls.cameraview.CameraImpl",
		"com.fuse.controls.cameraview.CameraXSession",
		"com.fuse.controls.cameraview.IPictureCallback",
		"com.fuse.controls.cameraview.RecordingSession",
		"com.fuse.controls.cameraview.IStartRecordingSession")]
	extern(ANDROID) class Camera : ViewHandle
	{
		public Java.Object CameraHandle { get; private set; }
		public CameraFacing Facing { get; private set; }
		public int CameraId { get; private set; }
		public string LensId { get; private set; }

		FlashMode _flashMode = FlashMode.Off;
		public FlashMode FlashMode
		{
			get { return _flashMode; }
			set
			{
				if (value.IsSupported(this))
				{
					SetFlashMode(CameraHandle, value.AsString());
					_flashMode = value;
				}
			}
		}

		class BoolPromise : CameraPromise<bool>
		{
			public void OnResolve(bool value) { Resolve(value); }
			public void OnReject(string message) { Reject(new Exception(message)); }
		}

		class FloatPromise : CameraPromise<float>
		{
			public void OnResolve(float value) { Resolve(value); }
			public void OnReject(string message) { Reject(new Exception(message)); }
		}

		class NothingPromise : CameraPromise<Nothing>
		{
			public void OnStarted() { Resolve(default(Nothing)); }
			public void OnReject(string message) { Reject(new Exception(message)); }
		}

		class PicturePromise : CameraPromise<Photo>
		{
			public void OnResolve(Java.Object bytesArray)
			{
				if (State == FutureState.Pending)
					Resolve(new NativePhoto(bytesArray));
			}

			public void OnReject(string exceptionMessage)
			{
				if (State == FutureState.Pending)
					Reject(new Exception(exceptionMessage));
			}
		}

		public Future<Photo> CapturePhoto()
		{
			var picturePromise = new PicturePromise();
			TakePicture(picturePromise.OnResolve, picturePromise.OnReject);
			return picturePromise;
		}

		class AndroidPhotoOptionPromise : PhotoOptionPromise
		{
			Camera _camera;
			string _parameters;

			public AndroidPhotoOptionPromise(Camera camera)
			{
				_camera = camera;
				_parameters = _camera.SaveParameters();
			}

			protected override void Visit(PhotoResolution photoResolution)
			{
				var size = int2(photoResolution.Width, photoResolution.Height);
				if (_camera.SupportsSize(size))
					_camera.SetPictureSize(size.X, size.Y);
				else
				{
					_camera.RestoreParameters(_parameters);
					throw new Exception("Resolution not supported: " + size);
				}
			}

			protected override void Visit(PhotoQuality photoQuality)
			{
				if (photoQuality.Value < 1 || photoQuality.Value > 100)
					throw new Exception("PhotoQuality must be between 1 and 100");

				_camera.SetJpegQuality(photoQuality.Value);
			}
		}

		public Future<PhotoOption[]> SetPhotoOptions(PhotoOption[] options)
		{
			return new AndroidPhotoOptionPromise(this).Visit(options);
		}

		class AndroidCameraFocusPointPromise : Promise<Nothing>
		{
			Camera _camera;
			string _parameters;

			public AndroidCameraFocusPointPromise(Camera camera)
			{
				_camera = camera;
				_parameters = _camera.SaveParameters();
			}

			public Future<Nothing> doFocus(double x, double y, int cameraWidth, int cameraHeight, int isFocusLocked)
			{
				try
				{
					_camera.SetCameraFocusPointNow(x,y, cameraWidth, cameraHeight, isFocusLocked);

					Resolve(default(Nothing));
					return this;
				}
				catch (Exception e)
				{
					Reject(e);
					return this;
				}
			}
		}

		public Future<Nothing> SetCameraFocusPoint(double x, double y, int cameraWidth, int cameraHeight, int isFocusLocked)
		{
			return new AndroidCameraFocusPointPromise(this).doFocus(x, y, cameraWidth, cameraHeight, isFocusLocked);
		}

		class RecordingSessionPromise : Promise<RecordingSession>
		{
			Action _doneCallback;
			Action<IDisposable> _setRecordingSession;

			public RecordingSessionPromise(Action doneCallback, Action<IDisposable> setRecordingSession)
			{
				_doneCallback = doneCallback;
				_setRecordingSession = setRecordingSession;
			}

			public void OnResolve(Java.Object session)
			{
				if (State == FutureState.Pending)
				{
					var s = new AndroidRecordingSession(session, _doneCallback);
					_setRecordingSession(s);
					Resolve(s);
				}
			}

			public void OnReject(string exceptionMessage)
			{
				if (State == FutureState.Pending)
					Reject(new Exception(exceptionMessage));
			}
		}

		IDisposable _recordingSession = null;

		void SetRecordingSession(IDisposable recordingSession)
		{
			_recordingSession = recordingSession;
		}

		public Future<RecordingSession> StartRecording(Action doneCallback)
		{
			var recordingPromise = new RecordingSessionPromise(doneCallback, SetRecordingSession);
			var options = _videoOptions;
			StartRecording(
				recordingPromise.OnResolve,
				recordingPromise.OnReject,
				options.Resolution.X,
				options.Resolution.Y,
				options.FrameRate,
				options.BitRate,
				options.AudioEnabled,
				options.StabilizationEnabled);
			return recordingPromise;
		}

		public PreviewStretchMode PreviewStretchMode
		{
			set { UpdatePreviewStretchMode(value == Fuse.Controls.PreviewStretchMode.UniformToFill); }
		}

		public Camera(Java.Object cameraHandle, int cameraId, CameraFacing facing) : base(Create(cameraHandle, cameraId, 0, 0))
		{
			CameraHandle = cameraHandle;
			CameraId = cameraId;
			LensId = cameraId.ToString();
			Facing = facing;
			var supportedFlashModes = SupportedFlashModes;
			if (supportedFlashModes.Length > 0)
				FlashMode = supportedFlashModes[0];
		}

		VideoOptions _videoOptions = new VideoOptions(int2(0), 0, 0, true, true);

		public bool VideoAudioEnabled
		{
			get { return _videoOptions.AudioEnabled; }
		}

		public void SetJpegQuality(int quality)
		{
			SetJpegQuality(CameraHandle, quality);
		}

		[Foreign(Language.Java)]
		static void SetJpegQuality(Java.Object cameraHandle, int quality)
		@{
			((CameraXSession)cameraHandle).setJpegQuality(quality);
		@}

		public Future<Nothing> SetVideoOptions(VideoOptions options)
		{
			_videoOptions = options;
			return new Promise<Nothing>(default(Nothing));
		}

		public override void Dispose()
		{
			if (_recordingSession != null)
			{
				_recordingSession.Dispose();
				_recordingSession = null;
			}
			Dispose(NativeHandle);
			Release(CameraHandle);
			base.Dispose();
		}

		// picturesizes does not change for an instance of Camera
		int2[] _pictureSizes = null;
		public int2[] PictureSizes
		{
			get
			{
				if (_pictureSizes != null)
					return _pictureSizes;

				var count = GetSupportedPictureSizesCount(CameraHandle);
				var sizes = new int[count * 2];
				GetSupportedPictureSizes(CameraHandle, sizes);
				var result = new int2[count];
				for (var i = 0; i < result.Length; i++)
					result[i] = int2(sizes[(i * 2) + 0], sizes[(i * 2) + 1]);
				return _pictureSizes = result;
			}
		}

		public FlashMode[] SupportedFlashModes
		{
			get
			{
				var m = new List<FlashMode>();

				if (Fuse.Controls.FlashMode.Auto.IsSupported(this))
					m.Add(Fuse.Controls.FlashMode.Auto);

				if (Fuse.Controls.FlashMode.On.IsSupported(this))
					m.Add(Fuse.Controls.FlashMode.On);

				if (Fuse.Controls.FlashMode.Off.IsSupported(this))
					m.Add(Fuse.Controls.FlashMode.Off);

				return m.ToArray();
			}
		}

		public Future<CameraCapabilities> GetCameraCapabilities()
		{
			var p = new CameraCapabilitiesPromise(this);
			GetCameraCapabilitiesNow(CameraHandle, p.OnResolve, p.OnReject);
			return p;
		}

		class CameraCapabilitiesPromise : CameraPromise<CameraCapabilities>
		{
			Camera _camera;

			public CameraCapabilitiesPromise(Camera camera)
			{
				_camera = camera;
			}

			public void OnResolve(bool zoomSupported, float minZoom, float maxZoom, bool torchSupported, float minExposure, float maxExposure, float exposureStep, bool manualExposureSupported, float minIso, float maxIso, float minShutter, float maxShutter, string whiteBalanceModes, bool manualWhiteBalanceSupported, string focusModes)
			{
				Resolve(new CameraCapabilities(
					zoomSupported,
					minZoom,
					maxZoom,
					torchSupported,
					_camera.PictureSizes,
					_camera.SupportedFlashModes,
					GetSupportedFacings(),
					minExposure,
					maxExposure,
					exposureStep,
					manualExposureSupported,
					minIso,
					maxIso,
					minShutter,
					maxShutter,
					ParseWhiteBalanceModes(whiteBalanceModes),
					manualWhiteBalanceSupported,
					ParseFocusModes(focusModes)));
			}

			static FocusMode[] ParseFocusModes(string csv)
			{
				var modes = new List<FocusMode>();
				if (csv != null)
				{
					foreach (var part in csv.Split(','))
					{
						FocusMode mode;
						if (FocusModeHelpers.TryParse(part, out mode))
							modes.Add(mode);
					}
				}

				return modes.Count > 0 ? modes.ToArray() : FocusModeHelpers.All;
			}

			static WhiteBalance[] ParseWhiteBalanceModes(string csv)
			{
				var modes = new List<WhiteBalance>();
				if (csv != null)
				{
					foreach (var part in csv.Split(','))
					{
						WhiteBalance mode;
						if (WhiteBalanceHelpers.TryParse(part, out mode))
							modes.Add(mode);
					}
				}

				return modes.Count > 0 ? modes.ToArray() : WhiteBalanceHelpers.All;
			}

			public void OnReject(string message)
			{
				Reject(new Exception(message));
			}

			static CameraFacing[] GetSupportedFacings()
			{
				var facings = new List<CameraFacing>();
				int cameraId;
				if (CameraFacing.Back.TryGetCameraId(out cameraId))
					facings.Add(CameraFacing.Back);
				if (CameraFacing.Front.TryGetCameraId(out cameraId))
					facings.Add(CameraFacing.Front);
				return facings.ToArray();
			}
		}

		[Foreign(Language.Java)]
		static void GetCameraCapabilitiesNow(Java.Object cameraHandle, Action<bool,float,float,bool,float,float,float,bool,float,float,float,float,string,bool,string> onResolve, Action<string> onReject)
		@{
			try {
				CameraXSession session = (CameraXSession)cameraHandle;
				onResolve.run(
					session.isZoomSupported(),
					session.getMinZoom(),
					session.getMaxZoom(),
					session.isTorchSupported(),
					session.getMinExposureCompensation(),
					session.getMaxExposureCompensation(),
					session.getExposureCompensationStep(),
					session.isManualExposureSupported(),
					session.getMinIso(),
					session.getMaxIso(),
					session.getMinShutterSeconds(),
					session.getMaxShutterSeconds(),
					session.getSupportedWhiteBalanceModes(),
					session.isManualWhiteBalanceSupported(),
					session.getSupportedFocusModes());
			} catch (Exception e) {
				onReject.run(e.getMessage());
			}
		@}

		public Future<float> SetZoom(float zoom)
		{
			var p = new FloatPromise();
			SetZoom(CameraHandle, zoom, p.OnResolve, p.OnReject);
			return p;
		}

		[Foreign(Language.Java)]
		static void SetZoom(Java.Object cameraHandle, float zoom, Action<float> onResolve, Action<string> onReject)
		@{
			((CameraXSession)cameraHandle).setZoom(zoom, new CameraXSession.FloatCallback() {
				public void onResult(float value) { onResolve.run(value); }
				public void onError(String message) { onReject.run(message); }
			});
		@}

		public Future<float> GetZoom()
		{
			var p = new FloatPromise();
			GetZoom(CameraHandle, p.OnResolve, p.OnReject);
			return p;
		}

		[Foreign(Language.Java)]
		static void GetZoom(Java.Object cameraHandle, Action<float> onResolve, Action<string> onReject)
		@{
			try {
				onResolve.run(((CameraXSession)cameraHandle).getZoomNow());
			} catch (Exception e) {
				onReject.run(e.getMessage());
			}
		@}

		public float GetZoomNow()
		{
			return GetZoomNow(CameraHandle);
		}

		[Foreign(Language.Java)]
		static float GetZoomNow(Java.Object cameraHandle)
		@{
			return ((CameraXSession)cameraHandle).getZoomNow();
		@}

		public Future<bool> SetTorchMode(bool on)
		{
			var p = new BoolPromise();
			SetTorchMode(CameraHandle, on, _flashMode.AsString(), p.OnResolve, p.OnReject);
			return p;
		}

		[Foreign(Language.Java)]
		static void SetTorchMode(Java.Object cameraHandle, bool on, string flashMode, Action<bool> onResolve, Action<string> onReject)
		@{
			((CameraXSession)cameraHandle).setTorchMode(on, new CameraXSession.BoolCallback() {
				public void onResult(boolean value) { onResolve.run(value); }
				public void onError(String message) { onReject.run(message); }
			});
		@}

		public Future<bool> IsTorchOn()
		{
			var p = new BoolPromise();
			IsTorchOn(CameraHandle, p.OnResolve, p.OnReject);
			return p;
		}

		[Foreign(Language.Java)]
		static void IsTorchOn(Java.Object cameraHandle, Action<bool> onResolve, Action<string> onReject)
		@{
			try {
				onResolve.run(((CameraXSession)cameraHandle).isTorchOnNow());
			} catch (Exception e) {
				onReject.run(e.getMessage());
			}
		@}

		public bool IsTorchOnNow()
		{
			return IsTorchOnNow(CameraHandle);
		}

		[Foreign(Language.Java)]
		static bool IsTorchOnNow(Java.Object cameraHandle)
		@{
			return ((CameraXSession)cameraHandle).isTorchOnNow();
		@}

		public Future<float> SetExposureCompensation(float value)
		{
			var p = new FloatPromise();
			SetExposureCompensation(CameraHandle, value, p.OnResolve, p.OnReject);
			return p;
		}

		[Foreign(Language.Java)]
		static void SetExposureCompensation(Java.Object cameraHandle, float value, Action<float> onResolve, Action<string> onReject)
		@{
			((CameraXSession)cameraHandle).setExposureCompensation(value, new CameraXSession.FloatCallback() {
				public void onResult(float applied) { onResolve.run(applied); }
				public void onError(String message) { onReject.run(message); }
			});
		@}

		public Future<float> GetExposureCompensation()
		{
			var p = new FloatPromise();
			GetExposureCompensation(CameraHandle, p.OnResolve, p.OnReject);
			return p;
		}

		[Foreign(Language.Java)]
		static void GetExposureCompensation(Java.Object cameraHandle, Action<float> onResolve, Action<string> onReject)
		@{
			try {
				onResolve.run(((CameraXSession)cameraHandle).getExposureCompensationNow());
			} catch (Exception e) {
				onReject.run(e.getMessage());
			}
		@}

		public float GetExposureCompensationNow()
		{
			return GetExposureCompensationNow(CameraHandle);
		}

		[Foreign(Language.Java)]
		static float GetExposureCompensationNow(Java.Object cameraHandle)
		@{
			return ((CameraXSession)cameraHandle).getExposureCompensationNow();
		@}

		public Future<ManualExposureSettings> SetManualExposure(float iso, float shutterSeconds)
		{
			var p = new ManualExposurePromise();
			SetManualExposure(CameraHandle, iso, shutterSeconds, p.OnResolve, p.OnReject);
			return p;
		}

		public Future<ManualExposureSettings> SetAutoExposure()
		{
			var p = new ManualExposurePromise();
			SetAutoExposure(CameraHandle, p.OnResolve, p.OnReject);
			return p;
		}

		public Future<ManualExposureSettings> GetManualExposure()
		{
			var p = new ManualExposurePromise();
			GetManualExposure(CameraHandle, p.OnResolve, p.OnReject);
			return p;
		}

		class ManualExposurePromise : CameraPromise<ManualExposureSettings>
		{
			public void OnResolve(bool isManual, float iso, float shutterSeconds) { Resolve(new ManualExposureSettings(isManual, iso, shutterSeconds)); }
			public void OnReject(string message) { Reject(new Exception(message)); }
		}

		[Foreign(Language.Java)]
		static void SetManualExposure(Java.Object cameraHandle, float iso, float shutterSeconds, Action<bool,float,float> onResolve, Action<string> onReject)
		@{
			((CameraXSession)cameraHandle).setManualExposure(iso, shutterSeconds, new CameraXSession.ManualExposureCallback() {
				public void onResult(boolean isManual, float appliedIso, float appliedShutter) { onResolve.run(isManual, appliedIso, appliedShutter); }
				public void onError(String message) { onReject.run(message); }
			});
		@}

		[Foreign(Language.Java)]
		static void SetAutoExposure(Java.Object cameraHandle, Action<bool,float,float> onResolve, Action<string> onReject)
		@{
			((CameraXSession)cameraHandle).setAutoExposure(new CameraXSession.ManualExposureCallback() {
				public void onResult(boolean isManual, float appliedIso, float appliedShutter) { onResolve.run(isManual, appliedIso, appliedShutter); }
				public void onError(String message) { onReject.run(message); }
			});
		@}

		[Foreign(Language.Java)]
		static void GetManualExposure(Java.Object cameraHandle, Action<bool,float,float> onResolve, Action<string> onReject)
		@{
			try {
				CameraXSession session = (CameraXSession)cameraHandle;
				onResolve.run(session.isManualExposureNow(), session.getManualIsoNow(), session.getManualShutterSecondsNow());
			} catch (Exception e) {
				onReject.run(e.getMessage());
			}
		@}

		public Future<Barcode> ScanBarcode()
		{
			return ScanBarcode(null);
		}

		public Future<WhiteBalance> SetWhiteBalance(WhiteBalance whiteBalance)
		{
			var p = new WhiteBalancePromise();
			SetWhiteBalance(CameraHandle, whiteBalance.AsString(), p.OnResolve, p.OnReject);
			return p;
		}

		public Future<WhiteBalance> GetWhiteBalance()
		{
			var p = new WhiteBalancePromise();
			GetWhiteBalance(CameraHandle, p.OnResolve, p.OnReject);
			return p;
		}

		public Future<WhiteBalanceSettings> SetWhiteBalanceTemperature(float kelvin, float tint)
		{
			var p = new WhiteBalanceSettingsPromise();
			SetWhiteBalanceTemperature(CameraHandle, kelvin, tint, p.OnResolve, p.OnReject);
			return p;
		}

		public Future<WhiteBalanceSettings> GetWhiteBalanceTemperature()
		{
			var p = new WhiteBalanceSettingsPromise();
			GetWhiteBalanceTemperature(CameraHandle, p.OnResolve, p.OnReject);
			return p;
		}

		public Future<FocusMode> SetFocusMode(FocusMode focusMode)
		{
			var p = new FocusModePromise();
			SetFocusMode(CameraHandle, focusMode.AsString(), p.OnResolve, p.OnReject);
			return p;
		}

		public Future<FocusMode> GetFocusMode()
		{
			var p = new FocusModePromise();
			GetFocusMode(CameraHandle, p.OnResolve, p.OnReject);
			return p;
		}

		public FocusMode GetFocusModeNow()
		{
			return FocusModeHelpers.Parse(GetFocusModeString(CameraHandle));
		}

		public Future<MirrorMode> SetMirrorMode(MirrorMode mirrorMode)
		{
			var p = new MirrorModePromise();
			SetMirrorMode(CameraHandle, mirrorMode.AsString(), p.OnResolve, p.OnReject);
			return p;
		}

		public Future<MirrorMode> GetMirrorMode()
		{
			var p = new MirrorModePromise();
			GetMirrorMode(CameraHandle, p.OnResolve, p.OnReject);
			return p;
		}

		public MirrorMode GetMirrorModeNow()
		{
			return MirrorModeHelpers.Parse(GetMirrorModeString(CameraHandle));
		}

		class MirrorModePromise : CameraPromise<MirrorMode>
		{
			public void OnResolve(string mode) { Resolve(MirrorModeHelpers.Parse(mode)); }
			public void OnReject(string message) { Reject(new Exception(message)); }
		}

		public Future<Nothing> StartFaceDetection(Action<DetectedFace[]> onFaces)
		{
			var p = new NothingPromise();
			var collector = new FaceCollector(onFaces);
			StartFaceDetection(CameraHandle, collector.OnFace, collector.OnFrame, p.OnStarted, p.OnReject);
			return p;
		}

		public Future<bool> StopFaceDetection()
		{
			var p = new BoolPromise();
			StopFaceDetection(CameraHandle, p.OnResolve, p.OnReject);
			return p;
		}

		public Future<Nothing> StartFrameAnalysis(FrameAnalysisOptions options, Action<FrameStatistics> onStats)
		{
			var p = new FrameAnalysisPromise(onStats);
			StartFrameAnalysis(CameraHandle,
				options.MaxFps,
				options.Resolution.X, options.Resolution.Y,
				options.LumaWidth, options.LumaHeight,
				p.OnStatistics, p.OnStarted, p.OnReject);
			return p;
		}

		public Future<bool> StopFrameAnalysis()
		{
			var p = new BoolPromise();
			StopFrameAnalysis(CameraHandle, p.OnResolve, p.OnReject);
			return p;
		}

		public Future<OverlayOptions> SetOverlayOptions(OverlayOptions options)
		{
			var p = new OverlayOptionsPromise();
			SetOverlayOptions(CameraHandle, options.Zebra, options.Peaking, p.OnResolve, p.OnReject);
			return p;
		}

		class OverlayOptionsPromise : CameraPromise<OverlayOptions>
		{
			public void OnResolve(double zebra, double peaking) { Resolve(new OverlayOptions(zebra, peaking)); }
			public void OnReject(string message) { Reject(new Exception(message)); }
		}

		class FrameAnalysisPromise : CameraPromise<Nothing>
		{
			readonly Action<FrameStatistics> _onStats;
			Java.Object _statistics;

			public FrameAnalysisPromise(Action<FrameStatistics> onStats)
			{
				_onStats = onStats;
			}

			public void OnStatistics(double timestamp, double mean, double p1, double p50, double p99,
				double clippedLow, double clippedHigh, double analysisTime)
			{
				var statistics = _statistics;
				if (statistics == null)
					return;

				_onStats(new FrameStatistics(
					timestamp, mean, p1, p50, p99, clippedLow, clippedHigh,
					FrameStatistics.HistogramFrom(TakeStatisticsHistogram(statistics)),
					TakeStatisticsLuma(statistics),
					StatisticsLumaWidth(statistics),
					StatisticsLumaHeight(statistics),
					analysisTime));
			}

			public void OnStarted(Java.Object statistics)
			{
				_statistics = statistics;
				Resolve(default(Nothing));
			}

			public void OnReject(string message)
			{
				Reject(new Exception(message));
			}
		}

		[Foreign(Language.Java)]
		static void StartFrameAnalysis(Java.Object cameraHandle, int maxFps, int resolutionWidth, int resolutionHeight,
			int lumaWidth, int lumaHeight,
			Action<double,double,double,double,double,double,double,double> onStatistics,
			Action<Java.Object> onStarted, Action<string> onStartError)
		@{
			((CameraXSession)cameraHandle).startFrameAnalysis(maxFps, resolutionWidth, resolutionHeight, lumaWidth, lumaHeight,
				new CameraXSession.StatisticsCallback() {
					public void onStatistics(double timestamp, double mean, double p1, double p50, double p99,
						double clippedLow, double clippedHigh, double analysisTime) {
						onStatistics.run(timestamp, mean, p1, p50, p99, clippedLow, clippedHigh, analysisTime);
					}
				},
				new CameraXSession.StatisticsStartCallback() {
					public void onStarted(Object statistics) { onStarted.run(statistics); }
					public void onError(String message) { onStartError.run(message); }
				});
		@}

		[Foreign(Language.Java)]
		static void StopFrameAnalysis(Java.Object cameraHandle, Action<bool> onResolve, Action<string> onReject)
		@{
			((CameraXSession)cameraHandle).stopFrameAnalysis(new CameraXSession.BoolCallback() {
				public void onResult(boolean wasAnalysing) { onResolve.run(wasAnalysing); }
				public void onError(String message) { onReject.run(message); }
			});
		@}

		[Foreign(Language.Java)]
		static byte[] TakeStatisticsHistogram(Java.Object statistics)
		@{
			byte[] histogram = CameraXSession.takeStatisticsHistogram(statistics);
			return histogram == null ? null : new ByteArray(histogram);
		@}

		[Foreign(Language.Java)]
		static byte[] TakeStatisticsLuma(Java.Object statistics)
		@{
			byte[] luma = CameraXSession.takeStatisticsLuma(statistics);
			return luma == null ? null : new ByteArray(luma);
		@}

		[Foreign(Language.Java)]
		static int StatisticsLumaWidth(Java.Object statistics)
		@{
			return CameraXSession.statisticsLumaWidth(statistics);
		@}

		[Foreign(Language.Java)]
		static int StatisticsLumaHeight(Java.Object statistics)
		@{
			return CameraXSession.statisticsLumaHeight(statistics);
		@}

		[Foreign(Language.Java)]
		static void SetOverlayOptions(Java.Object cameraHandle, double zebra, double peaking, Action<double,double> onResolve, Action<string> onReject)
		@{
			((CameraXSession)cameraHandle).setOverlayOptions(zebra, peaking, new CameraXSession.OverlayOptionsCallback() {
				public void onResult(double appliedZebra, double appliedPeaking) { onResolve.run(appliedZebra, appliedPeaking); }
				public void onError(String message) { onReject.run(message); }
			});
		@}

		public Future<Nothing> StartErrorMonitoring(Action<CameraEvent> onEvent)
		{
			var p = new NothingPromise();
			StartErrorMonitoring(CameraHandle,
				(type, reason, message) => onEvent(new CameraEvent(type, reason, message)),
				p.OnStarted,
				p.OnReject);
			return p;
		}

		public Future<bool> StopErrorMonitoring()
		{
			var p = new BoolPromise();
			StopErrorMonitoring(CameraHandle, p.OnResolve, p.OnReject);
			return p;
		}

		[Foreign(Language.Java)]
		static void StartErrorMonitoring(Java.Object cameraHandle, Action<string,string,string> onEvent, Action onStarted, Action<string> onStartError)
		@{
			((CameraXSession)cameraHandle).startErrorMonitoring(new CameraXSession.CameraEventCallback() {
				public void onEvent(String type, String reason, String message) { onEvent.run(type, reason, message); }
			}, new CameraXSession.StartCallback() {
				public void onStarted() { onStarted.run(); }
				public void onError(String message) { onStartError.run(message); }
			});
		@}

		[Foreign(Language.Java)]
		static void StopErrorMonitoring(Java.Object cameraHandle, Action<bool> onResolve, Action<string> onReject)
		@{
			((CameraXSession)cameraHandle).stopErrorMonitoring(new CameraXSession.BoolCallback() {
				public void onResult(boolean wasMonitoring) { onResolve.run(wasMonitoring); }
				public void onError(String message) { onReject.run(message); }
			});
		@}

		class FocusModePromise : CameraPromise<FocusMode>
		{
			public void OnResolve(string mode) { Resolve(FocusModeHelpers.Parse(mode)); }
			public void OnReject(string message) { Reject(new Exception(message)); }
		}

		class WhiteBalanceSettingsPromise : CameraPromise<WhiteBalanceSettings>
		{
			public void OnResolve(bool isManual, float kelvin, float tint) { Resolve(new WhiteBalanceSettings(isManual, kelvin, tint)); }
			public void OnReject(string message) { Reject(new Exception(message)); }
		}

		public WhiteBalance GetWhiteBalanceNow()
		{
			return WhiteBalanceHelpers.Parse(GetWhiteBalanceString(CameraHandle));
		}

		class WhiteBalancePromise : CameraPromise<WhiteBalance>
		{
			public void OnResolve(string mode) { Resolve(WhiteBalanceHelpers.Parse(mode)); }
			public void OnReject(string message) { Reject(new Exception(message)); }
		}

		[Foreign(Language.Java)]
		static void SetWhiteBalance(Java.Object cameraHandle, string mode, Action<string> onResolve, Action<string> onReject)
		@{
			((CameraXSession)cameraHandle).setWhiteBalance(mode, new CameraXSession.StringCallback() {
				public void onResult(String appliedMode) { onResolve.run(appliedMode); }
				public void onError(String message) { onReject.run(message); }
			});
		@}

		[Foreign(Language.Java)]
		static void GetWhiteBalance(Java.Object cameraHandle, Action<string> onResolve, Action<string> onReject)
		@{
			try {
				onResolve.run(((CameraXSession)cameraHandle).getWhiteBalanceNow());
			} catch (Exception e) {
				onReject.run(e.getMessage());
			}
		@}

		[Foreign(Language.Java)]
		static string GetWhiteBalanceString(Java.Object cameraHandle)
		@{
			return ((CameraXSession)cameraHandle).getWhiteBalanceNow();
		@}

		[Foreign(Language.Java)]
		static void SetWhiteBalanceTemperature(Java.Object cameraHandle, float kelvin, float tint, Action<bool,float,float> onResolve, Action<string> onReject)
		@{
			((CameraXSession)cameraHandle).setWhiteBalanceTemperature(kelvin, tint, new CameraXSession.WhiteBalanceSettingsCallback() {
				public void onResult(boolean isManual, float appliedKelvin, float appliedTint) { onResolve.run(isManual, appliedKelvin, appliedTint); }
				public void onError(String message) { onReject.run(message); }
			});
		@}

		[Foreign(Language.Java)]
		static void GetWhiteBalanceTemperature(Java.Object cameraHandle, Action<bool,float,float> onResolve, Action<string> onReject)
		@{
			try {
				CameraXSession session = (CameraXSession)cameraHandle;
				onResolve.run(session.isManualWhiteBalanceNow(), session.getWhiteBalanceKelvinNow(), session.getWhiteBalanceTintNow());
			} catch (Exception e) {
				onReject.run(e.getMessage());
			}
		@}

		[Foreign(Language.Java)]
		static void SetFocusMode(Java.Object cameraHandle, string mode, Action<string> onResolve, Action<string> onReject)
		@{
			((CameraXSession)cameraHandle).setFocusMode(mode, new CameraXSession.StringCallback() {
				public void onResult(String appliedMode) { onResolve.run(appliedMode); }
				public void onError(String message) { onReject.run(message); }
			});
		@}

		[Foreign(Language.Java)]
		static void GetFocusMode(Java.Object cameraHandle, Action<string> onResolve, Action<string> onReject)
		@{
			try {
				onResolve.run(((CameraXSession)cameraHandle).getFocusModeNow());
			} catch (Exception e) {
				onReject.run(e.getMessage());
			}
		@}

		[Foreign(Language.Java)]
		static string GetFocusModeString(Java.Object cameraHandle)
		@{
			return ((CameraXSession)cameraHandle).getFocusModeNow();
		@}

		[Foreign(Language.Java)]
		static void SetMirrorMode(Java.Object cameraHandle, string mode, Action<string> onResolve, Action<string> onReject)
		@{
			((CameraXSession)cameraHandle).setMirrorMode(mode, new CameraXSession.StringCallback() {
				public void onResult(String appliedMode) { onResolve.run(appliedMode); }
				public void onError(String message) { onReject.run(message); }
			});
		@}

		[Foreign(Language.Java)]
		static void GetMirrorMode(Java.Object cameraHandle, Action<string> onResolve, Action<string> onReject)
		@{
			try {
				onResolve.run(((CameraXSession)cameraHandle).getMirrorModeNow());
			} catch (Exception e) {
				onReject.run(e.getMessage());
			}
		@}

		[Foreign(Language.Java)]
		static string GetMirrorModeString(Java.Object cameraHandle)
		@{
			return ((CameraXSession)cameraHandle).getMirrorModeNow();
		@}

		[Foreign(Language.Java)]
		static void StartFaceDetection(Java.Object cameraHandle, Action<int,float,float,float,float,float,float> onFace, Action onFrame, Action onStarted, Action<string> onStartError)
		@{
			((CameraXSession)cameraHandle).startFaceDetection(new CameraXSession.FaceCallback() {
				public void onFace(int id, float x, float y, float width, float height, float roll, float yaw) { onFace.run(id, x, y, width, height, roll, yaw); }
				public void onFrame() { onFrame.run(); }
			}, new CameraXSession.StartCallback() {
				public void onStarted() { onStarted.run(); }
				public void onError(String message) { onStartError.run(message); }
			});
		@}

		[Foreign(Language.Java)]
		static void StopFaceDetection(Java.Object cameraHandle, Action<bool> onResolve, Action<string> onReject)
		@{
			((CameraXSession)cameraHandle).stopFaceDetection(new CameraXSession.BoolCallback() {
				public void onResult(boolean wasDetecting) { onResolve.run(wasDetecting); }
				public void onError(String message) { onReject.run(message); }
			});
		@}

		public Future<Barcode> ScanBarcode(string[] formats)
		{
			var p = new ScanBarcodePromise();
			ScanBarcode(CameraHandle, NormalizeBarcodeFormats(formats), p.OnResolve, p.OnReject);
			return p;
		}

		class ScanBarcodePromise : CameraPromise<Barcode>
		{
			public void OnResolve(string value, string format) { Resolve(new Barcode(value, format)); }
			public void OnReject(string message) { Reject(new Exception(message)); }
		}

		[Foreign(Language.Java)]
		static void ScanBarcode(Java.Object cameraHandle, string[] formats, Action<string,string> onResolve, Action<string> onReject)
		@{
			((CameraXSession)cameraHandle).scanBarcode(formats.copyArray(), new CameraXSession.BarcodeCallback() {
				public void onResult(String value, String format) { onResolve.run(value, format); }
				public void onError(String message) { onReject.run(message); }
			});
		@}

		public Future<Nothing> StartBarcodeScanning(Action<Barcode> onDetected, string[] formats)
		{
			var p = new NothingPromise();
			StartBarcodeScanning(CameraHandle, NormalizeBarcodeFormats(formats),
				(value, format) => onDetected(new Barcode(value, format)),
				p.OnStarted,
				p.OnReject);
			return p;
		}

		static string[] NormalizeBarcodeFormats(string[] formats)
		{
			return formats != null ? formats : new string[0];
		}

		[Foreign(Language.Java)]
		static void StartBarcodeScanning(Java.Object cameraHandle, string[] formats, Action<string,string> onDetected, Action onStarted, Action<string> onStartError)
		@{
			((CameraXSession)cameraHandle).startBarcodeScanning(formats.copyArray(), new CameraXSession.BarcodeCallback() {
				public void onResult(String value, String format) { onDetected.run(value, format); }
				public void onError(String message) { }
			}, new CameraXSession.StartCallback() {
				public void onStarted() { onStarted.run(); }
				public void onError(String message) { onStartError.run(message); }
			});
		@}

		public Future<bool> StopBarcodeScanning()
		{
			var p = new BoolPromise();
			StopBarcodeScanning(CameraHandle, p.OnResolve, p.OnReject);
			return p;
		}

		[Foreign(Language.Java)]
		static void StopBarcodeScanning(Java.Object cameraHandle, Action<bool> onResolve, Action<string> onReject)
		@{
			((CameraXSession)cameraHandle).stopBarcodeScanning(new CameraXSession.BoolCallback() {
				public void onResult(boolean wasScanning) { onResolve.run(wasScanning); }
				public void onError(String message) { onReject.run(message); }
			});
		@}

		bool SupportsSize(int2 size)
		{
			foreach (var s in PictureSizes)
				if (s == size)
					return true;
			return false;
		}

		[Foreign(Language.Java)]
		void GetSupportedPictureSizes(Java.Object handle, int[] output)
		@{
			int[] sizes = ((CameraXSession)handle).getSupportedPictureSizes();
			for (int i = 0; i < sizes.length; i++)
				output.set(i, sizes[i]);
		@}

		[Foreign(Language.Java)]
		int GetSupportedPictureSizesCount(Java.Object handle)
		@{
			return ((CameraXSession)handle).getSupportedPictureSizesCount();
		@}

		[Foreign(Language.Java)]
		void UpdatePreviewStretchMode(bool shouldFill)
		@{
			((CameraImpl)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()}).updateStretchMode(shouldFill);
		@}

		[Foreign(Language.Java)]
		void SetFlashMode(Java.Object handle, string flashMode)
		@{
			((CameraImpl)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()}).setFlashMode(flashMode);
		@}

		[Foreign(Language.Java)]
		void SetCameraFocusPointNow(double x, double y, int cameraWidth, int cameraHeight, int isFocusLocked)
		@{
			((CameraImpl)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()}).setCameraFocusPoint(x,y,cameraWidth,cameraHeight, isFocusLocked);
		@}

		[Foreign(Language.Java)]
		void TakePicture(Action<Java.Object> resolve, Action<string> reject)
		@{
			((CameraImpl)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()}).takePicture(new IPictureCallback() {
				public void onPictureTaken(byte[] data) {
					resolve.run(data);
				}
				public void onError(Exception e) {
					reject.run(e.getMessage());
				}
			});
		@}

		[Foreign(Language.Java)]
		void StartRecording(Action<Java.Object> resolve, Action<string> reject, int width, int height, int frameRate, int bitRate, bool audioEnabled, bool stabilizationEnabled)
		@{
			((CameraImpl)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()}).startRecording(new IStartRecordingSession() {
				public void onSuccess(RecordingSession recordingSession) {
					resolve.run(recordingSession);
				}
				public void onException(String message) {
					reject.run(message);
				}
			}, width, height, frameRate, bitRate, audioEnabled, stabilizationEnabled);
		@}

		[Foreign(Language.Java)]
		string SaveParameters()
		@{
			return ((CameraImpl)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()}).saveParameters();
		@}

		[Foreign(Language.Java)]
		void RestoreParameters(string parameters)
		@{
			((CameraImpl)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()}).restoreParameters(parameters);
		@}

		[Foreign(Language.Java)]
		void SetPictureSize(int width, int height)
		@{
			((CameraImpl)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()}).setPictureSize(width, height);
		@}

		[Foreign(Language.Java)]
		static void Release(Java.Object handle)
		@{
			((CameraXSession)handle).dispose();
		@}

		[Foreign(Language.Java)]
		static void Dispose(Java.Object handle)
		@{
			((CameraImpl)handle).dispose();
		@}

		[Foreign(Language.Java)]
		static Java.Object Create(Java.Object session, int cameraId, int maxWidth, int maxHeight)
		@{
			CameraImpl view = new CameraImpl(com.fuse.Activity.getRootActivity(), (CameraXSession)session);
			view.setLayoutParams(new android.widget.FrameLayout.LayoutParams(android.view.ViewGroup.LayoutParams.MATCH_PARENT, android.view.ViewGroup.LayoutParams.MATCH_PARENT));
			return view;
		@}
	}

	[ForeignInclude(Language.Java,
		"com.fuse.controls.cameraview.CameraXSession")]
	extern(ANDROID) internal static class FlashModeExtensions
	{
		public static bool IsSupported(this FlashMode flashMode, Camera camera)
		{
			return IsSupported(flashMode.AsString(), camera.CameraHandle);
		}

		[Foreign(Language.Java)]
		static bool IsSupported(string flashMode, Java.Object cameraHandle)
		@{
			return ((CameraXSession)cameraHandle).isFlashModeSupported(flashMode);
		@}

		public static string AsString(this FlashMode flashMode)
		{
			switch (flashMode)
			{
				case FlashMode.Auto:
					return "auto";
				case FlashMode.On:
					return "on";
				case FlashMode.Off:
					return "off";
				default:
					throw new Exception("Unexpected FlashMode: " + flashMode);
			}
		}
	}
}
