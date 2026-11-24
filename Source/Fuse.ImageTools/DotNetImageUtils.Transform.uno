using Uno;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.ImageTools
{
	using DotNetNative;

	extern (DOTNET) internal partial class DotNetImageUtils
	{
		public static void Resize(string path, int desiredWidth, int desiredHeight, int mode, string format, int quality, int background, Action<string> onSuccess, Action<string> onFail, bool inPlace)
		{
			try
			{
				if (desiredWidth <= 0 || desiredHeight <= 0)
					throw new Exception("desiredWidth and desiredHeight must be larger than 0");

				bool orientationChanged;
				var source = LoadOrientedBitmap(path, out orientationChanged);
				try
				{
					int sourceWidth = source.Width;
					int sourceHeight = source.Height;
					DotNetBitmap result = null;

					try
					{
						switch (mode)
						{
							case 1:
							{
								float ratio = 1.0f;
								if (sourceWidth > desiredWidth)
									ratio = (float)desiredWidth / sourceWidth;
								if (sourceHeight * ratio > desiredHeight)
									ratio = (float)desiredHeight / sourceHeight;

								int width = Math.Max(1, (int)Math.Round((double)(sourceWidth * ratio)));
								int height = Math.Max(1, (int)Math.Round((double)(sourceHeight * ratio)));
								result = Render(source, width, height);
								break;
							}
							case 2:
							{
								float ratio = Math.Max(
									(float)desiredWidth / sourceWidth,
									(float)desiredHeight / sourceHeight);

								int width = Math.Max(1, (int)Math.Round((double)(sourceWidth * ratio)));
								int height = Math.Max(1, (int)Math.Round((double)(sourceHeight * ratio)));
								var scaled = Render(source, width, height);
								try
								{
									int left = Math.Max(0, (width - desiredWidth) / 2);
									int top = Math.Max(0, (height - desiredHeight) / 2);
									result = CropBitmap(
										scaled, left, top,
										Math.Min(desiredWidth, width), Math.Min(desiredHeight, height));
								}
								finally
								{
									scaled.Dispose();
								}
								break;
							}
							case 3:
							{
								float ratio = Math.Min(
									(float)desiredWidth / sourceWidth,
									(float)desiredHeight / sourceHeight);
								int width = Math.Max(1, (int)Math.Round((double)(sourceWidth * ratio)));
								int height = Math.Max(1, (int)Math.Round((double)(sourceHeight * ratio)));
								result = Render(source, width, height);
								break;
							}
							case 4:
							{
								float ratio = Math.Min(
									(float)desiredWidth / sourceWidth,
									(float)desiredHeight / sourceHeight);
								int width = Math.Max(1, (int)Math.Round((double)(sourceWidth * ratio)));
								int height = Math.Max(1, (int)Math.Round((double)(sourceHeight * ratio)));

								var scaled = Render(source, width, height);
								try
								{
									result = PadBitmap(scaled, desiredWidth, desiredHeight, background);
								}
								finally
								{
									scaled.Dispose();
								}
								break;
							}
							default:
								result = Render(source, desiredWidth, desiredHeight);
								break;
						}

						SaveResult(result, path, format, quality, inPlace, onSuccess);
					}
					finally
					{
						if (result != null)
							result.Dispose();
					}
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

		public static void Crop(string path, int width, int height, int x, int y, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool inPlace)
		{
			try
			{
				bool orientationChanged;
				var source = LoadOrientedBitmap(path, out orientationChanged);
				try
				{
					int left = Math.Max(0, x);
					int top = Math.Max(0, y);
					int cropWidth = Math.Min(width, source.Width - left);
					int cropHeight = Math.Min(height, source.Height - top);

					if (cropWidth <= 0 || cropHeight <= 0)
						throw new Exception("Crop rectangle is outside image bounds");

					var result = CropBitmap(source, left, top, cropWidth, cropHeight);
					try
					{
						SaveResult(result, path, format, quality, inPlace, onSuccess);
					}
					finally
					{
						result.Dispose();
					}
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

		public static void Rotate(string path, double degrees, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool inPlace)
		{
			try
			{
				degrees = degrees - Math.Floor(degrees / 360.0) * 360.0;

				bool orientationChanged;
				var source = LoadOrientedBitmap(path, out orientationChanged);
				try
				{
					bool hasFormat = format != null && format.Length > 0;
					if (degrees == 0 && !orientationChanged && !hasFormat && inPlace)
					{
						onSuccess(path);
						return;
					}

					DotNetBitmap result = source;
					bool ownsResult = false;

					try
					{
						if (degrees != 0)
						{
							result = RotateBitmap(source, degrees);
							ownsResult = true;
						}

						SaveResult(result, path, format, quality, inPlace, onSuccess);
					}
					finally
					{
						if (ownsResult)
							result.Dispose();
					}
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

		public static void Flip(string path, bool horizontal, bool vertical, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool inPlace)
		{
			try
			{
				bool orientationChanged;
				var source = LoadOrientedBitmap(path, out orientationChanged);
				try
				{
					var result = FlipBitmap(source, horizontal, vertical);
					try
					{
						SaveResult(result, path, format, quality, inPlace, onSuccess);
					}
					finally
					{
						result.Dispose();
					}
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

		public static void AutoOrient(string path, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool inPlace)
		{
			try
			{
				bool hasFormat = format != null && format.Length > 0;
				var source = LoadBitmap(path);
				try
				{
					int orientation = GetOrientation(source);
					if (orientation <= 1 && !hasFormat && inPlace)
					{
						onSuccess(path);
						return;
					}

					DotNetBitmap result = source;
					bool ownsResult = false;

					try
					{
						if (orientation > 1)
						{
							result = new DotNetBitmap(source);
							result.RotateFlip(OrientationToRotateFlip(orientation));
							ownsResult = true;
						}

						SaveResult(result, path, format, quality, inPlace, onSuccess);
					}
					finally
					{
						if (ownsResult)
							result.Dispose();
					}
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

		public static void Thumbnail(string path, int maxWidth, int maxHeight, string format, int quality, Action<string> onSuccess, Action<string> onFail)
		{
			try
			{
				if (maxWidth <= 0 && maxHeight <= 0)
					throw new Exception("maxWidth and/or maxHeight must be larger than 0");

				bool orientationChanged;
				var source = LoadOrientedBitmap(path, out orientationChanged);
				try
				{
					int sourceWidth = source.Width;
					int sourceHeight = source.Height;

					float ratio = 1.0f;
					if (maxWidth > 0)
						ratio = Math.Min(ratio, (float)maxWidth / sourceWidth);
					if (maxHeight > 0)
						ratio = Math.Min(ratio, (float)maxHeight / sourceHeight);
					ratio = Math.Min(ratio, 1.0f);

					int width = Math.Max(1, (int)Math.Round((double)(sourceWidth * ratio)));
					int height = Math.Max(1, (int)Math.Round((double)(sourceHeight * ratio)));
					var result = Render(source, width, height);
					try
					{
						var targetFormat = NormalizeFormat(format, path);
						var target = TemporaryPath(ExtensionForFormat(targetFormat));
						SaveBitmap(result, target, targetFormat, quality);
						onSuccess(target);
					}
					finally
					{
						result.Dispose();
					}
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

		public static void Convert(string path, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool inPlace)
		{
			try
			{
				bool orientationChanged;
				var source = LoadOrientedBitmap(path, out orientationChanged);
				try
				{
					SaveResult(source, path, format, quality, inPlace, onSuccess);
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

	}
}
