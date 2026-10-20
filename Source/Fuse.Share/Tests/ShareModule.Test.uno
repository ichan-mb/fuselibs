using Uno;
using Uno.Testing;
using Fuse.Scripting;
using Fuse.Scripting.JavaScript.Test;
using Fuse.Share;

namespace Fuse.Share.Test
{
	public class ShareRequestParserTest
	{
		static Scripting.Object Options(Context context, string source)
		{
			return context.Evaluate("ShareOptions", source) as Scripting.Object;
		}

		[Test]
		public void ParsesTextAndUrl()
		{
			JSTest.RunTest(context =>
			{
				var options = Options(context,
					"({ text: 'hello', url: 'https://fuseopen.com/', subject: 'subject', chooserTitle: 'chooser' })");

				var request = ShareRequestParser.FromOptions(new object[] { options });

				Assert.AreEqual("hello", request.Text);
				Assert.AreEqual("https://fuseopen.com/", request.Url);
				Assert.AreEqual("subject", request.Subject);
				Assert.AreEqual("chooser", request.ChooserTitle);
				Assert.IsTrue(request.HasText);
				Assert.IsTrue(request.HasUrl);
				Assert.IsFalse(request.HasFiles);
				Assert.IsFalse(request.HasOrigin);
			});
		}

		[Test]
		public void ParsesFileArray()
		{
			JSTest.RunTest(context =>
			{
				var options = Options(context, "({ files: ['/a.jpg', '/b.jpg'], mimeType: 'image/jpeg' })");
				var request = ShareRequestParser.FromOptions(new object[] { options });

				Assert.AreEqual(2, request.Files.Length);
				Assert.AreEqual("/a.jpg", request.Files[0]);
				Assert.AreEqual("/b.jpg", request.Files[1]);
				Assert.AreEqual("image/jpeg", request.MimeType);
				Assert.IsTrue(request.HasFiles);
			});
		}

		[Test]
		public void ParsesSingleFileAlias()
		{
			JSTest.RunTest(context =>
			{
				var options = Options(context, "({ file: '/one.png' })");
				var request = ShareRequestParser.FromOptions(new object[] { options });

				Assert.AreEqual(1, request.Files.Length);
				Assert.AreEqual("/one.png", request.Files[0]);
			});
		}

		[Test]
		public void RejectsEmptyOptions()
		{
			JSTest.RunTest(context =>
			{
				var options = Options(context, "({})");
				Assert.Throws<Exception>(() => ShareRequestParser.FromOptions(new object[] { options }));
			});
		}

		[Test]
		public void RejectsNonStringFileEntries()
		{
			JSTest.RunTest(context =>
			{
				var options = Options(context, "({ files: [1] })");
				Assert.Throws<Exception>(() => ShareRequestParser.FromOptions(new object[] { options }));
			});
		}

		[Test]
		public void GuardAllowsOnlyOneActiveShare()
		{
			ShareSessionGuard.End();

			Assert.IsTrue(ShareSessionGuard.TryBegin());
			Assert.IsFalse(ShareSessionGuard.TryBegin());

			ShareSessionGuard.End();
			Assert.IsTrue(ShareSessionGuard.TryBegin());
			ShareSessionGuard.End();
		}
	}
}
