using Uno;
using Uno.UX;

using Fuse.Scripting;

namespace Fuse.Controls
{
	/**
		The FuseJS module exposing `NativeNavigationView`'s modals.

		```javascript
		var nav = require("NativeNavigation");

		nav.present("ModalPage", { title: "Hello", closeModal: function() { nav.dismiss(); } });
		nav.present("Filters", data, "sheet", true, false); // style, dragToDismiss, expandable
		nav.setExpanded(true);  // full height, or false for its own height back
		nav.dismiss();
		```

		The style argument is `fullScreen` (the default), `pageSheet`, `formSheet` or `sheet`. The methods
		operate on the most recently rooted `NativeNavigationView`.
	*/
	[UXGlobalModule]
	public sealed class NativeNavigationModule : NativeModule
	{
		static NativeNavigationModule _instance;

		public NativeNavigationModule()
		{
			if (_instance != null)
				return;
			_instance = this;

			Resource.SetGlobalKey(this, "NativeNavigation");

			AddMember(new NativeFunction("present", (NativeCallback)Present));
			AddMember(new NativeFunction("setExpanded", (NativeCallback)SetExpanded));
			AddMember(new NativeFunction("dismiss", (NativeCallback)Dismiss));
		}

		static object Present(Context c, object[] args)
		{
			if (args.Length < 1 || args[0] == null)
				return null;

			var templateName = args[0].ToString();

			// Reflect the live JS value on the JS thread before handing it to the UI thread; using the raw
			// handle off-thread would call into the JS engine and the bindings would never resolve.
			object data = args.Length > 1 ? c.Reflect(args[1]) : null;

			var style = args.Length > 2 ? ParseStyle(args[2]) : ModalPresentationStyle.FullScreen;
			var dragToDismiss = args.Length <= 3 || !(args[3] is bool) || (bool)args[3];
			var expandable = args.Length <= 4 || !(args[4] is bool) || (bool)args[4];

			// Runs on the JavaScript thread: marshal to the UI thread before touching Fuse/UIKit state.
			Fuse.UpdateManager.Dispatcher.Invoke(() => {
				var nav = NativeNavigationView.Active;
				if (nav != null)
					nav.PresentTemplate(templateName, data, style, dragToDismiss, expandable);
			});

			return null;
		}

		/** Gives the modal on screen the full height (`true`), or its own height back. */
		static object SetExpanded(Context c, object[] args)
		{
			var expanded = args.Length > 0 && args[0] is bool && (bool)args[0];

			Fuse.UpdateManager.Dispatcher.Invoke(() => {
				var nav = NativeNavigationView.Active;
				if (nav != null)
					nav.SetModalExpanded(expanded);
			});

			return null;
		}

		/** Parses a `ModalPresentationStyle` name, case-insensitively. An unknown name warns and is ignored. */
		static ModalPresentationStyle ParseStyle(object value)
		{
			var name = value != null ? value.ToString() : null;
			if (string.IsNullOrEmpty(name))
				return ModalPresentationStyle.FullScreen;

			// Uno does not support switching on a string.
			var lower = name.ToLower();
			if (lower == "fullscreen" || lower == "full-screen")
				return ModalPresentationStyle.FullScreen;
			if (lower == "pagesheet" || lower == "page-sheet")
				return ModalPresentationStyle.PageSheet;
			if (lower == "formsheet" || lower == "form-sheet")
				return ModalPresentationStyle.FormSheet;
			if (lower == "sheet")
				return ModalPresentationStyle.Sheet;

			Fuse.Diagnostics.UserWarning("Unknown modal presentation style '" + name + "', using fullScreen", typeof(NativeNavigationModule));
			return ModalPresentationStyle.FullScreen;
		}

		static object Dismiss(Context c, object[] args)
		{
			Fuse.UpdateManager.Dispatcher.Invoke(() => {
				var nav = NativeNavigationView.Active;
				if (nav != null)
					nav.DismissModal();
			});

			return null;
		}
	}
}
