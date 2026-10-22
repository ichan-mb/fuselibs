#import <Foundation/Foundation.h>

/*
 * Common interface of the CoreMotion/UIKit backed sensor wrappers.
 *
 * The Uno layer only needs this protocol, so a single provider can start, stop and query any of
 * the concrete wrappers (accelerometer, gyroscope, device motion, battery, ...).
 */
@protocol FOSensor <NSObject>

- (BOOL)startSensing;

- (BOOL)stopSensing;

- (BOOL)isSensing;

@end
