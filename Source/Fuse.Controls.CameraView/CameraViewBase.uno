using Uno;
using Uno.Compiler.ExportTargetInterop;
using Uno.Threading;

using Fuse;
using Fuse.Controls.Native;
using Fuse.Scripting;

namespace Fuse.Controls
{
	public enum PreviewStretchMode
	{
		Uniform,
		UniformToFill,
	}

	public enum FlashMode
	{
		Auto,
		On,
		Off,
	}

	public enum CaptureMode
	{
		Photo,
		Video,
	}

	public enum CameraFacing
	{
		Back,
		Front,
	}

	public abstract partial class CameraViewBase : LayoutControl, ICameraViewHost
	{
		PreviewStretchMode _previewStretchMode;
		public PreviewStretchMode PreviewStretchMode
		{
			get { return _previewStretchMode; }
			set
			{
				if (_previewStretchMode != value)
				{
					_previewStretchMode = value;
					CameraView.PreviewStretchMode = value;
				}
			}
		}

		ICamera _camera;
		ICamera Camera
		{
			get { return _camera ?? DummyCameraView.Instance; }
		}

		ICameraView CameraView
		{
			get { return ViewHandle as ICameraView ?? DummyCameraView.Instance; }
		}

		protected override void OnUnrooted()
		{
			base.OnUnrooted();
			_camera = null;
			_cameraPromise = null;
		}

		extern(ANDROID || iOS)
		protected override void PushPropertiesToNativeView()
		{
			CameraView.PreviewStretchMode = PreviewStretchMode;
		}

		GetCameraInfoPromise _cameraPromise;
		GetCameraInfoPromise CameraPromise
		{
			get { return _cameraPromise ?? (_cameraPromise = new GetCameraInfoPromise()); }
		}

		void ICameraViewHost.OnError(Exception e)
		{
			Fuse.Diagnostics.InternalError(e.Message, this);
			CameraPromise.Reject(e);
		}

		void ICameraViewHost.OnCameraLoaded(ICamera camera)
		{
			_camera = camera;
			CameraPromise.OnCameraLoaded(camera);
			ReapplySettingsIfNeeded();
		}

		// The camera controls are recorded as they are set so they can be restored
		// when the platform recreates the camera or switches to another device.
		bool _hasFlashMode;
		FlashMode _flashMode;
		bool _hasTorchMode;
		bool _torchOn;
		bool _hasZoom;
		float _zoom;
		bool _hasExposureCompensation;
		float _exposureCompensation;
		bool _hasManualExposure;
		bool _manualExposureEnabled;
		float _manualIso;
		float _manualShutterSeconds;
		bool _hasWhiteBalance;
		bool _whiteBalanceIsManual;
		WhiteBalance _whiteBalance;
		float _whiteBalanceKelvin;
		float _whiteBalanceTint;
		bool _hasFocusMode;
		FocusMode _focusMode;
		bool _hasMirrorMode;
		MirrorMode _mirrorMode;

		ICamera _lastAppliedCamera;

		bool HasRecordedSettings
		{
			get
			{
				return _hasFlashMode || _hasTorchMode || _hasZoom || _hasExposureCompensation ||
					_hasManualExposure || _hasWhiteBalance || _hasFocusMode || _hasMirrorMode;
			}
		}

		void ReapplySettingsIfNeeded()
		{
			if (!HasRecordedSettings)
				return;

			if (_lastAppliedCamera == _camera)
				return;

			_lastAppliedCamera = _camera;
			ApplySettingsStep(0);
		}

		// Restores the recorded controls one at a time. Mirroring goes first since
		// it rebuilds the Android use cases, which resets the capture options.
		void ApplySettingsStep(int step)
		{
			switch (step)
			{
				case 0:
					if (!_hasMirrorMode)
					{
						ApplySettingsStep(1);
						return;
					}
					Camera.SetMirrorMode(_mirrorMode).Then(_ => ApplySettingsStep(1), _ => ApplySettingsStep(1));
					return;

				case 1:
					if (!_hasFocusMode)
					{
						ApplySettingsStep(2);
						return;
					}
					Camera.SetFocusMode(_focusMode).Then(_ => ApplySettingsStep(2), _ => ApplySettingsStep(2));
					return;

				case 2:
					if (!_hasExposureCompensation)
					{
						ApplySettingsStep(3);
						return;
					}
					Camera.SetExposureCompensation(_exposureCompensation).Then(_ => ApplySettingsStep(3), _ => ApplySettingsStep(3));
					return;

				case 3:
					if (!_hasManualExposure)
					{
						ApplySettingsStep(4);
						return;
					}
					if (_manualExposureEnabled)
						Camera.SetManualExposure(_manualIso, _manualShutterSeconds).Then(_ => ApplySettingsStep(4), _ => ApplySettingsStep(4));
					else
						Camera.SetAutoExposure().Then(_ => ApplySettingsStep(4), _ => ApplySettingsStep(4));
					return;

				case 4:
					if (!_hasWhiteBalance)
					{
						ApplySettingsStep(5);
						return;
					}
					if (_whiteBalanceIsManual)
						Camera.SetWhiteBalanceTemperature(_whiteBalanceKelvin, _whiteBalanceTint).Then(_ => ApplySettingsStep(5), _ => ApplySettingsStep(5));
					else
						Camera.SetWhiteBalance(_whiteBalance).Then(_ => ApplySettingsStep(5), _ => ApplySettingsStep(5));
					return;

				case 5:
					if (!_hasFlashMode)
					{
						ApplySettingsStep(6);
						return;
					}
					Camera.SetFlashMode(_flashMode).Then(_ => ApplySettingsStep(6), _ => ApplySettingsStep(6));
					return;

				case 6:
					if (!_hasTorchMode)
					{
						ApplySettingsStep(7);
						return;
					}
					Camera.SetTorchMode(_torchOn).Then(_ => ApplySettingsStep(7), _ => ApplySettingsStep(7));
					return;

				case 7:
					if (!_hasZoom)
					{
						ApplySettingsStep(8);
						return;
					}
					Camera.SetZoom(_zoom).Then(_ => ApplySettingsStep(8), _ => ApplySettingsStep(8));
					return;

				default:
					return;
			}
		}

		public Future<Photo> CapturePhoto()
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<Photo>();

			OnPhotoCaptureStarted();

			var f = Camera.CapturePhoto();
			f.Then(OnPhotoCaptured);
			return f;
		}

		public Future<RecordingSession> StartRecording()
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<RecordingSession>();

			return Camera.StartRecording();
		}

		public Future<CaptureMode> SetCaptureMode(CaptureMode mode)
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<CaptureMode>();

			return Camera.SetCaptureMode(mode);
		}

		public Future<CameraFacing> SetCameraFacing(CameraFacing facing)
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<CameraFacing>();

			_lastAppliedCamera = null;
			return Camera.SetCameraFacing(facing).Then(_ => ReapplySettingsIfNeeded());
		}

		public Future<Nothing> SetCameraFocusPoint(double x, double y, int cameraWidth, int cameraHeight, int isFocusLocked)
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<Nothing>();
			return Camera.SetCameraFocusPoint(x, y, cameraWidth, cameraHeight, isFocusLocked);
		}

		public Future<FlashMode> SetFlashMode(FlashMode mode)
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<FlashMode>();

			_hasFlashMode = true;
			_flashMode = mode;
			return Camera.SetFlashMode(mode);
		}

		class GetCameraInfoPromise : CameraPromise<CameraInfo>
		{
			public void OnCameraLoaded(ICamera camera) { camera.GetCameraInfo().Then(Resolve, Reject); }
		}

		public Future<CameraInfo> GetCameraInfo()
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<CameraInfo>();

			if (_camera == null)
				return CameraPromise;
			else
				return _camera.GetCameraInfo();
		}

		public Future<PhotoOption[]> SetPhotoOptions(PhotoOption[] options)
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<PhotoOption[]>();

			return Camera.SetPhotoOptions(options);
		}

		public Future<CameraCapabilities> GetCameraCapabilities()
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<CameraCapabilities>();

			return Camera.GetCameraCapabilities();
		}

		public Future<Nothing> SetVideoOptions(VideoOptions options)
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<Nothing>();

			return Camera.SetVideoOptions(options);
		}

		public Future<float> SetZoom(float zoom)
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<float>();

			_hasZoom = true;
			_zoom = zoom;
			return Camera.SetZoom(zoom);
		}

		public Future<float> GetZoom()
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<float>();

			return Camera.GetZoom();
		}

		public Future<bool> SetTorchMode(bool on)
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<bool>();

			_hasTorchMode = true;
			_torchOn = on;
			return Camera.SetTorchMode(on);
		}

		public Future<bool> IsTorchOn()
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<bool>();

			return Camera.IsTorchOn();
		}

		public Future<float> SetExposureCompensation(float value)
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<float>();

			_hasExposureCompensation = true;
			_exposureCompensation = value;
			return Camera.SetExposureCompensation(value);
		}

		public Future<float> GetExposureCompensation()
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<float>();

			return Camera.GetExposureCompensation();
		}

		public Future<CameraLens[]> GetAvailableLenses()
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<CameraLens[]>();

			return Camera.GetAvailableLenses();
		}

		public Future<string> SetCameraLens(string lensId)
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<string>();

			_lastAppliedCamera = null;
			return Camera.SetCameraLens(lensId).Then(_ => ReapplySettingsIfNeeded());
		}

		public Future<ManualExposureSettings> SetManualExposure(float iso, float shutterSeconds)
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<ManualExposureSettings>();

			_hasManualExposure = true;
			_manualExposureEnabled = true;
			_manualIso = iso;
			_manualShutterSeconds = shutterSeconds;
			return Camera.SetManualExposure(iso, shutterSeconds);
		}

		public Future<ManualExposureSettings> SetAutoExposure()
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<ManualExposureSettings>();

			_hasManualExposure = true;
			_manualExposureEnabled = false;
			return Camera.SetAutoExposure();
		}

		public Future<ManualExposureSettings> GetManualExposure()
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<ManualExposureSettings>();

			return Camera.GetManualExposure();
		}

		public Future<Barcode> ScanBarcode()
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<Barcode>();

			return Camera.ScanBarcode();
		}

		public Future<WhiteBalance> SetWhiteBalance(WhiteBalance whiteBalance)
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<WhiteBalance>();

			if (whiteBalance == WhiteBalance.Manual)
				return new Promise<WhiteBalance>().RejectWithMessage("Use SetWhiteBalanceTemperature to set a manual white balance");

			_hasWhiteBalance = true;
			_whiteBalanceIsManual = false;
			_whiteBalance = whiteBalance;
			return Camera.SetWhiteBalance(whiteBalance);
		}

		public Future<WhiteBalance> GetWhiteBalance()
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<WhiteBalance>();

			return Camera.GetWhiteBalance();
		}

		public Future<WhiteBalanceSettings> SetWhiteBalanceTemperature(float kelvin, float tint)
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<WhiteBalanceSettings>();

			_hasWhiteBalance = true;
			_whiteBalanceIsManual = true;
			_whiteBalanceKelvin = kelvin;
			_whiteBalanceTint = tint;
			return Camera.SetWhiteBalanceTemperature(kelvin, tint);
		}

		public Future<WhiteBalanceSettings> GetWhiteBalanceTemperature()
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<WhiteBalanceSettings>();

			return Camera.GetWhiteBalanceTemperature();
		}

		public Future<FocusMode> SetFocusMode(FocusMode focusMode)
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<FocusMode>();

			_hasFocusMode = true;
			_focusMode = focusMode;
			return Camera.SetFocusMode(focusMode);
		}

		public Future<FocusMode> GetFocusMode()
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<FocusMode>();

			return Camera.GetFocusMode();
		}

		public Future<MirrorMode> SetMirrorMode(MirrorMode mirrorMode)
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<MirrorMode>();

			_hasMirrorMode = true;
			_mirrorMode = mirrorMode;
			return Camera.SetMirrorMode(mirrorMode);
		}

		public Future<MirrorMode> GetMirrorMode()
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<MirrorMode>();

			return Camera.GetMirrorMode();
		}

		public Future<Nothing> StartFaceDetection(Action<DetectedFace[]> onFaces)
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<Nothing>();

			if (onFaces == null)
				return new Promise<Nothing>().RejectWithMessage("A face callback must be provided");

			return Camera.StartFaceDetection(onFaces);
		}

		public Future<bool> StopFaceDetection()
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<bool>();

			return Camera.StopFaceDetection();
		}

		public Future<Nothing> StartErrorMonitoring(Action<CameraEvent> onEvent)
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<Nothing>();

			if (onEvent == null)
				return new Promise<Nothing>().RejectWithMessage("A camera event callback must be provided");

			return Camera.StartErrorMonitoring(onEvent);
		}

		public Future<bool> StopErrorMonitoring()
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<bool>();

			return Camera.StopErrorMonitoring();
		}

		public Future<Barcode> ScanBarcode(string[] formats)
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<Barcode>();

			return Camera.ScanBarcode(formats);
		}

		public Future<Nothing> StartBarcodeScanning(Action<Barcode> onDetected)
		{
			return StartBarcodeScanning(onDetected, null);
		}

		public Future<Nothing> StartBarcodeScanning(Action<Barcode> onDetected, string[] formats)
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<Nothing>();

			if (onDetected == null)
				return new Promise<Nothing>().RejectWithMessage("A barcode callback must be provided");

			return Camera.StartBarcodeScanning(onDetected, formats);
		}

		public Future<bool> StopBarcodeScanning()
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<bool>();

			return Camera.StopBarcodeScanning();
		}

		public Future<Nothing> StartFrameAnalysis(Action<FrameStatistics> onStats)
		{
			return StartFrameAnalysis(onStats, null);
		}

		public Future<Nothing> StartFrameAnalysis(Action<FrameStatistics> onStats, FrameAnalysisOptions options)
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<Nothing>();

			if (onStats == null)
				return new Promise<Nothing>().RejectWithMessage("A statistics callback must be provided");

			return Camera.StartFrameAnalysis(options ?? FrameAnalysisOptions.Default, onStats);
		}

		public Future<bool> StopFrameAnalysis()
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<bool>();

			return Camera.StopFrameAnalysis();
		}

		public Future<OverlayOptions> SetOverlayOptions(OverlayOptions options)
		{
			if (!IsRootingCompleted)
				return RejectNotRooted<OverlayOptions>();

			if (options == null)
				return new Promise<OverlayOptions>().RejectWithMessage("Overlay options must be provided");

			return Camera.SetOverlayOptions(options);
		}

		Future<T> RejectNotRooted<T>()
		{
			var p = new Promise<T>();
			p.Reject(new Exception(ToString() + " not rooted"));
			return p;
		}

		void OnPhotoCaptured(Photo photo)
		{
			if (IsRootingCompleted)
			{
				var handler = PhotoCaptured;
				if (handler != null)
					handler(photo);
			}
		}

		void OnPhotoCaptureStarted()
		{
			var pcs = PhotoCaptureStarted;
			if (pcs != null)
				pcs(this, EventArgs.Empty);
		}

		internal delegate void PhotoCapturedHandler(Photo photo);

		internal event PhotoCapturedHandler PhotoCaptured;

		internal event EventHandler PhotoCaptureStarted;
	}

	internal interface ICameraViewHost
	{
		void OnCameraLoaded(ICamera camera);
		void OnError(Exception e);
	}

	internal interface ICameraView
	{
		PreviewStretchMode PreviewStretchMode { set; }
	}

	internal interface ICamera
	{
		Future<Photo> CapturePhoto();
		Future<RecordingSession> StartRecording();
		Future<CaptureMode> SetCaptureMode(CaptureMode mode);
		Future<CameraFacing> SetCameraFacing(CameraFacing facing);
		Future<Nothing> SetCameraFocusPoint(double x, double y, int cameraWidth, int cameraHeight, int isFocusLocked);
		Future<FlashMode> SetFlashMode(FlashMode mode);
		Future<PhotoOption[]> SetPhotoOptions(PhotoOption[] options);
		Future<CameraInfo> GetCameraInfo();
		Future<CameraCapabilities> GetCameraCapabilities();
		Future<Nothing> SetVideoOptions(VideoOptions options);
		Future<float> SetZoom(float zoom);
		Future<float> GetZoom();
		Future<bool> SetTorchMode(bool on);
		Future<bool> IsTorchOn();
		Future<float> SetExposureCompensation(float value);
		Future<float> GetExposureCompensation();
		Future<CameraLens[]> GetAvailableLenses();
		Future<string> SetCameraLens(string lensId);
		Future<ManualExposureSettings> SetManualExposure(float iso, float shutterSeconds);
		Future<ManualExposureSettings> SetAutoExposure();
		Future<ManualExposureSettings> GetManualExposure();
		Future<Barcode> ScanBarcode();
		Future<Barcode> ScanBarcode(string[] formats);
		Future<WhiteBalance> SetWhiteBalance(WhiteBalance whiteBalance);
		Future<WhiteBalance> GetWhiteBalance();
		Future<WhiteBalanceSettings> SetWhiteBalanceTemperature(float kelvin, float tint);
		Future<WhiteBalanceSettings> GetWhiteBalanceTemperature();
		Future<FocusMode> SetFocusMode(FocusMode focusMode);
		Future<FocusMode> GetFocusMode();
		Future<MirrorMode> SetMirrorMode(MirrorMode mirrorMode);
		Future<MirrorMode> GetMirrorMode();
		Future<Nothing> StartFaceDetection(Action<DetectedFace[]> onFaces);
		Future<bool> StopFaceDetection();
		Future<Nothing> StartErrorMonitoring(Action<CameraEvent> onEvent);
		Future<bool> StopErrorMonitoring();
		Future<Nothing> StartBarcodeScanning(Action<Barcode> onDetected, string[] formats);
		Future<bool> StopBarcodeScanning();
		Future<Nothing> StartFrameAnalysis(FrameAnalysisOptions options, Action<FrameStatistics> onStats);
		Future<bool> StopFrameAnalysis();
		Future<OverlayOptions> SetOverlayOptions(OverlayOptions options);
	}

	class DummyCameraView : ICameraView, ICamera
	{
		public static readonly DummyCameraView Instance = new DummyCameraView();
		public PreviewStretchMode PreviewStretchMode { set { } }
		public Future<Photo> CapturePhoto() { return Reject<Photo>(); }
		public Future<RecordingSession> StartRecording() { return Reject<RecordingSession>(); }
		public Future<CaptureMode> SetCaptureMode(CaptureMode mode) { return Reject<CaptureMode>(); }
		public Future<CameraFacing> SetCameraFacing(CameraFacing facing) { return Reject<CameraFacing>(); }
		public Future<Nothing> SetCameraFocusPoint(double x, double y, int cameraWidth, int cameraHeight, int isFocusLocked) { return Reject<Nothing>(); }
		public Future<FlashMode> SetFlashMode(FlashMode mode) { return Reject<FlashMode>(); }
		public Future<CameraInfo> GetCameraInfo() { return Reject<CameraInfo>(); }
		public Future<PhotoOption[]> SetPhotoOptions(PhotoOption[] options) { return Reject<PhotoOption[]>(); }
		public Future<CameraCapabilities> GetCameraCapabilities() { return Reject<CameraCapabilities>(); }
		public Future<Nothing> SetVideoOptions(VideoOptions options) { return Reject<Nothing>(); }
		public Future<float> SetZoom(float zoom) { return Reject<float>(); }
		public Future<float> GetZoom() { return Reject<float>(); }
		public Future<bool> SetTorchMode(bool on) { return Reject<bool>(); }
		public Future<bool> IsTorchOn() { return Reject<bool>(); }
		public Future<float> SetExposureCompensation(float value) { return Reject<float>(); }
		public Future<float> GetExposureCompensation() { return Reject<float>(); }
		public Future<CameraLens[]> GetAvailableLenses() { return Reject<CameraLens[]>(); }
		public Future<string> SetCameraLens(string lensId) { return Reject<string>(); }
		public Future<ManualExposureSettings> SetManualExposure(float iso, float shutterSeconds) { return Reject<ManualExposureSettings>(); }
		public Future<ManualExposureSettings> SetAutoExposure() { return Reject<ManualExposureSettings>(); }
		public Future<ManualExposureSettings> GetManualExposure() { return Reject<ManualExposureSettings>(); }
		public Future<Barcode> ScanBarcode() { return Reject<Barcode>(); }
		public Future<Barcode> ScanBarcode(string[] formats) { return Reject<Barcode>(); }
		public Future<WhiteBalance> SetWhiteBalance(WhiteBalance whiteBalance) { return Reject<WhiteBalance>(); }
		public Future<WhiteBalance> GetWhiteBalance() { return Reject<WhiteBalance>(); }
		public Future<WhiteBalanceSettings> SetWhiteBalanceTemperature(float kelvin, float tint) { return Reject<WhiteBalanceSettings>(); }
		public Future<WhiteBalanceSettings> GetWhiteBalanceTemperature() { return Reject<WhiteBalanceSettings>(); }
		public Future<FocusMode> SetFocusMode(FocusMode focusMode) { return Reject<FocusMode>(); }
		public Future<FocusMode> GetFocusMode() { return Reject<FocusMode>(); }
		public Future<MirrorMode> SetMirrorMode(MirrorMode mirrorMode) { return Reject<MirrorMode>(); }
		public Future<MirrorMode> GetMirrorMode() { return Reject<MirrorMode>(); }
		public Future<Nothing> StartFaceDetection(Action<DetectedFace[]> onFaces) { return Reject<Nothing>(); }
		public Future<bool> StopFaceDetection() { return Reject<bool>(); }
		public Future<Nothing> StartErrorMonitoring(Action<CameraEvent> onEvent) { return Reject<Nothing>(); }
		public Future<bool> StopErrorMonitoring() { return Reject<bool>(); }
		public Future<Nothing> StartBarcodeScanning(Action<Barcode> onDetected, string[] formats) { return Reject<Nothing>(); }
		public Future<bool> StopBarcodeScanning() { return Reject<bool>(); }
		public Future<Nothing> StartFrameAnalysis(FrameAnalysisOptions options, Action<FrameStatistics> onStats) { return Reject<Nothing>(); }
		public Future<bool> StopFrameAnalysis() { return Reject<bool>(); }
		public Future<OverlayOptions> SetOverlayOptions(OverlayOptions options) { return Reject<OverlayOptions>(); }
		Future<T> Reject<T>()
		{
			if defined(Android || iOS)
				return new Promise<T>().RejectWithMessage("Camera not loaded");
			else
				return new Promise<T>().RejectWithMessage("Platform not supported");
		}
	}
}
