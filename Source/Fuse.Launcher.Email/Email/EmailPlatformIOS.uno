using Uno;
using Uno.Threading;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.LauncherImpl
{
	[ForeignInclude(Language.ObjC, "Email/EmailUI.h")]
	internal extern(iOS) static class EmailPlatformIOS
	{
		public static bool IsAvailable()
		{
			return IsAvailableNative();
		}

		public static void Launch(EmailMessage message, Promise<EmailLaunchStatus> promise)
		{
			var useInApp = message.PreferInAppComposer
				|| (message.Attachments != null && message.Attachments.Length > 0)
				|| !String.IsNullOrEmpty(message.HtmlBody);

			LaunchNative(
				EmailUriHelper.BuildUri(message),
				EmailUriHelper.Normalize(message.To),
				EmailUriHelper.Normalize(message.CarbonCopy),
				EmailUriHelper.Normalize(message.BlindCarbonCopy),
				message.Subject,
				message.Body,
				message.HtmlBody,
				message.Attachments,
				useInApp,
				status => promise.Resolve(ParseStatus(status)),
				error => promise.Reject(new Exception(error)));
		}

		static EmailLaunchStatus ParseStatus(string status)
		{
			if (status == "sent")
				return EmailLaunchStatus.Sent;
			if (status == "saved")
				return EmailLaunchStatus.Saved;
			if (status == "cancelled")
				return EmailLaunchStatus.Cancelled;
			return EmailLaunchStatus.Opened;
		}

		[Foreign(Language.ObjC)]
		static bool IsAvailableNative()
		@{
			return FuseEmailIsAvailable();
		@}

		[Foreign(Language.ObjC)]
		static void LaunchNative(string mailtoUri, string[] to, string[] cc, string[] bcc,
			string subject, string body, string htmlBody, string[] attachments, bool useInApp,
			Action<string> onComplete, Action<string> onError)
		@{
			dispatch_async(dispatch_get_main_queue(), ^{
				FuseEmailLaunch(
					mailtoUri,
					to != nil ? [to copyArray] : nil,
					cc != nil ? [cc copyArray] : nil,
					bcc != nil ? [bcc copyArray] : nil,
					subject,
					body,
					htmlBody,
					attachments != nil ? [attachments copyArray] : nil,
					useInApp,
					^(NSString* status) { onComplete(status); },
					^(NSString* error) { onError(error != nil ? error : @"Could not compose email."); });
			});
		@}
	}
}
