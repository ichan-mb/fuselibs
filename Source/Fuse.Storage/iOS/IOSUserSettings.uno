using Uno;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Storage
{
	[ForeignInclude(Language.ObjC, "iOS/NSUserDefaults+SecureAdditions.h")]
	extern(iOS) class IOSUserSettings : IUserSettings
	{
		ObjC.Object _handle;

		public IOSUserSettings()
		{
			_handle = Init();
		}

		[Foreign(Language.ObjC)]
		ObjC.Object Init()
		@{
			NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
			[userDefaults setSecret:@"UX1qMnfqmPm9GV1Bz6w5h1(41i80|x"];
			return userDefaults;
		@}

		public string GetStringValue(string key)
		{
			return GetStringValue(_handle, key);
		}

		[Foreign(Language.ObjC)]
		string GetStringValue(ObjC.Object handle, string key)
		@{
			return [handle secretStringForKey:key];
		@}

		public bool GetBooleanValue(string key)
		{
			return GetBooleanValue(_handle, key);
		}

		[Foreign(Language.ObjC)]
		bool GetBooleanValue(ObjC.Object handle, string key)
		@{
			return [handle secretBoolForKey:key];
		@}

		public double GetNumberValue(string key)
		{
			return (double)GetFloatValue(_handle, key);
		}

		[Foreign(Language.ObjC)]
		float GetFloatValue(ObjC.Object handle, string key)
		@{
			return [handle secretFloatForKey:key];
		@}

		public void SetStringValue(string key, string value)
		{
			SetStringValue(_handle, key, value);
		}

		[Foreign(Language.ObjC)]
		void SetStringValue(ObjC.Object handle, string key, string value)
		@{
			[handle setSecretObject:value forKey:key];
			[handle synchronize];
		@}

		public void SetBooleanValue(string key, bool value)
		{
			SetBooleanValue(_handle, key, value);
		}

		[Foreign(Language.ObjC)]
		void SetBooleanValue(ObjC.Object handle, string key, bool value)
		@{
			[handle setSecretBool:value forKey:key];
			[handle synchronize];
		@}

		public void SetNumberValue(string key, double value)
		{
			SetFloatValue(_handle, key, (float)value);
		}

		[Foreign(Language.ObjC)]
		void SetFloatValue(ObjC.Object handle, string key, float value)
		@{
			[handle setSecretFloat:value forKey:key];
			[handle synchronize];
		@}

		public void Remove(string key)
		{
			Remove(_handle, key);
		}

		[Foreign(Language.ObjC)]
		void Remove(ObjC.Object handle, string key)
		@{
			[handle setSecretObject:nil forKey:key];
			[handle synchronize];
		@}

		public void Clear()
		{
			Clear(_handle);
		}

		[Foreign(Language.ObjC)]
		void Clear(ObjC.Object handle)
		@{
			[[NSUserDefaults standardUserDefaults] removePersistentDomainForName:[[NSBundle mainBundle] bundleIdentifier]];
		@}
	}
}