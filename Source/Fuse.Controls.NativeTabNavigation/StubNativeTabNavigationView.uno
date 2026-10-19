using Uno;

using Fuse;

namespace Fuse.Controls
{
	extern(!iOS && !Android) internal class StubNativeTabNavigationView : INativeTabNavigationView
	{
		public void AddTab(object nativeHandle, string templateName, TabProps props)
		{
		}

		public void SetTabProps(int index, TabProps props)
		{
		}

		public void RemoveTab(int index)
		{
		}

		public void SetTabContent(int index, object nativeHandle)
		{
		}

		public void SelectTab(int index)
		{
		}

		public void SetSelectedCallback(Action<int> callback)
		{
		}

		public void ConfigureTabBar(TabBarProps props)
		{
		}

		public void SetContentInsetsCallback(Action<float4> callback)
		{
		}
	}

	extern(!iOS && !Android) internal static class NativeTabNavigationViewFactory
	{
		internal static INativeTabNavigationView CreateNativeImpl()
		{
			return new StubNativeTabNavigationView();
		}
	}
}
