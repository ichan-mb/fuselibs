namespace Fuse
{
	/**
		The result of a successful email launch.

		`Opened` means the platform handed the message to an email application.
		`Sent`, `Saved` and `Cancelled` are only reported by the iOS in-app
		composer. Failures are reported as a rejected `Future` / `Promise`.
	*/
	public enum EmailLaunchStatus
	{
		Opened,
		Sent,
		Saved,
		Cancelled
	}

	/**
		Describes an email to compose.

		Recipients and attachments are arrays. Comma- and semicolon-separated
		strings are also accepted and normalized for backwards compatibility.

		Platform-specific properties are ignored on platforms that do not
		support them.
	*/
	public sealed class EmailMessage
	{
		/** The recipient addresses. */
		public string[] To { get; set; }

		/** The carbon copy addresses. */
		public string[] CarbonCopy { get; set; }

		/** The blind carbon copy addresses. */
		public string[] BlindCarbonCopy { get; set; }

		/** The subject line. */
		public string Subject { get; set; }

		/** The plain text body. */
		public string Body { get; set; }

		/**
			An HTML body.

			Android passes this to clients that support `EXTRA_HTML_TEXT`.
			On iOS this requires the in-app composer and a configured Mail
			account. `Body` is used as the plain text fallback when possible.
		*/
		public string HtmlBody { get; set; }

		/** File paths to attach. `file://` paths and `content://` URIs are accepted on Android. */
		public string[] Attachments { get; set; }

		/** The title of the Android chooser shown for messages with attachments or HTML. */
		public string ChooserTitle { get; set; }

		/**
			An Android package to target, for example `"com.google.android.gm"`.

			If the package is not installed the launch falls back to the regular
			chooser.
		*/
		public string AndroidPackage { get; set; }

		/**
			Use the iOS in-app composer instead of `mailto:`.

			This is automatically enabled when `Attachments` or `HtmlBody` is set.
			It requires a configured Mail account; otherwise the launch falls back
			to `mailto:` when that is possible. iOS only.
		*/
		public bool PreferInAppComposer { get; set; }
	}
}
