using Uno;

namespace Fuse.Controls
{
	/**
		Controls how the camera preview and captured media are mirrored.
	*/
	public enum MirrorMode
	{
		/**
			Mirror the preview for the front facing camera only. Captured photos and
			videos are not mirrored. This is the platform default.
		*/
		Auto,
		/** Mirror both the preview and captured photos and videos. */
		On,
		/** Never mirror the preview or captured media. */
		Off,
	}

	internal static class MirrorModeHelpers
	{
		public static string AsString(this MirrorMode mirrorMode)
		{
			switch (mirrorMode)
			{
				case MirrorMode.Auto: return "auto";
				case MirrorMode.On: return "on";
				case MirrorMode.Off: return "off";
				default: return "auto";
			}
		}

		public static MirrorMode Parse(string value)
		{
			MirrorMode result;
			return TryParse(value, out result) ? result : MirrorMode.Auto;
		}

		/** All mirror modes, in the order they are reported to the user. */
		public static readonly MirrorMode[] All = new MirrorMode[]
		{
			MirrorMode.Auto,
			MirrorMode.On,
			MirrorMode.Off,
		};

		public static bool TryParse(string value, out MirrorMode result)
		{
			var name = value == null ? "" : value.ToLower();

			if (name == "auto") { result = MirrorMode.Auto; return true; }
			if (name == "on") { result = MirrorMode.On; return true; }
			if (name == "off") { result = MirrorMode.Off; return true; }

			result = MirrorMode.Auto;
			return false;
		}
	}
}
