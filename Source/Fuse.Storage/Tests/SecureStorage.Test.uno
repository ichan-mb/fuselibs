using Uno;
using Uno.Testing;
using FuseTest;

namespace Fuse.Storage.Test
{
	public class SecureStorageTest : TestBase
	{
		[Test]
		public void SecureStorageIsNotSupportedOnDesktop()
		{
			if defined(!MOBILE)
				Assert.Throws<NotSupportedException>(() => SecureStorage.Get("key"));
		}
	}
}
