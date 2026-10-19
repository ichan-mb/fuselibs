using Uno;
using Uno.Compiler.ExportTargetInterop;

using Fuse;
using Fuse.Controls.Native;

namespace Fuse.Controls.Android
{
	/**
		Android `IViewControllerRoot`: an isolated native container, viewport and tree renderer per page.
	*/
	extern(Android) internal class ViewControllerRoot : IViewControllerRoot
	{
		ViewHandle _rootViewHandle;
		NativeRootViewport _viewport;
		ViewControllerFrame _frame;
		DataContextTreeRendererPanel _renderPanel;
		Visual _content;
		bool _followsOwnSize = true;

		public ViewControllerRoot(Node contextSource = null)
		{
			_rootViewHandle = ViewFactory.InstantiateViewGroup();

			// The frame keeps the app frame until the platform reports the size this page's view was given.
			_frame = new ViewControllerFrame();
			_viewport = new NativeRootViewport(_rootViewHandle, _frame);

			_renderPanel = new DataContextTreeRendererPanel(this, contextSource);
			_viewport.Children.Add(_renderPanel);

			// Something must consume a press nothing inside the page takes, or Fuse keeps the pointer down
			// and drops the next tap (a modal's Close would need two taps); setClickable does that here.
			Fuse.Controls.Native.Android.InputDispatch.AddListener(_rootViewHandle, _renderPanel);
			TakeUnhandledPresses(_rootViewHandle.NativeHandle);

			// A page lays out at the size its own view is given; a modal keeps the app frame instead
			// (see SetFollowsOwnSize), since its insets are derived from that.
			ObserveSizeChanged(_rootViewHandle.NativeHandle);
		}

		/** Has the given view report its size to this page's frame every time Android lays it out. */
		[Foreign(Language.Java)]
		void ObserveSizeChanged(Java.Object view)
		@{
			android.view.View v = (android.view.View)view;
			v.addOnLayoutChangeListener(new android.view.View.OnLayoutChangeListener() {
				public void onLayoutChange(android.view.View view, int left, int top, int right, int bottom,
						int oldLeft, int oldTop, int oldRight, int oldBottom)
				{
					if (right - left == oldRight - oldLeft && bottom - top == oldBottom - oldTop)
						return;

					@{global::Fuse.Controls.Android.ViewControllerRoot:of(_this).ReportSize(int,int):call(right - left, bottom - top)};
				}
			});
		@}

		/** Reports the size the page's own view was given, in pixels, so the page lays out at it. */
		void ReportSize(int widthPx, int heightPx)
		{
			// A modal keeps the app frame, which is what its insets are derived from.
			if (_frame == null || !_followsOwnSize)
				return;

			_frame.SetSize(float2(widthPx, heightPx));
		}

		/** Makes the given view take a press that nothing inside the page takes (see the constructor). */
		[Foreign(Language.Java)]
		static void TakeUnhandledPresses(Java.Object view)
		@{
			((android.view.View)view).setClickable(true);
		@}

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

			_viewport = null;
			if (_frame != null)
			{
				_frame.Dispose();
				_frame = null;
			}

			if (_rootViewHandle != null)
			{
				_rootViewHandle.Dispose();
				_rootViewHandle = null;
			}

			_renderPanel = null;
		}

		void INativeViewRoot.Add(ViewHandle handle)
		{
			if (_rootViewHandle != null && handle != null)
			{
				_rootViewHandle.InsertChild(handle);
			}
		}

		void INativeViewRoot.Remove(ViewHandle handle)
		{
			if (handle != null && _rootViewHandle != null)
			{
				_rootViewHandle.RemoveChild(handle);
			}
		}
	}
}
