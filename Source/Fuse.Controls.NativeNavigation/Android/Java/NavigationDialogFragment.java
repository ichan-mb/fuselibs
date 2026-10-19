package com.fuse.controls.nativenavigation;

/**
 * A modal dialog hosting a page's view with its own bar; sheet/card styles size the content inside the
 * full-screen window. Dismissal is driven by the shared layer.
 */
public class NavigationDialogFragment extends androidx.fragment.app.DialogFragment
{
	/** Presentation style, mirroring `ModalPresentationStyle` in the Uno layer (see DialogStyle there). */
	public static final int STYLE_FULL_SCREEN = 0;
	public static final int STYLE_PAGE_SHEET = 1;
	public static final int STYLE_FORM_SHEET = 2;
	public static final int STYLE_SHEET = 3;

	private static final int SLIDE_DURATION_MS = 300;
	private static final int SLIDE_OUT_DURATION_MS = 250;

	/** Fraction of the screen a bottom sheet occupies. */
	private static final float SHEET_HEIGHT = 0.55f;
	/** Fractions a card is inset / sized by, as parts of the screen. */
	private static final float CARD_TOP_MARGIN = 0.08f;
	private static final float CARD_SIDE_MARGIN = 0.06f;
	private static final float CARD_HEIGHT = 0.6f;

	/** How much the page behind a sheet or card is dimmed. */
	private static final float SCRIM_ALPHA = 0.4f;

	/** The grabber a draggable card is pulled down by. */
	private static final int GRABBER_STRIP_DP = 16;
	private static final int GRABBER_BAR_WIDTH_DP = 36;
	private static final int GRABBER_BAR_HEIGHT_DP = 4;
	private static final int GRABBER_COLOR = 0x33000000;
	/** A drag past this fraction of the card's height dismisses it. */
	private static final float DISMISS_FRACTION = 0.4f;
	/** A downward fling at least this fast (pixels per second) also dismisses it. */
	private static final float DISMISS_VELOCITY = 1200f;

	private final android.view.View content;
	private final int style;
	private final boolean dragToDismiss;
	/** Whether a sheet can be dragged up to the page sheet's size (see canExpand). */
	private final boolean expandable;
	private android.widget.FrameLayout root;
	private androidx.appcompat.widget.Toolbar toolbar;
	private boolean dismissing;
	private Runnable onLaidOut;
	private Runnable onDismissedByUser;
	/** Runs when the content view's size changes, so the hosted page can follow it. */
	private Runnable onContentSizeChanged;
	/** The size last passed to `onContentSizeChanged`, so only a change is reported. */
	private int reportedWidth = -1;
	private int reportedHeight = -1;
	/** Whether a sheet has been dragged up to the page sheet's size. */
	private boolean expanded;

	public NavigationDialogFragment(android.view.View content)
	{
		this(content, STYLE_FULL_SCREEN, true, true);
	}

	public NavigationDialogFragment(android.view.View content, int style)
	{
		this(content, style, true, true);
	}

	public NavigationDialogFragment(android.view.View content, int style, boolean dragToDismiss, boolean expandable)
	{
		this.content = content;
		this.style = style;
		this.dragToDismiss = dragToDismiss;
		this.expandable = expandable;
	}

	/**
	 * Runs `onLaidOut` once the content has been laid out, so the caller can measure it; runs at most once.
	 */
	public void setOnLaidOut(Runnable runnable)
	{
		onLaidOut = runnable;
	}

	/**
	 * Runs when the content view's size changes, so the hosted page is laid out at it; this changes while
	 * the modal is up (a sheet dragged up to the page sheet's size).
	 */
	public void setOnContentSizeChanged(Runnable runnable)
	{
		onContentSizeChanged = runnable;
	}

	/** The view hosting the presented page, or null before the dialog's view has been created. */
	public android.view.View getContent()
	{
		return content;
	}

	/**
	 * Runs when the user dragged the card down far enough to dismiss it; the caller dismisses through the
	 * shared layer, so the page is released and the navigation state stays in step.
	 */
	public void setOnDismissedByUser(Runnable runnable)
	{
		onDismissedByUser = runnable;
	}

	/**
	 * Whether the user can drag the card down to dismiss it: the sheet styles, and only when the
	 * presentation asked for it.
	 */
	private boolean isDraggable()
	{
		return dragToDismiss && (style == STYLE_PAGE_SHEET || style == STYLE_SHEET);
	}

	/**
	 * Slides the modal back down and dismisses it, reporting through `onDismissed` so the page is not
	 * released while still on screen. `onDismissed` always runs, even without an animation.
	 */
	public void dismissAnimated(final Runnable onDismissed)
	{
		// A second dismissal while one is running must not start a second animation.
		if (dismissing)
			return;
		dismissing = true;

		if (root == null || !isAdded())
		{
			dismissNow(onDismissed);
			return;
		}

		// Continue from where the card is (partway down after a drag); the remaining distance sets the
		// duration, so a dismiss after a drag does not crawl the last part.
		int cardHeight = root.getHeight();
		int duration = SLIDE_OUT_DURATION_MS;
		if (cardHeight > 0)
		{
			float remaining = Math.max(0, cardHeight - root.getTranslationY()) / cardHeight;
			duration = (int)Math.max(80, SLIDE_OUT_DURATION_MS * remaining);
		}

		root.animate()
			.translationY(cardHeight)
			.setDuration(duration)
			.setInterpolator(new android.view.animation.AccelerateInterpolator())
			.withEndAction(new Runnable() { public void run() {
				dismissNow(onDismissed);
			}})
			.start();
	}

	private void dismissNow(Runnable onDismissed)
	{
		dismiss();

		if (onDismissed != null)
			onDismissed.run();
	}

	@Override
	public void onCreate(android.os.Bundle savedInstanceState)
	{
		super.onCreate(savedInstanceState);
		setStyle(androidx.fragment.app.DialogFragment.STYLE_NO_FRAME, 0);
		setCancelable(false);
	}

	@Override
	public android.view.View onCreateView(android.view.LayoutInflater inflater, android.view.ViewGroup container, android.os.Bundle savedInstanceState)
	{
		root = new android.widget.FrameLayout(getContext());
		root.setLayoutParams(new android.widget.FrameLayout.LayoutParams(
			android.view.ViewGroup.LayoutParams.MATCH_PARENT,
			android.view.ViewGroup.LayoutParams.MATCH_PARENT));

		toolbar = NavigationUi.createOverlayToolbar(getContext());

		// The same view may be re-attached after being dismissed and re-presented.
		if (content.getParent() instanceof android.view.ViewGroup)
			((android.view.ViewGroup)content.getParent()).removeView(content);

		content.setLayoutParams(new android.widget.FrameLayout.LayoutParams(
			android.view.ViewGroup.LayoutParams.MATCH_PARENT,
			android.view.ViewGroup.LayoutParams.MATCH_PARENT));
		root.addView(content);

		// Added after the content: the page's surface fills the window (including the bar strip) and would
		// otherwise consume the bar's touches. The bar still draws over that strip.
		root.addView(toolbar);

		// The page follows this view's size, which changes while the modal is up (a sheet dragged up to
		// the page sheet size). Same-size passes are skipped: re-laying out at the same size is waste.
		content.addOnLayoutChangeListener(new android.view.View.OnLayoutChangeListener() {
			public void onLayoutChange(android.view.View view, int left, int top, int right, int bottom,
					int oldLeft, int oldTop, int oldRight, int oldBottom)
			{
				int width = right - left;
				int height = bottom - top;
				if (width == reportedWidth && height == reportedHeight)
					return;

				reportedWidth = width;
				reportedHeight = height;

				if (onContentSizeChanged != null)
					onContentSizeChanged.run();
			}
		});

		// Added last, so the grabber is above the page's transparent surface over the bar strip. Only
		// draggable styles get one: it must not promise a drag that is not there.
		if (isDraggable())
			addGrabber();

		return root;
	}

	/**
	 * Adds the strip the card is dragged by, over the bar (which the page does not draw into). It is a
	 * separate strip because the page consumes touches for its own scrolling.
	 */
	private void addGrabber()
	{
		float density = getResources().getDisplayMetrics().density;
		int strip = (int)(GRABBER_STRIP_DP * density + 0.5f);

		android.widget.FrameLayout handle = new android.widget.FrameLayout(getContext());
		handle.setLayoutParams(new android.widget.FrameLayout.LayoutParams(
			android.view.ViewGroup.LayoutParams.MATCH_PARENT, strip, android.view.Gravity.TOP));

		int width = (int)(GRABBER_BAR_WIDTH_DP * density + 0.5f);
		int height = (int)(GRABBER_BAR_HEIGHT_DP * density + 0.5f);

		android.graphics.drawable.GradientDrawable bar = new android.graphics.drawable.GradientDrawable();
		bar.setShape(android.graphics.drawable.GradientDrawable.RECTANGLE);
		bar.setColor(GRABBER_COLOR);
		bar.setCornerRadius(height / 2.0f);

		android.view.View barView = new android.view.View(getContext());
		barView.setBackground(bar);
		barView.setLayoutParams(new android.widget.FrameLayout.LayoutParams(
			width, height, android.view.Gravity.CENTER));
		handle.addView(barView);

		root.addView(handle);

		handle.setOnTouchListener(new DragCard());
	}

	/** Whether the card can be dragged up to the page sheet's size: an expandable sheet. */
	private boolean canExpand()
	{
		return expandable && style == STYLE_SHEET;
	}

	/**
	 * Gives the card the page sheet's size (`true`), or its own size back, animating to either. Does
	 * nothing for a card with only one size.
	 */
	public void setExpanded(boolean value, boolean animated)
	{
		if (!canExpand())
			return;

		expanded = value;

		int target = value ? expandedTopMargin() : restingTopMargin();
		if (animated)
			animateTopMargin(target);
		else
			setTopMargin(target);
	}

	/** The height of the area a card is placed in: the display less the system bars. */
	private int availableHeight()
	{
		android.util.DisplayMetrics metrics = getResources().getDisplayMetrics();
		android.graphics.Rect system = NavigationUi.systemBars(getContext(), null);
		return metrics.heightPixels - system.top - system.bottom;
	}

	/** The top margin of the card at rest: the sheet's, which is what applyPresentationStyle gives it. */
	private int restingTopMargin()
	{
		return (int)(availableHeight() * (1 - SHEET_HEIGHT));
	}

	/** The top margin of the card enlarged: the page sheet's, which reaches the bottom of the area. */
	private int expandedTopMargin()
	{
		return (int)(availableHeight() * CARD_TOP_MARGIN);
	}

	private int currentTopMargin()
	{
		android.view.ViewGroup.LayoutParams lp = root != null ? root.getLayoutParams() : null;
		if (!(lp instanceof android.widget.FrameLayout.LayoutParams))
			return 0;
		return ((android.widget.FrameLayout.LayoutParams)lp).topMargin;
	}

	/** Moves the card's top edge, resizing it (and the page it hosts, once the size is reported). */
	private void setTopMargin(int topMargin)
	{
		android.view.ViewGroup.LayoutParams lp = root != null ? root.getLayoutParams() : null;
		if (!(lp instanceof android.widget.FrameLayout.LayoutParams))
			return;

		if (((android.widget.FrameLayout.LayoutParams)lp).topMargin == topMargin)
			return;

		((android.widget.FrameLayout.LayoutParams)lp).topMargin = topMargin;
		root.setLayoutParams(lp);
	}

	/** Animates the card's top edge to `target` after a resize is released rather than dragged. */
	private void animateTopMargin(final int target)
	{
		int from = currentTopMargin();
		if (from == target)
		{
			setTopMargin(target);
			return;
		}

		android.animation.ValueAnimator animator = android.animation.ValueAnimator.ofInt(from, target);
		animator.setDuration(SLIDE_DURATION_MS);
		animator.setInterpolator(new android.view.animation.DecelerateInterpolator());
		animator.addUpdateListener(new android.animation.ValueAnimator.AnimatorUpdateListener() {
			public void onAnimationUpdate(android.animation.ValueAnimator animation)
			{
				setTopMargin(((Integer)animation.getAnimatedValue()).intValue());
			}
		});
		animator.start();
	}

	/**
	 * Drags the card with the finger: up to enlarge it, down to restore its resting size or dismiss it.
	 */
	private class DragCard implements android.view.View.OnTouchListener
	{
		private float startY;
		/** The card's top margin when the drag began, which is what a drag up or down is measured from. */
		private int startMargin;
		private android.view.VelocityTracker velocity;
		/** Whether this drag is changing the card's size rather than moving it down to dismiss it. */
		private boolean resizing;

		public boolean onTouch(android.view.View view, android.view.MotionEvent e)
		{
			if (root == null)
				return false;

			switch (e.getActionMasked())
			{
				case android.view.MotionEvent.ACTION_DOWN:
					// The card moves with the finger, so a position relative to the view would too; raw Y does not.
					startY = e.getRawY();
					startMargin = currentTopMargin();
					resizing = false;
					velocity = android.view.VelocityTracker.obtain();
					return true;

				case android.view.MotionEvent.ACTION_MOVE:
					if (velocity != null)
						velocity.addMovement(e);

					float dy = e.getRawY() - startY;

					// A drag up from rest enlarges the card; a drag down from the enlarged size restores it.
					// From rest, a drag down moves the whole card instead, to dismiss it.
					if (canExpand() && (expanded || dy < 0f))
					{
						resizing = true;
						int enlarged = expandedTopMargin();
						int resting = restingTopMargin();
						setTopMargin(Math.max(enlarged, Math.min(resting, startMargin + (int)dy)));
					}
					else
					{
						root.setTranslationY(Math.max(0f, dy));
					}
					return true;

				case android.view.MotionEvent.ACTION_UP:
				case android.view.MotionEvent.ACTION_CANCEL:
					float fling = 0f;
					if (velocity != null)
					{
						velocity.computeCurrentVelocity(1000);
						fling = velocity.getYVelocity();
						velocity.recycle();
						velocity = null;
					}

					boolean released = e.getActionMasked() == android.view.MotionEvent.ACTION_UP;

					if (resizing)
						settleSize(released, fling);
					else
						settleDismiss(released, fling);

					resizing = false;
					return true;
			}

			return false;
		}

		/**
		 * Gives the card whichever of its two sizes it was dragged closer to. A fling settles it outright.
		 */
		private void settleSize(boolean released, float fling)
		{
			int enlarged = expandedTopMargin();
			int resting = restingTopMargin();

			boolean wantExpanded;
			if (released && fling < -DISMISS_VELOCITY)
				wantExpanded = true;
			else if (released && fling > DISMISS_VELOCITY)
				wantExpanded = false;
			else
			{
				int current = currentTopMargin();
				wantExpanded = current - enlarged < resting - current;
			}

			expanded = wantExpanded;
			animateTopMargin(wantExpanded ? enlarged : resting);
		}

		/** Dismisses the card if dragged far enough or flicked, and springs it back otherwise. */
		private void settleDismiss(boolean released, float fling)
		{
			boolean dismiss = released
				&& (root.getTranslationY() > root.getHeight() * DISMISS_FRACTION || fling > DISMISS_VELOCITY);

			if (dismiss)
			{
				// Through the shared layer, so the page is released and state stays in step. The card keeps
				// sliding from where the finger left it.
				if (onDismissedByUser != null)
					onDismissedByUser.run();
				else
					dismissAnimated(null);
			}
			else
			{
				root.animate()
					.translationY(0f)
					.setDuration(SLIDE_DURATION_MS)
					.setInterpolator(new android.view.animation.DecelerateInterpolator())
					.start();
			}
		}
	}

	@Override
	public void onStart()
	{
		super.onStart();

		android.app.Dialog dialog = getDialog();
		if (dialog == null)
			return;

		android.view.Window w = dialog.getWindow();
		if (w == null)
			return;

		// Full-screen, undimmed and frameless for every style: a scrim covers only the window's own frame,
		// so the sheet/card styles inset the content within it (see applyPresentationStyle).
		w.setLayout(android.view.ViewGroup.LayoutParams.MATCH_PARENT, android.view.ViewGroup.LayoutParams.MATCH_PARENT);
		w.setBackgroundDrawable(new android.graphics.drawable.ColorDrawable(android.graphics.Color.TRANSPARENT));
		w.setDimAmount(0.0f);

		// A card or sheet follows the content's size, so let the window resize for the keyboard and the page
		// re-lays out. A full-screen dialog keeps the app frame and pans the focused field into view instead.
		if (style != STYLE_FULL_SCREEN)
			w.setSoftInputMode(android.view.WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);

		// Keep focus on the main window: taking it away makes Fuse deactivate its input, so the page
		// underneath would need an extra tap after dismissal. Touches still reach the dialog.
		w.addFlags(android.view.WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE);

		applyPresentationStyle(w);

		// Slide the whole modal up from the bottom once it has been laid out.
		if (root != null)
		{
			root.post(new Runnable() { public void run() {
				if (root == null)
					return;

				// Report the content's size before animating, while the modal is still off-screen.
				if (onLaidOut != null)
				{
					Runnable r = onLaidOut;
					onLaidOut = null;
					r.run();
				}

				root.setTranslationY(root.getHeight());
				root.animate()
					.translationY(0f)
					.setDuration(SLIDE_DURATION_MS)
					.setInterpolator(new android.view.animation.DecelerateInterpolator())
					.start();
			} });
		}
	}

	/**
	 * Turns on the scrim and insets the content to the card's position for the requested style.
	 * Android has no modal styles of its own, so sheets/cards are the full-screen content made smaller.
	 */
	private void applyPresentationStyle(android.view.Window w)
	{
		if (style == STYLE_FULL_SCREEN)
			return;

		// Let the page behind show through, dimmed. The flag is needed: the amount alone does nothing.
		w.addFlags(android.view.WindowManager.LayoutParams.FLAG_DIM_BEHIND);
		w.setDimAmount(SCRIM_ALPHA);

		if (root == null)
			return;

		android.util.DisplayMetrics metrics = getResources().getDisplayMetrics();

		// The window is the display less the system bars, so size the card against that (a WindowInsets
		// object is not available here yet, hence the dimension resources).
		android.graphics.Rect system = NavigationUi.systemBars(getContext(), null);
		int availableWidth = metrics.widthPixels - system.left - system.right;
		int availableHeight = availableHeight();

		android.widget.FrameLayout.LayoutParams lp = new android.widget.FrameLayout.LayoutParams(
			android.view.ViewGroup.LayoutParams.MATCH_PARENT,
			android.view.ViewGroup.LayoutParams.MATCH_PARENT);

		switch (style)
		{
			case STYLE_PAGE_SHEET:
				// A card inset from the top, reaching the bottom of the area (as a UIKit page sheet does).
				lp.topMargin = (int)(availableHeight * CARD_TOP_MARGIN);
				setCardBackground(true);
				break;

			case STYLE_FORM_SHEET:
				// A smaller card, centred.
				lp.topMargin = (int)(availableHeight * (1 - CARD_HEIGHT) / 2);
				lp.bottomMargin = lp.topMargin;
				lp.leftMargin = (int)(availableWidth * CARD_SIDE_MARGIN);
				lp.rightMargin = lp.leftMargin;
				setCardBackground(false);
				break;

			case STYLE_SHEET:
				// A panel covering the lower part of the area; it can be dragged up to the page sheet's size.
				lp.topMargin = restingTopMargin();
				setCardBackground(true);
				break;
		}

		root.setLayoutParams(lp);
	}

	/**
	 * Rounds the modal's corners, clipping the page to them where the render surface supports an outline
	 * (a SurfaceView is composited outside the view hierarchy).
	 */
	private void setCardBackground(boolean topOnly)
	{
		if (root == null)
			return;

		float radius = 16 * getResources().getDisplayMetrics().density;
		android.graphics.drawable.GradientDrawable background = new android.graphics.drawable.GradientDrawable();
		background.setShape(android.graphics.drawable.GradientDrawable.RECTANGLE);
		background.setColor(android.graphics.Color.WHITE);
		if (topOnly)
			background.setCornerRadii(new float[] { radius, radius, radius, radius, 0, 0, 0, 0 });
		else
			background.setCornerRadius(radius);

		root.setBackground(background);
		root.setClipToOutline(true);
	}

	public androidx.appcompat.widget.Toolbar getToolbar()
	{
		return toolbar;
	}

	@Override
	public void onDestroyView()
	{
		if (root != null)
			root.removeView(content);

		root = null;
		toolbar = null;
		super.onDestroyView();
	}
}
