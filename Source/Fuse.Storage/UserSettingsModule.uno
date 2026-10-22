using Uno;
using Uno.UX;

using Fuse;
using Fuse.Scripting;

namespace Fuse.Storage
{
	[UXGlobalModule]
	/**
		@scriptmodule FuseJS/UserSettings

		`FuseJS/UserSettings` module provides key-value pairs mechanism to store and retrieve primitive data types (string, number, boolean) as well as an array and json object.
		You can use this module to store information such as configuration data, application states etc.

		> `UserSettings` module is implemented atop NSUserDefaults on iOS and Shared Preferences on Android

		## Example
		```xml
			<JavaScript>
				var userSettings = require("FuseJS/UserSettings")

				userSettings.putString('email', 'john.appleseed@example.com');
				userSettings.putString('password', 's3c1ReT');
				userSettings.putString('api_token', '73awnljqurelcvxiy832a');
				userSettings.putBoolean('logged', true);
				userSettings.putNumber('state_num', 2);
				userSettings.putArray('preferences', ['Technology', 'Cars', 'Foods']);
				userSettings.putObject('profile', {
					'first_name': 'John',
					'last_name': 'Appleseed',
					'gender': 'male',
					'address': '5 avenue'
					'age': 25,
					'married': false
				});

				var email = userSettings.getString('email');
				var password = userSettings.getString('password');
				var api_token = userSettings.getString('api_token');
				var logged = userSettings.getBoolean('logged');
				var state_num = userSettings.getNumber('state_num');
				var preferences = userSettings.getArray('preferences');
				var profile = userSettings.getObject('profile');
			</JavaScript>
		```

		## Named stores

		Use `open(name)` to access a separate store. On iOS the name is an
		`NSUserDefaults` suite name (for App Groups), on Android it is a separate
		`SharedPreferences` file, and on desktop it is a separate JSON file.

		```js
			var shared = require("FuseJS/UserSettings").open("group.com.example.app");
			shared.putString("token", "abc");
		```

		Use `onChanged(callback)` to be notified about changes made through the module.
	*/
	public sealed class UserSettingsModule : NativeModule
	{
		static readonly UserSettingsModule _instance;
		readonly UserSettingsStore _defaultStore = new UserSettingsStore(null);
		public UserSettingsModule()
		{
			if (_instance != null) return;
			_instance = this;
			Resource.SetGlobalKey(_instance, "FuseJS/UserSettings");
			AddMember(new NativeFunction("getString", GetString));
			AddMember(new NativeFunction("putString", PutString));
			AddMember(new NativeFunction("getNumber", GetNumber));
			AddMember(new NativeFunction("putNumber", PutNumber));
			AddMember(new NativeFunction("getBoolean", GetBoolean));
			AddMember(new NativeFunction("putBoolean", PutBoolean));
			AddMember(new NativeFunction("getArray", GetObject));
			AddMember(new NativeFunction("putArray", PutObject));
			AddMember(new NativeFunction("getObject", GetObject));
			AddMember(new NativeFunction("putObject", PutObject));
			AddMember(new NativeFunction("hasKey", HasKey));
			AddMember(new NativeFunction("keys", Keys));
			AddMember(new NativeFunction("getAll", GetAll));
			AddMember(new NativeFunction("remove", Remove));
			AddMember(new NativeFunction("clear", Clear));
			AddMember(new NativeFunction("open", Open));
			AddMember(new NativeFunction("onChanged", OnChanged));
		}

		static object GetStringFromStore(object[] args, UserSettingsStore store)
		{
			if (args.Length > 0)
			{
				string key = args[0] as string;
				if (key == null)
					return args.Length > 1 ? args[1] as string : null;

				if (args.Length > 1 && !store.HasKey(key))
					return args[1] as string;

				return store.GetStringValue(key);
			}
			return null;
		}

		static object PutStringToStore(object[] args, UserSettingsStore store)
		{
			if (args.Length > 1)
			{
				string key = args[0] as string;
				if (key != null && args[1] != null)
				{
					string value = args[1] as string;
					if (value == null)
						throw new Scripting.Error("Argument 2 (value) is required to be a string");

					store.SetStringValue(key, value);
				}
			}
			return null;
		}

		static object GetNumberFromStore(object[] args, UserSettingsStore store)
		{
			if (args.Length > 0)
			{
				string key = args[0] as string;
				if (key == null)
				{
					if (args.Length > 1)
						return Marshal.ToDouble(args[1]);
					return null;
				}

				if (args.Length > 1 && !store.HasKey(key))
					return Marshal.ToDouble(args[1]);

				return store.GetNumberValue(key);
			}
			return null;
		}

		static object PutNumberToStore(object[] args, UserSettingsStore store)
		{
			if (args.Length > 1)
			{
				string key = args[0] as string;
				if (key != null && args[1] != null)
					store.SetNumberValue(key, Marshal.ToDouble(args[1]));
			}
			return null;
		}

		static object GetBooleanFromStore(object[] args, UserSettingsStore store)
		{
			if (args.Length > 0)
			{
				string key = args[0] as string;
				if (key == null)
				{
					if (args.Length > 1)
						return Marshal.ToBool(args[1]);
					return null;
				}

				if (args.Length > 1 && !store.HasKey(key))
					return Marshal.ToBool(args[1]);

				return store.GetBooleanValue(key);
			}
			return null;
		}

		static object PutBooleanToStore(object[] args, UserSettingsStore store)
		{
			if (args.Length > 1)
			{
				string key = args[0] as string;
				if (key != null && args[1] != null)
					store.SetBooleanValue(key, Marshal.ToBool(args[1]));
			}
			return null;
		}

		static object GetObjectFromStore(Context c, object[] args, UserSettingsStore store)
		{
			if (args.Length > 0)
			{
				string key = args[0] as string;
				if (key == null)
					return null;

				var value = store.GetStringValue(key);
				if (value != null)
					return Converter(c, Json.Parse(value));
			}
			return null;
		}

		static object PutObjectToStore(object[] args, UserSettingsStore store)
		{
			if (args.Length > 1)
			{
				string key = args[0] as string;
				if (key != null && args[1] != null)
					store.SetStringValue(key, Json.Stringify(args[1]));
			}
			return null;
		}

		static object HasKeyInStore(object[] args, UserSettingsStore store)
		{
			if (args.Length > 0)
				return store.HasKey(args[0] as string);

			return false;
		}

		static object RemoveFromStore(object[] args, UserSettingsStore store)
		{
			if (args.Length > 0)
			{
				string key = args[0] as string;
				if (key != null)
					store.Remove(key);
			}
			return null;
		}

		static bool IsValidStoreName(string name)
		{
			for (int i = 0; i < name.Length; i++)
			{
				var c = name[i];
				if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
						|| c == '.' || c == '-' || c == '_')
					continue;

				return false;
			}

			return true;
		}

		/**
			@scriptmethod open(name)
			@param name (String) The name of the store to open
			@return (Object) An object with the same get/put/hasKey/keys/getAll/remove/clear/onChanged methods as this module

			Opens a named store. On iOS the name is used as an `NSUserDefaults` suite name,
			on Android as a `SharedPreferences` file name, and on desktop as a separate
			JSON file. The name may only contain letters, digits, `.`, `-` and `_`.

			On iOS, using a suite name requires the corresponding App Group entitlement.

			```js
				var userSettings = require("FuseJS/UserSettings");

				var shared = userSettings.open("group.com.example.app");
				shared.putString("token", "abc");
			```
		*/
		object Open(Context c, object[] args)
		{
			if (args.Length > 0)
			{
				string name = args[0] as string;
				if (name == null || name.Length == 0)
					throw new Scripting.Error("Argument 1 (name) is required to be a non-empty string");

				if (!IsValidStoreName(name))
					throw new Scripting.Error("Store name may only contain letters, digits, '.', '-' and '_'");

				return CreateStoreObject(c, new UserSettingsStore(name));
			}

			throw new Scripting.Error("Argument 1 (name) is required to be a non-empty string");
		}

		/**
			@scriptmethod onChanged(callback)
			@param callback (Function) Called with the changed key, or `null` after `clear()`. Pass `null` to stop listening.

			Listens for changes made through this module. Changes made directly through
			native APIs are not reported.

			```js
				var userSettings = require("FuseJS/UserSettings");

				userSettings.onChanged(function(key) {
					console.log("Changed: " + key);
				});
			```
		*/
		object OnChanged(Context c, object[] args)
		{
			Function listener = null;
			if (args.Length > 0 && args[0] != null)
			{
				listener = args[0] as Function;
				if (listener == null)
					throw new Scripting.Error("Argument 1 (callback) is required to be a function or null");
			}

			_defaultStore.SetChangedListener(c, listener);
			return null;
		}

		Scripting.Object CreateStoreObject(Context c, UserSettingsStore store)
		{
			var result = c.NewObject();
			var closure = new StoreClosure(store);

			result["getString"] = c.CallbackToFunction(new Callback(closure.GetString));
			result["putString"] = c.CallbackToFunction(new Callback(closure.PutString));
			result["getNumber"] = c.CallbackToFunction(new Callback(closure.GetNumber));
			result["putNumber"] = c.CallbackToFunction(new Callback(closure.PutNumber));
			result["getBoolean"] = c.CallbackToFunction(new Callback(closure.GetBoolean));
			result["putBoolean"] = c.CallbackToFunction(new Callback(closure.PutBoolean));
			result["getArray"] = c.CallbackToFunction(new Callback(closure.GetObject));
			result["putArray"] = c.CallbackToFunction(new Callback(closure.PutObject));
			result["getObject"] = c.CallbackToFunction(new Callback(closure.GetObject));
			result["putObject"] = c.CallbackToFunction(new Callback(closure.PutObject));
			result["hasKey"] = c.CallbackToFunction(new Callback(closure.HasKey));
			result["keys"] = c.CallbackToFunction(new Callback(closure.Keys));
			result["getAll"] = c.CallbackToFunction(new Callback(closure.GetAll));
			result["remove"] = c.CallbackToFunction(new Callback(closure.Remove));
			result["clear"] = c.CallbackToFunction(new Callback(closure.Clear));
			result["onChanged"] = c.CallbackToFunction(new Callback(closure.OnChanged));
			result["name"] = store.Name;

			return result;
		}

		class StoreClosure
		{
			readonly UserSettingsStore _store;

			public StoreClosure(UserSettingsStore store)
			{
				_store = store;
			}

			public object GetString(Context c, object[] args) { return GetStringFromStore(args, _store); }
			public object PutString(Context c, object[] args) { return PutStringToStore(args, _store); }
			public object GetNumber(Context c, object[] args) { return GetNumberFromStore(args, _store); }
			public object PutNumber(Context c, object[] args) { return PutNumberToStore(args, _store); }
			public object GetBoolean(Context c, object[] args) { return GetBooleanFromStore(args, _store); }
			public object PutBoolean(Context c, object[] args) { return PutBooleanToStore(args, _store); }
			public object GetObject(Context c, object[] args) { return GetObjectFromStore(c, args, _store); }
			public object PutObject(Context c, object[] args) { return PutObjectToStore(args, _store); }
			public object HasKey(Context c, object[] args) { return HasKeyInStore(args, _store); }
			public object Keys(Context c, object[] args) { return ToScriptingArray(c, _store.GetKeys()); }
			public object GetAll(Context c, object[] args) { return Converter(c, Json.Parse(_store.GetAllJson())); }
			public object Remove(Context c, object[] args) { return RemoveFromStore(args, _store); }

			public object Clear(Context c, object[] args)
			{
				_store.Clear();
				return null;
			}

			public object OnChanged(Context c, object[] args)
			{
				Function listener = null;
				if (args.Length > 0 && args[0] != null)
				{
					listener = args[0] as Function;
					if (listener == null)
						throw new Scripting.Error("Argument 1 (callback) is required to be a function or null");
				}

				_store.SetChangedListener(c, listener);
				return null;
			}
		}

		static Scripting.Array ToScriptingArray(Context c, string[] values)
		{
			var result = new object[values.Length];
			for (int i = 0; i < values.Length; i++)
				result[i] = values[i];

			return c.NewArray(result);
		}

		/**
			@scriptmethod getString(key, defaultValue)

			Retrieve a String value from the UserSetting. If the key does not exist
			and a `defaultValue` is provided, it is returned instead.

			@param key The name of the UserSetting to retrieve
			@param defaultValue Optional value returned when the key does not exist

		*/
		object GetString(Context c, object[] args)
		{
			return GetStringFromStore(args, _defaultStore);
		}

		/**
			@scriptmethod putString(key, value)

			Set a String value in the UserSetting.

			@param key The name of the UserSetting to save
			@param value The string value of the UserSetting to save
		*/
		object PutString(Context c, object[] args)
		{
			return PutStringToStore(args, _defaultStore);
		}

		/**
			@scriptmethod getNumber(key, defaultValue)

			Retrieve a Number value from the UserSetting. If the key does not exist
			and a `defaultValue` is provided, it is returned instead.

			@param key The name of the UserSetting to retrieve
			@param defaultValue Optional value returned when the key does not exist

		*/
		object GetNumber(Context c, object[] args)
		{
			return GetNumberFromStore(args, _defaultStore);
		}

		/**
			@scriptmethod putNumber(key, value)

			Set a Number value in the UserSetting.

			@param key The name of the UserSetting to save
			@param value The number value of the UserSetting to save
		*/
		object PutNumber(Context c, object[] args)
		{
			return PutNumberToStore(args, _defaultStore);
		}

		/**
			@scriptmethod getBoolean(key, defaultValue)

			Retrieve a Boolean value from the UserSetting. If the key does not exist
			and a `defaultValue` is provided, it is returned instead.

			@param key The name of the UserSetting to retrieve
			@param defaultValue Optional value returned when the key does not exist

		*/
		object GetBoolean(Context c, object[] args)
		{
			return GetBooleanFromStore(args, _defaultStore);
		}

		/**
			@scriptmethod putNumber(key, value)

			Set a Boolean value in the UserSetting.

			@param key The name of the UserSetting to save
			@param value The boolean value of the UserSetting to save
		*/
		object PutBoolean(Context c, object[] args)
		{
			return PutBooleanToStore(args, _defaultStore);
		}

		/**
			@scriptmethod getObject(key)

			Retrieve a Json Object value from the UserSetting.

			@param key The name of the UserSetting to retrieve

		*/
		object GetObject(Context c, object[] args)
		{
			return GetObjectFromStore(c, args, _defaultStore);
		}

		/**
			@scriptmethod putObject(key, value)

			Set a JSON value in the UserSetting.

			@param key The name of the UserSetting to save
			@param value The JSON object value of the UserSetting to save
		*/
		object PutObject(Context c, object[] args)
		{
			return PutObjectToStore(args, _defaultStore);
		}

		/**
			@scriptmethod hasKey(key)

			Check whether a key exists in the UserSetting.

			@param key The name of the UserSetting to check
			@return (boolean) `true` if the key exists, `false` otherwise

			```js
				var userSettings = require("FuseJS/UserSettings");

				if(userSettings.hasKey('email')) {
					console.log("Email is stored");
				}
			```
		*/
		object HasKey(Context c, object[] args)
		{
			return HasKeyInStore(args, _defaultStore);
		}

		/**
			@scriptmethod keys()

			Get the names of all keys in the UserSetting.

			@return (Array) An array of key names

			```js
				var userSettings = require("FuseJS/UserSettings");

				userSettings.keys().forEach(function(key) {
					console.log(key);
				});
			```
		*/
		object Keys(Context c, object[] args)
		{
			return ToScriptingArray(c, _defaultStore.GetKeys());
		}

		/**
			@scriptmethod getAll()

			Get all key-value pairs in the UserSetting.

			Values stored with `putArray` and `putObject` are returned as their JSON strings.

			@return (Object) An object containing all stored values

			```js
				var userSettings = require("FuseJS/UserSettings");

				var values = userSettings.getAll();
				console.log(JSON.stringify(values));
			```
		*/
		object GetAll(Context c, object[] args)
		{
			return Converter(c, Json.Parse(_defaultStore.GetAllJson()));
		}

		/**
			@scriptmethod remove(key)

			remove value based on key.

			@param key The name of the UserSetting to remove
		*/
		object Remove(Context c, object[] args)
		{
			return RemoveFromStore(args, _defaultStore);
		}

		/**
			@scriptmethod clear()

			clear User Setting values
		*/
		object Clear(Context c, object[] args)
		{
			_defaultStore.Clear();
			return null;
		}

		static object Converter(Context c, object obj)
		{
			if (obj is IObject)
			{
				var output = c.NewObject();
				var data = obj as IObject;
				for (var i=0; i<data.Keys.Length; i++)
					output[data.Keys[i]] = Converter(c, data[data.Keys[i]]);
				return output;
			}
			else if (obj is IArray)
			{
				var arr = obj as IArray;
				var values = new object[arr.Length];
				for (int i = 0; i < values.Length; i++)
					values[i] = Converter(c, arr[i]);
				return c.NewArray(values);
			}
			else if (obj is string)
				return (string)obj;
			else if (obj is bool)
				return (bool)obj;
			else if (obj is double)
				return (double)obj;
			else
				return null;
		}
	}
}