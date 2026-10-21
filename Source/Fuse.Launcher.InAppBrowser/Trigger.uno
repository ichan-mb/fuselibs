using Uno;

namespace Fuse.Triggers.Actions
{

	/** Launch a URL in the in-app browser.

		On iOS this uses `SFSafariViewController`, and on Android it uses Chrome Custom Tabs.

		You'll find this trigger action in the Fuse.Launcher package, which have to be referenced from your uno project.
		For example:

		```json
			{
				"references": [
					"Fuse",
					"FuseJS",
					"Fuse.Launcher"
				]
			}
		```

		## Example

		```xml
			<StackPanel Margin="20">
				<Button Margin="10" Text="Launch InApp Browser">
					<Clicked>
						<LaunchInAppBrowser Url="https://fuseopen.com" />
					</Clicked>
				</Button>
				<Button Margin="10" Text="Launch InApp Browser With Options">
					<Clicked>
						<LaunchInAppBrowser Url="https://fuseopen.com"
						                    ReaderMode="true"
						                    ToolbarColor="#1E88E5" />
					</Clicked>
				</Button>
			</StackPanel>
		```
	*/
	public class LaunchInAppBrowser : TriggerAction
	{
		public LaunchInAppBrowser()
		{
			CollapseChromeOnScroll = true;
			BookmarksButtonEnabled = true;
			DownloadButtonEnabled = true;
			Animated = true;
			FallbackToExternalBrowser = true;
		}

		public string Url {get; set;}

		/** Open in reader mode when the page supports it. iOS only. */
		public bool ReaderMode {get; set;}

		/** Collapse the browser chrome while scrolling. Defaults to `true`. */
		public bool CollapseChromeOnScroll {get; set;}

		/** Toolbar background color as a hex string. */
		public string ToolbarColor {get; set;}

		/** Color of the browser controls as a hex string. iOS only. */
		public string ControlTintColor {get; set;}

		/** Navigation bar color as a hex string. Android only. */
		public string NavigationBarColor {get; set;}

		/** Navigation bar divider color as a hex string. Android only. */
		public string NavigationBarDividerColor {get; set;}

		/** Toolbar color used in dark mode as a hex string. Android only. */
		public string ToolbarColorDark {get; set;}

		/** Navigation bar color used in dark mode as a hex string. Android only. */
		public string NavigationBarColorDark {get; set;}

		/** Navigation bar divider color used in dark mode as a hex string. Android only. */
		public string NavigationBarDividerColorDark {get; set;}

		/** Force the system, light or dark color scheme. */
		public InAppBrowserColorScheme ColorScheme {get; set;}

		/** Whether the Android share menu item is shown. Android only. */
		public InAppBrowserShareState ShareState {get; set;}

		/** Whether the Android bookmarks button is shown. Defaults to `true`. Android only. */
		public bool BookmarksButtonEnabled {get; set;}

		/** Whether the Android download button is shown. Defaults to `true`. Android only. */
		public bool DownloadButtonEnabled {get; set;}

		/** Show the page title in the toolbar. Android only. */
		public bool ShowTitle {get; set;}

		/** Style of the dismiss button. iOS only. */
		public InAppBrowserDismissButtonStyle DismissButtonStyle {get; set;}

		/** Presentation style of the browser. iOS only. */
		public InAppBrowserPresentationStyle PresentationStyle {get; set;}

		/** Preferred sheet height: Default, Medium or Large. */
		public InAppBrowserSheetSize SheetSize {get; set;}

		/** Animate the browser presentation. Defaults to `true`. iOS only. */
		public bool Animated {get; set;}

		/** Open the URL in the normal browser when Custom Tabs is not available. Defaults to `true`. Android only. */
		public bool FallbackToExternalBrowser {get; set;}

		protected override void Perform(Node target)
		{
			try
			{
				Fuse.LauncherImpl.InAppBrowserLauncher.LaunchInAppBrowser(Url, new InAppBrowserOptions {
					ReaderMode = ReaderMode,
					CollapseChromeOnScroll = CollapseChromeOnScroll,
					ToolbarColor = ToolbarColor,
					ControlTintColor = ControlTintColor,
					NavigationBarColor = NavigationBarColor,
					NavigationBarDividerColor = NavigationBarDividerColor,
					ToolbarColorDark = ToolbarColorDark,
					NavigationBarColorDark = NavigationBarColorDark,
					NavigationBarDividerColorDark = NavigationBarDividerColorDark,
					ColorScheme = ColorScheme,
					ShareState = ShareState,
					BookmarksButtonEnabled = BookmarksButtonEnabled,
					DownloadButtonEnabled = DownloadButtonEnabled,
					ShowTitle = ShowTitle,
					DismissButtonStyle = DismissButtonStyle,
					PresentationStyle = PresentationStyle,
					SheetSize = SheetSize,
					Animated = Animated,
					FallbackToExternalBrowser = FallbackToExternalBrowser
				});
			}
			catch (ArgumentException e)
			{
				Fuse.Diagnostics.UserError(e.Message, this);
			}
		}
	}
}
