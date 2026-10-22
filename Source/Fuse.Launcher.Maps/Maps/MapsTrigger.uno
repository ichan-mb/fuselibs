using Uno;

namespace Fuse.Triggers.Actions
{
	/**
		Launch the default map app to show a location or search.

		You'll find this trigger action in the Fuse.Launcher package, which has
		to be referenced from your uno project.

		For example:
		```json
			{
				"references": [
					"Fuse",
					"FuseJS",
					"Fuse.Launcher"
				]
			}
		```

		The trigger is fire-and-forget. Use `Fuse.Launcher.LaunchMaps` or
		`FuseJS/Maps` when you need the launch result.

		## Example
		```xml
			<StackPanel Margin="20">
				<Button Margin="10" Text="Launch Maps">
					<Clicked>
						<LaunchMaps Latitude="59.9139" Longitude="10.7522" />
					</Clicked>
				</Button>
				<Button Margin="10" Text="Find pizza">
					<Clicked>
						<LaunchMaps Query="pizza" NearLatitude="59.9139" NearLongitude="10.7522" />
					</Clicked>
				</Button>
			</StackPanel>
		```
	*/
	public class LaunchMaps : TriggerAction
	{
		public string Latitude {get; set;}
		public string Longitude {get; set;}

		/** A place name or address to search for. */
		public string Query {get; set;}

		/** An optional label for the pin shown at Latitude/Longitude. */
		public string Label {get; set;}

		/** The zoom level, 1–23. `0` uses the platform default. */
		public int Zoom {get; set;}

		/** The base map to show. */
		public MapType MapType {get; set;}

		/** The latitude to search near, used with Query. */
		public string NearLatitude {get; set;}

		/** The longitude to search near, used with Query. */
		public string NearLongitude {get; set;}

		/** An Android package to target, for example `"com.google.android.apps.maps"`. */
		public string AndroidPackage {get; set;}

		/** Try Google Maps before Apple Maps. iOS only. */
		public bool PreferGoogleMaps {get; set;}

		bool _useWebFallback = true;

		/** Open a web map when no native map app is available. Defaults to true. */
		public bool UseWebFallback
		{
			get { return _useWebFallback; }
			set { _useWebFallback = value; }
		}

		protected override void Perform(Node target)
		{
			double lat = 0;
			double lon = 0;
			var hasLocation = MapTriggerHelper.TryParseCoordinates(
				Latitude, Longitude, out lat, out lon);

			if (!hasLocation && (!string.IsNullOrEmpty(Latitude) || !string.IsNullOrEmpty(Longitude)))
			{
				Fuse.Diagnostics.UserError(
					"`LaunchMaps` requires numeric `Latitude` and `Longitude`.", this);
				return;
			}

			double nearLat = 0;
			double nearLon = 0;
			var hasNear = MapTriggerHelper.TryParseCoordinates(
				NearLatitude, NearLongitude, out nearLat, out nearLon);

			if (!hasNear && (!string.IsNullOrEmpty(NearLatitude) || !string.IsNullOrEmpty(NearLongitude)))
			{
				Fuse.Diagnostics.UserError(
					"`LaunchMaps` requires numeric `NearLatitude` and `NearLongitude`.", this);
				return;
			}

			if (!hasLocation && !hasNear && string.IsNullOrEmpty(Query))
			{
				Fuse.Diagnostics.UserError(
					"`LaunchMaps` requires `Latitude`/`Longitude` or `Query`.", this);
				return;
			}

			if (hasNear && string.IsNullOrEmpty(Query))
			{
				Fuse.Diagnostics.UserError(
					"`LaunchMaps` requires `Query` when using `NearLatitude`/`NearLongitude`.",
					this);
				return;
			}

			var options = new MapLaunchOptions
			{
				Query = Query,
				Zoom = Zoom,
				MapType = MapType,
				AndroidPackage = AndroidPackage,
				PreferGoogleMaps = PreferGoogleMaps,
				UseWebFallback = UseWebFallback
			};

			if (hasLocation)
				options.Location = new MapLocation(lat, lon, Label);

			if (hasNear)
				options.SearchNear = new MapLocation(nearLat, nearLon);

			Fuse.LauncherImpl.MapsLauncher.Launch(options).Catch(e =>
				Fuse.Diagnostics.UserError("Could not launch maps: " + e.Message, this));
		}
	}

	/**
		Open directions in the default map app.

		The trigger is fire-and-forget. Use `Fuse.Launcher.LaunchDirections` or
		`FuseJS/Maps.directions` when you need the launch result.

		## Example
		```xml
			<Button Text="Directions">
				<Clicked>
					<LaunchDirections
						Latitude="59.9139" Longitude="10.7522"
						DestinationLatitude="59.9117" DestinationLongitude="10.7401"
						TravelMode="Walking" />
				</Clicked>
			</Button>
		```
	*/
	public class LaunchDirections : TriggerAction
	{
		/** The origin latitude. Leave empty to start at the current location. */
		public string Latitude {get; set;}

		/** The origin longitude. */
		public string Longitude {get; set;}

		/** An optional label for the origin. */
		public string OriginLabel {get; set;}

		/** The destination latitude. */
		public string DestinationLatitude {get; set;}

		/** The destination longitude. */
		public string DestinationLongitude {get; set;}

		/** An optional label for the destination. */
		public string DestinationLabel {get; set;}

		/** A destination address, used when destination coordinates are not set. */
		public string DestinationAddress {get; set;}

		/** How to travel. */
		public MapTravelMode TravelMode {get; set;}

		/** Start turn-by-turn navigation when possible. */
		public bool StartNavigation {get; set;}

		/** The base map to show. */
		public MapType MapType {get; set;}

		/** Show traffic when opening directions in Apple Maps. iOS only. */
		public bool ShowTraffic {get; set;}

		/** Try Google Maps before Apple Maps. iOS only. */
		public bool PreferGoogleMaps {get; set;}

		/** An Android package to target, for example `"com.google.android.apps.maps"`. */
		public string AndroidPackage {get; set;}

		bool _useWebFallback = true;

		/** Open a web map when no native map app is available. Defaults to true. */
		public bool UseWebFallback
		{
			get { return _useWebFallback; }
			set { _useWebFallback = value; }
		}

		protected override void Perform(Node target)
		{
			double lat = 0;
			double lon = 0;
			var hasOrigin = MapTriggerHelper.TryParseCoordinates(
				Latitude, Longitude, out lat, out lon);

			if (!hasOrigin && (!string.IsNullOrEmpty(Latitude) || !string.IsNullOrEmpty(Longitude)))
			{
				Fuse.Diagnostics.UserError(
					"`LaunchDirections` requires numeric `Latitude` and `Longitude`.", this);
				return;
			}

			double destLat = 0;
			double destLon = 0;
			var hasDestination = MapTriggerHelper.TryParseCoordinates(
				DestinationLatitude, DestinationLongitude, out destLat, out destLon);

			if (!hasDestination &&
				(!string.IsNullOrEmpty(DestinationLatitude) || !string.IsNullOrEmpty(DestinationLongitude)))
			{
				Fuse.Diagnostics.UserError(
					"`LaunchDirections` requires numeric `DestinationLatitude` and `DestinationLongitude`.",
					this);
				return;
			}

			if (!hasDestination && string.IsNullOrEmpty(DestinationAddress))
			{
				Fuse.Diagnostics.UserError(
					"`LaunchDirections` requires `DestinationLatitude`/`DestinationLongitude` or `DestinationAddress`.",
					this);
				return;
			}

			var options = new MapLaunchOptions
			{
				TravelMode = TravelMode,
				StartNavigation = StartNavigation,
				MapType = MapType,
				ShowTraffic = ShowTraffic,
				PreferGoogleMaps = PreferGoogleMaps,
				AndroidPackage = AndroidPackage,
				UseWebFallback = UseWebFallback
			};

			if (hasOrigin)
				options.Origin = new MapLocation(lat, lon, OriginLabel);

			if (hasDestination)
				options.Destination = new MapLocation(destLat, destLon, DestinationLabel);
			else
				options.DestinationAddress = DestinationAddress;

			Fuse.LauncherImpl.MapsLauncher.Launch(options).Catch(e =>
				Fuse.Diagnostics.UserError("Could not launch directions: " + e.Message, this));
		}
	}

	static class MapTriggerHelper
	{
		public static bool TryParseCoordinates(
			string latitude, string longitude, out double lat, out double lon)
		{
			lat = 0;
			lon = 0;

			if (string.IsNullOrEmpty(latitude) && string.IsNullOrEmpty(longitude))
				return false;

			return Double.TryParse(latitude, out lat) &&
				Double.TryParse(longitude, out lon);
		}
	}
}
