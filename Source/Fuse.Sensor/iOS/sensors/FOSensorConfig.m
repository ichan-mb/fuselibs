#import "FOSensorConfig.h"
#import "FOMotionManager.h"
#import "FOAccelerometer.h"
#import "FOGyroscope.h"
#import "FOMagnetometer.h"
#import "FODeviceMotion.h"
#import "FOPedometer.h"
#import "FOPressure.h"


// Must match Fuse.Sensor.SensorType.
enum
{
    SensorTypeAccelerometer = 0,
    SensorTypeGyroscope,
    SensorTypeMagnetometer,
    SensorTypeGravity,
    SensorTypeUserAcceleration,
    SensorTypeRotation,
    SensorTypeStepCounter,
    SensorTypePressure,
    SensorTypeBattery,
    SensorTypeConnectionState
};


@implementation FOSensorConfig

+ (BOOL)isAvailable:(int)sensorType
{
    switch (sensorType)
    {
        case SensorTypeAccelerometer:
            return [FOAccelerometer isSensorAvailable];

        case SensorTypeGyroscope:
            return [FOGyroscope isSensorAvailable];

        case SensorTypeMagnetometer:
            return [FOMagnetometer isSensorAvailable];

        case SensorTypeGravity:
        case SensorTypeUserAcceleration:
        case SensorTypeRotation:
            return [FODeviceMotion isSensorAvailable];

        case SensorTypeStepCounter:
            return [FOPedometer isSensorAvailable];

        case SensorTypePressure:
            return [FOPressure isSensorAvailable];

        case SensorTypeBattery:
        case SensorTypeConnectionState:
            return YES;
    }

    return NO;
}

+ (void)setUpdateInterval:(NSTimeInterval)interval forSensorType:(int)sensorType
{
    CMMotionManager *manager = [FOMotionManager sharedMotionManager];

    switch (sensorType)
    {
        case SensorTypeAccelerometer:
            manager.accelerometerUpdateInterval = interval;
            break;

        case SensorTypeGyroscope:
            manager.gyroUpdateInterval = interval;
            break;

        case SensorTypeMagnetometer:
            manager.magnetometerUpdateInterval = interval;
            break;

        case SensorTypeGravity:
        case SensorTypeUserAcceleration:
        case SensorTypeRotation:
            manager.deviceMotionUpdateInterval = interval;
            break;

        default:
            // Step counter, pressure, battery and connectivity are paced by the system.
            break;
    }
}

@end
