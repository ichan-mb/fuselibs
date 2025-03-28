using Uno;
using Uno.UX;
using Uno.Platform.iOS;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Controls.Native.iOS
{
	extern(!iOS) public class ScrollView
	{
		[UXConstructor]
		public ScrollView([UXParameter("Host")]IScrollViewHost host) { }
	}

	[Require("source.include", "iOS/Helpers.h")]
	[Require("source.include", "UIKit/UIKit.h")]
	[Require("source.include", "CoreGraphics/CoreGraphics.h")]
	extern(iOS) public class ScrollView : View, IScrollView
	{
		readonly ObjC.Object _delegateHandle;
		IScrollViewHost _host;

		ScrollDirections _scrollDirection;
		public ScrollDirections AllowedScrollDirections
		{
			set { _scrollDirection = value; }
		}

		public bool UserScroll
		{
			set { SetUserScroll(Handle, value); }
		}

		bool _snapMinTransform;
		public bool SnapMinTransform
		{
			set { _snapMinTransform = value; }
		}

		bool _snapMaxTransform;
		public bool SnapMaxTransform
		{
			set { _snapMaxTransform = value; }
		}

		[Foreign(Language.ObjC)]
		static void SetUserScroll(ObjC.Object handle, bool isScroll)
		@{
			::UIScrollView* scrollView = (::UIScrollView*)handle;
			scrollView.scrollEnabled = isScroll;
		@}

		public float2 ScrollPosition
		{
			set { SetContentOffset(Handle, value.X, value.Y, false); }
		}

		public float2 Goto
		{
			set { SetContentOffset(Handle, value.X, value.Y, true); }
		}

		float _snapInterval = 0;
		public float SnapInterval
		{
			set { _snapInterval = value; }
		}

		int _snapAlignment = -1;
		public SnapAlign SnapAlignment
		{
			set { _snapAlignment = value == SnapAlign.Start ? 0 : value == SnapAlign.Center ? 1 : 2; }
		}

		int _decelerationRate = 0;
		public DecelerationType DecelerationRate
		{
			set
			{
				_decelerationRate = value == DecelerationType.Fast ? 1 : 0;
				SetDecelerationRate(Handle, _decelerationRate);
			}
		}

		[UXConstructor]
		public ScrollView([UXParameter("Host")]IScrollViewHost host) : base(Create())
		{
			_host = host;
			_delegateHandle = AddCallback(Handle, OnScrollViewDidScroll, OnInteractionChanged, OnWillEndDragging);
		}

		public override void Dispose()
		{
			_host = null;
			base.Dispose();
		}

		[Foreign(Language.ObjC)]
		static ObjC.Object Create()
		@{
			::UIScrollView* scrollView = [[::UIScrollView alloc] init];
			[scrollView setMultipleTouchEnabled:true];
			[scrollView setOpaque:true];
			scrollView.showsHorizontalScrollIndicator = false;
			scrollView.showsVerticalScrollIndicator = false;
			return  scrollView;
		@}

		[Foreign(Language.ObjC)]
		static void SetDecelerationRate(ObjC.Object handle, int decelerationRate)
		@{
			::UIScrollView* scrollView = (::UIScrollView*)handle;
			if (decelerationRate == 1)
				scrollView.decelerationRate = UIScrollViewDecelerationRateFast;
			else
				scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object AddCallback(ObjC.Object handle, Action<ObjC.Object> callback, Action<bool> interactingCallback, Action<ObjC.Object, uCGPoint, IntPtr> scrollViewWillEndDraggingCallback)
		@{
			ScrollViewDelegate* del = [[ScrollViewDelegate alloc] init];
			[del setDidScrollCallback: callback];
			[del setDidInteractinglCallback: interactingCallback];
			[del setWillEndDraggingCallback: scrollViewWillEndDraggingCallback];
			::UIScrollView* scrollView =  (::UIScrollView*)handle;
			[scrollView setDelegate:del];
			return del;
		@}

		void OnScrollViewDidScroll(ObjC.Object scrollViewHandle)
		{
			float x = 0.0f;
			float y = 0.0f;
			GetContentOffset(Handle, out x, out y);
			_host.OnScrollPositionChanged(float2(x, y));
			if (!_snapMinTransform)
				SetDisableBounceStart(Handle, _scrollDirection == ScrollDirections.Horizontal);
			if (!_snapMaxTransform)
				SetDisableBounceEnd(Handle, _scrollDirection == ScrollDirections.Horizontal);
		}

		void OnInteractionChanged(bool isInteracting)
		{
			_host.OnInteractionChanged(isInteracting);
		}

		void OnWillEndDragging(ObjC.Object scrollViewHandle, uCGPoint velocity, IntPtr targetContentOffset)
		{
			if (_snapInterval > 0)
			{
				bool isHorizontal = _scrollDirection == ScrollDirections.Horizontal;
				var vel = CGPointToUnoFloat2(velocity);
				var velocityAxis = isHorizontal ? vel.X : vel.Y;
				var targetContentOffsetAxis = GetTargetContentOffsetY(targetContentOffset);
				if (isHorizontal)
					targetContentOffsetAxis = GetTargetContentOffsetX(targetContentOffset);
				// Pick snap point based on direction and proximity
				var fractionalIndex = targetContentOffsetAxis / _snapInterval;

				var snapIndex = velocityAxis > 0.0 ? Math.Ceil(fractionalIndex) : velocityAxis < 0.0 ? Math.Floor(fractionalIndex) : Math.Round(fractionalIndex);
				var newTargetContentOffset = snapIndex * _snapInterval;

				// Set new targetContentOffset
				if (isHorizontal)
					SetTargetContentOffsetX(targetContentOffset, newTargetContentOffset);
				else
					SetTargetContentOffsetY(targetContentOffset, newTargetContentOffset);
			}
		}

		[Foreign(Language.ObjC)]
		static extern float2 CGPointToUnoFloat2(uCGPoint point)
		@{
			@{Uno.Float2} unoPoint;
			unoPoint.X = point.x;
			unoPoint.Y = point.y;
			return unoPoint;
		@}

		[Foreign(Language.ObjC)]
		static float GetTargetContentOffsetX(IntPtr targetContentOffset)
		@{
			CGPoint* point = (CGPoint*)targetContentOffset;
			return point->x;
		@}

		[Foreign(Language.ObjC)]
		static float GetTargetContentOffsetY(IntPtr targetContentOffset)
		@{
			CGPoint* point = (CGPoint*)targetContentOffset;
			return point->y;
		@}

		[Foreign(Language.ObjC)]
		static void SetTargetContentOffsetX(IntPtr targetContentOffset, float value)
		@{
			CGPoint* point = (CGPoint*)targetContentOffset;
			point->x = value;
		@}

		[Foreign(Language.ObjC)]
		static void SetTargetContentOffsetY(IntPtr targetContentOffset, float value)
		@{
			CGPoint* point = (CGPoint*)targetContentOffset;
			point->y = value;
		@}

		internal protected override void OnSizeChanged()
		{
			var contentSize = _host.ContentSize;
			SetContentSize(Handle, contentSize.X, contentSize.Y);
		}

		[Foreign(Language.ObjC)]
		static void SetDisableBounceStart(ObjC.Object handle, bool isHorizontal)
		@{
			::UIScrollView* scrollView = (::UIScrollView*)handle;
			if (isHorizontal)
			{
				if (scrollView.contentOffset.x < 0) {
					scrollView.contentOffset = CGPointMake(0, scrollView.contentOffset.y);
				}
			}
			else
			{
				if (scrollView.contentOffset.y < 0) {
					scrollView.contentOffset = CGPointMake(scrollView.contentOffset.x, 0);
				}
			}
		@}

		[Foreign(Language.ObjC)]
		static void SetDisableBounceEnd(ObjC.Object handle, bool isHorizontal)
		@{
			::UIScrollView* scrollView = (::UIScrollView*)handle;
			if (isHorizontal)
			{
				CGFloat rightOffset = scrollView.contentSize.width - scrollView.bounds.size.width;
				if (rightOffset > 0 && scrollView.contentOffset.x > rightOffset) {
					scrollView.contentOffset = CGPointMake(rightOffset, scrollView.contentOffset.y);
				}
			}
			else
			{
				CGFloat bottomOffset = scrollView.contentSize.height - scrollView.bounds.size.height;
				if (scrollView.contentOffset.y > bottomOffset) {
					scrollView.contentOffset = CGPointMake(scrollView.contentOffset.x, bottomOffset);
				}
			}
		@}

		[Foreign(Language.ObjC)]
		static void SetContentOffset(ObjC.Object handle, float x, float y, bool animated)
		@{
			::UIScrollView* scrollView = (::UIScrollView*)handle;
			CGPoint p = { 0 };
			p.x = (CGFloat)x;
			p.y = (CGFloat)y;
			[scrollView setContentOffset:p animated:animated];
		@}

		[Foreign(Language.ObjC)]
		static void GetContentOffset(ObjC.Object handle, out float x, out float y)
		@{
			::UIScrollView* scrollView = (::UIScrollView*)handle;
			CGPoint offset = [scrollView contentOffset];
			*x = offset.x;
			*y = offset.y;
		@}

		[Foreign(Language.ObjC)]
		static void SetContentSize(ObjC.Object handle, float w, float h)
		@{
			::UIScrollView* scrollView = (::UIScrollView*)handle;
			CGSize size = { 0 };
			size.width = (CGFloat)w;
			size.height = (CGFloat)h;
			[scrollView setContentSize:size];
		@}

		[Foreign(Language.ObjC)]
		static void GetContentSize(ObjC.Object handle, out float w, out float h)
		@{
			::UIScrollView* scrollView = (::UIScrollView*)handle;
			CGSize size = [scrollView contentSize];
			*w = (float)size.width;
			*h = (float)size.height;
		@}

	}
}