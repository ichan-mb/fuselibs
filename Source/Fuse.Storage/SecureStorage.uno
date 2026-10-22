using Uno;

namespace Fuse.Storage
{
	/**
		Native secure storage for small secrets.

		Uses the Keychain on iOS and the Android Keystore on Android 6.0 (API 23)
		and newer. On desktop, or on older Android versions, the methods throw.
	*/
	public static class SecureStorage
	{
		public static string Get(string key)
		{
			if defined(Android)
				return AndroidSecureStorage.GetValue(key);
			else if defined(iOS)
				return IOSSecureStorage.GetValue(key);
			else
				throw new NotSupportedException("Secure storage is only available on Android 6.0+ and iOS");
		}

		public static bool Set(string key, string value)
		{
			if defined(Android)
				return AndroidSecureStorage.SetValue(key, value);
			else if defined(iOS)
				return IOSSecureStorage.SetValue(key, value);
			else
				throw new NotSupportedException("Secure storage is only available on Android 6.0+ and iOS");
		}

		public static bool Remove(string key)
		{
			if defined(Android)
				return AndroidSecureStorage.RemoveValue(key);
			else if defined(iOS)
				return IOSSecureStorage.RemoveValue(key);
			else
				throw new NotSupportedException("Secure storage is only available on Android 6.0+ and iOS");
		}

		public static bool HasKey(string key)
		{
			if defined(Android)
				return AndroidSecureStorage.HasKey(key);
			else if defined(iOS)
				return IOSSecureStorage.HasKey(key);
			else
				throw new NotSupportedException("Secure storage is only available on Android 6.0+ and iOS");
		}

		public static bool Clear()
		{
			if defined(Android)
				return AndroidSecureStorage.Clear();
			else if defined(iOS)
				return IOSSecureStorage.Clear();
			else
				throw new NotSupportedException("Secure storage is only available on Android 6.0+ and iOS");
		}
	}
}
