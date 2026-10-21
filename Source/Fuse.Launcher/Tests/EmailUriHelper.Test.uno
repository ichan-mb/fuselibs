using Uno;
using Uno.Testing;
using Fuse;
using FuseTest;

namespace Fuse.LauncherTest
{
	public class EmailUriHelperTest : TestBase
	{
		[Test]
		public void BuildUri_NoFields_ReturnsBareMailto()
		{
			var uri = EmailUriHelper.BuildUri(new EmailMessage());
			Assert.AreEqual("mailto:", uri);
		}

		[Test]
		public void BuildUri_WithRecipient_DoesNotAddQuery()
		{
			var uri = EmailUriHelper.BuildUri(new EmailMessage
			{
				To = new string[] { "foo@example.com" }
			});
			Assert.AreEqual("mailto:foo@example.com", uri);
		}

		[Test]
		public void BuildUri_JoinsMultipleRecipients()
		{
			var uri = EmailUriHelper.BuildUri(new EmailMessage
			{
				To = new string[] { "foo@example.com", "bar@example.com" }
			});
			Assert.AreEqual("mailto:foo@example.com,bar@example.com", uri);
		}

		[Test]
		public void BuildUri_NormalizesSemicolonSeparatedRecipients()
		{
			var uri = EmailUriHelper.BuildUri(new EmailMessage
			{
				To = new string[] { "foo@example.com; bar@example.com, baz@example.com" }
			});
			Assert.AreEqual("mailto:foo@example.com,bar@example.com,baz@example.com", uri);
		}

		[Test]
		public void BuildUri_SkipsEmptyParameters()
		{
			var uri = EmailUriHelper.BuildUri(new EmailMessage
			{
				To = new string[] { "foo@example.com" },
				CarbonCopy = new string[0],
				Subject = "Hi"
			});
			Assert.AreEqual("mailto:foo@example.com?subject=Hi", uri);
		}

		[Test]
		public void BuildUri_OrdersCcBccSubjectAndBody()
		{
			var uri = EmailUriHelper.BuildUri(new EmailMessage
			{
				To = new string[] { "foo@example.com" },
				CarbonCopy = new string[] { "cc@example.com" },
				BlindCarbonCopy = new string[] { "bcc@example.com" },
				Subject = "Hi",
				Body = "Hello"
			});
			Assert.AreEqual(
				"mailto:foo@example.com?cc=cc@example.com&bcc=bcc@example.com&subject=Hi&body=Hello",
				uri);
		}

		[Test]
		public void BuildUri_EncodesSubjectAndBody()
		{
			var uri = EmailUriHelper.BuildUri(new EmailMessage
			{
				To = new string[] { "foo@example.com" },
				Subject = "Hello world",
				Body = "line1\nline2"
			});
			Assert.AreEqual("mailto:foo@example.com?subject=Hello%20world&body=line1%0Aline2", uri);
		}

		[Test]
		public void BuildUri_EncodesRecipientSpecialCharacters()
		{
			var uri = EmailUriHelper.BuildUri(new EmailMessage
			{
				To = new string[] { "foo+tag@example.com" },
				CarbonCopy = new string[] { "a&b@example.com" }
			});
			Assert.AreEqual("mailto:foo%2Btag@example.com?cc=a%26b@example.com", uri);
		}

		[Test]
		public void BuildUri_EncodesUnicode()
		{
			var uri = EmailUriHelper.BuildUri(new EmailMessage
			{
				To = new string[] { "J\u00F6hn@example.com" },
				Subject = "\u00B1"
			});
			Assert.AreEqual("mailto:J%C3%B6hn@example.com?subject=%C2%B1", uri);
		}

		[Test]
		public void BuildUri_AllowsEmptyRecipient()
		{
			var uri = EmailUriHelper.BuildUri(new EmailMessage
			{
				Subject = "Hi"
			});
			Assert.AreEqual("mailto:?subject=Hi", uri);
		}

		[Test]
		public void FromString_NormalizesLegacyRecipients()
		{
			var recipients = EmailUriHelper.FromString("a@example.com; b@example.com,,c@example.com");
			Assert.AreEqual(3, recipients.Length);
			Assert.AreEqual("a@example.com", recipients[0]);
			Assert.AreEqual("b@example.com", recipients[1]);
			Assert.AreEqual("c@example.com", recipients[2]);
		}

		[Test]
		public void BuildUri_LegacyRecipientsAreEncoded()
		{
			var uri = EmailUriHelper.BuildUri(
				EmailUriHelper.FromString("a+b@example.com;c@example.com"),
				null, null, "Hi", null);
			Assert.AreEqual("mailto:a%2Bb@example.com,c@example.com?subject=Hi", uri);
		}
	}
}
