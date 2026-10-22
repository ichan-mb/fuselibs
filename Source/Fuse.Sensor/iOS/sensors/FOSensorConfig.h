#import <Foundation/Foundation.h>

/*
 * CoreMotion availability and sampling rate configuration.
 *
 * Sensor types are addressed by the numeric value of Fuse.Sensor.SensorType.
 */
@interface FOSensorConfig : NSObject

- (instancetype)init NS_UNAVAILABLE;

+ (BOOL)isAvailable:(int)sensorType;

+ (void)setUpdateInterval:(NSTimeInterval)interval forSensorType:(int)sensorType;

@end
