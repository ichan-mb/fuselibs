using Uno;
using Fuse;
using Fuse.Elements;
using Fuse.Controls.Native;
using Fuse.Navigation;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Controls
{
	/**
		A specialized TreeRendererPanel that forwards data context requests back to a parent
		NativeNavigationView. This enables data binding to work correctly when template instances
		are isolated in separate ViewControllerRoot contexts.

		When a template instance is moved to a ViewControllerRoot for native view controller
		integration, it loses access to the original NativeNavigationView's data context.
		This panel acts as a bridge, forwarding ISubtreeDataProvider requests back to the
		navigation view that created it.
	*/
	extern(Android || iOS) internal class DataContextTreeRendererPanel : TreeRendererPanel, Node.ISubtreeDataProvider
	{
		[WeakReference]
		NativeNavigationView _navigationView;

		public DataContextTreeRendererPanel(INativeViewRoot nativeViewHost, NativeNavigationView navigationView)
			: base(nativeViewHost)
		{
			_navigationView = navigationView;
		}

		Node.ContextDataResult ISubtreeDataProvider.TryGetDataProvider(Node n, Node.DataType type, out object provider)
		{
			provider = null;
			// First check if we have local PageData on this visual
			var v = n as Visual;
			if (v != null)
			{
				var pd = PageData.Get(v);
				if (pd != null && pd.Context != null)
				{
					provider = pd.Context;
					return type == Node.DataType.Prime ? Node.ContextDataResult.NullProvider : Node.ContextDataResult.Continue;
				}
			}

			// Forward the request to the navigation view if it exists
			if (_navigationView != null)
			{
				var navProvider = _navigationView as ISubtreeDataProvider;
				if (navProvider != null)
				{
					return navProvider.TryGetDataProvider(n, type, out provider);
				}
			}

			return Node.ContextDataResult.Continue;
		}
	}

	/**
		Stub implementation for non-mobile platforms that don't use native navigation
	*/
	extern(!Android && !iOS) internal class DataContextTreeRendererPanel : Fuse.Controls.Panel, Node.ISubtreeDataProvider
	{
		[WeakReference]
		NativeNavigationView _navigationView;

		public DataContextTreeRendererPanel(object nativeViewHost, NativeNavigationView navigationView)
		{
			_navigationView = navigationView;
		}

		Node.ContextDataResult ISubtreeDataProvider.TryGetDataProvider(Node n, Node.DataType type, out object provider)
		{
			provider = null;

			// Forward the request to the navigation view if it exists
			if (_navigationView != null)
			{
				var navProvider = _navigationView as ISubtreeDataProvider;
				if (navProvider != null)
				{
					return navProvider.TryGetDataProvider(n, type, out provider);
				}
			}

			return Node.ContextDataResult.Continue;
		}
	}
}
