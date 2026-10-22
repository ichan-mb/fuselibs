using Uno;
using Uno.IO;
using Uno.Time;
using Uno.UX;
using Uno.Threading;
using Fuse.Scripting;

namespace Fuse.Storage
{
	[UXGlobalModule]
	/**
		@scriptmodule FuseJS/Storage

		The storage API allows you to read from and write to files in the application directory.
		```js
			var Storage = require("FuseJS/Storage");
		```
		Check out the individual functions for documentation on how to use them.
	*/
	public sealed class StorageModule : NativeModule
	{
		static readonly StorageModule _instance;
		public StorageModule()
		{
			if(_instance != null) return;
			Resource.SetGlobalKey(_instance = this, "FuseJS/Storage");
			AddMember(new NativeProperty<string, string>("dataDirectory", GetDataDirectory));
			AddMember(new NativeProperty<string, string>("cacheDirectory", GetCacheDirectory));
			AddMember(new NativeFunction("writeSync", Write));
			AddMember(new NativeFunction("readSync", Read));
			AddMember(new NativeFunction("removeSync", Remove));
			// Note: 'delete' is a reserved word in TypeScript, so similar methods in the FileSystem module
			// were renamed to 'remove'. The 'removeSync' method in this module was renamed to match this.
			// Calling 'deleteSync' will still work to avoid breaking existing code.
			AddMember(new NativeFunction("deleteSync", Remove));
			AddMember(new NativeFunction("existsSync", Exists));
			AddMember(new NativeFunction("appendSync", Append));
			AddMember(new NativeFunction("listSync", ListSync));
			AddMember(new NativeFunction("createDirectorySync", CreateDirectorySync));
			AddMember(new NativeFunction("readBufferSync", ReadBufferSync));
			AddMember(new NativeFunction("writeBufferSync", WriteBufferSync));
			AddMember(new NativeFunction("getFileInfoSync", GetFileInfoSync));
			AddMember(new NativeFunction("copySync", CopySync));
			AddMember(new NativeFunction("moveSync", MoveSync));
			AddMember(new NativePromise<bool, bool>("write", WriteAsync, null));
			AddMember(new NativePromise<string, string>("read", ReadAsync, null));
			AddMember(new NativePromise<bool, bool>("remove", RemoveAsync, null));
			AddMember(new NativePromise<bool, bool>("exists", ExistsAsync, null));
			AddMember(new NativePromise<bool, bool>("append", AppendAsync, null));
			AddMember(new NativePromise<string[], Scripting.Array>("list", List, ToScriptingArray));
			AddMember(new NativePromise<bool, bool>("createDirectory", CreateDirectory, null));
			AddMember(new NativePromise<byte[], Scripting.Object>("readBuffer", ReadBuffer));
			AddMember(new NativePromise<bool, bool>("writeBuffer", WriteBuffer, null));
			AddMember(new NativePromise<FileSystemInfo, Scripting.Object>("getFileInfo", GetFileInfo, ToScriptingObject));
			AddMember(new NativePromise<bool, bool>("copy", Copy, null));
			AddMember(new NativePromise<bool, bool>("move", Move, null));
		}

		static string GetStringArg(object[] args, int index, string name)
		{
			if (args != null && args.Length > index && args[index] != null)
			{
				var value = args[index] as string;
				if (value != null)
					return value;
			}

			throw new Scripting.Error("Argument " + (index + 1) + " (" + name + ") is required to be a string");
		}

		static string GetOptionalStringArg(object[] args, int index)
		{
			if (args == null || args.Length <= index || args[index] == null)
				return "";

			var value = args[index] as string;
			if (value == null)
				throw new Scripting.Error("Argument " + (index + 1) + " is required to be a string");

			return value;
		}

		static byte[] GetBufferArg(object[] args, int index, string name)
		{
			if (args != null && args.Length > index && args[index] != null)
			{
				var value = args[index] as byte[];
				if (value != null)
					return value;
			}

			throw new Scripting.Error("Argument " + (index + 1) + " (" + name + ") is required to be an ArrayBuffer");
		}

		static Scripting.Array ToScriptingArray(Context context, string[] values)
		{
			var result = new object[values.Length];
			for (int i = 0; i < values.Length; i++)
				result[i] = values[i];

			return context.NewArray(result);
		}

		static Scripting.Object ToScriptingObject(Context context, FileSystemInfo info)
		{
			var result = context.NewObject();
			result["name"] = Path.GetFileName(info.FullName);
			result["exists"] = info.Exists;
			result["isDirectory"] = info is DirectoryInfo;

			if (info.Exists)
			{
				var fileInfo = info as FileInfo;
				if (fileInfo != null)
					result["size"] = (double)fileInfo.Length;

				result["lastModified"] = ToScriptingDate(context, info.LastWriteTimeUtc);
			}

			return result;
		}

		static object ToScriptingDate(Context context, ZonedDateTime time)
		{
			var msSinceUnixEpoch = ((time.ToInstant() - Uno.Time.Constants.UnixEpoch).Ticks)
									/ Uno.Time.Constants.TicksPerMillisecond;
			return context.Evaluate("(Date Converter)", string.Format("new Date({0})", msSinceUnixEpoch));
		}

		/**
			@scriptproperty dataDirectory

			The directory used for application-private data files.

			On desktop this is a per-project directory below the user data directory.
		*/
		string GetDataDirectory()
		{
			return Fuse.Storage.ApplicationDir.GetRootDirectory();
		}

		/**
			@scriptproperty cacheDirectory

			The directory used for regenerable cache files.

			Files in this directory may be removed by the operating system when space is low.
		*/
		string GetCacheDirectory()
		{
			return Fuse.Storage.ApplicationDir.GetCacheRootDirectory();
		}

		/**
			@scriptmethod write(filename, contents)
			@param filename (String) The file to write to
			@param contents (String) The contents to write to the file
			@return (Promise) A promise of a boolean, which will be `true` if the write succeeded.

			Asynchronously writes to a file.

			```js
				var Storage = require("FuseJS/Storage");

				Storage.write("myfile.txt", "Hello from Fuse!")
					.then(function(succeeded) {
						if(succeeded) {
							console.log("Successfully wrote to file");
						}
						else {
							console.log("Couldn't write to file.");
						}
					});
			```
		*/
		static Future<bool> WriteAsync(Context c, object[] args)
		{
			var filename = GetStringArg(args, 0, "filename");
			var value = GetStringArg(args, 1, "contents");
			return Fuse.Storage.ApplicationDir.WriteAsync(filename, value);
		}

		/**
			@scriptmethod read(filename)
			@param filename (String) The file to read
			@return (Promise) A promise of the file's contents.

			Asynchronously reads a file and returns a promise of its contents.

			```js
				var Storage = require("FuseJS/Storage");

				Storage.read("myfile.txt")
					.then(function(contents) {
						console.log(contents);
					}, function(error) {
						console.log(error);
					});
			```
			
		*/
		static Future<string> ReadAsync(Context c, object[] args)
		{
			var filename = GetStringArg(args, 0, "filename");
			return Fuse.Storage.ApplicationDir.ReadAsync(filename);
		}

		/**
			@scriptmethod remove(filename)
			@param filename (String) The file to delete
			@return (Promise) A promise of a boolean, which will be `true` if the file was deleted.

			Asynchronously deletes a file inside the application folder.

			```js
				var Storage = require("FuseJS/Storage");

				Storage.remove("uselessFile.txt")
					.then(function(success) {
						if(success) {
							console.log("Deleted file");
						}
						else {
							console.log("Couldn't delete file");
						}
					});
			```
		*/
		static Future<bool> RemoveAsync(Context c, object[] args)
		{
			var filename = GetStringArg(args, 0, "filename");
			return Fuse.Storage.ApplicationDir.DeleteAsync(filename);
		}

		/**
			@scriptmethod removeSync(filename)
			@param filename (String) The file to delete
			@return (boolean) `true` if the file was deleted, `false` otherwise.

			Synchrounously deletes a file inside the application folder.

			```js
				var Storage = require("FuseJS/Storage");

				var success = Storage.removeSync("uselessFile.txt");
				if(success) {
					console.log("Deleted file");
				}
				else {
					console.log("An error occured!");
				}
			```

			> Warning: This call will block until the operation is finished.
		*/
		static object Remove(Context c, object[] args)
		{
			var filename = GetStringArg(args, 0, "filename");
			return Fuse.Storage.ApplicationDir.Delete(filename);
		}

		/**
			@scriptmethod exists(filename)
			@param filename (String) The file or directory to check
			@return (Promise) A promise of a boolean, which will be `true` if the file or directory exists.

			Asynchronously checks if a file or directory exists inside the application folder.

			```js
				var Storage = require("FuseJS/Storage");

				Storage.exists("myfile.txt")
					.then(function(exists) {
						console.log("File exists: " + exists);
					});
			```
		*/
		static Future<bool> ExistsAsync(Context c, object[] args)
		{
			var filename = GetStringArg(args, 0, "filename");
			return Fuse.Storage.ApplicationDir.ExistsAsync(filename);
		}

		/**
			@scriptmethod existsSync(filename)
			@param filename (String) The file or directory to check
			@return (boolean) `true` if the file or directory exists, `false` otherwise.

			Synchrounously checks if a file or directory exists inside the application folder.

			```js
				var Storage = require("FuseJS/Storage");

				if(Storage.existsSync("myfile.txt")) {
					console.log("File exists");
				}
			```

			> Warning: This call will block until the operation is finished.
		*/
		static object Exists(Context c, object[] args)
		{
			var filename = GetStringArg(args, 0, "filename");
			return Fuse.Storage.ApplicationDir.Exists(filename);
		}

		/**
			@scriptmethod append(filename, contents)
			@param filename (String) The file to append to
			@param contents (String) The contents to append to the file
			@return (Promise) A promise of a boolean, which will be `true` if the append succeeded.

			Asynchronously appends to a file. The file is created if it does not exist.

			```js
				var Storage = require("FuseJS/Storage");

				Storage.append("myfile.txt", "Hello from Fuse!")
					.then(function(succeeded) {
						console.log("Appended: " + succeeded);
					});
			```
		*/
		static Future<bool> AppendAsync(Context c, object[] args)
		{
			var filename = GetStringArg(args, 0, "filename");
			var value = GetStringArg(args, 1, "contents");
			return Fuse.Storage.ApplicationDir.AppendAsync(filename, value);
		}

		/**
			@scriptmethod appendSync(filename, contents)
			@param filename (String) The file to append to
			@param contents (String) The contents to append to the file
			@return (boolean) `true` if the append succeeded, `false` otherwise

			Synchrounously appends to a file. The file is created if it does not exist.

			```js
				var Storage = require("FuseJS/Storage");

				var success = Storage.appendSync("myfile.txt", "Hello from Fuse!");
			```

			> Warning: This call will block until the operation is finished.
		*/
		static object Append(Context c, object[] args)
		{
			var filename = GetStringArg(args, 0, "filename");
			var value = GetStringArg(args, 1, "contents");
			return Fuse.Storage.ApplicationDir.Append(filename, value);
		}

		/**
			@scriptmethod list(directory)
			@param directory (String) Optional directory to list, relative to the application folder
			@return (Promise) A promise of an array of file and directory names.

			Asynchronously lists the entries in the application folder.
			If `directory` is omitted the root of the application folder is listed.

			```js
				var Storage = require("FuseJS/Storage");

				Storage.list()
					.then(function(entries) {
						console.log("Entries: " + entries.join(", "));
					});
			```
		*/
		static Future<string[]> List(Context c, object[] args)
		{
			var directory = GetOptionalStringArg(args, 0);
			return Fuse.Storage.ApplicationDir.ListAsync(directory);
		}

		/**
			@scriptmethod listSync(directory)
			@param directory (String) Optional directory to list, relative to the application folder
			@return (Array) An array of file and directory names.

			Synchrounously lists the entries in the application folder.
			If `directory` is omitted the root of the application folder is listed.

			```js
				var Storage = require("FuseJS/Storage");

				var entries = Storage.listSync();
			```

			> Warning: This call will block until the operation is finished.
		*/
		static object ListSync(Context c, object[] args)
		{
			var directory = GetOptionalStringArg(args, 0);
			return ToScriptingArray(c, Fuse.Storage.ApplicationDir.List(directory));
		}

		/**
			@scriptmethod createDirectory(directory)
			@param directory (String) The directory to create, relative to the application folder
			@return (Promise) A promise of a boolean, which will be `true` if the directory was created.

			Asynchronously creates a directory, including any missing parent directories.

			```js
				var Storage = require("FuseJS/Storage");

				Storage.createDirectory("cache")
					.then(function(succeeded) {
						return Storage.write("cache/data.txt", "Hello");
					});
			```
		*/
		static Future<bool> CreateDirectory(Context c, object[] args)
		{
			var directory = GetStringArg(args, 0, "directory");
			return Fuse.Storage.ApplicationDir.CreateDirectoryAsync(directory);
		}

		/**
			@scriptmethod createDirectorySync(directory)
			@param directory (String) The directory to create, relative to the application folder
			@return (boolean) `true` if the directory was created, `false` otherwise

			Synchrounously creates a directory, including any missing parent directories.

			```js
				var Storage = require("FuseJS/Storage");

				var success = Storage.createDirectorySync("cache");
			```

			> Warning: This call will block until the operation is finished.
		*/
		static object CreateDirectorySync(Context c, object[] args)
		{
			var directory = GetStringArg(args, 0, "directory");
			return Fuse.Storage.ApplicationDir.CreateDirectory(directory);
		}

		/**
			@scriptmethod readBuffer(filename)
			@param filename (String) The file to read
			@return (Promise) A promise of the file's contents as an ArrayBuffer.

			Asynchronously reads a file and returns a promise of an ArrayBuffer with its contents.

			```js
				var Storage = require("FuseJS/Storage");

				Storage.readBuffer("image.png")
					.then(function(buffer) {
						console.log("Read " + buffer.byteLength + " bytes");
					});
			```
		*/
		static Future<byte[]> ReadBuffer(Context c, object[] args)
		{
			var filename = GetStringArg(args, 0, "filename");
			return Fuse.Storage.ApplicationDir.ReadBufferAsync(filename);
		}

		/**
			@scriptmethod readBufferSync(filename)
			@param filename (String) The file to read
			@return (ArrayBuffer) The file's contents as an ArrayBuffer.

			Synchrounously reads a file and returns an ArrayBuffer with its contents.

			```js
				var Storage = require("FuseJS/Storage");

				var buffer = Storage.readBufferSync("image.png");
			```

			> Warning: This call will block until the operation is finished.
		*/
		static object ReadBufferSync(Context c, object[] args)
		{
			var filename = GetStringArg(args, 0, "filename");
			return Fuse.Storage.ApplicationDir.ReadBuffer(filename);
		}

		/**
			@scriptmethod writeBuffer(filename, data)
			@param filename (String) The file to write to
			@param data (ArrayBuffer) The data to write to the file
			@return (Promise) A promise of a boolean, which will be `true` if the write succeeded.

			Asynchronously writes an ArrayBuffer to a file.

			```js
				var Storage = require("FuseJS/Storage");

				var data = new ArrayBuffer(4);
				new Int32Array(data)[0] = 0x1337;

				Storage.writeBuffer("data.bin", data)
					.then(function(succeeded) {
						console.log("Wrote: " + succeeded);
					});
			```
		*/
		static Future<bool> WriteBuffer(Context c, object[] args)
		{
			var filename = GetStringArg(args, 0, "filename");
			var data = GetBufferArg(args, 1, "data");
			return Fuse.Storage.ApplicationDir.WriteBufferAsync(filename, data);
		}

		/**
			@scriptmethod writeBufferSync(filename, data)
			@param filename (String) The file to write to
			@param data (ArrayBuffer) The data to write to the file
			@return (boolean) `true` if the write was successful, `false` otherwise

			Synchrounously writes an ArrayBuffer to a file.

			```js
				var Storage = require("FuseJS/Storage");

				var data = new ArrayBuffer(4);
				new Int32Array(data)[0] = 0x1337;

				Storage.writeBufferSync("data.bin", data);
			```

			> Warning: This call will block until the operation is finished.
		*/
		static object WriteBufferSync(Context c, object[] args)
		{
			var filename = GetStringArg(args, 0, "filename");
			var data = GetBufferArg(args, 1, "data");
			return Fuse.Storage.ApplicationDir.WriteBuffer(filename, data);
		}

		/**
			@scriptmethod getFileInfo(filename)
			@param filename (String) The file or directory to inspect
			@return (Promise) A promise of an object with `name`, `size`, `lastModified`, `isDirectory` and `exists` properties.

			Asynchronously gets information about a file or directory inside the application folder.
			`size` and `lastModified` are only present when the entry exists.

			```js
				var Storage = require("FuseJS/Storage");

				Storage.getFileInfo("myfile.txt")
					.then(function(info) {
						console.log(info.name + " is " + info.size + " bytes");
						console.log(info.lastModified);
					});
			```
		*/
		static Future<FileSystemInfo> GetFileInfo(Context c, object[] args)
		{
			var filename = GetStringArg(args, 0, "filename");
			return Fuse.Storage.ApplicationDir.GetFileInfoAsync(filename);
		}

		/**
			@scriptmethod getFileInfoSync(filename)
			@param filename (String) The file or directory to inspect
			@return (Object) An object with `name`, `size`, `lastModified`, `isDirectory` and `exists` properties.

			Synchrounously gets information about a file or directory inside the application folder.
			`size` and `lastModified` are only present when the entry exists.

			```js
				var Storage = require("FuseJS/Storage");

				var info = Storage.getFileInfoSync("myfile.txt");
				console.log(info.name + " is " + info.size + " bytes");
			```

			> Warning: This call will block until the operation is finished.
		*/
		static object GetFileInfoSync(Context c, object[] args)
		{
			var filename = GetStringArg(args, 0, "filename");
			return ToScriptingObject(c, Fuse.Storage.ApplicationDir.GetFileInfo(filename));
		}

		/**
			@scriptmethod copy(source, destination)
			@param source (String) The file or directory to copy
			@param destination (String) The destination path
			@return (Promise) A promise of a boolean, which will be `true` if the copy succeeded.

			Asynchronously copies a file or directory inside the application folder.
			The destination must not already exist.

			```js
				var Storage = require("FuseJS/Storage");

				Storage.copy("myfile.txt", "myfile.backup.txt")
					.then(function(succeeded) {
						console.log("Copied: " + succeeded);
					});
			```
		*/
		static Future<bool> Copy(Context c, object[] args)
		{
			var source = GetStringArg(args, 0, "source");
			var destination = GetStringArg(args, 1, "destination");
			return Fuse.Storage.ApplicationDir.CopyAsync(source, destination);
		}

		/**
			@scriptmethod copySync(source, destination)
			@param source (String) The file or directory to copy
			@param destination (String) The destination path
			@return (boolean) `true` if the copy succeeded, `false` otherwise

			Synchrounously copies a file or directory inside the application folder.
			The destination must not already exist.

			```js
				var Storage = require("FuseJS/Storage");

				Storage.copySync("myfile.txt", "myfile.backup.txt");
			```

			> Warning: This call will block until the operation is finished.
		*/
		static object CopySync(Context c, object[] args)
		{
			var source = GetStringArg(args, 0, "source");
			var destination = GetStringArg(args, 1, "destination");
			return Fuse.Storage.ApplicationDir.Copy(source, destination);
		}

		/**
			@scriptmethod move(source, destination)
			@param source (String) The file or directory to move
			@param destination (String) The destination path
			@return (Promise) A promise of a boolean, which will be `true` if the move succeeded.

			Asynchronously moves a file or directory inside the application folder.
			The destination must not already exist.

			```js
				var Storage = require("FuseJS/Storage");

				Storage.move("myfile.txt", "archive/myfile.txt")
					.then(function(succeeded) {
						console.log("Moved: " + succeeded);
					});
			```
		*/
		static Future<bool> Move(Context c, object[] args)
		{
			var source = GetStringArg(args, 0, "source");
			var destination = GetStringArg(args, 1, "destination");
			return Fuse.Storage.ApplicationDir.MoveAsync(source, destination);
		}

		/**
			@scriptmethod moveSync(source, destination)
			@param source (String) The file or directory to move
			@param destination (String) The destination path
			@return (boolean) `true` if the move succeeded, `false` otherwise

			Synchrounously moves a file or directory inside the application folder.
			The destination must not already exist.

			```js
				var Storage = require("FuseJS/Storage");

				Storage.moveSync("myfile.txt", "archive/myfile.txt");
			```

			> Warning: This call will block until the operation is finished.
		*/
		static object MoveSync(Context c, object[] args)
		{
			var source = GetStringArg(args, 0, "source");
			var destination = GetStringArg(args, 1, "destination");
			return Fuse.Storage.ApplicationDir.Move(source, destination);
		}

		/**
			@scriptmethod writeSync(filename, contents)
			@param filename (String) The file to write to
			@return (boolean) `true` if the write was successful, `false` otherwise

			Synchrounously writes data to a file inside the application folder.

			```js
				var Storage = require("FuseJS/Storage");

				var success = Storage.writeSync("myfile.txt", "Hello from Fuse!");
				if(success) {
					console.log("Successfully wrote to file");
				}
				else {
					console.log("An error occured!");
				}
			```

			> Warning: This call will block until the operation is finished. Use write() if you are writing large amounts of data.
		*/
		static object Write(Context c, object[] args)
		{
			var filename = GetStringArg(args, 0, "filename");
			var value = GetStringArg(args, 1, "contents");
			return Fuse.Storage.ApplicationDir.Write(filename, value);
		}

		/**
			@scriptmethod readSync(filename)
			@param filename (String) The file to read from
			@return (String) The contents of the file

			Synchrounously reads data from a file inside the application folder.

			```js
				var Storage = require("FuseJS/Storage");

				var contents = Storage.readSync("myfile.txt");
				console.log(contents);
			```
			
			> Warning: This call will block until the operation is finished. Use read() if you are reading large amounts of data.
		*/
		static object Read(Context c, object[] args)
		{
			var filename = GetStringArg(args, 0, "filename");

			string content;
			if (Fuse.Storage.ApplicationDir.TryRead(filename, out content))
				return content;
			else
				return string.Empty; // HACK!!
		}
	}
}
