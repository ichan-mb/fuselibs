using Uno;
using Uno.Testing;
using Fuse;
using Fuse.LauncherImpl;
using FuseTest;

namespace Fuse.LauncherTest
{
	public class InAppBrowserLauncherTest : TestBase
	{
		[Test]
		public void AcceptsHttpAndHttpsUrls()
		{
			InAppBrowserLauncher.ValidateUrl("https://fuseopen.com");
			InAppBrowserLauncher.ValidateUrl("http://example.com/path?q=1#fragment");
			InAppBrowserLauncher.ValidateUrl("https://example.com:8443/path");
			InAppBrowserLauncher.ValidateUrl("HTTPS://EXAMPLE.COM");
		}

		[Test]
		public void RejectsNullUrl()
		{
			Assert.Throws<ArgumentNullException>(() => InAppBrowserLauncher.ValidateUrl(null));
		}

		[Test]
		public void RejectsEmptyUrl()
		{
			Assert.Throws<ArgumentException>(() => InAppBrowserLauncher.ValidateUrl(""));
		}

		[Test]
		public void RejectsMalformedUrl()
		{
			Assert.Throws<ArgumentException>(() => InAppBrowserLauncher.ValidateUrl("not a url"));
		}

		[Test]
		public void RejectsNonHttpSchemes()
		{
			Assert.Throws<ArgumentException>(() => InAppBrowserLauncher.ValidateUrl("ftp://example.com"));
			Assert.Throws<ArgumentException>(() => InAppBrowserLauncher.ValidateUrl("file:///tmp/test"));
			Assert.Throws<ArgumentException>(() => InAppBrowserLauncher.ValidateUrl("mailto:test@example.com"));
		}

		[Test]
		public void OptionsHaveSensibleDefaults()
		{
			var options = new InAppBrowserOptions();
			Assert.IsTrue(options.CollapseChromeOnScroll);
			Assert.IsTrue(options.BookmarksButtonEnabled);
			Assert.IsTrue(options.DownloadButtonEnabled);
			Assert.IsTrue(options.Animated);
			Assert.IsTrue(options.FallbackToExternalBrowser);
			Assert.IsFalse(options.ReaderMode);
			Assert.IsFalse(options.ShowTitle);
			Assert.AreEqual(InAppBrowserDismissButtonStyle.Done, options.DismissButtonStyle);
			Assert.AreEqual(InAppBrowserPresentationStyle.Automatic, options.PresentationStyle);
			Assert.AreEqual(InAppBrowserSheetSize.Default, options.SheetSize);
			Assert.AreEqual(InAppBrowserColorScheme.System, options.ColorScheme);
			Assert.AreEqual(InAppBrowserShareState.Default, options.ShareState);
		}

		[Test]
		public void ParsesColorsToArgb()
		{
			int argb;
			Assert.IsTrue(InAppBrowserLauncher.TryGetColor("#FF0000", out argb));
			Assert.AreEqual(255, (argb >> 24) & 0xff);
			Assert.AreEqual(255, (argb >> 16) & 0xff);
			Assert.AreEqual(0, (argb >> 8) & 0xff);
			Assert.AreEqual(0, argb & 0xff);

			Assert.IsFalse(InAppBrowserLauncher.TryGetColor(null, out argb));
			Assert.IsFalse(InAppBrowserLauncher.TryGetColor("", out argb));
		}

		[Test]
		public void RejectsInvalidColor()
		{
			Assert.Throws<ArgumentException>(TryGetInvalidColor);
		}

		static void TryGetInvalidColor()
		{
			int argb;
			InAppBrowserLauncher.TryGetColor("red", out argb);
		}
	}
}
