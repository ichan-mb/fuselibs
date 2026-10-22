using Uno;
using Uno.Threading;

namespace Fuse.LauncherImpl
{
	public static class PhoneLauncher
	{
		/** Whether the platform can launch a phone call. */
		public static bool CanCall()
		{
			if defined(Android)
				return PhonePlatformAndroid.IsCallAvailable();
			else if defined(iOS)
				return PhonePlatformIOS.IsCallAvailable();
			else
				return false;
		}

		/** Whether the platform can compose an SMS message. */
		public static bool CanSendSms()
		{
			if defined(Android)
				return PhonePlatformAndroid.IsSmsAvailable();
			else if defined(iOS)
				return PhonePlatformIOS.IsSmsAvailable();
			else
				return false;
		}

		/** Whether the platform can launch a FaceTime call. */
		public static bool CanFaceTime()
		{
			if defined(iOS)
				return PhonePlatformIOS.IsFaceTimeAvailable();
			else
				return false;
		}

		/**
			Launch a phone call.

			The returned future resolves to `PhoneLaunchStatus.Opened` once the
			platform hands the request to a phone application, and rejects with
			a user-facing message when it cannot.
		*/
		public static Future<PhoneLaunchStatus> LaunchCall(PhoneCallOptions options)
		{
			var promise = new Promise<PhoneLaunchStatus>();

			if (options == null)
			{
				promise.Reject(new ArgumentNullException(nameof(options)));
				return promise;
			}

			if (string.IsNullOrEmpty(options.Number) || string.IsNullOrEmpty(options.Number.Trim()))
			{
				promise.Reject(new Exception("A phone number is required."));
				return promise;
			}

			try
			{
				if defined(Android)
					PhonePlatformAndroid.LaunchCall(options, promise);
				else if defined(iOS)
					PhonePlatformIOS.LaunchCall(options, promise);
				else
					promise.Reject(new Exception("Phone calls are not supported on this platform."));
			}
			catch (Exception e)
			{
				promise.Reject(e);
			}

			return promise;
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
			var promise = new Promise<PhoneLaunchStatus>();

			if (message == null)
			{
				promise.Reject(new ArgumentNullException(nameof(message)));
				return promise;
			}

			if (message.Recipients == null || message.Recipients.Length == 0)
			{
				promise.Reject(new Exception("At least one recipient is required."));
				return promise;
			}

			for (int i = 0; i < message.Recipients.Length; i++)
			{
				if (string.IsNullOrEmpty(message.Recipients[i]) ||
					string.IsNullOrEmpty(message.Recipients[i].Trim()))
				{
					promise.Reject(new Exception("Recipients must not be empty."));
					return promise;
				}
			}

			try
			{
				if defined(Android)
					PhonePlatformAndroid.LaunchSms(message, promise);
				else if defined(iOS)
					PhonePlatformIOS.LaunchSms(message, promise);
				else
					promise.Reject(new Exception("SMS is not supported on this platform."));
			}
			catch (Exception e)
			{
				promise.Reject(e);
			}

			return promise;
		}

		/**
			Launch the phone application with a number.

			This legacy, fire-and-forget overload keeps the original signature.
			It opens the dialer; use `LaunchCall(PhoneCallOptions)` to place the
			call directly or to observe the result.
		*/
		public static void LaunchCall(string phoneNumber)
		{
			LaunchCall(new PhoneCallOptions
			{
				Number = phoneNumber,
				Mode = PhoneCallMode.Dial
			}).Catch(e => { });
		}

		/**
			Launch the messaging application with a number and body.

			This legacy, fire-and-forget overload keeps the original signature.
			Use `LaunchSms(SmsMessage)` to observe the result.
		*/
		public static void LaunchSms(string phoneNumber, string body)
		{
			LaunchSms(new SmsMessage
			{
				Recipients = new[] { phoneNumber },
				Body = body
			}).Catch(e => { });
		}
	}
}
