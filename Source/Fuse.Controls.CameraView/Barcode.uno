using Uno;

namespace Fuse.Controls
{
	/**
		Result of a barcode/QR scan.
	*/
	public class Barcode
	{
		public const string ValueName = "value";
		public const string FormatName = "format";

		/** Barcode format names reported in `Barcode.Format`. */
		public const string FormatUnknown = "UNKNOWN";
		public const string FormatQrCode = "QR_CODE";
		public const string FormatEan13 = "EAN_13";
		public const string FormatEan8 = "EAN_8";
		public const string FormatUpcA = "UPC_A";
		public const string FormatUpcE = "UPC_E";
		public const string FormatCode128 = "CODE_128";
		public const string FormatCode39 = "CODE_39";
		public const string FormatCode93 = "CODE_93";
		public const string FormatItf = "ITF";
		public const string FormatCodabar = "CODABAR";
		public const string FormatDataMatrix = "DATA_MATRIX";
		public const string FormatPdf417 = "PDF417";
		public const string FormatAztec = "AZTEC";

		public readonly string Value;
		public readonly string Format;

		public Barcode(string value, string format)
		{
			Value = value;
			Format = format;
		}
	}
}
