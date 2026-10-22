using Uno;
using Uno.UX;
using Uno.Threading;
using Fuse.Scripting;

namespace Fuse.Reactive.FuseJS
{
	/**
		@scriptmodule FuseJS/Maps

		Launches the map application to show a location, search, or open
		directions.

		You need to add a reference to `Fuse.Launcher` (or
		`Fuse.Launcher.Maps`) in your project file to use this feature.

		## Example

		```js
			var Maps = require("FuseJS/Maps");
			Maps.searchNear(59.9117715, 10.7400957, "pizza restaurant")
				.then(function(result) {
					console.log(result.status);
				});
		```
	*/
	[UXGlobalModule]
	public sealed class Maps : NativeModule
	{
		static readonly Maps _instance;

		public Maps()
		{
			if(_instance != null) return;
			Resource.SetGlobalKey(_instance = this, "FuseJS/Maps");
			AddMember(new NativeFunction("isAvailable", IsAvailable));
			AddMember(new NativePromise<MapLaunchStatus, Scripting.Object>(
				"open", Open, ConvertResult));
			AddMember(new NativePromise<MapLaunchStatus, Scripting.Object>(
				"search", Search, ConvertResult));
			AddMember(new NativePromise<MapLaunchStatus, Scripting.Object>(
				"directions", Directions, ConvertResult));
			AddMember(new NativePromise<MapLaunchStatus, Scripting.Object>(
				"openAt", OpenAt, ConvertResult));
			AddMember(new NativePromise<MapLaunchStatus, Scripting.Object>(
				"searchNearby", SearchNearby, ConvertResult));
			AddMember(new NativePromise<MapLaunchStatus, Scripting.Object>(
				"searchNear", SearchNear, ConvertResult));
		}

		/**
			@scriptmethod isAvailable()

			Returns `true` when the platform can launch a map application.

			@return (Bool) Whether a map application is available.
		*/
		static object IsAvailable(Scripting.Context context, object[] args)
		{
			return Fuse.LauncherImpl.MapsLauncher.IsAvailable();
		}

		/**
			@scriptmethod open(options)

			Shows a location on the map.

			Options:
			- `latitude` – Latitude in decimal degrees.
			- `longitude` – Longitude in decimal degrees.
			- `label` – An optional label for the pin.
			- `zoom` – An optional zoom level (1–23).
			- `mapType` – `"standard"`, `"satellite"` or `"hybrid"`.
			- `androidPackage` – An Android package to target.
			- `preferGoogleMaps` – Try Google Maps first on iOS.
			- `useWebFallback` – Open a web map when no native app is available.

			@return (Promise) Resolves to an object with `status`
			(`"opened"`). Rejects when the map cannot be opened.

			## Example
			```js
				Maps.open({
					latitude: 59.9117715,
					longitude: 10.7400957,
					label: "Fuse",
					zoom: 16
				}).then(function(result) {
					console.log(result.status);
				});
			```
		*/
		static Future<MapLaunchStatus> Open(Scripting.Context context, object[] args)
		{
			var promise = new Promise<MapLaunchStatus>();

			try
			{
				var options = RequireOptions(args, "open");

				Launch(new MapLaunchOptions
				{
					Location = ParseSingleLocation(options, "open"),
					Zoom = GetInt(options, "zoom", 0),
					MapType = ParseMapType(GetString(options, "mapType")),
					AndroidPackage = GetString(options, "androidPackage"),
					PreferGoogleMaps = GetBool(options, "preferGoogleMaps", false),
					UseWebFallback = GetBool(options, "useWebFallback", true)
				}, promise);
			}
			catch (Exception e)
			{
				promise.Reject(e);
			}

			return promise;
		}

		/**
			@scriptmethod search(queryOrOptions)

			Searches for a place.

			Pass a query string, or an options object with:
			- `query` – The search query.
			- `near` – An optional location object
			  (`{ latitude, longitude, label }`) to search near.
			- `zoom`, `mapType`, `androidPackage`, `preferGoogleMaps`,
			  `useWebFallback` – As for `open`.

			@return (Promise) Resolves to an object with `status`
			(`"opened"`). Rejects when the map cannot be opened.

			## Example
			```js
				Maps.search({ query: "pizza", near: { latitude: 59.9, longitude: 10.7 } });
			```
		*/
		static Future<MapLaunchStatus> Search(Scripting.Context context, object[] args)
		{
			var promise = new Promise<MapLaunchStatus>();

			try
			{
				if (args == null || args.Length == 0)
					throw new Exception("search requires a query string or an options object.");

				MapLaunchOptions mapOptions;

				var query = args[0] as string;
				if (query != null)
				{
					if (string.IsNullOrEmpty(query))
						throw new Exception("search requires a non-empty query string.");

					mapOptions = new MapLaunchOptions { Query = query };
				}
				else
				{
					var source = args[0] as Scripting.Object;
					if (source == null)
						throw new Exception("search requires a query string or an options object.");

					mapOptions = new MapLaunchOptions
					{
						Query = GetString(source, "query"),
						Zoom = GetInt(source, "zoom", 0),
						MapType = ParseMapType(GetString(source, "mapType")),
						AndroidPackage = GetString(source, "androidPackage"),
						PreferGoogleMaps = GetBool(source, "preferGoogleMaps", false),
						UseWebFallback = GetBool(source, "useWebFallback", true)
					};

					if (source.ContainsKey("near") && source["near"] != null)
						mapOptions.SearchNear = ParseLocation(source["near"], "near");

					if (string.IsNullOrEmpty(mapOptions.Query))
						throw new Exception("search requires a 'query' string.");
				}

				Launch(mapOptions, promise);
			}
			catch (Exception e)
			{
				promise.Reject(e);
			}

			return promise;
		}

		/**
			@scriptmethod directions(options)

			Opens directions.

			Options:
			- `from` – An optional location object. Defaults to the current
			  location.
			- `to` – A location object or an address string.
			- `mode` – `"driving"`, `"walking"`, `"transit"` or `"cycling"`.
			- `startNavigation` – Start turn-by-turn navigation when possible.
			- `mapType`, `showTraffic`, `preferGoogleMaps`,
			  `androidPackage`, `useWebFallback` – As for `open`.

			@return (Promise) Resolves to an object with `status`
			(`"opened"`). Rejects when the map cannot be opened.

			## Example
			```js
				Maps.directions({
					to: { latitude: 59.9117715, longitude: 10.7400957, label: "Fuse" },
					mode: "walking"
				});
			```
		*/
		static Future<MapLaunchStatus> Directions(Scripting.Context context, object[] args)
		{
			var promise = new Promise<MapLaunchStatus>();

			try
			{
				var source = RequireOptions(args, "directions");

				if (!source.ContainsKey("to") || source["to"] == null)
					throw new Exception("directions requires a 'to' location or address.");

				var mapOptions = new MapLaunchOptions
				{
					TravelMode = ParseTravelMode(GetString(source, "mode")),
					StartNavigation = GetBool(source, "startNavigation", false),
					MapType = ParseMapType(GetString(source, "mapType")),
					ShowTraffic = GetBool(source, "showTraffic", false),
					PreferGoogleMaps = GetBool(source, "preferGoogleMaps", false),
					AndroidPackage = GetString(source, "androidPackage"),
					UseWebFallback = GetBool(source, "useWebFallback", true)
				};

				var address = source["to"] as string;
				if (address != null)
				{
					if (string.IsNullOrEmpty(address.Trim()))
						throw new Exception("directions requires a non-empty 'to' address.");

					mapOptions.DestinationAddress = address;
				}
				else
				{
					mapOptions.Destination = ParseLocation(source["to"], "to");
				}

				if (source.ContainsKey("from") && source["from"] != null)
					mapOptions.Origin = ParseLocation(source["from"], "from");

				Launch(mapOptions, promise);
			}
			catch (Exception e)
			{
				promise.Reject(e);
			}

			return promise;
		}

		/**
			@scriptmethod openAt(latitude, longitude)

			Shows a location on the map.

			This is the legacy positional form. Prefer `open`.

			@return (Promise) Resolves to an object with `status`.
		*/
		public static Future<MapLaunchStatus> OpenAt(Scripting.Context context, object[] args)
		{
			var promise = new Promise<MapLaunchStatus>();

			try
			{
				if (args == null || args.Length < 2)
					throw new Exception("openAt requires latitude and longitude.");

				Launch(new MapLaunchOptions
				{
					Location = new MapLocation(
						Marshal.ToDouble(args[0]),
						Marshal.ToDouble(args[1]))
				}, promise);
			}
			catch (Exception e)
			{
				promise.Reject(e);
			}

			return promise;
		}

		/**
			@scriptmethod searchNearby(query)

			Searches for a place.

			This is the legacy form. Prefer `search`.

			@return (Promise) Resolves to an object with `status`.
		*/
		public static Future<MapLaunchStatus> SearchNearby(Scripting.Context context, object[] args)
		{
			var promise = new Promise<MapLaunchStatus>();

			try
			{
				var query = args != null && args.Length > 0 ? args[0] as string : null;
				if (string.IsNullOrEmpty(query))
					throw new Exception("searchNearby requires a query string.");

				Launch(new MapLaunchOptions { Query = query }, promise);
			}
			catch (Exception e)
			{
				promise.Reject(e);
			}

			return promise;
		}

		/**
			@scriptmethod searchNear(latitude, longitude, query)

			Searches for a place near a location.

			This is the legacy form. Prefer `search`.

			@return (Promise) Resolves to an object with `status`.
		*/
		public static Future<MapLaunchStatus> SearchNear(Scripting.Context context, object[] args)
		{
			var promise = new Promise<MapLaunchStatus>();

			try
			{
				if (args == null || args.Length < 3)
					throw new Exception("searchNear requires latitude, longitude and a query string.");

				var query = args[2] as string;
				if (string.IsNullOrEmpty(query))
					throw new Exception("searchNear requires a query string.");

				Launch(new MapLaunchOptions
				{
					Location = new MapLocation(
						Marshal.ToDouble(args[0]),
						Marshal.ToDouble(args[1])),
					Query = query
				}, promise);
			}
			catch (Exception e)
			{
				promise.Reject(e);
			}

			return promise;
		}

		static void Launch(MapLaunchOptions options, Promise<MapLaunchStatus> promise)
		{
			Fuse.LauncherImpl.MapsLauncher.Launch(options).Then(
				status => promise.Resolve(status),
				error => promise.Reject(error));
		}

		static Scripting.Object ConvertResult(Scripting.Context context, MapLaunchStatus status)
		{
			var result = context.NewObject();
			result["status"] = "opened";
			return result;
		}

		static Scripting.Object RequireOptions(object[] args, string method)
		{
			if (args == null || args.Length == 0)
				throw new Exception(method + " requires an options object.");

			var options = args[0] as Scripting.Object;
			if (options == null)
				throw new Exception(method + " requires an options object.");

			return options;
		}

		static MapLocation ParseSingleLocation(Scripting.Object options, string method)
		{
			if (options.ContainsKey("location") && options["location"] != null)
				return ParseLocation(options["location"], "location");

			if (!options.ContainsKey("latitude") || !options.ContainsKey("longitude"))
				throw new Exception(method + " requires latitude and longitude.");

			return FromCoordinates(options);
		}

		static MapLocation ParseLocation(object value, string name)
		{
			var options = value as Scripting.Object;
			if (options == null)
				throw new Exception("'" + name + "' must be a location object.");

			if (!options.ContainsKey("latitude") || !options.ContainsKey("longitude"))
				throw new Exception("'" + name + "' requires latitude and longitude.");

			return FromCoordinates(options);
		}

		static MapLocation FromCoordinates(Scripting.Object options)
		{
			return new MapLocation(
				Marshal.ToDouble(options["latitude"]),
				Marshal.ToDouble(options["longitude"]),
				GetString(options, "label"));
		}

		static string GetString(Scripting.Object options, string key)
		{
			if (options == null || !options.ContainsKey(key))
				return null;

			var value = options[key];
			if (value == null)
				return null;

			var str = value as string;
			return str != null ? str : value.ToString();
		}

		static bool GetBool(Scripting.Object options, string key, bool defaultValue)
		{
			if (options == null || !options.ContainsKey(key) || options[key] == null)
				return defaultValue;

			return Marshal.ToBool(options[key]);
		}

		static int GetInt(Scripting.Object options, string key, int defaultValue)
		{
			if (options == null || !options.ContainsKey(key) || options[key] == null)
				return defaultValue;

			return Marshal.ToInt(options[key]);
		}

		static MapType ParseMapType(string value)
		{
			if (string.IsNullOrEmpty(value))
				return MapType.Standard;

			var normalized = value.ToLower();
			if (normalized == "standard")
				return MapType.Standard;
			if (normalized == "satellite")
				return MapType.Satellite;
			if (normalized == "hybrid")
				return MapType.Hybrid;

			throw new Exception(
				"Unknown mapType '" + value + "'. Use \"standard\", \"satellite\" or \"hybrid\".");
		}

		static MapTravelMode ParseTravelMode(string value)
		{
			if (string.IsNullOrEmpty(value))
				return MapTravelMode.Driving;

			var normalized = value.ToLower();
			if (normalized == "driving")
				return MapTravelMode.Driving;
			if (normalized == "walking")
				return MapTravelMode.Walking;
			if (normalized == "transit")
				return MapTravelMode.Transit;
			if (normalized == "cycling" || normalized == "bicycling")
				return MapTravelMode.Cycling;

			throw new Exception(
				"Unknown mode '" + value + "'. Use \"driving\", \"walking\", \"transit\" or \"cycling\".");
		}
	}
}
