using Uno;
using Fuse;
using Fuse.Scripting;

namespace Fuse.Controls
{
	/**
		Options used when analysing camera frames.

		`maxFps` limits how often the statistics callback is called. The camera
		keeps analysing at its own rate, so a lower value only reduces the work
		done to deliver statistics.

		`resolution` is the resolution requested for the frame analysis stream. It
		applies when analysis starts and is treated as a hint, like the video
		resolution. Higher values cost more power and can limit the other camera
		streams, so the default is 640x480.

		`lumaWidth` and `lumaHeight` request a downscaled luminance image next to
		the statistics. Leave them at zero to avoid transferring any pixels.
	*/
	public class FrameAnalysisOptions
	{
		public const string MaxFpsName = "maxFps";
		public const string ResolutionName = "resolution";
		public const string LumaWidthName = "lumaWidth";
		public const string LumaHeightName = "lumaHeight";

		public const int DefaultMaxFps = 15;
		public const int DefaultResolutionWidth = 640;
		public const int DefaultResolutionHeight = 480;
		public const int MaxLumaSize = 1024;

		public readonly int MaxFps;
		public readonly int2 Resolution;
		public readonly int LumaWidth;
		public readonly int LumaHeight;

		public FrameAnalysisOptions(int maxFps, int2 resolution, int lumaWidth, int lumaHeight)
		{
			MaxFps = maxFps > 0 ? maxFps : DefaultMaxFps;

			Resolution = int2(
				resolution.X > 0 ? resolution.X : DefaultResolutionWidth,
				resolution.Y > 0 ? resolution.Y : DefaultResolutionHeight);

			LumaWidth = Clamp(lumaWidth, 0, MaxLumaSize);
			LumaHeight = Clamp(lumaHeight, 0, MaxLumaSize);

			if (LumaWidth > 0 && LumaHeight == 0)
				LumaHeight = Clamp(LumaWidth * 3 / 4, 1, MaxLumaSize);
		}

		public static FrameAnalysisOptions Default
		{
			get { return new FrameAnalysisOptions(DefaultMaxFps, int2(DefaultResolutionWidth, DefaultResolutionHeight), 0, 0); }
		}

		static int Clamp(int value, int min, int max)
		{
			return value < min ? min : (value > max ? max : value);
		}

		internal static FrameAnalysisOptions From(Fuse.Scripting.Object obj)
		{
			var maxFps = obj.ContainsKey(MaxFpsName) ? (int)Value.ToNumber(obj[MaxFpsName]) : DefaultMaxFps;

			var resolution = int2(0);
			if (obj.ContainsKey(ResolutionName))
			{
				var resolutionObject = obj[ResolutionName] as Fuse.Scripting.Object;
				if (resolutionObject == null ||
					!resolutionObject.ContainsKey("width") ||
					!resolutionObject.ContainsKey("height"))
					throw new Exception("FrameAnalysisOptions: resolution must contain width and height");

				resolution = int2(
					(int)Value.ToNumber(resolutionObject["width"]),
					(int)Value.ToNumber(resolutionObject["height"]));
			}

			var lumaWidth = obj.ContainsKey(LumaWidthName) ? (int)Value.ToNumber(obj[LumaWidthName]) : 0;
			var lumaHeight = obj.ContainsKey(LumaHeightName) ? (int)Value.ToNumber(obj[LumaHeightName]) : 0;

			return new FrameAnalysisOptions(maxFps, resolution, lumaWidth, lumaHeight);
		}
	}
}
