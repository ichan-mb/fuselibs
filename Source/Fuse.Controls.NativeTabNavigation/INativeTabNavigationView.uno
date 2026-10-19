using Uno;

using Fuse;

namespace Fuse.Controls
{
	/**
		How a tab is presented: its title and icon, resolved by `NativeTabNavigationView` for the
		current platform.
	*/
	internal class TabProps
	{
		public string Title { get; set; }
		/** A platform symbol name (SF Symbols on iOS, a Material Symbols ligature on Android). */
		public string Symbols { get; set; }
		public bool IsFilled { get; set; }
		/** Screen-reader name; falls back to `Title`. */
		public string AccessibilityLabel { get; set; }
		/** Whether the user can select the tab. */
		public bool Enabled { get; set; }
		/** Where the tab sits in the bar. */
		public TabPlacement Placement { get; set; }
		/** Whether the tab is added at startup (used by the shared layer; platforms ignore it). */
		public bool AutoAdd { get; set; }
		/** Per-tab colours; when unset the bar's tint / selected tint is used. */
		public bool HasColor { get; set; }
		public float4 Color { get; set; }
		public bool HasSelectedColor { get; set; }
		public float4 SelectedColor { get; set; }
		/** Badge text; null for none, empty for a dot. */
		public string Badge { get; set; }
		public float4 BadgeColor { get; set; }
		public float4 BadgeTextColor { get; set; }
	}

	/** What the system back button does on a tab other than the first. */
	public enum TabBackBehavior
	{
		/** Leave Back to the app (the usual behaviour for a tab bar). */
		Exit,
		/** Select the first tab instead of leaving the app. */
		ReturnToFirst
	}

	/** Where a tab sits in the bar (follows UIKit's `UITabPlacement`, plus `Search`). */
	public enum TabPlacement
	{
		/** Resolved by the platform: a normal tab. */
		Automatic,
		Default,
		/** Can be added/removed by the user's tab customization. */
		Optional,
		/** Cannot be removed, can be moved within the bar. */
		Movable,
		/** Always visible and placed at the trailing side of the bar. */
		Pinned,
		/** Cannot be moved or removed, placed before all customizable tabs. */
		Fixed,
		/** Only shown in a sidebar; on Android it is hidden. iOS shows it as a normal tab when there is no sidebar (iPhone). */
		SidebarOnly,
		/**
			A search tab: on iOS 26+ it is shown as the separate trailing search button; on Android
			it is a round, elevated button at the trailing edge.
		*/
		Search
	}

	/** When a tab's title is shown under its icon. */
	public enum TabBarLabelVisibility
	{
		Always,
		Selected,
		Never
	}

	/** The tab bar's appearance, shared by both platforms. */
	internal class TabBarProps
	{
		public float4 BackgroundColor { get; set; }
		public float4 TintColor { get; set; }
		public float4 SelectedTintColor { get; set; }
		/** Whether the bar is blurred rather than opaque (iOS; Android uses the background's alpha). */
		public bool Translucent { get; set; }
		/** Whether the whole bar is hidden. */
		public bool Hidden { get; set; }
		public TabBarLabelVisibility ShowLabels { get; set; }
	}

	/**
		Contract between the shared `NativeTabNavigationView` and its platform implementation
		(`UITabBarController` on iOS, a bottom tab bar with a page container on Android).
	*/
	internal interface INativeTabNavigationView
	{
		/** Adds a tab whose content is the given native view (`null` for a lazy tab), with its title and icon. */
		void AddTab(object nativeHandle, string templateName, TabProps props);

		/** Updates the title, icon and badge of an existing tab. */
		void SetTabProps(int index, TabProps props);

		/** Removes a tab and its page. */
		void RemoveTab(int index);

		/** Adds the page view to a tab that was added without one (lazy tabs). */
		void SetTabContent(int index, object nativeHandle);

		/** Selects a tab in the platform's tab control. */
		void SelectTab(int index);

		/** Invoked when the user selects a tab; the shared layer then updates its state. */
		void SetSelectedCallback(Action<int> callback);

		/** Applies the tab bar's colours. */
		void ConfigureTabBar(TabBarProps props);

		/**
			Reports the insets (status bar, safe area) the tab pages should be padded by, in points, and
			again whenever they change (rotation, window changes).
		*/
		void SetContentInsetsCallback(Action<float4> callback);
	}
}
