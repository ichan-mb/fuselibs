package com.fuse.maps;
import android.os.Bundle;
import android.widget.FrameLayout;
import android.graphics.Bitmap;
import android.graphics.Color;

import com.google.android.gms.maps.MapsInitializer;
import com.google.android.gms.maps.CameraUpdate;
import com.google.android.gms.maps.CameraUpdateFactory;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.GoogleMap.SnapshotReadyCallback;
import com.google.android.gms.maps.MapView;
import com.google.android.gms.maps.OnMapReadyCallback;
import com.google.android.gms.maps.UiSettings;
import com.google.android.gms.maps.model.CameraPosition;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.Marker;
import com.google.android.gms.maps.model.MarkerOptions;
import com.google.android.gms.maps.model.Polyline;
import com.google.android.gms.maps.model.PolylineOptions;
import com.google.android.gms.maps.model.Polygon;
import com.google.android.gms.maps.model.Circle;
import com.google.android.gms.maps.model.CircleOptions;
import com.google.android.gms.maps.model.PolygonOptions;
import com.google.android.gms.maps.model.Cap;
import com.google.android.gms.maps.model.ButtCap;
import com.google.android.gms.maps.model.RoundCap;
import com.google.android.gms.maps.model.SquareCap;
import com.google.android.gms.maps.model.JointType;
import com.google.android.gms.maps.model.Dash;
import com.google.android.gms.maps.model.Gap;
import com.google.android.gms.maps.model.Dot;
import com.google.android.gms.maps.model.PatternItem;
import com.google.android.gms.maps.model.BitmapDescriptorFactory;
import com.google.android.gms.maps.model.LatLngBounds;
import com.google.android.gms.maps.model.GroundOverlay;
import com.google.android.gms.maps.model.GroundOverlayOptions;
import com.google.android.gms.maps.model.TileOverlay;
import com.google.android.gms.maps.model.TileOverlayOptions;
import com.google.android.gms.maps.model.UrlTileProvider;
import java.net.URL;
import java.net.MalformedURLException;
import java.net.HttpURLConnection;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import org.json.JSONArray;
import org.json.JSONObject;
import java.util.Map;
import java.util.List;
import java.util.Arrays;
import java.util.ArrayList;
import java.util.HashMap;
import java.io.FileOutputStream;
import com.foreign.Uno.Action_String;

public class FuseMap extends FrameLayout {

	public interface FuseMapCallback
	{
		void onReady();
		void onLongPress(double lat, double lng);
		void onPress(double lat, double lng);
		void onCameraIdle();
		boolean onMarkerPress(Marker m);
		void onPolygonPress(Polygon p);
		void onPolylinePress(Polyline p);
		void onCirclePress(Circle c);
		void onMarkerSelected(int uid);
		void onMarkerDeselected(int uid);
		void onMarkerDragStart(int uid);
		void onMarkerDrag(int uid, double lat, double lng);
		void onMarkerDragEnd(int uid, double lat, double lng);
	}

	private FuseMapCallback _callback;
	private GoogleMap _googleMap;
	private MapView _mapView;
	private boolean _resumed;
	private boolean _created;
	private int _paddingLeft;
	private int _paddingTop;
	private int _paddingRight;
	private int _paddingBottom;
	private float _minZoom = 0f;
	private float _maxZoom = 21f;
	private Map<Marker, Integer> _markerIDs;
	private Map<Integer, Marker> _markersByUid;
	private Map<Polyline, Integer> _polylines;
	private Map<Polygon, Integer> _polygons;
	private Map<Circle, Integer> _circles;
	private Map<GroundOverlay, Integer> _groundOverlays;
	private Map<TileOverlay, Integer> _tileOverlays;
	private Map<Integer, Polyline> _routePolylines;

	public FuseMap()
	{
		super(com.fuse.Activity.getRootActivity());
		MapsInitializer.initialize(com.fuse.Activity.getRootActivity());
		_mapView = new MapView(com.fuse.Activity.getRootActivity());
		addView(_mapView);
		_markerIDs = new HashMap<Marker,Integer>();
		_markersByUid = new HashMap<Integer,Marker>();
		_polylines = new HashMap<Polyline, Integer>();
		_polygons = new HashMap<Polygon, Integer>();
		_circles = new HashMap<Circle, Integer>();
		_groundOverlays = new HashMap<GroundOverlay, Integer>();
		_tileOverlays = new HashMap<TileOverlay, Integer>();
		_routePolylines = new HashMap<Integer, Polyline>();

		_mapView.getMapAsync(new OnMapReadyCallback()
		{
			@Override
			public void onMapReady(GoogleMap googleMap)
			{
				configure(googleMap);
			}
		});
	}

	public int getIdforMarker(Marker m)
	{
		Integer id = _markerIDs.get(m);
		return id == null ? -1 : id.intValue();
	}

	public int getIdforPolygon(Polygon p)
	{
		Integer id = _polygons.get(p);
		return id == null ? -1 : id.intValue();
	}

	public int getIdforPolyline(Polyline p)
	{
		Integer id = _polylines.get(p);
		return id == null ? -1 : id.intValue();
	}

	public int getIdforCircle(Circle c)
	{
		Integer id = _circles.get(c);
		return id == null ? -1 : id.intValue();
	}

	public void SetCallback(FuseMapCallback callback)
	{
		_callback = callback;
	}

	public void dispose()
	{
		if (_googleMap!=null)
		{
			_googleMap.setOnCameraIdleListener(null);
			_googleMap.setOnMapClickListener(null);
			_googleMap.setOnMapLongClickListener(null);
			_googleMap.setOnMarkerClickListener(null);
			_googleMap.setOnMarkerDragListener(null);
			_googleMap.setOnInfoWindowCloseListener(null);
			_googleMap.setOnPolygonClickListener(null);
			_googleMap.setOnPolylineClickListener(null);
			_googleMap.setOnCircleClickListener(null);
		}
		if (_mapView!=null)
		{
			onPause();
			onDestroy();
			removeView(_mapView);
		}
		_callback = null;
		_googleMap = null;
		_mapView = null;
		_markerIDs = null;
		_markersByUid = null;
		_polylines = null;
		_polygons = null;
		_circles = null;
		_groundOverlays = null;
		_tileOverlays = null;
		_routePolylines = null;
	}

	public void setMyLocationEnabled(boolean b){
		if (_googleMap == null) return;
		_googleMap.setMyLocationEnabled(b);
	}

	private void configure(GoogleMap map)
	{
		_googleMap = map;
		_googleMap.setOnCameraIdleListener(new GoogleMap.OnCameraIdleListener()
		{
			@Override
			public void onCameraIdle()
			{
				FuseMap.this.onCameraIdle();
			}
		});

		_googleMap.setOnMapLongClickListener(new GoogleMap.OnMapLongClickListener()
		{
			@Override
			public void onMapLongClick(LatLng latLng)
			{
				onMapLongPress(latLng);
			}
		});

		_googleMap.setOnMapClickListener(new GoogleMap.OnMapClickListener()
		{
			@Override
			public void onMapClick(LatLng latLng)
			{
				onClick(latLng);
			}
		});

		_googleMap.setOnMarkerClickListener(new GoogleMap.OnMarkerClickListener()
		{
			@Override
			public boolean onMarkerClick(Marker marker)
			{
				return onMarkerPress(marker);
			}
		});

		_googleMap.setOnMarkerDragListener(new GoogleMap.OnMarkerDragListener()
		{
			@Override
			public void onMarkerDragStart(Marker marker)
			{
				markerDragStart(marker);
			}
			@Override
			public void onMarkerDrag(Marker marker)
			{
				LatLng p = marker.getPosition();
				onMarkerDragged(marker, p.latitude, p.longitude);
			}
			@Override
			public void onMarkerDragEnd(Marker marker)
			{
				LatLng p = marker.getPosition();
				onMarkerDragEnded(marker, p.latitude, p.longitude);
			}
		});

		_googleMap.setOnInfoWindowCloseListener(new GoogleMap.OnInfoWindowCloseListener()
		{
			@Override
			public void onInfoWindowClose(Marker marker)
			{
				markerDeselected(marker);
			}
		});

		_googleMap.setOnPolygonClickListener(new GoogleMap.OnPolygonClickListener() {

			@Override
			public void onPolygonClick(Polygon polygon) {
				onPolygonPress(polygon);
			}
		});

		_googleMap.setOnPolylineClickListener(new GoogleMap.OnPolylineClickListener() {

			@Override
			public void onPolylineClick(Polyline polyline) {
				onPolylinePress(polyline);
			}
		});

		_googleMap.setOnCircleClickListener(new GoogleMap.OnCircleClickListener() {

			@Override
			public void onCircleClick(Circle circle) {
				onCirclePress(circle);
			}
		});

		if (_callback!=null)
			_callback.onReady();
	}

	void onPolygonPress(Polygon polygon)
	{
		if (_callback != null)
			_callback.onPolygonPress(polygon);
	}

	void onPolylinePress(Polyline polyline)
	{
		if (_callback != null)
			_callback.onPolylinePress(polyline);
	}

	void onCirclePress(Circle circle)
	{
		if (_callback != null)
			_callback.onCirclePress(circle);
	}

	private boolean onMarkerPress(Marker marker)
	{
		if (_callback != null)
		{
			int uid = getIdforMarker(marker);
			if (uid >= 0)
				_callback.onMarkerSelected(uid);
			return _callback.onMarkerPress(marker);
		}
		return false;
	}

	private void markerDragStart(Marker marker)
	{
		if (_callback == null) return;
		int uid = getIdforMarker(marker);
		if (uid >= 0)
			_callback.onMarkerDragStart(uid);
	}

	private void onMarkerDragged(Marker marker, double lat, double lng)
	{
		if (_callback == null) return;
		int uid = getIdforMarker(marker);
		if (uid >= 0)
			_callback.onMarkerDrag(uid, lat, lng);
	}

	private void onMarkerDragEnded(Marker marker, double lat, double lng)
	{
		if (_callback == null) return;
		int uid = getIdforMarker(marker);
		if (uid >= 0)
			_callback.onMarkerDragEnd(uid, lat, lng);
	}

	private void markerDeselected(Marker marker)
	{
		if (_callback == null) return;
		int uid = getIdforMarker(marker);
		if (uid >= 0)
			_callback.onMarkerDeselected(uid);
	}

	void onMapLongPress(LatLng latLng)
	{
		if (_callback != null)
			_callback.onLongPress(latLng.latitude, latLng.longitude);
	}

	void onClick(LatLng latLng)
	{
		if (_callback != null)
			_callback.onPress(latLng.latitude, latLng.longitude);
	}

	/* Markers */

	public String addMarker(double lat, double lng, String label, String snippet, String iconPath, float iconAnchorX, float iconAnchorY, int color, boolean draggable, int uid)
	{
		if (_googleMap == null) return null;
		MarkerOptions opt = new MarkerOptions().position(new LatLng(lat, lng));
		if (iconPath!=null)
		{
			opt.icon(BitmapDescriptorFactory.fromPath(iconPath)).anchor(iconAnchorX, iconAnchorY);
		}
		else
		{
			opt.icon(defaultMarker(color));
		}
		if (label!=null) opt.title(label);
		if (snippet!=null) opt.snippet(snippet);
		opt.draggable(draggable);
		Marker m =  _googleMap.addMarker(opt);
		_markerIDs.put(m, uid);
		_markersByUid.put(uid, m);
		return m.getId();
	}

	public String updateMarker(int uid, double lat, double lng, String label, String snippet, String iconPath, float iconAnchorX, float iconAnchorY, int color, boolean draggable)
	{
		if (_googleMap == null) return null;
		Marker m = _markersByUid.get(uid);
		if (m == null) return null;

		m.setPosition(new LatLng(lat, lng));
		m.setTitle(label);
		m.setSnippet(snippet);
		m.setDraggable(draggable);

		if (iconPath!=null)
		{
			m.setIcon(BitmapDescriptorFactory.fromPath(iconPath));
			m.setAnchor(iconAnchorX, iconAnchorY);
		}
		else
		{
			m.setIcon(defaultMarker(color));
		}

		return m.getId();
	}

	private BitmapDescriptor defaultMarker(int color)
	{
		int alpha = (color >>> 24) & 0xFF;
		if (alpha == 0)
			return BitmapDescriptorFactory.defaultMarker();

		float[] hsv = new float[3];
		Color.colorToHSV(color, hsv);
		return BitmapDescriptorFactory.defaultMarker(hsv[0]);
	}

	public void removeMarker(int uid)
	{
		if (_markersByUid == null) return;
		Marker m = _markersByUid.remove(uid);
		if (m == null) return;

		if (_markerIDs != null)
			_markerIDs.remove(m);
		m.remove();
	}

	public void selectMarker(int uid)
	{
		if (_markersByUid == null) return;
		Marker m = _markersByUid.get(uid);
		if (m != null)
			m.showInfoWindow();
	}

	public void deselectMarker(int uid)
	{
		if (_markersByUid == null) return;
		Marker m = _markersByUid.get(uid);
		if (m != null)
			m.hideInfoWindow();
	}

	private Cap convertIntCap(int cap)
	{
		Cap capObj = null;
		switch (cap)
		{
			case 0: capObj = new RoundCap(); break;
			case 1: capObj = new ButtCap(); break;
			case 2: capObj = new SquareCap(); break;
			default:
				capObj = new RoundCap();
		}
		return capObj;
	}

	private int selectJointType(int joinType)
	{
		int jointType;
		switch (joinType) {
			case 0: jointType = JointType.ROUND; break;
			case 1: jointType = JointType.BEVEL; break;
			case 2: jointType = JointType.DEFAULT; break;
			default:
				jointType = JointType.ROUND;
		}
		return jointType;
	}

	private Polyline drawPolyline(List<LatLng> points, int strokeColor, int lineWidth, boolean geodesic, int startCap, int endCap, int jointType, List<PatternItem> pattern, float zIndex)
	{
		Cap sCap = convertIntCap(startCap);
		Cap eCap = convertIntCap(endCap);
		PolylineOptions options = new PolylineOptions()
			.color(strokeColor)
			.width(lineWidth)
			.startCap(sCap)
			.endCap(eCap)
			.jointType(jointType)
			.geodesic(geodesic)
			.zIndex(zIndex)
			.addAll(points);
		if (pattern != null)
			options.pattern(pattern);
		return _googleMap.addPolyline(options);
	}

	private Polygon drawPolygon(List<LatLng> points, List<List<LatLng>> holes, int strokeColor, int fillColor, int lineWidth, boolean geodesic, int jointType, List<PatternItem> pattern, float zIndex)
	{
		PolygonOptions options = new PolygonOptions()
			.strokeColor(strokeColor)
			.fillColor(fillColor)
			.strokeWidth(lineWidth)
			.strokeJointType(jointType)
			.geodesic(geodesic)
			.zIndex(zIndex)
			.addAll(points);

		if (holes != null)
		{
			for (List<LatLng> hole : holes)
				options.addHole(hole);
		}

		if (pattern != null)
			options.strokePattern(pattern);

		return _googleMap.addPolygon(options);
	}

	private Circle drawCircle(LatLng center, double radius, int strokeColor, int fillColor, int lineWidth, List<PatternItem> pattern, float zIndex)
	{
		CircleOptions options = new CircleOptions()
			.strokeColor(strokeColor)
			.fillColor(fillColor)
			.strokeWidth(lineWidth)
			.center(center)
			.radius(radius)
			.strokePattern(pattern)
			.zIndex(zIndex);
		return _googleMap.addCircle(options);
	}

	private List<PatternItem> constructPattern(int[] dashPattern)
	{
		if (dashPattern.length == 2) {
			if (dashPattern[0] > 0 && dashPattern[1] > 0)
				return Arrays.asList(new Gap(dashPattern[1]), new Dash(dashPattern[0]));
		}
		return null;
	}

	public String AddOverlay(int type, double[] coordinates, double[] holeCoordinates, int[] holeLengths, int strokeColor, int fillColor, int lineWidth, boolean geodesic, int startCap, int endCap, int joinType, int[] dashPattern, double centerLatitude, double centerLongitude, double radius, int zIndex, float alpha, int uid)
	{
		if (_googleMap == null) return null;

		int jointType = selectJointType(joinType);
		List<PatternItem> pattern = constructPattern(dashPattern);
		List<LatLng> points = new ArrayList<>();
		for (int i=0; i<coordinates.length; i+=2)
			points.add(new LatLng(coordinates[i], coordinates[i+1]));

		strokeColor = applyAlpha(strokeColor, alpha);
		fillColor = applyAlpha(fillColor, alpha);
		float z = (float)zIndex;

		switch (type)
		{
			case 1:
			{
				List<List<LatLng>> holes = buildHoles(holeCoordinates, holeLengths);
				Polygon polygon = drawPolygon(points, holes, strokeColor, fillColor, lineWidth, geodesic, jointType, pattern, z);
				polygon.setClickable(true);
				_polygons.put(polygon, uid);
				return polygon.getId();
			}
			case 2:
			{
				Circle circle = drawCircle(new LatLng(centerLatitude, centerLongitude), radius, strokeColor, fillColor, lineWidth, pattern, z);
				circle.setClickable(true);
				_circles.put(circle, uid);
				return circle.getId();
			}
			default:
			{
				Polyline polyline = drawPolyline(points, strokeColor, lineWidth, geodesic, startCap, endCap, jointType, pattern, z);
				polyline.setClickable(true);
				_polylines.put(polyline, uid);
				return polyline.getId();
			}
		}
	}

	private int applyAlpha(int color, float alpha)
	{
		if (alpha >= 1.0f) return color;
		if (alpha <= 0.0f) return color & 0x00FFFFFF;

		int a = (int)(((color >>> 24) & 0xFF) * alpha);
		return (color & 0x00FFFFFF) | (a << 24);
	}

	private List<List<LatLng>> buildHoles(double[] holeCoordinates, int[] holeLengths)
	{
		if (holeCoordinates == null || holeLengths == null || holeLengths.length == 0)
			return null;

		List<List<LatLng>> holes = new ArrayList<>();
		int offset = 0;

		for (int h = 0; h < holeLengths.length; h++)
		{
			int count = holeLengths[h];
			if (count < 3)
			{
				offset += count * 2;
				continue;
			}

			List<LatLng> hole = new ArrayList<>();
			for (int i = 0; i < count; i++)
			{
				hole.add(new LatLng(holeCoordinates[offset], holeCoordinates[offset + 1]));
				offset += 2;
			}
			holes.add(hole);
		}

		return holes;
	}

	public String addImageOverlay(String imagePath, double minLatitude, double minLongitude, double maxLatitude, double maxLongitude, float opacity, int zIndex, int uid)
	{
		if (_googleMap == null || imagePath == null) return null;
		if (maxLatitude <= minLatitude || maxLongitude <= minLongitude) return null;

		BitmapDescriptor descriptor;
		try {
			descriptor = BitmapDescriptorFactory.fromPath(imagePath);
		} catch (Exception e) {
			return null;
		}

		LatLngBounds bounds = new LatLngBounds(
			new LatLng(minLatitude, minLongitude),
			new LatLng(maxLatitude, maxLongitude));

		GroundOverlayOptions options = new GroundOverlayOptions()
			.image(descriptor)
			.positionFromBounds(bounds)
			.transparency(Math.max(0f, Math.min(1f, 1f - opacity)))
			.zIndex((float)zIndex);

		GroundOverlay overlay = _googleMap.addGroundOverlay(options);
		_groundOverlays.put(overlay, uid);
		return overlay.getId();
	}

	public String addTileOverlay(final String urlTemplate, int minZoom, int maxZoom, float opacity, int zIndex, int uid)
	{
		if (_googleMap == null || urlTemplate == null) return null;

		UrlTileProvider provider = new UrlTileProvider(256, 256)
		{
			@Override
			public URL getTileUrl(int x, int y, int zoom)
			{
				String url = urlTemplate
					.replace("{x}", Integer.toString(x))
					.replace("{y}", Integer.toString(y))
					.replace("{z}", Integer.toString(zoom));

				try {
					return new URL(url);
				} catch (MalformedURLException e) {
					return null;
				}
			}
		};

		TileOverlayOptions options = new TileOverlayOptions()
			.tileProvider(provider)
			.transparency(Math.max(0f, Math.min(1f, 1f - opacity)))
			.zIndex((float)zIndex);

		TileOverlay overlay = _googleMap.addTileOverlay(options);
		_tileOverlays.put(overlay, uid);
		return null;
	}

	public void clearOverlays()
	{
		if (_googleMap == null) return;
		for (Polyline polyline : _polylines.keySet()) {
			polyline.remove();
		}
		_polylines.clear();
		for (Polygon polygon : _polygons.keySet()) {
			polygon.remove();
		}
		_polygons.clear();
		for (Circle circle : _circles.keySet()) {
			circle.remove();
		}
		_circles.clear();
		for (GroundOverlay overlay : _groundOverlays.keySet()) {
			overlay.remove();
		}
		_groundOverlays.clear();
		for (TileOverlay overlay : _tileOverlays.keySet()) {
			overlay.remove();
		}
		_tileOverlays.clear();
	}

	/* Routes */

	public void clearRoutes()
	{
		if (_googleMap == null || _routePolylines == null) return;

		for (Polyline line : _routePolylines.values())
			line.remove();
		_routePolylines.clear();
	}

	public void addRoutePolyline(int uid, double[] coordinates, int color, int lineWidth, float alpha, int zIndex)
	{
		if (_googleMap == null || _routePolylines == null || coordinates == null || coordinates.length < 4)
			return;

		Polyline existing = _routePolylines.get(uid);
		if (existing != null)
		{
			existing.remove();
			_routePolylines.remove(uid);
		}

		List<LatLng> points = new ArrayList<>();
		for (int i = 0; i + 1 < coordinates.length; i += 2)
			points.add(new LatLng(coordinates[i], coordinates[i + 1]));

		PolylineOptions options = new PolylineOptions()
			.color(applyAlpha(color, alpha))
			.width(lineWidth)
			.zIndex((float)zIndex)
			.addAll(points);

		_routePolylines.put(uid, _googleMap.addPolyline(options));
	}

	/* Geocoding and routing */

	public String geocode(String query, int maxResults)
	{
		if (!android.location.Geocoder.isPresent()) return null;

		try {
			android.location.Geocoder geocoder = new android.location.Geocoder(com.fuse.Activity.getRootActivity(), java.util.Locale.getDefault());
			return encodeAddresses(geocoder.getFromLocationName(query, maxResults));
		} catch (Exception e) {
			return null;
		}
	}

	public String reverseGeocode(double latitude, double longitude, int maxResults)
	{
		if (!android.location.Geocoder.isPresent()) return null;

		try {
			android.location.Geocoder geocoder = new android.location.Geocoder(com.fuse.Activity.getRootActivity(), java.util.Locale.getDefault());
			return encodeAddresses(geocoder.getFromLocation(latitude, longitude, maxResults));
		} catch (Exception e) {
			return null;
		}
	}

	private String encodeAddresses(java.util.List<android.location.Address> addresses)
	{
		if (addresses == null) return "";

		StringBuilder builder = new StringBuilder();
		for (android.location.Address address : addresses)
		{
			String name = address.getFeatureName();
			if (name == null) name = address.getLocality();
			if (name == null) name = "";

			builder.append(sanitize(name)).append('\t')
				.append(sanitize(formatAddress(address))).append('\t')
				.append(address.getLatitude()).append('\t')
				.append(address.getLongitude()).append('\n');
		}
		return builder.toString();
	}

	private String formatAddress(android.location.Address address)
	{
		StringBuilder builder = new StringBuilder();
		int max = address.getMaxAddressLineIndex();

		for (int i = 0; i <= max; i++)
		{
			String line = address.getAddressLine(i);
			if (line == null || line.length() == 0) continue;
			if (builder.length() > 0) builder.append(", ");
			builder.append(line);
		}

		return builder.toString();
	}

	private String sanitize(String value)
	{
		if (value == null) return "";
		return value.replace('\t', ' ').replace('\n', ' ').replace('\r', ' ');
	}

	public String calculateRoute(double fromLat, double fromLng, double toLat, double toLng, int mode)
	{
		String apiKey = getApiKey();
		if (apiKey == null) return null;

		String modeName;
		switch (mode)
		{
			case 1: modeName = "walking"; break;
			case 2: modeName = "transit"; break;
			case 3: modeName = "bicycling"; break;
			default: modeName = "driving"; break;
		}

		String url = "https://maps.googleapis.com/maps/api/directions/json"
			+ "?origin=" + fromLat + "," + fromLng
			+ "&destination=" + toLat + "," + toLng
			+ "&mode=" + modeName
			+ "&key=" + apiKey;

		HttpURLConnection connection = null;
		try {
			connection = (HttpURLConnection) new URL(url).openConnection();
			connection.setConnectTimeout(15000);
			connection.setReadTimeout(15000);
			connection.setRequestMethod("GET");

			if (connection.getResponseCode() != 200)
				return null;

			BufferedReader reader = new BufferedReader(new InputStreamReader(connection.getInputStream(), "UTF-8"));
			StringBuilder response = new StringBuilder();
			String line;
			while ((line = reader.readLine()) != null)
				response.append(line);
			reader.close();

			JSONObject json = new JSONObject(response.toString());
			if (!"OK".equals(json.optString("status")))
				return null;

			JSONArray routes = json.optJSONArray("routes");
			if (routes == null || routes.length() == 0)
				return null;

			JSONObject route = routes.getJSONObject(0);
			JSONArray legs = route.optJSONArray("legs");
			if (legs == null || legs.length() == 0)
				return null;

			JSONObject leg = legs.getJSONObject(0);
			double distance = leg.getJSONObject("distance").optDouble("value", 0.0);
			double duration = leg.getJSONObject("duration").optDouble("value", 0.0);

			String encodedPolyline = route.getJSONObject("overview_polyline").optString("points", "");
			java.util.List<LatLng> points = decodePolyline(encodedPolyline);

			StringBuilder builder = new StringBuilder();
			builder.append(distance).append('\t')
				.append(duration).append('\t')
				.append(sanitize(route.optString("summary", ""))).append('\n');

			for (LatLng point : points)
				builder.append(point.latitude).append('\t').append(point.longitude).append('\n');

			return builder.toString();
		} catch (Exception e) {
			return null;
		} finally {
			if (connection != null)
				connection.disconnect();
		}
	}

	private String getApiKey()
	{
		try {
			android.app.Activity activity = com.fuse.Activity.getRootActivity();
			android.content.pm.ApplicationInfo info = activity.getPackageManager()
				.getApplicationInfo(activity.getPackageName(), android.content.pm.PackageManager.GET_META_DATA);

			if (info != null && info.metaData != null)
				return info.metaData.getString("com.google.android.geo.API_KEY");
		} catch (Exception e) { }

		return null;
	}

	private java.util.List<LatLng> decodePolyline(String encoded)
	{
		java.util.List<LatLng> points = new ArrayList<>();
		if (encoded == null || encoded.length() == 0)
			return points;

		int index = 0;
		int lat = 0;
		int lng = 0;
		int length = encoded.length();

		while (index < length)
		{
			int shift = 0;
			int result = 0;
			int b;

			do {
				b = encoded.charAt(index++) - 63;
				result |= (b & 0x1f) << shift;
				shift += 5;
			} while (b >= 0x20);

			lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

			shift = 0;
			result = 0;

			do {
				b = encoded.charAt(index++) - 63;
				result |= (b & 0x1f) << shift;
				shift += 5;
			} while (b >= 0x20);

			lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

			points.add(new LatLng(lat / 1E5, lng / 1E5));
		}

		return points;
	}

	/* Camera */

	public void moveCamera(double lat, double lng, float zoom, float tilt, float bearing, double duration)
	{
		if (_googleMap == null) return;
		CameraUpdate cu = genCamUpdate(lat, lng, zoom, tilt, bearing);
		performCameraMove(cu, duration);
	}

	public void showAllMarkers()
	{
		if (_googleMap == null || _mapView == null || _markerIDs == null || _markerIDs.isEmpty())
			return;

		LatLngBounds.Builder builder = new LatLngBounds.Builder();
		for (Marker marker : _markerIDs.keySet()) {
			builder.include(marker.getPosition());
		}

		LatLngBounds bounds;
		try {
			bounds = builder.build();
		} catch (IllegalStateException e) {
			return;
		}

		int width = _mapView.getMeasuredWidth();
		int height = _mapView.getMeasuredHeight();
		if (width <= 0 || height <= 0)
			return;

		int padding = (int) (height * 0.15); // offset from edges of the map in pixels
		CameraUpdate cu = CameraUpdateFactory.newLatLngBounds(bounds, width, height, padding);
		_googleMap.animateCamera(cu);
	}

	public void shapshot(final Action_String actionSucess, final Action_String actionError)
	{
		if (_googleMap == null)
		{
			if (actionError != null)
				actionError.run("Map is not ready");
			return;
		}
		SnapshotReadyCallback callback = new SnapshotReadyCallback() {
			Bitmap bitmap;

			@Override
			public void onSnapshotReady(Bitmap snapshot) {
				bitmap = snapshot;
				try {
					android.content.Context context = com.fuse.Activity.getRootActivity();
					java.io.File dir = context.getFilesDir();
					String mPath = dir.getAbsolutePath() + "/map_snapshot.png";
					FileOutputStream out = new FileOutputStream(mPath);
					bitmap.compress(Bitmap.CompressFormat.PNG, 90, out);
					actionSucess.run(mPath);
				} catch (Exception e) {
					actionError.run(e.getMessage());
					e.printStackTrace();
				}
			}
		};
		_googleMap.snapshot(callback);
	}

	public void setPosition(double lat, double lng, double duration)
	{
		if (_googleMap == null) return;
		CameraUpdate cu = genCamUpdate(lat, lng, getZoom(), getTilt(), getOrientation());
		performCameraMove(cu, duration);
	}

	private LatLng getPosition(){
		if (_googleMap == null) return new LatLng(0, 0);
		return _googleMap.getCameraPosition().target;
	}

	public double getPositionLat()
	{
		return getPosition().latitude;
	}

	public double getPositionLong()
	{
		return getPosition().longitude;
	}

	public void configureUI(boolean compass, boolean myLocationButton)
	{
		if (_googleMap == null) return;
		UiSettings settings = _googleMap.getUiSettings();
		settings.setCompassEnabled(compass);
		settings.setMyLocationButtonEnabled(myLocationButton);
	}

	public void configureGestures(boolean zoom, boolean rotate, boolean tilt, boolean scroll){
		if (_googleMap == null) return;
		UiSettings settings = _googleMap.getUiSettings();
		settings.setZoomGesturesEnabled(zoom);
		settings.setRotateGesturesEnabled(rotate);
		settings.setTiltGesturesEnabled(tilt);
		settings.setScrollGesturesEnabled(scroll);
	}

	public void zoomBy(float increment, double duration)
	{
		if (_googleMap == null) return;
		LatLng p = getPosition();
		CameraUpdate cu = genCamUpdate(p.latitude,p.longitude, getZoom()+increment, getTilt(), getOrientation());
		performCameraMove(cu, duration);
	}

	public void scrollBy(float dx, float dy, double duration)
	{
		if (_googleMap == null) return;
		CameraUpdate cu = CameraUpdateFactory.scrollBy(dx, dy);
		performCameraMove(cu, duration);
	}

	public void cancelAnimation()
	{
		if (_googleMap == null) return;
		_googleMap.stopAnimation();
	}

	public void showBounds(double minLatitude, double minLongitude, double maxLatitude, double maxLongitude)
	{
		if (_googleMap == null || _mapView == null) return;

		LatLngBounds bounds = new LatLngBounds(
			new LatLng(minLatitude, minLongitude),
			new LatLng(maxLatitude, maxLongitude));

		int width = _mapView.getMeasuredWidth();
		int height = _mapView.getMeasuredHeight();
		if (width <= 0 || height <= 0) return;

		int padding = Math.max(Math.max(_paddingLeft, _paddingTop), Math.max(_paddingRight, _paddingBottom));
		CameraUpdate cu = CameraUpdateFactory.newLatLngBounds(bounds, width, height, padding);
		_googleMap.animateCamera(cu);
	}

	public void setPaddingDp(float left, float top, float right, float bottom)
	{
		float density = getResources().getDisplayMetrics().density;
		_paddingLeft = (int)(left * density);
		_paddingTop = (int)(top * density);
		_paddingRight = (int)(right * density);
		_paddingBottom = (int)(bottom * density);

		if (_googleMap != null)
			_googleMap.setPadding(_paddingLeft, _paddingTop, _paddingRight, _paddingBottom);
	}

	public void setZoomLimits(float minZoom, float maxZoom)
	{
		if (minZoom > maxZoom) return;

		_minZoom = minZoom;
		_maxZoom = maxZoom;

		if (_googleMap == null) return;
		_googleMap.setMinZoomPreference(minZoom);
		_googleMap.setMaxZoomPreference(maxZoom);
	}

	private LatLngBounds getVisibleLatLngBounds()
	{
		if (_googleMap == null) return null;
		return _googleMap.getProjection().getVisibleRegion().latLngBounds;
	}

	public double getVisibleMinLatitude()
	{
		LatLngBounds b = getVisibleLatLngBounds();
		return b == null ? 0.0 : b.southwest.latitude;
	}

	public double getVisibleMinLongitude()
	{
		LatLngBounds b = getVisibleLatLngBounds();
		return b == null ? 0.0 : b.southwest.longitude;
	}

	public double getVisibleMaxLatitude()
	{
		LatLngBounds b = getVisibleLatLngBounds();
		return b == null ? 0.0 : b.northeast.latitude;
	}

	public double getVisibleMaxLongitude()
	{
		LatLngBounds b = getVisibleLatLngBounds();
		return b == null ? 0.0 : b.northeast.longitude;
	}

	public float getZoom()
	{
		if (_googleMap == null) return 0f;
		return _googleMap.getCameraPosition().zoom;
	}

	public float getTilt()
	{
		if (_googleMap == null) return 0f;
		return _googleMap.getCameraPosition().tilt;
	}

	public float getOrientation()
	{
		if (_googleMap == null) return 0f;
		return _googleMap.getCameraPosition().bearing;
	}

	private CameraUpdate genCamUpdate(double lat, double lng, float zoom, float tilt, float bearing)
	{
		return CameraUpdateFactory.newCameraPosition(
			CameraPosition.builder()
				.bearing(bearing)
				.tilt(tilt)
				.zoom(zoom)
				.target(new LatLng(lat, lng))
				.build()
		);
	}

	private void performCameraMove(CameraUpdate cu, double duration)
	{
		if (duration == 0.0)
		{
			_googleMap.moveCamera(cu);
			return;
		}

		_googleMap.animateCamera(cu, (int) Math.floor(duration * 1000.0));
	}

	private void onCameraIdle()
	{
		if (_callback != null)
			_callback.onCameraIdle();
	}

	/* Visuals */

	public void setNormalStyle()
	{
		if (_googleMap == null) return;
		_googleMap.setMapType(GoogleMap.MAP_TYPE_NORMAL);
	}

	public void setSatelliteStyle()
	{
		if (_googleMap == null) return;
		_googleMap.setMapType(GoogleMap.MAP_TYPE_SATELLITE);
	}

	public void setHybridStyle()
	{
		if (_googleMap == null) return;
		_googleMap.setMapType(GoogleMap.MAP_TYPE_HYBRID);
	}

	public void setTerrainStyle()
	{
		if (_googleMap == null) return;
		_googleMap.setMapType(GoogleMap.MAP_TYPE_TERRAIN);
	}

	/* LIFECYCLE */

	public void onCreate(Bundle bundle){
		if (_mapView != null && !_created)
		{
			_mapView.onCreate(bundle);
			_created = true;
		}
	}
	public void onResume(){
		if (_mapView != null && _created && !_resumed)
		{
			_mapView.onResume();
			_resumed = true;
		}
	}
	public void onPause(){
		if (_mapView != null && _resumed)
		{
			_mapView.onPause();
			_resumed = false;
		}
	}
	public void onDestroy(){
		if (_mapView != null && _created)
		{
			_mapView.onDestroy();
			_created = false;
		}
	}
}
