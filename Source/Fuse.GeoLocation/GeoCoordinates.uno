using Uno;

namespace Fuse.GeoLocation
{
	public class GeoCoordinates
	{
		const double EarthRadiusMeters = 6371000.0;

		double _lat;
		double _long;

		public double Latitude { get { return _lat; } }
		public double Longitude { get { return _long; } }

		/*
		 * True when latitude and longitude are within their valid ranges.
		 */
		public bool IsValid
		{
			get
			{
				return !double.IsNaN(_lat) && !double.IsNaN(_long)
					&& _lat >= -90 && _lat <= 90
					&& _long >= -180 && _long <= 180;
			}
		}

		public GeoCoordinates(double latitude, double longitude)
		{
			_lat = latitude;
			_long = longitude;
		}

		/*
		 * Great-circle distance to another coordinate, in meters.
		 */
		public double DistanceTo(GeoCoordinates other)
		{
			if (other == null)
				throw new ArgumentNullException("other");

			var lat1 = ToRadians(_lat);
			var lat2 = ToRadians(other._lat);
			var dLat = lat2 - lat1;
			var dLon = ToRadians(other._long - _long);

			var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2)
				+ Math.Cos(lat1) * Math.Cos(lat2) * Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
			a = Math.Clamp(a, 0.0, 1.0);
			var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
			return EarthRadiusMeters * c;
		}

		/*
		 * Initial bearing to another coordinate, in degrees from true north (0-360).
		 */
		public double BearingTo(GeoCoordinates other)
		{
			if (other == null)
				throw new ArgumentNullException("other");

			var lat1 = ToRadians(_lat);
			var lat2 = ToRadians(other._lat);
			var dLon = ToRadians(other._long - _long);

			var y = Math.Sin(dLon) * Math.Cos(lat2);
			var x = Math.Cos(lat1) * Math.Sin(lat2)
				- Math.Sin(lat1) * Math.Cos(lat2) * Math.Cos(dLon);
			var bearing = Math.Atan2(y, x) * 180.0 / Math.PI;
			bearing += 360.0;
			return bearing - Math.Floor(bearing / 360.0) * 360.0;
		}

		static double ToRadians(double degrees)
		{
			return degrees * Math.PI / 180.0;
		}

		public override bool Equals(object obj)
		{
			var other = obj as GeoCoordinates;
			return other != null && _lat == other._lat && _long == other._long;
		}

		public override int GetHashCode()
		{
			return _lat.GetHashCode() ^ _long.GetHashCode();
		}

		public override string ToString()
		{
			return Latitude + " - " + Longitude;
		}
	}
}
