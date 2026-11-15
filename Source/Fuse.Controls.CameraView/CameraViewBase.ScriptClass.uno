using Uno;
using Uno.UX;
using Uno.Time;
using Uno.Compiler.ExportTargetInterop;
using Uno.Threading;
using Uno.Collections;

using Fuse;
using Fuse.Controls;
using Fuse.Controls.Native;
using Fuse.Scripting;

namespace Fuse.Controls
{
	/**
		@include Docs/README.md
	*/
	public partial class CameraViewBase
	{
		const string InfoPhotoResolutions = "photoResolutions";

		static CameraViewBase()
		{
			ScriptClass.Register(typeof(CameraViewBase),
				new ScriptPromise<CameraViewBase,Photo,object>("capturePhoto", ExecutionThread.MainThread, capturePhoto, ConvertPhoto),
				new ScriptPromise<CameraViewBase,RecordingSession,object>("startRecording", ExecutionThread.MainThread, startRecording, ConvertRecordingSession),
				new ScriptPromise<CameraViewBase,CaptureMode,object>("setCaptureMode", ExecutionThread.MainThread, setCaptureMode, ConvertCaptureMode),
				new ScriptPromise<CameraViewBase,CameraFacing,object>("setCameraFacing", ExecutionThread.MainThread, setCameraFacing, ConvertCameraFacing),
				new ScriptPromise<CameraViewBase,Nothing,object>("setCameraFocusPoint", ExecutionThread.MainThread, setCameraFocusPoint),
				new ScriptPromise<CameraViewBase,FlashMode,object>("setFlashMode", ExecutionThread.MainThread, setFlashMode, ConvertFlashMode),
				new ScriptPromise<CameraViewBase,CameraInfo,object>("getCameraInfo", ExecutionThread.MainThread, getCameraInfo, ConvertCameraInfo),
				new ScriptPromise<CameraViewBase,PhotoOption[],object>("setPhotoOptions", ExecutionThread.JavaScript, setPhotoOptions, ConvertPhotoOptions),
				new ScriptPromise<CameraViewBase,Nothing,object>("setVideoOptions", ExecutionThread.JavaScript, setVideoOptions),
				new ScriptPromise<CameraViewBase,CameraCapabilities,object>("getCameraCapabilities", ExecutionThread.MainThread, getCameraCapabilities, ConvertCameraCapabilities),
				new ScriptPromise<CameraViewBase,float,object>("setZoom", ExecutionThread.MainThread, setZoom, ConvertFloat),
				new ScriptPromise<CameraViewBase,float,object>("getZoom", ExecutionThread.MainThread, getZoom, ConvertFloat),
				new ScriptPromise<CameraViewBase,bool,object>("setTorchMode", ExecutionThread.MainThread, setTorchMode, ConvertBool),
				new ScriptPromise<CameraViewBase,bool,object>("isTorchOn", ExecutionThread.MainThread, isTorchOn, ConvertBool),
				new ScriptPromise<CameraViewBase,float,object>("setExposureCompensation", ExecutionThread.MainThread, setExposureCompensation, ConvertFloat),
				new ScriptPromise<CameraViewBase,float,object>("getExposureCompensation", ExecutionThread.MainThread, getExposureCompensation, ConvertFloat),
				new ScriptPromise<CameraViewBase,CameraLens[],object>("getAvailableLenses", ExecutionThread.MainThread, getAvailableLenses, ConvertCameraLenses),
				new ScriptPromise<CameraViewBase,string,string>("setCameraLens", ExecutionThread.MainThread, setCameraLens),
				new ScriptPromise<CameraViewBase,ManualExposureSettings,object>("setManualExposure", ExecutionThread.MainThread, setManualExposure, ConvertManualExposureSettings),
				new ScriptPromise<CameraViewBase,ManualExposureSettings,object>("setAutoExposure", ExecutionThread.MainThread, setAutoExposure, ConvertManualExposureSettings),
				new ScriptPromise<CameraViewBase,ManualExposureSettings,object>("getManualExposure", ExecutionThread.MainThread, getManualExposure, ConvertManualExposureSettings),
				new ScriptPromise<CameraViewBase,Barcode,object>("scanBarcode", ExecutionThread.MainThread, scanBarcode, ConvertBarcode),
				new ScriptPromise<CameraViewBase,Nothing,object>("startBarcodeScanning", ExecutionThread.MainThread, startBarcodeScanning),
				new ScriptPromise<CameraViewBase,bool,object>("stopBarcodeScanning", ExecutionThread.MainThread, stopBarcodeScanning, ConvertBool),
				new ScriptPromise<CameraViewBase,WhiteBalance,string>("setWhiteBalance", ExecutionThread.MainThread, setWhiteBalance, ConvertWhiteBalance),
				new ScriptPromise<CameraViewBase,WhiteBalance,string>("getWhiteBalance", ExecutionThread.MainThread, getWhiteBalance, ConvertWhiteBalance),
				new ScriptPromise<CameraViewBase,WhiteBalanceSettings,object>("setWhiteBalanceTemperature", ExecutionThread.MainThread, setWhiteBalanceTemperature, ConvertWhiteBalanceSettings),
				new ScriptPromise<CameraViewBase,WhiteBalanceSettings,object>("getWhiteBalanceTemperature", ExecutionThread.MainThread, getWhiteBalanceTemperature, ConvertWhiteBalanceSettings),
				new ScriptPromise<CameraViewBase,FocusMode,string>("setFocusMode", ExecutionThread.MainThread, setFocusMode, ConvertFocusMode),
				new ScriptPromise<CameraViewBase,FocusMode,string>("getFocusMode", ExecutionThread.MainThread, getFocusMode, ConvertFocusMode),
				new ScriptPromise<CameraViewBase,MirrorMode,string>("setMirrorMode", ExecutionThread.MainThread, setMirrorMode, ConvertMirrorMode),
				new ScriptPromise<CameraViewBase,MirrorMode,string>("getMirrorMode", ExecutionThread.MainThread, getMirrorMode, ConvertMirrorMode),
				new ScriptPromise<CameraViewBase,Nothing,object>("startFaceDetection", ExecutionThread.MainThread, startFaceDetection),
				new ScriptPromise<CameraViewBase,bool,object>("stopFaceDetection", ExecutionThread.MainThread, stopFaceDetection, ConvertBool),
				new ScriptPromise<CameraViewBase,Nothing,object>("startErrorMonitoring", ExecutionThread.MainThread, startErrorMonitoring),
				new ScriptPromise<CameraViewBase,bool,object>("stopErrorMonitoring", ExecutionThread.MainThread, stopErrorMonitoring, ConvertBool),
				new ScriptPromise<CameraViewBase,Nothing,object>("startFrameAnalysis", ExecutionThread.MainThread, startFrameAnalysis),
				new ScriptPromise<CameraViewBase,bool,object>("stopFrameAnalysis", ExecutionThread.MainThread, stopFrameAnalysis, ConvertBool),
				new ScriptPromise<CameraViewBase,OverlayOptions,object>("setOverlayOptions", ExecutionThread.JavaScript, setOverlayOptions, ConvertOverlayOptions),
				new ScriptReadonlyProperty("CAPTURE_MODE_PHOTO", EnumHelpers.AsString(CaptureMode.Photo)),
				new ScriptReadonlyProperty("CAPTURE_MODE_VIDEO", EnumHelpers.AsString(CaptureMode.Video)),
				new ScriptReadonlyProperty("CAMERA_FACING_FRONT", EnumHelpers.AsString(CameraFacing.Front)),
				new ScriptReadonlyProperty("CAMERA_FACING_BACK", EnumHelpers.AsString(CameraFacing.Back)),
				new ScriptReadonlyProperty("FLASH_MODE_AUTO", EnumHelpers.AsString(FlashMode.Auto)),
				new ScriptReadonlyProperty("FLASH_MODE_ON", EnumHelpers.AsString(FlashMode.On)),
				new ScriptReadonlyProperty("FLASH_MODE_OFF", EnumHelpers.AsString(FlashMode.Off)),
				new ScriptReadonlyProperty("OPTION_PHOTO_RESOLUTION", PhotoResolution.Name),
				new ScriptReadonlyProperty("OPTION_PHOTO_QUALITY", PhotoQuality.Name),
				new ScriptReadonlyProperty("OPTION_VIDEO_RESOLUTION", VideoOptions.ResolutionName),
				new ScriptReadonlyProperty("OPTION_VIDEO_FRAME_RATE", VideoOptions.FrameRateName),
				new ScriptReadonlyProperty("OPTION_VIDEO_BIT_RATE", VideoOptions.BitRateName),
				new ScriptReadonlyProperty("OPTION_VIDEO_AUDIO_ENABLED", VideoOptions.AudioEnabledName),
				new ScriptReadonlyProperty("OPTION_VIDEO_STABILIZATION_ENABLED", VideoOptions.StabilizationEnabledName),
				new ScriptReadonlyProperty("INFO_FLASH_MODE", CameraInfo.FlashModeName),
				new ScriptReadonlyProperty("INFO_CAMERA_FACING", CameraInfo.CameraFacingName),
				new ScriptReadonlyProperty("INFO_CAPTURE_MODE", CameraInfo.CaptureModeName),
				new ScriptReadonlyProperty("INFO_PHOTO_RESOLUTIONS", CameraInfo.PhotoResolutionsName),
				new ScriptReadonlyProperty("INFO_SUPPORTED_FLASH_MODES", CameraInfo.SupportedFlashModesName),
				new ScriptReadonlyProperty("INFO_ZOOM", CameraInfo.ZoomName),
				new ScriptReadonlyProperty("INFO_TORCH_ON", CameraInfo.TorchOnName),
				new ScriptReadonlyProperty("INFO_EXPOSURE_COMPENSATION", CameraInfo.ExposureCompensationName),
				new ScriptReadonlyProperty("INFO_LENS_ID", CameraInfo.LensIdName),
				new ScriptReadonlyProperty("LENS_ID", CameraLens.IdName),
				new ScriptReadonlyProperty("LENS_FACING", CameraLens.FacingName),
				new ScriptReadonlyProperty("LENS_NAME", CameraLens.NameName),
				new ScriptReadonlyProperty("CAP_ZOOM_SUPPORTED", CameraCapabilities.ZoomSupportedName),
				new ScriptReadonlyProperty("CAP_MIN_ZOOM", CameraCapabilities.MinZoomName),
				new ScriptReadonlyProperty("CAP_MAX_ZOOM", CameraCapabilities.MaxZoomName),
				new ScriptReadonlyProperty("CAP_TORCH_SUPPORTED", CameraCapabilities.TorchSupportedName),
				new ScriptReadonlyProperty("CAP_PHOTO_RESOLUTIONS", CameraCapabilities.PhotoResolutionsName),
				new ScriptReadonlyProperty("CAP_SUPPORTED_FLASH_MODES", CameraCapabilities.SupportedFlashModesName),
				new ScriptReadonlyProperty("CAP_SUPPORTED_FACINGS", CameraCapabilities.SupportedFacingsName),
				new ScriptReadonlyProperty("CAP_MIN_EXPOSURE_COMPENSATION", CameraCapabilities.MinExposureCompensationName),
				new ScriptReadonlyProperty("CAP_MAX_EXPOSURE_COMPENSATION", CameraCapabilities.MaxExposureCompensationName),
				new ScriptReadonlyProperty("CAP_EXPOSURE_COMPENSATION_STEP", CameraCapabilities.ExposureCompensationStepName),
				new ScriptReadonlyProperty("CAP_MANUAL_EXPOSURE_SUPPORTED", CameraCapabilities.ManualExposureSupportedName),
				new ScriptReadonlyProperty("CAP_MIN_ISO", CameraCapabilities.MinIsoName),
				new ScriptReadonlyProperty("CAP_MAX_ISO", CameraCapabilities.MaxIsoName),
				new ScriptReadonlyProperty("CAP_MIN_SHUTTER_SECONDS", CameraCapabilities.MinShutterSecondsName),
				new ScriptReadonlyProperty("CAP_MAX_SHUTTER_SECONDS", CameraCapabilities.MaxShutterSecondsName),
				new ScriptReadonlyProperty("BARCODE_VALUE", Barcode.ValueName),
				new ScriptReadonlyProperty("BARCODE_FORMAT", Barcode.FormatName),
				new ScriptReadonlyProperty("BARCODE_FORMAT_UNKNOWN", Barcode.FormatUnknown),
				new ScriptReadonlyProperty("BARCODE_FORMAT_QR_CODE", Barcode.FormatQrCode),
				new ScriptReadonlyProperty("BARCODE_FORMAT_EAN_13", Barcode.FormatEan13),
				new ScriptReadonlyProperty("BARCODE_FORMAT_EAN_8", Barcode.FormatEan8),
				new ScriptReadonlyProperty("BARCODE_FORMAT_UPC_A", Barcode.FormatUpcA),
				new ScriptReadonlyProperty("BARCODE_FORMAT_UPC_E", Barcode.FormatUpcE),
				new ScriptReadonlyProperty("BARCODE_FORMAT_CODE_128", Barcode.FormatCode128),
				new ScriptReadonlyProperty("BARCODE_FORMAT_CODE_39", Barcode.FormatCode39),
				new ScriptReadonlyProperty("BARCODE_FORMAT_CODE_93", Barcode.FormatCode93),
				new ScriptReadonlyProperty("BARCODE_FORMAT_ITF", Barcode.FormatItf),
				new ScriptReadonlyProperty("BARCODE_FORMAT_CODABAR", Barcode.FormatCodabar),
				new ScriptReadonlyProperty("BARCODE_FORMAT_DATA_MATRIX", Barcode.FormatDataMatrix),
				new ScriptReadonlyProperty("BARCODE_FORMAT_PDF417", Barcode.FormatPdf417),
				new ScriptReadonlyProperty("BARCODE_FORMAT_AZTEC", Barcode.FormatAztec),
				new ScriptReadonlyProperty("WHITE_BALANCE_AUTO", WhiteBalance.Auto.AsString()),
				new ScriptReadonlyProperty("WHITE_BALANCE_INCANDESCENT", WhiteBalance.Incandescent.AsString()),
				new ScriptReadonlyProperty("WHITE_BALANCE_FLUORESCENT", WhiteBalance.Fluorescent.AsString()),
				new ScriptReadonlyProperty("WHITE_BALANCE_WARM_FLUORESCENT", WhiteBalance.WarmFluorescent.AsString()),
				new ScriptReadonlyProperty("WHITE_BALANCE_DAYLIGHT", WhiteBalance.Daylight.AsString()),
				new ScriptReadonlyProperty("WHITE_BALANCE_CLOUDY", WhiteBalance.Cloudy.AsString()),
				new ScriptReadonlyProperty("WHITE_BALANCE_TWILIGHT", WhiteBalance.Twilight.AsString()),
				new ScriptReadonlyProperty("WHITE_BALANCE_SHADE", WhiteBalance.Shade.AsString()),
				new ScriptReadonlyProperty("WHITE_BALANCE_MANUAL", WhiteBalance.Manual.AsString()),
				new ScriptReadonlyProperty("INFO_WHITE_BALANCE", CameraInfo.WhiteBalanceName),
				new ScriptReadonlyProperty("CAP_WHITE_BALANCE_MODES", CameraCapabilities.WhiteBalanceModesName),
				new ScriptReadonlyProperty("CAP_MANUAL_WHITE_BALANCE_SUPPORTED", CameraCapabilities.ManualWhiteBalanceSupportedName),
				new ScriptReadonlyProperty("FOCUS_MODE_AUTO", FocusMode.Auto.AsString()),
				new ScriptReadonlyProperty("FOCUS_MODE_CONTINUOUS", FocusMode.Continuous.AsString()),
				new ScriptReadonlyProperty("FOCUS_MODE_LOCKED", FocusMode.Locked.AsString()),
				new ScriptReadonlyProperty("INFO_FOCUS_MODE", CameraInfo.FocusModeName),
				new ScriptReadonlyProperty("CAP_FOCUS_MODES", CameraCapabilities.FocusModesName),
				new ScriptReadonlyProperty("CAP_MIRROR_MODES", CameraCapabilities.MirrorModesName),
				new ScriptReadonlyProperty("MIRROR_MODE_AUTO", MirrorMode.Auto.AsString()),
				new ScriptReadonlyProperty("MIRROR_MODE_ON", MirrorMode.On.AsString()),
				new ScriptReadonlyProperty("MIRROR_MODE_OFF", MirrorMode.Off.AsString()),
				new ScriptReadonlyProperty("INFO_MIRROR_MODE", CameraInfo.MirrorModeName),
				new ScriptReadonlyProperty("FACE_ID", DetectedFace.IdName),
				new ScriptReadonlyProperty("FACE_X", DetectedFace.XName),
				new ScriptReadonlyProperty("FACE_Y", DetectedFace.YName),
				new ScriptReadonlyProperty("FACE_WIDTH", DetectedFace.WidthName),
				new ScriptReadonlyProperty("FACE_HEIGHT", DetectedFace.HeightName),
				new ScriptReadonlyProperty("FACE_ROLL", DetectedFace.RollName),
				new ScriptReadonlyProperty("FACE_YAW", DetectedFace.YawName),
				new ScriptReadonlyProperty("EVENT_TYPE", CameraEvent.TypeName),
				new ScriptReadonlyProperty("EVENT_REASON", CameraEvent.ReasonName),
				new ScriptReadonlyProperty("EVENT_MESSAGE", CameraEvent.MessageName),
				new ScriptReadonlyProperty("EVENT_ERROR", CameraEvent.TypeError),
				new ScriptReadonlyProperty("EVENT_INTERRUPTED", CameraEvent.TypeInterrupted),
				new ScriptReadonlyProperty("EVENT_RESUMED", CameraEvent.TypeResumed),
				new ScriptReadonlyProperty("OPTION_ANALYSIS_MAX_FPS", FrameAnalysisOptions.MaxFpsName),
				new ScriptReadonlyProperty("OPTION_ANALYSIS_RESOLUTION", FrameAnalysisOptions.ResolutionName),
				new ScriptReadonlyProperty("OPTION_ANALYSIS_LUMA_WIDTH", FrameAnalysisOptions.LumaWidthName),
				new ScriptReadonlyProperty("OPTION_ANALYSIS_LUMA_HEIGHT", FrameAnalysisOptions.LumaHeightName),
				new ScriptReadonlyProperty("STATS_TIMESTAMP", FrameStatistics.TimestampName),
				new ScriptReadonlyProperty("STATS_MEAN", FrameStatistics.MeanName),
				new ScriptReadonlyProperty("STATS_P1", FrameStatistics.P1Name),
				new ScriptReadonlyProperty("STATS_P50", FrameStatistics.P50Name),
				new ScriptReadonlyProperty("STATS_P99", FrameStatistics.P99Name),
				new ScriptReadonlyProperty("STATS_CLIPPED_LOW", FrameStatistics.ClippedLowName),
				new ScriptReadonlyProperty("STATS_CLIPPED_HIGH", FrameStatistics.ClippedHighName),
				new ScriptReadonlyProperty("STATS_HISTOGRAM", FrameStatistics.HistogramName),
				new ScriptReadonlyProperty("STATS_LUMA", FrameStatistics.LumaName),
				new ScriptReadonlyProperty("STATS_LUMA_WIDTH", FrameStatistics.LumaWidthName),
				new ScriptReadonlyProperty("STATS_LUMA_HEIGHT", FrameStatistics.LumaHeightName),
				new ScriptReadonlyProperty("STATS_ANALYSIS_TIME", FrameStatistics.AnalysisTimeName),
				new ScriptReadonlyProperty("OPTION_OVERLAY_ZEBRA", OverlayOptions.ZebraName),
				new ScriptReadonlyProperty("OPTION_OVERLAY_PEAKING", OverlayOptions.PeakingName),
				new ScriptReadonlyProperty("META_WIDTH", PhotoMetadata.WidthName),
				new ScriptReadonlyProperty("META_HEIGHT", PhotoMetadata.HeightName),
				new ScriptReadonlyProperty("META_ORIENTATION", PhotoMetadata.OrientationName),
				new ScriptReadonlyProperty("META_TIMESTAMP", PhotoMetadata.TimestampName),
				new ScriptReadonlyProperty("META_ISO", PhotoMetadata.IsoName),
				new ScriptReadonlyProperty("META_EXPOSURE_TIME", PhotoMetadata.ExposureTimeName),
				new ScriptReadonlyProperty("META_F_NUMBER", PhotoMetadata.FNumberName),
				new ScriptReadonlyProperty("META_FOCAL_LENGTH", PhotoMetadata.FocalLengthName),
				new ScriptReadonlyProperty("RECORDING_META_WIDTH", RecordingMetadata.WidthName),
				new ScriptReadonlyProperty("RECORDING_META_HEIGHT", RecordingMetadata.HeightName),
				new ScriptReadonlyProperty("RECORDING_META_DURATION", RecordingMetadata.DurationName),
				new ScriptReadonlyProperty("RECORDING_META_FILE_SIZE", RecordingMetadata.FileSizeName));
		}

		/**
			Capture photo

			@scriptmethod capturePhoto()

			Returns a Promise that resolves to a @Fuse.Controls.Photo. The `CaptureMode` must be set to `CAPTURE_MODE_PHOTO`.
			`photo` holds onto the resrouces representing the captured photo, when you are done using it you must
			call `release()`. This will free up the resources. Its considered bad practice to keep more than one
			photo around, this might cause memory usage problems on weaker devices.

				<CameraView ux:Name="Camera" />
				<JavaScript>
					Camera.capturePhoto()
						.then(function(photo) {
							photo.release();
						})
						.catch(function(error) { });
				</JavaScript>
		*/
		static Future<Photo> capturePhoto(Context context, CameraViewBase self, object[] args)
		{
			return self.CapturePhoto();
		}

		/**
			Start video recording

			@scriptmethod startRecording()

			Returns a promise that resolves to a @Fuse.Controls.RecordingSession. The `CaptureMode` must be set to `CAPTURE_MODE_VIDEO`

				<CameraView ux:Name="Camera" />
				<JavaScript>
					Camera.capturePhoto()
						.then(function(recordingSession) { })
						.catch(function(error) { });
				</JavaScript>
		*/
		static Future<RecordingSession> startRecording(Context context, CameraViewBase self, object[] args)
		{
			return self.StartRecording();
		}

		/**
			Set CaptureMode

			@scriptmethod setCaptureMode( captureMode )

			Returns a promise that resolves to the new `CaptureMode`. The values for `CaptureMode` can be found
			as constants on the `CameraView`. Valid values are `CAPTURE_MODE_PHOTO` and `CAPTURE_MODE_VIDEO`

				<CameraView ux:Name="Camera" />
				<JavaScript>
					Camera.setCaptureMode(Camera.CAPTURE_MODE_PHOTO)
						.then(function(newCaptureMode) {  })
						.catch(function(error) { });
				</JavaScript>
		*/
		static Future<CaptureMode> setCaptureMode(Context context, CameraViewBase self, object[] args)
		{
			if (args.Length != 1)
				return new Promise<CaptureMode>().RejectWithMessage("An argument for CaptureMode must be provided");

			var arg = args[0] as string;
			if (arg != null)
				return self.SetCaptureMode(EnumHelpers.As<CaptureMode>(arg));
			else
				return new Promise<CaptureMode>().RejectWithMessage("Bad argument");
		}

		/**
			Set CameraFacing

			@scriptmethod setCameraFacing( cameraFacing )

			Returns a promise that resolves to the new `CameraFacing`. The values for `CameraFacing` can be found
			as constants on the `CameraView`. Valid values are `CAMERA_FACING_BACK` and `CAMERA_FACING_BACK`

				<CameraView ux:Name="Camera" />
				<JavaScript>
					Camera.setCameraFacing(Camera.CAMERA_FACING_FRONT)
						.then(function(newCameraFacing) {  })
						.catch(function(error) { });
				</JavaScript>
		*/
		static Future<CameraFacing> setCameraFacing(Context context, CameraViewBase self, object[] args)
		{
			if (args.Length != 1)
				return new Promise<CameraFacing>().RejectWithMessage("An argument for CameraFacing must be provided");

			var arg = args[0] as string;
			if (arg != null)
				return self.SetCameraFacing(EnumHelpers.As<CameraFacing>(arg));
			else
				return new Promise<CameraFacing>().RejectWithMessage("Bad argument");
		}

		/**
			Set CameraFocusPoint

			@scriptmethod setCameraFocusPoint( x, y, cameraWidth, cameraHeight, isFocusLocked )

			Returns a promise of nothing. Valid values are double x, double y, int cameraWidth, int cameraHeight and int isFocusLocked.

				<CameraView ux:Name="Camera" />
				<JavaScript>
					Camera.setCameraFocusPoint(x, y, cameraWidth, cameraHeight, isFocusLocked)
						.then(function(isSet) {  })
						.catch(function(error) { });
				</JavaScript>
		*/
		static Future<Nothing> setCameraFocusPoint(Context context, CameraViewBase self, object[] args)
		{
			if (args.Length != 5)
				return new Promise<Nothing>().RejectWithMessage("Arguments for CameraFocusPoint must be provided");

			return self.SetCameraFocusPoint(
				Marshal.ToDouble(args[0]), Marshal.ToDouble(args[1]),
				Marshal.ToInt(args[2]), Marshal.ToInt(args[3]), Marshal.ToInt(args[4])
			);
		}

		/**
			Set FlashMode

			@scriptmethod setFlashMode( flashMode )

			Returns a promise that resolves to the new `FlashMode`. The values for `FlashMode` can be found
			as constants on the `CameraView`. Valid values are `FLASH_MODE_AUTO`, `FLASH_MODE_ON` and `FLASH_MODE_OFF`

				<CameraView ux:Name="Camera" />
				<JavaScript>
					Camera.setFlashMode(Camera.FLASH_MODE_OFF)
						.then(function(newFlashMode) {  })
						.catch(function(error) { });
				</JavaScript>
		*/
		static Future<FlashMode> setFlashMode(Context context, CameraViewBase self, object[] args)
		{
			if (args.Length != 1)
				return new Promise<FlashMode>().RejectWithMessage("An argument for FlashMode must be provided");

			var arg = args[0] as string;
			if (arg != null)
				return self.SetFlashMode(EnumHelpers.As<FlashMode>(arg));
			else
				return new Promise<FlashMode>().RejectWithMessage("Bad argument");
		}

		/**
			Get CameraInfo

			@scriptmethod getCameraInfo()

			Returns a promise that resolves to an object containing information about the camera state. The object will always
			contain the current FlashMode, CaptureMode, CameraFacing, Zoom, TorchOn, ExposureCompensation and LensId.

			This promise does not resolve until the camera is fully loaded. When the camera is loaded this promise resolves immediatley.

				<CameraView ux:Name="Camera" />
				<JavaScript>
					Camera.getCameraInfo()
						.then(function(info) {
							console.log(info[Camera.INFO_FLASH_MODE]);
							console.log(info[Camera.INFO_CAPTURE_MODE]);
							console.log(info[Camera.INFO_CAMERA_FACING]);
							console.log(info[Camera.INFO_ZOOM]);
							console.log(info[Camera.INFO_TORCH_ON]);
							console.log(info[Camera.INFO_EXPOSURE_COMPENSATION]);
							console.log(info[Camera.INFO_LENS_ID]);
							console.log(info[Camera.INFO_SUPPORTED_FLASH_MODES].join());
						})
						.catch(function(error) { });
				</JavaScript>

			On Android the user should set the output resolution for photos, while on iOS you cannot set a specific resolution.
			In this abstraction we try to pick a sensible resolution based on the max width and height of OpenGL textures and
			the aspect of the camera preview. However you might want to configure this yourself. `getCameraInfo` returns
			the available photo resolutions. On Android this is the full list of settable resolutions. On iOS it reports
			the active format's high resolution still dimensions, since iOS does not allow choosing a specific resolution:

				<CameraView ux:Name="Camera" />
				<JavaScript>
					Camera.getCameraInfo()
						.then(function(info) {
							// check if INFO_PHOTO_RESOLUTIONS exists
							if (Camera.INFO_PHOTO_RESOLUTIONS in info) {
								info[Camera.INFO_PHOTO_RESOLUTIONS].forEach(function(e) {
									console.log(e.width + "x" + e.height);
								});
							}
						})
						.catch(function(error) { });
				</JavaScript>

		*/
		static Future<CameraInfo> getCameraInfo(Context context, CameraViewBase self, object[] args)
		{
			return self.GetCameraInfo();
		}

		class SetPhotoOptionsClosure : Promise<PhotoOption[]>
		{
			CameraViewBase _cameraViewBase;
			PhotoOption[] _options;

			public SetPhotoOptionsClosure(PhotoOption[] options, CameraViewBase cameraViewBase)
			{
				_options = options;
				_cameraViewBase = cameraViewBase;
				UpdateManager.PostAction(Dispatch);
			}

			void Dispatch()
			{
				_cameraViewBase.SetPhotoOptions(_options).Then(Resolve, Reject);
			}
		}

		/**
			Set PhotoOptions

			@scriptmethod setPhotoOptions( photoOptions )

			Returns a promise that resolves when the options are successfully set. Due to platform differences some
			options might not be valid on all platforms.

				<CameraView ux:Name="Camera" />
				<JavaScript>
					Camera.getCameraInfo()
						.then(function(info) {
							if ("photoResolutions" in info) {
								// photoResolutions is an array of supported resolutions, for example: { width: 1920, height: 1080 }
								var resolution = pick_appropriate_resolution(info["photoResolutions"]);
								var options = {};
								options[Camera.OPTION_PHOTO_RESOLUTION] = resolution;

								Camera.setPhotoOptions(options)
									.then(function() { })
									.catch(function(error) { });
							}
						})
				</JavaScript>

			On Android, `OPTION_PHOTO_QUALITY` can also be used to set the JPEG quality from 1 to 100.
		*/
		static Future<PhotoOption[]> setPhotoOptions(Context context, CameraViewBase self, object[] args)
		{
			if (args.Length != 1)
				return new Promise<PhotoOption[]>().RejectWithMessage("An argument with photo options must be provided");

			var obj = args[0] as Fuse.Scripting.Object;
			if (obj == null)
				return new Promise<PhotoOption[]>().RejectWithMessage("Invalid argument");

			PhotoOption[] options = null;

			try
			{
				options = PhotoOption.From(obj);
			}
			catch(Exception e)
			{
				var p = new Promise<PhotoOption[]>();
				p.Reject(e);
				return p;
			}

			return new SetPhotoOptionsClosure(options, self);
		}

		class SetVideoOptionsClosure : Promise<Nothing>
		{
			CameraViewBase _cameraViewBase;
			VideoOptions _options;

			public SetVideoOptionsClosure(VideoOptions options, CameraViewBase cameraViewBase)
			{
				_options = options;
				_cameraViewBase = cameraViewBase;
				UpdateManager.PostAction(Dispatch);
			}

			void Dispatch()
			{
				_cameraViewBase.SetVideoOptions(_options).Then(Resolve, Reject);
			}
		}

		/**
			Set video options

			@scriptmethod setVideoOptions( videoOptions )

			Sets the recording resolution, frame rate, bit rate, audio and stabilization options.
			The resolution is treated as a hint; the platform picks the closest supported profile.
			Set these options before switching to `CAPTURE_MODE_VIDEO`.

				<CameraView ux:Name="Camera" />
				<JavaScript>
					var options = {};
					options[Camera.OPTION_VIDEO_RESOLUTION] = { width: 1920, height: 1080 };
					options[Camera.OPTION_VIDEO_FRAME_RATE] = 30;
					options[Camera.OPTION_VIDEO_AUDIO_ENABLED] = true;

					Camera.setVideoOptions(options)
						.then(function() { })
						.catch(function(error) { });
				</JavaScript>
		*/
		static Future<Nothing> setVideoOptions(Context context, CameraViewBase self, object[] args)
		{
			if (args.Length != 1)
				return new Promise<Nothing>().RejectWithMessage("An argument with video options must be provided");

			var obj = args[0] as Fuse.Scripting.Object;
			if (obj == null)
				return new Promise<Nothing>().RejectWithMessage("Invalid argument");

			VideoOptions options = null;

			try
			{
				options = VideoOptions.From(obj);
			}
			catch (Exception e)
			{
				var p = new Promise<Nothing>();
				p.Reject(e);
				return p;
			}

			return new SetVideoOptionsClosure(options, self);
		}

		/**
			Get camera capabilities

			@scriptmethod getCameraCapabilities()

			Returns a promise that resolves to an object describing what the loaded camera can do.
			The object contains `zoomSupported`, `minZoom`, `maxZoom`, `torchSupported`,
			`photoResolutions`, `supportedFlashModes`, `supportedFacings`, and exposure
			compensation limits where available.

				<CameraView ux:Name="Camera" />
				<JavaScript>
					Camera.getCameraCapabilities()
						.then(function(caps) {
							console.log("zoom: " + caps[Camera.CAP_MIN_ZOOM] + " - " + caps[Camera.CAP_MAX_ZOOM]);
							console.log("torch: " + caps[Camera.CAP_TORCH_SUPPORTED]);
						})
						.catch(function(error) { });
				</JavaScript>
		*/
		static Future<CameraCapabilities> getCameraCapabilities(Context context, CameraViewBase self, object[] args)
		{
			return self.GetCameraCapabilities();
		}

		/**
			Set zoom factor

			@scriptmethod setZoom( zoom )

			Returns a promise that resolves to the zoom factor actually applied by the camera.
			`1.0` means no zoom. Use `getCameraCapabilities()` to read `minZoom` and `maxZoom`.

				<CameraView ux:Name="Camera" />
				<JavaScript>
					Camera.setZoom(2.0)
						.then(function(zoom) { console.log("Zoom: " + zoom); })
						.catch(function(error) { });
				</JavaScript>
		*/
		static Future<float> setZoom(Context context, CameraViewBase self, object[] args)
		{
			if (args.Length != 1)
				return new Promise<float>().RejectWithMessage("An argument for zoom must be provided");

			return self.SetZoom((float)Marshal.ToDouble(args[0]));
		}

		static Future<float> getZoom(Context context, CameraViewBase self, object[] args)
		{
			return self.GetZoom();
		}

		/**
			Turn the torch on or off

			@scriptmethod setTorchMode( on )

			Returns a promise that resolves to the current torch state. The torch is separate
			from the capture flash mode. Use `getCameraCapabilities()` to check `torchSupported`.

				<CameraView ux:Name="Camera" />
				<JavaScript>
					Camera.setTorchMode(true)
						.then(function(isOn) { console.log("Torch: " + isOn); })
						.catch(function(error) { });
				</JavaScript>
		*/
		static Future<bool> setTorchMode(Context context, CameraViewBase self, object[] args)
		{
			if (args.Length != 1)
				return new Promise<bool>().RejectWithMessage("An argument for torch mode must be provided");

			return self.SetTorchMode(Marshal.ToBool(args[0]));
		}

		static Future<bool> isTorchOn(Context context, CameraViewBase self, object[] args)
		{
			return self.IsTorchOn();
		}

		/**
			Set exposure compensation

			@scriptmethod setExposureCompensation( value )

			Returns a promise that resolves to the exposure compensation actually applied.
			Use `getCameraCapabilities()` to read the supported range and step.

				<CameraView ux:Name="Camera" />
				<JavaScript>
					Camera.setExposureCompensation(0.5)
						.then(function(value) { console.log("Exposure: " + value); })
						.catch(function(error) { });
				</JavaScript>
		*/
		static Future<float> setExposureCompensation(Context context, CameraViewBase self, object[] args)
		{
			if (args.Length != 1)
				return new Promise<float>().RejectWithMessage("An argument for exposure compensation must be provided");

			return self.SetExposureCompensation((float)Marshal.ToDouble(args[0]));
		}

		static Future<float> getExposureCompensation(Context context, CameraViewBase self, object[] args)
		{
			return self.GetExposureCompensation();
		}

		static Future<CameraLens[]> getAvailableLenses(Context context, CameraViewBase self, object[] args)
		{
			return self.GetAvailableLenses();
		}

		static Future<string> setCameraLens(Context context, CameraViewBase self, object[] args)
		{
			if (args.Length != 1)
				return new Promise<string>().RejectWithMessage("An argument for lens id must be provided");

			var lensId = args[0] as string;
			if (lensId == null)
				return new Promise<string>().RejectWithMessage("Invalid argument");

			return self.SetCameraLens(lensId);
		}

		static Future<ManualExposureSettings> setManualExposure(Context context, CameraViewBase self, object[] args)
		{
			if (args.Length != 2)
				return new Promise<ManualExposureSettings>().RejectWithMessage("Arguments for iso and shutter seconds must be provided");

			return self.SetManualExposure(
				(float)Marshal.ToDouble(args[0]),
				(float)Marshal.ToDouble(args[1]));
		}

		static Future<ManualExposureSettings> setAutoExposure(Context context, CameraViewBase self, object[] args)
		{
			return self.SetAutoExposure();
		}

		static Future<ManualExposureSettings> getManualExposure(Context context, CameraViewBase self, object[] args)
		{
			return self.GetManualExposure();
		}

		/**
			Scan a barcode

			@scriptmethod scanBarcode( formats )

			Returns a promise that resolves to the first barcode or QR code found in the
			live preview. The result has a `value` and a `format` field, also available
			as `BARCODE_VALUE` and `BARCODE_FORMAT`. Scanning stops as soon as a code is
			found, after which the camera returns to its previous state.

			An optional array of `BARCODE_FORMAT_*` values can be passed to limit which
			formats are scanned. To keep scanning call `scanBarcode()` again when the
			promise resolves, or use `startBarcodeScanning()`.

				<CameraView ux:Name="Camera" />
				<JavaScript>
					Camera.scanBarcode()
						.then(function(barcode) {
							console.log(barcode[Camera.BARCODE_VALUE] + " (" + barcode[Camera.BARCODE_FORMAT] + ")");
						})
						.catch(function(error) { });
				</JavaScript>
		*/
		static Future<Barcode> scanBarcode(Context context, CameraViewBase self, object[] args)
		{
			if (args.Length > 0)
				return self.ScanBarcode(ParseBarcodeFormats(args[0]));

			return self.ScanBarcode();
		}

		/**
			Start scanning barcodes continuously

			@scriptmethod startBarcodeScanning( onDetected, formats )

			Starts scanning the live preview and calls `onDetected` with every new barcode
			until `stopBarcodeScanning()` is called. The promise resolves when scanning
			has started. Repeats of the same value are not reported again.

			An optional array of `BARCODE_FORMAT_*` values can be passed to limit which
			formats are scanned.

				<JavaScript>
					Camera.startBarcodeScanning(function(barcode) {
						console.log("Detected: " + barcode[Camera.BARCODE_VALUE]);
					}, [Camera.BARCODE_FORMAT_QR_CODE])
						.then(function() { })
						.catch(function(error) { });
				</JavaScript>
		*/
		static Future<Nothing> startBarcodeScanning(Context context, CameraViewBase self, object[] args)
		{
			if (args.Length < 1 || !(args[0] is Function))
				return new Promise<Nothing>().RejectWithMessage("A barcode callback function must be provided");

			var onDetected = args[0] as Function;
			var formats = args.Length > 1 ? ParseBarcodeFormats(args[1]) : null;

			return self.StartBarcodeScanning(barcode => OnBarcodeDetected(context, onDetected, barcode), formats);
		}

		static void OnBarcodeDetected(Context context, Function onDetected, Barcode barcode)
		{
			context.Invoke(c => onDetected.Call(c, ConvertBarcode(c, barcode)));
		}

		/**
			Stop scanning barcodes

			@scriptmethod stopBarcodeScanning()

			Stops a scan started with `startBarcodeScanning()`. The promise resolves to
			`true` if a scan was running.
		*/
		static Future<bool> stopBarcodeScanning(Context context, CameraViewBase self, object[] args)
		{
			return self.StopBarcodeScanning();
		}

		/**
			Set white balance

			@scriptmethod setWhiteBalance( whiteBalance )

			Returns a promise that resolves to the white balance mode that was applied.
			Use one of the `WHITE_BALANCE_*` constants. `getCameraCapabilities()`
			reports the modes the current camera supports in `CAP_WHITE_BALANCE_MODES`.

				<CameraView ux:Name="Camera" />
				<JavaScript>
					Camera.setWhiteBalance(Camera.WHITE_BALANCE_DAYLIGHT)
						.then(function(mode) { console.log("White balance: " + mode); })
						.catch(function(error) { });
				</JavaScript>
		*/
		static Future<WhiteBalance> setWhiteBalance(Context context, CameraViewBase self, object[] args)
		{
			if (args.Length != 1)
				return new Promise<WhiteBalance>().RejectWithMessage("A white balance mode must be provided");

			var value = args[0] as string;
			var whiteBalance = WhiteBalance.Auto;
			if (value == null || !WhiteBalanceHelpers.TryParse(value, out whiteBalance))
				return new Promise<WhiteBalance>().RejectWithMessage("Invalid white balance mode");

			return self.SetWhiteBalance(whiteBalance);
		}

		static Future<WhiteBalance> getWhiteBalance(Context context, CameraViewBase self, object[] args)
		{
			return self.GetWhiteBalance();
		}

		/**
			Set manual white balance

			@scriptmethod setWhiteBalanceTemperature( kelvin, tint )

			Locks the white balance to a color temperature in Kelvin and a tint. A positive
			tint is magenta, a negative tint is green. Returns a promise that resolves to
			the applied values.

				<JavaScript>
					Camera.setWhiteBalanceTemperature(5000, 0)
						.then(function(settings) { console.log(settings.isManual, settings.kelvin, settings.tint); })
						.catch(function(error) { });
				</JavaScript>
		*/
		static Future<WhiteBalanceSettings> setWhiteBalanceTemperature(Context context, CameraViewBase self, object[] args)
		{
			if (args.Length != 2)
				return new Promise<WhiteBalanceSettings>().RejectWithMessage("Arguments for kelvin and tint must be provided");

			return self.SetWhiteBalanceTemperature(
				(float)Marshal.ToDouble(args[0]),
				(float)Marshal.ToDouble(args[1]));
		}

		static Future<WhiteBalanceSettings> getWhiteBalanceTemperature(Context context, CameraViewBase self, object[] args)
		{
			return self.GetWhiteBalanceTemperature();
		}

		/**
			Set focus mode

			@scriptmethod setFocusMode( focusMode )

			Controls how the camera focuses. Use `FOCUS_MODE_AUTO` to focus once,
			`FOCUS_MODE_CONTINUOUS` to keep adjusting the focus and `FOCUS_MODE_LOCKED`
			to keep the focus where it currently is. Returns the applied mode.

				<JavaScript>
					Camera.setFocusMode(Camera.FOCUS_MODE_CONTINUOUS)
						.then(function(mode) { console.log("Focus mode: " + mode); })
						.catch(function(error) { });
				</JavaScript>
		*/
		static Future<FocusMode> setFocusMode(Context context, CameraViewBase self, object[] args)
		{
			if (args.Length != 1)
				return new Promise<FocusMode>().RejectWithMessage("A focus mode must be provided");

			var value = args[0] as string;
			var focusMode = FocusMode.Continuous;
			if (value == null || !FocusModeHelpers.TryParse(value, out focusMode))
				return new Promise<FocusMode>().RejectWithMessage("Invalid focus mode");

			return self.SetFocusMode(focusMode);
		}

		static Future<FocusMode> getFocusMode(Context context, CameraViewBase self, object[] args)
		{
			return self.GetFocusMode();
		}

		/**
			Set mirror mode

			@scriptmethod setMirrorMode( mirrorMode )

			Controls mirroring of the preview and captured media. `MIRROR_MODE_AUTO`
			mirrors the preview for the front camera only (the default), `MIRROR_MODE_ON`
			mirrors everything and `MIRROR_MODE_OFF` mirrors nothing. Returns the applied mode.

				<JavaScript>
					Camera.setMirrorMode(Camera.MIRROR_MODE_ON)
						.then(function(mode) { console.log("Mirror mode: " + mode); })
						.catch(function(error) { });
				</JavaScript>
		*/
		static Future<MirrorMode> setMirrorMode(Context context, CameraViewBase self, object[] args)
		{
			if (args.Length != 1)
				return new Promise<MirrorMode>().RejectWithMessage("A mirror mode must be provided");

			var value = args[0] as string;
			var mirrorMode = MirrorMode.Auto;
			if (value == null || !MirrorModeHelpers.TryParse(value, out mirrorMode))
				return new Promise<MirrorMode>().RejectWithMessage("Invalid mirror mode");

			return self.SetMirrorMode(mirrorMode);
		}

		static Future<MirrorMode> getMirrorMode(Context context, CameraViewBase self, object[] args)
		{
			return self.GetMirrorMode();
		}

		/**
			Start face detection

			@scriptmethod startFaceDetection( onFaces )

			Starts detecting faces in the live preview and calls `onFaces` with the faces
			found in each analyzed frame. The promise resolves when detection has started.
			Face detection and `startBarcodeScanning()` cannot run at the same time.

			The face bounds are normalized to the preview (0 to 1), and `FACE_ID` is -1
			when the platform does not track faces.

				<JavaScript>
					Camera.startFaceDetection(function(faces) {
						faces.forEach(function(face) {
							console.log(face[Camera.FACE_ID] + ": " + face[Camera.FACE_X] + ", " + face[Camera.FACE_Y]);
						});
					})
						.then(function() { })
						.catch(function(error) { });
				</JavaScript>
		*/
		static Future<Nothing> startFaceDetection(Context context, CameraViewBase self, object[] args)
		{
			if (args.Length < 1 || !(args[0] is Function))
				return new Promise<Nothing>().RejectWithMessage("A face callback function must be provided");

			var onFaces = args[0] as Function;
			return self.StartFaceDetection(faces => OnFacesDetected(context, onFaces, faces));
		}

		static void OnFacesDetected(Context context, Function onFaces, DetectedFace[] faces)
		{
			context.Invoke(c => onFaces.Call(c, ConvertDetectedFaces(c, faces)));
		}

		static object ConvertDetectedFaces(Context c, DetectedFace[] faces)
		{
			object[] values = new object[faces.Length];
			for (var i = 0; i < faces.Length; i++)
			{
				var obj = c.NewObject();
				obj[DetectedFace.IdName] = faces[i].Id;
				obj[DetectedFace.XName] = (double)faces[i].X;
				obj[DetectedFace.YName] = (double)faces[i].Y;
				obj[DetectedFace.WidthName] = (double)faces[i].Width;
				obj[DetectedFace.HeightName] = (double)faces[i].Height;
				obj[DetectedFace.RollName] = (double)faces[i].Roll;
				obj[DetectedFace.YawName] = (double)faces[i].Yaw;
				values[i] = obj;
			}
			return values;
		}

		/**
			Stop face detection

			@scriptmethod stopFaceDetection()

			Stops detection started with `startFaceDetection()`. The promise resolves to
			`true` if detection was running.
		*/
		static Future<bool> stopFaceDetection(Context context, CameraViewBase self, object[] args)
		{
			return self.StopFaceDetection();
		}

		/**
			Start monitoring the camera state

			@scriptmethod startErrorMonitoring( onEvent )

			Calls `onEvent` when the camera reports a problem or is interrupted. The event
			has a `type` (`EVENT_ERROR`, `EVENT_INTERRUPTED` or `EVENT_RESUMED`), a
			platform specific `reason` and a human readable `message`.

				<JavaScript>
					Camera.startErrorMonitoring(function(event) {
						console.log(event[Camera.EVENT_TYPE] + ": " + event[Camera.EVENT_REASON]);
					})
						.then(function() { })
						.catch(function(error) { });
				</JavaScript>
		*/
		static Future<Nothing> startErrorMonitoring(Context context, CameraViewBase self, object[] args)
		{
			if (args.Length < 1 || !(args[0] is Function))
				return new Promise<Nothing>().RejectWithMessage("A camera event callback function must be provided");

			var onEvent = args[0] as Function;
			return self.StartErrorMonitoring(cameraEvent => OnCameraEvent(context, onEvent, cameraEvent));
		}

		static void OnCameraEvent(Context context, Function onEvent, CameraEvent cameraEvent)
		{
			context.Invoke(c => onEvent.Call(c, ConvertCameraEvent(c, cameraEvent)));
		}

		static object ConvertCameraEvent(Context c, CameraEvent cameraEvent)
		{
			var obj = c.NewObject();
			obj[CameraEvent.TypeName] = cameraEvent.Type;
			obj[CameraEvent.ReasonName] = cameraEvent.Reason;
			obj[CameraEvent.MessageName] = cameraEvent.Message;
			return obj;
		}

		/**
			Stop monitoring the camera state

			@scriptmethod stopErrorMonitoring()

			Stops monitoring started with `startErrorMonitoring()`. The promise resolves to
			`true` if monitoring was active.
		*/
		static Future<bool> stopErrorMonitoring(Context context, CameraViewBase self, object[] args)
		{
			return self.StopErrorMonitoring();
		}

		/**
			Start analysing camera frames

			@scriptmethod startFrameAnalysis( onStats, options )

			Calls `onStats` with statistics for the analysed frames: a luminance
			histogram, mean and percentile luminance, the clipped fraction, and how long
			the frame took to analyse. Everything except `timestamp` and `analysisTime`
			is normalized to 0..1.

			`options` is optional. `maxFps` limits the callback rate (default 15),
			`resolution` sets the analysis resolution (default 640x480) and applies when
			analysis starts, and `lumaWidth`/`lumaHeight` additionally request a
			downscaled luminance image as an `ArrayBuffer`.

			Statistics are computed natively. Nothing is sent to JavaScript unless it is
			asked for, and frame analysis can run together with barcode scanning and face
			detection since they share one analysis stream.

				<CameraView ux:Name="Camera" />
				<JavaScript>
					var options = {};
					options[Camera.OPTION_ANALYSIS_MAX_FPS] = 10;

					Camera.startFrameAnalysis(function(stats) {
						console.log("mean " + stats[Camera.STATS_MEAN] +
							", clipped " + stats[Camera.STATS_CLIPPED_HIGH]);
					}, options)
						.then(function() { })
						.catch(function(error) { });
				</JavaScript>
		*/
		static Future<Nothing> startFrameAnalysis(Context context, CameraViewBase self, object[] args)
		{
			if (args.Length < 1 || !(args[0] is Function))
				return new Promise<Nothing>().RejectWithMessage("A statistics callback function must be provided");

			var onStats = args[0] as Function;
			FrameAnalysisOptions options = null;

			if (args.Length > 1 && args[1] != null)
			{
				var obj = args[1] as Fuse.Scripting.Object;
				if (obj == null)
					return new Promise<Nothing>().RejectWithMessage("Invalid frame analysis options");

				try
				{
					options = FrameAnalysisOptions.From(obj);
				}
				catch (Exception e)
				{
					var p = new Promise<Nothing>();
					p.Reject(e);
					return p;
				}
			}

			return self.StartFrameAnalysis(stats => OnFrameStatistics(context, onStats, stats), options);
		}

		static void OnFrameStatistics(Context context, Function onStats, FrameStatistics stats)
		{
			context.Invoke(c => onStats.Call(c, ConvertFrameStatistics(c, stats)));
		}

		static object ConvertFrameStatistics(Context c, FrameStatistics stats)
		{
			var obj = c.NewObject();
			obj[FrameStatistics.TimestampName] = stats.Timestamp;
			obj[FrameStatistics.MeanName] = stats.Mean;
			obj[FrameStatistics.P1Name] = stats.P1;
			obj[FrameStatistics.P50Name] = stats.P50;
			obj[FrameStatistics.P99Name] = stats.P99;
			obj[FrameStatistics.ClippedLowName] = stats.ClippedLow;
			obj[FrameStatistics.ClippedHighName] = stats.ClippedHigh;
			obj[FrameStatistics.HistogramName] = ConvertHistogram(c, stats.Histogram);
			obj[FrameStatistics.AnalysisTimeName] = stats.AnalysisTime;

			if (stats.Luma != null)
			{
				obj[FrameStatistics.LumaName] = stats.Luma;
				obj[FrameStatistics.LumaWidthName] = stats.LumaWidth;
				obj[FrameStatistics.LumaHeightName] = stats.LumaHeight;
			}

			return obj;
		}

		static object ConvertHistogram(Context c, double[] histogram)
		{
			if (histogram == null)
				return null;

			var array = c.NewArray();
			for (var i = 0; i < histogram.Length; i++)
				array[i] = histogram[i];

			return array;
		}

		/**
			Stop analysing camera frames

			@scriptmethod stopFrameAnalysis()

			Stops analysis started with `startFrameAnalysis()`. The promise resolves to
			`true` if analysis was running.
		*/
		static Future<bool> stopFrameAnalysis(Context context, CameraViewBase self, object[] args)
		{
			return self.StopFrameAnalysis();
		}

		/**
			Set the analysis overlay

			@scriptmethod setOverlayOptions( options )

			Draws an overlay on top of the preview from the analysed frames. `zebra`
			marks pixels at or above the given luminance with diagonal stripes, and
			`peaking` highlights edges, where a higher value detects weaker edges. Both
			are normalized to 0..1 and 0 turns that part off.

			The overlay is drawn natively, so it does not cost anything in JavaScript
			and keeps working while the preview is animating. It is not part of the
			captured photo or video.

				<CameraView ux:Name="Camera" />
				<JavaScript>
					var options = {};
					options[Camera.OPTION_OVERLAY_ZEBRA] = 0.95;
					options[Camera.OPTION_OVERLAY_PEAKING] = 0.5;

					Camera.setOverlayOptions(options)
						.then(function(applied) { })
						.catch(function(error) { });
				</JavaScript>
		*/
		static Future<OverlayOptions> setOverlayOptions(Context context, CameraViewBase self, object[] args)
		{
			if (args.Length < 1 || !(args[0] is Fuse.Scripting.Object))
				return new Promise<OverlayOptions>().RejectWithMessage("An argument with overlay options must be provided");

			OverlayOptions options = null;

			try
			{
				options = OverlayOptions.From(args[0] as Fuse.Scripting.Object);
			}
			catch (Exception e)
			{
				var p = new Promise<OverlayOptions>();
				p.Reject(e);
				return p;
			}

			return self.SetOverlayOptions(options);
		}

		static object ConvertOverlayOptions(Context c, OverlayOptions options)
		{
			var obj = c.NewObject();
			obj[OverlayOptions.ZebraName] = options.Zebra;
			obj[OverlayOptions.PeakingName] = options.Peaking;
			return obj;
		}

		static string ConvertWhiteBalance(Context context, WhiteBalance whiteBalance)
		{
			return whiteBalance.AsString();
		}

		static object ConvertWhiteBalanceSettings(Context c, WhiteBalanceSettings settings)
		{
			var obj = c.NewObject();
			obj[WhiteBalanceSettings.IsManualName] = settings.IsManual;
			obj[WhiteBalanceSettings.KelvinName] = (double)settings.Kelvin;
			obj[WhiteBalanceSettings.TintName] = (double)settings.Tint;
			return obj;
		}

		static string ConvertFocusMode(Context context, FocusMode focusMode)
		{
			return focusMode.AsString();
		}

		static string ConvertMirrorMode(Context context, MirrorMode mirrorMode)
		{
			return mirrorMode.AsString();
		}

		static string[] ParseBarcodeFormats(object value)
		{
			var formats = value as object[];
			if (formats == null)
				return null;

			var result = new List<string>();
			for (int i = 0; i < formats.Length; i++)
			{
				var format = formats[i] as string;
				if (format != null && format.Length > 0)
					result.Add(format);
			}

			return result.Count == 0 ? null : result.ToArray();
		}

		static object ConvertManualExposureSettings(Context c, ManualExposureSettings settings)
		{
			var obj = c.NewObject();
			obj[ManualExposureSettings.IsManualName] = settings.IsManual;
			obj[ManualExposureSettings.IsoName] = (double)settings.Iso;
			obj[ManualExposureSettings.ShutterSecondsName] = (double)settings.ShutterSeconds;
			return obj;
		}

		static object ConvertBarcode(Context c, Barcode barcode)
		{
			var obj = c.NewObject();
			obj[Barcode.ValueName] = barcode.Value;
			obj[Barcode.FormatName] = barcode.Format;
			return obj;
		}

		static object ConvertFloat(Context c, float value)
		{
			return value;
		}

		static object ConvertBool(Context c, bool value)
		{
			return value;
		}

		static object ConvertCameraLenses(Context c, CameraLens[] lenses)
		{
			object[] values = new object[lenses.Length];
			for (var i = 0; i < lenses.Length; i++)
			{
				var obj = c.NewObject();
				obj[CameraLens.IdName] = lenses[i].Id;
				obj[CameraLens.FacingName] = ConvertCameraFacing(c, lenses[i].Facing);
				obj[CameraLens.NameName] = lenses[i].Name;
				values[i] = obj;
			}
			return c.NewArray(values);
		}

		static object ConvertCameraCapabilities(Context c, CameraCapabilities cameraCapabilities)
		{
			var dict = c.NewObject();
			dict[CameraCapabilities.ZoomSupportedName] = cameraCapabilities.ZoomSupported;
			dict[CameraCapabilities.MinZoomName] = (double)cameraCapabilities.MinZoom;
			dict[CameraCapabilities.MaxZoomName] = (double)cameraCapabilities.MaxZoom;
			dict[CameraCapabilities.TorchSupportedName] = cameraCapabilities.TorchSupported;
			dict[CameraCapabilities.PhotoResolutionsName] = ConvertPhotoResolutions(c, cameraCapabilities.PhotoResolutions);
			dict[CameraCapabilities.SupportedFlashModesName] = ConvertFlashModes(c, cameraCapabilities.SupportedFlashModes);
			dict[CameraCapabilities.SupportedFacingsName] = ConvertCameraFacings(c, cameraCapabilities.SupportedFacings);
			dict[CameraCapabilities.MinExposureCompensationName] = (double)cameraCapabilities.MinExposureCompensation;
			dict[CameraCapabilities.MaxExposureCompensationName] = (double)cameraCapabilities.MaxExposureCompensation;
			dict[CameraCapabilities.ExposureCompensationStepName] = (double)cameraCapabilities.ExposureCompensationStep;
			dict[CameraCapabilities.ManualExposureSupportedName] = cameraCapabilities.ManualExposureSupported;
			dict[CameraCapabilities.MinIsoName] = (double)cameraCapabilities.MinIso;
			dict[CameraCapabilities.MaxIsoName] = (double)cameraCapabilities.MaxIso;
			dict[CameraCapabilities.MinShutterSecondsName] = (double)cameraCapabilities.MinShutterSeconds;
			dict[CameraCapabilities.MaxShutterSecondsName] = (double)cameraCapabilities.MaxShutterSeconds;
			var whiteBalanceModes = cameraCapabilities.WhiteBalanceModes;
			object[] whiteBalanceValues = new object[whiteBalanceModes.Length];
			for (var i = 0; i < whiteBalanceModes.Length; i++)
				whiteBalanceValues[i] = whiteBalanceModes[i].AsString();
			dict[CameraCapabilities.WhiteBalanceModesName] = whiteBalanceValues;
			dict[CameraCapabilities.ManualWhiteBalanceSupportedName] = cameraCapabilities.ManualWhiteBalanceSupported;
			var focusModes = cameraCapabilities.FocusModes;
			object[] focusModeValues = new object[focusModes.Length];
			for (var i = 0; i < focusModes.Length; i++)
				focusModeValues[i] = focusModes[i].AsString();
			dict[CameraCapabilities.FocusModesName] = focusModeValues;
			var mirrorModes = cameraCapabilities.MirrorModes;
			object[] mirrorModeValues = new object[mirrorModes.Length];
			for (var i = 0; i < mirrorModes.Length; i++)
				mirrorModeValues[i] = mirrorModes[i].AsString();
			dict[CameraCapabilities.MirrorModesName] = mirrorModeValues;
			return dict;
		}

		static object ConvertPhotoResolutions(Context c, int2[] sizes)
		{
			object[] values = new object[sizes.Length];
			for (var i = 0; i < sizes.Length; i++)
			{
				var obj = c.NewObject();
				obj["width"] = sizes[i].X;
				obj["height"] = sizes[i].Y;
				values[i] = obj;
			}
			return c.NewArray(values);
		}

		static object ConvertFlashModes(Context c, FlashMode[] flashModes)
		{
			object[] values = new object[flashModes.Length];
			for (var i = 0; i < flashModes.Length; i++)
				values[i] = ConvertFlashMode(c, flashModes[i]);
			return c.NewArray(values);
		}

		static object ConvertCameraFacings(Context c, CameraFacing[] facings)
		{
			object[] values = new object[facings.Length];
			for (var i = 0; i < facings.Length; i++)
				values[i] = ConvertCameraFacing(c, facings[i]);
			return c.NewArray(values);
		}

		static object ConvertPhoto(Context c, Photo pictureResult)
		{
			return c.Unwrap(pictureResult);
		}

		static object ConvertRecordingSession(Context c, RecordingSession recordingSession)
		{
			return c.Unwrap(recordingSession);
		}

		static object ConvertCaptureMode(Context c, CaptureMode captureMode)
		{
			return EnumHelpers.AsString(captureMode);
		}

		static object ConvertCameraFacing(Context c, CameraFacing cameraFacing)
		{
			return EnumHelpers.AsString(cameraFacing);
		}

		static object ConvertFlashMode(Context c, FlashMode flashMode)
		{
			return EnumHelpers.AsString(flashMode);
		}

		static object ConvertCameraInfo(Context c, CameraInfo cameraInfo)
		{
			var dict = c.NewObject();
			dict[CameraInfo.FlashModeName] = ConvertFlashMode(c, cameraInfo.FlashMode);
			dict[CameraInfo.CaptureModeName] = ConvertCaptureMode(c, cameraInfo.CaptureMode);
			dict[CameraInfo.CameraFacingName] = ConvertCameraFacing(c, cameraInfo.CameraFacing);
			dict[CameraInfo.ZoomName] = (double)cameraInfo.Zoom;
			dict[CameraInfo.TorchOnName] = cameraInfo.TorchOn;
			dict[CameraInfo.ExposureCompensationName] = (double)cameraInfo.ExposureCompensation;
			dict[CameraInfo.LensIdName] = cameraInfo.LensId;
			dict[CameraInfo.WhiteBalanceName] = cameraInfo.WhiteBalance.AsString();
			dict[CameraInfo.FocusModeName] = cameraInfo.FocusMode.AsString();
			dict[CameraInfo.MirrorModeName] = cameraInfo.MirrorMode.AsString();
			var sizes = cameraInfo.PhotoResolutions;
			if (sizes.Length > 0)
				dict[InfoPhotoResolutions] = ConvertPhotoResolutions(c, sizes);
			dict[CameraInfo.SupportedFlashModesName] = ConvertFlashModes(c, cameraInfo.SupportedFlashModes);
			return dict;
		}

		static object ConvertPhotoOptions(Context c, PhotoOption[] options)
		{
			return null;
		}
	}
}
