using Uno.Testing;
using Fuse;
using FuseTest;

namespace Fuse.LauncherTest
{
	public class PhoneUriHelperTest : TestBase
	{
		[Test]
		public void PhoneNumberToTelUri_removes_separators()
		{
			var phoneUri = PhoneUriHelper.PhoneNumberToTelUri("123 33 321");
			Assert.AreEqual("tel:12333321", phoneUri);
		}

		[Test]
		public void PhoneNumbersToSmstoUri_joins_recipients()
		{
			var phoneUri = PhoneUriHelper.PhoneNumbersToSmstoUri(new[] { "123 33 321", "456" });
			Assert.AreEqual("smsto:12333321,456", phoneUri);
		}

		[Test]
		public void PhoneNumbersToIosSmsUri_uses_ampersand_body()
		{
			var phoneUri = PhoneUriHelper.PhoneNumbersToIosSmsUri(new[] { "123 33 321" }, "hi there");
			Assert.AreEqual("sms:12333321&body=hi%20there", phoneUri);
		}

		[Test]
		public void NormalizeNumber_preserves_international_prefix()
		{
			Assert.AreEqual("+4712345678", PhoneUriHelper.NormalizeNumber("+47 (123) 45-678"));
		}

		[Test]
		public void NormalizeNumber_converts_keypad_letters()
		{
			Assert.AreEqual("18003569377", PhoneUriHelper.NormalizeNumber("1-800-FLOWERS"));
		}

		[Test]
		public void PhoneNumberToTelUri_preserves_ussd_code()
		{
			Assert.AreEqual("tel:*123%23", PhoneUriHelper.PhoneNumberToTelUri("*123#"));
		}

		[Test]
		public void PhoneNumbersToIosSmsUri_preserves_international_prefix()
		{
			var phoneUri = PhoneUriHelper.PhoneNumbersToIosSmsUri(new[] { "+47 123" }, null);
			Assert.AreEqual("sms:+47123", phoneUri);
		}

		[Test]
		public void PhoneNumberToFaceTimeUri_uses_video_or_audio_scheme()
		{
			Assert.AreEqual("facetime:+47123", PhoneUriHelper.PhoneNumberToFaceTimeUri("+47 123", false));
			Assert.AreEqual("facetime-audio:+47123", PhoneUriHelper.PhoneNumberToFaceTimeUri("+47 123", true));
		}

		[Test]
		public void PhoneNumberToFaceTimeUri_accepts_apple_id()
		{
			Assert.AreEqual("facetime-audio:user%40example.com",
				PhoneUriHelper.PhoneNumberToFaceTimeUri("user@example.com", true));
		}
	}
}
