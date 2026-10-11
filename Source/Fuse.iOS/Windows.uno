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
	/** Multi-window support (UIKit scenes, iPad multitasking, dual-screen devices).

		When the generated app declares `supportsMultipleScenes`, every additional
		scene session gets its own window. Mount content in those windows by
		providing @Windows.ContentFactory before sessions connect; each new
		window's content is created by invoking the factory once.
	*/
	[Require("source.include", "UIKit/UIKit.h")]
	extern(iOS && !LIBRARY) public static class Windows
	{
		static Func<Visual> _contentFactory;
		/** Factory creating the content for each additional scene window. Must
			be set before sessions connect (on app start). If null, additional
			windows have no content. */
		public static Func<Visual> ContentFactory
		{
			get { return _contentFactory; }
			set { _contentFactory = value; }
		}

		static readonly List<Window> _stagedWindows = new List<Window>();
		static readonly List<MountedWindow> _mounted = new List<MountedWindow>();
		static readonly List<Window> _declaredWindows = new List<Window>();
		static Window _mountingWindow;

		/** Whether a window is currently being mounted into its own scene window;
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
			mounted yet, a scene session is requested and the window mounts when
			it connects. */
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
				if (IsWindowAlive(m.Display.Window))
				{
					ActivateScene(m.Display.Window);
					return;
				}

				// The window was closed by the system (its scene discarded); forget
				// the stale mount so a fresh window can be requested below.
				_mounted.Remove(m);
				m.Host.Unmount(window);
				Fuse.Platform.WindowEvents.RaiseClosed(NameOf(window));
			}

			Fuse.Platform.WindowEvents.RaiseWillOpen(NameOf(window));

			if (!_stagedWindows.Contains(window))
				_stagedWindows.Insert(0, window);

			Open();
		}

		/** Closes a specific window (destroys its scene session). The declaration
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

			CloseScene(m.Display.Window);
			_mounted.Remove(m);

			m.Host.Unmount(window);

			if (!_stagedWindows.Contains(window))
				_stagedWindows.Add(window);

			Fuse.Platform.WindowEvents.RaiseClosed(NameOf(window));
		}

		static MountedWindow FindMounted(Window window)
		{
			for (int i = 0; i < _mounted.Count; ++i)
				if (_mounted[i].Window == window)
					return _mounted[i];

			return null;
		}

		[Foreign(Language.ObjC)]
		static bool IsWindowAlive(ObjC.Object window)
		@{
			UIWindow* w = (UIWindow*)window;
			// A window closed by the system is hidden and/or detached from any
			// scene; such a window can no longer be activated.
			return !w.hidden && [w windowScene] != nil;
		@}

		[Foreign(Language.ObjC)]
		static void ActivateScene(ObjC.Object window)
		@{
			UIScene* scene = [(UIWindow*)window windowScene];
			if (scene == nil)
				return;

			[UIApplication.sharedApplication
				requestSceneSessionActivation:scene.session
				userActivity:nil
				options:nil
				errorHandler:^(NSError *error)
				{
					NSLog(@"Fuse.Platform.Windows.ActivateScene failed: %@", error);
				}];
		@}

		[Foreign(Language.ObjC)]
		static void CloseScene(ObjC.Object window)
		@{
			UIScene* scene = [(UIWindow*)window windowScene];
			if (scene == nil)
				return;

			[UIApplication.sharedApplication
				requestSceneSessionDestruction:scene.session
				options:nil
				errorHandler:^(NSError *error)
				{
					NSLog(@"Fuse.Platform.Windows.CloseScene failed: %@", error);
				}];
		@}

		/** The UX-declared secondary windows, in declaration order; each mounts
			when an additional scene session connects. */
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
			// Nothing to remount at runtime in this phase; the flag decides at
			// rooting time which container hosts the main content.
		}

		/** Applies the title of the app's main window (the system window title). */
		static internal void SetMainWindowTitle(Window window)
		{
			if (window == null || string.IsNullOrEmpty(window.Title))
				return;

			var display = Uno.Platform.Displays.MainDisplay as iOSDisplay;
			if (display == null)
				return;

			WindowContentHost.ApplyTitle(display.Window, window.Title);
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
				WindowContentHost.ApplyTitle(_mounted[i].Display.Window, _mounted[i].Window.Title);
		}

		static Windows()
		{
			Displays.SecondaryDisplayAdded += OnSecondaryDisplayAdded;
			Displays.SecondaryDisplayDiscarded += OnSecondaryDisplayDiscarded;
		}

		/** The system discarded a window (the user closed it); release its content
			and re-stage its declaration so it can be opened again. */
		static void OnSecondaryDisplayDiscarded(object sender, object displayWindow)
		{
			for (int i = 0; i < _mounted.Count; ++i)
			{
				var m = _mounted[i];
				if (!IsSameWindow(m.Display.Window, (ObjC.Object)displayWindow))
					continue;

				_mounted.RemoveAt(i);
				m.Host.Unmount(m.Window);

				if (!_stagedWindows.Contains(m.Window))
					_stagedWindows.Add(m.Window);

				Fuse.Platform.WindowEvents.RaiseClosed(NameOf(m.Window));
				return;
			}
		}

		static string NameOf(Window window)
		{
			if (window.Name != null)
				return window.Name;

			return window.Title ?? "(untitled)";
		}

		[Foreign(Language.ObjC)]
		static bool IsSameWindow(ObjC.Object a, ObjC.Object b)
		@{
			return a == b;
		@}

		static void OnSecondaryDisplayAdded(object sender, Display display)
		{
			Visual content = null;
			string title = null;

			if (_stagedWindows.Count > 0)
			{
				while (_stagedWindows.Count > 0)
				{
					var w = _stagedWindows[0];
					_stagedWindows.RemoveAt(0);

					// Defensive: a main window must never be mounted into its own
					// window; that would move the app's main content.
					if (IsMainWindow(w))
						continue;

					content = w;
					title = w.Title;
					break;
				}
			}
			else if (_contentFactory != null)
			{
				content = _contentFactory();
			}

			if (content == null)
				return;

			var host = new WindowContentHost((iOSDisplay)display);

			var window = content as Window;
			if (window != null)
				_mountingWindow = window;

			host.Mount(content, title);

			if (window != null)
			{
				_mountingWindow = null;
				_mounted.Add(new MountedWindow(window, (iOSDisplay)display, host));
				Fuse.Platform.WindowEvents.RaiseOpened(NameOf(window));
			}
		}

		/** Requests a new scene session from the OS (iPad multitasking; on
			devices that don't support multiple windows the request is rejected
			gracefully). */
		[Foreign(Language.ObjC)]
		public static void Open()
		@{
			if (@available(iOS 13.0, *))
			{
				[UIApplication.sharedApplication
					requestSceneSessionActivation:nil
					userActivity:nil
					options:nil
					errorHandler:^(NSError *error)
					{
						NSLog(@"Fuse.Platform.Windows.Open failed: %@", error);
					}];
			}
		@}
	}

	extern(iOS) class MountedWindow
	{
		public readonly Window Window;
		public readonly iOSDisplay Display;
		public readonly WindowContentHost Host;

		public MountedWindow(Window window, iOSDisplay display, WindowContentHost host)
		{
			Window = window;
			Display = display;
			Host = host;
		}
	}

	extern(iOS) class DisplayFrame : IFrame
	{
		iOSDisplay _display;

		public DisplayFrame(iOSDisplay display)
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

	extern(iOS) class WindowContentHost : INativeViewRoot
	{
		iOSDisplay _display;
		RootViewport _viewport;
		TreeRendererPanel _panel;
		ObjC.Object _rootView;
		ViewHandle _mounted;

		public WindowContentHost(iOSDisplay display)
		{
			_display = display;
			_rootView = GetWindowRootView(display.Window);
			_viewport = new NativeRootViewport(new ViewHandle(_rootView), new DisplayFrame(display));
			_panel = new TreeRendererPanel(this);
			_viewport.Children.Add(_panel);
		}

		public void Mount(Visual content, string title)
		{
			if (title != null)
				ApplyTitle(_display.Window, title);

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
				return;
			}

			_panel.Children.Add(content);
		}

		/** Detaches a window's content (used when its window closes). */
		public void Unmount(Visual content)
		{
			var parent = content.Parent;
			if (parent != null)
				parent.Children.Remove(content);
		}

		/** Sets the system window title. The window may not be attached to its scene
			yet (it is assigned right after mounting), so retry shortly. */
		[Foreign(Language.ObjC)]
		internal static void ApplyTitle(ObjC.Object window, string title)
		@{
			if (window == nil || title == nil)
				return;

			UIWindow* w = (UIWindow*)window;
			UIScene* scene = [w windowScene];

			if (scene != nil)
			{
				[scene setTitle: title];
				return;
			}

			__block int attempts = 0;
			__block void (^trySet)(void);
			trySet = ^{
				UIScene* s = [(UIWindow*)w windowScene];
				if (s != nil)
				{
					[s setTitle: title];
					return;
				}

				if (++attempts < 10)
					dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), trySet);
			};

			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), trySet);
		@}

		void UnmountCurrent()
		{
			if (_mounted == null)
				return;

			RemoveFromSuperview(_mounted.NativeHandle);
			_mounted = null;
		}

		void INativeViewRoot.Add(ViewHandle handle)
		{
			UnmountCurrent();

			_mounted = handle;
			AddSubview(_rootView, handle.NativeHandle);
		}

		void INativeViewRoot.Remove(ViewHandle handle)
		{
			RemoveFromSuperview(handle.NativeHandle);
			if (_mounted == handle)
				_mounted = null;
		}

		[Foreign(Language.ObjC)]
		static ObjC.Object GetWindowRootView(ObjC.Object window)
		@{
			return [(UIWindow*)window rootViewController].view;
		@}

		[Foreign(Language.ObjC)]
		static void AddSubview(ObjC.Object root, ObjC.Object view)
		@{
			UIView* v = (UIView*)view;
			v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
			[(UIView*)root addSubview: v];
		@}

		[Foreign(Language.ObjC)]
		static void RemoveFromSuperview(ObjC.Object view)
		@{
			[(UIView*)view removeFromSuperview];
		@}
	}
}