#include <CoreLocation/CoreLocation.h>

@interface LocationManagerDelegate : NSObject<CLLocationManagerDelegate>
@property (nonatomic, copy) void (^_onLocationChanged)(CLLocation* location);
@property (nonatomic, copy) void (^_onError)(NSError* location);
@property (nonatomic, copy) void (^_onChangeAuthorizationStatus)(int status);
@property (nonatomic, copy) void (^_onHeadingChanged)(CLHeading* heading);
@property (nonatomic, copy) void (^_onRegionEvent)(CLRegion* region, int event, NSError* error);
- (id)initWithBlock:(void (^)(CLLocation* location))onLocationChanged error:(void (^)(NSError* err))onError
											 changeAuthorizationStatus:(void (^)(int status))onChangeAuthorizationStatus
											 heading:(void (^)(CLHeading* heading))onHeadingChanged
											 regionEvent:(void (^)(CLRegion* region, int event, NSError* error))onRegionEvent;
@end
