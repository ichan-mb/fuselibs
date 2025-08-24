using Uno;
using Fuse;
using Fuse.Controls.Native;

namespace Fuse.Controls
{
	/**
		Interface for platform-specific ViewControllerRoot implementations.
		This provides a cross-platform abstraction for creating isolated native rendering contexts
		that can be safely integrated with platform-specific navigation controllers.
	*/
	public interface IViewControllerRoot : INativeViewRoot
	{
		/**
			Sets the content Visual that will be rendered in this view controller context.
			The content will be added to the platform's native rendering pipeline.
		*/
		void SetContent(Visual content);

		/**
			Gets the native view handle that contains the rendered content.
			This can be safely added to a platform-specific view controller.
		*/
		ViewHandle GetViewHandle();

		/**
			Gets the native handle (UIView on iOS, View on Android) for the rendered content.
			This is what gets added to the platform's view controller.
		*/
		object GetNativeHandle();

		/**
			Cleans up the rendering context and releases resources.
			Should properly dispose of all native handles and rendering contexts.
		*/
		void Dispose();
	}

	/**
		Factory for creating platform-specific ViewControllerRoot implementations.
		This provides a clean abstraction layer for cross-platform code.
	*/
	public static class ViewControllerRootFactory
	{
		/**
			Creates a platform-specific ViewControllerRoot implementation.
			Returns the appropriate implementation for the current platform.
		*/
		public static IViewControllerRoot Create()
		{
			if defined(iOS)
				return new iOS.ViewControllerRoot();
			// else if defined(Android)
			// 	return new Android.ViewControllerRoot();
			else
				return new ViewControllerRootStub();
		}
	}

	/**
		Stub implementation for platforms that don't support native navigation.
		Provides basic functionality for testing and non-mobile platforms.
	*/
	internal class ViewControllerRootStub : IViewControllerRoot
	{
		public void SetContent(Visual content) { }
		public ViewHandle GetViewHandle() { return null; }
		public object GetNativeHandle() { return null; }
		public void Dispose() { }

		// INativeViewRoot implementation
		void INativeViewRoot.Add(ViewHandle handle) { }
		void INativeViewRoot.Remove(ViewHandle handle) { }
	}
}
