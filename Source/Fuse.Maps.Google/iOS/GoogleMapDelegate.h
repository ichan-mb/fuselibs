#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>
#import <GoogleMaps/GoogleMaps.h>
#import <UIKit/UIKit.h>

@interface GoogleMapDelegate
    : NSObject <GMSMapViewDelegate, CLLocationManagerDelegate>

- (void)setAsDelegate:(GMSMapView *)mapView;
- (void)setActions:(void (^)(void))onReady
         onCameraIdle:(void (^)(void))onCameraIdle
          onMarkerTap:(void (^)(int, NSString *))onMarkerTap
       onMarkerSelect:(void (^)(int))onMarkerSelect
     onMarkerDeselect:(void (^)(int))onMarkerDeselect
    onMarkerDragStart:(void (^)(int))onMarkerDragStart
         onMarkerDrag:(void (^)(int, double, double))onMarkerDrag
      onMarkerDragEnd:(void (^)(int, double, double))onMarkerDragEnd
         onOverlayTap:(void (^)(int))onOverlayTap
             onMapTap:(void (^)(double, double))onMapTap
       onMapLongPress:(void (^)(double, double))onMapLongPress;
- (void)requestLocationAuth:(void (^)(bool))callback;
- (void)cleanup;

- (void)addMarker:(int)uid
         latitude:(double)latitude
        longitude:(double)longitude
            label:(NSString *)label
          snippet:(NSString *)snippet
             icon:(NSString *)iconPath
          anchorX:(float)anchorX
          anchorY:(float)anchorY
            color:(UIColor *)color
        draggable:(bool)draggable;

- (void)updateMarker:(int)uid
            latitude:(double)latitude
           longitude:(double)longitude
               label:(NSString *)label
             snippet:(NSString *)snippet
                icon:(NSString *)iconPath
             anchorX:(float)anchorX
             anchorY:(float)anchorY
               color:(UIColor *)color
           draggable:(bool)draggable;

- (void)removeMarker:(int)uid;
- (void)clearMarkers;
- (void)selectMarker:(int)uid;
- (void)deselectMarker:(int)uid;

- (void)addPolyline:(int)uid
        coordinates:(NSArray<NSNumber *> *)coordinates
        strokeColor:(UIColor *)strokeColor
          lineWidth:(int)lineWidth
           geodesic:(bool)geodesic
             zIndex:(int)zIndex
              alpha:(float)alpha;

- (void)addPolygon:(int)uid
       coordinates:(NSArray<NSNumber *> *)coordinates
             holes:(NSArray<NSNumber *> *)holes
       holeLengths:(NSArray<NSNumber *> *)holeLengths
       strokeColor:(UIColor *)strokeColor
         fillColor:(UIColor *)fillColor
         lineWidth:(int)lineWidth
          geodesic:(bool)geodesic
            zIndex:(int)zIndex
             alpha:(float)alpha;

- (void)addCircle:(int)uid
         latitude:(double)latitude
        longitude:(double)longitude
           radius:(double)radius
      strokeColor:(UIColor *)strokeColor
        fillColor:(UIColor *)fillColor
        lineWidth:(int)lineWidth
           zIndex:(int)zIndex
            alpha:(float)alpha;

- (void)addGroundOverlay:(int)uid
                   image:(NSString *)imagePath
             minLatitude:(double)minLatitude
            minLongitude:(double)minLongitude
             maxLatitude:(double)maxLatitude
            maxLongitude:(double)maxLongitude
                 opacity:(float)opacity
                  zIndex:(int)zIndex;

- (void)addTileLayer:(int)uid
         urlTemplate:(NSString *)urlTemplate
             minZoom:(int)minZoom
             maxZoom:(int)maxZoom
             opacity:(float)opacity
              zIndex:(int)zIndex;

- (void)clearOverlays;

- (void)addRoutePolyline:(int)uid
             coordinates:(NSArray<NSNumber *> *)coordinates
             strokeColor:(UIColor *)strokeColor
               lineWidth:(int)lineWidth
                   alpha:(float)alpha
                  zIndex:(int)zIndex;

- (void)clearRoutes;

- (void)geocode:(NSString *)query
         apiKey:(NSString *)apiKey
        success:(void (^)(NSString *))success
          error:(void (^)(NSString *))error;

- (void)reverseGeocode:(double)latitude
             longitude:(double)longitude
                apiKey:(NSString *)apiKey
               success:(void (^)(NSString *))success
                 error:(void (^)(NSString *))error;

- (void)calculateRouteFrom:(double)fromLatitude
             fromLongitude:(double)fromLongitude
                toLatitude:(double)toLatitude
               toLongitude:(double)toLongitude
                      mode:(int)mode
                    apiKey:(NSString *)apiKey
                   success:(void (^)(NSString *))success
                     error:(void (^)(NSString *))error;

- (void)takeSnapshot:(void (^)(NSString *))success
               error:(void (^)(NSString *))error;

@end
