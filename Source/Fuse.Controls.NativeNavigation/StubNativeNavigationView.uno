using Uno;

using Fuse;
using Fuse.Controls;
using Fuse.Controls.Native;

namespace Fuse.Controls
{
	extern(!iOS && !Android) internal class StubNativeNavigationView : INativeNavigationView
	{
		public StubNativeNavigationView()
		{
		}

		public void SetHost(NativeNavigationView host)
		{
		}

		public void NavigateToView(object nativeHandle, string templateName, bool isPush, bool isPop)
		{
			if defined(DEBUG)
				Fuse.Diagnostics.InternalError("NativeNavigationView is not implemented on this platform", this);
		}

		public void PresentView(object nativeHandle, string templateName, ModalPresentationStyle style, bool dragToDismiss, bool expandable)
		{
		}

		public void SetModalExpanded(bool expanded)
		{
		}

		public void DismissView()
		{
			// Nothing is presented: report the dismissal straight away so the page is released.
			if (_modalDismissedCallback != null)
				_modalDismissedCallback();
		}

		public void DismissAllModals()
		{
		}

		Action _modalDismissedCallback;
		public void SetModalDismissedCallback(Action callback)
		{
			_modalDismissedCallback = callback;
		}

		public void SetModalLaidOutCallback(Action<float2> callback)
		{
		}

		public void ConfigureNavigationBar(string templateName, NavigationBarProps config)
		{
		}

		public void SetNavigationChangeCallback(Action<string,int,bool> callback)
		{
		}

		public void SetNavigationStartedCallback(Action<string,int,bool> callback)
		{
		}

		public int GetNativeStackCount()
		{
			return 0;
		}

		public string[] GetNativeStackTemplates()
		{
			return new string[0];
		}

		public void PopFromNativeStack()
		{
		}

		public float4 GetNavigationSafeInsets(string templateName)
		{
			return float4(0);
		}

		public float4 GetModalSafeAreaInsets()
		{
			return float4(0);
		}

	}

	// Factory for platforms without a native implementation.
	extern(!iOS && !Android) internal static class NativeNavigationViewFactory
	{
		internal static Fuse.Controls.Native.IView Create(NativeNavigationView host)
		{
			// No native view: the shared layer falls back to plain Fuse rendering.
			return null;
		}

		internal static INativeNavigationView CreateNativeImpl(NativeNavigationView host)
		{
			var impl = new StubNativeNavigationView();
			impl.SetHost(host);
			return impl;
		}
	}
}
