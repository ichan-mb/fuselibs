using Fuse.Scripting;

namespace Fuse.Controls
{
	public class CameraInfo
	{
		public const string FlashModeName = "flashMode";
		public const string CameraFacingName = "cameraFacing";
		public const string CaptureModeName = "captureMode";
		public const string PhotoResolutionsName = "photoResolutions";
		public const string SupportedFlashModesName = "supportedFlashModes";
		public const string ZoomName = "zoom";
		public const string TorchOnName = "torchOn";
		public const string ExposureCompensationName = "exposureCompensation";
		public const string LensIdName = "lensId";
		public const string WhiteBalanceName = "whiteBalance";
		public const string FocusModeName = "focusMode";
		public const string MirrorModeName = "mirrorMode";

		public readonly FlashMode FlashMode;
		public readonly CameraFacing CameraFacing;
		public readonly CaptureMode CaptureMode;
		public readonly int2[] PhotoResolutions;
		public readonly FlashMode[] SupportedFlashModes;
		public readonly float Zoom;
		public readonly bool TorchOn;
		public readonly float ExposureCompensation;
		public readonly string LensId;
		public readonly WhiteBalance WhiteBalance;
		public readonly FocusMode FocusMode;
		public readonly MirrorMode MirrorMode;

		public CameraInfo(
			FlashMode flashMode,
			CameraFacing cameraFacing,
			CaptureMode captureMode,
			int2[] photoResolutions,
			FlashMode[] supportedFlashModes)
			: this(flashMode, cameraFacing, captureMode, photoResolutions, supportedFlashModes, 1.0f, false, 0.0f, "")
		{
		}

		public CameraInfo(
			FlashMode flashMode,
			CameraFacing cameraFacing,
			CaptureMode captureMode,
			int2[] photoResolutions,
			FlashMode[] supportedFlashModes,
			float zoom,
			bool torchOn)
			: this(flashMode, cameraFacing, captureMode, photoResolutions, supportedFlashModes, zoom, torchOn, 0.0f, "")
		{
		}

		public CameraInfo(
			FlashMode flashMode,
			CameraFacing cameraFacing,
			CaptureMode captureMode,
			int2[] photoResolutions,
			FlashMode[] supportedFlashModes,
			float zoom,
			bool torchOn,
			float exposureCompensation)
			: this(flashMode, cameraFacing, captureMode, photoResolutions, supportedFlashModes, zoom, torchOn, exposureCompensation, "")
		{
		}

		public CameraInfo(
			FlashMode flashMode,
			CameraFacing cameraFacing,
			CaptureMode captureMode,
			int2[] photoResolutions,
			FlashMode[] supportedFlashModes,
			float zoom,
			bool torchOn,
			float exposureCompensation,
			string lensId)
			: this(flashMode, cameraFacing, captureMode, photoResolutions, supportedFlashModes, zoom, torchOn, exposureCompensation, lensId, WhiteBalance.Auto)
		{
		}

		public CameraInfo(
			FlashMode flashMode,
			CameraFacing cameraFacing,
			CaptureMode captureMode,
			int2[] photoResolutions,
			FlashMode[] supportedFlashModes,
			float zoom,
			bool torchOn,
			float exposureCompensation,
			string lensId,
			WhiteBalance whiteBalance)
			: this(flashMode, cameraFacing, captureMode, photoResolutions, supportedFlashModes, zoom, torchOn, exposureCompensation, lensId, whiteBalance, FocusMode.Continuous)
		{
		}

		public CameraInfo(
			FlashMode flashMode,
			CameraFacing cameraFacing,
			CaptureMode captureMode,
			int2[] photoResolutions,
			FlashMode[] supportedFlashModes,
			float zoom,
			bool torchOn,
			float exposureCompensation,
			string lensId,
			WhiteBalance whiteBalance,
			FocusMode focusMode)
			: this(flashMode, cameraFacing, captureMode, photoResolutions, supportedFlashModes, zoom, torchOn, exposureCompensation, lensId, whiteBalance, focusMode, MirrorMode.Auto)
		{
		}

		public CameraInfo(
			FlashMode flashMode,
			CameraFacing cameraFacing,
			CaptureMode captureMode,
			int2[] photoResolutions,
			FlashMode[] supportedFlashModes,
			float zoom,
			bool torchOn,
			float exposureCompensation,
			string lensId,
			WhiteBalance whiteBalance,
			FocusMode focusMode,
			MirrorMode mirrorMode)
		{
			FlashMode = flashMode;
			CameraFacing = cameraFacing;
			CaptureMode = captureMode;
			PhotoResolutions = photoResolutions;
			SupportedFlashModes = supportedFlashModes;
			Zoom = zoom;
			TorchOn = torchOn;
			ExposureCompensation = exposureCompensation;
			LensId = lensId;
			WhiteBalance = whiteBalance;
			FocusMode = focusMode;
			MirrorMode = mirrorMode;
		}
	}
}
