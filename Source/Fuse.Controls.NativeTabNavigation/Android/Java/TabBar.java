package com.fuse.controls.nativetabnavigation;

/**
 * The bottom tab bar: one item per tab, each an icon (a Material Symbols ligature, when the tab has one)
 * above its title. Normal tabs share the bar's width; `Pinned`/`Search` items sit at the trailing edge,
 * and the search item is drawn as a round, elevated button.
 */
public class TabBar extends android.widget.LinearLayout
{
	public interface Listener
	{
		void onTabSelected(int index);
	}

	static class Item
	{
		android.widget.LinearLayout root;
		android.widget.FrameLayout iconHolder;
		android.widget.TextView icon;
		android.widget.TextView label;
		android.widget.TextView badge;
		String title;
		String accessibilityLabel;
		boolean enabled = true;
		boolean hasColor;
		int color;
		boolean hasSelectedColor;
		int selectedColor;
		int placement = PLACEMENT_AUTOMATIC;
	}

	private static final int BAR_HEIGHT_DP = 56;

	/**
		The bar's height in pixels. Larger font scales need more room for the labels; without this the
		label would be clipped at the bottom of the bar.
	*/
	public static int barHeight(android.content.Context context)
	{
		float density = context.getResources().getDisplayMetrics().density;
		float fontScale = context.getResources().getConfiguration().fontScale;
		float extraDp = Math.max(0f, (fontScale - 1f) * LABEL_SIZE_SP * 1.4f);
		return (int)((BAR_HEIGHT_DP + extraDp) * density + 0.5f);
	}

	// Placement values from Fuse.Controls.TabPlacement, matching UIKit's UITabPlacement. Android
	// renders every value except these as a normal tab.
	static final int PLACEMENT_AUTOMATIC = 0;
	static final int PLACEMENT_PINNED = 4;
	static final int PLACEMENT_SIDEBAR_ONLY = 6;
	static final int PLACEMENT_SEARCH = 7;

	/** Width of a pinned (separate) item, which does not share the bar's width with the others. */
	private static final int PINNED_WIDTH_DP = 64;
	private static final int SEPARATED_GAP_DP = 8;
	/** The search item is a round, elevated button (a FAB-like trailing action). */
	private static final int SEARCH_SIZE_DP = 48;
	private static final int SEARCH_ELEVATION_DP = 4;
	private static final int ICON_SIZE_DP = 24;
	private static final int LABEL_SIZE_SP = 11;

	/** Keeps the search item's elevation shadow round instead of following a rectangle. */
	private static final android.view.ViewOutlineProvider SEARCH_OUTLINE_PROVIDER =
		new android.view.ViewOutlineProvider()
		{
			@Override
			public void getOutline(android.view.View view, android.graphics.Outline outline)
			{
				outline.setOval(0, 0, view.getWidth(), view.getHeight());
			}
		};

	private final java.util.ArrayList<Item> items = new java.util.ArrayList<Item>();
	/** The normal tabs, taking the width that the pinned items do not use. */
	private final android.widget.LinearLayout normalGroup;
	private final String fontPath;
	private final float density;
	private int tint = 0xFF6B7280;
	private int selectedTint = 0xFF007AFF;
	private int pillColor = 0x14000000;
	private int searchColor = 0xFFF2F2F7;
	private int rippleColor = 0x1F000000;
	private int selected = -1;
	private int labelMode = 0; // 0 always, 1 selected, 2 never
	private Listener listener;
	private android.graphics.Typeface symbolsTypeface;

	public TabBar(android.content.Context context, String fontPath)
	{
		super(context);
		this.fontPath = fontPath;
		density = context.getResources().getDisplayMetrics().density;

		setOrientation(HORIZONTAL);
		setBackgroundColor(0xFFFFFFFF);

		normalGroup = new android.widget.LinearLayout(context);
		normalGroup.setOrientation(HORIZONTAL);
		normalGroup.setLayoutParams(new android.widget.LinearLayout.LayoutParams(
			0, android.view.ViewGroup.LayoutParams.MATCH_PARENT, 1f));
		addView(normalGroup);
	}

	public void setListener(Listener listener)
	{
		this.listener = listener;
	}

	public void setColors(int backgroundArgb, int tintArgb, int selectedTintArgb)
	{
		setBackgroundColor(backgroundArgb);
		tint = tintArgb;
		selectedTint = selectedTintArgb;

		// The pinned pill and the search button must contrast with the bar: on a light bar they are a
		// dark overlay, on a dark bar a light one.
		float luminance = 0.299f * ((backgroundArgb >> 16) & 0xFF) / 255f
			+ 0.587f * ((backgroundArgb >> 8) & 0xFF) / 255f
			+ 0.114f * (backgroundArgb & 0xFF) / 255f;
		pillColor = luminance < 0.5f ? 0x1FFFFFFF : 0x14000000;
		searchColor = luminance < 0.5f
			? blend(backgroundArgb, 0xFFFFFFFF, 0.12f)
			: blend(backgroundArgb, 0x000000, 0.06f);
		rippleColor = luminance < 0.5f ? 0x33FFFFFF : 0x1F000000;

		for (int i = 0; i < items.size(); i++)
		{
			Item item = items.get(i);
			if (item.placement == PLACEMENT_SEARCH)
				item.root.setBackground(searchBackground());
			else if (item.placement == PLACEMENT_PINNED)
				item.root.setBackground(pillBackground());
		}

		applyColors();
	}

	/** Mixes `overlay` into `base` by `amount` (0..1) and returns an opaque ARGB colour. */
	private static int blend(int base, int overlay, float amount)
	{
		int r = Math.round(((base >> 16) & 0xFF) * (1 - amount) + ((overlay >> 16) & 0xFF) * amount);
		int g = Math.round(((base >> 8) & 0xFF) * (1 - amount) + ((overlay >> 8) & 0xFF) * amount);
		int b = Math.round((base & 0xFF) * (1 - amount) + (overlay & 0xFF) * amount);
		return 0xFF000000 | (r << 16) | (g << 8) | b;
	}

	/** Adds a tab and returns its index. `ligature` may be null or empty for a title-only tab. */
	public int addItem(String title, String ligature, boolean filled, String accessibilityLabel, int placement)
	{
		final int index = items.size();

		Item item = new Item();
		item.root = new android.widget.LinearLayout(getContext());
		item.root.setOrientation(VERTICAL);
		item.root.setGravity(android.view.Gravity.CENTER);
		item.root.setPadding(dp(2), dp(4), dp(2), dp(4));
		item.root.setClipChildren(false);
		item.root.setClipToPadding(false);
		item.root.setFocusable(true);
		item.root.setOnClickListener(new android.view.View.OnClickListener() {
			public void onClick(android.view.View v)
			{
				if (listener != null && item.enabled)
					listener.onTabSelected(index);
			}
		});

		item.iconHolder = new android.widget.FrameLayout(getContext());
		item.iconHolder.setClipChildren(false);
		item.iconHolder.setClipToPadding(false);
		// Room at the icon's top-right for the badge; it overlaps the icon slightly.
		item.iconHolder.setLayoutParams(new android.widget.LinearLayout.LayoutParams(
			dp(ICON_SIZE_DP + 12), dp(ICON_SIZE_DP + 4)));

		item.icon = new android.widget.TextView(getContext());
		item.icon.setLayoutParams(new android.widget.FrameLayout.LayoutParams(
			android.view.ViewGroup.LayoutParams.WRAP_CONTENT, android.view.ViewGroup.LayoutParams.WRAP_CONTENT,
			android.view.Gravity.CENTER));
		item.icon.setTextSize(android.util.TypedValue.COMPLEX_UNIT_DIP, ICON_SIZE_DP);
		item.icon.setGravity(android.view.Gravity.CENTER);
		item.icon.setSingleLine(true);
		item.icon.setIncludeFontPadding(false);

		item.label = new android.widget.TextView(getContext());
		item.label.setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, LABEL_SIZE_SP);
		item.label.setGravity(android.view.Gravity.CENTER);
		item.label.setSingleLine(true);
		item.label.setIncludeFontPadding(false);
		item.label.setEllipsize(android.text.TextUtils.TruncateAt.END);

		item.badge = new android.widget.TextView(getContext());
		item.badge.setGravity(android.view.Gravity.CENTER);
		item.badge.setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, 10);
		item.badge.setIncludeFontPadding(false);
		item.badge.setSingleLine(true);
		item.badge.setVisibility(android.view.View.GONE);
		android.widget.FrameLayout.LayoutParams badgeParams = new android.widget.FrameLayout.LayoutParams(
			android.view.ViewGroup.LayoutParams.WRAP_CONTENT, android.view.ViewGroup.LayoutParams.WRAP_CONTENT,
			android.view.Gravity.TOP | android.view.Gravity.END);
		item.badge.setLayoutParams(badgeParams);

		item.iconHolder.addView(item.icon);
		item.iconHolder.addView(item.badge);

		item.root.addView(item.iconHolder);
		item.root.addView(item.label);

		item.placement = placement;
		items.add(item);
		addItemView(item);

		setItem(index, title, ligature, filled, accessibilityLabel);
		return index;
	}

	public void setItem(int index, String title, String ligature, boolean filled, String accessibilityLabel)
	{
		if (index < 0 || index >= items.size())
			return;

		Item item = items.get(index);
		boolean hasIcon = ligature != null && ligature.length() > 0 && getSymbolsTypeface() != null;

		item.icon.setVisibility(hasIcon ? android.view.View.VISIBLE : android.view.View.GONE);
		if (hasIcon)
		{
			item.icon.setTypeface(getSymbolsTypeface());
			item.icon.setText(ligature);
			// Material Symbols is a variable font; 'FILL' selects the filled variant.
			if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O)
			{
				try
				{
					item.icon.setFontVariationSettings(filled
						? "'FILL' 1, 'wght' 400, 'GRAD' 0, 'opsz' 24"
						: "'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 24");
				}
				catch (Exception e)
				{
					// Variation settings are best-effort; the outline glyph still renders.
				}
			}
		}

		item.title = title;
		item.accessibilityLabel = accessibilityLabel;
		item.label.setText(title == null ? "" : title);
		applyLabelVisibility();

		updateContentDescription(item);
		applyColors();
	}

	/** Sets the badge; null hides it, an empty string shows a dot. */
	public void setBadge(int index, String text, int backgroundArgb, int foregroundArgb)
	{
		if (index < 0 || index >= items.size())
			return;

		Item item = items.get(index);
		if (text == null)
		{
			item.badge.setVisibility(android.view.View.GONE);
			updateContentDescription(item);
			return;
		}

		boolean dot = text.length() == 0;
		int size = dp(dot ? 8 : 16);

		android.graphics.drawable.GradientDrawable background = new android.graphics.drawable.GradientDrawable();
		background.setShape(android.graphics.drawable.GradientDrawable.RECTANGLE);
		background.setColor(backgroundArgb);
		background.setCornerRadius(size / 2.0f);

		item.badge.setText(dot ? "" : text);
		item.badge.setTextColor(foregroundArgb);
		item.badge.setBackground(background);
		item.badge.setMinWidth(size);
		item.badge.setMinHeight(size);
		item.badge.setPadding(dot ? 0 : dp(4), dp(1), dot ? 0 : dp(4), dp(1));
		item.badge.setVisibility(android.view.View.VISIBLE);
		updateContentDescription(item);
	}

	private void updateContentDescription(Item item)
	{
		String label = item.accessibilityLabel != null && item.accessibilityLabel.length() > 0
			? item.accessibilityLabel
			: item.title;

		if (item.badge.getVisibility() == android.view.View.VISIBLE)
		{
			String badge = item.badge.getText() != null ? item.badge.getText().toString() : "";
			String suffix = badge.length() > 0 ? badge : "new";
			label = (label == null || label.length() == 0) ? suffix : label + ", " + suffix;
		}

		if (label != null && label.length() > 0)
			item.root.setContentDescription(label);
		else
			item.root.setContentDescription(null);
	}

	public void setItemEnabled(int index, boolean enabled)
	{
		if (index < 0 || index >= items.size())
			return;

		Item item = items.get(index);
		item.enabled = enabled;
		item.root.setEnabled(enabled);
		item.root.setAlpha(enabled ? 1.0f : 0.4f);
	}

	public void removeItem(int index)
	{
		if (index < 0 || index >= items.size())
			return;

		Item item = items.get(index);
		android.view.ViewParent parent = item.root.getParent();
		if (parent instanceof android.view.ViewGroup)
			((android.view.ViewGroup)parent).removeView(item.root);
		items.remove(index);

		if (selected == index)
			selected = -1;
		else if (selected > index)
			selected--;

		applyColors();
	}

	/** Moves an item between the normal group and the trailing (pinned) position. */
	public void setItemPlacement(int index, int placement)
	{
		if (index < 0 || index >= items.size())
			return;

		Item item = items.get(index);
		if (item.placement == placement)
			return;

		android.view.ViewParent parent = item.root.getParent();
		if (parent instanceof android.view.ViewGroup)
			((android.view.ViewGroup)parent).removeView(item.root);

		item.placement = placement;
		addItemView(item);
		applyColors();
		applyLabelVisibility();
	}

	/** Adds an item's view to the bar, styled for its placement. */
	private void addItemView(Item item)
	{
		boolean search = item.placement == PLACEMENT_SEARCH;
		boolean pinned = item.placement == PLACEMENT_PINNED;
		boolean detached = search || pinned || item.placement == PLACEMENT_SIDEBAR_ONLY;

		if (detached)
		{
			android.widget.LinearLayout.LayoutParams lp = search
				? new android.widget.LinearLayout.LayoutParams(dp(SEARCH_SIZE_DP), dp(SEARCH_SIZE_DP))
				: new android.widget.LinearLayout.LayoutParams(
					dp(PINNED_WIDTH_DP), android.view.ViewGroup.LayoutParams.MATCH_PARENT);

			if (search)
			{
				lp.setMarginStart(dp(SEPARATED_GAP_DP));
				lp.setMarginEnd(dp(SEPARATED_GAP_DP));
				lp.gravity = android.view.Gravity.CENTER_VERTICAL;
				item.root.setOutlineProvider(SEARCH_OUTLINE_PROVIDER);
				item.root.setBackground(searchBackground());
				item.root.setElevation(dp(SEARCH_ELEVATION_DP));
			}
			else if (pinned)
			{
				lp.setMarginStart(dp(SEPARATED_GAP_DP));
				item.root.setBackground(pillBackground());
				item.root.setElevation(0);
			}
			else
			{
				item.root.setBackgroundResource(selectableItemBackgroundBorderless(getContext()));
				item.root.setElevation(0);
			}

			if (!search)
				item.root.setOutlineProvider(null);

			item.root.setVisibility(item.placement == PLACEMENT_SIDEBAR_ONLY
				? android.view.View.GONE : android.view.View.VISIBLE);
			addView(item.root, lp);
		}
		else
		{
			item.root.setOutlineProvider(null);
			item.root.setElevation(0);
			item.root.setBackgroundResource(selectableItemBackgroundBorderless(getContext()));
			item.root.setVisibility(android.view.View.VISIBLE);
			normalGroup.addView(item.root, new android.widget.LinearLayout.LayoutParams(
				0, android.view.ViewGroup.LayoutParams.MATCH_PARENT, 1f));
		}
	}

	private android.graphics.drawable.GradientDrawable pillBackground()
	{
		android.graphics.drawable.GradientDrawable background =
			new android.graphics.drawable.GradientDrawable();
		background.setShape(android.graphics.drawable.GradientDrawable.RECTANGLE);
		background.setColor(pillColor);
		background.setCornerRadius(dp(16));
		return background;
	}

	/** The round, elevated background of the search item. */
	private android.graphics.drawable.Drawable searchBackground()
	{
		android.graphics.drawable.GradientDrawable fill = new android.graphics.drawable.GradientDrawable();
		fill.setShape(android.graphics.drawable.GradientDrawable.OVAL);
		fill.setColor(searchColor);

		android.graphics.drawable.GradientDrawable mask = new android.graphics.drawable.GradientDrawable();
		mask.setShape(android.graphics.drawable.GradientDrawable.OVAL);
		mask.setColor(0xFFFFFFFF);

		return new android.graphics.drawable.RippleDrawable(
			android.content.res.ColorStateList.valueOf(rippleColor), fill, mask);
	}

	public void setItemColors(int index, boolean hasColor, int colorArgb,
		boolean hasSelectedColor, int selectedColorArgb)
	{
		if (index < 0 || index >= items.size())
			return;

		Item item = items.get(index);
		item.hasColor = hasColor;
		item.color = colorArgb;
		item.hasSelectedColor = hasSelectedColor;
		item.selectedColor = selectedColorArgb;
		applyColors();
	}

	public void setLabelVisibility(int mode)
	{
		labelMode = mode;
		applyLabelVisibility();
	}

	private void applyLabelVisibility()
	{
		for (int i = 0; i < items.size(); i++)
		{
			Item item = items.get(i);
			boolean hasText = item.title != null && item.title.length() > 0;

			// The search item is an icon-only round button, like iOS's prominent search tab.
			if (item.placement == PLACEMENT_SEARCH || !hasText)
			{
				item.label.setVisibility(android.view.View.GONE);
				continue;
			}

			if (labelMode == 0)
				item.label.setVisibility(android.view.View.VISIBLE);
			else if (labelMode == 1)
			{
				// Keep the unselected label's space so the icons do not shift when selection changes.
				item.label.setVisibility(i == selected
					? android.view.View.VISIBLE : android.view.View.INVISIBLE);
			}
			else
				item.label.setVisibility(android.view.View.GONE);
		}
	}

	public void setSelected(int index)
	{
		selected = index;
		applyColors();
		applyLabelVisibility();
	}

	private void applyColors()
	{
		for (int i = 0; i < items.size(); i++)
		{
			Item item = items.get(i);
			int normal = item.hasColor ? item.color : tint;
			int selectedColor = item.hasSelectedColor ? item.selectedColor : selectedTint;
			int color = i == selected ? selectedColor : normal;
			item.icon.setTextColor(color);
			item.label.setTextColor(color);
			// Accessibility: TalkBack announces the selected tab from this state.
			item.root.setSelected(i == selected);
		}
	}

	private android.graphics.Typeface getSymbolsTypeface()
	{
		if (symbolsTypeface == null && fontPath != null)
		{
			try
			{
				symbolsTypeface = android.graphics.Typeface.createFromAsset(
					com.fuse.Activity.getRootActivity().getAssets(), fontPath);
			}
			catch (Exception e)
			{
				android.util.Log.e("FuseTabNavigation", "Failed to load Material Symbols font: " + e.getMessage());
			}
		}
		return symbolsTypeface;
	}

	private int dp(int value)
	{
		return (int)(value * density + 0.5f);
	}

	/** The system navigation-bar inset at the bottom, or a dimension-resource fallback. */
	public static int bottomInset(android.content.Context context, android.view.View view)
	{
		android.view.WindowInsets insets = view != null ? view.getRootWindowInsets() : null;
		if (insets != null)
		{
			if (android.os.Build.VERSION.SDK_INT >= 30)
				return insets.getInsets(android.view.WindowInsets.Type.navigationBars()).bottom;
			return insets.getSystemWindowInsetBottom();
		}

		int id = context.getResources().getIdentifier("navigation_bar_height", "dimen", "android");
		return id > 0 ? context.getResources().getDimensionPixelSize(id) : 0;
	}

	static int selectableItemBackgroundBorderless(android.content.Context context)
	{
		android.util.TypedValue value = new android.util.TypedValue();
		if (context.getTheme().resolveAttribute(
			androidx.appcompat.R.attr.selectableItemBackgroundBorderless, value, true))
			return value.resourceId;
		return 0;
	}
}
