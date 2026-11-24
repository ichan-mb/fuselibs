using Uno;
using Uno.Collections;
using Uno.Testing;
using Fuse;
using FuseTest;

namespace Fuse.LauncherTest
{
	public class InterAppUriHelperTest : TestBase
	{
		[Test]
		public void IsApplicationId_accepts_package_names()
		{
			Assert.IsTrue(InterAppUriHelper.IsApplicationId("com.example.app"));
			Assert.IsTrue(InterAppUriHelper.IsApplicationId("myapp"));
		}

		[Test]
		public void IsApplicationId_rejects_uris()
		{
			Assert.IsFalse(InterAppUriHelper.IsApplicationId("myapp://host"));
			Assert.IsFalse(InterAppUriHelper.IsApplicationId("https://fuseopen.com"));
			Assert.IsFalse(InterAppUriHelper.IsApplicationId("mailto:user@example.com"));
			Assert.IsFalse(InterAppUriHelper.IsApplicationId("tel:+4712345678"));
		}

		[Test]
		public void IsApplicationId_rejects_paths_and_empty_values()
		{
			Assert.IsFalse(InterAppUriHelper.IsApplicationId("com.example.app/activity"));
			Assert.IsFalse(InterAppUriHelper.IsApplicationId("com.example.app activity"));
			Assert.IsFalse(InterAppUriHelper.IsApplicationId(""));
			Assert.IsFalse(InterAppUriHelper.IsApplicationId(null));
		}

		[Test]
		public void AndroidStoreUri_builds_market_and_web_uris()
		{
			Assert.AreEqual("market://details?id=com.example.app",
				InterAppUriHelper.AndroidStoreUri("com.example.app"));
			Assert.AreEqual("https://play.google.com/store/apps/details?id=com.example.app",
				InterAppUriHelper.AndroidStoreWebUri("com.example.app"));
		}

		[Test]
		public void AndroidStoreUri_preserves_explicit_urls()
		{
			Assert.AreEqual("https://play.google.com/store/apps/details?id=com.example.app",
				InterAppUriHelper.AndroidStoreUri("https://play.google.com/store/apps/details?id=com.example.app"));
		}

		[Test]
		public void AppleStoreUri_builds_app_store_uris()
		{
			Assert.AreEqual("itms-apps://itunes.apple.com/app/id123456789",
				InterAppUriHelper.AppleStoreUri("123456789"));
			Assert.AreEqual("itms-apps://itunes.apple.com/app/id123456789",
				InterAppUriHelper.AppleStoreUri("id123456789"));
			Assert.AreEqual("https://apps.apple.com/app/id123456789",
				InterAppUriHelper.AppleStoreWebUri("123456789"));
		}

		[Test]
		public void AppleStoreUri_preserves_explicit_urls()
		{
			Assert.AreEqual("https://apps.apple.com/app/id123456789",
				InterAppUriHelper.AppleStoreUri("https://apps.apple.com/app/id123456789"));
		}

		[Test]
		public void SplitAndroidFlags_splits_comma_separated_values()
		{
			var flags = InterAppUriHelper.SplitAndroidFlags("newTask, clearTop");
			Assert.AreEqual(2, flags.Length);
			Assert.AreEqual("newTask", flags[0]);
			Assert.AreEqual(" clearTop", flags[1]);
			Assert.IsTrue(InterAppUriHelper.SplitAndroidFlags(null) == null);
		}

		[Test]
		public void NormalizeAndroidFlags_normalizes_names()
		{
			var flags = InterAppUriHelper.NormalizeAndroidFlags(
				new[] { "newTask", " CLEARTOP ", "clearTask" });

			Assert.AreEqual(3, flags.Length);
			Assert.AreEqual("newTask", flags[0]);
			Assert.AreEqual("clearTop", flags[1]);
			Assert.AreEqual("clearTask", flags[2]);
		}

		[Test]
		public void NormalizeAndroidFlags_returns_null_for_empty_lists()
		{
			Assert.IsTrue(InterAppUriHelper.NormalizeAndroidFlags(null) == null);
			Assert.IsTrue(InterAppUriHelper.NormalizeAndroidFlags(new string[0]) == null);
		}

		[Test]
		public void NormalizeAndroidFlags_rejects_unknown_names()
		{
			Assert.Throws<ArgumentException>(() =>
				InterAppUriHelper.NormalizeAndroidFlags(new[] { "bogus" }));
		}

		[Test]
		public void FlattenExtras_produces_key_value_pairs()
		{
			var extras = InterAppUriHelper.FlattenExtras(
				new Dictionary<string, string> { { "key", "value" } });

			Assert.AreEqual(2, extras.Length);
			Assert.AreEqual("key", extras[0]);
			Assert.AreEqual("value", extras[1]);
			Assert.IsTrue(InterAppUriHelper.FlattenExtras(null) == null);
		}
	}
}
