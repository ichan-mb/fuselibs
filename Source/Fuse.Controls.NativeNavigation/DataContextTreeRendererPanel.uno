using Uno;

using Fuse;
using Fuse.Controls.Native;
using Fuse.Navigation;

namespace Fuse.Controls
{
	/**
		A `TreeRendererPanel` that forwards data-context requests to the view that created the isolated
		rendering context, so bindings in a template instance still resolve.
	*/
	extern(Android || iOS) internal class DataContextTreeRendererPanel : TreeRendererPanel, Node.ISubtreeDataProvider
	{
		[WeakReference]
		Node _contextSource;

		public DataContextTreeRendererPanel(INativeViewRoot nativeViewHost, Node contextSource)
			: base(nativeViewHost)
		{
			_contextSource = contextSource;
		}

		Node.ContextDataResult ISubtreeDataProvider.TryGetDataProvider(Node n, Node.DataType type, out object provider)
		{
			provider = null;

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

			if (_contextSource != null)
			{
				var navProvider = _contextSource as ISubtreeDataProvider;
				if (navProvider != null)
					return navProvider.TryGetDataProvider(n, type, out provider);
			}

			return Node.ContextDataResult.Continue;
		}
	}

	/**
		Stub for platforms without native navigation.
	*/
	extern(!Android && !iOS) internal class DataContextTreeRendererPanel : Fuse.Controls.Panel, Node.ISubtreeDataProvider
	{
		[WeakReference]
		Node _contextSource;

		public DataContextTreeRendererPanel(object nativeViewHost, Node contextSource)
		{
			_contextSource = contextSource;
		}

		Node.ContextDataResult ISubtreeDataProvider.TryGetDataProvider(Node n, Node.DataType type, out object provider)
		{
			provider = null;

			if (_contextSource != null)
			{
				var navProvider = _contextSource as ISubtreeDataProvider;
				if (navProvider != null)
					return navProvider.TryGetDataProvider(n, type, out provider);
			}

			return Node.ContextDataResult.Continue;
		}
	}
}
