using Uno;
using Uno.Collections;
using Uno.Compiler.ExportTargetInterop;
using Fuse.Scripting;
namespace Fuse.ImageTools
{
	public sealed class Image
	{
		public string Path { get; private set; }
		public string Name { get; private set; }
		int2 _dims;
		Dictionary<string, object> _info;
		bool _infoLoaded;

		public int Width {
			get{
				CheckDims();
				return _dims.X;
			}
		}

		public int Height {
			get{
				CheckDims();
				return _dims.Y;
			}
		}

		extern(Android) void CheckDims()
		{
			if(_dims.X == 0 && _dims.Y == 0)
				_dims = AndroidImageUtils.GetSize(this);
		}

		extern(iOS) void CheckDims()
		{
			if(_dims.X == 0 && _dims.Y == 0)
				_dims = iOSImageUtils.GetSize(this);
		}

		/** The MIME type of the image file, or an empty string if it could not be determined. */
		public string MimeType
		{
			get { EnsureInfo(); return (string)_info["mimeType"]; }
		}

		/** The size of the image file in bytes. */
		public long FileSize
		{
			get { EnsureInfo(); return (long)(double)_info["fileSize"]; }
		}

		/** The EXIF orientation of the image (1-8), or 0 if unknown. */
		public int Orientation
		{
			get { EnsureInfo(); return (int)_info["orientation"]; }
		}

		/** Whether the image format may contain an alpha channel. */
		public bool HasAlpha
		{
			get { EnsureInfo(); return (bool)_info["hasAlpha"]; }
		}

		public bool Rename(string newName, bool overwrite = false)
		{
			if(newName == Name) return true;
			var newPath = Uno.IO.Path.Combine(Uno.IO.Path.GetDirectoryName(Path), newName);
			if(!overwrite && Uno.IO.File.Exists(newPath)) return false;
			Uno.IO.File.Move(Path,newPath);
			Path = newPath;
			Name = newName;
			return true;
		}

		extern(DOTNET) void CheckDims()
		{
			if(_dims.X == 0 && _dims.Y == 0)
			{
				try
				{
					_dims = DotNetImageUtils.GetSize(Path);
				}
				catch(Exception)
				{
					_dims = int2(0);
				}
			}
		}

		extern(!Mobile && !DOTNET) void CheckDims() { }

		void EnsureInfo()
		{
			if (_infoLoaded) return;
			_infoLoaded = true;
			ReadInfo();
		}

		extern(Android) void ReadInfo()
		{
			_info["mimeType"] = AndroidImageUtils.GetMimeType(Path);
			_info["fileSize"] = (double)AndroidImageUtils.GetFileSize(Path);
			_info["orientation"] = AndroidImageUtils.GetOrientation(Path);
			_info["hasAlpha"] = AndroidImageUtils.HasAlpha(Path);
			int frameCount = AndroidImageUtils.GetFrameCount(Path);
			_info["frameCount"] = frameCount;
			_info["isAnimated"] = frameCount > 1;
			_info["exif"] = ParseExif(AndroidImageUtils.GetExif(Path));
		}

		extern(iOS) void ReadInfo()
		{
			_info["mimeType"] = iOSImageUtils.GetMimeType(Path);
			_info["fileSize"] = (double)iOSImageUtils.GetFileSize(Path);
			_info["orientation"] = iOSImageUtils.GetOrientation(Path);
			_info["hasAlpha"] = iOSImageUtils.HasAlpha(Path);
			int frameCount = iOSImageUtils.GetFrameCount(Path);
			_info["frameCount"] = frameCount;
			_info["isAnimated"] = frameCount > 1;
			_info["exif"] = ParseExif(iOSImageUtils.GetExif(Path));
		}

		extern(!Mobile && !DOTNET) void ReadInfo()
		{
			var mime = MimeTypeFromExtension(Path);
			long size = 0;
			if (Uno.IO.File.Exists(Path))
				size = new Uno.IO.FileInfo(Path).Length;

			_info["mimeType"] = mime;
			_info["fileSize"] = (double)size;
			_info["orientation"] = 0;
			_info["hasAlpha"] = mime == "image/png" || mime == "image/gif" || mime == "image/webp";
			_info["frameCount"] = 1;
			_info["isAnimated"] = false;
			_info["exif"] = new Dictionary<string, object>();
		}

		extern(DOTNET) void ReadInfo()
		{
			var mime = MimeTypeFromExtension(Path);
			long size = 0;
			if (Uno.IO.File.Exists(Path))
				size = new Uno.IO.FileInfo(Path).Length;

			int orientation = 0;
			bool hasAlpha = false;
			try
			{
				orientation = DotNetImageUtils.GetOrientation(Path);
				hasAlpha = DotNetImageUtils.HasAlpha(Path);
			}
			catch(Exception)
			{
			}

			_info["mimeType"] = mime;
			_info["fileSize"] = (double)size;
			_info["orientation"] = orientation;
			_info["hasAlpha"] = hasAlpha;
			int frameCount = DotNetImageUtils.GetFrameCount(Path);
			_info["frameCount"] = frameCount;
			_info["isAnimated"] = frameCount > 1;
			_info["exif"] = ParseExif(DotNetImageUtils.GetExif(Path));
		}

		static string MimeTypeFromExtension(string path)
		{
			var dot = path.LastIndexOf('.');
			var ext = dot >= 0 ? path.Substring(dot).ToLower() : "";

			if (ext == ".jpg" || ext == ".jpeg")
				return "image/jpeg";
			if (ext == ".png")
				return "image/png";
			if (ext == ".gif")
				return "image/gif";
			if (ext == ".webp")
				return "image/webp";
			if (ext == ".bmp")
				return "image/bmp";
			if (ext == ".tif" || ext == ".tiff")
				return "image/tiff";
			if (ext == ".heic" || ext == ".heif")
				return "image/heic";

			return "";
		}

		static Dictionary<string, object> ParseExif(string data)
		{
			var result = new Dictionary<string, object>();
			if (string.IsNullOrEmpty(data))
				return result;

			foreach (var line in data.Split('\n'))
			{
				if (line.Length == 0)
					continue;

				var tab = line.IndexOf('\t');
				if (tab <= 0)
					continue;

				result[line.Substring(0, tab)] = line.Substring(tab + 1);
			}

			return result;
		}

		static object ToScriptable(Context c, object value)
		{
			var dict = value as Dictionary<string, object>;
			if (dict == null)
				return value;

			var result = c.NewObject();
			foreach (var key in dict.Keys)
				result[key] = ToScriptable(c, dict[key]);

			return result;
		}

		/** Metadata about the image. The contents are populated lazily. */
		public Dictionary<string, object> Info
		{
			get
			{
				EnsureInfo();
				return _info;
			}
		}

		public Image() : this("No path") {}

		public Image(string path)
		{
			Path = path;
			Name = Uno.IO.Path.GetFileName(Path);
			_info = new Dictionary<string, object>();
		}

		public static Image FromObject(object o)
		{
			return FromObject((Scripting.Object)o);
		}

		public static Image FromObject(Scripting.Object o)
		{
			if (o == null)
				return null;

			var path = o["path"] as string;
			if (path == null)
				return null;

			return new Image(path);
		}

		Scripting.Object InfoToObject(Context c)
		{
			EnsureInfo();
			var outValue = c.NewObject();
			foreach(var key in _info.Keys)
			{
				outValue[key] = ToScriptable(c, _info[key]);
			}
			return outValue;
		}

		/** Returns the image metadata as a plain JavaScript object, including path and dimensions. */
		public Scripting.Object ToInfoObject(Context c)
		{
			var outValue = InfoToObject(c);
			outValue["path"] = Path;
			outValue["name"] = Name;
			outValue["width"] = Width;
			outValue["height"] = Height;
			return outValue;
		}

		public Scripting.Object ToObject(Scripting.Context c)
		{

			var outValue = c.NewObject();

			outValue["path"] = Path;
			outValue["name"] = Uno.IO.Path.GetFileName(Path);
			outValue["width"] = Width;
			outValue["height"] = Height;
			outValue["info"] = InfoToObject(c);

			outValue.Freeze(c);

			return outValue;
		}

		public static Scripting.Object Converter(Context context, Image result)
		{
			return result.ToObject(context);
		}

		public static Scripting.Object InfoConverter(Context context, Image result)
		{
			return result.ToInfoObject(context);
		}
	}
}
