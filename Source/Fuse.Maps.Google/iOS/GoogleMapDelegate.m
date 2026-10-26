#import "GoogleMapDelegate.h"

static NSString* Sanitize(NSString* value)
{
	if (value == nil)
		return @"";

	value = [value stringByReplacingOccurrencesOfString:@"\t" withString:@" "];
	value = [value stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
	value = [value stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
	return value;
}

static UIColor* ColorWithOpacity(UIColor* color, float opacity)
{
	CGFloat red, green, blue, alpha;
	if (![color getRed:&red green:&green blue:&blue alpha:&alpha])
		return color;

	return [UIColor colorWithRed:red green:green blue:blue alpha:alpha * opacity];
}

@implementation GoogleMapDelegate
{
	GMSMapView* _mapView;
	NSMutableDictionary<NSNumber*, GMSMarker*>* _markers;
	NSMutableDictionary<NSNumber*, GMSOverlay*>* _overlays;
	NSMutableDictionary<NSNumber*, GMSPolyline*>* _routes;
	CLLocationManager* _locationManager;
	void (^_authBlock)(bool);
	BOOL _ready;
	BOOL _readyDelivered;

	void (^_onReady)(void);
	void (^_onCameraIdle)(void);
	void (^_onMarkerTap)(int, NSString*);
	void (^_onMarkerSelect)(int);
	void (^_onMarkerDeselect)(int);
	void (^_onMarkerDragStart)(int);
	void (^_onMarkerDrag)(int, double, double);
	void (^_onMarkerDragEnd)(int, double, double);
	void (^_onOverlayTap)(int);
	void (^_onMapTap)(double, double);
	void (^_onMapLongPress)(double, double);
}

-(id)init
{
	self = [super init];
	if (self == nil)
		return nil;

	_markers = [[NSMutableDictionary alloc] init];
	_overlays = [[NSMutableDictionary alloc] init];
	_routes = [[NSMutableDictionary alloc] init];
	_ready = NO;
	_readyDelivered = NO;
	return self;
}

-(void)dealloc
{
	[self cleanup];
}

-(void)setAsDelegate:(GMSMapView*)mapView
{
	_mapView = mapView;
	_mapView.delegate = self;
	_ready = NO;
	_readyDelivered = NO;

	// The SDK does not always report that the first frame is ready, so use a
	// short timer as a fallback.
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self notifyReady];
	});
}

-(void)setActions:(void(^)(void))onReady
	onCameraIdle:(void(^)(void))onCameraIdle
	onMarkerTap:(void(^)(int, NSString*))onMarkerTap
	onMarkerSelect:(void(^)(int))onMarkerSelect
	onMarkerDeselect:(void(^)(int))onMarkerDeselect
	onMarkerDragStart:(void(^)(int))onMarkerDragStart
	onMarkerDrag:(void(^)(int, double, double))onMarkerDrag
	onMarkerDragEnd:(void(^)(int, double, double))onMarkerDragEnd
	onOverlayTap:(void(^)(int))onOverlayTap
	onMapTap:(void(^)(double, double))onMapTap
	onMapLongPress:(void(^)(double, double))onMapLongPress
{
	_onReady = onReady;
	_onCameraIdle = onCameraIdle;
	_onMarkerTap = onMarkerTap;
	_onMarkerSelect = onMarkerSelect;
	_onMarkerDeselect = onMarkerDeselect;
	_onMarkerDragStart = onMarkerDragStart;
	_onMarkerDrag = onMarkerDrag;
	_onMarkerDragEnd = onMarkerDragEnd;
	_onOverlayTap = onOverlayTap;
	_onMapTap = onMapTap;
	_onMapLongPress = onMapLongPress;

	[self deliverReady];
}

-(void)notifyReady
{
	if (_mapView == nil)
		return;

	_ready = YES;
	[self deliverReady];
}

	-(void)deliverReady
	{
		if (!_ready || _readyDelivered || _onReady == nil)
			return;

		_readyDelivered = YES;
		_onReady();
	}

-(void)cleanup
{
	[self clearMarkers];
	[self clearOverlays];
	[self clearRoutes];

	_mapView.delegate = nil;
	_mapView = nil;

	if (_locationManager != nil)
	{
		_locationManager.delegate = nil;
		_locationManager = nil;
	}

	_authBlock = nil;
	_ready = NO;
	_readyDelivered = NO;
	_onReady = nil;
	_onCameraIdle = nil;
	_onMarkerTap = nil;
	_onMarkerSelect = nil;
	_onMarkerDeselect = nil;
	_onMarkerDragStart = nil;
	_onMarkerDrag = nil;
	_onMarkerDragEnd = nil;
	_onOverlayTap = nil;
	_onMapTap = nil;
	_onMapLongPress = nil;
}

/* Location */

-(BOOL)authorized
{
	CLAuthorizationStatus status;
	if (@available(iOS 14.0, *))
	{
		if (_locationManager == nil)
		{
			_locationManager = [[CLLocationManager alloc] init];
			_locationManager.delegate = self;
		}
		status = _locationManager.authorizationStatus;
	}
	else
		status = [CLLocationManager authorizationStatus];

	return status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusAuthorizedAlways;
}

-(void)notifyAuthorizationChanged
{
	void (^callback)(bool) = _authBlock;
	_authBlock = nil;
	if (callback != nil)
		callback([self authorized]);
}

-(void)locationManagerDidChangeAuthorization:(CLLocationManager*)manager
{
	[self notifyAuthorizationChanged];
}

-(void)locationManager:(CLLocationManager*)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
	if (@available(iOS 14.0, *))
		return;

	[self notifyAuthorizationChanged];
}

-(void)requestLocationAuth:(void(^)(bool))callback
{
	if ([self authorized])
	{
		if (callback != nil)
			callback(YES);
		return;
	}

	_authBlock = callback;

	if (_locationManager == nil)
	{
		_locationManager = [[CLLocationManager alloc] init];
		_locationManager.delegate = self;
	}

	[_locationManager requestWhenInUseAuthorization];
}

/* Markers */

-(void)applyMarker:(GMSMarker*)marker
	label:(NSString*)label
	snippet:(NSString*)snippet
	icon:(NSString*)iconPath
	anchorX:(float)anchorX
	anchorY:(float)anchorY
	color:(UIColor*)color
	draggable:(bool)draggable
{
	marker.title = label;
	marker.snippet = snippet;
	marker.draggable = draggable;
	marker.tappable = YES;
	marker.zIndex = 1;

	if (iconPath != nil)
	{
		UIImage* image = [UIImage imageWithContentsOfFile:iconPath];
		if (image != nil)
		{
			marker.icon = image;
			marker.groundAnchor = CGPointMake(anchorX, anchorY);
			return;
		}
	}

	if (color != nil)
		marker.icon = [GMSMarker markerImageWithColor:color];
	else
		marker.icon = nil;

	marker.groundAnchor = CGPointMake(0.5, 1.0);
}

-(void)addMarker:(int)uid
	latitude:(double)latitude
	longitude:(double)longitude
	label:(NSString*)label
	snippet:(NSString*)snippet
	icon:(NSString*)iconPath
	anchorX:(float)anchorX
	anchorY:(float)anchorY
	color:(UIColor*)color
	draggable:(bool)draggable
{
	if (_mapView == nil)
		return;

	GMSMarker* marker = [GMSMarker markerWithPosition:CLLocationCoordinate2DMake(latitude, longitude)];
	marker.userData = @(uid);
	[self applyMarker:marker label:label snippet:snippet icon:iconPath anchorX:anchorX anchorY:anchorY color:color draggable:draggable];
	marker.map = _mapView;
	[_markers setObject:marker forKey:@(uid)];
}

-(void)updateMarker:(int)uid
	latitude:(double)latitude
	longitude:(double)longitude
	label:(NSString*)label
	snippet:(NSString*)snippet
	icon:(NSString*)iconPath
	anchorX:(float)anchorX
	anchorY:(float)anchorY
	color:(UIColor*)color
	draggable:(bool)draggable
{
	GMSMarker* marker = [_markers objectForKey:@(uid)];
	if (marker == nil)
		return;

	marker.position = CLLocationCoordinate2DMake(latitude, longitude);
	[self applyMarker:marker label:label snippet:snippet icon:iconPath anchorX:anchorX anchorY:anchorY color:color draggable:draggable];
}

-(void)removeMarker:(int)uid
{
	GMSMarker* marker = [_markers objectForKey:@(uid)];
	if (marker == nil)
		return;

	marker.map = nil;
	[_markers removeObjectForKey:@(uid)];
}

-(void)clearMarkers
{
	for (GMSMarker* marker in _markers.allValues)
		marker.map = nil;

	[_markers removeAllObjects];
}

-(void)selectMarker:(int)uid
{
	GMSMarker* marker = [_markers objectForKey:@(uid)];
	if (marker != nil)
		_mapView.selectedMarker = marker;
}

-(void)deselectMarker:(int)uid
{
	GMSMarker* marker = [_markers objectForKey:@(uid)];
	if (marker != nil && _mapView.selectedMarker == marker)
		_mapView.selectedMarker = nil;
}

/* Overlays */

-(GMSMutablePath*)pathFromCoordinates:(NSArray<NSNumber*>*)coordinates
{
	GMSMutablePath* path = [GMSMutablePath path];
	for (NSUInteger i = 0; i + 1 < coordinates.count; i += 2)
	{
		double latitude = [[coordinates objectAtIndex:i] doubleValue];
		double longitude = [[coordinates objectAtIndex:i + 1] doubleValue];
		[path addCoordinate:CLLocationCoordinate2DMake(latitude, longitude)];
	}
	return path;
}

-(void)addPolyline:(int)uid
	coordinates:(NSArray<NSNumber*>*)coordinates
	strokeColor:(UIColor*)strokeColor
	lineWidth:(int)lineWidth
	geodesic:(bool)geodesic
	zIndex:(int)zIndex
	alpha:(float)alpha
{
	if (_mapView == nil)
		return;

	if (coordinates == nil || coordinates.count < 4)
		return;

	GMSPolyline* polyline = [GMSPolyline polylineWithPath:[self pathFromCoordinates:coordinates]];
	polyline.strokeColor = ColorWithOpacity(strokeColor, alpha);
	polyline.strokeWidth = lineWidth;
	polyline.geodesic = geodesic;
	polyline.zIndex = zIndex;
	polyline.tappable = YES;
	polyline.userData = @(uid);
	polyline.map = _mapView;
	[_overlays setObject:polyline forKey:@(uid)];
}

-(void)addPolygon:(int)uid
	coordinates:(NSArray<NSNumber*>*)coordinates
	holes:(NSArray<NSNumber*>*)holeCoordinates
	holeLengths:(NSArray<NSNumber*>*)holeLengths
	strokeColor:(UIColor*)strokeColor
	fillColor:(UIColor*)fillColor
	lineWidth:(int)lineWidth
	geodesic:(bool)geodesic
	zIndex:(int)zIndex
	alpha:(float)alpha
{
	if (_mapView == nil)
		return;

	if (coordinates == nil || coordinates.count < 6)
		return;

	GMSPolygon* polygon = [GMSPolygon polygonWithPath:[self pathFromCoordinates:coordinates]];

	NSMutableArray<GMSPath*>* holePaths = [NSMutableArray array];
	NSUInteger offset = 0;

	for (NSUInteger h = 0; h < holeLengths.count; h++)
	{
		NSUInteger count = [[holeLengths objectAtIndex:h] unsignedIntegerValue];
		if (count < 3)
		{
			offset += count * 2;
			continue;
		}

		GMSMutablePath* hole = [GMSMutablePath path];
		for (NSUInteger i = 0; i < count; i++)
		{
			double latitude = [[holeCoordinates objectAtIndex:offset] doubleValue];
			double longitude = [[holeCoordinates objectAtIndex:offset + 1] doubleValue];
			[hole addCoordinate:CLLocationCoordinate2DMake(latitude, longitude)];
			offset += 2;
		}

		[holePaths addObject:hole];
	}

	if (holePaths.count > 0)
		polygon.holes = holePaths;

	polygon.strokeColor = ColorWithOpacity(strokeColor, alpha);
	polygon.fillColor = ColorWithOpacity(fillColor, alpha);
	polygon.strokeWidth = lineWidth;
	polygon.geodesic = geodesic;
	polygon.zIndex = zIndex;
	polygon.tappable = YES;
	polygon.userData = @(uid);
	polygon.map = _mapView;
	[_overlays setObject:polygon forKey:@(uid)];
}

-(void)addCircle:(int)uid
	latitude:(double)latitude
	longitude:(double)longitude
	radius:(double)radius
	strokeColor:(UIColor*)strokeColor
	fillColor:(UIColor*)fillColor
	lineWidth:(int)lineWidth
	zIndex:(int)zIndex
	alpha:(float)alpha
{
	if (_mapView == nil)
		return;

	GMSCircle* circle = [GMSCircle circleWithPosition:CLLocationCoordinate2DMake(latitude, longitude) radius:radius];
	circle.strokeColor = ColorWithOpacity(strokeColor, alpha);
	circle.fillColor = ColorWithOpacity(fillColor, alpha);
	circle.strokeWidth = lineWidth;
	circle.zIndex = zIndex;
	circle.tappable = YES;
	circle.userData = @(uid);
	circle.map = _mapView;
	[_overlays setObject:circle forKey:@(uid)];
}

-(void)addGroundOverlay:(int)uid
	image:(NSString*)imagePath
	minLatitude:(double)minLatitude
	minLongitude:(double)minLongitude
	maxLatitude:(double)maxLatitude
	maxLongitude:(double)maxLongitude
	opacity:(float)opacity
	zIndex:(int)zIndex
{
	if (_mapView == nil || imagePath == nil)
		return;

	UIImage* image = [UIImage imageWithContentsOfFile:imagePath];
	if (image == nil)
		return;

	GMSCoordinateBounds* bounds = [[GMSCoordinateBounds alloc]
		initWithCoordinate:CLLocationCoordinate2DMake(minLatitude, minLongitude)
		coordinate:CLLocationCoordinate2DMake(maxLatitude, maxLongitude)];

	GMSGroundOverlay* overlay = [GMSGroundOverlay groundOverlayWithBounds:bounds icon:image];
	overlay.opacity = opacity;
	overlay.zIndex = zIndex;
	overlay.tappable = YES;
	overlay.userData = @(uid);
	overlay.map = _mapView;
	[_overlays setObject:overlay forKey:@(uid)];
}

-(void)addTileLayer:(int)uid
	urlTemplate:(NSString*)urlTemplate
	minZoom:(int)minZoom
	maxZoom:(int)maxZoom
	opacity:(float)opacity
	zIndex:(int)zIndex
{
	if (_mapView == nil || urlTemplate == nil)
		return;

	GMSURLTileLayer* layer = [GMSURLTileLayer tileLayerWithURLConstructor:^NSURL*(NSUInteger x, NSUInteger y, NSUInteger zoom) {
		NSString* url = urlTemplate;
		url = [url stringByReplacingOccurrencesOfString:@"{x}" withString:[NSString stringWithFormat:@"%lu", (unsigned long)x]];
		url = [url stringByReplacingOccurrencesOfString:@"{y}" withString:[NSString stringWithFormat:@"%lu", (unsigned long)y]];
		url = [url stringByReplacingOccurrencesOfString:@"{z}" withString:[NSString stringWithFormat:@"%lu", (unsigned long)zoom]];
		return [NSURL URLWithString:url];
	}];

	layer.minimumZ = (NSUInteger)minZoom;
	layer.maximumZ = (NSUInteger)maxZoom;
	layer.opacity = opacity;
	layer.zIndex = zIndex;
	layer.tappable = NO;
	layer.userData = @(uid);
	layer.map = _mapView;
	[_overlays setObject:layer forKey:@(uid)];
}

-(void)clearOverlays
{
	for (GMSOverlay* overlay in _overlays.allValues)
		overlay.map = nil;

	[_overlays removeAllObjects];
}

/* Routes */

-(void)addRoutePolyline:(int)uid
	coordinates:(NSArray<NSNumber*>*)coordinates
	strokeColor:(UIColor*)strokeColor
	lineWidth:(int)lineWidth
	alpha:(float)alpha
	zIndex:(int)zIndex
{
	if (_mapView == nil)
		return;

	if (coordinates == nil || coordinates.count < 4)
		return;

	GMSPolyline* polyline = [GMSPolyline polylineWithPath:[self pathFromCoordinates:coordinates]];
	polyline.strokeColor = ColorWithOpacity(strokeColor, alpha);
	polyline.strokeWidth = lineWidth;
	polyline.zIndex = zIndex;
	polyline.tappable = NO;
	polyline.userData = @(uid);
	polyline.map = _mapView;
	[_routes setObject:polyline forKey:@(uid)];
}

-(void)clearRoutes
{
	for (GMSPolyline* polyline in _routes.allValues)
		polyline.map = nil;

	[_routes removeAllObjects];
}

/* Remote services */

-(void)requestJSON:(NSString*)urlString
	success:(void(^)(NSDictionary*))success
	error:(void(^)(NSString*))error
{
	NSURL* url = [NSURL URLWithString:urlString];
	if (url == nil)
	{
		error(@"Invalid URL");
		return;
	}

	[[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData* data, NSURLResponse* response, NSError* requestError) {
		if (requestError != nil)
		{
			NSString* message = requestError.localizedDescription;
			dispatch_async(dispatch_get_main_queue(), ^{ error(message); });
			return;
		}

		NSError* jsonError = nil;
		NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
		if (json == nil)
		{
			dispatch_async(dispatch_get_main_queue(), ^{ error(@"Invalid response from Google"); });
			return;
		}

		NSString* status = json[@"status"];
		if (status != nil && ![status isEqualToString:@"OK"] && ![status isEqualToString:@"ZERO_RESULTS"])
		{
			NSString* message = [NSString stringWithFormat:@"Google API error: %@", status];
			dispatch_async(dispatch_get_main_queue(), ^{ error(message); });
			return;
		}

		dispatch_async(dispatch_get_main_queue(), ^{ success(json); });
	}] resume];
}

-(NSString*)placeNameFromResult:(NSDictionary*)result
{
	NSArray* components = result[@"address_components"];
	for (NSDictionary* component in components)
	{
		NSArray* types = component[@"types"];
		if ([types containsObject:@"locality"] ||
			[types containsObject:@"administrative_area_level_1"] ||
			[types containsObject:@"point_of_interest"])
			return component[@"long_name"];
	}

	return result[@"formatted_address"];
}

-(void)geocode:(NSString*)query
	apiKey:(NSString*)apiKey
	success:(void(^)(NSString*))success
	error:(void(^)(NSString*))error
{
	if (apiKey.length == 0)
	{
		error(@"A Google Maps API key is required");
		return;
	}

	NSString* encoded = [query stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
	NSString* url = [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/geocode/json?address=%@&key=%@", encoded, apiKey];

	[self requestJSON:url success:^(NSDictionary* json) {
		NSMutableString* result = [NSMutableString string];
		for (NSDictionary* place in json[@"results"])
		{
			NSDictionary* location = place[@"geometry"][@"location"];
			[result appendFormat:@"%@\t%@\t%f\t%f\n",
				Sanitize([self placeNameFromResult:place]),
				Sanitize(place[@"formatted_address"]),
				[location[@"lat"] doubleValue],
				[location[@"lng"] doubleValue]];
		}
		success(result);
	} error:error];
}

-(void)reverseGeocode:(double)latitude
	longitude:(double)longitude
	apiKey:(NSString*)apiKey
	success:(void(^)(NSString*))success
	error:(void(^)(NSString*))error
{
	if (apiKey.length == 0)
	{
		error(@"A Google Maps API key is required");
		return;
	}

	NSString* url = [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/geocode/json?latlng=%f,%f&key=%@", latitude, longitude, apiKey];

	[self requestJSON:url success:^(NSDictionary* json) {
		NSMutableString* result = [NSMutableString string];
		for (NSDictionary* place in json[@"results"])
		{
			NSDictionary* location = place[@"geometry"][@"location"];
			[result appendFormat:@"%@\t%@\t%f\t%f\n",
				Sanitize([self placeNameFromResult:place]),
				Sanitize(place[@"formatted_address"]),
				[location[@"lat"] doubleValue],
				[location[@"lng"] doubleValue]];
		}
		success(result);
	} error:error];
}

-(NSArray<NSValue*>*)decodePolyline:(NSString*)encoded
{
	NSMutableArray<NSValue*>* points = [NSMutableArray array];
	if (encoded == nil)
		return points;

	NSUInteger index = 0;
	NSUInteger length = encoded.length;
	NSInteger latitude = 0;
	NSInteger longitude = 0;

	while (index < length)
	{
		NSInteger b;
		NSInteger shift = 0;
		NSInteger result = 0;

		do {
			b = (NSInteger)[encoded characterAtIndex:index++] - 63;
			result |= (b & 0x1f) << shift;
			shift += 5;
		} while (b >= 0x20);

		latitude += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

		shift = 0;
		result = 0;

		do {
			b = (NSInteger)[encoded characterAtIndex:index++] - 63;
			result |= (b & 0x1f) << shift;
			shift += 5;
		} while (b >= 0x20);

		longitude += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

		CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(latitude / 1e5, longitude / 1e5);
		[points addObject:[NSValue valueWithBytes:&coordinate objCType:@encode(CLLocationCoordinate2D)]];
	}

	return points;
}

-(void)calculateRouteFrom:(double)fromLatitude
	fromLongitude:(double)fromLongitude
	toLatitude:(double)toLatitude
	toLongitude:(double)toLongitude
	mode:(int)mode
	apiKey:(NSString*)apiKey
	success:(void(^)(NSString*))success
	error:(void(^)(NSString*))error
{
	if (apiKey.length == 0)
	{
		error(@"A Google Maps API key is required");
		return;
	}

	NSString* travelMode = @"driving";
	switch (mode)
	{
		case 1: travelMode = @"walking"; break;
		case 2: travelMode = @"transit"; break;
		case 3: travelMode = @"bicycling"; break;
		default: travelMode = @"driving"; break;
	}

	NSString* url = [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/directions/json?origin=%f,%f&destination=%f,%f&mode=%@&key=%@",
		fromLatitude, fromLongitude, toLatitude, toLongitude, travelMode, apiKey];

	[self requestJSON:url success:^(NSDictionary* json) {
		NSArray* routes = json[@"routes"];
		if (routes.count == 0)
		{
			error(@"No route was found");
			return;
		}

		NSDictionary* route = routes[0];
		NSArray* legs = route[@"legs"];
		if (legs.count == 0)
		{
			error(@"No route was found");
			return;
		}

		NSDictionary* leg = legs[0];
		double distance = [leg[@"distance"][@"value"] doubleValue];
		double duration = [leg[@"duration"][@"value"] doubleValue];
		NSString* summary = route[@"summary"] != nil ? route[@"summary"] : @"";
		NSArray<NSValue*>* coordinates = [self decodePolyline:route[@"overview_polyline"][@"points"]];

		NSMutableString* result = [NSMutableString stringWithFormat:@"%f\t%f\t%@\n", distance, duration, Sanitize(summary)];
		for (NSValue* value in coordinates)
		{
			CLLocationCoordinate2D coordinate;
			[value getValue:&coordinate];
			[result appendFormat:@"%f\t%f\n", coordinate.latitude, coordinate.longitude];
		}

		success(result);
	} error:error];
}

-(void)takeSnapshot:(void(^)(NSString*))success error:(void(^)(NSString*))error
{
	if (_mapView == nil || _mapView.bounds.size.width <= 0 || _mapView.bounds.size.height <= 0)
	{
		error(@"The map is not ready");
		return;
	}

	UIGraphicsImageRenderer* renderer = [[UIGraphicsImageRenderer alloc] initWithSize:_mapView.bounds.size];
	UIImage* image = [renderer imageWithActions:^(UIGraphicsImageRendererContext* context) {
		[_mapView drawViewHierarchyInRect:_mapView.bounds afterScreenUpdates:YES];
	}];

	NSData* data = UIImagePNGRepresentation(image);
	NSString* path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"map_snapshot.png"];

	if (data == nil || ![data writeToFile:path atomically:YES])
	{
		error(@"Could not write the snapshot");
		return;
	}

	success(path);
}

/* GMSMapViewDelegate */

-(void)mapViewDidFinishLoadingMap:(GMSMapView*)mapView
{
	[self notifyReady];
}

-(void)mapView:(GMSMapView*)mapView idleAtCameraPosition:(GMSCameraPosition*)position
{
	if (_onCameraIdle != nil)
		_onCameraIdle();
}

-(void)mapView:(GMSMapView*)mapView didTapAtCoordinate:(CLLocationCoordinate2D)coordinate
{
	if (_onMapTap != nil)
		_onMapTap(coordinate.latitude, coordinate.longitude);
}

-(void)mapView:(GMSMapView*)mapView didLongPressAtCoordinate:(CLLocationCoordinate2D)coordinate
{
	if (_onMapLongPress != nil)
		_onMapLongPress(coordinate.latitude, coordinate.longitude);
}

-(BOOL)mapView:(GMSMapView*)mapView didTapMarker:(GMSMarker*)marker
{
	int uid = [marker.userData intValue];

	if (_onMarkerTap != nil)
		_onMarkerTap(uid, marker.title);
	if (_onMarkerSelect != nil)
		_onMarkerSelect(uid);

	return NO;
}

-(void)mapView:(GMSMapView*)mapView didCloseInfoWindowOfMarker:(GMSMarker*)marker
{
	if (_onMarkerDeselect != nil)
		_onMarkerDeselect([marker.userData intValue]);
}

-(void)mapView:(GMSMapView*)mapView didBeginDraggingMarker:(GMSMarker*)marker
{
	if (_onMarkerDragStart != nil)
		_onMarkerDragStart([marker.userData intValue]);
}

-(void)mapView:(GMSMapView*)mapView didDragMarker:(GMSMarker*)marker
{
	if (_onMarkerDrag != nil)
		_onMarkerDrag([marker.userData intValue], marker.position.latitude, marker.position.longitude);
}

-(void)mapView:(GMSMapView*)mapView didEndDraggingMarker:(GMSMarker*)marker
{
	if (_onMarkerDragEnd != nil)
		_onMarkerDragEnd([marker.userData intValue], marker.position.latitude, marker.position.longitude);
}

-(void)mapView:(GMSMapView*)mapView didTapOverlay:(GMSOverlay*)overlay
{
	if (_onOverlayTap != nil)
		_onOverlayTap([overlay.userData intValue]);
}

@end
