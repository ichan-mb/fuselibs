using Uno;
using Uno.IO;
using Uno.Threading;

namespace Fuse.Storage
{
	internal static class ApplicationDir
	{
		static string _rootDirectory;
		static readonly object _rootMutex = new object();
		static string _cacheRootDirectory;
		static readonly object _cacheRootMutex = new object();
		static int _atomicWriteCounter;
		static readonly object _atomicWriteMutex = new object();

		/**
			Returns the directory used for application-private storage.

			On mobile the platform already sandboxes every application, so the
			user data directory can be used directly. On desktop all applications
			share the same user data directory, so files are placed in a
			project-specific subdirectory.
		*/
		public static string GetRootDirectory()
		{
			lock (_rootMutex)
			{
				if (_rootDirectory != null)
					return _rootDirectory;

				var dataDirectory = Directory.GetUserDirectory(UserDirectory.Data);

				if defined(MOBILE)
					_rootDirectory = dataDirectory;
				else
					_rootDirectory = Path.Combine(dataDirectory, @(project.name));

				if (!Directory.Exists(_rootDirectory))
					Directory.CreateDirectory(_rootDirectory);

				return _rootDirectory;
			}
		}

		/**
			Returns the directory used for regenerable application cache files.
		*/
		public static string GetCacheRootDirectory()
		{
			lock (_cacheRootMutex)
			{
				if (_cacheRootDirectory != null)
					return _cacheRootDirectory;

				var cacheDirectory = Directory.GetUserDirectory(UserDirectory.Cache);

				if defined(MOBILE)
					_cacheRootDirectory = cacheDirectory;
				else
					_cacheRootDirectory = Path.Combine(cacheDirectory, @(project.name));

				if (!Directory.Exists(_cacheRootDirectory))
					Directory.CreateDirectory(_cacheRootDirectory);

				return _cacheRootDirectory;
			}
		}

		/**
			Validates a path and combines it with the application storage root.

			Only relative paths that stay inside the storage directory are allowed.
		*/
		static string GetPath(string path)
		{
			ValidateRelativePath(path);
			return Path.Combine(GetRootDirectory(), path);
		}

		static string GetDirectoryPath(string path)
		{
			if (path == null || path.Length == 0)
				return GetRootDirectory();

			return GetPath(path);
		}

		static void ValidateRelativePath(string path)
		{
			if (path == null)
				throw new ArgumentNullException(nameof(path));

			if (path.Length == 0)
				throw new ArgumentException("Path must not be empty.", nameof(path));

			if (path.IndexOf('\0') >= 0)
				throw new ArgumentException("Path must not contain null characters.", nameof(path));

			if (Path.IsPathRooted(path))
				throw new ArgumentException("Path must be relative to the application storage directory.", nameof(path));

			var hasEntry = false;
			var start = 0;

			for (int i = 0; i <= path.Length; i++)
			{
				if (i < path.Length && path[i] != '/' && path[i] != '\\')
					continue;

				var length = i - start;
				if (length > 0)
				{
					if (length == 2 && path[start] == '.' && path[start + 1] == '.')
						throw new ArgumentException("Path must not contain '..'.", nameof(path));

					if (length != 1 || path[start] != '.')
						hasEntry = true;
				}

				start = i + 1;
			}

			if (!hasEntry)
				throw new ArgumentException("Path must refer to a file or directory.", nameof(path));
		}

		public static bool Write(string filename, string value)
		{
			if (value == null)
				throw new ArgumentNullException(nameof(value));

			var filepath = GetPath(filename);
			WriteTextAtomic(filepath, value);

			return true;
		}

		static void WriteTextAtomic(string filepath, string value)
		{
			var tempPath = GetTempWritePath(filepath);
			try
			{
				File.WriteAllText(tempPath, value);
				ReplaceFile(tempPath, filepath);
			}
			finally
			{
				if (File.Exists(tempPath))
					File.Delete(tempPath);
			}
		}

		static void WriteBytesAtomic(string filepath, byte[] value)
		{
			var tempPath = GetTempWritePath(filepath);
			try
			{
				File.WriteAllBytes(tempPath, value);
				ReplaceFile(tempPath, filepath);
			}
			finally
			{
				if (File.Exists(tempPath))
					File.Delete(tempPath);
			}
		}

		static string GetTempWritePath(string filepath)
		{
			lock (_atomicWriteMutex)
			{
				return filepath + ".tmp-" + (++_atomicWriteCounter);
			}
		}

		static void ReplaceFile(string source, string destination)
		{
			if defined(DOTNET)
			{
				if (File.Exists(destination))
					File.Delete(destination);

				File.Move(source, destination);
			}
			else if defined(WIN32)
			{
				if (File.Exists(destination))
					File.Delete(destination);

				File.Move(source, destination);
			}
			else
			{
				// POSIX rename replaces the destination atomically.
				File.Move(source, destination);
			}
		}

		public static bool Append(string filename, string value)
		{
			if (value == null)
				throw new ArgumentNullException(nameof(value));

			var filepath = GetPath(filename);
			File.AppendAllText(filepath, value);

			return true;
		}

		public static bool TryRead(string filename, out string content)
		{
			var filepath = GetPath(filename);
			if (!File.Exists(filepath))
			{
				content = string.Empty;
				return false;
			}

			content = File.ReadAllText(filepath);
			return true;
		}

		public static string Read(string filename)
		{
			string content;
			if (TryRead(filename, out content))
				return content;
			else
				throw new Exception("File does not exist.");
		}

		public static bool Exists(string filename)
		{
			var filepath = GetPath(filename);
			return File.Exists(filepath) || Directory.Exists(filepath);
		}

		public static bool Delete(string filename)
		{
			var filepath = GetPath(filename);
			if(!File.Exists(filepath)) return false;

			try
			{
				File.Delete(filepath);
				return true;
			} catch(Exception e) {}
			return false;
		}

		public static string[] List(string path)
		{
			var dirpath = GetDirectoryPath(path);
			if (!Directory.Exists(dirpath))
				throw new Exception("Directory does not exist.");

			var result = new Uno.Collections.List<string>();
			foreach (var entry in Directory.EnumerateFileSystemEntries(dirpath))
				result.Add(Path.GetFileName(entry));

			return result.ToArray();
		}

		public static bool CreateDirectory(string path)
		{
			var dirpath = GetPath(path);
			if (!Directory.Exists(dirpath))
				Directory.CreateDirectory(dirpath);

			return true;
		}

		public static byte[] ReadBuffer(string filename)
		{
			var filepath = GetPath(filename);
			return File.ReadAllBytes(filepath);
		}

		public static bool WriteBuffer(string filename, byte[] value)
		{
			if (value == null)
				throw new ArgumentNullException(nameof(value));

			var filepath = GetPath(filename);
			WriteBytesAtomic(filepath, value);

			return true;
		}

		public static FileSystemInfo GetFileInfo(string filename)
		{
			var filepath = GetPath(filename);
			if (Directory.Exists(filepath))
				return new DirectoryInfo(filepath);

			return new FileInfo(filepath);
		}

		public static bool Copy(string source, string destination)
		{
			var sourcePath = GetPath(source);
			var destinationPath = GetPath(destination);

			if (Directory.Exists(sourcePath))
			{
				var normalizedSource = NormalizeRelativePath(source);
				var normalizedDestination = NormalizeRelativePath(destination);
				if (normalizedDestination == normalizedSource
						|| normalizedDestination.StartsWith(normalizedSource + "/"))
					throw new Exception("Destination cannot be inside the source directory.");

				if (File.Exists(destinationPath) || Directory.Exists(destinationPath))
					throw new Exception("Destination already exists.");

				CopyDirectory(sourcePath, destinationPath);
			}
			else
			{
				File.Copy(sourcePath, destinationPath);
			}

			return true;
		}

		static string NormalizeRelativePath(string path)
		{
			return path.Replace('\\', '/').Trim('/');
		}

		static void CopyDirectory(string source, string destination)
		{
			if (!Directory.Exists(destination))
				Directory.CreateDirectory(destination);

			foreach (var entry in Directory.EnumerateFileSystemEntries(source))
			{
				var target = Path.Combine(destination, Path.GetFileName(entry));
				if (Directory.Exists(entry))
					CopyDirectory(entry, target);
				else
					File.Copy(entry, target);
			}
		}

		public static bool Move(string source, string destination)
		{
			var sourcePath = GetPath(source);
			var destinationPath = GetPath(destination);

			if (Directory.Exists(sourcePath))
				Directory.Move(sourcePath, destinationPath);
			else
				File.Move(sourcePath, destinationPath);

			return true;
		}

		public static Future<bool> WriteAsync(string filename, string value)
		{
			return Promise<bool>.Run(new WriteClosure(filename, value).Invoke);
		}

		public static Future<bool> WriteAsync(IDispatcher dispatcher, string filename, string value)
		{
			return Promise<bool>.Run(dispatcher, new WriteClosure(filename, value).Invoke);
		}

		public static Future<bool> AppendAsync(string filename, string value)
		{
			return Promise<bool>.Run(new AppendClosure(filename, value).Invoke);
		}

		public static Future<string> ReadAsync(string filename)
		{
			return Promise<string>.Run(new ReadClosure(filename).Invoke);
		}

		public static Future<string> ReadAsync(IDispatcher dispatcher, string filename)
		{
			return Promise<string>.Run(dispatcher, new ReadClosure(filename).Invoke);
		}

		public static Future<bool> ExistsAsync(string filename)
		{
			return Promise<bool>.Run(new ExistsClosure(filename).Invoke);
		}

		public static Future<bool> DeleteAsync(string filename)
		{
			return Promise<bool>.Run(new DeleteClosure(filename).Invoke);
		}

		public static Future<string[]> ListAsync(string path)
		{
			return Promise<string[]>.Run(new ListClosure(path).Invoke);
		}

		public static Future<bool> CreateDirectoryAsync(string path)
		{
			return Promise<bool>.Run(new CreateDirectoryClosure(path).Invoke);
		}

		public static Future<byte[]> ReadBufferAsync(string filename)
		{
			return Promise<byte[]>.Run(new ReadBufferClosure(filename).Invoke);
		}

		public static Future<bool> WriteBufferAsync(string filename, byte[] value)
		{
			return Promise<bool>.Run(new WriteBufferClosure(filename, value).Invoke);
		}

		public static Future<FileSystemInfo> GetFileInfoAsync(string filename)
		{
			return Promise<FileSystemInfo>.Run(new GetFileInfoClosure(filename).Invoke);
		}

		public static Future<bool> CopyAsync(string source, string destination)
		{
			return Promise<bool>.Run(new CopyClosure(source, destination).Invoke);
		}

		public static Future<bool> MoveAsync(string source, string destination)
		{
			return Promise<bool>.Run(new MoveClosure(source, destination).Invoke);
		}

		class WriteClosure
		{
			readonly string _filename;
			readonly string _value;

			public WriteClosure(string filename, string value)
			{
				_filename = filename;
				_value = value;
			}

			public bool Invoke()
			{
				return ApplicationDir.Write(_filename, _value);
			}
		}

		class AppendClosure
		{
			readonly string _filename;
			readonly string _value;

			public AppendClosure(string filename, string value)
			{
				_filename = filename;
				_value = value;
			}

			public bool Invoke()
			{
				return ApplicationDir.Append(_filename, _value);
			}
		}

		class ReadClosure
		{
			readonly string _filename;

			public ReadClosure(string filename)
			{
				_filename = filename;
			}

			public string Invoke()
			{
				return ApplicationDir.Read(_filename);
			}
		}

		class ExistsClosure
		{
			readonly string _filename;

			public ExistsClosure(string filename)
			{
				_filename = filename;
			}

			public bool Invoke()
			{
				return ApplicationDir.Exists(_filename);
			}
		}

		class DeleteClosure
		{
			readonly string _filename;

			public DeleteClosure(string filename)
			{
				_filename = filename;
			}

			public bool Invoke()
			{
				return ApplicationDir.Delete(_filename);
			}
		}

		class ListClosure
		{
			readonly string _path;

			public ListClosure(string path)
			{
				_path = path;
			}

			public string[] Invoke()
			{
				return ApplicationDir.List(_path);
			}
		}

		class CreateDirectoryClosure
		{
			readonly string _path;

			public CreateDirectoryClosure(string path)
			{
				_path = path;
			}

			public bool Invoke()
			{
				return ApplicationDir.CreateDirectory(_path);
			}
		}

		class ReadBufferClosure
		{
			readonly string _filename;

			public ReadBufferClosure(string filename)
			{
				_filename = filename;
			}

			public byte[] Invoke()
			{
				return ApplicationDir.ReadBuffer(_filename);
			}
		}

		class WriteBufferClosure
		{
			readonly string _filename;
			readonly byte[] _value;

			public WriteBufferClosure(string filename, byte[] value)
			{
				_filename = filename;
				_value = value;
			}

			public bool Invoke()
			{
				return ApplicationDir.WriteBuffer(_filename, _value);
			}
		}

		class GetFileInfoClosure
		{
			readonly string _filename;

			public GetFileInfoClosure(string filename)
			{
				_filename = filename;
			}

			public FileSystemInfo Invoke()
			{
				return ApplicationDir.GetFileInfo(_filename);
			}
		}

		class CopyClosure
		{
			readonly string _source;
			readonly string _destination;

			public CopyClosure(string source, string destination)
			{
				_source = source;
				_destination = destination;
			}

			public bool Invoke()
			{
				return ApplicationDir.Copy(_source, _destination);
			}
		}

		class MoveClosure
		{
			readonly string _source;
			readonly string _destination;

			public MoveClosure(string source, string destination)
			{
				_source = source;
				_destination = destination;
			}

			public bool Invoke()
			{
				return ApplicationDir.Move(_source, _destination);
			}
		}
	}
}
