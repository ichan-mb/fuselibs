using Uno;
using Uno.Compiler.ExportTargetInterop;
using Android;

namespace Fuse
{
	public enum InAppBrowserDismissButtonStyle
	{
		Done,
		Close,
		Cancel
	}

	public enum InAppBrowserPresentationStyle
	{
		Automatic,
		FullScreen,
		PageSheet
	}

	// Values must match CustomTabsIntent.COLOR_SCHEME_* in androidx.browser.
	public enum InAppBrowserColorScheme
	{
		System,
		Light,
		Dark
	}

	// Values must match CustomTabsIntent.SHARE_STATE_* in androidx.browser.
	public enum InAppBrowserShareState
	{
		Default,
		On,
		Off
	}

	public enum InAppBrowserSheetSize
	{
		Default,
		Medium,
		Large
	}

	/**
		Options for opening a URL in the in-app browser.

		Platform-specific options are ignored on platforms that do not support them.
	*/
	public sealed class InAppBrowserOptions
	{
		public InAppBrowserOptions()
		{
			CollapseChromeOnScroll = true;
			BookmarksButtonEnabled = true;
			DownloadButtonEnabled = true;
			Animated = true;
			FallbackToExternalBrowser = true;
		}

		/**
			Open in reader mode when the page supports it.

			iOS only.
		*/
		public bool ReaderMode { get; set; }

		/**
			Collapse the browser chrome while scrolling.

			Defaults to `true`.
		*/
		public bool CollapseChromeOnScroll { get; set; }

		/**
			Background color of the browser toolbar as a hex string, for example `"#1E88E5"`.
		*/
		public string ToolbarColor { get; set; }

		/**
			Color of the browser controls as a hex string, for example `"#FFFFFF"`.

			iOS only.
		*/
		public string ControlTintColor { get; set; }

		/**
			Color of the Android navigation bar as a hex string.

			Android only.
		*/
		public string NavigationBarColor { get; set; }

		/**
			Color of the Android navigation bar divider as a hex string.

			Android only.
		*/
		public string NavigationBarDividerColor { get; set; }

		/**
			Toolbar background color used in dark mode as a hex string.

			Android only. iOS follows the system appearance.
		*/
		public string ToolbarColorDark { get; set; }

		/**
			Navigation bar color used in dark mode as a hex string.

			Android only.
		*/
		public string NavigationBarColorDark { get; set; }

		/**
			Navigation bar divider color used in dark mode as a hex string.

			Android only.
		*/
		public string NavigationBarDividerColorDark { get; set; }

		/**
			Force the browser to use the system, light or dark color scheme.
		*/
		public InAppBrowserColorScheme ColorScheme { get; set; }

		/**
			Whether the Android share menu item is shown.

			Android only. iOS always shows its share button.
		*/
		public InAppBrowserShareState ShareState { get; set; }

		/**
			Whether the Android bookmarks button is shown.

			Defaults to `true`. Android only.
		*/
		public bool BookmarksButtonEnabled { get; set; }

		/**
			Whether the Android download button is shown.

			Defaults to `true`. Android only.
		*/
		public bool DownloadButtonEnabled { get; set; }

		/**
			Show the page title in the toolbar.

			Android only.
		*/
		public bool ShowTitle { get; set; }

		/**
			Style of the dismiss button.

			iOS only.
		*/
		public InAppBrowserDismissButtonStyle DismissButtonStyle { get; set; }

		/**
			Presentation style of the browser.

			iOS only.
		*/
		public InAppBrowserPresentationStyle PresentationStyle { get; set; }

		/**
			Preferred height when the browser is presented as a bottom sheet.

			`Medium` is approximately half the screen and `Large` is a large sheet.
			`Default` keeps the platform's normal full-height presentation.
			On iOS, `SheetSize` is ignored when `PresentationStyle` is `FullScreen`.
			Requires iOS 15+.
		*/
		public InAppBrowserSheetSize SheetSize { get; set; }

		/**
			Animate the browser presentation.

			Defaults to `true`. iOS only.
		*/
		public bool Animated { get; set; }

		/**
			Open the URL in the normal browser when Custom Tabs is not available.

			Defaults to `true`. Android only.
		*/
		public bool FallbackToExternalBrowser { get; set; }
	}
}

namespace Fuse.LauncherImpl
{
	public static class InAppBrowserLauncher
	{
		public static void LaunchInAppBrowser(string url)
		{
			LaunchInAppBrowser(url, null);
		}

		public static void LaunchInAppBrowser(string url, InAppBrowserOptions options)
		{
			ValidateUrl(url);

			if (options == null)
				options = new InAppBrowserOptions();

			if defined(iOS)
				InAppBrowseriOSImpl.OpenUrl(url, options);
			if defined(Android)
				InAppBrowserAndroidImpl.OpenUrl(url, options);
		}

		internal static void ValidateUrl(string url)
		{
			if (url == null)
				throw new ArgumentNullException(nameof(url));

			if (url.Length == 0)
				throw new ArgumentException("URL must not be empty", nameof(url));

			Uno.Net.Http.Uri uri = null;
			try
			{
				uri = new Uno.Net.Http.Uri(url);
			}
			catch (Exception e)
			{
				throw new ArgumentException("Invalid URL: " + url + " (" + e.Message + ")");
			}

			if (uri.Scheme != "http" && uri.Scheme != "https")
				throw new ArgumentException("In-app browser only supports http and https URLs: " + url);

			if (string.IsNullOrEmpty(uri.Host))
				throw new ArgumentException("Invalid URL: " + url);
		}

		internal static bool TryGetColor(string color, out int argb)
		{
			argb = 0;

			if (string.IsNullOrEmpty(color))
				return false;

			float4 rgba;
			if (!Uno.Color.TryParse(color, out rgba))
				throw new ArgumentException("Invalid color: " + color);

			argb = (int)Uno.Color.ToArgb(rgba);
			return true;
		}
	}

	extern(iOS) class InAppBrowseriOSImpl
	{
		public static void OpenUrl(string url, InAppBrowserOptions options)
		{
			int barTintArgb;
			var hasBarTint = InAppBrowserLauncher.TryGetColor(options.ToolbarColor, out barTintArgb);

			int controlTintArgb;
			var hasControlTint = InAppBrowserLauncher.TryGetColor(options.ControlTintColor, out controlTintArgb);

			Safari.PresentSafari(
				url,
				options.ReaderMode,
				options.CollapseChromeOnScroll,
				options.Animated,
				hasBarTint,
				barTintArgb,
				hasControlTint,
				controlTintArgb,
				(int)options.DismissButtonStyle,
				(int)options.PresentationStyle,
				(int)options.SheetSize,
				(int)options.ColorScheme);
		}
	}

	extern(Android) class InAppBrowserAndroidImpl
	{
		public static void OpenUrl(string url, InAppBrowserOptions options)
		{
			int toolbarColorArgb;
			var hasToolbarColor = InAppBrowserLauncher.TryGetColor(options.ToolbarColor, out toolbarColorArgb);

			int navigationBarColorArgb;
			var hasNavigationBarColor = InAppBrowserLauncher.TryGetColor(options.NavigationBarColor, out navigationBarColorArgb);

			int navigationBarDividerColorArgb;
			var hasNavigationBarDividerColor = InAppBrowserLauncher.TryGetColor(options.NavigationBarDividerColor, out navigationBarDividerColorArgb);

			int toolbarColorDarkArgb;
			var hasToolbarColorDark = InAppBrowserLauncher.TryGetColor(options.ToolbarColorDark, out toolbarColorDarkArgb);

			int navigationBarColorDarkArgb;
			var hasNavigationBarColorDark = InAppBrowserLauncher.TryGetColor(options.NavigationBarColorDark, out navigationBarColorDarkArgb);

			int navigationBarDividerColorDarkArgb;
			var hasNavigationBarDividerColorDark = InAppBrowserLauncher.TryGetColor(options.NavigationBarDividerColorDark, out navigationBarDividerColorDarkArgb);

			var requestCode = ActivityUtils.AllocateRequestCode();

			// Android uses the browser's own animation; `Animated` is iOS only for now.
			Chrome.PresentChrome(
				url,
				options.ShowTitle,
				options.CollapseChromeOnScroll,
				hasToolbarColor,
				toolbarColorArgb,
				hasNavigationBarColor,
				navigationBarColorArgb,
				hasNavigationBarDividerColor,
				navigationBarDividerColorArgb,
				(int)options.ColorScheme,
				(int)options.ShareState,
				(int)options.SheetSize,
				options.BookmarksButtonEnabled,
				options.DownloadButtonEnabled,
				hasToolbarColorDark,
				toolbarColorDarkArgb,
				hasNavigationBarColorDark,
				navigationBarColorDarkArgb,
				hasNavigationBarDividerColorDark,
				navigationBarDividerColorDarkArgb,
				requestCode,
				options.FallbackToExternalBrowser);
		}
	}

	[Require("xcode.framework", "SafariServices")]
	[Require("source.include", "UIKit/UIKit.h")]
	[Require("source.include", "SafariServices/SafariServices.h")]
	public extern(iOS) class Safari
	{
		[Foreign(Language.ObjC)]
		public static void PresentSafari(string url, bool readerMode, bool collapseChrome, bool animated,
			bool hasBarTint, int barTintArgb, bool hasControlTint, int controlTintArgb,
			int dismissButtonStyle, int presentationStyle, int sheetSize, int colorScheme)
		@{
			if (url == nil)
				return;

			dispatch_async(dispatch_get_main_queue(), ^{
				NSURL* u = [NSURL URLWithString:url];
				if (u == nil)
					return;

				NSString* scheme = [u.scheme lowercaseString];
				if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"])
					return;

				SFSafariViewController* vc = nil;
				if (@available(iOS 11.0, *))
				{
					SFSafariViewControllerConfiguration* config = [[SFSafariViewControllerConfiguration alloc] init];
					config.entersReaderIfAvailable = readerMode;
					config.barCollapsingEnabled = collapseChrome;

					vc = [[SFSafariViewController alloc] initWithURL:u configuration:config];
				}
				else
				{
					#pragma clang diagnostic push
					#pragma clang diagnostic ignored "-Wdeprecated-declarations"
					vc = [[SFSafariViewController alloc] initWithURL:u entersReaderIfAvailable:readerMode];
					#pragma clang diagnostic pop
				}

				if (vc == nil)
					return;

				if (@available(iOS 10.0, *))
				{
					if (hasBarTint)
					{
						vc.preferredBarTintColor = [UIColor colorWithRed:((barTintArgb >> 16) & 0xff) / 255.0
						                                           green:((barTintArgb >> 8) & 0xff) / 255.0
						                                            blue:(barTintArgb & 0xff) / 255.0
						                                           alpha:((barTintArgb >> 24) & 0xff) / 255.0];
					}

					if (hasControlTint)
					{
						vc.preferredControlTintColor = [UIColor colorWithRed:((controlTintArgb >> 16) & 0xff) / 255.0
						                                               green:((controlTintArgb >> 8) & 0xff) / 255.0
						                                                blue:(controlTintArgb & 0xff) / 255.0
						                                               alpha:((controlTintArgb >> 24) & 0xff) / 255.0];
					}
				}

				if (@available(iOS 11.0, *))
				{
					switch (dismissButtonStyle)
					{
						case 1:
							vc.dismissButtonStyle = SFSafariViewControllerDismissButtonStyleClose;
							break;
						case 2:
							vc.dismissButtonStyle = SFSafariViewControllerDismissButtonStyleCancel;
							break;
						default:
							vc.dismissButtonStyle = SFSafariViewControllerDismissButtonStyleDone;
							break;
					}
				}

				switch (presentationStyle)
				{
					case 1:
						vc.modalPresentationStyle = UIModalPresentationFullScreen;
						break;
					case 2:
						vc.modalPresentationStyle = UIModalPresentationPageSheet;
						break;
					default:
						break;
				}

				if (@available(iOS 15.0, *))
				{
					// SheetSize implies a page sheet; a full-screen presentation has no detents.
					if (sheetSize != 0 && presentationStyle != 1)
					{
						vc.modalPresentationStyle = UIModalPresentationPageSheet;

						UISheetPresentationController* sheet = vc.sheetPresentationController;
						if (sheet != nil)
						{
							if (sheetSize == 1)
								sheet.detents = @[ [UISheetPresentationControllerDetent mediumDetent] ];
							else
								sheet.detents = @[ [UISheetPresentationControllerDetent largeDetent] ];
						}
					}
				}

				if (@available(iOS 13.0, *))
				{
					switch (colorScheme)
					{
						case 1:
							vc.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
							break;
						case 2:
							vc.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
							break;
						default:
							break;
					}
				}

				UIViewController* presenter = nil;
				if (@available(iOS 13.0, *))
				{
					for (UIScene* scene in [UIApplication sharedApplication].connectedScenes)
					{
						if (![scene isKindOfClass:[UIWindowScene class]])
							continue;

						UIWindowScene* windowScene = (UIWindowScene*)scene;
						UIWindow* window = nil;
						for (UIWindow* candidate in windowScene.windows)
						{
							if (candidate.isKeyWindow)
							{
								window = candidate;
								break;
							}
						}

						if (window == nil)
							window = windowScene.windows.firstObject;

						if (window != nil)
						{
							presenter = window.rootViewController;
							break;
						}
					}
				}
				else
				{
					#pragma clang diagnostic push
					#pragma clang diagnostic ignored "-Wdeprecated-declarations"
					presenter = [UIApplication sharedApplication].keyWindow.rootViewController;
					#pragma clang diagnostic pop
				}

				if (presenter == nil)
					presenter = (UIViewController*)[[UIApplication sharedApplication] delegate];

				while (presenter.presentedViewController != nil)
					presenter = presenter.presentedViewController;

				if ([presenter isKindOfClass:[UIAlertController class]] || presenter.isBeingDismissed)
					presenter = presenter.presentingViewController;

				if (presenter == nil)
					return;

				// Don't stack a second in-app browser on top of an existing one.
				for (UIViewController* current = presenter; current != nil; current = current.presentingViewController)
				{
					if ([current isKindOfClass:[SFSafariViewController class]])
						return;
				}

				[presenter presentViewController:vc animated:animated completion:nil];
			});
		@}
	}

	[Require("gradle.dependency.implementation", "androidx.browser:browser:1.8.0")]
	[ForeignInclude(Language.Java,
		"androidx.browser.customtabs.CustomTabsIntent",
		"androidx.browser.customtabs.CustomTabsClient",
		"androidx.browser.customtabs.CustomTabColorSchemeParams",
		"android.content.Intent",
		"android.net.Uri")]
	public extern(Android) class Chrome
	{
		[Foreign(Language.Java)]
		public static void PresentChrome(string url, bool showTitle, bool collapseChrome,
			bool hasToolbarColor, int toolbarColorArgb,
			bool hasNavigationBarColor, int navigationBarColorArgb,
			bool hasNavigationBarDividerColor, int navigationBarDividerColorArgb,
			int colorScheme, int shareState, int sheetSize,
			bool bookmarksButtonEnabled, bool downloadButtonEnabled,
			bool hasToolbarColorDark, int toolbarColorDarkArgb,
			bool hasNavigationBarColorDark, int navigationBarColorDarkArgb,
			bool hasNavigationBarDividerColorDark, int navigationBarDividerColorDarkArgb,
			int requestCode, bool fallbackToExternalBrowser)
		@{
			final android.app.Activity activity = com.fuse.Activity.getRootActivity();
			if (activity == null)
				return;

			activity.runOnUiThread(new Runnable() {
				public void run() {
					if (activity.isFinishing() || activity.isDestroyed())
						return;

					Uri uri = Uri.parse(url);
					if (uri == null || uri.getScheme() == null)
						return;

					String scheme = uri.getScheme();
					if (!scheme.equalsIgnoreCase("http") && !scheme.equalsIgnoreCase("https"))
						return;

					try {
						boolean hasCustomTabs = CustomTabsClient.getPackageName(activity, null) != null;
						if (!hasCustomTabs && !fallbackToExternalBrowser)
							return;

						CustomTabsIntent.Builder builder = new CustomTabsIntent.Builder();
						builder.setShowTitle(showTitle);
						builder.setUrlBarHidingEnabled(collapseChrome);

						// Values match InAppBrowserSheetSize: 1 = Medium, 2 = Large.
						if (sheetSize != 0) {
							float fraction = sheetSize == 1 ? 0.5f : 0.9f;
							int heightPx = (int)(activity.getResources().getDisplayMetrics().heightPixels * fraction);
							builder.setInitialActivityHeightPx(heightPx);
						}

						builder.setColorScheme(colorScheme);
						builder.setShareState(shareState);
						builder.setBookmarksButtonEnabled(bookmarksButtonEnabled);
						builder.setDownloadButtonEnabled(downloadButtonEnabled);

						if (hasToolbarColor || hasNavigationBarColor || hasNavigationBarDividerColor) {
							CustomTabColorSchemeParams.Builder params = new CustomTabColorSchemeParams.Builder();
							if (hasToolbarColor)
								params.setToolbarColor(toolbarColorArgb);
							if (hasNavigationBarColor)
								params.setNavigationBarColor(navigationBarColorArgb);
							if (hasNavigationBarDividerColor)
								params.setNavigationBarDividerColor(navigationBarDividerColorArgb);
							builder.setDefaultColorSchemeParams(params.build());
						}

						if (hasToolbarColorDark || hasNavigationBarColorDark || hasNavigationBarDividerColorDark) {
							CustomTabColorSchemeParams.Builder darkParams = new CustomTabColorSchemeParams.Builder();
							if (hasToolbarColorDark)
								darkParams.setToolbarColor(toolbarColorDarkArgb);
							if (hasNavigationBarColorDark)
								darkParams.setNavigationBarColor(navigationBarColorDarkArgb);
							if (hasNavigationBarDividerColorDark)
								darkParams.setNavigationBarDividerColor(navigationBarDividerColorDarkArgb);
							builder.setColorSchemeParams(CustomTabsIntent.COLOR_SCHEME_DARK, darkParams.build());
						}

						CustomTabsIntent customTabsIntent = builder.build();
						Intent customTabIntent = customTabsIntent.intent;
						customTabIntent.setData(uri);

						// Partial Custom Tabs require either a session or a for-result launch.
						activity.startActivityForResult(customTabIntent, requestCode);
					} catch (android.content.ActivityNotFoundException e) {
						if (fallbackToExternalBrowser) {
							try {
								activity.startActivity(new Intent(Intent.ACTION_VIEW, uri));
							} catch (android.content.ActivityNotFoundException ignored) {
								// No browser is installed.
							}
						}
					} catch (Exception e) {
						android.util.Log.e("Fuse.InAppBrowser", "Failed to open in-app browser", e);
					}
				}
			});
		@}
	}
}
