using Uno;
using Uno.Threading;

namespace Fuse.LauncherImpl
{
	/**
		Launches the default email application.

		`Launch` composes a message using the native email capabilities of the
		platform and returns a `Future<EmailLaunchStatus>`. Failures, including
		the case where no email application is available, are reported as a
		rejected future.
	*/
	public static class EmailLauncher
	{
		/** Whether the platform can launch an email application. */
		public static bool IsAvailable()
		{
			if defined(Android)
				return EmailPlatformAndroid.IsAvailable();
			else if defined(iOS)
				return EmailPlatformIOS.IsAvailable();
			else
				return false;
		}

		/** Compose an email using the native email capabilities of the platform. */
		public static Future<EmailLaunchStatus> Launch(EmailMessage message)
		{
			var promise = new Promise<EmailLaunchStatus>();

			if (message == null)
			{
				promise.Reject(new ArgumentNullException(nameof(message)));
				return promise;
			}

			if defined(Android)
			{
				EmailPlatformAndroid.Launch(message, promise);
			}
			else if defined(iOS)
			{
				EmailPlatformIOS.Launch(message, promise);
			}
			else
			{
				promise.Reject(new Exception("Email is not supported on this platform."));
			}

			return promise;
		}

		/**
			Launch the email application with a template.

			This legacy, fire-and-forget overload keeps the original signature.
			Use `Launch` to observe the result or to provide attachments and HTML.
		*/
		public static void LaunchEmail(string to, string carbonCopy,
			string blindCarbonCopy, string subject, string message)
		{
			if (to == null)
				throw new ArgumentNullException(nameof(to));

			if defined(Android || iOS)
			{
				var email = new EmailMessage
				{
					To = EmailUriHelper.FromString(to),
					CarbonCopy = EmailUriHelper.FromString(carbonCopy),
					BlindCarbonCopy = EmailUriHelper.FromString(blindCarbonCopy),
					Subject = subject,
					Body = message
				};

				Launch(email).Catch(e => { });
			}
		}
	}
}
