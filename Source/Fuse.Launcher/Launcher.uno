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

		/** Whether the platform can open the given URI. */
		public static bool CanOpenUri(string uri)
		{
			return InterAppLauncher.CanOpenUri(uri);
		}

		/**
			Whether the platform can launch the given application.

			On Android pass a package name. On iOS pass a URI scheme.
		*/
		public static bool CanLaunchApp(string applicationId)
		{
			return InterAppLauncher.CanLaunchApp(applicationId);
		}

		/**
			Open a URI.

			The returned future resolves to `InterAppLaunchStatus.Opened` once
			the platform hands the request to another application, and rejects
			with a user-facing message when it cannot.
		*/
		public static Future<InterAppLaunchStatus> LaunchUri(string uri)
		{
			return InterAppLauncher.LaunchUri(uri);
		}

		/**
			Open a URI with explicit launch options.

			The returned future resolves to `InterAppLaunchStatus.Opened` once
			the platform hands the request to another application, and rejects
			with a user-facing message when it cannot.
		*/
		public static Future<InterAppLaunchStatus> LaunchUri(InterAppLaunchOptions options)
		{
			return InterAppLauncher.LaunchUri(options);
		}

		/**
			Launch an app by URI, or on Android by package id.

			This legacy overload does not report the launch result. Use
			`LaunchApp(InterAppLaunchOptions)` to observe it.
		*/
		public static void LaunchApp(string uri, string appStoreUri = null)
		{
			InterAppLauncher.LaunchApp(uri, appStoreUri);
		}

		/**
			Launch an app by URI, or on Android by package id.

			The returned future resolves to `InterAppLaunchStatus.Opened` once
			the platform hands the request to another application, and rejects
			with a user-facing message when it cannot.
		*/
		public static Future<InterAppLaunchStatus> LaunchApp(InterAppLaunchOptions options)
		{
			return InterAppLauncher.LaunchApp(options);
		}

		/**
			Launch an Android application by package id.

			Unlike `LaunchApp`, this never treats the argument as a URI.
			Rejects on iOS, which has no API for launching an app by bundle id.
		*/
		public static Future<InterAppLaunchStatus> LaunchPackage(
			string applicationId, InterAppLaunchOptions options = null)
		{
			return InterAppLauncher.LaunchPackage(applicationId, options);
		}

		/**
			Open the operating system's settings page for this application.

			The returned future resolves to `InterAppLaunchStatus.Opened` once the
			settings page is shown, and rejects with a user-facing message when it
			cannot be opened.
		*/
		public static Future<InterAppLaunchStatus> OpenSettings()
		{
			return InterAppLauncher.OpenSettings();
		}

		/**
			Open the store page for an application.

			The returned future resolves to `InterAppLaunchStatus.Opened` once the
			store page is shown, and rejects with a user-facing message when it
			cannot be opened.
		*/
		public static Future<InterAppLaunchStatus> OpenStore(InterAppStoreOptions options)
		{
			return InterAppLauncher.OpenStore(options);
		}

		/** Whether the platform can launch a phone call. */
		public static bool CanCall()
		{
			return PhoneLauncher.CanCall();
		}

		/** Whether the platform can compose an SMS message. */
		public static bool CanSendSms()
		{
			return PhoneLauncher.CanSendSms();
		}

		/** Whether the platform can launch a FaceTime call. */
		public static bool CanFaceTime()
		{
			return PhoneLauncher.CanFaceTime();
		}

		public static void LaunchCall(string phoneNumber)
		{
			PhoneLauncher.LaunchCall(phoneNumber);
		}

		/**
			Launch a phone call.

			The returned future resolves to `PhoneLaunchStatus.Opened` once the
			platform hands the request to a phone application, and rejects with a
			user-facing message when it cannot.
		*/
		public static Future<PhoneLaunchStatus> LaunchCall(PhoneCallOptions options)
		{
			return PhoneLauncher.LaunchCall(options);
		}

		public static void LaunchSms(string phoneNumber, string body)
		{
			PhoneLauncher.LaunchSms(phoneNumber, body);
		}

		/**
			Compose an SMS message.

			The returned future resolves to `PhoneLaunchStatus.Opened` after the
			platform hands the message to a messaging application, or to
			`PhoneLaunchStatus.Sent` / `PhoneLaunchStatus.Cancelled` when the iOS
			in-app composer is used. It rejects with a user-facing message when
			the message cannot be launched.
		*/
		public static Future<PhoneLaunchStatus> LaunchSms(SmsMessage message)
		{
			return PhoneLauncher.LaunchSms(message);
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
