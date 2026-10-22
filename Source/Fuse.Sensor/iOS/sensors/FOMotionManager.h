#import <Foundation/Foundation.h>
#include <CoreMotion/CoreMotion.h>

@interface FOMotionManager : NSObject

- (instancetype)init NS_UNAVAILABLE;

+ (CMMotionManager *)sharedMotionManager;

/*
 * CMMotionManager supports a single deviceMotion handler. Several sensor providers
 * (GRAVITY, USER_ACCELERATION and ROTATION) consume the same deviceMotion stream, so
 * updates have to be fanned out to all of them instead of each provider starting and
 * stopping deviceMotion updates on the shared manager.
 *
 * add returns a token that must be passed to removeDeviceMotionListener.
 */
+ (NSInteger)addDeviceMotionListener:(void (^)(CMDeviceMotion* deviceMotionData))onDataChanged
                               error:(void (^)(NSError* err))onError;

+ (void)removeDeviceMotionListener:(NSInteger)token;

@end
