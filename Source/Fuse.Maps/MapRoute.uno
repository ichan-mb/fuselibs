using Uno;
using Uno.UX;
using Fuse.Scripting;

namespace Fuse.Controls
{
	public delegate void RouteEventHandler(object sender, RouteEventArgs args);

	/** Event arguments for @MapRoute.Calculated and @MapRoute.Failed. */
	public sealed class RouteEventArgs : EventArgs, IScriptEvent
	{
		public readonly double Distance;
		public readonly double Duration;
		public readonly string Error;

		public RouteEventArgs(double distance, double duration, string error)
		{
			Distance = distance;
			Duration = duration;
			Error = error;
		}

		void IScriptEvent.Serialize(IEventSerializer s)
		{
			s.AddDouble("distance", Distance);
			s.AddDouble("duration", Duration);
			if (Error != null)
				s.AddString("error", Error);
		}
	}

	/**
		Calculates and draws a route between two points on a @MapView.

		The route is requested automatically when it is rooted or when one of
		`FromLatitude`, `FromLongitude`, `ToLatitude`, `ToLongitude` or `Mode`
		changes, and drawn as a polyline on the map. Use `Distance`, `Duration`
		and `IsCalculated` to display information about the result, or listen to
		the `Calculated` and `Failed` events.

		```HTML
		<NativeViewHost>
			<MapView Latitude="59.9" Longitude="10.7" Zoom="12">
				<MapRoute FromLatitude="59.9115573" FromLongitude="10.73888"
				          ToLatitude="59.9500"     ToLongitude="10.7800"
				          Mode="Driving" StrokeColor="Blue" LineWidth="6" />
			</MapView>
		</NativeViewHost>
		```

		*Note:* On Android, routing uses the Google Directions REST API, so the
		Directions API must be enabled for the key configured with
		`Android.Geo.ApiKey`. On iOS, `MKDirections` is used and no key is needed.

		@seealso Fuse.Controls.MapView
	*/
	public class MapRoute : Node
	{
		static int UID_POOL = 0;
		internal int Uid = UID_POOL++;

		static Selector _fromLatitudeName = "FromLatitude";
		static Selector _fromLongitudeName = "FromLongitude";
		static Selector _toLatitudeName = "ToLatitude";
		static Selector _toLongitudeName = "ToLongitude";
		static Selector _modeName = "Mode";
		static Selector _strokeColorName = "StrokeColor";
		static Selector _lineWidthName = "LineWidth";
		static Selector _zIndexName = "ZIndex";
		static Selector _alphaName = "Alpha";
		static Selector _visibleName = "Visible";
		static Selector _distanceName = "Distance";
		static Selector _durationName = "Duration";
		static Selector _isCalculatedName = "IsCalculated";
		static Selector _isCalculatingName = "IsCalculating";
		static Selector _errorName = "Error";
		static Selector _polylineName = "Polyline";

		/** Dispatched when the route has been calculated. */
		public event RouteEventHandler Calculated;
		/** Dispatched when the route calculation failed. */
		public event RouteEventHandler Failed;

		double _fromLatitude;
		/** The latitude of the starting point. */
		public double FromLatitude
		{
			get { return _fromLatitude; }
			set
			{
				if (_fromLatitude == value) return;
				_fromLatitude = value;
				Invalidate();
				OnPropertyChanged(_fromLatitudeName);
			}
		}

		double _fromLongitude;
		/** The longitude of the starting point. */
		public double FromLongitude
		{
			get { return _fromLongitude; }
			set
			{
				if (_fromLongitude == value) return;
				_fromLongitude = value;
				Invalidate();
				OnPropertyChanged(_fromLongitudeName);
			}
		}

		double _toLatitude;
		/** The latitude of the destination. */
		public double ToLatitude
		{
			get { return _toLatitude; }
			set
			{
				if (_toLatitude == value) return;
				_toLatitude = value;
				Invalidate();
				OnPropertyChanged(_toLatitudeName);
			}
		}

		double _toLongitude;
		/** The longitude of the destination. */
		public double ToLongitude
		{
			get { return _toLongitude; }
			set
			{
				if (_toLongitude == value) return;
				_toLongitude = value;
				Invalidate();
				OnPropertyChanged(_toLongitudeName);
			}
		}

		RouteMode _mode = RouteMode.Driving;
		/** The travel mode of the route. */
		public RouteMode Mode
		{
			get { return _mode; }
			set
			{
				if (_mode == value) return;
				_mode = value;
				Invalidate();
				OnPropertyChanged(_modeName);
			}
		}

		float4 _strokeColor = float4(0.13f, 0.59f, 0.95f, 1);
		/** The color of the route line. */
		public float4 StrokeColor
		{
			get { return _strokeColor; }
			set
			{
				if (_strokeColor == value) return;
				_strokeColor = value;
				OnPropertyChanged(_strokeColorName);
				MarkDirty();
			}
		}

		int _lineWidth = 6;
		/** The width of the route line. */
		public int LineWidth
		{
			get { return _lineWidth; }
			set
			{
				if (_lineWidth == value) return;
				_lineWidth = value;
				OnPropertyChanged(_lineWidthName);
				MarkDirty();
			}
		}

		int _zIndex = 0;
		/** The draw order of the route. Higher values draw on top. */
		public int ZIndex
		{
			get { return _zIndex; }
			set
			{
				if (_zIndex == value) return;
				_zIndex = value;
				OnPropertyChanged(_zIndexName);
				MarkDirty();
			}
		}

		float _alpha = 1;
		/** The opacity of the route, from `0` to `1`. */
		public float Alpha
		{
			get { return _alpha; }
			set
			{
				if (_alpha == value) return;
				_alpha = value;
				OnPropertyChanged(_alphaName);
				MarkDirty();
			}
		}

		bool _visible = true;
		/** Specifies whether the route is drawn. */
		public bool Visible
		{
			get { return _visible; }
			set
			{
				if (_visible == value) return;
				_visible = value;
				OnPropertyChanged(_visibleName);
				MarkDirty();
			}
		}

		double _distance;
		/** The length of the calculated route, in meters. */
		public double Distance
		{
			get { return _distance; }
		}

		double _duration;
		/** The estimated travel time of the calculated route, in seconds. */
		public double Duration
		{
			get { return _duration; }
		}

		Coordinate[] _polyline;
		/** The points of the calculated route, in order. */
		public Coordinate[] Polyline
		{
			get { return _polyline; }
		}

		bool _isCalculating;
		/** `true` while a route calculation is in progress. */
		public bool IsCalculating
		{
			get { return _isCalculating; }
		}

		/** `true` once the route has been calculated. */
		public bool IsCalculated
		{
			get { return _polyline != null; }
		}

		string _error;
		/** The error message from the last failed calculation, or `null`. */
		public string Error
		{
			get { return _error; }
		}

		bool _needsCalculation = true;
		int _generation;

		internal bool HasPolyline
		{
			get { return _polyline != null && _polyline.Length > 1; }
		}

		internal int Generation
		{
			get { return _generation; }
		}

		internal bool NeedsCalculation
		{
			get { return _needsCalculation && !_isCalculating && IsValid; }
		}

		internal void MarkCalculationStarted()
		{
			_isCalculating = true;
			_needsCalculation = false;
			OnPropertyChanged(_isCalculatingName);
		}

		internal void SetResult(int generation, Coordinate[] polyline, double distance, double duration)
		{
			if (generation != _generation) return;

			_polyline = polyline;
			_distance = distance;
			_duration = duration;
			_error = null;
			_isCalculating = false;
			_needsCalculation = false;

			OnPropertyChanged(_polylineName);
			OnPropertyChanged(_distanceName);
			OnPropertyChanged(_durationName);
			OnPropertyChanged(_isCalculatedName);
			OnPropertyChanged(_isCalculatingName);
			OnPropertyChanged(_errorName);

			if (Calculated != null)
				Calculated(this, new RouteEventArgs(distance, duration, null));
		}

		internal void SetError(int generation, string message)
		{
			if (generation != _generation) return;

			_isCalculating = false;
			_error = message;

			OnPropertyChanged(_isCalculatingName);
			OnPropertyChanged(_errorName);

			if (Failed != null)
				Failed(this, new RouteEventArgs(0, 0, message));
		}

		/** Requests a new calculation with the current parameters. */
		public void Refresh()
		{
			Invalidate();
			OnPropertyChanged(_fromLatitudeName);
			OnPropertyChanged(_fromLongitudeName);
			OnPropertyChanged(_toLatitudeName);
			OnPropertyChanged(_toLongitudeName);
			OnPropertyChanged(_modeName);
		}

		internal double[] GetPolylineArray()
		{
			if (_polyline == null)
				return new double[0];

			var items = new double[_polyline.Length * 2];
			var idx = 0;
			foreach (var point in _polyline)
			{
				items[idx++] = point.Latitude;
				items[idx++] = point.Longitude;
			}
			return items;
		}

		bool IsValid
		{
			get
			{
				return _fromLatitude >= -90 && _fromLatitude <= 90
					&& _toLatitude >= -90 && _toLatitude <= 90
					&& _fromLongitude >= -180 && _fromLongitude <= 180
					&& _toLongitude >= -180 && _toLongitude <= 180
					&& (_fromLatitude != _toLatitude || _fromLongitude != _toLongitude);
			}
		}

		void Invalidate()
		{
			_needsCalculation = true;
			_isCalculating = false;
			_generation++;

			_polyline = null;
			_distance = 0;
			_duration = 0;
			_error = null;

			OnPropertyChanged(_polylineName);
			OnPropertyChanged(_distanceName);
			OnPropertyChanged(_durationName);
			OnPropertyChanged(_isCalculatedName);
			OnPropertyChanged(_isCalculatingName);
			OnPropertyChanged(_errorName);

			MarkDirty();
		}

		void MarkDirty()
		{
			var map = Parent as MapView;
			if (map != null)
				map.UpdateRoutesNextFrame();
		}

		protected override void OnRooted()
		{
			base.OnRooted();

			var map = Parent as MapView;
			if (map != null)
				map.AddRoute(this);
		}

		protected override void OnUnrooted()
		{
			var map = Parent as MapView;
			if (map != null)
				map.RemoveRoute(this);

			base.OnUnrooted();
		}
	}
}
