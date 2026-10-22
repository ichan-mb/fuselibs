using Uno;
using Uno.Text;
using Uno.IO;
using Uno.Collections;
using Uno.Compiler.ExportTargetInterop;
using Fuse.Android.Permissions;
using Uno.Net.Http;
using Uno.Threading;
using Fuse.LauncherImpl;

namespace Fuse
{
	public static class Launcher
	{
		public static void LaunchUri(Uri uri)
		{
			InterAppLauncher.LaunchUri(uri);
		}

		public static void LaunchCall(string phoneNumber)
		{
			PhoneLauncher.LaunchCall(phoneNumber);
		}

		public static void LaunchSms(string phoneNumber, string body)
		{
			PhoneLauncher.LaunchSms(phoneNumber, body);
		}

		public static void LaunchMaps(double latitude, double longitude)
		{
			MapsLauncher.LaunchMaps(latitude, longitude);
		}

		public static void LaunchMaps(string query)
		{
			MapsLauncher.LaunchMaps(query);
		}

		public static void LaunchMaps(double latitude, double longitude, string query)
		{
			MapsLauncher.LaunchMaps(latitude, longitude, query);
		}

		/** Whether the platform can launch a map application. */
		public static bool IsMapAvailable()
		{
			return MapsLauncher.IsAvailable();
		}

		/**
			Open the platform map application.

			The returned future resolves to `MapLaunchStatus.Opened` once the
			platform hands the request to a map application, and rejects with a
			user-facing message when it cannot.
		*/
		public static Future<MapLaunchStatus> LaunchMaps(MapLaunchOptions options)
		{
			return MapsLauncher.Launch(options);
		}

		/**
			Open directions to a destination.

			When `origin` is `null`, directions start at the current location.
		*/
		public static Future<MapLaunchStatus> LaunchDirections(
			MapLocation origin, MapLocation destination)
		{
			return MapsLauncher.LaunchDirections(origin, destination);
		}

		/** Open directions using the given travel mode. */
		public static Future<MapLaunchStatus> LaunchDirections(
			MapLocation origin, MapLocation destination, MapTravelMode mode)
		{
			return MapsLauncher.LaunchDirections(origin, destination, mode);
		}

		public static void LaunchEmail(string to, string carbonCopy, string blindCarbonCopy, string subject, string message)
		{
			EmailLauncher.LaunchEmail(to, carbonCopy, blindCarbonCopy, subject, message);
		}

		/** Whether the platform can launch an email application. */
		public static bool IsEmailAvailable()
		{
			return EmailLauncher.IsAvailable();
		}

		/**
			Compose an email using the native capabilities of the platform.

			The returned future resolves to `Opened`, `Sent`, `Saved` or `Cancelled`
			and rejects with a user-facing message when the message cannot be
			launched.
		*/
		public static Future<EmailLaunchStatus> LaunchEmail(EmailMessage message)
		{
			return EmailLauncher.Launch(message);
		}

		public static void LaunchInAppBrowser(string url)
		{
			InAppBrowserLauncher.LaunchInAppBrowser(url);
		}

		public static void LaunchInAppBrowser(string url, InAppBrowserOptions options)
		{
			InAppBrowserLauncher.LaunchInAppBrowser(url, options);
		}
	}
}
