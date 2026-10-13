using Uno;
using Uno.Collections;
using Uno.Compiler.ExportTargetInterop;
using Uno.Diagnostics;
using Uno.Platform;
using Fuse;
using Fuse.Controls;
using Fuse.Controls.Native;

namespace Fuse.Platform
{
	/** Multi-window support (Android secondary displays).

		Android apps cannot create arbitrary windows on their main display, so
		each additional @Window is hosted on a secondary/external display (HDMI,
		wireless cast, a desktop-mode like Samsung DeX/ChromeOS, or a virtual
		display) using an `android.app.Presentation`, which is a window bound to a
		specific display.

		The windows are mounted onto displays as they become available, in
		declaration order, and can also be requested with @Windows.Open or
		@Fuse.Triggers.Actions.WindowOpen. Provide @Windows.ContentFactory before
		displays connect to create content for displays that do not have a staged
		declaration.
	*/
	extern(Android && !LIBRARY) public static class Windows
	{
		static Func<Visual> _contentFactory;
		/** Factory creating the content for each additional window. Must be set
			before displays connect (on app start). If null and no @Window is
			staged, additional displays get no content. */
		public static Func<Visual> ContentFactory
		{
			get { return _contentFactory; }
			set { _contentFactory = value; }
		}

		static readonly List<Window> _stagedWindows = new List<Window>();
		static readonly List<MountedWindow> _mounted = new List<MountedWindow>();
		static readonly List<Window> _declaredWindows = new List<Window>();
		static readonly List<AndroidDisplay> _availableDisplays = new List<AndroidDisplay>();
		static Window _mountingWindow;

		/** Whether a window is currently being mounted into its own display window;
			its re-rooting must not collapse/re-stage it again. */
		static internal bool IsMounting(Window window)
		{
			return _mountingWindow == window;
		}

		static internal void RegisterWindow(Window window)
		{
			if (!_declaredWindows.Contains(window))
				_declaredWindows.Add(window);
		}

		/** Whether a declaration is the app's main window: explicitly marked, or -
			if nothing is marked - the first declared window. */
		static internal bool IsMainWindow(Window window)
		{
			if (window.MainWindow)
				return true;

			for (int i = 0; i < _declaredWindows.Count; ++i)
				if (_declaredWindows[i].MainWindow)
					return false;

			return _declaredWindows.Count > 0 && _declaredWindows[0] == window;
		}

		/** Opens (or brings to front) a specific UX-declared window. If it is not
			mounted yet, it is placed on the next available secondary display. */
		public static void OpenWindow(Window window)
		{
			if (window == null)
			{
				Fuse.Diagnostics.UserError( "WindowOpen requires a Target window", window );
				return;
			}

			var m = FindMounted(window);
			if (m != null)
			{
				m.Host.BringToFront();
				return;
			}

			Fuse.Platform.WindowEvents.RaiseWillOpen(NameOf(window));

			if (!_stagedWindows.Contains(window))
				_stagedWindows.Insert(0, window);

			Open();
		}

		/** Closes a specific window (dismisses its display window). The declaration
			returns to the staged list so it can be opened again. */
		public static void CloseWindow(Window window)
		{
			if (window == null)
				return;

			var m = FindMounted(window);
			if (m == null)
			{
				_stagedWindows.Remove(window);
				return;
			}

			Fuse.Platform.WindowEvents.RaiseWillClose(NameOf(window));

			m.Host.Close();
			_mounted.Remove(m);

			// The display the window occupied is free again and can host another
			// declaration.
			if (!_availableDisplays.Contains(m.Display))
				_availableDisplays.Add(m.Display);

			m.Host.Unmount(window);

			if (!_stagedWindows.Contains(window))
				_stagedWindows.Add(window);

			Fuse.Platform.WindowEvents.RaiseClosed(NameOf(window));
		}

		/** Mounts staged windows onto the currently available secondary displays. */
		public static void Open()
		{
			MountStaged();
		}

		static MountedWindow FindMounted(Window window)
		{
			for (int i = 0; i < _mounted.Count; ++i)
				if (_mounted[i].Window == window)
					return _mounted[i];

			return null;
		}

		/** The UX-declared secondary windows, in declaration order; each mounts
			when a secondary display is available for it. */
		static internal void StageWindow(Window window)
		{
			if (IsMainWindow(window))
				return;

			if (_stagedWindows.Contains(window))
				return;

			_stagedWindows.Add(window);
		}

		static internal void UnstageWindow(Window window)
		{
			_stagedWindows.Remove(window);
		}

		static internal void WindowMainChanged(Window window)
		{
			// Nothing to remount at runtime; the flag decides at rooting time
			// which container hosts the main content.
		}

		/** Applies the title of the app's main window (the system window label). */
		static internal void SetMainWindowTitle(Window window)
		{
			if (window == null || string.IsNullOrEmpty(window.Title))
				return;

			SetActivityTitle(window.Title);
		}

		static internal void UpdateWindowTitle()
		{
			for (int i = 0; i < _declaredWindows.Count; ++i)
				if (IsMainWindow(_declaredWindows[i]))
				{
					SetMainWindowTitle(_declaredWindows[i]);
					break;
				}

			for (int i = 0; i < _mounted.Count; ++i)
				_mounted[i].Host.SetTitle(_mounted[i].Window.Title);
		}

		static Windows()
		{
			Displays.SecondaryDisplayAdded += OnSecondaryDisplayAdded;
			Displays.SecondaryDisplayDiscarded += OnSecondaryDisplayDiscarded;

			// Pick up secondary displays that were already connected when the app
			// started (the DisplayManager listener only reports later changes).
			for (int i = 0; i < Displays.All.Count; ++i)
			{
				var display = Displays.All[i] as AndroidDisplay;
				if (display != null && display.Handle != null && !_availableDisplays.Contains(display))
					_availableDisplays.Add(display);
			}
		}

		static void OnSecondaryDisplayAdded(object sender, Display display)
		{
			var androidDisplay = display as AndroidDisplay;
			if (androidDisplay == null)
				return;

			if (!_availableDisplays.Contains(androidDisplay))
				_availableDisplays.Add(androidDisplay);

			MountStaged();
		}

		/** A secondary display was removed: release the window it hosted (if any)
			and re-stage its declaration so it can be opened on another display. */
		static void OnSecondaryDisplayDiscarded(object sender, object discarded)
		{
			var display = discarded as AndroidDisplay;

			for (int i = 0; i < _mounted.Count; ++i)
			{
				var m = _mounted[i];
				if (m.Display != display)
					continue;

				_mounted.RemoveAt(i);
				m.Host.Close();
				m.Host.Unmount(m.Window);

				if (!_stagedWindows.Contains(m.Window))
					_stagedWindows.Add(m.Window);

				Fuse.Platform.WindowEvents.RaiseClosed(NameOf(m.Window));
				return;
			}

			// No window was mounted on it; just forget the display.
			_availableDisplays.Remove(display);
		}

		static void MountStaged()
		{
			while (_availableDisplays.Count > 0)
			{
				var window = NextStagedWindow();
				string title = window != null ? window.Title : null;
				Visual content = window;

				if (content == null)
				{
					// No declaration is waiting; fall back to the content factory.
					if (_contentFactory == null)
						return;

					content = _contentFactory();
				}

				if (content == null)
					return;

				var display = _availableDisplays[0];
				_availableDisplays.RemoveAt(0);

				Mount(content, title, display);
			}
		}

		/** The next declaration waiting to be shown, skipping the main window (which
			must stay in the app's main render). */
		static Window NextStagedWindow()
		{
			while (_stagedWindows.Count > 0)
			{
				var window = _stagedWindows[0];
				_stagedWindows.RemoveAt(0);

				if (!IsMainWindow(window))
					return window;
			}

			return null;
		}

		static void Mount(Visual content, string title, AndroidDisplay display)
		{
			var host = new WindowContentHost(display);

			var window = content as Window;
			if (window != null)
				_mountingWindow = window;

			host.Mount(content, title);

			if (window != null)
			{
				_mountingWindow = null;
				_mounted.Add(new MountedWindow(window, display, host));
				Fuse.Platform.WindowEvents.RaiseOpened(NameOf(window));
			}
		}

		static string NameOf(Window window)
		{
			if (window.Name != null)
				return window.Name;

			return window.Title ?? "(untitled)";
		}

		[Foreign(Language.Java)]
		static void SetActivityTitle(string title)
		@{
			com.fuse.Activity.getRootActivity().setTitle(title);
		@}
	}

	extern(Android && !LIBRARY) class MountedWindow
	{
		public readonly Window Window;
		public readonly AndroidDisplay Display;
		public readonly WindowContentHost Host;

		public MountedWindow(Window window, AndroidDisplay display, WindowContentHost host)
		{
			Window = window;
			Display = display;
			Host = host;
		}
	}

	extern(Android && !LIBRARY) class DisplayFrame : IFrame
	{
		AndroidDisplay _display;

		public DisplayFrame(AndroidDisplay display)
		{
			_display = display;
		}

		public float2 Size
		{
			get { return _display.Frame.Size; }
		}

		public event EventHandler FrameChanged
		{
			add { _display.FrameChanged += value; }
			remove { _display.FrameChanged -= value; }
		}
	}

	/** Hosts the content of a @Window in a native window (`android.app.Presentation`)
		on a secondary display, bridging Fuse visuals to a native view tree in the
		presentation's content view. */
	extern(Android && !LIBRARY) class WindowContentHost : INativeViewRoot
	{
		AndroidDisplay _display;
		RootViewport _viewport;
		TreeRendererPanel _panel;
		Java.Object _presentation;
		Java.Object _rootView;
		ViewHandle _mounted;

		public WindowContentHost(AndroidDisplay display)
		{
			_display = display;
			_rootView = CreateFrameLayout();
			_presentation = CreatePresentation(display.Handle, _rootView);
			_viewport = new NativeRootViewport(new ViewHandle(_rootView), new DisplayFrame(display));
			_panel = new TreeRendererPanel(this);
			_viewport.Children.Add(_panel);
		}

		public void Mount(Visual content, string title)
		{
			if (title != null)
				SetTitle(title);

			var window = content as Fuse.Window;
			if (window != null)
			{
				// UX-declared secondary windows carry their content as children
				// and may still sit in the main tree; detach from there first.
				var parent = window.Parent;
				var contextParent = window.PreservedContextParent ?? parent;

				if (parent != null)
					parent.Children.Remove(window);

				// Keep the app's data context (JavaScript modules, resources)
				// reachable from the new tree; bindings resolve by walking up.
				// (Unrooting clears this, so set it after detaching.)
				if (contextParent != null)
					window.OverrideContextParent = contextParent;

				window.Visibility = Fuse.Elements.Visibility.Visible;
				_panel.Children.Add(window);
				window.InvalidateLayout();
			}
			else
			{
				_panel.Children.Add(content);
			}

			Show();
		}

		/** Detaches a window's content (used when its window closes). */
		public void Unmount(Visual content)
		{
			var parent = content.Parent;
			if (parent != null)
				parent.Children.Remove(content);

			UnmountCurrent();
		}

		/** The system window title. */
		public void SetTitle(string title)
		{
			SetPresentationTitle(_presentation, title);
		}

		public void Show()
		{
			ShowPresentation(_presentation);
		}

		/** Dismisses the native window (used when it is explicitly closed). */
		public void Close()
		{
			DismissPresentation(_presentation);
		}

		public void BringToFront()
		{
			// A presentation fills its whole display, so it is already in front;
			// re-show it in case the system had dismissed it.
			ShowPresentation(_presentation);
		}

		void UnmountCurrent()
		{
			if (_mounted == null)
				return;

			RemoveView(_rootView, _mounted.NativeHandle);
			_mounted = null;
		}

		void INativeViewRoot.Add(ViewHandle handle)
		{
			UnmountCurrent();

			_mounted = handle;
			AddView(_rootView, handle.NativeHandle);
		}

		void INativeViewRoot.Remove(ViewHandle handle)
		{
			RemoveView(_rootView, handle.NativeHandle);
			if (_mounted == handle)
				_mounted = null;
		}

		//------------------------------------------------------------
		// Native

		[Foreign(Language.Java)]
		static Java.Object CreateFrameLayout()
		@{
			android.app.Activity activity = com.fuse.Activity.getRootActivity();
			android.widget.FrameLayout frame = new android.widget.FrameLayout(activity);
			frame.setLayoutParams(new android.widget.FrameLayout.LayoutParams(
				android.view.ViewGroup.LayoutParams.MATCH_PARENT,
				android.view.ViewGroup.LayoutParams.MATCH_PARENT));
			return frame;
		@}

		[Foreign(Language.Java)]
		static Java.Object CreatePresentation(Java.Object displayHandle, Java.Object contentView)
		@{
			android.app.Activity activity = com.fuse.Activity.getRootActivity();
			android.app.Presentation presentation =
				new android.app.Presentation(activity, (android.view.Display)displayHandle);
			presentation.setContentView((android.view.View)contentView);
			return presentation;
		@}

		[Foreign(Language.Java)]
		static void ShowPresentation(Java.Object presentation)
		@{
			final android.app.Presentation p = (android.app.Presentation)presentation;
			if (p.isShowing())
				return;

			com.fuse.Activity.getRootActivity().runOnUiThread(new Runnable() { public void run() {
				try {
					p.show();
				} catch (Exception e) {
					android.util.Log.e("Fuse", "Failed to show window: " + e);
				}
			}});
		@}

		[Foreign(Language.Java)]
		static void DismissPresentation(Java.Object presentation)
		@{
			final android.app.Presentation p = (android.app.Presentation)presentation;
			com.fuse.Activity.getRootActivity().runOnUiThread(new Runnable() { public void run() {
				if (p.isShowing())
					p.dismiss();
			}});
		@}

		[Foreign(Language.Java)]
		static void SetPresentationTitle(Java.Object presentation, string title)
		@{
			if (title == null)
				return;
			((android.app.Presentation)presentation).setTitle(title);
		@}

		[Foreign(Language.Java)]
		static void AddView(Java.Object parent, Java.Object child)
		@{
			android.view.View c = (android.view.View)child;
			c.setLayoutParams(new android.widget.FrameLayout.LayoutParams(
				android.view.ViewGroup.LayoutParams.MATCH_PARENT,
				android.view.ViewGroup.LayoutParams.MATCH_PARENT));
			((android.widget.FrameLayout)parent).addView(c);
		@}

		[Foreign(Language.Java)]
		static void RemoveView(Java.Object parent, Java.Object child)
		@{
			((android.widget.FrameLayout)parent).removeView((android.view.View)child);
		@}
	}
}
