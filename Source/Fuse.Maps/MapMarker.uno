using Fuse.Elements;
using Uno.UX;
using Uno;
namespace Fuse.Controls
{
	/** Adds a map marker to a @MapView

	To annotate the map, you must decorate it with `MapMarker` nodes. `MapMarker` nodes are simple value objects that contain a `Latitude`, a `Longitude` and a `Label`

	```HTML
	<NativeViewHost>
		<MapView>
			<MapMarker Label="Fuse HQ" Latitude="59.9115573" Longitude="10.73888" />
		</MapView>
	</NativeViewHost>
	```

	If you need to generate MapMarkers dynamically from JS, data binding and @(Each) are your friends. While we're scripting we might as well hook into the MapMarker's `Tapped` event to detect when the user has selected a marker.

	```HTML
	<JavaScript>
		var Observable = require("FuseJS/Observable");
		module.exports = {
			markers : Observable({latitude:30.282786, longitude:-97.741736, label:"Austin, Texas", hometown:true}),
			onMarkerTapped : function(args) {
				console.log("Marker tapped: "+args.data.hometown);
			}
		}
	</JavaScript>

	<NativeViewHost>
		<MapView>
			<Each Items={markers}>
				<MapMarker Latitude="{latitude}" Longitude="{longitude}" Label="{label}" Tapped={onMarkerTapped} />
			</Each>
		</MapView>
	</NativeViewHost>
	```

	@seealso Fuse.Controls.MapView
	*/
	public class MapMarker : Node
	{
		static int UID_POOL = 0;
		internal int uid = UID_POOL++;
		public delegate void MarkerTappedHandler(object sender, EventArgs args);
		public event MarkerTappedHandler Tapped;

		/** Dispatched when the user starts dragging this marker. */
		public event MarkerEventHandler DragStarted;
		/** Dispatched continuously while the user drags this marker. */
		public event MarkerEventHandler Dragging;
		/** Dispatched when the user stops dragging this marker, after `Latitude` and `Longitude` have been updated. */
		public event MarkerEventHandler DragEnded;
		/** Dispatched when this marker is selected. */
		public event MarkerEventHandler Selected;
		/** Dispatched when this marker is deselected. */
		public event MarkerEventHandler Deselected;

		internal MarkerEventArgs CreateEventArgs()
		{
			return new MarkerEventArgs(this);
		}

		internal void HandleTapped()
		{
			if (Tapped != null)
				Tapped(this, CreateEventArgs());
		}

		internal void HandleDragStarted()
		{
			if (DragStarted != null)
				DragStarted(this, CreateEventArgs());
		}

		internal void HandleDragging(double latitude, double longitude)
		{
			// Update silently; bindings are notified once the drag ends.
			_latitude = latitude;
			_longitude = longitude;

			if (Dragging != null)
				Dragging(this, CreateEventArgs());
		}

		internal void HandleDragEnded(double latitude, double longitude)
		{
			_latitude = latitude;
			_longitude = longitude;

			OnPropertyChanged(_latitudeName);
			OnPropertyChanged(_longitudeName);

			if (DragEnded != null)
				DragEnded(this, CreateEventArgs());
		}

		internal void HandleSelected()
		{
			if (Selected != null)
				Selected(this, CreateEventArgs());
		}

		internal void HandleDeselected()
		{
			if (Deselected != null)
				Deselected(this, CreateEventArgs());
		}

		string _label;
		public string Label {
			get
			{
				return _label;
			}
			set
			{
				_label = value;
				MarkDirty();
			}
		}

		double _latitude;
		static Selector _latitudeName = "Latitude";
		/**
			The latitude coordinate of this marker
		*/
		public double Latitude {
			get
			{
				return _latitude;
			}
			set
			{
				if (_latitude == value) return;
				_latitude = value;
				MarkDirty();
			}
		}

		double _longitude;
		static Selector _longitudeName = "Longitude";
		/**
			The longitude coordinate of this marker
		*/
		public double Longitude {
			get
			{
				return _longitude;
			}
			set
			{
				if (_longitude == value) return;
				_longitude = value;
				MarkDirty();
			}
		}

		FileSource _icon;
		/**
			The asset image file to use as the marker icon override
		*/
		public FileSource IconFile
		{
			get {
				return _icon;
			}
			set {
				_icon = value;
				MarkDirty();
			}
		}

		float2 _iconAnchor = float2(0.5f, 0.5f);
		/**
			The normalized X-position of the Icon image to use as the icon/map contact point
		*/
		public float IconAnchorX
		{
			get { return _iconAnchor.X; }
			set { _iconAnchor.X = value; MarkDirty(); }
		}

		/**
			The normalized Y-position of the Icon image to use as the icon/map contact point
		*/
		public float IconAnchorY
		{
			get { return _iconAnchor.Y; }
			set { _iconAnchor.Y = value; MarkDirty(); }
		}

		protected override void OnRooted()
		{
			base.OnRooted();
			MapView m = Parent as MapView;
			if (m != null) m.AddMarker(this);
		}

		string _snippet;
		/**
			Extra text displayed in the marker's callout, below the `Label`.
		*/
		public string Snippet
		{
			get { return _snippet; }
			set
			{
				_snippet = value;
				MarkDirty();
			}
		}

		float4 _color = float4(0, 0, 0, 0);
		/**
			Tint color of the default marker icon. Ignored when `IconFile` is set.
			A fully transparent color (the default) means the platform's default marker color.
		*/
		public float4 Color
		{
			get { return _color; }
			set
			{
				_color = value;
				MarkDirty();
			}
		}

		bool _draggable;
		/**
			Specifies whether the user is allowed to drag this marker. When the user drags it,
			`Latitude` and `Longitude` are updated and `DragStarted`, `Dragging` and `DragEnded` are dispatched.
		*/
		public bool Draggable
		{
			get { return _draggable; }
			set
			{
				_draggable = value;
				MarkDirty();
			}
		}

		protected override void OnUnrooted()
		{
			base.OnUnrooted();
			MapView m = Parent as MapView;
			if (m != null) m.RemoveMarker(this);
		}

		void MarkDirty()
		{
			MapView m = Parent as MapView;
			if (m != null) m.UpdateMarkersNextFrame();
		}
	}
}
