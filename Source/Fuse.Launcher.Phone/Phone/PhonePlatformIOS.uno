using Uno;
using Uno.Threading;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.LauncherImpl
{
	[ForeignInclude(Language.ObjC, "Phone/PhoneUI.h")]
	internal extern(iOS) static class PhonePlatformIOS
	{
		public static bool IsCallAvailable()
		{
			return CanOpenUrlNative("tel:");
		}

		public static bool IsSmsAvailable()
		{
			return CanSendSmsNative();
		}

		public static bool IsFaceTimeAvailable()
		{
			return CanOpenUrlNative("facetime:");
		}

		public static void LaunchCall(PhoneCallOptions options, Promise<PhoneLaunchStatus> promise)
		{
			// iOS does not expose an API for placing a call without user
			// confirmation, so both modes open the dialer.
			var useFaceTime = options.FaceTime || options.FaceTimeAudioOnly;
			var uri = useFaceTime
				? PhoneUriHelper.PhoneNumberToFaceTimeUri(options.Number, options.FaceTimeAudioOnly)
				: PhoneUriHelper.PhoneNumberToTelUri(options.Number);

			LaunchCallNative(
				uri,
				() => promise.Resolve(PhoneLaunchStatus.Opened),
				error => promise.Reject(new Exception(error)));
		}

		public static void LaunchSms(SmsMessage message, Promise<PhoneLaunchStatus> promise)
		{
			var useInApp = message.PreferInAppComposer
				|| !String.IsNullOrEmpty(message.Subject)
				|| (message.Attachments != null && message.Attachments.Length > 0);

			LaunchSmsNative(
				PhoneUriHelper.PhoneNumbersToIosSmsUri(message.Recipients, message.Body),
				message.Recipients,
				message.Body,
				message.Subject,
				message.Attachments,
				useInApp,
				status => promise.Resolve(ParseStatus(status)),
				error => promise.Reject(new Exception(error)));
		}

		static PhoneLaunchStatus ParseStatus(string status)
		{
			if (status == "sent")
				return PhoneLaunchStatus.Sent;
			if (status == "cancelled")
				return PhoneLaunchStatus.Cancelled;
			return PhoneLaunchStatus.Opened;
		}

		[Foreign(Language.ObjC)]
		static bool CanOpenUrlNative(string uri)
		@{
			return FusePhoneCanOpenUrl(uri);
		@}

		[Foreign(Language.ObjC)]
		static bool CanSendSmsNative()
		@{
			return FusePhoneCanSendSms();
		@}

		[Foreign(Language.ObjC)]
		static void LaunchCallNative(string uri, Action onOpened, Action<string> onError)
		@{
			FusePhoneOpenUrl(uri, onOpened, onError);
		@}

		[Foreign(Language.ObjC)]
		static void LaunchSmsNative(string smsUri, string[] recipients, string body,
			string subject, string[] attachments, bool useInApp,
			Action<string> onComplete, Action<string> onError)
		@{
			FusePhoneLaunchSms(
				smsUri,
				recipients != nil ? [recipients copyArray] : nil,
				body,
				subject,
				attachments != nil ? [attachments copyArray] : nil,
				useInApp,
				onComplete,
				onError);
		@}
	}
}
