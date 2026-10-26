using Uno;
using Uno.UX;
using Uno.Collections;
using Uno.Threading;
using Fuse.Scripting;

namespace Fuse.Controls
{
	public partial class MapView
	{
		static MapView()
		{
			if defined(Android)
				Fuse.Maps.MapProviders.Register(new Fuse.Maps.Android.NativeMapProvider());
			else if defined(iOS)
				Fuse.Maps.MapProviders.Register(new Fuse.Maps.iOS.NativeMapProvider());

			if (Fuse.Maps.MapProviders.Default == null)
				Fuse.Maps.MapProviders.Default = "Native";

			ScriptClass.Register(typeof(MapView),
				new ScriptMethod<MapView>("setLocation", setLocation),
				new ScriptMethod<MapView>("setBearing", setBearing),
				new ScriptMethod<MapView>("setTilt", setTilt),
				new ScriptMethod<MapView>("setZoom", setZoom),
				new ScriptMethod<MapView>("showAllMarkers", showAllMarkers),
				new ScriptMethod<MapView>("setMarkers", setMarkers),
				new ScriptMethod<MapView>("setRoutes", setRoutes),
				new ScriptMethod<MapView>("selectMarker", selectMarker),
				new ScriptMethod<MapView>("deselectMarker", deselectMarker),
				new ScriptMethod<MapView>("animateTo", animateTo),
				new ScriptMethod<MapView>("cancelAnimation", cancelAnimation),
				new ScriptMethod<MapView>("zoomBy", zoomBy),
				new ScriptMethod<MapView>("scrollBy", scrollBy),
				new ScriptMethod<MapView>("showBounds", showBounds),
				new ScriptPromise<MapView, MapPlace[], Fuse.Scripting.Array>("geocode", ExecutionThread.MainThread, geocode, ConvertPlaces),
				new ScriptPromise<MapView, MapPlace[], Fuse.Scripting.Array>("reverseGeocode", ExecutionThread.MainThread, reverseGeocode, ConvertPlaces),
				new ScriptPromise<MapView, MapRouteResult, Fuse.Scripting.Object>("calculateRoute", ExecutionThread.MainThread, calculateRoute, ConvertRoute),
				new ScriptPromise<MapView, string, string>("snapshot", ExecutionThread.MainThread, snapshot, null),
				new ScriptMethod<MapView>("setOverlays", setOverlays));
		}

		/** Sets the geographical location the MapView is focused on.

			@scriptMethod setLocation(latitude, longitude)
			@param latitude (number) The latitude coordinate to pan to.
			@param longitude (number) The longitude coordinate to pan to.
		*/
		static void setLocation(MapView view, object[] args)
		{
			switch(args.Length)
			{
				case 2:
					view.Latitude = Marshal.ToDouble(args[0]);
					view.Longitude = Marshal.ToDouble(args[1]);
					return;
				default:
					Fuse.Diagnostics.UserError( "MapView.setLocation requires 2 number arguments", view );
					return;
			}
		}

		/** Sets the [Bearing](api:fuse/controls/mapview/bearing) of a MapView.

			@scriptmethod setBearing(bearing)
			@param bearing (number) The desired [Bearing](api:fuse/controls/mapview/bearing).
		*/
		static void setBearing(MapView view, object[] args)
		{
			switch(args.Length)
			{
				case 1:
					view.Bearing = Marshal.ToDouble(args[0]);
					return;
				default:
					Fuse.Diagnostics.UserError( "MapView.setBearing requires 1 number argument", view );
					return;
			}
		}

		/** Sets the [Tilt](api:fuse/controls/mapview/tilt) angle of a MapView.

			@scriptmethod setTilt(tilt)
			@param tilt (number) The desired [Tilt](api:fuse/controls/mapview/tilt) angle.
		*/
		static void setTilt(MapView view, object[] args)
		{
			switch(args.Length)
			{
				case 1:
					view.Tilt = Marshal.ToDouble(args[0]);
					return;
				default:
					Fuse.Diagnostics.UserError( "MapView.setTilt requires 1 number argument", view );
					return;
			}
		}

		/** Sets the [Zoom](api:fuse/controls/mapview/zoom) level of a MapView.

			@scriptmethod setZoom(zoom)
			@param zoom (number) The desired [Zoom](api:fuse/controls/mapview/zoom) level.
		*/
		static void setZoom(MapView view, object[] args)
		{
			switch(args.Length)
			{
				case 1:
					view.Zoom = Marshal.ToDouble(args[0]);
					return;
				default:
					Fuse.Diagnostics.UserError( "MapView.setZoom requires 1 number argument", view );
					return;
			}
		}

		/** Replaces the MapView's overlays.

			@scriptmethod setOverlays(overlays)
			@param overlays (Object|Array) Either a single object describing a map overlay, or an array of them.

			The following format is used for describing map overlays:
			```json
				{
					lineWidth: 2,
					strokeColor: '#348',
					fillColor: '#348',
					overlayType: 'polygon', // polyline, polygon, circle, image or tile
					startCap: 'round', // available round, butt, square
					endCap: 'round,' // available round, butt, square
					lineJoin: 'miter', // available round, bevel, miter
					zIndex: 0,
					alpha: 1, // 0 (transparent) to 1 (opaque)
					visible: true,
					coordinates: [
						{ latitude: 59.911567, longitude: 10.741030 },
						{ latitude: 60.011567, longitude: 10.941030 },
						{ latitude: 60.111567, longitude: 11.001030 },
					],
					holes: [ // polygon holes, each entry is a ring of coordinates
						[{ latitude: 59.95, longitude: 10.80 }]
					]
				}
			```

			An `image` overlay is described with `imageFile` and the `minLatitude`, `minLongitude`,
			`maxLatitude` and `maxLongitude` bounds. A `tile` overlay is described with
			`tileUrlTemplate` (supporting `{x}`, `{y}` and `{z}`), `tileMinZoom` and `tileMaxZoom`.
			## Example

			The following example places a map overlay
			```xml
				<NativeViewHost>
					<MapView ux:Name="myMapView" />
				</NativeViewHost>

				<JavaScript>
					myMapView.setOverlays([
						{
							lineWidth: 2,
							strokeColor: '#348',
							fillColor: '#348',
							overlayType: 'polygon',
							coordinates: [
								{ latitude: 59.911567, longitude: 10.741030 },
								{ latitude: 60.011567, longitude: 10.941030 },
								{ latitude: 60.111567, longitude: 11.001030 },
							]
						}
					]);
				</JavaScript>
			```
		*/
		static void setOverlays(MapView view, object[] args)
		{
			view.Overlays.Clear();
			switch(args.Length)
			{
				case 1:
					if (args[0] is IArray)
					{
						SetOverlaysWithArray(view, args[0] as IArray);
					}
					else if(args[0] is IObject)
					{
						view.AddOverlay(OverlayFromObject(view, args[0] as IObject));
					}
					break;
				default:
					foreach(object ob in args)
					{
						if(ob is IObject)
							view.AddOverlay(OverlayFromObject(view, ob as IObject));
						else{
							Fuse.Diagnostics.UserError( "MapView overlays should follow the format { lineWidth:3, strokeColor:\"blue\", fillColor:\"blue\", type:\"polyline\", coordinates:[{latitude: -6.90343, longitude: 107.346424}, {latitude: -6.94343, longitude: 107.396424}] }", view );
							break;
						}
					}
					break;
			}
			view.UpdateOverlays();
		}

		static void SetOverlaysWithArray(MapView view, IArray a)
		{
			for(int i = 0; i < a.Length; i++)
			{
				var item = a[i] as IObject;
				if(item!=null)
					view.AddOverlay(OverlayFromObject(view, item));
			}
		}

		static MapOverlay OverlayFromObject(MapView view, IObject o)
		{
			var m = new MapOverlay();
			foreach(string key in o.Keys)
			{
				var lowerkey = key.ToLower();
				if (lowerkey=="linewidth")
				{
					m.LineWidth = Marshal.ToInt(o[key]);
				}
				else if (lowerkey=="strokecolor")
				{
					var strokeColor = float4(1, 0, 0, 1);
					Marshal.TryToColorFloat4(o[key], out strokeColor);
					m.StrokeColor = strokeColor;
				}
				else if (lowerkey=="fillcolor")
				{
					var fillColor = float4(1, 0, 0, 1);
					Marshal.TryToColorFloat4(o[key], out fillColor);
					m.FillColor = fillColor;
				}
				else if (lowerkey=="overlaytype")
				{
					var type = o[key] as string;
					var lowertype = type.ToLower();
					if (lowertype == "polyline")
						m.Type = OverlayType.Polyline;
					else if (lowertype == "polygon")
						m.Type = OverlayType.Polygon;
					else if (lowertype == "circle")
						m.Type = OverlayType.Circle;
					else if (lowertype == "image")
						m.Type = OverlayType.Image;
					else if (lowertype == "tile")
						m.Type = OverlayType.Tile;
					else
						Fuse.Diagnostics.UserError("Invalid OverlayType. Expected value are : Polyline, Polygon, Circle, Image, Tile", view );
				}
				else if (lowerkey=="startcap")
				{
					var type = o[key] as string;
					var lowertype = type.ToLower();
					if (lowertype == "square")
						m.StartCap = LineCap.Square;
					else if (lowertype == "butt")
						m.StartCap = LineCap.Butt;
					else
						m.StartCap = LineCap.Round;
				}
				else if (lowerkey=="endcap")
				{
					var type = o[key] as string;
					var lowertype = type.ToLower();
					if (lowertype == "square")
						m.EndCap = LineCap.Square;
					else if (lowertype == "butt")
						m.EndCap = LineCap.Butt;
					else
						m.EndCap = LineCap.Round;
				}
				else if (lowerkey=="jointype")
				{
					var type = o[key] as string;
					var lowertype = type.ToLower();
					if (lowertype == "bevel")
						m.JoinType = LineJoin.Bevel;
					else if (lowertype == "miter")
						m.JoinType = LineJoin.Miter;
					else
						m.JoinType = LineJoin.Round;
				}
				else if (lowerkey=="dashpattern")
				{
					var dashPattern = o[key] as IArray;
					if (dashPattern != null)
					{
						if (dashPattern.Length > 1)
							m.DashPattern = int2(Marshal.ToInt(dashPattern[0]), Marshal.ToInt(dashPattern[1]));
					}
				}
				else if(lowerkey=="centerlatitude")
				{
					m.CenterLatitude = Marshal.ToDouble(o[key]);
				}
				else if(lowerkey=="centerlongitude")
				{
					m.CenterLongitude = Marshal.ToDouble(o[key]);
				}
				else if (lowerkey=="radius")
				{
					m.Radius = Marshal.ToDouble(o[key]);
				}
				else if (lowerkey=="zindex")
				{
					m.ZIndex = Marshal.ToInt(o[key]);
				}
				else if (lowerkey=="alpha")
				{
					m.Alpha = Marshal.ToFloat(o[key]);
				}
				else if (lowerkey=="visible")
				{
					m.Visible = Marshal.ToBool(o[key]);
				}
				else if (lowerkey=="imagefile")
				{
					m.ImageFile = Marshal.ToType<FileSource>(o[key] as string);
				}
				else if (lowerkey=="minlatitude")
				{
					m.MinLatitude = Marshal.ToDouble(o[key]);
				}
				else if (lowerkey=="minlongitude")
				{
					m.MinLongitude = Marshal.ToDouble(o[key]);
				}
				else if (lowerkey=="maxlatitude")
				{
					m.MaxLatitude = Marshal.ToDouble(o[key]);
				}
				else if (lowerkey=="maxlongitude")
				{
					m.MaxLongitude = Marshal.ToDouble(o[key]);
				}
				else if (lowerkey=="tileurltemplate")
				{
					m.TileUrlTemplate = o[key] as string;
				}
				else if (lowerkey=="tileminzoom")
				{
					m.TileMinZoom = Marshal.ToInt(o[key]);
				}
				else if (lowerkey=="tilemaxzoom")
				{
					m.TileMaxZoom = Marshal.ToInt(o[key]);
				}
				else if (lowerkey=="holes")
				{
					var holes = o[key] as IArray;
					if (holes != null)
					{
						for (int h = 0; h < holes.Length; h++)
						{
							var ring = holes[h] as IArray;
							if (ring == null) continue;

							var hole = new MapOverlayHole();
							for (int i = 0; i < ring.Length; i++)
							{
								var coordinate = ring[i] as IObject;
								if (coordinate == null) continue;

								var coord = new Coordinate();
								foreach (string coordKey in coordinate.Keys)
								{
									var lowerCoordKey = coordKey.ToLower();
									if (lowerCoordKey == "latitude")
										coord.Latitude = Marshal.ToDouble(coordinate[coordKey]);
									else if (lowerCoordKey == "longitude")
										coord.Longitude = Marshal.ToDouble(coordinate[coordKey]);
								}
								hole.Coordinates.Add(coord);
							}

							m.Holes.Add(hole);
						}
					}
				}
				else if (lowerkey=="coordinates")
				{
					var coordinates = o[key] as IArray;
					if (coordinates != null)
					{
						for(int i = 0; i < coordinates.Length; i++)
						{
							var coordinate = coordinates[i] as IObject;
							if (coordinate != null)
							{
								var coord = new Coordinate();
								foreach(string coordKey in coordinate.Keys)
								{
									var lowerCoordKey = coordKey.ToLower();
									if (lowerCoordKey=="latitude")
									{
										coord.Latitude = Marshal.ToDouble(coordinate[coordKey]);
									}
									else if (lowerCoordKey=="longitude")
									{
										coord.Longitude = Marshal.ToDouble(coordinate[coordKey]);
									}
								}
								m.Coordinates.Add(coord);
							}
						}
					}
				}

			}
			return m;
		}

		/** Replaces the MapView's markers.

			@scriptmethod setMarkers(markers)
			@param markers (Object|Array) Either a single object describing a map marker, or an array of them.

			The following format is used for describing map markers:
			```json
				{
					latitude: 0,
					longitude: 0,
					label: "Hello, world!",
					snippet: "Optional callout text",
					iconFile: "Assets/marker.png",
					iconAnchorX: 0.5,
					iconAnchorY: 1.0,
					color: "#ff3300", // tint of the default marker, ignored when iconFile is set
					draggable: true
				}
			```
			## Example

			The following example places a map marker at Fuse's home in Oslo, Norway.
			```xml
				<NativeViewHost>
					<MapView ux:Name="myMapView" />
				</NativeViewHost>

				<JavaScript>
					myMapView.setMarkers([
						{ latitude: 59.911567, longitude: 10.741030, label: "Fuse HQ" }
					]);
				</JavaScript>
			```
		*/
		static void setMarkers(MapView view, object[] args)
		{
			view.Markers.Clear();
			switch(args.Length)
			{
				case 1:
					if (args[0] is IArray)
					{
						SetMarkersWithArray(view, args[0] as IArray);
					}
					else if(args[0] is IObject)
					{
						view.AddMarker(MarkerFromObject(args[0] as IObject));
					}
					break;
				default:
					foreach(object ob in args)
					{
						if(ob is IObject)
							view.AddMarker(MarkerFromObject(ob as IObject));
						else{
							Fuse.Diagnostics.UserError( "MapView markers should follow the format { latitude:0.0, longitude:0.0, label:\"MyLabel\" }", view );
							break;
						}
					}
					break;
			}
			view.UpdateMarkers();

		}

		static void SetMarkersWithArray(MapView view, IArray a)
		{
			for(int i = 0; i < a.Length; i++)
			{
				var item = a[i] as IObject;
				if(item!=null)
					view.AddMarker(MarkerFromObject(item));
			}
		}

		static MapMarker MarkerFromObject(IObject o)
		{
			var m = new MapMarker();
			foreach(string key in o.Keys)
			{
				var lowerkey = key.ToLower();
				if(lowerkey=="latitude")
				{
					m.Latitude = Marshal.ToDouble(o[key]);
				}
				else if(lowerkey=="longitude")
				{
					m.Longitude = Marshal.ToDouble(o[key]);
				}
				else if(lowerkey=="label")
				{
					m.Label = o[key] as string;
				}
				else if(lowerkey=="iconfile")
				{
					m.IconFile = Marshal.ToType<FileSource>(o[key] as string);
				}
				else if(lowerkey=="iconanchorx")
				{
					m.IconAnchorX = Marshal.ToFloat(o[key]);
				}
				else if (lowerkey=="iconanchory")
				{
					m.IconAnchorY = Marshal.ToFloat(o[key]);
				}
				else if (lowerkey=="snippet")
				{
					m.Snippet = o[key] as string;
				}
				else if (lowerkey=="color")
				{
					var color = float4(0, 0, 0, 0);
					Marshal.TryToColorFloat4(o[key], out color);
					m.Color = color;
				}
				else if (lowerkey=="draggable")
				{
					m.Draggable = Marshal.ToBool(o[key]);
				}
			}
			return m;
		}

		/** Selects a marker by its id, showing its callout.

			@scriptMethod selectMarker(id)
			@param id (number) The id of the marker to select, as reported in marker event arguments.
		*/
		static void selectMarker(MapView view, object[] args)
		{
			if (args.Length != 1)
			{
				Fuse.Diagnostics.UserError("MapView.selectMarker requires 1 number argument", view);
				return;
			}

			view.SelectMarker(view.FindMarker(Marshal.ToInt(args[0])));
		}

		/** Deselects a marker by its id, hiding its callout.

			@scriptMethod deselectMarker(id)
			@param id (number) The id of the marker to deselect.
		*/
		static void deselectMarker(MapView view, object[] args)
		{
			if (args.Length != 1)
			{
				Fuse.Diagnostics.UserError("MapView.deselectMarker requires 1 number argument", view);
				return;
			}

			view.DeselectMarker(view.FindMarker(Marshal.ToInt(args[0])));
		}

		/** Animates the camera to a new position.

			@scriptMethod animateTo(latitude, longitude, zoom, tilt, bearing, duration)
			@param latitude (number) The latitude coordinate to animate to.
			@param longitude (number) The longitude coordinate to animate to.
			@param zoom (number) Optional zoom level. Defaults to the current zoom level.
			@param tilt (number) Optional tilt angle. Defaults to the current tilt.
			@param bearing (number) Optional bearing. Defaults to the current bearing.
			@param duration (number) Optional duration in seconds. Defaults to `0.3`.
		*/
		static void animateTo(MapView view, object[] args)
		{
			if (args.Length < 2 || args.Length > 6)
			{
				Fuse.Diagnostics.UserError("MapView.animateTo requires 2 to 6 number arguments", view);
				return;
			}

			var latitude = Marshal.ToDouble(args[0]);
			var longitude = Marshal.ToDouble(args[1]);
			var zoom = args.Length > 2 ? Marshal.ToDouble(args[2]) : view.Zoom;
			var tilt = args.Length > 3 ? Marshal.ToDouble(args[3]) : view.Tilt;
			var bearing = args.Length > 4 ? Marshal.ToDouble(args[4]) : view.Bearing;
			var duration = args.Length > 5 ? Marshal.ToDouble(args[5]) : 0.3;

			view.AnimateTo(latitude, longitude, zoom, tilt, bearing, duration);
		}

		/** Cancels an ongoing camera animation.

			@scriptMethod cancelAnimation()
		*/
		static void cancelAnimation(MapView view, object[] args)
		{
			view.CancelAnimation();
		}

		/** Changes the zoom level by the given amount.

			@scriptMethod zoomBy(delta)
			@param delta (number) The amount to change the zoom level by. Positive values zoom in.
		*/
		static void zoomBy(MapView view, object[] args)
		{
			if (args.Length != 1)
			{
				Fuse.Diagnostics.UserError("MapView.zoomBy requires 1 number argument", view);
				return;
			}

			view.ZoomBy(Marshal.ToDouble(args[0]));
		}

		/** Pans the map by the given number of points.

			@scriptMethod scrollBy(dx, dy)
			@param dx (number) Horizontal offset in points.
			@param dy (number) Vertical offset in points.
		*/
		static void scrollBy(MapView view, object[] args)
		{
			if (args.Length != 2)
			{
				Fuse.Diagnostics.UserError("MapView.scrollBy requires 2 number arguments", view);
				return;
			}

			view.ScrollBy(Marshal.ToFloat(args[0]), Marshal.ToFloat(args[1]));
		}

		/** Moves the camera so the given area fits in the view.

			@scriptMethod showBounds(minLatitude, minLongitude, maxLatitude, maxLongitude)
			@param minLatitude (number) Latitude of the south-west corner.
			@param minLongitude (number) Longitude of the south-west corner.
			@param maxLatitude (number) Latitude of the north-east corner.
			@param maxLongitude (number) Longitude of the north-east corner.
		*/
		static void showBounds(MapView view, object[] args)
		{
			if (args.Length != 4)
			{
				Fuse.Diagnostics.UserError("MapView.showBounds requires 4 number arguments", view);
				return;
			}

			view.ShowBounds(
				Marshal.ToDouble(args[0]),
				Marshal.ToDouble(args[1]),
				Marshal.ToDouble(args[2]),
				Marshal.ToDouble(args[3])
			);
		}

		/** Looks up an address and returns the matching places.

			@scriptMethod geocode(query)
			@param query (string) The address to look up.
		*/
		static Future<MapPlace[]> geocode(Context context, MapView view, object[] args)
		{
			if (args.Length != 1 || !(args[0] is string))
				return MapView.RejectedFuture<MapPlace[]>("MapView.geocode requires 1 string argument");

			return view.Geocode((string)args[0]);
		}

		/** Returns the places at or near the given coordinates.

			@scriptMethod reverseGeocode(latitude, longitude)
		*/
		static Future<MapPlace[]> reverseGeocode(Context context, MapView view, object[] args)
		{
			if (args.Length != 2)
				return MapView.RejectedFuture<MapPlace[]>("MapView.reverseGeocode requires 2 number arguments");

			return view.ReverseGeocode(Marshal.ToDouble(args[0]), Marshal.ToDouble(args[1]));
		}

		/** Calculates a route between two points.

			@scriptMethod calculateRoute(fromLatitude, fromLongitude, toLatitude, toLongitude, mode)
			@param mode (string) Optional. One of `driving`, `walking`, `transit` or `cycling`. Defaults to `driving`.

			The promise resolves with an object containing `polyline` (an array of `{ latitude, longitude }`),
			`distance` (meters), `duration` (seconds) and `name`.
		*/
		static Future<MapRouteResult> calculateRoute(Context context, MapView view, object[] args)
		{
			if (args.Length < 4 || args.Length > 5)
				return MapView.RejectedFuture<MapRouteResult>("MapView.calculateRoute requires 4 or 5 arguments");

			var mode = RouteMode.Driving;
			if (args.Length == 5)
			{
				var modeString = args[4] as string;
				if (modeString != null)
					mode = ParseRouteMode(modeString);
			}

			return view.CalculateRoute(
				Marshal.ToDouble(args[0]),
				Marshal.ToDouble(args[1]),
				Marshal.ToDouble(args[2]),
				Marshal.ToDouble(args[3]),
				mode
			);
		}

		static Fuse.Scripting.Array ConvertPlaces(Context context, MapPlace[] places)
		{
			var items = new object[places.Length];
			for (int i = 0; i < places.Length; i++)
			{
				var obj = context.NewObject();
				obj["name"] = places[i].Name;
				obj["address"] = places[i].Address;
				obj["latitude"] = places[i].Latitude;
				obj["longitude"] = places[i].Longitude;
				items[i] = obj;
			}

			return context.NewArray(items);
		}

		static Fuse.Scripting.Object ConvertRoute(Context context, MapRouteResult route)
		{
			var obj = context.NewObject();
			obj["distance"] = route.Distance;
			obj["duration"] = route.Duration;
			obj["name"] = route.Name;

			var points = new object[route.Polyline.Length];
			for (int i = 0; i < route.Polyline.Length; i++)
			{
				var point = context.NewObject();
				point["latitude"] = route.Polyline[i].Latitude;
				point["longitude"] = route.Polyline[i].Longitude;
				points[i] = point;
			}
			obj["polyline"] = context.NewArray(points);

			return obj;
		}

		static RouteMode ParseRouteMode(string value)
		{
			if (value == null) return RouteMode.Driving;

			var lower = value.ToLower();
			if (lower == "walking") return RouteMode.Walking;
			if (lower == "transit") return RouteMode.Transit;
			if (lower == "cycling") return RouteMode.Cycling;
			return RouteMode.Driving;
		}

		/** Replaces the MapView's routes.

			@scriptmethod setRoutes(routes)
			@param routes (Object|Array) Either a single object describing a route, or an array of them.

			Each route requests and draws a route between two points. The following format is used:
			```json
				{
					fromLatitude: 59.9115573,
					fromLongitude: 10.73888,
					toLatitude: 59.9500,
					toLongitude: 10.7800,
					mode: "driving", // driving, walking, transit or cycling
					strokeColor: "#2196F3",
					lineWidth: 6,
					zIndex: 0,
					alpha: 1,
					visible: true
				}
			```

			## Example

			```xml
				<NativeViewHost>
					<MapView ux:Name="myMapView" />
				</NativeViewHost>

				<JavaScript>
					myMapView.setRoutes([
						{
							fromLatitude: 59.9115573,
							fromLongitude: 10.73888,
							toLatitude: 59.9500,
							toLongitude: 10.7800,
							strokeColor: "#2196F3",
							lineWidth: 6
						}
					]);
				</JavaScript>
			```
		*/
		static void setRoutes(MapView view, object[] args)
		{
			view.Routes.Clear();

			switch(args.Length)
			{
				case 1:
					if (args[0] is IArray)
					{
						var array = args[0] as IArray;
						for (int i = 0; i < array.Length; i++)
						{
							var item = array[i] as IObject;
							if (item != null)
								view.AddRoute(RouteFromObject(item));
						}
					}
					else if (args[0] is IObject)
					{
						view.AddRoute(RouteFromObject(args[0] as IObject));
					}
					break;
				default:
					foreach(object ob in args)
					{
						if (ob is IObject)
							view.AddRoute(RouteFromObject(ob as IObject));
						else
						{
							Fuse.Diagnostics.UserError("MapView routes should follow the format { fromLatitude: 59.9, fromLongitude: 10.7, toLatitude: 59.95, toLongitude: 10.78, mode: \"driving\", strokeColor: \"#2196F3\", lineWidth: 6 }", view);
							break;
						}
					}
					break;
			}

			view.UpdateRoutes();
		}

		static MapRoute RouteFromObject(IObject o)
		{
			var route = new MapRoute();

			foreach(string key in o.Keys)
			{
				var lowerkey = key.ToLower();

				if (lowerkey == "fromlatitude")
					route.FromLatitude = Marshal.ToDouble(o[key]);
				else if (lowerkey == "fromlongitude")
					route.FromLongitude = Marshal.ToDouble(o[key]);
				else if (lowerkey == "tolatitude")
					route.ToLatitude = Marshal.ToDouble(o[key]);
				else if (lowerkey == "tolongitude")
					route.ToLongitude = Marshal.ToDouble(o[key]);
				else if (lowerkey == "mode")
					route.Mode = ParseRouteMode(o[key] as string);
				else if (lowerkey == "strokecolor")
				{
					var color = float4(0.13f, 0.59f, 0.95f, 1);
					Marshal.TryToColorFloat4(o[key], out color);
					route.StrokeColor = color;
				}
				else if (lowerkey == "linewidth")
					route.LineWidth = Marshal.ToInt(o[key]);
				else if (lowerkey == "zindex")
					route.ZIndex = Marshal.ToInt(o[key]);
				else if (lowerkey == "alpha")
					route.Alpha = Marshal.ToFloat(o[key]);
				else if (lowerkey == "visible")
					route.Visible = Marshal.ToBool(o[key]);
			}

			return route;
		}

		/** Zoom to make all of markers in the MapView is shown.

			@scriptMethod showAllMarkers()
		*/
		static void showAllMarkers(MapView view, object[] args)
		{
			view.ShowAllMarkers();
		}

		/** Take a snapshot of MapView.

			@scriptMethod snapshot()
			use this method to take a picture of the MapView, returning a promise with the path argument of where the picture is stored

			Examples:
			```xml
				<NativeViewHost>
					<MapView ux:Name="MapView" />
				</NativeViewHost>
				<JavaScript>
					MapView.snapshot()
						.then(function(path) {
							console.log(path);
						})
						.catch(function(err) { });
				</JavaScript>
			```
		*/
		static Future<string> snapshot(Context context, MapView self, object[] args)
		{
			var p = new Promise<string>();
			var pc = new PromiseCallback(p);
			self.Snapshot(pc.Resolve, pc.Reject);
			return p;
		}

		class PromiseCallback
		{
			Promise<string> _p;
			public PromiseCallback(Promise<string> p)
			{
				_p = p;
			}

			public void Resolve(string path)
			{
				_p.Resolve(path);
			}

			public void Reject(string reason)
			{
				_p.Reject(new Exception(reason));
			}
		}
	}
}
