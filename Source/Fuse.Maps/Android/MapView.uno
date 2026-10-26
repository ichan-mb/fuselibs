using Uno;
using Uno.Collections;
using Uno.Threading;
using Fuse.Controls;
using Fuse.Android.Permissions;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Maps.Android
{
	[Require("gradle.dependency.implementation", "com.google.android.gms:play-services-maps:17.0.0")]
	extern (Android) public class MapView : Fuse.Controls.Native.Android.LeafView, IMapView
	{
		public bool IsReady { get; private set; }
		public Action OnReady { get; set; }
		MarkerIconCache _markerGraphicsCache;

		public static MapView Create(IMapViewHost host)
		{
			var m = ForeignHelpers.CreateMap();
			return new MapView(host, m);
		}

		Java.Object _mapView;
		IMapViewHost _host;

		MapView(IMapViewHost host, Java.Object map) : base(map)
		{
			IsReady = false;
			_mapView = map;
			_host = host;
			_markerGraphicsCache = new MarkerIconCache(UpdateMarkers);
			ForeignHelpers.SetMapEventHandlers(
				_mapView,
				OnMapReady,
				OnLocationLongPress,
				OnLocationTapped,
				OnCameraIdle,
				OnMarkerTapped,
				OnOverlayTapped,
				OnMarkerSelected,
				OnMarkerDeselected,
				OnMarkerDragStarted,
				OnMarkerDragging,
				OnMarkerDragEnded
				);
			ForeignHelpers.Configure(_mapView);

			Fuse.Platform.Lifecycle.EnteringForeground += OnEnteringForeground;
			Fuse.Platform.Lifecycle.EnteringBackground += OnEnteringBackground;
		}

		void OnEnteringForeground(Fuse.Platform.ApplicationState state)
		{
			if (_mapView != null)
				ForeignHelpers.Resume(_mapView);
		}

		void OnEnteringBackground(Fuse.Platform.ApplicationState state)
		{
			if (_mapView != null)
				ForeignHelpers.Pause(_mapView);
		}

		public override void Dispose()
		{
			Fuse.Platform.Lifecycle.EnteringForeground -= OnEnteringForeground;
			Fuse.Platform.Lifecycle.EnteringBackground -= OnEnteringBackground;

			IsReady = false;
			_markerStates.Clear();

			if (_mapView != null)
				ForeignHelpers.Destroy(_mapView);
			_mapView = null;

			var host = _host;
			_host = null;
			if (host != null)
				host.OnViewDisposed(this);

			base.Dispose();
		}

		void OnCameraIdle()
		{
			if (_host != null)
				_host.OnCameraChanged();
		}

		void OnLocationTapped(double latitude, double longitude)
		{
			if (_host != null)
				_host.OnLocationTapped(latitude, longitude);
		}

		void OnLocationLongPress(double latitude, double longitude)
		{
			if (_host != null)
				_host.OnLocationLongPress(latitude, longitude);
		}

		void OnMarkerTapped(int uid, string title)
		{
			if (_host != null)
				_host.OnMarkerTapped(uid, title);
		}

		void OnMarkerSelected(int uid)
		{
			if (_host != null)
				_host.OnMarkerSelected(uid);
		}

		void OnMarkerDeselected(int uid)
		{
			if (_host != null)
				_host.OnMarkerDeselected(uid);
		}

		void OnMarkerDragStarted(int uid)
		{
			if (_host != null)
				_host.OnMarkerDragStarted(uid);
		}

		void OnMarkerDragging(int uid, double latitude, double longitude)
		{
			if (_host != null)
				_host.OnMarkerDragging(uid, latitude, longitude);
		}

		void OnMarkerDragEnded(int uid, double latitude, double longitude)
		{
			if (_host != null)
				_host.OnMarkerDragEnded(uid, latitude, longitude);
		}

		void OnOverlayTapped(int id)
		{
			if (_host != null)
				_host.OnOverlayTapped(id);
		}

		internal void OnMapReady()
		{
			//Apply buffered props
			IsReady = true;
			Style = _mapStyleInternal;
			ShowMyLocation = _showLocation;
			ConfigUI();
			ConfigGestures();
			ApplyPadding();
			ApplyZoomLimits();
			UpdateMarkers();
			UpdateOverlays();
			if (OnReady != null)
				OnReady();
		}

		MapStyle _mapStyleInternal;
		public MapStyle Style
		{
			get { return _mapStyleInternal; }
			set
			{
				_mapStyleInternal = value;
				if (IsReady)
					switch(_mapStyleInternal)
					{
						case MapStyle.Satellite:
							ForeignHelpers.SetSatelliteStyle(_mapView);
						break;
						case MapStyle.Hybrid:
							ForeignHelpers.SetHybridStyle(_mapView);
						break;
						case MapStyle.Terrain:
							ForeignHelpers.SetTerrainStyle(_mapView);
						break;
						default:
							ForeignHelpers.SetNormalStyle(_mapView);
						break;
					}
			}
		}

		public double Zoom
		{
			get {
				if (!IsReady) return 0.0;
				return ForeignHelpers.GetZoom(_mapView);
			}
		}

		Dictionary<int, MarkerState> _markerStates = new Dictionary<int, MarkerState>();
		List<int> _removedMarkerUids = new List<int>();

		public void UpdateMarkers(){
			if (!IsReady || _mapView == null || _host == null) return;

			var markers = _host.Markers;

			var currentUids = new HashSet<int>();
			foreach (MapMarker marker in markers)
				currentUids.Add(marker.uid);

			_removedMarkerUids.Clear();
			foreach (var pair in _markerStates)
			{
				if (!currentUids.Contains(pair.Key))
					_removedMarkerUids.Add(pair.Key);
			}

			foreach (var uid in _removedMarkerUids)
			{
				ForeignHelpers.RemoveMarker(_mapView, uid);
				_markerStates.Remove(uid);
			}

			foreach (MapMarker m in markers)
			{
				var state = MarkerState.From(m, _markerGraphicsCache.Get(m.IconFile));

				MarkerState previous;
				if (_markerStates.TryGetValue(m.uid, out previous))
				{
					if (!state.Differs(previous))
						continue;

					ForeignHelpers.UpdateMarker(
						_mapView,
						m.uid,
						state.Latitude,
						state.Longitude,
						state.Label,
						state.Snippet,
						state.IconPath,
						state.IconAnchorX,
						state.IconAnchorY,
						(int)Uno.Color.ToArgb(state.Color),
						state.Draggable
					);
				}
				else
				{
					ForeignHelpers.AddMarker(
						_mapView,
						state.Latitude,
						state.Longitude,
						state.Label,
						state.Snippet,
						state.IconPath,
						state.IconAnchorX,
						state.IconAnchorY,
						(int)Uno.Color.ToArgb(state.Color),
						state.Draggable,
						m.uid
					);
				}

				_markerStates[m.uid] = state;
			}
		}

		public void SelectMarker(int uid)
		{
			if (IsReady && _mapView != null)
				ForeignHelpers.SelectMarker(_mapView, uid);
		}

		public void DeselectMarker(int uid)
		{
			if (IsReady && _mapView != null)
				ForeignHelpers.DeselectMarker(_mapView, uid);
		}

		public void UpdateRoutes()
		{
			if (!IsReady || _mapView == null) return;

			ForeignHelpers.ClearRoutes(_mapView);

			foreach (MapRoute route in _host.Routes)
			{
				if (route.NeedsCalculation)
				{
					route.MarkCalculationStarted();

					var callback = new RouteProgressCallback(_host, route.Uid, route.Generation);
					ForeignHelpers.StartRouteCalculation(
						_mapView,
						route.FromLatitude,
						route.FromLongitude,
						route.ToLatitude,
						route.ToLongitude,
						(int)route.Mode,
						callback.OnSuccess,
						callback.OnError
					);
				}

				if (route.Visible && route.HasPolyline)
				{
					ForeignHelpers.AddRoutePolyline(
						_mapView,
						route.Uid,
						route.GetPolylineArray(),
						(int)Uno.Color.ToArgb(route.StrokeColor),
						route.LineWidth,
						route.Alpha,
						route.ZIndex
					);
				}
			}
		}

		class RouteProgressCallback
		{
			readonly IMapViewHost _host;
			readonly int _uid;
			readonly int _generation;

			public RouteProgressCallback(IMapViewHost host, int uid, int generation)
			{
				_host = host;
				_uid = uid;
				_generation = generation;
			}

			public void OnSuccess(string encoded)
			{
				if (_host != null)
					_host.OnRouteResult(_uid, _generation, encoded);
			}

			public void OnError(string message)
			{
				if (_host != null)
					_host.OnRouteError(_uid, _generation, message);
			}
		}

		public void UpdateOverlays()
		{
			if (!IsReady || _mapView == null || _host == null) return;
			ForeignHelpers.ClearOverlays(_mapView);

			foreach(MapOverlay p in _host.Overlays)
			{
				if (!p.Visible) continue;

				if (p.Type == OverlayType.Image)
				{
					ForeignHelpers.AddImageOverlay(
						_mapView,
						_markerGraphicsCache.Get(p.ImageFile),
						p.MinLatitude,
						p.MinLongitude,
						p.MaxLatitude,
						p.MaxLongitude,
						p.Alpha,
						p.ZIndex,
						p.Uid
					);
					continue;
				}

				if (p.Type == OverlayType.Tile)
				{
					ForeignHelpers.AddTileOverlay(
						_mapView,
						p.TileUrlTemplate,
						p.TileMinZoom,
						p.TileMaxZoom,
						p.Alpha,
						p.ZIndex,
						p.Uid
					);
					continue;
				}

				int[] pattern = new int[] { p.DashPattern.X, p.DashPattern.Y };
				ForeignHelpers.AddOverlay(
					_mapView, p.Type,
					p.GetCoordinatesArray(),
					p.GetHolesCoordinatesArray(),
					p.GetHoleLengthsArray(),
					(int)Uno.Color.ToArgb(p.StrokeColor),
					(int)Uno.Color.ToArgb(p.FillColor),
					p.LineWidth,
					p.Geodesic,
					p.StartCap,
					p.EndCap,
					p.JoinType,
					pattern,
					p.CenterLatitude,
					p.CenterLongitude,
					p.Radius,
					p.ZIndex,
					p.Alpha,
					p.Uid
					);
			}
		}

		public void SetLocation(double latitude, double longitude)
		{
			if (IsReady && _mapView != null)
				ForeignHelpers.SetPosition(_mapView, latitude, longitude, 0.0);
		}

		public double Bearing {
			get {
				if (!IsReady || _mapView == null) return 0.0;
				return ForeignHelpers.GetOrientation(_mapView);
			}
		}

		public double Tilt {
			get {
				if (!IsReady || _mapView == null) return 0.0;
				return ForeignHelpers.GetTilt(_mapView);
			}
		}

		public double Latitude {
			get {
				if (!IsReady || _mapView == null) return 0.0;
				return ForeignHelpers.GetPositionLat(_mapView);
			}
		}

		public double Longitude {
			get {
				if (!IsReady || _mapView == null) return 0.0;
				return ForeignHelpers.GetPositionLong(_mapView);
			}
		}

		public void MoveTo(double latitude, double longitude, double zoomlevel, double tilt, double orientation)
		{
			if (IsReady && _mapView != null)
				ForeignHelpers.MoveCamera(_mapView, latitude, longitude, (float)zoomlevel, (float)tilt, (float)orientation, 0.0);
		}

		public void ShowAllMarkers()
		{
			if (IsReady && _mapView != null)
				ForeignHelpers.ShowAllMarkers(_mapView);
		}

		public void Snapshot(Action<string> actionSucces, Action<string> actionError)
		{
			if (IsReady && _mapView != null)
				ForeignHelpers.TakeSnapshot(_mapView, actionSucces, actionError);
			else if (actionError != null)
				actionError("MapView is not ready");
		}

		void ConfigUI(){
			if (IsReady) ForeignHelpers.ConfigureUI(_mapView, _showCompass, _showLocationButton);
		}

		void ConfigGestures(){
			if (IsReady) ForeignHelpers.ConfigureGestures(_mapView, _allowZoom, _allowRotate, _allowTilt, _allowScroll);
		}

		public void AnimateTo(double latitude, double longitude, double zoomlevel, double tilt, double orientation, double duration)
		{
			if (!IsReady || _mapView == null) return;
			ForeignHelpers.MoveCamera(_mapView, latitude, longitude, (float)zoomlevel, (float)tilt, (float)orientation, duration);
		}

		public void CancelAnimation()
		{
			if (!IsReady || _mapView == null) return;
			ForeignHelpers.CancelAnimation(_mapView);

			if (_host != null)
				_host.OnCameraChanged();
		}

		public void ShowBounds(double minLatitude, double minLongitude, double maxLatitude, double maxLongitude)
		{
			if (!IsReady || _mapView == null) return;
			ForeignHelpers.ShowBounds(_mapView, minLatitude, minLongitude, maxLatitude, maxLongitude);
		}

		public MapBounds GetVisibleBounds()
		{
			if (!IsReady || _mapView == null) return null;

			return new MapBounds(
				ForeignHelpers.GetVisibleMinLatitude(_mapView),
				ForeignHelpers.GetVisibleMinLongitude(_mapView),
				ForeignHelpers.GetVisibleMaxLatitude(_mapView),
				ForeignHelpers.GetVisibleMaxLongitude(_mapView)
			);
		}

		public void ZoomBy(double delta, double duration)
		{
			if (!IsReady || _mapView == null) return;
			ForeignHelpers.ZoomBy(_mapView, (float)delta, duration);

			if (duration <= 0.0 && _host != null)
				_host.OnCameraChanged();
		}

		public void ScrollBy(float dx, float dy, double duration)
		{
			if (!IsReady || _mapView == null) return;
			ForeignHelpers.ScrollBy(_mapView, dx, dy, duration);

			if (duration <= 0.0 && _host != null)
				_host.OnCameraChanged();
		}

		public Future<MapPlace[]> Geocode(string query)
		{
			var promise = new Promise<MapPlace[]>();

			if (_mapView == null)
			{
				promise.Reject(new Exception("MapView is not ready"));
				return promise;
			}

			var callback = new PlaceCallback(promise);
			ForeignHelpers.Geocode(_mapView, query, callback.OnSuccess, callback.OnError);
			return promise;
		}

		public Future<MapPlace[]> ReverseGeocode(double latitude, double longitude)
		{
			var promise = new Promise<MapPlace[]>();

			if (_mapView == null)
			{
				promise.Reject(new Exception("MapView is not ready"));
				return promise;
			}

			var callback = new PlaceCallback(promise);
			ForeignHelpers.ReverseGeocode(_mapView, latitude, longitude, callback.OnSuccess, callback.OnError);
			return promise;
		}

		public Future<MapRouteResult> CalculateRoute(double fromLatitude, double fromLongitude, double toLatitude, double toLongitude, RouteMode mode)
		{
			var promise = new Promise<MapRouteResult>();

			if (_mapView == null)
			{
				promise.Reject(new Exception("MapView is not ready"));
				return promise;
			}

			var callback = new RouteCallback(promise);
			ForeignHelpers.CalculateRoute(_mapView, fromLatitude, fromLongitude, toLatitude, toLongitude, (int)mode, callback.OnSuccess, callback.OnError);
			return promise;
		}

		class PlaceCallback
		{
			readonly Promise<MapPlace[]> _promise;

			public PlaceCallback(Promise<MapPlace[]> promise)
			{
				_promise = promise;
			}

			public void OnSuccess(string encoded)
			{
				_promise.Resolve(MapPlace.ParseList(encoded));
			}

			public void OnError(string message)
			{
				_promise.Reject(new Exception(message));
			}
		}

		class RouteCallback
		{
			readonly Promise<MapRouteResult> _promise;

			public RouteCallback(Promise<MapRouteResult> promise)
			{
				_promise = promise;
			}

			public void OnSuccess(string encoded)
			{
				var result = MapRouteResult.Parse(encoded);
				if (result == null)
					_promise.Reject(new Exception("Could not calculate the route"));
				else
					_promise.Resolve(result);
			}

			public void OnError(string message)
			{
				_promise.Reject(new Exception(message));
			}
		}

		class ShowLocationCommand
		{
			readonly bool _value;
			readonly MapView _mapView;
			public ShowLocationCommand(MapView mapView, bool newValue)
			{
				_mapView = mapView;
				_value = newValue;
			}
			public void Execute(PlatformPermission[] grantedPermissions)
			{
				if (_mapView == null) return;
				_mapView.SetMyLocationEnabled(_value);
			}
			public void Reject(Exception e)
			{
				debug_log("Could not acquire location permissions");
			}
		}

		internal void SetMyLocationEnabled(bool value)
		{
			if (!IsReady || _mapView == null) return;
			ForeignHelpers.SetMyLocationEnabled(_mapView, value);
		}

		bool _showLocation;
		public bool ShowMyLocation {
			get {
				return _showLocation;
			}
			set {
				_showLocation = value;
				if (IsReady)
				{
					if (_showLocation)
					{
						var permissions = new PlatformPermission[]
						{
							Permissions.Android.ACCESS_FINE_LOCATION,
							Permissions.Android.ACCESS_COARSE_LOCATION
						};
						var cmd = new ShowLocationCommand(this, _showLocation);
						Permissions.Request(permissions).Then(cmd.Execute, cmd.Reject);
					}
					else
					{
						SetMyLocationEnabled(_showLocation);
					}
				}
			}
		}

		bool _showLocationButton;
		public bool ShowMyLocationButton {
			get {
				return _showLocationButton;
			}
			set {
				_showLocationButton = value;
				ConfigUI();
			}
		}

		bool _showCompass;
		public bool ShowCompass {
			get {
				return _showCompass;
			}
			set {
				_showCompass = value;
				ConfigUI();
			}
		}
		bool _allowZoom;
		public bool AllowZoom {
			get {
				return _allowZoom;
			}
			set {
				_allowZoom = value;
				ConfigGestures();
			}
		}

		bool _allowTilt;
		public bool AllowTilt {
			get {
				return _allowTilt;
			}
			set {
				_allowTilt = value;
				ConfigGestures();
			}
		}

		bool _allowRotate;
		public bool AllowRotate {
			get {
				return _allowRotate;
			}
			set {
				_allowRotate = value;
				ConfigGestures();
			}
		}

		bool _allowScroll;
		public bool AllowScroll {
			get {
				return _allowScroll;
			}
			set {
				_allowScroll = value;
				ConfigGestures();
			}
		}

		float4 _padding = float4(0);
		public float4 Padding
		{
			get { return _padding; }
			set
			{
				_padding = value;
				ApplyPadding();
			}
		}

		void ApplyPadding()
		{
			if (!IsReady || _mapView == null) return;
			ForeignHelpers.SetPadding(_mapView, _padding.X, _padding.Y, _padding.Z, _padding.W);
		}

		double _minZoom = 0;
		public double MinZoom
		{
			get { return _minZoom; }
			set
			{
				_minZoom = value;
				ApplyZoomLimits();
			}
		}

		double _maxZoom = 21;
		public double MaxZoom
		{
			get { return _maxZoom; }
			set
			{
				_maxZoom = value;
				ApplyZoomLimits();
			}
		}

		void ApplyZoomLimits()
		{
			if (!IsReady || _mapView == null) return;
			ForeignHelpers.SetZoomLimits(_mapView, (float)_minZoom, (float)_maxZoom);
		}
	}

	extern (Android) public class NativeMapProvider : IMapProvider
	{
		public string Name { get { return "Native"; } }

		public IMapView Create(IMapViewHost host)
		{
			return MapView.Create(host);
		}
	}
}
