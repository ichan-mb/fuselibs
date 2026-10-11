using Uno;
using Uno.UX;

namespace Fuse.Platform
{
	/** Window lifecycle events.

		These are exposed to JavaScript as the `FuseJS/Windows` module; the
		argument of each event is the `ux:Name` of the window.
	*/
	public static class WindowEvents
	{
		/** A window is about to be requested/opened. */
		public static event Action<string> WillOpen;
		/** A window has been opened (its content is mounted and visible). */
		public static event Action<string> Opened;
		/** A window is about to be closed. */
		public static event Action<string> WillClose;
		/** A window has been closed. */
		public static event Action<string> Closed;

		public static void RaiseWillOpen(string name)
		{
			var handler = WillOpen;
			if (handler != null)
				handler(name);
		}

		public static void RaiseOpened(string name)
		{
			var handler = Opened;
			if (handler != null)
				handler(name);
		}

		public static void RaiseWillClose(string name)
		{
			var handler = WillClose;
			if (handler != null)
				handler(name);
		}

		public static void RaiseClosed(string name)
		{
			var handler = Closed;
			if (handler != null)
				handler(name);
		}
	}
}