using Uno;
using Uno.Threading;

namespace Fuse.LauncherImpl
{
	public static class MapsLauncher
	{
		/** Whether the platform can launch a map application. */
		public static bool IsAvailable()
		{
			if defined(Android)
				return MapsPlatformAndroid.IsAvailable();
			else if defined(iOS)
				return MapsPlatformIOS.IsAvailable();
			else
				return false;
		}

		/**
			Open the platform map application.

			The returned future resolves to `MapLaunchStatus.Opened` once the
			platform hands the request to a map application, and rejects with a
			user-facing message when it cannot.
		*/
		public static Future<MapLaunchStatus> Launch(MapLaunchOptions options)
		{
			var promise = new Promise<MapLaunchStatus>();

			try
			{
				MapsUriHelper.Validate(options);

				if defined(Android)
					MapsPlatformAndroid.Launch(options, promise);
				else if defined(iOS)
					MapsPlatformIOS.Launch(options, promise);
				else
					promise.Reject(new Exception("Maps are not supported on this platform."));
			}
			catch (Exception e)
			{
				promise.Reject(e);
			}

			return promise;
		}

		/**
			Open directions to a destination.

			When `origin` is `null`, directions start at the current location.
		*/
		public static Future<MapLaunchStatus> LaunchDirections(
			MapLocation origin, MapLocation destination)
		{
			return LaunchDirections(origin, destination, MapTravelMode.Driving);
		}

		/** Open directions using the given travel mode. */
		public static Future<MapLaunchStatus> LaunchDirections(
			MapLocation origin, MapLocation destination, MapTravelMode mode)
		{
			return Launch(new MapLaunchOptions
			{
				Origin = origin,
				Destination = destination,
				TravelMode = mode
			});
		}

		public static void LaunchMaps(double latitude, double longitude)
		{
			Launch(new MapLaunchOptions
			{
				Location = new MapLocation(latitude, longitude)
			}).Catch(e => { });
		}

		public static void LaunchMaps(string query)
		{
			Launch(new MapLaunchOptions
			{
				Query = query
			}).Catch(e => { });
		}

		public static void LaunchMaps(double latitude, double longitude, string query)
		{
			Launch(new MapLaunchOptions
			{
				Location = new MapLocation(latitude, longitude),
				Query = query
			}).Catch(e => { });
		}
	}
}
