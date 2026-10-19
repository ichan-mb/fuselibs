package com.fuse.controls.nativenavigation;

/**
 * Hosts a Fuse page's native view in a Fragment so it takes part in the back stack; the view outlives
 * the fragment view, so it is detached on destroy and re-attached on create.
 */
public class FuseNavigationFragment extends androidx.fragment.app.Fragment
{
	private final android.view.View content;
	private final java.lang.Runnable onExited;

	public FuseNavigationFragment(android.view.View content)
	{
		this(content, null);
	}

	/**
	 * @param onExited invoked when this fragment's view finishes its exiting transition (may be null).
	 */
	public FuseNavigationFragment(android.view.View content, java.lang.Runnable onExited)
	{
		this.content = content;
		this.onExited = onExited;
	}

	@Override
	public android.view.View onCreateView(android.view.LayoutInflater inflater, android.view.ViewGroup container, android.os.Bundle savedInstanceState)
	{
		android.widget.FrameLayout wrapper = new android.widget.FrameLayout(container.getContext());
		wrapper.setLayoutParams(new android.view.ViewGroup.LayoutParams(
			android.view.ViewGroup.LayoutParams.MATCH_PARENT,
			android.view.ViewGroup.LayoutParams.MATCH_PARENT));

		// The same view may be re-attached after a back-stack pop, so detach it from its parent first.
		if (content.getParent() instanceof android.view.ViewGroup)
			((android.view.ViewGroup)content.getParent()).removeView(content);

		content.setLayoutParams(new android.widget.FrameLayout.LayoutParams(
			android.view.ViewGroup.LayoutParams.MATCH_PARENT,
			android.view.ViewGroup.LayoutParams.MATCH_PARENT));
		wrapper.addView(content);

		return wrapper;
	}

	/**
	 * FragmentAnim loads a transition's animator through here, so this observes the exact end of the
	 * exit animation without changing how it looks.
	 */
	@Override
	public android.animation.Animator onCreateAnimator(int transit, boolean enter, int nextAnim)
	{
		android.animation.Animator animator = null;
		if (nextAnim != 0)
			animator = android.animation.AnimatorInflater.loadAnimator(getContext(), nextAnim);

		if (animator != null && !enter && onExited != null)
		{
			animator.addListener(new android.animation.AnimatorListenerAdapter() {
				@Override
				public void onAnimationEnd(android.animation.Animator animation)
				{
					onExited.run();
				}
			});
		}

		return animator;
	}

	@Override
	public void onDestroyView()
	{
		android.view.View wrapper = getView();
		if (wrapper instanceof android.view.ViewGroup)
			((android.view.ViewGroup)wrapper).removeView(content);

		super.onDestroyView();
	}
}
