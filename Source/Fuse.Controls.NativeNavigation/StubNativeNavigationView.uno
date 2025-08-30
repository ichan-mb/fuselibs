using Uno;
using Fuse;
using Fuse.Controls;
using Fuse.Controls.Native;


namespace Fuse.Controls
{
	extern(!iOS) public class StubNativeNavigationView : INativeNavigationView
	{
		NativeNavigationView _host;

		public StubNativeNavigationView()
		{
		}

		public void SetHost(NativeNavigationView host)
		{
			_host = host;
		}

		public void NavigateToView(object nativeHandle, string templateName, bool isPush, bool isPop)
		{
			// Stub implementation - no native navigation on this platform
			if defined(DEBUG)
			{
				Fuse.Diagnostics.InternalError("NativeNavigationView is not implemented on this platform", this);
			}
		}

		public Visual CreateTemplateInstance(string templateName)
		{
			if (_host == null)
				return null;

			var template = _host.FindTemplate(templateName);
			if (template == null)
				return null;

			var instance = template.New() as Visual;
			if (instance != null)
			{
				instance.Name = templateName;
			}

			return instance;
		}

		public object GetNavigationController()
		{
			return null;
		}

		public void PresentInWindow()
		{
			// Stub implementation - no native navigation on this platform
		}

		public void ConfigureNavigationBar(string templateName, NavigationBarProps config)
		{
			// Stub implementation - no navigation bar customization on this platform
		}

		public void SetNavigationChangeCallback(Action<string,int,bool> callback)
		{
			// Stub implementation - no navigation bar customization on this platform
		}

		public int GetNativeStackCount()
		{
			// Stub implementation - no native stack on this platform
			return 0;
		}

		public string[] GetNativeStackTemplates()
		{
			// Stub implementation - no native stack on this platform
			return new string[0];
		}

		public void PopFromNativeStack()
		{
			// Stub implementation - no native navigation on this platform
		}

	}

	// Factory class to create the appropriate native implementation
	extern(!iOS) public static class NativeNavigationViewFactory
	{
		public static Fuse.Controls.Native.IView Create(NativeNavigationView host)
		{
			// Return null to fall back to default Panel behavior
			return null;
		}

		public static INativeNavigationView CreateNativeImpl(NativeNavigationView host)
		{
			var impl = new StubNativeNavigationView();
			impl.SetHost(host);
			return impl;
		}
	}
}
