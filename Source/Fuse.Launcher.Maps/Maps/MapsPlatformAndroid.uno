using Uno;
using Uno.Threading;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.LauncherImpl
{
	[ForeignInclude(Language.Java,
					"android.app.Activity",
					"com.fuse.launcher.maps.MapsLauncherHelper")]
	internal extern(Android) static class MapsPlatformAndroid
	{
		public static bool IsAvailable()
		{
			return IsAvailableNative();
		}

		public static void Launch(MapLaunchOptions options, Promise<MapLaunchStatus> promise)
		{
			var primaryUri = MapsUriHelper.HasDestination(options)
				? MapsUriHelper.BuildAndroidDirectionsUri(options)
				: MapsUriHelper.BuildGeoUri(options);

			var webFallbackUri = options.UseWebFallback
				? MapsUriHelper.BuildGoogleMapsUrl(options)
				: null;

			// Avoid retrying the same URL when the primary URI is already
			// the web directions URL.
			if (webFallbackUri == primaryUri)
				webFallbackUri = null;

			LaunchNative(
				primaryUri,
				webFallbackUri,
				options.AndroidPackage,
				() => promise.Resolve(MapLaunchStatus.Opened),
				error => promise.Reject(new Exception(error)));
		}

		[Foreign(Language.Java)]
		static bool IsAvailableNative()
		@{
			android.app.Activity activity = com.fuse.Activity.getRootActivity();
			return com.fuse.launcher.maps.MapsLauncherHelper.isAvailable(activity);
		@}

		[Foreign(Language.Java)]
		static void LaunchNative(string uri, string webFallbackUri, string packageName,
			Action onOpened, Action<string> onError)
		@{
			android.app.Activity activity = com.fuse.Activity.getRootActivity();
			com.fuse.launcher.maps.MapsLauncherHelper.launch(
				activity, uri, webFallbackUri, packageName, onOpened, onError);
		@}
	}
}
