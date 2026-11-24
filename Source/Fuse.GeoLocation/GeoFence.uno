namespace Fuse.GeoLocation
{
	/**
		A circular geofence.
	*/
	public class GeoFence
	{
		readonly int _id;
		readonly GeoCoordinates _center;
		readonly double _radius;
		readonly string _identifier;

		public int Id { get { return _id; } }
		public GeoCoordinates Center { get { return _center; } }

		/**
			Radius in meters.
		*/
		public double Radius { get { return _radius; } }

		/**
			An optional application-defined identifier.
		*/
		public string Identifier { get { return _identifier; } }

		public GeoFence(int id, GeoCoordinates center, double radius, string identifier)
		{
			_id = id;
			_center = center;
			_radius = radius;
			_identifier = identifier != null ? identifier : "";
		}

		public override string ToString()
		{
			return _identifier + " (" + _center + ", " + _radius + "m)";
		}
	}
}
