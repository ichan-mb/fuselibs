package com.fuse.android.views;

import java.lang.reflect.Field;
import android.os.Build;
import android.widget.OverScroller;
import android.animation.ObjectAnimator;
import android.animation.ValueAnimator;
import android.content.Context;
import android.util.DisplayMetrics;
import android.view.MotionEvent;
import android.view.View;
import android.view.animation.Interpolator;

import androidx.annotation.NonNull;

public class HorizontalScrollView extends android.widget.HorizontalScrollView {

	private static final int MAX_X_OVERSCROLL_DISTANCE = 50;
	private static final float DEFAULT_DAMPING_COEFFICIENT = 4.0f;
	private static final long DEFAULT_BOUNCE_DELAY = 400;

	private float mDamping;
	private boolean mIncrementalDamping;
	private long mBounceDelay;
	private boolean mDisableBounceStart;
	private boolean mDisableBounceEnd;

	private final Interpolator mInterpolator;
	private View mChildView;
	private float mStart;
    private int mOverScrolledDistance;
	private ObjectAnimator mAnimator;
	private FuseScrollView.OnOverScrollListener mOverScrollListener;
	private int mMaxXOverscrollDistance;
	private final OverScroller mScroller;
	private float _snapInterval;
	private int _snapAlignment;

	private static Field sScrollerField;
	private static boolean sTriedToGetScrollerField = false;
	private Runnable scrollerTask;
	private int initialPosition;
	private int newCheck = 100;
	private boolean alreadySnap = false;
	private int decelerationRate;

	public HorizontalScrollView(android.content.Context context) {
		super(context);
		this.mDamping = DEFAULT_DAMPING_COEFFICIENT;
		this.mIncrementalDamping = true;
		this.mBounceDelay = DEFAULT_BOUNCE_DELAY;

		this.setVerticalScrollBarEnabled(false);
		this.setHorizontalScrollBarEnabled(false);
		this.setFillViewport(true);
		mScroller = getOverScrollerFromParent();

		this.mInterpolator = new FuseScrollView.DefaultQuartOutInterpolator();
		initBounceScrollView(context);

		scrollerTask = new Runnable() {
			public void run() {

				int newPosition = getScrollY();
				if(initialPosition - newPosition == 0){ //has stopped
					onScrollStopped();
				}else{
					initialPosition = getScrollY();
					HorizontalScrollView.this.postDelayed(scrollerTask, newCheck);
				}
			}
		};
	}

	public void setSnapInterval(float interval) {
		DisplayMetrics metrics = getContext().getResources().getDisplayMetrics();
		float dpi = metrics.density;
		this._snapInterval = interval * dpi;
	}

	public void setSnapAlignment(int alignment) {
		this._snapAlignment = alignment;
	}

	public void setDecelerationRate(int decelerationRate) {
		this.decelerationRate = decelerationRate;
		if (decelerationRate == 1)
			mScroller.setFriction(1 - com.fuse.android.views.FuseScrollView.DECELERATION_RATE_FAST);
		else
			mScroller.setFriction(1 - com.fuse.android.views.FuseScrollView.DECELERATION_RATE_NORMAL);
	}

	private OverScroller getOverScrollerFromParent() {
		OverScroller scroller;

		if (!sTriedToGetScrollerField) {
			sTriedToGetScrollerField = true;
			try {
				sScrollerField = android.widget.HorizontalScrollView.class.getDeclaredField("mScroller");
				sScrollerField.setAccessible(true);
			} catch (NoSuchFieldException e) {
			}
		}

		if (sScrollerField != null) {
			try {
			Object scrollerValue = sScrollerField.get(this);
			if (scrollerValue instanceof OverScroller) {
				scroller = (OverScroller) scrollerValue;
			} else {
				scroller = null;
			}
			} catch (IllegalAccessException e) {
				throw new RuntimeException("Failed to get mScroller from ScrollView!", e);
			}
		} else {
			scroller = null;
		}

		return scroller;
	}

	private int getMaxScrollX() {
		return this.getChildAt(0).getWidth();
	}

	private int predictFinalScrollPosition(int velocityX) {
		OverScroller scroller = new OverScroller(this.getContext());
		if (this.decelerationRate == 1)
			scroller.setFriction(1 - com.fuse.android.views.FuseScrollView.DECELERATION_RATE_FAST);
		else
			scroller.setFriction(1 - com.fuse.android.views.FuseScrollView.DECELERATION_RATE_NORMAL);
		int width = this.getWidth() - this.getPaddingStart() - this.getPaddingEnd();
		int height = this.getHeight() - this.getPaddingBottom() - this.getPaddingTop();
		scroller.fling(getScrollX(), getScrollY(), 0, velocityX, 0, getMaxScrollX(), 0, 0, width / 2, height / 2);
		return scroller.getFinalX();
	}

	private void flingAndSnap(int velocityX) {
		if (getChildCount() <= 0) {
			return;
		}

		int maximumOffset = getMaxScrollX();
		int targetOffset = predictFinalScrollPosition(velocityX);
		double ratio = (double) targetOffset / _snapInterval;

		int smallerOffset = (int) (Math.floor(ratio) * _snapInterval);
		int largerOffset = (int) (Math.ceil(ratio) * _snapInterval);
		int nearestOffset = (int) (Math.round(ratio) * _snapInterval);

		if (velocityX > 0) {
			velocityX += (int) ((largerOffset - targetOffset) * 10.0);
			targetOffset = largerOffset;
		} else if (velocityX < 0) {
			velocityX -= (int) ((targetOffset - smallerOffset) * 10.0);
			targetOffset = smallerOffset;
		} else {
			targetOffset = nearestOffset;
		}
		// Make sure the new offset isn't out of bounds
		targetOffset = Math.min(Math.max(0, targetOffset), maximumOffset);
		mScroller.fling(getScrollX(), getScrollY(), velocityX != 0 ? velocityX : targetOffset - getScrollX(), 0, targetOffset, targetOffset, 0, 0, 0, 0 );
		alreadySnap = true;
		postInvalidateOnAnimation();
	}

	void onScrollStopped() {
		if (_snapInterval > 0 && !alreadySnap) {
			flingAndSnap(0);
		}
		alreadySnap = false;
	}

	@Override
	public void fling(int velocityX) {
		if (_snapInterval > 0) {
			flingAndSnap(velocityX);
		} else {
			super.fling(velocityX);
		}
	}

	private void initBounceScrollView(Context context) {
		final DisplayMetrics metrics = context.getResources().getDisplayMetrics();
		final float density = metrics.density;
		this.mMaxXOverscrollDistance = (int) (density * MAX_X_OVERSCROLL_DISTANCE);
	}

	@Override
	protected boolean overScrollBy(int deltaX, int deltaY, int scrollX, int scrollY,
									int scrollRangeX, int scrollRangeY,
									int maxOverScrollX, int maxOverScrollY,
									boolean isTouchEvent) {
		int offset = mChildView.getMeasuredWidth() - getWidth();
		offset = Math.max(offset, 0);
		int overScrollDistance = mMaxXOverscrollDistance;
		if (deltaX < 0 && scrollX == 0 && mDisableBounceStart)
			overScrollDistance = 0;
		else if (deltaX > 0 && scrollX == offset && mDisableBounceEnd)
			overScrollDistance = 0;
		return super.overScrollBy(deltaX, deltaY, scrollX, scrollY,
									scrollRangeX, scrollRangeY,
									overScrollDistance, maxOverScrollY,
									isTouchEvent);
	}

	@Override
	public boolean onInterceptTouchEvent(MotionEvent ev) {
		if (this.mChildView == null && getChildCount() > 0 || mChildView != getChildAt(0)) {
			this.mChildView = getChildAt(0);
		}
		return super.onInterceptTouchEvent(ev) && isHorizontalScroll(ev);
	}

	private boolean isHorizontalScroll(MotionEvent ev) {
		try {
			return Math.abs(ev.getX() - ev.getHistoricalX(0)) > Math.abs(ev.getY() - ev.getHistoricalY(0));
		} catch (IllegalArgumentException e) {
			return true;
		}
	}

	@Override
	public boolean onTouchEvent(MotionEvent ev) {
		if (this.mChildView == null)
			return super.onTouchEvent(ev);

		switch (ev.getActionMasked()) {
			case MotionEvent.ACTION_DOWN:
				this.mStart = ev.getX();

				break;
			case MotionEvent.ACTION_MOVE:
				float now, delta;
				int dampingDelta;

				now = ev.getX();
				delta = mStart - now;
				dampingDelta = (int) (delta / calculateDamping());
				this.mStart = now;

                if (canMove(dampingDelta)) {
					this.mOverScrolledDistance += dampingDelta;
					this.mChildView.setTranslationX(-this.mOverScrolledDistance);
					if (this.mOverScrollListener != null) {
						this.mOverScrollListener.onOverScrolling(this.mOverScrolledDistance <= 0, Math.abs(this.mOverScrolledDistance));
					}
				}

				break;
			case MotionEvent.ACTION_UP:
			case MotionEvent.ACTION_CANCEL:
                this.mOverScrolledDistance = 0;

				cancelAnimator();
				this.mAnimator = ObjectAnimator.ofFloat(mChildView, View.TRANSLATION_X, 0);
				this.mAnimator.setDuration(mBounceDelay).setInterpolator(mInterpolator);
				if (this.mOverScrollListener != null) {
					this.mAnimator.addUpdateListener(new ValueAnimator.AnimatorUpdateListener() {
						@Override
						public void onAnimationUpdate(@NonNull ValueAnimator animation) {
							float value = (float) animation.getAnimatedValue();
							mOverScrollListener.onOverScrolling(value <= 0, Math.abs((int) value));
						}
					});
				}
				this.mAnimator.start();

				initialPosition = getScrollY();
				HorizontalScrollView.this.postDelayed(scrollerTask, newCheck);

				break;
		}

		return isHorizontalScroll(ev) && super.onTouchEvent(ev);
	}

	private float calculateDamping() {
		float ratio;
		ratio = Math.abs(mChildView.getTranslationX()) / mChildView.getMeasuredHeight();
		ratio += 0.2F;
		if (this.mIncrementalDamping) {
			return this.mDamping / (1.0f - (float) Math.pow(ratio, 2));
		} else {
			return this.mDamping;
		}
	}

	private boolean canMove(int delta) {
		return delta < 0 ? canMoveFromStart() : canMoveFromEnd();
	}

	private boolean canMoveFromStart() {
		return getScrollX() == 0 && !isDisableBounceStart();
	}

	private boolean canMoveFromEnd() {
		int offset = mChildView.getMeasuredWidth() - getWidth();
		offset = Math.max(offset, 0);
		return getScrollX() == offset && !isDisableBounceEnd();
	}

	private void cancelAnimator() {
		if (this.mAnimator != null && this.mAnimator.isRunning()) {
			this.mAnimator.cancel();
		}
	}

	ScrollEventHandler _scrollEventHandler;

	public void setScrollEventHandler(ScrollEventHandler scrollEventhandler) {
		_scrollEventHandler = scrollEventhandler;
	}

	protected void onScrollChanged(int l, int t, int oldl, int oldt) {
		if (_scrollEventHandler != null) {
			_scrollEventHandler.onScrollChanged(l, t, oldl, oldt);
		}
		super.onScrollChanged(l, t, oldl, oldt);
	}

	public boolean isDisableBounceStart() {
		return mDisableBounceStart;
	}

	public void setDisableBounceStart(boolean disableBounceStart) {
		this.mDisableBounceStart = disableBounceStart;
	}

	public boolean isDisableBounceEnd() {
		return mDisableBounceEnd;
	}

	public void setDisableBounceEnd(boolean disableBounceEnd) {
		this.mDisableBounceEnd = disableBounceEnd;
	}
}
