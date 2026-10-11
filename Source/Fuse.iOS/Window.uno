using Uno;
using Fuse.Platform;

namespace Fuse
{
	/** Declares a window for the app.

		One window must be marked `MainWindow="true"`; its content is the app's
		primary window content (on iOS this is the window the whole app has
		always rendered into).

		Every other window mounts as soon as an additional scene session
		connects (iPad multitasking, dual-screen devices) or when
		@Fuse.Platform.Windows.Open requests one.

		## Example
		```xml
			<App>
				<Window Title="Main" MainWindow="true">
					<Text Value="Hello in the main window" />
				</Window>
			</App>
		```
	*/
	extern(iOS && !LIBRARY) public class Window : Fuse.Controls.Panel
	{
		// The node the window was originally rooted under (the app), used to
		// keep its data context (JavaScript modules, resources) reachable
		// once it is moved into its own scene window.
		internal Node PreservedContextParent;

		string _title;
		/** Name shown for this window where the system presents windows
			(app switcher, Stage Manager). */
		public string Title
		{
			get { return _title; }
			set
			{
				_title = value;
				if (IsRootingCompleted)
					Fuse.Platform.Windows.UpdateWindowTitle();
			}
		}

		bool _mainWindow;
		/** Marks this window as the app's main window. Exactly one should
			have this. */
		public bool MainWindow
		{
			get { return _mainWindow; }
			set
			{
				_mainWindow = value;

				if (IsRootingCompleted)
					Fuse.Platform.Windows.WindowMainChanged(this);
			}
		}

		protected override void OnRooted()
		{
			base.OnRooted();

			if (PreservedContextParent == null && Parent != null)
				PreservedContextParent = Parent;

			Fuse.Platform.Windows.RegisterWindow(this);

			if (Fuse.Platform.Windows.IsMainWindow(this))
			{
				Fuse.Platform.Windows.SetMainWindowTitle(this);
				return;
			}

			// Being (re-)rooted as part of mounting into its own scene window:
			// leave it visible there.
			if (Fuse.Platform.Windows.IsMounting(this))
				return;

			// Hidden in the main render until it is mounted in its own window
			// by the scene session that grants it.
			Visibility = Fuse.Elements.Visibility.Collapsed;
			Fuse.Platform.Windows.StageWindow(this);
		}

		protected override void OnUnrooted()
			{
				Fuse.Platform.Windows.UnstageWindow(this);
				base.OnUnrooted();
			}
		}

		/** Library (preview/editor) builds on iOS: declared windows render inline;
			native scene windows are app-only for now. */
		extern(iOS && LIBRARY) public class Window : Fuse.Controls.Panel
		{
			/** Name shown for this window where the system presents windows. */
			public string Title { get; set; }

			/** Marks this window as the app's main window. */
			public bool MainWindow { get; set; }
		}
	}