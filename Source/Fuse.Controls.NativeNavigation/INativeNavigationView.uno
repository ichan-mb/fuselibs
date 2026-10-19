using Uno;

using Fuse;

namespace Fuse.Controls
{
	/**
		Contract between the shared `NativeNavigationView` and its platform implementation (a
		`UINavigationController` stack on iOS, a `FragmentManager` back stack with a `Toolbar` on Android).
	*/
	internal interface INativeNavigationView
	{
		/** Navigates to the given native view: a push (`isPush`), a pop (`isPop`) or an initial/replace. */
		void NavigateToView(object nativeHandle, string templateName, bool isPush, bool isPop);

		/** Sets the `NativeNavigationView` that owns this implementation. */
		void SetHost(NativeNavigationView host);

		/** Presents a view modally in the given style. */
		void PresentView(object nativeHandle, string templateName, ModalPresentationStyle style, bool dragToDismiss, bool expandable);

		/** Gives the top-most modal its expanded size, or the size of its own presentation style back. */
		void SetModalExpanded(bool expanded);

		/** Dismisses the top-most modal; `SetModalDismissedCallback` reports when the animation has finished. */
		void DismissView();

		/**
			Dismisses every presented modal immediately, without animating or reporting, for teardown:
			the shared layer releases the presented pages straight afterwards.
		*/
		void DismissAllModals();

		/** Invoked once a modal dismissal has finished animating, so the page is not released mid-animation. */
		void SetModalDismissedCallback(Action callback);

		/** Configures the bar appearance for a template. */
		void ConfigureNavigationBar(string templateName, NavigationBarProps config);

		/** Invoked once native navigation has settled; the shared layer then reconciles its contexts. */
		void SetNavigationChangeCallback(Action<string,int,bool> callback);

		/** Invoked before the native transition runs, so page animations run in step with it. */
		void SetNavigationStartedCallback(Action<string,int,bool> callback);

		/** Invoked once a presented modal's content is laid out, with the size of that view in pixels. */
		void SetModalLaidOutCallback(Action<float2> callback);

		/** The native stack count, the authoritative value. */
		int GetNativeStackCount();

		/** The template names on the native stack, bottom to top. */
		string[] GetNativeStackTemplates();

		/** Pops the top view controller from the native stack. */
		void PopFromNativeStack();

		/** The safe-area insets (including the bar) for a template's content, in points. */
		float4 GetNavigationSafeInsets(string templateName);

		/** The safe-area insets (status bar / home indicator) for a presented modal, in points. */
		float4 GetModalSafeAreaInsets();
	}

	/**
		Configuration object for navigation bar appearance.
	*/
	internal class NavigationBarProps
	{
		public string Title { get; set; }
		public float4 BackgroundColor { get; set; }
		public float4 ForegroundColor { get; set; }
		public float4 TintColor { get; set; }
		public bool LargeTitle { get; set; }
		public bool Translucent { get; set; }
		public bool Hidden { get; set; }
		public string BackButtonTitle { get; set; }
		public ToolbarItemProps[] ToolbarItems { get; set; }

		/**
			Menu entries for the toolbar buttons, flattened. Each carries the index of the `ToolbarItem` it
			belongs to.
		*/
		public ToolbarMenuItemProps[] MenuItems { get; set; }
	}
}
