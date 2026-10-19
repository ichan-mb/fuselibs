using Uno;
using Uno.Compiler.ExportTargetInterop;

using Fuse;
using Fuse.Controls.Native;

namespace Fuse.Controls.iOS
{
	/**
		iOS ViewControllerRoot: creates an isolated native rendering context for a UIViewController.
	*/
	[ForeignInclude(Language.ObjC, "iOS/ViewControllerRootView.h")]
	[Require("source.include", "UIKit/UIKit.h")]
	extern(iOS) internal class ViewControllerRoot : IViewControllerRoot
	{
		ViewHandle _rootViewHandle;
		NativeRootViewport _viewport;
		ViewControllerFrame _frame;
		DataContextTreeRendererPanel _renderPanel;
		Visual _content;
		bool _followsOwnSize = true;

		public ViewControllerRoot(Node contextSource = null)
		{
			// Create a native UIView container for this view controller context
			_rootViewHandle = new ViewHandle(CreateiOSContainer());

			// The viewport follows this frame, not the app frame, so a page given a smaller native
			// view lays out at that size. It starts at the app frame until a size is reported.
			_frame = new ViewControllerFrame();
			_viewport = new NativeRootViewport(_rootViewHandle, _frame);

			// Forwards data-context requests back to the navigation view.
			_renderPanel = new DataContextTreeRendererPanel(this, contextSource);

			_viewport.Children.Add(_renderPanel);

			// Pages follow their own view's size; a modal is told SetFollowsOwnSize(false) and keeps
			// the app frame its insets are derived from.
			SetOnLayout(_rootViewHandle.NativeHandle, () => ReportLayout());
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

		public void SetContentSize(float2 pixelSize)
		{
			if (_frame != null)
				_frame.SetSize(pixelSize);
		}

		public void SetFollowsOwnSize(bool followsOwnSize)
		{
			_followsOwnSize = followsOwnSize;
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
			if (_frame != null)
			{
				_frame.Dispose();
				_frame = null;
			}

			if (_rootViewHandle != null)
			{
				// The view's block retains this root (and the root retains the view), so clear it
				// before disposing the view.
				ClearOnLayout(_rootViewHandle.NativeHandle);
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

		/** Lays the page out at its container's size, unless it was told not to follow it (a modal). */
		void ReportLayout()
		{
			if (_rootViewHandle == null || _frame == null || !_followsOwnSize)
				return;

			int widthPx, heightPx;
			if (!GetContainerPixelSize(_rootViewHandle.NativeHandle, out widthPx, out heightPx))
				return;

			_frame.SetSize(float2(widthPx, heightPx));
		}

		/** Asks the container to report every UIKit layout pass (see the constructor). */
		[Foreign(Language.ObjC)]
		static void SetOnLayout(ObjC.Object containerHandle, Action onLayout)
		@{
			FuseViewControllerRootView* view = (FuseViewControllerRootView*)containerHandle;
			view.onLayout = onLayout;
		@}

		/** Stops layout reporting, which also breaks the block's retain cycle; called from Dispose. */
		[Foreign(Language.ObjC)]
		static void ClearOnLayout(ObjC.Object containerHandle)
		@{
			FuseViewControllerRootView* view = (FuseViewControllerRootView*)containerHandle;
			view.onLayout = nil;
		@}

		/**
			Pixel size (points × window screen scale) of this page's own container; false while it is
			not in a window, so the page keeps the app frame until then.
		*/
		[Foreign(Language.ObjC)]
		static bool GetContainerPixelSize(ObjC.Object containerHandle, out int widthPx, out int heightPx)
		@{
			*widthPx = *heightPx = 0;

			FuseViewControllerRootView* view = (FuseViewControllerRootView*)containerHandle;
			if (view == nil || view.window == nil)
				return false;

			// Report pixels like iOSDisplay: points would lay the page out at a fraction of the view.
			CGFloat scale = view.window.screen != nil ? view.window.screen.scale : UIScreen.mainScreen.scale;
			CGSize size = view.bounds.size;
			*widthPx = (int)(size.width * scale);
			*heightPx = (int)(size.height * scale);

			return true;
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object CreateiOSContainer()
		@{
			FuseViewControllerRootView* containerView = [[FuseViewControllerRootView alloc] init];
			containerView.backgroundColor = [UIColor clearColor];
			containerView.clipsToBounds = YES;

			[containerView sizeToFit];
			containerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

			return containerView;
		@}
	}
}
