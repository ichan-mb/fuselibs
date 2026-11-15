using Uno;
using Fuse;
using Fuse.Scripting;

namespace Fuse.Controls
{
	/**
		Options for the analysis overlay drawn on top of the preview.

		`zebra` marks pixels at or above the given luminance with diagonal stripes,
		which is how overexposed areas are usually shown. `peaking` highlights
		edges, where a higher value detects weaker edges.

		Both are normalized to 0..1 and both default to 0, which turns that part of
		the overlay off. The overlay is drawn natively from the same frames the
		statistics use, so it costs nothing in JavaScript.
	*/
	public class OverlayOptions
	{
		public const string ZebraName = "zebra";
		public const string PeakingName = "peaking";

		public readonly double Zebra;
		public readonly double Peaking;

		public OverlayOptions(double zebra, double peaking)
		{
			Zebra = Clamp01(zebra);
			Peaking = Clamp01(peaking);
		}

		public static OverlayOptions None
		{
			get { return new OverlayOptions(0, 0); }
		}

		public bool IsEmpty
		{
			get { return Zebra <= 0 && Peaking <= 0; }
		}

		static double Clamp01(double value)
		{
			return value < 0 ? 0.0 : (value > 1 ? 1.0 : value);
		}

		internal static OverlayOptions From(Fuse.Scripting.Object obj)
		{
			var zebra = obj.ContainsKey(ZebraName) ? Value.ToNumber(obj[ZebraName]) : 0.0;
			var peaking = obj.ContainsKey(PeakingName) ? Value.ToNumber(obj[PeakingName]) : 0.0;
			return new OverlayOptions(zebra, peaking);
		}
	}
}
