using Uno;

using Fuse;
using Fuse.Controls.Native;

namespace Fuse.Controls
{
	/**
		Platform-specific rendering context for a page: an isolated native view hierarchy and viewport.
	*/
	internal interface IViewControllerRoot : INativeViewRoot
	{
		/** Sets the `Visual` rendered in this context. */
		void SetContent(Visual content);

		/** The native view (a `UIView` on iOS, a `View` on Android) to add to the platform's controller. */
		object GetNativeHandle();

		/**
			Re-lays the page out at the size its presentation gave it (used for modals); a page otherwise follows
			the size of its own native view, reported by the platform implementation.
		*/
		void SetContentSize(float2 pixelSize);

		/**
			Whether the page follows the size of its own native view (the default), or not -- which is what a
			modal is told: it keeps the app frame, from which its insets are derived, and the presentation
			answers for its size instead.
		*/
		void SetFollowsOwnSize(bool followsOwnSize);

		/** Releases the rendering context and its native resources. */
		void Dispose();
	}

	/**
		Factory for the platform `ViewControllerRoot` implementations.
	*/
	internal static class ViewControllerRootFactory
	{
		internal static IViewControllerRoot Create(Node contextSource = null)
		{
			if defined(iOS)
				return new iOS.ViewControllerRoot(contextSource);
			else if defined(Android)
				return new Android.ViewControllerRoot(contextSource);
			else
				return new ViewControllerRootStub();
		}
	}

	/**
		Stub for platforms that don't support native navigation.
	*/
	internal class ViewControllerRootStub : IViewControllerRoot
	{
		public ViewControllerRootStub() { }
		public void SetContent(Visual content) { }
		public void SetContentSize(float2 pixelSize) { }
		public void SetFollowsOwnSize(bool followsOwnSize) { }
		public object GetNativeHandle() { return null; }
		public void Dispose() { }

		// INativeViewRoot implementation
		void INativeViewRoot.Add(ViewHandle handle) { }
		void INativeViewRoot.Remove(ViewHandle handle) { }
	}
}
