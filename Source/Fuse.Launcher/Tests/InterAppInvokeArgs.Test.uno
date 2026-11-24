using Uno.Testing;
using FuseTest;

namespace Fuse.LauncherTest
{
	public class InterAppInvokeArgsTest : TestBase
	{
		[Test]
		public void Exposes_platform_metadata()
		{
			var args = new Uno.Platform.EventSources.InterAppInvokeArgs(
				"myapp://open?foo=bar#fragment", "com.example.app", true, true, false);

			Assert.AreEqual("myapp://open?foo=bar#fragment", args.Uri);
			Assert.AreEqual("?foo=bar", args.Query);
			Assert.AreEqual("com.example.app", args.SourceApplication);
			Assert.IsTrue(args.IsUniversalLink);
			Assert.IsTrue(args.IsOpenInPlace);
			Assert.IsFalse(args.IsColdStart);
		}
	}
}
