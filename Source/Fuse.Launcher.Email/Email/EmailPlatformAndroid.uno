using Uno;
using Uno.Threading;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.LauncherImpl
{
	[ForeignInclude(Language.Java,
					"android.content.Intent",
					"android.net.Uri",
					"android.app.Activity",
					"com.fuse.launcher.email.EmailLauncherHelper")]
	internal extern(Android) static class EmailPlatformAndroid
	{
		public static bool IsAvailable()
		{
			return IsAvailableNative();
		}

		public static void Launch(EmailMessage message, Promise<EmailLaunchStatus> promise)
		{
			LaunchNative(
				EmailUriHelper.BuildUri(message),
				EmailUriHelper.Normalize(message.To),
				EmailUriHelper.Normalize(message.CarbonCopy),
				EmailUriHelper.Normalize(message.BlindCarbonCopy),
				message.Subject,
				message.Body,
				message.HtmlBody,
				message.Attachments,
				message.ChooserTitle,
				message.AndroidPackage,
				() => promise.Resolve(EmailLaunchStatus.Opened),
				error => promise.Reject(new Exception(error)));
		}

		[Foreign(Language.Java)]
		static bool IsAvailableNative()
		@{
			android.app.Activity activity = com.fuse.Activity.getRootActivity();
			return com.fuse.launcher.email.EmailLauncherHelper.isAvailable(activity);
		@}

		[Foreign(Language.Java)]
		static void LaunchNative(string mailtoUri, string[] to, string[] cc, string[] bcc,
			string subject, string body, string htmlBody, string[] attachments,
			string chooserTitle, string packageName,
			Action onOpened, Action<string> onError)
		@{
			android.app.Activity activity = com.fuse.Activity.getRootActivity();
			com.fuse.launcher.email.EmailLauncherHelper.launch(
				activity,
				mailtoUri,
				to != null ? to.copyArray() : null,
				cc != null ? cc.copyArray() : null,
				bcc != null ? bcc.copyArray() : null,
				subject,
				body,
				htmlBody,
				attachments != null ? attachments.copyArray() : null,
				chooserTitle,
				packageName,
				onOpened,
				onError);
		@}
	}
}
