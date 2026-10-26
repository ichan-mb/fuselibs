using Uno;
using Uno.Collections;
using Uno.UX;
using Uno.Threading;
using Fuse.Elements;
using Fuse.Maps;

namespace Fuse.Controls
{

	public enum MapStyle
	{
		Normal,
		Satellite,
		Hybrid,
		Terrain
	}

	internal class MapCameraState
	{
		public double Latitude { get; set; }
		public double Longitude { get; set; }
		public double Bearing { get; set; }
		public double Tilt { get; set; }
		public double Zoom { get; set; }

		public override string ToString()
		{
			return "[MapCameraState Latitude:" + Latitude + " Longitude:" + Longitude
				+ " Bearing:" + Bearing + " Zoom:" + Zoom + " Tilt:" + Tilt + "]";
		}
	}

	internal class MapConfig
	{
		public bool ShowMyLocation { get; set; }
		public bool ShowMyLocationButton { get; set; }
		public bool ShowCompass { get; set; }
		public bool AllowZoom { get; set; }
		public bool AllowTilt { get; set; }
		public bool AllowRotate { get; set; }
		public bool AllowScroll { get; set; }
		public MapStyle Style { get; set; }
		public float4 Padding { get; set; }
		public double MinZoom { get; set; }
		public double MaxZoom { get; set; }

		public MapConfig()
		{
			ShowMyLocation = false;
			ShowMyLocationButton = false;
			ShowCompass = false;
			AllowZoom = AllowTilt = AllowRotate = AllowScroll = true;
			Padding = float4(0);
			MinZoom = 0;
			MaxZoom = 21;
		}

		public void Apply(IMapView mv)
		{
			mv.ShowMyLocation = ShowMyLocation;
			mv.ShowMyLocationButton = ShowMyLocationButton;
			mv.ShowCompass = ShowCompass;
			mv.AllowZoom = AllowZoom;
			mv.AllowTilt = AllowTilt;
			mv.AllowRotate = AllowRotate;
			mv.AllowScroll = AllowScroll;
			mv.Style = Style;
			mv.Padding = Padding;
			mv.MinZoom = MinZoom;
			mv.MaxZoom = MaxZoom;
		}
	}

	/** Displays a native map view.

	@include Docs/Brief.md
	@ux Docs/Example.ux
	@include Docs/ExampleDescription.md

	@seealso Fuse.Controls.MapMarker
	*/
	public partial class MapView : Panel, IMapViewHost
	{
		string _provider;

		/**
			The name of the map provider to use.

			Defaults to the platform's native provider. This must be set before the
			map view is created.
		*/
		public string Provider
		{
			get { return _provider; }
			set
			{
				if (_provider == value) return;

				if (MapViewClient != null)
				{
					Fuse.Diagnostics.UserError("MapView.Provider must be set before the map view is created", this);
					return;
				}

				_provider = value;
			}
		}

		protected override Fuse.Controls.Native.IView CreateNativeView()
		{
			var provider = MapProviders.Resolve(_provider);

			if (provider == null && _provider != null)
				Fuse.Diagnostics.UserError("Unknown map provider '" + _provider + "'", this);

			if (provider == null)
				provider = MapProviders.Resolve(null);

			if (provider == null)
				return base.CreateNativeView();

			var view = provider.Create(this);

			if (view == null)
			{
				var fallback = MapProviders.Resolve(null);
				if (fallback != null && fallback != provider)
					view = fallback.Create(this);
			}

			if (view == null)
				return base.CreateNativeView();

			MapViewClient = view;
			return view;
		}

		/**
			Dispatched when a map marker is tapped.

			*Handler example*
			```JS
			exports.onMarkerTapped = function(args) {
				console.log("Marker tapped: "+args.label);
			}
			```
		*/
		public event MarkerEventHandler MarkerTapped;

		/**
			Dispatched when a map marker is selected (its callout is shown).

			*Handler example*
			```JS
			exports.onMarkerSelected = function(args) {
				console.log("Marker selected: "+args.id);
			}
			```
		*/
		public event MarkerEventHandler MarkerSelected;

		/** Dispatched when a map marker is deselected. */
		public event MarkerEventHandler MarkerDeselected;

		/** Dispatched when the user starts dragging a draggable marker. */
		public event MarkerEventHandler MarkerDragStarted;

		/** Dispatched continuously while the user drags a draggable marker. */
		public event MarkerEventHandler MarkerDragged;

		/** Dispatched when the user stops dragging a draggable marker. `Latitude` and `Longitude` are updated on the marker. */
		public event MarkerEventHandler MarkerDragEnded;

		/**
			Dispatched when the visible geographical area of the map changes.

			*Handler example*
			```JS
			exports.onBoundsChanged = function(args) {
				console.log(args.minLatitude + ", " + args.minLongitude);
			}
			```
		*/
		public event MapBoundsEventHandler BoundsChanged;

		/**
			Dispatched when a map location is tapped.

			*Handler example*
			```JS
			exports.onTapped = function(args) {
				console.log("Map tapped: "+args.latitude+", "+args.longitude);
			}
			```
		*/
		public event MapEventHandler LocationTapped;

		/**
			Dispatched when a map location is pressed and held.

			*Handler example*
			```JS
			exports.onLongPress = function(args) {
				console.log("Map longpresed: "+args.latitude+", "+args.longitude);
			}
			```
		*/
		public event MapEventHandler LocationLongPressed;

		/**
			Dispatched once the native map has finished loading and is ready to be used.

			*Handler example*
			```JS
			exports.onReady = function() {
				console.log("Map is ready");
			}
			```
		*/
		public event EventHandler Ready;

		MapConfig _mapConfig;
		MapCameraState _cameraState;
		public MapView()
		{
			if defined(!MOBILE)
			{
				Background = new Fuse.Drawing.SolidColor(float4(0.6f,0.6f,0.6f,1.0f));
				var t = new Fuse.Controls.Text();
				t.Alignment = Alignment.Center;
				t.SetValue("MapView requires a mobile target.", this);
				t.TextAlignment = TextAlignment.Center;
				Children.Add(t);
			}
			_cameraState = new MapCameraState();
			_mapConfig = new MapConfig();
		}

		internal ObservableList<MapOverlay> _overlays;
		public ObservableList<MapOverlay> Overlays
		{
			get
			{
				if (_overlays==null) _overlays = new ObservableList<MapOverlay>(OnOverlayAdded, OnOverlayRemoved);
				return _overlays;
			}
		}


		internal void AddOverlay(MapOverlay p)
		{
			if (Overlays.Contains(p)) return;
			Overlays.Add(p);
		}

		internal void RemoveOverlay(MapOverlay p)
		{
			Overlays.Remove(p);
		}

		public void ClearOverlays(){
			if (_overlays == null) return;
			_overlays.Clear();
			UpdateOverlays();
		}

		void OnOverlayAdded(MapOverlay overlay)
		{
			UpdateOverlaysNextFrame();
		}

		void OnOverlayRemoved(MapOverlay overlay)
		{
			UpdateOverlaysNextFrame();
		}

		bool _willUpdateOverlaysNextFrame;
		internal void UpdateOverlaysNextFrame()
		{
			if (!MapIsReady || _willUpdateOverlaysNextFrame) return;
			UpdateManager.PerformNextFrame(DeferredOverlayUpdate, UpdateStage.Primary);
			_willUpdateOverlaysNextFrame = true;
		}

		void DeferredOverlayUpdate()
		{
			_willUpdateOverlaysNextFrame = false;
			UpdateOverlays();
		}

		void UpdateOverlays()
		{
			if (MapIsReady)
				MapViewClient.UpdateOverlays();
		}

		internal ObservableList<MapRoute> _routes;
		/** The routes calculated and drawn by this map. */
		public ObservableList<MapRoute> Routes
		{
			get
			{
				if (_routes == null) _routes = new ObservableList<MapRoute>(OnRouteAdded, OnRouteRemoved);
				return _routes;
			}
		}

		internal void AddRoute(MapRoute route)
		{
			if (Routes.Contains(route)) return;
			Routes.Add(route);
		}

		internal void RemoveRoute(MapRoute route)
		{
			Routes.Remove(route);
		}

		/** Removes all routes from the map. */
		public void ClearRoutes()
		{
			if (_routes == null) return;
			_routes.Clear();
			UpdateRoutes();
		}

		void OnRouteAdded(MapRoute route)
		{
			UpdateRoutesNextFrame();
		}

		void OnRouteRemoved(MapRoute route)
		{
			UpdateRoutesNextFrame();
		}

		bool _willUpdateRoutesNextFrame;
		internal void UpdateRoutesNextFrame()
		{
			if (!MapIsReady || _willUpdateRoutesNextFrame) return;
			UpdateManager.PerformNextFrame(DeferredRouteUpdate, UpdateStage.Primary);
			_willUpdateRoutesNextFrame = true;
		}

		void DeferredRouteUpdate()
		{
			_willUpdateRoutesNextFrame = false;
			UpdateRoutes();
		}

		void UpdateRoutes()
		{
			if (MapIsReady)
				MapViewClient.UpdateRoutes();
		}

		MapRoute FindRoute(int uid)
		{
			if (_routes == null) return null;

			foreach (MapRoute route in _routes)
			{
				if (route.Uid == uid)
					return route;
			}

			return null;
		}

		void IMapViewHost.OnRouteResult(int uid, int generation, string encoded)
		{
			var route = FindRoute(uid);
			if (route == null) return;

			var result = MapRouteResult.Parse(encoded);
			if (result == null)
				route.SetError(generation, "Could not calculate the route");
			else
				route.SetResult(generation, result.Polyline, result.Distance, result.Duration);

			UpdateRoutesNextFrame();
		}

		void IMapViewHost.OnRouteError(int uid, int generation, string message)
		{
			var route = FindRoute(uid);
			if (route != null)
				route.SetError(generation, message);

			UpdateRoutesNextFrame();
		}

		void ShowAllMarkers()
		{
			RunWhenReady(ShowAllMarkersWhenReady);
		}

		void ShowAllMarkersWhenReady()
		{
			if (MapViewClient != null)
				MapViewClient.ShowAllMarkers();
		}

		void Snapshot(Action<string> actionSucces, Action<string> actionError)
		{
			var command = new SnapshotCommand(this, actionSucces, actionError);
			RunWhenReady(command.Execute, actionError);
		}

		class SnapshotCommand
		{
			readonly MapView _mapView;
			readonly Action<string> _success;
			readonly Action<string> _error;

			public SnapshotCommand(MapView mapView, Action<string> success, Action<string> error)
			{
				_mapView = mapView;
				_success = success;
				_error = error;
			}

			public void Execute()
			{
				if (_mapView.MapViewClient != null)
					_mapView.MapViewClient.Snapshot(_success, _error);
			}
		}

		List<PendingReadyAction> _pendingReadyActions;

		class PendingReadyAction
		{
			public readonly Action Execute;
			public readonly Action<string> Cancel;

			public PendingReadyAction(Action execute, Action<string> cancel)
			{
				Execute = execute;
				Cancel = cancel;
			}
		}

		/** Runs the action immediately when the map is ready, otherwise defers it until it becomes ready. */
		void RunWhenReady(Action action)
		{
			RunWhenReady(action, null);
		}

		void RunWhenReady(Action action, Action<string> cancel)
		{
			if (action == null) return;

			if (MapIsReady)
			{
				action();
				return;
			}

			if (_pendingReadyActions == null)
				_pendingReadyActions = new List<PendingReadyAction>();
			_pendingReadyActions.Add(new PendingReadyAction(action, cancel));
		}

		void FlushPendingReadyActions()
		{
			if (_pendingReadyActions == null) return;

			var actions = _pendingReadyActions;
			_pendingReadyActions = null;
			foreach (var action in actions)
				action.Execute();
		}

		void ClearPendingReadyActions()
		{
			if (_pendingReadyActions == null) return;

			var actions = _pendingReadyActions;
			_pendingReadyActions = null;
			foreach (var action in actions)
			{
				if (action.Cancel != null)
					action.Cancel("MapView was disposed before it became ready");
			}
		}

		internal ObservableList<MapMarker> _markers;
		public ObservableList<MapMarker> Markers
		{
			get
			{
				if (_markers==null) _markers = new ObservableList<MapMarker>(OnMarkerAdded, OnMarkerRemoved);
				return _markers;
			}
		}


		internal void AddMarker(MapMarker m)
		{
			if (Markers.Contains(m)) return;
			Markers.Add(m);
		}

		internal void RemoveMarker(MapMarker m)
		{
			Markers.Remove(m);
		}

		void OnMarkerAdded(MapMarker marker)
		{
			UpdateMarkersNextFrame();
		}

		void OnMarkerRemoved(MapMarker marker)
		{
			UpdateMarkersNextFrame();
		}

		public void ClearMarkers(){
			if (_markers == null) return;
			_markers.Clear();
			UpdateMarkers();
		}

		bool _willUpdateMarkersNextFrame;
		internal void UpdateMarkersNextFrame()
		{
			if (!MapIsReady || _willUpdateMarkersNextFrame) return;
			UpdateManager.PerformNextFrame(DeferredMarkerUpdate, UpdateStage.Primary);
			_willUpdateMarkersNextFrame = true;
		}

		void DeferredMarkerUpdate()
		{
			_willUpdateMarkersNextFrame = false;
			UpdateMarkers();
		}

		bool _willUpdateCameraNextFrame;
		internal void UpdateCameraNextFrame()
		{
			if (!MapIsReady || _willUpdateCameraNextFrame) return;
			UpdateManager.PerformNextFrame(ApplyCameraState, UpdateStage.Primary);
			_willUpdateCameraNextFrame = true;
		}

		void ApplyCameraState()
		{
			_willUpdateCameraNextFrame = false;
			if (MapIsReady)
				MapViewClient.MoveTo(Latitude, Longitude, Zoom, Tilt, Bearing);
		}

		internal void UpdateMarkers()
		{
			if (MapIsReady)
				MapViewClient.UpdateMarkers();
		}

		IMapView _mapViewClient;
		internal IMapView MapViewClient
		{
			get { return _mapViewClient; }
			set
			{
				_mapViewClient = value;
				if (_mapViewClient == null)
				{
					_mapReady = false;
					ClearPendingReadyActions();
					OnPropertyChanged(_isReadyName, this);
					return;
				}

				MapViewClient.OnReady = OnMapReady;

				_mapConfig.Apply(MapViewClient);

			}
		}

		bool _mapReady = false;
		void OnMapReady()
		{
			if (MapViewClient == null) return;
			_mapReady = true;
			MapViewClient.OnReady = null;
			ApplyCameraState();
			UpdateRestState();
			UpdateMarkers();
			UpdateOverlays();
			UpdateRoutes();
			SyncVisibleBounds();
			OnPropertyChanged(_isReadyName, this);
			FlushPendingReadyActions();
			if (Ready != null)
				Ready(this, new EventArgs());
		}

		/* Provider callbacks */

		MapMarker FindMarker(int id)
		{
			if (_markers == null) return null;

			foreach (MapMarker marker in _markers)
			{
				if (marker.uid == id)
					return marker;
			}

			return null;
		}

		void IMapViewHost.OnViewDisposed(IMapView view)
		{
			if (MapViewClient == view)
				MapViewClient = null;
		}

		void IMapViewHost.OnCameraChanged()
		{
			SyncCameraFromMap();
		}

		void IMapViewHost.OnMarkerTapped(int id, string label)
		{
			var marker = FindMarker(id);

			if (MarkerTapped != null)
				MarkerTapped(this, new MarkerEventArgs(marker, id, label));

			if (marker != null)
				marker.HandleTapped();
		}

		void IMapViewHost.OnMarkerSelected(int id)
		{
			var marker = FindMarker(id);

			if (marker != null)
				marker.HandleSelected();

			if (MarkerSelected != null)
				MarkerSelected(this, new MarkerEventArgs(marker, id, marker != null ? marker.Label : null));
		}

		void IMapViewHost.OnMarkerDeselected(int id)
		{
			var marker = FindMarker(id);

			if (marker != null)
				marker.HandleDeselected();

			if (MarkerDeselected != null)
				MarkerDeselected(this, new MarkerEventArgs(marker, id, marker != null ? marker.Label : null));
		}

		void IMapViewHost.OnMarkerDragStarted(int id)
		{
			var marker = FindMarker(id);

			if (marker != null)
				marker.HandleDragStarted();

			if (MarkerDragStarted != null)
				MarkerDragStarted(this, new MarkerEventArgs(marker, id, marker != null ? marker.Label : null));
		}

		void IMapViewHost.OnMarkerDragging(int id, double latitude, double longitude)
		{
			var marker = FindMarker(id);

			if (marker != null)
				marker.HandleDragging(latitude, longitude);

			if (MarkerDragged != null)
				MarkerDragged(this, new MarkerEventArgs(marker, id, marker != null ? marker.Label : null));
		}

		void IMapViewHost.OnMarkerDragEnded(int id, double latitude, double longitude)
		{
			var marker = FindMarker(id);

			if (marker != null)
				marker.HandleDragEnded(latitude, longitude);

			if (MarkerDragEnded != null)
				MarkerDragEnded(this, new MarkerEventArgs(marker, id, marker != null ? marker.Label : null));
		}

		/** Selects the given marker, showing its callout. */
		public void SelectMarker(MapMarker marker)
		{
			if (!MapIsReady || marker == null) return;
			MapViewClient.SelectMarker(marker.uid);
		}

		/** Deselects the given marker, hiding its callout. */
		public void DeselectMarker(MapMarker marker)
		{
			if (!MapIsReady || marker == null) return;
			MapViewClient.DeselectMarker(marker.uid);
		}

		void IMapViewHost.OnOverlayTapped(int id)
		{
			foreach (MapOverlay overlay in Overlays)
			{
				if (overlay.Uid == id)
				{
					overlay.HandleTapped();
					return;
				}
			}
		}

		void IMapViewHost.OnLocationTapped(double latitude, double longitude)
		{
			if (LocationTapped != null)
				LocationTapped(this, new MapEventArgs(latitude, longitude));
		}

		void IMapViewHost.OnLocationLongPress(double latitude, double longitude)
		{
			if (LocationLongPressed != null)
				LocationLongPressed(this, new MapEventArgs(latitude, longitude));
		}

		internal void UpdateRestState()
		{
			OnPropertyChanged(_latitudeName, this);
			OnPropertyChanged(_longitudeName, this);
			OnPropertyChanged(_zoomName, this);
			OnPropertyChanged(_bearingName, this);
			OnPropertyChanged(_tiltName, this);
		}

		public void SetLocation(double latitude, double longitude)
		{
			Latitude = latitude;
			Longitude = longitude;
		}

		MapBounds _visibleBounds = new MapBounds();
		/** The geographical area currently visible on the map. */
		public MapBounds VisibleBounds
		{
			get { return _visibleBounds; }
		}

		/** Moves the camera to the given position over the given number of seconds. */
		public void AnimateTo(double latitude, double longitude, double zoom, double tilt, double bearing, double duration)
		{
			if (!MapIsReady) return;
			MapViewClient.AnimateTo(latitude, longitude, zoom, tilt, bearing, duration);
		}

		/** Cancels an ongoing camera animation. */
		public void CancelAnimation()
		{
			if (!MapIsReady) return;
			MapViewClient.CancelAnimation();
		}

		/** Moves the camera so the given area fits in the view, taking `MapPadding` into account. */
		public void ShowBounds(double minLatitude, double minLongitude, double maxLatitude, double maxLongitude)
		{
			if (!MapIsReady) return;
			MapViewClient.ShowBounds(minLatitude, minLongitude, maxLatitude, maxLongitude);
		}

		/** Moves the camera so the given area fits in the view, taking `MapPadding` into account. */
		public void ShowBounds(MapBounds bounds)
		{
			if (bounds == null) return;
			ShowBounds(bounds.MinLatitude, bounds.MinLongitude, bounds.MaxLatitude, bounds.MaxLongitude);
		}

		/** Changes the zoom level by the given amount. */
		public void ZoomBy(double delta)
		{
			if (!MapIsReady) return;
			MapViewClient.ZoomBy(delta, 0.0);
		}

		/** Pans the map by the given number of points. */
		public void ScrollBy(float dx, float dy)
		{
			if (!MapIsReady) return;
			MapViewClient.ScrollBy(dx, dy, 0.0);
		}

		/**
			Looks up the given address and returns the matching places.
		*/
		public Future<MapPlace[]> Geocode(string query)
		{
			if (MapViewClient == null)
				return RejectedFuture<MapPlace[]>("MapView is not ready");

			return MapViewClient.Geocode(query);
		}

		/**
			Returns the places at or near the given coordinates.
		*/
		public Future<MapPlace[]> ReverseGeocode(double latitude, double longitude)
		{
			if (MapViewClient == null)
				return RejectedFuture<MapPlace[]>("MapView is not ready");

			return MapViewClient.ReverseGeocode(latitude, longitude);
		}

		/**
			Calculates a route between two points. The result contains the route geometry, distance in
			meters and estimated duration in seconds. The geometry can be drawn with @MapOverlay.
		*/
		public Future<MapRouteResult> CalculateRoute(double fromLatitude, double fromLongitude, double toLatitude, double toLongitude, RouteMode mode)
		{
			if (MapViewClient == null)
				return RejectedFuture<MapRouteResult>("MapView is not ready");

			return MapViewClient.CalculateRoute(fromLatitude, fromLongitude, toLatitude, toLongitude, mode);
		}

		static Future<T> RejectedFuture<T>(string message)
		{
			var promise = new Promise<T>();
			promise.Reject(new Exception(message));
			return promise;
		}

		bool MapIsReady
		{
			get {
				return _mapReady;
			}
		}

		Selector _isReadyName = "IsReady";

		/** `true` once the native map has finished loading and is ready to be used. */
		public bool IsReady
		{
			get { return MapIsReady; }
		}

		/** Copies the camera state back from the native map and notifies bindings when it actually changed. */
		internal void SyncCameraFromMap()
		{
			if (!MapIsReady || MapViewClient == null) return;

			SyncVisibleBounds();

			var client = MapViewClient;
			var latitude = client.Latitude;
			var longitude = client.Longitude;
			var zoom = client.Zoom;
			var tilt = client.Tilt;
			var bearing = client.Bearing;

			bool changed =
				Math.Abs(latitude - _cameraState.Latitude) > 0.000001 ||
				Math.Abs(longitude - _cameraState.Longitude) > 0.000001 ||
				Math.Abs(zoom - _cameraState.Zoom) > 0.001 ||
				Math.Abs(tilt - _cameraState.Tilt) > 0.001 ||
				Math.Abs(bearing - _cameraState.Bearing) > 0.001;

			if (!changed) return;

			_cameraState.Latitude = latitude;
			_cameraState.Longitude = longitude;
			_cameraState.Zoom = zoom;
			_cameraState.Tilt = tilt;
			_cameraState.Bearing = bearing;
			UpdateRestState();
		}

		void SyncVisibleBounds()
		{
			if (!MapIsReady || MapViewClient == null) return;

			var bounds = MapViewClient.GetVisibleBounds();
			if (bounds == null) return;

			if (bounds.MinLatitude == _visibleBounds.MinLatitude &&
				bounds.MinLongitude == _visibleBounds.MinLongitude &&
				bounds.MaxLatitude == _visibleBounds.MaxLatitude &&
				bounds.MaxLongitude == _visibleBounds.MaxLongitude)
				return;

			_visibleBounds.MinLatitude = bounds.MinLatitude;
			_visibleBounds.MinLongitude = bounds.MinLongitude;
			_visibleBounds.MaxLatitude = bounds.MaxLatitude;
			_visibleBounds.MaxLongitude = bounds.MaxLongitude;

			if (BoundsChanged != null)
				BoundsChanged(this, new MapBoundsEventArgs(_visibleBounds));
		}

		/** `True` if the user's geographical location should be visible on the map. */
		public bool ShowMyLocation {
			get { return _mapConfig.ShowMyLocation; }
			set {
				_mapConfig.ShowMyLocation = value;
				if (MapIsReady)
					MapViewClient.ShowMyLocation = _mapConfig.ShowMyLocation;
			}
		}
		/** When `true`, MapView will display a button that focuses the camera on the user's geographical location.

			> *Note:* The [ShowMyLocation](api:fuse/controls/mapview/showmylocation) property must be `True` for this to have an effect.
		*/
		public bool ShowMyLocationButton {
			get { return _mapConfig.ShowMyLocationButton; }
			set {
				_mapConfig.ShowMyLocationButton = value;
				if (MapIsReady)
					MapViewClient.ShowMyLocationButton = _mapConfig.ShowMyLocationButton;
			}
		}
		/** When `True`, a compass will be shown on the map. */
		public bool ShowCompass {
			get { return _mapConfig.ShowCompass; }
			set {
				_mapConfig.ShowCompass = value;
				if (MapIsReady)
					MapViewClient.ShowCompass = _mapConfig.ShowCompass;
			}
		}
		/** Specifies whether the user is allowed to zoom the map.
			The zoom level can still be changed using the [Zoom](api:fuse/controls/mapview/zoom) property.
		*/
		public bool AllowZoom {
			get { return _mapConfig.AllowZoom; }
			set {
				_mapConfig.AllowZoom = value;
				if (MapIsReady)
					MapViewClient.AllowZoom = _mapConfig.AllowZoom;
			}
		}
		/** Specifies whether the user is allowed to tilt the map.
			The tilt angle can still be changed using the [Tilt](api:fuse/controls/mapview/tilt) property.
		*/
		public bool AllowTilt {
			get { return _mapConfig.AllowTilt; }
			set {
				_mapConfig.AllowTilt = value;
				if (MapIsReady)
					MapViewClient.AllowTilt = _mapConfig.AllowTilt;
			}
		}
		/** Specifies whether the user is allowed to rotate the map.
			The bearing can still be changed using the [Bearing](api:fuse/controls/mapview/bearing) property.
		*/
		public bool AllowRotate {
			get { return _mapConfig.AllowRotate; }
			set {
				_mapConfig.AllowRotate = value;
				if (MapIsReady)
					MapViewClient.AllowRotate = _mapConfig.AllowRotate;
			}
		}

		/** Specifies whether the user is allowed to scroll the map.
			The position can still be modified by the API.
		*/
		public bool AllowScroll {
			get { return _mapConfig.AllowScroll; }
			set {
				_mapConfig.AllowScroll = value;
				if (MapIsReady)
					MapViewClient.AllowScroll = _mapConfig.AllowScroll;
			}
		}

		/** The rendering style of the map (`Normal`, `Satellite`, `Hybrid` or `Terrain`).
			`Terrain` falls back to `Normal` on native iOS maps, which do not expose a terrain style.
		*/
		public MapStyle Style
		{
			get { return _mapConfig.Style; }
			set {
				_mapConfig.Style = value;
				if (MapIsReady)
					MapViewClient.Style = _mapConfig.Style;
			}
		}

		/**
			Padding between the edges of the map and its camera target, in points, stored as
			`(left, top, right, bottom)`. Useful when toolbars or sheets cover part of the map.

			This is separate from the layout `Padding` inherited from `Element`.
		*/
		public float4 MapPadding
		{
			get { return _mapConfig.Padding; }
			set {
				_mapConfig.Padding = value;
				if (MapIsReady)
					MapViewClient.Padding = _mapConfig.Padding;
			}
		}

		/** The lowest zoom level the camera can reach. Defaults to `0`. */
		public double MinZoom
		{
			get { return _mapConfig.MinZoom; }
			set {
				_mapConfig.MinZoom = value;
				if (MapIsReady)
					MapViewClient.MinZoom = _mapConfig.MinZoom;
			}
		}

		/** The highest zoom level the camera can reach. Defaults to `21`. */
		public double MaxZoom
		{
			get { return _mapConfig.MaxZoom; }
			set {
				_mapConfig.MaxZoom = value;
				if (MapIsReady)
					MapViewClient.MaxZoom = _mapConfig.MaxZoom;
			}
		}

		Selector _tiltName = "Tilt";

		[UXOriginSetter("SetTilt")]
		/** The angle of rotation around the X axis, measured in degrees. */
		public double Tilt
		{
			get { return _cameraState.Tilt; }
			set { SetTilt(value, this);	}
		}

		public void SetTilt(double value, IPropertyListener origin)
		{
			_cameraState.Tilt = value;
			UpdateCameraNextFrame();
			OnPropertyChanged(_tiltName, origin);
		}

		Selector _bearingName = "Bearing";

		[UXOriginSetter("SetBearing")]
		/** The bearing of the map relative to true north, in degrees. */
		public double Bearing
		{
			get { return _cameraState.Bearing; }
			set { SetBearing(value, this);	}
		}

		public void SetBearing(double value, IPropertyListener origin)
		{
			_cameraState.Bearing = value;
			UpdateCameraNextFrame();
			OnPropertyChanged(_bearingName, origin);
		}

		Selector _zoomName = "Zoom";

		[UXOriginSetter("SetZoom")]
		/** The zoom level of the camera. Corresponds to [Google Maps' Zoom Levels](https://developers.google.com/maps/documentation/static-maps/intro#Zoomlevels). */
		public double Zoom
		{
			get { return _cameraState.Zoom; }
			set { SetZoom(value, this);	}
		}

		public void SetZoom(double value, IPropertyListener origin)
		{
			_cameraState.Zoom = value;
			UpdateCameraNextFrame();
			OnPropertyChanged(_zoomName, origin);
		}

		/**
			Latitude
		**/
		Selector _latitudeName = "Latitude";

		[UXOriginSetter("SetLatitude")]
		/** The latitude coordinate. */
		public double Latitude
		{
			get { return _cameraState.Latitude; }
			set { SetLatitude(value, this);	}
		}

		public void SetLatitude(double value, IPropertyListener origin)
		{
			_cameraState.Latitude = value;
			UpdateCameraNextFrame();
			OnPropertyChanged(_latitudeName, origin);
		}

		Selector _longitudeName = "Longitude";

		[UXOriginSetter("SetLongitude")]
		/** The longitude coordinate. */
		public double Longitude
		{
			get { return _cameraState.Longitude; }
			set { SetLongitude(value, this);	}
		}

		public void SetLongitude(double value, IPropertyListener origin)
		{
			_cameraState.Longitude = value;
			UpdateCameraNextFrame();
			OnPropertyChanged(_longitudeName, origin);
		}
	}
}
