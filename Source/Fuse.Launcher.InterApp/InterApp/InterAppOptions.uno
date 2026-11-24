using Uno.Collections;

namespace Fuse
{
	/**
		The result of a successful inter-app launch.

		`Opened` means the platform handed the request to another application.
		Failures are reported as a rejected `Future` / `Promise`.
	*/
	public enum InterAppLaunchStatus
	{
		Opened
	}

	/**
		Describes a URI or application to launch.

		Use `Uri` for the target. On Android a URI can be any intent data URI
		(for example `https://...`, `tel:...` or `myapp://...`). When
		`LaunchApp` is used with an Android package id, such as
		`"com.example.app"`, the package is launched directly.
	*/
	public sealed class InterAppLaunchOptions
	{
		/**
			The URI to open, or an Android application id when passed to
			`LaunchApp`.
		*/
		public string Uri { get; set; }

		/**
			An Android package to target, for example `"com.example.app"`.

			If the package is not installed the launch falls back to the
			default application that handles `Uri`.

			Ignored on iOS, where the URI scheme selects the application.
		*/
		public string AndroidPackage { get; set; }

		/**
			An explicit Android activity class to target inside `AndroidPackage`,
			for example `"com.example.app.MainActivity"`.

			Requires `AndroidPackage`. Ignored on iOS.
		*/
		public string AndroidClassName { get; set; }

		/**
			Android intent flags to add, for example `"newTask"` or `"clearTop"`.

			See `FuseJS/InterApp` documentation for the supported flag names.
			Ignored on iOS.
		*/
		public string[] AndroidFlags { get; set; }

		/**
			A MIME type for the intent data, for example `"text/plain"`.

			When set, the Android intent uses `setDataAndType` instead of
			`setData`. Ignored on iOS.
		*/
		public string MimeType { get; set; }

		/**
			String extras added to the Android intent.

			Use the platform extra name as the key, for example
			`"android.intent.extra.SUBJECT"`. Ignored on iOS.
		*/
		public Dictionary<string, string> AndroidExtras { get; set; }

		/**
			Only open the URI when it is a universal link.

			iOS only. When `false`, regular URL schemes and universal links are
			both accepted.
		*/
		public bool UniversalLinksOnly { get; set; }

		/**
			A store URI to open when the requested application or URI cannot be
			opened, for example
			`"https://play.google.com/store/apps/details?id=com.example.app"` or
			`"https://apps.apple.com/app/id123456789"`.

			Leave empty to report the failure instead. The legacy
			`LaunchApp(string)` form still falls back to the Play Store when the
			target is an Android package id.
		*/
		public string AppStoreUri { get; set; }

		/** Create a copy of these options. */
		public InterAppLaunchOptions Clone()
		{
			return new InterAppLaunchOptions
			{
				Uri = Uri,
				AndroidPackage = AndroidPackage,
				AndroidClassName = AndroidClassName,
				AndroidFlags = AndroidFlags,
				MimeType = MimeType,
				AndroidExtras = AndroidExtras,
				UniversalLinksOnly = UniversalLinksOnly,
				AppStoreUri = AppStoreUri
			};
		}
	}

	/**
		Describes an application store page to open.

		Provide `StoreUri` to open an explicit store URL. Otherwise set
		`AndroidPackage` on Android or `AppStoreId` on iOS.
	*/
	public sealed class InterAppStoreOptions
	{
		/**
			The Android package whose store page should be opened, for example
			`"com.example.app"`.
		*/
		public string AndroidPackage { get; set; }

		/**
			The iOS App Store id, with or without the `id` prefix, for example
			`"123456789"` or `"id123456789"`.
		*/
		public string AppStoreId { get; set; }

		/**
			An explicit store URI that overrides the platform defaults.

			Use this to target a specific store or to open a web store page.
		*/
		public string StoreUri { get; set; }
	}
}
