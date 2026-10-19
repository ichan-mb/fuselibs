using Uno;
using Uno.UX;

using Fuse.Scripting;

namespace Fuse.Controls
{
	/**
		A FuseJS module that selects tabs in the most recently rooted `NativeTabNavigationView`.

		```javascript
		var tabs = require("NativeTabNavigation");
		tabs.select("Search");
		tabs.selectIndex(1);
		```
	*/
	[UXGlobalModule]
	public sealed class NativeTabNavigationModule : NativeModule
	{
		static NativeTabNavigationModule _instance;
		static Fuse.Scripting.Function _onSelected;
		static Context _selectedContext;

		public NativeTabNavigationModule()
		{
			if (_instance != null)
				return;
			_instance = this;

			Resource.SetGlobalKey(this, "NativeTabNavigation");

			AddMember(new NativeFunction("select", (NativeCallback)Select));
			AddMember(new NativeFunction("selectIndex", (NativeCallback)SelectIndex));
			AddMember(new NativeFunction("add", (NativeCallback)Add));
			AddMember(new NativeFunction("remove", (NativeCallback)Remove));
			AddMember(new NativeFunction("onSelected", (NativeCallback)OnSelected));

			NativeTabNavigationView.SelectedIndexChangedGlobal += OnSelectedIndexChanged;
		}

		/** Runs `action` on the active view, on the UI thread. */
		static void WithActive(Action<NativeTabNavigationView> action)
		{
			Fuse.UpdateManager.Dispatcher.Invoke(() => {
				var tabs = NativeTabNavigationView.Active;
				if (tabs != null)
					action(tabs);
			});
		}

		static object Select(Context c, object[] args)
		{
			if (args.Length < 1 || args[0] == null)
				return null;

			var templateName = args[0].ToString();
			WithActive(tabs => tabs.SelectTab(templateName));
			return null;
		}

		/**
			Registers the function called when the selected tab changes, with the new index. Passing null
			removes it.
		*/
		static object OnSelected(Context c, object[] args)
		{
			_onSelected = args.Length > 0 ? args[0] as Fuse.Scripting.Function : null;
			_selectedContext = _onSelected != null ? c : null;

			// Report the current selection so a late registration has the right starting state.
			var tabs = NativeTabNavigationView.Active;
			if (_onSelected != null && tabs != null && tabs.SelectedIndex >= 0)
				_onSelected.Call(c, new object[] { tabs.SelectedIndex });

			return null;
		}

		static void OnSelectedIndexChanged(int index)
		{
			if (_onSelected != null && _selectedContext != null)
				_onSelected.Call(_selectedContext, new object[] { index });
		}

		static object Add(Context c, object[] args)
		{
			if (args.Length < 1 || args[0] == null)
				return null;

			var templateName = args[0].ToString();
			WithActive(tabs => tabs.AddTab(templateName));
			return null;
		}

		static object Remove(Context c, object[] args)
		{
			if (args.Length < 1 || args[0] == null)
				return null;

			var templateName = args[0].ToString();
			WithActive(tabs => tabs.RemoveTab(templateName));
			return null;
		}

		static object SelectIndex(Context c, object[] args)
		{
			if (args.Length < 1 || !(args[0] is double))
				return null;

			var index = (int)(double)args[0];
			WithActive(tabs => tabs.SelectedIndex = index);
			return null;
		}
	}
}
