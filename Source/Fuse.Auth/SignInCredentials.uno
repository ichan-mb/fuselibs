using Uno;
using Fuse.Storage;

namespace Fuse
{
	/**
		Stores platform sign-in credentials in secure storage when available.

		Existing credentials written to UserSettings by older versions are
		migrated lazily on first read.
	*/
	internal static class SignInCredentials
	{
		static readonly string[] Keys = new string[]
		{
			"platformSignIn.userId",
			"platformSignIn.lastName",
			"platformSignIn.firstName",
			"platformSignIn.email",
			"platformSignIn.user",
			"platformSignIn.password"
		};

		static bool CanUseSecureStorage
		{
			get
			{
				if defined(Android)
					return global::Android.Base.Versions.ApiLevel >= 23;
				else if defined(iOS)
					return true;
				else
					return false;
			}
		}

		public static string Get(string key)
		{
			if (CanUseSecureStorage)
			{
				var secure = GetSecure(key);
				if (!string.IsNullOrEmpty(secure))
				{
					// Clean up any legacy value left by older versions.
					RemoveLegacy(key);
					return secure;
				}
			}

			var legacy = GetLegacy(key);
			if (!string.IsNullOrEmpty(legacy))
			{
				if (CanUseSecureStorage && SetSecure(key, legacy))
					RemoveLegacy(key);

				return legacy;
			}

			return "";
		}

		public static void Set(string key, string value)
		{
			if (string.IsNullOrEmpty(value))
				return;

			if (CanUseSecureStorage && SetSecure(key, value))
			{
				RemoveLegacy(key);
				return;
			}

			SetLegacy(key, value);
		}

		public static void MigrateAll()
		{
			for (int i = 0; i < Keys.Length; i++)
				Get(Keys[i]);
		}

		public static void Clear()
		{
			for (int i = 0; i < Keys.Length; i++)
			{
				if (CanUseSecureStorage)
					RemoveSecure(Keys[i]);

				RemoveLegacy(Keys[i]);
			}
		}

		static string GetSecure(string key)
		{
			try
			{
				return SecureStorage.Get(key);
			}
			catch (Exception)
			{
				return null;
			}
		}

		static bool SetSecure(string key, string value)
		{
			try
			{
				return SecureStorage.Set(key, value);
			}
			catch (Exception)
			{
				return false;
			}
		}

		static void RemoveSecure(string key)
		{
			try
			{
				SecureStorage.Remove(key);
			}
			catch (Exception) { }
		}

		static string GetLegacy(string key)
		{
			if defined(Android)
				return AndroidUserSettingsImpl.GetStringValue(key);
			else if defined(iOS)
				return IOSUserSettingsImpl.GetStringValue(key);
			else
				return DesktopUserSettingsImpl.GetInstance().GetStringValue(key);
		}

		static void RemoveLegacy(string key)
		{
			if defined(Android)
				AndroidUserSettingsImpl.Remove(key);
			else if defined(iOS)
				IOSUserSettingsImpl.Remove(key);
			else
				DesktopUserSettingsImpl.GetInstance().Remove(key);
		}

		static void SetLegacy(string key, string value)
		{
			if defined(Android)
				AndroidUserSettingsImpl.SetStringValue(key, value);
			else if defined(iOS)
				IOSUserSettingsImpl.SetStringValue(key, value);
			else
				DesktopUserSettingsImpl.GetInstance().SetStringValue(key, value);
		}
	}
}
