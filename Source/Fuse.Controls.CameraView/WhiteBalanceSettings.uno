using Uno;

namespace Fuse.Controls
{
	/**
		Current manual white balance state.
	*/
	public class WhiteBalanceSettings
	{
		public const string IsManualName = "isManual";
		public const string KelvinName = "kelvin";
		public const string TintName = "tint";

		public readonly bool IsManual;
		public readonly float Kelvin;
		public readonly float Tint;

		public WhiteBalanceSettings(bool isManual, float kelvin, float tint)
		{
			IsManual = isManual;
			Kelvin = kelvin;
			Tint = tint;
		}
	}
}
