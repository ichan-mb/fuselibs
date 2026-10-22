using Uno;
using Fuse.Scripting;

namespace Fuse.Storage
{
	internal class UserSettingsStore
	{
		readonly string _name;
		Function _changedListener;
		Context _changedContext;

		public UserSettingsStore(string name)
		{
			_name = name;
		}

		public string Name
		{
			get { return _name; }
		}

		public void SetChangedListener(Context context, Function listener)
		{
			_changedContext = context;
			_changedListener = listener;
		}

		public string GetStringValue(string key)
		{
			if defined(Android)
				return AndroidUserSettingsImpl.GetStringValue(key, _name);
			else if defined(iOS)
				return IOSUserSettingsImpl.GetStringValue(key, _name);
			else
				return DesktopUserSettingsImpl.GetInstance(_name).GetStringValue(key);
		}

		public double GetNumberValue(string key)
		{
			if defined(Android)
				return AndroidUserSettingsImpl.GetNumberValue(key, _name);
			else if defined(iOS)
				return IOSUserSettingsImpl.GetNumberValue(key, _name);
			else
				return DesktopUserSettingsImpl.GetInstance(_name).GetNumberValue(key);
		}

		public bool GetBooleanValue(string key)
		{
			if defined(Android)
				return AndroidUserSettingsImpl.GetBooleanValue(key, _name);
			else if defined(iOS)
				return IOSUserSettingsImpl.GetBooleanValue(key, _name);
			else
				return DesktopUserSettingsImpl.GetInstance(_name).GetBooleanValue(key);
		}

		public bool HasKey(string key)
		{
			if (key == null)
				return false;

			if defined(Android)
				return AndroidUserSettingsImpl.HasKey(key, _name);
			else if defined(iOS)
				return IOSUserSettingsImpl.HasKey(key, _name);
			else
				return DesktopUserSettingsImpl.GetInstance(_name).HasKey(key);
		}

		public string[] GetKeys()
		{
			if defined(Android)
				return AndroidUserSettingsImpl.GetKeys(_name);
			else if defined(iOS)
				return IOSUserSettingsImpl.GetKeys(_name);
			else
				return DesktopUserSettingsImpl.GetInstance(_name).GetKeys();
		}

		public string GetAllJson()
		{
			if defined(Android)
				return AndroidUserSettingsImpl.GetAllJson(_name);
			else if defined(iOS)
				return IOSUserSettingsImpl.GetAllJson(_name);
			else
				return DesktopUserSettingsImpl.GetInstance(_name).GetAllJson();
		}

		public void SetStringValue(string key, string value)
		{
			if defined(Android)
				AndroidUserSettingsImpl.SetStringValue(key, value, _name);
			else if defined(iOS)
				IOSUserSettingsImpl.SetStringValue(key, value, _name);
			else
				DesktopUserSettingsImpl.GetInstance(_name).SetStringValue(key, value);

			NotifyChanged(key);
		}

		public void SetNumberValue(string key, double value)
		{
			if defined(Android)
				AndroidUserSettingsImpl.SetNumberValue(key, value, _name);
			else if defined(iOS)
				IOSUserSettingsImpl.SetNumberValue(key, value, _name);
			else
				DesktopUserSettingsImpl.GetInstance(_name).SetNumberValue(key, value);

			NotifyChanged(key);
		}

		public void SetBooleanValue(string key, bool value)
		{
			if defined(Android)
				AndroidUserSettingsImpl.SetBooleanValue(key, value, _name);
			else if defined(iOS)
				IOSUserSettingsImpl.SetBooleanValue(key, value, _name);
			else
				DesktopUserSettingsImpl.GetInstance(_name).SetBooleanValue(key, value);

			NotifyChanged(key);
		}

		public void Remove(string key)
		{
			if defined(Android)
				AndroidUserSettingsImpl.Remove(key, _name);
			else if defined(iOS)
				IOSUserSettingsImpl.Remove(key, _name);
			else
				DesktopUserSettingsImpl.GetInstance(_name).Remove(key);

			NotifyChanged(key);
		}

		public void Clear()
		{
			if defined(Android)
				AndroidUserSettingsImpl.Clear(_name);
			else if defined(iOS)
				IOSUserSettingsImpl.Clear(_name);
			else
				DesktopUserSettingsImpl.GetInstance(_name).Clear();

			NotifyChanged(null);
		}

		void NotifyChanged(string key)
		{
			if (_changedListener == null || _changedContext == null)
				return;

			try
			{
				_changedContext.Invoke(new ChangedClosure(this, key).Invoke);
			}
			catch (Exception)
			{
				_changedListener = null;
				_changedContext = null;
			}
		}

		class ChangedClosure
		{
			readonly UserSettingsStore _store;
			readonly string _key;

			public ChangedClosure(UserSettingsStore store, string key)
			{
				_store = store;
				_key = key;
			}

			public void Invoke(Context context)
			{
				try
				{
					if (_store._changedListener != null)
						_store._changedListener.Call(context, new object[] { _key });
				}
				catch (Exception)
				{
					_store._changedListener = null;
					_store._changedContext = null;
				}
			}
		}
	}
}
