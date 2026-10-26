#import <MapKit/MapKit.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface MapViewDelegate : NSObject<MKMapViewDelegate, CLLocationManagerDelegate>
	-(void)setAsDelegate:(MKMapView*)mv;
	-(void)cleanup;
	-(void)setShowsMyLocationButton:(BOOL)show;
	-(double)getZoomLevel;
	-(void)setMapMoveAction:(void(^)(bool))action;
	-(void)setMapTouchAction:(void(^)(int, double, double))action;
	-(void)setMarkerSelectAction:(void(^)(int, NSString*))action;
	-(void)setMarkerSelectedAction:(void(^)(int))action;
	-(int)addMarker:(NSString*)label
	latitude:(double)lat
	longitude:(double)lng
	snippet:(NSString*)snippet
	icon:(NSString*)iconPath
	iconX:(float)iconX
	iconY:(float)iconY
	color:(UIColor*)color
	draggable:(bool)draggable
	markerID:(int)markerID;
	-(void)updateMarker:(NSString*)label
	latitude:(double)lat
	longitude:(double)lng
	snippet:(NSString*)snippet
	icon:(NSString*)iconPath
	iconX:(float)iconX
	iconY:(float)iconY
	color:(UIColor*)color
	draggable:(bool)draggable
	markerID:(int)markerID;
	-(void)selectMarker:(int)markerID;
	-(void)deselectMarker:(int)markerID;
	-(BOOL)authorized;
	-(void)removeMarker:(int)identifier;
	-(void)clearMarkers;
	-(void)addOverlay:(id)coords type:(int)overlayType holes:(NSArray<NSNumber *> *)holeCoords holeLengths:(NSArray<NSNumber *> *)holeLengths strokeColor:(UIColor *)strokeColor fillColor:(UIColor *)fillColor lineWidth:(int)lineWidth geodesic:(bool)geodesic startCap:(int)startCap endCap:(int)endCap joinType:(int)joinType pattern:(NSArray<NSNumber *> *)pattern centerLatitude:(double)centerLatitude centerLongitude:(double)centerLongitude radius:(double)radius alpha:(float)alpha overlayID:(int)overlayID;
	-(void)addImageOverlay:(NSString*)imagePath minLatitude:(double)minLat minLongitude:(double)minLng maxLatitude:(double)maxLat maxLongitude:(double)maxLng opacity:(float)opacity overlayID:(int)overlayID;
	-(void)addTileOverlay:(NSString*)urlTemplate minZoom:(int)minZoom maxZoom:(int)maxZoom opacity:(float)opacity overlayID:(int)overlayID;
	-(void)clearOverlays;
	-(void)clearRoutes;
	-(void)addRoutePolyline:(int)uid coordinates:(id)coords strokeColor:(UIColor*)color lineWidth:(int)lineWidth alpha:(float)alpha;
	-(void)requestLocationAuthentication:(void(^)(bool))onRequestResult;
	-(void)locationManager:(CLLocationManager*)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status;
	-(void)moveTo:(double)lat longitude:(double)l zoom:(double)z tilt:(double)t orientation:(double)o;
	-(void)showAllAnotations;
	-(void)animateTo:(double)lat longitude:(double)lng zoom:(double)z tilt:(double)t orientation:(double)o duration:(double)duration;
	-(void)cancelAnimation;
	-(void)showBoundsMinLatitude:(double)minLat minLongitude:(double)minLng maxLatitude:(double)maxLat maxLongitude:(double)maxLng;
	-(void)setPaddingLeft:(float)left top:(float)top right:(float)right bottom:(float)bottom;
	-(void)setZoomLimitsMin:(double)minZoom max:(double)maxZoom;
	-(void)zoomBy:(double)delta;
	-(void)scrollBy:(float)dx dy:(float)dy;
	-(double)getVisibleMinLatitude;
	-(double)getVisibleMinLongitude;
	-(double)getVisibleMaxLatitude;
	-(double)getVisibleMaxLongitude;
	-(void)geocode:(NSString*)query onSuccess:(void(^)(NSString*))onSuccess onError:(void(^)(NSString*))onError;
	-(void)reverseGeocode:(double)latitude longitude:(double)longitude onSuccess:(void(^)(NSString*))onSuccess onError:(void(^)(NSString*))onError;
	-(void)calculateRoute:(double)fromLat fromLongitude:(double)fromLng toLatitude:(double)toLat toLongitude:(double)toLng mode:(int)mode onSuccess:(void(^)(NSString*))onSuccess onError:(void(^)(NSString*))onError;
	-(void)takeSnapshot:(void(^)(NSString *))onSnapshotSucceed error:(void(^)(NSString *))onSnapshotError;
	@property (nonatomic, strong) void (^mapMoveBlock)(bool);
	@property (nonatomic, strong) void (^touchBlock)(int type, double x, double y);
	@property (nonatomic, strong) void (^markerSelectBlock)(int id, NSString* label);
	@property (nonatomic, strong) void (^markerSelectedBlock)(int id);
	@property (nonatomic, strong) void (^markerDeselectBlock)(int id);
	@property (nonatomic, strong) void (^markerDragStartBlock)(int id);
	@property (nonatomic, strong) void (^markerDragBlock)(int id, double lat, double lng);
	@property (nonatomic, strong) void (^markerDragEndBlock)(int id, double lat, double lng);
	@property (nonatomic, strong) void (^overlaySelectBlock)(int id);
	@property (nonatomic, strong) void (^authChangeBlock)(bool authorized);
@end
