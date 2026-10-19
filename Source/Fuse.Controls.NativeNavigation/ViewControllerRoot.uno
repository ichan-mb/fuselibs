using Uno;

using Fuse;
using Fuse.Controls.Native;

namespace Fuse.Controls
{
	/**
		Drives a page's Fuse viewport from the size its native view was actually given, rather than the app
		frame (see the platform ViewControllerRoot implementations). A modal keeps the app frame, which is
		what its insets are derived from, and is answered for by its presentation (see `OnModalLaidOut`).

		Until a size is reported this is the app frame, so it also follows it: the initial page is created
		before the app frame is known, and a viewport sized once at zero never draws anything.
	*/
	internal class ViewControllerFrame : IFrame, IDisposable
	{
		float2 _size;
		bool _reported;
		RootViewport _appViewport;

		public event EventHandler FrameChanged;

		public ViewControllerFrame()
		{
			var app = Fuse.AppBase.Current;
			if (app != null && app.RootViewport != null)
			{
				_appViewport = app.RootViewport;
				_appViewport.Resized += OnAppViewportResized;
			}
		}

		void OnAppViewportResized(float2 size)
		{
			// Once the platform has reported a size, that is the page's own size rather than the app frame.
			if (_reported)
				return;

			if (FrameChanged != null)
				FrameChanged(this, EventArgs.Empty);
		}

		public float2 Size
		{
			get
			{
				if (_reported)
					return _size;

				// Read lazily: the app frame may not be known when this is created.
				var app = Fuse.AppBase.Current;
				return app != null && app.RootViewport != null ? app.RootViewport.PixelSize : float2(0);
			}
		}

		/** Sets the size the content was given, in pixels, and re-lays the page out when it changes. */
		public void SetSize(float2 size)
		{
			if (size.X <= 0 || size.Y <= 0)
				return;

			if (_reported && _size == size)
				return;

			_size = size;
			_reported = true;

			if (FrameChanged != null)
				FrameChanged(this, EventArgs.Empty);
		}

		public void Dispose()
		{
			if (_appViewport != null)
			{
				_appViewport.Resized -= OnAppViewportResized;
				_appViewport = null;
			}
		}
	}

	/**
		Cross-platform `ViewControllerRoot` that delegates to the platform implementation (see
		`ViewControllerRootFactory`), creating an isolated native view hierarchy per page.
	*/
	internal class ViewControllerRoot : IViewControllerRoot
	{
		readonly IViewControllerRoot _platformImpl;

		public ViewControllerRoot(Node contextSource = null)
		{
			// Create platform-specific implementation through factory
			_platformImpl = ViewControllerRootFactory.Create(contextSource);
		}

		// Delegate all interface methods to the platform implementation.
		public void SetContent(Visual content)
		{
			_platformImpl.SetContent(content);
		}

		public void SetContentSize(float2 pixelSize)
		{
			_platformImpl.SetContentSize(pixelSize);
		}

		public void SetFollowsOwnSize(bool followsOwnSize)
		{
			_platformImpl.SetFollowsOwnSize(followsOwnSize);
		}

		public object GetNativeHandle()
		{
			return _platformImpl.GetNativeHandle();
		}

		public void Dispose()
		{
			_platformImpl.Dispose();
		}

		// INativeViewRoot implementation
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
