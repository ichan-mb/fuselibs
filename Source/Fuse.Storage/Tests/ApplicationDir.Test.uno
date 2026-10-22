using Uno;
using Uno.IO;
using Uno.Testing;
using Uno.Threading;
using Fuse.Storage;
using FuseTest;

namespace Fuse.Storage.Test
{
	public class ApplicationDirTest : TestBase
	{
		static int _uniqueCounter;

		[Test]
		public void WriteReadExistsAndDelete()
		{
			var filename = GetUniqueFilename();
			try
			{
				Assert.IsFalse(ApplicationDir.Exists(filename));
				Assert.IsTrue(ApplicationDir.Write(filename, "hello"));
				Assert.IsTrue(ApplicationDir.Exists(filename));
				Assert.AreEqual("hello", ApplicationDir.Read(filename));

				Assert.IsTrue(WaitForSuccessAndGetValue(ApplicationDir.ExistsAsync(filename)));
				Assert.AreEqual("hello", WaitForSuccessAndGetValue(ApplicationDir.ReadAsync(filename)));

				Assert.IsTrue(ApplicationDir.Delete(filename));
				Assert.IsFalse(ApplicationDir.Exists(filename));
				Assert.IsFalse(ApplicationDir.Delete(filename));
			}
			finally
			{
				ApplicationDir.Delete(filename);
			}
		}

		[Test]
		public void AppendCreatesAndAppendsToFile()
		{
			var filename = GetUniqueFilename();
			try
			{
				Assert.IsTrue(ApplicationDir.Append(filename, "hello"));
				Assert.AreEqual("hello", ApplicationDir.Read(filename));

				Assert.IsTrue(WaitForSuccessAndGetValue(ApplicationDir.AppendAsync(filename, " world")));
				Assert.AreEqual("hello world", ApplicationDir.Read(filename));
			}
			finally
			{
				ApplicationDir.Delete(filename);
			}
		}

		[Test]
		public void AsyncDeleteRemovesFile()
		{
			var filename = GetUniqueFilename();
			try
			{
				ApplicationDir.Write(filename, "content");
				Assert.IsTrue(WaitForSuccessAndGetValue(ApplicationDir.DeleteAsync(filename)));
				Assert.IsFalse(ApplicationDir.Exists(filename));
			}
			finally
			{
				ApplicationDir.Delete(filename);
			}
		}

		[Test]
		public void CreateDirectoryAndListEntries()
		{
			var directory = GetUniqueFilename();
			var nestedDirectory = Path.Combine(directory, "nested");
			var filename = Path.Combine(nestedDirectory, "file.txt");
			try
			{
				Assert.IsTrue(ApplicationDir.CreateDirectory(nestedDirectory));
				Assert.IsTrue(Directory.Exists(Path.Combine(ApplicationDir.GetRootDirectory(), nestedDirectory)));
				Assert.IsTrue(ApplicationDir.Write(filename, "content"));

				var entries = ApplicationDir.List("");
				Assert.IsTrue(Contains(entries, directory));

				var nestedEntries = ApplicationDir.List(directory);
				Assert.AreEqual(1, nestedEntries.Length);
				Assert.AreEqual("nested", nestedEntries[0]);

				var asyncEntries = WaitForSuccessAndGetValue(ApplicationDir.ListAsync(directory));
				Assert.AreEqual(1, asyncEntries.Length);
				Assert.AreEqual("nested", asyncEntries[0]);
			}
			finally
			{
				DeleteDirectory(directory);
			}
		}

		[Test]
		public void CreateDirectoryAsyncCreatesDirectory()
		{
			var directory = GetUniqueFilename();
			try
			{
				Assert.IsTrue(WaitForSuccessAndGetValue(ApplicationDir.CreateDirectoryAsync(directory)));
				Assert.IsTrue(Directory.Exists(Path.Combine(ApplicationDir.GetRootDirectory(), directory)));
			}
			finally
			{
				DeleteDirectory(directory);
			}
		}

		[Test]
		public void RejectsPathsOutsideApplicationDirectory()
		{
			Assert.Throws<ArgumentException>(() => ApplicationDir.Write("../escape.txt", "x"));
			Assert.Throws<ArgumentException>(() => ApplicationDir.Write("cache/../../escape.txt", "x"));
			Assert.Throws<ArgumentException>(() => ApplicationDir.Exists("/absolute.txt"));
			Assert.Throws<ArgumentException>(() => ApplicationDir.Write("", "x"));
			Assert.Throws<ArgumentException>(() => ApplicationDir.List(".."));
		}

		[Test]
		public void ReadWriteBufferRoundTrip()
		{
			var filename = GetUniqueFilename();
			var data = new byte[] { 0, 1, 2, 3, 127, 255 };
			try
			{
				Assert.IsTrue(ApplicationDir.WriteBuffer(filename, data));

				var read = ApplicationDir.ReadBuffer(filename);
				Assert.AreEqual(data.Length, read.Length);
				for (int i = 0; i < data.Length; i++)
					Assert.AreEqual(data[i], read[i]);

				var readAsync = WaitForSuccessAndGetValue(ApplicationDir.ReadBufferAsync(filename));
				Assert.AreEqual(data.Length, readAsync.Length);

				var asyncData = new byte[] { 4, 5, 6 };
				Assert.IsTrue(WaitForSuccessAndGetValue(ApplicationDir.WriteBufferAsync(filename, asyncData)));
				Assert.AreEqual(asyncData.Length, ApplicationDir.ReadBuffer(filename).Length);
			}
			finally
			{
				ApplicationDir.Delete(filename);
			}
		}

		[Test]
		public void GetFileInfoReturnsSizeAndType()
		{
			var filename = GetUniqueFilename();
			try
			{
				ApplicationDir.Write(filename, "hello");

				var info = ApplicationDir.GetFileInfo(filename);
				Assert.IsTrue(info.Exists);
				Assert.IsTrue(info is FileInfo);
				Assert.AreEqual(5L, ((FileInfo)info).Length);

				var asyncInfo = WaitForSuccessAndGetValue(ApplicationDir.GetFileInfoAsync(filename));
				Assert.IsTrue(asyncInfo.Exists);
				Assert.AreEqual(5L, ((FileInfo)asyncInfo).Length);

				var missing = ApplicationDir.GetFileInfo(GetUniqueFilename());
				Assert.IsFalse(missing.Exists);
			}
			finally
			{
				ApplicationDir.Delete(filename);
			}
		}

		[Test]
		public void CopyAndMoveFile()
		{
			var source = GetUniqueFilename();
			var copy = source + ".copy";
			var moved = source + ".moved";
			var asyncCopy = source + ".acopy";
			var asyncMoved = source + ".amoved";
			try
			{
				ApplicationDir.Write(source, "content");

				Assert.IsTrue(ApplicationDir.Copy(source, copy));
				Assert.AreEqual("content", ApplicationDir.Read(copy));

				Assert.IsTrue(ApplicationDir.Move(copy, moved));
				Assert.IsFalse(ApplicationDir.Exists(copy));
				Assert.AreEqual("content", ApplicationDir.Read(moved));

				Assert.IsTrue(WaitForSuccessAndGetValue(ApplicationDir.CopyAsync(source, asyncCopy)));
				Assert.IsTrue(WaitForSuccessAndGetValue(ApplicationDir.MoveAsync(asyncCopy, asyncMoved)));
				Assert.IsFalse(ApplicationDir.Exists(asyncCopy));
				Assert.AreEqual("content", ApplicationDir.Read(asyncMoved));
			}
			finally
			{
				ApplicationDir.Delete(source);
				ApplicationDir.Delete(copy);
				ApplicationDir.Delete(moved);
				ApplicationDir.Delete(asyncCopy);
				ApplicationDir.Delete(asyncMoved);
			}
		}

		[Test]
		public void CopyDirectoryRecursively()
		{
			var directory = GetUniqueFilename();
			var nested = Path.Combine(directory, "nested");
			var filename = Path.Combine(nested, "file.txt");
			var copy = directory + "-copy";
			try
			{
				ApplicationDir.CreateDirectory(nested);
				ApplicationDir.Write(filename, "content");

				Assert.Throws<Exception>(() => ApplicationDir.Copy(directory, Path.Combine(directory, "copy")));

				Assert.IsTrue(ApplicationDir.Copy(directory, copy));
				Assert.AreEqual("content", ApplicationDir.Read(Path.Combine(copy, "nested", "file.txt")));
			}
			finally
			{
				DeleteDirectory(directory);
				DeleteDirectory(copy);
			}
		}

		[Test]
		public void CacheDirectoryIsCreated()
		{
			var cache = ApplicationDir.GetCacheRootDirectory();
			Assert.IsTrue(Directory.Exists(cache));
			Assert.AreEqual(cache, ApplicationDir.GetCacheRootDirectory());
		}

		static void DeleteDirectory(string path)
		{
			var fullPath = Path.Combine(ApplicationDir.GetRootDirectory(), path);
			if (Directory.Exists(fullPath))
				Directory.Delete(fullPath, true);
		}

		static string GetUniqueFilename()
		{
			string filename;
			do
			{
				filename = "storage-test-" + (++_uniqueCounter);
			} while (ApplicationDir.Exists(filename));

			return filename;
		}

		static bool Contains(string[] values, string value)
		{
			foreach (var v in values)
				if (v == value)
					return true;

			return false;
		}

		T WaitForSuccessAndGetValue<T>(Future<T> future)
		{
			future.Wait();

			var resultBox = new Box<T>();
			var exceptionBox = new Box<Exception>();
			future.Then(resultBox.Deliver, exceptionBox.Deliver);
			Assert.AreEqual(exceptionBox.Value, null, "Threw exception from future: " + exceptionBox.Value);

			return resultBox.Value;
		}

		class Box<T>
		{
			T _value;

			public void Deliver(T value)
			{
				_value = value;
			}

			public T Value
			{
				get { return _value; }
			}
		}
	}
}
