#import "MapViewDelegate.h"
#define MERCATOR_OFFSET 268435456
#define MERCATOR_RADIUS 85445659.44705395

static double DistanceSquaredFromPointToSegment(CGPoint p, CGPoint a, CGPoint b)
{
	double dx = b.x - a.x;
	double dy = b.y - a.y;
	double lengthSq = dx * dx + dy * dy;

	double t = 0.0;
	if (lengthSq > 0.0)
		t = MAX(0.0, MIN(1.0, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSq));

	double projX = a.x + t * dx;
	double projY = a.y + t * dy;
	double ddx = p.x - projX;
	double ddy = p.y - projY;

	return ddx * ddx + ddy * ddy;
}

@interface MapViewDelegate ()
-(BOOL)isPoint:(CGPoint)point nearPolyline:(MKPolyline*)polyline renderer:(MKOverlayPathRenderer*)renderer;
-(void)applyRegion:(MKCoordinateRegion)region center:(CLLocationCoordinate2D)center pitch:(double)pitch heading:(double)heading;
-(MKCoordinateRegion)visibleCoordinateRegion;
@end

@interface FusePinAnnotation : MKPointAnnotation
	@property(copy) NSString* icon;
	@property float iconX;
	@property float iconY;
	@property bool draggable;
	@property(retain) UIColor* markerColor;
	@property int markerID;
@end

@implementation FusePinAnnotation
@end

@interface FuseOverlay : NSObject
	@property(retain) id<MKOverlay> overlay;
	@property(retain) MKOverlayRenderer* renderer;
	@property int overlayID;
@end

@implementation FuseOverlay
@end

@interface FuseGroundOverlay : NSObject <MKOverlay>
	@property(nonatomic) MKMapRect boundingMapRect;
	@property(nonatomic) CLLocationCoordinate2D coordinate;
	@property(retain) UIImage* image;
	@property(nonatomic) double opacity;
@end

@implementation FuseGroundOverlay
@end

@interface FuseGroundOverlayRenderer : MKOverlayRenderer
@end

@implementation FuseGroundOverlayRenderer
	- (void)drawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale inContext:(CGContextRef)context
	{
		FuseGroundOverlay* groundOverlay = (FuseGroundOverlay*)self.overlay;
		if (groundOverlay.image == nil)
			return;

		CGRect rect = [self rectForMapRect:groundOverlay.boundingMapRect];

		CGContextSaveGState(context);
		CGContextSetAlpha(context, groundOverlay.opacity);
		CGContextTranslateCTM(context, 0, rect.origin.y * 2 + rect.size.height);
		CGContextScaleCTM(context, 1.0, -1.0);
		CGContextDrawImage(context, rect, groundOverlay.image.CGImage);
		CGContextRestoreGState(context);
	}
	@end

@implementation MapViewDelegate
{
	MKMapView* _mapView;
	NSMutableDictionary* _annotations;
	NSMutableDictionary* _overlays;
	NSMutableDictionary* _routes;
	CLLocationManager* _locationMgr;
	MKUserTrackingButton* _trackingButton;
	UITapGestureRecognizer* _tapRecognizer;
	UILongPressGestureRecognizer* _longPressRecognizer;
	NSTimeInterval _suppressMapMoveUntil;
	NSTimeInterval _suppressSelectionUntil;
	float _padLeft;
	float _padTop;
	float _padRight;
	float _padBottom;
	double _minZoom;
	double _maxZoom;
}

	@synthesize mapMoveBlock;
	@synthesize markerSelectBlock;
	@synthesize markerSelectedBlock;
	@synthesize markerDeselectBlock;
	@synthesize markerDragStartBlock;
	@synthesize markerDragBlock;
	@synthesize markerDragEndBlock;
	@synthesize overlaySelectBlock;
	@synthesize touchBlock;
	@synthesize authChangeBlock;

	static int _idOverlayPool = 0;

	-(id)init
	{
		self = [super init];
		_minZoom = 0.0;
		_maxZoom = 21.0;
		_locationMgr = [[CLLocationManager alloc] init];
		[_locationMgr setDelegate:self];
		_annotations = [[NSMutableDictionary alloc] init];
		_overlays = [[NSMutableDictionary alloc] init];
		_routes = [[NSMutableDictionary alloc] init];
		return self;
	}

	-(BOOL)authorized
	{
		CLAuthorizationStatus status;
		if (@available(iOS 14.0, *))
			status = _locationMgr.authorizationStatus;
		else
			status = [CLLocationManager authorizationStatus];

		switch(status){
			case kCLAuthorizationStatusAuthorizedWhenInUse:
			case kCLAuthorizationStatusAuthorizedAlways:
				return true;
			default:
				return false;
		}
	}

	-(void)locationManagerDidChangeAuthorization:(CLLocationManager*)manager
	{
		[self notifyAuthorizationChanged];
	}

	-(void)locationManager:(CLLocationManager*)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
	{
		if (@available(iOS 14.0, *))
			return; // handled by locationManagerDidChangeAuthorization
		[self notifyAuthorizationChanged];
	}

	-(void)notifyAuthorizationChanged
	{
		void(^callback)(bool) = authChangeBlock;
		authChangeBlock = nil;
		if (callback!=nil)
			callback([self authorized]);
	}

	-(void)requestLocationAuthentication:(void(^)(bool))onRequestResult
	{
		if ([self authorized]){
			if (onRequestResult!=nil)
				onRequestResult(true);
		}else{
			authChangeBlock = onRequestResult;
			[_locationMgr requestWhenInUseAuthorization];
		}
	}

	-(void)setAsDelegate:(MKMapView*)mv
	{
		if (_mapView != nil && _mapView != mv)
		{
			if (_tapRecognizer != nil) [_mapView removeGestureRecognizer:_tapRecognizer];
			if (_longPressRecognizer != nil) [_mapView removeGestureRecognizer:_longPressRecognizer];
		}
		_tapRecognizer = nil;
		_longPressRecognizer = nil;

		_mapView = mv;
		[_mapView setDelegate:self];

		_tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
		_longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPress:)];

		[mv addGestureRecognizer:_tapRecognizer];
		[mv addGestureRecognizer:_longPressRecognizer];
	}

	-(void)cleanup
	{
		if (_mapView != nil)
		{
			if (_tapRecognizer != nil) [_mapView removeGestureRecognizer:_tapRecognizer];
			if (_longPressRecognizer != nil) [_mapView removeGestureRecognizer:_longPressRecognizer];
		}
		_tapRecognizer = nil;
		_longPressRecognizer = nil;

		if (_trackingButton != nil)
		{
			[_trackingButton removeFromSuperview];
			_trackingButton = nil;
		}

		if (_locationMgr != nil)
		{
			_locationMgr.delegate = nil;
			_locationMgr = nil;
		}

		authChangeBlock = nil;
		_mapView = nil;
	}

	-(void)setShowsMyLocationButton:(BOOL)show
	{
		if (show && _trackingButton == nil)
		{
			UIView* container = _mapView.superview;
			if (container == nil) return;

			_trackingButton = [MKUserTrackingButton userTrackingButtonWithMapView:_mapView];
			_trackingButton.translatesAutoresizingMaskIntoConstraints = NO;
			[container addSubview:_trackingButton];

			[NSLayoutConstraint activateConstraints:@[
				[_trackingButton.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-16.0],
				[_trackingButton.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-16.0]
			]];
		}

		_trackingButton.hidden = !show;
	}

	-(int)nextOverlayId
	{
		return _idOverlayPool++;
	}

	-(void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view
	{
		if ([NSDate timeIntervalSinceReferenceDate] < _suppressSelectionUntil)
			return;

		id annotation = view.annotation;
		if (![annotation isKindOfClass:[MKUserLocation class]]) {
			if (markerSelectBlock){
				FusePinAnnotation* a = (FusePinAnnotation*)[view annotation];
				markerSelectBlock(a.markerID, a.title);
			}
			if (markerSelectedBlock && [annotation isKindOfClass:[FusePinAnnotation class]]){
				FusePinAnnotation* a = (FusePinAnnotation*)annotation;
				markerSelectedBlock(a.markerID);
			}
		}
	}

	-(void)mapView:(MKMapView *)mapView didDeselectAnnotationView:(MKAnnotationView *)view
	{
		if ([NSDate timeIntervalSinceReferenceDate] < _suppressSelectionUntil)
			return;

		id annotation = view.annotation;
		if (![annotation isKindOfClass:[MKUserLocation class]]) {
			if (markerDeselectBlock && [annotation isKindOfClass:[FusePinAnnotation class]]){
				FusePinAnnotation* a = (FusePinAnnotation*)annotation;
				markerDeselectBlock(a.markerID);
			}
		}
	}

	-(int)addMarker:(NSString*)label
		latitude:(double)lat
		longitude:(double)lng
		snippet:(NSString*)snippet
		icon:(NSString*)iconPath
		iconX:(float)iconX
		iconY:(float)iconY
		color:(UIColor*)color
		draggable:(bool)draggable
		markerID:(int)markerID
	{
		FusePinAnnotation* a = [[FusePinAnnotation alloc] init];
		a.coordinate = CLLocationCoordinate2DMake(lat,lng);
		a.title = label;
		a.subtitle = snippet;
		a.icon = iconPath;
		a.iconX = iconX;
		a.iconY = iconY;
		a.draggable = draggable;
		a.markerColor = color;
		a.markerID = markerID;
		[_mapView addAnnotation:a];
		[_annotations setObject:a forKey:\@(markerID)];
		return markerID;
	}

	-(void)updateMarker:(NSString*)label
		latitude:(double)lat
		longitude:(double)lng
		snippet:(NSString*)snippet
		icon:(NSString*)iconPath
		iconX:(float)iconX
		iconY:(float)iconY
		color:(UIColor*)color
		draggable:(bool)draggable
		markerID:(int)markerID
	{
		FusePinAnnotation* a = [_annotations objectForKey:@(markerID)];
		if (a == nil)
			return;

		a.coordinate = CLLocationCoordinate2DMake(lat, lng);
		a.title = label;
		a.subtitle = snippet;
		a.icon = iconPath;
		a.iconX = iconX;
		a.iconY = iconY;
		a.draggable = draggable;
		a.markerColor = color;
	}

	-(void)removeMarker:(int)identifier
	{
		FusePinAnnotation* a = [_annotations objectForKey:@(identifier)];
		if (a==nil) return;
		[_mapView removeAnnotation:a];
		[_annotations removeObjectForKey:@(identifier)];
	}

	-(void)selectMarker:(int)markerID
	{
		if (_mapView == nil) return;
		FusePinAnnotation* a = [_annotations objectForKey:@(markerID)];
		if (a != nil)
		{
			_suppressSelectionUntil = [NSDate timeIntervalSinceReferenceDate] + 0.2;
			[_mapView selectAnnotation:a animated:YES];
		}
	}

	-(void)deselectMarker:(int)markerID
	{
		if (_mapView == nil) return;
		FusePinAnnotation* a = [_annotations objectForKey:@(markerID)];
		if (a != nil)
		{
			_suppressSelectionUntil = [NSDate timeIntervalSinceReferenceDate] + 0.2;
			[_mapView deselectAnnotation:a animated:YES];
		}
	}

	- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view didChangeDragState:(MKAnnotationViewDragState)newState fromOldState:(MKAnnotationViewDragState)oldState
	{
		if (![view.annotation isKindOfClass:[FusePinAnnotation class]])
			return;

		FusePinAnnotation* a = (FusePinAnnotation*)view.annotation;

		switch (newState)
		{
			case MKAnnotationViewDragStateStarting:
				if (markerDragStartBlock)
					markerDragStartBlock(a.markerID);
				break;
			case MKAnnotationViewDragStateDragging:
			{
				CLLocationCoordinate2D coord = [mapView convertPoint:view.center toCoordinateFromView:mapView];
				if (markerDragBlock)
					markerDragBlock(a.markerID, coord.latitude, coord.longitude);
				break;
			}
			case MKAnnotationViewDragStateEnding:
			{
				CLLocationCoordinate2D coord = [mapView convertPoint:view.center toCoordinateFromView:mapView];
				a.coordinate = coord;
				if (markerDragEndBlock)
					markerDragEndBlock(a.markerID, coord.latitude, coord.longitude);
				break;
			}
			case MKAnnotationViewDragStateCanceling:
			{
				CLLocationCoordinate2D coord = a.coordinate;
				if (markerDragEndBlock)
					markerDragEndBlock(a.markerID, coord.latitude, coord.longitude);
				break;
			}
			default:
				break;
		}
	}

	-(void) clearMarkers
	{
		for(id key in _annotations)
		{
			FusePinAnnotation* a = [_annotations objectForKey:key];
			if (a==nil) continue;
			[_mapView removeAnnotation:a];
		}
		[_annotations removeAllObjects];
	}

	-(void)registerOverlay:(id<MKOverlay>)overlay renderer:(MKOverlayRenderer*)renderer overlayID:(int)overlayID
	{
		FuseOverlay *fuseOverlay = [[FuseOverlay alloc] init];
		fuseOverlay.overlay = overlay;
		fuseOverlay.renderer = renderer;
		fuseOverlay.overlayID = overlayID;
		[_overlays setObject:fuseOverlay forKey:\@(_idOverlayPool)];
		[self nextOverlayId];
	}

	-(void)_setupOverlayRenderer:(id<MKOverlay>)overlay
		renderer:(MKOverlayPathRenderer*)renderer
		strokeColor:(UIColor *) strokeColor
		fillColor:(UIColor *)fillColor
		lineWidth:(int)lineWidth
		startCap:(int)startCap
		endCap:(int)endCap
		joinType:(int)joinType
		pattern:(NSArray<NSNumber *> *)pattern
		alpha:(float)alpha
		overlayID:(int)overlayID
	{
		renderer.lineWidth = lineWidth;
		renderer.strokeColor = strokeColor;
		renderer.fillColor = fillColor;
		renderer.alpha = alpha;
		CGLineCap lineCap = kCGLineCapRound;
		switch (startCap)
		{
			case 0: lineCap = kCGLineCapRound; break;
			case 1: lineCap = kCGLineCapButt; break;
			case 2: lineCap = kCGLineCapSquare; break;
		}
		renderer.lineCap = lineCap;
		CGLineJoin lineJoin = kCGLineJoinRound;
		switch (joinType)
		{
			case 0: lineJoin = kCGLineJoinRound; break;
			case 1: lineJoin = kCGLineJoinBevel; break;
			case 2: lineJoin = kCGLineJoinMiter; break;
		}
		renderer.lineJoin = lineJoin;
		renderer.lineDashPattern = pattern;
		[self registerOverlay:overlay renderer:renderer overlayID:overlayID];
	}

	-(NSArray<MKPolygon*>*)buildPolygonHoles:(NSArray<NSNumber*>*)holeCoords lengths:(NSArray<NSNumber*>*)holeLengths
	{
		if (holeCoords == nil || holeLengths == nil || holeLengths.count == 0)
			return nil;

		NSMutableArray<MKPolygon*>* polygons = [NSMutableArray array];
		NSUInteger offset = 0;

		for (NSUInteger h = 0; h < holeLengths.count; h++)
		{
			NSUInteger count = [[holeLengths objectAtIndex:h] unsignedIntegerValue];
			if (count < 3)
			{
				offset += count * 2;
				continue;
			}

			CLLocationCoordinate2D* hole = malloc(sizeof(CLLocationCoordinate2D) * count);
			for (NSUInteger i = 0; i < count; i++)
			{
				double lat = [[holeCoords objectAtIndex:offset] doubleValue];
				double lon = [[holeCoords objectAtIndex:offset + 1] doubleValue];
				hole[i] = CLLocationCoordinate2DMake(lat, lon);
				offset += 2;
			}

			[polygons addObject:[MKPolygon polygonWithCoordinates:hole count:count]];
			free(hole);
		}

		return polygons.count > 0 ? polygons : nil;
	}

	-(void)addOverlay:(id)coords type:(int)overlayType
		holes:(NSArray<NSNumber *> *)holeCoords
		holeLengths:(NSArray<NSNumber *> *)holeLengths
		strokeColor:(UIColor *)strokeColor
		fillColor:(UIColor *)fillColor
		lineWidth:(int)lineWidth
		geodesic:(bool)geodesic
		startCap:(int)startCap
		endCap:(int)endCap
		joinType:(int)joinType
		pattern:(NSArray<NSNumber *> *)pattern
		centerLatitude:(double)centerLatitude
		centerLongitude:(double)centerLongitude
		radius:(double)radius
		alpha:(float)alpha
		overlayID:(int)overlayID
	{
		NSUInteger count = [coords count];
		NSUInteger numOfCoordinate = count / 2;
		CLLocationCoordinate2D coordinates[numOfCoordinate];
		int idx = 0;
		for (int i = 0; i < count; i+=2)
		{
			double lat = [coords[i] doubleValue];
			double lon = [coords[i+1] doubleValue];
			coordinates[idx] = CLLocationCoordinate2DMake(lat, lon);
			idx++;
		}
		id<MKOverlay> overlay;
		MKOverlayPathRenderer *renderer;
		switch (overlayType)
		{
			case 1:
			{
				NSArray<MKPolygon*>* interiorPolygons = [self buildPolygonHoles:holeCoords lengths:holeLengths];
				if (interiorPolygons != nil)
					overlay = [MKPolygon polygonWithCoordinates:coordinates count:numOfCoordinate interiorPolygons:interiorPolygons];
				else
					overlay = [MKPolygon polygonWithCoordinates:coordinates count:numOfCoordinate];
				renderer = [[MKPolygonRenderer alloc] initWithPolygon:(MKPolygon*)overlay];
				break;
			}
			case 2:
			{
				CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(centerLatitude, centerLongitude);
				overlay = [MKCircle circleWithCenterCoordinate:coordinate radius:(CLLocationDistance)radius];
				renderer = [[MKCircleRenderer alloc] initWithCircle:(MKCircle*)overlay];
				break;
			}
			default:
			{
				if (geodesic)
					overlay = [MKGeodesicPolyline polylineWithCoordinates:coordinates count:numOfCoordinate];
				else
					overlay = [MKPolyline polylineWithCoordinates:coordinates count:numOfCoordinate];
				renderer = [[MKPolylineRenderer alloc] initWithPolyline:(MKPolyline*)overlay];
				break;
			}
		}
		[self _setupOverlayRenderer:overlay
			renderer:renderer
			strokeColor:strokeColor
			fillColor:fillColor
			lineWidth:lineWidth
			startCap:startCap
			endCap:endCap
			joinType:joinType
			pattern:pattern
			alpha:alpha
			overlayID:overlayID];
		[_mapView addOverlay:overlay];
	}

	-(void)addImageOverlay:(NSString*)imagePath minLatitude:(double)minLat minLongitude:(double)minLng maxLatitude:(double)maxLat maxLongitude:(double)maxLng opacity:(float)opacity overlayID:(int)overlayID
	{
		if (_mapView == nil || imagePath == nil) return;
		if (maxLat <= minLat || maxLng <= minLng) return;

		UIImage* image = [UIImage imageWithContentsOfFile:imagePath];
		if (image == nil) return;

		MKMapPoint southWest = MKMapPointForCoordinate(CLLocationCoordinate2DMake(minLat, minLng));
		MKMapPoint northEast = MKMapPointForCoordinate(CLLocationCoordinate2DMake(maxLat, maxLng));

		double x = MIN(southWest.x, northEast.x);
		double y = MIN(southWest.y, northEast.y);
		double width = fabs(northEast.x - southWest.x);
		double height = fabs(northEast.y - southWest.y);

		if (width <= 0.0 || height <= 0.0) return;

		FuseGroundOverlay* overlay = [[FuseGroundOverlay alloc] init];
		overlay.boundingMapRect = MKMapRectMake(x, y, width, height);
		overlay.coordinate = CLLocationCoordinate2DMake((minLat + maxLat) / 2.0, (minLng + maxLng) / 2.0);
		overlay.image = image;
		overlay.opacity = MAX(0.0, MIN((double)opacity, 1.0));

		FuseGroundOverlayRenderer* renderer = [[FuseGroundOverlayRenderer alloc] initWithOverlay:overlay];
		[self registerOverlay:overlay renderer:renderer overlayID:overlayID];
		[_mapView addOverlay:overlay];
	}

	-(void)addTileOverlay:(NSString*)urlTemplate minZoom:(int)minZoom maxZoom:(int)maxZoom opacity:(float)opacity overlayID:(int)overlayID
	{
		if (_mapView == nil || urlTemplate == nil) return;

		MKTileOverlay* overlay = [[MKTileOverlay alloc] initWithURLTemplate:urlTemplate];
		overlay.minimumZ = (NSInteger)minZoom;
		overlay.maximumZ = (NSInteger)maxZoom;
		overlay.canReplaceMapContent = NO;

		MKTileOverlayRenderer* renderer = [[MKTileOverlayRenderer alloc] initWithTileOverlay:overlay];
		renderer.alpha = MAX(0.0, MIN((double)opacity, 1.0));

		[self registerOverlay:overlay renderer:renderer overlayID:overlayID];
		[_mapView addOverlay:overlay level:MKOverlayLevelAboveRoads];
	}

	-(void)clearOverlays
	{
		for(id key in _overlays)
		{
			FuseOverlay* a = [_overlays objectForKey:key];
			if (a==nil) continue;
			[_mapView removeOverlay:a.overlay];
		}
		[_overlays removeAllObjects];
	}

	-(void)clearRoutes
	{
		for(id key in _routes)
		{
			FuseOverlay* route = [_routes objectForKey:key];
			if (route == nil) continue;
			[_mapView removeOverlay:route.overlay];
		}
		[_routes removeAllObjects];
	}

	-(void)addRoutePolyline:(int)uid coordinates:(id)coords strokeColor:(UIColor*)color lineWidth:(int)lineWidth alpha:(float)alpha
	{
		if (_mapView == nil || coords == nil)
			return;

		NSUInteger count = [coords count] / 2;
		if (count < 2)
			return;

		CLLocationCoordinate2D* points = malloc(sizeof(CLLocationCoordinate2D) * count);
		for (NSUInteger i = 0; i < count; i++)
		{
			double lat = [[coords objectAtIndex:(i * 2)] doubleValue];
			double lon = [[coords objectAtIndex:(i * 2) + 1] doubleValue];
			points[i] = CLLocationCoordinate2DMake(lat, lon);
		}

		MKPolyline* polyline = [MKPolyline polylineWithCoordinates:points count:count];
		free(points);

		MKPolylineRenderer* renderer = [[MKPolylineRenderer alloc] initWithPolyline:polyline];
		renderer.strokeColor = color;
		renderer.lineWidth = lineWidth;
		renderer.alpha = alpha;

		FuseOverlay* entry = [[FuseOverlay alloc] init];
		entry.overlay = polyline;
		entry.renderer = renderer;
		entry.overlayID = uid;
		[_routes setObject:entry forKey:@(uid)];

		[_mapView addOverlay:polyline level:MKOverlayLevelAboveRoads];
	}

	-(void)onTap:(UITapGestureRecognizer*)sender
	{
		if (sender.state == UIGestureRecognizerStateEnded && touchBlock != nil)
		{
			CGPoint l = [sender locationInView:_mapView];
			CLLocationCoordinate2D coord = [_mapView convertPoint:l toCoordinateFromView:_mapView];

			touchBlock(2, coord.latitude, coord.longitude);
			[self checkOverlayTapped:coord];
		}
	}

	-(void)checkOverlayTapped:(CLLocationCoordinate2D)coord
	{
		if (overlaySelectBlock == NULL)
			return;

		MKMapPoint mappoint = MKMapPointForCoordinate(coord);
		NSArray* overlays = _mapView.overlays;

		// Iterate from the topmost overlay down.
		for (NSInteger index = (NSInteger)overlays.count - 1; index >= 0; index--)
		{
			id<MKOverlay> overlay = [overlays objectAtIndex:(NSUInteger)index];

			MKOverlayPathRenderer * renderer = (MKOverlayPathRenderer*)[_mapView rendererForOverlay:overlay];
			if (renderer == nil)
				continue;

			if (![renderer isKindOfClass:[MKOverlayPathRenderer class]])
				continue;

			CGPoint tapPoint = [renderer pointForMapPoint:mappoint];

			BOOL hit = NO;
			if ([overlay isKindOfClass:[MKPolyline class]])
				hit = [self isPoint:tapPoint nearPolyline:(MKPolyline*)overlay renderer:renderer];
			else if (renderer.path != NULL)
				hit = CGPathContainsPoint(renderer.path, nil, tapPoint, false);

			if (hit)
			{
				for(id key in _overlays)
				{
					FuseOverlay* a = [_overlays objectForKey:key];
					if (a.overlay == overlay)
					{
						overlaySelectBlock(a.overlayID);
						return;
					}
				}
			}
		}
	}

	-(BOOL)isPoint:(CGPoint)point nearPolyline:(MKPolyline*)polyline renderer:(MKOverlayPathRenderer*)renderer
	{
		NSUInteger count = polyline.pointCount;
		if (count < 2)
			return NO;

		MKMapPoint* points = polyline.points;
		double tolerance = MAX(renderer.lineWidth, 22.0);
		double toleranceSq = tolerance * tolerance;

		for (NSUInteger i = 1; i < count; i++)
		{
			CGPoint a = [renderer pointForMapPoint:points[i-1]];
			CGPoint b = [renderer pointForMapPoint:points[i]];
			if (DistanceSquaredFromPointToSegment(point, a, b) <= toleranceSq)
				return YES;
		}

		return NO;
	}

	-(void)onLongPress:(UILongPressGestureRecognizer *)sender
	{
		if (touchBlock == nil) return;
		if (sender.state == UIGestureRecognizerStateBegan)
		{
			CGPoint l = [sender locationInView:_mapView];
			CLLocationCoordinate2D coord = [_mapView convertPoint:l toCoordinateFromView:_mapView];
			touchBlock(3, coord.latitude, coord.longitude);
		}
	}

	-(void)setMarkerSelectAction:(void(^)(int, NSString*))action
	{
		id previous = markerSelectBlock;
		markerSelectBlock = action;
	}

	-(void)setMarkerSelectedAction:(void(^)(int))action
	{
		markerSelectedBlock = action;
	}

	-(void)setMarkerDeselectAction:(void(^)(int))action
	{
		markerDeselectBlock = action;
	}

	-(void)setMarkerDragStartAction:(void(^)(int))action
	{
		markerDragStartBlock = action;
	}

	-(void)setMarkerDragAction:(void(^)(int, double, double))action
	{
		markerDragBlock = action;
	}

	-(void)setMarkerDragEndAction:(void(^)(int, double, double))action
	{
		markerDragEndBlock = action;
	}

	-(void)setMapTouchAction:(void(^)(int type, double x, double y))action
	{
		id previous = touchBlock;
		touchBlock = action;
	}

	-(void)setMapMoveAction:(void(^)(bool))action
	{
		id previous = mapMoveBlock;
		mapMoveBlock = action;
	}

	- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
	{
		for(id key in _overlays)
		{
			FuseOverlay* a = [_overlays objectForKey:key];
			if (a.overlay == overlay)
				return a.renderer;
		}

		for(id key in _routes)
		{
			FuseOverlay* route = [_routes objectForKey:key];
			if (route.overlay == overlay)
				return route.renderer;
		}

		MKOverlayPathRenderer *renderer = nil;
		if ([overlay isKindOfClass:[MKPolyline class]])
			renderer = [[MKPolylineRenderer alloc] initWithPolyline:(MKPolyline *)overlay];
		else if ([overlay isKindOfClass:[MKPolygon class]])
			renderer = [[MKPolygonRenderer alloc] initWithPolygon:(MKPolygon *)overlay];
		else if ([overlay isKindOfClass:[MKCircle class]])
			renderer = [[MKCircleRenderer alloc] initWithCircle:(MKCircle *)overlay];
		else if ([overlay isKindOfClass:[MKTileOverlay class]])
			return [[MKTileOverlayRenderer alloc] initWithTileOverlay:(MKTileOverlay *)overlay];
		else if ([overlay isKindOfClass:[FuseGroundOverlay class]])
			return [[FuseGroundOverlayRenderer alloc] initWithOverlay:overlay];
		else
			return nil;

		renderer.lineWidth = 2;
		renderer.strokeColor = [UIColor redColor];
		renderer.fillColor = [UIColor redColor];

		return renderer;
	}

	- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
	{
		if ([NSDate timeIntervalSinceReferenceDate] < _suppressMapMoveUntil)
			return;

		if (mapMoveBlock)
			mapMoveBlock(animated);
	}

	-(double)longitudeToPixelSpaceX:(double)longitude
	{
		return round(MERCATOR_OFFSET + MERCATOR_RADIUS * longitude * M_PI / 180.0);
	}

	-(double)latitudeToPixelSpaceY:(double)latitude
	{
		return round(MERCATOR_OFFSET - MERCATOR_RADIUS * logf((1 + sinf(latitude * M_PI / 180.0)) / (1 - sinf(latitude * M_PI / 180.0))) / 2.0);
	}

	-(double)pixelSpaceXToLongitude:(double)pixelX
	{
		return ((round(pixelX) - MERCATOR_OFFSET) / MERCATOR_RADIUS) * 180.0 / M_PI;
	}

	-(double)pixelSpaceYToLatitude:(double)pixelY
	{
		return (M_PI / 2.0 - 2.0 * atan(exp((round(pixelY) - MERCATOR_OFFSET) / MERCATOR_RADIUS))) * 180.0 / M_PI;
	}
	-(MKAnnotationView *)mapView:(MKMapView *)theMapView viewForAnnotation:(id <MKAnnotation>)annotation
	{
		if ([annotation isKindOfClass:[MKUserLocation class]])
			return nil;  //return nil to use default blue dot view

		// When using this MapView at the same time as FuseJS/GeoLocation we sporadically receive an
		// annotation of type MKUserLocation, so never assume the annotation is a FusePinAnnotation.
		if (![annotation isKindOfClass:[FusePinAnnotation class]])
			return nil;

		FusePinAnnotation* a = (FusePinAnnotation*)annotation;

		if (a.icon == nil)
		{
			static NSString* defaultIdentifier = @"FuseDefaultMarker";
			MKMarkerAnnotationView* markerView = (MKMarkerAnnotationView*)[theMapView dequeueReusableAnnotationViewWithIdentifier:defaultIdentifier];
			if (markerView == nil)
			{
				markerView = [[MKMarkerAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:defaultIdentifier];
				markerView.canShowCallout = YES;
			}
			markerView.draggable = a.draggable;
			markerView.markerTintColor = a.markerColor;
			markerView.annotation = annotation;
			return markerView;
		}

		NSString* identifier = a.icon;
		MKAnnotationView* annotationView = (MKAnnotationView*)[theMapView dequeueReusableAnnotationViewWithIdentifier:identifier];
		if (annotationView == nil)
		{
			annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:identifier];
			annotationView.canShowCallout = YES;
		}

		UIImage* image = [UIImage imageWithContentsOfFile:a.icon];
		if (image != nil && image.size.width > 0.0)
		{
			double ratio = image.size.width / 32.0; //32 is the width of the standard pin view
			UIImage* scaledImage = [UIImage imageWithCGImage:[image CGImage] scale:ratio orientation:image.imageOrientation];
			annotationView.image = scaledImage;
			annotationView.centerOffset = CGPointMake(scaledImage.size.width*(a.iconX-0.5), -scaledImage.size.height*(a.iconY-0.5));
		}

		annotationView.annotation = annotation;
		annotationView.draggable = a.draggable;
		return annotationView;
	}

	-(MKCoordinateSpan)coordinateSpanWithMapView:(MKMapView *)mapView centerCoordinate:(CLLocationCoordinate2D)centerCoordinate andZoomLevel:(NSUInteger)zoomLevel
	{
		// convert center coordiate to pixel space
		double centerPixelX = [self longitudeToPixelSpaceX:centerCoordinate.longitude];
		double centerPixelY = [self latitudeToPixelSpaceY:centerCoordinate.latitude];

		// determine the scale value from the zoom level
		NSInteger zoomExponent = log2(MKMapSizeWorld.width / 256) - zoomLevel;
		double zoomScale = pow(2, zoomExponent);

		// scale the map’s size in pixel space
		CGSize mapSizeInPixels = mapView.bounds.size;
		double scaledMapWidth = mapSizeInPixels.width * zoomScale;
		double scaledMapHeight = mapSizeInPixels.height * zoomScale;

		// figure out the position of the top-left pixel
		double topLeftPixelX = centerPixelX - (scaledMapWidth / 2);
		double topLeftPixelY = centerPixelY - (scaledMapHeight / 2);

		// find delta between left and right longitudes
		CLLocationDegrees minLng = [self pixelSpaceXToLongitude:topLeftPixelX];
		CLLocationDegrees maxLng = [self pixelSpaceXToLongitude:topLeftPixelX + scaledMapWidth];
		CLLocationDegrees longitudeDelta = maxLng - minLng;

		// find delta between top and bottom latitudes
		CLLocationDegrees minLat = [self pixelSpaceYToLatitude:topLeftPixelY];
		CLLocationDegrees maxLat = [self pixelSpaceYToLatitude:topLeftPixelY + scaledMapHeight];
		CLLocationDegrees latitudeDelta = -1 * (maxLat - minLat);

		// create and return the lat/lng span
		MKCoordinateSpan span = MKCoordinateSpanMake(latitudeDelta, longitudeDelta);
		return span;
	}

	-(void)moveTo:(double)lat longitude:(double)lng zoom:(double)z tilt:(double)t orientation:(double)o
	{
		if (_mapView == nil)
			return;

		z = MAX(2.0, MIN(z, 21));
		z = MAX(_minZoom, MIN(z, _maxZoom));

		CLLocationCoordinate2D newCenter = CLLocationCoordinate2DMake(lat, lng);
		MKCoordinateSpan span = [self coordinateSpanWithMapView:_mapView centerCoordinate:newCenter andZoomLevel:z];
		[_mapView setRegion:MKCoordinateRegionMake(newCenter, span) animated:NO];

		double pitch = MAX(0.0, MIN(t, 75.0));
		double heading = fmod(o, 360.0);
		if (heading < 0.0)
			heading += 360.0;

		MKMapCamera* camera = _mapView.camera;
		if (fabs(camera.pitch - pitch) > 0.01 || fabs(camera.heading - heading) > 0.01)
		{
			camera.centerCoordinate = newCenter;
			camera.pitch = pitch;
			camera.heading = heading;
			[_mapView setCamera:camera animated:NO];
		}
	}

	-(void)showAllAnotations
	{
		if (_mapView == nil)
			return;

		NSMutableArray* annotations = [NSMutableArray array];
		for (id<MKAnnotation> annotation in _mapView.annotations)
		{
			if (![annotation isKindOfClass:[MKUserLocation class]])
				[annotations addObject:annotation];
		}

		if (annotations.count == 0)
			return;

		[_mapView showAnnotations:annotations animated:YES];
	}

	-(void)animateTo:(double)lat longitude:(double)lng zoom:(double)z tilt:(double)t orientation:(double)o duration:(double)duration
	{
		if (_mapView == nil)
			return;

		z = MAX(2.0, MIN(z, 21));
		z = MAX(_minZoom, MIN(z, _maxZoom));

		CLLocationCoordinate2D center = CLLocationCoordinate2DMake(lat, lng);
		MKCoordinateSpan span = [self coordinateSpanWithMapView:_mapView centerCoordinate:center andZoomLevel:z];
		MKCoordinateRegion region = MKCoordinateRegionMake(center, span);

		double pitch = MAX(0.0, MIN(t, 75.0));
		double heading = fmod(o, 360.0);
		if (heading < 0.0)
			heading += 360.0;

		_suppressMapMoveUntil = [NSDate timeIntervalSinceReferenceDate] + duration + 0.2;

		if (duration <= 0.0)
		{
			[self applyRegion:region center:center pitch:pitch heading:heading];
			return;
		}

		[UIView animateWithDuration:duration delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
			[self applyRegion:region center:center pitch:pitch heading:heading];
		} completion:^(BOOL finished) {
			if (self->mapMoveBlock)
				self->mapMoveBlock(YES);
		}];
	}

	-(void)applyRegion:(MKCoordinateRegion)region center:(CLLocationCoordinate2D)center pitch:(double)pitch heading:(double)heading
	{
		if (_mapView == nil)
			return;

		[_mapView setRegion:region animated:NO];

		MKMapCamera* camera = _mapView.camera;
		if (fabs(camera.pitch - pitch) > 0.01 || fabs(camera.heading - heading) > 0.01)
		{
			camera.centerCoordinate = center;
			camera.pitch = pitch;
			camera.heading = heading;
			[_mapView setCamera:camera animated:NO];
		}
	}

	-(void)cancelAnimation
	{
		if (_mapView == nil)
			return;

		[_mapView.layer removeAllAnimations];
		_suppressMapMoveUntil = [NSDate timeIntervalSinceReferenceDate] + 0.2;

		if (mapMoveBlock)
			mapMoveBlock(YES);
	}

	-(void)showBoundsMinLatitude:(double)minLat minLongitude:(double)minLng maxLatitude:(double)maxLat maxLongitude:(double)maxLng
	{
		if (_mapView == nil)
			return;

		MKMapPoint southWest = MKMapPointForCoordinate(CLLocationCoordinate2DMake(minLat, minLng));
		MKMapPoint northEast = MKMapPointForCoordinate(CLLocationCoordinate2DMake(maxLat, maxLng));

		double x = MIN(southWest.x, northEast.x);
		double y = MIN(southWest.y, northEast.y);
		double width = fabs(northEast.x - southWest.x);
		double height = fabs(northEast.y - southWest.y);

		if (width <= 0.0) width = 1.0;
		if (height <= 0.0) height = 1.0;

		MKMapRect rect = MKMapRectMake(x, y, width, height);
		UIEdgeInsets insets = UIEdgeInsetsMake(_padTop, _padLeft, _padBottom, _padRight);

		_suppressMapMoveUntil = [NSDate timeIntervalSinceReferenceDate] + 0.8;
		[_mapView setVisibleMapRect:rect edgePadding:insets animated:YES];

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			if (self->mapMoveBlock)
				self->mapMoveBlock(YES);
		});
	}

	-(void)setPaddingLeft:(float)left top:(float)top right:(float)right bottom:(float)bottom
	{
		_padLeft = left;
		_padTop = top;
		_padRight = right;
		_padBottom = bottom;

		if (_mapView != nil)
			_mapView.layoutMargins = UIEdgeInsetsMake(top, left, bottom, right);
	}

	-(void)setZoomLimitsMin:(double)minZoom max:(double)maxZoom
	{
		if (minZoom > maxZoom)
			return;

		_minZoom = minZoom;
		_maxZoom = maxZoom;

		if (_mapView == nil)
			return;

		if (@available(iOS 13.0, *))
		{
			double currentZoom = [self getZoomLevel];
			double currentDistance = _mapView.camera.centerCoordinateDistance;

			if (currentZoom <= 0.0 || currentDistance <= 0.0)
				return;

			double minDistance = currentDistance * pow(2.0, currentZoom - _maxZoom);
			double maxDistance = currentDistance * pow(2.0, currentZoom - _minZoom);

			_mapView.cameraZoomRange = [[MKMapCameraZoomRange alloc] initWithMinCenterCoordinateDistance:minDistance maxCenterCoordinateDistance:maxDistance];
		}
	}

	-(void)zoomBy:(double)delta
	{
		if (_mapView == nil)
			return;

		double z = [self getZoomLevel] + delta;
		CLLocationCoordinate2D center = _mapView.centerCoordinate;
		[self moveTo:center.latitude longitude:center.longitude zoom:z tilt:_mapView.camera.pitch orientation:_mapView.camera.heading];

		if (mapMoveBlock)
			mapMoveBlock(YES);
	}

	-(void)scrollBy:(float)dx dy:(float)dy
	{
		if (_mapView == nil)
			return;

		CGPoint center = [_mapView convertCoordinate:_mapView.centerCoordinate toPointToView:_mapView];
		CGPoint shifted = CGPointMake(center.x + dx, center.y + dy);
		CLLocationCoordinate2D coord = [_mapView convertPoint:shifted toCoordinateFromView:_mapView];

		if (CLLocationCoordinate2DIsValid(coord))
		{
			[_mapView setCenterCoordinate:coord animated:NO];

			if (mapMoveBlock)
				mapMoveBlock(YES);
		}
	}

	-(MKCoordinateRegion)visibleCoordinateRegion
	{
		return MKCoordinateRegionForMapRect(_mapView.visibleMapRect);
	}

	-(double)getVisibleMinLatitude
	{
		if (_mapView == nil) return 0.0;
		MKCoordinateRegion region = [self visibleCoordinateRegion];
		return region.center.latitude - region.span.latitudeDelta / 2.0;
	}

	-(double)getVisibleMinLongitude
	{
		if (_mapView == nil) return 0.0;
		MKCoordinateRegion region = [self visibleCoordinateRegion];
		return region.center.longitude - region.span.longitudeDelta / 2.0;
	}

	-(double)getVisibleMaxLatitude
	{
		if (_mapView == nil) return 0.0;
		MKCoordinateRegion region = [self visibleCoordinateRegion];
		return region.center.latitude + region.span.latitudeDelta / 2.0;
	}

	-(double)getVisibleMaxLongitude
	{
		if (_mapView == nil) return 0.0;
		MKCoordinateRegion region = [self visibleCoordinateRegion];
		return region.center.longitude + region.span.longitudeDelta / 2.0;
	}

	-(NSString*)sanitize:(NSString*)value
	{
		if (value == nil) return @"";

		NSString* result = [value stringByReplacingOccurrencesOfString:@"\t" withString:@" "];
		result = [result stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
		result = [result stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
		return result;
	}

	-(NSString*)formatPlacemarkAddress:(CLPlacemark*)placemark
	{
		NSMutableArray* parts = [NSMutableArray array];

		if (placemark.thoroughfare != nil) [parts addObject:placemark.thoroughfare];
		if (placemark.locality != nil) [parts addObject:placemark.locality];
		if (placemark.administrativeArea != nil) [parts addObject:placemark.administrativeArea];
		if (placemark.postalCode != nil) [parts addObject:placemark.postalCode];
		if (placemark.country != nil) [parts addObject:placemark.country];

		return [parts componentsJoinedByString:@", "];
	}

	-(NSString*)encodePlacemarks:(NSArray<CLPlacemark*>*)placemarks
	{
		NSMutableString* result = [NSMutableString string];

		for (CLPlacemark* placemark in placemarks)
		{
			NSString* name = placemark.name != nil ? placemark.name : @"";
			NSString* address = [self formatPlacemarkAddress:placemark];
			CLLocationCoordinate2D coordinate = placemark.location.coordinate;

			[result appendFormat:@"%@\t%@\t%f\t%f\n",
				[self sanitize:name], [self sanitize:address], coordinate.latitude, coordinate.longitude];
		}

		return result;
	}

	-(void)geocode:(NSString*)query onSuccess:(void(^)(NSString*))onSuccess onError:(void(^)(NSString*))onError
	{
		if (query == nil)
		{
			if (onError) onError(@"A query is required");
			return;
		}

		CLGeocoder* geocoder = [[CLGeocoder alloc] init];
		[geocoder geocodeAddressString:query completionHandler:^(NSArray<CLPlacemark *> *placemarks, NSError *error) {
			if (error != nil)
			{
				NSString* message = error.localizedDescription;
				dispatch_async(dispatch_get_main_queue(), ^{
					if (onError) onError(message);
				});
				return;
			}

			NSString* encoded = [self encodePlacemarks:placemarks];
			dispatch_async(dispatch_get_main_queue(), ^{
				if (onSuccess) onSuccess(encoded);
			});
		}];
	}

	-(void)reverseGeocode:(double)latitude longitude:(double)longitude onSuccess:(void(^)(NSString*))onSuccess onError:(void(^)(NSString*))onError
	{
		CLGeocoder* geocoder = [[CLGeocoder alloc] init];
		CLLocation* location = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];

		[geocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> *placemarks, NSError *error) {
			if (error != nil)
			{
				NSString* message = error.localizedDescription;
				dispatch_async(dispatch_get_main_queue(), ^{
					if (onError) onError(message);
				});
				return;
			}

			NSString* encoded = [self encodePlacemarks:placemarks];
			dispatch_async(dispatch_get_main_queue(), ^{
				if (onSuccess) onSuccess(encoded);
			});
		}];
	}

	-(void)calculateRoute:(double)fromLat fromLongitude:(double)fromLng toLatitude:(double)toLat toLongitude:(double)toLng mode:(int)mode onSuccess:(void(^)(NSString*))onSuccess onError:(void(^)(NSString*))onError
	{
		MKPlacemark* fromPlacemark = [[MKPlacemark alloc] initWithCoordinate:CLLocationCoordinate2DMake(fromLat, fromLng)];
		MKPlacemark* toPlacemark = [[MKPlacemark alloc] initWithCoordinate:CLLocationCoordinate2DMake(toLat, toLng)];

		MKDirectionsRequest* request = [[MKDirectionsRequest alloc] init];
		request.source = [[MKMapItem alloc] initWithPlacemark:fromPlacemark];
		request.destination = [[MKMapItem alloc] initWithPlacemark:toPlacemark];

		switch (mode)
		{
			case 1: request.transportType = MKDirectionsTransportTypeWalking; break;
			case 2: request.transportType = MKDirectionsTransportTypeTransit; break;
			case 3: request.transportType = MKDirectionsTransportTypeWalking; break; // cycling is not supported by MapKit
			default: request.transportType = MKDirectionsTransportTypeAutomobile; break;
		}

		MKDirections* directions = [[MKDirections alloc] initWithRequest:request];
		[directions calculateDirectionsWithCompletionHandler:^(MKDirectionsResponse* response, NSError* error) {
			if (error != nil)
			{
				NSString* message = error.localizedDescription;
				dispatch_async(dispatch_get_main_queue(), ^{
					if (onError) onError(message);
				});
				return;
			}

			NSArray<MKRoute*>* routes = response.routes;
			if (routes == nil || routes.count == 0)
			{
				dispatch_async(dispatch_get_main_queue(), ^{
					if (onError) onError(@"No route was found");
				});
				return;
			}

			MKRoute* route = routes[0];
			NSString* name = route.name != nil ? route.name : @"";

			NSMutableString* result = [NSMutableString stringWithFormat:@"%.0f\t%.0f\t%@\n",
				route.distance, route.expectedTravelTime, [self sanitize:name]];

			MKPolyline* polyline = route.polyline;
			MKMapPoint* points = polyline.points;

			for (NSUInteger i = 0; i < polyline.pointCount; i++)
			{
				CLLocationCoordinate2D coordinate = MKCoordinateForMapPoint(points[i]);
				[result appendFormat:@"%f\t%f\n", coordinate.latitude, coordinate.longitude];
			}

			dispatch_async(dispatch_get_main_queue(), ^{
				if (onSuccess) onSuccess(result);
			});
		}];
	}

	-(void)takeSnapshot:(void(^)(NSString *))onSnapshotSucceed error:(void(^)(NSString *))onSnapshotError
	{
		MKMapSnapshotOptions *options = [[MKMapSnapshotOptions alloc] init];
		options.region = _mapView.region;
		options.scale = [UIScreen mainScreen].scale;
		options.size = _mapView.frame.size;

		MKMapSnapshotter *snapshotter = [[MKMapSnapshotter alloc] initWithOptions:options];
		[snapshotter startWithCompletionHandler:^(MKMapSnapshot *snapshot, NSError *error) {
			if (error != nil) {
				if (onSnapshotError != nil)
					onSnapshotError([error localizedDescription]);
				return;
			}

			UIImage *image = snapshot.image;
			MKAnnotationView *pin = [[MKPinAnnotationView alloc] initWithAnnotation:nil reuseIdentifier:@""];

			CGRect finalImageRect = CGRectMake(0, 0, image.size.width, image.size.height);
			UIGraphicsBeginImageContextWithOptions(image.size, YES, image.scale);
			[image drawAtPoint:CGPointMake(0, 0)];

			for (FusePinAnnotation * annotation in [_annotations allValues])
			{
				CGPoint point = [snapshot pointForCoordinate:annotation.coordinate];
				if (CGRectContainsPoint(finalImageRect, point)) // this is too conservative, but you get the idea
				{
					UIImage* pinImage;
					CGPoint pinCenterOffset;
					if (annotation.icon != nil)
					{
						UIImage* imgMarker = [UIImage imageWithContentsOfFile:annotation.icon];
						double ratio = imgMarker.size.width / 32.0; //32 is the width of the standard pin view
						pinImage = [UIImage imageWithCGImage:[imgMarker CGImage] scale:ratio orientation:imgMarker.imageOrientation];
						pinCenterOffset = CGPointMake(pin.frame.size.width*(annotation.iconX-0.5), -pin.frame.size.height*(annotation.iconY-0.5));
					}
					else
					{
						pinImage = pin.image;
						pinCenterOffset = pin.centerOffset;
					}
					point.x -= pin.bounds.size.width / 2.0;
					point.y -= pin.bounds.size.height / 2.0;
					point.x += pinCenterOffset.x;
					point.y += pinCenterOffset.y;

					[pinImage drawAtPoint:point];
				}
			}

			UIImage *finalImage = UIGraphicsGetImageFromCurrentImageContext();
			UIGraphicsEndImageContext();
			NSData *data = UIImagePNGRepresentation(finalImage);
			NSString * path = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)[0];
			NSString * filename = [path stringByAppendingPathComponent:@"map_snapshot.png"];
			[data writeToFile:filename atomically:YES];

			if (onSnapshotSucceed != nil)
				onSnapshotSucceed(filename);
		}];
	}

	-(double)getZoomLevel
	{
		if (_mapView == nil)
			return 0.0;

		CLLocationDegrees longitudeDelta = _mapView.region.span.longitudeDelta;
		double mapWidthPoints = CGRectGetWidth(_mapView.bounds);

		if (longitudeDelta <= 0.0 || mapWidthPoints <= 0.0)
			return 0.0;

		return log2(360.0 * mapWidthPoints / (256.0 * longitudeDelta));
	}

@end
