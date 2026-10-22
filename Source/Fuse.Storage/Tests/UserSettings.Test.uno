using Uno;
using Uno.Testing;
using Fuse.Storage;
using FuseTest;

namespace Fuse.Storage.Test
{
	public class DesktopUserSettingsTest : TestBase
	{
		[Test]
		public void KeysAndGetAllReflectStoredValues()
		{
			if defined(!MOBILE)
			{
				var settings = DesktopUserSettingsImpl.GetInstance();
				settings.Clear();

				Assert.IsFalse(settings.HasKey("string"));
				settings.SetStringValue("string", "value");
				settings.SetNumberValue("number", 1234567890123.0);
				settings.SetBooleanValue("boolean", true);

				Assert.IsTrue(settings.HasKey("string"));
				Assert.AreEqual("value", settings.GetStringValue("string"));
				Assert.AreEqual(1234567890123.0, settings.GetNumberValue("number"));
				Assert.IsTrue(settings.GetBooleanValue("boolean"));

				var keys = settings.GetKeys();
				Assert.AreEqual(3, keys.Length);
				Assert.IsTrue(Contains(keys, "string"));
				Assert.IsTrue(Contains(keys, "number"));
				Assert.IsTrue(Contains(keys, "boolean"));

				var all = Json.Parse(settings.GetAllJson()) as IObject;
				Assert.IsTrue(all != null);
				Assert.AreEqual("value", all["string"] as string);
				Assert.AreEqual(1234567890123.0, (double)all["number"]);
				Assert.AreEqual(true, (bool)all["boolean"]);

				settings.Clear();
			}
		}

		[Test]
		public void NamedStoresAreIsolated()
		{
			if defined(!MOBILE)
			{
				var first = new UserSettingsStore("test-store-a");
				var second = new UserSettingsStore("test-store-b");
				first.Clear();
				second.Clear();

				first.SetStringValue("key", "first");
				second.SetStringValue("key", "second");

				Assert.AreEqual("first", first.GetStringValue("key"));
				Assert.AreEqual("second", second.GetStringValue("key"));
				Assert.AreEqual("first", DesktopUserSettingsImpl.GetInstance("test-store-a").GetStringValue("key"));
				Assert.AreEqual("second", DesktopUserSettingsImpl.GetInstance("test-store-b").GetStringValue("key"));

				first.Clear();
				second.Clear();
			}
		}

		static bool Contains(string[] values, string value)
		{
			foreach (var v in values)
				if (v == value)
					return true;

			return false;
		}
	}
}
