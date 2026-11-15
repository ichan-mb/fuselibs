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

namespace Fuse.Controls.Android
{
	extern(!ANDROID) class CameraView
	{
		[UXConstructor]
		public CameraView([UXParameter("Host")]ICameraViewHost host) { }
	}

	extern(ANDROID) class CameraView : Fuse.Controls.Native.Android.View, ICameraView, ICamera
	{
		enum CaptureState
		{
			Idle,
			CapturingPhoto,
			CapturingVideo,
		}

		ICameraViewHost _host;

		[UXConstructor]
		public CameraView([UXParameter("Host")]ICameraViewHost host) : base(Create())
		{
			Fuse.Platform.Lifecycle.EnteringForeground += OnEnteringForeground;
			Fuse.Platform.Lifecycle.EnteringBackground += OnEnteringBackground;

			_host = host;
			_cameraFuture = new InitialLoadClosure(CameraFacing.Back);
			_cameraFuture.Then(OnCameraLoaded, OnCameraRejected);
		}

		bool _inForeground = true;
		void OnEnteringBackground(Fuse.Platform.ApplicationState s)
		{
			if (!_inForeground)
				return;
			_inForeground = false;
			CleanupCamera();
		}

		void OnEnteringForeground(Fuse.Platform.ApplicationState s)
		{
			if (_inForeground)
				return;
			_inForeground = true;
			if (!_isLoading)
			{
				if (_lastLensId != null)
					LoadCameraLens(_lastLensId);
				else
					LoadCamera(_lastCameraFacing);
			}
		}

		class InitialLoadClosure : CameraPromise<Camera>
		{
			CameraFacing _facing;

			public InitialLoadClosure(CameraFacing facing)
			{
				_facing = facing;

				Permissions.Request(Permissions.Android.CAMERA).Then(OnCameraPermissionGranted, Reject);
			}

			void OnStoragePermissionGranted(PlatformPermission permission) { }

			void OnStoragePermissionRejected(Exception e) { }

			void OnCameraPermissionGranted(PlatformPermission permission)
			{
				// Storage access is only needed to copy captures to the public gallery
				// on older Android versions. Do not let a denied storage permission
				// prevent the camera itself from loading.
				if (AndroidProperties.BuildVersion < 29)
					Permissions.Request(Permissions.Android.WRITE_EXTERNAL_STORAGE).Then(OnStoragePermissionGranted, OnStoragePermissionRejected);

				CameraLoader.Load(_facing).Then(Resolve, Reject);
			}
		}

		Future<Camera> _cameraFuture;
		bool _isLoading = true;
		CameraFacing _lastCameraFacing;
		string _lastLensId = null;
		void LoadCamera(CameraFacing facing)
		{
			_isLoading = true;
			try
			{
				if (_camera != null)
					CleanupCamera();

				_cameraFuture.Cancel();
				_lastCameraFacing = facing;
				_lastLensId = null;
				_cameraFuture = CameraLoader.Load(facing);
				_cameraFuture.Then(OnCameraLoaded, OnCameraRejected);
			}
			catch (Exception e)
			{
				_isLoading = false;
				throw e;
			}
		}

		void LoadCameraLens(string lensId)
		{
			_isLoading = true;
			try
			{
				if (_camera != null)
					CleanupCamera();

				_cameraFuture.Cancel();
				_lastLensId = lensId;
				_cameraFuture = CameraLoader.LoadLens(lensId);
				_cameraFuture.Then(OnCameraLoaded, OnCameraRejected);
			}
			catch (Exception e)
			{
				_isLoading = false;
				throw e;
			}
		}

		void OnCameraRejected(Exception e)
		{
			if (_isDisposed)
				return;
			_isLoading = false;
			_host.OnError(e);
		}

		Camera _camera;
		void OnCameraLoaded(Camera camera)
		{
			if (_isDisposed)
			{
				camera.Dispose();
				return;
			}
			_isLoading = false;
			_camera = camera;
			_lastCameraFacing = camera.Facing;
			InsertChild(_camera);
			_camera.PreviewStretchMode = _previewStretchMode;
			_host.OnCameraLoaded(this);
		}

		PreviewStretchMode _previewStretchMode;

		PreviewStretchMode ICameraView.PreviewStretchMode
		{
			set
			{
				_previewStretchMode = value;
				if (_camera != null)
					_camera.PreviewStretchMode = _previewStretchMode;
			}
		}

		CaptureState _captureState = CaptureState.Idle;
		CaptureMode _captureMode = CaptureMode.Photo;

		void ResetCaptureState() { _captureState = CaptureState.Idle; }

		Future<Photo> ICamera.CapturePhoto()
		{
			if (_camera == null)
				return Reject<Photo>("Camera busy or misconfigured");

			if (_captureState != CaptureState.Idle)
				return Reject<Photo>("Cannot capture photo while already capturing photo or video");

			if (_captureMode != CaptureMode.Photo)
				return Reject<Photo>("Cannot capture photo, CaptureMode not set to photo");

			_captureState = CaptureState.CapturingPhoto;

			return _camera.CapturePhoto().Intercept(ResetCaptureState);
		}

		Future<RecordingSession> ICamera.StartRecording()
		{
			if (_camera == null)
				return Reject<RecordingSession>("Camera busy or misconfigured");

			if (_captureState != CaptureState.Idle)
				return Reject<RecordingSession>("Cannot start recording while already capturing photo or video");

			if (_captureMode != CaptureMode.Video)
				return Reject<RecordingSession>("Cannot start recording, CaptureMode not set to video");

			if (!_recordAudioPermissionGranted && _camera.VideoAudioEnabled)
				return new StartRecordingWithPermissionClosure(this);

			return StartRecordingNow();
		}

		Future<RecordingSession> StartRecordingNow()
		{
			if (_camera == null)
				return Reject<RecordingSession>("Camera busy or misconfigured");

			if (_captureState != CaptureState.Idle)
				return Reject<RecordingSession>("Cannot start recording while already capturing photo or video");

			if (_captureMode != CaptureMode.Video)
				return Reject<RecordingSession>("Cannot start recording, CaptureMode not set to video");

			_captureState = CaptureState.CapturingVideo;

			return _camera.StartRecording(ResetCaptureState).InvokeOnRejected(ResetCaptureState);
		}

		bool _recordAudioPermissionGranted = false;

		class StartRecordingWithPermissionClosure : CameraPromise<RecordingSession>
		{
			CameraView _cameraView;

			public StartRecordingWithPermissionClosure(CameraView cameraView)
			{
				_cameraView = cameraView;
				Permissions.Request(Permissions.Android.RECORD_AUDIO).Then(OnPermissionGranted, OnPermissionRejected);
			}

			void OnPermissionGranted(PlatformPermission permission)
			{
				_cameraView._recordAudioPermissionGranted = true;
				_cameraView.StartRecordingNow().Then(Resolve, Reject);
			}

			void OnPermissionRejected(Exception e)
			{
				Reject(new Exception("Microphone permission is required to record video: " + e.Message));
			}
		}

		Future<CaptureMode> ICamera.SetCaptureMode(CaptureMode mode)
		{
			if (_captureState != CaptureState.Idle)
				return Reject<CaptureMode>("Cannot set CaptureMode while capturing photo or video");

			if (mode == CaptureMode.Video && !_recordAudioPermissionGranted && (_camera == null || _camera.VideoAudioEnabled))
				return new SetCaptureModeWithPermissionClosure(this, mode);

			_captureMode = mode;
			return new Promise<CaptureMode>(mode);
		}

		class SetCaptureModeWithPermissionClosure : CameraPromise<CaptureMode>
		{
			CameraView _cameraView;
			CaptureMode _mode;

			public SetCaptureModeWithPermissionClosure(CameraView cameraView, CaptureMode mode)
			{
				_cameraView = cameraView;
				_mode = mode;
				Permissions.Request(Permissions.Android.RECORD_AUDIO).Then(OnPermissionGranted, OnPermissionRejected);
			}

			void OnPermissionGranted(PlatformPermission permission)
			{
				if (_cameraView._captureState != CaptureState.Idle)
				{
					Reject(new Exception("Cannot set CaptureMode while capturing photo or video"));
					return;
				}

				_cameraView._recordAudioPermissionGranted = true;
				_cameraView._captureMode = _mode;
				Resolve(_mode);
			}

			void OnPermissionRejected(Exception e)
			{
				Reject(new Exception("Microphone permission is required to record video: " + e.Message));
			}
		}

		Future<PhotoOption[]> ICamera.SetPhotoOptions(PhotoOption[] options)
		{
			if (_camera == null)
				return Reject<PhotoOption[]>("Camera busy or misconfigured");

			if (_captureState != CaptureState.Idle)
				return Reject<PhotoOption[]>("Cannot set photo options while capturing photo or video");

			return _camera.SetPhotoOptions(options);
		}

		Future<CameraCapabilities> ICamera.GetCameraCapabilities()
		{
			if (_camera == null)
				return Reject<CameraCapabilities>("Camera busy or misconfigured");

			return _camera.GetCameraCapabilities();
		}

		Future<Nothing> ICamera.SetVideoOptions(VideoOptions options)
		{
			if (_camera == null)
				return Reject<Nothing>("Camera busy or misconfigured");

			if (_captureState != CaptureState.Idle)
				return Reject<Nothing>("Cannot set video options while capturing photo or video");

			return _camera.SetVideoOptions(options);
		}

		Future<float> ICamera.SetZoom(float zoom)
		{
			if (_camera == null)
				return Reject<float>("Camera busy or misconfigured");

			return _camera.SetZoom(zoom);
		}

		Future<float> ICamera.GetZoom()
		{
			if (_camera == null)
				return Reject<float>("Camera busy or misconfigured");

			return _camera.GetZoom();
		}

		Future<bool> ICamera.SetTorchMode(bool on)
		{
			if (_camera == null)
				return Reject<bool>("Camera busy or misconfigured");

			if (_captureState != CaptureState.Idle)
				return Reject<bool>("Cannot set TorchMode while capturing photo or video");

			return _camera.SetTorchMode(on);
		}

		Future<bool> ICamera.IsTorchOn()
		{
			if (_camera == null)
				return Reject<bool>("Camera busy or misconfigured");

			return _camera.IsTorchOn();
		}

		Future<float> ICamera.SetExposureCompensation(float value)
		{
			if (_camera == null)
				return Reject<float>("Camera busy or misconfigured");

			return _camera.SetExposureCompensation(value);
		}

		Future<float> ICamera.GetExposureCompensation()
		{
			if (_camera == null)
				return Reject<float>("Camera busy or misconfigured");

			return _camera.GetExposureCompensation();
		}

		Future<ManualExposureSettings> ICamera.SetManualExposure(float iso, float shutterSeconds)
		{
			if (_camera == null)
				return Reject<ManualExposureSettings>("Camera busy or misconfigured");

			return _camera.SetManualExposure(iso, shutterSeconds);
		}

		Future<ManualExposureSettings> ICamera.SetAutoExposure()
		{
			if (_camera == null)
				return Reject<ManualExposureSettings>("Camera busy or misconfigured");

			return _camera.SetAutoExposure();
		}

		Future<ManualExposureSettings> ICamera.GetManualExposure()
		{
			if (_camera == null)
				return Reject<ManualExposureSettings>("Camera busy or misconfigured");

			return _camera.GetManualExposure();
		}

		Future<Barcode> ICamera.ScanBarcode()
		{
			if (_camera == null)
				return Reject<Barcode>("Camera busy or misconfigured");

			return _camera.ScanBarcode();
		}

		Future<WhiteBalance> ICamera.SetWhiteBalance(WhiteBalance whiteBalance)
		{
			if (_camera == null)
				return Reject<WhiteBalance>("Camera busy or misconfigured");

			return _camera.SetWhiteBalance(whiteBalance);
		}

		Future<WhiteBalance> ICamera.GetWhiteBalance()
		{
			if (_camera == null)
				return Reject<WhiteBalance>("Camera busy or misconfigured");

			return _camera.GetWhiteBalance();
		}

		Future<WhiteBalanceSettings> ICamera.SetWhiteBalanceTemperature(float kelvin, float tint)
		{
			if (_camera == null)
				return Reject<WhiteBalanceSettings>("Camera busy or misconfigured");

			return _camera.SetWhiteBalanceTemperature(kelvin, tint);
		}

		Future<WhiteBalanceSettings> ICamera.GetWhiteBalanceTemperature()
		{
			if (_camera == null)
				return Reject<WhiteBalanceSettings>("Camera busy or misconfigured");

			return _camera.GetWhiteBalanceTemperature();
		}

		Future<FocusMode> ICamera.SetFocusMode(FocusMode focusMode)
		{
			if (_camera == null)
				return Reject<FocusMode>("Camera busy or misconfigured");

			return _camera.SetFocusMode(focusMode);
		}

		Future<FocusMode> ICamera.GetFocusMode()
		{
			if (_camera == null)
				return Reject<FocusMode>("Camera busy or misconfigured");

			return _camera.GetFocusMode();
		}

		Future<MirrorMode> ICamera.SetMirrorMode(MirrorMode mirrorMode)
		{
			if (_camera == null)
				return Reject<MirrorMode>("Camera busy or misconfigured");

			return _camera.SetMirrorMode(mirrorMode);
		}

		Future<MirrorMode> ICamera.GetMirrorMode()
		{
			if (_camera == null)
				return Reject<MirrorMode>("Camera busy or misconfigured");

			return _camera.GetMirrorMode();
		}

		Future<Nothing> ICamera.StartFaceDetection(Action<DetectedFace[]> onFaces)
		{
			if (_camera == null)
				return Reject<Nothing>("Camera busy or misconfigured");

			return _camera.StartFaceDetection(onFaces);
		}

		Future<bool> ICamera.StopFaceDetection()
		{
			if (_camera == null)
				return Reject<bool>("Camera busy or misconfigured");

			return _camera.StopFaceDetection();
		}

		Future<Nothing> ICamera.StartFrameAnalysis(FrameAnalysisOptions options, Action<FrameStatistics> onStats)
		{
			if (_camera == null)
				return Reject<Nothing>("Camera busy or misconfigured");

			return _camera.StartFrameAnalysis(options, onStats);
		}

		Future<bool> ICamera.StopFrameAnalysis()
		{
			if (_camera == null)
				return Reject<bool>("Camera busy or misconfigured");

			return _camera.StopFrameAnalysis();
		}

		Future<OverlayOptions> ICamera.SetOverlayOptions(OverlayOptions options)
		{
			if (_camera == null)
				return Reject<OverlayOptions>("Camera busy or misconfigured");

			return _camera.SetOverlayOptions(options);
		}

		Future<Nothing> ICamera.StartErrorMonitoring(Action<CameraEvent> onEvent)
		{
			if (_camera == null)
				return Reject<Nothing>("Camera busy or misconfigured");

			return _camera.StartErrorMonitoring(onEvent);
		}

		Future<bool> ICamera.StopErrorMonitoring()
		{
			if (_camera == null)
				return Reject<bool>("Camera busy or misconfigured");

			return _camera.StopErrorMonitoring();
		}

		Future<Barcode> ICamera.ScanBarcode(string[] formats)
		{
			if (_camera == null)
				return Reject<Barcode>("Camera busy or misconfigured");

			return _camera.ScanBarcode(formats);
		}

		Future<Nothing> ICamera.StartBarcodeScanning(Action<Barcode> onDetected, string[] formats)
		{
			if (_camera == null)
				return Reject<Nothing>("Camera busy or misconfigured");

			return _camera.StartBarcodeScanning(onDetected, formats);
		}

		Future<bool> ICamera.StopBarcodeScanning()
		{
			if (_camera == null)
				return Reject<bool>("Camera busy or misconfigured");

			return _camera.StopBarcodeScanning();
		}

		Future<CameraLens[]> ICamera.GetAvailableLenses()
		{
			return new Promise<CameraLens[]>(CameraLoader.GetAvailableLenses());
		}

		class SetCameraLensClosure : CameraPromise<string>
		{
			string _lensId;

			public SetCameraLensClosure(string lensId)
			{
				_lensId = lensId;
			}

			public void OnResolve(Camera camera)
			{
				if (camera.LensId == _lensId)
					Resolve(_lensId);
				else
					Reject(new Exception("Failed to set camera lens"));
			}

			public void OnReject(Exception e) { Reject(new Exception("Failed to set camera lens: " + e.Message)); }
		}

		Future<string> ICamera.SetCameraLens(string lensId)
		{
			if (_captureState != CaptureState.Idle)
				return Reject<string>("Cannot set CameraLens while capturing photo or video");

			if (_cameraFuture.State != FutureState.Resolved)
				return Reject<string>("Camera busy or misconfigured");

			if (_camera != null && _camera.LensId == lensId)
				return new Promise<string>(lensId);

			var p = new SetCameraLensClosure(lensId);
			LoadCameraLens(lensId);
			_cameraFuture.Then(p.OnResolve, p.OnReject);
			return p;
		}

		class SetCameraFacingClosure : CameraPromise<CameraFacing>
		{
			CameraFacing _cameraFacing;

			public SetCameraFacingClosure(CameraFacing cameraFacing)
			{
				_cameraFacing = cameraFacing;
			}

			public void OnResolve(Camera camera)
			{
				if (camera.Facing == _cameraFacing)
					Resolve(_cameraFacing);
				else
					Reject(new Exception("Failed to set CameraFacing"));
			}

			public void OnReject(Exception e) { Reject(new Exception("Failed to set CameraFacing: " + e.Message)); }
		}

		Future<CameraFacing> ICamera.SetCameraFacing(CameraFacing facing)
		{
			if (_captureState != CaptureState.Idle)
				return Reject<CameraFacing>("Cannot set CameraFacing while capturing photo or video");

			if (_cameraFuture.State != FutureState.Resolved)
				return Reject<CameraFacing>("Camera busy or misconfigured");

			if (_camera != null && _camera.Facing == facing)
				return new Promise<CameraFacing>(facing);

			var p = new SetCameraFacingClosure(facing);
			LoadCamera(facing);
			_cameraFuture.Then(p.OnResolve, p.OnReject);
			return p;
		}

		Future<Nothing> ICamera.SetCameraFocusPoint(double x, double y, int cameraWidth, int cameraHeight, int isFocusLocked)
		{
			if (_camera == null)
				return Reject<Nothing>("Camera busy or misconfigured");

			if (_captureState != CaptureState.Idle)
				return Reject<Nothing>("Cannot set photo options while capturing photo or video");

			return _camera.SetCameraFocusPoint(x, y, cameraWidth, cameraHeight, isFocusLocked);
		}

		Future<FlashMode> ICamera.SetFlashMode(FlashMode mode)
		{
			if (_camera == null)
				return Reject<FlashMode>("Camera busy or misconfigured");

			if (_captureState != CaptureState.Idle)
				return Reject<FlashMode>("Cannot set FlashMode while capturing photo or video");

			if (!mode.IsSupported(_camera))
				return Reject<FlashMode>("FlashMode." + mode + " not supported for CameraFacing." + _camera.Facing);

			return new Promise<FlashMode>(_camera.FlashMode = mode);
		}

		class GetCameraInfoClosure : Promise<CameraInfo>
		{
			CameraView _cameraView;

			public GetCameraInfoClosure(CameraView cameraView)
			{
				_cameraView = cameraView;
				_cameraView._cameraFuture.Then(OnResolve, OnReject);
			}

			void OnResolve(Camera camera) { Resolve(new CameraInfo(camera.FlashMode, camera.Facing, _cameraView._captureMode, camera.PictureSizes, camera.SupportedFlashModes, camera.GetZoomNow(), camera.IsTorchOnNow(), camera.GetExposureCompensationNow(), camera.LensId, camera.GetWhiteBalanceNow(), camera.GetFocusModeNow(), camera.GetMirrorModeNow())); }
			void OnReject(Exception e) { Reject(new Exception("Failed to get camera info: " + e.Message, e)); }
		}

		Future<CameraInfo> ICamera.GetCameraInfo()
		{
			return new GetCameraInfoClosure(this);
		}

		Future<T> Reject<T>(string message)
		{
			var p = new Promise<T>();
			p.Reject(new Exception(message));
			return p;
		}

		void CleanupCamera()
		{
			if (_camera != null)
			{
				RemoveChild(_camera);
				_camera.Dispose();
				_camera = null;
			}
		}

		bool _isDisposed = false;
		public override void Dispose()
		{
			Fuse.Platform.Lifecycle.EnteringForeground -= OnEnteringForeground;
			Fuse.Platform.Lifecycle.EnteringBackground -= OnEnteringBackground;
			CleanupCamera();
			base.Dispose();
			_host = null;
			_isDisposed = true;
		}

		[Foreign(Language.Java)]
		static Java.Object Create()
		@{
			android.widget.FrameLayout frameLayout = new android.widget.FrameLayout(com.fuse.Activity.getRootActivity());
			frameLayout.setLayoutParams(new android.widget.FrameLayout.LayoutParams(android.view.ViewGroup.LayoutParams.MATCH_PARENT, android.view.ViewGroup.LayoutParams.MATCH_PARENT));
			return frameLayout;
		@}
	}
}
