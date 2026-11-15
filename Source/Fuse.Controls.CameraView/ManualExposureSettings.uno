using Uno;

namespace Fuse.Controls
{
	/**
		Current manual exposure state.
	*/
	public class ManualExposureSettings
	{
		public const string IsManualName = "isManual";
		public const string IsoName = "iso";
		public const string ShutterSecondsName = "shutterSeconds";

		public readonly bool IsManual;
		public readonly float Iso;
		public readonly float ShutterSeconds;

		public ManualExposureSettings(bool isManual, float iso, float shutterSeconds)
		{
			IsManual = isManual;
			Iso = iso;
			ShutterSeconds = shutterSeconds;
		}
	}
}
