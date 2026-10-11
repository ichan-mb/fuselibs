using Uno.UX;
using Fuse.Platform;
using Fuse.Scripting;

namespace FuseJS
{
	[UXGlobalModule]
	/** Window lifecycle events.

		Listen for the lifecycle of @Fuse.Window declarations. Each event is
		passed the `ux:Name` of the window it refers to.

		This module is an @EventEmitter, so the methods from @EventEmitter can
		be used to listen to events.

		## Example
		```xml
			<JavaScript>
				var Windows = require("FuseJS/Windows");

				Windows.on("willOpen", function(name) {
					console.log("window will open: " + name);
				});
				Windows.on("opened", function(name) {
					console.log("window opened: " + name);
				});
				Windows.on("willClose", function(name) {
					console.log("window will close: " + name);
				});
				Windows.on("closed", function(name) {
					console.log("window closed: " + name);
				});
			</JavaScript>
		```

		## Events
		- `willOpen` — a window is about to be opened
		- `opened` — the window has opened (its content is mounted and visible)
		- `willClose` — the window is about to be closed
		- `closed` — the window has been closed

		@scriptevent willOpen
		@param name (String) The `ux:Name` of the window.

		@scriptevent opened
		@param name (String) The `ux:Name` of the window.

		@scriptevent willClose
		@param name (String) The `ux:Name` of the window.

		@scriptevent closed
		@param name (String) The `ux:Name` of the window.
	*/
	public sealed class Windows : NativeEventEmitterModule
	{
		static readonly Windows _instance;

		public Windows()
			: base(true,
				"willOpen",
				"opened",
				"willClose",
				"closed")
		{
			if (_instance != null)
				return;

			Resource.SetGlobalKey(_instance = this, "FuseJS/Windows");

			Fuse.Platform.WindowEvents.WillOpen += OnWillOpen;
			Fuse.Platform.WindowEvents.Opened += OnOpened;
			Fuse.Platform.WindowEvents.WillClose += OnWillClose;
			Fuse.Platform.WindowEvents.Closed += OnClosed;
		}

		void OnWillOpen(string name)
		{
			Emit("willOpen", name);
		}

		void OnOpened(string name)
		{
			Emit("opened", name);
		}

		void OnWillClose(string name)
		{
			Emit("willClose", name);
		}

		void OnClosed(string name)
		{
			Emit("closed", name);
		}
	}
}