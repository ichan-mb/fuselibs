using Uno;

namespace Fuse.Controls
{
	/**
		Metadata for a captured photo.

		The size is reported as the photo will be displayed, so images with a
		rotated EXIF orientation have their width and height swapped.
	*/
	public class PhotoMetadata
	{
		public const string WidthName = "width";
		public const string HeightName = "height";
		public const string OrientationName = "orientation";
		public const string TimestampName = "timestamp";
		public const string IsoName = "iso";
		public const string ExposureTimeName = "exposureTime";
		public const string FNumberName = "fNumber";
		public const string FocalLengthName = "focalLength";

		/** Displayed width in pixels. */
		public readonly int Width;
		/** Displayed height in pixels. */
		public readonly int Height;
		/** EXIF orientation (1 to 8). */
		public readonly int Orientation;
		/** Capture time in milliseconds since the Unix epoch, or 0 when unknown. */
		public readonly double Timestamp;
		/** ISO sensitivity, or 0 when unknown. */
		public readonly int Iso;
		/** Exposure time in seconds, or 0 when unknown. */
		public readonly float ExposureTime;
		/** Aperture f-number, or 0 when unknown. */
		public readonly float FNumber;
		/** Focal length in millimeters, or 0 when unknown. */
		public readonly float FocalLength;

		public PhotoMetadata(
			int width,
			int height,
			int orientation,
			double timestamp,
			int iso,
			float exposureTime,
			float fNumber,
			float focalLength)
		{
			Width = width;
			Height = height;
			Orientation = orientation;
			Timestamp = timestamp;
			Iso = iso;
			ExposureTime = exposureTime;
			FNumber = fNumber;
			FocalLength = focalLength;
		}

		internal static PhotoMetadata FromExif(
			int width,
			int height,
			int orientation,
			int iso,
			double timestamp,
			float exposureTime,
			float fNumber,
			float focalLength)
		{
			// Orientations 5 to 8 swap the width and height.
			if (orientation >= 5 && orientation <= 8)
			{
				var tmp = width;
				width = height;
				height = tmp;
			}

			return new PhotoMetadata(width, height, orientation, timestamp, iso, exposureTime, fNumber, focalLength);
		}
	}
}
