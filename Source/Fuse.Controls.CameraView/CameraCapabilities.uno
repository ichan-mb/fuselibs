using Uno;

namespace Fuse.Controls
{
	/**
		Static capabilities of the currently loaded camera.

		Use `CameraView.getCameraCapabilities()` to query these values. They
		describe what the camera can do, not its current state.
	*/
	public class CameraCapabilities
	{
		public const string ZoomSupportedName = "zoomSupported";
		public const string MinZoomName = "minZoom";
		public const string MaxZoomName = "maxZoom";
		public const string TorchSupportedName = "torchSupported";
		public const string PhotoResolutionsName = "photoResolutions";
		public const string SupportedFlashModesName = "supportedFlashModes";
		public const string SupportedFacingsName = "supportedFacings";
		public const string MinExposureCompensationName = "minExposureCompensation";
		public const string MaxExposureCompensationName = "maxExposureCompensation";
		public const string ExposureCompensationStepName = "exposureCompensationStep";
		public const string ManualExposureSupportedName = "manualExposureSupported";
		public const string MinIsoName = "minIso";
		public const string MaxIsoName = "maxIso";
		public const string MinShutterSecondsName = "minShutterSeconds";
		public const string MaxShutterSecondsName = "maxShutterSeconds";
		public const string WhiteBalanceModesName = "whiteBalanceModes";
		public const string ManualWhiteBalanceSupportedName = "manualWhiteBalanceSupported";
		public const string FocusModesName = "focusModes";
		public const string MirrorModesName = "mirrorModes";

		public readonly bool ZoomSupported;
		public readonly float MinZoom;
		public readonly float MaxZoom;
		public readonly bool TorchSupported;
		public readonly int2[] PhotoResolutions;
		public readonly FlashMode[] SupportedFlashModes;
		public readonly CameraFacing[] SupportedFacings;
		public readonly float MinExposureCompensation;
		public readonly float MaxExposureCompensation;
		public readonly float ExposureCompensationStep;
		public readonly bool ManualExposureSupported;
		public readonly float MinIso;
		public readonly float MaxIso;
		public readonly float MinShutterSeconds;
		public readonly float MaxShutterSeconds;
		public readonly WhiteBalance[] WhiteBalanceModes;
		public readonly bool ManualWhiteBalanceSupported;
		public readonly FocusMode[] FocusModes;
		public readonly MirrorMode[] MirrorModes = MirrorModeHelpers.All;

		public CameraCapabilities(
			bool zoomSupported,
			float minZoom,
			float maxZoom,
			bool torchSupported,
			int2[] photoResolutions,
			FlashMode[] supportedFlashModes,
			CameraFacing[] supportedFacings,
			float minExposureCompensation,
			float maxExposureCompensation,
			float exposureCompensationStep,
			bool manualExposureSupported,
			float minIso,
			float maxIso,
			float minShutterSeconds,
			float maxShutterSeconds)
			: this(zoomSupported, minZoom, maxZoom, torchSupported, photoResolutions, supportedFlashModes, supportedFacings, minExposureCompensation, maxExposureCompensation, exposureCompensationStep, manualExposureSupported, minIso, maxIso, minShutterSeconds, maxShutterSeconds, WhiteBalanceHelpers.All, false, FocusModeHelpers.All)
		{
		}

		public CameraCapabilities(
			bool zoomSupported,
			float minZoom,
			float maxZoom,
			bool torchSupported,
			int2[] photoResolutions,
			FlashMode[] supportedFlashModes,
			CameraFacing[] supportedFacings,
			float minExposureCompensation,
			float maxExposureCompensation,
			float exposureCompensationStep,
			bool manualExposureSupported,
			float minIso,
			float maxIso,
			float minShutterSeconds,
			float maxShutterSeconds,
			WhiteBalance[] whiteBalanceModes)
			: this(zoomSupported, minZoom, maxZoom, torchSupported, photoResolutions, supportedFlashModes, supportedFacings, minExposureCompensation, maxExposureCompensation, exposureCompensationStep, manualExposureSupported, minIso, maxIso, minShutterSeconds, maxShutterSeconds, whiteBalanceModes, false, FocusModeHelpers.All)
		{
		}

		public CameraCapabilities(
			bool zoomSupported,
			float minZoom,
			float maxZoom,
			bool torchSupported,
			int2[] photoResolutions,
			FlashMode[] supportedFlashModes,
			CameraFacing[] supportedFacings,
			float minExposureCompensation,
			float maxExposureCompensation,
			float exposureCompensationStep,
			bool manualExposureSupported,
			float minIso,
			float maxIso,
			float minShutterSeconds,
			float maxShutterSeconds,
			WhiteBalance[] whiteBalanceModes,
			bool manualWhiteBalanceSupported)
			: this(zoomSupported, minZoom, maxZoom, torchSupported, photoResolutions, supportedFlashModes, supportedFacings, minExposureCompensation, maxExposureCompensation, exposureCompensationStep, manualExposureSupported, minIso, maxIso, minShutterSeconds, maxShutterSeconds, whiteBalanceModes, manualWhiteBalanceSupported, FocusModeHelpers.All)
		{
		}

		public CameraCapabilities(
			bool zoomSupported,
			float minZoom,
			float maxZoom,
			bool torchSupported,
			int2[] photoResolutions,
			FlashMode[] supportedFlashModes,
			CameraFacing[] supportedFacings,
			float minExposureCompensation,
			float maxExposureCompensation,
			float exposureCompensationStep,
			bool manualExposureSupported,
			float minIso,
			float maxIso,
			float minShutterSeconds,
			float maxShutterSeconds,
			WhiteBalance[] whiteBalanceModes,
			bool manualWhiteBalanceSupported,
			FocusMode[] focusModes)
		{
			ZoomSupported = zoomSupported;
			MinZoom = minZoom;
			MaxZoom = maxZoom;
			TorchSupported = torchSupported;
			PhotoResolutions = photoResolutions;
			SupportedFlashModes = supportedFlashModes;
			SupportedFacings = supportedFacings;
			MinExposureCompensation = minExposureCompensation;
			MaxExposureCompensation = maxExposureCompensation;
			ExposureCompensationStep = exposureCompensationStep;
			ManualExposureSupported = manualExposureSupported;
			MinIso = minIso;
			MaxIso = maxIso;
			MinShutterSeconds = minShutterSeconds;
			MaxShutterSeconds = maxShutterSeconds;
			WhiteBalanceModes = whiteBalanceModes;
			ManualWhiteBalanceSupported = manualWhiteBalanceSupported;
			FocusModes = focusModes;
		}
	}
}
