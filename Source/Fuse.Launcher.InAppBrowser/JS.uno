using Uno;
using Uno.UX;
using Fuse.Scripting;

namespace Fuse.Reactive.FuseJS
{
	[UXGlobalModule]
	/**
		@scriptmodule FuseJS/InAppBrowser

		The InAppBrowser API allows you to launch In App Browser

		You need to add a reference to `"Fuse.Launcher"` in your project file to use this feature.

		## Example

		```javascript
			var inAppBrowser = require("FuseJS/InAppBrowser");
			inAppBrowser.openUrl("https://fuseopen.com");
		```
	*/
	public class InAppBrowserModule : NativeModule
	{
		static InAppBrowserModule _instance;

		public InAppBrowserModule()
		{
			if (_instance != null)
				return;

			_instance = this;
			Resource.SetGlobalKey(_instance, "FuseJS/InAppBrowser");

			AddMember(new NativeFunction("openUrl", (NativeCallback)OpenUrl));
		}

		/** @scriptmethod openUrl

			Opens a URL in the in-app browser.

			`openUrl` accepts the following arguments:

			url – The URL to open. Only `http` and `https` URLs are supported.
			options – Optional object with the following properties:
			  * `readerMode` – iOS: open in reader mode when the page supports it.
			  * `collapseChromeOnScroll` – Collapse the browser chrome while scrolling. Defaults to `true`.
			  * `toolbarColor` – Toolbar background color as a hex string, for example `"#1E88E5"`.
			  * `controlTintColor` – iOS: color of the browser controls as a hex string.
			  * `navigationBarColor` – Android: navigation bar color as a hex string.
			  * `navigationBarDividerColor` – Android: navigation bar divider color as a hex string.
			  * `toolbarColorDark` – Android: toolbar color used in dark mode.
			  * `navigationBarColorDark` – Android: navigation bar color used in dark mode.
			  * `navigationBarDividerColorDark` – Android: navigation bar divider color used in dark mode.
			  * `colorScheme` – Force `"system"`, `"light"` or `"dark"`.
			  * `shareState` – Android: `"default"`, `"on"` or `"off"`.
			  * `bookmarksButtonEnabled` – Android: show the bookmarks button. Defaults to `true`.
			  * `downloadButtonEnabled` – Android: show the download button. Defaults to `true`.
			  * `showTitle` – Android: show the page title in the toolbar.
			  * `dismissButtonStyle` – iOS: `"done"`, `"close"` or `"cancel"`.
			  * `presentationStyle` – iOS: `"automatic"`, `"fullScreen"` or `"pageSheet"`.
			  * `sheetSize` – `"default"`, `"medium"` or `"large"` for bottom-sheet presentations.
			  * `animated` – iOS: animate the browser presentation. Defaults to `true`.
			  * `fallbackToExternalBrowser` – Android: open in the normal browser when Custom Tabs is not available. Defaults to `true`.

			```javascript
				var inAppBrowser = require("FuseJS/InAppBrowser");
				inAppBrowser.openUrl("https://fuseopen.com", {
					readerMode: true,
					toolbarColor: "#1E88E5"
				});
			```
		*/
		object[] OpenUrl(Context c, object[] args)
		{
			var url = args.ValueOrDefault<string>(0,"");
			if (url == "")
				throw new Exception("You need to supply a valid url");

			var scriptOptions = args.Length > 1 ? args[1] as Fuse.Scripting.Object : null;
			var options = ParseOptions(scriptOptions);

			Fuse.LauncherImpl.InAppBrowserLauncher.LaunchInAppBrowser(url, options);
			return null;
		}

		static InAppBrowserOptions ParseOptions(Fuse.Scripting.Object obj)
		{
			return new InAppBrowserOptions {
				ReaderMode = GetBool(obj, "readerMode", false),
				CollapseChromeOnScroll = GetBool(obj, "collapseChromeOnScroll", true),
				ToolbarColor = GetString(obj, "toolbarColor"),
				ControlTintColor = GetString(obj, "controlTintColor"),
				NavigationBarColor = GetString(obj, "navigationBarColor"),
				NavigationBarDividerColor = GetString(obj, "navigationBarDividerColor"),
				ToolbarColorDark = GetString(obj, "toolbarColorDark"),
				NavigationBarColorDark = GetString(obj, "navigationBarColorDark"),
				NavigationBarDividerColorDark = GetString(obj, "navigationBarDividerColorDark"),
				ColorScheme = GetColorScheme(obj),
				ShareState = GetShareState(obj),
				BookmarksButtonEnabled = GetBool(obj, "bookmarksButtonEnabled", true),
				DownloadButtonEnabled = GetBool(obj, "downloadButtonEnabled", true),
				ShowTitle = GetBool(obj, "showTitle", false),
				DismissButtonStyle = GetDismissButtonStyle(obj),
				PresentationStyle = GetPresentationStyle(obj),
				SheetSize = GetSheetSize(obj),
				Animated = GetBool(obj, "animated", true),
				FallbackToExternalBrowser = GetBool(obj, "fallbackToExternalBrowser", true)
			};
		}

		static string GetString(Fuse.Scripting.Object obj, string key)
		{
			if (obj == null || !obj.ContainsKey(key))
				return null;

			return obj[key] as string;
		}

		static bool GetBool(Fuse.Scripting.Object obj, string key, bool defaultValue)
		{
			if (obj == null || !obj.ContainsKey(key))
				return defaultValue;

			var value = obj[key];
			if (value is bool)
				return (bool)value;
			if (value is double)
				return (double)value != 0;

			return defaultValue;
		}

		static InAppBrowserDismissButtonStyle GetDismissButtonStyle(Fuse.Scripting.Object obj)
		{
			var value = GetString(obj, "dismissButtonStyle");
			if (value == null)
				return InAppBrowserDismissButtonStyle.Done;

			// Uno does not support switching on a string.
			var lower = value.ToLower();
			if (lower == "close")
				return InAppBrowserDismissButtonStyle.Close;
			if (lower == "cancel")
				return InAppBrowserDismissButtonStyle.Cancel;

			return InAppBrowserDismissButtonStyle.Done;
		}

		static InAppBrowserColorScheme GetColorScheme(Fuse.Scripting.Object obj)
		{
			var value = GetString(obj, "colorScheme");
			if (value == null)
				return InAppBrowserColorScheme.System;

			var lower = value.ToLower();
			if (lower == "light")
				return InAppBrowserColorScheme.Light;
			if (lower == "dark")
				return InAppBrowserColorScheme.Dark;

			return InAppBrowserColorScheme.System;
		}

		static InAppBrowserShareState GetShareState(Fuse.Scripting.Object obj)
		{
			var value = GetString(obj, "shareState");
			if (value == null)
				return InAppBrowserShareState.Default;

			var lower = value.ToLower();
			if (lower == "on")
				return InAppBrowserShareState.On;
			if (lower == "off")
				return InAppBrowserShareState.Off;

			return InAppBrowserShareState.Default;
		}

		static InAppBrowserPresentationStyle GetPresentationStyle(Fuse.Scripting.Object obj)
		{
			var value = GetString(obj, "presentationStyle");
			if (value == null)
				return InAppBrowserPresentationStyle.Automatic;

			// Uno does not support switching on a string.
			var lower = value.ToLower();
			if (lower == "fullscreen")
				return InAppBrowserPresentationStyle.FullScreen;
			if (lower == "pagesheet")
				return InAppBrowserPresentationStyle.PageSheet;

			return InAppBrowserPresentationStyle.Automatic;
		}

		static InAppBrowserSheetSize GetSheetSize(Fuse.Scripting.Object obj)
		{
			var value = GetString(obj, "sheetSize");
			if (value == null)
				return InAppBrowserSheetSize.Default;

			var lower = value.ToLower();
			if (lower == "medium")
				return InAppBrowserSheetSize.Medium;
			if (lower == "large")
				return InAppBrowserSheetSize.Large;

			return InAppBrowserSheetSize.Default;
		}
	}

}
