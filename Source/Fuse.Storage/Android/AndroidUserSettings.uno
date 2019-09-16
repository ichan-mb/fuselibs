using Uno;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Storage
{
	[ForeignInclude(Language.Java, "android.content.SharedPreferences", "com.fuse.securepreferences.SecurePreferences")]
	extern(Android) class AndroidUserSettings : IUserSettings
	{
		Java.Object _handle;
		Java.Object _handleEditor;

		public AndroidUserSettings()
		{
			_handle = Init();
			_handleEditor = GetEditor(_handle);
		}

		[Foreign(Language.Java)]
		Java.Object Init()
		@{
			return new SecurePreferences(com.fuse.Activity.getRootActivity());
		@}

		[Foreign(Language.Java)]
		Java.Object GetEditor(Java.Object handle)
		@{
			return ((SecurePreferences)handle).edit();
		@}

		public string GetStringValue(string key)
		{
			return GetStringValue(_handle, key);
		}

		[Foreign(Language.Java)]
		string GetStringValue(Java.Object handle, string key)
		@{
			return ((SecurePreferences)handle).getString(key, "");
		@}

		public bool GetBooleanValue(string key)
		{
			return GetBooleanValue(_handle, key);
		}

		[Foreign(Language.Java)]
		bool GetBooleanValue(Java.Object handle, string key)
		@{
			return ((SecurePreferences)handle).getBoolean(key, false);
		@}

		public double GetNumberValue(string key)
		{
			return (double)GetFloatValue(_handle, key);
		}

		[Foreign(Language.Java)]
		float GetFloatValue(Java.Object handle, string key)
		@{
			return ((SecurePreferences)handle).getFloat(key, -1);
		@}

		public void SetStringValue(string key, string value)
		{
			SetStringValue(_handleEditor, key, value);
		}

		[Foreign(Language.Java)]
		void SetStringValue(Java.Object handle, string key, string value)
		@{
			((SecurePreferences.Editor)handle).putString(key, value);
			((SecurePreferences.Editor)handle).commit();
		@}

		public void SetBooleanValue(string key, bool value)
		{
			SetBooleanValue(_handleEditor, key, value);
		}

		[Foreign(Language.Java)]
		void SetBooleanValue(Java.Object handle, string key, bool value)
		@{
			((SecurePreferences.Editor)handle).putBoolean(key, value);
			((SecurePreferences.Editor)handle).commit();
		@}

		public void SetNumberValue(string key, double value)
		{
			SetFloatValue(_handleEditor, key, (float)value);
		}

		[Foreign(Language.Java)]
		void SetFloatValue(Java.Object handle, string key, float value)
		@{
			((SecurePreferences.Editor)handle).putFloat(key, value);
			((SecurePreferences.Editor)handle).commit();
		@}

		public void Remove(string key)
		{
			Remove(_handleEditor, key);
		}

		[Foreign(Language.Java)]
		void Remove(Java.Object handle, string key)
		@{
			((SecurePreferences.Editor)handle).remove(key);
			((SecurePreferences.Editor)handle).commit();
		@}

		public void Clear()
		{
			Clear(_handleEditor);
		}

		[Foreign(Language.Java)]
		void Clear(Java.Object handle)
		@{
			((SecurePreferences.Editor)handle).clear();
			((SecurePreferences.Editor)handle).commit();
		@}
	}
}