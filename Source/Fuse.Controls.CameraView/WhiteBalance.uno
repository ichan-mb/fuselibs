using Uno;

namespace Fuse.Controls
{
	/**
		White balance modes supported by the camera.
	*/
	public enum WhiteBalance
	{
		/** Let the camera adjust the white balance to the scene. */
		Auto,
		/** Incandescent / tungsten lighting. */
		Incandescent,
		/** Fluorescent lighting. */
		Fluorescent,
		/** Warm fluorescent lighting. */
		WarmFluorescent,
		/** Direct sunlight. */
		Daylight,
		/** Overcast sky. */
		Cloudy,
		/** Twilight / low light. */
		Twilight,
		/** Deep shade. */
		Shade,
		/** Fixed temperature and tint, set with `setWhiteBalanceTemperature()`. */
		Manual,
	}

	internal static class WhiteBalanceHelpers
	{
		public static string AsString(this WhiteBalance whiteBalance)
		{
			switch (whiteBalance)
			{
				case WhiteBalance.Auto: return "auto";
				case WhiteBalance.Incandescent: return "incandescent";
				case WhiteBalance.Fluorescent: return "fluorescent";
				case WhiteBalance.WarmFluorescent: return "warm-fluorescent";
				case WhiteBalance.Daylight: return "daylight";
				case WhiteBalance.Cloudy: return "cloudy";
				case WhiteBalance.Twilight: return "twilight";
				case WhiteBalance.Shade: return "shade";
				case WhiteBalance.Manual: return "manual";
				default: return "auto";
			}
		}

		public static WhiteBalance Parse(string value)
		{
			WhiteBalance result;
			return TryParse(value, out result) ? result : WhiteBalance.Auto;
		}

		public static bool TryParse(string value, out WhiteBalance result)
		{
			var name = value == null ? "" : value.ToLower();

			if (name == "auto") { result = WhiteBalance.Auto; return true; }
			if (name == "incandescent") { result = WhiteBalance.Incandescent; return true; }
			if (name == "fluorescent") { result = WhiteBalance.Fluorescent; return true; }
			if (name == "warm-fluorescent" || name == "warmfluorescent") { result = WhiteBalance.WarmFluorescent; return true; }
			if (name == "daylight") { result = WhiteBalance.Daylight; return true; }
			if (name == "cloudy") { result = WhiteBalance.Cloudy; return true; }
			if (name == "twilight") { result = WhiteBalance.Twilight; return true; }
			if (name == "shade") { result = WhiteBalance.Shade; return true; }
			if (name == "manual") { result = WhiteBalance.Manual; return true; }

			result = WhiteBalance.Auto;
			return false;
		}

		/** All white balance modes, in the order they are reported to the user. */
		public static readonly WhiteBalance[] All = new WhiteBalance[]
		{
			WhiteBalance.Auto,
			WhiteBalance.Incandescent,
			WhiteBalance.Fluorescent,
			WhiteBalance.WarmFluorescent,
			WhiteBalance.Daylight,
			WhiteBalance.Cloudy,
			WhiteBalance.Twilight,
			WhiteBalance.Shade,
		};
	}
}
