using Uno;
using Uno.Threading;
using Uno.Compiler.ExportTargetInterop;
using Fuse.Android.Permissions;

namespace Fuse.LauncherImpl
{
	[ForeignInclude(Language.Java,
					"android.app.Activity",
					"com.fuse.launcher.phone.PhoneLauncherHelper")]
	internal extern(Android) static class PhonePlatformAndroid
	{
		public static bool IsCallAvailable()
		{
			return IsCallAvailableNative();
		}

		public static bool IsSmsAvailable()
		{
			return IsSmsAvailableNative();
		}

		public static void LaunchCall(PhoneCallOptions options, Promise<PhoneLaunchStatus> promise)
		{
			if (options.FaceTime || options.FaceTimeAudioOnly)
			{
				promise.Reject(new Exception("FaceTime is not available on Android."));
				return;
			}

			var uri = PhoneUriHelper.PhoneNumberToTelUri(options.Number);

			if (options.Mode == PhoneCallMode.Call)
			{
				// Placing the call directly requires CALL_PHONE. Fall back to
				// the dialer when the permission is denied or unavailable.
				Permissions.Request(Permissions.Android.CALL_PHONE).Then(
					p => LaunchCallNative(uri, true, options.AndroidPackage,
						() => promise.Resolve(PhoneLaunchStatus.Opened),
						error => promise.Reject(new Exception(error))),
					e => LaunchCallNative(uri, false, options.AndroidPackage,
						() => promise.Resolve(PhoneLaunchStatus.Opened),
						error => promise.Reject(new Exception(error))));
			}
			else
			{
				LaunchCallNative(uri, false, options.AndroidPackage,
					() => promise.Resolve(PhoneLaunchStatus.Opened),
					error => promise.Reject(new Exception(error)));
			}
		}

		public static void LaunchSms(SmsMessage message, Promise<PhoneLaunchStatus> promise)
		{
			LaunchSmsNative(
				PhoneUriHelper.PhoneNumbersToSmstoUri(message.Recipients),
				message.Body,
				message.ChooserTitle,
				message.AndroidPackage,
				() => promise.Resolve(PhoneLaunchStatus.Opened),
				error => promise.Reject(new Exception(error)));
		}

		[Foreign(Language.Java)]
		static bool IsCallAvailableNative()
		@{
			android.app.Activity activity = com.fuse.Activity.getRootActivity();
			return com.fuse.launcher.phone.PhoneLauncherHelper.isCallAvailable(activity);
		@}

		[Foreign(Language.Java)]
		static bool IsSmsAvailableNative()
		@{
			android.app.Activity activity = com.fuse.Activity.getRootActivity();
			return com.fuse.launcher.phone.PhoneLauncherHelper.isSmsAvailable(activity);
		@}

		[Foreign(Language.Java)]
		static void LaunchCallNative(string uri, bool directCall, string packageName,
			Action onOpened, Action<string> onError)
		@{
			android.app.Activity activity = com.fuse.Activity.getRootActivity();
			com.fuse.launcher.phone.PhoneLauncherHelper.launchCall(
				activity, uri, directCall, packageName, onOpened, onError);
		@}

		[Foreign(Language.Java)]
		static void LaunchSmsNative(string uri, string body, string chooserTitle, string packageName,
			Action onOpened, Action<string> onError)
		@{
			android.app.Activity activity = com.fuse.Activity.getRootActivity();
			com.fuse.launcher.phone.PhoneLauncherHelper.launchSms(
				activity, uri, body, chooserTitle, packageName, onOpened, onError);
		@}
	}
}
