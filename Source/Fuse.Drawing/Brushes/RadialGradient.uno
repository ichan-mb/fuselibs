using Uno;
using Uno.Collections;
using Uno.Collections.EnumerableExtensions;
using Uno.Graphics;
using Uno.UX;


namespace Fuse.Drawing
{


	/**
		A Radial gradient @Brush.

		@RadialGradient lets you describe a Radial gradient using a collection of @GradientStops.
		The following example displays a @Rectangle with a @RadialGradient that fades from white to black at center.

		```xml
		<Rectangle>
			<RadialGradient StartPoint="0.5, 0.5">
				<GradientStop Offset="0" Color="#fff" />
				<GradientStop Offset="1" Color="#000" />
			</RadialGradient>
		</Rectangle>
		```

		You may also specify any number of @GradientStops.

		```xml
		<Circle>
			<RadialGradient StartPoint="0.75, 0.5">
				<GradientStop Offset="0" Color="#f00" />
				<GradientStop Offset="0.3" Color="#f0f" />
				<GradientStop Offset="0.6" Color="#00f" />
				<GradientStop Offset="1" Color="#0ff" />
			</RadialGradient>
		</Circle>
		```
	*/
	public class RadialGradient: DynamicBrush, IPropertyListener
	{
		static Selector _stopsName = "Stops";
        static Selector _startPointName = "StartPoint";


		void IPropertyListener.OnPropertyChanged(PropertyObject sender, Selector property)
		{
			OnPropertyChanged(_stopsName);
		}

		RootableList<GradientStop> _stops = new RootableList<GradientStop>();

		static GradientStop[] _emptySortedStops = new GradientStop[0];
		public GradientStop[] SortedStops { get { return ToArray(_stops) ?? _emptySortedStops; } }

		[UXContent]
		public IList<GradientStop> Stops { get { return _stops; } }

		/**
			Check to ensure that stops are in the right order. If they are not, throw an exception, as the code assumes they are ordered correctly.
		*/
		static void ValidateStopsSorted(IList<GradientStop> stops)
		{
			for (int i = 1; i < stops.Count; ++i)
			{
				if (stops[i].Offset < stops[i - 1].Offset)
					throw new Exception(String.Format("Gradient stop offsets must be in order! Expected something bigger or equal to {0}, but got {1}!", stops[i - 1].Offset, stops[i].Offset));
			}
		}

		/**
			The starting point of the gradient. Specified as a proportion of the total size of the @Shape the brush is applied to.
			This means that, for instance, a value of `0, 1` results in the gradient starting at the bottom-left corner.
		*/
        float2 _startPoint;
		public float2 StartPoint
		{
			get { return _startPoint; }
			set
			{
				if (_startPoint != value)
				{
					_startPoint = value;
					OnPropertyChanged(_startPointName);
				}
			}
		}

		void OnAdded(GradientStop gs)
		{
			gs.AddPropertyListener(this);

			if (IsPinned)
			{
				OnPropertyChanged(_stopsName);
				ValidateStopsSorted(_stops);
			}
		}

		void OnRemoved(GradientStop gs)
		{
			gs.RemovePropertyListener(this);

			if (IsPinned)
				OnPropertyChanged(_stopsName);
		}

		public RadialGradient()
		{
		}

		public RadialGradient(params GradientStop[] stops)
		{
			foreach (var s in stops) _stops.Add(s);
		}

		protected override void OnPinned()
		{
			base.OnPinned();
            _stops.RootSubscribe(OnAdded, OnRemoved);
		}

		protected override void OnPrepare(DrawContext dc, float2 canvasSize)
		{
			base.OnPrepare(dc, canvasSize);
		}

		protected override void OnUnpinned()
		{
            _stops.RootUnsubscribe();
			base.OnUnpinned();
		}

		public float2 GetEffectiveStartPoint( float2 size )
		{
			return float2(StartPoint.X * size.X, StartPoint.Y * size.Y);
		}
	}
}
