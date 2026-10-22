#import "FODeviceMotion.h"
#import "FOMotionManager.h"

@interface FODeviceMotion ()

@property (nonatomic, strong) CMMotionManager *motionManager;
@property (nonatomic, assign) NSInteger listenerToken;

@end


@implementation FODeviceMotion

@synthesize _onDataChanged;
@synthesize _onError;

- (instancetype)initWithBlock:(void (^)(CMDeviceMotion* deviceMotionData))onDataChanged error:(void (^)(NSError* err))onError
{
    if (self = [super init])
    {
        self.motionManager = [FOMotionManager sharedMotionManager];
        self._onDataChanged = onDataChanged;
        self._onError = onError;
        self.listenerToken = 0;
    }
    return self;
}

- (void)dealloc
{
    [FOMotionManager removeDeviceMotionListener:_listenerToken];
}

#pragma mark Sensing

+ (BOOL)isSensorAvailable
{
    return [FOMotionManager sharedMotionManager].isDeviceMotionAvailable;
}

- (BOOL)startSensing
{
    if (![FODeviceMotion isSensorAvailable])
    {
        return NO;
    }

    if (self.listenerToken != 0)
    {
        _sensing = YES;
        return YES;
    }

    // Device motion is shared between GRAVITY, USER_ACCELERATION and ROTATION. Registering a
    // listener instead of calling startDeviceMotionUpdates directly keeps the other providers
    // running when one of them stops.
    self.listenerToken = [FOMotionManager addDeviceMotionListener:self._onDataChanged error:self._onError];
    _sensing = YES;
    return YES;
}

- (BOOL)stopSensing
{
    [FOMotionManager removeDeviceMotionListener:self.listenerToken];
    self.listenerToken = 0;
    _sensing = NO;
    return YES;
}

@end
