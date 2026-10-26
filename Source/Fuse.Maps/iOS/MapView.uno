using Uno;
using Uno.Collections;
using Uno.Threading;
using Fuse.Controls;
using Fuse.Controls.Native.iOS;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Maps.iOS
{

	[Require("source.include", "MapKit/MapKit.h")]
	extern (iOS) internal class FuseMapView
	{
		public readonly ObjC.Object Handle;
		public readonly ObjC.Object Container;
		public FuseMapView()
		{
			Container = CreateContainer();
			Handle = CreateMap(Container);
		}

		[Foreign(Language.ObjC)]
		ObjC.Object CreateContainer()
		@{
			UIView* view = [[UIView alloc] init];
			return view;
		@}

		[Foreign(Language.ObjC)]
		ObjC.Object CreateMap(ObjC.Object container)
		@{
			MKMapView* mv = [[MKMapView alloc] init];
			UIView* mvc = container;
			mv.frame = mvc.bounds;
			mv.translatesAutoresizingMaskIntoConstraints = YES;
			mv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
			[mvc addSubview:mv];
			return mv;
		@}

		[Foreign(Language.ObjC)]
		public void Dispose()
		@{
			MKMapView* mv = @{FuseMapView:of(_this).Handle:get()};
			mv.delegate = nil;
			[mv removeFromSuperview];
			[mv removeAnnotations:mv.annotations];
			[mv removeOverlays:mv.overlays];
		@}

		[Foreign(Language.ObjC)]
		public bool GetBoolValue(string key)
		@{
			id result = [@{FuseMapView:of(_this).Handle:get()} valueForKey:key];
			return [result boolValue];
		@}

		[Foreign(Language.ObjC)]
		public void SetBoolValue(string key, bool val)
		@{
			[@{FuseMapView:of(_this).Handle:get()} setValue:[NSNumber numberWithBool:val] forKey:key];
		@}

		[Foreign(Language.ObjC)]
		public void SetIntValue(string key, int val)
		@{
			[@{FuseMapView:of(_this).Handle:get()} setValue:[NSNumber numberWithInt:val] forKey:key];
		@}

		[Foreign(Language.ObjC)]
		public double GetHeading()
		@{
			MKMapView* mv = @{FuseMapView:of(_this).Handle:get()};
			return mv.camera.heading;
		@}

		[Foreign(Language.ObjC)]
		public double GetPitch()
		@{
			MKMapView* mv = @{FuseMapView:of(_this).Handle:get()};
			return mv.camera.pitch;
		@}

		[Foreign(Language.ObjC)]
		public double GetLatitude()
		@{
			MKMapView* mv = @{FuseMapView:of(_this).Handle:get()};
			return mv.centerCoordinate.latitude;
		@}

		[Foreign(Language.ObjC)]
		public double GetLongitude()
		@{
			MKMapView* mv = @{FuseMapView:of(_this).Handle:get()};
			return mv.centerCoordinate.longitude;
		@}
	}

	[Require("source.include", "iOS/MapViewController.h")]
	extern (iOS) internal class MapViewContainer
	{

		public Action OnReady;
		public Action OnResize;
		public FuseMapView Map { get; private set; }
		public ObjC.Object Handle { get; private set; }
		public MapViewContainer(FuseMapView map)
		{
			Map = map;
			Handle = Create(Map.Container, viewDidAppear, viewDidResize);
		}

		[Foreign(Language.ObjC)]
		ObjC.Object Create(ObjC.Object view, Action onReady, Action onResize)
		@{
			return [[MapViewController alloc] initWithView:view onAppeared:onReady onResize:onResize];
		@}

		void viewDidAppear()
		{
			if (OnReady!=null)
				OnReady();
		}

		void viewDidResize()
		{
			if (OnResize!=null)
				OnResize();
		}

		public void Dispose()
		{
			Handle = null;
			Map = null;
		}

		[Foreign(Language.ObjC)]
		public ObjC.Object GetView()
		@{
			UIViewController* vc = @{MapViewContainer:of(_this).Handle:get()};
			return vc.view;
		@}
	}


	[Require("source.include", "iOS/MapViewDelegate.h")]
	extern (iOS) public class MapView : LeafView, IMapView
	{

		public override void Dispose()
		{
			DisposeDelegate();
			_container.Dispose();
			_mapView.Dispose();
			_mapView = null;
			_container = null;
			_markerStates.Clear();

			var host = _host;
			_host = null;
			if (host != null)
				host.OnViewDisposed(this);

			base.Dispose();
		}

		MapViewContainer _container;
		FuseMapView _mapView;
		ObjC.Object _mapViewDelegate;

		IMapViewHost _host;
		MarkerIconCache _markerGraphicsCache;

		public static MapView Create(IMapViewHost host)
		{
			var v = new FuseMapView();
			var mvc = new MapViewContainer(v);
			return new MapView(host, mvc);
		}

		MapView(IMapViewHost host, MapViewContainer mvc) : base(mvc.GetView())
		{
			_host = host;
			_container = mvc;
			_container.OnReady = OnReadyInternal;
			_container.OnResize = OnReadyInternal;
			_mapView = _container.Map;
			_mapViewDelegate = Configure(_mapView.Handle, OnCameraMoved, OnMapTouch, OnMarkerTapped, OnOverlayTapped, OnMarkerSelected, OnMarkerDeselected, OnMarkerDragStarted, OnMarkerDragging, OnMarkerDragEnded);
			_markerGraphicsCache = new MarkerIconCache(UpdateMarkers);
		}

		bool _isReady;
		public bool IsReady {
			get
			{
				return _isReady;
			}
		}
		public Action OnReady { get; set; }

		void OnReadyInternal()
		{
			_isReady = true;
			ApplyZoomLimits();
			if (_readyFired) return;
			_readyFired = true;
			if (OnReady != null) OnReady();
		}

		bool _readyFired;

		[Require("source.include", "iOS/MapViewDelegate.h")]
		[Foreign(Language.ObjC)]
		ObjC.Object Configure(ObjC.Object mapView, Action<bool> onMapMove, Action<int, double, double> onMapTouch, Action<int, string> onMarkerTouch, Action<int> onOverlayTouch, Action<int> onMarkerSelect, Action<int> onMarkerDeselect, Action<int> onMarkerDragStart, Action<int, double, double> onMarkerDrag, Action<int, double, double> onMarkerDragEnd)
		@{
			MKMapView* mv = mapView;
			MapViewDelegate* dg = [[MapViewDelegate alloc] init];
			[dg setAsDelegate:mv];
			[dg setMapMoveAction:onMapMove];
			[dg setMapTouchAction:onMapTouch];
			[dg setMarkerSelectAction:onMarkerTouch];
			[dg setMarkerSelectedAction:onMarkerSelect];
			[dg setOverlaySelectBlock:onOverlayTouch];
			[dg setMarkerDeselectAction:onMarkerDeselect];
			[dg setMarkerDragStartAction:onMarkerDragStart];
			[dg setMarkerDragAction:onMarkerDrag];
			[dg setMarkerDragEndAction:onMarkerDragEnd];
			return dg;
		@}

		[Foreign(Language.ObjC)]
		void DisposeDelegate()
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg clearMarkers];
			[dg clearOverlays];
			[dg clearRoutes];
			[dg cleanup];
			[dg setMapMoveAction:nil];
			[dg setMapTouchAction:nil];
		@}

		[Foreign(Language.ObjC)]
		double GetZoomLevel()
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			return [dg getZoomLevel];
		@}

		void OnMapTouch(int type, double lat, double lng)
		{
			switch(type)
			{
				case 2: // Tap
					OnLocationTapped(lat, lng);
					break;
				case 3: // Long press
					OnLocationLongPress(lat, lng);
					break;
			}
		}

		void OnLocationTapped(double lat, double lng)
		{
			if (_host != null)
				_host.OnLocationTapped(lat, lng);
		}

		void OnLocationLongPress(double lat, double lng)
		{
			if (_host != null)
				_host.OnLocationLongPress(lat, lng);
		}

		void OnCameraMoved(bool animated)
		{
			if (_host != null)
				_host.OnCameraChanged();
		}

		[Foreign(Language.ObjC)]
		int AddMarker(int uid, string label, double lat, double lng, string snippet, String iconPath, float iconAnchorX, float iconAnchorY, float4 color, bool draggable)
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			UIColor* tint = color.W > 0.0f ? [UIColor colorWithRed:color.X green:color.Y blue:color.Z alpha:color.W] : nil;
			return [dg addMarker:label latitude:lat longitude:lng snippet:snippet icon:iconPath iconX:iconAnchorX iconY:iconAnchorY color:tint draggable:draggable markerID:uid];
		@}

		[Foreign(Language.ObjC)]
		void UpdateMarker(int uid, string label, double lat, double lng, string snippet, String iconPath, float iconAnchorX, float iconAnchorY, float4 color, bool draggable)
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			UIColor* tint = color.W > 0.0f ? [UIColor colorWithRed:color.X green:color.Y blue:color.Z alpha:color.W] : nil;
			[dg updateMarker:label latitude:lat longitude:lng snippet:snippet icon:iconPath iconX:iconAnchorX iconY:iconAnchorY color:tint draggable:draggable markerID:uid];
		@}

		[Foreign(Language.ObjC)]
		void RemoveMarker(int identifier)
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg removeMarker:identifier];
		@}

		void OnMarkerTapped(int id, string label)
		{
			if (_host != null)
				_host.OnMarkerTapped(id, label);
		}

		void OnOverlayTapped(int id)
		{
			if (_host != null)
				_host.OnOverlayTapped(id);
		}

		Dictionary<int, MarkerState> _markerStates = new Dictionary<int, MarkerState>();
		List<int> _removedMarkerUids = new List<int>();

		public void UpdateMarkers()
		{
			if (_host == null) return;

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
				RemoveMarker(uid);
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

					// Some changes require a new annotation view, so recreate the annotation.
					if (state.NeedsNewView(previous))
					{
						RemoveMarker(m.uid);
						AddMarker(
							m.uid,
							state.Label,
							state.Latitude,
							state.Longitude,
							state.Snippet,
							state.IconPath,
							state.IconAnchorX,
							state.IconAnchorY,
							state.Color,
							state.Draggable
						);
					}
					else
					{
						UpdateMarker(
							m.uid,
							state.Label,
							state.Latitude,
							state.Longitude,
							state.Snippet,
							state.IconPath,
							state.IconAnchorX,
							state.IconAnchorY,
							state.Color,
							state.Draggable
						);
					}
				}
				else
				{
					AddMarker(
						m.uid,
						state.Label,
						state.Latitude,
						state.Longitude,
						state.Snippet,
						state.IconPath,
						state.IconAnchorX,
						state.IconAnchorY,
						state.Color,
						state.Draggable
					);
				}

				_markerStates[m.uid] = state;
			}
		}

		public void SelectMarker(int uid)
		{
			SelectMarkerNative(uid);
		}

		public void DeselectMarker(int uid)
		{
			DeselectMarkerNative(uid);
		}

		[Foreign(Language.ObjC)]
		void SelectMarkerNative(int uid)
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg selectMarker:uid];
		@}

		[Foreign(Language.ObjC)]
		void DeselectMarkerNative(int uid)
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg deselectMarker:uid];
		@}

		public void OnMarkerSelected(int uid)
		{
			if (_host != null)
				_host.OnMarkerSelected(uid);
		}

		public void OnMarkerDeselected(int uid)
		{
			if (_host != null)
				_host.OnMarkerDeselected(uid);
		}

		public void OnMarkerDragStarted(int uid)
		{
			if (_host != null)
				_host.OnMarkerDragStarted(uid);
		}

		public void OnMarkerDragging(int uid, double latitude, double longitude)
		{
			if (_host != null)
				_host.OnMarkerDragging(uid, latitude, longitude);
		}

		public void OnMarkerDragEnded(int uid, double latitude, double longitude)
		{
			if (_host != null)
				_host.OnMarkerDragEnded(uid, latitude, longitude);
		}

		[Foreign(Language.ObjC)]
		void ClearOverlays()
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg clearOverlays];
		@}

		[Foreign(Language.ObjC)]
		void AddOverlay(int uid, OverlayType type, double[] coordinates, double[] holeCoordinates, int[] holeLengths, float4 strokeColor, float4 fillColor, int lineWidth, bool geodesic, LineCap startCap, LineCap endCap, LineJoin joinType, int2 dashPattern, double centerLatitude, double centerLongitude, double radius, float alpha)
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			NSArray<NSNumber *> *pattern = @[[NSNumber numberWithInt:dashPattern.X], [NSNumber numberWithInt:dashPattern.Y]];
			[dg addOverlay:coordinates
				type:type
				holes:holeCoordinates
				holeLengths:holeLengths
				strokeColor:[UIColor colorWithRed:strokeColor.X green:strokeColor.Y blue:strokeColor.Z alpha:strokeColor.W]
				fillColor:[UIColor colorWithRed:fillColor.X green:fillColor.Y blue:fillColor.Z alpha:fillColor.W]
				lineWidth:lineWidth
				geodesic:geodesic
				startCap:startCap
				endCap:endCap
				joinType:joinType
				pattern:pattern
				centerLatitude:centerLatitude
				centerLongitude:centerLongitude
				radius:radius
				alpha:alpha
				overlayID:uid];
		@}

		[Foreign(Language.ObjC)]
		void AddImageOverlay(int uid, String imagePath, double minLatitude, double minLongitude, double maxLatitude, double maxLongitude, float opacity)
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg addImageOverlay:imagePath minLatitude:minLatitude minLongitude:minLongitude maxLatitude:maxLatitude maxLongitude:maxLongitude opacity:opacity overlayID:uid];
		@}

		[Foreign(Language.ObjC)]
		void AddTileOverlay(int uid, String urlTemplate, int minZoom, int maxZoom, float opacity)
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg addTileOverlay:urlTemplate minZoom:minZoom maxZoom:maxZoom opacity:opacity overlayID:uid];
		@}

		public void UpdateOverlays()
		{
			if (_host == null) return;

			ClearOverlays();

			var visible = new List<MapOverlay>();
			foreach(MapOverlay p in _host.Overlays)
			{
				if (p.Visible)
					visible.Add(p);
			}

			// MapKit draws overlays in the order they are added, so sort by ZIndex.
			for (int i = 1; i < visible.Count; i++)
			{
				var item = visible[i];
				int j = i - 1;
				while (j >= 0 && visible[j].ZIndex > item.ZIndex)
				{
					visible[j + 1] = visible[j];
					j--;
				}
				visible[j + 1] = item;
			}

			foreach(MapOverlay p in visible)
			{
				if (p.Type == OverlayType.Image)
				{
					AddImageOverlay(
						p.Uid,
						_markerGraphicsCache.Get(p.ImageFile),
						p.MinLatitude,
						p.MinLongitude,
						p.MaxLatitude,
						p.MaxLongitude,
						p.Alpha
					);
					continue;
				}

				if (p.Type == OverlayType.Tile)
				{
					AddTileOverlay(
						p.Uid,
						p.TileUrlTemplate,
						p.TileMinZoom,
						p.TileMaxZoom,
						p.Alpha
					);
					continue;
				}

				AddOverlay(
					p.Uid,
					p.Type,
					p.GetCoordinatesArray(),
					p.GetHolesCoordinatesArray(),
					p.GetHoleLengthsArray(),
					p.StrokeColor,
					p.FillColor,
					p.LineWidth,
					p.Geodesic,
					p.StartCap,
					p.EndCap,
					p.JoinType,
					p.DashPattern,
					p.CenterLatitude,
					p.CenterLongitude,
					p.Radius,
					p.Alpha
					);
			}
		}

		public void UpdateRoutes()
		{
			if (_mapViewDelegate == null) return;

			ClearRoutesNative();

			foreach (MapRoute route in _host.Routes)
			{
				if (route.NeedsCalculation)
				{
					route.MarkCalculationStarted();

					var callback = new RouteProgressCallback(_host, route.Uid, route.Generation);
					CalculateRouteNative(
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
					AddRoutePolylineNative(
						route.Uid,
						route.GetPolylineArray(),
						route.StrokeColor,
						route.LineWidth,
						route.Alpha
					);
				}
			}
		}

		[Foreign(Language.ObjC)]
		void ClearRoutesNative()
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg clearRoutes];
		@}

		[Foreign(Language.ObjC)]
		void AddRoutePolylineNative(int uid, double[] coordinates, float4 strokeColor, int lineWidth, float alpha)
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg addRoutePolyline:uid
				coordinates:coordinates
				strokeColor:[UIColor colorWithRed:strokeColor.X green:strokeColor.Y blue:strokeColor.Z alpha:strokeColor.W]
				lineWidth:lineWidth
				alpha:alpha];
		@}

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

		MapStyle _mapStyle = MapStyle.Normal;
		public MapStyle Style
		{
			get {
				return _mapStyle;
			}
			set {
				_mapStyle = value;
				switch(_mapStyle)
				{
					case MapStyle.Satellite:
						_mapView.SetIntValue("mapType", 1);
						break;
					case MapStyle.Hybrid:
						_mapView.SetIntValue("mapType", 2);
						break;
					// MapKit has no terrain map type; fall back to the standard map.
					case MapStyle.Terrain:
					default:
						_mapView.SetIntValue("mapType", 0);
						break;
				}
			}
		}

		double _latInternal;
		public double Latitude
		{
			get
			{
				return Double.IsNaN(_mapView.GetLatitude())
					? _latInternal : _mapView.GetLatitude();
			}
		}

		double _lngInternal;
		public double Longitude
		{
			get
			{
				return Double.IsNaN(_mapView.GetLongitude())
					? _lngInternal : _mapView.GetLongitude();
			}
		}

		public double Bearing
		{
			get
			{
				return _mapView.GetHeading();
			}
		}
		public double Tilt
		{
			get
			{
				return _mapView.GetPitch();
			}
		}
		public double Zoom
		{
			get
			{
				return GetZoomLevel();
			}
		}

		[Foreign(Language.ObjC)]
		public void MoveTo(double latitude, double longitude, double zoomlevel, double tilt, double orientation)
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg moveTo:latitude longitude:longitude zoom:zoomlevel tilt:tilt orientation:orientation];
		@}

		void HandleLocationAuthChange(bool status)
		{
			_mapView.SetBoolValue("showsUserLocation", status);
		}

		public bool ShowMyLocation
		{
			get
			{
				return _mapView.GetBoolValue("showsUserLocation");
			}
			set
			{
				if (value)
					RequestLocationAuth(HandleLocationAuthChange);
				else
					_mapView.SetBoolValue("showsUserLocation", value);
			}
		}
		bool _showMyLocationButton;
		public bool ShowMyLocationButton
		{
			get { return _showMyLocationButton; }
			set
			{
				_showMyLocationButton = value;
				if (_mapViewDelegate != null)
					SetShowsMyLocationButton(value);
			}
		}

		[Foreign(Language.ObjC)]
		void SetShowsMyLocationButton(bool show)
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg setShowsMyLocationButton:show];
		@}

		[Foreign(Language.ObjC)]
		public void RequestLocationAuth(Action<bool> onAuthorizationResult)
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg requestLocationAuthentication:onAuthorizationResult];
		@}

		bool _showCompass;
		public bool ShowCompass
		{
			get { return _showCompass; }
			set
			{
				_showCompass = value;
				if (_mapView != null)
					_mapView.SetBoolValue("showsCompass", value);
			}
		}

		public bool AllowZoom
		{
			get { return _mapView.GetBoolValue("zoomEnabled"); }
			set { _mapView.SetBoolValue("zoomEnabled", value); }
		}

		public bool AllowTilt
		{
			get { return _mapView.GetBoolValue("pitchEnabled"); }
			set { _mapView.SetBoolValue("pitchEnabled", value); }
		}

		public bool AllowRotate
		{
			get { return _mapView.GetBoolValue("rotateEnabled"); }
			set { _mapView.SetBoolValue("rotateEnabled", value); }
		}

		public bool AllowScroll
		{
			get { return _mapView.GetBoolValue("scrollEnabled"); }
			set { _mapView.SetBoolValue("scrollEnabled", value); }
		}

		float4 _padding = float4(0);
		public float4 Padding
		{
			get { return _padding; }
			set
			{
				_padding = value;
				if (_mapViewDelegate != null)
					SetPaddingNative(value.X, value.Y, value.Z, value.W);
			}
		}

		[Foreign(Language.ObjC)]
		void SetPaddingNative(float left, float top, float right, float bottom)
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg setPaddingLeft:left top:top right:right bottom:bottom];
		@}

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
			if (_mapViewDelegate == null) return;
			SetZoomLimitsNative(_minZoom, _maxZoom);
		}

		[Foreign(Language.ObjC)]
		void SetZoomLimitsNative(double minZoom, double maxZoom)
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg setZoomLimitsMin:minZoom max:maxZoom];
		@}

		public void SetLocation(double latitude, double longitude)
		{
			MoveTo(latitude,longitude, Zoom, Tilt, Bearing);
		}

		public void ShowAllMarkers()
		{
			ShowAllAnotations();
		}

		[Foreign(Language.ObjC)]
		public void ShowAllAnotations()
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg showAllAnotations];
		@}

		public void AnimateTo(double latitude, double longitude, double zoomlevel, double tilt, double orientation, double duration)
		{
			if (_mapViewDelegate == null) return;
			AnimateToNative(latitude, longitude, zoomlevel, tilt, orientation, duration);
		}

		[Foreign(Language.ObjC)]
		void AnimateToNative(double latitude, double longitude, double zoomlevel, double tilt, double orientation, double duration)
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg animateTo:latitude longitude:longitude zoom:zoomlevel tilt:tilt orientation:orientation duration:duration];
		@}

		public void CancelAnimation()
		{
			if (_mapViewDelegate == null) return;
			CancelAnimationNative();
		}

		[Foreign(Language.ObjC)]
		void CancelAnimationNative()
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg cancelAnimation];
		@}

		public void ShowBounds(double minLatitude, double minLongitude, double maxLatitude, double maxLongitude)
		{
			if (_mapViewDelegate == null) return;
			ShowBoundsNative(minLatitude, minLongitude, maxLatitude, maxLongitude);
		}

		[Foreign(Language.ObjC)]
		void ShowBoundsNative(double minLatitude, double minLongitude, double maxLatitude, double maxLongitude)
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg showBoundsMinLatitude:minLatitude minLongitude:minLongitude maxLatitude:maxLatitude maxLongitude:maxLongitude];
		@}

		public MapBounds GetVisibleBounds()
		{
			if (_mapViewDelegate == null) return null;

			return new MapBounds(
				GetVisibleMinLatitude(),
				GetVisibleMinLongitude(),
				GetVisibleMaxLatitude(),
				GetVisibleMaxLongitude()
			);
		}

		[Foreign(Language.ObjC)]
		double GetVisibleMinLatitude()
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			return [dg getVisibleMinLatitude];
		@}

		[Foreign(Language.ObjC)]
		double GetVisibleMinLongitude()
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			return [dg getVisibleMinLongitude];
		@}

		[Foreign(Language.ObjC)]
		double GetVisibleMaxLatitude()
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			return [dg getVisibleMaxLatitude];
		@}

		[Foreign(Language.ObjC)]
		double GetVisibleMaxLongitude()
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			return [dg getVisibleMaxLongitude];
		@}

		public void ZoomBy(double delta, double duration)
		{
			if (_mapViewDelegate == null) return;
			ZoomByNative(delta);
		}

		[Foreign(Language.ObjC)]
		void ZoomByNative(double delta)
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg zoomBy:delta];
		@}

		public void ScrollBy(float dx, float dy, double duration)
		{
			if (_mapViewDelegate == null) return;
			ScrollByNative(dx, dy);
		}

		[Foreign(Language.ObjC)]
		void ScrollByNative(float dx, float dy)
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg scrollBy:dx dy:dy];
		@}

		public Future<MapPlace[]> Geocode(string query)
		{
			var promise = new Promise<MapPlace[]>();

			if (_mapViewDelegate == null)
			{
				promise.Reject(new Exception("MapView is not ready"));
				return promise;
			}

			var callback = new PlaceCallback(promise);
			GeocodeNative(query, callback.OnSuccess, callback.OnError);
			return promise;
		}

		[Foreign(Language.ObjC)]
		void GeocodeNative(string query, Action<string> onSuccess, Action<string> onError)
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg geocode:query onSuccess:onSuccess onError:onError];
		@}

		public Future<MapPlace[]> ReverseGeocode(double latitude, double longitude)
		{
			var promise = new Promise<MapPlace[]>();

			if (_mapViewDelegate == null)
			{
				promise.Reject(new Exception("MapView is not ready"));
				return promise;
			}

			var callback = new PlaceCallback(promise);
			ReverseGeocodeNative(latitude, longitude, callback.OnSuccess, callback.OnError);
			return promise;
		}

		[Foreign(Language.ObjC)]
		void ReverseGeocodeNative(double latitude, double longitude, Action<string> onSuccess, Action<string> onError)
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg reverseGeocode:latitude longitude:longitude onSuccess:onSuccess onError:onError];
		@}

		public Future<MapRouteResult> CalculateRoute(double fromLatitude, double fromLongitude, double toLatitude, double toLongitude, RouteMode mode)
		{
			var promise = new Promise<MapRouteResult>();

			if (_mapViewDelegate == null)
			{
				promise.Reject(new Exception("MapView is not ready"));
				return promise;
			}

			var callback = new RouteCallback(promise);
			CalculateRouteNative(fromLatitude, fromLongitude, toLatitude, toLongitude, (int)mode, callback.OnSuccess, callback.OnError);
			return promise;
		}

		[Foreign(Language.ObjC)]
		void CalculateRouteNative(double fromLatitude, double fromLongitude, double toLatitude, double toLongitude, int mode, Action<string> onSuccess, Action<string> onError)
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg calculateRoute:fromLatitude fromLongitude:fromLongitude toLatitude:toLatitude toLongitude:toLongitude mode:mode onSuccess:onSuccess onError:onError];
		@}

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

		public void Snapshot(Action<string> actionSucces, Action<string> actionError)
		{
			TakeSnapshot(actionSucces, actionError);
		}

		[Foreign(Language.ObjC)]
		public void TakeSnapshot(Action<string> actionSucces, Action<string> actionError)
		@{
			MapViewDelegate* dg = (MapViewDelegate*)@{MapView:of(_this)._mapViewDelegate:get()};
			[dg takeSnapshot:actionSucces error:actionError];
		@}
	}

	extern (iOS) public class NativeMapProvider : IMapProvider
	{
		public string Name { get { return "Native"; } }

		public IMapView Create(IMapViewHost host)
		{
			return MapView.Create(host);
		}
	}
}
