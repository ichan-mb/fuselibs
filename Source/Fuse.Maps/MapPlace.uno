using Uno;
using Uno.UX;
using Uno.Collections;
using Fuse.Scripting;

namespace Fuse.Controls
{
	/** A place returned by @MapView.Geocode or @MapView.ReverseGeocode. */
	public sealed class MapPlace : EventArgs, IScriptEvent
	{
		public readonly string Name;
		public readonly string Address;
		public readonly double Latitude;
		public readonly double Longitude;

		public MapPlace(string name, string address, double latitude, double longitude)
		{
			Name = name;
			Address = address;
			Latitude = latitude;
			Longitude = longitude;
		}

		void IScriptEvent.Serialize(IEventSerializer s)
		{
			s.AddString("name", Name);
			s.AddString("address", Address);
			s.AddDouble("latitude", Latitude);
			s.AddDouble("longitude", Longitude);
		}

		/** Parses the tab/newline separated format produced by the platform geocoders. */
		internal static MapPlace[] ParseList(string encoded)
		{
			if (encoded == null || encoded.Length == 0)
				return new MapPlace[0];

			var lines = encoded.Split('\n');
			var places = new List<MapPlace>();

			foreach (var line in lines)
			{
				if (line.Length == 0) continue;

				var fields = line.Split('\t');
				if (fields.Length < 4) continue;

				double latitude;
				double longitude;
				if (!Double.TryParse(fields[2], out latitude)) continue;
				if (!Double.TryParse(fields[3], out longitude)) continue;

				places.Add(new MapPlace(fields[0], fields[1], latitude, longitude));
			}

			return places.ToArray();
		}
	}

	public enum RouteMode
	{
		Driving,
		Walking,
		Transit,
		Cycling
	}

	/** The result of @MapView.CalculateRoute. */
	public sealed class MapRouteResult : EventArgs
	{
		/** The points of the route, in order. */
		public readonly Coordinate[] Polyline;
		/** The length of the route in meters. */
		public readonly double Distance;
		/** The estimated travel time in seconds. */
		public readonly double Duration;
		/** A human readable name for the route, if the platform provides one. */
		public readonly string Name;

		public MapRouteResult(Coordinate[] polyline, double distance, double duration, string name)
		{
			Polyline = polyline;
			Distance = distance;
			Duration = duration;
			Name = name;
		}

		/** Parses the tab/newline separated format produced by the platform routers. */
		internal static MapRouteResult Parse(string encoded)
		{
			if (encoded == null || encoded.Length == 0)
				return null;

			var lines = encoded.Split('\n');
			if (lines.Length == 0)
				return null;

			var header = lines[0].Split('\t');
			if (header.Length < 2)
				return null;

			double distance;
			double duration;
			if (!Double.TryParse(header[0], out distance)) return null;
			if (!Double.TryParse(header[1], out duration)) return null;

			var name = header.Length > 2 ? header[2] : null;

			var points = new List<Coordinate>();
			for (int i = 1; i < lines.Length; i++)
			{
				var fields = lines[i].Split('\t');
				if (fields.Length < 2) continue;

				double latitude;
				double longitude;
				if (!Double.TryParse(fields[0], out latitude)) continue;
				if (!Double.TryParse(fields[1], out longitude)) continue;

				points.Add(new Coordinate(latitude, longitude));
			}

			return new MapRouteResult(points.ToArray(), distance, duration, name);
		}
	}
}
