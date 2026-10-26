using Uno;
using Fuse.Controls;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Maps.Android
{
	[ForeignInclude(Language.Java, "com.fuse.maps.FuseMap")]
	extern (Android) static class ForeignHelpers
	{
		[Foreign(Language.Java)]
		internal static Java.Object CreateMap()
		@{
			return new FuseMap();
		@}

		[Foreign(Language.Java)]
		internal static void MoveCamera(Java.Object handle, double lat, double lng, float zoom, float tilt, float bearing, double duration)
		@{
			FuseMap map = (FuseMap)handle;
			map.moveCamera(lat,lng,zoom,tilt,bearing,duration);
		@}

		[Foreign(Language.Java)]
		internal static void ShowAllMarkers(Java.Object handle)
		@{
			FuseMap map = (FuseMap)handle;
			map.showAllMarkers();
		@}

		[Foreign(Language.Java)]
		internal static void CancelAnimation(Java.Object handle)
		@{
			FuseMap map = (FuseMap)handle;
			map.cancelAnimation();
		@}

		[Foreign(Language.Java)]
		internal static void ShowBounds(Java.Object handle, double minLatitude, double minLongitude, double maxLatitude, double maxLongitude)
		@{
			FuseMap map = (FuseMap)handle;
			map.showBounds(minLatitude, minLongitude, maxLatitude, maxLongitude);
		@}

		[Foreign(Language.Java)]
		internal static void SetPadding(Java.Object handle, float left, float top, float right, float bottom)
		@{
			FuseMap map = (FuseMap)handle;
			map.setPaddingDp(left, top, right, bottom);
		@}

		[Foreign(Language.Java)]
		internal static void SetZoomLimits(Java.Object handle, float minZoom, float maxZoom)
		@{
			FuseMap map = (FuseMap)handle;
			map.setZoomLimits(minZoom, maxZoom);
		@}

		[Foreign(Language.Java)]
		internal static void ZoomBy(Java.Object handle, float delta, double duration)
		@{
			FuseMap map = (FuseMap)handle;
			map.zoomBy(delta, duration);
		@}

		[Foreign(Language.Java)]
		internal static void ScrollBy(Java.Object handle, float dx, float dy, double duration)
		@{
			FuseMap map = (FuseMap)handle;
			map.scrollBy(dx, dy, duration);
		@}

		[Foreign(Language.Java)]
		internal static double GetVisibleMinLatitude(Java.Object handle)
		@{
			FuseMap map = (FuseMap)handle;
			return map.getVisibleMinLatitude();
		@}

		[Foreign(Language.Java)]
		internal static double GetVisibleMinLongitude(Java.Object handle)
		@{
			FuseMap map = (FuseMap)handle;
			return map.getVisibleMinLongitude();
		@}

		[Foreign(Language.Java)]
		internal static double GetVisibleMaxLatitude(Java.Object handle)
		@{
			FuseMap map = (FuseMap)handle;
			return map.getVisibleMaxLatitude();
		@}

		[Foreign(Language.Java)]
		internal static double GetVisibleMaxLongitude(Java.Object handle)
		@{
			FuseMap map = (FuseMap)handle;
			return map.getVisibleMaxLongitude();
		@}

		[Foreign(Language.Java)]
		internal static void Geocode(Java.Object handle, string query, Action<string> onSuccess, Action<string> onError)
		@{
			final FuseMap map = (FuseMap)handle;
			final android.app.Activity activity = com.fuse.Activity.getRootActivity();

			new java.lang.Thread(new Runnable() {
				@Override public void run() {
					final String result = map.geocode(query, 5);
					activity.runOnUiThread(new Runnable() {
						@Override public void run() {
							if (result != null) onSuccess.run(result);
							else onError.run("Geocoding failed");
						}
					});
				}
			}).start();
		@}

		[Foreign(Language.Java)]
		internal static void ReverseGeocode(Java.Object handle, double latitude, double longitude, Action<string> onSuccess, Action<string> onError)
		@{
			final FuseMap map = (FuseMap)handle;
			final android.app.Activity activity = com.fuse.Activity.getRootActivity();

			new java.lang.Thread(new Runnable() {
				@Override public void run() {
					final String result = map.reverseGeocode(latitude, longitude, 5);
					activity.runOnUiThread(new Runnable() {
						@Override public void run() {
							if (result != null) onSuccess.run(result);
							else onError.run("Reverse geocoding failed");
						}
					});
				}
			}).start();
		@}

		[Foreign(Language.Java)]
		internal static void CalculateRoute(Java.Object handle, double fromLatitude, double fromLongitude, double toLatitude, double toLongitude, int mode, Action<string> onSuccess, Action<string> onError)
		@{
			final FuseMap map = (FuseMap)handle;
			final android.app.Activity activity = com.fuse.Activity.getRootActivity();

			new java.lang.Thread(new Runnable() {
				@Override public void run() {
					final String result = map.calculateRoute(fromLatitude, fromLongitude, toLatitude, toLongitude, mode);
					activity.runOnUiThread(new Runnable() {
						@Override public void run() {
							if (result != null) onSuccess.run(result);
							else onError.run("Could not calculate the route");
						}
					});
				}
			}).start();
		@}

		[Foreign(Language.Java)]
		internal static void ClearRoutes(Java.Object handle)
		@{
			FuseMap map = (FuseMap)handle;
			map.clearRoutes();
		@}

		[Foreign(Language.Java)]
		internal static void AddRoutePolyline(Java.Object handle, int uid, double[] coordinates, int color, int lineWidth, float alpha, int zIndex)
		@{
			FuseMap map = (FuseMap)handle;
			map.addRoutePolyline(uid, coordinates.copyArray(), color, lineWidth, alpha, zIndex);
		@}

		[Foreign(Language.Java)]
		internal static void StartRouteCalculation(Java.Object handle, double fromLatitude, double fromLongitude, double toLatitude, double toLongitude, int mode, Action<string> onSuccess, Action<string> onError)
		@{
			final FuseMap map = (FuseMap)handle;
			final android.app.Activity activity = com.fuse.Activity.getRootActivity();

			new java.lang.Thread(new Runnable() {
				@Override public void run() {
					final String result = map.calculateRoute(fromLatitude, fromLongitude, toLatitude, toLongitude, mode);
					activity.runOnUiThread(new Runnable() {
						@Override public void run() {
							if (result != null) onSuccess.run(result);
							else onError.run("Could not calculate the route");
						}
					});
				}
			}).start();
		@}

		[Foreign(Language.Java)]
		internal static void TakeSnapshot(Java.Object handle, Action<string> actionSucces, Action<string> actionError)
		@{
			FuseMap map = (FuseMap)handle;
			map.shapshot(actionSucces, actionError);
		@}

		[Foreign(Language.Java)]
		internal static void SetPosition(Java.Object handle, double lat, double lng, double duration)
		@{
			FuseMap map = (FuseMap)handle;
			map.setPosition(lat,lng,duration);
		@}

		[Foreign(Language.Java)]
		internal static double GetPositionLat(Java.Object handle)
		@{
			FuseMap map = (FuseMap)handle;
			return map.getPositionLat();
		@}

		[Foreign(Language.Java)]
		internal static double GetPositionLong(Java.Object handle)
		@{
			FuseMap map = (FuseMap)handle;
			return map.getPositionLong();
		@}

		[Foreign(Language.Java)]
		internal static void ConfigureUI(Java.Object handle, bool compass, bool myLocationButton)
		@{
			FuseMap map = (FuseMap)handle;
			map.configureUI(compass, myLocationButton);
		@}

		[Foreign(Language.Java)]
		internal static void ConfigureGestures(Java.Object handle, bool zoom, bool rotate, bool tilt, bool scroll)
		@{
			FuseMap map = (FuseMap)handle;
			map.configureGestures(zoom,rotate,tilt, scroll);
		@}

		[Foreign(Language.Java)]
		internal static float GetTilt(Java.Object handle)
		@{
			FuseMap map = (FuseMap)handle;
			return map.getTilt();
		@}

		[Foreign(Language.Java)]
		internal static double GetOrientation(Java.Object handle)
		@{
			FuseMap map = (FuseMap)handle;
			return map.getOrientation();
		@}

		[Foreign(Language.Java)]
		internal static void SetSatelliteStyle(Java.Object handle)
		@{
			FuseMap map = (FuseMap)handle;
			map.setSatelliteStyle();
		@}

		[Foreign(Language.Java)]
		internal static void SetHybridStyle(Java.Object handle)
		@{
			FuseMap map = (FuseMap)handle;
			map.setHybridStyle();
		@}

		[Foreign(Language.Java)]
		internal static void SetTerrainStyle(Java.Object handle)
		@{
			FuseMap map = (FuseMap)handle;
			map.setTerrainStyle();
		@}

		[Foreign(Language.Java)]
		internal static void SetNormalStyle(Java.Object handle)
		@{
			FuseMap map = (FuseMap)handle;
			map.setNormalStyle();
		@}

		[Foreign(Language.Java)]
		internal static float GetZoom(Java.Object handle)
		@{
			FuseMap map = (FuseMap)handle;
			return map.getZoom();
		@}

		[Foreign(Language.Java)]
		internal static string AddMarker(Java.Object handle, double lat, double lng, String label, String snippet, String iconPath, float iconAnchorX, float iconAnchorY, int color, bool draggable, int uid)
		@{
			FuseMap map = (FuseMap)handle;
			return map.addMarker(lat, lng, label, snippet, iconPath, iconAnchorX, iconAnchorY, color, draggable, uid);
		@}

		[Foreign(Language.Java)]
		internal static void UpdateMarker(Java.Object handle, int uid, double lat, double lng, String label, String snippet, String iconPath, float iconAnchorX, float iconAnchorY, int color, bool draggable)
		@{
			FuseMap map = (FuseMap)handle;
			map.updateMarker(uid, lat, lng, label, snippet, iconPath, iconAnchorX, iconAnchorY, color, draggable);
		@}

		[Foreign(Language.Java)]
		internal static void RemoveMarker(Java.Object handle, int uid)
		@{
			FuseMap map = (FuseMap)handle;
			map.removeMarker(uid);
		@}

		[Foreign(Language.Java)]
		internal static void SelectMarker(Java.Object handle, int uid)
		@{
			FuseMap map = (FuseMap)handle;
			map.selectMarker(uid);
		@}

		[Foreign(Language.Java)]
		internal static void DeselectMarker(Java.Object handle, int uid)
		@{
			FuseMap map = (FuseMap)handle;
			map.deselectMarker(uid);
		@}

		[Foreign(Language.Java)]
		internal static void AddOverlay(Java.Object handle, OverlayType type, double[] coordinates, double[] holeCoordinates, int[] holeLengths, int strokeColor, int fillColor, int lineWidth, bool geodesic, LineCap startCap, LineCap endCap, LineJoin joinType, int[] dashPattern, double centerLatitude, double centerLongitude, double radius, int zIndex, float alpha, int uid)
		@{
			FuseMap map = (FuseMap)handle;
			map.AddOverlay(type, coordinates.copyArray(), holeCoordinates.copyArray(), holeLengths.copyArray(), strokeColor, fillColor, lineWidth, geodesic, startCap, endCap, joinType, dashPattern.copyArray(), centerLatitude, centerLongitude, radius, zIndex, alpha, uid);
		@}

		[Foreign(Language.Java)]
		internal static void AddImageOverlay(Java.Object handle, String imagePath, double minLatitude, double minLongitude, double maxLatitude, double maxLongitude, float opacity, int zIndex, int uid)
		@{
			FuseMap map = (FuseMap)handle;
			map.addImageOverlay(imagePath, minLatitude, minLongitude, maxLatitude, maxLongitude, opacity, zIndex, uid);
		@}

		[Foreign(Language.Java)]
		internal static void AddTileOverlay(Java.Object handle, String urlTemplate, int minZoom, int maxZoom, float opacity, int zIndex, int uid)
		@{
			FuseMap map = (FuseMap)handle;
			map.addTileOverlay(urlTemplate, minZoom, maxZoom, opacity, zIndex, uid);
		@}

		[Foreign(Language.Java)]
		internal static void ClearOverlays(Java.Object handle)
		@{
			FuseMap map = (FuseMap)handle;
			map.clearOverlays();
		@}

		[Foreign(Language.Java)]
		internal static void SetMyLocationEnabled(Java.Object handle, bool b)
		@{
			FuseMap map = (FuseMap)handle;
			map.setMyLocationEnabled(b);
		@}

		[Foreign(Language.Java)]
		internal static void Destroy(Java.Object handle)
		@{
			FuseMap map = (FuseMap)handle;
			map.dispose();
		@}

		[Foreign(Language.Java)]
		internal static void Configure(Java.Object handle)
		@{
			FuseMap map = (FuseMap)handle;
			map.onCreate(null);
			map.onResume();
		@}

		[Foreign(Language.Java)]
		internal static void Resume(Java.Object handle)
		@{
			FuseMap map = (FuseMap)handle;
			map.onResume();
		@}

		[Foreign(Language.Java)]
		internal static void Pause(Java.Object handle)
		@{
			FuseMap map = (FuseMap)handle;
			map.onPause();
		@}

		[Foreign(Language.Java)]
		internal static void SetMapEventHandlers(
			Java.Object handle,
			Action onMapReady,
			Action<double, double> handleLocationLongPress,
			Action<double, double> handleLocationTapped,
			Action onCameraIdle,
			Action<int, string> handleMarkerPressed,
			Action<int> handleOverlayPressed,
			Action<int> handleMarkerSelected,
			Action<int> handleMarkerDeselected,
			Action<int> handleMarkerDragStart,
			Action<int, double, double> handleMarkerDragging,
			Action<int, double, double> handleMarkerDragEnd
		)
		@{
			final FuseMap map = (FuseMap)handle;
			map.SetCallback(new FuseMap.FuseMapCallback() {
				@Override
				public void onReady() {
					onMapReady.run();
				}
				@Override
				public void onLongPress(double lat, double lng) {
					handleLocationLongPress.run(lat, lng);
				}
				@Override
				public void onPress(double lat, double lng) {
					handleLocationTapped.run(lat,lng);
				}
				@Override
				public void onCameraIdle() {
					onCameraIdle.run();
				}
				@Override
				public boolean onMarkerPress(com.google.android.gms.maps.model.Marker m) {
					handleMarkerPressed.run(map.getIdforMarker(m), m.getTitle());
					return false;
				}
				@Override
				public void onPolygonPress(com.google.android.gms.maps.model.Polygon m) {
					handleOverlayPressed.run(map.getIdforPolygon(m));
				}
				@Override
				public void onPolylinePress(com.google.android.gms.maps.model.Polyline m) {
					handleOverlayPressed.run(map.getIdforPolyline(m));
				}
				@Override
				public void onCirclePress(com.google.android.gms.maps.model.Circle m) {
					handleOverlayPressed.run(map.getIdforCircle(m));
				}
				@Override
				public void onMarkerSelected(int uid) {
					handleMarkerSelected.run(uid);
				}
				@Override
				public void onMarkerDeselected(int uid) {
					handleMarkerDeselected.run(uid);
				}
				@Override
				public void onMarkerDragStart(int uid) {
					handleMarkerDragStart.run(uid);
				}
				@Override
				public void onMarkerDrag(int uid, double lat, double lng) {
					handleMarkerDragging.run(uid, lat, lng);
				}
				@Override
				public void onMarkerDragEnd(int uid, double lat, double lng) {
					handleMarkerDragEnd.run(uid, lat, lng);
				}
			});
		@}
	}
}
