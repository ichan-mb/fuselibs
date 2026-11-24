using Uno;
using Uno.IO;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.ImageTools
{
	namespace DotNetNative
	{
		[DotNetType("System.Drawing.Imaging.ImageFormat")]
		extern (DOTNET) internal class ImageFormat
		{
			public extern static ImageFormat Jpeg { get; }
			public extern static ImageFormat Png { get; }
			public extern static ImageFormat Gif { get; }
			public extern static ImageFormat Bmp { get; }
		}

		[DotNetType("System.Drawing.Imaging.ImageCodecInfo")]
		extern (DOTNET) internal class ImageCodecInfo
		{
			public extern static ImageCodecInfo[] GetImageEncoders();
			public extern string MimeType { get; }
		}

		[DotNetType("System.Drawing.Imaging.Encoder")]
		extern (DOTNET) internal class Encoder
		{
			public extern static readonly Encoder Quality;
		}

		[DotNetType("System.Drawing.Imaging.EncoderParameter")]
		extern (DOTNET) internal class EncoderParameter
		{
			public extern EncoderParameter(Encoder encoder, long value);
			public extern void Dispose();
		}

		[DotNetType("System.Drawing.Imaging.EncoderParameters")]
		extern (DOTNET) internal class EncoderParameters
		{
			public extern EncoderParameters(int count);
			public extern EncoderParameter[] Param { get; set; }
			public extern void Dispose();
		}

		[DotNetType("System.Drawing.Imaging.PixelFormat")]
		extern (DOTNET) internal enum PixelFormat
		{
			Format32bppArgb = 2498570,
			Format32bppPArgb = 925707,
			Format32bppRgb = 139273,
			Alpha = 262144,
			PAlpha = 524288
		}

		[DotNetType("System.Drawing.Imaging.PropertyItem")]
		extern (DOTNET) internal class PropertyItem
		{
			public extern int Id { get; set; }
			public extern int Len { get; set; }
			public extern short Type { get; set; }
			public extern byte[] Value { get; set; }
		}

		[DotNetType("System.Drawing.Imaging.FrameDimension")]
		extern (DOTNET) internal class DotNetFrameDimension
		{
			public extern static DotNetFrameDimension Time { get; }
		}

		[DotNetType("System.Drawing.Image")]
		extern (DOTNET) internal class DotNetImage
		{
			public extern static DotNetImage FromFile(string path);
			public extern static DotNetImage FromStream(Stream stream);
			public extern void Save(Stream stream, ImageFormat format);
			public extern void Save(string filename, ImageFormat format);
			public extern void Save(string filename, ImageCodecInfo encoder, EncoderParameters encoderParams);
			public extern void Save(Stream stream, ImageCodecInfo encoder, EncoderParameters encoderParams);
			public extern int Width { get; }
			public extern int Height { get; }
			public extern PixelFormat PixelFormat { get; }
			public extern PropertyItem[] PropertyItems { get; }
			public extern int GetFrameCount(DotNetFrameDimension dimension);
			public extern void Dispose();
		}

		[DotNetType("System.Drawing.Bitmap")]
		extern (DOTNET) internal class DotNetBitmap : DotNetImage
		{
			public extern DotNetBitmap(int width, int height);
			public extern DotNetBitmap(int width, int height, PixelFormat format);
			public extern DotNetBitmap(DotNetImage image);
			public extern void RotateFlip(RotateFlipType rotateFlipType);
			public extern DotNetBitmapData LockBits(DotNetRectangle rect, DotNetImageLockMode flags, PixelFormat format);
			public extern void UnlockBits(DotNetBitmapData bitmapdata);
		}

		[DotNetType("System.Drawing.Graphics")]
		extern (DOTNET) internal class DotNetGraphics
		{
			public extern static DotNetGraphics FromImage(DotNetImage image);
			public extern void DrawImage(DotNetImage image, DotNetRectangleF rect);
			public extern void DrawImage(DotNetImage image, DotNetRectangle destRect, DotNetRectangle srcRect, DotNetGraphicsUnit srcUnit);
			public extern void TranslateTransform(float dx, float dy);
			public extern void RotateTransform(float angle);
			public extern void ScaleTransform(float sx, float sy);
			public extern void Clear(DotNetColor color);
			public extern void DrawString(string s, DotNetFont font, DotNetBrush brush, float x, float y);
			public extern DotNetInterpolationMode InterpolationMode { get; set; }
			public extern void Dispose();
		}

		[DotNetType("System.Drawing.Drawing2D.InterpolationMode")]
		extern (DOTNET) internal enum DotNetInterpolationMode
		{
			Default = 0,
			Low = 1,
			High = 2,
			Bilinear = 3,
			Bicubic = 4,
			NearestNeighbor = 5,
			HighQualityBilinear = 6,
			HighQualityBicubic = 7
		}

		[DotNetType("System.Drawing.GraphicsUnit")]
		extern (DOTNET) internal enum DotNetGraphicsUnit
		{
			World = 0,
			Display = 1,
			Pixel = 2,
			Point = 3,
			Inch = 4,
			Document = 5,
			Millimeter = 6
		}

		[DotNetType("System.Drawing.Color")]
		extern (DOTNET) internal struct DotNetColor
		{
			public extern static DotNetColor FromArgb(int argb);
		}

		[DotNetType("System.Drawing.FontFamily")]
		extern (DOTNET) internal class DotNetFontFamily
		{
			public extern static DotNetFontFamily GenericSansSerif { get; }
		}

		[DotNetType("System.Drawing.Font")]
		extern (DOTNET) internal class DotNetFont
		{
			public extern DotNetFont(string familyName, float emSize);
			public extern DotNetFont(DotNetFontFamily family, float emSize);
			public extern void Dispose();
		}

		[DotNetType("System.Drawing.Brush")]
		extern (DOTNET) internal abstract class DotNetBrush
		{
			public abstract extern void Dispose();
		}

		[DotNetType("System.Drawing.SolidBrush")]
		extern (DOTNET) internal class DotNetSolidBrush : DotNetBrush
		{
			public extern DotNetSolidBrush(DotNetColor color);
			public override extern void Dispose();
		}

		[DotNetType("System.Drawing.Imaging.BitmapData")]
		extern (DOTNET) internal class DotNetBitmapData
		{
			public extern int Stride { get; }
			public extern IntPtr Scan0 { get; }
		}

		[DotNetType("System.Drawing.Imaging.ImageLockMode")]
		extern (DOTNET) internal enum DotNetImageLockMode
		{
			ReadOnly = 1,
			WriteOnly = 2,
			ReadWrite = 3
		}

		[DotNetType("System.Runtime.InteropServices.Marshal")]
		extern (DOTNET) internal static class DotNetMarshal
		{
			public extern static void Copy(IntPtr source, byte[] destination, int startIndex, int length);
			public extern static void Copy(byte[] source, int startIndex, IntPtr destination, int length);
		}

		[DotNetType("System.Drawing.Rectangle")]
		extern (DOTNET) internal struct DotNetRectangle
		{
			public extern DotNetRectangle(int x, int y, int width, int height);
			public extern int X { get; set; }
			public extern int Y { get; set; }
			public extern int Width { get; set; }
			public extern int Height { get; set; }
		}

		[DotNetType("System.Drawing.RectangleF")]
		extern (DOTNET) internal struct DotNetRectangleF
		{
			public extern DotNetRectangleF(float x, float y, float width, float height);
			public extern float X { get; set; }
			public extern float Y { get; set; }
			public extern float Width { get; set; }
			public extern float Height { get; set; }
		}

		[DotNetType("System.Drawing.RotateFlipType")]
		extern (DOTNET) internal enum RotateFlipType
		{
			Rotate180FlipNone = 2,
			Rotate180FlipX = 6,
			Rotate180FlipXY = 0,
			Rotate180FlipY = 4,
			Rotate270FlipNone = 3,
			Rotate270FlipX = 7,
			Rotate270FlipXY = 1,
			Rotate270FlipY = 5,
			Rotate90FlipNone = 1,
			Rotate90FlipX = 5,
			Rotate90FlipXY = 3,
			Rotate90FlipY = 7,
			RotateNoneFlipNone = 0,
			RotateNoneFlipX = 4,
			RotateNoneFlipXY = 2,
			RotateNoneFlipY = 6
		}

		[DotNetType("System.Convert")]
		extern (DOTNET) internal class Convert
		{
			public extern static byte[] FromBase64String(string s);
			public extern static string ToBase64String(byte[] inArray);
		}

		[DotNetType("System.Uri")]
		extern (DOTNET) internal class DotNetUri
		{
			public extern DotNetUri(string uriString);
			public extern string LocalPath { get; }
		}

		[DotNetType("System.IO.Path")]
		extern (DOTNET) internal class Path
		{
			public extern static string GetTempPath();
			public extern static string GetRandomFileName();
			public extern static string ChangeExtension(string path, string extension);
			public extern static string GetFileName(string path);
		}
	}
}
