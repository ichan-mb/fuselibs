using Uno;

namespace Fuse.Controls
{
	/**
		Focus modes supported by the camera.
	*/
	public enum FocusMode
	{
		/** Focus once when the scene changes. */
		Auto,
		/** Keep adjusting the focus continuously. */
		Continuous,
		/** Keep the focus where it currently is. */
		Locked,
	}

	internal static class FocusModeHelpers
	{
		public static string AsString(this FocusMode focusMode)
		{
			switch (focusMode)
			{
				case FocusMode.Auto: return "auto";
				case FocusMode.Continuous: return "continuous";
				case FocusMode.Locked: return "locked";
				default: return "continuous";
			}
		}

		public static FocusMode Parse(string value)
		{
			FocusMode result;
			return TryParse(value, out result) ? result : FocusMode.Continuous;
		}

		public static bool TryParse(string value, out FocusMode result)
		{
			var name = value == null ? "" : value.ToLower();

			if (name == "auto") { result = FocusMode.Auto; return true; }
			if (name == "continuous") { result = FocusMode.Continuous; return true; }
			if (name == "locked") { result = FocusMode.Locked; return true; }

			result = FocusMode.Continuous;
			return false;
		}

		/** All focus modes, in the order they are reported to the user. */
		public static readonly FocusMode[] All = new FocusMode[]
		{
			FocusMode.Auto,
			FocusMode.Continuous,
			FocusMode.Locked,
		};
	}
}
