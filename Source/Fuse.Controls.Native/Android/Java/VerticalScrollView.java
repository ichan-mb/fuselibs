package com.fuse.android.views;

import java.lang.reflect.Field;
import android.os.Build;
import android.widget.ScrollView;
import android.widget.OverScroller;
import android.animation.ObjectAnimator;
import android.animation.ValueAnimator;
import android.content.Context;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.MotionEvent;
import android.view.View;
import android.view.animation.Interpolator;

import androidx.annotation.NonNull;

public class VerticalScrollView extends ScrollView {

	private static final int MAX_Y_OVERSCROLL_DISTANCE = 50;
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
	private int mMaxYOverscrollDistance;
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

	public VerticalScrollView(Context context) {
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
					VerticalScrollView.this.postDelayed(scrollerTask, newCheck);
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
				sScrollerField = ScrollView.class.getDeclaredField("mScroller");
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

	private void initBounceScrollView(Context context) {
		final DisplayMetrics metrics = context.getResources().getDisplayMetrics();
		final float density = metrics.density;
		this.mMaxYOverscrollDistance = (int) (density * MAX_Y_OVERSCROLL_DISTANCE);
	}

	private int getMaxScrollY() {
		return this.getChildAt(0).getHeight();
	}

	private int predictFinalScrollPosition(int velocityY) {
		OverScroller scroller = new OverScroller(this.getContext());
		if (this.decelerationRate == 1)
			scroller.setFriction(1 - com.fuse.android.views.FuseScrollView.DECELERATION_RATE_FAST);
		else
			scroller.setFriction(1 - com.fuse.android.views.FuseScrollView.DECELERATION_RATE_NORMAL);
		int width = this.getWidth() - this.getPaddingStart() - this.getPaddingEnd();
		int height = this.getHeight() - this.getPaddingBottom() - this.getPaddingTop();
		scroller.fling(getScrollX(), getScrollY(), 0, velocityY, 0, 0, 0, getMaxScrollY(), width / 2, height / 2);
		return scroller.getFinalY();
	}

	private void flingAndSnap(int velocityY) {
		if (getChildCount() <= 0) {
			return;
		}

		int maximumOffset = getMaxScrollY();
		int targetOffset = predictFinalScrollPosition(velocityY);
		double ratio = (double) targetOffset / _snapInterval;

		int smallerOffset = (int) (Math.floor(ratio) * _snapInterval);
		int largerOffset = (int) (Math.ceil(ratio) * _snapInterval);
		int nearestOffset = (int) (Math.round(ratio) * _snapInterval);

		if (velocityY > 0) {
			velocityY += (int) ((largerOffset - targetOffset) * 10.0);
			targetOffset = largerOffset;
		} else if (velocityY < 0) {
			velocityY -= (int) ((targetOffset - smallerOffset) * 10.0);
			targetOffset = smallerOffset;
		} else {
			targetOffset = nearestOffset;
		}
		// Make sure the new offset isn't out of bounds
		targetOffset = Math.min(Math.max(0, targetOffset), maximumOffset);
		mScroller.fling(getScrollX(), getScrollY(), 0, velocityY != 0 ? velocityY : targetOffset - getScrollY(), 0, 0, targetOffset, targetOffset, 0, 0 );
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
	public void fling(int velocityY) {
		if (_snapInterval > 0) {
			flingAndSnap(velocityY);
		} else {
			super.fling(velocityY);
		}
	}

	@Override
	protected boolean overScrollBy(int deltaX, int deltaY, int scrollX, int scrollY,
									int scrollRangeX, int scrollRangeY,
									int maxOverScrollX, int maxOverScrollY,
									boolean isTouchEvent) {
		int offset = mChildView.getMeasuredHeight() - getHeight();
		offset = Math.max(offset, 0);
		int overScrollDistance = mMaxYOverscrollDistance;
		if (deltaY < 0 && scrollY == 0 && mDisableBounceStart)
			overScrollDistance = 0;
		else if (deltaY > 0 && scrollY == offset && mDisableBounceEnd)
			overScrollDistance = 0;
		return super.overScrollBy(deltaX, deltaY, scrollX, scrollY,
									scrollRangeX, scrollRangeY,
									maxOverScrollX, overScrollDistance,
									isTouchEvent);
	}

	@Override
	public boolean onInterceptTouchEvent(MotionEvent ev) {
		if (this.mChildView == null && getChildCount() > 0 || mChildView != getChildAt(0)) {
			this.mChildView = getChildAt(0);
		}
		return super.onInterceptTouchEvent(ev) && isVerticalScroll(ev);
	}

	private boolean isVerticalScroll(MotionEvent ev) {
		try {
			return Math.abs(ev.getX() - ev.getHistoricalX(0)) < Math.abs(ev.getY() - ev.getHistoricalY(0));
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
				this.mStart = ev.getY();

				break;
			case MotionEvent.ACTION_MOVE:
				float now, delta;
				int dampingDelta;

				now = ev.getY();
				delta = mStart - now;
				dampingDelta = (int) (delta / calculateDamping());
				this.mStart = now;

				if (canMove(dampingDelta)) {
					this.mOverScrolledDistance += dampingDelta;
					this.mChildView.setTranslationY(-this.mOverScrolledDistance);
					if (this.mOverScrollListener != null) {
						this.mOverScrollListener.onOverScrolling(this.mOverScrolledDistance <= 0, Math.abs(this.mOverScrolledDistance));
					}
				}

				break;
			case MotionEvent.ACTION_UP:
			case MotionEvent.ACTION_CANCEL:
				this.mOverScrolledDistance = 0;

				cancelAnimator();
				this.mAnimator = ObjectAnimator.ofFloat(mChildView, View.TRANSLATION_Y, 0);
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
				VerticalScrollView.this.postDelayed(scrollerTask, newCheck);

				break;
		}

		return isVerticalScroll(ev) && super.onTouchEvent(ev);
	}

	private float calculateDamping() {
		float ratio;
		ratio = Math.abs(mChildView.getTranslationY()) / mChildView.getMeasuredHeight();
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
		return getScrollY() == 0 && !isDisableBounceStart();
	}

	private boolean canMoveFromEnd() {
		int offset = mChildView.getMeasuredHeight() - getHeight();
		offset = Math.max(offset, 0);
		return getScrollY() == offset && !isDisableBounceEnd();
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

	public void draw(android.graphics.Canvas canvas)
	{
		boolean clipChildren = getClipChildren();
		if (clipChildren)
		{
			int x = getScrollX();
			int y = getScrollY();
			int w = getWidth() + x;
			int h = getHeight() + y;
			android.graphics.Rect rect = new android.graphics.Rect(x, y, w, h);
			canvas.clipRect(rect);
		}
		super.draw(canvas);
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