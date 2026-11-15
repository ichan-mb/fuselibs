using Uno;
using Fuse;
using Fuse.Scripting;

namespace Fuse.Controls
{
	/**
		Options used when recording video.

		The requested resolution is treated as a hint. The platform picks the
		closest supported recording profile. `frameRate` and `bitRate` are
		honored where the platform supports overriding them.
	*/
	public class VideoOptions
	{
		public const string ResolutionName = "resolution";
		public const string FrameRateName = "frameRate";
		public const string BitRateName = "bitRate";
		public const string AudioEnabledName = "audioEnabled";
		public const string StabilizationEnabledName = "stabilizationEnabled";

		public readonly int2 Resolution;
		public readonly int FrameRate;
		public readonly int BitRate;
		public readonly bool AudioEnabled;
		public readonly bool StabilizationEnabled;

		public VideoOptions(int2 resolution, int frameRate, int bitRate, bool audioEnabled, bool stabilizationEnabled)
		{
			Resolution = resolution;
			FrameRate = frameRate;
			BitRate = bitRate;
			AudioEnabled = audioEnabled;
			StabilizationEnabled = stabilizationEnabled;
		}

		internal static VideoOptions From(Fuse.Scripting.Object obj)
		{
			var resolution = int2(0);
			if (obj.ContainsKey(ResolutionName))
			{
				var resolutionObject = obj[ResolutionName] as Fuse.Scripting.Object;
				if (resolutionObject == null ||
					!resolutionObject.ContainsKey("width") ||
					!resolutionObject.ContainsKey("height"))
					throw new Exception("VideoOptions: resolution must contain width and height");

				resolution = int2(
					(int)Value.ToNumber(resolutionObject["width"]),
					(int)Value.ToNumber(resolutionObject["height"]));
			}

			var frameRate = obj.ContainsKey(FrameRateName) ? (int)Value.ToNumber(obj[FrameRateName]) : 0;
			var bitRate = obj.ContainsKey(BitRateName) ? (int)Value.ToNumber(obj[BitRateName]) : 0;
			var audioEnabled = !obj.ContainsKey(AudioEnabledName) || Marshal.ToBool(obj[AudioEnabledName]);
			var stabilizationEnabled = !obj.ContainsKey(StabilizationEnabledName) || Marshal.ToBool(obj[StabilizationEnabledName]);

			return new VideoOptions(resolution, frameRate, bitRate, audioEnabled, stabilizationEnabled);
		}
	}
}
