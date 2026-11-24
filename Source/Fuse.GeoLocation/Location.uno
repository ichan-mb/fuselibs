using Uno.Time;

namespace Fuse.GeoLocation
{
	public class Location
	{
		GeoCoordinates _coordinates;
		LocalDateTime _dateTime;
		double _altitude;
		double _accuracy;
		double _speed;
		double _verticalAccuracy;
		double _heading;
		double _speedAccuracy;
		bool _isMock;
		string _provider;
		bool _hasAltitude;
		bool _hasSpeed;
		bool _hasHeading;

		public GeoCoordinates Coordinates { get { return _coordinates; } }
		public LocalDateTime DateTime { get { return _dateTime; }}

		/*
		 * Horizontal accuracy in meters
		 */
		public double Accuracy { get { return _accuracy; } }

		public double Altitude { get { return _altitude; } }

		public bool HasAltitude { get { return _hasAltitude; } }

		public double Speed { get { return _speed; } }

		public bool HasSpeed { get { return _hasSpeed; } }

		/*
		 * Vertical accuracy in meters. A negative value means unavailable.
		 */
		public double VerticalAccuracy { get { return _verticalAccuracy; } }

		/*
		 * Direction of travel in degrees from true north. A negative value means unavailable.
		 */
		public double Heading { get { return _heading; } }

		public bool HasHeading { get { return _hasHeading; } }

		/*
		 * Speed accuracy in meters per second. A negative value means unavailable.
		 */
		public double SpeedAccuracy { get { return _speedAccuracy; } }

		/*
		 * True when the location was reported by a mock/spoofed provider.
		 */
		public bool IsMock { get { return _isMock; } }

		/*
		 * The name of the provider that produced this location, when available.
		 */
		public string Provider { get { return _provider; } }

		/*
		 * Milliseconds since the Unix epoch.
		 */
		public long Timestamp
		{
			get { return _dateTime.InUtc().ToInstant().Ticks / Constants.TicksPerMillisecond; }
		}

		public Location(GeoCoordinates coordinates, double accuracy, double altitude, double speed, LocalDateTime dateTime)
			: this(coordinates, accuracy, altitude, speed, dateTime, -1, -1, -1, false, null, true, true, false)
		{
		}

		public Location(
			GeoCoordinates coordinates,
			double accuracy,
			double altitude,
			double speed,
			LocalDateTime dateTime,
			double verticalAccuracy,
			double heading,
			double speedAccuracy,
			bool isMock,
			string provider,
			bool hasAltitude,
			bool hasSpeed,
			bool hasHeading)
		{
			_coordinates = coordinates;
			_accuracy = accuracy;
			_dateTime = dateTime;
			_altitude = altitude;
			_speed = speed;
			_verticalAccuracy = verticalAccuracy;
			_heading = heading;
			_speedAccuracy = speedAccuracy;
			_isMock = isMock;
			_provider = provider;
			_hasAltitude = hasAltitude;
			_hasSpeed = hasSpeed;
			_hasHeading = hasHeading;
		}

		public override string ToString()
		{
			return Coordinates + " " + Accuracy + " (" + DateTime.Month + "/" + DateTime.Day + " " + DateTime.Hour + ":" + DateTime.Minute + ")";
		}
	}
}
