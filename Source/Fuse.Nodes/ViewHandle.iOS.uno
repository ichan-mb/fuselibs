using Uno;
using Uno.Collections;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Controls.Native
{


	[Require("source.include", "UIKit/UIKit.h")]
	[Require("source.include", "iOS/Helpers.h")]
	[Require("source.include", "iOS/CanvasViewGroup.h")]
	[Require("source.include", "CoreGraphics/CoreGraphics.h")]
	[Require("source.include", "QuartzCore/QuartzCore.h")]
	[Require("source.include", "CoreImage/CoreImage.h")]
	extern(iOS) public class ViewHandle : IDisposable
	{
		public enum InputMode
		{
			Automatic,
			Manual
		}

		public enum Invalidation
		{
			None,
			OnInvalidateVisual,
		}

		public readonly ObjC.Object NativeHandle;

		internal readonly bool IsLeafView;
		internal readonly bool NeedsInvalidation;

		internal bool NeedsRenderBounds;

		readonly InputMode _inputMode;

		public ViewHandle(ObjC.Object nativeHandle, InputMode inputMode = InputMode.Automatic) : this(nativeHandle, false, inputMode) { }

		public ViewHandle(ObjC.Object nativeHandle, bool isLeafView, InputMode inputMode = InputMode.Automatic, Invalidation invalidation = Invalidation.None)
		{
			NativeHandle = nativeHandle;
			IsLeafView = isLeafView;
			NeedsInvalidation = invalidation == Invalidation.OnInvalidateVisual;
			_inputMode = inputMode;
			InitAnchorPoint();
			IsEnabled = true;
			HitTestEnabled = true;
		}

		public override string ToString()
		{
			return "Fuse.Controls.Native.ViewHandle(" + Format() + ")";
		}

		public virtual void Dispose()
		{
			blurView = null;
			originalBlurImage = null;
		}

		internal bool HandlesInput
		{
			get { return _inputMode == InputMode.Manual; }
		}

		float2 _position = float2(0.0f);
		float2 _size = float2(0.0f);
		internal protected float2 Position
		{
			get { return _position; }
			private set
			{
				_position = value;
				OnPositionChanged();
			}
		}
		internal protected float2 Size
		{
			get { return _size; }
			private set
			{
				_size = value;
				OnSizeChanged();
			}
		}

		public virtual ObjC.Object HitTestHandle
		{
			get { return GetHitTesthandle(); }
		}

		ObjC.Object blurView;
		ObjC.Object originalBlurImage;

		[Foreign(Language.ObjC)]
		public void ApplyBlurEffect(float radius)
		@{
			UIView* view = (UIView*)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()};
			UIImageView* imageView = Nil;
			for (UIView *subview in view.subviews) {
				if ([subview isKindOfClass:[UIImageView class]] && subview.tag != 1001) {
					imageView = (UIImageView*)subview;
					break;
				}
			}
			if (imageView != Nil) {
				CIContext *context = [CIContext contextWithOptions:nil];
				CIImage *inputImage = [[CIImage alloc] initWithImage:imageView.image];

				CIFilter *blurFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
				[blurFilter setValue:inputImage forKey:kCIInputImageKey];
				[blurFilter setValue:[NSNumber numberWithFloat:radius] forKey:kCIInputRadiusKey];

				CIImage *outputImage = [blurFilter outputImage];
				CGImageRef cgImage = [context createCGImage:outputImage fromRect:[inputImage extent]];

				UIImage *blurredImage = [UIImage imageWithCGImage:cgImage];
				CGImageRelease(cgImage);

				imageView.image = blurredImage;
			} else {
				if (radius == 0.0f)
				{
					UIView *blurView = [view viewWithTag:1001];
					if (blurView) {
						[blurView removeFromSuperview];
						blurView = nil;
						@{Fuse.Controls.Native.ViewHandle:of(_this).blurView:set(Nil)};
					}
					@{Fuse.Controls.Native.ViewHandle:of(_this).originalBlurImage:set(Nil)};
					return;
				}

				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

					UIImage *image = (UIImage*)@{Fuse.Controls.Native.ViewHandle:of(_this).originalBlurImage:get()};

					if (image == Nil)
					{
						if (view.frame.size.width == 0 && view.frame.size.height == 0)
							return;

						UIGraphicsBeginImageContextWithOptions(view.frame.size, NO, [UIScreen mainScreen].scale);
						[view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];
						image = UIGraphicsGetImageFromCurrentImageContext();
						UIGraphicsEndImageContext();

						if (!image) return;

						@{Fuse.Controls.Native.ViewHandle:of(_this).originalBlurImage:set(image)};
					}

					CIImage *ciImage = [[CIImage alloc] initWithImage:image];
					CIFilter *filter = [CIFilter filterWithName:@"CIGaussianBlur"];
					if (!filter) return;

					[filter setValue:ciImage forKey:kCIInputImageKey];
					[filter setValue:[NSNumber numberWithFloat:radius] forKey:kCIInputRadiusKey];

					CIImage *outputImage = filter.outputImage;
					if (!outputImage) return;

					CIContext *ciContext = [CIContext contextWithOptions:nil];
					CGImageRef cgImage = [ciContext createCGImage:outputImage
													fromRect:[outputImage extent]];
					if (!cgImage) return;

					UIImage *blurredImage = [UIImage imageWithCGImage:cgImage];
					CGImageRelease(cgImage);

					UIImageView *blurView = (UIImageView *)@{Fuse.Controls.Native.ViewHandle:of(_this).blurView:get()};
					if (blurView != Nil)
					{
						blurView.image = blurredImage;
						if (blurView.superview == Nil)
							[view addSubview:blurView];
					} else {
						blurView = [[UIImageView alloc] initWithImage:blurredImage];
						blurView.tag = 1001;
						[view addSubview:blurView];
						@{Fuse.Controls.Native.ViewHandle:of(_this).blurView:set(blurView)};
					}
					blurView.frame = CGRectMake(-radius - radius / 2, -radius - radius / 2, view.bounds.size.width + radius*3, view.bounds.size.height + radius*3);
					[view setNeedsLayout];
				});
			}
		@}

		[Foreign(Language.ObjC)]
		public void RemoveBlurEffect()
		@{
			UIView* view = (UIView*)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()};
			UIView *blurView = [view viewWithTag:1001];
			if (blurView) {
				[blurView removeFromSuperview];
			}
		@}

		[Foreign(Language.ObjC)]
		ObjC.Object GetHitTesthandle()
		@{
			UIView* view = (UIView*)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()};
			if ([view isKindOfClass:[ShapeView class]])
			{
				auto sv = (ShapeView*)view;
				return [sv childrenView];
			}
			else return view;
		@}

		internal bool IsEnabled { get; set; }
		internal bool HitTestEnabled { get; set; }

		internal protected virtual void OnPositionChanged() {}
		internal protected virtual void OnSizeChanged() {}

		[Foreign(Language.ObjC)]
		public void SetAccessibilityIdentifier(string name)
		@{
			UIView* view = (UIView*)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()};
			[view setAccessibilityIdentifier:name];
		@}

		[Foreign(Language.ObjC)]
		void InitAnchorPoint()
		@{
			UIView* view = (UIView*)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()};
			[[view layer] setAnchorPoint: { 0.0f, 0.0f }];
		@}

		[Foreign(Language.ObjC)]
		public void SetClipToBounds(bool clipToBounds)
		@{
			UIView* view = (UIView*)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()};
			[view setClipsToBounds:clipToBounds];
		@}

		[Foreign(Language.ObjC)]
		public void SetOpacity(float value)
		@{
			UIView* view = (UIView*)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()};
			[view setAlpha: (CGFloat)value];
		@}

		public void SetHitTestEnabled(bool value)
		{
			HitTestEnabled = value;
			SetEnabledImpl(HitTestEnabled && IsEnabled);
		}

		public void SetEnabled(bool value)
		{
			IsEnabled = value;
			SetEnabledImpl(HitTestEnabled && IsEnabled);
		}

		[Foreign(Language.ObjC)]
		void SetEnabledImpl(bool value)
		@{
			UIView* view = (UIView*)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()};
			[view setUserInteractionEnabled:value];
		@}

		[Foreign(Language.ObjC)]
		public void SetIsVisible(bool isVisible)
		@{
			UIView* view = (UIView*)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()};
			[view setHidden: !isVisible];
		@}

		[Foreign(Language.ObjC)]
		public string Format()
		@{
			UIView* view = (UIView*)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()};
			return [view description];
		@}

		[Foreign(Language.ObjC)]
		public bool IsUIControl()
		@{
			UIView* view = (UIView*)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()};
			return [view isKindOfClass:[UIControl class]];
		@}

		[Foreign(Language.ObjC)]
		public void InsertChild(ViewHandle childHandle)
		@{
			UIView* parent = (UIView*)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()};
			UIView* child = (UIView*)@{Fuse.Controls.Native.ViewHandle:of(childHandle).NativeHandle:get()};
			[parent addSubview:child];
		@}

		[Foreign(Language.ObjC)]
		public void InsertChild(ViewHandle childHandle, int index)
		@{
			UIView* parent = (UIView*)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()};
			UIView* child = (UIView*)@{Fuse.Controls.Native.ViewHandle:of(childHandle).NativeHandle:get()};
			[parent insertSubview:child atIndex:index];
		@}

		[Foreign(Language.ObjC)]
		public void RemoveChild(ViewHandle childHandle)
		@{
			UIView* child = (UIView*)@{Fuse.Controls.Native.ViewHandle:of(childHandle).NativeHandle:get()};
			[child removeFromSuperview];
		@}

		[Foreign(Language.ObjC)]
		public void BringToFront()
		@{
			UIView* view = (UIView*)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()};
			auto parent = [view superview];
			if (parent != NULL)
				[parent bringSubviewToFront:view];
		@}

		[Foreign(Language.ObjC)]
		public void SendToBack()
		@{
			UIView* view = (UIView*)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()};
			auto parent = [view superview];
			if (parent != NULL)
				[parent sendSubviewToBack:view];
		@}

		[Foreign(Language.ObjC)]
		public void Invalidate()
		@{
			if (@{Fuse.Controls.Native.ViewHandle:of(_this).NeedsInvalidation})
			{
				UIView* view = (UIView*)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()};
				[view setNeedsDisplay];
			}
		@}

		public void SetBackgroundColor(float4 c)
		{
			SetBackground(NativeHandle, c.X, c.Y, c.Z, c.W);
		}

		[Foreign(Language.ObjC)]
		static void SetBackground(ObjC.Object handle, float r, float g, float b, float a)
		@{
			UIView* view = (UIView*)handle;
			[view setBackgroundColor:[UIColor colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a]];
		@}

		public void UpdateViewRect(float4x4 transform, float2 size, float density)
		{
			SetTransform(transform);
			SetSize(size);
		}

		public void SetSize(float2 size)
		{
			SetSize(size.X, size.Y);
			Size = size;
		}

		internal void SetSizeAndVisualBounds(float2 size, VisualBounds bounds)
		{
			var r = bounds.FlatRect;
			SetSizeAndBounds(size.X, size.Y, r.Position.X, r.Position.Y, r.Width, r.Height);
			Size = size;
		}

		[Foreign(Language.ObjC)]
		void SetSizeAndBounds(float w, float h, float bx, float by, float bw, float bh)
		@{
			UIView* view = (UIView*)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()};
			auto t = [[view layer] transform];
			[[view layer] setTransform:CATransform3DIdentity];
			[view setCenter: CGPointZero];
			[view setFrame: { { 0.0f, 0.0f }, { w, h } } ];

			if ([[view superview] isKindOfClass:[UIScrollView class]])
			{
				auto sv = (UIScrollView*)[view superview];
				[sv setContentSize: CGSizeMake(w, h)];
			}

			if ([view isKindOfClass:[CanvasViewGroup class]])
			{
				CanvasViewGroup* cvg = (CanvasViewGroup*)view;
				[cvg setRenderBounds: CGRectMake(bx, by, bw, bh)];
			}

			[[view layer] setTransform:t];
		@}

		[Foreign(Language.ObjC)]
		void SetSize(float w, float h)
		@{
			UIView* view = (UIView*)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()};
			auto t = [[view layer] transform];
			[[view layer] setTransform:CATransform3DIdentity];
			[view setCenter: CGPointZero];
			[view setFrame: { { 0.0f, 0.0f }, { w, h } } ];

			if ([[view superview] isKindOfClass:[UIScrollView class]])
			{
				auto sv = (UIScrollView*)[view superview];
				[sv setContentSize: CGSizeMake(w, h)];
			}

			[[view layer] setTransform:t];
		@}

		public void SetTransform(float4x4 t)
		{
			SetTransform(
				t.M11, t.M12, t.M13, t.M14,
				t.M21, t.M22, t.M23, t.M24,
				t.M31, t.M32, t.M33, t.M34,
				t.M41, t.M42, t.M43, t.M44);
			Position = float2(t.M41, t.M42);
		}

		[Foreign(Language.ObjC)]
		void SetTransform(
			float m11, float m12, float m13, float m14,
			float m21, float m22, float m23, float m24,
			float m31, float m32, float m33, float m34,
			float m41, float m42, float m43, float m44)
		@{
			CATransform3D transform = {
				m11, m12, m13, m14,
				m21, m22, m23, m24,
				m31, m32, m33, m34,
				m41, m42, m43, m44
			};
			UIView* view = (UIView*)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()};
			[[view layer] setTransform:transform];
		@}

		public float2 Measure(LayoutParams lp, float density)
		{
			var fillSize = lp.Size;
			if (!lp.HasX)
				fillSize.X = 1e6f;
			if (!lp.HasY)
				fillSize.Y = 1e6f;

			var maxSize = iOSDevice.CompensateForOrientation(fillSize);

			float resW;
			float resH;
			SizeThatFits(maxSize.X, maxSize.Y, out resW, out resH);
			var result = float2(resW, resH);

			return iOSDevice.CompensateForOrientation(result);
		}

		[Foreign(Language.ObjC)]
		void SizeThatFits(float w, float h, out float resW, out float resH)
		@{
			UIView* view = (UIView*)@{Fuse.Controls.Native.ViewHandle:of(_this).NativeHandle:get()};
			CGSize size = { w, h };
			CGSize result = [view sizeThatFits:size];
			*resW = (float)result.width;
			*resH = (float)result.height;
		@}
	}

	extern(iOS) internal static class ViewFactory
	{
		public static ViewHandle InstantiateViewGroup()
		{
			return new ViewHandle(InstantiateViewGroupImpl(), false);
		}

		[Foreign(Language.ObjC)]
		static ObjC.Object InstantiateViewGroupImpl()
		@{
			UIControl* control = [[UIControl alloc] init];
			[control setOpaque:false];
			[control setMultipleTouchEnabled:true];
			return control;
		@}
	}
}