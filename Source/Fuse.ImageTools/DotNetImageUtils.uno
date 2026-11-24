using Uno.Threading;
using Uno;
using Uno.IO;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.ImageTools
{
	using DotNetNative;

	extern (DOTNET) internal partial class DotNetImageUtils
	{
		public static void GetImageFromUri(string uri, Action<string> onSuccess, Action<string> onFail)
		{
			try
			{
				string path = uri;
				if (uri.StartsWith("file:"))
					path = new DotNetUri(uri).LocalPath;

				if (!Uno.IO.File.Exists(path))
					throw new Exception("File not found: " + path);

				onSuccess(path);
			}
			catch (Exception e)
			{
				onFail(e.Message);
			}
		}

		public static void GetImageFromBase64(string b64, Action<string> onSuccess, Action<string> onFail)
		{
			try
			{
				var asBytes = DotNetNative.Convert.FromBase64String(StripDataUri(b64));
				var stream = new MemoryStream(asBytes);
				DotNetImage outImage = DotNetImage.FromStream(stream);

				var extension = ExtensionFromData(asBytes);
				if (extension == "webp" || extension == "heic")
					extension = "jpg";

				var path = TemporaryPath(extension);
				outImage.Save(path, ImageFormatFor(extension));
				outImage.Dispose();
				onSuccess(path);
			}
			catch (Exception e)
			{
				onFail(e.Message);
			}
		}

		public static void GetBase64FromImage(string path, Action<string> onSuccess, Action<string> onFail)
		{
			GetBase64FromImage(path, null, 90, onSuccess, onFail);
		}

		public static void GetBase64FromImage(string path, string format, int quality, Action<string> onSuccess, Action<string> onFail)
		{
			try
			{
				bool orientationChanged;
				var image = LoadOrientedBitmap(path, out orientationChanged);
				try
				{
					using (MemoryStream ms = new MemoryStream())
					{
						var fmt = NormalizeFormat(format, path);
						SaveBitmap(image, ms, fmt, quality);
						var buffer = ms.GetBuffer();
						var length = (int)ms.Length;
						var bytes = new byte[length];
						for (int i = 0; i < length; i++)
							bytes[i] = buffer[i];
						onSuccess(DotNetNative.Convert.ToBase64String(bytes));
					}
				}
				finally
				{
					image.Dispose();
				}
			}
			catch (Exception e)
			{
				onFail(e.Message);
			}
		}

		public static int2 GetSize(string path)
		{
			var image = DotNetImage.FromFile(path);
			try
			{
				int orientation = GetOrientation(image);
				if (orientation >= 5 && orientation <= 8)
					return int2(image.Height, image.Width);

				return int2(image.Width, image.Height);
			}
			finally
			{
				image.Dispose();
			}
		}

		public static int GetOrientation(string path)
		{
			var image = DotNetImage.FromFile(path);
			try
			{
				return GetOrientation(image);
			}
			finally
			{
				image.Dispose();
			}
		}

		public static bool HasAlpha(string path)
		{
			var image = DotNetImage.FromFile(path);
			try
			{
				var format = (int)image.PixelFormat;
				return (format & (int)PixelFormat.Alpha) != 0 || (format & (int)PixelFormat.PAlpha) != 0;
			}
			finally
			{
				image.Dispose();
			}
		}

		public static void Save(string path, string directory, string name, string format, int quality, Action<string> onSuccess, Action<string> onFail)
		{
			try
			{
				bool orientationChanged;
				var source = LoadOrientedBitmap(path, out orientationChanged);
				try
				{
					var selectedFormat = format;
					if (selectedFormat == null || selectedFormat.Length == 0)
						selectedFormat = FormatFromName(name);

					var targetFormat = NormalizeFormat(selectedFormat, path);
					var target = SavePath(directory, name, ExtensionForFormat(targetFormat));

					SaveBitmap(source, target, targetFormat, quality);
					onSuccess(target);
				}
				finally
				{
					source.Dispose();
				}
			}
			catch (Exception e)
			{
				onFail(e.Message);
			}
		}

		public static int GetFrameCount(string path)
		{
			try
			{
				var image = DotNetImage.FromFile(path);
				try
				{
					return image.GetFrameCount(DotNetFrameDimension.Time);
				}
				finally
				{
					image.Dispose();
				}
			}
			catch (Exception)
			{
				return 1;
			}
		}

		public static string GetExif(string path)
		{
			try
			{
				var image = DotNetImage.FromFile(path);
				try
				{
					var result = "";
					var properties = image.PropertyItems;
					if (properties == null)
						return "";

					foreach (var property in properties)
					{
						int type = (int)property.Type;

						if (type == 2)
						{
							var text = Ascii(property.Value);
							if (property.Id == 0x010F)
								AppendExif(ref result, "make", text);
							else if (property.Id == 0x0110)
								AppendExif(ref result, "model", text);
							else if (property.Id == 0x0132)
								AppendExif(ref result, "dateTime", text);
						}
						else if (type == 3)
						{
							var number = property.Value.GetShort(0, true).ToString();
							if (property.Id == 0x8827)
								AppendExif(ref result, "iso", number);
							else if (property.Id == 0x9209)
								AppendExif(ref result, "flash", number);
						}
						else if (type == 5)
						{
							var number = Rational(property.Value);
							if (property.Id == 0x829A)
								AppendExif(ref result, "exposureTime", number);
							else if (property.Id == 0x829D)
								AppendExif(ref result, "fNumber", number);
							else if (property.Id == 0x920A)
								AppendExif(ref result, "focalLength", number);
						}
					}

					return result;
				}
				finally
				{
					image.Dispose();
				}
			}
			catch (Exception)
			{
				return "";
			}
		}

		public static void ClearCache()
		{
			try
			{
				var directory = DotNetNative.Path.GetTempPath();
				foreach (var file in Uno.IO.Directory.EnumerateFiles(directory))
				{
					if (Uno.IO.Path.GetFileName(file).StartsWith("IMG_"))
						Uno.IO.File.Delete(file);
				}
			}
			catch (Exception)
			{
			}
		}

		static void SaveResult(DotNetBitmap bitmap, string sourcePath, string format, int quality, bool inPlace, Action<string> onSuccess)
		{
			var targetFormat = NormalizeFormat(format, sourcePath);
			var target = TargetPath(sourcePath, targetFormat, inPlace);
			SaveBitmap(bitmap, target, targetFormat, quality);
			onSuccess(target);
		}

		static DotNetBitmap LoadBitmap(string path)
		{
			var image = DotNetImage.FromFile(path);
			try
			{
				return new DotNetBitmap(image);
			}
			finally
			{
				image.Dispose();
			}
		}

		static DotNetBitmap LoadOrientedBitmap(string path, out bool orientationChanged)
		{
			var source = LoadBitmap(path);
			int orientation = GetOrientation(source);
			orientationChanged = orientation > 1;

			if (!orientationChanged)
				return source;

			var oriented = new DotNetBitmap(source);
			oriented.RotateFlip(OrientationToRotateFlip(orientation));
			source.Dispose();
			return oriented;
		}

		static int GetOrientation(DotNetImage image)
		{
			try
			{
				var properties = image.PropertyItems;
				if (properties == null)
					return 1;

				foreach (var property in properties)
				{
					if (property.Id == 274)
						return property.Value.GetShort(0, true);
				}
			}
			catch (Exception)
			{
			}

			return 1;
		}

		static RotateFlipType OrientationToRotateFlip(int orientation)
		{
			switch (orientation)
			{
				case 2: return RotateFlipType.RotateNoneFlipX;
				case 3: return RotateFlipType.Rotate180FlipNone;
				case 4: return RotateFlipType.RotateNoneFlipY;
				case 5: return RotateFlipType.Rotate90FlipX;
				case 6: return RotateFlipType.Rotate90FlipNone;
				case 7: return RotateFlipType.Rotate270FlipX;
				case 8: return RotateFlipType.Rotate270FlipNone;
				default: return RotateFlipType.RotateNoneFlipNone;
			}
		}

		static DotNetBitmap Render(DotNetBitmap source, int width, int height)
		{
			var target = new DotNetBitmap(width, height);
			var graphics = DotNetGraphics.FromImage(target);
			try
			{
				graphics.InterpolationMode = DotNetInterpolationMode.HighQualityBicubic;
				graphics.DrawImage(source, new DotNetRectangleF(0, 0, width, height));
			}
			finally
			{
				graphics.Dispose();
			}
			return target;
		}

		static DotNetBitmap CropBitmap(DotNetBitmap source, int x, int y, int width, int height)
		{
			var target = new DotNetBitmap(width, height);
			var graphics = DotNetGraphics.FromImage(target);
			try
			{
				graphics.DrawImage(
					source,
					new DotNetRectangle(0, 0, width, height),
					new DotNetRectangle(x, y, width, height),
					DotNetGraphicsUnit.Pixel);
			}
			finally
			{
				graphics.Dispose();
			}
			return target;
		}

		static DotNetBitmap PadBitmap(DotNetBitmap source, int width, int height, int background)
		{
			var target = new DotNetBitmap(width, height);
			var graphics = DotNetGraphics.FromImage(target);
			try
			{
				graphics.InterpolationMode = DotNetInterpolationMode.HighQualityBicubic;
				graphics.Clear(DotNetColor.FromArgb(background));
				graphics.DrawImage(
					source,
					new DotNetRectangleF(
						(width - source.Width) / 2.0f,
						(height - source.Height) / 2.0f,
						source.Width,
						source.Height));
			}
			finally
			{
				graphics.Dispose();
			}
			return target;
		}

		static string FormatFromName(string name)
		{
			if (name == null)
				return null;

			int dot = name.LastIndexOf('.');
			if (dot < 0 || dot == name.Length - 1)
				return null;

			var extension = name.Substring(dot + 1).ToLower();
			if (extension == "jpeg")
				return "jpg";
			if (extension == "jpg" || extension == "png" || extension == "webp")
				return extension;

			return null;
		}

		static string ExtensionForFormat(string format)
		{
			if (format == "png")
				return "png";
			if (format == "webp")
				return "webp";
			return "jpg";
		}

		static string SavePath(string directory, string name, string extension)
		{
			var dir = directory == "temp"
				? DotNetNative.Path.GetTempPath()
				: Uno.IO.Path.Combine(
					Uno.IO.Directory.GetUserDirectory(Uno.IO.UserDirectory.Documents), "images");

			if (!Uno.IO.Directory.Exists(dir))
				Uno.IO.Directory.CreateDirectory(dir);

			string fileName;
			if (name != null && name.Length > 0)
			{
				int dot = name.LastIndexOf('.');
				var baseName = dot > 0 ? name.Substring(0, dot) : name;
				fileName = baseName + "." + extension;
			}
			else
			{
				var random = DotNetNative.Path.GetRandomFileName();
				int dot = random.LastIndexOf('.');
				if (dot >= 0)
					random = random.Substring(0, dot);
				fileName = "IMG_" + random + "." + extension;
			}

			var target = Uno.IO.Path.Combine(dir, fileName);
			if (!Uno.IO.File.Exists(target))
				return target;

			var stem = fileName.Substring(0, fileName.Length - extension.Length - 1);
			for (int i = 1; i < 1000; i++)
			{
				var candidate = Uno.IO.Path.Combine(dir, stem + "-" + i + "." + extension);
				if (!Uno.IO.File.Exists(candidate))
					return candidate;
			}

			throw new Exception("Could not create a unique file name for: " + name);
		}

		static void AppendExif(ref string result, string key, string value)
		{
			if (!string.IsNullOrEmpty(value))
				result += key + "\t" + value + "\n";
		}

		static string Ascii(byte[] bytes)
		{
			if (bytes == null)
				return "";

			var result = "";
			for (int i = 0; i < bytes.Length; i++)
			{
				if (bytes[i] == 0)
					break;
				result += (char)bytes[i];
			}

			return result.Trim();
		}

		static string Rational(byte[] value)
		{
			if (value == null || value.Length < 8)
				return "";

			int numerator =
				(int)value[0] |
				((int)value[1] << 8) |
				((int)value[2] << 16) |
				((int)value[3] << 24);

			int denominator =
				(int)value[4] |
				((int)value[5] << 8) |
				((int)value[6] << 16) |
				((int)value[7] << 24);

			if (denominator == 0)
				return "";

			return ((double)numerator / denominator).ToString();
		}

		static DotNetBitmap RotateBitmap(DotNetBitmap source, double degrees)
		{
			double radians = degrees * Math.PI / 180.0;
			double cosine = Math.Abs(Math.Cos(radians));
			double sine = Math.Abs(Math.Sin(radians));

			int width = Math.Max(1, (int)Math.Round(source.Width * cosine + source.Height * sine));
			int height = Math.Max(1, (int)Math.Round(source.Width * sine + source.Height * cosine));

			var target = new DotNetBitmap(width, height);
			var graphics = DotNetGraphics.FromImage(target);
			try
			{
				graphics.InterpolationMode = DotNetInterpolationMode.HighQualityBicubic;
				graphics.TranslateTransform(width / 2.0f, height / 2.0f);
				graphics.RotateTransform((float)degrees);
				graphics.DrawImage(
					source,
					new DotNetRectangleF(
						-source.Width / 2.0f,
						-source.Height / 2.0f,
						source.Width,
						source.Height));
			}
			finally
			{
				graphics.Dispose();
			}
			return target;
		}

		static DotNetBitmap FlipBitmap(DotNetBitmap source, bool horizontal, bool vertical)
		{
			var target = new DotNetBitmap(source.Width, source.Height);
			var graphics = DotNetGraphics.FromImage(target);
			try
			{
				graphics.TranslateTransform(
					horizontal ? source.Width : 0,
					vertical ? source.Height : 0);
				graphics.ScaleTransform(
					horizontal ? -1 : 1,
					vertical ? -1 : 1);
				graphics.DrawImage(
					source,
					new DotNetRectangleF(0, 0, source.Width, source.Height));
			}
			finally
			{
				graphics.Dispose();
			}
			return target;
		}

		static void SaveBitmap(DotNetBitmap bitmap, string path, string format, int quality)
		{
			if (format == "png")
			{
				bitmap.Save(path, ImageFormat.Png);
				return;
			}
			if (format == "gif")
			{
				bitmap.Save(path, ImageFormat.Gif);
				return;
			}
			if (format == "bmp")
			{
				bitmap.Save(path, ImageFormat.Bmp);
				return;
			}
			if (format == "webp")
				throw new Exception("WebP encoding is not supported on .NET");

			var codec = FindEncoder("image/jpeg");
			if (codec == null)
			{
				bitmap.Save(path, ImageFormat.Jpeg);
				return;
			}

			var parameters = new EncoderParameters(1);
			var parameter = new EncoderParameter(Encoder.Quality, ClampQuality(quality));
			parameters.Param = new EncoderParameter[] { parameter };
			try
			{
				bitmap.Save(path, codec, parameters);
			}
			finally
			{
				parameter.Dispose();
				parameters.Dispose();
			}
		}

		static void SaveBitmap(DotNetBitmap bitmap, Stream stream, string format, int quality)
		{
			if (format == "png")
			{
				bitmap.Save(stream, ImageFormat.Png);
				return;
			}
			if (format == "gif")
			{
				bitmap.Save(stream, ImageFormat.Gif);
				return;
			}
			if (format == "bmp")
			{
				bitmap.Save(stream, ImageFormat.Bmp);
				return;
			}
			if (format == "webp")
				throw new Exception("WebP encoding is not supported on .NET");

			var codec = FindEncoder("image/jpeg");
			if (codec == null)
			{
				bitmap.Save(stream, ImageFormat.Jpeg);
				return;
			}

			var parameters = new EncoderParameters(1);
			var parameter = new EncoderParameter(Encoder.Quality, ClampQuality(quality));
			parameters.Param = new EncoderParameter[] { parameter };
			try
			{
				bitmap.Save(stream, codec, parameters);
			}
			finally
			{
				parameter.Dispose();
				parameters.Dispose();
			}
		}

		static ImageCodecInfo FindEncoder(string mimeType)
		{
			foreach (var codec in ImageCodecInfo.GetImageEncoders())
			{
				if (codec.MimeType == mimeType)
					return codec;
			}
			return null;
		}

		static int ClampQuality(int quality)
		{
			return quality < 0 ? 0 : (quality > 100 ? 100 : quality);
		}

		static ImageFormat ImageFormatFor(string extension)
		{
			if (extension == "png")
				return ImageFormat.Png;
			if (extension == "gif")
				return ImageFormat.Gif;
			if (extension == "bmp")
				return ImageFormat.Bmp;
			return ImageFormat.Jpeg;
		}

		static string NormalizeFormat(string format, string path)
		{
			if (format == null || format.Length == 0)
				return ExtensionFromPath(path);

			format = format.ToLower();
			if (format == "jpeg")
				return "jpg";

			if (format != "jpg" && format != "png" && format != "webp")
				throw new Exception("format must be one of \"jpeg\", \"png\" or \"webp\"");

			return format;
		}

		static string ExtensionFromPath(string path)
		{
			int dot = path.LastIndexOf('.');
			var extension = dot >= 0 ? path.Substring(dot + 1).ToLower() : "";

			if (extension == "jpeg" || extension == "jpg" || extension == "png" ||
					extension == "webp" || extension == "gif" || extension == "bmp")
				return extension;

			return "jpg";
		}

		static string TargetPath(string sourcePath, string format, bool inPlace)
		{
			var extension = format;
			if (inPlace)
			{
				var sourceExtension = ExtensionFromPath(sourcePath);
				bool matches = format == "jpg"
					? (sourceExtension == "jpg" || sourceExtension == "jpeg")
					: sourceExtension == format;

				if (matches)
					return sourcePath;
			}

			return TemporaryPath(extension);
		}

		static string ExtensionFromData(byte[] bytes)
		{
			if (bytes == null || bytes.Length < 3)
				return "jpg";

			int b0 = (int)bytes[0];
			int b1 = (int)bytes[1];

			if (b0 == 0xFF && b1 == 0xD8)
				return "jpg";
			if (b0 == 0x89 && b1 == 'P' && (int)bytes[2] == 'N')
				return "png";
			if (b0 == 'G' && b1 == 'I' && (int)bytes[2] == 'F')
				return "gif";
			if (b0 == 'B' && b1 == 'M')
				return "bmp";

			if (bytes.Length >= 12)
			{
				if (b0 == 'R' && b1 == 'I' && (int)bytes[2] == 'F' && (int)bytes[3] == 'F' &&
						(int)bytes[8] == 'W' && (int)bytes[9] == 'E' &&
						(int)bytes[10] == 'B' && (int)bytes[11] == 'P')
					return "webp";

				if ((int)bytes[4] == 'f' && (int)bytes[5] == 't' &&
						(int)bytes[6] == 'y' && (int)bytes[7] == 'p')
					return "heic";
			}

			return "jpg";
		}

		static string StripDataUri(string value)
		{
			int comma = value.IndexOf(',');
			if (value.StartsWith("data:") && comma >= 0)
				return value.Substring(comma + 1);
			return value;
		}

		static string TemporaryPath(string extension)
		{
			var dir = DotNetNative.Path.GetTempPath();
			var path = DotNetNative.Path.ChangeExtension(dir + "IMG_" + DotNetNative.Path.GetRandomFileName(), extension);
			return path;
		}
	}

}
