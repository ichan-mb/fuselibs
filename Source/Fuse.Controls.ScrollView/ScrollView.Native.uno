using Uno;
using Uno.Collections;
using Fuse.Elements;
using Fuse.Controls.Native;

namespace Fuse.Controls
{
	public partial class ScrollViewBase
	{
		IScrollView NativeScrollView
		{
			get { return _nativeScrollView != null ? _nativeScrollView : NativeView as IScrollView; }
		}

		// The native scroll view is a template part, not necessarily this control's own native view.
		IScrollView _nativeScrollView;

		void IScrollViewHost.SetScrollView(IScrollView scrollView)
		{
			_nativeScrollView = scrollView;

			// A new native view starts with no content size, so the next push must not be skipped.
			_hasNativeContentSize = false;
		}

		float IScrollViewHost.PixelsPerPoint
		{
			get { return Viewport.PixelsPerPoint; }
		}

		void IScrollViewHost.OnScrollPositionChanged(float2 newScrollPosition)
		{
			SetScrollPosition(newScrollPosition, null);
		}

		void IScrollViewHost.OnInteractionChanged(bool isInteracting)
		{
			if (isInteracting)
				BeginInteraction(_interactionId, OnCancelInteraction);
			else
				EndInteraction(_interactionId);
		}

		void OnCancelInteraction()
		{
			EndInteraction(_interactionId);
		}

		float2 IScrollViewHost.ContentSize
		{
			get
			{
				if (Element == null)
					return float2(0);

				// What `MaxScroll` is built from: the content's margin box, its position and this control's
				// padding. The painted size alone leaves the margins past the end, so the last part of the
				// content could only be reached while bouncing. The non-scrolling axis stays at the viewport.
				var extent = ContentMarginSize + Element.ActualPosition + Padding.XY + Padding.ZW;
				var scroll = ConstrainExtents(extent - ActualSize);
				return float2(Math.Max(scroll.X, 0.0f), Math.Max(scroll.Y, 0.0f)) + ActualSize;
			}
		}

		float2 _lastNativeContentSize;
		bool _hasNativeContentSize;

		/** Pushes the content size to the native scroll view (a no-op where it measures its child). */
		internal void UpdateNativeContentSize()
		{
			var nsv = NativeScrollView;
			if (nsv == null)
				return;

			var size = ((IScrollViewHost)this).ContentSize;
			if (_hasNativeContentSize && size == _lastNativeContentSize)
				return;

			_lastNativeContentSize = size;
			_hasNativeContentSize = true;
			nsv.UpdateContentSize();
		}

		internal sealed override void CompensateForScrollView(ref float4x4 t)
		{
			t.M41 = t.M41 + ScrollPosition.X;
			t.M42 = t.M42 + ScrollPosition.Y;
		}

		protected override void PushPropertiesToNativeView()
		{
			base.PushPropertiesToNativeView();
			UpdateNativeScrollViewParam();
		}

		private void UpdateNativeScrollViewParam()
		{
			var nsv = NativeScrollView;
			if (nsv != null)
			{
				nsv.AllowedScrollDirections = AllowedScrollDirections;
				nsv.UserScroll = UserScroll;
				nsv.SnapMinTransform = SnapMinTransform;
				nsv.SnapMaxTransform = SnapMaxTransform;
			}
		}
	}
}
