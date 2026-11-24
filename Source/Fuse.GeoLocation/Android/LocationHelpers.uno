using Uno.Compiler.ExportTargetInterop;
using Fuse.GeoLocation;

namespace Fuse.GeoLocation.Android
{
	[ForeignInclude(Language.Java, "android.location.Location")]
	public extern(Android) class LocationHelpers
	{
		[Foreign(Language.Java)]
		public static double GetAltitude(this Java.Object handle)
		@{
			Location l = (Location)handle;
			return l.getAltitude();
		@}

		[Foreign(Language.Java)]
		public static bool HasAltitude(this Java.Object handle)
		@{
			return ((Location)handle).hasAltitude();
		@}

		[Foreign(Language.Java)]
		public static double GetLatitude(this Java.Object handle)
		@{
			Location l = (Location)handle;
			return l.getLatitude();
		@}

		[Foreign(Language.Java)]
		public static double GetLongitude(this Java.Object handle)
		@{
			Location l = (Location)handle;
			return l.getLongitude();
		@}

		[Foreign(Language.Java)]
		public static double GetSpeed(this Java.Object handle)
		@{
			Location l = (Location)handle;
			return l.getSpeed();
		@}

		[Foreign(Language.Java)]
		public static bool HasSpeed(this Java.Object handle)
		@{
			return ((Location)handle).hasSpeed();
		@}

		[Foreign(Language.Java)]
		public static long GetTime(this Java.Object handle)
		@{
			Location l = (Location)handle;
			return l.getTime();
		@}

		[Foreign(Language.Java)]
		public static float GetAccuracy(this Java.Object handle)
		@{
			Location l = (Location)handle;
			return l.getAccuracy();
		@}

		[Foreign(Language.Java)]
		public static double GetVerticalAccuracy(this Java.Object handle)
		@{
			Location l = (Location)handle;
			if (android.os.Build.VERSION.SDK_INT >= 26 && l.hasVerticalAccuracy())
				return l.getVerticalAccuracyMeters();
			return -1;
		@}

		[Foreign(Language.Java)]
		public static double GetBearing(this Java.Object handle)
		@{
			Location l = (Location)handle;
			if (android.os.Build.VERSION.SDK_INT >= 26)
			{
				if (l.hasBearing())
					return l.getBearing();
				return -1;
			}
			return l.getBearing();
		@}

		[Foreign(Language.Java)]
		public static bool HasBearing(this Java.Object handle)
		@{
			Location l = (Location)handle;
			if (android.os.Build.VERSION.SDK_INT >= 26)
				return l.hasBearing();
			return true;
		@}

		[Foreign(Language.Java)]
		public static double GetSpeedAccuracy(this Java.Object handle)
		@{
			Location l = (Location)handle;
			if (android.os.Build.VERSION.SDK_INT >= 26 && l.hasSpeedAccuracy())
				return l.getSpeedAccuracyMetersPerSecond();
			return -1;
		@}

		[Foreign(Language.Java)]
		public static bool GetIsMock(this Java.Object handle)
		@{
			Location l = (Location)handle;
			if (android.os.Build.VERSION.SDK_INT >= 31)
				return l.isMock();
			if (android.os.Build.VERSION.SDK_INT >= 18)
				return l.isFromMockProvider();
			return false;
		@}

		[Foreign(Language.Java)]
		public static string GetProvider(this Java.Object handle)
		@{
			return ((Location)handle).getProvider();
		@}

		public static Location ConvertLocation(Java.Object loc)
		{
			var instant = Uno.Time.Instant.FromMillisecondsSinceUnixEpoch(LocationHelpers.GetTime(loc));
			var dateTime = new Uno.Time.LocalDateTime(instant, Uno.Time.CalendarSystem.Iso);
			var heading = LocationHelpers.GetBearing(loc);

			return new Location(
							new GeoCoordinates(LocationHelpers.GetLatitude(loc),
							LocationHelpers.GetLongitude(loc)),
							LocationHelpers.GetAccuracy(loc),
							LocationHelpers.GetAltitude(loc),
							LocationHelpers.GetSpeed(loc),
							dateTime,
							LocationHelpers.GetVerticalAccuracy(loc),
							heading,
							LocationHelpers.GetSpeedAccuracy(loc),
							LocationHelpers.GetIsMock(loc),
							LocationHelpers.GetProvider(loc),
							LocationHelpers.HasAltitude(loc),
							LocationHelpers.HasSpeed(loc),
							LocationHelpers.HasBearing(loc));
		}
	}
}
