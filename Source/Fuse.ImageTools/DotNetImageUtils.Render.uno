using Uno;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.ImageTools
{
	using DotNetNative;

	extern (DOTNET) internal partial class DotNetImageUtils
	{
		public static void Composite(string path, string overlayPath, int x, int y, double opacity, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool inPlace)
		{
			try
			{
				bool orientationChanged;
				var baseImage = LoadOrientedBitmap(path, out orientationChanged);
				var overlay = LoadOrientedBitmap(overlayPath, out orientationChanged);

				try
				{
					var result = CompositeBitmaps(baseImage, overlay, x, y, (float)opacity);
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
					baseImage.Dispose();
					overlay.Dispose();
				}
			}
			catch (Exception e)
			{
				onFail(e.Message);
			}
		}

		public static void Filter(string path, string type, double amount, int radius, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool inPlace)
		{
			try
			{
				if (type == "blur")
					throw new Exception("blur is not supported on .NET");

				bool orientationChanged;
				var source = LoadOrientedBitmap(path, out orientationChanged);

				try
				{
					var result = ApplyColorFilter(source, type, (float)amount);
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

		static DotNetBitmap CompositeBitmaps(DotNetBitmap baseImage, DotNetBitmap overlay, int x, int y, float opacity)
		{
			int width = baseImage.Width;
			int height = baseImage.Height;

			var result = new DotNetBitmap(width, height, PixelFormat.Format32bppArgb);
			var baseData = baseImage.LockBits(new DotNetRectangle(0, 0, width, height), DotNetImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
			var overlayData = overlay.LockBits(new DotNetRectangle(0, 0, overlay.Width, overlay.Height), DotNetImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
			var resultData = result.LockBits(new DotNetRectangle(0, 0, width, height), DotNetImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);

			try
			{
				int baseStride = baseData.Stride;
				int overlayStride = overlayData.Stride;
				int resultStride = resultData.Stride;

				var baseBytes = new byte[baseStride * height];
				var overlayBytes = new byte[overlayStride * overlay.Height];
				var resultBytes = new byte[resultStride * height];

				DotNetMarshal.Copy(baseData.Scan0, baseBytes, 0, baseBytes.Length);
				DotNetMarshal.Copy(overlayData.Scan0, overlayBytes, 0, overlayBytes.Length);

				for (int row = 0; row < height; row++)
				{
					int sourceRow = row * baseStride;
					int resultRow = row * resultStride;
					for (int column = 0; column < width * 4; column++)
						resultBytes[resultRow + column] = baseBytes[sourceRow + column];
				}

				float alphaScale = Math.Max(0.0f, Math.Min(1.0f, opacity));
				int startX = Math.Max(0, -x);
				int startY = Math.Max(0, -y);
				int endX = Math.Min(overlay.Width, width - x);
				int endY = Math.Min(overlay.Height, height - y);

				for (int overlayY = startY; overlayY < endY; overlayY++)
				{
					int overlayRow = overlayY * overlayStride;
					int resultRow = (y + overlayY) * resultStride;

					for (int overlayX = startX; overlayX < endX; overlayX++)
					{
						int overlayIndex = overlayRow + overlayX * 4;
						int resultIndex = resultRow + (x + overlayX) * 4;

						float overlayAlpha = (overlayBytes[overlayIndex + 3] / 255.0f) * alphaScale;
						if (overlayAlpha <= 0.0f)
							continue;

						float baseAlpha = baseBytes[resultIndex + 3] / 255.0f;
						float outAlpha = overlayAlpha + baseAlpha * (1.0f - overlayAlpha);

						if (outAlpha <= 0.0f)
						{
							resultBytes[resultIndex] = 0;
							resultBytes[resultIndex + 1] = 0;
							resultBytes[resultIndex + 2] = 0;
							resultBytes[resultIndex + 3] = 0;
							continue;
						}

						resultBytes[resultIndex] = BlendChannel(overlayBytes[overlayIndex], baseBytes[resultIndex], overlayAlpha, baseAlpha, outAlpha);
						resultBytes[resultIndex + 1] = BlendChannel(overlayBytes[overlayIndex + 1], baseBytes[resultIndex + 1], overlayAlpha, baseAlpha, outAlpha);
						resultBytes[resultIndex + 2] = BlendChannel(overlayBytes[overlayIndex + 2], baseBytes[resultIndex + 2], overlayAlpha, baseAlpha, outAlpha);
						resultBytes[resultIndex + 3] = ClampToByte(outAlpha * 255.0f);
					}
				}

				DotNetMarshal.Copy(resultBytes, 0, resultData.Scan0, resultBytes.Length);
				return result;
			}
			finally
			{
				baseImage.UnlockBits(baseData);
				overlay.UnlockBits(overlayData);
				result.UnlockBits(resultData);
			}
		}

		static byte BlendChannel(byte overlay, byte baseChannel, float overlayAlpha, float baseAlpha, float outAlpha)
		{
			float value = (overlay * overlayAlpha + baseChannel * baseAlpha * (1.0f - overlayAlpha)) / outAlpha;
			return ClampToByte(value);
		}

		static DotNetBitmap ApplyColorFilter(DotNetBitmap source, string type, float amount)
		{
			int mode = FilterMode(type);
			if (mode < 0)
				throw new Exception("Unsupported filter type: " + type);

			int width = source.Width;
			int height = source.Height;
			var result = new DotNetBitmap(width, height, PixelFormat.Format32bppArgb);
			var sourceData = source.LockBits(new DotNetRectangle(0, 0, width, height), DotNetImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
			var resultData = result.LockBits(new DotNetRectangle(0, 0, width, height), DotNetImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);

			try
			{
				int sourceStride = sourceData.Stride;
				int resultStride = resultData.Stride;
				var sourceBytes = new byte[sourceStride * height];
				var resultBytes = new byte[resultStride * height];

				DotNetMarshal.Copy(sourceData.Scan0, sourceBytes, 0, sourceBytes.Length);

				float contrastFactor = 1.0f + amount;
				float saturationFactor = 1.0f + amount;
				int brightnessOffset = (int)Math.Round((double)(amount * 255.0f));

				for (int y = 0; y < height; y++)
				{
					int sourceRow = y * sourceStride;
					int resultRow = y * resultStride;

					for (int x = 0; x < width; x++)
					{
						int sourceIndex = sourceRow + x * 4;
						int resultIndex = resultRow + x * 4;

						int b = sourceBytes[sourceIndex];
						int g = sourceBytes[sourceIndex + 1];
						int r = sourceBytes[sourceIndex + 2];

						switch (mode)
						{
							case 0:
							{
								int luma = (int)Math.Round((double)(0.299f * r + 0.587f * g + 0.114f * b));
								r = g = b = luma;
								break;
							}
							case 1:
							{
								int sepiaR = (int)Math.Round((double)(0.393f * r + 0.769f * g + 0.189f * b));
								int sepiaG = (int)Math.Round((double)(0.349f * r + 0.686f * g + 0.168f * b));
								int sepiaB = (int)Math.Round((double)(0.272f * r + 0.534f * g + 0.131f * b));
								r = ClampToByte(sepiaR);
								g = ClampToByte(sepiaG);
								b = ClampToByte(sepiaB);
								break;
							}
							case 2:
								r = ClampToByte(r + brightnessOffset);
								g = ClampToByte(g + brightnessOffset);
								b = ClampToByte(b + brightnessOffset);
								break;
							case 3:
								r = ClampToByte((r - 128) * contrastFactor + 128);
								g = ClampToByte((g - 128) * contrastFactor + 128);
								b = ClampToByte((b - 128) * contrastFactor + 128);
								break;
							case 4:
							{
								float luma = 0.213f * r + 0.715f * g + 0.072f * b;
								r = ClampToByte(luma + (r - luma) * saturationFactor);
								g = ClampToByte(luma + (g - luma) * saturationFactor);
								b = ClampToByte(luma + (b - luma) * saturationFactor);
								break;
							}
						}

						resultBytes[resultIndex] = (byte)b;
						resultBytes[resultIndex + 1] = (byte)g;
						resultBytes[resultIndex + 2] = (byte)r;
						resultBytes[resultIndex + 3] = sourceBytes[sourceIndex + 3];
					}
				}

				DotNetMarshal.Copy(resultBytes, 0, resultData.Scan0, resultBytes.Length);
				return result;
			}
			finally
			{
				source.UnlockBits(sourceData);
				result.UnlockBits(resultData);
			}
		}

		static int FilterMode(string type)
		{
			if (type == "grayscale") return 0;
			if (type == "sepia") return 1;
			if (type == "brightness") return 2;
			if (type == "contrast") return 3;
			if (type == "saturation") return 4;
			return -1;
		}

		static byte ClampToByte(double value)
		{
			return (byte)Math.Max(0, Math.Min(255, (int)Math.Round(value)));
		}

		public static void DrawText(string path, string text, int x, int y, double fontSize, string font, int color, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool inPlace)
		{
			try
			{
				bool orientationChanged;
				var source = LoadOrientedBitmap(path, out orientationChanged);

				try
				{
					var result = new DotNetBitmap(source.Width, source.Height);
					try
					{
						var graphics = DotNetGraphics.FromImage(result);
						try
						{
							graphics.DrawImage(source, new DotNetRectangleF(0, 0, source.Width, source.Height));

							DotNetFont textFont = null;
							try
							{
								if (font != null && font.Length > 0)
								{
									try
									{
										textFont = new DotNetFont(font, (float)fontSize);
									}
									catch (Exception)
									{
									}
								}

								if (textFont == null)
									textFont = new DotNetFont(DotNetFontFamily.GenericSansSerif, (float)fontSize);

								var brush = new DotNetSolidBrush(DotNetColor.FromArgb(color));
								try
								{
									graphics.DrawString(text, textFont, brush, x, y);
								}
								finally
								{
									brush.Dispose();
								}
							}
							finally
							{
								if (textFont != null)
									textFont.Dispose();
							}
						}
						finally
						{
							graphics.Dispose();
						}

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

		public static byte[] GetPixelBuffer(string path)
		{
			bool orientationChanged;
			var source = LoadOrientedBitmap(path, out orientationChanged);

			try
			{
				int width = source.Width;
				int height = source.Height;

				var data = source.LockBits(
					new DotNetRectangle(0, 0, width, height),
					DotNetImageLockMode.ReadOnly,
					PixelFormat.Format32bppArgb);

				try
				{
					int stride = data.Stride;
					long bufferLength = (long)stride * height;
					long rgbaLength = (long)width * height * 4;

					if (bufferLength > int.MaxValue || rgbaLength > int.MaxValue)
						throw new Exception("Image is too large for a pixel buffer");

					var buffer = new byte[(int)bufferLength];
					DotNetMarshal.Copy(data.Scan0, buffer, 0, buffer.Length);

					var rgba = new byte[(int)rgbaLength];
					int index = 0;

					for (int y = 0; y < height; y++)
					{
						int sourceIndex = y * stride;
						for (int x = 0; x < width; x++)
						{
							rgba[index++] = buffer[sourceIndex + 2];
							rgba[index++] = buffer[sourceIndex + 1];
							rgba[index++] = buffer[sourceIndex];
							rgba[index++] = buffer[sourceIndex + 3];
							sourceIndex += 4;
						}
					}

					return rgba;
				}
				finally
				{
					source.UnlockBits(data);
				}
			}
			finally
			{
				source.Dispose();
			}
			throw new Exception("Could not read pixel buffer");
		}

	}
}
