namespace Fuse
{
	/**
		A geographic location used when launching a map application.

		Latitude and longitude are in decimal degrees (WGS 84).
	*/
	public sealed class MapLocation
	{
		/** The latitude in decimal degrees, between -90 and 90. */
		public double Latitude { get; set; }

		/** The longitude in decimal degrees, between -180 and 180. */
		public double Longitude { get; set; }

		/**
			An optional label for the location, such as a place name.

			Used as the pin label, and as the origin/destination name when
			opening directions in Apple Maps.
		*/
		public string Label { get; set; }

		public MapLocation()
		{
		}

		public MapLocation(double latitude, double longitude)
		{
			Latitude = latitude;
			Longitude = longitude;
		}

		public MapLocation(double latitude, double longitude, string label)
		{
			Latitude = latitude;
			Longitude = longitude;
			Label = label;
		}
	}
}
