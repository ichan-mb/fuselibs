using Uno;
using Fuse.Controls;

namespace Fuse
{
	/** Declares a window for the app.

		The desktop preview renders all declared windows inline, one after the
		other; native multi-window support is iOS-only for now. The properties
		are accepted so that UX using @Window remains portable.
	*/
	extern(!MOBILE) public class Window : Fuse.Controls.Panel
	{
		/** Name shown for this window where the system presents windows.
			Ignored on this platform for now. */
		public string Title { get; set; }

		/** Marks this window as the app's main window. Ignored on this platform
			for now. */
		public bool MainWindow { get; set; }
	}
}