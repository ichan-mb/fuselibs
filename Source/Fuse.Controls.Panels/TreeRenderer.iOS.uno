using Uno;
using Uno.UX;
using Uno.Collections;
using Fuse;
using Fuse.Drawing;
using Fuse.Elements;
using Fuse.Controls;
using Fuse.Controls.Native;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Controls
{
	extern(iOS) class TreeRenderer : ITreeRenderer
	{
		Action<ViewHandle> _setRoot;
		Action<ViewHandle> _clearRoot;

		public TreeRenderer(Action<ViewHandle> setRoot, Action<ViewHandle> clearRoot)
		{
			_setRoot = setRoot;
			_clearRoot = clearRoot;
		}

		readonly Dictionary<Element,ViewHandle> _elements = new Dictionary<Element,ViewHandle>();

		// Elements shown as a plain container view, below the root: the views that let
		// touches through when the element draws nothing (UpdatePassThrough).
		readonly HashSet<Element> _containers = new HashSet<Element>();

		void ITreeRenderer.RootingStarted(Element e)
		{
			bool isContainer;
			var v = InstantiateView(e, out isContainer);
			if (e is Control)
				((Control)e).ViewHandle = v;

			var hasParent = e.Parent is Element && _elements.ContainsKey((Element)e.Parent);
			if (hasParent)
				_elements[(Element)e.Parent].InsertChild(v, 0);
			else
				_setRoot(v);

			if (!v.HandlesInput)
				Fuse.Controls.Native.iOS.InputDispatch.AddInputHandler(e, v);

			_elements.Add(e, v);

			// The root has to take every touch no other view takes, or Fuse gets none of them.
			if (isContainer && hasParent && !v.HandlesInput)
			{
				_containers.Add(e);
				UpdatePassThrough(e);
			}
		}

		// A container view takes a touch that lands on it only where Fuse's own hit testing
		// would hit the element: with HitTestMode LocalBounds, or LocalVisual and a background.
		// Otherwise it is left to the views behind, as in the OpenGL renderer: an empty Panel in
		// front must not stop a ScrollView behind it from scrolling.
		void UpdatePassThrough(Element e)
		{
			if (!_containers.Contains(e))
				return;

			var mode = e.HitTestMode;
			var control = e as Control;
			var hitsItself = mode.HasFlag(HitTestMode.LocalBounds)
				|| (mode.HasFlag(HitTestMode.LocalVisual) && control != null && control.Background != null);

			Fuse.Controls.Native.iOS.InputDispatch.SetHitTestPassThrough(_elements[e], !hitsItself);
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
			_containers.Remove(e);

			if (!v.HandlesInput)
				Fuse.Controls.Native.iOS.InputDispatch.RemoveInputHandler(v);

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
			UpdatePassThrough(e);
		}

		void ITreeRenderer.TransformChanged(Element e)
		{
			var viewHandle = _elements[e];
			var transform = e.LocalTransform;

			var p = e.Parent;
			if (p is Control)
				((Control)p).CompensateForScrollView(ref transform);

			viewHandle.SetTransform(transform);
		}

		void ITreeRenderer.RenderBoundsChanged(Element e)
		{
			var viewHandle = _elements[e];
			if (viewHandle.NeedsRenderBounds)
				viewHandle.SetSizeAndVisualBounds(e.ActualSize, e.RenderBoundsWithoutEffects);
		}

		void ITreeRenderer.Placed(Element e)
		{
			var viewHandle = _elements[e];
			if (viewHandle.NeedsRenderBounds)
				viewHandle.SetSizeAndVisualBounds(e.ActualSize, e.RenderBoundsWithoutEffects);
			else
				viewHandle.SetSize(e.ActualSize);
		}

		void ITreeRenderer.IsVisibleChanged(Element e, bool isVisible)
		{
			_elements[e].SetIsVisible(isVisible);
		}

		void ITreeRenderer.IsEnabledChanged(Element e, bool isEnabled)
		{
			var v = _elements[e];
			v.SetEnabled(isEnabled);
		}

		void ITreeRenderer.OpacityChanged(Element e, float opacity)
		{
			_elements[e].SetOpacity(opacity);
		}

		void ITreeRenderer.ClipToBoundsChanged(Element e, bool clipToBounds)
		{
			_elements[e].SetClipToBounds(clipToBounds);
		}

		void ITreeRenderer.HitTestModeChanged(Element e, bool enabled)
		{
			var v = _elements[e];
			v.SetHitTestEnabled(enabled);
			UpdatePassThrough(e);
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
			var canMeasure = viewHandle.IsLeafView;
			size = canMeasure
				? viewHandle.Measure(lp, e.Viewport.PixelsPerPoint)
				: float2(0.0f);
			return canMeasure;
		}

		ViewHandle InstantiateView(Element e, out bool isContainer)
		{
			isContainer = false;
			var sd = e as ISurfaceDrawable;
			if (sd != null && sd.IsPrimary)
			{
				return new Fuse.Controls.Native.iOS.CanvasViewGroup(sd, e.Viewport.PixelsPerPoint);
			}

			ViewHandle result = null;
			var appearance = (InstantiateTemplate(e) ?? InstantiateViewOld(e)) as ViewHandle;
			if (appearance != null)
			{
				if (e is Control)
				{
					((Control)e).ViewHandle = appearance;
					if (appearance is IView)
						((Control)e).NativeView = (IView)appearance;
				}
				result = appearance;
			}
			else
			{
				result = ViewFactory.InstantiateViewGroup();
				isContainer = true;
			}
			result.SetAccessibilityIdentifier(e.ToString());
			return result;
		}

		object InstantiateTemplate(Element e)
		{
			var t = e.FindTemplate("iOSAppearance");
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

	}

	extern(iOS) static class Extensions
	{
		public static float4 GetColor(this Brush brush)
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
					Fuse.Diagnostics.Unsupported( "Cannot convert to a color", brush );
			}
			return c;
		}
	}
}