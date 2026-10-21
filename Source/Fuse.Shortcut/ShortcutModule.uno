using Uno;
using Uno.UX;
using Uno.Threading;
using Uno.Collections;
using Fuse;
using Fuse.Scripting;

namespace Fuse.Shortcut
{
	/**
		@scriptmodule FuseJS/Shortcut

		This module allows you to show menu items when pressing the App Icon on the device home screen.
		This feature refers to the [home screen actions](https://developer.apple.com/design/human-interface-guidelines/ios/system-capabilities/home-screen-actions/) on iOS and [App Shortcut](https://developer.android.com/guide/topics/ui/shortcuts.html) on Android (introduced in Android 7.1 / API Level 25).

		You need to add a reference to `"Fuse.Shortcut"` in your project file to use this feature.

		This module is an @EventEmitter, so the methods from @EventEmitter can be used to listen to events.

		## Usage

		The following example shows how to create shortcuts:
		```xml
				<App>
					<JavaScript>

						var Observable = require("FuseJS/Observable")
						var selectedShortcut = new Observable("-")

						var shortcut = require("FuseJS/Shortcut");
						shortcut.registerShortcuts([
							{
								id: 'compose',
								title: "Compose",
								subtitle: "New message",
								systemIcon: "square.and.pencil"
							},
							{
								id: 'profile',
								title: "Profile",
								systemIcon: "person",
								extras: { userId: "42" }
							},
							{
								id: 'book_store',
								title: "Book Store",
								icon: "assets/images/book.png"
							}
						]).then(function() {
							console.log("Shortcuts registered");
						});

						shortcut.on('shortcutClicked', (id, details) => {
							selectedShortcut.value = id;
							console.log("launch type: " + details.launchType);
							console.log("extras: " + JSON.stringify(details.extras));
						})

						module.exports = {
							selectedShortcut
						}

					</JavaScript>
					<StackPanel Margin="20">
						<Text Value="Selected Shortcut: {selectedShortcut}" />
					</StackPanel>
				</App>
		```

		`registerShortcuts` accepts an array of objects with the following properties:
		* `id` - id of the shortcut, passed to the `shortcutClicked` callback when the shortcut is clicked. Mandatory.
		* `title` - title to display in the menu. Mandatory.
		* `subtitle` - subtitle to display below the title on iOS, and the long label on Android. Optional.
		* `icon` - local image path (asset path, not a URL) that must be registered as a Bundle. More info about Bundle [here.](/docs/assets/bundle). Optional.
		* `systemIcon` - a universal symbol name from the icon set used by `Symbols` (for example `"square.and.pencil"`, `"trash"` or `"gear"`). The symbol is mapped to an SF Symbol on iOS and a Material Symbol on Android. On iOS, system icons require iOS 13 or newer; older versions fall back to `icon`. Optional.
		* `systemIconFilled` - whether to use the filled variant of `systemIcon`. Optional, defaults to `false`.
		* `extras` - an object with custom data that is passed back in the `details.extras` of the `shortcutClicked` event. On iOS this is exposed as `userInfo`, and on Android it is stored in the shortcut Intent and in the native `ShortcutInfo` extras. Optional.
		* `rank` - display rank used by Android to order shortcuts. Android only. Optional.
		* `categories` - array of category strings such as `"android.shortcut.conversation"`. Android only. Optional.
		* `disabled` - whether the shortcut is disabled. Android only. Omit to leave the current disabled state unchanged. Optional.
		* `disabledMessage` - message shown by the launcher when the shortcut is disabled. Android only. Optional.

		Android-only properties are ignored on iOS.

		`systemIcon` takes precedence over `icon` when both are specified.

		## Notes

		Shortcuts are managed by the operating system and may be removed when the app is updated or reinstalled. Register them again when the app starts.

		The `extras` payload is stored by the OS and the launcher. Do not use it for secrets.

		On Android, `extras` is also stored in the native `ShortcutInfo` extras as a `PersistableBundle`. Nested objects and primitive arrays are converted; mixed or object arrays are preserved as JSON strings.

		## Methods

		* `registerShortcuts(shortcuts)` - replaces all dynamic shortcuts. Returns a `Promise<bool>`. Rejects if the list exceeds `getMaxShortcutCount()`.
		* `updateShortcuts(shortcuts)` - adds new shortcuts and updates existing ones, leaving other shortcuts untouched. Returns a `Promise<bool>`. Rejects if the resulting set would exceed `getMaxShortcutCount()`.
		* `removeShortcuts(ids)` - removes the shortcuts with the given ids. Returns a `Promise<bool>`.
		* `clearShortcuts()` - removes all dynamic shortcuts. Returns a `Promise<bool>`.
		* `getShortcuts()` - returns a `Promise` that resolves to an array of `{ id, title, subtitle, extras }` objects describing the currently registered shortcuts. On Android the objects also include `rank`, `categories`, `disabled` and `disabledMessage`.
		* `isSupported()` - returns whether shortcuts are supported on the current platform. Android requires API level 25 or newer.
		* `getMaxShortcutCount()` - returns the maximum number of dynamic shortcuts supported by the platform (typically 4 on iOS).
		* `reportShortcutUsed(id)` - reports that a shortcut was used, which helps Android rank shortcuts. Android only; resolves to `false` on iOS. Returns a `Promise<bool>`.

		## Events

		* `shortcutClicked` - emitted when a shortcut is clicked. The first argument is the shortcut `id`, and the second argument is an object with `extras` and `launchType` (`"cold"` when the shortcut launched the app, or `"resume"` when the app was already running).
	*/
	[UXGlobalModule]
	public class ShortcutModule : NativeEventEmitterModule
	{
		static readonly ShortcutModule _instance;
		public ShortcutModule() : base(true, "shortcutClicked")
		{
			if(_instance != null) return;
			Resource.SetGlobalKey(_instance = this, "FuseJS/Shortcut");

			AddMember(new NativeFunction("registerShortcuts", RegisterShortcuts));
			AddMember(new NativeFunction("updateShortcuts", UpdateShortcuts));
			AddMember(new NativeFunction("removeShortcuts", RemoveShortcuts));
			AddMember(new NativeFunction("clearShortcuts", ClearShortcuts));
			AddMember(new NativeFunction("getShortcuts", GetShortcuts));
			AddMember(new NativeFunction("isSupported", IsSupported));
			AddMember(new NativeFunction("getMaxShortcutCount", GetMaxShortcutCount));
			AddMember(new NativeFunction("reportShortcutUsed", ReportShortcutUsed));
		}

		object RegisterShortcuts(Context c, object[] args)
		{
			string shortcuts;
			try
			{
				shortcuts = ValidateShortcuts(args, "registerShortcuts");
			}
			catch (Exception e)
			{
				return CreateRejectedPromise<bool>(c, e.Message);
			}

			return RunShortcutOperation(c, () => ShortcutProvider.RegisterShortcuts(shortcuts, MenuClicked));
		}

		object UpdateShortcuts(Context c, object[] args)
		{
			string shortcuts;
			try
			{
				shortcuts = ValidateShortcuts(args, "updateShortcuts");
			}
			catch (Exception e)
			{
				return CreateRejectedPromise<bool>(c, e.Message);
			}

			return RunShortcutOperation(c, () => ShortcutProvider.UpdateShortcuts(shortcuts, MenuClicked));
		}

		object RemoveShortcuts(Context c, object[] args)
		{
			string ids;
			try
			{
				ids = ValidateShortcutIds(args, "removeShortcuts");
			}
			catch (Exception e)
			{
				return CreateRejectedPromise<bool>(c, e.Message);
			}

			return RunShortcutOperation(c, () => ShortcutProvider.RemoveShortcuts(ids));
		}

		object ClearShortcuts(Context c, object[] args)
		{
			return RunShortcutOperation(c, () => ShortcutProvider.ClearShortcuts());
		}

		object GetShortcuts(Context c, object[] args)
		{
			var promise = new Promise<string>();
			new Thread(() =>
			{
				try
				{
					promise.Resolve(ShortcutProvider.GetShortcuts());
				}
				catch (Exception e)
				{
					promise.Reject(e);
				}
			}).Start();

			return WrapPromise<string, Scripting.Array>(c, promise, ToScriptingArray);
		}

		object IsSupported(Context c, object[] args)
		{
			return ShortcutProvider.IsSupported();
		}

		object GetMaxShortcutCount(Context c, object[] args)
		{
			return ShortcutProvider.GetMaxShortcutCount();
		}

		object ReportShortcutUsed(Context c, object[] args)
		{
			string id;
			try
			{
				id = ValidateShortcutId(args, "reportShortcutUsed");
			}
			catch (Exception e)
			{
				return CreateRejectedPromise<bool>(c, e.Message);
			}

			return RunShortcutOperation(c, () => ShortcutProvider.ReportShortcutUsed(id));
		}

		void MenuClicked(string payloadJson)
		{
			EmitFactory(c =>
			{
				var payload = c.ParseJson(payloadJson);
				object id = null;
				var payloadObject = payload as Scripting.Object;
				if (payloadObject != null && payloadObject.ContainsKey("id"))
					id = payloadObject["id"];

				return new object[] { id, payload };
			});
		}

		static object RunShortcutOperation(Context c, Func<bool> operation)
		{
			var promise = new Promise<bool>();
			new Thread(() =>
			{
				try
				{
					promise.Resolve(operation());
				}
				catch (Exception e)
				{
					promise.Reject(e);
				}
			}).Start();

			return WrapPromise<bool, bool>(c, promise, null);
		}

		static object CreateRejectedPromise<T>(Context c, string message)
		{
			var promise = new Promise<T>();
			promise.Reject(new Exception(message));
			return WrapPromise<T, T>(c, promise, null);
		}

		static object WrapPromise<T, TJSResult>(Context c, Future<T> future, ResultConverter<T, TJSResult> converter)
		{
			var promise = (Function)c.GlobalObject["Promise"];
			return promise.Construct(c, (Callback)new PromiseRunner<T, TJSResult>(c.ThreadWorker, future, converter).Run);
		}

		static Scripting.Array ToScriptingArray(Context c, string json)
		{
			return c.ParseJson(json) as Scripting.Array;
		}

		static string ValidateShortcuts(object[] args, string methodName)
		{
			if (args == null || args.Length < 1 || !(args[0] is IArray))
				throw new Exception(methodName + " expects an array of shortcuts.");

			var shortcuts = (IArray)args[0];
			var ids = new HashSet<string>();

			int maxShortcuts = ShortcutProvider.GetMaxShortcutCount();
			if (maxShortcuts > 0 && shortcuts.Length > maxShortcuts)
				throw new Exception(methodName + ": " + shortcuts.Length + " shortcuts specified, but this platform supports at most " + maxShortcuts + ".");

			for (int i = 0; i < shortcuts.Length; i++)
			{
				var shortcut = shortcuts[i] as IObject;
				if (shortcut == null)
					throw new Exception(methodName + ": shortcut at index " + i + " must be an object.");

				var id = GetString(shortcut, "id");
				if (string.IsNullOrEmpty(id))
					throw new Exception(methodName + ": shortcut at index " + i + " must have a non-empty 'id'.");

				// Use Contains before Add so this also works with older Uno versions
				// where HashSet.Add returned true when the item already existed.
				if (ids.Contains(id))
					throw new Exception(methodName + ": duplicate shortcut id '" + id + "'.");

				ids.Add(id);

				var title = GetString(shortcut, "title");
				if (string.IsNullOrEmpty(title))
					throw new Exception(methodName + ": shortcut '" + id + "' must have a non-empty 'title'.");

				ValidateOptionalString(shortcut, "subtitle", id);
				ValidateOptionalString(shortcut, "icon", id);
				ValidateOptionalString(shortcut, "systemIcon", id);
				ValidateOptionalString(shortcut, "disabledMessage", id);

				if (shortcut.ContainsKey("rank") && shortcut["rank"] != null && !(shortcut["rank"] is int) && !(shortcut["rank"] is double))
					throw new Exception(methodName + ": shortcut '" + id + "' has an invalid 'rank' value. Expected a number.");

				if (shortcut.ContainsKey("disabled") && shortcut["disabled"] != null && !(shortcut["disabled"] is bool))
					throw new Exception(methodName + ": shortcut '" + id + "' has an invalid 'disabled' value. Expected a boolean.");

				if (shortcut.ContainsKey("categories") && shortcut["categories"] != null)
				{
					var categories = shortcut["categories"] as IArray;
					if (categories == null)
						throw new Exception(methodName + ": shortcut '" + id + "' has an invalid 'categories' value. Expected an array of strings.");

					for (int j = 0; j < categories.Length; j++)
					{
						if (!(categories[j] is string) || string.IsNullOrEmpty((string)categories[j]))
							throw new Exception(methodName + ": shortcut '" + id + "' has an invalid 'categories[" + j + "]' value. Expected a non-empty string.");
					}
				}

				if (shortcut.ContainsKey("systemIconFilled") && shortcut["systemIconFilled"] != null && !(shortcut["systemIconFilled"] is bool))
					throw new Exception(methodName + ": shortcut '" + id + "' has an invalid 'systemIconFilled' value. Expected a boolean.");

				if (shortcut.ContainsKey("extras") && shortcut["extras"] != null && !(shortcut["extras"] is IObject))
					throw new Exception(methodName + ": shortcut '" + id + "' has an invalid 'extras' value. Expected an object.");
			}

			return Json.Stringify(args[0]);
		}

		static string ValidateShortcutId(object[] args, string methodName)
		{
			if (args == null || args.Length < 1 || !(args[0] is string) || string.IsNullOrEmpty((string)args[0]))
				throw new Exception(methodName + " expects a non-empty shortcut id.");

			return (string)args[0];
		}

		static string ValidateShortcutIds(object[] args, string methodName)
		{
			if (args == null || args.Length < 1 || !(args[0] is IArray))
				throw new Exception(methodName + " expects an array of shortcut ids.");

			var ids = (IArray)args[0];
			for (int i = 0; i < ids.Length; i++)
			{
				if (!(ids[i] is string) || string.IsNullOrEmpty((string)ids[i]))
					throw new Exception(methodName + ": shortcut id at index " + i + " must be a non-empty string.");
			}

			return Json.Stringify(args[0]);
		}

		static string GetString(IObject obj, string key)
		{
			if (!obj.ContainsKey(key) || obj[key] == null)
				return null;

			var value = obj[key];
			if (!(value is string))
				throw new Exception("'" + key + "' must be a string.");

			return (string)value;
		}

		static void ValidateOptionalString(IObject obj, string key, string id)
		{
			if (!obj.ContainsKey(key) || obj[key] == null)
				return;

			if (!(obj[key] is string))
				throw new Exception("Shortcut '" + id + "': '" + key + "' must be a string.");
		}

		class PromiseRunner<T, TJSResult>
		{
			readonly IThreadWorker _threadWorker;
			readonly Future<T> _future;
			readonly ResultConverter<T, TJSResult> _converter;
			Function _resolve;
			Function _reject;
			T _result;
			Exception _reason;

			public PromiseRunner(IThreadWorker threadWorker, Future<T> future, ResultConverter<T, TJSResult> converter)
			{
				_threadWorker = threadWorker;
				_future = future;
				_converter = converter;
			}

			public object Run(Context context, object[] args)
			{
				if (args.Length > 0)
					_resolve = args[0] as Function;

				if (args.Length > 1)
					_reject = args[1] as Function;

				_future.Then(Resolve, Reject);
				return null;
			}

			void Resolve(T result)
			{
				_result = result;
				if (_resolve != null)
					_threadWorker.Invoke(InternalResolve);
			}

			void InternalResolve(Context context)
			{
				if (_converter != null)
					_resolve.Call(context, _converter(context, _result));
				else
					_resolve.Call(context, _result);
			}

			void Reject(Exception reason)
			{
				_reason = reason;
				if (_reject != null)
					_threadWorker.Invoke(InternalReject);
			}

			void InternalReject(Context context)
			{
				_reject.Call(context, _reason.Message);
			}
		}
	}
}
