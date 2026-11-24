#include <iOS/LocationManagerDelegate.h>

@implementation LocationManagerDelegate

@synthesize _onLocationChanged;
@synthesize _onError;
@synthesize _onChangeAuthorizationStatus;
@synthesize _onHeadingChanged;
@synthesize _onRegionEvent;

- (id)initWithBlock:(void (^)(CLLocation* location))onLocationChanged error:(void (^)(NSError* err))onError
										 changeAuthorizationStatus:(void (^)(int status))onChangeAuthorizationStatus
										 heading:(void (^)(CLHeading* heading))onHeadingChanged
										 regionEvent:(void (^)(CLRegion* region, int event, NSError* error))onRegionEvent {
	self = [super init];
	if (self) {
		self._onChangeAuthorizationStatus = onChangeAuthorizationStatus;
		self._onLocationChanged = onLocationChanged;
		self._onError = onError;
		self._onHeadingChanged = onHeadingChanged;
		self._onRegionEvent = onRegionEvent;
	}
	return self;
}

- (void)locationManager:(CLLocationManager*)manager didUpdateLocations:(NSArray*)locations {
	for (CLLocation* location in locations) {
		_onLocationChanged(location);
	}
}

- (void)locationManager:(CLLocationManager*)manager didUpdateHeading:(CLHeading*)newHeading {
	if (_onHeadingChanged)
		_onHeadingChanged(newHeading);
}

- (void)locationManager:(CLLocationManager*)manager didStartMonitoringForRegion:(CLRegion*)region {
	[manager requestStateForRegion:region];
}

- (void)locationManager:(CLLocationManager*)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion*)region {
	if (state == CLRegionStateInside) {
		if (_onRegionEvent)
			_onRegionEvent(region, 1, nil);
	} else if (state == CLRegionStateOutside) {
		if (_onRegionEvent)
			_onRegionEvent(region, 2, nil);
	}
}

- (void)locationManager:(CLLocationManager*)manager didEnterRegion:(CLRegion*)region {
	if (_onRegionEvent)
		_onRegionEvent(region, 1, nil);
}

- (void)locationManager:(CLLocationManager*)manager didExitRegion:(CLRegion*)region {
	if (_onRegionEvent)
		_onRegionEvent(region, 2, nil);
}

- (void)locationManager:(CLLocationManager*)manager monitoringDidFailForRegion:(CLRegion*)region withError:(NSError*)error {
	if (_onRegionEvent)
		_onRegionEvent(region, 3, error);
}

- (BOOL)locationManagerShouldDisplayHeadingCalibration:(CLLocationManager*)manager {
	return NO;
}

- (void)locationManager:(CLLocationManager*)manager didFailWithError:(NSError*)error {
	_onError(error);
}

- (void)locationManager:(CLLocationManager*)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
	_onChangeAuthorizationStatus((int)status);
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager*)manager {
	CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
	if (@available(iOS 14.0, *))
		status = manager.authorizationStatus;
	_onChangeAuthorizationStatus((int)status);
}

@end
