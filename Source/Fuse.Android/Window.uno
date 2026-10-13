using Uno;
using Fuse.Platform;

namespace Fuse
{
	/** Declares a window for the app.

		One window must be marked `MainWindow="true"`; its content is the app's
		primary window content (on Android this is the window the whole app has
		always rendered into).

		Every other window is hosted in its own native window on a secondary
		/external display (`android.app.Presentation`), in declaration order, as
		displays become available. Android apps cannot create arbitrary windows on
		the main display, so on a device with a single display these declarations
		remain unshown until one is attached or requested with
		@Fuse.Triggers.Actions.WindowOpen.

		## Example
		```xml
			<App>
				<Window Title="Main" MainWindow="true">
					<Text Value="Hello in the main window" />
				</Window>
			</App>
		```
	*/
	extern(Android && !LIBRARY) public class Window : Fuse.Controls.Panel
	{
		// The node the window was originally rooted under (the app), used to
		// keep its data context (JavaScript modules, resources) reachable
		// once it is moved into its own display window.
		internal Node PreservedContextParent;

		string _title;
		/** Name shown for this window where the system presents windows. */
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
		/** Marks this window as the app's main window. Exactly one should have
			this. */
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

			// Being (re-)rooted as part of mounting into its own display window:
			// leave it visible there.
			if (Fuse.Platform.Windows.IsMounting(this))
				return;

			// Hidden in the main render until it is mounted in its own window on
			// a secondary display.
			Visibility = Fuse.Elements.Visibility.Collapsed;
			Fuse.Platform.Windows.StageWindow(this);
		}

		protected override void OnUnrooted()
		{
			Fuse.Platform.Windows.UnstageWindow(this);
			base.OnUnrooted();
		}
	}

	/** Library (preview/editor) builds on Android: declared windows render inline;
		native display windows are app-only for now. */
	extern(Android && LIBRARY) public class Window : Fuse.Controls.Panel
	{
		/** Name shown for this window where the system presents windows. */
		public string Title { get; set; }

		/** Marks this window as the app's main window. */
		public bool MainWindow { get; set; }
	}
}
