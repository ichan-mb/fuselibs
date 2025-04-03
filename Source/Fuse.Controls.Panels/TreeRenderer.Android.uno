using Uno;
using Uno.UX;
using Uno.Collections;
using Fuse;
using Fuse.Drawing;
using Fuse.Effects;
using Fuse.Elements;
using Fuse.Controls;
using Fuse.Controls.Native;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Controls
{
	extern(Android) class TreeRenderer : ITreeRenderer
	{
		class ViewGroup : ViewHandle
		{
			ViewHandle _content;

			public ViewGroup(ViewHandle content) : base(ViewFactory.InstantiateViewGroup().NativeHandle)
			{
				_content = content;
				InsertChild(content);
			}

			public override float2 Measure(LayoutParams lp, float density)
			{
				return _content.Measure(lp, density);
			}

			public override void Dispose()
			{
				base.Dispose();
				_content.Dispose();
				_content = null;
			}
		}
		Action<ViewHandle> _setRoot;
		Action<ViewHandle> _clearRoot;

		public TreeRenderer(Action<ViewHandle> setRoot, Action<ViewHandle> clearRoot)
		{
			_setRoot = setRoot;
			_clearRoot = clearRoot;
		}

		readonly Dictionary<Element,ViewHandle> _elements = new Dictionary<Element,ViewHandle>();

		void ITreeRenderer.RootingStarted(Element e)
		{
			var v = InstantiateView(e);
			if (e is Control)
				((Control)e).ViewHandle = v;

			if (e.Parent is Element && _elements.ContainsKey((Element)e.Parent))
			{
				GetParentViewGroup(e).InsertChild(v, 0);
			}
			else
				_setRoot(v);

			if (!v.HandlesInput)
				Fuse.Controls.Native.Android.InputDispatch.AddListener(v, e);

			_elements.Add(e, v);
		}

		ViewHandle GetParentViewGroup(Element e)
		{
			var parent = (Element)e.Parent;
			var parentView = _elements[parent];
			if (!parentView.IsViewGroup())
				TransformIntoViewGroup(parent);
			return _elements[parent];
		}

		void TransformIntoViewGroup(Element e)
		{
			var parentView = _elements[(Element)e.Parent];
			var child = _elements[e];
			var index = parentView.IndexOfChild(child);
			parentView.RemoveChild(child);
			var viewGroup = new ViewGroup(child);
			ViewHandle.CopyState(child, viewGroup);
			child.ResetState();
			parentView.InsertChild(viewGroup, index);
			_elements[e] = viewGroup;
		}

		void ITreeRenderer.Rooted(Element e) { }

		void ITreeRenderer.Unrooted(Element e)
		{
			if (e.Parent is Element && _elements.ContainsKey((Element)e.Parent))
				_elements[(Element)e.Parent].RemoveChild(_elements[e]);
			else
				_clearRoot(_elements[e]);

			var v = _elements[e];
			_elements.Remove(e);

			if (!v.HandlesInput)
				Fuse.Controls.Native.Android.InputDispatch.RemoveListener(v);

			RemoveEffect(e);

			if (e is Control)
			{
				var c = (Control)e;
				if (c.ViewHandle != null)
				{
					c.ViewHandle.Dispose();
					c.ViewHandle = null;
				}
				c.NativeView = null;
			}
		}

		void ITreeRenderer.BackgroundChanged(Element e, Brush background)
		{
			_elements[e].SetBackgroundColor(background.GetColor());
		}

		void ITreeRenderer.TransformChanged(Element e)
		{
			var viewHandle = _elements[e];
			var transform = e.LocalTransform;
			var size = e.ActualSize;
			var density = e.Viewport.PixelsPerPoint;

			var p = e.Parent;
			if (p is Control)
				((Control)p).CompensateForScrollView(ref transform);

			viewHandle.UpdateViewRect(transform, size, density);
		}

		void ITreeRenderer.Placed(Element e)
		{
			var density = e.Viewport.PixelsPerPoint;
			var actualPosition = (int2)(e.ActualPosition * density);
			var actualSize = (int2)(e.ActualSize * density);
			_elements[e].UpdateViewRect(actualPosition.X, actualPosition.Y, actualSize.X, actualSize.Y);

			ApplyEffect(e);
		}

		void ITreeRenderer.RenderBoundsChanged(Element e)
		{
			ApplyEffect(e);
		}

		void ITreeRenderer.IsVisibleChanged(Element e, bool isVisible)
		{
			_elements[e].SetIsVisible(isVisible);
		}

		void ITreeRenderer.IsEnabledChanged(Element e, bool isEnabled)
		{
			_elements[e].SetEnabled(isEnabled);
		}

		void ITreeRenderer.OpacityChanged(Element e, float opacity)
		{
			_elements[e].SetOpacity(opacity);
		}

		void ITreeRenderer.ClipToBoundsChanged(Element e, bool clipToBounds)
		{
			var viewHandle = _elements[e];
			if (viewHandle.IsViewGroup())
				viewHandle.SetClipToBounds(clipToBounds);
		}

		void ITreeRenderer.HitTestModeChanged(Element e, bool enabled)
		{
			var viewHandle = _elements[e];
			if (viewHandle.IsViewGroup())
				viewHandle.SetHitTestEnabled(enabled);
		}

		void ITreeRenderer.ZOrderChanged(Element e, Visual[] zorder)
		{
			for (var i = 0; i < zorder.Length; i++)
			{
				var child = zorder[i] as Element;
				if (child != null)
					_elements[child].BringToFront();
			}
		}

		bool ITreeRenderer.Measure(Element e, LayoutParams lp, out float2 size)
		{
			var viewHandle = _elements[e];
			var canMeasure = viewHandle.IsLeafView || viewHandle is ViewGroup;
			size = canMeasure
				? viewHandle.Measure(lp, e.Viewport.PixelsPerPoint)
				: float2(0.0f);
			return canMeasure;
		}

		ViewHandle InstantiateView(Element e)
		{
			var sd = e as ISurfaceDrawable;
			if (sd != null && sd.IsPrimary)
			{
				return new Fuse.Controls.Native.Android.CanvasViewGroup(sd, e.Viewport.PixelsPerPoint);
			}

			var appearance = (InstantiateTemplate(e) ?? InstantiateViewOld(e)) as ViewHandle;
			if (appearance != null)
			{
				if (e is Control)
				{
					((Control)e).ViewHandle = appearance;
					if (appearance is IView)
						((Control)e).NativeView = (IView)appearance;
				}
				return appearance;
			}
			else
			{
				return ViewFactory.InstantiateViewGroup();
			}
		}

		object InstantiateTemplate(Element e)
		{
			var t = e.FindTemplate("AndroidAppearance");
			return t != null ? t.New() : null;
		}

		// For backwardscompatibility with old pattern
		object InstantiateViewOld(Element e)
		{
			if (e is Control)
			{
				var c = (Control)e;
				return c.InstantiateNativeView();
			}
			return null;
		}

		void ApplyEffect(Element e)
		{
			var blur = e.FirstChild<Blur>();
			var desaturate = e.FirstChild<Desaturate>();
			var duotone = e.FirstChild<Duotone>();
			var viewHandle = e.ViewHandle;
			if (viewHandle != null && (blur != null || desaturate != null || duotone != null))
			{
				var blurRadius = 0.0f;
				var saturationAmount = 1.0f;
				var duotoneLightColor = 0;
				var duotoneShadowColor = 0;

				if (blur != null) blurRadius = blur.Radius;
				if (desaturate != null) saturationAmount = 1.0f - desaturate.Amount;
				if (duotone != null)
				{
					duotoneLightColor = (int)Uno.Color.ToArgb(float4(duotone.Light, 1));
					duotoneShadowColor = (int)Uno.Color.ToArgb(float4(duotone.Shadow, 1));
				}
				viewHandle.ApplyEffect(blur != null, desaturate != null, duotone != null, blurRadius, saturationAmount, duotoneLightColor, duotoneShadowColor);
			}
		}

		void RemoveEffect(Element e)
		{
			var viewHandle = e.ViewHandle;
			if (viewHandle != null)
			{
				viewHandle.RemoveEffect();
			}
		}
	}

	extern(Android) static class Extensions
	{
		public static int GetColor(this Brush brush)
		{
			var c = float4(0);
			if (brush != null)
			{
				var sc = brush as Fuse.Drawing.SolidColor;
				if (sc != null)
					c = sc.Color;
				var ssc = brush as Fuse.Drawing.StaticSolidColor;
				if (ssc != null)
					c = ssc.Color;

				if (sc == null && ssc == null)
					Fuse.Diagnostics.Unsupported( "Cannot convert to a color" , brush );
			}
			return (int)Uno.Color.ToArgb(c);
		}
	}
}