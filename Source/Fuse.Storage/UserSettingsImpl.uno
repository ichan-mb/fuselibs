using Uno;
using Uno.IO;
using Uno.Text;
using Uno.UX;
using Uno.Collections;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Storage
{
	public extern(!MOBILE) class DesktopUserSettingsImpl
	{
		static readonly Dictionary<string, DesktopUserSettingsImpl> instances = new Dictionary<string, DesktopUserSettingsImpl>();
		static readonly object _instancesMutex = new object();

		readonly Dictionary<string, object> _data = new Dictionary<string, object>();
		readonly string _filename;

		static string GetFilename(string name)
		{
			string folder = @(project.name);
			string filename = (name == null || name.Length == 0)
				? "UserSettings.json"
				: "UserSettings-" + SanitizeName(name) + ".json";
			var settingFolder = Path.Combine(Directory.GetUserDirectory(UserDirectory.Data), folder);
			var settingFile = Path.Combine(settingFolder, filename);

			if (!Directory.Exists(settingFolder))
				Directory.CreateDirectory(settingFolder);
			if (!File.Exists(settingFile))
				using(var stream = File.Open(settingFile, FileMode.Create)) {}

			return settingFile;
		}

		static string SanitizeName(string name)
		{
			var result = new StringBuilder();
			for (int i = 0; i < name.Length; i++)
			{
				var c = name[i];
				if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
						|| c == '.' || c == '-' || c == '_')
					result.Append(c);
				else
					result.Append('_');
			}

			return result.ToString();
		}

		DesktopUserSettingsImpl(string name)
		{
			_filename = GetFilename(name);

			string content = File.ReadAllText(_filename);
			if (content != "") {
				IObject obj = Json.Parse(content) as IObject;
				if (obj != null)
					for (var i = 0; i< obj.Keys.Length; i++)
						_data[obj.Keys[i]] = obj[obj.Keys[i]];
			}
		}

		public static DesktopUserSettingsImpl GetInstance()
		{
			return GetInstance(null);
		}

		public static DesktopUserSettingsImpl GetInstance(string name)
		{
			var key = name ?? "";

			lock (_instancesMutex)
			{
				DesktopUserSettingsImpl instance;
				if (instances.TryGetValue(key, out instance))
					return instance;

				instance = new DesktopUserSettingsImpl(name);
				instances[key] = instance;
				return instance;
			}
		}

		public string GetStringValue(string key)
		{
			if (_data.ContainsKey(key))
				return _data[key] as string;
			else
				return "";
		}

		public double GetNumberValue(string key)
		{
			if (_data.ContainsKey(key))
				return (double)_data[key];
			else
				return 0;
		}

		public bool GetBooleanValue(string key)
		{
			if (_data.ContainsKey(key))
				return (bool)_data[key];
			else
				return false;
		}

		public bool HasKey(string key)
		{
			return _data.ContainsKey(key);
		}

		public string[] GetKeys()
		{
			var keys = new string[_data.Count];
			var index = 0;
			foreach (var key in _data.Keys)
				keys[index++] = key;
			return keys;
		}

		public string GetAllJson()
		{
			return Json.Stringify(_data);
		}

		public void SetStringValue(string key, string value)
		{
			if (_data.ContainsKey(key))
				_data.Remove(key);
			_data.Add(key, value);
			Synchronize();
		}

		public void SetNumberValue(string key, double value)
		{
			if (_data.ContainsKey(key))
				_data.Remove(key);
			_data.Add(key, value);
			Synchronize();
		}

		public void SetBooleanValue(string key, bool value)
		{
			if (_data.ContainsKey(key))
				_data.Remove(key);
			_data.Add(key, value);
			Synchronize();
		}

		public void Remove(string key)
		{
			_data.Remove(key);
			Synchronize();
		}

		public void Clear()
		{
			_data.Clear();
			Synchronize();
		}

		private void Synchronize()
		{
			var jsonString = Json.Stringify(_data);
			File.WriteAllText(_filename, jsonString);
		}
	}

	[ForeignInclude(Language.Java,
		"com.fuse.Activity",
		"android.content.SharedPreferences",
		"android.preference.PreferenceManager",
		"java.util.Map",
		"java.util.Set",
		"org.json.JSONArray",
		"org.json.JSONException",
		"org.json.JSONObject")]
	public extern(Android) class AndroidUserSettingsImpl
	{
		static readonly Dictionary<string, Java.Object> _preferences = new Dictionary<string, Java.Object>();
		static readonly object _preferencesMutex = new object();

		static Java.Object GetPreferences(string storeName)
		{
			var key = storeName ?? "";

			lock (_preferencesMutex)
			{
				Java.Object preferences;
				if (_preferences.TryGetValue(key, out preferences))
					return preferences;

				preferences = CreatePreferences(storeName);
				_preferences[key] = preferences;
				return preferences;
			}
		}

		[Foreign(Language.Java)]
		static Java.Object CreatePreferences(string storeName)
		@{
			android.content.Context context = Activity.getRootActivity();
			if (storeName == null || storeName.isEmpty())
				return PreferenceManager.getDefaultSharedPreferences(context);

			return context.getSharedPreferences(storeName, android.content.Context.MODE_PRIVATE);
		@}

		public static bool HasKey(string key)
		{
			return HasKey(key, null);
		}

		public static bool HasKey(string key, string storeName)
		{
			return HasKeyInternal(GetPreferences(storeName), key);
		}

		[Foreign(Language.Java)]
		static bool HasKeyInternal(Java.Object preferences, string key)
		@{
			return ((SharedPreferences)preferences).contains(key);
		@}

		public static string[] GetKeys()
		{
			return GetKeys(null);
		}

		public static string[] GetKeys(string storeName)
		{
			return GetKeysInternal(GetPreferences(storeName));
		}

		[Foreign(Language.Java)]
		static string[] GetKeysInternal(Java.Object preferences)
		@{
			Map<String, ?> values = ((SharedPreferences)preferences).getAll();
			com.uno.StringArray result = new com.uno.StringArray(values.size());
			int index = 0;
			for (String key : values.keySet())
				result.set(index++, key);
			return result;
		@}

		public static string GetAllJson()
		{
			return GetAllJson(null);
		}

		public static string GetAllJson(string storeName)
		{
			return GetAllJsonInternal(GetPreferences(storeName));
		}

		[Foreign(Language.Java)]
		static string GetAllJsonInternal(Java.Object preferences)
		@{
			JSONObject result = new JSONObject();
			for (Map.Entry<String, ?> entry : ((SharedPreferences)preferences).getAll().entrySet()) {
				Object value = entry.getValue();
				try {
					if (value instanceof Set) {
						JSONArray array = new JSONArray();
						for (Object item : (Set)value)
							array.put(item);
						result.put(entry.getKey(), array);
					} else {
						result.put(entry.getKey(), value);
					}
				} catch (JSONException e) {
					// Skip values that cannot be represented as JSON
				}
			}
			return result.toString();
		@}

		public static string GetStringValue(string key)
		{
			return GetStringValue(key, null);
		}

		public static string GetStringValue(string key, string storeName)
		{
			return GetStringValueInternal(GetPreferences(storeName), key);
		}

		[Foreign(Language.Java)]
		static string GetStringValueInternal(Java.Object preferences, string key)
		@{
			return ((SharedPreferences)preferences).getString(key, "");
		@}

		public static double GetNumberValue(string key)
		{
			return GetNumberValue(key, null);
		}

		public static double GetNumberValue(string key, string storeName)
		{
			return GetNumberValueInternal(GetPreferences(storeName), key);
		}

		[Foreign(Language.Java)]
		static double GetNumberValueInternal(Java.Object preferences, string key)
		@{
			Object value = ((SharedPreferences)preferences).getAll().get(key);
			if (value instanceof Number)
				return ((Number)value).doubleValue();
			if (value instanceof String) {
				try {
					return Double.parseDouble((String)value);
				} catch (NumberFormatException e) {
					return 0;
				}
			}
			return 0;
		@}

		public static bool GetBooleanValue(string key)
		{
			return GetBooleanValue(key, null);
		}

		public static bool GetBooleanValue(string key, string storeName)
		{
			return GetBooleanValueInternal(GetPreferences(storeName), key);
		}

		[Foreign(Language.Java)]
		static bool GetBooleanValueInternal(Java.Object preferences, string key)
		@{
			return ((SharedPreferences)preferences).getBoolean(key, false);
		@}

		public static void SetStringValue(string key, string value)
		{
			SetStringValue(key, value, null);
		}

		public static void SetStringValue(string key, string value, string storeName)
		{
			SetStringValueInternal(GetPreferences(storeName), key, value);
		}

		[Foreign(Language.Java)]
		static void SetStringValueInternal(Java.Object preferences, string key, string value)
		@{
			SharedPreferences.Editor editor = ((SharedPreferences)preferences).edit();
			editor.putString(key, value);
			editor.apply();
		@}

		public static void SetNumberValue(string key, double value)
		{
			SetNumberValue(key, value, null);
		}

		public static void SetNumberValue(string key, double value, string storeName)
		{
			SetNumberValueInternal(GetPreferences(storeName), key, value);
		}

		[Foreign(Language.Java)]
		static void SetNumberValueInternal(Java.Object preferences, string key, double value)
		@{
			SharedPreferences.Editor editor = ((SharedPreferences)preferences).edit();
			// SharedPreferences has no double type. Store integral values as long so
			// timestamps and identifiers keep their precision; fractional values use float.
			if (!Double.isNaN(value) && !Double.isInfinite(value) && value == Math.rint(value)
					&& Math.abs(value) <= 9007199254740992.0)
				editor.putLong(key, (long)value);
			else
				editor.putFloat(key, (float)value);
			editor.apply();
		@}

		public static void SetBooleanValue(string key, bool value)
		{
			SetBooleanValue(key, value, null);
		}

		public static void SetBooleanValue(string key, bool value, string storeName)
		{
			SetBooleanValueInternal(GetPreferences(storeName), key, value);
		}

		[Foreign(Language.Java)]
		static void SetBooleanValueInternal(Java.Object preferences, string key, bool value)
		@{
			SharedPreferences.Editor editor = ((SharedPreferences)preferences).edit();
			editor.putBoolean(key, value);
			editor.apply();
		@}

		public static void Remove(string key)
		{
			Remove(key, null);
		}

		public static void Remove(string key, string storeName)
		{
			RemoveInternal(GetPreferences(storeName), key);
		}

		[Foreign(Language.Java)]
		static void RemoveInternal(Java.Object preferences, string key)
		@{
			SharedPreferences.Editor editor = ((SharedPreferences)preferences).edit();
			editor.remove(key);
			editor.apply();
		@}

		public static void Clear()
		{
			Clear(null);
		}

		public static void Clear(string storeName)
		{
			ClearInternal(GetPreferences(storeName));
		}

		[Foreign(Language.Java)]
		static void ClearInternal(Java.Object preferences)
		@{
			SharedPreferences.Editor editor = ((SharedPreferences)preferences).edit();
			editor.clear();
			editor.apply();
		@}
	}

	[ForeignInclude(Language.ObjC, "math.h")]
	public extern(iOS) class IOSUserSettingsImpl
	{
		static readonly Dictionary<string, ObjC.Object> _defaults = new Dictionary<string, ObjC.Object>();
		static readonly object _defaultsMutex = new object();

		static ObjC.Object GetDefaults(string suiteName)
		{
			var key = suiteName ?? "";

			lock (_defaultsMutex)
			{
				ObjC.Object defaults;
				if (_defaults.TryGetValue(key, out defaults))
					return defaults;

				defaults = CreateDefaults(suiteName);
				_defaults[key] = defaults;
				return defaults;
			}
		}

		[Foreign(Language.ObjC)]
		static ObjC.Object CreateDefaults(string suiteName)
		@{
			if (suiteName == nil || [suiteName length] == 0)
				return [NSUserDefaults standardUserDefaults];

			return [[NSUserDefaults alloc] initWithSuiteName:suiteName];
		@}

		static string GetDomainName(string suiteName)
		{
			if (suiteName != null && suiteName.Length > 0)
				return suiteName;

			return null;
		}

		public static bool HasKey(string key)
		{
			return HasKey(key, null);
		}

		public static bool HasKey(string key, string suiteName)
		{
			return HasKeyInternal(GetDefaults(suiteName), GetDomainName(suiteName), key);
		}

		[Foreign(Language.ObjC)]
		static bool HasKeyInternal(ObjC.Object defaults, string suiteName, string key)
		@{
			NSString* domainName = (suiteName != nil && [suiteName length] > 0)
				? suiteName
				: [[NSBundle mainBundle] bundleIdentifier];
			if (domainName == nil)
				return false;

			NSDictionary* domain = [(NSUserDefaults*)defaults persistentDomainForName:domainName];
			return domain != nil && [domain objectForKey:key] != nil;
		@}

		public static string[] GetKeys()
		{
			return GetKeys(null);
		}

		public static string[] GetKeys(string suiteName)
		{
			return GetKeysInternal(GetDefaults(suiteName), GetDomainName(suiteName));
		}

		[Foreign(Language.ObjC)]
		static string[] GetKeysInternal(ObjC.Object defaults, string suiteName)
		@{
			NSString* domainName = (suiteName != nil && [suiteName length] > 0)
				? suiteName
				: [[NSBundle mainBundle] bundleIdentifier];
			if (domainName == nil)
				return @{string[]:new(0)};

			NSDictionary* domain = [(NSUserDefaults*)defaults persistentDomainForName:domainName];
			if (domain == nil)
				return @{string[]:new(0)};

			NSArray* keys = [domain allKeys];
			id<UnoArray> result = @{string[]:new((int)[keys count])};
			for (int i = 0; i < (int)[keys count]; ++i)
				@{string[]:of(result).Set(i, [keys objectAtIndex:i])};

			return result;
		@}

		public static string GetAllJson()
		{
			return GetAllJson(null);
		}

		public static string GetAllJson(string suiteName)
		{
			return GetAllJsonInternal(GetDefaults(suiteName), GetDomainName(suiteName));
		}

		[Foreign(Language.ObjC)]
		static string GetAllJsonInternal(ObjC.Object defaults, string suiteName)
		@{
			NSString* domainName = (suiteName != nil && [suiteName length] > 0)
				? suiteName
				: [[NSBundle mainBundle] bundleIdentifier];
			if (domainName == nil)
				return @"{}";

			NSDictionary* domain = [(NSUserDefaults*)defaults persistentDomainForName:domainName];
			if (domain == nil)
				return @"{}";

			NSMutableDictionary* result = [NSMutableDictionary dictionary];
			for (NSString* key in domain) {
				id value = [domain objectForKey:key];

				if ([value isKindOfClass:[NSDate class]]) {
					[result setObject:[NSNumber numberWithDouble:([value timeIntervalSince1970] * 1000.0)] forKey:key];
				} else if ([value isKindOfClass:[NSURL class]]) {
					[result setObject:[value absoluteString] forKey:key];
				} else if ([value isKindOfClass:[NSData class]]) {
					[result setObject:[value base64EncodedStringWithOptions:0] forKey:key];
				} else if ([value isKindOfClass:[NSNumber class]]) {
					double number = [value doubleValue];
					if (!isnan(number) && !isinf(number))
						[result setObject:value forKey:key];
				} else if ([value isKindOfClass:[NSString class]]
						|| [value isKindOfClass:[NSArray class]]
						|| [value isKindOfClass:[NSDictionary class]]) {
					[result setObject:value forKey:key];
				}
			}

			if (![NSJSONSerialization isValidJSONObject:result])
				return @"{}";

			NSData* data = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
			if (data == nil)
				return @"{}";

			return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		@}

		public static string GetStringValue(string key)
		{
			return GetStringValue(key, null);
		}

		public static string GetStringValue(string key, string suiteName)
		{
			return GetStringValueInternal(GetDefaults(suiteName), key);
		}

		[Foreign(Language.ObjC)]
		static string GetStringValueInternal(ObjC.Object defaults, string key)
		@{
			return [(NSUserDefaults*)defaults stringForKey:key];
		@}

		public static double GetNumberValue(string key)
		{
			return GetNumberValue(key, null);
		}

		public static double GetNumberValue(string key, string suiteName)
		{
			return GetNumberValueInternal(GetDefaults(suiteName), key);
		}

		[Foreign(Language.ObjC)]
		static double GetNumberValueInternal(ObjC.Object defaults, string key)
		@{
			return [(NSUserDefaults*)defaults doubleForKey:key];
		@}

		public static bool GetBooleanValue(string key)
		{
			return GetBooleanValue(key, null);
		}

		public static bool GetBooleanValue(string key, string suiteName)
		{
			return GetBooleanValueInternal(GetDefaults(suiteName), key);
		}

		[Foreign(Language.ObjC)]
		static bool GetBooleanValueInternal(ObjC.Object defaults, string key)
		@{
			return [(NSUserDefaults*)defaults boolForKey:key];
		@}

		public static void SetStringValue(string key, string value)
		{
			SetStringValue(key, value, null);
		}

		public static void SetStringValue(string key, string value, string suiteName)
		{
			SetStringValueInternal(GetDefaults(suiteName), key, value);
		}

		[Foreign(Language.ObjC)]
		static void SetStringValueInternal(ObjC.Object defaults, string key, string value)
		@{
			NSUserDefaults* userDefault = (NSUserDefaults*)defaults;
			[userDefault setObject:value forKey:key];
			[userDefault synchronize];
		@}

		public static void SetNumberValue(string key, double value)
		{
			SetNumberValue(key, value, null);
		}

		public static void SetNumberValue(string key, double value, string suiteName)
		{
			SetNumberValueInternal(GetDefaults(suiteName), key, value);
		}

		[Foreign(Language.ObjC)]
		static void SetNumberValueInternal(ObjC.Object defaults, string key, double value)
		@{
			NSUserDefaults* userDefault = (NSUserDefaults*)defaults;
			[userDefault setDouble:value forKey:key];
			[userDefault synchronize];
		@}

		public static void SetBooleanValue(string key, bool value)
		{
			SetBooleanValue(key, value, null);
		}

		public static void SetBooleanValue(string key, bool value, string suiteName)
		{
			SetBooleanValueInternal(GetDefaults(suiteName), key, value);
		}

		[Foreign(Language.ObjC)]
		static void SetBooleanValueInternal(ObjC.Object defaults, string key, bool value)
		@{
			NSUserDefaults* userDefault = (NSUserDefaults*)defaults;
			[userDefault setBool:value forKey:key];
			[userDefault synchronize];
		@}

		public static void Remove(string key)
		{
			Remove(key, null);
		}

		public static void Remove(string key, string suiteName)
		{
			RemoveInternal(GetDefaults(suiteName), key);
		}

		[Foreign(Language.ObjC)]
		static void RemoveInternal(ObjC.Object defaults, string key)
		@{
			NSUserDefaults* userDefault = (NSUserDefaults*)defaults;
			[userDefault removeObjectForKey:key];
			[userDefault synchronize];
		@}

		public static void Clear()
		{
			Clear(null);
		}

		public static void Clear(string suiteName)
		{
			ClearInternal(GetDefaults(suiteName), GetDomainName(suiteName));
		}

		[Foreign(Language.ObjC)]
		static void ClearInternal(ObjC.Object defaults, string suiteName)
		@{
			NSString* domainName = (suiteName != nil && [suiteName length] > 0)
				? suiteName
				: [[NSBundle mainBundle] bundleIdentifier];
			if (domainName != nil)
				[(NSUserDefaults*)defaults removePersistentDomainForName:domainName];
		@}
	}
}