using Fuse.Elements;
using Uno.UX;
using Uno;
using Uno.Collections;

namespace Fuse.Controls
{

	public enum OverlayType
	{
		Polyline,
		Polygon,
		Circle,
		Image,
		Tile
	}

	public enum LineCap
	{
		Round,
		Butt,
		Square
	}

	public enum LineJoin
	{
		Round,
		Bevel,
		Miter
	}

	public class Coordinate : PropertyObject
	{
		static Selector _latitudeName = "Latitude";
		double _latitude = 0;
		/**
			The latitude coordinate
		*/
		public double Latitude {
			get
			{
				return _latitude;
			}
			set
			{
				if (_latitude != value)
				{
					_latitude = value;
					OnPropertyChanged(_latitudeName);
				}
			}
		}

		static Selector _longitudeName = "Longitude";
		double _longitude = 0;
		/**
			The longitude coordinate
		*/
		public double Longitude {
			get
			{
				return _longitude;
			}
			set
			{
				if (_longitude != value)
				{
					_longitude = value;
					OnPropertyChanged(_longitudeName);
				}
			}
		}

		public Coordinate() {}

		public Coordinate(double latitude, double longitude)
		{
			_latitude = latitude;
			_longitude = longitude;
		}
	}

	/** A hole cut out of a @MapOverlay of type `Polygon`.

		Holes are added programmatically or from JavaScript via `MapView.setOverlays`.
	*/
	public class MapOverlayHole : Node, IPropertyListener
	{
		internal MapOverlay Owner;
		RootableList<Coordinate> _coordinates = new RootableList<Coordinate>();

		public MapOverlayHole()
		{
			_coordinates.Subscribe(OnCoordinateAdded, OnCoordinateRemoved);
		}

		[UXContent]
		public IList<Coordinate> Coordinates
		{
			get
			{
				return _coordinates;
			}
		}

		void OnCoordinateAdded(Coordinate coord)
		{
			coord.AddPropertyListener(this);
			Changed();
		}

		void OnCoordinateRemoved(Coordinate coord)
		{
			coord.RemovePropertyListener(this);
			Changed();
		}

		void IPropertyListener.OnPropertyChanged(PropertyObject sender, Selector property)
		{
			Changed();
		}

		void Changed()
		{
			if (Owner != null)
				Owner.NotifyHoleChanged();
		}
	}

	/** Draws a shape on a @MapView.

		`Type` selects what is drawn: `Polyline` and `Polygon` use the `Coordinates` list,
		`Circle` uses `CenterLatitude`, `CenterLongitude` and `Radius` (in meters), `Image`
		stretches `ImageFile` between the `MinLatitude`/`MinLongitude` and
		`MaxLatitude`/`MaxLongitude` corners, and `Tile` fetches raster tiles from
		`TileUrlTemplate`.

		```HTML
		<NativeViewHost>
			<MapView Zoom="14" Latitude="-6.914742" Longitude="107.609820">
				<MapOverlay Type="Polyline" StrokeColor="Blue" LineWidth="5">
					<Coordinate Latitude="-6.914742" Longitude="107.609820" />
					<Coordinate Latitude="-6.915850" Longitude="107.609929" />
					<Coordinate Latitude="-6.916959" Longitude="107.611009" />
				</MapOverlay>
			</MapView>
		</NativeViewHost>
		```

		Polygons can have holes through the `Holes` list, and overlays can be ordered
		and faded with `ZIndex` and `Alpha`.

		@seealso Fuse.Controls.MapView
	*/
	public class MapOverlay : Node, IPropertyListener
	{

		static Selector _coordinatesName = "Coordinates";
		static Selector _overlayTypeName = "OverlayType";
		static Selector _startCapName = "StartCap";
		static Selector _endCapName = "EndCap";
		static Selector _joinTypeName = "JoinType";
		static Selector _strokeColorName = "StrokeColor";
		static Selector _fillColorName = "FillColor";
		static Selector _lineWidthName = "LineWidth";
		static Selector _geodesicName = "Geodesic";
		static Selector _dashPatternName = "DashPattern";
		static Selector _centerLatitudeName = "CenterLatitude";
		static Selector _centerLongitudeName = "CenterLongitude";
		static Selector _radiusName = "Radius";
		static Selector _zIndexName = "ZIndex";
		static Selector _alphaName = "Alpha";
		static Selector _visibleName = "Visible";
		static Selector _imageFilePathName = "ImageFilePath";
		static Selector _minLatitudeName = "MinLatitude";
		static Selector _minLongitudeName = "MinLongitude";
		static Selector _maxLatitudeName = "MaxLatitude";
		static Selector _maxLongitudeName = "MaxLongitude";
		static Selector _tileUrlTemplateName = "TileUrlTemplate";
		static Selector _tileMinZoomName = "TileMinZoom";
		static Selector _tileMaxZoomName = "TileMaxZoom";
		static int _uidPool = 0;
		internal int Uid = _uidPool++;
		public delegate void OverlayTappedHandler(object sender, EventArgs args);
		public event OverlayTappedHandler Tapped;

		internal void HandleTapped()
		{
			if (Tapped != null)
				Tapped(this, new EventArgs());
		}

		void IPropertyListener.OnPropertyChanged(PropertyObject sender, Selector property)
		{
			MarkDirty();
		}

		void SetDirty(Selector property)
		{
			OnPropertyChanged(property);
			MarkDirty();
		}

		OverlayType _overlayType = OverlayType.Polyline;
		/**
			The overlay type
		*/
		public OverlayType Type
		{
			get
			{
				return _overlayType;
			}

			set
			{
				if (_overlayType != value)
				{
					_overlayType = value;
					SetDirty(_overlayTypeName);
				}
			}
		}

		LineCap _startCap = LineCap.Round;
		/**
			The Start Cap of line
		*/
		public LineCap StartCap
		{
			get
			{
				return _startCap;
			}

			set
			{
				if (_startCap != value)
				{
					_startCap = value;
					SetDirty(_startCapName);
				}
			}
		}

		LineCap _endCap = LineCap.Round;
		/**
			The End Cap of line
		*/
		public LineCap EndCap
		{
			get
			{
				return _endCap;
			}

			set
			{
				if (_endCap != value)
				{
					_endCap = value;
					SetDirty(_endCapName);
				}
			}
		}

		LineJoin _joinType = LineJoin.Round;
		/**
			The Joint Type of line
		*/
		public LineJoin JoinType
		{
			get
			{
				return _joinType;
			}

			set
			{
				if (_joinType != value)
				{
					_joinType = value;
					SetDirty(_joinTypeName);
				}
			}
		}

		float4 _strokeColor = float4(1,0,0,1);
		/**
			The Stroke Color of overlay
		*/
		public float4 StrokeColor
		{
			get
			{
				return _strokeColor;
			}
			set
			{
				if (_strokeColor != value)
				{
					_strokeColor = value;
					SetDirty(_strokeColorName);
				}
			}
		}

		float4 _fillColor = float4(1,0,0,1);
		/**
			The Fill Color of overlay, only applicable on Polygon and Circle
		*/
		public float4 FillColor
		{
			get
			{
				return _fillColor;
			}
			set
			{
				if (_fillColor != value)
				{
					_fillColor = value;
					SetDirty(_fillColorName);
				}
			}
		}

		int _lineWidth = 2;
		/**
			The Line Width of overlay
		*/
		public int LineWidth
		{
			get
			{
				return _lineWidth;
			}
			set
			{
				if (_lineWidth != value)
				{
					_lineWidth = value;
					SetDirty(_lineWidthName);
				}
			}
		}

		bool _geodesic = false;
		/**
			Set whether to do geodesic draw on polyline
		*/
		public bool Geodesic
		{
			get
			{
				return _geodesic;
			}
			set
			{
				if (_geodesic != value)
				{
					_geodesic = value;
					SetDirty(_geodesicName);
				}
			}
		}

		int2 _dashPattern = int2(0,0);
		/**
			The dash pattern when drawing stroke, int2 type with first value define length of dash, and second value define length of gap
		*/
		public int2 DashPattern
		{
			get
			{
				return _dashPattern;
			}
			set
			{
				if (_dashPattern != value)
				{
					_dashPattern = value;
					SetDirty(_dashPatternName);
				}
			}
		}

		double _centerLatitude = 0;
		/**
			The center latitude coordinate, applicable when using Circle overlay type
		*/
		public double CenterLatitude {
			get
			{
				return _centerLatitude;
			}
			set
			{
				if (_centerLatitude != value)
				{
					_centerLatitude = value;
					SetDirty(_centerLatitudeName);
				}
			}
		}

		double _centerLongitude = 0;
		/**
			The center longitude coordinate, applicable when using Circle overlay type
		*/
		public double CenterLongitude {
			get
			{
				return _centerLongitude;
			}
			set
			{
				if (_centerLongitude != value)
				{
					_centerLongitude = value;
					SetDirty(_centerLongitudeName);
				}
			}
		}

		double _radius = 10;
		/**
			Radius of the circle overlay, pplicable when using Circle overlay type
		*/
		public double Radius
		{
			get
			{
				return _radius;
			}
			set
			{
				if (_radius != value)
				{
					_radius = value;
					SetDirty(_radiusName);
				}
			}
		}

		public MapOverlay()
		{
		}

		public MapOverlay(params Coordinate[] coordinates)
		{
			foreach (var s in coordinates)
				_coordinates.Add(s);
		}

		int _zIndex = 0;
		/**
			The draw order of the overlay. Overlays with a higher value are drawn on top of overlays with a lower value.
		*/
		public int ZIndex
		{
			get { return _zIndex; }
			set
			{
				if (_zIndex != value)
				{
					_zIndex = value;
					SetDirty(_zIndexName);
				}
			}
		}

		float _alpha = 1;
		/**
			The opacity of the overlay, from `0` (transparent) to `1` (opaque).
		*/
		public float Alpha
		{
			get { return _alpha; }
			set
			{
				if (_alpha != value)
				{
					_alpha = value;
					SetDirty(_alphaName);
				}
			}
		}

		bool _visible = true;
		/**
			Specifies whether the overlay is drawn and can receive taps.
		*/
		public bool Visible
		{
			get { return _visible; }
			set
			{
				if (_visible != value)
				{
					_visible = value;
					SetDirty(_visibleName);
				}
			}
		}

		FileSource _image;
		/**
			The image to draw for an overlay of type `Image`. The image is stretched to fit the
			`MinLatitude`, `MinLongitude`, `MaxLatitude` and `MaxLongitude` bounds.
		*/
		public FileSource ImageFile
		{
			get { return _image; }
			set
			{
				if (_image != value)
				{
					_image = value;
					SetDirty(_imageFilePathName);
				}
			}
		}

		double _minLatitude = 0;
		/** The latitude of the south-west corner of an `Image` overlay. */
		public double MinLatitude
		{
			get { return _minLatitude; }
			set
			{
				if (_minLatitude != value)
				{
					_minLatitude = value;
					SetDirty(_minLatitudeName);
				}
			}
		}

		double _minLongitude = 0;
		/** The longitude of the south-west corner of an `Image` overlay. */
		public double MinLongitude
		{
			get { return _minLongitude; }
			set
			{
				if (_minLongitude != value)
				{
					_minLongitude = value;
					SetDirty(_minLongitudeName);
				}
			}
		}

		double _maxLatitude = 0;
		/** The latitude of the north-east corner of an `Image` overlay. */
		public double MaxLatitude
		{
			get { return _maxLatitude; }
			set
			{
				if (_maxLatitude != value)
				{
					_maxLatitude = value;
					SetDirty(_maxLatitudeName);
				}
			}
		}

		double _maxLongitude = 0;
		/** The longitude of the north-east corner of an `Image` overlay. */
		public double MaxLongitude
		{
			get { return _maxLongitude; }
			set
			{
				if (_maxLongitude != value)
				{
					_maxLongitude = value;
					SetDirty(_maxLongitudeName);
				}
			}
		}

		string _tileUrlTemplate;
		/**
			URL template for an overlay of type `Tile`. Supports the placeholders `{x}`, `{y}` and `{z}`.
		*/
		public string TileUrlTemplate
		{
			get { return _tileUrlTemplate; }
			set
			{
				if (_tileUrlTemplate != value)
				{
					_tileUrlTemplate = value;
					SetDirty(_tileUrlTemplateName);
				}
			}
		}

		int _tileMinZoom = 0;
		/** The lowest zoom level for which tiles are requested. */
		public int TileMinZoom
		{
			get { return _tileMinZoom; }
			set
			{
				if (_tileMinZoom != value)
				{
					_tileMinZoom = value;
					SetDirty(_tileMinZoomName);
				}
			}
		}

		int _tileMaxZoom = 21;
		/** The highest zoom level for which tiles are requested. */
		public int TileMaxZoom
		{
			get { return _tileMaxZoom; }
			set
			{
				if (_tileMaxZoom != value)
				{
					_tileMaxZoom = value;
					SetDirty(_tileMaxZoomName);
				}
			}
		}

		RootableList<MapOverlayHole> _holes = new RootableList<MapOverlayHole>();
		/** Holes cut out of an overlay of type `Polygon`. */
		public IList<MapOverlayHole> Holes
		{
			get
			{
				return _holes;
			}
		}

		void OnHoleAdded(MapOverlayHole hole)
		{
			hole.Owner = this;
			OnCoordinateChange();
		}

		void OnHoleRemoved(MapOverlayHole hole)
		{
			hole.Owner = null;
			OnCoordinateChange();
		}

		internal void NotifyHoleChanged()
		{
			SetDirty(_coordinatesName);
		}

		RootableList<Coordinate> _coordinates = new RootableList<Coordinate>();
		[UXContent]
		public IList<Coordinate> Coordinates
		{
			get
			{
				return _coordinates;
			}
		}

		void OnCoordinateAdded(Coordinate coord)
		{
			coord.AddPropertyListener(this);
			OnCoordinateChange();
		}

		void OnCoordinateRemoved(Coordinate coord)
		{
			coord.RemovePropertyListener(this);
			OnCoordinateChange();
		}

		void OnCoordinateChange()
		{
			if (_coordinates.Count > 0 || _holes.Count > 0)
			{
				SetDirty(_coordinatesName);
			}
		}

		protected override void OnRooted()
		{
			base.OnRooted();
			if (_coordinates != null)
				_coordinates.RootSubscribe(OnCoordinateAdded, OnCoordinateRemoved);
			_holes.RootSubscribe(OnHoleAdded, OnHoleRemoved);
			MapView m = Parent as MapView;
			if (m != null)
				m.AddOverlay(this);
		}

		protected override void OnUnrooted()
		{
			MapView m = Parent as MapView;
			if (m != null)
				m.RemoveOverlay(this);
			if (_coordinates != null)
				_coordinates.Unsubscribe();
			_holes.RootUnsubscribe();
			base.OnUnrooted();
		}

		void MarkDirty()
		{
			MapView m = Parent as MapView;
			if (m != null)
				m.UpdateOverlaysNextFrame();
		}

		public double[] GetCoordinatesArray()
		{
			var items = new double[Coordinates.Count * 2];
			var idx = 0;
			foreach(Coordinate p in Coordinates)
			{
				items[idx] = p.Latitude;
				items[idx + 1] = p.Longitude;
				idx+=2;
			}
			return items;
		}

		/** All hole coordinates concatenated as `latitude, longitude` pairs. */
		public double[] GetHolesCoordinatesArray()
		{
			var count = 0;
			foreach (MapOverlayHole hole in _holes)
				count += hole.Coordinates.Count;

			var items = new double[count * 2];
			var idx = 0;
			foreach (MapOverlayHole hole in _holes)
			{
				foreach (Coordinate c in hole.Coordinates)
				{
					items[idx++] = c.Latitude;
					items[idx++] = c.Longitude;
				}
			}
			return items;
		}

		/** The number of coordinates in each hole, in the same order as `GetHolesCoordinatesArray`. */
		public int[] GetHoleLengthsArray()
		{
			var lengths = new int[_holes.Count];
			for (int i = 0; i < _holes.Count; i++)
				lengths[i] = _holes[i].Coordinates.Count;
			return lengths;
		}
	}
}
