using Uno;
using Fuse;
using Fuse.Controls;
using Fuse.Controls.Native;
using Fuse.Elements;

namespace Fuse.Controls
{
	/**
		Cross-platform ViewControllerRoot that delegates to platform-specific implementations.
		This creates isolated native view hierarchies that can be safely added to platform-specific
		view controllers (UIViewController on iOS, Fragment on Android) without interfering with
		the main NativeNavigationView's visual tree.

		This follows the factory pattern for clean cross-platform abstraction.
	*/
	internal class ViewControllerRoot : IViewControllerRoot
	{
		readonly IViewControllerRoot _platformImpl;

		public ViewControllerRoot()
		{
			// Create platform-specific implementation through factory
			_platformImpl = ViewControllerRootFactory.Create();
		}

		// Delegate all interface methods to platform implementation
		public void SetContent(Visual content)
		{
			_platformImpl.SetContent(content);
		}

		public ViewHandle GetViewHandle()
		{
			return _platformImpl.GetViewHandle();
		}

		public object GetNativeHandle()
		{
			return _platformImpl.GetNativeHandle();
		}

		public void Dispose()
		{
			_platformImpl.Dispose();
		}

		// INativeViewRoot implementation - delegate to platform
		void INativeViewRoot.Add(ViewHandle handle)
		{
			(_platformImpl as INativeViewRoot).Add(handle);
		}

		void INativeViewRoot.Remove(ViewHandle handle)
		{
			(_platformImpl as INativeViewRoot).Remove(handle);
		}
	}
}
