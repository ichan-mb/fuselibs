package com.fuse.controls.nativenavigation;

/** Small helpers shared by the navigation bar and the modal dialog. */
public class NavigationUi
{
	/** The themed height of a navigation bar, in pixels. */
	public static int actionBarHeightPx()
	{
		android.app.Activity activity = com.fuse.Activity.getRootActivity();
		android.util.TypedValue tv = new android.util.TypedValue();
		if (activity.getTheme().resolveAttribute(androidx.appcompat.R.attr.actionBarSize, tv, true))
			return android.util.TypedValue.complexToDimensionPixelSize(tv.data, activity.getResources().getDisplayMetrics());

		return (int)(56 * activity.getResources().getDisplayMetrics().density + 0.5f);
	}

	/** The themed height of a navigation bar, in density-independent points. */
	public static float actionBarHeightPoints()
	{
		float density = com.fuse.Activity.getRootActivity().getResources().getDisplayMetrics().density;
		return actionBarHeightPx() / density;
	}

	/**
	 * System-bar insets from a WindowInsets; falls back to the framework dimension resources when there
	 * are none (the deprecated getters return zero on recent versions).
	 */
	public static android.graphics.Rect systemBars(android.content.Context context, android.view.WindowInsets insets)
	{
		android.graphics.Rect r = new android.graphics.Rect();

		if (insets != null)
		{
			if (android.os.Build.VERSION.SDK_INT >= 30)
			{
				android.graphics.Insets i = insets.getInsets(android.view.WindowInsets.Type.systemBars());
				r.set(i.left, i.top, i.right, i.bottom);
			}
			else
			{
				r.set(
					insets.getSystemWindowInsetLeft(),
					insets.getSystemWindowInsetTop(),
					insets.getSystemWindowInsetRight(),
					insets.getSystemWindowInsetBottom());
			}
			return r;
		}

		if (context != null)
		{
			r.top = dimenPx(context, "status_bar_height");
			r.bottom = dimenPx(context, "navigation_bar_height");
		}
		return r;
	}

	static int dimenPx(android.content.Context context, String name)
	{
		int id = context.getResources().getIdentifier(name, "dimen", "android");
		return id > 0 ? context.getResources().getDimensionPixelSize(id) : 0;
	}

	/**
	 * A toolbar sized from its own window's insets (status bar included) that also lays out the
	 * `Position="Left"` items after the back button.
	 */
	public static class InsetToolbar extends androidx.appcompat.widget.Toolbar
	{
		private final int actionBarPx;
		private final int defaultInsetStart;
		private final int defaultInsetStartWithNavigation;
		private android.view.View leadingItems;

		public InsetToolbar(android.content.Context context, int actionBarPx)
		{
			super(context);
			this.actionBarPx = actionBarPx;
			defaultInsetStart = getContentInsetStart();
			defaultInsetStartWithNavigation = getContentInsetStartWithNavigation();
			setLayoutParams(new android.widget.FrameLayout.LayoutParams(
				android.view.ViewGroup.LayoutParams.MATCH_PARENT, actionBarPx, android.view.Gravity.TOP));
		}

		/**
		 * Sets the `Position="Left"` container (or null to remove it); it is laid out after the navigation
		 * button.
		 */
		public void setLeadingItems(android.view.View view)
		{
			if (leadingItems == view)
				return;

			if (leadingItems != null)
				removeView(leadingItems);

			leadingItems = view;
			if (view != null)
				addView(view, new androidx.appcompat.widget.Toolbar.LayoutParams(
					android.view.ViewGroup.LayoutParams.WRAP_CONTENT,
					android.view.ViewGroup.LayoutParams.WRAP_CONTENT));

			requestLayout();
		}

		@Override
		protected void onLayout(boolean changed, int left, int top, int right, int bottom)
		{
			applyInsets();
			measureLeadingItems();
			reserveLeadingItems();
			super.onLayout(changed, left, top, right, bottom);
			layoutLeadingItems();
		}

		/**
		 * Measures the leading items without a width limit: they are measured against the available width in
		 * `onMeasure`, but their width is what the title's inset is derived from.
		 */
		private void measureLeadingItems()
		{
			if (leadingItems == null)
				return;

			leadingItems.measure(
				android.view.View.MeasureSpec.makeMeasureSpec(0, android.view.View.MeasureSpec.UNSPECIFIED),
				android.view.View.MeasureSpec.makeMeasureSpec(actionBarPx, android.view.View.MeasureSpec.AT_MOST));
		}

		private void applyInsets()
		{
			int top = systemBars(getContext(), getRootWindowInsets()).top;
			int height = actionBarPx + top;

			android.view.ViewGroup.LayoutParams lp = getLayoutParams();
			if (getPaddingTop() == top && lp != null && lp.height == height)
				return;

			if (lp == null)
				lp = new android.widget.FrameLayout.LayoutParams(
					android.view.ViewGroup.LayoutParams.MATCH_PARENT, height, android.view.Gravity.TOP);
			else
				lp.height = height;
			setLayoutParams(lp);
			setPadding(getPaddingLeft(), top, getPaddingRight(), getPaddingBottom());
		}

		/**
		 * Grows the start content inset past the leading items so `super.onLayout` places the title after
		 * them. The setters are guarded because they request a layout, which would loop.
		 */
		private void reserveLeadingItems()
		{
			int reserved;
			if (leadingItems == null)
			{
				reserved = -1;
			}
			else
			{
				reserved = leadingStart() + leadingItems.getMeasuredWidth() + dp(4);
				reserved = Math.max(reserved, Math.max(defaultInsetStart, defaultInsetStartWithNavigation));
			}

			int withNavigation = reserved >= 0 ? reserved : defaultInsetStartWithNavigation;
			if (getContentInsetStartWithNavigation() != withNavigation)
				setContentInsetStartWithNavigation(withNavigation);

			int start = reserved >= 0 ? reserved : defaultInsetStart;
			if (getContentInsetStart() != start)
				setContentInsetsRelative(start, getContentInsetEnd());
		}

		/** Places the leading items directly after the navigation button, vertically centred in the bar. */
		private void layoutLeadingItems()
		{
			if (leadingItems == null)
				return;

			int width = leadingItems.getMeasuredWidth();
			int height = leadingItems.getMeasuredHeight();
			int itemTop = getPaddingTop() + Math.max(0, (actionBarPx - height) / 2);
			int start = leadingStart();

			if (androidx.core.view.ViewCompat.getLayoutDirection(this) == androidx.core.view.ViewCompat.LAYOUT_DIRECTION_RTL)
			{
				int right = getWidth() - start;
				leadingItems.layout(right - width, itemTop, right, itemTop + height);
			}
			else
			{
				leadingItems.layout(start, itemTop, start + width, itemTop + height);
			}
		}

		/** Where the leading items begin: just past the navigation button, if one is shown. */
		private int leadingStart()
		{
			android.view.View nav = navigationButton();
			if (nav == null || nav.getVisibility() == android.view.View.GONE)
				return 0;

			android.view.ViewGroup.MarginLayoutParams lp = (android.view.ViewGroup.MarginLayoutParams) nav.getLayoutParams();
			return nav.getMeasuredWidth() + lp.leftMargin + lp.rightMargin;
		}

		/**
		 * The toolbar's navigation (back) button, created internally from the navigation icon, so it is
		 * identified as the image button among the children.
		 */
		private android.view.View navigationButton()
		{
			for (int i = 0; i < getChildCount(); i++)
			{
				android.view.View child = getChildAt(i);
				if (child instanceof android.widget.ImageButton)
					return child;
			}
			return null;
		}

		private int dp(int value)
		{
			return (int)(value * getResources().getDisplayMetrics().density + 0.5f);
		}
	}

	/** Creates a navigation bar sized and positioned to overlay the content, owning the status-bar area. */
	public static androidx.appcompat.widget.Toolbar createOverlayToolbar(android.content.Context context)
	{
		return new InsetToolbar(context, actionBarHeightPx());
	}
}
