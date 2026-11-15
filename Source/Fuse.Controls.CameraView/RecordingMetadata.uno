using Uno;

namespace Fuse.Controls
{
	/**
		Metadata for a finished video recording.
	*/
	public class RecordingMetadata
	{
		public const string WidthName = "width";
		public const string HeightName = "height";
		public const string DurationName = "duration";
		public const string FileSizeName = "fileSize";

		/** Displayed width in pixels. */
		public readonly int Width;
		/** Displayed height in pixels. */
		public readonly int Height;
		/** Duration in milliseconds. */
		public readonly int Duration;
		/** Size of the video file in bytes. */
		public readonly double FileSize;

		public RecordingMetadata(int width, int height, int duration, double fileSize)
		{
			Width = width;
			Height = height;
			Duration = duration;
			FileSize = fileSize;
		}
	}
}
