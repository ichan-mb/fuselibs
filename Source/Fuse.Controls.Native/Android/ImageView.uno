using Uno;
using Uno.UX;
using Uno.IO;
using Uno.Compiler.ExportTargetInterop;
using Uno.Collections;
using Uno.Graphics;
using OpenGL;
using Fuse.Resources;
using Fuse.Elements;

namespace Fuse.Controls.Native.Android
{
	[ForeignInclude(Language.Java,
		"java.lang.Runnable",
		"android.graphics.*",
		"android.app.Activity",
		"java.net.*",
		"java.io.*",
		"java.lang.*")]
	extern(Android) internal class HttpImageLoader : Uno.Threading.Promise<Java.Object>
	{

		public HttpImageLoader(string url) : base(UpdateManager.Dispatcher)
		{
			LoadAsync(url, Success, Error);
		}

		void Success(Java.Object bitmap)
		{
			if (!_isDisposed)
				Resolve(bitmap);
		}

		void Error(string errorMsg)
		{
			if (!_isDisposed)
				Reject(new Exception(errorMsg));
		}

		[Foreign(Language.Java)]
		static void LoadAsync(string urlString, Action<Java.Object> success, Action<string> error)
		@{
			Thread thread = new Thread() {
				public void run() {
					try
					{
						URL url = new URL(urlString);
						HttpURLConnection connection = (HttpURLConnection)url.openConnection();
						connection.setDoInput(true);
						connection.connect();
						InputStream input = connection.getInputStream();
						Bitmap bitmap = BitmapFactory.decodeStream(input);
						success.run(bitmap);
					}
					catch (IOException e)
					{
						error.run(e.getMessage());
					}
				}
			};
			thread.start();
		@}

		bool _isDisposed = false;
		public override void Dispose()
		{
			_isDisposed = true;
			base.Dispose();
		}

	}

	extern(Android) internal class ImageView : View, IImageView
	{

		ImageSource _imageSource;
		public ImageSource ImageSource
		{
			set
			{
				if (ImageSource is MultiDensityImageSource)
					((MultiDensityImageSource)ImageSource).ActiveChanged -= OnMultiDensityImageSourceActiveChanged;

				_imageSource = value;
				if (value == null)
					return;

				if (value is FileImageSource)
					UpdateImage((FileImageSource)value);
				else if (value is HttpImageSource)
					UpdateImage((HttpImageSource)value);
				else if (value is MultiDensityImageSource)
				{
					((MultiDensityImageSource)ImageSource).ActiveChanged += OnMultiDensityImageSourceActiveChanged;
					UpdateImage((MultiDensityImageSource)value);
				}
				else
				{
					throw new Exception(value + " not supported in native context");
				}
			}
			private get
			{
				return _imageSource;
			}
		}

		string _symbols;
		public string Symbols
		{
			set
			{
				if (_symbols != value)
				{
					_symbols = value;
					UpdateImage();
				}
			}
		}

		bool _isFilled;
		public bool IsFilled
		{
			set
			{
				if (_isFilled != value)
				{
					_isFilled = value;
					UpdateImage();
				}
			}
		}

		void OnMultiDensityImageSourceActiveChanged()
		{
			if (ImageSource is MultiDensityImageSource)
			{
				UpdateImage((MultiDensityImageSource)ImageSource);
			}
		}

		float4 _tintColor = float4(1.0f);
		public float4 TintColor
		{
			set
			{
				_tintColor = value;
				SetTint(_imageView, (int)Color.ToArgb(_tintColor));
			}
		}

		bool _isLoad = true;
		public bool IsLoaded
		{
			set { _isLoad = value; }
		}

		Java.Object _imageView;

		public ImageView() : base(CreateContainer())
		{
			_imageView = Create(Handle);
		}

		public override void Dispose()
		{
			ImageHandle = null;
			if (ImageSource != null && ImageSource is MultiDensityImageSource)
			{
				((MultiDensityImageSource)ImageSource).ActiveChanged -= OnMultiDensityImageSourceActiveChanged;
			}
			base.Dispose();
		}

		public void UpdateImageTransform(float density, float2 origin, float2 scale, float2 drawSize)
		{
			if (!string.IsNullOrEmpty(_symbols))
			{
				UpdateImage();
			}
			else
			{
				var imagePos = (int2)Math.Ceil(origin * density);
				var imageScale = scale * density;
				UpdateImageTransform(
					_imageView,
					imagePos.X,
					imagePos.Y,
					imageScale.X,
					imageScale.Y);
			}
		}

		IDisposable _imageHandle;
		ImageHandle ImageHandle
		{
			set
			{
				if (_imageHandle != null)
				{
					_imageHandle.Dispose();
					_imageHandle = null;
					ClearBitmap(_imageView);
				}

				_imageHandle = value;

				if (_imageHandle != null)
				{
					SetBitmap(_imageView, (Java.Object)value.Handle);
					SetTint(_imageView, (int)Color.ToArgb(_tintColor));
				}
			}
		}

		void UpdateImage()
		{
			if (!string.IsNullOrEmpty(_symbols) && Size.X > 0)
			{
				ImageHandle = null;
				var colorArgb = (int)Color.ToArgb(_tintColor);
				var bitmap = GetBitmapFromSymbol(_symbols, colorArgb, Size.X, _isFilled);
				SetBitmap(_imageView, bitmap);
			}
		}

		internal protected override void OnSizeChanged()
		{
			UpdateImage();
		}

		static Java.Object GetMaterialSymbolsTypeface()
		{
			var bundleFileSource = GetMaterialSymbolsBundleFileSource();
			if (bundleFileSource != null)
				return LoadTypefaceFromBundle(bundleFileSource.BundleFile);
			else
				return GetDefaultTypeface();
		}

		static BundleFileSource GetMaterialSymbolsBundleFileSource()
		{
			// Find the MaterialSymbols.ttf in the bundle
			foreach (var file in Uno.IO.Bundle.AllFiles)
			{
				if (file.SourcePath.EndsWith("MaterialSymbols.ttf"))
				{
					return new BundleFileSource(file);
				}
			}
			return null;
		}

		[Foreign(Language.Java)]
		static Java.Object LoadTypefaceFromBundle(BundleFile bundleFile)
		@{
			try
			{
				String uri = @{BundleFile:of(bundleFile).BundlePath:get()};
				android.content.res.AssetManager assetManager = com.fuse.Activity.getRootActivity().getAssets();
				android.graphics.Typeface typeface = android.graphics.Typeface.createFromAsset(assetManager, uri);
				return typeface;
			}
			catch (Exception e)
			{
				android.util.Log.e("ImageView", "Failed to load MaterialSymbols font: " + e.getMessage());
				return @{GetDefaultTypeface():call()};
			}
		@}

		[Foreign(Language.Java)]
		static Java.Object GetDefaultTypeface()
		@{
			return android.graphics.Typeface.DEFAULT;
		@}

		void UpdateImage(FileImageSource fileImageSource)
		{
			if (_isLoad)
				ImageHandle = ImageLoader.Load(fileImageSource.File);
		}

		void UpdateImage(HttpImageSource http)
		{
			if (_isLoad)
				ImageLoader.Load(http).Then(OnImageLoaded, OnImageLoadFailed);
		}

		void UpdateImage(MultiDensityImageSource multi)
		{
			var active = multi.Active;
			if (active != null)
			{
				if (active is FileImageSource)
					UpdateImage((FileImageSource)active);
				else if (active is HttpImageSource)
					UpdateImage((HttpImageSource)active);
				else
					throw new Exception(active + " not supported in native context");
			}
		}

		void OnImageLoaded(ImageHandle handle)
		{
			ImageHandle = handle;
		}

		void OnImageLoadFailed(Exception e)
		{
			ImageHandle = null;
		}

		float2 MeasureImage()
		{
			var wh = new int[2];
			GetImageSize(_imageView, wh);
			return float2((float)wh[0], (float)wh[1]);
		}

		[Foreign(Language.Java)]
		static Java.Object GetBitmapFromSymbol(string symbol, int colorArgb, int size, bool isFilled)
		@{
			android.graphics.Typeface typeface = (android.graphics.Typeface)@{GetMaterialSymbolsTypeface():call()};
			android.text.TextPaint paint = new android.text.TextPaint(android.graphics.Paint.ANTI_ALIAS_FLAG | android.graphics.Paint.SUBPIXEL_TEXT_FLAG);
			paint.setTypeface(typeface);
			paint.setColor(colorArgb);
			paint.setTextSize(size);
			paint.setTextAlign(android.graphics.Paint.Align.CENTER);

			// Set font variation for filled style
			if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
				try {
					if (isFilled) {
						paint.setFontVariationSettings("'FILL' 1, 'wght' 400, 'GRAD' 0, 'opsz' " + size);
					} else {
						paint.setFontVariationSettings("'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' " + size);
					}
				} catch (Exception e) {
					android.util.Log.w("ImageView", "Font variations not supported: " + e.getMessage());
				}
			}

			android.graphics.Bitmap bitmap = android.graphics.Bitmap.createBitmap(size, size, android.graphics.Bitmap.Config.ARGB_8888);
			android.graphics.Canvas canvas = new android.graphics.Canvas(bitmap);
			float y = (size / 2.0f) - ((paint.descent() + paint.ascent()) / 2.0f);
			canvas.drawText(symbol, size / 2.0f, y, paint);

			return bitmap;
		@}

		[Foreign(Language.Java)]
		static void GetImageSize(Java.Object handle, int[] wh)
		@{
			android.widget.ImageView imageView = (android.widget.ImageView)handle;
			imageView.measure(
				android.view.View.MeasureSpec.UNSPECIFIED,
				android.view.View.MeasureSpec.UNSPECIFIED);
			wh.set(0, imageView.getMeasuredWidth());
			wh.set(1, imageView.getMeasuredHeight());
		@}

		[Foreign(Language.Java)]
		static void UpdateImageTransform(Java.Object handle, float x, float y, float scaleX, float scaleY)
		@{
			android.widget.ImageView imageView = (android.widget.ImageView)handle;
			float[] m = new float[]
			{
				scaleX, 0.0f, 	x,
				0.0f,	scaleY, y,
				0.0f,	0.0f,	1.0f
			};
			android.graphics.Matrix matrix = new android.graphics.Matrix();
			matrix.setValues(m);
			imageView.setImageMatrix(matrix);
		@}

		[Foreign(Language.Java)]
		static void SetBitmap(Java.Object handle, Java.Object bitmapHandle)
		@{
			((android.widget.ImageView)handle).setImageBitmap( (android.graphics.Bitmap)bitmapHandle );
			((android.widget.ImageView)handle).invalidate();
		@}

		[Foreign(Language.Java)]
		static void SetTint(Java.Object handle, int rgba)
		@{
			android.graphics.drawable.Drawable drawable = ((android.widget.ImageView)handle).getDrawable();
			if (drawable != null) {
				drawable.setColorFilter(rgba, android.graphics.PorterDuff.Mode.MULTIPLY);
			}
		@}

		[Foreign(Language.Java)]
		static void ClearBitmap(Java.Object handle)
		@{
			((android.widget.ImageView)handle).setImageResource(0);
			((android.widget.ImageView)handle).invalidate();
		@}

		[Foreign(Language.Java)]
		static Java.Object Create(Java.Object container)
		@{
			android.widget.FrameLayout frameLayout = (android.widget.FrameLayout)container;
			android.widget.ImageView imageView = new android.widget.ImageView(com.fuse.Activity.getRootActivity());
			imageView.setScaleType(android.widget.ImageView.ScaleType.MATRIX);
			imageView.setLayoutParams(new android.widget.FrameLayout.LayoutParams(android.view.ViewGroup.LayoutParams.MATCH_PARENT, android.view.ViewGroup.LayoutParams.MATCH_PARENT));
			frameLayout.addView(imageView);
			return imageView;
		@}

		[Foreign(Language.Java)]
		static Java.Object CreateContainer()
		@{
			android.widget.FrameLayout frameLayout = new android.widget.FrameLayout(com.fuse.Activity.getRootActivity());
			frameLayout.setFocusable(true);
			frameLayout.setFocusableInTouchMode(true);
			frameLayout.setClipToPadding(true);
			frameLayout.setClipChildren(true);
			frameLayout.setLayoutParams(new android.widget.FrameLayout.LayoutParams(android.view.ViewGroup.LayoutParams.MATCH_PARENT, android.view.ViewGroup.LayoutParams.MATCH_PARENT));
			return frameLayout;
		@}

	}
}
