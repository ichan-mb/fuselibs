namespace Fuse
{
	/**
		The result of a successful map launch.

		`Opened` means the platform handed the request to a map application.
		Failures are reported as a rejected `Future` / `Promise`.
	*/
	public enum MapLaunchStatus
	{
		Opened
	}

	/** How to travel when opening directions. */
	public enum MapTravelMode
	{
		Driving,
		Walking,
		Transit,
		Cycling
	}

	/** The base map to show. */
	public enum MapType
	{
		Standard,
		Satellite,
		Hybrid
	}

	/**
		Describes what to show in the platform map application.

		Set `Location` to show a point, `Query` to search, or both to search
		near a point. Set `Destination` (or `DestinationAddress`) to open
		directions instead.

		When a destination is set, `Location`, `Query` and `SearchNear` are
		ignored. All properties are optional, but at least one of `Location`,
		`SearchNear`, `Query`, `Destination` or `DestinationAddress` must be
		set.
	*/
	public sealed class MapLaunchOptions
	{
		/** A location to show on the map. */
		public MapLocation Location { get; set; }

		/** A free-text search query, such as a place name or address. */
		public string Query { get; set; }

		/**
			The origin used to rank search results.

			Ignored by platforms that do not support a search origin.
		*/
		public MapLocation SearchNear { get; set; }

		/**
			The origin of directions.

			When `null`, directions start at the current location.
		*/
		public MapLocation Origin { get; set; }

		/** The destination of directions, as coordinates. */
		public MapLocation Destination { get; set; }

		/**
			The destination of directions, as a free-text address.

			Ignored when `Destination` is set.
		*/
		public string DestinationAddress { get; set; }

		/** How to travel when opening directions. */
		public MapTravelMode TravelMode { get; set; }

		/**
			Start turn-by-turn navigation when possible.

			Supported on Android when Google Maps handles the request, and by
			Google Maps URLs. Ignored on iOS, where Maps opens the directions
			view instead.
		*/
		public bool StartNavigation { get; set; }

		/**
			The base map to show.

			The Android `geo:` intent has no map-type parameter; Apple Maps
			(links and MapKit directions) and the Google Maps map-view URL
			apply it. Google Maps has no hybrid basemap, so `Hybrid` uses
			satellite there.
		*/
		public MapType MapType { get; set; }

		/**
			The zoom level.

			`0` uses the platform default. Valid values are 1 to 23; each
			platform clamps to the range it supports.
		*/
		public int Zoom { get; set; }

		/** Show traffic when opening coordinate directions in Apple Maps. iOS only. */
		public bool ShowTraffic { get; set; }

		/**
			Try the Google Maps app before Apple Maps. iOS only.

			If Google Maps is not installed, the launch falls back to Apple
			Maps.
		*/
		public bool PreferGoogleMaps { get; set; }

		/**
			An Android package to target, for example
			`"com.google.android.apps.maps"`.

			If the package is not installed the launch falls back to the
			default map application.
		*/
		public string AndroidPackage { get; set; }

		/**
			Open a web map when no native map application can handle the
			request. Enabled by default.
		*/
		public bool UseWebFallback { get; set; }

		public MapLaunchOptions()
		{
			UseWebFallback = true;
		}
	}
}
