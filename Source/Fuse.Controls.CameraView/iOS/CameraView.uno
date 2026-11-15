using Uno;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;
using Fuse.Android.Permissions;
using Uno.Threading;
using Uno.Collections;

using Fuse;
using Fuse.Controls;
using Fuse.Controls.Native;
using Fuse.Controls.CameraView;

namespace Fuse.Controls.iOS
{
	extern(!iOS) class CameraView
	{
		[UXConstructor]
		public CameraView([UXParameter("Host")]ICameraViewHost host) { }
	}

	extern(iOS) class NativeRecording : Recording
	{
		public NativeRecording(string filePath) : base(filePath)
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
			GetMetadata(FilePath, p.OnResolve, p.OnReject);
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

			public void OnResolve(string path) { Resolve(path); }
			public void OnReject(string msg) { Reject(new Exception(msg)); }
		}

		class MetadataPromise : CameraPromise<RecordingMetadata>
		{
			public void OnResolve(int width, int height, int duration, double fileSize)
			{
				Resolve(new RecordingMetadata(width, height, duration, fileSize));
			}

			public void OnReject(string msg) { Reject(new Exception(msg)); }
		}

		[Require("source.include", "AVFoundation/AVFoundation.h")]
		[Require("source.include", "UIKit/UIKit.h")]
		[Require("source.include", "math.h")]
		[Require("xcode.framework", "AVFoundation")]
		[Foreign(Language.ObjC)]
		static void SaveThumbnail(string filePath, Action<string> resolve, Action<string> reject, bool useSizeHint, float widthHint, float heightHint)
		@{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				AVURLAsset* asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:filePath] options:nil];
				AVAssetImageGenerator* generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
				generator.appliesPreferredTrackTransform = YES;

				if (useSizeHint) {
					generator.maximumSize = CGSizeMake(widthHint, heightHint);
				} else {
					CGRect screenBounds = [[UIScreen mainScreen] bounds];
					CGFloat screenScale = [[UIScreen mainScreen] scale];
					generator.maximumSize = CGSizeMake((screenBounds.size.width * screenScale) / 2, (screenBounds.size.height * screenScale) / 2);
				}

				NSError* error = nil;
				CGImageRef image = [generator copyCGImageAtTime:kCMTimeZero actualTime:NULL error:&error];
				if (!image) {
					reject([NSString stringWithFormat:@"Failed to generate a video thumbnail: %@", error]);
					return;
				}

				UIImage* thumbnail = [UIImage imageWithCGImage:image];
				CGImageRelease(image);

				NSData* data = UIImageJPEGRepresentation(thumbnail, 1.0f);
				if (!data) {
					reject(@"Failed to encode the video thumbnail");
					return;
				}

				NSString* dir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
				NSString* path = [NSString stringWithFormat:@"%@/IMG_%@.jpg", dir, [[NSUUID UUID] UUIDString]];

				NSError* writeError = nil;
				if (![data writeToFile:path options:NSDataWritingWithoutOverwriting error:&writeError])
					reject([NSString stringWithFormat:@"Failed to save the video thumbnail: %@", writeError]);
				else
					resolve(path);
			});
		@}

		[Require("source.include", "AVFoundation/AVFoundation.h")]
		[Require("source.include", "math.h")]
		[Require("xcode.framework", "AVFoundation")]
		[Foreign(Language.ObjC)]
		static void GetMetadata(string filePath, Action<int,int,int,double> onResolve, Action<string> onReject)
		@{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				AVURLAsset* asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:filePath] options:nil];

				int duration = 0;
				CMTime assetDuration = asset.duration;
				if (CMTIME_IS_VALID(assetDuration))
					duration = (int)llround(CMTimeGetSeconds(assetDuration) * 1000.0);

				int width = 0;
				int height = 0;
				NSArray<AVAssetTrack*>* tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
				if (tracks.count > 0) {
					AVAssetTrack* track = tracks[0];
					CGSize displayed = CGSizeApplyAffineTransform(track.naturalSize, track.preferredTransform);
					width = (int)llround(fabs(displayed.width));
					height = (int)llround(fabs(displayed.height));
				}

				double fileSize = 0.0;
				NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:NULL];
				if (attributes)
					fileSize = [attributes[NSFileSize] doubleValue];

				onResolve(width, height, duration, fileSize);
			});
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
			public void OnReject(string msg) { Reject(new Exception(msg)); }
		}

		[Require("xcode.framework", "Photos")]
		[Require("source.include", "Photos/PHPhotoLibrary.h")]
		[Require("source.include", "Photos/PHAssetChangeRequest.h")]
		[Foreign(Language.ObjC)]
		static void SaveToCameraRoll(string filePath, Action<bool> onResolve, Action<string> onReject)
		@{
			[PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
				BOOL authorized = status == PHAuthorizationStatusAuthorized;
				if (@available(iOS 14.0, *))
					authorized = authorized || status == PHAuthorizationStatusLimited;

				if (!authorized) {
					onReject(@"Photo library permission denied");
					return;
				}

				NSURL* url = [NSURL fileURLWithPath:filePath];
				[[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
					[PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
				} completionHandler:^(BOOL success, NSError* error) {
					if (success)
						onResolve(YES);
					else
						onReject(error.localizedDescription ?: @"Failed to save video to camera roll");
				}];
			}];
		@}
	}

	[Require("source.include", "iOS/RecordingSession.h")]
	extern(iOS) class NativeRecordingSession : RecordingSession, IDisposable
	{

		ObjC.Object _handle;

		public NativeRecordingSession(ObjC.Object handle)
		{
			_handle = handle;
		}

		class StopClosure : CameraPromise<Recording>
		{
			public void OnResolve(string filePath) { Resolve(new NativeRecording(filePath)); }
			public void OnReject(string msg) { Reject(new Exception(msg)); }
		}

		public override Future<Recording> Stop()
		{
			var p = new StopClosure();
			Stop(_handle, p.OnResolve, p.OnReject);
			return p;
		}

		public override Future<bool> Pause()
		{
			var p = new BoolClosure();
			Pause(_handle, p.OnResolve, p.OnReject);
			return p;
		}

		public override Future<bool> Resume()
		{
			var p = new BoolClosure();
			Resume(_handle, p.OnResolve, p.OnReject);
			return p;
		}

		class BoolClosure : CameraPromise<bool>
		{
			public void OnResolve(bool value) { Resolve(value); }
			public void OnReject(string msg) { Reject(new Exception(msg)); }
		}

		public override Future<int> GetDuration()
		{
			var p = new DurationClosure();
			GetDuration(_handle, p.OnResolve, p.OnReject);
			return p;
		}

		class DurationClosure : CameraPromise<int>
		{
			public void OnResolve(int duration) { Resolve(duration); }
			public void OnReject(string msg) { Reject(new Exception(msg)); }
		}

		void IDisposable.Dispose()
		{
			Stop();
		}

		[Foreign(Language.ObjC)]
		static void Stop(ObjC.Object handle, Action<string> resolve, Action<string> reject)
		@{
			[((::RecordingSession*)handle) stopRecording:resolve onReject:reject];
		@}

		[Foreign(Language.ObjC)]
		static void GetDuration(ObjC.Object handle, Action<int> onResolve, Action<string> onReject)
		@{
			onResolve((int)[((::RecordingSession*)handle) durationMilliseconds]);
		@}

		[Foreign(Language.ObjC)]
		static void Pause(ObjC.Object handle, Action<bool> onResolve, Action<string> onReject)
		@{
			[((::RecordingSession*)handle) pauseRecording:onResolve onReject:onReject];
		@}

		[Foreign(Language.ObjC)]
		static void Resume(ObjC.Object handle, Action<bool> onResolve, Action<string> onReject)
		@{
			[((::RecordingSession*)handle) resumeRecording:onResolve onReject:onReject];
		@}

		public static RecordingSession New(ObjC.Object handle)
		{
			return new NativeRecordingSession(handle);
		}
	}

	[Require("source.include", "iOS/CameraPreview.h")]
	[Require("source.include", "iOS/CameraViewImpl.h")]
	extern(iOS) class NativeCamera : ICamera
	{
		static readonly int CaptureModePhoto = extern<int>"fcv::CAPTURE_MODE_PHOTO";
		static readonly int CaptureModeVideo = extern<int>"fcv::CAPTURE_MODE_VIDEO";

		static readonly int CameraFacingFront = extern<int>"fcv::CAMERA_FACING_FRONT";
		static readonly int CameraFacingBack = extern<int>"fcv::CAMERA_FACING_BACK";

		static readonly int FlashModeAuto = extern<int>"fcv::FLASH_MODE_AUTO";
		static readonly int FlashModeOn = extern<int>"fcv::FLASH_MODE_ON";
		static readonly int FlashModeOff = extern<int>"fcv::FLASH_MODE_OFF";

		IntPtr _handle;

		NativeCamera(IntPtr handle)
		{
			_handle = handle;
		}

		class LoadClosure : CameraPromise<NativeCamera>
		{
			public IntPtr DisposeHandle;

			public void OnResolve(IntPtr handle)
			{
				if (!_cancelled)
					Resolve(new NativeCamera(handle));
			}

			public void OnReject(string msg)
			{
				if (!_cancelled)
					Reject(new Exception(msg));
			}

			bool _cancelled = false;
			public override void Cancel(bool shutdownGracefully = false)
			{
				if (!_cancelled)
				{
					NativeCamera.Dispose(DisposeHandle);
					DisposeHandle = IntPtr.Zero;
					_cancelled = true;
				}
			}
		}

		public static Future<NativeCamera> Load(ObjC.Object cameraPreview)
		{
			var p = new LoadClosure();
			p.DisposeHandle = LoadCameraView(cameraPreview, p.OnResolve, p.OnReject);
			return p;
		}

		class BoolClosure : CameraPromise<bool>
		{
			public void OnResolve(bool value) { Resolve(value); }
			public void OnReject(string msg) { Reject(new Exception(msg)); }
		}

		class FloatClosure : CameraPromise<float>
		{
			public void OnResolve(float value) { Resolve(value); }
			public void OnReject(string msg) { Reject(new Exception(msg)); }
		}

		class StartClosure : CameraPromise<Nothing>
		{
			public void OnStarted(string error)
			{
				if (error == null)
					Resolve(default(Nothing));
				else
					Reject(new Exception(error));
			}
		}

		class CapturePhotoClosure : CameraPromise<Photo>
		{
			public void OnResolve(ObjC.Object imageData, int orientation) { Resolve(new NativePhoto(imageData, orientation)); }
			public void OnReject(string msg) { Reject(new Exception(msg)); }
		}

		public Future<Photo> CapturePhoto()
		{
			var p = new CapturePhotoClosure();
			CapturePhoto(_handle, p.OnResolve, p.OnReject);
			return p;
		}

		class StartRecordingClosure : CameraPromise<RecordingSession>
		{
			Action<IDisposable> _setRecordingSession;

			public StartRecordingClosure(Action<IDisposable> setRecordingSession)
			{
				_setRecordingSession = setRecordingSession;
			}

			public void OnResolve(ObjC.Object recordingSession)
			{
				var s = new NativeRecordingSession(recordingSession);
				_setRecordingSession(s);
				Resolve(s);
			}

			public void OnReject(string msg) { Reject(new Exception(msg)); }
		}

		IDisposable _recordingSession = null;
		void SetRecordingSession(IDisposable recordingSession)
		{
			_recordingSession = recordingSession;
		}

		public Future<RecordingSession> StartRecording()
		{
			var p = new StartRecordingClosure(SetRecordingSession);
			StartRecording(_handle, p.OnResolve, p.OnReject);
			return p;
		}

		class SetCaptureModeClosure : CameraPromise<CaptureMode>
		{
			public void OnResolve(int captureMode) { Resolve(IntToCaptureMode(captureMode)); }
			public void OnReject(string msg) { Reject(new Exception(msg)); }
		}

		public Future<CaptureMode> SetCaptureMode(CaptureMode mode)
		{
			var p = new SetCaptureModeClosure();
			SetCaptureMode(_handle, CaptureModeToInt(mode), p.OnResolve, p.OnReject);
			return p;
		}

		class SetCameraFacingClosure : CameraPromise<CameraFacing>
		{
			public void OnResolve(int cameraFacing) { Resolve(IntToCameraFacing(cameraFacing)); }
			public void OnReject(string msg) { Reject(new Exception(msg)); }
		}

		public Future<CameraFacing> SetCameraFacing(CameraFacing facing)
		{
			var p = new SetCameraFacingClosure();
			SetCameraFacing(_handle, CameraFacingToInt(facing), p.OnResolve, p.OnReject);
			return p;
		}

		class SetCameraFocusPointClosure : CameraPromise<Nothing>
		{
			public void OnResolve(Nothing nothing) { Resolve(default(Nothing)); }
			public void OnReject(string msg) { Reject(new Exception(msg)); }
		}

		public Future<Nothing> SetCameraFocusPoint(double x, double y, int cameraWidth, int cameraHeight, int isFocusLocked)
		{
			var p = new SetCameraFocusPointClosure();
			SetCameraFocusPoint(_handle, x, y, cameraWidth, cameraHeight, isFocusLocked, p.OnResolve, p.OnReject);
			return p;
		}

		class SetFlashModeClosure : CameraPromise<FlashMode>
		{
			public void OnResolve(int flashMode) { Resolve(IntToFlashMode(flashMode)); }
			public void OnReject(string msg) { Reject(new Exception(msg)); }
		}

		public Future<FlashMode> SetFlashMode(FlashMode flashMode)
		{
			var p = new SetFlashModeClosure();
			SetFlashMode(_handle, FlashModeToInt(flashMode), p.OnResolve, p.OnReject);
			return p;
		}

		class GetCameraInfoClosure : CameraPromise<CameraInfo>
		{
			public void OnResolve(int captureMode, int flashMode, int cameraFacing, ObjC.Object supportedFlashModes, ObjC.Object photoResolutions, float zoom, bool torchOn, float exposureCompensation, ObjC.Object lensId, ObjC.Object whiteBalance, ObjC.Object focusMode, ObjC.Object mirrorMode)
			{
				Resolve(new CameraInfo(
					IntToFlashMode(flashMode),
					IntToCameraFacing(cameraFacing),
					IntToCaptureMode(captureMode),
					NativeCamera.GetPhotoResolutions(photoResolutions),
					NativeCamera.GetFlashModes(supportedFlashModes),
					zoom,
					torchOn,
					exposureCompensation,
					NativeCamera.ObjCStringToString(lensId),
					WhiteBalanceHelpers.Parse(NativeCamera.ObjCStringToString(whiteBalance)),
					FocusModeHelpers.Parse(NativeCamera.ObjCStringToString(focusMode)),
					MirrorModeHelpers.Parse(NativeCamera.ObjCStringToString(mirrorMode))));
			}
		}

		class GetCameraCapabilitiesClosure : CameraPromise<CameraCapabilities>
		{
			public void OnResolve(bool zoomSupported, float minZoom, float maxZoom, bool torchSupported, float minExposure, float maxExposure, float exposureStep, bool manualExposureSupported, float minIso, float maxIso, float minShutter, float maxShutter, ObjC.Object supportedFlashModes, ObjC.Object photoResolutions, ObjC.Object supportedFacings, bool manualWhiteBalanceSupported)
			{
				Resolve(new CameraCapabilities(
					zoomSupported,
					minZoom,
					maxZoom,
					torchSupported,
					NativeCamera.GetPhotoResolutions(photoResolutions),
					NativeCamera.GetFlashModes(supportedFlashModes),
					NativeCamera.GetCameraFacings(supportedFacings),
					minExposure,
					maxExposure,
					exposureStep,
					manualExposureSupported,
					minIso,
					maxIso,
					minShutter,
					maxShutter,
					WhiteBalanceHelpers.All,
					manualWhiteBalanceSupported,
					FocusModeHelpers.All));
			}
		}

		static FlashMode[] GetFlashModes(ObjC.Object array)
		{
			var len = NSArrayLength(array);
			var result = new FlashMode[len];
			for (var i = 0; i < len; i++)
				result[i] = (FlashMode)NSArrayGetElement(array, i);
			return result;
		}

		static int2[] GetPhotoResolutions(ObjC.Object array)
		{
			var len = NSArrayLength(array);
			var result = new int2[len];
			for (var i = 0; i < len; i++)
				result[i] = NSArrayGetPhotoResolution(array, i);
			return result;
		}

		static CameraFacing[] GetCameraFacings(ObjC.Object array)
		{
			var len = NSArrayLength(array);
			var result = new CameraFacing[len];
			for (var i = 0; i < len; i++)
				result[i] = (CameraFacing)NSArrayGetElement(array, i);
			return result;
		}

		[Foreign(Language.ObjC)]
		static int NSArrayLength(ObjC.Object array)
		@{
			return (int)((NSArray*)array).count;
		@}

		[Require("source.include", "iOS/CameraViewImpl.h")]
		[Foreign(Language.ObjC)]
		static int NSArrayGetElement(ObjC.Object array, int index)
		@{
			return [(NSArray<NSNumber*>*)array objectAtIndex:index].intValue;
		@}

		[Require("source.include", "iOS/CameraViewImpl.h")]
		[Foreign(Language.ObjC)]
		static int2 NSArrayGetPhotoResolution(ObjC.Object array, int index)
		@{
			CGSize size = [(NSValue*)[(NSArray*)array objectAtIndex:index] CGSizeValue];
			return @{int2(int,int):new((int)size.width, (int)size.height)};
		@}

		[Require("source.include", "Foundation/Foundation.h")]
		[Foreign(Language.ObjC)]
		static string NSArrayGetString(ObjC.Object array, int index)
		@{
			return [(NSArray<NSString*>*)array objectAtIndex:index];
		@}

		[Require("source.include", "Foundation/Foundation.h")]
		[Foreign(Language.ObjC)]
		static string ObjCStringToString(ObjC.Object value)
		@{
			return (NSString*)value;
		@}

		public Future<CameraInfo> GetCameraInfo()
		{
			var p = new GetCameraInfoClosure();
			GetCameraInfo(_handle, p.OnResolve);
			return p;
		}

		public Future<CameraCapabilities> GetCameraCapabilities()
		{
			var p = new GetCameraCapabilitiesClosure();
			GetCameraCapabilities(_handle, p.OnResolve);
			return p;
		}

		public Future<Nothing> SetVideoOptions(VideoOptions options)
		{
			var p = new SetVideoOptionsClosure();
			SetVideoOptions(
				_handle,
				options.Resolution.X,
				options.Resolution.Y,
				options.FrameRate,
				options.BitRate,
				options.AudioEnabled,
				options.StabilizationEnabled,
				p.OnResolve,
				p.OnReject);
			return p;
		}

		class SetVideoOptionsClosure : CameraPromise<Nothing>
		{
			public void OnResolve(bool success) { Resolve(default(Nothing)); }
			public void OnReject(string msg) { Reject(new Exception(msg)); }
		}

		public Future<float> SetZoom(float zoom)
		{
			var p = new FloatClosure();
			SetZoom(_handle, zoom, p.OnResolve, p.OnReject);
			return p;
		}

		public Future<float> GetZoom()
		{
			var p = new FloatClosure();
			GetZoom(_handle, p.OnResolve, p.OnReject);
			return p;
		}

		public Future<bool> SetTorchMode(bool on)
		{
			var p = new BoolClosure();
			SetTorchMode(_handle, on, p.OnResolve, p.OnReject);
			return p;
		}

		public Future<bool> IsTorchOn()
		{
			var p = new BoolClosure();
			IsTorchOn(_handle, p.OnResolve, p.OnReject);
			return p;
		}

		public Future<float> SetExposureCompensation(float value)
		{
			var p = new FloatClosure();
			SetExposureCompensation(_handle, value, p.OnResolve, p.OnReject);
			return p;
		}

		public Future<float> GetExposureCompensation()
		{
			var p = new FloatClosure();
			GetExposureCompensation(_handle, p.OnResolve, p.OnReject);
			return p;
		}

		public Future<CameraLens[]> GetAvailableLenses()
		{
			var p = new LensesClosure();
			GetAvailableLenses(_handle, p.OnResolve);
			return p;
		}

		class LensesClosure : CameraPromise<CameraLens[]>
		{
			public void OnResolve(ObjC.Object ids, ObjC.Object facings, ObjC.Object names)
			{
				Resolve(NativeCamera.ToLenses(ids, facings, names));
			}
		}

		static CameraLens[] ToLenses(ObjC.Object ids, ObjC.Object facings, ObjC.Object names)
		{
			var len = NSArrayLength(ids);
			var result = new CameraLens[len];
			for (var i = 0; i < len; i++)
				result[i] = new CameraLens(
					NSArrayGetString(ids, i),
					(CameraFacing)NSArrayGetElement(facings, i),
					NSArrayGetString(names, i));
			return result;
		}

		public Future<string> SetCameraLens(string lensId)
		{
			var p = new SetCameraLensClosure();
			SetCameraLens(_handle, lensId, p.OnResolve, p.OnReject);
			return p;
		}

		class SetCameraLensClosure : CameraPromise<string>
		{
			public void OnResolve(string lensId) { Resolve(lensId); }
			public void OnReject(string msg) { Reject(new Exception(msg)); }
		}

		public Future<ManualExposureSettings> SetManualExposure(float iso, float shutterSeconds)
		{
			var p = new ManualExposureClosure();
			SetManualExposure(_handle, iso, shutterSeconds, p.OnResolve, p.OnReject);
			return p;
		}

		public Future<ManualExposureSettings> SetAutoExposure()
		{
			var p = new ManualExposureClosure();
			SetAutoExposure(_handle, p.OnResolve, p.OnReject);
			return p;
		}

		public Future<ManualExposureSettings> GetManualExposure()
		{
			var p = new ManualExposureClosure();
			GetManualExposure(_handle, p.OnResolve, p.OnReject);
			return p;
		}

		class ManualExposureClosure : CameraPromise<ManualExposureSettings>
		{
			public void OnResolve(bool isManual, float iso, float shutterSeconds) { Resolve(new ManualExposureSettings(isManual, iso, shutterSeconds)); }
			public void OnReject(string msg) { Reject(new Exception(msg)); }
		}

		public Future<Barcode> ScanBarcode()
		{
			return ScanBarcode(null);
		}

		public Future<Barcode> ScanBarcode(string[] formats)
		{
			var p = new BarcodeClosure();
			ScanBarcode(_handle, NormalizeBarcodeFormats(formats), p.OnResolve, p.OnReject);
			return p;
		}

		class BarcodeClosure : CameraPromise<Barcode>
		{
			public void OnResolve(string value, string format) { Resolve(new Barcode(value, format)); }
			public void OnReject(string msg) { Reject(new Exception(msg)); }
		}

		public Future<Nothing> StartBarcodeScanning(Action<Barcode> onDetected, string[] formats)
		{
			var p = new StartClosure();
			StartBarcodeScanning(_handle, NormalizeBarcodeFormats(formats),
				(value, format) => onDetected(new Barcode(value, format)),
				p.OnStarted);
			return p;
		}

		public Future<bool> StopBarcodeScanning()
		{
			var p = new BoolClosure();
			StopBarcodeScanning(_handle, p.OnResolve);
			return p;
		}

		public Future<WhiteBalance> SetWhiteBalance(WhiteBalance whiteBalance)
		{
			var p = new WhiteBalanceClosure();
			SetWhiteBalance(_handle, whiteBalance.AsString(), p.OnResolve, p.OnReject);
			return p;
		}

		public Future<WhiteBalance> GetWhiteBalance()
		{
			var p = new WhiteBalanceClosure();
			GetWhiteBalance(_handle, p.OnResolve);
			return p;
		}

		class WhiteBalanceClosure : CameraPromise<WhiteBalance>
		{
			public void OnResolve(string mode) { Resolve(WhiteBalanceHelpers.Parse(mode)); }
			public void OnReject(string msg) { Reject(new Exception(msg)); }
		}

		public Future<WhiteBalanceSettings> SetWhiteBalanceTemperature(float kelvin, float tint)
		{
			var p = new WhiteBalanceSettingsClosure();
			SetWhiteBalanceTemperature(_handle, kelvin, tint, p.OnResolve, p.OnReject);
			return p;
		}

		public Future<WhiteBalanceSettings> GetWhiteBalanceTemperature()
		{
			var p = new WhiteBalanceSettingsClosure();
			GetWhiteBalanceTemperature(_handle, p.OnResolve);
			return p;
		}

		class WhiteBalanceSettingsClosure : CameraPromise<WhiteBalanceSettings>
		{
			public void OnResolve(bool isManual, float kelvin, float tint) { Resolve(new WhiteBalanceSettings(isManual, kelvin, tint)); }
			public void OnReject(string msg) { Reject(new Exception(msg)); }
		}

		public Future<FocusMode> SetFocusMode(FocusMode focusMode)
		{
			var p = new FocusModeClosure();
			SetFocusMode(_handle, focusMode.AsString(), p.OnResolve, p.OnReject);
			return p;
		}

		public Future<FocusMode> GetFocusMode()
		{
			var p = new FocusModeClosure();
			GetFocusMode(_handle, p.OnResolve);
			return p;
		}

		class FocusModeClosure : CameraPromise<FocusMode>
		{
			public void OnResolve(string mode) { Resolve(FocusModeHelpers.Parse(mode)); }
			public void OnReject(string msg) { Reject(new Exception(msg)); }
		}

		public Future<MirrorMode> SetMirrorMode(MirrorMode mirrorMode)
		{
			var p = new MirrorModeClosure();
			SetMirrorMode(_handle, mirrorMode.AsString(), p.OnResolve, p.OnReject);
			return p;
		}

		public Future<MirrorMode> GetMirrorMode()
		{
			var p = new MirrorModeClosure();
			GetMirrorMode(_handle, p.OnResolve);
			return p;
		}

		class MirrorModeClosure : CameraPromise<MirrorMode>
		{
			public void OnResolve(string mode) { Resolve(MirrorModeHelpers.Parse(mode)); }
			public void OnReject(string msg) { Reject(new Exception(msg)); }
		}

		public Future<Nothing> StartFaceDetection(Action<DetectedFace[]> onFaces)
		{
			var p = new StartClosure();
			var collector = new FaceCollector(onFaces);
			StartFaceDetection(_handle, collector.OnFace, collector.OnFrame, p.OnStarted);
			return p;
		}

		public Future<bool> StopFaceDetection()
		{
			var p = new BoolClosure();
			StopFaceDetection(_handle, p.OnResolve);
			return p;
		}

		public Future<Nothing> StartFrameAnalysis(FrameAnalysisOptions options, Action<FrameStatistics> onStats)
		{
			var p = new FrameAnalysisClosure(onStats);
			StartFrameAnalysis(_handle, options.MaxFps,
				options.Resolution.X, options.Resolution.Y,
				options.LumaWidth, options.LumaHeight,
				p.OnStatistics, p.OnStarted, p.OnReject);
			return p;
		}

		public Future<bool> StopFrameAnalysis()
		{
			var p = new BoolClosure();
			StopFrameAnalysis(_handle, p.OnResolve);
			return p;
		}

		public Future<OverlayOptions> SetOverlayOptions(OverlayOptions options)
		{
			var p = new OverlayOptionsClosure();
			SetOverlayOptions(_handle, options.Zebra, options.Peaking, p.OnResolve, p.OnReject);
			return p;
		}

		class OverlayOptionsClosure : CameraPromise<OverlayOptions>
		{
			public void OnResolve(double zebra, double peaking) { Resolve(new OverlayOptions(zebra, peaking)); }
			public void OnReject(string message) { Reject(new Exception(message)); }
		}

		class FrameAnalysisClosure : CameraPromise<Nothing>
		{
			readonly Action<FrameStatistics> _onStats;
			ObjC.Object _statistics;

			public FrameAnalysisClosure(Action<FrameStatistics> onStats)
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

			public void OnStarted(ObjC.Object statistics)
			{
				_statistics = statistics;
				Resolve(default(Nothing));
			}

			public void OnReject(string message)
			{
				Reject(new Exception(message));
			}
		}

		public Future<Nothing> StartErrorMonitoring(Action<CameraEvent> onEvent)
		{
			var p = new StartClosure();
			StartErrorMonitoring(_handle,
				(type, reason, message) => onEvent(new CameraEvent(type, reason, message)),
				p.OnStarted);
			return p;
		}

		public Future<bool> StopErrorMonitoring()
		{
			var p = new BoolClosure();
			StopErrorMonitoring(_handle, p.OnResolve);
			return p;
		}

		public Future<PhotoOption[]> SetPhotoOptions(PhotoOption[] options)
		{
			PhotoResolution resolution = null;
			foreach (var option in options)
			{
				if (option is PhotoQuality)
					return RejectPhotoOptions("PhotoQuality option not supported on iOS");
				else if (option is PhotoResolution)
					resolution = (PhotoResolution)option;
				else
					return RejectPhotoOptions("Unexpected PhotoOption: " + option);
			}

			var p = new iOSPhotoOptionsPromise(options);
			if (resolution == null)
			{
				p.OnResolve();
				return p;
			}

			SetPhotoResolution(_handle, resolution.Width, resolution.Height, p.OnResolve, p.OnReject);
			return p;
		}

		class iOSPhotoOptionsPromise : CameraPromise<PhotoOption[]>
		{
			readonly PhotoOption[] _options;

			public iOSPhotoOptionsPromise(PhotoOption[] options)
			{
				_options = options;
			}

			public void OnResolve() { Resolve(_options); }
			public void OnReject(string message) { Reject(new Exception(message)); }
		}

		static Future<PhotoOption[]> RejectPhotoOptions(string message)
		{
			var p = new Promise<PhotoOption[]>();
			p.Reject(new Exception(message));
			return p;
		}

		[Foreign(Language.ObjC)]
		static void SetPhotoResolution(IntPtr handle, int width, int height, Action onResolve, Action<string> onReject)
		@{
			fcv::setPhotoResolution((fcv::CameraView*)handle, width, height, onResolve, onReject);
		@}

		public void Dispose()
		{
			if (_recordingSession != null)
			{
				_recordingSession.Dispose();
				_recordingSession = null;
			}

			if (_handle != IntPtr.Zero)
			{
				Dispose(_handle);
				_handle = IntPtr.Zero;
			}
		}

		[Foreign(Language.ObjC)]
		static void CapturePhoto(IntPtr handle, Action<ObjC.Object,int> onResolve, Action<string> onReject)
		@{
			fcv::capturePhoto((fcv::CameraView*)handle, onResolve, onReject);
		@}

		[Foreign(Language.ObjC)]
		static void StartRecording(IntPtr handle, Action<ObjC.Object> onResolve, Action<string> onReject)
		@{
			fcv::startRecording((fcv::CameraView*)handle, onResolve, onReject);
		@}

		[Foreign(Language.ObjC)]
		static void SetCaptureMode(IntPtr handle, int captureMode, Action<int> onResolve, Action<string> onReject)
		@{
			fcv::setCaptureMode((fcv::CameraView*)handle, captureMode, onResolve, onReject);
		@}

		[Foreign(Language.ObjC)]
		static void SetCameraFacing(IntPtr handle, int cameraFacing, Action<int> onResolve, Action<string> onReject)
		@{
			fcv::setCameraFacing((fcv::CameraView*)handle, cameraFacing, onResolve, onReject);
		@}

		[Foreign(Language.ObjC)]
		static void SetCameraFocusPoint(IntPtr handle, double x, double y, int cameraWidth, int cameraHeight, int isFocusLocked, Action<Nothing> onResolve, Action<string> onReject)
		@{
			fcv::setCameraFocusPoint((fcv::CameraView*)handle, x, y, cameraWidth, cameraHeight, isFocusLocked, onResolve, onReject);
		@}

		[Foreign(Language.ObjC)]
		static void SetFlashMode(IntPtr handle, int flashMode, Action<int> onResolve, Action<string> onReject)
		@{
			fcv::setFlashMode((fcv::CameraView*)handle, flashMode, onResolve, onReject);
		@}

		[Foreign(Language.ObjC)]
		static IntPtr LoadCameraView(ObjC.Object cameraPreview, Action<IntPtr> onResolve, Action<string> onReject)
		@{
			return fcv::loadCameraView((CameraPreview*)cameraPreview, onResolve, onReject);
		@}

		[Foreign(Language.ObjC)]
		static void GetCameraInfo(IntPtr handle, Action<int,int,int,ObjC.Object,ObjC.Object,float,bool,float,ObjC.Object,ObjC.Object,ObjC.Object,ObjC.Object> callback)
		@{
			fcv::getCameraInfo((fcv::CameraView*)handle, ^(fcv::CameraInfo cameraInfo) {
				callback(cameraInfo.captureMode, cameraInfo.flashMode, cameraInfo.cameraFacing, cameraInfo.supportedFlashModes, cameraInfo.photoResolutions, cameraInfo.zoom, cameraInfo.torchOn, cameraInfo.exposureCompensation, cameraInfo.lensId, cameraInfo.whiteBalance, cameraInfo.focusMode, cameraInfo.mirrorMode);
			});
		@}

		[Foreign(Language.ObjC)]
		static void GetCameraCapabilities(IntPtr handle, Action<bool,float,float,bool,float,float,float,bool,float,float,float,float,ObjC.Object,ObjC.Object,ObjC.Object,bool> callback)
		@{
			fcv::getCameraCapabilities((fcv::CameraView*)handle, ^(fcv::CameraCapabilities caps) {
				callback(caps.zoomSupported, caps.minZoom, caps.maxZoom, caps.torchSupported, caps.minExposureCompensation, caps.maxExposureCompensation, caps.exposureCompensationStep, caps.manualExposureSupported, caps.minIso, caps.maxIso, caps.minShutterSeconds, caps.maxShutterSeconds, caps.supportedFlashModes, caps.photoResolutions, caps.supportedFacings, caps.manualWhiteBalanceSupported);
			});
		@}

		[Foreign(Language.ObjC)]
		static void SetVideoOptions(IntPtr handle, int width, int height, int frameRate, int bitRate, bool audioEnabled, bool stabilizationEnabled, Action<bool> onResolve, Action<string> onReject)
		@{
			fcv::VideoOptions options = {};
			options.width = width;
			options.height = height;
			options.frameRate = frameRate;
			options.bitRate = bitRate;
			options.audioEnabled = audioEnabled;
			options.stabilizationEnabled = stabilizationEnabled;
			fcv::setVideoOptions((fcv::CameraView*)handle, options, onResolve, onReject);
		@}

		[Foreign(Language.ObjC)]
		static void SetZoom(IntPtr handle, float zoom, Action<float> onResolve, Action<string> onReject)
		@{
			fcv::setZoom((fcv::CameraView*)handle, zoom, onResolve, onReject);
		@}

		[Foreign(Language.ObjC)]
		static void GetZoom(IntPtr handle, Action<float> onResolve, Action<string> onReject)
		@{
			fcv::getZoom((fcv::CameraView*)handle, onResolve, onReject);
		@}

		[Foreign(Language.ObjC)]
		static void SetTorchMode(IntPtr handle, bool on, Action<bool> onResolve, Action<string> onReject)
		@{
			fcv::setTorchMode((fcv::CameraView*)handle, on, onResolve, onReject);
		@}

		[Foreign(Language.ObjC)]
		static void IsTorchOn(IntPtr handle, Action<bool> onResolve, Action<string> onReject)
		@{
			fcv::isTorchOn((fcv::CameraView*)handle, onResolve, onReject);
		@}

		[Foreign(Language.ObjC)]
		static void SetExposureCompensation(IntPtr handle, float value, Action<float> onResolve, Action<string> onReject)
		@{
			fcv::setExposureCompensation((fcv::CameraView*)handle, value, onResolve, onReject);
		@}

		[Foreign(Language.ObjC)]
		static void GetExposureCompensation(IntPtr handle, Action<float> onResolve, Action<string> onReject)
		@{
			fcv::getExposureCompensation((fcv::CameraView*)handle, onResolve, onReject);
		@}

		[Foreign(Language.ObjC)]
		static void GetAvailableLenses(IntPtr handle, Action<ObjC.Object,ObjC.Object,ObjC.Object> callback)
		@{
			fcv::getAvailableLenses((fcv::CameraView*)handle, ^(NSArray* ids, NSArray* facings, NSArray* names) {
				callback(ids, facings, names);
			});
		@}

		[Foreign(Language.ObjC)]
		static void SetCameraLens(IntPtr handle, string lensId, Action<string> onResolve, Action<string> onReject)
		@{
			fcv::setCameraLens((fcv::CameraView*)handle, lensId, onResolve, onReject);
		@}

		[Foreign(Language.ObjC)]
		static void SetManualExposure(IntPtr handle, float iso, double shutterSeconds, Action<bool,float,float> onResolve, Action<string> onReject)
		@{
			fcv::setManualExposure((fcv::CameraView*)handle, iso, shutterSeconds, onResolve, onReject);
		@}

		[Foreign(Language.ObjC)]
		static void SetAutoExposure(IntPtr handle, Action<bool,float,float> onResolve, Action<string> onReject)
		@{
			fcv::setAutoExposure((fcv::CameraView*)handle, onResolve, onReject);
		@}

		[Foreign(Language.ObjC)]
		static void GetManualExposure(IntPtr handle, Action<bool,float,float> onResolve, Action<string> onReject)
		@{
			fcv::getManualExposure((fcv::CameraView*)handle, onResolve, onReject);
		@}

		[Foreign(Language.ObjC)]
		static void ScanBarcode(IntPtr handle, string[] formats, Action<string,string> onResolve, Action<string> onReject)
		@{
			NSArray* formatList = formats ? [formats copyArray] : nil;
			fcv::scanBarcode((fcv::CameraView*)handle, formatList, onResolve, onReject);
		@}

		[Foreign(Language.ObjC)]
		static void StartBarcodeScanning(IntPtr handle, string[] formats, Action<string,string> onDetected, Action<string> onStarted)
		@{
			NSArray* formatList = formats ? [formats copyArray] : nil;
			fcv::startBarcodeScanning((fcv::CameraView*)handle, formatList, onDetected, onStarted);
		@}

		[Foreign(Language.ObjC)]
		static void StopBarcodeScanning(IntPtr handle, Action<bool> onStopped)
		@{
			fcv::stopBarcodeScanning((fcv::CameraView*)handle, onStopped);
		@}

		[Foreign(Language.ObjC)]
		static void SetWhiteBalance(IntPtr handle, string mode, Action<string> onResolve, Action<string> onReject)
		@{
			fcv::setWhiteBalance((fcv::CameraView*)handle, mode, onResolve, onReject);
		@}

		[Foreign(Language.ObjC)]
		static void GetWhiteBalance(IntPtr handle, Action<string> onResolve)
		@{
			fcv::getWhiteBalance((fcv::CameraView*)handle, onResolve);
		@}

		[Foreign(Language.ObjC)]
		static void SetWhiteBalanceTemperature(IntPtr handle, float kelvin, float tint, Action<bool,float,float> onResolve, Action<string> onReject)
		@{
			fcv::setWhiteBalanceTemperature((fcv::CameraView*)handle, kelvin, tint, onResolve, onReject);
		@}

		[Foreign(Language.ObjC)]
		static void GetWhiteBalanceTemperature(IntPtr handle, Action<bool,float,float> onResolve)
		@{
			fcv::getWhiteBalanceTemperature((fcv::CameraView*)handle, onResolve);
		@}

		[Foreign(Language.ObjC)]
		static void SetFocusMode(IntPtr handle, string mode, Action<string> onResolve, Action<string> onReject)
		@{
			fcv::setFocusMode((fcv::CameraView*)handle, mode, onResolve, onReject);
		@}

		[Foreign(Language.ObjC)]
		static void GetFocusMode(IntPtr handle, Action<string> onResolve)
		@{
			fcv::getFocusMode((fcv::CameraView*)handle, onResolve);
		@}

		[Foreign(Language.ObjC)]
		static void SetMirrorMode(IntPtr handle, string mode, Action<string> onResolve, Action<string> onReject)
		@{
			fcv::setMirrorMode((fcv::CameraView*)handle, mode, onResolve, onReject);
		@}

		[Foreign(Language.ObjC)]
		static void GetMirrorMode(IntPtr handle, Action<string> onResolve)
		@{
			fcv::getMirrorMode((fcv::CameraView*)handle, onResolve);
		@}

		[Foreign(Language.ObjC)]
		static void StartFaceDetection(IntPtr handle, Action<int,float,float,float,float,float,float> onFace, Action onFrame, Action<string> onStarted)
		@{
			fcv::startFaceDetection((fcv::CameraView*)handle, onFace, onFrame, onStarted);
		@}

		[Foreign(Language.ObjC)]
		static void StopFaceDetection(IntPtr handle, Action<bool> onStopped)
		@{
			fcv::stopFaceDetection((fcv::CameraView*)handle, onStopped);
		@}

		[Require("source.include", "iOS/CameraViewImpl.h")]
		[Foreign(Language.ObjC)]
		static void StartFrameAnalysis(IntPtr handle, int maxFps, int resolutionWidth, int resolutionHeight,
			int lumaWidth, int lumaHeight,
			Action<double,double,double,double,double,double,double,double> onStatistics,
			Action<ObjC.Object> onStarted, Action<string> onStartError)
		@{
			fcv::startFrameAnalysis((fcv::CameraView*)handle, maxFps, resolutionWidth, resolutionHeight, lumaWidth, lumaHeight,
				onStatistics, onStarted, onStartError);
		@}

		[Require("source.include", "iOS/CameraViewImpl.h")]
		[Foreign(Language.ObjC)]
		static void StopFrameAnalysis(IntPtr handle, Action<bool> onStopped)
		@{
			fcv::stopFrameAnalysis((fcv::CameraView*)handle, onStopped);
		@}

		[Require("source.include", "iOS/CameraViewImpl.h")]
		[Require("source.include", "Foundation/Foundation.h")]
		[Foreign(Language.ObjC)]
		static byte[] TakeStatisticsHistogram(ObjC.Object statistics)
		@{
			NSData* data = fcv::statisticsHistogram((void*)statistics);
			if (!data || data.length == 0)
				return nil;

			return [::StrongUnoArray strongUnoArrayWithUnoArray: uArray::New(@{byte:typeof}->Array(), (int)data.length, data.bytes)
				getAt: ^ id (::uArray* arr, int i) { return ::uObjC::Box<uint8_t>(arr->Item<uint8_t>(i)); }
				setAt: ^ (::uArray* arr, int i, id obj) { arr->Item<uint8_t>(i) = ::uObjC::Unbox<uint8_t>(obj); }];
		@}

		[Require("source.include", "iOS/CameraViewImpl.h")]
		[Require("source.include", "Foundation/Foundation.h")]
		[Foreign(Language.ObjC)]
		static byte[] TakeStatisticsLuma(ObjC.Object statistics)
		@{
			NSData* data = fcv::statisticsLuma((void*)statistics);
			if (!data || data.length == 0)
				return nil;

			return [::StrongUnoArray strongUnoArrayWithUnoArray: uArray::New(@{byte:typeof}->Array(), (int)data.length, data.bytes)
				getAt: ^ id (::uArray* arr, int i) { return ::uObjC::Box<uint8_t>(arr->Item<uint8_t>(i)); }
				setAt: ^ (::uArray* arr, int i, id obj) { arr->Item<uint8_t>(i) = ::uObjC::Unbox<uint8_t>(obj); }];
		@}

		[Require("source.include", "iOS/CameraViewImpl.h")]
		[Foreign(Language.ObjC)]
		static int StatisticsLumaWidth(ObjC.Object statistics)
		@{
			return fcv::statisticsLumaWidth((void*)statistics);
		@}

		[Require("source.include", "iOS/CameraViewImpl.h")]
		[Foreign(Language.ObjC)]
		static int StatisticsLumaHeight(ObjC.Object statistics)
		@{
			return fcv::statisticsLumaHeight((void*)statistics);
		@}

		[Require("source.include", "iOS/CameraViewImpl.h")]
		[Foreign(Language.ObjC)]
		static void SetOverlayOptions(IntPtr handle, double zebra, double peaking, Action<double,double> onResolved, Action<string> onError)
		@{
			fcv::setOverlayOptions((fcv::CameraView*)handle, zebra, peaking, onResolved, onError);
		@}

		[Foreign(Language.ObjC)]
		static void StartErrorMonitoring(IntPtr handle, Action<string,string,string> onEvent, Action<string> onStarted)
		@{
			fcv::startErrorMonitoring((fcv::CameraView*)handle, onEvent, onStarted);
		@}

		[Foreign(Language.ObjC)]
		static void StopErrorMonitoring(IntPtr handle, Action<bool> onStopped)
		@{
			fcv::stopErrorMonitoring((fcv::CameraView*)handle, onStopped);
		@}

		static string[] NormalizeBarcodeFormats(string[] formats)
		{
			return formats != null ? formats : new string[0];
		}

		[Foreign(Language.ObjC)]
		static void Dispose(IntPtr handle)
		@{
			fcv::dispose((fcv::disposable_t)handle);
		@}

		static CaptureMode IntToCaptureMode(int captureMode)
		{
			if (captureMode == CaptureModePhoto)
				return CaptureMode.Photo;
			else if (captureMode == CaptureModeVideo)
				return CaptureMode.Video;
			else
				throw new Exception("Invalid CaptureMode: " + captureMode);
		}

		static int CaptureModeToInt(CaptureMode captureMode)
		{
			switch (captureMode)
			{
				case CaptureMode.Photo:
					return CaptureModePhoto;
				case CaptureMode.Video:
					return CaptureModeVideo;
				default:
					throw new Exception("Unexpected CaptureMode: " + captureMode);
			}
		}

		static CameraFacing IntToCameraFacing(int cameraFacing)
		{
			if (cameraFacing == CameraFacingFront)
				return CameraFacing.Front;
			else if (cameraFacing == CameraFacingBack)
				return CameraFacing.Back;
			else
				throw new Exception("Invalid CameraFacing: " + cameraFacing);
		}

		static int CameraFacingToInt(CameraFacing cameraFacing)
		{
			switch(cameraFacing)
			{
				case CameraFacing.Front:
					return CameraFacingFront;
				case CameraFacing.Back:
					return CameraFacingBack;
				default:
					throw new Exception("Unexpected CameraFacing: " + cameraFacing);
			}
		}

		static int FlashModeToInt(FlashMode flashMode)
		{
			switch (flashMode)
			{
				case FlashMode.Auto:
					return FlashModeAuto;
				case FlashMode.On:
					return FlashModeOn;
				case FlashMode.Off:
					return FlashModeOff;
				default:
					throw new Exception("Unexpected FlashMode: " + flashMode);
			}
		}

		static FlashMode IntToFlashMode(int flashMode)
		{
			if (flashMode == FlashModeAuto)
				return FlashMode.Auto;
			else if (flashMode == FlashModeOn)
				return FlashMode.On;
			else if (flashMode == FlashModeOff)
				return FlashMode.Off;
			else
				throw new Exception("Unexpected FlashMode: " + flashMode);
		}
	}

	[Require("source.include", "iOS/CameraPreview.h")]
	extern(iOS) class CameraView : Fuse.Controls.Native.iOS.View, ICameraView
	{
		ICameraViewHost _host;
		ObjC.Object _cameraPreview;

		[UXConstructor]
		public CameraView([UXParameter("Host")]ICameraViewHost host)
			: this(host, CreateCameraPreview()) { }

		CameraView(ICameraViewHost host, ObjC.Object cameraPreview)
			: base(cameraPreview)
		{
			_host = host;
			_cameraPreview = cameraPreview;
			_cameraFuture = NativeCamera.Load(_cameraPreview);
			_cameraFuture.Then(OnCameraResolved, OnCameraRejected);
		}

		Future<NativeCamera> _cameraFuture;

		NativeCamera _impl;

		void OnCameraResolved(NativeCamera impl)
		{
			if (_isDisposed)
			{
				impl.Dispose();
				return;
			}
			_impl = impl;
			_host.OnCameraLoaded(impl);
		}

		void OnCameraRejected(Exception e)
		{
			if (_isDisposed)
				return;
			_host.OnError(e);
		}

		bool _isDisposed = false;
		public override void Dispose()
		{
			if (_isDisposed)
				return;
			if (_impl == null)
				_cameraFuture.Cancel();
			base.Dispose();
			_host = null;
			if (_impl != null)
			{
				_impl.Dispose();
				_impl = null;
			}
			_isDisposed = true;
		}

		PreviewStretchMode ICameraView.PreviewStretchMode { set { SetFillView(_cameraPreview, value == PreviewStretchMode.UniformToFill); } }

		[Foreign(Language.ObjC)]
		static ObjC.Object CreateCameraPreview()
		@{
			CameraPreview* preview = [[CameraPreview alloc] init];
			[preview setClipsToBounds:true];
			return preview;
		@}

		[Foreign(Language.ObjC)]
		static void SetFillView(ObjC.Object handle, bool fillView)
		@{
			((CameraPreview*)handle).fillView = fillView;
		@}
	}
}
