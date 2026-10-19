package com.fuse.controls.nativenavigation;

/**
 * Menu icon drawables: Material Symbols ligatures (mirroring ImageView) or Fuse-loaded bitmaps, tinted
 * for the toolbar.
 */
public class NavigationIcons
{
	private static android.graphics.Typeface symbolsTypeface;

	private static android.graphics.Typeface getSymbolsTypeface(String fontPath)
	{
		if (symbolsTypeface == null)
		{
			try
			{
				if (fontPath != null)
					symbolsTypeface = android.graphics.Typeface.createFromAsset(
						com.fuse.Activity.getRootActivity().getAssets(), fontPath);
			}
			catch (Exception e)
			{
				android.util.Log.e("FuseNavigation", "Failed to load MaterialSymbols font: " + e.getMessage());
			}

			if (symbolsTypeface == null)
				symbolsTypeface = android.graphics.Typeface.DEFAULT;
		}
		return symbolsTypeface;
	}

	/**
	 * Symbol icons keyed by everything that changes their pixels; cleared wholesale once it grows, since
	 * the tint can be animated.
	 */
	private static final int MAX_CACHED_SYMBOLS = 32;
	private static final java.util.HashMap<String, android.graphics.drawable.Drawable> symbolsCache =
		new java.util.HashMap<String, android.graphics.drawable.Drawable>();

	/**
	 * A drawable for a Material Symbols ligature, drawn once and reused: the bar re-applies its whole
	 * configuration on every change, and drawing a symbol allocates a bitmap.
	 */
	public static android.graphics.drawable.Drawable symbolDrawable(String fontPath, String ligature, int sizePx, boolean filled, int colorArgb)
	{
		if (ligature == null || ligature.length() == 0 || sizePx <= 0)
			return null;

		String key = ligature + "|" + sizePx + "|" + filled + "|" + colorArgb + "|" + fontPath;
		android.graphics.drawable.Drawable cached = symbolsCache.get(key);
		if (cached != null)
			return cached;

		android.graphics.drawable.Drawable drawn = drawSymbolDrawable(fontPath, ligature, sizePx, filled, colorArgb);
		if (drawn != null)
		{
			if (symbolsCache.size() >= MAX_CACHED_SYMBOLS)
				symbolsCache.clear();
			symbolsCache.put(key, drawn);
		}

		return drawn;
	}

	static android.graphics.drawable.Drawable drawSymbolDrawable(String fontPath, String ligature, int sizePx, boolean filled, int colorArgb)
	{
		android.text.TextPaint paint = new android.text.TextPaint(
			android.graphics.Paint.ANTI_ALIAS_FLAG | android.graphics.Paint.SUBPIXEL_TEXT_FLAG);
		paint.setTypeface(getSymbolsTypeface(fontPath));
		paint.setColor(colorArgb);
		paint.setTextSize(sizePx);
		paint.setTextAlign(android.graphics.Paint.Align.CENTER);

		// Material Symbols is a variable font; 'FILL' selects the filled variant.
		if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O)
		{
			try
			{
				paint.setFontVariationSettings(
					(filled ? "'FILL' 1, 'wght' 400, 'GRAD' 0, 'opsz' " : "'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' ") + sizePx);
			}
			catch (Exception e)
			{
				// Font variations not supported on this device/font; fall back to the default instance.
			}
		}

		android.graphics.Bitmap bitmap = android.graphics.Bitmap.createBitmap(sizePx, sizePx, android.graphics.Bitmap.Config.ARGB_8888);
		android.graphics.Canvas canvas = new android.graphics.Canvas(bitmap);
		float y = (sizePx / 2.0f) - ((paint.descent() + paint.ascent()) / 2.0f);
		canvas.drawText(ligature, sizePx / 2.0f, y, paint);

		return new android.graphics.drawable.BitmapDrawable(
			com.fuse.Activity.getRootActivity().getResources(), bitmap);
	}

	public static android.graphics.drawable.Drawable bitmapDrawable(Object bitmap, int colorArgb)
	{
		if (bitmap == null)
			return null;

		android.graphics.drawable.BitmapDrawable drawable = new android.graphics.drawable.BitmapDrawable(
			com.fuse.Activity.getRootActivity().getResources(), (android.graphics.Bitmap)bitmap);

		if (android.os.Build.VERSION.SDK_INT >= 21)
			drawable.setTint(colorArgb);

		return drawable;
	}
}
