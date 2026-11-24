namespace Fuse.GeoLocation
{
	/**
		A compass heading reading.
	*/
	public class Heading
	{
		readonly double _degrees;
		readonly double _accuracy;
		readonly long _timestamp;

		/**
			Heading in degrees clockwise from north (0-360).

			iOS uses true north when the platform can determine it, otherwise
			magnetic north. Android uses magnetic north.
		*/
		public double Degrees { get { return _degrees; } }

		/**
			Accuracy in degrees. A negative value means unavailable.
		*/
		public double Accuracy { get { return _accuracy; } }

		/**
			Milliseconds since the Unix epoch.
		*/
		public long Timestamp { get { return _timestamp; } }

		public Heading(double degrees, double accuracy, long timestamp)
		{
			_degrees = degrees;
			_accuracy = accuracy;
			_timestamp = timestamp;
		}

		public override string ToString()
		{
			return Degrees + " (" + Accuracy + ")";
		}
	}
}
