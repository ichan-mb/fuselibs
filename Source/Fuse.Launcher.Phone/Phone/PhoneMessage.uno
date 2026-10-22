namespace Fuse
{
	/**
		The result of a successful phone or SMS launch.

		`Opened` means the platform handed the request to a phone or messaging
		application. `Sent` and `Cancelled` are only reported by platforms that
		provide an in-app composer. Failures are reported as a rejected
		`Future` / `Promise`.
	*/
	public enum PhoneLaunchStatus
	{
		Opened,
		Sent,
		Cancelled
	}

	/**
		How a phone number should be opened.

		`Dial` opens the dialer with the number filled in and lets the user
		confirm the call. `Call` asks the platform to place the call directly;
		on Android this requires the `CALL_PHONE` permission, and when it is
		denied the launch falls back to `Dial`. On iOS both modes open the
		dialer, because the platform does not allow an app to place a call
		without user confirmation.
	*/
	public enum PhoneCallMode
	{
		Dial,
		Call
	}

	/** Describes a phone call to launch. */
	public sealed class PhoneCallOptions
	{
		/** The number to call. */
		public string Number { get; set; }

		/**
			Whether to open the dialer or place the call directly.

			Defaults to `Dial`, which does not require any permissions.
		*/
		public PhoneCallMode Mode { get; set; }

		/**
			An Android package to target, for example `"com.android.dialer"`.

			If the package is not installed the launch falls back to the default
			dialer.
		*/
		public string AndroidPackage { get; set; }

		/**
			Launch a FaceTime call instead of a phone call.

			iOS only. `Number` may be a phone number or an Apple ID email
			address. Rejects on other platforms.
		*/
		public bool FaceTime { get; set; }

		/**
			Launch a FaceTime audio call instead of a FaceTime video call.

			iOS only. Implies `FaceTime`.
		*/
		public bool FaceTimeAudioOnly { get; set; }
	}

	/** Describes an SMS message to compose. */
	public sealed class SmsMessage
	{
		/** The recipient numbers. */
		public string[] Recipients { get; set; }

		/** The message body. */
		public string Body { get; set; }

		/**
			The message subject.

			Requires the iOS in-app composer. Ignored on Android.
		*/
		public string Subject { get; set; }

		/**
			File paths to attach.

			Requires the iOS in-app composer and iOS 14 or later. Ignored on
			Android.
		*/
		public string[] Attachments { get; set; }

		/**
			Use the iOS in-app composer instead of the `sms:` link.

			This is automatically enabled when `Subject` or `Attachments` is set.
			The composer reports `Sent` and `Cancelled`; the `sms:` link only
			reports `Opened`. Requires a device that can send text messages.
		*/
		public bool PreferInAppComposer { get; set; }

		/**
			An Android package to target, for example
			`"com.google.android.apps.messaging"`.

			If the package is not installed the launch falls back to the default
			messaging application or chooser.
		*/
		public string AndroidPackage { get; set; }

		/**
			The title of the Android chooser shown when no `AndroidPackage` is
			set.

			Leave empty to open the default messaging application directly.
		*/
		public string ChooserTitle { get; set; }
	}
}
