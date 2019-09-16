using Uno;
using Uno.Collections;
using Uno.IO;

namespace Fuse.Storage
{
	interface IUserSettings
	{
		string GetStringValue(string key);

		double GetNumberValue(string key);

		bool GetBooleanValue(string key);

		void SetStringValue(string key, string value);

		void SetNumberValue(string key, double value);

		void SetBooleanValue(string key, bool value);

		void Remove(string key);

		void Clear();
	}

	public class UserSettingsImpl : IUserSettings
	{
		static IUserSettings _userSettings;
		public UserSettingsImpl()
		{
			if(_userSettings != null) return;
			if defined(Android)
				_userSettings = new AndroidUserSettings();
			else if defined(iOS)
				_userSettings = new IOSUserSettings();
			else
				_userSettings = new DesktopUserSettings();
		}

		public string GetStringValue(string key)
		{
			return _userSettings.GetStringValue(key);
		}

		public double GetNumberValue(string key)
		{
			return _userSettings.GetNumberValue(key);
		}

		public bool GetBooleanValue(string key)
		{
			return _userSettings.GetBooleanValue(key);
		}

		public void SetStringValue(string key, string value)
		{
			_userSettings.SetStringValue(key, value);
		}

		public void SetNumberValue(string key, double value)
		{
			_userSettings.SetNumberValue(key, value);
		}

		public void SetBooleanValue(string key, bool value)
		{
			_userSettings.SetBooleanValue(key, value);
		}

		public void Remove(string key)
		{
			_userSettings.Remove(key);
		}

		public void Clear()
		{
			_userSettings.Clear();
		}
	}
}