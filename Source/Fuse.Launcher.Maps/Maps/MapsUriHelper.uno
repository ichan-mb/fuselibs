using Uno;
using Uno.Net.Http;

namespace Fuse
{
	/**
		Builds map URIs and URLs for the supported platforms.

		The Android `geo:` scheme, Apple Maps links, Google Maps URLs and the
		Google Maps iOS URL scheme are built here so they can be tested without
		a device.
	*/
	internal static class MapsUriHelper
	{
		const int MaxZoom = 23;
		const int MaxAppleZoom = 20;
		const int MaxGoogleZoom = 21;

		public static void Validate(MapLaunchOptions options)
		{
			if (options == null)
				throw new ArgumentNullException(nameof(options));

			var hasDestination = HasDestination(options);

			if (!hasDestination &&
				options.Location == null && options.SearchNear == null &&
				string.IsNullOrEmpty(Query(options)))
				throw new ArgumentException(
					"MapLaunchOptions requires a Location, SearchNear, Query or Destination.");

			if (options.Location != null)
				ValidateLocation(options.Location);

			if (options.SearchNear != null)
				ValidateLocation(options.SearchNear);

			if (options.Origin != null)
				ValidateLocation(options.Origin);

			if (options.Destination != null)
				ValidateLocation(options.Destination);

			if (options.Origin != null && !hasDestination)
				throw new ArgumentException("Origin requires a Destination.");

			if (options.Zoom != 0 && (options.Zoom < 1 || options.Zoom > MaxZoom))
				throw new ArgumentOutOfRangeException(
					"Zoom must be between 1 and " + MaxZoom +
					", or 0 for the platform default.",
					nameof(options));
		}

		static void ValidateLocation(MapLocation location)
		{
			if (location == null)
				throw new ArgumentNullException(nameof(location));

			if (Double.IsNaN(location.Latitude) || Double.IsInfinity(location.Latitude) ||
				location.Latitude < -90 || location.Latitude > 90)
				throw new ArgumentOutOfRangeException(
					"Latitude must be between -90 and 90.", nameof(location));

			if (Double.IsNaN(location.Longitude) || Double.IsInfinity(location.Longitude) ||
				location.Longitude < -180 || location.Longitude > 180)
				throw new ArgumentOutOfRangeException(
					"Longitude must be between -180 and 180.", nameof(location));
		}

		/** Whether the options describe directions rather than a map view. */
		public static bool HasDestination(MapLaunchOptions options)
		{
			return options.Destination != null ||
				!string.IsNullOrEmpty(DestinationAddress(options));
		}

		/** Builds an Android `geo:` URI for showing a point or searching. */
		public static string BuildGeoUri(MapLaunchOptions options)
		{
			Validate(options);

			if (HasDestination(options))
				throw new ArgumentException(
					"BuildGeoUri does not support directions. Use BuildAndroidDirectionsUri.");

			var query = Query(options);
			if (!string.IsNullOrEmpty(query))
			{
				var searchCenter = ResolveSearchCenter(options);
				var uri = searchCenter != null
					? "geo:" + Format(searchCenter)
					: "geo:0,0";

				// Android has no documented "search near" parameter. Map apps
				// conventionally treat geo:lat,lng?q=query as a nearby search.
				uri = AddParameter(uri, "q", Uri.EscapeDataString(query));
				return AddParameter(uri, "z", ClampZoom(options.Zoom, MaxZoom));
			}

			// The documented form for dropping a pin at a coordinate.
			var pin = "geo:0,0?q=" + FormatWithLabel(ResolveLocation(options));
			return AddParameter(pin, "z", ClampZoom(options.Zoom, MaxZoom));
		}

		/**
			Builds the Android URI for directions.

			`google.navigation:` starts turn-by-turn navigation and is only
			used with Google Maps. Other cases use a Google Maps directions
			URL, which opens Google Maps or a browser.
		*/
		public static string BuildAndroidDirectionsUri(MapLaunchOptions options)
		{
			Validate(options);

			if (!HasDestination(options))
				throw new ArgumentException(
					"Directions require a Destination or DestinationAddress.");

			if (options.StartNavigation && options.Destination != null &&
				CanUseGoogleNavigation(options.AndroidPackage))
			{
				var mode = AndroidNavigationMode(options.TravelMode);
				if (mode != null)
					return "google.navigation:q=" + Format(options.Destination) +
						"&mode=" + mode;
			}

			return BuildGoogleMapsUrl(options);
		}

		/** Builds an Apple Maps link. */
		public static string BuildAppleMapsUri(MapLaunchOptions options)
		{
			Validate(options);

			if (HasDestination(options))
			{
				var uri = "https://maps.apple.com/?saddr=";
				if (options.Origin != null)
					uri += Format(options.Origin);

				uri += "&daddr=" + DestinationForUri(options);
				uri += "&dirflg=" + AppleDirectionsFlag(options.TravelMode);
				return uri;
			}

			var query = Query(options);
			if (!string.IsNullOrEmpty(query))
			{
				var uri = "https://maps.apple.com/?q=" + Uri.EscapeDataString(query);
				var searchNear = ResolveSearchCenter(options);
				if (searchNear != null)
					uri = AddParameter(uri, "sll", Format(searchNear));

				uri = AddParameter(uri, "z", ClampZoom(options.Zoom, MaxAppleZoom));
				return AddParameter(uri, "t", AppleMapType(options.MapType));
			}

			var location = ResolveLocation(options);
			var latlon = Format(location);
			var result = "https://maps.apple.com/?ll=" + latlon;
			result = AddParameter(result, "q",
				!string.IsNullOrEmpty(location.Label)
					? Uri.EscapeDataString(location.Label)
					: latlon);

			result = AddParameter(result, "z", ClampZoom(options.Zoom, MaxAppleZoom));
			return AddParameter(result, "t", AppleMapType(options.MapType));
		}

		/**
			Builds a Google Maps URL used when no native map application can
			handle the request.
		*/
		public static string BuildGoogleMapsUrl(MapLaunchOptions options)
		{
			Validate(options);

			if (HasDestination(options))
			{
				var uri = "https://www.google.com/maps/dir/?api=1";
				if (options.Origin != null)
					uri = AddParameter(uri, "origin", Format(options.Origin));

				uri = AddParameter(uri, "destination", DestinationForUri(options));
				uri = AddParameter(uri, "travelmode", GoogleTravelMode(options.TravelMode));

				if (options.StartNavigation &&
					options.TravelMode != MapTravelMode.Transit)
					uri = AddParameter(uri, "dir_action", "navigate");

				return uri;
			}

			var query = Query(options);
			if (!string.IsNullOrEmpty(query))
				return "https://www.google.com/maps/search/?api=1&query=" +
					Uri.EscapeDataString(query);

			var location = ResolveLocation(options);
			var result = "https://www.google.com/maps/@?api=1&map_action=map";
			result = AddParameter(result, "center", Format(location));
			result = AddParameter(result, "zoom", ClampZoom(options.Zoom, MaxGoogleZoom));
			return AddParameter(result, "basemap", GoogleSatelliteMode(options.MapType));
		}

		/**
			Builds a Google Maps iOS URL scheme URI.

			Used when `PreferGoogleMaps` is set; the caller falls back to
			Apple Maps when the scheme cannot be opened.
		*/
		public static string BuildGoogleMapsAppUri(MapLaunchOptions options)
		{
			Validate(options);

			if (HasDestination(options))
			{
				var uri = "comgooglemaps://?saddr=";
				if (options.Origin != null)
					uri += Format(options.Origin);

				uri += "&daddr=" + DestinationForUri(options);
				uri += "&directionsmode=" + GoogleTravelMode(options.TravelMode);
				return uri;
			}

			var query = Query(options);
			if (!string.IsNullOrEmpty(query))
				return "comgooglemaps://?q=" + Uri.EscapeDataString(query);

			var location = ResolveLocation(options);
			var result = "comgooglemaps://?q=" + FormatWithLabel(location);
			result = AddParameter(result, "zoom", ClampZoom(options.Zoom, MaxGoogleZoom));
			return AddParameter(result, "mapmode", GoogleSatelliteMode(options.MapType));
		}

		static string Query(MapLaunchOptions options)
		{
			if (string.IsNullOrEmpty(options.Query))
				return null;

			var query = options.Query.Trim();
			return query.Length == 0 ? null : query;
		}

		static string DestinationAddress(MapLaunchOptions options)
		{
			if (string.IsNullOrEmpty(options.DestinationAddress))
				return null;

			var address = options.DestinationAddress.Trim();
			return address.Length == 0 ? null : address;
		}

		static string DestinationForUri(MapLaunchOptions options)
		{
			if (options.Destination != null)
				return Format(options.Destination);

			return Uri.EscapeDataString(DestinationAddress(options));
		}

		static MapLocation ResolveLocation(MapLaunchOptions options)
		{
			if (options.Location != null)
				return options.Location;

			return options.SearchNear;
		}

		static MapLocation ResolveSearchCenter(MapLaunchOptions options)
		{
			if (options.SearchNear != null)
				return options.SearchNear;

			return options.Location;
		}

		static string Format(MapLocation location)
		{
			return location.Latitude.ToString() + "," + location.Longitude.ToString();
		}

		static string FormatWithLabel(MapLocation location)
		{
			var value = Format(location);
			if (string.IsNullOrEmpty(location.Label))
				return value;

			// Keep the coordinate delimiters readable while escaping the label.
			return value + "(" + Uri.EscapeDataString(location.Label) + ")";
		}

		static string AddParameter(string uri, string name, string value)
		{
			if (string.IsNullOrEmpty(value))
				return uri;

			return uri + (uri.IndexOf('?') >= 0 ? "&" : "?") + name + "=" + value;
		}

		static string ClampZoom(int zoom, int max)
		{
			if (zoom <= 0)
				return null;

			return Math.Min(zoom, max).ToString();
		}

		static bool CanUseGoogleNavigation(string packageName)
		{
			return string.IsNullOrEmpty(packageName) ||
				packageName == "com.google.android.apps.maps";
		}

		static string AndroidNavigationMode(MapTravelMode mode)
		{
			switch (mode)
			{
				case MapTravelMode.Driving:
					return "d";
				case MapTravelMode.Walking:
					return "w";
				case MapTravelMode.Cycling:
					return "b";
				default:
					// google.navigation: has no transit mode.
					return null;
			}
		}

		static string AppleMapType(MapType type)
		{
			switch (type)
			{
				case MapType.Satellite:
					return "k";
				case MapType.Hybrid:
					return "h";
				default:
					return null;
			}
		}

		static string AppleDirectionsFlag(MapTravelMode mode)
		{
			// The Apple Maps URL scheme has no cycling flag. MapKit handles
			// cycling; fall back to walking for the link.
			switch (mode)
			{
				case MapTravelMode.Walking:
					return "w";
				case MapTravelMode.Transit:
					return "r";
				case MapTravelMode.Cycling:
					return "w";
				default:
					return "d";
			}
		}

		static string GoogleTravelMode(MapTravelMode mode)
		{
			switch (mode)
			{
				case MapTravelMode.Walking:
					return "walking";
				case MapTravelMode.Transit:
					return "transit";
				case MapTravelMode.Cycling:
					return "bicycling";
				default:
					return "driving";
			}
		}

		static string GoogleSatelliteMode(MapType type)
		{
			switch (type)
			{
				case MapType.Satellite:
				case MapType.Hybrid:
					return "satellite";
				default:
					return null;
			}
		}
	}
}
