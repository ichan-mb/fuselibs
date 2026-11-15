using Uno;

namespace Fuse.Controls
{
	/**
		Statistics for one analysed camera frame.

		All values except `timestamp` and `analysisTime` are normalized to 0..1.
		`timestamp` is a monotonic clock in milliseconds and `analysisTime` is how
		long the frame took to analyse, which is useful when tuning `resolution`
		and `maxFps`.

		The luminance values assume sRGB luma weights, which matches how the
		platforms report Y from their YUV streams.
	*/
	public class FrameStatistics
	{
		public const string TimestampName = "timestamp";
		public const string MeanName = "mean";
		public const string P1Name = "p1";
		public const string P50Name = "p50";
		public const string P99Name = "p99";
		public const string ClippedLowName = "clippedLow";
		public const string ClippedHighName = "clippedHigh";
		public const string HistogramName = "histogram";
		public const string LumaName = "luma";
		public const string LumaWidthName = "lumaWidth";
		public const string LumaHeightName = "lumaHeight";
		public const string AnalysisTimeName = "analysisTime";

		/** Number of bins in the luminance histogram. */
		public const int HistogramBins = 64;

		public readonly double Timestamp;
		public readonly double Mean;

		/** Luminance percentiles: 1%, 50% and 99%. */
		public readonly double P1;
		public readonly double P50;
		public readonly double P99;

		/** Fraction of pixels below 2% and above 98% luminance. */
		public readonly double ClippedLow;
		public readonly double ClippedHigh;

		/** Luminance histogram, each bin normalized to 0..1 of the pixels. */
		public readonly double[] Histogram;

		/** Downscaled luminance image, or null when it was not requested. */
		public readonly byte[] Luma;
		public readonly int LumaWidth;
		public readonly int LumaHeight;

		public readonly double AnalysisTime;

		internal static double[] HistogramFrom(byte[] bytes)
		{
			if (bytes == null)
				return null;

			var bins = new double[bytes.Length];
			for (var i = 0; i < bins.Length; i++)
				bins[i] = bytes[i] / 255.0;

			return bins;
		}

		public FrameStatistics(double timestamp, double mean, double p1, double p50, double p99,
			double clippedLow, double clippedHigh, double[] histogram, byte[] luma,
			int lumaWidth, int lumaHeight, double analysisTime)
		{
			Timestamp = timestamp;
			Mean = mean;
			P1 = p1;
			P50 = p50;
			P99 = p99;
			ClippedLow = clippedLow;
			ClippedHigh = clippedHigh;
			Histogram = histogram;
			Luma = luma;
			LumaWidth = lumaWidth;
			LumaHeight = lumaHeight;
			AnalysisTime = analysisTime;
		}
	}
}
