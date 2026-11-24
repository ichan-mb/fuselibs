using Uno;
using Uno.Threading;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.LauncherImpl
{
	[ForeignInclude(Language.Java,
					"android.app.Activity",
					"com.fuse.launcher.interapp.InterAppLauncherHelper")]
	internal extern(Android) static class InterAppPlatformAndroid
	{
		public static bool CanOpenUri(string uri)
		{
			return CanOpenUriNative(uri);
		}

		public static bool CanLaunchApp(string applicationId)
		{
			return CanLaunchAppNative(applicationId);
		}

		public static void LaunchUri(string uri, InterAppLaunchOptions options,
			Action onOpened, Action<string> onError)
		{
			if (options == null)
				options = new InterAppLaunchOptions();

			LaunchUriNative(
				uri,
				options.AndroidPackage,
				options.AndroidClassName,
				options.MimeType,
				options.AndroidFlags,
				InterAppUriHelper.FlattenExtras(options.AndroidExtras),
				onOpened,
				onError);
		}

		public static void LaunchApp(string applicationId, InterAppLaunchOptions options,
			Action onOpened, Action<string> onError)
		{
			if (options == null)
				options = new InterAppLaunchOptions();

			LaunchAppNative(
				applicationId,
				options.AndroidFlags,
				InterAppUriHelper.FlattenExtras(options.AndroidExtras),
				onOpened,
				onError);
		}

		public static void OpenSettings(Action onOpened, Action<string> onError)
		{
			OpenSettingsNative(onOpened, onError);
		}

		[Foreign(Language.Java)]
		static bool CanOpenUriNative(string uri)
		@{
			android.app.Activity activity = com.fuse.Activity.getRootActivity();
			return com.fuse.launcher.interapp.InterAppLauncherHelper.isUriAvailable(activity, uri);
		@}

		[Foreign(Language.Java)]
		static bool CanLaunchAppNative(string applicationId)
		@{
			android.app.Activity activity = com.fuse.Activity.getRootActivity();
			return com.fuse.launcher.interapp.InterAppLauncherHelper.isAppAvailable(activity, applicationId);
		@}

		[Foreign(Language.Java)]
		static void LaunchUriNative(string uri, string packageName, string className,
			string mimeType, string[] flags, string[] extras,
			Action onOpened, Action<string> onError)
		@{
			android.app.Activity activity = com.fuse.Activity.getRootActivity();
			com.fuse.launcher.interapp.InterAppLauncherHelper.launchUri(
				activity,
				uri,
				packageName,
				className,
				mimeType,
				flags != null ? flags.copyArray() : null,
				extras != null ? extras.copyArray() : null,
				onOpened,
				onError);
		@}

		[Foreign(Language.Java)]
		static void LaunchAppNative(string applicationId, string[] flags, string[] extras,
			Action onOpened, Action<string> onError)
		@{
			android.app.Activity activity = com.fuse.Activity.getRootActivity();
			com.fuse.launcher.interapp.InterAppLauncherHelper.launchApp(
				activity,
				applicationId,
				flags != null ? flags.copyArray() : null,
				extras != null ? extras.copyArray() : null,
				onOpened,
				onError);
		@}

		[Foreign(Language.Java)]
		static void OpenSettingsNative(Action onOpened, Action<string> onError)
		@{
			android.app.Activity activity = com.fuse.Activity.getRootActivity();
			com.fuse.launcher.interapp.InterAppLauncherHelper.openSettings(
				activity, onOpened, onError);
		@}
	}
}
