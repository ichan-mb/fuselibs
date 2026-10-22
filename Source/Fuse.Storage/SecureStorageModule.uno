using Uno;
using Uno.UX;
using Uno.Threading;
using Uno.Compiler.ExportTargetInterop;
using Fuse.Scripting;

namespace Fuse.Storage
{
	[UXGlobalModule]
	/**
		@scriptmodule FuseJS/SecureStorage

		Stores small secrets such as tokens, passwords and keys using the platform
		secure storage: the Keychain on iOS and the Android Keystore on Android.

		```js
			var SecureStorage = require("FuseJS/SecureStorage");
		```

		> Secure storage is available on Android 6.0 (API 23) and newer, and on iOS.
		> On desktop the APIs reject with a `NotSupportedException`.
	*/
	public sealed class SecureStorageModule : NativeModule
	{
		static readonly SecureStorageModule _instance;

		public SecureStorageModule()
		{
			if (_instance != null) return;
			Resource.SetGlobalKey(_instance = this, "FuseJS/SecureStorage");
			AddMember(new NativePromise<string, string>("get", Get, null));
			AddMember(new NativePromise<bool, bool>("set", Set, null));
			AddMember(new NativePromise<bool, bool>("remove", Remove, null));
			AddMember(new NativePromise<bool, bool>("hasKey", HasKey, null));
			AddMember(new NativePromise<bool, bool>("clear", Clear, null));
		}

		static string GetKeyArg(object[] args)
		{
			if (args != null && args.Length > 0 && args[0] != null)
			{
				var key = args[0] as string;
				if (key != null && key.Length > 0)
					return key;
			}

			throw new Scripting.Error("Argument 1 (key) is required to be a non-empty string");
		}

		static string GetValueArg(object[] args)
		{
			if (args != null && args.Length > 1 && args[1] != null)
			{
				var value = args[1] as string;
				if (value != null)
					return value;
			}

			throw new Scripting.Error("Argument 2 (value) is required to be a string");
		}

		/**
			@scriptmethod get(key)
			@param key (String) The key to read
			@return (Promise) A promise of the stored string, or `null` if the key does not exist.

			```js
				var SecureStorage = require("FuseJS/SecureStorage");

				SecureStorage.get("token")
					.then(function(token) {
						console.log(token);
					});
			```
		*/
		static Future<string> Get(Context c, object[] args)
		{
			var key = GetKeyArg(args);
			return Promise<string>.Run(new GetClosure(key).Invoke);
		}

		/**
			@scriptmethod set(key, value)
			@param key (String) The key to write
			@param value (String) The secret to store
			@return (Promise) A promise of a boolean, which will be `true` if the value was stored.

			```js
				var SecureStorage = require("FuseJS/SecureStorage");

				SecureStorage.set("token", "abc123")
					.then(function(succeeded) {
						console.log("Stored: " + succeeded);
					});
			```
		*/
		static Future<bool> Set(Context c, object[] args)
		{
			var key = GetKeyArg(args);
			var value = GetValueArg(args);
			return Promise<bool>.Run(new SetClosure(key, value).Invoke);
		}

		/**
			@scriptmethod remove(key)
			@param key (String) The key to remove
			@return (Promise) A promise of a boolean, which will be `true` if the key was removed or did not exist.

			```js
				var SecureStorage = require("FuseJS/SecureStorage");

				SecureStorage.remove("token");
			```
		*/
		static Future<bool> Remove(Context c, object[] args)
		{
			var key = GetKeyArg(args);
			return Promise<bool>.Run(new RemoveClosure(key).Invoke);
		}

		/**
			@scriptmethod hasKey(key)
			@param key (String) The key to check
			@return (Promise) A promise of a boolean, which will be `true` if the key exists.

			```js
				var SecureStorage = require("FuseJS/SecureStorage");

				SecureStorage.hasKey("token")
					.then(function(exists) {
						console.log(exists);
					});
			```
		*/
		static Future<bool> HasKey(Context c, object[] args)
		{
			var key = GetKeyArg(args);
			return Promise<bool>.Run(new HasKeyClosure(key).Invoke);
		}

		/**
			@scriptmethod clear()
			@return (Promise) A promise of a boolean, which will be `true` if the storage was cleared.

			Removes all values from secure storage.

			```js
				var SecureStorage = require("FuseJS/SecureStorage");

				SecureStorage.clear();
			```
		*/
		static Future<bool> Clear(Context c, object[] args)
		{
			return Promise<bool>.Run(new ClearClosure().Invoke);
		}

		internal static string GetValue(string key)
		{
			return SecureStorage.Get(key);
		}

		internal static bool SetValue(string key, string value)
		{
			return SecureStorage.Set(key, value);
		}

		internal static bool RemoveValue(string key)
		{
			return SecureStorage.Remove(key);
		}

		internal static bool HasKeyValue(string key)
		{
			return SecureStorage.HasKey(key);
		}

		internal static bool ClearValues()
		{
			return SecureStorage.Clear();
		}

		class GetClosure
		{
			readonly string _key;

			public GetClosure(string key)
			{
				_key = key;
			}

			public string Invoke()
			{
				return GetValue(_key);
			}
		}

		class SetClosure
		{
			readonly string _key;
			readonly string _value;

			public SetClosure(string key, string value)
			{
				_key = key;
				_value = value;
			}

			public bool Invoke()
			{
				return SetValue(_key, _value);
			}
		}

		class RemoveClosure
		{
			readonly string _key;

			public RemoveClosure(string key)
			{
				_key = key;
			}

			public bool Invoke()
			{
				return RemoveValue(_key);
			}
		}

		class HasKeyClosure
		{
			readonly string _key;

			public HasKeyClosure(string key)
			{
				_key = key;
			}

			public bool Invoke()
			{
				return HasKeyValue(_key);
			}
		}

		class ClearClosure
		{
			public bool Invoke()
			{
				return ClearValues();
			}
		}
	}

	[Require("xcode.framework", "Security")]
	[ForeignInclude(Language.ObjC, "Security/Security.h")]
	extern(iOS) static class IOSSecureStorage
	{
		[Foreign(Language.ObjC)]
		public static string GetValue(string key)
		@{
			NSMutableDictionary* query = [NSMutableDictionary dictionary];
			[query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
			[query setObject:@"FuseSecureStorage" forKey:(__bridge id)kSecAttrService];
			[query setObject:key forKey:(__bridge id)kSecAttrAccount];
			[query setObject:[NSNumber numberWithBool:YES] forKey:(__bridge id)kSecReturnData];
			[query setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];

			CFTypeRef result = NULL;
			OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
			if (status != errSecSuccess || result == NULL)
				return nil;

			NSData* data = (__bridge_transfer NSData*)result;
			return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		@}

		[Foreign(Language.ObjC)]
		public static bool SetValue(string key, string value)
		@{
			NSData* data = [value dataUsingEncoding:NSUTF8StringEncoding];
			NSMutableDictionary* query = [NSMutableDictionary dictionary];
			[query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
			[query setObject:@"FuseSecureStorage" forKey:(__bridge id)kSecAttrService];
			[query setObject:key forKey:(__bridge id)kSecAttrAccount];

			NSDictionary* update = [NSDictionary dictionaryWithObject:data forKey:(__bridge id)kSecValueData];
			OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)update);
			if (status == errSecItemNotFound) {
				[query setObject:data forKey:(__bridge id)kSecValueData];
				[query setObject:(__bridge id)kSecAttrAccessibleAfterFirstUnlock forKey:(__bridge id)kSecAttrAccessible];
				status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
			}

			return status == errSecSuccess;
		@}

		[Foreign(Language.ObjC)]
		public static bool RemoveValue(string key)
		@{
			NSMutableDictionary* query = [NSMutableDictionary dictionary];
			[query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
			[query setObject:@"FuseSecureStorage" forKey:(__bridge id)kSecAttrService];
			[query setObject:key forKey:(__bridge id)kSecAttrAccount];

			OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
			return status == errSecSuccess || status == errSecItemNotFound;
		@}

		[Foreign(Language.ObjC)]
		public static bool HasKey(string key)
		@{
			NSMutableDictionary* query = [NSMutableDictionary dictionary];
			[query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
			[query setObject:@"FuseSecureStorage" forKey:(__bridge id)kSecAttrService];
			[query setObject:key forKey:(__bridge id)kSecAttrAccount];
			[query setObject:[NSNumber numberWithBool:YES] forKey:(__bridge id)kSecReturnData];
			[query setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];

			CFTypeRef result = NULL;
			OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
			if (result != NULL)
				CFRelease(result);

			return status == errSecSuccess;
		@}

		[Foreign(Language.ObjC)]
		public static bool Clear()
		@{
			NSMutableDictionary* query = [NSMutableDictionary dictionary];
			[query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
			[query setObject:@"FuseSecureStorage" forKey:(__bridge id)kSecAttrService];

			OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
			return status == errSecSuccess || status == errSecItemNotFound;
		@}
	}

	[ForeignInclude(Language.Java,
		"android.content.SharedPreferences",
		"android.util.Base64",
		"com.fuse.Activity",
		"javax.crypto.Cipher",
		"javax.crypto.SecretKey",
		"javax.crypto.spec.GCMParameterSpec")]
	extern(Android) static class AndroidSecureStorage
	{
		[Foreign(Language.Java)]
		static Java.Object GetPreferences()
		@{
			android.content.Context context = Activity.getRootActivity();
			return context.getSharedPreferences("fuse_secure_storage", android.content.Context.MODE_PRIVATE);
		@}

		[Foreign(Language.Java)]
		static Java.Object GetKey()
		@{
			if (android.os.Build.VERSION.SDK_INT < 23)
				throw new UnsupportedOperationException("FuseJS/SecureStorage requires Android 6.0 (API 23) or newer");

			try {
				return com.fuse.securestorage.SecureStorageApi23.getKey();
			} catch (Exception e) {
				throw new RuntimeException(e);
			}
		@}

		static readonly object _sync = new object();
		static Java.Object _preferences;
		static Java.Object _key;

		static Java.Object Preferences
		{
			get
			{
				lock (_sync)
				{
					if (_preferences == null)
						_preferences = GetPreferences();
					return _preferences;
				}
			}
		}

		static Java.Object Key
		{
			get
			{
				lock (_sync)
				{
					if (_key == null)
						_key = GetKey();
					return _key;
				}
			}
		}

		[Foreign(Language.Java)]
		static string GetValueInternal(Java.Object preferences, Java.Object key, string name)
		@{
			String stored = ((SharedPreferences)preferences).getString(name, null);
			if (stored == null)
				return null;

			String[] parts = stored.split(":");
			if (parts.length != 2)
				return null;

			try {
				byte[] iv = Base64.decode(parts[0], Base64.NO_WRAP);
				byte[] data = Base64.decode(parts[1], Base64.NO_WRAP);
				Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
				cipher.init(Cipher.DECRYPT_MODE, (SecretKey)key, new GCMParameterSpec(128, iv));
				return new String(cipher.doFinal(data), "UTF-8");
			} catch (Exception e) {
				return null;
			}
		@}

		[Foreign(Language.Java)]
		static bool SetValueInternal(Java.Object preferences, Java.Object key, string name, string value)
		@{
			try {
				Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
				cipher.init(Cipher.ENCRYPT_MODE, (SecretKey)key);
				byte[] iv = cipher.getIV();
				byte[] data = cipher.doFinal(value.getBytes("UTF-8"));
				String stored = Base64.encodeToString(iv, Base64.NO_WRAP)
					+ ":" + Base64.encodeToString(data, Base64.NO_WRAP);
				((SharedPreferences)preferences).edit().putString(name, stored).apply();
				return true;
			} catch (Exception e) {
				return false;
			}
		@}

		[Foreign(Language.Java)]
		static bool RemoveValueInternal(Java.Object preferences, string name)
		@{
			((SharedPreferences)preferences).edit().remove(name).apply();
			return true;
		@}

		[Foreign(Language.Java)]
		static bool HasKeyInternal(Java.Object preferences, string name)
		@{
			return ((SharedPreferences)preferences).contains(name);
		@}

		[Foreign(Language.Java)]
		static bool ClearInternal(Java.Object preferences)
		@{
			((SharedPreferences)preferences).edit().clear().apply();
			return true;
		@}

		public static string GetValue(string key)
		{
			return GetValueInternal(Preferences, Key, key);
		}

		public static bool SetValue(string key, string value)
		{
			return SetValueInternal(Preferences, Key, key, value);
		}

		public static bool RemoveValue(string key)
		{
			return RemoveValueInternal(Preferences, key);
		}

		public static bool HasKey(string key)
		{
			return HasKeyInternal(Preferences, key);
		}

		public static bool Clear()
		{
			return ClearInternal(Preferences);
		}
	}
}
