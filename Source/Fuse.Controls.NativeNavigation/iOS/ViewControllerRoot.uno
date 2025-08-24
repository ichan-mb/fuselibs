using Uno;
using Uno.Compiler.ExportTargetInterop;
using Fuse;
using Fuse.Controls;
using Fuse.Controls.Native;
using Fuse.Elements;

namespace Fuse.Controls.iOS
{
	/**
		iOS-specific ViewControllerRoot implementation that creates isolated native rendering contexts
		for UIViewController integration. This follows the same pattern as iOSApp.uno for proper
		integration with Fuse's rendering pipeline.
	*/
	extern(!iOS) internal class ViewControllerRoot : IViewControllerRoot
	{
		// Stub implementation for non-iOS platforms
		public void SetContent(Visual content) { }
		public ViewHandle GetViewHandle() { return null; }
		public object GetNativeHandle() { return null; }
		public void Dispose() { }
		void INativeViewRoot.Add(ViewHandle handle) { }
		void INativeViewRoot.Remove(ViewHandle handle) { }
	}

	[Require("source.include", "UIKit/UIKit.h")]
	extern(iOS) internal class ViewControllerRoot : IViewControllerRoot
	{
		ViewHandle _rootViewHandle;
		NativeRootViewport _viewport;
		TreeRendererPanel _renderPanel;
		Visual _content;

		public ViewControllerRoot()
		{
			// Create a native UIView container for this view controller context
			_rootViewHandle = new ViewHandle(CreateiOSContainer());

			// Create viewport to manage the TreeRendererPanel (like iOSApp does)
			_viewport = new NativeRootViewport(_rootViewHandle);

			// Create the tree renderer panel that will manage native rendering
			_renderPanel = new TreeRendererPanel(this);

			// Add TreeRendererPanel to viewport - CRITICAL for proper rendering!
			// This follows the same pattern as iOSApp.uno
			_viewport.Children.Add(_renderPanel);
		}

		public void SetContent(Visual content)
		{
			if (_content != null)
			{
				_renderPanel.Children.Remove(_content);
			}

			_content = content;

			if (_content != null)
			{
				_renderPanel.Children.Add(_content);
			}
		}

		public ViewHandle GetViewHandle()
		{
			return _rootViewHandle;
		}

		public object GetNativeHandle()
		{
			return _rootViewHandle.NativeHandle;
		}

		public void Dispose()
		{
			if (_content != null)
			{
				_renderPanel.Children.Remove(_content);
				_content = null;
			}

			if (_renderPanel != null && _viewport != null)
			{
				_viewport.Children.Remove(_renderPanel);
			}

			if (_viewport != null)
			{
				_viewport = null;
			}

			if (_rootViewHandle != null)
			{
				_rootViewHandle.Dispose();
				_rootViewHandle = null;
			}

			_renderPanel = null;
		}

		// INativeViewRoot implementation for iOS
		void INativeViewRoot.Add(ViewHandle handle)
		{
			if (_rootViewHandle != null && handle != null)
			{
				_rootViewHandle.InsertChild(handle);
			}
		}

		void INativeViewRoot.Remove(ViewHandle handle)
		{
			if (handle != null)
			{
				_rootViewHandle.RemoveChild(handle);
			}
		}

		[Foreign(Language.ObjC)]
		static ObjC.Object CreateiOSContainer()
		@{
			UIView* containerView = [[UIView alloc] init];
			containerView.backgroundColor = [UIColor clearColor];
			containerView.clipsToBounds = YES;

			// Set up auto-resizing for proper layout
			[containerView sizeToFit];
			containerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

			return containerView;
		@}

		[Foreign(Language.ObjC)]
		static void AddSubview(ObjC.Object parentHandle, ObjC.Object childHandle)
		@{
			UIView* parent = (UIView*)parentHandle;
			UIView* child = (UIView*)childHandle;

			if (parent && child) {
				[parent addSubview:child];
			}
		@}

		[Foreign(Language.ObjC)]
		static void RemoveFromSuperview(ObjC.Object childHandle)
		@{
			UIView* child = (UIView*)childHandle;

			if (child) {
				[child removeFromSuperview];
			}
		@}
	}
}
