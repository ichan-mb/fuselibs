using Uno;
using Uno.Collections;
using Uno.Testing;
using Uno.Threading;
using Fuse;
using FuseTest;

namespace Fuse.ImageTools.Test
{
	public class ImageToolsTest : TestBase
	{
		const string TestImage = "iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPAQMAAAABGAcJAAAABlBMVEX9//wAAQATpOzaAAAAH0l" +
			"EQVQI12MAAoMHIFLAAYSEwIiJgYGZASrI38AAAwBamgM5VF7xgwAAAABJRU5ErkJggg==";

		AutoResetEvent _done = new AutoResetEvent(false);

		[Test]
		[extern(NATIVE) Ignore("Only supported on dotnet, Android or iOS")]
		[extern(Android) Ignore("https://github.com/fuse-open/fuselibs/issues/690")]
		public void CreatingAnImageSucceeds()
		{
			using (var root = new TestRootPanel()){
				var image = Wait(ImageTools.ImageFromBase64(TestImage));
				Assert.AreNotEqual(null, image);
				Assert.IsTrue(Uno.IO.File.Exists(image.Path));
			}
		}

		void MakeInvalidImage()
		{
			var future = ImageTools.ImageFromBase64("iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPAQMAAAABGAcJAAAABlBMVEX9//wAAQATpOzaAAAAH0l");
			future.Then(OnSuccess, Fail);
		}

		[Test]
		[extern(NATIVE) Ignore("Only supported on dotnet, Android or iOS")]
		[extern(iOS || Android) Ignore("https://github.com/fuse-open/fuselibs/issues/674")]
		public void CreatingAnImageFails()
		{
			Assert.Throws<FormatException>(MakeInvalidImage);
		}

		[Test]
		[extern(NATIVE) Ignore("Only supported on dotnet, Android or iOS")]
		[extern(Android) Ignore("https://github.com/fuse-open/fuselibs/issues/690")]
		public void ImageInfoIsPopulated()
		{
			using (var root = new TestRootPanel()){
				var image = Wait(ImageTools.ImageFromBase64(TestImage));

				Assert.AreEqual("image/png", image.MimeType);
				Assert.IsTrue(image.FileSize > 0);
				Assert.AreEqual(15, image.Width);
				Assert.AreEqual(15, image.Height);
				Assert.AreEqual(1, image.Orientation);
				Assert.AreEqual(1, (int)image.Info["frameCount"]);
				Assert.IsFalse((bool)image.Info["isAnimated"]);
				Assert.AreEqual("image/png", (string)image.Info["mimeType"]);
			}
		}

		[Test]
		[extern(NATIVE) Ignore("Only supported on dotnet, Android or iOS")]
		[extern(Android) Ignore("https://github.com/fuse-open/fuselibs/issues/690")]
		public void ResizeAndRotateChangeDimensions()
		{
			using (var root = new TestRootPanel()){
				var image = Wait(ImageTools.ImageFromBase64(TestImage));
				var resized = Wait(ImageTools.Resize(image, 8, 4, ResizeMode.IgnoreAspect, false, "png", 90));

				Assert.AreEqual(8, resized.Width);
				Assert.AreEqual(4, resized.Height);
				Assert.AreNotEqual(image.Path, resized.Path);

				var rotated = Wait(ImageTools.Rotate(resized, 90, "png", 90, false));
				Assert.AreEqual(4, rotated.Width);
				Assert.AreEqual(8, rotated.Height);
				Assert.AreNotEqual(resized.Path, rotated.Path);
			}
		}

		[Test]
		[extern(NATIVE) Ignore("Only supported on dotnet, Android or iOS")]
		[extern(Android) Ignore("https://github.com/fuse-open/fuselibs/issues/690")]
		public void FlipKeepsDimensions()
		{
			using (var root = new TestRootPanel()){
				var image = Wait(ImageTools.ImageFromBase64(TestImage));
				var flipped = Wait(ImageTools.Flip(image, true, true, "png", 90, false));

				Assert.AreEqual(image.Width, flipped.Width);
				Assert.AreEqual(image.Height, flipped.Height);
				Assert.AreNotEqual(image.Path, flipped.Path);
			}
		}

		[Test]
		[extern(NATIVE) Ignore("Only supported on dotnet, Android or iOS")]
		[extern(Android) Ignore("https://github.com/fuse-open/fuselibs/issues/690")]
		public void Base64RoundTripHonorsFormat()
		{
			using (var root = new TestRootPanel()){
				var image = Wait(ImageTools.ImageFromBase64(TestImage));
				var base64 = Wait(ImageTools.ImageToBase64(image, "png", 90));

				Assert.IsFalse(base64.Contains("\n"));

				var roundTrip = Wait(ImageTools.ImageFromBase64(base64));
				Assert.AreEqual("image/png", roundTrip.MimeType);
			}
		}

		[Test]
		[extern(NATIVE) Ignore("Only supported on dotnet, Android or iOS")]
		[extern(Android) Ignore("https://github.com/fuse-open/fuselibs/issues/690")]
		public void DeleteRemovesTheImage()
		{
			using (var root = new TestRootPanel()){
				var image = Wait(ImageTools.ImageFromBase64(TestImage));
				Assert.IsTrue(Uno.IO.File.Exists(image.Path));

				Assert.IsTrue(Wait(ImageTools.Delete(image)));
				Assert.IsFalse(Uno.IO.File.Exists(image.Path));
			}
		}

		[Test]
		[extern(NATIVE) Ignore("Only supported on dotnet, Android or iOS")]
		[extern(Android) Ignore("https://github.com/fuse-open/fuselibs/issues/690")]
		public void ThumbnailFitsWithinBounds()
		{
			using (var root = new TestRootPanel()){
				var image = Wait(ImageTools.ImageFromBase64(TestImage));
				var thumbnail = Wait(ImageTools.Thumbnail(image, 8, 8, "png", 90));

				Assert.IsTrue(thumbnail.Width <= 8);
				Assert.IsTrue(thumbnail.Height <= 8);
				Assert.AreEqual(8, thumbnail.Width);
				Assert.AreEqual(8, thumbnail.Height);
				Assert.AreNotEqual(image.Path, thumbnail.Path);
			}
		}

		[Test]
		[extern(NATIVE) Ignore("Only supported on dotnet, Android or iOS")]
		[extern(Android) Ignore("https://github.com/fuse-open/fuselibs/issues/690")]
		public void FitAndPadModes()
		{
			using (var root = new TestRootPanel()){
				var image = Wait(ImageTools.ImageFromBase64(TestImage));

				var fitted = Wait(ImageTools.Resize(image, 8, 4, ResizeMode.Fit, false, "png", 90));
				Assert.AreEqual(4, fitted.Width);
				Assert.AreEqual(4, fitted.Height);

				var padded = Wait(ImageTools.Resize(image, 8, 4, ResizeMode.Pad, false, "png", 90, 0));
				Assert.AreEqual(8, padded.Width);
				Assert.AreEqual(4, padded.Height);
			}
		}

		[Test]
		[extern(NATIVE) Ignore("Only supported on dotnet, Android or iOS")]
		[extern(Android) Ignore("https://github.com/fuse-open/fuselibs/issues/690")]
		public void ConvertChangesFormat()
		{
			using (var root = new TestRootPanel()){
				var image = Wait(ImageTools.ImageFromBase64(TestImage));
				var converted = Wait(ImageTools.Convert(image, "jpg", 90, false));

				Assert.AreEqual(15, converted.Width);
				Assert.AreEqual(15, converted.Height);
				Assert.AreEqual("image/jpeg", converted.MimeType);
				Assert.AreNotEqual(image.Path, converted.Path);
			}
		}

		[Test]
		[extern(NATIVE) Ignore("Only supported on dotnet, Android or iOS")]
		[extern(Android) Ignore("https://github.com/fuse-open/fuselibs/issues/690")]
		public void SavePersistsToDocuments()
		{
			using (var root = new TestRootPanel()){
				var image = Wait(ImageTools.ImageFromBase64(TestImage));
				var saved = Wait(ImageTools.Save(image, "documents", "imagetools-test", "png", 90));

				Assert.IsTrue(Uno.IO.File.Exists(saved.Path));
				Assert.IsTrue(saved.Path.Contains("imagetools-test"));
				Assert.AreEqual("image/png", saved.MimeType);

				Wait(ImageTools.Delete(saved));
			}
		}

		[Test]
		[extern(NATIVE) Ignore("Only supported on dotnet, Android or iOS")]
		[extern(Android) Ignore("https://github.com/fuse-open/fuselibs/issues/690")]
		public void ImageInfoContainsExifObject()
		{
			using (var root = new TestRootPanel()){
				var image = Wait(ImageTools.ImageFromBase64(TestImage));
				Assert.IsTrue(image.Info.ContainsKey("exif"));
				Assert.AreNotEqual(null, image.Info["exif"] as Dictionary<string, object>);
			}
		}

		[Test]
		[extern(NATIVE) Ignore("Only supported on dotnet, Android or iOS")]
		[extern(Android) Ignore("https://github.com/fuse-open/fuselibs/issues/690")]
		public void CompositeKeepsBaseDimensions()
		{
			using (var root = new TestRootPanel()){
				var image = Wait(ImageTools.ImageFromBase64(TestImage));
				var overlay = Wait(ImageTools.Resize(image, 4, 4, ResizeMode.IgnoreAspect, false, "png", 90));
				var composited = Wait(ImageTools.Composite(image, overlay, 2, 2, 0.5, "png", 90, false));

				Assert.AreEqual(15, composited.Width);
				Assert.AreEqual(15, composited.Height);
				Assert.AreNotEqual(image.Path, composited.Path);
			}
		}

		[Test]
		[extern(NATIVE) Ignore("Only supported on dotnet, Android or iOS")]
		[extern(Android) Ignore("https://github.com/fuse-open/fuselibs/issues/690")]
		public void GrayscaleFilterKeepsDimensions()
		{
			using (var root = new TestRootPanel()){
				var image = Wait(ImageTools.ImageFromBase64(TestImage));
				var filtered = Wait(ImageTools.Filter(image, "grayscale", 0, 10, "png", 90, false));

				Assert.AreEqual(15, filtered.Width);
				Assert.AreEqual(15, filtered.Height);
				Assert.AreNotEqual(image.Path, filtered.Path);
			}
		}

		[Test]
		[extern(NATIVE) Ignore("Only supported on dotnet, Android or iOS")]
		[extern(Android) Ignore("https://github.com/fuse-open/fuselibs/issues/690")]
		public void DrawTextKeepsDimensions()
		{
			using (var root = new TestRootPanel()){
				var image = Wait(ImageTools.ImageFromBase64(TestImage));
				var captioned = Wait(ImageTools.DrawText(image, "Test", 2, 12, 10.0f, null, -16777216, "png", 90, false));

				Assert.AreEqual(15, captioned.Width);
				Assert.AreEqual(15, captioned.Height);
				Assert.AreNotEqual(image.Path, captioned.Path);
			}
		}

		[Test]
		[extern(NATIVE) Ignore("Only supported on dotnet, Android or iOS")]
		[extern(Android) Ignore("https://github.com/fuse-open/fuselibs/issues/690")]
		public void PixelBufferHasExpectedLength()
		{
			using (var root = new TestRootPanel()){
				var image = Wait(ImageTools.ImageFromBase64(TestImage));
				var buffer = Wait(ImageTools.GetPixelBuffer(image));

				Assert.AreEqual(15 * 15 * 4, buffer.Length);
			}
		}

		[Test]
		[extern(NATIVE) Ignore("Only supported on dotnet, Android or iOS")]
		[extern(Android) Ignore("https://github.com/fuse-open/fuselibs/issues/690")]
		public void ImageFromUriLoadsFile()
		{
			using (var root = new TestRootPanel()){
				var image = Wait(ImageTools.ImageFromBase64(TestImage));
				var loaded = Wait(ImageTools.ImageFromUri("file://" + image.Path));

				Assert.AreEqual(image.Width, loaded.Width);
				Assert.AreEqual(image.Height, loaded.Height);
				Assert.AreEqual("image/png", loaded.MimeType);

				Wait(ImageTools.Delete(loaded));
			}
		}

		T Wait<T>(Future<T> future)
		{
			T result = default(T);
			Exception error = null;

			future.Then(
				x => { result = x; _done.Set(); },
				e => { error = e; _done.Set(); });

			_done.WaitOne();

			if (error != null)
				throw error;

			return result;
		}

		void OnSuccess(Image image)
		{
			_done.Set();
		}

		void Fail(Exception e)
		{
			_done.Set();
		}
	}
}
