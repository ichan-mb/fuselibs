package com.fuse.controls.nativenavigation;

/**
 * The leading (left) side of the navigation bar: androidx Toolbar only lays its menu out on the right,
 * so these are built as plain buttons and laid out after the back button (see InsetToolbar).
 */
public class LeadingToolbarItems extends android.widget.LinearLayout
{
	private final float density;

	public LeadingToolbarItems(android.content.Context context)
	{
		super(context);
		density = context.getResources().getDisplayMetrics().density;
		setOrientation(HORIZONTAL);
		setGravity(android.view.Gravity.CENTER_VERTICAL);
	}

	/**
	 * Adds one item and returns its view (its id is the toolbar item id), so the caller can attach a
	 * click listener. `icon` may be null.
	 */
	public android.view.View addItem(int id, String title, boolean enabled, android.graphics.drawable.Drawable icon, int textColorArgb)
	{
		// A TextView is what appcompat uses for an action item, so the typography matches; a Button would
		// also force all-caps on some themes.
		androidx.appcompat.widget.AppCompatTextView button = new androidx.appcompat.widget.AppCompatTextView(getContext());
		button.setId(id);
		applyActionTextAppearance(button);
		button.setText(title == null ? "" : title);
		button.setTextColor(textColorArgb);
		button.setGravity(android.view.Gravity.CENTER);
		button.setSingleLine(true);
		button.setEllipsize(android.text.TextUtils.TruncateAt.END);
		button.setMinimumWidth(dp(48));
		button.setMinimumHeight(dp(48));
		button.setPadding(dp(12), 0, dp(12), 0);
		button.setBackgroundResource(selectableItemBackgroundBorderless(getContext()));
		if (icon != null)
		{
			button.setCompoundDrawablesRelativeWithIntrinsicBounds(icon, null, null, null);
			button.setCompoundDrawablePadding(dp(4));
		}
		button.setEnabled(enabled);
		addView(button);
		return button;
	}

	/** Uses the bar's action-menu text appearance, so a leading item matches the trailing menu items. */
	private void applyActionTextAppearance(android.widget.TextView view)
	{
		android.util.TypedValue value = new android.util.TypedValue();
		if (getContext().getTheme().resolveAttribute(androidx.appcompat.R.attr.actionMenuTextAppearance, value, true))
			androidx.core.widget.TextViewCompat.setTextAppearance(view, value.resourceId);
	}

	private int dp(int value)
	{
		return (int)(value * density + 0.5f);
	}

	/** The borderless ripple used by toolbar buttons, or 0 (no background) when the theme has none. */
	static int selectableItemBackgroundBorderless(android.content.Context context)
	{
		android.util.TypedValue value = new android.util.TypedValue();
		if (context.getTheme().resolveAttribute(androidx.appcompat.R.attr.selectableItemBackgroundBorderless, value, true))
			return value.resourceId;
		return 0;
	}
}
