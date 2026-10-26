using Uno;
using Uno.Collections;
using Uno.Threading;
using Fuse.Controls;
using Fuse.Controls.Native.iOS;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Maps.Google.iOS
{
	[Require("source.include", "GoogleMaps/GoogleMaps.h")]
	extern (iOS) internal class GoogleMapHost
	{
		public readonly ObjC.Object Container;
		public readonly ObjC.Object Map;

		public GoogleMapHost()
		{
			Container = CreateContainer();
			Map = CreateMap(Container);
		}

		[Foreign(Language.ObjC)]
		ObjC.Object CreateContainer()
		@{
			return [[UIView alloc] init];
		@}

		[Foreign(Language.ObjC)]
		ObjC.Object CreateMap(ObjC.Object container)
		@{
			UIView* view = container;
			GMSCameraPosition* camera = [GMSCameraPosition cameraWithLatitude:0.0 longitude:0.0 zoom:2.0];
			GMSMapView* map = [GMSMapView mapWithFrame:view.bounds camera:camera];
			map.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
			[view addSubview:map];
			return map;
		@}

		[Foreign(Language.ObjC)]
		public void Dispose()
		@{
			GMSMapView* map = @{GoogleMapHost:of(_this).Map:get()};
			map.delegate = nil;
			[map removeFromSuperview];
		@}
	}

	[Require("source.include", "iOS/GoogleMapDelegate.h")]
	extern (iOS) public class GoogleMapView : LeafView, IMapView
	{
		GoogleMapHost _hostView;
		ObjC.Object _mapView;
		ObjC.Object _mapViewDelegate;
		IMapViewHost _host;
		MarkerIconCache _markerGraphicsCache;

		Dictionary<int, MarkerState> _markerStates = new Dictionary<int, MarkerState>();
		List<int> _removedMarkerUids = new List<int>();

		MapStyle _style;
		bool _showLocation;
		bool _showLocationButton;
		bool _showCompass;
		bool _allowZoom = true;
		bool _allowTilt = true;
		bool _allowRotate = true;
		bool _allowScroll = true;
		float4 _padding;
		double _minZoom = 0;
		double _maxZoom = 21;

		public static GoogleMapView Create(IMapViewHost host)
		{
			InitializeServices(GoogleMapProvider.ApiKey);
			return new GoogleMapView(host, new GoogleMapHost());
		}

		GoogleMapView(IMapViewHost host, GoogleMapHost hostView) : base(hostView.Container)
		{
			_host = host;
			_hostView = hostView;
			_mapView = hostView.Map;
			_markerGraphicsCache = new MarkerIconCache(UpdateMarkers);
			_mapViewDelegate = Configure(
				_mapView,
				OnReadyInternal,
				OnCameraIdle,
				OnMarkerTapped,
				OnMarkerSelected,
				OnMarkerDeselected,
				OnMarkerDragStarted,
				OnMarkerDragging,
				OnMarkerDragEnded,
				OnOverlayTapped,
				OnLocationTapped,
				OnLocationLongPress
			);
		}

		public override void Dispose()
		{
			DisposeDelegate();

			_hostView.Dispose();
			_mapView = null;
			_hostView = null;
			_markerStates.Clear();

			var host = _host;
			_host = null;
			if (host != null)
				host.OnViewDisposed(this);

			base.Dispose();
		}

		[Foreign(Language.ObjC)]
		static void InitializeServices(string apiKey)
		@{
			static bool initialized = false;
			if (initialized)
				return;
			initialized = true;

			NSString* key = apiKey;
			if (key == nil || key.length == 0)
				key = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"GoogleMapsAPIKey"];

			if (key != nil && key.length > 0)
				[GMSServices provideAPIKey:key];
		@}

		[Foreign(Language.ObjC)]
		ObjC.Object Configure(
			ObjC.Object mapView,
			Action onReady,
			Action onCameraIdle,
			Action<int, string> onMarkerTap,
			Action<int> onMarkerSelect,
			Action<int> onMarkerDeselect,
			Action<int> onMarkerDragStart,
			Action<int, double, double> onMarkerDrag,
			Action<int, double, double> onMarkerDragEnd,
			Action<int> onOverlayTap,
			Action<double, double> onMapTap,
			Action<double, double> onMapLongPress)
		@{
			GoogleMapDelegate* dg = [[GoogleMapDelegate alloc] init];
			[dg setAsDelegate:(GMSMapView*)mapView];
			[dg setActions:onReady
				onCameraIdle:onCameraIdle
				onMarkerTap:onMarkerTap
				onMarkerSelect:onMarkerSelect
				onMarkerDeselect:onMarkerDeselect
				onMarkerDragStart:onMarkerDragStart
				onMarkerDrag:onMarkerDrag
				onMarkerDragEnd:onMarkerDragEnd
				onOverlayTap:onOverlayTap
				onMapTap:onMapTap
				onMapLongPress:onMapLongPress];
			return dg;
		@}

		[Foreign(Language.ObjC)]
		void DisposeDelegate()
		@{
			GoogleMapDelegate* dg = (GoogleMapDelegate*)@{GoogleMapView:of(_this)._mapViewDelegate:get()};
			[dg cleanup];
		@}

		bool _isReady;
		bool _readyFired;

		public bool IsReady
		{
			get { return _isReady; }
		}

		public Action OnReady { get; set; }

		void OnReadyInternal()
		{
			_isReady = true;

			if (_readyFired)
				return;

			_readyFired = true;

			if (OnReady != null)
				OnReady();
		}

		/* Camera */

		public double Latitude
		{
			get { return GetLatitude(_mapView); }
		}

		public double Longitude
		{
			get { return GetLongitude(_mapView); }
		}

		public double Zoom
		{
			get { return GetZoom(_mapView); }
		}

		public double Tilt
		{
			get { return GetTilt(_mapView); }
		}

		public double Bearing
		{
			get { return GetBearing(_mapView); }
		}

		[Foreign(Language.ObjC)]
		static double GetLatitude(ObjC.Object map)
		@{
			return ((GMSMapView*)map).camera.target.latitude;
		@}

		[Foreign(Language.ObjC)]
		static double GetLongitude(ObjC.Object map)
		@{
			return ((GMSMapView*)map).camera.target.longitude;
		@}

		[Foreign(Language.ObjC)]
		static double GetZoom(ObjC.Object map)
		@{
			return ((GMSMapView*)map).camera.zoom;
		@}

		[Foreign(Language.ObjC)]
		static double GetTilt(ObjC.Object map)
		@{
			return ((GMSMapView*)map).camera.viewingAngle;
		@}

		[Foreign(Language.ObjC)]
		static double GetBearing(ObjC.Object map)
		@{
			return ((GMSMapView*)map).camera.bearing;
		@}

		public void SetLocation(double latitude, double longitude)
		{
			MoveTo(latitude, longitude, Zoom, Tilt, Bearing);
		}

		public void MoveTo(double latitude, double longitude, double zoomlevel, double tilt, double orientation)
		{
			MoveToNative(_mapView, latitude, longitude, zoomlevel, tilt, orientation, false);
		}

		public void AnimateTo(double latitude, double longitude, double zoomlevel, double tilt, double orientation, double duration)
		{
			MoveToNative(_mapView, latitude, longitude, zoomlevel, tilt, orientation, true);
		}

		[Foreign(Language.ObjC)]
		void MoveToNative(ObjC.Object map, double latitude, double longitude, double zoomlevel, double tilt, double orientation, bool animated)
		@{
			GMSMapView* view = (GMSMapView*)map;
			GMSCameraPosition* camera = [GMSCameraPosition cameraWithTarget:CLLocationCoordinate2DMake(latitude, longitude) zoom:zoomlevel bearing:orientation viewingAngle:tilt];

			if (animated)
				[view animateToCameraPosition:camera];
			else
				[view setCamera:camera];
		@}

		public void CancelAnimation()
		{
			CancelAnimationNative(_mapView);
		}

		[Foreign(Language.ObjC)]
		void CancelAnimationNative(ObjC.Object map)
		@{
			[((GMSMapView*)map).layer removeAllAnimations];
		@}

		public void ShowBounds(double minLatitude, double minLongitude, double maxLatitude, double maxLongitude)
		{
			ShowBoundsNative(_mapView, minLatitude, minLongitude, maxLatitude, maxLongitude, _padding.X, _padding.Y, _padding.Z, _padding.W);
		}

		[Foreign(Language.ObjC)]
		void ShowBoundsNative(ObjC.Object map, double minLatitude, double minLongitude, double maxLatitude, double maxLongitude, float left, float top, float right, float bottom)
		@{
			GMSMapView* view = (GMSMapView*)map;
			GMSCoordinateBounds* bounds = [[GMSCoordinateBounds alloc]
				initWithCoordinate:CLLocationCoordinate2DMake(minLatitude, minLongitude)
				coordinate:CLLocationCoordinate2DMake(maxLatitude, maxLongitude)];

			view.padding = UIEdgeInsetsMake(top, left, bottom, right);

			CGFloat padding = MAX(MAX(left, top), MAX(right, bottom));
			[view animateWithCameraUpdate:[GMSCameraUpdate fitBounds:bounds withPadding:padding]];
		@}

		public MapBounds GetVisibleBounds()
		{
			return new MapBounds(
				GetVisibleMinLatitude(_mapView),
				GetVisibleMinLongitude(_mapView),
				GetVisibleMaxLatitude(_mapView),
				GetVisibleMaxLongitude(_mapView)
			);
		}

		[Foreign(Language.ObjC)]
		static double GetVisibleMinLatitude(ObjC.Object map)
		@{
			GMSVisibleRegion region = ((GMSMapView*)map).projection.visibleRegion;
			return MIN(MIN(region.nearLeft.latitude, region.nearRight.latitude), MIN(region.farLeft.latitude, region.farRight.latitude));
		@}

		[Foreign(Language.ObjC)]
		static double GetVisibleMinLongitude(ObjC.Object map)
		@{
			GMSVisibleRegion region = ((GMSMapView*)map).projection.visibleRegion;
			return MIN(MIN(region.nearLeft.longitude, region.nearRight.longitude), MIN(region.farLeft.longitude, region.farRight.longitude));
		@}

		[Foreign(Language.ObjC)]
		static double GetVisibleMaxLatitude(ObjC.Object map)
		@{
			GMSVisibleRegion region = ((GMSMapView*)map).projection.visibleRegion;
			return MAX(MAX(region.nearLeft.latitude, region.nearRight.latitude), MAX(region.farLeft.latitude, region.farRight.latitude));
		@}

		[Foreign(Language.ObjC)]
		static double GetVisibleMaxLongitude(ObjC.Object map)
		@{
			GMSVisibleRegion region = ((GMSMapView*)map).projection.visibleRegion;
			return MAX(MAX(region.nearLeft.longitude, region.nearRight.longitude), MAX(region.farLeft.longitude, region.farRight.longitude));
		@}

		public void ZoomBy(double delta, double duration)
		{
			ZoomByNative(_mapView, (float)delta, duration > 0.0);
		}

		[Foreign(Language.ObjC)]
		void ZoomByNative(ObjC.Object map, float delta, bool animated)
		@{
			GMSCameraUpdate* update = [GMSCameraUpdate zoomBy:delta];

			if (animated)
				[((GMSMapView*)map) animateWithCameraUpdate:update];
			else
				[((GMSMapView*)map) moveCamera:update];
		@}

		public void ScrollBy(float dx, float dy, double duration)
		{
			ScrollByNative(_mapView, dx, dy, duration > 0.0);
		}

		[Foreign(Language.ObjC)]
		void ScrollByNative(ObjC.Object map, float dx, float dy, bool animated)
		@{
			GMSCameraUpdate* update = [GMSCameraUpdate scrollByX:dx Y:dy];

			if (animated)
				[((GMSMapView*)map) animateWithCameraUpdate:update];
			else
				[((GMSMapView*)map) moveCamera:update];
		@}

		/* Configuration */

		public MapStyle Style
		{
			get { return _style; }
			set
			{
				_style = value;
				SetMapTypeNative(_mapView, (int)value);
			}
		}

		[Foreign(Language.ObjC)]
		void SetMapTypeNative(ObjC.Object map, int type)
		@{
			GMSMapView* view = (GMSMapView*)map;

			switch (type)
			{
				case 1: view.mapType = kGMSTypeSatellite; break;
				case 2: view.mapType = kGMSTypeHybrid; break;
				case 3: view.mapType = kGMSTypeTerrain; break;
				default: view.mapType = kGMSTypeNormal; break;
			}
		@}

		public bool ShowMyLocation
		{
			get { return _showLocation; }
			set
			{
				_showLocation = value;

				if (value)
					RequestLocationAuth(HandleLocationAuthChange);
				else
					SetMyLocationEnabledNative(_mapView, false);
			}
		}

		void HandleLocationAuthChange(bool status)
		{
			if (status)
				SetMyLocationEnabledNative(_mapView, true);
		}

		[Foreign(Language.ObjC)]
		void RequestLocationAuth(Action<bool> callback)
		@{
			GoogleMapDelegate* dg = (GoogleMapDelegate*)@{GoogleMapView:of(_this)._mapViewDelegate:get()};
			[dg requestLocationAuth:callback];
		@}

		[Foreign(Language.ObjC)]
		void SetMyLocationEnabledNative(ObjC.Object map, bool enabled)
		@{
			((GMSMapView*)map).myLocationEnabled = enabled;
		@}

		public bool ShowMyLocationButton
		{
			get { return _showLocationButton; }
			set { _showLocationButton = value; ApplySettings(); }
		}

		public bool ShowCompass
		{
			get { return _showCompass; }
			set { _showCompass = value; ApplySettings(); }
		}

		public bool AllowZoom
		{
			get { return _allowZoom; }
			set { _allowZoom = value; ApplySettings(); }
		}

		public bool AllowTilt
		{
			get { return _allowTilt; }
			set { _allowTilt = value; ApplySettings(); }
		}

		public bool AllowRotate
		{
			get { return _allowRotate; }
			set { _allowRotate = value; ApplySettings(); }
		}

		public bool AllowScroll
		{
			get { return _allowScroll; }
			set { _allowScroll = value; ApplySettings(); }
		}

		void ApplySettings()
		{
			SetSettingsNative(_mapView, _showCompass, _showLocationButton, _allowZoom, _allowTilt, _allowRotate, _allowScroll);
		}

		[Foreign(Language.ObjC)]
		void SetSettingsNative(ObjC.Object map, bool compass, bool myLocationButton, bool zoom, bool tilt, bool rotate, bool scroll)
		@{
			GMSUISettings* settings = ((GMSMapView*)map).settings;
			settings.compassButton = compass;
			settings.myLocationButton = myLocationButton;
			settings.zoomGestures = zoom;
			settings.tiltGestures = tilt;
			settings.rotateGestures = rotate;
			settings.scrollGestures = scroll;
		@}

		public float4 Padding
		{
			get { return _padding; }
			set
			{
				_padding = value;
				SetPaddingNative(_mapView, value.X, value.Y, value.Z, value.W);
			}
		}

		[Foreign(Language.ObjC)]
		void SetPaddingNative(ObjC.Object map, float left, float top, float right, float bottom)
		@{
			((GMSMapView*)map).padding = UIEdgeInsetsMake(top, left, bottom, right);
		@}

		public double MinZoom
		{
			get { return _minZoom; }
			set
			{
				_minZoom = value;
				ApplyZoomLimits();
			}
		}

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
			SetZoomLimitsNative(_mapView, (float)_minZoom, (float)_maxZoom);
		}

		[Foreign(Language.ObjC)]
		void SetZoomLimitsNative(ObjC.Object map, float minZoom, float maxZoom)
		@{
			GMSMapView* view = (GMSMapView*)map;
			view.minZoom = minZoom;
			view.maxZoom = maxZoom;
		@}

		/* Markers */

		public void UpdateMarkers()
		{
			if (_mapView == null || _host == null)
				return;

			var markers = _host.Markers;

			var currentUids = new HashSet<int>();
			foreach (var marker in markers)
				currentUids.Add(marker.uid);

			_removedMarkerUids.Clear();
			foreach (var pair in _markerStates)
			{
				if (!currentUids.Contains(pair.Key))
					_removedMarkerUids.Add(pair.Key);
			}

			foreach (var uid in _removedMarkerUids)
			{
				RemoveMarkerNative(_mapView, uid);
				_markerStates.Remove(uid);
			}

			foreach (var marker in markers)
			{
				var state = MarkerState.From(marker, _markerGraphicsCache.Get(marker.IconFile));

				MarkerState previous;
				if (_markerStates.TryGetValue(marker.uid, out previous))
				{
					if (!state.Differs(previous))
						continue;

					UpdateMarkerNative(
						_mapView,
						marker.uid,
						state.Latitude,
						state.Longitude,
						state.Label,
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
					AddMarkerNative(
						_mapView,
						marker.uid,
						state.Latitude,
						state.Longitude,
						state.Label,
						state.Snippet,
						state.IconPath,
						state.IconAnchorX,
						state.IconAnchorY,
						state.Color,
						state.Draggable
					);
				}

				_markerStates[marker.uid] = state;
			}
		}

		[Foreign(Language.ObjC)]
		void AddMarkerNative(ObjC.Object map, int uid, double latitude, double longitude, string label, string snippet, string iconPath, float anchorX, float anchorY, float4 color, bool draggable)
		@{
			GoogleMapDelegate* dg = (GoogleMapDelegate*)@{GoogleMapView:of(_this)._mapViewDelegate:get()};
			UIColor* tint = color.W > 0.0f ? [UIColor colorWithRed:color.X green:color.Y blue:color.Z alpha:color.W] : nil;
			[dg addMarker:uid latitude:latitude longitude:longitude label:label snippet:snippet icon:iconPath anchorX:anchorX anchorY:anchorY color:tint draggable:draggable];
		@}

		[Foreign(Language.ObjC)]
		void UpdateMarkerNative(ObjC.Object map, int uid, double latitude, double longitude, string label, string snippet, string iconPath, float anchorX, float anchorY, float4 color, bool draggable)
		@{
			GoogleMapDelegate* dg = (GoogleMapDelegate*)@{GoogleMapView:of(_this)._mapViewDelegate:get()};
			UIColor* tint = color.W > 0.0f ? [UIColor colorWithRed:color.X green:color.Y blue:color.Z alpha:color.W] : nil;
			[dg updateMarker:uid latitude:latitude longitude:longitude label:label snippet:snippet icon:iconPath anchorX:anchorX anchorY:anchorY color:tint draggable:draggable];
		@}

		[Foreign(Language.ObjC)]
		void RemoveMarkerNative(ObjC.Object map, int uid)
		@{
			GoogleMapDelegate* dg = (GoogleMapDelegate*)@{GoogleMapView:of(_this)._mapViewDelegate:get()};
			[dg removeMarker:uid];
		@}

		public void SelectMarker(int uid)
		{
			SelectMarkerNative(_mapView, uid);
		}

		public void DeselectMarker(int uid)
		{
			DeselectMarkerNative(_mapView, uid);
		}

		[Foreign(Language.ObjC)]
		void SelectMarkerNative(ObjC.Object map, int uid)
		@{
			GoogleMapDelegate* dg = (GoogleMapDelegate*)@{GoogleMapView:of(_this)._mapViewDelegate:get()};
			[dg selectMarker:uid];
		@}

		[Foreign(Language.ObjC)]
		void DeselectMarkerNative(ObjC.Object map, int uid)
		@{
			GoogleMapDelegate* dg = (GoogleMapDelegate*)@{GoogleMapView:of(_this)._mapViewDelegate:get()};
			[dg deselectMarker:uid];
		@}

		public void ShowAllMarkers()
		{
			if (_host == null)
				return;

			var markers = _host.Markers;
			if (markers.Count == 0)
				return;

			double minLatitude = 90;
			double maxLatitude = -90;
			double minLongitude = 180;
			double maxLongitude = -180;

			foreach (var marker in markers)
			{
				minLatitude = Math.Min(minLatitude, marker.Latitude);
				maxLatitude = Math.Max(maxLatitude, marker.Latitude);
				minLongitude = Math.Min(minLongitude, marker.Longitude);
				maxLongitude = Math.Max(maxLongitude, marker.Longitude);
			}

			ShowBounds(minLatitude, minLongitude, maxLatitude, maxLongitude);
		}

		/* Overlays */

		public void UpdateOverlays()
		{
			if (_mapView == null || _host == null)
				return;

			ClearOverlaysNative(_mapView);

			foreach (var overlay in _host.Overlays)
			{
				if (!overlay.Visible)
					continue;

				switch (overlay.Type)
				{
					case OverlayType.Image:
						AddGroundOverlayNative(
							_mapView,
							overlay.Uid,
							_markerGraphicsCache.Get(overlay.ImageFile),
							overlay.MinLatitude,
							overlay.MinLongitude,
							overlay.MaxLatitude,
							overlay.MaxLongitude,
							overlay.Alpha,
							overlay.ZIndex
						);
						break;

					case OverlayType.Tile:
						AddTileLayerNative(
							_mapView,
							overlay.Uid,
							overlay.TileUrlTemplate,
							overlay.TileMinZoom,
							overlay.TileMaxZoom,
							overlay.Alpha,
							overlay.ZIndex
						);
						break;

					case OverlayType.Polygon:
						AddPolygonNative(
							_mapView,
							overlay.Uid,
							overlay.GetCoordinatesArray(),
							overlay.GetHolesCoordinatesArray(),
							overlay.GetHoleLengthsArray(),
							overlay.StrokeColor,
							overlay.FillColor,
							overlay.LineWidth,
							overlay.Geodesic,
							overlay.ZIndex,
							overlay.Alpha
						);
						break;

					case OverlayType.Circle:
						AddCircleNative(
							_mapView,
							overlay.Uid,
							overlay.CenterLatitude,
							overlay.CenterLongitude,
							overlay.Radius,
							overlay.StrokeColor,
							overlay.FillColor,
							overlay.LineWidth,
							overlay.ZIndex,
							overlay.Alpha
						);
						break;

					default:
						AddPolylineNative(
							_mapView,
							overlay.Uid,
							overlay.GetCoordinatesArray(),
							overlay.StrokeColor,
							overlay.LineWidth,
							overlay.Geodesic,
							overlay.ZIndex,
							overlay.Alpha
						);
						break;
				}
			}
		}

		[Foreign(Language.ObjC)]
		void ClearOverlaysNative(ObjC.Object map)
		@{
			GoogleMapDelegate* dg = (GoogleMapDelegate*)@{GoogleMapView:of(_this)._mapViewDelegate:get()};
			[dg clearOverlays];
		@}

		[Foreign(Language.ObjC)]
		void AddPolylineNative(ObjC.Object map, int uid, double[] coordinates, float4 strokeColor, int lineWidth, bool geodesic, int zIndex, float alpha)
		@{
			GoogleMapDelegate* dg = (GoogleMapDelegate*)@{GoogleMapView:of(_this)._mapViewDelegate:get()};
			[dg addPolyline:uid
				coordinates:coordinates
				strokeColor:[UIColor colorWithRed:strokeColor.X green:strokeColor.Y blue:strokeColor.Z alpha:strokeColor.W]
				lineWidth:lineWidth
				geodesic:geodesic
				zIndex:zIndex
				alpha:alpha];
		@}

		[Foreign(Language.ObjC)]
		void AddPolygonNative(ObjC.Object map, int uid, double[] coordinates, double[] holeCoordinates, int[] holeLengths, float4 strokeColor, float4 fillColor, int lineWidth, bool geodesic, int zIndex, float alpha)
		@{
			GoogleMapDelegate* dg = (GoogleMapDelegate*)@{GoogleMapView:of(_this)._mapViewDelegate:get()};
			[dg addPolygon:uid
				coordinates:coordinates
				holes:holeCoordinates
				holeLengths:holeLengths
				strokeColor:[UIColor colorWithRed:strokeColor.X green:strokeColor.Y blue:strokeColor.Z alpha:strokeColor.W]
				fillColor:[UIColor colorWithRed:fillColor.X green:fillColor.Y blue:fillColor.Z alpha:fillColor.W]
				lineWidth:lineWidth
				geodesic:geodesic
				zIndex:zIndex
				alpha:alpha];
		@}

		[Foreign(Language.ObjC)]
		void AddCircleNative(ObjC.Object map, int uid, double latitude, double longitude, double radius, float4 strokeColor, float4 fillColor, int lineWidth, int zIndex, float alpha)
		@{
			GoogleMapDelegate* dg = (GoogleMapDelegate*)@{GoogleMapView:of(_this)._mapViewDelegate:get()};
			[dg addCircle:uid
				latitude:latitude
				longitude:longitude
				radius:radius
				strokeColor:[UIColor colorWithRed:strokeColor.X green:strokeColor.Y blue:strokeColor.Z alpha:strokeColor.W]
				fillColor:[UIColor colorWithRed:fillColor.X green:fillColor.Y blue:fillColor.Z alpha:fillColor.W]
				lineWidth:lineWidth
				zIndex:zIndex
				alpha:alpha];
		@}

		[Foreign(Language.ObjC)]
		void AddGroundOverlayNative(ObjC.Object map, int uid, string imagePath, double minLatitude, double minLongitude, double maxLatitude, double maxLongitude, float opacity, int zIndex)
		@{
			GoogleMapDelegate* dg = (GoogleMapDelegate*)@{GoogleMapView:of(_this)._mapViewDelegate:get()};
			[dg addGroundOverlay:uid
				image:imagePath
				minLatitude:minLatitude
				minLongitude:minLongitude
				maxLatitude:maxLatitude
				maxLongitude:maxLongitude
				opacity:opacity
				zIndex:zIndex];
		@}

		[Foreign(Language.ObjC)]
		void AddTileLayerNative(ObjC.Object map, int uid, string urlTemplate, int minZoom, int maxZoom, float opacity, int zIndex)
		@{
			GoogleMapDelegate* dg = (GoogleMapDelegate*)@{GoogleMapView:of(_this)._mapViewDelegate:get()};
			[dg addTileLayer:uid
				urlTemplate:urlTemplate
				minZoom:minZoom
				maxZoom:maxZoom
				opacity:opacity
				zIndex:zIndex];
		@}

		/* Routes */

		public void UpdateRoutes()
		{
			if (_mapView == null || _host == null)
				return;

			ClearRoutesNative(_mapView);

			foreach (var route in _host.Routes)
			{
				if (route.NeedsCalculation)
				{
					route.MarkCalculationStarted();

					var callback = new RouteCallback(_host, route.Uid, route.Generation);
					CalculateRouteNative(
						_mapView,
						route.FromLatitude,
						route.FromLongitude,
						route.ToLatitude,
						route.ToLongitude,
						(int)route.Mode,
						GoogleMapProvider.ApiKey,
						callback.OnSuccess,
						callback.OnError
					);
				}

				if (route.Visible && route.HasPolyline)
				{
					AddRoutePolylineNative(
						_mapView,
						route.Uid,
						route.GetPolylineArray(),
						route.StrokeColor,
						route.LineWidth,
						route.Alpha,
						route.ZIndex
					);
				}
			}
		}

		[Foreign(Language.ObjC)]
		void ClearRoutesNative(ObjC.Object map)
		@{
			GoogleMapDelegate* dg = (GoogleMapDelegate*)@{GoogleMapView:of(_this)._mapViewDelegate:get()};
			[dg clearRoutes];
		@}

		[Foreign(Language.ObjC)]
		void AddRoutePolylineNative(ObjC.Object map, int uid, double[] coordinates, float4 strokeColor, int lineWidth, float alpha, int zIndex)
		@{
			GoogleMapDelegate* dg = (GoogleMapDelegate*)@{GoogleMapView:of(_this)._mapViewDelegate:get()};
			[dg addRoutePolyline:uid
				coordinates:coordinates
				strokeColor:[UIColor colorWithRed:strokeColor.X green:strokeColor.Y blue:strokeColor.Z alpha:strokeColor.W]
				lineWidth:lineWidth
				alpha:alpha
				zIndex:zIndex];
		@}

		/* Geocoding and routing */

		public Future<MapPlace[]> Geocode(string query)
		{
			var promise = new Promise<MapPlace[]>();

			if (_mapView == null)
			{
				promise.Reject(new Exception("The map is not ready"));
				return promise;
			}

			var callback = new PlaceCallback(promise);
			GeocodeNative(_mapView, query, GoogleMapProvider.ApiKey, callback.OnSuccess, callback.OnError);
			return promise;
		}

		[Foreign(Language.ObjC)]
		void GeocodeNative(ObjC.Object map, string query, string apiKey, Action<string> onSuccess, Action<string> onError)
		@{
			GoogleMapDelegate* dg = (GoogleMapDelegate*)@{GoogleMapView:of(_this)._mapViewDelegate:get()};
			[dg geocode:query apiKey:apiKey success:onSuccess error:onError];
		@}

		public Future<MapPlace[]> ReverseGeocode(double latitude, double longitude)
		{
			var promise = new Promise<MapPlace[]>();

			if (_mapView == null)
			{
				promise.Reject(new Exception("The map is not ready"));
				return promise;
			}

			var callback = new PlaceCallback(promise);
			ReverseGeocodeNative(_mapView, latitude, longitude, GoogleMapProvider.ApiKey, callback.OnSuccess, callback.OnError);
			return promise;
		}

		[Foreign(Language.ObjC)]
		void ReverseGeocodeNative(ObjC.Object map, double latitude, double longitude, string apiKey, Action<string> onSuccess, Action<string> onError)
		@{
			GoogleMapDelegate* dg = (GoogleMapDelegate*)@{GoogleMapView:of(_this)._mapViewDelegate:get()};
			[dg reverseGeocode:latitude longitude:longitude apiKey:apiKey success:onSuccess error:onError];
		@}

		public Future<MapRouteResult> CalculateRoute(double fromLatitude, double fromLongitude, double toLatitude, double toLongitude, RouteMode mode)
		{
			var promise = new Promise<MapRouteResult>();

			if (_mapView == null)
			{
				promise.Reject(new Exception("The map is not ready"));
				return promise;
			}

			var callback = new RoutePromiseCallback(promise);
			CalculateRouteNative(
				_mapView,
				fromLatitude,
				fromLongitude,
				toLatitude,
				toLongitude,
				(int)mode,
				GoogleMapProvider.ApiKey,
				callback.OnSuccess,
				callback.OnError
			);
			return promise;
		}

		[Foreign(Language.ObjC)]
		void CalculateRouteNative(ObjC.Object map, double fromLatitude, double fromLongitude, double toLatitude, double toLongitude, int mode, string apiKey, Action<string> onSuccess, Action<string> onError)
		@{
			GoogleMapDelegate* dg = (GoogleMapDelegate*)@{GoogleMapView:of(_this)._mapViewDelegate:get()};
			[dg calculateRouteFrom:fromLatitude
				fromLongitude:fromLongitude
				toLatitude:toLatitude
				toLongitude:toLongitude
				mode:mode
				apiKey:apiKey
				success:onSuccess
				error:onError];
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

		class RoutePromiseCallback
		{
			readonly Promise<MapRouteResult> _promise;

			public RoutePromiseCallback(Promise<MapRouteResult> promise)
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

		class RouteCallback
		{
			readonly IMapViewHost _host;
			readonly int _uid;
			readonly int _generation;

			public RouteCallback(IMapViewHost host, int uid, int generation)
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

		/* Snapshot */

		public void Snapshot(Action<string> onSuccess, Action<string> onError)
		{
			if (_mapView == null)
			{
				if (onError != null)
					onError("The map is not ready");
				return;
			}

			TakeSnapshotNative(_mapView, onSuccess, onError);
		}

		[Foreign(Language.ObjC)]
		void TakeSnapshotNative(ObjC.Object map, Action<string> onSuccess, Action<string> onError)
		@{
			GoogleMapDelegate* dg = (GoogleMapDelegate*)@{GoogleMapView:of(_this)._mapViewDelegate:get()};
			[dg takeSnapshot:onSuccess error:onError];
		@}

		/* Provider callbacks */

		void OnCameraIdle()
		{
			if (_host != null)
				_host.OnCameraChanged();
		}

		void OnMarkerTapped(int id, string label)
		{
			if (_host != null)
				_host.OnMarkerTapped(id, label);
		}

		void OnMarkerSelected(int id)
		{
			if (_host != null)
				_host.OnMarkerSelected(id);
		}

		void OnMarkerDeselected(int id)
		{
			if (_host != null)
				_host.OnMarkerDeselected(id);
		}

		void OnMarkerDragStarted(int id)
		{
			if (_host != null)
				_host.OnMarkerDragStarted(id);
		}

		void OnMarkerDragging(int id, double latitude, double longitude)
		{
			if (_host != null)
				_host.OnMarkerDragging(id, latitude, longitude);
		}

		void OnMarkerDragEnded(int id, double latitude, double longitude)
		{
			if (_host != null)
				_host.OnMarkerDragEnded(id, latitude, longitude);
		}

		void OnOverlayTapped(int id)
		{
			if (_host != null)
				_host.OnOverlayTapped(id);
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
	}
}
