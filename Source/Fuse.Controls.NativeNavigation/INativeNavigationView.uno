using Uno;
using Fuse;

namespace Fuse.Controls
{
	/**
		Interface for platform-specific native navigation implementations.
		This allows the cross-platform NativeNavigationView to communicate
		with platform-specific implementations while maintaining clean separation.
	*/
	public interface INativeNavigationView
	{
		/**
			Navigate to a specific view with the given navigation mode.

			@param nativeHandle The native view handle (UIView on iOS) to navigate to
			@param templateName The name of the template being navigated to
			@param isPush Whether this is a push navigation (forward)
			@param isPop Whether this is a pop navigation (backward)
		*/
		void NavigateToView(object nativeHandle, string templateName, bool isPush, bool isPop);

		/**
			Set the host NativeNavigationView that owns this implementation.
			This allows the native implementation to access templates and other
			host functionality when needed.

			@param host The Fuse NativeNavigationView host
		*/
		void SetHost(NativeNavigationView host);

		/**
			Create a template instance by name.
			This is a convenience method that delegates to the host's template system.

			@param templateName The name of the template to instantiate
			@return A new Visual instance from the template, or null if not found
		*/
		Visual CreateTemplateInstance(string templateName);

		/**
			Gets the native navigation controller handle for advanced scenarios.
			On iOS, this returns the UINavigationController ObjC.Object.

			@return Platform-specific navigation controller handle
		*/
		object GetNavigationController();

		/**
			Present the navigation controller modally in the current window.
			This is useful for showing the navigation as a modal presentation.
		*/
		void PresentInWindow();

		/**
			Configure the navigation bar appearance for a specific template/view.
			This allows customization of title, colors, and other navigation bar properties.

			@param templateName The name of the template whose navigation bar should be configured
			@param config Configuration object containing navigation bar settings
		*/
		void ConfigureNavigationBar(string templateName, NavigationBarProps config);
	}

	/**
		Configuration object for navigation bar appearance
	*/
	public class NavigationBarProps
	{
		public string Title { get; set; }
		public float4 BackgroundColor { get; set; }
		public float4 ForegroundColor { get; set; }
		public float4 TintColor { get; set; }
		public bool LargeTitle { get; set; }
		public bool Translucent { get; set; }
		public bool Hidden { get; set; }
		public string BackButtonTitle { get; set; }
	}
}
